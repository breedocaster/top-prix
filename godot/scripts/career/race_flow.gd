class_name RaceFlow
extends RefCounted
## One career race in any format, as a small state machine a UI or bot can drive.
## Port of the web UI orchestration in web/src/ui2.js: UI.startRace, heats + main (UI.heatsStart),
## the 8-car drag elimination ladder (UI.dragStart/dragRound/dragFinish) and hillclimb best-of-2
## (UI.hillStart/hillRun/hillFinish). Plain sprints, features, endurance and rally stages are one stage.
##
##   var f := Career.startRace(race_id, vid, sid, "normal", series_id, fmt_id)
##   while not f.done:
##       f.rs.run_instant()                 # or step f.rs in a RaceView
##       var panel := f.stage_done()        # summary of the stage just run (see below)
##       # between stages the player may retune (Career bench helpers) when panel.can_retune
##       if panel.can_next: f.next() else: f.finish()
##   f.result                               # Career.finishRace output; series round already scored
##
## panel keys: stage ("race"|"heat"|"main"|"drag"|"hill"), can_next, can_retune, final, plus
## heat: pos, dnf, order[team], dead, slot, grid_size; drag: round_name, win, et, opp, opp_et, dead;
## hill: run, time, table[[team, time]], dead.
## Several team entries (opts.entries = [[vid, sid], ...], Career.entryCap): every car runs in the same
## race / heat / hill run together; panels then also carry `mine` = one row per entry. The drag ladder
## takes one car (Career.multiEntryOk).

var kind := "race"            # race | heats | drag | hill
var def: Dictionary
var vid
var sid
var entries: Array = []       # [[vid, sid], ...]; entries[0] is the lead car (vid/sid)
var tactic := "normal"
var series_id = null
var fmt: Dictionary
var rivals: Array = []
var rs: RaceSim = null        # race of the current stage
var stage := ""
var done := false
var result: Dictionary = {}
var panel: Dictionary = {}
var _checked := false
# heats
var _other: Array = []
var _hf: Dictionary = {}
var _grid: Array = []
var _slot := 0
var _heat_pos := 0
# drag
var _alive: Array = []
var _out: Array = []
var best_et = null
var _pairs: Array = []
var _mine: Array = []
var _opp = null
# hill
var run := 1
var _best := {}
var p_best := INF
var _pbest := {}              # entry index -> best run

## opts.dyn: an extra rival (the story dynasty, Story.rival_for) swapped into the field in place of
## the weakest rival (same field size; series rival lists are copied, never edited).
func _init(d: Dictionary, v_id, s_id, tac := "normal", ser = null, fmt_id := "", opts: Dictionary = {}) -> void:
	def = d; vid = v_id; sid = s_id; tactic = tac; series_id = ser
	var fs: Array = Data.formats(def.id)
	if ser != null: fmt = Career.seriesFormat(def)
	else:
		fmt = fs[0]
		for f in fs:
			if f.id == fmt_id: fmt = f
	entries = [[vid, sid]]
	if opts.get("entries") is Array and Career.multiEntryOk(fmt):
		for en in opts.entries:
			if entries.size() >= Career.entryCap(): break
			if en[0] == vid or en[1] == sid or entries.any(func(x): return x[0] == en[0] or x[1] == en[1]): continue
			entries.append([en[0], en[1]])
	if ser != null: rivals = Career.G.series[ser].act.rivals
	var dyn: Dictionary = opts.get("dyn", {}) if opts.get("dyn") is Dictionary else {}
	if not dyn.is_empty():
		if rivals.is_empty():
			rivals = Career.mkRivals(def, 7 if fmt.kind == "drag" else (Career.RIVAL_N[int(def.tier)] if int(def.tier) < Career.RIVAL_N.size() else 11))
		rivals = with_rival(rivals, dyn)
	if fmt.kind == "drag": kind = "drag"; _drag_start()
	elif fmt.kind == "heats": kind = "heats"; _heats_start()
	elif fmt.kind == "tt" and int(fmt.get("runs", 1)) == 2: kind = "hill"; _hill_start()
	else:
		kind = "race"; stage = "race"
		rs = _make(fmt, rivals if not rivals.is_empty() else null)

