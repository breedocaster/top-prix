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
		M.ACCENT: return Color("#f4f1e8") if team.get_luminance() < 0.6 else Color("#2a2a3a")
		M.GLASS: return Color("#3d5f86")
		M.TIRE: return Color("#2a2a30")
		M.METAL: return Color("#9aa2ad")
		M.HELMET: return Color("#f2f0ea")
		M.PLATE: return Color("#f8f4e8")
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

# ---------------- super-deformed vehicles (Penny Racers style) ----------------
const VCELL := Vector2i(48, 48)
const WORLD_PER_PX := 0.5       # sprite px -> world px (a car fills ~3/4 of a 26 px lane)
const LEVELS := 8                # 0..5 lit ramp, 6 = specular glint, 7 spare
const GLOSSY := [M.BODY, M.ACCENT, M.GLASS, M.HELMET, M.LIGHT, M.METAL, M.RED, M.PLATE]
const KINDS := ["hatch", "sedan", "kart", "roadster", "coupe", "gt", "super", "formula", "proto", "pickup", "truck", "rally",
	"buggy", "sprint", "scooter", "commuter", "naked", "cafe", "sport", "gp", "sidecar", "trail", "mx", "enduro", "flat", "smoto", "raid"]
const BAYER := [0.0, 0.5, 0.75, 0.25]

## 7-step glossy ramp: deep hue-shifted shadows up to a near-white glint.
static func ramp7(c: Color) -> Array:
	return [snes(c.darkened(0.66).lerp(Color("#1c0e3c"), 0.3)), snes(c.darkened(0.46).lerp(Color("#24124a"), 0.18)),
		snes(c.darkened(0.24).lerp(Color("#2a1850"), 0.06)), snes(c), snes(c.lightened(0.22).lerp(Color("#fff2b8"), 0.06)),
		snes(c.lightened(0.42).lerp(Color("#fff2b8"), 0.12)), snes(Color("#ffffff").lerp(c, 0.12)), snes(c)]

## Index sheet: 16 yaw frames x 2 poses (row 0 normal, row 1 coin-wheelie). R = material*10, G = level*30.
static func render_sd(vox: Dictionary, pivot: Vector2, frames: int = FRAMES, cell: Vector2i = VCELL, poses: int = 2, pitch: float = PITCH) -> Image:
	var img := Image.create(cell.x * frames, cell.y * poses, false, Image.FORMAT_RGBA8)
	var cp := cos(pitch); var sp := sin(pitch)
	var view := Vector3(cp, 0, -sp)
	var light := Vector3(-0.45, -0.55, 0.75).normalized()
	var half := (light - view).normalized()
	var ox := cell.x / 2.0
	var oy := cell.y - 5.0
	for pose in poses:
		var wa := 0.0 if pose == 0 else 0.28
		var ca := cos(wa); var sa := sin(wa)
		for f in frames:
			var yaw := f * TAU / frames
			var cy := cos(yaw); var sy := sin(yaw)
			var zb := PackedFloat32Array(); zb.resize(cell.x * cell.y); zb.fill(1e9)
			var x_off := f * cell.x
			var y_off := pose * cell.y
			for v in vox:
				var m: int = vox[v][0]
				var n: Vector3 = vox[v][1]
				var p := Vector3(v) + Vector3(0.5, 0.5, 0.5)
				if pose == 1:
					var dx := p.x - pivot.x; var dz := p.z - pivot.y
					p = Vector3(pivot.x + dx * ca - dz * sa, p.y, pivot.y + dx * sa + dz * ca)
					n = Vector3(n.x * ca - n.z * sa, n.y, n.x * sa + n.z * ca)
				var nr := Vector3(n.x * cy - n.y * sy, n.x * sy + n.y * cy, n.z)
				if nr.dot(view) > 0.15: continue
				var r := Vector3(p.x * cy - p.y * sy, p.x * sy + p.y * cy, p.z)
				var sx := ox + r.y
				var syy := oy - (r.x * sp + r.z * cp)
				var depth := r.x * cp - r.z * sp
				var lit := 0.28 + 0.78 * maxf(0.0, nr.dot(light)) - 0.12 * maxf(0.0, -nr.z)
				var x0 := int(floor(sx - 0.5)); var y0 := int(floor(syy - 0.5))
				for yy in range(y0, y0 + 2):
					if yy < 0 or yy >= cell.y: continue
					for xx in range(x0, x0 + 2):
						if xx < 0 or xx >= cell.x: continue
						var zi := yy * cell.x + xx
						if depth >= zb[zi]: continue
						zb[zi] = depth
						var lv := clampi(int(floor(lit * 5.0 + BAYER[(yy % 2) * 2 + (xx % 2)] * 0.4 + 0.2)), 0, 5)
						if m in GLOSSY and nr.dot(half) > 0.95: lv = 6
						img.set_pixel(x_off + xx, y_off + yy, Color8(m * 10, lv * 30, 0, 255))
			# 1px dark outline around the silhouette
			var solid := PackedByteArray(); solid.resize(cell.x * cell.y)
			for yy in cell.y:
				for xx in cell.x:
					solid[yy * cell.x + xx] = 1 if img.get_pixel(x_off + xx, y_off + yy).a > 0.5 else 0
			for yy in cell.y:
				for xx in cell.x:
					if solid[yy * cell.x + xx]: continue
					if (xx > 0 and solid[yy * cell.x + xx - 1]) or (xx < cell.x - 1 and solid[yy * cell.x + xx + 1]) \
							or (yy > 0 and solid[(yy - 1) * cell.x + xx]) or (yy < cell.y - 1 and solid[(yy + 1) * cell.x + xx]):
						img.set_pixel(x_off + xx, y_off + yy, Color8(0, 0, 0, 255))
	return img

