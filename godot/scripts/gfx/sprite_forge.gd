class_name SpriteForge
extends RefCounted
## Pre-rendered "16-bit" sprites, made the way SNES-era studios faked 3D: small voxel models are
## rendered offline (here: at runtime, once) from 16 yaw angles with a fixed light, quantized to a
## 4-shade ramp + dark outline, then palette-swapped per team. Output colors are snapped to
## the SNES 15-bit color space (5 bits per channel).

const FRAMES := 16
const CELL := Vector2i(44, 36)
const PITCH := 0.42   # camera looks down ~24 degrees, like a Mode 7 chase cam

# material ids (stored in the red channel of index sheets)
enum M { NONE, BODY, ACCENT, GLASS, TIRE, METAL, SUIT, HELMET, PLATE, LIGHT, TRIM,
	LEAF, TRUNK, ROCK, CACTUS, SNOW, HAY, RED, WHITE, SAND, DARKLEAF, YELLOW }

static var _idx_cache := {}
static var _tex_cache := {}

# ---------------- palette ----------------
static func snes(c: Color) -> Color:
	return Color(round(c.r * 31.0) / 31.0, round(c.g * 31.0) / 31.0, round(c.b * 31.0) / 31.0, c.a)

## 4-step ramp with hue shifting (shadows lean violet, highlights lean warm).
static func ramp(c: Color) -> Array:
	var dark := c.darkened(0.58).lerp(Color("#24124a"), 0.22)
	var mid := c.darkened(0.28).lerp(Color("#2a1850"), 0.08)
	var lite := c.lightened(0.32).lerp(Color("#fff2b8"), 0.12)
	return [snes(dark), snes(mid), snes(c), snes(lite)]

static func mat_color(m: int, team: Color) -> Color:
	match m:
		M.BODY, M.SUIT: return team
		M.ACCENT: return Color("#f4f1e8")
		M.GLASS: return Color("#3d5f86")
		M.TIRE: return Color("#2a2a30")
		M.METAL: return Color("#9aa2ad")
		M.HELMET: return Color("#f2f0ea")
		M.PLATE: return Color("#f0e8c8")
		M.LIGHT: return Color("#ffd84a")
		M.TRIM: return Color("#3a3c46")
		M.LEAF: return Color("#3f9a3a")
		M.DARKLEAF: return Color("#2f6f44")
		M.TRUNK: return Color("#7a4a26")
		M.ROCK: return Color("#8a8476")
		M.CACTUS: return Color("#4f9a4a")
		M.SNOW: return Color("#eef4fa")
		M.HAY: return Color("#e0b450")
		M.RED: return Color("#d8402e")
		M.WHITE: return Color("#f2f2ee")
		M.SAND: return Color("#d9b45c")
		M.YELLOW: return Color("#f2c21e")
	return Color.MAGENTA

# ---------------- voxel models ----------------
## Car/bike archetype for a body kind.
static func spec_for(kind: String) -> Dictionary:
	match kind:
		"hatch": return {"t": "car", "L": 22, "W": 13, "hb": 5, "gc": 2, "cab": [3, 15, 5, 2], "r": 3, "hatch": true}
		"sedan": return {"t": "car", "L": 26, "W": 13, "hb": 5, "gc": 2, "cab": [6, 17, 5, 2], "r": 3}
		"roadster": return {"t": "car", "L": 23, "W": 13, "hb": 4, "gc": 2, "cab": [9, 15, 0, 2], "r": 3, "open": true}
		"coupe": return {"t": "car", "L": 25, "W": 14, "hb": 4, "gc": 2, "cab": [6, 15, 4, 2], "r": 3, "spoiler": true}
		"gt", "super": return {"t": "car", "L": 27, "W": 15, "hb": 4, "gc": 1, "cab": [9, 17, 4, 2], "r": 3, "spoiler": true, "stripe": true}
		"formula": return {"t": "formula", "L": 28, "W": 15, "r": 3}
		"kart": return {"t": "kart", "L": 15, "W": 11, "r": 2}
		"proto": return {"t": "car", "L": 28, "W": 15, "hb": 4, "gc": 1, "cab": [10, 18, 3, 3], "r": 3, "fin": true, "spoiler": true}
		"pickup": return {"t": "car", "L": 26, "W": 14, "hb": 6, "gc": 4, "cab": [10, 18, 5, 2], "r": 4, "bed": true}
		"truck": return {"t": "car", "L": 28, "W": 15, "hb": 7, "gc": 5, "cab": [12, 21, 5, 2], "r": 5, "bed": true, "bar": true}
		"rally": return {"t": "car", "L": 23, "W": 13, "hb": 5, "gc": 3, "cab": [5, 16, 5, 2], "r": 3, "spoiler": true, "bar": true, "stripe": true}
		"buggy": return {"t": "buggy", "L": 22, "W": 14, "r": 4}
		"sprint": return {"t": "buggy", "L": 20, "W": 12, "r": 4, "topwing": true}
		"sidecar": return {"t": "bike", "L": 20, "r": 4, "fairing": true, "sidecar": true}
		"scooter": return {"t": "bike", "L": 16, "r": 3, "upright": true, "scooter": true}
		"commuter", "cafe", "naked": return {"t": "bike", "L": 19, "r": 4, "upright": kind != "cafe"}
		"sport", "gp": return {"t": "bike", "L": 20, "r": 4, "fairing": true}
		"trail", "mx", "enduro", "raid", "smoto", "flat": return {"t": "bike", "L": 20, "r": 5, "dirt": true, "upright": kind == "trail" or kind == "raid"}
	return {"t": "car", "L": 24, "W": 13, "hb": 5, "gc": 2, "cab": [5, 15, 5, 2], "r": 3}

