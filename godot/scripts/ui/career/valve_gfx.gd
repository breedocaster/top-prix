extends RefCounted
## Valve-lash and timing workbench: engine data and SNES-style drawing (same Pen / 15-bit colours as
## the carb cutaway). One crank angle (0..720, 0 = cylinder 1 TDC on compression) drives everything:
## piston, both cams (half speed) with real opening/closing points, bucket + shim (or rocker + screw),
## the lash gap, the feeler blade, the timing rotor under the left cover and the strobe check.
##
## XJ550 figures (sources in GuideData "xj550"): clearance cold IN 0.11-0.15 mm, EX 0.16-0.20 mm;
## shim-over-bucket, shims Y200..Y320 = thickness x100 in 0.05 mm steps; cylinders 1-4 left to right,
## firing order 1-2-4-3; Maxim cam timing IN 26 BTDC / 46 ABDC, EX 46 BBDC / 26 ATDC (252 deg); idle
## 1,200 +- 50 rpm; TCI ignition (not adjustable). The generic engines are clearly marked EXAMPLE.

const BG := preload("res://scripts/ui/career/bench_gfx.gd")
const MiniFont := preload("res://scripts/ui/career/mini_font.gd")

const ENGINES := {
	"xj550": {"n": "YAMAHA XJ550 '81-83", "short": "XJ550", "cyl": 4, "order": [1, 2, 4, 3], "adj": "shim",
		"in": [0.11, 0.15], "ex": [0.16, 0.20], "io": 26.0, "ic": 46.0, "eo": 46.0, "ec": 26.0, "idle": 1200,
		"shim": [2.00, 3.20], "example": false, "ign": "tci"},
	"single": {"n": "SINGLE, SCREW ADJUSTERS", "short": "SINGLE", "cyl": 1, "order": [1], "adj": "screw",
		"in": [0.08, 0.12], "ex": [0.13, 0.17], "io": 20.0, "ic": 50.0, "eo": 50.0, "ec": 20.0, "idle": 1400,
		"example": true, "ign": "plate"},
	"twin": {"n": "PARALLEL TWIN (360), SCREWS", "short": "TWIN", "cyl": 2, "order": [1, 2], "adj": "screw",
		"in": [0.08, 0.12], "ex": [0.13, 0.17], "io": 20.0, "ic": 50.0, "eo": 50.0, "ec": 20.0, "idle": 1200,
		"example": true, "ign": "plate", "phase": [0.0, 360.0]},
	"car4": {"n": "CAR INLINE-4, ROCKERS", "short": "CAR I4", "cyl": 4, "order": [1, 3, 4, 2], "adj": "screw",
		"in": [0.15, 0.20], "ex": [0.25, 0.30], "io": 18.0, "ic": 54.0, "eo": 54.0, "ec": 18.0, "idle": 850,
		"example": true, "ign": "dist"},
}

const GAPK := 22.0          # drawing units per mm of lash (exaggerated so 0.1 mm is visible)
const LIFT := 4.6           # nose lift in drawing units
const RB := 8.0             # cam base-circle radius
const WIN := 20.0           # crank degrees either side of "lobe pointing away" that count as measurable

static func eng(id: String) -> Dictionary: return ENGINES.get(id, ENGINES.xj550)

## Crank angle at which cylinder `c` (1-based) is at TDC on its compression stroke.
static func phase(e: Dictionary, c: int) -> float:
	if e.has("phase"): return float(e.phase[c - 1])
	var order: Array = e.order
	return float(order.find(c)) * 720.0 / order.size()

## Cylinder-local angle 0..720 (0 = TDC compression, 0-180 power, 180-360 exhaust, 360-540 intake).
static func local(e: Dictionary, c: int, th: float) -> float: return fposmod(th - phase(e, c), 720.0)

static func stroke(a: float) -> String:
	if a < 180.0: return "POWER"
	if a < 360.0: return "EXHAUST"
	if a < 540.0: return "INTAKE"
	return "COMPRESS"

