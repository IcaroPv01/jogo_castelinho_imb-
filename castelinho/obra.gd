class_name ObraCastelinho
extends RefCounted
## Época E1967: o Castelinho EM OBRA (V2_ROTEIRO §4.1). LICENÇA CRIATIVA: os dados históricos dizem que a obra foi de
## 1950 a 1975 e que as torres vieram depois; o estado exato em 1967 não está documentado, então é uma estimativa.
##
##  - corpo principal e arcada de pé, sem telhado (só caibros de madeira), parapeito da arcada incompleto;
##  - Torre A pela metade (até ~4 m, topo desigual) com andaime de madeira;
##  - Torre B só na fundação (baldrame de 0,9 m) com ferros de armação;
##  - pilhas de blocos de pedra (os que vieram pelo rio), um barco de madeira encalhado na areia;
##  - chão de areia (grupo Areia do entorno também vale em 1967), poucas casas de madeira e nenhuma rua;
##  - um muro baixo de blocos ao longo da Garibaldi COM UM BURACO de criança: por ele Tito entrava na obra (pista que
##    só existe em 1967, ver o nível).
## Tudo no grupo `Obra_1967` (Castelinho.g_1967), só aparece com GameState.epoca == E1967.
## O boneco do Tito e o castelinho de areia ficam em `Obra.tito_pos` (o nível instancia o boneco).

const Y := 3.5
const N_S := Vector3(0, 0, 1)
const N_N := Vector3(0, 0, -1)
const U_X := Vector3(1, 0, 0)
const U_Z := Vector3(0, 0, 1)

const TITO_POS := Vector3(-2.3, 0.0, -7.2)
const BURACO_POS := Vector3(-21.6, 0.0, -1.0)


static func construir(c: Castelinho) -> Dictionary:
	var g := c.g_1967
	var info := {"volumes": [], "tito_pos": TITO_POS, "buraco_pos": BURACO_POS}
	_corpo_e_arcada(c, g, info)
	_torre_a(c, g, info)
	_torre_b(c, g, info)
	_andaime(c, g)
	_pilhas(c, g, info)
	_barco(c, g)
	_muro_com_buraco(c, g)
	_castelo_de_areia(c, g)
	_canteiro(c, g)
	_casas(c, g)
	return info


# ------------------------------------------------------------------ corpo principal + arcada
static func _corpo_e_arcada(c: Castelinho, g: Castelinho.Grupo, info: Dictionary) -> void:
	var arcos: Array = []
	for a in Castelinho.medidas.get("arcos_fachada_sul", {}).get("arcos", []):
		arcos.append(Muros.ab(a["x"], a["w"], 0.0, a["imposta"], a["coroa"], "arco"))
	# fachada sul: os arcos já levantados (sem arquivoltas nem vidros: ainda é obra)
	c.parede_x(g, -11.0, -15.8, -5.0, 1, 0.0, Y, arcos, "ext", "ext", {"tampa": true})
	# parapeito da arcada: só o trecho oeste está pronto; o resto são ferros de armação
	Muros.muro(g.ext, g.ext, c.m.parede, c.m.parede, Vector3(-15.8, 0, -11.0), U_X, N_S, 6.0, Castelinho.T, Y, 4.0, [], {"col": false, "tampa": true})
	for x in [-9.6, -8.4, -7.2, -6.0, -5.3]:
		g.ext.caixa(c.m.ferro, Vector3(x - 0.012, Y, -11.2 - 0.012), Vector3(x + 0.012, Y + 0.9, -11.2 + 0.012), Malha.F_TODAS)
	# fachada leste: trecho da arcada e corpo principal, com a janela e a porta abertas (sem esquadrias)
	var fl: Dictionary = Castelinho.medidas.get("fachada_leste", {})
	var j: Array = fl.get("janelas", [])
	var p: Dictionary = fl.get("porta", {})
	var ab1 := [Muros.ab(j[0]["z"], j[0]["w"], j[0]["base"], j[0]["base"] + j[0]["h"], -1.0, "ret")]
	var ab2 := [
		Muros.ab(j[1]["z"], j[1]["w"], j[1]["base"], j[1]["base"] + j[1]["h"], -1.0, "ret"),
		Muros.ab(p["z"], p["w"], 0.0, p["imposta"], p["coroa"], "arco"),
	]
	c.parede_z(g, -5.0, -14.0, -11.0, 1, 0.0, Y, ab1, "ext", "ext", {"tampa": true})
	c.parede_z(g, -5.0, -20.5, -14.0, 1, 0.0, 4.2, ab2, "ext", "ext", {"tampa": true})
	# corpo principal: sul (fundo do hall), norte (com a porta do corredor) e oeste (com a porta do pátio)
	c.parede_x(g, -13.8, -12.5, -5.0, 1, 0.0, Y, [], "ext", "ext", {"tampa": true})
	c.parede_x(g, -20.5, -12.5, -5.0, -1, 0.0, 4.2, [Muros.ab(-8.5, 1.2, 0.0, 1.9, 2.3, "arco")], "ext", "ext", {"tampa": true})
	c.parede_z(g, -12.5, -20.5, -14.0, -1, 0.0, 4.2, [Muros.ab(-19.55, 0.95, 0.0, 1.85, 2.15, "arco")], "ext", "ext", {"tampa": true})
	# trecho cheio atrás da arcada, a oeste (a pilastra)
	g.ext.caixa(c.m.parede, Vector3(-15.8, 0, -15.0), Vector3(-12.5, Y, -13.8), Malha.F_SEM_BASE)
	g.ext.col(Vector3(-15.8, 0, -15.0), Vector3(-12.5, Y, -13.8))
	# sem telhado: só caibros de madeira atravessando o corpo principal e dois pontaletes
	for i in 7:
		var x := -12.2 + i * 1.15
		g.ext.caixa(c.m.madeira, Vector3(x - 0.07, 4.2, -20.6), Vector3(x + 0.07, 4.38, -13.9), Malha.F_TODAS, 1.0)
	for z in [-19.8, -15.2]:
		g.ext.caixa(c.m.madeira, Vector3(-12.4, 4.2, z - 0.07), Vector3(-5.0, 4.38, z + 0.07), Malha.F_TODAS, 1.0)
	info["volumes"].append([-15.8, -5.0, -14.2, -11.0, 4.0])
	info["volumes"].append([-12.5, -5.0, -20.5, -14.0, 4.3])


