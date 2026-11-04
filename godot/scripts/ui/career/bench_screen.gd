extends "res://scripts/ui/career/sub_screen.gd"
## Tuning bench (port of the web carb bench, EFI laptop, sync, dyno and setup sheet; web/src/ui2.js +
## tunegfx.js). ctx: {router?, vid, tab?: "carb"|"efi"|"sync"|"dyno"|"setup", cond?: Dictionary
## (e.g. a test day's conditions), race_id?: tune for this race's forecast, resume_label?/resume_btn?:
## show a "go back to the race" banner (pressing it sets ctx.resumed and emits closed)}.
## Animated canvases redraw every frame; nodes are rebuilt only when the structure changes, and
## stepper values / zone table / symptoms are updated in place after each adjustment.

const BG := preload("res://scripts/ui/career/bench_gfx.gd")
const KIT := preload("res://scripts/ui/career/sub_kit.gd")
const ZoneTable := preload("res://scripts/ui/career/zone_table.gd")

var vid
var v: Dictionary = {}
var bs: Dictionary = BG.new_state()
var cond: Dictionary = {}
var cond_race := ""
var cond_tag := ""
var ev: Dictionary = {}
var rich: Dictionary = {}
var etab := "ve"
var cells := {}                ## "j,i" -> true (EFI selection)
var dt := 0.0
# live widgets
var vals := {}                 ## key -> value Label of a stepper
var zone_tab = null
var symp_lbl: Label = null
var plug_lbl: Label = null
var hint_lbl: Label = null
var grid: Control = null
var canvases: Array = []
var dyno_btn: Button = null
var chart: Control = null
var dyno_sprite: Control = null
var _mat: ShaderMaterial = null

func _title() -> String: return "Bench"

func _tabs() -> Array:
	if v.is_empty(): return []
	var t := []
	var e = v.get("eng")
	if e != null and e.fuel == "efi": t.append(["efi", "EFI"])
	elif e != null and e.fuel == "carb": t.append(["carb", "CARBS"])
	else: t.append(["carb", "MOTOR"])
	if e != null and e.fuel != "none" and Tune.nCarbs(v) > 1: t.append(["sync", "SYNC"])
	t.append(["dyno", "DYNO"])
	t.append(["setup", "SETUP"])
	return t

func _init_screen() -> void:
	vid = ctx.get("vid")
	v = Career.veh(vid)
	if v.is_empty() and not Career.G.vehicles.is_empty():
		v = Career.G.vehicles[0]; vid = v.id
	var want := str(ctx.get("tab", ""))
	if want == "carb" or want == "efi" or want == "fuel" or want == "":
		tab = _tabs()[0][0] if not v.is_empty() else ""
	elif _tabs().any(func(x): return x[0] == want): tab = want
	else: tab = _tabs()[0][0] if not v.is_empty() else ""
	# router aliases (race screen passes rid/resume)
	if ctx.has("rid") and not ctx.has("race_id"): ctx.race_id = ctx.rid
	if ctx.get("resume") is String and not ctx.has("resume_label"): ctx.resume_label = "Back to " + str(ctx.resume)
	if ctx.get("cond") is Dictionary and not ctx.cond.is_empty():
		cond = ctx.cond
		cond_tag = "test"
	elif ctx.get("race_id") and Data.D.RACE.has(str(ctx.race_id)):
		cond_race = str(ctx.race_id)
		cond = Tune.forecast(Data.D.RACE[cond_race])
	else:
		cond = Tune.SHOP()
	var tc := Color(str(Career.G.team.color))
	_mat = SK.swap_material(SpriteForge.palette([tc]))
	_eval()

func _sig() -> String:
	if v.is_empty(): return ""
	var e = v.get("eng")
	return "%s|%s|%s|%d|%s" % [v.status, str(e.fuel) if e != null else "", str(e.get("carb", "")) if e != null else "", Career.facLv("dyno"), str(Career.G.tech.size())]

func _eval() -> void:
	if v.is_empty() or v.get("eng") == null: return
	ev = Tune.eval(v, cond)
	rich = Tune.carbRich(v) if v.eng.fuel == "carb" else {}

func _ready_ok() -> bool: return v.get("status", "") == "ready"

# ======================================================================
# build
# ======================================================================
func _fill(b: VBoxContainer) -> void:
	vals.clear()
	canvases.clear()
	zone_tab = null; symp_lbl = null; plug_lbl = null; hint_lbl = null; grid = null; dyno_btn = null; dyno_sprite = null; chart = null
	if v.is_empty():
		SK.note(b, "No vehicle to tune. Build one first!", SK.HL)
		return
	set_title("Bench")
	_eval()
	if ctx.get("resume_label"): _resume_banner(b)
	_veh_line(b)
	match tab:
		"carb", "efi":
			if v.eng.fuel == "carb": _fill_carb(b)
			elif v.eng.fuel == "efi": _fill_efi(b)
			else: SK.note(b, "Electric drive - nothing to jet or map. Lucky you. Check the Setup tab.", SK.HL)
		"sync": _fill_sync(b)
		"dyno": _fill_dyno(b)
		"setup": _fill_setup(b)

