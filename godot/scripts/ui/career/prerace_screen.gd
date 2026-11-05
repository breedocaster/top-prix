class_name PreraceScreen
extends CareerPage
## Pre-race (web ui2 UI.V.prerace): course map + surfaces, race-day conditions, format, vehicle and
## driver pickers, engine outlook (symptoms, warnings, crew tune), tactic, odds, START.
## Team entries: up to Career.entryCap() cars in one race (CAR 1 / CAR 2 / + ADD), each its own machine
## and driver; the pickers below edit the selected car.
## ctx: {rid, sid?: series id (a championship round: back = skip the round)}

var rid := ""
var sid = null
var fmt_id := ""
var sel_v = null              # the selected car's machine / driver (mirrors picks[cur])
var sel_d = null
var picks: Array = []         # [{"v": vehicle id, "d": driver id}] one per team car
var cur := 0
var tactic := "normal"
## Last start per race class (car / bike / any): the cars, drivers and tactic come back next time
## (machines or drivers that are busy or tired are swapped for the next best automatically).
static var _last := {}
var _map: TrackMini

func _init_page() -> void:
	rid = str(ctx.get("rid", ""))
	sid = ctx.get("sid")
	if sid != null and str(sid) == "": sid = null
	var r: Dictionary = Data.D.RACE[rid]
	set_title(r.n)
	tactic = str(ctx.get("tactic", "normal"))
	fmt_id = str(ctx.get("fmt", ""))
	var mem: Dictionary = _last.get(_mem_key(r), {})
	if not mem.is_empty():
		picks = (mem.picks as Array).duplicate(true)
		if not ctx.has("tactic"): tactic = str(mem.tactic)

static func _mem_key(r: Dictionary) -> String: return "%s|%s" % [str(Career.G.team.get("name", "")), str(r.cls)]

func _on_back() -> bool:
	if sid == null: return true
	confirm("SKIP THIS ROUND?", "You will score no points this round.", "SKIP", _skip)
	return false

func _skip() -> void:
	if sid != null and Career.G.series.get(sid, {}).get("act") != null: Career.seriesRoundSkip(sid)
	close()

func _series_live() -> bool:
	return sid != null and Career.G.series.get(sid, {}).get("act") is Dictionary

func _fmts(r: Dictionary) -> Array:
	return [Career.seriesFormat(r)] if sid != null else Career.formats(r)

