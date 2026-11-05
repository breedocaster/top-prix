extends RefCounted
## Team entries and shared roads:
##  - two of your cars in one career race (mass start, heats -> main, hillclimb best of 2), each scored
##    on its own machine and driver; the drag ladder keeps one car
##  - human cars on the same time-trial run (team entries, LAN versus) don't ghost through each other
##  - a rendered race with two call cards, the camera switching cars, and the volume sliders
## Rendered parts need:  xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy -- --test=team_test
var r

func ok(c: bool, m: String) -> void: r.ok(c, m)

func run(runner) -> void:
	r = runner
	ok(Career.load_json(FileAccess.get_file_as_string("res://tests/fixtures/web_save.json")), "load web save")
	var G := Career.G
	var cars := _pair()
	ok(cars.size() == 2, "fixture has two machines of one class")
	var drv: Array = Career.drivers().slice(0, 2)
	ok(drv.size() == 2, "fixture has two drivers")
	ok(Career.entryCap() >= 2 and not Career.multiEntryOk({"kind": "drag"}), "entry cap %d, drag ladder single" % Career.entryCap())
	var any_races: Array = Data.D.RACES.filter(func(x): return Career.clsOk(x, cars[0]) and Career.clsOk(x, cars[1]))
	var pick := func(kind: String, runs := 1) -> Dictionary:
		for x in any_races:
			for f in Data.formats(x.id):
				if f.kind == kind and int(f.get("runs", 1)) == runs: return {"rid": x.id, "fmt": f.id}
		return {}
	var specs := [pick.call("mass"), pick.call("heats"), pick.call("tt", 2), pick.call("drag")]
	for sp in specs:
		if sp.is_empty(): continue
		_reset(cars, drv)
		var ens := [[cars[0].id, drv[0].id], [cars[1].id, drv[1].id]]
		var races0 := int(G.st.races)
		var vr := cars.map(func(v): return int(v.races))
		var en0 := drv.map(func(s): return float(s.energy))
		var f := Career.startRace(sp.rid, cars[0].id, drv[0].id, "normal", null, sp.fmt, {"entries": ens})
		var want := 1 if f.fmt.kind == "drag" else 2
		ok(f.rs.players().size() == want and f.entries.size() == want, "%s %s: %d team cars on the grid" % [sp.rid, sp.fmt, f.rs.players().size()])
		var ps: Array = f.rs.players()
		ok(ps.all(func(P): return P.human and P.isPlayer and int(P.owner) == 1 and is_same(P.sparks, G.sparks)), "entries are yours and share the spark pool")
		var panels := []
		var guard := 0
		while not f.done and guard < 12:
			if f.stage == "main": ok(f.rs.players().size() == 2, "main event has both cars")
			f.rs.run_instant()
			var p := f.stage_done()
			panels.append(p)
			if want == 2 and p.stage in ["heat", "hill"]: ok(p.get("mine", []).size() == 2, "%s panel lists both cars" % p.stage)
			if p.can_next: f.next()
			else: f.finish()
			guard += 1
		var out := f.result
		ok(int(G.st.races) == races0 + 1, "%s counts as one team race" % sp.rid)
		var ents: Array = out.get("entries", [])
		ok(ents.size() == want, "%s result lists %d cars: %s" % [sp.rid, want, ents.map(func(e): return [e.pos, e.dnf, e.prize])])
		if want == 2:
			var best := 99
			for e in ents:
				if not e.dnf: best = mini(best, int(e.pos))
			ok(out.dnf or int(out.pos) == best, "team place is the best car (%s vs %s)" % [out.pos, best])
			ok(int(out.prize) == ents.reduce(func(a, e): return a + int(e.prize), 0), "prize is the sum of both cars")
			ok(int(cars[0].races) == vr[0] + 1 and int(cars[1].races) == vr[1] + 1, "both machines raced")
			ok(float(drv[0].energy) < en0[0] and float(drv[1].energy) < en0[1], "both drivers spent energy")
			if f.kind == "hill": ok(f.rs.order_override.size() == f.rivals.size() + 2, "hill table has both cars")
		print("  %s %s -> %s" % [sp.rid, sp.fmt, panels.map(func(p): return p.stage)])
	# shared road in time trials: two humans on one run fight for space, rivals stay ghosts
	var hill: Dictionary = pick.call("tt", 2)
	if not hill.is_empty():
		var def := Data.race(hill.rid)
		var fm: Dictionary = Data.formats_m1(def.id).filter(func(x): return x.kind == "tt")[0]
		var trk := RaceSim.build_track(def, false)
		var pre: Array = Game.presets()
		var a := Game.make_entry(pre[4], trk, 1, "A", "p1", "#e8432f", "push")
		var b := Game.make_entry(pre[4], trk, 2, "B", "p2", "#2f5fbf", "push")
		var rs := RaceSim.create(def, [a, b], {"fmt": fm, "seed": 7})
		var hs := rs.humans()
		var overlap := 0
		var g := 0
		while not rs.done and g < 20000:
			rs.step(0.05); g += 1
			if hs[0].fin or hs[1].fin or hs[0].dnf or hs[1].dnf: continue
			if absf(float(hs[0].lat) - float(hs[1].lat)) < 0.5 and absf(rs._gap(hs[0].prog, hs[1].prog)) < RaceSim.CAR_LEN * 0.9: overlap += 1
		ok(rs.tt and overlap < 5, "versus time trial: humans share the road (%d overlapping steps)" % overlap)
	_old_save_migration()
	await _render(cars, drv)

