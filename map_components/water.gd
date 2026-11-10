extends Node2D
class_name Water

# Real-looking water: a depth map (distance from shore) drives an animated water
# layer (shallow turquoise → deep blue, caustics, swell, shoreline foam), the
# wade/swim split in the player physics, and ripples + splashes for every actor.

const WATER := Vector2i(3, 1)
const SHADER := preload("res://shaders/water.gdshader")
const MAX_DEPTH := 6          # cells; deeper water just stays "deep"

var tilemap: TileMapLayer
var _depth := {}              # Vector2i -> distance to the nearest land cell
var _wet := {}                # actor -> was in water last frame
var _ripple_t := {}           # actor -> seconds until next ripple
var _last_pos := {}


func setup(map_tilemap: TileMapLayer, width: int, height: int) -> void:
	tilemap = map_tilemap
	z_index = 0
	# 1. distance from shore (multi-source BFS from every land cell)
	var queue: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []
	for cell in tilemap.get_used_cells():
		if tilemap.get_cell_atlas_coords(cell) == WATER:
			water_cells.append(cell)
		else:
			_depth[cell] = 0
			queue.append(cell)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var nd: int = _depth[c] + 1
		if nd > MAX_DEPTH:
			continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not _depth.has(n) and tilemap.get_cell_atlas_coords(n) == WATER:
				_depth[n] = nd
				queue.append(n)

	# 2. depth texture, one texel per cell
	var img := Image.create(width, height, false, Image.FORMAT_R8)
	for cell in water_cells:
		if cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height:
			img.set_pixel(cell.x, cell.y, Color(depth_at(cell) / float(MAX_DEPTH), 0, 0))

	# 3. water layer drawn over the base water tiles
	var layer := TileMapLayer.new()
	layer.tile_set = tilemap.tile_set
	layer.position = tilemap.position
	for cell in water_cells:
		layer.set_cell(cell, tilemap.get_cell_source_id(cell), WATER)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("depth_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("map_cells", Vector2(width, height))
	mat.set_shader_parameter("tile_px", float(tilemap.tile_set.tile_size.x))
	layer.material = mat
	tilemap.add_sibling(layer)
	tilemap.get_parent().move_child(layer, tilemap.get_index() + 1)
	mat.set_shader_parameter("layer_origin", layer.global_position)
	mat.set_shader_parameter("layer_scale", layer.global_scale.x)


# 0 = land, 1 = shallow (next to the shore), 2+ = deep
func depth_at(cell: Vector2i) -> int:
	return int(_depth.get(cell, MAX_DEPTH if tilemap.get_cell_atlas_coords(cell) == WATER else 0))


func depth_at_pos(local_pos: Vector2) -> int:
	return depth_at(tilemap.local_to_map(local_pos))


# ------------------------------------------------------------------ ripples + splashes
func _process(delta: float) -> void:
	for a in get_tree().get_nodes_in_group("actors"):
		var feet: Vector2 = a.position + Vector2(0, 14)
		var wet: bool = depth_at_pos(feet) > 0 and not bool(a.get("airborne"))
		var moved: float = feet.distance_to(_last_pos.get(a, feet))
		_last_pos[a] = feet
		if wet and not _wet.get(a, false):
			_splash(feet)
		_wet[a] = wet
		if wet:
			_ripple_t[a] = float(_ripple_t.get(a, 0.0)) - delta
			if _ripple_t[a] <= 0.0:
				_ripple_t[a] = 0.28 if moved > 0.3 else 1.1   # idle swimmers still make slow rings
				_ring(feet, 1.0 if moved > 0.3 else 0.6)


func _ring(at: Vector2, strength: float) -> void:
	var r := _Ring.new()
	r.position = at
	r.strength = strength
	r.z_index = int(at.y * 2.0 / 4.0) - 1
	add_child(r)


func _splash(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = int(at.y * 2.0 / 4.0) + 2
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.9, 0.97, 1.0, 0.9)
	p.emitting = true
	add_child(p)
	for i in 2:
		_ring(at, 1.3)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


class _Ring extends Node2D:
	var strength := 1.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t > 1.1:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := _t / 1.1
		var r := lerpf(3.0, 16.0, k) * strength
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))   # flat ellipse on the surface
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.92, 0.97, 1.0, (1.0 - k) * 0.55), 1.0)