func _resume_banner(b: VBoxContainer) -> void:
	var v2 := SK.card(b, "sel")
	var h := UIKit.hbox(4)
	h.add_child(SK.small(str(ctx.resume_label), SK.HL))
	h.add_child(SK.act(SK.sbtn(str(ctx.get("resume_btn", "GO")), _resume, SK.GREEN), "resume"))
	v2.add_child(h)

func _resume() -> void:
	ctx.resumed = true
	closed.emit()

func _veh_line(b: VBoxContainer) -> void:
	var e = v.get("eng")
	var cyl := Tune.cyl(v)
	var fuel := "Electric"
	if e != null and e.fuel == "efi": fuel = "EFI  %d CYL" % cyl
	elif e != null and e.fuel == "carb": fuel = "%s x%d" % [str(Data.D.CARBS[e.carb].n).split(" (")[0], Tune.nCarbs(v)]
	var v2 := SK.card(b)
	var h := UIKit.hbox(4)
	h.add_child(SK.big(v.name, Color.WHITE))
	if not _ready_ok(): h.add_child(SK.tag(str(v.status).to_upper(), SK.BD))
	v2.add_child(h)
	var line := fuel
	if e != null and e.fuel != "none": line += "  ENG %d%%" % int(roundf(float(e.cond) * 100))
	v2.add_child(SK.small(line, SK.SUB))
	if not _ready_ok(): v2.add_child(SK.small("Vehicle must be Ready to change the tune.", SK.BD))

func _cond_line(c: Dictionary) -> String:
	var s := "%dC  %dM" % [int(float(c.temp)), int(float(c.alt))]
	if float(c.alt2) != float(c.alt): s += "->%dM" % int(float(c.alt2))
	s += "  AIR %d%%" % int(roundf(float(c.rho) * 100))
	if float(c.alt2) != float(c.alt): s += "->%d%%" % int(roundf(float(c.rho2) * 100))
	if c.get("tod") == "night": s += "  NIGHT"
	return s

func _cond_chips(b: VBoxContainer, label := "TUNING FOR") -> void:
	var v2 := SK.card(b, "note")
	var h := UIKit.hbox(2)
	var l := SK.small(label, SK.SUB, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v2.add_child(l)
	h.add_child(SK.act(SK.chip("SHOP", cond_race == "" and cond_tag == "", _cond_shop), "cond:shop"))
	if cond_tag == "test":
		h.add_child(SK.act(SK.chip(str(cond.get("name", "Test")), true, func(): pass), "cond:test"))
	if cond_race != "":
		h.add_child(SK.act(SK.chip(Data.D.RACE[cond_race].n, cond_tag == "", _cond_race), "cond:race"))
	h.add_child(SK.act(SK.chip("PICK RACE", false, _cond_pick), "cond:pick"))
	v2.add_child(h)
	v2.add_child(SK.small(_cond_line(cond), SK.BL))

func _cond_shop() -> void:
	cond = Tune.SHOP(); cond_race = ""; cond_tag = ""
	rebuild()

func _cond_race() -> void:
	cond = Tune.forecast(Data.D.RACE[cond_race]); cond_tag = ""
	rebuild()

func _cond_pick() -> void:
	var items := []
	for id in Career.availRaceIds():
		if Data.D.RACE.has(id): items.append([id, Data.D.RACE[id].n])
		if items.size() >= 30: break
	if items.is_empty():
		say("No races open yet")
		return
	pick("Tune for which event?", items, _cond_picked)

func _cond_picked(id) -> void:
	cond_race = str(id); cond_tag = ""
	cond = Tune.forecast(Data.D.RACE[cond_race])
	rebuild()

## Stepper registered for in-place updates.
func _step(b: Control, key: String, label: String, value: String, desc: String, cb: Callable, dis := false, light := false) -> Control:
	var st := SK.stepper(label, value, desc, cb, dis, light)
	SK.act(st.get_meta("minus"), "dec:" + key)
	SK.act(st.get_meta("plus"), "inc:" + key)
	vals[key] = st.get_meta("value")
	b.add_child(st)
	return st

# ---------------- zone table + symptoms ----------------
func _zone_card(b: VBoxContainer, wb: bool) -> void:
	var c := SK.card(b)
	var zt := ZoneTable.new(ev.lam, ev.kd, wb)
	c.add_child(zt)
	zone_tab = zt
	if v.eng.fuel == "carb":
		if wb: c.add_child(SK.small("Target ~12.8 WOT / 12.9 mid / 13.2 low", SK.DIM))
		else:
			c.add_child(SK.small("No wideband - read plugs and symptoms. (Tech: Wideband O2)", SK.DIM))
			plug_lbl = SK.small("", SK.HL)
			c.add_child(plug_lbl)
	symp_lbl = SK.small("", Color.WHITE)
	c.add_child(symp_lbl)
	_update_live()

func _update_live() -> void:
	if v.is_empty() or v.get("eng") == null or v.eng.fuel == "none": return
	if zone_tab != null:
		zone_tab.set_data(ev.lam, ev.kd)
	if symp_lbl != null:
		var sy := Tune.symptoms(ev, v.eng.fuel == "efi")
		var t := ""
		for x in sy: t += ("\n" if t != "" else "") + "- " + SK.ascii(x)
		symp_lbl.text = t
	if plug_lbl != null:
		plug_lbl.text = "Plug chop (WOT): %s" % Tune.plug(float(ev.lam.wot))[0]
	if grid != null: grid.queue_redraw()
	if chart != null: chart.queue_redraw()
	_update_hint()

## After any tune change: re-evaluate and refresh values in place.
func _changed() -> void:
	_eval()
	_refresh_vals()
	_update_live()
	update_head()

func _refresh_vals() -> void:
	var e = v.get("eng")
	if e == null: return
	if e.fuel == "carb":
		var C_: Dictionary = Data.D.CARBS[e.carb]
		for p in C_.p:
			if vals.has("jet:" + p.k): vals["jet:" + p.k].text = _jet_val(p)
	if vals.has("timing"): vals.timing.text = "%s%d" % ["+" if int(e.timing) > 0 else "", int(e.timing)]
	for i in e.sync.size():
		if vals.has("sync:%d" % i): vals["sync:%d" % i].text = _sync_val(i)
	if vals.has("ae") and e.fuel == "efi": vals.ae.text = "%d%%" % int(e.efi.ae)
	for k in ["f", "r", "fd", "susp", "psi", "wing"]:
		if vals.has("set:" + k): vals["set:" + k].text = _set_val(k)

func _log_card(b: VBoxContainer, lg: Dictionary) -> void:
	b.add_child(SK.section("Last datalog"))
	var c := SK.card(b)
	c.add_child(SK.small("%s - %s" % [lg.src, Career.dateStr(int(lg.d))], SK.HL))
	c.add_child(SK.small(str(lg.cond), SK.DIM))
	c.add_child(ZoneTable.new(lg.lam, lg.kd, bool(lg.get("wb", false))))
	if float(lg.get("imb", 0)) > 1.2: c.add_child(SK.small("Carbs out of sync at the time", SK.HL))

func _fuel_chips(b: VBoxContainer) -> void:
	var e: Dictionary = v.eng
	var h := UIKit.hbox(2)
	var l := SK.small("FUEL", SK.SUB, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(l)
	for k in Data.D.FUELS:
		var F: Dictionary = Data.D.FUELS[k]
		var ok: bool = not F.get("tech") or Tune.has(F.tech)
		h.add_child(SK.act(SK.chip(str(F.n).to_upper(), str(e.get("fuelT", "pump")) == k, _fuel.bind(k), not ok), "fuel:" + k))
	b.add_child(h)
	if str(e.get("fuelT", "pump")) == "e85":
		b.add_child(SK.small("E85 needs ~32% more fuel. Jet up a lot!" if e.fuel == "carb" else ("Flex sensor adjusts the EFI automatically." if Tune.has("e85") else ""), SK.HL))

func _fuel(k: String) -> void:
	Career.setFuelT(vid, k)
	_eval()
	rebuild()

# ======================================================================
# carb bench
# ======================================================================
class CarbView extends Control:
	var bench
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, 176)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var ox := floorf((size.x - 240) / 2)
		BG.draw_carb(self, Vector2(ox, 0), bench.v, bench.ev, bench.rich, bench.bs, bench.dt)
		BG.draw_strip(self, Vector2(0, 152), size.x, bench.v, bench.ev, bench.bs)

## Static chart (redrawn only when the tune changes) with a per-frame throttle marker child.
class ChartView extends Control:
	var bench
	var marker: Control
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, 62)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker = ChartMarker.new()
		marker.bench = b
		marker.set_anchors_preset(Control.PRESET_FULL_RECT)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
	func _draw() -> void:
		BG.draw_chart(self, Vector2.ZERO, size.x, bench.ev, bench.bs)

