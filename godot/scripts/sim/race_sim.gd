class_name RaceSim
extends RefCounted
## Port of web/src/race.js, generalized from one player to any number of human entries
## (LAN co-op and versus). Each human entry carries its own tactic, sparks and owner peer.
## The host runs this; clients render snapshots (see Net + RaceView).

static var track_cache := {}
const BOOST := {"b": 5.0, "s": 8.0, "g": 12.0}

var def: Dictionary
var tr: Dictionary
var ents: Array = []
var order: Array = []
var t := 0.0
var K := 1.0
var T0 := 30.0
var rain := false
var done := false
var finishing := false
var msgs: Array = []          # {t, text, ent} ; ent = -1 for everyone
var msg_seq := 0               # total messages ever pushed (for network deltas)
var msgT := {}
var fmt: Dictionary
var tt := false
var drag := false
var test := false
var tree := 0.0
var green_said := false
var end_t := -1.0
var final_lap := false
var lap_factor := 1.0
var last_leader := -1
var mode := "standard"
var auto_retire := true
var rng := RandomNumberGenerator.new()

# ---------------- track ----------------
static func build_track(d: Dictionary, wet: bool, laps_override = null) -> Dictionary:
	var key := "%s%s%s" % [d.id, "r" if wet else "", str(laps_override) if laps_override != null else ""]
	if track_cache.has(key): return track_cache[key]
	var rng := URng.new(URng.fnv(d.id))
	var st: Dictionary = Data.D.STYLES[d.style]
	var secs := []
	var p: Dictionary = st.get("p", {})
	var n := int(st.n)
	for i in n:
		var type: String
		if st.has("pat"):
			type = st.pat[i % st.pat.size()]
		else:
			type = _pick_w(p, rng)
			if i == 0: type = "str" if p.has("str") else type
			if i > 0 and type == secs[i - 1].type and (type == "jmp" or type == "hp" or type == "chi"):
				type = "crv" if p.has("crv") else "str"
		var ab: Array = Data.D.TRACK_LEN.get(type, [1, 2])
		var a := int(ab[0]); var b := int(ab[1])
		var len_: int
		if d.style == "drag": len_ = 1 if type == "lau" else 2
		else: len_ = a + int(floor(rng.next() * (b - a + 1)))
		secs.append({"type": type, "len": len_})
	var at := 0
	for s in secs:
		s.at = at
		at += s.len
	var lap_len := at
	var entries := []
	for k in d.surf: entries.append([k, d.surf[k]])
	var keyed := []
	for e in entries: keyed.append([e, rng.next()])
	keyed.sort_custom(func(x, y): return x[1] < y[1])
	var cum := 0.0
	var blocks := []
	for kv in keyed:
		var s0 := cum
		cum += float(kv[0][1])
		blocks.append([kv[0][0], s0, cum])
	for s in secs:
		var mid: float = (s.at + s.len / 2.0) / lap_len * cum
		var k: String = blocks[blocks.size() - 1][0]
		for bl in blocks:
			if mid >= bl[1] and mid < bl[2]:
				k = bl[0]
				break
		s.surf = "wet" if (wet and k == "tar") else k
	var laps := int(laps_override) if laps_override != null else int(d.laps)
	var out := {"secs": secs, "lapLen": lap_len, "laps": laps, "total": lap_len * laps, "p2p": bool(st.get("p2p", false)),
		"oval": d.style == "oval", "drag": d.style == "drag", "hill": d.style == "hill", "style": d.style}
	track_cache[key] = out
	return out

static func _pick_w(p: Dictionary, rng: URng) -> String:
	var tot := 0.0
	for k in p: tot += p[k]
	var r := rng.next() * tot
	for k in p:
		r -= p[k]
		if r <= 0: return k
	return p.keys()[0]

static func main_surf(track: Dictionary) -> String:
	var m := {}
	for s in track.secs: m[s.surf] = m.get(s.surf, 0) + s.len
	var best := ""; var bv := -1
	for k in m:
		if m[k] > bv: bv = m[k]; best = k
	return best

