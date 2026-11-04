extends "res://scripts/ui/career/sub_screen.gd"
## Test day: pick a private track (Data.D.TESTS), laps, vehicle and driver; run the session in a
## RaceView (Career.startTest), then Career.finishTest and show lap times, the engine datalog (zone
## table, plug chop, symptoms) and driver gains. "Tune it" opens the bench for the session's
## conditions through the router (router.open("bench", {vid, tab, cond})); without a router it sets
## ctx.next = {name, ctx} and emits closed.
## ctx: {router?, vid?: preselected vehicle, track?: test id}

const ZoneTable := preload("res://scripts/ui/career/zone_table.gd")

var track := "t_tar"
var laps := 5
var tvid = null
var tsid = null
var rv: RaceView = null
var rs: RaceSim = null
var result: Dictionary = {}       ## {out, lapT, et, finT, dnf, holed, seized, cond, def_n, vid, cost}
var _mat: ShaderMaterial = null

func _title() -> String: return "Test Day"

func _init_screen() -> void:
	tvid = ctx.get("vid")
	track = str(ctx.get("track", "t_tar"))
	_mat = SK.swap_material(SpriteForge.palette([Color(str(Career.G.team.color))]))

func _sig() -> String:
	if not result.is_empty() or rv != null: return "busy"
	var a := []
	for v in Career.G.vehicles: a.append("%s%s" % [v.id, v.status])
	for s in Career.drivers(): a.append(str(int(float(s.energy)) / 5))
	return ",".join(a) + str(int(float(Career.G.money) / 1000))

func _tt() -> Dictionary:
	for t in Data.D.TESTS:
		if t.id == track: return t
	return Data.D.TESTS[0]

func _laps() -> int:
	var tt := _tt()
	return 3 if tt.style == "drag" or tt.style == "hill" else laps

func _vehicles() -> Array:
	return Career.G.vehicles.filter(func(v): return v.status == "ready" and Career.engReady(v))

func _drivers() -> Array:
	return Career.drivers().filter(func(s): return float(s.energy) >= 10)

