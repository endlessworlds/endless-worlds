extends Node2D

@onready var world := $WorldGenerator
@onready var time := $TimeSystem
@onready var rain := $RainController
@onready var lighting := $LightingSystem
@onready var spawner := $PlayerSpawner

@onready var player := $Player
@onready var player_shape: CollisionShape2D = $Player/CollisionShape2D
@onready var tilemap: TileMapLayer = $TileMap
@onready var hearts: HeartSystem = $HeartSystem

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
const TILE_DAMAGE_INTERVAL := 2.5
var can_take_tile_damage := true
var tile_damage_timer: Timer

# ==================================================
func _ready():
	world.generate()
	lighting.spawn_lava_lights()
	time.init_time()
	spawner.spawn_on_nearest_grass()

	create_tile_info_ui()
	create_bubble_ui()
	create_bubble_timer()
	create_tile_damage_timer()

# ==================================================
func _process(_delta):
	update_player_tile_info()

# ==================================================
# TILE INFO UI
# ==================================================
func create_tile_info_ui():
	var ui := CanvasLayer.new()
	add_child(ui)

	tile_info_label = Label.new()
	ui.add_child(tile_info_label)

	tile_info_label.position = Vector2(
		get_viewport().get_visible_rect().size.x - 200,
		60
	)

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
	bubble_timer.wait_time = 1.0
	bubble_timer.autostart = false
	bubble_timer.timeout.connect(_on_bubble_tick)
	add_child(bubble_timer)

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
	bubbles_left = MAX_BUBBLES
	bubble_container.visible = true
	update_bubbles()
	bubble_timer.start()

func exit_water():
	in_water = false
	bubble_timer.stop()
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
	else:
		# drowning damage (already timed)
		hearts.damage(1)

func update_bubbles():
	for i in range(bubble_container.get_child_count()):
		bubble_container.get_child(i).visible = i < bubbles_left

# ==================================================
# TEST INPUT
# ==================================================
func _input(event):
	if event.is_action_pressed("ui_accept"):
		hearts.damage(1)
	if event.is_action_pressed("ui_cancel"):
		hearts.heal(1)
