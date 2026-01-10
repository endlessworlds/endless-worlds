extends Control

@onready var score_label := $PlayerPanel/StatsVBox/ScoreLabel
@onready var high_score_label := $PlayerPanel/StatsVBox/HighScoreLabel
@onready var level_label := $PlayerPanel/StatsVBox/LevelLabel
@onready var start_button := $StartButton
@onready var topic_input: LineEdit = $TopicInput
@onready var joystick_ui := $JoyStickUI/VirtualJoystick

@onready var stats_button := $JoyStickUI/StatsButton
@onready var stats_popup := $JoyStickUI/StatsPopup
@onready var stats_text := $JoyStickUI/StatsPopup/VBoxContainer/StatsText
@onready var reset_button := $JoyStickUI/StatsPopup/VBoxContainer/ResetButton
@onready var close_button := $JoyStickUI/StatsPopup/VBoxContainer/CloseButton

var selected_topic: String = ""

func _ready():
	score_label.text = "⭐ Score: %d" % Global.score
	high_score_label.text = "🏆 High Score: %d" % Global.high_score
	level_label.text = "🧭 Level: %d" % Global.level

	stats_popup.visible = false

	stats_button.pressed.connect(_open_stats)
	reset_button.pressed.connect(_reset_stats)
	close_button.pressed.connect(_close_stats)

	start_button.pressed.connect(_on_start_pressed)
	joystick_ui.modulate.a = 0.3


func _open_stats():
	stats_text.text = Global.stats_to_string()
	stats_popup.visible = true


func _close_stats():
	stats_popup.visible = false


func _reset_stats():
	Global.reset_all_stats()
	stats_text.text = Global.stats_to_string()
	get_tree().reload_current_scene()


func _on_start_pressed():
	selected_topic = topic_input.text.strip_edges()
	if selected_topic.is_empty():
		selected_topic = "programming"

	Global.selected_topic = selected_topic
	get_tree().change_scene_to_file("res://map/map.tscn")
