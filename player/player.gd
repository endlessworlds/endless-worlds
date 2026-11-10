extends CharacterBody2D

# ================= MOVEMENT =================
@export var speed := 200.0
@export var sprint_speed := 350.0  # 🏃 Added
@export var water_speed_multiplier := 0.6

# ================= DROWNING (PIXELS) =================
@export var sink_in_speed := 6.0
@export var sink_out_speed := 20.0
@export var max_sink_px := 10.0

# ================= COLOR TINT =================
@export var max_blue_tint := 0.5
# ================= FOOTSTEPS =================
@export var footstep_interval_walk := 0.35
@export var footstep_interval_sprint := 0.22

# ================= NODES =================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var bubble_spawner: Node2D = $WaterBubbleSpawner

@onready var camera: Camera2D = $Camera2D
@onready var footsteps: AudioStreamPlayer2D = $FootstepPlayer
@onready var footstep_timer: Timer = $FootstepTimer

@onready var foot_trail: CPUParticles2D = $FootTrail
@onready var shadow: Sprite2D = $Shadow

# ================= JUMP =================
const JUMP_TIME := 0.42
const JUMP_HEIGHT := 14.0
var jump_t := -1.0           # < 0 = on the ground
var jump_h := 0.0            # current height above ground (px, player-local)
var airborne := false        # map skips lava / water checks while true
var _squash := 0.0           # +stretch (take-off) / -squash (landing)
var _base_scale := Vector2.ONE
var _shadow_scale := Vector2.ONE
var _dust: CPUParticles2D



# ================= BUBBLES =================
@export var bubble_scene := preload("res://map_components/water_bubble.tscn")
@export var bubble_spawn_rate := 0.6
var bubble_timer := 0.0

# ================= STATE =================
var in_water := false        # deep water: swimming (set from map.gd)
var wading := false          # shallow water next to the shore (set from map.gd)
const SWIM_ACCEL := 2.4      # low acceleration = momentum / drift while swimming
const SWIM_DRAG := 1.3
var _swim_t := 0.0
var sink_px := 0.0
var base_sprite_pos := Vector2.ZERO
var last_dir := Vector2.DOWN
var current_tile_type := "Dirt" # default

# Cache answer popup reference
var answer_popup_cached = null

# ================= FOOTSTEP SOUNDS =================
var FOOTSTEP_SOUNDS := {
	"Dirt": [],
	"Gravel": [],
	"Water": []
}

# ==================================================
func _ready():
	base_sprite_pos = sprite.position-Vector2(0,10)
	sprite.modulate = Color.WHITE
	camera.zoom = Vector2.ONE
	load_footstep_sounds()
	footstep_timer.timeout.connect(play_footstep)
	_setup_jump()
	Characters.apply(sprite, Global.character)
	
	foot_trail.position = Vector2(0, 7) # near feet
	
	# Cache answer popup reference (may not exist in all scenes)
	answer_popup_cached = get_tree().root.find_child("AnswerPopup", true, false)


# ==================================================
func load_footstep_sounds():
	FOOTSTEP_SOUNDS["Dirt"] = load_folder("res://assets/audio/Dirt")
	FOOTSTEP_SOUNDS["Gravel"] = load_folder("res://assets/audio/Gravel")
	FOOTSTEP_SOUNDS["Water"] = load_folder("res://assets/audio/Water")

func load_folder(path: String) -> Array:
	var sounds := []
	# ResourceLoader sees imported files in exported builds too (DirAccess only sees .import/.remap there).
	for file in ResourceLoader.list_directory(path):
		if file.ends_with(".ogg"):
			sounds.append(load(path + "/" + file))
	return sounds