## A copy of `list` with `r` in it: replaces a rival of the same team, else the weakest (last) one.
static func with_rival(list: Array, r: Dictionary) -> Array:
	var out := list.filter(func(x): return str(x.get("team", "")) != str(r.get("team", "")))
	if out.size() >= list.size() and not out.is_empty(): out.pop_back()
	out.push_front(r.duplicate())
	return out

func _make(f: Dictionary, rv, extra := {}) -> RaceSim:
	var o := {"fmt": f, "series": series_id, "tactic": tactic, "entries": entries}
	if rv != null: o.rivals = rv
	o.merge(extra, true)
	return Career.makeRace(def, vid, sid, o)

func _player() -> Dictionary: return rs.player()
func _players() -> Array: return rs.players()
func _veh() -> Dictionary: return Career.veh(vid)
func multi() -> bool: return entries.size() > 1
func _carry_all() -> void:
	for P in _players(): Career.carry(Career.veh(P.vid), P)
func _all_dead() -> bool: return _players().all(func(P): return _dead(P))
func _mark(P: Dictionary) -> String: return "P%d" % int(P.get("entry", 0))
## Name for a team car in tables: the team (one car) or the driver (several).
func ent_name(P: Dictionary) -> String: return str(Career.G.team.name) if not multi() else str(P.name)
func _dead(P: Dictionary) -> bool:
	return P.get("holed", false) or P.get("destroyed", false) or P.get("seized", false) or float(P.hp) < 0.15 or (P.get("cond") != null and float(P.cond) <= 0.1)
func _retune_ok() -> bool: return Tune.has("quickchange") or Tune.mode() != "sim"

## Call once the current stage's race is done. Returns (and stores) the stage panel.
func stage_done() -> Dictionary:
	if _checked: return panel
	_checked = true
	match stage:
		"race", "main": panel = {"stage": stage, "can_next": false, "can_retune": false, "final": true}
		"heat": panel = _heat_done()
		"drag": panel = _drag_done()
		"hill": panel = _hill_done()
	return panel

## Run the next stage (heat -> main, next drag round, hill run 2). Finishes when there is none.
func next() -> void:
	if done: return
	if not _checked: stage_done()
	if not panel.get("can_next", false):
		finish(); return
	_checked = false
	match stage:
		"heat": _start_main()
		"drag": _drag_round()
		"hill":
			run = 2
			_hill_run()

## End the flow and score it (also the web's "Keep run 1", "Results" and "leave without running").
func finish() -> Dictionary:
	if done: return result
	if not _checked: stage_done()
	match stage:
		"race", "main": result = Career.raceResult(rs)
		"heat":
			rs.fmt = fmt
			for P in _players(): P.dnf = true
			result = Career.raceResult(rs)
		"drag": result = _drag_finish()
		"hill": result = _hill_finish()
	result.flow = kind
	done = true
	return result

# ---------------- heats + main ----------------
func _heats_start() -> void:
	if rivals.is_empty(): rivals = Career.mkRivals(def, Career.RIVAL_N[int(def.tier)])
	var sh := U.shuffle(rivals)
	var half := int(floor(sh.size() / 2.0))
	var mine := sh.slice(0, half)
	_other = sh.slice(half)
	_hf = {"id": "heat", "kind": "mass", "laps": fmt.heatLaps, "mul": {"prize": 0, "rp": 0, "fans": 0, "wear": 0.5}}
	stage = "heat"
	rs = _make(_hf, mine)

