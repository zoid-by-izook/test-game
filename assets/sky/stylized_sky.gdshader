shader_type sky;

// Stylized daytime sky for test-game.
//
// Adapted from the GDQuest "godot-4-stylized-sky" demo
// (https://github.com/gdquest-demos/godot-4-stylized-sky), whose shader code
// is MIT licensed (see assets/sky/LICENSE-GDQuest-MIT.txt).
//
// Changes made for this project:
// - Single pass. The original renders clouds in a half-res pass, which the
//   Compatibility renderer (what this game's web export uses) does not
//   support, so the clouds are computed inline instead.
// - Removed unused features: starfield, shooting stars, astro sprite, high
//   clouds. This is a cheerful daytime sky.
// - Procedural sun disc instead of the astro texture.
// - Cloud textures are generated in-repo by tools/generate_sky_textures.py.
//   The demo's own textures are CC-BY-NC-SA 4.0 and are NOT used here.
// - Defaults tuned for a bright cartoon look that matches the Quaternius art.

group_uniforms sky;

uniform vec3 top_color : source_color = vec3(0.20, 0.52, 1.0);
uniform vec3 bottom_color : source_color = vec3(0.74, 0.90, 1.0);
uniform vec3 sun_scatter : source_color = vec3(1.0, 0.85, 0.6);

group_uniforms sun;

uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.88);
uniform float sun_size : hint_range(0.9990, 1.0, 0.0001) = 0.99965;

group_uniforms clouds;

uniform sampler2D cloud_shape_sampler : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_noise_sampler : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cloud_curves;

uniform int clouds_samples : hint_range(8, 32, 8) = 16;
uniform int shadow_sample : hint_range(1, 4, 1) = 4;

uniform float clouds_density : hint_range(0.0, 1.0, 0.1) = 0.7;
uniform float clouds_scale : hint_range(0.5, 1.5, 0.1) = 1.0;
uniform float clouds_smoothness : hint_range(0.01, 0.1, 0.01) = 0.035;
uniform vec3 clouds_light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float clouds_shadow_intensity : hint_range(0.1, 10.0, 0.1) = 1.0;

float cloud_density(vec3 p, float progress){
	float t_o = TIME * 0.001;
	float t_o_small = TIME * -0.005;
	float noise = texture(cloud_noise_sampler, p.xy * 4.0 + t_o_small).x * 0.1 + 0.9;
	float clouds_shape = texture(cloud_shape_sampler, (p.xy + t_o) * clouds_scale).x;
	float height_curve = texture(cloud_curves, vec2(progress, 0.0)).x;
	float base_density = 1.0 - clouds_density;
	float density =
	smoothstep(base_density - clouds_smoothness,
	base_density + clouds_smoothness,
	clouds_shape * noise * height_curve
	);
	return density;
}

vec2 cloud_ray_march(vec3 direction, vec3 sun_direction){
	float density = 0.0;
	float light = 0.0;

	// March along the view ray in texture space. A short march keeps each
	// pixel sampling a small texture region, so individual puffs stay
	// distinct instead of averaging into streaks.
	float height = 0.3;
	vec3 sample_point = vec3(0.0, 0.0, 2.0);

	for(int i = 0; i < clouds_samples; i++) {
		float progress = float(i) / float(clouds_samples);
		sample_point = direction * height * progress;
		float point_density = cloud_density(sample_point, progress);
		density += point_density;

		float point_light = 0.0;
		for(int f = 0; f < shadow_sample; f++){
			float shadow_progress = float(f) / float(shadow_sample);
			vec3 shadow_offset = sun_direction * height * shadow_progress;
			point_light += cloud_density(sample_point + shadow_offset, progress);
		}
		light += point_light;
	}
	return vec2(clamp(density, 0.0, 1.0), light / float(shadow_sample * clouds_samples));
}

vec3 compute_sky_color(vec3 eyedir, vec3 sun_dir) {
	// Blue gradient, deeper toward the zenith.
	vec3 sky_gradient = mix(bottom_color.rgb, top_color.rgb, pow(clamp(eyedir.y, 0.0, 1.0), 0.6));

	// Gentle warm haze hugging the horizon.
	float horizon_band = pow(1.0 - clamp(eyedir.y, 0.0, 1.0), 3.0);
	vec3 sky_color = sky_gradient + sun_scatter * horizon_band * 0.25;

	// Procedural sun disc + glow, placed on the scene's directional light,
	// with a touch of warmth in the sky around it.
	vec3 eye = normalize(eyedir);
	float sun_dot = clamp(dot(eye, normalize(sun_dir)), 0.0, 1.0);
	float disc = smoothstep(sun_size - 0.0006, sun_size, sun_dot);
	float glow = pow(sun_dot, 350.0) * 0.35;
	sky_color += sun_scatter * pow(sun_dot, 8.0) * 0.12;
	sky_color += sun_color * (disc + glow);

	// Puffy raymarched clouds. Our follow camera looks down at the level, so
	// the sky is only ever a thin band around the horizon (EYEDIR.y ~= 0):
	// run the march slightly below the horizon too, and fade clouds in from
	// there so the band actually gets clouds. Keep the up-clamp floor high
	// (0.3) so grazing rays don't stretch the march into thin streaks --
	// distant clouds stay big and puffy instead.
	float up = clamp(eyedir.y, 0.3, 1.0);
	if (eyedir.y > -0.2) {
		vec3 clouds_direction = vec3(eyedir.xz / up, 1.0);
		vec2 clouds = cloud_ray_march(clouds_direction, sun_dir);
		// Shade clouds bright white with soft blue-gray depth, NOT tinted by
		// the sky gradient: our camera only ever sees the pale horizon band,
		// so sky-tinted clouds would be invisible against it.
		float shade = exp(-clouds.y * clouds_shadow_intensity);
		vec3 cloud_color = mix(vec3(0.72, 0.78, 0.9), clouds_light_color, shade);
		float fade = smoothstep(-0.15, 0.03, eyedir.y);
		float cloud_alpha = (1.0 - exp(-clouds.x * 6.0)) * fade;
		sky_color = mix(sky_color, cloud_color, clamp(cloud_alpha, 0.0, 1.0));
	}

	return clamp(sky_color, 0.0, 1.0);
}

void sky() {
	COLOR = compute_sky_color(EYEDIR, LIGHT0_DIRECTION);
}
