extends Node
## Local profile: who you are, your team colors, and the machines you can race in quick/LAN races.
## Machines come from presets or from your web career (paste its GG1: export code).

const SAVE_PATH := "user://profile.json"
const PRESETS := [
	# [body, layout, tier, label, discipline it's tuned for]
	["kei", "ff", 1, "Kei Hatch", "CR"], ["commuter", "single", 1, "Commuter 125", "BR"], ["dirt250", "stroke2", 1, "Dirt 250", "BO"], ["buggy", "mr", 1, "Sand Buggy", "CO"],
	["hothatch", "ff", 2, "Hot Hatch", "CR"], ["rallyhatch", "awd", 2, "Rally Hatch", "CO"], ["ss600", "inline4", 2, "Supersport 600", "BR"], ["mx250f", "single", 2, "MX 250F", "BO"],
	["gt", "fr", 3, "GT Coupe", "CR"], ["rallycoupe", "awd", 3, "Rally Coupe", "CO"], ["sbk", "inline4", 3, "Superbike", "BR"], ["mx450", "single", 3, "MX 450", "BO"],
	["formula", "mr", 4, "Formula", "CR"], ["trophy", "awd", 4, "Trophy Truck", "CO"], ["motogp", "inline4", 4, "GP Prototype", "BR"], ["factorymx", "single", 4, "Factory MX", "BO"],
]
const TARGET_ODDS := 1.04
const TIER_DRIVER := [0, 40, 130, 320, 640, 900]

var player := {"name": "Ace Gasket", "team": "Top Prix Racing", "col": "#e8432f", "mode": "standard"}
var garage: Array = []
var sel := 0

func _ready() -> void:
	load_profile()
	if garage.is_empty():
		garage = presets()
		save_profile()

# ---------------- presets ----------------
func presets() -> Array:
	var out := []
	for p in PRESETS:
		if Data.body(p[0]).is_empty() or Data.layout(p[1]).is_empty(): continue
		var tier: int = p[2]
		var v := Prof.make_vehicle(p[0], p[1], 5 + tier, 1.1)
		var dv: int = TIER_DRIVER[tier]
		var d := Prof.make_driver(player.name, dv, dv, dv)
		var ctx := {"tech": {}, "partLv": {}}
		var ref := ref_race(p[4], tier)
		if not ref.is_empty(): _calibrate(v, d, ctx, ref)
		out.append({"label": p[3], "tier": tier, "disc": p[4], "veh": v, "drv": d, "ctx": ctx, "src": "preset"})
	return out

## Median-rated race of a discipline and tier: the yardstick a preset is tuned against.
static func ref_race(disc: String, tier: int) -> Dictionary:
	var pool: Array = Data.D.RACES.filter(func(r): return r.disc == disc and int(r.tier) == tier)
	if pool.is_empty(): return {}
	pool.sort_custom(func(a, b): return float(a.R) < float(b.R))
	return pool[pool.size() / 2]

## Spend upgrade points until the machine runs just ahead of mid-field in its reference race
## and has the durability to finish it.
func _calibrate(v: Dictionary, d: Dictionary, ctx: Dictionary, ref: Dictionary) -> void:
	var lvm := 1.0 + 0.03 * (int(v.lv) - 1)
	for _i in 6:
		var o := odds({"veh": v, "drv": d, "ctx": ctx}, ref)
		var ratio: float = TARGET_ODDS / max(o, 0.01)
		if absf(ratio - 1.0) < 0.01: break
		var st := Prof.vs(v, ctx)
		for k in ["spd", "acc", "hnd"]:
			v.upAdd[k] = int(v.upAdd[k]) + int(round(st[k] * (ratio - 1.0) / lvm))
	var st2 := Prof.vs(v, ctx)
	var top := 0.0
	for r in Data.D.RACES:
		if r.disc == ref.disc and int(r.tier) == int(ref.tier): top = max(top, float(r.R))
	var want := top * 1.0
	if st2.dur < want: v.upAdd.dur = int(v.upAdd.dur) + int(round((want - st2.dur) / lvm))

## Story/career machines join the garage (first), so cars you build in story mode race in multiplayer.
func refresh_story_slots() -> void:
	var career := get_node_or_null("/root/Career")
	var keep := garage.filter(func(s): return s.get("src", "") != "story")
	var story := []
	if career and typeof(career.get("G")) == TYPE_DICTIONARY and career.G.has("vehicles"):
		var G: Dictionary = career.G
		var drivers: Array = G.get("staff", []).filter(func(s): return s.get("role", "") == "drv")
		for v in G.vehicles:
			if v.get("status", "") != "ready" or drivers.is_empty(): continue
			var cls: String = Data.body(v.body).cls
			var best = drivers[0]
			var bs := -1.0
			for d in drivers:
				var sc := (float(d.pedal) + float(d.shift) + float(d.steer)) * float(d.get("aff", {}).get(cls, 1.0))
				if sc > bs: bs = sc; best = d
			story.append({"label": v.name, "tier": 0, "veh": v, "drv": best, "ctx": {"tech": G.get("tech", {}), "partLv": G.get("partLv", {})}, "src": "story"})
	var cur: Dictionary = slot() if not garage.is_empty() else {}
	garage = story + keep
	sel = maxi(0, garage.find(cur)) if not cur.is_empty() else 0

