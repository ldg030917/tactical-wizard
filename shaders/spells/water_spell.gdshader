shader_type spatial;
render_mode blend_add, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 spell_color : source_color = vec4(0.03, 0.35, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.22, 0.95, 1.0, 1.0);
uniform float intensity : hint_range(0.5, 8.0) = 3.5;
uniform float variant_seed : hint_range(0.0, 20.0) = 0.0;

void vertex() {
	float wave_a = sin(TIME * 5.5 + VERTEX.y * 17.0 + variant_seed) * 0.045;
	float wave_b = cos(TIME * 7.0 + VERTEX.x * 15.0 + VERTEX.z * 11.0) * 0.035;
	VERTEX *= 1.0 + wave_a + wave_b;
	VERTEX.x += sin(TIME * 4.0 + VERTEX.y * 20.0) * 0.035;
}

void fragment() {
	float current_a = sin(UV.x * 25.0 + UV.y * 14.0 - TIME * 5.5 + variant_seed);
	float current_b = sin(UV.x * -16.0 + UV.y * 29.0 + TIME * 7.0);
	float current = 0.5 + 0.25 * current_a + 0.25 * current_b;
	float foam = smoothstep(0.68, 0.95, current);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.7);
	vec3 water = mix(spell_color.rgb, accent_color.rgb, current * 0.42 + foam * 0.32);
	ALBEDO = water;
	EMISSION = water * intensity * 0.18 * (0.7 + foam * 1.7 + rim * 2.2);
	ALPHA = clamp(0.52 + foam * 0.28 + rim * 0.42, 0.0, 1.0);
}
