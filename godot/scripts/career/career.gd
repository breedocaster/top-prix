extends Node
## Career engine: port of web/src/engine.js + build.js (the web `E` object) plus the engine-side
## parts of race.js / ui*.js (career race entries, format flows, bench actions).
## `G` is the game state with exactly the web save shape (the JSON of `E.serialize()`).
## Function names keep the JS camelCase so UI code can mirror web/src/ui*.js call for call.
## Web hooks (E.H.*) are signals; see godot/PORTING.md.

signal toast(text: String)
signal popup(data: Dictionary)            ## {title, text, kind, ...} (web: {title, html})
signal floaty(text: String, vid, color: String)
signal sfx(name: String)
signal round_due(series_id: String)
signal year_end(summary: Dictionary)      ## {y, yr, bonus, rank}
signal game_end()
signal refresh()
signal build_ask(job: Dictionary)         ## answer with bChoose(job.vid, idx or "crew"); unconnected -> crew decides
# story layer
signal race_finished(info: Dictionary)    ## {race_id, fmt_id, pos, field, dnf, prize, series_id}
signal title_won(series_id: String)
signal workshop_up(level: int)
signal research_done(tech_id: String)     ## tech ids; body/layout/part research emits "body:<id>" etc.
signal vehicle_built(vid: int)
signal staff_hired(sid: int)
signal sponsor_signed(id: String)
signal day_passed(day: int)

var G: Dictionary = {}
var D: Dictionary = {}
var DAYS_MONTH := 28
var DAYS_YEAR := 336
var YEARS := 15
const STATS := ["spd", "acc", "hnd", "dur"]
const TERRS := ["on", "off", "wet", "ice"]
const SPARK_N := {"b": "Bronze", "s": "Silver", "g": "Gold"}
const SPARK_MUL := {"b": 1.5, "s": 2.0, "g": 3.0}
const FF := [1, .75, .6, .45, .38, .32, .28, .24, .2, .18, .16, .15]
const RIVAL_N := [0, 5, 7, 10, 13, 15]   # bigger grids as you climb the tiers
const EVENT_W := [3, 3, 2, 2, 1, 2, 2, 1, 2, 1, 1]

func _init() -> void:
	_bind_data()

func _ready() -> void:
	_bind_data()

func _bind_data() -> void:
	if D.is_empty() and Data != null and not Data.D.is_empty():
		D = Data.D
		DAYS_MONTH = int(D.DAYS_MONTH); DAYS_YEAR = int(D.DAYS_YEAR); YEARS = int(D.YEARS)

# ======================================================================
# helpers
# ======================================================================
func ws() -> Dictionary: return D.WORKSHOPS[int(G.ws)]
func drivers() -> Array: return G.staff.filter(func(s): return s.role == "drv")
func mechs() -> Array: return G.staff.filter(func(s): return s.role == "mec")
func staff(id) -> Dictionary:
	if id == null: return {}
	for s in G.staff:
		if s.id == id: return s
	return {}
func veh(id) -> Dictionary:
	if id == null: return {}
	for v in G.vehicles:
		if v.id == id: return v
	return {}
func nid() -> int:
	var n := int(G.nid)
	G.nid = n + 1
	return n
func year(d = null) -> int: return int(floor(float(G.day if d == null else d) / DAYS_YEAR)) + 1
func dateStr(d = null) -> String:
	var dd := int(G.day if d == null else d)
	var y := year(dd)
	var m := int(floor(float(dd % DAYS_YEAR) / DAYS_MONTH))
	var w := int(floor(float(dd % DAYS_MONTH) / 7)) + 1
	return "Y%d %s W%d" % [y, D.MONTHS[m], w]
func facV(fx: String) -> float:
	for f in G.fac:
		if f == null: continue
		var F: Dictionary = D.FAC[f.id]
		if F.fx == fx: return float(F.v[int(f.lv) - 1])
	return 0.0
func facLv(id: String) -> int:
	for f in G.fac:
		if f != null and f.id == id: return int(f.lv)
	return 0
func teamTech() -> float:
	return U.sum(mechs(), func(s): return s.tech) + 0.5 * U.sum(drivers(), func(s): return s.tech)
func fanRank(f = null) -> int:
	var fans: float = float(G.fans if f == null else f)
	var r := 0
	for i in D.FAN_RANKS.size():
		if fans >= float(D.FAN_RANKS[i][0]): r = i
	return r
func fanRankName() -> String: return D.FAN_RANKS[fanRank()][1]
## E.log (named addLog in GDScript, where log() is the math builtin).
func addLog(t: String) -> void:
	G.log.push_front({"d": G.day, "t": t})
	if G.log.size() > 40: G.log.resize(40)
func say(t: String) -> void:
	addLog(t)
	toast.emit(t)
func bays() -> int: return int(ws().teams) + 1
## Team size grows with the workshop and, within it, with fame: +1 mechanic per fan rank (max +4),
## +1 driver at ranks 2 and 4.
func drvCap() -> int: return int(ws().teams) + 1 + (1 if fanRank() >= 2 else 0) + (1 if fanRank() >= 4 else 0)
func mechCap() -> int: return int(ws().mech) + mini(4, fanRank())
## Cars the team may enter in one race: two from the start, three from the third workshop.
func entryCap() -> int: return 2 + (1 if int(G.ws) >= 3 else 0)
## Formats a team can enter several cars in (the drag ladder is a two-lane, one-car-per-team affair).
func multiEntryOk(fmt: Dictionary) -> bool: return str(fmt.get("kind", "mass")) != "drag"
func titlesIn(tier = null, disc = null) -> int:
	var n := 0
	for t in G.st.titles:
		var S = D.SER.get(t)
		if S != null and (tier == null or int(S.tier) == int(tier)) and (disc == null or S.disc == disc): n += 1
	return n
func wkey(k: String) -> void: G.st.wc[k] = int(G.st.wc.get(k, 0)) + 1
func _float(text: String, vid, col: String) -> void: floaty.emit(text, vid, col)
func _popup(title: String, text: String, kind := "", extra := {}) -> void:
	var d := {"title": title, "text": text, "kind": kind}
	d.merge(extra)
	popup.emit(d)

# ======================================================================
# staff generation
# ======================================================================
func genStaff(role: String, q: float) -> Dictionary:
	var base := 8 + q * 13
	var s := {"id": nid(), "role": role, "name": str(U.pick(D.FIRST)) + " " + str(U.pick(D.LAST)), "hair": U.pick(D.HAIR), "skin": U.pick(D.SKIN),
		"appeal": _sr(base, 0.8), "tech": _sr(base, 1.35 if role == "mec" else 0.7), "analysis": _sr(base, 1.0 if role == "mec" else 0.7),
		"lv": 1, "joined": G.day if not G.is_empty() else 0}
	if role == "drv":
		s.pedal = _sr(base, 1.15); s.shift = _sr(base, 1.15); s.steer = _sr(base, 1.15); s.energy = 100; s.maxE = 100
		var c := U.rand(0.86, 1.16)
		s.aff = {"car": U.fixed(c, 2), "bike": U.fixed(U.clamp(2.02 - c + U.rand(-0.08, 0.08), 0.84, 1.18), 2)}
		s.trait = U.pick(D.TRAITS.keys()) if U.chance(0.45) else null
	var avg: float
	if role == "drv": avg = (float(s.pedal) + s.shift + s.steer + s.appeal + s.tech + s.analysis) / 6
	else: avg = (float(s.appeal) + s.tech + s.analysis) / 3
	s.salary = int(U.round(avg * 0.22 + 2 + (2 if role == "drv" else 0))) * 1000
	return s

func _sr(base: float, m: float) -> int: return int(max(1.0, U.round(base * m * U.rand(0.6, 1.4))))

func refreshCandidates() -> void:
	var q := fanRank() + facV("scout") + float(G.ws) * 0.5
	G.cand = []
	for i in 5:
		var role: String = "drv" if i < 2 else ("mec" if i < 4 else U.pick(["drv", "mec"]))
		G.cand.append(genStaff(role, U.clamp(q + U.rand(-1, 1.2), 0, 12)))

func scoutCost() -> int: return int(U.round(10000 * (1 + fanRank())))
func scout() -> bool:
	var c := scoutCost()
	if G.money < c: return false
	G.money -= c
	refreshCandidates()
	return true

# ======================================================================
# new game
# ======================================================================
func newGame(name := "", color := "", mode := "") -> Dictionary:
	_bind_data()
	G = {"v": 1, "team": {"name": name if name != "" else "Team Hoosier", "color": color if color != "" else D.TEAM_COLORS[0]}, "day": 0, "money": 420000, "rp": 40, "fans": 0, "ws": 1,
		"staff": [], "vehicles": [], "jobs": [],
		"res": {"body": {}, "layout": {}, "part": {}}, "unl": {"body": {}, "layout": {}, "part": {}, "train": {}, "fac": {}},
		"partLv": {}, "races": {}, "series": {}, "spons": [], "sponDone": {}, "fac": [], "sparks": {"b": 1, "s": 0, "g": 0},
		"st": {"races": 0, "wins": 0, "podiums": 0, "dnf": 0, "titles": [], "earn": 0, "wc": {}},
		"cand": [], "settings": {"speed": 1, "autoRetire": true, "sound": true}, "log": [], "nid": 1, "yearWins": {},
		"lazy": {}, "ended": false, "tut": 0, "lastSave": 0, "wxRain": false, "year": {"wins": 0, "podiums": 0, "earn": 0, "titles": 0}, "tech": {"carbbasic": 1}, "ach": {}}
	G.settings.mode = mode if mode != "" else "standard"
	G.st.tests = 0; G.st.streak = 0; G.st.cells = 0
	for b in D.BODIES:
		if b.un == "S": G.res.body[b.id] = 1
	for l in D.LAYOUTS:
		if l.un == "S": G.res.layout[l.id] = 1
	var d := genStaff("drv", 1.2)
	d.pedal += 4; d.shift += 4; d.steer += 4
	G.staff.append(d)
	G.staff.append(genStaff("mec", 1.4))
	G.staff.append(genStaff("mec", 1.0))
	refreshCandidates()
	addLog("Welcome to the paddock! Build your first vehicle.")
	refresh.emit()
	return G

# ======================================================================
# availability / research
# ======================================================================
func bodyAvail(id: String) -> Dictionary:
	var b: Dictionary = D.BODY[id]
	if G.res.body.get(id): return {"ok": true, "done": true}
	if b.un == "sp": return {"ok": true} if G.unl.body.get(id) else {"ok": false, "why": "Sponsor reward"}
	var w := int(D.RANK_WS[b.rank])
	return {"ok": true} if int(G.ws) >= w else {"ok": false, "why": "Needs " + D.WORKSHOPS[w].n}
func layoutAvail(id: String) -> Dictionary:
	var l: Dictionary = D.LAYOUT[id]
	if G.res.layout.get(id): return {"ok": true, "done": true}
	if l.un == "sp": return {"ok": true} if G.unl.layout.get(id) else {"ok": false, "why": "Sponsor reward"}
	return {"ok": true}
func partAvail(id: String) -> Dictionary:
	var p: Dictionary = D.PART[id]
	if G.res.part.get(id): return {"ok": true, "done": true}
	if p.un == "sp": return {"ok": true} if G.unl.part.get(id) else {"ok": false, "why": "Sponsor reward"}
	var w := int(D.PART_TIER_WS[int(p.tier)])
	return {"ok": true} if int(G.ws) >= w else {"ok": false, "why": "Needs " + D.WORKSHOPS[w].n}
func research(kind: String, id: String) -> bool:
	var tab: Dictionary = {"body": D.BODY, "layout": D.LAYOUT, "part": D.PART}[kind]
	var src: Dictionary = tab[id]
	var av: Dictionary = bodyAvail(id) if kind == "body" else (layoutAvail(id) if kind == "layout" else partAvail(id))
	if not av.ok or av.get("done", false): return false
	if G.rp < src.rp: toast.emit("Not enough research data"); return false
	G.rp -= src.rp
	G.res[kind][id] = 1
	say("Researched %s!" % src.n)
	sfx.emit("good")
	research_done.emit(kind + ":" + id)
	return true

# ======================================================================
# vehicles
# ======================================================================
func partClsOk(p: Dictionary, cls: String) -> bool:
	return p.cls == "A" or (p.cls == "C" and cls == "car") or (p.cls == "B" and cls == "bike")
func partLv(pid: String) -> int: return int(G.partLv.get(pid, {"lv": 1}).lv)
## E.vs: effective stats with parts and level.
func vs(v: Dictionary) -> Dictionary: return Prof.vs(v, G)
func sysCost(bid: String, lid: String, sys) -> int:
	if not (sys is Dictionary) or sys.is_empty() or int(D.LAYOUT_CYL.get(lid, 4)) == 0: return 0
	var b: Dictionary = D.BODY[bid]
	if sys.get("type") == "efi": return Tune.efiCost(b)
	var def := Tune.defaultCarb(b.cls, lid)
	return Tune.carbSwapCost(b, sys.carb) if (sys.get("carb") and sys.carb != def) else 0
func vehCost(bid: String, lid: String) -> int:
	return int(U.round(float(D.BODY[bid].cost) * (1 + float(D.LAYOUT[lid].cm)) / 1000) * 1000)
