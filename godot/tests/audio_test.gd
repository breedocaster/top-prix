extends RefCounted
## Audio: engine banks load, voices map from vehicles, RPM model shifts through gears, music/SFX buses.
var r
func run(runner) -> void:
	r = runner
	var meta := EngineAudio._meta()
	r.ok(meta.get("voices", {}).size() >= 12, "engine voices in engines.json")
	var missing := 0
	for v in meta.voices:
		for ex in meta.voices[v].exhausts:
			for k in meta.voices[v].rpm:
				if not ResourceLoader.exists("res://audio/engine/%s_%s_%s.wav" % [v, ex, k]): missing += 1
	r.ok(missing == 0, "all engine loops import (%d missing)" % missing)
	for m in Audio.CONTEXTS.values():
		for t in m: r.ok(ResourceLoader.exists(Audio.MUSIC_DIR + t + ".ogg"), "music " + t)
	for b in ["Music", "SFX", "Engine"]: r.ok(AudioServer.get_bus_index(b) >= 0, "bus " + b)
	r.ok(EngineAudio.voice_for_vehicle(Prof.make_vehicle("kei", "ff")) == "i3car", "kei = I3")
	r.ok(EngineAudio.voice_for_vehicle(Prof.make_vehicle("mx250f", "stroke2")) == "single2", "2-stroke single")
	r.ok(EngineAudio.voice_for_vehicle(Prof.make_vehicle("sbk", "inline4")) == "i4bike", "I4 superbike")
	var v := Prof.make_vehicle("gt", "fr"); v.parts = ["straightpipe"]
	r.ok(EngineAudio.exhaust_for_vehicle(v) == "straight" and EngineAudio.voice_for_vehicle(v) == "v8", "GT straight-piped V8")
	# a quick race: engine slot 0 follows our car and climbs through the gears
	var def := Data.race("c2c")
	var s: Dictionary = Game.presets()[4]
	var trk := RaceSim.build_track(def, false)
	var rs := RaceSim.create(def, [Game.make_entry(s, trk, 1, "T", "me", "#e8432f")], {})
	r.main._open_race(func(rv): rv.start_sim(rs, "local", 1))
	var rv: RaceView = r.main.race_view
	rv.speed = 2.0
	var lo := 1e9; var hi := 0.0; var gears := {}; var thr_lo := 1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await r.get_tree().process_frame
		if rv._eng.is_empty() or rv._eng[0].idx < 0 or not rv.started: continue
		var rev: RevModel = rv._eng[0].rev
		lo = min(lo, rev.rpm); hi = max(hi, rev.rpm); gears[rev.gear] = true; thr_lo = min(thr_lo, rev.throttle)
	var node: EngineAudio = rv._eng[0].node
	print("  voice %s/%s rpm %d..%d gears %s min throttle %.2f" % [node.voice, node.exhaust, lo, hi, gears.keys(), thr_lo])
	r.ok(node.voice == "i4car", "hot hatch plays the I4")
	r.ok(hi > lo + 1500 and gears.size() >= 3, "revs and shifts through gears")
	r.ok(thr_lo < 0.3, "lifts / overrun happen")
	r.ok(Audio._ctx in ["race", "race_dirt", "rival"], "race music context (%s)" % Audio._ctx)