# ------------------------------------------------------------------ Torre A pela metade
static func _torre_a(c: Castelinho, g: Castelinho.Grupo, info: Dictionary) -> void:
	# topo desigual: o canto sudoeste ainda está baixo, o nordeste já passou dos 4 m
	c.parede_x(g, -11.0, -22.6, -15.8, 1, 0.0, 2.9, [], "ext", "ext", {"y1b": 4.2, "tampa": true})
	c.parede_z(g, -22.6, -15.0, -11.0, -1, 0.0, 2.6, [], "ext", "ext", {"y1b": 2.9, "tampa": true})
	c.parede_x(g, -15.0, -22.6, -15.8, -1, 0.0, 3.0, [], "ext", "ext", {"y1b": 4.1, "tampa": true})
	c.parede_z(g, -15.8, -15.0, -11.0, 1, 0.0, 4.2, [Muros.ab(-12.6, 1.3, 0.0, 1.9, 2.3, "arco")], "ext", "ext", {"tampa": true})
	# blocos soltos no alto da parede mais baixa
	for k in 3:
		var _et := Malha.abrir("bloco_solto_torre_a_%d" % (k + 1))
		g.ext.caixa(c.m.parede_clara, Vector3(-22.4 + k * 0.5, 2.6, -14.8), Vector3(-22.0 + k * 0.5, 2.95, -14.5), Malha.F_SEM_BASE)
	Malha.abrir("")
	info["volumes"].append([-22.6, -15.8, -15.0, -11.0, 4.2])


