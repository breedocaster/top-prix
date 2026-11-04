class_name CareerPage
extends Control
## Base for the part-A career sub-screens (build, machines, vehicle, races, prerace): the screen
## contract (`setup(ctx)`, `closed`) plus a standard frame: header bar (back, title, money), optional
## tab row, a scrolling body and a pinned footer. Subclasses override _init_page() and _render(),
## and call refresh() after any action (the router also calls it when the page is shown again).

signal closed

var router = null
var ctx: Dictionary = {}
var tab := ""
var body: VBoxContainer
var scroll: ScrollContainer
var footer: VBoxContainer
var top_box: VBoxContainer     ## pinned above the tabs; not cleared by refresh()
var tabs_row: HBoxContainer
var _title: Label
var _money: Label
var _tabs: Array = []          # [[id, label], ...]

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(c: Dictionary) -> void:
	ctx = c
	router = c.get("router")
	tab = str(c.get("tab", ""))
	_frame()
	_init_page()
	if tab == "" and not _tabs.is_empty(): tab = str(_tabs[0][0])
	_render_tabs()
	_render()

## Virtual: read ctx, set the title and tabs (set_tabs) before the first render.
func _init_page() -> void: pass
## Virtual: fill `body` (already cleared) and `footer`.
func _render() -> void: pass
## Virtual: back pressed. Return false to stay (e.g. after showing a confirm window).
func _on_back() -> bool: return true

func refresh() -> void:
	if body == null: return
	var sv := scroll.scroll_vertical
	CareerKit.clear(body)
	CareerKit.clear(footer)
	_money.text = U.money(float(Career.G.get("money", 0)))
	_money.add_theme_color_override("font_color", CareerKit.BAD if float(Career.G.get("money", 0)) < 0 else CareerKit.MONEY)
	_render_tabs()
	_render()
	_restore_scroll.call_deferred(sv)

func _restore_scroll(v: int) -> void:
	if scroll: scroll.scroll_vertical = v

func set_title(t: String) -> void:
	if _title: _title.text = CareerKit.asc(t)

func set_tabs(list: Array) -> void:
	_tabs = list

func go_tab(id: String) -> void:
	tab = id
	scroll.scroll_vertical = 0
	refresh()

func close() -> void:
	closed.emit()

func back() -> void:
	if _on_back(): close()

func _frame() -> void:
	CareerKit.clear(self)
	add_child(CareerKit.bg_rect())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]: m.add_theme_constant_override("margin_" + k, 4)
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_bottom", 4)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var root := CareerKit.vbox(4)
	m.add_child(root)
	var head := CareerKit.hbox(4)
	var hp := CareerKit.panel(head, "hud")
	root.add_child(hp)
	var bk := CareerKit.btn("<", back, UIKit.BTN_LO, false, "back")
	bk.custom_minimum_size = Vector2(26, 22)
	CareerKit.shrink(bk)
	head.add_child(bk)
	_title = CareerKit.lbl("", UIKit.GOLD, true, false)
	_title.add_theme_color_override("font_shadow_color", CareerKit.OUTLINE)
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_money = CareerKit.lbl(U.money(float(Career.G.get("money", 0))), CareerKit.MONEY, false, false)
	CareerKit.shrink(_money, true)
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_money)
	top_box = CareerKit.vbox(3)
	root.add_child(top_box)
	tabs_row = CareerKit.hbox(3)
	root.add_child(tabs_row)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	root.add_child(scroll)
	body = CareerKit.vbox(4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	footer = CareerKit.vbox(4)
	root.add_child(footer)

func _render_tabs() -> void:
	CareerKit.clear(tabs_row)
	tabs_row.visible = not _tabs.is_empty()
	for t in _tabs:
		var on: bool = str(t[0]) == tab
		var b := CareerKit.chip(str(t[1]), go_tab.bind(str(t[0])), on, false, "tab_" + str(t[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 20)
		tabs_row.add_child(b)

# ---------------- helpers for subclasses ----------------
func add(c: Control) -> Control:
	body.add_child(c)
	return c

func note(text: String, col: Color = CareerKit.SUB) -> Label:
	var l := CareerKit.small(text, col)
	body.add_child(l)
	return l

func confirm(t: String, text: String, yes: String, cb: Callable, col: Color = UIKit.ACCENT) -> void:
	if router: router.confirm(t, text, yes, cb, col)
	else: cb.call()

func open(name: String, c := {}) -> void:
	if router: router.open(name, c)

func can_open(name: String) -> bool:
	return router != null and router.has_screen(name)
