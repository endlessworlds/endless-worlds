extends Control

@onready var start_button := $StartButton
@onready var topic_input: LineEdit = $TopicInput
@onready var joystick_ui := $JoyStickUI/VirtualJoystick

@onready var stats_button := $JoyStickUI/StatsButton

var _stats_overlay: Panel

var selected_topic: String = ""
var _journal_button: Button
var _coding_button: Button
var _mp_button: Button
var _status_label: Label
const TOPIC_CHIPS := ["Python", "Space", "Biology", "History", "Math"]

func _ready():

	# Build the modern stats overlay (hidden by default)
	var StatsPopupScript = load("res://ui/stats_profile/stats_popup.gd")
	_stats_overlay = Panel.new()
	_stats_overlay.set_script(StatsPopupScript)
	_stats_overlay.visible = false
	$JoyStickUI.add_child(_stats_overlay)

	stats_button.pressed.connect(_open_stats)
	_stats_overlay.closed.connect(_close_stats)
	_stats_overlay.stats_reset.connect(_reset_stats)

	start_button.pressed.connect(_on_start_pressed)
	joystick_ui.modulate.a = 0.3

	_create_journal_button()
	_polish()
	if Net.active:  # came back from a room: drop the connection
		Net.leave()
	_dev_autoplay()

	# Auto-open journal if flagged after game end
	if Global.show_journal_on_home:
		Global.show_journal_on_home = false
		await get_tree().process_frame
		_open_journal()


func _create_journal_button() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_top = 10
	row.offset_right = -10
	$JoyStickUI.add_child(row)

	_mp_button = _top_button("🌐 Multiplayer", func(): Lobby.open(self, func(): return topic_input.text.strip_edges()))
	_coding_button = _top_button("💻 Coding", _on_coding_pressed)
	_journal_button = _top_button("📖 Journal", _open_journal)
	for b in [_mp_button, _coding_button, _journal_button]:
		row.add_child(b)


func _top_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	_style_top_button(b)
	b.pressed.connect(cb)
	return b


func _style_top_button(button: Button) -> void:
	button.add_theme_font_override("font", load("res://assets/fonts/Jersey10-Regular.ttf"))
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.6, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.6, 0.1, 1))

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
	sb_normal.content_margin_left = 14
	sb_normal.content_margin_right = 14
	button.add_theme_stylebox_override("normal", sb_normal)

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
	sb_hover.content_margin_left = 14
	sb_hover.content_margin_right = 14
	button.add_theme_stylebox_override("hover", sb_hover)
	button.add_theme_stylebox_override("pressed", sb_hover)
	button.focus_mode = Control.FOCUS_NONE


func _open_journal() -> void:
	var journal := LearningJournal.new()
	add_child(journal)
	journal.open()


func _open_stats():
	_stats_overlay.refresh()
	_stats_overlay.visible = true


func _close_stats():
	_stats_overlay.visible = false


func _reset_stats():
	Global.reset_all_stats()
	_stats_overlay.refresh()
	get_tree().reload_current_scene()


func _on_start_pressed():
	Global.is_coding_mode = false
	selected_topic = topic_input.text.strip_edges()
	if selected_topic.is_empty():
		selected_topic = "programming"

	Global.selected_topic = selected_topic
	get_tree().change_scene_to_file("res://map_components/map.tscn")


func _on_coding_pressed() -> void:
	Global.is_coding_mode = true
	Global.selected_topic = "coding"
	
	var file = FileAccess.open("res://data/coding_questions.json", FileAccess.READ)
	if file:
		var arr = JSON.parse_string(file.get_as_text())
		if typeof(arr) == TYPE_ARRAY and not arr.is_empty():
			Global.current_coding_question = arr[randi() % arr.size()]
	
	get_tree().change_scene_to_file("res://map_components/map.tscn")


