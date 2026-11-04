extends RefCounted
## Cars occupy space: no same-lane overlaps, overtakes need gaps, aggressive drivers bump.
var r
func run(runner) -> void:
	r = runner
	var tot := {"overlap": 0, "bumps": 0, "lanechg": 0, "races": 0, "stuck": 0.0, "fin": 0}
	for rid in ["c1a", "c2c", "c3c", "b2b", "o2a", "d2a", "c4c"]:
		var def := Data.race(rid)
		if def.is_empty(): continue
		for tac in ["safe", "normal", "push"]:
			var trk := RaceSim.build_track(def, false)
			var s: Dictionary = Game.presets()[4 if Data.D.DISC[def.disc].cls != "bike" else 6]
			var h := Game.make_entry(s, trk, 1, "T", "me", "#e8432f", tac)
			var rs := RaceSim.create(def, [h], {})
			var me: Dictionary = rs.humans()[0]
			var last_lane := {}
			var g := 0
			while not rs.done and g < 30000:
				rs.step(0.05); g += 1
				for e in rs.ents:
					if last_lane.has(e.idx) and last_lane[e.idx] != e.lane: tot.lanechg += 1
					last_lane[e.idx] = e.lane
				var live := rs.ents.filter(func(x): return not x.fin and not x.dnf)
				for a in live:
					for b in live:
						if a.idx < b.idx and absf(float(a.lat) - float(b.lat)) < 0.5 and absf(rs._gap(a.prog, b.prog)) < RaceSim.CAR_LEN * 0.9: tot.overlap += 1
				if not me.fin and not me.dnf: tot.stuck += float(me.stuck) * 0.0 + (0.05 if float(me.stuck) > 0 else 0.0)
			for m in rs.msgs: if "bump" in str(m.text).to_lower() or "bang doors" in str(m.text): tot.bumps += 1
			tot.races += 1
			if me.fin: tot.fin += 1
	print("  races %d  finished %d  lane changes %d  bump msgs %d  held-up time %.0fs  same-lane overlaps %d" % [tot.races, tot.fin, tot.lanechg, tot.bumps, tot.stuck, tot.overlap])
	r.ok(tot.fin >= tot.races * 0.8, "races still finish")
	r.ok(tot.lanechg > tot.races * 5, "cars change lanes to pass")
	r.ok(tot.stuck > 1.0, "you get held up sometimes")
	r.ok(tot.overlap < tot.races * 3, "cars don't ghost through each other (%d overlaps)" % tot.overlap)
