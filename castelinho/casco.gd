class_name CascoCastelinho
extends RefCounted
## Casco externo do Castelinho: fachadas, torres, ameias, cornijas, coberturas, chaminés e lajes.
## Tudo em coordenadas do Godot (x leste, z sul). Alturas validadas contra as fotos (ver LEIAME.md).

const Y := 3.5                   # laje/terraço
const N_S := Vector3(0, 0, 1)    # normal da fachada sul
const N_N := Vector3(0, 0, -1)
const N_L := Vector3(1, 0, 0)
const N_O := Vector3(-1, 0, 0)
const U_X := Vector3(1, 0, 0)
const U_Z := Vector3(0, 0, 1)


static func oz(z: float) -> Vector3:
	return Vector3(0, 0, z)    # origem de parede ao longo de X (uu = x absoluto)


static func ox(x: float) -> Vector3:
	return Vector3(x, 0, 0)    # origem de parede ao longo de Z (uu = z absoluto)


static func construir(c: Castelinho) -> void:
	_fachada_sul(c)
	_fachada_leste(c)
	_corpo_principal(c)
	_torre_a(c)
	_anexo_e_pavilhao(c)
	_bloco_patio(c)
	_corredor(c)
	_ala_fundos(c)
	_torre_b(c)
	_lajes(c)
	_chamines(c)


# ------------------------------------------------------------------ fachada sul (Av. Garibaldi): arcada
static func _fachada_sul(c: Castelinho) -> void:
	var g := c.g_base
	var z := -11.0
	var arcos: Array = []
	for a in Castelinho.medidas.get("arcos_fachada_sul", {}).get("arcos", []):
		arcos.append(Muros.ab(a["x"], a["w"], 0.0, a["imposta"], a["coroa"], "arco"))
	c.parede_x(g, z, -15.8, -5.0, 1, 0.0, Y, arcos, "ext", "int")
	c.parapeito(g, Vector3(-15.8, 0, z), U_X, N_S, 10.8, Y, 4.0)
	for a in Castelinho.medidas.get("arcos_fachada_sul", {}).get("arcos", []):
		c.arquivolta(g, oz(z), U_X, N_S, a["x"], a["w"], a["imposta"], a["coroa"], "arco")
	# parapeito da borda leste do terraço da arcada
	c.parapeito(g, Vector3(-5.0, 0, -14.2), U_Z, N_L, 3.2, Y, 4.0)


