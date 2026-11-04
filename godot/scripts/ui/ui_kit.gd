class_name UIKit
extends RefCounted
## Pixel UI: the SNES-menu skin shared by every screen (title, quick race, LAN, career, bench, race HUD).
##
## Frames are 9-slice StyleBoxTextures baked once in code (see frame()): a 1 px outline with notched
## corners, bevel rings (light top-left, dark bottom-right) and a banded vertical gradient, in the
## style of an SNES RPG window. Buttons (btn_style()) have a 2 px lip under the face that disappears
## when pressed (the label drops 1 px); hover lightens, disabled goes flat grey.
## Text hierarchy: DotGothic16 16 px for names, buttons and screen titles; PressStart2P 8 px for
## details and numbers; PressStart2P 16 px only for big headings (title()). No antialiasing or
## hinting, integer sizes only, 1 px drop shadows instead of thick outlines.
## Public API kept for race_view.gd: btn, label, title, vbox, hbox, panel, scroll, sb, money + colours.

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
const OUTLINE := Color("#140c24")
const SHADOW := Color(0.03, 0.02, 0.09, 0.85)
const INK := Color("#eef1fa")

static var font: Font          ## DotGothic16 16 px (a FontVariation, see theme())
static var font8: FontFile     ## PressStart2P 8 px
static var _theme: Theme
static var _tex_cache := {}
static var _frame_cache := {}
static var _icon_cache := {}

static func _load_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f = f.duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

## Flat box (kept for callers that want a plain colour; new code should prefer frame()).
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

static func _q(c: Color) -> Color:
	return SpriteForge.snes(c)

# ======================================================================
# frames
# ======================================================================
## Frame specs: rings go outside-in as [top-left colour, bottom-right colour]; fill is a banded
## gradient top -> bottom; r = corner notch (0..2); m = 9-slice margin; pad = content l, t, r, b.
const FRAMES := {
	"window": {"w": 16, "h": 64, "r": 2, "rings": [["#f4f4ee", "#b4bcd8"], ["#a8b2d8", "#5a6498"], ["#0c1240", "#0c1240"]],
		"top": "#3d5fcf", "bot": "#0f1c62", "bands": 12, "m": 4, "pad": [8, 7, 8, 7]},
	"header": {"w": 16, "h": 26, "r": 2, "rings": [["#f4f4ee", "#9aa4c8"], ["#0c1240", "#0c1240"]],
		"top": "#2f4cb8", "bot": "#16206a", "bands": 4, "m": 3, "pad": [4, 3, 5, 3]},
	"card": {"w": 12, "h": 32, "r": 1, "rings": [["#6f82cc", "#2a3672"]],
		"top": "#24327e", "bot": "#141c4e", "bands": 6, "m": 2, "pad": [5, 4, 5, 4]},
	"card_sel": {"w": 12, "h": 32, "r": 1, "rings": [["#ffe680", "#b08a1c"], ["#5a4a10", "#5a4a10"]],
		"top": "#30418e", "bot": "#1a2660", "bands": 6, "m": 3, "pad": [5, 4, 5, 4]},
	"card_dim": {"w": 12, "h": 32, "r": 1, "rings": [["#3e4560", "#20243a"]],
		"top": "#1a1e34", "bot": "#12152a", "bands": 3, "m": 2, "pad": [5, 4, 5, 4]},
	"card_gold": {"w": 12, "h": 32, "r": 1, "rings": [["#ffd84a", "#80661a"]],
		"top": "#463a16", "bot": "#2a220c", "bands": 4, "m": 2, "pad": [5, 4, 5, 4]},
	"card_red": {"w": 12, "h": 32, "r": 1, "rings": [["#ff8a8a", "#7a2a34"]],
		"top": "#4a1a28", "bot": "#2a0e18", "bands": 4, "m": 2, "pad": [5, 4, 5, 4]},
	"card_green": {"w": 12, "h": 32, "r": 1, "rings": [["#8ef58e", "#2a7a34"]],
		"top": "#1c4834", "bot": "#0f2a1e", "bands": 4, "m": 2, "pad": [5, 4, 5, 4]},
	"inset": {"w": 12, "h": 16, "r": 1, "rings": [["#050818", "#4c5ea8"]],
		"top": "#0a0f2e", "bot": "#0e1640", "bands": 2, "m": 2, "pad": [4, 3, 4, 3]},
	"note": {"w": 12, "h": 16, "r": 1, "rings": [["#0a0f2c", "#34488c"]],
		"top": "#111c48", "bot": "#14204e", "bands": 2, "m": 2, "pad": [5, 4, 5, 4]},
	"lcd": {"w": 12, "h": 16, "r": 1, "rings": [["#04060f", "#3c4c90"]],
		"top": "#050a1c", "bot": "#0a1430", "bands": 2, "m": 2, "pad": [3, 2, 3, 2]},
	"msg": {"w": 12, "h": 16, "r": 1, "rings": [["#ffd84a", "#8a6a18"]],
		"top": "#1a1c40", "bot": "#10123a", "bands": 2, "m": 2, "pad": [5, 3, 5, 3]},
	"group_head": {"w": 12, "h": 12, "r": 0, "rings": [],
		"top": "#3a4ea8", "bot": "#2a3a8a", "bands": 2, "m": 1, "pad": [5, 2, 5, 2]},
}

