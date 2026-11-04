class_name CareerKit
extends RefCounted
## Shared look for the career screens (not a screen itself): SNES window / card frames baked into
## 9-slice textures once, ASCII-safe labels (DotGothic16 16 px, PressStart2P 8 px), card buttons,
## chips, bars, section rules and the tiled menu background. Everything here is built on demand;
## nothing draws per frame except the few _draw() widgets, which only redraw when told to.

const TXT := Color("#eef1fa")
const SUB := Color("#9aa6c8")
const DIMC := Color("#6a769a")
const MONEY := Color("#9dffa8")
const RPC := Color("#7ac8ff")
const FANC := Color("#ff9fcf")
const BAD := Color("#ff7a7a")
const WARN := Color("#ffb04a")
const GOOD := Color("#8ef58e")
const OUTLINE := Color("#140c24")
const STAT_N := {"spd": "SPD", "acc": "ACC", "hnd": "HND", "dur": "DUR"}
const STAT_LONG := {"spd": "Speed", "acc": "Acceleration", "hnd": "Handling", "dur": "Durability"}
const STAT_COL := {"spd": Color("#ff8a5c"), "acc": Color("#ffd84a"), "hnd": Color("#7ac8ff"), "dur": Color("#8ef58e")}
const TERR_SHORT := {"on": "ON", "off": "OFF", "wet": "WET", "ice": "ICE"}
const SPARK_COL := {"b": Color("#e0975a"), "s": Color("#c8d0dc"), "g": Color("#ffd84a")}
const SPARK_N := {"b": "Bronze", "s": "Silver", "g": "Gold"}
const RANK_COL := {"E": Color("#9aa6c8"), "D": Color("#8ef58e"), "C": Color("#7ac8ff"), "B": Color("#c890ff"), "A": Color("#ffb04a"), "S": Color("#ff6a6a")}
const REPL := {"—": "-", "–": "-", "·": "|", "×": "x", "°": "", "→": ">", "…": "...", "’": "'",
	"‘": "'", "“": "\"", "”": "\"", "★": "*", "☆": ".", "✓": "+", "✔": "+", "⚠": "!", "≈": "~",
	"↑": "+", "↓": "-", "≤": "<=", "≥": ">=", "é": "e", "è": "e", "ü": "u", "ö": "o", "ä": "a"}

static var _sb_cache := {}
static var _bg: ImageTexture

# ---------------- text ----------------
## ASCII-only copy of any text (game data carries em dashes, middle dots, emoji icons).
static func asc(s) -> String:
	var t := str(s)
	var clean := true
	for i in t.length():
		var c := t.unicode_at(i)
		if c > 126 or (c < 32 and c != 10):
			clean = false
			break
	if clean: return t
	for k in REPL: t = t.replace(k, REPL[k])
	var out := PackedStringArray()
	for i in t.length():
		var c := t.unicode_at(i)
		if (c >= 32 and c <= 126) or c == 10: out.append(char(c))
	return "".join(out).strip_edges().replace("  ", " ")

static func money(v) -> String: return U.money(float(v))

## "Downdraft 2-Barrel 350", "Round-Slide 30": carb names without the "(XX-style)" tail.
static func carb_short(id: String) -> String:
	return str(Data.D.CARBS.get(id, {}).get("n", id)).split(" (")[0]

static func _fonts() -> void:
	if UIKit.font == null: UIKit.theme()

## Label: big = DotGothic16 16 px, else PressStart2P 8 px. wrap=false clips to one line.
static func lbl(text, col: Color = TXT, big := false, wrap := true) -> Label:
	_fonts()
	var l := Label.new()
	l.text = asc(text)
	l.add_theme_color_override("font_color", col)
	if big:
		l.add_theme_font_override("font", UIKit.font)
		l.add_theme_font_size_override("font_size", 16)
	else:
		l.add_theme_font_override("font", UIKit.font8)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_constant_override("line_spacing", 3)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

