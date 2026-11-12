# Sound.gd (Autoload): the game's sound effects (assets/audio/sfx, made by tools/make_sfx.py),
# played on the "SFX" bus so the Effects slider in Settings controls them.
#   Sound.play("hint")
# Every button clicks by itself; a button can pick another sound with
# set_meta("sfx", "key") or stay quiet with set_meta("sfx", "") (set before it enters the tree).
extends Node

const NAMES := ["click", "key", "open", "close", "hint", "jump", "hurt", "torch", "whack", "chest",
	"wrong", "win", "lose", "confetti"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}   # name -> msec it last played, so one event can't stack the same sound


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # pause menus still click
	for n in NAMES:
		_streams[n] = load("res://assets/audio/sfx/%s.wav" % n)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	get_tree().node_added.connect(_on_node_added)


func play(sound: String, volume_db := 0.0, pitch_var := 0.0) -> void:
	var s: AudioStream = _streams.get(sound)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sound, -1000)) < 45:
		return
	_last[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("_sfx_hooked"):
		n.set_meta("_sfx_hooked", true)   # re-parented buttons enter the tree again
		var b := n as BaseButton
		b.pressed.connect(func(): play(str(b.get_meta("sfx", "click")), -2.0, 0.04))
