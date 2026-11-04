class_name SDModels
extends RefCounted
## Super-deformed ("Choro-Q / Penny Racers") vehicle models built from signed-distance primitives:
## squeezed bodies, tall bubble cabins, big rubber (rear tyres larger), round headlight "eyes",
## garish decals and the coin slot in the tail. Voxelized at sprite resolution (1 voxel ~ 1 px)
## with smooth normals from the SDF gradient for pre-rendered, glossy shading.
## Model space: x forward, y right, z up; ground at z = 0.

const M := SpriteForge.M

# ---------------- primitives ----------------
static func rbox(c: Vector3, h: Vector3, r: float, m: int, paint := false) -> Dictionary:
	return {"t": 0, "c": c, "h": h, "r": r, "m": m, "paint": paint}
static func ell(c: Vector3, rad: Vector3, m: int, paint := false) -> Dictionary:
	return {"t": 1, "c": c, "h": rad, "r": 0.0, "m": m, "paint": paint}
static func cyl(c: Vector3, radius: float, half_w: float, m: int, round_r := 0.8) -> Dictionary:
	return {"t": 2, "c": c, "h": Vector3(radius, half_w, radius), "r": round_r, "m": m, "paint": false}
static func cylz(c: Vector3, radius: float, half_h: float, m: int, round_r := 0.8) -> Dictionary:
	return {"t": 4, "c": c, "h": Vector3(radius, radius, half_h), "r": round_r, "m": m, "paint": false}
static func cap(a: Vector3, b: Vector3, r: float, m: int) -> Dictionary:
	return {"t": 3, "c": a, "h": b, "r": r, "m": m, "paint": false}

static func sd(p: Vector3, q: Dictionary) -> float:
	match q.t:
		0:
			var d: Vector3 = (p - q.c).abs() - (q.h - Vector3.ONE * q.r)
			return Vector3(max(d.x, 0), max(d.y, 0), max(d.z, 0)).length() + min(max(d.x, max(d.y, d.z)), 0.0) - q.r
		1:
			var rr: Vector3 = q.h
			var k0: float = ((p - q.c) / rr).length()
			var k1: float = ((p - q.c) / (rr * rr)).length()
			return k0 * (k0 - 1.0) / max(k1, 1e-6)
		2:
			var c: Vector3 = q.c
			var dx: float = Vector2(p.x - c.x, p.z - c.z).length() - (q.h.x - q.r)
			var dy: float = absf(p.y - c.y) - (q.h.y - q.r)
			return min(max(dx, dy), 0.0) + Vector2(max(dx, 0), max(dy, 0)).length() - q.r
		4:
			var c4: Vector3 = q.c
			var dxy: float = Vector2(p.x - c4.x, p.y - c4.y).length() - (q.h.x - q.r)
			var dz: float = absf(p.z - c4.z) - (q.h.z - q.r)
			return min(max(dxy, dz), 0.0) + Vector2(max(dxy, 0), max(dz, 0)).length() - q.r
		3:
			var a: Vector3 = q.c; var b: Vector3 = q.h
			var pa := p - a; var ba := b - a
			var hh: float = clampf(pa.dot(ba) / ba.dot(ba), 0, 1)
			return (pa - ba * hh).length() - q.r
	return 1e9

static func _bounds(q: Dictionary) -> AABB:
	if q.t == 3:
		var a: Vector3 = q.c; var b: Vector3 = q.h
		return AABB(a.min(b) - Vector3.ONE * (q.r + 1), (a - b).abs() + Vector3.ONE * (q.r * 2 + 2))
	var h: Vector3 = q.h + Vector3.ONE * 1.5
	return AABB(q.c - h, h * 2)

## Voxelize: {Vector3i: [material, normal]} for surface voxels only.
static func voxelize(parts: Array) -> Dictionary:
	var solids := parts.filter(func(q): return not q.paint)
	var paints := parts.filter(func(q): return q.paint)
	var box := _bounds(solids[0])
	for q in solids: box = box.merge(_bounds(q))
	var lo := Vector3i(box.position.floor())
	lo.z = maxi(0, lo.z)
	var hi := Vector3i(box.end.ceil())
	var inside := {}
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var best := 0.5
				var m := -1
				for q in solids:
					if not _bounds(q).has_point(p): continue
					var d := sd(p, q)
					if d < best: best = d; m = q.m
				if m >= 0: inside[Vector3i(x, y, z)] = m
	var out := {}
	var nb := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for v in inside:
		var surface := false
		for o in nb:
			if not inside.has(v + o): surface = true; break
		if not surface: continue
		var p := Vector3(v) + Vector3(0.5, 0.5, 0.5)
		var m: int = inside[v]
		for q in paints:
			if _bounds(q).has_point(p) and sd(p, q) < 0.0: m = q.m
		out[v] = [m, _normal(p, solids)]
	return out

