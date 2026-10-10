class_name ExtrasCastelinho
extends RefCounted
## Camadas de tempo do Castelinho além da "casa completa":
##  - E2020 (museu): vidros nos arcos + porta de entrada, deck com pérgola, cerca de corda, hortênsias, letreiros
##  - E2019 (ruína): fibrocimento quebrado, mato alto, musgo (a parede troca de textura em Castelinho._on_epoca)
##  - E1950 (núcleo): casa de pedra de dois volumes com telhados de duas águas, chaminé saliente e janela gradeada
##    alta (foto antiga), oco e com a porta aberta, no lugar onde hoje fica o corpo principal.
##  - E1975: mobília de veraneio (ver MobiliaCastelinho)

const N_S := Vector3(0, 0, 1)
const N_N := Vector3(0, 0, -1)
const N_L := Vector3(1, 0, 0)
const N_O := Vector3(-1, 0, 0)
const U_X := Vector3(1, 0, 0)
const U_Z := Vector3(0, 0, 1)


static func construir(c: Castelinho) -> void:
	_museu(c)
	_ruina(c)
	_nucleo_1950(c)
	MobiliaCastelinho.construir(c)


# ------------------------------------------------------------------ E2020: museu
static func _museu(c: Castelinho) -> void:
	var g := c.g_museu
	var arcos: Array = Castelinho.medidas.get("arcos_fachada_sul", {}).get("arcos", [])
	# vidros nos arcos 2..5 (esquadria preta); o arco 1 é a porta de entrada (nó separado)
	for i in range(1, arcos.size()):
		var a: Dictionary = arcos[i]
		var _et := Malha.abrir("vidro_arco_%d" % (i + 1))
		_vidro_arco(c, g.ext, a["x"], a["w"], a["imposta"], a["coroa"])
		Malha.fechar(_et)
		g.ext.col(Vector3(a["x"] - a["w"] * 0.5, 0, -11.3), Vector3(a["x"] + a["w"] * 0.5, a["coroa"], -11.1))
	_porta_entrada(c, arcos[0])
	# porta de saída da Sala Medieval (norte): fechada em 2020 (em 1975 o vão está aberto e leva ao corredor)
	c.porta_arco_fechada(g.ext, Vector3(0, 0, -29.5), U_X, N_N, -10.2, 1.4, 0.0, 1.95, 2.35, 0.2, false)
	c.porta_arco_fechada(g.inte, Vector3(0, 0, -29.1), U_X, N_S, -10.2, 1.4, 0.0, 1.95, 2.35, 0.2, false)
	g.inte.col(Vector3(-10.95, 0.0, -29.45), Vector3(-9.45, 2.4, -29.2))
	_deck_e_pergola(c, g)
	_corda(c, g)
	_hortensias(c, g)
	_letreiros(c, g)


## Vidro com esquadria preta dentro de um arco abatido (plano z = -11,2, no meio da parede).
static func _vidro_arco(c: Castelinho, m: Malha, xc: float, w: float, imp: float, coroa: float, pz := -11.2) -> void:
	var pf := Muros.perfil("arco", xc - w * 0.5, xc + w * 0.5, imp, coroa)
	var base := Vector3(xc, 0.0, pz)
	for i in pf.size() - 1:
		m.tri(c.m.vidro, base, Vector3(pf[i].x, pf[i].y, pz), Vector3(pf[i + 1].x, pf[i + 1].y, pz), N_S)
	m.tri(c.m.vidro, base, Vector3(xc + w * 0.5, 0, pz), Vector3(xc - w * 0.5, 0, pz), N_S)
	m.tri(c.m.vidro, base, Vector3(xc - w * 0.5, 0, pz), Vector3(pf[0].x, pf[0].y, pz), N_S)
	m.tri(c.m.vidro, base, Vector3(pf[pf.size() - 1].x, pf[pf.size() - 1].y, pz), Vector3(xc + w * 0.5, 0, pz), N_S)
	# esquadria: contorno do arco (fita preta de 4 cm), travessa a 1,0 m e montante central
	for i in pf.size() - 1:
		var a := Vector3(pf[i].x, pf[i].y, pz)
		var b := Vector3(pf[i + 1].x, pf[i + 1].y, pz)
		var d := Vector3(0, -0.05, 0)
		m.quad_auto(c.m.ferro, a, b, b + d, a + d, N_S)
		m.quad_auto(c.m.ferro, a, b, b + d, a + d, N_N)
	for x in [xc - w * 0.5, xc + w * 0.5 - 0.04]:
		m.caixa(c.m.ferro, Vector3(x, 0, pz - 0.03), Vector3(x + 0.04, imp, pz + 0.03), Malha.F_TODAS)
	m.caixa(c.m.ferro, Vector3(xc - w * 0.5, 0.95, pz - 0.03), Vector3(xc + w * 0.5, 1.0, pz + 0.03), Malha.F_TODAS)
	m.caixa(c.m.ferro, Vector3(xc - 0.02, 0, pz - 0.03), Vector3(xc + 0.02, coroa - 0.05, pz + 0.03), Malha.F_TODAS)


