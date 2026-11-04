class_name GarageView
extends Control
## Career home-screen art: the team garage as an animated SNES-style diorama (256x208), driven only by
## plain data from set_state(). Vehicles are the pre-rendered SD sheets (art/vehicles; bikes use the
## rider-less "parked" sheet art/garage/bikes.png), crew the pre-rendered chibi sheets (art/crew), all
## palette-swapped on the GPU by palette_swap.gdshader. Static scenery (walls, windows, props, floor,
## lighting) is baked into one texture when the state's look changes; per frame we only draw that
## texture, sprites and a handful of small effects.
##
## set_state({
##   ws: 1..4                     Backyard Shed, Town Garage, Race Workshop, Factory HQ
##   bays: [{kind, col, status: "ready"|"building"|"upgrading"|"repair", phase: 0..8, waiting: bool,
##           label, prog: 0..1 (optional: progress inside the current phase, drives the paint wipe)}]
##   crew: [{role: "drv"|"mech", col, name, busy_bay: int (-1 = free), skin?, hair?}]
##   season: 0 spring, 1 summer, 2 autumn, 3 winter      (see season_of_day())
##   tod: "day" | "night"
##   facilities: ["dyno", "wind"/"tunnel", "gym", "kitchen"/"lounge", "telemetry", "gearbench", ...]
##   team_col: optional banner colour (defaults to the first bay's / crew member's col)
## })
## Build phases (status "building"): 0 blueprint, 1-4 bare metal rising out of the blueprint,
## 5 paint going on (left to right, by `prog`), 6+ full paint (7 = shakedown jiggle).
## Signals: bay_tapped(index), crew_tapped(index) (indices into state.bays / state.crew).
## Don't modulate this node or its parents: the palette shader reads the draw colour as a row index.

signal bay_tapped(index: int)
signal crew_tapped(index: int)

const W := 256
const H := 208
const SLOTS := [2, 2, 4, 6, 10]          # bay slots per workshop level (index = ws)
const WS_NAME := ["", "THE SHED", "TOWN GARAGE", "RACE WORKSHOP", "FACTORY HQ"]
const SKINS := ["#f5d0a9", "#e0ac69", "#c68642", "#8d5524", "#ffdbac"]
const HAIRS := ["#2b1a12", "#5a3214", "#c08a3e", "#e8d07a", "#8a2be2", "#c0392b"]
const CAP_COL := "#e2b53a"
const WALK := 22.0                       # crew walk speed, px/s
const V_FOOT := 43                       # ground line inside a 48x48 vehicle cell
const OUTLINE := "#140c24"
const BIKES := ["scooter", "commuter", "naked", "cafe", "sport", "gp", "sidecar", "trail", "mx", "enduro", "flat", "smoto", "raid"]
const BIKE_FRAMES := [5, 11]             # 3/4 front facing right / left
const BIKES_PATH := "res://art/garage/bikes.png"
const CAT_PATH := "res://art/crew/cat.png"

# ---------------- state ----------------
var state := {}
var ws := 1
var season := 0
var night := false
var team_col := Color("#e8432f")
var bays: Array = []
var crew: Array = []
var facilities: Array = []
var t := 0.0

# ---------------- layout ----------------
var room := {}                 # x0, x1, top, base (floor starts), bottom (floor ends)
var slots: Array = []          # {x, w, cx, gy, row, right}
var lanes: Array = []          # y of the walkways
var idle_lanes: Array = []     # walkways where idle crew may loiter (not in front of name plates)
var spots := {}                # name -> [Vector2 feet, facing]
var actors: Array = []
var fx: Array = []             # particles

var _bg: ImageTexture
var _bg_key := ""
var _img: Image
var _clip := Rect2i(0, 0, W, H)
var _lut_rows := {}
var _lut_key := ""
var _glass: Array = []         # window glass rects (weather)
var _gaps: Array = []          # roller-door openings (weather)
var _tubes: Array = []         # Vector3(x, y, w) fluorescent tubes
var _fans: Array = []          # Vector3(cx, cy, r) wind tunnel fans
var _screens: Array = []       # Rect2 telemetry / dyno screens
var _cat := Vector2(-99, -99)
var _rng := RandomNumberGenerator.new()
var _emit := 0.0

static var _tex_cache := {}
static var _box_cache := {}

# ======================================================================================
# API
# ======================================================================================
func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 7
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/palette_swap.gdshader")
	material = m

func _ready() -> void:
	if state.is_empty():
		set_state({"ws": 1, "bays": [], "crew": []})

func set_state(s: Dictionary) -> void:
	state = s
	ws = clampi(int(s.get("ws", 1)), 1, 4)
	season = posmod(int(s.get("season", 0)), 4)
	night = str(s.get("tod", "day")) == "night"
	bays = s.get("bays", [])
	crew = s.get("crew", [])
	facilities = []
	for f in s.get("facilities", []): facilities.append(str(f))
	var tc = s.get("team_col", null)
	if tc == null:
		if bays.size(): tc = bays[0].get("col", "#e8432f")
		elif crew.size(): tc = crew[0].get("col", "#e8432f")
		else: tc = "#e8432f"
	team_col = _col(tc)
	_layout()
	var key := "%d|%d|%s|%s|%s|%d" % [ws, season, night, team_col.to_html(), ",".join(PackedStringArray(facilities)), slots.size()]
	if key != _bg_key:
		_bake_bg()
		_bg_key = key
	_build_lut()
	_sync_actors()
	queue_redraw()

## Map a career day to a season index (the year starts in April, 28-day months).
static func season_of_day(day: int) -> int:
	var mo := posmod(day, 336) / 28
	if mo <= 1 or mo == 11: return 0
	if mo <= 4: return 1
	if mo <= 7: return 2
	return 3

## What's under a point (local coords): {"kind": "crew"|"bay", "index": i} or {}.
func hit_test(p: Vector2) -> Dictionary:
	var order := actors.duplicate()
	order.sort_custom(func(a, b): return a.pos.y > b.pos.y)
	for a in order:
		var ap: Vector2 = a.pos
		if Rect2(ap.x - 6, ap.y - 21, 12, 23).has_point(p): return {"kind": "crew", "index": int(a.idx)}
	for i in range(mini(bays.size(), slots.size()) - 1, -1, -1):
		if _bay_rect(i).has_point(p): return {"kind": "bay", "index": i}
	return {}

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var h := hit_test(e.position)
		if h.is_empty(): return
		accept_event()
		if h.kind == "crew": crew_tapped.emit(h.index)
		else: bay_tapped.emit(h.index)

func _bay_rect(i: int) -> Rect2:
	var s: Dictionary = slots[i]
	return Rect2(s.x, s.gy - 40, s.w, 58)

# ======================================================================================
# layout
# ======================================================================================
static func room_of(level: int) -> Dictionary:
	match level:
		1: return {"x0": 48, "x1": 208, "top": 30, "base": 92, "bottom": 186}
		2: return {"x0": 12, "x1": 244, "top": 18, "base": 90, "bottom": 208}
		3: return {"x0": 0, "x1": 256, "top": 0, "base": 88, "bottom": 208}
	return {"x0": 0, "x1": 256, "top": 0, "base": 86, "bottom": 208}

func _layout() -> void:
	room = room_of(ws)
	var n: int = maxi(SLOTS[ws], bays.size())
	var rows := 1 if n <= 4 else 2
	var per := ceili(n / float(rows))
	var x0: int = room.x0 + 4
	var x1: int = room.x1 - 4
	var bw: int = mini(76, (x1 - x0) / per)
	var sx: int = x0 + ((x1 - x0) - bw * per) / 2
	var gys := [144 if ws == 1 else 148] if rows == 1 else [128, 180]
	slots.clear()
	for i in n:
		var r := i / per
		var c := i % per
		var cx: int = sx + c * bw + bw / 2
		slots.append({"x": sx + c * bw, "w": bw, "cx": cx, "gy": gys[r], "row": r, "right": cx <= W / 2})
	var base: int = room.base
	lanes = [base + 9]
	idle_lanes = [base + 9]
	for g in gys:
		if g + 22 <= room.bottom - 2: lanes.append(g + 22)
	if rows == 1 and room.bottom - 8 > gys[0] + 36:
		lanes.append(room.bottom - 8)
		idle_lanes.append(room.bottom - 8)

func _xmin() -> float: return room.x0 + 8.0
func _xmax() -> float: return room.x1 - 8.0

# ======================================================================================
# vehicles: sheets, frames, measured extents
# ======================================================================================
static func is_bike(kind: String) -> bool:
	return SDModels.spec(kind).t == "bike"

## [texture, source rect] of the parked vehicle for a bay facing right/left.
static func vehicle_frame(kind: String, right: bool) -> Array:
	if is_bike(kind):
		var bt := _bikes_tex(kind)
		var row := 0 if not _tex_cache.has("bikes_atlas") else BIKES.find(kind)
		return [bt, Rect2((0 if right else 1) * 48, maxi(0, row) * 48, 48, 48)]
	return [SpriteForge.vehicle_tex(kind), Rect2((6 if right else 10) * 48, 0, 48, 48)]

## Opaque extent of a vehicle frame inside its 48x48 cell (cached).
static func vehicle_box(kind: String, right: bool) -> Rect2i:
	var key := "%s:%s" % [kind, right]
	if _box_cache.has(key): return _box_cache[key]
	var vf := vehicle_frame(kind, right)
	var tex: Texture2D = vf[0]
	var img := tex.get_image()
	var r: Rect2 = vf[1]
	var box := img.get_region(Rect2i(r)).get_used_rect()
	if box.size == Vector2i.ZERO: box = Rect2i(4, 8, 40, 38)
	_box_cache[key] = box
	return box

## Rider-less bikes for the bays (the race sheets carry the rider). Atlas rows = BIKES, cols = BIKE_FRAMES.
static func _bikes_tex(kind: String) -> Texture2D:
	if _tex_cache.has("bikes_atlas"): return _tex_cache["bikes_atlas"]
	if ResourceLoader.exists(BIKES_PATH):
		_tex_cache["bikes_atlas"] = load(BIKES_PATH)
		return _tex_cache["bikes_atlas"]
	if FileAccess.file_exists(ProjectSettings.globalize_path(BIKES_PATH)):
		_tex_cache["bikes_atlas"] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(BIKES_PATH)))
		return _tex_cache["bikes_atlas"]
	var key := "bike:" + kind
	if not _tex_cache.has(key): _tex_cache[key] = ImageTexture.create_from_image(bake_parked_bike(kind))
	return _tex_cache[key]

static func bake_parked_bike(kind: String) -> Image:
	var sheet := SpriteForge.render_sd(SDModels.voxelize(parked_bike_parts(kind)), SDModels.rear_axle(kind), SpriteForge.FRAMES, SpriteForge.VCELL, 1)
	var out := Image.create(48 * BIKE_FRAMES.size(), 48, false, Image.FORMAT_RGBA8)
	for i in BIKE_FRAMES.size():
		out.blit_rect(sheet, Rect2i(BIKE_FRAMES[i] * 48, 0, 48, 48), Vector2i(i * 48, 0))
	return out

static func bake_parked_bikes() -> Image:
	var out := Image.create(48 * BIKE_FRAMES.size(), 48 * BIKES.size(), false, Image.FORMAT_RGBA8)
	for i in BIKES.size():
		var img := bake_parked_bike(BIKES[i])
		out.blit_rect(img, Rect2i(0, 0, img.get_width(), 48), Vector2i(0, i * 48))
	return out

