class_name EndingScene
extends Control
## The ending: sunset over Tinplate (spark-plug water tower and all), your best machine on the top step
## of the podium in team colours under the Cup, confetti. Plays the ending dialogue, rolls the credits,
## then the epilogue, then emits finished(scene_id). Free play continues afterwards.

signal choice_made(choice: Dictionary)
signal finished(scene_id: String)

const CUP_Y := 176.0
const FRAME := 6          # vehicle sheet yaw frame used on the podium (front three-quarter, headlights on show)

var sc := {}
var team := "Team Tinplate"
var team_col := Color("#e8432f")
var machine_kind := "hatch"
var credits_info := {}
var phase := ""

var _stage: Stage
var _car: TextureRect
var _cup: TextureRect
var _banner: Label
var _box: DialogueBox
var _credits: CreditsRoll
var _t := 0.0

static var _cup_tex: Texture2D

## Sky, town, podium and confetti, drawn in code with SNES-snapped colours.
class Stage extends Control:
	var bits: Array = []
	var t := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func c(h: String) -> Color:
		return SpriteForge.snes(Color(h))
	func _draw() -> void:
		var w := size.x
		var horizon := 300.0
		var sky := ["#1a1046", "#2a1858", "#4a2068", "#7a2c6a", "#b8445a", "#e0684a", "#f29a4a", "#ffc86a"]
		for i in sky.size():
			var y0 := floorf(horizon * i / sky.size()); var y1 := floorf(horizon * (i + 1) / sky.size())
			draw_rect(Rect2(0, y0, w, y1 - y0), c(sky[i]))
		var rng := RandomNumberGenerator.new(); rng.seed = 1204
		for i in 40:
			var p := Vector2(rng.randi_range(0, int(w)), rng.randi_range(0, 110))
			if fmod(t * 1.3 + i * 0.37, 2.0) > 0.4: draw_rect(Rect2(p, Vector2(1, 1)), c("#fff2b8"))
		for r in range(26, 0, -2):     # setting sun
			draw_rect(Rect2(w * 0.3 - r, horizon - sqrt(26.0 * 26.0 - (26 - r) * (26 - r)) + 2, r * 2, 2), c("#ffe08a"))
		var town := c("#2a1840")
		var hs := [18, 26, 14, 34, 22, 16, 30, 20, 12, 24, 28, 16, 20]
		var x := 0.0
		for i in hs.size():
			var bw := w / hs.size()
			draw_rect(Rect2(x, horizon - hs[i], bw + 1, hs[i]), town)
			if i % 3 == 1: draw_rect(Rect2(x + 4, horizon - hs[i] + 6, 2, 2), c("#ffd84a"))
			x += bw
		# the spark-plug water tower
		var tx := w * 0.74
		for lx in [-10.0, -4.0, 4.0, 10.0]: draw_rect(Rect2(tx + lx, horizon - 52, 2, 52), town)
		draw_rect(Rect2(tx - 14, horizon - 76, 30, 24), town)
		draw_rect(Rect2(tx - 12, horizon - 74, 26, 2), c("#4a2c60"))
		draw_rect(Rect2(tx - 8, horizon - 82, 18, 6), town)       # hex nut
		draw_rect(Rect2(tx - 4, horizon - 100, 10, 18), town)     # ceramic insulator
		draw_rect(Rect2(tx - 2, horizon - 98, 2, 14), c("#4a2c60"))
		draw_rect(Rect2(tx - 1, horizon - 106, 4, 6), town)       # terminal
		# ground, crowd, podium
		draw_rect(Rect2(0, horizon, w, size.y - horizon), c("#2f6a3a"))
		draw_rect(Rect2(0, horizon, w, 6), c("#3f8a4a"))
		var crowd := RandomNumberGenerator.new(); crowd.seed = 77
		for i in 64:
			var cx := float(crowd.randi_range(0, int(w)))
			var cy := horizon + 10 + crowd.randi_range(0, 30) + (2 if fmod(t * 4.0 + i, 2.0) > 1.0 else 0)
			draw_rect(Rect2(cx, cy, 3, 3), c("#f1c9a0"))
			draw_rect(Rect2(cx - 1, cy + 3, 5, 5), Color.from_hsv(crowd.randf(), 0.6, 0.85))
		var steps := [[24.0, 80.0, 380.0, "2"], [80.0, 176.0, 356.0, "1"], [176.0, 232.0, 392.0, "3"]]
		for s in steps:
			var r := Rect2(s[0], s[2], s[1] - s[0], 452.0 - s[2])
			draw_rect(r.grow(1), c("#140c24"))
			draw_rect(r, c("#e8e0d0"))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), c("#ffffff"))
			draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), c("#a89e8e"))
			draw_string(UIKit.font8, Vector2(r.get_center().x - 4, r.position.y + 16), s[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c("#6a3fb5"))
		for b in bits:
			draw_rect(Rect2(b.p.round(), Vector2(2, 2)), b.c)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()

## Pull the team, its best machine (highest level), the cast and the machine list from the story/career.
func setup_from_story(story: Node) -> void:
	team = story.team_name()
	team_col = story.team_color()
	var g: Dictionary = story._g()
	var best := -1
	var names := []
	for v in g.get("vehicles", []):
		names.append(str(v.get("name", "")))
		if int(v.get("lv", 1)) > best:
			best = int(v.get("lv", 1))
			machine_kind = str(Data.body(str(v.get("body", ""))).get("kind", "hatch"))
	var crew := ["hazel", "rosie", "dewey", "barb", "walt"]
	if story.flag("midge_joined"): crew.append("midge")
	credits_info = {"team": team, "machines": names, "crew": crew, "rivals": ["victoria", "preston", "silas"], "chars": story.chars}

func play(scene: Dictionary) -> void:
	sc = scene
	if credits_info.is_empty():
		credits_info = {"team": team, "machines": [], "crew": ["hazel", "rosie", "dewey", "barb", "walt"], "rivals": ["victoria", "preston", "silas"]}
	_build_stage()
	_go("podium")

func _build_stage() -> void:
	_stage = Stage.new()
	add_child(_stage)
	_banner = UIKit.title("CROWNWELL CUP")
	_banner.position = Vector2(0, 18)
	_banner.size = Vector2(size.x, 20)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var champ := UIKit.label(team.to_upper() + " WINS!", Color.WHITE, true)
	champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	champ.position = Vector2(0, 42)
	champ.size = Vector2(size.x, 10)
	champ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(champ)
	_car = TextureRect.new()
	_car.texture = machine_tex(machine_kind, team_col)
	_car.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car.stretch_mode = TextureRect.STRETCH_SCALE
	_car.size = Vector2(96, 96)
	_car.position = Vector2(roundf(size.x / 2.0 - 48), 356 - 96 + 10)
	_car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_car)
	_cup = TextureRect.new()
	_cup.texture = cup_tex()
	_cup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cup.stretch_mode = TextureRect.STRETCH_SCALE
	_cup.size = Vector2(80, 80)
	_cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cup.position = Vector2(roundf(size.x / 2.0 - 40), CUP_Y)
	add_child(_cup)
	for i in 70:
		_stage.bits.append({"p": Vector2(randf() * size.x, -randf() * 400), "v": randf_range(24, 52), "s": randf() * TAU,
			"c": SpriteForge.snes([team_col, UIKit.GOLD, Color.WHITE, UIKit.ACCENT, Color("#3fb3e8")][i % 5])})