func buildQ(bid: String) -> float: return U.clamp(teamTech() / float(D.RANK_REQ[D.BODY[bid].rank]), 0.45, 1.6)
func qMult(q: float) -> float: return 0.72 + 0.28 * q
func activeJobs() -> int: return G.jobs.size()
func canStartJob() -> bool:
	if G.jobs.size() >= bays(): toast.emit("All work bays busy!"); return false
	return true

## Staged build (build.js override). Returns the new vehicle, or {} when it can't start.
func startBuild(bid: String, lid: String, spark = null, sys = null) -> Dictionary:
	var v := _startBuildBase(bid, lid, spark, sys)
	if v.is_empty(): return v
	var j := bJob(v.id)
	var days := int(U.round(float(D.BODY[bid].days) * float(D.BUILD_MULT)))
	var per := days / 8.0
	var pd := []
	for i in 8: pd.append(per)
	j.pd = pd; j.pi = 0; j.total = days; j.left = days; j.evN = 0; j.evs = []; j.plen = per
	v.bm = {"spd": 0, "acc": 0, "hnd": 0, "dur": 0, "on": 0, "off": 0, "wet": 0, "ice": 0, "adv": 0}
	v.blog = []; v.bflags = []
	bWaitNext(j, v)
	return v

func _startBuildBase(bid: String, lid: String, spark, sys) -> Dictionary:
	if not D.BODY.has(bid) or not D.LAYOUT.has(lid): return {}
	var b: Dictionary = D.BODY[bid]
	var L: Dictionary = D.LAYOUT[lid]
	if not G.res.body.get(bid) or not G.res.layout.get(lid) or L.cls != b.cls: return {}
	if G.vehicles.size() >= int(ws().veh): toast.emit("Garage is full! Sell or scrap a vehicle."); return {}
	if not canStartJob(): return {}
	var cost := vehCost(bid, lid) + sysCost(bid, lid, sys)
	if G.money < cost: toast.emit("Not enough money"); return {}
	if sys is Dictionary and sys.get("type") == "efi" and not Tune.has("efi"): return {}
	if sys is Dictionary and sys.get("carb") and not Tune.carbAvail(sys.carb): return {}
	if spark and not useSpark(spark): return {}
	G.money -= cost
	var sb: float = {"b": 0.1, "s": 0.2, "g": 0.3}[spark] if spark else 0.0
	var n := 1
	for x in G.vehicles:
		if x.body == bid: n += 1
	var v := {"id": nid(), "body": bid, "layout": lid, "name": "%s #%d" % [b.n, n], "q": buildQ(bid) + sb, "phase": {"spd": 0, "acc": 0, "hnd": 0, "dur": 0},
		"base": {"spd": 0, "acc": 0, "hnd": 0, "dur": 0}, "terr": b.t.duplicate(), "upAdd": {"spd": 0, "acc": 0, "hnd": 0, "dur": 0}, "up": {"spd": 0, "acc": 0, "hnd": 0, "dur": 0},
		"parts": [], "lv": 1, "xp": 0, "hp": 1, "status": "build", "races": 0, "wins": 0, "cost": cost}
	Tune.initEng(v, sys)
	v.setup = Tune.defaultSetup(v)
	G.vehicles.append(v)
	G.jobs.append({"id": nid(), "type": "build", "vid": v.id, "left": b.days, "total": b.days, "req": D.RANK_REQ[b.rank], "ph": 0})
	say("Started building %s (%s)" % [v.name, L.n])
	sfx.emit("click")
	return v

## Staged finish (build.js override) + E.finishBuild.
func finishBuild(v: Dictionary) -> void:
	var fl: Array = v.get("bflags", [])
	if fl.has("full"):
		var bm0 = v.get("bm")
		var worst: String = U.sort_by(STATS, func(k): return float(v.phase[k]) + (float(bm0[k]) if bm0 != null else 0.0) / 100)[0]
		if v.phase[worst] < 0: v.phase[worst] = 0
		elif bm0 != null: bm0[worst] += 3
	_finishBuildBase(v)
	var bm = v.get("bm")
	if bm != null:
		for k in STATS: v.base[k] = U.round(float(v.base[k]) * (1 + float(bm[k]) / 100))
		for k in TERRS: v.terr[k] += bm[k]
		v.advB = bm.adv
	if fl.has("dyno") and v.get("eng") != null and v.eng.fuel != "none":
		if v.eng.fuel == "efi": Tune.initEFI(v)
		Tune.crewTune(v, Tune.SHOP(), 0.98)
	vehicle_built.emit(int(v.id))

func _finishBuildBase(v: Dictionary) -> void:
	var b: Dictionary = D.BODY[v.body]
	var L: Dictionary = D.LAYOUT[v.layout]
	var qm := qMult(float(v.q))
	var fb := {"spd": facV("bSpd"), "acc": facV("bAcc"), "hnd": facV("bHnd"), "dur": facV("bDur")}
	for k in STATS:
		v.base[k] = U.round(float(b.s[k]) * qm * (1 + float(L.m.get(k, 0)) / 100) * (1 + float(v.phase[k])) * (1 + fb[k] / 100))
	var ft := {"on": facV("tOn"), "off": facV("tOff"), "wet": facV("tWet"), "ice": facV("tIce")}
	for k in TERRS: v.terr[k] = float(b.t[k]) + float(L.t.get(k, 0)) + ft[k]
	v.status = "ready"; v.hp = 1
	ach("build1")
	if v.get("eng") != null and v.eng.fuel == "efi":
		Tune.initEFI(v); ach("efi1")
	say("%s is complete!" % v.name)
	sfx.emit("fanfare")
	_float("Complete!", v.id, "#ffe066")

func buildPhase(v: Dictionary, _job: Dictionary) -> void:
	var r := U.random() + (float(v.q) - 1) * 0.35
	var k: String = U.pick(STATS)
	var txt: String; var amt: float; var col: String
	if r > 0.86: txt = "Eureka!"; amt = 0.08; col = "#ffe066"
	elif r > 0.55: txt = U.pick(["Smooth!", "Nice fit!", "Clean welds!"]); amt = 0.04; col = "#9ff"
	elif r > 0.2: txt = U.pick(["Steady...", "Hmm, okay.", "Tightening up"]); amt = 0.01; col = "#ddd"
	else: txt = U.pick(["Oops!", "Stripped a bolt!", "Wrong part!"]); amt = -0.03; col = "#f88"
	v.phase[k] += amt
	_float(txt, v.id, col)

func upCost(v: Dictionary, k: String) -> int:
	return int(U.round(float(D.BODY[v.body].cost) * 0.12 * pow(float(v.up[k]) + 1, 1.35) / 1000) * 1000)
func startUpgrade(vid, k: String, spark = null) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status != "ready": return false
	if int(v.up[k]) >= 5: return false
	if not canStartJob(): return false
	var c := upCost(v, k)
	if G.money < c: toast.emit("Not enough money"); return false
	if spark and not useSpark(spark): return false
	G.money -= c
	v.status = "upgrade"
	var days := 4 + 2 * int(v.up[k])
	G.jobs.append({"id": nid(), "type": "up", "vid": vid, "k": k, "left": days, "total": days, "req": D.RANK_REQ[D.BODY[v.body].rank], "spark": spark if spark else null})
	say("Upgrading %s: %s" % [v.name, k.to_upper()])
	sfx.emit("click")
	return true
func finishUpgrade(v: Dictionary, job: Dictionary) -> void:
	var b: Dictionary = D.BODY[v.body]
	var k: String = job.k
	var q := U.clamp(teamTech() / float(job.req), 0.45, 1.6)
	var fb: float = {"spd": facV("bSpd"), "acc": facV("bAcc"), "hnd": facV("bHnd"), "dur": facV("bDur")}[k]
	var sm: float = SPARK_MUL[job.spark] if job.get("spark") else 1.0
	var gain := int(max(1.0, U.round((float(b.s[k]) * 0.085 + 3) * (0.8 + 0.25 * q) * (1 + fb / 100) * sm * U.rand(0.9, 1.15))))
	v.upAdd[k] += gain; v.up[k] += 1; v.status = "ready"
	say("%s: %s +%d" % [v.name, k.to_upper(), gain])
	_float("%s +%d" % [k.to_upper(), gain], v.id, "#7f7")
	sfx.emit("good")
func partCost(pid: String) -> int: return int(U.round(float(D.PART[pid].cost) * (1 - facV("partdisc") / 100) / 1000) * 1000)
func installPart(vid, pid: String) -> bool:
	var v := veh(vid)
	if v.is_empty() or not D.PART.has(pid): return false
	var P: Dictionary = D.PART[pid]
	var b: Dictionary = D.BODY[v.body]
	if not G.res.part.get(pid) or not partClsOk(P, b.cls): return false
	if v.status == "build": toast.emit("Still being built"); return false
	if v.parts.has(pid): return false
	var same = null
	for x in v.parts:
		if D.PART[x].cat == P.cat: same = x; break
	if same == null and v.parts.size() >= slots(v): toast.emit("No free part slots"); return false
	var c := partCost(pid)
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	if same != null: v.parts = v.parts.filter(func(x): return x != same)
	v.parts.append(pid)
	say("Installed %s on %s" % [P.n, v.name])
	_float(P.n, v.id, "#9cf")
	sfx.emit("good")
	return true
func removePart(vid, pid: String) -> void:
	var v := veh(vid)
	if v.is_empty(): return
	v.parts = v.parts.filter(func(x): return x != pid)
func rushCost(v: Dictionary) -> int: return int(U.round((1 - float(v.hp)) * float(D.BODY[v.body].cost) * 0.3 / 1000 + 1) * 1000)
func rushRepair(vid) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status != "repair": return false
	var c := rushCost(v)
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	G.jobs = G.jobs.filter(func(j): return j.vid != vid)
	v.hp = 1; v.status = "ready"
	say("%s rush-repaired" % v.name)
	sfx.emit("good")
	return true
func sellValue(v: Dictionary) -> int:
	return int(U.round((float(v.cost) * 0.4 + U.sum(v.parts, func(p): return float(D.PART[p].cost) * 0.25)) / 1000) * 1000)
func scrapRP(v: Dictionary) -> int: return int(U.round(float(D.BODY[v.body].rp) * 0.3 + float(v.races) * 2 + 5))
func removeVehicle(vid) -> void:
	G.vehicles = G.vehicles.filter(func(v): return v.id != vid)
	G.jobs = G.jobs.filter(func(j): return j.vid != vid)
func sell(vid) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status == "build": return false
	var m := sellValue(v)
	G.money += m
	removeVehicle(vid)
	say("Sold %s for %s" % [v.name, U.money(m)])
	return true
func scrap(vid) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status == "build": return false
	var r := scrapRP(v)
	G.rp += r
	removeVehicle(vid)
	say("Scrapped %s: +%d RP" % [v.name, r])
	return true
func slots(v: Dictionary) -> int: return int(D.BODY[v.body].slots) + int(v.get("slotB", 0))

# ======================================================================
# sparks
# ======================================================================
func useSpark(t) -> bool:
	if not t or not int(G.sparks.get(t, 0)): toast.emit("No spark of that kind"); return false
	G.sparks[t] -= 1
	return true
func giveSpark(t: String, why := "") -> void:
	G.sparks[t] += 1
	say("Got a %s Spark! %s" % [SPARK_N[t], why])

# ======================================================================
# staff actions
# ======================================================================
func hire(cid) -> bool:
	var c = null
	for x in G.cand:
		if x.id == cid: c = x; break
	if c == null: return false
	var W := ws()
	if c.role == "drv" and drivers().size() >= drvCap(): toast.emit("Driver limit (%d) — grow your fame or workshop" % drvCap()); return false
	if c.role == "mec" and mechs().size() >= mechCap(): toast.emit("Mechanic limit (%d) — grow your fame or workshop" % mechCap()); return false
	var fee: float = float(c.salary) * 3
	if G.money < fee: toast.emit("Not enough money"); return false
	G.money -= fee
	c.joined = G.day
	G.staff.append(c)
	G.cand = G.cand.filter(func(x): return not is_same(x, c))
	say("%s joined the team!" % c.name)
	sfx.emit("fanfare")
	staff_hired.emit(int(c.id))
	return true
func fire(sid) -> bool:
	var s := staff(sid)
	if s.is_empty(): return false
	if s.role == "drv" and drivers().size() <= 1: toast.emit("You need at least one driver"); return false
	G.staff = G.staff.filter(func(x): return not is_same(x, s))
	say("%s left the team." % s.name)
	return true
func mechLvCost(s: Dictionary) -> int: return int(U.round(12 * pow(float(s.lv), 1.9)))
func levelMech(sid) -> bool:
	var s := staff(sid)
	if s.is_empty() or s.role != "mec" or int(s.lv) >= 10: return false
	var c := mechLvCost(s)
	if G.rp < c: toast.emit("Not enough research data"); return false
	G.rp -= c
	s.lv += 1
	var t := U.ri(3, 6) + int(s.lv)
	var a := U.ri(1, 3)
	var an := U.ri(1, 4)
	s.tech += t; s.appeal += a; s.analysis += an
	s.salary = U.round(float(s.salary) * 1.08 / 1000) * 1000
	say("%s reached Lv%d! Tech +%d" % [s.name, int(s.lv), t])
	sfx.emit("good")
	return true
