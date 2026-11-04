extends RefCounted
## Career / story UI suite (part A screens) driven through the real UI:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy -- --test=career_ui_test
## title -> STORY MODE -> Short -> new team -> story intro -> BUILD (answering every build prompt) ->
## ticks until built -> MACHINES / vehicle tabs -> RACES -> prerace -> RaceView at high speed -> results ->
## story scenes; then a heats race, the drag ladder, a hillclimb with a retune between runs, a dynasty
## race (dyn_pos), a series round (race-day window), save / title / CONTINUE. Screenshots: tests/shots/cui_*.png.
## Part-B screens missing from scripts/ui/career/ are served by tests/stubs/career/.

var r
var main
var cs: CareerScreen
var shots := 0
var scenes_seen := 0
var choices := 0
var build_prompts := 0
var events := 0
var finished_infos: Array = []
var headless := false

func ok(c: bool, m: String) -> void: r.ok(c, m)

func run(runner) -> void:
	r = runner
	main = r.main
	headless = DisplayServer.get_name() == "headless"
	CareerScreen.extra_dirs = ["res://tests/stubs/career/"]
	U.seed(5150)
	if FileAccess.file_exists(CareerScreen.SAVE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(CareerScreen.SAVE_PATH))
	Career.race_finished.connect(func(info): finished_infos.append(info))
	var t0 := Time.get_ticks_msec()
	print("- title / story pick / new team"); await t_start()
	print("- build"); await t_build()
	print("- machines"); await t_machines()
	print("- first race"); await t_first_race()
	print("- formats"); await t_formats()
	print("- test session"); await t_test_session()
	print("- dynasty race"); await t_dynasty()
	print("- series round"); await t_series()
	print("- year end"); await t_year_end()
	print("- save / continue"); await t_save_continue()
	print("- ending -> free play"); await t_ending()
	print("- free career"); await t_free_career()
	Engine.time_scale = 1.0
	print("  scenes %d, choices %d, build prompts %d (events %d), shots %d, %.1fs" % [scenes_seen, choices, build_prompts, events, shots, (Time.get_ticks_msec() - t0) / 1000.0])

# ---------------- helpers ----------------
func tree() -> SceneTree: return r.get_tree()

func frames(n := 3) -> void:
	for i in n: await tree().process_frame

func shot(name: String) -> void:
	shots += 1
	# toasts live 2.6 s of real time; the suite runs faster than that, so keep them out of screen shots
	if cs and is_instance_valid(cs) and cs.toast_box and not "home" in name:
		for t in cs.toast_box.get_children(): t.queue_free()
	if headless:
		await frames(2)
		return
	await r.shot("cui_" + name)

## Settings > QUIT TO TITLE (real screen: "quit" then the confirm modal; stub: "stub_quit").
func quit_from_settings() -> void:
	if await press(top(), "stub_quit", false): return
	await press(top(), "quit")
	await frames(2)
	await press(top(), "modal_yes")

func press(root: Node, key: String, must := true) -> bool:
	var b := CareerKit.find_button(root, key)
	if b == null or b.disabled:
		if must: ok(false, "button '%s' %s" % [key, "disabled" if b else "not found"])
		return false
	b.pressed.emit()
	await frames(2)
	return true

func top() -> Control: return cs.top() if cs else null

func dialog() -> Node:
	for host in [cs.story_layer if cs else null, tree().root]:
		if host == null: continue
		var st: Array = [host]
		while not st.is_empty():
			var n: Node = st.pop_back()
			if n is DialogueBox and not n.is_queued_for_deletion() and (n as DialogueBox).is_visible_in_tree(): return n
			st.append_array(n.get_children())
	return null

## Play out any story scene on screen (choices: always the first).
func play_scenes(tag := "") -> void:
	var guard := 0
	var shot_one := tag == ""
	while Story.is_presenting() and guard < 600:
		guard += 1
		var d := dialog()
		if d == null:
			var es := _ending()
			if es:
				var cr = es.credits()
				if cr: cr.skip_to(1.0)
			await frames(2)
			continue
		if not shot_one and not d.typing:
			shot_one = true
			await shot(tag)
		if d.is_waiting_choice():
			choices += 1
			d.pick(0)
		else:
			if d.idx == 0 and not d.typing: scenes_seen += 1
			d.advance()
		await frames(1)
	ok(not Story.is_presenting(), "story scenes played out (%s)" % tag)

