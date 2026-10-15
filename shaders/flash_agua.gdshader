shader_type spatial;
// Lampejo de água subindo (world/flash_agua.gd): translúcido, sem luz, com listras de brilho que correm. Dura ~0,2 s.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 cor : source_color = vec4(0.08, 0.5, 0.56, 1.0);
uniform float alfa : hint_range(0.0, 1.0) = 0.5;

varying vec3 p_mundo;

void vertex() {
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float w = sin(p_mundo.x * 5.0 + TIME * 11.0) * sin(p_mundo.z * 4.0 - TIME * 8.0) * 0.5 + 0.5;
	w += sin(p_mundo.y * 16.0 - TIME * 13.0) * 0.25;
	ALBEDO = mix(cor.rgb, vec3(0.72, 1.0, 0.95), clamp(w * 0.5, 0.0, 1.0));
	ALPHA = alfa * (0.65 + 0.35 * clamp(w, 0.0, 1.0));
}
