class_name BuildScreen
extends CareerPage
## BUILD (web UI.V.build + ui2 fuel-system step + ui3 staged build): body -> layout -> fuel system ->
## estimate with the 8-phase plan -> Career.startBuild. The first build decision pops up right away.
## ctx: {cls?: "car"|"bike"}

const HINT := {
	"design": "What kind of machine is this going to be? This sets its character.",
	"frame": "The backbone. Stiffer and lighter is faster, heavier is tougher.",
	"engine": "How the motor goes together decides power, torque and how long it lives.",
	"drive": "Gearing and how the power gets to the ground.",
	"susp": "Spring, damper and brake package. Pick for the surfaces you race on.",
	"body": "Panels, aero and paint. Sponsors care about the paint.",
	"elec": "Wiring loom and fuel system hookup.",
	"shake": "Last checks before it rolls out the door.",
}

var body_id := ""
var layout_id := ""
var sys = null
var sys_picked := false
var spark := ""

func _init_page() -> void:
	set_title("BUILD")
	if tab == "": tab = str(ctx.get("cls", "car"))
	_sync_tabs()

func _sync_tabs() -> void:
	set_tabs([] if body_id != "" else [["car", "CARS"], ["bike", "BIKES"]])

func _on_back() -> bool:
	if body_id == "": return true
	if layout_id != "" and sys_picked and _needs_sys():
		sys_picked = false; sys = null
	elif layout_id != "":
		layout_id = ""; sys = null; sys_picked = false
	else:
		body_id = ""
	_sync_tabs()
	refresh()
	return false

func _needs_sys() -> bool:
	return layout_id != "" and int(Data.D.LAYOUT_CYL.get(layout_id, 4)) != 0

func _team() -> Color: return Color(str(Career.G.team.color))

func _render() -> void:
	var G: Dictionary = Career.G
	var W := Career.ws()
	var info := CareerKit.hbox(10)
	info.add_child(CareerKit.tag("GARAGE %d/%d" % [G.vehicles.size(), int(W.veh)], CareerKit.TXT if G.vehicles.size() < int(W.veh) else CareerKit.BAD))
	info.add_child(CareerKit.tag("BAYS %d/%d" % [G.jobs.size(), Career.bays()], CareerKit.TXT if G.jobs.size() < Career.bays() else CareerKit.BAD))
	info.add_child(CareerKit.tag("TECH %d" % int(round(Career.teamTech())), CareerKit.RPC))
	add(info)
	if body_id == "": _bodies()
	elif layout_id == "": _layouts()
	elif _needs_sys() and not sys_picked: _systems()
	else: _confirm()

# ---------------- step 1: body ----------------
func _bodies() -> void:
	var G: Dictionary = Career.G
	var locked := 0
	var shown := 0
	for b in Data.D.BODIES:
		if b.cls != tab: continue
		var av := Career.bodyAvail(b.id)
		if not av.get("done", false):
			locked += 1
			continue
		shown += 1
		var row := CareerKit.hbox(6)
		row.add_child(VehiclePortrait.new().setup(b.kind, _team()))
		var col := CareerKit.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := CareerKit.hbox(4)
		nm.add_child(CareerKit.big(b.n))
		var rk := CareerKit.lbl(b.rank, CareerKit.rank_col(b.rank), true, false)
		CareerKit.shrink(rk, true)
		nm.add_child(rk)
		col.add_child(nm)
		col.add_child(CareerKit.stat_grid(b.s))
		col.add_child(CareerKit.terr_row(b.t, true))
		col.add_child(CareerKit.line("%s | %dd | skill %d%%" % [U.money(float(b.cost)), int(round(float(b.days) * float(Data.D.BUILD_MULT))), int(round(Career.buildQ(b.id) * 100))],
			CareerKit.MONEY if float(G.money) >= float(b.cost) else CareerKit.BAD))
		col.add_child(CareerKit.line("%d part slots" % int(b.slots), CareerKit.SUB))
		row.add_child(col)
		add(CareerKit.card_btn(row, _pick_body.bind(b.id), "card", false, "body_" + str(b.id)))
	if shown == 0: note("No %ss researched yet. Visit RESEARCH." % tab, CareerKit.WARN)
	if locked > 0: note("%d more %ss to discover in Research." % [locked, tab], CareerKit.DIMC)

