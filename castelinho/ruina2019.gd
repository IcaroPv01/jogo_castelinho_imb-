class_name RuinaCastelinho
extends RefCounted
## Sinais visuais de cada época do Castelinho (só enfeite: NENHUMA colisão, os caminhos continuam abertos).
##
##  - 2019 (`ruina_2019`): o prédio fechado e abandonado, para ninguém confundir com 1975 ou com o presente:
##    tábuas pregadas nos arcos da arcada (a porta fica livre, só com fita zebrada), placa "INTERDITADO", mato alto,
##    letreiro apagado "CHOPERIA" (o prédio foi choperia até 2019, docs/pesquisa/castelinho.md), mesas viradas e pilhas de
##    cadeiras de restaurante, garrafas, o cartaz amarelado de PROCURA-SE do Tito e a pichação "CADÊ O TITO?".
##  - presente (`faixa_reaberto`): faixa de pano "REABERTO · VISITAS GUIADAS AOS SÁBADOS" (visitas 1 e 2 inteira, 3 rasgada
##    e solta de um canto, 4 sem faixa). Fato: aberto aos sábados desde 20/02/2026.
## Tudo é geometria da `Malha` (poucas superfícies) ou Label3D; os nós soltos ficam num pai marcado com `Epocas.marcar`.

const N_S := Vector3(0, 0, 1)
const N_L := Vector3(1, 0, 0)
const Z_FACE := -11.0            # plano externo da fachada sul (arcada)

static var _mat_zebra: StandardMaterial3D


# ------------------------------------------------------------------ materiais
## Fita zebrada amarela e preta (listras diagonais), dupla face. UV: 1 repetição em u = 0,4 m.
static func mat_zebra() -> StandardMaterial3D:
	if _mat_zebra == null:
		var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 64:
				var listra := int((x + y) / 8) % 2 == 0
				img.set_pixel(x, y, Color(0.9, 0.74, 0.1) if listra else Color(0.08, 0.08, 0.08))
		_mat_zebra = StandardMaterial3D.new()
		_mat_zebra.albedo_texture = ImageTexture.create_from_image(img)
		_mat_zebra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat_zebra.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_zebra.roughness = 0.9
	return _mat_zebra


## Fita entre dois pontos, com barriga (`sag` m no meio). Plano vertical (a fita segue de a até b).
static func _fita(m: Malha, a: Vector3, b: Vector3, sag := 0.05, larg := 0.09, pedacos := 5) -> void:
	var mat := mat_zebra()
	var comp := a.distance_to(b)
	var up := Vector3(0, larg, 0)
	for k in pedacos:
		var t0 := float(k) / pedacos
		var t1 := float(k + 1) / pedacos
		var p0 := a.lerp(b, t0) - Vector3(0, sag * sin(t0 * PI), 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sag * sin(t1 * PI), 0)
		var u0 := t0 * comp / 0.4
		var u1 := t1 * comp / 0.4
		m.quad_uv(mat, p0, p1, p1 + up, p0 + up, N_S, Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0))


## Tábua levemente inclinada (altura `ya` na ponta esquerda, `yb` na direita), com espessura. z de `zb` (colada) a `zf`.
static func _tabua(m: Malha, mat: Material, x0: float, x1: float, ya: float, yb: float, h: float, zb: float, zf: float) -> void:
	var a0 := Vector3(x0, ya, zb)
	var a1 := Vector3(x1, yb, zb)
	var b0 := Vector3(x0, ya, zf)
	var b1 := Vector3(x1, yb, zf)
	var up := Vector3(0, h, 0)
	var uv := Vector2(1.0, 1.0)
	m.quad_auto(mat, b0, b1, b1 + up, b0 + up, N_S, uv)                        # frente
	m.quad_auto(mat, a0, a1, a1 + up, a0 + up, -N_S, uv)                       # costas (vista de dentro da arcada)
	m.quad_auto(mat, a0 + up, a1 + up, b1 + up, b0 + up, Vector3.UP, uv)       # topo
	m.quad_auto(mat, a0, a1, b1, b0, Vector3.DOWN, uv)                         # fundo
	m.quad_auto(mat, a0, b0, b0 + up, a0 + up, -N_L, uv)                       # ponta esquerda
	m.quad_auto(mat, a1, b1, b1 + up, a1 + up, N_L, uv)                        # ponta direita


