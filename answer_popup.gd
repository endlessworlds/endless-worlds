#change the ui to be exactly same as the ui of actual wordle and animations and also font size increase

extends CanvasLayer
class_name AnswerPopup

@onready var wordle_grid := $Panel/VBoxContainer/FillContainer/WordleGrid
@onready var keyboard = $Panel/VBoxContainer/CustomKeyboard # Adjust path to your sibling node
var max_attempts := 5
var current_row := 0
var current_col := 0
var boxes := []

# Add these constants at the top of your script
const COLOR_CORRECT = Color("6aaa64") # Green
const COLOR_PRESENT = Color("c9b458") # Yellow
const COLOR_ABSENT = Color("787c7e")  # Gray
const COLOR_EMPTY = Color("3a3a3c")   # Dark Gray Border


@onready var message: Label = $Panel/VBoxContainer/MessageLabel
@onready var submit: Button = $Panel/VBoxContainer/SubmitButton
@onready var close_button: Button = $Panel/CloseButton
@onready var question_label: Label = $Panel/VBoxContainer/QuestionLabel

@onready var victory_sound: AudioStreamPlayer = $VictorySound
@onready var gameover_sound: AudioStreamPlayer = $GameOverSound
const KBC_OPEN_SOUND  = preload("res://assets/answerpopup/kbc-question.mp3")
const KBC_LOCK_SOUND  = preload("res://assets/answerpopup/kbc-answer-locked-in.mp3")
const KBC_RIGHT_SOUND = preload("res://assets/answerpopup/kbc-right-answer.mp3")
const KBC_WRONG_SOUND = preload("res://assets/answerpopup/kbc-wrong-answer.mp3")


@onready var whack_container = $Panel/VBoxContainer/WhackContainer
@onready var mole_grid = $Panel/VBoxContainer/WhackContainer/MoleGrid
@onready var hammer: TextureRect = $Hammer

var mole_slots = []
var whack_timer : Timer
var active_mole_index := -1
var hammer_rest_rotation := 0.0
var hammer_hit_rotation := -35.0
var whack_active := false
var kbc_open_sound_player: AudioStreamPlayer
var kbc_lock_sound_player: AudioStreamPlayer
var kbc_right_sound_player: AudioStreamPlayer
var kbc_wrong_sound_player: AudioStreamPlayer

# EXISTING OPTION BUTTONS (NO DYNAMIC CREATION)
@onready var option_buttons: Array[Button] = [
	$Panel/VBoxContainer/OptionsContainer/OptionA,
	$Panel/VBoxContainer/OptionsContainer/OptionB,
	$Panel/VBoxContainer/OptionsContainer/OptionC,
	$Panel/VBoxContainer/OptionsContainer/OptionD
]

@onready var fill_container: VBoxContainer = $Panel/VBoxContainer/FillContainer
@onready var answer_input: LineEdit = $Panel/VBoxContainer/FillContainer/AnswerInput
@onready var wordlock_container: HBoxContainer = $Panel/VBoxContainer/WordLockContainer

# WordLock constants
const WORDLOCK_LABEL_H := 60
const WORDLOCK_COL_W  := 70
const WORDLOCK_COL_SEP := 8   # tile separation inside each column VBox
const WORDLOCK_CLIP_H  := 468  # visible viewport height (7 tiles: 7×60 + 6×8)
const WORDLOCK_FONT = preload("res://Jersey10-Regular.ttf")
# WordLock colour palette
const WORDLOCK_ACTIVE_BG    := Color(0.294, 0.0,   0.510)        # #4B0082 deep indigo
const WORDLOCK_INACTIVE_BG  := Color(0.800, 0.800, 1.0  )        # #CCCCFF light lavender
const WORDLOCK_GLOW_COLOR   := Color(0.471, 0.318, 0.663)        # #7851A9 medium purple
const WORDLOCK_INACTIVE_FONT := Color(0.294, 0.0,  0.510)        # dark indigo on lavender bg

var wordlock_columns: Array = []
var wordlock_selected_chars: Array = []

# ========== KBC VARIABLES ==========
const KBC_BG_COLOR      := Color(0.043, 0.043, 0.271, 0.4)   # #0B0B45 Dark Blue 50% transparent
const KBC_GOLD          := Color(1.0, 0.843, 0.0)       # #FFD700 Gold
const KBC_OPTION_BG     := Color(0.05, 0.1, 0.35)       # Dark blue option bg
const KBC_OPTION_BORDER := Color(1.0, 0.843, 0.0, 0.6)  # Gold border
const KBC_LIFELINE_BG   := Color(0.1, 0.1, 0.4, 0.9)    # Original lifeline blue
const KBC_GRADIENT_TOP  := Color(0.18, 0.28, 0.80, 0.96)
const KBC_GRADIENT_MID  := Color(0.07, 0.09, 0.46, 0.96)
const KBC_GRADIENT_BOTTOM := Color(0.02, 0.02, 0.18, 0.96)
const KBC_Q_GRADIENT_TOP := Color(0.22, 0.34, 0.92, 0.96)
const KBC_Q_GRADIENT_MID := Color(0.08, 0.10, 0.50, 0.96)
const KBC_Q_GRADIENT_BOTTOM := Color(0.02, 0.02, 0.20, 0.96)
const KBC_SELECTED_TOP := Color(0.95, 0.77, 0.15, 0.96)
const KBC_SELECTED_MID := Color(0.48, 0.30, 0.02, 0.96)
const KBC_SELECTED_BOTTOM := Color(0.18, 0.10, 0.01, 0.96)
const KBC_CORRECT_COLOR := Color(0.0, 0.7, 0.0)         # Green
const KBC_WRONG_COLOR   := Color(0.85, 0.1, 0.1)        # Red
const KBC_SELECTED_COLOR := Color(0.9, 0.75, 0.0)       # Yellow/Gold highlight

var kbc_container: Control = null
var kbc_msg_label: Label = null
var kbc_option_buttons: Array = []
var kbc_lifeline_buttons: Array = []  # [fifty_fifty, audience_poll, phone_friend]
var kbc_lock_btn: Button = null
var kbc_locked_in_player: AudioStreamPlayer = null
var kbc_right_answer_player: AudioStreamPlayer = null
var kbc_wrong_answer_player: AudioStreamPlayer = null
var kbc_selected_answer := ""
var kbc_lifelines_used := { "fifty_fifty": false, "audience_poll": false, "phone_friend": false }
var kbc_current_options: Array = []
var kbc_audience_popup: Control = null
var kbc_phone_popup: Control = null

var correct_answer := ""
var selected_answer := ""
var current_question := ""
var popup_type: Global.QuestionType
var hearts: HeartSystem
var map_ref

func _hide_all_popups():
	# Hide MCQ
	for btn in option_buttons:
		btn.visible = false

	# Hide fill in blank
	fill_container.visible = false
	answer_input.text = ""
	
	# Hide whack-a-mole
	whack_container.visible = false
	
	# Hide word lock
	wordlock_container.visible = false
	
	# Hide KBC
	if kbc_container:
		kbc_container.visible = false
	if kbc_audience_popup:
		kbc_audience_popup.queue_free()
		kbc_audience_popup = null
	if kbc_phone_popup:
		kbc_phone_popup.queue_free()
		kbc_phone_popup = null
	
	# NEW: Hide custom keyboard by default
	if keyboard:
		keyboard.visible = false