static func rival_terr(d: Dictionary) -> Dictionary:
	var b := 96 + 7 * int(d.tier)
	var t := {"on": b, "off": b, "wet": b - 6, "ice": b - 10}
	match d.disc:
		"CR", "BR", "DR": t.on += 28; t.wet += 10
		"CO": t.off += 26; t.ice += 22; t.wet += 8
		"BO": t.off += 28; t.ice += 10
		"HC": t.on += 22; t.off += 12; t.wet += 8; t.ice += 10
		_: t.on += 12; t.off += 12; t.wet += 8; t.ice += 8
	return t

static func rival_mul(m: String) -> float: return 0.94 if m == "easy" else 1.0

static func mk_rivals(d: Dictionary, n: int, rng: RandomNumberGenerator, exclude_teams := []) -> Array:
	var pool := []
	for r in Data.D.RIVALS:
		if not exclude_teams.has(r[0]): pool.append(r)
	pool.shuffle()
	var out := []
	for i in min(n, pool.size()):
		var r: Array = pool[i]
		out.append({"team": r[0], "col": r[1],
			"drv": "%s %s" % [Data.D.FIRST[rng.randi() % Data.D.FIRST.size()], Data.D.LAST[rng.randi() % Data.D.LAST.size()]],
			"f": 1.12 - 0.28 * i / max(1, n - 1) + rng.randf_range(-0.03, 0.03)})
	return out

static func default_rival_count(d: Dictionary) -> int:
	return [0, 5, 7, 9, 11, 11][int(d.tier)]

