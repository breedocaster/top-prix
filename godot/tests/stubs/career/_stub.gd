extends Control
## Test stand-in for a part-B career screen (the real ones live in scripts/ui/career/ and win when
## present). Same contract: fills its parent, setup(ctx), signal closed.

signal closed

var screen_name := "STUB"
var ctx := {}

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(c: Dictionary) -> void:
	ctx = c
	add_child(CareerKit.bg_rect())
	var v := CareerKit.vbox(6)
	v.position = Vector2(8, 8)
	v.size = Vector2(240, 0)
	add_child(v)
	v.add_child(CareerKit.heading(screen_name))
	var keys := []
	for k in c:
		if k != "router": keys.append("%s=%s" % [k, str(c[k]).left(24)])
	v.add_child(CareerKit.small("Part-B stub screen. ctx: " + ", ".join(keys), CareerKit.SUB))
	_extra(v)
	v.add_child(CareerKit.btn("DONE", func(): closed.emit(), UIKit.OK, false, "stub_done"))

func _extra(_v: VBoxContainer) -> void: pass
