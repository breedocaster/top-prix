extends "res://scripts/ui/career/sub_screen.gd"
## Settings: difficulty (Data.D.MODES via Career.setMode), auto-retire, sound, game speed, save export
## as a GG1 code (Career.exportCode, copied to the clipboard), import a code (Career.load_json), how to
## play, and quit to title (router.open("title") when a router is present, else ctx.quit_to_title =
## true and `closed`). ctx: {router?}

signal loaded()                  ## a save was imported (the career state was replaced)

var export_box: TextEdit = null
var import_box: TextEdit = null
var show_export := false
var show_import := false
var import_text := ""

const HELP := [
	"BUILD cars or bikes from researched bodies. Mechanics' Tech sets build quality and speed.",
	"UPGRADE Speed / Accel / Handling / Durability up to 5x each, and fit PARTS in free slots.",
	"Match the vehicle to the surface: On-Rd, Off-Rd, Wet and Icy grip all matter.",
	"Drivers: Pedal -> speed, Shift -> accel, Steer -> handling. Train them with money + energy.",
	"Win normal races to unlock a SERIES; win a series to move to a bigger workshop.",
	"Sign SPONSORS and finish their goals to unlock training, layouts, parts and facilities.",
	"TUNE the engine on the bench: jets, needles and floats on carbs, VE / spark tables on EFI.",
	"SPARKS (first podiums and titles) boost a race, build, upgrade or training session.",
]

const CREDITS := [
	"Music: original compositions for Top Prix.",
	"Instrument samples: MuseScore_General by S. Christian Collins and Fluid (R3) GM by Frank Wen, both MIT license (parts public domain / CC0). Full notices: audio/CREDITS.md in the game files.",
	"Engine sounds and effects synthesized for the game.",
]

func _title() -> String: return "Settings"

func _sig() -> String: return str(Career.G.settings) + str(Career.G.team)

func _fill(b: VBoxContainer) -> void:
	var S: Dictionary = Career.G.settings
	var m := Tune.mode()
	# difficulty
	var dv := SK.card(b)
	dv.add_child(SK.big("Difficulty", SK.HL))
	var ch := UIKit.hbox(2)
	for k in Data.D.MODES:
		ch.add_child(SK.act(SK.chip(str(Data.D.MODES[k].n).to_upper(), m == k, _mode.bind(k)), "mode:" + k))
	dv.add_child(ch)
	dv.add_child(SK.small(Data.D.MODES[m].d, SK.SUB))
	dv.add_child(SK.small("Change any time.", SK.DIM))
	# team name + colour (changeable any time)
	var tm := SK.card(b)
	tm.add_child(SK.big("Team", SK.HL))
	var nh := UIKit.hbox(3)
	var ne := LineEdit.new()
	ne.text = str(Career.G.team.name)
	ne.max_length = 22
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_submitted.connect(func(_t): _rename(ne))
	nh.add_child(ne)
	nh.add_child(SK.act(SK.sbtn("RENAME", _rename.bind(ne), UIKit.BTN, 64), "rename"))
	tm.add_child(nh)
	tm.add_child(SK.small("Colour", Color.WHITE, false))
	tm.add_child(UIKit.swatches(str(Career.G.team.color), _team_col))
	# toggles
	var tv := SK.card(b)
	tv.add_child(SK.big("Game", SK.HL))
	tv.add_child(_toggle("Auto-retire", "Retire at 8% durability so a vehicle is never destroyed.", bool(S.get("autoRetire", true)), "autoRetire"))
	tv.add_child(_toggle("Menu sounds", "Clicks and jingles in the garage.", bool(S.get("sound", true)), "sound"))
	var sp := UIKit.hbox(3)
	var sl := SK.small("Game speed", Color.WHITE, false)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.add_child(sl)
	for x in [1, 2, 4]:
		var c := SK.act(SK.chip("%dX" % x, int(S.get("speed", 1)) == x, _speed.bind(x)), "speed:%d" % x)
		c.size_flags_horizontal = Control.SIZE_SHRINK_END
		c.custom_minimum_size = Vector2(30, 0)
		sp.add_child(c)
	tv.add_child(sp)
	# save
	var sv := SK.card(b)
	sv.add_child(SK.big("Save code", SK.HL))
	sv.add_child(SK.small("Export a GG1 code to move this career to another device (web or Godot), or paste one to load it.", SK.SUB))
	var bh := UIKit.hbox(3)
	bh.add_child(SK.act(SK.btn("EXPORT", _toggle_export, UIKit.BTN, true), "export"))
	bh.add_child(SK.act(SK.btn("IMPORT", _toggle_import, UIKit.BTN, true), "import"))
	sv.add_child(bh)
	if show_export:
		export_box = _text_box(Career.exportCode(), false)
		sv.add_child(export_box)
		sv.add_child(SK.act(SK.btn("COPY TO CLIPBOARD", _copy, SK.GREEN, true), "copy"))
	if show_import:
		import_box = _text_box(import_text, true)
		import_box.placeholder_text = "Paste a GG1: code here"
		import_box.text_changed.connect(_import_changed)
		sv.add_child(import_box)
		var ih := UIKit.hbox(3)
		ih.add_child(SK.act(SK.btn("PASTE", _paste, UIKit.BTN, true), "paste"))
		ih.add_child(SK.act(SK.btn("LOAD", _ask_load, SK.RED, true), "load"))
		sv.add_child(ih)
		sv.add_child(SK.small("Loading replaces the current career.", SK.BD))
	# volume
	var av := SK.card(b)
	av.add_child(SK.big("Sound", SK.HL))
	av.add_child(UIKit.volume_sliders(96))
	# help
	var hv := SK.card(b)
	hv.add_child(SK.big("How to play", SK.HL))
	for l in HELP: hv.add_child(SK.small("- " + l, SK.SUB))
	hv.add_child(SK.act(SK.btn("OPEN THE HOW-TO GUIDE", _guide, SK.GREEN, true), "guide"))
	hv.add_child(SK.small("21 topics, each in Simple and Detailed. Also on the ? in the garage and the GUIDE button on the bench.", SK.DIM))
	# credits (the soundfonts' MIT notice ships in the build as audio/CREDITS.md)
	var cv := SK.card(b)
	cv.add_child(SK.big("Credits", SK.HL))
	for l in CREDITS: cv.add_child(SK.small(l, SK.SUB))
	# quit
	b.add_child(SK.act(SK.btn("QUIT TO TITLE", _ask_quit, SK.RED), "quit"))