# ---------------- create ----------------
## humans: [{name, team, team_key, col, kind, cls, prof:{S,A,H,t,pm,mis,wear,dur}, sk:Array, hp, cond, cyl, owner, rt, sparks:{}}]
## opts: fmt, rivals(Array), n_rivals(int), rain(bool), test(bool), mode, seed
static func create(d: Dictionary, humans: Array, opts: Dictionary = {}) -> RaceSim:
	var rs := RaceSim.new()
	if opts.has("seed"): rs.rng.seed = int(opts.seed)
	else: rs.rng.randomize()
	rs.def = d
	rs.mode = opts.get("mode", "standard")
	rs.auto_retire = rs.mode != "sim"
	rs.test = bool(opts.get("test", false))
	var fm: Dictionary = opts.get("fmt", {})
	if fm.is_empty():
		fm = {"id": "sprint", "kind": "mass", "laps": d.laps, "mul": {"prize": 1, "rp": 1, "fans": 1, "wear": 1}}
	rs.fmt = fm
	if opts.has("rain"): rs.rain = bool(opts.rain)
	elif d.surf.has("tar") and not rs.test: rs.rain = rs.rng.randf() < 0.08
	var laps_o = fm.laps if int(fm.laps) != int(d.laps) else null
	rs.tr = build_track(d, rs.rain, laps_o)
	var n: int = opts.get("n_rivals", default_rival_count(d))
	var team_names := []
	for h in humans: team_names.append(h.team)
	var rivals: Array = opts.get("rivals", mk_rivals(d, n, rs.rng, team_names))
	var kinds: Array
	if d.disc == "OP":
		kinds = Data.D.KINDS.CR + Data.D.KINDS.CO + Data.D.KINDS.BR + Data.D.KINDS.BO
	else:
		kinds = Data.D.KINDS.get(d.disc, Data.D.KINDS.CR)
	var tier_k := kinds.slice(0, min(kinds.size(), 2 + int(d.tier) * 2))
	var tb := rival_terr(d)
	var rm := rival_mul(rs.mode)
	var R := float(d.R)
	var ai := []
	for r in rivals:
		var str_ := R * float(r.f) * rm
		var tt_ := {}
		for k in ["on", "off", "wet", "ice"]: tt_[k] = tb[k] + rs.rng.randf_range(-6, 8)
		var kind: String = r.get("kind", tier_k[rs.rng.randi() % tier_k.size()])
		ai.append({"human": false, "owner": 0, "name": r.drv, "team": r.team, "team_key": "ai:" + r.team, "col": r.col, "kind": kind,
			"S": str_ * rs.rng.randf_range(0.93, 1.07), "A": str_ * rs.rng.randf_range(0.93, 1.07), "H": str_ * rs.rng.randf_range(0.93, 1.07),
			"t": tt_, "pm": 1.0, "mis": 1.0, "dnfAt": (rs.rng.randf_range(0.2, 0.9) if (not rs.test and rs.rng.randf() < 0.03) else -1.0),
			"rt": rs.rng.randf_range(0.04, 0.2)})
	var hs := []
	for h in humans:
		var e := {"human": true, "owner": int(h.get("owner", 1)), "name": h.name, "team": h.team, "team_key": h.get("team_key", h.team),
			"col": h.col, "kind": h.kind, "cls": h.get("cls", "car"), "tactic": h.get("tactic", "normal"),
			"sparks": h.get("sparks", {"b": 2, "s": 1, "g": 0}).duplicate(), "hp": float(h.get("hp", 1.0)),
			"cond": float(h.get("cond", 1.0)), "cyl": int(h.get("cyl", 4)), "sk": h.get("sk", []), "rt": float(h.get("rt", 0.12)),
			"dnfAt": -1.0, "warn": {}, "critWarned": false, "lapT": [], "lapN": 0, "lastLapAt": 0.0, "lastPos": 0,
			"redlight": false}
		e.merge(h.prof, true)
		hs.append(e)
	rs.tt = fm.kind == "tt" or rs.test
	rs.drag = rs.tr.drag
	var grid := []
	if rs.drag:
		grid = hs + ai
	else:
		grid = ai.duplicate()
		grid.shuffle()
		for i in hs.size():
			var pi := 0 if rs.tt else int(floor(grid.size() * rs.rng.randf_range(0.35, 0.75)))
			if fm.kind == "duel": pi = i
			grid.insert(min(pi, grid.size()), hs[i])
	for i in grid.size():
		var e: Dictionary = grid[i]
		e.idx = i
		e.prog = 0.0 if (rs.tt or rs.drag) else -i * 0.18
		e.fin = false; e.dnf = false; e.finT = 0.0; e.slow = 0.0; e.boost = 0.0; e.secIdx = -1; e.noise = 1.0
		e.v = 0.0; e.air = 0.0; e.crash = 0.0; e.splits = [0.0, 0.0]; e.retired = false; e.destroyed = false
		e.lane = (i % 2) if rs.drag else (i % 3)
		if e.dnfAt > 0: e.dnfAt *= rs.tr.total
	rs.ents = grid
	rs.T0 = 9.0 if rs.drag else clampf(rs.tr.total * 0.8, 24, 90)
	rs.K = rs.tr.total / rs.T0
	rs.lap_factor = pow(rs.tr.laps, -0.35)
	rs.tree = 1.8 if rs.drag else 0.0
	rs.order = grid.duplicate()
	for i in grid.size():
		grid[i].pos = i + 1
		if grid[i].human: grid[i].lastPos = i + 1
	if rs.drag:
		rs.msg("Staging... watch the tree!")
		for e in hs:
			if rs.rng.randf() < {"safe": 0.005, "normal": 0.02, "push": 0.07}[e.tactic]: e.redlight = true
	elif rs.tt:
		rs.msg("Test session - out you go!" if rs.test else "Green light - on the clock!")
	else:
		rs.msg(["Lights out - and they're away!", "The flag drops! Here we go!", "And they're off!"][rs.rng.randi() % 3])
	return rs

