extends RefCounted
## Widgets shared by the career sub-screens (staff, research, sponsors, facilities, records, settings,
## test day, bench). Built on UIKit (pixel theme): DotGothic16 for names/buttons, PressStart2P 8 px
## for dense details, MiniFont 3x5 inside drawn canvases. Everything shown goes through ascii().

const MiniFont := preload("res://scripts/ui/career/mini_font.gd")

const CARD := Color("#1b2445")
const CARD_EDGE := Color("#4b5ea0")
const DONE := Color("#173a2a")
const DONE_EDGE := Color("#3fb34a")
const LOCK := Color("#161a2c")
const LOCK_EDGE := Color("#3a3f55")
const SEL_EDGE := Color("#ffd84a")
const SUB := Color("#b9c7f0")
const HL := Color("#ffd84a")
const GD := Color("#8ef58e")
const BD := Color("#ff8a8a")
const BL := Color("#8fd8ff")
const DIM := Color("#8a96b8")
const GREEN := Color("#2f8f3a")
const RED := Color("#b8382a")
const GREY := Color("#3a3f55")
const CAP_COL := "#e2b53a"

const _REPL := {"×": "x", "–": "-", "—": "-", "·": "-", "→": "->", "←": "<-", "°": "", "★": "*", "☆": ".",
	"⚠": "!", "…": "...", "“": "\"", "”": "\"", "‘": "'", "’": "'", "é": "e", "è": "e", "ü": "u", "ö": "o",
	"ä": "a", "ñ": "n", "½": "1/2", "¼": "1/4", "¾": "3/4", "²": "2", "≈": "~", "✓": "OK", "✔": "OK", "•": "-",
	"≋": "~", "μ": "u", "±": "+/-"}

## Printable ASCII only (the pixel fonts have nothing else): known symbols map to look-alikes, the rest
## (emoji, CJK) is dropped.
static func ascii(s) -> String:
	var t := str(s)
	var plain := true
	for i in t.length():
		if t.unicode_at(i) > 126 or t.unicode_at(i) < 32: plain = false; break
	if plain: return t
	for k in _REPL: t = t.replace(k, _REPL[k])
	var out := ""
	for i in t.length():
		var c := t.unicode_at(i)
		if c == 10: out += "\n"
		elif c >= 32 and c <= 126: out += t[i]
	while out.contains("  "): out = out.replace("  ", " ")
	return out.strip_edges()

static func money(v: float) -> String: return ascii(U.money(v))