## Peak-lift angle and duration (cylinder-local crank degrees) for "in" / "ex".
static func peak(e: Dictionary, v: String) -> float:
	if v == "in": return (360.0 - float(e.io) + 540.0 + float(e.ic)) / 2.0
	return (180.0 - float(e.eo) + 360.0 + float(e.ec)) / 2.0
static func dur(e: Dictionary, v: String) -> float:
	return (180.0 + float(e.io) + float(e.ic)) if v == "in" else (180.0 + float(e.eo) + float(e.ec))

## Cam lift (drawing units) at a cylinder-local crank angle.
static func lift(e: Dictionary, v: String, a: float) -> float:
	var d := wrapf(a - peak(e, v), -360.0, 360.0)
	var D := dur(e, v)
	if absf(d) >= D / 2.0: return 0.0
	return LIFT * pow(cos(PI * d / D), 2)

## Crank degrees from the "lobe pointing straight away from the shim" position (0 = measure here).
static func from_away(e: Dictionary, v: String, a: float) -> float:
	return wrapf(a - (peak(e, v) + 360.0), -360.0, 360.0)

static func measurable(e: Dictionary, v: String, a: float) -> bool: return absf(from_away(e, v, a)) <= WIN

## Next crank angle (> th, in turning direction) where some valve's lobe points straight away.
## Returns [angle, cylinder, "in"/"ex"].
static func next_check(e: Dictionary, th: float, dir := 1.0) -> Array:
	var best := [th, 1, "ex"]
	var bd := INF
	for c in range(1, int(e.cyl) + 1):
		for v in ["ex", "in"]:
			var target := fposmod(phase(e, c) + peak(e, v) + 360.0, 720.0)
			var d := fposmod((target - th) * dir, 720.0)
			if d < 1.0: d += 720.0
			if d < bd: bd = d; best = [fposmod(th + d * dir, 720.0), c, v]
	return best

static func spec(e: Dictionary, v: String) -> Array: return e["in"] if v == "in" else e["ex"]
static func target(e: Dictionary, v: String) -> float:
	var s := spec(e, v)
	return (float(s[0]) + float(s[1])) / 2.0

## Shim maths (shim-over-bucket): new = installed + (measured - target), rounded to 0.05 mm and kept
## inside the shim range. Returns {shim, result, change} in mm.
static func shim_for(e: Dictionary, v: String, measured: float, installed: float) -> Dictionary:
	var want: float = installed + (measured - target(e, v))
	var sh: float = clampf(roundf(want / 0.05) * 0.05, float(e.shim[0]), float(e.shim[1]))
	return {"shim": snappedf(sh, 0.01), "result": snappedf(measured + installed - sh, 0.001), "change": snappedf(sh - installed, 0.01)}

static func status(e: Dictionary, v: String, measured: float) -> String:
	var s := spec(e, v)
	if measured < float(s[0]) - 0.0005: return "TIGHT"
	if measured > float(s[1]) + 0.0005: return "LOOSE"
	return "OK"

static func shim_name(mm: float) -> String: return "Y%d" % int(roundf(mm * 100.0))
static func inch(mm: float) -> String: return ("%.4f" % (mm / 25.4)).trim_prefix("0")

# ======================================================================
# drawing (160 x 100 units through Pen at k = 1.5 -> 240 x 150 px)
# ======================================================================
static func C(h: String) -> Color: return BG.C(h)

