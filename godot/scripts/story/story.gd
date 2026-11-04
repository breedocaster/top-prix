extends Node
## Story mode: "The Crownwell Cup". You inherit Augie Moss's backyard shed in Tinplate, Indiana and climb
## from the county fair to the World tier against the Crownwell dynasty.
##
## Content lives in data/story/*.json (characters, chapters per campaign length, scenes). State lives in
## Career.G.story so it rides along in the normal save. Objectives are checked against Career.G and the
## Career signals listed in PORTING.md; Story keeps working (in a local dict) when Career is absent.
##
## API: start_campaign(length), current_chapter(), objectives(), objective_text(), progress(),
##      pending_scene(), scene(id), scene_done(id), apply_choice(c), present(host), is_finished(),
##      rival_for(race_id), dynasty_races(), validate()
## Signals: scene_ready(scene_id), chapter_changed(n), story_finished(), objectives_changed(), rewarded(text)

signal scene_ready(scene_id: String)
signal chapter_changed(n: int)
signal story_finished()
signal objectives_changed()
signal rewarded(text: String)
signal presented_all()

const DIR := "res://data/story/"
const SCENE_FILES := ["scenes_main.json", "scenes_side.json", "scenes_end.json"]
const VERSION := 1
const ENDING := "ending"
const OBJ_TYPES := ["build", "veh_lv", "race_top", "win", "podium", "race_n", "beat_dynasty", "title", "title_disc",
	"workshop", "tech", "staff", "sponsor", "spon_goal", "fans", "money", "wc", "flag"]
## Career signal -> handler. Connected when a node named Career appears under /root.
const SIGNALS := {"race_finished": "_on_race_finished", "title_won": "_on_title_won", "workshop_up": "_on_workshop_up",
	"research_done": "_on_research_done", "vehicle_built": "_on_vehicle_built", "staff_hired": "_on_staff_hired",
	"sponsor_signed": "_on_sponsor_signed", "day_passed": "_on_day_passed", "refresh": "_on_refresh"}
## Starting staff get the story crew's names and looks (first driver, first mechanic).
const CREW := {"drv": {"name": "Rosie Alvarez", "hair": "#2b1a12", "skin": "#c68642"},
	"mec": {"name": "Dewey Brandt", "hair": "#f39c12", "skin": "#ffdbac"}}

var chars := {}
var meta := {}
var lengths := {}
var chapters := {}
var scenes := {}
var global_beats: Array = []
var free_dyn := {}
var radio := {}

var career: Node = null
## Pop scenes up automatically (on an overlay layer) as soon as they are queued.
var auto_present := false
## Push one-line WTPL radio toasts through Career.toast after races.
var radio_toasts := true

var _local := {}
var _layer: CanvasLayer = null
var _showing: Node = null
var _host: Node = null

func _ready() -> void:
	load_data()
	get_tree().node_added.connect(_on_node_added)
	_try_attach.call_deferred()

# ---------------- data ----------------
func load_data() -> void:
	var c := _json(DIR + "characters.json")
	chars = c.get("chars", {})
	meta = c.get("meta", {})
	var ch := _json(DIR + "chapters.json")
	lengths = ch.get("lengths", {})
	chapters = ch.get("chapters", {})
	global_beats = ch.get("global_beats", [])
	free_dyn = ch.get("free_dyn", {})
	radio = ch.get("radio", {})
	scenes = {}
	for f in SCENE_FILES: scenes.merge(_json(DIR + f), true)

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Story: missing " + path)
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(v) != TYPE_DICTIONARY:
		push_error("Story: bad JSON in " + path)
		return {}
	return v

# ---------------- career hookup ----------------
func _try_attach() -> void:
	var c := get_node_or_null("/root/Career")
	if c and c != career: attach(c)

func _on_node_added(n: Node) -> void:
	if n.name == "Career" and n.get_parent() == get_tree().root and n != career:
		attach.call_deferred(n)

func attach(c: Node) -> void:
	if c == null or not is_instance_valid(c): return
	if career and is_instance_valid(career) and career != c: detach()
	career = c
	for sig in SIGNALS:
		if c.has_signal(sig):
			var cb := Callable(self, SIGNALS[sig])
			if not c.is_connected(sig, cb): c.connect(sig, cb)
	if not c.tree_exiting.is_connected(_on_career_exit): c.tree_exiting.connect(_on_career_exit)
	_evaluate()

func detach() -> void:
	if career and is_instance_valid(career):
		for sig in SIGNALS:
			var cb := Callable(self, SIGNALS[sig])
			if career.has_signal(sig) and career.is_connected(sig, cb): career.disconnect(sig, cb)
		if career.tree_exiting.is_connected(_on_career_exit): career.tree_exiting.disconnect(_on_career_exit)
	career = null

func _on_career_exit() -> void:
	detach()

## The live save (Career.G), or {} when there is no career.
func _g() -> Dictionary:
	if career and is_instance_valid(career):
		var g = career.get("G")
		if typeof(g) == TYPE_DICTIONARY: return g
	return {}

## Story state: Career.G.story, or a local dict without a career.
func st() -> Dictionary:
	var g := _g()
	if g.is_empty(): return _local
	if typeof(g.get("story")) != TYPE_DICTIONARY: g["story"] = {}
	return g["story"]

