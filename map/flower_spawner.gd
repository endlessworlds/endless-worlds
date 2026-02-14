extends Node

# ---------------- WORLD SIZE ----------------
@export var width: int = 200
@export var height: int = 200

@onready var tilemap: TileMapLayer = $"../TileMap"

# ---------------- SETTINGS ----------------
const GRASS: Vector2i = Vector2i(0, 0)
const TOTAL_FLOWERS: int = 100
const FLOWER_TYPES: int = 10

# Preload all flower textures for web export reliability
const FLOWER_TEXTURES = [
	preload("res://assets/flowers/flower_dandelion.png"),
	preload("res://assets/flowers/flower_cornflower.png"),
	preload("res://assets/flowers/flower_blue_orchid.png"),
	preload("res://assets/flowers/flower_allium.png"),
	preload("res://assets/flowers/firefly_bush.png"),
	preload("res://assets/flowers/eyeblossom_blooming.png"),
	preload("res://assets/flowers/double_plant_rose_bottom.png"),
	preload("res://assets/flowers/double_plant_paeonia_top.png"),
	preload("res://assets/flowers/double_plant_paeonia_bottom.png"),
	preload("res://assets/flowers/double_plant_grass_carried.png"),
	preload("res://assets/flowers/deadbush.png"),
	preload("res://assets/flowers/crimson_fungus.png"),
	preload("res://assets/flowers/coral_fan_red.png"),
	preload("res://assets/flowers/cherry_sapling.png"),
	preload("res://assets/flowers/torchflower.png"),
	preload("res://assets/flowers/tall_dry_grass.png"),
	preload("res://assets/flowers/sweet_berry_bush_stage3.png"),
	preload("res://assets/flowers/flower_wither_rose.png"),
	preload("res://assets/flowers/flower_tulip_white.png"),
	preload("res://assets/flowers/flower_tulip_red.png"),
	preload("res://assets/flowers/flower_tulip_pink.png"),
	preload("res://assets/flowers/flower_tulip_orange.png"),
	preload("res://assets/flowers/flower_rose_blue.png"),
	preload("res://assets/flowers/flower_rose.png"),
	preload("res://assets/flowers/flower_paeonia.png"),
	preload("res://assets/flowers/flower_oxeye_daisy.png"),
	preload("res://assets/flowers/flower_lily_of_the_valley.png"),
	preload("res://assets/flowers/flower_houstonia.png")
]

# ==================================================
# FLOWER SPAWNER
# ==================================================
func spawn_flowers() -> void:
	var grass_positions: Array[Vector2i] = []
	
	for x: int in range(width):
		for y: int in range(height):
			var pos: Vector2i = Vector2i(x, y)

			if tilemap.get_cell_source_id(pos) == -1:
				continue

			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				grass_positions.append(pos)
	
	if grass_positions.is_empty():
		push_error("❌ No grass tiles found for flowers")
		return
	
	grass_positions.shuffle()
	
	if FLOWER_TEXTURES.size() == 0:
		push_error("❌ No flower textures found")
		return
	
	var flower_textures = FLOWER_TEXTURES.duplicate()
	flower_textures.shuffle()
	flower_textures = flower_textures.slice(0, min(FLOWER_TYPES, flower_textures.size()))
	
	var count: int = min(TOTAL_FLOWERS, grass_positions.size())
	
	for i: int in range(count):
		var cell: Vector2i = grass_positions[i]
		var tex: Texture2D = flower_textures.pick_random()
		
		var flower: Sprite2D = Sprite2D.new()
		flower.texture = tex
		
		var tile_local: Vector2 = tilemap.map_to_local(cell)
		flower.global_position = tilemap.to_global(tile_local)
		flower.scale = Vector2(2.0, 2.0)
		flower.rotation = randf_range(-0.1, 0.1)
		flower.z_index = int(flower.global_position.y / 4.0)
		
		add_child(flower)
	
	print("✅ Spawned ", count, " flowers")
