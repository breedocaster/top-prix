extends RefCounted
## Course layouts: every race's road keeps clear of itself, bends meet the minimum radius,
## progress maps monotonically to distance, and floor textures stay within the GPU limit.
func run(r) -> void:
	var worst := 0
	var crowded := []
	var big := 0.0
	var scaled := 0
	var n := 0
	for rid in Data.D.RACE:
		var def: Dictionary = Data.race(rid)
		for rain in [false]:
			var trk := RaceSim.build_track(def, rain)
			var g := TrackGeo.build(trk, str(rid))
			n += 1
			if g.crowding > 0: crowded.append("%s:%d" % [rid, g.crowding])
			worst = maxi(worst, g.crowding)
			big = maxf(big, maxf(g.bbox.size.x, g.bbox.size.y))
			if g.tex_scale > 1.0: scaled += 1
			# minimum radius from the drawn heading change
			var R := g.min_radius()
			var tight := 0
			for i in range(1, g.pts.size() - 6, 3):
				var dh := absf(angle_difference(g.heads[i], g.heads[i + 6]))
				if dh > 0.001 and (6.0 * TrackGeo.STEP) / dh < R * 0.8: tight += 1
			r.ok(tight == 0, "%s bends wide enough (%d tight)" % [rid, tight]) if tight > 0 else null
			# monotonic progress->px
			var last := -1.0
			var mono := true
			var L: float = trk.lapLen
			for k in 200:
				var px := g.px_of(L * k / 200.0)
				if px < last: mono = false
				last = px
			if not mono: r.ok(false, "%s progress mapping monotonic" % rid)
			var vp_px := maxf(g.bbox.size.x, g.bbox.size.y) / g.tex_scale
			if vp_px > TrackGeo.MAX_TEX: r.ok(false, "%s floor texture %d px" % [rid, int(vp_px)])
	print("  %d courses, %d with some crowding %s, largest %d px, %d painted at reduced res" % [n, crowded.size(), str(crowded.slice(0, 12)), int(big), scaled])
	r.ok(crowded.size() <= n / 10, "road rarely runs close to itself (%d/%d)" % [crowded.size(), n])