# =============================
func _ready():
	visible = false
	hammer.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	kbc_open_sound_player = AudioStreamPlayer.new()
	kbc_open_sound_player.stream = KBC_OPEN_SOUND
	add_child(kbc_open_sound_player)
	kbc_locked_in_player = AudioStreamPlayer.new()
	kbc_locked_in_player.stream = KBC_LOCK_SOUND
	add_child(kbc_locked_in_player)
	kbc_right_answer_player = AudioStreamPlayer.new()
	kbc_right_answer_player.stream = KBC_RIGHT_SOUND
	add_child(kbc_right_answer_player)
	kbc_wrong_answer_player = AudioStreamPlayer.new()
	kbc_wrong_answer_player.stream = KBC_WRONG_SOUND
	add_child(kbc_wrong_answer_player)
	submit.pressed.connect(_on_submit)
	close_button.pressed.connect(close)
	
	# Prevent UI focus from capturing keyboard navigation (WASD/UI actions)
	submit.focus_mode = Control.FOCUS_NONE
	close_button.focus_mode = Control.FOCUS_NONE
	for btn in option_buttons:
		btn.focus_mode = Control.FOCUS_NONE
	
	# --- KEYBOARD CONFIGURATION ---
	# Disable the system virtual keyboard for mobile devices
	answer_input.virtual_keyboard_enabled = false 
	# Keep editable so PC users can type and LineEdit logic works
	answer_input.editable = true 
	# Prevent the LineEdit from grabbing focus and potentially triggering OS behaviors
	answer_input.focus_mode = Control.FOCUS_CLICK
	for child in mole_grid.get_children():
		mole_slots.append(child)
	whack_timer = Timer.new()
	whack_timer.wait_time = 0.75
	whack_timer.timeout.connect(_pop_random_mole)
	add_child(whack_timer)

	

	for i in range(mole_slots.size()):
		var slot = mole_slots[i]
		slot.gui_input.connect(_on_mole_clicked.bind(i))
		
		
	for slot in mole_slots:
		var slot_w = slot.custom_minimum_size.x  # 300
		var clip = slot.get_node("ClipContainer")
		var mole = clip.get_node("Mole")
		var hole = slot.get_node("Hole")
		var label = slot.get_node("OptionLabel")
		# Center ClipContainer horizontally
		var clip_w = clip.size.x
		clip.position.x = (slot_w - clip_w) / 2.0
		# Center Mole inside ClipContainer
		var mole_w = mole.size.x
		mole.position.x = (clip_w - mole_w) / 2.0
		# Center Hole horizontally
		var hole_w = hole.size.x
		hole.position.x = (slot_w - hole_w) / 2.0
		# Hide mole below clip
		mole.position.y = clip.size.y
	# Listen to custom 2D keyboard buttons
	if keyboard:
		keyboard.key_pressed.connect(_on_custom_key_pressed)
		keyboard.backspace_pressed.connect(_on_custom_backspace)
		keyboard.enter_pressed.connect(_on_submit)

func _process(_delta):
	if whack_active:
		hammer.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		hammer.global_position = get_viewport().get_mouse_position() - hammer.size * 0.5
	else:
		hammer.visible = false
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_custom_key_pressed(chars: String):
	# Update LineEdit for Fill-in-the-blank
	if popup_type == Global.QuestionType.FILL_BLANK:
		answer_input.text += chars
		answer_input.caret_column = answer_input.text.length()
	
	# Update Wordle Grid
	if popup_type == Global.QuestionType.WORDLE:
		_handle_wordle_input(chars)

func _on_custom_backspace():
	# Backspace for LineEdit (fill-in-the-blank)
	if popup_type == Global.QuestionType.FILL_BLANK:
		if answer_input.text.length() > 0:
			answer_input.text = answer_input.text.left(-1)
	
	# Backspace for Wordle
	if popup_type == Global.QuestionType.WORDLE and current_col > 0:
		current_col -= 1
		var box = boxes[current_row][current_col]
		box.get_child(0).text = ""



# Shared logic for Wordle input (triggered by PC or Custom Buttons)
func _handle_wordle_input(chars: String):
	if current_row >= max_attempts: return
	if current_col >= correct_answer.length(): return  # Prevent writing beyond word length
	
	var box = boxes[current_row][current_col]
	box.get_child(0).text = chars.to_upper()
	
	# Animation
	var tween = create_tween()
	tween.tween_property(box, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(box, "scale", Vector2(1.0, 1.0), 0.05)
	current_col += 1

		
		
# =============================
# OPEN POPUP WITH MCQs
# =============================
func open(solution: String, options: Array, heart_system: HeartSystem, map, question: String = ""):
	if solution.is_empty():
		push_error("❌ Empty correct answer")
		return

	visible = true
	get_viewport().gui_release_focus()
	
	# --- BLOCK BACKGROUND INPUT ---
	# This ensures that mouse clicks don't go through the panel
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	hearts = heart_system
	map_ref = map
	correct_answer = solution.to_lower()
	selected_answer = ""
	current_question = question

	_hide_all_popups()
	
	# Display question at the top if provided
	if question_label and not question.is_empty():
		question_label.text = question
		question_label.visible = true
	elif question_label:
		question_label.visible = false
	
	popup_type = Global.current_question_type

	match Global.current_question_type:
		Global.QuestionType.MCQ:
			_open_mcq(options)
		Global.QuestionType.FILL_BLANK:
			_open_fill_blank()
		Global.QuestionType.WORDLE:
			_open_wordle()
		Global.QuestionType.WHACK:
			_open_whack(options, solution)
		Global.QuestionType.WORD_LOCK:
			_open_wordlock()
		Global.QuestionType.KBC:
			_open_kbc(options)

func _open_whack(options: Array, solution: String):
	whack_container.visible = true
	submit.visible = false  # No submit button for whack mode
	correct_answer = solution.to_lower()

	# Shuffle options and reset all moles to hidden position
	var shuffled = options.duplicate()
	shuffled.shuffle()

	for i in range(mole_slots.size()):
		var slot = mole_slots[i]
		var label = slot.get_node("OptionLabel")
		label.text = shuffled[i]
		label.visible = false
		# Fit label width to text + padding and center it
		var slot_w = slot.custom_minimum_size.x
		var text_w = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, label.get_theme_font_size("font_size")).x
		var padding = 20.0
		label.size.x = text_w + padding
		label.position.x = (slot_w - label.size.x) / 2.0
		# Ensure mole is in hidden position
		var clip = slot.get_node("ClipContainer")
		var mole = clip.get_node("Mole")
		mole.position.y = clip.size.y

	active_mole_index = -1
	whack_active = true
	whack_timer.start()


func _pop_random_mole():
	if active_mole_index != -1:
		_hide_mole(active_mole_index)

	active_mole_index = randi() % mole_slots.size()
	_show_mole(active_mole_index)