# ------------------------------------------------------------------ fachada leste (Av. Nilza): letreiro, janelas, porta
static func _fachada_leste(c: Castelinho) -> void:
	var g := c.g_base
	var fl: Dictionary = Castelinho.medidas.get("fachada_leste", {})
	var x := -5.0
	# trecho da arcada (z -14 .. -11): janela 1 (grade) no hall
	var j: Array = fl.get("janelas", [])
	var jan1: Dictionary = j[0]
	var jan2: Dictionary = j[1]
	var ab1 := [Muros.ab(jan1["z"], jan1["w"], jan1["base"], jan1["base"] + jan1["h"], -1.0, "ret")]
	c.parede_z(c.g_base, x, -14.0, -11.0, 1, 0.0, Y, ab1, "ext", "int")
	# trecho do corpo principal (z -20.5 .. -14): janela 2, porta em arco, beiral a 4,2 m
	var p: Dictionary = fl.get("porta", {})
	var ab2 := [
		Muros.ab(jan2["z"], jan2["w"], jan2["base"], jan2["base"] + jan2["h"], -1.0, "ret"),
		Muros.ab(p["z"], p["w"], 0.0, p["imposta"], p["coroa"], "arco"),
	]
	c.parede_z(g, x, -20.5, -14.0, 1, 0.0, 4.2, ab2, "ext", "int", {"tampa": true})
	# janelas com grade de losangos + venezianas (decoração)
	var o := ox(x)
	c.janela_grade(g, o, U_Z, N_L, jan1["z"], jan1["w"], jan1["base"], jan1["h"])
	c.janela_grade(g, o, U_Z, N_L, jan2["z"], jan2["w"], jan2["base"], jan2["h"])
	# porta de madeira em arco (fechada), 2 folhas com 4 vidros cada
	c.porta_arco_fechada(g.ext, o, U_Z, N_L, p["z"], p["w"], 0.0, p["imposta"], p["coroa"], 0.2, true)
	# a porta fechada era só pintura (o vão da parede ficava sem colisão): em 1975 e 2019, sem a cerca do museu,
	# dava para entrar no Salão de Arte pela Av. Nilza
	g.ext.col(Vector3(x - 0.45, 0.0, p["z"] - p["w"] * 0.5), Vector3(x + 0.05, p["coroa"], p["z"] + p["w"] * 0.5))
	c.arquivolta(g, o, U_Z, N_L, p["z"], p["w"], p["imposta"], p["coroa"], "arco")
	# frestas sob o beiral (decalque escuro) e janela alta de veneziana fechada
	var fr: Dictionary = fl.get("frestas", {})
	for fz in fr.get("z", []):
		c.decalque_vao(g.ext, c.m.escuro, o, U_Z, N_L, fz, fr["w"], fr["base"], fr["base"] + fr["h"] - 0.06, fr["base"] + fr["h"], "arco")
	var ja: Dictionary = fl.get("janela_alta", {})
	c.veneziana_fechada(g, o, U_Z, N_L, ja["z"], ja["w"], ja["base"], ja["h"])
	# corredor dos fundos (z -23.5 .. -20.5): janelinha e platibanda
	var ab3 := [Muros.ab(-22.0, 0.6, 1.3, 2.5, -1.0, "ret")]
	c.parede_z(g, x, -23.5, -20.5, 1, 0.0, Y, ab3, "ext", "int")
	c.janela_grade(g, o, U_Z, N_L, -22.0, 0.6, 1.3, 1.2, false)
	c.parede_z(g, x, -23.5, -20.5, 1, Y, 4.6, [], "ext", "ext", {"mat_e": c.m.reboco, "mat_i": c.m.reboco, "tampa": true, "mat_topo": c.m.reboco})


# ------------------------------------------------------------------ corpo principal (bloco do letreiro)
static func _corpo_principal(c: Castelinho) -> void:
	var g := c.g_base
	var cp: Dictionary = Castelinho.medidas.get("volumes", {}).get("corpo_principal", {})
	var y_l: float = cp.get("beiral_leste", 4.2)
	var y_o: float = cp.get("cota_alta_oeste", 5.5)
	# sul (dentro: hall e Sala do Pescador; acima da laje: terraço)
	c.parede_x(g, -13.8, -12.5, -5.0, 1, 0.0, Y, [], "int", "int")
	c.parede_x(g, -13.8, -12.5, -5.0, 1, Y, y_o, [], "ext", "int", {"y1b": y_l, "tampa": true})
	# trecho cheio atrás da arcada a oeste do corpo principal (pilastra)
	g.inte.caixa(c.m.parede_int, Vector3(-15.8, 0, -15.0), Vector3(-12.5, Y, -13.8), Malha.F_TODAS - Malha.F_PY - Malha.F_NY)
	g.inte.col(Vector3(-15.8, 0, -15.0), Vector3(-12.5, Y, -13.8))
	# norte (face do corredor; acima da laje: terraço dos fundos)
	var porta_n := [Muros.ab(-8.5, 1.2, 0.0, 1.9, 2.3, "arco")]
	c.parede_x(g, -20.5, -12.5, -5.0, -1, 0.0, Y, porta_n, "int", "int")
	c.parede_x(g, -20.5, -12.5, -5.0, -1, Y, y_o, [], "ext", "int", {"y1b": y_l, "tampa": true})
	# oeste (dentro: pátio/Meio Ambiente; acima da laje: terraço, com janelas altas de veneziana)
	var porta_o := [Muros.ab(-19.55, 0.95, 0.0, 1.85, 2.15, "arco")]
	c.parede_z(g, -12.5, -20.5, -14.0, -1, 0.0, Y, porta_o, "int", "int")
	c.parede_z(g, -12.5, -20.5, -14.0, -1, Y, y_o, [], "ext", "int", {"tampa": true})
	var o := ox(-12.5)
	c.veneziana_fechada(g, o, U_Z, N_O, -17.0, 0.8, 3.9, 1.25)
	c.veneziana_fechada(g, o, U_Z, N_O, -18.4, 0.8, 3.9, 1.25)
	# cobertura de fibrocimento de uma água (cai para o leste), beirais
	var proj: float = cp.get("beiral_projecao", 0.7)
	var k := tan(deg_to_rad(10.0))
	var y_topo_leste := y_l + 0.1
	var x_w := -12.5 - 0.15
	var x_e := -5.0 + proj
	var y_w := y_topo_leste + (-5.0 - x_w) * k
	var y_e := y_topo_leste - proj * k
	g.ext.telhado_agua(c.m.fibro, c.m.madeira, x_w, x_e, -20.5 - 0.3, -14.0 + 0.3, y_w, y_e, 0.1, true)
	# forro de madeira e vigas do corpo principal
	c.forro(g, -12.1, -5.4, -20.1, -14.2, Y_TETO_CORPO)
	c.vigas(g, -12.1, -5.4, -20.1, -14.2, Y_TETO_CORPO, "x", 1.5)
	# beiral de madeira: faixa escura aparente sob a borda leste
	g.ext.caixa(c.m.madeira, Vector3(-5.0, y_l - 0.12, -20.8), Vector3(-5.0 + proj, y_l, -13.7), Malha.F_TODAS, 1.0)