# ==================================================
func _physics_process(delta):
	# Check if answer popup is visible - if so, disable movement
	var movement_blocked = (answer_popup_cached and answer_popup_cached.visible) or Global.input_locked
	
	var dir := Vector2.ZERO
	
	# Only process input if movement is not blocked
	if not movement_blocked:
		dir = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)

	# 🏃 SPRINT LOGIC
	var sprinting := Input.is_action_pressed("sprint")
	var current_speed = sprint_speed if Input.is_action_pressed("sprint") else speed

	# 🌊 WATER LOGIC
	if in_water:
		current_speed *= water_speed_multiplier
		sink_px = min(max_sink_px, sink_px + sink_in_speed * delta)
	elif wading:
		current_speed *= 0.75
		sink_px = move_toward(sink_px, max_sink_px * 0.45, sink_in_speed * delta)
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

	# JUMP: Space / gamepad A. Arc + squash & stretch; you can hop over small lava patches.
	if not movement_blocked and jump_t < 0.0 and not in_water and Input.is_action_just_pressed("jump"):
		jump_t = 0.0
		_squash = 0.18
		stop_footsteps()
	_update_jump(delta)

	# VISUAL SINK (sprite only) + a gentle bob while swimming
	_swim_t += delta
	var bob := sin(_swim_t * 3.2) * 1.2 if in_water else 0.0
	sprite.position = base_sprite_pos + Vector2(0, sink_px - jump_h + bob)

	# MOVEMENT
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		last_dir = dir
		if in_water:
			velocity = velocity.lerp(dir * current_speed, clampf(SWIM_ACCEL * delta, 0.0, 1.0))  # strokes build up speed
		else:
			velocity = dir * current_speed
		play_animation(dir)
		if not airborne:
			start_footsteps(sprinting)
	else:
		if in_water:
			velocity = velocity.lerp(Vector2.ZERO, clampf(SWIM_DRAG * delta, 0.0, 1.0))  # glide to a stop
		else:
			velocity = Vector2.ZERO
		set_idle_frame()
		stop_footsteps()

	move_and_slide()
	
	# 🟤 Smoky walking marks
	if dir != Vector2.ZERO and not airborne:
		foot_trail.emitting = true
	else:
		foot_trail.emitting = false


	# 🔑 DEPTH SORT — MUST BE AFTER MOVE
	update_depth()

	# 🎨 WATER TINT
	apply_water_tint()

# ==================================================
# 🔊 FOOTSTEP SYSTEM
# ==================================================
func start_footsteps(sprinting: bool):
	if footstep_timer.is_stopped():
		footstep_timer.wait_time = (
			footstep_interval_sprint if sprinting else footstep_interval_walk
		)
		footstep_timer.start()

func stop_footsteps():
	if not footstep_timer.is_stopped():
		footstep_timer.stop()

func play_footstep():
	var list :Variant= FOOTSTEP_SOUNDS.get(current_tile_type, [])
	if list.is_empty():
		return
	footsteps.stream = list.pick_random()
	footsteps.pitch_scale = randf_range(0.95, 1.05)
	footsteps.play()


# ==================================================
# 🔑 FOOT-BASED DEPTH SORT (NO LAG)
# ==================================================
func update_depth():
	var rect := collider.shape as RectangleShape2D
	var feet_y: float = global_position.y + rect.extents.y
	z_index = int(feet_y/4)

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


# ==================================================
# 🦘 JUMP
# ==================================================
func _setup_jump() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_A
		InputMap.action_add_event("jump", pad)
	_base_scale = sprite.scale
	_shadow_scale = shadow.scale
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.amount = 10
	_dust.lifetime = 0.45
	_dust.local_coords = false
	_dust.position = Vector2(0, 8)
	_dust.direction = Vector2(0, -1)
	_dust.spread = 80.0
	_dust.initial_velocity_min = 12.0
	_dust.initial_velocity_max = 28.0
	_dust.gravity = Vector2(0, 30)
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.8, 0.7, 0.7))
	ramp.set_color(1, Color(0.85, 0.8, 0.7, 0.0))
	_dust.color_ramp = ramp
	_dust.z_index = -1
	add_child(_dust)


func _update_jump(delta: float) -> void:
	if jump_t >= 0.0:
		jump_t += delta
		var p := jump_t / JUMP_TIME
		if p >= 1.0:
			jump_t = -1.0
			jump_h = 0.0
			_squash = -0.22  # landing squash
			_dust.restart()
			_dust.emitting = true
		else:
			jump_h = sin(p * PI) * JUMP_HEIGHT
	airborne = jump_t >= 0.0
	_squash = move_toward(_squash, 0.0, delta * 1.4)
	sprite.scale = _base_scale * Vector2(1.0 - _squash, 1.0 + _squash)
	var k := 1.0 - (jump_h / JUMP_HEIGHT) * 0.45
	shadow.scale = _shadow_scale * k
	shadow.modulate.a = 0.3 * k
