extends "res://scripts/ui/career/sub_screen.gd"
## Valve lash & timing workbench (opened from the How-to guide). Turn the engine by hand and watch the
## cams, buckets/rockers, lash gap and timing marks; find each valve's measuring position; fill in a
## clearance + shim worksheet for your own engine (saved on this device); check timing with a strobe.
## Models: the Yamaha XJ550 (real figures, shim-over-bucket) and three EXAMPLE engines with screw
## adjusters (single, 360 twin, car inline-4) for the simpler version.
## ctx: {router?, model?: "xj550" | "single" | "twin" | "car4", level?: "sim" | "kid"}

const VG := preload("res://scripts/ui/career/valve_gfx.gd")
const SAVE := "user://valve_sheets.json"

var model := "xj550"
var level := "sim"
var th := 0.0            # crank angle 0..720 (0 = #1 TDC compression)
var cyl := 1
var sel := "ex"
var feeler := true
var rpm := 1200.0
var running := false
var units := "mm"
var sheets := {}         # model -> {"1in": {"m": mm or null, "s": shim mm}}
var _fire := 0.0
var _canvases := []
var _anim := 0.0

func _title() -> String: return "Valves & timing"
func _tabs() -> Array: return [["valves", "VALVES"], ["timing", "TIMING"], ["sheet", "WORKSHEET"]]
func _head_info() -> String: return "" if Career.G.is_empty() else super._head_info()
func _sig() -> String: return ""

func _init_screen() -> void:
	model = str(ctx.get("model", "xj550"))
	level = str(ctx.get("level", "sim"))
	if not VG.ENGINES.has(model): model = "xj550"
	_load()
	rpm = float(e().idle)

func e() -> Dictionary: return VG.eng(model)

# ---------------- persistence ----------------
func _load() -> void:
	if not FileAccess.file_exists(SAVE): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if d is Dictionary:
		sheets = d.get("sheets", {})
		units = str(d.get("units", "mm"))

func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"sheets": sheets, "units": units}))

func _row(key: String) -> Dictionary:
	if not sheets.has(model): sheets[model] = {}
	if not sheets[model].has(key): sheets[model][key] = {"m": null, "s": 2.70 if e().adj == "shim" else null}
	return sheets[model][key]

func _meas_map() -> Dictionary:
	var out := {}
	if sheets.has(model):
		for k in sheets[model]:
			var m = sheets[model][k].get("m")
			if m != null: out[k] = float(m)
	return out

# ---------------- build ----------------
func _fill(b: VBoxContainer) -> void:
	_canvases.clear()
	var mh := UIKit.hbox(2)
	for id in ["xj550", "single", "twin", "car4"]:
		var c := SK.act(SK.chip(VG.ENGINES[id].short, model == id, _set_model.bind(id)), "model:" + id)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mh.add_child(c)
	b.add_child(mh)
	var E := e()
	var head := SK.card(b, "gold" if not E.example else "warn", 1)
	head.add_child(SK.small(E.n, SK.HL, false))
	head.add_child(SK.small("Clearance (cold): IN %.2f-%.2f mm, EX %.2f-%.2f mm%s" % [E["in"][0], E["in"][1], E.ex[0], E.ex[1],
		"" if not E.example else "  EXAMPLE - use your manual's spec"], Color.WHITE if not E.example else SK.BD))
	match tab:
		"valves": _fill_valves(b)
		"timing": _fill_timing(b)
		"sheet": _fill_sheet(b)