static func _box(v: Dictionary, x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, m: int) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				v[Vector3i(x, y, z)] = m

## wheel: axis along y, centered at (cx, *, cz)
static func _wheel(v: Dictionary, cx: int, cz: int, r: int, y0: int, y1: int) -> void:
	for x in range(cx - r, cx + r + 1):
		for z in range(cz - r, cz + r + 1):
			var d := Vector2(x - cx, z - cz).length()
			if d <= r + 0.3:
				for y in range(y0, y1):
					v[Vector3i(x, y, z)] = M.METAL if d < r * 0.45 else M.TIRE

## Model space: x forward, y right, z up. Origin roughly at the rear-left-bottom; recentered on render.
static func build(spec: Dictionary) -> Dictionary:
	var v := {}
	var L: int = spec.L
	match spec.t:
		"car":
			var W: int = spec.W; var hb: int = spec.hb; var gc: int = spec.gc; var r: int = spec.r
			_box(v, 0, L, 1, W - 1, gc, gc + hb, M.BODY)
			_box(v, 1, L - 1, 0, W, gc + 1, gc + hb - 1, M.BODY)          # fender flares
			var cab: Array = spec.cab
			if spec.get("open", false):
				_box(v, cab[0], cab[1], 3, W - 3, gc + hb, gc + hb + 1, M.TRIM)
				_box(v, cab[1] - 1, cab[1], 2, W - 2, gc + hb, gc + hb + 2, M.GLASS)
			else:
				var inset: int = cab[3]
				_box(v, cab[0], cab[1], inset, W - inset, gc + hb, gc + hb + cab[2], M.GLASS)
				_box(v, cab[0] + 1, cab[1] - 1, inset, W - inset, gc + hb + cab[2] - 1, gc + hb + cab[2], M.BODY)  # roof
				_box(v, cab[0] + 2, cab[1] - 2, inset + 1, W - inset - 1, gc + hb, gc + hb + cab[2] - 1, M.TRIM)   # pillars/interior
			if spec.get("stripe", false):
				_box(v, 0, L, W / 2 - 1, W / 2 + 1, gc + hb - 1, gc + hb, M.ACCENT)
			if spec.get("spoiler", false):
				_box(v, 0, 2, 1, W - 1, gc + hb + 2, gc + hb + 3, M.TRIM)
				_box(v, 1, 2, 2, 3, gc + hb, gc + hb + 2, M.TRIM); _box(v, 1, 2, W - 3, W - 2, gc + hb, gc + hb + 2, M.TRIM)
			if spec.get("fin", false):
				_box(v, 0, cab[0], W / 2, W / 2 + 1, gc + hb, gc + hb + 3, M.BODY)
			if spec.get("bed", false):
				_box(v, 1, cab[0] - 1, 2, W - 2, gc + hb - 1, gc + hb, M.TRIM)
			if spec.get("bar", false):
				_box(v, cab[0] + 3, cab[0] + 5, inset_or(spec), W - inset_or(spec), gc + hb + cab[2], gc + hb + cab[2] + 1, M.LIGHT)
			_box(v, 0, 1, 1, 3, gc + 2, gc + 3, M.RED); _box(v, 0, 1, W - 3, W - 1, gc + 2, gc + 3, M.RED)   # tail lights
			_box(v, L - 1, L, 1, 3, gc + 2, gc + 3, M.LIGHT); _box(v, L - 1, L, W - 3, W - 1, gc + 2, gc + 3, M.LIGHT)
			_wheel(v, 4, r, r, -1, 2); _wheel(v, 4, r, r, W - 2, W + 1)
			_wheel(v, L - 5, r, r, -1, 2); _wheel(v, L - 5, r, r, W - 2, W + 1)
		"formula":
			var W: int = spec.W; var r: int = spec.r
			_box(v, 3, L - 2, W / 2 - 2, W / 2 + 2, 1, 4, M.BODY)                # tub
			_box(v, 6, 14, W / 2 - 3, W / 2 + 3, 1, 4, M.BODY)                   # sidepods
			_box(v, L - 3, L, 1, W - 1, 1, 2, M.ACCENT)                          # front wing
			_box(v, 0, 2, 1, W - 1, 6, 7, M.BODY)                                # rear wing
			_box(v, 1, 2, W / 2 - 1, W / 2 + 1, 3, 6, M.TRIM)
			_box(v, 11, 14, W / 2 - 1, W / 2 + 1, 4, 6, M.HELMET)                # driver
			_wheel(v, 4, r, r + 1, -1, 3); _wheel(v, 4, r, r + 1, W - 3, W + 1)
			_wheel(v, L - 6, r, r, 0, 2); _wheel(v, L - 6, r, r, W - 2, W)
		"kart":
			var W: int = spec.W
			_box(v, 1, L - 1, 2, W - 2, 1, 2, M.TRIM)
			_box(v, L - 3, L, 2, W - 2, 1, 3, M.BODY)
			_box(v, 4, 8, W / 2 - 2, W / 2 + 2, 2, 5, M.SUIT)
			_box(v, 5, 7, W / 2 - 1, W / 2 + 1, 5, 7, M.HELMET)
			_wheel(v, 3, 2, 2, 0, 2); _wheel(v, 3, 2, 2, W - 2, W)
			_wheel(v, L - 4, 2, 2, 0, 2); _wheel(v, L - 4, 2, 2, W - 2, W)
		"buggy":
			var W: int = spec.W; var r: int = spec.r
			_box(v, 2, L - 2, 3, W - 3, r, r + 2, M.BODY)
			_box(v, 6, 14, 3, 4, r + 2, r + 7, M.METAL); _box(v, 6, 14, W - 4, W - 3, r + 2, r + 7, M.METAL)  # roll cage
			_box(v, 6, 14, 3, W - 3, r + 7, r + 8, M.METAL)
			_box(v, 8, 11, W / 2 - 1, W / 2 + 1, r + 2, r + 6, M.SUIT)
			if spec.get("topwing", false): _box(v, 4, 14, 1, W - 1, r + 9, r + 10, M.BODY)
			_wheel(v, 4, r, r, 0, 3); _wheel(v, 4, r, r, W - 3, W)
			_wheel(v, L - 4, r, r, 0, 3); _wheel(v, L - 4, r, r, W - 3, W)
		"bike":
			var r: int = spec.r
			var dirt: bool = spec.get("dirt", false)
			var hz := r + (2 if dirt else 0)        # frame / seat base height
			var fx := L - r - 1                      # front axle x
			_wheel(v, r, r, r, 2, 4); _wheel(v, fx, r, r, 2, 4)
			_box(v, r, fx, 2, 4, hz, hz + 2, M.TRIM)                         # frame rails
			_box(v, r + 2, r + 7, 1, 5, r - 1, r + 3, M.METAL)              # engine
			_box(v, r + 4, fx - 2, 1, 5, hz + 1, hz + 4, M.BODY)            # tank
			_box(v, 1, r + 4, 4, 5, r, r + 2, M.METAL)                       # exhaust
			for k in 4:                                                      # fork
				_box(v, fx - k, fx - k + 1, 2, 4, r + k * 2, r + k * 2 + 2, M.METAL)
			_box(v, fx - 3, fx - 2, 0, 6, hz + 5, hz + 6, M.TRIM)            # bars
			_box(v, fx - 1, fx, 2, 4, hz + 3, hz + 4, M.LIGHT)               # headlight
			_box(v, 0, 1, 2, 4, hz + 2, hz + 3, M.RED)                       # tail light
			if spec.get("fairing", false):
				_box(v, fx - 5, fx, 1, 5, hz + 1, hz + 5, M.BODY)
				_box(v, fx - 4, fx - 1, 2, 4, hz + 5, hz + 7, M.GLASS)
				_box(v, r - 1, r + 4, 1, 5, hz + 1, hz + 3, M.BODY)          # tail section
			if dirt:
				_box(v, fx - 2, fx + 3, 2, 4, r * 2 + 1, r * 2 + 2, M.BODY)  # high fender
				_box(v, fx - 2, fx, 1, 5, hz + 3, hz + 6, M.PLATE)           # number plate
				_box(v, r, r + 6, 1, 5, hz + 1, hz + 3, M.BODY)              # side panels
			if spec.get("scooter", false):
				_box(v, r + 1, fx - 1, 1, 5, r - 1, hz + 1, M.BODY)
			# rider
			var crouch: bool = not spec.get("upright", false)
			var sx := r + 2
			_box(v, sx, sx + 4, 1, 5, hz + 2, hz + 4, M.TRIM)                # seat + hips
			_box(v, sx + 1, sx + 3, 0, 1, hz, hz + 3, M.TRIM)                # legs
			_box(v, sx + 1, sx + 3, 5, 6, hz, hz + 3, M.TRIM)
			if crouch:
				_box(v, sx + 2, sx + 7, 1, 5, hz + 4, hz + 7, M.SUIT)        # torso tucked
				_box(v, sx + 6, fx - 2, 0, 1, hz + 5, hz + 6, M.SUIT); _box(v, sx + 6, fx - 2, 5, 6, hz + 5, hz + 6, M.SUIT)
				_box(v, sx + 6, sx + 10, 1, 5, hz + 6, hz + 10, M.HELMET)
				_box(v, sx + 9, sx + 10, 2, 4, hz + 7, hz + 9, M.GLASS)
			else:
				_box(v, sx + 1, sx + 5, 1, 5, hz + 4, hz + 10, M.SUIT)       # torso upright
				_box(v, sx + 4, fx - 2, 0, 1, hz + 6, hz + 7, M.SUIT); _box(v, sx + 4, fx - 2, 5, 6, hz + 6, hz + 7, M.SUIT)
				_box(v, sx + 1, sx + 5, 1, 5, hz + 10, hz + 14, M.HELMET)
				_box(v, sx + 4, sx + 5, 2, 4, hz + 11, hz + 13, M.GLASS)
			if spec.get("sidecar", false):
				_box(v, r + 2, fx - 2, 6, 11, r - 1, r + 3, M.BODY)
				_wheel(v, L / 2, r - 1, r - 1, 9, 11)
	return v