# ------------------------------------------------------------------ Torre B: só a fundação
static func _torre_b(c: Castelinho, g: Castelinho.Grupo, info: Dictionary) -> void:
	var h := 0.9
	c.parede_x(g, -23.5, -8.2, -5.0, 1, 0.0, h, [], "ext", "ext", {"tampa": true})
	c.parede_x(g, -26.7, -8.2, -5.0, -1, 0.0, h, [], "ext", "ext", {"tampa": true})
	c.parede_z(g, -8.2, -26.7, -23.5, -1, 0.0, h, [], "ext", "ext", {"tampa": true})
	c.parede_z(g, -5.0, -26.7, -23.5, 1, 0.0, h, [], "ext", "ext", {"tampa": true})
	# ferros de armação saindo do baldrame (varetas finas, alturas diferentes)
	var i := 0
	for x in [-7.9, -7.0, -6.1, -5.3]:
		for z in [-26.4, -23.8]:
			var alt := 1.7 + 0.18 * float((i * 3) % 4)
			Malha.abrir("ferro_armacao_%d" % (i + 1))
			g.ext.caixa(c.m.ferro, Vector3(x - 0.012, h, z - 0.012), Vector3(x + 0.012, alt, z + 0.012), Malha.F_TODAS)
			i += 1
	Malha.abrir("")
	# baldrame baixo da ala dos fundos (só o traçado, sem colisão)
	g.ext.caixa(c.m.parede_clara, Vector3(-17.0, 0, -29.5), Vector3(-8.2, 0.18, -29.1), Malha.F_SEM_BASE)
	g.ext.caixa(c.m.parede_clara, Vector3(-17.0, 0, -29.5), Vector3(-16.6, 0.18, -23.5), Malha.F_SEM_BASE)
	info["volumes"].append([-8.2, -5.0, -26.7, -23.5, 0.9])


# ------------------------------------------------------------------ andaime de madeira (Torre A)
static func _andaime(c: Castelinho, g: Castelinho.Grupo) -> void:
	var e := g.ext
	# revisão V2: o andaime era de madeira_escura com 9 cm (lia como barras pretas de metal). Agora é pinho cru
	# (claro, com tom por peça), varas de 14 cm e pranchas largas: lê como andaime de madeira de obra dos anos 60.
	var madeira: Material = Castelinho.mat_cor(Color(0.8, 0.64, 0.44), 0.95)
	var prancha: Material = Castelinho.mat_tri("tabuas_claras", Vector3(1.5, 1.5, 1.5))
	var z := -10.35
	var xs := [-23.3, -21.0, -18.7, -16.4]
	var ys := [1.7, 3.3, 4.9]
	var _et := Malha.abrir("andaime_torre_a")
	for x in xs:
		e.caixa(madeira, Vector3(x - 0.07, 0.0, z - 0.07), Vector3(x + 0.07, 5.5, z + 0.07), Malha.F_SEM_BASE, 1.0)
	for zz in [-12.2, -14.4]:
		e.caixa(madeira, Vector3(-23.3 - 0.07, 0.0, zz - 0.07), Vector3(-23.3 + 0.07, 5.5, zz + 0.07), Malha.F_SEM_BASE, 1.0)
	for y in ys:
		e.caixa(madeira, Vector3(-23.45, y - 0.05, z - 0.06), Vector3(-16.25, y + 0.05, z + 0.06), Malha.F_TODAS, 1.0)
		e.caixa(madeira, Vector3(-23.3 - 0.06, y - 0.05, -14.5), Vector3(-23.3 + 0.06, y + 0.05, -10.3), Malha.F_TODAS, 1.0)
	# pranchas de piso em dois níveis (o de cima só no trecho já usado), com rodapé e tábuas soltas
	e.caixa(prancha, Vector3(-23.45, 1.75, -11.05), Vector3(-16.25, 1.82, -10.2), Malha.F_TODAS, 1.5)
	e.caixa(prancha, Vector3(-23.45, 3.35, -11.05), Vector3(-19.0, 3.42, -10.2), Malha.F_TODAS, 1.5)
	e.caixa(prancha, Vector3(-23.45, 1.82, -10.24), Vector3(-16.25, 2.0, -10.2), Malha.F_TODAS, 1.5)
	e.caixa(prancha, Vector3(-19.2, 3.42, -11.0), Vector3(-17.6, 3.47, -10.7), Malha.F_TODAS, 1.5)
	# diagonais (contraventamento)
	var d := Vector3(0, 0.1, 0)
	for i in xs.size() - 1:
		var a := Vector3(xs[i], ys[0], z)
		var b := Vector3(xs[i + 1], ys[1], z)
		for n in [N_S, N_N]:
			e.quad_auto(madeira, a, b, b + d, a + d, n)
	for i in 2:
		var a2 := Vector3(xs[i], ys[1], z)
		var b2 := Vector3(xs[i + 1], ys[2], z)
		for n in [N_S, N_N]:
			e.quad_auto(madeira, a2, b2, b2 + d, a2 + d, n)
	# escada de mão encostada no andaime
	Malha.abrir("escada_de_mao_andaime")
	for lado in [-0.2, 0.2]:
		e.caixa(madeira, Vector3(-19.6 + lado - 0.025, 0.0, -10.2), Vector3(-19.6 + lado + 0.025, 3.3, -10.15), Malha.F_TODAS, 1.0)
	for k in 9:
		e.caixa(madeira, Vector3(-19.8, 0.3 + k * 0.33, -10.21), Vector3(-19.4, 0.33 + k * 0.33, -10.14), Malha.F_TODAS, 1.0)
	Malha.fechar(_et)