func _guide() -> void:
	if router: router.open("guide", {})

func _rename(ne: LineEdit) -> void:
	var t := ne.text.strip_edges()
	if t == "" or t == str(Career.G.team.name): return
	Career.G.team.name = t
	CareerScreen.save_game()
	say("Team renamed to %s" % t)
	rebuild()

func _team_col(hex: String) -> void:
	Career.G.team.color = hex
	CareerScreen.save_game()
	rebuild()

func _toggle(label: String, desc: String, on: bool, key: String) -> Control:
	var h := UIKit.hbox(4)
	var lv := UIKit.vbox(1)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(SK.small(label, Color.WHITE, false))
	if desc != "": lv.add_child(SK.small(desc, SK.DIM))
	h.add_child(lv)
	var bt := SK.act(SK.sbtn("ON" if on else "OFF", _flip.bind(key), SK.GREEN if on else SK.GREY, 44), "toggle:" + key)
	bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bt)
	return h

func _text_box(text: String, editable: bool) -> TextEdit:
	var t := TextEdit.new()
	t.text = text
	t.editable = editable
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.custom_minimum_size = Vector2(0, 72)
	t.add_theme_font_override("font", UIKit.font8)
	t.add_theme_font_size_override("font_size", 8)
	t.add_theme_stylebox_override("normal", UIKit.frame_new("inset", 4, 3, 4, 3))
	t.add_theme_stylebox_override("focus", UIKit.frame_new("msg", 4, 3, 4, 3))
	t.add_theme_stylebox_override("read_only", UIKit.frame_new("lcd", 4, 3, 4, 3))
	t.add_theme_color_override("font_color", Color.WHITE)
	t.add_theme_color_override("font_readonly_color", SK.BL)
	return t

# ---------------- actions ----------------
func _mode(k: String) -> void:
	Career.setMode(k)
	say("Difficulty: " + str(Data.D.MODES[k].n))
	rebuild()

func _flip(key: String) -> void:
	Career.G.settings[key] = not bool(Career.G.settings.get(key, true))
	rebuild()

func _speed(x: int) -> void:
	Career.G.settings.speed = x
	rebuild()

func _toggle_export() -> void:
	show_export = not show_export
	rebuild()

func _toggle_import() -> void:
	show_import = not show_import
	rebuild()

func _copy() -> void:
	DisplayServer.clipboard_set(Career.exportCode())
	say("Save code copied!")

func _paste() -> void:
	import_text = DisplayServer.clipboard_get()
	if import_box: import_box.text = import_text

func _import_changed() -> void:
	if import_box: import_text = import_box.text

func _ask_load() -> void:
	if import_text.strip_edges() == "":
		say("Paste a save code first")
		return
	confirm("Load this save?", "This replaces your current career with the one in the code.", "LOAD", _load)

## Loads `import_text`; true on success.
func _load() -> bool:
	if Career.load_json(import_text):
		say("Save loaded!")
		import_text = ""
		show_import = false
		loaded.emit()
		rebuild(true)
		return true
	say("That code did not work")
	return false

func _ask_quit() -> void:
	confirm("Quit to title?", "Leave this career and go back to the title screen.", "QUIT", _quit)

func _quit() -> void:
	if go("title", {}): return
	ctx.quit_to_title = true
	closed.emit()
