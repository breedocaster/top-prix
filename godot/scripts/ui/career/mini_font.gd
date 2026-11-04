extends RefCounted
## 3x5 pixel font for canvas annotations (jet sizes on the carb cutaway, EFI cell values, chart axes).
## One white glyph atlas built once; each character is a draw_texture_rect_region tinted by the
## draw colour (a per-call modulate, never a node modulate), so it is cheap to redraw every frame.
## Lower case maps to upper case. Advance 4 px (narrow punctuation 2 px); scale 2 doubles everything.

const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111",
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001011001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
	"8": "111101111101111", "9": "111101111001111",
	"-": "000000111000000", ".": "000000000000010", "'": "010010000000000", "!": "010010010000010",
	"?": "110001010000010", "/": "001001010100100", "#": "101111101111101", "+": "000010111010000",
	":": "000010000010000", "&": "010101010101011", " ": "000000000000000", "%": "101001010100101",
	"=": "000111000111000", "(": "010100100100010", ")": "010001001001010", ",": "000000000010100",
	"<": "001010100010001", ">": "100010001010100", "*": "000101010101000", "_": "000000000000111",
	"\"": "101101000000000", "[": "110100100100110", "]": "011001001001011", "^": "010101000000000",
	";": "000010000010100", "|": "010010010010010", "$": "011110010011110", "~": "000011110000000",
	"@": "010101111100011", "\\": "100100010001001", "{": "011010110010011", "}": "110010011010110",
}
const NARROW := ".:',;!|"
const ADV := 4

static var _atlas: ImageTexture = null
static var _index := {}

static func _ensure() -> void:
	if _atlas != null: return
	var keys := GLYPHS.keys()
	var img := Image.create(keys.size() * 4, 5, false, Image.FORMAT_RGBA8)
	for n in keys.size():
		var g: String = GLYPHS[keys[n]]
		_index[keys[n]] = n
		for k in 15:
			if g[k] == "1": img.set_pixel(n * 4 + k % 3, k / 3, Color.WHITE)
	_atlas = ImageTexture.create_from_image(img)

static func _adv(ch: String) -> int:
	return 2 if NARROW.contains(ch) else ADV

## Width in pixels of `text` at scale `s` (trailing gap removed).
static func width(text: String, s: int = 1) -> int:
	var w := 0
	for ch in text.to_upper(): w += _adv(ch)
	return maxi(0, w - 1) * s

## Draw `text` with its top-left at `pos`. align: 0 left, 1 centre, 2 right (pos.x is the anchor).
static func draw(ci: CanvasItem, text: String, pos: Vector2, col: Color, align: int = 0, s: int = 1, shadow := false) -> void:
	_ensure()
	var t := text.to_upper()
	var x := pos.x
	if align == 1: x -= floorf(width(t, s) / 2.0)
	elif align == 2: x -= width(t, s)
	x = floorf(x)
	var y := floorf(pos.y)
	for ch in t:
		var n: int = _index.get(ch, -1)
		var a := _adv(ch)
		if n >= 0 and ch != " ":
			var ox := -1 if a == 2 else 0
			var dst := Rect2(x + ox * s, y, 3 * s, 5 * s)
			if shadow: ci.draw_texture_rect_region(_atlas, Rect2(dst.position + Vector2(s, s), dst.size), Rect2(n * 4, 0, 3, 5), Color(0, 0, 0, col.a * 0.85))
			ci.draw_texture_rect_region(_atlas, dst, Rect2(n * 4, 0, 3, 5), col)
		x += a * s
