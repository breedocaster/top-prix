class_name RaceScreen
extends Control
## A career race of any format (RaceFlow) shown in the Mode 7 RaceView, stage by stage: heat -> main,
## the 8-car drag ladder, hillclimb best-of-2 (with a retune at the bench between runs), rally stages,
## endurance. Between stages and at the end a SNES window shows the stage table / results (prize, RP,
## fans, XP, sparks, engine report, championship, unlocks, the dynasty's place).
## ctx: {rid, vid, drv (driver staff id), tactic, sid (series id or null), fmt}
##   or a private test session: {test: track id (D.TESTS), vid, drv, laps} -> Career.startTest / finishTest,
##   lap times + datalog window; DONE returns to the screen that opened it.

signal closed

var router = null
var ctx := {}
var flow: RaceFlow
var rv: RaceView
var panel_win: SnesWindow
var result: Dictionary = {}
var _retuning := false
var _bg: ColorRect
var _xp0 := 0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(c: Dictionary) -> void:
	ctx = c
	router = c.get("router")
	_bg = ColorRect.new()
	_bg.color = UIKit.BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	if c.get("test") != null:
		_start_test()
		return
	var opts := {}
	var dyn: Dictionary = Story.rival_for(str(c.rid))
	if not dyn.is_empty(): opts.dyn = dyn
	var sid = c.get("sid")
	if sid != null and str(sid) == "": sid = null
	flow = Career.startRace(str(c.rid), c.vid, c.drv, str(c.get("tactic", "normal")), sid, str(c.get("fmt", "")), opts)
	if router: router.racing = true
	_start_stage()

# ---------------- test session ----------------
var test_rs: RaceSim = null

func _start_test() -> void:
	if router: router.racing = true
	test_rs = Career.startTest(str(ctx.test), ctx.vid, ctx.drv, int(ctx.get("laps", 5)))
	rv = RaceView.new()
	rv.title_override = CareerKit.asc("TEST - " + str(test_rs.def.n)).left(31)
	add_child(rv)
	rv.finished.connect(_on_test_end)
	rv.start_sim(test_rs, "local", 1)

func _on_test_end(_res: Dictionary) -> void:
	var cost := Career.testCost(int(test_rs.tr.laps))
	var out := Career.finishTest(test_rs)
	var P := test_rs.player()
	var v := Career.veh(P.vid)
	var c: Dictionary = test_rs.cond
	var body := []
	body.append(_center(CareerKit.small("%s | %dC %dm" % [test_rs.def.n, int(c.get("temp", 20)), int(c.get("alt", 200))], CareerKit.SUB)))
	var laps: Array = P.get("lapT", [])
	if not laps.is_empty():
		body.append(CareerKit.sec("LAP TIMES"))
		var f := CareerKit.flow(8)
		for i in laps.size(): f.add_child(CareerKit.tag("L%d %.2fs" % [i + 1, float(laps[i])], CareerKit.TXT))
		body.append(f)
	if P.dnf: body.append(CareerKit.small("Holed a piston during the test!" if P.get("holed", false) else ("Seized!" if P.get("seized", false) else "Session cut short."), CareerKit.BAD))
	var e = v.get("eng") if not v.is_empty() else null
	if e is Dictionary and e.fuel != "none" and e.get("log") is Dictionary:
		var ev := Tune.eval(v, c)
		body.append(CareerKit.sec("DATALOG"))
		body.append(CareerKit.zone_grid(ev.lam, bool(e.log.get("wb", false))))
		if not bool(e.log.get("wb", false)): body.append(CareerKit.small("Plug chop: " + str(Tune.plug(float(ev.lam.wot))[0]), CareerKit.SUB))
		for sy in Tune.symptoms(ev, e.fuel == "efi"): body.append(CareerKit.small("* " + str(sy), CareerKit.SUB))
	var g: Array = out.get("gains", [])
	body.append(CareerKit.small("Driver: %s | cost %s" % [", ".join(PackedStringArray(g.map(func(k): return str(k) + " +1"))), U.money(cost)], CareerKit.GOOD))
	var btns := [{"t": "DONE", "cb": _test_done, "col": UIKit.OK, "tid": "continue"}]
	if e is Dictionary and e.fuel != "none" and router and router.has_screen("bench"):
		btns.push_front({"t": "TUNE IT", "cb": _test_tune, "col": UIKit.BTN, "tid": "tune"})
	Career.sfx.emit("good")
	_win("TEST COMPLETE", body, btns)

func _test_done() -> void:
	if router: router.race_done(false)
	else: closed.emit()

