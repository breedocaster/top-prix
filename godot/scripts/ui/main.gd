extends Control
## Screen router: title (with attract-mode race), story / free career (CareerScreen), quick race,
## garage/import, profile, LAN lobby, race, results.

var body: Control
var career: CareerScreen
var _nt := {}               # new-team form: {kind, len, name, col, mode}
var race_view: RaceView
var last_quick := {}
var lobby_box: VBoxContainer
var hosts_box: VBoxContainer
var ip_edit: LineEdit
var status_lbl: Label
var race_pick_open := false

func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.hosts_changed.connect(_on_hosts_changed)
	Net.race_setup.connect(_on_race_setup)
	Net.snap.connect(_on_snap)
	Net.msgs.connect(_on_msgs)
	Net.results.connect(_on_results)
	Net.closed.connect(title_screen)
	Net.joined.connect(lobby_screen)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			var runner = load("res://tests/test_runner.gd").new()
			runner.main = self
			runner.test_name = a.substr(7)
			get_tree().root.add_child.call_deferred(runner)   # outside Main, which clears its children
			return
	title_screen()

func _on_lobby_changed(_s: Dictionary) -> void:
	if lobby_box: _fill_lobby()

func _on_hosts_changed(_l: Array) -> void:
	if hosts_box: _fill_hosts()

func _on_snap(s: Dictionary) -> void:
	if race_view: race_view.apply_snapshot(s)

func _on_msgs(a: Array) -> void:
	if race_view: race_view.add_msgs(a)

func _on_results(r: Dictionary) -> void:
	if race_view: race_view.show_results(r)

# ---------------- helpers ----------------
func _clear() -> VBoxContainer:
	if race_view:
		race_view.queue_free(); race_view = null
		Net.race_view = null
	career = null
	for c in get_children(): c.queue_free()
	lobby_box = null; hosts_box = null; status_lbl = null
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + k, 6)
	add_child(m)
	var v := UIKit.vbox(6)
	m.add_child(v)
	body = v
	return v

func _row(items: Array) -> HBoxContainer:
	var h := UIKit.hbox(4)
	for it in items:
		if it is Control:
			it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(it)
	return h

func _slot_line(s: Dictionary) -> String:
	var b: Dictionary = Data.body(s.veh.body)
	return "%s  [%s]" % [s.label, "Car" if b.cls == "car" else "Bike"]

# ---------------- title ----------------
func title_screen(note: String = "") -> void:
	Net.leave()
	var v := _clear()
	var demo := _attract()
	if demo: v.add_child(demo)
	v.add_child(UIKit.title("TOP PRIX"))
	v.add_child(UIKit.label("Motorsport team manager", UIKit.DIM))
	if note != "": v.add_child(UIKit.label(note, UIKit.ACCENT))
	var info := CareerScreen.save_info()
	if not info.is_empty():
		var cb := UIKit.btn("CONTINUE: " + CareerKit.asc(info.team), _continue, UIKit.OK)
		cb.set_meta("tid", "continue")
		v.add_child(cb)
		v.add_child(UIKit.label("%s | %s fans%s" % [info.date, U.num(info.fans), " | story mode" if info.story else ""], UIKit.DIM, true))
	var sb := UIKit.btn("STORY MODE", _story_pick, UIKit.ACCENT)
	sb.set_meta("tid", "story")
	var fb := UIKit.btn("FREE CAREER", new_team_screen.bind("free", ""))
	fb.set_meta("tid", "free")
	v.add_child(_row([sb, fb]))
	v.add_child(UIKit.btn("QUICK RACE", quick_screen))
	v.add_child(_row([UIKit.btn("CO-OP LAN", lan_screen.bind("coop"), UIKit.OK), UIKit.btn("VERSUS LAN", lan_screen.bind("versus"), UIKit.ACCENT)]))
	v.add_child(_row([UIKit.btn("GARAGE", garage_screen), UIKit.btn("PROFILE", profile_screen)]))
	v.add_child(UIKit.label("Machine: " + _slot_line(Game.slot()), Color("#c8d0e8"), true))

