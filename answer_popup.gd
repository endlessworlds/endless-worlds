extends CanvasLayer
class_name AnswerPopup

@onready var message: Label = $Panel/VBoxContainer/MessageLabel
@onready var input: LineEdit = $Panel/VBoxContainer/AnswerInput
@onready var submit: Button = $Panel/VBoxContainer/SubmitButton
@onready var close_button: Button = $Panel/CloseButton

var correct_answer: String = ""
var hearts: HeartSystem
var map_ref

func _ready():
	visible = false
	submit.pressed.connect(_on_submit)
	close_button.pressed.connect(close)

	# 🚫 Prevent Enter key from submitting
	input.gui_input.connect(_block_enter_key)

# =============================
# OPEN POPUP
# =============================
func open(solution: String, heart_system: HeartSystem, map):
	if solution.is_empty():
		push_error("❌ AnswerPopup opened with EMPTY solution!")
		return

	visible = true
	input.text = ""
	message.text = "Enter your answer"
	correct_answer = solution.to_lower()
	hearts = heart_system
	map_ref = map

	input.grab_focus()

# =============================
# BLOCK ENTER KEY
# =============================
func _block_enter_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()

# =============================
# ESC TO CLOSE
# =============================
func _input(event):
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()

func close():
	visible = false
	input.text = ""
	message.text = ""

# =============================
# SUBMIT LOGIC
# =============================
func _on_submit():
	var user_answer := input.text.strip_edges().to_lower()

	print(user_answer + " " + correct_answer)

	if user_answer == correct_answer:
		$"../DifficultyRL".give_feedback(true, Global.current_hint_count)
		Global.end_game(true)

		# 🎊 CONFETTI BLAST
		spawn_confetti()

		# 🎉 BIG VICTORY TEXT
		message.text = "🎉 VICTORY!"
		message.add_theme_font_size_override("font_size", 60)

		Global.add_score(50)
		Global.next_level()   # ⭐ LEVEL UP

		await get_tree().create_timer(1.5).timeout
		# # (Optional) reset font size so it doesn't affect reuse
		# message.remove_theme_font_size_override("font_size")
		close()
		
		# 🏠 GO BACK TO HOME
		get_tree().change_scene_to_file("res://HomeScreen.tscn")

	else:
		$"../DifficultyRL".give_feedback(false, Global.current_hint_count)
		message.text = "❌ Try again"
		hearts.damage(1)
		input.text = ""
		await get_tree().create_timer(1.0).timeout
		close()

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

		# 🎨 COLOR
		particles.modulate = c

		# 🔺 SHAPE TEXTURE
		var shape :Variant= shapes.pick_random()
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
					if Vector2(x, y).distance_to(Vector2(size/2.0, size/2)) <= size/2:
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

	var tex := ImageTexture.create_from_image(img)
	return tex
