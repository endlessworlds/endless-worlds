extends Node2D

@onready var world := $WorldGenerator
@onready var time := $TimeSystem
@onready var rain := $RainController
@onready var lighting := $LightingSystem
@onready var spawner := $PlayerSpawner

@onready var player := $Player
@onready var player_shape: CollisionShape2D = $Player/CollisionShape2D
@onready var tilemap : TileMapLayer = $TileMap

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
var tile_info_label : Label


# GAME CONFIGS OR GLOBAL VARIABLES
@export var enable_rain := true  
@export var TILE_SOURCE_ID := 0
func _ready():
	# passes the arguments function
	rain.rain_enabled = enable_rain
	world.SRC = TILE_SOURCE_ID
	
	
	
	world.generate()
	lighting.spawn_lava_lights()
	time.init_time()
	spawner.spawn_on_nearest_grass()
	
	create_tile_info_ui()

func _process(_delta):
	update_player_tile_info()

	
	
func create_tile_info_ui():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	tile_info_label = Label.new()
	canvas.add_child(tile_info_label)

	tile_info_label.anchor_left = 1
	tile_info_label.anchor_top = 0
	tile_info_label.anchor_right = 1
	tile_info_label.anchor_bottom = 0

	tile_info_label.offset_left = -200
	tile_info_label.offset_top = 20
	tile_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tile_info_label.add_theme_font_size_override("font_size", 16)

func update_player_tile_info():
	if not player_shape or not player_shape.shape:
		return

	# Get collision shape center in GLOBAL space
	var shape_center := player_shape.global_position

	# Convert global → tilemap local → map cell
	var cell := tilemap.local_to_map(
		tilemap.to_local(shape_center)
	)

	var atlas := tilemap.get_cell_atlas_coords(cell)
	player.in_water = (atlas == Vector2i(3, 1)) # WATER


	if TILE_NAMES.has(atlas):
		tile_info_label.text = "Tile: " + TILE_NAMES[atlas]
	else:
		tile_info_label.text = "Tile: Unknown"
