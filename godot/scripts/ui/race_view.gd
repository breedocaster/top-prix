class_name RaceView
extends Control
## SNES-style race screen. Top: 256x272 Mode 7 view (sky/parallax, perspective floor, scaled sprites)
## with an overlay HUD (position + gap, lap/time, minimap, course name, banners).
## Bottom: standings board, commentary ticker and race-call cards for the entries this device owns.
## Runs the sim itself (local / LAN host) or renders host snapshots (LAN client).

signal finished(result: Dictionary)

const VIEW := Vector2(256, 272)
const HORIZON := 62.0
const FOCAL := 136.0
const CAM_H := 54.0
const CAM_DIST := 80.0
const FOG_FAR := 1400.0
const MAP := Vector2(68, 68)      # overlay minimap box
const SNAP_HZ := 15.0

var net_mode := "local"      # local | host | client
var attract := false
## Label for the course strip under the game screen (career: series / round / stage); "" = race name.
var title_override := ""
var sim: RaceSim
var def: Dictionary
var tr: Dictionary
var fmt: Dictionary
var geo: TrackGeo
var ents: Array = []
var my_owner := 1
var follow := -1
var follow_lock := -1           # entry the camera was told to follow (tap a call card's name)
var cam_pos := Vector2.ZERO
var cam_ang := 0.0
var speed := 1.0
var countdown := 1.6
var started := false
var ended := false
var race_t := 0.0
var snap_acc := 0.0
var sent_msg := 0
var shown_msg := 0
var log_lines: Array = []
var result_cache := {}

var screen: Control
var backdrop: Backdrop
var floor_rect: ColorRect
var floor_mat: ShaderMaterial
var layer: SpriteLayer
var painter_vp: SubViewport
var overlay: Control            # HUD drawn over the game screen
var banner: Label
var board: Control              # standings chips
var ticker: Control             # commentary
var calls: VBoxContainer
var speed_btn: Button
var call_widgets := {}
var _flash := ""                # transient banner text (FINAL LAP, ...)
var _flash_t := 0.0
var _last_lap := 0
var _rows := 6                  # standings board rows (fewer when two call cards need the room)
var _map_pts := PackedVector2Array()
var _map_sc := 1.0
var _map_off := Vector2.ZERO
# audio
var _eng: Array = []            # [{node: EngineAudio, rev: RevModel, idx: int}]
var _eng_t := 0.0
var _kref := 1.0
var _cd_last := -1
var _went := false
var _seen := {}                 # idx -> {crash, boost, fin}

# ---------------- setup ----------------
## Local or LAN-host race. `owner` is this device's peer id (1 for local/host).
func start_sim(rs: RaceSim, mode: String, owner: int = 1) -> void:
	net_mode = mode
	sim = rs
	my_owner = owner
	def = rs.def; tr = rs.tr; fmt = rs.fmt
	ents = rs.ents
	_build(rs.rain)

## LAN client: build from the host's setup packet.
func start_client(setup: Dictionary, owner: int) -> void:
	net_mode = "client"
	my_owner = owner
	def = Data.race(setup.race_id)
	fmt = setup.fmt
	var laps_o = fmt.laps if int(fmt.laps) != int(def.laps) else null
	tr = RaceSim.build_track(def, setup.rain, laps_o)
	ents = []
	for s in setup.ents:
		var e: Dictionary = s.duplicate(true)
		e.merge({"prog": 0.0, "v": 0.0, "lane": float(e.get("lane", 1)), "fin": false, "dnf": false, "hp": 1.0, "boost": 0.0,
			"air": 0.0, "crash": 0.0, "pos": e.idx + 1, "tactic": "normal", "sparks": {"b": 0, "s": 0, "g": 0}}, false)
		ents.append(e)
	countdown = float(setup.get("countdown", 1.6))
	_build(setup.rain)

