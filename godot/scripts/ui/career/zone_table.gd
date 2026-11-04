extends Control
## Mixture by throttle zone (web UI.zoneTable): Idle, 1/8-1/4, 1/4-3/4, 3/4-Full and Snap (transition).
## num = wideband numbers (AFR + target) else the zone verdicts; KNOCK under any knocking zone.

const BG := preload("res://scripts/ui/career/bench_gfx.gd")
const KIT := preload("res://scripts/ui/career/sub_kit.gd")

var lam: Dictionary = {}
var kd: Dictionary = {}
var num := false

func _init(l: Dictionary = {}, k: Dictionary = {}, n := false) -> void:
	lam = l
	kd = k
	num = n
	custom_minimum_size = Vector2(0, 32)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func set_data(l: Dictionary, k: Dictionary) -> void:
	lam = l
	kd = k
	queue_redraw()

func _draw() -> void:
	if lam.is_empty(): return
	var zs := ["idle", "low", "mid", "wot", "trans"]
	var cw := floorf((size.x + 2) / 5.0)
	for k in 5:
		var z: String = zs[k]
		var tz := "low" if z == "trans" else z
		var x := k * cw
		var mid := x + floorf((cw - 2) / 2)
		draw_rect(Rect2(x, 0, cw - 2, 32), BG.C("#0a0f2a"))
		draw_rect(Rect2(x + 1, 1, cw - 4, 30), BG.C("#18224e"))
		draw_rect(Rect2(x + 1, 1, cw - 4, 8), BG.C("#2a3a80"))
		draw_rect(Rect2(x + 1, 1, cw - 4, 1), BG.C("#4a5ca8"))
		BG.MiniFont.draw(self, "SNAP" if z == "trans" else KIT.ascii(Data.D.ZONE_N[z]).to_upper(), Vector2(mid, 3), BG.C("#c8d4f0"), 1)
		var l: float = float(lam.get(z, 0.9))
		var zl := Tune.zoneLabel(l, tz)
		if num:
			BG.font8_draw(self, U.to_fixed(l * 14.7, 1), Vector2(mid, 10), BG.C(zl[1]), 1)
			BG.MiniFont.draw(self, ">" + U.to_fixed(float(Data.D.LAM[tz]) * 14.7, 1), Vector2(mid, 20), BG.C("#7d8aa8"), 1)
		else:
			var words := str(zl[0]).to_upper().split(" ")
			for wi in words.size(): BG.MiniFont.draw(self, words[wi], Vector2(mid, 11 + wi * 7), BG.C(zl[1]), 1)
		if float(kd.get(z, 0)) > 0.3: BG.MiniFont.draw(self, "KNOCK", Vector2(mid, 26), BG.C("#ff6060"), 1)
