extends RefCounted
## Story mode suite:  godot --path godot -- --test=story_test
## Screenshots need a renderer:  xvfb-run -a godot --path godot --rendering-driver opengl3 --audio-driver Dummy -- --test=story_test
##  - bakes the portraits to art/portraits/*.png (+ tests/shots/story_portraits.png contact sheet)
##  - validates the story data against the game tables
##  - drives Short to the ending through a stub Career (signals + G), checking transitions, rewards,
##    persistence round-trips and the dynasty hook; drives Medium and Long through their extra chapters
##  - plays every queued scene through Story.present() (dialogue, choices, ending, credits)
##  - screenshots the dialogue box, HUD, picker, ending and credits

var r
var stub
var toasts: Array = []
var changed: Array = []
var finished_n := 0
var checks := 0

func ok(cond: bool, what: String) -> void:
	checks += 1
	r.ok(cond, what)

## Stand-in for the Career autoload (scripts/career/career.gd, ported in parallel): G + the story signals.
class CareerStub extends Node:
	signal race_finished(info)
	signal title_won(series_id)
	signal workshop_up(level)
	signal research_done(tech_id)
	signal vehicle_built(vid)
	signal staff_hired(sid)
	signal sponsor_signed(id)
	signal day_passed(day)
	signal toast(text)
	signal popup(data)
	signal refresh()
	var G: Dictionary = {}

func run(runner) -> void:
	r = runner
	var tree: SceneTree = r.get_tree()
	t_bake()
	t_data()
	stub = tree.root.get_node_or_null("Career")
	if stub == null:
		stub = CareerStub.new()
		stub.name = "Career"
		tree.root.add_child(stub)
	await tree.process_frame
	await tree.process_frame
	ok(Story.career == stub, "Story attached to /root/Career by itself")
	Story.attach(stub)
	stub.toast.connect(func(t): toasts.append(t))
	Story.chapter_changed.connect(func(n): changed.append(n))
	Story.story_finished.connect(func(): finished_n += 1)
	t_no_career()
	await t_short()
	t_long_lengths()
	await t_present()
	if DisplayServer.get_name() != "headless":
		await t_shots()
	else:
		print("  (headless: skipping screenshots)")
	print("  story checks: %d" % checks)

