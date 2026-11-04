class_name CareerScreen
extends Control
## Career home screen and the career screen router.
##
## Home: status bar (date, fan rank, time controls, money, RP, fans, sparks), the animated GarageView fed
## from Career.G, the story strip, a "what's next" line, the 3x3 menu and a workshop/drivers/news panel.
## Time runs (Career.tick on a timer, 1000 ms per day at 1x) only while home is showing with no window,
## story scene, race or pending series round. Toasts and floaty texts play over the garage.
##
## Router: sub-screens are scripts `res://scripts/ui/career/<name>_screen.gd` that extend Control, fill
## their parent, and have `setup(ctx)` + `signal closed` (ctx always carries `router`). open() adds the
## screen to the tree, then calls setup(ctx); closed / back() pops it; the screen under it is shown again
## and gets refresh() if it has one.
##   open(name, ctx := {}) -> Control     back()     replace(name, ctx)     go_home()
##   has_screen(name) -> bool             confirm(title, text, yes, cb)      show_window(spec)
##   save_game() / load_game() / has_save() (static)                        quit_to_title()
## Part-B screen names: staff, research, sponsor, facility, records, settings, test_day, bench.

signal quit_requested

const SAVE_PATH := "user://career.json"
const DIR := "res://scripts/ui/career/"
const DAY_MS := 1000.0
const MENU := [["build", "BUILD"], ["machines", "MACHINES"], ["races", "RACES"], ["staff", "STAFF"], ["research", "RESEARCH"],
	["sponsor", "SPONSORS"], ["facility", "SHOP"], ["records", "RECORDS"], ["settings", "SETTINGS"]]
const JOB_TAG := {"up": "TUNE", "reb": "ENGINE", "swap": "FUEL", "rep": "REPAIR"}
const JOB_COL := {"build": Color("#ffb04a"), "up": Color("#7ac8ff"), "reb": Color("#c890ff"), "swap": Color("#c890ff"), "rep": Color("#ff7a7a")}

## Extra folders searched for screens missing from DIR (tests point this at stub screens).
static var extra_dirs: Array = []

var main = null
var stack: Array = []
var home: Control
var gv: GarageView
var story_hud: StoryHUD
var nextbar: Button
var menu_btns := {}
var badges := {}
var act_box: VBoxContainer
var fx_layer: Control
var toast_box: VBoxContainer
var win_layer: Control
var story_layer: Control
var queue: Array = []
var cur_win: SnesWindow = null
var sfx: CareerSfx
var racing := false
var acc := 0.0
var dirty := true

var _date: Label
var _rank: Label
var _money: Label
var _rp: Label
var _fans: Label
var _sparks: Label
var _speed := {}
var _gv_key := ""
var _act_key := ""
var _vids: Array = []
var _ending_pending := false
var _quit_go_back := true

# ======================================================================
# save / load
# ======================================================================
static func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)

static func save_game() -> bool:
	if Career.G.is_empty(): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return false
	f.store_string(Career.serialize())
	f.close()
	return true

static func load_game() -> bool:
	if not has_save(): return false
	return Career.load_json(FileAccess.get_file_as_string(SAVE_PATH))

## {team, color, date, fans, story} of the save on disk, {} if none / unreadable (title screen).
static func save_info() -> Dictionary:
	if not has_save(): return {}
	var o = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (o is Dictionary) or not o.has("team"): return {}
	var st = o.get("story")
	var d := int(o.get("day", 0))
	var dy := int(Data.D.DAYS_YEAR)
	var dm := int(Data.D.DAYS_MONTH)
	var date := "Y%d %s W%d" % [d / dy + 1, Data.D.MONTHS[(d % dy) / dm], (d % dm) / 7 + 1]
	return {"team": str(o.team.get("name", "")), "color": str(o.team.get("color", "#e8432f")), "date": date, "fans": float(o.get("fans", 0)),
		"story": st is Dictionary and bool(st.get("on", false)) and not bool(st.get("done", false))}

# ======================================================================
# build
# ======================================================================
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()

func _ready() -> void:
	_build_home()
	win_layer = Control.new()
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(win_layer)
	toast_box = CareerKit.vbox(2)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	story_layer = Control.new()
	story_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(story_layer)
	sfx = CareerSfx.new()
	add_child(sfx)
	Career.sfx.connect(sfx.play)
	Career.toast.connect(_on_toast)
	Career.popup.connect(_on_popup)
	Career.floaty.connect(_on_floaty)
	Career.round_due.connect(_on_round_due)
	Career.year_end.connect(_on_year_end)
	Career.game_end.connect(_on_game_end)
	Career.refresh.connect(_on_refresh)
	Career.build_ask.connect(_on_build_ask)
	Story.scene_ready.connect(_on_scene_ready)
	Story.presented_all.connect(_on_presented_all)
	Story.story_finished.connect(_on_story_finished)
	_quit_go_back = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	if Career.G.get("settings", {}).get("speed") == null: Career.G.settings.speed = 1
	# build prompts and race days that were open when the game was saved (time stays stopped until answered)
	for j in Career.G.get("jobs", []):
		if j.get("wait") != null and j.get("pd") != null: _on_build_ask(j)
	for id in Career.G.get("series", {}):
		var a = Career.G.series[id].get("act")
		if a is Dictionary and bool(a.get("pending", false)): show_window({"kind": "round", "sid": id})
	_refresh_home()
	_present_story.call_deferred()