# ---------------- helpers ----------------
func msg(text: String, key := "", gap := 1.5, ent := -1) -> void:
	if key != "":
		var k := key + ":" + str(ent)
		if msgT.has(k) and t - msgT[k] < gap: return
		msgT[k] = t
	msgs.append({"t": t, "text": text, "ent": ent, "n": msg_seq})
	msg_seq += 1
	if msgs.size() > 40: msgs.pop_front()

func sec_at(prog: float) -> int:
	var L: float = tr.lapLen
	var lp := fposmod(prog, L)
	var s: Array = tr.secs
	for i in range(s.size() - 1, -1, -1):
		if lp >= s[i].at: return i
	return 0

func pace(e: Dictionary, sec: Dictionary, idx: int) -> float:
	var w: Array = Data.D.SEC[sec.type].w
	var tk: String = Data.D.SURF[sec.surf].k
	if e.human and e.sk.size() > idx:
		var k: Dictionary = e.sk[idx]
		var p: float = ((w[0] * e.S * k.s + w[1] * e.A * k.a) * k.ef + w[2] * e.H * k.h) * (clampf(e.t[tk] * k.t, 5, 220) / 100.0) * e.pm
		if e.get("fouled", false): p *= 1.0 - 0.55 / max(1, e.cyl)
		return p
	return (w[0] * e.S + w[1] * e.A + w[2] * e.H) * (clampf(e.t[tk], 5, 220) / 100.0) * e.pm

func label(e: Dictionary, viewer: Dictionary = {}) -> String:
	if not viewer.is_empty() and e.idx == viewer.idx: return "You"
	return e.name.split(" ")[0] + " (" + e.team + ")" if e.human else e.team

func humans() -> Array:
	return ents.filter(func(e): return e.human)

func tac(e: Dictionary) -> Dictionary:
	return Data.D.TAC[e.get("tactic", "normal")] if e.human else Data.D.TAC.normal

# ---------------- commands (race calls) ----------------
func set_tactic(idx: int, tactic: String) -> void:
	if idx < 0 or idx >= ents.size() or not Data.D.TAC.has(tactic): return
	var e: Dictionary = ents[idx]
	if not e.human or e.fin or e.dnf: return
	e.tactic = tactic
	msg("Crew: %s pace" % Data.D.TAC[tactic].n, "tac", 0.5, idx)

func use_spark(idx: int, kind: String) -> bool:
	if idx < 0 or idx >= ents.size(): return false
	var e: Dictionary = ents[idx]
	if not e.human or e.fin or e.dnf or e.boost > 0: return false
	if int(e.sparks.get(kind, 0)) <= 0: return false
	e.sparks[kind] -= 1
	e.boost = BOOST[kind]
	e.slow = 0.0
	msg("Spark! Pushing to the limit!", "", 0, idx)
	for o in humans():
		if o.idx != e.idx: msg("%s fires a spark!" % e.name.split(" ")[0], "", 0, o.idx)
	return true

func retire(idx: int) -> void:
	var e: Dictionary = ents[idx]
	if not e.human or e.fin or e.dnf: return
	e.dnf = true; e.retired = true
	msg("You retire from the race.", "", 0, idx)