## Porta de vidro de duas folhas no arco de entrada (E2020). Cada folha gira em torno da dobradiça.
static func _porta_entrada(c: Castelinho, a: Dictionary) -> void:
	var xc: float = a["x"]
	var w: float = a["w"]
	var imp: float = a["imposta"]
	var coroa: float = a["coroa"]
	var raiz := Node3D.new()
	raiz.name = "PortaEntrada"
	Malha.nomear(raiz, "porta_entrada_vidro")
	c.add_child(raiz)
	c.porta_entrada = raiz
	# bandeira fixa em arco acima das folhas (no mesmo plano z = -11,2)
	var fixa := Malha.new()
	var pf := Muros.perfil("arco", xc - w * 0.5, xc + w * 0.5, imp, coroa)
	var pz := -11.2
	var base := Vector3(xc, imp, pz)
	for i in pf.size() - 1:
		fixa.tri(c.m.vidro, base, Vector3(pf[i].x, pf[i].y, pz), Vector3(pf[i + 1].x, pf[i + 1].y, pz), N_S)
		fixa.quad_auto(c.m.ferro, Vector3(pf[i].x, pf[i].y, pz), Vector3(pf[i + 1].x, pf[i + 1].y, pz), Vector3(pf[i + 1].x, pf[i + 1].y - 0.05, pz), Vector3(pf[i].x, pf[i].y - 0.05, pz), N_S)
	fixa.caixa(c.m.ferro, Vector3(xc - w * 0.5, imp - 0.05, pz - 0.03), Vector3(xc + w * 0.5, imp, pz + 0.03), Malha.F_TODAS)
	var mi_fixa := fixa.construir_instancia(raiz, "BandeiraFixa", 1)
	if mi_fixa:
		mi_fixa.global_position = Vector3.ZERO
	# folhas
	var meio := w * 0.5 - 0.03
	for lado in [-1, 1]:
		var folha := Node3D.new()
		folha.name = "Folha_E" if lado == -1 else "Folha_D"
		folha.position = Vector3(xc + lado * (w * 0.5 - 0.02), 0, pz)
		raiz.add_child(folha)
		var fm := Malha.new()
		var s := -float(lado)               # direção da folha a partir da dobradiça (para o centro)
		var x0 := 0.0
		var x1 := s * meio
		fm.quad_auto(c.m.vidro, Vector3(x0, 0.05, 0), Vector3(x1, 0.05, 0), Vector3(x1, imp - 0.05, 0), Vector3(x0, imp - 0.05, 0), N_S)
		for xx in [minf(x0, x1), maxf(x0, x1) - 0.05]:
			fm.caixa(c.m.ferro, Vector3(xx, 0.0, -0.025), Vector3(xx + 0.05, imp, 0.025), Malha.F_TODAS)
		fm.caixa(c.m.ferro, Vector3(minf(x0, x1), 0.0, -0.025), Vector3(maxf(x0, x1), 0.07, 0.025), Malha.F_TODAS)
		fm.caixa(c.m.ferro, Vector3(minf(x0, x1), imp - 0.05, -0.025), Vector3(maxf(x0, x1), imp, 0.025), Malha.F_TODAS)
		fm.caixa(c.m.ferro, Vector3(minf(x0, x1), 0.95, -0.025), Vector3(maxf(x0, x1), 1.0, 0.025), Malha.F_TODAS)
		# puxador (junto ao centro)
		var hx := x1 - s * 0.1
		fm.caixa(c.m.branco, Vector3(hx - 0.015, 0.85, -0.06), Vector3(hx + 0.015, 1.25, 0.06), Malha.F_TODAS)
		fm.construir_instancia(folha, "Malha", 1)
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(meio, 2.1, 0.12)
		cs.shape = bs
		cs.position = Vector3(s * meio * 0.5, 1.05, 0)
		sb.add_child(cs)
		folha.add_child(sb)
	Epocas.marcar(raiz, [GameState.Epoca.E2020])


