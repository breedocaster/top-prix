class_name CrewFace
extends Control
## A staff member as the garage chibi (art/crew sheets, front-facing), recoloured for their skin, hair
## and the team suit with a one-row palette (cached per look). Not a screen. Don't modulate it.

var role := "drv"
var pose := "stand"
var px := 1
static var _pal := {}

func setup(s: Dictionary, team_col, scale_px := 1) -> CrewFace:
	role = "drv" if str(s.get("role", "drv")) == "drv" else "mech"
	px = maxi(1, scale_px)
	custom_minimum_size = Vector2(CrewModels.CELL) * px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tc: Color = team_col if team_col is Color else Color(str(team_col))
	var skin := Color(str(s.get("skin", GarageView.SKINS[0])))
	var hair := Color(str(s.get("hair", GarageView.HAIRS[0])))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/palette_swap.gdshader")
	m.set_shader_parameter("palette", _palette(tc, skin, hair))
	material = m
	return self

static func _palette(base: Color, skin: Color, hair: Color) -> ImageTexture:
	var key := "%s|%s|%s" % [base.to_html(), skin.to_html(), hair.to_html()]
	if _pal.has(key): return _pal[key]
	var M := SpriteForge.M
	var mats: int = M.size()
	var over := {CrewModels.SKIN: skin, CrewModels.HAIR: hair, CrewModels.CAP: Color(GarageView.CAP_COL)}
	var img := Image.create(mats * SpriteForge.LEVELS, 1, false, Image.FORMAT_RGBA8)
	var outline := SpriteForge.snes(Color(GarageView.OUTLINE))
	for m in mats:
		var ramp: Array = [] if m == 0 else SpriteForge.ramp7(over.get(m, SpriteForge.mat_color(m, base)))
		for l in SpriteForge.LEVELS:
			img.set_pixel(m * SpriteForge.LEVELS + l, 0, outline if m == 0 else ramp[mini(l, 7)])
	var t := ImageTexture.create_from_image(img)
	_pal[key] = t
	return t

func _draw() -> void:
	var tex := CrewModels.tex(role)
	var c := Vector2(CrewModels.CELL)
	var at := ((size - c * px) / 2.0).round()
	draw_texture_rect_region(tex, Rect2(at, c * px), CrewModels.frame_rect(pose, 2), SpriteForge.row_color(0))