## Shared 9-slice frame (do not mutate; use frame_new() for a private copy).
static func frame(kind: String) -> StyleBoxTexture:
	if _frame_cache.has(kind): return _frame_cache[kind]
	var spec: Dictionary = FRAMES.get(kind, FRAMES.card)
	var s := StyleBoxTexture.new()
	s.texture = _frame_tex(kind, spec)
	var m := int(spec.m)
	s.texture_margin_left = m; s.texture_margin_right = m; s.texture_margin_top = m; s.texture_margin_bottom = m
	var pad: Array = spec.pad
	s.content_margin_left = pad[0]; s.content_margin_top = pad[1]; s.content_margin_right = pad[2]; s.content_margin_bottom = pad[3]
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_frame_cache[kind] = s
	return s

## Private copy of a frame with new content margins (l, t, r, b; -1 keeps the frame's own).
static func frame_new(kind: String, l := -1, t := -1, r := -1, b := -1) -> StyleBoxTexture:
	var s: StyleBoxTexture = frame(kind).duplicate()
	if l >= 0: s.content_margin_left = l
	if t >= 0: s.content_margin_top = t
	if r >= 0: s.content_margin_right = r
	if b >= 0: s.content_margin_bottom = b
	return s

## A frame tinted from one colour (UIKit.panel(child, bg) and other custom-colour boxes).
static func frame_tint(bg: Color, kind := "inset") -> StyleBoxTexture:
	var key := "%s@%s" % [kind, bg.to_html(false)]
	if _frame_cache.has(key): return _frame_cache[key]
	var spec: Dictionary = FRAMES.get(kind, FRAMES.inset).duplicate(true)
	if kind == "inset":
		spec.top = bg.darkened(0.1).to_html(false); spec.bot = bg.lightened(0.04).to_html(false)
		spec.rings = [[bg.darkened(0.6).to_html(false), bg.lightened(0.35).to_html(false)]]
	else:
		spec.top = bg.lightened(0.12).to_html(false); spec.bot = bg.darkened(0.2).to_html(false)
		spec.rings = [[bg.lightened(0.5).to_html(false), bg.darkened(0.45).to_html(false)]]
	var s := StyleBoxTexture.new()
	s.texture = _frame_tex(key, spec)
	var m := int(spec.m)
	s.texture_margin_left = m; s.texture_margin_right = m; s.texture_margin_top = m; s.texture_margin_bottom = m
	var pad: Array = spec.pad
	s.content_margin_left = pad[0]; s.content_margin_top = pad[1]; s.content_margin_right = pad[2]; s.content_margin_bottom = pad[3]
	_frame_cache[key] = s
	return s

static func _frame_tex(key: String, spec: Dictionary) -> ImageTexture:
	if _tex_cache.has("f:" + key): return _tex_cache["f:" + key]
	var t := ImageTexture.create_from_image(frame_img(int(spec.w), int(spec.h), int(spec.r), spec.rings, Color(spec.top), Color(spec.bot), int(spec.bands)))
	_tex_cache["f:" + key] = t
	return t

