class_name RaceView
extends Control
## SNES-style race screen. Top: 256x224 Mode 7 view (sky/parallax, perspective floor, scaled sprites).
## Bottom: minimap, standings, commentary and race calls for the entries this device owns.
## Runs the sim itself (local / LAN host) or renders host snapshots (LAN client).

signal finished(result: Dictionary)

const VIEW := Vector2(256, 224)
const HORIZON := 70.0
const FOCAL := 128.0
const CAM_H := 40.0
const CAM_DIST := 66.0
const FOG_FAR := 1100.0
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
var hud_pos: Label
var hud_lap: Label
var hud_time: Label
var banner: Label
var minimap: Control
var standings: VBoxContainer
var log_box: VBoxContainer
var calls: VBoxContainer
var speed_btn: Button
var call_widgets := {}
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
	hud_pos = _hud_label(Vector2(4, 4), 16, UIKit.GOLD)
	hud_lap = _hud_label(Vector2(150, 4), 8, Color.WHITE)
	hud_time = _hud_label(Vector2(150, 16), 8, Color.WHITE)
	banner = _hud_label(Vector2(0, 92), 16, UIKit.GOLD)
	banner.size = Vector2(VIEW.x, 24)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tl := UIKit.label((title_override if title_override != "" else str(def.n)).to_upper(), Color("#d8e4f0"), true)
	tl.position = Vector2(4, VIEW.y - 12); tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.add_theme_color_override("font_outline_color", Color("#140c24")); tl.add_theme_constant_override("outline_size", 3)
	screen.add_child(tl)
	if attract:
		for l in [hud_pos, hud_lap, hud_time, banner]: l.visible = false
		countdown = 0.0
	else:
		_build_panel()
		_setup_audio()
	follow = _pick_follow()
	var e0: Dictionary = ents[max(0, follow)]
	var s0 := geo.sample(e0.rprog, e0.rlane)
	cam_ang = s0.ang
	cam_pos = s0.pos - Vector2.from_angle(cam_ang) * CAM_DIST

func _hud_label(p: Vector2, size: int, c: Color) -> Label:
	var l := Label.new()
	l.position = p
	l.add_theme_font_override("font", UIKit.font8)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color("#140c24"))
	l.add_theme_constant_override("outline_size", 4)
	screen.add_child(l)
	return l

