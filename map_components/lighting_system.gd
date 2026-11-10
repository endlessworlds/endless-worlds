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
const CLUSTER := 5   # cells per light bucket side

# Every lava tile used to get its own additive light, so lava lakes stacked dozens
# of lights into a blown-out, banded blob. Now lava is bucketed into 5x5-cell
# clusters: one soft light per cluster, at its centroid, sized by its lava count.
func spawn_lava_lights():
	for c in glow_manager.get_children():
		c.queue_free()
	var buckets := {}
	for pos in tilemap.get_used_cells():
		var a := tilemap.get_cell_atlas_coords(pos)
		if a == LAVA or a == Vector2i(2, 1):   # lava + magma glow
			var key := Vector2i(pos.x / CLUSTER, pos.y / CLUSTER)
			if not buckets.has(key):
				buckets[key] = [Vector2.ZERO, 0]
			buckets[key][0] += tilemap.map_to_local(pos)
			buckets[key][1] += 1
	for key in buckets:
		var n: int = buckets[key][1]
		var light := PointLight2D.new()
		light.texture = preload("res://assets/wildlife/light_soft.png")
		light.color = Color(1.0, 0.45, 0.12)
		light.texture_scale = clampf(0.35 + sqrt(n) * 0.16, 0.45, 1.6)
		light.energy = clampf(0.35 + n * 0.03, 0.4, 0.85)
		light.position = glow_manager.to_local(tilemap.to_global(buckets[key][0] / n))
		light.range_z_min = -4096   # light every depth-sorted sprite, not just the ground
		light.range_z_max = 4096
		light.set_meta("base_energy", light.energy)
		light.set_meta("phase", randf() * TAU)
		glow_manager.add_child(light)


# slow, uneven lava pulse
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for l in glow_manager.get_children():
		if l is PointLight2D and l.has_meta("base_energy"):
			var ph: float = l.get_meta("phase")
			l.energy = l.get_meta("base_energy") * (0.88 + 0.08 * sin(t * 1.3 + ph) + 0.04 * sin(t * 3.7 + ph * 2.0))


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
