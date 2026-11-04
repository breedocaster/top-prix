extends "res://scripts/ui/career/sub_screen.gd"
## Sponsors: active contracts (ad level, monthly pay, goal progress, reward) with End contract, and
## offers to sign (Career.sponsorOffers / signSponsor / cancelSponsor / goalProgress / goalText /
## rewardText). ctx: {router?, tab?: "active"|"offers"}

func _title() -> String: return "Sponsors"
func _tabs() -> Array: return [["active", "CONTRACTS"], ["offers", "OFFERS"]]

func _sig() -> String:
	var a := []
	for sp in Career.G.spons:
		var pr := Career.goalProgress(sp)
		a.append("%s:%d:%d:%s" % [sp.id, int(sp.ad), int(float(pr[0])), str(sp.done)])
	return "%s|%d|%d" % [",".join(a), int(float(Career.G.fans)), int(Career.G.ws)]

func _fill(b: VBoxContainer) -> void:
	var W := Career.ws()
	SK.note(b, "Sponsors %d/%d. Racing raises each sponsor's Ad level (driver Appeal + vehicle Ad appeal), which raises their pay. Finish a sponsor's goal to unlock new stuff!" % [Career.G.spons.size(), int(W.spon)])
	if tab == "active": _fill_active(b)
	else: _fill_offers(b)

func _stars(n: int) -> Control:
	var h := UIKit.hbox(0)
	h.size_flags_horizontal = Control.SIZE_SHRINK_END
	for i in 5: h.add_child(SK.icon_rect("star" if i < n else "star_off"))
	return h

func _fill_active(b: VBoxContainer) -> void:
	if Career.G.spons.is_empty():
		SK.note(b, "No sponsors yet. Check the Offers tab!", SK.HL)
		return
	for sp in Career.G.spons:
		var S: Dictionary = Data.D.SPON[sp.id]
		var v := SK.card(b, "done" if sp.done else "")
		var top := UIKit.hbox(4)
		top.add_child(SK.big(S.n))
		top.add_child(_stars(int(sp.ad)))
		v.add_child(top)
		v.add_child(SK.small("\"%s\"" % SK.ascii(S.bl), SK.DIM))
		v.add_child(SK.small("Pays %s/month  -  Ad Lv%d" % [SK.money(Career.sponsorPay(sp)), int(sp.ad)], SK.GD))
		if int(sp.ad) < 5:
			v.add_child(SK.bar_row("AD", float(sp.adx) / (60.0 * int(sp.ad)), "LV%d" % (int(sp.ad) + 1), Color("#7ac8ff")))
		if sp.done:
			var h := UIKit.hbox(4)
			h.add_child(SK.icon_rect("check"))
			h.add_child(SK.small("Goal complete", SK.GD))
			v.add_child(h)
		else:
			var pr := Career.goalProgress(sp)
			var c: float = float(pr[0]); var n: float = float(pr[1])
			v.add_child(SK.small("GOAL: " + Career.goalText(S.goal), Color.WHITE))
			v.add_child(SK.bar_row("", clampf(c / maxf(1.0, n), 0, 1), "%s/%s" % [U.num(clampf(c, 0, n)), U.num(n)], Color("#ffd84a")))
			v.add_child(SK.small("REWARD: " + Career.rewardText(S.rw), SK.HL))
		var br := UIKit.hbox(3)
		var sp_l := Control.new()
		sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(sp_l)
		br.add_child(SK.act(SK.sbtn("END CONTRACT", _ask_cancel.bind(sp.id), SK.RED), "cancel:" + str(sp.id)))
		v.add_child(br)

func _fill_offers(b: VBoxContainer) -> void:
	var W := Career.ws()
	var off := Career.sponsorOffers()
	var full: bool = Career.G.spons.size() >= int(W.spon)
	if full: SK.note(b, "All sponsor slots are full. End a contract or move to a bigger workshop.", SK.BD)
	if off.is_empty(): SK.note(b, "No new offers. Get more fans!", SK.HL)
	for S in off:
		var done := bool(Career.G.sponDone.get(S.id, false))
		var v := SK.card(b)
		var top := UIKit.hbox(4)
		top.add_child(SK.big(S.n))
		top.add_child(SK.act(SK.sbtn("SIGN", _sign.bind(S.id), SK.GREEN, 52, full), "sign:" + str(S.id)))
		v.add_child(top)
		v.add_child(SK.small("\"%s\"" % SK.ascii(S.bl), SK.DIM))
		var sign: float = float(S.sign) * (500.0 if done else 1000.0)
		v.add_child(SK.small("Signing %s  -  Base %s/mo" % [SK.money(sign), SK.money(float(S.mo) * 1000)], SK.GD))
		if done:
			v.add_child(SK.small("Goal already completed", SK.GD))
		else:
			v.add_child(SK.small("GOAL: " + Career.goalText(S.goal), Color.WHITE))
			v.add_child(SK.small("REWARD: " + Career.rewardText(S.rw), SK.HL))
	var nxt = null
	for S in Data.D.SPONSORS:
		if float(S.fans) > float(Career.G.fans): nxt = S; break
	if nxt != null:
		var l := SK.small("Next sponsor interest at %s fans" % U.num(float(nxt.fans)), SK.SUB)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(l)

func _sign(id: String) -> void:
	if Career.signSponsor(id): rebuild()

func _ask_cancel(id: String) -> void:
	confirm("End contract?", "End the deal with %s? Goal progress is lost." % SK.ascii(Data.D.SPON[id].n), "END IT", _cancel.bind(id))

func _cancel(id: String) -> void:
	Career.cancelSponsor(id)
	rebuild()
