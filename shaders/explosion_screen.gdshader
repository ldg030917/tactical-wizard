shader_type canvas_item;

uniform float blast_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fire_core : source_color = vec3(1.0, 0.94, 0.62);
uniform vec3 fire_edge : source_color = vec3(1.0, 0.08, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.7778, 1.0);
	float radius = length(centered);
	float turbulence = noise(centered * 13.0 + blast_progress * 9.0) * 0.10;
	float expanding = blast_progress * 1.32;
	float shock = 1.0 - smoothstep(0.018, 0.095, abs(radius + turbulence - expanding));
	float fireball = 1.0 - smoothstep(expanding * 0.42, expanding * 0.92, radius + turbulence * 0.7);
	float embers = step(0.88, noise(centered * 42.0 - blast_progress * 17.0)) * (1.0 - blast_progress);
	float fade = 1.0 - smoothstep(0.66, 1.0, blast_progress);
	vec3 color = mix(fire_edge, fire_core, clamp(fireball + shock * 0.8, 0.0, 1.0));
	color += vec3(1.0, 0.28, 0.01) * embers;
	float alpha = clamp((shock * 0.92 + fireball * 0.86 + embers * 0.45) * fade, 0.0, 0.96);
	COLOR = vec4(color, alpha);
}