## Deck de madeira com pérgola aberta e dois guarda-sóis pretos (foto aérea 2019; presente em 2019 e 2020).
static func _deck_e_pergola(c: Castelinho, g: Castelinho.Grupo) -> void:
	_deck(c, g)


static func _deck(c: Castelinho, g: Castelinho.Grupo) -> void:
	var x0 := -14.0
	var x1 := -7.5
	var z0 := -9.2
	var z1 := -4.2
	var e := g.ext
	var _et := Malha.abrir("deck_madeira")
	e.caixa(c.m.deck, Vector3(x0, 0.0, z0), Vector3(x1, 0.07, z1), Malha.F_SEM_BASE, 1.5)
	e.col(Vector3(x0, 0.0, z0), Vector3(x1, 0.07, z1))
	var h := 2.5
	var ip := 0
	for px in [x0 + 0.15, (x0 + x1) * 0.5, x1 - 0.15]:
		for pz in [z0 + 0.15, z1 - 0.15]:
			ip += 1
			Malha.abrir("pergola_poste_%d" % ip)
			e.caixa(c.m.madeira, Vector3(px - 0.07, 0.07, pz - 0.07), Vector3(px + 0.07, h, pz + 0.07), Malha.F_TODAS, 1.0)
	# vigas longas (ao longo de x) e caibros (ao longo de z)
	Malha.abrir("pergola_vigas")
	for pz in [z0 + 0.15, z1 - 0.15]:
		e.caixa(c.m.madeira, Vector3(x0, h, pz - 0.06), Vector3(x1, h + 0.16, pz + 0.06), Malha.F_TODAS, 1.0)
	var n := 8
	for i in n:
		var x := x0 + 0.2 + i * (x1 - x0 - 0.4) / (n - 1)
		e.caixa(c.m.madeira, Vector3(x - 0.04, h + 0.16, z0 - 0.15), Vector3(x + 0.04, h + 0.24, z1 + 0.15), Malha.F_TODAS, 1.0)
	# guarda-sóis pretos
	for p in [Vector3(-12.2, 0, -5.8), Vector3(-9.0, 0, -7.6)]:
		Malha.abrir("guarda_sol_deck_%d" % (1 if p.x < -10.0 else 2))
		e.caixa(c.m.ferro, Vector3(p.x - 0.02, 0, p.z - 0.02), Vector3(p.x + 0.02, 2.0, p.z + 0.02), Malha.F_TODAS)
		e.piramide(c.m.escuro, Vector3(p.x, 1.85, p.z), 2.0, 2.0, 0.55, 1.0)
	Malha.fechar(_et)


## Cerca de corda trançada em postes baixos, em arco suave (foto frontal 2026). Sem colisão.
static func _corda(c: Castelinho, g: Castelinho.Grupo) -> void:
	var z := -2.6
	var xs := [-27.0, -24.6, -22.2, -19.8, -17.4, -15.0, -12.6, -10.2, -7.8]   # abre um vão no caminho de lajotas (x -7,8..-3)
	var _et := Malha.abrir("")
	for i in xs.size():
		Malha.abrir("cerca_corda_poste_%d" % (i + 1))
		g.ext.caixa(c.m.madeira, Vector3(xs[i] - 0.05, 0, z - 0.05), Vector3(xs[i] + 0.05, 0.5, z + 0.05), Malha.F_TODAS, 1.0)
	for i in xs.size() - 1:
		Malha.abrir("cerca_corda_%d" % (i + 1))
		var a: float = xs[i]
		var b: float = xs[i + 1]
		var pts: Array = []
		for k in 7:
			var t := float(k) / 6.0
			pts.append(Vector3(lerpf(a, b, t), 0.46 - 0.16 * sin(t * PI), z))
		for k in 6:
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var d := Vector3(0, 0.05, 0)
			g.ext.quad_auto(c.m.corda, p0, p1, p1 + d, p0 + d, N_S)
	Malha.fechar(_et)