static func inset_or(spec: Dictionary) -> int:
	return int(spec.cab[3]) if spec.has("cab") else 2

# ---------------- props (billboards) ----------------
static func prop_model(name: String) -> Dictionary:
	var v := {}
	match name:
		"pine", "snowpine":
			_box(v, 4, 6, 4, 6, 0, 4, M.TRUNK)
			for i in 6:
				var rr := 5 - i * 0.8
				for x in range(-5, 6):
					for y in range(-5, 6):
						if Vector2(x, y).length() <= rr:
							var m := M.SNOW if (name == "snowpine" and (i % 2 == 1 or i == 5)) else (M.DARKLEAF if i % 2 == 0 else M.LEAF)
							v[Vector3i(x + 5, y + 5, 4 + i * 3)] = m
							v[Vector3i(x + 5, y + 5, 5 + i * 3)] = m
							if i < 5: v[Vector3i(x + 5, y + 5, 6 + i * 3)] = m
		"oak":
			_box(v, 5, 7, 5, 7, 0, 7, M.TRUNK)
			for x in range(-6, 7):
				for y in range(-6, 7):
					for z in range(-5, 6):
						if Vector3(x, y, z * 1.2).length() <= 6.2:
							v[Vector3i(x + 6, y + 6, z + 13)] = M.LEAF if (x + y + z) % 3 != 0 else M.DARKLEAF
		"palm":
			for z in 16: v[Vector3i(4 + int(z / 6.0), 4, z)] = M.TRUNK
			for a in 6:
				var dir := Vector2.from_angle(a * TAU / 6.0)
				for s in 7:
					var p := dir * s
					v[Vector3i(6 + int(p.x), 4 + int(p.y), 16 - int(s * s / 9.0))] = M.LEAF
		"cactus":
			_box(v, 2, 4, 2, 4, 0, 12, M.CACTUS)
			_box(v, 0, 2, 2, 4, 5, 7, M.CACTUS); _box(v, 0, 1, 2, 4, 7, 10, M.CACTUS)
			_box(v, 4, 6, 2, 4, 3, 5, M.CACTUS); _box(v, 5, 6, 2, 4, 5, 8, M.CACTUS)
		"rock":
			for x in range(-5, 6):
				for y in range(-4, 5):
					for z in range(0, 6):
						if Vector3(x, y * 1.2, z * 1.4).length() <= 5.2 + sin(x * 1.7 + y) * 0.6:
							v[Vector3i(x + 5, y + 4, z)] = M.ROCK if z < 4 else (M.SNOW if name == "snowrock" else M.ROCK)
		"tires":
			for i in 3:
				for x in range(-3, 4):
					for y in range(-3, 4):
						var d := Vector2(x, y).length()
						if d <= 3.3 and d >= 1.2:
							v[Vector3i(x + 3, y + 3, i * 2)] = M.TIRE
							v[Vector3i(x + 3, y + 3, i * 2 + 1)] = M.WHITE if i == 1 else M.TIRE
		"hay":
			_box(v, 0, 8, 0, 4, 0, 4, M.HAY)
			_box(v, 0, 8, 1, 2, 4, 5, M.HAY)
		"marker":
			_box(v, 0, 1, 0, 1, 0, 6, M.WHITE)
			_box(v, 0, 1, 0, 1, 4, 6, M.RED)
	return v