static func _field(p: Vector3, solids: Array) -> float:
	var best := 1e9
	for q in solids:
		if _bounds(q).grow(2).has_point(p): best = min(best, sd(p, q))
	return best

static func _normal(p: Vector3, solids: Array) -> Vector3:
	var e := 0.7
	var n := Vector3(
		_field(p + Vector3(e, 0, 0), solids) - _field(p - Vector3(e, 0, 0), solids),
		_field(p + Vector3(0, e, 0), solids) - _field(p - Vector3(0, e, 0), solids),
		_field(p + Vector3(0, 0, e), solids) - _field(p - Vector3(0, 0, e), solids))
	return n.normalized() if n.length() > 1e-5 else Vector3.UP

# ---------------- kinds ----------------
## Archetype params per body kind. Units ~ sprite pixels.
static func spec(kind: String) -> Dictionary:
	var car := {"t": "car", "L": 28, "W": 20, "bz": 4.0, "bh": 9.0, "br": 4.0, "cx": -2.0, "cl": 17.0, "cw": 17.0, "ch": 10.0, "cr": 5.0,
		"wf": 5.0, "wr": 6.0, "ax": 9.0}
	match kind:
		"hatch": return car
		"sedan": return car.merged({"L": 31, "cx": -1.0, "cl": 16.0, "ch": 9.0, "ax": 10.0}, true)
		"coupe": return car.merged({"L": 29, "bh": 8.0, "cx": -3.0, "cl": 14.0, "ch": 8.0, "spoiler": true}, true)
		"gt", "super": return car.merged({"L": 30, "W": 22, "bh": 7.0, "bz": 3.5, "cx": -2.0, "cl": 13.0, "cw": 18.0, "ch": 7.0, "spoiler": true, "stripe": true, "wf": 5.0, "wr": 6.5}, true)
		"roadster": return car.merged({"L": 28, "bh": 8.0, "open": true}, true)
		"proto": return car.merged({"L": 31, "W": 22, "bh": 6.0, "bz": 3.0, "canopy": true, "fin": true, "spoiler": true, "stripe": true}, true)
		"pickup": return car.merged({"L": 31, "bz": 6.0, "bh": 9.0, "cx": 4.0, "cl": 12.0, "ch": 9.0, "bed": true, "wf": 6.0, "wr": 7.0, "ax": 10.0}, true)
		"truck": return car.merged({"L": 32, "W": 22, "bz": 8.0, "bh": 9.0, "cx": 4.0, "cl": 12.0, "ch": 9.0, "bed": true, "bar": true, "wf": 7.5, "wr": 8.0, "ax": 10.5}, true)
		"rally": return car.merged({"bz": 5.0, "spoiler": true, "stripe": true, "bar": true, "flaps": true, "wf": 5.5, "wr": 6.0}, true)
		"buggy": return {"t": "buggy", "L": 26, "W": 20, "wf": 6.0, "wr": 7.5, "ax": 8.5}
		"sprint": return {"t": "buggy", "L": 24, "W": 18, "wf": 5.5, "wr": 7.5, "ax": 8.0, "topwing": true}
		"formula": return {"t": "formula", "L": 32, "W": 22, "wf": 5.0, "wr": 6.5, "ax": 10.0}
		"kart": return {"t": "kart", "L": 20, "W": 18, "wf": 3.5, "wr": 4.0, "ax": 6.5}
		"sidecar": return {"t": "bike", "fairing": true, "sidecar": true}
		"scooter": return {"t": "bike", "upright": true, "scooter": true, "wf": 4.0, "wr": 4.0}
		"commuter", "naked": return {"t": "bike", "upright": true}
		"cafe": return {"t": "bike", "cafe": true}
		"sport", "gp": return {"t": "bike", "fairing": true}
		"trail", "mx", "enduro", "raid", "smoto", "flat": return {"t": "bike", "dirt": true, "upright": kind in ["trail", "raid", "flat"], "wf": 6.0, "wr": 6.0}
	return car

