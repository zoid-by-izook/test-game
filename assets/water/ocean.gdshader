shader_type spatial;
// Original stylized ocean for test-game (no third-party code).
// Six directional waves plus texture-based fBm noise displace the surface
// (per-vertex); the fragment evaluates the same field per-pixel: 99% of the
// color range is a deep-blue gradient, with hard, noise-broken white cuts
// at the wave extremes. (Shore foam comes in a follow-up PR.)

uniform vec4 darker_blue : source_color = vec4(0.008, 0.06, 0.20, 1.0);
uniform vec4 dark_blue : source_color = vec4(0.04, 0.20, 0.42, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
// Tileable fBm noise texture (R: swell, G: whitecap patchiness).
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float wave_height = 0.45;
uniform float wave_speed = 1.1;

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


	ALBEDO = col;
	ROUGHNESS = 0.35;
}
