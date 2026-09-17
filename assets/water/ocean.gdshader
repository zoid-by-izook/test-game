shader_type spatial;
// Original stylized ocean for test-game (no third-party code).
// Three layered sine waves displace the surface; the fragment tints
// crests lighter and troughs darker for a hand-painted swell look.

uniform vec4 crest_color : source_color = vec4(0.30, 0.68, 0.88, 1.0);
uniform vec4 trough_color : source_color = vec4(0.10, 0.42, 0.72, 1.0);
uniform float wave_height = 0.45;
uniform float wave_speed = 1.1;

varying float wave_t;

void vertex() {
	float w = sin(VERTEX.x * 0.22 + TIME * wave_speed)
		+ 0.6 * sin(VERTEX.z * 0.30 - TIME * wave_speed * 0.7)
		+ 0.35 * sin((VERTEX.x + VERTEX.z) * 0.10 + TIME * wave_speed * 1.4);
	wave_t = clamp(w * 0.28 + 0.5, 0.0, 1.0);
	VERTEX.y += w * wave_height * 0.33;
}

void fragment() {
	ALBEDO = mix(trough_color.rgb, crest_color.rgb, wave_t);
	ROUGHNESS = 0.35;
}