# ------------------------------------------------------------------ layout + polish
# The scene's controls live in world space around the walking character, so they drift
# with window size. Move them into one screen-space layer: title on top, the character
# visible in the middle, controls centered below.
func _polish() -> void:
	var font := load("res://assets/fonts/Jersey10-Regular.ttf")
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)

	# Title, centered near the top, gently floating
	var title: Label = $TitleLabel
	var title_box := Control.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_box.offset_top = 96
	ui.add_child(title_box)
	title.reparent(title_box, false)
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(900, title.get_minimum_size().y)
	title.position = Vector2(-450, 0)
	var bob := create_tween().set_loops()
	bob.tween_property(title, "position:y", -8.0, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(title, "position:y", 0.0, 1.6).set_trans(Tween.TRANS_SINE)

	# Controls column, centered below the character
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 12)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = -300
	col.offset_right = 300
	col.offset_top = 36
	ui.add_child(col)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	col.add_child(chips)
	for t in TOPIC_CHIPS:
		var c := Button.new()
		c.text = t
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_override("font", font)
		c.add_theme_font_size_override("font_size", 22)
		for st in ["normal", "hover", "pressed"]:
			var cs := StyleBoxFlat.new()
			cs.set_corner_radius_all(12)
			cs.content_margin_left = 14
			cs.content_margin_right = 14
			cs.content_margin_top = 2
			cs.content_margin_bottom = 2
			cs.bg_color = Color(0.05, 0.08, 0.15, 0.78) if st == "normal" else Color(0.95, 0.55, 0.1, 0.95)
			cs.set_border_width_all(1)
			cs.border_color = Color(1, 1, 1, 0.25)
			c.add_theme_stylebox_override(st, cs)
		c.pressed.connect(func(): topic_input.text = t)
		chips.add_child(c)

	topic_input.reparent(col, false)
	topic_input.set_anchors_preset(Control.PRESET_TOP_LEFT)
	topic_input.custom_minimum_size = Vector2(560, 56)
	topic_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	topic_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.78)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.75, 0.3, 0.55)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	topic_input.add_theme_stylebox_override("normal", sb)
	var sbf := sb.duplicate()
	sbf.border_color = Color(1.0, 0.85, 0.4, 1.0)
	topic_input.add_theme_stylebox_override("focus", sbf)
	if not Global.selected_topic in ["programming", "coding"]:
		topic_input.text = Global.selected_topic

	start_button.reparent(col, false)
	start_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	start_button.custom_minimum_size = Vector2(230, 70)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(16)
		b.bg_color = {"normal": Color(0.85, 0.35, 0.05, 0.92), "hover": Color(1.0, 0.5, 0.1, 1.0), "pressed": Color(0.65, 0.25, 0.0, 1.0)}[st]
		b.shadow_color = Color(1.0, 0.5, 0.1, 0.45)
		b.shadow_size = 14 if st == "hover" else 8
		start_button.add_theme_stylebox_override(st, b)
	start_button.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.resized.connect(func(): start_button.pivot_offset = start_button.size * 0.5)
	var pulse := create_tween().set_loops()
	pulse.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(start_button, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	# One-line stats strip replaces the old floating panel
	$PlayerPanel.visible = false
	var stats := Label.new()
	stats.text = "⭐ Score %d     🧭 Level %d     🏆 Best %d" % [Global.score, Global.level, Global.high_score]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_override("font", font)
	stats.add_theme_font_size_override("font_size", 24)
	stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stats.add_theme_constant_override("outline_size", 6)
	col.add_child(stats)

	# Live status: AI server + difficulty picked by the RL model
	_status_label = Label.new()
	_status_label.add_theme_font_override("font", font)
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.position = Vector2(14, 52)
	$JoyStickUI.add_child(_status_label)
	_set_status("◌ Connecting…", Color(0.85, 0.88, 1.0))
	var http := HTTPRequest.new()
	http.timeout = 4.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, _b):
		var online: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200
		_set_status("● AI online" if online else "● Offline mode", Color(0.5, 1.0, 0.6) if online else Color(1.0, 0.8, 0.45)))
	http.request(Global.api_url("/health"))


func _set_status(text: String, col: Color) -> void:
	_status_label.text = "%s     🎯 %s     🔥 %d" % [text, Global.get_difficulty().capitalize(), Global.win_streak]
	_status_label.add_theme_color_override("font_color", col)


# Dev/testing: `godot -- --host-room=ABCDE --name=Ann` waits for a 2nd player then starts;
# `godot -- --join-room=ABCDE --name=Bob` joins it. Used to smoke-test multiplayer.
func _dev_autoplay() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.get_slice("=", 0).trim_prefix("--")] = a.get_slice("=", 1)
	if args.has("tutorial"):
		$JoyStickUI/TutorialButton._open()
	if args.has("lobby"):
		Lobby.open(self, func(): return topic_input.text.strip_edges())
	if args.has("host-room"):
		Net.host_room(args.get("name", "Host"), args["host-room"])
		while Net.peers.size() < int(args.get("players", "2")):
			await get_tree().create_timer(0.25).timeout
		Net.host_start_round(args.get("topic", "space"), 1)
		get_tree().change_scene_to_file("res://map_components/map.tscn")
	elif args.has("join-room"):
		Net.message.connect(func(_f, d):
			if str(d.get("t", "")) == "start":
				get_tree().change_scene_to_file("res://map_components/map.tscn"))
		Net.disconnected.connect(func(_r):  # host may not be up yet: retry
			await get_tree().create_timer(1.0).timeout
			Net.join_room(args["join-room"], args.get("name", "Guest")))
		Net.join_room(args["join-room"], args.get("name", "Guest"))
