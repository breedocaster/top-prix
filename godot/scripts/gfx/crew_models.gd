class_name CrewModels
extends RefCounted
## Chibi garage crew (Kairosoft-sized, super-deformed: head ~ half the height) built from the same SDF
## primitives as the vehicles (SDModels) and pre-rendered the same way (SpriteForge.render_sd): glossy
## 7-step ramp, Bayer dither, 1 px outline, index colours (R = material*10, G = level*30) so the
## palette_swap shader recolours them per person on the GPU.
##
## Sheet layout (art/crew/<role>.png): columns = facing (0 away, 1 right, 2 front, 3 left),
## rows = POSES. Cell CELL px, feet at (CELL.x / 2, FOOT_Y).
## Materials: SUIT = overalls / race suit (team colour), SKIN, HAIR, CAP (mechanic cap), HELMET,
## GLASS (visor), TRIM (boots, belt, gloves), EYE, METAL (wrench), WHITE (suit stripe).

const M := SpriteForge.M
const CELL := Vector2i(24, 28)
const FOOT_Y := 23                 # render_sd puts the ground at cell.y - 5
const FACINGS := 4
const POSES := ["stand", "walk_a", "walk_b", "work_a", "work_b"]
const ROLES := ["mech", "drv"]
# material ids re-used for people; the garage palette maps them to per-person colours
const SKIN := M.SAND
const HAIR := M.TRUNK
const CAP := M.YELLOW
const EYE := M.TIRE

static var _tex := {}

static func path(role: String) -> String:
	return "res://art/crew/%s.png" % role

const S := 0.84                    # model scale: ~21 px tall at 1x next to ~30 px toy cars

static func _e(c: Vector3, r: Vector3, m: int, paint := false) -> Dictionary:
	return SDModels.ell(c * S, r * S, m, paint)
static func _k(a: Vector3, b: Vector3, r: float, m: int) -> Dictionary:
	return SDModels.cap(a * S, b * S, r * S, m)
static func _b(c: Vector3, h: Vector3, r: float, m: int, paint := false) -> Dictionary:
	return SDModels.rbox(c * S, h * S, r * S, m, paint)

