shader_type spatial;
// Moldura das placas (Painel3D): todas as caixas coloridas de uma placa numa só malha (um draw call em vez de
// sete). A cor vem da cor de vértice e o alfa do vértice guarda o "brilho" (emissão = cor x brilho), que mantém a
// placa legível em sala escura, como o StandardMaterial3D fazia. (O Godot já entrega COLOR linearizado: conferido
// por captura contra a versão antiga, mesma cor de pixel.)
// (especular padrão, como o StandardMaterial3D de antes)

void fragment() {
	vec3 cor = COLOR.rgb;
	ALBEDO = cor;
	ROUGHNESS = 0.8;
	EMISSION = cor * COLOR.a;
}