# ---------------- rendering ----------------
## Faces of a voxel set that touch empty space: [center Vector3, normal Vector3, material].
static func _faces(v: Dictionary) -> Array:
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var mn := Vector3(INF, INF, INF); var mx := -mn
	for p in v:
		mn = mn.min(Vector3(p)); mx = mx.max(Vector3(p))
	var ctr := Vector3((mn.x + mx.x + 1) / 2.0, (mn.y + mx.y + 1) / 2.0, mn.z)
	var out := []
	for p in v:
		for d in dirs:
			if v.has(p + d): continue
			out.append([Vector3(p) + Vector3(0.5, 0.5, 0.5) + Vector3(d) * 0.5 - ctr, Vector3(d), v[p]])
	return out

## Index image: R = material id, G = shade (0..3), A = 1; outline pixels have R = 0.
static func render_index(v: Dictionary, frames: int, cell: Vector2i, pitch: float = PITCH, scale: float = 1.0) -> Image:
	var faces := _faces(v)
	var img := Image.create(cell.x * frames, cell.y, false, Image.FORMAT_RGBA8)
	var cp := cos(pitch); var sp := sin(pitch)
	var light := Vector3(-0.35, -0.5, 0.8).normalized()
	var view := Vector3(cp, 0, -sp)
	var ox := cell.x / 2.0
	var oy := cell.y - 4.0
	for f in frames:
		var yaw := f * TAU / frames
		var cy := cos(yaw); var sy := sin(yaw)
		var zb := PackedFloat32Array(); zb.resize(cell.x * cell.y); zb.fill(1e9)
		for fc in faces:
			var c: Vector3 = fc[0]; var n: Vector3 = fc[1]
			var nr := Vector3(n.x * cy - n.y * sy, n.x * sy + n.y * cy, n.z)
			if nr.dot(view) >= -0.05: continue
			var r := Vector3(c.x * cy - c.y * sy, c.x * sy + c.y * cy, c.z)
			var sx := ox + r.y * scale
			var syy := oy - (r.x * sp + r.z * cp) * scale
			var depth := r.x * cp - r.z * sp
			var lv := nr.dot(light)
			var shade := 3 if lv > 0.55 else 2 if lv > 0.15 else 1 if lv > -0.3 else 0
			var col := Color8(fc[2], shade, 0, 255)
			var x0 := int(floor(sx - 0.5 * scale)); var y0 := int(floor(syy - 0.5 * scale))
			var k := int(ceil(scale)) + 1
			for yy in range(y0, y0 + k):
				if yy < 0 or yy >= cell.y: continue
				for xx in range(x0, x0 + k):
					if xx < 0 or xx >= cell.x: continue
					var zi := yy * cell.x + xx
					if depth < zb[zi]:
						zb[zi] = depth
						img.set_pixel(f * cell.x + xx, yy, col)
		# outline
		var solid := PackedByteArray(); solid.resize(cell.x * cell.y)
		for yy in cell.y:
			for xx in cell.x:
				solid[yy * cell.x + xx] = 1 if img.get_pixel(f * cell.x + xx, yy).a > 0.5 else 0
		for yy in cell.y:
			for xx in cell.x:
				if solid[yy * cell.x + xx]: continue
				var nb := false
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(xx, yy) + o
					if q.x >= 0 and q.y >= 0 and q.x < cell.x and q.y < cell.y and solid[q.y * cell.x + q.x]:
						nb = true; break
				if nb: img.set_pixel(f * cell.x + xx, yy, Color8(0, 0, 0, 255))
	return img

