class_name StoryHUD
extends Control
## Story strip for the top or bottom of any screen (256 x 26): chapter number and title, the current
## objective, and a pip per objective. Updates itself from the Story autoload; hidden when no campaign
## is running. Tap it for the full objective list (emits `tapped`; `objectives_panel()` builds the list).

signal tapped()

const H := 26

var always_show := false
var _ch: Label
var _obj: Label
var _pips: Array = []
var _story: Node

func _init() -> void:
	custom_minimum_size = Vector2(0, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_ch = _lbl(UIKit.GOLD)
	_ch.position = Vector2(6, 4)
	_obj = _lbl(Color.WHITE)
	_obj.position = Vector2(6, 14)
	_story = get_node_or_null("/root/Story")
	if _story:
		_story.objectives_changed.connect(refresh)
		_story.chapter_changed.connect(_on_chapter)
		_story.story_finished.connect(refresh)
	resized.connect(refresh)
	refresh()

func _lbl(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UIKit.font8)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", DialogueBox.OUTLINE)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _on_chapter(_n: int) -> void:
	refresh()

func refresh() -> void:
	if _ch == null: return
	var on: bool = _story != null and _story.has_campaign()
	visible = on or always_show
	_pips.clear()
	if not on:
		_ch.text = "STORY MODE"
		_obj.text = "> No campaign"
		queue_redraw()
		return
	var ch: Dictionary = _story.current_chapter()
	var top := "FINALE" if bool(ch.get("finale", false)) else "CH %d/%d" % [int(ch.get("n", 1)), int(ch.get("of", 1))]
	_ch.text = ("%s %s" % [top, str(ch.get("title", ""))]).to_upper()
	_obj.text = "> " + _story.objective_text()
	if not _story.is_finished():
		for o in _story.objectives(): _pips.append(bool(o.done))
	var pw := _pips.size() * 6 + 4
	_ch.size = Vector2(size.x - 12, 9)
	_obj.size = Vector2(size.x - 12 - pw, 9)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	draw_style_box(UIKit.frame("header"), Rect2(0, 0, w, H))
	for i in _pips.size():
		var x := w - 7 - (_pips.size() - i) * 6
		draw_rect(Rect2(x, 15, 5, 5), DialogueBox.OUTLINE)
		draw_rect(Rect2(x + 1, 16, 3, 3), UIKit.OK if _pips[i] else Color("#3a4470"))
		if _pips[i]: draw_rect(Rect2(x + 1, 16, 2, 1), Color("#a8f0a8"))

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		tapped.emit()

## Full objective list for the current chapter, as a panel (checks, counts and race/tech details).
static func objectives_panel(story: Node) -> PanelContainer:
	var v := UIKit.vbox(3)
	var ch: Dictionary = story.current_chapter()
	var top := "FINALE" if bool(ch.get("finale", false)) else "CHAPTER %d of %d" % [int(ch.get("n", 1)), int(ch.get("of", 1))]
	v.add_child(UIKit.label(top, UIKit.GOLD, true))
	v.add_child(UIKit.label(str(ch.get("title", "Story")), UIKit.GOLD))
	for o in story.objectives():
		var mark := "[X] " if o.done else "[ ] "
		var cnt := "" if int(o.need) <= 1 else "  %d/%d" % [int(o.cur), int(o.need)]
		v.add_child(UIKit.label(mark + str(o.txt) + cnt, UIKit.OK if o.done else Color.WHITE))
		if str(o.detail) != "": v.add_child(UIKit.label(str(o.detail), UIKit.DIM, true))
	return UIKit.panel(v)