func _render() -> void:
	var D: Dictionary = Data.D
	var G: Dictionary = Career.G
	var r: Dictionary = D.RACE[rid]
	if sid != null and not _series_live(): sid = null       # the round was settled elsewhere
	var fmts := _fmts(r)
	var fmt: Dictionary = fmts[0]
	for f in fmts:
		if f.id == fmt_id: fmt = f
	fmt_id = fmt.id
	var laps_o = fmt.laps if int(fmt.laps) != int(r.laps) else null
	var tr := RaceSim.build_track(r, false, laps_o)
	var cond := Tune.forecast(r)
	# selections (web defaults: best odds vehicle, most rested driver), one pair per team car
	var vs := Career.eligibleVehicles(r)
	var okd := Career.eligibleDrivers()
	Career.odds_cache = {}
	var cap := Career.entryCap() if Career.multiEntryOk(fmt) else 1
	if picks.is_empty(): picks = [{"v": sel_v, "d": sel_d}]
	if picks.size() > cap: picks = picks.slice(0, cap)
	cur = clampi(cur, 0, picks.size() - 1)
	var used_v := []
	var used_d := []
	for pk in picks:
		if pk.v != null and (used_v.has(pk.v) or not vs.any(func(x): return x.id == pk.v)): pk.v = null
		if pk.v == null and not vs.is_empty():
			var d0: Dictionary = Career.drivers()[0]
			var best := -1.0
			for v in vs:
				if used_v.has(v.id): continue
				var o := Career.oddsRatio(r, v, d0)
				if o > best: best = o; pk.v = v.id
		if pk.v != null: used_v.append(pk.v)
		if pk.d != null and (used_d.has(pk.d) or not okd.any(func(x): return x.id == pk.d)): pk.d = null
		if pk.d == null:
			var free := okd.filter(func(x): return not used_d.has(x.id))
			if not free.is_empty(): pk.d = U.sort_by(free, func(s): return float(s.energy), true)[0].id
		if pk.d != null: used_d.append(pk.d)
	sel_v = picks[cur].v
	sel_d = picks[cur].d
	# header: series round, map, surfaces, conditions
	if sid != null:
		var S: Dictionary = D.SER[sid]
		var a: Dictionary = G.series[sid].act
		add(CareerKit.panel(CareerKit.small("%s | Round %d/%d%s" % [S.n, int(a.round) + 1, S.rounds.size(), (" | you have %d pts" % int(a.pts.get("you", 0))) if int(a.round) > 0 else ""], UIKit.GOLD), "card_gold"))
	var top := CareerKit.hbox(6)
	if _map == null or _map.rid != rid or _map.laps != int(tr.laps):
		_map = TrackMini.new()
		_map.setup(r, tr)
	if _map.get_parent(): _map.get_parent().remove_child(_map)
	top.add_child(_map)
	var info := CareerKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(CareerKit.line("%s | T%d %s" % [D.DISC[r.disc].n, int(r.tier), str(D.TIER_N[int(r.tier)])], CareerKit.TXT))
	info.add_child(CareerKit.line("Cars & bikes" if r.cls == "any" else ("Cars only" if r.cls == "car" else "Bikes only"), CareerKit.SUB))
	info.add_child(CareerKit.surf_bar(r))
	var cnt := {}
	for s in tr.secs: cnt[s.type] = int(cnt.get(s.type, 0)) + 1
	var secs := []
	for k in cnt: secs.append("%s x%d" % [D.SEC[k].n, cnt[k]])
	info.add_child(CareerKit.small(", ".join(secs), CareerKit.SUB))
	info.add_child(CareerKit.line("%d %s | rating %d" % [int(tr.laps), "stages" if tr.p2p and int(tr.laps) > 1 else ("stage" if tr.p2p else ("pass" if tr.drag else "laps")), int(r.R)], CareerKit.TXT))
	top.add_child(info)
	add(CareerKit.panel(top, "card"))
	add(_cond_line(cond))
	if not Story.rival_for(rid).is_empty():
		var dy: Dictionary = Story.rival_for(rid)
		add(CareerKit.panel(CareerKit.small("Crownwell Racing is on the grid: %s." % str(dy.get("drv", "")), Color("#d8b0ff")), "card_red"))
	# format
	add(CareerKit.sec("FORMAT"))
	for f in fmts:
		var mul: Dictionary = f.mul
		var sub := "%s prize, %s RP, %s wear" % [_x(mul.prize), _x(mul.rp), _x(mul.get("wear", 1))]
		var fv := CareerKit.vbox(1)
		fv.add_child(CareerKit.lbl(CareerKit.asc(f.n), Color.WHITE, false, true))
		fv.add_child(CareerKit.line(sub, CareerKit.SUB))
		add(CareerKit.card_btn(fv, _set_fmt.bind(f.id), "card_sel" if f.id == fmt_id else "card", false, "fmt_" + str(f.id)))
	# team entries
	var multi := picks.size() > 1
	if cap >= 2 and (multi or (vs.size() >= 2 and okd.size() >= 2)):
		add(CareerKit.sec("ENTRIES %d/%d" % [picks.size(), cap]))
		var eh := CareerKit.hbox(3)
		for i in picks.size():
			var c := CareerKit.chip("CAR %d" % (i + 1), _set_cur.bind(i), i == cur, false, "entry_%d" % i)
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eh.add_child(c)
		if picks.size() < cap and vs.size() > picks.size() and okd.size() > picks.size():
			var ad := CareerKit.chip("+ ADD CAR", _add_entry, false, false, "entry_add")
			ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eh.add_child(ad)
		if multi:
			var rm := CareerKit.chip("REMOVE", _remove_entry, false, false, "entry_remove")
			rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			eh.add_child(rm)
		add(eh)
		note("Every car races in the same event. Each earns its own prize and wears its own machine and driver; RP and fans count your best car in full, the others at half.", CareerKit.DIMC)
	elif not Career.multiEntryOk(fmt) and vs.size() >= 2 and okd.size() >= 2:
		note("Drag eliminations take one car per team.", CareerKit.DIMC)
	# vehicle
	add(CareerKit.sec("MACHINE" if not multi else "MACHINE - CAR %d" % (cur + 1)))
	if vs.is_empty():
		var why := "No ready %smachine! " % ("" if r.cls == "any" else str(r.cls) + " ")
		why += "Your eligible machines are busy or need an engine rebuild." if G.vehicles.any(func(x): return Career.clsOk(r, x)) else "Build one first."
		note(why, CareerKit.WARN)
	for v in vs:
		var other := _owner_of("v", v.id)
		if other >= 0 and other != cur:
			add(CareerKit.small("CAR %d:" % (other + 1), UIKit.GOLD))
			add(MachinesScreen.card(v, CareerKit.stat_max(), _set_cur.bind(other), false, true))
		else:
			add(MachinesScreen.card(v, CareerKit.stat_max(), _set_v.bind(v.id), v.id == sel_v, true))
	var v0 := Career.veh(sel_v)
	if not v0.is_empty(): _engine_outlook(v0, r, tr, cond, cnt)
	# driver
	add(CareerKit.sec("DRIVER" if not multi else "DRIVER - CAR %d" % (cur + 1)))
	for s in Career.drivers():
		var od := _owner_of("d", s.id)
		if od >= 0 and od != cur: add(CareerKit.small("CAR %d:" % (od + 1), UIKit.GOLD))
		add(_driver_card(s, od if od != cur else -1))
	# tactic
	add(CareerKit.sec("TACTIC"))
	var th := CareerKit.hbox(3)
	for k in ["safe", "normal", "push"]:
		var c := CareerKit.chip(str(D.TAC[k].n).to_upper(), _set_tac.bind(k), tactic == k, false, "tac_" + k)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(0, 22)
		th.add_child(c)
	add(th)
	note("Safe: fewer mistakes, less wear, cooler engine. Push: faster, riskier, hotter." + (" Push also risks a red light." if r.style == "drag" else ""), CareerKit.DIMC)
	# outlook + start
	var s0 := Career.staff(sel_d)
	if not v0.is_empty() and not s0.is_empty():
		var o := Career.oddsRatio(r, v0, s0)
		var ol := CareerKit.odds(o)
		var oh := CareerKit.hbox(4)
		var a := CareerKit.lbl("OUTLOOK", CareerKit.SUB, false, false)
		CareerKit.shrink(a)
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		oh.add_child(a)
		oh.add_child(CareerKit.lbl(ol[0], ol[1], true, false))
		var pc := CareerKit.lbl("%d%% pace" % int(round(o * 100)), CareerKit.SUB, false, false)
		CareerKit.shrink(pc, true)
		pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		oh.add_child(pc)
		footer.add_child(CareerKit.panel(oh, "card"))
		var label := "START RACE"
		match str(fmt.kind):
			"drag": label = "START ELIMINATIONS"
			"heats": label = "START HEAT"
			"tt": label = "START RUN 1" if int(fmt.get("runs", 1)) == 2 else ("START STAGE 1" if int(fmt.laps) > 1 and tr.p2p else "START RUN")
		if multi: label += " (%d CARS)" % picks.size()
		var go := CareerKit.btn(label, _go, Color("#2f8a4a"), false, "start")
		go.custom_minimum_size = Vector2(0, 30)
		footer.add_child(go)
	elif not v0.is_empty():
		footer.add_child(CareerKit.small("Every driver is too tired to race. Rest them a few days.", CareerKit.WARN))
	if sid != null:
		footer.add_child(CareerKit.btn("SKIP THIS ROUND", back, UIKit.BTN_LO, true, "skip_round"))
	Career.odds_cache = null

