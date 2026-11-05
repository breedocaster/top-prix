extends "res://scripts/ui/career/sub_screen.gd"
## How-to guide (GuideData): a topic list, then a topic page. Two reading levels:
## SIMPLE (kids and grown-ups, the default in Easy / Standard) and DETAILED (real tuning knowledge,
## the default in Sim); the chips at the top switch between them any time.
## ctx: {router?, topic?: open straight to a topic (BACK then closes), level?: "kid" | "sim"}

var topic := ""
var level := "kid"
var _direct := false          # opened on a topic from elsewhere (bench GUIDE): BACK closes

const PARA := Color("#e8ecf8")
const NOTE := Color("#9fe8ff")

func _title() -> String:
	var t := GuideData.topic(topic)
	return str(t.t) if not t.is_empty() else "How-to"

func _init_screen() -> void:
	level = str(ctx.get("level", "sim" if Tune.mode() == "sim" else "kid"))
	topic = str(ctx.get("topic", ""))
	_direct = topic != ""

func _sig() -> String: return topic + "|" + level

func _head_info() -> String:
	return "" if Career.G.is_empty() else super._head_info()

func back() -> void:
	if modal != null: close_modal(); return
	if topic != "" and not _direct:
		topic = ""
		head_title.text = SK.ascii(_title()).to_upper() if head_title else ""
		rebuild(true)
		return
	closed.emit()

func _fill(b: VBoxContainer) -> void:
	# reading level
	var lh := UIKit.hbox(3)
	for lv in [["kid", "SIMPLE"], ["sim", "DETAILED"]]:
		var c := SK.act(SK.chip(lv[1], level == lv[0], _set_level.bind(lv[0])), "level:" + lv[0])
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(c)
	b.add_child(lh)
	if topic == "":
		_list(b)
	else:
		_page(b, GuideData.topic(topic))

func _list(b: VBoxContainer) -> void:
	SK.note(b, "Simple: easy words for anyone. Detailed: the real tuning stuff." if level == "kid" else "Detailed: practical, real-world tuning. Simple: the same ideas in easy words.", SK.SUB)
	for t in GuideData.TOPICS:
		var row := UIKit.hbox(6)
		var ic := UIKit.icon_rect(str(t.ic), 1)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var col := UIKit.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(SK.big(t.t, Color.WHITE))
		col.add_child(SK.small(t.sum[level], SK.SUB))
		row.add_child(col)
		var card := CareerKit.card_btn(row, _open.bind(str(t.id)), "card", false, "topic:" + str(t.id))
		b.add_child(card)

func _page(b: VBoxContainer, t: Dictionary) -> void:
	if t.is_empty():
		SK.note(b, "Topic not found.", SK.SUB)
		return
	var v := SK.card(b, "", 4)
	for line in t[level]:
		var s := str(line)
		if s.begins_with("# "):
			v.add_child(SK.section(s.substr(2)))
		elif s.begins_with("- "):
			var h := UIKit.hbox(4)
			var dot := SK.small("*", SK.HL, false)
			dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			dot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			dot.custom_minimum_size = Vector2(8, 0)
			dot.autowrap_mode = TextServer.AUTOWRAP_OFF
			h.add_child(dot)
			var l := _para(s.substr(2))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			v.add_child(h)
		elif s.begins_with("> "):
			var tip := SK.card(v, "gold")
			tip.add_child(SK.small("TIP", SK.HL, false))
			tip.add_child(_para(s.substr(2)))
		elif s.begins_with("= "):
			var nt := SK.card(v, "note")
			nt.add_child(SK.small("IN TOP PRIX", NOTE, false))
			nt.add_child(SK.small(s.substr(2), NOTE))
		else:
			v.add_child(_para(s))
	if t.has("tool"):
		var tool: Dictionary = t.tool
		b.add_child(SK.act(SK.btn("OPEN THE VALVE BENCH", _open_tool.bind(tool), SK.GREEN), "tool"))
	# prev / next / all
	var ids: Array = GuideData.TOPICS.map(func(x): return str(x.id))
	var i := ids.find(str(t.id))
	var nav := UIKit.hbox(3)
	if i > 0: nav.add_child(SK.act(SK.btn("< PREV", _open.bind(ids[i - 1]), UIKit.BTN_LO, true), "prev"))
	if not _direct: nav.add_child(SK.act(SK.btn("ALL TOPICS", back, UIKit.BTN_LO, true), "all"))
	if i >= 0 and i < ids.size() - 1: nav.add_child(SK.act(SK.btn("NEXT >", _open.bind(ids[i + 1]), UIKit.BTN_LO, true), "next"))
	b.add_child(nav)

func _para(text: String) -> Label:
	var l := UIKit.label(SK.ascii(text), PARA)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_constant_override("line_spacing", -3)
	return l

## The valve & timing workbench: through the career router when there is one, otherwise (title screen)
## as an overlay on top of this screen.
func _open_tool(tool: Dictionary) -> void:
	var c := {"model": str(tool.get("model", "xj550")), "level": level}
	if router and router.has_method("open"):
		router.open(str(tool.screen), c)
		return
	var vs = load("res://scripts/ui/career/%s_screen.gd" % str(tool.screen)).new()
	add_child(vs)
	vs.setup(c)
	vs.closed.connect(func(): vs.queue_free())

func _open(id: String) -> void:
	topic = id
	if head_title: head_title.text = SK.ascii(_title()).to_upper()
	rebuild(true)

func _set_level(lv: String) -> void:
	level = lv
	rebuild()
