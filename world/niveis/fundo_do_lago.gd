class_name FundoDoLago
extends RefCounted
## O fundo do lago do final "Sala 101" (braco_morto.gd chama `chao_e_algas` e `pecas`). Tudo por sugestão: o que uma criança
## deixou para trás (sapatinhos, balde, pazinha, bola, óculos de natação, um chinelo), uma âncora com corrente, garrafas,
## pedras, um pedalinho-cisne tombado ao longe, raios de luz inclinados, a superfície vista de baixo, bolhas e partículas.
## Nada de corpo nem de sangue. Coordenadas no espaço da raiz (escala 1.5; x para o lado, -z para a frente da câmera).
## A laje de concreto da rampa vai de x -1.1 a 1.1 e termina em z -2.1; depois dela o fundo é a lama, 0,35 abaixo.
## Desempenho web: 2 Malhas (chão e peças), 8 quads aditivos, 2 emissores de partículas (<= 40 cada), 2 luzes novas, sem sombras.

const MalhaGd := preload("res://castelinho/malha.gd")
const SalasGd := preload("res://world/niveis/porao_salas.gd")

const BX := 1.1            # meia largura da laje (concreto)
const ZF := -2.1           # fim da laje
const LAMA := -0.34        # altura da lama, abaixo da laje
const TETO_Y := 1.6        # a "superfície" vista de baixo

const SH_RAIO := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 cor : source_color = vec3(0.35, 0.72, 0.78);
uniform float forca = 0.5;
uniform float fase = 0.0;
uniform float vis = 0.0;
void fragment() {
	float u = abs(UV.x - 0.5) * 2.0;
	float lado = pow(clamp(1.0 - u, 0.0, 1.0), 1.7);
	float v = UV.y;
	float pulso = 0.75 + 0.25 * sin(TIME * 0.55 + fase) + 0.1 * sin(TIME * 1.6 + fase * 2.3);
	float topo = smoothstep(0.0, 0.12, v);
	float chao = 1.0 - smoothstep(0.55, 1.0, v);
	ALBEDO = cor;
	ALPHA = forca * lado * topo * (0.25 + 0.75 * chao) * pulso * vis;
}
"""

const SH_TETO := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float vis = 0.0;
varying vec3 pw;
void vertex() { pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = pw.xz;
	float t = TIME * 0.22;
	float a = sin(q.x * 1.1 + t) + sin(q.y * 0.9 - t * 1.2) + sin((q.x + q.y) * 1.9 + t * 1.7) * 0.6 + sin((q.x - q.y) * 3.3 - t * 2.1) * 0.3;
	float b = pow(clamp(0.5 + 0.28 * a, 0.0, 1.0), 2.4);
	vec3 base = vec3(0.04, 0.13, 0.16);
	vec3 luz = vec3(0.30, 0.58, 0.60);
	ALBEDO = (base + luz * b) * vis;
}
"""

