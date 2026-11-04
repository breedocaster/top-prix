extends Control
## Base for the career sub-screens (part B). Screen contract: fills its parent, setup(ctx), emits
## `closed` for BACK. ctx.router (optional) has open(name, ctx) / back().
## Layout (256 px wide): header [<] TITLE  money/RP, optional tab bar, scrolling body that is rebuilt
## only when the screen's state signature changes, and a one-line message bar for Career toasts
## (ctx.no_toast = true hides it when the router shows toasts itself). Modal confirm / pick dialogs.
## Subclasses override: _title(), _tabs(), _init_screen(), _fill(body), _sig(), _head_info().

signal closed

const SK := preload("res://scripts/ui/career/sub_kit.gd")
const MiniFont := preload("res://scripts/ui/career/mini_font.gd")

var ctx: Dictionary = {}
var router = null
var tab := ""
var frame: VBoxContainer
var head_title: Label
var head_info: Label
var tab_bar: HBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var msg_panel: PanelContainer
var msg_lbl: Label
var modal: Control = null
var _msg_t := 0.0
var _sig_last := ""
var _dirty := false
var _built := false
var _gen := 0

# ---------------- overridables ----------------
func _title() -> String: return ""
func _tabs() -> Array: return []          ## [[id, label], ...]
func _init_screen() -> void: pass
func _fill(_b: VBoxContainer) -> void: pass
func _sig() -> String: return ""          ## rebuild on Career.refresh only when this changes
func _head_info() -> String:
	return "%s\nRP %d" % [SK.money(float(Career.G.get("money", 0))), int(Career.G.get("rp", 0))]

# ---------------- contract ----------------
func setup(c: Dictionary) -> void:
	ctx = c
	router = c.get("router")
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame()
	var tb := _tabs()
	if tab == "": tab = str(c.get("tab", tb[0][0] if tb.size() else ""))
	_init_screen()
	_built = true
	if not Career.refresh.is_connected(_on_refresh): Career.refresh.connect(_on_refresh)
	if not Career.toast.is_connected(_on_toast): Career.toast.connect(_on_toast)
	rebuild()

func _exit_tree() -> void:
	if Career.refresh.is_connected(_on_refresh): Career.refresh.disconnect(_on_refresh)
	if Career.toast.is_connected(_on_toast): Career.toast.disconnect(_on_toast)

func back() -> void:
	if modal != null: close_modal(); return
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()

## Open another screen through the router (no-op without one). Returns true when routed.
func go(name: String, c: Dictionary = {}) -> bool:
	if router != null and router.has_method("open"):
		router.open(name, c)
		return true
	return false

# ---------------- frame ----------------
func _frame() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]: m.add_theme_constant_override("margin_" + k, 3)
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_bottom", 3)
	add_child(m)
	frame = UIKit.vbox(3)
	m.add_child(frame)
	# header
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UIKit.sb(Color("#141a3a"), Color("#4b5ea0"), 2, 2))
	frame.add_child(hp)
	var h := UIKit.hbox(4)
	hp.add_child(h)
	var bb := SK.act(SK.btn("<", back, UIKit.BTN_LO), "back")
	bb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bb.custom_minimum_size = Vector2(26, 24)
	h.add_child(bb)
	head_title = UIKit.title(SK.ascii(_title()).to_upper())
	head_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_title.clip_text = true
	h.add_child(head_title)
	head_info = SK.small("", Color.WHITE, false)
	head_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head_info.size_flags_horizontal = Control.SIZE_SHRINK_END
	head_info.clip_text = false
	head_info.add_theme_constant_override("line_spacing", 2)
	h.add_child(head_info)
	# tabs
	tab_bar = UIKit.hbox(2)
	frame.add_child(tab_bar)
	# body
	body = UIKit.vbox(4)
	scroll = UIKit.scroll(body)
	scroll.follow_focus = false
	frame.add_child(scroll)
	# message bar
	msg_panel = PanelContainer.new()
	msg_panel.add_theme_stylebox_override("panel", UIKit.sb(Color("#0f1736"), Color("#ffd84a"), 1, 3))
	msg_lbl = SK.small("", SK.HL)
	msg_lbl.custom_minimum_size = Vector2(0, 10)
	msg_panel.add_child(msg_lbl)
	msg_panel.visible = false
	frame.add_child(msg_panel)