# ------------------------------------------------------------------ 2019
static func ruina_2019(c: Castelinho) -> void:
	var g := c.g_2019
	var e := g.ext
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 20190
	var arcos: Array = Castelinho.medidas.get("arcos_fachada_sul", {}).get("arcos", [])
	var _et := Malha.abrir("")
	# --- tábuas pregadas nos arcos 2 a 5 (o arco 1 é a porta: fica livre, só com fita)
	var madeira_clara := Castelinho.mat_uv("tabuas_claras", Color(1.7, 1.55, 1.3))
	for i in range(1, arcos.size()):
		var a: Dictionary = arcos[i]
		var xc: float = a["x"]
		var hw: float = float(a["w"]) * 0.5 + 0.05
		Malha.abrir("tabuas_arco_%d_2019" % (i + 1))
		var niveis := [0.02, 0.48, 0.94, 1.4, 1.86, 2.28]
		for k in niveis.size():
			if i == 3 and k == 5:
				continue                       # a de cima caiu (aparece caída no chão, abaixo)
			var y: float = niveis[k] + rnd.randf_range(-0.03, 0.03)
			var x0 := xc - hw - rnd.randf_range(0.0, 0.06)
			var x1 := xc + hw + rnd.randf_range(0.0, 0.06)
			if i == 1 and k == 3:
				x1 = xc + 0.1                  # tábua quebrada: só metade do vão
			var dy := rnd.randf_range(-0.05, 0.05)
			_tabua(e, madeira_clara, x0, x1, y, y + dy, 0.17, Z_FACE + 0.04, Z_FACE + 0.07)
		# uma diagonal em cada dois arcos
		if i % 2 == 0:
			_tabua(e, madeira_clara, xc - hw, xc + hw, 0.5, 1.8, 0.14, Z_FACE + 0.075, Z_FACE + 0.1)
		if i == 3:
			Malha.abrir("tabua_caida_2019")
			e.caixa(madeira_clara, Vector3(xc - 0.1, 0.0, Z_FACE + 0.45), Vector3(xc + 0.9, 0.04, Z_FACE + 0.6), Malha.F_SEM_BASE, 1.0)
	# --- a porta de entrada (arco 1): fita zebrada atravessada, sem bloquear
	var p: Dictionary = arcos[0]
	var xp: float = p["x"]
	var hp: float = float(p["w"]) * 0.5 + 0.08
	Malha.abrir("fita_zebrada_porta_2019")
	_fita(e, Vector3(xp - hp, 1.02, Z_FACE + 0.06), Vector3(xp + hp, 1.1, Z_FACE + 0.06), 0.07)
	_fita(e, Vector3(xp - hp, 1.42, Z_FACE + 0.07), Vector3(xp + hp, 1.36, Z_FACE + 0.07), 0.05)
	_fita(e, Vector3(xp - hp, 0.45, Z_FACE + 0.08), Vector3(xp + hp * 0.7, 1.62, Z_FACE + 0.08), 0.03, 0.09, 7)
	# um pedaço solto, pendurado na ponta
	e.quad_uv(mat_zebra(), Vector3(xp + hp - 0.02, 1.34, Z_FACE + 0.07), Vector3(xp + hp - 0.1, 0.66, Z_FACE + 0.07),
		Vector3(xp + hp - 0.01, 0.66, Z_FACE + 0.07), Vector3(xp + hp + 0.07, 1.34, Z_FACE + 0.07), N_S,
		Vector2(0, 0), Vector2(1.7, 0), Vector2(1.7, 1), Vector2(0, 1))
	# --- placa de INTERDITADO no pilar entre a porta e o arco 2 (corpo; o texto é Label3D, ver `_textos`)
	var xi := -7.825
	Malha.abrir("placa_interditado_2019")
	e.caixa(Castelinho.mat_cor(Color(0.82, 0.8, 0.74), 0.9), Vector3(xi - 0.25, 1.5, Z_FACE + 0.01), Vector3(xi + 0.25, 1.86, Z_FACE + 0.03), Malha.F_SEM_BASE)
	e.caixa(Castelinho.mat_cor(Color(0.62, 0.12, 0.1), 0.9), Vector3(xi - 0.25, 1.74, Z_FACE + 0.03), Vector3(xi + 0.25, 1.86, Z_FACE + 0.035), Malha.F_SEM_BASE)
	# --- letreiro apagado: tábua verde-escura desbotada, onde hoje fica a placa da Casa de Cultura
	Malha.abrir("letreiro_choperia_2019")
	var verde := Castelinho.mat_cor(Color(0.13, 0.2, 0.17), 0.95)
	var fio := Castelinho.mat_cor(Color(0.42, 0.38, 0.28), 0.95)
	e.caixa(fio, Vector3(-13.55, 2.62, Z_FACE + 0.005), Vector3(-9.85, 3.08, Z_FACE + 0.035), Malha.F_SEM_BASE)
	e.caixa(verde, Vector3(-13.5, 2.66, Z_FACE + 0.035), Vector3(-9.9, 3.04, Z_FACE + 0.045), Malha.F_SEM_BASE)
	# --- mato mais alto e mais denso na frente, nas laterais e furando o deck
	var capim: Material = Castelinho.mat_cor(Color.WHITE, 1.0, true)
	var altos := [
		Vector3(-5.6, 0, -10.5), Vector3(-7.9, 0, -10.45), Vector3(-9.6, 0, -10.5), Vector3(-11.4, 0, -10.45), Vector3(-13.2, 0, -10.5),
		Vector3(-15.0, 0, -10.45), Vector3(-17.0, 0, -10.5), Vector3(-4.5, 0, -12.2), Vector3(-4.55, 0, -13.5), Vector3(-4.5, 0, -16.9),
		Vector3(-4.5, 0, -19.5), Vector3(-6.2, 0, -9.0), Vector3(-9.6, 0.07, -6.4), Vector3(-12.8, 0.07, -5.0), Vector3(-8.2, 0.07, -8.4),
	]
	for i in altos.size():
		var q: Vector3 = altos[i]
		Malha.abrir("mato_alto_frente_%d" % (i + 1))
		for j in 3:
			var dx := (float((i * 5 + j * 7) % 9) / 8.0 - 0.5) * 0.9
			ExtrasCastelinho._touceira(e, capim, q + Vector3(dx, 0, 0), 0.95 + 0.6 * float((i + j * 3) % 5) / 4.0, rnd)
	# --- interior: mesas viradas, pilhas de cadeiras e garrafas de restaurante
	var tampo := Castelinho.mat_cor(Color(0.42, 0.28, 0.16), 0.9)
	var pernas := Castelinho.mat_cor(Color(0.2, 0.16, 0.13), 0.9)
	var cadeira := Castelinho.mat_cor(Color(0.34, 0.22, 0.13), 0.9)
	var vidro_verde := Castelinho.mat_cor(Color(0.12, 0.3, 0.16), 0.3)
	var vidro_ambar := Castelinho.mat_cor(Color(0.5, 0.3, 0.08), 0.3)
	_mesa_virada(g.inte, tampo, pernas, Vector3(-11.6, 0, -24.6), "x", "mesa_virada_medieval_1")
	_mesa_virada(g.inte, tampo, pernas, Vector3(-12.0, 0, -28.3), "z", "mesa_virada_medieval_2")
	_mesa_virada(g.inte, tampo, pernas, Vector3(-12.2, 0, -12.9), "z", "mesa_virada_hall")
	_pilha_cadeiras(g.inte, cadeira, Vector3(-16.2, 0, -24.8), 5, "cadeiras_empilhadas_medieval_1")
	_pilha_cadeiras(g.inte, cadeira, Vector3(-9.0, 0, -24.3), 4, "cadeiras_empilhadas_medieval_2")
	_pilha_cadeiras(g.inte, cadeira, Vector3(-9.0, 0, -12.3), 6, "cadeiras_empilhadas_hall")
	_garrafa(g.inte, vidro_verde, Vector3(-12.6, 0, -24.7), false, "garrafa_2019_1")
	_garrafa(g.inte, vidro_ambar, Vector3(-10.0, 0, -28.7), false, "garrafa_2019_2")
	_garrafa(g.inte, vidro_verde, Vector3(-11.0, 0, -26.3), true, "garrafa_2019_3")
	_garrafa(g.inte, vidro_ambar, Vector3(-7.4, 0, -12.6), true, "garrafa_2019_4")
	Malha.fechar(_et)
	_textos(c)