static func _wheels(parts: Array, ax: float, wf: float, wr: float, y: float, ww: float) -> void:
	for side in [-1.0, 1.0]:
		for w in [[ax, wf], [-ax, wr]]:
			var c := Vector3(w[0], side * y, w[1])
			parts.append(cyl(c, w[1], ww, M.TIRE, 1.4))
			parts.append(cyl(c + Vector3(0, side * 0.6, 0), w[1] * 0.5, ww * 0.95, M.METAL, 0.6))

static func build(kind: String) -> Dictionary:
	var s := spec(kind)
	var P := []
	match s.t:
		"car":
			var L: float = s.L; var W: float = s.W; var bz: float = s.bz; var bh: float = s.bh
			var zc := bz + bh * 0.5
			P.append(rbox(Vector3(0, 0, zc), Vector3(L * 0.5, W * 0.5, bh * 0.5), s.br, M.BODY))
			if s.get("open", false):
				P.append(rbox(Vector3(1, 0, bz + bh + 1.5), Vector3(1, W * 0.4, 2.5), 1.0, M.GLASS))       # windscreen
				P.append(ell(Vector3(-4, 0, bz + bh + 3.5), Vector3(3.5, 3.5, 3.5), M.HELMET))            # driver
				P.append(cap(Vector3(-8, -5, bz + bh), Vector3(-8, 5, bz + bh + 2), 1.2, M.TRIM))
			elif s.get("canopy", false):
				P.append(ell(Vector3(-1, 0, bz + bh), Vector3(9, 7, 6), M.GLASS))
			else:
				var cz: float = bz + bh + s.ch * 0.5 - 1.0
				P.append(rbox(Vector3(s.cx, 0, cz), Vector3(s.cl * 0.5, s.cw * 0.5, s.ch * 0.5), s.cr, M.BODY))
				# window band painted around the cabin, roof stays body colour
				P.append(rbox(Vector3(s.cx, 0, cz - 0.5), Vector3(s.cl * 0.5 + 1, s.cw * 0.5 + 1, s.ch * 0.32), 1.0, M.GLASS, true))
				P.append(rbox(Vector3(s.cx, 0, cz - 0.5), Vector3(0.7, s.cw * 0.5 + 1, s.ch * 0.32), 0.2, M.BODY, true))  # B-pillar
			if s.get("stripe", false):
				P.append(rbox(Vector3(0, 0, bz + bh + 6), Vector3(L * 0.5 + 1, 2.2, 12), 0.5, M.ACCENT, true))
			# side roundel (race number disc) — the Penny Racers garish decal
			P.append(ell(Vector3(1, 0, zc + 0.5), Vector3(3.2, W * 0.5 + 1, 3.2), M.PLATE, true))
			# headlight "eyes", grille, tail lights, bumpers, coin slot
			for side in [-1.0, 1.0]:
				P.append(ell(Vector3(L * 0.5 - 0.5, side * W * 0.27, zc + 1.0), Vector3(1.6, 2.2, 2.2), M.LIGHT))
				P.append(ell(Vector3(-L * 0.5 + 0.5, side * W * 0.3, zc + 1.5), Vector3(1.2, 1.8, 1.3), M.RED))
			P.append(rbox(Vector3(L * 0.5, 0, bz + 1.5), Vector3(1.2, W * 0.45, 1.3), 1.0, M.TRIM))
			P.append(rbox(Vector3(-L * 0.5, 0, bz + 1.5), Vector3(1.2, W * 0.45, 1.3), 1.0, M.TRIM))
			P.append(rbox(Vector3(-L * 0.5 + 0.4, 0, bz + bh - 1.8), Vector3(1.0, 2.6, 0.5), 0.1, M.TRIM, true))
			if s.get("spoiler", false):
				P.append(rbox(Vector3(-L * 0.5 + 1.5, 0, bz + bh + 4.5), Vector3(2.2, W * 0.48, 0.8), 0.4, M.ACCENT))
				for side in [-1.0, 1.0]: P.append(cap(Vector3(-L * 0.5 + 2, side * W * 0.3, bz + bh), Vector3(-L * 0.5 + 2, side * W * 0.3, bz + bh + 4), 0.8, M.TRIM))
			if s.get("fin", false):
				P.append(rbox(Vector3(-L * 0.5 + 4, 0, bz + bh + 3), Vector3(4, 0.7, 3), 0.5, M.BODY))
			if s.get("bed", false):
				P.append(rbox(Vector3(-L * 0.25, 0, bz + bh + 0.2), Vector3(L * 0.22, W * 0.4, 1.0), 0.3, M.TRIM, true))
			if s.get("bar", false):
				var bx: float = s.cx + 1.0 if not s.get("bed", false) else s.cx
				P.append(rbox(Vector3(bx, 0, bz + bh + s.ch + 0.5), Vector3(1.5, s.cw * 0.4, 1.0), 0.5, M.TRIM))
				for k in 4: P.append(ell(Vector3(bx + 1.2, -4.5 + k * 3.0, bz + bh + s.ch + 0.8), Vector3(0.8, 1.2, 1.2), M.LIGHT))
			if s.get("flaps", false):
				for side in [-1.0, 1.0]: P.append(rbox(Vector3(-s.ax - 5.5, side * (W * 0.5 - 1), 3.5), Vector3(0.5, 2.0, 2.5), 0.2, M.RED))
			_wheels(P, s.ax, s.wf, s.wr, W * 0.5 - 1.0, 2.6)
		"formula":
			P.append(cap(Vector3(-11, 0, 5), Vector3(14, 0, 4), 3.8, M.BODY))                         # tub + nose
			P.append(ell(Vector3(-2, 0, 5), Vector3(8, 7, 3.5), M.BODY))                               # sidepods
			P.append(rbox(Vector3(15, 0, 2.5), Vector3(1.8, 10, 0.8), 0.4, M.ACCENT))                   # front wing
			P.append(rbox(Vector3(-14, 0, 12), Vector3(2.5, 9, 1.2), 0.5, M.ACCENT))                    # rear wing
			for side in [-1.0, 1.0]: P.append(rbox(Vector3(-14, side * 8.5, 9), Vector3(2.5, 0.6, 3.5), 0.3, M.TRIM))
			P.append(ell(Vector3(1, 0, 10), Vector3(3.6, 3.6, 3.6), M.HELMET))
			P.append(ell(Vector3(3.5, 0, 10.5), Vector3(1.2, 2.6, 1.3), M.GLASS))
			P.append(ell(Vector3(-5, 0, 10), Vector3(3, 2.5, 3), M.BODY))                               # airbox
			_wheels(P, s.ax, s.wf, s.wr, 9.0, 3.0)
		"kart":
			P.append(rbox(Vector3(0, 0, 3), Vector3(9, 6, 1.0), 0.6, M.TRIM))
			P.append(rbox(Vector3(9, 0, 4), Vector3(1.5, 6, 2), 1.0, M.BODY))                           # nose fairing
			P.append(ell(Vector3(-1, 0, 7), Vector3(3.5, 4.5, 4), M.SUIT))
			P.append(ell(Vector3(0, 0, 12.5), Vector3(4.5, 4.5, 4.5), M.HELMET))                        # big SD head
			P.append(ell(Vector3(3.2, 0, 13), Vector3(1.2, 3.0, 1.5), M.GLASS))
			_wheels(P, s.ax, s.wf, s.wr, 8.0, 2.0)
		"buggy":
			P.append(rbox(Vector3(0, 0, 7), Vector3(10, 7, 2.5), 2.0, M.BODY))
			for side in [-1.0, 1.0]:
				P.append(cap(Vector3(6, side * 6, 8), Vector3(1, side * 5, 17), 0.9, M.METAL))
				P.append(cap(Vector3(-7, side * 6, 8), Vector3(-3, side * 5, 17), 0.9, M.METAL))
			P.append(cap(Vector3(1, -5, 17), Vector3(1, 5, 17), 0.9, M.METAL))
			P.append(cap(Vector3(-3, -5, 17), Vector3(-3, 5, 17), 0.9, M.METAL))
			P.append(ell(Vector3(-1, 0, 13), Vector3(3.5, 3.5, 3.5), M.HELMET))
			P.append(ell(Vector3(1.5, 0, 13.5), Vector3(1.2, 2.6, 1.4), M.GLASS))
			if s.get("topwing", false): P.append(rbox(Vector3(-2, 0, 20), Vector3(9, 8, 0.8), 0.4, M.BODY))
			for side in [-1.0, 1.0]: P.append(ell(Vector3(10.5, side * 4, 8), Vector3(1.2, 1.8, 1.8), M.LIGHT))
			_wheels(P, s.ax, s.wf, s.wr, s.W * 0.5, 3.0)
		"bike":
			var dirt: bool = s.get("dirt", false)
			var wf: float = s.get("wf", 5.0); var wr: float = s.get("wr", 6.0)
			var ax := 9.0
			for w in [[ax, wf], [-ax, wr]]:
				P.append(cyl(Vector3(w[0], 0, w[1]), w[1], 2.0 if not dirt else 1.6, M.TIRE, 1.2))
				P.append(cyl(Vector3(w[0], 0, w[1]), w[1] * 0.45, 2.2, M.METAL, 0.5))
			var seat := wr + (5.0 if dirt else 3.5)
			P.append(ell(Vector3(-1, 0, seat), Vector3(6.5, 2.6, 2.6), M.TRIM))                           # frame / seat
			P.append(ell(Vector3(3, 0, seat + 1.5), Vector3(4.5, 3.2, 2.8), M.BODY))                        # tank
			P.append(rbox(Vector3(-1, 0, wr + 0.5), Vector3(3.5, 2.6, 3), 1.2, M.METAL))                    # engine
			P.append(cap(Vector3(-4, 2.6, wr), Vector3(-12, 2.8, wr + 2), 1.1, M.METAL))                    # exhaust
			P.append(cap(Vector3(ax, 0, wf), Vector3(ax - 3, 0, seat + 4), 0.9, M.METAL))                  # fork
			P.append(cap(Vector3(ax - 3.5, -4, seat + 4.5), Vector3(ax - 3.5, 4, seat + 4.5), 0.7, M.TRIM)) # bars
			P.append(ell(Vector3(ax - 1.5, 0, seat + 2.5), Vector3(1.2, 1.6, 1.6), M.LIGHT))
			P.append(ell(Vector3(-ax + 1, 0, seat + 1), Vector3(1.0, 1.4, 1.0), M.RED))
			if s.get("fairing", false):
				P.append(ell(Vector3(ax - 3, 0, seat + 2), Vector3(4, 3.6, 4.5), M.BODY))
				P.append(ell(Vector3(ax - 3.5, 0, seat + 6), Vector3(2, 2.6, 1.8), M.GLASS))
				P.append(ell(Vector3(-6, 0, seat + 1), Vector3(3.5, 2.6, 2), M.BODY))
			if s.get("cafe", false):
				P.append(ell(Vector3(-5, 0, seat + 1.5), Vector3(3, 2.4, 1.8), M.BODY))
			if dirt:
				P.append(rbox(Vector3(ax, 0, wf * 2 + 1.5), Vector3(4, 1.6, 0.6), 0.4, M.BODY))              # high fender
				P.append(rbox(Vector3(ax - 2, 0, seat + 3.5), Vector3(0.8, 3, 3), 0.6, M.PLATE))            # number plate
				P.append(rbox(Vector3(-ax + 1, 0, seat + 1), Vector3(4, 1.4, 0.6), 0.4, M.BODY))            # rear fender
			if s.get("scooter", false):
				P.append(rbox(Vector3(0, 0, wr + 1), Vector3(7, 3, 3), 2.0, M.BODY))
			# rider: chibi proportions (big helmet)
			var up: bool = s.get("upright", false)
			var hip := Vector3(-2, 0, seat + 2.5)
			var chest := hip + (Vector3(3, 0, 6.5) if up else Vector3(6, 0, 4.0))
			P.append(ell(hip, Vector3(3, 3.4, 2.4), M.SUIT))
			P.append(cap(hip, chest, 3.0, M.SUIT))
			for side in [-1.0, 1.0]:
				P.append(cap(chest + Vector3(0, side * 2.8, 0), Vector3(ax - 3.5, side * 3.6, seat + 4.8), 1.1, M.SUIT))   # arms
				P.append(cap(hip + Vector3(1, side * 2.6, 0), Vector3(1.5, side * 3.4, wr + 1.5), 1.3, M.TRIM))          # legs
			var head := chest + (Vector3(0.5, 0, 5.5) if up else Vector3(2.5, 0, 4.5))
			P.append(ell(head, Vector3(4.2, 4.0, 4.2), M.HELMET))
			P.append(ell(head + Vector3(2.8, 0, 0.3), Vector3(1.6, 3.0, 1.6), M.GLASS))
			P.append(ell(head + Vector3(0, 0, 3.2), Vector3(3.5, 1.0, 1.4), M.SUIT, true))               # helmet stripe
			if s.get("sidecar", false):
				P.append(ell(Vector3(0, 9, 6), Vector3(7, 3.5, 3.5), M.BODY))
				P.append(cyl(Vector3(0, 11, 4), 4, 1.5, M.TIRE, 1.0))
				P.append(ell(Vector3(-1, 9, 10), Vector3(3, 3, 3), M.HELMET))
	return voxelize(P)

