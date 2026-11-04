extends "res://scripts/ui/career/sub_screen.gd"
## Records: team overview (fan rank + progress, score, record, sparks, this season, books), titles and
## season history per series, achievements (Data.D.ACH vs G.ach) and the news log.
## ctx: {router?, tab?: "team"|"titles"|"awards"|"news"}

func _title() -> String: return "Records"
func _tabs() -> Array: return [["team", "TEAM"], ["titles", "TITLES"], ["awards", "AWARDS"], ["news", "NEWS"]]

func _sig() -> String:
	return "%d|%d|%d|%d|%d" % [int(Career.G.day) / 7, Career.G.ach.size(), Career.G.st.titles.size(), int(Career.G.st.races), Career.G.log.size()]

func _fill(b: VBoxContainer) -> void:
	match tab:
		"team": _fill_team(b)
		"titles": _fill_titles(b)
		"awards": _fill_awards(b)
		"news": _fill_news(b)

func _kv(g: GridContainer, k: String, val: String, col: Color = Color.WHITE) -> void:
	g.add_child(SK.small(k, SK.SUB, false))
	var l := SK.small(val, col, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	g.add_child(l)

func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 2)
	return g

func _fill_team(b: VBoxContainer) -> void:
	var G := Career.G
	var v := SK.card(b, "sel")
	var top := UIKit.hbox(5)
	var sw := ColorRect.new()
	sw.color = Color(str(G.team.color))
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(sw)
	top.add_child(SK.big(G.team.name, Color.WHITE))
	v.add_child(top)
	v.add_child(SK.small("%s  (Year %d/%d)" % [Career.dateStr(), Career.year(), int(Data.D.YEARS)], SK.SUB))
	# fan rank
	var rk := Career.fanRank()
	var FR: Array = Data.D.FAN_RANKS
	v.add_child(SK.small("%s team - %s fans" % [Career.fanRankName(), U.num(float(G.fans))], SK.HL))
	if rk + 1 < FR.size():
		var lo := float(FR[rk][0]); var hi := float(FR[rk + 1][0])
		v.add_child(SK.bar_row("RANK", (float(G.fans) - lo) / maxf(1.0, hi - lo), "%s" % U.num(hi), Color("#ff8a5c")))
		v.add_child(SK.small("Next: %s at %s fans" % [FR[rk + 1][1], U.num(hi)], SK.DIM))
	else:
		v.add_child(SK.small("Top fan rank reached!", SK.GD))
	# score
	var sc := SK.card(b)
	var sh := UIKit.hbox(4)
	sh.add_child(SK.big("SCORE", SK.SUB))
	var sl := UIKit.title(U.num(float(Career.score())), SK.HL)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sl)
	sc.add_child(sh)
	sc.add_child(SK.small("Titles, wins, podiums, fans, money and workshop size all count.", SK.DIM))
	# record
	var rc := SK.card(b)
	rc.add_child(SK.section("Career record"))
	var st: Dictionary = G.st
	var g := _grid()
	_kv(g, "Races", str(int(st.races)))
	_kv(g, "Wins", str(int(st.wins)), SK.HL)
	_kv(g, "Podiums", str(int(st.podiums)))
	_kv(g, "DNFs", str(int(st.dnf)), SK.BD if int(st.dnf) > 0 else Color.WHITE)
	_kv(g, "Titles", str(st.titles.size()), SK.HL)
	_kv(g, "Tests", str(int(st.get("tests", 0))))
	_kv(g, "Streak", str(int(st.get("streak", 0))))
	_kv(g, "Awards", "%d" % G.ach.size())
	rc.add_child(g)
	rc.add_child(SK.small("Prize money %s" % SK.money(float(st.earn)), SK.GD))
	var sp := UIKit.hbox(3)
	sp.add_child(SK.small("SPARKS", SK.SUB, false))
	for k in ["b", "s", "g"]:
		sp.add_child(SK.icon_rect("spark_" + k))
		sp.add_child(SK.small("%d" % int(G.sparks[k]), Color.WHITE, false))
	rc.add_child(sp)
	# this season
	var yc := SK.card(b)
	yc.add_child(SK.section("Season %d so far" % Career.year()))
	var y: Dictionary = G.year
	var g2 := _grid()
	_kv(g2, "Wins", str(int(y.wins)), SK.HL)
	_kv(g2, "Podiums", str(int(y.podiums)))
	_kv(g2, "Titles", str(int(y.titles)), SK.HL)
	_kv(g2, "Prize", SK.money(float(y.earn)), SK.GD)
	yc.add_child(g2)
	# books
	var bk := SK.card(b)
	bk.add_child(SK.section("Books"))
	var lm = G.get("lastMonth")
	if lm is Dictionary:
		bk.add_child(SK.small("Sponsors +%s" % SK.money(float(lm.sp)), SK.GD))
		if float(lm.get("merch", 0)) > 0: bk.add_child(SK.small("Merch +%s" % SK.money(float(lm.merch)), SK.GD))
		bk.add_child(SK.small("Salaries -%s" % SK.money(float(lm.sal)), SK.BD))
	else:
		bk.add_child(SK.small("First month-end coming up.", SK.DIM))