func _day() -> int:
	return int(_g().get("day", 0))

# ---------------- campaign ----------------
func has_campaign() -> bool: return bool(st().get("on", false))
func is_active() -> bool: return has_campaign() and not bool(st().get("done", false))
func is_finished() -> bool: return bool(st().get("done", false))
func in_free_play() -> bool: return bool(st().get("free", false))
func flag(f: String) -> bool: return st().get("flags", {}).has(f)
func length() -> String: return str(st().get("len", ""))

## Start a campaign: "short", "medium" or "long". opts.crew (default true) renames the starting staff.
func start_campaign(len_id: String, opts: Dictionary = {}) -> bool:
	if not lengths.has(len_id): return false
	var s := {"v": VERSION, "on": true, "len": len_id, "chs": (lengths[len_id].chapters as Array).duplicate(),
		"i": -1, "prog": {}, "base": {}, "queue": [], "seen": {}, "fired": {}, "flags": {}, "notes": {},
		"done": false, "free": false, "day0": _day(), "hist": []}
	var g := _g()
	if g.is_empty(): _local = s
	else: g["story"] = s
	if bool(opts.get("crew", true)): _name_crew()
	_begin(0)
	_evaluate()
	return true

## Drop the campaign (the save keeps playing as a normal career).
func abandon() -> void:
	var g := _g()
	if g.is_empty(): _local = {}
	else: g.erase("story")
	objectives_changed.emit()

func _name_crew() -> void:
	var staff: Array = _g().get("staff", [])
	var named := {}
	for sm in staff:
		var role := str(sm.get("role", ""))
		if CREW.has(role) and not named.has(role):
			sm.merge(CREW[role], true)
			named[role] = true

func chapter_ids() -> Array: return st().get("chs", [])

## Chapter definition with the campaign length's overrides applied.
func chapter_for(id: String, len_id: String) -> Dictionary:
	var base: Dictionary = chapters.get(id, {})
	if base.is_empty(): return {}
	var ch := base.duplicate()
	ch["id"] = id
	var over: Dictionary = base.get("by_len", {}).get(len_id, {})
	ch.merge(over, true)
	return ch

func chapter_def(i: int = -1) -> Dictionary:
	var s := st()
	if i < 0: i = int(s.get("i", 0))
	var chs: Array = s.get("chs", [])
	if i < 0 or i >= chs.size(): return {}
	return chapter_for(str(chs[i]), str(s.get("len", "short")))

func current_chapter() -> Dictionary:
	if not has_campaign(): return {}
	var s := st()
	var ch := chapter_def()
	if ch.is_empty(): return {}
	return {"n": int(s.i) + 1, "of": chapter_ids().size(), "id": ch.id, "title": str(ch.title), "tier": int(ch.get("tier", 1)),
		"side": bool(ch.get("side", false)), "finale": bool(ch.get("finale", false)), "len": length(), "done": is_finished()}

func _begin(i: int) -> void:
	var s := st()
	s["i"] = i
	var ch := chapter_def(i)
	var n: int = (ch.get("obj", []) as Array).size()
	var done := []
	var cnt := []
	for k in n:
		done.append(false)
		cnt.append(0)
	s["prog"] = {"done": done, "c": cnt, "races": 0}
	s["base"] = _snapshot()
	s["day_ch"] = _day()
	_queue(str(ch.get("intro", "")))
	_fire("start", {})
	chapter_changed.emit(i + 1)
	objectives_changed.emit()

func _snapshot() -> Dictionary:
	var stt: Dictionary = _g().get("st", {})
	return {"wc": (stt.get("wc", {}) as Dictionary).duplicate(), "wins": int(stt.get("wins", 0)),
		"races": int(stt.get("races", 0)), "day": _day()}

func _prog() -> Dictionary:
	var s := st()
	if typeof(s.get("prog")) != TYPE_DICTIONARY: s["prog"] = {}
	var p: Dictionary = s["prog"]
	var n: int = (chapter_def().get("obj", []) as Array).size()
	for key in ["done", "c"]:
		if typeof(p.get(key)) != TYPE_ARRAY: p[key] = []
		var a: Array = p[key]
		while a.size() < n: a.append(false if key == "done" else 0)
	return p

func _done(k: int) -> bool:
	var d: Array = _prog().done
	return k < d.size() and bool(d[k])

func _counter(k: int) -> int:
	var c: Array = _prog().c
	return int(c[k]) if k < c.size() else 0

func _bump(k: int) -> void:
	var c: Array = _prog().c
	if k < c.size(): c[k] = int(c[k]) + 1

func _all_done() -> bool:
	var n: int = (chapter_def().get("obj", []) as Array).size()
	for k in n:
		if not _done(k): return false
	return true

## Re-check every objective; completes chapters (possibly several) when all are met.
func _evaluate() -> void:
	var guard := 0
	while is_active() and guard < 16:
		guard += 1
		var objs: Array = chapter_def().get("obj", [])
		var p := _prog()
		var changed := false
		for k in objs.size():
			if _done(k): continue
			var cn := _status(objs[k], k)
			if cn.x >= cn.y:
				p.done[k] = true
				changed = true
				_fire("obj", {"idx": k})
		if changed: objectives_changed.emit()
		if not _all_done(): break
		_complete()