func _ending() -> Node:
	for c in cs.story_layer.get_children():
		if c is EndingScene: return c
	return null

## Answer whatever window is up (build prompts: pick an affordable option, sometimes the crew).
func answer_window() -> bool:
	var w: SnesWindow = cs.cur_win
	if w == null or not is_instance_valid(w): return false
	if w.kind.begins_with("build:"):
		build_prompts += 1
		if w.title.begins_with("!"): events += 1
		var n := w.button_count()
		var pick := -1
		for i in n:
			var bd := w.button_def(i)
			if not bool(bd.get("dis", false)) and str(bd.get("tid", "")).begins_with("opt_"):
				pick = i
				if build_prompts % 3 == 0: break      # mix first and last affordable picks
		if build_prompts % 5 == 0 or pick < 0: pick = n - 1   # sometimes let the crew decide
		w.press(pick)
	elif w.kind.begins_with("round:"):
		w.press(0)
	else:
		w.press(maxi(0, w.cancel_index))
	await frames(2)
	return true

func settle(limit := 200) -> void:
	var g := 0
	while g < limit:
		g += 1
		if Story.is_presenting(): await play_scenes()
		elif cs.cur_win != null and is_instance_valid(cs.cur_win): await answer_window()
		else: break
		await frames(1)

func rest() -> void:
	var G := Career.G
	for s in Career.drivers(): s.energy = s.maxE
	G.jobs = G.jobs.filter(func(j): return j.type != "rep")
	for v in G.vehicles:
		if v.status == "repair": v.status = "ready"
		v.hp = 1.0
		if v.get("eng") is Dictionary: v.eng.cond = 1.0
	Career.refresh.emit()

## Watch the current RaceView at high speed until it hands over (stage window or results).
func watch_race(tag: String, shot_mid := true) -> void:
	var rs_scr = top()
	ok(rs_scr is RaceScreen, "race screen open (%s)" % tag)
	if not (rs_scr is RaceScreen): return
	var rsn: RaceScreen = rs_scr
	var rv: RaceView = rsn.rv
	ok(rv != null and rv.sim == (rsn.flow.rs if rsn.flow else rsn.test_rs), "RaceView runs the flow's race (%s)" % tag)
	rv.speed = 4.0
	Engine.time_scale = 4.0
	if shot_mid:
		var t0 := Time.get_ticks_msec()
		while not rv.sim.done and Time.get_ticks_msec() - t0 < 2500: await frames(1)
		await shot(tag)
	var t1 := Time.get_ticks_msec()
	while (rsn.panel_win == null or not is_instance_valid(rsn.panel_win)) and Time.get_ticks_msec() - t1 < 120000:
		if rv.sim.done and Time.get_ticks_msec() - t1 > 60000: break
		await frames(1)
	Engine.time_scale = 1.0
	await frames(3)
	ok(rsn.panel_win != null and is_instance_valid(rsn.panel_win), "stage / results window after %s" % tag)

func race_from_prerace(rid: String, fmt: String, tag: String) -> RaceScreen:
	cs.go_home()
	await settle()
	cs.open("races", {"tier": int(Data.race(rid).tier)})
	await frames(3)
	var pr := cs.open("prerace", {"rid": rid})
	await frames(3)
	if fmt != "": await press(pr, "fmt_" + fmt)
	await frames(2)
	await press(top(), "start")
	await frames(3)
	var rsn = top()
	ok(rsn is RaceScreen, "%s: race started from prerace" % tag)
	return rsn if rsn is RaceScreen else null

