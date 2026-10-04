shader_type sky;
// Céu com nuvens "de desenho" (Flash/PS1): degradê topo -> horizonte, camada de nuvens projetada num plano alto
// (textura tileável assets/textures/nuvens.png: R = densidade, G = luz) com borda dura e 3 tons chapados, e o
// disco do Sol. Sem TIME: o mapa de radiância só é refeito quando a época troca os parâmetros (barato na web).

uniform vec4 cor_topo : source_color = vec4(0.42, 0.62, 0.9, 1.0);
uniform vec4 cor_horizonte : source_color = vec4(0.82, 0.89, 0.96, 1.0);
uniform vec4 cor_chao : source_color = vec4(0.6, 0.66, 0.7, 1.0);
uniform sampler2D nuvens : repeat_enable, filter_linear;
uniform vec4 cor_nuvem : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_nuvem_sombra : source_color = vec4(0.72, 0.76, 0.86, 1.0);
uniform float cobertura : hint_range(0.0, 1.0) = 0.55;   // limiar de densidade: menor = mais nuvem
uniform float escala_nuvem = 0.22;
uniform vec2 deslocamento = vec2(0.0);
uniform float sol_tamanho = 0.9993;
uniform float sol_forca = 1.0;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 ceu = mix(cor_horizonte.rgb, cor_topo.rgb, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		ceu = mix(cor_horizonte.rgb, cor_chao.rgb, clamp(-h * 5.0, 0.0, 1.0));
	}
	if (LIGHT0_ENABLED) {
		float s = dot(d, LIGHT0_DIRECTION);
		float disco = smoothstep(sol_tamanho, sol_tamanho + 0.0003, s);
		float halo = pow(max(s, 0.0), 24.0) * 0.25;
		ceu += LIGHT0_COLOR * (disco * 1.5 + halo) * sol_forca;
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.15) * escala_nuvem + deslocamento;
		vec4 n = texture(nuvens, uv);
		float dens = smoothstep(cobertura, cobertura + 0.035, n.r);
		// 3 tons chapados (sombra, meio, luz), como as nuvens da tela de título
		float luz = n.g;
		vec3 meio = mix(cor_nuvem_sombra.rgb, cor_nuvem.rgb, 0.55);
		vec3 cn = luz > 0.62 ? cor_nuvem.rgb : (luz > 0.38 ? meio : cor_nuvem_sombra.rgb);
		// borda fina mais escura (contorno do desenho)
		float borda = smoothstep(cobertura, cobertura + 0.035, n.r) - smoothstep(cobertura + 0.035, cobertura + 0.07, n.r);
		cn = mix(cn, cor_nuvem_sombra.rgb * 0.9, borda * 0.6);
		float some = smoothstep(0.02, 0.22, h);
		ceu = mix(ceu, cn, dens * some);
	}
	COLOR = ceu;
}
