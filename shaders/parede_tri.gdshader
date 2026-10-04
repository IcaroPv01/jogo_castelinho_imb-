shader_type spatial;
// Parede de blocos do Castelinho: textura triplanar em coordenadas do mundo (as paredes não têm UV), filtro
// nearest (pixels visíveis) e oclusão falsa no pé da parede, calculada pela altura do fragmento no mundo.
// Sem sombras dinâmicas na web, esse escurecimento perto do chão é o que "assenta" o prédio no gramado.
// Barato: 3 leituras de textura (como o triplanar do StandardMaterial3D) e nenhuma luz extra.
// Cor de vértice (COLOR) multiplica o resultado: é assim que a Malha funde as variantes de tom numa só superfície.
render_mode specular_disabled;

uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 escala = vec3(0.6757, 0.6734, 0.6757);   // 1 / metros por repetição (x, y, z)
uniform vec4 tom : source_color = vec4(1.0);          // usado só quando o material é aplicado direto (fora da Malha)
uniform float ao_forca : hint_range(0.0, 1.0) = 0.36; // quanto escurece rente ao chão
uniform float ao_altura = 1.5;                        // metros acima do chão onde o escurecimento termina
uniform float ao_y = 0.0;                             // cota do chão

varying vec3 p_mundo;
varying vec3 n_mundo;

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
	vec3 cor = cx * w.x + cy * w.y + cz * w.z;
	float h = clamp((p_mundo.y - ao_y) / ao_altura, 0.0, 1.0);
	float ao = 1.0 - ao_forca * (1.0 - h) * (1.0 - h);
	ALBEDO = cor * COLOR.rgb * tom.rgb * ao;
	ROUGHNESS = 0.95;
}