func _build_panel() -> void:
	var root := UIKit.vbox(3)
	root.position = Vector2(2, VIEW.y + 2)
	root.size = Vector2(VIEW.x - 4, 0)
	add_child(root)
	var top := UIKit.hbox(4)
	root.add_child(top)
	minimap = Control.new()
	minimap.custom_minimum_size = Vector2(92, 92)
	minimap.draw.connect(_draw_minimap)
	top.add_child(UIKit.panel(minimap, Color("#0f1736")))
	standings = UIKit.vbox(0)
	standings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(standings)
	for i in 8:
		var l := UIKit.label("", Color.WHITE, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.custom_minimum_size = Vector2(150, 10)
		standings.add_child(l)
	log_box = UIKit.vbox(0)
	log_box.custom_minimum_size = Vector2(0, 52)
	root.add_child(UIKit.panel(log_box, Color("#0f1736")))
	for i in 3:
		var l2 := UIKit.label("", UIKit.DIM)
		l2.autowrap_mode = TextServer.AUTOWRAP_OFF
		l2.clip_text = true
		l2.custom_minimum_size = Vector2(240, 0)
		log_box.add_child(l2)
	calls = UIKit.vbox(3)
	root.add_child(calls)
	for e in ents:
		if e.human and is_mine(e): _add_call_row(e)
	var bar := UIKit.hbox(4)
	root.add_child(bar)
	if net_mode != "client":
		speed_btn = UIKit.btn("SPEED x1", _toggle_speed)
		bar.add_child(speed_btn)
	var skip := UIKit.btn("SKIP" if net_mode == "local" else "LEAVE", _skip, UIKit.BTN_LO)
	bar.add_child(skip)

func _add_call_row(e: Dictionary) -> void:
	var box := UIKit.vbox(2)
	var r1 := UIKit.hbox(3)
	var nm := UIKit.label(e.name.split(" ")[0], Color(e.col).lightened(0.3))
	nm.custom_minimum_size = Vector2(52, 0)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	r1.add_child(nm)
	var tb := {}
	for tc in ["safe", "normal", "push"]:
		var b := UIKit.btn({"safe": "SAFE", "normal": "NORM", "push": "PUSH"}[tc], call_cmd.bind(int(e.idx), "tactic", tc))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r1.add_child(b)
		tb[tc] = b
	box.add_child(r1)
	var r2 := UIKit.hbox(3)
	var sp := {}
	for k in ["b", "s", "g"]:
		var b2 := UIKit.btn("", call_cmd.bind(int(e.idx), "spark", k), {"b": Color("#a0603a"), "s": Color("#7a8494"), "g": Color("#b8901e")}[k])
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r2.add_child(b2)
		sp[k] = b2
	var rt := UIKit.btn("RETIRE", call_cmd.bind(int(e.idx), "retire", ""), UIKit.ACCENT)
	r2.add_child(rt)
	box.add_child(r2)
	calls.add_child(box)
	call_widgets[int(e.idx)] = {"tac": tb, "spark": sp, "retire": rt}

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
	if minimap: minimap.queue_redraw()

## Cars sit where the sim puts them (lanes are real now); just ease the sprite sideways.
func _visual_lanes(delta: float) -> void:
	for e in ents:
		e.rlane = move_toward(float(e.get("rlane", _lane_off(e))), _lane_off(e), delta * 3.0)
		e.wob = sin(race_t * 9.0 + e.idx) * 0.25 if e.get("crash", 0.0) > 0 else 0.0

func _pick_follow() -> int:
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
	var n := ents.size()
	if not me.is_empty():
		if tr.drag:
			hud_pos.text = "LANE %d" % (int(me.lane) % 2 + 1)
		elif fmt.get("kind", "") == "tt":
			hud_pos.text = "STAGE" if tr.p2p else "TIME"
		else:
			hud_pos.text = "P%d/%d" % [int(me.get("pos", 1)), n]
		var lap: int = clampi(int(floor(max(0.0, me.rprog) / tr.lapLen)) + 1, 1, int(tr.laps))
		hud_lap.text = ("STAGE %d/%d" if tr.p2p else "LAP %d/%d") % [lap, int(tr.laps)]
	hud_time.text = "%d:%04.1f" % [int(race_t) / 60, fmod(race_t, 60.0)]
	if countdown > 0 and not tr.drag:
		banner.text = str(int(ceil(countdown / 0.55)))
	elif race_t < 1.0 and not tr.drag:
		banner.text = "GO!"
	elif not me.is_empty() and me.fin:
		banner.text = "FINISH!"
	elif not me.is_empty() and me.dnf:
		banner.text = "RETIRED" if me.get("retired", false) else "OUT!"
	else:
		banner.text = ""
	# standings (top 6 + me)
	var ord := ents.duplicate()
	ord.sort_custom(func(a, b): return int(a.get("pos", 99)) < int(b.get("pos", 99)))
	var labels := standings.get_children()
	var shown := 0
	for e in ord:
		if shown >= 8: break
		if shown >= 6 and not is_mine(e): continue
		var tag := "%d %s" % [int(e.get("pos", 0)), e.team if not e.human else e.name.split(" ")[0]]
		if e.dnf: tag += " x"
		elif e.fin: tag += " F"
		var l: Label = labels[shown]
		l.text = tag
		l.add_theme_color_override("font_color", Color(e.col).lightened(0.35) if e.human else Color("#c8d0e8"))
		shown += 1
	for i in range(shown, labels.size()): labels[i].text = ""
	# race-call buttons
	for idx in call_widgets:
		var w: Dictionary = call_widgets[idx]
		var e2: Dictionary = ents[idx]
		var live: bool = not e2.fin and not e2.dnf
		for tc in w.tac:
			var b: Button = w.tac[tc]
			b.disabled = not live
			b.modulate = Color.WHITE if e2.get("tactic", "normal") == tc else Color(0.6, 0.6, 0.7)
		for k in w.spark:
			var cnt := int(e2.get("sparks", {}).get(k, 0))
			var b2: Button = w.spark[k]
			b2.text = "%s%d" % [{"b": "BRZ ", "s": "SLV ", "g": "GLD "}[k], cnt]
			b2.disabled = not live or cnt <= 0 or e2.get("boost", 0.0) > 0
		w.retire.disabled = not live

func _log(m: Dictionary) -> void:
	if attract: return
	var ent := int(m.get("ent", -1))
	if ent >= 0 and ent < ents.size() and not is_mine(ents[ent]): return
	log_lines.append(m.text)
	while log_lines.size() > 3: log_lines.pop_front()
	var labels := log_box.get_children()
	for i in labels.size():
		var l: Label = labels[i]
		l.text = log_lines[i] if i < log_lines.size() else ""
		l.add_theme_color_override("font_color", Color.WHITE if i == log_lines.size() - 1 else UIKit.DIM)

func _draw_minimap() -> void:
	var box := Vector2(92, 92)
	var r := geo.bbox.grow(-140)
	var sc: float = min((box.x - 8) / max(r.size.x, 1.0), (box.y - 8) / max(r.size.y, 1.0))
	var off := (box - r.size * sc) * 0.5 - r.position * sc
	var pts := PackedVector2Array()
	for i in range(0, geo.pts.size(), 6): pts.append(geo.pts[i] * sc + off)
	if geo.closed and pts.size() > 0: pts.append(pts[0])
	minimap.draw_polyline(pts, Color("#5d5f68"), 3.0)
	minimap.draw_polyline(pts, Color("#9aa2ad"), 1.0)
	for e in ents:
		if e.dnf: continue
		var p: Vector2 = geo.sample(e.rprog, 0.0).pos * sc + off
		var big := is_mine(e)
		minimap.draw_rect(Rect2(p - Vector2(2, 2) if big else p - Vector2(1, 1), Vector2(4, 4) if big else Vector2(3, 3)), Color(e.col) if not big else Color.WHITE)
		if big: minimap.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(e.col))

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
			var dw: float = absf(float(e.rprog) - float(me.rprog)) * geo.unit
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
