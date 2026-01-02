extends Node

# ---------------- WORLD SIZE ----------------
@export var island_size := 200
@export var water_border := 40
# Total area is 280x280
@onready var total_width := island_size + (water_border * 2)
@onready var total_height := island_size + (water_border * 2)

# ---------------- TILE REFERENCES ----------------
@onready var tilemap: TileMapLayer = $"../TileMap"
@onready var noise := FastNoiseLite.new()

# ---------------- EXTERNAL SCENES ----------------
@export var well_scene: PackedScene

# ---------------- TILE ATLAS ----------------
var SRC: int = 0
const GRASS = Vector2i(0, 0)
const DIRT  = Vector2i(1, 0)
const CLAY  = Vector2i(2, 0)
const MUD   = Vector2i(3, 0)
const SAND  = Vector2i(0, 1)
const LAVA  = Vector2i(1, 1)
const MAGMA = Vector2i(2, 1)
const WATER = Vector2i(3, 1)

# ---------------- WELL SETTINGS ----------------
const WELL_TILES: Array[Vector2i] = [
	Vector2i(80, 80), 
	Vector2i(120, 120) 
]
var wells_spawned: bool = false

# ==================================================
# WORLD GENERATION
# ==================================================
func generate_world():
	# Lower frequency (0.006) creates larger, connected landmasses
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.006 
	noise.seed = randi()

	fill_ocean()
	generate_connected_island()
	add_natural_beaches()
	
	# Place decorative patches only on Grass
	place_patches(DIRT, 0.4, 0.012)
	place_patches(MUD, 0.5, 0.02)
	place_patches(CLAY, 0.55, 0.025)
	
	# Place hazards/water inside the island
	place_patches(WATER, 0.6, 0.015) 
	place_patches(MAGMA, 0.65, 0.02)

# ==================================================
# CORE GENERATION LOGIC
# ==================================================

func fill_ocean():
	for x in range(total_width):
		for y in range(total_height):
			tilemap.set_cell(Vector2i(x, y), SRC, WATER)

func generate_connected_island():
	var center_x = total_width / 2.0
	var center_y = total_height / 2.0
	var max_dist = island_size / 1.8 

	for x in range(water_border, total_width - water_border):
		for y in range(water_border, total_height - water_border):
			var pos = Vector2i(x, y)
			
			# Distance math (0.0 at center, 1.0 at edges)
			var dist_x = (x - center_x) / max_dist
			var dist_y = (y - center_y) / max_dist
			var distance = sqrt(dist_x*dist_x + dist_y*dist_y)
			
			var noise_val = noise.get_noise_2d(x, y)
			
			# CONNECTION FORMULA:
			# We use a gentler falloff (distance^2) so the island stays chunky.
			# If distance is very low (near center), we boost the land chance 
			# to ensure a central walkable "spine".
			var land_threshold = 0.1
			var final_val = noise_val + (0.35 * (1.0 - distance)) - (distance * distance)
			
			if final_val > -0.15:
				tilemap.set_cell(pos, SRC, GRASS)

func add_natural_beaches():
	# Makes beaches look thicker and more cohesive
	for x in range(total_width):
		for y in range(total_height):
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				var neighbor_water = false
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if tilemap.get_cell_atlas_coords(pos + d) == WATER:
						neighbor_water = true
						break
				
				if neighbor_water:
					tilemap.set_cell(pos, SRC, SAND)
					# Small chance to expand sand to make it look less like a "line"
					if randf() > 0.5:
						for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
							if tilemap.get_cell_atlas_coords(pos+d) == GRASS:
								tilemap.set_cell(pos+d, SRC, SAND)

func place_patches(tile: Vector2i, threshold: float, freq: float):
	var old_freq = noise.frequency
	noise.frequency = freq
	for x in range(total_width):
		for y in range(total_height):
			var pos := Vector2i(x, y)
			# Decorative patches only spawn on land (Grass/Dirt/Sand)
			var current_tile = tilemap.get_cell_atlas_coords(pos)
			if current_tile == GRASS:
				if noise.get_noise_2d(x, y) > threshold:
					tilemap.set_cell(pos, SRC, tile)
	noise.frequency = old_freq

# ==================================================
# WELL SPAWNING
# ==================================================
# ---------------- WELL SETTINGS ----------------
@export var well_count: int = 6 # Set to 6


func spawn_wells(parent_map: Node) -> void:
	if wells_spawned or well_scene == null: return
	wells_spawned = true

	var placed_count = 0
	var attempts = 0
	var max_attempts = 1000 # Prevent infinite loops if island is too small

	while placed_count < well_count and attempts < max_attempts:
		attempts += 1
		
		# Pick a random spot within the island bounds (avoiding the water border)
		var rx = randi_range(water_border, total_width - water_border)
		var ry = randi_range(water_border, total_height - water_border)
		var tile_pos = Vector2i(rx, ry)
		
		# Check if the tile is a valid land tile (Grass, Dirt, Mud, etc.)
		# We want to avoid placing wells directly in Water, Lava, or Magma
		var current_tile = tilemap.get_cell_atlas_coords(tile_pos)
		if current_tile != WATER and current_tile != LAVA and current_tile != MAGMA:
			
			# 1. Clear a circular land patch for the well so it looks built-in
			for x in range(-3, 4):
				for y in range(-3, 4):
					var p = tile_pos + Vector2i(x, y)
					# Check bounds and distance for a small circle
					if (x*x + y*y) < 10: 
						tilemap.set_cell(p, SRC, GRASS if randf() > 0.3 else DIRT)

			# 2. Instantiate and place the well
			var well = well_scene.instantiate()
			well.add_to_group("world_lighting")
			tilemap.add_child(well)
			
			# map_to_local centers the object on the tile
			well.position = tilemap.map_to_local(tile_pos)

			# 3. Connect signals
			if parent_map.has_method("_on_well_interacted"):
				well.interact.connect(parent_map._on_well_interacted)
			
			placed_count += 1
