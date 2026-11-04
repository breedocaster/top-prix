extends "res://scripts/ui/career/sub_screen.gd"
## Staff: roster (drivers + mechanics with stats, level, energy, trait, salary and a chibi in team
## colours), hiring (candidates, scout), training (Data.D.TRAINING, sparks) and mechanic levels.
## ctx: {router?, tab?: "team"|"hire"|"train", sid?: preselected driver for training}

var train_sid = null
var spark := ""
var _lut_mat: ShaderMaterial = null
var _rows := {}

func _title() -> String: return "Staff"
func _tabs() -> Array: return [["team", "TEAM"], ["hire", "HIRE"], ["train", "TRAIN"]]

func _init_screen() -> void:
	train_sid = ctx.get("sid")

func _sig() -> String:
	var a := []
	for s in Career.G.staff: a.append("%s:%d:%d:%d" % [s.id, int(float(s.get("energy", 0)) / 5), int(s.get("lv", 1)), int(s.get("tech", 0))])
	for c in Career.G.cand: a.append(str(c.id))
	return "%s|%d|%d|%s" % [",".join(a), int(float(Career.G.money) / 1000), int(Career.G.rp), str(Career.G.sparks)]

func _head_info() -> String:
	return "%s\nRP %d" % [SK.money(float(Career.G.money)), int(Career.G.rp)]

# ---------------- body ----------------
func _fill(b: VBoxContainer) -> void:
	_build_lut()
	match tab:
		"team": _fill_team(b)
		"hire": _fill_hire(b)
		"train": _fill_train(b)

func _build_lut() -> void:
	var people := []
	_rows.clear()
	for s in Career.G.staff:
		_rows[s.id] = people.size(); people.append(s)
	for c in Career.G.cand:
		_rows[c.id] = people.size(); people.append(c)
	var tc := Color(str(Career.G.team.color))
	_lut_mat = SK.swap_material(SK.crew_lut(people, tc))

func _fill_team(b: VBoxContainer) -> void:
	var W := Career.ws()
	var sal := U.sum(Career.G.staff, func(s): return s.salary)
	var fame := ""
	if Career.drvCap() > int(W.teams) + 1 or Career.mechCap() > int(W.mech): fame = "  (+fame)"
	SK.note(b, "Drivers %d/%d  Mechanics %d/%d%s\nSalaries %s/month" % [Career.drivers().size(), Career.drvCap(), Career.mechs().size(), Career.mechCap(), fame, SK.money(sal)])
	b.add_child(SK.section("Drivers"))
	for s in Career.drivers():
		var row := _card(b, s)
		row.add_child(SK.act(SK.btn("TRAIN", _go_train.bind(s.id), UIKit.BTN, true), "train_sel:%d" % int(s.id)))
		row.add_child(SK.act(SK.btn("RELEASE", _ask_fire.bind(s.id), SK.RED, true), "fire:%d" % int(s.id)))
	b.add_child(SK.section("Mechanics"))
	for s in Career.mechs():
		var row := _card(b, s)
		if int(s.lv) < 10:
			var c := Career.mechLvCost(s)
			row.add_child(SK.act(SK.btn("LV UP %d RP" % c, _lvup.bind(s.id), UIKit.BTN, true, float(Career.G.rp) < c), "lvup:%d" % int(s.id)))
		else:
			var mx := SK.small("MAX LV", SK.GD, false)
			mx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(mx)
		row.add_child(SK.act(SK.btn("RELEASE", _ask_fire.bind(s.id), SK.RED, true), "fire:%d" % int(s.id)))

