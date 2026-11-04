class_name EngineAudio
extends Node
## One audible engine. Plays the pre-rendered loops from tools/audio/engines.py (RPM layers on and
## off throttle), crossfading the two layers around the current RPM and pitch-shifting each toward it.
## Drive it with `rpm` (absolute) and `load` (0 = overrun, 1 = full throttle). A RevModel can do that
## from race speed (gears, shifts, lift-off pops).

const DIR := "res://audio/engine/"
static var meta := {}
static var _streams := {}

var voice := "i4car"
var exhaust := "stock"
var rpm := 900.0
var throttle := 0.3
var gain_db := 0.0
var bus := "Engine"
var _players := {}          # layer key -> AudioStreamPlayer
var _rpm_of := {}           # layer key -> recorded rpm

static func _meta() -> Dictionary:
	if meta.is_empty():
		var f := FileAccess.open(DIR + "engines.json", FileAccess.READ)
		if f: meta = JSON.parse_string(f.get_as_text())
	return meta

static func info(v: String) -> Dictionary:
	return _meta().get("voices", {}).get(v, {})

func setup(v: String, ex: String) -> void:
	if info(v).is_empty(): v = "i4car"
	var vi := info(v)
	if not (vi.get("exhausts", []) as Array).has(ex): ex = str(vi.get("exhausts", ["stock"])[0])
	if v == voice and ex == exhaust and not _players.is_empty(): return
	voice = v; exhaust = ex
	for p in _players.values(): p.queue_free()
	_players.clear()
	_rpm_of = vi.get("rpm", {})
	for key in _rpm_of:
		var path := "%s%s_%s_%s.wav" % [DIR, v, ex, key]
		if not _streams.has(path):
			_streams[path] = load(path) if ResourceLoader.exists(path) else null
		if _streams[path] == null: continue
		var p := AudioStreamPlayer.new()
		p.stream = _streams[path]
		p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
		p.volume_db = -80.0
		add_child(p)
		_players[key] = p
	rpm = float(vi.get("idle", 900))

func idle_rpm() -> float: return float(info(voice).get("idle", 900))
func red_rpm() -> float: return float(info(voice).get("red", 7000))

## Weights for a set of layers ordered by rpm: linear crossfade between the two around `r`.
func _blend(keys: Array, r: float) -> Dictionary:
	var out := {}
	var ks := keys.filter(func(k): return _players.has(k))
	if ks.is_empty(): return out
	ks.sort_custom(func(a, b): return float(_rpm_of[a]) < float(_rpm_of[b]))
	if r <= float(_rpm_of[ks[0]]): out[ks[0]] = 1.0; return out
	if r >= float(_rpm_of[ks.back()]): out[ks.back()] = 1.0; return out
	for i in ks.size() - 1:
		var a: float = _rpm_of[ks[i]]; var b: float = _rpm_of[ks[i + 1]]
		if r >= a and r <= b:
			var t: float = (r - a) / max(1.0, b - a)
			out[ks[i]] = cos(t * PI * 0.5); out[ks[i + 1]] = sin(t * PI * 0.5)   # equal power
			break
	return out

func _process(_d: float) -> void:
	if _players.is_empty(): return
	var on := _blend(["idle", "r1", "r2", "r3", "r4"], rpm)
	var off := _blend(["idle", "o2", "o4"], rpm)
	var w := {}
	var l := clampf(throttle, 0.0, 1.0)
	for k in on: w[k] = w.get(k, 0.0) + on[k] * sqrt(l)
	for k in off: w[k] = w.get(k, 0.0) + off[k] * sqrt(1.0 - l)
	for k in _players:
		var p: AudioStreamPlayer = _players[k]
		var wk: float = w.get(k, 0.0)
		if wk < 0.004:
			if p.playing: p.stop()
			continue
		p.pitch_scale = clampf(rpm / max(1.0, float(_rpm_of[k])), 0.5, 2.0)
		p.volume_db = linear_to_db(wk) + gain_db
		if not p.playing:
			p.play(randf() * 0.5)

func silence() -> void:
	for p in _players.values(): p.stop()

# ---------------- which engine / exhaust a machine has ----------------
const EXH_PART := {"straightpipe": "straight", "sportexh": "sport", "expchamber": "race", "tiheaders": "race", "raceexh": "race", "tiworks": "race"}
const BIKE_LAYOUT := {"single": "single4", "stroke2": "single2", "twin": "twin270", "vtwin": "vtwin45", "triple": "triple", "inline4": "i4bike", "elec": "electric"}
const KIND_VOICE := {"hatch": "i4car", "sedan": "i4car", "roadster": "i4car", "rally": "i4car", "coupe": "v6", "gt": "v8", "super": "v8",
	"proto": "v8", "formula": "v10", "kart": "single2", "pickup": "v8", "truck": "v8", "buggy": "v8", "sprint": "v8",
	"commuter": "single4", "scooter": "single4", "naked": "twin270", "cafe": "twin270", "sport": "i4bike", "super_b": "i4bike", "gp": "single2",
	"sidecar": "i4bike", "trail": "single4", "mx": "single2", "enduro": "single4", "flat": "twin270", "smoto": "single4", "raid": "single4"}

## Voice for a built vehicle: bikes by engine layout, cars by body.
static func voice_for_vehicle(v: Dictionary) -> String:
	var b: Dictionary = Data.body(str(v.get("body", "")))
	if b.is_empty(): return "i4car"
	if b.cls == "bike": return str(BIKE_LAYOUT.get(str(v.get("layout", "")), voice_for_kind(str(b.kind), "bike")))
	if b.id == "kei": return "i3car"
	if b.id == "fjr": return "i4car"
	return voice_for_kind(str(b.kind), "car")

static func voice_for_kind(kind: String, cls := "car") -> String:
	if cls == "bike" and kind == "super": return "i4bike"
	return str(KIND_VOICE.get(kind, "i4bike" if cls == "bike" else "i4car"))

static func exhaust_for_vehicle(v: Dictionary) -> String:
	var best := "stock"
	var rank := {"stock": 0, "sport": 1, "race": 2, "straight": 3}
	for pid in v.get("parts", []):
		var e: String = EXH_PART.get(str(pid), "")
		if e != "" and rank[e] > rank[best]: best = e
	return best
