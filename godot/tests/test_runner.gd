extends Node
## In-game test driver: godot --path godot -- --test=<name>
##   sim        parity with the web build (RNG, tracks, profiles) + race batch stats
##   shots      screenshots of menus and race views across environments (needs a renderer)
##   net_host   / net_client   two-process LAN co-op race over 127.0.0.1
##   vs_host    / vs_client    two-process LAN versus drag duel
## Exit code 0 = pass. Reports go to stdout; screenshots to tests/shots/.

var main
var test_name := ""
var fails := 0

func _ready() -> void:
	run(main, test_name)
var shots_dir := ""

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", what)

func done() -> void:
	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)

func run(m, name: String) -> void:
	main = m
	shots_dir = ProjectSettings.globalize_path("res://tests/shots")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	match name:
		"sim": await t_sim()
		"shots": await t_shots()
		"net_host": await t_net_host("coop")
		"net_client": await t_net_client("coop")
		"vs_host": await t_net_host("versus")
		"vs_client": await t_net_client("versus")
		"bake": t_bake()
		_:
			# drop-in suites: tests/<name>.gd with `func run(r) -> void` (r = this runner: r.ok(), r.shot(), r.main)
			var path := "res://tests/%s.gd" % name
			if ResourceLoader.exists(path):
				var suite = load(path).new()
				await suite.run(self)
			else:
				print("unknown test ", name); fails = 1
	done()

func shot(file: String) -> void:
	for i in 3: await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(file + ".png"))
	print("shot ", file)

