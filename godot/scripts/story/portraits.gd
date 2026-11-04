class_name Portraits
extends RefCounted
## Story-mode character busts, built like the vehicles: super-deformed SDF primitives (big head,
## small shoulders), voxelized at 1 voxel ~ 1 px, rendered once with the same glossy 7-step ramp,
## Bayer-dithered light levels, specular glints, 15-bit colour snapping and 1 px dark outline.
## Baked to res://art/portraits/<id>_<expr>.png by tests/story_test.gd; rendered live if missing.
## Model space: x = where the face looks, y = right, z = up; bust cut flat at z = 0.

const CELL := Vector2i(48, 48)
const YAW := PI - 0.24      # slight three-quarter view, looking toward screen right
const PITCH := 0.2
const DIR := "res://art/portraits"

# portrait materials (stored as id * 10 in the red channel, like SpriteForge index sheets)
enum P { NONE, SKIN, HAIR, EYE, WHITE, BROW, MOUTH, BLUSH, TEETH, SHIRT, JACKET, TRIM, CAP, ACC, METAL, GLASS, ACC2, RED, DARK, HAIR2 }
const GLOSSY := [P.HAIR, P.JACKET, P.CAP, P.ACC, P.METAL, P.GLASS, P.RED, P.HAIR2, P.WHITE]
const BAYER := [0.0, 0.5, 0.75, 0.25]
## Cel-shaded without dither: faces read cleaner at 48 px.
const FLAT := [P.SKIN]

## Head: centre and radii. Everything on the face is placed on this ellipsoid's front surface.
const HC := Vector3(0, 0, 25.0)
const HR := Vector3(12.0, 14.0, 12.5)

## Who exists and which expressions each one has (kept in step with data/story/characters.json).
const CAST := {
	"hazel": ["neutral", "happy", "angry"],
	"rosie": ["neutral", "happy", "angry"],
	"dewey": ["neutral", "happy", "worried"],
	"barb": ["neutral", "happy", "worried"],
	"walt": ["neutral", "happy", "worried"],
	"victoria": ["neutral", "happy", "angry"],
	"preston": ["neutral", "happy", "angry"],
	"silas": ["neutral", "happy", "angry"],
	"midge": ["neutral", "happy", "worried"],
}

static var _tex := {}
static var _base := {}

