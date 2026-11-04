class_name SpriteLayer
extends Node2D
## Scaled billboards on the Mode 7 plane: vehicles (16-angle pre-rendered sheets) and trackside
## props, depth-sorted far to near, like SNES OAM sprites with per-object scaling.

var rv: RaceView
var props := []        # [world Vector2, ImageTexture, scale]
var sheets := {}       # ent idx -> indexed Texture2D (palette-swapped on the GPU)
var shadow := Color(0.05, 0.03, 0.12, 0.45)
var rain := false
var t := 0.0

func _process(d: float) -> void:
	t += d

func place_props(geo: TrackGeo, theme: Dictionary, seed: int, env: String) -> void:
	props.clear()
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var kinds: Array = theme.props
	var n := geo.pts.size()
	var W := geo.width
	var i := 6
	while i < n:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var nrm := Vector2.from_angle(geo.heads[i] + PI / 2.0)
		var d := W * 0.5 + rng.randf_range(24, 80)
		var w := geo.pts[i] + nrm * side * d
		if _clear(geo, w, W * 0.5 + 16):
			var k: String = kinds[rng.randi() % kinds.size()]
			props.append([w, SpriteForge.prop_texture(k), {"pine": 1.4, "snowpine": 1.4, "oak": 1.4, "palm": 1.4, "cactus": 1.7, "rock": 1.2}.get(k, 1.0)])
		i += rng.randi_range(9, 22)
	# grandstands around the start in stadium-like settings
	if env in ["stadium", "night", "rain"] and not geo.tr.drag:
		for g in 4:
			var j := posmod(n - 30 + g * 16, n)
			var nrm2 := Vector2.from_angle(geo.heads[j] + PI / 2.0)
			var w2 := geo.pts[j] - nrm2 * (W * 0.5 + 46)
			if _clear(geo, w2, W * 0.5 + 30): props.append([w2, SpriteForge.stand_texture(seed + g), 2.0])
	if geo.tr.drag:
		props.append([geo.pts[0] + Vector2.from_angle(geo.heads[0] + PI / 2.0) * (W * 0.5 + 10), _tree_light(), 1.4])

func _clear(geo: TrackGeo, w: Vector2, r: float) -> bool:
	var r2 := r * r
	for k in range(0, geo.pts.size(), 3):
		if geo.pts[k].distance_squared_to(w) < r2: return false
	return true

func _tree_light() -> ImageTexture:
	var img := Image.create(8, 30, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(3, 6, 2, 24), Color("#4a4e5a"))
	img.fill_rect(Rect2i(1, 0, 6, 16), Color("#1a1a20"))
	for k in 5:
		img.set_pixel(2, 1 + k * 3, Color("#f2c21e")); img.set_pixel(5, 1 + k * 3, Color("#f2c21e"))
	img.set_pixel(2, 13, Color("#3ad84a")); img.set_pixel(5, 13, Color("#3ad84a"))
	return ImageTexture.create_from_image(img)

func project(w: Vector2) -> Vector3:
	var rel: Vector2 = w - rv.cam_pos
	var fwd := Vector2.from_angle(rv.cam_ang)
	var rgt := Vector2(-fwd.y, fwd.x)
	var z := rel.dot(fwd)
	if z < 44.0: return Vector3(0, 0, -1)
	var x := rel.dot(rgt)
	return Vector3(rv.VIEW.x * 0.5 + x * rv.FOCAL / z, rv.HORIZON + rv.CAM_H * rv.FOCAL / z, z)