func _fill_valves(b: VBoxContainer) -> void:
	var E := e()
	SK.note(b, _valves_note(), SK.SUB)
	var strip := Canvas.new(self, "strip", 42)
	b.add_child(strip); _canvases.append(strip)
	var cut := Canvas.new(self, "cut", 152)
	b.add_child(cut); _canvases.append(cut)
	# turning the engine
	var tr := UIKit.hbox(2)
	for st in [[-90, "<90"], [-10, "<10"], [10, "10>"], [90, "90>"]]:
		var bt := SK.act(SK.sbtn(st[1], _turn.bind(float(st[0])), UIKit.BTN, 30), "turn:%d" % int(st[0]))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.add_child(bt)
	var nx := SK.act(SK.sbtn("NEXT CHECK >", _next_check, SK.GREEN, 86), "next_check")
	tr.add_child(nx)
	b.add_child(tr)
	# cylinder / valve / feeler
	if int(E.cyl) > 1:
		var cr := UIKit.hbox(2)
		for c in range(1, int(E.cyl) + 1):
			var cb := SK.act(SK.chip("CYL %d" % c, cyl == c, _set_cyl.bind(c)), "cyl:%d" % c)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cr.add_child(cb)
		b.add_child(cr)
	var ch := UIKit.hbox(2)
	for v in ["ex", "in"]:
		var vb := SK.act(SK.chip(v.to_upper(), sel == v, _set_sel.bind(v)), "valve:" + v)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(vb)
	var fb := SK.act(SK.chip("FEELER", feeler, _toggle_feeler), "feeler")
	fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(fb)
	b.add_child(ch)
	# what can be measured right now
	var now := []
	for c in range(1, int(E.cyl) + 1):
		for v in ["ex", "in"]:
			if VG.measurable(E, v, VG.local(E, c, th)): now.append("#%d %s" % [c, v.to_upper()])
	var g := SK.group(b, "Measure now", "#1 " + VG.tdc_txt(VG.local(E, 1, th)))
	if now.is_empty():
		g.add_child(SK.small("No lobe points away from its valve here. Tap NEXT CHECK.", SK.SUB))
	else:
		g.add_child(SK.small(", ".join(now) + ("  - slide the feeler between the cam's base circle and the shim." if E.adj == "shim" else "  - slide the feeler between the adjuster screw and the valve stem."), SK.GD))
	# reading for the cutaway valve
	var key := "%d%s" % [cyl, sel]
	var rw := _row(key)
	g.add_child(_reading_row(key, rw, true))
	g.add_child(_result_line(sel, rw))
	# the rotor
	var rg := SK.group(b, "Timing window (left cover off)")
	var rot := Canvas.new(self, "rotor", 92)
	rg.add_child(rot); _canvases.append(rot)
	rg.add_child(SK.small(_tdc_text(), SK.HL))

func _valves_note() -> String:
	var E := e()
	if level == "kid":
		if E.adj == "shim":
			return "Valves need a tiny gap so they can close all the way. Turn the engine until a cam bump points AWAY from its valve (green), then slide a thin gauge into the gap. Too tight or too loose? Swap the little shim disc."
		return "Valves need a tiny gap so they close all the way. Turn the engine until the bump points away (green), slide the thin gauge in, and turn the screw until it just drags."
	if E.adj == "shim":
		return "Engine COLD (room temp). Plugs out, cover off. Turn the crank with a wrench on the bolt in the centre of the ignition rotor (left cover). Measure each valve with its lobe pointing straight away from the shim. Green = measure now."
	return "Engine cold. Turn the crank to TDC compression for the cylinder (both rockers loose), check each valve with a feeler under the adjuster, then loosen the locknut, set the screw for a slight drag and lock it - recheck after tightening."

func _tdc_text() -> String:
	var E := e()
	var a := VG.local(E, 1, th)
	if absf(wrapf(a, -360.0, 360.0)) < 6.0: return "Pointer on T: #1 TDC COMPRESSION (both #1 lobes away)."
	if absf(wrapf(a - 360.0, -360.0, 360.0)) < 6.0:
		return "Pointer on T: #1 on OVERLAP%s - turn one more turn for #1 compression." % (" (#4 on compression)" if int(E.cyl) == 4 and model != "car4" else "")
	if int(E.cyl) == 4 and absf(wrapf(fposmod(th, 360.0) - 180.0, -180.0, 180.0)) < 6.0: return "Pointer on the 2-3 T mark: #2 or #3 at TDC."
	return "Rotor turns with the crank; the pointer is fixed at the top."