const Y_TETO_CORPO := Castelinho.Y_TETO_CORPO


# ------------------------------------------------------------------ Torre A + torreta piramidal
static func _torre_a(c: Castelinho) -> void:
	var g := c.g_base
	var ta: Dictionary = Castelinho.medidas.get("volumes", {}).get("torre_a", {})
	var yt: float = ta.get("piso_terraco", 6.8)
	var topo: float = ta.get("topo_parede", 7.4)
	var tor: Dictionary = ta.get("torreta", {})
	var yf: float = tor.get("topo_fuste", 8.4)
	var ya: float = tor.get("apice", 9.9)
	# SUL: fresta no térreo, par geminado ogival no 2º nível, fresta na torreta
	var ab_s := [
		Muros.ab(-21.2, 0.22, 1.2, 1.9, 2.2, "ogival"),
		Muros.ab(-20.6, 0.34, 4.0, 5.1, 5.7, "ogival"),
		Muros.ab(-19.9, 0.34, 4.0, 5.1, 5.7, "ogival"),
		Muros.ab(-16.85, 0.22, 4.7, 5.4, 5.7, "ogival"),
	]
	c.parede_x(g, -11.0, -22.6, -15.8, 1, 0.0, yt, ab_s, "ext", "int")
	var o := oz(-11.0)
	for xx in [-20.6, -19.9]:
		c.janela_arco(g, o, U_X, N_S, xx, 0.34, 4.0, 5.1, 5.7, "ogival", "vidro_verde")
	c.janela_arco(g, o, U_X, N_S, -16.85, 0.22, 4.7, 5.4, 5.7, "ogival", "vidro_verde")
	c.janela_arco(g, o, U_X, N_S, -21.2, 0.22, 1.2, 1.9, 2.2, "ogival", "vidro_verde")
	c.arquivolta(g, o, U_X, N_S, -20.25, 1.15, 5.75, 6.2, "arco", 0.1)
	# LESTE (acima da arcada): térreo e 2º nível com porta; aqui o lado de fora é o hall (térreo) e o terraço (acima)
	var porta_t := [Muros.ab(-12.6, 1.3, 0.0, 1.9, 2.3, "arco")]
	c.parede_z(g, -15.8, -15.0, -11.0, 1, 0.0, Y, porta_t, "int", "int")
	var porta_2 := [Muros.ab(-12.5, 1.2, Y, Y + 1.9, Y + 2.3, "arco")]
	c.parede_z(g, -15.8, -15.0, -11.0, 1, Y, yt, porta_2, "ext", "int")
	# NORTE: térreo dá no Meio Ambiente (porta); 2º nível dá no terraço do pátio
	var porta_n := [Muros.ab(-18.6, 1.2, 0.0, 1.9, 2.3, "arco")]
	c.parede_x(g, -15.0, -22.6, -15.8, -1, 0.0, Y, porta_n, "int", "int")
	c.parede_x(g, -15.0, -22.6, -15.8, -1, Y, yt, [], "ext", "int")
	# OESTE: arco largo ligando ao anexo (Sala dos Povos Originários) no térreo
	var arco_o := [Muros.ab(-12.9, 1.8, 0.0, 1.9, 2.4, "arco")]
	c.parede_z(g, -22.6, -15.0, -11.0, -1, 0.0, Y, arco_o, "int", "int")
	c.parede_z(g, -22.6, -15.0, -11.0, -1, Y, yt, [], "ext", "int")
	# parapeitos ameados (fora da torreta)
	c.parapeito(g, Vector3(-22.6, 0, -11.0), U_X, N_S, 4.7, yt, topo)
	c.parapeito(g, Vector3(-22.6, 0, -15.0), U_Z, N_O, 4.0, yt, topo)
	c.parapeito(g, Vector3(-22.6, 0, -15.0), U_X, N_N, 6.8, yt, topo)
	c.parapeito(g, Vector3(-15.8, 0, -15.0), U_Z, N_L, 1.9, yt, topo)
	# torreta: fuste maciço até o topo do fuste, cornija e pirâmide
	var tx0: float = tor["x"][0]
	var tx1: float = tor["x"][1]
	var tz0: float = tor["z"][0]
	var tz1: float = tor["z"][1]
	g.ext.caixa(c.m.parede, Vector3(tx0, yt, tz0), Vector3(tx1, yf, tz1), Malha.F_SEM_BASE - Malha.F_PY)
	g.ext.col(Vector3(tx0, yt, tz0), Vector3(tx1, yf, tz1))
	var Lt := tx1 - tx0
	c.cornija(g, Vector3(tx0, 0, tz1), U_X, N_S, Lt, yf)
	c.cornija(g, Vector3(tx1, 0, tz0), U_Z, N_L, tz1 - tz0, yf)
	c.cornija(g, Vector3(tx0, 0, tz0), U_X, N_N, Lt, yf)
	c.cornija(g, Vector3(tx0, 0, tz0), U_Z, N_O, tz1 - tz0, yf)
	var cx := (tx0 + tx1) * 0.5
	var cz := (tz0 + tz1) * 0.5
	g.ext.piramide(c.m.telha, Vector3(cx, yf, cz), Lt + 0.3, tz1 - tz0 + 0.3, ya - yf, 1.0, c.m.madeira)
	g.ext.col(Vector3(tx0, yf, tz0), Vector3(tx1, ya, tz1))
	# fresta em arco no alto do fuste da torreta (sul e leste), como nas fotos
	var yj := yf - 1.15
	c.decalque_vao(g.ext, c.m.escuro, oz(tz1), U_X, N_S, cx, 0.24, yj, yj + 0.5, yj + 0.66, "arco")
	c.decalque_vao(g.ext, c.m.escuro, ox(tx1), U_Z, N_L, cz, 0.24, yj, yj + 0.5, yj + 0.66, "arco")