func _build(rain: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var cond: Dictionary = Data.cond(def.id)
	var env := Env.pick(tr, cond, rain)
	var theme := Env.theme(env)
	geo = TrackGeo.build(tr, def.id)
	# painted course texture
	painter_vp = TrackPainter.make_viewport(geo, env == "night")
	add_child(painter_vp)
	# 256x224 game screen
	screen = Control.new()
	screen.position = Vector2.ZERO
	screen.size = VIEW
	screen.clip_contents = true
	add_child(screen)
	backdrop = Backdrop.new()
	backdrop.setup(env, HORIZON, VIEW, URng.fnv(def.id))
	screen.add_child(backdrop)
	floor_rect = ColorRect.new()
	floor_rect.size = VIEW
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = load("res://shaders/mode7.gdshader")
	floor_mat.set_shader_parameter("track_tex", painter_vp.get_texture())
	floor_mat.set_shader_parameter("tex_origin", geo.bbox.position)
	floor_mat.set_shader_parameter("tex_size", geo.bbox.size)
	floor_mat.set_shader_parameter("cam_h", CAM_H)
	floor_mat.set_shader_parameter("horizon", HORIZON)
	floor_mat.set_shader_parameter("focal", FOCAL)
	floor_mat.set_shader_parameter("view_size", VIEW)
	floor_mat.set_shader_parameter("fog_far", FOG_FAR)
	var g: Array = theme.ground
	floor_mat.set_shader_parameter("ground_a", Color(g[0]))
	floor_mat.set_shader_parameter("ground_b", Color(g[1]))
	floor_mat.set_shader_parameter("ground_c", Color(g[2]))
	floor_mat.set_shader_parameter("ground_kind", int(g[3]))
	floor_mat.set_shader_parameter("fog_col", Color(theme.fog))
	floor_rect.material = floor_mat
	screen.add_child(floor_rect)
	layer = SpriteLayer.new()
	layer.rv = self
	layer.rain = rain
	layer.place_props(geo, theme, URng.fnv(def.id) & 0xFFFF, env)
	screen.add_child(layer)
	var cols := []
	for e in ents:
		layer.sheets[int(e.idx)] = SpriteForge.vehicle_tex(e.kind)
		cols.append(Color(e.col))
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/palette_swap.gdshader")
	pm.set_shader_parameter("palette", SpriteForge.palette(cols))
	layer.material = pm
	for e in ents:
		e.rprog = float(e.prog)
		e.rlane = _lane_off(e)
	# HUD over the game screen
	if attract:
		countdown = 0.0
	else:
		_prep_minimap()
		overlay = Control.new()
		overlay.size = VIEW
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.draw.connect(_draw_overlay)
		screen.add_child(overlay)
		banner = UIKit.title("")
		banner.position = Vector2(0, 104); banner.size = Vector2(VIEW.x, 24)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(banner)
		_build_panel()
		_setup_audio()
	follow = _pick_follow()
	var e0: Dictionary = ents[max(0, follow)]
	var s0 := geo.sample(e0.rprog, e0.rlane)
	cam_ang = s0.ang
	cam_pos = s0.pos - Vector2.from_angle(cam_ang) * CAM_DIST

func _build_panel() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.position = Vector2(0, VIEW.y); bg.size = Vector2(VIEW.x, 512 - VIEW.y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := UIKit.vbox(3)
	root.position = Vector2(2, VIEW.y + 2)
	root.size = Vector2(VIEW.x - 4, 0)
	add_child(root)
	var mine := ents.filter(func(e): return is_mine(e))
	_rows = [ROWS, ROWS, 4, 3][mini(mine.size(), 3)]
	board = Control.new()
	board.custom_minimum_size = Vector2(VIEW.x - 12, _rows * 11 + 1)
	board.draw.connect(_draw_board)
	root.add_child(UIKit.window(board, "lcd"))
	ticker = Control.new()
	ticker.custom_minimum_size = Vector2(VIEW.x - 12, 21)
	ticker.draw.connect(_draw_ticker)
	root.add_child(UIKit.window(ticker, "lcd"))
	calls = UIKit.vbox(3)
	root.add_child(calls)
	for e in mine: _add_call_row(e, mine.size() > 1)
	var bar := UIKit.hbox(4)
	root.add_child(bar)
	if net_mode != "client":
		speed_btn = UIKit.btn("SPEED x1", _toggle_speed)
		bar.add_child(speed_btn)
	var vol := UIKit.btn("VOL", _toggle_vol, UIKit.BTN_LO)
	vol.size_flags_horizontal = Control.SIZE_FILL
	vol.custom_minimum_size = Vector2(44, 0)
	bar.add_child(vol)
	var skip := UIKit.btn("SKIP" if net_mode == "local" else "LEAVE", _skip, UIKit.BTN_LO)
	bar.add_child(skip)

## Volume panel over the game screen (music / effects / engines), toggled by VOL.
var _vol_panel: Control = null
func _toggle_vol() -> void:
	if _vol_panel and is_instance_valid(_vol_panel):
		_vol_panel.queue_free(); _vol_panel = null
		return
	var box := UIKit.vbox(4)
	box.add_child(UIKit.label("SOUND", UIKit.GOLD, true))
	box.add_child(UIKit.volume_sliders(96))
	box.add_child(UIKit.btn("CLOSE", _toggle_vol, UIKit.BTN_LO))
	_vol_panel = UIKit.window(box)
	_vol_panel.position = Vector2(8, 70)
	_vol_panel.custom_minimum_size = Vector2(VIEW.x - 16, 0)
	add_child(_vol_panel)

const ROWS := 6                 # standings board rows (two columns)
const TAC_COL := {"safe": Color("#2f9a52"), "normal": Color("#3f78e0"), "push": Color("#d8402e")}
const TAC_OFF := Color("#2a3156")
const SPARK_COL := {"b": Color("#a0603a"), "s": Color("#7a8494"), "g": Color("#b8901e")}

## One card per entry this device commands: name + health, tactic switch, sparks, retire.
## Compact (one row) when this device runs more than two entries.
func _add_call_row(e: Dictionary, compact: bool) -> void:
	var box := UIKit.vbox(2)
	var nm := Button.new()
	nm.text = CareerKit.asc(str(e.name)).split(" ")[0].left(9).to_upper()
	nm.flat = true
	nm.focus_mode = Control.FOCUS_NONE
	nm.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nm.clip_text = true
	nm.add_theme_font_override("font", UIKit.font8)
	nm.add_theme_font_size_override("font_size", 8)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: nm.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	nm.pressed.connect(func(): follow_lock = int(e.idx))
	var stat := Control.new()
	stat.custom_minimum_size = Vector2(60, 9)
	stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat.draw.connect(_draw_call_stat.bind(stat, int(e.idx)))
	var tb := {}
	var sp := {}
	var rt := UIKit.btn("RET", call_cmd.bind(int(e.idx), "retire", ""), UIKit.ACCENT)
	if compact:
		# two or three cars: name + health on one line, then S/N/P, sparks and retire in one row
		box.add_theme_constant_override("separation", 1)
		var r0c := UIKit.hbox(4)
		nm.custom_minimum_size = Vector2(70, 0)
		r0c.add_child(nm)
		r0c.add_child(stat)
		box.add_child(r0c)
		var r := UIKit.hbox(2)
		for tc in ["safe", "normal", "push"]:
			var b := UIKit.btn({"safe": "S", "normal": "N", "push": "P"}[tc], call_cmd.bind(int(e.idx), "tactic", tc))
			b.custom_minimum_size = Vector2(24, 0)
			r.add_child(b); tb[tc] = b
		r.add_child(_gap_px(3))
		for k in ["b", "s", "g"]:
			var b2 := UIKit.btn("", call_cmd.bind(int(e.idx), "spark", k), SPARK_COL[k])
			b2.custom_minimum_size = Vector2(30, 0)
			r.add_child(b2); sp[k] = b2
		r.add_child(_gap_px(3))
		rt.custom_minimum_size = Vector2(34, 0)
		r.add_child(rt)
		box.add_child(r)
	else:
		var r0 := UIKit.hbox(4)
		nm.custom_minimum_size = Vector2(70, 0)
		r0.add_child(nm)
		r0.add_child(stat)
		box.add_child(r0)
		var r1 := UIKit.hbox(3)
		for tc in ["safe", "normal", "push"]:
			var b := UIKit.btn({"safe": "SAFE", "normal": "NORMAL", "push": "PUSH"}[tc], call_cmd.bind(int(e.idx), "tactic", tc))
			r1.add_child(b); tb[tc] = b
		box.add_child(r1)
		var r2 := UIKit.hbox(3)
		for k in ["b", "s", "g"]:
			var b2 := UIKit.btn("", call_cmd.bind(int(e.idx), "spark", k), SPARK_COL[k])
			r2.add_child(b2); sp[k] = b2
		rt.text = "RETIRE"
		r2.add_child(rt)
		box.add_child(r2)
	var card := UIKit.window(box, "card")
	if compact: card.add_theme_stylebox_override("panel", UIKit.frame_new("card", 4, 2, 4, 2))
	calls.add_child(card)
	call_widgets[int(e.idx)] = {"tac": tb, "spark": sp, "retire": rt, "stat": stat, "cur": "", "name": nm, "col": Color(e.col).lightened(0.35)}

func _gap_px(w: int) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(w, 0)
	return g

func _draw_call_stat(c: Control, idx: int) -> void:
	var e: Dictionary = ents[idx]
	var w := c.size.x
	# car health and engine condition bars
	var hp := clampf(float(e.get("hp", 1.0)), 0.0, 1.0)
	var cond := clampf(float(e.get("cond", 1.0)), 0.0, 1.0)
	_bar(c, Rect2(0, 0, w * 0.5 - 2, 8), hp, "CAR")
	_bar(c, Rect2(w * 0.5 + 2, 0, w * 0.5 - 2, 8), cond, "ENG")

func _bar(c: Control, r: Rect2, v: float, tag: String) -> void:
	var f := UIKit.font8
	c.draw_rect(r, Color("#050a1c"))
	var col := Color("#3fb34a") if v > 0.6 else (Color("#f2c21e") if v > 0.3 else Color("#e8432f"))
	c.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((r.size.x - 2) * v, r.size.y - 2)), col)
	c.draw_string(f, r.position + Vector2(2, 7), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.7))
	c.draw_string(f, r.position + Vector2(1, 6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

# ---------------- commands ----------------
func is_mine(e: Dictionary) -> bool:
	return e.get("human", false) and int(e.get("owner", 0)) == my_owner

func call_cmd(idx: int, kind: String, arg: String) -> void:
	if net_mode == "client":
		Net.send_cmd(idx, kind, arg)
		return
	apply_cmd(idx, kind, arg, my_owner)

## Host/local: apply a race call if `from_peer` owns the entry.
func apply_cmd(idx: int, kind: String, arg: String, from_peer: int) -> void:
	if sim == null or idx < 0 or idx >= sim.ents.size(): return
	if int(sim.ents[idx].get("owner", -1)) != from_peer: return
	match kind:
		"tactic": sim.set_tactic(idx, arg)
		"spark": sim.use_spark(idx, arg)
		"retire": sim.retire(idx)

func _toggle_speed() -> void:
	set_speed({1.0: 2.0, 2.0: 4.0, 4.0: 1.0}.get(speed, 1.0))

## Set the sim speed (1, 2 or 4) and its button label (career keeps it across stages).
func set_speed(s: float) -> void:
	speed = s
	if speed_btn: speed_btn.text = "SPEED x%d" % int(speed)

func _skip() -> void:
	if net_mode == "client" or net_mode == "host":
		finished.emit({"left": true})
		return
	if sim and not sim.done:
		countdown = 0.0
		sim.run_instant()

# ---------------- network state ----------------
static func snap_of(rs: RaceSim) -> Dictionary:
	var pf := PackedFloat32Array()
	var hum := {}
	var order := PackedByteArray()
	for e in rs.ents:
		var fl := (1 if e.fin else 0) | (2 if e.dnf else 0) | (4 if e.get("retired", false) else 0)
		pf.append_array(PackedFloat32Array([e.prog, e.v, e.get("lat", e.lane), fl, e.get("hp", 1.0), e.boost, e.air, e.crash]))
		if e.human: hum[e.idx] = [e.tactic, e.sparks.b, e.sparks.s, e.sparks.g, e.get("cond", 1.0)]
	for e in rs.order: order.append(e.idx)
	return {"t": rs.t, "e": pf, "h": hum, "o": order, "fl": int(rs.final_lap)}

func apply_snapshot(s: Dictionary) -> void:
	if net_mode != "client": return
	race_t = s.t
	started = true
	countdown = 0.0
	var pf: PackedFloat32Array = s.e
	for i in ents.size():
		var e: Dictionary = ents[i]
		var b := i * 8
		if b + 7 >= pf.size(): break
		e.prog = pf[b]; e.v = pf[b + 1]; e.lat = pf[b + 2]
		var fl := int(pf[b + 3])
		e.fin = fl & 1 != 0; e.dnf = fl & 2 != 0; e.retired = fl & 4 != 0
		e.hp = pf[b + 4]; e.boost = pf[b + 5]; e.air = pf[b + 6]; e.crash = pf[b + 7]
		e.snap_age = 0.0
	for k in s.h:
		var h: Array = s.h[k]
		var e2: Dictionary = ents[int(k)]
		e2.tactic = h[0]; e2.sparks = {"b": h[1], "s": h[2], "g": h[3]}; e2.cond = h[4]
	var o: PackedByteArray = s.o
	for i in o.size(): ents[o[i]].pos = i + 1

func add_msgs(arr: Array) -> void:
	for m in arr: _log(m)

func show_results(res: Dictionary) -> void:
	if ended: return
	ended = true
	finished.emit(res)

# ---------------- frame ----------------
func _process(delta: float) -> void:
	if geo == null: return
	if net_mode != "client":
		if countdown > 0:
			countdown -= delta
		elif not sim.done:
			sim.step(minf(delta, 0.05) * speed)
			started = true
		race_t = sim.t
		while sent_msg < sim.msgs.size():
			var m: Dictionary = sim.msgs[sent_msg]
			sent_msg += 1
			_log(m)
			if net_mode == "host": Net.host_msgs([m])
		if sim.msgs.size() < sent_msg: sent_msg = sim.msgs.size()
		if net_mode == "host":
			snap_acc += delta
			if snap_acc >= 1.0 / SNAP_HZ:
				snap_acc = 0.0
				Net.host_snapshot(snap_of(sim))
		if sim.done and not ended:
			ended = true
			result_cache = {"res": sim.results(), "teams": sim.team_table(), "race_id": def.id, "fmt": fmt, "drag": tr.drag, "tt": sim.tt}
			if net_mode == "host": Net.host_results(result_cache)
			get_tree().create_timer(1.2).timeout.connect(func(): finished.emit(result_cache))
	else:
		if countdown > 0: countdown -= delta
		for e in ents:
			if not e.fin and not e.dnf and started:
				e.snap_age = e.get("snap_age", 0.0) + delta
				e.prog_x = e.prog + e.v * min(e.snap_age, 0.25)
	_update_render(delta)
	_update_hud()
	if not attract: _update_audio(delta)

func sim_tree() -> float:
	return sim.tree if sim else (1.8 if tr.drag else 0.0)

## Lateral offset in lanes from the track centre (sim lanes, so cars keep their own space).
func _lane_off(e: Dictionary) -> float:
	return float(e.get("lat", e.lane)) - (float(tr.get("lanes", 3)) - 1.0) * 0.5

func _update_render(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	for e in ents:
		var target: float = e.get("prog_x", e.prog) if net_mode == "client" else float(e.prog)
		if absf(target - e.rprog) > 3.0: e.rprog = target
		else: e.rprog = lerpf(e.rprog, target, k if net_mode == "client" else 1.0)
	_visual_lanes(delta)
	follow = _pick_follow()
	if follow >= 0:
		var f: Dictionary = ents[follow]
		var s := geo.sample(f.rprog, f.rlane)
		cam_ang = lerp_angle(cam_ang, s.ang, 1.0 - exp(-delta * 5.0))
		# fixed chase distance; only the heading swings (SMK-style)
		cam_pos = s.pos - Vector2.from_angle(cam_ang) * CAM_DIST
	floor_mat.set_shader_parameter("cam_pos", cam_pos)
	floor_mat.set_shader_parameter("cam_ang", cam_ang)
	backdrop.cam_ang = cam_ang
	layer.queue_redraw()

## Cars sit where the sim puts them (lanes are real now); just ease the sprite sideways.
func _visual_lanes(delta: float) -> void:
	for e in ents:
		e.rlane = move_toward(float(e.get("rlane", _lane_off(e))), _lane_off(e), delta * 3.0)
		e.wob = sin(race_t * 9.0 + e.idx) * 0.25 if e.get("crash", 0.0) > 0 else 0.0

func _pick_follow() -> int:
	if follow_lock >= 0 and follow_lock < ents.size() and not ents[follow_lock].dnf: return follow_lock
	for e in ents:
		if is_mine(e) and not e.dnf: return int(e.idx)
	for e in ents:
		if is_mine(e): return int(e.idx)
	var best := -1
	var bp := -INF
	for e in ents:
		if not e.dnf and e.rprog > bp: bp = e.rprog; best = int(e.idx)
	return max(best, 0)

func _update_hud() -> void:
	if attract: return
	var me: Dictionary = ents[follow] if follow >= 0 else {}
	if not me.is_empty() and not tr.drag and int(tr.laps) > 1:
		var lap: int = clampi(int(floor(max(0.0, me.rprog) / tr.lapLen)) + 1, 1, int(tr.laps))
		if lap != _last_lap and _last_lap > 0 and not me.fin:
			_flash = "FINAL LAP" if lap == int(tr.laps) else ("STAGE %d" % lap if tr.p2p else "LAP %d" % lap)
			_flash_t = 1.6
		_last_lap = lap
	_flash_t -= get_process_delta_time()
	if countdown > 0 and not tr.drag:
		banner.text = str(int(ceil(countdown / 0.55)))
	elif race_t < 1.0 and not tr.drag:
		banner.text = "GO!"
	elif not me.is_empty() and me.fin:
		banner.text = "FINISH!"
	elif not me.is_empty() and me.dnf:
		banner.text = "RETIRED" if me.get("retired", false) else "OUT!"
	elif _flash_t > 0.0:
		banner.text = _flash if int(_flash_t * 6.0) % 2 == 0 or _flash_t < 1.0 else ""
	else:
		banner.text = ""
	banner.add_theme_color_override("font_color", UIKit.ACCENT if banner.text == "FINAL LAP" else UIKit.GOLD)
	overlay.queue_redraw()
	board.queue_redraw()
	# race-call cards
	for idx in call_widgets:
		var w: Dictionary = call_widgets[idx]
		var e2: Dictionary = ents[idx]
		var live: bool = not e2.fin and not e2.dnf
		var cur: String = str(e2.get("tactic", "normal"))
		if cur != w.cur:
			w.cur = cur
			for tc in w.tac:
				UIKit.style_btn(w.tac[tc], TAC_COL[tc] if tc == cur else TAC_OFF)
				(w.tac[tc] as Button).add_theme_color_override("font_color", Color.WHITE if tc == cur else UIKit.DIM)
		for tc in w.tac: (w.tac[tc] as Button).disabled = not live
		for k in w.spark:
			var cnt := int(e2.get("sparks", {}).get(k, 0))
			var b2: Button = w.spark[k]
			b2.text = ("%s%d" if w.retire.text == "RET" else "%s x%d") % [{"b": "B", "s": "S", "g": "G"}[k] if w.retire.text == "RET" else {"b": "BRZ", "s": "SLV", "g": "GLD"}[k], cnt]
			b2.disabled = not live or cnt <= 0 or e2.get("boost", 0.0) > 0
		w.retire.disabled = not live
		(w.stat as Control).queue_redraw()
		# the car the camera follows is named in gold (tap a name to follow that car)
		var nb: Button = w.name
		var fc: Color = UIKit.GOLD if int(idx) == follow and call_widgets.size() > 1 else w.col
		for k2 in ["font_color", "font_hover_color", "font_pressed_color"]: nb.add_theme_color_override(k2, fc)

static func ordinal(n: int) -> String:
	if n % 100 >= 11 and n % 100 <= 13: return "TH"
	return {1: "ST", 2: "ND", 3: "RD"}.get(n % 10, "TH")

func _txt(c: CanvasItem, p: Vector2, t: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(UIKit.font8, p + Vector2(1, 1), t, align, width, size, Color(0.03, 0.02, 0.09, 0.9))
	c.draw_string(UIKit.font8, p, t, align, width, size, col)

func _box(c: CanvasItem, r: Rect2, alpha := 0.78) -> void:
	c.draw_rect(r, Color(0.02, 0.03, 0.12, alpha))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(0.75, 0.8, 1.0, 0.55))
	c.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.5))
	c.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Color(0.75, 0.8, 1.0, 0.35))
	c.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), Color(0, 0, 0, 0.5))

