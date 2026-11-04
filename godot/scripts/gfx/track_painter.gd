class_name TrackPainter
extends Node2D
## Paints the top-down course into a SubViewport once; the Mode 7 shader samples the result.

var geo: TrackGeo
var dark := false

static func make_viewport(g: TrackGeo, night: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(g.bbox.size.x), ceili(g.bbox.size.y))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var p := TrackPainter.new()
	p.geo = g
	p.dark = night
	p.position = -g.bbox.position
	vp.add_child(p)
	return vp

func _col(hex: String) -> Color:
	var c := Color(hex)
	return c.darkened(0.45) if dark else c

func _sec_at(i: int) -> Dictionary:
	return geo.tr.secs[geo.sec_index_at_px(i * TrackGeo.STEP)]

func _draw() -> void:
	var pts := geo.pts
	var n := pts.size()
	var W := geo.width
	var secs: Array = geo.tr.secs
	var rng := RandomNumberGenerator.new(); rng.seed = 1234
	# 1) verge / run-off
	for i in range(0, n, 2):
		var s := _sec_at(i)
		draw_circle(pts[i], W * 0.5 + 9.0, _col(Env.VERGE_COL[s.surf]))
	# 2) surface
	for i in range(0, n, 2):
		var s := _sec_at(i)
		draw_circle(pts[i], W * 0.5, _col(Env.SURF_COL[s.surf]))
	# 3) texture detail + lines + curbs
	for i in range(0, n, 1):
		var s := _sec_at(i)
		var hd := geo.heads[i]
		var nrm := Vector2.from_angle(hd + PI / 2.0)
		var p := pts[i]
		var surf: String = s.surf
		var base := _col(Env.SURF_COL[surf])
		var tarmac := surf == "tar" or surf == "wet"
		if tarmac:
			if i % 3 == 0:
				for k in 2:
					var off := rng.randf_range(-W * 0.45, W * 0.45)
					draw_rect(Rect2((p + nrm * off).floor(), Vector2(2, 2)), base.darkened(0.12) if rng.randf() < 0.6 else base.lightened(0.08))
			if i % 2 == 0:
				for side in [-1.0, 1.0]:
					draw_rect(Rect2((p + nrm * side * (W * 0.5 - 4.0)).floor(), Vector2(2, 2)), _col("#e8e8e0"))
			if (s.type == "crv" or s.type == "hp" or s.type == "chi") and i % 2 == 0:
				var c := _col("#d8402e") if (i / 2) % 2 == 0 else _col("#f2f2ee")
				for side in [-1.0, 1.0]:
					draw_rect(Rect2((p + nrm * side * (W * 0.5 + 1.0) - Vector2(2, 2)).floor(), Vector2(4, 4)), c)
		else:
			# ruts
			if i % 1 == 0:
				for side in [-1.0, 1.0]:
					draw_rect(Rect2((p + nrm * side * W * 0.2).floor(), Vector2(2, 2)), base.darkened(0.22))
			if i % 4 == 0 and rng.randf() < 0.5:
				var off2 := rng.randf_range(-W * 0.45, W * 0.45)
				draw_rect(Rect2((p + nrm * off2).floor(), Vector2(3, 2)), base.lightened(0.15) if surf != "mud" else base.darkened(0.3))
		if s.type == "jmp":
			var u: float = (i * TrackGeo.STEP - geo.sec_px[geo.sec_index_at_px(i * TrackGeo.STEP)]) / (s.len * geo.unit)
			if u > 0.25 and u < 0.42 and i % 2 == 0:
				_cross(p, nrm, W, _col("#f2c21e") if (i / 2) % 2 == 0 else _col("#2a2a30"))
			if u >= 0.42 and u < 0.5:
				_cross(p, nrm, W, base.darkened(0.35))
		if s.type == "rgh" and i % 3 == 0:
			_cross(p, nrm, W * 0.8, base.darkened(0.18))
	# 4) start / finish
	_checker(0)
	if not geo.closed:
		_checker(n - 1)
	if geo.tr.drag:
		for i in range(0, n, 6):
			draw_rect(Rect2((pts[i] - Vector2(1, 1)).floor(), Vector2(2, 3)), _col("#f2f2ee"))
	elif geo.closed:
		# grid slots behind the line
		for g in 6:
			var i := n - 1 - (g + 1) * 7
			if i <= 0: break
			var nrm := Vector2.from_angle(geo.heads[i] + PI / 2.0)
			for side in [-1.0, 1.0]:
				draw_rect(Rect2((pts[i] + nrm * side * W * 0.22 - Vector2(4, 1)).floor(), Vector2(8, 2)), _col("#f2f2ee"))

func _cross(p: Vector2, nrm: Vector2, w: float, c: Color) -> void:
	var a := p - nrm * w * 0.5
	for k in int(w / 2.0):
		draw_rect(Rect2((a + nrm * k * 2.0).floor(), Vector2(2, 2)), c)

func _checker(i: int) -> void:
	var p := geo.pts[i]
	var hd := geo.heads[i]
	var fwd := Vector2.from_angle(hd)
	var nrm := Vector2.from_angle(hd + PI / 2.0)
	var W := geo.width
	for row in 2:
		for k in int(W / 4.0) + 1:
			var c := Color("#f2f2ee") if (k + row) % 2 == 0 else Color("#1a1a20")
			var q := p - nrm * W * 0.5 + nrm * k * 4.0 + fwd * row * 4.0
			draw_rect(Rect2(q.floor(), Vector2(4, 4)), c)