# ------------------------------------------------------------------ pilhas de blocos
static func _pilhas(c: Castelinho, g: Castelinho.Grupo, info: Dictionary) -> void:
	var mat: Material = c.m.parede_clara
	var pilhas := [
		[-20.4, -8.3, 0.0], [-18.2, -8.9, 15.0], [-24.8, -7.6, -10.0], [-3.1, -15.5, 0.0], [-3.7, -27.0, 8.0],
		[-14.2, -6.4, 0.0], [-26.5, -16.0, 20.0], [-4.0, -19.0, -6.0],
	]
	var ip := 0
	for p in pilhas:
		var x: float = p[0]
		var z: float = p[1]
		ip += 1
		var _et := Malha.abrir("pilha_blocos_%d" % ip)
		for k in 3:
			var w := 1.5 - 0.35 * k
			var d := 0.9 - 0.15 * k
			g.ext.caixa(mat, Vector3(x - w * 0.5, k * 0.3, z - d * 0.5), Vector3(x + w * 0.5, (k + 1) * 0.3, z + d * 0.5), Malha.F_SEM_BASE)
		g.ext.col(Vector3(x - 0.75, 0, z - 0.45), Vector3(x + 0.75, 0.9, z + 0.45))
		Malha.fechar(_et)
		info["volumes"].append([x - 0.8, x + 0.8, z - 0.5, z + 0.5, 0.9])


# ------------------------------------------------------------------ barco de madeira encalhado
static func _barco(c: Castelinho, g: Castelinho.Grupo) -> void:
	# revisão V2: o casco era madeira quase preta com o costado azul chapado (de longe, uma mancha azul). Agora:
	# madeira cinza-clara de barco velho por dentro e no fundo, costado verde-água desbotado.
	var madeira: Material = Castelinho.mat_cor(Color(0.6, 0.55, 0.48), 0.95)
	var pintura := Castelinho.mat_cor(Color(0.36, 0.6, 0.58), 0.9)
	var o := Vector3(-16.6, 0.0, -4.2)
	var b := Basis.from_euler(Vector3(deg_to_rad(8.0), deg_to_rad(28.0), deg_to_rad(-6.0)))
	var L := 3.6
	var n := 8
	var est: Array = []         # por estação: [quilha, quina_e, borda_e, quina_d, borda_d]
	for i in n + 1:
		var t := float(i) / float(n)
		var u := t * 2.0 - 1.0
		var larg := 0.62 * sqrt(maxf(0.0, 1.0 - pow(absf(u), 2.6)))
		var quilha := 0.1 + 0.05 * u * u
		var borda := 0.72 + 0.22 * u * u
		var x := u * L * 0.5
		var quina := quilha + 0.22
		est.append([
			o + b * Vector3(x, quilha, 0.0),
			o + b * Vector3(x, quina, larg * 0.8),
			o + b * Vector3(x, borda, larg),
			o + b * Vector3(x, quina, -larg * 0.8),
			o + b * Vector3(x, borda, -larg),
		])
	var e := g.ext
	var cima := Vector3.UP
	var _et := Malha.abrir("barco_encalhado")
	for i in n:
		var a: Array = est[i]
		var d: Array = est[i + 1]
		# casco por fora (fundo e costado), e por dentro (mesmas faces, normal oposta)
		var pares := [[0, 1], [1, 2], [0, 3], [3, 4]]
		for pr in pares:
			var p0: Vector3 = a[pr[0]]
			var p1: Vector3 = a[pr[1]]
			var q1: Vector3 = d[pr[1]]
			var q0: Vector3 = d[pr[0]]
			var centro := (p0 + p1 + q0 + q1) * 0.25
			var fora := (centro - (o + b * Vector3(0, 0.5, 0))).normalized()
			e.quad_auto(pintura if pr[1] == 2 or pr[1] == 4 else madeira, p0, p1, q1, q0, fora, Vector2(1.0, 1.0))
			e.quad_auto(madeira, p0, p1, q1, q0, -fora, Vector2(1.0, 1.0))
		# fio da borda (um filete de madeira por cima)
		for lado in [2, 4]:
			var pa: Vector3 = a[lado]
			var pb: Vector3 = d[lado]
			e.quad_auto(madeira, pa, pb, pb + cima * 0.04, pa + cima * 0.04, cima, Vector2(1.0, 1.0))
	# bancos (tábuas atravessadas) e um remo caído ao lado
	for t in [-0.45, 0.0, 0.5]:
		var x: float = t * L
		var lar := 0.55
		_caixa_rot(e, madeira, o, b, Vector3(x - 0.14, 0.5, -lar), Vector3(x + 0.14, 0.56, lar))
	Malha.abrir("remo_barco")
	_caixa_rot(e, madeira, Vector3(-14.9, 0.05, -3.1), Basis.from_euler(Vector3(0, deg_to_rad(-20.0), 0)), Vector3(-1.1, 0.0, -0.03), Vector3(1.1, 0.06, 0.03))
	g.ext.col(Vector3(-18.2, 0, -5.2), Vector3(-15.0, 0.8, -3.2))
	Malha.fechar(_et)