func _fill(b: VBoxContainer) -> void:
	if not result.is_empty():
		_fill_result(b)
		return
	var vs := _vehicles()
	if tvid == null or not vs.any(func(v): return v.id == tvid): tvid = vs[0].id if vs.size() else null
	var ds := _drivers()
	if tsid == null or not ds.any(func(s): return s.id == tsid):
		tsid = null
		var best := -1.0
		for s in ds:
			if float(s.energy) > best: best = float(s.energy); tsid = s.id
	SK.note(b, "Run laps alone at a private track: a full fuel datalog (AFR per throttle zone, knock, sync), lap times and a little driver experience. Costs money and some energy.")
	b.add_child(SK.section("Track"))
	for t in Data.D.TESTS:
		var c := SK.chip(t.n, t.id == track, _set_track.bind(t.id))
		c.custom_minimum_size = Vector2(0, 20)
		b.add_child(SK.act(c, "track:" + str(t.id)))
	var tt := _tt()
	var surf := []
	for k in tt.surf: surf.append("%s %d%%" % [Data.D.SURF[k].n, int(tt.surf[k])])
	var info := "%s - %s" % [", ".join(surf), {"circuit": "lapped circuit", "mx": "dirt loop", "drag": "1/4 mile, 3 passes", "hill": "hill run, 3 climbs"}.get(tt.style, tt.style)]
	if tt.get("alt"): info += " - %d->%dM" % [int(tt.alt), int(tt.get("alt2", tt.alt))]
	b.add_child(SK.small(info, SK.BL))
	if tt.style != "drag" and tt.style != "hill":
		var lh := UIKit.hbox(2)
		var ll := SK.small("LAPS", SK.SUB, false)
		ll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lh.add_child(ll)
		for n in [3, 5, 10]: lh.add_child(SK.act(SK.chip("%d" % n, laps == n, _set_laps.bind(n)), "laps:%d" % n))
		b.add_child(lh)
	b.add_child(SK.section("Vehicle"))
	if vs.is_empty(): SK.note(b, "No ready vehicle.", SK.BD)
	for v in vs:
		var B: Dictionary = Data.D.BODY[v.body]
		var sel: bool = v.id == tvid
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", SK.card_style("sel" if sel else ""))
		var h := UIKit.hbox(4)
		p.add_child(h)
		h.add_child(SK.veh_sprite(B.kind, 0, _mat, 6, Rect2(0, 8, 48, 36)))
		var iv := UIKit.vbox(1)
		iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(iv)
		iv.add_child(SK.big(v.name, SK.HL if sel else Color.WHITE))
		var e = v.get("eng")
		var fs := "Electric"
		if e != null and e.fuel == "efi": fs = "EFI"
		elif e != null and e.fuel == "carb": fs = str(Data.D.CARBS[e.carb].n).split(" (")[0]
		iv.add_child(SK.small(fs, SK.SUB))
		if e != null and e.fuel != "none": iv.add_child(SK.small("ENGINE %d%%" % int(roundf(float(e.cond) * 100)), SK.SUB))
		var pick_b := SK.act(SK.sbtn("PICKED" if sel else "PICK", _set_veh.bind(v.id), SK.GREEN if sel else UIKit.BTN, 52), "veh:%d" % int(v.id))
		pick_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pick_b)
		b.add_child(p)
	b.add_child(SK.section("Driver"))
	if ds.is_empty(): SK.note(b, "Everyone is too tired.", SK.BD)
	var dh := HFlowContainer.new()
	dh.add_theme_constant_override("h_separation", 2)
	dh.add_theme_constant_override("v_separation", 2)
	for s in ds:
		var c2 := SK.fit_btn(SK.chip("%s EN%d" % [str(s.name).split(" ")[0], int(float(s.energy))], s.id == tsid, _set_drv.bind(s.id)))
		c2.custom_minimum_size.y = 20
		dh.add_child(SK.act(c2, "drv:%d" % int(s.id)))
	b.add_child(dh)
	var cost := Career.testCost(_laps())
	var go_b := SK.act(SK.btn("START TEST (%s)" % SK.money(cost), _start, SK.GREEN, false, tvid == null or tsid == null or float(Career.G.money) < cost), "start")
	go_b.custom_minimum_size = Vector2(0, 28)
	b.add_child(go_b)

func _set_track(id: String) -> void:
	track = id
	rebuild()

func _set_laps(n: int) -> void:
	laps = n
	rebuild()

func _set_veh(id) -> void:
	tvid = id
	rebuild()

func _set_drv(id) -> void:
	tsid = id
	rebuild()

# ---------------- session ----------------
func _start() -> void:
	var v := Career.veh(tvid)
	var s := Career.staff(tsid)
	if v.is_empty() or s.is_empty(): return
	if float(Career.G.money) < Career.testCost(_laps()):
		say("Not enough money")
		return
	rs = Career.startTest(track, tvid, tsid, _laps())
	frame.get_parent().visible = false
	rv = RaceView.new()
	add_child(rv)
	rv.start_sim(rs, "local", 1)
	rv.finished.connect(_on_finished)

func _on_finished(_res: Dictionary) -> void:
	if rs == null: return
	var P := rs.player()
	var v := Career.veh(P.vid)
	var out := Career.finishTest(rs)
	result = {"out": out, "lapT": P.get("lapT", []).duplicate(), "et": P.get("et", {}), "finT": P.get("finT", 0.0), "fin": P.get("fin", false), "dnf": P.get("dnf", false),
		"holed": P.get("holed", false), "seized": P.get("seized", false), "cond": rs.cond, "def_n": rs.def.n, "vid": P.vid, "cost": Career.testCost(int(rs.tr.laps)),
		"drag": rs.tr.drag, "p2p": rs.tr.p2p}
	if rv != null:
		remove_child(rv)
		rv.queue_free()
		rv = null
	rs = null
	frame.get_parent().visible = true
	set_title("Test Done")
	rebuild(true)