func trainCost(s: Dictionary, t: Dictionary) -> int:
	if float(t.cost) < 0: return int(U.round(float(t.cost) * (1 + fanRank() * 0.3) / 1000) * 1000)
	return int(U.round(float(t.cost) * (1 + (float(s.pedal) + float(s.shift) + float(s.steer)) / 450) / 1000) * 1000)
func trainAvail(id: String) -> bool:
	var t: Dictionary = D.TRAIN[id]
	return t.un == "S" or bool(G.unl.train.get(id, false))
## -> gains dict, or null when training can't happen.
func train(sid, tid: String, spark = null):
	var s := staff(sid)
	if s.is_empty() or s.role != "drv" or not D.TRAIN.has(tid) or not trainAvail(tid): return null
	var t: Dictionary = D.TRAIN[tid]
	var en := int(U.round(float(t.en) * (0.6 if s.get("trait") == "iron" else 1.0)))
	if float(s.energy) < en: toast.emit("%s is too tired" % s.name); return null
	var tc := trainCost(s, t)
	if tc > 0 and G.money < tc: toast.emit("Not enough money"); return null
	if spark and not useSpark(spark): return null
	G.money -= tc
	s.energy -= en
	var out := {}
	var sm: float = SPARK_MUL[spark] if spark else 1.0
	var gm: float = (1 + facV("train") / 100) * (1.4 if s.get("trait") == "bloomer" else 1.0) * sm
	for k in t.g:
		if k == "car" or k == "bike":
			s.aff[k] = U.fixed(minf(1.45, float(s.aff[k]) + float(t.g[k]) * sm), 2); out[k] = "+"; continue
		if k == "maxE":
			s.maxE = minf(160, float(s.maxE) + float(t.g[k])); out.maxE = t.g[k]; continue
		var dim: float = 120 / (120 + float(s[k]) * 0.35)
		var g := int(max(1.0, U.round(float(t.g[k]) * gm * U.rand(0.8, 1.3) * dim)))
		s[k] += g; out[k] = g
	if tid == "oddjobs": out.money = -tc
	return out

# ======================================================================
# sponsors
# ======================================================================
func sponsorOffers() -> Array:
	var arr := []
	for s in D.SPONSORS:
		if float(G.fans) >= float(s.fans) and not G.spons.any(func(x): return x.id == s.id): arr.append(s)
	return U.sort_by(arr, func(s): return float(s.fans), true).slice(0, 5)
func sponsorPay(sp: Dictionary) -> float:
	return U.round(float(D.SPON[sp.id].mo) * 1000 * (1 + 0.3 * (float(sp.ad) - 1)) * (1 + facV("spon") / 100))
func signSponsor(id: String) -> bool:
	if G.spons.size() >= int(ws().spon): toast.emit("Sponsor slots full"); return false
	var S: Dictionary = D.SPON[id]
	var done := bool(G.sponDone.get(id, false))
	G.money += U.round(float(S.sign) * 500) if done else float(S.sign) * 1000
	G.spons.append({"id": id, "ad": 1, "adx": 0, "day": G.day, "base": {"st": G.st.duplicate(true), "fans": G.fans}, "done": done})
	say("Signed with %s!" % S.n)
	sfx.emit("fanfare")
	sponsor_signed.emit(id)
	return true
func cancelSponsor(id: String) -> void:
	G.spons = G.spons.filter(func(s): return s.id != id)
	say("Contract with %s ended." % D.SPON[id].n)
func goalKey(g: Dictionary):
	if g.get("disc"): return "disc:" + g.disc
	if g.get("surf"): return "terr:" + g.surf
	if g.get("cls"): return "cls:" + g.cls
	if g.get("tier"): return "tier:" + str(int(g.tier))
	return null
## -> [current, needed]
func goalProgress(sp: Dictionary) -> Array:
	var g: Dictionary = D.SPON[sp.id].goal
	var b: Dictionary = sp.base.st
	match g.t:
		"enter", "races": return [float(G.st.races) - float(b.races), g.n]
		"podium": return [float(G.st.podiums) - float(b.podiums), g.n]
		"win":
			var k = goalKey(g)
			if k == null: return [float(G.st.wins) - float(b.wins), g.n]
			return [float(G.st.wc.get("w:" + k, 0)) - float(b.wc.get("w:" + k, 0)), g.n]
		"series":
			return [_title_count(G.st.titles, g) - _title_count(b.titles, g), g.n]
		"fans": return [G.fans, g.n]
		"money": return [G.money, g.n]
	return [0, 1]
func _title_count(titles: Array, g: Dictionary) -> int:
	var n := 0
	for t in titles:
		var S: Dictionary = D.SER[t]
		if (not g.get("tier") or int(S.tier) == int(g.tier)) and (not g.get("disc") or S.disc == g.disc): n += 1
	return n
func goalText(g: Dictionary) -> String:
	var parts := []
	if g.get("disc"): parts.append(D.DISC[g.disc].n)
	if g.get("surf"): parts.append(D.TERR_N[g.surf])
	if g.get("cls") == "bike": parts.append("bike")
	elif g.get("cls") == "car": parts.append("car")
	if g.get("tier"): parts.append(D.TIER_N[int(g.tier)])
	var f := " ".join(parts)
	var n := int(g.n)
	match g.t:
		"enter": return "Enter %d races" % n
		"races": return "Run %d races" % n
		"podium": return "Finish on the podium %d×" % n
		"win": return "Win %s%srace%s" % [(str(n) + " ") if n > 1 else "a ", (f + " ") if f != "" else "", "s" if n > 1 else ""]
		"series": return "Win %s%sseries title%s" % [(str(n) + " ") if n > 1 else "a ", (f + " ") if f != "" else "", "s" if n > 1 else ""]
		"fans": return "Reach %s fans" % U.num(n)
		"money": return "Hold %s" % U.money(n)
	return ""
func rewardText(rw: Dictionary) -> String:
	var a := []
	for t in rw.get("train", []): a.append("Training: " + D.TRAIN[t].n)
	for t in rw.get("layout", []): a.append("Layout: " + D.LAYOUT[t].n)
	for t in rw.get("part", []): a.append("Part: " + D.PART[t].n)
	for t in rw.get("body", []): a.append("Vehicle: " + D.BODY[t].n)
	for t in rw.get("fac", []): a.append("Facility: " + D.FAC[t].n)
	if rw.get("cash"): a.append("Bonus " + U.money(float(rw.cash) * 1000))
	return ", ".join(a)
func checkSponsors() -> void:
	for sp in G.spons:
		if sp.done: continue
		var pr := goalProgress(sp)
		if float(pr[0]) >= float(pr[1]):
			sp.done = true
			G.sponDone[sp.id] = 1
			var S: Dictionary = D.SPON[sp.id]
			var rw: Dictionary = S.rw
			for t in rw.get("train", []): G.unl.train[t] = 1
			for t in rw.get("layout", []): G.unl.layout[t] = 1
			for t in rw.get("part", []): G.unl.part[t] = 1
			for t in rw.get("body", []): G.unl.body[t] = 1
			for t in rw.get("fac", []): G.unl.fac[t] = 1
			if rw.get("cash"): G.money += float(rw.cash) * 1000
			addLog("%s goal complete!" % S.n)
			_popup("Sponsor Goal Achieved!", "%s is thrilled!\n\nUnlocked: %s" % [S.n, rewardText(rw)], "sponsor_goal", {"sponsor": sp.id})
			sfx.emit("fanfare")

# ======================================================================
# facilities
# ======================================================================
func facAvail(id: String) -> bool: return D.FAC[id].un == "S" or bool(G.unl.fac.get(id, false))
func buildFac(id: String) -> bool:
	var W := ws()
	var used: int = G.fac.filter(func(f): return f != null).size()
	if used >= int(W.fac): toast.emit("No free facility slots"); return false
	if facLv(id) > 0: return false
	var c: float = float(D.FAC[id].cost[0]) * 1000
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	G.fac.append({"id": id, "lv": 1})
	say("Built %s!" % D.FAC[id].n)
	sfx.emit("fanfare")
	return true
func upgradeFac(id: String) -> bool:
	var f = null
	for x in G.fac:
		if x != null and x.id == id: f = x; break
	if f == null or int(f.lv) >= 3: return false
	var c: float = float(D.FAC[id].cost[int(f.lv)]) * 1000
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	f.lv += 1
	say("%s upgraded to Lv%d" % [D.FAC[id].n, int(f.lv)])
	sfx.emit("good")
	return true
func demolishFac(id: String) -> void:
	G.fac = G.fac.filter(func(f): return f != null and f.id != id)
	say("Removed %s" % D.FAC[id].n)

# ======================================================================
# workshop
# ======================================================================
func wsNeed():
	if int(G.ws) < 4: return {"titles": 1, "tier": int(G.ws), "cost": D.WORKSHOPS[int(G.ws) + 1].cost}
	return null
func canUpgradeWS() -> bool:
	var n = wsNeed()
	if n == null: return false
	return titlesIn(n.tier) >= int(n.titles)
func upgradeWS() -> bool:
	if not canUpgradeWS(): return false
	var n: Dictionary = wsNeed()
	if G.money < n.cost: toast.emit("Not enough money"); return false
	G.money -= n.cost
	G.ws = int(G.ws) + 1
	say("Moved into the %s!" % ws().n)
	sfx.emit("fanfare")
	_popup("Welcome to the %s!" % ws().n, "More room for staff, vehicles, facilities and sponsors.\n\nNew %s races and research are now available!" % D.TIER_N[int(G.ws)], "workshop", {"level": int(G.ws)})
	workshop_up.emit(int(G.ws))
	return true
func legendOpen() -> bool: return int(G.ws) >= 4 and titlesIn(4) >= 2

# ======================================================================
# races
# ======================================================================
func best(id: String) -> int:
	var r = G.races.get(id)
	if r == null or not r.get("best"): return 99
	return int(r.best)
func raceState(id: String) -> Dictionary:
	var r: Dictionary = D.RACE[id]
	if r.excl: return {"ok": false, "why": "Series only", "series": true}
	if int(r.tier) == 5:
		if not legendOpen(): return {"ok": false, "why": "Win 2 World series"}
	elif int(G.ws) < int(r.tier): return {"ok": false, "why": "Needs " + D.WORKSHOPS[int(r.tier)].n}
	if r.letter == "a":
		if r.disc == "OP" and int(r.tier) == 1 and int(G.st.wins) < 2: return {"ok": false, "why": "Win 2 races first"}
		return {"ok": true}
	var prev: String = id.substr(0, id.length() - 1) + ("a" if r.letter == "b" else "b")
	if best(prev) > 3: return {"ok": false, "why": "Top 3 at " + D.RACE[prev].n}
	return {"ok": true}
func seriesState(id: String) -> Dictionary:
	var S: Dictionary = D.SER[id]
	var st: Dictionary = G.series.get(id, {})
	if st.get("act") != null: return {"ok": false, "active": true, "why": "In progress"}
	var tier := int(S.tier)
	if tier == 5 and not legendOpen(): return {"ok": false, "why": "Win 2 World series"}
	if tier < 5 and int(G.ws) < tier: return {"ok": false, "why": "Needs " + D.WORKSHOPS[tier].n}
	var need := 1 if (S.disc == "OP" and tier < 5) else 2
	var w := 0
	for r in D.RACES:
		if int(r.tier) == tier and r.disc == S.disc and not r.excl and best(r.id) == 1: w += 1
	if w < need: return {"ok": false, "why": "Win %d %s %s race%s (%d/%d)" % [need, D.DISC[S.disc].n, D.TIER_N[tier], "s" if need > 1 else "", w, need]}
	if st.get("lastStart") != null and int(G.day) - int(st.lastStart) < DAYS_YEAR:
		return {"ok": false, "why": "Next season in %dd" % (DAYS_YEAR - (int(G.day) - int(st.lastStart)))}
	var act := 0
	for k in G.series:
		if G.series[k].get("act") != null: act += 1
	if act >= int(ws().teams): return {"ok": false, "why": "Too many active series"}
	return {"ok": true}
func availRaceIds() -> Array:
	var out := []
	for r in D.RACES:
		if raceState(r.id).ok: out.append(r.id)
	for s in D.SERIES:
		if seriesState(s.id).ok: out.append(s.id)
	return out
func clsOk(race: Dictionary, v: Dictionary) -> bool: return race.cls == "any" or D.BODY[v.body].cls == race.cls
func eligibleVehicles(race: Dictionary) -> Array:
	return G.vehicles.filter(func(v): return v.status == "ready" and clsOk(race, v) and engReady(v))