func _reading_row(key: String, rw: Dictionary, with_shim: bool) -> Control:
	var E := e()
	var h := UIKit.hbox(2)
	var lb := SK.small(key.left(1) + " " + key.substr(1).to_upper(), Color.WHITE, false)
	lb.custom_minimum_size = Vector2(28, 0)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(lb)
	var mv = rw.get("m")
	h.add_child(SK.act(SK.sbtn("-", _adj_m.bind(key, -0.01), UIKit.BTN_LO, 16), "m-:" + key))
	var ml := SK.small(("--" if mv == null else (("%.2f" % float(mv)) if units == "mm" else VG.inch(float(mv)))), SK.HL, false)
	ml.custom_minimum_size = Vector2(34, 0)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ml)
	h.add_child(SK.act(SK.sbtn("+", _adj_m.bind(key, 0.01), UIKit.BTN_LO, 16), "m+:" + key))
	if with_shim and E.adj == "shim":
		var sp := Control.new(); sp.custom_minimum_size = Vector2(4, 0); h.add_child(sp)
		h.add_child(SK.act(SK.sbtn("-", _adj_s.bind(key, -0.05), UIKit.BTN_LO, 16), "s-:" + key))
		var sl := SK.small(VG.shim_name(float(rw.s)), Color("#e0b030"), false)
		sl.custom_minimum_size = Vector2(30, 0)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sl)
		h.add_child(SK.act(SK.sbtn("+", _adj_s.bind(key, 0.05), UIKit.BTN_LO, 16), "s+:" + key))
	return h

func _result_line(v: String, rw: Dictionary) -> Label:
	var E := e()
	var mv = rw.get("m")
	if mv == null:
		if tab == "sheet": return SK.small("not measured yet", SK.DIM)
		return SK.small("Enter the feeler that slides with a slight drag%s." % (" and the number on the installed shim" if E.adj == "shim" else ""), SK.SUB)
	var m := float(mv)
	var stt := VG.status(E, v, m)
	if E.adj == "shim":
		var r := VG.shim_for(E, v, m, float(rw.s))
		if stt == "OK": return SK.small("OK - in spec. Leave %s in." % VG.shim_name(float(rw.s)), SK.GD)
		return SK.small("%s - fit %s (%s%.2f mm) -> about %.2f mm" % [stt, VG.shim_name(float(r.shim)), "+" if float(r.change) > 0 else "", float(r.change), float(r.result)], SK.BD)
	if stt == "OK": return SK.small("OK - in spec.", SK.GD)
	return SK.small("%s - loosen the locknut, set to %.2f mm (slight drag), lock, recheck." % [stt, VG.target(E, v)], SK.BD)

func _fill_timing(b: VBoxContainer) -> void:
	var E := e()
	SK.note(b, _timing_note(), SK.SUB)
	var rot := Canvas.new(self, "strobe", 120)
	b.add_child(rot); _canvases.append(rot)
	var rh := UIKit.hbox(2)
	for st in [[-500, "-500"], [-100, "-100"], [100, "+100"], [500, "+500"]]:
		var bt := SK.act(SK.sbtn(st[1], _adj_rpm.bind(float(st[0])), UIKit.BTN, 30), "rpm:%d" % int(st[0]))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(bt)
	var rb := SK.act(SK.sbtn("STOP" if running else "START", _toggle_run, SK.RED if running else SK.GREEN, 50), "run")
	rh.add_child(rb)
	b.add_child(rh)
	var g := SK.group(b, "Timing light", "%d RPM" % int(rpm))
	var adv := VG.advance(E, rpm)
	var at_idle := absf(rpm - float(E.idle)) <= 60.0
	if not running: g.add_child(SK.small("Start the engine, then watch the marks under the strobe.", SK.SUB))
	elif at_idle: g.add_child(SK.small("Idle %d rpm: the F range sits under the pointer - good." % int(E.idle), SK.GD))
	else: g.add_child(SK.small("Above idle the marks swing away from T as the spark advances (about %d deg here on this example curve)." % int(adv), SK.HL))
	for l in _timing_steps(): g.add_child(SK.small("- " + l, SK.SUB))