# ---------------- palettes ----------------
static func palette(id: String) -> Dictionary:
	var p := {P.SKIN: "#f5d0a9", P.HAIR: "#5a3214", P.EYE: "#2a1838", P.WHITE: "#fbf8f0", P.MOUTH: "#8a2638",
		P.BLUSH: "#f2828a", P.TEETH: "#ffffff", P.SHIRT: "#e8e4d8", P.JACKET: "#3f6fb0", P.TRIM: "#3a3c46",
		P.CAP: "#2f9a4a", P.ACC: "#ffd84a", P.METAL: "#9aa2ad", P.GLASS: "#78b8e8", P.ACC2: "#f2f0ea",
		P.RED: "#d8402e", P.DARK: "#2a2a30", P.HAIR2: "#e8e8f0"}
	match id:
		"hazel": p.merge({P.SKIN: "#e8b888", P.HAIR: "#d4d6e2", P.JACKET: "#4a78b8", P.SHIRT: "#e8e2cc", P.RED: "#d8402e", P.METAL: "#8a6a3a", P.GLASS: "#5fc8b8"}, true)
		"rosie": p.merge({P.SKIN: "#c68642", P.HAIR: "#3a2014", P.JACKET: "#e8432f", P.SHIRT: "#f4f1e8", P.ACC2: "#f2e2c0", P.BLUSH: "#e0705a"}, true)
		"dewey": p.merge({P.SKIN: "#ffdbac", P.HAIR: "#e07a2a", P.CAP: "#2f9a4a", P.ACC2: "#f2f0ea", P.JACKET: "#4f8a3a", P.SHIRT: "#e8d8a8", P.BLUSH: "#d88a5a"}, true)
		"barb": p.merge({P.SKIN: "#f5d0a9", P.HAIR: "#f0d070", P.JACKET: "#f2b01e", P.SHIRT: "#fbf6ee", P.MOUTH: "#d8406a", P.ACC2: "#fbf6ee"}, true)
		"walt": p.merge({P.SKIN: "#e0ac69", P.HAIR: "#b8b8c0", P.JACKET: "#8a5a32", P.SHIRT: "#e8e4d8", P.RED: "#c0392b", P.DARK: "#3a3c46", P.GLASS: "#a8d8f0"}, true)
		"victoria": p.merge({P.SKIN: "#ffdbac", P.HAIR: "#eef0f8", P.JACKET: "#6a3fb5", P.SHIRT: "#2a1838", P.MOUTH: "#a01838", P.ACC: "#ffd84a"}, true)
		"preston": p.merge({P.SKIN: "#f5d0a9", P.HAIR: "#f2d468", P.JACKET: "#6a3fb5", P.SHIRT: "#ffd84a", P.ACC: "#ffd84a"}, true)
		"silas": p.merge({P.SKIN: "#c8946a", P.HAIR: "#2a2a3a", P.JACKET: "#4a2a8a", P.SHIRT: "#1e1a2a", P.ACC: "#ffd84a", P.BLUSH: "#8a5a4a"}, true)
		"midge": p.merge({P.SKIN: "#8d5524", P.HAIR: "#5a5a66", P.HAIR2: "#e8e8f0", P.JACKET: "#5a7088", P.SHIRT: "#e8e4d8", P.GLASS: "#c8e8f8", P.ACC: "#6a3fb5"}, true)
	return p

# ---------------- geometry helpers ----------------
static func E(c: Vector3, r: Vector3, m: int, paint := false) -> Dictionary: return SDModels.ell(c, r, m, paint)
static func B(c: Vector3, h: Vector3, r: float, m: int, paint := false) -> Dictionary: return SDModels.rbox(c, h, r, m, paint)
static func C(a: Vector3, b: Vector3, r: float, m: int) -> Dictionary: return SDModels.cap(a, b, r, m)

## Point on the head's front surface at sideways offset y and height dz (relative to the head centre).
static func face(y: float, dz: float, out := 0.0) -> Vector3:
	var k := 1.0 - pow(y / HR.y, 2) - pow(dz / HR.z, 2)
	return Vector3(HC.x + HR.x * sqrt(maxf(k, 0.0)) + out, y, HC.z + dz)

# ---------------- bodies ----------------
static func _bust(P_: Array, collar := "round") -> void:
	P_.append(E(Vector3(-1, 0, 4.0), Vector3(8.0, 12.5, 9.5), P.JACKET))                    # shoulders
	P_.append(SDModels.cylz(Vector3(0, 0, 13.0), 3.4, 2.5, P.SKIN, 1.0))                    # neck
	match collar:
		"round": P_.append(B(Vector3(5.0, 0, 10.5), Vector3(2.5, 4.2, 2.2), 1.5, P.SHIRT))
		"vee":
			P_.append(B(Vector3(4.8, 0, 9.5), Vector3(2.5, 3.2, 3.0), 1.2, P.SHIRT))
			for s in [-1.0, 1.0]: P_.append(C(Vector3(5.0, s * 5.0, 12.5), Vector3(6.5, s * 1.0, 6.0), 1.1, P.JACKET))
		"popped":
			for s in [-1.0, 1.0]: P_.append(B(Vector3(1.5, s * 5.6, 13.5), Vector3(3.8, 1.3, 3.6), 0.8, P.ACC))
			P_.append(B(Vector3(5.0, 0, 10.0), Vector3(2.2, 3.6, 2.5), 1.2, P.SHIRT))
		"suit":
			for s in [-1.0, 1.0]: P_.append(B(Vector3(2.8, s * 5.0, 13.0), Vector3(3.4, 1.3, 2.6), 0.8, P.SHIRT))
			P_.append(B(Vector3(5.2, 0, 9.5), Vector3(2.2, 3.2, 2.5), 1.2, P.SHIRT))