func _exit_tree() -> void:
	if sfx and Career.sfx.is_connected(sfx.play): Career.sfx.disconnect(sfx.play)
	for pair in [[Career.toast, _on_toast], [Career.popup, _on_popup], [Career.floaty, _on_floaty], [Career.round_due, _on_round_due],
			[Career.year_end, _on_year_end], [Career.game_end, _on_game_end], [Career.refresh, _on_refresh], [Career.build_ask, _on_build_ask],
			[Story.scene_ready, _on_scene_ready], [Story.presented_all, _on_presented_all], [Story.story_finished, _on_story_finished]]:
		var sg: Signal = pair[0]
		if sg.is_connected(pair[1]): sg.disconnect(pair[1])
	if is_inside_tree(): get_tree().quit_on_go_back = _quit_go_back

func _build_home() -> void:
	home = Control.new()
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home)
	home.add_child(CareerKit.bg_rect())
	var root := CareerKit.vbox(3)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_bottom = -3
	home.add_child(root)
	root.add_child(_build_status())
	# garage + effects layer
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(GarageView.W, GarageView.H)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	gv = GarageView.new()
	holder.add_child(gv)
	gv.bay_tapped.connect(_on_bay)
	gv.crew_tapped.connect(_on_crew)
	fx_layer = Control.new()
	fx_layer.size = Vector2(GarageView.W, GarageView.H)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fx_layer)
	holder.resized.connect(func(): _center_garage(holder))
	var pads := MarginContainer.new()
	for k in ["left", "right"]: pads.add_theme_constant_override("margin_" + k, 4)
	pads.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pads)
	var low := CareerKit.vbox(4)
	pads.add_child(low)
	story_hud = StoryHUD.new()
	story_hud.tapped.connect(_show_objectives)
	low.add_child(story_hud)
	nextbar = Button.new()
	nextbar.focus_mode = Control.FOCUS_NONE
	nextbar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nextbar.clip_text = true
	nextbar.add_theme_font_override("font", UIKit.font8)
	nextbar.add_theme_font_size_override("font_size", 8)
	nextbar.add_theme_color_override("font_color", UIKit.GOLD)
	nextbar.add_theme_color_override("font_hover_color", Color.WHITE)
	for st in ["normal", "hover", "pressed", "hover_pressed"]: nextbar.add_theme_stylebox_override(st, CareerKit.sb("card"))
	nextbar.custom_minimum_size = Vector2(0, 18)
	nextbar.pressed.connect(_on_nextbar)
	nextbar.set_meta("tid", "nextbar")
	low.add_child(nextbar)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	low.add_child(grid)
	for m in MENU:
		var id: String = m[0]
		var col := UIKit.BTN
		if id == "build": col = Color("#2f8a4a")
		elif id == "races": col = Color("#c0392b")
		var b := CareerKit.btn(m[1], _on_menu.bind(id), col, false, "menu_" + id)
		b.custom_minimum_size = Vector2(0, 26)
		grid.add_child(b)
		menu_btns[id] = b
		var dot := Badge.new()
		dot.visible = false
		b.add_child(dot)
		dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dot.position = Vector2(b.size.x - 9, 2)
		b.resized.connect(func(): dot.position = Vector2(b.size.x - 9, 2))
		badges[id] = dot
	var ap := PanelContainer.new()
	ap.add_theme_stylebox_override("panel", CareerKit.sb("card"))
	ap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	low.add_child(ap)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 40)
	ap.add_child(sc)
	act_box = CareerKit.vbox(2)
	act_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(act_box)

func _center_garage(holder: Control) -> void:
	var x := roundf((holder.size.x - GarageView.W) / 2.0)
	gv.position = Vector2(x, 0)
	fx_layer.position = Vector2(x, 0)

func _build_status() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CareerKit.sb("hud"))
	var v := CareerKit.vbox(2)
	p.add_child(v)
	var r1 := CareerKit.hbox(8)
	v.add_child(r1)
	_date = CareerKit.lbl("", UIKit.GOLD, false, false)
	CareerKit.shrink(_date)
	_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(_date)
	_rank = CareerKit.lbl("", CareerKit.FANC.darkened(0.15), false, false)
	_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(_rank)
	for sp in [0, 1, 2]:
		var b := CareerKit.chip(["II", "1x", "2x"][sp], _speed_btn.bind(sp), false, false, "speed_%d" % sp)
		b.custom_minimum_size = Vector2(22, 16)
		CareerKit.shrink(b, true)
		r1.add_child(b)
		_speed[sp] = b
	var r2 := CareerKit.hbox(8)
	v.add_child(r2)
	_money = CareerKit.lbl("", CareerKit.MONEY, false, false)
	_rp = CareerKit.lbl("", CareerKit.RPC, false, false)
	_fans = CareerKit.lbl("", CareerKit.FANC, false, false)
	_sparks = CareerKit.lbl("", UIKit.GOLD, false, false)
	for l in [_money, _rp, _fans]:
		CareerKit.shrink(l)
		r2.add_child(l)
	_sparks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r2.add_child(_sparks)
	return p