## SDModels' bike without the rider (seat pad instead), for bikes parked on a stand.
static func parked_bike_parts(kind: String) -> Array:
	var M := SpriteForge.M
	var s := SDModels.spec(kind)
	var P := []
	var dirt: bool = s.get("dirt", false)
	var wf: float = s.get("wf", 5.0)
	var wr: float = s.get("wr", 6.0)
	var ax := 9.0
	for w in [[ax, wf], [-ax, wr]]:
		P.append(SDModels.cyl(Vector3(w[0], 0, w[1]), w[1], 2.0 if not dirt else 1.6, M.TIRE, 1.2))
		P.append(SDModels.cyl(Vector3(w[0], 0, w[1]), w[1] * 0.45, 2.2, M.METAL, 0.5))
	var seat := wr + (5.0 if dirt else 3.5)
	P.append(SDModels.ell(Vector3(-1, 0, seat), Vector3(6.5, 2.6, 2.6), M.TRIM))
	P.append(SDModels.ell(Vector3(3, 0, seat + 1.5), Vector3(4.5, 3.2, 2.8), M.BODY))
	P.append(SDModels.rbox(Vector3(-1, 0, wr + 0.5), Vector3(3.5, 2.6, 3), 1.2, M.METAL))
	P.append(SDModels.cap(Vector3(-4, 2.6, wr), Vector3(-12, 2.8, wr + 2), 1.1, M.METAL))
	P.append(SDModels.cap(Vector3(ax, 0, wf), Vector3(ax - 3, 0, seat + 4), 0.9, M.METAL))
	P.append(SDModels.cap(Vector3(ax - 3.5, -4, seat + 4.5), Vector3(ax - 3.5, 4, seat + 4.5), 0.7, M.TRIM))
	P.append(SDModels.ell(Vector3(ax - 1.5, 0, seat + 2.5), Vector3(1.2, 1.6, 1.6), M.LIGHT))
	P.append(SDModels.ell(Vector3(-ax + 1, 0, seat + 1), Vector3(1.0, 1.4, 1.0), M.RED))
	P.append(SDModels.ell(Vector3(-3, 0, seat + 1.6), Vector3(3.8, 2.4, 1.3), M.TRIM))                 # seat pad
	if s.get("fairing", false):
		P.append(SDModels.ell(Vector3(ax - 3, 0, seat + 2), Vector3(4, 3.6, 4.5), M.BODY))
		P.append(SDModels.ell(Vector3(ax - 3.5, 0, seat + 6), Vector3(2, 2.6, 1.8), M.GLASS))
		P.append(SDModels.ell(Vector3(-6, 0, seat + 1), Vector3(3.5, 2.6, 2), M.BODY))
	if s.get("cafe", false):
		P.append(SDModels.ell(Vector3(-5, 0, seat + 1.5), Vector3(3, 2.4, 1.8), M.BODY))
	if dirt:
		P.append(SDModels.rbox(Vector3(ax, 0, wf * 2 + 1.5), Vector3(4, 1.6, 0.6), 0.4, M.BODY))
		P.append(SDModels.rbox(Vector3(ax - 2, 0, seat + 3.5), Vector3(0.8, 3, 3), 0.6, M.PLATE))
		P.append(SDModels.rbox(Vector3(-ax + 1, 0, seat + 1), Vector3(4, 1.4, 0.6), 0.4, M.BODY))
	if s.get("scooter", false):
		P.append(SDModels.rbox(Vector3(0, 0, wr + 1), Vector3(7, 3, 3), 2.0, M.BODY))
	if s.get("sidecar", false):
		P.append(SDModels.ell(Vector3(0, 9, 6), Vector3(7, 3.5, 3.5), M.BODY))
		P.append(SDModels.cyl(Vector3(0, 11, 4), 4, 1.5, M.TIRE, 1.0))
		P.append(SDModels.ell(Vector3(1, 9, 9), Vector3(2.5, 2.6, 1.2), M.GLASS, true))
	return P

# ======================================================================================
# palette (one LUT row per paint job / person)
# ======================================================================================
func _row(key: String) -> int:
	return int(_lut_rows.get(key, 0))

func _build_lut() -> void:
	var specs := []
	_lut_rows.clear()
	var add := func(key: String, spec: Dictionary) -> void:
		if _lut_rows.has(key): return
		_lut_rows[key] = specs.size()
		specs.append(spec)
	var M := SpriteForge.M
	add.call("team:" + team_col.to_html(), {"base": team_col})
	add.call("blue", {"blue": true})
	add.call("grey", {"base": Color("#a4acb6"), "over": {
		M.GLASS: Color("#5a6470"), M.LIGHT: Color("#8a929c"), M.RED: Color("#8a929c"), M.PLATE: Color("#b8c0c8"),
		M.HELMET: Color("#b8c0c8"), M.ACCENT: Color("#8e96a0"), M.METAL: Color("#c4ccd4")}})
	add.call("cat", {"base": Color("#ec9a40"), "over": {M.TRUNK: Color("#b8602a"), M.WHITE: Color("#f8eedc"), M.RED: Color("#f08a9a")}})
	for b in bays:
		var c := _col(b.get("col", team_col))
		add.call("team:" + c.to_html(), {"base": c})
	for i in crew.size():
		var cr: Dictionary = crew[i]
		var h := absi(hash(str(cr.get("name", i))))
		var skin := _col(cr.get("skin", SKINS[h % SKINS.size()]))
		var hair := _col(cr.get("hair", HAIRS[(h / 7) % HAIRS.size()]))
		add.call("crew:%d" % i, {"base": _col(cr.get("col", team_col)), "over": {CrewModels.SKIN: skin, CrewModels.HAIR: hair,
			CrewModels.CAP: Color(CAP_COL)}})
	var key := str(specs)
	if key == _lut_key: return
	_lut_key = key
	var mats := M.size()
	var img := Image.create(mats * SpriteForge.LEVELS, specs.size(), false, Image.FORMAT_RGBA8)
	var outline := SpriteForge.snes(Color(OUTLINE))
	for r in specs.size():
		var sp: Dictionary = specs[r]
		for m in mats:
			for l in SpriteForge.LEVELS:
				var c2: Color
				if sp.has("blue"): c2 = _blueprint(m, l)
				elif m == 0: c2 = outline
				else:
					var over: Dictionary = sp.get("over", {})
					var base_c: Color = over.get(m, SpriteForge.mat_color(m, sp.base))
					c2 = SpriteForge.ramp7(base_c)[mini(l, 7)]
				img.set_pixel(m * SpriteForge.LEVELS + l, r, c2)
	(material as ShaderMaterial).set_shader_parameter("palette", ImageTexture.create_from_image(img))

## Blueprint "hologram": light outline, translucent blue fill banded by the shading level.
static func _blueprint(m: int, l: int) -> Color:
	if m == 0: return Color("#d8f4ff")
	if l >= 6: return Color(0.85, 0.95, 1.0, 0.85)
	if l >= 4: return Color(0.36, 0.62, 0.9, 0.5)
	if l >= 2: return Color(0.2, 0.44, 0.78, 0.42)
	return Color(0.13, 0.3, 0.62, 0.42)

# ======================================================================================
# crew
# ======================================================================================
func _sync_actors() -> void:
	var old := actors
	actors = []
	for i in crew.size():
		var c: Dictionary = crew[i]
		var role := "drv" if str(c.get("role", "mech")) == "drv" else "mech"
		var key := "%s|%s" % [role, str(c.get("name", i))]
		var a: Dictionary = {}
		for o in old:
			if o.key == key: a = o; break
		var fresh := a.is_empty()
		if fresh:
			a = {"key": key, "pos": Vector2.ZERO, "path": [], "face": 2, "mode": "idle", "timer": 0.0,
				"anim": _rng.randf() * 4.0, "goal": ""}
		a.idx = i
		a.role = role
		a.row = _row("crew:%d" % i)
		var bb := int(c.get("busy_bay", -1))
		a.busy = bb if bb >= 0 and bb < mini(bays.size(), slots.size()) else -1
		actors.append(a)
	# work spots: the k-th worker at a bay takes spot k
	var count := {}
	for a in actors:
		if a.busy < 0: continue
		a.spot_k = int(count.get(a.busy, 0))
		count[a.busy] = a.spot_k + 1
	for a in actors:
		if a.busy >= 0:
			var goal := "work:%d:%d" % [a.busy, a.spot_k]
			if a.goal != goal:
				if a.pos == Vector2.ZERO: _snap_to(a, _work_spot(a.busy, a.spot_k))
				else: _go(a, _work_spot(a.busy, a.spot_k), goal)
				a.goal = goal
		elif a.pos == Vector2.ZERO:
			var sp := _pick_idle(a)
			a.pos = sp[0]; a.face = sp[1]; a.goal = sp[2]
			a.mode = "idle"; a.timer = _rng.randf_range(0.5, 3.5)
		elif str(a.goal).begins_with("work:"):
			a.goal = ""; a.mode = "idle"; a.timer = 0.3

func _snap_to(a: Dictionary, sp: Array) -> void:
	a.pos = sp[0]; a.face = sp[1]; a.path = []; a.mode = "work"

## [feet, facing] for the k-th worker at bay i: either side of the vehicle, then behind it
## (spots that would fall outside the room go last).
func _work_spot(i: int, k: int) -> Array:
	var s: Dictionary = slots[i]
	var box := vehicle_box(str(bays[i].get("kind", "hatch")), s.right)
	var l: float = s.cx - 24 + box.position.x
	var r: float = s.cx - 24 + box.end.x
	var gy: float = s.gy
	var all := [[Vector2(l - 3, gy + 1), 1], [Vector2(r + 3, gy + 1), 3], [Vector2(l + 4, gy - 6), 1], [Vector2(r - 4, gy - 6), 3]]
	var ok := []
	var bad := []
	for sp in all:
		var x: float = sp[0].x
		if x < room.x0 + 7 or x > room.x1 - 7: bad.append(sp)
		else: ok.append(sp)
	var order: Array = ok + bad
	return order[k % order.size()]

## A free idle target: [feet, facing, goal key], away from where the others stand or are heading.
func _pick_idle(a: Dictionary) -> Array:
	var taken := {}
	var near := []
	for o in actors:
		if o == a: continue
		taken[o.goal] = true
		near.append(o.pos)
		if o.path.size(): near.append(o.path[o.path.size() - 1])
	var opts := []
	for k in spots.keys():
		if not taken.has(k) and _free(spots[k][0], near): opts.append(k)
	if a.role == "drv":
		for i in mini(bays.size(), slots.size()):
			var key := "admire:%d" % i
			if str(bays[i].get("status", "ready")) == "ready" and not taken.has(key) and _free(_admire_spot(i)[0], near): opts.append(key)
	if opts.is_empty() or _rng.randf() < 0.3:
		for tries in 8:
			var lane: float = idle_lanes[_rng.randi() % idle_lanes.size()]
			var p := Vector2(roundf(_rng.randf_range(_xmin(), _xmax())), lane)
			if _free(p, near) or tries == 7:
				return [p, 2 if _rng.randf() < 0.6 else (1 if _rng.randf() < 0.5 else 3), "lane"]
	var pick: String = opts[_rng.randi() % opts.size()]
	if pick.begins_with("admire:"):
		var sp2 := _admire_spot(int(pick.substr(7)))
		return [sp2[0], sp2[1], pick]
	var sp: Array = spots[pick]
	return [sp[0], sp[1], pick]

func _admire_spot(i: int) -> Array:
	return _work_spot(i, 1 if slots[i].right else 0)

static func _free(p: Vector2, near: Array) -> bool:
	for q in near:
		if absf(q.x - p.x) < 11.0 and absf(q.y - p.y) < 8.0: return false
	return true

func _go(a: Dictionary, sp: Array, goal: String) -> void:
	a.path = _route(a.pos, sp[0])
	a.end_face = sp[1]
	a.goal = goal
	a.mode = "walk"

func _nearest_lane(y: float) -> float:
	var best: float = lanes[0]
	for l in lanes:
		if absf(l - y) < absf(best - y): best = l
	return best

## Manhattan route along the walkways, crossing bay rows only in the gaps between bays.
func _route(from: Vector2, to: Vector2) -> Array:
	var pts := []
	var la := _nearest_lane(from.y)
	var lb := _nearest_lane(to.y)
	if absf(from.y - la) > 0.5: pts.append(Vector2(from.x, la))
	if absf(la - lb) > 0.5:
		var mid := (from.x + to.x) * 0.5
		var gx := _xmin()
		for s in slots:
			for x in [float(s.x), float(s.x + s.w)]:
				if x >= _xmin() and x <= _xmax() and absf(x - mid) < absf(gx - mid): gx = x
		pts.append(Vector2(gx, la))
		pts.append(Vector2(gx, lb))
	pts.append(Vector2(to.x, lb))
	pts.append(to)
	return pts