static func _head(P_: Array) -> void:
	P_.append(E(HC, HR, P.SKIN))
	for s in [-1.0, 1.0]: P_.append(E(Vector3(HC.x - 1.0, s * (HR.y - 0.4), HC.z - 1.5), Vector3(2.2, 1.8, 2.8), P.SKIN))   # ears

## A cap of hair over the skull: pushed back by `back`, raised by `up`, puffed out by `puff`.
static func _hair(P_: Array, back := 2.0, up := 3.0, puff := 0.6, m: int = P.HAIR) -> void:
	P_.append(E(Vector3(HC.x - back, 0, HC.z + up), Vector3(HR.x - 0.3 + puff * 0.3, HR.y + puff, HR.z - 0.3 + puff * 0.3), m))

## Solid geometry per character (hair, hats, accessories, clothes).
static func solids(id: String) -> Array:
	var S := []
	var H := HC
	match id:
		"hazel":
			_bust(S, "vee")
			S.append(B(Vector3(-0.5, 0, 7.0), Vector3(7.5, 12.0, 1.5), 1.0, P.RED, true))                # bandana band
			_head(S)
			_hair(S, 2.2, 3.2, 0.5)
			S.append(E(Vector3(H.x - 9.0, 1.5, H.z + 9.5), Vector3(5.2, 5.2, 4.8), P.HAIR))             # bun
			S.append(C(face(-10.5, 6.0, -1.6), face(-2.0, 9.5, -1.2), 2.0, P.HAIR))                     # swept bangs
			S.append(C(face(10.5, 6.0, -1.6), face(2.0, 9.5, -1.2), 2.0, P.HAIR))
			S.append(B(Vector3(H.x - 1.0, 0, H.z + 9.0), Vector3(12.5, 15.0, 1.1), 0.8, P.DARK, true))   # goggle strap
			for s in [-1.0, 1.0]:
				S.append(E(face(s * 5.0, 9.0, 0.0), Vector3(2.2, 3.1, 2.6), P.METAL))                    # goggle cups
				S.append(E(face(s * 5.0, 9.0, 1.9), Vector3(1.6, 2.2, 1.8), P.GLASS, true))
		"rosie":
			_bust(S, "round")
			for s in [-1.0, 1.0]: S.append(B(Vector3(1.0, s * 6.5, 6.0), Vector3(5.5, 1.0, 5.5), 0.6, P.SHIRT, true))   # suit stripes
			_head(S)
			_hair(S, 2.0, 2.8, 0.6)
			S.append(C(face(-11.0, 6.0, -1.4), face(3.0, 9.4, -1.0), 2.4, P.HAIR))                     # side-swept fringe
			S.append(C(face(2.0, 9.4, -1.4), face(9.5, 5.5, -1.8), 2.0, P.HAIR))
			S.append(E(Vector3(H.x - 8.5, 5.0, H.z + 10.0), Vector3(3.0, 3.0, 3.0), P.RED))             # scrunchie
			S.append(C(Vector3(H.x - 9.5, 6.0, H.z + 10.5), Vector3(H.x - 13.0, 14.0, H.z + 9.0), 3.4, P.HAIR))   # flipped ponytail
			S.append(C(Vector3(H.x - 13.0, 14.0, H.z + 9.0), Vector3(H.x - 12.0, 18.5, H.z + 2.0), 2.4, P.HAIR))
		"dewey":
			_bust(S, "round")
			for s in [-1.0, 1.0]: S.append(B(Vector3(3.8, s * 5.0, 5.0), Vector3(2.0, 1.0, 6.0), 0.5, P.TRIM, true))  # overall straps
			_head(S)
			for s in [-1.0, 1.0]:
				S.append(E(Vector3(H.x - 1.0, s * 12.5, H.z + 3.0), Vector3(4.2, 3.2, 4.6), P.HAIR))    # tufts under the cap
				S.append(C(Vector3(H.x + 2.0, s * 12.0, H.z + 1.0), Vector3(H.x + 4.5, s * 13.5, H.z - 2.0), 1.2, P.HAIR))
			S.append(E(Vector3(H.x - 7.0, 0, H.z + 1.0), Vector3(5.5, 12.0, 6.5), P.HAIR))
			S.append(E(Vector3(H.x - 1.0, 0, H.z + 5.5), Vector3(12.0, 14.2, 9.6), P.CAP))             # trucker cap crown
			S.append(B(face(0, 7.5, -1.4), Vector3(1.6, 7.0, 3.8), 1.4, P.ACC2, true))                 # mesh-front panel
			S.append(B(face(0, 4.8, 3.2), Vector3(4.2, 9.5, 0.8), 0.7, P.CAP))                         # bill
			S.append(E(face(0, 8.5, -0.3), Vector3(1.0, 2.4, 1.6), P.RED, true))                       # patch
		"barb":
			_bust(S, "suit")
			_head(S)
			_hair(S, 2.6, 3.8, 1.2)
			for i in 7:
				var a := -PI * 0.5 + i * PI / 6.0
				S.append(E(Vector3(H.x - 4.5, sin(a) * 14.5, H.z + 4.5 + cos(a) * 10.0), Vector3(4.6, 4.6, 4.6), P.HAIR))   # perm curls
			for s in [-1.0, 1.0]:
				S.append(E(Vector3(H.x - 4.5, s * 15.0, H.z - 5.0), Vector3(4.2, 3.8, 5.2), P.HAIR))
				S.append(E(Vector3(H.x - 0.5, s * 14.2, H.z - 5.0), Vector3(1.5, 1.5, 1.5), P.WHITE))     # pearls
			S.append(C(face(-9.0, 7.6, -1.2), face(7.0, 8.6, -1.2), 2.4, P.HAIR))                       # bangs
			S.append(E(Vector3(4.2, -5.5, 7.5), Vector3(1.2, 2.0, 2.0), P.RED))                          # Corn Belt pin
		"walt":
			_bust(S, "suit")
			S.append(E(Vector3(6.4, -2.0, 11.0), Vector3(1.4, 2.0, 1.5), P.RED))                         # bow tie
			S.append(E(Vector3(6.4, 2.0, 11.0), Vector3(1.4, 2.0, 1.5), P.RED))
			_head(S)
			for s in [-1.0, 1.0]:
				S.append(E(Vector3(H.x - 3.5, s * 12.6, H.z + 0.5), Vector3(6.5, 3.4, 4.8), P.HAIR))     # side fringe
				S.append(SDModels.cyl(Vector3(H.x - 1.0, s * 14.6, H.z), 4.4, 1.7, P.DARK, 1.0))         # ear cups
				S.append(C(Vector3(H.x - 1.0, s * 14.4, H.z + 3.5), Vector3(H.x - 1.0, s * 10.5, H.z + 12.0), 1.1, P.DARK))
			S.append(C(Vector3(H.x - 1.0, -10.5, H.z + 12.0), Vector3(H.x - 1.0, 10.5, H.z + 12.0), 1.1, P.DARK))   # headband
			S.append(C(Vector3(H.x, -15.0, H.z - 2.0), face(-8.5, -8.0, 2.4), 0.7, P.DARK))            # mic boom
			S.append(E(face(-8.0, -8.2, 2.8), Vector3(1.7, 1.7, 1.7), P.RED))
			for s in [-1.0, 1.0]:
				S.append(E(face(s * 5.3, -0.8, 0.9), Vector3(0.8, 2.9, 2.6), P.METAL))                   # round specs
				S.append(E(face(s * 5.3, -0.8, 1.7), Vector3(0.9, 2.2, 1.9), P.GLASS, true))
			S.append(C(face(-2.2, 0.0, 1.5), face(2.2, 0.0, 1.5), 0.5, P.METAL))
		"victoria":
			_bust(S, "suit")
			S.append(E(Vector3(4.5, -5.5, 8.0), Vector3(1.4, 2.0, 2.0), P.ACC))                          # brooch
			_head(S)
			_hair(S, 2.4, 3.6, 0.4)
			S.append(E(Vector3(H.x - 5.0, 0, H.z + 12.0), Vector3(6.0, 7.0, 5.4), P.HAIR))              # tall chignon
			S.append(C(face(-11.0, 4.0, -1.6), face(5.0, 10.0, -1.2), 2.6, P.HAIR))                      # sleek sweep
			for s in [-1.0, 1.0]: S.append(E(Vector3(H.x - 0.5, s * 14.2, H.z - 5.5), Vector3(1.4, 1.4, 1.9), P.ACC))
		"preston":
			_bust(S, "popped")
			_head(S)
			_hair(S, 2.6, 2.8, 0.2)
			S.append(E(Vector3(H.x + 3.5, 2.0, H.z + 10.5), Vector3(7.5, 11.0, 4.6), P.HAIR))           # pompadour swoop
			S.append(E(Vector3(H.x + 8.5, 4.5, H.z + 9.0), Vector3(3.2, 5.5, 2.8), P.HAIR))
		"silas":
			_bust(S, "round")
			for s in [-1.0, 1.0]: S.append(B(Vector3(1.0, s * 7.5, 6.0), Vector3(6.5, 0.9, 6.5), 0.5, P.ACC, true))   # gold piping
			_head(S)
			_hair(S, 2.8, 2.4, 0.2)
			S.append(C(face(-8.0, 8.4, -1.8), face(8.0, 8.4, -1.8), 1.6, P.HAIR))
			S.append(C(face(4.0, 8.0, -1.0), face(10.0, 1.0, -0.8), 1.0, P.HAIR))                        # one loose strand
		"midge":
			_bust(S, "vee")
			S.append(B(Vector3(4.5, 6.0, 7.0), Vector3(1.0, 2.2, 1.6), 0.4, P.ACC, true))               # torn-off patch outline
			_head(S)
			_hair(S, 1.8, 2.2, 0.8)
			for s in [-1.0, 1.0]: S.append(E(Vector3(H.x - 1.0, s * 13.4, H.z - 4.0), Vector3(5.5, 3.2, 5.0), P.HAIR))
			S.append(C(face(-10.0, 7.4, -1.2), face(10.0, 7.4, -1.2), 2.0, P.HAIR))                      # straight fringe
			S.append(B(Vector3(H.x - 2.0, 4.5, H.z + 10.0), Vector3(8.0, 2.2, 2.2), 0.8, P.HAIR2, true))  # grey streak
			for s in [-1.0, 1.0]: S.append(E(face(s * 5.3, -0.6, 0.9), Vector3(0.9, 3.4, 2.7), P.GLASS))   # safety glasses
			S.append(C(face(-9.5, 0.4, 0.4), face(9.5, 0.4, 0.4), 0.55, P.DARK))
			S.append(E(Vector3(H.x + 2.0, 14.5, H.z + 1.0), Vector3(1.0, 1.0, 4.2), P.ACC2))            # pencil behind the ear
	return S