## Caixa "girada": 8 cantos transformados por `b` ao redor de `o`, só as 4 faces de cima/laterais (peça pequena).
static func _caixa_rot(m: Malha, mat: Material, o: Vector3, b: Basis, p0: Vector3, p1: Vector3) -> void:
	var cs: Array = []
	for i in 8:
		cs.append(o + b * Vector3(p0.x if (i & 1) == 0 else p1.x, p0.y if (i & 2) == 0 else p1.y, p0.z if (i & 4) == 0 else p1.z))
	var faces := [[0, 1, 5, 4, Vector3.DOWN], [2, 6, 7, 3, Vector3.UP], [0, 4, 6, 2, Vector3.LEFT], [1, 3, 7, 5, Vector3.RIGHT],
		[0, 2, 3, 1, Vector3.BACK], [4, 5, 7, 6, Vector3.FORWARD]]
	for f in faces:
		var n: Vector3 = b * (f[4] as Vector3)
		m.quad_auto(mat, cs[f[0]], cs[f[1]], cs[f[2]], cs[f[3]], n, Vector2(1.0, 1.0))


# ------------------------------------------------------------------ muro baixo da Garibaldi, com o buraco de criança
static func _muro_com_buraco(c: Castelinho, g: Castelinho.Grupo) -> void:
	var xb := BURACO_POS.x
	# o muro corre ao longo da Garibaldi; a abertura (0,75 m x 0,85 m) é o buraco por onde Tito entrava na obra
	c.parede_x(g, -1.0, -29.8, -3.6, 1, 0.0, 1.1, [Muros.ab(xb, 0.75, 0.0, 0.85, 0.85, "ret")], "ext", "ext", {"tampa": true}, 0.25)
	# revisão V2: o vão retangular parecia uma porta. Blocos meio quebrados avançam para dentro do vão (bordas
	# serrilhadas) e o alto cede: lê como um buraco aberto a chute, do tamanho de uma criança.
	var _et := Malha.abrir("buraco_muro_dentes")
	var dentes := [[-0.38, 0.62, -0.2, 0.85], [-0.16, 0.74, 0.1, 0.85], [0.22, 0.58, 0.38, 0.85], [-0.38, 0.0, -0.26, 0.22],
		[-0.38, 0.34, -0.3, 0.5], [0.28, 0.12, 0.38, 0.3], [0.3, 0.4, 0.38, 0.52]]
	for dd in dentes:
		g.ext.caixa(c.m.parede, Vector3(xb + dd[0], dd[1], -1.28), Vector3(xb + dd[2], dd[3], -0.97), Malha.F_SEM_BASE)
	# blocos quebrados jogados em volta do buraco
	for k in 5:
		Malha.abrir("bloco_quebrado_buraco_%d" % (k + 1))
		var dx := -0.55 + 0.28 * k
		g.ext.caixa(c.m.parede_clara, Vector3(xb + dx - 0.1, 0.0, -0.45 + 0.1 * float(k % 2)), Vector3(xb + dx + 0.1, 0.16, -0.25 + 0.1 * float(k % 2)), Malha.F_SEM_BASE)
	# o muro termina em pilaretes: dois pilaretes na ponta do portão
	Malha.abrir("pilarete_portao_obra")
	g.ext.caixa(c.m.parede, Vector3(-3.8, 0, -1.25), Vector3(-3.3, 1.4, -0.75), Malha.F_SEM_BASE)
	Malha.fechar(_et)