# ---------------- title -> new story career ----------------
func t_start() -> void:
	main.title_screen()
	await frames(30)
	await shot("01_title")
	ok(CareerKit.find_button(main, "story") != null and CareerKit.find_button(main, "free") != null, "title has STORY MODE and FREE CAREER")
	ok(CareerKit.find_button(main, "continue") == null, "no CONTINUE without a save")
	for t in ["quick race", "co-op lan", "versus lan", "garage", "profile"]:
		ok(CareerKit.find_button(main, t) != null, "title keeps " + t)
	await press(main, "story")
	await frames(5)
	await shot("02_campaign_picker")
	await press(main, "short")
	await frames(3)
	await shot("03_new_team")
	await press(main, "mode_easy")
	await press(main, "mode_standard")
	await press(main, "start")
	await frames(4)
	cs = main.career
	ok(cs != null and cs.is_inside_tree(), "career screen open")
	ok(Story.has_campaign() and Story.length() == "short", "short campaign started")
	ok(Career.G.team.name == Game.player.team, "team name from the profile")
	ok(FileAccess.file_exists(CareerScreen.SAVE_PATH), "new career saved")
	await frames(10)
	ok(Story.is_presenting(), "story intro presented on entering home")
	await play_scenes("04_story_intro")
	await settle()
	await frames(10)
	await shot("05_home")
	ok(cs.gv.state.get("crew", []).size() == Career.G.staff.size(), "garage crew from staff")
	ok(str(cs.gv.state.get("team_col", "")) == str(Career.G.team.color), "garage team colour")
	# real-time clock: 1 day per second at 1x, nothing while paused
	var d0 := int(Career.G.day)
	await press(cs, "speed_0")
	await r._secs(1.3)
	ok(int(Career.G.day) == d0, "paused: no days pass")
	await press(cs, "speed_1")
	await r._secs(1.25)
	ok(int(Career.G.day) == d0 + 1, "1x: one day per second (%d -> %d)" % [d0, int(Career.G.day)])
	await press(cs, "speed_2")
	ok(cs.speed() == 2, "fast = 2x")
	await press(cs, "speed_2")
	ok(cs.speed() == 4, "fast again = 4x")
	await press(cs, "speed_1")

# ---------------- build ----------------
func t_build() -> void:
	await press(cs, "menu_build")
	await frames(3)
	await shot("06_build_bodies")
	await press(top(), "tab_bike")
	await frames(2)
	await shot("06b_build_bikes")
	await press(top(), "tab_car")
	await press(top(), "body_kei")
	await frames(2)
	await shot("07_build_layout")
	await press(top(), "layout_ff")
	await frames(2)
	await shot("08_build_fuel")
	await press(top(), "sys_d2")
	await frames(3)
	await shot("09_build_confirm")
	var money0 := float(Career.G.money)
	await press(top(), "do_build")
	await frames(4)
	ok(Career.G.vehicles.size() == 1 and Career.G.vehicles[0].status == "build", "build started")
	ok(float(Career.G.money) < money0, "build paid")
	ok(cs.stack.is_empty(), "back home after BUILD")
	ok(cs.cur_win != null and cs.cur_win.kind.begins_with("build:"), "first build decision asked right away")
	await shot("10_build_ask")
	var vid = Career.G.vehicles[0].id
	var days := 0
	var shot_event := false
	var shot_sheet := false
	var shot_garage := false
	while Career.veh(vid).status == "build" and days < 400:
		if Story.is_presenting(): await play_scenes()
		elif cs.cur_win != null and is_instance_valid(cs.cur_win):
			if not shot_event and cs.cur_win.title.begins_with("!"):
				shot_event = true
				await shot("11_build_event")
			await answer_window()
		else:
			var j := Career.bJob(vid)
			if not shot_sheet and int(j.get("pi", 0)) >= 3:
				shot_sheet = true
				cs.open("vehicle", {"vid": vid})
				await frames(3)
				await shot("12_build_sheet")
				cs.back()
				await frames(2)
			if not shot_garage and int(j.get("pi", 0)) >= 5:
				shot_garage = true
				await frames(20)
				await shot("13_home_building")
			days += cs.run_days(1)
			await frames(1)
	ok(Career.veh(vid).status == "ready", "machine built in %d days" % days)
	ok(build_prompts >= 8, "answered %d build prompts through windows" % build_prompts)
	await settle()
	await frames(20)
	await shot("14_home_built")
	ok(cs.gv.bays.size() == 1 and str(cs.gv.bays[0].status) == "ready", "garage shows the finished machine")

