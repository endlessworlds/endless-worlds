#Call `hearts.damage(amount)` to reduce health and `hearts.heal(amount)` to restore it.

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
# PUBLIC API
# ==================================================
func damage(amount := 1):
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


func _emit_player_died():
	emit_signal("player_died")
