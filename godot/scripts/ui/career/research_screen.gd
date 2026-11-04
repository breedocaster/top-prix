extends "res://scripts/ui/career/sub_screen.gd"
## Research: Tech tree (Data.D.TECH with prerequisites, workshop gating, RP costs), vehicle bodies
## (cars / bikes with SD sprites), layouts and parts. Spends RP via Career.researchTech / research.
## ctx: {router?, tab?: "tech"|"body"|"layout"|"part", cls?: "car"|"bike"}

var cls := "car"
var _mat: ShaderMaterial = null

const TCAT := ["Fuel", "Engine", "Chassis", "Crew"]

func _title() -> String: return "Research"
func _tabs() -> Array: return [["tech", "TECH"], ["body", "BODIES"], ["layout", "LAYOUTS"], ["part", "PARTS"]]

func _init_screen() -> void:
	cls = str(ctx.get("cls", "car"))

func _sig() -> String:
	return "%d|%d|%d|%d|%d" % [int(Career.G.rp), Career.G.tech.size(), int(Career.G.ws), Career.G.res.body.size() + Career.G.res.layout.size() + Career.G.res.part.size(),
		Career.G.unl.body.size() + Career.G.unl.layout.size() + Career.G.unl.part.size()]

func _fill(b: VBoxContainer) -> void:
	SK.note(b, "Research Data: %d RP. Earned from races (driver and mechanic Analysis boost it), scrapping and events." % int(Career.G.rp))
	match tab:
		"tech": _fill_tech(b)
		"body": _fill_bodies(b)
		"layout": _fill_layouts(b)
		"part": _fill_parts(b)

# ---------------- tech tree ----------------
## Tree order inside a category: each tech right after its last prerequisite (depth = tree depth).
func _tree(cat: String) -> Array:
	var list: Array = Data.D.TECH.filter(func(t): return t.cat == cat)
	var ids := {}
	for t in list: ids[t.id] = t
	var out := []
	var placed := {}
	var depth := {}
	var guard := 0
	while out.size() < list.size() and guard < 50:
		guard += 1
		for t in list:
			if placed.has(t.id): continue
			var reqs: Array = t.req.filter(func(x): return ids.has(x))
			if not reqs.all(func(x): return placed.has(x)): continue
			var d := 0
			var at := -1
			for q in reqs:
				d = maxi(d, int(depth[q]) + 1)
				at = maxi(at, out.find(q))
			# after the parent's existing subtree
			var pos := out.size()
			if at >= 0:
				pos = at + 1
				while pos < out.size() and int(depth[out[pos]]) > int(depth[out[at]]): pos += 1
			out.insert(pos, t.id)
			placed[t.id] = true
			depth[t.id] = d
	var res := []
	for id in out: res.append([ids[id], int(depth[id])])
	return res

func _fill_tech(b: VBoxContainer) -> void:
	var owned := 0
	for t in Data.D.TECH:
		if Tune.has(t.id): owned += 1
	b.add_child(SK.small("%d/%d technologies owned" % [owned, Data.D.TECH.size()], SK.GD))
	for cat in TCAT:
		b.add_child(SK.section(cat))
		for it in _tree(cat):
			_tech_card(b, it[0], it[1])

func _tech_card(parent: Control, t: Dictionary, depth: int) -> void:
	var av := Career.techAvail(t.id)
	var done := bool(av.get("done", false))
	var st := "done" if done else ("" if av.ok else "lock")
	var h := UIKit.hbox(0)
	parent.add_child(h)
	if depth > 0:
		var tw := TreeWire.new()
		tw.depth = depth
		tw.custom_minimum_size = Vector2(depth * 8, 0)
		tw.size_flags_vertical = Control.SIZE_FILL
		h.add_child(tw)
	var v := SK.card(h, st)
	v.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(4)
	v.add_child(top)
	var nm := SK.big(t.n, Color.WHITE if av.ok else SK.DIM)
	top.add_child(nm)
	if done:
		top.add_child(SK.icon_rect("check"))
	elif av.ok:
		var rp := int(t.rp)
		var bt := SK.act(SK.sbtn("%d RP" % rp, _res_tech.bind(t.id), UIKit.BTN, 58, float(Career.G.rp) < rp), "tech:" + str(t.id))
		top.add_child(bt)
	else:
		top.add_child(SK.icon_rect("lock"))
	v.add_child(SK.small(t.d, SK.SUB if av.ok else SK.DIM))
	if not t.req.is_empty() or int(t.ws) > 1:
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 3)
		fl.add_theme_constant_override("v_separation", 2)
		var nl := SK.small("NEEDS", SK.DIM, false)
		nl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		fl.add_child(nl)
		for q in t.req:
			var have := Tune.has(q)
			fl.add_child(SK.tag(Data.D.TECHM[q].n, SK.GD if have else SK.BD, Color("#16301f") if have else Color("#3a1c1c")))
		if int(t.ws) > 1:
			var wok := int(Career.G.ws) >= int(t.ws)
			fl.add_child(SK.tag(Data.D.WORKSHOPS[int(t.ws)].n, SK.GD if wok else SK.BD, Color("#16301f") if wok else Color("#3a1c1c")))
		v.add_child(fl)
	if not av.ok and not done:
		v.add_child(SK.small(str(av.get("why", "")), SK.HL))