## Parts list for one pose (model space: x forward, y right, z up, feet on z = 0).
static func parts(role: String, pose: String) -> Array:
	var P := []
	var drv := role == "drv"
	var walk := 0.0
	if pose == "walk_a": walk = 1.0
	elif pose == "walk_b": walk = -1.0
	var work := pose.begins_with("work")
	# boots + short legs
	for side in [-1.0, 1.0]:
		var fx: float = walk * side * 1.8
		P.append(_e(Vector3(fx + 0.7, side * 1.6, 1.0), Vector3(1.9, 1.3, 1.1), M.TRIM))
		P.append(_k(Vector3(fx * 0.6, side * 1.5, 1.8), Vector3(0, side * 1.4, 4.6), 1.35, M.SUIT))
	# torso (overalls / race suit)
	P.append(_e(Vector3(0, 0, 7.0), Vector3(2.6, 3.1, 3.1), M.SUIT))
	if drv:
		P.append(_b(Vector3(0, 0, 5.6), Vector3(3.2, 3.6, 0.55), 0.2, M.WHITE, true))     # belt stripe
		P.append(_b(Vector3(0, 0, 8.4), Vector3(3.2, 0.6, 2.4), 0.2, M.WHITE, true))      # zip stripe
	else:
		P.append(_b(Vector3(2.0, 0, 8.6), Vector3(1.0, 1.7, 1.3), 0.3, M.WHITE, true))    # bib / T-shirt
		P.append(_b(Vector3(0, 0, 5.4), Vector3(3.2, 3.6, 0.5), 0.2, M.TRIM, true))       # belt
	# arms + hands
	var hands := []
	for side in [-1.0, 1.0]:
		var h := Vector3(0.3, side * 3.8, 5.2)
		if walk != 0.0: h = Vector3(-walk * side * 1.8, side * 3.7, 5.5)
		if work:
			h = Vector3(3.1, side * 2.5, 7.4)
			if pose == "work_b" and side > 0: h = Vector3(2.8, 2.5, 9.8)
			if pose == "work_b" and side < 0: h = Vector3(3.3, -2.5, 6.9)
		hands.append(h)
		P.append(_k(Vector3(0, side * 2.9, 9.0), h, 1.15, M.SUIT))
		P.append(_e(h, Vector3(1.25, 1.25, 1.25), M.TRIM if drv else SKIN))
	if work and not drv:
		# spanner in the right hand
		var hr: Vector3 = hands[1]
		var tip := hr + (Vector3(3.0, 0, 1.2) if pose == "work_a" else Vector3(1.4, 0, 3.0))
		P.append(_k(hr, tip, 0.6, M.METAL))
		P.append(_e(tip, Vector3(1.0, 1.0, 1.0), M.METAL))
	# big SD head
	var head := Vector3(0.4, 0, 14.3)
	if drv:
		# full-face helmet with a team stripe; face shows through the open visor
		P.append(_e(head + Vector3(0, 0, 0.4), Vector3(4.9, 5.0, 4.8), M.HELMET))
		P.append(_b(head + Vector3(-1, -2.4, 5.0), Vector3(7, 0.8, 3.0), 0.3, M.SUIT, true))
		P.append(_b(head + Vector3(-1, 2.4, 5.0), Vector3(7, 0.8, 3.0), 0.3, M.SUIT, true))
		P.append(_e(head + Vector3(4.6, 0, -0.4), Vector3(2.4, 3.4, 2.0), SKIN, true))
		P.append(_b(head + Vector3(4.4, 0, 2.0), Vector3(1.8, 3.8, 0.7), 0.2, M.GLASS, true))   # visor up
		for side in [-1.0, 1.0]:
			P.append(_e(head + Vector3(4.9, side * 1.4, -0.3), Vector3(0.9, 0.7, 1.1), EYE, true))
	else:
		P.append(_e(head, Vector3(4.3, 4.6, 4.1), SKIN))
		P.append(_e(head + Vector3(-2.6, 0, 0.2), Vector3(3.4, 5.4, 3.8), HAIR, true))      # hair (back + sides)
		P.append(_e(head + Vector3(0.4, 0, 4.0), Vector3(5.2, 5.4, 2.6), CAP, true))       # cap crown
		P.append(_b(head + Vector3(4.2, 0, 2.2), Vector3(1.9, 3.5, 0.5), 0.3, CAP))         # brim
		for side in [-1.0, 1.0]:
			P.append(_e(head + Vector3(4.0, side * 1.7, -0.3), Vector3(0.9, 0.75, 1.15), EYE, true))
	return P

## Index sheet for one role: FACINGS columns x POSES rows.
static func bake(role: String) -> Image:
	var sheet := Image.create(CELL.x * FACINGS, CELL.y * POSES.size(), false, Image.FORMAT_RGBA8)
	for i in POSES.size():
		var vox := SDModels.voxelize(parts(role, POSES[i]))
		var strip := SpriteForge.render_sd(vox, Vector2.ZERO, FACINGS, CELL, 1, SpriteForge.PITCH)
		sheet.blit_rect(strip, Rect2i(0, 0, strip.get_width(), strip.get_height()), Vector2i(0, i * CELL.y))
	return sheet

## Index sheet as a texture: the baked PNG when present, otherwise rendered now (slow; bake via the garage test).
static func tex(role: String) -> Texture2D:
	if _tex.has(role): return _tex[role]
	var t: Texture2D
	var p := path(role)
	if ResourceLoader.exists(p):
		t = load(p)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(p)):
		t = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(p)))
	else:
		t = ImageTexture.create_from_image(bake(role))
	_tex[role] = t
	return t

static func pose_index(pose: String) -> int:
	return maxi(0, POSES.find(pose))

## Source rect of a frame in the sheet.
static func frame_rect(pose: String, facing: int) -> Rect2:
	return Rect2(facing * CELL.x, pose_index(pose) * CELL.y, CELL.x, CELL.y)
