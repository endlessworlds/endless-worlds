extends Node

# ---------------- WORLD SIZE ----------------
@export var width := 280
@export var height := 280

@onready var tilemap : TileMapLayer = $"../TileMap"
@onready var glow_manager := $"../GlowManager"

# ---------------- TILE ATLAS ----------------
const SRC := 0
const LAVA = Vector2i(1, 1)

# ==================================================
# LAVA LIGHTS (EXACT COPY)
# ==================================================
func spawn_lava_lights():
	for c in glow_manager.get_children():
		c.queue_free()

	var tile_size : Vector2 = Vector2(tilemap.tile_set.tile_size)

	for x in width:
		for y in height:
			var pos := Vector2i(x, y)
			if tilemap.get_cell_atlas_coords(pos) == LAVA:
				var light := PointLight2D.new()
				light.color = Color(1.0, 0.4, 0.1,0.5)
				light.texture = preload("res://assets/glow.png")
				light.range_z_max = 4096
				light.light_mask = 1
				light.texture_scale = 2

				# ✅ TRUE CENTER OF TILE
				var tile_center := tilemap.map_to_local(pos) 
				light.position = glow_manager.to_local(
					tilemap.to_global(tile_center)
				)

				glow_manager.add_child(light)

# ==================================================
# GLOW UPDATE (EXACT COPY)
# ==================================================
func update_glow(color: Color):
	if not glow_manager:
		return

	var darkness: float = clamp(1.0 - color.v, 0.0, 1.0)

	for child in glow_manager.get_children():
		if child is PointLight2D:
			# keep existing energy logic
			child.energy = lerp(0.0, 0.35, darkness)

			# ✅ NEW: gradual opacity change
			var c: Color = child.color
			c.a = lerp(0.1, 0.5, darkness)
			child.color = c
