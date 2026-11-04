class_name CreditsRoll
extends Control
## End credits: cast with their portraits, your team and the machines you built, then THE END?
## Scrolls up on its own; tap to fast-forward. Emits finished() once everything has scrolled past.

signal finished()

var speed := 26.0
var fast := 1.0
## {team, machines: [names], crew: [char ids], rivals: [char ids], chars: {id: {full, role}}}
var info := {}

var _content: VBoxContainer
var _y := 0.0
var _done := false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIKit.theme()

func setup(i: Dictionary) -> void:
	info = i

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#080614")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_content = UIKit.vbox(6)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_build()
	_content.position = Vector2(0, size.y)
	_content.size = Vector2(size.x, _content.get_combined_minimum_size().y)
	_y = size.y

func _center(t: String, c: Color = Color.WHITE, small := false) -> Label:
	var l := UIKit.label(t, c, small)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l

func _gap(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(c)

func _person(id: String, flip: bool) -> void:
	var c: Dictionary = info.get("chars", {}).get(id, {})
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = Portraits.tex(id, "happy")
	pic.flip_h = flip
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.custom_minimum_size = Vector2(48, 48)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	v.custom_minimum_size = Vector2(150, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIKit.label(str(c.get("full", id)), Color(str(c.get("col", "#ffffff"))))
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(n)
	v.add_child(UIKit.label(str(c.get("role", "")), UIKit.DIM, true))
	if flip:
		row.add_child(v)
		row.add_child(pic)
	else:
		row.add_child(pic)
		row.add_child(v)
	_content.add_child(row)

func _build() -> void:
	_gap(24)
	var t := UIKit.title("TOP PRIX")
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(t)
	_center("STORY MODE", UIKit.DIM, true)
	_center("The Crownwell Cup")
	_gap(28)
	_center("STARRING", UIKit.GOLD, true)
	_center(str(info.get("team", "Your team")))
	_gap(20)
	_center("THE CREW", UIKit.GOLD, true)
	for id in info.get("crew", []): _person(id, false)
	_gap(20)
	_center("THE CROWNWELLS", UIKit.GOLD, true)
	for id in info.get("rivals", []): _person(id, true)
	_gap(20)
	_center("THE MACHINES", UIKit.GOLD, true)
	var ms: Array = info.get("machines", [])
	if ms.is_empty(): _center("Every machine you built.", Color.WHITE, true)
	for m in ms.slice(0, 12): _center(str(m), Color.WHITE, true)
	_gap(20)
	_center("TINPLATE, INDIANA", UIKit.GOLD, true)
	_center("Pop. 1,204", Color.WHITE, true)
	_center("and one retired raccoon", UIKit.DIM, true)
	_gap(20)
	_center("Thanks for playing!")
	_gap(160)
	var e := UIKit.title("THE END?")
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(e)
	_center("Free play continues.", UIKit.DIM, true)
	_gap(40)

func _process(delta: float) -> void:
	if _done or _content == null: return
	_y -= speed * fast * delta
	_content.position = Vector2(0, roundf(_y))
	_content.size = Vector2(size.x, _content.get_combined_minimum_size().y)
	if _y + _content.size.y < 0:
		_done = true
		finished.emit()

## Jump to a point in the roll (0 = start, 1 = everything scrolled past).
func skip_to(frac: float) -> void:
	_content.size = Vector2(size.x, _content.get_combined_minimum_size().y)
	_y = size.y - (_content.size.y + size.y) * clampf(frac, 0, 1)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		fast = 1.0 if fast > 1.0 else 6.0