class ChartMarker extends Control:
	var bench
	func _draw() -> void:
		BG.draw_chart_marker(self, Vector2.ZERO, size.x, bench.bs)

## Drag anywhere on the track to set the throttle (stops a sweep).
class Throttle extends Control:
	var bench
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, 20)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(e: InputEvent) -> void:
		var x := -1.0
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed: x = e.position.x
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0: x = e.position.x
		if x >= 0:
			bench.bs.sweep = false
			bench.bs.thr = clampf((x - 4) / maxf(1.0, size.x - 8), 0.02, 1.0)
			accept_event()
	func _draw() -> void:
		var thr: float = bench.bs.thr
		draw_rect(Rect2(0, 0, size.x, size.y), BG.C("#0d1330"))
		draw_rect(Rect2(4, 8, size.x - 8, 4), BG.C("#1d2650"))
		draw_rect(Rect2(4, 8, floorf((size.x - 8) * thr), 4), BG.C("#ffd84a"))
		var kx := floorf(4 + (size.x - 8) * thr)
		draw_rect(Rect2(kx - 4, 2, 8, 16), BG.C("#140c24"))
		draw_rect(Rect2(kx - 3, 3, 6, 14), BG.C("#f2f2ee"))
		draw_rect(Rect2(kx - 1, 6, 2, 8), BG.C("#8a96b8"))
		BG.MiniFont.draw(self, "THROTTLE", Vector2(6, 1), BG.C("#8fa3d8"))