func _test_tune() -> void:
	if router == null: return
	router.racing = false
	CareerScreen.save_game()
	var e = Career.veh(test_rs.player().vid).get("eng")
	router.replace("bench", {"vid": test_rs.player().vid, "tab": "efi" if e is Dictionary and e.fuel == "efi" else "carb", "cond": test_rs.cond})

func _stage_title() -> String:
	var d: Dictionary = flow.def
	var pre := ""
	if flow.series_id != null:
		var S: Dictionary = Data.D.SER[flow.series_id]
		var a = Career.G.series[flow.series_id].get("act")
		pre = "R%d " % (int(a.round) + 1) if a is Dictionary else ""
	var t := pre + str(d.n)
	match flow.stage:
		"heat": t = pre + "HEAT - " + str(d.n)
		"main": t = pre + "MAIN - " + str(d.n)
		"drag": t = pre + {"Quarterfinal": "QF", "Semifinal": "SF"}.get(flow._round_name(flow._alive.size()), "FINAL") + " - " + str(d.n)
		"hill": t = pre + "RUN %d - %s" % [flow.run, d.n]
	return t.left(31)

func _start_stage() -> void:
	var sp := 1.0
	if rv:
		sp = rv.speed
		rv.queue_free()
	rv = RaceView.new()
	rv.title_override = CareerKit.asc(_stage_title())
	add_child(rv)
	rv.finished.connect(_on_stage_end)
	rv.start_sim(flow.rs, "local", 1)
	rv.set_speed(sp)
	Career.sfx.emit("start")

func _on_stage_end(_res: Dictionary) -> void:
	var p := flow.stage_done()
	if bool(p.get("final", false)) and not p.has("round_name") and p.stage != "hill":
		_finish()
		return
	_show_panel(p)

## Stage summary between runs (web racePanel): heat order + main grid, drag round, hill run table.
func _show_panel(p: Dictionary) -> void:
	var body := []
	var btns := []
	var t := ""
	match str(p.stage):
		"heat":
			t = "HEAT: %s" % ("DNF" if p.dnf else U.ord(int(p.pos)))
			var ord: Array = p.order
			for i in ord.size():
				var me: bool = str(ord[i]) == str(Career.G.team.name)
				body.append(_row(i + 1, str(ord[i]), "", me))
			if p.dead: body.append(CareerKit.small("Your machine can't make the main.", CareerKit.BAD))
			else: body.append(CareerKit.small("Main event grid: you start P%d of %d." % [int(p.slot) + 1, int(p.grid_size)], UIKit.GOLD))
			if p.dead: btns.append({"t": "SEE RESULTS", "cb": _finish, "col": UIKit.OK, "wide": true, "tid": "results"})
			else: btns.append({"t": "START MAIN", "cb": _next, "col": UIKit.OK, "wide": true, "tid": "next"})
		"drag":
			t = "%s: %s" % [str(p.round_name).to_upper(), "WIN!" if p.win else "LOSS"]
			var et = p.get("et")
			body.append(CareerKit.pair("You", ("RED LIGHT" if p.get("redlight", false) else ("%.3fs" % float(et.et) if et is Dictionary and not et.is_empty() else "DNF")), UIKit.GOLD, CareerKit.TXT))
			if et is Dictionary and not et.is_empty(): body.append(CareerKit.line("RT %.3f | %d mph" % [float(et.rt), int(et.mph)], CareerKit.SUB))
			var oet = p.get("opp_et")
			body.append(CareerKit.pair(str(p.opp), ("%.3fs" % float(oet.et)) if oet is Dictionary else "DNF", CareerKit.TXT, CareerKit.TXT))
			if p.can_next:
				body.append(CareerKit.small("On to the FINAL!" if flow._alive.size() == 2 else "On to the semis!", CareerKit.GOOD))
				btns.append({"t": "NEXT ROUND", "cb": _next, "col": UIKit.OK, "wide": true, "tid": "next"})
			else:
				body.append(CareerKit.small("You won the eliminations!" if p.get("won_ladder", false) else "Out of the eliminations.", UIKit.GOLD if p.get("won_ladder", false) else CareerKit.SUB))
				btns.append({"t": "RESULTS", "cb": _finish, "col": UIKit.OK, "wide": true, "tid": "results"})
		"hill":
			t = "RUN %d: %s" % [int(p.run), ("%.2fs" % float(p.time)) if p.time != null else "DNF"]
			var tab: Array = p.table
			for i in tab.size():
				var row: Array = tab[i]
				var me := row.size() > 2
				body.append(_row(i + 1, str(row[0]), ("%.2fs" % float(row[1])) if is_finite(float(row[1])) else "DNF", me))
			if p.can_next:
				body.append(CareerKit.small("Best of two runs counts. The air gets thin up there: retune for the summit?", CareerKit.SUB))
				btns.append({"t": "RUN 2", "cb": _next, "col": UIKit.OK, "tid": "next"})
				btns.append({"t": "KEEP RUN 1", "cb": _finish, "col": UIKit.BTN_LO, "tid": "keep"})
			else:
				btns.append({"t": "RESULTS", "cb": _finish, "col": UIKit.OK, "wide": true, "tid": "results"})
	if p.get("can_retune", false) and router and router.has_screen("bench"):
		btns.append({"t": "RETUNE FIRST", "cb": _retune, "col": UIKit.BTN, "wide": true, "tid": "retune", "keep": false})
	_win(t, body, btns)