func _show_mole(index):
	var clip = mole_slots[index].get_node("ClipContainer")
	var mole = clip.get_node("Mole")

	var tween = create_tween()
	tween.tween_property(mole, "position:y", 0, 0.135)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	var label = mole_slots[index].get_node("OptionLabel")
	label.visible = true
func _hide_mole(index):
	var clip = mole_slots[index].get_node("ClipContainer")
	var mole = clip.get_node("Mole")

	var hidden_y = clip.size.y

	var tween = create_tween()
	tween.tween_property(mole, "position:y", hidden_y, 0.135)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	var label = mole_slots[index].get_node("OptionLabel")
	label.visible = false
func _on_mole_clicked(event, index):
	if event is InputEventMouseButton and event.pressed:
		if index != active_mole_index:
			return

		# Validate click is within the mole/hole visual area (centered 220x220 in 300x300 slot)
		var local_pos = event.position
		var hole_rect = Rect2(40, 0, 220, 300)  # Covers hole + mole visual area
		if not hole_rect.has_point(local_pos):
			return

		_swing_hammer()
		_shake_panel()

		var label = mole_slots[index].get_node("OptionLabel")
		var chosen = label.text.to_lower()

		# Stop the game logic but keep hammer visible during victory/loss animation
		if whack_timer:
			whack_timer.stop()
		active_mole_index = -1

		if chosen == correct_answer:
			_handle_victory_shared()
		else:
			_handle_wrong_shared()		
func _stop_whack():
	whack_active = false
	if whack_timer:
		whack_timer.stop()
	active_mole_index = -1
	hammer.visible = false
	hammer.rotation_degrees = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _swing_hammer():
	var tween = create_tween()
	tween.tween_property(hammer, "rotation_degrees", hammer_hit_rotation, 0.05)
	tween.tween_property(hammer, "rotation_degrees", hammer_rest_rotation, 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _shake_panel():
	var original_pos = $Panel.position
	var tween = create_tween()
	for i in 5:
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property($Panel, "position", original_pos + offset, 0.03)
	tween.tween_property($Panel, "position", original_pos, 0.05)

func close():
	_stop_whack()
	_hide_all_popups()
	visible = false
	selected_answer = ""
	message.text = ""
	
	# Reset submit button visibility
	submit.visible = true
	
	# Hide question label
	if question_label:
		question_label.visible = false

	for btn in option_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = false
	
	# Reset KBC state
	kbc_selected_answer = ""
	kbc_msg_label = null
	kbc_lock_btn = null
	kbc_lifelines_used = { "fifty_fifty": false, "audience_poll": false, "phone_friend": false }
	kbc_current_options.clear()
	kbc_option_buttons.clear()
	kbc_lifeline_buttons.clear()
	if kbc_locked_in_player and kbc_locked_in_player.playing:
		kbc_locked_in_player.stop()
	if kbc_right_answer_player and kbc_right_answer_player.playing:
		kbc_right_answer_player.stop()
	if kbc_wrong_answer_player and kbc_wrong_answer_player.playing:
		kbc_wrong_answer_player.stop()
	if kbc_container:
		kbc_container.queue_free()
		kbc_container = null

# Update _unhandled_input to "consume" the event
func _unhandled_input(event):
	if not visible: return
	
	# Stop the event from reaching nodes behind this popup
	get_viewport().set_input_as_handled()
	
	# Handle keyboard input for both WORDLE and FILL_BLANK
	if event is InputEventKey and event.pressed:
		var key_text = ""
		
		if event.keycode == KEY_BACKSPACE:
			key_text = "BKSP"
			_on_custom_backspace()
		elif event.keycode == KEY_ENTER:
			key_text = "ENTER"
			_on_submit()
		elif event.keycode == KEY_SPACE:
			key_text = "SPACE"
			_on_custom_key_pressed(" ")
		else:
			# Convert physical key to string (e.g., "A")
			if event.unicode != 0:
				key_text = char(event.unicode).to_upper()
				if key_text != "":
					_on_custom_key_pressed(key_text)
		
		# TRIGGER THE COOL ANIMATION (Wordle + Fill-in-the-blank)
		if keyboard and key_text != "" and Global.current_question_type in [Global.QuestionType.WORDLE, Global.QuestionType.FILL_BLANK]:
			keyboard.animate_key_press(key_text)

func _build_wordle_grid():
	boxes.clear()
	current_row = 0
	current_col = 0
	for row in wordle_grid.get_children(): row.queue_free()

	for r in range(max_attempts):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8) # Space between boxes
		wordle_grid.add_child(row)
		
		var row_boxes := []
		for i in correct_answer.length():
			var panel = PanelContainer.new()
			var lbl = Label.new()
			var style = StyleBoxFlat.new()
			
			# FIX: Set borders individually to avoid the error
			style.draw_center = true
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2) # Helper method (works in Godot 4)
			# If set_border_width_all still fails, use:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = COLOR_EMPTY
			
			panel.add_theme_stylebox_override("panel", style)
			panel.custom_minimum_size = Vector2(60, 60)
			panel.pivot_offset = Vector2(30, 30)
			
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 32)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			
			panel.add_child(lbl)
			row.add_child(panel)
			row_boxes.append(panel)
		boxes.append(row_boxes)
		
func _apply_wordlock_btn_style(btn: Button, style: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style)
	btn.add_theme_stylebox_override("pressed", style)

func _make_wordlock_tile_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left    = 12
	s.corner_radius_top_right   = 12
	s.corner_radius_bottom_right = 12
	s.corner_radius_bottom_left  = 12
	if selected:
		s.bg_color     = WORDLOCK_ACTIVE_BG
		s.border_width_left   = 3
		s.border_width_top    = 3
		s.border_width_right  = 3
		s.border_width_bottom = 3
		s.border_color  = WORDLOCK_GLOW_COLOR
		s.shadow_color  = Color(WORDLOCK_GLOW_COLOR.r, WORDLOCK_GLOW_COLOR.g, WORDLOCK_GLOW_COLOR.b, 0.85)
		s.shadow_size   = 8
	else:
		s.bg_color     = WORDLOCK_INACTIVE_BG
		s.shadow_color = Color(WORDLOCK_GLOW_COLOR.r, WORDLOCK_GLOW_COLOR.g, WORDLOCK_GLOW_COLOR.b, 0.30)
		s.shadow_size  = 3
	return s

func _open_wordlock():
	message.text = "Select the correct characters"
	wordlock_container.visible = true
	_build_wordlock_columns()

