class_name PoraoQuarto
extends RefCounted
## O quarto do Tito (sala 95) e os slides do último dia (salas 96 a 99) do porão (V2_ROTEIRO §6.3).
##
## O quarto é um quarto de veraneio de 1967 INTEIRO e SECO no meio da masmorra alagada: sobe 0,7 m sobre uma plataforma
## (rampas nas pontas), papel de parede, cama, criado-mudo com abajur, guarda-roupa, balde vermelho, desenhos e as marcas
## de altura a lápis. O disco sem data está na cama. Nada de corpo, sangue ou violência: só as coisas de uma criança.
##
## Os slides são cenas simples na época ESEMDATA (`Epocas.marcar`): só aparecem com o Visor ligado no disco sem data.
## Tito é sempre uma silhueta de menino (bermuda azul, balde vermelho) e a Figura Branca, a do Passo da Mãe Rosa.

const SalasGd := preload("res://world/niveis/porao_salas.gd")
const MalhaGd := preload("res://castelinho/malha.gd")
const MurosGd := preload("res://castelinho/muros.gd")

const PISO := 0.7        # altura do piso do quarto em relação à entrada


static func quarto(c) -> void:
	var w: float = c.w
	var L: float = c.L
	var h := 3.5
	var T: float = SalasGd.T
	SalasGd.casca(c, {"h": h, "sem_piso": true})
	var mv := SalasGd.mat_vc()
	var mm: Material = c.mats["madeira"]
	var mpa: Material = c.mats["papel"]
	var rampa := 1.6
	# plataforma de tábuas e rampas
	c.madeira.caixa(mm, Vector3(-w * 0.5, PISO - 0.5, -L + rampa), Vector3(w * 0.5, PISO, -rampa), Malha.F_PY, 0.0, Color(0.95, 0.9, 0.85))
	c.col(Vector3(-w * 0.5, PISO - 0.5, -L + rampa), Vector3(w * 0.5, PISO, -rampa))
	c.madeira.quad(mm, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, PISO, -rampa), Vector3(-w * 0.5, PISO, -rampa), Vector3.UP, Vector2.ZERO, Color(0.85, 0.8, 0.75))
	c.madeira.quad(mm, Vector3(-w * 0.5, PISO, -L + rampa), Vector3(w * 0.5, PISO, -L + rampa), Vector3(w * 0.5, 0, -L), Vector3(-w * 0.5, 0, -L), Vector3.UP, Vector2.ZERO, Color(0.85, 0.8, 0.75))
	c.pedra.rampa(PackedVector3Array([Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, PISO, -rampa), Vector3(w * 0.5, PISO, -rampa),
		Vector3(-w * 0.5, -0.5, 0), Vector3(w * 0.5, -0.5, 0), Vector3(-w * 0.5, -0.5, -rampa), Vector3(w * 0.5, -0.5, -rampa)]))
	c.pedra.rampa(PackedVector3Array([Vector3(-w * 0.5, 0, -L), Vector3(w * 0.5, 0, -L), Vector3(-w * 0.5, PISO, -L + rampa), Vector3(w * 0.5, PISO, -L + rampa),
		Vector3(-w * 0.5, -0.5, -L), Vector3(w * 0.5, -0.5, -L), Vector3(-w * 0.5, -0.5, -L + rampa), Vector3(w * 0.5, -0.5, -L + rampa)]))
	# papel de parede listrado nas laterais, com rodapé de madeira
	for lado in [-1, 1]:
		var x: float = lado * (w * 0.5 - 0.015)
		var z := -rampa
		var k := 0
		while z > -L + rampa - 0.01:
			var z2 := maxf(z - 0.45, -L + rampa)
			var cor := Color(1, 1, 1) if k % 2 == 0 else Color(0.88, 0.8, 0.66)
			c.papel.quad(mpa, Vector3(x, PISO + 0.15, z), Vector3(x, PISO + 0.15, z2), Vector3(x, h - 0.1, z2), Vector3(x, h - 0.1, z), Vector3(-lado, 0, 0), Vector2.ZERO, cor)
			z = z2
			k += 1
		c.madeira.caixa(mm, Vector3(x - 0.02 if lado > 0 else x - 0.03, PISO, -L + rampa), Vector3(x + 0.03 if lado > 0 else x + 0.02, PISO + 0.15, -rampa), Malha.F_TODAS, 0.0, Color(0.6, 0.5, 0.45))
	# forro de madeira
	SalasGd.teto_plano(c, -w * 0.5, w * 0.5, -L, 0.0, h, c.madeira, mm)
	# parede de fundo do quarto (atrás da porta): paineis de papel dos dois lados da passagem
	for lado in [-1, 1]:
		var xa: float = lado * 1.35
		var xb: float = lado * (w * 0.5)
		c.papel.quad(mpa, Vector3(minf(xa, xb), PISO + 0.15, -L + 0.02), Vector3(maxf(xa, xb), PISO + 0.15, -L + 0.02), Vector3(maxf(xa, xb), h - 0.1, -L + 0.02), Vector3(minf(xa, xb), h - 0.1, -L + 0.02), Vector3.BACK, Vector2.ZERO, Color(0.95, 0.88, 0.75))
	# cama de solteiro (pés para o fundo) encostada na parede esquerda
	var xl := -w * 0.5
	SalasGd.solida(c, c.madeira, mm, xl + 0.02, PISO, -6.2, xl + 1.0, PISO + 0.42, -3.6, Color(0.85, 0.7, 0.6))
	SalasGd.caixa(c.vc, mv, xl + 0.06, PISO + 0.42, -6.1, xl + 0.96, PISO + 0.56, -4.2, Color(0.35, 0.5, 0.68))       # colcha
	SalasGd.caixa(c.vc, mv, xl + 0.1, PISO + 0.56, -4.3, xl + 0.9, PISO + 0.66, -3.7, Color(0.9, 0.88, 0.8))         # travesseiro
	SalasGd.caixa(c.vc, mv, xl + 0.06, PISO + 0.42, -4.2, xl + 0.96, PISO + 0.5, -3.65, Color(0.9, 0.88, 0.8))       # lençol dobrado
	# criado-mudo com abajur
	SalasGd.solida(c, c.madeira, mm, xl + 0.02, PISO, -3.3, xl + 0.55, PISO + 0.5, -2.7, Color(0.8, 0.65, 0.55))
	SalasGd.caixa(c.vc, mv, xl + 0.18, PISO + 0.5, -3.1, xl + 0.4, PISO + 0.58, -2.9, Color(0.5, 0.4, 0.3))
	SalasGd.caixa(c.vc, mv, xl + 0.22, PISO + 0.58, -3.06, xl + 0.36, PISO + 0.9, -2.94, Color(0.95, 0.85, 0.55))
	SalasGd.caixa(c.luz, SalasGd.mat_luz(), xl + 0.2, PISO + 0.7, -3.08, xl + 0.38, PISO + 0.88, -2.92, Color(1.0, 0.9, 0.6), Malha.F_TODAS)
	SalasGd.luz_solta(c, Vector3(xl + 0.9, PISO + 1.1, -3.0), Color(1.0, 0.8, 0.5), 1.6, 8.5)
	# guarda-roupa de duas portas na parede direita
	SalasGd.solida(c, c.madeira, mm, w * 0.5 - 0.65, PISO, -6.4, w * 0.5 - 0.02, PISO + 2.0, -4.6, Color(0.75, 0.6, 0.5))
	SalasGd.caixa(c.vc, mv, w * 0.5 - 0.69, PISO + 0.9, -5.57, w * 0.5 - 0.65, PISO + 1.1, -5.53, Color(0.85, 0.75, 0.3))
	# tapete redondo (quadrado, low-poly) e o balde vermelho com a pazinha ao lado
	SalasGd.caixa(c.vc, mv, -1.0, PISO, -5.2, 0.4, PISO + 0.02, -3.2, Color(0.5, 0.2, 0.2), Malha.F_PY)
	var balde := Node3D.new()
	balde.name = "Balde"
	balde.position = Vector3(0.9, PISO, -2.6)
	c.raiz.add_child(balde)
	var cil := CylinderMesh.new()
	cil.top_radius = 0.16
	cil.bottom_radius = 0.12
	cil.height = 0.26
	cil.radial_segments = 8
	cil.rings = 1
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color(0.85, 0.1, 0.08)
	mb.roughness = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = cil
	mi.material_override = mb
	mi.position.y = 0.13
	balde.add_child(mi)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.15
	tor.outer_radius = 0.17
	tor.rings = 8
	tor.ring_segments = 3
	var al := MeshInstance3D.new()
	al.mesh = tor
	al.material_override = mb
	al.position.y = 0.3
	al.rotation_degrees = Vector3(0, 0, 90)
	balde.add_child(al)
	SalasGd.caixa(c.vc, mv, 1.25, PISO, -2.7, 1.4, PISO + 0.04, -2.3, Color(0.9, 0.7, 0.15))                       # pazinha de plástico
	SalasGd.caixa(c.vc, mv, 1.2, PISO, -2.4, 1.3, PISO + 0.05, -2.0, Color(0.3, 0.55, 0.9))                         # uma sandália
	# desenhos na parede acima da cama (1, 2, 3 e o do jogador, o 7) e o recado de giz
	var tex := SalasGd.tex_desenho
	SalasGd.quadro(c, tex.call(1), Vector3(xl + 0.02, PISO + 1.75, -5.4), Vector3.RIGHT, 0.9, 0.68, -3.0)
	SalasGd.quadro(c, tex.call(2), Vector3(xl + 0.02, PISO + 1.55, -4.2), Vector3.RIGHT, 0.9, 0.68, 4.0)
	SalasGd.quadro(c, tex.call(3), Vector3(xl + 0.02, PISO + 1.8, -3.0), Vector3.RIGHT, 0.9, 0.68, -2.0)
	SalasGd.quadro(c, tex.call(7), Vector3(w * 0.5 - 0.02, PISO + 1.5, -3.4), Vector3.LEFT, 0.9, 0.68, 2.0)
	SalasGd.rotulo(c, "OLHA PELA LENTE", Vector3(xl + 0.035, PISO + 1.05, -4.6), 90.0, 30, Color(0.15, 0.3, 0.85, 0.9), 0.0032)
	# marcas de altura a lápis no batente da porta: "TITO 6, 7, 8, 9" e depois nada
	for i in 4:
		var y := PISO + 0.95 + i * 0.12
		c.vc.caixa(mv, Vector3(w * 0.5 - 0.03, y, -2.55), Vector3(w * 0.5, y + 0.014, -2.05), Malha.F_TODAS, 0.0, Color(0.25, 0.25, 0.3))
		SalasGd.rotulo(c, "TITO %d" % (6 + i), Vector3(w * 0.5 - 0.04, y + 0.03, -2.3), 270.0, 14, Color(0.25, 0.25, 0.3), 0.0016)
	# o disco sem data na cama (o interativo é criado pelo nível: precisa de acesso ao GameState e ao Visor)
	c.pontos["disco"] = Vector3(xl + 0.5, PISO + 0.72, -4.0)
	var disco := Node3D.new()
	disco.name = "Disco"
	disco.position = c.pontos["disco"]
	c.raiz.add_child(disco)
	var d_m := CylinderMesh.new()
	d_m.top_radius = 0.1
	d_m.bottom_radius = 0.1
	d_m.height = 0.012
	d_m.radial_segments = 14
	d_m.rings = 1
	var m_d := StandardMaterial3D.new()
	m_d.albedo_color = Color(0.9, 0.1, 0.1)
	m_d.emission_enabled = true
	m_d.emission = Color(0.9, 0.15, 0.1)
	m_d.emission_energy_multiplier = 0.9
	var d_mi := MeshInstance3D.new()
	d_mi.mesh = d_m
	d_mi.material_override = m_d
	disco.add_child(d_mi)
	var m_q := StandardMaterial3D.new()
	m_q.albedo_color = Color(0.95, 0.95, 0.8)
	m_q.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var q_m := CylinderMesh.new()
	q_m.top_radius = 0.012
	q_m.bottom_radius = 0.012
	q_m.height = 0.016
	q_m.radial_segments = 4
	q_m.rings = 1
	for i in 7:
		var a := TAU * i / 7.0
		var q := MeshInstance3D.new()
		q.mesh = q_m
		q.material_override = m_q
		q.position = Vector3(cos(a) * 0.07, 0.002, sin(a) * 0.07)
		disco.add_child(q)
	# o quarto não alaga: lâmpada de teto fraca e o ponto da voz (o Tito chama de "dentro")
	SalasGd.luz_solta(c, Vector3(0.5, h - 0.5, -4.5), Color(1.0, 0.85, 0.6), 0.8, 7.0)
	c.pontos["figura"] = Vector3(0, PISO + 0.05, -L + 1.6)
	c.pontos["voz"] = Vector3(0, PISO + 1.2, -L + 0.8)
	c.piso_fn = func(z: float) -> float:
		if z > -rampa:
			return PISO * (-z / rampa)
		if z < -L + rampa:
			return PISO * ((L + z) / rampa)
		return PISO