## Overlay HUD: position + gap (top left), lap + time (top right), minimap (bottom right), course name.
func _draw_overlay() -> void:
	var c := overlay
	var me: Dictionary = ents[follow] if follow >= 0 else {}
	var n := ents.size()
	# position badge
	_box(c, Rect2(3, 3, 74, 29))
	if not me.is_empty():
		if tr.drag:
			_txt(c, Vector2(8, 22), "LANE", 8, UIKit.DIM)
			_txt(c, Vector2(44, 25), str(int(me.lane) % 2 + 1), 16, UIKit.GOLD)
		elif fmt.get("kind", "") == "tt":
			_txt(c, Vector2(8, 15), "STAGE" if tr.p2p else "TIME TRIAL", 8, UIKit.GOLD)
			var fr := clampf(float(me.rprog) / maxf(float(tr.total), 0.01), 0.0, 1.0)
			c.draw_rect(Rect2(8, 20, 64, 6), Color("#050a1c"))
			c.draw_rect(Rect2(9, 21, 62 * fr, 4), Color("#3fb34a"))
		else:
			var pos := int(me.get("pos", 1))
			var ps := str(pos)
			_txt(c, Vector2(7, 25), ps, 16, UIKit.GOLD if pos <= 3 else UIKit.INK)
			_txt(c, Vector2(7 + 16 * ps.length(), 17), ordinal(pos), 8, UIKit.GOLD if pos <= 3 else UIKit.INK)
			_txt(c, Vector2(7 + 16 * ps.length(), 27), "/%d" % n, 8, UIKit.DIM)
		var gap := _gap_text(me)
		if gap != "":
			_box(c, Rect2(3, 33, 74, 12), 0.5)
			_txt(c, Vector2(6, 42), gap, 8, Color("#9ff0a8") if gap.begins_with("LEAD") else Color("#ffd0a0"))
	# lap + time
	_box(c, Rect2(VIEW.x - 83, 3, 80, 29))
	if not me.is_empty():
		var lap: int = clampi(int(floor(max(0.0, me.rprog) / tr.lapLen)) + 1, 1, int(tr.laps))
		var lt := ("STG %d/%d" if tr.p2p else "LAP %d/%d") % [lap, int(tr.laps)]
		_txt(c, Vector2(VIEW.x - 79, 14), lt, 8, UIKit.ACCENT.lightened(0.3) if lap == int(tr.laps) and int(tr.laps) > 1 else UIKit.INK)
	_txt(c, Vector2(VIEW.x - 79, 27), "%d:%04.1f" % [int(race_t) / 60, fmod(race_t, 60.0)], 8, UIKit.GOLD)
	# course name
	var nm := CareerKit.asc((title_override if title_override != "" else str(def.n)).to_upper())
	var room := int((VIEW.x - MAP.x - 14) / 8.0)
	_txt(c, Vector2(4, VIEW.y - 5), nm.left(room), 8, Color("#d8e4f0"))
	# minimap
	var mr := Rect2(VIEW - MAP - Vector2(3, 3), MAP)
	_box(c, mr, 0.5)
	if _map_pts.size() > 1:
		var pts := PackedVector2Array()
		for q in _map_pts: pts.append(q + mr.position)
		c.draw_polyline(pts, Color(0.1, 0.1, 0.16, 0.9), 3.0)
		c.draw_polyline(pts, Color("#b8c0cc"), 1.0)
		var st: Vector2 = pts[0]
		c.draw_rect(Rect2(st - Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
	for e in ents:
		if e.dnf or is_mine(e): continue
		var p: Vector2 = geo.sample(e.rprog, 0.0).pos * _map_sc + _map_off + mr.position
		c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(e.col))
	for e in ents:
		if e.dnf or not is_mine(e): continue
		var p2: Vector2 = geo.sample(e.rprog, 0.0).pos * _map_sc + _map_off + mr.position
		c.draw_rect(Rect2(p2 - Vector2(2, 2), Vector2(5, 5)), Color.WHITE)
		c.draw_rect(Rect2(p2 - Vector2(1, 1), Vector2(3, 3)), Color(e.col))

## Gap in seconds to the car ahead (or to second place when leading).
func _gap_text(me: Dictionary) -> String:
	if tr.drag or fmt.get("kind", "") == "tt" or me.fin or me.dnf or not started: return ""
	var pos := int(me.get("pos", 1))
	var other: Dictionary = {}
	for e in ents:
		if int(e.get("pos", 0)) == (pos + 1 if pos == 1 else pos - 1): other = e
	if other.is_empty() or other.dnf: return ""
	var v := maxf(float(me.get("v", 0.0)), 0.05)
	var d := absf(float(other.rprog) - float(me.rprog)) / v
	if d > 99.0: return ""
	return ("LEAD +%.1fs" if pos == 1 else "GAP  -%.1fs") % d

func _prep_minimap() -> void:
	var r := geo.bbox.grow(-(geo.width * 0.5 + 200.0) + geo.width * 0.5)
	_map_sc = minf((MAP.x - 10) / maxf(r.size.x, 1.0), (MAP.y - 10) / maxf(r.size.y, 1.0))
	_map_off = (MAP - r.size * _map_sc) * 0.5 - r.position * _map_sc
	_map_pts = PackedVector2Array()
	for i in range(0, geo.pts.size(), 6): _map_pts.append(geo.pts[i] * _map_sc + _map_off)
	if geo.closed and _map_pts.size() > 0: _map_pts.append(_map_pts[0])

## Standings board: two columns of chips (position, team colour, name, status); your entries in gold.
func _draw_board() -> void:
	var c := board
	var ord := ents.duplicate()
	ord.sort_custom(func(a, b): return int(a.get("pos", 99)) < int(b.get("pos", 99)))
	var slots := _rows * 2
	var show := ord.slice(0, slots)
	var missing := ord.slice(slots).filter(func(e): return is_mine(e))
	var k := show.size() - 1
	for e in missing:
		while k >= 0 and is_mine(show[k]): k -= 1
		if k < 0: break
		show[k] = e; k -= 1
	var cw := (c.size.x - 4) * 0.5
	for i in show.size():
		var e: Dictionary = show[i]
		var col := i / _rows
		var row := i % _rows
		var p := Vector2(col * (cw + 4), row * 11)
		var mine := is_mine(e)
		if mine: c.draw_rect(Rect2(p, Vector2(cw, 11)), Color(1.0, 0.85, 0.3, 0.18))
		var dim := bool(e.dnf)
		_txt(c, p + Vector2(0, 9), "%2d" % int(e.get("pos", 0)), 8, UIKit.GOLD if mine else (UIKit.DIM if dim else UIKit.INK))
		c.draw_rect(Rect2(p + Vector2(18, 2), Vector2(6, 7)), Color(e.col).darkened(0.5 if dim else 0.0))
		c.draw_rect(Rect2(p + Vector2(18, 2), Vector2(6, 1)), Color(e.col).lightened(0.4))
		var nm := CareerKit.asc(str(e.name).split(" ")[0] if e.human else str(e.team)).to_upper()
		_txt(c, p + Vector2(27, 9), nm.left(int((cw - 38) / 8.0)), 8, (Color(e.col).lightened(0.45) if mine else (UIKit.DIM if dim else Color("#c8d0e8"))))
		var tag := "X" if e.dnf else ("F" if e.fin else "")
		if tag != "": _txt(c, p + Vector2(cw - 9, 9), tag, 8, Color("#e8432f") if e.dnf else Color("#3fb34a"))
		if mine:
			c.draw_rect(Rect2(p, Vector2(cw, 1)), UIKit.GOLD); c.draw_rect(Rect2(p + Vector2(0, 10), Vector2(cw, 1)), UIKit.GOLD)

func _log(m: Dictionary) -> void:
	if attract: return
	var ent := int(m.get("ent", -1))
	if ent >= 0 and ent < ents.size() and not is_mine(ents[ent]): return
	log_lines.append(CareerKit.asc(str(m.text)))
	while log_lines.size() > 2: log_lines.pop_front()
	if ticker: ticker.queue_redraw()

## Commentary: the newest call wrapped over two lines, the one before it dimmed above.
func _draw_ticker() -> void:
	var c := ticker
	var cols := int(c.size.x / 8.0)
	if log_lines.is_empty(): return
	var newest: String = log_lines[log_lines.size() - 1]
	var lines := _wrap(newest, cols)
	if lines.size() < 2 and log_lines.size() > 1:
		_txt(c, Vector2(0, 8), str(log_lines[0]).left(cols), 8, UIKit.DIM)
		_txt(c, Vector2(0, 19), lines[0], 8, Color.WHITE)
	else:
		for i in mini(2, lines.size()): _txt(c, Vector2(0, 8 + i * 11), lines[i], 8, Color.WHITE)

static func _wrap(t: String, cols: int) -> Array:
	var out := []
	var line := ""
	for w in t.split(" "):
		if line == "": line = w
		elif line.length() + 1 + w.length() <= cols: line += " " + w
		else: out.append(line.left(cols)); line = w
	if line != "": out.append(line.left(cols))
	if out.size() > 2:
		out = out.slice(0, 2)
		out[1] = (out[1] as String).left(cols - 2) + ".."
	return out

# ---------------- audio: engines, race SFX, music ----------------
func _setup_audio() -> void:
	var T0 := 9.0 if tr.drag else clampf(float(tr.total) * 0.8, 24.0, 90.0)
	_kref = float(tr.total) / T0
	for i in 3:
		var n := EngineAudio.new()
		add_child(n)
		_eng.append({"node": n, "rev": RevModel.new(), "idx": -1})
	var dirt := not (RaceSim.main_surf(tr) in ["tar", "wet"])
	var rival := false
	for e in ents:
		var ref = e.get("ref")
		if bool(e.get("dynasty", false)) or (ref is Dictionary and bool(ref.get("dynasty", false))): rival = true
	Audio.music("rival" if rival else ("race_dirt" if dirt else "race"))

const BIKE_KINDS := ["commuter", "scooter", "naked", "sport", "cafe", "super", "gp", "sidecar", "trail", "mx", "enduro", "flat", "smoto", "raid"]

func _voice_of(e: Dictionary) -> Array:
	var v := str(e.get("voice", ""))
	var ex := str(e.get("exh", ""))
	if v == "":
		var bike: bool = e.get("cls", "") == "bike" or BIKE_KINDS.has(str(e.kind))
		v = EngineAudio.voice_for_kind(str(e.kind), "bike" if bike else "car")
	if ex == "":
		var tier := int(def.get("tier", 1))
		ex = "race" if tier >= 3 else ("sport" if tier == 2 else "stock")
	return [v, ex]

func _update_audio(delta: float) -> void:
	if _eng.is_empty() or follow < 0: return
	_eng_t -= delta
	if _eng_t <= 0.0:
		_eng_t = 0.4
		var f: Dictionary = ents[follow]
		var near := []
		for e in ents:
			if int(e.idx) == follow or e.dnf: continue
			var d := absf(float(e.rprog) - float(f.rprog))
			if not tr.p2p and not tr.drag: d = minf(d, float(tr.lapLen) - fposmod(d, float(tr.lapLen)))
			near.append([d, int(e.idx)])
		near.sort_custom(func(a, b): return a[0] < b[0])
		var want := [follow] + near.slice(0, 2).map(func(x): return x[1])
		for i in _eng.size():
			var slot: Dictionary = _eng[i]
			var idx: int = want[i] if i < want.size() else -1
			if idx != slot.idx:
				slot.idx = idx
				if idx < 0: (slot.node as EngineAudio).silence(); continue
				var vx := _voice_of(ents[idx])
				var node: EngineAudio = slot.node
				node.setup(vx[0], vx[1])
				(slot.rev as RevModel).setup(node.idle_rpm(), node.red_rpm(), ents[idx].get("cls", "") == "bike" or BIKE_KINDS.has(str(ents[idx].kind)))
	var me: Dictionary = ents[follow]
	for i in _eng.size():
		var slot: Dictionary = _eng[i]
		if slot.idx < 0: continue
		var e: Dictionary = ents[slot.idx]
		var rev: RevModel = slot.rev
		var go_on: bool = started and countdown <= 0.0 and not (tr.drag and race_t < sim_tree())
		rev.step(delta, clampf(float(e.get("v", 0.0)) / (_kref * 1.35), 0.0, 1.0), go_on, bool(e.fin) or bool(e.dnf), float(e.get("boost", 0.0)) > 0.0)
		var node: EngineAudio = slot.node
		node.rpm = rev.rpm
		node.throttle = rev.throttle
		if i == 0: node.gain_db = 0.0
		else:
			var dw: float = absf(geo.px_of(float(e.rprog)) - geo.px_of(float(me.rprog)))
			node.gain_db = -5.0 - 18.0 * log(maxf(dw, 30.0) / 30.0) / log(10.0)
	# race SFX for this device's entries
	var cd := int(ceil(countdown / 0.55)) if countdown > 0 else 0
	if cd != _cd_last and cd > 0: Audio.sfx("beep")
	_cd_last = cd
	if started and not _went and countdown <= 0.0:
		_went = true; Audio.sfx("go")
	for e in ents:
		if not is_mine(e): continue
		var k := int(e.idx)
		var sn: Dictionary = _seen.get(k, {"crash": 0.0, "boost": 0.0, "fin": false})
		if float(e.get("crash", 0.0)) > sn.crash + 0.05: Audio.sfx("crash" if float(e.crash) >= 1.0 else "bump")
		if float(e.get("boost", 0.0)) > 0.0 and sn.boost <= 0.0: Audio.sfx("spark")
		if bool(e.fin) and not sn.fin: Audio.sfx("crowd", -4.0)
		_seen[k] = {"crash": float(e.get("crash", 0.0)), "boost": float(e.get("boost", 0.0)), "fin": bool(e.fin)}