class Badge extends Control:
	func _init() -> void:
		size = Vector2(7, 7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 7, 7), Color("#140c24"))
		draw_rect(Rect2(1, 1, 5, 5), Color("#ff4a3a"))
		draw_rect(Rect2(2, 2, 2, 1), Color("#ffb0a0"))

# ======================================================================
# time
# ======================================================================
func speed() -> int:
	return int(Career.G.get("settings", {}).get("speed", 1))

func _set_speed(sp: int) -> void:
	Career.G.settings.speed = sp
	_update_status()

## Time buttons: pause, 1x, fast (tap again while fast: 2x <-> 4x), like the web top bar.
func _speed_btn(i: int) -> void:
	match i:
		0: _set_speed(0)
		1: _set_speed(1)
		_: _set_speed(4 if speed() == 2 else 2)

func paused() -> bool:
	if speed() <= 0 or racing or not stack.is_empty() or cur_win != null or not queue.is_empty(): return true
	if Story.is_presenting(): return true
	if not is_visible_in_tree(): return true
	for id in Career.G.get("series", {}):
		var a = Career.G.series[id].get("act")
		if a is Dictionary and bool(a.get("pending", false)): return true
	return false

func _process(delta: float) -> void:
	if Career.G.is_empty(): return
	if dirty and home.visible: _refresh_home()
	if paused():
		acc = minf(acc, DAY_MS * 0.9)
		return
	acc += delta * 1000.0 * speed()
	var n := 0
	while acc >= DAY_MS and n < 6:
		acc -= DAY_MS
		n += 1
		Career.tick()
		if int(Career.G.day) % Career.DAYS_MONTH == 0: save_game()
		if paused():
			acc = 0.0
			break

## Advance `days` days right now (tests / debug), stopping early when something needs input.
func run_days(days: int) -> int:
	var n := 0
	while n < days and not paused():
		Career.tick()
		n += 1
		if int(Career.G.day) % Career.DAYS_MONTH == 0: save_game()
	return n

# ======================================================================
# home refresh
# ======================================================================
func _on_refresh() -> void:
	dirty = true

func _refresh_home() -> void:
	dirty = false
	if Career.G.is_empty(): return
	_update_status()
	var st := _garage_state()
	var key := str(st)
	if key != _gv_key:
		_gv_key = key
		gv.set_state(st)
	_update_nextbar()
	_update_badges()
	_update_activity()

func _update_status() -> void:
	var G: Dictionary = Career.G
	_date.text = CareerKit.asc(Career.dateStr()).to_upper()
	_rank.text = CareerKit.asc(Career.fanRankName()).to_upper()
	_money.text = U.money(float(G.money))
	_money.add_theme_color_override("font_color", CareerKit.BAD if float(G.money) < 0 else CareerKit.MONEY)
	_rp.text = "RP %s" % U.num(float(G.rp))
	_fans.text = "FANS %s" % U.num(float(G.fans))
	var sp: Dictionary = G.sparks
	_sparks.text = "B%d S%d G%d" % [int(sp.get("b", 0)), int(sp.get("s", 0)), int(sp.get("g", 0))]
	var cur := speed()
	(_speed[2] as Button).text = "4x" if cur == 4 else "2x"
	for k in _speed:
		var on: bool = (int(k) == cur) if int(k) < 2 else cur >= 2
		var c := UIKit.GOLD.darkened(0.35) if on else Color("#22408a")
		var b: Button = _speed[k]
		b.add_theme_stylebox_override("normal", UIKit.sb(c, CareerKit.OUTLINE, 1, 4))
		b.add_theme_stylebox_override("hover", UIKit.sb(c.lightened(0.15), CareerKit.OUTLINE, 1, 4))