## Side cutaway of one cylinder, seen from the left side of the bike (front = left): exhaust cam and
## valve on the left, intake on the right, piston below, plug in the middle, feeler blade in the gap.
## st: {th, cyl, sel ("in"/"ex"), meas: {"1in": mm...}, shims: {...}, feeler: bool, fire: float}
static func draw_cutaway(ci: CanvasItem, origin: Vector2, e: Dictionary, st: Dictionary) -> void:
	var p := BG.Pen.new(ci, origin, 1.5)
	var cyl := int(st.cyl)
	var a := local(e, cyl, float(st.th))
	var AL := C("#9aa3ad"); var ALd := C("#6f7882"); var ALl := C("#c3cbd3"); var BORE := C("#0d1020")
	var STEEL := C("#c8ccd8"); var GOLD := C("#e0b030"); var HOT := C("#ff8a3a")
	p.r(0, 0, 160, 100, C("#1a2140"))
	for y in range(0, 100, 10): p.r(0, y, 160, 1, C("#1f2850"))
	var shim: bool = e.adj == "shim"
	# head casting and cam carrier
	p.r(18, 28, 124, 42, ALd); p.r(20, 30, 120, 38, AL)
	for k in range(22, 138, 6): p.r(k, 30, 2, 38, ALd)          # cooling fins
	# cylinder and piston
	var pist := 2.0 + 16.0 * (1.0 - cos(deg_to_rad(a))) / 2.0
	p.r(44, 68, 72, 32, ALd); p.r(46, 68, 68, 32, BORE)
	p.r(47, 70 + pist, 66, 10, C("#b7bfc7")); p.r(47, 70 + pist, 66, 1, ALl)
	p.r(47, 73 + pist, 66, 1, C("#555b66")); p.r(47, 75 + pist, 66, 1, C("#555b66"))
	p.r(76, 80 + pist, 8, 20 - pist, C("#8d959d"))                  # con rod
	# combustion chamber + ports
	p.r(40, 62, 80, 6, BORE)
	var fire: float = st.get("fire", 0.0)
	if fire > 0.0: p.r(56, 63, 48, 5, C("#ffd27a") if fire > 0.5 else C("#ff8a3a"))
	p.r(6, 50, 36, 8, BORE); p.r(118, 50, 36, 8, BORE)              # exhaust port (front), intake port (rear)
	p.txt("EXHAUST", 6, 59, C("#ff9a9a")); p.txt("INTAKE", 120, 59, C("#9fe8ff"))
	# spark plug
	p.r(77, 34, 6, 30, C("#e8e8e0")); p.r(78, 30, 4, 5, C("#3a3f4a")); p.r(79, 62, 2, 3, C("#9aa3ad"))
	if fire > 0.0: p.r(78, 64, 4, 2, C("#ffffff"))
	# the two valve trains
	for v in ["ex", "in"]:
		var cx := 52.0 if v == "ex" else 108.0
		var key := "%d%s" % [cyl, v]
		var meas: float = float(st.meas.get(key, target(e, v)))
		var gap := meas * GAPK
		var li := lift(e, v, a)
		var open_by := maxf(0.0, li - gap)
		var cam_y := 12.0
		var sel: bool = str(st.sel) == v
		var hl := measurable(e, v, a)
		if shim:
			# bucket + shim under the cam (DOHC shim-over-bucket)
			var sy := cam_y + RB + gap + open_by
			p.r(cx - 7, sy, 14, 2, GOLD)                                  # shim
			p.r(cx - 8, sy + 2, 16, 10, STEEL); p.r(cx - 8, sy + 2, 16, 1, C("#ffffff"))
			p.r(cx - 8, sy + 11, 16, 1, C("#7c8494"))
			p.r(cx - 1, sy + 12, 2, maxf(1.0, 61.0 + open_by - (sy + 12)), C("#a8b0bc"))     # stem
			for k in 5: p.r(cx - 5, sy + 13 + k * 2, 10, 1, C("#5a6170"))   # spring coils
			p.r(cx - 6, 61 + open_by, 12, 2, C("#a8b0bc"))                # valve head
		else:
			# rocker + adjuster screw / locknut over the valve stem (screw-type, simplified)
			var rk := 30.0 + open_by * 0.8
			p.r(cx - 10, 26, 20, 3, C("#8d959d"))
			p.r(cx - 2, 26, 4, 4, C("#5a6170"))                            # pivot
			p.r(cx - 1, rk, 2, 6, C("#e0b030"))                            # adjuster screw
			p.r(cx - 3, rk + 1, 6, 2, C("#c08a20"))                        # locknut
			p.r(cx - 1, rk + 6 + gap, 2, 30, C("#a8b0bc"))
			p.r(cx - 6, 61 + open_by, 12, 2, C("#a8b0bc"))
		# cam lobe (rotating at half crank speed); counter-clockwise on screen
		var rot := deg_to_rad(90.0 - (a - peak(e, v)) / 2.0)
		var pts := PackedVector2Array()
		for i in 48:
			var beta := TAU * i / 48.0
			var crank_d := rad_to_deg(beta) * 2.0
			var cd := wrapf(crank_d, -360.0, 360.0)
			var r := RB + (LIFT * pow(cos(PI * cd / dur(e, v)), 2) if absf(cd) < dur(e, v) / 2.0 else 0.0)
			var ang := rot + beta
			pts.append(p.o + (Vector2(cx, cam_y) + Vector2(cos(ang), sin(ang)) * r) * p.k)
		var lobe_col := C("#8ef58e") if hl else (C("#ff9a9a") if li > gap else C("#b7bfc7"))
		ci.draw_colored_polygon(pts, lobe_col)
		p.r(cx - 2, cam_y - 2, 4, 4, C("#3a3f4a"))                          # cam journal
		p.txt("EX" if v == "ex" else "IN", cx - 4 if v == "ex" else cx - 4, 2, C("#ffd84a") if sel else C("#c8d0e8"))
		# lash gap + feeler blade
		if li <= gap and gap > 0.0:
			if bool(st.get("feeler", false)) and sel:
				p.r(cx - 20, cam_y + RB + 0.2, 28, maxf(0.6, gap - 0.4), C("#d8d8d0") if hl else C("#8a8a80"))
				p.txt("%.2f" % meas, cx - 22 if v == "ex" else cx - 2, cam_y + RB + gap + 3, C("#ffffff"))
			elif shim:
				p.r(cx - 7, cam_y + RB, 14, maxf(0.5, gap), A("#7fd3ff", 0.25))
	# labels
	p.txt("CYL %d %s %s" % [cyl, stroke(a), tdc_txt(a)], 2, 92, C("#ffd84a"))
	if bool(e.example): p.txt("EXAMPLE ENGINE", 104, 92, C("#ff9a9a"))

