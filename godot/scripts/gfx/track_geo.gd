class_name TrackGeo
extends RefCounted
## Turns the sim's 1-D section list into a 2-D course for the Mode 7 floor.
## - Loops close exactly (turning sums to 360 deg, positional drift spread along the lap);
##   point-to-point stages meander; drag strips are straight.
## - Every bend gets enough drawn length for a minimum radius (half the road + verge), so the road
##   never folds onto itself in hairpins/chicanes. Progress maps to arc length per section, so the sim's
##   timing is unchanged while tight sections are drawn longer.
## - Layouts whose distant parts crowd each other are re-rolled (deterministic per race id).
## - Very large stages paint their floor texture at reduced resolution instead of shrinking the track.

const STEP := 4.0
const MAX_TEX := 4096.0      # per side (every GLES3 phone we target handles 4096)
const MAX_TEXELS := 6.0e6    # ~24 MB of RGBA8 for the painted floor
const LANE_PX := 26.0      # one car's width of road + a gap
const BASE_UNIT := 160.0

var unit := BASE_UNIT      # world px per section unit (straights)
var lanes := 3
var width := 94.0          # road width
var pts := PackedVector2Array()
var heads := PackedFloat32Array()
var lap_px := 0.0
var closed := true
var tr: Dictionary
var bbox := Rect2()
var sec_px := PackedFloat32Array()    # arc length where each section starts
var sec_len := PackedFloat32Array()   # drawn length of each section
var tex_scale := 1.0                  # world px per floor-texture texel
var crowding := 0
var debug_close := false
var close_err := 0.0                  # loop gap left after the length solve (px)

static func build(track: Dictionary, seed_id: String) -> TrackGeo:
	var g := TrackGeo.new()
	g.tr = track
	g.closed = not (track.p2p or track.drag)
	g.lanes = int(track.get("lanes", 3))
	g.width = g.lanes * LANE_PX + 16.0
	var best := {}
	var best_bad := 1 << 30
	for attempt in 24:
		if attempt > 0 and attempt % 8 == 0: g.unit *= 1.1      # more room if it keeps crowding
		g._layout(seed_id, attempt)
		var bad := g._crowding()
		# a loop that only closes by bending it shut distorts its bends: count that as crowding
		if g.closed and g.close_err > g.lap_px * 0.012: bad += int(g.close_err / g.lap_px * 2000.0)
		if bad < best_bad:
			best_bad = bad
			best = {"pts": g.pts, "heads": g.heads, "lap_px": g.lap_px, "bbox": g.bbox, "sec_px": g.sec_px, "sec_len": g.sec_len, "unit": g.unit}
		if bad == 0 or track.drag: break
	for k in best: g.set(k, best[k])
	g.crowding = best_bad
	var big: float = max(g.bbox.size.x, g.bbox.size.y)
	g.tex_scale = maxf(1.0, maxf(big / (MAX_TEX - 8.0), sqrt(g.bbox.size.x * g.bbox.size.y / MAX_TEXELS)))
	return g

func min_radius() -> float: return width * 0.5 + 34.0

func _turns(seed_id: String, attempt: int) -> Array:
	var rng := URng.new(URng.fnv(seed_id + ":geo" + (str(attempt) if attempt > 0 else "")))
	var secs: Array = tr.secs
	var a := []
	var dir := 1.0
	var last := 1.0
	var cum := 0.0
	for i in secs.size():
		var s: Dictionary = secs[i]
		var ang := 0.0
		match s.type:
			"crv": ang = deg_to_rad(rng.range_f(55, 105))
			"hp": ang = deg_to_rad(rng.range_f(140, 170))
			"hill": ang = deg_to_rad(rng.range_f(15, 45))
		var sgn := dir
		if closed:
			if s.type == "crv" and rng.chance(0.12): sgn = -dir
			if tr.oval: ang = PI / 2.0 if s.type == "crv" else 0.0
		else:
			# meander, but keep heading within ~100 deg of the start so a stage never doubles back
			if absf(cum) > deg_to_rad(25.0): sgn = -signf(cum)
			else: sgn = -last if rng.chance(0.7) else last
			if ang != 0.0: last = sgn
			cum += ang * sgn
		a.append(ang * sgn)
	if tr.drag:
		for i in a.size(): a[i] = 0.0
		return a
	if closed:
		var net := 0.0
		for x in a: net += x
		if net < PI * 0.6:
			for i in a.size():
				if secs[i].type == "str" or secs[i].type == "jmp" or secs[i].type == "lau": a[i] += (TAU - net) / secs.size() * 1.6
		var pos := 0.0; var neg := 0.0
		for x in a:
			if x > 0: pos += x
			else: neg += x
		var k: float = (TAU - neg) / max(pos, 0.001)
		for i in a.size():
			if a[i] > 0: a[i] *= k
	return a

## Fraction of a section's length that carries its turn.
func _span(type: String) -> float:
	match type:
		"chi": return 0.8
		"rgh": return 1.0
	return 0.86