# ---------------- sim ----------------
func t_sim() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parity.json"))
	ok(URng.fnv("c1a") == int(fx.rngSeq[0]), "fnv c1a %d vs %d" % [URng.fnv("c1a"), int(fx.rngSeq[0])])
	ok(URng.fnv("h4x2") == int(fx.rngSeq[1]), "fnv h4x2")
	var r := URng.new(URng.fnv("c1a"))
	for i in 3:
		var a := r.next()
		ok(absf(a - float(fx.rngSeq[2 + i])) < 1e-12, "mulberry32 #%d %.15f vs %.15f" % [i, a, float(fx.rngSeq[2 + i])])
	for id in fx.tracks:
		var want: Dictionary = fx.tracks[id]
		var got := RaceSim.build_track(Data.race(id), false)
		ok(got.lapLen == int(want.lapLen), "track %s lapLen %d vs %d" % [id, got.lapLen, int(want.lapLen)])
		var same: bool = got.secs.size() == want.secs.size()
		if same:
			for i in got.secs.size():
				var g: Dictionary = got.secs[i]; var w: Array = want.secs[i]
				if g.type != w[0] or g.len != int(w[1]) or g.at != int(w[2]) or g.surf != w[3]: same = false
		ok(same, "track %s sections match the web build" % id)
	var team := {"tech": fx.tech, "partLv": fx.partLv}
	for vid in fx.prof:
		var P: Dictionary = fx.prof[vid]
		var p := Prof.profile(P.veh, P.staff, team)
		for k in ["S", "A", "H", "pm", "mis", "wear", "dur"]:
			ok(absf(float(p[k]) - float(P.profile[k])) < 1e-6, "profile %s %s: %s vs %s" % [P.veh.body, k, p[k], P.profile[k]])
		for k in ["on", "off", "wet", "ice"]:
			ok(int(p.t[k]) == int(P.profile.t[k]), "terrain %s %s" % [P.veh.body, k])
		var sk := Prof.race_secs(P.veh, RaceSim.build_track(Data.race("c1a"), false), team)
		ok(absf(sk[0].ef - float(P.secs0.ef)) < 1e-9, "section ef %s" % P.veh.body)
	# race batches: presets should land mid-field in their tier's middle race
	var i_pool := 0
	var all_pos := 0.0; var all_n := 0
	for s in Game.presets():
		var pool: Array = Data.D.RACES.filter(func(x): return int(x.tier) == int(s.tier) and x.disc == s.disc)
		if pool.is_empty(): continue
		var def: Dictionary = pool[(i_pool * 7) % pool.size()]
		i_pool += 1
		var pos_sum := 0.0; var fin := 0; var n := 12
		for i in n:
			var fm: Dictionary = Data.formats_m1(def.id)[0]
			var trk := RaceSim.build_track(def, false, fm.laps if int(fm.laps) != int(def.laps) else null)
			var rs := RaceSim.create(def, [Game.make_entry(s, trk, 1, "Test", "me", "#e8432f")], {"fmt": fm})
			rs.run_instant()
			var me: Dictionary = rs.humans()[0]
			pos_sum += float(me.pos) / rs.ents.size()
			if me.fin: fin += 1
		print("  %-15s T%d %-28s avg pos %3d%%  odds %.2f  finished %d/%d" % [s.label, s.tier, def.n, int(pos_sum / n * 100), Game.odds(s, def), fin, n])
		ok(fin >= n * 0.75, "%s finishes most races" % s.label)
		all_pos += pos_sum / n; all_n += 1
	print("  presets: mean finishing position %d%% of field (0%% = win, 100%% = last)" % int(all_pos / all_n * 100))
	ok(all_pos / all_n > 0.15 and all_pos / all_n < 0.7, "presets are competitive but not dominant")
	# multi-human: co-op pair + race calls
	var d2 := Data.race("c2c")
	var trk2 := RaceSim.build_track(d2, false)
	var a := Game.make_entry(Game.presets()[4], trk2, 1, "Coop", "coop", "#e8432f")
	var b := Game.make_entry(Game.presets()[4], trk2, 2, "Coop", "coop", "#2f7de8")
	var rs2 := RaceSim.create(d2, [a, b], {})
	var hs := rs2.humans()
	ok(hs.size() == 2, "two human entries")
	for i in 30: rs2.step(0.05)
	rs2.set_tactic(hs[0].idx, "push")
	ok(hs[0].tactic == "push", "tactic applied")
	ok(rs2.use_spark(hs[1].idx, "b") and hs[1].sparks.b == 1 and hs[1].boost > 0, "spark applied")
	ok(not rs2.use_spark(hs[1].idx, "g"), "no gold spark available")
	rs2.run_instant()
	var tt := rs2.team_table()
	ok(tt.any(func(x): return x[0] == "coop"), "coop team scored")
	print("  co-op table: ", tt.slice(0, 4))
	# drag + hill formats
	var dr: Array = Data.D.RACES.filter(func(x): return x.style == "drag")
	var rs3 := RaceSim.create(dr[0], [Game.make_entry(Game.presets()[0], RaceSim.build_track(dr[0], false), 1, "A", "p1", "#e8432f"), Game.make_entry(Game.presets()[1], RaceSim.build_track(dr[0], false), 2, "B", "p2", "#2f7de8")], {"n_rivals": 0})
	rs3.run_instant()
	var ets: Array = rs3.humans().map(func(e): return e.get("et", {}))
	print("  drag ETs: ", ets)
	ok(rs3.humans().all(func(e): return e.dnf or e.has("et")), "drag ET computed")
	var hc: Array = Data.D.RACES.filter(func(x): return x.style == "hill")
	var rs4 := RaceSim.create(hc[0], [Game.make_entry(Game.presets()[0], RaceSim.build_track(hc[0], false), 1, "A", "p1", "#e8432f")], {"fmt": Data.formats_m1(hc[0].id)[0]})
	ok(rs4.tt, "hillclimb runs as time trial")
	rs4.run_instant()
	ok(rs4.done, "hillclimb finished")
	# geometry: every style closes / lays out inside the texture budget
	for st in ["oval", "circuit", "tech", "speed", "street", "mx", "enduro", "rally", "desert", "hill", "mixed", "drag"]:
		var rr: Array = Data.D.RACES.filter(func(x): return x.style == st)
		if rr.is_empty(): continue
		for def3 in rr.slice(0, 3):
			var g := TrackGeo.build(RaceSim.build_track(def3, false), def3.id)
			var tx: Vector2 = g.bbox.size / g.tex_scale
			ok(tx.x <= TrackGeo.MAX_TEX and tx.y <= TrackGeo.MAX_TEX and tx.x * tx.y <= TrackGeo.MAX_TEXELS + 1.0, "%s texture %s" % [def3.id, tx])
			if g.closed: ok(g.pts[0].distance_to(g.pts[g.pts.size() - 1]) < 0.01, "%s closes" % def3.id)