func _update_actor(a: Dictionary, dt: float) -> void:
	a.anim += dt
	match a.mode:
		"walk":
			var step := WALK * dt
			while step > 0.0 and a.path.size():
				var tgt: Vector2 = a.path[0]
				var d: Vector2 = tgt - a.pos
				if d.length() <= step:
					a.pos = tgt; step -= d.length(); a.path.pop_front()
				else:
					a.pos += d.normalized() * step; step = 0.0
					a.face = (1 if d.x > 0 else 3) if absf(d.x) >= absf(d.y) else (2 if d.y > 0 else 0)
			if a.path.is_empty():
				a.face = a.get("end_face", 2)
				if str(a.goal).begins_with("work:"): a.mode = "work"
				else:
					a.mode = "idle"; a.timer = _rng.randf_range(2.0, 5.0)
		"idle":
			a.timer -= dt
			if a.timer <= 0.0:
				var sp := _pick_idle(a)
				_go(a, [sp[0], sp[1]], sp[2])

# ======================================================================================
# frame update
# ======================================================================================
func _process(dt: float) -> void:
	if not is_visible_in_tree(): return
	t += dt
	for a in actors: _update_actor(a, dt)
	_update_fx(dt)
	queue_redraw()

func _update_fx(dt: float) -> void:
	var keep := []
	for p in fx:
		p.life -= dt
		if p.life <= 0.0: continue
		p.v.y += p.g * dt
		p.p += p.v * dt
		keep.append(p)
	fx = keep
	_emit += dt
	if _emit < 0.05: return
	_emit = 0.0
	if fx.size() > 90: return
	# welding sparks / spray mist / tool glints from busy mechanics
	for a in actors:
		if a.mode != "work" or a.busy < 0 or a.role != "mech": continue
		var b: Dictionary = bays[a.busy]
		var st := str(b.get("status", "ready"))
		var ph := int(b.get("phase", 8))
		var hand: Vector2 = a.pos + Vector2(6 if a.face == 1 else (-6 if a.face == 3 else 0), -9)
		if st == "building" and ph >= 1 and ph <= 4:
			if _rng.randf() < 0.5:
				for k in _rng.randi_range(1, 3):
					_spark(hand, Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-40, -10)), "spark")
		elif st == "building" and ph == 5:
			if _rng.randf() < 0.5:
				_spark(hand + Vector2(0, -2), Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-10, -3)), "mist", 0.6, _col(b.get("col", team_col)))
		elif _rng.randf() < 0.12:
			_spark(hand, Vector2.ZERO, "flash", 0.1)
	# smoke from bays under repair
	for i in mini(bays.size(), slots.size()):
		if str(bays[i].get("status", "")) == "repair" and _rng.randf() < 0.12:
			var s: Dictionary = slots[i]
			_spark(Vector2(s.cx + _rng.randf_range(-8, 8), s.gy - 24), Vector2(_rng.randf_range(-3, 3), -9), "smoke", 1.4)

func _spark(p: Vector2, v: Vector2, kind: String, life := 0.45, c := Color.WHITE) -> void:
	fx.append({"p": p, "v": v, "kind": kind, "life": life, "max": life, "g": 90.0 if kind == "spark" else 0.0, "c": c})

# ======================================================================================
# draw
# ======================================================================================
func _draw() -> void:
	if _bg == null: return
	draw_texture(_bg, Vector2.ZERO)
	_draw_ambient()
	var items := []
	for i in slots.size():
		items.append([float(slots[i].gy), 0, i])
		if i < bays.size(): items.append([float(slots[i].gy) + 12.0, 2, i])    # name plate on the lift's front face
	for a in actors: items.append([a.pos.y + 0.5, 1, a])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			0: _draw_bay(it[2])
			1: _draw_actor(it[2])
			2: _draw_plate(it[2])
	_draw_fx()
	for i in mini(bays.size(), slots.size()):
		if bays[i].get("waiting", false): _draw_ask(i)

# ---------------- ambient ----------------
func _draw_ambient() -> void:
	for r in _glass + _gaps: _draw_weather(r)
	# fluorescent tubes (the first one flickers now and then)
	for i in _tubes.size():
		var tb: Vector3 = _tubes[i]
		var on := true
		if i == 0:
			var ph := fmod(t, 6.7)
			on = not ((ph > 4.0 and ph < 4.08) or (ph > 4.16 and ph < 4.22) or (ph > 4.3 and ph < 4.55))
		draw_rect(Rect2(tb.x, tb.y, tb.z, 1), Color("#f4fbff") if on else Color("#6d7784"))
		if on: draw_rect(Rect2(tb.x - 2, tb.y + 1, tb.z + 4, 2), Color(1.0, 1.0, 0.9, 0.14))
	# wind tunnel fan
	for f in _fans:
		var ang := t * 9.0
		for k in 3:
			var d := Vector2.from_angle(ang + k * TAU / 3.0)
			for s in range(2, int(f.z)):
				draw_rect(Rect2((Vector2(f.x, f.y) + d * s).floor(), Vector2(1, 1)), Color("#c8d0d8"))
		draw_rect(Rect2(f.x - 1, f.y - 1, 3, 3), Color("#5a6470"))
	# live screens
	for r in _screens:
		var n := int(r.size.x) - 2
		for x in n:
			var y: float = r.position.y + r.size.y * 0.5 + sin(x * 0.8 + t * 4.0 + r.position.x) * (r.size.y * 0.3)
			draw_rect(Rect2(r.position.x + 1 + x, roundf(y), 1, 1), Color("#7ff0a0"))
	if _cat.x > 0: _draw_cat()

func _draw_weather(r: Rect2) -> void:
	var area := r.size.x * r.size.y
	match season:
		0:   # spring showers
			for i in int(area / 90.0) + 2:
				var x := fposmod(i * 7.3 + t * 8.0, r.size.x)
				var y := fposmod(i * 11.7 + t * 90.0, r.size.y + 3) - 3
				var h := minf(3.0, r.size.y - y)
				if y >= 0 and h > 0: draw_rect(Rect2(r.position.x + floorf(x), r.position.y + floorf(y), 1, h), Color(0.85, 0.92, 1.0, 0.7))
		2:   # autumn leaves
			for i in int(area / 220.0) + 1:
				var x := fposmod(i * 13.1 + t * 7.0 + sin(t * 2.0 + i) * 3.0, r.size.x - 1)
				var y := fposmod(i * 9.7 + t * 11.0, r.size.y - 1)
				draw_rect(Rect2(r.position.x + floorf(x), r.position.y + floorf(y), 2 if int(t * 4 + i) % 2 else 1, 1),
					Color("#e0782a") if i % 2 else Color("#c84a22"))
		3:   # snow
			for i in int(area / 110.0) + 2:
				var x := fposmod(i * 7.9 + sin(t * 1.3 + i) * 2.0, r.size.x)
				var y := fposmod(i * 5.3 + t * 9.0, r.size.y)
				draw_rect(Rect2(r.position.x + floorf(x), r.position.y + floorf(y), 1, 1), Color("#ffffff"))

func _draw_cat() -> void:
	var tex := _cat_tex()
	var fr := 1 if fmod(t, 2.6) < 1.3 else 0
	draw_texture_rect_region(tex, Rect2(_cat.x - 12, _cat.y - 19, 24, 24), Rect2(24 * fr, 0, 24, 24), SpriteForge.row_color(_row("cat")))
	var zt := fmod(t, 3.0)
	if zt < 2.2:
		var k := zt / 2.2
		var zp := (_cat + Vector2(-10 - k * 3.0, -13 - k * 7.0)).round()
		draw_texture(_text_tex("z", Color(0.08, 0.05, 0.14, 0.6 * (1.0 - k))), zp + Vector2(1, 1))
		draw_texture(_text_tex("z", Color(1, 1, 1, 1.0 - k * 0.7)), zp)

# ---------------- bays ----------------
func _draw_bay(i: int) -> void:
	var s: Dictionary = slots[i]
	var has := i < bays.size()
	var b: Dictionary = bays[i] if has else {}
	var kind := str(b.get("kind", "hatch"))
	var st := str(b.get("status", "ready"))
	var ph := int(b.get("phase", 8))
	var cx: float = s.cx
	var gy: float = s.gy
	var box := vehicle_box(kind, s.right) if has else Rect2i(6, 10, 36, 36)
	var hw := maxf(14.0, maxf(24.0 - box.position.x, box.end.x - 24.0) + 2.0)
	var lift := _lift_of(b) if has else 0.0
	var ground := _draw_lift(cx, gy, lift, hw, has)
	if not has: return
	if st == "building" and ph == 7 and int(t * 16) % 2 == 0: ground -= 1.0     # shakedown: engine running
	# contact shadow
	draw_rect(Rect2(cx - hw + 5, ground - 3, hw * 2 - 10, 3), Color(0.04, 0.02, 0.1, 0.3))
	var vf := vehicle_frame(kind, s.right)
	var tex: Texture2D = vf[0]
	var src: Rect2 = vf[1]
	var pos := Vector2(cx - 24, ground - V_FOOT).round()
	var team := SpriteForge.row_color(_row("team:" + _col(b.get("col", team_col)).to_html()))
	var grey := SpriteForge.row_color(_row("grey"))
	var blue := SpriteForge.row_color(_row("blue"))
	if st == "building" and ph <= 0:
		_draw_blueprint_mat(cx, gy, hw)
		draw_texture_rect_region(tex, Rect2(pos, Vector2(48, 48)), src, blue)
		var sy := float(box.position.y) + fmod(t * 12.0, float(box.size.y))
		draw_rect(Rect2(pos.x + box.position.x, pos.y + sy, box.size.x, 1), Color(0.75, 0.92, 1.0, 0.4))
	elif st == "building" and ph <= 4:
		# bare metal rises out of the blueprint, chassis first
		var frac: float = [0.0, 0.4, 0.6, 0.8, 1.0][ph]
		var cut := int(round(box.end.y - box.size.y * frac))
		draw_texture_rect_region(tex, Rect2(pos, Vector2(48, cut)), Rect2(src.position, Vector2(48, cut)), blue)
		draw_texture_rect_region(tex, Rect2(pos + Vector2(0, cut), Vector2(48, 48 - cut)), Rect2(src.position + Vector2(0, cut), Vector2(48, 48 - cut)), grey)
		if ph < 4: draw_rect(Rect2(pos.x + box.position.x + 1, pos.y + cut, box.size.x - 2, 1), Color(1.0, 0.92, 0.5, 0.5 + 0.3 * sin(t * 10.0)))
	elif st == "building" and ph == 5:
		var pr := clampf(float(b.get("prog", 0.5)), 0.0, 1.0)
		var wipe := int(round(box.position.x + box.size.x * pr))
		draw_texture_rect_region(tex, Rect2(pos, Vector2(48, 48)), src, grey)
		draw_texture_rect_region(tex, Rect2(pos, Vector2(wipe, 48)), Rect2(src.position, Vector2(wipe, 48)), team)
		var ey := pos.y + box.position.y + box.size.y * 0.5 + sin(t * 9.0) * box.size.y * 0.3
		if int(t * 10) % 2 == 0: draw_rect(Rect2(pos.x + wipe - 1, roundf(ey), 2, 2), Color("#eef4fa"))
	else:
		draw_texture_rect_region(tex, Rect2(pos, Vector2(48, 48)), src, team)
		if st == "ready": _draw_glint(i, pos, box)
	if st == "building" and ph >= 1 and ph <= 7: _draw_tool_flash(i, pos, box)

## How far a bay's lift / stands are raised.
static func _lift_of(b: Dictionary) -> float:
	var st := str(b.get("status", "ready"))
	var ph := int(b.get("phase", 8))
	if st == "upgrading" or st == "repair": return 7.0
	if st == "building" and ph >= 1 and ph <= 4: return 3.0
	return 0.0