static func A(h: String, a: float) -> Color: return BG.A(h, a)

## Crank position relative to this cylinder's compression TDC, as a mechanic says it.
static func tdc_txt(a: float) -> String:
	var rel := wrapf(a, -360.0, 360.0)
	if absf(rel) < 1.0: return "TDC"
	if absf(absf(rel) - 360.0) < 1.0: return "TDC OVERLAP"
	return ("%d BTDC" % int(roundf(-rel))) if rel < 0 else ("%d ATDC" % int(roundf(rel)))

## Strip of cylinders: number, stroke and EX / IN status dots (green = lobe away, measure now;
## red = valve open; grey = closed on the base circle). The cutaway cylinder is framed in gold.
static func draw_strip(ci: CanvasItem, origin: Vector2, w: float, e: Dictionary, st: Dictionary) -> void:
	var n := int(e.cyl)
	var cw := (w - 2.0) / n
	for c in range(1, n + 1):
		var x := origin.x + 1.0 + (c - 1) * cw
		var a := local(e, c, float(st.th))
		var sel: bool = int(st.cyl) == c
		ci.draw_rect(Rect2(x, origin.y, cw - 2, 30), C("#ffd84a") if sel else C("#2a3672"))
		ci.draw_rect(Rect2(x + 1, origin.y + 1, cw - 4, 28), C("#141c4e"))
		MiniFont.draw(ci, "#%d" % c, Vector2(x + 4, origin.y + 4), C("#ffffff"))
		MiniFont.draw(ci, stroke(a).left(5), Vector2(x + 4, origin.y + 12), C("#9fe8ff"))
		for vi in 2:
			var v: String = ["ex", "in"][vi]
			var li := lift(e, v, a)
			var col := C("#8ef58e") if measurable(e, v, a) else (C("#ff6a5a") if li > 0.01 else C("#5a6170"))
			var dx := x + cw - 16 + vi * 7
			ci.draw_rect(Rect2(dx, origin.y + 4, 5, 5), col)
			MiniFont.draw(ci, "E" if v == "ex" else "I", Vector2(dx + 1, origin.y + 11), C("#c8d0e8"))
	if int(e.cyl) > 1:
		var fo := "-".join((e.order as Array).map(func(z): return str(z)))
		MiniFont.draw(ci, "FIRING ORDER " + fo, Vector2(origin.x + w - 2, origin.y + 32), C("#6f82cc"), 2)

