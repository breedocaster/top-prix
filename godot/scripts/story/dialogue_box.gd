class_name DialogueBox
extends Control
## SNES-RPG dialogue window for the 256 px wide portrait screen. Add it to any Control (it fills its
## parent and swallows taps) or let Story.present() put it on an overlay layer.
##   play({id, lines: [{who, expr, text, name, col, side, choices?}], card?: {top, title, sub}})
## Bordered gradient window, 48x48 portrait in its own frame (allies left, rivals right and mirrored),
## name plate, typewriter text (tap: finish the line, tap again: next), 2-3 choice buttons, chapter cards.
## Long lines are paginated into 3-row boxes. Emits choice_made(choice) and finished(scene_id).

signal line_started(index: int)
signal choice_made(choice: Dictionary)
signal finished(scene_id: String)

const COLS := 28           # 8 px glyphs: 28 x 8 = 224 px of text
const ROWS := 3
const CHOICE_COLS := 20
const LINE_H := 18
const CHOICE_H := 24        # button rows: DotGothic16 is 24 px tall
const WIN_H := 74
const PORT := 48
const CPS := 45.0

const OUTLINE := Color("#140c24")
const EDGE := Color("#f2f2ee")
const EDGE2 := Color("#8a96b8")
const TOP := Color("#2c3f9e")
const BOTTOM := Color("#0e1748")
const NARRATOR := Color("#c8d8ff")

var scene_id := ""
var lines: Array = []
var idx := -1
var cps := CPS
var dim := true
var typing := false

var _shown := 0.0
var _total := 0
var _waiting := false
var _sel := 0
var _blink := 0.0
var _card_up := false
var _done := false

var _shade: ColorRect
var _win: Frame
var _text: Label
var _pframe: Frame
var _port: TextureRect
var _plate: Frame
var _name: Label
var _cwin: Frame
var _cbox: VBoxContainer
var _arrow: Arrow
var _card: Frame

## A window frame drawn the SNES way: dark outline, light double border, banded gradient fill.
class Frame extends Control:
	var top := TOP
	var bottom := BOTTOM
	var bands := 6
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), OUTLINE)
		draw_rect(Rect2(1, 1, w - 2, h - 2), EDGE)
		draw_rect(Rect2(3, 3, w - 6, h - 6), EDGE2)
		var inner := Rect2(4, 4, w - 8, h - 8)
		var n := maxi(1, mini(bands, int(inner.size.y / 2)))
		for i in n:
			var y0 := inner.position.y + floorf(inner.size.y * i / n)
			var y1 := inner.position.y + floorf(inner.size.y * (i + 1) / n)
			draw_rect(Rect2(inner.position.x, y0, inner.size.x, y1 - y0), SpriteForge.snes(top.lerp(bottom, float(i) / maxf(1, n - 1))))

## Blinking "next" triangle.
class Arrow extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(8, 5)
		size = Vector2(8, 5)
	func _draw() -> void:
		for r in 4:
			draw_rect(Rect2(r, r, 7 - 2 * r, 1), EDGE)
		draw_rect(Rect2(3, 4, 1, 1), EDGE2)

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()

func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()

func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.03, 0.02, 0.08, 0.35)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_win = Frame.new()
	add_child(_win)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", UIKit.font)
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_constant_override("line_spacing", LINE_H - 24)
	_text.add_theme_color_override("font_shadow_color", OUTLINE)
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.visible_characters_behavior = TextServer.VC_CHARS_BEFORE_SHAPING
	_win.add_child(_text)
	_arrow = Arrow.new()
	_win.add_child(_arrow)
	_pframe = Frame.new()
	_pframe.bands = 4
	add_child(_pframe)
	_port = TextureRect.new()
	_port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_port.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_port.stretch_mode = TextureRect.STRETCH_KEEP
	_port.size = Vector2(PORT, PORT)
	_pframe.add_child(_port)
	_plate = Frame.new()
	_plate.bands = 2
	add_child(_plate)
	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_override("font", UIKit.font8)
	_name.add_theme_font_size_override("font_size", 8)
	_name.add_theme_color_override("font_shadow_color", OUTLINE)
	_name.add_theme_constant_override("shadow_offset_x", 1)
	_name.add_theme_constant_override("shadow_offset_y", 1)
	_plate.add_child(_name)
	_cwin = Frame.new()
	_cwin.visible = false
	add_child(_cwin)
	_cbox = VBoxContainer.new()
	_cbox.add_theme_constant_override("separation", 0)
	_cwin.add_child(_cbox)
	_card = Frame.new()
	_card.visible = false
	_card.top = Color("#3a2a7a")
	_card.bottom = Color("#120c30")
	add_child(_card)