# ---------------- screenshots ----------------
func t_shots() -> void:
	main.title_screen()
	await _frames(40)
	await shot("01_title")
	main.quick_screen()
	await shot("02_quick")
	var picks := [["c2c", 4], ["o2b", 5], ["d1a", 7], ["o1c", 1], ["o2a", 5], ["b1b", 6], ["c3c", 8], ["r1a", 0], ["h2a", 10]]
	var k := 3
	for pk in picks:
		var def := Data.race(pk[0])
		if def.is_empty():
			var alt: Array = Data.D.RACES.filter(func(x): return x.id.begins_with(pk[0].substr(0, 2)))
			if alt.is_empty(): continue
			def = alt[0]
		var pre: Array = Game.presets()
		var s: Dictionary = pre[pk[1]]
		if not Data.race_cls_ok(def, Game.cls_of(s)):
			for p2 in pre:
				if Data.race_cls_ok(def, Game.cls_of(p2)) and int(p2.tier) == int(def.tier): s = p2; break
		var fm: Dictionary = Data.formats_m1(def.id)[0]
		var trk := RaceSim.build_track(def, false, fm.laps if int(fm.laps) != int(def.laps) else null)
		var rs := RaceSim.create(def, [Game.make_entry(s, trk, 1, Game.player.team, "me", Game.player.col)], {"fmt": fm, "rain": pk[0] == "b1b"})
		main._open_race(func(rv): rv.start_sim(rs, "local", 1))
		main.race_view.speed = 2.0
		await _secs(5.0 if k == 3 else 3.5)
		await shot("%02d_race_%s" % [k, def.id])
		k += 1
	main.race_view.speed = 4.0
	main.race_view._skip()
	await _secs(2.0)
	await shot("%02d_results" % k)
	main.garage_screen()
	await shot("%02d_garage" % (k + 1))
	main.lan_screen("coop")
	await shot("%02d_lan" % (k + 2))
	_contact_sheet("sprites.png")

## Bake the super-deformed vehicle sheets to art/vehicles/*.png (index colours; palette-swapped at runtime).
func t_bake() -> void:
	var dir := ProjectSettings.globalize_path("res://art/vehicles")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := OS.get_environment("BAKE_ONLY")
	for k in SpriteForge.KINDS:
		if only != "" and not only.split(",").has(k): continue
		var t0 := Time.get_ticks_msec()
		var img := SpriteForge.bake_vehicle(k)
		img.save_png(dir.path_join(k + ".png"))
		print("baked %-9s %5d ms" % [k, Time.get_ticks_msec() - t0])
	var pdir := ProjectSettings.globalize_path("res://art/props")
	DirAccess.make_dir_recursive_absolute(pdir)
	var strip := Image.create(SpriteForge.PCELL.x * SpriteForge.PROPS.size(), SpriteForge.PCELL.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color("#4a9c42"))
	for i in SpriteForge.PROPS.size():
		var pn: String = SpriteForge.PROPS[i]
		if only != "" and not only.split(",").has(pn) and not only.split(",").has("props"): continue
		var pimg := SpriteForge.bake_prop(pn)
		pimg.save_png(pdir.path_join(pn + ".png"))
		strip.blend_rect(SpriteForge.colorize_sd(pimg, Color.WHITE), Rect2i(Vector2i.ZERO, SpriteForge.PCELL), Vector2i(i * SpriteForge.PCELL.x, 0))
		print("baked prop %s" % pn)
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	strip.save_png(shots_dir.path_join("props_sd.png"))
	_contact_sheet("sprites_sd.png", true)

func _contact_sheet(file: String, from_disk := false) -> void:
	var cell := SpriteForge.VCELL
	var kinds := ["hatch", "gt", "rally", "pickup", "formula", "buggy", "sport", "mx", "naked", "kart"]
	var img := Image.create(cell.x * 9, cell.y * kinds.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color("#4a9c42"))
	for row in kinds.size():
		var idx: Image
		var path := ProjectSettings.globalize_path(SpriteForge.vehicle_path(kinds[row]))
		if from_disk and FileAccess.file_exists(path): idx = Image.load_from_file(path)
		else: idx = SpriteForge.vehicle_tex(kinds[row]).get_image()
		var sheet := SpriteForge.colorize_sd(idx, Color(Data.D.TEAM_COLORS[row % Data.D.TEAM_COLORS.size()]))
		for f in 8:
			img.blend_rect(sheet, Rect2i(f * 2 * cell.x, 0, cell.x, cell.y), Vector2i(f * cell.x, row * cell.y))
		img.blend_rect(sheet, Rect2i(2 * cell.x, cell.y, cell.x, cell.y), Vector2i(8 * cell.x, row * cell.y))   # wheelie
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(shots_dir.path_join(file))