func _build_wordlock_columns():
	for child in wordlock_container.get_children():
		child.queue_free()
	wordlock_columns.clear()
	wordlock_selected_chars.clear()

	var word := correct_answer.to_upper()
	var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

	for col_idx in word.length():
		var correct_char := word[col_idx]

		var count := randi_range(2, 4)
		var chars: Array[String] = [correct_char]
		while chars.size() < count:
			var c := alphabet[randi() % alphabet.length()]
			if not chars.has(c):
				chars.append(c)
		chars.shuffle()

		# Clip container — defines the visible scroll viewport
		var clip := Control.new()
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(WORDLOCK_COL_W, WORDLOCK_CLIP_H)

		# VBoxContainer scrolled inside the clip
		var col_box := VBoxContainer.new()
		col_box.add_theme_constant_override("separation", WORDLOCK_COL_SEP)
		clip.add_child(col_box)

		# Top padding: 3 tile-slots so tile 0 centres at row 4 (viewport middle)
		var pad_top := Control.new()
		pad_top.custom_minimum_size = Vector2(WORDLOCK_COL_W, (WORDLOCK_CLIP_H - WORDLOCK_LABEL_H) / 2 - WORDLOCK_COL_SEP)
		col_box.add_child(pad_top)

		var char_labels: Array = []
		for i in chars.size():
			var btn := Button.new()
			btn.text = chars[i]
			btn.custom_minimum_size = Vector2(WORDLOCK_COL_W, WORDLOCK_LABEL_H)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 30)
			btn.add_theme_font_override("font", WORDLOCK_FONT)
			var font_col := Color.WHITE if i == 0 else WORDLOCK_INACTIVE_FONT
			btn.add_theme_color_override("font_color",         font_col)
			btn.add_theme_color_override("font_hover_color",   font_col)
			btn.add_theme_color_override("font_pressed_color", font_col)
			var style := _make_wordlock_tile_style(i == 0)
			_apply_wordlock_btn_style(btn, style)
			btn.pressed.connect(_on_wordlock_char_selected.bind(col_idx, i))
			col_box.add_child(btn)
			char_labels.append(btn)

		# Bottom padding: symmetric with top so the last tile can also be centred
		var pad_bot := Control.new()
		pad_bot.custom_minimum_size = Vector2(WORDLOCK_COL_W, (WORDLOCK_CLIP_H - WORDLOCK_LABEL_H) / 2)
		col_box.add_child(pad_bot)

		wordlock_container.add_child(clip)
		wordlock_selected_chars.append(chars[0].to_lower())
		wordlock_columns.append({
			"charlist":     col_box,
			"labels":       char_labels,
			"selected_idx": 0,
			"chars":        chars
		})

func _on_wordlock_char_selected(col_idx: int, char_idx: int):
	var col: Dictionary = wordlock_columns[col_idx]

	# Restore normal style + dark font on previously selected tile
	var prev_btn: Button = col["labels"][col["selected_idx"]]
	_apply_wordlock_btn_style(prev_btn, _make_wordlock_tile_style(false))
	var inactive_font := WORDLOCK_INACTIVE_FONT
	prev_btn.add_theme_color_override("font_color",         inactive_font)
	prev_btn.add_theme_color_override("font_hover_color",   inactive_font)
	prev_btn.add_theme_color_override("font_pressed_color", inactive_font)

	# Apply selected style + white font to newly chosen tile
	var new_btn: Button = col["labels"][char_idx]
	_apply_wordlock_btn_style(new_btn, _make_wordlock_tile_style(true))
	new_btn.add_theme_color_override("font_color",         Color.WHITE)
	new_btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	new_btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	col["selected_idx"] = char_idx
	wordlock_selected_chars[col_idx] = col["chars"][char_idx].to_lower()

	# Smooth scroll: tween VBox.y so the selected tile centres at row 4 (CLIP_H/2).
	# pad_top = (CLIP_H-LABEL_H)/2 - SEP, so tile i centre = pad_top + SEP + i*(LABEL_H+SEP) + LABEL_H/2
	#                                                        = CLIP_H/2 - i*(LABEL_H+SEP).
	# Setting VBox.y = -(i*(LABEL_H+SEP)) places that centre at CLIP_H/2 (the viewport centre).
	var target_y := float(-char_idx * (WORDLOCK_LABEL_H + WORDLOCK_COL_SEP))
	var tween := create_tween()
	tween.tween_property(col["charlist"], "position:y", target_y, 0.25) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

func _open_mcq(options: Array):
	message.text = "Choose the correct answer"

	# RESET & FILL EXISTING BUTTONS
	for i in option_buttons.size():
		var btn := option_buttons[i]

		btn.modulate = Color.WHITE
		btn.disabled = false
		btn.visible = false

		# Disconnect old signals safely
		for c in btn.pressed.get_connections():
			btn.pressed.disconnect(c.callable)

		if i < options.size():
			btn.text = options[i]
			btn.visible = true
			btn.pressed.connect(_on_option_selected.bind(btn, options[i]))

func _open_fill_blank():
	message.text = "Fill in the correct answer"
	fill_container.visible = true
	if keyboard: keyboard.visible = true # NEW: Show for Fill Blank
	answer_input.visible = true
	# Don't grab focus - we handle keyboard input in _unhandled_input

func _open_wordle():
	message.text = "Guess the word"
	fill_container.visible = true
	answer_input.visible = false
	if keyboard: keyboard.visible = true # NEW: Show for Wordle
	_build_wordle_grid()


# =============================
# OPTION SELECT
# =============================
func _on_option_selected(btn: Button, option_text: String):
	selected_answer = option_text.to_lower()

	# Reset all buttons
	for b in option_buttons:
		b.modulate = Color.WHITE

	# Highlight selected
	btn.modulate = Color(0.6, 1.0, 0.6)

# =============================
# SUBMIT ANSWER
# =============================
func _on_submit():
	var user_answer := ""

	match popup_type:
		Global.QuestionType.MCQ:
			user_answer = selected_answer
			_process_standard_answer(user_answer)
			
		Global.QuestionType.FILL_BLANK:
			user_answer = answer_input.text.strip_edges().to_lower()
			_process_standard_answer(user_answer)
			
		Global.QuestionType.WORDLE:
			# Check if the current row is full
			if current_col < correct_answer.length():
				message.text = "⚠ Not enough letters"
				# Optional: Add a shake animation here
				return
			
			# You already have this! We just need to call it.
			_evaluate_word()
		
		Global.QuestionType.WORD_LOCK:
			user_answer = "".join(wordlock_selected_chars)
			_process_standard_answer(user_answer)
		
		Global.QuestionType.KBC:
			_kbc_process_answer(kbc_selected_answer)
			return

# Helper to handle the logic for MCQ and Fill-in-blank
func _process_standard_answer(user_answer: String):
	if user_answer == "":
		message.text = "⚠ Answer required"
		return

	if user_answer == correct_answer:
		_handle_victory_shared()
	else:
		_handle_wrong_shared()

func _handle_victory_shared():
	if has_node("../DifficultyRL"):
		$"../DifficultyRL".give_feedback(true, Global.current_hint_count)
	Global.end_game(true)
	spawn_confetti()
	message.text = "🎉 VICTORY!"
	if kbc_msg_label:
		kbc_msg_label.text = "🎉 VICTORY!"
		kbc_msg_label.add_theme_color_override("font_color", KBC_GOLD)
		kbc_msg_label.visible = true
	victory_sound.play()
	Global.add_score(30)
	Global.next_level()
	await get_tree().create_timer(1.5).timeout
	close()
	get_tree().change_scene_to_file("res://HomeScreen.tscn")