# ---------------- labels ----------------
## 8 px PressStart2P label (wraps by default).
## wrap = false keeps the text on one line at its natural width; clip = true lets it shrink and cut.
static func small(text, col: Color = SUB, wrap := true, clip := false) -> Label:
	var l := UIKit.label(ascii(text), col, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.clip_text = clip
	if clip: l.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## 16 px DotGothic16 label (one line, trimmed with "..." when too long, unless wrap).
static func big(text, col: Color = Color.WHITE, wrap := false) -> Label:
	var l := UIKit.label(ascii(text), col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if not wrap:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func section(text: String) -> Control:
	var h := UIKit.hbox(4)
	var l := small(text.to_upper(), HL, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(l)
	var line := ColorRect.new()
	line.color = Color("#2c3b70")
	line.custom_minimum_size = Vector2(4, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(line)
	return h

# ---------------- cards ----------------
static func card_style(state := "") -> StyleBoxFlat:
	match state:
		"done": return UIKit.sb(DONE, DONE_EDGE, 2, 5)
		"lock": return UIKit.sb(LOCK, LOCK_EDGE, 2, 5)
		"sel": return UIKit.sb(Color("#22305a"), SEL_EDGE, 2, 5)
		"note": return UIKit.sb(Color("#13204a"), Color("#2c3b70"), 1, 5)
		"warn": return UIKit.sb(Color("#3a1c1c"), Color("#b8382a"), 2, 5)
	return UIKit.sb(CARD, CARD_EDGE, 2, 5)

## Card panel; returns the inner VBox (the panel is its parent).
static func card(parent: Control, state := "", sep := 2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(state))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(sep)
	p.add_child(v)
	parent.add_child(p)
	return v

static func note(parent: Control, text, col: Color = SUB) -> Label:
	var v := card(parent, "note")
	var l := small(text, col)
	v.add_child(l)
	return l

# ---------------- buttons ----------------
## Button: 16 px font by default, 8 px with small = true. color tints the face.
static func btn(text, cb: Callable, color: Color = UIKit.BTN, small_font := false, disabled := false) -> Button:
	var b := UIKit.btn(ascii(text), cb, color)
	if small_font:
		b.add_theme_font_override("font", UIKit.font8)
		b.add_theme_font_size_override("font_size", 8)
		var faces := {"normal": color, "hover": color.lightened(0.15), "pressed": color.darkened(0.25), "hover_pressed": color.darkened(0.25), "disabled": Color("#3a3f55")}
		for k in faces:
			var st := UIKit.sb(faces[k], UIKit.BG, 2, 4)
			st.content_margin_left = 3; st.content_margin_right = 3
			st.content_margin_top = 4; st.content_margin_bottom = 4
			b.add_theme_stylebox_override(k, st)
	b.disabled = disabled
	return b

## Compact button that does not stretch (fixed min width).
static func sbtn(text, cb: Callable, color: Color = UIKit.BTN, w := 0, disabled := false) -> Button:
	var b := btn(text, cb, color, true, disabled)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.clip_text = false
	if w > 0: b.custom_minimum_size = Vector2(w, 0)
	return b

## Toggle chip (8 px). on = gold face with dark text.
static func chip(text, on: bool, cb: Callable, disabled := false) -> Button:
	var b := btn(text, cb, HL if on else Color("#22408a"), true, disabled)
	if on:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color("#140c24"))
	return b

static func row(items: Array, sep := 4) -> HBoxContainer:
	var h := UIKit.hbox(sep)
	for it in items:
		if it is Control: h.add_child(it)
	return h

# ---------------- stepper ----------------
## [label] [-] value [+] with the description on its own full-width line underneath.
## Meta "minus" / "plus" / "value" hold the widgets.
static func stepper(label: String, value: String, desc: String, cb: Callable, disabled := false, light := false) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(Color("#dde3ec") if light else Color("#2c3d7c"), Color("#8a93a3") if light else Color("#5a70bd"), 1, 4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := UIKit.vbox(2)
	p.add_child(vb)
	var h := UIKit.hbox(3)
	vb.add_child(h)
	var l := small(label, Color("#111a33") if light else Color.WHITE)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var m := btn("-", cb.bind(-1), Color("#3f6fd0"), false, disabled)
	m.size_flags_horizontal = Control.SIZE_SHRINK_END
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.custom_minimum_size = Vector2(26, 22)
	h.add_child(m)
	var v := small(value, Color("#1f4e8f") if light else HL, false)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.custom_minimum_size = Vector2(64, 0)
	h.add_child(v)
	var pl := btn("+", cb.bind(1), Color("#3f6fd0"), false, disabled)
	pl.size_flags_horizontal = Control.SIZE_SHRINK_END
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pl.custom_minimum_size = Vector2(26, 22)
	h.add_child(pl)
	if desc != "": vb.add_child(small(desc, Color("#334466") if light else SUB))
	p.set_meta("minus", m)
	p.set_meta("plus", pl)
	p.set_meta("value", v)
	return p

# ---------------- bars ----------------
class Bar extends Control:
	var frac := 0.0
	var col := Color("#8ef58e")
	var col2 := Color(0, 0, 0, 0)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).abs()
		draw_rect(r, Color("#2c3b70"))
		draw_rect(r.grow(-1), Color("#0d1330"))
		var w := floorf((size.x - 2) * clampf(frac, 0.0, 1.0))
		if w <= 0: return
		draw_rect(Rect2(1, 1, w, size.y - 2), col)
		if col2.a > 0: draw_rect(Rect2(1, 1, w, 1), col2)

static func bar(frac: float, col: Color = Color("#8ef58e"), h := 6) -> Control:
	var b := Bar.new()
	b.frac = frac
	b.col = col
	b.col2 = col.lightened(0.35)
	b.custom_minimum_size = Vector2(16, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Labelled bar row: "EN [######  ] 85/100".
static func bar_row(label: String, frac: float, right: String, col: Color) -> HBoxContainer:
	var h := UIKit.hbox(3)
	var l := small(label, SUB, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.custom_minimum_size = Vector2(l.text.length() * 8, 0)
	h.add_child(l)
	h.add_child(bar(frac, col))
	var r := small(right, SUB, false)
	r.size_flags_horizontal = Control.SIZE_SHRINK_END
	r.custom_minimum_size = Vector2(right.length() * 8, 0)
	h.add_child(r)
	return h

## Mini-font stat bars in a grid: rows [[label, value, max, color], ...]. sqrt scale keeps small
## numbers visible next to big ones.
class StatBars extends Control:
	var rows: Array = []
	var cols := 2
	var cell_w := 0.0
	func _init(r: Array = [], c := 2) -> void:
		rows = r
		cols = c
		custom_minimum_size = Vector2(0, ceili(r.size() / float(c)) * 8)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var cw := floorf((size.x + 4) / cols)
		for i in rows.size():
			var it: Array = rows[i]
			var x := (i % cols) * cw
			var y := (i / cols) * 8.0
			MiniFont.draw(self, str(it[0]), Vector2(x, y + 1), SUB)
			var bx := x + 14.0
			var bw := cw - 14.0 - 18.0
			draw_rect(Rect2(bx, y + 1, bw, 5), Color("#0d1330"))
			var f := sqrt(clampf(float(it[1]) / maxf(1.0, float(it[2])), 0.0, 1.0))
			draw_rect(Rect2(bx, y + 1, maxf(1.0, floorf(bw * f)), 5), it[3])
			draw_rect(Rect2(bx, y + 1, maxf(1.0, floorf(bw * f)), 1), Color(it[3]).lightened(0.4))
			MiniFont.draw(self, str(int(it[1])), Vector2(x + cw - 5, y + 1), Color.WHITE, 2)

## Mini-font run of coloured words: parts [[text, color], ...] (one line).
class MiniLine extends Control:
	var parts: Array = []
	func _init(p: Array = []) -> void:
		parts = p
		custom_minimum_size = Vector2(0, 6)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var x := 0.0
		for p in parts:
			MiniFont.draw(self, str(p[0]), Vector2(x, 0), p[1])
			x += MiniFont.width(str(p[0])) + 5

# ---------------- palette-swapped sprites ----------------
## Draws one frame of an index sheet; the palette_swap material decides the colours. Never modulate it.
class SpriteBox extends Control:
	var tex: Texture2D
	var src := Rect2()
	var row := 0
	var off := Vector2.ZERO
	var px := 1
	func _draw() -> void:
		if tex != null: draw_texture_rect_region(tex, Rect2(off, src.size * px), src, SpriteForge.row_color(row))

static func swap_material(lut: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/palette_swap.gdshader")
	m.set_shader_parameter("palette", lut)
	return m

static func _col(v, fallback: String) -> Color:
	var s := str(v) if v != null else fallback
	if not s.begins_with("#"): s = fallback
	return Color(s)

## LUT for chibi crew: one row per person {skin, hair, ...}, suit in the team colour.
static func crew_lut(people: Array, team: Color) -> ImageTexture:
	var M := SpriteForge.M
	var mats := M.size()
	var img := Image.create(mats * SpriteForge.LEVELS, maxi(1, people.size()), false, Image.FORMAT_RGBA8)
	var outline := SpriteForge.snes(Color("#140c24"))
	for r in people.size():
		var p: Dictionary = people[r]
		var over := {CrewModels.SKIN: _col(p.get("skin"), "#f5d0a9"), CrewModels.HAIR: _col(p.get("hair"), "#5a3214"), CrewModels.CAP: Color(CAP_COL)}
		for m in mats:
			var ramp: Array = SpriteForge.ramp7(over.get(m, SpriteForge.mat_color(m, team))) if m != 0 else []
			for l in SpriteForge.LEVELS:
				img.set_pixel(m * SpriteForge.LEVELS + l, r, outline if m == 0 else ramp[mini(l, 7)])
	return ImageTexture.create_from_image(img)

## Front-facing chibi of a staff member (role "drv" / "mec").
static func crew_sprite(role: String, row: int, mat: Material, pose := "stand", px := 1) -> SpriteBox:
	var s := SpriteBox.new()
	var r := "drv" if role == "drv" else "mech"
	s.tex = CrewModels.tex(r)
	s.src = CrewModels.frame_rect(pose, 2)
	s.row = row
	s.px = px
	s.material = mat
	s.custom_minimum_size = Vector2(CrewModels.CELL) * px
	s.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return s

## SD vehicle sprite (48x48 cell; frame 6 = three-quarter view facing right, 4 = side view).
static func veh_sprite(kind: String, row: int, mat: Material, frame := 6, crop := Rect2(0, 6, 48, 40)) -> SpriteBox:
	var s := SpriteBox.new()
	s.tex = SpriteForge.vehicle_tex(kind)
	s.src = Rect2(frame * 48 + crop.position.x, crop.position.y, crop.size.x, crop.size.y)
	s.row = row
	s.material = mat
	s.custom_minimum_size = crop.size
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s

# ---------------- pixel icons ----------------
static var _icons := {}

## Small 12x12 badge icons drawn in code: medal (gold/off), lock, check, star, spark_b/s/g.
static func icon(name: String) -> ImageTexture:
	if _icons.has(name): return _icons[name]
	var rows: Array
	var pal := {"k": Color("#140c24")}
	match name:
		"medal", "medal_off":
			rows = ["..rrr..bbb..", "..rrr..bbb..", "...rr.bb....", "....rbb.....", "...kkkkk....", "..kyyyyyk...",
				".kyywwyyyk..", ".kywyyyyyk..", ".kyyyyyyok..", ".kyyyyyook..", "..kyyoook...", "...kkkkk...."]
			if name == "medal":
				pal.merge({"r": Color("#d8402e"), "b": Color("#2f7de8"), "y": Color("#ffd84a"), "w": Color("#fff8d0"), "o": Color("#c89020")})
			else:
				pal.merge({"r": Color("#4a4f66"), "b": Color("#3a3f55"), "y": Color("#5a6078"), "w": Color("#7a8098"), "o": Color("#454a60")})
		"lock":
			rows = ["............", "....kkkk....", "...kggggk...", "..kgk..kgk..", "..kgk..kgk..", ".kkkkkkkkkk.",
				".kyyyyyyyyk.", ".kyyykkyyyk.", ".kyyykkyyyk.", ".kyyyyyyyyk.", ".kkkkkkkkkk.", "............"]
			pal.merge({"g": Color("#9aa2ad"), "y": Color("#c8a24a")})
		"check":
			rows = ["............", "..........kk", ".........kgk", "........kggk", ".kk....kggk.", "kggk..kggk..",
				".kggkkggk...", "..kgggggk...", "...kgggk....", "....kgk.....", ".....k......", "............"]
			pal.merge({"g": Color("#8ef58e")})
		"star", "star_off":
			rows = [".....kk.....", ".....kk.....", "....kyyk....", "kkkkkyykkkkk", ".kyyyyyyyyk.", "..kyyyyyyk..",
				"...kyyyyk...", "..kyykkyyk..", "..kyk..kyk..", ".kyk....kyk.", ".kk......kk.", "............"]
			pal.merge({"y": Color("#ffd84a") if name == "star" else Color("#4a4f66")})
		_:
			rows = ["............", "....kkkk....", "...kyyyyk...", "..kyywwyyk..", ".kyywwwwyyk.", ".kywwwwwwyk.",
				".kyywwwwyyk.", "..kyywwyyk..", "...kyyyyk...", "....kkkk....", "............", "............"]
			var c: String = {"spark_b": "#c07a40", "spark_s": "#b8c4d4", "spark_g": "#ffd84a"}.get(name, "#ffd84a")
			pal.merge({"y": Color(c), "w": Color(c).lightened(0.5)})
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in mini(12, r.length()):
			if pal.has(r[x]): img.set_pixel(x, y, SpriteForge.snes(pal[r[x]]))
	_icons[name] = ImageTexture.create_from_image(img)
	return _icons[name]

static func icon_rect(name: String, px := 1) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.custom_minimum_size = Vector2(12, 12) * px
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return t

## Coloured square badge with a letter (facilities).
class Badge extends Control:
	var col := Color.WHITE
	var letter := ""
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 16, 16), Color("#140c24"))
		draw_rect(Rect2(1, 1, 14, 14), SpriteForge.snes(col))
		draw_rect(Rect2(1, 1, 14, 1), SpriteForge.snes(col.lightened(0.35)))
		draw_rect(Rect2(1, 14, 14, 1), SpriteForge.snes(col.darkened(0.35)))
		var tc := Color("#140c24") if col.get_luminance() > 0.55 else Color.WHITE
		MiniFont.draw(self, letter, Vector2(8, 4), tc, 1, 2)

static func badge(col: Color, letter: String) -> Control:
	var b := Badge.new()
	b.col = col
	b.letter = letter.substr(0, 1).to_upper()
	b.custom_minimum_size = Vector2(16, 16)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return b

## Width of a string in the 8 px font.
static func w8(text: String) -> float:
	return UIKit.font8.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x

## One-line label that takes its natural width up to max_w, then trims with "...".
static func fit(text, col: Color = SUB, max_w := 200.0) -> Label:
	var l := small(text, col, false, true)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(minf(w8(l.text), max_w), 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l

## Give a (clipping) 8 px button its natural width so it can live in flow / shrink layouts.
static func fit_btn(b: Button, pad := 8.0) -> Button:
	b.custom_minimum_size.x = w8(b.text) + pad
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

## Text in an 8 px-padded panel strip (a "chip" that is just a label).
static func tag(text, col: Color = HL, bg: Color = Color("#2a2f55"), max_w := 190.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(bg, Color("#140c24"), 1, 2))
	var l := fit(text, col, max_w)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

# ---------------- test helpers ----------------
## First descendant Button whose meta "act" equals `act` (tests press buttons through this).
static func find_act(root: Node, act: String) -> Button:
	for c in root.get_children():
		if c is Button and c.has_meta("act") and str(c.get_meta("act")) == act: return c
		var f := find_act(c, act)
		if f != null: return f
	return null

static func act(b: Button, a: String) -> Button:
	b.set_meta("act", a)
	return b
