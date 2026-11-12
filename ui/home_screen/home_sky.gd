extends Node
class_name HomeSky

# Day / night on the home screen: the island and hero are tinted through a CanvasModulate
# (dawn pink, white noon, orange dusk, blue night), the island's post-FX shader adds the
# grade, vignette and low-sun light shafts, and the hero's torch lights up after dark.
# A whole day passes every DAY_SECS, starting from this computer's clock.
#   HomeSky.new().setup(home, hero_sprite)

const DAY_SECS := 150.0
const POST_SHADER := preload("res://shaders/post_fx.gdshader")
const KEYS := [   # hour -> world tint
	[0.0, Color(0.30, 0.33, 0.55)], [4.8, Color(0.30, 0.33, 0.55)], [6.0, Color(0.92, 0.66, 0.66)],
	[7.5, Color(1, 1, 1)], [16.5, Color(1, 1, 1)], [18.0, Color(1.0, 0.72, 0.5)],
	[19.4, Color(0.30, 0.33, 0.55)], [24.0, Color(0.30, 0.33, 0.55)]]

var hour := 12.0
var _mod: CanvasModulate
var _post: ShaderMaterial
var _torch: HandTorch


func setup(home: Node, hero: AnimatedSprite2D) -> HomeSky:
	var t := Time.get_time_dict_from_system()
	hour = t.hour + t.minute / 60.0
	for arg in OS.get_cmdline_user_args():   # dev: -- --hour=21
		if arg.begins_with("--hour="):
			hour = float(arg.get_slice("=", 1))
	home.add_child(self)
	_mod = CanvasModulate.new()
	home.add_child(_mod)
	_torch = HandTorch.new(hero)
	hero.get_parent().add_child(_torch)
	# Post FX goes first among the layer-1 canvas layers so the home buttons draw on top of it.
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST_SHADER
	rect.material = _post
	rect.visible = not Screen.low()
	Screen.quality_changed.connect(func(): rect.visible = not Screen.low())
	layer.add_child(rect)
	home.add_child(layer)
	home.move_child(layer, 0)
	_process(0.0)
	return self


static func tint_at(h: float) -> Color:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h <= b[0]:
			return (a[1] as Color).lerp(b[1], smoothstep(a[0], b[0], h))
	return KEYS[0][1]


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / DAY_SECS, 24.0)
	var c := tint_at(hour)
	_mod.color = c
	var dark := clampf((1.0 - c.v) / 0.45, 0.0, 1.0)
	_torch.set_lit(dark > 0.45)
	# same sun model as the island (atmosphere.gd): shafts only while the sun is low
	var daylight := smoothstep(5.5, 7.0, hour) * (1.0 - smoothstep(18.0, 19.3, hour))
	var sun_t := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	_post.set_shader_parameter("sun_rays", daylight * pow(1.0 - sin(sun_t * PI), 1.5))
	_post.set_shader_parameter("sun_pos", Vector2(lerpf(1.15, -0.15, sun_t), -0.2))
	_post.set_shader_parameter("vignette", lerpf(0.3, 0.55, dark))
	_post.set_shader_parameter("saturation", lerpf(1.12, 0.95, dark))
	_post.set_shader_parameter("tint", Vector3(1.03, 1.0, 0.96))