func _complete() -> void:
	var s := st()
	var i := int(s.i)
	var ch := chapter_def()
	var txt := grant(ch.get("reward", {}))
	var outro := str(ch.get("outro", ""))
	var label := "Finale" if bool(ch.get("finale", false)) else "Chapter %d" % (i + 1)
	if outro != "": s.notes[outro] = "%s complete!%s" % [label, (" Reward: " + txt) if txt != "" else ""]
	(s.hist as Array).append({"id": ch.id, "day": _day()})
	_queue(outro)
	rewarded.emit(txt)
	_toast("%s complete: %s" % [label, str(ch.title)])
	if i + 1 < chapter_ids().size(): _begin(i + 1)
	else: _finish()

func _finish() -> void:
	var s := st()
	s["done"] = true
	s["day_end"] = _day()
	_queue(ENDING)
	objectives_changed.emit()
	story_finished.emit()

# ---------------- objectives ----------------
func _status(o: Dictionary, k: int) -> Vector2i:
	var g := _g()
	var need := int(o.get("n", 1))
	match str(o.get("t", "")):
		"build":
			var c := 0
			for v in g.get("vehicles", []):
				if str(v.get("status", "")) != "build" and _veh_ok(v, o): c += 1
			return Vector2i(c, need)
		"veh_lv":
			var best := 0
			for v in g.get("vehicles", []): best = maxi(best, int(v.get("lv", 1)))
			return Vector2i(best, int(o.get("lv", 1)))
		"race_top":
			if _counter(k) > 0: return Vector2i(1, 1)
			var races: Dictionary = g.get("races", {})
			for id in o.get("race", []):
				if int(races.get(id, {}).get("best", 99)) <= int(o.get("pos", 3)): return Vector2i(1, 1)
			return Vector2i(0, 1)
		"win", "podium", "race_n", "beat_dynasty":
			return Vector2i(_counter(k), need)
		"title":
			return Vector2i(_titles(o), need)
		"title_disc":
			var discs := {}
			for t in g.get("st", {}).get("titles", []):
				var ser: Dictionary = Data.D.SER.get(t, {})
				if not ser.is_empty(): discs[ser.disc] = true
			return Vector2i(discs.size(), need)
		"workshop":
			return Vector2i(int(g.get("ws", 1)), int(o.get("lv", 2)))
		"tech":
			var ids: Array = o.get("id", [])
			var have := 0
			for id in ids:
				if g.get("tech", {}).has(id): have += 1
			return Vector2i(have, ids.size())
		"staff":
			var c := 0
			for sm in g.get("staff", []):
				if not o.has("role") or str(sm.get("role", "")) == str(o.role): c += 1
			return Vector2i(c, need)
		"sponsor":
			if bool(o.get("new", false)): return Vector2i(_counter(k), need)
			var c := 0
			for sp in g.get("spons", []):
				if not o.has("id") or str(sp.get("id", "")) in o.id: c += 1
			return Vector2i(c, need)
		"spon_goal":
			return Vector2i((g.get("sponDone", {}) as Dictionary).size(), need)
		"fans":
			return Vector2i(int(g.get("fans", 0)), need)
		"money":
			return Vector2i(int(g.get("money", 0)), need)
		"wc":
			var key := str(o.get("key", ""))
			var now := int(g.get("st", {}).get("wc", {}).get(key, 0))
			var was := int(st().get("base", {}).get("wc", {}).get(key, 0))
			return Vector2i(now - was, need)
		"flag":
			return Vector2i(1 if flag(str(o.get("flag", ""))) else 0, 1)
	return Vector2i(0, maxi(1, need))

func _titles(o: Dictionary) -> int:
	var c := 0
	for t in _g().get("st", {}).get("titles", []):
		var ser: Dictionary = Data.D.SER.get(t, {})
		if ser.is_empty(): continue
		if o.has("series") and not str(t) in o.series: continue
		if o.has("tier") and not _num_in(o.tier, int(ser.tier)): continue
		if o.has("disc") and not _str_in(o.disc, str(ser.disc)): continue
		if o.has("cls") and str(ser.cls) != str(o.cls): continue
		c += 1
	return c

func _veh_ok(v: Dictionary, f: Dictionary) -> bool:
	var b: Dictionary = Data.body(str(v.get("body", "")))
	if f.has("cls") and str(b.get("cls", "")) != str(f.cls): return false
	if f.has("disc"):
		var kinds: Array = Data.D.KINDS.get(str(f.disc), [])
		var dcls := str(Data.D.DISC.get(str(f.disc), {}).get("cls", "any"))
		if not str(b.get("kind", "")) in kinds: return false
		if dcls != "any" and str(b.get("cls", "")) != dcls: return false
	if f.has("kind") and not _str_in(f.kind, str(b.get("kind", ""))): return false
	if f.has("body") and not _str_in(f.body, str(v.get("body", ""))): return false
	if bool(f.get("efi", false)) and str(v.get("eng", {}).get("fuel", "")) != "efi": return false
	return true

