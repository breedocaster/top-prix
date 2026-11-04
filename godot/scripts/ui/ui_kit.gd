class_name UIKit
extends RefCounted
## Pixel UI: SNES-menu styled theme built in code (crisp DotGothic16, square 2px borders).

const BG := Color("#0b1030")
const PANEL := Color("#1b2445")
const EDGE := Color("#f2f2ee")
const BTN := Color("#2f5fbf")
const BTN_HI := Color("#3f78e0")
const BTN_LO := Color("#22408a")
const ACCENT := Color("#e8432f")
const GOLD := Color("#ffd84a")
const OK := Color("#3fb34a")
const DIM := Color("#8a96b8")

static var font: FontFile
static var font8: FontFile
static var _theme: Theme

static func _load_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f = f.duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

static func sb(bg: Color, edge: Color = Color.BLACK, bw: int = 2, pad: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(bw)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad - 1; s.content_margin_bottom = pad - 1
	return s

static func theme() -> Theme:
	if _theme: return _theme
	font = _load_font("res://fonts/DotGothic16-Regular.ttf")
	font8 = _load_font("res://fonts/PressStart2P-Regular.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 16
	th.set_stylebox("normal", "Button", sb(BTN, BG))
	th.set_stylebox("hover", "Button", sb(BTN_HI, BG))
	th.set_stylebox("pressed", "Button", sb(BTN_LO, BG))
	th.set_stylebox("hover_pressed", "Button", sb(BTN_LO, BG))
	th.set_stylebox("disabled", "Button", sb(Color("#3a3f55"), BG))
	th.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), GOLD))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", DIM)
	th.set_stylebox("panel", "PanelContainer", sb(PANEL, EDGE, 2, 6))
	th.set_stylebox("panel", "Panel", sb(PANEL, EDGE, 2, 6))
	th.set_color("font_color", "Label", Color.WHITE)
	th.set_stylebox("normal", "LineEdit", sb(Color("#0f1736"), EDGE))
	th.set_stylebox("focus", "LineEdit", sb(Color("#0f1736"), GOLD))
	th.set_color("font_color", "LineEdit", Color.WHITE)
	th.set_constant("separation", "VBoxContainer", 4)
	th.set_constant("separation", "HBoxContainer", 4)
	th.set_stylebox("scroll", "VScrollBar", sb(Color("#0f1736"), Color.BLACK, 0, 0))
	th.set_stylebox("grabber", "VScrollBar", sb(DIM, Color.BLACK, 0, 2))
	th.set_stylebox("grabber_highlight", "VScrollBar", sb(EDGE, Color.BLACK, 0, 2))
	th.set_stylebox("grabber_pressed", "VScrollBar", sb(GOLD, Color.BLACK, 0, 2))
	_theme = th
	return th

static func label(text: String, color: Color = Color.WHITE, small := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if small:
		l.add_theme_font_override("font", font8)
		l.add_theme_font_size_override("font_size", 8)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func title(text: String, color: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font8)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#140c24"))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func btn(text: String, cb: Callable, color: Color = BTN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(16, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if color != BTN:
		b.add_theme_stylebox_override("normal", sb(color, BG))
		b.add_theme_stylebox_override("hover", sb(color.lightened(0.15), BG))
		b.add_theme_stylebox_override("pressed", sb(color.darkened(0.25), BG))
	b.pressed.connect(cb)
	return b

static func vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func panel(child: Control, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	if bg != PANEL: p.add_theme_stylebox_override("panel", sb(bg, EDGE, 2, 6))
	p.add_child(child)
	return p

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func money(v: float) -> String:
	var a := absf(v); var s := "-" if v < 0 else ""
	if a >= 1e6: return s + "$%.1fM" % (a / 1e6)
	if a >= 1e3: return s + "$%dK" % int(round(a / 1e3))
	return s + "$%d" % int(a)
