class_name MachinesScreen
extends CareerPage
## MACHINES: every vehicle with its status, condition and stats; tap one for its screen.
## Test Day (part B) opens from here too.

func _init_page() -> void:
	set_title("MACHINES")

func _render() -> void:
	var G: Dictionary = Career.G
	add(CareerKit.pair("GARAGE %d/%d" % [G.vehicles.size(), int(Career.ws().veh)], "BAYS %d/%d" % [G.jobs.size(), Career.bays()], CareerKit.TXT, CareerKit.TXT))
	note("Tap a machine to upgrade it, fit parts, work on the engine, repair or sell it.", CareerKit.DIMC)
	if can_open("test_day"):
		var ready: Array = G.vehicles.filter(func(v): return v.status == "ready" and Career.engReady(v))
		var tb := CareerKit.btn("TEST DAY: LOG DATA & TRAIN", _test_day.bind(ready[0].id if not ready.is_empty() else null), UIKit.BTN, true, "test_day")
		tb.disabled = ready.is_empty()
		add(tb)
	if G.vehicles.is_empty():
		note("Empty garage! Use BUILD to make your first machine.", CareerKit.WARN)
		var bb := CareerKit.btn("BUILD", _go_build, Color("#2f8a4a"), false, "go_build")
		add(bb)
		return
	var mx := CareerKit.stat_max()
	for v in G.vehicles:
		add(card(v, mx, _open_vehicle.bind(v.id)))

## Vehicle summary card (also used by the prerace picker).
static func card(v: Dictionary, mx: float, cb: Callable, sel := false, compact := false) -> Control:
	var b: Dictionary = Data.D.BODY[v.body]
	var row := CareerKit.hbox(6)
	var pv := VehiclePortrait.new().setup(b.kind, Color(str(Career.G.team.color)))
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pv)
	var col := CareerKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := CareerKit.hbox(4)
	nm.add_child(CareerKit.big(v.name))
	var rk := CareerKit.lbl(b.rank, CareerKit.rank_col(b.rank), true, false)
	CareerKit.shrink(rk, true)
	nm.add_child(rk)
	col.add_child(nm)
	col.add_child(CareerKit.line("%s | Lv%d | %dW/%dR" % [Data.D.LAYOUT[v.layout].n, int(v.lv), int(v.wins), int(v.races)], CareerKit.SUB))
	col.add_child(status_line(v))
	if v.status != "build":
		var hp := CareerKit.hbox(4)
		var l := CareerKit.line("HP", CareerKit.SUB)
		CareerKit.shrink(l)
		hp.add_child(l)
		hp.add_child(CareerKit.bar(float(v.hp), hp_col(float(v.hp)), 0, 6))
		var e = v.get("eng")
		if e is Dictionary and e.fuel != "none":
			var l2 := CareerKit.line("ENG", CareerKit.SUB)
			CareerKit.shrink(l2)
			hp.add_child(l2)
			hp.add_child(CareerKit.bar(float(e.cond), hp_col(float(e.cond)), 0, 6))
		col.add_child(hp)
		if not compact:
			var st := Career.vs(v)
			for k in Career.STATS:
				col.add_child(CareerKit.stat_bar(k, float(st[k]), mx * (1.3 if k == "dur" else 1.0)))
		else:
			var st2 := Career.vs(v)
			col.add_child(CareerKit.stat_grid(st2))
			col.add_child(CareerKit.terr_row(st2, true))
	row.add_child(col)
	return CareerKit.card_btn(row, cb, "card_sel" if sel else "card", false, "veh_%d" % int(v.id))

static func hp_col(x: float) -> Color:
	if x > 0.5: return CareerKit.GOOD
	if x > 0.25: return UIKit.GOLD
	return CareerKit.BAD

static func status_line(v: Dictionary) -> Label:
	match str(v.status):
		"ready": return CareerKit.line("READY | parts %d/%d" % [v.parts.size(), Career.slots(v)], CareerKit.GOOD)
		"repair": return CareerKit.line("REPAIRING | HP %d%%" % int(round(float(v.hp) * 100)), CareerKit.BAD)
		"upgrade":
			var t := "IN THE SHOP"
			for j in Career.G.jobs:
				if j.vid == v.id:
					t = {"up": "TUNING " + str(j.get("k", "")).to_upper(), "reb": "ENGINE REBUILD", "swap": "FUEL SYSTEM SWAP"}.get(j.type, t)
			return CareerKit.line(t, CareerKit.RPC)
		"build":
			var j := Career.bJob(v.id)
			if j.get("pd") != null:
				return CareerKit.line("BUILD %s %d/8%s" % [Data.D.BPHS[Data.D.BPH[int(j.pi)]], int(j.pi) + 1, " !" if j.get("wait") != null else ""],
					UIKit.GOLD if j.get("wait") != null else CareerKit.WARN)
			return CareerKit.line("BUILDING", CareerKit.WARN)
	return CareerKit.line(str(v.status), CareerKit.SUB)

func _open_vehicle(vid) -> void:
	open("vehicle", {"vid": vid})

func _go_build() -> void:
	if router: router.replace("build")

func _test_day(vid) -> void:
	open("test_day", {"vid": vid})