func raceEnergy(s: Dictionary) -> int: return 20 if s.get("trait") == "iron" else 30
func eligibleDrivers() -> Array: return drivers().filter(func(s): return float(s.energy) >= raceEnergy(s))
## E.profile: effective race profile of driver + vehicle.
func profile(v: Dictionary, s: Dictionary) -> Dictionary: return Prof.profile(v, s, G)
## E.oddsRatio: expected pace vs the race's rating (1.0 = even).
## Set odds_cache = {} while scoring many driver/vehicle pairs with nothing changing in between
## (pre-race screens, bots): the driver-independent engine part is computed once per race + vehicle.
var odds_cache = null
func oddsRatio(race: Dictionary, v: Dictionary, s: Dictionary) -> float:
	var p := profile(v, s)
	var tr := RaceSim.build_track(race, false)
	var rt := RaceSim.rival_terr(race)
	var rsx: Dictionary
	var key := "%s|%s" % [race.id, str(v.id)]
	if odds_cache is Dictionary and odds_cache.has(key): rsx = odds_cache[key]
	else:
		rsx = Tune.raceSecs(v, race, tr, Tune.forecast(race), Tune.mode() == "easy")
		if odds_cache is Dictionary: odds_cache[key] = rsx
	var rm := RaceSim.rival_mul(Tune.mode())
	var tot := 0.0; var rv := 0.0
	var R: float = race.R
	for i in tr.secs.size():
		var sc: Dictionary = tr.secs[i]
		var w: Array = D.SEC[sc.type].w
		var tk: String = D.SURF[sc.surf].k
		var k: Dictionary = rsx.secs[i]
		tot += ((float(w[0]) * p.S * k.s + float(w[1]) * p.A * k.a) * k.ef + float(w[2]) * p.H * k.h) * (U.clamp(float(p.t[tk]) * k.t, 5, 220) / 100) * p.pm * float(sc.len)
		rv += R * rm * (float(rt[tk]) + 1) / 100 * float(sc.len)
	return tot / rv
## [label, color]
func oddsLabel(r: float) -> Array:
	if r < 0.8: return ["Hopeless", "#f55"]
	if r < 0.95: return ["Tough", "#f95"]
	if r < 1.07: return ["Even", "#fd5"]
	if r < 1.2: return ["Favored", "#9e5"]
	return ["Dominant", "#5ef"]
## E.bestSetup (ui2.js): crew searches the setup sheet for the best odds at a race.
func bestSetup(v: Dictionary, r: Dictionary, s: Dictionary) -> void:
	var bike: bool = D.BODY[v.body].cls == "bike"
	var keys := ["r", "susp", "psi"] if bike else ["fd", "susp", "psi", "wing"]
	var rng := {"r": [34, 60, 1], "fd": [2.8, 4.8, 0.1], "susp": [1, 10, 1], "psi": [8, 40, 2] if bike else [18, 40, 2], "wing": [0, 15, 1]}
	for _pass in 2:
		for k in keys:
			var a: float = rng[k][0]; var b: float = rng[k][1]; var st: float = rng[k][2]
			var bst = v.setup[k]
			var bs := oddsRatio(r, v, s)
			var x := a
			while x <= b + 1e-9:
				v.setup[k] = U.fixed(x, 2)
				var o := oddsRatio(r, v, s)
				if o > bs + 1e-6: bs = o; bst = v.setup[k]
				x += st
			v.setup[k] = bst

# ======================================================================
# series
# ======================================================================
func enterSeries(id: String) -> bool:
	var S: Dictionary = D.SER[id]
	var st := seriesState(id)
	if not st.ok: toast.emit(st.why); return false
	if G.money < S.fee: toast.emit("Not enough money for entry fee"); return false
	G.money -= S.fee
	var nr := int(S.rivals)
	var rv := U.shuffle(D.RIVALS).slice(0, nr)
	var rivals := []
	for i in rv.size():
		var r: Array = rv[i]
		rivals.append({"team": r[0], "col": r[1], "drv": str(U.pick(D.FIRST)) + " " + str(U.pick(D.LAST)), "f": U.fixed(1.13 - 0.3 * i / (nr - 1) + U.rand(-0.03, 0.03), 3)})
	if not G.series.has(id): G.series[id] = {"titles": 0, "best": 99}
	G.series[id].lastStart = G.day
	G.series[id].act = {"round": 0, "next": int(G.day) + 7, "pts": {"you": 0}, "rivals": rivals, "res": [], "pending": false}
	for r in rivals: G.series[id].act.pts[r.team] = 0
	say("Entered the %s! Round 1 in 7 days." % S.n)
	sfx.emit("fanfare")
	return true
## [[team_key, pts], ...] best first ("you" = the player); stable like the web sort.
func standings(id: String) -> Array:
	var a: Dictionary = G.series[id].act
	var arr := []
	for k in a.pts: arr.append([k, a.pts[k]])
	return U.sort_by(arr, func(x): return float(x[1]), true)
## Score a series round from a finished career race (web: E.seriesRoundDone(id, rs)).
func seriesRoundDone(id: String, rs: RaceSim) -> void:
	var a: Dictionary = G.series[id].act
	var S: Dictionary = D.SER[id]
	var order := raceOrder(rs)
	var me := -1
	for i in order.size():
		var e: Dictionary = order[i]
		if isPlayerEnt(e) and me < 0: me = i
		if e.get("dnf", false): continue
		var p: int = int(D.POINTS[i]) if i < D.POINTS.size() else 0
		var key: String = "you" if isPlayerEnt(e) else e.team
		a.pts[key] = int(a.pts.get(key, 0)) + p
	a.res.append("DNF" if rs.players().all(func(x): return bool(x.dnf)) else me + 1)
	a.round = int(a.round) + 1
	a.pending = false
	if int(a.round) >= S.rounds.size(): endSeries(id)
	else:
		a.next = int(G.day) + 21
		addLog("%s: round %d in 3 weeks" % [S.n, int(a.round) + 1])
func seriesRoundSkip(id: String) -> void:
	var a: Dictionary = G.series[id].act
	a.res.append("—")
	a.round = int(a.round) + 1
	a.pending = false
	# rivals still score (web sorts with a random comparator; here each rival rolls a random key)
	var order := U.sort_by(a.rivals, func(r): return float(r.f) * U.rand(0.9, 1.1), true)
	for i in order.size():
		a.pts[order[i].team] = int(a.pts.get(order[i].team, 0)) + (int(D.POINTS[i]) if i < D.POINTS.size() else 0)
	if int(a.round) >= D.SER[id].rounds.size(): endSeries(id)
	else: a.next = int(G.day) + 21
func endSeries(id: String) -> void:
	var S: Dictionary = D.SER[id]
	var st: Dictionary = G.series[id]
	var tb := standings(id)
	var pos := 1
	for i in tb.size():
		if tb[i][0] == "you": pos = i + 1; break
	st.lastEnd = G.day
	st.best = mini(int(st.get("best", 99)) if st.get("best") else 99, pos)
	st.erase("act")
	var lines := []
	for i in mini(6, tb.size()):
		lines.append("%d. %s  %d" % [i + 1, G.team.name if tb[i][0] == "you" else tb[i][0], int(tb[i][1])])
	var text := "\n".join(lines)
	var title_text: String
	var prize := 0.0
	var fans := 0.0
	if pos == 1:
		var first: bool = not G.st.titles.has(id)
		G.st.titles.append(id)
		st.titles = int(st.titles) + 1
		G.year.titles += 1
		prize = U.round(float(S.prize) * paceMul()) if first else U.round(float(S.prize) * 0.5 * paceMul())
		G.money += prize; G.st.earn += prize; G.year.earn += prize
		fans = U.round(float(S.prize) / 1500 * (1 + facV("fans") / 100))
		G.fans += fans
		giveSpark("g", "Series champion!")
		title_text = "CHAMPIONS!\n" + text + "\nPrize %s · Fans +%s" % [U.money(prize), U.num(fans)]
		if canUpgradeWS(): title_text += "\n\nA bigger workshop is available! (Team menu)"
		sfx.emit("fanfare")
	else:
		prize = U.round(float(S.prize) * (0.4 if pos == 2 else 0.2)) if pos <= 3 else 0.0
		G.money += prize; G.st.earn += prize
		G.fans += U.round(float(S.prize) / 6000)
		title_text = "%s in the championship\n%s" % [U.ord(pos), text] + (("\nPrize " + U.money(prize)) if prize else "")
	addLog("%s finished: %s" % [S.n, U.ord(pos)])
	_popup(S.n + " — Final", title_text, "series_end", {"series_id": id, "pos": pos, "table": tb, "prize": prize})
	checkSponsors()
	if pos == 1: title_won.emit(id)

# ======================================================================
# race entries (race.js Race.create for the career)
# ======================================================================
func mkRivals(def: Dictionary, n: int) -> Array:
	var rv := U.shuffle(D.RIVALS).slice(0, n)
	var out := []
	for i in rv.size():
		out.append({"team": rv[i][0], "col": rv[i][1], "drv": str(U.pick(D.FIRST)) + " " + str(U.pick(D.LAST)), "f": 1.12 - 0.28 * i / maxf(1, n - 1) + U.rand(-0.03, 0.03)})
	return out

func _kinds_for(def: Dictionary) -> Array:
	var K: Dictionary = D.KINDS
	var kinds: Array = (K.CR + K.CO + K.BR + K.BO) if def.disc == "OP" else K.get(def.disc, K.CR)
	return kinds.slice(0, mini(kinds.size(), 2 + int(def.tier) * 2))

## Career race: one human entry per team car (owner 1, team G.team), each built from Career.profile and
## Tune.raceSecs (full fuel model). opts: fmt, rivals, series, round, cond, test, tactic, entries
## ([[vid, sid], ...]; default [[vid, sid]]), gridRivals + playerSlot / playerSlots (heats main), heat,
## rain (force), seed.
func makeRace(def: Dictionary, vid, sid, opts: Dictionary = {}) -> RaceSim:
	var ens: Array = opts.get("entries", []) if opts.get("entries") is Array else []
	if ens.is_empty(): ens = [[vid, sid]]
	var fmt: Dictionary = opts.get("fmt", {})
	if fmt.is_empty(): fmt = {"id": "sprint", "kind": "mass", "laps": def.laps, "mul": {"prize": 1, "rp": 1, "fans": 1, "wear": 1}}
	var test := bool(opts.get("test", false))
	var rain := false
	if def.surf.has("tar") and not test:
		if G.wxRain: rain = true; G.wxRain = false
		elif U.chance(0.08): rain = true
	if opts.has("rain"): rain = bool(opts.rain)
	var laps_o = fmt.laps if int(fmt.laps) != int(def.laps) else null
	var tr := RaceSim.build_track(def, rain, laps_o)
	var rivals: Array = opts.rivals if opts.get("rivals") != null else mkRivals(def, RIVAL_N[int(def.tier)] if int(def.tier) < RIVAL_N.size() else 11)
	var tk := _kinds_for(def)
	for r in rivals:
		if not r.has("kind"): r.kind = U.pick(tk)
	var cond: Dictionary = opts.cond if opts.get("cond") != null else Tune.forecast(def)
	var hs := []
	var fuel_cost := 0.0
	for k in ens.size():
		var v := veh(ens[k][0])
		var s := staff(ens[k][1])
		assert(not v.is_empty() and not s.is_empty(), "makeRace: unknown vehicle/driver")
		var b: Dictionary = D.BODY[v.body]
		if Tune.mode() == "easy" and v.eng.fuel != "none": Tune.crewTune(v, cond, 0.99)
		elif Tune.mode() == "standard" and v.eng.fuel != "none" and not test:
			# middle ground: tune what you like, but the crew won't race an engine-killer
			var why := Tune.danger(v, cond)
			if why != "":
				Tune.crewTune(v, cond, 0.97)
				say("Crew reset %s's tune to a safe baseline (it was %s)." % [v.name, why])
				toast.emit("Crew reset the tune: it was %s" % why)
		var p := profile(v, s)
		var rsx := Tune.raceSecs(v, def, tr, cond)
		# exhaust show from the real tune: lean idle / 1/8 throttle pops on lift-off, rich WOT smokes
		var lam: Dictionary = rsx.ev.lam if rsx.get("ev") is Dictionary and rsx.ev.get("lam") is Dictionary else {}
		var fx_pop := clampf((float(lam.get("idle", 0.93)) - 0.95) * 8.0 + (float(lam.get("low", 0.9)) - 0.93) * 6.0, 0.0, 1.0) + 0.05
		var fx_smoke := clampf((0.82 - float(lam.get("wot", 0.87))) * 9.0, 0.0, 1.0)
		var extra := {"isPlayer": true, "entry": k, "vid": v.id, "sid": s.id, "hair": s.get("hair", "#222"), "fx_pop": fx_pop, "fx_smoke": fx_smoke,
			"fouled": bool(rsx.foul) and U.chance(0.3), "seizeRisk": bool(rsx.seize), "seized": false, "holed": false,
			"forged": Tune.has("forged"), "tcmap": Tune.has("tcmap") and v.eng.fuel == "efi"}
		hs.append({"name": s.name, "team": G.team.name, "team_key": "you", "col": G.team.color, "kind": b.kind, "cls": b.cls,
			"prof": p, "sk": rsx.secs, "hp": float(v.hp), "cond": float(v.eng.get("cond", 1)), "cyl": Tune.cyl(v), "owner": 1,
			"tactic": opts.get("tactic", "normal"), "rt": U.clamp(0.2 - (float(s.shift) + float(s.analysis)) / 1200, 0.02, 0.2),
			"sparks": G.sparks, "extra": extra, "voice": EngineAudio.voice_for_vehicle(v), "exh": EngineAudio.exhaust_for_vehicle(v)})
		var fuel: Dictionary = D.FUELS[v.eng.get("fuelT", "pump") if v.eng.get("fuelT") else "pump"]
		if float(fuel.cost) > 0 and not test: fuel_cost += float(fuel.cost) * float(fmt.mul.get("wear", 1) if fmt.mul.get("wear") else 1)
	var ro := {"fmt": fmt, "rivals": rivals, "rain": rain, "test": test, "mode": Tune.mode(), "seed": opts.get("seed", U.rng.randi())}
	if opts.get("gridRivals") != null:
		ro.grid_rivals = opts.gridRivals
		ro.player_slot = int(opts.get("playerSlot", 0))
		if opts.get("playerSlots") is Array: ro.player_slots = opts.playerSlots
	var rs := RaceSim.create(def, hs, ro)
	for P in rs.players(): P.sparks = G.sparks      # one shared spark pool for the team
	var P0 := rs.player()
	rs.auto_retire = bool(G.settings.get("autoRetire", true))
	rs.auto_retire_eng = rs.auto_retire and Tune.mode() != "sim"
	rs.series = opts.get("series")
	rs.series_round = int(opts.get("round", -1))
	rs.cond = cond
	rs.telem = Tune.has("telem")
	rs.heat = opts.get("heat")
	rs.gridSlot = int(P0.idx)
	rs.career = true
	if fuel_cost > 0: rs.fuelCost = fuel_cost
	return rs

