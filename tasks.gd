extends Node2D
class_name Tasks

@export var hint_pickup_scene: PackedScene
@export var spawn_radius: float = 800.0

var total_hints: int = 0
var collected_hints: int = 0

signal hint_collected
signal all_hints_collected

func spawn_hints(count: int, center: Vector2) -> void:
	if hint_pickup_scene == null:
		push_error("Tasks.spawn_hints: hint_pickup_scene is not assigned!")
		return

	total_hints = count
	collected_hints = 0

	for i in range(count):
		var pickup = hint_pickup_scene.instantiate()
		add_child(pickup)

		var offset = Vector2(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		pickup.position = center + offset

		if pickup.has_signal("collected"):
			pickup.collected.connect(_on_hint_collected)
		else:
			push_warning("Spawned hint pickup does not have 'collected' signal!")

func _on_hint_collected() -> void:
	collected_hints += 1
	emit_signal("hint_collected")

	if collected_hints >= total_hints:
		emit_signal("all_hints_collected")
