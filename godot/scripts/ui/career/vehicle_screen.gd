class_name VehicleScreen
extends CareerPage
## One machine (web UI.V.vehicle + ui2/ui3): spinning portrait header, tabs INFO / UPGRADE / PARTS /
## ENGINE, the staged-build sheet while it is being built, and doors to part B's workbench
## (bench_screen: carb / efi / sync / dyno / setup) and Test Day. ctx: {vid, tab?}

const TABS := [["info", "INFO"], ["upgrade", "UPGRADE"], ["parts", "PARTS"], ["engine", "ENGINE"]]

var vid
var spark := ""
var _portrait: VehiclePortrait
var _head_col: VBoxContainer

func _init_page() -> void:
	vid = ctx.get("vid")
	if not tab in ["info", "upgrade", "parts", "engine"]: tab = "info"
	var v := Career.veh(vid)
	if v.is_empty(): return
	var row := CareerKit.hbox(6)
	_portrait = VehiclePortrait.new().setup(Data.D.BODY[v.body].kind, Color(str(Career.G.team.color)), 2, true, 5)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait)
	_head_col = CareerKit.vbox(2)
	_head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_head_col)
	top_box.add_child(CareerKit.panel(row, "card"))

func _v() -> Dictionary: return Career.veh(vid)

func _render() -> void:
	var v := _v()
	if v.is_empty():
		close.call_deferred()
		return
	set_title(v.name)
	_head(v)
	if v.status == "build":
		set_tabs([])
		tabs_row.visible = false
		_build_sheet(v)
		return
	if _tabs.is_empty():
		set_tabs(TABS)
		_render_tabs()
	match tab:
		"upgrade": _upgrade(v)
		"parts": _parts(v)
		"engine": _engine(v)
		_: _info(v)

func _head(v: Dictionary) -> void:
	CareerKit.clear(_head_col)
	var b: Dictionary = Data.D.BODY[v.body]
	var e = v.get("eng")
	var nm := CareerKit.hbox(4)
	nm.add_child(CareerKit.big(v.name))
	var rk := CareerKit.lbl(b.rank, CareerKit.rank_col(b.rank), true, false)
	CareerKit.shrink(rk, true)
	nm.add_child(rk)
	_head_col.add_child(nm)
	_head_col.add_child(CareerKit.line("%s | %s" % ["Car" if b.cls == "car" else "Bike", Data.D.LAYOUT[v.layout].n], CareerKit.SUB))
	if e is Dictionary and e.fuel != "none":
		_head_col.add_child(CareerKit.small("EFI" if e.fuel == "efi" else CareerKit.carb_short(e.carb), UIKit.GOLD))
	_head_col.add_child(MachinesScreen.status_line(v))
	if v.status != "build":
		var lv := CareerKit.hbox(4)
		var l := CareerKit.line("Lv%d" % int(v.lv), CareerKit.TXT)
		CareerKit.shrink(l)
		lv.add_child(l)
		lv.add_child(CareerKit.bar(float(v.xp) / maxf(1.0, Career.vehXpNeed(v)) if int(v.lv) < 10 else 1.0, CareerKit.RPC, 0, 6))
		_head_col.add_child(lv)
		_head_col.add_child(_meter("HP", float(v.hp)))
		if e is Dictionary and e.fuel != "none": _head_col.add_child(_meter("ENG", float(e.cond)))