func _race_match(f: Dictionary, def: Dictionary, info: Dictionary) -> bool:
	if f.has("race") and not str(def.get("id", "")) in f.race: return false
	if f.has("disc") and not _str_in(f.disc, str(def.disc)): return false
	if f.has("tier") and not _num_in(f.tier, int(def.tier)): return false
	if f.has("tier_min") and int(def.tier) < int(f.tier_min): return false
	if f.has("style") and not _str_in(f.style, str(def.style)): return false
	if bool(f.get("hill", false)) and not (str(def.disc) == "HC" or str(def.style) == "hill"): return false
	if f.has("series") and not str(info.get("series_id", "")) in f.series: return false
	return true

static func _num_in(v, n: int) -> bool:
	if v is Array:
		for x in v:
			if int(x) == n: return true
		return false
	return int(v) == n

static func _str_in(v, s: String) -> bool:
	if v is Array: return s in v
	return str(v) == s

## Objective list for the HUD: [{txt, done, cur, need, detail}].
func objectives() -> Array:
	var out := []
	if not has_campaign(): return out
	var objs: Array = chapter_def().get("obj", [])
	for k in objs.size():
		var o: Dictionary = objs[k]
		var cn := _status(o, k)
		var d := _done(k) or is_finished()
		var need := 1 if str(o.t) in ["workshop", "flag"] else cn.y     # "move to the Town Garage 1/2" reads wrong
		out.append({"t": str(o.t), "txt": str(o.get("txt", o.t)), "done": d, "cur": need if d else mini(cn.x, need), "need": need, "detail": _detail(o)})
	return out

func _detail(o: Dictionary) -> String:
	var names := []
	match str(o.get("t", "")):
		"race_top", "beat_dynasty":
			for id in o.get("race", []): names.append(str(Data.race(id).get("n", id)))
		"tech":
			for id in o.get("id", []): names.append(str(Data.D.TECHM.get(id, {}).get("n", id)))
		"title":
			for id in o.get("series", []): names.append(str(Data.D.SER.get(id, {}).get("n", id)))
	return ", ".join(names)

func objective_text() -> String:
	if not has_campaign(): return ""
	if is_finished(): return "Story complete! Free play" if in_free_play() else "The Crownwell Cup is won!"
	for o in objectives():
		if not o.done: return str(o.txt) + _count_txt(int(o.cur), int(o.need))
	return "Chapter complete"

static func _count_txt(cur: int, need: int) -> String:
	if need <= 1: return ""
	if need < 1000: return " %d/%d" % [cur, need]
	return " %s/%s" % [_short(cur), _short(need)]

static func _short(n: int) -> String:
	if n >= 1000000: return "%.1fM" % (n / 1e6)
	if n >= 1000: return "%dK" % int(n / 1000)
	return str(n)

func progress() -> Dictionary:
	if not has_campaign(): return {}
	var s := st()
	var objs := objectives()
	var done := 0
	for o in objs:
		if o.done: done += 1
	var n := chapter_ids().size()
	var frac := float(done) / maxf(1.0, objs.size())
	return {"len": length(), "chapter": int(s.i) + 1, "chapters": n, "done": done, "total": objs.size(), "frac": frac,
		"campaign": 1.0 if is_finished() else (float(s.i) + frac) / maxf(1.0, n), "finished": is_finished(), "free": in_free_play()}

# ---------------- beats & scenes ----------------
func _fire(evt: String, ctx: Dictionary) -> void:
	if not is_active(): return
	var s := st()
	var ch := chapter_def()
	for pair in [[ch.get("beats", []), str(ch.get("id", ""))], [global_beats, "g"]]:
		for b in pair[0]:
			if str(b.get("on", "")) != evt: continue
			var key := "%s:%s" % [pair[1], b.scene]
			if s.fired.has(key) and not bool(b.get("repeat", false)): continue
			if not _beat_ok(b, evt, ctx): continue
			s.fired[key] = _day()
			_queue(str(b.scene))

func _beat_ok(b: Dictionary, evt: String, ctx: Dictionary) -> bool:
	if b.has("len") and not length() in b.len: return false
	if b.has("flag") and not flag(str(b.flag)): return false
	if b.has("noflag") and flag(str(b.noflag)): return false
	match evt:
		"race_finished":
			if not _race_match(b, ctx.def, ctx.info): return false
			if b.has("win") and bool(b.win) != bool(ctx.win): return false
			if b.has("podium") and bool(b.podium) != bool(ctx.pod): return false
			if b.has("dnf") and bool(b.dnf) != bool(ctx.dnf): return false
			if b.has("pos_max") and (bool(ctx.dnf) or int(ctx.pos) > int(b.pos_max)): return false
			if b.has("nth") and int(b.nth) != int(ctx.nth): return false
			if b.has("dyn") and bool(b.dyn) != bool(ctx.dyn): return false
			if b.has("beat") and bool(b.beat) != bool(ctx.beat): return false
		"vehicle_built":
			if not _veh_ok(ctx.get("veh", {}), b): return false
		"title_won":
			var ser: Dictionary = Data.D.SER.get(str(ctx.sid), {})
			if b.has("series") and not str(ctx.sid) in b.series: return false
			if b.has("tier") and not _num_in(b.tier, int(ser.get("tier", 0))): return false
			if b.has("disc") and not _str_in(b.disc, str(ser.get("disc", ""))): return false
			if b.has("cls") and str(ser.get("cls", "")) != str(b.cls): return false
		"research_done":
			if b.has("tech") and not str(ctx.tech) in b.tech: return false
		"workshop_up":
			if b.has("level") and int(ctx.level) < int(b.level): return false
		"sponsor_signed":
			if b.has("id") and not str(ctx.id) in b.id: return false
		"day":
			if b.has("after") and int(ctx.days) < int(b.after): return false
		"obj":
			if b.has("idx") and int(b.idx) != int(ctx.idx): return false
	return true

