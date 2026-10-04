shader_type canvas_item;
// Pós-processamento de tela cheia (camada de Efeitos). Compatibility/WebGL2: só lê a tela com
// hint_screen_texture. Tudo é dosado por `corrupcao` (0 = imagem intacta). Quando corrupcao,
// pulso e visor são zero, o autoload esconde o ColorRect e nem chega a rodar.
//
//  corrupcao  0..1  pixelização leve, dithering/menos cores, dessaturação, vinheta, grão,
//                   aberração cromática e (acima de ~0.5) faixas de glitch
//  pulso      0..1  glitch forte momentâneo (sustos)
//  visor      0..1  moldura do Visor do Tempo (plástico vermelho, dois olhos redondos, sépia)

uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;
uniform float corrupcao : hint_range(0.0, 1.0) = 0.0;
uniform float pulso : hint_range(0.0, 1.5) = 0.0;
uniform float visor : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	float c = corrupcao;
	float p = pulso;
	vec2 uv = SCREEN_UV;

	// ---------------------------------------------------------- Visor: cada olho vê o centro da tela
	vec2 q = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	vec2 centro = vec2(0.0);
	float dcirc = 0.0;
	float dentro = 1.0;
	if (visor > 0.001) {
		float raio_base = min(0.42, (0.5 * aspect - 0.05) * 0.5);
		float raio = raio_base * (0.25 + 0.75 * visor);
		float lado = q.x < 0.0 ? -1.0 : 1.0;
		centro = vec2(lado * (raio_base + 0.02), 0.0);
		dcirc = length(q - centro) - raio;
		dentro = step(dcirc, 0.0);
		uv = vec2(0.5) + (q - centro) / vec2(aspect, 1.0) * 1.15;
		uv.x += lado * 0.004; // estéreo falso
	}

	// ---------------------------------------------------------- glitch: faixas horizontais + tremor
	float g = smoothstep(0.45, 0.8, c);
	float fatia = floor(TIME * 7.0);
	float dispara = step(1.0 - 0.10 * g - 0.85 * min(p, 1.0), hash11(fatia * 1.37));
	float cy = hash11(fatia * 3.1 + 5.0);
	float alt = 0.008 + 0.06 * hash11(fatia * 5.3 + 1.0) + 0.08 * p;
	float faixa = dispara * step(abs(uv.y - cy), alt);
	uv.x += faixa * (hash11(fatia * 7.7 + 2.0) - 0.5) * (0.07 + 0.2 * p);
	float tremor = floor(TIME * 30.0);
	uv += p * (vec2(hash11(tremor), hash11(tremor + 9.0)) - 0.5) * 0.02;

	// ---------------------------------------------------------- pixelização (resolução efetiva cai)
	float k = smoothstep(0.1, 0.65, c);
	float linhas = mix(res.y, 240.0, k);
	linhas = mix(linhas, 150.0, min(p, 1.0) * 0.6);
	if (linhas < res.y - 0.5) {
		vec2 grade = vec2(linhas * aspect, linhas);
		uv = (floor(uv * grade) + 0.5) / grade;
	}

	// ---------------------------------------------------------- aberração cromática
	float ca = 0.0045 * smoothstep(0.0, 0.7, c) + 0.012 * p + faixa * 0.01;
	vec3 col;
	if (ca > 0.00002) {
		vec2 off = (uv - 0.5) * ca * 2.0 + vec2(ca * 0.25, 0.0);
		col = vec3(texture(tela, uv + off).r, texture(tela, uv).g, texture(tela, uv - off).b);
	} else {
		col = texture(tela, uv).rgb;
	}

	// ---------------------------------------------------------- cor: dessaturação, tom frio, meios-tons mais escuros
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), 0.7 * smoothstep(0.05, 0.9, c));
	col *= mix(vec3(1.0), vec3(0.94, 1.0, 0.98), smoothstep(0.2, 0.9, c));
	if (c > 0.001) {
		col = pow(max(col, vec3(0.0)), vec3(1.0 + 0.35 * c));
	}
	float inverte = p * step(0.6, hash11(floor(TIME * 24.0))) * 0.5;
	col = mix(col, vec3(1.0) - col, inverte);

	// ---------------------------------------------------------- dithering ordenado (Bayer 4x4) + menos cores
	float d = smoothstep(0.1, 0.7, c);
	if (d > 0.001) {
		float niveis = mix(256.0, 16.0, d);
		vec2 bloco = floor(FRAGCOORD.xy / max(res.y / linhas, 1.0));
		int idx = int(mod(bloco.x, 4.0)) + 4 * int(mod(bloco.y, 4.0));
		float limiar = BAYER[idx] / 16.0 + 1.0 / 32.0;
		col = floor(col * (niveis - 1.0) + limiar) / (niveis - 1.0);
	}

	// ---------------------------------------------------------- vinheta e grão
	vec2 vv = (SCREEN_UV - 0.5) * vec2(aspect * 0.85, 1.0);
	float v = smoothstep(0.3, 0.95, length(vv) * 1.25);
	col *= 1.0 - v * (0.6 * smoothstep(0.0, 0.6, c) + 0.3 * min(p, 1.0));
	float grao = hash21(FRAGCOORD.xy + floor(TIME * 24.0) * 17.0) - 0.5;
	col += grao * (0.07 * smoothstep(0.0, 0.8, c) + 0.12 * p);

	// ---------------------------------------------------------- moldura do Visor do Tempo
	if (visor > 0.001) {
		// sépia leve dentro das lentes + escurecimento nas bordas
		float l2 = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 sepia = vec3(l2 * 1.12, l2 * 0.88, l2 * 0.64);
		col = mix(col, sepia, 0.55);
		col *= 1.0 - 0.55 * smoothstep(-0.14, 0.0, dcirc);

		vec2 n = normalize(q - centro + vec2(1e-5));
		float anel = smoothstep(0.0, 0.01, dcirc) * (1.0 - smoothstep(0.012, 0.03, dcirc));
		float bisel = smoothstep(0.01, 0.1, dcirc);
		vec3 plastico = vec3(0.80, 0.07, 0.08) * (0.72 + 0.28 * bisel);
		float luz = max(dot(n, normalize(vec2(-0.6, -0.8))), 0.0);
		plastico += vec3(1.0, 0.72, 0.66) * pow(luz, 6.0) * (1.0 - smoothstep(0.0, 0.09, dcirc)) * 0.5;
		plastico = mix(plastico, vec3(0.06, 0.0, 0.0), anel);
		plastico *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 0.006, abs(q.x)));
		plastico *= 0.85 - 0.3 * q.y;
		plastico += (hash21(FRAGCOORD.xy * 0.5) - 0.5) * 0.03;
		col = mix(plastico, col, dentro);
	}

	COLOR = vec4(col, 1.0);
}