# ------------------------------------------------------------------ anexo ameado + pavilhão de canto
static func _anexo_e_pavilhao(c: Castelinho) -> void:
	var g := c.g_base
	# SUL do anexo: dois pares de janelas geminadas em arco (veneziana + grade)
	var ab := [
		Muros.ab(-26.1, 0.5, 0.9, 2.0, 2.4, "arco"), Muros.ab(-25.3, 0.5, 0.9, 2.0, 2.4, "arco"),
		Muros.ab(-23.9, 0.5, 0.9, 2.0, 2.4, "arco"), Muros.ab(-23.1, 0.5, 0.9, 2.0, 2.4, "arco"),
	]
	c.parede_x(g, -11.0, -26.8, -22.6, 1, 0.0, Y, ab, "ext", "int")
	c.parapeito(g, Vector3(-26.8, 0, -11.0), U_X, N_S, 4.2, Y, 4.0)
	var o := oz(-11.0)
	for xx in [-26.1, -25.3, -23.9, -23.1]:
		c.janela_arco(g, o, U_X, N_S, xx, 0.5, 0.9, 2.0, 2.4, "arco", "vidro_verde")
	# moldura em arco raso (relevo) sobre cada par de janelas geminadas
	for uc in [-25.7, -23.5]:
		c.arquivolta(g, o, U_X, N_S, uc, 1.7, 2.5, 2.85, "arco", 0.1)
	# folhas de veneziana dos pares (abertas, coladas à parede)
	for par in [[-26.1, -25.3], [-23.9, -23.1]]:
		for lado in [0, 1]:
			var xa: float = par[0] - 0.25 - 0.4 if lado == 0 else par[1] + 0.25
			var xb: float = xa + 0.4
			g.ext.quad(c.m.veneziana, Vector3(xa, 0.85, -10.97), Vector3(xb, 0.85, -10.97), Vector3(xb, 2.45, -10.97), Vector3(xa, 2.45, -10.97), N_S, Vector2(0.4, 1.6))
	# OESTE do anexo
	c.parede_z(g, -26.8, -15.0, -11.0, -1, 0.0, Y, [], "ext", "int")
	c.parapeito(g, Vector3(-26.8, 0, -15.0), U_Z, N_O, 4.0, Y, 4.0)
	# NORTE do anexo (voltada para o Meio Ambiente)
	c.parede_x(g, -15.0, -26.8, -22.6, -1, 0.0, Y, [], "int", "int")
	# pavilhão de canto: torreta baixa isolada
	var pv: Dictionary = Castelinho.medidas.get("volumes", {}).get("pavilhao", {})
	var x0: float = pv["x"][0]
	var x1: float = pv["x"][1]
	var z0: float = pv["z"][0]
	var z1: float = pv["z"][1]
	var yf: float = pv.get("topo_fuste", 4.5)
	var ya: float = pv.get("apice", 5.8)
	g.ext.caixa(c.m.parede, Vector3(x0, 0, z0), Vector3(x1, yf, z1), Malha.F_SEM_BASE - Malha.F_PY - Malha.F_PX)
	g.ext.col(Vector3(x0, 0, z0), Vector3(x1, yf, z1))
	c.cornija(g, Vector3(x0, 0, z1), U_X, N_S, x1 - x0, yf)
	c.cornija(g, Vector3(x0, 0, z0), U_X, N_N, x1 - x0, yf)
	c.cornija(g, Vector3(x0, 0, z0), U_Z, N_O, z1 - z0, yf)
	g.ext.piramide(c.m.telha, Vector3((x0 + x1) * 0.5, yf, (z0 + z1) * 0.5), x1 - x0 + 0.3, z1 - z0 + 0.3, ya - yf, 1.0, c.m.madeira)
	c.decalque_vao(g.ext, c.m.escuro, oz(z1), U_X, N_S, (x0 + x1) * 0.5, 0.2, 1.4, 2.2, 2.55, "ogival")


