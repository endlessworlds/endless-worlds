extends Node
class_name SurvivalSfx

# Tiny retro sound effects synthesized at startup (no audio files): square/saw/noise
# voices with pitch sweeps and decay, played through a small pool of players.

const RATE := 22050
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	#          name       wave      f0     f1     dur   vol
	_make("shoot",   "square", 1400.0, 700.0, 0.07, 0.25)
	_make("hit",     "noise",  0.0,    0.0,   0.05, 0.3)
	_make("kill",    "square", 500.0,  1100.0, 0.11, 0.3)
	_make("hurt",    "saw",    260.0,  110.0, 0.22, 0.45)
	_make("boom",    "noise",  0.0,    0.0,   0.4,  0.55)
	_make("boss",    "saw",    90.0,   55.0,  0.9,  0.5)
	_make("portal",  "square", 220.0,  660.0, 0.22, 0.15)
	_make("pickup",  "square", 880.0,  1320.0, 0.12, 0.3)
	_make("dash",    "noise",  0.0,    0.0,   0.12, 0.18)
	_make("upgrade", "arp",    523.0,  0.0,   0.36, 0.3)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		p.bus = &"SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)


func play(name: String, pitch_var := 0.08) -> void:
	if not _streams.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _make(name: String, wave: String, f0: float, f1: float, dur: float, vol: float) -> void:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var notes := [1.0, 1.26, 1.5, 2.0]   # major arpeggio for "upgrade"
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if wave == "arp":
			f = f0 * notes[mini(int(t * notes.size()), notes.size() - 1)]
		phase = fmod(phase + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"square", "arp":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = phase * 2.0 - 1.0 + 0.3 * sin(t * 60.0)   # growl wobble
			"noise":
				s = randf_range(-1.0, 1.0) * (1.0 - t * 0.5)
		var env := pow(1.0 - t, 2.0) * minf(1.0, t * 40.0)   # quick attack, smooth decay
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_streams[name] = w
