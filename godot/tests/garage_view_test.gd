extends RefCounted
## Garage home-screen art: bakes the crew + cat sheets (art/crew/*.png), renders the GarageView at every
## workshop level with mixed bays and crew, checks tap hit-testing, and writes screenshots:
##   tests/shots/garage_ws1..4.png (full viewport), garage_extra_*.png, garage_all.png (2x contact sheet),
##   crew_sheets.png (crew/cat sheets, 4x).

var taps := []

func _colorize(idx: Image, cols: Dictionary, team: Color) -> Image:
	var out := Image.create(idx.get_width(), idx.get_height(), false, Image.FORMAT_RGBA8)
	var ramps := {}
	for y in idx.get_height():
		for x in idx.get_width():
			var p := idx.get_pixel(x, y)
			if p.a < 0.5: continue
			var m := int(round(p.r8 / 10.0))
			if m == 0: out.set_pixel(x, y, Color("#140c24")); continue
			if not ramps.has(m): ramps[m] = SpriteForge.ramp7(cols.get(m, SpriteForge.mat_color(m, team)))
			out.set_pixel(x, y, ramps[m][clampi(int(round(p.g8 / 30.0)), 0, 7)])
	return out

func _bake(r) -> void:
	var dir := ProjectSettings.globalize_path("res://art/crew")
	DirAccess.make_dir_recursive_absolute(dir)
	var sheets := []
	for role in CrewModels.ROLES:
		var t0 := Time.get_ticks_msec()
		var img := CrewModels.bake(role)
		img.save_png(dir.path_join(role + ".png"))
		print("baked crew %s %d ms" % [role, Time.get_ticks_msec() - t0])
		sheets.append(_colorize(img, {CrewModels.SKIN: Color("#f5d0a9"), CrewModels.HAIR: Color("#5a3214"), CrewModels.CAP: Color("#e2b53a")}, Color("#e8432f")))
	var gdir := ProjectSettings.globalize_path("res://art/garage")
	DirAccess.make_dir_recursive_absolute(gdir)
	var t1 := Time.get_ticks_msec()
	var bikes := GarageView.bake_parked_bikes()
	bikes.save_png(ProjectSettings.globalize_path(GarageView.BIKES_PATH))
	print("baked parked bikes %d ms" % (Time.get_ticks_msec() - t1))
	r.ok(FileAccess.file_exists(ProjectSettings.globalize_path(GarageView.BIKES_PATH)), "parked bikes baked")
	var cat := GarageView.bake_cat()
	cat.save_png(dir.path_join("cat.png"))
	sheets.append(_colorize(cat, {SpriteForge.M.SUIT: Color("#ec9a40"), SpriteForge.M.TRUNK: Color("#b8602a"), SpriteForge.M.WHITE: Color("#f8eedc"), SpriteForge.M.RED: Color("#f08a9a")}, Color("#ec9a40")))
	sheets.append(_colorize(bikes, {}, Color("#e8432f")))
	r.ok(FileAccess.file_exists(dir.path_join("mech.png")) and FileAccess.file_exists(dir.path_join("drv.png")), "crew sheets baked")
	var w := 0
	var h := 0
	for s in sheets:
		w += s.get_width() + 4; h = maxi(h, s.get_height())
	var sheet := Image.create(w, h, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#7d8a96"))
	var x := 0
	for s in sheets:
		sheet.blend_rect(s, Rect2i(0, 0, s.get_width(), s.get_height()), Vector2i(x, 0)); x += s.get_width() + 4
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png(r.shots_dir.path_join("crew_sheets.png"))

static func _b(kind: String, status: String, phase: int, label: String, waiting := false, col := "#e8432f", prog := 0.5) -> Dictionary:
	return {"kind": kind, "col": col, "status": status, "phase": phase, "waiting": waiting, "label": label, "prog": prog}

static func _c(role: String, name: String, busy := -1, col := "#e8432f") -> Dictionary:
	return {"role": role, "col": col, "name": name, "busy_bay": busy}

func _states() -> Array:
	var A := "#e8432f"
	var B := "#2f7de8"
	return [
		{"name": "garage_ws1", "ws": 1, "season": 0, "tod": "day", "facilities": ["kitchen"],
			"bays": [_b("hatch", "building", 2, "Kei Hatch"), _b("sport", "ready", 8, "Sport 250")],
			"crew": [_c("mech", "Kenji", 0), _c("mech", "Mabel", 0), _c("drv", "Rosa")]},
		{"name": "garage_ws2", "ws": 2, "season": 1, "tod": "day", "facilities": ["dyno", "gym"],
			"bays": [_b("sedan", "building", 0, "City Sedan", true), _b("coupe", "building", 5, "Coupe", false, A, 0.55),
				_b("mx", "ready", 8, "MX 250"), _b("gt", "upgrading", 8, "GT")],
			"crew": [_c("mech", "Kenji", 1), _c("mech", "Mabel", 3), _c("mech", "Otto", 3), _c("drv", "Rosa"), _c("drv", "Duke")]},
		{"name": "garage_ws3", "ws": 3, "season": 2, "tod": "day", "facilities": ["dyno", "wind", "gym"],
			"bays": [_b("rally", "ready", 8, "Rally 4WD"), _b("formula", "building", 3, "Formula"), _b("naked", "repair", 8, "Naked 600"),
				_b("pickup", "building", 6, "Pickup", true), _b("cafe", "ready", 8, "Cafe Racer"), _b("kart", "upgrading", 8, "Kart")],
			"crew": [_c("mech", "Kenji", 1), _c("mech", "Mabel", 1), _c("mech", "Otto", 2), _c("mech", "Yuki", 3), _c("mech", "Ade", 5),
				_c("drv", "Rosa"), _c("drv", "Duke")]},
		{"name": "garage_ws4", "ws": 4, "season": 3, "tod": "night", "facilities": ["dyno", "wind", "gym", "kitchen", "telemetry"],
			"bays": [_b("proto", "ready", 8, "Proto LMP"), _b("gp", "ready", 8, "GP 500", false, B), _b("super", "building", 1, "Hyper"),
				_b("buggy", "building", 4, "Buggy", true), _b("enduro", "repair", 8, "Enduro", false, B),
				_b("formula", "upgrading", 8, "F-Junior"), _b("smoto", "building", 0, "SuMo", false, B), _b("truck", "building", 7, "Trophy Truck"),
				_b("sidecar", "ready", 8, "Sidecar", false, B)],
			"crew": [_c("mech", "Kenji", 2), _c("mech", "Mabel", 3), _c("mech", "Otto", 4, B), _c("mech", "Yuki", 5), _c("mech", "Ade", 7),
				_c("mech", "Lin", 7), _c("mech", "Sol"), _c("drv", "Rosa"), _c("drv", "Duke", -1, B), _c("drv", "Vera")]},
		{"name": "garage_extra_ws3_winter_night", "ws": 3, "season": 3, "tod": "night", "facilities": ["kitchen", "telemetry"],
			"bays": [_b("hatch", "ready", 8, "Kei Hatch", false, "#2fb34a"), _b("trail", "building", 5, "Trail 200", false, "#2fb34a", 0.3),
				_b("roadster", "ready", 8, "Roadster", false, "#2fb34a")],
			"crew": [_c("mech", "Kenji", 1, "#2fb34a"), _c("drv", "Rosa", -1, "#2fb34a")], "team_col": "#2fb34a"},
		{"name": "garage_extra_ws1_autumn_night", "ws": 1, "season": 2, "tod": "night", "facilities": [],
			"bays": [_b("scooter", "repair", 8, "Scooter", false, "#f2b01e")],
			"crew": [_c("mech", "Kenji", 0, "#f2b01e"), _c("drv", "Rosa", -1, "#f2b01e")]},
	]

func run(r) -> void:
	_bake(r)
	var sheet := Image.create(GarageView.W * 2, GarageView.H * 3, false, Image.FORMAT_RGBA8)
	var k := 0
	var gv: GarageView = null
	for st in _states():
		if gv: gv.queue_free()
		gv = GarageView.new()     # fresh view: busy crew start at their bays
		r.main.add_child(gv)
		gv.bay_tapped.connect(func(i): taps.append(["bay", i]))
		gv.crew_tapped.connect(func(i): taps.append(["crew", i]))
		var t0 := Time.get_ticks_usec()
		gv.set_state(st)
		print("%s: set_state %.1f ms" % [st.name, (Time.get_ticks_usec() - t0) / 1000.0])
		r.ok(gv.slots.size() >= st.bays.size(), "%s: a slot per bay" % st.name)
		r.ok(gv.actors.size() == st.crew.size(), "%s: an actor per crew member" % st.name)
		await r.get_tree().create_timer(1.2).timeout
		await r.shot(st.name)
		if OS.get_environment("GARAGE_DEBUG") != "":
			for a in gv.actors: print("  %s %s pos=%s mode=%s goal=%s" % [a.role, a.key, a.pos, a.mode, a.goal])
		var img: Image = r.get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, GarageView.W, GarageView.H))
		sheet.blit_rect(img, Rect2i(0, 0, GarageView.W, GarageView.H), Vector2i((k % 2) * GarageView.W, (k / 2) * GarageView.H))
		k += 1
		# taps: the first bay and the first crew member
		taps.clear()
		var s0: Dictionary = gv.slots[0]
		var tp := Vector2(s0.cx, s0.gy - 12)
		for dy in range(0, 30, 3):
			if gv.hit_test(Vector2(s0.cx, s0.gy - 12 - dy)).get("kind", "") == "bay": tp = Vector2(s0.cx, s0.gy - 12 - dy); break
		gv._gui_input(_click(tp))
		var a0: Dictionary = gv.actors[0]
		var ap: Vector2 = a0.pos
		var hit := gv.hit_test(ap + Vector2(0, -10))
		r.ok(taps.size() == 1 and taps[0][0] == "bay", "%s: bay tap -> %s" % [st.name, taps])
		r.ok(hit.get("kind", "") == "crew", "%s: crew hit-test at %s -> %s" % [st.name, ap, hit])
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png(r.shots_dir.path_join("garage_all.png"))
	await _anim(r, gv)
	gv.queue_free()