func _fill_carb(b: VBoxContainer) -> void:
	var e: Dictionary = v.eng
	var C_: Dictionary = Data.D.CARBS[e.carb]
	var wb := Tune.has("wideband")
	var n := Tune.nCarbs(v)
	_cond_chips(b)
	var cv := CarbView.new(self)
	b.add_child(cv)
	canvases.append(cv)
	var th := UIKit.hbox(3)
	var tr := Throttle.new(self)
	th.add_child(tr)
	canvases.append(tr)
	th.add_child(SK.act(SK.sbtn("SWEEP", _sweep, SK.GREEN if bs.sweep else UIKit.BTN, 48), "sweep"))
	th.add_child(SK.act(SK.sbtn("SNAP", _snap, UIKit.BTN, 40), "snap"))
	b.add_child(th)
	var ch := ChartView.new(self)
	b.add_child(ch)
	chart = ch
	canvases.append(ch.marker)
	_zone_card(b, wb)
	_fuel_chips(b)
	b.add_child(SK.section("%s%s" % [str(C_.n).split(" (")[0], (" x%d" % n) if n > 1 else ""]))
	var std := Tune.mode() == "standard"
	for p in C_.p:
		if std and not Tune.STD_KEYS.has(str(p.k)): continue
		_step(b, "jet:" + p.k, p.n, _jet_val(p), str(p.get("d", "")), _jet.bind(p.k), not _ready_ok())
	var tdesc := "Base timing vs. stock" if Tune.mode() == "sim" else "More advance = more power until it knocks. Hot days and pump gas knock sooner."
	if not std:
		_step(b, "timing", "Ignition advance", "%s%d" % ["+" if int(e.timing) > 0 else "", int(e.timing)], tdesc, _timing, not _ready_ok())
	else:
		b.add_child(SK.small("Standard: float, pump, power valve and timing are crew-set. Go too far and the crew resets it to a safe tune before the race.", SK.DIM))
		var why := Tune.danger(v, cond)
		if why != "": b.add_child(SK.small("CREW LIMIT: %s - they'll reset this before racing." % why, SK.RED))
	_crew_row(b, "RESET TO STOCK", _stock_jets, "stock")
	if n > 1:
		var sh := SK.small("%d carbs to balance - see the SYNC tab." % n, SK.HL)
		b.add_child(sh)
	if e.get("log") != null: _log_card(b, e.log)

func _jet_val(p: Dictionary) -> String:
	var x = v.eng.jets.get(p.k)
	var s := BG._jets_txt(x)
	if p.k == "clip": s = "#" + s
	return s + SK.ascii(str(p.get("u", "")))

func _crew_row(b: VBoxContainer, reset_label: String, reset_cb: Callable, reset_act: String) -> void:
	if Tune.mode() == "standard" and Tune.has("crewchief"):
		var cb := SK.act(SK.btn("CREW TUNE (%s)" % SK.money(Tune.crewCost()), _crew_tune, SK.GREEN, true, float(Career.G.money) < Tune.crewCost() or not _ready_ok()), "crew")
		b.add_child(cb)
	b.add_child(SK.act(SK.btn(reset_label, reset_cb, SK.GREY, true, not _ready_ok()), reset_act))
	if Tune.mode() == "standard" and not Tune.has("crewchief"):
		b.add_child(SK.small("Tech: Crew Chief Program lets the crew tune it for a fee.", SK.DIM))
	elif Tune.mode() == "easy":
		b.add_child(SK.small("Easy mode: the crew re-tunes before every race.", SK.GD))

func _jet(dir: int, k: String) -> void:
	Career.adjJet(vid, k, dir)
	Career.checkSpot(v, cond)
	_changed()

func _timing(dir: int) -> void:
	Career.adjTiming(vid, dir)
	_changed()

func _stock_jets() -> void:
	Career.resetJets(vid)
	_changed()

func _crew_tune() -> void:
	if Career.buyCrewTune(vid, cond):
		say("Crew tuned it for " + SK.ascii(cond.get("name", "the shop")))
		_changed()
		rebuild()

func _sweep() -> void:
	bs.sweep = not bs.sweep
	var b := SK.find_act(body, "sweep")
	if b: b.add_theme_stylebox_override("normal", UIKit.sb(SK.GREEN if bs.sweep else UIKit.BTN, UIKit.BG, 2, 4))

func _snap() -> void: BG.snap(bs)