func _garage_state() -> Dictionary:
	var G: Dictionary = Career.G
	var col := str(G.team.color)
	var bays := []
	var busy := []
	_vids = []
	for v in G.vehicles:
		var b: Dictionary = Data.D.BODY[v.body]
		var st := "ready"
		var ph := 8
		var waiting := false
		var prog := 0.5
		match str(v.status):
			"build":
				st = "building"
				var j := Career.bJob(v.id)
				if j.get("pd") != null:
					ph = clampi(int(j.pi), 0, 7)
					waiting = j.get("wait") != null
					prog = clampf(1.0 - float(j.pd[ph]) / maxf(0.01, float(j.get("plen", 1))), 0.0, 1.0)
				elif not j.is_empty():
					ph = clampi(int(j.get("ph", 0)) * 2, 0, 7)
				else: ph = 0
			"upgrade": st = "upgrading"
			"repair": st = "repair"
		if st != "ready": busy.append(bays.size())
		bays.append({"kind": str(b.kind), "col": col, "status": st, "phase": ph, "waiting": waiting, "label": str(v.name), "prog": snappedf(prog, 0.05)})
		_vids.append(v.id)
	var crew := []
	var mi := 0
	for s in G.staff:
		var c := {"role": "drv" if s.role == "drv" else "mech", "col": col, "name": str(s.name), "busy_bay": -1}
		if s.role == "mec" and not busy.is_empty():
			c.busy_bay = busy[mi % busy.size()]
			mi += 1
		if s.get("skin") != null: c.skin = str(s.skin)
		if s.get("hair") != null: c.hair = str(s.hair)
		crew.append(c)
	var fac := []
	for f in G.fac:
		if f != null: fac.append(str(f.id))
	return {"ws": int(G.ws), "bays": bays, "crew": crew, "season": GarageView.season_of_day(int(G.day)), "tod": "day", "facilities": fac, "team_col": col}

func _update_nextbar() -> void:
	var G: Dictionary = Career.G
	var best = null
	for id in G.series:
		var a = G.series[id].get("act")
		if a is Dictionary and (best == null or int(a.next) < int(G.series[best].act.next)): best = id
	var t := ""
	if best != null:
		var S: Dictionary = Data.D.SER[best]
		var a: Dictionary = G.series[best].act
		var r: Dictionary = Data.D.RACE[S.rounds[mini(int(a.round), S.rounds.size() - 1)]]
		var dd := maxi(0, int(a.next) - int(G.day))
		if bool(a.get("pending", false)) or dd == 0: t = "> RACE DAY! R%d %s" % [int(a.round) + 1, r.n]
		else: t = "> R%d in %dd: %s" % [int(a.round) + 1, dd, r.n]
	elif G.vehicles.is_empty(): t = "> BUILD your first machine!"
	else:
		var n := Career.availRaceIds().size()
		t = "> %d event%s open: tap to race" % [n, "" if n == 1 else "s"]
	nextbar.text = CareerKit.asc(t)

func _update_badges() -> void:
	var G: Dictionary = Career.G
	var ser := false
	for id in Career.availRaceIds():
		if Data.D.SER.has(id): ser = true; break
	badges.races.visible = ser
	badges.sponsor.visible = G.spons.size() < int(Career.ws().spon) and not Career.sponsorOffers().is_empty() and has_screen("sponsor")
	badges.facility.visible = Career.canUpgradeWS() and has_screen("facility")
	for id in menu_btns:
		var ok: bool = has_screen(id) or id in ["build", "machines", "races"]
		menu_btns[id].disabled = not ok

