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
	gs.back(); await _frames(2)
	gs.back(); await _frames(3)
	r.ok(CareerKit.find_button(m, "howto") != null, "BACK returns to the title")

func _frames(n: int) -> void:
	for i in n: await r.get_tree().process_frame