func _timing_note() -> String:
	var E := e()
	if level == "kid":
		return "The spark has to happen just BEFORE the piston reaches the top. A timing light flashes with the spark, so the spinning marks look frozen. At idle the F mark should sit under the pointer."
	match str(E.ign):
		"tci": return "XJ550: transistorized (TCI) ignition - timing is CHECKED, not adjusted. Warm engine, timing light on the #1 lead, idle %d +-50 rpm: the pointer should sit inside the F range on the timing plate." % int(E.idle)
		"plate": return "EXAMPLE points / plate ignition: set static timing at the F mark, then check with a light at idle and adjust the plate."
		_: return "EXAMPLE distributor engine: light on #1, at idle loosen the distributor clamp and turn the body until the mark lines up; tighten and recheck."

func _timing_steps() -> Array:
	var E := e()
	if level == "kid": return ["Hook the light to cylinder 1's plug wire.", "Run the engine at its normal idle.", "Point the light at the window: F under the pointer = right."]
	match str(E.ign):
		"tci": return ["Out of range at idle: nothing to adjust - test the pickup coils, the TCI unit and the wiring, and check the rotor is fitted the right way.",
			"Rev it slowly: the marks should move smoothly as the TCI advances the spark. Jumpy marks = pickup or wiring trouble.",
			"Coils fire in pairs (1-4, 2-3), so a light on #1 also sees #4's wasted spark - same marks."]
		"plate": return ["Static: turn to F on compression, set the points to just open (or the pickup aligned).", "Dynamic: light on the cylinder's lead at idle, loosen the plate screws, rotate the plate until F is under the pointer, tighten.", "Check full advance at the rpm your manual gives."]
		_: return ["Disconnect / plug the vacuum advance line if the manual says so.", "Set idle first, then timing; reset idle after.", "Check total advance at higher rpm if your manual lists it."]

func _fill_sheet(b: VBoxContainer) -> void:
	var E := e()
	var uh := UIKit.hbox(2)
	for u in ["mm", "in"]:
		var c := SK.act(SK.chip("SHOW " + u.to_upper(), units == u, _set_units.bind(u)), "units:" + u)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		uh.add_child(c)
	uh.add_child(SK.act(SK.chip("CLEAR", false, _ask_clear), "clear"))
	b.add_child(uh)
	SK.note(b, ("Your engine, saved on this device. Enter each reading and the number on the installed shim (Y270 = 2.70 mm). New shim = installed + (measured - target %.3f IN / %.3f EX), rounded to 0.05 mm." % [VG.target(E, "in"), VG.target(E, "ex")]) if E.adj == "shim" else "Your engine, saved on this device. Enter each reading; the sheet tells you which screws to set.", SK.SUB)
	var changes := []
	for c in range(1, int(E.cyl) + 1):
		var g := SK.group(b, "Cylinder %d" % c)
		for v in ["in", "ex"]:
			var key := "%d%s" % [c, v]
			var rw := _row(key)
			g.add_child(_reading_row(key, rw, true))
			g.add_child(_result_line(v, rw))
			if rw.get("m") != null and E.adj == "shim" and VG.status(E, v, float(rw.m)) != "OK":
				changes.append([key, float(rw.s), float(VG.shim_for(E, v, float(rw.m), float(rw.s)).shim)])
	if E.adj == "shim":
		var pg := SK.group(b, "Shim plan", "%d to change" % changes.size())
		if changes.is_empty():
			pg.add_child(SK.small("Nothing to change yet." if _meas_map().is_empty() else "All entered valves are in spec.", SK.SUB))
		else:
			var out := changes.map(func(x): return x[1])
			var need := changes.map(func(x): return x[2])
			var buy := []
			for n in need:
				var i := -1
				for j in out.size():
					if absf(float(out[j]) - float(n)) < 0.001: i = j; break
				if i >= 0: out.remove_at(i)
				else: buy.append(n)
			for x in changes:
				pg.add_child(SK.small("%s %s: %s -> %s" % [str(x[0]).left(1), str(x[0]).substr(1).to_upper(), VG.shim_name(x[1]), VG.shim_name(x[2])], Color.WHITE))
			pg.add_child(SK.small("Reuse the shims you pull out where they fit. Buy: %s" % (", ".join(buy.map(func(z): return VG.shim_name(z))) if not buy.is_empty() else "nothing - the swaps cover it!"), SK.HL))
			pg.add_child(SK.small("Shims go in number side DOWN. Recheck every changed valve.", SK.SUB))

