shader_type spatial;
// Original stylized ocean for test-game (no third-party code).
// Layered sine waves + value noise displace the surface (per-vertex); the
// fragment evaluates the same field per-pixel for smooth coloring: a
// deep->crest gradient, noise-broken whitecaps, and an animated foam ring
// where the water meets the island.

uniform vec4 deep_color : source_color = vec4(0.04, 0.23, 0.52, 1.0);
uniform vec4 mid_color : source_color = vec4(0.10, 0.42, 0.72, 1.0);
uniform vec4 crest_color : source_color = vec4(0.30, 0.68, 0.88, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.97, 1.0, 1.0);
uniform float wave_height = 0.45;
uniform float wave_speed = 1.1;
// Island shoreline (analytic circle). The water mesh is centered on the
// island, so the island sits at local (0, 0); radius matches the top
// grass layer. Foam band straddles the jittered cube edge.
uniform vec2 island_center = vec2(0.0, 0.0);
uniform float island_radius = 20.0;
uniform float foam_width = 3.5;

varying vec2 pos_xz;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Combined wave field: the original three sines plus slow and fine value
// noise so the pattern never visibly repeats. `t` is passed in so vertex
// and fragment evaluate the identical field.
float wave_at(vec2 p, float t) {
	float w = sin(p.x * 0.22 + t * wave_speed)
		+ 0.6 * sin(p.y * 0.30 - t * wave_speed * 0.7)
		+ 0.35 * sin((p.x + p.y) * 0.10 + t * wave_speed * 1.4);
	// Slow swell modulation: large-scale organic drift.
	w += (vnoise(p * 0.045 + vec2(t * 0.08, -t * 0.06)) - 0.5) * 0.9;
	// Fine chop: small high-frequency breakup.
	w += (vnoise(p * 0.33 + vec2(-t * 0.22, t * 0.18)) - 0.5) * 0.28;
	return w;
}

void vertex() {
	pos_xz = VERTEX.xz;
	float w = wave_at(VERTEX.xz, TIME);
	VERTEX.y += w * wave_height * 0.33;
}

void fragment() {
	float t = TIME;
	float w = wave_at(pos_xz, t);
	float wave_t = clamp(w * 0.28 + 0.5, 0.0, 1.0);

	// Three-stop water gradient: deep -> mid -> crest.
	vec3 col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, wave_t));
	col = mix(col, crest_color.rgb, smoothstep(0.55, 0.85, wave_t));

	// Whitecaps: foam white where waves peak, broken up by drifting noise
	// so caps appear and dissolve organically instead of as a flat band.
	float cap_n = vnoise(pos_xz * 0.55 + vec2(t * 0.25, -t * 0.20));
	float whitecap = smoothstep(0.80, 0.95, wave_t + (cap_n - 0.5) * 0.30);
	col = mix(col, foam_color.rgb, whitecap * 0.9);

	// Shore foam: an animated ring hugging the island. Distance from the
	// island center minus the top-layer radius gives signed shore distance;
	// the band is widened to cover the jittered cube edge, then carved by
	// noise and a traveling sine so it pulses against the shore.
	float shore_d = length(pos_xz - island_center) - island_radius;
	float band = 1.0 - smoothstep(0.0, foam_width, abs(shore_d - 0.8));
	float foam_n = vnoise(pos_xz * 0.75 + vec2(t * 0.45, t * 0.30));
	float pulse = 0.5 + 0.5 * sin(t * 2.0 - shore_d * 2.2);
	float shore_foam = band * smoothstep(0.30, 0.72, foam_n * 0.65 + pulse * 0.35);
	col = mix(col, foam_color.rgb, clamp(shore_foam, 0.0, 1.0) * 0.85);

	ALBEDO = col;
	ROUGHNESS = 0.35;
}
