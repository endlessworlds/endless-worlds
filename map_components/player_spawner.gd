extends Node

@onready var tilemap: TileMapLayer = $"../TileMap"
@onready var player: CharacterBody2D = $"../Player"

# Matches your 280x280 total area
@onready var total_width = 280 
@onready var total_height = 280

const SRC = 0
const GRASS = Vector2i(0, 0)
const DIRT = Vector2i(1, 0)

func spawn_player_at_center():
	# 1. Target the exact center coordinate requested
	var center_tile = Vector2i(280, 280)
	
	# 2. Safety: Force a small landing pad of land at the center
	# This ensures the player never spawns in water/lava
	for x in range(-2, 3):
		for y in range(-2, 3):
			var p = center_tile + Vector2i(x, y)
			# Create a mix of Grass and Dirt for a natural look
			var tile_type = GRASS if randf() > 0.2 else DIRT
			tilemap.set_cell(p, maxi(tilemap.get_cell_source_id(p), 0), tile_type)  # keep the biome tileset
	# Never start next to lava/magma/water: clear a wider safe circle of hazards.
	const HAZARDS := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	for x in range(-7, 8):
		for y in range(-7, 8):
			var p = center_tile + Vector2i(x, y)
			if x * x + y * y <= 49 and tilemap.get_cell_atlas_coords(p) in HAZARDS:
				tilemap.set_cell(p, tilemap.get_cell_source_id(p), GRASS)

	# 3. Teleport player
	# map_to_local centers the player exactly in the middle of tile 140,140
	player.global_position = tilemap.map_to_local(center_tile)
	
	# 4. Camera Fix
	# Prevents the camera from "sliding" from (0,0) to the center on start
	if player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		cam.reset_smoothing() 
		cam.force_update_scroll()