func _layout() -> void:
	if _win == null: return
	var W := size.x; var H := size.y
	_shade.position = Vector2.ZERO
	_shade.size = size
	_win.position = Vector2(4, H - 4 - WIN_H)
	_win.size = Vector2(W - 8, WIN_H)
	_text.position = Vector2(10, 7)
	_text.size = Vector2(W - 28, LINE_H * ROWS + 6)
	_arrow.position = Vector2(W - 8 - 16, WIN_H - 11)
	_place_speaker()
	_place_choices()
	_card.size = Vector2(minf(W - 24, 216), 70)
	_card.position = Vector2(roundf((W - _card.size.x) / 2.0), roundf(H * 0.36))

func _cur() -> Dictionary:
	return lines[idx] if idx >= 0 and idx < lines.size() else {}

func _rival() -> bool:
	return str(_cur().get("side", "ally")) == "rival"

func _place_speaker() -> void:
	var W := size.x
	var wy := _win.position.y
	var right := _rival()
	_pframe.size = Vector2(PORT + 4, PORT + 4)
	_pframe.position = Vector2(W - 8 - _pframe.size.x if right else 8.0, wy - PORT - 2)
	_port.position = Vector2(2, 2)
	var nw := maxf(40.0, _name.text.length() * 8 + 12)
	_plate.size = Vector2(nw, 15)
	var px: float = (_pframe.position.x - 2 - nw) if right else (_pframe.position.x + _pframe.size.x + 2)
	if not _pframe.visible: px = 8.0
	_plate.position = Vector2(px, wy - 13)
	_name.position = Vector2(6, 4)

func _place_choices() -> void:
	if not _cwin.visible: return
	var W := size.x
	var n := _cbox.get_child_count()
	var cw := float(CHOICE_COLS * 8 + 26)
	_cwin.size = Vector2(cw, n * CHOICE_H + 8)
	var x := 4.0 if _rival() else W - 4 - cw
	_cwin.position = Vector2(x, _win.position.y - 16 - _cwin.size.y)
	_cbox.position = Vector2(6, 4)
	_cbox.size = Vector2(cw - 12, n * CHOICE_H)
	for i in n:
		var b: Button = _cbox.get_child(i)
		b.text = ("> " if i == _sel else "  ") + str(b.get_meta("t"))

# ---------------- text ----------------
## Greedy word wrap to `cols` monospace columns (explicit newlines kept, long words split).
static func wrap_text(text: String, cols: int = COLS) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			while word.length() > cols:
				if line != "": out.append(line); line = ""
				out.append(word.substr(0, cols))
				word = word.substr(cols)
			if line == "": line = word
			elif line.length() + 1 + word.length() <= cols: line += " " + word
			else:
				out.append(line)
				line = word
		out.append(line)
	return out

## Split dialogue lines into 3-row pages; choices stay on the last page.
static func paginate(src: Array) -> Array:
	var out := []
	for l in src:
		var rows := wrap_text(str(l.get("text", "")))
		var pages := maxi(1, ceili(rows.size() / float(ROWS)))
		for p in pages:
			var pl: Dictionary = (l as Dictionary).duplicate()
			pl["text"] = "\n".join(rows.slice(p * ROWS, mini(rows.size(), (p + 1) * ROWS)))
			if p < pages - 1: pl.erase("choices")
			out.append(pl)
	return out

# ---------------- flow ----------------
func play(sc: Dictionary) -> void:
	if _win == null: _build_now()
	scene_id = str(sc.get("id", ""))
	lines = paginate(sc.get("lines", []))
	idx = -1
	_done = false
	_shade.visible = dim
	var card: Dictionary = sc.get("card", {})
	if not card.is_empty():
		_show_card(card)
	else:
		_next()

func _build_now() -> void:
	_build()
	resized.connect(_layout)
	_layout()