func _draw() -> void:
	if rv == null or rv.geo == null: return
	var items := []
	var far: float = rv.FOG_FAR
	for p in props:
		var q := project(p[0])
		if q.z <= 0 or q.z > far: continue
		var s: float = rv.FOCAL / q.z * p[2]
		var tex: ImageTexture = p[1]
		var sz := Vector2(tex.get_width(), tex.get_height()) * s
		if q.x + sz.x * 0.5 < -4 or q.x - sz.x * 0.5 > rv.VIEW.x + 4: continue
		items.append([q.z, tex, Rect2(0, 0, tex.get_width(), tex.get_height()), Rect2(Vector2(q.x - sz.x * 0.5, q.y - sz.y + 2 * s).round(), sz.round()), false, 0.0])
	var cell := Vector2(SpriteForge.VCELL)
	for e in rv.ents:
		if e.get("dnf", false) and not e.get("crash_show", false) and e.get("retired", false): continue
		var smp: Dictionary = rv.geo.sample(e.rprog, e.rlane)
		var q := project(smp.pos)
		if q.z <= 0 or q.z > far: continue
		var s: float = rv.FOCAL / q.z * SpriteForge.WORLD_PER_PX
		var rel := wrapf(smp.ang - rv.cam_ang + e.get("wob", 0.0), -PI, PI)
		var fr := posmod(int(round(rel / (TAU / SpriteForge.FRAMES))), SpriteForge.FRAMES)
		var tex: Texture2D = sheets.get(int(e.idx))
		if tex == null: continue
		var air: float = e.get("air", 0.0)
		var lift := sin(clampf(air, 0, 1) * PI) * 22.0 * s if air > 0 else 0.0
		var bounce := 1.0 if (e.get("crash", 0.0) > 0 and int(t * 20) % 2 == 0) else 0.0
		# Penny Racers coin-wheelie: sparks and drag launches pop the nose up
		var pose := 1 if (e.get("boost", 0.0) > 0 or (rv.tr.drag and rv.race_t < rv.sim_tree() + 0.9 and rv.race_t > 0.0)) else 0
		var sz := cell * s
		var pos := Vector2(q.x - SpriteForge.VCELL.x * 0.5 * s, q.y - (SpriteForge.VCELL.y - 5) * s - lift - bounce * s)
		items.append([q.z - 0.01, tex, Rect2(fr * cell.x, pose * cell.y, cell.x, cell.y), Rect2(pos.round(), sz.round()), true, lift, q, s, e])
	items.sort_custom(func(a, b): return a[0] > b[0])
	for it in items:
		if it[4]:
			var q2: Vector3 = it[6]
			var s2: float = it[7]
			var sw := 28.0 * s2
			draw_rect(Rect2(Vector2(q2.x - sw * 0.5, q2.y - 3.0 * s2).round(), Vector2(sw, max(1.0, 5.0 * s2)).round()), shadow)
			draw_texture_rect_region(it[1], it[3], it[2], SpriteForge.row_color(int(it[8].idx)))
		else:
			draw_texture_rect_region(it[1], it[3], it[2])
		if it[4]:
			var e2: Dictionary = it[8]
			if e2.get("boost", 0.0) > 0 and int(t * 12) % 2 == 0:
				var r: Rect2 = it[3]
				draw_rect(Rect2(r.position.x + r.size.x * 0.35, r.end.y - r.size.y * 0.12, r.size.x * 0.3, max(2.0, r.size.y * 0.08)), Color("#ffd84a"))
			if e2.human and rv.is_mine(e2):
				var r2: Rect2 = it[3]
				var cx := r2.position.x + r2.size.x * 0.5
				draw_rect(Rect2(cx - 2, r2.position.y - 6 - int(t * 4) % 2, 5, 3), Color("#ffffff"))
				draw_rect(Rect2(cx - 1, r2.position.y - 3 - int(t * 4) % 2, 3, 1), Color("#ffffff"))
	if rain:
		for i in 70:
			var rx := fposmod(i * 53.0 + t * 30.0, rv.VIEW.x)
			var ry := fposmod(i * 29.0 + t * 280.0, rv.VIEW.y)
			draw_rect(Rect2(rx, ry, 1, 4), Color(0.8, 0.85, 0.95, 0.45))
