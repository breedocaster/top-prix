class_name RevModel
extends RefCounted
## Turns race speed into engine RPM and throttle: a 5/6-speed box that revs out on straights, shifts
## up (short lift), and downshifts with throttle blips and overrun into corners.

const TOPS := [0.0, 0.26, 0.42, 0.58, 0.74, 0.88, 1.0]   # top-speed fraction per gear (6 gears)

var idle := 900.0
var red := 7000.0
var gear := 1
var gears := 6
var rpm := 900.0
var throttle := 0.3
var v_s := 0.0             # smoothed speed (the car's inertia)
var shift_t := 0.0
var blip_t := 0.0

func setup(idle_rpm: float, red_rpm: float, bike: bool) -> void:
	idle = idle_rpm; red = red_rpm
	gears = 6 if bike else 5
	rpm = idle

## speed_frac: 0..1 of a typical top speed; started: false = on the grid; boost: spark active
func step(dt: float, speed_frac: float, started: bool, done: bool, boost: bool) -> void:
	if done:
		throttle = 0.15; rpm = lerpf(rpm, idle, 1.0 - exp(-dt * 2.5)); return
	if not started:
		# staging: blip the throttle on the grid
		var target := idle + (red - idle) * (0.35 + 0.2 * sin(Time.get_ticks_msec() / 160.0))
		rpm = lerpf(rpm, target, 1.0 - exp(-dt * 6.0)); throttle = 0.7; return
	var prev := v_s
	v_s = lerpf(v_s, speed_frac, 1.0 - exp(-dt / 0.7))
	var accel: float = (v_s - prev) / max(dt, 1e-4)
	var top: float = TOPS[mini(gear, TOPS.size() - 1)] * (6.0 / gears if gears < 6 else 1.0)
	top = minf(top, 1.0)
	var frac := clampf(v_s / max(top, 0.05), 0.0, 1.05)
	if frac > 0.97 and gear < gears:
		gear += 1; shift_t = 0.12
	elif gear > 1 and frac < 0.52:
		gear -= 1; blip_t = 0.18
	var target_rpm := idle + (red - idle) * clampf(frac * 0.95, 0.0, 1.0)
	if blip_t > 0: target_rpm += (red - idle) * 0.12
	rpm = lerpf(rpm, target_rpm, 1.0 - exp(-dt * (25.0 if shift_t > 0 else 9.0)))
	if shift_t > 0:
		shift_t -= dt; throttle = 0.0
	elif accel > 0.02 or boost:
		throttle = lerpf(throttle, 1.0, 1.0 - exp(-dt * 12.0))
	elif accel < -0.03:
		throttle = lerpf(throttle, 0.0, 1.0 - exp(-dt * 10.0))
	else:
		throttle = lerpf(throttle, 0.55, 1.0 - exp(-dt * 4.0))
	blip_t = max(0.0, blip_t - dt)
	rpm = clampf(rpm, idle * 0.9, red * 1.02)