# ------------------------------------------------------------------ bloco do pátio (Sala Meio Ambiente + escada)
static func _bloco_patio(c: Castelinho) -> void:
	var g := c.g_base
	# OESTE (x=-25): duas frestas ogivais; acima da laje, platibanda branca
	var ab := [Muros.ab(-16.9, 0.3, 1.2, 2.1, 2.5, "ogival"), Muros.ab(-18.9, 0.3, 1.2, 2.1, 2.5, "ogival")]
	c.parede_z(g, -25.0, -20.5, -15.0, -1, 0.0, Y, ab, "ext", "int")
	var o := ox(-25.0)
	for zz in [-16.9, -18.9]:
		c.janela_arco(g, o, U_Z, N_O, zz, 0.3, 1.2, 2.1, 2.5, "ogival", "vidro_ambar")
	c.parapeito(g, Vector3(-25.0, 0, -20.5), U_Z, N_O, 5.5, Y, 4.6, false, false, 0.3, c.m.reboco, c.m.reboco)
	# NORTE (z=-20.5): face voltada ao corredor, porta do Meio Ambiente (x=-22.8)
	var porta := [Muros.ab(-22.8, 1.1, 0.0, 1.9, 2.3, "arco")]
	c.parede_x(g, -20.5, -25.0, -12.5, -1, 0.0, Y, porta, "int", "int")