func _secs(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

# ---------------- LAN ----------------
func t_net_host(mode: String) -> void:
	Game.player.name = "Hosty"
	Game.sel = 4 if mode == "coop" else 0
	ok(Net.host(mode) == OK, "host opened")
	main.lobby_screen()
	var t0 := Time.get_ticks_msec()
	while Net.lobby.players.size() < 2 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	ok(Net.lobby.players.size() == 2, "client registered (%d players)" % Net.lobby.players.size())
	Net.set_lobby("cls", "T2" if mode == "coop" else "open")
	if mode == "versus":
		Net.set_lobby("duel", "drag")
	var races := Net.eligible_races()
	ok(races.size() > 0, "eligible races")
	var pick: Dictionary = races[0]
	for r in races:
		if mode == "coop" and r.id == "c2c": pick = r
	Net.lobby.race_id = pick.id
	Net.set_lobby("fmt_id", Data.formats_m1(pick.id)[0].id)
	await _frames(30)
	await shot(mode + "_host_lobby")
	main._host_start()
	ok(main.race_view != null and main.race_view.sim != null, "host race running")
	var rv: RaceView = main.race_view
	rv.speed = 2.0
	await _frames(150)
	await shot(mode + "_host_race")
	if mode == "coop":
		ok(rv.sim.humans().all(func(e): return (e.S + e.A + e.H) / 3.0 <= Game.class_cap(2) + 0.01), "T2 class cap applied")
	var remote := rv.sim.humans().filter(func(e): return int(e.owner) != 1)
	ok(remote.size() == 1, "remote entry present")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000: await get_tree().process_frame
	if mode == "coop" and remote.size() == 1:
		ok(remote[0].sparks.b < 2 or remote[0].tactic == "push", "client race call reached host (sparks %s, tactic %s)" % [remote[0].sparks, remote[0].tactic])
	rv.speed = 4.0
	t0 = Time.get_ticks_msec()
	while main.race_view != null and Time.get_ticks_msec() - t0 < 90000: await get_tree().process_frame
	ok(main.race_view == null, "race finished on host")
	await shot(mode + "_host_results")
	await _frames(120)   # let the client receive results before closing
	Net.leave()

func t_net_client(mode: String) -> void:
	Game.player.name = "Clio"
	Game.player.col = "#2f7de8"
	Game.sel = 6 if mode == "coop" else 1
	await _frames(20)
	ok(Net.join("127.0.0.1") == OK, "client socket")
	var t0 := Time.get_ticks_msec()
	while main.race_view == null and Time.get_ticks_msec() - t0 < 30000: await get_tree().process_frame
	ok(main.race_view != null, "client received race setup")
	if main.race_view == null: return
	var rv: RaceView = main.race_view
	t0 = Time.get_ticks_msec()
	while not rv.started and Time.get_ticks_msec() - t0 < 10000: await get_tree().process_frame
	ok(rv.started, "client got snapshots")
	var mine := rv.ents.filter(func(e): return rv.is_mine(e))
	ok(mine.size() == 1, "client owns one entry")
	if mode == "coop" and mine.size() == 1:
		rv.call_cmd(int(mine[0].idx), "tactic", "push")
		rv.call_cmd(int(mine[0].idx), "spark", "b")
	await _frames(90)
	await shot(mode + "_client_race")
	t0 = Time.get_ticks_msec()
	var p0: float = mine[0].prog if mine.size() else 0.0
	while main.race_view != null and Time.get_ticks_msec() - t0 < 90000: await get_tree().process_frame
	ok(main.race_view == null, "client saw results")
	await _frames(10)
	await shot(mode + "_client_results")
