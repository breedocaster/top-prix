extends Node
## Game content, exported from the web build (web/tools/export_godot.js).
## Keys mirror the JS `D` object: BODY, LAYOUT, PART, RACE, SEC, SURF, STYLES, RIVALS, ...

var D: Dictionary = {}

func _init() -> void:
	var f := FileAccess.open("res://data/game_data.json", FileAccess.READ)
	assert(f != null, "missing data/game_data.json — run node web/tools/export_godot.js")
	D = JSON.parse_string(f.get_as_text())

func body(id: String) -> Dictionary: return D.BODY.get(id, {})
func layout(id: String) -> Dictionary: return D.LAYOUT.get(id, {})
func part(id: String) -> Dictionary: return D.PART.get(id, {})
func race(id: String) -> Dictionary: return D.RACE.get(id, {})
func sec(t: String) -> Dictionary: return D.SEC[t]
func surf(s: String) -> Dictionary: return D.SURF[s]
func formats(race_id: String) -> Array: return D.FORMATS.get(race_id, [])
## Formats the Godot race flow runs today: heats and the 8-car drag ladder come with the career port.
func formats_m1(race_id: String) -> Array:
	var out := []
	for f in formats(race_id):
		if f.kind == "heats": continue
		if f.kind == "drag":
			f = f.duplicate(); f.n = "Head-to-head run"
		out.append(f)
	return out

func cond(race_id: String) -> Dictionary: return D.CONDS.get(race_id, {"alt": 200, "alt2": 200, "temp": 18, "tod": "day"})

## Races usable for a vehicle class ("car"/"bike"); DR/HC/OP allow both.
func races_for(cls: String) -> Array:
	var out := []
	for r in D.RACES:
		if r.cls == cls or r.cls == "any" or r.cls == "" or r.cls == null:
			out.append(r)
	return out

func race_cls_ok(r: Dictionary, cls: String) -> bool:
	return r.cls == cls or r.cls == "any" or r.cls == "" or r.cls == null

## Color helper: "#rrggbb" -> Color
static func col(hex: String) -> Color:
	return Color.html(hex)
