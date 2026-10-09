class_name InteriorCastelinho
extends RefCounted
## Interior oco e caminhável: pisos de pedra, forros com vigas, divisórias, escadas (rampa de colisão por
## baixo dos degraus visuais), poços de escada e lustres. Distribuição plausível (não há planta real):
## ver castelinho/LEIAME.md.

const Y := 3.5


static func construir(c: Castelinho) -> void:
	var g := c.g_base
	_pisos_e_vigas(c)
	_divisorias(c)
	_escada_patio(c)
	_escada_torre(c)
	_lustres(c)
	_bancos_de_pedra(c)
	if g == null:
		return


static func _pisos_e_vigas(c: Castelinho) -> void:
	var g := c.g_base
	# pisos (pedra irregular) cobrindo a pegada de cada volume: ficam sob as paredes e sob os vãos (soleiras)
	for r in [
		[-15.8, -5.0, -14.2, -11.0],    # galeria da arcada (hall)
		[-22.6, -15.8, -15.0, -11.0],   # térreo da Torre A
		[-26.8, -22.6, -15.0, -11.0],   # anexo
		[-25.0, -12.5, -20.5, -15.0],   # bloco do pátio
		[-25.0, -5.0, -23.5, -20.5],    # corredor
		[-12.5, -5.0, -20.5, -14.2],    # corpo principal
		[-17.0, -8.2, -29.5, -23.5],    # ala dos fundos
	]:
		c.piso(g, r[0], r[1], r[2], r[3])
	# vigas aparentes (madeira escura) sob o forro
	c.vigas(g, -15.4, -5.4, -13.8, -11.4, Castelinho.Y_TETO, "z", 1.45)          # hall
	c.vigas(g, -26.4, -16.6, -14.6, -11.4, Castelinho.Y_TETO, "z", 1.4)         # Povos Originários
	c.vigas(g, -24.6, -12.5, -20.1, -15.0, Castelinho.Y_TETO, "z", 1.6)         # Meio Ambiente
	c.vigas(g, -24.6, -5.4, -23.1, -20.5, Castelinho.Y_TETO, "z", 1.5)          # corredor
	c.vigas(g, -22.2, -16.2, -14.6, -11.4, 6.5, "z", 1.4)                       # 2º nível da torre


## Divisórias internas (espessura 0,22): a do corpo principal (Salão de Arte / Sala do Pescador) e a da escada.
static func _divisorias(c: Castelinho) -> void:
	var g := c.g_base
	# P1: separa o Salão de Arte/Acervo (norte) da Sala do Pescador (sul), com arco a leste
	var arco := [Muros.ab(-6.4, 1.3, 0.0, 1.9, 2.35, "arco")]
	c.parede_x(g, -17.19, -12.1, -5.4, 1, 0.0, Castelinho.Y_TETO_CORPO, arco, "int", "int", {}, Castelinho.TI)
	# corredor da escada do pátio: parede sul (z -19,0 .. -18,78) de x=-21 a x=-12,5
	c.parede_x(g, -18.78, -21.0, -12.5, 1, 0.0, Castelinho.Y_TETO, [], "int", "int", {}, Castelinho.TI)


# ------------------------------------------------------------------ escadas
## Escada reta ao longo de X: de x_ini (cota y_ini) a x_fim (cota y_fim), largura z0..z1, maciça até base_y.
## Degraus visuais de ~19 cm + rampa de colisão convexa por baixo (CharacterBody sobe degraus mal).
static func escada_x(c: Castelinho, ma: Malha, mat: Material, x_ini: float, x_fim: float, z0: float, z1: float, y_ini: float, y_fim: float, base_y: float) -> void:
	var dy := y_fim - y_ini
	var dx := x_fim - x_ini
	var n := maxi(2, int(ceil(absf(dy) / 0.19)))
	for k in range(1, n + 1):
		var xa := x_ini + dx * float(k - 1) / n
		var xb := x_ini + dx * float(k) / n
		var yk := y_ini + dy * float(k) / n
		ma.caixa(mat, Vector3(minf(xa, xb), base_y, z0), Vector3(maxf(xa, xb), yk, z1), Malha.F_SEM_BASE)
	var pts := PackedVector3Array()
	for z in [z0, z1]:
		pts.append(Vector3(x_ini, base_y, z))
		pts.append(Vector3(x_fim, base_y, z))
		pts.append(Vector3(x_fim, y_fim, z))
		pts.append(Vector3(x_ini, y_ini, z))
	ma.rampa(pts)