## Race.useSpark: spends from G.sparks (the player's entry shares that dictionary).
func raceSpark(rs: RaceSim, t: String) -> bool:
	var P := rs.player()
	if P.fin or P.dnf or P.boost > 0: return false
	if int(G.sparks.get(t, 0)) <= 0: toast.emit("No spark of that kind"); return false
	if not rs.use_spark(int(P.idx), t): return false
	sfx.emit("spark")
	return true

## Race.quickTime: non-visual time for a rival run (time-trial and drag ladders).
func quickTime(def: Dictionary, rival: Dictionary, fmt = null) -> float:
	var laps_o = fmt.laps if (fmt is Dictionary and int(fmt.laps) != int(def.laps)) else null
	var tr := RaceSim.build_track(def, false, laps_o)
	var tb := RaceSim.rival_terr(def)
	var R: float = def.R
	var stv: float = R * float(rival.f) * RaceSim.rival_mul(Tune.mode())
	var t := 0.0
	for s in tr.secs:
		var w: Array = D.SEC[s.type].w
		var tk: String = D.SURF[s.surf].k
		var p: float = stv * U.rand(0.93, 1.07) * (float(tb[tk]) + U.rand(-6, 8)) / 100 * (float(w[0]) + float(w[1]) + float(w[2]))
		t += float(s.len) / (p / R)
	t *= float(tr.laps)
	if U.chance(0.12): t *= U.rand(1.03, 1.12)
	var T0: float = 9.0 if tr.drag else U.clamp(float(tr.total) * 0.8, 24, 90)
	return t * T0 / float(tr.total)

## D.seriesFormat(r)
func seriesFormat(def: Dictionary) -> Dictionary:
	var f: Array = Data.formats(def.id)
	for x in f:
		if x.id == "heats": return x
	for x in f:
		if x.id == "best2": return x
	return f[0]
func formats(def: Dictionary) -> Array: return Data.formats(def.id)

## Final classification for scoring: rs.order, or the pseudo order a drag/hill flow left.
func raceOrder(rs: RaceSim) -> Array: return rs.order_override if not rs.order_override.is_empty() else rs.order
func isPlayerEnt(e: Dictionary) -> bool: return bool(e.get("isPlayer", false))

## Race flow for one career race (all formats). See RaceFlow.
## opts.dyn: the story dynasty rival (Story.rival_for) to enter into the field.
func startRace(race_id: String, vid, sid, tactic := "normal", series_id = null, fmt_id := "", opts: Dictionary = {}) -> RaceFlow:
	return RaceFlow.new(D.RACE[race_id], vid, sid, tactic, series_id, fmt_id, opts)

## UI.raceResult engine part: finishRace + series round scoring.
func raceResult(rs: RaceSim) -> Dictionary:
	var out := finishRace(rs)
	if rs.series != null and G.series.has(rs.series) and G.series[rs.series].get("act") != null:
		seriesRoundDone(rs.series, rs)
	return out

## UI.carry: hp / engine condition after a heat, drag round or hill run.
func carry(v: Dictionary, P: Dictionary) -> void:
	v.hp = U.clamp(float(P.hp), 0, 1)
	if v.get("eng") != null: v.eng.cond = U.clamp(float(P.cond) if P.get("cond") != null else float(v.eng.cond), 0, 1)

# ======================================================================
# race results
# ======================================================================
## Score a finished race for the team. With several entries, the team's result (wins, sparks, story,
## series "you" points come from each car's place) is its best car; every car earns its own prize and
## wears its own machine and driver; RP and fans count the best car fully and the others at half.
func finishRace(rs: RaceSim) -> Dictionary:
	var def: Dictionary = rs.def
	var Ps: Array = rs.players()
	var mul: Dictionary = rs.fmt.get("mul", {"prize": 1, "rp": 1, "fans": 1, "wear": 1})
	var ord0 := raceOrder(rs)
	# each entry's place
	var places := []
	for P in Ps:
		var pp: int = int(P.pos)
		if Ps.size() == 1 and rs.forcePos > 0: pp = rs.forcePos
		elif not rs.order_override.is_empty():
			var at := ord0.find(P)
			if at >= 0: pp = at + 1
		places.append(pp)
	var lead := 0
	for i in Ps.size():
		var bi: bool = bool(Ps[lead].dnf)
		if (bi and not Ps[i].dnf) or (bool(Ps[i].dnf) == bi and places[i] < places[lead]): lead = i
	var P: Dictionary = Ps[lead]
	var pos: int = places[lead]
	var dnf: bool = P.dnf
	var v := veh(P.vid)
	var s := staff(P.sid)
	var ff: float = 0.1 if dnf else (float(FF[pos - 1]) if pos - 1 < FF.size() else 0.12)
	var out := {"pos": pos, "dnf": dnf, "prize": 0, "rp": 0, "fans": 0, "unl": [], "spark": null, "destroyed": bool(Ps[0].get("destroyed", false)), "entries": []}
	var before := availRaceIds()
	var rk0 := fanRank()
	var rep: float = 0.4 if (rs.series == null and G.yearWins.get(def.id)) else 1.0
	out.rep = rep < 1
	var ms := mechs()
	var mAn: float = U.sum(ms, func(m): return m.analysis) / ms.size() if ms.size() else 0.0
	for i in Ps.size():
		var Pi: Dictionary = Ps[i]
		var vi := veh(Pi.vid)
		var si := staff(Pi.sid)
		var posi: int = places[i]
		var dnfi: bool = Pi.dnf
		var ffi: float = 0.1 if dnfi else (float(FF[posi - 1]) if posi - 1 < FF.size() else 0.12)
		var wgt: float = 1.0 if i == lead else 0.5
		var eo := {"vid": Pi.vid, "sid": Pi.sid, "name": str(si.get("name", "")), "veh": str(vi.get("name", "")), "pos": posi, "dnf": dnfi,
			"prize": 0, "destroyed": bool(Pi.get("destroyed", false)), "holed": bool(Pi.get("holed", false)), "seized": bool(Pi.get("seized", false))}
		# money
		if not dnfi and posi <= 12: eo.prize = U.round(float(def.prize) * float(D.PRIZE_SPLIT[posi - 1]) * rep * float(mul.prize) * paceMul() / 100) * 100
		out.prize += eo.prize
		# RP + fans
		var vst: Dictionary = vs(vi) if not vi.is_empty() else {"fx": {"rp": 0, "fan": 0}, "adv": 0}
		out.rp += U.round(wgt * float(def.rp) * ffi * (1 + (float(si.analysis) + mAn) / 250) * (1 + facV("rp") / 100) * (1 + float(vst.fx.rp)) * (1.3 if rs.series != null else 1.0) * (0.6 if rep < 1 else 1.0) * float(mul.rp) * paceMul() * (1.1 if Tune.has("telem") else 1.0) * (1.1 if (not vi.is_empty() and vi.get("bflags", []).has("data")) else 1.0))
		out.fans += U.round(wgt * float(def.R) * 0.6 * ffi * (0.5 if rep < 1 else 1.0) * float(mul.fans) * paceMul() * (1 + float(si.appeal) / 250) * (1 + facV("fans") / 100) * (1.3 if si.get("trait") == "show" else 1.0) * (1 + float(vst.fx.fan)) * (1.4 if rs.series != null else 1.0))
		if not dnfi and si.get("trait") == "lucky" and U.chance(0.15): giveSpark("b", "Lucky!")
		# vehicle
		if not vi.is_empty():
			vi.races += 1
			if not dnfi and posi == 1: vi.wins += 1
			if Pi.get("destroyed", false):
				removeVehicle(vi.id)
				addLog("%s was destroyed!" % vi.name)
			else:
				vi.hp = U.clamp(float(Pi.hp), 0, 1)
				vi.xp += U.round(float(def.tier) * 12 * (ffi + 0.3))
				while int(vi.lv) < 10 and float(vi.xp) >= vehXpNeed(vi):
					vi.xp -= vehXpNeed(vi); vi.lv += 1; eo.vlv = vi.lv
					if i == 0: out.vlv = vi.lv
				for pid in vi.parts:
					if not G.partLv.has(pid): G.partLv[pid] = {"lv": 1, "xp": 0}
					var pl: Dictionary = G.partLv[pid]
					if int(pl.lv) < 5:
						pl.xp += int(def.tier) * 8 + 4
						while int(pl.lv) < 5 and float(pl.xp) >= 40 * int(pl.lv):
							pl.xp -= 40 * int(pl.lv); pl.lv += 1
				engAfter(vi, rs, Pi, mul)
				if float(vi.hp) < 0.999:
					var days := maxi(1, int(ceil((1 - float(vi.hp)) * 14)))
					vi.status = "repair"
					G.jobs.append({"id": nid(), "type": "rep", "vid": vi.id, "left": days, "total": days, "req": D.RANK_REQ[D.BODY[vi.body].rank], "nob": true})
				else: vi.status = "ready"
		# driver
		si.energy = maxf(0, float(si.energy) - raceEnergy(si))
		if U.chance(0.6):
			var k: String = U.pick(["pedal", "shift", "steer"])
			si[k] += 1
		# sponsors ad
		for sp in G.spons:
			if int(sp.ad) >= 5: continue
			sp.adx += wgt * (float(si.appeal) + float(vst.adv)) / 8 * (ffi + 0.3)
			while int(sp.ad) < 5 and float(sp.adx) >= 60 * int(sp.ad):
				sp.adx -= 60 * int(sp.ad); sp.ad += 1
				addLog("%s ad effect Lv%d!" % [D.SPON[sp.id].n, int(sp.ad)])
		if Pi.get("holed", false): ach("holed")
		if Pi.get("seized", false): ach("seize")
		out.entries.append(eo)
	G.money += out.prize; G.st.earn += out.prize; G.year.earn += out.prize
	G.rp += out.rp
	G.fans += out.fans
	# team stats (best car)
	G.st.races += 1
	if not dnf and pos == 1: G.st.wins += 1; G.year.wins += 1; G.yearWins[def.id] = 1
	if not dnf and pos <= 3: G.st.podiums += 1; G.year.podiums += 1
	if dnf: G.st.dnf += 1
	if not dnf and pos == 1:
		wkey("w:disc:" + def.disc)
		wkey("w:cls:" + (D.BODY[v.body].cls if not v.is_empty() else def.cls))
		wkey("w:tier:" + str(int(def.tier)))
		var tk := {}
		for k in def.surf:
			var t: String = D.SURF[k].k
			tk[t] = float(tk.get(t, 0)) + float(def.surf[k])
		if rs.rain and tk.get("on"): tk.wet = float(tk.get("wet", 0)) + tk.on
		for k in tk:
			if tk[k] >= 40: wkey("w:terr:" + k)
	# best & sparks
	if not G.races.has(def.id): G.races[def.id] = {"best": 99, "n": 0, "w": 0}
	var rr: Dictionary = G.races[def.id]
	rr.n += 1
	if not dnf and pos == 1: rr.w += 1
	if not dnf and pos < int(rr.best):
		if pos <= 3:
			var t: String = "g" if pos == 1 else ("s" if pos == 2 else "b")
			giveSpark(t, "First " + ("win" if pos == 1 else "podium") + " here!")
			out.spark = t
		rr.best = pos
	if Ps.size() > 1 and not out.entries.any(func(x): return bool(x.dnf)) and places.max() <= 2: ach("onetwo")
	# streaks & achievements
	if not dnf and pos == 1:
		G.st.streak = int(G.st.get("streak", 0)) + 1
		if int(G.st.streak) >= 3: ach("hat")
	else: G.st.streak = 0
	if not dnf and pos == 1:
		var c: Dictionary = rs.cond if not rs.cond.is_empty() else {"alt": 0, "temp": 20}
		if not v.is_empty() and v.get("eng") != null and v.eng.fuel == "carb" and maxf(float(c.alt), float(c.get("alt2", 0))) >= 2500: ach("thinair")
		if float(c.temp) <= -10: ach("frozen")
		if def.disc == "HC" or def.style == "hill":
			ach("hill1")
			if float(c.get("alt2", 0)) >= 4000: ach("clouds")
		if rs.fmt.get("id") == "endur": ach("endur")
		if rs.gridSlot >= 0 and rs.gridSlot >= int(floor(rs.ents.size() / 2.0)): ach("comeback")
		if rs.heatWin: ach("heatmain")
		if rs.drag: ach("drag1")
	if not dnf and rs.fmt.get("id") == "endur": ach("endur")
	if rs.fuelCost: G.money -= rs.fuelCost
	checkSponsors()
	checkAch()
	var after := availRaceIds()
	for x in after:
		if not before.has(x): out.unl.append(x)
	var res_txt := "DNF" if dnf else U.ord(pos)
	if Ps.size() > 1: res_txt = " & ".join(out.entries.map(func(x): return "DNF" if x.dnf else U.ord(int(x.pos))))
	addLog("%s: %s (+%s)" % [def.n, res_txt, U.money(out.prize)])
	var rk1 := fanRank()
	if rk1 > rk0:
		_popup("Team Rank Up!", "Your team is now %s!\n\nBigger sponsors are calling, and better staff want to join." % D.FAN_RANKS[rk1][1], "rank_up", {"rank": rk1})
		refreshCandidates()
	var info := {"race_id": def.id, "fmt_id": rs.fmt.get("id", "sprint"), "pos": pos, "field": raceOrder(rs).size(), "dnf": dnf,
		"prize": out.prize, "series_id": rs.series, "entries": Ps.size()}
	# story dynasty rival (Story.rival_for): where they finished, 0 = DNF
	var ord := raceOrder(rs)
	for i in ord.size():
		var e: Dictionary = ord[i]
		var ref = e.get("ref")
		if bool(e.get("dynasty", false)) or (ref is Dictionary and bool(ref.get("dynasty", false))):
			out.dyn_pos = 0 if bool(e.get("dnf", false)) else i + 1
			info.dyn_pos = out.dyn_pos
			break
	race_finished.emit(info)
	return out