# ---------------- actions ----------------
func _set_model(id: String) -> void:
	model = id; th = 0.0; cyl = 1; rpm = float(e().idle); running = false
	rebuild()

func _turn(d: float) -> void:
	th = fposmod(th + d, 720.0)
	_redraw_or_rebuild()

func _next_check() -> void:
	var nc := VG.next_check(e(), th)
	th = float(nc[0]); cyl = int(nc[1]); sel = str(nc[2])
	rebuild()

func _set_cyl(c: int) -> void: cyl = c; rebuild()
func _set_sel(v: String) -> void: sel = v; rebuild()
func _toggle_feeler() -> void: feeler = not feeler; rebuild()
func _set_units(u: String) -> void: units = u; _save(); rebuild()
func _toggle_run() -> void: running = not running; rebuild()

func _adj_rpm(d: float) -> void:
	rpm = clampf(rpm + d, float(e().idle) - 200.0, 6000.0)
	if absf(rpm - float(e().idle)) < 60.0: rpm = float(e().idle)
	rebuild()

func _adj_m(key: String, d: float) -> void:
	var rw := _row(key)
	var v: String = key.substr(1)
	var start: float = VG.target(e(), v) if rw.get("m") == null else float(rw.m)
	rw.m = snappedf(clampf(start + (d if rw.get("m") != null else 0.0), 0.0, 0.60), 0.01)
	_save(); rebuild()

func _adj_s(key: String, d: float) -> void:
	var rw := _row(key)
	rw.s = snappedf(clampf(float(rw.s) + d, float(e().shim[0]), float(e().shim[1])), 0.01)
	_save(); rebuild()

func _ask_clear() -> void:
	confirm("CLEAR THE SHEET?", "Removes every reading for the %s." % e().short, "CLEAR", _clear)

func _clear() -> void:
	sheets.erase(model)
	_save(); rebuild()

func _redraw_or_rebuild() -> void:
	rebuild()

func _process(dt: float) -> void:
	super._process(dt)
	if tab == "timing" and running:
		_anim += dt
		_fire = 1.0 if fmod(_anim * 8.0, 1.0) < 0.15 else 0.0
		th = fposmod(th + dt * 120.0, 720.0)
		for c in _canvases:
			if is_instance_valid(c): c.queue_redraw()

func draw_canvas(c: Control, kind: String) -> void:
	var E := e()
	var st := {"th": th, "cyl": cyl, "sel": sel, "meas": _meas_map(), "feeler": feeler, "fire": _fire}
	match kind:
		"strip": VG.draw_strip(c, Vector2.ZERO, c.size.x, E, st)
		"cut": VG.draw_cutaway(c, Vector2(floorf((c.size.x - 240) / 2), 0), E, st)
		"rotor": VG.draw_rotor(c, Vector2(c.size.x * 0.5, 48), 38, E, th)
		"strobe":
			c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("#05081a"))
			if running and _fire > 0.0:
				VG.draw_rotor(c, Vector2(c.size.x * 0.5, 62), 50, E, th, rpm)
				MiniFont.draw(c, "FLASH", Vector2(6, 6), Color("#ffffff"))
			elif running:
				MiniFont.draw(c, "DARK BETWEEN FLASHES", Vector2(6, 6), Color("#5a6170"))
				VG.draw_rotor(c, Vector2(c.size.x * 0.5, 62), 50, E, th, rpm)
				c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.02, 0.03, 0.1, 0.6))
			else:
				VG.draw_rotor(c, Vector2(c.size.x * 0.5, 62), 50, E, 0.0)
				MiniFont.draw(c, "ENGINE OFF", Vector2(6, 6), Color("#9aa3ad"))

class Canvas extends Control:
	var screen
	var kind := ""
	func _init(s, k: String, h: float) -> void:
		screen = s; kind = k
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		screen.draw_canvas(self, kind)
