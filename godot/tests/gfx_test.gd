extends RefCounted
## Race-screen graphics checks (rendered): start gantry + lamps in the countdown, corner dressing,
## skid marks, night headlights, exhaust pops. Screenshots: tests/shots/gfx_*.png
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy -- --test=gfx_test
var r

func run(runner) -> void:
	r = runner
	if DisplayServer.get_name() == "headless":
		r.ok(true, "gfx_test needs a renderer; skipped")
		return
	for spec in [["c1a", "start", 0.6], ["c3c", "night", 6.0], ["c2c", "hairpin", 9.0], ["o2b", "stage", 0.6]]:
		var def := Data.race(spec[0])
		if def.is_empty(): continue
		var pre: Array = Game.presets()
		var s: Dictionary = pre[4]
		for p2 in pre:
			if Data.race_cls_ok(def, Game.cls_of(p2)): s = p2; break
		var trk := RaceSim.build_track(def, false)
		var h := Game.make_entry(s, trk, 1, "Gfx", "me", "#e8432f", "push")
		h.fx_pop = 0.9
		var rs := RaceSim.create(def, [h], {"seed": 3})
		r.main._open_race(func(rv): rv.start_sim(rs, "local", 1))
		var rv: RaceView = r.main.race_view
		rv.set_speed(2.0 if spec[2] > 3 else 1.0)
		await r.get_tree().create_timer(spec[2] / (2.0 if spec[2] > 3 else 1.0)).timeout
		r.ok(rv.layer.gantries.size() >= 1, "%s has a start gantry" % spec[0])
		await r.shot("gfx_" + spec[1])
		rv.set_speed(1.0)
	r.main.title_screen()
	await _guide()

## How-to guide: from the title (no career), the topic list, a page in both reading levels.
func _guide() -> void:
	var m = r.main
	await r.get_tree().process_frame
	var hb := CareerKit.find_button(m, "howto")
	r.ok(hb != null, "title has HOW TO PLAY")
	if hb == null: return
	hb.pressed.emit()
	await _frames(3)
	var g = m.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("guide_screen.gd"))
	r.ok(g.size() == 1, "guide screen opens from the title")
	if g.is_empty(): return
	var gs = g[0]
	await r.shot("guide_list")
	var tb := CareerKit.find_button(gs, "topic:carb_down")
	r.ok(tb != null, "guide lists the downdraft topic")
	if tb: tb.pressed.emit()
	await _frames(3)
	r.ok(gs.topic == "carb_down", "topic page opens")
	await r.shot("guide_page_" + gs.level)
	var other: String = "sim" if gs.level == "kid" else "kid"
	var lb := CareerKit.find_button(gs, "level:" + other)
	if lb: lb.pressed.emit()
	await _frames(3)
	r.ok(gs.level == other, "reading level switches")
	await r.shot("guide_page_" + other)
	for t in GuideData.TOPICS:
		r.ok(t.kid.size() >= 3 and t.sim.size() >= 3 and t.sum.has("kid") and t.sum.has("sim"), "topic %s has both versions" % t.id)
		for line in t.kid + t.sim:
			var bad := false
			for ch in str(line):
				if ch.unicode_at(0) > 126: bad = true
			if bad: r.ok(false, "non-ASCII text in topic %s: %s" % [t.id, line])
	await _valves(gs)
	gs.back(); await _frames(2)
	gs.back(); await _frames(3)
	r.ok(CareerKit.find_button(m, "howto") != null, "BACK returns to the title")

## XJ550 valve bench: shim maths, measuring positions, the screens.
func _valves(gs) -> void:
	var VG = load("res://scripts/ui/career/valve_gfx.gd")
	var E: Dictionary = VG.eng("xj550")
	var r1: Dictionary = VG.shim_for(E, "in", 0.08, 2.05)
	r.ok(VG.shim_name(r1.shim) == "Y200", "0.08 mm intake on a Y205 -> Y200 (%s)" % VG.shim_name(r1.shim))
	var r2: Dictionary = VG.shim_for(E, "ex", 0.25, 2.70)
	r.ok(VG.shim_name(r2.shim) == "Y275" and absf(float(r2.result) - 0.20) < 0.001, "0.25 mm exhaust on a Y270 -> Y275 (%s, %.3f)" % [VG.shim_name(r2.shim), float(r2.result)])
	r.ok(VG.status(E, "in", 0.11) == "OK" and VG.status(E, "in", 0.10) == "TIGHT" and VG.status(E, "ex", 0.21) == "LOOSE", "spec windows")
	# measure positions: exhaust ~100 deg before TDC compression, intake ~100 after (Maxim cam timing)
	r.ok(VG.measurable(E, "in", 100.0) and VG.measurable(E, "ex", 620.0) and not VG.measurable(E, "in", 460.0), "measuring positions follow the cam timing")
	r.ok(VG.lift(E, "in", 0.0) == 0.0 and VG.lift(E, "ex", 0.0) == 0.0, "both valves closed at #1 TDC compression")
	var seen := {}
	var th := 0.0
	for i in 8:
		var nc: Array = VG.next_check(E, th)
		th = float(nc[0]); seen["%d%s" % [nc[1], nc[2]]] = true
	r.ok(seen.size() == 8, "NEXT CHECK visits all 8 valves in two turns (%d)" % seen.size())
	gs._open("xj550")
	await _frames(3)
	var tb := CareerKit.find_button(gs, "tool")
	r.ok(tb != null, "XJ550 topic has OPEN THE VALVE BENCH")
	if tb == null: return
	tb.pressed.emit()
	await _frames(3)
	var vs = gs.get_children().filter(func(c): return c.has_method("draw_canvas"))
	r.ok(vs.size() == 1, "valve bench opens over the guide")
	if vs.is_empty(): return
	var v = vs[0]
	await r.shot("valves_xj550_tdc")
	CareerKit.find_button(v, "next_check").pressed.emit(); await _frames(3)
	CareerKit.find_button(v, "m-:" + "%d%s" % [v.cyl, v.sel]).pressed.emit(); await _frames(2)
	await r.shot("valves_xj550_check")
	v.tab = "timing"; v.running = true; v.rebuild(true)
	await r.get_tree().create_timer(0.5).timeout
	await r.shot("valves_xj550_timing")
	v.tab = "sheet"; v.running = false; v.rebuild(true)
	await _frames(3)
	await r.shot("valves_xj550_sheet")
	CareerKit.find_button(v, "model:single").pressed.emit(); await _frames(2)
	v.tab = "valves"; v.rebuild(true); await _frames(3)
	await r.shot("valves_single")
	v.sheets.erase("xj550"); v.sheets.erase("single"); v._save()
	v.back(); await _frames(2)


func _frames(n: int) -> void:
	for i in n: await r.get_tree().process_frame
