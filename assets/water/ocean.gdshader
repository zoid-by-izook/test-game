shader_type spatial;
// Original stylized ocean for test-game (no third-party code).
// Three layered sine waves displace the surface (per-vertex); the fragment
// evaluates the same waves per-pixel so crest/trough tinting gets smooth
// per-pixel gradients instead of chunky per-vertex color bands.

uniform vec4 crest_color : source_color = vec4(0.30, 0.68, 0.88, 1.0);
uniform vec4 trough_color : source_color = vec4(0.10, 0.42, 0.72, 1.0);
uniform float wave_height = 0.45;
uniform float wave_speed = 1.1;

varying vec2 pos_xz;

float wave_at(vec2 p) {
	return sin(p.x * 0.22 + TIME * wave_speed)
		+ 0.6 * sin(p.y * 0.30 - TIME * wave_speed * 0.7)
		+ 0.35 * sin((p.x + p.y) * 0.10 + TIME * wave_speed * 1.4);
}

void vertex() {
	pos_xz = VERTEX.xz;
	float w = wave_at(VERTEX.xz);
	VERTEX.y += w * wave_height * 0.33;
}

void fragment() {
	// Per-pixel evaluation: pos_xz interpolates linearly across each
	// triangle (which is correct for a position), so evaluating the
	// nonlinear wave pattern here yields full per-pixel detail.
	float wave_t = clamp(wave_at(pos_xz) * 0.28 + 0.5, 0.0, 1.0);
	ALBEDO = mix(trough_color.rgb, crest_color.rgb, wave_t);
	ROUGHNESS = 0.35;
}