# ---------------- faces ----------------
## Faces are hand-drawn pixel stamps (like SNES portrait artists did over pre-rendered heads), placed at
## the screen projection of anchor points on the 3D head, so they follow the three-quarter turn.
const EYE_OPEN := [".##.", "#WW#", "#W##", "####", "#I##", ".##."]
const EYE_OPEN_FAR := [".#.", "#W#", "###", "###", "#I#", ".#."]
const EYE_SPEC := [".##.", "#W##", "####", ".##."]           # small eyes behind glasses
const EYE_LID := ["BBBB", "#WW#", "#I##", ".##."]            # cool half-lidded
const EYE_LID_FAR := ["BBB", "#W#", "#I#", ".#."]
const EYE_ANGRY := ["B...", "#B..", "#W##", "#I##", ".##."]
const EYE_ANGRY_FAR := ["B..", "#B.", "#W#", "#I#", ".#."]
const EYE_HAPPY := [".###.", "#...#"]
const EYE_HAPPY_FAR := [".##.", "#..#"]
const MOUTH_LINE := ["MMMM"]
const MOUTH_SMIRK := ["....M", ".MMM.", "M...."]
const MOUTH_SMILE := ["M....M", ".MMMM."]
const MOUTH_OPEN := ["MMMMMM", "MTTTTM", ".MRRM.", "..MM.."]
const MOUTH_GRIT := ["MMMMMMM", "MTMTMTM", "MMMMMMM"]
const MOUTH_O := [".M.", "MRM", ".M."]
const MOUTH_FROWN := [".MMM.", "M...M"]
const BLUSH := ["P.P.", ".P.P"]
const FRECKLES := ["F.F", ".F."]
const PLASTER := ["AAAA", "AaaA", "AAAA"]
const SWEAT := [".S.", "SSS", "SLS", ".S."]
const VEIN := [".V.V.", "VV.VV", ".....", "VV.VV", ".V.V."]