## Tree connector: vertical line from the parent and an elbow into the card.
class TreeWire extends Control:
	var depth := 1
	func _draw() -> void:
		var x := depth * 8 - 5
		var c := Color("#4b5ea0")
		draw_rect(Rect2(x, -4, 1, 14), c)
		draw_rect(Rect2(x, 10, 5, 1), c)

func _res_tech(id: String) -> void:
	if Career.researchTech(id): rebuild()

# ---------------- bodies ----------------
func _fill_bodies(b: VBoxContainer) -> void:
	var h := UIKit.hbox(2)
	h.add_child(SK.act(SK.chip("CARS", cls == "car", _set_cls.bind("car")), "cls:car"))
	h.add_child(SK.act(SK.chip("BIKES", cls == "bike", _set_cls.bind("bike")), "cls:bike"))
	b.add_child(h)
	var tc := Color(str(Career.G.team.color))
	_mat = SK.swap_material(SpriteForge.palette([tc, Color("#6a7080")]))
	for B in Data.D.BODIES:
		if B.cls != cls: continue
		var av := Career.bodyAvail(B.id)
		var done := bool(av.get("done", false))
		var v := SK.card(b, "done" if done else ("" if av.ok else "lock"))
		var row := UIKit.hbox(4)
		v.add_child(row)
		var spr := SK.veh_sprite(B.kind, 0 if (done or av.ok) else 1, _mat)
		row.add_child(spr)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var top := UIKit.hbox(3)
		top.add_child(SK.big(B.n, Color.WHITE if av.ok else SK.DIM))
		top.add_child(SK.tag(B.rank, _rank_col(B.rank), Color("#140c24")))
		info.add_child(top)
		info.add_child(SK.StatBars.new([["SPD", B.s.spd, 500, Color("#ff8a5c")], ["ACC", B.s.acc, 500, Color("#ffd84a")],
			["HND", B.s.hnd, 500, Color("#7ac8ff")], ["DUR", B.s.dur, 560, Color("#8ef58e")]]))
		var tl := []
		for k in ["on", "off", "wet", "ice"]:
			var x := int(B.t[k])
			tl.append(["%s %d" % [{"on": "ON", "off": "OFF", "wet": "WET", "ice": "ICE"}[k], x], SK.GD if x >= 115 else (SK.BD if x < 70 else Color.WHITE)])
		info.add_child(SK.MiniLine.new(tl))
		var bot := UIKit.hbox(4)
		var ex := SK.small("%s  %d slots" % [SK.money(float(B.cost)), int(B.slots)], SK.SUB, false)
		bot.add_child(ex)
		if done: bot.add_child(SK.icon_rect("check"))
		elif av.ok: bot.add_child(SK.act(SK.sbtn("%d RP" % int(B.rp), _res.bind("body", B.id), UIKit.BTN, 58, float(Career.G.rp) < float(B.rp)), "body:" + str(B.id)))
		else:
			bot.add_child(SK.icon_rect("lock"))
		v.add_child(bot)
		if not av.ok and not done: v.add_child(SK.small(str(av.get("why", "")), SK.HL))

static func _rank_col(r: String) -> Color:
	return Color({"E": "#9aa2ad", "D": "#8ef58e", "C": "#7ac8ff", "B": "#c08aff", "A": "#ffb347", "S": "#ff5c8a"}.get(r, "#ffffff"))