func _handle_wrong_shared():
	if has_node("../DifficultyRL"):
		$"../DifficultyRL".give_feedback(false, Global.current_hint_count)
	message.text = "❌ Wrong Answer"
	if kbc_msg_label:
		kbc_msg_label.text = "❌ Wrong Answer"
		kbc_msg_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		kbc_msg_label.visible = true
	if popup_type != Global.QuestionType.KBC:
		gameover_sound.play()
	Global.add_score(-10)
	hearts.damage(2)
	await get_tree().create_timer(1.0).timeout
	close()
	
# =============================
# KBC ANSWER WITH SUSPENSE
# =============================
func _kbc_process_answer(user_answer: String):
	if user_answer == "":
		message.text = "⚠ Select an answer first"
		return

	# Block input on options and lock button without visually greying them out
	for btn in kbc_option_buttons:
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kbc_lock_btn:
		kbc_lock_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Play the dramatic locked-in sound and wait for it to finish
	if kbc_locked_in_player.playing:
		kbc_locked_in_player.stop()
	kbc_locked_in_player.play()
	await kbc_locked_in_player.finished

	# Reveal the result
	_kbc_highlight_answer(user_answer)

	if user_answer == correct_answer:
		kbc_right_answer_player.play()
		if has_node("../DifficultyRL"):
			$"../DifficultyRL".give_feedback(true, Global.current_hint_count)
		Global.end_game(true)
		spawn_confetti()
		message.text = "🎉 VICTORY!"
		if kbc_msg_label:
			kbc_msg_label.text = "🎉 VICTORY!"
			kbc_msg_label.add_theme_color_override("font_color", KBC_GOLD)
			kbc_msg_label.visible = true
		Global.add_score(30)
		Global.next_level()
		await get_tree().create_timer(2.5).timeout
		close()
		get_tree().change_scene_to_file("res://HomeScreen.tscn")
	else:
		kbc_wrong_answer_player.play()
		if has_node("../DifficultyRL"):
			$"../DifficultyRL".give_feedback(false, Global.current_hint_count)
		message.text = "❌ Wrong Answer"
		if kbc_msg_label:
			kbc_msg_label.text = "❌ Wrong Answer"
			kbc_msg_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			kbc_msg_label.visible = true
		Global.add_score(-10)
		hearts.damage(2)
		await get_tree().create_timer(2.5).timeout
		close()

func _kbc_highlight_answer(selected: String):
	for i in kbc_option_buttons.size():
		var btn: Button = kbc_option_buttons[i]
		var opt_text: String = kbc_current_options[i].to_lower()
		if opt_text == correct_answer:
			var green_style := _make_kbc_option_hex_style(
				320, 44,
				Color(0.0, 0.55, 0.05, 0.96),
				Color(0.0, 0.38, 0.03, 0.96),
				Color(0.0, 0.22, 0.02, 0.96),
				KBC_CORRECT_COLOR, 14, 3
			)
			btn.add_theme_stylebox_override("normal", green_style)
			btn.add_theme_stylebox_override("hover", green_style)
			btn.add_theme_stylebox_override("pressed", green_style)
			btn.add_theme_stylebox_override("disabled", green_style)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_disabled_color", Color.WHITE)
		elif opt_text == selected:
			var red_style := _make_kbc_option_hex_style(
				320, 44,
				Color(0.65, 0.0, 0.0, 0.96),
				Color(0.42, 0.0, 0.0, 0.96),
				Color(0.22, 0.0, 0.0, 0.96),
				KBC_WRONG_COLOR, 14, 3
			)
			btn.add_theme_stylebox_override("normal", red_style)
			btn.add_theme_stylebox_override("hover", red_style)
			btn.add_theme_stylebox_override("pressed", red_style)
			btn.add_theme_stylebox_override("disabled", red_style)
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_color_override("font_disabled_color", Color.WHITE)

# =============================
# KBC (KAUN BANEGA CROREPATI)
# =============================
func _open_kbc(options: Array):
	question_label.visible = false  # We'll show question in our own styled label
	message.text = ""
	submit.visible = false  # KBC uses direct option click, then a lock-in button

	kbc_selected_answer = ""
	kbc_current_options = options.duplicate()
	kbc_lifelines_used = { "fifty_fifty": false, "audience_poll": false, "phone_friend": false }
	if kbc_open_sound_player.playing:
		kbc_open_sound_player.stop()
	kbc_open_sound_player.play()

	# Build the entire KBC UI dynamically
	_build_kbc_ui(options)