# ======================================================================
# EFI laptop
# ======================================================================
## RPM x load table. Tap a cell to (de)select it, drag to paint the selection.
class VeGrid extends Control:
	var bench
	var paint := true
	const AX := 20.0
	const RH := 13.0
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, RH * 6 + 9)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
	func cw() -> float: return floorf((size.x - AX) / 8.0)
	func cell_at(p: Vector2) -> Vector2i:
		var i := int(floor((p.x - AX) / cw()))
		var r := int(floor(p.y / RH))
		if i < 0 or i > 7 or r < 0 or r > 5: return Vector2i(-1, -1)
		return Vector2i(5 - r, i)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var c := cell_at(e.position)
			if c.x >= 0:
				var k := "%d,%d" % [c.x, c.y]
				paint = not bench.cells.has(k)
				bench.set_cell(c.x, c.y, paint)
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var c2 := cell_at(e.position)
			if c2.x >= 0: bench.set_cell(c2.x, c2.y, paint)
			accept_event()
	func _draw() -> void:
		var v: Dictionary = bench.v
		var f: Dictionary = v.eng.efi
		var et: String = bench.etab
		var tb: Array = f.ve if et == "ve" else (f.ign if et == "ign" else f.afr)
		var rng: Array = [30.0, 120.0] if et == "ve" else ([5.0, 45.0] if et == "ign" else [11.0, 15.5])
		var lg = v.eng.get("log")
		var has_log: bool = lg is Dictionary and lg.get("cells") != null
		var w := cw()
		var bins: Array = Data.D.RPM_B[Data.D.BODY[v.body].cls]
		var ev: Dictionary = bench.ev
		for r in 6:
			var j := 5 - r
			var y := r * RH
			BG.MiniFont.draw(self, str(int(Data.D.LOAD_B[j])), Vector2(AX - 3, y + 4), BG.C("#334455"), 2)
			for i in 8:
				var val: float = float(tb[j][i])
				var nrm := clampf((val - rng[0]) / (rng[1] - rng[0]), 0, 1)
				var x := AX + i * w
				var bg := BG.hsl(230 - 230 * nrm, 0.7, 0.62 if et == "afr" else 0.58)
				draw_rect(Rect2(x, y, w - 1, RH - 1), bg)
				var txt := U.to_fixed(val, 1) if et == "afr" else str(int(roundf(val)))
				var sel: bool = bench.cells.has("%d,%d" % [j, i])
				if et == "afr": BG.MiniFont.draw(self, txt, Vector2(x + (w - 1) / 2 - 1, y + 4), Color("#000000"), 1)
				else: BG.font8_draw(self, txt, Vector2(x + (w - 1) / 2, y + 2), Color("#101010"), 1, 8, false)
				if sel:
					draw_rect(Rect2(x, y, w - 1, RH - 1), Color("#000000"), false, 1.0)
					draw_rect(Rect2(x + 1, y + 1, w - 3, RH - 3), Color("#ffffff"), false, 1.0)
				var mark := Color(0, 0, 0, 0)
				if has_log and et == "ve" and lg.get("wb", false):
					var err: float = float(lg.cells[j][i]) / (float(f.afr[j][i]) / 14.7) - 1.0
					if absf(err) > 0.02: mark = Color("#cc0000") if err > 0 else Color("#0040c0")
				if et == "ign" and has_log and Tune.has("knock") and ev.get("cells") != null:
					if float(f.ign[j][i]) - Tune.kl(v, i, j, float(ev.cells[j][i]), bench.cond) > 0: mark = Color("#ff00c8")
				if mark.a > 0:
					draw_rect(Rect2(x + w - 4, y + 1, 2, 3), mark)
		var by := 6 * RH + 2
		BG.MiniFont.draw(self, "KPA", Vector2(1, by), BG.C("#334455"))
		for i in 8:
			var rr: float = float(bins[i])
			var lab := ""
			if rr >= 10000: lab = U.to_fixed(rr / 1000.0, 1) + "K"
			elif fmod(rr, 1000.0) != 0: lab = U.to_fixed(rr / 1000.0, 1) + "K"
			else: lab = str(int(rr / 1000.0)) + "K"
			BG.MiniFont.draw(self, lab, Vector2(AX + i * w + (w - 1) / 2, by), BG.C("#334455"), 1)

func set_cell(j: int, i: int, on: bool) -> void:
	var k := "%d,%d" % [j, i]
	if on: cells[k] = true
	else: cells.erase(k)
	if grid: grid.queue_redraw()
	_update_hint()

func sel_cells() -> Array:
	var out := []
	for k in cells:
		var p: PackedStringArray = str(k).split(",")
		out.append([int(p[0]), int(p[1])])
	return out

func _lbtn(text: String, cb: Callable, act: String, on := false, dis := false) -> Button:
	var b := UIKit.btn(text, cb)
	b.add_theme_font_override("font", UIKit.font8)
	b.add_theme_font_size_override("font_size", 8)
	var face := Color("#ffffff") if on else Color("#d5dae2")
	var edge := Color("#1f4e8f") if on else Color("#8a93a3")
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var c := face
		if k == "hover": c = face.lightened(0.3)
		elif k.begins_with("pressed") or k == "hover_pressed": c = face.darkened(0.15)
		elif k == "disabled": c = Color("#b0b6c0")
		var st := UIKit.sb(c, edge, 1, 3)
		st.content_margin_left = 1; st.content_margin_right = 1
		b.add_theme_stylebox_override(k, st)
	for c2 in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c2, Color("#1f4e8f") if on else Color("#111111"))
	b.add_theme_color_override("font_disabled_color", Color("#6a7080"))
	b.disabled = dis
	b.custom_minimum_size = Vector2(0, 18)
	SK.act(b, act)
	return b