func _queue(id: String) -> void:
	if id == "" or not scenes.has(id): return
	var q: Array = st().get("queue", [])
	if id in q: return
	q.append(id)
	var fx: Dictionary = scenes[id].get("fx", {})
	if not fx.is_empty(): apply_fx(fx)
	scene_ready.emit(id)
	if auto_present: present.call_deferred()

## Next scene to play ("" if none). Scenes stay queued (and saved) until scene_done().
func pending_scene() -> String:
	var q: Array = st().get("queue", [])
	return str(q[0]) if q.size() > 0 else ""

func pending_scenes() -> Array:
	return (st().get("queue", []) as Array).duplicate()

func scene_done(id: String) -> void:
	var s := st()
	(s.get("queue", []) as Array).erase(id)
	if typeof(s.get("seen")) == TYPE_DICTIONARY: s.seen[id] = _day()
	if typeof(s.get("notes")) == TYPE_DICTIONARY: s.notes.erase(id)
	if id == ENDING and is_finished():
		s["free"] = true
		objectives_changed.emit()

## A scene ready to show: lines resolved (flags, tokens, speaker names/colours), chapter card, reward note.
func scene(id: String) -> Dictionary:
	var raw: Dictionary = scenes.get(id, {})
	if raw.is_empty(): return {}
	var out := {"id": id, "kind": str(raw.get("kind", "dialogue")), "lines": _lines(raw.get("lines", []))}
	if raw.has("epilogue"): out["epilogue"] = _lines(raw.epilogue)
	var card := _card_for(id)
	if not card.is_empty(): out["card"] = card
	var note := str(st().get("notes", {}).get(id, ""))
	if note != "": (out.lines as Array).append({"who": "", "expr": "", "text": note, "name": "", "col": "#ffd84a", "side": "ally", "note": true})
	return out

func _lines(arr: Array) -> Array:
	var out := []
	for l in arr:
		if l.has("if") and not flag(str(l["if"])): continue
		if l.has("ifnot") and flag(str(l.ifnot)): continue
		out.append(_line(l))
	return out

func _line(l: Dictionary) -> Dictionary:
	var who := str(l.get("who", ""))
	var c: Dictionary = chars.get(who, {})
	var r := {"who": who, "expr": str(l.get("expr", "neutral")), "text": fmt(str(l.get("text", ""))),
		"name": str(c.get("n", "")), "col": str(c.get("col", "#c8d8ff")), "side": str(c.get("side", "ally"))}
	if l.has("choices"):
		var cs := []
		for ch in l.choices:
			cs.append({"t": fmt(str(ch.get("t", ""))), "fx": ch.get("fx", {}), "set": str(ch.get("set", "")), "reply": _lines(ch.get("reply", []))})
		r["choices"] = cs
	return r

func _card_for(id: String) -> Dictionary:
	var chs := chapter_ids()
	for i in chs.size():
		var ch := chapter_for(str(chs[i]), length())
		if str(ch.get("intro", "")) == id:
			var top := "FINALE" if bool(ch.get("finale", false)) else "CHAPTER %d" % (i + 1)
			return {"top": top, "title": str(ch.title), "sub": "%s campaign  %d/%d" % [str(lengths.get(length(), {}).get("n", "")), i + 1, chs.size()]}
	return {}

func team_name() -> String:
	var g := _g()
	if g.has("team"): return str(g.team.get("name", "Team Tinplate"))
	var game := get_node_or_null("/root/Game")
	if game: return str(game.player.get("team", "Team Tinplate"))
	return "Team Tinplate"

func team_color() -> Color:
	var g := _g()
	if g.has("team"): return Color(str(g.team.get("color", "#e8432f")))
	var game := get_node_or_null("/root/Game")
	if game: return Color(str(game.player.get("col", "#e8432f")))
	return Color("#e8432f")

func fmt(t: String) -> String:
	if t.find("{") < 0: return t
	return t.format({"team": team_name(), "town": str(meta.get("town", "")), "radio": str(meta.get("radio", "")),
		"rival": str(meta.get("dynasty_team", "")), "star": str(chars.get("silas", {}).get("full", ""))})

## Choice picked in a dialogue: apply its effects and set its flag.
func apply_choice(c: Dictionary) -> void:
	apply_fx(c.get("fx", {}))
	if str(c.get("set", "")) != "": st().get("flags", {})[str(c.set)] = true
	objectives_changed.emit()