## Nós de texto e cartaz (Label3D, MeshInstance3D) da ruína, num pai só marcado como E2019.
static func _textos(c: Castelinho) -> void:
	var raiz := Node3D.new()
	raiz.name = "Textos_2019"
	c.add_child(raiz)
	# INTERDITADO
	var xi := -7.825
	var l1 := Construtor.rotulo(raiz, "INTERDITADO", Vector3(xi, 1.62, Z_FACE + 0.04), 64, Color(0.5, 0.08, 0.07))
	l1.pixel_size = 0.0011
	var l1b := Construtor.rotulo(raiz, "ACESSO PROIBIDO", Vector3(xi, 1.8, Z_FACE + 0.04), 40, Color(0.97, 0.9, 0.85))
	l1b.pixel_size = 0.0012
	# CHOPERIA, desbotado e apagado
	var ch := Construtor.rotulo(raiz, "CHOPERIA", Vector3(-11.7, 2.85, Z_FACE + 0.05), 120, Color(0.56, 0.52, 0.4, 0.8))
	ch.pixel_size = 0.0043
	ch.shaded = true
	# cartaz de PROCURA-SE, amarelado e torto, na fachada leste (x = -5,0, virada para +x), mais a pichação
	var cartaz := TitoCastelinho.folha(raiz, "procura_se", Vector3(-4.97, 1.55, -14.55), 90.0, 0.5, 1, false, 2.5)
	Malha.nomear(cartaz, "cartaz_procura_se_2019")
	var mt := cartaz.material_override as StandardMaterial3D
	mt.albedo_color = Color(0.82, 0.78, 0.62)
	var pich := Construtor.rotulo(raiz, "CADÊ O TITO?", Vector3(-4.99, 0.78, -14.7), 110, Color(0.95, 0.93, 0.86, 0.95))
	pich.pixel_size = 0.0034
	pich.outline_size = 10
	pich.outline_modulate = Color(0.45, 0.05, 0.05, 0.9)
	pich.rotation_degrees = Vector3(0, 90, 3.0)
	pich.shaded = true
	Malha.nomear(pich, "pichacao_cade_o_tito_2019")
	# ponta do cartaz descolada (verso claro do papel dobrado), no canto de baixo
	var ponta := Malha.new()
	ponta.tri(Castelinho.mat_cor(Color(0.78, 0.72, 0.55), 0.95), Vector3(-4.955, 1.2, -14.8), Vector3(-4.955, 1.36, -14.8), Vector3(-4.955, 1.2, -14.64), N_L)
	var mi := ponta.construir_instancia(raiz, "PontaDescolada", 1)
	if mi:
		Malha.nomear(mi, "cartaz_procura_se_ponta_2019")
	Epocas.marcar(raiz, [GameState.Epoca.E2019])