## Two raceable machines of the same class (fixture saves change when the web bot is re-run).
func _pair() -> Array:
	var by := {}
	for v in Career.G.vehicles:
		if v.status == "build" or not (v.get("eng") is Dictionary): continue
		var c: String = Data.D.BODY[v.body].cls
		if not by.has(c): by[c] = []
		by[c].append(v)
	for c in by:
		if by[c].size() >= 2: return by[c].slice(0, 2)
	return []

## A save from before carbs gained idle feed restrictors / air bleeds / cutaways loads with stock parts.
func _old_save_migration() -> void:
	var G := Career.G
	var v: Dictionary = G.vehicles[0]
	var swaps := {"car": ["q4", ["pilot", "hsab"]], "bike": ["pwk", ["cut"]]}
	var sw: Array = swaps[Data.D.BODY[v.body].cls]
	v.eng.fuel = "carb"; v.eng.carb = sw[0]
	Tune.stockJets(v)
	for k in sw[1]: v.eng.jets.erase(k)
	ok(Career.load_json(Career.serialize()), "reload a save missing the new carb parts")
	var v2: Dictionary = Career.G.vehicles[0]
	var C: Dictionary = Data.D.CARBS[sw[0]]
	for p in C.p:
		if p.k in sw[1]: ok(v2.eng.jets.get(p.k) != null and is_equal_approx(float(v2.eng.jets[p.k]), float(p.stock)), "%s %s back at stock %s" % [sw[0], p.k, str(p.stock)])
	Career.adjJet(v2.id, sw[1][0], 1)
	ok(float(v2.eng.jets[sw[1][0]]) > float(C.p.filter(func(x): return x.k == sw[1][0])[0].stock), "new part adjusts on the bench")

func _reset(cars: Array, drv: Array) -> void:
	for v in cars:
		v.status = "ready"; v.hp = 1.0
		if v.get("eng") is Dictionary: v.eng.cond = 1.0
	for s in drv: s.energy = s.maxE
	Career.G.jobs = Career.G.jobs.filter(func(j): return j.type != "rep")