static func _x(m) -> String:
	var f := float(m)
	if is_equal_approx(f, 1.0): return "1x"
	return ("%.2f" % f).rstrip("0").rstrip(".") + "x"

func _cond_line(c: Dictionary) -> Control:
	var h := CareerKit.flow(8)
	var hill: bool = float(c.alt2) != float(c.alt)
	for it in [["%dC" % int(c.temp), CareerKit.TXT], ["%dm%s" % [int(c.alt), (" > %dm" % int(c.alt2)) if hill else ""], CareerKit.TXT],
			["air %d%%%s" % [int(round(float(c.rho) * 100)), (" > %d%%" % int(round(float(c.rho2) * 100))) if hill else ""], CareerKit.RPC],
			["NIGHT" if c.get("tod") == "night" else "DAY", UIKit.GOLD]]:
		var l := CareerKit.lbl(it[0], it[1], false, false)
		CareerKit.shrink(l)
		h.add_child(l)
	var p := CareerKit.panel(h, "card")
	return p

func _engine_outlook(v: Dictionary, r: Dictionary, tr: Dictionary, cond: Dictionary, cnt: Dictionary) -> void:
	var e = v.get("eng")
	if not (e is Dictionary) or e.fuel == "none": return
	var D: Dictionary = Data.D
	var m := Tune.mode()
	var box := CareerKit.vbox(2)
	box.add_child(CareerKit.sec("ENGINE OUTLOOK"))
	box.add_child(CareerKit.small(("EFI" if e.fuel == "efi" else CareerKit.carb_short(e.carb)) + " | " + str(D.FUELS[e.get("fuelT", "pump")].n), CareerKit.SUB))
	if m == "easy":
		box.add_child(CareerKit.small("The crew will jet and map for these conditions before the start.", CareerKit.GOOD))
	elif m == "sim":
		box.add_child(CareerKit.small("Sim mode: no crew forecast. Trust your datalogs.", CareerKit.SUB))
	else:
		var rsx := Tune.raceSecs(v, r, tr, cond)
		var ev: Dictionary = rsx.ev
		var wb := Tune.has("wideband")
		box.add_child(CareerKit.zone_grid(ev.lam, wb))
		var w := []
		if float(cond.alt2) != float(cond.alt):
			var c2 := cond.duplicate()
			c2.alt = cond.alt2
			c2.temp = float(cond.temp) - (float(cond.alt2) - float(cond.alt)) * 0.0065
			var tp := Tune.eval(v, c2, cond.rho2)
			w.append(["At the summit WOT goes %s" % (("to %.1f" % Tune.afr(float(tp.lam.wot))) if wb else str(Tune.zoneLabel(float(tp.lam.wot), "wot")[0]).to_lower()), CareerKit.SUB])
		if float(ev.kd.get("wot", 0)) > 0.3 or float(ev.kd.get("mid", 0)) > 0.3: w.append(["! Knock risk under load: pull timing, richen or run better fuel", CareerKit.BAD])
		if float(ev.lh.get("wot", 0)) > 0.3 or float(ev.lh.get("mid", 0)) > 0.3: w.append(["! Lean under load: engine damage likely", CareerKit.BAD])
		if bool(ev.get("seize", false)): w.append(["! Two-stroke too lean: seizure risk!", CareerKit.BAD])
		if bool(ev.get("starve", false)) and (cnt.has("jmp") or cnt.has("rgh")): w.append(["Low fuel level + jumps = starvation", CareerKit.WARN])
		if bool(ev.get("flood", false)) and cnt.has("rgh"): w.append(["High fuel level + rough sections = flooding", CareerKit.WARN])
		if bool(ev.get("foul", false)): w.append(["Very rich idle: may foul a plug", CareerKit.WARN])
		if float(ev.get("imb", 0)) > 1.2: w.append(["Carbs out of sync", CareerKit.WARN])
		if float(e.cond) < 0.4: w.append(["Engine is tired: rebuild soon", CareerKit.BAD])
		for s in Tune.symptoms(ev, e.fuel == "efi"):
			if not str(s).begins_with("Crisp"): w.append([str(s), CareerKit.SUB])
		if w.is_empty(): w.append(["No warnings from the crew.", CareerKit.GOOD])
		for x in w: box.add_child(CareerKit.small(x[0], x[1]))
	var f := CareerKit.flow(3)
	if can_open("bench"):
		f.add_child(CareerKit.btn("EFI" if e.fuel == "efi" else "CARBS", open.bind("bench", {"vid": v.id, "tab": "efi" if e.fuel == "efi" else "carb", "rid": rid, "cond": cond}), UIKit.BTN, true, "pre_tune"))
		f.add_child(CareerKit.btn("SETUP", open.bind("bench", {"vid": v.id, "tab": "setup", "rid": rid, "cond": cond}), UIKit.BTN, true, "pre_setup"))
	if m == "standard" and Tune.has("crewchief"):
		var cb := CareerKit.btn("CREW TUNE %s" % U.money(Tune.crewCost()), _crew_tune.bind(cond), UIKit.OK, true, "crew_tune")
		cb.disabled = float(Career.G.money) < Tune.crewCost()
		f.add_child(cb)
	if f.get_child_count() > 0: box.add_child(f)
	add(CareerKit.panel(box, "card"))

