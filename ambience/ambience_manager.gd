extends Node

@onready var ambience_player: AudioStreamPlayer = $"../AmbiencePlayer"

# Preload all ambience tracks for web export reliability
const AMBIENCE_TRACKS = [
	preload("res://assets/audio/ambience/birds-chirping.mp3"),
	preload("res://assets/audio/ambience/birds-rain.mp3"),
	preload("res://assets/audio/ambience/birds-singing.mp3")
]

func _ready():
	print("Ambience Manager: Loaded ", AMBIENCE_TRACKS.size(), " tracks")
	_play_random_ambience()

func _play_random_ambience():
	if AMBIENCE_TRACKS.size() == 0:
		push_warning("No ambience files found.")
		return
	
	var stream: AudioStream = AMBIENCE_TRACKS.pick_random()
	if stream == null:
		push_error("Failed to load ambience stream")
		return
	
	print("Playing ambience track")
	ambience_player.stream = stream
	ambience_player.volume_db = -10
	ambience_player.play()
	
	# ✅ ensure looping
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