## Palette-swap an index sheet into final colors.
static func colorize(idx: Image, team: Color) -> Image:
	var out := Image.create(idx.get_width(), idx.get_height(), false, Image.FORMAT_RGBA8)
	var ramps := {}
	var outline := snes(Color("#140c24"))
	for y in idx.get_height():
		for x in idx.get_width():
			var p := idx.get_pixel(x, y)
			if p.a < 0.5: continue
			var m := p.r8
			if m == 0:
				out.set_pixel(x, y, outline); continue
			if not ramps.has(m): ramps[m] = ramp(mat_color(m, team))
			out.set_pixel(x, y, ramps[m][clampi(p.g8, 0, 3)])
	return out

static func vehicle_index(kind: String) -> Image:
	if not _idx_cache.has(kind):
		var spec := spec_for(kind)
		var sc := 1.0 if spec.t != "bike" else 1.2
		_idx_cache[kind] = render_index(build(spec), FRAMES, CELL, PITCH, sc)
	return _idx_cache[kind]

## 16-frame horizontal sheet (frame 0 = seen from behind) for a body kind in a team color.
static func vehicle_sheet(kind: String, team: Color) -> ImageTexture:
	var key := kind + team.to_html(false)
	if not _tex_cache.has(key):
		_tex_cache[key] = ImageTexture.create_from_image(colorize(vehicle_index(kind), team))
	return _tex_cache[key]