func _update_activity() -> void:
	var G: Dictionary = Career.G
	var rows := []
	for j in G.jobs:
		var v := Career.veh(j.vid)
		if v.is_empty(): continue
		var pr := clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)
		var tag: String = JOB_TAG.get(j.type, "WORK")
		var wait := false
		if j.type == "build":
			if j.get("pd") != null:
				tag = "%s %d/8" % [Data.D.BPHS[Data.D.BPH[int(j.pi)]], int(j.pi) + 1]
				wait = j.get("wait") != null
			else: tag = "BUILD"
		elif j.type == "up": tag = "TUNE " + str(j.k).to_upper()
		rows.append([j.type, tag, str(v.name), snappedf(pr, 0.02), wait, v.id])
	var drv := []
	for s in Career.drivers(): drv.append([str(s.name), int(round(float(s.energy))), float(s.maxE)])
	var news := []
	for l in G.log.slice(0, 5): news.append([int(l.d), str(l.t)])
	var key := str([rows, drv, news, G.vehicles.size()])
	if key == _act_key: return
	_act_key = key
	CareerKit.clear(act_box)
	act_box.add_child(CareerKit.sec("WORKSHOP %d/%d BAYS" % [G.jobs.size(), Career.bays()]))
	if rows.is_empty():
		act_box.add_child(CareerKit.line("All bays free." if not G.vehicles.is_empty() else "Empty shed. Time to BUILD!", CareerKit.DIMC))
	for r in rows:
		var h := CareerKit.hbox(4)
		var tl := CareerKit.lbl(r[1] + (" !" if r[4] else ""), UIKit.GOLD if r[4] else JOB_COL.get(r[0], CareerKit.TXT), false, false)
		tl.custom_minimum_size = Vector2(84, 0)
		CareerKit.shrink(tl)
		h.add_child(tl)
		h.add_child(CareerKit.lbl(r[2], CareerKit.TXT, false, false))
		h.add_child(CareerKit.bar(r[3], JOB_COL.get(r[0], CareerKit.GOOD), 52, 6))
		var c := CareerKit.card_btn(h, _on_job.bind(r[5], r[4]), "card_gold" if r[4] else "card", false, "job_%d" % int(r[5]))
		act_box.add_child(c)
	act_box.add_child(CareerKit.sec("DRIVERS"))
	for d in drv:
		var h2 := CareerKit.hbox(4)
		h2.add_child(CareerKit.lbl(d[0], CareerKit.TXT, false, false))
		h2.add_child(CareerKit.bar(float(d[1]) / maxf(1.0, d[2]), Color("#ffb347") if float(d[1]) < 30 else CareerKit.GOOD, 60, 6))
		var n := CareerKit.lbl(str(d[1]), CareerKit.SUB, false, false)
		n.custom_minimum_size = Vector2(24, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		CareerKit.shrink(n, true)
		h2.add_child(n)
		act_box.add_child(h2)
	act_box.add_child(CareerKit.sec("NEWS"))
	for nw in news:
		var l := CareerKit.small("%s  %s" % [CareerKit.asc(Career.dateStr(nw[0])), nw[1]], CareerKit.SUB)
		act_box.add_child(l)

# ======================================================================
# home input
# ======================================================================
func _on_menu(id: String) -> void:
	match id:
		"races": open("races", {"tab": "series" if _active_series() else "races"})
		_: open(id)

func _active_series() -> bool:
	for id in Career.G.series:
		if Career.G.series[id].get("act") != null: return true
	return false

func _on_nextbar() -> void:
	if Career.G.vehicles.is_empty(): open("build")
	else: open("races", {"tab": "series" if _active_series() else "races"})

func _on_bay(i: int) -> void:
	if i < 0 or i >= _vids.size(): return
	var v := Career.veh(_vids[i])
	if v.is_empty(): return
	var j := Career.bJob(v.id)
	if not j.is_empty() and j.get("wait") != null:
		Career.bDecide(v.id)
		return
	open("vehicle", {"vid": v.id})

func _on_crew(_i: int) -> void:
	if has_screen("staff"): open("staff")

func _on_job(vid, waiting: bool) -> void:
	if waiting: Career.bDecide(vid)
	else: open("vehicle", {"vid": vid})

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if cur_win != null and is_instance_valid(cur_win): cur_win.dismiss()
			elif Story.is_presenting() or racing: pass
			elif not stack.is_empty():
				var top: Control = stack.back()
				if top.has_method("back"): top.back()
				else: back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if not Career.G.is_empty(): save_game()

# ======================================================================
# router
# ======================================================================
func _path(name: String) -> String:
	var p := DIR + name + "_screen.gd"
	if ResourceLoader.exists(p): return p
	for d in extra_dirs:
		var q := str(d) + name + "_screen.gd"
		if ResourceLoader.exists(q): return q
	return ""

func has_screen(name: String) -> bool: return _path(name) != ""

func top() -> Control: return stack.back() if not stack.is_empty() else null

func open(name: String, ctx := {}) -> Control:
	if name == "title":   # part-B screens (settings) ask for the title this way
		quit_to_title()
		return null
	var p := _path(name)
	if p == "":
		_on_toast("Coming soon!")
		return null
	var scr = load(p).new()
	if not (scr is Control):
		push_warning("CareerScreen: %s is not a Control" % p)
		return null
	var s: Control = scr
	var c: Dictionary = ctx.duplicate()
	c.router = self
	s.set_meta("screen", name)
	if not stack.is_empty(): (stack.back() as Control).visible = false
	home.visible = false
	gv.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(s)
	move_child(s, win_layer.get_index())
	_place_toasts.call_deferred()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.set_offsets_preset(Control.PRESET_FULL_RECT)
	stack.append(s)
	if s.has_signal("closed"): s.connect("closed", _on_screen_closed.bind(s))
	if s.has_method("setup"): s.call("setup", c)
	return s

func _on_screen_closed(s: Control) -> void:
	if stack.is_empty(): return
	if stack.back() == s: back()
	elif stack.has(s):
		stack.erase(s)
		s.queue_free()

func back() -> void:
	if stack.is_empty(): return
	var s: Control = stack.pop_back()
	s.queue_free()
	_show_top()

## Replace the top screen (prerace -> race).
func replace(name: String, ctx := {}) -> Control:
	if not stack.is_empty():
		var s: Control = stack.pop_back()
		s.queue_free()
	return open(name, ctx)

func go_home() -> void:
	while not stack.is_empty():
		var s: Control = stack.pop_back()
		s.queue_free()
	_show_top()

func _show_top() -> void:
	_place_toasts.call_deferred()
	if stack.is_empty():
		home.visible = true
		gv.process_mode = Node.PROCESS_MODE_INHERIT
		dirty = true
		_act_key = ""
		_present_story()
		_pump()
	else:
		var t: Control = stack.back()
		t.visible = true
		if t.has_method("refresh"): t.call("refresh")

## Race screen: the race is over and its results were dismissed (home, or back to the opener for tests).
func race_done(to_home := true) -> void:
	racing = false
	save_game()
	if to_home: go_home()
	else: back()

func quit_to_title() -> void:
	save_game()
	quit_requested.emit()

# ======================================================================
# windows
# ======================================================================
## spec: {kind: "popup"|"build"|"round"|"year"|"end"|"confirm"|"objectives"|"free"|"window", ...}
## Specs with now = true jump the queue and show even during a race.
func show_window(spec: Dictionary) -> void:
	if bool(spec.get("now", false)): queue.push_front(spec)
	else: queue.append(spec)
	_pump()

func confirm(t: String, text: String, yes: String, cb: Callable, col: Color = UIKit.ACCENT) -> void:
	show_window({"kind": "confirm", "title": t, "text": text, "yes": yes, "cb": cb, "col": col, "now": true})

func _pump() -> void:
	if cur_win != null and is_instance_valid(cur_win): return
	cur_win = null
	if Story.is_presenting(): return
	while not queue.is_empty():
		var spec: Dictionary = queue[0]
		if racing and not bool(spec.get("now", false)): return
		queue.pop_front()
		var w := _make_window(spec)
		if w == null: continue
		cur_win = w
		win_layer.add_child(w)
		if str(spec.kind) in ["build", "round", "popup"]: sfx.play("bump" if str(spec.kind) == "build" else "good")
		w.closed.connect(_on_win_closed.bind(w))
		return
	_present_story()

func _on_win_closed(_i: int, w: SnesWindow) -> void:
	if cur_win == w: cur_win = null
	dirty = true
	if not stack.is_empty():
		var t: Control = stack.back()
		if t.has_method("refresh") and t.visible: t.call("refresh")
	_pump.call_deferred()

func _make_window(spec: Dictionary) -> SnesWindow:
	var w := SnesWindow.new()
	match str(spec.kind):
		"popup": return _popup_window(w, spec.data)
		"build": return _build_window(w, spec.vid)
		"round": return _round_window(w, str(spec.sid))
		"year": return _year_window(w, spec.s)
		"end": return _end_window(w)
		"objectives": return _objectives_window(w)
		"free":
			w.build("FREE PLAY", ["The Crownwell Cup sits in the shed in Tinplate.", "Your career goes on: more series, more machines, the Legend tier. Race on!"],
				[{"t": "RACE ON!", "col": UIKit.OK, "tid": "ok"}])
			w.cancel_index = 0
			return w
		"confirm":
			w.build(str(spec.title), str(spec.text), [{"t": "CANCEL", "col": UIKit.BTN_LO, "tid": "cancel"},
				{"t": str(spec.yes), "cb": spec.cb, "col": spec.get("col", UIKit.ACCENT), "tid": "yes"}])
			w.cancel_index = 0
			return w
		"window":
			return spec.win
	w.free()
	return null

func _popup_window(w: SnesWindow, d: Dictionary) -> SnesWindow:
	var k := str(d.get("kind", ""))
	var btns := []
	if k == "engine_failure" and d.get("vid") != null and not Career.veh(d.vid).is_empty():
		btns.append({"t": "LATER", "col": UIKit.BTN_LO, "tid": "ok"})
		btns.append({"t": "ENGINE", "cb": open.bind("vehicle", {"vid": d.vid, "tab": "engine"}), "col": UIKit.OK, "tid": "engine"})
	else:
		btns.append({"t": "OK", "col": UIKit.OK, "tid": "ok"})
	var col := UIKit.GOLD
	if k in ["engine_failure"]: col = CareerKit.BAD
	w.build(CareerKit.asc(d.get("title", "")).to_upper(), CareerKit.asc(d.get("text", "")), btns, col)
	w.kind = "popup:" + k
	w.cancel_index = 0
	return w

func _build_window(w: SnesWindow, vid) -> SnesWindow:
	var j := Career.bJob(vid)
	var v := Career.veh(vid)
	if j.is_empty() or v.is_empty() or j.get("wait") == null:
		w.free()
		return null
	j.asked = true
	var wt: Dictionary = j.wait
	var D: Dictionary = Data.D
	var body := []
	var btns := []
	if wt.k == "ph":
		var ph: String = wt.ph
		var top := CareerKit.pair(v.name, "PHASE %d/8" % (int(j.pi) + 1), CareerKit.TXT, UIKit.GOLD)
		body.append(top)
		body.append(CareerKit.small(BuildScreen.HINT.get(ph, ""), CareerKit.SUB))
		var bl: Array = v.get("blog", [])
		if not bl.is_empty():
			var so := CareerKit.vbox(1)
			for x in bl.slice(maxi(0, bl.size() - 3)): so.add_child(CareerKit.line("+ " + str(x), CareerKit.GOOD))
			body.append(so)
		var opts := Career.bOpts(v, ph)
		for i in opts.size():
			var o: Dictionary = opts[i]
			var r := Career.bReq(o, v)
			var sub := [str(o.get("d", "")), [CareerKit.asc(Career.bFx(o, v)) if Career.bFx(o, v) != "" else "No change", UIKit.GOLD]]
			if not r.ok: sub.append(["LOCKED: " + str(r.why), CareerKit.BAD])
			btns.append({"t": str(o.n), "tag": "CREW PICK" if o.get("crew") else "", "sub": sub, "dis": not r.ok, "cb": _bchoose.bind(vid, i),
				"tid": "opt_%d" % i, "kind": "card_sel" if o.get("crew") else "card"})
		btns.append({"t": "Let the crew decide", "cb": _bchoose.bind(vid, "crew"), "col": UIKit.BTN_LO, "wide": true, "tid": "crew"})
		w.build(str(D.BPHN[ph]), body, btns)
		w.cancel_index = btns.size() - 1
	else:
		var e: Dictionary = D.BEVM[wt.ev]
		body.append(CareerKit.small(str(wt.get("txt", "")), Color("#e4e8f6")))
		body.append(CareerKit.small("%s | %s next" % [v.name, D.BPHN.get(wt.get("next", ""), "")], CareerKit.SUB))
		for i in e.o.size():
			var o2: Dictionary = e.o[i]
			var c := Career.bCost(o2, v)
			var ok := not (c > 0 and float(Career.G.money) < c)
			var fx := Career.bFx(o2, v)
			btns.append({"t": str(o2.n), "sub": [[fx if fx != "" else "No change", UIKit.GOLD if fx != "" else CareerKit.SUB]] + ([] if ok else [["Not enough money", CareerKit.BAD]]),
				"dis": not ok, "cb": _bchoose.bind(vid, i), "tid": "opt_%d" % i})
		w.build("! " + str(e.n), body, btns, CareerKit.WARN)
		w.cancel_index = btns.size() - 1
	w.kind = "build:%s" % str(vid)
	return w

func _bchoose(vid, idx) -> bool:
	var ok := Career.bChoose(vid, idx)
	if not ok:
		_on_toast("Can't do that right now")
		return false
	dirty = true
	return true

func _round_window(w: SnesWindow, sid: String) -> SnesWindow:
	var S: Dictionary = Data.D.SER[sid]
	var a = Career.G.series.get(sid, {}).get("act")
	if not (a is Dictionary):
		w.free()
		return null
	var r: Dictionary = Data.D.RACE[S.rounds[int(a.round)]]
	var body := [CareerKit.big(S.n, Color.WHITE), CareerKit.line("Round %d of %d" % [int(a.round) + 1, S.rounds.size()], CareerKit.SUB),
		CareerKit.big(r.n, UIKit.GOLD), CareerKit.small("Choose who races. Skipping scores no points.", CareerKit.SUB)]
	w.build("RACE DAY!", body, [{"t": "LET'S GO!", "cb": open.bind("prerace", {"rid": r.id, "sid": sid}), "col": UIKit.OK, "wide": true, "tid": "go"}])
	w.kind = "round:" + sid
	return w

func _year_window(w: SnesWindow, s: Dictionary) -> SnesWindow:
	var yr: Dictionary = s.get("yr", {})
	var y := int(s.get("y", 1))
	var rank := int(s.get("rank", 0))
	var body := [CareerKit.pair("Wins", str(int(yr.get("wins", 0))), CareerKit.TXT, UIKit.GOLD),
		CareerKit.pair("Podiums", str(int(yr.get("podiums", 0))), CareerKit.TXT, UIKit.GOLD),
		CareerKit.pair("Titles", str(int(yr.get("titles", 0))), CareerKit.TXT, UIKit.GOLD),
		CareerKit.pair("Prize money", U.money(float(yr.get("earn", 0))), CareerKit.TXT, CareerKit.MONEY),
		CareerKit.pair("Team rank", str(Data.D.FAN_RANKS[rank][1]), CareerKit.TXT, CareerKit.FANC),
		CareerKit.pair("Fan-club bonus", "+" + U.money(float(s.get("bonus", 0))), CareerKit.TXT, CareerKit.MONEY)]
	if y < Career.YEARS: body.append(CareerKit.small("%d seasons to go!" % (Career.YEARS - y), CareerKit.SUB))
	w.build("YEAR %d REPORT" % y, body, [{"t": "OK", "col": UIKit.OK, "tid": "ok"}])
	w.cancel_index = 0
	return w

func _end_window(w: SnesWindow) -> SnesWindow:
	var G: Dictionary = Career.G
	var tiers: Array = G.st.titles.map(func(t): return int(Data.D.SER[t].tier))
	var verdict := "A solid career. Keep racing - the season never ends!"
	if 5 in tiers: verdict = "A true Legend of the sport!"
	elif 4 in tiers: verdict = "World champions! Can you conquer the Legend series?"
	var body := [CareerKit.heading("SCORE %s" % U.num(float(Career.score()))),
		CareerKit.pair("Titles", str(G.st.titles.size()), CareerKit.TXT, UIKit.GOLD), CareerKit.pair("Wins", str(int(G.st.wins)), CareerKit.TXT, UIKit.GOLD),
		CareerKit.pair("Fans", U.num(float(G.fans)), CareerKit.TXT, CareerKit.FANC), CareerKit.small(verdict, Color.WHITE),
		CareerKit.small("You can keep playing as long as you like.", CareerKit.SUB)]
	w.build("%d SEASONS COMPLETE!" % Career.YEARS, body, [{"t": "KEEP RACING", "col": UIKit.OK, "tid": "ok"}])
	w.cancel_index = 0
	return w

func _objectives_window(w: SnesWindow) -> SnesWindow:
	var ch: Dictionary = Story.current_chapter()
	var body := []
	var top := "FINALE" if bool(ch.get("finale", false)) else "CHAPTER %d OF %d" % [int(ch.get("n", 1)), int(ch.get("of", 1))]
	body.append(CareerKit.line(top, UIKit.GOLD))
	for o in Story.objectives():
		var cnt := "" if int(o.need) <= 1 else "  %s/%s" % [U.num(float(o.cur)), U.num(float(o.need))]
		body.append(CareerKit.small(("[X] " if o.done else "[ ] ") + str(o.txt) + cnt, CareerKit.GOOD if o.done else Color.WHITE))
		if str(o.detail) != "": body.append(CareerKit.small("    " + str(o.detail), CareerKit.DIMC))
	if Story.is_finished(): body.append(CareerKit.small(Story.objective_text(), CareerKit.GOOD))
	w.build(str(ch.get("title", "Story")), body, [{"t": "OK", "col": UIKit.OK, "tid": "ok"}])
	w.cancel_index = 0
	return w

func _show_objectives() -> void:
	if Story.has_campaign(): show_window({"kind": "objectives", "now": true})

# ======================================================================
# Career signals
# ======================================================================
func _on_toast(t: String) -> void:
	if toast_box == null: return
	while toast_box.get_child_count() >= 3:
		var o := toast_box.get_child(0)
		toast_box.remove_child(o)
		o.queue_free()
	var l := CareerKit.small(t, Color.WHITE)
	var p := CareerKit.panel(l, "card")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE      # taps go through to the screen
	toast_box.add_child(p)
	_place_toasts()
	get_tree().create_timer(2.6).timeout.connect(_drop_toast.bind(p))

## Toasts sit over the garage roof at home and under the header elsewhere; they never block taps.
func _place_toasts() -> void:
	var y := 40 if (home.visible and stack.is_empty()) else 32
	toast_box.anchor_left = 0.0
	toast_box.anchor_right = 1.0
	toast_box.anchor_top = 0.0
	toast_box.anchor_bottom = 0.0
	toast_box.offset_left = 6
	toast_box.offset_right = -6
	toast_box.offset_top = y
	toast_box.offset_bottom = y

func _drop_toast(p) -> void:
	if is_instance_valid(p):
		p.queue_free()
		_place_toasts.call_deferred()

func _on_floaty(text: String, vid, col: String) -> void:
	if gv == null or not home.visible: return
	var x := GarageView.W / 2.0
	var y := 90.0
	var i := _vids.find(vid) if vid != null else -1
	if i >= 0 and i < gv.slots.size():
		x = float(gv.slots[i].cx)
		y = float(gv.slots[i].gy) - 48.0
	var l := CareerKit.lbl(text, Color(col) if col != "" else Color.WHITE, false, false)
	l.add_theme_color_override("font_outline_color", CareerKit.OUTLINE)
	l.add_theme_constant_override("outline_size", 3)
	CareerKit.shrink(l)
	fx_layer.add_child(l)
	var w := float(l.get_combined_minimum_size().x)
	l.position = Vector2(clampf(roundf(x - w / 2.0), 2.0, GarageView.W - w - 2.0), y)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", y - 18.0, 1.3)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.5)
	tw.tween_callback(l.queue_free)

func _on_popup(d: Dictionary) -> void:
	show_window({"kind": "popup", "data": d})

func _on_build_ask(j: Dictionary) -> void:
	var key := "build:%s" % str(j.vid)
	if cur_win != null and is_instance_valid(cur_win) and cur_win.kind == key: return
	for s in queue:
		if str(s.kind) == "build" and str(s.vid) == str(j.vid): return
	show_window({"kind": "build", "vid": j.vid})

func _on_round_due(sid: String) -> void:
	save_game()
	show_window({"kind": "round", "sid": sid})

func _on_year_end(s: Dictionary) -> void:
	save_game()
	show_window({"kind": "year", "s": s})

func _on_game_end() -> void:
	show_window({"kind": "end"})

# ======================================================================
# story
# ======================================================================
func _present_story() -> void:
	if not is_inside_tree() or racing or not stack.is_empty(): return
	if cur_win != null and is_instance_valid(cur_win): return
	if Story.is_presenting() or Story.pending_scene() == "": return
	Story.present(story_layer)

func _on_scene_ready(_id: String) -> void:
	_present_story.call_deferred()

func _on_presented_all() -> void:
	if _ending_pending and Story.is_finished():
		_ending_pending = false
		show_window({"kind": "free"})
	dirty = true
	_pump()

func _on_story_finished() -> void:
	_ending_pending = true