func _fill_titles(b: VBoxContainer) -> void:
	var G := Career.G
	var tc := SK.card(b, "sel")
	tc.add_child(SK.section("Trophy case"))
	if G.st.titles.is_empty():
		tc.add_child(SK.small("No titles yet. Win races to open a series, then win the series!", SK.DIM))
	else:
		var counts := {}
		for t in G.st.titles: counts[t] = int(counts.get(t, 0)) + 1
		for t in counts:
			var S: Dictionary = Data.D.SER[t]
			var h := UIKit.hbox(4)
			h.add_child(SK.icon_rect("medal", 2))
			var tl := SK.small("%s x%d" % [S.n, int(counts[t])], SK.HL)
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(tl)
			tc.add_child(h)
	for tier in range(1, 6):
		var ss: Array = Data.D.SERIES.filter(func(x): return int(x.tier) == tier)
		if ss.is_empty(): continue
		b.add_child(SK.section(Data.D.TIER_N[tier]))
		for S in ss:
			var sv = G.series.get(S.id)
			var champ: bool = sv is Dictionary and int(sv.get("titles", 0)) > 0
			var v := SK.card(b, "done" if champ else "")
			var top := UIKit.hbox(4)
			top.add_child(SK.big(S.n, Color.WHITE))
			top.add_child(SK.tag(Data.D.DISC[S.disc].n, SK.BL))
			v.add_child(top)
			var line := ""
			var col := SK.SUB
			if sv is Dictionary and sv.get("act") != null:
				var a: Dictionary = sv.act
				var tb := Career.standings(S.id)
				var pos := 1
				for i in tb.size():
					if tb[i][0] == "you": pos = i + 1
				line = "IN PROGRESS: round %d/%d, %s with %d pts" % [int(a.round) + 1, S.rounds.size(), U.ord(pos), int(a.pts.get("you", 0))]
				col = SK.HL
			elif sv is Dictionary:
				var best := int(sv.get("best", 99))
				line = ("Champions x%d" % int(sv.titles)) if champ else ("Best finish %s" % (U.ord(best) if best < 99 else "-"))
				if sv.get("lastEnd") != null: line += "  - last season %s" % Career.dateStr(int(sv.lastEnd))
				col = SK.HL if champ else SK.SUB
			else:
				var ss2 := Career.seriesState(S.id)
				line = "Open - not entered yet" if ss2.ok else "Locked: %s" % str(ss2.get("why", ""))
				col = SK.GD if ss2.ok else SK.DIM
			v.add_child(SK.small(line, col))

func _fill_awards(b: VBoxContainer) -> void:
	var G := Career.G
	var got: int = G.ach.size()
	var nv := SK.card(b, "sel")
	nv.add_child(SK.small("%d/%d achievements unlocked" % [got, Data.D.ACH.size()], SK.HL))
	nv.add_child(SK.bar(float(got) / maxf(1.0, Data.D.ACH.size()), Color("#ffd84a"), 6))
	for a in Data.D.ACH:
		var on = G.ach.get(a.id)
		var v := SK.card(b, "done" if on else "lock")
		var h := UIKit.hbox(5)
		v.add_child(h)
		h.add_child(SK.icon_rect("medal" if on else "medal_off", 2))
		var info := UIKit.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(SK.big(a.n, Color.WHITE if on else SK.SUB))
		info.add_child(SK.small(a.d, SK.SUB if on else SK.DIM))
		var rw: Dictionary = a.get("rw", {})
		var r := []
		if rw.get("cash"): r.append(SK.money(float(rw.cash) * 1000))
		if rw.get("rp"): r.append("%d RP" % int(rw.rp))
		if rw.get("spark"): r.append("%s Spark" % Career.SPARK_N[rw.spark])
		if on: info.add_child(SK.small("Unlocked %s" % Career.dateStr(int(on) - 1), SK.GD))
		elif not r.is_empty(): info.add_child(SK.small("Reward: " + ", ".join(r), SK.HL))

func _fill_news(b: VBoxContainer) -> void:
	if Career.G.log.is_empty():
		b.add_child(SK.small("Nothing yet.", SK.DIM))
	for l in Career.G.log:
		var v := UIKit.vbox(0)
		v.add_child(SK.small(Career.dateStr(int(l.d)), SK.BL, false))
		v.add_child(SK.small(l.t, Color.WHITE))
		b.add_child(v)
		var sep := ColorRect.new()
		sep.color = Color("#2c3b70")
		sep.custom_minimum_size = Vector2(0, 1)
		b.add_child(sep)
