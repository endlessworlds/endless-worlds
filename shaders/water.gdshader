shader_type canvas_item;

// Pixel-art water drawn over the water tiles. Keeps the tile's own texture and
// biome palette; depth shading is blended across tiles with ordered (Bayer)
// dithering, a wavy foam line laps against the shore, and small wave glints drift.
// Everything snaps to the art's pixel grid.
//
// depth_map: one texel per map cell, 0 = land, (1..6)/6 = cells from the shore.
uniform sampler2D depth_map : filter_nearest;
uniform vec2 map_cells = vec2(280.0, 280.0);
uniform float tile_px = 16.0;
uniform vec2 layer_origin = vec2(0.0);   // global position of the water layer
uniform float layer_scale = 2.0;         // the map node is drawn at 2x

varying vec2 world;

void vertex() {
	// Tile layers draw in chunks with their own local origin, so go through the
	// world position and back into layer pixels.
	world = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - layer_origin) / layer_scale;
}

float depth_of(vec2 cell) {
	return texture(depth_map, (cell + 0.5) / map_cells).r;
}

bool is_land(vec2 cell) {
	return depth_of(cell) < 0.01;
}

float bayer4(vec2 p) {
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 w = floor(world);
	vec2 cell = floor(w / tile_px);
	vec2 p = w - cell * tile_px;                 // pixel inside the tile, 0..15
	vec4 tex = texture(TEXTURE, UV);

	// smooth depth between cell centres, then dithered into 3 shades
	vec2 c = (w + 0.5) / tile_px - 0.5;
	vec2 c0 = floor(c);
	vec2 f = c - c0;
	float d = mix(mix(depth_of(c0), depth_of(c0 + vec2(1.0, 0.0)), f.x),
				  mix(depth_of(c0 + vec2(0.0, 1.0)), depth_of(c0 + vec2(1.0, 1.0)), f.x), f.y);
	float t = smoothstep(0.08, 0.6, d) * 2.0;
	float level = clamp(floor(t + bayer4(w)), 0.0, 2.0);
	vec3 col = tex.rgb;
	if (level < 0.5) {
		col = col * vec3(0.92, 1.02, 0.95) + vec3(0.0, 0.05, 0.0);   // shallow: lighter, a touch green
	} else if (level < 1.5) {
		col *= 0.84;
	} else {
		col *= vec3(0.66, 0.68, 0.72);                                  // deep
	}

	// drifting wave glints: short horizontal dashes on every 4th row
	float row = floor(w.y / 4.0);
	float phase = w.x * 0.18 - TIME * 1.6 + row * 2.3 + sin(row * 1.7 + TIME * 0.5) * 3.0;
	col += step(0.96, sin(phase)) * step(mod(w.y, 4.0), 0.5) * 0.15;

	// foam: distance (px) to the nearest land edge, compared with a wavy, lapping width
	float edge = 99.0;
	float along = 0.0;
	if (is_land(cell + vec2(-1.0, 0.0)) && p.x < edge) { edge = p.x; along = w.y; }
	if (is_land(cell + vec2(1.0, 0.0)) && tile_px - 1.0 - p.x < edge) { edge = tile_px - 1.0 - p.x; along = w.y; }
	if (is_land(cell + vec2(0.0, -1.0)) && p.y < edge) { edge = p.y; along = w.x; }
	if (is_land(cell + vec2(0.0, 1.0)) && tile_px - 1.0 - p.y < edge) { edge = tile_px - 1.0 - p.y; along = w.x; }
	// inner corners where only the diagonal is land
	vec2 q = vec2(min(p.x, tile_px - 1.0 - p.x), min(p.y, tile_px - 1.0 - p.y));
	vec2 dg = vec2(p.x < 8.0 ? -1.0 : 1.0, p.y < 8.0 ? -1.0 : 1.0);
	if (is_land(cell + dg)) { edge = min(edge, max(q.x, q.y)); along = w.x + w.y; }

	float lap = 1.6 + 1.1 * sin(TIME * 1.9 + along * 0.35) + 0.6 * sin(TIME * 0.7 + along * 0.11);
	float foam = step(edge, lap);
	float spray = step(edge, lap + 2.0) * step(0.7, bayer4(w + floor(TIME * 3.0)));   // broken fringe
	col = mix(col, vec3(0.86, 0.92, 0.98), max(foam * 0.85, spray * 0.45));

	COLOR = vec4(min(col, vec3(0.86)), tex.a);   // stay under the bloom threshold
}