func _win(t: String, body: Array, btns: Array) -> void:
	if panel_win and is_instance_valid(panel_win): panel_win.queue_free()
	panel_win = SnesWindow.new()
	panel_win.build(t, body, btns)
	add_child(panel_win)

func _next() -> void:
	flow.next()
	if flow.done:
		_finish()
		return
	_start_stage()

func _retune() -> void:
	var e = Career.veh(flow.vid).get("eng")
	var tb := "setup"
	if e is Dictionary and e.fuel != "none": tb = "efi" if e.fuel == "efi" else "carb"
	_retuning = true
	router.open("bench", {"vid": flow.vid, "tab": tb, "cond": flow.rs.cond, "rid": str(flow.def.id), "resume": _stage_title()})

## Router: the bench closed, we're on top again -> show the stage panel again.
func refresh() -> void:
	if _retuning and not flow.done:
		_retuning = false
		_show_panel(flow.stage_done())

func _finish() -> void:
	if flow.done and not result.is_empty(): return
	var v0 := Career.veh(flow.vid)
	_xp0 = int(v0.get("xp", 0))
	result = flow.finish()
	Career.sfx.emit("crash" if result.get("dnf", false) else ("fanfare" if int(result.get("pos", 9)) == 1 else "good"))
	_show_results()