func _meter(t: String, x: float) -> HBoxContainer:
	var h := CareerKit.hbox(4)
	var l := CareerKit.line(t, CareerKit.SUB)
	l.custom_minimum_size = Vector2(26, 0)
	CareerKit.shrink(l)
	h.add_child(l)
	h.add_child(CareerKit.bar(x, MachinesScreen.hp_col(x), 0, 6))
	var n := CareerKit.line("%d%%" % int(round(x * 100)), CareerKit.TXT)
	n.custom_minimum_size = Vector2(32, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	CareerKit.shrink(n, true)
	h.add_child(n)
	return h

# ---------------- INFO ----------------
func _info(v: Dictionary) -> void:
	var st := Career.vs(v)
	var mx := CareerKit.stat_max()
	add(CareerKit.sec("STATS"))
	for k in Career.STATS: add(CareerKit.stat_bar(k, float(st[k]), mx * (1.3 if k == "dur" else 1.0)))
	add(CareerKit.terr_row(st))
	var fx := ["Ad appeal %d" % int(st.adv)]
	if float(st.fx.rp) > 0: fx.append("RP +%d%%" % int(round(float(st.fx.rp) * 100)))
	if float(st.fx.mis) < 1: fx.append("mistakes -%d%%" % int(round((1 - float(st.fx.mis)) * 100)))
	if float(st.fx.wear) < 1: fx.append("wear -%d%%" % int(round((1 - float(st.fx.wear)) * 100)))
	note(", ".join(fx), CareerKit.SUB)
	add(CareerKit.sec("RECORD"))
	add(CareerKit.pair("Level", "Lv%d  %d/%d XP" % [int(v.lv), int(v.xp), int(Career.vehXpNeed(v))] if int(v.lv) < 10 else "Lv10 MAX", CareerKit.TXT, CareerKit.RPC))
	add(CareerKit.pair("Races / wins", "%d / %d" % [int(v.races), int(v.wins)], CareerKit.TXT, UIKit.GOLD))
	add(CareerKit.pair("Part slots", "%d / %d" % [v.parts.size(), Career.slots(v)], CareerKit.TXT, CareerKit.TXT))
	add(CareerKit.pair("Build quality", "%d%%" % int(round(Career.qMult(minf(1.6, float(v.q))) * 100)), CareerKit.TXT, CareerKit.TXT))
	if v.status == "repair":
		var rb := CareerKit.btn("RUSH REPAIR %s" % U.money(Career.rushCost(v)), _rush, UIKit.ACCENT, false, "rush")
		rb.disabled = float(Career.G.money) < Career.rushCost(v)
		add(rb)
	add(CareerKit.sec("WORKBENCH"))
	var row := CareerKit.hbox(4)
	var td := CareerKit.btn("TEST DAY", open.bind("test_day", {"vid": vid}), UIKit.BTN, true, "test_day")
	td.disabled = not can_open("test_day") or v.status != "ready" or not Career.engReady(v)
	row.add_child(td)
	var su := CareerKit.btn("SETUP SHEET", open.bind("bench", {"vid": vid, "tab": "setup"}), UIKit.BTN, true, "bench_setup")
	su.disabled = not can_open("bench")
	row.add_child(su)
	add(row)
	if not can_open("bench") or not can_open("test_day"): note("Workbench screens are not installed in this build.", CareerKit.DIMC)
	add(CareerKit.sec("SELL OR SCRAP"))
	var r2 := CareerKit.hbox(4)
	r2.add_child(CareerKit.btn("SELL %s" % U.money(Career.sellValue(v)), _sell, UIKit.BTN_LO, true, "sell"))
	r2.add_child(CareerKit.btn("SCRAP +%d RP" % Career.scrapRP(v), _scrap, UIKit.ACCENT, true, "scrap"))
	add(r2)

func _rush() -> void:
	Career.rushRepair(vid)
	refresh()

func _sell() -> void:
	var v := _v()
	confirm("SELL MACHINE?", "Sell %s for %s?" % [v.name, U.money(Career.sellValue(v))], "SELL", _do_sell)

func _do_sell() -> void:
	if Career.sell(vid): close()

func _scrap() -> void:
	var v := _v()
	confirm("SCRAP MACHINE?", "Scrap %s for %d research data?" % [v.name, Career.scrapRP(v)], "SCRAP", _do_scrap)

func _do_scrap() -> void:
	if Career.scrap(vid): close()

# ---------------- UPGRADE ----------------
func _upgrade(v: Dictionary) -> void:
	var st := Career.vs(v)
	note("Each stat can be upgraded 5 times. Mechanics' Tech and facilities boost the gain.")
	for k in Career.STATS:
		var lv := int(v.up[k])
		var c := Career.upCost(v, k)
		var row := CareerKit.hbox(6)
		var col := CareerKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := CareerKit.hbox(6)
		nm.add_child(CareerKit.lbl(CareerKit.STAT_LONG[k], CareerKit.STAT_COL[k], true, false))
		var p := Pips.new()
		p.n = lv
		p.col = CareerKit.STAT_COL[k]
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_child(p)
		col.add_child(nm)
		col.add_child(CareerKit.line("Now %d | +%d tuned" % [int(st[k]), int(v.upAdd[k])], CareerKit.SUB))
		row.add_child(col)
		if lv < 5:
			var b := CareerKit.btn(U.money(c), _do_up.bind(k), UIKit.BTN, true, "up_" + k)
			CareerKit.shrink(b, true)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.custom_minimum_size = Vector2(56, 22)
			b.disabled = v.status != "ready" or float(Career.G.money) < c
			row.add_child(b)
		else:
			var mxl := CareerKit.lbl("MAX", CareerKit.GOOD, true, false)
			CareerKit.shrink(mxl, true)
			row.add_child(mxl)
		add(CareerKit.panel(row, "card"))
	add(CareerKit.spark_row(spark, _set_spark))
	if v.status != "ready": note("The machine must be READY to upgrade.", CareerKit.WARN)
	note("Upgrades take a work bay for a few days (%d/%d bays busy)." % [Career.G.jobs.size(), Career.bays()], CareerKit.DIMC)

func _set_spark(k: String) -> void:
	spark = k
	refresh()

func _do_up(k: String) -> void:
	Career.startUpgrade(vid, k, spark if spark != "" else null)
	spark = ""
	refresh()

class Pips extends Control:
	var n := 0
	var col := Color.WHITE
	func _init() -> void:
		custom_minimum_size = Vector2(5 * 7, 7)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in 5:
			draw_rect(Rect2(i * 7, 0, 6, 6), Color("#140c24"))
			draw_rect(Rect2(i * 7 + 1, 1, 4, 4), col if i < n else Color("#2a3460"))

# ---------------- PARTS ----------------
static func part_fx(P: Dictionary) -> String:
	var a := []
	for k in P.st:
		var nm: String = CareerKit.TERR_SHORT.get(k, str(k).to_upper())
		a.append("%s %s%d" % [nm, "+" if float(P.st[k]) > 0 else "", int(P.st[k])])
	var fx: Dictionary = P.get("fx", {})
	if fx.get("rp"): a.append("RP +%d%%" % int(round(float(fx.rp) * 100)))
	if fx.get("mis"): a.append("Mistakes -%d%%" % int(round((1 - float(fx.mis)) * 100)))
	if fx.get("wear"): a.append("Wear -%d%%" % int(round((1 - float(fx.wear)) * 100)))
	if fx.get("fan"): a.append("Fans +%d%%" % int(round(float(fx.fan) * 100)))
	return ", ".join(a)

func _parts(v: Dictionary) -> void:
	var D: Dictionary = Data.D
	var b: Dictionary = D.BODY[v.body]
	note("Slots %d/%d. One part per category: fitting one replaces the old. Engine, exhaust and intake parts change the fueling, so retune after fitting!" % [v.parts.size(), Career.slots(v)])
	add(CareerKit.sec("INSTALLED"))
	if v.parts.is_empty(): note("None yet.", CareerKit.DIMC)
	for pid in v.parts:
		var P: Dictionary = D.PART[pid]
		var row := CareerKit.hbox(6)
		var col := CareerKit.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(CareerKit.big(P.n))
		col.add_child(CareerKit.line("%s | Lv%d" % [D.PART_CATS[P.cat], Career.partLv(pid)], CareerKit.SUB))
		col.add_child(CareerKit.small(part_fx(P), UIKit.GOLD))
		row.add_child(col)
		var rb := CareerKit.btn("REMOVE", _rm_part.bind(pid), UIKit.ACCENT, true, "rm_" + str(pid))
		CareerKit.shrink(rb, true)
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rb)
		add(CareerKit.panel(row, "card"))
	add(CareerKit.sec("AVAILABLE"))
	var n := 0
	var locked := 0
	for P in D.PARTS:
		if not Career.partClsOk(P, b.cls) or v.parts.has(P.id): continue
		if not Career.G.res.part.get(P.id):
			locked += 1
			continue
		n += 1
		var c := Career.partCost(P.id)
		var rep := ""
		for x in v.parts:
			if D.PART[x].cat == P.cat: rep = D.PART[x].n
		var row2 := CareerKit.hbox(6)
		var col2 := CareerKit.vbox(1)
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col2.add_child(CareerKit.big(P.n))
		col2.add_child(CareerKit.line("%s | T%d%s" % [D.PART_CATS[P.cat], int(P.tier), (" | replaces " + rep) if rep != "" else ""], CareerKit.SUB))
		col2.add_child(CareerKit.small(part_fx(P), UIKit.GOLD))
		row2.add_child(col2)
		var ib := CareerKit.btn(U.money(c), _inst_part.bind(P.id), UIKit.OK, true, "inst_" + str(P.id))
		CareerKit.shrink(ib, true)
		ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ib.custom_minimum_size = Vector2(52, 22)
		ib.disabled = float(Career.G.money) < c or (rep == "" and v.parts.size() >= Career.slots(v))
		row2.add_child(ib)
		add(CareerKit.panel(row2, "card"))
	if n == 0: note("Nothing new to fit. Research parts in RESEARCH.", CareerKit.DIMC)
	if locked > 0: note("%d more parts to research." % locked, CareerKit.DIMC)