func engAfter(v: Dictionary, rs: RaceSim, P: Dictionary, mul: Dictionary) -> void:
	var e = v.get("eng")
	if e == null: return
	if e.fuel != "none":
		var fl: Array = v.get("bflags", [])
		var tac: String = P.get("tactic", "normal")
		var wear: float = 0.014 * float(mul.get("wear", 1)) * (0.7 if Tune.has("oilcool") else 1.0) * (0.7 if fl.has("endur") else 1.0) * (0.85 if fl.has("loom") else 1.0) * (1.3 if tac == "push" else (0.8 if tac == "safe" else 1.0))
		e.cond = U.clamp((float(P.cond) if P.get("cond") != null else float(e.cond)) - wear, 0, 1)
		var n: int = e.sync.size()
		var bi := Tune.syncBase(n)
		var tier := int(rs.def.get("tier", 1)) if rs.def.get("tier") else 1
		var ns := []
		for i in n:
			ns.append(0 if i == bi else U.fixed(U.clamp(float(e.sync[i]) + U.rand(-0.45, 0.45) * (1 + tier * 0.1), -6, 6), 1))
		e.sync = ns
		if (Tune.has("datalog") or fl.has("data")) and not rs.cond.is_empty(): e.log = Tune.makeLog(v, rs.cond, "Race: " + rs.def.n)
		if float(e.cond) <= 0:
			_popup("Engine Failure", "%s's engine is finished. Open Garage → Engine to rebuild it before racing again." % v.name, "engine_failure", {"vid": v.id})
func engReady(v: Dictionary) -> bool:
	var e = v.get("eng")
	return e == null or e.fuel == "none" or float(e.cond) > 0.02
func startRebuild(vid) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status != "ready": return false
	if not canStartJob(): return false
	var c := Tune.rebuildCost(v)
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	v.status = "upgrade"
	var days := int(ceil(3 + (1 - float(v.eng.cond)) * 10))
	G.jobs.append({"id": nid(), "type": "reb", "vid": vid, "left": days, "total": days, "req": D.RANK_REQ[D.BODY[v.body].rank]})
	say("Rebuilding %s's engine" % v.name)
	return true
## sys: {type:"efi"} or {type:"carb", carb:"fcr"}
func startSwap(vid, sys: Dictionary) -> bool:
	var v := veh(vid)
	if v.is_empty() or v.status != "ready": return false
	if not canStartJob(): return false
	var b: Dictionary = D.BODY[v.body]
	var c := Tune.efiCost(b) if sys.type == "efi" else Tune.carbSwapCost(b, sys.carb)
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	v.status = "upgrade"
	G.jobs.append({"id": nid(), "type": "swap", "vid": vid, "sys": sys, "left": 4, "total": 4, "req": D.RANK_REQ[b.rank]})
	say("Fitting %s to %s" % ["EFI" if sys.type == "efi" else D.CARBS[sys.carb].n, v.name])
	return true
func researchTech(id: String) -> bool:
	var t = D.TECHM.get(id)
	if t == null or Tune.has(id): return false
	if not techAvail(id).ok: return false
	if G.rp < t.rp: toast.emit("Not enough research data"); return false
	G.rp -= t.rp
	G.tech[id] = 1
	say("Tech unlocked: %s!" % t.n)
	sfx.emit("fanfare")
	research_done.emit(id)
	checkAch()
	return true
func techAvail(id: String) -> Dictionary:
	var t: Dictionary = D.TECHM[id]
	if Tune.has(id): return {"ok": true, "done": true}
	if int(G.ws) < int(t.ws): return {"ok": false, "why": "Needs " + D.WORKSHOPS[int(t.ws)].n}
	var miss := []
	for r in t.req:
		if not Tune.has(r): miss.append(D.TECHM[r].n)
	if not miss.is_empty(): return {"ok": false, "why": "Needs " + ", ".join(miss)}
	return {"ok": true}
func ach(id: String) -> bool:
	if G.get("ach") == null: G.ach = {}
	if G.ach.get(id): return false
	var a = D.ACHM.get(id)
	if a == null: return false
	G.ach[id] = int(G.day) + 1
	var rw: Dictionary = a.get("rw", {})
	if rw.get("cash"): G.money += float(rw.cash) * 1000
	if rw.get("rp"): G.rp += rw.rp
	if rw.get("spark"): G.sparks[rw.spark] += 1
	var r := []
	if rw.get("cash"): r.append(U.money(float(rw.cash) * 1000))
	if rw.get("rp"): r.append("%d RP" % int(rw.rp))
	if rw.get("spark"): r.append(SPARK_N[rw.spark] + " Spark")
	var rt := " + ".join(r)
	addLog("Achievement: %s" % a.n)
	_popup("%s Achievement!" % a.ic, a.n + "\n" + a.d + (("\nReward: " + rt) if rt != "" else ""), "achievement", {"ach": id})
	sfx.emit("fanfare")
	return true
func checkAch() -> void:
	for a in D.ACH:
		if G.ach.get(a.id): continue
		var c = _achChk(a.id)
		if c == true: ach(a.id)
## D.ACH[].chk ports (functions don't survive the JSON export). null = event-only achievement.
func _achChk(id: String):
	var st: Dictionary = G.st
	var wc: Dictionary = st.wc
	match id:
		"race1": return int(st.races) >= 1
		"win1": return int(st.wins) >= 1
		"pod10": return int(st.podiums) >= 10
		"win10": return int(st.wins) >= 10
		"win50": return int(st.wins) >= 50
		"win150": return int(st.wins) >= 150
		"title1": return st.titles.size() >= 1
		"title5": return st.titles.size() >= 5
		"world": return st.titles.any(func(t): return int(D.SER[t].tier) == 4)
		"legend": return st.titles.has("s5l")
		"bothways": return int(wc.get("w:cls:car", 0)) > 0 and int(wc.get("w:cls:bike", 0)) > 0
		"alldisc": return D.DISC.keys().all(func(k): return int(wc.get("w:disc:" + k, 0)) > 0)
		"rain": return int(wc.get("w:terr:wet", 0)) > 0
		"mud": return int(wc.get("w:terr:off", 0)) > 0
		"ice": return int(wc.get("w:terr:ice", 0)) > 0
		"factory": return int(G.ws) >= 4
		"fullgar": return G.vehicles.size() >= int(D.WORKSHOPS[int(G.ws)].veh) and int(G.ws) >= 2
		"mil": return float(G.money) >= 1e6
		"mil10": return float(G.money) >= 1e7
		"fans10k": return float(G.fans) >= 10000
		"fans100k": return float(G.fans) >= 100000
		"spon5": return G.sponDone.size() >= 5
		"tech10": return G.tech.size() >= 10
		"techall": return D.TECH.all(func(t): return bool(G.tech.get(t.id, false)))
		"mech10": return G.staff.any(func(s): return s.role == "mec" and int(s.lv) >= 10)
		"test10": return int(st.get("tests", 0)) >= 10
	return null
func vehXpNeed(v: Dictionary) -> float: return U.round(40 * pow(float(v.lv), 1.3))

# ======================================================================
# test day
# ======================================================================
func testCost(laps: int) -> int: return laps * 3000 * int(G.ws)
## Race def for a private test session (UI.A.tGo). Uses fmt laps as an override so the
## track cache keys on the lap count (the web reuses the first session's lap count).
func testDef(track_id: String, vid, sid, laps := 5) -> Dictionary:
	var tt: Dictionary = {}
	for t in D.TESTS:
		if t.id == track_id: tt = t
	var v := veh(vid); var s := staff(sid)
	var p := profile(v, s)
	if tt.style == "drag" or tt.style == "hill": laps = 3
	return {"id": tt.id, "n": tt.n, "tier": maxi(1, int(G.ws)), "disc": "OP", "cls": "any", "surf": tt.surf, "style": tt.style, "laps": 1,
		"R": maxf(10, (p.S + p.A + p.H) / 3 / 1.25), "prize": 0, "rp": 0, "alt": tt.get("alt", 200) if tt.get("alt") else 200,
		"alt2": tt.get("alt2") if tt.get("alt2") else (tt.alt if tt.get("alt") else 200), "temp": 20, "_testLaps": laps}
func startTest(track_id: String, vid, sid, laps := 5) -> RaceSim:
	var def := testDef(track_id, vid, sid, laps)
	var n := int(def._testLaps)
	var cond := Tune.forecast(def)
	return makeRace(def, vid, sid, {"test": true, "rivals": [], "fmt": {"id": "test", "kind": "tt", "laps": n, "mul": {"prize": 0, "rp": 0, "fans": 0, "wear": 0.4}}, "cond": cond})
func finishTest(rs: RaceSim) -> Dictionary:
	var P := rs.player()
	var v := veh(P.vid); var s := staff(P.sid)
	var laps := int(rs.tr.laps)
	var out := {"gains": []}
	G.money -= testCost(laps)
	s.energy = maxf(0, float(s.energy) - (8 + 2 * laps))
	G.st.tests = int(G.st.get("tests", 0)) + 1
	var n := maxi(1, int(floor(laps / 3.0)))
	for i in n:
		var k: String = U.pick(["pedal", "shift", "steer"])
		s[k] += 1; out.gains.append(k)
	var cls: String = D.BODY[v.body].cls
	s.aff[cls] = U.fixed(minf(1.45, float(s.aff[cls]) + 0.004 * laps), 3)
	v.xp += laps * 2
	while int(v.lv) < 10 and float(v.xp) >= vehXpNeed(v):
		v.xp -= vehXpNeed(v); v.lv += 1
	if v.get("eng") != null and v.eng.fuel != "none":
		v.eng.cond = U.clamp((float(P.cond) if P.get("cond") != null else float(v.eng.cond)) - 0.002 * laps, 0, 1)
		v.eng.log = Tune.makeLog(v, rs.cond, "Test: " + rs.def.n)
	v.hp = U.clamp(float(P.hp), 0, 1)
	if float(v.hp) < 0.999:
		var days := maxi(1, int(ceil((1 - float(v.hp)) * 14)))
		v.status = "repair"
		G.jobs.append({"id": nid(), "type": "rep", "vid": v.id, "left": days, "total": days, "req": D.RANK_REQ[D.BODY[v.body].rank], "nob": true})
	checkAch()
	addLog("Test day: %d laps with %s" % [laps, v.name])
	return out

# ======================================================================
# time
# ======================================================================
## Story pacing: the Short campaign runs hotter (race rewards and shop speed) so it lands near an hour;
## Medium a little. Free careers and free play after the ending run at the web build's rates.
func paceMul() -> float:
	var st = G.get("story")
	if typeof(st) != TYPE_DICTIONARY or not st.get("on", false) or st.get("done", false) or st.get("free", false): return 1.0
	return float({"short": 1.6, "medium": 1.2}.get(str(st.get("len", "")), 1.0))

func jobRate(job: Dictionary) -> float:
	var n := 0
	for j in G.jobs:
		if not j.get("nob", false): n += 1
	var share: float = 1.0 if job.get("nob", false) else 1 + 0.35 * maxi(0, n - 1)
	var lazy: float = 0.6 if (G.get("lazyUntil") and float(G.lazyUntil) > float(G.day)) else 1.0
	return U.clamp(0.5 + 0.7 * teamTech() / float(job.req), 0.5, 1.8 if job.type == "build" else 2.6) * (1 + facV("speed") / 100) / share * lazy * (1.0 + (paceMul() - 1.0) * 0.6)

func _drop_job(j: Dictionary) -> void:
	for i in G.jobs.size():
		if is_same(G.jobs[i], j): G.jobs.remove_at(i); return

