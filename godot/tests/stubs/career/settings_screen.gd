extends "res://tests/stubs/career/_stub.gd"

func _init() -> void:
	super()
	screen_name = "SETTINGS"

func _extra(v: VBoxContainer) -> void:
	v.add_child(CareerKit.btn("QUIT TO TITLE", func(): ctx.router.quit_to_title(), UIKit.ACCENT, false, "stub_quit"))
