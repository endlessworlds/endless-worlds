extends Node2D

@onready var world := $WorldGenerator
@onready var time := $TimeSystem
@onready var rain := $RainController
@onready var lighting := $LightingSystem
@onready var spawner := $PlayerSpawner

@onready var player := $Player
@onready var player_shape: CollisionShape2D = $Player/CollisionShape2D
@onready var tilemap : TileMapLayer = $TileMap

# ================= UI LAYER =================
var ui_layer: CanvasLayer

# ================= HEALTH / HEART SYSTEM =================
@export var max_hearts := 5
var current_hearts := 5

var hearts_container: HBoxContainer
var heart_full: Texture2D
var heart_empty: Texture2D

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
var tile_info_label: Label

# ================= CONFIG =================
@export var enable_rain := true  
@export var TILE_SOURCE_ID := 0

# ==================================================
# READY
# ==================================================
func _ready():
	rain.rain_enabled = enable_rain
	world.SRC = TILE_SOURCE_ID

	world.generate()
	lighting.spawn_lava_lights()
	time.init_time()
	spawner.spawn_on_nearest_grass()

	# ✅ ONE CanvasLayer ONLY
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	create_tile_info_ui()
	create_hearts_ui()

# ==================================================
# PROCESS
# ==================================================
func _process(_delta):
	update_player_tile_info()

# ==================================================
# TILE INFO UI
# ==================================================
func create_tile_info_ui():
	tile_info_label = Label.new()
	ui_layer.add_child(tile_info_label)

	tile_info_label.position = Vector2(
		get_viewport_rect().size.x - 200,
		20
	)

	tile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tile_info_label.add_theme_font_size_override("font_size", 16)

func update_player_tile_info():
	if not player_shape:
		return

	var shape_center := player_shape.global_position

	var cell := tilemap.local_to_map(
		tilemap.to_local(shape_center)
	)

	var atlas := tilemap.get_cell_atlas_coords(cell)
	player.in_water = (atlas == Vector2i(3, 1))

	if TILE_NAMES.has(atlas):
		tile_info_label.text = "Tile: " + TILE_NAMES[atlas]
	else:
		tile_info_label.text = "Tile: Unknown"

# ==================================================
# HEARTS UI
# ==================================================
func create_hearts_ui():
	hearts_container = HBoxContainer.new()
	ui_layer.add_child(hearts_container)

	# ✅ Manual positioning (reliable)
	hearts_container.position = Vector2(
		get_viewport_rect().size.x - (max_hearts * 28),
		50
	)

	hearts_container.add_theme_constant_override("separation", 4)

	heart_full = load("res://assets/ui/heart_full.png")
	heart_empty = load("res://assets/ui/heart_empty.png")

	for i in range(max_hearts):
		var heart := TextureRect.new()
		heart.texture = heart_full
		heart.custom_minimum_size = Vector2(24, 24)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		hearts_container.add_child(heart)

	update_hearts_ui()

func update_hearts_ui():
	for i in range(hearts_container.get_child_count()):
		var heart := hearts_container.get_child(i) as TextureRect
		heart.texture = heart_full if i < current_hearts else heart_empty

# ==================================================
# DAMAGE / HEAL
# ==================================================
func damage(amount := 1):
	current_hearts = clamp(current_hearts - amount, 0, max_hearts)
	update_hearts_ui()

	if current_hearts == 0:
		player_died()

func heal(amount := 1):
	current_hearts = clamp(current_hearts + amount, 0, max_hearts)
	update_hearts_ui()

func player_died():
	print("Player died!")