static func prop_texture(name: String) -> ImageTexture:
	var key := "prop:" + name
	if not _tex_cache.has(key):
		var cell := Vector2i(28, 30) if name != "palm" else Vector2i(30, 30)
		var idx := render_index(prop_model(name), 1, cell, 0.3, 1.0)
		_tex_cache[key] = ImageTexture.create_from_image(colorize(idx, Color.WHITE))
	return _tex_cache[key]

## Small crowd/grandstand billboard drawn directly in pixels.
static func stand_texture(seed: int) -> ImageTexture:
	var key := "stand%d" % seed
	if _tex_cache.has(key): return _tex_cache[key]
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var img := Image.create(48, 26, false, Image.FORMAT_RGBA8)
	var roof := snes(Color("#c8402e")); var frame := snes(Color("#5a5f6e")); var seat := snes(Color("#8a90a0"))
	img.fill_rect(Rect2i(0, 0, 48, 4), roof)
	img.fill_rect(Rect2i(0, 4, 48, 2), snes(Color("#e8e2d0")))
	for row in 5:
		var y := 7 + row * 3
		img.fill_rect(Rect2i(1, y + 2, 46, 1), seat)
		for x in range(2, 46, 2):
			if rng.randf() < 0.85:
				var c := snes(Color.from_hsv(rng.randf(), 0.55, 0.9))
				img.set_pixel(x, y, snes(Color("#f1c9a0")))
				img.set_pixel(x, y + 1, c)
	img.fill_rect(Rect2i(0, 4, 1, 22), frame); img.fill_rect(Rect2i(47, 4, 1, 22), frame)
	img.fill_rect(Rect2i(0, 24, 48, 2), frame)
	_tex_cache[key] = ImageTexture.create_from_image(img)
	return _tex_cache[key]