func _driver_card(s: Dictionary, other := -1) -> Control:
	var D: Dictionary = Data.D
	var ok := float(s.energy) >= Career.raceEnergy(s)
	var row := CareerKit.hbox(6)
	var face := CrewFace.new().setup(s, Career.G.team.color)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var col := CareerKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(CareerKit.lbl(s.name, Color.WHITE if ok else CareerKit.DIMC, true, false))
	if s.get("trait") != null and D.TRAITS.has(s.trait):
		col.add_child(CareerKit.small("%s: %s" % [D.TRAITS[s.trait].n, D.TRAITS[s.trait].d], UIKit.GOLD))
	col.add_child(CareerKit.line("PED %d SHF %d STR %d" % [int(s.pedal), int(s.shift), int(s.steer)], CareerKit.TXT))
	col.add_child(CareerKit.line("Car x%.2f  Bike x%.2f" % [float(s.aff.car), float(s.aff.bike)], CareerKit.SUB))
	var eh := CareerKit.hbox(4)
	var el := CareerKit.line("ENERGY", CareerKit.SUB)
	CareerKit.shrink(el)
	eh.add_child(el)
	eh.add_child(CareerKit.bar(float(s.energy) / maxf(1.0, float(s.maxE)), CareerKit.GOOD if ok else CareerKit.BAD, 0, 6))
	col.add_child(eh)
	if not ok: col.add_child(CareerKit.line("Too tired to race", CareerKit.BAD))
	row.add_child(col)
	var cb: Callable = _set_cur.bind(other) if other >= 0 else _set_d.bind(s.id)
	return CareerKit.card_btn(row, cb, "card_sel" if s.id == sel_d else "card", not ok, "drv_%d" % int(s.id))