func _render(_cars: Array, _drv: Array) -> void:
	if DisplayServer.get_name() == "headless": return
	var cars := _pair()          # the save was reloaded: fetch the live dictionaries
	var drv: Array = Career.drivers().slice(0, 2)
	_reset(cars, drv)
	var mass: Array = Data.D.RACES.filter(func(x): return Career.clsOk(x, cars[0]) and Career.clsOk(x, cars[1]) and Data.formats(x.id)[0].kind == "mass")
	var f := Career.startRace(mass[0].id, cars[0].id, drv[0].id, "normal", null, "", {"entries": [[cars[0].id, drv[0].id], [cars[1].id, drv[1].id]]})
	r.main._open_race(func(rv): rv.start_sim(f.rs, "local", 1))
	var rv: RaceView = r.main.race_view
	rv.speed = 2.0
	await r.get_tree().create_timer(4.0).timeout
	ok(rv.call_widgets.size() == 2, "two call cards")
	var ids: Array = rv.call_widgets.keys()
	var first: int = rv.follow
	var other: int = ids[1] if int(ids[0]) == first else ids[0]
	(rv.call_widgets[other].name as Button).pressed.emit()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	ok(rv.follow == other, "tapping a car's name moves the camera to it (%d -> %d)" % [first, rv.follow])
	await r.shot("team_race")
	rv._toggle_vol()
	await r.get_tree().process_frame
	var sl: HSlider = _find_slider(rv._vol_panel, "vol:music_vol")
	ok(sl != null, "race VOL panel has a music slider")
	if sl:
		sl.value = 0.3
		ok(is_equal_approx(float(Game.player.music_vol), 0.3), "music slider sets the volume")
		var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
		ok(absf(db - linear_to_db(0.09)) < 0.1, "music bus at %.1f dB" % db)
		sl.value = 0.6
	await r.shot("team_race_vol")
	rv._toggle_vol()
	rv.speed = 4.0
	rv._skip()
	await r.get_tree().create_timer(1.5).timeout
	await _career_flow(mass[0].id)
	await _qol()

## Quality-of-life checks: team colour pickers, back button in the menus, race speed memory.
func _qol() -> void:
	var m = r.main
	m.new_team_screen("free", "")
	await _frames(2)
	ok(await _press(m, "col_2f7de8"), "new team: colour swatch found")
	ok(str(m._nt.col) == "#2f7de8", "new team: picking a colour sticks (%s)" % str(m._nt.col))
	ok(await _press(m, "col_3a3f4a"), "new team: second-row colour swatch")
	ok(str(m._nt.col) == "#3a3f4a", "new team: extended palette colour (%s)" % str(m._nt.col))
	await r.shot("team_new_colours")
	# back button: quick race -> title
	m.quick_screen()
	await _frames(2)
	m._go_back()
	await _frames(2)
	ok(CareerKit.find_button(m, "story") != null, "back from Quick Race lands on the title")
	# career settings: rename + recolour mid-career
	m.career_screen()
	await _frames(4)
	var cs = m.career
	var st = cs.open("settings")
	await _frames(3)
	ok(await _press(cs.top(), "col_9ad81e"), "settings: team colour swatch")
	ok(str(Career.G.team.color) == "#9ad81e", "settings: team colour changed (%s)" % str(Career.G.team.color))
	var le: LineEdit = _find_line_edit(cs.top())
	if le:
		le.text = "Lime Time Racing"
		ok(await _press(cs.top(), "rename"), "settings: rename button")
		ok(str(Career.G.team.name) == "Lime Time Racing", "settings: team renamed")
	await r.shot("team_settings")
	# the bench's GUIDE button opens the matching how-to topic; the hub has a ? too
	var vb: Dictionary = Career.G.vehicles.filter(func(x): return x.get("eng") is Dictionary and x.eng.fuel == "carb")[0] if Career.G.vehicles.any(func(x): return x.get("eng") is Dictionary and x.eng.fuel == "carb") else {}
	if not vb.is_empty():
		vb.status = "ready"
		cs.open("bench", {"vid": vb.id})
		await _frames(3)
		ok(await _press(cs.top(), "guide"), "bench has a GUIDE button")
		await _frames(2)
		var gt = cs.top()
		ok(gt != null and str(gt.get("topic")) == GuideData.for_bench("carb", str(Data.D.CARBS[vb.eng.carb].kind)), "bench GUIDE opens the carb topic (%s)" % str(gt.get("topic")))
		gt.back(); await _frames(2)
	# race speed is remembered between local races
	Game.player.race_speed = 1.0
	var rs := RaceSim.create(Data.race("c1a"), [Game.make_entry(Game.presets()[4], RaceSim.build_track(Data.race("c1a"), false), 1, "T", "me", "#e8432f")], {})
	m._open_race(func(rv): rv.start_sim(rs, "local", 1))
	await _frames(2)
	m.race_view._toggle_speed()
	ok(float(Game.player.race_speed) == 2.0, "speed choice saved")
	var rs2 := RaceSim.create(Data.race("c1a"), [Game.make_entry(Game.presets()[4], RaceSim.build_track(Data.race("c1a"), false), 1, "T", "me", "#e8432f")], {})
	m._open_race(func(rv): rv.start_sim(rs2, "local", 1))
	await _frames(2)
	ok(m.race_view.speed == 2.0, "next race starts at the saved speed")
	m.race_view.set_speed(1.0)
	m.title_screen()
	await _frames(2)