func _kappa(type: String, u: float, ang: float, Ls: float) -> float:
	match type:
		"chi":
			var amp := deg_to_rad(60.0) / (Ls * 0.4)
			if u < 0.1 or u > 0.9: return 0.0
			return amp if u < 0.5 else -amp
		"rgh":
			return sin(u * TAU * 2.0) * deg_to_rad(28.0) / Ls * PI
		_:
			if ang == 0.0 or u < 0.07 or u > 0.93: return 0.0
			return ang / (Ls * 0.86)

func _layout(seed_id: String, attempt: int) -> void:
	var secs: Array = tr.secs
	var turns := _turns(seed_id, attempt)
	pts = PackedVector2Array(); heads = PackedFloat32Array(); sec_px = PackedFloat32Array(); sec_len = PackedFloat32Array()
	var R := min_radius()
	var lens := []
	for i in secs.size():
		var t0: String = secs[i].type
		var need: float = absf(turns[i])
		if t0 == "chi": need = deg_to_rad(120.0)
		elif t0 == "rgh": need = 1.6
		lens.append(maxf(float(secs[i].len) * unit, need * R / _span(t0)))
	if closed:
		var tl := _close_loop(secs, turns, lens)
		turns = tl[0]; lens = tl[1]
	var p := Vector2.ZERO
	var h := -PI / 2.0
	pts.append(p); heads.append(h)
	var s_acc := 0.0
	for i in secs.size():
		var t: String = secs[i].type
		var Ls: float = lens[i]
		sec_px.append(s_acc); sec_len.append(Ls)
		var n := int(ceil(Ls / STEP))
		var ds := Ls / n
		for j in n:
			var u := (j + 0.5) / n
			h += _kappa(t, u, turns[i], Ls) * ds
			p += Vector2.from_angle(h) * ds
			pts.append(p); heads.append(h)
		s_acc += Ls
	lap_px = s_acc
	close_err = 0.0
	if closed:
		var gap := pts[pts.size() - 1] - pts[0]
		close_err = gap.length()
		for i in pts.size():
			pts[i] -= gap * (float(i) / (pts.size() - 1))
		for i in pts.size():
			var a := pts[max(0, i - 1)]; var b := pts[min(pts.size() - 1, i + 1)]
			heads[i] = (b - a).angle()
	var mn := Vector2(INF, INF); var mx := -mn
	for q in pts:
		mn = mn.min(q); mx = mx.max(q)
	var margin := 200.0 + width * 0.5
	bbox = Rect2(mn - Vector2(margin, margin), mx - mn + Vector2(margin, margin) * 2.0)

## Close a loop without bending it shut. The end point is sum(L_i * rot(h_i) * chord_i(turn_i)), so we
## nudge section lengths (straights first) and turn angles (within +-35%, signs kept, total 360 deg)
## by iterated weighted least-norm steps until the end meets the start. Bends keep their minimum radius.
static var _chord_cache := {}

func _chord(type: String, a: float) -> Vector2:
	if type == "chi" or type == "rgh":
		if _chord_cache.has(type): return _chord_cache[type]
		var c := Vector2.ZERO
		var hh := 0.0
		for j in 48:
			hh += _kappa(type, (j + 0.5) / 48.0, 0.0, 1.0) / 48.0
			c += Vector2.from_angle(hh) / 48.0
		_chord_cache[type] = c
		return c
	var arc := Vector2(0.86, 0.0) if absf(a) < 1e-4 else Vector2(sin(a), 1.0 - cos(a)) * (0.86 / a)
	return Vector2(0.07, 0.0) + arc + Vector2.from_angle(a) * 0.07

func _loop_res(secs: Array, x: Array, m: int, K: float) -> Vector3:
	var h := -PI / 2.0
	var e := Vector2.ZERO
	var tot := 0.0
	for i in m:
		var a: float = x[m + i]
		e += (_chord(secs[i].type, a) * float(x[i])).rotated(h)
		h += a; tot += a
	return Vector3(e.x, e.y, (tot - TAU) * K)