func _heat_done() -> Dictionary:
	var P := _player()
	_carry_all()
	var my_ord := []
	for e in rs.order: my_ord.append(_mark(e) if e.human else e.ref)
	var timed := []
	for r in _other: timed.append([r, Career.quickTime(def, r, _hf)])
	var oth := U.sort_by(timed, func(x): return x[1]).map(func(x): return x[0])
	_grid = []
	for i in maxi(my_ord.size(), oth.size()):
		if i < my_ord.size(): _grid.append(my_ord[i])
		if i < oth.size(): _grid.append(oth[i])
	_slot = _grid.find(_mark(P))
	_heat_pos = my_ord.find(_mark(P)) + 1
	var dead := _all_dead()
	var names := []
	for e in rs.order: names.append(ent_name(e) if e.human else e.team)
	var mine := []
	for Q in _players():
		mine.append({"name": ent_name(Q), "pos": my_ord.find(_mark(Q)) + 1, "dnf": Q.dnf, "slot": _grid.find(_mark(Q)), "dead": _dead(Q)})
	return {"stage": "heat", "pos": _heat_pos, "dnf": P.dnf, "order": names, "dead": dead, "slot": _slot, "grid_size": _grid.size(),
		"mine": mine, "can_next": not dead, "can_retune": not dead and _retune_ok(), "final": false}

func _start_main() -> void:
	var P := _player()
	var hw: bool = _heat_pos == 1 and not P.dnf
	var gr := _grid.filter(func(x): return not (x is String))
	var slots := []
	for i in entries.size(): slots.append(maxi(0, _grid.find("P%d" % i)))
	stage = "main"
	rs = _make(fmt, rivals, {"gridRivals": gr, "playerSlot": _slot, "playerSlots": slots})
	rs.heatWin = hw

# ---------------- drag eliminations ----------------
func _drag_start() -> void:
	var rv: Array = rivals if not rivals.is_empty() else Career.mkRivals(def, 7)
	rivals = rv.slice(0, 7)
	_alive = U.shuffle(rivals + ["P"])
	_out = []
	best_et = null
	_drag_round()

func _drag_round() -> void:
	var n := _alive.size()
	_pairs = []
	for i in range(0, n, 2): _pairs.append([_alive[i], _alive[i + 1]])
	for p in _pairs:
		if p.has("P"): _mine = p
	_opp = _mine[1] if (_mine[0] is String) else _mine[0]
	stage = "drag"
	rs = _make(fmt, [_opp])

func _round_name(n: int) -> String: return "Quarterfinal" if n == 8 else ("Semifinal" if n == 4 else "Final")

func _drag_done() -> Dictionary:
	var P := _player()
	Career.carry(_veh(), P)
	var n := _alive.size()
	var O: Dictionary = {}
	for e in rs.ents:
		if not e.human: O = e
	var pt: float = P.finT if P.fin else INF
	var ot: float = O.finT if O.get("fin", false) else INF
	var win: bool = not P.get("redlight", false) and pt < ot
	var et = P.get("et")
	if et is Dictionary and not et.is_empty():
		best_et = float(et.et) if best_et == null else minf(best_et, float(et.et))
		if float(et.et) < 10: Career.ach("ten")
		if float(et.et) < 9: Career.ach("eights")
	var oet = rs.et_of(O) if O.get("fin", false) else null
	var nx := []
	for p in _pairs:
		if is_same(p, _mine):
			nx.append("P" if win else _opp)
			_out.append({"e": _opp if win else "P", "r": n})
		else:
			var w := 0 if Career.quickTime(def, p[0], fmt) < Career.quickTime(def, p[1], fmt) else 1
			nx.append(p[w])
			_out.append({"e": p[1 - w], "r": n})
	_alive = nx
	var dead := _dead(P)
	var more: bool = win and _alive.size() > 1 and not dead
	return {"stage": "drag", "round_name": _round_name(n), "win": win, "redlight": P.get("redlight", false), "et": et, "opp": _opp.team, "opp_et": oet,
		"dead": dead, "can_next": more, "can_retune": more and _retune_ok(), "final": not more, "won_ladder": win and _alive.size() == 1}

