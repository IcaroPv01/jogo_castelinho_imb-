shader_type spatial;
// Escada que desce "para dentro" de um quad (revisão V2): a porta zebrada do hall (sala 80) e o alçapão da Sala
// Medieval em 2019 eram um retângulo preto e uma grelha pintada no chão. Aqui um raio caminha por uma escada
// VIRTUAL atrás do quad (mapeamento de interior, como as janelas falsas de prédio), com degraus de pedra, paredes de
// tijolo, um fio de água descendo pelos degraus e um brilho frio lá no fundo. É 1 draw call e nenhuma geometria:
// o chão e a parede continuam sólidos (descer é pela interação, como antes).
//
// Espaço local do quad: plano z = 0, frente +z. Coordenadas da escada: u (de lado a lado), h (altura, para cima),
// d (para a frente, para dentro da escada).
//   modo 0 (porta na parede): u = x, h = y, d = -z. A escada começa na soleira e desce para dentro da parede.
//   modo 1 (alçapão no chão; o nó é girado para o +z local apontar para cima): u = x, h = z, d = y.
// Compatibility/WebGL2: um laço de 56 passos num quad pequeno; filtro "pixelado" pela grade `pixels`.
render_mode unshaded, cull_back, depth_draw_opaque;

uniform int modo = 0;
uniform vec3 origem = vec3(0.0);          // somado a VERTEX: põe a soleira (porta) ou o centro do vão (alçapão) no zero
uniform float meia_largura = 0.5;
uniform float pisada = 0.32;               // profundidade de cada degrau
uniform float espelho = 0.16;              // altura de cada degrau
uniform float alto = 2.1;                  // porta: altura do vão (o teto desce junto com a escada)
uniform vec2 vao_d = vec2(-0.6, 0.6);      // alçapão: o vão ao longo de d
uniform vec3 cor_pedra : source_color = vec3(0.40, 0.26, 0.22);
uniform vec3 cor_degrau : source_color = vec3(0.60, 0.56, 0.50);
uniform vec3 cor_agua : source_color = vec3(0.42, 0.62, 0.70);
uniform vec3 cor_fundo : source_color = vec3(0.10, 0.26, 0.28);
uniform float luz = 1.15;
uniform float agua = 1.0;
uniform float pixels = 40.0;               // pixels por metro (estilo PS1)

varying vec3 p_loc;
varying vec3 cam_loc;

void vertex() {
	p_loc = VERTEX + origem;
	cam_loc = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz + origem;
}

vec3 para_escada(vec3 v) {
	return modo == 0 ? vec3(v.x, v.y, -v.z) : vec3(v.x, v.z, v.y);
}

float tijolo(float a, float b) {
	float fila = floor(b * 6.0);
	float bx = fract(a * 3.2 + fila * 0.5);
	float by = fract(b * 6.0);
	float junta = step(bx, 0.06) + step(by, 0.12);
	float var = fract(sin(dot(vec2(floor(a * 3.2 + fila * 0.5), fila), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(0.78 + 0.3 * var, 0.45, clamp(junta, 0.0, 1.0));
}

void fragment() {
	vec3 pq = floor(p_loc * pixels + 0.5) / pixels;          // a grade de pixels fica presa ao quad
	vec3 ro = para_escada(pq);
	vec3 rd = normalize(para_escada(p_loc - cam_loc));
	float d0 = modo == 0 ? 0.12 : vao_d.x;
	float incl = espelho / pisada;
	vec3 col = cor_fundo * 0.25;
	float prof = 6.0;
	float t = 0.0;
	for (int i = 0; i < 56; i++) {
		t += 0.025 + t * 0.06;
		vec3 q = ro + rd * t;
		float u = q.x;
		float h = q.y;
		float d = q.z;
		float k = max(0.0, ceil((d - d0) / pisada));
		float hf = -espelho * k;
		float hc = modo == 0 ? alto - max(0.0, d) * incl : (d < vao_d.y ? 99.0 : -0.12 - (d - vao_d.y) * incl);
		prof = max(0.0, d - d0) * 0.55 + max(0.0, -h) * 0.35;
		if (modo == 1 && d < vao_d.x - 0.02) {                     // parede do fundo do alçapão (embaixo da borda)
			col = cor_pedra * tijolo(u, h) * 0.8;
			break;
		}
		if (abs(u) > meia_largura) {                               // paredes laterais de tijolo
			col = cor_pedra * tijolo(d, h);
			break;
		}
		if (h < hf) {                                              // pisada: quina acesa na ponta, sombra no começo
			// (a escada desce para longe: os espelhos ficam de costas para quem olha; o que separa os degraus é a
			// quina clara e a faixa de sombra logo abaixo da quina anterior)
			float f = fract((d - d0) / pisada);
			col = cor_degrau;
			col *= f > 0.84 ? 1.4 : (f < 0.2 && k > 1.0 ? 0.5 : 1.0);
			// fio de água descendo pelo meio da escada, com brilho que corre para baixo
			float fio = 1.0 - smoothstep(0.1, 0.32, abs(u + sin(d * 3.1) * 0.09));
			float corre = 0.5 + 0.5 * sin(d * 13.0 - TIME * 4.0 + u * 3.0);
			col = mix(col, cor_agua * (0.8 + 0.6 * corre), agua * fio * 0.75);
			break;
		}
		if (h > hc) {                                              // teto (desce com a escada)
			col = cor_pedra * 0.55 * tijolo(u, d);
			break;
		}
		if (d > 4.6 || t > 7.0) {                                  // o fundo: escuro, com um brilho frio de água
			col = cor_fundo;
			prof = 2.0;
			break;
		}
	}
	float luz_prof = exp(-prof * 0.75);
	col = col * luz * luz_prof + cor_fundo * (1.0 - luz_prof) * 0.35;
	ALBEDO = col;
}