static func eye_color(id: String) -> Color:
	match id:
		"hazel": return Color("#3a6a5a")
		"rosie": return Color("#6a3a1a")
		"dewey": return Color("#2a5aa8")
		"barb": return Color("#2a7ab8")
		"walt": return Color("#4a3a2a")
		"victoria": return Color("#6a3a9a")
		"preston": return Color("#3a6ad8")
		"silas": return Color("#5a5a6a")
		"midge": return Color("#3a2a1a")
	return Color("#3a2a4a")

static func _cmap(id: String) -> Dictionary:
	var pal := palette(id)
	var ec := eye_color(id)
	var hair := Color(pal[P.HAIR])
	var brow := hair.darkened(0.5) if hair.get_luminance() < 0.7 else Color("#6a6a7a")
	var skin := Color(pal[P.SKIN])
	var cm := {"#": ec.darkened(0.62), "I": ec.lightened(0.25), "W": Color("#fbf8f0"), "B": brow,
		"M": Color(pal[P.MOUTH]).darkened(0.35), "T": Color("#ffffff"), "R": Color("#e0607a"),
		"P": Color(pal[P.BLUSH]), "F": skin.darkened(0.32), "A": Color("#f2e2c0"), "a": Color("#c8a07a"),
		"S": Color("#8ad0f8"), "L": Color("#eaf8ff"), "V": Color("#e8402e")}
	for k in cm: cm[k] = SpriteForge.snes(cm[k])
	return cm