func _build_kbc_ui(options: Array):
	if kbc_container:
		kbc_container.queue_free()
		kbc_container = null
	kbc_msg_label = null
	kbc_option_buttons.clear()
	kbc_lifeline_buttons.clear()

	# Root container
	kbc_container = Control.new()
	kbc_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	$Panel.add_child(kbc_container)

	# Dark blue KBC background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = KBC_BG_COLOR
	kbc_container.add_child(bg)

	# === FLOATING MESSAGE LABEL — shown on victory/wrong, always on top ===
	kbc_msg_label = Label.new()
	kbc_msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	kbc_msg_label.anchor_left = 0.05
	kbc_msg_label.anchor_right = 0.95
	kbc_msg_label.anchor_top = 0.0
	kbc_msg_label.anchor_bottom = 0.12
	kbc_msg_label.offset_left = 0
	kbc_msg_label.offset_right = 0
	kbc_msg_label.offset_top = 6
	kbc_msg_label.offset_bottom = 0
	kbc_msg_label.z_index = 100
	kbc_msg_label.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	kbc_msg_label.add_theme_font_size_override("font_size", 36)
	kbc_msg_label.add_theme_color_override("font_color", KBC_GOLD)
	kbc_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kbc_msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kbc_msg_label.visible = false
	kbc_container.add_child(kbc_msg_label)

	# === MAIN BODY: vertical stack with bottom lifelines ===
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.anchor_left = 0.02
	main_vbox.anchor_right = 0.98
	main_vbox.anchor_top = 0.02
	main_vbox.anchor_bottom = 0.98
	main_vbox.offset_left = 0
	main_vbox.offset_right = 0
	main_vbox.offset_top = 0
	main_vbox.offset_bottom = 0
	main_vbox.add_theme_constant_override("separation", 12)
	kbc_container.add_child(main_vbox)

	var logo_center := CenterContainer.new()
	logo_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(logo_center)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/answerpopup/kbc.png")
	logo.custom_minimum_size = Vector2(0, 320)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo_center.add_child(logo)

	var question_panel := PanelContainer.new()
	question_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q_style := _make_kbc_gradient_style(
		480,
		84,
		KBC_Q_GRADIENT_TOP,
		KBC_Q_GRADIENT_MID,
		KBC_Q_GRADIENT_BOTTOM,
		KBC_GOLD,
		20,
		2
	)
	q_style.content_margin_left = 20
	q_style.content_margin_right = 20
	q_style.content_margin_top = 10
	q_style.content_margin_bottom = 10
	question_panel.add_theme_stylebox_override("panel", q_style)
	main_vbox.add_child(question_panel)

	var q_label := Label.new()
	q_label.text = current_question
	q_label.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	q_label.add_theme_font_size_override("font_size", 28)
	q_label.add_theme_color_override("font_color", Color.WHITE)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_panel.add_child(q_label)

	var options_grid := GridContainer.new()
	options_grid.columns = 2
	options_grid.add_theme_constant_override("h_separation", 16)
	options_grid.add_theme_constant_override("v_separation", 12)
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(options_grid)

	var prefixes := ["A", "B", "C", "D"]
	for i in range(min(options.size(), 4)):
		var btn := _make_kbc_option_btn(prefixes[i] + ":  " + options[i])
		btn.pressed.connect(_on_kbc_option_selected.bind(i, options[i]))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options_grid.add_child(btn)
		kbc_option_buttons.append(btn)

	var lock_btn := Button.new()
	lock_btn.text = "LOCK"
	lock_btn.custom_minimum_size = Vector2(200, 50)
	lock_btn.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	lock_btn.add_theme_font_size_override("font_size", 28)
	lock_btn.focus_mode = Control.FOCUS_NONE
	var lock_style := StyleBoxFlat.new()
	lock_style.bg_color = Color(0.0, 0.5, 0.0, 0.9)
	lock_style.corner_radius_top_left = 16
	lock_style.corner_radius_top_right = 16
	lock_style.corner_radius_bottom_right = 16
	lock_style.corner_radius_bottom_left = 16
	lock_style.corner_detail = 1
	lock_style.border_width_left = 2
	lock_style.border_width_top = 2
	lock_style.border_width_right = 2
	lock_style.border_width_bottom = 2
	lock_style.border_color = KBC_GOLD
	lock_btn.add_theme_stylebox_override("normal", lock_style)
	lock_btn.add_theme_stylebox_override("hover", lock_style)
	lock_btn.add_theme_stylebox_override("pressed", lock_style)
	lock_btn.add_theme_color_override("font_color", Color.WHITE)
	lock_btn.pressed.connect(_on_submit)
	main_vbox.add_child(lock_btn)
	lock_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kbc_lock_btn = lock_btn

	var content_spacer := Control.new()
	content_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_spacer)

	var lifeline_bar := HBoxContainer.new()
	lifeline_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	lifeline_bar.add_theme_constant_override("separation", 12)
	lifeline_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(lifeline_bar)

	var lifeline_label := Label.new()
	lifeline_label.text = "⚡ LIFELINES"
	lifeline_label.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	lifeline_label.add_theme_font_size_override("font_size", 20)
	lifeline_label.add_theme_color_override("font_color", KBC_GOLD)
	lifeline_bar.add_child(lifeline_label)

	var btn_5050 := _make_kbc_lifeline_btn("🌓 50:50")
	btn_5050.pressed.connect(_kbc_use_fifty_fifty)
	lifeline_bar.add_child(btn_5050)

	var btn_audience := _make_kbc_lifeline_btn("📊 Audience")
	btn_audience.pressed.connect(_kbc_use_audience_poll)
	lifeline_bar.add_child(btn_audience)

	var btn_phone := _make_kbc_lifeline_btn("📞 Phone")
	btn_phone.pressed.connect(_kbc_use_phone_friend)
	lifeline_bar.add_child(btn_phone)

	kbc_lifeline_buttons = [btn_5050, btn_audience, btn_phone]

	# Ensure close button renders above KBC overlay
	close_button.move_to_front()

	# === MESSAGE LABEL (reuse existing) ===
	# message label is already part of the Panel, we just keep it visible

func _make_kbc_lifeline_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(190, 55)
	btn.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	btn.add_theme_font_size_override("font_size", 18)
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = KBC_LIFELINE_BG
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_detail = 1
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = KBC_GOLD
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", KBC_GOLD)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	return btn

func _make_kbc_gradient_style(width: int, height: int, top_color: Color, mid_color: Color, bottom_color: Color, border_color: Color, corner_cut: int, border_width: int) -> StyleBoxTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var t :Variant= float(y) / max(1.0, float(height - 1))
		var vertical := top_color.lerp(bottom_color, t)
		var mid_boost :Variant= 1.0 - abs(t - 0.5) * 2.0
		for x in range(width):
			var left := x
			var right := width - 1 - x
			var top := y
			var bottom := height - 1 - y
			var in_tl_cut := left < corner_cut and top < corner_cut and left + top < corner_cut
			var in_tr_cut := right < corner_cut and top < corner_cut and right + top < corner_cut
			var in_bl_cut := left < corner_cut and bottom < corner_cut and left + bottom < corner_cut
			var in_br_cut := right < corner_cut and bottom < corner_cut and right + bottom < corner_cut
			if in_tl_cut or in_tr_cut or in_bl_cut or in_br_cut:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var center_glow :Variant= 1.0 - abs((float(x) / max(1.0, float(width - 1))) - 0.5) * 2.0
			var fill := vertical.lerp(mid_color, clamp(mid_boost * 0.55 + center_glow * 0.20, 0.0, 0.65))

			var is_border := left < border_width or right < border_width or top < border_width or bottom < border_width
			is_border = is_border or (left < corner_cut and top < corner_cut and left + top < corner_cut + border_width)
			is_border = is_border or (right < corner_cut and top < corner_cut and right + top < corner_cut + border_width)
			is_border = is_border or (left < corner_cut and bottom < corner_cut and left + bottom < corner_cut + border_width)
			is_border = is_border or (right < corner_cut and bottom < corner_cut and right + bottom < corner_cut + border_width)

			image.set_pixel(x, y, border_color if is_border else fill)

	var texture := ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = corner_cut
	style.texture_margin_top = corner_cut
	style.texture_margin_right = corner_cut
	style.texture_margin_bottom = corner_cut
	return style

func _make_kbc_option_hex_style(width: int, height: int, top_color: Color, mid_color: Color, bottom_color: Color, border_color: Color, side_cut: int, border_width: int) -> StyleBoxTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var half_h :Variant= max(1.0, (height - 1) / 2.0)
	for y in range(height):
		var t :Variant= float(y) / max(1.0, float(height - 1))
		var vertical := top_color.lerp(bottom_color, t)
		var mid_boost :Variant= 1.0 - abs(t - 0.5) * 2.0
		var side_inset := int(round(side_cut * abs(float(y) - half_h) / half_h))
		var left_edge := side_inset
		var right_edge := width - 1 - side_inset

		for x in range(width):
			if x < left_edge or x > right_edge:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var center_glow :Variant= 1.0 - abs((float(x) / max(1.0, float(width - 1))) - 0.5) * 2.0
			var fill := vertical.lerp(mid_color, clamp(mid_boost * 0.55 + center_glow * 0.20, 0.0, 0.65))

			var is_border := x - left_edge < border_width or right_edge - x < border_width
			is_border = is_border or y < border_width or (height - 1 - y) < border_width
			image.set_pixel(x, y, border_color if is_border else fill)

	var texture := ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = side_cut
	style.texture_margin_top = 2
	style.texture_margin_right = side_cut
	style.texture_margin_bottom = 2
	return style