func _close_loop(secs: Array, turns: Array, lens: Array) -> Array:
	var m := secs.size()
	var R := min_radius()
	var K := 400.0
	var x := lens.duplicate() + turns.duplicate()
	var lo := []; var hi := []; var w := []
	for i in m:
		var L0: float = lens[i]
		var t: String = secs[i].type
		var straight: bool = turns[i] == 0.0 and not (t in ["chi", "rgh"])
		if straight: lo.append(0.4 * L0); hi.append(3.0 * L0); w.append(pow(0.6 * L0, 2))
		elif t in ["chi", "rgh"]: lo.append(L0); hi.append(2.0 * L0); w.append(pow(0.2 * L0, 2))
		else: lo.append(0.8 * L0); hi.append(3.0 * L0); w.append(pow(0.4 * L0, 2))
	for i in m:
		var a0: float = turns[i]
		var t2: String = secs[i].type
		if t2 in ["chi", "rgh", "jmp", "lau"]:
			lo.append(a0); hi.append(a0); w.append(0.0)
		elif a0 == 0.0 or t2 == "str":
			# straights may sweep a little
			lo.append(a0 - 0.45); hi.append(a0 + 0.45); w.append(0.02)
		else:
			var a1 := a0 * 0.6; var a2 := a0 * 1.4
			lo.append(maxf(minf(a1, a2), -3.0)); hi.append(minf(maxf(a1, a2), 3.0))
			w.append(pow(0.25 * absf(a0), 2))
	var n := 2 * m
	var r := _loop_res(secs, x, m, K)
	for it in 60:
		if debug_close: print("    it", it, " r=", r)
		if Vector2(r.x, r.y).length() < 2.0 and absf(r.z) < 1.0: break
		var J := []
		for k in n:
			if w[k] == 0.0: J.append(Vector3.ZERO); continue
			var dx: float = 1.0 if k < m else 0.001
			var x2 := x.duplicate(); x2[k] = float(x2[k]) + dx
			J.append((_loop_res(secs, x2, m, K) - r) / dx)
		var cols := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		for k in n:
			var wk: float = w[k]
			if wk == 0.0: continue
			if (x[k] <= lo[k] + 1e-6 or x[k] >= hi[k] - 1e-6) and it > 0: wk *= 0.05   # pinned at a limit
			var j: Vector3 = J[k]
			cols[0] += j * j.x * wk; cols[1] += j * j.y * wk; cols[2] += j * j.z * wk
		var M := Basis(cols[0], cols[1], cols[2])
		if absf(M.determinant()) < 1e-9: break
		var lam: Vector3 = M.inverse() * (-r)
		var step := 1.0
		var best_x := x
		var best_r := r
		for ls in 4:
			var xn := x.duplicate()
			for k in n:
				if w[k] == 0.0: continue
				xn[k] = clampf(float(xn[k]) + step * float(w[k]) * (J[k] as Vector3).dot(lam), lo[k], hi[k])
			for i in m:
				if secs[i].type in ["chi", "rgh"]: continue
				xn[i] = maxf(float(xn[i]), absf(float(xn[m + i])) * R / 0.86)
			var rn := _loop_res(secs, xn, m, K)
			if rn.length() < best_r.length():
				best_x = xn; best_r = rn
				break
			step *= 0.5
		if best_x == x: break
		x = best_x; r = best_r
	return [x.slice(m), x.slice(0, m)]

## Pairs of road samples that are far apart along the course but close on the ground.
func _crowding() -> int:
	var min_d := width + 48.0
	var cell := min_d
	var grid := {}
	var stride := 3
	var n := pts.size()
	for i in range(0, n, stride):
		var c := Vector2i(floor(pts[i].x / cell), floor(pts[i].y / cell))
		if not grid.has(c): grid[c] = []
		grid[c].append(i)
	var along := min_d * 2.4 / STEP
	var bad := 0
	for i in range(0, n, stride):
		var c := Vector2i(floor(pts[i].x / cell), floor(pts[i].y / cell))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for j in grid.get(c + Vector2i(dx, dy), []):
					if j <= i: continue
					var sep := float(j - i)
					if closed: sep = minf(sep, float(n - (j - i)))
					if sep < along: continue
					if pts[i].distance_to(pts[j]) < min_d: bad += 1
	return bad

## Arc length (px) for a progress value (section units).
func px_of(prog: float) -> float:
	var L: float = tr.lapLen
	if not closed:
		if prog < 0: return prog * unit
		if prog >= L: return lap_px + (prog - L) * unit
	var lp := fposmod(prog, L)
	var secs: Array = tr.secs
	var i := secs.size() - 1
	while i > 0 and lp < float(secs[i].at): i -= 1
	return sec_px[i] + (lp - float(secs[i].at)) / float(secs[i].len) * sec_len[i]

## Position/heading at progress p (section units). lane: lateral offset in lanes from the centre line.
func sample(prog: float, lane: float = 0.0) -> Dictionary:
	var s := px_of(prog)
	var f := s / STEP
	var n := pts.size() - 1
	var i := int(floor(f))
	var t := f - i
	var a: Vector2; var b: Vector2; var ha: float; var hb: float
	if i < 0:
		a = pts[0] + Vector2.from_angle(heads[0]) * (f * STEP); b = a; ha = heads[0]; hb = ha; t = 0
	elif i >= n:
		a = pts[n]; b = pts[n]; ha = heads[n]; hb = ha
	else:
		a = pts[i]; b = pts[i + 1]; ha = heads[i]; hb = heads[i + 1]
	var pos := a.lerp(b, t)
	var hd := lerp_angle(ha, hb, t)
	var nrm := Vector2.from_angle(hd + PI / 2.0)
	return {"pos": pos + nrm * lane * LANE_PX, "ang": hd}

func sec_index_at_px(s: float) -> int:
	for i in range(sec_px.size() - 1, -1, -1):
		if s >= sec_px[i]: return i
	return 0