## Multiplayer classes: in a tier class, machines above the tier's top rating are pegged down to it.
static func class_cap(tier: int) -> float:
	var top := 0.0
	for r in Data.D.RACES:
		if int(r.tier) == tier: top = max(top, float(r.R))
	return top * 1.05

static func cap_entry(e: Dictionary, tier: int) -> void:
	var p: Dictionary = e.prof
	var avg: float = (float(p.S) + float(p.A) + float(p.H)) / 3.0
	var cap := class_cap(tier)
	if avg > cap:
		var k := cap / avg
		p.S = p.S * k; p.A = p.A * k; p.H = p.H * k
		e.capped = true

func slot(i: int = -1) -> Dictionary:
	if garage.is_empty(): return {}
	return garage[clampi(sel if i < 0 else i, 0, garage.size() - 1)]

## Slot as raced: preset machines are driven by you (your profile name).
func race_slot(i: int = -1) -> Dictionary:
	var s := slot(i).duplicate(true)
	if s.get("src", "") == "preset": s.drv.name = player.name
	return s

func cls_of(s: Dictionary) -> String:
	return Data.body(s.veh.body).cls

# ---------------- race entries ----------------
## Human entry for RaceSim.create from a garage slot (also used by the LAN host for remote slots).
static func make_entry(s: Dictionary, track: Dictionary, owner: int, team: String, team_key: String, col: String, tactic := "normal") -> Dictionary:
	var v: Dictionary = s.veh
	var d: Dictionary = s.drv
	var ctx: Dictionary = s.get("ctx", {})
	var b: Dictionary = Data.body(v.body)
	var cyl = Data.D.LAYOUT_CYL.get(v.layout, 4)
	return {"name": d.name, "team": team, "team_key": team_key, "col": col, "kind": b.kind, "cls": b.cls,
		"prof": Prof.profile(v, d, ctx), "sk": Prof.race_secs(v, track, ctx), "hp": float(v.get("hp", 1.0)),
		"cond": float(v.get("eng", {}).get("cond", 1.0)), "cyl": int(cyl), "owner": owner, "tactic": tactic,
		"rt": clampf(0.2 - (float(d.get("shift", 0)) + float(d.get("analysis", 0))) / 1200.0, 0.02, 0.2),
		"sparks": {"b": 2, "s": 1, "g": 0}, "machine": s.get("label", b.n)}

## Expected pace vs the rival field (1.0 = mid-pack), like the web build's odds meter.
static func odds(s: Dictionary, race: Dictionary, mode := "standard") -> float:
	var track := RaceSim.build_track(race, false)
	var p := Prof.profile(s.veh, s.drv, s.get("ctx", {}))
	var sk := Prof.race_secs(s.veh, track, s.get("ctx", {}))
	var rt := RaceSim.rival_terr(race)
	var tot := 0.0; var rv := 0.0
	for i in track.secs.size():
		var sc: Dictionary = track.secs[i]
		var w: Array = Data.D.SEC[sc.type].w
		var tk: String = Data.D.SURF[sc.surf].k
		var k: Dictionary = sk[i]
		tot += ((w[0] * p.S * k.s + w[1] * p.A * k.a) * k.ef + w[2] * p.H * k.h) * (clampf(p.t[tk] * k.t, 5, 220) / 100.0) * p.pm * sc.len
		rv += float(race.R) * RaceSim.rival_mul(mode) * (rt[tk] + 1) / 100.0 * sc.len
	return tot / max(rv, 0.001)

# ---------------- web career import ----------------
## Paste the web build's export code (GG1:...). Imports every ready vehicle, paired with its best driver.
func import_web(code: String) -> int:
	var raw := code.strip_edges().replace("GG1:", "").replace("\n", "").replace(" ", "")
	var txt := Marshalls.base64_to_utf8(raw)
	var G = JSON.parse_string(txt)
	if typeof(G) != TYPE_DICTIONARY or not G.has("vehicles"): return -1
	var ctx := {"tech": G.get("tech", {}), "partLv": G.get("partLv", {})}
	var drivers: Array = G.staff.filter(func(s): return s.get("role", "") == "drv")
	if drivers.is_empty(): return 0
	garage = garage.filter(func(s): return s.src != "web")
	var n := 0
	for v in G.vehicles:
		if v.get("status", "") != "ready": continue
		var cls: String = Data.body(v.body).cls
		var best = drivers[0]
		var bs := -1.0
		for d in drivers:
			var sc := (float(d.pedal) + float(d.shift) + float(d.steer)) * float(d.get("aff", {}).get(cls, 1.0))
			if sc > bs: bs = sc; best = d
		garage.insert(n, {"label": v.name, "tier": 0, "veh": v, "drv": best, "ctx": ctx, "src": "web"})
		n += 1
	if G.has("team"):
		player.team = G.team.get("name", player.team)
		player.col = G.team.get("color", player.col)
	sel = 0
	save_profile()
	return n

# ---------------- persistence ----------------
func save_profile() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"player": player, "garage": garage, "sel": sel}))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY: return
	player.merge(d.get("player", {}), true)
	garage = d.get("garage", [])
	sel = int(d.get("sel", 0))