## Lift / stand under a bay; returns the y the vehicle stands on.
func _draw_lift(cx: float, gy: float, lift: float, hw: float, has: bool) -> float:
	var out := Color(OUTLINE)
	if ws == 1:
		# backyard: old plywood under the wheels, red jack stands when it's up
		if not has: return gy
		if lift > 0.0:
			for sx in [-hw + 7, hw - 10]:
				draw_rect(Rect2(cx + sx - 1, gy - lift - 1, 5, lift + 2), out)
				draw_rect(Rect2(cx + sx, gy - lift, 3, lift + 1), Color("#d8402e"))
				draw_rect(Rect2(cx + sx, gy - lift, 1, lift + 1), Color("#f07a5a"))
				draw_rect(Rect2(cx + sx - 2, gy, 7, 2), Color("#7f1d12"))
		else:
			draw_rect(Rect2(cx - hw + 2, gy - 6, hw * 2 - 4, 8), Color("#7a5a36"))
			draw_rect(Rect2(cx - hw + 3, gy - 5, hw * 2 - 6, 6), Color("#a07a48"))
			draw_rect(Rect2(cx - hw + 3, gy - 5, hw * 2 - 6, 1), Color("#b8945c"))
		return gy - lift
	var top_c: Color
	var face_c: Color
	match ws:
		2:
			top_c = Color("#7c8a98"); face_c = Color("#3a6ab0")
		3:
			top_c = Color("#8a929c"); face_c = Color("#e8b830")
		_:
			top_c = Color("#e4e8ee"); face_c = Color("#9aa2ad")
	var y := gy - 1.0 - lift
	if lift > 0.0:
		# hydraulic base + scissor arms
		draw_rect(Rect2(cx - hw + 5, gy - 1, hw * 2 - 10, 3), out)
		draw_rect(Rect2(cx - hw + 6, gy - 1, hw * 2 - 12, 2), Color("#4a4e58"))
		var span := hw * 1.1
		for k in int(lift) + 1:
			var f := k / maxf(1.0, lift)
			var yy := y + 3 + k
			draw_rect(Rect2(roundf(cx - span * 0.5 + f * span), yy, 2, 1), Color("#2a2a30"))
			draw_rect(Rect2(roundf(cx + span * 0.5 - f * span) - 1, yy, 2, 1), Color("#5a606c"))
	# deck (top face) + front face
	draw_rect(Rect2(cx - hw - 1, y - 8, hw * 2 + 2, 13), out)
	draw_rect(Rect2(cx - hw, y - 7, hw * 2, 7), top_c.darkened(0.08))
	draw_rect(Rect2(cx - hw, y - 7, hw * 2, 1), top_c.lightened(0.18))
	for k in range(3, int(hw * 2) - 2, 4):
		draw_rect(Rect2(cx - hw + k, y - 5 + (k / 4) % 2 * 2, 1, 1), top_c.darkened(0.25))
	draw_rect(Rect2(cx - hw, y, hw * 2, 4), face_c)
	draw_rect(Rect2(cx - hw, y, hw * 2, 1), face_c.lightened(0.25))
	match ws:
		2:
			for bx in [cx - hw + 2, cx + hw - 3]: draw_rect(Rect2(bx, y + 2, 1, 1), Color("#c4ccd4"))
		3:
			for k in range(0, int(hw * 2), 6):
				draw_rect(Rect2(cx - hw + k, y + 1, 3, 3), Color("#2a2a30"))
		_:
			draw_rect(Rect2(cx - hw + 3, y + 2, hw * 2 - 6, 1), SpriteForge.snes(team_col.lightened(0.25)) if has else Color("#6a7480"))
	return y - 3.0

func _draw_blueprint_mat(cx: float, gy: float, hw: float) -> void:
	var r := Rect2(cx - hw - 2, gy - 11, hw * 2 + 4, 14)
	draw_rect(r, Color(0.16, 0.36, 0.72, 0.55))
	for x in range(2, int(r.size.x), 6): draw_rect(Rect2(r.position.x + x, r.position.y, 1, r.size.y), Color(0.55, 0.78, 1.0, 0.25))
	for y in range(2, int(r.size.y), 4): draw_rect(Rect2(r.position.x, r.position.y + y, r.size.x, 1), Color(0.55, 0.78, 1.0, 0.25))
	# dimension line
	var c := Color("#bfe6ff")
	draw_rect(Rect2(r.position.x + 2, gy + 6, r.size.x - 4, 1), c)
	draw_rect(Rect2(r.position.x + 2, gy + 5, 1, 3), c)
	draw_rect(Rect2(r.end.x - 3, gy + 5, 1, 3), c)

func _draw_glint(i: int, pos: Vector2, box: Rect2i) -> void:
	var ph := fmod(t + i * 1.37, 4.0)
	if ph > 0.45: return
	var k := ph / 0.45
	var p := pos + Vector2(box.position.x + 4 + k * (box.size.x - 8), box.position.y + 6 + k * 3).round()
	var c := Color(1, 1, 1, 0.9)
	draw_rect(Rect2(p.x, p.y - 2, 1, 5), c)
	draw_rect(Rect2(p.x - 2, p.y, 5, 1), c)

func _draw_tool_flash(i: int, pos: Vector2, box: Rect2i) -> void:
	var n := int(t * 6.0)
	var h := absi(hash(Vector2i(i, n)))
	if h % 3 != 0: return
	var p := pos + Vector2(box.position.x + 4 + h % maxi(1, box.size.x - 8), box.position.y + 6 + (h / 64) % maxi(1, box.size.y - 12))
	var c := Color("#fff7c0") if (h / 5) % 2 else Color("#bfe6ff")
	draw_rect(Rect2(p.x, p.y - 1, 1, 3), c)
	draw_rect(Rect2(p.x - 1, p.y, 3, 1), c)

func _draw_plate(i: int) -> void:
	var s: Dictionary = slots[i]
	var b: Dictionary = bays[i]
	var st := str(b.get("status", "ready"))
	var ph := int(b.get("phase", 8))
	var label := str(b.get("label", "")).to_upper()
	var maxc := maxi(3, (int(s.w) - 10) / 4)
	if label.length() > maxc: label = label.substr(0, maxc).strip_edges()
	var tt := _text_tex(label, Color("#f2f2ee"))
	var pw := tt.get_width() + 9
	var building := st == "building"
	var phh := 11 if building else 9
	var x := roundf(float(s.cx) - pw / 2.0)
	var y: float = s.gy + (1 if ws >= 2 else 3)
	draw_rect(Rect2(x, y, pw, phh), Color(OUTLINE))
	draw_rect(Rect2(x + 1, y + 1, pw - 2, phh - 2), Color("#24305a"))
	draw_rect(Rect2(x + 1, y + 1, pw - 2, 1), Color("#3a4a80"))
	var dot := Color("#3fd34a")
	match st:
		"building": dot = Color("#ffb020")
		"upgrading": dot = Color("#4ab0ff")
		"repair": dot = Color("#ff4a3a")
	if st != "ready" and int(t * 3) % 2 == 0: dot = dot.darkened(0.4)
	draw_rect(Rect2(x + 2, y + 2, 2, 5), dot)
	draw_texture(tt, Vector2(x + 6, y + 2))
	if building:
		var bx := x + 2
		var bw := pw - 4
		for k in 8:
			var x0 := bx + floorf(k * bw / 8.0)
			var x1 := bx + floorf((k + 1) * bw / 8.0) - 1
			draw_rect(Rect2(x0, y + 8, maxf(1.0, x1 - x0), 1), Color("#ffb020") if k < ph else Color("#4a5478"))

func _draw_ask(i: int) -> void:
	var s: Dictionary = slots[i]
	var box := vehicle_box(str(bays[i].get("kind", "hatch")), s.right)
	var ground: float = s.gy - _lift_of(bays[i]) - (4.0 if ws >= 2 else 0.0)
	var top := ground - V_FOOT + box.position.y
	var x := clampf(s.cx - 24 + box.end.x - 8, 1, W - 13)
	draw_texture(_ask_tex(), Vector2(roundf(x), top - 10 + roundf(sin(t * 4.0) * 1.5)))

# ---------------- crew ----------------
func _draw_actor(a: Dictionary) -> void:
	var pose := "stand"
	var bob := 0.0
	match a.mode:
		"walk":
			var f := int(a.anim * 8.0) % 4
			pose = ["walk_a", "stand", "walk_b", "stand"][f]
			bob = -1.0 if f % 2 == 1 else 0.0
		"work":
			if a.role == "mech": pose = "work_a" if int(a.anim * 4.0) % 2 == 0 else "work_b"
			else: pose = "work_b" if fmod(a.anim, 3.0) < 0.6 else "stand"
	var p: Vector2 = a.pos.round()
	draw_rect(Rect2(p.x - 4, p.y - 1, 9, 2), Color(0.04, 0.02, 0.1, 0.3))
	var tex := CrewModels.tex(a.role)
	var src := CrewModels.frame_rect(pose, int(a.face))
	draw_texture_rect_region(tex, Rect2(p.x - CrewModels.CELL.x / 2, p.y - CrewModels.FOOT_Y + bob, CrewModels.CELL.x, CrewModels.CELL.y), src,
		SpriteForge.row_color(int(a.row)))

func _draw_fx() -> void:
	for p in fx:
		var k: float = p.life / p.max
		match p.kind:
			"spark":
				draw_rect(Rect2(p.p.round(), Vector2(1, 1)), Color("#fff7a0") if k > 0.5 else Color("#ff9a2a"))
			"mist":
				var c: Color = p.c
				draw_rect(Rect2(p.p.round(), Vector2(2, 2)), Color(c.r, c.g, c.b, 0.55 * k))
			"smoke":
				var sz := 2.0 + (1.0 - k) * 3.0
				draw_rect(Rect2((p.p - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz).round()), Color(0.3, 0.3, 0.36, 0.7 * k))
			"flash":
				var c2 := Color(1, 1, 0.85, k)
				draw_rect(Rect2(p.p.x, p.p.y - 1, 1, 3), c2)
				draw_rect(Rect2(p.p.x - 1, p.p.y, 3, 1), c2)

# ======================================================================================
# small baked textures: tiny font, "?" bubble, cat
# ======================================================================================
const GLYPHS := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
	"2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
	"6": "011100110101010", "7": "111001010010010", "8": "010101010101010", "9": "010101011001110",
	"-": "000000111000000", ".": "000000000000010", "'": "010010000000000", "!": "010010010000010",
	"?": "110001010000010", "/": "001001010100100", "#": "101111101111101", "+": "000010111010000",
	":": "000010000010000", "&": "010101010101011", "z": "000111001010111", " ": "000000000000000",
}

## 3x5 pixel font baked to a texture (cached per string + colour).
static func _text_tex(text: String, c: Color) -> ImageTexture:
	var key := "txt:%s:%s" % [text, c.to_html()]
	if _tex_cache.has(key): return _tex_cache[key]
	var w := maxi(1, text.length() * 4 - 1)
	var img := Image.create(w, 5, false, Image.FORMAT_RGBA8)
	for i in text.length():
		var g: String = GLYPHS.get(text[i], GLYPHS["?"])
		for k in 15:
			if g[k] == "1": img.set_pixel(i * 4 + k % 3, k / 3, c)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

static func _ask_tex() -> ImageTexture:
	if _tex_cache.has("ask"): return _tex_cache["ask"]
	var rows := [
		"..kkkkkkkk..",
		".kwwwwwwwwk.",
		"kwwwkkkkwwwk",
		"kwwkyyyykwwk",
		"kwwkykkyykwk",
		"kwwwkkkyykwk",
		"kwwwwkyykwwk",
		"kwwwwkyykwwk",
		"kwwwwwkkwwwk",
		"kwwwwkyykwwk",
		".kwwwkkkkwk.",
		"..kkkwwkkk..",
		"....kwk.....",
		"....kk......",
	]
	var tex := ImageTexture.create_from_image(_pix(rows, {"k": Color(OUTLINE), "w": Color("#fff8e0"), "y": Color("#e8432f")}))
	_tex_cache["ask"] = tex
	return tex

static func _pix(rows: Array, pal: Dictionary) -> Image:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if pal.has(r[x]): img.set_pixel(x, y, SpriteForge.snes(pal[r[x]]))
	return img

## The garage cat: an SD model like everything else, 2 breathing frames ("cat" palette row).
static func _cat_tex() -> Texture2D:
	if _tex_cache.has("cat"): return _tex_cache["cat"]
	var t2: Texture2D
	if ResourceLoader.exists(CAT_PATH): t2 = load(CAT_PATH)
	elif FileAccess.file_exists(ProjectSettings.globalize_path(CAT_PATH)):
		t2 = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(CAT_PATH)))
	else: t2 = ImageTexture.create_from_image(bake_cat())
	_tex_cache["cat"] = t2
	return t2

