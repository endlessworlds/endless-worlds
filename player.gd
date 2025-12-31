extends CharacterBody2D

# ================= MOVEMENT =================
@export var speed := 200.0
@export var water_speed_multiplier := 0.6

# ================= DROWNING (PIXELS) =================
@export var sink_in_speed := 6.0
@export var sink_out_speed := 20.0
@export var max_sink_px := 10.0

# ================= COLOR TINT =================
@export var max_blue_tint := 0.5

# ================= NODES =================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var bubble_spawner: Node2D = $WaterBubbleSpawner

# ================= BUBBLES =================
@export var bubble_scene := preload("res://WaterBubble.tscn")
@export var bubble_spawn_rate := 0.6
var bubble_timer := 0.0

# ================= STATE =================
var in_water := false        # SET FROM map.gd
var sink_px := 0.0
var base_sprite_pos := Vector2.ZERO
var last_dir := Vector2.DOWN

# ==================================================
func _ready():
	base_sprite_pos = sprite.position-Vector2(0,10)
	sprite.modulate = Color.WHITE

# ==================================================
func _physics_process(delta):
	var dir := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)

	var current_speed := speed

	# 🌊 WATER LOGIC
	if in_water:
		current_speed *= water_speed_multiplier
		sink_px = min(max_sink_px, sink_px + sink_in_speed * delta)
	else:
		sink_px = max(0.0, sink_px - sink_out_speed * delta)

	# 🫧 WATER BUBBLES
	if in_water:
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			spawn_water_bubble()
			bubble_timer = bubble_spawn_rate
	else:
		bubble_timer = 0.0

	# VISUAL SINK (sprite only)
	sprite.position = base_sprite_pos + Vector2(0, sink_px)

	# MOVEMENT
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		last_dir = dir
		velocity = dir * current_speed
		play_animation(dir)
	else:
		velocity = Vector2.ZERO
		set_idle_frame()

	move_and_slide()

	# 🔑 DEPTH SORT — MUST BE AFTER MOVE
	update_depth()

	# 🎨 WATER TINT
	apply_water_tint()

# ==================================================
# 🔑 FOOT-BASED DEPTH SORT (NO LAG)
# ==================================================
func update_depth():
	var rect := collider.shape as RectangleShape2D
	var feet_y: float = global_position.y + rect.extents.y
	z_index = int(feet_y/4)

	# 🧪 DEBUG (uncomment if needed)
	print("PLAYER feet_y:", feet_y, "z:", z_index)

# ==================================================
# 🎨 WATER TINT
# ==================================================
func apply_water_tint():
	if max_sink_px <= 0.0:
		sprite.modulate = Color.WHITE
		return

	var t: float = sink_px / max_sink_px

	sprite.modulate = Color(
		1.0 - t * max_blue_tint,
		1.0 - t * max_blue_tint,
		1.0,
		1.0
	)

# ==================================================
# 🎞 ANIMATION
# ==================================================
func play_animation(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		sprite.play("walk_right" if dir.x > 0 else "walk_left")
	else:
		sprite.play("walk_down" if dir.y > 0 else "walk_up")

func set_idle_frame():
	sprite.stop()

	if abs(last_dir.x) > abs(last_dir.y):
		sprite.animation = "walk_right" if last_dir.x > 0 else "walk_left"
	else:
		sprite.animation = "walk_down" if last_dir.y > 0 else "walk_up"

	sprite.frame = 1

# ==================================================
# 🫧 BUBBLE SPAWN
# ==================================================
func spawn_water_bubble():
	var bubble := bubble_scene.instantiate()
	get_parent().add_child(bubble)

	var offset := Vector2(
		randf_range(-6, 6),
		-12 + randf_range(-4, 2)
	)

	bubble.global_position = bubble_spawner.global_position + offset