## Trackside props in the same smooth pre-rendered style.
static func prop(name: String) -> Dictionary:
	var P := []
	match name:
		"pine", "snowpine":
			P.append(rbox(Vector3(0, 0, 3), Vector3(1.6, 1.6, 4), 0.6, M.TRUNK))
			for i in 4:
				var r := 9.0 - i * 2.0
				P.append(ell(Vector3(0, 0, 9 + i * 6.0), Vector3(r, r, 4.2), M.DARKLEAF if i % 2 == 0 else M.LEAF))
				if name == "snowpine": P.append(ell(Vector3(0, 0, 11 + i * 6.0), Vector3(r * 0.8, r * 0.8, 2.6), M.SNOW, true))
		"oak":
			P.append(rbox(Vector3(0, 0, 5), Vector3(2, 2, 5), 0.8, M.TRUNK))
			P.append(ell(Vector3(0, 0, 17), Vector3(10, 10, 8), M.LEAF))
			P.append(ell(Vector3(-4, -3, 21), Vector3(6, 6, 5), M.LEAF))
			P.append(ell(Vector3(4, 3, 14), Vector3(6, 6, 5), M.DARKLEAF))
		"palm":
			P.append(cap(Vector3(0, 0, 0), Vector3(3, 0, 22), 1.6, M.TRUNK))
			for a in 6:
				var d := Vector2.from_angle(a * TAU / 6.0)
				P.append(cap(Vector3(3, 0, 23), Vector3(3 + d.x * 10, d.y * 10, 18), 1.5, M.LEAF))
		"cactus":
			P.append(cap(Vector3(0, 0, 0), Vector3(0, 0, 20), 3.0, M.CACTUS))
			P.append(cap(Vector3(0, 0, 9), Vector3(-6, 0, 9), 2.0, M.CACTUS)); P.append(cap(Vector3(-6, 0, 9), Vector3(-6, 0, 15), 2.0, M.CACTUS))
			P.append(cap(Vector3(0, 0, 6), Vector3(5, 0, 6), 2.0, M.CACTUS)); P.append(cap(Vector3(5, 0, 6), Vector3(5, 0, 12), 2.0, M.CACTUS))
		"rock":
			P.append(ell(Vector3(0, 0, 4), Vector3(9, 7, 6), M.ROCK))
			P.append(ell(Vector3(4, 3, 7), Vector3(5, 5, 5), M.ROCK))
		"tires":
			for i in 3:
				P.append(cylz(Vector3(0, 0, 2 + i * 3.6), 6.0, 1.8, M.TIRE if i != 1 else M.WHITE, 1.2))
		"hay":
			P.append(cyl(Vector3(0, 0, 6), 6.0, 6.0, M.HAY, 1.5))
		"marker":
			P.append(rbox(Vector3(0, 0, 7), Vector3(1.2, 1.2, 7), 0.5, M.WHITE))
			P.append(rbox(Vector3(0, 0, 11), Vector3(1.3, 1.3, 1.5), 0.3, M.RED, true))
	return voxelize(P)

## Rear-axle position, for the coin-wheelie pivot.
static func rear_axle(kind: String) -> Vector2:
	var s := spec(kind)
	return Vector2(-float(s.get("ax", 9.0)), float(s.get("wr", 6.0)))