func _rm_part(pid: String) -> void:
	confirm("REMOVE PART?", "%s will be discarded." % Data.D.PART[pid].n, "REMOVE", _do_rm.bind(pid))

func _do_rm(pid: String) -> void:
	Career.removePart(vid, pid)
	refresh()

func _inst_part(pid: String) -> void:
	Career.installPart(vid, pid)
	refresh()

# ---------------- ENGINE ----------------
func _engine(v: Dictionary) -> void:
	var D: Dictionary = Data.D
	var e = v.get("eng")
	var b: Dictionary = D.BODY[v.body]
	if not (e is Dictionary) or e.fuel == "none":
		note("Electric motor: nothing to rebuild or jet. Lucky you.", CareerKit.GOOD)
		_bench_row(v, ["setup"])
		return
	var cyl := Tune.cyl(v)
	var sysn: String = "EFI" if e.fuel == "efi" else "%s x%d" % [CareerKit.carb_short(e.carb), Tune.nCarbs(v)]
	var card := CareerKit.vbox(2)
	card.add_child(CareerKit.big("%d-cylinder %s" % [cyl, D.LAYOUT[v.layout].n]))
	card.add_child(CareerKit.small(sysn + " | " + str(D.FUELS[e.get("fuelT", "pump")].n), UIKit.GOLD))
	card.add_child(_meter("COND", float(e.cond)))
	if float(e.cond) <= 0.02: card.add_child(CareerKit.small("Engine is dead: rebuild before racing.", CareerKit.BAD))
	elif float(e.cond) < 0.4: card.add_child(CareerKit.small("Tired engine: rebuild soon.", CareerKit.WARN))
	if float(e.cond) < 0.999:
		var rb := CareerKit.btn("REBUILD ENGINE %s" % U.money(Tune.rebuildCost(v)), _rebuild, UIKit.OK, true, "rebuild")
		rb.disabled = v.status != "ready" or float(Career.G.money) < Tune.rebuildCost(v)
		card.add_child(rb)
	add(CareerKit.panel(card, "card"))
	add(CareerKit.sec("WORKBENCH"))
	_bench_row(v, ["efi" if e.fuel == "efi" else "carb", "sync", "dyno", "setup"])
	add(CareerKit.sec("FUEL"))
	var f := CareerKit.flow(3)
	for k in D.FUELS:
		var F: Dictionary = D.FUELS[k]
		var ok: bool = not F.get("tech") or Tune.has(str(F.tech))
		var t := str(F.n) + ((" %s/race" % U.money(float(F.cost))) if float(F.cost) > 0 else "")
		f.add_child(CareerKit.chip(t if ok else t + " (locked)", _fuel.bind(k), str(e.get("fuelT", "pump")) == k, not ok, "fuel_" + k))
	add(f)
	var ft := str(e.get("fuelT", "pump"))
	if ft == "e85": note("E85 needs ~32% more fuel. Jet up a lot!" if e.fuel == "carb" else "Flex sensor adjusts the EFI automatically." if Tune.has("e85") else "", CareerKit.WARN)
	else: note("Race gas and E85 add knock margin.", CareerKit.DIMC)
	add(CareerKit.sec("FUEL SYSTEM"))
	for k in Tune.carbsFor(v):
		if k == e.get("carb") and e.fuel != "efi": continue
		var C: Dictionary = D.CARBS[k]
		var ok2 := Tune.carbAvail(k)
		var feats := ["+%d%% power" % int(round((float(C.pw) - 1) * 100)) if float(C.pw) > 1 else "Basic"]
		for p in C.p:
			if p.k == "pump": feats.append("accel pump")
		if C.get("kind") == "cv": feats.append("CV slide")
		if int(C.get("carbs", 1)) > 1 or (C.cls == "bike" and cyl > 1): feats.append("needs sync")
		var lock := "" if ok2 else "Tech: " + str(D.TECHM.get(str(C.un), {}).get("n", "research"))
		add(_swap_row(CareerKit.carb_short(k), ", ".join(feats), Tune.carbSwapCost(b, k), lock, {"type": "carb", "carb": k}, v, "swap_" + k))
	if e.fuel != "efi":
		add(_swap_row("Convert to EFI", "Laptop tuning: VE, spark and AFR tables. +5% power when mapped.", Tune.efiCost(b),
			"" if Tune.has("efi") else "Tech: Throttle-Body EFI", {"type": "efi"}, v, "swap_efi"))
	var lg = e.get("log")
	if lg is Dictionary:
		add(CareerKit.sec("LAST DATALOG"))
		note("%s | %s | %s" % [str(lg.get("src", "")), Career.dateStr(int(lg.get("d", 0))), str(lg.get("cond", ""))], CareerKit.SUB)
		add(CareerKit.zone_grid(lg.get("lam", {}), bool(lg.get("wb", false))))

