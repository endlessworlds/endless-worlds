shader_type canvas_item;

// Full-screen grade applied over the world (below the HUD).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.38;
uniform float saturation = 1.12;
uniform float contrast = 1.06;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
uniform float grain = 0.025;
uniform float bloom = 0.15;
uniform float sun_rays = 0.0;                 // 0 at noon/night, ~1 at sunrise/sunset
uniform vec2 sun_pos = vec2(1.15, -0.2);      // screen UV of the sun (off-screen corner)
uniform vec3 sun_color = vec3(1.0, 0.8, 0.55);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// cheap bloom: blurred mip of the bright parts (lava, lights, fireflies)
	vec3 blur = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;
	c += max(blur - 0.78, 0.0) * bloom * 2.5;  // only real highlights (lava, flames)

	// low-sun shafts + glow from the sun's side of the screen
	if (sun_rays > 0.001) {
		vec2 to = SCREEN_UV - sun_pos;
		float ang = atan(to.y, to.x);
		float d = length(to);
		float beams = 0.5 + 0.5 * sin(ang * 38.0 + TIME * 0.15) * sin(ang * 23.0 - TIME * 0.11 + 1.7);
		beams = pow(beams, 3.0);
		float fall = smoothstep(1.5, 0.0, d);
		c += sun_color * (beams * 0.45 + 0.3) * fall * sun_rays * 0.4;
	}

	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;

	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 2.2;

	c += (hash(SCREEN_UV * 1000.0 + TIME) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