func apply_fx(fx: Dictionary) -> void:
	if fx.has("set"):
		if typeof(st().get("flags")) != TYPE_DICTIONARY: st()["flags"] = {}
		st().flags[str(fx.set)] = true
	var g := _g()
	if g.is_empty(): return
	for k in ["money", "rp", "fans"]:
		if fx.has(k): _add(g, k, fx[k])
	if fx.has("sparks"):
		if typeof(g.get("sparks")) != TYPE_DICTIONARY: g["sparks"] = {"b": 0, "s": 0, "g": 0}
		for t in fx.sparks: _add(g.sparks, t, fx.sparks[t])
	if fx.has("drop_sponsor"):
		var sp: Array = g.get("spons", [])
		for x in sp.duplicate():
			if str(x.get("id", "")) == str(fx.drop_sponsor): sp.erase(x)

## Add keeping the stored number type (the web save has ints; JSON-loaded saves have floats).
static func _add(d: Dictionary, k: String, amt) -> void:
	var old = d.get(k, 0)
	if typeof(old) == TYPE_INT: d[k] = int(old) + int(amt)
	else: d[k] = float(old) + float(amt)

## Write a chapter reward into Career.G. Returns a short summary ("$200K, 30 RP, ...").
func grant(rw: Dictionary) -> String:
	var g := _g()
	var parts := []
	if rw.has("set"): st().get("flags", {})[str(rw.set)] = true
	if g.is_empty() or rw.is_empty(): return ""
	if rw.has("money"):
		_add(g, "money", rw.money)
		parts.append(UIKit.money(float(rw.money)))
	if rw.has("rp"):
		_add(g, "rp", rw.rp)
		parts.append("%d RP" % int(rw.rp))
	if rw.has("fans"):
		_add(g, "fans", rw.fans)
		parts.append("%d fans" % int(rw.fans))
	if rw.has("sparks"):
		if typeof(g.get("sparks")) != TYPE_DICTIONARY: g["sparks"] = {"b": 0, "s": 0, "g": 0}
		for t in rw.sparks:
			_add(g.sparks, t, rw.sparks[t])
			parts.append("%d %s Spark" % [int(rw.sparks[t]), {"b": "Bronze", "s": "Silver", "g": "Gold"}.get(t, t)])
	for id in rw.get("tech", []):
		if typeof(g.get("tech")) != TYPE_DICTIONARY: g["tech"] = {}
		g.tech[id] = 1
		parts.append("Tech: " + str(Data.D.TECHM.get(id, {}).get("n", id)))
	var unl: Dictionary = rw.get("unl", {})
	var tables := {"train": "TRAIN", "fac": "FAC", "body": "BODY", "layout": "LAYOUT", "part": "PART"}
	for kind in unl:
		if typeof(g.get("unl")) != TYPE_DICTIONARY: g["unl"] = {}
		if typeof(g.unl.get(kind)) != TYPE_DICTIONARY: g.unl[kind] = {}
		for id in unl[kind]:
			g.unl[kind][id] = 1
			parts.append("%s unlocked" % str(Data.D.get(tables.get(kind, ""), {}).get(id, {}).get("n", id)))
	for sdef in rw.get("staff", []):
		var sm: Dictionary = (sdef as Dictionary).duplicate(true)
		sm["id"] = int(g.get("nid", 1))
		g["nid"] = int(g.get("nid", 1)) + 1
		sm["joined"] = _day()
		if typeof(g.get("staff")) != TYPE_ARRAY: g["staff"] = []
		(g.staff as Array).append(sm)
		parts.append("%s joins the crew" % str(sm.get("name", "")))
	return ", ".join(parts)

# ---------------- Career events ----------------
func _on_race_finished(info: Dictionary) -> void:
	var rid := str(info.get("race_id", ""))
	var def: Dictionary = Data.race(rid)
	if def.is_empty() or not has_campaign(): return
	var pos := int(info.get("pos", 99))
	var dnf := bool(info.get("dnf", false))
	var win := not dnf and pos == 1
	var pod := not dnf and pos <= 3
	var dyn := not rival_for(rid).is_empty()
	var beat := dyn and _beats_dynasty(info)
	if is_active():
		var p := _prog()
		p["races"] = int(p.get("races", 0)) + 1
		var objs: Array = chapter_def().get("obj", [])
		for k in objs.size():
			if _done(k): continue
			var o: Dictionary = objs[k]
			var hit := false
			match str(o.t):
				"win": hit = win and _race_match(o, def, info)
				"podium": hit = pod and _race_match(o, def, info)
				"race_n": hit = _race_match(o, def, info)
				"race_top": hit = not dnf and pos <= int(o.get("pos", 3)) and rid in o.race
				"beat_dynasty": hit = beat and rid in o.race
			if hit: _bump(k)
		_fire("race_finished", {"def": def, "info": info, "win": win, "pod": pod, "dnf": dnf, "pos": pos, "dyn": dyn, "beat": beat, "nth": int(p.races)})
	_radio(def, info, win, pod, dnf, dyn, beat)
	_evaluate()

## Beat the dynasty: info.dyn_pos (their finishing place, 0 = DNF) when the race layer provides it, else a win.
static func _beats_dynasty(info: Dictionary) -> bool:
	if bool(info.get("dnf", false)): return false
	var pos := int(info.get("pos", 99))
	if info.has("dyn_pos"):
		var dp := int(info.dyn_pos)
		return dp <= 0 or pos < dp
	return pos == 1

func _on_title_won(sid) -> void:
	_fire("title_won", {"sid": str(sid)})
	_evaluate()

func _on_workshop_up(level) -> void:
	_fire("workshop_up", {"level": int(level)})
	_evaluate()