# ---------------- step ----------------
func step(dt: float) -> void:
	if done: return
	t += dt
	var R := float(def.R)
	if drag and not green_said and t >= tree:
		green_said = true
		msg("GREEN!")
		for e in ents:
			if e.human and e.redlight:
				e.dnf = true
				msg("RED LIGHT! Jumped the start!", "", 0, e.idx)
	for e in ents:
		if e.fin or e.dnf: continue
		if drag and t < tree + e.rt: continue
		var idx := sec_at(max(0.0, e.prog))
		var sec: Dictionary = tr.secs[idx]
		if idx != e.secIdx:
			var prev: int = e.secIdx
			if e.human and e.sk.size() > 0 and prev >= 0:
				var pk: Dictionary = e.sk[prev]
				if pk.starve and tr.secs[prev].type == "jmp" and not e.warn.has("starve"):
					e.warn.starve = 1; e.slow = 0.6; e.cond -= 0.01
					msg("Fuel starvation on landing! (float level too low)", "", 0, e.idx)
			e.secIdx = idx
			e.noise = rng.randf_range(0.965, 1.035)
			if e.human and sec.type == "jmp" and rng.randf() < 0.3:
				msg(["Huge air!", "Sends it over the jump!", "Look at that hang time!"][rng.randi() % 3], "jmp", 4, e.idx)
			if e.human and e.sk.size() > idx and e.sk[idx].flood and not e.warn.has("flood"):
				e.warn.flood = 1; e.slow = 0.35
				msg("Floods over the whoops - fuel level too high!", "", 0, e.idx)
		var p: float = pace(e, sec, idx) * e.noise
		var tc := tac(e)
		if e.human: p *= tc.pace
		if e.boost > 0: p *= 1.2; e.boost -= dt
		if e.slow > 0: p *= 0.35; e.slow -= dt
		var v: float = max(0.05, p / R * K)
		e.v = v
		var dp := v * dt
		e.prog += dp
		if sec.type == "jmp": e.air = (fposmod(e.prog, tr.lapLen) - sec.at) / sec.len
		else: e.air = 0.0
		if e.crash > 0: e.crash = max(0.0, e.crash - dt)
		if e.human:
			var ln := int(floor(max(0.0, e.prog) / tr.lapLen))
			if ln > e.lapN:
				e.lapT.append(t - e.lastLapAt); e.lastLapAt = t; e.lapN = ln
		# splits (time trials)
		if tt:
			var k := int(floor(e.prog / tr.total * 3))
			if k >= 1 and k <= 2 and e.splits[k - 1] == 0.0:
				e.splits[k - 1] = t
				if e.human and not test:
					var best := INF
					for x in ents:
						if x.idx != e.idx and x.splits[k - 1] > 0: best = min(best, x.splits[k - 1])
					if best < INF:
						var dd := t - best
						msg("Split %d: %s%.2fs" % [k, "-" if dd <= 0 else "+", absf(dd)], "", 0, e.idx)
					else:
						msg("Split %d: fastest so far!" % k, "", 0, e.idx)
		# mistakes
		if e.slow <= 0 and e.boost <= 0 and e.prog > 0:
			var tk: String = Data.D.SURF[sec.surf].k
			var hr: float = e.H * (clampf(e.t[tk], 5, 220) / 100.0) / R
			var pm: float = Data.D.SEC[sec.type].risk * Data.D.SURF[sec.surf].risk * clampf(1.7 - hr * 0.7, 0.35, 1.8) * e.mis * (tc.mis if e.human else 1.0)
			if rng.randf() < pm * dt: mistake(e, sec)
		# damage & engine (humans)
		if e.human:
			var d: float = R * 0.012 * Data.D.SEC[sec.type].dmg * Data.D.SURF[sec.surf].dmg * tc.dmg * e.wear * lap_factor
			e.hp -= d * dp / e.dur
			if not e.critWarned and e.hp < 0.3:
				e.critWarned = true
				msg("Durability critical!", "", 0, e.idx)
			if e.sk.size() > idx:
				var k2: Dictionary = e.sk[idx]
				var kd: float = k2.kd
				var lh: float = k2.lh
				if e.tactic == "safe": kd = max(0.0, kd - 1.5)
				if kd > 0 or lh > 0:
					var rate := (0.004 * pow(kd, 1.4) + 0.006 * pow(lh, 1.2)) * (1.3 if e.tactic == "push" else 0.6 if e.tactic == "safe" else 1.0)
					e.cond -= rate * dt
					if kd > 0.3 and not e.warn.has("knock"):
						e.warn.knock = 1; msg("Ping... ping..." if mode == "sim" else "Pinging under load! (try Safe)", "", 0, e.idx)
					if lh > 0.5 and not e.warn.has("lean"):
						e.warn.lean = 1; msg("Something smells hot..." if mode == "sim" else "Running lean and hot!", "", 0, e.idx)
				if not e.dnf and e.cond <= 0.1 and auto_retire:
					e.dnf = true; e.retired = true; msg("Crew calls it in - saving the engine.", "", 0, e.idx)
				elif not e.dnf and e.cond <= 0:
					e.cond = 0.0; e.dnf = true; e.holed = true; msg("BANG! Holed a piston!", "", 0, e.idx)
			if not e.dnf and e.hp <= 0.08 and auto_retire:
				e.dnf = true; e.retired = true; msg("Your crew calls it in - retired to save the machine.", "", 0, e.idx)
			elif not e.dnf and e.hp <= 0:
				e.hp = 0.0; e.dnf = true; e.destroyed = true; msg("The machine is wrecked!", "", 0, e.idx)
		elif e.dnfAt > 0 and e.prog >= e.dnfAt:
			e.dnf = true
			if not tt: msg("%s pulls off - mechanical failure!" % e.team)
		if not e.dnf and e.prog >= tr.total:
			e.fin = true
			e.finT = t - (e.prog - tr.total) / v
			if e.human:
				var pos := 0
				for x in ents:
					if x.fin and x.finT <= e.finT: pos += 1
				if drag:
					e.et = et_of(e)
					msg("%.3fs @ %d mph" % [e.et.et, e.et.mph], "", 0, e.idx)
				elif test: msg("Session complete.", "", 0, e.idx)
				else: msg("YOU WIN!!" if pos == 1 else "You cross the line %s!" % ordinal(pos), "", 0, e.idx)
				for o in humans():
					if o.idx != e.idx and not drag and not test:
						msg("%s finishes %s" % [e.name.split(" ")[0], ordinal(pos)], "", 0, o.idx)
			else:
				var nf := 0
				for x in ents: if x.fin: nf += 1
				if nf == 1 and not tt: msg("%s takes the checkered flag!" % e.team)
	order = ents.duplicate()
	order.sort_custom(_cmp_order)
	for i in order.size(): order[i].pos = i + 1
	var L: Dictionary = order[0]
	if not tt and not drag and L.idx != last_leader and t > 1.5:
		msg("%s takes the lead!" % label(L), "lead", 2)
	last_leader = L.idx
	for e in humans():
		var pos: int = e.pos
		if not tt and not drag and not e.fin and not e.dnf and t > 1.5 and pos != e.lastPos:
			if pos < e.lastPos: msg("You pass %s! Up to P%d" % [label(order[pos], e), pos], "pos", 1.2, e.idx)
			else: msg("%s gets by... P%d" % [label(order[pos - 2], e), pos], "pos", 1.2, e.idx)
			e.lastPos = pos
	if not final_lap and tr.laps > 1 and not tr.p2p and L.prog >= tr.lapLen * (tr.laps - 1):
		final_lap = true; msg("Final lap!")
	if not final_lap and tr.laps > 1 and tr.p2p:
		for e in humans():
			if e.prog >= tr.lapLen * (tr.laps - 1): final_lap = true; msg("Final stage!"); break
	var hs := humans()
	var all_done := hs.size() > 0
	for e in hs:
		if not (e.fin or e.dnf): all_done = false
	if hs.is_empty() and not ents.any(func(e): return not e.fin and not e.dnf): done = true
	if all_done and end_t < 0: end_t = t
	if not finishing and end_t >= 0 and t - end_t > 1.6: finish_all()