static func _hortensias(c: Castelinho, g: Castelinho.Grupo) -> void:
	var pos := [
		Vector3(-9.6, 0, -10.2), Vector3(-11.3, 0, -10.3), Vector3(-13.2, 0, -10.2), Vector3(-15.4, 0, -10.3),
		Vector3(-17.6, 0, -10.2), Vector3(-19.2, 0, -10.4), Vector3(-23.0, 0, -10.2), Vector3(-25.0, 0, -10.3),
		Vector3(-4.3, 0, -12.0), Vector3(-4.3, 0, -15.0), Vector3(-4.3, 0, -18.0), Vector3(-4.3, 0, -20.0),
		Vector3(-26.8, 0, -9.5), Vector3(-27.6, 0, -11.0),
		# maciço contínuo diante do anexo e da torre (fotos "torres" e "hibisco" de 2026)
		Vector3(-20.6, 0, -10.25), Vector3(-21.8, 0, -10.3), Vector3(-24.0, 0, -10.25), Vector3(-26.0, 0, -10.3),
		Vector3(-18.4, 0, -10.3), Vector3(-16.4, 0, -10.25),
	]
	# arbusto arredondado + cachos (bolinhas) de flor por cima, como nas fotos de 2026 (azul, lilás, branco, rosa)
	var paleta := [Color(0.5, 0.62, 0.95), Color(0.72, 0.7, 0.95), Color(0.93, 0.94, 0.97), Color(0.6, 0.72, 0.98),
		Color(0.92, 0.66, 0.84)]
	var flor: Material = Castelinho.mat_cor(Color.WHITE, 1.0)
	var folha: Material = Castelinho.mat_tri("folhagem", Vector3(0.8, 0.8, 0.8), Color(0.82, 1.0, 0.72))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1975
	var _et := Malha.abrir("")
	for i in pos.size():
		var p: Vector3 = pos[i]
		var s := 0.95 + 0.35 * float((i * 7) % 5) / 4.0
		Malha.abrir("hortensia_%d" % (i + 1))
		g.ext.bolha(folha, p + Vector3(0, 0.38 * s, 0), Vector3(0.6 * s, 0.42 * s, 0.42 * s), rnd, 7, 2, 0.15,
			Color(1.0, 1.0, 1.0), Color(0.4, 0.45, 0.4))
		var cor_mae: Color = paleta[(i * 3) % paleta.size()]
		for k in 7:
			var ang := TAU * float(k) / 7.0 + rnd.randf_range(-0.3, 0.3)
			var rr := rnd.randf_range(0.15, 0.48) * s
			var cp := p + Vector3(cos(ang) * rr * 1.15, 0.62 * s + rnd.randf_range(-0.12, 0.08), sin(ang) * rr * 0.75)
			var tom: Color = cor_mae.lerp(paleta[rnd.randi() % paleta.size()], 0.3) * rnd.randf_range(0.9, 1.05)
			tom.a = 1.0
			g.ext.bolha(flor, cp, Vector3(0.17, 0.14, 0.17) * s, rnd, 5, 2, 0.15, tom, tom * Color(0.62, 0.62, 0.7))
	Malha.fechar(_et)


