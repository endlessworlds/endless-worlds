extends Node
class_name Atmosphere

# Lighting + post-processing. The time system darkens the whole world through one
# CanvasModulate; PointLight2Ds (hand torch, wells, hint bulbs, lava) add light back,
# so everything they touch — trees, flowers, players — is lit consistently.

const LIGHT_TEX := preload("res://assets/wildlife/light_soft.png")
const POST_SHADER := preload("res://shaders/post_fx.gdshader")

var time_system: Node
var torch: HandTorch
var _lights: Array[PointLight2D] = []   # well / hint lights, scaled by darkness
var _post: ShaderMaterial
var _scan := 0.0
var dark := 0.0                          # 0 = noon, 1 = midnight


func setup(map: Node2D, player: Node2D, time_sys: Node, snowy: bool) -> void:
	time_system = time_sys
	torch = HandTorch.new(player.get_node("AnimatedSprite2D"))
	torch.max_energy = 0.5 if snowy else 0.85
	player.add_child(torch)

	# Post FX sits on the first CanvasLayer slot so the HUD layers draw on top of it.
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST_SHADER
	_post.set_shader_parameter("tint", Vector3(0.94, 0.98, 1.06) if snowy else Vector3(1.03, 1.0, 0.96))
	rect.material = _post
	layer.add_child(rect)
	map.add_child(layer)
	map.move_child(layer, 0)



func cycle_torch() -> void:
	Global.torch_mode = (Global.torch_mode + 1) % 3


func torch_should_burn() -> bool:
	match Global.torch_mode:
		1: return true
		2: return false
	return dark > 0.45  # auto: dusk to dawn


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and not Global.input_locked:
		cycle_torch()
		get_viewport().set_input_as_handled()


func _make_light(color: Color, scl: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = LIGHT_TEX
	l.color = color
	l.texture_scale = scl
	l.energy = 0.0
	return l


func _attach_lights() -> void:
	for w in get_tree().get_nodes_in_group("wells"):
		if not w.has_meta("lit"):
			w.set_meta("lit", true)
			var l := _make_light(Color(0.45, 0.8, 1.0), 0.9)
			l.position = Vector2(0, 10)
			w.add_child(l)
			_lights.append(l)
	for h in get_tree().get_nodes_in_group("hints"):
		if not h.has_meta("lit"):
			h.set_meta("lit", true)
			var l := _make_light(Color(1.0, 0.88, 0.4), 1.2)  # hints are scaled 0.5
			h.add_child(l)
			_lights.append(l)


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_attach_lights()
	if time_system == null or time_system.canvas_mod == null:
		return
	var c: Color = time_system.current_light_color
	dark = clampf((1.0 - c.v) / 0.5, 0.0, 1.0)
	var wl = get_parent().get("wildlife")
	if wl:
		wl.set_daylight(dark < 0.5)  # butterflies + flocks by day only
	torch.set_lit(torch_should_burn())
	_lights = _lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
	for l in _lights:
		l.energy = lerpf(0.0, 0.75, dark)
	_post.set_shader_parameter("vignette", lerpf(0.3, 0.55, dark))
	_post.set_shader_parameter("saturation", lerpf(1.12, 0.95, dark))
