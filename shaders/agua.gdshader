shader_type spatial;
render_mode specular_disabled;
// Água simples para a Barra (flashback). Ondas por soma de senoides (vértice + normal analítica),
// cor por fresnel (fundo escuro -> reflexo do céu), brilho falso do sol e espuma na margem.
// Compatibility/WebGL2: sem refração, sem profundidade, sem transparência (evita ordenação).

uniform vec3 cor_fundo : source_color = vec3(0.05, 0.13, 0.19);
uniform vec3 cor_raso : source_color = vec3(0.30, 0.42, 0.38);
uniform vec3 cor_ceu : source_color = vec3(1.0, 0.55, 0.3);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.8, 0.5);
uniform vec3 dir_sol = vec3(-0.6, 0.12, -0.8);   // do ponto de vista da cena em direção ao sol (mundo)
uniform float margem_z = -3.0;                    // z (mundo) da linha d'água
uniform float amplitude = 0.07;
uniform float velocidade = 1.0;

varying vec3 pos_mundo;

vec3 ondas(vec2 p, float t) {
	// retorna (altura, d/dx, d/dz)
	float h = 0.0;
	vec2 g = vec2(0.0);
	vec4 a = vec4(0.7, 0.5, 1.3, 2.1);       // frequências
	vec4 w = vec4(1.1, 1.7, 0.9, 2.3);       // velocidades
	vec2 d0 = vec2(0.8, 0.6);
	vec2 d1 = vec2(-0.5, 0.86);
	vec2 d2 = vec2(0.2, -0.98);
	vec2 d3 = vec2(-0.9, -0.4);
	float f0 = dot(p, d0) * a.x + t * w.x;
	float f1 = dot(p, d1) * a.y + t * w.y;
	float f2 = dot(p, d2) * a.z + t * w.z;
	float f3 = dot(p, d3) * a.w + t * w.w;
	h = sin(f0) * 1.0 + sin(f1) * 0.7 + sin(f2) * 0.35 + sin(f3) * 0.18;
	g = cos(f0) * d0 * a.x + cos(f1) * 0.7 * d1 * a.y + cos(f2) * 0.35 * d2 * a.z + cos(f3) * 0.18 * d3 * a.w;
	return vec3(h, g);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = ondas(w.xz, TIME * velocidade);
	VERTEX.y += o.x * amplitude;
	NORMAL = normalize(vec3(-o.y * amplitude, 1.0, -o.z * amplitude));
	pos_mundo = w;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	float raso = 1.0 - smoothstep(0.0, 9.0, margem_z - pos_mundo.z);
	vec3 base = mix(cor_fundo, cor_raso, raso * raso);
	vec3 cor = mix(base, cor_ceu * 0.9, clamp(f * 0.85 + 0.08, 0.0, 1.0));
	// brilho do sol (faixa de reflexo com cintilação das ondas)
	vec3 ls = normalize((VIEW_MATRIX * vec4(normalize(dir_sol), 0.0)).xyz);
	float brilho = pow(max(dot(reflect(-ls, n), v), 0.0), 60.0);
	cor += cor_sol * brilho * 1.6;
	// espuma: linhas claras perto da margem
	float dist = pos_mundo.z - margem_z;
	float linha = smoothstep(0.55, 0.95, sin(dist * 2.2 - TIME * 1.4 + sin(pos_mundo.x * 0.6) * 1.2));
	float espuma = linha * (1.0 - smoothstep(0.0, 4.5, margem_z - pos_mundo.z)) * step(pos_mundo.z, margem_z + 0.2);
	cor = mix(cor, vec3(0.95, 0.9, 0.82), espuma * 0.6);
	ALBEDO = cor;
	EMISSION = cor * 0.35;
	ROUGHNESS = 0.4;
}