# ------------------------------------------------------------------ castelinho de areia (Tito brinca ao lado)
static func _castelo_de_areia(c: Castelinho, g: Castelinho.Grupo) -> void:
	var areia := Castelinho.mat_cor(Color(0.86, 0.74, 0.5), 1.0)
	var areia2 := Castelinho.mat_cor(Color(0.78, 0.66, 0.43), 1.0)
	var o := TITO_POS + Vector3(0.62, 0, 0.1)
	var _et := Malha.abrir("castelinho_de_areia")
	g.ext.caixa(areia, o + Vector3(-0.32, 0, -0.22), o + Vector3(0.32, 0.18, 0.22), Malha.F_SEM_BASE)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g.ext.caixa(areia2, o + Vector3(0.3 * sx - 0.07, 0.0, 0.2 * sz - 0.07), o + Vector3(0.3 * sx + 0.07, 0.3, 0.2 * sz + 0.07), Malha.F_SEM_BASE)
			g.ext.caixa(areia, o + Vector3(0.3 * sx - 0.045, 0.3, 0.2 * sz - 0.045), o + Vector3(0.3 * sx + 0.045, 0.36, 0.2 * sz + 0.045), Malha.F_SEM_BASE)
	g.ext.caixa(areia2, o + Vector3(-0.1, 0.18, -0.08), o + Vector3(0.1, 0.34, 0.08), Malha.F_SEM_BASE)
	# poça de areia revirada e a pazinha
	Malha.abrir("poca_de_areia_tito")
	g.ext.caixa(areia2, TITO_POS + Vector3(-0.5, 0, -0.35), TITO_POS + Vector3(-0.2, 0.05, -0.05), Malha.F_SEM_BASE)
	Malha.fechar(_et)


# ------------------------------------------------------------------ canteiro de obra (revisão V2)
## O que diz "obra" de longe: carrinho de mão, caixa de massa, monte de areia grossa, sacos de cimento e tábuas.
static func _canteiro(c: Castelinho, g: Castelinho.Grupo) -> void:
	var e := g.ext
	var pinho: Material = Castelinho.mat_cor(Color(0.78, 0.62, 0.42), 0.95)
	var ferro := Castelinho.mat_cor(Color(0.3, 0.32, 0.3), 0.6)
	var massa := Castelinho.mat_cor(Color(0.6, 0.6, 0.58), 1.0)
	var saco := Castelinho.mat_cor(Color(0.82, 0.76, 0.6), 1.0)
	var areia := Castelinho.mat_cor(Color(0.72, 0.6, 0.42), 1.0)
	# carrinho de mão (caçamba de chapa, roda e dois braços) ao pé do andaime
	var o := Vector3(-17.6, 0.0, -8.6)
	var _et := Malha.abrir("carrinho_de_mao")
	e.caixa(ferro, o + Vector3(-0.35, 0.3, -0.3), o + Vector3(0.35, 0.62, 0.3), Malha.F_TODAS)
	e.caixa(massa, o + Vector3(-0.3, 0.62, -0.25), o + Vector3(0.3, 0.64, 0.25), Malha.F_PY)
	e.caixa(ferro, o + Vector3(0.45, 0.05, -0.05), o + Vector3(0.65, 0.3, 0.05), Malha.F_TODAS)
	for lado in [-0.22, 0.22]:
		e.caixa(pinho, o + Vector3(-1.1, 0.42, lado - 0.025), o + Vector3(0.45, 0.47, lado + 0.025), Malha.F_TODAS, 1.0)
		e.caixa(ferro, o + Vector3(-0.3, 0.0, lado - 0.02), o + Vector3(-0.26, 0.3, lado + 0.02), Malha.F_TODAS)
	# caixa de massa (tábuas baixas com argamassa cinza) e a enxada encostada
	var m0 := Vector3(-13.2, 0.0, -8.4)
	Malha.abrir("caixa_de_massa")
	e.caixa(pinho, m0 + Vector3(-0.7, 0.0, -0.45), m0 + Vector3(0.7, 0.25, 0.45), Malha.F_SEM_BASE, 1.0)
	e.caixa(massa, m0 + Vector3(-0.64, 0.2, -0.39), m0 + Vector3(0.64, 0.21, 0.39), Malha.F_PY)
	e.caixa(pinho, m0 + Vector3(0.5, 0.2, -0.03), m0 + Vector3(1.6, 0.24, 0.03), Malha.F_TODAS, 1.0)
	# monte de areia grossa (pirâmide baixa) e sacos de cimento empilhados
	Malha.abrir("monte_de_areia_grossa")
	e.piramide(areia, Vector3(-11.5, 0.0, -7.2), 2.2, 1.8, 0.9, 1.0)
	for k in 5:
		Malha.abrir("saco_de_cimento_%d" % (k + 1))
		var px := -9.9 + (k % 3) * 0.48
		var py := 0.0 if k < 3 else 0.18
		var pz := -7.6 + (0.24 if k >= 3 else 0.0)
		e.caixa(saco, Vector3(px - 0.22, py, pz - 0.32), Vector3(px + 0.22, py + 0.18, pz + 0.32), Malha.F_SEM_BASE)
	# tábuas soltas no chão
	for k in 4:
		Malha.abrir("tabua_solta_%d" % (k + 1))
		e.caixa(pinho, Vector3(-21.0 + k * 0.05, 0.02 + k * 0.035, -6.4 - k * 0.32), Vector3(-18.0 + k * 0.05, 0.05 + k * 0.035, -6.15 - k * 0.32), Malha.F_TODAS, 1.0)
	Malha.abrir("")
	g.ext.col(Vector3(-13.9, 0, -8.9), Vector3(-12.5, 0.3, -7.9))
	g.ext.col(Vector3(-12.6, 0, -8.1), Vector3(-10.4, 0.7, -6.3))
	Malha.fechar(_et)


