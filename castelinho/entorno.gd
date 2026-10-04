class_name EntornoCastelinho
extends RefCounted
## Entorno do Castelinho: lote gramado, calçadas, Av. Garibaldi (pista dupla com canteiro, ao sul), Av. Nilza
## Costa Godoy (a leste), casas vizinhas baixas, pinheiros (Pinus), postes, cercas e as barreiras invisíveis do lote.
## Épocas: 1975/2019/2020 = a cidade; 1950 = só areia, dunas e vento. O corredor de 1975 (salas 24-25) também
## é construído aqui: só existe em E1975 e passa do limite norte do lote (z = -34) até z = -82.
##
## Coordenadas do Godot: lote x -30..0, z -34..0 (origem = esquina Garibaldi x Nilza; norte = -z).

const N_S := Vector3(0, 0, 1)
const N_N := Vector3(0, 0, -1)
const N_L := Vector3(1, 0, 0)
const N_O := Vector3(-1, 0, 0)

const Z_CORREDOR_FIM := -82.0
const X_CORREDOR := -10.2        # eixo do corredor (alinhado com a porta de saída da Sala Medieval)
const L_CORREDOR := 2.3


static func construir(raiz: Node3D, c: Castelinho) -> Dictionary:
	var g_cid := Castelinho.Grupo.new("Cidade", Castelinho.ep_casa())
	var g_cerca_n := Castelinho.Grupo.new("CercaNorte", [GameState.Epoca.E2019, GameState.Epoca.E2020])
	var g_areia := Castelinho.Grupo.new("Areia_1950", [GameState.Epoca.E1950])
	var g_cor := Castelinho.Grupo.new("Corredor_1975", [GameState.Epoca.E1975])
	_chao(raiz, c, g_cid, g_areia)
	_ruas(c, g_cid)
	_lote(c, g_cid)
	_casas(c, g_cid)
	_postes(c, g_cid)
	_cercas(c, g_cid, g_cerca_n)
	_dunas(c, g_areia)
	_corredor_1975(c, g_cor)
	for g in [g_cid, g_cerca_n, g_areia, g_cor]:
		g.finalizar(raiz)
	var mm_pinus := _pinheiros(raiz, c)
	_barreiras(raiz)
	return {"cidade": g_cid, "areia": g_areia, "corredor": g_cor, "pinheiros": mm_pinus}


# ------------------------------------------------------------------ terreno
static func _chao(raiz: Node3D, c: Castelinho, g_cid: Castelinho.Grupo, g_areia: Castelinho.Grupo) -> void:
	# colisão do chão: sempre existe, em qualquer época
	var corpo := StaticBody3D.new()
	corpo.name = "ChaoColisao"
	corpo.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 1.0, 600)
	cs.shape = bs
	cs.position = Vector3(-15, -0.5, -40)
	corpo.add_child(cs)
	raiz.add_child(corpo)
	var grama: Material = Castelinho.mat_tri("grama", Vector3(2.5, 2.5, 2.5))
	var areia: Material = Castelinho.mat_tri("areia_1950", Vector3(2.5, 2.5, 2.5))
	g_cid.ext.quad(grama, Vector3(-300, 0, -340), Vector3(270, 0, -340), Vector3(270, 0, 260), Vector3(-300, 0, 260), Vector3.UP)
	g_areia.ext.quad(areia, Vector3(-300, 0, -340), Vector3(270, 0, -340), Vector3(270, 0, 260), Vector3(-300, 0, 260), Vector3.UP)


