extends Node2D

@onready var world := $WorldGenerator
@onready var time := $TimeSystem
@onready var rain := $RainController
@onready var lighting := $LightingSystem
@onready var spawner := $PlayerSpawner
@onready var flower_spawner := $FlowerSpawner

@onready var player := $Player
@onready var player_shape: CollisionShape2D = $Player/CollisionShape2D
@onready var tilemap: TileMapLayer = $TileMap
@onready var hearts: HeartSystem = $HeartSystem

var score_label: Label
var death_overlay: CanvasLayer
var death_label: Label
var death_bg: ColorRect

# ================= TILE INFO =================
const TILE_NAMES := {
	Vector2i(0, 0): "Grass",
	Vector2i(1, 0): "Dirt",
	Vector2i(2, 0): "Clay",
	Vector2i(3, 0): "Mud",
	Vector2i(0, 1): "Sand",
	Vector2i(1, 1): "Lava",
	Vector2i(2, 1): "Magma",
	Vector2i(3, 1): "Water",
}

const WATER_TILE := Vector2i(3, 1)
const LAVA_TILE := Vector2i(1, 1)
const MAGMA_TILE := Vector2i(2, 1)

var tile_info_label: Label

# ================= WATER BREATHING =================
const MAX_BUBBLES := 5
var bubbles_left := MAX_BUBBLES
var in_water := false

var bubble_container: HBoxContainer
var bubble_timer: Timer

# ================= TILE DAMAGE COOLDOWN =================
var drown_damage_timer: Timer

const DAMAGE_INTERVAL := 2.0
const TILE_DAMAGE_INTERVAL := DAMAGE_INTERVAL
var can_take_tile_damage := true
var tile_damage_timer: Timer

# ==================================================
func _ready():
	world.generate()
	flower_spawner.spawn_flowers()
	lighting.spawn_lava_lights()
	time.init_time()
	spawner.spawn_on_nearest_grass()
	

	create_tile_info_ui()
	create_bubble_ui()
	create_bubble_timer()
	create_drown_damage_timer()
	create_tile_damage_timer()
	create_score_ui()


	hearts.connect("player_died", _on_player_died)
	create_death_overlay()



# ==================================================
func _process(_delta):
	update_player_tile_info()
	update_score_label()

# ==================================================
# TILE INFO UI
# ==================================================
func create_tile_info_ui():
	var ui := CanvasLayer.new()
	add_child(ui)

	tile_info_label = Label.new()
	ui.add_child(tile_info_label)

	# anchor bottom-left
	tile_info_label.anchor_left = 0
	tile_info_label.anchor_top = 1
	tile_info_label.anchor_right = 0
	tile_info_label.anchor_bottom = 1

	# give it size + offset
	tile_info_label.offset_left = 20
	tile_info_label.offset_top = -40
	tile_info_label.offset_right = 200
	tile_info_label.offset_bottom = -20

	tile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile_info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# debug safety (optional)
	tile_info_label.text = "Tile: Grass"



# ==================================================
# WATER BUBBLES UI
# ==================================================
func create_bubble_ui():
	bubble_container = HBoxContainer.new()
	hearts.add_child(bubble_container) # attach to HeartSystem CanvasLayer

	bubble_container.visible = false
	bubble_container.add_theme_constant_override("separation", 6)

	for i in range(MAX_BUBBLES):
		var bubble := TextureRect.new()
		bubble.texture = preload("res://assets/ui/bubble.png")
		bubble.custom_minimum_size = Vector2(40,40)
		bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		bubble_container.add_child(bubble)

	await get_tree().process_frame
	position_bubbles()

func position_bubbles():
	var hearts_container: HBoxContainer = hearts.hearts_container
	if hearts_container == null:
		return

	bubble_container.position = hearts_container.position + Vector2(
		0,
		hearts.heart_size + 8
	)

# ==================================================
# BUBBLE TIMER
# ==================================================
func create_bubble_timer():
	bubble_timer = Timer.new()
	bubble_timer.wait_time = 1.0   # bubbles drop every 1 sec
	bubble_timer.autostart = false
	bubble_timer.timeout.connect(_on_bubble_tick)
	add_child(bubble_timer)


func create_drown_damage_timer():
	drown_damage_timer = Timer.new()
	drown_damage_timer.wait_time = DAMAGE_INTERVAL # 2 seconds
	drown_damage_timer.autostart = false
	drown_damage_timer.timeout.connect(func():
		if in_water and bubbles_left <= 0:
			hearts.damage(1)
	)
	add_child(drown_damage_timer)


# ==================================================
# TILE DAMAGE TIMER
# ==================================================
func create_tile_damage_timer():
	tile_damage_timer = Timer.new()
	tile_damage_timer.wait_time = TILE_DAMAGE_INTERVAL
	tile_damage_timer.one_shot = true
	tile_damage_timer.timeout.connect(func():
		can_take_tile_damage = true
	)
	add_child(tile_damage_timer)