## Curled-up sleeping cat (x forward = head), orange tabby with a white muzzle and chest.
static func cat_parts(breath: float) -> Array:
	var M := SpriteForge.M
	var P := []
	P.append(SDModels.ell(Vector3(-1.2, 0, 3.0), Vector3(6.0, 3.9 + breath * 0.3, 3.0 + breath * 0.5), M.SUIT))   # loaf
	P.append(SDModels.ell(Vector3(5.4, 0, 4.9), Vector3(3.2, 3.3, 3.0), M.SUIT))                                 # head
	for side in [-1.0, 1.0]:
		P.append(SDModels.ell(Vector3(4.9, side * 1.8, 7.8), Vector3(1.4, 1.0, 1.5), M.SUIT))                    # ears
		P.append(SDModels.ell(Vector3(4.9, side * 2.0, 9.0), Vector3(0.7, 0.6, 1.0), M.SUIT))
		P.append(SDModels.rbox(Vector3(8.2, side * 1.3, 5.6), Vector3(0.6, 0.8, 0.3), 0.1, M.TIRE, true))        # closed eyes
	P.append(SDModels.ell(Vector3(8.3, 0, 4.0), Vector3(1.5, 2.3, 1.4), M.WHITE, true))                          # muzzle
	P.append(SDModels.ell(Vector3(8.8, 0, 4.6), Vector3(0.6, 0.7, 0.5), M.RED, true))                            # nose
	P.append(SDModels.ell(Vector3(4.4, 0, 1.4), Vector3(2.2, 3.6, 1.6), M.WHITE, true))                          # chest
	P.append(SDModels.cap(Vector3(-6.6, 1.5, 1.4), Vector3(-3.6, -4.2, 1.2), 1.25, M.SUIT))                     # tail...
	P.append(SDModels.cap(Vector3(-3.6, -4.2, 1.2), Vector3(2.6, -4.5, 1.2), 1.25, M.SUIT))                     # ...round the front
	P.append(SDModels.ell(Vector3(2.6, -4.5, 1.2), Vector3(1.6, 1.6, 1.6), M.TRUNK, true))                      # tail tip
	for k in 3:
		P.append(SDModels.rbox(Vector3(-5.2 + k * 2.4, 0, 7), Vector3(0.5, 7, 3.4), 0.1, M.TRUNK, true))        # tabby stripes
	return P

const CAT_FRAME := 12     # side-on, facing left

static func bake_cat() -> Image:
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	for k in 2:
		var strip := SpriteForge.render_sd(SDModels.voxelize(cat_parts(float(k))), Vector2.ZERO, 16, Vector2i(24, 24), 1, SpriteForge.PITCH)
		img.blit_rect(strip, Rect2i(CAT_FRAME * 24, 0, 24, 24), Vector2i(k * 24, 0))
	return img

# ======================================================================================
# background bake
# ======================================================================================
static func _hx(h: String) -> Color:
	return SpriteForge.snes(Color(h))

static func _col(v) -> Color:
	if v is Color: return v
	return Color(str(v))

func _r(x: int, y: int, w: int, h: int, c: Color) -> void:
	if w <= 0 or h <= 0: return
	var rr := Rect2i(x, y, w, h).intersection(_clip)
	if rr.size.x > 0 and rr.size.y > 0: _img.fill_rect(rr, c)

func _p(x: int, y: int, c: Color) -> void:
	if _clip.has_point(Vector2i(x, y)): _img.set_pixel(x, y, c)

## 50% checker dither of c over the area.
func _dith(x: int, y: int, w: int, h: int, c: Color, ph := 0) -> void:
	if w <= 0 or h <= 0: return
	var rr := Rect2i(x, y, w, h).intersection(_clip)
	for yy in range(rr.position.y, rr.end.y):
		for xx in range(rr.position.x, rr.end.x):
			if (xx + yy + ph) & 1 == 0: _img.set_pixel(xx, yy, c)

## Blend the area toward c by a (snapped back to 15-bit).
func _tint(x: int, y: int, w: int, h: int, c: Color, a: float) -> void:
	if w <= 0 or h <= 0: return
	var rr := Rect2i(x, y, w, h).intersection(_clip)
	for yy in range(rr.position.y, rr.end.y):
		for xx in range(rr.position.x, rr.end.x):
			_img.set_pixel(xx, yy, SpriteForge.snes(_img.get_pixel(xx, yy).lerp(c, a)))

func _ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for xx in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var d := pow((xx + 0.5 - cx) / rx, 2) + pow((yy + 0.5 - cy) / ry, 2)
			if d <= 1.0: _p(xx, yy, c)

## Soft (dithered-edge) tint inside an ellipse: light pools, stains.
func _tint_ell(cx: float, cy: float, rx: float, ry: float, c: Color, a: float) -> void:
	for yy in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for xx in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var d := pow((xx + 0.5 - cx) / rx, 2) + pow((yy + 0.5 - cy) / ry, 2)
			if d > 1.0 or not _clip.has_point(Vector2i(xx, yy)): continue
			var aa := a if d < 0.6 else (a * 0.5 if (xx + yy) & 1 == 0 else 0.0)
			if aa > 0.0: _img.set_pixel(xx, yy, SpriteForge.snes(_img.get_pixel(xx, yy).lerp(c, aa)))

func _line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_p(x0, y0, c)
		if x0 == x1 and y0 == y1: break
		var e2 := 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy

func _box(x: int, y: int, w: int, h: int, c: Color) -> void:
	_r(x, y, w, 1, c); _r(x, y + h - 1, w, 1, c); _r(x, y, 1, h, c); _r(x + w - 1, y, 1, h, c)

func _blit(src: Image, x: int, y: int) -> void:
	_img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))

func _text(s: String, x: int, y: int, c: Color) -> void:
	_blit(_text_tex(s, c).get_image(), x, y)

## A small sign board with centred text.
func _sign(cx: int, y: int, s: String, bg: Color, fg: Color, edge: Color) -> void:
	var w := s.length() * 4 + 7
	var x := cx - w / 2
	_r(x, y, w, 9, edge)
	_r(x + 1, y + 1, w - 2, 7, bg)
	_text(s, x + 4, y + 2, fg)

func _nightify(c: Color) -> Color:
	return SpriteForge.snes(c.darkened(0.5).lerp(Color("#1a2050"), 0.35)) if night else c

# ---------------- outside: sky, scenery, season ----------------
func _sky_cols() -> Array:
	if night: return [_hx("#0b1030"), _hx("#2c3870")]
	match season:
		0: return [_hx("#62aee8"), _hx("#cdeeff")]
		1: return [_hx("#3c9ce8"), _hx("#b0e0fa")]
		2: return [_hx("#6e9cc8"), _hx("#f4d8a8")]
	return [_hx("#8aa2b8"), _hx("#e6eef4")]

func _ground_cols() -> Array:
	var g: Array
	match season:
		0: g = ["#62b84a", "#4a9a3a", "#f4b8d0"]
		1: g = ["#52a83a", "#3a8a30", "#f2d34a"]
		2: g = ["#a8963e", "#8a7432", "#e0782a"]
		_: g = ["#eef4fa", "#c4d4e6", "#ffffff"]
	return [_nightify(_hx(g[0])), _nightify(_hx(g[1])), _nightify(_hx(g[2]))]

func _tree_cols() -> Array:
	var g: Array
	match season:
		0: g = ["#5cb84a", "#3f8f3a", "#f4b8d0"]
		1: g = ["#3f9a3a", "#2f6f44", "#3f9a3a"]
		2: g = ["#e07a2a", "#b04a22", "#f2b03a"]
		_: g = ["#8a7a6a", "#5a4a3a", "#f4f8fc"]
	return [_nightify(_hx(g[0])), _nightify(_hx(g[1])), _nightify(_hx(g[2]))]

func _sky(x: int, y: int, w: int, h: int) -> void:
	var sc := _sky_cols()
	var bands := maxi(2, h / 4)
	for i in bands:
		var y0 := y + i * h / bands
		var y1 := y + (i + 1) * h / bands
		_r(x, y0, w, y1 - y0, SpriteForge.snes(sc[0].lerp(sc[1], float(i) / (bands - 1))))
	if night:
		for i in w * h / 110 + 1:
			var hh := absi(hash(Vector3i(x, y, i)))
			_p(x + hh % w, y + (hh / w) % maxi(1, h * 2 / 3), _hx("#ffffff") if i % 3 else _hx("#9aa8d8"))
		if w > 60:
			_ell(x + w * 0.78, y + 7, 3.5, 3.5, _hx("#f4f1d0"))
			_ell(x + w * 0.78 + 1.5, y + 6, 3.0, 3.0, sc[0])
	elif season != 3:
		for i in maxi(1, w / 44):
			var hh := absi(hash(Vector3i(x, w, i)))
			var cx := x + hh % maxi(1, w - 10)
			var cy := y + 2 + (hh / 7) % maxi(1, h / 3)
			var cc := _hx("#ffffff")
			_r(cx, cy + 1, 12, 2, cc); _r(cx + 3, cy, 6, 1, cc); _r(cx + 1, cy + 3, 10, 1, _hx("#dce8f4"))

## Trees along a horizon at hy, ground below to y1.
func _scenery(x: int, w: int, hy: int, y1: int, dense := 1.0) -> void:
	var gc := _ground_cols()
	var tc := _tree_cols()
	for xx in range(x - 4, x + w + 4, 5):
		var hh := absi(hash(Vector2i(xx, 77)))
		var th := 4 + hh % 6
		if (hh / 11) % 10 > int(dense * 10): continue
		for k in th:
			var half := mini(3, (k + 1) / 2 + 1)
			_r(xx - half, hy - th + k, half * 2 + 1, 1, tc[1] if k > th / 2 else tc[0])
		if season == 3: _r(xx - 1, hy - th, 3, 1, tc[2])
		elif season == 0 and hh % 3 == 0: _p(xx, hy - th + 2, tc[2])
		elif season == 2 and hh % 2 == 0: _p(xx + 1, hy - th + 1, tc[2])
	_r(x, hy, w, y1 - hy, gc[0])
	_r(x, hy, w, 1, gc[1])
	for i in w * (y1 - hy) / 20:
		var hh := absi(hash(Vector3i(x, hy, i)))
		_p(x + hh % w, hy + 1 + (hh / w) % maxi(1, y1 - hy - 1), gc[2] if i % 4 == 0 else gc[1])

## Window: frame + glass view (sky, trees, ground) + mullions. Records the glass rect for weather.
func _window(x: int, y: int, w: int, h: int, frame: Color, panes_x := 2, panes_y := 2, horizon := 0.62) -> void:
	_r(x - 2, y - 2, w + 4, h + 4, frame.darkened(0.35))
	_r(x - 1, y - 1, w + 2, h + 2, frame)
	_clip = Rect2i(x, y, w, h)
	var hy := y + int(h * horizon)
	_sky(x, y, w, hy - y)
	_scenery(x, w, hy, y + h)
	if not night:
		for k in 3:
			_line(x + 2 + k * 2 + w / 3, y + 1, x + 1 + k * 2 + w / 3 - 4, y + 5, _hx("#ffffff") if k != 1 else _hx("#e4f4ff"))
	_clip = Rect2i(0, 0, W, H)
	for i in range(1, panes_x): _r(x + i * w / panes_x, y, 1, h, frame)
	for i in range(1, panes_y): _r(x, y + i * h / panes_y, w, 1, frame)
	_r(x - 3, y + h + 2, w + 6, 2, frame.lightened(0.15))      # sill
	_r(x - 3, y + h + 4, w + 6, 1, frame.darkened(0.45))
	_glass.append(Rect2(x, y, w, h))

## Roller door, partly open at the bottom (outside visible in the gap).
func _roller(x: int, y: int, w: int, h: int, gap: int, slat: Color) -> void:
	var base: int = room.base
	_r(x - 3, y - 6, w + 6, 6, slat.darkened(0.45))            # drum housing
	_r(x - 3, y - 6, w + 6, 1, slat.darkened(0.2))
	_r(x - 3, y, 3, h, slat.darkened(0.5))                      # guides
	_r(x + w, y, 3, h, slat.darkened(0.5))
	var gy := y + h - gap
	_clip = Rect2i(x, gy, w, gap)
	_sky(x, gy, w, gap)
	_scenery(x, w, gy + gap / 2, y + h, 0.6)
	_clip = Rect2i(0, 0, W, H)
	_gaps.append(Rect2(x, gy, w, gap))
	for yy in range(y, gy):
		var k := (yy - y) % 4
		var c := slat if k == 0 else (slat.darkened(0.1) if k == 1 else (slat.darkened(0.22) if k == 2 else slat.lightened(0.12)))
		_r(x, yy, w, 1, c)
	_r(x, gy - 2, w, 2, slat.darkened(0.55))                   # bottom bar
	_r(x + w / 2 - 3, gy - 4, 6, 1, slat.darkened(0.55))      # handle
	if not night: _tint(x - 2, base, w + 4, 6, _hx("#fff4d0"), 0.18)
	spots["door"] = [Vector2(x + w / 2, base + 9), 0]