# ---------------- machines ----------------
func t_machines() -> void:
	var vid = Career.G.vehicles[0].id
	Career.G.money = float(Career.G.money) + 300000
	await press(cs, "menu_machines")
	await frames(3)
	await shot("15_machines")
	await press(top(), "veh_%d" % int(vid))
	await frames(6)
	await shot("16_vehicle_info")
	await press(top(), "tab_upgrade")
	await shot("17_vehicle_upgrade")
	await press(top(), "tab_parts")
	await shot("18_vehicle_parts")
	await press(top(), "tab_engine")
	await shot("19_vehicle_engine")
	await press(top(), "bench_carb")
	await frames(2)
	ok(top() != null and str(top().get_meta("screen", "")) == "bench" and str(top().ctx.get("tab")) == "carb", "engine tab opens the bench (carb)")
	top().closed.emit()   # real or stub bench: BACK = closed
	await frames(3)
	ok(top() is VehicleScreen, "back to the machine")
	await press(top(), "tab_upgrade")
	await press(top(), "up_spd")
	ok(Career.veh(vid).status == "upgrade", "upgrade started from the UI")
	await press(top(), "tab_info")
	await press(top(), "sell")
	ok(cs.cur_win != null and cs.cur_win.kind == "", "sell asks first")
	await shot("20_confirm_sell")
	cs.cur_win.press(0)
	await frames(2)
	ok(not Career.veh(vid).is_empty(), "cancel keeps the machine")
	cs.go_home()
	await frames(2)
	var n := 0
	while Career.veh(vid).status != "ready" and n < 40:
		n += cs.run_days(1)
		await settle()
	ok(Career.veh(vid).status == "ready", "upgrade done")

# ---------------- first race ----------------
func t_first_race() -> void:
	rest()
	var tb := Time.get_ticks_usec()
	var rsc := cs.open("races")
	var built_ms := (Time.get_ticks_usec() - tb) / 1000.0
	print("  RACES screen built in %.1f ms" % built_ms)
	ok(built_ms < 400.0, "races list builds fast enough for a phone (%.0f ms)" % built_ms)
	cs.back()
	await frames(2)
	await press(cs, "menu_races")
	await frames(3)
	await shot("21_races")
	await press(top(), "tab_series")
	await shot("22_series")
	await press(top(), "tab_races")
	tb = Time.get_ticks_usec()
	await press(top(), "race_c1a")
	print("  prerace opened in %.1f ms (incl. 2 frames)" % ((Time.get_ticks_usec() - tb) / 1000.0))
	await frames(3)
	await shot("23_prerace")
	var pr = top()
	ok(pr is PreraceScreen, "prerace open")
	pr.scroll.scroll_vertical = 9999
	await frames(3)
	await shot("24_prerace_bottom")
	var n0 := finished_infos.size()
	await press(pr, "start")
	await frames(3)
	ok(cs.racing, "router knows a race is on")
	await watch_race("25_race")
	await shot("26_results")
	ok(finished_infos.size() == n0 + 1, "race scored once")
	ok(int(Career.G.st.races) >= 1, "career race counted")
	await press(top(), "continue")
	await frames(4)
	ok(not cs.racing and cs.stack.is_empty(), "home after results")
	await settle()
	await frames(10)
	await shot("27_home_after_race")
	ok(Story.objectives().size() > 0 and bool(Story.objectives()[0].done), "story objective 'build' complete")
	cs.story_hud.tapped.emit()
	await frames(3)
	ok(cs.cur_win != null and cs.cur_win.kind == "", "tapping the story strip lists the objectives")
	await shot("27b_objectives")
	await answer_window()

# ---------------- formats ----------------
func t_formats() -> void:
	var G := Career.G
	G.money = float(G.money) + 500000
	G.st.wins = maxi(2, int(G.st.wins))     # unlock the Open tier-1 races
	# heats + main
	rest()
	var rs := await race_from_prerace("p1a", "heats", "heats")
	if rs:
		await watch_race("28_heat_race", true)
		await shot("29_heat_panel")
		ok(rs.flow.stage == "heat", "heats: heat first")
		if not rs.flow.panel.get("dead", false):
			await press(rs, "next")
			ok(rs.flow.stage == "main", "heats: main next")
			await watch_race("30_main_race", true)
		else:
			await press(rs, "results")
		await shot("31_heats_results")
		await press(top(), "continue")
		await settle()
	# drag ladder
	rest()
	rs = await race_from_prerace("r1a", "elim", "drag")
	if rs:
		var rounds := 0
		while rs.flow and not rs.flow.done and rounds < 4:
			await watch_race("32_drag_round%d" % rounds, rounds == 0)
			rounds += 1
			if rounds == 1: await shot("33_drag_panel")
			if rs.flow.panel.get("can_next", false): await press(rs, "next")
			else:
				await press(rs, "results")
				break
		ok(rs.flow.done and rs.flow.rs.order_override.size() == 8, "drag ladder finished (%d rounds)" % rounds)
		await shot("34_drag_results")
		await press(top(), "continue")
		await settle()
	# hillclimb best of 2 with a retune between runs
	rest()
	rs = await race_from_prerace("h1a", "best2", "hill")
	if rs:
		await watch_race("35_hill_run1", true)
		await shot("36_hill_panel")
		ok(rs.flow.stage == "hill" and rs.flow.run == 1, "hill run 1")
		if rs.flow.panel.get("can_next", false):
			await press(rs, "retune")
			await frames(3)
			ok(str(top().get_meta("screen", "")) == "bench", "retune opens the bench between runs")
			await shot("37_hill_retune")
			var tuned: bool = await press(top(), "stub_tune", false)
			if not tuned and Career.has_method("adjJet"): Career.adjJet(rs.flow.vid, "main", 1)
			top().closed.emit()
			await frames(3)
			ok(top() == rs and rs.panel_win != null and is_instance_valid(rs.panel_win), "back at the hill panel after retune")
			await press(rs, "next")
			ok(rs.flow.run == 2, "hill run 2")
			await watch_race("38_hill_run2", false)
			await press(rs, "results")
		else:
			await press(rs, "results")
		ok(rs.flow.done and rs.flow.rs.order_override.size() == rs.flow.rivals.size() + 1, "hill best-of-2 scored")
		await shot("39_hill_results")
		await press(top(), "continue")
		await settle()

