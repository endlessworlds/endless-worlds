extends CharacterBody2D
@onready var bubbles := $BubbleParticles

@export var speed := 200.0
@export var water_speed_multiplier := 0.6

# DROWNING (PIXELS)
@export var sink_in_speed := 6.0      # slow descent
@export var sink_out_speed := 20.0    # fast recovery
@export var max_sink_px := 10.0       # small sink distance

# COLOR TINT
@export var max_blue_tint := 0.5      # 0–1 (how blue at max sink)

@onready var sprite := $AnimatedSprite2D

var in_water := false        # SET FROM map.gd
var sink_px := 0.0
var base_sprite_pos := Vector2.ZERO
var last_dir := Vector2.DOWN

func _ready():
	base_sprite_pos = sprite.position
	sprite.modulate = Color.WHITE
	bubbles.emitting = false

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

	# VISUAL SINK (POSITION ONLY)
	sprite.position = base_sprite_pos + Vector2(0, sink_px)

	# VISUAL BLUE TINT (NO OVERLAY)
	apply_water_tint()

	# MOVEMENT + ANIMATION
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		last_dir = dir
		velocity = dir * current_speed
		play_animation(dir)
	else:
		velocity = Vector2.ZERO
		set_idle_frame()

	move_and_slide()
	update_bubbles()


# ---------------- WATER TINT ----------------
func apply_water_tint():
	if max_sink_px <= 0.0:
		sprite.modulate = Color.WHITE
		return

	var t: float = sink_px / max_sink_px   # 0 → 1

	# Blend from white → blue
	sprite.modulate = Color(
		1.0 - t * max_blue_tint,  # red down
		1.0 - t * max_blue_tint,  # green down
		1.0,                      # blue stays
		1.0
	)

# ---------------- ANIMATION ----------------
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


func update_bubbles():
	if in_water and sink_px > 2.0:
		bubbles.emitting = true

		# More bubbles as sink increases
		bubbles.amount = int(10 + (sink_px / max_sink_px) * 20)

		# Keep bubbles at feet
		bubbles.position = sprite.position + Vector2(0, max_sink_px)
	else:
		bubbles.emitting = false
