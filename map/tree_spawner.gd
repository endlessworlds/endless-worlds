extends Node

# ---------------- WORLD SIZE ----------------
@export var width: int = 200
@export var height: int = 200
@onready var tilemap: TileMapLayer = $"../TileMap"

# ---------------- SETTINGS ----------------
const GRASS: Vector2i = Vector2i(0, 0)
const TOTAL_TREES: int = 20
const TREE_TYPES: int = 4
const SHADOW_TEX = preload("res://assets/glow.png")

# Preload all tree textures for web export reliability
const TREE_TEXTURES = [
	preload("res://assets/trees/winter_conifer_tree_3.png"),
	preload("res://assets/trees/winter_conifer_tree_2.png"),
	preload("res://assets/trees/winter_conifer_tree_4.png"),
	preload("res://assets/trees/winter_conifer_tree_1.png"),
	preload("res://assets/trees/middle_lane_tree4.png"),
	preload("res://assets/trees/winter_conifer_tree_5.png"),
	preload("res://assets/trees/winter_tree_7.png"),
	preload("res://assets/trees/winter_tree_8.png"),
	preload("res://assets/trees/winter_tree_9.png"),
	preload("res://assets/trees/middle_lane_tree3.png"),
	preload("res://assets/trees/middle_lane_tree2.png"),
	preload("res://assets/trees/jungle_tree_7.png"),
	preload("res://assets/trees/jungle_tree_6.png"),
	preload("res://assets/trees/jungle_tree_5.png"),
	preload("res://assets/trees/jungle_tree_4.png"),
	preload("res://assets/trees/jungle_tree_3.png"),
	preload("res://assets/trees/jungle_tree_2.png"),
	preload("res://assets/trees/fir_tree_4.png"),
	preload("res://assets/trees/fir_tree_3.png"),
	preload("res://assets/trees/fir_tree_2.png"),
	preload("res://assets/trees/fir_tree_1.png"),
	preload("res://assets/trees/birch_5.png"),
	preload("res://assets/trees/birch_4.png"),
	preload("res://assets/trees/birch_3.png"),
	preload("res://assets/trees/birch_2.png"),
	preload("res://assets/trees/birch_1.png")
]

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
	
	if TREE_TEXTURES.size() == 0:
		push_error("❌ No tree textures found")
		return
	
	var tree_textures = TREE_TEXTURES.duplicate()
	tree_textures.shuffle()
	tree_textures = tree_textures.slice(0, min(TREE_TYPES, tree_textures.size()))
	
	var count: int = min(TOTAL_TREES, grass_positions.size())
	
	for i: int in range(count):
		var cell: Vector2i = grass_positions[i]
		var tex: Texture2D = tree_textures.pick_random()
		
		var tree := Sprite2D.new()
		tree.texture = tex
		tree.centered = false
		tree.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 10)
		
		var tile_local: Vector2 = tilemap.map_to_local(cell)
		tree.global_position = tilemap.to_global(tile_local)
		tree.rotation = randf_range(-0.05, 0.05)
		tree.z_index = int(tree.global_position.y / 4.0)
		
		# --------- TEXTURE SHADOW ---------
		var shadow := Sprite2D.new()
		shadow.texture = SHADOW_TEX
		shadow.modulate = Color(0, 0, 0, 0.2)
		shadow.show_behind_parent = true
		shadow.z_index = -1
		
		var shadow_scale_x = (tex.get_width() / float(SHADOW_TEX.get_width())) * 1.1
		shadow.scale = Vector2(shadow_scale_x, shadow_scale_x * 0.3)
		shadow.position = Vector2(0, 7)
		tree.add_child(shadow)
		
		# --------- HITBOX GENERATION ---------
		var img = tex.get_image()
		var img_w = img.get_width()
		var img_h = img.get_height()
		
		var scan_height = 25
		var scan_region = Rect2i(0, img_h - scan_height, img_w, scan_height)
		var bottom_slice = img.get_region(scan_region)
		
		var bitmap = BitMap.new()
		bitmap.create_from_image_alpha(bottom_slice)
		
		var polygons = bitmap.opaque_to_polygons(Rect2i(0, 0, img_w, scan_height), 2.0)
		
		var static_body := StaticBody2D.new()
		static_body.position = tree.offset + Vector2(0, img_h - scan_height + 30)
		
		for poly in polygons:
			var collision_poly = CollisionPolygon2D.new()
			collision_poly.polygon = poly
			static_body.add_child(collision_poly)
		
		add_child(tree)
		tree.add_child(static_body)
	
	print("✅ Spawned ", count, " trees")