func _find_line_edit(n: Node) -> LineEdit:
	if n is LineEdit: return n
	for c in n.get_children():
		var x := _find_line_edit(c)
		if x: return x
	return null

## Garage UI: prerace -> + ADD CAR -> start -> race screen with both cars -> results window.
func _career_flow(rid: String) -> void:
	ok(Career.load_json(FileAccess.get_file_as_string("res://tests/fixtures/web_save.json")), "reload web save")
	var cars := _pair()
	_reset(cars, Career.drivers().slice(0, 2))
	Career.G.jobs = []          # no build-decision windows over the screens we look at
	r.main.career_screen()
	await _frames(4)
	var cs = r.main.career
	var pr = cs.open("prerace", {"rid": rid})
	await _frames(3)
	ok(await _press(pr, "entry_add"), "prerace offers + ADD CAR")
	await _frames(2)
	pr = cs.top()
	ok(pr is PreraceScreen and pr.picks.size() == 2 and pr.picks[0].v != pr.picks[1].v and pr.picks[0].d != pr.picks[1].d, "second car gets its own machine and driver")
	var b: Button = CareerKit.find_button(pr, "entry_1")
	var sc := b.get_parent()
	while sc and not (sc is ScrollContainer): sc = sc.get_parent()
	if sc: (sc as ScrollContainer).ensure_control_visible(b)
	await _frames(2)
	await r.shot("team_prerace")
	ok(await _press(pr, "start"), "start with two cars")
	await _frames(3)
	var rsn = cs.top()
	ok(rsn is RaceScreen and rsn.flow.multi() and rsn.flow.rs.players().size() == 2, "career race screen runs both cars")
	if rsn is RaceScreen:
		rsn.rv.speed = 4.0
		rsn.rv._skip()
		await r.get_tree().create_timer(2.5).timeout
		await r.shot("team_results")
		ok(rsn.result.get("entries", []).size() == 2, "results window has both cars")

func _frames(n: int) -> void:
	for i in n: await r.get_tree().process_frame

func _press(root: Node, key: String) -> bool:
	var b := CareerKit.find_button(root, key)
	if b == null or b.disabled: return false
	b.pressed.emit()
	await _frames(2)
	return true

func _find_slider(n: Node, act: String) -> HSlider:
	if n == null: return null
	if n is HSlider and str(n.get_meta("act", "")) == act: return n
	for c in n.get_children():
		var x := _find_slider(c, act)
		if x: return x
	return null