func _drag_finish() -> Dictionary:
	var P := _player()
	while _alive.size() > 1:
		var n := _alive.size()
		var nx := []
		for i in range(0, n, 2):
			var a = _alive[i]; var b = _alive[i + 1]
			var w := 0
			if a is String: w = 0
			elif b is String: w = 1
			else: w = 0 if Career.quickTime(def, a, fmt) < Career.quickTime(def, b, fmt) else 1
			nx.append(b if w else a)
			_out.append({"e": a if w else b, "r": n})
		_alive = nx
	var order := [_alive[0]]
	for r in [2, 4, 8]:
		for o in _out:
			if int(o.r) == r: order.append(o.e)
	var ents := []
	for x in order:
		if x is String: ents.append(P)
		else: ents.append({"team": x.team, "col": x.col, "isPlayer": false, "human": false, "dnf": false, "fin": true, "dynasty": bool(x.get("dynasty", false))})
	var pos := order.find("P") + 1
	if not P.get("holed", false) and not P.get("destroyed", false) and not P.get("seized", false): P.dnf = false
	rs.order_override = ents
	rs.forcePos = pos
	rs.fmt = fmt
	rs.drag = true
	var out := Career.raceResult(rs)
	if best_et != null: out.best_et = best_et
	return out

# ---------------- hillclimb best of 2 ----------------
func _hill_start() -> void:
	if rivals.is_empty(): rivals = Career.mkRivals(def, Career.RIVAL_N[int(def.tier)])
	run = 1
	_best = {}
	p_best = INF
	_pbest = {}
	_hill_run()

func _hill_run() -> void:
	var f := fmt.duplicate()
	f.kind = "tt"
	stage = "hill"
	rs = _make(f, rivals)

func _hill_done() -> Dictionary:
	var P := _player()
	_carry_all()
	for e in rs.ents:
		var t: float = e.finT if e.fin else INF
		if e.human:
			var k := int(e.get("entry", 0))
			_pbest[k] = minf(float(_pbest.get(k, INF)), t)
			if k == 0: p_best = minf(p_best, t)
		else: _best[e.team] = minf(float(_best.get(e.team, INF)), t)
	var tab := []
	for r in rivals: tab.append([r.team, float(_best.get(r.team, INF))])
	var mine := []
	for Q in _players():
		var k2 := int(Q.get("entry", 0))
		tab.append([ent_name(Q), float(_pbest.get(k2, INF)), true])
		mine.append({"name": ent_name(Q), "time": Q.finT if Q.fin else null, "best": float(_pbest.get(k2, INF))})
	tab = U.sort_by(tab, func(x): return x[1])
	var dead := _all_dead()
	var more: bool = run == 1 and not dead
	return {"stage": "hill", "run": run, "time": P.finT if P.fin else null, "table": tab.slice(0, 8 + entries.size() - 1), "dead": dead,
		"mine": mine, "can_next": more, "can_retune": more, "final": not more}

func _hill_finish() -> Dictionary:
	var P := _player()
	var lst := []
	for r in rivals: lst.append([r, float(_best.get(r.team, INF))])
	for Q in _players(): lst.append([Q, float(_pbest.get(int(Q.get("entry", 0)), INF))])
	lst = U.sort_by(lst, func(x): return x[1])
	var ents := []
	var pos := 0
	for i in lst.size():
		var x: Array = lst[i]
		if x[0] is Dictionary and bool(x[0].get("isPlayer", false)):
			ents.append(x[0])
			if is_same(x[0], P): pos = i + 1
			if is_finite(x[1]): x[0].dnf = false
		else:
			var fin := is_finite(x[1])
			ents.append({"team": x[0].team, "col": x[0].col, "isPlayer": false, "human": false, "dnf": not fin, "fin": fin, "dynasty": bool(x[0].get("dynasty", false))})
	rs.order_override = ents
	rs.forcePos = pos
	rs.fmt = fmt
	var out := Career.raceResult(rs)
	var bt := INF
	for k in _pbest: bt = minf(bt, float(_pbest[k]))
	if is_finite(bt): out.best_time = bt
	return out