# ==================================================
# TILE CHECKING
# ==================================================
func update_player_tile_info():
	var cell := tilemap.local_to_map(
		tilemap.to_local(player_shape.global_position)
	)

	var atlas := tilemap.get_cell_atlas_coords(cell)
	tile_info_label.text = "Tile: " + TILE_NAMES.get(atlas, "Unknown")

	# ---- WATER LOGIC ----
	if atlas == WATER_TILE:
		if not in_water:
			enter_water()
	else:
		if in_water:
			exit_water()

	# ---- LAVA / MAGMA DAMAGE ----
	if atlas == LAVA_TILE or atlas == MAGMA_TILE:
		if can_take_tile_damage:
			hearts.damage(1)
			can_take_tile_damage = false
			tile_damage_timer.start()

# ==================================================
# WATER STATE
# ==================================================
func enter_water():
	in_water = true
	player.in_water = true
	bubbles_left = MAX_BUBBLES
	bubble_container.visible = true
	update_bubbles()
	bubble_timer.start()


func exit_water():
	in_water = false
	player.in_water = false
	bubble_timer.stop()
	drown_damage_timer.stop()
	bubble_container.visible = false
	bubbles_left = MAX_BUBBLES


# ==================================================
# BUBBLE TICK
# ==================================================
func _on_bubble_tick():
	if not in_water:
		return

	if bubbles_left > 0:
		bubbles_left -= 1
		update_bubbles()

		# start drowning once bubbles end
		if bubbles_left == 0:
			drown_damage_timer.start()


func update_bubbles():
	for i in range(bubble_container.get_child_count()):
		var bubble := bubble_container.get_child(i) as TextureRect

		if i < bubbles_left:
			# bubble should be visible
			if not bubble.visible:
				bubble.visible = true
				bubble.modulate.a = 0.0

				var tween := create_tween()
				tween.tween_property(bubble, "modulate:a", 1.0, 0.3)
		else:
			# bubble should disappear
			if bubble.visible:
				var tween := create_tween()
				tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
				tween.tween_callback(func():
					bubble.visible = false
				)

func create_score_ui():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	score_label = Label.new()
	canvas.add_child(score_label)

	# Load font
	var font: FontFile = load("res://Jersey10-Regular.ttf")


	# Apply font
	score_label.add_theme_font_override("font", font)
	score_label.add_theme_font_size_override("font_size", 40)
	score_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	score_label.position = Vector2(20, 20)
	score_label.text = "Score: %d" % Global.score


func update_score_label():
	if score_label:
		score_label.text = "Score: %d" % Global.score

func add_score(amount: int):
	Global.add_score(amount)
	update_score_label()

func _on_player_died():
	var messages = [
		"💙 You tried your best!",
		"🌊 The world was tough today!",
		"🔥 Nice run, adventurer!",
		"✨ You'll do even better next time!"
	]

	death_label.text = "%s\nScore: %d" % [
		messages.pick_random(),
		Global.score
	]

	death_overlay.visible = true

	# reset alpha
	death_bg.modulate.a = 0.0
	death_label.modulate.a = 0.0

	# fade in overlay
	var tween := create_tween()
	tween.tween_property(death_bg, "modulate:a", 0.65, 0.4)
	tween.parallel().tween_property(death_label, "modulate:a", 1.0, 0.4)

	# wait 2 seconds (scene NOT paused)
	await get_tree().create_timer(5.0).timeout

	get_tree().change_scene_to_file("res://HomeScreen.tscn")


func create_death_overlay():
	death_overlay = CanvasLayer.new()
	add_child(death_overlay)

	# Capture screen
	var backbuffer := BackBufferCopy.new()
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	death_overlay.add_child(backbuffer)

	# Blur layer
	death_bg = ColorRect.new()
	death_bg.anchor_left = 0
	death_bg.anchor_top = 0
	death_bg.anchor_right = 1
	death_bg.anchor_bottom = 1

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/screen_blur.gdshader")
	mat.set_shader_parameter("blur_strength", 3.0)
	death_bg.material = mat

	death_overlay.add_child(death_bg)

	# Message label
	death_label = Label.new()
	death_label.anchor_left = 0.5
	death_label.anchor_top = 0.5
	death_label.anchor_right = 0.5
	death_label.anchor_bottom = 0.5
	death_label.offset_left = -300
	death_label.offset_top = -60
	death_label.offset_right = 300
	death_label.offset_bottom = 60
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_override("font", load("res://Jersey10-Regular.ttf"))
	death_label.add_theme_font_size_override("font_size", 60)
	death_label.modulate.a = 0.0

	death_overlay.add_child(death_label)
	death_overlay.visible = false


# ==================================================
# TEST INPUT
# ==================================================
func _input(event):
	if event.is_action_pressed("ui_accept"):
		add_score(10)
	if event.is_action_pressed("ui_cancel"):
		add_score(-10)
