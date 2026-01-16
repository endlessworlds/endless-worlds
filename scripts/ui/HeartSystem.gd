extends CanvasLayer
class_name HeartSystem

signal player_died

@export var max_hearts := 5
@export var heart_size := 40
@export var spacing := 6

var current_hearts := max_hearts
var hearts_container: HBoxContainer
var heart_full: Texture2D
var heart_empty: Texture2D

# 📳 SHAKE SETTINGS
var shake_strength := 12.0

# ==================================================
func _ready():
	create_hearts_ui()
	update_hearts_ui()

# ==================================================
func create_hearts_ui():
	hearts_container = HBoxContainer.new()
	add_child(hearts_container)

	# Load textures
	heart_full = load("res://assets/ui/heart_full.png")
	heart_empty = load("res://assets/ui/heart_empty.png")

	hearts_container.add_theme_constant_override("separation", spacing)

	# Create heart icons
	for i in range(max_hearts):
		var heart := TextureRect.new()
		heart.texture = heart_full
		heart.custom_minimum_size = Vector2(heart_size, heart_size)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		heart.modulate = Color(1, 1, 1, 0.8)
		hearts_container.add_child(heart)

	# Position top-right AFTER viewport is ready
	await get_tree().process_frame
	update_position()

# ==================================================
func update_position():
	var screen_size := get_viewport().get_visible_rect().size
	var total_width := max_hearts * heart_size + (max_hearts - 1) * spacing

	hearts_container.position = Vector2(
		screen_size.x - total_width - 20,
		20
	)

# ==================================================
func update_hearts_ui():
	for i in range(hearts_container.get_child_count()):
		var heart := hearts_container.get_child(i) as TextureRect
		heart.texture = heart_full if i < current_hearts else heart_empty

# ==================================================
# 📳 SCREEN SHAKE ONLY
# ==================================================
func _screen_shake():
	var tween := create_tween()
	for i in range(8):
		var offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		tween.tween_property(self, "offset", offset, 0.04)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.1)

# ==================================================
# PUBLIC API
# ==================================================
func damage(amount := 1):
	_shake_camera()   # 🎥 WORLD SHAKE
	_shake_hearts()   # ❤️ UI SHAKE

	for i in range(amount):
		if current_hearts <= 0:
			return

		current_hearts -= 1

		var heart := hearts_container.get_child(current_hearts) as TextureRect

		var tween := create_tween()

		tween.tween_property(heart, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func():
			heart.texture = heart_empty
			heart.modulate.a = 1.0
		)

	if current_hearts == 0:
		_emit_player_died()


func heal(amount := 1):
	for i in range(amount):
		if current_hearts >= max_hearts:
			return

		var heart := hearts_container.get_child(current_hearts) as TextureRect
		heart.texture = heart_full
		heart.modulate.a = 0.0

		var tween := create_tween()
		tween.tween_property(heart, "modulate:a", 1.0, 0.3)

		current_hearts += 1
		
func _shake_camera():
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake()
		



func _shake_hearts():
	if not hearts_container:
		return

	var original_pos := hearts_container.position
	var tween := create_tween()
	var strength := 6.0
	var steps := 6

	for i in range(steps):
		var offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		tween.tween_property(
			hearts_container,
			"position",
			original_pos + offset,
			0.03
		)

	tween.tween_property(hearts_container, "position", original_pos, 0.05)

func _emit_player_died():
	emit_signal("player_died")
