shader_type spatial;
// Reflexo longo de uma luz sobre água parada (revisão V2, Braço Morto): uma faixa deitada na água que sai do pé da
// luz e aponta SEMPRE para a câmera (o reflexo de verdade fica na linha entre a luz e quem olha). Instância de
// MultiMesh: a origem da instância é o começo da faixa, na margem de lá; UV.x atravessa a faixa, UV.y vai da margem
// até perto do jogador. A textura (metade direita de `faixa`) tem as quebras de marola; elas ondulam devagar.
// Sem luz, 1 draw call para todos os reflexos. O nó precisa de `extra_cull_margin` (a faixa se move no shader).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform sampler2D faixa : source_color, filter_nearest, repeat_disable;
uniform vec4 cor : source_color = vec4(1.0, 0.72, 0.36, 0.9);
uniform float comprimento = 26.0;
uniform float largura = 0.5;
uniform float abertura = 2.0;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 d = cam.xz - o.xz;
	float dist = max(length(d), 0.001);
	d /= dist;
	vec2 lado = vec2(-d.y, d.x);
	float len = min(comprimento, dist * 0.85);
	float u = UV.x * 2.0 - 1.0;
	vec2 xz = o.xz + d * (UV.y * len) + lado * (u * largura * mix(1.0, abertura, UV.y));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(xz.x, o.y, xz.y, 1.0)).xyz;
}

void fragment() {
	float marola = sin(UV.y * 38.0 - TIME * 1.3) * 0.06;
	vec4 t = texture(faixa, vec2(0.5 + 0.5 * clamp(UV.x + marola, 0.0, 1.0), UV.y));
	ALBEDO = cor.rgb;
	ALPHA = t.a * cor.a;
}