# ------------------------------------------------------------------ casas de madeira em volta (quase ninguém em 1967)
static func _casas(c: Castelinho, g: Castelinho.Grupo) -> void:
	var tabuas: Material = c.m.tabuas
	var telha: Material = Castelinho.mat_uv("telha_ceramica")
	var porta: Material = Castelinho.mat_cor(Color(0.22, 0.17, 0.13), 0.9)
	var janela: Material = Castelinho.mat_cor(Color(0.15, 0.2, 0.24), 0.3)
	# [x, z, largura, profundidade, altura, cumeeira ao longo de x?]
	var casas := [[-14.0, 13.0, 6.0, 4.6, 2.5, true], [-32.0, 10.0, 5.2, 4.2, 2.4, false], [12.5, -14.0, 4.6, 5.8, 2.5, false]]
	for h in casas:
		var cx_: float = h[0]
		var cz: float = h[1]
		var w: float = h[2]
		var d: float = h[3]
		var alt: float = h[4]
		var _et := Malha.abrir("casa_madeira_1967_%d" % (casas.find(h) + 1))
		g.ext.caixa(tabuas, Vector3(cx_ - w * 0.5, 0.35, cz - d * 0.5), Vector3(cx_ + w * 0.5, alt, cz + d * 0.5), Malha.F_SEM_BASE - Malha.F_PY, 1.5)
		# palafita baixa (pilotis) para a areia
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				g.ext.caixa(c.m.madeira, Vector3(cx_ + sx * (w * 0.5 - 0.2) - 0.07, 0, cz + sz * (d * 0.5 - 0.2) - 0.07),
					Vector3(cx_ + sx * (w * 0.5 - 0.2) + 0.07, 0.4, cz + sz * (d * 0.5 - 0.2) + 0.07), Malha.F_TODAS, 1.0)
		EntornoCastelinho._duas_aguas(g.ext, telha, tabuas, cx_, cz, w + 0.7, d + 0.7, alt, 1.4, bool(h[5]))
		# porta e janela na face sul
		g.ext.caixa(porta, Vector3(cx_ - 0.45, 0.35, cz + d * 0.5), Vector3(cx_ + 0.45, 2.1, cz + d * 0.5 + 0.04), Malha.F_TODAS)
		g.ext.caixa(janela, Vector3(cx_ + w * 0.28 - 0.4, 1.1, cz + d * 0.5), Vector3(cx_ + w * 0.28 + 0.4, 1.9, cz + d * 0.5 + 0.04), Malha.F_TODAS)
		Malha.fechar(_et)