## Frame image: transparent notched corners (r), 1 px outline, bevel rings, banded gradient fill.
static func frame_img(w: int, h: int, r: int, rings: Array, top: Color, bot: Color, bands: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var nr := rings.size()
	var fill_h := h - 2 * (nr + 1)
	var n := maxi(1, bands)
	for y in h:
		for x in w:
			var i := mini(x, w - 1 - x)
			var j := mini(y, h - 1 - y)
			var d := mini(i, j)
			if i < r and j < r:
				var cd := i + j - r
				if cd < 0: continue
				d = mini(d, cd)
			var c: Color
			if d == 0: c = OUTLINE
			elif d <= nr:
				var ring: Array = rings[d - 1]
				var tl := y == d or x == d
				var br := y == h - 1 - d or x == w - 1 - d
				if tl and not br: c = Color(ring[0])
				elif br and not tl: c = Color(ring[1])
				else: c = Color(ring[0]).lerp(Color(ring[1]), 0.5)
			else:
				var fy := y - (nr + 1)
				var band := floorf(float(fy) * n / maxf(1.0, float(fill_h)))
				c = top.lerp(bot, band / maxf(1.0, float(n - 1)))
			img.set_pixel(x, y, _q(c))
	return img

# ======================================================================
# buttons
# ======================================================================
## Bevelled button face for one state: "normal", "hover", "pressed", "disabled". flat = chip/tab
## (1 px lip, smaller bevel). pad = content l, t, r, b for the normal state.
static func btn_style(face: Color, state := "normal", pad: Array = [4, 3, 4, 3], flat := false) -> StyleBoxTexture:
	var lip := 1 if flat else 2
	var s := StyleBoxTexture.new()
	s.texture = _btn_tex(face, state, flat)
	var lp := 0 if state == "pressed" else lip
	s.texture_margin_left = 2; s.texture_margin_right = 2
	s.texture_margin_top = 2; s.texture_margin_bottom = 1 + lp + 1
	s.content_margin_left = pad[0]; s.content_margin_right = pad[2]
	s.content_margin_top = pad[1]; s.content_margin_bottom = pad[3]
	if state == "pressed":
		s.content_margin_top = pad[1] + 1
		s.content_margin_bottom = maxi(0, pad[3] - 1)
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

static func _btn_tex(face: Color, state: String, flat: bool) -> ImageTexture:
	var key := "b:%s:%s:%s" % [face.to_html(false), state, "f" if flat else "b"]
	if _tex_cache.has(key): return _tex_cache[key]
	var w := 12
	var h := 18 if flat else 24
	var lip := 0 if state == "pressed" else (1 if flat else 2)
	var c := face
	match state:
		"hover": c = face.lightened(0.16)
		"pressed": c = face.darkened(0.22)
		"disabled":
			var g := face.get_luminance() * 0.35 + 0.16
			c = Color(g * 0.92, g * 0.95, g * 1.15)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(1, 0, w - 2, h), _q(OUTLINE))
	img.fill_rect(Rect2i(0, 1, w, h - 2), _q(OUTLINE))
	var fh := h - 2 - lip
	var bands := 3
	for y in fh:
		var band := floorf(float(y) * bands / float(fh))
		var col := c.lightened(0.12).lerp(c.darkened(0.14), band / float(bands - 1))
		img.fill_rect(Rect2i(1, 1 + y, w - 2, 1), _q(col))
	if state == "disabled":
		img.fill_rect(Rect2i(1, 1, w - 2, 1), _q(c.lightened(0.12)))
	elif state == "pressed":
		img.fill_rect(Rect2i(1, 1, w - 2, 1), _q(c.darkened(0.45)))
		img.fill_rect(Rect2i(1, 2, 1, fh - 1), _q(c.darkened(0.25)))
	else:
		img.fill_rect(Rect2i(2, 1, w - 4, 1), _q(c.lightened(0.55)))
		img.fill_rect(Rect2i(1, 1, 1, fh), _q(c.lightened(0.28)))
		img.fill_rect(Rect2i(w - 2, 2, 1, fh - 1), _q(c.darkened(0.28)))
		img.set_pixel(1, 1, _q(c.lightened(0.4)))
	for k in lip:
		img.fill_rect(Rect2i(1, h - 2 - k, w - 2, 1), _q(c.darkened(0.62 if k == 0 else 0.5)))
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t

## Give a button the bevelled face in `face` for every state. Text colours: white, or dark ink on
## light faces (gold chips).
static func style_btn(b: Button, face: Color, pad: Array = [4, 3, 4, 3], flat := false) -> Button:
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, btn_style(face, st, pad, flat))
	b.add_theme_stylebox_override("hover_pressed", btn_style(face, "pressed", pad, flat))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dark := face.get_luminance() > 0.6
	var fc := Color("#1a1430") if dark else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color("#8890a8"))
	if not dark:
		b.add_theme_color_override("font_shadow_color", SHADOW)
		b.add_theme_constant_override("shadow_offset_x", 1)
		b.add_theme_constant_override("shadow_offset_y", 1)
	else:
		b.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.35))
		b.add_theme_constant_override("shadow_offset_x", 1)
		b.add_theme_constant_override("shadow_offset_y", 1)
	return b