## Letreiros genéricos (sem brasão nem marca real): "Castelinho" (leste) e a placa da Casa de Cultura (sul).
static func _letreiros(c: Castelinho, g: Castelinho.Grupo) -> void:
	var fl: Dictionary = Castelinho.medidas.get("fachada_leste", {}).get("letreiro", {})
	var z: float = fl.get("z", -15.0)
	var y: float = fl.get("base", 2.6)
	var w: float = fl.get("w", 2.1)
	var h: float = fl.get("h", 0.45)
	var x := -4.97
	var _et := Malha.abrir("letreiro_castelinho_leste")
	g.ext.quad_uv(c.m.letreiro, Vector3(x, y, z + w * 0.5), Vector3(x, y, z - w * 0.5), Vector3(x, y + h, z - w * 0.5), Vector3(x, y + h, z + w * 0.5), N_L,
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	# placa na arcada
	var px := -11.7
	var py := 2.62
	var pw := 1.8
	var ph := 0.56
	var zp := -10.975
	Malha.abrir("placa_casa_de_cultura")
	g.ext.caixa(c.m.branco, Vector3(px - pw * 0.5, py, zp), Vector3(px + pw * 0.5, py + ph, zp + 0.03), Malha.F_SEM_BASE)
	g.ext.caixa(c.m.bordo, Vector3(px - pw * 0.5, py + ph * 0.42, zp + 0.03), Vector3(px + pw * 0.5, py + ph, zp + 0.045), Malha.F_SEM_BASE)
	var l1 := Construtor.rotulo(c, "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA", Vector3(px, py + ph * 0.18, zp + 0.05), 28, Color(0.15, 0.15, 0.18))
	l1.pixel_size = 0.0021
	var l2 := Construtor.rotulo(c, "CASA DE CULTURA E MUSEU", Vector3(px, py + ph * 0.71, zp + 0.06), 36, Color(1, 1, 1))
	l2.pixel_size = 0.0027
	for l in [l1, l2]:
		l.double_sided = false
		l.rotation_degrees = Vector3(0, 0, 0)
		Epocas.marcar(l, [GameState.Epoca.E2020])
	# plaquinha ao lado do arco de entrada
	Malha.abrir("plaquinha_arco_entrada")
	g.ext.caixa(c.m.branco, Vector3(-4.82, 1.1, -11.02), Vector3(-4.52, 1.35, -10.99), Malha.F_SEM_BASE)
	Malha.fechar(_et)


# ------------------------------------------------------------------ E2019: ruína
static func _ruina(c: Castelinho) -> void:
	var g := c.g_2019
	_deck(c, g)
	var e := g.ext
	# chapas de fibrocimento empenadas/soltas sobre o telhado do corpo principal
	var k := tan(deg_to_rad(10.0))
	var _et := Malha.abrir("")
	var ich := 0
	for p in [[-11.2, -19.0, 1.3, 0.9, 0.35], [-9.4, -17.0, 1.1, 1.2, 0.28], [-7.2, -15.2, 1.2, 0.8, 0.4], [-10.2, -15.0, 0.9, 1.1, 0.3]]:
		var x: float = p[0]
		var z: float = p[1]
		var w: float = p[2]
		var d: float = p[3]
		var lev: float = p[4]
		ich += 1
		Malha.abrir("chapa_fibrocimento_solta_%d" % ich)
		var y := 4.3 + (-5.0 - x) * k + 0.04
		var a := Vector3(x, y, z)
		var b := Vector3(x + w, y - w * k, z)
		var cc := Vector3(x + w, y - w * k + lev, z + d)
		var dd := Vector3(x, y + lev, z + d)
		e.quad_auto(c.m.fibro, a, b, cc, dd, Vector3.UP, Vector2(1.416, 1.416))
		e.quad_auto(c.m.madeira, a, b, cc, dd, Vector3.DOWN)
	# mato alto (tufos verdes escuros) ao pé das paredes e nas ameias
	var tufos := [
		Vector3(-6.0, 0, -10.4), Vector3(-9.0, 0, -10.3), Vector3(-12.0, 0, -10.4), Vector3(-17.5, 0, -10.3), Vector3(-22.0, 0, -10.3),
		Vector3(-4.4, 0, -13.0), Vector3(-4.4, 0, -17.0), Vector3(-4.4, 0, -21.0), Vector3(-26.0, 0, -12.0), Vector3(-25.5, 0, -17.0),
		Vector3(-18.0, 0, -24.0), Vector3(-16.0, 0, -30.5), Vector3(-9.0, 0, -30.4), Vector3(-4.4, 0, -28.0),
	]
	# capim alto em touceiras: lâminas finas (triângulos de dupla face) do pé escuro à ponta seca/clara
	var capim: Material = Castelinho.mat_cor(Color.WHITE, 1.0, true)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 2019
	for i in tufos.size():
		var p: Vector3 = tufos[i]
		Malha.abrir("mato_alto_%d" % (i + 1))
		for j in 4:
			var dx := (float((i * 3 + j * 5) % 9) / 8.0 - 0.5) * 1.3
			var dz := (float((i * 7 + j * 3) % 9) / 8.0 - 0.5) * 0.7
			_touceira(e, capim, p + Vector3(dx, 0, dz), 0.5 + 0.6 * float((i + j * 2) % 5) / 4.0, rnd)
	# mato nascendo nas ameias da Torre A
	for i in 9:
		var x := -22.2 + i * 0.6
		Malha.abrir("mato_ameia_torre_a_%d" % (i + 1))
		_touceira(e, capim, Vector3(x, 7.8, -14.75), 0.35 + 0.1 * float(i % 3), rnd)
	Malha.fechar(_et)


## Touceira de capim: ~9 lâminas inclinadas em leque (cor de vértice: verde-escuro no pé, palha na ponta).
static func _touceira(m: Malha, mat: Material, base: Vector3, alt: float, rnd: RandomNumberGenerator) -> void:
	var pe := Color(0.16, 0.24, 0.12)
	var ponta := Color(0.62, 0.62, 0.36) if rnd.randf() < 0.5 else Color(0.42, 0.55, 0.26)
	for k in 9:
		var a := TAU * float(k) / 9.0 + rnd.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		var lado := Vector3(-d.z, 0, d.x) * 0.045
		var h := alt * rnd.randf_range(0.6, 1.1)
		var topo := base + d * h * rnd.randf_range(0.25, 0.55) + Vector3(0, h, 0)
		m.tri_cores(mat, base - lado, base + lado, topo, d, pe, pe, ponta)


# ------------------------------------------------------------------ E1950: núcleo original
## Volume A (alto, norte): x -12,5..-5, z -20,5..-15,5, cumeeira ao longo de z a 6,4 m.
## Volume B (baixo, sul): x -12,5..-5, z -15,5..-11, cumeeira a 4,5 m. Chaminé saliente na face norte de A.
static func _nucleo_1950(c: Castelinho) -> void:
	var g := c.g_1950
	var me := g.ext
	var mi := g.inte
	var pe: Material = c.m.parede_1950
	var pi: Material = c.m.parede_1950
	var T := 0.4
	var ha := 4.8
	var hb := 3.3
	var ra := 6.4
	var rb := 4.5
	var x0 := -12.5
	var x1 := -5.0
	var xm := (x0 + x1) * 0.5
	# piso de pedra
	mi.quad(c.m.piso, Vector3(x0, 0.012, -20.5), Vector3(x1, 0.012, -20.5), Vector3(x1, 0.012, -11.0), Vector3(x0, 0.012, -11.0), Vector3.UP)
	# --- volume A
	Muros.muro_z(me, mi, pe, pi, x1, -20.5, -15.5, 1, T, 0.0, ha, [Muros.ab(-18.2, 1.5, 0.0, 1.7, 2.2, "arco")], {"tampa": false})
	Muros.muro_z(me, mi, pe, pi, x0, -20.5, -15.5, -1, T, 0.0, ha, [], {})
	Muros.muro_x(me, mi, pe, pi, -20.5, x0, x1, -1, T, 0.0, ha, [], {})
	_oitao(c, me, mi, pe, pi, -20.5, -1, x0, x1, ha, ra, T)
	# --- volume B
	Muros.muro_z(me, mi, pe, pi, x1, -15.5, -11.0, 1, T, 0.0, hb, [], {})
	Muros.muro_z(me, mi, pe, pi, x0, -15.5, -11.0, -1, T, 0.0, hb, [], {})
	Muros.muro_x(me, mi, pe, pi, -11.0, x0, x1, 1, T, 0.0, hb, [], {})
	_oitao(c, me, mi, pe, pi, -11.0, 1, x0, x1, hb, rb, T)
	# divisória A/B (empena do volume A para dentro de B) com porta
	Muros.muro_x(mi, mi, pi, pi, -15.5, x0, x1, 1, T, 0.0, ha, [Muros.ab(-8.75, 1.1, 0.0, 1.9, 2.3, "arco")], {})
	# telhados de duas águas (fibrocimento), cumeeira ao longo de z
	_duas_aguas(c, me, x0, x1, -20.5 - 0.35, -15.5, ha, ra)
	_duas_aguas(c, me, x0, x1, -15.5, -11.0 + 0.35, hb, rb)
	# janelas com veneziana fechada no leste (volume B) e janela alta sobre a porta
	var o := Vector3(x1, 0, 0)
	for zz in [-12.3, -14.1]:
		c.veneziana_fechada(g, o, U_Z, N_L, zz, 0.7, 1.0, 1.25, c.m.tabuas)
	c.veneziana_fechada(g, o, U_Z, N_L, -18.2, 0.7, 3.5, 1.0, c.m.tabuas)
	# janelas de tábua também no sul (volume B) e no oeste, como na foto antiga
	c.veneziana_fechada(g, Vector3(0, 0, -11.0), U_X, N_S, -10.4, 0.7, 1.0, 1.25, c.m.tabuas)
	c.veneziana_fechada(g, Vector3(0, 0, -11.0), U_X, N_S, -7.1, 0.7, 1.0, 1.25, c.m.tabuas)
	c.veneziana_fechada(g, Vector3(x0, 0, 0), U_Z, N_O, -13.2, 0.7, 1.0, 1.25, c.m.tabuas)
	c.veneziana_fechada(g, Vector3(x0, 0, 0), U_Z, N_O, -18.0, 0.7, 1.0, 1.25, c.m.tabuas)
	# folha da porta arqueada, aberta para dentro (encostada no vão)
	var _et := Malha.abrir("porta_nucleo_1950")
	me.quad(c.m.tabuas, Vector3(x1 - 0.4, 0.0, -18.95), Vector3(x1 - 1.3, 0.0, -18.95), Vector3(x1 - 1.3, 1.7, -18.95), Vector3(x1 - 0.4, 1.7, -18.95), Vector3(0, 0, 1), Vector2(1.0, 1.0))
	me.quad(c.m.tabuas, Vector3(x1 - 0.4, 0.0, -18.99), Vector3(x1 - 1.3, 0.0, -18.99), Vector3(x1 - 1.3, 1.7, -18.99), Vector3(x1 - 0.4, 1.7, -18.99), Vector3(0, 0, -1), Vector2(1.0, 1.0))
	# janela gradeada alta na face norte de A (foto antiga)
	Malha.abrir("janela_gradeada_1950")
	var on := Vector3(0, 0, -20.5)
	c.decalque_vao(me, c.m.escuro, on, U_X, N_N, -10.3, 0.75, 3.7, 4.1, 4.1, "ret")
	var ga := Vector3(-10.3 - 0.375, 3.7, -20.5 - 0.02)
	me.quad(c.m.grade, ga, ga + Vector3(0.75, 0, 0), ga + Vector3(0.75, 0.4, 0), ga + Vector3(0, 0.4, 0), N_N, Vector2(0.75, 0.4))
	# chaminé saliente na face norte de A
	Malha.abrir("chamine_1950")
	me.caixa(pe, Vector3(-7.1, 0, -21.2), Vector3(-6.0, 7.1, -20.5), Malha.F_SEM_BASE - Malha.F_PY)
	me.caixa(pe, Vector3(-7.2, 7.1, -21.3), Vector3(-5.9, 7.25, -20.4), Malha.F_SEM_BASE)
	# colisão: paredes são geradas pelo muro(); chaminé
	me.col(Vector3(-7.1, 0, -21.2), Vector3(-6.0, 7.1, -20.5))
	Malha.fechar(_et)
	# cobertura do volume B encosta na parede de A: degrau da empena
	# portas/janelas: porta aberta (escura) no leste de A


static func _oitao(c: Castelinho, me: Malha, mi: Malha, pe: Material, pi: Material, z: float, fora: int, x0: float, x1: float, h: float, r: float, t: float) -> void:
	# empena triangular (face externa em z, interna recuada t)
	var n := Vector3(0, 0, float(fora))
	var zi := z - fora * t
	var xm := (x0 + x1) * 0.5
	me.tri(pe, Vector3(x0, h, z), Vector3(x1, h, z), Vector3(xm, r, z), n)
	mi.tri(pi, Vector3(x0, h, zi), Vector3(x1, h, zi), Vector3(xm, r, zi), -n)


static func _duas_aguas(c: Castelinho, m: Malha, x0: float, x1: float, z0: float, z1: float, h: float, r: float) -> void:
	var xm := (x0 + x1) * 0.5
	var ov := 0.5
	var dy := (r - h) * (ov / (xm - x0))
	var e := Vector3(0, 0.1, 0)
	# água oeste e leste
	var a := Vector3(x0 - ov, h - dy, z0)
	var b := Vector3(xm, r, z0)
	var cc := Vector3(xm, r, z1)
	var d := Vector3(x0 - ov, h - dy, z1)
	m.quad_auto(c.m.fibro, a, d, cc, b, Vector3.UP, Vector2(1.416, 1.416))
	m.quad_auto(c.m.madeira, a - e, d - e, cc - e, b - e, Vector3.DOWN)
	var a2 := Vector3(x1 + ov, h - dy, z0)
	var d2 := Vector3(x1 + ov, h - dy, z1)
	m.quad_auto(c.m.fibro, a2, d2, cc, b, Vector3.UP, Vector2(1.416, 1.416))
	m.quad_auto(c.m.madeira, a2 - e, d2 - e, cc - e, b - e, Vector3.DOWN)