# ---------------- test session through the race screen ----------------
func t_test_session() -> void:
	cs.go_home()
	await settle()
	rest()
	var v: Dictionary = Career.G.vehicles[0]
	var tests0 := int(Career.G.st.get("tests", 0))
	cs.open("machines")
	await frames(2)
	var td := cs.open("test_day", {"vid": v.id})        # part-B screen (stub here) hands off to "race"
	await frames(2)
	cs.open("race", {"test": "t_tar", "vid": v.id, "drv": Career.drivers()[0].id, "laps": 3})
	await frames(3)
	await watch_race("race_test", false)
	await shot("39b_test_results")
	ok(int(Career.G.st.tests) == tests0 + 1, "test session scored (finishTest)")
	await press(top(), "continue")
	await frames(3)
	ok(top() == td and not cs.racing, "DONE returns to the screen that opened the test")
	cs.go_home()
	await settle()

# ---------------- dynasty ----------------
func t_dynasty() -> void:
	var G := Career.G
	var rid := ""
	for x in ["c1c", "o1c", "b1c", "d1c"]:
		if not Story.rival_for(x).is_empty() and Data.race(x).cls in ["car", "any"]:
			rid = x
			break
	ok(rid != "", "a chapter-1 race has Crownwell on the grid")
	if rid == "": return
	var prev: String = rid.substr(0, rid.length() - 1) + "b"
	if not G.races.has(prev): G.races[prev] = {"best": 2, "n": 1, "w": 0}
	G.races[prev].best = mini(int(G.races[prev].best), 2)
	rest()
	var n0 := finished_infos.size()
	var rs := await race_from_prerace(rid, "", "dynasty")
	if rs == null: return
	ok(rs.flow.rs.ents.any(func(e): return e.get("ref", {}).get("dynasty", false)), "dynasty entry on the grid")
	await watch_race("40_dynasty_race", true)
	var guard := 0
	while not rs.flow.done and guard < 6:
		guard += 1
		if rs.flow.panel.get("can_next", false): await press(rs, "next")
		else: await press(rs, "results")
		if not rs.flow.done: await watch_race("dyn_stage", false)
	await shot("41_dynasty_results")
	ok(finished_infos.size() > n0 and finished_infos.back().has("dyn_pos"), "race_finished carries dyn_pos %s" % str(finished_infos.back() if finished_infos.size() else {}))
	await press(top(), "continue")
	await settle()

