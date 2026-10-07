shader_type spatial;
// Água escura do porão (V2 §6.1): um plano por sala, sem refração nem profundidade (Compatibility/WebGL2).
// Cor por fresnel (fundo petróleo quase preto -> reflexo cinza-esverdeado), marolas de normal analítica e brilho
// das luzes da sala (o specular do Godot faz o resto). `ondas` = 0 deixa a água parada como um espelho (o último
// dia, no Visor sem data).
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec3 cor_fundo : source_color = vec3(0.012, 0.045, 0.05);
uniform vec3 cor_ceu : source_color = vec3(0.16, 0.24, 0.24);
uniform float opacidade : hint_range(0.0, 1.0) = 0.9;
uniform float ondas : hint_range(0.0, 1.0) = 1.0;
uniform float velocidade = 0.7;

varying vec3 p_mundo;

void vertex() {
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = p_mundo.xz;
	float t = TIME * velocidade;
	float a = sin(q.x * 2.1 + t * 1.3) + sin(q.y * 1.7 - t * 1.1) + sin((q.x + q.y) * 3.1 + t * 2.0) * 0.5;
	float gx = cos(q.x * 2.1 + t * 1.3) * 2.1 + cos((q.x + q.y) * 3.1 + t * 2.0) * 1.55;
	float gz = -cos(q.y * 1.7 - t * 1.1) * 1.7 + cos((q.x + q.y) * 3.1 + t * 2.0) * 1.55;
	vec3 n = normalize(vec3(-gx * 0.02 * ondas, 1.0, -gz * 0.02 * ondas));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), v), 0.0, 1.0), 2.5);
	vec3 cor = mix(cor_fundo, cor_ceu, clamp(f * 0.8 + a * 0.01 * ondas, 0.0, 1.0));
	ALBEDO = cor;
	ALPHA = mix(opacidade, 1.0, f * 0.5);
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
}