## Size a label / button to its text (no clipping) and pack it at the start (or end) of a row.
static func shrink(c: Control, end := false) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_END if end else Control.SIZE_SHRINK_BEGIN
	if c is Label:
		(c as Label).clip_text = false
		(c as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	elif c is Button: (c as Button).clip_text = false
	return c

## One-line label sized to its text (for rows of short tags).
static func tag(text, col: Color = SUB, big_font := false) -> Label:
	var l := lbl(text, col, big_font, false)
	shrink(l)
	return l

static func small(text, col: Color = SUB) -> Label: return lbl(text, col, false, true)
static func line(text, col: Color = SUB) -> Label: return lbl(text, col, false, false)
static func big(text, col: Color = TXT) -> Label: return lbl(text, col, true, false)

## Outlined gold heading (PressStart2P 16 px) like UIKit.title, but ASCII-safe and clipped.
static func heading(text, col: Color = UIKit.GOLD) -> Label:
	_fonts()
	var l := Label.new()
	l.text = asc(text)
	l.add_theme_font_override("font", UIKit.font8)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------------- frames ----------------
## 9-slice frames: "win" (SNES window: outline, double light border, banded blue gradient),
## "card", "card_sel", "card_dim", "card_gold", "card_red", "hud", "chip".
static func sb(kind: String) -> StyleBox:
	if _sb_cache.has(kind): return _sb_cache[kind]
	var s := StyleBoxTexture.new()
	var img: Image
	var m := 4
	match kind:
		"win":
			img = _frame_img(16, 64, Color("#2c3f9e"), Color("#0e1748"), Color("#f2f2ee"), Color("#8a96b8"), 8)
			s.content_margin_left = 8; s.content_margin_right = 8; s.content_margin_top = 7; s.content_margin_bottom = 7
		"hud":
			img = _frame_img(12, 24, Color("#22328a"), Color("#141d58"), Color("#f2f2ee"), Color("#5a68a8"), 3)
			s.content_margin_left = 5; s.content_margin_right = 5; s.content_margin_top = 3; s.content_margin_bottom = 3
		"card_sel":
			img = _frame_img(12, 12, Color("#26357a"), Color("#1c2864"), UIKit.GOLD, Color("#a08420"), 1)
			m = 3
		"card_dim":
			img = _frame_img(12, 12, Color("#161a2c"), Color("#161a2c"), Color("#3a405a"), Color("#262a40"), 1)
			m = 3
		"card_gold":
			img = _frame_img(12, 12, Color("#3a3216"), Color("#2a2410"), UIKit.GOLD, Color("#806a20"), 1)
			m = 3
		"card_red":
			img = _frame_img(12, 12, Color("#3a1620"), Color("#2a1018"), Color("#ff7a7a"), Color("#80303a"), 1)
			m = 3
		"chip":
			img = _frame_img(8, 8, Color("#22408a"), Color("#22408a"), Color("#5a78c8"), Color("#22408a"), 1)
			m = 2
		_:
			img = _frame_img(12, 12, Color("#18224e"), Color("#121a40"), Color("#5a6aa8"), Color("#2a3870"), 1)
			m = 3
	if not kind in ["win", "hud"]:
		s.content_margin_left = 5; s.content_margin_right = 5; s.content_margin_top = 4; s.content_margin_bottom = 4
		if kind == "chip":
			s.content_margin_left = 4; s.content_margin_right = 4; s.content_margin_top = 2; s.content_margin_bottom = 2
	s.texture = ImageTexture.create_from_image(img)
	s.texture_margin_left = m; s.texture_margin_right = m; s.texture_margin_top = m; s.texture_margin_bottom = m
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_sb_cache[kind] = s
	return s

## Frame image: 1 px outline, `bw` px light edge (+1 px darker inner edge), banded gradient fill.
static func _frame_img(w: int, h: int, top: Color, bottom: Color, edge: Color, edge2: Color, bands: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	var inner := Rect2i(1, 1, w - 2, h - 2)
	img.fill_rect(inner, SpriteForge.snes(edge))
	var b := 2 if w >= 16 else 1
	img.fill_rect(inner.grow(-b + 1).grow(-1), SpriteForge.snes(edge2))
	var fill := inner.grow(-b)
	if w >= 16: fill = fill.grow(-1)
	var n := maxi(1, bands)
	for i in n:
		var y0 := fill.position.y + int(floor(fill.size.y * float(i) / n))
		var y1 := fill.position.y + int(floor(fill.size.y * float(i + 1) / n))
		img.fill_rect(Rect2i(fill.position.x, y0, fill.size.x, y1 - y0), SpriteForge.snes(top.lerp(bottom, float(i) / maxf(1, n - 1))))
	return img

static func panel(child: Control, kind := "card") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(kind))
	p.add_child(child)
	return p

## A tappable card: `content` laid out normally with a transparent Button stretched over it.
## The Button carries meta "tid" (tests find it by that id or by `tid_text`).
static func card_btn(content: Control, cb: Callable, kind := "card", dis := false, tid := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb("card_dim" if dis and kind == "card" else kind))
	p.add_child(content)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = dis
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var clear := StyleBoxEmpty.new()
	for st in ["normal", "disabled", "focus"]: b.add_theme_stylebox_override(st, clear)
	var hov := StyleBoxFlat.new(); hov.bg_color = Color(1, 1, 1, 0.07)
	var prs := StyleBoxFlat.new(); prs.bg_color = Color(1, 1, 1, 0.14)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_stylebox_override("hover_pressed", prs)
	if cb.is_valid(): b.pressed.connect(cb)
	if tid != "": b.set_meta("tid", tid)
	p.add_child(b)
	return p

## Standard button (UIKit look) that never grows past its text; `small` uses the 8 px font.
static func btn(text, cb: Callable, col: Color = UIKit.BTN, small_font := false, tid := "") -> Button:
	var b := UIKit.btn(asc(text), cb, col)
	if small_font:
		b.add_theme_font_override("font", UIKit.font8)
		b.add_theme_font_size_override("font_size", 8)
		b.custom_minimum_size = Vector2(16, 18)
	if tid != "": b.set_meta("tid", tid)
	return b

## Toggle chip (8 px font). on = gold.
static func chip(text, cb: Callable, on := false, dis := false, tid := "") -> Button:
	_fonts()
	var b := Button.new()
	b.text = asc(text)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = dis
	b.add_theme_font_override("font", UIKit.font8)
	b.add_theme_font_size_override("font_size", 8)
	b.custom_minimum_size = Vector2(0, 18)
	var c := UIKit.GOLD.darkened(0.35) if on else Color("#22408a")
	b.add_theme_stylebox_override("normal", UIKit.sb(c, OUTLINE, 1, 4))
	b.add_theme_stylebox_override("hover", UIKit.sb(c.lightened(0.15), OUTLINE, 1, 4))
	b.add_theme_stylebox_override("pressed", UIKit.sb(c.darkened(0.2), OUTLINE, 1, 4))
	b.add_theme_stylebox_override("hover_pressed", UIKit.sb(c.darkened(0.2), OUTLINE, 1, 4))
	b.add_theme_stylebox_override("disabled", UIKit.sb(Color("#262a40"), OUTLINE, 1, 4))
	b.add_theme_color_override("font_color", Color.WHITE if not on else Color("#fff6c8"))
	b.add_theme_color_override("font_disabled_color", DIMC)
	if cb.is_valid(): b.pressed.connect(cb)
	if tid != "": b.set_meta("tid", tid)
	return b

static func vbox(sep := 3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func flow(sep := 3) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

static func gap(h := 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Section rule: "-- TITLE ------------" in gold 8 px.
static func sec(text, col: Color = UIKit.GOLD) -> Control:
	var h := hbox(4)
	var l := lbl(text, col, false, false)
	CareerKit.shrink(l)
	h.add_child(l)
	var r := Rule.new()
	r.col = col.darkened(0.45)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(r)
	h.custom_minimum_size = Vector2(0, 12)
	return h

## Two labels on one line: left (expands, clipped) and right (shrinks).
static func pair(left, right, lc: Color = TXT, rc: Color = SUB, big_left := false) -> HBoxContainer:
	var h := hbox(4)
	var a := lbl(left, lc, big_left, false)
	h.add_child(a)
	var b := lbl(right, rc, false, false)
	CareerKit.shrink(b, true)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	return h

class Rule extends Control:
	var col := Color("#5a4a20")
	func _init() -> void:
		custom_minimum_size = Vector2(8, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := floorf(size.y / 2.0)
		draw_rect(Rect2(0, y, size.x, 1), col)

## Horizontal bar with an outline; frac 0..1.
class Bar extends Control:
	var frac := 0.0
	var col := Color("#8ef58e")
	var back := Color("#0a0e24")
	func _init() -> void:
		custom_minimum_size = Vector2(24, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_frac(f: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-0.0)
		draw_rect(r, Color("#140c24"))
		draw_rect(r.grow(-1), back)
		var w := floorf((size.x - 2) * frac)
		if w > 0:
			draw_rect(Rect2(1, 1, w, size.y - 2), col)
			draw_rect(Rect2(1, 1, w, 1), col.lightened(0.35))

static func bar(frac: float, col: Color, w := 0, h := 6) -> Bar:
	var b := Bar.new()
	b.frac = clampf(frac, 0.0, 1.0)
	b.col = col
	b.custom_minimum_size = Vector2(w if w > 0 else 24, h)
	if w <= 0: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## "SPD [=======    ] 123"
static func stat_bar(k: String, v: float, mx: float) -> HBoxContainer:
	var h := hbox(4)
	var a := lbl(STAT_N.get(k, k.to_upper()), STAT_COL.get(k, TXT), false, false)
	a.custom_minimum_size = Vector2(26, 0)
	CareerKit.shrink(a)
	h.add_child(a)
	h.add_child(bar(v / maxf(1.0, mx), STAT_COL.get(k, TXT), 0, 7))
	var n := lbl(str(int(round(v))), TXT, false, false)
	n.custom_minimum_size = Vector2(34, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	CareerKit.shrink(n, true)
	h.add_child(n)
	return h

## Stat scale for bars at the current workshop (web UI.statMax).
static func stat_max() -> float:
	return float([0, 140, 260, 520, 900, 1200][clampi(int(Career.G.get("ws", 1)), 0, 5)])

static func terr_col(x: float) -> Color:
	if x >= 115: return GOOD
	if x < 70: return BAD
	return TXT

## "ON 100  OFF 55  WET 85  ICE 55" (tight: "ON100 OFF55 ..."), coloured by grip.
static func terr_row(t: Dictionary, tight := false) -> HBoxContainer:
	var h := hbox(4 if tight else 6)
	for k in ["on", "off", "wet", "ice"]:
		var l := lbl(("%s%d" if tight else "%s %d") % [TERR_SHORT[k], int(round(float(t.get(k, 0))))], terr_col(float(t.get(k, 0))), false, false)
		CareerKit.shrink(l)
		h.add_child(l)
	return h

## Mixture per throttle zone as a 2x2 grid: "IDLE RICH  LOW TARGET / MID LEAN  WOT 12.8" (AFR with a wideband).
static func zone_grid(lam: Dictionary, wb: bool) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 2)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for z in Tune.ZONES:
		var x: float = float(lam.get(z, 0.9))
		var zl: Array = Tune.zoneLabel(x, z)
		var word := str(zl[0]).to_upper()
		if word == "ON TARGET": word = "TARGET"
		g.add_child(tag("%-4s %s" % [str(z).to_upper(), ("%.1f AFR" % Tune.afr(x)) if wb else word], Color(str(zl[1]))))
	return g

## 2x2 "SPD 28  ACC 30 / HND 30  DUR 46" in the stat colours.
static func stat_grid(s: Dictionary) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 2)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["spd", "acc", "hnd", "dur"]:
		g.add_child(tag("%s %d" % [STAT_N[k], int(round(float(s.get(k, 0))))], STAT_COL[k]))
	return g

## Surface mix strip for a race.
class SurfBar extends Control:
	var segs: Array = []      # [[weight, Color], ...]
	func _init() -> void:
		custom_minimum_size = Vector2(24, 5)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var tot := 0.0
		for s in segs: tot += float(s[0])
		draw_rect(Rect2(Vector2.ZERO, size), Color("#140c24"))
		var x := 1.0
		var w := size.x - 2
		for s in segs:
			var sw := roundf(w * float(s[0]) / maxf(1.0, tot))
			draw_rect(Rect2(x, 1, minf(sw, size.x - 1 - x), size.y - 2), s[1])
			x += sw

static func surf_bar(r: Dictionary) -> SurfBar:
	var s := SurfBar.new()
	for k in r.surf: s.segs.append([float(r.surf[k]), Color(str(Data.D.SURF[k].col))])
	return s

## Rank badge text colour.
static func rank_col(rk: String) -> Color: return RANK_COL.get(rk, TXT)

## Odds label [text, Color] for a ratio.
static func odds(r: float) -> Array:
	var o: Array = Career.oddsLabel(r)
	return [str(o[0]), Color(str(o[1]))]

## Tiled two-tone background (SNES menu pattern), shared.
static func bg_tex() -> ImageTexture:
	if _bg: return _bg
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var a := SpriteForge.snes(Color("#0b1030"))
	var b := SpriteForge.snes(Color("#0e1438"))
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, b if ((x + y) % 16 < 8) != ((x - y + 16) % 16 < 8) else a)
	_bg = ImageTexture.create_from_image(img)
	return _bg

static func bg_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture = bg_tex()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Remove and free every child.
static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

## Spark selector chips (None / Bronze xN / ...) for builds, upgrades and training. cb(kind) with "" = none.
static func spark_row(cur: String, cb: Callable) -> Control:
	var G: Dictionary = Career.G
	var sp: Dictionary = G.get("sparks", {})
	var f := flow(3)
	var have := false
	for k in ["b", "s", "g"]:
		if int(sp.get(k, 0)) > 0: have = true
	if not have: return f
	var l := lbl("Use a Spark?", SUB, false, false)
	CareerKit.shrink(l)
	f.add_child(l)
	f.add_child(chip("None", cb.bind(""), cur == ""))
	for k in ["b", "s", "g"]:
		if int(sp.get(k, 0)) > 0:
			f.add_child(chip("%s x%d" % [SPARK_N[k], int(sp[k])], cb.bind(k), cur == k, false, "spark_" + k))
	return f

## Find a visible button by tid meta or by (case-insensitive) text prefix; tests and the router use it.
static func find_button(root: Node, key: String) -> BaseButton:
	var stack: Array = [root]
	var k := key.to_lower()
	var found: BaseButton = null
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible: continue
		if n is BaseButton:
			var b: BaseButton = n
			if str(b.get_meta("tid", "")) == key or str(b.get_meta("act", "")) == key: return b
			if found == null and b is Button and (b as Button).text.to_lower().begins_with(k) and k != "": found = b
		var ch := n.get_children()
		for i in range(ch.size() - 1, -1, -1): stack.append(ch[i])
	return found