## Screen position of a model-space point, same projection as render().
static func project(p: Vector3, yaw: float = YAW, pitch: float = PITCH, cell: Vector2i = CELL) -> Vector2:
	var cy := cos(yaw); var sy := sin(yaw)
	var r := Vector3(p.x * cy - p.y * sy, p.x * sy + p.y * cy, p.z)
	return Vector2(cell.x / 2.0 + r.y, cell.y - 1.0 - (r.x * sin(pitch) + r.z * cos(pitch)))

static func _stamp(img: Image, pat: Array, center: Vector2, cm: Dictionary, flip := false) -> void:
	var h := pat.size()
	var w: int = pat[0].length()
	var x0 := int(round(center.x - w / 2.0)); var y0 := int(round(center.y - h / 2.0))
	for y in h:
		var row: String = pat[y]
		for x in w:
			var ch := row[w - 1 - x] if flip else row[x]
			if ch == "." or not cm.has(ch): continue
			var px := Vector2i(x0 + x, y0 + y)
			if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height(): continue
			img.set_pixelv(px, cm[ch])

static func _line(img: Image, a: Vector2, b: Vector2, col: Color, thick := 1) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / max(1, n))
		for t in thick:
			var q := Vector2i(int(round(p.x)), int(round(p.y)) + t)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height(): img.set_pixelv(q, col)