func _cmp_order(a: Dictionary, b: Dictionary) -> bool:
	if a.dnf != b.dnf: return not a.dnf
	if a.fin and b.fin: return a.finT < b.finT
	if a.fin != b.fin: return a.fin
	return a.prog > b.prog

func et_of(e: Dictionary) -> Dictionary:
	var tier := int(def.tier)
	var ref: float = [0, 14.2, 12.0, 10.2, 8.4, 7.0][tier] if tier <= 5 else 10.0
	var mph0: float = [0, 96, 116, 138, 165, 190][tier] if tier <= 5 else 120.0
	var tb := rival_terr(def)
	var tref: float = T0 / (tb.on / 100.0) / rival_mul(mode)
	var el: float = e.finT - tree - e.rt
	return {"et": snappedf(ref * el / tref, 0.001), "rt": snappedf(e.rt, 0.001), "mph": int(round(mph0 * pow(tref / el, 0.8)))}

func mistake(e: Dictionary, sec: Dictionary) -> void:
	var big: bool = (sec.type == "jmp" or sec.type == "rgh") and rng.randf() < 0.18 * (tac(e).mis if e.human else 1.0)
	e.slow = rng.randf_range(1.8, 2.6) if big else rng.randf_range(0.7, 1.4)
	e.crash = 1.2 if big else 0.6
	var sn: String = Data.D.SURF[sec.surf].n.to_lower()
	if sec.type == "lau":
		if e.human: msg(["Big wheelspin off the line!", "Wheelie on launch!", "Bogged the launch!"][rng.randi() % 3], "", 0, e.idx)
		e.slow = rng.randf_range(0.3, 0.6)
		return
	if e.human:
		e.hp -= 0.12 if big else 0.03
		var small := ["Slides wide on the %s!" % sn, "Locks up into the %s!" % Data.D.SEC[sec.type].n.to_lower(), "Little moment there on the %s" % sn, "Fumbles a shift!"]
		var bigm := ["Hard landing! That hurt!", "Big crash - but back on it!", "Cartwheel! Somehow still going!"]
		msg((bigm if big else small)[rng.randi() % (3 if big else 4)], "pm", 1, e.idx)
	else:
		if big and rng.randf() < 0.12:
			e.dnf = true
			if not tt: msg("%s crashes out!" % e.team)
			return
		var oi: int = e.get("pos", 99) - 1
		if oi < 3 and not tt:
			msg("%s %s on the %s!" % [e.team, ["spins", "runs wide", "gets crossed up", "overshoots"][rng.randi() % 4], sn], "rm", 2)