# ======================================================================
# theme
# ======================================================================
static func theme() -> Theme:
	if _theme: return _theme
	# DotGothic16 is not drawn on a whole-pixel grid: the gap between the dot and the stem of i / j is
	# 0.8 px at 16 px, and at Godot's baseline phase the mono rasteriser fills it ("Kei" read "Kel").
	# A 1% vertical stretch of the outlines moves the sampling phase so the gap survives; every other
	# ASCII glyph rasterises exactly as before.
	var dg := FontVariation.new()
	dg.base_font = _load_font("res://fonts/DotGothic16-Regular.ttf")
	dg.variation_transform = Transform2D(Vector2(1, 0), Vector2(0, 1.01), Vector2.ZERO)
	font = dg
	font8 = _load_font("res://fonts/PressStart2P-Regular.ttf")
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 16
	for st in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(st, "Button", btn_style(BTN, st))
	th.set_stylebox("hover_pressed", "Button", btn_style(BTN, "pressed"))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#8890a8"))
	th.set_color("font_shadow_color", "Button", SHADOW)
	th.set_constant("shadow_offset_x", "Button", 1)
	th.set_constant("shadow_offset_y", "Button", 1)
	th.set_stylebox("panel", "PanelContainer", frame_new("window", 6, 5, 6, 5))
	th.set_stylebox("panel", "Panel", frame_new("window", 6, 5, 6, 5))
	th.set_color("font_color", "Label", Color.WHITE)
	th.set_stylebox("normal", "LineEdit", frame_new("inset", 5, 4, 5, 4))
	th.set_stylebox("focus", "LineEdit", frame_new("msg", 5, 4, 5, 4))
	th.set_stylebox("read_only", "LineEdit", frame_new("lcd", 5, 4, 5, 4))
	th.set_color("font_color", "LineEdit", Color.WHITE)
	th.set_color("font_placeholder_color", "LineEdit", Color("#5a6898"))
	th.set_color("caret_color", "LineEdit", GOLD)
	th.set_color("selection_color", "LineEdit", Color(0.25, 0.45, 0.9, 0.6))
	th.set_stylebox("normal", "TextEdit", frame_new("inset", 4, 3, 4, 3))
	th.set_stylebox("focus", "TextEdit", frame_new("msg", 4, 3, 4, 3))
	th.set_stylebox("read_only", "TextEdit", frame_new("lcd", 4, 3, 4, 3))
	th.set_constant("separation", "VBoxContainer", 4)
	th.set_constant("separation", "HBoxContainer", 4)
	# slim pixel scrollbar: dark well, bevelled grabber
	var track := frame_new("lcd", 0, 0, 0, 0)
	track.content_margin_left = 2; track.content_margin_right = 2
	th.set_stylebox("scroll", "VScrollBar", track)
	th.set_stylebox("scroll_focus", "VScrollBar", track)
	th.set_stylebox("grabber", "VScrollBar", btn_style(Color("#5a6aa8"), "normal", [2, 3, 2, 3], true))
	th.set_stylebox("grabber_highlight", "VScrollBar", btn_style(Color("#8a9ad8"), "normal", [2, 3, 2, 3], true))
	th.set_stylebox("grabber_pressed", "VScrollBar", btn_style(GOLD.darkened(0.2), "normal", [2, 3, 2, 3], true))
	for ic in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
		th.set_icon(ic, "VScrollBar", _empty_tex())
	# slider: inset groove, gold fill, pixel knob
	var groove := frame_new("lcd", 0, 3, 0, 3)
	th.set_stylebox("slider", "HSlider", groove)
	var fill := btn_style(GOLD.darkened(0.15), "normal", [0, 3, 0, 3], true)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	th.set_icon("grabber", "HSlider", knob_tex(false))
	th.set_icon("grabber_highlight", "HSlider", knob_tex(true))
	th.set_icon("grabber_disabled", "HSlider", knob_tex(false))
	th.set_constant("center_grabber", "HSlider", 0)
	_theme = th
	return th