static func _plano(m: Malha, mat: Material, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	m.quad(mat, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP)


static func _ruas(c: Castelinho, g: Castelinho.Grupo) -> void:
	var m := g.ext
	var asfalto: Material = Castelinho.mat_tri("asfalto", Vector3(2, 2, 2))
	var calc: Material = Castelinho.mat_tri("calcada_lajotas", Vector3(2, 2, 2))
	var meio_fio: Material = Castelinho.mat_cor(Color(0.62, 0.62, 0.6), 0.9)
	var faixa: Material = Castelinho.mat_cor(Color(0.92, 0.92, 0.86), 0.9)
	var amarela: Material = Castelinho.mat_cor(Color(0.9, 0.75, 0.15), 0.9)
	var grama: Material = Castelinho.mat_tri("grama", Vector3(2.5, 2.5, 2.5), Color(0.9, 1.0, 0.85))
	# Av. Garibaldi (sul): pista z 2,6..8,8, canteiro 8,8..10,6, pista 10,6..16,8
	_plano(m, asfalto, -260, 262, 2.6, 8.8, 0.02)
	_plano(m, asfalto, -260, 262, 10.6, 16.8, 0.02)
	m.caixa(grama, Vector3(-260, 0, 8.8), Vector3(262, 0.14, 10.6), Malha.F_SEM_BASE, 2.5)
	m.caixa(meio_fio, Vector3(-260, 0.0, 8.7), Vector3(262, 0.15, 8.8), Malha.F_SEM_BASE)
	m.caixa(meio_fio, Vector3(-260, 0.0, 10.6), Vector3(262, 0.15, 10.7), Malha.F_SEM_BASE)
	# Av. Nilza Costa Godoy (leste): x 2,6..9,6, de norte a sul
	_plano(m, asfalto, 2.6, 9.6, -330, 17, 0.025)
	# calçadas: frente do lote (z 0..2,6), lateral leste (x 0..2,6) e do outro lado
	_plano(m, calc, -300, 2.6, 0.0, 2.6, 0.03)
	_plano(m, calc, 0.0, 2.6, -330, 0.0, 0.03)
	_plano(m, calc, -260, 262, 16.8, 19.4, 0.03)
	_plano(m, calc, 9.6, 12.2, -330, 17, 0.03)
	for z in [2.6]:
		m.caixa(meio_fio, Vector3(-300, 0.0, z), Vector3(2.6, 0.14, z + 0.12), Malha.F_SEM_BASE)
	m.caixa(meio_fio, Vector3(2.6, 0.0, -330), Vector3(2.72, 0.14, 2.6), Malha.F_SEM_BASE)
	# marcações: tracejado branco no meio de cada pista e linha dupla amarela na Nilza
	var x := -250.0
	while x < 255.0:
		m.caixa(faixa, Vector3(x, 0.03, 5.65), Vector3(x + 2.0, 0.035, 5.75), Malha.F_PY)
		m.caixa(faixa, Vector3(x, 0.03, 13.65), Vector3(x + 2.0, 0.035, 13.75), Malha.F_PY)
		x += 5.0
	var z := -320.0
	while z < 14.0:
		m.caixa(amarela, Vector3(5.98, 0.032, z), Vector3(6.02, 0.037, z + 3.0), Malha.F_PY)
		z += 6.0


## Caminho de lajotas até a porta de entrada, cascalho do lado leste, canteiros.
static func _lote(c: Castelinho, g: Castelinho.Grupo) -> void:
	var m := g.ext
	var calc: Material = Castelinho.mat_tri("calcada_lajotas", Vector3(2, 2, 2))
	var areia: Material = Castelinho.mat_tri("areia", Vector3(2, 2, 2), Color(0.85, 0.82, 0.78))
	_plano(m, calc, -5.2, -3.6, -10.95, 0.0, 0.03)
	_plano(m, calc, -7.0, -3.6, -10.95, -9.7, 0.03)
	# cascalho junto à fachada leste (foto do drone)
	_plano(m, areia, -4.9, -0.3, -24.0, -9.2, 0.015)
	# caminho de lajotas irregulares que contorna a lateral oeste até o jardim
	_plano(m, calc, -23.0, -9.0, -9.4, -8.9, 0.03)
	# árvore retorcida na frente (foto frontal 2026): tronco inclinado, galhos finos e copa rala cinza-esverdeada
	var tronco: Material = Castelinho.mat_tri("casca", Vector3(1, 1, 1), Color(0.8, 0.78, 0.72))
	var verde: Material = Castelinho.mat_cor(Color(0.5, 0.58, 0.46), 1.0)
	m.caixa(tronco, Vector3(-17.4, 0, -6.2), Vector3(-17.2, 1.4, -6.0), Malha.F_SEM_BASE)
	m.caixa(tronco, Vector3(-17.5, 1.4, -6.3), Vector3(-17.3, 2.2, -6.1), Malha.F_SEM_BASE)
	for gl in [[-18.4, 2.0, -6.4, -17.4, 2.12, -6.2], [-17.3, 2.1, -6.3, -16.2, 2.22, -6.1], [-17.4, 2.2, -6.9, -17.2, 2.32, -5.6], [-17.9, 2.4, -6.2, -16.8, 2.5, -6.0]]:
		m.caixa(tronco, Vector3(gl[0], gl[1], gl[2]), Vector3(gl[3], gl[4], gl[5]), Malha.F_SEM_BASE)
	for p in [[-18.7, 2.3, -6.9, 0.7], [-17.5, 2.7, -6.6, 0.8], [-16.4, 2.3, -6.2, 0.7], [-17.9, 2.2, -5.9, 0.6], [-16.8, 2.9, -5.9, 0.6], [-18.2, 2.8, -6.3, 0.6]]:
		m.caixa(verde, Vector3(p[0], p[1], p[2]), Vector3(p[0] + p[3], p[1] + p[3] * 0.7, p[2] + p[3] * 0.8), Malha.F_SEM_BASE)
	m.col(Vector3(-17.5, 0, -6.4), Vector3(-17.1, 2.0, -5.8))
	# lixeira de madeira e vaso (cantinhos do jardim)
	m.caixa(Castelinho.mat_tri("madeira_escura", Vector3(1, 1, 1)), Vector3(-3.0, 0, -9.8), Vector3(-2.4, 0.7, -9.2), Malha.F_SEM_BASE)


# ------------------------------------------------------------------ casas vizinhas (baixas, genéricas)
static func _casas(c: Castelinho, g: Castelinho.Grupo) -> void:
	var m := g.ext
	var cores := [Color(0.93, 0.9, 0.8), Color(0.95, 0.85, 0.45), Color(0.7, 0.82, 0.9), Color(0.92, 0.7, 0.62), Color(0.85, 0.88, 0.8)]
	var mats: Array = []
	for cor in cores:
		mats.append(Castelinho.mat_tri("reboco", Vector3(2, 2, 2), cor))
	var telha: Material = Castelinho.mat_uv("telha_ceramica")
	var porta: Material = Castelinho.mat_cor(Color(0.25, 0.2, 0.17), 0.9)
	var vid: Material = Castelinho.mat_cor(Color(0.2, 0.28, 0.32), 0.3)
	# [x, z, largura, profundidade, altura, cor, direção da fachada (a rua): "n","s","l","o"]
	var lista := [
		# sul (do outro lado da Garibaldi): olham para o norte
		[-44, 24, 10, 8, 3.2, 0, "n"], [-30, 24, 9, 8, 3.0, 1, "n"], [-17, 25, 11, 9, 3.4, 2, "n"], [-3, 24, 9, 8, 3.1, 3, "n"],
		[10, 24, 10, 9, 3.2, 4, "n"], [24, 25, 9, 8, 3.0, 0, "n"], [-58, 25, 10, 8, 3.2, 3, "n"],
		# leste (do outro lado da Nilza): olham para o oeste
		[18, -4, 8, 9, 3.2, 1, "o"], [18, -18, 9, 9, 3.0, 2, "o"], [19, -32, 8, 8, 3.1, 4, "o"], [18, -46, 9, 9, 3.2, 0, "o"],
		[18, 9, 8, 7, 3.0, 3, "o"],
		# oeste e norte do lote
		[-48, -10, 9, 9, 3.2, 4, "l"], [-49, -25, 9, 9, 3.0, 2, "l"], [-48, -42, 8, 9, 3.1, 1, "l"],
		[-24, -46, 9, 8, 3.2, 3, "s"], [-8, -47, 10, 8, 3.0, 0, "s"], [10, -48, 9, 8, 3.1, 4, "s"],
	]
	for h in lista:
		var cx_: float = h[0]
		var cz: float = h[1]
		var w: float = h[2]
		var d: float = h[3]
		var alt: float = h[4]
		m.caixa(mats[h[5]], Vector3(cx_ - w * 0.5, 0, cz - d * 0.5), Vector3(cx_ + w * 0.5, alt, cz + d * 0.5), Malha.F_SEM_BASE - Malha.F_PY)
		m.piramide(telha, Vector3(cx_, alt, cz), w + 1.0, d + 1.0, 1.8, 1.0)
		# porta e duas janelas na face voltada para a rua
		var face := Vector3.ZERO
		var fo := Vector3.ZERO
		var lado := Vector3.ZERO
		match h[6]:
			"n":
				face = N_N
				fo = Vector3(cx_, 0, cz - d * 0.5)
				lado = Vector3(1, 0, 0)
			"s":
				face = N_S
				fo = Vector3(cx_, 0, cz + d * 0.5)
				lado = Vector3(1, 0, 0)
			"l":
				face = N_L
				fo = Vector3(cx_ + w * 0.5, 0, cz)
				lado = Vector3(0, 0, 1)
			"o":
				face = N_O
				fo = Vector3(cx_ - w * 0.5, 0, cz)
				lado = Vector3(0, 0, 1)
		m.caixa(porta, fo - lado * 0.5, fo + lado * 0.5 + face * 0.05 + Vector3(0, 2.1, 0), Malha.F_TODAS)
		for k in [-1, 1]:
			var p: Vector3 = fo + lado * (2.4 * k)
			m.caixa(vid, p - lado * 0.6 + Vector3(0, 1.0, 0), p + lado * 0.6 + face * 0.05 + Vector3(0, 2.0, 0), Malha.F_TODAS)


# ------------------------------------------------------------------ postes
static func _postes(c: Castelinho, g: Castelinho.Grupo) -> void:
	var m := g.ext
	var concreto: Material = Castelinho.mat_cor(Color(0.6, 0.6, 0.58), 0.9)
	var ferro: Material = c.m.ferro
	var luz: Material = Castelinho.mat_luz(Color(1.0, 0.95, 0.8), 1.0)
	var pontos := [Vector3(-3.0, 0, 2.2), Vector3(-28.0, 0, 2.2), Vector3(-60.0, 0, 2.2), Vector3(2.2, 0, -30.0), Vector3(2.2, 0, -62.0),
		Vector3(10.0, 0, 18.0), Vector3(-30.0, 0, 18.0), Vector3(9.0, 0, -12.0)]
	for p in pontos:
		m.caixa(concreto, p + Vector3(-0.1, 0, -0.1), p + Vector3(0.1, 7.0, 0.1), Malha.F_SEM_BASE)
		m.caixa(concreto, p + Vector3(-0.6, 6.6, -0.05), p + Vector3(0.6, 6.75, 0.05), Malha.F_TODAS)
		m.caixa(ferro, p + Vector3(-1.3, 6.8, -0.05), p + Vector3(0.0, 6.88, 0.05), Malha.F_TODAS)
		m.caixa(luz, p + Vector3(-1.5, 6.72, -0.1), p + Vector3(-1.2, 6.8, 0.1), Malha.F_TODAS)


# ------------------------------------------------------------------ cercas
static func _cercas(c: Castelinho, g: Castelinho.Grupo, g_n: Castelinho.Grupo) -> void:
	var tab: Material = Castelinho.mat_tri("madeira_escura", Vector3(1, 1, 1), Color(1.2, 1.1, 1.0))
	var verde: Material = Castelinho.mat_tri("folhagem", Vector3(1, 1, 1), Color(0.75, 1.0, 0.7))
	# oeste (x = -30): tábuas de 1,6 m + moita no pé
	g.ext.caixa(tab, Vector3(-30.12, 0, -34.0), Vector3(-30.0, 1.7, 0.0), Malha.F_SEM_BASE, 1.0)
	g.ext.col(Vector3(-30.3, 0, -34.0), Vector3(-30.0, 2.0, 0.0))
	var z := -33.0
	while z < 0.0:
		g.ext.caixa(tab, Vector3(-30.25, 0, z - 0.08), Vector3(-30.0, 1.9, z + 0.08), Malha.F_TODAS, 1.0)
		z += 3.0
	# norte (z = -34): cerca e cerca-viva; some em 1975 para o corredor passar
	g_n.ext.caixa(tab, Vector3(-30.0, 0, -34.12), Vector3(0.0, 1.7, -34.0), Malha.F_SEM_BASE, 1.0)
	g_n.ext.col(Vector3(-30.0, 0, -34.3), Vector3(0.0, 2.0, -34.0))
	g.ext.caixa(verde, Vector3(-30.0, 0, -34.6), Vector3(0.0, 1.4, -33.4), Malha.F_SEM_BASE - Malha.F_NZ)
	# cerca-viva baixa ao longo da Nilza (leste do lote): moitas espaçadas
	for zz in [-30.0, -26.0, -22.5, -9.0, -6.0, -3.0]:
		g.ext.caixa(verde, Vector3(-0.8, 0, zz - 0.65), Vector3(-0.2, 0.6, zz + 0.65), Malha.F_SEM_BASE)


## Dunas baixas de areia (só E1950): colinas de baixo poligonagem ao redor.
static func _dunas(c: Castelinho, g: Castelinho.Grupo) -> void:
	var areia: Material = Castelinho.mat_tri("areia_1950", Vector3(2.5, 2.5, 2.5), Color(0.96, 0.94, 0.9))
	var dunas := [
		[-60, -20, 26, 18, 4.0], [-52, -70, 30, 22, 5.0], [20, -60, 24, 20, 4.5], [30, 10, 22, 16, 3.0],
		[-20, -90, 34, 20, 5.5], [-90, 20, 30, 18, 3.5], [60, -30, 26, 20, 4.0], [-30, 60, 32, 18, 3.5],
		[0, -130, 40, 24, 6.0], [-110, -60, 36, 22, 5.0],
	]
	for d in dunas:
		_duna(g.ext, areia, Vector3(d[0], 0, d[1]), d[2], d[3], d[4])


static func _duna(m: Malha, mat: Material, c: Vector3, rx: float, rz: float, h: float) -> void:
	var n := 7
	var pts: Array = []
	for j in n + 1:
		var linha: Array = []
		for i in n + 1:
			var gx := (float(i) / n) * 2.0 - 1.0
			var gz := (float(j) / n) * 2.0 - 1.0
			var r2 := minf(1.0, gx * gx + gz * gz)
			var y := h * (1.0 - r2) * (1.0 - r2)
			linha.append(c + Vector3(gx * rx, y, gz * rz))
		pts.append(linha)
	for j in n:
		for i in n:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var cc: Vector3 = pts[j + 1][i + 1]
			var d: Vector3 = pts[j + 1][i]
			if a.y < 0.02 and b.y < 0.02 and cc.y < 0.02 and d.y < 0.02:
				continue
			m.quad_auto(mat, a, b, cc, d, Vector3.UP, Vector2(2.5, 2.5))


# ------------------------------------------------------------------ pinheiros (MultiMesh: tronco + copa em blocos)
## Três variantes de silhueta (copa irregular); cada uma é um MultiMesh (2 superfícies: tronco e copa).
static func _pinus_mesh(var_: int) -> ArrayMesh:
	var m := Malha.new()
	var casca: Material = Castelinho.mat_tri("casca", Vector3(1, 1, 1))
	var folha: Material = Castelinho.mat_tri("folhagem", Vector3(1, 1, 1))
	var alt := 10.0 + float(var_) * 0.8
	m.caixa(casca, Vector3(-0.16, 0, -0.16), Vector3(0.16, alt, 0.16), Malha.F_SEM_BASE)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 31 + var_
	var y := 5.6 + float(var_) * 0.3
	var w := 2.9 - float(var_) * 0.2
	while y < alt - 0.8:
		var ox := rnd.randf_range(-0.35, 0.35)
		var oz := rnd.randf_range(-0.35, 0.35)
		var h := rnd.randf_range(0.7, 1.0)
		m.caixa(folha, Vector3(ox - w * 0.5, y, oz - w * 0.5), Vector3(ox + w * 0.5, y + h, oz + w * 0.5), Malha.F_SEM_BASE)
		y += h + rnd.randf_range(0.05, 0.3)
		w = maxf(1.1, w - rnd.randf_range(0.3, 0.55))
	m.piramide(folha, Vector3(0, alt - 0.7, 0), w, w, 1.7, 1.0)
	# galho baixo
	m.caixa(folha, Vector3(-1.0, 5.0 + var_ * 0.3, -0.2), Vector3(1.0, 5.5 + var_ * 0.3, 0.2), Malha.F_SEM_BASE)
	return m.construir_malha()


static func _pinheiros(raiz: Node3D, c: Castelinho) -> MultiMeshInstance3D:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1975
	var lugares: Array = []
	# fundos (norte) e oeste do lote (como nas fotos), fora do eixo do corredor de 1975
	for i in 22:
		var x := -33.0 + float(i) * 1.6 + rnd.randf_range(-0.7, 0.7)
		if x > -14.5 and x < -6.0:
			continue
		lugares.append(Vector3(x, 0, -36.0 + rnd.randf_range(-3.0, 1.0)))
	for i in 12:
		lugares.append(Vector3(-32.5 + rnd.randf_range(-2.0, 1.0), 0, -4.0 - float(i) * 2.6 + rnd.randf_range(-1.0, 1.0)))
	for i in 8:
		lugares.append(Vector3(-2.0 + rnd.randf_range(-1.0, 1.0), 0, -30.0 + rnd.randf_range(-3.0, 3.0)) if i < 3 else Vector3(rnd.randf_range(-30.0, 14.0), 0, rnd.randf_range(-60.0, -38.0)))
	for i in 8:
		lugares.append(Vector3(rnd.randf_range(-70.0, -36.0), 0, rnd.randf_range(-70.0, 20.0)))
	var primeiro: MultiMeshInstance3D = null
	for v in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _pinus_mesh(v)
		var meus: Array = []
		for i in lugares.size():
			if i % 3 == v:
				meus.append(lugares[i])
		mm.instance_count = meus.size()
		for i in meus.size():
			var s := rnd.randf_range(0.85, 1.25)
			var b := Basis(Vector3.UP, rnd.randf_range(0.0, TAU)).scaled(Vector3(s, s * rnd.randf_range(0.9, 1.2), s))
			mm.set_instance_transform(i, Transform3D(b, meus[i]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Pinheiros_%d" % v
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mmi)
		Epocas.marcar(mmi, Castelinho.ep_casa())
		if primeiro == null:
			primeiro = mmi
	return primeiro


# ------------------------------------------------------------------ barreiras invisíveis (jogador fica no lote + calçadas)
static func _barreiras(raiz: Node3D) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Barreiras"
	corpo.collision_layer = 1
	raiz.add_child(corpo)
	var caixas := [
		# [centro, tamanho]
		[Vector3(-14.0, 2.5, 2.9), Vector3(40.0, 5.0, 0.6)],        # meio-fio da Garibaldi
		[Vector3(2.9, 2.5, -20.0), Vector3(0.6, 5.0, 46.0)],        # meio-fio da Nilza
		[Vector3(-30.4, 2.5, -17.0), Vector3(0.8, 5.0, 40.0)],      # oeste
	]
	for b in caixas:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		corpo.add_child(cs)
	# norte: duas partes, com vão no corredor de 1975, e um fecho do vão fora de 1975
	var norte := [
		[Vector3((-30.5 + (X_CORREDOR - L_CORREDOR * 0.5 - 0.15)) * 0.5, 2.5, -34.6), Vector3(absf(-30.5 - (X_CORREDOR - L_CORREDOR * 0.5 - 0.15)), 5.0, 0.6)],
		[Vector3(((X_CORREDOR + L_CORREDOR * 0.5 + 0.15) + 3.0) * 0.5, 2.5, -34.6), Vector3(absf(3.0 - (X_CORREDOR + L_CORREDOR * 0.5 + 0.15)), 5.0, 0.6)],
	]
	for b in norte:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b[1]
		cs.shape = bs
		cs.position = b[0]
		corpo.add_child(cs)
	var fecho := StaticBody3D.new()
	fecho.name = "BarreiraNorteFecho"
	fecho.collision_layer = 1
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(L_CORREDOR + 0.3, 5.0, 0.6)
	cs2.shape = bs2
	fecho.add_child(cs2)
	fecho.position = Vector3(X_CORREDOR, 2.5, -34.6)
	raiz.add_child(fecho)
	Epocas.marcar(fecho, [GameState.Epoca.E1950, GameState.Epoca.E2019, GameState.Epoca.E2020])


# ------------------------------------------------------------------ corredor de 1975 (só em E1975)
## Eixo x = X_CORREDOR, de z = -29,5 (porta da Sala Medieval) até Z_CORREDOR_FIM. Mais comprido do que o lote.
static func _corredor_1975(c: Castelinho, g: Castelinho.Grupo) -> void:
	var xa := X_CORREDOR - L_CORREDOR * 0.5
	var xb := X_CORREDOR + L_CORREDOR * 0.5
	var z0 := -29.5
	var z1 := Z_CORREDOR_FIM
	var t := 0.3
	var alt := 3.0
	var parede: Material = Castelinho.mat_tri("reboco", Vector3(2, 2, 2), Color(0.92, 0.84, 0.66))
	var rodape: Material = Castelinho.mat_tri("madeira_escura", Vector3(1, 1, 1))
	var piso: Material = Castelinho.mat_tri("deck_madeira", Vector3(1.5, 1.5, 1.5))
	var forro_: Material = c.m.forro
	var m := g.inte
	# piso e forro
	m.caixa(piso, Vector3(xa, 0.0, z1), Vector3(xb, 0.02, z0), Malha.F_PY, 1.5)
	m.caixa(forro_, Vector3(xa, alt, z1), Vector3(xb, alt + 0.05, z0), Malha.F_NY, 1.5)
	# paredes laterais com portas fechadas (quadros de madeira) de 4 em 4 m
	for lado in [-1, 1]:
		var x: float = xa if lado == -1 else xb
		var normal := Vector3(1, 0, 0) if lado == -1 else Vector3(-1, 0, 0)
		m.caixa(parede, Vector3(x - t * (1.0 if lado == -1 else 0.0), 0, z1), Vector3(x + t * (0.0 if lado == -1 else 1.0), alt, z0), Malha.F_TODAS - Malha.F_PY - Malha.F_NY, 2.0)
		g.ext.col(Vector3(x - t * (1.0 if lado == -1 else 0.0), 0, z1), Vector3(x + t * (0.0 if lado == -1 else 1.0), alt, z0))
		m.caixa(rodape, Vector3(x if lado == 1 else x, 0, z1) + Vector3(0.0 if lado == -1 else -0.04, 0, 0), Vector3(x + (0.04 if lado == -1 else 0.0), 0.15, z0), Malha.F_TODAS)
		var zz := z0 - 3.0
		while zz > z1 + 3.0:
			m.quad(c.m.porta, Vector3(x + normal.x * 0.01, 0.0, zz + 0.5), Vector3(x + normal.x * 0.01, 0.0, zz - 0.5), Vector3(x + normal.x * 0.01, 2.1, zz - 0.5), Vector3(x + normal.x * 0.01, 2.1, zz + 0.5), normal, Vector2(1, 1))
			zz -= 4.0
	# parede do fundo com a porta de saída (para o Ato II): o nível coloca o Interagivel
	m.caixa(parede, Vector3(xa - t, 0, z1 - t), Vector3(xb + t, alt, z1), Malha.F_TODAS - Malha.F_PY - Malha.F_NY, 2.0)
	g.ext.col(Vector3(xa - t, 0, z1 - t), Vector3(xb + t, alt, z1))
	m.quad(c.m.porta, Vector3(X_CORREDOR - 0.55, 0.0, z1 + 0.02), Vector3(X_CORREDOR + 0.55, 0.0, z1 + 0.02), Vector3(X_CORREDOR + 0.55, 2.2, z1 + 0.02), Vector3(X_CORREDOR - 0.55, 2.2, z1 + 0.02), N_S, Vector2(1, 1))
	# fundo do corredor do lado do jogador: a porta do fundo é um quadro luminoso (a luz de fim de tarde vaza)
	m.caixa(Castelinho.mat_luz(Color(1.0, 0.8, 0.5), 1.2), Vector3(X_CORREDOR - 0.5, 2.0, z1 + 0.03), Vector3(X_CORREDOR + 0.5, 2.15, z1 + 0.05), Malha.F_PZ)
	# vigas e lustres do corredor
	var zl := z0 - 3.0
	while zl > z1 + 2.0:
		m.caixa(c.m.madeira, Vector3(xa, alt - 0.2, zl - 0.07), Vector3(xb, alt, zl + 0.07), Malha.F_TODAS - Malha.F_PY, 1.0)
		zl -= 2.0
	var zlz := z0 - 8.0
	var i := 0
	while zlz > z1 + 4.0:
		InteriorCastelinho.lustre(c, m, Vector3(X_CORREDOR, 2.55, zlz), alt, 0.8)
		if i % 3 == 0:
			c.luzes.append({"pos": Vector3(X_CORREDOR, 2.4, zlz), "sala": "corredor1975"})
		zlz -= 9.0
		i += 1
