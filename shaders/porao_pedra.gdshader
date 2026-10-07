shader_type spatial;
// Pedra do porão (V2 §6.1): a mesma pedra do Castelinho, mais escura e úmida. Triplanar em coordenadas do mundo
// (as paredes não têm UV), filtro nearest (pixels visíveis, estilo PS1) e três "sujeiras" baratas:
//  - oclusão falsa rente ao chão da sala (`piso_y`),
//  - faixa molhada e esverdeada acima da água (`agua_y`),
//  - abaixo da água, tudo escurece e puxa para o verde-petróleo.
// A cor de vértice (COLOR) multiplica o resultado: a Malha usa isso para variar o tom de bloco a bloco.
// Compatibility/WebGL2: 3 leituras de textura, nenhuma luz extra.
render_mode specular_disabled;

uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 escala = vec3(0.6757, 0.6734, 0.6757);   // 1 / metros por repetição (x, y, z)
uniform vec4 tom : source_color = vec4(0.46, 0.40, 0.40, 1.0);
uniform float umidade : hint_range(0.0, 1.0) = 0.7;   // 0 = seco (o quarto do Tito), 1 = encharcado
uniform float agua_y = -1000.0;                       // cota (mundo) da superfície da água desta sala
uniform float piso_y = 0.0;                           // cota (mundo) do piso da sala
uniform float ao_forca : hint_range(0.0, 1.0) = 0.45;
uniform vec3 cor_agua : source_color = vec3(0.03, 0.10, 0.10);

varying vec3 p_mundo;
varying vec3 n_mundo;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	p_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(n_mundo), vec3(8.0));
	w /= (w.x + w.y + w.z);
	vec3 p = p_mundo * escala;
	vec3 cx = texture(textura, vec2(p.z, -p.y)).rgb;
	vec3 cy = texture(textura, vec2(p.x, p.z)).rgb;
	vec3 cz = texture(textura, vec2(p.x, -p.y)).rgb;
	vec3 cor = (cx * w.x + cy * w.y + cz * w.z) * COLOR.rgb * tom.rgb;

	// escorridos: faixas verticais escuras irregulares (só em parede), mais fortes quanto mais úmido
	float coluna = hash(vec2(floor(p_mundo.x * 2.3 + p_mundo.z * 2.1), 7.0));
	float escorre = step(0.62, coluna) * smoothstep(0.0, 2.2, p_mundo.y - piso_y) * (1.0 - w.y);
	cor *= 1.0 - umidade * 0.30 * escorre;

	// oclusão falsa rente ao chão
	float h = clamp((p_mundo.y - piso_y) / 1.4, 0.0, 1.0);
	cor *= 1.0 - ao_forca * (1.0 - h) * (1.0 - h);

	// acima da água: faixa molhada, mais escura e esverdeada; abaixo: submerso
	float acima = p_mundo.y - agua_y;
	float molhado = (1.0 - smoothstep(0.0, 0.65, acima)) * umidade;
	cor = mix(cor, cor * vec3(0.55, 0.78, 0.66), molhado * step(-0.02, acima));
	float sub = 1.0 - smoothstep(-0.12, 0.02, acima);
	cor = mix(cor, cor * 0.45 + cor_agua * 0.7, sub * umidade);

	ALBEDO = cor;
	ROUGHNESS = 0.95;
}
