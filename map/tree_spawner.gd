extends Node

# ---------------- WORLD SIZE ----------------
@export var width: int = 200
@export var height: int = 200
@onready var tilemap: TileMapLayer = $"../TileMap"

# ---------------- SETTINGS ----------------
const GRASS: Vector2i = Vector2i(0, 0)

const TOTAL_TREES: int = 20
const TREE_TYPES: int = 4
const TREE_PATH: String = "res://assets/trees/"

# ==================================================
# TREE SPAWNER
# ==================================================
func spawn_trees() -> void:
	var grass_positions: Array[Vector2i] = []

	for x: int in range(width):
		for y: int in range(height):
			var pos: Vector2i = Vector2i(x, y)
			if tilemap.get_cell_source_id(pos) == -1: continue
			if tilemap.get_cell_atlas_coords(pos) == GRASS:
				grass_positions.append(pos)

	if grass_positions.is_empty(): return
	grass_positions.shuffle()

	var tree_textures: Array[Texture2D] = load_tree_textures()
	if tree_textures.is_empty(): return

	tree_textures.shuffle()
	tree_textures = tree_textures.slice(0, TREE_TYPES)

	var count: int = min(TOTAL_TREES, grass_positions.size())

	for i: int in range(count):
		var cell: Vector2i = grass_positions[i]
		var tex: Texture2D = tree_textures.pick_random()

		var tree := Sprite2D.new()
		tree.texture = tex
		tree.centered = false
		# Offset ensures the "root" of the tree is at the tile center
		tree.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 10)

		var tile_local: Vector2 = tilemap.map_to_local(cell)
		tree.global_position = tilemap.to_global(tile_local)
		tree.rotation = randf_range(-0.05, 0.05)
		tree.z_index = int(tree.global_position.y / 4.0)

		# --------- ELLIPSE SHADOW GENERATION ---------
		var shadow := Polygon2D.new()
		var shadow_points := PackedVector2Array()
		var steps := 32
		var radius_x : float = tex.get_width() * 0.4 # Adjust width of shadow
		var radius_y : float = radius_x * 0.4        # Flatten it into an ellipse
		
		for j in range(steps):
			var angle = j * PI * 2 / steps
			shadow_points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
		
		shadow.polygon = shadow_points
		shadow.color = Color(0, 0, 0, 0.3) # Semi-transparent black
		shadow.show_behind_parent = true   # Puts shadow under the tree sprite
		
		# Position shadow at the "feet" of the tree
		shadow.position = Vector2(0, 5) 
		tree.add_child(shadow)

		# --------- HITBOX GENERATION (Trunk Only) ---------
		var img = tex.get_image()
		var img_w = img.get_width()
		var img_h = img.get_height()
		var scan_height = 25
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(img.get_region(Rect2i(0, img_h - scan_height, img_w, scan_height)))
		
		var polygons = bitmap.opaque_to_polygons(Rect2i(0, 0, img_w, scan_height), 2.0)
		var static_body := StaticBody2D.new()
		static_body.position = tree.offset + Vector2(0, img_h - scan_height)
		
		for poly in polygons:
			var collision_poly = CollisionPolygon2D.new()
			collision_poly.polygon = poly
			static_body.add_child(collision_poly)

			## --- DEBUG VISUAL (Optional: Remove in production) ---
			#var debug_line = Line2D.new()
			#var closed_poly = Array(poly)
			#closed_poly.append(poly[0]) # Close the loop
			#debug_line.points = PackedVector2Array(closed_poly)
			#debug_line.width = 1.0
			#debug_line.default_color = Color(1, 0, 0, 1) # Semi-transparent red
			#
			## Move the line up by 30 pixels
			#debug_line.position.y -= 30 
			#
			#collision_poly.add_child(debug_line)

		add_child(tree)


		tree.add_child(static_body)

# ==================================================
# LOAD TREE TEXTURES
# ==================================================
func load_tree_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if not DirAccess.dir_exists_absolute(TREE_PATH): return textures
	var files = ResourceLoader.list_directory(TREE_PATH)
	for file in files:
		if file.ends_with(".png"):
			var tex = load(TREE_PATH + file)
			if tex is Texture2D: textures.append(tex)
	return textures