func _show_card(card: Dictionary) -> void:
	_card_up = true
	_card.visible = true
	_win.visible = false
	_pframe.visible = false
	_plate.visible = false
	for c in _card.get_children(): c.queue_free()
	var v := UIKit.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.position = Vector2(8, 10)
	v.size = Vector2(_card.size.x - 16, _card.size.y - 20)
	var top := UIKit.label(str(card.get("top", "")), UIKit.GOLD, true)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ttl := UIKit.label(str(card.get("title", "")), Color.WHITE)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_color_override("font_shadow_color", OUTLINE)
	ttl.add_theme_constant_override("shadow_offset_x", 1)
	ttl.add_theme_constant_override("shadow_offset_y", 1)
	var sub := UIKit.label(str(card.get("sub", "")), UIKit.DIM, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [top, ttl, sub]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	_card.add_child(v)

func _next() -> void:
	if _done: return
	idx += 1
	if idx >= lines.size():
		_finish()
		return
	_show_line()

func _show_line() -> void:
	var l := _cur()
	var who := str(l.get("who", ""))
	_win.visible = true
	_cwin.visible = false
	_waiting = false
	var tex: Texture2D = Portraits.tex(who, str(l.get("expr", "neutral"))) if who != "" else null
	_pframe.visible = tex != null
	_port.texture = tex
	_port.flip_h = _rival()
	var tint := Color(str(l.get("col", "#ffffff")))
	_pframe.top = tint.darkened(0.35).lerp(TOP, 0.5)
	_pframe.bottom = tint.darkened(0.75).lerp(BOTTOM, 0.4)
	_pframe.queue_redraw()
	_name.text = str(l.get("name", "")).to_upper()
	_name.add_theme_color_override("font_color", tint)
	_plate.visible = _name.text != ""
	var col := Color.WHITE
	if who == "": col = UIKit.GOLD if bool(l.get("note", false)) else NARRATOR
	_text.add_theme_color_override("font_color", col)
	_text.text = str(l.get("text", ""))
	_total = _text.text.length()
	_shown = 0.0
	_text.visible_characters = 0
	typing = true
	_place_speaker()
	line_started.emit(idx)

func _process(delta: float) -> void:
	_blink += delta
	if _arrow: _arrow.visible = not typing and not _waiting and not _card_up and _win.visible and fmod(_blink, 0.8) < 0.5
	if not typing: return
	_shown += cps * delta
	_text.visible_characters = int(_shown)
	if _shown >= _total: _end_typing()

func _end_typing() -> void:
	typing = false
	_text.visible_characters = -1
	if _cur().has("choices") and not (_cur().choices as Array).is_empty(): _show_choices()

func _show_choices() -> void:
	_waiting = true
	_sel = 0
	for c in _cbox.get_children():
		_cbox.remove_child(c)
		c.queue_free()
	var cs: Array = _cur().choices
	for i in cs.size():
		var b := Button.new()
		b.set_meta("t", str(cs[i].get("t", "")))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, CHOICE_H)
		b.add_theme_font_override("font", UIKit.font)
		b.add_theme_font_size_override("font_size", 16)
		var clear := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]: b.add_theme_stylebox_override(st, clear)
		for c in ["font_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(c, Color.WHITE)
		b.add_theme_color_override("font_hover_color", UIKit.GOLD)
		b.add_theme_color_override("font_hover_pressed_color", UIKit.GOLD)
		b.mouse_entered.connect(_hover.bind(i))
		b.pressed.connect(pick.bind(i))
		_cbox.add_child(b)
	_cwin.visible = true
	_place_choices()

func _hover(i: int) -> void:
	_sel = i
	_place_choices()

## Pick choice i of the current line (UI buttons call this; tests can too).
func pick(i: int) -> void:
	if not _waiting: return
	var cs: Array = _cur().get("choices", [])
	if i < 0 or i >= cs.size(): return
	var c: Dictionary = cs[i]
	_waiting = false
	_cwin.visible = false
	choice_made.emit(c)
	var reply := paginate(c.get("reply", []))
	for j in reply.size(): lines.insert(idx + 1 + j, reply[j])
	_next()

## Tap: dismiss the card, finish typing, or go to the next box.
func advance() -> void:
	if _done: return
	if _card_up:
		_card_up = false
		_card.visible = false
		_next()
		return
	if typing:
		_shown = _total
		_end_typing()
		return
	if _waiting: return
	_next()

func is_waiting_choice() -> bool: return _waiting
func current() -> Dictionary: return _cur()

func _finish() -> void:
	_done = true
	typing = false
	finished.emit(scene_id)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		advance()

func _unhandled_input(e: InputEvent) -> void:
	if not is_visible_in_tree() or _done: return
	if _waiting:
		var n := _cbox.get_child_count()
		if e.is_action_pressed("ui_up"): _sel = posmod(_sel - 1, n); _place_choices(); get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_down"): _sel = posmod(_sel + 1, n); _place_choices(); get_viewport().set_input_as_handled()
		elif e.is_action_pressed("ui_accept"): get_viewport().set_input_as_handled(); pick(_sel)
	elif e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()