# ------------------------------------------------------------------ corredor dos fundos (Secretaria) sob a laje
static func _corredor(c: Castelinho) -> void:
	var g := c.g_base
	var reb: Material = c.m.reboco
	# OESTE
	c.parede_z(g, -25.0, -23.5, -20.5, -1, 0.0, Y, [Muros.ab(-22.0, 0.6, 1.3, 2.5, -1.0, "ret")], "ext", "int")
	c.janela_grade(g, ox(-25.0), U_Z, N_O, -22.0, 0.6, 1.3, 1.2, false)
	# NORTE (z=-23.5): oeste da ala = exterior; ala = interior da Sala Medieval; leste = Torre B
	c.parede_x(g, -23.5, -25.0, -17.0, -1, 0.0, Y, [], "ext", "int")
	var porta_ala := [Muros.ab(-12.6, 1.4, 0.0, 1.95, 2.35, "arco")]
	c.parede_x(g, -23.5, -17.0, -8.2, -1, 0.0, Y, porta_ala, "int", "int")
	c.parede_x(g, -23.5, -8.2, -5.0, -1, 0.0, Y, [], "int", "int")
	# platibandas brancas (1,1 m) nas bordas do terraço do corredor/pátio
	c.parapeito(g, Vector3(-25.0, 0, -23.5), U_X, N_N, 8.0, Y, 4.6, false, false, 0.3, reb, reb)
	c.parapeito(g, Vector3(-25.0, 0, -23.5), U_Z, N_O, 3.0, Y, 4.6, false, false, 0.3, reb, reb)
	# parede norte do corredor acima da laje, voltada ao sul (lado da ala dos fundos)
	c.parede_x(g, -23.1, -17.0, -8.2, 1, Y, 4.4, [], "ext", "int")


# ------------------------------------------------------------------ ala dos fundos (Sala Medieval)
static func _ala_fundos(c: Castelinho) -> void:
	var g := c.g_base
	var ad: Dictionary = Castelinho.medidas.get("volumes", {}).get("ala_fundos", {})
	var y_n: float = ad.get("beiral", 3.6) + 0.1
	var y_s: float = ad.get("cota_alta", 4.6) - 0.2
	# OESTE: dois portões em arco (madeira escura)
	var portoes := [Muros.ab(-24.8, 1.4, 0.0, 1.8, 2.4, "arco"), Muros.ab(-26.6, 1.4, 0.0, 1.8, 2.4, "arco")]
	c.parede_z(g, -17.0, -29.5, -23.5, -1, 0.0, y_n, portoes, "ext", "int", {"y1b": y_s, "tampa": true})
	var o := ox(-17.0)
	for zz in [-24.8, -26.6]:
		c.porta_arco_fechada(g.ext, o, U_Z, N_O, zz, 1.4, 0.0, 1.8, 2.4, 0.2, false)
		# os portões fechados eram só pintura: o vão da parede ficava sem colisão e dava para entrar na Sala Medieval
		# pelos fundos do lote, pulando as salas 7 a 20 (e o Visor)
		g.ext.col(Vector3(-17.45, 0.0, zz - 0.7), Vector3(-16.95, 2.4, zz + 0.7))
	# LESTE
	c.parede_z(g, -8.2, -29.5, -23.5, 1, 0.0, y_n, [], "ext", "int", {"y1b": y_s, "tampa": true})
	# NORTE: porta de saída (x=-10.2), lareira por dentro; frestas cegas
	var saida := [Muros.ab(-10.2, 1.4, 0.0, 1.95, 2.35, "arco")]
	c.parede_x(g, -29.5, -17.0, -8.2, -1, 0.0, y_n, saida, "ext", "int", {"tampa": true})
	for xx in [-16.0, -8.9]:
		c.decalque_vao(g.ext, c.m.escuro, oz(-29.5), U_X, N_N, xx, 0.2, 1.6, 2.4, 2.75, "ogival")
	# cobertura de fibrocimento de uma água (cai para o norte)
	var k := tan(deg_to_rad(10.0))
	g.ext.telhado_agua_z(c.m.fibro, c.m.madeira, -17.0 - 0.5, -8.2 + 0.4, -29.5 - 0.6, -23.1, y_n + 0.1 - 0.6 * k, y_s + 0.1, 0.1)
	# forro e vigas da sala
	c.forro(g, -16.6, -8.6, -29.1, -23.5, 3.4)
	c.vigas(g, -16.6, -8.6, -29.1, -23.5, 3.4, "x", 1.6)


