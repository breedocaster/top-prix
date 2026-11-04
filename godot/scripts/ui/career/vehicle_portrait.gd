class_name VehiclePortrait
extends Control
## A machine drawn from its super-deformed sheet (SpriteForge.vehicle_tex), palette-swapped on the GPU
## in the team colour (palette_swap.gdshader, modulate SpriteForge.row_color(0)). spin = true walks
## slowly through the 16 yaw frames (one redraw per frame step, no image work). Not a screen.
## Don't modulate this node or its parents: the shader reads the draw colour as a palette row.

const STEP := 0.16          # seconds per yaw frame while spinning
const STILL := 6            # 3/4 view facing right

var kind := "hatch"
var col := Color("#e8432f")
var px := 1                 # integer scale
var spin := false
var frame := STILL
var grey := false           # locked / unavailable: drawn in the grey shop palette
var _t := 0.0

static var _pal := {}

## trim: pixels (at 1x) of the empty cell margin left out of the layout box on each side; the sprite
## still draws whole, centred, over the neighbours' margins.
func setup(k: String, c, scale_px := 1, spinning := false, trim := 0) -> VehiclePortrait:
	kind = k if SpriteForge.KINDS.has(k) else "hatch"
	col = c if c is Color else Color(str(c))
	px = maxi(1, scale_px)
	spin = spinning
	custom_minimum_size = (Vector2(SpriteForge.VCELL) - Vector2(trim, trim) * 2) * px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/palette_swap.gdshader")
	m.set_shader_parameter("palette", palette_for(Color("#7a8494") if grey else col))
	material = m
	set_process(spin)
	queue_redraw()
	return self

func set_grey(g: bool) -> void:
	grey = g
	if material: (material as ShaderMaterial).set_shader_parameter("palette", palette_for(Color("#7a8494") if grey else col))
	queue_redraw()

static func palette_for(c: Color) -> ImageTexture:
	var key := c.to_html()
	if not _pal.has(key): _pal[key] = SpriteForge.palette([c])
	return _pal[key]

func _process(d: float) -> void:
	_t += d
	if _t >= STEP:
		_t -= STEP
		frame = (frame + 1) % SpriteForge.FRAMES
		queue_redraw()

func _draw() -> void:
	var tex := SpriteForge.vehicle_tex(kind)
	var c := Vector2(SpriteForge.VCELL)
	var sz := c * px
	var at := ((size - sz) / 2.0).round()
	draw_rect(Rect2(at + Vector2(6 * px, (c.y - 7) * px), Vector2((c.x - 12) * px, 3 * px)), Color(0.02, 0.01, 0.08, 0.35))
	draw_texture_rect_region(tex, Rect2(at, sz), Rect2(frame * c.x, 0, c.x, c.y), SpriteForge.row_color(0))