func _set_cls(c: String) -> void:
	if c == cls: return
	cls = c
	rebuild(true)

func _res(kind: String, id: String) -> void:
	if Career.research(kind, id): rebuild()

# ---------------- layouts ----------------
func _fill_layouts(b: VBoxContainer) -> void:
	for L in Data.D.LAYOUTS:
		var av := Career.layoutAvail(L.id)
		var done := bool(av.get("done", false))
		var v := SK.card(b, "done" if done else ("" if av.ok else "lock"))
		var top := UIKit.hbox(4)
		top.add_child(SK.big("%s (%s)" % [L.n, L.cls], Color.WHITE if av.ok else SK.DIM))
		if done: top.add_child(SK.icon_rect("check"))
		elif av.ok: top.add_child(SK.act(SK.sbtn("%d RP" % int(L.rp), _res.bind("layout", L.id), UIKit.BTN, 58, float(Career.G.rp) < float(L.rp)), "layout:" + str(L.id)))
		else: top.add_child(SK.icon_rect("lock"))
		v.add_child(top)
		v.add_child(SK.small(L.d, SK.SUB))
		var fx := _mods(L.get("m", {}), L.get("t", {}))
		if fx != "": v.add_child(SK.small(fx, SK.HL))
		var cyl := int(Data.D.LAYOUT_CYL.get(L.id, 4))
		v.add_child(SK.small("Electric - no fuel system" if cyl == 0 else "%d cyl%s" % [cyl, " - one carb per cylinder" if L.cls == "bike" and cyl > 1 else ""], SK.DIM))
		if not av.ok and not done: v.add_child(SK.small(str(av.get("why", "")), SK.HL))

static func _mods(m: Dictionary, t: Dictionary) -> String:
	var a := []
	for k in m: a.append("%s %s%d%%" % [str(k).to_upper(), "+" if float(m[k]) > 0 else "", int(m[k])])
	for k in t: a.append("%s %s%d" % [Data.D.TERR_N[k], "+" if float(t[k]) > 0 else "", int(t[k])])
	return "  ".join(a)

# ---------------- parts ----------------
static func part_fx(P: Dictionary) -> String:
	var a := []
	for k in P.st:
		var x := int(P.st[k])
		a.append("%s %s%d" % [Data.D.TERR_N[k] if Data.D.TERR_N.has(k) else str(k).to_upper(), "+" if x > 0 else "", x])
	var fx: Dictionary = P.fx
	if fx.get("rp"): a.append("RP +%d%%" % int(round(float(fx.rp) * 100)))
	if fx.get("mis"): a.append("Mistakes -%d%%" % int(round((1 - float(fx.mis)) * 100)))
	if fx.get("wear"): a.append("Wear -%d%%" % int(round((1 - float(fx.wear)) * 100)))
	if fx.get("fan"): a.append("Fans +%d%%" % int(round(float(fx.fan) * 100)))
	return "  ".join(a)

func _fill_parts(b: VBoxContainer) -> void:
	for cat in Data.D.PART_CATS:
		var ps: Array = Data.D.PARTS.filter(func(p): return p.cat == cat)
		if ps.is_empty(): continue
		b.add_child(SK.section(Data.D.PART_CATS[cat]))
		for P in ps:
			var av := Career.partAvail(P.id)
			var done := bool(av.get("done", false))
			var v := SK.card(b, "done" if done else ("" if av.ok else "lock"))
			var top := UIKit.hbox(4)
			top.add_child(SK.big(P.n, Color.WHITE if av.ok else SK.DIM))
			if done: top.add_child(SK.icon_rect("check"))
			elif av.ok: top.add_child(SK.act(SK.sbtn("%d RP" % int(P.rp), _res.bind("part", P.id), UIKit.BTN, 58, float(Career.G.rp) < float(P.rp)), "part:" + str(P.id)))
			else: top.add_child(SK.icon_rect("lock"))
			v.add_child(top)
			var who: String = {"A": "Any", "C": "Cars", "B": "Bikes"}.get(P.cls, "Any")
			v.add_child(SK.small("T%d  %s  %s" % [int(P.tier), who, SK.money(float(P.cost))], SK.DIM, false))
			v.add_child(SK.small(part_fx(P), SK.HL))
			if not av.ok and not done: v.add_child(SK.small(str(av.get("why", "")), SK.HL))