## Mureta inclinada (guarda-corpo de pedra) acompanhando a escada, em z0..z1.
static func guarda_x(c: Castelinho, ma: Malha, mat: Material, x_a: float, x_b: float, y_a: float, y_b: float, alt: float, z0: float, z1: float) -> void:
	var a0 := Vector3(x_a, y_a, z0)
	var b0 := Vector3(x_b, y_b, z0)
	var a1 := Vector3(x_a, y_a, z1)
	var b1 := Vector3(x_b, y_b, z1)
	var up := Vector3(0, alt, 0)
	ma.quad_auto(mat, a0, b0, b0 + up, a0 + up, Vector3(0, 0, -1))
	ma.quad_auto(mat, a1, b1, b1 + up, a1 + up, Vector3(0, 0, 1))
	ma.quad_auto(mat, a0 + up, b0 + up, b1 + up, a1 + up, Vector3.UP)
	var pts := PackedVector3Array([a0, b0, b0 + up, a0 + up, a1, b1, b1 + up, a1 + up])
	ma.rampa(pts)


static func _escada_patio(c: Castelinho) -> void:
	var g := c.g_base
	# sobe de oeste para... de x=-13,0 (cota 0) até x=-20,6 (cota 3,5) no corredor z -20,1 .. -19,0; pouso até x=-21
	escada_x(c, g.inte, c.m.piso, -13.0, -20.6, -20.1, -19.0, 0.0, Y, 0.0)
	g.inte.caixa(c.m.piso, Vector3(-21.0, 0.0, -20.1), Vector3(-20.6, Y, -19.0), Malha.F_SEM_BASE)
	g.inte.col(Vector3(-21.0, 0.0, -20.1), Vector3(-20.6, Y, -19.0))
	# bordas do poço da escada (faces verticais da laje voltadas para o furo)
	var e := g.ext
	var m: Material = c.m.laje
	var y0 := 3.2
	e.quad(m, Vector3(-21.0, y0, -20.1), Vector3(-16.0, y0, -20.1), Vector3(-16.0, Y, -20.1), Vector3(-21.0, Y, -20.1), Vector3(0, 0, 1))
	e.quad(m, Vector3(-21.0, y0, -19.0), Vector3(-16.0, y0, -19.0), Vector3(-16.0, Y, -19.0), Vector3(-21.0, Y, -19.0), Vector3(0, 0, -1))
	e.quad(m, Vector3(-21.0, y0, -20.1), Vector3(-21.0, y0, -19.0), Vector3(-21.0, Y, -19.0), Vector3(-21.0, Y, -20.1), Vector3(1, 0, 0))
	e.quad(m, Vector3(-16.0, y0, -20.1), Vector3(-16.0, y0, -19.0), Vector3(-16.0, Y, -19.0), Vector3(-16.0, Y, -20.1), Vector3(-1, 0, 0))


static func _escada_torre(c: Castelinho) -> void:
	var g := c.g_base
	# 2º nível -> terraço: patamar de chegada x -17,4..-16,2; sobe junto à parede norte de x=-17,4 (cota 3,5) até
	# x=-21,3 (cota 6,8); pouso até x=-22,2 (a saída é pelo lado sul, a laje do terraço fica rente ao patamar)
	var incl := 3.3 / 3.9
	escada_x(c, g.inte, c.m.piso, -17.4, -21.3, -14.6, -13.5, Y, 6.8, Y)
	g.inte.caixa(c.m.piso, Vector3(-22.2, Y, -14.6), Vector3(-21.3, 6.8, -13.5), Malha.F_SEM_BASE)
	g.inte.col(Vector3(-22.2, Y, -14.6), Vector3(-21.3, 6.8, -13.5))
	# guarda de pedra só no trecho alto, onde a queda passa de 1 m (o pé da escada fica aberto para o cômodo)
	guarda_x(c, g.inte, c.m.parede_int, -18.7, -21.1, Y + 1.3 * incl, Y + 3.7 * incl, 0.95, -13.62, -13.5)
	# bordas do poço (face vertical da laje do terraço): x -22,2..-18,2
	var e := g.ext
	var m: Material = c.m.laje
	var ya := 6.5
	var yb := 6.8
	e.quad(m, Vector3(-22.2, ya, -14.6), Vector3(-18.2, ya, -14.6), Vector3(-18.2, yb, -14.6), Vector3(-22.2, yb, -14.6), Vector3(0, 0, 1))
	e.quad(m, Vector3(-22.2, ya, -13.5), Vector3(-18.2, ya, -13.5), Vector3(-18.2, yb, -13.5), Vector3(-22.2, yb, -13.5), Vector3(0, 0, -1))
	e.quad(m, Vector3(-18.2, ya, -14.6), Vector3(-18.2, ya, -13.5), Vector3(-18.2, yb, -13.5), Vector3(-18.2, yb, -14.6), Vector3(-1, 0, 0))