## E.tick: advance one game day.
func tick() -> void:
	G.day = int(G.day) + 1
	for j in G.jobs.duplicate():
		var v := veh(j.vid)
		if v.is_empty(): _drop_job(j); continue
		if j.type == "build":
			if tickBuild(j, v):
				_drop_job(j); finishBuild(v)
			continue
		j.left -= jobRate(j)
		if j.type == "rep": v.hp = minf(1, float(v.hp) + (1.0 / 14) * jobRate(j))
		if j.left <= 0:
			_drop_job(j)
			match j.type:
				"up": finishUpgrade(v, j)
				"rep": v.hp = 1; v.status = "ready"; addLog("%s repaired" % v.name)
				"reb":
					v.eng.cond = 1; v.status = "ready"
					say("%s: fresh engine!" % v.name); _float("Rebuilt!", v.id, "#8ef58e")
				"swap":
					var keep = v.eng.get("fuelT", "pump")
					Tune.initEng(v, j.sys); v.eng.fuelT = keep; v.status = "ready"
					say("%s: %s" % [v.name, "EFI installed — base map loaded, go tune it!" if j.sys.type == "efi" else D.CARBS[j.sys.carb].n + " fitted"])
					if j.sys.type == "efi": ach("efi1")
	var regen := 1.6 + facV("regen")
	for s in drivers(): s.energy = minf(float(s.maxE), float(s.energy) + regen)
	for id in G.series:
		var a = G.series[id].get("act")
		if a != null and not a.pending and int(G.day) >= int(a.next):
			a.pending = true
			round_due.emit(id)
	if U.chance(0.018): randomEvent()
	if int(G.day) % DAYS_MONTH == 0: monthly()
	if int(G.day) % DAYS_YEAR == 0: yearly()
	day_passed.emit(int(G.day))
	refresh.emit()

func monthly() -> void:
	var sal := U.sum(G.staff, func(s): return s.salary)
	var sp := U.sum(G.spons, func(s): return sponsorPay(s))
	var merch := U.round(float(G.fans) * facV("merch"))
	G.money += sp + merch - sal
	G.lastMonth = {"sal": sal, "sp": sp, "merch": merch}
	addLog("Month end: sponsors +%s%s, salaries -%s" % [U.money(sp), (", merch +" + U.money(merch)) if merch else "", U.money(sal)])
	if G.money < 0: toast.emit("⚠ In the red! Race, sign sponsors or do Odd Jobs.")
	refreshCandidates()
	checkSponsors()
	checkAch()
	G.wxRain = U.chance(0.2)

func yearly() -> void:
	var y := year() - 1
	var rank := fanRank()
	var bonus := rank * rank * 40000
	G.money += bonus
	var yr: Dictionary = G.year
	G.year = {"wins": 0, "podiums": 0, "earn": 0, "titles": 0}
	G.yearWins = {}
	year_end.emit({"y": y, "yr": yr, "bonus": bonus, "rank": rank})
	if y >= YEARS and not G.ended:
		G.ended = true
		game_end.emit()

func score() -> int:
	var t := 0.0
	for id in G.st.titles: t += [0, 100, 300, 800, 2000, 5000][int(D.SER[id].tier)]
	return int(U.round(t + float(G.st.wins) * 20 + float(G.st.podiums) * 5 + float(G.fans) / 50 + maxf(0, float(G.money)) / 50000 + float(G.ws) * 200))

# ======================================================================
# random events (E.EVENTS)
# ======================================================================
func randomEvent() -> void:
	var tot := 0.0
	for w in EVENT_W: tot += w
	var r := U.random() * tot
	for i in EVENT_W.size():
		r -= EVENT_W[i]
		if r <= 0:
			var t = _event(i)
			if t != null: say(t)
			return

func _event(i: int):
	match i:
		0:
			var m := U.ri(5, 20) * 1000 * (1 + fanRank())
			G.money += m
			return "A fan sent a care package! +%s" % U.money(m)
		1:
			var s = U.pick(mechs())
			if s == null: return null
			var r := U.ri(3, 8) + int(G.ws) * 3
			G.rp += r
			_float("Idea!", null, "#ffe066")
			return "%s had a brainstorm! +%d RP" % [s.name, r]
		2:
			var f := U.round(30 + float(G.fans) * 0.04)
			G.fans += f
			return "A racing magazine featured the team! +%d fans" % int(f)
		3:
			var s = U.pick(mechs())
			if s == null: return null
			G.lazyUntil = int(G.day) + 5
			return "%s is slacking off... work slows for a few days." % s.name
		4:
			giveSpark("b", "")
			return "Found an old trophy in the parts bin. It sparkles!"
		5:
			var s = U.pick(drivers())
			s.appeal += 2
			return "%s signed autographs for local kids. Appeal +2" % s.name
		6:
			var s = U.pick(G.staff)
			if s == null: return null
			s.tech += 2
			return "%s learned a new trick from a video. Tech +2" % s.name
		7:
			if fanRank() < 2: return null
			var m := 50000 * fanRank()
			G.money += m
			return "An investor was impressed! +%s" % U.money(m)
		8:
			var d = U.pick(drivers())
			d.energy = minf(float(d.maxE), float(d.energy) + 30)
			return "%s had a great night's sleep. Energy +30" % d.name
		9:
			G.wxRain = true
			return "Weather service: rain likely at the next tarmac race."
		10:
			var m := U.ri(10, 30) * 1000
			G.money += m
			return "The team bake sale was a hit! +%s" % U.money(m)
	return null

# ======================================================================
# staged build process (build.js)
# ======================================================================
func bOpts(v: Dictionary, ph: String) -> Array:
	var b: Dictionary = D.BODY[v.body]
	var o = D.BOPT[ph]
	if o is Array: return o
	if ph == "engine": return o.elec if int(D.LAYOUT_CYL.get(v.layout, 4)) == 0 else o.ice
	return o[b.cls]
func bCost(o: Dictionary, v: Dictionary) -> int:
	if not o.get("cost"): return 0
	var c := int(U.round(float(o.cost) * float(D.BODY[v.body].cost) / 1000) * 1000)
	if o.get("min"): return int(signf(c) * maxf(absf(c), float(o.min)))
	return c
func bReq(o: Dictionary, v: Dictionary) -> Dictionary:
	var r: Dictionary = o.get("req", {})
	if r.get("ws") and int(G.ws) < int(r.ws): return {"ok": false, "why": "Needs " + D.WORKSHOPS[int(r.ws)].n}
	if r.get("tech") and not Tune.has(r.tech): return {"ok": false, "why": "Tech: " + D.TECHM[r.tech].n}
	if r.get("fac") and not facLv(r.fac): return {"ok": false, "why": "Needs " + D.FAC[r.fac].n}
	if r.get("q") and buildQ(v.body) < float(r.q): return {"ok": false, "why": "Team skill %d%% (need %d%%)" % [U.iround(buildQ(v.body) * 100), U.iround(float(r.q) * 100)]}
	var c := bCost(o, v)
	if c > 0 and G.money < c: return {"ok": false, "why": "Not enough money"}
	return {"ok": true}
## Effect summary text for a build option.
func bFx(o: Dictionary, v: Dictionary) -> String:
	var a := []
	var m: Dictionary = o.get("m", {})
	for k in m:
		if k == "rand": a.append("random stat +%d%%" % int(m[k])); continue
		a.append("%s %s%d%%" % [k.to_upper(), "+" if m[k] > 0 else "", int(m[k])])
	var t: Dictionary = o.get("t", {})
	for k in t: a.append("%s %s%d" % [D.TERR_N[k], "+" if t[k] > 0 else "", int(t[k])])
	if o.get("adv"): a.append("Ad appeal %s%d" % ["+" if o.adv > 0 else "", int(o.adv)])
	if o.get("slot"): a.append("+1 part slot")
	if o.get("gamble"):
		var w := []
		for k in o.gamble.win: w.append("%s +%d%%" % [k.to_upper(), int(o.gamble.win[k])])
		a.append("%d%%: %s" % [U.iround(float(o.gamble.p) * 100), " ".join(w) if not w.is_empty() else "fine"])
	var c := bCost(o, v)
	if c: a.append(U.money(c) if c > 0 else "saves " + U.money(-c))
	if o.get("money"): a.append("+" + U.money(U.round(float(o.money) * float(D.BODY[v.body].cost) / 1000) * 1000))
	if o.get("days"): a.append("%s%d days" % ["+" if o.days > 0 else "", int(o.days)])
	if o.get("fans"): a.append("+fans")
	return " · ".join(a)
func bJob(vid) -> Dictionary:
	for j in G.jobs:
		if j.vid == vid and j.type == "build": return j
	return {}
func bMerge(v: Dictionary, o: Dictionary, scale := 1.0) -> void:
	if v.get("bm") == null: v.bm = {"spd": 0, "acc": 0, "hnd": 0, "dur": 0, "on": 0, "off": 0, "wet": 0, "ice": 0, "adv": 0}
	var bm: Dictionary = v.bm
	var m: Dictionary = o.get("m", {})
	for k in m:
		if k == "rand":
			var kk: String = U.pick(STATS)
			bm[kk] += m.rand
			continue
		bm[k] += float(m[k]) * scale
	var t: Dictionary = o.get("t", {})
	for k in t: bm[k] += t[k]
	if o.get("adv"): bm.adv += o.adv
	if o.get("slot"): v.slotB = int(v.get("slotB", 0)) + int(o.slot)
	if o.get("flag"):
		if v.get("bflags") == null: v.bflags = []
		v.bflags.append(o.flag)
func bWaitNext(j: Dictionary, v: Dictionary) -> void:
	var ph: String = D.BPH[int(j.pi)]
	if int(j.pi) >= 1 and int(j.get("evN", 0)) < 3 and U.chance(0.3):
		var evs: Array = j.get("evs", [])
		var ice_ok: bool = int(D.LAYOUT_CYL.get(v.layout, 4)) != 0
		var pool := []
		for e in D.BEV:
			if not evs.has(e.id) and (not e.get("ice") or ice_ok) and (not e.get("spon") or G.spons.size()): pool.append(e)
		if not pool.is_empty():
			var e: Dictionary = U.pick(pool)
			j.evs = evs + [e.id]
			j.evN = int(j.get("evN", 0)) + 1
			var mech = U.pick(mechs()); if mech == null: mech = {"name": "The crew"}
			var drv = U.pick(drivers()); if drv == null: drv = {"name": "Your driver"}
			var sp: String = D.SPON[U.pick(G.spons).id].n if G.spons.size() else ""
			j.wait = {"k": "ev", "ev": e.id, "txt": e.d.replace("{m}", mech.name).replace("{d}", drv.name).replace("{s}", sp), "drv": drv.get("id"), "next": ph}
			j.asked = false
			return
	j.wait = {"k": "ph", "ph": ph}
	j.asked = false
## Answer a build decision: idx = option index, or "crew" to let the crew decide.
func bChoose(vid, idx) -> bool:
	var j := bJob(vid)
	var v := veh(vid)
	if j.is_empty() or v.is_empty() or j.get("wait") == null: return false
	var w: Dictionary = j.wait
	var crew: bool = idx is String and idx == "crew"
	var o = null
	if w.k == "ph":
		var opts := bOpts(v, w.ph)
		if crew:
			for x in opts:
				if x.get("crew") and bReq(x, v).ok: o = x; break
			if o == null:
				for x in opts:
					if bReq(x, v).ok and not bCost(x, v): o = x; break
			if o == null:
				for x in opts:
					if bReq(x, v).ok: o = x; break
		elif int(idx) >= 0 and int(idx) < opts.size(): o = opts[int(idx)]
		if o == null or not bReq(o, v).ok: return false
	else:
		var e: Dictionary = D.BEVM[w.ev]
		if crew: o = e.o[e.o.size() - 1]
		elif int(idx) >= 0 and int(idx) < e.o.size(): o = e.o[int(idx)]
		if o == null: return false
		var c0 := bCost(o, v)
		if c0 > 0 and G.money < c0: return false
	var c := bCost(o, v)
	G.money -= c
	if o.get("money"): G.money += U.round(float(o.money) * float(D.BODY[v.body].cost) / 1000) * 1000
	if o.get("days"):
		var pi := int(j.pi)
		j.pd[pi] = maxf(0.2, float(j.pd[pi]) + float(o.days))
		j.total = maxf(1, float(j.total) + float(o.days))
	var note := ""
	if o.get("gamble"):
		if U.chance(float(o.gamble.p)):
			bMerge(v, {"m": o.gamble.win}); note = " — it worked!"; _float("Nice!", v.id, "#8ef58e")
		else:
			bMerge(v, {"m": o.gamble.lose}); note = " — no luck."; _float("Oops", v.id, "#ff9a9a")
	else: bMerge(v, o)
	if o.get("fans"): G.fans += U.round(40 + float(G.fans) * 0.02)
	if o.get("drv"):
		var s := staff(w.get("drv"))
		if not s.is_empty():
			s.energy = maxf(0, float(s.energy) - 10)
			var cls: String = D.BODY[v.body].cls
			s.aff[cls] = U.fixed(minf(1.45, float(s.aff[cls]) + 0.02), 2)
	if v.get("blog") == null: v.blog = []
	v.blog.append(("%s: %s" % [D.BPHN[w.ph], o.n]) if w.k == "ph" else ("%s: %s%s" % [D.BEVM[w.ev].n, o.n, note]))
	if w.k == "ph":
		if j.get("ch") == null: j.ch = {}
		j.ch[w.ph] = o.id
		j.wait = null
	else:
		j.wait = {"k": "ph", "ph": w.next}
		j.asked = false
	j.left = U.sum(j.pd.slice(int(j.pi)))
	if w.k == "ph": say("%s: %s" % [v.name, o.n])
	return true
