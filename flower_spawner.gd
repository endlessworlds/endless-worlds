extends Node

# ---------------- WORLD SIZE ----------------
@export var width: int = 200
@export var height: int = 200

@onready var tilemap: TileMapLayer = $"../TileMap"

# ---------------- SETTINGS ----------------
const GRASS: Vector2i = Vector2i(0, 0)
const TOTAL_FLOWERS: int = 100
const FLOWER_TYPES: int = 10
const FLOWER_PATH: String = "res://assets/flowers/"

# ==================================================
# FLOWER SPAWNER
# ==================================================
func spawn_flowers() -> void:
	var grass_positions: Array[Vector2i] = []

	# 🔁 SAME SCAN LOGIC AS LAVA
	for x in width:
		for y in height:
			var pos: Vector2i = Vector2i(x, y)

			# ensure tile exists
			if tilemap.get_cell_source_id(pos) == -1:
				continue

			# only grass tiles
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				grass_positions.append(pos)

	if grass_positions.is_empty():
		push_error("❌ No grass tiles found for flowers")
		return

	grass_positions.shuffle()

	# load flower textures
	var flower_textures: Array[Texture2D] = load_flower_textures()
	if flower_textures.is_empty():
		push_error("❌ No flower textures found")
		return

	flower_textures.shuffle()
	flower_textures = flower_textures.slice(0, FLOWER_TYPES)

	var tile_size: Vector2 = Vector2(tilemap.tile_set.tile_size)
	var count: int = min(TOTAL_FLOWERS, grass_positions.size())

	for i in range(count):
		var cell: Vector2i = grass_positions[i]
		var tex: Texture2D = flower_textures.pick_random()

		var flower: Sprite2D = Sprite2D.new()
		flower.texture = tex
		flower.z_index = 2

		# ✅ SCALE-SAFE POSITION (works with Map scale = 2)
		var tile_local: Vector2 = tilemap.map_to_local(cell) + tile_size / 2.0
		flower.global_position = tilemap.to_global(tile_local)

		# 🌸 DOUBLE SIZE FLOWERS
		flower.scale = Vector2(2, 2)

		# optional natural variation
		flower.rotation = randf_range(-0.1, 0.1)

		add_child(flower)

# ==================================================
# LOAD FLOWER TEXTURES
# ==================================================
func load_flower_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	var dir: DirAccess = DirAccess.open(FLOWER_PATH)
	if dir == null:
		return textures

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var tex: Texture2D = load(FLOWER_PATH + file_name) as Texture2D
			if tex:
				textures.append(tex)
		file_name = dir.get_next()

	dir.list_dir_end()
	return textures