func _pegboard(x: int, y: int, w: int, h: int) -> void:
	var bd := _hx("#c9a26a")
	_r(x - 1, y - 1, w + 2, h + 2, _hx("#7a5a32"))
	_r(x, y, w, h, bd)
	for yy in range(y + 1, y + h, 3):
		for xx in range(x + 1, x + w, 3): _p(xx, yy, _hx("#a07c48"))
	var tools := ["wrench", "hammer", "screw", "pliers", "wrench2", "saw", "screw2", "wrench"]
	var tx := x + 3
	var i := 0
	while tx < x + w - 4:
		var tl: String = tools[i % tools.size()]
		var sh := _hx("#8a6a3c")
		match tl:
			"wrench", "wrench2":
				var c := _hx("#b8c0c8")
				_r(tx + 1, y + 3, 1, h - 7, sh); _r(tx, y + 3, 1, h - 8, c)
				_r(tx - 1, y + 2, 3, 2, c); _p(tx, y + 2, bd)
				_r(tx - 1, y + h - 6, 3, 2, c)
				tx += 5
			"hammer":
				_r(tx + 1, y + 5, 1, h - 7, _hx("#8a5a2a")); _r(tx, y + 5, 1, h - 7, _hx("#b07a3a"))
				_r(tx - 2, y + 3, 6, 2, _hx("#6a7280")); _r(tx - 2, y + 3, 6, 1, _hx("#9aa2ad"))
				tx += 7
			"screw", "screw2":
				var hc := _hx("#d8402e") if tl == "screw" else _hx("#2f7de8")
				_r(tx - 1, y + 3, 3, 4, hc); _r(tx - 1, y + 3, 1, 4, hc.lightened(0.3))
				_r(tx, y + 7, 1, h - 10, _hx("#b8c0c8"))
				tx += 5
			"pliers":
				_r(tx - 1, y + 3, 1, h - 8, _hx("#d8402e")); _r(tx + 1, y + 3, 1, h - 8, _hx("#d8402e"))
				_r(tx, y + h - 6, 1, 3, _hx("#9aa2ad"))
				tx += 5
			"saw":
				_r(tx - 1, y + 3, 3, 3, _hx("#e0b450")); _r(tx, y + 6, 3, h - 9, _hx("#c4ccd4"))
				for k in range(y + 7, y + h - 3, 2): _p(tx + 3, k, _hx("#8a929c"))
				tx += 7
		i += 1

func _bench(x: int, w: int, steel: bool) -> void:
	var base: int = room.base
	var top_y := base - 12
	var wood := _hx("#9a6a3a") if not steel else _hx("#6a7682")
	var lite := wood.lightened(0.25)
	var dark := wood.darkened(0.4)
	_r(x + 1, top_y + 3, 2, base - top_y, dark)
	_r(x + w - 3, top_y + 3, 2, base - top_y, dark)
	_r(x + 1, base - 3, w - 2, 2, wood.darkened(0.2))
	if steel:
		_r(x + w - 18, top_y + 3, 14, base - top_y - 3, _hx("#c0392b"))
		for k in 3:
			_r(x + w - 18, top_y + 5 + k * 4, 14, 1, _hx("#7f1d12"))
			_r(x + w - 13, top_y + 6 + k * 4, 4, 1, _hx("#e8e2d0"))
	else:
		_r(x + 4, base - 7, 7, 4, _hx("#5a6470"))
		_r(x + 4, base - 7, 7, 1, _hx("#8a96a0"))
	_r(x - 1, top_y, w + 2, 3, wood)
	_r(x - 1, top_y, w + 2, 1, lite)
	_r(x - 1, top_y + 3, w + 2, 1, dark)
	# vise, toolbox, mug
	_r(x + 4, top_y - 4, 6, 4, _hx("#3a6ab0")); _r(x + 4, top_y - 4, 6, 1, _hx("#6a9ae0")); _r(x + 2, top_y - 2, 2, 1, _hx("#9aa2ad"))
	_r(x + w / 2 - 2, top_y - 5, 12, 5, _hx("#d8402e")); _r(x + w / 2 - 2, top_y - 5, 12, 1, _hx("#f07a5a"))
	_r(x + w / 2 + 2, top_y - 7, 4, 1, _hx("#2a2a30")); _r(x + w / 2 + 1, top_y - 6, 1, 1, _hx("#2a2a30")); _r(x + w / 2 + 6, top_y - 6, 1, 1, _hx("#2a2a30"))
	_r(x + w - 8, top_y - 3, 3, 3, _hx("#f2f2ee")); _p(x + w - 5, top_y - 2, _hx("#f2f2ee"))
	spots["bench"] = [Vector2(x + w / 2, base + 8), 0]
	spots["bench2"] = [Vector2(x + w / 2 - 12, base + 8), 0]

func _drum(x: int, c: Color) -> void:
	var base: int = room.base
	var y := base - 14
	_r(x, y + 1, 11, 14, c)
	_r(x + 1, y, 9, 1, c.lightened(0.3))
	_r(x + 1, y + 1, 9, 1, c.darkened(0.3))
	_r(x, y + 5, 11, 1, c.darkened(0.25)); _r(x, y + 10, 11, 1, c.darkened(0.25))
	_r(x + 1, y + 2, 2, 12, c.lightened(0.25))
	_r(x + 8, y + 2, 2, 12, c.darkened(0.2))
	_p(x + 7, y, _hx("#2a2a30"))
	_r(x - 1, y + 1, 1, 14, _hx(OUTLINE)); _r(x + 11, y + 1, 1, 14, _hx(OUTLINE)); _r(x, y + 15, 11, 1, _hx(OUTLINE))
	_r(x + 1, y - 1, 9, 1, _hx(OUTLINE))

## Tyre stack (four slicks with lettered sidewalls); returns where the cat curls up on top.
func _tyres(x: int) -> Vector2:
	var base: int = room.base
	var rub := _hx("#2e2e36")
	var hi := _hx("#4a4a56")
	var dk := _hx("#1c1c22")
	var out := _hx(OUTLINE)
	var n := 4
	var w := 18
	var y := base + 1
	for i in n:
		y -= 5
		_r(x, y + 1, w, 4, rub)
		_r(x + 1, y, w - 2, 1, rub)
		_r(x + 1, y + 1, w - 2, 1, hi)
		_r(x + 1, y + 4, w - 2, 1, dk)
		if i % 2 == 0: _r(x + 5, y + 2, 7, 1, _hx("#d8dde4"))          # sidewall lettering
		else: _r(x + 4, y + 2, 2, 1, _hx("#e2b53a")); _r(x + 11, y + 2, 2, 1, _hx("#e2b53a"))
		_p(x - 1, y + 2, out); _p(x - 1, y + 3, out); _p(x + w, y + 2, out); _p(x + w, y + 3, out)
	# top: tread ring around the hole
	_r(x + 1, y - 3, w - 2, 3, hi)
	_r(x + 4, y - 2, w - 8, 2, dk)
	_r(x + 2, y - 4, w - 4, 1, out)
	_p(x, y - 2, out); _p(x + w - 1, y - 2, out)
	spots["tyres"] = [Vector2(x + w / 2 - 6, base + 8), 0]
	return Vector2(x + w / 2.0, y)

func _banner(x: int, y: int, w: int, h: int) -> void:
	var c := SpriteForge.snes(team_col)
	var d := SpriteForge.snes(team_col.darkened(0.35))
	var l := SpriteForge.snes(team_col.lightened(0.3))
	_r(x - 3, y - 2, w + 6, 2, _hx("#5a4632"))                  # rod
	_p(x - 4, y - 2, _hx("#e0b450")); _p(x + w + 3, y - 2, _hx("#e0b450"))
	_r(x, y, w, h, c)
	_r(x, y, 1, h, l); _r(x + w - 1, y, 1, h, d)
	for k in 5:
		_r(x, y + h + k, w / 2 - k, 1, c if k < 4 else d)
		_r(x + w / 2 + k, y + h + k, w - w / 2 - k, 1, c if k < 4 else d)
	var ex := x + w / 2
	var ey := y + h / 2 - 2
	var wht := _hx("#f8f4e8")
	_ell(ex, ey, 5.5, 5.5, wht)
	_ell(ex, ey, 4.0, 4.0, c)
	_r(ex - 1, ey - 3, 2, 6, wht); _r(ex - 3, ey - 1, 6, 2, wht)
	_r(ex - 2, ey - 2, 4, 4, wht)
	_r(x + 2, y + h - 6, w - 4, 1, wht); _r(x + 4, y + h - 4, w - 8, 1, wht)
	_r(x, y, w, 1, d)

func _tool_chest(x: int, c: Color) -> void:
	var base: int = room.base
	var y := base - 22
	_r(x - 1, y - 1, 20, 24, _hx(OUTLINE))
	_r(x, y, 18, 22, c)
	_r(x, y, 18, 1, c.lightened(0.3))
	_r(x + 17, y, 1, 22, c.darkened(0.3))
	for k in 5:
		_r(x + 1, y + 3 + k * 4, 16, 1, c.darkened(0.4))
		_r(x + 6, y + 4 + k * 4, 6, 1, _hx("#e8e2d0"))
	_r(x + 1, base - 1, 2, 2, _hx("#2a2a30")); _r(x + 15, base - 1, 2, 2, _hx("#2a2a30"))

func _shelf(x: int, y: int, w: int) -> void:
	var c := _hx("#6a7280")
	_r(x, y, w, 1, c.lightened(0.2)); _r(x, y + 1, w, 1, c.darkened(0.3))
	_r(x + 1, y + 2, 1, 2, c.darkened(0.3)); _r(x + w - 2, y + 2, 1, 2, c.darkened(0.3))
	var cols := ["#d8402e", "#2f7de8", "#e0b450", "#3fb34a", "#9b4de8"]
	var bx := x + 1
	var i := 0
	while bx < x + w - 5:
		var hh := absi(hash(Vector2i(bx, y)))
		var bw := 4 + hh % 4
		var bh := 3 + (hh / 3) % 4
		var bc := _hx(cols[(i + hh) % cols.size()])
		_r(bx, y - bh, bw, bh, bc); _r(bx, y - bh, bw, 1, bc.lightened(0.3))
		bx += bw + 1; i += 1

func _tube_fixture(x: int, y: int, w: int, hang: int) -> void:
	_r(x + 3, y - hang, 1, hang, _hx("#4a4e58")); _r(x + w - 4, y - hang, 1, hang, _hx("#4a4e58"))
	_r(x, y - 2, w, 2, _hx("#8a929c")); _r(x, y - 2, w, 1, _hx("#c4ccd4"))
	_tubes.append(Vector3(x + 1, y, w - 2))

