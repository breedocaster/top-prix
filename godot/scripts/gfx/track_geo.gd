class_name TrackGeo
extends RefCounted
## Turns the sim's 1-D section list into a 2-D course for the Mode 7 floor.
## Loops close exactly (turning sums to 360 degrees, positional drift is spread along the lap);
## point-to-point stages meander; drag strips are straight. Progress `p` (section units) maps to arc length.

const STEP := 4.0
const MAX_TEX := 2048.0

const LANE_PX := 22.0      # one car's width of tarmac
var lanes := 3
var unit := 120.0          # world px per section unit
var width := 54.0          # track width
var pts := PackedVector2Array()
var heads := PackedFloat32Array()
var lap_px := 0.0
var closed := true
var tr: Dictionary
var bbox := Rect2()
var sec_px := PackedFloat32Array()   # arc length at section starts

static func build(track: Dictionary, seed_id: String) -> TrackGeo:
	var g := TrackGeo.new()
	g.tr = track
	g.closed = not (track.p2p or track.drag)
	g.lanes = int(track.get("lanes", 3))
	g.width = g.lanes * LANE_PX + 14.0
	g._layout(seed_id)
	var big: float = max(g.bbox.size.x, g.bbox.size.y)
	if big > MAX_TEX - 320.0:
		g.unit *= (MAX_TEX - 320.0) / big
		g._layout(seed_id)
	return g

func _turns(seed_id: String) -> Array:
	var rng := URng.new(URng.fnv(seed_id + ":geo"))
	var secs: Array = tr.secs
	var a := []
	var dir := 1.0
	for i in secs.size():
		var s: Dictionary = secs[i]
		var ang := 0.0
		match s.type:
			"crv": ang = deg_to_rad(rng.range_f(55, 105))
			"hp": ang = deg_to_rad(rng.range_f(150, 175))
			"hill": ang = deg_to_rad(rng.range_f(15, 45))
		var sgn := dir
		if closed:
			if s.type == "crv" and rng.chance(0.2): sgn = -dir
			if tr.oval: ang = PI / 2.0 if s.type == "crv" else 0.0
		else:
			sgn = 1.0 if rng.chance(0.5) else -1.0
		a.append(ang * sgn)
	if tr.drag:
		for i in a.size(): a[i] = 0.0
		return a
	if closed:
		var net := 0.0
		for x in a: net += x
		if net < PI * 0.6:
			# not enough turning in curves (fast tracks): bend the straights a little too
			for i in a.size():
				if secs[i].type == "str" or secs[i].type == "jmp" or secs[i].type == "lau": a[i] += (TAU - net) / secs.size() * 1.6
			net = 0.0
			for x in a: net += x
		var pos := 0.0; var neg := 0.0
		for x in a:
			if x > 0: pos += x
			else: neg += x
		var k: float = (TAU - neg) / max(pos, 0.001)
		for i in a.size():
			if a[i] > 0: a[i] *= k
	return a

func _kappa(type: String, u: float, ang: float, Ls: float) -> float:
	# curvature profile within a section (u in 0..1); integrates to `ang`
	match type:
		"chi":
			var amp := deg_to_rad(70.0) / (Ls * 0.4)
			if u < 0.1 or u > 0.9: return 0.0
			return amp if u < 0.5 else -amp
		"rgh":
			return sin(u * TAU * 2.0) * deg_to_rad(40.0) / Ls * PI
		_:
			if ang == 0.0: return 0.0
			if u < 0.15 or u > 0.85: return 0.0
			return ang / (Ls * 0.7)

func _layout(seed_id: String) -> void:
	var secs: Array = tr.secs
	var turns := _turns(seed_id)
	pts = PackedVector2Array(); heads = PackedFloat32Array(); sec_px = PackedFloat32Array()
	var p := Vector2.ZERO
	var h := -PI / 2.0
	pts.append(p); heads.append(h)
	var s_acc := 0.0
	for i in secs.size():
		sec_px.append(s_acc)
		var Ls: float = secs[i].len * unit
		var n := int(ceil(Ls / STEP))
		var ds := Ls / n
		for j in n:
			var u := (j + 0.5) / n
			h += _kappa(secs[i].type, u, turns[i], Ls) * ds
			p += Vector2.from_angle(h) * ds
			pts.append(p); heads.append(h)
		s_acc += Ls
	lap_px = s_acc
	if closed:
		var gap := pts[pts.size() - 1] - pts[0]
		for i in pts.size():
			pts[i] -= gap * (float(i) / (pts.size() - 1))
		for i in pts.size():
			var a := pts[max(0, i - 1)]; var b := pts[min(pts.size() - 1, i + 1)]
			heads[i] = (b - a).angle()
	var mn := Vector2(INF, INF); var mx := -mn
	for q in pts:
		mn = mn.min(q); mx = mx.max(q)
	var margin := 160.0
	bbox = Rect2(mn - Vector2(margin, margin), mx - mn + Vector2(margin, margin) * 2.0)

## Position/heading at progress p (section units). lane: -1..1 lateral offset in lanes.
func sample(prog: float, lane: float = 0.0) -> Dictionary:
	var s: float = fposmod(prog, tr.lapLen) * unit if (closed or prog >= 0) else prog * unit
	if not closed and prog >= 0: s = fposmod(prog, tr.lapLen) * unit
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
