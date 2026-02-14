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

@onready var victory_sound: AudioStreamPlayer = $VictorySound
@onready var gameover_sound: AudioStreamPlayer = $GameOverSound


# EXISTING OPTION BUTTONS (NO DYNAMIC CREATION)
@onready var option_buttons: Array[Button] = [
	$Panel/VBoxContainer/OptionsContainer/OptionA,
	$Panel/VBoxContainer/OptionsContainer/OptionB,
	$Panel/VBoxContainer/OptionsContainer/OptionC,
	$Panel/VBoxContainer/OptionsContainer/OptionD
]

@onready var fill_container: VBoxContainer = $Panel/VBoxContainer/FillContainer
@onready var answer_input: LineEdit = $Panel/VBoxContainer/FillContainer/AnswerInput


var correct_answer := ""
var selected_answer := ""
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
	
	# NEW: Hide custom keyboard by default
	if keyboard:
		keyboard.visible = false


# =============================
func _ready():
	visible = false
	submit.pressed.connect(_on_submit)
	close_button.pressed.connect(close)
	
	# --- KEYBOARD CONFIGURATION ---
	# Disable the system virtual keyboard for mobile devices
	answer_input.virtual_keyboard_enabled = false 
	# Keep editable so PC users can type and LineEdit logic works
	answer_input.editable = true 
	# Prevent the LineEdit from grabbing focus and potentially triggering OS behaviors
	answer_input.focus_mode = Control.FOCUS_CLICK
	
	# Listen to custom 2D keyboard buttons
	if keyboard:
		keyboard.key_pressed.connect(_on_custom_key_pressed)
		keyboard.backspace_pressed.connect(_on_custom_backspace)
		keyboard.enter_pressed.connect(_on_submit)

func _on_custom_key_pressed(chars: String):
	# Update LineEdit for Fill-in-the-blank
	answer_input.text += chars
	answer_input.caret_column = answer_input.text.length()
	
	# Update Wordle Grid
	if popup_type == Global.QuestionType.WORDLE:
		_handle_wordle_input(chars)

func _on_custom_backspace():
	# Backspace for LineEdit
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
	if current_col < correct_answer.length():
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
func open(solution: String, options: Array, heart_system: HeartSystem, map):
	if solution.is_empty():
		push_error("❌ Empty correct answer")
		return

	visible = true
	
	# --- BLOCK BACKGROUND INPUT ---
	# This ensures that mouse clicks don't go through the panel
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Optional: If you want to stop the player from moving/processing logic
	# get_tree().paused = true # Uncomment if your game supports pausing
	
	hearts = heart_system
	map_ref = map
	correct_answer = solution.to_lower()
	selected_answer = ""

	_hide_all_popups()
	
	popup_type = Global.current_question_type

	match Global.current_question_type:
		Global.QuestionType.MCQ:
			_open_mcq(options)
		Global.QuestionType.FILL_BLANK:
			_open_fill_blank()
		Global.QuestionType.WORDLE:
			_open_wordle()

func close():
	# --- RESTORE BACKGROUND INPUT ---
	# get_tree().paused = false # Uncomment if you used the pause method
	
	_hide_all_popups()
	visible = false
	selected_answer = ""
	message.text = ""

	for btn in option_buttons:
		btn.modulate = Color.WHITE
		btn.disabled = false

# Update _unhandled_input to "consume" the event
func _unhandled_input(event):
	if not visible: return
	
	# Stop the event from reaching nodes behind this popup
	get_viewport().set_input_as_handled()
	
	# Only process if Wordle is active
	if Global.current_question_type != Global.QuestionType.WORDLE: return
	if current_row >= max_attempts: return
	
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
			key_text = char(event.unicode).to_upper()
			if key_text != "":
				_on_custom_key_pressed(key_text)
		
		# TRIGGER THE COOL ANIMATION
		if keyboard and key_text != "":
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
	answer_input.grab_focus()

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
	gameover_sound.play()
	Global.add_score(-10)
	hearts.damage(2)
	await get_tree().create_timer(1.0).timeout
	close()
	
# =============================


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
