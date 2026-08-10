shader_type spatial;
render_mode blend_add, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 spell_color : source_color = vec4(1.0, 0.78, 0.22, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.98, 0.82, 1.0);
uniform float intensity : hint_range(0.5, 8.0) = 3.6;
uniform float variant_seed : hint_range(0.0, 20.0) = 0.0;

void vertex() {
	float arcane_pulse = sin(TIME * 6.0 + length(VERTEX) * 24.0 + variant_seed) * 0.035;
	VERTEX *= 1.0 + arcane_pulse;
}

void fragment() {
	float latitude = abs(sin(UV.y * 34.0 - TIME * 4.0));
	float longitude = abs(sin(UV.x * 38.0 + TIME * 3.0 + variant_seed));
	float runes = pow(1.0 - min(latitude, longitude), 8.0);
	float pulse = 0.65 + 0.35 * sin(TIME * 5.0 + variant_seed);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.4);
	vec3 arcane = mix(spell_color.rgb, accent_color.rgb, runes * 0.9 + rim * 0.35);
	ALBEDO = arcane;
	EMISSION = arcane * intensity * 0.16 * (0.8 + runes * 2.5 + rim * 2.0 + pulse * 0.35);
	ALPHA = clamp(0.58 + runes * 0.28 + rim * 0.38, 0.0, 1.0);
}