func _fill_efi(b: VBoxContainer) -> void:
	var e: Dictionary = v.eng
	var f: Dictionary = e.efi
	_cond_chips(b)
	# laptop
	var lap := PanelContainer.new()
	lap.add_theme_stylebox_override("panel", UIKit.sb(Color("#2b2f3a"), Color("#0b0d12"), 3, 4))
	b.add_child(lap)
	var lv := UIKit.vbox(0)
	lap.add_child(lv)
	var scr := PanelContainer.new()
	scr.add_theme_stylebox_override("panel", UIKit.sb(Color("#eef1f5"), Color("#000000"), 2, 2))
	lv.add_child(scr)
	var base := ColorRect.new()
	base.color = Color("#4a505e")
	base.custom_minimum_size = Vector2(0, 5)
	lv.add_child(base)
	var sv := UIKit.vbox(3)
	scr.add_child(sv)
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UIKit.sb(Color("#1f4e8f"), Color("#1f4e8f"), 0, 2))
	var load_s := "MAP" if Tune.has("mapsens") else "ALPHA-N"
	var extra := ""
	if Tune.has("iat"): extra += "+IAT"
	if Tune.has("knock"): extra += "+KNK"
	var th := UIKit.hbox(2)
	th.add_child(SK.small("TUNERSTUDIO-ISH", Color.WHITE, false))
	var tl := SK.small(load_s + extra, Color("#bcd4ff"), false)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	th.add_child(tl)
	top.add_child(th)
	sv.add_child(top)
	var tabs := UIKit.hbox(1)
	for t in [["ve", "VE"], ["ign", "SPARK"], ["afr", "AFR"], ["log", "LOG"], ["set", "SET"]]:
		if Tune.mode() == "standard" and t[0] in ["ign", "set"]: continue
		tabs.add_child(_lbtn(t[1], _etab.bind(t[0]), "etab:" + t[0], etab == t[0]))
	sv.add_child(tabs)
	if etab == "ve" or etab == "ign" or etab == "afr":
		grid = VeGrid.new(self)
		sv.add_child(grid)
		var r1 := UIKit.hbox(1)
		r1.add_child(_lbtn("ROW", _sel_row, "sel:row"))
		r1.add_child(_lbtn("COL", _sel_col, "sel:col"))
		r1.add_child(_lbtn("ALL", _sel_all, "sel:all"))
		r1.add_child(_lbtn("NONE", _sel_none, "sel:none"))
		sv.add_child(r1)
		var r2 := UIKit.hbox(1)
		for op in ["-5%", "-1", "+1", "+5%"]:
			r2.add_child(_lbtn(op, _cadj.bind(op), "cadj:" + op))
		sv.add_child(r2)
		var r3 := UIKit.hbox(1)
		if etab != "afr": r3.add_child(_lbtn("SMOOTH", _smooth, "smooth"))
		if etab == "ve" and Tune.has("veal"):
			var lg = e.get("log")
			var ok: bool = lg is Dictionary and lg.get("cells") != null and bool(lg.get("wb", false))
			r3.add_child(_lbtn("VE ANALYZE", _veal, "veal", false, not ok))
		if r3.get_child_count() > 0: sv.add_child(r3)
		else: r3.free()
		var hp := PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UIKit.sb(Color("#fffbe0"), Color("#c9b36a"), 1, 3))
		hint_lbl = SK.small("", Color("#222222"))
		hp.add_child(hint_lbl)
		sv.add_child(hp)
	elif etab == "log":
		if e.get("log") != null:
			var lg2: Dictionary = e.log
			sv.add_child(SK.small("%s - %s" % [lg2.src, Career.dateStr(int(lg2.d))], Color("#1f4e8f")))
			sv.add_child(ZoneTable.new(lg2.lam, lg2.kd, bool(lg2.get("wb", false))))
			sv.add_child(SK.small("Cells logged: %s" % ("yes - VE Analyze can use it" if lg2.get("cells") != null else "no"), Color("#334466")))
		else:
			sv.add_child(SK.small("No datalog yet. Run a dyno pull or a test day.", Color("#334466")))
		sv.add_child(_lbtn("GO TO DYNO", _set_tab.bind("dyno"), "goto:dyno"))
	else:
		_step(sv, "ae", "Accel enrichment (TPSdot)", "%d%%" % int(f.ae), "Extra fuel on throttle snaps - fixes the bog off hairpins", _ae, false, true)
		var info := "LOAD: %s\nIAT: %s\nKNOCK CONTROL: %s\nLAUNCH: %s" % ["MAP (baro corrected)" if Tune.has("mapsens") else "TPS - goes rich at altitude",
			"on" if Tune.has("iat") else "not fitted", "on" if Tune.has("knock") else "not fitted", "2-step armed" if Tune.has("launch") else "-"]
		sv.add_child(SK.small(info, Color("#334466")))
	_zone_card(b, true)
	_fuel_chips(b)
	_crew_row(b, "RELOAD THE BASE MAP", _ask_base, "base")
	if e.get("log") != null and etab != "log": _log_card(b, e.log)

func _update_hint() -> void:
	if hint_lbl == null: return
	var ks := sel_cells()
	var bins: Array = Data.D.RPM_B[Data.D.BODY[v.body].cls]
	if ks.size() == 1:
		var j: int = ks[0][0]; var i: int = ks[0][1]
		var f: Dictionary = v.eng.efi
		var t := "CELL %d RPM / %d KPA" % [int(bins[i]), int(Data.D.LOAD_B[j])]
		var lg = v.eng.get("log")
		var has_log: bool = lg is Dictionary and lg.get("cells") != null
		if etab == "ve" and has_log and lg.get("wb", false):
			var m: float = float(lg.cells[j][i]) * 14.7
			var tg: float = float(f.afr[j][i])
			t += "\nLog AFR %s vs target %s -> suggest VE %d" % [U.to_fixed(m, 1), U.to_fixed(tg, 1), int(roundf(float(f.ve[j][i]) * m / tg))]
		elif etab == "ve" and not has_log: t += "\nNo datalog yet - dyno pull or test day"
		if etab == "ign" and Tune.mode() != "sim": t += "\nMBT ~%d deg" % int(roundf(Tune.mbt(i, j)))
		hint_lbl.text = t
	elif ks.size() > 1:
		hint_lbl.text = "%d cells selected" % ks.size()
	else:
		hint_lbl.text = "Tap cells to select (drag to paint), then adjust."

