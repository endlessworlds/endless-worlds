extends Node

# ---------------- WORLD SIZE ----------------
@export var width: int = 200
@export var height: int = 200
@onready var tilemap: TileMapLayer = $"../TileMap"

# ---------------- SETTINGS ----------------
const GRASS: Vector2i = Vector2i(0, 0)

const TOTAL_TREES: int = 40        # 🌲 fewer than flowers
const TREE_TYPES: int = 6          # number of tree variations
const TREE_PATH: String = "res://assets/trees/"

# ==================================================
# TREE SPAWNER
# ==================================================
func spawn_trees() -> void:
	var grass_positions: Array[Vector2i] = []

	# 1️⃣ Collect all grass tiles
	for x: int in range(width):
		for y: int in range(height):
			var pos: Vector2i = Vector2i(x, y)

			if tilemap.get_cell_source_id(pos) == -1:
				continue

			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				grass_positions.append(pos)

	if grass_positions.is_empty():
		push_error("❌ No grass tiles found for trees")
		return

	grass_positions.shuffle()

	# 2️⃣ Load tree textures
	var tree_textures: Array[Texture2D] = load_tree_textures()
	if tree_textures.is_empty():
		push_error("❌ No tree textures found")
		return

	tree_textures.shuffle()
	tree_textures = tree_textures.slice(0, TREE_TYPES)

	# 3️⃣ Spawn trees
	var count: int = min(TOTAL_TREES, grass_positions.size())

	for i: int in range(count):
		var cell: Vector2i = grass_positions[i]
		var tex: Texture2D = tree_textures.pick_random()

		var tree := Sprite2D.new()
		tree.texture = tex

		# 🔑 Place tree at tile base (trunk on ground)
		var tile_local: Vector2 = tilemap.map_to_local(cell)
		tree.global_position = tilemap.to_global(tile_local)

		# 🌲 Trees are bigger than flowers
		tree.scale = Vector2(2.8, 2.8)

		# Small random rotation for natural look
		tree.rotation = randf_range(-0.05, 0.05)

		# 🔑 Depth sorting based on trunk/base
		tree.z_index = int(tree.global_position.y)

		add_child(tree)

# ==================================================
# LOAD TREE TEXTURES
# ==================================================
func load_tree_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	if not DirAccess.dir_exists_absolute(TREE_PATH):
		push_error("❌ Directory not found: " + TREE_PATH)
		return textures

	var files = ResourceLoader.list_directory(TREE_PATH)

	for file in files:
		if file.ends_with(".png"):
			var tex = load(TREE_PATH + file)
			if tex is Texture2D:
				textures.append(tex)

	return textures
