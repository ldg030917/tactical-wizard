shader_type spatial;
render_mode blend_add, depth_prepass_alpha, cull_disabled, unshaded;

uniform vec4 spell_color : source_color = vec4(1.0, 0.16, 0.015, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.72, 0.05, 1.0);
uniform float intensity : hint_range(0.5, 8.0) = 3.8;
uniform float variant_seed : hint_range(0.0, 20.0) = 0.0;

void vertex() {
	float flame = sin(TIME * 10.0 + VERTEX.y * 18.0 + variant_seed) * 0.055;
	flame += sin(TIME * 6.0 + VERTEX.x * 23.0) * 0.025;
	VERTEX *= 1.0 + flame;
	VERTEX.y += max(VERTEX.y, 0.0) * sin(TIME * 8.0 + VERTEX.x * 16.0) * 0.08;
}

void fragment() {
	float tongues = 0.5 + 0.5 * sin(UV.y * 32.0 - TIME * 11.0 + sin(UV.x * 25.0 + variant_seed) * 2.0);
	float sparks = pow(max(0.0, sin(UV.x * 91.0 + UV.y * 57.0 - TIME * 17.0)), 18.0);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.2);
	vec3 hot = mix(spell_color.rgb, accent_color.rgb, tongues * 0.34 + sparks * 0.5);
	ALBEDO = hot;
	EMISSION = hot * intensity * 0.18 * (0.75 + tongues * 0.75 + rim * 1.8 + sparks * 3.0);
	ALPHA = clamp(0.62 + rim * 0.34 + sparks, 0.0, 1.0);
}
