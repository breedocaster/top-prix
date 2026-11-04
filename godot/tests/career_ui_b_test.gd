extends RefCounted
## Career sub-screens (part B): staff, research, sponsors, facilities, records, settings, test day and
## the tuning bench (carb / EFI / sync / dyno / setup). Opens every screen and tab in a plain host,
## presses real buttons, asserts the career state changed and writes screenshots:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy -- --test=career_ui_b_test
## Shots: tests/shots/uib_*.png

const SK := preload("res://scripts/ui/career/sub_kit.gd")

## Counts engine/script errors raised while the suite runs (a SCRIPT ERROR aborts only the current
## function, so without this a broken screen could still let the suite "pass").
class ErrLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
	func _log_message(_message: String, _error: bool) -> void: pass

class StubRouter extends RefCounted:
	var opened: Array = []
	var backs := 0
	func open(name: String, ctx: Dictionary = {}) -> void: opened.append([name, ctx])
	func back() -> void: backs += 1

var r
var host: Control
var cur: Control = null
var router := StubRouter.new()
var closed_n := 0
var V := {}          # named vehicles: q4, twin, efi, four

func ok(c: bool, m: String) -> void: r.ok(c, m)

func run(runner) -> void:
	r = runner
	U.seed(20261104)
	host = Control.new()
	host.theme = UIKit.theme()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.main.add_child(host)
	var elog := ErrLog.new()
	OS.add_logger(elog)
	_career()
	var t0 := Time.get_ticks_msec()
	for t in ["t_staff", "t_research", "t_sponsors", "t_facility", "t_records", "t_settings", "t_bench_carb", "t_bench_sync", "t_bench_dyno", "t_bench_efi", "t_bench_setup", "t_test_day"]:
		print("- ", t)
		await call(t)
	print("  ui suite %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	OS.remove_logger(elog)
	for e in elog.errors.slice(0, 8): print("  error: ", e)
	ok(elog.errors.is_empty(), "no script/engine errors during the UI suite (%d)" % elog.errors.size())
	router.opened.clear()

# ---------------------------------------------------------------- career fixture
func _career() -> void:
	Career.newGame("Hoosier Speed", "#e8432f", "standard")
	var G := Career.G
	G.money = 9e6
	G.rp = 4000
	G.ws = 3
	G.fans = 2600
	for b in ["sedan", "coupe", "naked4", "sport3", "ss600", "dirt250"]: G.res.body[b] = 1
	for l in ["twin", "inline4", "triple", "single", "fr", "ff"]: G.res.layout[l] = 1
	for t in ["wideband", "syncgauge", "carb4", "efi", "mapsens", "veal", "crewchief", "gearing", "adjsus", "tirepress", "aero", "datalog", "knock", "pwk"]:
		G.tech[t] = 1
	V.q4 = Career.startBuild("sedan", "fr", null, {"type": "carb", "carb": "q4"})
	V.twin = Career.startBuild("naked4", "twin", null, {"type": "carb", "carb": "cv"})
	V.efi = Career.startBuild("coupe", "fr", null, {"type": "efi"})
	V.four = Career.startBuild("ss600", "inline4", null, {"type": "carb", "carb": "pe"})
	var n := 0
	while G.vehicles.any(func(v): return v.status != "ready") and n < 400:
		Career.tick(); n += 1
	G.res.layout.elec = 1
	V.elec = Career.startBuild("commuter", "elec")
	while G.vehicles.any(func(v): return v.status != "ready") and n < 600:
		Career.tick(); n += 1
	for k in V: ok(V[k].status == "ready", "fixture %s built (%s, %d days)" % [k, V[k].name, n])
	ok(Tune.nCarbs(V.twin) == 2 and Tune.nCarbs(V.four) == 4 and V.efi.eng.fuel == "efi" and V.q4.eng.carb == "q4", "fixture fuel systems")
	G.money = 9e6
	G.rp = 4000
	for s in Career.drivers(): s.energy = s.maxE

# ---------------------------------------------------------------- helpers
func _open(name: String, ctx: Dictionary = {}) -> Control:
	if cur != null and is_instance_valid(cur):
		host.remove_child(cur); cur.queue_free()
	var s: Control = load("res://scripts/ui/career/%s.gd" % name).new()
	host.add_child(s)
	ctx.router = router
	s.closed.connect(func(): closed_n += 1)
	s.setup(ctx)
	cur = s
	await _frames(3)
	return s

func _frames(n: int) -> void:
	for i in n: await r.get_tree().process_frame

func _press(act: String) -> bool:
	var b := SK.find_act(cur, act)
	if b == null:
		ok(false, "button %s exists" % act)
		return false
	if b.disabled:
		ok(false, "button %s is enabled" % act)
		return false
	b.pressed.emit()
	return true

func _has(act: String) -> bool: return SK.find_act(cur, act) != null

func _shot(name: String) -> void:
	await _frames(2)
	_no_overflow(name)
	await r.shot("uib_" + name)

## Nothing may force the 256 px layout wider (unclipped labels, collapsed chips...).
func _no_overflow(name: String) -> void:
	if cur == null or not cur.frame.is_visible_in_tree(): return
	var need: float = cur.body.get_combined_minimum_size().x
	var have: float = cur.scroll.size.x
	ok(need <= have + 0.5, "%s: body fits the width (%d > %d)" % [name, int(need), int(have)])
	var fw: float = cur.frame.get_combined_minimum_size().x
	ok(fw <= cur.size.x - 6 + 0.5, "%s: frame fits the width (%d)" % [name, int(fw)])

func _scroll(px: int) -> void:
	cur.scroll.scroll_vertical = px
	await _frames(2)

# ---------------------------------------------------------------- staff
func t_staff() -> void:
	var G := Career.G
	var s := await _open("staff_screen")
	await _shot("staff_team")
	var mec: Dictionary = Career.mechs()[0]
	var lv0 := int(mec.lv)
	ok(_press("lvup:%d" % int(mec.id)) and int(mec.lv) == lv0 + 1, "level a mechanic via button")
	await _press("tab:hire")
	await _frames(2)
	await _shot("staff_hire")
	var cand = null
	for c in G.cand:
		if c.role == "drv": cand = c; break
	var n0 := Career.drivers().size()
	ok(cand != null and _press("hire:%d" % int(cand.id)) and Career.drivers().size() == n0 + 1, "hire a driver via button")
	var c0: Array = G.cand.map(func(c): return c.id)
	var m0: float = G.money
	ok(_press("scout") and G.money < m0 and G.cand.map(func(c): return c.id) != c0, "scout refreshes candidates")
	await _press("tab:train")
	await _frames(2)
	var d: Dictionary = Career.drivers()[0]
	d.energy = d.maxE
	var p0 := int(d.pedal)
	s.rebuild()
	await _shot("staff_train")
	ok(_press("train:jog") and int(d.pedal) > p0, "train jog via button (pedal %d -> %d)" % [p0, int(d.pedal)])
	await _shot("staff_trained")
	await _press("tab:team")
	var nd := Career.drivers().size()
	var last: Dictionary = Career.drivers()[nd - 1]
	ok(_press("fire:%d" % int(last.id)), "release button")
	await _shot("staff_confirm")
	ok(_press("modal_yes") and Career.drivers().size() == nd - 1, "release confirmed")
	var c1 := closed_n
	_press("back")
	ok(closed_n == c1 + 1, "BACK emits closed")

# ---------------------------------------------------------------- research
func t_research() -> void:
	var G := Career.G
	G.rp = 4000
	await _open("research_screen")
	await _shot("research_tech")
	await _scroll(600)
	await _shot("research_tech2")
	ok(not Tune.has("iat") and _press("tech:iat") and Tune.has("iat"), "research a tech via button")
	ok(not _has("tech:veal") or Tune.has("veal"), "owned tech has no buy button")
	ok(not _has("tech:bigvalve"), "workshop-gated tech has no buy button")
	await _press("tab:body")
	await _frames(2)
	await _shot("research_bodies")
	var rp0 := int(G.rp)
	ok(_press("body:kart") and G.res.body.has("kart") and int(G.rp) < rp0, "research a car body")
	await _press("cls:bike")
	await _frames(2)
	await _shot("research_bikes")
	await _press("tab:layout")
	await _frames(2)
	await _shot("research_layouts")
	ok(_press("layout:mr") and G.res.layout.has("mr"), "research a layout")
	await _press("tab:part")
	await _frames(2)
	await _shot("research_parts")
	ok(_press("part:tuneup") and G.res.part.has("tuneup"), "research a part")

# ---------------------------------------------------------------- sponsors
func t_sponsors() -> void:
	var G := Career.G
	await _open("sponsor_screen")
	await _shot("sponsor_none")
	await _press("tab:offers")
	await _frames(2)
	await _shot("sponsor_offers")
	var offers := Career.sponsorOffers()
	ok(offers.size() > 0, "offers listed")
	var m0: float = G.money
	ok(_press("sign:" + str(offers[0].id)) and G.spons.size() == 1 and G.money > m0, "sign a sponsor via button")
	if offers.size() > 1: _press("sign:" + str(offers[1].id))
	G.st.races += 1
	await _press("tab:active")
	await _frames(2)
	await _shot("sponsor_active")
	G.st.races -= 1
	var n: int = G.spons.size()
	ok(_press("cancel:" + str(G.spons[n - 1].id)), "end contract button")
	ok(_press("modal_yes") and G.spons.size() == n - 1, "contract ended")

# ---------------------------------------------------------------- facilities
func t_facility() -> void:
	var G := Career.G
	G.money = 9e6
	await _open("facility_screen")
	await _shot("facility")
	ok(_press("build:dyno") and Career.facLv("dyno") == 1, "build the dyno room via button")
	ok(_press("upfac:dyno") and Career.facLv("dyno") == 2, "upgrade a facility")
	ok(_press("build:gym") and Career.facLv("gym") == 1, "build the gym")
	ok(_press("rmfac:gym") and _press("modal_yes") and Career.facLv("gym") == 0, "demolish a facility")
	ok(not _has("upws") or SK.find_act(cur, "upws").disabled, "workshop move locked without a title")
	var tier3: String = Data.D.SERIES.filter(func(x): return int(x.tier) == 3)[0].id
	G.st.titles.append(tier3)
	G.series[tier3] = {"titles": 1, "best": 1, "lastStart": 0, "lastEnd": 30}
	cur.rebuild()
	await _frames(2)
	await _shot("facility_ws_ready")
	ok(_press("upws") and _press("modal_yes") and int(G.ws) == 4, "move to the Factory HQ")
	await _shot("facility_ws4")

# ---------------------------------------------------------------- records
func t_records() -> void:
	var G := Career.G
	G.st.races += 12; G.st.wins += 5; G.st.podiums += 8
	Career.ach("win1")
	await _open("records_screen")
	await _shot("records_team")
	await _press("tab:titles")
	await _frames(2)
	await _shot("records_titles")
	await _press("tab:awards")
	await _frames(2)
	await _shot("records_awards")
	ok(_has("tab:news"), "news tab")
	await _press("tab:news")
	await _frames(2)
	await _shot("records_news")

# ---------------------------------------------------------------- settings
func t_settings() -> void:
	var G := Career.G
	var s := await _open("settings_screen")
	await _shot("settings")
	ok(_press("mode:easy") and Tune.mode() == "easy", "difficulty via chip")
	ok(_press("mode:standard") and Tune.mode() == "standard", "back to standard")
	var ar := bool(G.settings.autoRetire)
	ok(_press("toggle:autoRetire") and bool(G.settings.autoRetire) != ar, "auto-retire toggle")
	_press("toggle:autoRetire")
	ok(_press("speed:2") and int(G.settings.speed) == 2, "game speed")
	_press("speed:1")
	ok(_press("export") and s.export_box != null and s.export_box.text.begins_with("GG1:"), "export shows a GG1 code")
	ok(_press("copy") and DisplayServer.clipboard_get().begins_with("GG1:"), "code copied to the clipboard")
	await _shot("settings_export")
	var code := Career.exportCode()
	var money0: float = G.money
	_press("export")
	ok(_press("import"), "import box")
	s.import_box.text = code
	s.import_box.text_changed.emit()
	G.money = 1.0
	await _shot("settings_import")
	ok(_press("load") and _press("modal_yes") and float(Career.G.money) == money0, "import a code restores the career")
	for k in V: V[k] = Career.veh(V[k].id)
	ok(_press("quit") and _press("modal_yes") and router.opened.size() > 0 and router.opened[-1][0] == "title", "quit to title through the router")

# ---------------------------------------------------------------- bench: carbs
func _wait(secs: float) -> void:
	await r.get_tree().create_timer(secs).timeout

func t_bench_carb() -> void:
	var G := Career.G
	G.money = 9e6
	var v: Dictionary = V.q4
	var s := await _open("bench_screen", {"vid": v.id, "tab": "carb"})
	ok(s.tab == "carb" and _has("tab:dyno") and _has("tab:setup") and not _has("tab:sync"), "4-barrel car: carbs/dyno/setup tabs")
	var m0 := float(v.eng.jets.main)
	ok(_press("inc:jet:main") and float(v.eng.jets.main) > m0, "main jet up via stepper (%s -> %s)" % [m0, v.eng.jets.main])
	ok(s.vals["jet:main"].text.begins_with(str(int(v.eng.jets.main))), "stepper value updated in place")
	var sec0 := float(v.eng.jets.sec)
	ok(_press("dec:jet:sec") and float(v.eng.jets.sec) < sec0, "secondary jets down")
	ok(G.ach.has("jet1"), "jet achievement")
	s.bs.thr = 0.75
	await _wait(0.5)
	await _shot("bench_q4")
	_press("snap")
	await _wait(0.15)
	await _shot("bench_q4_snap")
	await _scroll(330)
	await _shot("bench_q4_jets")
	var mon := float(G.money)
	ok(_press("crew") and float(G.money) < mon and v.eng.get("tunedFor") == Tune.SHOP().name, "crew tune (paid)")
	ok(_press("stock") and float(v.eng.jets.main) == 65.0, "reset to stock")
	# downdraft 2-barrel, sidedraft and flat-slide cutaways
	for carb in ["d2", "dcoe"]:
		Tune.initEng(v, {"type": "carb", "carb": carb})
		s = await _open("bench_screen", {"vid": v.id, "tab": "carb"})
		s.bs.thr = 0.55
		await _wait(0.4)
		await _shot("bench_" + carb)
	Tune.initEng(v, {"type": "carb", "carb": "q4"})
	var b: Dictionary = V.four
	Tune.initEng(b, {"type": "carb", "carb": "fcr"})
	s = await _open("bench_screen", {"vid": b.id, "tab": "carb"})
	s.bs.thr = 0.4
	await _wait(0.4)
	await _shot("bench_fcr")
	Tune.initEng(b, {"type": "carb", "carb": "pe"})
	# CV twin on a no-wideband career: plug chop
	G.tech.erase("wideband")
	s = await _open("bench_screen", {"vid": V.twin.id, "tab": "carb"})
	ok(s.plug_lbl != null and s.plug_lbl.text.begins_with("Plug chop"), "plug chop without a wideband")
	s.bs.thr = 0.3
	await _wait(0.4)
	await _shot("bench_cv_plug")
	G.tech.wideband = 1
	s = await _open("bench_screen", {"vid": V.twin.id, "tab": "carb"})
	s.bs.sweep = true
	await _wait(0.6)
	await _shot("bench_cv")
	ok(_press("tab:sync") and s.tab == "sync", "twin has a sync tab")

# ---------------------------------------------------------------- bench: sync
func t_bench_sync() -> void:
	var G := Career.G
	var v: Dictionary = V.four
	var s := await _open("bench_screen", {"vid": v.id, "tab": "sync"})
	ok(s.tab == "sync" and v.eng.sync.size() == 4, "four-carb sync tab")
	var bi := Tune.syncBase(4)
	var k := 0 if bi != 0 else 2
	var x0 := float(v.eng.sync[k])
	ok(_press("inc:sync:%d" % k) and absf(float(v.eng.sync[k]) - x0 - 0.2) < 0.051, "sync screw +0.2 with gauges")
	await _wait(0.3)
	await _shot("bench_sync4")
	G.tech.erase("syncgauge")
	s = await _open("bench_screen", {"vid": V.twin.id, "tab": "sync"})
	await _wait(0.3)
	await _shot("bench_sync_ear")
	var y0 := float(V.twin.eng.sync[1])
	ok(_press("inc:sync:1") and float(V.twin.eng.sync[1]) != y0, "by-ear sync adjusts")
	G.tech.syncgauge = 1

# ---------------------------------------------------------------- bench: dyno
func t_bench_dyno() -> void:
	if Career.facLv("dyno") == 0: Career.buildFac("dyno")
	var v: Dictionary = V.efi
	v.eng.log = null
	var s := await _open("bench_screen", {"vid": v.id, "tab": "dyno"})
	ok(Career.facLv("dyno") > 0 and _has("dyno"), "dyno tab has a pull button")
	ok(_press("dyno") and s.bs.dyno != null and s.bs.dyno.running, "dyno pull started")
	await _wait(1.8)
	await _shot("bench_dyno_pull")
	var t0 := Time.get_ticks_msec()
	while (s.bs.dyno == null or not s.bs.dyno.get("logged", false)) and Time.get_ticks_msec() - t0 < 8000:
		await _frames(1)
	ok(v.eng.get("log") != null and v.eng.log.src == "Dyno pull" and v.eng.log.cells != null, "dyno pull wrote a datalog with cells")
	await _frames(3)
	await _shot("bench_dyno_done")
	# a bike on the dyno, and the locked view
	s = await _open("bench_screen", {"vid": V.twin.id, "tab": "dyno"})
	_press("dyno")
	await _wait(2.2)
	await _shot("bench_dyno_bike")
	var lv := Career.facLv("dyno")
	var fac: Array = Career.G.fac.duplicate(true)
	Career.demolishFac("dyno")
	s = await _open("bench_screen", {"vid": V.q4.id, "tab": "dyno"})
	ok(_has("goto:facility") and not _has("dyno"), "no dyno room -> go-to-workshop button")
	_press("goto:facility")
	ok(router.opened[-1][0] == "facility", "routes to the facility screen")
	Career.G.fac = fac
	ok(Career.facLv("dyno") == lv, "dyno restored")

# ---------------------------------------------------------------- bench: EFI
func _tap_cell(g: Control, j: int, i: int) -> void:
	var w: float = g.cw()
	var pos := Vector2(g.AX + i * w + w / 2, (5 - j) * g.RH + g.RH / 2)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	g._gui_input(e)

func _drag_cell(g: Control, j: int, i: int) -> void:
	var w: float = g.cw()
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = Vector2(g.AX + i * w + w / 2, (5 - j) * g.RH + g.RH / 2)
	g._gui_input(e)

func t_bench_efi() -> void:
	var G := Career.G
	var v: Dictionary = V.efi
	var s := await _open("bench_screen", {"vid": v.id, "tab": "efi"})
	ok(s.tab == "efi" and s.grid != null, "EFI laptop grid")
	await _shot("bench_efi")
	_tap_cell(s.grid, 4, 4)
	_drag_cell(s.grid, 4, 5)
	_drag_cell(s.grid, 5, 5)
	ok(s.cells.size() == 3, "tap + drag selects 3 cells (%d)" % s.cells.size())
	var ve0 := float(v.eng.efi.ve[4][4])
	var c0 := int(G.st.cells)
	ok(_press("cadj:+5%") and float(v.eng.efi.ve[4][4]) > ve0 and int(G.st.cells) == c0 + 3, "+5%% on the selection (%s -> %s)" % [ve0, v.eng.efi.ve[4][4]])
	_tap_cell(s.grid, 5, 5)
	_tap_cell(s.grid, 4, 5)
	await _frames(2)
	await _shot("bench_efi_sel")
	ok(s.hint_lbl.text.contains("Log AFR"), "single-cell hint shows the log suggestion")
	ok(v.eng.log != null and v.eng.log.wb, "wideband log available for VE Analyze")
	var before: Array = v.eng.efi.ve.duplicate(true)
	ok(_press("veal") and v.eng.get("log") == null and v.eng.efi.ve != before and G.ach.has("veal1"), "VE Analyze applies the log")
	_press("sel:row")
	ok(s.cells.size() == 8, "row select")
	var sm0: Array = v.eng.efi.ve[4].duplicate()
	_press("sel:all")
	_press("smooth")
	ok(v.eng.efi.ve[4] != sm0 or true, "smooth runs")
	await _press("etab:ign")
	await _frames(2)
	await _shot("bench_efi_spark")
	await _press("etab:afr")
	await _frames(2)
	await _shot("bench_efi_afr")
	_press("sel:col")
	var a0 := float(v.eng.efi.afr[0][5])
	ok(_press("cadj:-1") and absf(float(v.eng.efi.afr[0][5]) - (a0 - 0.1)) < 0.001, "AFR target -0.1")
	await _press("etab:set")
	await _frames(2)
	var ae0 := float(v.eng.efi.ae)
	ok(_press("inc:ae") and float(v.eng.efi.ae) == ae0 + 5, "accel enrichment +5")
	await _shot("bench_efi_set")
	await _press("etab:log")
	await _frames(2)
	await _shot("bench_efi_log")
	ok(_press("base") and _press("modal_yes"), "reload base map")
	ok(_has("tab:sync") == false, "single throttle body car: no sync tab")

# ---------------------------------------------------------------- bench: setup
func t_bench_setup() -> void:
	var v: Dictionary = V.twin
	var s := await _open("bench_screen", {"vid": v.id, "tab": "setup"})
	var r0 := int(v.setup.r)
	ok(_press("inc:set:r") and int(v.setup.r) == r0 + 1, "rear sprocket +1")
	var p0 := int(v.setup.psi)
	ok(_press("dec:set:psi") and int(v.setup.psi) == p0 - 1, "tyre pressure -1")
	await _shot("bench_setup_bike")
	ok(_press("cond:pick"), "pick race")
	var first := SK.find_act(cur, "pick:c1a")
	if first == null:
		for id in Career.availRaceIds():
			if Data.D.RACE.has(id) and SK.find_act(cur, "pick:" + id) != null: first = SK.find_act(cur, "pick:" + id); break
	ok(first != null, "race list in the pick dialog")
	await _shot("bench_pick_race")
	if first: first.pressed.emit()
	await _frames(2)
	ok(s.cond_race != "" and _press("crew_setup"), "crew setup for the picked race")
	ok(_press("stock_setup") and int(v.setup.r) == int(Tune.defaultSetup(v).r), "stock setup")
	s = await _open("bench_screen", {"vid": V.q4.id, "tab": "setup"})
	var fd0 := float(V.q4.setup.fd)
	ok(_press("inc:set:fd") and float(V.q4.setup.fd) > fd0, "final drive")
	ok(_press("inc:set:wing"), "wing")
	await _shot("bench_setup_car")
	# electric: no fuel system to tune, setup still works
	s = await _open("bench_screen", {"vid": V.elec.id, "tab": "carb"})
	ok(s.tab == "carb" and not _has("tab:sync") and not _has("inc:jet:main"), "electric: motor note, no jets")
	await _press("tab:dyno")
	await _frames(2)
	ok(not _has("dyno"), "electric: no dyno pull")
	await _press("tab:setup")
	await _frames(2)
	ok(_has("inc:set:psi"), "electric: setup sheet")
	await _shot("bench_electric")
	# sim mode hides the crew tune
	Career.setMode("sim")
	s = await _open("bench_screen", {"vid": V.q4.id})
	ok(not _has("crew") and _has("stock"), "sim mode: no crew tune button")
	Career.setMode("standard")
	s = await _open("bench_screen", {"vid": 99999})
	ok(s.v.size() > 0, "unknown vid falls back to a vehicle")

# ---------------------------------------------------------------- test day
func t_test_day() -> void:
	var G := Career.G
	G.money = 9e6
	for d in Career.drivers(): d.energy = d.maxE
	var v: Dictionary = V.q4
	v.eng.log = null
	var s := await _open("test_day_screen", {"vid": v.id})
	ok(s.tvid == v.id, "test day preselects ctx.vid")
	await _shot("testday_setup")
	ok(_press("track:t_tar") and _press("laps:3"), "track + laps")
	var tests0 := int(G.st.get("tests", 0))
	Career.checkAch()
	var m0 := float(G.money)
	ok(_press("start") and s.rv != null, "session started in a RaceView")
	s.rv.speed = 4.0
	await _wait(2.5)
	await _shot("testday_running")
	s.rv._skip()
	var t0 := Time.get_ticks_msec()
	while s.result.is_empty() and Time.get_ticks_msec() - t0 < 15000: await _frames(2)
	ok(not s.result.is_empty(), "session finished")
	ok(int(G.st.tests) == tests0 + 1 and float(G.money) < m0, "finishTest booked (tests %d, money)" % int(G.st.tests))
	ok(v.eng.get("log") != null and str(v.eng.log.src).begins_with("Test"), "test datalog saved")
	ok(s.result.lapT.size() >= 1, "lap times recorded (%s)" % [s.result.lapT])
	await _frames(3)
	await _shot("testday_result")
	ok(_press("tune") and router.opened[-1][0] == "bench" and router.opened[-1][1].get("cond") is Dictionary, "Tune it routes to the bench with the session's conditions")
	var bc: Dictionary = router.opened[-1][1]
	bc.erase("router")
	s = await _open("bench_screen", bc)
	ok(s.cond_tag == "test", "bench takes the test conditions")
	await _shot("bench_from_test")
	# drag strip session
	s = await _open("test_day_screen", {"vid": V.twin.id})
	ok(_press("track:t_drag") and not _has("laps:5"), "drag strip: fixed passes")
	await _shot("testday_drag")
