shader_type spatial;
render_mode blend_add, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 spell_color : source_color = vec4(0.05, 0.68, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.62, 1.0, 0.16, 1.0);
uniform float intensity : hint_range(0.5, 8.0) = 3.3;
uniform float variant_seed : hint_range(0.0, 20.0) = 0.0;

void vertex() {
	float growth = sin(TIME * 4.5 + VERTEX.y * 13.0 + variant_seed) * 0.045;
	float curl = cos(TIME * 3.2 + atan(VERTEX.z, VERTEX.x) * 5.0) * 0.035;
	VERTEX *= 1.0 + growth + curl;
	VERTEX.xz += normalize(VERTEX.xz + vec2(0.001)) * growth * 0.08;
}

void fragment() {
	float veins = abs(sin(UV.x * 31.0 + sin(UV.y * 17.0 + TIME * 2.0) * 2.5));
	veins = pow(1.0 - veins, 5.0);
	float spores = pow(max(0.0, sin(UV.x * 79.0 + UV.y * 83.0 + TIME * 6.0 + variant_seed)), 22.0);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.0);
	vec3 life = mix(spell_color.rgb, accent_color.rgb, veins * 0.42 + spores * 0.55);
	ALBEDO = life;
	EMISSION = life * intensity * 0.18 * (0.75 + veins * 2.1 + spores * 3.0 + rim * 1.6);
	ALPHA = clamp(0.62 + veins * 0.18 + rim * 0.35 + spores, 0.0, 1.0);
}