func _set_fmt(id: String) -> void:
	fmt_id = id
	refresh()

func _set_v(id) -> void:
	sel_v = id
	picks[cur].v = id
	refresh()

func _set_d(id) -> void:
	sel_d = id
	picks[cur].d = id
	refresh()

## Which team car (index) has this machine ("v") or driver ("d"), or -1.
func _owner_of(k: String, id) -> int:
	for i in picks.size():
		if picks[i][k] == id: return i
	return -1

func _set_cur(i: int) -> void:
	cur = i
	refresh()

func _add_entry() -> void:
	picks.append({"v": null, "d": null})
	cur = picks.size() - 1
	refresh()

func _remove_entry() -> void:
	if picks.size() < 2: return
	picks.remove_at(cur)
	cur = clampi(cur - 1, 0, picks.size() - 1)
	refresh()

func _set_tac(k: String) -> void:
	tactic = k
	refresh()

func _crew_tune(cond: Dictionary) -> void:
	if Career.buyCrewTune(sel_v, cond):
		if router: router._on_toast("Crew tuned for race-day conditions")
	refresh()

func _go() -> void:
	var ens := []
	for pk in picks:
		var v := Career.veh(pk.v)
		var s := Career.staff(pk.d)
		if v.is_empty() or s.is_empty():
			if router: router._on_toast("Pick a machine and driver for every car")
			return
		if float(s.energy) < Career.raceEnergy(s):
			if router: router._on_toast("%s is too tired" % s.name)
			return
		ens.append([pk.v, pk.d])
	_last[_mem_key(Data.D.RACE[rid])] = {"picks": picks.duplicate(true), "tactic": tactic}
	var c := {"rid": rid, "vid": ens[0][0], "drv": ens[0][1], "tactic": tactic, "sid": sid, "fmt": fmt_id}
	if ens.size() > 1: c.entries = ens
	if router: router.replace("race", c)

## Small course map (TrackGeo polyline), drawn once.
class TrackMini extends Control:
	var rid := ""
	var laps := 0
	var pts := PackedVector2Array()
	var closed := true
	var col := Color("#9aa2ad")
	func setup(r: Dictionary, tr: Dictionary) -> void:
		rid = str(r.id)
		laps = int(tr.laps)
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := TrackGeo.build(tr, rid)
		closed = g.closed
		var box := Vector2(64, 64)
		var rr := g.bbox.grow(-140) if g.bbox.size.x > 300 and g.bbox.size.y > 300 else g.bbox
		var sc: float = minf((box.x - 10) / maxf(rr.size.x, 1.0), (box.y - 10) / maxf(rr.size.y, 1.0))
		var off := (box - rr.size * sc) * 0.5 - rr.position * sc
		pts = PackedVector2Array()
		for i in range(0, g.pts.size(), 4): pts.append((g.pts[i] * sc + off).round())
		if closed and pts.size() > 0: pts.append(pts[0])
		var main := RaceSim.main_surf(tr)
		if Data.D.SURF.has(main): col = Color(str(Data.D.SURF[main].col)).lightened(0.15)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#140c24"))
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("#0a1a14"))
		if pts.size() < 2: return
		draw_polyline(pts, Color("#3a3c46"), 4.0)
		draw_polyline(pts, col, 2.0)
		draw_rect(Rect2(pts[0] - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
