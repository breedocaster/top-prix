extends RefCounted
## Tuning-bench pixel art: port of web/src/tunegfx.js (Bench.*). Carb cutaways (round slide, CV,
## flat slide, sidedraft, 2/4-barrel downdraft) with animated air, fuel drops, float bowl, needle and
## jets; the instrument strip (wideband AFR or plug chop, TPS, vacuum); the AFR-vs-throttle chart;
## Carbtune sync columns or by-ear idle; the dyno pull (roller, SD vehicle sprite, rpm gauge, power and
## AFR traces) and its step function. Everything is draw_rect / MiniFont on the caller's canvas with
## 15-bit (SNES) colours; no images are made per frame. Web coordinates (160 wide) are drawn through a
## Pen that scales them (1.5x for the cutaways) and floors every edge so pixels stay crisp.
## State dict (one per bench): see new_state().

const MiniFont := preload("res://scripts/ui/career/mini_font.gd")

static var rng := RandomNumberGenerator.new()
static var _cc := {}

## 15-bit colour from a hex string (cached).
static func C(hex: String) -> Color:
	var c = _cc.get(hex)
	if c == null:
		c = SpriteForge.snes(Color(hex))
		_cc[hex] = c
	return c

static func A(hex: String, a: float) -> Color:
	var c := C(hex)
	return Color(c.r, c.g, c.b, a)

static func new_state() -> Dictionary:
	return {"thr": 0.15, "sweep": false, "dir": 1.0, "snapT": 0.0, "snapHold": 0.0, "t": 0.0, "drops": [], "air": [], "dyno": null, "smoke": []}

## CSS hsl() -> 15-bit colour.
static func hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var hp := fmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
	var r := 0.0; var g := 0.0; var b := 0.0
	if hp < 1: r = c; g = x
	elif hp < 2: r = x; g = c
	elif hp < 3: g = c; b = x
	elif hp < 4: g = x; b = c
	elif hp < 5: r = x; b = c
	else: r = c; b = x
	var m := l - c / 2.0
	return SpriteForge.snes(Color(r + m, g + m, b + m))

static func chance(p: float) -> bool: return rng.randf() < p
static func rand(a: float, b: float) -> float: return a + rng.randf() * (b - a)

# ---------------- model helpers ----------------
static func lam_at(ev: Dictionary, thr: float) -> float:
	var L: Dictionary = ev.lam
	var xs := [0.04, 0.18, 0.5, 0.9]
	var ys := [float(L.idle), float(L.low), float(L.mid), float(L.wot)]
	if thr <= xs[0]: return ys[0]
	for i in range(1, 4):
		if thr <= xs[i]:
			return ys[i - 1] + (ys[i] - ys[i - 1]) * (thr - xs[i - 1]) / (xs[i] - xs[i - 1])
	return ys[3]

static func tgt_at(thr: float) -> float: return lam_at({"lam": Data.D.LAM}, thr)

static func tick(s: Dictionary, dt: float) -> void:
	s.t = float(s.t) + dt
	if s.sweep:
		s.thr = float(s.thr) + float(s.dir) * dt * 0.35
		if s.thr >= 1.0: s.thr = 1.0; s.dir = -1.0
		if s.thr <= 0.02: s.thr = 0.02; s.dir = 1.0
	if float(s.snapT) > 0: s.snapT = float(s.snapT) - dt
	if float(s.snapHold) > 0:
		s.snapHold = float(s.snapHold) - dt
		if float(s.snapHold) <= 0: s.thr = 0.2

## Throttle snap (accelerator pump shot), back to 20% after 0.9 s.
static func snap(s: Dictionary) -> void:
	s.sweep = false
	s.thr = 0.95
	s.snapT = 0.5
	s.snapHold = 0.9

static func fuel_col(lam: float) -> Color:
	if lam < 0.8: return C("#c8641e")
	if lam < 0.85: return C("#e88a2a")
	if lam < 0.92: return C("#f2b33d")
	if lam < 0.98: return C("#f6dd7a")
	return C("#cfe9f2")

## Colour of a lambda reading against its target (green on target, orange rich, red lean).
static func afr_col(lam: float, tgt: float) -> Color:
	if absf(lam - tgt) < 0.02: return C("#7dff7d")
	return C("#ffb347") if lam < tgt else C("#ff6060")