func _show_results() -> void:
	var out := result
	var rs := flow.rs
	var d: Dictionary = flow.def
	var G: Dictionary = Career.G
	var pos := int(out.get("pos", 0))
	var dnf := bool(out.get("dnf", false))
	var big := "%s PLACE" % U.ord(pos).to_upper()
	var col := CareerKit.TXT
	if dnf: big = "WRECKED" if out.get("destroyed", false) else "DNF"; col = CareerKit.BAD
	elif pos == 1: big = "VICTORY!"; col = UIKit.GOLD
	elif pos <= 3: col = Color("#d8dce8")
	var P := rs.player()
	var v := Career.veh(flow.vid)
	var body := []
	body.append(CareerKit.heading(big, col))
	body.append(_center(CareerKit.small(str(d.n) + ((" | " + str(Data.D.SER[flow.series_id].n)) if flow.series_id != null else ""), CareerKit.SUB)))
	if out.has("best_et"): body.append(_center(CareerKit.small("Best ET %.3fs" % float(out.best_et), UIKit.GOLD)))
	if out.has("best_time"): body.append(_center(CareerKit.small("Best run %.2fs" % float(out.best_time), UIKit.GOLD)))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 3)
	var xp := ""
	if out.has("vlv"): xp = "Lv%d!" % int(out.vlv)
	elif not v.is_empty(): xp = "+%d" % maxi(0, int(v.xp) - _xp0)
	for it in [["PRIZE", U.money(float(out.get("prize", 0))), CareerKit.MONEY], ["RP", "+%d" % int(out.get("rp", 0)), CareerKit.RPC],
			["FANS", "+" + U.num(float(out.get("fans", 0))), CareerKit.FANC], ["XP", xp if xp != "" else "-", UIKit.GOLD]]:
		var h := CareerKit.hbox(4)
		var a := CareerKit.line(it[0], CareerKit.SUB)
		CareerKit.shrink(a)
		h.add_child(a)
		var b := CareerKit.line(it[1], it[2])
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(b)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(h)
	body.append(CareerKit.panel(g, "inset"))
	if out.get("rep", false): body.append(CareerKit.small("Repeat win this year: reduced rewards.", CareerKit.WARN))
	if out.get("spark") != null: body.append(CareerKit.small("Earned a %s Spark!" % CareerKit.SPARK_N.get(str(out.spark), ""), CareerKit.SPARK_COL.get(str(out.spark), UIKit.GOLD)))
	if out.get("destroyed", false): body.append(CareerKit.small("The machine was destroyed.", CareerKit.BAD))
	if not v.is_empty():
		var parts := ["HP %d%%" % int(round(float(v.hp) * 100))]
		var e = v.get("eng")
		if e is Dictionary and e.fuel != "none":
			parts.append("engine %d%%" % int(round(float(e.cond) * 100)))
			if P.get("holed", false): parts.append("HOLED A PISTON!")
			elif P.get("seized", false): parts.append("SEIZED!")
		if rs.fuelCost > 0: parts.append("fuel %s" % U.money(rs.fuelCost))
		if v.status == "repair": parts.append("in for repairs")
		body.append(CareerKit.small(", ".join(parts), CareerKit.BAD if P.get("holed", false) or P.get("seized", false) else CareerKit.SUB))
	if out.has("dyn_pos"):
		var dp := int(out.dyn_pos)
		var beat := not dnf and (dp == 0 or pos < dp)
		body.append(CareerKit.panel(CareerKit.small("Crownwell Racing: %s. %s" % ["DNF" if dp == 0 else U.ord(dp), "You beat them!" if beat else "They beat you this time."],
			CareerKit.GOOD if beat else Color("#d8b0ff")), "card_red"))
	body.append(CareerKit.sec("RESULTS"))
	var ord := Career.raceOrder(rs)
	for i in mini(8, ord.size()):
		var e2: Dictionary = ord[i]
		var me := Career.isPlayerEnt(e2)
		var nm: String = str(G.team.name) if me else str(e2.get("team", "?"))
		var tail := "DNF" if bool(e2.get("dnf", false)) and not bool(e2.get("fin", false)) else ""
		body.append(_row(i + 1, nm, tail, me, Color("#d8b0ff") if _is_dyn(e2) else CareerKit.TXT))
	if flow.series_id != null and G.series.get(flow.series_id, {}).get("act") != null:
		body.append(CareerKit.sec("CHAMPIONSHIP"))
		var tb := Career.standings(flow.series_id)
		for i in mini(5, tb.size()):
			var me2: bool = tb[i][0] == "you"
			body.append(_row(i + 1, str(G.team.name) if me2 else str(tb[i][0]), "%d PTS" % int(tb[i][1]), me2))
	var unl: Array = out.get("unl", [])
	if not unl.is_empty():
		body.append(CareerKit.sec("UNLOCKED!"))
		for id in unl:
			body.append(CareerKit.small(str(Data.D.RACE[id].n) if Data.D.RACE.has(id) else str(Data.D.SER[id].n) + " (Series)", UIKit.GOLD))
	_win("", body, [{"t": "CONTINUE", "cb": _done, "col": UIKit.OK, "wide": true, "tid": "continue"}])

const MEDAL := [Color("#ffd84a"), Color("#d8dce8"), Color("#e0975a")]

## Standings row: medal-coloured position, name, optional right column; your row sits in a gold card.
func _row(pos: int, name: String, right: String, me: bool, col: Color = CareerKit.TXT) -> Control:
	var h := CareerKit.hbox(4)
	var pl := CareerKit.lbl("%d" % pos, MEDAL[pos - 1] if pos >= 1 and pos <= 3 else CareerKit.SUB, false, false)
	pl.custom_minimum_size = Vector2(16, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	CareerKit.shrink(pl)
	h.add_child(pl)
	h.add_child(CareerKit.lbl(name, UIKit.GOLD if me else col, false, false))
	if right != "":
		var rl := CareerKit.lbl(right, CareerKit.BAD if right == "DNF" else (UIKit.GOLD if me else CareerKit.SUB), false, false)
		CareerKit.shrink(rl, true)
		h.add_child(rl)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.frame_new("card_gold", 3, 2, 4, 2) if me else StyleBoxEmpty.new())
	if not me:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 3; e.content_margin_right = 4; e.content_margin_top = 1; e.content_margin_bottom = 1
		p.add_theme_stylebox_override("panel", e)
	p.add_child(h)
	return p

static func _is_dyn(e: Dictionary) -> bool:
	var ref = e.get("ref")
	return bool(e.get("dynasty", false)) or (ref is Dictionary and bool(ref.get("dynasty", false)))

func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _done() -> void:
	if router: router.race_done()
	else: closed.emit()

func back() -> void:
	pass   # no leaving mid-race; RaceView has SKIP
