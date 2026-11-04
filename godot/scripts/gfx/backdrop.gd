class_name Backdrop
extends Node2D
## Sky + three parallax strips above the Mode 7 horizon. The strip is 1024 px wide (= one full turn
## at a 90 degree FOV), so the horizon layer turns in lockstep with the floor; far layers lag
## slightly and near layers lead, for that SNES depth feel.

const STRIP := 1024
var view := Vector2(256, 224)
var horizon := 70.0
var theme: Dictionary
var env := "stadium"
var cam_ang := 0.0
var t := 0.0
var layers := []   # [ImageTexture, speed, y]
var night := false
var rain := false
var clouds := []

func setup(env_name: String, horizon_y: float, view_size: Vector2, seed: int) -> void:
	env = env_name
	theme = Env.theme(env_name)
	horizon = horizon_y
	view = view_size
	night = env_name == "night"
	rain = env_name == "rain"
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	layers = [
		[_ridge(rng, 40, 22, 0.012, Color(theme.far), env in ["snow", "mountain"], 0), 0.85, horizon - 40],
		[_ridge(rng, 26, 12, 0.03, Color(theme.mid), false, 1), 1.0, horizon - 26],
		[_near(rng, theme.near), 1.15, horizon - 16],
	]
	clouds.clear()
	for i in 7:
		clouds.append([rng.randf() * STRIP, rng.randf_range(6, horizon - 40), rng.randi_range(14, 34)])

func _ridge(rng: RandomNumberGenerator, h: int, amp: float, freq: float, col: Color, caps: bool, kind: int) -> ImageTexture:
	var img := Image.create(STRIP, h, false, Image.FORMAT_RGBA8)
	var c := SpriteForge.snes(col)
	var shade := SpriteForge.snes(col.darkened(0.18))
	var cap := SpriteForge.snes(Color("#f4f8fc"))
	var ph := rng.randf() * 100.0
	for x in STRIP:
		var a := float(x) / STRIP * TAU
		# periodic noise so the strip wraps seamlessly
		var y := amp * (0.55 + 0.25 * sin(a * 3.0 + ph) + 0.15 * sin(a * 7.0 + ph * 2.0) + 0.1 * sin(a * 17.0 + ph))
		if kind == 1: y = amp * (0.5 + 0.3 * sin(a * 5.0 + ph) + 0.2 * sin(a * 11.0 + ph * 0.5))
		var top := int(h - y - (h - amp) * 0.5)
		for yy in range(max(0, top), h):
			var cc := c if (x / 3 + yy) % 7 != 0 else shade
			if caps and yy < top + 3 and top < h - amp * 0.7: cc = cap
			img.set_pixel(x, yy, cc)
	return ImageTexture.create_from_image(img)

func _near(rng: RandomNumberGenerator, kind: String) -> ImageTexture:
	var h := 16
	var img := Image.create(STRIP, h, false, Image.FORMAT_RGBA8)
	match kind:
		"stands":
			var x := 0
			while x < STRIP:
				var w := rng.randi_range(40, 90)
				var bh := rng.randi_range(8, 15)
				var body := SpriteForge.snes(Color("#8a90a0") if not night else Color("#2a3050"))
				var roof := SpriteForge.snes(Color("#c8402e"))
				for xx in range(x, min(STRIP, x + w)):
					for yy in range(h - bh, h):
						var cc := body
						if yy == h - bh: cc = roof
						elif (xx + yy) % 3 == 0 and yy > h - bh + 1:
							cc = SpriteForge.snes(Color.from_hsv(fmod(xx * 0.137, 1.0), 0.5, 0.9 if not night else 0.5))
						img.set_pixel(xx, yy, cc)
				# light towers
				if rng.randf() < 0.5 and x + w + 3 < STRIP:
					for yy in range(0, h): img.set_pixel(x + w + 1, yy, SpriteForge.snes(Color("#5a5f6e")))
					for xx in range(x + w - 1, x + w + 4): img.set_pixel(xx, 0, SpriteForge.snes(Color("#fff2b0")))
				x += w + rng.randi_range(10, 40)
		"mesas":
			var x2 := 0
			while x2 < STRIP:
				var w2 := rng.randi_range(30, 80)
				var mh := rng.randi_range(6, 14)
				for xx in range(x2, min(STRIP, x2 + w2)):
					for yy in range(h - mh, h):
						img.set_pixel(xx, yy, SpriteForge.snes(Color("#a65f34") if yy > h - mh + 2 else Color("#c97a44")))
				x2 += w2 + rng.randi_range(20, 70)
		_:
			# tree line (pines or round trees)
			var pine := kind == "pines"
			var dark := SpriteForge.snes(Color("#2f6f44") if env != "snow" else Color("#5f8a78"))
			var lite := SpriteForge.snes(Color("#3f9a3a") if env != "snow" else Color("#e8f0f8"))
			for x3 in range(0, STRIP, 5):
				var th := rng.randi_range(7, 15)
				for yy in range(h - th, h):
					var half: int = (yy - (h - th)) / 2 if pine else mini(3, (yy - (h - th)) + 1)
					for dx in range(-half, half + 1):
						var xx := posmod(x3 + dx, STRIP)
						img.set_pixel(xx, yy, lite if (dx < 0 and yy < h - 3) else dark)
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _band_sky() -> void:
	var a := Color(theme.sky[0]); var b := Color(theme.sky[1])
	var bands := 10
	var hh := horizon / bands
	for i in bands:
		draw_rect(Rect2(0, floor(i * hh), view.x, ceil(hh) + 1), SpriteForge.snes(a.lerp(b, float(i) / (bands - 1))))

func _draw() -> void:
	_band_sky()
	var base := cam_ang / TAU * STRIP
	# sun / moon
	var sx := fposmod(STRIP * 0.3 - base * 0.8, STRIP)
	if sx < view.x + 12:
		var sc := Color("#f2f4ff") if night else Color("#fff6c8")
		if not rain:
			draw_rect(Rect2(sx - 5, 10, 10, 10), SpriteForge.snes(sc))
			draw_rect(Rect2(sx - 7, 12, 14, 6), SpriteForge.snes(sc))
	# clouds drift
	if not night:
		for c in clouds:
			var cx := fposmod(c[0] - base * 0.7 + t * 3.0, STRIP)
			if cx > view.x + 40: continue
			var w: int = c[2]
			var cy: float = c[1]
			var cc := SpriteForge.snes(Color("#ffffff") if not rain else Color("#c8ccd2"))
			draw_rect(Rect2(cx, cy, w, 4), cc)
			draw_rect(Rect2(cx + 4, cy - 3, w - 10, 3), cc)
			draw_rect(Rect2(cx + 2, cy + 4, w - 6, 2), SpriteForge.snes(Color("#d8e4f0") if not rain else Color("#a8b0b8")))
	else:
		for i in 40:
			var stx := fposmod(i * 97.0 - base * 0.6, STRIP)
			if stx < view.x: draw_rect(Rect2(stx, fmod(i * 37.0, horizon - 20.0), 1, 1), Color(1, 1, 1, 0.8 if i % 3 else 0.4))
	for L in layers:
		var tex: ImageTexture = L[0]
		var off := fposmod(base * L[1], STRIP)
		var y: float = L[2]
		draw_texture_rect_region(tex, Rect2(0, y, view.x, tex.get_height()), Rect2(off, 0, view.x, tex.get_height()))
		if off + view.x > STRIP:
			var w2 := off + view.x - STRIP
			draw_texture_rect_region(tex, Rect2(view.x - w2, y, w2, tex.get_height()), Rect2(0, 0, w2, tex.get_height()))