func _attract() -> Control:
	var races: Array = Data.D.RACES.filter(func(r): return r.style in ["circuit", "rally", "mx", "street", "speed"])
	if races.is_empty(): return null
	var def: Dictionary = races[randi() % races.size()]
	var rs := RaceSim.create(def, [], {"n_rivals": 6, "rain": false})
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(244, 150)
	holder.clip_contents = true
	var rv := RaceView.new()
	rv.attract = true
	rv.position = Vector2(-6, -40)
	holder.add_child(rv)
	rv.start_sim(rs, "local", -1)
	return holder

# ---------------- career ----------------
func _story_pick() -> void:
	_clear()
	var p := CampaignPicker.new()
	add_child(p)
	p.picked.connect(func(len_id: String): new_team_screen("story", len_id))
	p.cancelled.connect(title_screen.bind(""))

## New team: name, colour and difficulty (defaults from the profile), then START.
func new_team_screen(kind: String, len_id: String) -> void:
	if _nt.get("kind") != kind or _nt.get("len") != len_id:
		_nt = {"kind": kind, "len": len_id, "name": Game.player.team, "col": Game.player.col, "mode": Game.player.mode}
	var v := _clear()
	var story := kind == "story"
	v.add_child(UIKit.title("STORY MODE" if story else "FREE CAREER"))
	if story:
		var L: Dictionary = Story.lengths.get(len_id, {})
		v.add_child(UIKit.label("%s campaign: %d chapters, %s" % [str(L.get("n", len_id)), (L.get("chapters", []) as Array).size(), str(L.get("time", ""))], UIKit.GOLD, true))
	else:
		v.add_child(UIKit.label("Open-ended career: 15 seasons from a backyard shed to world titles. No story, all racing.", UIKit.DIM, true))
	v.add_child(UIKit.label("Team name"))
	var nm := LineEdit.new()
	nm.text = str(_nt.name)
	nm.max_length = 22
	nm.text_changed.connect(func(t: String): _nt.name = t)
	v.add_child(nm)
	v.add_child(UIKit.label("Team colour"))
	var sw := UIKit.hbox(2)
	for hex in Data.D.TEAM_COLORS:
		var b := UIKit.btn("*" if hex == _nt.col else " ", _nt_set.bind("col", hex), Color(hex))
		b.custom_minimum_size = Vector2(26, 24)
		sw.add_child(b)
	v.add_child(sw)
	v.add_child(UIKit.label("Difficulty"))
	var mh := UIKit.hbox(2)
	for m in ["easy", "standard", "sim"]:
		var mb := UIKit.btn(("*" if _nt.mode == m else "") + Data.D.MODES[m].n, _nt_set.bind("mode", m), UIKit.OK if _nt.mode == m else UIKit.BTN)
		mb.set_meta("tid", "mode_" + m)
		mh.add_child(mb)
	v.add_child(mh)
	v.add_child(UIKit.label(Data.D.MODES[_nt.mode].d, UIKit.DIM, true))
	var info := CareerScreen.save_info()
	if not info.is_empty():
		v.add_child(UIKit.label("Starting replaces your saved career (%s, %s)." % [CareerKit.asc(info.team), info.date], UIKit.ACCENT, true))
	var go := UIKit.btn("START YOUR TEAM!", _start_career, UIKit.OK)
	go.set_meta("tid", "start")
	v.add_child(go)
	v.add_child(UIKit.btn("BACK", _story_pick if story else title_screen.bind(""), UIKit.BTN_LO))

func _nt_set(k: String, val: String) -> void:
	_nt[k] = val
	new_team_screen(str(_nt.kind), str(_nt.len))

func _start_career() -> void:
	var name := str(_nt.get("name", "")).strip_edges()
	if name == "": name = "Top Prix Racing"
	Game.player.team = name
	Game.player.col = str(_nt.col)
	Game.player.mode = str(_nt.mode)
	Game.save_profile()
	Career.newGame(name, str(_nt.col), str(_nt.mode))
	if _nt.kind == "story": Story.start_campaign(str(_nt.len))
	_nt = {}
	CareerScreen.save_game()
	career_screen()

func _continue() -> void:
	if CareerScreen.load_game(): career_screen()
	else: title_screen("Couldn't read the saved career.")

func career_screen() -> void:
	Net.leave()
	_clear()
	career = CareerScreen.new()
	career.main = self
	career.quit_requested.connect(title_screen.bind(""))
	add_child(career)