static func bake_vehicle(kind: String) -> Image:
	return render_sd(SDModels.build(kind), SDModels.rear_axle(kind))

static func vehicle_path(kind: String) -> String:
	return "res://art/vehicles/%s.png" % kind

## Index sheet as a texture: the baked PNG if present, otherwise rendered now (slow; bake with --test=bake).
static func vehicle_tex(kind: String) -> Texture2D:
	var key := "veh:" + kind
	if _tex_cache.has(key): return _tex_cache[key]
	var t: Texture2D
	if ResourceLoader.exists(vehicle_path(kind)):
		t = load(vehicle_path(kind))
	else:
		t = ImageTexture.create_from_image(bake_vehicle(kind))
	_tex_cache[key] = t
	return t

## Palette LUT: row per team colour, column = material * LEVELS + level. Pass row via draw modulate
## Color(0, 1, 0, (row + 128) / 255) and the palette shader swaps colours on the GPU.
static func palette(team_cols: Array) -> ImageTexture:
	var mats := M.size()
	var img := Image.create(mats * LEVELS, max(1, team_cols.size()), false, Image.FORMAT_RGBA8)
	var outline := snes(Color("#140c24"))
	for row in team_cols.size():
		var tc: Color = team_cols[row]
		for m in mats:
			var rp: Array = ramp7(mat_color(m, tc)) if m != 0 else []
			for l in LEVELS:
				img.set_pixel(m * LEVELS + l, row, outline if m == 0 else rp[min(l, 7)])
	return ImageTexture.create_from_image(img)

static func row_color(row: int) -> Color:
	return Color(0, 1, 0, (row + 128) / 255.0)

## CPU palette swap (previews / tests).
static func colorize_sd(idx: Image, team: Color) -> Image:
	var out := Image.create(idx.get_width(), idx.get_height(), false, Image.FORMAT_RGBA8)
	var ramps := {}
	var outline := snes(Color("#140c24"))
	for y in idx.get_height():
		for x in idx.get_width():
			var p := idx.get_pixel(x, y)
			if p.a < 0.5: continue
			var m := int(round(p.r8 / 10.0))
			if m == 0: out.set_pixel(x, y, outline); continue
			if not ramps.has(m): ramps[m] = ramp7(mat_color(m, team))
			out.set_pixel(x, y, ramps[m][clampi(int(round(p.g8 / 30.0)), 0, 7)])
	return out