## Mesa de restaurante tombada sobre a borda: o tampo fica em pé e as pernas apontam para o lado.
## eixo "x": o tampo está no plano yz e as pernas apontam para +x; eixo "z": no plano xy, pernas para +z.
static func _mesa_virada(m: Malha, tampo: Material, pernas: Material, p: Vector3, eixo: String, nome: String) -> void:
	var _et := Malha.abrir(nome)
	var L := 1.2          # comprimento do tampo
	var A := 0.7          # largura do tampo (vira a altura dele em pé)
	var comp := 0.72      # pernas
	if eixo == "x":
		m.caixa(tampo, p + Vector3(-0.03, 0.0, -L * 0.5), p + Vector3(0.03, A, L * 0.5), Malha.F_TODAS, 1.0)
		for dz in [-L * 0.5 + 0.06, L * 0.5 - 0.06]:
			for y in [0.0, A - 0.06]:
				m.caixa(pernas, p + Vector3(0.03, y, dz - 0.03), p + Vector3(0.03 + comp, y + 0.06, dz + 0.03), Malha.F_TODAS, 1.0)
	else:
		m.caixa(tampo, p + Vector3(-L * 0.5, 0.0, -0.03), p + Vector3(L * 0.5, A, 0.03), Malha.F_TODAS, 1.0)
		for dx in [-L * 0.5 + 0.06, L * 0.5 - 0.06]:
			for y in [0.0, A - 0.06]:
				m.caixa(pernas, p + Vector3(dx - 0.03, y, 0.03), p + Vector3(dx + 0.03, y + 0.06, 0.03 + comp), Malha.F_TODAS, 1.0)
	Malha.fechar(_et)