func finish_all() -> void:
	finishing = true
	var guard := 0
	while ents.any(func(e): return not e.fin and not e.dnf) and guard < 6000:
		var n := msgs.size()
		step(0.1)
		while msgs.size() > n + 3: msgs.pop_back()
		guard += 1
	done = true

func run_instant() -> void:
	finishing = true
	var g := 0
	while ents.any(func(e): return not e.fin and not e.dnf) and g < 20000:
		step(0.1)
		g += 1
	done = true

# ---------------- results ----------------
## Final classification: [{idx, pos, name, team, team_key, human, owner, finT, dnf, pts}]
func results() -> Array:
	var out := []
	var pts_tab: Array = Data.D.POINTS
	var i := 0
	for e in order:
		i += 1
		var pts: int = 0 if e.dnf else (pts_tab[i - 1] if i <= pts_tab.size() else 0)
		out.append({"idx": e.idx, "pos": i, "name": e.name, "team": e.team, "team_key": e.team_key, "human": e.human,
			"owner": e.get("owner", 0), "finT": e.finT, "dnf": e.dnf, "pts": pts, "et": e.get("et", {}), "lapT": e.get("lapT", [])})
	return out

## Team totals (co-op "team vs the world"): {team_key: pts}, sorted desc as Array of [key, team, pts]
func team_table() -> Array:
	var m := {}
	var names := {}
	for r in results():
		m[r.team_key] = m.get(r.team_key, 0) + r.pts
		names[r.team_key] = r.team
	var arr := []
	for k in m: arr.append([k, names[k], m[k]])
	arr.sort_custom(func(a, b): return a[2] > b[2])
	return arr

static func ordinal(n: int) -> String:
	var s := ["th", "st", "nd", "rd"]
	var v := n % 100
	var i := (v - 20) % 10
	if i >= 1 and i <= 3: return str(n) + s[i]
	if v >= 1 and v <= 3: return str(n) + s[v]
	return str(n) + "th"
