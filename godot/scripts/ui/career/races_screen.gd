class_name RacesScreen
extends CareerPage
## RACES (web UI.V.race): tier chips, then RACES (calendar by discipline: state, best finish, surface,
## prize, the outlook of your best ready machine) or SERIES (enter, rounds, standings, next round).
## ctx: {tab?: "races"|"series", tier?: int}

var tier := 1

func _init_page() -> void:
	set_title("RACES")
	set_tabs([["races", "RACES"], ["series", "SERIES"]])
	if not tab in ["races", "series"]: tab = "races"
	tier = int(ctx.get("tier", mini(int(Career.G.ws), 4)))

func _max_tier() -> int: return 5 if Career.legendOpen() else int(Career.G.ws)

func _render() -> void:
	var D: Dictionary = Data.D
	var tr := CareerKit.hbox(3)
	for t in range(1, 6):
		var ok := t <= _max_tier()
		var c := CareerKit.chip("T%d" % t, _set_tier.bind(t), tier == t, false, "tier_%d" % t)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not ok: c.add_theme_color_override("font_color", CareerKit.DIMC)
		tr.add_child(c)
	add(tr)
	add(CareerKit.pair(str(D.TIER_N[tier]).to_upper(), "" if tier <= _max_tier() else ("Win 2 World series" if tier == 5 else "Needs " + str(D.WORKSHOPS[tier].n)),
		UIKit.GOLD, CareerKit.DIMC, true))
	if tab == "series": _series()
	else: _races()

func _set_tier(t: int) -> void:
	tier = t
	scroll.scroll_vertical = 0
	refresh()

## Best ready pairing for a race: [odds, vehicle] or [] when nothing can enter.
static func best_odds(r: Dictionary) -> Array:
	var vs := Career.eligibleVehicles(r)
	var ds := Career.eligibleDrivers()
	if vs.is_empty() or ds.is_empty(): return []
	var s: Dictionary = U.sort_by(ds, func(d): return float(d.pedal) + float(d.shift) + float(d.steer), true)[0]
	var best := -1.0
	var bv := {}
	for v in vs:
		var o := Career.oddsRatio(r, v, s)
		if o > best: best = o; bv = v
	return [best, bv]

func _races() -> void:
	var D: Dictionary = Data.D
	var G: Dictionary = Career.G
	Career.odds_cache = {}
	var any := false
	for disc in D.DISC:
		var rs: Array = D.RACES.filter(func(r): return int(r.tier) == tier and r.disc == disc and not r.excl)
		if rs.is_empty(): continue
		any = true
		add(CareerKit.sec(str(D.DISC[disc].n).to_upper()))
		for r in rs: add(_race_card(r))
	Career.odds_cache = null
	if not any: note("No races at this tier.", CareerKit.DIMC)
	var n := 0
	for id in G.series:
		if G.series[id].get("act") != null: n += 1
	if n > 0: note("%d series in progress: see the SERIES tab." % n, UIKit.GOLD)

func _race_card(r: Dictionary) -> Control:
	var st := Career.raceState(r.id)
	var rr: Dictionary = Career.G.races.get(r.id, {})
	var ok: bool = st.ok
	var v := CareerKit.vbox(2)
	var top := CareerKit.hbox(4)
	top.add_child(CareerKit.lbl(r.n, Color.WHITE if ok else CareerKit.DIMC, true, false))
	var b := Career.best(r.id)
	if b < 99:
		var m := CareerKit.lbl(U.ord(b), [UIKit.GOLD, Color("#d8dce8"), Color("#e0975a")][b - 1] if b <= 3 else CareerKit.SUB, true, false)
		CareerKit.shrink(m, true)
		top.add_child(m)
	v.add_child(top)
	v.add_child(CareerKit.surf_bar(r))
	var cls := "Cars & bikes" if r.cls == "any" else ("Cars" if r.cls == "car" else "Bikes")
	var surf := []
	for k in r.surf: surf.append(str(Data.D.SURF[k].n))
	v.add_child(CareerKit.line("%s | %s | %d lap%s | R%d" % [cls, "/".join(surf), int(r.laps), "" if int(r.laps) == 1 else "s", int(r.R)], CareerKit.SUB))
	var pz := "Prize %s" % U.money(float(r.prize))
	if not rr.is_empty(): pz += " | ran %dx won %dx" % [int(rr.get("n", 0)), int(rr.get("w", 0))]
	v.add_child(CareerKit.line(pz, CareerKit.MONEY if ok else CareerKit.DIMC))
	if Career.G.yearWins.get(r.id): v.add_child(CareerKit.line("Won this year: reduced prize", CareerKit.WARN))
	if not ok:
		v.add_child(CareerKit.small("LOCKED: " + str(st.why), CareerKit.DIMC))
	else:
		var bo := best_odds(r)
		if bo.is_empty():
			var why := "Drivers too tired to race" if not Career.eligibleVehicles(r).is_empty() else "No ready machine for this one"
			v.add_child(CareerKit.line(why, CareerKit.DIMC))
		else:
			var o := CareerKit.odds(float(bo[0]))
			v.add_child(CareerKit.line("Outlook: %s (%d%%)" % [o[0], int(round(float(bo[0]) * 100))], o[1]))
			if Career.G.vehicles.size() > 1: v.add_child(CareerKit.line("  best with " + str(bo[1].name), CareerKit.SUB))
	if not Story.rival_for(r.id).is_empty(): v.add_child(CareerKit.line("Crownwell Racing is entered!", Color("#c890ff")))
	return CareerKit.card_btn(v, _pick.bind(r.id), "card", not ok, "race_" + str(r.id))