## Pilha de `n` cadeiras: quatro pernas altas, `n` assentos empilhados e um encosto no topo.
static func _pilha_cadeiras(m: Malha, mat: Material, p: Vector3, n: int, nome: String) -> void:
	var _et := Malha.abrir(nome)
	var passo := 0.09
	var topo := 0.45 + passo * (n - 1)
	for dx in [-0.19, 0.19]:
		for dz in [-0.19, 0.19]:
			m.caixa(mat, p + Vector3(dx - 0.018, 0.0, dz - 0.018), p + Vector3(dx + 0.018, topo, dz + 0.018), Malha.F_TODAS, 1.0)
	for k in n:
		var y := 0.45 + passo * k
		m.caixa(mat, p + Vector3(-0.21, y, -0.21), p + Vector3(0.21, y + 0.035, 0.21), Malha.F_TODAS, 1.0)
	m.caixa(mat, p + Vector3(-0.21, topo, 0.19), p + Vector3(0.21, topo + 0.5, 0.22), Malha.F_TODAS, 1.0)
	Malha.fechar(_et)


## Garrafa de vidro em pé (corpo + gargalo) ou deitada ao longo de x.
static func _garrafa(m: Malha, mat: Material, p: Vector3, deitada: bool, nome: String) -> void:
	var _et := Malha.abrir(nome)
	if deitada:
		m.caixa(mat, p + Vector3(-0.1, 0.0, -0.035), p + Vector3(0.08, 0.07, 0.035), Malha.F_SEM_BASE)
		m.caixa(mat, p + Vector3(0.08, 0.02, -0.015), p + Vector3(0.18, 0.05, 0.015), Malha.F_SEM_BASE)
	else:
		m.caixa(mat, p + Vector3(-0.035, 0.0, -0.035), p + Vector3(0.035, 0.18, 0.035), Malha.F_SEM_BASE)
		m.caixa(mat, p + Vector3(-0.015, 0.18, -0.015), p + Vector3(0.015, 0.28, 0.015), Malha.F_SEM_BASE)
	Malha.fechar(_et)