func _on_research_done(tech_id) -> void:
	_fire("research_done", {"tech": str(tech_id)})
	_evaluate()

func _on_vehicle_built(vid) -> void:
	var veh := {}
	for v in _g().get("vehicles", []):
		if int(v.get("id", -1)) == int(vid): veh = v
	_fire("vehicle_built", {"veh": veh})
	_evaluate()

func _on_staff_hired(_sid) -> void:
	_fire("staff_hired", {})
	_evaluate()

func _on_sponsor_signed(id) -> void:
	if is_active():
		var objs: Array = chapter_def().get("obj", [])
		for k in objs.size():
			var o: Dictionary = objs[k]
			if str(o.t) == "sponsor" and bool(o.get("new", false)) and not _done(k):
				if not o.has("id") or str(id) in o.id: _bump(k)
	_fire("sponsor_signed", {"id": str(id)})
	_evaluate()

func _on_day_passed(_day_n) -> void:
	if not is_active(): return
	_fire("day", {"days": _day() - int(st().get("day_ch", 0))})
	_evaluate()

func _on_refresh() -> void:
	_evaluate()
	objectives_changed.emit()

func _toast(text: String) -> void:
	if career and is_instance_valid(career) and career.has_signal("toast"): career.emit_signal("toast", text)

func _radio(def: Dictionary, info: Dictionary, win: bool, pod: bool, dnf: bool, dyn: bool, beat: bool) -> void:
	if not radio_toasts: return
	var key := ""
	if dyn: key = "dyn_win" if beat else "dyn_lose"
	elif win: key = "win"
	elif pod: key = "podium"
	elif dnf: key = "dnf"
	var pool: Array = radio.get(key, [])
	if pool.is_empty(): return
	var rv := rival_for(str(def.id))
	var line := str(pool[(_day() + int(info.get("pos", 0))) % pool.size()])
	_toast(fmt(line.replace("{race}", str(def.n)).replace("{pos}", str(info.get("pos", ""))).replace("{drv}", str(rv.get("drv", "")))))

# ---------------- the dynasty ----------------
## Crownwell's entry for a race, in the RaceSim rival shape {team, col, drv, f, kind} plus {dynasty, char};
## {} when they are not on that grid. The race layer can append it to (or swap it into) the rival list,
## and report their finishing place back as race_finished info.dyn_pos.
func rival_for(race_id: String) -> Dictionary:
	if not has_campaign(): return {}
	var cfg: Dictionary = free_dyn
	var extra := []
	if is_active():
		var ch := chapter_def()
		cfg = ch.get("dyn", {})
		for o in ch.get("obj", []):
			if str(o.get("t", "")) == "beat_dynasty": extra.append_array(o.race)
	if cfg.is_empty(): return {}
	var def: Dictionary = Data.race(race_id)
	if def.is_empty(): return {}
	var hit: bool = race_id in extra or race_id in cfg.get("races", [])
	if not hit and cfg.has("tier"):
		hit = _num_in(cfg.tier, int(def.tier)) and race_id.substr(2) in cfg.get("slots", []) \
			and (not cfg.has("disc") or _str_in(cfg.disc, str(def.disc)))
	if not hit: return {}
	var who := str(cfg.get("drv", "silas"))
	var r := {"team": str(meta.get("dynasty_team", "Crownwell Racing")), "col": str(meta.get("dynasty_col", "#6a3fb5")),
		"drv": str(chars.get(who, {}).get("full", who)), "f": float(cfg.get("f", 1.12)), "dynasty": true, "char": who}
	var kind := _dyn_kind(def)
	if kind != "": r["kind"] = kind
	return r

static func _dyn_kind(def: Dictionary) -> String:
	var disc := str(def.disc)
	var kinds: Array = Data.D.KINDS.get(disc, [])
	if disc == "OP": kinds = ["hatch", "rally", "coupe", "gt", "super", "proto"]
	if kinds.is_empty(): return ""
	return str(kinds[mini(kinds.size() - 1, int(def.tier) + 1)])

func dynasty_races() -> Array:
	var out := []
	for r in Data.D.RACES:
		if not rival_for(str(r.id)).is_empty(): out.append(str(r.id))
	return out

# ---------------- presenting ----------------
## Play every pending scene, in order, on `host` (any Control) or on an overlay layer above everything.
## Returns the dialogue/ending node, or null when nothing is pending.
func present(host: Node = null) -> Node:
	if _showing and is_instance_valid(_showing): return _showing
	var id := pending_scene()
	if id == "":
		_close_layer()
		return null
	if host == null or not is_instance_valid(host):
		host = _host if _host and is_instance_valid(_host) else _overlay()
	_host = host
	var sc := scene(id)
	var node: Node
	if str(sc.get("kind", "")) == "ending":
		var es := EndingScene.new()
		host.add_child(es)
		es.setup_from_story(self)
		node = es
	else:
		node = DialogueBox.new()
		host.add_child(node)
	node.choice_made.connect(apply_choice)
	node.finished.connect(_presented.bind(id))
	node.play(sc)
	_showing = node
	return node