# ------------------------------------------------------------------ Torre B (quarto pequeno sobre o corredor)
static func _torre_b(c: Castelinho) -> void:
	var g := c.g_base
	var tb: Dictionary = Castelinho.medidas.get("volumes", {}).get("torre_b", {})
	var yt: float = tb.get("piso_terraco", 5.9) + 0.3     # topo da laje do teto
	var topo: float = tb.get("topo_parede", 6.2) + 0.6
	var tor: Dictionary = tb.get("torreta", {})
	var yf: float = tor.get("topo_fuste", 7.0)
	var ya: float = tor.get("apice", 8.5)
	# base maciça (do chão à laje do corredor)
	g.ext.caixa(c.m.parede, Vector3(-8.2, 0, -26.7), Vector3(-5.0, Y, -23.5), Malha.F_PX | Malha.F_NZ)
	g.ext.col(Vector3(-8.2, 0, -26.7), Vector3(-5.0, Y, -23.5))
	# paredes do quarto (3,5 .. 6,2), face externa em ext
	var fr := [Muros.ab(-24.4, 0.2, 4.4, 5.3, 5.6, "ogival"), Muros.ab(-25.6, 0.2, 4.4, 5.3, 5.6, "ogival")]
	c.parede_z(g, -5.0, -26.7, -23.5, 1, Y, yt, fr, "ext", "int")
	c.parede_z(g, -8.2, -26.7, -23.5, -1, Y, yt, [], "ext", "int")
	c.parede_x(g, -26.7, -8.2, -5.0, -1, Y, yt, [], "ext", "int")
	# sul (lado do terraço): porta em arco aberta, escura (foto aérea 2019)
	var porta := [Muros.ab(-7.2, 1.0, Y, Y + 1.8, Y + 2.2, "arco")]
	c.parede_x(g, -23.1, -8.2, -5.0, 1, Y, yt, porta, "ext", "int", {"y1b": yt})
	var o := ox(-5.0)
	for zz in [-24.4, -25.6]:
		c.janela_arco(g, o, U_Z, N_L, zz, 0.2, 4.4, 5.3, 5.6, "ogival", "vidro_verde")
	# parapeitos ameados
	c.parapeito(g, Vector3(-8.2, 0, -23.1), U_X, N_S, 3.2, yt, topo)
	c.parapeito(g, Vector3(-5.0, 0, -26.7), U_Z, N_L, 3.6, yt, topo)
	c.parapeito(g, Vector3(-8.2, 0, -26.7), U_X, N_N, 3.2, yt, topo)
	c.parapeito(g, Vector3(-8.2, 0, -26.7), U_Z, N_O, 3.6, yt, topo)
	# torreta no canto SE, cornija e pirâmide
	var tx0: float = tor["x"][0]
	var tx1: float = tor["x"][1]
	var tz0: float = tor["z"][0]
	var tz1: float = tor["z"][1]
	g.ext.caixa(c.m.parede, Vector3(tx0, yt, tz0), Vector3(tx1, yf, tz1), Malha.F_SEM_BASE - Malha.F_PY)
	c.cornija(g, Vector3(tx0, 0, tz1), U_X, N_S, tx1 - tx0, yf)
	c.cornija(g, Vector3(tx1, 0, tz0), U_Z, N_L, tz1 - tz0, yf)
	c.cornija(g, Vector3(tx0, 0, tz0), U_X, N_N, tx1 - tx0, yf)
	c.cornija(g, Vector3(tx0, 0, tz0), U_Z, N_O, tz1 - tz0, yf)
	g.ext.piramide(c.m.telha, Vector3((tx0 + tx1) * 0.5, yf, (tz0 + tz1) * 0.5), tx1 - tx0 + 0.3, tz1 - tz0 + 0.3, ya - yf, 1.0, c.m.madeira)
	var yjb := yf - 1.0
	c.decalque_vao(g.ext, c.m.escuro, oz(tz1), U_X, N_S, (tx0 + tx1) * 0.5, 0.2, yjb, yjb + 0.42, yjb + 0.56, "arco")
	c.decalque_vao(g.ext, c.m.escuro, ox(tx1), U_Z, N_L, (tz0 + tz1) * 0.5, 0.2, yjb, yjb + 0.42, yjb + 0.56, "arco")
	# laje do teto e piso do quarto
	g.ext.caixa(c.m.laje, Vector3(-8.2, 5.9, -26.7), Vector3(-5.0, 6.2, -23.1), Malha.F_PY)
	g.inte.caixa(c.m.forro, Vector3(-8.2, 5.9, -26.7), Vector3(-5.0, 6.2, -23.1), Malha.F_NY, 1.5)
	g.col_sempre.col(Vector3(-8.2, 5.9, -26.7), Vector3(-5.0, 6.2, -23.1))
	g.inte.quad(c.m.piso, Vector3(-7.8, Y + 0.012, -26.3), Vector3(-5.4, Y + 0.012, -26.3), Vector3(-5.4, Y + 0.012, -23.5), Vector3(-7.8, Y + 0.012, -23.5), Vector3.UP)