func _pick(rid: String) -> void:
	open("prerace", {"rid": rid})

func _series() -> void:
	var D: Dictionary = Data.D
	var G: Dictionary = Career.G
	note("Win normal races to unlock a series. Win a series to unlock a bigger workshop. Points: %s..." % "-".join(PackedStringArray(D.POINTS.slice(0, 5).map(func(x): return str(int(x))))), CareerKit.SUB)
	var any := false
	for S in D.SERIES:
		if int(S.tier) != tier: continue
		any = true
		add(_series_card(S))
	if not any: note("No series at this tier.", CareerKit.DIMC)

func _series_card(S: Dictionary) -> Control:
	var G: Dictionary = Career.G
	var D: Dictionary = Data.D
	var st := Career.seriesState(S.id)
	var sv: Dictionary = G.series.get(S.id, {})
	var a = sv.get("act")
	var live: bool = a is Dictionary
	var v := CareerKit.vbox(2)
	var top := CareerKit.hbox(4)
	top.add_child(CareerKit.lbl(S.n, Color.WHITE if (st.ok or live) else CareerKit.DIMC, true, false))
	if int(sv.get("titles", 0)) > 0:
		var tl := CareerKit.lbl("TITLE x%d" % int(sv.titles), UIKit.GOLD, false, false)
		CareerKit.shrink(tl, true)
		top.add_child(tl)
	v.add_child(top)
	v.add_child(CareerKit.small("%s | %d rounds | %d teams" % [D.DISC[S.disc].n, S.rounds.size(), int(S.rivals) + 1], CareerKit.SUB))
	v.add_child(CareerKit.line("Champion %s | entry %s" % [U.money(float(S.prize)), U.money(float(S.fee))], CareerKit.MONEY))
	var rounds := CareerKit.vbox(1)
	for i in S.rounds.size():
		var rid: String = S.rounds[i]
		var res := ""
		if live and i < a.res.size(): res = "  > " + (str(a.res[i]) if a.res[i] is String else U.ord(int(a.res[i])))
		var cur: bool = live and int(a.round) == i
		rounds.add_child(CareerKit.line("%s%d. %s%s" % ["> " if cur else "  ", i + 1, D.RACE[rid].n, res], UIKit.GOLD if cur else CareerKit.TXT))
	v.add_child(rounds)
	var btn: Button = null
	if live:
		v.add_child(CareerKit.sec("STANDINGS"))
		var tb := Career.standings(S.id)
		for i in mini(5, tb.size()):
			var me: bool = tb[i][0] == "you"
			v.add_child(CareerKit.pair("%d. %s" % [i + 1, G.team.name if me else str(tb[i][0])], "%d pts" % int(tb[i][1]), UIKit.GOLD if me else CareerKit.TXT, UIKit.GOLD if me else CareerKit.SUB))
		if bool(a.get("pending", false)):
			btn = CareerKit.btn("RACE ROUND %d NOW" % (int(a.round) + 1), _race_round.bind(S.id), UIKit.OK, true, "round_" + str(S.id))
		else:
			v.add_child(CareerKit.line("Next round in %d days" % maxi(0, int(a.next) - int(G.day)), UIKit.GOLD))
	elif st.ok:
		btn = CareerKit.btn("ENTER (%s)" % U.money(float(S.fee)), _enter.bind(S.id), UIKit.OK, true, "enter_" + str(S.id))
		btn.disabled = float(G.money) < float(S.fee)
	else:
		v.add_child(CareerKit.small("LOCKED: " + str(st.why), CareerKit.DIMC))
	if btn: v.add_child(btn)
	var kind := "card"
	if live: kind = "card_gold"
	elif not st.ok: kind = "card_dim"
	return CareerKit.panel(v, kind)

func _enter(sid: String) -> void:
	var S: Dictionary = Data.D.SER[sid]
	confirm("ENTER %s?" % str(S.n).to_upper(), "Entry fee %s. %d rounds, one every 3 weeks. Each round you choose who races." % [U.money(float(S.fee)), S.rounds.size()],
		"ENTER", _do_enter.bind(sid), UIKit.OK)

func _do_enter(sid: String) -> void:
	Career.enterSeries(sid)
	refresh()

func _race_round(sid: String) -> void:
	var a: Dictionary = Career.G.series[sid].act
	open("prerace", {"rid": Data.D.SER[sid].rounds[int(a.round)], "sid": sid})