# ---------------- portraits ----------------
func t_bake() -> void:
	var dir := ProjectSettings.globalize_path(Portraits.DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var ids: Array = Portraits.CAST.keys()
	var sheet := Image.create(48 * 3, 48 * ids.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#24305e"))
	var n := 0
	var t0 := Time.get_ticks_msec()
	for row in ids.size():
		var id: String = ids[row]
		var ex: Array = Portraits.CAST[id]
		ok(ex.size() >= 3, "%s has 3 expressions" % id)
		for c in ex.size():
			var img := Portraits.bake(id, ex[c])
			ok(img.get_width() == 48 and img.get_height() == 48, "%s_%s is 48x48" % [id, ex[c]])
			var solid := 0
			for y in 48:
				for x in 48:
					if img.get_pixel(x, y).a > 0.5: solid += 1
			ok(solid > 48 * 48 * 0.35, "%s_%s has a bust (%d px)" % [id, ex[c], solid])
			img.save_png(dir.path_join("%s_%s.png" % [id, ex[c]]))
			sheet.blend_rect(img, Rect2i(0, 0, 48, 48), Vector2i(c * 48, row * 48))
			n += 1
	Portraits.clear_cache()
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png(r.shots_dir.path_join("story_portraits.png"))
	print("  baked %d portraits in %d ms -> %s" % [n, Time.get_ticks_msec() - t0, dir])
	ok(n == 27, "27 portraits baked (%d)" % n)

# ---------------- data ----------------
func t_data() -> void:
	var bad: Array = Story.validate()
	for b in bad: print("  data: ", b)
	ok(bad.is_empty(), "story data validates (%d problems)" % bad.size())
	ok(Story.chars.size() >= 8, "cast loaded")
	var L: Dictionary = Story.lengths
	ok((L.short.chapters as Array).size() == 5, "Short has 5 chapters")
	ok((L.medium.chapters as Array).size() == 8, "Medium has 8 chapters")
	ok((L.long.chapters as Array).size() == 12, "Long has 12 chapters")
	for id in ["mud", "drag", "hill"]: ok(id in L.medium.chapters and id in L.long.chapters, "Medium and Long include " + id)
	for id in ["rain", "titles", "world", "legend"]: ok(id in L.long.chapters and not id in L.medium.chapters, "Long-only chapter " + id)
	for len_id in L:
		var spine: Array = (L[len_id].chapters as Array).filter(func(c): return not bool(Story.chapters[c].get("side", false)))
		ok(spine == ["ch1", "ch2", "ch3", "ch4", "fin"], "%s keeps the core spine %s" % [len_id, spine])
		ok(str(L[len_id].chapters[-1]) == "fin", "%s ends with the finale" % len_id)
	var fin_s := Story.chapter_for("fin", "short")
	var fin_l := Story.chapter_for("fin", "long")
	ok(fin_s.obj[1].race != fin_l.obj[1].race and "l5x2" in fin_l.obj[1].race, "finale race differs by length (Long: Ultimate Crown)")
	ok(Story.chapter_for("ch4", "short").obj[0].t == "win" and Story.chapter_for("ch4", "long").obj[0].t == "title", "ch4 objectives scale with length")

# ---------------- stub career ----------------
func new_game() -> Dictionary:
	var g := {"v": 1, "team": {"name": "Tinplate Garage", "color": "#2f7de8"}, "day": 0, "money": 420000, "rp": 40, "fans": 0, "ws": 1,
		"staff": [{"id": 1, "role": "drv", "name": "Ace Gasket", "pedal": 30, "shift": 30, "steer": 30},
			{"id": 2, "role": "mec", "name": "Bo Bolt", "tech": 30}, {"id": 3, "role": "mec", "name": "Cy Cog", "tech": 20}],
		"vehicles": [], "jobs": [], "res": {"body": {}, "layout": {}, "part": {}}, "unl": {"body": {}, "layout": {}, "part": {}, "train": {}, "fac": {}},
		"partLv": {}, "races": {}, "series": {}, "spons": [], "sponDone": {}, "fac": [], "sparks": {"b": 1, "s": 0, "g": 0},
		"st": {"races": 0, "wins": 0, "podiums": 0, "dnf": 0, "titles": [], "earn": 0, "wc": {}}, "nid": 4, "tech": {"carbbasic": 1}, "ach": {}}
	stub.set("G", g)
	return g

func G() -> Dictionary: return stub.get("G")

var _vid := 100
func add_vehicle(body: String, efi := false, lv := 1) -> int:
	_vid += 1
	var b: Dictionary = Data.body(body)
	G().vehicles.append({"id": _vid, "body": body, "layout": "ff" if b.cls == "car" else "single", "name": "%s #%d" % [b.n, _vid],
		"status": "ready", "lv": lv, "eng": {"fuel": "efi" if efi else "carb", "cond": 1.0}})
	stub.vehicle_built.emit(_vid)
	return _vid

## Finish a race the way the engine bookkeeps it (st counters, wc keys, best), then emit race_finished.
func race(rid: String, pos: int, extra: Dictionary = {}) -> void:
	var g := G()
	var def: Dictionary = Data.race(rid)
	g.st.races += 1
	if pos == 1:
		g.st.wins += 1
		for k in ["w:disc:" + def.disc, "w:tier:%d" % int(def.tier)]: g.st.wc[k] = int(g.st.wc.get(k, 0)) + 1
		var tk := {}
		for s in def.surf: tk[Data.D.SURF[s].k] = int(tk.get(Data.D.SURF[s].k, 0)) + int(def.surf[s])
		for k in tk:
			if tk[k] >= 40: g.st.wc["w:terr:" + k] = int(g.st.wc.get("w:terr:" + k, 0)) + 1
	if pos <= 3: g.st.podiums += 1
	var rr: Dictionary = g.races.get(rid, {"best": 99, "n": 0, "w": 0})
	rr.best = mini(int(rr.best), pos)
	rr.n = int(rr.n) + 1
	g.races[rid] = rr
	var info := {"race_id": rid, "fmt_id": "sprint", "pos": pos, "field": 8, "dnf": false, "prize": 0, "series_id": ""}
	info.merge(extra, true)
	stub.race_finished.emit(info)

func title(sid: String) -> void:
	G().st.titles.append(sid)
	stub.title_won.emit(sid)

func tech(id: String) -> void:
	G().tech[id] = 1
	stub.research_done.emit(id)

func workshop(lv: int) -> void:
	G().ws = lv
	stub.workshop_up.emit(lv)

func day() -> void:
	G().day = int(G().day) + 1
	stub.day_passed.emit(G().day)

func n_ch() -> int: return int(Story.current_chapter().get("n", 0))

# ---------------- Story without a career ----------------
func t_no_career() -> void:
	Story.detach()
	ok(Story.start_campaign("short", {"crew": false}), "campaign starts without Career (local state)")
	ok(Story.current_chapter().n == 1 and Story.pending_scene() == "c1_intro", "local campaign at chapter 1")
	ok(Story.objective_text() == "Build your first machine", "first objective text: " + Story.objective_text())
	Story.abandon()
	Story.attach(stub)

# ---------------- Short, start to finish ----------------
func t_short() -> void:
	var g := new_game()
	changed.clear()
	finished_n = 0
	ok(not Story.has_campaign(), "fresh save has no campaign")
	ok(Story.start_campaign("short"), "start Short")
	ok(g.has("story") and g.story.len == "short", "state lives in Career.G.story")
	ok(g.staff[0].name == "Rosie Alvarez" and g.staff[1].name == "Dewey Brandt" and g.staff[2].name == "Cy Cog", "crew named after the story cast")
	ok(changed == [1], "chapter_changed(1)")
	ok(Story.pending_scene() == "c1_intro", "intro queued")
	var sc := Story.scene("c1_intro")
	ok(sc.card.top == "CHAPTER 1" and sc.card.title == "Rust and Elbow Grease", "chapter card")
	ok(sc.lines[1].name == "Walt" and sc.lines[1].expr == "happy", "speaker resolved")
	ok(Story.progress().chapters == 5 and Story.progress().chapter == 1, "progress()")
	# --- chapter 1
	var money0 := float(g.money)
	add_vehicle("kei")
	ok(Story.objectives()[0].done, "built first machine")
	ok("c1_built" in Story.pending_scenes(), "build beat queued")
	ok(Story.objective_text() == "Win a Rookie race", "next objective: " + Story.objective_text())
	ok(not Story.rival_for("c1c").is_empty() and Story.rival_for("c1c").drv == "Preston Crownwell", "Preston on the c1c grid")
	ok(Story.rival_for("c1a").is_empty(), "no Crownwell at c1a")
	race("c1a", 1)
	ok("c1_first_race" in Story.pending_scenes() and "c1_first_win" in Story.pending_scenes(), "first race + first win beats")
	ok(toasts.size() > 0 and str(toasts[-1]).begins_with("WTPL 1340:"), "radio toast: %s" % [toasts.back() if toasts.size() else ""])
	title("s1c")
	ok("c1_title" in Story.pending_scenes(), "title beat")
	ok(n_ch() == 1, "still chapter 1 until the move")
	workshop(2)
	ok(n_ch() == 2 and changed == [1, 2], "chapter 2 after moving to the Town Garage")
	ok(float(g.money) - money0 == 200000.0, "ch1 money reward (%s)" % (float(g.money) - money0))
	ok(int(g.rp) == 70 and int(g.sparks.b) == 2 and int(g.fans) == 100 and g.tech.has("syncgauge"), "ch1 rp/spark/fans/tech reward")
	var q := Story.pending_scenes()
	ok(q.find("c1_outro") >= 0 and q.find("c1_outro") < q.find("c2_intro"), "outro before next intro: %s" % [q])
	var outro := Story.scene("c1_outro")
	ok(bool(outro.lines[-1].get("note", false)) and str(outro.lines[-1].text).begins_with("Chapter 1 complete!"), "reward note on the outro")
	# --- persistence round trip in the middle of the campaign
	tech("wideband")
	var before := {"ch": Story.current_chapter(), "obj": Story.objectives(), "q": Story.pending_scenes(), "txt": Story.objective_text()}
	stub.set("G", JSON.parse_string(JSON.stringify(G())))
	g = G()
	stub.refresh.emit()
	ok(Story.current_chapter() == before.ch, "chapter survives JSON round trip")
	ok(Story.pending_scenes() == before.q, "scene queue survives JSON round trip")
	ok(str(Story.objectives()) == str(before.obj) and Story.objective_text() == before.txt, "objectives survive JSON round trip")
	# --- chapter 2
	race("c2a", 1)
	race("c2b", 2)
	ok("c2_rosie_offer" in Story.pending_scenes(), "Rosie's offer on the 2nd race of ch2")
	race("c2c", 3)
	ok(Story.objectives()[1].done, "podium at a National headliner")
	title("s2c")
	workshop(3)
	ok(n_ch() == 3, "chapter 3")
	ok(int(g.sparks.s) == 1, "silver spark from ch2")
	# --- chapter 3
	race("c3a", 4)
	ok("c3_silas" in Story.pending_scenes(), "Silas introduced")
	ok(Story.rival_for("c3c").drv == "Silas Vane", "Silas on the c3c grid")
	tech("efi")
	ok("c3_efi" in Story.pending_scenes(), "EFI research beat")
	add_vehicle("gt", true)
	ok("c3_efi_build" in Story.pending_scenes(), "EFI machine beat")
	title("s3c")
	workshop(4)
	ok(n_ch() == 4 and Story.current_chapter().title == "World Stage", "chapter 4")
	# --- chapter 4 (Short: a World race win + 6,000 fans)
	race("c4a", 1)
	ok(Story.objectives()[0].done and n_ch() == 4, "World race won, fans pending")
	g.fans = 7000
	day()
	ok(n_ch() == 5 and Story.current_chapter().finale, "finale reached")
	ok(Story.scene("fin_intro").card.top == "FINALE", "finale card")
	# --- finale
	ok(Story.objective_text().begins_with("Raise a machine to Lv 5"), "finale objective: " + Story.objective_text())
	g.vehicles[0].lv = 5
	day()
	var dyn := Story.rival_for("c4c")
	ok(dyn.get("dynasty", false) and dyn.drv == "Silas Vane" and dyn.team == "Crownwell Racing" and float(dyn.f) > 1.1, "dynasty entry for the Cup: %s" % [dyn])
	ok(dyn.has("kind") and dyn.kind in Data.D.KINDS.CR, "dynasty kind fits the race")
	ok("c4c" in Story.dynasty_races() and "h4c" in Story.dynasty_races(), "dynasty_races() lists the Cup races")
	race("c4c", 2, {"dyn_pos": 1})
	ok("fin_lost" in Story.pending_scenes() and not Story.is_finished(), "losing to Silas: not over yet")
	var m0 := float(g.money)
	race("c4c", 3, {"dyn_pos": 5})
	ok(Story.is_finished() and finished_n == 1, "beating Crownwell (P3 vs their P5) ends the story")
	ok(float(g.money) - m0 == 10000000.0 and g.unl.body.has("comet") and g.unl.body.has("arrow"), "finale reward")
	ok(Story.pending_scenes().slice(-2) == ["fin_outro", "ending"], "fin_outro then ending queued")
	ok(changed == [1, 2, 3, 4, 5], "chapter_changed 1..5 (%s)" % [changed])
	ok(Story.progress().campaign == 1.0, "campaign progress 100%")
	var done_txt := JSON.stringify(G())
	stub.set("G", JSON.parse_string(done_txt))
	ok(Story.is_finished() and Story.pending_scene() != "", "finished state survives save/load")

# ---------------- Medium / Long through their extra chapters ----------------
func t_long_lengths() -> void:
	for len_id in ["medium", "long"]:
		var g := new_game()
		var m0 := float(g.money)
		changed.clear()
		finished_n = 0
		Story.start_campaign(len_id)
		g.spons.append({"id": "cornoil", "ad": 1})
		stub.sponsor_signed.emit("cornoil")
		ok("g_cornoil" in Story.pending_scenes(), "%s: Barb welcomes the Corn Belt deal" % len_id)
		var ids: Array = Story.lengths[len_id].chapters
		var expect := 0.0
		for i in ids.size():
			var ch := Story.current_chapter()
			ok(ch.n == i + 1 and ch.id == ids[i], "%s: chapter %d is %s (%s)" % [len_id, i + 1, ids[i], ch.get("id")])
			var cd := Story.chapter_def()
			expect += float(cd.get("reward", {}).get("money", 0))
			if str(cd.get("intro", "")) == "drag_intro": expect += 100000.0
			for k in (cd.obj as Array).size():
				if Story.current_chapter().n != i + 1 or Story.is_finished(): break
				if not Story.objectives()[k].done: satisfy(cd.obj[k])
			ok(Story.current_chapter().n == i + 2 or Story.is_finished(), "%s: %s completes" % [len_id, ids[i]])
			if Story.is_finished(): break
		ok(Story.is_finished() and finished_n == 1, "%s reaches the ending" % len_id)
		ok(changed.size() == ids.size(), "%s: %d chapter changes" % [len_id, changed.size()])
		ok(absf(float(g.money) - m0 - expect) < 1.0, "%s: money rewards add up (%s vs %s)" % [len_id, float(g.money) - m0, expect])
		ok(g.staff.any(func(s): return s.name == "Midge Ostrowski"), "%s: Midge defects and joins" % len_id)
		ok(not g.spons.any(func(s): return s.id == "cornoil"), "%s: Corn Belt contract voided" % len_id)
		ok(Story.flag("midge_joined") and Story.scene("fin_intro").lines.any(func(l): return l.who == "midge"), "%s: Midge in the finale" % len_id)
		if len_id == "long": ok(g.unl.train.has("rainschool") and g.unl.body.has("sidecar"), "long: side-arc unlocks granted")

## Make G satisfy one objective, emitting the signal the real engine would.
func satisfy(o: Dictionary) -> void:
	var g := G()
	var n := int(o.get("n", 1))
	match str(o.t):
		"build":
			for i in n: add_vehicle(_body_for(o), bool(o.get("efi", false)))
		"veh_lv":
			if g.vehicles.is_empty(): add_vehicle("kei")
			g.vehicles[0].lv = int(o.lv)
			day()
		"race_top": race(o.race[0], 1)
		"win", "podium", "race_n":
			for i in n: race(_race_for(o), 1)
		"beat_dynasty": race(o.race[0], 1, {"dyn_pos": 2})
		"title":
			for i in n: title(_series_for(o))
		"workshop": workshop(int(o.lv))
		"tech":
			for id in o.id: tech(id)
		"sponsor":
			g.spons.append({"id": "hotdog", "ad": 1})
			stub.sponsor_signed.emit("hotdog")
		"fans":
			g.fans = int(o.n)
			day()
		"wc":
			var rid := "b2c" if o.key == "w:terr:wet" else "c1a"
			race(rid, 1)
		_:
			ok(false, "test can't satisfy objective type %s" % o.t)

func _body_for(o: Dictionary) -> String:
	for b in Data.D.BODIES:
		if o.has("disc") and not (b.kind in Data.D.KINDS[o.disc] and (Data.D.DISC[o.disc].cls == "any" or b.cls == Data.D.DISC[o.disc].cls)): continue
		if o.has("cls") and b.cls != o.cls: continue
		return b.id
	return "kei"

func _race_for(o: Dictionary) -> String:
	for d in Data.D.RACES:
		if Story._race_match(o, d, {}): return d.id
	ok(false, "no race matches %s" % [o])
	return "c1a"

func _series_for(o: Dictionary) -> String:
	for s in Data.D.SERIES:
		if o.has("series") and not s.id in o.series: continue
		if o.has("tier") and int(s.tier) != int(o.tier): continue
		if o.has("cls") and s.cls != o.cls: continue
		if o.has("disc") and s.disc != o.disc: continue
		return s.id
	ok(false, "no series matches %s" % [o])
	return "s1c"

# ---------------- presenting the queue (UI flow) ----------------
func t_present() -> void:
	var tree: SceneTree = r.get_tree()
	new_game()
	Story.start_campaign("short")
	# fast-forward to the end with the scenes still queued, then play them all
	var g := G()
	add_vehicle("kei")
	race("c1a", 1)
	var fans0 := int(g.fans)
	var box = Story.present()
	ok(box is DialogueBox, "present() shows a DialogueBox on the overlay")
	var steps := await _drive(5000)
	ok(Story.pending_scene() == "" and not Story.is_presenting(), "all queued scenes played (%d taps)" % steps)
	ok(Story.flag("stubborn") and Story.flag("barb_quick"), "first choices applied (flags)")
	ok(int(g.fans) == fans0 + 20, "choice effect: +20 fans")
	ok(int(g.story.seen.size()) >= 4, "seen scenes recorded")
	# finish the campaign and play the ending through the overlay
	title("s1c"); workshop(2); tech("wideband"); race("c2c", 1); title("s2c"); workshop(3)
	tech("efi"); add_vehicle("gt", true); title("s3c"); workshop(4)
	race("c4a", 1); g.fans = 9000; g.vehicles[0].lv = 5; day()
	race("c4c", 1)
	ok(Story.is_finished() and not Story.in_free_play(), "finished, ending pending")
	Story.present()
	steps = await _drive(8000)
	ok(Story.in_free_play() and Story.pending_scene() == "", "ending + credits + epilogue played, free play on (%d steps)" % steps)
	ok(Story.objective_text() == "Story complete! Free play", "free play objective text")
	ok(Story.rival_for("c4x2").get("drv", "") == "Silas Vane" and Story.rival_for("c4a").is_empty(), "free play: Crownwell at season finals only")
	await tree.process_frame

## Tap through whatever Story.present() is showing until the queue is empty.
func _drive(limit: int) -> int:
	var tree: SceneTree = r.get_tree()
	var n := 0
	while (Story.is_presenting() or Story.pending_scene() != "") and n < limit:
		n += 1
		var node = Story._showing
		if node is DialogueBox:
			if node.is_waiting_choice(): node.pick(0)
			else: node.advance()
		elif node is EndingScene:
			var b = node.box()
			if b:
				if b.is_waiting_choice(): b.pick(0)
				else: b.advance()
			elif node.credits():
				node.credits().skip_to(1.0)
		elif node == null and Story.pending_scene() != "":
			Story.present()
		await tree.process_frame
	return n

# ---------------- screenshots ----------------
func _screen(title_txt: String) -> Control:
	r.main._clear()
	var v: VBoxContainer = r.main.body
	var hud := StoryHUD.new()
	v.add_child(hud)
	v.add_child(UIKit.title(title_txt))
	v.add_child(UIKit.label("Bay 1: Kei Hatch #1  Lv 3", Color("#c8d0e8"), true))
	v.add_child(UIKit.label("Bay 2: Dirt 250 #1  Lv 2", Color("#c8d0e8"), true))
	for t in ["BUILD", "RACES", "STAFF", "RESEARCH"]: v.add_child(UIKit.btn(t, func(): pass))
	return r.main

func _box_at(sc: Dictionary, line: int) -> DialogueBox:
	var box := DialogueBox.new()
	r.main.add_child(box)
	box.play(sc)
	if sc.has("card"): box.advance()
	for i in line:
		if box.typing: box.advance()
		box.advance()
	if box.typing: box.advance()
	return box

func t_shots() -> void:
	var tree: SceneTree = r.get_tree()
	new_game()
	Story.start_campaign("medium")
	add_vehicle("kei")
	_screen("GARAGE")
	var box := DialogueBox.new()
	r.main.add_child(box)
	box.play(Story.scene("c1_intro"))
	await r.shot("story_01_card")
	box.advance()
	box.advance()
	await r.shot("story_02_narrator")
	box.queue_free()
	_box_at(Story.scene("c1_intro"), 6)
	await r.shot("story_03_hazel")
	_screen("GARAGE")
	box = _box_at(Story.scene("c1_intro"), 8)
	ok(box.is_waiting_choice(), "choice window up on Hazel's question")
	await r.shot("story_04_choice")
	box.pick(0)
	box.advance()
	await r.shot("story_05_reply")
	_screen("RACE RESULTS")
	box = _box_at(Story.scene("c1_title"), 3)
	await r.shot("story_06_rival_choice")
	_screen("RACE RESULTS")
	_box_at(Story.scene("c3_silas"), 0)
	await r.shot("story_07_silas")
	_screen("GARAGE")
	_box_at(Story.scene("hill_climb"), 0)
	await r.shot("story_08_midge")
	r.main._clear()
	var hud := StoryHUD.new()
	r.main.body.add_child(hud)
	r.main.body.add_child(StoryHUD.objectives_panel(Story))
	await r.shot("story_09_hud_objectives")
	r.main._clear()
	var picker := CampaignPicker.new()
	r.main.add_child(picker)
	await r.shot("story_10_picker")
	picker.queue_free()
	# ending + credits
	r.main._clear()
	var g := G()
	g.vehicles[0].lv = 9
	g.vehicles[0].body = "rallyhatch"
	var es := EndingScene.new()
	r.main.add_child(es)
	es.setup_from_story(Story)
	es.play(Story.scene("ending"))
	for i in 40: await tree.process_frame
	es.box().advance()
	await r.shot("story_11_ending")
	while es.box(): es.box().advance(); await tree.process_frame
	ok(es.credits() != null, "credits roll after the podium")
	es.credits().skip_to(0.3)
	await r.shot("story_12_credits")
	es.credits().skip_to(0.86)
	await r.shot("story_13_the_end")
	es.queue_free()
	r.main._clear()