# ============================================================================ slides do último dia (V2 §6.3)
## Monta, na sala 96..99 (`c.ultimo`), o slide dela dentro de um nó marcado ESEMDATA. Cada sala tem uma coisa só.
static func vinheta(c) -> void:
	var slide := Node3D.new()
	slide.name = "Slide%d" % c.ultimo
	c.raiz.add_child(slide)
	var L: float = c.L
	match c.ultimo:
		96:
			# Tito sai de casa ao entardecer, de costas, com o balde: no meio do corredor, indo para a luz
			_menino(slide, Vector3(0.0, 0.0, -L * 0.62), PI, false, true)
			_poente(slide, c, -L + 0.08, 2.6, 3.0, 0.0, false)
		97:
			# Tito na margem do Braço Morto: sentado numa borda de pedra, de costas, o balde ao lado
			_menino(slide, Vector3(-1.2, 0.0, -L + 3.0), PI, true, true)
			_poente(slide, c, -L + 0.08, 3.4, 3.2, 0.0, true)
		98:
			# a Figura Branca do outro lado da água, de braços abertos; o menino pequeno, sentado, de costas para nós
			_menino(slide, Vector3(-1.0, 0.0, -3.6), PI, true, true)
			_figura_aberta(slide, Vector3(0.0, 0.0, -L + 1.2))
			_poente(slide, c, -L + 0.08, 3.4, 3.2, 0.0, true)
		99:
			# a água parada, sem ninguém, e o balde boiando (o nível põe o balde na cota da água)
			var balde := _balde_boiando()
			balde.position = Vector3(0.4, c.base_agua, -2.2)
			slide.add_child(balde)
			c.nos_agua_alvo.append(balde)
	Epocas.marcar(slide, [GameState.Epoca.ESEMDATA])
	c.tito_slides.append(slide)


