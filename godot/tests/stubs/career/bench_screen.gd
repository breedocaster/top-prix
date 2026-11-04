extends "res://tests/stubs/career/_stub.gd"
## Bench stub: "crew tune" for the given conditions so retune flows have an effect.

func _init() -> void:
	super()
	screen_name = "BENCH"

func _extra(v: VBoxContainer) -> void:
	v.add_child(CareerKit.btn("CREW TUNE", _tune, UIKit.BTN, false, "stub_tune"))

func _tune() -> void:
	var veh := Career.veh(ctx.get("vid"))
	if not veh.is_empty() and ctx.get("cond") is Dictionary: Tune.crewTune(veh, ctx.cond, 0.97)