func set_title(t: String) -> void:
	if head_title: head_title.text = SK.ascii(t).to_upper()

func _rebuild_tabs() -> void:
	for c in tab_bar.get_children():
		tab_bar.remove_child(c); c.queue_free()
	var tb := _tabs()
	tab_bar.visible = tb.size() > 1
	for t in tb:
		var b := SK.chip(t[1], t[0] == tab, _set_tab.bind(t[0]))
		b.custom_minimum_size = Vector2(0, 22)
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var st: StyleBoxFlat = b.get_theme_stylebox(k)
			st.content_margin_left = 1; st.content_margin_right = 1
		SK.act(b, "tab:" + str(t[0]))
		tab_bar.add_child(b)

func _set_tab(t: String) -> void:
	if t == tab: return
	tab = t
	scroll.scroll_vertical = 0
	rebuild(true)

# ---------------- rebuild ----------------
## Rebuild the body (keeps the scroll position unless `top`).
func rebuild(top := false) -> void:
	if not _built: return
	var sv := 0 if top else scroll.scroll_vertical
	_gen += 1
	_rebuild_tabs()
	for c in body.get_children():
		body.remove_child(c); c.queue_free()
	_fill(body)
	_sig_last = _sig()
	update_head()
	if sv > 0: _restore_scroll.call_deferred(sv, _gen)

func _restore_scroll(v: int, gen: int) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if is_instance_valid(scroll) and gen == _gen: scroll.scroll_vertical = v

func update_head() -> void:
	if head_info: head_info.text = SK.ascii(_head_info())

func _on_refresh() -> void: _dirty = true

func _process(dt: float) -> void:
	if _dirty:
		_dirty = false
		update_head()
		if modal == null:
			var s := _sig()
			if s != _sig_last: rebuild()
	if _msg_t > 0:
		_msg_t -= dt
		if _msg_t <= 0: msg_panel.visible = false

# ---------------- messages ----------------
func _on_toast(t: String) -> void: say(t)

func say(t: String, secs := 3.0) -> void:
	if ctx.get("no_toast", false) or msg_lbl == null: return
	msg_lbl.text = SK.ascii(t)
	msg_panel.visible = true
	_msg_t = secs

# ---------------- modals ----------------
func close_modal() -> void:
	if modal != null:
		remove_child(modal); modal.queue_free(); modal = null

## Dim overlay + centred panel; returns the panel's VBox.
func open_modal(title: String) -> VBoxContainer:
	close_modal()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(c)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(UIKit.PANEL, UIKit.EDGE, 2, 6))
	p.custom_minimum_size = Vector2(236, 0)
	c.add_child(p)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var t := SK.big(title, SK.HL, true)
	v.add_child(t)
	add_child(ov)
	modal = ov
	return v

## Yes/No dialog. cb runs on yes.
func confirm(title: String, text: String, yes: String, cb: Callable, yes_col: Color = UIKit.ACCENT) -> void:
	var v := open_modal(title)
	v.add_child(SK.small(text, Color.WHITE))
	var h := UIKit.hbox(4)
	h.add_child(SK.act(SK.btn("CANCEL", close_modal, SK.GREY), "modal_no"))
	h.add_child(SK.act(SK.btn(yes, _confirm_yes.bind(cb), yes_col), "modal_yes"))
	v.add_child(h)

func _confirm_yes(cb: Callable) -> void:
	close_modal()
	cb.call()

## Scrolling pick list: items [[id, label], ...]; cb(id).
func pick(title: String, items: Array, cb: Callable) -> void:
	var v := open_modal(title)
	var lst := UIKit.vbox(3)
	for it in items:
		var b := SK.btn(it[1], _pick_done.bind(cb, it[0]), UIKit.BTN, true)
		b.custom_minimum_size = Vector2(0, 20)
		SK.act(b, "pick:" + str(it[0]))
		lst.add_child(b)
	var sc := UIKit.scroll(lst)
	sc.custom_minimum_size = Vector2(0, mini(300, items.size() * 23 + 4))
	v.add_child(sc)
	v.add_child(SK.act(SK.btn("CANCEL", close_modal, SK.GREY), "modal_no"))

func _pick_done(cb: Callable, id) -> void:
	close_modal()
	cb.call(id)