func _swap_row(title: String, sub: String, cost: int, lock: String, sys: Dictionary, v: Dictionary, tid: String) -> Control:
	var row := CareerKit.hbox(6)
	var col := CareerKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(CareerKit.lbl(title, Color.WHITE if lock == "" else CareerKit.DIMC, true, false))
	col.add_child(CareerKit.small(sub, CareerKit.SUB if lock == "" else CareerKit.DIMC))
	if lock != "": col.add_child(CareerKit.line(lock, CareerKit.DIMC))
	row.add_child(col)
	if lock == "":
		var b := CareerKit.btn(U.money(cost), _swap.bind(sys, title), UIKit.BTN, true, tid)
		CareerKit.shrink(b, true)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(52, 22)
		b.disabled = v.status != "ready" or float(Career.G.money) < cost
		row.add_child(b)
	return CareerKit.panel(row, "card" if lock == "" else "card_dim")

func _bench_row(v: Dictionary, tabs: Array) -> void:
	var f := CareerKit.flow(3)
	var names := {"carb": "CARBS", "efi": "EFI LAPTOP", "sync": "SYNC", "dyno": "DYNO", "setup": "SETUP"}
	for t in tabs:
		var b := CareerKit.btn(names.get(t, str(t).to_upper()), open.bind("bench", {"vid": vid, "tab": t}), UIKit.BTN, true, "bench_" + str(t))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not can_open("bench")
		f.add_child(b)
	add(f)
	if not can_open("bench"): note("Workbench screens are not installed in this build.", CareerKit.DIMC)

