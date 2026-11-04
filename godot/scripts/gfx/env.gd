class_name Env
extends RefCounted
## Scenery themes. Picked from the track's main surface (like the web build's GX.ENV),
## with hillclimbs moved to the mountains.

const MAP := {"tar": "stadium", "wet": "stadium", "dirt": "country", "mud": "swamp", "sand": "desert", "snow": "snow", "ice": "snow"}

const THEMES := {
	"stadium": {"sky": ["#3a7fd8", "#b6e2fa"], "far": "#6c8fae", "mid": "#58789a", "near": "stands",
		"ground": ["#3f8f3a", "#4a9c42", "#6fbf55", 0], "fog": "#bfe0f2", "props": ["tires", "oak", "marker", "tires"]},
	"country": {"sky": ["#4aa6e6", "#cdebf8"], "far": "#7d9fb0", "mid": "#4f8a55", "near": "trees",
		"ground": ["#5f9a3e", "#6ea648", "#8fbf5a", 1], "fog": "#d2ecf6", "props": ["oak", "hay", "pine", "oak"]},
	"swamp": {"sky": ["#6f8a7e", "#c2d2bf"], "far": "#55705f", "mid": "#3f5d47", "near": "trees",
		"ground": ["#4c6a3a", "#5a5a32", "#6f8a4a", 1], "fog": "#b8c8b4", "props": ["oak", "pine", "rock"]},
	"desert": {"sky": ["#e8904a", "#fde0a6"], "far": "#c98a52", "mid": "#b8743f", "near": "mesas",
		"ground": ["#d9b060", "#cfa452", "#e8c47a", 2], "fog": "#f6dcae", "props": ["cactus", "rock", "cactus", "tires"]},
	"snow": {"sky": ["#9ab8d2", "#eef5fa"], "far": "#c8d6e2", "mid": "#a9bccb", "near": "pines",
		"ground": ["#e6eef6", "#d6e2ee", "#ffffff", 3], "fog": "#eef4fa", "props": ["snowpine", "snowpine", "rock"]},
	"mountain": {"sky": ["#2f7fd0", "#bfe2f7"], "far": "#7b8ea6", "mid": "#4d6b57", "near": "pines",
		"ground": ["#5d8a46", "#7a7a62", "#8f9a6a", 1], "fog": "#cfe6f4", "props": ["pine", "rock", "pine", "marker"]},
	"night": {"sky": ["#0b1030", "#26305a"], "far": "#1b2445", "mid": "#141b38", "near": "stands",
		"ground": ["#1f3f2a", "#22462e", "#2f5a3a", 0], "fog": "#1a2240", "props": ["tires", "marker"]},
	"rain": {"sky": ["#5b6b7a", "#9aa6b0"], "far": "#6a7a88", "mid": "#4f6270", "near": "stands",
		"ground": ["#3c6e3a", "#447a40", "#5a8a50", 0], "fog": "#8a96a2", "props": ["tires", "oak", "marker"]},
}

const SURF_COL := {"tar": "#5d5f68", "wet": "#4a5870", "dirt": "#a2683a", "sand": "#d9b45c", "mud": "#6b4a2b", "snow": "#dfe8f2", "ice": "#a9dcf0"}
const VERGE_COL := {"tar": "#c9b37a", "wet": "#a99a6a", "dirt": "#7d5030", "sand": "#b8934a", "mud": "#4f3520", "snow": "#b8c8d8", "ice": "#c8e4f0"}

static func pick(track: Dictionary, cond: Dictionary, rain: bool) -> String:
	var env: String = MAP.get(RaceSim.main_surf(track), "stadium")
	if track.hill and env != "snow": env = "mountain"
	if cond.get("tod", "day") == "night": return "night"
	if rain: return "rain"
	return env

static func theme(name: String) -> Dictionary:
	return THEMES.get(name, THEMES.stadium)