func _make_kbc_option_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 36)
	btn.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE
	var style := _make_kbc_option_hex_style(
		320,
		44,
		KBC_GRADIENT_TOP,
		KBC_GRADIENT_MID,
		KBC_GRADIENT_BOTTOM,
		KBC_OPTION_BORDER,
		14,
		2
	)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", KBC_GOLD)
	return btn

func _on_kbc_option_selected(index: int, option_text: String):
	kbc_selected_answer = option_text.to_lower()

	# Reset all option highlights
	for i in kbc_option_buttons.size():
		var btn: Button = kbc_option_buttons[i]
		var style := _make_kbc_option_hex_style(
			320,
			44,
			KBC_GRADIENT_TOP,
			KBC_GRADIENT_MID,
			KBC_GRADIENT_BOTTOM,
			KBC_OPTION_BORDER,
			14,
			2
		)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_color_override("font_color", Color.WHITE)

	# Highlight selected option in gold
	var selected_btn: Button = kbc_option_buttons[index]
	var sel_style := _make_kbc_option_hex_style(
		320,
		44,
		KBC_SELECTED_TOP,
		KBC_SELECTED_MID,
		KBC_SELECTED_BOTTOM,
		KBC_SELECTED_COLOR,
		14,
		3
	)
	selected_btn.add_theme_stylebox_override("normal", sel_style)
	selected_btn.add_theme_stylebox_override("hover", sel_style)
	selected_btn.add_theme_stylebox_override("pressed", sel_style)
	selected_btn.add_theme_color_override("font_color", KBC_GOLD)

# ========== KBC LIFELINES ==========

func _kbc_disable_lifeline_btn(btn: Button):
	btn.disabled = true
	var grey_style := StyleBoxFlat.new()
	grey_style.bg_color = Color(0.2, 0.2, 0.2, 0.7)
	grey_style.corner_radius_top_left = 20
	grey_style.corner_radius_top_right = 20
	grey_style.corner_radius_bottom_right = 20
	grey_style.corner_radius_bottom_left = 20
	grey_style.corner_detail = 1
	grey_style.border_width_left = 2
	grey_style.border_width_top = 2
	grey_style.border_width_right = 2
	grey_style.border_width_bottom = 2
	grey_style.border_color = Color(0.4, 0.4, 0.4)
	btn.add_theme_stylebox_override("normal", grey_style)
	btn.add_theme_stylebox_override("disabled", grey_style)
	btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))

func _kbc_use_fifty_fifty():
	if kbc_lifelines_used["fifty_fifty"]:
		return
	kbc_lifelines_used["fifty_fifty"] = true
	hearts.damage(2)
	_kbc_disable_lifeline_btn(kbc_lifeline_buttons[0])

	# Find wrong options and hide 2 of them
	var wrong_indices: Array = []
	for i in kbc_option_buttons.size():
		var btn_text: String = kbc_current_options[i].to_lower()
		if btn_text != correct_answer:
			wrong_indices.append(i)

	wrong_indices.shuffle()
	var to_hide := wrong_indices.slice(0, min(2, wrong_indices.size()))  # Hide 2 wrong options
	for idx in to_hide:
		var btn: Button = kbc_option_buttons[idx]
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.2)  # Fade out

	message.text = "🌓 50:50 used! Two options removed. (-2 ❤️)"

func _kbc_use_audience_poll():
	if kbc_lifelines_used["audience_poll"]:
		return
	kbc_lifelines_used["audience_poll"] = true
	hearts.damage(2)
	_kbc_disable_lifeline_btn(kbc_lifeline_buttons[1])

	# Generate percentages — correct answer gets highest
	var percentages := []
	var correct_pct := randi_range(45, 70)
	var correct_idx := -1
	var wrong_count := 0
	for i in kbc_current_options.size():
		if kbc_current_options[i].to_lower() == correct_answer:
			correct_idx = i
		else:
			wrong_count += 1
	var remaining := 100 - correct_pct
	for i in kbc_current_options.size():
		if i == correct_idx:
			percentages.append(correct_pct)
		else:
			wrong_count -= 1
			if wrong_count == 0:
				# Last wrong option gets all remaining
				percentages.append(remaining)
				remaining = 0
			else:
				var p := clampi(randi_range(3, max(5, remaining / (wrong_count + 1))), 1, remaining - wrong_count)
				percentages.append(p)
				remaining -= p
	# Safety: ensure total is exactly 100
	var total := 0
	for p in percentages:
		total += p
	if total != 100 and percentages.size() > 0:
		percentages[0] += (100 - total)

	# Show audience poll popup
	_show_kbc_audience_popup(percentages)
	message.text = "📊 Audience Poll used! (-2 ❤️)"

func _show_kbc_audience_popup(percentages: Array):
	if kbc_audience_popup:
		kbc_audience_popup.queue_free()

	kbc_audience_popup = PanelContainer.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.02, 0.02, 0.15, 0.95)
	popup_style.corner_radius_top_left = 16
	popup_style.corner_radius_top_right = 16
	popup_style.corner_radius_bottom_right = 16
	popup_style.corner_radius_bottom_left = 16
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = KBC_GOLD
	popup_style.content_margin_left = 20
	popup_style.content_margin_right = 20
	popup_style.content_margin_top = 16
	popup_style.content_margin_bottom = 16
	kbc_audience_popup.add_theme_stylebox_override("panel", popup_style)
	kbc_audience_popup.set_anchors_preset(Control.PRESET_CENTER)
	kbc_audience_popup.offset_left = -180
	kbc_audience_popup.offset_right = 180
	kbc_audience_popup.offset_top = -140
	kbc_audience_popup.offset_bottom = 140
	kbc_audience_popup.z_index = 10
	kbc_container.add_child(kbc_audience_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	kbc_audience_popup.add_child(vbox)

	var title := Label.new()
	title.text = "📊 Audience Poll Results"
	title.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", KBC_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var prefixes := ["A", "B", "C", "D"]
	for i in range(min(percentages.size(), 4)):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "%s: %d%%" % [prefixes[i], percentages[i]]
		lbl.custom_minimum_size = Vector2(70, 0)
		lbl.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(lbl)

		# Bar
		var bar_bg := ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(200, 22)
		bar_bg.color = Color(0.15, 0.15, 0.35)
		row.add_child(bar_bg)

		var bar_fill := ColorRect.new()
		var bar_color := KBC_GOLD if kbc_current_options[i].to_lower() == correct_answer else Color(0.3, 0.5, 0.8)
		bar_fill.color = bar_color
		bar_fill.custom_minimum_size = Vector2(0, 22)
		bar_fill.size = Vector2(0, 22)
		bar_bg.add_child(bar_fill)

		# Animate bar fill
		var target_w :Variant= (percentages[i] / 100.0) * 200.0
		var tw := create_tween()
		tw.tween_property(bar_fill, "custom_minimum_size:x", target_w, 0.6).set_trans(Tween.TRANS_SINE)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(80, 35)
	close_btn.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.1, 0.1, 0.4)
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_style.border_width_left = 1
	close_style.border_width_top = 1
	close_style.border_width_right = 1
	close_style.border_width_bottom = 1
	close_style.border_color = KBC_GOLD
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_color_override("font_color", KBC_GOLD)
	close_btn.pressed.connect(func():
		if kbc_audience_popup:
			kbc_audience_popup.queue_free()
			kbc_audience_popup = null
	)
	vbox.add_child(close_btn)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _kbc_use_phone_friend():
	if kbc_lifelines_used["phone_friend"]:
		return
	kbc_lifelines_used["phone_friend"] = true
	hearts.damage(2)
	_kbc_disable_lifeline_btn(kbc_lifeline_buttons[2])

	# Find the correct option text
	var friend_answer := ""
	for opt in kbc_current_options:
		if opt.to_lower() == correct_answer:
			friend_answer = opt
			break

	# Show phone-a-friend popup
	_show_kbc_phone_popup(friend_answer)
	message.text = "📞 Phone a Friend used! (-2 ❤️)"