## UI.A.bDecide: ask again about a build decision that is still waiting (e.g. its popup was closed).
func bDecide(vid) -> void:
	var j := bJob(vid)
	if not j.is_empty() and j.get("wait") != null:
		j.asked = true
		_buildAsk(j)
func _buildAsk(j: Dictionary) -> void:
	if build_ask.get_connections().is_empty():
		var v := veh(j.vid)
		if not v.is_empty(): bChoose(v.id, "crew")
	else: build_ask.emit(j)
func tickBuild(j: Dictionary, v: Dictionary) -> bool:
	var ph := [0.3, 0.6, 0.9]
	if j.get("pd") == null:
		j.left -= jobRate(j)
		var prog: float = 1 - float(j.left) / float(j.total)
		while int(j.ph) < 3 and prog >= ph[int(j.ph)]:
			buildPhase(v, j); j.ph += 1
		return j.left <= 0
	if j.get("wait") != null:
		if not j.get("asked", false):
			j.asked = true; _buildAsk(j)
		return false
	var pi := int(j.pi)
	j.pd[pi] -= jobRate(j)
	if float(j.pd[pi]) <= 0 and pi < 7:
		var carry_: float = j.pd[pi]
		j.pi = pi + 1
		j.pd[pi + 1] += carry_
		bWaitNext(j, v)
	j.left = maxf(0, U.sum(j.pd.slice(int(j.pi))))
	var prog2: float = 1 - float(j.left) / float(j.total)
	while int(j.ph) < 3 and prog2 >= ph[int(j.ph)]:
		buildPhase(v, j); j.ph += 1
	if j.get("wait") != null and not j.get("asked", false):
		j.asked = true; _buildAsk(j)
	return int(j.pi) == 7 and float(j.pd[7]) <= 0 and j.get("wait") == null

# ======================================================================
# bench (engine/tune actions from web/src/ui2.js, minus the UI)
# ======================================================================
func adjJet(vid, k: String, dir: int) -> void:
	var v := veh(vid)
	var C: Dictionary = D.CARBS[v.eng.carb]
	for p in C.p:
		if p.k == k:
			v.eng.jets[k] = U.fixed(U.clamp(float(v.eng.jets.get(k, p.stock)) + dir * float(p.step), p.min, p.max), 2)
	ach("jet1")
func adjTiming(vid, dir: int) -> void:
	var v := veh(vid)
	v.eng.timing = int(U.clamp(float(v.eng.timing) + dir, -6, 8))
func resetJets(vid) -> void:
	var v := veh(vid)
	Tune.stockJets(v); v.eng.timing = 0
## Paid crew tune for a condition (Standard mode, Crew Chief tech).
func buyCrewTune(vid, cond: Dictionary) -> bool:
	var v := veh(vid)
	var c := Tune.crewCost()
	if G.money < c: toast.emit("Not enough money"); return false
	G.money -= c
	Tune.crewTune(v, cond, 0.96)
	return true
func adjSync(vid, i: int, dir: int) -> void:
	var v := veh(vid)
	var g := Tune.has("syncgauge")
	v.eng.sync[i] = U.fixed(U.clamp(float(v.eng.sync[i]) + dir * (0.2 if g else 0.6) + (0.0 if g else U.rand(-0.25, 0.25)), -6, 6), 1)
	var bi := Tune.syncBase(v.eng.sync.size())
	if v.eng.sync.size() == 4:
		var ok := true
		for k in 4:
			if k != bi and absf(float(v.eng.sync[k])) > 0.3: ok = false
		if ok: ach("sync4")
## Spot On check after a tune change (needs a wideband).
func checkSpot(v: Dictionary, cond: Dictionary) -> void:
	if not Tune.has("wideband"): return
	var ev := Tune.eval(v, cond)
	for z in Tune.ZONES:
		if absf(float(ev.lam[z]) - float(D.LAM[z])) > 0.02: return
	ach("spoton")
## EFI table edit: table "ve" | "ign" | "afr"; cells [[j,i],...]; op "+1", "-1", "+5%", "-5%".
func adjCells(vid, table: String, cells: Array, op: String) -> void:
	var v := veh(vid)
	var tb: Array = v.eng.efi[table]
	for c in cells:
		var j: int = c[0]; var i: int = c[1]
		var x: float = tb[j][i]
		if op.ends_with("%"): x *= 1 + op.trim_suffix("%").to_float() / 100
		else: x += (op.to_float() * 0.1) if table == "afr" else op.to_float()
		tb[j][i] = U.fixed(U.clamp(x, 9.5, 16.5), 1) if table == "afr" else U.round(U.clamp(x, -5 if table == "ign" else 5, 55 if table == "ign" else 180))
	G.st.cells = int(G.st.get("cells", 0)) + cells.size()
	if int(G.st.cells) >= 50: ach("cells")
func smoothCells(vid, table: String, cells: Array) -> void:
	if cells.size() < 2: return
	var v := veh(vid)
	var tb: Array = v.eng.efi[table]
	var cp := tb.duplicate(true)
	for c in cells:
		var j: int = c[0]; var i: int = c[1]
		var s := 0.0; var n := 0
		for d in [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]:
			var jj: int = j + d[0]; var ii: int = i + d[1]
			if jj >= 0 and jj < 6 and ii >= 0 and ii < 8: s += float(cp[jj][ii]); n += 1
		tb[j][i] = U.round(s / n)
## VE Analyze: apply the last wideband datalog to the VE table. -> cells changed
func veAnalyze(vid) -> int:
	var v := veh(vid)
	var f: Dictionary = v.eng.efi
	var lg = v.eng.get("log")
	if lg == null or lg.get("cells") == null: return 0
	var vis := {}
	for z in Tune.ZC:
		for c in Tune.ZC[z]: vis["%d,%d" % [c[0], c[1]]] = [c[0], c[1]]
	for i in 8:
		vis["4,%d" % i] = [4, i]; vis["5,%d" % i] = [5, i]
	var n := 0
	for k in vis:
		var j: int = vis[k][0]; var i: int = vis[k][1]
		var m: float = lg.cells[j][i]
		var tg: float = float(f.afr[j][i]) / 14.7
		var nv := U.round(float(f.ve[j][i]) * m / tg)
		if nv != float(f.ve[j][i]):
			f.ve[j][i] = U.clamp(nv, 5, 180); n += 1
	v.eng.log = null
	ach("veal1")
	return n
func efiBase(vid) -> void: Tune.initEFI(veh(vid))
func adjAE(vid, dir: int) -> void:
	var v := veh(vid)
	v.eng.efi.ae = U.clamp(float(v.eng.efi.ae) + dir * 5, 0, 250)
func setFuelT(vid, f: String) -> void:
	var F: Dictionary = D.FUELS[f]
	if F.get("tech") and not Tune.has(F.tech): return
	veh(vid).eng.fuelT = f
## Setup sheet stepper: key f | r | fd | susp | psi | wing.
func adjSetup(vid, key: String, dir: int) -> void:
	var st: Dictionary = veh(vid).setup
	match key:
		"f": st.f = U.clamp(float(st.f) + dir, 11, 19)
		"r": st.r = U.clamp(float(st.r) + dir, 34, 60)
		"fd": st.fd = U.fixed(U.clamp(float(st.fd) + dir * 0.05, 2.8, 4.8), 2)
		"susp": st.susp = U.clamp(float(st.susp) + dir, 1, 10)
		"psi": st.psi = U.clamp(float(st.psi) + dir, 8, 44)
		"wing": st.wing = U.clamp(float(st.wing) + dir, 0, 15)
func stockSetup(vid) -> void:
	var v := veh(vid)
	v.setup = Tune.defaultSetup(v)
func setMode(m: String) -> void: G.settings.mode = m

# ======================================================================
# save / load
# ======================================================================
## E.serialize: the web save JSON (integral numbers written without ".0").
func serialize() -> String: return to_json(G)

## Web save code (Save.exportCode).
func exportCode() -> String: return "GG1:" + Marshalls.utf8_to_base64(serialize())

## E.load(+ Save.importCode): JSON text or a "GG1:" base64 code. Returns false on a bad save.
func load_json(text: String) -> bool:
	_bind_data()
	var s := text.strip_edges()
	if s.begins_with("GG1:"):
		var raw := s.substr(4)
		for ws_ch in [" ", "\n", "\r", "\t"]: raw = raw.replace(ws_ch, "")
		s = Marshalls.base64_to_utf8(raw)
	var o = parse_json_exact(s)
	if not (o is Dictionary) or o.get("v") == null or int(o.v) != 1 or o.get("team") == null:
		push_warning("Career.load_json: bad save")
		return false
	o = _ints(o)
	G = o
	var st := {"speed": 1, "autoRetire": true, "sound": true, "mode": "standard"}
	st.merge(G.get("settings", {}), true)
	G.settings = st
	if G.st.get("wc") == null: G.st.wc = {}
	if G.get("year") == null: G.year = {"wins": 0, "podiums": 0, "earn": 0, "titles": 0}
	if G.get("tech") == null: G.tech = {"carbbasic": 1}
	if G.get("ach") == null: G.ach = {}
	if not G.st.get("tests"): G.st.tests = 0
	if not G.st.get("streak"): G.st.streak = 0
	if not G.st.get("cells"): G.st.cells = 0
	for v in G.vehicles:
		if v.get("eng") == null: Tune.initEng(v, null)
		Tune.fillJets(v)
		if v.get("setup") == null: v.setup = Tune.defaultSetup(v)
	for j in G.jobs: j.asked = false
	refresh.emit()
	return true

## JSON.parse_string, but every non-integer number is the exact double the text names
## (Godot's parser can land 1 ulp off on 16-17 digit numbers; V8 is exact, so web saves would drift).
static var _num_re: RegEx = null
static func parse_json_exact(text: String):
	var o = JSON.parse_string(text)
	if not (o is Dictionary or o is Array): return o
	if _num_re == null:
		_num_re = RegEx.new()
		_num_re.compile("\"(?:[^\"\\\\]|\\\\.)*\"|-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?")
	var toks := PackedStringArray()
	for m in _num_re.search_all(text):
		var t := m.get_string()
		if not t.begins_with("\""): toks.append(t)
	if _count_nums(o) != toks.size(): return o
	_fix_nums(o, toks, [0])
	return o

static func _count_nums(x) -> int:
	if x is Dictionary:
		var n := 0
		for k in x: n += _count_nums(x[k])
		return n
	if x is Array:
		var n2 := 0
		for e in x: n2 += _count_nums(e)
		return n2
	return 1 if (x is float or x is int) else 0

static func _fix_nums(x, toks: PackedStringArray, k: Array):
	if x is Dictionary:
		for key in x: x[key] = _fix_nums(x[key], toks, k)
		return x
	if x is Array:
		for i in x.size(): x[i] = _fix_nums(x[i], toks, k)
		return x
	if x is float or x is int:
		var t: String = toks[k[0]]
		k[0] += 1
		if x is float and (t.contains(".") or t.contains("e") or t.contains("E")): return _exact(x, t)
	return x

static func _exact(x: float, t: String) -> float:
	if _fmt_float(x) == t: return x
	var b := PackedByteArray()
	b.resize(8)
	for d in [1, -1, 2, -2, 3, -3]:
		b.encode_double(0, x)
		b.encode_s64(0, b.decode_s64(0) + (d if x >= 0 else -d))
		var y := b.decode_double(0)
		if _fmt_float(y) == t: return y
	return x

## Shortest round-trip decimal like JS Number#toString (exponent written 1e-7 / 1e+21).
static func _fmt_float(x: float) -> String:
	var s := JSON.stringify(x, "", false, true)
	var e := s.find("e")
	if e < 0: return s
	var ex := s.substr(e + 1)
	var neg := ex.begins_with("-")
	ex = ex.trim_prefix("-").trim_prefix("+").lstrip("0")
	return s.substr(0, e) + ("e-" if neg else "e+") + (ex if ex != "" else "0")

## JSON numbers arrive as floats: make integral ones ints so ids, days and counters behave like JS numbers.
static func _ints(x):
	if x is Dictionary:
		for k in x: x[k] = _ints(x[k])
		return x
	if x is Array:
		for i in x.size(): x[i] = _ints(x[i])
		return x
	if x is float and is_finite(x) and x == floor(x) and absf(x) < 9007199254740992.0: return int(x)
	return x

static func to_json(x) -> String:
	match typeof(x):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "true" if x else "false"
		TYPE_INT: return str(x)
		TYPE_FLOAT:
			if not is_finite(x): return "null"
			if x == floor(x) and absf(x) < 9007199254740992.0: return str(int(x))
			return _fmt_float(x)
		TYPE_STRING, TYPE_STRING_NAME: return JSON.stringify(str(x))
		TYPE_DICTIONARY:
			var parts := PackedStringArray()
			for k in x: parts.append(JSON.stringify(str(k)) + ":" + to_json(x[k]))
			return "{" + ",".join(parts) + "}"
		TYPE_ARRAY:
			var p2 := PackedStringArray()
			for e in x: p2.append(to_json(e))
			return "[" + ",".join(p2) + "]"
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return to_json(Array(x))
	return JSON.stringify(x)