# ---------------- facility props ----------------
## Draws a facility prop standing on the floor against the wall in [x, x + w).
func _facility(id: String, x: int, w: int) -> void:
	var base: int = room.base
	var out := _hx(OUTLINE)
	match id:
		"dyno":
			var cw := 14 if w >= 18 else 10
			var cx0 := x + (w - cw) / 2
			_r(cx0 - 1, base - 25, cw + 2, 26, out)
			_r(cx0, base - 24, cw, 24, _hx("#3a3f4a")); _r(cx0, base - 24, cw, 1, _hx("#6a7282"))
			_r(cx0 + 2, base - 21, cw - 4, 7, _hx("#0c1a14")); _screens.append(Rect2(cx0 + 2, base - 21, cw - 4, 7))
			for k in 3: _p(cx0 + 2 + k * (cw - 4) / 3 + 1, base - 11, [_hx("#3fd34a"), _hx("#ffb020"), _hx("#ff4a3a")][k])
			_r(cx0 + 2, base - 8, cw - 4, 1, _hx("#2a2a30"))
			if w >= 18:
				_r(x, base - 2, w, 3, _hx("#2a2a30")); _r(x + 1, base - 2, w - 2, 1, _hx("#9aa2ad"))
			spots["dyno"] = [Vector2(x + w / 2, base + 8), 0]
		"wind", "tunnel":
			var hs := 12 if w >= 22 else 7
			var cx := x + w / 2
			var cy := base - hs - 1
			_r(cx - hs, cy - hs, hs * 2, hs * 2, out)
			_r(cx - hs + 1, cy - hs + 1, hs * 2 - 2, hs * 2 - 2, _hx("#5a6470")); _r(cx - hs + 1, cy - hs + 1, hs * 2 - 2, 1, _hx("#8a96a0"))
			_ell(cx, cy, hs - 2.5, hs - 2.5, _hx("#1e2430"))
			_ell(cx, cy, hs - 3.5, hs - 3.5, _hx("#2e3644"))
			_r(cx - hs + 3, base - 1, hs * 2 - 6, 2, _hx("#3a3f4a"))
			_fans.append(Vector3(cx, cy, hs - 4))
		"gym":
			_r(x + 1, base - 13, w - 2, 2, _hx("#4a4e58")); _r(x + 2, base - 11, 1, 11, _hx("#4a4e58")); _r(x + w - 3, base - 11, 1, 11, _hx("#4a4e58"))
			_r(x + 1, base - 6, w - 2, 1, _hx("#4a4e58"))
			for k in maxi(1, (w - 6) / 6):
				var dx := x + 3 + k * 6
				_r(dx, base - 16, 2, 3, _hx("#2a2a30")); _r(dx + 2, base - 15, 2, 1, _hx("#9aa2ad")); _r(dx + 4, base - 16, 2, 3, _hx("#2a2a30"))
				_r(dx, base - 9, 2, 3, _hx("#d8402e")); _r(dx + 2, base - 8, 2, 1, _hx("#9aa2ad")); _r(dx + 4, base - 9, 2, 3, _hx("#d8402e"))
			spots["gym"] = [Vector2(x + w / 2, base + 8), 0]
		"kitchen", "lounge":
			_r(x - 1, base - 27, 12, 28, out)
			_r(x, base - 26, 10, 26, _hx("#e8ecef")); _r(x, base - 26, 10, 1, _hx("#ffffff")); _r(x + 9, base - 26, 1, 26, _hx("#a8b0b8"))
			_r(x, base - 17, 10, 1, _hx("#a8b0b8")); _r(x + 7, base - 23, 1, 4, _hx("#8a929c")); _r(x + 7, base - 14, 1, 4, _hx("#8a929c"))
			_p(x + 3, base - 22, _hx("#d8402e")); _p(x + 4, base - 13, _hx("#2f7de8"))
			if w >= 20:
				_r(x + 11, base - 10, w - 11, 10, _hx("#9a6a3a")); _r(x + 11, base - 10, w - 11, 1, _hx("#c08a50"))
				_r(x + 13, base - 17, 6, 7, _hx("#2a2a30")); _r(x + 14, base - 15, 4, 2, _hx("#d8402e"))
				_r(x + 15, base - 12, 2, 2, _hx("#f2f2ee"))
			spots["coffee"] = [Vector2(x + 10, base + 8), 0]
		"telemetry":
			_r(x, base - 10, w, 2, _hx("#4a4e58")); _r(x + 1, base - 8, 1, 8, _hx("#4a4e58")); _r(x + w - 2, base - 8, 1, 8, _hx("#4a4e58"))
			var nm := 2 if w >= 20 else 1
			for k in nm:
				var mw := w / nm
				var mx := x + 1 + k * mw
				_r(mx - 1, base - 22, mw, 12, out)
				_r(mx, base - 21, mw - 2, 10, _hx("#2a2a30"))
				_r(mx + 1, base - 20, mw - 4, 7, _hx("#0c1a24"))
				_screens.append(Rect2(mx + 1, base - 20, mw - 4, 7))
			spots["desk"] = [Vector2(x + w / 2, base + 8), 0]
		_:   # gearbench / fab / stress: a gearbox on a stand
			_r(x + 1, base - 9, w - 2, 2, _hx("#6a7682")); _r(x + 2, base - 7, 1, 7, _hx("#4a4e58")); _r(x + w - 3, base - 7, 1, 7, _hx("#4a4e58"))
			_r(x + 4, base - 16, 9, 7, _hx("#8a929c")); _r(x + 4, base - 16, 9, 1, _hx("#c4ccd4"))
			_ell(x + 6, base - 13, 2, 2, _hx("#5a6470")); _ell(x + 11, base - 13, 2, 2, _hx("#5a6470"))

## Recognised facilities in a stable order.
func _fac_list() -> Array:
	var known := ["dyno", "wind", "tunnel", "gym", "kitchen", "lounge", "telemetry", "gearbench", "fab", "stress"]
	var out := []
	for k in known:
		if not facilities.has(k): continue
		if k == "tunnel" and out.has("wind"): continue
		if k == "lounge" and out.has("kitchen"): continue
		if k in ["fab", "stress"] and (out.has("gearbench") or out.has("fab")): continue
		out.append(k)
	return out

## Fill wall slots [[x, w, filler], ...] with facilities, falling back to the slot's filler prop.
func _fill_slots(slot_list: Array) -> void:
	var facs := _fac_list()
	for i in slot_list.size():
		var sl: Array = slot_list[i]
		if i < facs.size(): _facility(facs[i], sl[0], sl[1])
		else:
			match str(sl[2]):
				"drum": _drum(sl[0] + (sl[1] - 11) / 2, _hx("#2f5fbf"))
				"drums":
					_drum(sl[0], _hx("#c0392b")); _drum(sl[0] + 12, _hx("#2f5fbf"))
				"chest": _tool_chest(sl[0], _hx("#2f5fbf"))

# ---------------- floor ----------------
func _floor(c0: Color, c1: Color, joints: Color, tiles := false) -> void:
	var base: int = room.base
	var bottom: int = room.bottom
	var x0: int = room.x0
	var x1: int = room.x1
	var bands := 8
	for i in bands:
		var y0 := base + (bottom - base) * i / bands
		var y1 := base + (bottom - base) * (i + 1) / bands
		_r(x0, y0, x1 - x0, y1 - y0, SpriteForge.snes(c0.lerp(c1, float(i) / (bands - 1))))
	_clip = Rect2i(x0, base, x1 - x0, bottom - base)
	for ry in [0, 7, 17, 31, 50, 76, 108]:
		if base + ry < bottom: _r(x0, base + ry, x1 - x0, 1, joints)
	for xb in range(-256, 513, 48 if not tiles else 32):
		_line(128 + int((xb - 128) * 0.62), base, xb, H, joints)
	_clip = Rect2i(0, 0, W, H)
	_r(x0, base, x1 - x0, 1, c0.darkened(0.35))
	_dith(x0, base + 1, x1 - x0, 2, c0.darkened(0.25))

func _stains(n: int) -> void:
	var base: int = room.base
	var bottom: int = room.bottom
	for i in n:
		var hh := absi(hash(Vector2i(i, ws * 31 + 5)))
		var sx: float = room.x0 + 12 + hh % maxi(1, room.x1 - room.x0 - 24)
		var sy: float = base + 14 + (hh / 97) % maxi(1, bottom - base - 18)
		var rx := 3.0 + (hh / 13) % 5
		var c := _hx("#2a2630")
		_tint_ell(sx, sy, rx, rx * 0.4, c, 0.35)
		_tint_ell(sx + rx * 0.6, sy + 1, rx * 0.5, rx * 0.25, c, 0.25)

func _bay_marks() -> void:
	if ws == 1: return
	var c := _hx("#e2b53a") if ws < 4 else SpriteForge.snes(team_col.lerp(Color.WHITE, 0.3))
	for s in slots:
		var x0: int = s.cx - s.w / 2 + 3
		var x1: int = s.cx + s.w / 2 - 4
		var y0: int = s.gy - 15
		var y1: int = s.gy + 4
		for p in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
			_r(p[0] if p[2] > 0 else p[0] - 4, p[1], 5, 1, c)
			_r(p[0], p[1] if p[3] > 0 else p[1] - 3, 1, 4, c)

# ---------------- per level ----------------
func _bake_bg() -> void:
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_clip = Rect2i(0, 0, W, H)
	_glass.clear(); _gaps.clear(); _tubes.clear(); _fans.clear(); _screens.clear(); spots.clear()
	_cat = Vector2(-99, -99)
	match ws:
		1: _bake_shed()
		2: _bake_town()
		3: _bake_works()
		_: _bake_hq()
	_bay_marks()
	_light()
	_bg = ImageTexture.create_from_image(_img)
	_img = null

func _light() -> void:
	var base: int = room.base
	if night:
		_tint(room.x0, room.top, room.x1 - room.x0, room.bottom - room.top, _hx("#101838"), 0.16 if ws <= 2 else 0.22)
		for tb in _tubes:
			_tint_ell(tb.x + tb.z / 2, base + 50, tb.z * 1.3, 22, _hx("#fff8e0"), 0.12)
			_tint_ell(tb.x + tb.z / 2, tb.y + 10, tb.z * 0.7, 9, _hx("#fff8e0"), 0.1)
	else:
		# sunlight falling through the low windows onto the floor
		for g in _glass:
			if g.position.y + g.size.y < base - 40: continue
			var gx: int = int(g.position.x)
			var gw: int = int(g.size.x)
			for k in 20:
				_tint(gx - 2 + k, base + 3 + k, gw + 4, 1, _hx("#fff4c8"), 0.13 if k < 16 or k % 2 == 0 else 0.06)

## Jerry can + a spare tyre lying flat, standing on the floor at the given feet positions.
func _floor_junk(cx: int, cy: int, tx: int, ty: int) -> void:
	var out := _hx(OUTLINE)
	# jerry can
	_r(cx - 1, cy - 10, 9, 11, out)
	_r(cx, cy - 9, 7, 9, _hx("#d8402e")); _r(cx, cy - 9, 7, 1, _hx("#f07a5a")); _r(cx + 5, cy - 9, 2, 9, _hx("#a02a1e"))
	_r(cx + 1, cy - 12, 3, 3, out); _r(cx + 2, cy - 11, 1, 2, _hx("#e2b53a"))
	_line(cx + 1, cy - 7, cx + 5, cy - 3, _hx("#a02a1e"))
	# tyre lying flat
	_tint_ell(tx + 9, ty - 1, 10, 3, _hx("#1c1430"), 0.35)
	_ell(tx + 9, ty - 4, 10, 4.5, out)
	_ell(tx + 9, ty - 4, 9, 3.5, _hx("#2e2e36"))
	_ell(tx + 9, ty - 5, 9, 3, _hx("#4a4a56"))
	_ell(tx + 9, ty - 5, 5, 1.6, _hx("#1c1c22"))
	_r(tx + 1, ty - 2, 17, 1, _hx("#22222a"))

func _outside_full(ground_y: int) -> void:
	_sky(0, 0, W, ground_y)
	_scenery(0, W, ground_y, H, 0.9)