func _show_kbc_phone_popup(friend_answer: String):
	if kbc_phone_popup:
		kbc_phone_popup.queue_free()

	kbc_phone_popup = PanelContainer.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.02, 0.02, 0.15, 0.95)
	popup_style.corner_radius_top_left = 16
	popup_style.corner_radius_top_right = 16
	popup_style.corner_radius_bottom_right = 16
	popup_style.corner_radius_bottom_left = 16
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = KBC_GOLD
	popup_style.content_margin_left = 24
	popup_style.content_margin_right = 24
	popup_style.content_margin_top = 20
	popup_style.content_margin_bottom = 20
	kbc_phone_popup.add_theme_stylebox_override("panel", popup_style)
	kbc_phone_popup.set_anchors_preset(Control.PRESET_CENTER)
	kbc_phone_popup.offset_left = -160
	kbc_phone_popup.offset_right = 160
	kbc_phone_popup.offset_top = -90
	kbc_phone_popup.offset_bottom = 90
	kbc_phone_popup.z_index = 10
	kbc_container.add_child(kbc_phone_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	kbc_phone_popup.add_child(vbox)

	var title := Label.new()
	title.text = "📞 Calling Friend..."
	title.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", KBC_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint_label := Label.new()
	hint_label.text = "\"I think the answer is %s\"" % friend_answer
	hint_label.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(80, 35)
	close_btn.add_theme_font_override("font", preload("res://Jersey10-Regular.ttf"))
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.1, 0.1, 0.4)
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_style.border_width_left = 1
	close_style.border_width_top = 1
	close_style.border_width_right = 1
	close_style.border_width_bottom = 1
	close_style.border_color = KBC_GOLD
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_color_override("font_color", KBC_GOLD)
	close_btn.pressed.connect(func():
		if kbc_phone_popup:
			kbc_phone_popup.queue_free()
			kbc_phone_popup = null
	)
	vbox.add_child(close_btn)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

# =============================
# CONFETTI (UNCHANGED)
# =============================
func spawn_confetti():
	var viewport_size := get_viewport().get_visible_rect().size

	var colors := [
		Color.RED,
		Color.YELLOW,
		Color.GREEN,
		Color.CYAN,
		Color.MAGENTA,
		Color.ORANGE
	]

	var shapes := ["circle", "square", "rectangle", "triangle", "parallelogram"]

	for c in colors:
		var particles := CPUParticles2D.new()
		add_child(particles)

		particles.position = viewport_size * 0.5 + Vector2(0, -200)
		particles.amount = 80
		particles.explosiveness = 1.0
		particles.lifetime = 2.0
		particles.one_shot = true
		particles.direction = Vector2(0, -1)
		particles.spread = 180
		particles.gravity = Vector2(0, 1200)
		particles.initial_velocity_min = 400
		particles.initial_velocity_max = 900
		particles.angular_velocity_min = 100
		particles.angular_velocity_max = 400
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.2
		particles.modulate = c

		var shape: Variant = shapes.pick_random()
		particles.texture = _make_shape_texture(shape, 16)

		particles.emitting = true
		get_tree().create_timer(3.0).timeout.connect(particles.queue_free)

func _make_shape_texture(shape: String, size := 16) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var c := Color.WHITE

	match shape:
		"circle":
			for x in size:
				for y in size:
					if Vector2(x, y).distance_to(Vector2(size / 2.0, size / 2.0)) <= size / 2.0:
						img.set_pixel(x, y, c)
		"square":
			img.fill(c)
		"rectangle":
			for x in size:
				for y in int(size * 0.6):
					img.set_pixel(x, y + int(size * 0.2), c)
		"triangle":
			for y in size:
				for x in int((y / float(size)) * size):
					img.set_pixel(x + (size - x) / 2, y, c)
		"parallelogram":
			for y in size:
				for x in int(size * 0.7):
					img.set_pixel(x + int(y * 0.2), y, c)

	return ImageTexture.create_from_image(img)


func _evaluate_word():
	var guess := ""
	for box in boxes[current_row]:
		guess += box.get_child(0).text.to_lower()

	# Color Logic with Wordle animations
	for i in guess.length():
		var box = boxes[current_row][i]
		var lbl = box.get_child(0)
		var char_guess = guess[i]
		var target_color = COLOR_ABSENT
		
		if correct_answer[i] == char_guess:
			target_color = COLOR_CORRECT
		elif correct_answer.contains(char_guess):
			target_color = COLOR_PRESENT

		# FLIP ANIMATION
		var tween = create_tween()
		tween.tween_property(box, "scale:y", 0.0, 0.1).set_delay(i * 0.1)
		
		# Change color exactly when the box is "flat"
		tween.step_finished.connect(func(idx):
			var style = box.get_theme_stylebox("panel").duplicate()
			style.bg_color = target_color
			style.border_color = target_color
			box.add_theme_stylebox_override("panel", style)
		, CONNECT_ONE_SHOT)
		
		tween.tween_property(box, "scale:y", 1.0, 0.1)

	# Wait for the last box to finish flipping
	await get_tree().create_timer(0.2 + (0.1 * guess.length())).timeout

	if guess == correct_answer:
		_wordle_victory()
	else:
		# RESTORED HEART/SCORE LOGIC
		Global.add_score(-5)
		if hearts:
			hearts.damage(1)
		
		current_row += 1
		current_col = 0
		
		if current_row >= max_attempts:
			_wordle_defeat()
			
func _wordle_defeat():
	message.text = "❌ Out of attempts!"
	gameover_sound.play()

	
	# Optional: Give feedback to your RL system if applicable
	if has_node("../DifficultyRL"):
		get_node("../DifficultyRL").give_feedback(false, Global.current_hint_count)

	# Wait a moment so the player can see their last row, then close
	await get_tree().create_timer(1.5).timeout
	close()
		
func _wordle_victory():
	spawn_confetti()
	victory_sound.play()
	message.text = "🎉 VICTORY!"

	Global.end_game(true)
	Global.add_score(30)
	Global.next_level()

	await get_tree().create_timer(1.5).timeout
	close()
	get_tree().change_scene_to_file("res://HomeScreen.tscn")