## One yaw frame of a vehicle sheet in team colours (same pipeline as the race sprites).
static func machine_tex(kind: String, col: Color) -> Texture2D:
	var sheet := SpriteForge.colorize_sd(SpriteForge.vehicle_tex(kind).get_image(), col)
	var at := AtlasTexture.new()
	at.atlas = ImageTexture.create_from_image(sheet)
	at.region = Rect2(FRAME * SpriteForge.VCELL.x, 0, SpriteForge.VCELL.x, SpriteForge.VCELL.y)
	return at

## The Cup itself: SDF primitives, gold glossy ramp, rendered like the trackside props.
static func cup_tex() -> Texture2D:
	if _cup_tex: return _cup_tex
	var M := SpriteForge.M
	var P := [SDModels.cylz(Vector3(0, 0, 2), 8.0, 2.0, M.TRIM, 0.8), SDModels.cylz(Vector3(0, 0, 5.5), 5.5, 1.6, M.TRIM, 0.6),
		SDModels.cylz(Vector3(0, 0, 10), 1.8, 3.5, M.LIGHT, 0.6), SDModels.ell(Vector3(0, 0, 13.5), Vector3(3.5, 3.5, 1.6), M.LIGHT),
		SDModels.ell(Vector3(0, 0, 22), Vector3(8.5, 8.5, 8.0), M.LIGHT), SDModels.cylz(Vector3(0, 0, 28.5), 9.0, 1.3, M.LIGHT, 0.6),
		SDModels.rbox(Vector3(-8.2, 0, 21), Vector3(0.6, 3.0, 2.2), 0.3, M.PLATE, true)]
	for s in [-1.0, 1.0]:
		P.append(SDModels.cap(Vector3(0, s * 8.0, 26), Vector3(0, s * 13.0, 22), 1.4, M.LIGHT))
		P.append(SDModels.cap(Vector3(0, s * 13.0, 22), Vector3(0, s * 7.5, 16), 1.4, M.LIGHT))
	var idx := SpriteForge.render_sd(SDModels.voxelize(P), Vector2.ZERO, 1, Vector2i(40, 40), 1, 0.3)
	_cup_tex = ImageTexture.create_from_image(SpriteForge.colorize_sd(idx, Color.WHITE))
	return _cup_tex

func _go(p: String) -> void:
	phase = p
	if _box and is_instance_valid(_box): _box.queue_free()
	_box = null
	match p:
		"podium", "epilogue":
			if _credits and is_instance_valid(_credits): _credits.queue_free()
			_credits = null
			var lines: Array = sc.get("lines" if p == "podium" else "epilogue", [])
			if lines.is_empty():
				_after_dialogue("")
				return
			_box = DialogueBox.new()
			_box.dim = false
			add_child(_box)
			_box.choice_made.connect(_relay_choice)
			_box.finished.connect(_after_dialogue)
			_box.play({"id": str(sc.get("id", "")) + ":" + p, "lines": lines})
		"credits":
			_credits = CreditsRoll.new()
			_credits.setup(credits_info)
			add_child(_credits)
			_credits.finished.connect(_go.bind("epilogue"))
		"done":
			finished.emit(str(sc.get("id", "")))

func _relay_choice(c: Dictionary) -> void:
	choice_made.emit(c)

func _after_dialogue(_id: String) -> void:
	_go("credits" if phase == "podium" else "done")

## Current dialogue box (podium or epilogue phase), for tests and skip buttons.
func box() -> DialogueBox: return _box
func credits() -> CreditsRoll: return _credits

func _process(delta: float) -> void:
	if _stage == null: return
	_t += delta
	_stage.t = _t
	for b in _stage.bits:
		b.p.y += b.v * delta
		b.p.x += sin(_t * 3.0 + b.s) * 12.0 * delta
		if b.p.y > 460: b.p = Vector2(randf() * size.x, -4.0)
	if _cup: _cup.position.y = CUP_Y + roundf(sin(_t * 2.0) * 2.0) * 2
	_stage.queue_redraw()
