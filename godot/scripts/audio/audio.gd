extends Node
## Music, SFX and engine buses. Music is picked by context and crossfaded; all tracks are original
## compositions rendered by tools/audio/music.py (no licensing strings attached).
## Volumes (0..1) live in Game.player: music_vol, sfx_vol, engine_vol.

const MUSIC_DIR := "res://audio/music/"
const SFX_DIR := "res://audio/sfx/"
const CONTEXTS := {
	"title": ["tinplate_boogie"],
	"garage": ["shed_sessions", "tinplate_boogie"],
	"race": ["full_throttle", "redline_shuffle"],
	"race_dirt": ["gravel_surf", "full_throttle"],
	"rival": ["crownwell_motors"],
	"credits": ["long_road_home"],
}

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer
var _ctx := ""
var _track := ""
var _fade_t := 0.0
var _jingle: AudioStreamPlayer
var _sfx: Array = []
var _sfx_i := 0
var _cache := {}

func _ready() -> void:
	for b in ["Music", "SFX", "Engine"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_a = _player("Music"); _b = _player("Music"); _cur = _a
	_jingle = _player("Music")
	for i in 4: _sfx.append(_player("SFX"))
	apply_volumes()
	_a.finished.connect(_next_track.bind(_a))
	_b.finished.connect(_next_track.bind(_b))

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func apply_volumes() -> void:
	var P: Dictionary = Game.player if Game else {}
	for pair in [["Music", "music_vol", 0.6], ["SFX", "sfx_vol", 0.8], ["Engine", "engine_vol", 0.8]]:
		var v := clampf(float(P.get(pair[1], pair[2])), 0.0, 1.0)
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(i, linear_to_db(max(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## Switch the music to a context (keeps playing if it's already that context).
func music(ctx: String) -> void:
	if ctx == _ctx: return
	_ctx = ctx
	var list: Array = CONTEXTS.get(ctx, [])
	if list.is_empty(): return
	var name: String = list[randi() % list.size()] if ctx.begins_with("race") else list[0]
	_play(name)

func _play(name: String) -> void:
	var st := _stream(MUSIC_DIR + name + ".ogg")
	if st == null: return
	_track = name
	var nxt := _b if _cur == _a else _a
	nxt.stream = st
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, 1.2)
	if _cur.playing: tw.tween_property(_cur, "volume_db", -40.0, 1.2)
	var old := _cur
	tw.chain().tween_callback(old.stop)
	_cur = nxt

func _next_track(p: AudioStreamPlayer) -> void:
	if p != _cur: return
	var list: Array = CONTEXTS.get(_ctx, [])
	if list.is_empty(): return
	var i := list.find(_track)
	_play(list[(i + 1) % list.size()])

func stop_music() -> void:
	_ctx = ""
	var tw := create_tween()
	tw.tween_property(_cur, "volume_db", -40.0, 0.8)
	tw.tween_callback(_cur.stop)

## Short stinger over ducked music: "win", "podium", "lose".
func jingle(name: String) -> void:
	var st := _stream(MUSIC_DIR + "jingle_" + name + ".ogg")
	if st == null: return
	_jingle.stream = st
	_jingle.play()
	var tw := create_tween()
	tw.tween_property(_cur, "volume_db", -18.0, 0.2)
	tw.tween_interval(st.get_length())
	tw.tween_property(_cur, "volume_db", 0.0, 1.0)

func sfx(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var st := _stream(SFX_DIR + name + ".wav")
	if st == null: return
	var p: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()