## Draw eyes, brows, mouth and extras for an expression onto a coloured portrait.
static func draw_face(img: Image, id: String, expr: String) -> void:
	var cm := _cmap(id)
	var cool := id in ["silas", "victoria"]
	var glasses := id in ["walt", "midge"]
	var ey := 5.3; var ez := -1.2
	var mouth := project(face(0.3, -6.8))
	for s in [-1.0, 1.0]:
		var c := project(face(s * ey, ez))
		var w := (project(face(s * ey + 1.5, ez)) - project(face(s * ey - 1.5, ez))).length()
		var far := w < 2.6
		var inner_right := mouth.x > c.x
		var pat: Array
		if glasses: pat = EYE_SPEC if expr != "happy" else EYE_HAPPY_FAR
		elif expr == "happy" and not cool: pat = EYE_HAPPY_FAR if far else EYE_HAPPY
		elif cool: pat = EYE_LID_FAR if far else EYE_LID
		elif expr == "angry": pat = EYE_ANGRY_FAR if far else EYE_ANGRY
		else: pat = EYE_OPEN_FAR if far else EYE_OPEN
		var flip := (pat == EYE_ANGRY or pat == EYE_ANGRY_FAR) and not inner_right
		_stamp(img, pat, c, cm, flip)
		# brows
		var o := project(face(s * (ey + 2.2), ez + 5.0))
		var i := project(face(s * (ey - 1.8), ez + 5.0))
		match expr:
			"angry": o.y -= 1.0; i.y += 1.5
			"worried": o.y += 1.0; i.y -= 1.0
			"happy": o.y -= 0.5; i.y -= 0.5
		if cool and expr == "angry": o.y -= 0.5; i.y += 0.5
		_line(img, o, i, cm.B, 2 if id in ["hazel", "silas", "midge", "walt"] else 1)
		# cheeks
		var ck := project(face(s * 8.4, -4.4))
		if expr == "happy" or id in ["rosie", "barb", "dewey"]:
			_stamp(img, BLUSH if id != "dewey" else FRECKLES, ck, cm)
	match expr:
		"happy": _stamp(img, MOUTH_SMILE if cool else MOUTH_OPEN, mouth + Vector2(0, 0.5), cm)
		"angry": _stamp(img, MOUTH_FROWN if cool else MOUTH_GRIT, mouth, cm)
		"worried": _stamp(img, MOUTH_O, mouth, cm)
		_: _stamp(img, MOUTH_SMIRK if id in ["preston", "victoria", "silas", "hazel"] else MOUTH_LINE, mouth, cm)
	if id == "rosie": _stamp(img, PLASTER, project(face(-8.8, -2.8)), cm)
	if id == "silas": _line(img, project(face(6.6, 6.6)), project(face(4.6, 1.6)), cm.F, 1)
	if expr == "worried": _stamp(img, SWEAT, project(face(10.5, 5.0)), cm)
	if expr == "angry" and not cool: _stamp(img, VEIN, project(face(-8.0, 8.0)), cm)

# ---------------- rendering ----------------
## Surface voxels of the character's solids, cached per character (expressions are 2D stamps).
static func base_voxels(id: String) -> Dictionary:
	if not _base.has(id): _base[id] = SDModels.voxelize(solids(id))
	return _base[id]

