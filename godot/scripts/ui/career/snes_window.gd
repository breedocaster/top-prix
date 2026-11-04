class_name SnesWindow
extends Control
## Modal SNES-style window (not a screen): dims what is behind it, shows a framed window with a title,
## a body (text and/or Controls) and buttons. Buttons are dictionaries:
##   {t: label, cb: Callable (optional), col: Color, dis: bool, sub: "second line" or [lines], keep: bool, tid: String}
## Buttons with `sub` render as option cards (name + detail lines); the rest as a button grid.
## The window scrolls when taller than the screen. Emits closed(index) (-1 = dismissed).

signal closed(index: int)

const W := 244
var title := ""
var kind := ""                 # free tag for the router (popup kind, "build:<vid>", ...)
var cancel_index := -1         # button index used for the Android back key (-1: back does nothing)

var _win: PanelContainer
var _scroll: ScrollContainer
var _inner: VBoxContainer
var _last_h := -1.0
var _buttons: Array = []
var _done := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

## body: String, Control, or Array of (String | Control). Strings render as wrapped 8 px text.
func build(t: String, body, buttons: Array, title_col: Color = UIKit.GOLD) -> SnesWindow:
	title = t
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.01, 0.08, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_win = PanelContainer.new()
	_win.add_theme_stylebox_override("panel", CareerKit.sb("win"))
	_win.custom_minimum_size = Vector2(W, 0)
	add_child(_win)
	var root := CareerKit.vbox(4)
	_win.add_child(root)
	if t != "":
		var tl := CareerKit.lbl(t, title_col, true, true)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.add_theme_color_override("font_shadow_color", CareerKit.OUTLINE)
		tl.add_theme_constant_override("shadow_offset_x", 1)
		tl.add_theme_constant_override("shadow_offset_y", 1)
		root.add_child(tl)
		var r := CareerKit.Rule.new()
		r.col = Color("#8a96b8")
		r.custom_minimum_size = Vector2(0, 3)
		root.add_child(r)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_scroll)
	_inner = CareerKit.vbox(4)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_inner)
	var parts: Array = body if body is Array else [body]
	for p in parts:
		if p is Control: _inner.add_child(p)
		elif str(p) != "":
			_inner.add_child(CareerKit.lbl(str(p), Color("#e4e8f6"), false, true))
	if not buttons.is_empty():
		_inner.add_child(CareerKit.gap(2))
		var grid: HBoxContainer = null
		for i in buttons.size():
			var bd: Dictionary = buttons[i]
			var dis := bool(bd.get("dis", false))
			if bd.has("sub"):
				grid = null
				var v := CareerKit.vbox(1)
				var th := CareerKit.hbox(4)
				th.add_child(CareerKit.lbl(str(bd.t), CareerKit.DIMC if dis else Color.WHITE, true, false))
				if str(bd.get("tag", "")) != "":
					var tg := CareerKit.tag(str(bd.tag), UIKit.GOLD)
					CareerKit.shrink(tg, true)
					tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					th.add_child(tg)
				v.add_child(th)
				var subs: Array = bd.sub if bd.sub is Array else [bd.sub]
				for sl in subs:
					if sl is Array:
						v.add_child(CareerKit.lbl(str(sl[0]), CareerKit.DIMC if dis else sl[1], false, true))
					elif str(sl) != "":
						v.add_child(CareerKit.lbl(str(sl), CareerKit.DIMC if dis else CareerKit.SUB, false, true))
				var card := CareerKit.card_btn(v, _press.bind(i), str(bd.get("kind", "card")), dis, str(bd.get("tid", "")))
				_inner.add_child(card)
				_buttons.append(card.get_child(1))
			else:
				var b := CareerKit.btn(str(bd.t), _press.bind(i), bd.get("col", UIKit.BTN), false, str(bd.get("tid", "")))
				b.disabled = dis
				b.custom_minimum_size = Vector2(0, 26)
				if bool(bd.get("wide", false)) or buttons.size() == 1 or str(bd.t).length() > 12:
					grid = null
					_inner.add_child(b)
				else:
					if grid == null or grid.get_child_count() >= 2:
						grid = CareerKit.hbox(4)
						_inner.add_child(grid)
					grid.add_child(b)
				_buttons.append(b)
	_buttons_def = buttons
	return self

var _buttons_def: Array = []

func _ready() -> void:
	_fit()

func _process(_d: float) -> void:
	_fit()

## Keep the window centred and as tall as its content (scrolling past the screen height).
func _fit() -> void:
	if _win == null: return
	var want := _inner.get_combined_minimum_size().y
	var vp := size if size.y > 0 else get_viewport_rect().size
	var head := 0.0
	for c in _win.get_child(0).get_children():
		if c != _scroll: head += c.get_combined_minimum_size().y + 4
	var maxh := vp.y - 16 - head - 14
	var h := minf(want, maxh)
	if absf(h - _last_h) > 0.5:
		_last_h = h
		_scroll.custom_minimum_size = Vector2(0, h)
	var ws := _win.get_combined_minimum_size()
	_win.size = Vector2(W, ws.y)
	_win.position = Vector2(roundf((vp.x - W) / 2.0), roundf(maxf(6.0, (vp.y - ws.y) / 2.0)))

func _press(i: int) -> void:
	if _done: return
	var bd: Dictionary = _buttons_def[i] if i >= 0 and i < _buttons_def.size() else {}
	if bool(bd.get("dis", false)): return
	var keep := bool(bd.get("keep", false))
	_done = true
	var cb = bd.get("cb")
	if cb is Callable and (cb as Callable).is_valid():
		var r = (cb as Callable).call()
		if r is bool and r == false: keep = true      # the action didn't happen: stay open
	if keep:
		_done = false
		return
	close(i)

## Press button i (tests, Android back).
func press(i: int) -> void: _press(i)

func button_count() -> int: return _buttons_def.size()
func button_def(i: int) -> Dictionary: return _buttons_def[i]

func close(i := -1) -> void:
	_done = true
	if is_inside_tree():
		closed.emit(i)
		queue_free()

func dismiss() -> void:
	if cancel_index >= 0: _press(cancel_index)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton or e is InputEventScreenTouch: accept_event()