# ---------------- series ----------------
func t_series() -> void:
	var G := Career.G
	G.money = float(G.money) + 200000
	for x in ["c1a", "c1b"]:
		G.races[x] = {"best": 1, "n": 1, "w": 1}
	var sid := "s1c"
	ok(Career.seriesState(sid).ok, "series unlocked: %s" % str(Career.seriesState(sid)))
	cs.go_home()
	await settle()
	cs.open("races", {"tab": "series", "tier": 1})
	await frames(3)
	await press(top(), "enter_" + sid)
	await shot("42_series_confirm")
	await press(cs.cur_win, "yes")
	ok(G.series.get(sid, {}).get("act") != null, "entered the series")
	await shot("43_series_card")
	cs.go_home()
	await frames(2)
	var n := 0
	while cs.cur_win == null and n < 30:
		n += cs.run_days(1)
		if Story.is_presenting(): await play_scenes()
		if cs.cur_win != null and not cs.cur_win.kind.begins_with("round:"): await answer_window()
		await frames(1)
	ok(cs.cur_win != null and cs.cur_win.kind == "round:" + sid, "race-day window")
	await shot("44_race_day")
	ok(cs.paused(), "time stops on race day")
	await press(cs.cur_win, "go")
	await frames(3)
	ok(top() is PreraceScreen and top().sid == sid, "race day opens the series prerace")
	await shot("45_series_prerace")
	await press(top(), "back")
	ok(cs.cur_win != null, "leaving a series round asks to skip")
	await press(cs.cur_win, "yes")
	await frames(3)
	ok(int(G.series[sid].act.round) == 1, "round skipped")

# ---------------- save / continue ----------------
func t_save_continue() -> void:
	cs.go_home()
	await settle()
	ok(CareerScreen.save_game(), "saved")
	var saved := Career.serialize()
	await press(cs, "menu_settings")
	await quit_from_settings()
	await frames(5)
	ok(main.career == null, "quit to title")
	await frames(20)
	await shot("46_title_continue")
	ok(CareerKit.find_button(main, "continue") != null, "CONTINUE on the title")
	Career.newGame("Scratch", "#2f7de8")      # prove CONTINUE really loads from disk
	await press(main, "continue")
	await frames(5)
	cs = main.career
	ok(cs != null, "career screen after CONTINUE")
	ok(Career.serialize() == saved, "CONTINUE restored the exact save")
	ok(Story.has_campaign() and Story.length() == "short", "story state survived the save")
	await settle()
	await frames(10)
	await shot("47_continued_home")

# ---------------- year end ----------------
func t_year_end() -> void:
	cs.go_home()
	await settle()
	var G := Career.G
	for id in G.series:
		if G.series[id].get("act") is Dictionary: G.series[id].act.next = Career.DAYS_YEAR + 40    # keep race days out of the way
	G.day = Career.DAYS_YEAR - 1
	ok(cs.run_days(1) == 1, "ticked into the new year")
	await frames(3)
	var seen := false
	var g := 0
	while g < 10:
		g += 1
		if Story.is_presenting(): await play_scenes()
		elif cs.cur_win != null and is_instance_valid(cs.cur_win):
			if cs.cur_win.title.begins_with("YEAR"):
				seen = true
				await shot("48_year_report")
			await answer_window()
		else: break
		await frames(2)
	ok(seen, "year report window")
	ok(Career.year() == 2, "year 2")

# ---------------- ending -> credits -> free play ----------------
func t_ending() -> void:
	cs.go_home()
	await settle()
	Story._finish()          # jump to the end of the campaign (the chapters themselves are story_test's job)
	await frames(4)
	ok(Story.is_presenting() and _ending() != null, "ending scene presented at home")
	await frames(30)
	await shot("50_ending")
	var g := 0
	var shot_credits := false
	while Story.is_presenting() and g < 900:
		g += 1
		var es := _ending()
		var d := dialog()
		if d != null:
			if d.is_waiting_choice(): d.pick(0)
			else: d.advance()
		elif es and es.credits():
			if not shot_credits:
				shot_credits = true
				es.credits().skip_to(0.12)
				await frames(4)
				await shot("51_credits")
			es.credits().skip_to(1.0)
		await frames(1)
	ok(not Story.is_presenting(), "ending + credits finished")
	ok(Story.in_free_play(), "story in free play after the ending")
	await frames(3)
	ok(cs.cur_win != null and cs.cur_win.title == "FREE PLAY", "free-play window after the credits")
	await shot("52_free_play")
	await settle()
	ok(not cs.paused() or cs.speed() == 0, "career runs on after the ending")

# ---------------- free career ----------------
func t_free_career() -> void:
	await press(cs, "menu_settings")
	await quit_from_settings()
	await frames(5)
	await press(main, "free")
	await frames(3)
	await shot("53_new_free")
	await press(main, "start")
	await frames(6)
	cs = main.career
	ok(cs != null and not Story.has_campaign(), "free career without a campaign")
	ok(not cs.story_hud.visible, "no story strip in a free career")
	await settle()
	await frames(10)
	await shot("54_free_home")