# ------------------------------------------------------------------ lustres de ferro (pátina verde) + pontos de luz
static func lustre(c: Castelinho, ma: Malha, pos: Vector3, teto: float, tam := 1.0) -> void:
	var ferro: Material = Castelinho.mat_cor(Color(0.10, 0.12, 0.11), 0.9)
	var luz: Material = c.m.luz
	var ch := teto - pos.y
	ma.caixa(ferro, pos + Vector3(-0.012, 0, -0.012), pos + Vector3(0.012, ch, 0.012), Malha.F_TODAS)
	ma.caixa(ferro, pos + Vector3(-0.28 * tam, -0.04, -0.03), pos + Vector3(0.28 * tam, 0.02, 0.03), Malha.F_TODAS)
	ma.caixa(ferro, pos + Vector3(-0.03, -0.04, -0.28 * tam), pos + Vector3(0.03, 0.02, 0.28 * tam), Malha.F_TODAS)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var p: Vector3 = pos + d * 0.3 * tam
		ma.caixa(ferro, p + Vector3(-0.05, 0.02, -0.05), p + Vector3(0.05, 0.07, 0.05), Malha.F_TODAS)
		ma.caixa(luz, p + Vector3(-0.035, 0.07, -0.035), p + Vector3(0.035, 0.2, 0.035), Malha.F_TODAS)


static func _lustres(c: Castelinho) -> void:
	var g := c.g_base
	# [posição do centro do lustre, altura do forro]
	var lista := [
		[Vector3(-10.4, 2.55, -12.6), 3.2, "hall"],
		[Vector3(-18.3, 2.55, -12.9), 3.2, "povos"],
		[Vector3(-24.7, 2.55, -12.9), 3.2, "povos"],
		[Vector3(-17.0, 2.55, -17.7), 3.2, "ambiente"],
		[Vector3(-22.0, 2.55, -17.7), 3.2, "ambiente"],
		[Vector3(-22.0, 2.55, -21.8), 3.2, "corredor"],
		[Vector3(-13.0, 2.55, -21.8), 3.2, "corredor"],
		[Vector3(-8.0, 2.55, -21.8), 3.2, "corredor"],
		[Vector3(-8.7, 3.0, -18.7), 3.9, "arte"],
		[Vector3(-8.7, 3.0, -15.7), 3.9, "pescador"],
		[Vector3(-12.6, 2.65, -26.3), 3.4, "medieval"],
		[Vector3(-19.4, 5.85, -12.9), 6.5, "torre2"],
		[Vector3(-6.6, 4.9, -24.9), 5.9, "torreb"],
	]
	for l in lista:
		lustre(c, g.inte, l[0], l[1], 1.0)
		c.luzes.append({"pos": l[0] - Vector3(0, 0.3, 0), "sala": l[2]})


## Banco de pedra e mesa de pedra (churrasqueira) no gramado, como nas fotos.
static func _bancos_de_pedra(c: Castelinho) -> void:
	var g := c.g_base
	var pe: Material = c.m.parede
	# mesa de pedra com bancos (jardim, lado oeste, foto frontal 2026)
	g.ext.caixa(pe, Vector3(-24.6, 0, -7.4), Vector3(-23.2, 0.75, -6.6), Malha.F_TODAS)
	g.ext.col(Vector3(-24.6, 0, -7.4), Vector3(-23.2, 0.75, -6.6))
	g.ext.caixa(pe, Vector3(-25.0, 0.0, -8.1), Vector3(-22.8, 0.42, -7.5), Malha.F_TODAS)
	g.ext.caixa(pe, Vector3(-25.0, 0.0, -6.5), Vector3(-22.8, 0.42, -5.9), Malha.F_TODAS)
	g.ext.col(Vector3(-25.0, 0.0, -8.1), Vector3(-22.8, 0.42, -5.9))
	# churrasqueira de pedra
	g.ext.caixa(pe, Vector3(-27.0, 0, -6.9), Vector3(-25.6, 0.9, -5.7), Malha.F_TODAS)
	g.ext.col(Vector3(-27.0, 0, -6.9), Vector3(-25.6, 0.9, -5.7))
