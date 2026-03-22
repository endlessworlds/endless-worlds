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
var _journal_button: Button

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

	_create_journal_button()

	# Auto-open journal if flagged after game end
	if Global.show_journal_on_home:
		Global.show_journal_on_home = false
		await get_tree().process_frame
		_open_journal()


func _create_journal_button() -> void:
	_journal_button = Button.new()
	_journal_button.text = "📖 Journal"
	_journal_button.add_theme_font_override("font", load("res://Jersey10-Regular.ttf"))
	_journal_button.add_theme_font_size_override("font_size", 30)
	_journal_button.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	_journal_button.add_theme_color_override("font_hover_color", Color(1, 1, 0.6, 1))
	_journal_button.add_theme_color_override("font_pressed_color", Color(1, 0.6, 0.1, 1))

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.25, 0.12, 0.03, 0.75)
	sb_normal.corner_radius_top_left = 10
	sb_normal.corner_radius_top_right = 10
	sb_normal.corner_radius_bottom_left = 10
	sb_normal.corner_radius_bottom_right = 10
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(0.72, 0.40, 0.10, 0.9)
	_journal_button.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.35, 0.18, 0.05, 0.90)
	sb_hover.corner_radius_top_left = 10
	sb_hover.corner_radius_top_right = 10
	sb_hover.corner_radius_bottom_left = 10
	sb_hover.corner_radius_bottom_right = 10
	sb_hover.border_width_left = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = Color(1.0, 0.75, 0.2, 1.0)
	_journal_button.add_theme_stylebox_override("hover", sb_hover)
	_journal_button.add_theme_stylebox_override("pressed", sb_hover)

	_journal_button.focus_mode = Control.FOCUS_NONE
	# Place the button in the top-right corner of the screen inside the JoyStickUI CanvasLayer
	const BTN_W := 170.0
	const BTN_H := 40.0
	const MARGIN := 10.0
	var vp_w := get_viewport().get_visible_rect().size.x
	_journal_button.custom_minimum_size = Vector2(BTN_W, BTN_H)
	_journal_button.size = Vector2(BTN_W, BTN_H)
	_journal_button.position = Vector2(vp_w - BTN_W - MARGIN, MARGIN)
	_journal_button.z_index = 10
	_journal_button.pressed.connect(_open_journal)
	$JoyStickUI.add_child(_journal_button)


func _open_journal() -> void:
	var journal := LearningJournal.new()
	add_child(journal)
	journal.open()


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
