extends "res://scripts/ui/career/sub_screen.gd"
## Facilities + workshop: build / upgrade / demolish facilities (Career.facAvail, buildFac, upgradeFac,
## demolishFac) and move to the next workshop (wsNeed, canUpgradeWS, upgradeWS) with its perks.
## ctx: {router?}

const UNIT := {"regen": "/day", "scout": " tier", "merch": " $/fan"}

func _title() -> String: return "Workshop"

func _sig() -> String:
	return "%s|%d|%d|%d|%s" % [str(Career.G.fac), int(Career.G.ws), int(float(Career.G.money) / 1000), Career.G.st.titles.size(), str(Career.G.unl.fac)]

func _fill(b: VBoxContainer) -> void:
	_workshop(b)
	var W := Career.ws()
	var built: Array = Career.G.fac.filter(func(f): return f != null)
	b.add_child(SK.section("Facilities %d/%d" % [built.size(), int(W.fac)]))
	if built.is_empty(): b.add_child(SK.small("Nothing built yet.", SK.DIM))
	for f in built:
		var F: Dictionary = Data.D.FAC[f.id]
		var lv := int(f.lv)
		var v := SK.card(b)
		var top := UIKit.hbox(4)
		top.add_child(SK.badge(Color(F.col), F.n))
		top.add_child(SK.big(F.n))
		top.add_child(SK.tag("LV%d" % lv, SK.HL))
		v.add_child(top)
		v.add_child(SK.small("%s - now %s%s" % [F.d, _v(F.v[lv - 1]), UNIT.get(F.fx, "%")], SK.SUB))
		v.add_child(_pips(lv))
		var br := UIKit.hbox(3)
		if lv < 3:
			var c: float = float(F.cost[lv]) * 1000
			br.add_child(SK.act(SK.btn("UPGRADE %s" % SK.money(c), _up.bind(f.id), UIKit.BTN, true, float(Career.G.money) < c), "upfac:" + str(f.id)))
		else:
			var mx := SK.small("MAX LEVEL", SK.GD, false)
			br.add_child(mx)
		br.add_child(SK.act(SK.sbtn("REMOVE", _ask_rm.bind(f.id), SK.RED), "rmfac:" + str(f.id)))
		v.add_child(br)
	b.add_child(SK.section("Build new"))
	var full := built.size() >= int(W.fac)
	if full: SK.note(b, "No free facility slots. A bigger workshop has more room.", SK.BD)
	for F in Data.D.FACILITIES:
		if built.any(func(x): return x.id == F.id): continue
		var ok := Career.facAvail(F.id)
		var c2: float = float(F.cost[0]) * 1000
		var v := SK.card(b, "" if ok else "lock")
		var top := UIKit.hbox(4)
		top.add_child(SK.badge(Color(F.col) if ok else Color("#4a4f66"), F.n))
		top.add_child(SK.big(F.n, Color.WHITE if ok else SK.DIM))
		if ok: top.add_child(SK.act(SK.sbtn(SK.money(c2), _build.bind(F.id), SK.GREEN, 56, float(Career.G.money) < c2 or full), "build:" + str(F.id)))
		else: top.add_child(SK.icon_rect("lock"))
		v.add_child(top)
		var vals := []
		for x in F.v: vals.append(_v(x))
		v.add_child(SK.small("%s (%s%s)" % [F.d, " / ".join(vals), UNIT.get(F.fx, "%")], SK.SUB if ok else SK.DIM))
		if not ok: v.add_child(SK.small("Sponsor reward", SK.HL))

static func _v(x) -> String:
	var f := float(x)
	return str(int(f)) if f == floorf(f) else U.to_fixed(f, 1)

func _pips(lv: int) -> Control:
	var h := UIKit.hbox(2)
	for i in 3:
		var c := ColorRect.new()
		c.color = SK.HL if i < lv else Color("#2c3b70")
		c.custom_minimum_size = Vector2(24, 4)
		h.add_child(c)
	return h

func _workshop(b: VBoxContainer) -> void:
	var W := Career.ws()
	var v := SK.card(b, "sel")
	v.add_child(SK.big(W.n, SK.HL))
	v.add_child(SK.small("Drivers %d  Mechanics %d  Vehicles %d  Facilities %d  Sponsors %d" % [int(W.teams) + 1, int(W.mech), int(W.veh), int(W.fac), int(W.spon)], SK.SUB))
	var n = Career.wsNeed()
	if n == null:
		v.add_child(SK.small("Top workshop reached! " + ("Legend races are open." if Career.legendOpen() else "Win 2 World series to unlock Legend races."), SK.GD))
		return
	var N: Dictionary = Data.D.WORKSHOPS[int(Career.G.ws) + 1]
	v.add_child(SK.section("Next: " + N.n))
	var perks := []
	perks.append(["Drivers", int(W.teams) + 1, int(N.teams) + 1])
	perks.append(["Mechanics", int(W.mech), int(N.mech)])
	perks.append(["Vehicles", int(W.veh), int(N.veh)])
	perks.append(["Facilities", int(W.fac), int(N.fac)])
	perks.append(["Sponsors", int(W.spon), int(N.spon)])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 1)
	for p in perks:
		g.add_child(SK.small(p[0], SK.SUB, false))
		g.add_child(SK.small("%d -> %d" % [p[1], p[2]], SK.GD if p[2] > p[1] else Color.WHITE, false))
	v.add_child(g)
	v.add_child(SK.small("+ %s races, research and techs" % Data.D.TIER_N[int(Career.G.ws) + 1], SK.GD))
	var ok := Career.canUpgradeWS()
	var req := UIKit.hbox(4)
	req.add_child(SK.icon_rect("check" if ok else "lock"))
	req.add_child(SK.small("Win a %s series title" % Data.D.TIER_N[int(n.tier)], SK.GD if ok else SK.BD))
	v.add_child(req)
	var cost: float = float(n.cost)
	var mreq := UIKit.hbox(4)
	var rich := float(Career.G.money) >= cost
	mreq.add_child(SK.icon_rect("check" if rich else "lock"))
	mreq.add_child(SK.small("Cost %s" % SK.money(cost), SK.GD if rich else SK.BD))
	v.add_child(mreq)
	v.add_child(SK.act(SK.btn("MOVE TO " + str(N.n).to_upper(), _ask_ws, SK.GREEN if ok else SK.GREY, false, not ok or not rich), "upws"))

func _build(id: String) -> void:
	if Career.buildFac(id): rebuild()

func _up(id: String) -> void:
	if Career.upgradeFac(id): rebuild()

func _ask_rm(id: String) -> void:
	confirm("Remove facility?", "Tear down the %s? No refund." % SK.ascii(Data.D.FAC[id].n), "TEAR DOWN", _rm.bind(id))

func _rm(id: String) -> void:
	Career.demolishFac(id)
	rebuild()

func _ask_ws() -> void:
	var N: Dictionary = Data.D.WORKSHOPS[int(Career.G.ws) + 1]
	confirm("Move workshop?", "Move into the %s for %s?" % [SK.ascii(N.n), SK.money(float(Career.wsNeed().cost))], "MOVE", _ws, SK.GREEN)

func _ws() -> void:
	if Career.upgradeWS(): rebuild(true)