func _rebuild() -> void:
	Career.startRebuild(vid)
	refresh()

func _fuel(k: String) -> void:
	Career.setFuelT(vid, k)
	refresh()

func _swap(sys: Dictionary, title: String) -> void:
	var v := _v()
	var what := "EFI (base map: needs tuning!)" if sys.type == "efi" else title
	confirm("CHANGE FUEL SYSTEM?", "Fit %s to %s? Takes a few days in a work bay." % [what, v.name], "FIT IT", _do_swap.bind(sys), UIKit.OK)

func _do_swap(sys: Dictionary) -> void:
	Career.startSwap(vid, sys)
	refresh()

# ---------------- staged build sheet ----------------
func _build_sheet(v: Dictionary) -> void:
	var D: Dictionary = Data.D
	var j := Career.bJob(vid)
	if j.is_empty() or j.get("pd") == null:
		note("Still being built...", CareerKit.WARN)
		return
	var pr := clampf(1.0 - float(j.left) / maxf(0.01, float(j.total)), 0.0, 1.0)
	add(CareerKit.sec("BUILD SHEET"))
	add(CareerKit.bar(pr, CareerKit.WARN, 0, 8))
	note("~%d work-days left (crew speed decides real days)" % int(ceil(float(j.left))), CareerKit.SUB)
	var ch: Dictionary = j.get("ch", {}) if j.get("ch") is Dictionary else {}
	for i in D.BPH.size():
		var ph: String = D.BPH[i]
		var op := ""
		if ch.has(ph):
			for o in Career.bOpts(v, ph):
				if o.id == ch[ph]: op = str(o.n)
		var mark := "-"
		var col := CareerKit.DIMC
		var right := op
		if i < int(j.pi) or op != "":
			mark = "+"; col = CareerKit.GOOD
		elif i == int(j.pi):
			mark = ">"; col = UIKit.GOLD
			right = "WAITING ON YOU" if j.get("wait") != null else "in progress"
		var h := CareerKit.hbox(4)
		var l := CareerKit.tag("%s %s" % [mark, D.BPHS[ph]], col)
		l.custom_minimum_size = Vector2(92, 0)
		h.add_child(l)
		h.add_child(CareerKit.small(right, UIKit.GOLD if right == "WAITING ON YOU" else CareerKit.SUB))
		add(h)
	var ev := []
	for x in v.get("blog", []):
		var is_ph := false
		for p in D.BPH:
			if str(x).begins_with(str(D.BPHN[p])): is_ph = true
		if not is_ph: ev.append(str(x))
	if not ev.is_empty():
		add(CareerKit.sec("SHOP LOG"))
		for x in ev: note("* " + x, CareerKit.SUB)
	var bm = v.get("bm")
	if bm is Dictionary:
		var fx := []
		for k in Career.STATS:
			if float(bm[k]) != 0: fx.append("%s %s%d%%" % [str(k).to_upper(), "+" if float(bm[k]) > 0 else "", int(round(float(bm[k])))])
		for k in Career.TERRS:
			if float(bm[k]) != 0: fx.append("%s %s%d" % [CareerKit.TERR_SHORT[k], "+" if float(bm[k]) > 0 else "", int(bm[k])])
		if int(v.get("slotB", 0)) > 0: fx.append("+%d slot" % int(v.slotB))
		if not fx.is_empty():
			add(CareerKit.sec("BUILD SO FAR"))
			note(", ".join(fx), UIKit.GOLD)
	if j.get("wait") != null:
		var w: Dictionary = j.wait
		var t := "MAKE THE %s CALL" % (str(D.BPHN[w.ph]).to_upper() if w.k == "ph" else "SHOP")
		var b := CareerKit.btn(t, _decide, Color("#2f8a4a"), true, "decide")
		b.custom_minimum_size = Vector2(0, 28)
		footer.add_child(b)

func _decide() -> void:
	Career.bDecide(vid)