func _pick_body(id: String) -> void:
	body_id = id
	layout_id = ""; sys = null; sys_picked = false; spark = ""
	_sync_tabs()
	scroll.scroll_vertical = 0
	refresh()

func _body_head(spin := false) -> Control:
	var b: Dictionary = Data.D.BODY[body_id]
	var row := CareerKit.hbox(6)
	row.add_child(VehiclePortrait.new().setup(b.kind, _team(), 2 if spin else 1, spin, 5 if spin else 0))
	var col := CareerKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(CareerKit.big(b.n))
	col.add_child(CareerKit.line("Rank %s | %s" % [b.rank, "Car" if b.cls == "car" else "Bike"], CareerKit.rank_col(b.rank)))
	if layout_id != "": col.add_child(CareerKit.line(Data.D.LAYOUT[layout_id].n, CareerKit.TXT))
	if sys is Dictionary:
		col.add_child(CareerKit.small("EFI" if sys.get("type") == "efi" else CareerKit.carb_short(sys.carb), UIKit.GOLD))
	row.add_child(col)
	return CareerKit.panel(row, "card")

# ---------------- step 2: layout ----------------
func _layouts() -> void:
	var b: Dictionary = Data.D.BODY[body_id]
	set_title("BUILD: LAYOUT")
	add(_body_head())
	add(CareerKit.sec("DRIVE LAYOUT" if b.cls == "car" else "ENGINE TYPE"))
	for L in Data.D.LAYOUTS:
		if L.cls != b.cls: continue
		var ok := bool(Career.G.res.layout.get(L.id, false))
		var mods := []
		for k in L.m: mods.append("%s %s%d%%" % [str(k).to_upper(), "+" if float(L.m[k]) > 0 else "", int(L.m[k])])
		for k in L.t: mods.append("%s %s%d" % [CareerKit.TERR_SHORT.get(k, k), "+" if float(L.t[k]) > 0 else "", int(L.t[k])])
		var v := CareerKit.vbox(1)
		v.add_child(CareerKit.pair(L.n, U.money(float(Career.vehCost(b.id, L.id))) if ok else "LOCKED", Color.WHITE if ok else CareerKit.DIMC,
			CareerKit.MONEY if ok else CareerKit.DIMC, true))
		v.add_child(CareerKit.small(str(L.d), CareerKit.SUB if ok else CareerKit.DIMC))
		v.add_child(CareerKit.small(", ".join(mods) if not mods.is_empty() else "No modifiers", UIKit.GOLD if ok else CareerKit.DIMC))
		if ok and float(L.cm) != 0: v.add_child(CareerKit.line("Cost %+d%%" % int(round(float(L.cm) * 100)), CareerKit.SUB))
		if not ok: v.add_child(CareerKit.line("Research it first", CareerKit.DIMC))
		add(CareerKit.card_btn(v, _pick_layout.bind(L.id), "card", not ok, "layout_" + str(L.id)))

func _pick_layout(id: String) -> void:
	layout_id = id
	sys = null; sys_picked = false
	scroll.scroll_vertical = 0
	refresh()

# ---------------- step 3: fuel system ----------------
func _systems() -> void:
	var b: Dictionary = Data.D.BODY[body_id]
	var cyl := int(Data.D.LAYOUT_CYL.get(layout_id, 4))
	set_title("BUILD: FUEL")
	add(_body_head())
	add(CareerKit.sec("FUEL SYSTEM" + (" (%d CYL, %d CARB%s)" % [cyl, cyl, "S" if cyl > 1 else ""] if b.cls == "bike" else "")))
	for k in Tune.carbsFor({"body": body_id}):
		var C: Dictionary = Data.D.CARBS[k]
		var ok := Tune.carbAvail(k)
		var add_c := Career.sysCost(body_id, layout_id, {"type": "carb", "carb": k})
		var feats := ["+%d%% power" % int(round((float(C.pw) - 1) * 100)) if float(C.pw) > 1 else "Basic"]
		for p in C.p:
			if p.k == "pump": feats.append("accel pump")
		if C.get("kind") == "cv": feats.append("smooth CV slide")
		var v := CareerKit.vbox(1)
		v.add_child(CareerKit.lbl(CareerKit.carb_short(k), Color.WHITE if ok else CareerKit.DIMC, true, false))
		v.add_child(CareerKit.pair(", ".join(feats), ("+" + U.money(add_c) if add_c > 0 else "Included") if ok else "LOCKED", CareerKit.SUB if ok else CareerKit.DIMC,
			CareerKit.MONEY if ok else CareerKit.DIMC))
		if not ok:
			var t = Data.D.TECHM.get(str(C.un), {})
			v.add_child(CareerKit.line("Tech: " + str(t.get("n", "research")), CareerKit.DIMC))
		add(CareerKit.card_btn(v, _pick_sys.bind({"type": "carb", "carb": k}), "card", not ok, "sys_" + k))
	var okE := Tune.has("efi")
	var ve := CareerKit.vbox(1)
	ve.add_child(CareerKit.pair("EFI (fuel injection)", "+" + U.money(float(Tune.efiCost(b))) if okE else "LOCKED", Color.WHITE if okE else CareerKit.DIMC, CareerKit.MONEY if okE else CareerKit.DIMC, true))
	ve.add_child(CareerKit.small("Laptop-tuned injection: VE, spark and AFR tables. +5% power when mapped.", CareerKit.SUB if okE else CareerKit.DIMC))
	if not okE: ve.add_child(CareerKit.line("Tech: Throttle-Body EFI", CareerKit.DIMC))
	add(CareerKit.card_btn(ve, _pick_sys.bind({"type": "efi"}), "card", not okE, "sys_efi"))

