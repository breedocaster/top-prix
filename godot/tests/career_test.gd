extends RefCounted
## Career port suite (Career / Tune / RaceFlow):
##   godot --headless --path godot -- --test=career_test
## Bot length and focus: env BOT_YEARS (default 3), BOT_FOCUS (default CR,BO), BOT_SEED (default 7);
## compare with the web bot:  cd web/test && node bot.js CR,BO 12
## Fixtures come from `node web/tools/career_fixtures.js`.

var r
var sig := {}
var asks := 0
var pending: Array = []

func ok(c: bool, m: String) -> void: r.ok(c, m)

func run(runner) -> void:
	r = runner
	U.seed(20261103)
	var t0 := Time.get_ticks_msec()
	for s in ["toast", "popup", "sfx", "round_due", "year_end", "game_end", "race_finished", "title_won", "workshop_up", "research_done", "vehicle_built", "staff_hired", "sponsor_signed", "day_passed"]:
		sig[s] = []
		Career.connect(s, _on_sig.bind(s))
	print("- t_new_game"); t_new_game()
	print("- t_build"); t_build()
	print("- t_ticks_and_staff"); t_ticks_and_staff()
	print("- t_race"); t_race()
	print("- t_formats"); t_formats()
	print("- t_series_year"); t_series_year()
	print("- t_research"); t_research()
	print("- t_sponsors"); t_sponsors()
	print("- t_save_roundtrip"); t_save_roundtrip()
	print("- t_web_save"); t_web_save()
	print("- t_tune_parity"); t_tune_parity()
	print("  suite time %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	t_bot()

func _on_sig(a = null, b = null, c = null, name := "") -> void:
	# signals carry 0..3 args; bind() appends the name last
	var args := [a, b, c]
	if name == "":
		for i in range(2, -1, -1):
			if args[i] is String and sig.has(args[i]):
				name = args[i]; args.resize(i); break
	if sig.has(name): sig[name].append(args)

func _clear() -> void:
	for k in sig: sig[k].clear()

func _rested() -> void:
	for s in Career.drivers(): s.energy = s.maxE

# ---------------------------------------------------------------- new game
func t_new_game() -> void:
	var G := Career.newGame("Test Racing", "#e8432f", "standard")
	var keys := ["v", "team", "day", "money", "rp", "fans", "ws", "staff", "vehicles", "jobs", "res", "unl", "partLv", "races", "series", "spons", "sponDone", "fac", "sparks",
		"st", "cand", "settings", "log", "nid", "yearWins", "lazy", "ended", "tut", "lastSave", "wxRain", "year", "tech", "ach"]
	ok(G.keys() == keys, "newGame G keys/order match the web: %s" % [G.keys()])
	ok(G.staff.size() == 3 and Career.drivers().size() == 1 and Career.mechs().size() == 2, "starting staff")
	ok(G.cand.size() == 5, "5 hiring candidates")
	ok(int(G.money) == 420000 and G.res.body.has("kei") and G.res.body.has("commuter") and G.res.layout.has("ff"), "starting money and research")
	ok(G.settings.mode == "standard" and int(G.st.tests) == 0, "settings/st extras")
	var d: Dictionary = Career.drivers()[0]
	ok(d.has("aff") and d.has("trait") and int(d.salary) % 1000 == 0, "driver fields")
	ok(Career.dateStr() == "Y1 Apr W1", "dateStr %s" % Career.dateStr())

# ---------------------------------------------------------------- staged build
func _answer(job: Dictionary) -> void:
	asks += 1
	var w: Dictionary = job.wait
	if w.k == "ph":
		var v := Career.veh(job.vid)
		var opts := Career.bOpts(v, w.ph)
		# pick the last affordable option to exercise non-crew paths
		for i in range(opts.size() - 1, -1, -1):
			if Career.bReq(opts[i], v).ok:
				ok(Career.bChoose(job.vid, i), "bChoose phase %s idx %d" % [w.ph, i]); return
		Career.bChoose(job.vid, "crew")
	else:
		ok(Career.bChoose(job.vid, 0) or Career.bChoose(job.vid, "crew"), "bChoose event %s" % w.ev)

func t_build() -> void:
	_clear()
	Career.build_ask.connect(_answer)
	var v := Career.startBuild("kei", "fr")
	ok(not v.is_empty() and v.status == "build", "startBuild")
	var j := Career.bJob(v.id)
	ok(j.pd.size() == 8 and j.wait != null and j.wait.k == "ph" and j.wait.ph == "design", "staged job waits on design")
	ok(not Career.startBuild("kei", "ff").is_empty(), "second bay")
	ok(Career.startBuild("kei", "ff").is_empty(), "garage/bays full -> {}")
	var days := 0
	while (v.status == "build" or Career.G.vehicles[1].status == "build") and days < 300:
		Career.tick(); days += 1
	Career.build_ask.disconnect(_answer)
	ok(v.status == "ready", "build finished in %d days" % days)
	ok(asks >= 16, "answered %d build prompts (8 phases x 2 builds + events)" % asks)
	ok(v.blog.size() >= 8 and v.base.spd > 0 and v.has("advB"), "build log %d entries, base %s" % [v.blog.size(), v.base])
	ok(sig.vehicle_built.size() == 2, "vehicle_built x2")
	var jb := Career.bJob(v.id)
	ok(jb.is_empty(), "build job removed")
	# crew-decided build (no listener): sell one and rebuild
	ok(Career.sell(Career.G.vehicles[1].id), "sell")
	Career.G.money += 100000
	var v2 := Career.startBuild("kei", "ff", null, {"type": "carb", "carb": "d2"})
	var n := 0
	while v2.status == "build" and n < 300:
		Career.tick(); n += 1
	ok(v2.status == "ready" and v2.bflags is Array, "crew-decided build done in %d days, flags %s" % [n, v2.bflags])
	print("  build: kei FR %d days, %d prompts, base %s, flags %s" % [days, asks, v.base, v.bflags])

# ---------------------------------------------------------------- ticks, staff
func t_ticks_and_staff() -> void:
	_clear()
	var G := Career.G
	var m0: float = G.money
	var d0 := int(G.day)
	while int(G.day) % 28 != 27: Career.tick()
	Career.tick()
	ok(G.has("lastMonth") and float(G.lastMonth.sal) > 0, "month end paid salaries %s" % [G.get("lastMonth")])
	ok(sig.day_passed.size() == int(G.day) - d0, "day_passed per tick")
	G.money = 1e6
	ok(Career.fire(Career.drivers()[0].id) == false, "cannot fire the only driver")
	var c = null
	for x in G.cand:
		if x.role == "mec": c = x; break
	ok(c != null and not Career.hire(c.id), "mechanic limit in the shed")
	for x in G.cand:
		if x.role == "drv": c = x; break
	ok(Career.hire(c.id) and Career.drivers().size() == 2, "hire a second driver")
	ok(sig.staff_hired.size() == 1 and int(sig.staff_hired[0][0]) == int(c.id), "staff_hired")
	var mec: Dictionary = Career.mechs()[0]
	G.rp = 500
	var t0: float = mec.tech
	ok(Career.levelMech(mec.id) and float(mec.tech) > t0, "levelMech")
	var d: Dictionary = Career.drivers()[0]
	d.energy = 100
	var out = Career.train(d.id, "jog")
	ok(out is Dictionary and out.has("pedal"), "train jog %s" % [out])
	ok(Career.buildFac("dyno") and Career.facLv("dyno") == 1 and Career.facV("bSpd") == 6.0, "build facility")
	ok(Career.upgradeFac("dyno") and Career.facV("bSpd") == 12.0, "upgrade facility")
	var v: Dictionary = G.vehicles[0]
	ok(Career.startUpgrade(v.id, "spd"), "startUpgrade")
	var n := 0
	while v.status != "ready" and n < 60:
		Career.tick(); n += 1
	ok(int(v.up.spd) == 1 and float(v.upAdd.spd) > 0, "upgrade done in %d days (+%s)" % [n, v.upAdd.spd])
	G.res.part["tuneup"] = 1
	ok(Career.installPart(v.id, "tuneup") and v.parts.has("tuneup"), "installPart")

# ---------------------------------------------------------------- race
func t_race() -> void:
	_clear()
	_rested()
	var G := Career.G
	var v: Dictionary = G.vehicles[0]
	var s: Dictionary = Career.drivers()[0]
	var def := Data.race("c1a")
	var o := Career.oddsRatio(def, v, s)
	ok(o > 0.3 and o < 5, "oddsRatio %.3f %s" % [o, Career.oddsLabel(o)[0]])
	var rs := Career.makeRace(def, v.id, s.id, {"tactic": "normal"})
	var P := rs.player()
	ok(P.human and P.isPlayer and P.vid == v.id and P.team_key == "you", "player entry")
	ok(is_same(P.sparks, G.sparks), "player sparks are G.sparks")
	ok(P.sk.size() == rs.tr.secs.size() and P.sk[0].has("kd"), "sk from Tune.raceSecs")
	ok(rs.ents.size() == 6, "tier-1 field: 5 rivals + you")
	var sp0 := int(G.sparks.b)
	if sp0 > 0:
		for i in 5: rs.step(0.1)
		ok(Career.raceSpark(rs, "b") and int(G.sparks.b) == sp0 - 1, "race spark spends G.sparks")
	rs.run_instant()
	ok(rs.done, "race ran")
	var races0 := int(G.st.races)
	var out := Career.finishRace(rs)
	ok(int(G.st.races) == races0 + 1 and out.pos >= 1 and out.pos <= 6, "finishRace pos %d prize %s rp %s fans %s" % [out.pos, out.prize, out.rp, out.fans])
	ok(sig.race_finished.size() == 1 and sig.race_finished[0][0].race_id == "c1a" and sig.race_finished[0][0].field == 6, "race_finished info %s" % [sig.race_finished])
	ok(G.races.has("c1a") and int(G.races.c1a.n) == 1, "race record")
	ok(G.ach.has("race1"), "Green Flag achievement")
	ok(float(v.eng.cond) < 1.0, "engine wear applied (%.3f)" % float(v.eng.cond))
	# a quick string of races to check durability, repair jobs and wins
	var wins := 0
	for i in 6:
		_rested()
		v.status = "ready"; v.hp = 1; v.eng.cond = 1
		var rs2 := Career.makeRace(def, v.id, s.id)
		rs2.run_instant()
		var o2 := Career.finishRace(rs2)
		if o2.pos == 1 and not o2.dnf: wins += 1
	print("  c1a with the built kei: odds %.2f, %d/6 wins, fans %d, money %s" % [o, wins, int(G.fans), U.money(G.money)])
	G.jobs = G.jobs.filter(func(j): return j.type != "rep")
	v.status = "ready"; v.hp = 1

# ---------------------------------------------------------------- formats
func _drive(f: RaceFlow) -> Array:
	var panels := []
	var guard := 0
	while not f.done and guard < 12:
		f.rs.run_instant()
		var p := f.stage_done()
		panels.append(p)
		if p.can_retune: Tune.crewTune(Career.veh(f.vid), f.rs.cond, 0.97)
		if p.can_next: f.next()
		else: f.finish()
		guard += 1
	return panels

func t_formats() -> void:
	var G := Career.G
	G.money = 5e6
	G.ws = 2
	var v: Dictionary = G.vehicles[0]
	var s: Dictionary = Career.drivers()[0]
	var res := {}
	for spec in [["c2c", "heats"], ["r1a", "elim"], ["h1a", "best2"], ["o1b", "rally3"], ["c2a", "endur"], ["c1b", "feature"], ["p1a", "heats"]]:
		_rested(); v.status = "ready"; v.hp = 1; v.eng.cond = 1
		var f := Career.startRace(spec[0], v.id, s.id, "normal", null, spec[1])
		ok(f.fmt.id == spec[1], "%s format %s" % [spec[0], f.fmt.id])
		var panels := _drive(f)
		ok(f.done and f.result.has("pos"), "%s %s flow finished: pos %s" % [spec[0], spec[1], f.result.get("pos")])
		res[spec[1] + ":" + spec[0]] = [f.result.pos, panels.map(func(p): return p.stage)]
		if spec[1] == "heats":
			ok(panels[0].stage == "heat" and (panels.size() == 2 or panels[0].dead), "heats: heat then main %s" % [panels.map(func(p): return p.stage)])
			if panels.size() == 2: ok(f.rs.ents.size() == Career.RIVAL_N[int(Data.race(spec[0]).tier)] + 1, "main has the full field")
		if spec[1] == "elim":
			ok(panels[0].round_name == "Quarterfinal" and f.rs.forcePos >= 1 and f.rs.order_override.size() == 8, "drag ladder %s" % [panels.map(func(p): return [p.round_name, p.win, p.et])])
		if spec[1] == "best2":
			ok(panels.size() == 2 and panels[1].run == 2 and f.rs.order_override.size() == f.rivals.size() + 1, "hill best of 2")
		G.jobs = G.jobs.filter(func(j): return j.type != "rep")
	print("  formats: ", res)
	# test day
	_rested(); v.status = "ready"; v.hp = 1
	var rs := Career.startTest("t_hill", v.id, s.id)
	ok(rs.test and rs.tr.laps == 3 and rs.ents.size() == 1, "hill test session")
	rs.run_instant()
	var out := Career.finishTest(rs)
	ok(int(G.st.tests) == 1 and out.gains.size() >= 1 and v.eng.log != null and v.eng.log.src.begins_with("Test"), "finishTest logs %s" % [out])
	var rs2 := Career.startTest("t_tar", v.id, s.id, 10)
	ok(rs2.tr.laps == 10, "test laps are not stale from a cached track (%d)" % rs2.tr.laps)
	G.jobs = G.jobs.filter(func(j): return j.type != "rep")
	v.status = "ready"; v.hp = 1
	G.ws = 1

# ---------------------------------------------------------------- series + year end
func _on_round(id: String) -> void: pending.append(id)

func t_series_year() -> void:
	_clear()
	var G := Career.G
	Career.round_due.connect(_on_round)
	var v: Dictionary = G.vehicles[0]
	var s: Dictionary = Career.drivers()[0]
	for k in ["spd", "acc", "hnd", "dur"]: v.upAdd[k] = float(v.upAdd[k]) + 160   # a ringer, so the title is won
	G.races["c1a"] = {"best": 1, "n": 1, "w": 1}
	G.races["c1b"] = {"best": 1, "n": 1, "w": 1}
	G.money = 1e6
	ok(Career.seriesState("s1c").ok, "s1c open: %s" % [Career.seriesState("s1c")])
	ok(Career.enterSeries("s1c"), "enterSeries")
	var a: Dictionary = G.series.s1c.act
	ok(a.rivals.size() == 7 and a.pts.size() == 8 and int(a.next) == int(G.day) + 7, "series act shape")
	var rounds := 0
	var guard := 0
	while G.series.s1c.get("act") != null and guard < 200:
		Career.tick(); guard += 1
		while not pending.is_empty():
			var id: String = pending.pop_front()
			var rid: String = Data.D.SER[id].rounds[int(G.series[id].act.round)]
			_rested(); v.status = "ready"; v.hp = 1; v.eng.cond = 1
			var f := Career.startRace(rid, v.id, s.id, "normal", id)
			ok(f.series_id == id and f.fmt.id == Career.seriesFormat(Data.race(rid)).id, "series round uses the series format")
			_drive(f)
			rounds += 1
	Career.round_due.disconnect(_on_round)
	ok(rounds == 5 and G.series.s1c.get("act") == null and G.series.s1c.has("lastEnd"), "5 rounds then endSeries (%d)" % rounds)
	ok(G.st.titles.has("s1c") and sig.title_won.size() == 1, "title won + title_won signal (best %s)" % G.series.s1c.best)
	ok(sig.popup.any(func(p): return p[0].kind == "series_end"), "series final popup")
	ok(Career.canUpgradeWS(), "workshop upgrade unlocked")
	G.money = 1e6
	ok(Career.upgradeWS() and int(G.ws) == 2 and sig.workshop_up.size() == 1 and int(sig.workshop_up[0][0]) == 2, "upgradeWS + workshop_up")
	for k in ["spd", "acc", "hnd", "dur"]: v.upAdd[k] = float(v.upAdd[k]) - 160
	# year end
	while int(G.day) % 336 != 0: Career.tick()
	ok(sig.year_end.size() == 1 and int(sig.year_end[0][0].y) == 1 and G.yearWins.is_empty(), "year_end summary %s" % [sig.year_end[0][0] if sig.year_end.size() else null])
	ok(Career.year() == 2, "year 2")

# ---------------------------------------------------------------- research
func t_research() -> void:
	_clear()
	var G := Career.G
	G.rp = 1000
	ok(not Career.techAvail("efi").ok, "efi needs wideband")
	ok(Career.researchTech("wideband") and Tune.has("wideband"), "researchTech")
	ok(Career.techAvail("efi").ok and Career.researchTech("efi"), "efi")
	ok(Career.research("body", "sedan") and G.res.body.has("sedan"), "research body")
	ok(sig.research_done.size() == 3 and sig.research_done[0][0] == "wideband" and sig.research_done[2][0] == "body:sedan", "research_done %s" % [sig.research_done])
	ok(not Career.research("body", "gt"), "gt needs a bigger workshop: %s" % Career.bodyAvail("gt").why)
	# EFI swap job
	var v: Dictionary = G.vehicles[0]
	G.money = 2e6
	G.jobs = G.jobs.filter(func(j): return j.vid != v.id)
	v.status = "ready"
	ok(Career.startSwap(v.id, {"type": "efi"}), "startSwap EFI")
	var n := 0
	while v.status != "ready" and n < 30:
		Career.tick(); n += 1
	ok(v.eng.fuel == "efi" and v.eng.efi.ve.size() == 6 and G.ach.has("efi1"), "EFI fitted after %d days" % n)
	var cells := [[4, 4], [4, 5], [5, 5]]
	Career.adjCells(v.id, "ve", cells, "+5%")
	ok(int(G.st.cells) == 3, "cell edits counted")
	Career.buyCrewTune(v.id, Tune.SHOP())
	ok(v.eng.tunedFor == Tune.SHOP().name, "crew tuned EFI")
	v.eng.log = Tune.makeLog(v, Tune.SHOP(), "Dyno pull")
	ok(v.eng.log.cells != null and v.eng.log.wb == true, "wideband datalog with cells")

# ---------------------------------------------------------------- sponsors
func t_sponsors() -> void:
	_clear()
	var G := Career.G
	var offers := Career.sponsorOffers()
	ok(offers.size() > 0, "sponsor offers")
	var pick: Dictionary = offers[offers.size() - 1]
	for o in offers:
		if o.id == "cornoil": pick = o
	var m0: float = G.money
	ok(Career.signSponsor(pick.id) and sig.sponsor_signed.size() == 1, "signSponsor %s" % pick.id)
	ok(float(G.money) > m0, "signing bonus")
	var sp: Dictionary = G.spons[G.spons.size() - 1]
	ok(sp.base.st.races == G.st.races and not is_same(sp.base.st, G.st), "sponsor baseline is a copy")
	var gp := Career.goalProgress(sp)
	ok(gp.size() == 2 and float(gp[0]) == 0.0, "goal progress %s: %s" % [Career.goalText(D().SPON[pick.id].goal), gp])
	if pick.id == "cornoil":
		G.st.races += 3
		Career.checkSponsors()
		ok(sp.done and G.sponDone.has("cornoil") and G.unl.train.has("drag"), "cornoil goal done, drag training unlocked")
		ok(sig.popup.any(func(p): return p[0].kind == "sponsor_goal"), "sponsor goal popup")
		G.st.races -= 3
	var pay := Career.sponsorPay(sp)
	ok(pay > 0, "sponsorPay %s" % pay)

func D() -> Dictionary: return Data.D

# ---------------------------------------------------------------- save / load
func t_save_roundtrip() -> void:
	var s1 := Career.serialize()
	ok(Career.load_json(s1), "load own save")
	var s2 := Career.serialize()
	ok(s1 == s2, "serialize -> load -> serialize is identical (%d bytes)" % s1.length())
	var code := Career.exportCode()
	ok(code.begins_with("GG1:") and Career.load_json(code) and Career.serialize() == s1, "GG1 export code round-trips")
	var j = JSON.parse_string(s1)
	ok(j is Dictionary and j.v == 1.0, "save is plain JSON")
	ok(not Career.load_json("{\"v\":2}") and Career.serialize() == s1, "bad save rejected, state kept")

# ---------------------------------------------------------------- web save
func _deep_eq(a, b, path: String, errs: Array) -> void:
	if errs.size() > 8: return
	if (a is int or a is float) and (b is int or b is float):
		if absf(float(a) - float(b)) > 1e-9 * maxf(1.0, absf(float(b))): errs.append("%s: %s vs %s" % [path, a, b])
		return
	if typeof(a) != typeof(b): errs.append("%s: type %s vs %s" % [path, type_string(typeof(a)), type_string(typeof(b))]); return
	if a is Dictionary:
		if a.keys() != b.keys(): errs.append("%s: keys %s vs %s" % [path, a.keys(), b.keys()]); return
		for k in a: _deep_eq(a[k], b[k], path + "." + str(k), errs)
	elif a is Array:
		if a.size() != b.size(): errs.append("%s: size %d vs %d" % [path, a.size(), b.size()]); return
		for i in a.size(): _deep_eq(a[i], b[i], "%s[%d]" % [path, i], errs)
	elif a != b: errs.append("%s: %s vs %s" % [path, a, b])

func t_web_save() -> void:
	_clear()
	var txt := FileAccess.get_file_as_string("res://tests/fixtures/web_save.json")
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tune_parity.json"))
	var sm: Dictionary = fx.saveSummary
	ok(Career.load_json(txt), "load a Node-generated web save")
	var G := Career.G
	var errs := []
	_deep_eq(JSON.parse_string(Career.serialize()), JSON.parse_string(sm.webReload), "G", errs)
	ok(errs.is_empty(), "web save survives load -> serialize unchanged %s" % [errs])
	ok(Career.serialize() == sm.webReload, "byte-identical to the web's own E.load -> E.serialize")
	ok(int(G.day) == int(sm.day) and int(G.ws) == int(sm.ws) and int(G.st.wins) == int(sm.wins), "web save fields")
	ok(Career.score() == int(sm.score), "score %d vs web %d" % [Career.score(), int(sm.score)])
	ok(Career.availRaceIds() == sm.availRaceIds, "availRaceIds match the web")
	for id in sm.standings:
		var st := Career.standings(id)
		var same: bool = st.size() == sm.standings[id].size()
		for i in st.size():
			if same and (st[i][0] != sm.standings[id][i][0] or int(st[i][1]) != int(sm.standings[id][i][1])): same = false
		ok(same, "standings %s match the web" % id)
	var code := FileAccess.get_file_as_string("res://tests/fixtures/web_save_gg1.txt")
	ok(Career.load_json(code) and Career.serialize() == sm.webReload, "GG1 code of the web save loads the same career")
	# keep playing the web career for a couple of months
	G = Career.G
	Career.round_due.connect(_on_round)
	var raced := 0
	for d in 70:
		Career.tick()
		while not pending.is_empty():
			var id: String = pending.pop_front()
			var a: Dictionary = G.series[id].act
			var rid: String = Data.D.SER[id].rounds[int(a.round)]
			var bp := _best_pair(Data.race(rid))
			if bp.is_empty(): Career.seriesRoundSkip(id); continue
			var f := Career.startRace(rid, bp.v.id, bp.s.id, "normal", id)
			_drive(f)
			raced += 1
	Career.round_due.disconnect(_on_round)
	ok(not Career.bJob(int(sm.buildVid)).get("wait") or Career.veh(int(sm.buildVid)).status != "build", "pending build decision resolved by the crew")
	var after = JSON.parse_string(Career.serialize())
	var base_keys: Array = JSON.parse_string(txt).keys()
	ok(base_keys.all(func(k): return after.has(k)), "save keeps the web shape after play")
	print("  web save: %s, %d series rounds raced in 70 days, money %s, titles %s" % [Career.dateStr(), raced, U.money(G.money), G.st.titles])

# ---------------------------------------------------------------- Tune parity
var _n := 0
var _bad: Array = []
var _maxd := 0.0

func _cmp(got, want, path: String) -> void:
	if want is bool:
		_n += 1
		var gb: bool = got == true if got is bool else false
		if gb != want: _bad.append("%s: %s vs %s" % [path, got, want])
		return
	if want is float or want is int:
		_n += 1
		if not (got is float or got is int): _bad.append("%s: %s vs %s" % [path, got, want]); return
		var d := absf(float(got) - float(want))
		var rel := d / maxf(1.0, absf(float(want)))
		_maxd = maxf(_maxd, rel)
		if rel > 1e-9: _bad.append("%s: %.17g vs %.17g" % [path, float(got), float(want)])
		return
	if want == null:
		_n += 1
		if got != null and not (got is bool and got == false): _bad.append("%s: %s vs null" % [path, got])
		return
	if want is String:
		_n += 1
		if str(got) != want: _bad.append("%s: %s vs %s" % [path, got, want])
		return
	if want is Dictionary:
		if not (got is Dictionary): _bad.append("%s: missing" % path); return
		for k in want: _cmp(got.get(k), want[k], path + "." + str(k))
		return
	if want is Array:
		if not (got is Array) or got.size() != want.size(): _bad.append("%s: array %s vs %s" % [path, got, want]); return
		for i in want.size(): _cmp(got[i], want[i], "%s[%d]" % [path, i])

func t_tune_parity() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tune_parity.json"))
	var t0 := Time.get_ticks_msec()
	var n_odds := 0
	for g in fx.groups:
		ok(Career.load_json(Career.to_json(g.G)), "parity group %s loads" % g.name)
		var nb := _bad.size()
		for c in g.cases:
			var v := Career.veh(int(c.vid))
			var p := "%s/%s#%d" % [g.name, v.body, int(c.vid)]
			_cmp(Tune.need(v), c.need, p + ".need")
			_cmp(Tune.evalIdeal(v), c.ideal, p + ".ideal")
			if c.has("carbRich"): _cmp(Tune.carbRich(v), c.carbRich, p + ".carbRich")
			if c.has("trueVE"): _cmp(Tune.trueVE(v), c.trueVE, p + ".trueVE")
			var ev0 := {}
			for i in c.evals.size():
				var e: Dictionary = c.evals[i]
				var ev := Tune.eval(v, e.cond, e.rho)
				if i == 0: ev0 = ev
				_cmp(ev, e.ev, "%s.eval[%d]" % [p, i])
			var efi: bool = v.eng.fuel == "efi"
			_cmp(Tune.symptoms(ev0, efi), c.symptoms, p + ".symptoms")
			_cmp(Tune.plug(ev0.lam.wot), c.plug, p + ".plug")
			_cmp(Tune.zoneLabel(ev0.lam.mid, "mid"), c.zoneLabel, p + ".zoneLabel")
			for rc in c.races:
				var def := Data.race(rc.rid)
				_cmp(Tune.forecast(def), rc.cond, "%s.%s.forecast" % [p, rc.rid])
				var rsx := Tune.raceSecs(v, def, RaceSim.build_track(def, false), rc.cond)
				_cmp(rsx.secs, rc.secs, "%s.%s.secs" % [p, rc.rid])
				_cmp(rsx.foul, rc.foul, "%s.%s.foul" % [p, rc.rid])
				_cmp(rsx.seize, rc.seize, "%s.%s.seize" % [p, rc.rid])
				for od in rc.odds:
					_cmp(Career.oddsRatio(def, v, Career.staff(int(od.sid))), od.o, "%s.%s.odds" % [p, rc.rid]); n_odds += 1
			if c.has("crew"):
				var vc: Dictionary = v.duplicate(true)
				Tune.crewTune(vc, c.crew.cond, 1.0)
				_cmp(vc.eng, c.crew.eng, p + ".crewTune")
		for it in g.get("inits", []):
			var v2: Dictionary = it.v.duplicate(true)
			Tune.initEng(v2, it.sys)
			_cmp(v2.eng, it.eng, "%s/initEng#%d" % [g.name, int(it.v.id)])
		for row in g.get("forecast", []):
			for f in row: _cmp(Tune.forecast(Data.race(f.rid), int(f.day)), f.f, "%s/forecast %s d%d" % [g.name, f.rid, int(f.day)])
		print("  parity %-12s %2d vehicles  mismatches %d" % [g.name, g.cases.size(), _bad.size() - nb])
	for b in _bad.slice(0, 12): print("    ", b)
	ok(_bad.is_empty(), "Tune parity: %d mismatches" % _bad.size())
	print("  Tune parity: %d values (%d odds ratios) vs web, max rel diff %s, %d ms" % [_n, n_odds, String.num_scientific(_maxd), Time.get_ticks_msec() - t0])

# ---------------------------------------------------------------- headless bot (port of web/test/bot.js)
var FOCUS: Array = ["CR", "BO"]
var destroyed := 0

func _best_pair(race: Dictionary) -> Dictionary:
	var best := {}
	for v in Career.eligibleVehicles(race):
		for s in Career.eligibleDrivers():
			var o := Career.oddsRatio(race, v, s)
			if best.is_empty() or o > best.o: best = {"v": v, "s": s, "o": o}
	return best

func _run_race(rid: String, v: Dictionary, s: Dictionary, series = null) -> Dictionary:
	var G := Career.G
	var def := Data.race(rid)
	var opts := {}
	if v.eng.fuel != "none": Tune.crewTune(v, Tune.forecast(def), 0.97)
	if series != null:
		opts.series = series; opts.rivals = G.series[series].act.rivals
	var rs := Career.makeRace(def, v.id, s.id, opts)
	rs.run_instant()
	var out := Career.finishRace(rs)
	if rs.player().get("destroyed", false): destroyed += 1
	if series != null: Career.seriesRoundDone(series, rs)
	return out

func _cls_for(disc: String) -> String: return Data.D.DISC[disc].cls
func _terr_need(disc: String) -> String: return {"CR": "on", "BR": "on", "CO": "off", "BO": "off", "OP": "off"}[disc]
func _ssum(b: Dictionary) -> float: return float(b.s.spd) + float(b.s.acc) + float(b.s.hnd)

func _decide() -> void:
	var G := Career.G
	var DD := Data.D
	var W := Career.ws()
	if Career.canUpgradeWS() and float(G.money) > float(Career.wsNeed().cost) * 1.3: Career.upgradeWS()
	while G.spons.size() < int(W.spon):
		var o := Career.sponsorOffers()
		if o.is_empty(): break
		Career.signSponsor(o[0].id)
	for disc in FOCUS:
		var cls := _cls_for(disc); var tk := _terr_need(disc)
		var cands: Array = DD.BODIES.filter(func(b): return b.cls == cls and Career.bodyAvail(b.id).ok and not G.res.body.get(b.id))
		cands = U.sort_by(cands, func(b): return _ssum(b) * float(b.t[tk]), true)
		if not cands.is_empty() and float(G.rp) >= float(cands[0].rp): Career.research("body", cands[0].id)
	for l in DD.LAYOUTS:
		if Career.layoutAvail(l.id).ok and not G.res.layout.get(l.id) and float(G.rp) >= float(l.rp) + 30: Career.research("layout", l.id)
	for p in U.sort_by(DD.PARTS, func(p): return float(p.tier), true):
		if Career.partAvail(p.id).ok and not G.res.part.get(p.id) and float(G.rp) >= float(p.rp) + 40: Career.research("part", p.id)
	for m in Career.mechs():
		if int(m.lv) < 10 and float(G.rp) >= Career.mechLvCost(m) + 60: Career.levelMech(m.id)
	var drv := Career.drivers()
	for c in G.cand.duplicate():
		if c.role == "drv" and drv.size() < int(W.teams) + 1 and float(G.money) > float(c.salary) * 12: Career.hire(c.id)
		if c.role == "mec" and Career.mechs().size() < int(W.mech) and float(G.money) > float(c.salary) * 12: Career.hire(c.id)
	var wms := U.sort_by(Career.mechs(), func(x): return float(x.tech))
	var bcs := U.sort_by(G.cand.filter(func(c): return c.role == "mec"), func(x): return float(x.tech), true)
	if not wms.is_empty() and not bcs.is_empty() and float(bcs[0].tech) > float(wms[0].tech) * 1.6 and float(G.money) > float(bcs[0].salary) * 15:
		Career.fire(wms[0].id); Career.hire(bcs[0].id)
	for disc in FOCUS:
		var cls := _cls_for(disc); var tk := _terr_need(disc)
		var have: Array = G.vehicles.filter(func(v): return DD.BODY[v.body].cls == cls and float(DD.BODY[v.body].t[tk]) >= 95)
		var bodies := U.sort_by(DD.BODIES.filter(func(b): return b.cls == cls and G.res.body.get(b.id) and float(b.t[tk]) >= 95), func(b): return _ssum(b), true)
		if bodies.is_empty(): continue
		var b: Dictionary = bodies[0]
		var bh := U.sort_by(have.map(func(v): return DD.BODY[v.body]), func(x): return _ssum(x), true)
		if not bh.is_empty() and bh[0].id == b.id: continue
		if G.vehicles.size() >= int(W.veh):
			var old := U.sort_by(G.vehicles.filter(func(v): return v.status == "ready" and DD.BODY[v.body].cls == cls), func(x): return float(DD.BODY[x.body].cost))
			if not old.is_empty() and float(G.money) > Career.vehCost(b.id, "ff") * 2: Career.scrap(old[0].id)
			else: continue
		var ls := U.sort_by(DD.LAYOUTS.filter(func(l): return l.cls == cls and G.res.layout.get(l.id)),
			func(l): return float(l.m.get("spd", 0)) + float(l.m.get("acc", 0)) + float(l.m.get("hnd", 0)) + float(l.t.get(tk, 0)) * 1.2, true)
		for l in ls:
			if float(G.money) > Career.vehCost(b.id, l.id) * 1.4:
				Career.startBuild(b.id, l.id); break
	for tc in DD.TECH:
		if not Tune.has(tc.id) and Career.techAvail(tc.id).ok and float(G.rp) >= float(tc.rp) + 30: Career.researchTech(tc.id)
	for v in G.vehicles:
		if v.status == "ready" and v.eng.fuel != "none" and float(v.eng.cond) < 0.45 and float(G.money) > Tune.rebuildCost(v) * 2: Career.startRebuild(v.id)
	for v in G.vehicles.duplicate():
		if v.status != "ready": continue
		var k: String = U.sort_by(["spd", "acc", "hnd", "dur"], func(x): return float(v.up[x]))[0]
		if int(v.up[k]) < 5 and float(G.money) > Career.upCost(v, k) * 2.5:
			Career.startUpgrade(v.id, k); continue
		var cls: String = DD.BODY[v.body].cls
		var cats := {}
		for p in DD.PARTS:
			if G.res.part.get(p.id) and Career.partClsOk(p, cls):
				if not cats.has(p.cat) or float(p.tier) > float(cats[p.cat].tier): cats[p.cat] = p
		for cat in cats:
			var p: Dictionary = cats[cat]
			if v.parts.has(p.id): continue
			var cur = null
			for x in v.parts:
				if DD.PART[x].cat == cat: cur = x; break
			if cur != null and float(DD.PART[cur].tier) >= float(p.tier): continue
			if p.cat == "tir": continue
			if float(G.money) > Career.partCost(p.id) * 3: Career.installPart(v.id, p.id)
	for s in Career.drivers():
		var tb := U.sort_by(DD.TRAINING.filter(func(t): return Career.trainAvail(t.id) and float(t.cost) > 0 and t.g.has("pedal")), func(t): return float(t.cost), true)
		if float(s.energy) > 70 and not tb.is_empty() and float(G.money) > float(tb[0].cost) * 6: Career.train(s.id, tb[0].id)
	for f in ["dyno", "gearbench", "tunnel", "gym", "telemetry", "lounge", "fab", "media", "merch"]:
		if not Career.facAvail(f): continue
		var lv := Career.facLv(f)
		if lv == 0 and G.fac.filter(func(x): return x != null).size() < int(W.fac) and float(G.money) > float(DD.FAC[f].cost[0]) * 1000 * 4: Career.buildFac(f)
		elif lv > 0 and lv < 3 and float(G.money) > float(DD.FAC[f].cost[lv]) * 1000 * 5: Career.upgradeFac(f)
	Career.odds_cache = {}
	for S in DD.SERIES:
		if not Career.seriesState(S.id).ok: continue
		var bp := _best_pair(DD.RACE[S.rounds[0]])
		if not bp.is_empty() and bp.o >= 1.0 and float(G.money) > float(S.fee) * 2: Career.enterSeries(S.id)
	var options := []
	for rr in DD.RACES:
		if not Career.raceState(rr.id).ok: continue
		var bp := _best_pair(rr)
		if bp.is_empty() or float(bp.s.energy) < 45: continue
		options.append({"r": rr, "bp": bp, "score": (2 if bp.o >= 1.05 else (1 if bp.o >= 0.95 else 0)) * 1e6 + float(rr.prize) * minf(1.3, bp.o)})
	Career.odds_cache = null
	options = U.sort_by(options, func(x): return x.score, true)
	if not options.is_empty() and options[0].bp.o >= 0.85: _run_race(options[0].r.id, options[0].bp.v, options[0].bp.s)

func t_bot() -> void:
	var years := int(OS.get_environment("BOT_YEARS")) if OS.get_environment("BOT_YEARS") != "" else 3
	if OS.get_environment("BOT_FOCUS") != "": FOCUS = Array(OS.get_environment("BOT_FOCUS").split(","))
	U.seed(int(OS.get_environment("BOT_SEED")) if OS.get_environment("BOT_SEED") != "" else 7)
	if years <= 0: return
	var t0 := Time.get_ticks_msec()
	Career.newGame("Bot", Data.D.TEAM_COLORS[0])
	var G := Career.G
	Career.round_due.connect(_on_round)
	pending.clear()
	destroyed = 0
	var last_y := 1
	var last_titles := 0
	var lines := []
	var maxd := years * Career.DAYS_YEAR
	while int(G.day) < maxd:
		Career.tick()
		G = Career.G
		while not pending.is_empty():
			var id: String = pending.pop_front()
			var a: Dictionary = G.series[id].act
			var rid: String = Data.D.SER[id].rounds[int(a.round)]
			var bp := _best_pair(Data.race(rid))
			if not bp.is_empty(): _run_race(rid, bp.v, bp.s, id)
			else: Career.seriesRoundSkip(id)
		if int(G.day) % 4 == 0: _decide()
		if Career.year() != last_y:
			last_y = Career.year()
			var tiers := []
			for t in range(1, 6):
				tiers.append(Data.D.RACES.filter(func(x): return int(x.tier) == t and not x.excl and Career.best(x.id) == 1).size())
			var nt: Array = G.st.titles.slice(last_titles)
			last_titles = G.st.titles.size()
			var line := "Y%d: newTitles[%s] ws%d $%.2fM rp%d fans%d wins%d/%d tierWins%s veh:%s drvPed:%s tech%d destroyed%d" % [last_y - 1, ",".join(nt), int(G.ws), float(G.money) / 1e6,
				int(G.rp), int(G.fans), int(G.st.wins), int(G.st.races), str(tiers).replace(" ", ""), ",".join(G.vehicles.map(func(v): return "%sL%d" % [v.body, int(v.lv)])),
				"/".join(Career.drivers().map(func(d): return str(int(d.pedal)))), U.iround(Career.teamTech()), destroyed]
			lines.append(line)
			print("  bot ", line, "   (%.0fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Career.round_due.disconnect(_on_round)
	print("  bot score %d saveBytes %d  (%d years in %.0fs)" % [Career.score(), Career.serialize().length(), years, (Time.get_ticks_msec() - t0) / 1000.0])
	ok(int(G.st.races) > 40 * years, "bot raced (%d races)" % int(G.st.races))
	ok(G.st.titles.size() >= 1, "bot won a title")
	ok(int(G.ws) >= 2 or years < 2, "bot moved up a workshop")