func _bake_shed() -> void:
	var x0: int = room.x0
	var x1: int = room.x1
	var top: int = room.top
	var base: int = room.base
	var bottom: int = room.bottom
	_outside_full(base - 8)
	# picket fence
	var fc := _nightify(_hx("#e8e2d0"))
	var fd := _nightify(_hx("#b8b2a2"))
	for fx2 in range(0, W, 5):
		if fx2 > x0 - 14 and fx2 < x1 + 10: continue
		_r(fx2, base - 10, 3, 12, fc); _p(fx2 + 1, base - 11, fc); _r(fx2 + 2, base - 9, 1, 11, fd)
	_r(0, base - 7, x0 - 12, 1, fd); _r(x1 + 10, base - 7, W - x1 - 10, 1, fd)
	_r(0, base - 2, x0 - 12, 1, fd); _r(x1 + 10, base - 2, W - x1 - 10, 1, fd)
	# stepping-stone path in front of the shed
	var stone := _nightify(_hx("#a8a29a"))
	for k in 3:
		var sy := bottom + 6 + k * 6
		_ell(128 + (k % 2) * 6 - 3, sy, 6, 2.2, stone)
	# gable roof: dark underside + chunky corrugated tin edge
	var peak := 3
	var eave_l := x0 - 12
	var eave_r := x1 + 12
	var span := 128 - eave_l
	var tin := _nightify(_hx("#9aa6b2"))
	var tin_d := _nightify(_hx("#6e7a88"))
	for x in range(eave_l, eave_r):
		var ry := peak + int(absi(x - 128) * float(top - peak) / span)
		_r(x, ry + 4, 1, top - ry - 4, _hx("#3a2a1e"))
		var c := tin if (x / 2) % 2 == 0 else tin_d
		_r(x, ry, 1, 4, c)
		_p(x, ry - 1, _hx(OUTLINE)); _p(x, ry + 4, _hx("#2a1c12"))
		if season == 3: _r(x, ry - 1, 1, 2, _hx("#f4f8fc"))
	_r(x0 - 6, top - 3, x1 - x0 + 12, 4, _hx("#6e4527"))           # tie beam
	_r(x0 - 6, top - 3, x1 - x0 + 12, 1, _hx("#9a6a3a"))
	_r(126, peak + 8, 4, top - peak - 11, _hx("#5d3a20"))           # king post
	_line(128, peak + 9, x0 + 10, top - 3, _hx("#5d3a20")); _line(128, peak + 9, x1 - 10, top - 3, _hx("#5d3a20"))
	_sign(128, 13, WS_NAME[1], _hx("#e8dcc0"), _hx("#7a2a1a"), _hx("#5d3a20"))
	# plank wall
	for x in range(x0, x1):
		var pk := (x - x0) / 7
		var c := _hx("#8a5a35") if pk % 2 == 0 else _hx("#94633c")
		if (x - x0) % 7 == 0: c = _hx("#5d3a20")
		_r(x, top + 1, 1, base - top - 1, c)
	for x in range(x0 + 3, x1, 7):
		_p(x, top + 4, _hx("#4a2c18")); _p(x, base - 4, _hx("#4a2c18"))
		var hh := absi(hash(x))
		if hh % 3 == 0: _ell(x + 1, top + 14 + hh % 40, 1.2, 0.8, _hx("#6e4527"))
	# floor slab, ending in a front edge on the grass
	_floor(_hx("#7e776c"), _hx("#99917f"), _hx("#6e675e"))
	_r(x0 - 6, bottom, x1 - x0 + 12, 3, _hx("#5e584e"))
	_r(x0 - 6, bottom + 3, x1 - x0 + 12, 1, _hx("#3e3a34"))
	_stains(5)
	_line(x0 + 30, base + 40, x0 + 44, base + 52, _hx("#5e584e")); _line(x0 + 44, base + 52, x0 + 41, base + 62, _hx("#5e584e"))
	_line(x1 - 26, base + 80, x1 - 44, base + 86, _hx("#5e584e"))
	_floor_junk(x0 + 8, bottom - 4, x1 - 34, bottom - 4)
	# posts (cut-away frame)
	_r(x0 - 6, top - 3, 6, bottom - top + 6, _hx("#6e4527")); _r(x0 - 6, top - 3, 1, bottom - top + 6, _hx("#9a6a3a"))
	_r(x1, top - 3, 6, bottom - top + 6, _hx("#6e4527")); _r(x1 + 5, top - 3, 1, bottom - top + 6, _hx("#4a2c18"))
	# wall features
	_roller(x0 + 5, base - 44, 28, 44, 8, _hx("#9aa4ae"))
	_pegboard(x0 + 52, base - 42, 42, 18)
	_bench(x0 + 50, 46, false)
	_window(x0 + 104, top + 12, 24, 18, _hx("#e8e2d0"))
	spots["window"] = [Vector2(x0 + 116, base + 9), 0]
	_banner(x0 + 136, top + 8, 14, 20)
	_fill_slots([[x0 + 102, 24, "drum"], [x0 + 36, 12, "drum"]])
	_cat = _tyres(x1 - 22)
	_tube_fixture(112, top + 6, 32, 4)

func _bake_town() -> void:
	var x0: int = room.x0
	var x1: int = room.x1
	var top: int = room.top
	var base: int = room.base
	_outside_full(base)
	_r(0, base, W, H - base, _nightify(_hx("#a8a8a0")))          # pavement
	for y in range(base + 10, H, 14): _r(0, y, W, 1, _nightify(_hx("#8a8a84")))
	# brick parapet + sign
	var brick := _hx("#a3503f")
	_r(x0 - 6, top - 14, x1 - x0 + 12, 14, _hx("#8a4436"))
	for y in range(top - 14, top, 5): _r(x0 - 6, y, x1 - x0 + 12, 1, _hx("#b06454"))
	_r(x0 - 8, top - 16, x1 - x0 + 16, 3, _hx("#c9a99a"))
	_sign(128, 3, WS_NAME[2], _hx("#24305a"), _hx("#ffd84a"), _hx("#e8e2d0"))
	# brick wall
	for y in range(top, base):
		var row := (y - top) / 5
		for x in range(x0, x1):
			var c := brick
			if (y - top) % 5 == 4: c = _hx("#c9a99a")
			elif (x + (6 if row % 2 else 0)) % 12 == 0: c = _hx("#c9a99a")
			elif absi(hash(Vector2i((x + (6 if row % 2 else 0)) / 12, row))) % 5 == 0: c = _hx("#94463a")
			_img.set_pixel(x, y, c)
	_r(x0, base - 14, x1 - x0, 14, _hx("#5f7f6f")); _r(x0, base - 14, x1 - x0, 1, _hx("#7f9f8f")); _r(x0, base - 3, x1 - x0, 3, _hx("#3f5a4f"))
	_r(x0, top, x1 - x0, 2, _hx("#5e2a20"))
	_floor(_hx("#86868a"), _hx("#a2a2a4"), _hx("#76767a"))
	_stains(7)
	# brick piers (cut-away frame)
	_r(x0 - 6, top - 2, 6, H - top + 2, _hx("#8a4436")); _r(x0 - 6, top - 2, 1, H - top + 2, _hx("#c06a58"))
	_r(x1, top - 2, 6, H - top + 2, _hx("#8a4436")); _r(x1 + 5, top - 2, 1, H - top + 2, _hx("#5e2a20"))
	_roller(x0 + 8, base - 54, 46, 54, 11, _hx("#8e9aa6"))
	_window(x0 + 66, top + 14, 28, 20, _hx("#e8e2d0"))
	spots["window"] = [Vector2(x0 + 80, base + 9), 0]
	_pegboard(x0 + 104, base - 46, 50, 22)
	_bench(x0 + 102, 54, false)
	_window(x0 + 168, top + 14, 28, 20, _hx("#e8e2d0"))
	_banner(x0 + 204, top + 8, 16, 28)
	_fill_slots([[x0 + 166, 30, "drums"], [x0 + 64, 32, "drum"]])
	_cat = _tyres(x1 - 22)
	_tube_fixture(56, top + 6, 30, 4)
	_tube_fixture(150, top + 6, 30, 4)

func _bake_works() -> void:
	var base: int = room.base
	var st := _hx("#7d8a96")
	for x in W:
		var k := x % 6
		var c := st if k < 3 else (st.lightened(0.12) if k == 3 else (st.darkened(0.1) if k == 4 else st.darkened(0.18)))
		_r(x, 0, 1, base, c)
	# ceiling trusses
	_r(0, 0, W, 9, _hx("#3a4250"))
	for x in range(0, W, 16):
		_line(x, 8, x + 8, 1, _hx("#5a6470")); _line(x + 8, 1, x + 16, 8, _hx("#5a6470"))
	_r(0, 0, W, 1, _hx("#5a6470")); _r(0, 8, W, 2, _hx("#2a303a"))
	for i in 4: _window(16 + i * 62, 14, 40, 12, _hx("#4a5260"), 3, 1, 0.9)
	_r(0, 33, W, 3, _hx("#4a5260")); _r(0, 33, W, 1, _hx("#6a7682"))
	_r(0, base - 18, W, 18, _hx("#4f6a8a")); _r(0, base - 18, W, 1, _hx("#7f9aba")); _r(0, base - 3, W, 3, _hx("#2f3f55"))
	for x in [0, 84, 170, 252]:
		_r(x, 9, 4, base - 9, _hx("#4a5260")); _r(x, 9, 1, base - 9, _hx("#6a7682"))
	_floor(_hx("#5f6f80"), _hx("#7e90a2"), _hx("#56657a"))
	_r(0, base + 6, W, 1, _hx("#e2b53a"))                         # walkway line
	_stains(5)
	_roller(10, base - 52, 54, 52, 12, _hx("#c4ccd4"))
	_drum(53, _hx("#2f5fbf"))
	_tool_chest(70, _hx("#c0392b"))
	_sign(124, 36, WS_NAME[3], _hx("#24305a"), _hx("#ffd84a"), _hx("#e8e2d0"))
	_pegboard(98, base - 42, 52, 20)
	_bench(96, 56, true)
	_banner(158, 40, 18, 26)
	_shelf(186, 46, 46)
	_fill_slots([[184, 24, "drum"], [210, 22, ""]])
	_cat = _tyres(234)
	for x in [40, 120, 200]: _tube_fixture(x, 13, 30, 3)

func _bake_hq() -> void:
	var base: int = room.base
	for y in range(0, base):
		_r(0, y, W, 1, _hx("#e4e8ee") if y % 22 != 0 else _hx("#c8ced8"))
	for x in range(0, W, 32): _r(x, 0, 1, base, _hx("#ccd2dc"))
	_r(0, 0, W, 6, _hx("#3a4250")); _r(0, 5, W, 1, _hx("#2a303a"))
	for x in range(10, W, 48): _r(x, 1, 28, 3, _hx("#f4fbff"))
	# glass wall with the city beyond
	var gx := 84
	var gw := 120
	var gy := 12
	var gh := 42
	_r(gx - 2, gy - 2, gw + 4, gh + 4, _hx("#3a4250"))
	_clip = Rect2i(gx, gy, gw, gh)
	_sky(gx, gy, gw, gh - 8)
	var sc := _nightify(_hx("#8494b0")) if not night else _hx("#1c2650")
	for i in 13:
		var hh := absi(hash(Vector2i(i, 99)))
		var bx := gx + i * 10 - 3
		var bh := 10 + hh % 18
		var by := gy + gh - 8 - bh
		_r(bx, by, 9, bh, sc)
		_r(bx, by, 1, bh, sc.lightened(0.12))
		for wy in range(by + 2, by + bh, 3):
			for wx in range(bx + 2, bx + 8, 2):
				if absi(hash(Vector2i(wx, wy))) % 3 == 0: _p(wx, wy, _hx("#ffe890") if night else _hx("#a8bad4"))
		if season == 3: _r(bx, by, 9, 1, _hx("#f4f8fc"))
	_scenery(gx, gw, gy + gh - 7, gy + gh, 0.6)
	_clip = Rect2i(0, 0, W, H)
	for i in range(1, 4): _r(gx + i * gw / 4, gy, 1, gh, _hx("#3a4250"))
	_glass.append(Rect2(gx, gy, gw, gh))
	spots["window"] = [Vector2(gx + gw / 2, base + 9), 0]
	_r(0, 58, W, 4, SpriteForge.snes(team_col)); _r(0, 62, W, 1, SpriteForge.snes(team_col.darkened(0.35)))
	_r(0, base - 3, W, 3, _hx("#8a929c"))
	_floor(_hx("#b8bfca"), _hx("#d8dde4"), _hx("#a8b0bc"), true)
	_tint(gx + 4, base + 2, gw - 8, 10, _hx("#ffffff"), 0.1)
	_stains(2)
	_roller(8, base - 56, 50, 56, 12, _hx("#dfe4ea"))
	_drum(35, SpriteForge.snes(team_col)); _drum(47, _hx("#3a3f4a"))
	_banner(64, 12, 12, 30)
	_banner(214, 12, 12, 30)
	_sign(128, 0, WS_NAME[4], _hx("#24305a"), _hx("#ffd84a"), _hx("#3a4250"))
	_fill_slots([[64, 26, "chest"], [94, 24, ""], [122, 24, ""], [150, 26, ""]])
	_bench(184, 44, true)
	_cat = _tyres(234)
	for x in [24, 104, 184]: _tube_fixture(x, 8, 34, 1)