static func prop_texture(name: String) -> ImageTexture:
	var key := "prop:" + name
	if not _tex_cache.has(key):
		var path := "res://art/props/%s.png" % name
		var idx: Image
		if ResourceLoader.exists(path): idx = load(path).get_image()
		else: idx = bake_prop(name)
		_tex_cache[key] = ImageTexture.create_from_image(colorize_sd(idx, Color.WHITE))
	return _tex_cache[key]

const PROPS := ["pine", "snowpine", "oak", "palm", "cactus", "rock", "tires", "hay", "marker"]
const PCELL := Vector2i(40, 52)

static func bake_prop(name: String) -> Image:
	return render_sd(SDModels.prop(name), Vector2.ZERO, 1, PCELL, 1, 0.3)

## 3x5 pixel text straight into an Image (MiniFont glyphs), for trackside boards and banners.
static func img_text(img: Image, text: String, x: int, y: int, col: Color, s := 1) -> void:
	var MF = load("res://scripts/ui/career/mini_font.gd")
	var cx := x
	for ch in text.to_upper():
		var g: String = MF.GLYPHS.get(ch, MF.GLYPHS[" "])
		for i in 15:
			if g[i] == "1":
				var px := cx + (i % 3) * s
				var py := y + (i / 3) * s
				img.fill_rect(Rect2i(px, py, s, s), col)
		cx += (2 if ch in MF.NARROW else 4) * s

static func text_w(text: String, s := 1) -> int:
	var MF = load("res://scripts/ui/career/mini_font.gd")
	var w := 0
	for ch in text: w += (2 if ch in MF.NARROW else 4) * s
	return w

## Trackside advertising board (a fictional sponsor from the game's sponsor list).
static func board_texture(text: String, bg: Color, fg: Color) -> ImageTexture:
	var key := "board:%s:%s" % [text, bg.to_html(false)]
	if _tex_cache.has(key): return _tex_cache[key]
	var tw := text_w(text)
	var img := Image.create(tw + 6, 12, false, Image.FORMAT_RGBA8)
	var post := snes(Color("#3a3f4a"))
	img.fill_rect(Rect2i(0, 0, tw + 6, 9), snes(bg.darkened(0.45)))
	img.fill_rect(Rect2i(1, 1, tw + 4, 7), snes(bg))
	img.fill_rect(Rect2i(1, 1, tw + 4, 1), snes(bg.lightened(0.3)))
	img_text(img, text, 3, 2, snes(fg))
	img.fill_rect(Rect2i(2, 9, 2, 3), post); img.fill_rect(Rect2i(tw + 2, 9, 2, 3), post)
	_tex_cache[key] = ImageTexture.create_from_image(img)
	return _tex_cache[key]

## Start / finish gantry banner (the lamps are drawn live over it by SpriteLayer).
static func banner_texture(text: String) -> ImageTexture:
	var key := "banner:" + text
	if _tex_cache.has(key): return _tex_cache[key]
	var w := 72
	var img := Image.create(w, 16, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, w, 16), snes(Color("#141a3a")))
	for x in range(0, w, 2):
		for y in [1, 14]:
			img.set_pixel(x + (0 if y == 1 else 1), y, snes(Color("#f2f2ee")))
			img.set_pixel(x + (1 if y == 1 else 0), y, snes(Color("#1a1a20")))
	img.fill_rect(Rect2i(0, 2, w, 1), snes(Color("#ffd84a")))
	img.fill_rect(Rect2i(0, 13, w, 1), snes(Color("#ffd84a")))
	var tw := text_w(text, 2)
	img_text(img, text, (w - tw) / 2, 3, snes(Color("#ffffff")), 2)
	_tex_cache[key] = ImageTexture.create_from_image(img)
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
