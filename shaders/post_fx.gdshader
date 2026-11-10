shader_type canvas_item;

// Full-screen grade applied over the world (below the HUD).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.38;
uniform float saturation = 1.12;
uniform float contrast = 1.06;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float grain = 0.025;
uniform float bloom = 0.15;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// cheap bloom: blurred mip of the bright parts (lava, lights, fireflies)
	vec3 blur = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;
	c += max(blur - 0.78, 0.0) * bloom * 2.5;  // only real highlights (lava, flames)

	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;

	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.2;

	c += (hash(SCREEN_UV * 1000.0 + TIME) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