func _fill_result(b: VBoxContainer) -> void:
	var v := Career.veh(result.vid)
	var c: Dictionary = result.cond
	var top := SK.card(b, "sel")
	top.add_child(SK.big("TEST COMPLETE", SK.HL))
	top.add_child(SK.small(result.def_n, Color.WHITE))
	var cl := "%dC  %dM" % [int(float(c.temp)), int(float(c.alt))]
	if float(c.alt2) != float(c.alt): cl += "->%dM" % int(float(c.alt2))
	cl += "  AIR %d%%" % int(roundf(float(c.rho) * 100))
	top.add_child(SK.small(cl, SK.BL))
	# times
	var tc := SK.card(b)
	var lt: Array = result.lapT
	if result.drag:
		tc.add_child(SK.section("Passes"))
		var et: Dictionary = result.et
		if not et.is_empty(): tc.add_child(SK.small("ET %ss @ %s  -  RT %ss" % [U.to_fixed(float(et.et), 3), str(et.get("mph", "")), U.to_fixed(float(et.get("rt", 0)), 3)], SK.HL))
		else: tc.add_child(SK.small("No clean pass.", SK.DIM))
	elif result.p2p:
		tc.add_child(SK.section("Runs"))
		tc.add_child(SK.small(("Time %ss" % U.to_fixed(float(result.finT), 2)) if result.fin else "Did not finish", SK.HL))
	else:
		tc.add_child(SK.section("Lap times"))
		if lt.is_empty(): tc.add_child(SK.small("No complete laps.", SK.DIM))
		var best := INF
		for x in lt: best = minf(best, float(x))
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 6)
		for i in lt.size():
			var isb := float(lt[i]) == best
			g.add_child(SK.small("L%d %s" % [i + 1, U.to_fixed(float(lt[i]), 2)], SK.GD if isb else Color.WHITE, false))
		tc.add_child(g)
		if lt.size() > 0: tc.add_child(SK.small("Best %ss" % U.to_fixed(best, 2), SK.GD))
	if result.dnf:
		SK.note(b, "Holed a piston during the test!" if result.holed else ("Seized!" if result.seized else "Session cut short."), SK.BD)
	# datalog
	if not v.is_empty() and v.get("eng") != null and v.eng.fuel != "none" and v.eng.get("log") != null:
		var lg: Dictionary = v.eng.log
		var ev := Tune.eval(v, c)
		var dc := SK.card(b)
		dc.add_child(SK.section("Datalog"))
		dc.add_child(ZoneTable.new(ev.lam, ev.kd, bool(lg.get("wb", false))))
		if not lg.get("wb", false): dc.add_child(SK.small("Plug chop: %s" % Tune.plug(float(ev.lam.wot))[0], SK.HL))
		for x in Tune.symptoms(ev, v.eng.fuel == "efi"): dc.add_child(SK.small("- " + SK.ascii(x), Color.WHITE))
		dc.add_child(SK.small("Engine %d%%" % int(roundf(float(v.eng.cond) * 100)), SK.SUB))
	# driver
	var gains: Array = result.out.get("gains", [])
	var ga := []
	for k in gains: ga.append("%s +1" % {"pedal": "PED", "shift": "SHF", "steer": "STR"}.get(k, str(k)))
	SK.note(b, "Driver: %s\nCost %s" % [", ".join(ga) if not ga.is_empty() else "-", SK.money(float(result.cost))])
	var h := UIKit.hbox(3)
	if not v.is_empty() and v.get("eng") != null and v.eng.fuel != "none":
		h.add_child(SK.act(SK.btn("TUNE IT", _tune_it, UIKit.BTN), "tune"))
	h.add_child(SK.act(SK.btn("AGAIN", _again, SK.GREY), "again"))
	h.add_child(SK.act(SK.btn("DONE", back, SK.GREEN), "done"))
	b.add_child(h)

func _tune_it() -> void:
	var v := Career.veh(result.vid)
	var c := {"vid": result.vid, "tab": "efi" if v.get("eng") != null and v.eng.fuel == "efi" else "carb", "cond": result.cond}
	if go("bench", c): return
	ctx.next = {"name": "bench", "ctx": c}
	closed.emit()

func _again() -> void:
	result = {}
	set_title("Test Day")
	rebuild(true)

func back() -> void:
	if rv != null:
		rv._skip()
		return
	super()
