extends Node2D

@export var transition_speed : float = 0.4
@export var is_snow : bool = true : set = set_is_snow

@onready var rain_far : CPUParticles2D = $RainFar
@onready var rain_near : CPUParticles2D = $RainNear
@onready var camera := get_viewport().get_camera_2d()

var raining := false
var intensity := 0.0

# Inline Shader Code
var shader_code = """
shader_type canvas_item;
uniform float is_snow : hint_range(0.0, 1.0) = 0.0;
uniform float global_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    // Mix between original blue and pure white based on is_snow
    vec3 final_rgb = mix(tex_color.rgb, vec3(1.0, 1.0, 1.0), is_snow);
    COLOR = vec4(final_rgb, tex_color.a * global_alpha);
}
"""

func _ready():
	rain_far.emitting = false
	rain_near.emitting = false
	
	# Create and apply the material in-code
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = shader_code
	
	# Use duplicate() so each particle system has its own material instance
	rain_far.material = mat
	rain_near.material = mat.duplicate()
	
	apply_weather_type()

func _process(delta):
	if camera:
		global_position = camera.global_position

	if raining:
		intensity = move_toward(intensity, 1.0, transition_speed * delta)
	else:
		intensity = move_toward(intensity, 0.0, transition_speed * delta)

	# Update the shader parameters
	rain_far.material.set_shader_parameter("global_alpha", intensity)
	rain_near.material.set_shader_parameter("global_alpha", intensity)

func set_is_snow(value: bool):
	is_snow = value
	if is_inside_tree():
		apply_weather_type()

func apply_weather_type():
	var snow_val = 1.0 if is_snow else 0.0
	
	# Safety check to ensure materials exist
	if rain_far.material:
		rain_far.material.set_shader_parameter("is_snow", snow_val)
		rain_near.material.set_shader_parameter("is_snow", snow_val)
	
	# Above every depth-sorted sprite (player z = feet_y / 4 can exceed 2000).
	rain_far.z_index = 4050
	rain_near.z_index = 4060
	for p: CPUParticles2D in [rain_far, rain_near]:
		var near := p == rain_near
		if is_snow:
			# Real snow: round flakes drifting and swirling, not slowed-down rain streaks.
			p.texture = _flake_texture()
			p.speed_scale = 1.0
			p.lifetime = 9.0 if near else 12.0
			p.gravity = Vector2(18, 55 if near else 35)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 40.0
			p.spread = 40.0
			p.tangential_accel_min = -25.0
			p.tangential_accel_max = 25.0
			p.scale_amount_min = 0.6 if near else 0.35
			p.scale_amount_max = 1.4 if near else 0.8
			p.amount = 420 if near else 260
		else:
			p.speed_scale = 1.0

func start_rain():
	raining = true
	rain_far.emitting = true
	rain_near.emitting = true

func stop_rain():
	raining = false
	# We let the intensity fade finish before stopping emission
	if intensity <= 0.01:
		rain_far.emitting = false
		rain_near.emitting = false


func _flake_texture() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 8
	g.height = 8
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	return g
