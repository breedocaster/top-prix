class_name CampaignPicker
extends Control
## "Choose your campaign" screen: premise, the crew, and Short / Medium / Long with their play time,
## chapter count and what each adds. Emits picked(length) or cancelled().

signal picked(length: String)
signal cancelled()

const ORDER := ["short", "medium", "long"]

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIKit.theme()

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + k, 6)
	add_child(m)
	var v := UIKit.vbox(4)
	m.add_child(v)
	v.add_child(UIKit.title("STORY MODE"))
	var faces := UIKit.hbox(4)
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in ["hazel", "rosie", "dewey"]:
		var t := TextureRect.new()
		t.texture = Portraits.tex(id, "happy")
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(48, 48)
		faces.add_child(t)
	var foe := TextureRect.new()
	foe.texture = Portraits.tex("victoria", "neutral")
	foe.flip_h = true
	foe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foe.custom_minimum_size = Vector2(48, 48)
	faces.add_child(foe)
	v.add_child(faces)
	v.add_child(UIKit.label("Great-Uncle Augie left you a shed in Tinplate, Indiana. The Crownwells want it. Race them for it.", Color("#c8d0e8")))
	var story := get_node_or_null("/root/Story")
	var lens: Dictionary = story.lengths if story else {}
	for id in ORDER:
		if not lens.has(id): continue
		var L: Dictionary = lens[id]
		var b := UIKit.btn("%s  %s" % [str(L.n).to_upper(), str(L.time)], _pick.bind(id), [UIKit.OK, UIKit.BTN, UIKit.ACCENT][ORDER.find(id)])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
		v.add_child(UIKit.label("%d chapters. %s" % [(L.chapters as Array).size(), str(L.d)], UIKit.DIM, true))
	v.add_child(UIKit.label("Free play continues after the ending. Machines you build race in LAN multiplayer too.", UIKit.GOLD, true))
	v.add_child(UIKit.btn("BACK", func(): cancelled.emit(), UIKit.BTN_LO))

func _pick(id: String) -> void:
	picked.emit(id)
