extends Node

# ---------------- WORLD SIZE ----------------
@export var width := 200
@export var height := 200

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
	Vector2i(50, 80),
	Vector2i(50, 120)
]
var wells_spawned: bool = false

# ==================================================
# WORLD GENERATION
# ==================================================
func generate_world():
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.seed = randi()

	fill_water()
	generate_island()
	add_sand_edges()
	place_patches(DIRT, 0.3, 0.015)
	place_patches(MAGMA, 0.45, 0.02)
	place_patches(WATER, 0.4, 0.018)
	place_patches(MUD, 0.55, 0.025)
	place_patches(CLAY, 0.6, 0.028)

# ==================================================
# WELL LOGIC
# ==================================================
func spawn_wells(parent_map: Node) -> void:
	if wells_spawned:
		return

	if well_scene == null:
		push_error("❌ Well scene not assigned in WorldGenerator!")
		return

	wells_spawned = true

	for tile_pos in WELL_TILES:
		# Ensure ground is walkable under well
		place_grass_under_well(tile_pos)

		var local_pos: Vector2 = tilemap.map_to_local(tile_pos)
		var world_pos: Vector2 = tilemap.to_global(local_pos)

		var well: Well = well_scene.instantiate()
		well.position = world_pos
		parent_map.add_child(well)

		# Connect well interaction to Map.gd's function
		if parent_map.has_method("_on_well_interacted"):
			well.interact.connect(parent_map._on_well_interacted)

# 5x5 grass patch helper
func place_grass_under_well(center: Vector2i) -> void:
	for x in range(-2, 3):
		for y in range(-2, 3):
			tilemap.set_cell(center + Vector2i(x, y), SRC, GRASS)

# ==================================================
# TERRAIN HELPERS
# ==================================================
func fill_water():
	for x in width:
		for y in height:
			tilemap.set_cell(Vector2i(x, y), SRC, WATER)

func generate_island():
	for x in width:
		for y in height:
			if noise.get_noise_2d(x, y) > -0.1:
				tilemap.set_cell(Vector2i(x, y), SRC, GRASS)

func add_sand_edges():
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if tilemap.get_cell_atlas_coords(pos + d) == WATER:
						tilemap.set_cell(pos, SRC, SAND)
						break

func place_patches(tile: Vector2i, threshold: float, freq: float):
	var old := noise.frequency
	noise.frequency = freq
	for x in width:
		for y in height:
			if noise.get_noise_2d(x, y) > threshold:
				var pos := Vector2i(x, y)
				if tilemap.get_cell_atlas_coords(pos) == GRASS:
					tilemap.set_cell(pos, SRC, tile)
	noise.frequency = old