## Timing rotor under the left cover: the rotor turns with the crank, the pointer is fixed at the top.
## Marks: T for 1-4 TDC (and 2-3 on a 4), F = the idle firing range just before T. strobe >= 0 freezes
## the rotor where the spark fires at that rpm (advance grows with rpm) - the timing-light check.
static func draw_rotor(ci: CanvasItem, center: Vector2, rad: float, e: Dictionary, th: float, strobe := -1.0) -> void:
	ci.draw_circle(center, rad + 4, C("#3a3f4a"))
	ci.draw_circle(center, rad + 2, C("#6f7882"))
	ci.draw_circle(center, rad, C("#c3cbd3"))
	ci.draw_circle(center, rad * 0.45, C("#9aa3ad"))
	ci.draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), C("#5a6170"))     # rotor bolt (turn here)
	var ang := th
	if strobe >= 0.0: ang = -advance(e, strobe)
	var marks := [[0.0, "T", "1-4"]]
	if int(e.cyl) == 4: marks.append([180.0, "T", "2-3"])
	if int(e.cyl) == 2 and not e.has("phase"): marks.append([180.0, "T", "2"])
	for m in marks:
		var base: float = float(m[0])
		var a0 := deg_to_rad(-90.0 + base + ang)
		var d := Vector2(cos(a0), sin(a0))
		ci.draw_line(center + d * rad * 0.62, center + d * (rad - 1), C("#1a1a20"), 2.0)
		MiniFont.draw(ci, str(m[1]), center + d * (rad * 0.42) - Vector2(1, 2), C("#c8402e"))
		# F range: idle firing range, a short bracket before T
		for f in [8.0, 14.0]:
			var a1 := deg_to_rad(-90.0 + base + ang + f)
			var d1 := Vector2(cos(a1), sin(a1))
			ci.draw_line(center + d1 * rad * 0.78, center + d1 * (rad - 1), C("#2f5fbf"), 1.0)
		var af := deg_to_rad(-90.0 + base + ang + 11.0)
		MiniFont.draw(ci, "F", center + Vector2(cos(af), sin(af)) * (rad * 0.62) - Vector2(1, 2), C("#2f5fbf"))
	# fixed pointer at 12 o'clock
	var tip := center + Vector2(0, -rad + 2)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4, -8), tip + Vector2(4, -8)]), C("#ffd84a"))
	if strobe >= 0.0:
		ci.draw_circle(center, rad + 6, A("#ffffff", 0.06))

## Spark advance before TDC (deg) at an rpm: sits in the F range at idle, grows to full advance by
## ~5,000 rpm. Shape only (the plate's own brackets are the spec): EXAMPLE curve.
static func advance(e: Dictionary, rpm: float) -> float:
	var idle := float(e.idle)
	var t := clampf((rpm - idle) / (5000.0 - idle), 0.0, 1.0)
	return 11.0 + 24.0 * t * t * (3.0 - 2.0 * t)