static func _mat_slide(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _peca(pai: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


static func _balde_boiando() -> Node3D:
	var n := Node3D.new()
	n.name = "BaldeBoiando"
	var cil := CylinderMesh.new()
	cil.top_radius = 0.17
	cil.bottom_radius = 0.13
	cil.height = 0.27
	cil.radial_segments = 8
	cil.rings = 1
	var mat := _mat_slide(Color(0.9, 0.12, 0.08))
	_peca(n, cil, Vector3(0, 0.05, 0), mat, Vector3(14, 0, 8))
	return n


## Um menino de ~1,2 m (9 anos): camiseta clara, bermuda azul, pernas magras, cabelo escuro. Sempre de costas.
static func _menino(pai: Node3D, pos: Vector3, yaw: float, sentado: bool, balde: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Tito"
	n.position = pos
	n.rotation.y = yaw
	pai.add_child(n)
	var camisa := _mat_slide(Color(0.95, 0.9, 0.7))
	var bermuda := _mat_slide(Color(0.15, 0.3, 0.8))
	var pele := _mat_slide(Color(0.85, 0.62, 0.48))
	var cabelo := _mat_slide(Color(0.12, 0.08, 0.06))
	var vermelho := _mat_slide(Color(0.9, 0.12, 0.08))
	var y0 := 0.0 if not sentado else -0.38
	# tronco
	var tronco := CapsuleMesh.new()
	tronco.radius = 0.15
	tronco.height = 0.52
	tronco.radial_segments = 8
	tronco.rings = 2
	_peca(n, tronco, Vector3(0, 0.78 + y0, 0), camisa)
	# bermuda e pernas
	var shorts := BoxMesh.new()
	shorts.size = Vector3(0.3, 0.22, 0.2)
	_peca(n, shorts, Vector3(0, 0.5 + y0, 0), bermuda)
	var perna := CapsuleMesh.new()
	perna.radius = 0.055
	perna.height = 0.42
	perna.radial_segments = 6
	perna.rings = 1
	if sentado:
		# sentado numa borda: coxas para a frente (-Z local = para a água), canelas penduradas
		for lado in [-1.0, 1.0]:
			_peca(n, perna, Vector3(lado * 0.08, 0.5 + y0, -0.16), pele, Vector3(90, 0, 0))
			_peca(n, perna, Vector3(lado * 0.08, 0.28 + y0, -0.36), pele)
	else:
		for lado in [-1.0, 1.0]:
			_peca(n, perna, Vector3(lado * 0.08, 0.21, 0), pele)
	# braços
	var braco := CapsuleMesh.new()
	braco.radius = 0.045
	braco.height = 0.4
	braco.radial_segments = 6
	braco.rings = 1
	_peca(n, braco, Vector3(-0.2, 0.78 + y0, 0.0), pele, Vector3(0, 0, 8))
	var braco_d := _peca(n, braco, Vector3(0.2, 0.74 + y0, 0.0), pele, Vector3(0, 0, -6))
	# cabeça, cabelo
	var cab := SphereMesh.new()
	cab.radius = 0.12
	cab.height = 0.24
	cab.radial_segments = 8
	cab.rings = 4
	_peca(n, cab, Vector3(0, 1.2 + y0, 0), pele)
	var cab2 := SphereMesh.new()
	cab2.radius = 0.125
	cab2.height = 0.2
	cab2.radial_segments = 8
	cab2.rings = 3
	_peca(n, cab2, Vector3(0, 1.24 + y0, 0.025), cabelo)
	# o balde vermelho na mão direita (ao lado do corpo, ou no chão ao lado, se sentado)
	if balde:
		var cil := CylinderMesh.new()
		cil.top_radius = 0.13
		cil.bottom_radius = 0.1
		cil.height = 0.22
		cil.radial_segments = 8
		cil.rings = 1
		if sentado:
			_peca(n, cil, Vector3(0.38, 0.11 + y0 + 0.2, 0.05), vermelho)
		else:
			_peca(n, cil, Vector3(0.28, 0.32, 0.0), vermelho)
			braco_d.rotation_degrees = Vector3(0, 0, -22)
	return n


## A Figura Branca de braços abertos (silhueta estática do slide 3): saia, tronco, cabeça sem rosto, véu, braços em T.
static func _figura_aberta(pai: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "FiguraAberta"
	n.position = pos
	pai.add_child(n)
	var branco := _mat_slide(Color(0.95, 0.96, 1.0))
	var veu_m := StandardMaterial3D.new()
	veu_m.albedo_color = Color(0.9, 0.93, 1.0, 0.4)
	veu_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veu_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veu_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var saia := CylinderMesh.new()
	saia.top_radius = 0.16
	saia.bottom_radius = 0.44
	saia.height = 1.4
	saia.radial_segments = 10
	saia.rings = 1
	_peca(n, saia, Vector3(0, 0.78, 0), branco)
	var tronco := CapsuleMesh.new()
	tronco.radius = 0.15
	tronco.height = 0.78
	tronco.radial_segments = 8
	tronco.rings = 2
	_peca(n, tronco, Vector3(0, 1.78, 0), branco)
	var cab := SphereMesh.new()
	cab.radius = 0.11
	cab.height = 0.22
	cab.radial_segments = 8
	cab.rings = 4
	_peca(n, cab, Vector3(0.0, 2.3, 0), branco).scale = Vector3(0.85, 1.25, 0.9)
	var braco := CapsuleMesh.new()
	braco.radius = 0.04
	braco.height = 1.3
	braco.radial_segments = 6
	braco.rings = 1
	_peca(n, braco, Vector3(-0.68, 2.05, 0.0), branco, Vector3(0, 0, 82))
	_peca(n, braco, Vector3(0.68, 2.05, 0.0), branco, Vector3(0, 0, -82))
	var veu := CylinderMesh.new()
	veu.top_radius = 0.18
	veu.bottom_radius = 0.7
	veu.height = 2.3
	veu.radial_segments = 12
	veu.rings = 1
	veu.cap_top = false
	veu.cap_bottom = false
	_peca(n, veu, Vector3(0, 1.2, 0.02), veu_m)
	return n


## Pano de fundo do poente (quad sem luz com gradiente por cor de vértice) para fechar o fim da sala: céu roxo, faixa
## laranja no horizonte e, se `lago`, uma faixa escura (a margem oposta) e o reflexo laranja embaixo.
static func _poente(pai: Node3D, c, z: float, larg: float, alt: float, y0: float, lago: bool) -> void:
	var m := MalhaGd.new()
	var mat := SalasGd.mat_luz()
	var topo := Color(0.30, 0.16, 0.38)
	var meio := Color(0.95, 0.5, 0.2)
	var hor := Color(1.0, 0.72, 0.3)
	var x0 := -larg * 0.5
	var x1 := larg * 0.5
	var ya := y0 + c.dy * 0.0
	var faixas := [[0.0, 0.42, hor, hor], [0.42, 0.62, hor, meio], [0.62, 1.0, meio, topo]]
	if lago:
		faixas = [[0.0, 0.32, Color(0.85, 0.42, 0.18), Color(0.95, 0.55, 0.22)], [0.32, 0.38, Color(0.12, 0.08, 0.1), Color(0.12, 0.08, 0.1)],
			[0.38, 0.62, hor, meio], [0.62, 1.0, meio, topo]]
	for f in faixas:
		var y_a: float = ya + f[0] * alt
		var y_b: float = ya + f[1] * alt
		m.tri_cores(mat, Vector3(x0, y_a, z), Vector3(x1, y_a, z), Vector3(x1, y_b, z), Vector3(0, 0, 1), f[2], f[2], f[3])
		m.tri_cores(mat, Vector3(x0, y_a, z), Vector3(x1, y_b, z), Vector3(x0, y_b, z), Vector3(0, 0, 1), f[2], f[3], f[3])
	m.construir_instancia(pai, "Poente")