func _etab(t: String) -> void:
	etab = t
	cells.clear()
	rebuild()

func _sel_row() -> void:
	var ks := sel_cells()
	var j: int = ks[0][0] if ks.size() else 5
	cells.clear()
	for i in 8: cells["%d,%d" % [j, i]] = true
	_after_sel()

func _sel_col() -> void:
	var ks := sel_cells()
	var i: int = ks[0][1] if ks.size() else 5
	cells.clear()
	for j in 6: cells["%d,%d" % [j, i]] = true
	_after_sel()

func _sel_all() -> void:
	cells.clear()
	for j in 6:
		for i in 8: cells["%d,%d" % [j, i]] = true
	_after_sel()

func _sel_none() -> void:
	cells.clear()
	_after_sel()

func _after_sel() -> void:
	if grid: grid.queue_redraw()
	_update_hint()

func _cadj(op: String) -> void:
	if cells.is_empty():
		say("Tap cells to select them")
		return
	Career.adjCells(vid, etab, sel_cells(), op)
	Career.checkSpot(v, cond)
	_changed()

func _smooth() -> void:
	Career.smoothCells(vid, etab, sel_cells())
	_changed()

func _veal() -> void:
	var n := Career.veAnalyze(vid)
	say("VE Analyze corrected %d cells. Log again to verify." % n)
	_eval()
	rebuild()

func _ask_base() -> void:
	confirm("Reload base map?", "Your VE, spark and AFR tables go back to the rough base tune.", "RELOAD", _base)

func _base() -> void:
	Career.efiBase(vid)
	_changed()

func _ae(dir: int) -> void:
	Career.adjAE(vid, dir)
	_changed()

# ======================================================================
# sync
# ======================================================================
class SyncView extends Control:
	var bench
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, 92)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		BG.draw_sync(self, Vector2.ZERO, size.x, bench.v, bench.bs)

func _sync_val(i: int) -> String:
	if not Tune.has("syncgauge"): return "?"
	var x := float(v.eng.sync[i])
	return "%s%s" % ["+" if x > 0 else "", U.to_fixed(x, 1)]

func _fill_sync(b: VBoxContainer) -> void:
	var e: Dictionary = v.eng
	var n: int = e.sync.size()
	var bi := Tune.syncBase(n)
	var g := Tune.has("syncgauge")
	b.add_child(SK.section("%s sync (%d)" % ["Throttle-body" if e.fuel == "efi" else "Carb", n]))
	var sv := SyncView.new(self)
	b.add_child(sv)
	canvases.append(sv)
	b.add_child(SK.small("Match every column to the base carb. Sync drifts as you race." if g else "Without gauges you adjust by ear - coarse steps and no readout. (Tech: Vacuum Sync Gauges)", SK.SUB))
	for i in n:
		if i == bi: continue
		_step(b, "sync:%d" % i, "#%d sync screw" % (i + 1), _sync_val(i), "", _sync.bind(i), not _ready_ok())
	_zone_card(b, Tune.has("wideband"))

func _sync(dir: int, i: int) -> void:
	Career.adjSync(vid, i, dir)
	_changed()

# ======================================================================
# dyno
# ======================================================================
class DynoView extends Control:
	var bench
	var ground := Vector2.ZERO
	func _init(b) -> void:
		bench = b
		custom_minimum_size = Vector2(0, BG.DYNO_H)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		ground = BG.draw_dyno(self, Vector2.ZERO, size.x, bench.v, bench.bs, bench.dt)

func _fill_dyno(b: VBoxContainer) -> void:
	var e = v.get("eng")
	if Career.facLv("dyno") <= 0:
		SK.note(b, "Build a Dyno Room (Workshop screen) to do dyno pulls. Meanwhile a Test Day logs the same data.", SK.HL)
		b.add_child(SK.act(SK.btn("GO TO WORKSHOP", _go_fac, UIKit.BTN), "goto:facility"))
		if e != null and e.get("log") != null: _log_card(b, e.log)
		return
	if e == null or e.fuel == "none":
		SK.note(b, "Electric motor - nothing to log on the dyno.", SK.HL)
		return
	_cond_chips(b, "PULL CONDITIONS")
	var dv := DynoView.new(self)
	b.add_child(dv)
	canvases.append(dv)
	var spr := SK.veh_sprite(Data.D.BODY[v.body].kind, 0, _mat, 4, Rect2(0, 0, 48, 48))
	spr.position = Vector2(40, 38)
	dv.add_child(spr)
	dyno_sprite = spr
	var d = bs.dyno
	var running: bool = d is Dictionary and d.vid == v.id and d.running
	dyno_btn = SK.act(SK.btn("PULLING..." if running else "RUN A WOT PULL", _dyno_run, SK.GREEN, false, running or not _ready_ok()), "dyno")
	b.add_child(dyno_btn)
	if d is Dictionary and d.vid == v.id and d.done:
		b.add_child(SK.small("Peak %d hp. Datalog saved - check the %s tab." % [int(roundf(float(d.peak))), "EFI LOG" if e.fuel == "efi" else "CARBS"], SK.GD))
	_zone_card(b, Tune.has("wideband"))
	if e.get("log") != null: _log_card(b, e.log)