## Single-view version of SpriteForge.render_sd (same light, dither, glint and outline rules).
static func render(vox: Dictionary, yaw: float = YAW, pitch: float = PITCH, cell: Vector2i = CELL) -> Image:
	var img := Image.create(cell.x, cell.y, false, Image.FORMAT_RGBA8)
	var cp := cos(pitch); var sp := sin(pitch)
	var view := Vector3(cp, 0, -sp)
	var light := Vector3(-0.45, -0.55, 0.75).normalized()
	var half := (light - view).normalized()
	var ox := cell.x / 2.0
	var oy := cell.y - 1.0
	var cy := cos(yaw); var sy := sin(yaw)
	var zb := PackedFloat32Array(); zb.resize(cell.x * cell.y); zb.fill(1e9)
	for v in vox:
		var m: int = vox[v][0]
		var n: Vector3 = vox[v][1]
		var p := Vector3(v) + Vector3(0.5, 0.5, 0.5)
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
				var flat: bool = m in FLAT
				var lv := clampi(int(floor(lit * 5.0 + (0.4 if flat else BAYER[(yy % 2) * 2 + (xx % 2)] * 0.4) + 0.2)), 0, 5)
				if m == P.SKIN: lv = clampi(lv, 2, 5)          # no muddy deep shadow on faces
				if m in GLOSSY and nr.dot(half) > 0.95: lv = 6
				img.set_pixel(xx, yy, Color8(m * 10, lv * 30, 0, 255))
	var solid := PackedByteArray(); solid.resize(cell.x * cell.y)
	for yy in cell.y:
		for xx in cell.x:
			solid[yy * cell.x + xx] = 1 if img.get_pixel(xx, yy).a > 0.5 else 0
	for yy in cell.y:
		for xx in cell.x:
			if solid[yy * cell.x + xx]: continue
			if (xx > 0 and solid[yy * cell.x + xx - 1]) or (xx < cell.x - 1 and solid[yy * cell.x + xx + 1]) \
					or (yy > 0 and solid[(yy - 1) * cell.x + xx]) or (yy < cell.y - 1 and solid[(yy + 1) * cell.x + xx]):
				img.set_pixel(xx, yy, Color8(0, 0, 0, 255))
	return img

## Index image -> final colours with the character's palette (glossy 7-step ramps, 15-bit snapped).
static func colorize(idx: Image, id: String) -> Image:
	var pal := palette(id)
	var out := Image.create(idx.get_width(), idx.get_height(), false, Image.FORMAT_RGBA8)
	var ramps := {}
	var outline := SpriteForge.snes(Color("#140c24"))
	for y in idx.get_height():
		for x in idx.get_width():
			var px := idx.get_pixel(x, y)
			if px.a < 0.5: continue
			var m := int(round(px.r8 / 10.0))
			if m == 0: out.set_pixel(x, y, outline); continue
			if not ramps.has(m):
				var base: Color = Color(pal.get(m, "#ff00ff"))
				if m == P.BROW: base = Color(pal[P.HAIR]).darkened(0.55)
				ramps[m] = SpriteForge.ramp7(base)
			out.set_pixel(x, y, ramps[m][clampi(int(round(px.g8 / 30.0)), 0, 7)])
	return out

static func bake(id: String, expr: String) -> Image:
	var img := colorize(render(base_voxels(id)), id)
	draw_face(img, id, expr)
	return img

static func path(id: String, expr: String) -> String:
	return "%s/%s_%s.png" % [DIR, id, expr]

static func has_expr(id: String, expr: String) -> bool:
	return CAST.has(id) and expr in CAST[id]

## Portrait texture: imported PNG, raw PNG on disk (fresh bake, not imported yet), or rendered now.
static func tex(id: String, expr: String = "neutral") -> Texture2D:
	if not CAST.has(id): return null
	if not has_expr(id, expr): expr = "neutral"
	var key := id + "_" + expr
	if _tex.has(key): return _tex[key]
	var t: Texture2D = null
	var p := path(id, expr)
	if ResourceLoader.exists(p):
		t = load(p)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(p)):
		t = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(p)))
	else:
		t = ImageTexture.create_from_image(bake(id, expr))
	_tex[key] = t
	return t

static func clear_cache() -> void:
	_tex.clear()
	_base.clear()