func _pick_sys(s: Dictionary) -> void:
	sys = s
	sys_picked = true
	scroll.scroll_vertical = 0
	refresh()

# ---------------- step 4: estimate + confirm ----------------
func _cost() -> int:
	return Career.vehCost(body_id, layout_id) + Career.sysCost(body_id, layout_id, sys)

func _confirm() -> void:
	var G: Dictionary = Career.G
	var b: Dictionary = Data.D.BODY[body_id]
	set_title("BUILD: CONFIRM")
	add(_body_head(true))
	var cost := _cost()
	var q := Career.buildQ(body_id) + ({"b": 0.1, "s": 0.2, "g": 0.3}.get(spark, 0.0) as float)
	var rate := clampf(0.5 + 0.7 * Career.teamTech() / float(Data.D.RANK_REQ[b.rank]), 0.5, 1.8) * (1 + Career.facV("speed") / 100)
	var days := int(ceil(float(b.days) * float(Data.D.BUILD_MULT) / rate))
	add(CareerKit.sec("ESTIMATE"))
	add(CareerKit.pair("Team skill vs this machine", "%d%%" % int(round(q * 100)), CareerKit.TXT, CareerKit.GOOD if q >= 1 else CareerKit.WARN))
	add(CareerKit.pair("Stats vs spec", "~%d%%" % int(round(Career.qMult(minf(1.6, q)) * 100)), CareerKit.TXT, CareerKit.TXT))
	add(CareerKit.pair("Build time", "~%d days" % days, CareerKit.TXT, CareerKit.TXT))
	add(CareerKit.pair("Cost", U.money(cost), CareerKit.TXT, CareerKit.MONEY if float(G.money) >= cost else CareerKit.BAD))
	add(CareerKit.sec("THE BUILD, PHASE BY PHASE"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	for i in Data.D.BPH.size():
		var l := CareerKit.line("%d %s" % [i + 1, Data.D.BPHS[Data.D.BPH[i]]], CareerKit.TXT)
		grid.add_child(l)
	add(grid)
	note("You choose each phase as it comes together, plus whatever the shop throws at you. Or let the crew decide.", CareerKit.SUB)
	add(CareerKit.spark_row(spark, _set_spark))
	var why := ""
	if G.vehicles.size() >= int(Career.ws().veh): why = "Garage is full: sell or scrap a machine."
	elif G.jobs.size() >= Career.bays(): why = "All work bays are busy."
	elif float(G.money) < cost: why = "Not enough money."
	if why != "": footer.add_child(CareerKit.small(why, CareerKit.BAD))
	var go := CareerKit.btn("BUILD FOR %s" % U.money(cost), _do_build, Color("#2f8a4a"), false, "do_build")
	go.custom_minimum_size = Vector2(0, 30)
	go.disabled = why != ""
	footer.add_child(go)

func _set_spark(k: String) -> void:
	spark = k
	refresh()

func _do_build() -> void:
	var v := Career.startBuild(body_id, layout_id, spark if spark != "" else null, sys)
	if v.is_empty():
		refresh()
		return
	var r = router
	var vid = v.id
	close()
	if r: r.show_window({"kind": "build", "vid": vid})