const SH_CAUSTICA := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform float vis = 0.0;
varying vec3 pw;
void vertex() { pw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = pw.xz * 1.6;
	float t = TIME * 0.35;
	float a = sin(q.x * 2.3 + t) + sin(q.y * 2.0 - t * 1.3) + sin((q.x + q.y) * 3.1 + t * 1.9);
	float c = pow(1.0 - abs(sin(a * 1.15)), 7.0);
	vec2 e = (UV - 0.5) * 2.0;
	float borda = clamp(1.0 - dot(e, e), 0.0, 1.0);
	ALBEDO = vec3(0.30, 0.62, 0.66);
	ALPHA = c * borda * 0.30 * vis;
}
"""


# ============================================================================ chão

## Altura da areia (espaço da raiz): ondulação fina e montes baixos sobre a laje; fora dela, desce até a lama.
static func altura(x: float, z: float) -> float:
	var dx: float = maxf(absf(x) - BX, 0.0)
	var dz: float = maxf(ZF - z, 0.0)
	var d: float = sqrt(dx * dx + dz * dz)
	var borda: float = smoothstep(0.0, 0.5, d)
	var onda: float = _onda(x, z)
	var monte: float = sin(x * 1.7 + 0.6) * sin(z * 1.3 - 0.4)
	return (0.003 + 0.016 * onda + 0.02 * maxf(monte, 0.0)) * (1.0 - borda) + LAMA * borda


## Cristas de ondulação: ripas quase perpendiculares ao olhar, tortas, com período de uns 0,25.
static func _onda(x: float, z: float) -> float:
	return 0.5 + 0.5 * sin(z * 25.0 + x * 5.0 + sin(x * 2.3 + z * 1.7) * 2.5)


static func _cor_chao(x: float, z: float) -> Color:
	var dx: float = maxf(absf(x) - BX, 0.0)
	var dz: float = maxf(ZF - z, 0.0)
	var borda: float = smoothstep(0.0, 0.5, sqrt(dx * dx + dz * dz))
	var onda: float = _onda(x, z)
	var c: Color = Color(0.20, 0.25, 0.25).lerp(Color(0.52, 0.58, 0.54), onda)
	# lodo: manchas escuras e esverdeadas
	var lodo: float = smoothstep(0.15, 0.55, sin(x * 3.1 + z * 2.3 + 1.0) * sin(x * 1.7 - z * 3.9))
	c = c.lerp(Color(0.10, 0.14, 0.10), lodo * 0.8)
	return c.lerp(Color(0.05, 0.07, 0.05), borda)


## Areia em ondas e lodo (uma malha, cor por vértice) e touceiras de alga. É o primeiro filho da raiz.
static func chao_e_algas(raiz: Node3D) -> void:
	var m: Malha = MalhaGd.new()
	var mv: Material = SalasGd.mat_vc()
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var passo: float = 0.08
	var x0: float = -1.8
	var z0: float = 0.7
	var nx: int = 45
	var nz: int = 72
	var pts: Array = []
	var cores: Array = []
	for j in nz + 1:
		for i in nx + 1:
			var x: float = x0 + passo * i
			var z: float = z0 - 0.05 * j
			pts.append(Vector3(x, altura(x, z), z))
			cores.append(_cor_chao(x, z))
	for j in nz:
		for i in nx:
			var a: int = j * (nx + 1) + i
			var b: int = a + 1
			var c: int = a + nx + 1
			var d: int = c + 1
			m.tri_cores(mv, pts[a], pts[c], pts[b], Vector3.UP, cores[a], cores[c], cores[b])
			m.tri_cores(mv, pts[b], pts[c], pts[d], Vector3.UP, cores[b], cores[c], cores[d])
	# touceiras de alga (fitas de duas partes, escuras)
	var touceiras: Array = [Vector2(-0.95, -0.7), Vector2(-0.6, -1.1), Vector2(0.95, -1.05), Vector2(1.15, -0.6), Vector2(-0.25, -1.5),
		Vector2(0.35, -1.6), Vector2(-1.3, -0.95), Vector2(0.75, -0.45), Vector2(1.0, -1.9), Vector2(-1.1, -1.8), Vector2(0.1, -2.0)]
	for t in touceiras:
		for k in rng.randi_range(4, 6):
			var bx: float = t.x + rng.randf_range(-0.12, 0.12)
			var bz: float = t.y + rng.randf_range(-0.12, 0.12)
			var base: Vector3 = Vector3(bx, altura(bx, bz) - 0.01, bz)
			var alt: float = rng.randf_range(0.3, 0.75)
			var giro: float = rng.randf_range(0.0, TAU)
			var lado: Vector3 = Vector3(cos(giro), 0, sin(giro))
			var inclina: Vector3 = Vector3(-lado.z, 0, lado.x) * rng.randf_range(-0.12, 0.12)
			var meio: Vector3 = base + Vector3(0, alt * 0.5, 0) + inclina
			var ponta: Vector3 = base + Vector3(0, alt, 0) + inclina * 2.6 + lado * 0.03
			var w: float = 0.028
			var c0: Color = Color(0.04, 0.1, 0.07)
			var c1: Color = Color(0.13, 0.28, 0.18)
			var c2: Color = Color(0.22, 0.42, 0.27)
			for dica in [lado.cross(Vector3.UP), -lado.cross(Vector3.UP)]:
				m.tri_cores(mv, base - lado * w, base + lado * w, meio + lado * w * 0.7, dica, c0, c0, c1)
				m.tri_cores(mv, base - lado * w, meio + lado * w * 0.7, meio - lado * w * 0.7, dica, c0, c1, c1)
				m.tri_cores(mv, meio - lado * w * 0.7, meio + lado * w * 0.7, ponta, dica, c1, c1, c2)
	m.construir_instancia(raiz, "AreiaEAlgas")


# ============================================================================ peças

## Tudo o que está no fundo, a atmosfera (raios, superfície, bolhas) e as luzes.
static func pecas(raiz: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var m: Malha = MalhaGd.new()
	var mv: Material = SalasGd.mat_vc()
	var vidro := StandardMaterial3D.new()
	vidro.vertex_color_use_as_albedo = true
	vidro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vidro.roughness = 0.2
	vidro.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_sapatinhos(m, mv)
	_balde(m, mv, rng)
	_pazinha(m, mv)
	_bola(m, mv)
	_oculos(m, mv, vidro)
	_chinelo(m, mv)
	_garrafa(m, mv, vidro, Vector3(-1.25, 0.0, -1.2), 70.0)
	_garrafa(m, mv, vidro, Vector3(1.1, 0.0, -1.15), -25.0)
	_ancora_e_corrente(m, mv, Vector3(-0.95, 0.0, -1.85))
	_pedras(m, mv, rng)
	_pedalinho(m, mv, rng)
	m.construir_instancia(raiz, "Pecas")
	_atmosfera(raiz)
	_luzes(raiz)
	_nevoa(raiz)


static func _y(x: float, z: float) -> float:
	return altura(x, z)


static func _pos(x: float, z: float, dy := 0.0) -> Vector3:
	return Vector3(x, altura(x, z) + dy, z)


static func _tf(pos: Vector3, yaw_graus: float, pitch_graus := 0.0, roll_graus := 0.0) -> Transform3D:
	var b: Basis = Basis(Vector3.UP, deg_to_rad(yaw_graus)) * Basis(Vector3.RIGHT, deg_to_rad(pitch_graus)) * Basis(Vector3.FORWARD, deg_to_rad(roll_graus))
	return Transform3D(b, pos)


static func _esc(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


## Triângulo no espaço do objeto, transformado por T; `centro` (espaço do objeto) orienta a normal para fora.
static func _tri(m: Malha, mat: Material, t: Transform3D, centro: Vector3, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var cen: Vector3 = (a + b + c) / 3.0
	m.tri_cores(mat, t * a, t * b, t * c, t.basis * (cen - centro), ca, cb, cc)


## Caixa com o centro em `c` (espaço do objeto); a parte de baixo escurece (oclusão falsa).
static func _caixa(m: Malha, mat: Material, t: Transform3D, c: Vector3, tam: Vector3, cor: Color, escuro := 0.6) -> void:
	var h: Vector3 = tam * 0.5
	for ax in 3:
		var n: Vector3 = Vector3.ZERO
		n[ax] = 1.0
		var u: Vector3 = Vector3.ZERO
		u[(ax + 1) % 3] = 1.0
		var v: Vector3 = Vector3.ZERO
		v[(ax + 2) % 3] = 1.0
		for s in [-1.0, 1.0]:
			var cf: Vector3 = c + n * s * h
			var q: Array = [cf - u * h * 1.0 - v * h, cf + u * h - v * h, cf + u * h + v * h, cf - u * h + v * h]
			var cs: Array = []
			for p in q:
				cs.append(cor if p.y > c.y - 0.001 else _esc(cor, escuro))
			_tri(m, mat, t, c, q[0], q[1], q[2], cs[0], cs[1], cs[2])
			_tri(m, mat, t, c, q[0], q[2], q[3], cs[0], cs[2], cs[3])


## Cilindro (eixo Y) com o centro em `c`, raios embaixo/em cima, tampas.
static func _cil(m: Malha, mat: Material, t: Transform3D, c: Vector3, rb: float, rt: float, alt: float, seg: int, cor: Color, tampas := true) -> void:
	var yb: float = c.y - alt * 0.5
	var yt: float = c.y + alt * 0.5
	for k in seg:
		var a0: float = TAU * float(k) / float(seg)
		var a1: float = TAU * float(k + 1) / float(seg)
		var b0: Vector3 = Vector3(c.x + cos(a0) * rb, yb, c.z + sin(a0) * rb)
		var b1: Vector3 = Vector3(c.x + cos(a1) * rb, yb, c.z + sin(a1) * rb)
		var t0: Vector3 = Vector3(c.x + cos(a0) * rt, yt, c.z + sin(a0) * rt)
		var t1: Vector3 = Vector3(c.x + cos(a1) * rt, yt, c.z + sin(a1) * rt)
		var cb: Color = _esc(cor, 0.65)
		_tri(m, mat, t, Vector3(c.x, (yb + yt) * 0.5, c.z), b0, b1, t1, cb, cb, cor)
		_tri(m, mat, t, Vector3(c.x, (yb + yt) * 0.5, c.z), b0, t1, t0, cb, cor, cor)
		if tampas:
			_tri(m, mat, t, c, Vector3(c.x, yt, c.z), t0, t1, cor, cor, cor)
			_tri(m, mat, t, c, Vector3(c.x, yb, c.z), b1, b0, cb, cb, cb)


## Elipsoide facetado, irregular, de `cor_base` (embaixo) a `cor_topo` (em cima).
static func _elipsoide(m: Malha, mat: Material, t: Transform3D, c: Vector3, r: Vector3, rng: RandomNumberGenerator, seg: int, aneis: int,
		jit: float, cor_topo: Color, cor_base: Color) -> void:
	var rings: Array = []
	var giro: float = rng.randf_range(0.0, TAU)
	for i in aneis:
		var th: float = PI * float(i + 1) / float(aneis + 1)
		var pts: Array = []
		for k in seg:
			var ph: float = giro + TAU * (float(k) + 0.5 * float(i % 2)) / float(seg)
			var j: float = 1.0 + rng.randf_range(-jit, jit)
			pts.append(c + Vector3(r.x * sin(th) * cos(ph) * j, r.y * cos(th) * (1.0 + rng.randf_range(-jit, jit) * 0.5), r.z * sin(th) * sin(ph) * j))
		rings.append(pts)
	var topo: Vector3 = c + Vector3(0, r.y, 0)
	var base: Vector3 = c - Vector3(0, r.y * 0.9, 0)
	var cor_em := func(p: Vector3) -> Color:
		return cor_base.lerp(cor_topo, clampf((p.y - (c.y - r.y)) / (2.0 * r.y), 0.0, 1.0))
	for k in seg:
		var k1: int = (k + 1) % seg
		var a: Vector3 = rings[0][k]
		var b: Vector3 = rings[0][k1]
		_tri(m, mat, t, c, topo, a, b, cor_em.call(topo), cor_em.call(a), cor_em.call(b))
		a = rings[aneis - 1][k]
		b = rings[aneis - 1][k1]
		_tri(m, mat, t, c, base, a, b, cor_em.call(base), cor_em.call(a), cor_em.call(b))
	for i in aneis - 1:
		for k in seg:
			var k1: int = (k + 1) % seg
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k1]
			var d: Vector3 = rings[i + 1][k]
			var e: Vector3 = rings[i + 1][k1]
			_tri(m, mat, t, c, a, d, b, cor_em.call(a), cor_em.call(d), cor_em.call(b))
			_tri(m, mat, t, c, b, d, e, cor_em.call(b), cor_em.call(d), cor_em.call(e))


## Tubo (prisma de `lados` faces) por uma linha de pontos (espaço do objeto).
static func _tubo(m: Malha, mat: Material, t: Transform3D, pts: Array, r: float, cor: Color, lados := 5) -> void:
	var aneis: Array = []
	for i in pts.size():
		var d: Vector3 = Vector3.ZERO
		if i > 0:
			d += (pts[i] - pts[i - 1]).normalized()
		if i < pts.size() - 1:
			d += (pts[i + 1] - pts[i]).normalized()
		d = d.normalized()
		var ref: Vector3 = Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var u: Vector3 = d.cross(ref).normalized()
		var v: Vector3 = d.cross(u).normalized()
		var anel: Array = []
		for k in lados:
			var a: float = TAU * float(k) / float(lados)
			anel.append(pts[i] + (u * cos(a) + v * sin(a)) * r)
		aneis.append(anel)
	for i in pts.size() - 1:
		for k in lados:
			var k1: int = (k + 1) % lados
			var cen: Vector3 = (pts[i] + pts[i + 1]) * 0.5
			var cb: Color = _esc(cor, 0.7)
			_tri(m, mat, t, cen, aneis[i][k], aneis[i][k1], aneis[i + 1][k1], cb, cb, cor)
			_tri(m, mat, t, cen, aneis[i][k], aneis[i + 1][k1], aneis[i + 1][k], cb, cor, cor)


static func _sapatinhos(m: Malha, mv: Material) -> void:
	var branco: Color = Color(0.82, 0.82, 0.76)
	var azul: Color = Color(0.22, 0.38, 0.85)
	for i in 2:
		var x: float = -0.2 + i * 0.17
		var z: float = -0.62 - i * 0.08
		var tf: Transform3D = _tf(_pos(x, z, 0.012), rad_to_deg(0.25 - i * 0.7))
		_caixa(m, mv, tf, Vector3.ZERO, Vector3(0.09, 0.025, 0.2), branco)
		_caixa(m, mv, tf, Vector3(0, 0.043, -0.03), Vector3(0.08, 0.06, 0.13), azul)
		_caixa(m, mv, tf, Vector3(0, 0.03, 0.06), Vector3(0.075, 0.035, 0.06), azul)     # a biqueira baixa
		_caixa(m, mv, tf, Vector3(0, 0.062, -0.055), Vector3(0.06, 0.008, 0.045), Color(0.1, 0.12, 0.3))     # a boca do tênis


static func _balde(m: Malha, mv: Material, rng: RandomNumberGenerator) -> void:
	var tf: Transform3D = _tf(_pos(0.38, -0.78, 0.09), 25.0, 0.0, 80.0)
	var cor: Color = Color(0.9, 0.14, 0.09)
	_cil(m, mv, tf, Vector3.ZERO, 0.12, 0.17, 0.26, 10, cor, false)
	_cil(m, mv, tf, Vector3(0, -0.12, 0), 0.12, 0.12, 0.012, 10, _esc(cor, 0.8))      # o fundo
	_cil(m, mv, tf, Vector3(0, 0.125, 0), 0.172, 0.172, 0.012, 10, _esc(cor, 0.85), false)     # o aro da boca
	# areia que ficou dentro, derramada na boca
	_elipsoide(m, mv, _tf(_pos(0.2, -0.86, 0.0), 0.0), Vector3.ZERO, Vector3(0.12, 0.025, 0.09), rng, 6, 2, 0.15, Color(0.42, 0.47, 0.44), Color(0.2, 0.24, 0.23))


static func _pazinha(m: Malha, mv: Material) -> void:
	var amarelo: Color = Color(1.0, 0.82, 0.12)
	var tf: Transform3D = _tf(_pos(0.18, -0.32, 0.012), -125.0, -4.0)
	_caixa(m, mv, tf, Vector3.ZERO, Vector3(0.075, 0.009, 0.08), amarelo)                # a lâmina
	_caixa(m, mv, tf, Vector3(-0.0375, 0.012, 0.0), Vector3(0.009, 0.02, 0.08), _esc(amarelo, 0.9))      # a borda de cada lado
	_caixa(m, mv, tf, Vector3(0.0375, 0.012, 0.0), Vector3(0.009, 0.02, 0.08), _esc(amarelo, 0.9))
	_caixa(m, mv, tf, Vector3(0, 0.012, -0.04), Vector3(0.075, 0.02, 0.009), _esc(amarelo, 0.9))
	_caixa(m, mv, tf, Vector3(0, 0.004, 0.075), Vector3(0.022, 0.01, 0.07), amarelo)     # o pescoço
	_caixa(m, mv, tf, Vector3(0, 0.004, 0.16), Vector3(0.02, 0.012, 0.11), _esc(amarelo, 0.95))     # o cabo
	_caixa(m, mv, tf, Vector3(0, 0.004, 0.225), Vector3(0.07, 0.012, 0.014), amarelo)               # a argola do cabo
	_caixa(m, mv, tf, Vector3(-0.03, 0.004, 0.25), Vector3(0.014, 0.012, 0.05), amarelo)
	_caixa(m, mv, tf, Vector3(0.03, 0.004, 0.25), Vector3(0.014, 0.012, 0.05), amarelo)


## Bolinha de praia listrada, afundada pela metade.
static func _bola(m: Malha, mv: Material) -> void:
	var tf: Transform3D = _tf(_pos(-0.62, -0.62, 0.03), 0.0, 20.0, 15.0)
	var paineis: Array = [Color(0.78, 0.18, 0.14), Color(0.82, 0.82, 0.76), Color(0.2, 0.36, 0.74), Color(0.82, 0.82, 0.76)]
	var seg: int = 12
	var aneis: int = 5
	var r: float = 0.06
	var pts: Array = []
	for i in aneis + 1:
		var th: float = PI * float(i) / float(aneis)
		var linha: Array = []
		for k in seg + 1:
			var ph: float = TAU * float(k) / float(seg)
			linha.append(Vector3(r * sin(th) * cos(ph), r * cos(th), r * sin(th) * sin(ph)))
		pts.append(linha)
	for i in aneis:
		for k in seg:
			var cor: Color = paineis[(k / 3) % paineis.size()]
			var tom: float = 0.7 + 0.3 * clampf(float(aneis - i) / float(aneis), 0.0, 1.0)
			cor = _esc(cor, tom)
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][k + 1]
			var c: Vector3 = pts[i + 1][k]
			var d: Vector3 = pts[i + 1][k + 1]
			_tri(m, mv, tf, Vector3.ZERO, a, c, b, cor, cor, cor)
			_tri(m, mv, tf, Vector3.ZERO, b, c, d, cor, cor, cor)


## Óculos de natação infantil, caídos de barriga para cima, com a tira em laço por trás.
static func _oculos(m: Malha, mv: Material, vidro: Material) -> void:
	var tf: Transform3D = _tf(_pos(-0.3, -0.4, 0.025), 12.0, 0.0, 8.0)
	tf.basis = tf.basis.scaled(Vector3.ONE * 0.75)
	var borracha: Color = Color(0.14, 0.24, 0.6)
	for lado in [-1.0, 1.0]:
		var c: Vector3 = Vector3(lado * 0.055, 0.0, 0.0)
		_cil(m, mv, tf, c, 0.046, 0.04, 0.03, 8, borracha, false)
		_cil(m, vidro, tf, c + Vector3(0, 0.006, 0), 0.034, 0.034, 0.03, 8, Color(0.6, 0.9, 0.95, 0.5), true)
	_caixa(m, mv, tf, Vector3.ZERO, Vector3(0.03, 0.014, 0.02), borracha)     # a ponte do nariz
	var tira: Array = []
	for k in 17:
		var a: float = PI * float(k) / 16.0
		tira.append(Vector3(cos(a) * 0.12, 0.0, -0.045 - sin(a) * 0.12))
	_tubo(m, mv, tf, tira, 0.007, Color(0.06, 0.07, 0.12), 4)


static func _chinelo(m: Malha, mv: Material) -> void:
	var rosa: Color = Color(0.78, 0.36, 0.5)
	var tf: Transform3D = _tf(_pos(0.2, -0.56, 0.01), 35.0)
	_caixa(m, mv, tf, Vector3(0, 0, 0.07), Vector3(0.085, 0.016, 0.13), rosa)            # a ponta
	_caixa(m, mv, tf, Vector3(0, 0, -0.04), Vector3(0.075, 0.016, 0.1), _esc(rosa, 0.92))   # o calcanhar
	_caixa(m, mv, tf, Vector3(0, 0, 0.0), Vector3(0.07, 0.016, 0.05), _esc(rosa, 0.96))
	var tira: Color = Color(0.85, 0.8, 0.45)
	_tubo(m, mv, tf, [Vector3(0, 0.012, 0.075), Vector3(-0.025, 0.03, 0.03), Vector3(-0.04, 0.012, 0.0)], 0.007, tira, 4)
	_tubo(m, mv, tf, [Vector3(0, 0.012, 0.075), Vector3(0.025, 0.03, 0.03), Vector3(0.04, 0.012, 0.0)], 0.007, tira, 4)


static func _garrafa(m: Malha, mv: Material, vidro: Material, p: Vector3, yaw: float) -> void:
	var tf: Transform3D = _tf(_pos(p.x, p.z, 0.026), yaw, 0.0, 90.0)
	var verde: Color = Color(0.22, 0.5, 0.3, 0.6)
	_cil(m, vidro, tf, Vector3.ZERO, 0.028, 0.028, 0.15, 7, verde)
	_cil(m, vidro, tf, Vector3(0, 0.095, 0), 0.028, 0.012, 0.045, 7, verde, false)
	_cil(m, vidro, tf, Vector3(0, 0.15, 0), 0.012, 0.012, 0.07, 7, verde)
	_cil(m, mv, tf, Vector3(0, 0.188, 0), 0.015, 0.015, 0.012, 7, Color(0.3, 0.3, 0.32))     # a tampinha


static func _pedras(m: Malha, mv: Material, rng: RandomNumberGenerator) -> void:
	var lista: Array = [Vector4(1.05, -0.55, 0.14, 0.7), Vector4(-1.05, -0.3, 0.1, 0.8), Vector4(0.92, -1.4, 0.2, 0.7), Vector4(-0.95, -2.0, 0.16, 0.8),
		Vector4(0.2, -2.05, 0.12, 0.8), Vector4(1.38, -1.0, 0.25, 0.7), Vector4(-1.4, -1.2, 0.2, 0.7), Vector4(-0.1, -2.4, 0.3, 0.6),
		Vector4(0.62, -0.3, 0.03, 0.8), Vector4(0.7, -0.34, 0.025, 0.8), Vector4(0.05, -0.15, 0.02, 0.8), Vector4(-0.55, -0.22, 0.028, 0.8)]
	for pd in lista:
		var r: float = pd.z
		var tf: Transform3D = _tf(_pos(pd.x, pd.y, r * pd.w * 0.3), rng.randf_range(0.0, 360.0))
		_elipsoide(m, mv, tf, Vector3.ZERO, Vector3(r, r * pd.w, r * rng.randf_range(0.7, 1.0)), rng, 7, 3, 0.16, Color(0.36, 0.4, 0.4), Color(0.12, 0.15, 0.15))


static func _ancora_e_corrente(m: Malha, mv: Material, p: Vector3) -> void:
	var ferrugem: Color = Color(0.4, 0.2, 0.1)
	var tf: Transform3D = _tf(_pos(p.x, p.z, 0.02), 140.0, 0.0, 14.0)
	# a âncora deitada: haste ao longo de z, cepo atravessado, dois braços em V com as unhas
	_caixa(m, mv, tf, Vector3.ZERO, Vector3(0.026, 0.026, 0.4), ferrugem)
	_caixa(m, mv, tf, Vector3(0, 0.01, -0.15), Vector3(0.22, 0.02, 0.02), _esc(ferrugem, 0.9))
	for lado in [-1.0, 1.0]:
		var tb: Transform3D = tf * Transform3D(Basis(Vector3.UP, deg_to_rad(lado * 38.0)), Vector3(lado * 0.045, 0, 0.2))
		_caixa(m, mv, tb, Vector3(0, 0, -0.0), Vector3(0.024, 0.024, 0.16), _esc(ferrugem, 0.95))
		_caixa(m, mv, tb, Vector3(0, 0, 0.09), Vector3(0.05, 0.016, 0.04), _esc(ferrugem, 0.85))
	_tubo(m, mv, tf, [Vector3(0, 0, -0.2), Vector3(0.025, 0.0, -0.24), Vector3(0, 0.0, -0.28), Vector3(-0.025, 0, -0.24), Vector3(0, 0, -0.2)], 0.008, ferrugem, 4)     # o anel
	# a corrente: sai do anel, serpenteia pela laje e escorre pela beira para a lama
	var ini: Vector3 = Vector3(p.x, 0.0, p.z) + (tf.basis * Vector3(0, 0, -0.28))
	var dir: Vector2 = Vector2(-0.82, -0.57)
	for i in 22:
		var s: float = 0.058 * float(i + 1)
		var onda: float = sin(float(i) * 0.5) * 0.045
		var x: float = ini.x + dir.x * s - dir.y * onda
		var z: float = ini.z + dir.y * s + dir.x * onda
		var yaw: float = rad_to_deg(atan2(-dir.y, dir.x)) + 60.0 * cos(float(i) * 0.5)
		var elo: Transform3D = _tf(_pos(x, z, 0.012), yaw, 0.0, 90.0 if i % 2 == 0 else 0.0)
		_caixa(m, mv, elo, Vector3.ZERO, Vector3(0.05, 0.012, 0.024), _esc(ferrugem, 0.85 + 0.25 * float(i % 3) * 0.3))


## Pedalinho-cisne afundado e tombado de lado, longe, na lama: só a silhueta pálida (casco, banco, pescoço torto, bico).
static func _pedalinho(m: Malha, mv: Material, rng: RandomNumberGenerator) -> void:
	var tf: Transform3D = _tf(Vector3(0.1, LAMA + 0.3, -5.2), 20.0, 55.0, 0.0)
	var pal: Color = Color(0.74, 0.78, 0.77)
	_elipsoide(m, mv, tf, Vector3.ZERO, Vector3(0.78, 0.3, 0.4), rng, 10, 4, 0.05, pal, Color(0.2, 0.26, 0.26))
	_caixa(m, mv, tf, Vector3(0.08, 0.12, 0), Vector3(0.3, 0.05, 0.5), Color(0.25, 0.3, 0.52))       # o banco
	_caixa(m, mv, tf, Vector3(0.2, 0.22, 0), Vector3(0.04, 0.14, 0.46), Color(0.55, 0.58, 0.58))      # o encosto
	_elipsoide(m, mv, tf, Vector3(0.74, 0.2, 0), Vector3(0.14, 0.12, 0.08), rng, 6, 3, 0.08, pal, Color(0.3, 0.36, 0.36))    # o rabo
	var pescoco: Array = [Vector3(-0.62, 0.1, 0), Vector3(-0.84, 0.3, 0), Vector3(-0.88, 0.62, 0), Vector3(-0.78, 0.88, 0), Vector3(-0.62, 0.94, 0)]
	_tubo(m, mv, tf, pescoco, 0.06, pal, 6)
	_elipsoide(m, mv, tf, Vector3(-0.55, 0.94, 0), Vector3(0.09, 0.065, 0.06), rng, 6, 3, 0.05, pal, Color(0.4, 0.44, 0.44))     # a cabeça
	_caixa(m, mv, tf, Vector3(-0.44, 0.92, 0), Vector3(0.12, 0.025, 0.05), Color(0.8, 0.45, 0.16))    # o bico
	_tubo(m, mv, tf, [Vector3(0.3, -0.2, 0.15), Vector3(0.38, -0.34, 0.34)], 0.016, Color(0.3, 0.3, 0.32), 4)     # o pedal


# ============================================================================ atmosfera

static func _shader_mat(codigo: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = codigo
	var sm := ShaderMaterial.new()
	sm.shader = sh
	return sm


## Raios inclinados, superfície vista de baixo, brilho de caustica sobre a areia, bolhas e partículas.
static func _atmosfera(raiz: Node3D) -> void:
	var mats: Array = []
	# raios de luz: faixas em z de -2.8 a -6.2, inclinadas, que se apagam rumo ao fundo
	var raios: Array = [Vector4(-1.6, -2.6, 0.8, 0.0), Vector4(-0.5, -3.4, 1.3, 1.3), Vector4(1.0, -3.0, 0.7, 2.6), Vector4(2.0, -4.0, 1.4, 3.9),
		Vector4(-2.6, -4.6, 1.6, 5.1), Vector4(0.4, -5.8, 2.0, 6.0)]
	for rd in raios:
		var q := QuadMesh.new()
		q.size = Vector2(rd.z, 2.7)
		var mi := MeshInstance3D.new()
		mi.name = "Raio"
		mi.mesh = q
		var mt: ShaderMaterial = _shader_mat(SH_RAIO)
		mt.set_shader_parameter("fase", rd.w)
		mt.set_shader_parameter("forca", 1.2 if rd.y > -5.0 else 1.7)
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		mi.position = Vector3(rd.x, LAMA + 1.35, rd.y)
		mi.rotation.z = 0.32
		mats.append(mt)
	# a superfície vista de baixo: luz difusa que ondula
	var plano := PlaneMesh.new()
	plano.size = Vector2(60.0, 60.0)
	var teto := MeshInstance3D.new()
	teto.name = "SuperficieDeBaixo"
	teto.mesh = plano
	var mt_teto: ShaderMaterial = _shader_mat(SH_TETO)
	teto.material_override = mt_teto
	teto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(teto)
	teto.position = Vector3(0, TETO_Y, -20.0)
	mats.append(mt_teto)
	# luz ondulante no chão, em volta dos brinquedos
	var chao := PlaneMesh.new()
	chao.size = Vector2(3.4, 4.4)
	var caus := MeshInstance3D.new()
	caus.name = "BrilhoNaAreia"
	caus.mesh = chao
	var mt_c: ShaderMaterial = _shader_mat(SH_CAUSTICA)
	caus.material_override = mt_c
	caus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(caus)
	caus.position = Vector3(0, 0.05, -0.9)
	mats.append(mt_c)
	# tudo aparece devagar (o resto do fundo já está lá quando os olhos se acostumam)
	var tw: Tween = raiz.create_tween().set_parallel()
	for mt in mats:
		mt.set_shader_parameter("vis", 0.0)
		tw.tween_property(mt, "shader_parameter/vis", 1.0, 2.5)
	# bolhas subindo do fundo e poeira em suspensão
	_particulas(raiz, "Bolhas", 30, Vector3(-0.1, 0.02, -1.0), Vector3(0.9, 0.01, 0.45), 0.1, 0.2, Vector3(0.1, 1, 0), 10.0, 5.0, 0.009, Color(0.7, 0.9, 1.0, 0.45))
	_particulas(raiz, "Poeira", 36, Vector3(0, 0.45, -1.4), Vector3(1.6, 0.4, 1.8), 0.01, 0.04, Vector3(0, 1, 0), 180.0, 14.0, 0.005, Color(0.75, 0.9, 0.95, 0.4))


static func _particulas(raiz: Node3D, nome: String, qtd: int, pos: Vector3, caixa: Vector3, v0: float, v1: float, dir: Vector3, abertura: float,
		vida: float, raio: float, cor: Color) -> void:
	var p := CPUParticles3D.new()
	p.name = nome
	p.amount = qtd
	p.lifetime = vida
	p.preprocess = vida
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = caixa
	p.direction = dir
	p.spread = abertura
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	var esfera := SphereMesh.new()
	esfera.radius = raio
	esfera.height = raio * 2.0
	esfera.radial_segments = 6
	esfera.rings = 3
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = cor
	esfera.material = mt
	p.mesh = esfera
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(p)
	p.position = pos


## A luz fria e fraca em cima dos brinquedos (como antes) e uma segunda, esverdeada, sobre o pedalinho ao longe.
static func _luzes(raiz: Node3D) -> void:
	var luz := OmniLight3D.new()
	luz.name = "LuzDosBrinquedos"
	luz.position = Vector3(0.05, 0.75, -0.35)
	luz.light_color = Color(0.55, 0.78, 1.0)
	luz.light_energy = 2.6
	luz.omni_range = 4.5
	luz.shadow_enabled = false
	raiz.add_child(luz)
	var luz2 := OmniLight3D.new()
	luz2.name = "LuzDoPedalinho"
	luz2.position = Vector3(-1.3, 1.0, -4.0)
	luz2.light_color = Color(0.5, 0.85, 0.8)
	luz2.light_energy = 3.0
	luz2.omni_range = 3.6
	luz2.shadow_enabled = false
	raiz.add_child(luz2)


## A névoa fica mais azul-esverdeada (a de `_afundar` é quase preta): dá profundidade sem apagar o quadro.
static func _nevoa(raiz: Node3D) -> void:
	var nivel: Node = raiz.get_parent()
	if nivel == null or not ("env" in nivel):
		return
	var env: Environment = nivel.get("env")
	if env == null:
		return
	var tw: Tween = raiz.create_tween().set_parallel()
	tw.tween_property(env, "fog_light_color", Color(0.025, 0.09, 0.11), 2.5)
	tw.tween_property(env, "fog_depth_end", 13.0, 2.5)