# ------------------------------------------------------------------ presente: faixa de REABERTO
## Faixa de pano pendurada na viga da frente da pérgola do deck (x -14..-7,5, z -9,05; a viga vai de y 2,5 a 2,66), entre o poste da ponta e o do meio, virada
## para a calçada. Visitas 1 e 2: inteira; visita 3: solta de um canto, pendendo rasgada; visita 4: sem faixa.
## `visita` vem de GameState (o nível é recarregado a cada visita).
static func faixa_reaberto(c: Castelinho, visita: int) -> void:
	if visita >= 4:
		return
	var rasgada := visita == 3
	var w := 2.9
	var h := 0.75
	var raiz := Node3D.new()
	raiz.name = "FaixaReaberto"
	Malha.nomear(raiz, "faixa_reaberto_rasgada" if rasgada else "faixa_reaberto")
	# canto esquerdo preso na viga; na visita 3 o direito se soltou e a faixa pende inclinada
	raiz.position = Vector3(-13.75, 2.5, -8.975)
	if rasgada:
		raiz.rotation_degrees = Vector3(0, 0, -11.0)
	c.add_child(raiz)
	var pano := Castelinho.mat_cor(Color(0.9, 0.9, 0.86) if not rasgada else Color(0.8, 0.79, 0.74), 0.95, true)
	var m := Malha.new()
	if not rasgada:
		m.quad(pano, Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(w, -h, 0), Vector3(0, -h, 0), N_S)
	else:
		# borda direita rasgada em dentes; leque de triângulos a partir de um ponto do miolo
		var f := Vector3(w * 0.3, -h * 0.5, 0)
		var pts := [Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(w * 0.97, -h * 0.28, 0), Vector3(w * 0.9, -h * 0.42, 0),
			Vector3(w * 0.96, -h * 0.66, 0), Vector3(w * 0.88, -h * 0.82, 0), Vector3(w * 0.93, -h, 0), Vector3(0, -h, 0)]
		for i in pts.size():
			m.tri(pano, f, pts[i], pts[(i + 1) % pts.size()], N_S)
	# barras de cor na ponta (faixa azul-petróleo em cima e embaixo)
	var azul := Castelinho.mat_cor(Color(0.1, 0.34, 0.4), 0.95, true)
	m.quad(azul, Vector3(0, 0, 0.004), Vector3(w * (0.97 if rasgada else 1.0), 0, 0.004), Vector3(w * (0.97 if rasgada else 1.0), -0.06, 0.004), Vector3(0, -0.06, 0.004), N_S)
	m.quad(azul, Vector3(0, -h + 0.06, 0.004), Vector3(w * (0.93 if rasgada else 1.0), -h + 0.06, 0.004), Vector3(w * (0.93 if rasgada else 1.0), -h, 0.004), Vector3(0, -h, 0.004), N_S)
	m.construir_instancia(raiz, "Pano", 1)
	var cor_txt := Color(0.1, 0.3, 0.36)
	var l1 := Construtor.rotulo(raiz, "REABERTO", Vector3(w * 0.45, -h * 0.35, 0.01), 100, cor_txt)
	l1.pixel_size = 0.0034
	l1.shaded = true
	var l2 := Construtor.rotulo(raiz, "VISITAS GUIADAS AOS SÁBADOS · 9h–17h", Vector3(w * 0.45, -h * 0.74, 0.01), 40, cor_txt)
	l2.pixel_size = 0.0026
	l2.shaded = true
	# cordinhas que prendem a faixa à viga (a do canto direito está solta na visita 3)
	var cordas := Malha.new()
	var corda := Castelinho.mat_cor(Color(0.7, 0.62, 0.45), 1.0, true)
	for x in ([0.06, w * 0.5, w - 0.06] if not rasgada else [0.06, w * 0.5]):
		cordas.quad(corda, Vector3(x - 0.012, 0, 0.008), Vector3(x + 0.012, 0, 0.008), Vector3(x + 0.012, 0.1, 0.008), Vector3(x - 0.012, 0.1, 0.008), N_S)
	cordas.construir_instancia(raiz, "Cordas", 1)
	Epocas.marcar(raiz, [GameState.Epoca.E2020])