# ------------------------------------------------------------------ lajes (terraços) a 3,5 m
static func _lajes(c: Castelinho) -> void:
	var g := c.g_base
	# arcada (forro do hall + terraço) e tira atrás
	c.laje(g, -15.8, -5.0, -14.2, -11.0, Y)
	c.laje(g, -15.8, -12.5, -15.0, -14.2, Y)
	# anexo
	c.laje(g, -26.8, -22.6, -15.0, -11.0, Y)
	# bloco do pátio (com furo da escada: x -21..-16, z -20.1..-19.0)
	c.laje(g, -25.0, -21.0, -20.5, -15.0, Y)
	c.laje(g, -21.0, -16.0, -20.5, -20.1, Y)
	c.laje(g, -21.0, -16.0, -19.0, -15.0, Y)
	c.laje(g, -16.0, -12.5, -20.5, -15.0, Y)
	# corredor e terraço dos fundos
	c.laje(g, -25.0, -5.0, -23.5, -20.5, Y)
	# lajes da Torre A: piso do 2º nível (interno) e terraço do topo com furo da escada (x -22.2..-18.2, z -14.6..-13.5)
	c.laje(g, -22.2, -16.2, -14.6, -11.4, Y, 0.3, "int")
	var yt := 6.8
	c.laje(g, -22.6, -22.2, -15.0, -11.0, yt)
	c.laje(g, -22.2, -18.2, -15.0, -14.6, yt)
	c.laje(g, -22.2, -18.2, -13.5, -11.0, yt)
	c.laje(g, -18.2, -15.8, -15.0, -11.0, yt)


# ------------------------------------------------------------------ chaminés de bloco
static func _chamines(c: Castelinho) -> void:
	var g := c.g_base
	for ch in Castelinho.medidas.get("chamines", []):
		var x: float = ch["x"]
		var z: float = ch["z"]
		var w: float = ch["w"]
		var b: float = ch["base"]
		var t: float = ch["topo"]
		g.ext.caixa(c.m.parede, Vector3(x - w * 0.5, b, z - w * 0.5), Vector3(x + w * 0.5, t, z + w * 0.5), Malha.F_SEM_BASE - Malha.F_PY)
		g.ext.col(Vector3(x - w * 0.5, b, z - w * 0.5), Vector3(x + w * 0.5, t, z + w * 0.5))
		# capa e pirâmide baixa
		g.ext.caixa(c.m.parede, Vector3(x - w * 0.5 - 0.08, t, z - w * 0.5 - 0.08), Vector3(x + w * 0.5 + 0.08, t + 0.12, z + w * 0.5 + 0.08), Malha.F_SEM_BASE)
		g.ext.piramide(c.m.telha, Vector3(x, t + 0.12, z), w + 0.16, w + 0.16, 0.3, 1.0)