static func _empty_tex() -> ImageTexture:
	if _tex_cache.has("empty"): return _tex_cache.empty
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	_tex_cache.empty = ImageTexture.create_from_image(img)
	return _tex_cache.empty

## 10x14 slider knob (white bevel, gold when highlighted).
static func knob_tex(hi: bool) -> ImageTexture:
	var key := "knob:%s" % hi
	if _tex_cache.has(key): return _tex_cache[key]
	var rows := [".kkkkkkkk.", "kwwwwwwwgk", "kwlllllldk", "kwlllllldk", "kwlkkkkldk", "kwlllllldk", "kwlkkkkldk",
		"kwlllllldk", "kwlkkkkldk", "kwlllllldk", "kwlllllldk", "kgddddddgk", ".kkkkkkkk.", ".........."]
	var base := GOLD if hi else Color("#d8dcea")
	var pal := {"k": OUTLINE, "w": base.lightened(0.6), "l": base, "g": base.darkened(0.25), "d": base.darkened(0.45)}
	var img := Image.create(10, 14, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in mini(10, r.length()):
			if pal.has(r[x]): img.set_pixel(x, y, _q(pal[r[x]]))
	_tex_cache[key] = ImageTexture.create_from_image(img)
	return _tex_cache[key]

# ======================================================================
# widgets (public API)
# ======================================================================
## 1 px dark drop shadow on a Label / Button (the SNES text look).
static func shadow(c: Control, col: Color = SHADOW) -> Control:
	c.add_theme_color_override("font_shadow_color", col)
	c.add_theme_constant_override("shadow_offset_x", 1)
	c.add_theme_constant_override("shadow_offset_y", 1)
	return c

static func label(text: String, color: Color = Color.WHITE, small := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if small:
		l.add_theme_font_override("font", font8)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_constant_override("line_spacing", 3)
	shadow(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Big heading (PressStart2P 16): thin outline plus a 2 px drop shadow in a darker shade.
static func title(text: String, color: Color = GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font8)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 2)
	l.add_theme_color_override("font_shadow_color", OUTLINE)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func btn(text: String, cb: Callable, color: Color = BTN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.custom_minimum_size = Vector2(16, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if color != BTN: style_btn(b, color)
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

## Framed panel: the SNES window by default, or a sunken well tinted from `bg`.
static func panel(child: Control, bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	if bg != PANEL: p.add_theme_stylebox_override("panel", frame_tint(bg, "inset"))
	p.add_child(child)
	return p

## Panel with a named frame (frame(kind)); content margins from the frame unless overridden.
static func window(child: Control, kind := "window") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(kind))
	p.add_child(child)
	return p

## Music / sound effects / engine volume sliders (Game.player.*_vol, applied live, saved with the profile).
## Used by the title Profile page, career Settings and the race screen's VOL panel.
const VOLUMES := [["Music", "music_vol", 0.6], ["Sound effects", "sfx_vol", 0.8], ["Engines", "engine_vol", 0.8]]

static func volume_sliders(label_w := 104) -> VBoxContainer:
	var box := vbox(4)
	for pair in VOLUMES:
		var h := hbox(4)
		var l := label(pair[0], Color.WHITE, true)
		l.custom_minimum_size = Vector2(label_w, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05
		sl.value = float(Game.player.get(pair[1], pair[2]))
		sl.custom_minimum_size = Vector2(0, 18)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.set_meta("act", "vol:" + str(pair[1]))
		var pct := label("%d%%" % int(round(sl.value * 100)), DIM, true)
		pct.custom_minimum_size = Vector2(34, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.autowrap_mode = TextServer.AUTOWRAP_OFF
		pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value_changed.connect(_on_vol.bind(str(pair[1]), pct))
		sl.drag_ended.connect(func(_c): Game.save_profile())
		h.add_child(sl)
		h.add_child(pct)
		box.add_child(h)
	return box

static func _on_vol(val: float, key: String, pct: Label) -> void:
	Game.player[key] = val
	pct.text = "%d%%" % int(round(val * 100))
	Audio.apply_volumes()
	if Engine.get_main_loop() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): Game.save_profile()

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

## Tiled two-tone diagonal background (SNES menu pattern), full rect.
static func bg_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture = bg_tex()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func bg_tex() -> ImageTexture:
	if _tex_cache.has("bg"): return _tex_cache.bg
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var a := _q(BG)
	var b := _q(Color("#0f1640"))
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, b if ((x + y) % 16 < 8) != ((x - y + 16) % 16 < 8) else a)
	_tex_cache.bg = ImageTexture.create_from_image(img)
	return _tex_cache.bg

## Thin rule line (1 px dark + 1 px light) for separating rows inside windows.
class Rule2 extends Control:
	var dark := Color("#0c1240")
	var light := Color("#4a5ca8")
	func _init() -> void:
		custom_minimum_size = Vector2(4, 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, 1), dark)
		draw_rect(Rect2(0, 1, size.x, 1), light)

static func rule() -> Control: return Rule2.new()

# ======================================================================
# pixel icons
# ======================================================================
const IC_PAL := {
	"k": "#140c24", "w": "#fbfbf4", "l": "#c8d0dc", "g": "#8a96a8", "d": "#4a5068", "y": "#ffd84a", "Y": "#c8961e",
	"o": "#f08a2c", "r": "#e8432f", "R": "#962018", "b": "#4a8ce8", "B": "#22488a", "c": "#9ae0ff", "n": "#5ac85a",
	"N": "#25742f", "p": "#ff9fcf", "P": "#c0508a", "t": "#d8a060", "T": "#8a5a2a", "s": "#f5c8a0", "v": "#b47ae8", "V": "#6a3aa0",
}

## Pixel-art icons, 16x16 (menu) or 8x8 (status): build, machines, races, staff, research, sponsor,
## facility, records, settings, coin, rp, fans, spark_b/s/g, back.
const ICONS := {
	"build": [
		"................",
		"..........kkkk..",
		".........kwllk..",
		"........kwlk....",
		"........klk..kk.",
		"........klk.klk.",
		"........kllkllk.",
		".......kllllllk.",
		"......kllllggk..",
		".....kllgkkkk...",
		"....kllgk.......",
		"...kllgk........",
		"..kwlgk.........",
		"..klgk..........",
		"...kk...........",
		"................"],
	"machines": [
		"................",
		"................",
		"......kkkkk.....",
		".....kRrrrrk....",
		"....kRkccwckk...",
		"....krkcccck.k..",
		"..kkkrrrrrrrrkk.",
		".krrwrrrrrrrrrrk",
		".krrrrrrrrrrryyk",
		".kRRRRRRRRRRRRRk",
		".kRkkkRRRRRkkkRk",
		"..kkdgkkkkkkdgk.",
		"...kgwdk..kgwdk.",
		"...kddgk..kddgk.",
		"....kkk....kkk..",
		"................"],
	"races": [
		"................",
		".kk.............",
		"kgkkkkkkkkkkkk..",
		"klkwwkkwwkkwwk..",
		"klkwwkkwwkkwwk..",
		"klkkkwwkkwwkkwk.",
		"klkkkwwkkwwkkwk.",
		"klkwwkkwwkkwwkkk",
		"klkwwkkwwkkwwkk.",
		"klkkkkkkkkkkkk..",
		"klk.............",
		"klk.............",
		"klk.............",
		"kgk.............",
		"kdk.............",
		".k.............."],
	"staff": [
		"................",
		".....kkkkkk.....",
		"...kkbbbbwbkk...",
		"..kbbbbbbbwbbk..",
		"..kbbbbbbbbbbk..",
		".kbbrrrrrrrrbbk.",
		".kbkkkkkkkkkkbk.",
		".kbkccccccwwkbk.",
		".kbkcccccccwkbk.",
		".kbkkkkkkkkkkbk.",
		".kBbbbbbbbbbbBk.",
		"..kBbbbbbbbbBk..",
		"..kkBBBBBBBBkk..",
		"..kddkkkkkkddk..",
		"...kkk....kkk...",
		"................"],
	"research": [
		"................",
		"......kkkkk.....",
		"......klwlk.....",
		"......kkkkk.....",
		".......kwk......",
		".......kwk......",
		"......kwllk.....",
		".....kwlllgk....",
		"....kwlnnnngk...",
		"...kwnnwnnnngk..",
		"...knnnnnnwnnk..",
		"..knnnwnnnnnnnk.",
		"..knnnnnnnnnNNk.",
		"..kNNNNNNNNNNNk.",
		"...kkkkkkkkkkk..",
		"................"],
	"sponsor": [
		"................",
		"......kkkk......",
		".....kYkkYk.....",
		"......kyyk......",
		".....kkkkkk.....",
		"....kyyyyyyk....",
		"...kyywyyyyyk...",
		"..kyywyykyyyyk..",
		"..kywyykkkyyyk..",
		".kyyyyykyyyyyYk.",
		".kyyyyykkkyyyYk.",
		".kyyyyyyykyyyYk.",
		".kyyyyykkkyyYYk.",
		"..kYyyyykyyYYk..",
		"...kkkkkkkkkk...",
		"................"],
	"facility": [
		"................",
		"...........kk...",
		"......kk..kddk..",
		".....krrk.kddk..",
		"....krrrrkkddk..",
		"...krrwrrrrkdk..",
		"..krrwrrrrrrrk..",
		".krrrrrrrrrrrrk.",
		"kkkkkkkkkkkkkkkk",
		".kttkkkkkkkkttk.",
		".kttkgggggdkttk.",
		".kttkddddddkttk.",
		".kttkgggggdkttk.",
		".kttkddddddkttk.",
		".kkkkkkkkkkkkkk.",
		"................"],
	"records": [
		"................",
		"..kkkkkkkkkkkk..",
		".kykwyyyyyyyYyk.",
		"kyk.kwyyyyyyk.yk",
		"kyk.kwyyyyyyk.yk",
		".kyykyyyyyyYkyk.",
		"..kkkyyyyyyYkk..",
		"....kYyyyyYYk...",
		".....kkYYYkk....",
		"......kYYk......",
		"......kyYk......",
		".....kkkkkk.....",
		"....kTTttTTk....",
		"....kTtyytTk....",
		"...kkkkkkkkkk...",
		"................"],
	"settings": [
		"................",
		"......kkkk......",
		"..kk..klgk..kk..",
		".klgkkkllkkklgk.",
		".kllllllllllllk.",
		"..kllglkkglllk..",
		"..klgkk..kkglk..",
		"kkkllk....klgkkk",
		"kllllk....kllllk",
		"kkkllkk..kkgdkkk",
		"..klggkkkkgdgk..",
		"..kllgggggddgk..",
		".klllgddgddddgk.",
		".kgdkkkddkkkgdk.",
		"..kk..kgdk..kk..",
		"......kkkk......"],
	"coin": [
		"..kkkk..",
		".kyyyYk.",
		"kywyyyYk",
		"kywkkyYk",
		"kyykyyYk",
		"kyyYyYYk",
		".kYYYYk.",
		"..kkkk.."],
	"rp": [
		"..kkkk..",
		"..kclk..",
		"..kclk..",
		".kcwcck.",
		"kbccbcck",
		"kbbbbbbk",
		"kBbbbbBk",
		".kkkkkk."],
	"fans": [
		"........",
		".kk.kk..",
		"kwpkppk.",
		"kpppppk.",
		"kpppPPk.",
		".kpPPk..",
		"..kPk...",
		"...k...."],
	"spark": [
		"...k....",
		"..kwk...",
		".kwyyk..",
		"kwyyyyk.",
		".kyyYk..",
		"..kYk...",
		"...k....",
		"........"],
	"back": [
		"........",
		"...kk...",
		"..kwk...",
		".kwwkkkk",
		"kwwwwwwk",
		".kwwkkkk",
		"..kwk...",
		"...kk..."],
}

## Icon texture by name (spark_b / spark_s / spark_g recolour the spark gem).
static func icon(name: String) -> ImageTexture:
	if _icon_cache.has(name): return _icon_cache[name]
	var base := name
	var over := {}
	match name:
		"spark_b": base = "spark"; over = {"w": "#ffd0a8", "y": "#d08850", "Y": "#8a4a20"}
		"spark_s": base = "spark"; over = {"w": "#ffffff", "y": "#c8d0dc", "Y": "#7a8494"}
		"spark_g": base = "spark"; over = {"w": "#fff8c8", "y": "#ffd84a", "Y": "#c8961e"}
	var rows: Array = ICONS.get(base, ICONS.coin)
	var w: int = (rows[0] as String).length()
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in mini(w, r.length()):
			var ch := r[x]
			if ch == ".": continue
			var hex: String = over.get(ch, IC_PAL.get(ch, ""))
			if hex != "": img.set_pixel(x, y, _q(Color(hex)))
	_icon_cache[name] = ImageTexture.create_from_image(img)
	return _icon_cache[name]

static func icon_rect(name: String, px := 1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	var sz: Vector2 = t.texture.get_size() * px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = sz
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
