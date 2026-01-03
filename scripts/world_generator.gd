extends Node

# ---------------- WORLD SIZE ----------------
@export var island_size := 200
@export var water_border := 40
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
var wells_spawned := false
@export var well_count := 6

# ==================================================
# WORLD GENERATION
# ==================================================
func generate_world():
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.006
	noise.seed = randi()

	fill_ocean()
	generate_connected_island()
	add_natural_beaches()

	# Decorative land patches
	place_patches(MAGMA, 0.6, 0.015)
	place_patches(DIRT, 0.4, 0.012)
	place_patches(MUD, 0.5, 0.02)
	place_patches(CLAY, 0.55, 0.025)

	# 🔥 ORIGINAL MAGMA (UNCHANGED)

	# 🔥 NEW: scatter lava naturally around magma
	scatter_lava_near_magma()

# ==================================================
# CORE GENERATION
# ==================================================
func fill_ocean():
	for x in range(total_width):
		for y in range(total_height):
			tilemap.set_cell(Vector2i(x, y), SRC, WATER)

func generate_connected_island():
	var cx = total_width / 2.0
	var cy = total_height / 2.0
	var max_dist = island_size / 1.8

	for x in range(water_border, total_width - water_border):
		for y in range(water_border, total_height - water_border):
			var dx = (x - cx) / max_dist
			var dy = (y - cy) / max_dist
			var distance = sqrt(dx * dx + dy * dy)
			var val = noise.get_noise_2d(x, y)
			var final_val = val + (0.35 * (1.0 - distance)) - (distance * distance)

			if final_val > -0.15:
				tilemap.set_cell(Vector2i(x, y), SRC, GRASS)

func add_natural_beaches():
	for x in range(total_width):
		for y in range(total_height):
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if tilemap.get_cell_atlas_coords(pos + d) == WATER:
						tilemap.set_cell(pos, SRC, SAND)
						break

# ==================================================
# PATCH HELPER (UNCHANGED)
# ==================================================
func place_patches(tile: Vector2i, threshold: float, freq: float):
	var old_freq = noise.frequency
	noise.frequency = freq

	for x in range(total_width):
		for y in range(total_height):
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				if noise.get_noise_2d(x, y) > threshold:
					tilemap.set_cell(pos, SRC, tile)

	noise.frequency = old_freq

# ==================================================
# 🔥 SIMPLE LAVA SCATTER (NEW & SAFE)
# ==================================================
func scatter_lava_near_magma():
	var magma_positions: Array[Vector2i] = []

	# 1. Collect all magma tiles
	for x in range(3, total_width - 3):
		for y in range(3, total_height - 3):
			var pos: Vector2i = Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == MAGMA:
				magma_positions.append(pos)

	# 2. Shuffle to ensure even random spread
	magma_positions.shuffle()

	# 3. Replace up to 40 magma tiles with lava
	var lava_count: int = min(40, magma_positions.size())

	for i in range(lava_count):
		tilemap.set_cell(magma_positions[i], SRC, LAVA)

# ==================================================
# WELL SPAWNING (UNCHANGED)
# ==================================================
func spawn_wells(parent_map: Node) -> void:
	if wells_spawned or well_scene == null:
		return

	wells_spawned = true
	var placed := 0
	var attempts := 0

	while placed < well_count and attempts < 1000:
		attempts += 1
		var rx = randi_range(water_border, total_width - water_border)
		var ry = randi_range(water_border, total_height - water_border)
		var tile_pos := Vector2i(rx, ry)

		var t = tilemap.get_cell_atlas_coords(tile_pos)
		if t != WATER and t != LAVA and t != MAGMA:
			for x in range(-3, 4):
				for y in range(-3, 4):
					if x * x + y * y < 10:
						tilemap.set_cell(tile_pos + Vector2i(x, y), SRC, GRASS)

			var well = well_scene.instantiate()
			tilemap.add_child(well)
			well.position = tilemap.map_to_local(tile_pos)

			if parent_map.has_method("_on_well_interacted"):
				well.interact.connect(parent_map._on_well_interacted)

			placed += 1