func _go_fac() -> void:
	go("facility", {})

func _dyno_run() -> void:
	if not _ready_ok():
		say("Vehicle must be ready")
		return
	_eval()
	bs.dyno = BG.dyno_start(v, cond, ev)
	Career.sfx.emit("start")
	if dyno_btn:
		dyno_btn.text = "PULLING..."
		dyno_btn.disabled = true

func _dyno_done() -> void:
	var d: Dictionary = bs.dyno
	d.logged = true
	v.eng.log = Tune.makeLog(v, d.cond, "Dyno pull")
	say("Pull done - datalog saved")
	_eval()
	rebuild()

# ======================================================================
# setup sheet
# ======================================================================
func _set_val(k: String) -> String:
	var st: Dictionary = v.setup
	match k:
		"f": return "%dT" % int(st.f)
		"r": return "%dT" % int(st.r)
		"fd": return U.to_fixed(float(st.fd), 2) + ":1"
		"susp": return "%d CLK" % int(st.susp)
		"psi": return "%d PSI" % int(st.psi)
		"wing": return "%d DEG" % int(st.wing)
	return ""

func _lock(t: String) -> String:
	return "" if Tune.has(t) else "LOCKED: " + SK.ascii(Data.D.TECHM[t].n)

func _fill_setup(b: VBoxContainer) -> void:
	var bike: bool = Data.D.BODY[v.body].cls == "bike"
	var st: Dictionary = v.setup
	SK.note(b, "Setup changes how speed, acceleration and grip show up on each track. Locked rows need Tech.")
	if bike:
		var ratio := float(st.r) / float(st.f)
		var rel := ratio / Tune.stockRatio(v)
		var rd := "shorter: more accel, less top speed" if rel > 1.02 else ("taller: more top speed, softer launch" if rel < 0.98 else "stock-ish")
		_step(b, "set:f", "Front sprocket", _set_val("f"), _lock("gearing"), _setup.bind("f"), not Tune.has("gearing"))
		_step(b, "set:r", "Rear sprocket", _set_val("r"), _lock("gearing") if not Tune.has("gearing") else "Ratio %s - %s" % [U.to_fixed(ratio, 2), rd], _setup.bind("r"), not Tune.has("gearing"))
	else:
		var fd := float(st.fd)
		var dd := "Short: launches and hills" if fd > 3.75 else ("Tall: fast tracks" if fd < 3.65 else "Stock")
		_step(b, "set:fd", "Final drive", _set_val("fd"), _lock("gearing") if not Tune.has("gearing") else dd, _setup.bind("fd"), not Tune.has("gearing"))
	_step(b, "set:susp", "Suspension stiffness", _set_val("susp"), _lock("adjsus") if not Tune.has("adjsus") else "Stiffer = sharper on tarmac, worse over rough ground", _setup.bind("susp"), not Tune.has("adjsus"))
	_step(b, "set:psi", "Tire pressure", _set_val("psi"), _lock("tirepress") if not Tune.has("tirepress") else "Stock %d - air down for dirt, up a touch for tarmac" % int(Tune.stockPsi(v)), _setup.bind("psi"), not Tune.has("tirepress"))
	if not bike:
		_step(b, "set:wing", "Wing angle", _set_val("wing"), _lock("aero") if not Tune.has("aero") else "More wing = more cornering grip, less top speed", _setup.bind("wing"), not Tune.has("aero"))
	_cond_chips(b, "SETTING UP FOR")
	var h := UIKit.hbox(3)
	var rn: String = "(PICK RACE)" if cond_race == "" else str(Data.D.RACE[cond_race].n)
	h.add_child(SK.act(SK.btn("CREW SETUP", _crew_setup, SK.GREEN, true, cond_race == "" or Career.drivers().is_empty()), "crew_setup"))
	h.add_child(SK.act(SK.btn("STOCK SETUP", _stock_setup, SK.GREY, true), "stock_setup"))
	b.add_child(h)
	b.add_child(SK.small("Crew setup for: %s" % SK.ascii(rn), SK.DIM))

func _setup(dir: int, key: String) -> void:
	Career.adjSetup(vid, key, dir)
	if key == "r" or key == "f" or key == "fd": rebuild()
	else: _changed()

func _stock_setup() -> void:
	Career.stockSetup(vid)
	rebuild()

func _crew_setup() -> void:
	if cond_race == "" or Career.drivers().is_empty(): return
	Career.bestSetup(v, Data.D.RACE[cond_race], Career.drivers()[0])
	say("Crew set it up for " + SK.ascii(Data.D.RACE[cond_race].n))
	rebuild()

# ======================================================================
# frame
# ======================================================================
func _process(delta: float) -> void:
	super(delta)
	if v.is_empty() or modal != null: return
	dt = minf(delta, 0.1)
	BG.tick(bs, dt)
	var d = bs.dyno
	if d is Dictionary and d.vid == v.id:
		if d.running: BG.dyno_step(v, d, dt)
		if d.done and not d.logged: _dyno_done()
	if dyno_sprite != null:
		var run: bool = d is Dictionary and d.running
		dyno_sprite.position.y = 38.0 + (1.0 if run and int(bs.t * 30) % 2 == 0 else 0.0)
	for c in canvases:
		if is_instance_valid(c) and c.is_visible_in_tree(): c.queue_redraw()