func _presented(_sid: String, id: String) -> void:
	scene_done(id)
	if _showing and is_instance_valid(_showing): _showing.queue_free()
	_showing = null
	if pending_scene() != "":
		present(_host)
	else:
		_close_layer()
		_host = null
		presented_all.emit()

func is_presenting() -> bool:
	return _showing != null and is_instance_valid(_showing)

func _overlay() -> Control:
	if _layer and is_instance_valid(_layer): return _layer.get_child(0)
	_layer = CanvasLayer.new()
	_layer.layer = 64
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	_layer.add_child(root)
	get_tree().root.add_child(_layer)
	return root

func _close_layer() -> void:
	if _layer and is_instance_valid(_layer): _layer.queue_free()
	_layer = null

# ---------------- validation (tests) ----------------
## Every problem found in the story data: missing scenes/characters/expressions, unknown game ids,
## lines that overflow a 3-row dialogue box, non-ASCII text.
func validate() -> Array:
	var bad := []
	for L in lengths:
		for cid in lengths[L].chapters:
			if not chapters.has(cid): bad.append("length %s: no chapter %s" % [L, cid])
	for cid in chapters:
		for L in lengths:
			var ch := chapter_for(cid, L)
			for key in ["intro", "outro"]:
				if not scenes.has(str(ch.get(key, ""))): bad.append("%s: %s scene missing" % [cid, key])
			for b in ch.get("beats", []):
				if not scenes.has(str(b.get("scene", ""))): bad.append("%s: beat scene %s missing" % [cid, b.get("scene")])
			for o in ch.get("obj", []): bad.append_array(_check_obj(cid, o))
			var dyn: Dictionary = ch.get("dyn", {})
			if not dyn.is_empty() and not chars.has(str(dyn.get("drv", ""))): bad.append("%s: dyn driver" % cid)
			for id in dyn.get("races", []):
				if Data.race(id).is_empty(): bad.append("%s: dyn race %s" % [cid, id])
			bad.append_array(_check_reward(cid, ch.get("reward", {})))
	for b in global_beats:
		if not scenes.has(str(b.scene)): bad.append("global beat scene %s missing" % b.scene)
	for sid in scenes:
		var sc: Dictionary = scenes[sid]
		for key in ["lines", "epilogue"]:
			for l in sc.get(key, []): bad.append_array(_check_line(sid, l))
	var seen := {}
	for e in bad: seen[e] = true
	return seen.keys()

func _check_obj(cid: String, o: Dictionary) -> Array:
	var bad := []
	var t := str(o.get("t", ""))
	if not t in OBJ_TYPES: bad.append("%s: objective type %s" % [cid, t])
	if str(o.get("txt", "")).length() > 30: bad.append("%s: objective text too long: %s" % [cid, o.txt])
	for id in o.get("race", []):
		if Data.race(id).is_empty(): bad.append("%s: race %s" % [cid, id])
	for id in o.get("series", []):
		if not Data.D.SER.has(id): bad.append("%s: series %s" % [cid, id])
	if t == "tech":
		for id in o.get("id", []):
			if not Data.D.TECHM.has(id): bad.append("%s: tech %s" % [cid, id])
	if o.has("disc") and not Data.D.DISC.has(str(o.disc)): bad.append("%s: disc %s" % [cid, o.disc])
	return bad

func _check_reward(cid: String, rw: Dictionary) -> Array:
	var bad := []
	for id in rw.get("tech", []):
		if not Data.D.TECHM.has(id): bad.append("%s: reward tech %s" % [cid, id])
	var tables := {"train": "TRAIN", "fac": "FAC", "body": "BODY", "layout": "LAYOUT", "part": "PART"}
	var unl: Dictionary = rw.get("unl", {})
	for kind in unl:
		for id in unl[kind]:
			if not Data.D.get(tables.get(kind, ""), {}).has(id): bad.append("%s: reward %s %s" % [cid, kind, id])
	return bad

func _check_line(sid: String, l: Dictionary) -> Array:
	var bad := []
	var who := str(l.get("who", ""))
	if who != "":
		if not chars.has(who): bad.append("%s: unknown speaker %s" % [sid, who])
		elif not str(l.get("expr", "neutral")) in chars[who].expr: bad.append("%s: %s has no %s face" % [sid, who, l.get("expr")])
		elif not Portraits.has_expr(who, str(l.get("expr", "neutral"))): bad.append("%s: no portrait %s_%s" % [sid, who, l.get("expr")])
	var text := str(l.get("text", "")).format({"team": "Top Prix Racing", "town": "Tinplate", "radio": "WTPL 1340", "rival": "Crownwell Racing", "star": "Silas Vane"})
	if DialogueBox.wrap_text(text).size() > DialogueBox.ROWS: bad.append("%s: line overflows the box: %s" % [sid, text])
	for i in text.length():
		if text.unicode_at(i) > 126: bad.append("%s: non-ASCII text: %s" % [sid, text]); break
	var cs: Array = l.get("choices", [])
	if cs.size() > 0 and (cs.size() < 2 or cs.size() > 3): bad.append("%s: choices must be 2-3" % sid)
	for c in cs:
		if str(c.get("t", "")).length() > DialogueBox.CHOICE_COLS: bad.append("%s: choice too long: %s" % [sid, c.t])
		for r in c.get("reply", []): bad.append_array(_check_line(sid, r))
	return bad
