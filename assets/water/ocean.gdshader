shader_type spatial;
// Original stylized ocean for test-game (no third-party code).
// Six directional waves plus texture-based fBm noise displace the surface
// (per-vertex); the fragment evaluates the same field per-pixel: 99% of the
// color range is a deep-blue gradient, with hard, noise-broken white cuts
// at the wave extremes, plus an animated foam ring where water meets island.

uniform vec4 darker_blue : source_color = vec4(0.008, 0.06, 0.20, 1.0);
uniform vec4 dark_blue : source_color = vec4(0.04, 0.20, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
// Tileable fBm noise texture (R: swell, G: whitecap patchiness, B: foam).
uniform sampler2D noise_tex : filter_linear, repeat_enable;
// Baked world-space shoreline distance field (R: signed meters to shore,
// positive in water; G: confinement mask, 1 = narrow channel/inlet).
// Foam hugs the real cube edges, not an analytic shape.
uniform sampler2D shore_sdf : filter_linear;
uniform vec2 sdf_min = vec2(-75.0, -81.0);
uniform float sdf_size = 150.0;
uniform float sdf_max_dist = 12.0;
// Ocean mesh position (xz): converts shader-local pos_xz to world xz.
uniform vec2 ocean_offset = vec2(0.0, -6.0);
uniform float wave_height = 0.45;
uniform float wave_speed = 1.1;
uniform float foam_width = 2.4;

varying vec2 pos_xz;

// Fractal noise from the texture: three taps at different scales drifting
// over time, so the pattern never visibly repeats.
float fbm_at(vec2 p, float t) {
	vec2 uv = p * 0.006;
	float n = texture(noise_tex, uv + vec2(t * 0.010, -t * 0.008)).r * 0.55
		+ texture(noise_tex, uv * 2.7 + vec2(-t * 0.015, t * 0.013)).r * 0.30
		+ texture(noise_tex, uv * 6.1 + vec2(t * 0.025, t * 0.020)).r * 0.15;
	return n;
}

// Six wide directional waves (varied angles, irrational-ish frequencies)
// plus strong fBm. `t` is passed in so vertex and fragment evaluate identically.
float wave_at(vec2 p, float t) {
	float s = wave_speed * 0.5;
	float w = sin(dot(p, vec2(0.073, 0.017)) + t * s * 1.00)
		+ 0.60 * sin(dot(p, vec2(-0.027, 0.100)) - t * s * 0.70)
		+ 0.45 * sin(dot(p, vec2(0.060, -0.073)) + t * s * 1.23)
		+ 0.35 * sin(dot(p, vec2(-0.103, -0.040)) - t * s * 0.87)
		+ 0.28 * sin(dot(p, vec2(0.030, 0.137)) + t * s * 1.45)
		+ 0.22 * sin(dot(p, vec2(-0.150, 0.093)) - t * s * 1.10);
	w += (fbm_at(p, t) - 0.5) * 2.2;
	return w;
}

void vertex() {
	pos_xz = VERTEX.xz;
	float w = wave_at(VERTEX.xz, TIME);
	VERTEX.y += w * wave_height * 0.20;
}

void fragment() {
	float t = TIME;
	float w = wave_at(pos_xz, t);
	float wave_t = clamp(w * 0.20 + 0.5, 0.0, 1.0);

	// 99.8%: darker blue -> dark blue.
	vec3 col = mix(darker_blue.rgb, dark_blue.rgb, smoothstep(0.001, 0.999, wave_t));

	// Random white at the extremes: hard cuts (step, no fade), patchiness
	// from a second noise channel so white appears in scattered flecks,
	// never as a smooth band. Just 0.1% of each end.
	float patch = texture(noise_tex, pos_xz * 0.015 + vec2(t * 0.03, -t * 0.025)).g;
	float wv = wave_t + (patch - 0.5) * 0.12;
	float white = clamp(step(0.999, wv) + step(wv, 0.001), 0.0, 1.0);
	col = mix(col, foam_color.rgb, white);

	// Shore foam: distance sampled from the baked shoreline SDF, so it hugs
	// the actual cube edges. shore_d > 0 in water, < 0 inside the island.
	// The band straddles the edge, carved by noise and a traveling pulse
	// so it laps at the cubes.
	vec2 world_xz = pos_xz + ocean_offset;
	vec2 sdf_uv = clamp((world_xz - sdf_min) / sdf_size, 0.0, 1.0);
	vec2 sdf_sample = texture(shore_sdf, sdf_uv).rg;
	float shore_d = (sdf_sample.r * 2.0 - 1.0) * sdf_max_dist;
	float confined = sdf_sample.g;
	float band = 1.0 - smoothstep(foam_width * 0.5, foam_width, abs(shore_d - 0.8));
	float foam_n = texture(noise_tex, pos_xz * 0.06 + vec2(t * 0.05, t * 0.035)).b;
	float pulse = 0.5 + 0.5 * sin(t * 2.0 - shore_d * 2.2);
	float shore_foam = band * smoothstep(0.30, 0.72, foam_n * 0.65 + pulse * 0.35);
	// Foam color: vivid blue near the cubes, sharp cut to white at the outer
	// edge. In narrow channels (confined) the transition widens so it doesn't
	// form a glitchy sharp line.
	float trans_width = mix(0.3, 1.8, confined);
	float foam_t = smoothstep(1.2 - trans_width * 0.5, 1.2 + trans_width * 0.5, shore_d);
	vec3 foam_blue = vec3(0.10, 0.45, 0.75);
	vec3 foam_col = mix(foam_blue, foam_color.rgb, foam_t);
	col = mix(col, foam_col, clamp(shore_foam, 0.0, 1.0) * 0.95);

	ALBEDO = col;
	ROUGHNESS = 0.35;
}