# ---------------- quick race ----------------
func quick_screen() -> void:
	var v := _clear()
	v.add_child(UIKit.title("QUICK RACE"))
	var s := Game.slot()
	var cls := Game.cls_of(s)
	v.add_child(_row([UIKit.btn("<", _cycle.bind(-1, quick_screen)), UIKit.label(s.label, UIKit.GOLD), UIKit.btn(">", _cycle.bind(1, quick_screen))]))
	v.add_child(UIKit.label("Pick a race. Pace vs the field shown on the right.", UIKit.DIM, true))
	var list := UIKit.vbox(2)
	for r in Data.races_for(cls):
		var o := Game.odds(s, r, Game.player.mode)
		var c := Color("#9dffa8") if o >= 1.05 else (UIKit.GOLD if o >= 0.92 else Color("#ffb0a0"))
		var b := UIKit.btn("%3d%% T%d %s" % [int(round(o * 100)), int(r.tier), r.n], _quick_fmt.bind(r.id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", c)
		b.clip_text = true
		list.add_child(b)
	v.add_child(UIKit.scroll(list))
	v.add_child(UIKit.btn("BACK", title_screen, UIKit.BTN_LO))

func _cycle(d: int, back: Callable) -> void:
	Game.sel = posmod(Game.sel + d, Game.garage.size())
	Game.save_profile()
	back.call()

func _quick_fmt(race_id: String) -> void:
	var r := Data.race(race_id)
	var fmts := Data.formats_m1(race_id)
	if fmts.size() == 1:
		_quick_go(race_id, fmts[0].id); return
	var v := _clear()
	v.add_child(UIKit.title(r.n.to_upper()))
	var c := Data.cond(race_id)
	v.add_child(UIKit.label("%s  %s  %d m  %d C" % [Data.D.DISC[r.disc].n, r.style, int(c.alt), int(c.temp)], UIKit.DIM, true))
	for f in fmts:
		v.add_child(UIKit.btn(f.n, _quick_go.bind(race_id, f.id)))
	v.add_child(UIKit.btn("BACK", quick_screen, UIKit.BTN_LO))

func _quick_go(race_id: String, fmt_id: String) -> void:
	var def := Data.race(race_id)
	var fm: Dictionary = Data.formats_m1(race_id)[0]
	for f in Data.formats_m1(race_id):
		if f.id == fmt_id: fm = f
	last_quick = {"race": race_id, "fmt": fmt_id}
	var track := RaceSim.build_track(def, false, fm.laps if int(fm.laps) != int(def.laps) else null)
	var h := Game.make_entry(Game.race_slot(), track, 1, Game.player.team, "me", Game.player.col)
	var opts := {"fmt": fm, "mode": Game.player.mode}
	if def.style == "drag": opts.n_rivals = 1
	var rs := RaceSim.create(def, [h], opts)
	_open_race(func(rv): rv.start_sim(rs, "local", 1))

# ---------------- race / results ----------------
func _open_race(start: Callable) -> void:
	_clear()
	for c in get_children(): c.queue_free()
	var bg := ColorRect.new(); bg.color = UIKit.BG; bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	race_view = RaceView.new()
	add_child(race_view)
	race_view.finished.connect(results_screen)
	start.call(race_view)

func _on_race_setup(setup: Dictionary) -> void:
	_open_race(func(rv): rv.start_client(setup, Net.my_id()))

func results_screen(res: Dictionary) -> void:
	if res.get("left", false):
		title_screen("You left the session.")
		return
	var was_net := Net.role
	var v := _clear()
	var def := Data.race(res.race_id)
	v.add_child(UIKit.title("RESULTS"))
	v.add_child(UIKit.label(def.n, UIKit.DIM))
	var me := Net.my_id() if was_net != "off" else 1
	var list := UIKit.vbox(1)
	for r in res.res:
		var t: String = "DNF" if r.dnf else ("%.3fs" % r.et.et if res.get("drag", false) and r.et.size() > 0 else _fmt_t(r.finT))
		var line := "%2d %-14s %s" % [r.pos, (r.name.split(" ")[0] if r.human else r.team).substr(0, 14), t]
		var col := Color("#c8d0e8")
		if r.human: col = UIKit.GOLD if int(r.owner) == me else Color.WHITE
		var l := UIKit.label(line, col, true)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		list.add_child(l)
	v.add_child(UIKit.scroll(list))
	var mode: String = Net.lobby.get("mode", "solo") if was_net != "off" else "solo"
	if mode == "coop":
		var teams: Array = res.teams
		var rank := 1
		for tt in teams:
			if tt[0] == "coop": break
			rank += 1
		var pts := 0
		for tt in teams:
			if tt[0] == "coop": pts = tt[2]
		v.add_child(UIKit.label("TEAM: %d pts  -  %s of %d teams" % [pts, RaceSim.ordinal(rank), teams.size()], UIKit.OK if rank == 1 else UIKit.GOLD))
	elif mode == "versus":
		var best := {}
		for r in res.res:
			if r.human and not r.dnf:
				best = r; break
		if best.is_empty(): v.add_child(UIKit.label("No one finished!", UIKit.ACCENT))
		else: v.add_child(UIKit.label("%s WINS THE DUEL!" % best.name.split(" ")[0].to_upper(), UIKit.GOLD if int(best.owner) == me else UIKit.ACCENT))
	if was_net == "host":
		v.add_child(UIKit.btn("REMATCH", _host_start, UIKit.ACCENT))
		v.add_child(UIKit.btn("BACK TO LOBBY", func(): Net.set_lobby("race_id", Net.lobby.race_id); lobby_screen()))
	elif was_net == "client": v.add_child(UIKit.label("Waiting for host...", UIKit.DIM))
	else:
		v.add_child(UIKit.btn("RACE AGAIN", func(): _quick_go(last_quick.race, last_quick.fmt)))
		v.add_child(UIKit.btn("MENU", title_screen, UIKit.BTN_LO))
	if was_net == "client": v.add_child(UIKit.btn("LEAVE", title_screen, UIKit.BTN_LO))
	if was_net == "client":
		Net.lobby_changed.connect(_back_to_lobby_once, CONNECT_ONE_SHOT)

func _back_to_lobby_once(_s) -> void:
	if not race_view and Net.role == "client": lobby_screen()

func _fmt_t(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]

# ---------------- garage ----------------
func garage_screen() -> void:
	Game.refresh_story_slots()
	var v := _clear()
	v.add_child(UIKit.title("GARAGE"))
	var list := UIKit.vbox(2)
	for i in Game.garage.size():
		var s: Dictionary = Game.garage[i]
		var p := Prof.profile(s.veh, s.drv, s.get("ctx", {}))
		var txt := "%s%s  S%d A%d H%d" % ["> " if i == Game.sel else "", s.label, int(p.S), int(p.A), int(p.H)]
		var b := UIKit.btn(txt, func(): Game.sel = i; Game.save_profile(); garage_screen(), UIKit.BTN if s.src == "preset" else UIKit.OK)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		list.add_child(b)
	v.add_child(UIKit.scroll(list))
	v.add_child(UIKit.label("Bring your web career: in the web game open Save > Export, paste the GG1: code here.", UIKit.DIM, true))
	var code := LineEdit.new()
	code.placeholder_text = "GG1:..."
	v.add_child(code)
	status_lbl = UIKit.label("", UIKit.GOLD, true)
	v.add_child(_row([UIKit.btn("PASTE", func(): code.text = DisplayServer.clipboard_get()), UIKit.btn("IMPORT", _do_import.bind(code), UIKit.OK)]))
	v.add_child(status_lbl)
	v.add_child(UIKit.btn("BACK", title_screen, UIKit.BTN_LO))

func _do_import(code: LineEdit) -> void:
	var n := Game.import_web(code.text)
	if n < 0:
		status_lbl.text = "That code didn't decode."
		return
	garage_screen()
	status_lbl.text = "Imported %d machines." % n

# ---------------- profile ----------------
func profile_screen() -> void:
	var v := _clear()
	v.add_child(UIKit.title("PROFILE"))
	var nm := LineEdit.new(); nm.text = Game.player.name; nm.max_length = 18
	var tm := LineEdit.new(); tm.text = Game.player.team; tm.max_length = 20
	v.add_child(UIKit.label("Driver name")); v.add_child(nm)
	v.add_child(UIKit.label("Team name")); v.add_child(tm)
	v.add_child(UIKit.label("Team color"))
	var sw := UIKit.hbox(2)
	for hex in Data.D.TEAM_COLORS:
		var b := UIKit.btn("*" if hex == Game.player.col else " ", func(): Game.player.col = hex; Game.save_profile(); profile_screen(), Color(hex))
		b.custom_minimum_size = Vector2(26, 22)
		sw.add_child(b)
	v.add_child(sw)
	v.add_child(UIKit.label("Difficulty"))
	var mh := UIKit.hbox(2)
	for m in ["easy", "standard", "sim"]:
		mh.add_child(UIKit.btn(("*" if Game.player.mode == m else "") + Data.D.MODES[m].n, func(): Game.player.mode = m; Game.save_profile(); profile_screen(), UIKit.OK if Game.player.mode == m else UIKit.BTN))
	v.add_child(mh)
	v.add_child(UIKit.label(Data.D.MODES[Game.player.mode].d, UIKit.DIM, true))
	v.add_child(UIKit.btn("SAVE", _save_profile.bind(nm, tm), UIKit.OK))

func _save_profile(nm: LineEdit, tm: LineEdit) -> void:
	if nm.text.strip_edges() != "": Game.player.name = nm.text.strip_edges()
	if tm.text.strip_edges() != "": Game.player.team = tm.text.strip_edges()
	for s in Game.garage:
		if s.src == "preset": s.drv.name = Game.player.name
	Game.save_profile()
	title_screen()

# ---------------- LAN ----------------
func lan_screen(mode: String) -> void:
	var v := _clear()
	v.add_child(UIKit.title("CO-OP" if mode == "coop" else "VERSUS"))
	v.add_child(UIKit.label("Team vs the world: everyone races for one team, each phone runs its own driver." if mode == "coop" else "Head to head: circuit, drag strip or hillclimb, with or without the AI field.", UIKit.DIM, true))
	v.add_child(UIKit.btn("HOST A GAME", _host_game.bind(mode), UIKit.OK))
	v.add_child(UIKit.label("Games on this Wi-Fi:"))
	hosts_box = UIKit.vbox(2)
	v.add_child(UIKit.panel(hosts_box, Color("#0f1736")))
	Net.listen(true)
	_fill_hosts()
	ip_edit = LineEdit.new(); ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.20"
	v.add_child(_row([ip_edit, UIKit.btn("JOIN", func(): _join(ip_edit.text.strip_edges()))]))
	status_lbl = UIKit.label("", UIKit.ACCENT, true)
	v.add_child(status_lbl)
	v.add_child(UIKit.label("Your IP: " + Net.local_ip(), UIKit.DIM, true))
	v.add_child(UIKit.btn("BACK", func(): Net.listen(false); title_screen(), UIKit.BTN_LO))

func _host_game(mode: String) -> void:
	var err := Net.host(mode)
	if err != OK:
		status_lbl.text = "Couldn't open port %d (%s)." % [Net.PORT, error_string(err)]
		return
	lobby_screen()

func _fill_hosts() -> void:
	if not hosts_box: return
	for c in hosts_box.get_children(): c.queue_free()
	if Net.hosts.is_empty():
		hosts_box.add_child(UIKit.label("Searching...", UIKit.DIM, true))
	for h in Net.hosts.values():
		var b := UIKit.btn("%s - %s (%d)" % [h.name, h.mode.to_upper(), int(h.n)], _join.bind(h.ip))
		b.clip_text = true
		hosts_box.add_child(b)

func _join(ip: String) -> void:
	if ip == "": return
	Net.listen(false)
	var err := Net.join(ip)
	if err != OK and status_lbl: status_lbl.text = "Join failed: " + error_string(err)
	elif status_lbl: status_lbl.text = "Connecting to %s..." % ip

func lobby_screen() -> void:
	Game.refresh_story_slots()
	var v := _clear()
	var mode: String = Net.lobby.get("mode", "coop")
	v.add_child(UIKit.title(("CO-OP" if mode == "coop" else "VERSUS") + " LOBBY"))
	if Net.role == "host":
		v.add_child(UIKit.label("Hosting on %s" % Net.local_ip(), UIKit.DIM, true))
	lobby_box = UIKit.vbox(4)
	v.add_child(UIKit.scroll(lobby_box))
	_fill_lobby()
	v.add_child(UIKit.btn("LEAVE", title_screen, UIKit.BTN_LO))

func _fill_lobby() -> void:
	if not lobby_box or race_view: return
	for c in lobby_box.get_children(): c.queue_free()
	var L := Net.lobby
	if L.is_empty(): return
	var coop: bool = L.mode == "coop"
	if coop: lobby_box.add_child(UIKit.label("Team: " + L.team, Color(L.col)))
	for id in L.players:
		var p: Dictionary = L.players[id]
		var who := "%s%s" % [p.name, " (you)" if int(id) == Net.my_id() else ""]
		var l := UIKit.label("%s - %s%s" % [who, p.label, "" if coop else "  [" + p.team + "]"], Color(p.col).lightened(0.3), true)
		lobby_box.add_child(l)
	lobby_box.add_child(_row([UIKit.btn("< MACHINE", func(): _cycle(-1, func(): Net.update_my_slot()), UIKit.BTN_LO), UIKit.btn("MACHINE >", func(): _cycle(1, func(): Net.update_my_slot()), UIKit.BTN_LO)]))
	if Net.role != "host":
		var rn: String = str(Data.race(L.race_id).get("n", "-")) if L.race_id != "" else "host is choosing..."
		lobby_box.add_child(UIKit.label("Race: " + str(rn), UIKit.GOLD))
		lobby_box.add_child(UIKit.label("Waiting for the host to start.", UIKit.DIM, true))
		return
	if not coop:
		var dh := UIKit.hbox(2)
		for d in ["circuit", "drag", "hill"]:
			dh.add_child(UIKit.btn(("*" if L.duel == d else "") + d.to_upper(), func(): Net.lobby.race_id = ""; Net.set_lobby("duel", d), UIKit.OK if L.duel == d else UIKit.BTN))
		lobby_box.add_child(dh)
		if L.duel == "circuit":
			lobby_box.add_child(UIKit.btn("AI FIELD: " + ("ON" if L.field else "OFF"), func(): Net.set_lobby("field", not L.field)))
	var ch := UIKit.hbox(2)
	for c in ["open", "T1", "T2", "T3", "T4"]:
		ch.add_child(UIKit.btn(("*" if L.get("cls", "open") == c else "") + c.to_upper(), _set_class.bind(c), UIKit.OK if L.get("cls", "open") == c else UIKit.BTN_LO))
	lobby_box.add_child(UIKit.label("Class: tier classes cap faster machines; OPEN = best build wins.", UIKit.DIM, true))
	lobby_box.add_child(ch)
	var races := Net.eligible_races()
	if L.race_id != "" and not races.any(func(x): return x.id == L.race_id): Net.lobby.race_id = ""
	if L.race_id == "" and races.size() > 0:
		Net.lobby.race_id = races[0].id
		Net.lobby.fmt_id = Data.formats_m1(races[0].id)[0].id
	var cur := Data.race(L.race_id)
	lobby_box.add_child(UIKit.btn("RACE: %s >" % cur.get("n", "-"), _race_picker))
	if L.race_id != "":
		var fh := UIKit.vbox(2)
		for f in Data.formats_m1(L.race_id):
			fh.add_child(UIKit.btn(("* " if f.id == L.fmt_id else "") + f.n, func(): Net.set_lobby("fmt_id", f.id), UIKit.OK if f.id == L.fmt_id else UIKit.BTN_LO))
		lobby_box.add_child(fh)
	var go := UIKit.btn("START RACE (%d players)" % L.players.size(), _host_start, UIKit.ACCENT)
	go.disabled = L.race_id == ""
	lobby_box.add_child(go)

func _set_class(c: String) -> void:
	Net.lobby.race_id = ""
	Net.set_lobby("cls", c)

func _race_picker() -> void:
	var v := _clear()
	v.add_child(UIKit.title("PICK RACE"))
	var list := UIKit.vbox(2)
	for r in Net.eligible_races():
		var b := UIKit.btn("T%d %s" % [int(r.tier), r.n], _pick_race.bind(r.id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		list.add_child(b)
	v.add_child(UIKit.scroll(list))
	v.add_child(UIKit.btn("BACK", lobby_screen, UIKit.BTN_LO))

func _pick_race(id: String) -> void:
	Net.lobby.race_id = id
	Net.set_lobby("fmt_id", Data.formats_m1(id)[0].id)
	lobby_screen()

func _host_start() -> void:
	var r := Net.host_start()
	if r.is_empty(): return
	_open_race(_start_host_view.bind(r.sim))

func _start_host_view(rv: RaceView, rs: RaceSim) -> void:
	Net.race_view = rv
	rv.start_sim(rs, "host", 1)
