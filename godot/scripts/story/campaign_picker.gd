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
	add_child(UIKit.bg_rect())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + k, 4)
	add_child(m)
	var v := UIKit.vbox(5)
	m.add_child(v)
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UIKit.frame_new("header", 6, 4, 6, 4))
	hp.add_child(CareerKit.lbl("STORY MODE", UIKit.GOLD, true, false))
	v.add_child(hp)
	var intro := UIKit.vbox(4)
	v.add_child(UIKit.window(intro))
	var faces := UIKit.hbox(4)
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in ["hazel", "rosie", "dewey"]:
		var t := TextureRect.new()
		t.texture = Portraits.tex(id, "happy")
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(48, 48)
		faces.add_child(_framed(t))
	var foe := TextureRect.new()
	foe.texture = Portraits.tex("victoria", "neutral")
	foe.flip_h = true
	foe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foe.custom_minimum_size = Vector2(48, 48)
	var vs := UIKit.label("VS", UIKit.ACCENT, true)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	faces.add_child(vs)
	faces.add_child(_framed(foe, true))
	intro.add_child(faces)
	intro.add_child(UIKit.label("Great-Uncle Augie left you a shed in Tinplate, Indiana. The Crownwells want it. Race them for it.", Color("#e4e8f6"), true))
	var opts := UIKit.vbox(4)
	v.add_child(UIKit.scroll(opts))
	var story := get_node_or_null("/root/Story")
	var lens: Dictionary = story.lengths if story else {}
	for id in ORDER:
		if not lens.has(id): continue
		var L: Dictionary = lens[id]
		var card := UIKit.vbox(3)
		var b := UIKit.btn("%s  %s" % [str(L.n).to_upper(), str(L.time)], _pick.bind(id), [UIKit.OK, UIKit.BTN, UIKit.ACCENT][ORDER.find(id)])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_child(b)
		card.add_child(UIKit.label("%d chapters. %s" % [(L.chapters as Array).size(), str(L.d)], Color("#c8d0e8"), true))
		opts.add_child(UIKit.window(card, "card"))
	opts.add_child(UIKit.label("Free play continues after the ending. Machines you build race in LAN multiplayer too.", UIKit.GOLD, true))
	v.add_child(UIKit.btn("BACK", func(): cancelled.emit(), UIKit.BTN_LO))

## Portrait in a small sunken frame (red edge for the rival).
func _framed(t: TextureRect, foe := false) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.frame_new("card_red" if foe else "inset", 2, 2, 2, 2))
	p.add_child(t)
	return p

func _pick(id: String) -> void:
	picked.emit(id)
