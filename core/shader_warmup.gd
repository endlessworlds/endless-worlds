extends Node2D
class_name ShaderWarmup

# The web build (GL) compiles each canvas shader variant the first time something draws with
# it, which froze play for 150-750 ms on laptop GPUs (first torch-lit sprite, first particles).
# This draws the variants play needs later, almost invisibly at the middle of the screen for a
# few frames while the level loads, then frees itself: sprites, polygons and particles, plain
# and unshaded (torch), with and without a light, plus every world shader material under a
# light. Each variant costs ~130 ms on an Intel iGPU, so only these are warmed.
#   ShaderWarmup.run(level)

const LIGHT_TEX := preload("res://assets/wildlife/light_soft.png")
const FRAMES := 4

var _level: Node
var _groups: Array[Node2D] = []


static func run(level: Node) -> void:
	var w := ShaderWarmup.new()
	w._level = level
	w.z_index = 100
	level.add_child(w)


func _ready() -> void:
	for lit in [false, true]:
		var group := Node2D.new()
		group.position = Vector2(-60 if lit else 60, 0)   # 120 px apart: the light reaches only one group
		group.modulate.a = 0.02
		add_child(group)
		_groups.append(group)
		if lit:
			var light := PointLight2D.new()
			light.texture = LIGHT_TEX
			light.texture_scale = 0.2
			light.energy = 0.01
			group.add_child(light)
	var plain: Array = [Sprite2D, Polygon2D, CPUParticles2D]
	_add_kinds(null, plain, _groups)
	_add_kinds(_unshaded(), [Sprite2D, CPUParticles2D], _groups)
	_follow_camera()
	await get_tree().process_frame   # the level has added its own nodes by now
	var seen := {}
	for n in _level.find_children("*", "CanvasItem", true, false):
		var m: Material = (n as CanvasItem).material
		# Screen-layer (HUD, post FX) materials are never lit and already drew unlit.
		if m is ShaderMaterial and not seen.has(m) and (n as CanvasItem).get_canvas_layer_node() == null:
			seen[m] = true
			var kind = CPUParticles2D if n is CPUParticles2D else (Polygon2D if n is Polygon2D or n is Line2D else Sprite2D)
			_add_kinds(m, [kind], [_groups[1]])
	for i in FRAMES:
		_follow_camera()
		await get_tree().process_frame
	queue_free()


func _unshaded() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


# Sprite2D = quads, Polygon2D = vertex attributes, CPUParticles2D = instanced.
func _add_kinds(mat: Material, kinds: Array, groups: Array) -> void:
	var px := PlaceholderTexture2D.new()
	px.size = Vector2(4, 4)
	for group in groups:
		for kind in kinds:
			var item: CanvasItem = kind.new()
			if item is Sprite2D:
				item.texture = px
			elif item is Polygon2D:
				item.polygon = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(0, 4)])
			else:
				item.amount = 2
				item.lifetime = 0.2
			item.material = mat
			group.add_child(item)


func _follow_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		global_position = cam.get_screen_center_position()
