class_name CareerSfx
extends Node
## The web build's little square-wave sound set (web/src/main.js SFX), synthesised once into
## AudioStreamWAVs and played on Career.sfx when G.settings.sound is on. Not a screen.

const RATE := 22050
## name -> [[freq, dur, wave, vol, delay], ...]
const SOUNDS := {
	"click": [[880, 0.04, "sq", 0.03, 0.0]],
	"good": [[660, 0.08, "sq", 0.05, 0.0], [990, 0.12, "sq", 0.05, 0.08]],
	"fanfare": [[523, 0.14, "sq", 0.05, 0.0], [659, 0.14, "sq", 0.05, 0.1], [784, 0.14, "sq", 0.05, 0.2], [1047, 0.14, "sq", 0.05, 0.3]],
	"crash": [[120, 0.3, "saw", 0.07, 0.0], [80, 0.4, "sq", 0.05, 0.05]],
	"bump": [[160, 0.08, "sq", 0.04, 0.0]],
	"spark": [[880, 0.1, "tri", 0.06, 0.0], [1175, 0.1, "tri", 0.06, 0.06], [1568, 0.1, "tri", 0.06, 0.12]],
	"start": [[440, 0.12, "sq", 0.05, 0.0], [440, 0.12, "sq", 0.05, 0.35], [440, 0.12, "sq", 0.05, 0.7], [880, 0.3, "sq", 0.05, 1.05]],
}

static var _bank := {}
var _players: Array = []
var _next := 0

func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		_players.append(p)

func play(name: String) -> void:
	var st = Career.G.get("settings", {})
	if st is Dictionary and not bool(st.get("sound", true)): return
	# rendered effects (tools/audio/sfx.py) and jingles take over when present
	if name == "fanfare": Audio.jingle("win"); return
	if ResourceLoader.exists(Audio.SFX_DIR + name + ".wav"): Audio.sfx(name); return
	if not SOUNDS.has(name): return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream(name)
	p.play()

static func stream(name: String) -> AudioStreamWAV:
	if _bank.has(name): return _bank[name]
	var tones: Array = SOUNDS[name]
	var total := 0.0
	for t in tones: total = maxf(total, float(t[1]) + float(t[4]) + 0.02)
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for t in tones:
		var f: float = t[0]
		var d: float = t[1]
		var vol: float = float(t[3]) * 6.0
		var s0 := int(float(t[4]) * RATE)
		var len := int(d * RATE)
		for i in len:
			if s0 + i >= n: break
			var ph := fmod(f * i / RATE, 1.0)
			var w := 0.0
			match str(t[2]):
				"saw": w = ph * 2.0 - 1.0
				"tri": w = 1.0 - 4.0 * absf(ph - 0.5)
				_: w = 1.0 if ph < 0.5 else -1.0
			var env := exp(-6.0 * float(i) / maxf(1.0, len))     # exponential ramp like the web gain curve
			buf[s0 + i] += w * vol * env
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n: pcm.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	_bank[name] = s
	return s