func _fill_hire(b: VBoxContainer) -> void:
	SK.note(b, "New faces arrive every month. More fans and a Scout Office bring better candidates. Signing fee = 3 months' salary.")
	if Career.G.cand.is_empty(): SK.note(b, "No candidates right now.", SK.DIM)
	for c in Career.G.cand:
		var fee := float(c.salary) * 3
		var row := _card(b, c)
		row.add_child(SK.act(SK.btn("HIRE %s" % SK.money(fee), _hire.bind(c.id), SK.GREEN, true, float(Career.G.money) < fee), "hire:%d" % int(c.id)))
	var sc := Career.scoutCost()
	var sb := SK.act(SK.btn("SCOUT NEW FACES (%s)" % SK.money(sc), _scout, UIKit.BTN, false, float(Career.G.money) < sc), "scout")
	b.add_child(sb)

func _fill_train(b: VBoxContainer) -> void:
	var ds := Career.drivers()
	if ds.is_empty():
		SK.note(b, "No drivers to train.")
		return
	if train_sid == null or Career.staff(train_sid).is_empty() or Career.staff(train_sid).role != "drv": train_sid = ds[0].id
	var s := Career.staff(train_sid)
	var chips := UIKit.hbox(2)
	for d in ds:
		chips.add_child(SK.act(SK.chip(str(d.name).split(" ")[0], d.id == train_sid, _sel_drv.bind(d.id)), "drv:%d" % int(d.id)))
	b.add_child(chips)
	_card(b, s)
	# sparks
	var sp: Dictionary = Career.G.sparks
	if int(sp.b) + int(sp.s) + int(sp.g) > 0:
		var h := UIKit.hbox(2)
		var l := SK.small("SPARK", SK.SUB, false)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		h.add_child(l)
		h.add_child(SK.act(SK.chip("NONE", spark == "", _set_spark.bind("")), "spark:"))
		for k in ["b", "s", "g"]:
			h.add_child(SK.act(SK.chip("%s %d" % [{"b": "BRZ", "s": "SLV", "g": "GLD"}[k], int(sp[k])], spark == k, _set_spark.bind(k), int(sp[k]) <= 0), "spark:" + k))
		b.add_child(h)
		if spark != "": b.add_child(SK.small("Next session x%.1f gains (%s Spark)" % [float(Career.SPARK_MUL[spark]), Career.SPARK_N[spark]], SK.HL))
	b.add_child(SK.section("Sessions"))
	for t in Data.D.TRAINING:
		var ok := Career.trainAvail(t.id)
		var tc := Career.trainCost(s, t)
		var en := int(U.round(float(t.en) * (0.6 if s.get("trait") == "iron" else 1.0)))
		var v := SK.card(b, "" if ok else "lock")
		var h := UIKit.hbox(4)
		v.add_child(h)
		var lv := UIKit.vbox(1)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lv)
		lv.add_child(SK.big(t.n, Color.WHITE if ok else SK.DIM))
		lv.add_child(SK.small("EN %d  %s" % [en, _gains_text(t)], SK.HL if ok else SK.DIM))
		if ok:
			var lab := ("+" + SK.money(-tc)) if tc < 0 else SK.money(tc)
			var dis := (tc > 0 and float(Career.G.money) < tc) or float(s.energy) < en
			var bt := SK.act(SK.sbtn(lab, _train.bind(t.id), SK.GREEN if tc < 0 else UIKit.BTN, 64, dis), "train:" + str(t.id))
			bt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(bt)
		else:
			h.add_child(SK.icon_rect("lock"))
			lv.add_child(SK.small("Sponsor reward", SK.DIM))

func _gains_text(t: Dictionary) -> String:
	var a := []
	for k in t.g:
		if k == "car" or k == "bike": a.append("%s affinity up" % k)
		elif k == "maxE": a.append("Max energy +%d" % int(t.g[k]))
		else: a.append("%s+%d" % [ABBR.get(k, str(k).to_upper()), int(t.g[k])])
	return " ".join(a) if not a.is_empty() else "Earn money"

const ABBR := {"pedal": "PED", "shift": "SHF", "steer": "STR", "appeal": "APL", "tech": "TEC", "analysis": "ANL"}