static func font8_draw(ci: CanvasItem, t: String, pos: Vector2, col: Color, align := 0, sz := 8, shadow := true) -> void:
	var f: Font = UIKit.font8
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var x := pos.x
	if align == 1: x -= floorf(w / 2.0)
	elif align == 2: x -= w
	var base := Vector2(floorf(x), floorf(pos.y) + f.get_ascent(sz))
	if shadow: ci.draw_string(f, base + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.8))
	ci.draw_string(f, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

## Scaled drawing in web units: edges are floored so neighbouring rects never gap or overlap.
class Pen:
	var ci: CanvasItem
	var o := Vector2.ZERO
	var k := 1.0
	func _init(c: CanvasItem, origin: Vector2, scale: float) -> void:
		ci = c; o = origin; k = scale
	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		var x0 := floorf(o.x + x * k); var y0 := floorf(o.y + y * k)
		var x1 := floorf(o.x + (x + w) * k); var y1 := floorf(o.y + (y + h) * k)
		ci.draw_rect(Rect2(x0, y0, maxf(1.0, x1 - x0), maxf(1.0, y1 - y0)), c)
	func rc(x: float, y: float, w: float, h: float, c: Color, cl: Rect2) -> void:
		var a := Rect2(x, y, w, h).intersection(cl)
		if a.size.x > 0 and a.size.y > 0: r(a.position.x, a.position.y, a.size.x, a.size.y, c)
	func dot(x: float, y: float, sz: float, c: Color) -> void:
		ci.draw_rect(Rect2(floorf(o.x + x * k), floorf(o.y + y * k), sz, sz), c)
	func txt(t: String, x: float, y: float, c: Color, align := 0) -> void:
		MiniFont.draw(ci, t, Vector2(o.x + x * k, o.y + y * k), c, align)

static func _jets_txt(x) -> String:
	var f := float(x)
	return str(int(f)) if f == floorf(f) else U.to_fixed(f, 2).rstrip("0").rstrip(".")

# ======================================================================
# carb cutaway (web Bench.drawCarb / drawDown), 160x100 web units at k = 1.5 -> 240x150 px
# ======================================================================
static func draw_carb(ci: CanvasItem, origin: Vector2, v: Dictionary, ev: Dictionary, rich: Dictionary, s: Dictionary, dt: float) -> void:
	var p := Pen.new(ci, origin, 1.5)
	var C_: Dictionary = Data.D.CARBS[v.eng.carb]
	var j: Dictionary = v.eng.jets
	var thr: float = s.thr
	var t: float = s.t
	var lam := lam_at(ev, thr)
	var snap_on: bool = float(s.snapT) > 0
	p.r(0, 0, 160, 100, C("#1a2140"))
	for y in range(0, 100, 10): p.r(0, y, 160, 1, C("#1f2850"))
	if C_.kind == "down":
		_draw_down(p, v, C_, j, thr, lam, snap_on, t, s, dt)
		return
	var AL := C("#9aa3ad"); var ALd := C("#6f7882"); var ALl := C("#c3cbd3"); var BORE := C("#0d1020")
	var side: bool = C_.kind == "side"
	# bell mouth, bore, manifold
	p.r(4, 36, 12, 24, ALd); p.r(6, 38, 10, 20, BORE)
	p.r(14, 34, 128, 4, AL); p.r(14, 58, 128, 4, AL); p.r(14, 38, 128, 20, BORE)
	p.r(142, 36, 14, 24, C("#3d3d3d")); p.r(142, 38, 14, 20, C("#120d0a"))
	# airflow
	if chance(dt * (8 + thr * 60)): s.air.append({"x": 6.0, "y": 39.0 + rng.randf() * 17.0})
	var air := []
	for a in s.air:
		a.x = float(a.x) + dt * (30 + thr * 160)
		if a.x < 156:
			air.append(a)
			p.r(a.x, a.y, 3, 1, C("#7fd3ff"))
	s.air = air
	# mixture tint downstream
	var fc := fuel_col(lam)
	var tint := Color(fc.r, fc.g, fc.b, 0.25 + 0.4 * thr)
	p.r(96, 38, 46, 20, tint); p.r(142, 38, 14, 20, tint)
	# slide / butterfly
	if not side:
		p.r(62, 6, 32, 30, AL); p.r(64, 8, 28, 28, ALl)
		if C_.kind == "cv":
			p.r(58, 4, 40, 6, ALd); p.r(60, 9, 36, 1, C("#222222"))
			p.txt("DIAPHRAGM", 18, 24, C("#cfe0ff"))
		var flat: bool = C_.kind == "flat"
		var sw := 8.0 if flat else 22.0
		var sx := 78.0 - sw / 2.0
		var sb := 56.0 - thr * 17.0
		p.r(sx, sb - 24, sw, 24, C("#d8dde2") if flat else C("#b7bfc7"))
		p.r(sx, sb - 1, sw, 1, C("#555555"))
		if not flat: p.r(sx + sw - 3, sb - 6, 3, 6, C("#8d959d"))
		for k in 22:
			var w := 2.0 if k < 8 else 1.0
			p.r(78 - (1.0 if w > 1 else 0.0), sb + k - 2, w, 1, C("#e6e9ec"))
		p.r(78, sb, 1, 1, C("#ffd84a"))
	else:
		var ang := thr * PI * 0.45
		for k in range(-9, 10):
			p.r(118 + sin(ang) * k * 0.9, 48 + cos(ang) * k, 2, 1, C("#d8dde2"))
		p.r(117, 47, 3, 3, C("#555555"))
		p.txt("BUTTERFLY", 104, 26, C("#cfe0ff"))
		p.r(74, 14, 8, 20, AL); p.r(76, 12, 4, 3, C("#c8a24a"))
		p.txt("AIR CORR %s" % _jets_txt(j.get("airc", 0)), 84, 12, C("#ffd84a"))
		p.r(76, 16, 4, 18, BORE)
	# needle jet / emulsion tube
	p.r(76, 58, 5, 22, ALl); p.r(77, 58, 3, 22, C("#2a1a08"))
	# float bowl
	var bx := 48.0; var by := 68.0; var bw := 60.0; var bh := 28.0
	var fl := float(j.get("float", 0))
	p.r(bx, by, bw, bh, AL); p.r(bx + 2, by + 2, bw - 4, bh - 4, BORE)
	var lvl := by + 18 - fl * 1.4 + sin(t * 3) * 0.4 * (1 + thr)
	var cl := Rect2(bx + 2, by + 2, bw - 4, bh - 4)
	p.rc(bx + 2, lvl, bw - 4, bh, C("#e0a12b"), cl); p.rc(bx + 2, lvl, bw - 4, 1, C("#ffd27a"), cl)
	var fy := lvl - 5
	p.r(bx + 5, fy, 14, 5, C("#d7c78a")); p.r(bx + bw - 19, fy, 14, 5, C("#d7c78a"))
	p.r(bx + 19, fy + 2, bw - 38, 1, C("#888888")); p.r(bx + bw - 8, by + 2, 3, maxf(1, fy - by - 1), C("#777777"))
	p.txt("FUEL LEVEL %s%s MM" % ["+" if fl > 0 else "", _jets_txt(fl)], bx, by + bh + 1.5, C("#ffd84a"))
	# inlet + needle valve
	p.r(bx + bw, by + 4, 14, 3, C("#5b3a1a"))
	if (thr > 0.4 or sin(t * 3) > 0.6) and chance(dt * 20):
		s.drops.append({"x": bx + bw - 6, "y": by + 5, "vx": 0.0, "vy": 12.0, "t": 0.0, "c": "#ffcf5c", "rise": false})
	# main jet (orifice width by size)
	var mainP: Dictionary = {}
	for q in C_.p:
		if q.k == "main": mainP = q
	var mw := clampf(roundf(2 + (float(j.main) / float(mainP.stock) - 1) * 12), 1, 6)
	p.r(74, 80, 9, 5, C("#c8a24a")); p.r(78.5 - mw / 2.0, 80, mw, 5, C("#1a1206"))
	p.r(83, 82, 27, 1, C("#4b5ea0"))
	p.txt("MAIN %s" % _jets_txt(j.main), 111, 79, C("#ffd84a"))
	# pilot jet + passage
	if j.has("pilot"):
		p.r(60, 78, 4, 8, C("#c8a24a")); p.r(61, 78, 2, 8, C("#1a1206"))
		p.r(61, 62, 2, 16, C("#3a2a10")); p.r(61, 60, 26, 2, C("#3a2a10"))
		p.txt("PILOT %s" % _jets_txt(j.pilot), 4, 88, C("#ffd84a"))
	# mixture screw
	var sp: Dictionary = {}
	for q in C_.p:
		if q.k == "screw": sp = q
	if not sp.is_empty():
		var ang2 := float(j.get("screw", 0)) * TAU
		p.r(26, 62, 10, 6, ALd)
		for k in range(-3, 4): p.r(31 + cos(ang2) * k, 65 + sin(ang2) * k, 1, 1, C("#ffd84a"))
		var air_scr: bool = str(sp.n).begins_with("Air")
		p.txt("%s %st" % ["AIR SCR" if air_scr else "FUEL SCR", _jets_txt(j.screw)], 4, 71, C("#ffd84a"))
	# accelerator pump
	if j.has("pump"):
		p.r(bx + bw - 10, by + bh - 8, 8, 6, C("#7a6a4a")); p.r(70, 37, 2, 2, C("#ffd84a"))
		p.txt("PUMP %s" % _jets_txt(j.pump), 112, 88, C("#ffd84a"))
		if snap_on:
			for k in 4: s.drops.append({"x": 71.0, "y": 39.0, "vx": rand(10, 40), "vy": rand(5, 20), "t": 0.0, "c": "#ffb000", "rise": false})
	# fuel up the needle jet and spray
	var flow: float = 0.6 if thr < 0.2 else float(rich.get("mid", 1.0))
	var rate := (thr if thr > 0.08 else 0.15) * 30 * flow / (lam / 0.9)
	if chance(dt * rate): s.drops.append({"x": 77.5, "y": 80.0, "vx": 0.0, "vy": -40 - thr * 30, "t": 0.0, "c": "#ffb000", "rise": true})
	if thr < 0.3 and j.has("pilot") and chance(dt * 12): s.drops.append({"x": 86.0, "y": 57.0, "vx": 30.0, "vy": -6.0, "t": 0.0, "c": "#ffd27a", "rise": false})
	var drops := []
	for d in s.drops:
		d.t = float(d.t) + dt
		if d.t >= 1.2: continue
		if d.rise and d.y < 56:
			d.rise = false; d.vx = 40 + thr * 120; d.vy = rand(-15, 15)
		d.x = float(d.x) + float(d.vx) * dt
		d.y = float(d.y) + float(d.vy) * dt
		drops.append(d)
		if d.x < 156: p.dot(d.x, d.y, 2, C(d.c))
	s.drops = drops
	# needle inset
	if not side and j.has("clip"):
		var clip := int(j.clip)
		p.r(118, 3, 40, 31, BORE); p.r(118, 3, 40, 1, C("#4b5ea0"))
		p.txt("JET NEEDLE", 120, 5, C("#cfe0ff"))
		for g in 5: p.r(126, 11 + g * 3, 8, 1, C("#ffd84a") if g + 1 == clip else C("#7d8590"))
		p.r(129, 10, 2, 22, C("#e6e9ec")); p.r(129, 32, 1, 1, C("#e6e9ec"))
		p.r(124, 10 + (clip - 1) * 3, 12, 3, C("#ffd84a"))
		p.txt("CLIP %d" % clip, 138, 12, C("#ffd84a"))
		p.txt("1 LEAN", 138, 20, C("#8fa3d8"))
		p.txt("5 RICH", 138, 26, C("#8fa3d8"))

static func _draw_down(p: Pen, v: Dictionary, C_: Dictionary, j: Dictionary, thr: float, lam: float, snap_on: bool, t: float, s: Dictionary, dt: float) -> void:
	var AL := C("#9aa3ad"); var ALd := C("#6f7882"); var BORE := C("#0d1020")
	p.r(26, 4, 86, 6, ALd); p.r(30, 10, 78, 72, AL)
	var four := int(C_.get("barrels", 2)) == 4
	var barrels: Array = [36.0, 56.0, 74.0, 94.0] if four else [42.0, 78.0]
	var bwid := 14.0 if four else 20.0
	var vac := 18.0 * pow(1 - thr, 1.5)
	var pv_open: bool = j.has("pv") and vac < float(j.pv)
	for bx in barrels:
		p.r(bx, 10, bwid, 74, BORE)
		p.r(bx + bwid / 2 - 3, 30, 6, 3, C("#c3cbd3")); p.r(bx + bwid / 2 - 1, 33, 2, 2, C("#c3cbd3"))
		var sec: bool = four and bx >= 74
		var op := maxf(0.0, (thr - 0.6) / 0.4) if sec else thr
		var ang := op * PI * 0.45
		for k in range(int(-bwid / 2) + 1, int(bwid / 2)):
			p.r(bx + bwid / 2 + cos(ang) * k * 0.95, 66 + sin(ang) * k, 1, 1, C("#d8dde2"))
		if op > 0.12 and chance(dt * op * 40): s.drops.append({"x": bx + bwid / 2, "y": 34.0, "vx": rand(-6, 6), "vy": 30 + op * 60, "t": 0.0, "c": "#ffb000"})
		if chance(dt * (6 + op * 40)): s.air.append({"x": bx + 2 + rng.randf() * (bwid - 4), "y": 10.0})
		if sec:
			p.txt("2ND", bx + bwid / 2, 86, C("#8fa3d8") if op <= 0 else C("#8ef58e"), 1)
	var air := []
	for a in s.air:
		a.y = float(a.y) + dt * (30 + thr * 140)
		if a.y < 84:
			air.append(a)
			p.r(a.x, a.y, 1, 3, C("#7fd3ff"))
	s.air = air
	var fc := fuel_col(lam)
	p.r(30, 74, 78, 10, Color(fc.r, fc.g, fc.b, 0.3 + 0.4 * thr))
	# float bowl
	var bx2 := 112.0; var by := 18.0; var bw := 34.0; var bh := 50.0
	var fl := float(j.get("float", 0))
	p.r(bx2, by, bw, bh, AL); p.r(bx2 + 2, by + 2, bw - 4, bh - 4, BORE)
	var lvl := by + 30 - fl * 1.6 + sin(t * 3) * 0.4
	var cl := Rect2(bx2 + 2, by + 2, bw - 4, bh - 4)
	p.rc(bx2 + 2, lvl, bw - 4, bh, C("#e0a12b"), cl); p.rc(bx2 + 2, lvl, bw - 4, 1, C("#ffd27a"), cl)
	p.r(bx2 + 6, lvl - 5, 22, 5, C("#d7c78a")); p.r(bx2 + bw - 6, by - 4, 3, 6, C("#777777")); p.r(bx2 + bw, by, 10, 3, C("#5b3a1a"))
	p.txt("LEVEL %s%s MM" % ["+" if fl > 0 else "", _jets_txt(fl)], bx2, by + bh + 1, C("#ffd84a"))
	# metering block + jets
	p.r(106, 34, 6, 40, C("#8d959d"))
	var mainP: Dictionary = C_.p[0]
	var mw := clampf(roundf(2 + (float(j.main) / float(mainP.stock) - 1) * 12), 1, 5)
	p.r(107, 64, 4, 4, C("#c8a24a")); p.r(109 - mw / 2.0, 64, mw, 4, C("#1a1206"))
	p.txt("PRI %s" % _jets_txt(j.main), 112, 74, C("#ffd84a"))
	if j.has("sec"): p.txt("SEC %s" % _jets_txt(j.sec), 112, 80, C("#ffd84a"))
	if j.has("pv"):
		p.r(107, 48, 4, 6, C("#8ef58e") if pv_open else C("#b05050"))
		p.txt("PV %s\" %s" % [_jets_txt(j.pv), "OPEN" if pv_open else "SHUT"], 112, 86, C("#8ef58e") if pv_open else C("#ff9a9a"))
	# accelerator pump
	if j.has("pump"):
		p.r(40, 88, 30, 6, C("#7a6a4a")); p.r(44, 86, 22, 2, C("#5a4a2a"))
		p.txt("SQUIRTER %s" % _jets_txt(j.pump), 3, 95, C("#ffd84a"))
		if snap_on:
			for bx in barrels.slice(0, 2):
				for k in 4: s.drops.append({"x": bx + bwid / 2, "y": 14.0, "vx": rand(-8, 8), "vy": rand(40, 90), "t": 0.0, "c": "#ffb000"})
	# idle mixture screws
	var ang2 := float(j.get("screw", 0)) * TAU
	for sx in [34.0, 100.0]:
		for k in range(-2, 3): p.r(sx + cos(ang2) * k, 78 + sin(ang2) * k, 1, 1, C("#ffd84a"))
	p.txt("IDLE %st" % _jets_txt(j.get("screw", 0)), 3, 76, C("#ffd84a"))
	var drops := []
	for d in s.drops:
		d.t = float(d.t) + dt
		if d.t >= 1.0: continue
		d.x = float(d.x) + float(d.vx) * dt
		d.y = float(d.y) + float(d.vy) * dt
		drops.append(d)
		p.dot(d.x, d.y, 2, C(d.c))
	s.drops = drops

## Vacuum (inHg) at a throttle opening, for the instrument strip.
static func vacuum(thr: float) -> float: return 18.0 * pow(1 - thr, 1.5)

# ======================================================================
# instrument strip under the cutaway: wideband / plug, TPS, mixture verdict
# ======================================================================
static func draw_strip(ci: CanvasItem, o: Vector2, w: float, v: Dictionary, ev: Dictionary, s: Dictionary) -> void:
	var thr: float = s.thr
	var lam := lam_at(ev, thr)
	var tgt := tgt_at(thr)
	var wb := Tune.has("wideband")
	var h := 24.0
	ci.draw_rect(Rect2(o, Vector2(w, h)), C("#050805"))
	# gauge box
	ci.draw_rect(Rect2(o + Vector2(1, 1), Vector2(70, h - 2)), C("#0d1a0d"))
	if wb:
		MiniFont.draw(ci, "WIDEBAND", o + Vector2(4, 3), C("#8fa3d8"))
		font8_draw(ci, U.to_fixed(lam * 14.7, 1), o + Vector2(36, 12), afr_col(lam, tgt), 1)
		MiniFont.draw(ci, "AFR", o + Vector2(56, 14), C("#8fa3d8"))
	else:
		var pl := Tune.plug(lam)
		# spark plug: terminal, insulator, shell, electrode tip coloured by the chop
		ci.draw_rect(Rect2(o + Vector2(6, 3), Vector2(4, 3)), C("#9aa2ad"))
		ci.draw_rect(Rect2(o + Vector2(5, 6), Vector2(6, 7)), C("#eeeeee"))
		ci.draw_rect(Rect2(o + Vector2(4, 13), Vector2(8, 4)), C("#8d959d"))
		ci.draw_rect(Rect2(o + Vector2(6, 17), Vector2(4, 4)), C(pl[1]))
		MiniFont.draw(ci, "PLUG CHOP", o + Vector2(16, 3), C("#8fa3d8"))
		MiniFont.draw(ci, str(pl[2]).to_upper(), o + Vector2(16, 12), C(pl[1]) if pl[1] != "#1c1c1c" else C("#ff9a5c"))
	# TPS bar
	var tx := o.x + 76
	MiniFont.draw(ci, "TPS %d%%" % int(roundf(thr * 100)), Vector2(tx, o.y + 3), C("#cfe0ff"))
	var bw := 92.0
	ci.draw_rect(Rect2(tx, o.y + 12, bw, 8), C("#1d2650"))
	ci.draw_rect(Rect2(tx, o.y + 12, floorf(bw * thr), 8), C("#ffd84a") if float(s.snapT) <= 0 else C("#ff8a5c"))
	for q in [0.25, 0.5, 0.75]: ci.draw_rect(Rect2(tx + floorf(bw * q), o.y + 12, 1, 8), C("#0d1330"))
	# verdict / vacuum
	var vx := o.x + 174
	var C_: Dictionary = Data.D.CARBS.get(str(v.eng.get("carb", "")), {})
	if v.eng.fuel == "carb" and C_.get("kind") == "down":
		MiniFont.draw(ci, "VACUUM", Vector2(vx, o.y + 3), C("#8fd8ff"))
		MiniFont.draw(ci, "%s INHG" % U.to_fixed(vacuum(thr), 1), Vector2(vx, o.y + 13), C("#8fd8ff"))
	else:
		var d := lam - tgt
		var word := "ON TARGET"
		if d < -0.06: word = "VERY RICH"
		elif d < -0.02: word = "RICH"
		elif d > 0.06: word = "VERY LEAN"
		elif d > 0.02: word = "LEAN"
		MiniFont.draw(ci, "MIXTURE", Vector2(vx, o.y + 3), C("#8fa3d8"))
		MiniFont.draw(ci, word if wb else "?" if absf(d) < 0.04 else ("RICH?" if d < 0 else "LEAN?"), Vector2(vx, o.y + 13), afr_col(lam, tgt))

# ======================================================================
# AFR vs throttle chart (web Bench.drawChart), native px
# ======================================================================
static func draw_chart(ci: CanvasItem, o: Vector2, w: float, ev: Dictionary, s: Dictionary) -> void:
	var h := 62.0
	ci.draw_rect(Rect2(o, Vector2(w, h)), C("#0d1330"))
	var x0 := o.x + 14.0
	var pw := w - 20.0
	var top := o.y + 4.0
	var ph := 44.0
	for i in 5: ci.draw_rect(Rect2(floorf(x0 + pw * i / 4.0), top, 1, ph), C("#1d2650"))
	for l in [10.0, 13.0, 16.0]:
		var yy := floorf(top + ph - (l - 10.0) / 6.0 * ph)
		ci.draw_rect(Rect2(x0, yy, pw, 1), C("#1d2650"))
	var band := A("#7dff7d", 0.25)
	for x in int(pw):
		var th := x / pw
		var tg := tgt_at(th)
		var y1 := _cy(tg - 0.02, top, ph); var y2 := _cy(tg + 0.02, top, ph)
		ci.draw_rect(Rect2(x0 + x, y2, 1, maxf(1.0, y1 - y2)), band)
	if Tune.has("wideband"):
		var py := -1.0
		for x in int(pw):
			var yy := _cy(lam_at(ev, x / pw), top, ph)
			var a := yy if py < 0 else minf(py, yy)
			var b := yy if py < 0 else maxf(py, yy)
			ci.draw_rect(Rect2(x0 + x, a, 1, b - a + 1), C("#ffd84a"))
			py = yy
	else:
		MiniFont.draw(ci, "WIDEBAND O2 NEEDED FOR AN AFR TRACE", Vector2(x0 + pw / 2, top + 14), C("#8fa3d8"), 1)
		MiniFont.draw(ci, "READ THE PLUG + SYMPTOMS", Vector2(x0 + pw / 2, top + 22), C("#8fa3d8"), 1)
	MiniFont.draw(ci, "16", Vector2(o.x + 2, top - 2), C("#cfe0ff"))
	MiniFont.draw(ci, "13", Vector2(o.x + 2, floorf(top + ph / 2) - 2), C("#cfe0ff"))
	MiniFont.draw(ci, "10", Vector2(o.x + 2, top + ph - 4), C("#cfe0ff"))
	var labs := ["0%", "1/4", "1/2", "3/4", "WOT"]
	for i in 5:
		MiniFont.draw(ci, labs[i], Vector2(x0 + pw * i / 4.0, top + ph + 4), C("#cfe0ff"), 0 if i == 0 else (2 if i == 4 else 1))
	MiniFont.draw(ci, "AFR", Vector2(o.x + w - 3, top + 1), C("#ffd84a"), 2)

## Throttle marker for the chart (drawn on a separate per-frame overlay).
static func draw_chart_marker(ci: CanvasItem, o: Vector2, w: float, s: Dictionary) -> void:
	var x0 := o.x + 14.0
	var pw := w - 20.0
	ci.draw_rect(Rect2(floorf(x0 + float(s.thr) * pw), o.y + 4, 1, 44), Color.WHITE)

static func _cy(l: float, top: float, ph: float) -> float:
	return floorf(top + ph - (clampf(l * 14.7, 10, 16) - 10) / 6.0 * ph)

# ======================================================================
# sync (web Bench.drawSync): Carbtune columns, or by ear
# ======================================================================
static func draw_sync(ci: CanvasItem, o: Vector2, w: float, v: Dictionary, s: Dictionary) -> void:
	var t: float = s.t
	var sync: Array = v.eng.sync
	var n := sync.size()
	var bi := Tune.syncBase(n)
	var h := 92.0
	ci.draw_rect(Rect2(o, Vector2(w, h)), C("#1a2140"))
	var offs := 0.0; var no := 0
	for i in n:
		if i != bi: offs += absf(float(sync[i])); no += 1
	var imb := offs / no if no > 0 else 0.0
	if Tune.has("syncgauge"):
		var span := (w - 24) / maxf(1, n)
		var cw := minf(34.0, span - 8)
		var base_y := o.y + 72.0
		for i in n:
			var x := floorf(o.x + 12 + i * span + (span - cw) / 2)
			ci.draw_rect(Rect2(x, o.y + 6, cw, 66), C("#0d1020"))
			ci.draw_rect(Rect2(x, o.y + 6, cw, 1), C("#7d8590"))
			for m in 11: ci.draw_rect(Rect2(x, o.y + 8 + m * 6, 3 if m % 5 else 5, 1), C("#4b5ea0"))
			var off := float(sync[i])
			var hh := floorf(32 + off * 4.6 + sin(t * (18 + i * 1.3)) * 1.4)
			ci.draw_rect(Rect2(x + floorf(cw / 2) - 3, base_y - hh, 6, hh), C("#c0392b"))
			ci.draw_rect(Rect2(x + floorf(cw / 2) - 3, base_y - hh, 6, 2), C("#ff8080"))
			MiniFont.draw(ci, "BASE" if i == bi else "#%d" % (i + 1), Vector2(x + cw / 2, o.y + 76), C("#ffd84a") if i == bi else C("#cfe0ff"), 1)
			if i != bi:
				var d := "%s%s" % ["+" if off > 0 else "", U.to_fixed(off, 1)]
				MiniFont.draw(ci, d, Vector2(x + cw / 2, o.y + 84), C("#8ef58e") if absf(off) <= 0.3 else C("#ffb347"), 1)
		ci.draw_rect(Rect2(o.x + 8, base_y - 32, w - 16, 1), C("#8ef58e"))
	else:
		var rpm := 1200 + sin(t * (4 + imb * 3)) * imb * 90 + sin(t * 23) * imb * 40
		var col := C("#8ef58e") if imb < 0.6 else (C("#ffd84a") if imb < 1.5 else C("#ff7070"))
		MiniFont.draw(ci, "NO SYNC GAUGES - LISTENING BY EAR", Vector2(o.x + w / 2, o.y + 8), C("#cfe0ff"), 1)
		font8_draw(ci, "IDLE %d RPM" % int(rpm), Vector2(o.x + w / 2, o.y + 22), col, 1)
		# tach needle wobble
		var cx := o.x + w / 2
		ci.draw_rect(Rect2(cx - 60, o.y + 44, 120, 8), C("#0d1020"))
		var nx := cx + (rpm - 1200) / 4.0
		ci.draw_rect(Rect2(floorf(nx) - 1, o.y + 42, 3, 12), col)
		ci.draw_rect(Rect2(cx, o.y + 44, 1, 8), C("#4b5ea0"))
		MiniFont.draw(ci, "SMOOTH AND EVEN" if imb < 0.6 else ("A LITTLE LUMPY" if imb < 1.5 else "LUMPY, HUNTING IDLE"), Vector2(cx, o.y + 62), C("#cfe0ff"), 1)
		MiniFont.draw(ci, "TECH: VACUUM SYNC GAUGES", Vector2(cx, o.y + 78), C("#8fa3d8"), 1)

# ======================================================================
# dyno (web Bench.drawDyno / dynoStep), native px; vehicle drawn by the caller (palette sprite)
# ======================================================================
const DYNO_H := 112.0

static func dyno_start(v: Dictionary, cond: Dictionary, ev: Dictionary) -> Dictionary:
	return {"running": true, "tt": 0.0, "rpm": 0.0, "trace": [], "ev": ev, "vid": v.id, "cond": cond, "cur": null, "done": false, "logged": false, "peak": 0.0}

static func dyno_step(v: Dictionary, d: Dictionary, dt: float) -> void:
	if d == null or not d.running: return
	d.tt = float(d.tt) + dt
	var cls: String = Data.D.BODY[v.body].cls
	var bins: Array = Data.D.RPM_B[cls]
	var f := clampf(float(d.tt) / 4.0, 0, 1)
	d.rpm = float(bins[1]) + (float(bins[7]) - float(bins[1])) * f
	var ic := mini(7, maxi(0, int(roundf(f * 6)) + 1))
	var ev: Dictionary = d.ev
	var lam_c: float = float(ev.cells[5][ic]) if ev.get("cells") != null else float(ev.lam.wot)
	var tgt: float = float(v.eng.efi.afr[5][ic]) / 14.7 if v.eng.fuel == "efi" else float(Data.D.LAM.wot)
	var st := Career.vs(v)
	var base := (float(st.spd) * 0.6 + float(st.acc) * 0.4) * 0.45
	var hp := base * exp(-pow((ic - 5) / 3.0, 2)) * 0.6 + base * 0.4 * (ic / 7.0)
	var pf := Tune.pf(lam_c, "wot")
	var cur := {"lam": lam_c * (1 + rand(-0.008, 0.008)), "tgt": tgt, "kd": float(ev.kd.wot), "hp": hp * pf * float(ev.tf.wot), "ic": ic}
	d.cur = cur
	d.peak = maxf(float(d.peak), float(cur.hp))
	d.trace.append({"r": f, "hp": cur.hp, "lam": cur.lam})
	if f >= 1:
		d.running = false
		d.done = true

## Background, roller, fan, gauges and traces. Returns the vehicle's ground point for the sprite.
static func draw_dyno(ci: CanvasItem, o: Vector2, w: float, v: Dictionary, s: Dictionary, dt: float) -> Vector2:
	var t: float = s.t
	var d = s.dyno
	var run: bool = d is Dictionary and d.vid == v.id and d.running
	var h := DYNO_H
	var floor_y := o.y + 80
	ci.draw_rect(Rect2(o, Vector2(w, h)), C("#1b2036"))
	ci.draw_rect(Rect2(o.x, floor_y, w, h - 80), C("#2a2f45"))
	for x in range(0, int(w), 16): ci.draw_rect(Rect2(o.x + x, floor_y, 1, h - 80), C("#232838"))
	# roller pit
	var rx := o.x + 34
	ci.draw_rect(Rect2(rx - 2, floor_y - 1, 64, 10), C("#141824"))
	ci.draw_rect(Rect2(rx, floor_y, 60, 8), C("#555555"))
	var spin := t * 40.0 if run else 0.0
	for k in 5: ci.draw_rect(Rect2(rx + fmod(k * 12 + spin, 60.0), floor_y, 2, 8), C("#888888"))
	# fan
	ci.draw_rect(Rect2(o.x + 4, floor_y - 40, 10, 40), C("#3d4766"))
	ci.draw_rect(Rect2(o.x + 2, floor_y - 42, 14, 3), C("#4f5b80"))
	for k in 4: ci.draw_rect(Rect2(o.x + 6, floor_y - 36 + k * 8, 6, 2), C("#2a3150"))
	if run:
		for k in 5: ci.draw_rect(Rect2(o.x + 16 + fmod(t * 80 + k * 13, 30.0), floor_y - 34 + k * 6, 6, 1), C("#7fd3ff"))
		if chance(0.6): s.smoke.append({"x": o.x + 24.0, "y": floor_y - 8, "vx": -20.0, "vy": -6.0, "t": 0.0})
	# smoke puffs
	var sm := []
	for p in s.smoke:
		p.t = float(p.t) + dt
		if p.t >= 0.8: continue
		p.x = float(p.x) + float(p.vx) * dt
		p.y = float(p.y) + float(p.vy) * dt
		sm.append(p)
		ci.draw_rect(Rect2(floorf(p.x), floorf(p.y), 3, 3), Color(0.4, 0.4, 0.45, 1.0 - float(p.t)))
	s.smoke = sm
	# rpm gauge
	var cls: String = Data.D.BODY[v.body].cls
	var rpm_max := float(Data.D.RPM_B[cls][7])
	var rpm: float = float(d.rpm) if d is Dictionary and d.vid == v.id else 0.0
	var gx := o.x + 104.0
	ci.draw_rect(Rect2(gx, o.y + 4, 66, 70), C("#0d1020"))
	var c := Vector2(gx + 33, o.y + 36)
	ci.draw_arc(c, 24, PI * 0.8, PI * 2.2, 24, C("#4b5ea0"), 1.0, false)
	ci.draw_arc(c, 24, PI * 1.9, PI * 2.2, 8, C("#c0392b"), 2.0, false)
	for k in 9:
		var a := PI * 0.8 + PI * 1.4 * k / 8.0
		ci.draw_rect(Rect2(floorf(c.x + cos(a) * 21), floorf(c.y + sin(a) * 21), 1, 1), C("#cfe0ff"))
	var ang := PI * 0.8 + PI * 1.4 * (rpm / rpm_max)
	ci.draw_line(c, c + Vector2(cos(ang), sin(ang)) * 20, C("#ff6060"), 1.0, false)
	ci.draw_rect(Rect2(c - Vector2(1, 1), Vector2(3, 3)), C("#cfe0ff"))
	MiniFont.draw(ci, "%d RPM" % int(rpm), Vector2(c.x, o.y + 64), C("#cfe0ff"), 1)
	MiniFont.draw(ci, "X1000", Vector2(c.x, o.y + 46), C("#4b5ea0"), 1)
	# AFR / knock / hp column
	var ax := o.x + 174.0
	ci.draw_rect(Rect2(ax, o.y + 4, w - 178, 70), C("#0d1020"))
	var cx := ax + (w - 178) / 2
	MiniFont.draw(ci, "AFR", Vector2(cx, o.y + 8), C("#8fa3d8"), 1)
	if d is Dictionary and d.vid == v.id and d.cur != null:
		var cur: Dictionary = d.cur
		var l: float = cur.lam
		font8_draw(ci, U.to_fixed(l * 14.7, 1) if Tune.has("wideband") else "--", Vector2(cx, o.y + 16), afr_col(l, float(cur.tgt)), 1)
		if float(cur.kd) > 0.3:
			MiniFont.draw(ci, "KNOCK!", Vector2(cx, o.y + 30), C("#ff4040") if int(t * 6) % 2 else C("#ffd84a"), 1)
		MiniFont.draw(ci, "POWER", Vector2(cx, o.y + 42), C("#8fa3d8"), 1)
		font8_draw(ci, "%d" % int(roundf(float(cur.hp))), Vector2(cx, o.y + 50), C("#ffd84a"), 1)
		MiniFont.draw(ci, "HP", Vector2(cx, o.y + 61), C("#8fa3d8"), 1)
	else:
		font8_draw(ci, "--", Vector2(cx, o.y + 16), C("#4b5ea0"), 1)
		MiniFont.draw(ci, "POWER", Vector2(cx, o.y + 42), C("#8fa3d8"), 1)
		font8_draw(ci, "--", Vector2(cx, o.y + 50), C("#4b5ea0"), 1)
	# power + AFR traces
	var tx := o.x + 4.0
	var tw := 96.0
	ci.draw_rect(Rect2(tx, o.y + 4, tw, 30), C("#0d1020"))
	MiniFont.draw(ci, "POWER", Vector2(tx + 2, o.y + 6), C("#ffd84a"))
	MiniFont.draw(ci, "AFR", Vector2(tx + tw - 2, o.y + 6), C("#7fd3ff"), 2)
	if d is Dictionary and d.vid == v.id and not d.trace.is_empty():
		var mx := 1.0
		for q in d.trace: mx = maxf(mx, float(q.hp))
		for q in d.trace:
			var x := floorf(tx + 2 + float(q.r) * (tw - 4))
			ci.draw_rect(Rect2(x, floorf(o.y + 32 - float(q.hp) / mx * 20), 1, 1), C("#ffd84a"))
			ci.draw_rect(Rect2(x, floorf(o.y + 32 - clampf((float(q.lam) * 14.7 - 10) / 6, 0, 1) * 20), 1, 1), C("#7fd3ff"))
	return Vector2(rx + 30, floor_y + 1)