## Re-assign the crew (as a career tick would) and film them walking to their new bays.
func _anim(r, gv: GarageView) -> void:
	var st: Dictionary = _states()[2].duplicate(true)
	gv.set_state(st)
	await r.get_tree().create_timer(0.5).timeout
	var before: Vector2 = gv.actors[0].pos
	st.crew[0].busy_bay = 3          # Kenji: formula -> pickup (other row)
	st.crew[2].busy_bay = -1         # Otto knocks off
	st.crew[5].busy_bay = 0          # Rosa checks on the rally car
	st.bays[3].waiting = false
	gv.set_state(st)
	var strip := Image.create(GarageView.W * 3, GarageView.H * 2, false, Image.FORMAT_RGBA8)
	for i in 6:
		await r.get_tree().create_timer(0.8).timeout
		await r.get_tree().process_frame
		var img: Image = r.get_viewport().get_texture().get_image().get_region(Rect2i(0, 0, GarageView.W, GarageView.H))
		strip.blit_rect(img, Rect2i(0, 0, GarageView.W, GarageView.H), Vector2i((i % 3) * GarageView.W, (i / 3) * GarageView.H))
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	strip.save_png(r.shots_dir.path_join("garage_anim.png"))
	var k: Dictionary = gv.actors[0]
	r.ok(k.pos != before, "re-assigned mechanic moved (%s -> %s)" % [before, k.pos])
	r.ok(k.goal == "work:3:0", "mechanic heads for the new bay (%s)" % k.goal)

func _click(p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e