## Staff card; returns the button row for the caller to fill.
func _card(parent: Control, s: Dictionary) -> HBoxContainer:
	var drv: bool = s.role == "drv"
	var v := SK.card(parent)
	var top := UIKit.hbox(5)
	v.add_child(top)
	var port := PanelContainer.new()
	port.add_theme_stylebox_override("panel", UIKit.frame_new("inset", 1, 1, 1, 1))
	port.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var spr := SK.crew_sprite(s.role, int(_rows.get(s.id, 0)), _lut_mat, "stand", 2)
	spr.src = Rect2(spr.src.position + Vector2(0, 2), Vector2(24, 26))
	spr.custom_minimum_size = Vector2(48, 52)
	port.add_child(spr)
	top.add_child(port)
	var info := UIKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	info.add_child(SK.big(s.name))
	var role_line := UIKit.hbox(4)
	var rl := SK.small("DRIVER" if drv else "MECH LV%d" % int(s.lv), SK.BL, false)
	rl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	role_line.add_child(rl)
	var tr = s.get("trait")
	if tr != null and Data.D.TRAITS.has(tr): role_line.add_child(SK.tag(Data.D.TRAITS[tr].n))
	info.add_child(role_line)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 2)
	var stats := ["pedal", "shift", "steer"] if drv else []
	stats += ["appeal", "tech", "analysis"]
	for st in stats:
		var hi: bool = (drv and st in ["pedal", "shift", "steer"]) or (not drv and st == "tech")
		var l := SK.small("%s %d" % [ABBR[st], int(s[st])], SK.HL if hi else Color.WHITE, false)
		g.add_child(l)
	info.add_child(g)
	if drv: info.add_child(SK.small("CAR %sx BIKE %sx" % [U.to_fixed(float(s.aff.car), 2), U.to_fixed(float(s.aff.bike), 2)], SK.SUB, false))
	info.add_child(SK.small("PAY %s/MO" % SK.money(float(s.salary)), SK.SUB, false))
	if drv:
		if tr != null and Data.D.TRAITS.has(tr): v.add_child(SK.small(Data.D.TRAITS[tr].d, SK.DIM))
		var e := float(s.energy) / maxf(1.0, float(s.maxE))
		v.add_child(SK.bar_row("ENERGY", e, "%d/%d" % [int(float(s.energy)), int(float(s.maxE))], Color("#8ef58e") if e > 0.5 else (Color("#ffd84a") if e > 0.25 else Color("#ff6060"))))
	var btns := UIKit.hbox(3)
	v.add_child(btns)
	return btns

# ---------------- actions ----------------
func _go_train(sid) -> void:
	train_sid = sid
	tab = "train"
	rebuild(true)

func _sel_drv(sid) -> void:
	train_sid = sid
	rebuild()

func _set_spark(k: String) -> void:
	spark = k
	rebuild()

func _lvup(sid) -> void:
	if Career.levelMech(sid): rebuild()

func _hire(cid) -> void:
	if Career.hire(cid): rebuild()

func _scout() -> void:
	if Career.scout():
		say("New candidates arrived!")
		rebuild(true)

func _ask_fire(sid) -> void:
	var s := Career.staff(sid)
	if s.is_empty(): return
	confirm("Release staff?", "Let %s go? They won't come back." % SK.ascii(s.name), "RELEASE", _fire.bind(sid))

func _fire(sid) -> void:
	if Career.fire(sid): rebuild()

func _train(tid: String) -> void:
	var s := Career.staff(train_sid)
	if s.is_empty(): return
	var out = Career.train(train_sid, tid, spark if spark != "" else null)
	spark = ""
	if out is Dictionary:
		var a := []
		for k in out:
			if k == "money": a.append("+" + SK.money(absf(float(out[k]))))
			elif k == "car" or k == "bike": a.append("%s affinity up" % k)
			else: a.append("%s +%s" % [ABBR.get(k, str(k).to_upper()), str(out[k])])
		say("%s: %s" % [str(s.name).split(" ")[0], ", ".join(a) if not a.is_empty() else "done"])
		Career.sfx.emit("good")
	rebuild()
