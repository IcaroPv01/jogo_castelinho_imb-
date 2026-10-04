class_name MobiliaCastelinho
extends RefCounted
## Mobília e acervo do Castelinho, combinados na malha por época:
##  - E2020 (museu): cavaletes com telas, vitrines, mesas de acervo, tronos, lareira, escudos, tochas, mural do pescador
##  - E1975 (casa de veraneio): sofá, poltronas, tapete, mesa, estante (mesmo cômodo da Sala Medieval)
## Também fornece construtores de nós avulsos (pinguim, armadura, telefone) e a textura dos recortes de papelão.

const N_S := Vector3(0, 0, 1)
const N_N := Vector3(0, 0, -1)
const N_L := Vector3(1, 0, 0)
const N_O := Vector3(-1, 0, 0)


## Caixa centrada em `c` com tamanho `t`; `col` = também gera colisão no grupo.
static func cx(g: Castelinho.Grupo, mat: Material, c: Vector3, t: Vector3, col := false, uv := 0.0) -> void:
	var p0 := c - t * 0.5
	var p1 := c + t * 0.5
	g.inte.caixa(mat, p0, p1, Malha.F_TODAS, uv)
	if col:
		g.inte.col(p0, p1)


## Polígono regular (disco) voltado para `n` (escudos redondos). Plano perpendicular a n (n alinhado a x ou z).
static func disco(ma: Malha, mat: Material, c: Vector3, n: Vector3, raio: float, seg := 10) -> void:
	var eixo_u := Vector3.UP.cross(n).normalized()
	var eixo_v := Vector3.UP
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var p0 := c + (eixo_u * cos(a0) + eixo_v * sin(a0)) * raio
		var p1 := c + (eixo_u * cos(a1) + eixo_v * sin(a1)) * raio
		ma.tri(mat, c, p0, p1, n)


static func construir(c: Castelinho) -> void:
	_museu(c)
	_veraneio_1975(c)


# ------------------------------------------------------------------ E2020
static func _museu(c: Castelinho) -> void:
	var g := c.g_museu
	var madeira: Material = c.m.madeira
	var tela_cores := [Color(0.85, 0.3, 0.45), Color(0.2, 0.7, 0.7), Color(0.95, 0.65, 0.2), Color(0.4, 0.3, 0.8), Color(0.9, 0.85, 0.3)]
	var claro: Material = Castelinho.mat_cor(Color(0.82, 0.62, 0.38), 0.9)
	# --- hall (galeria): cavaletes com telas encostados na parede norte
	for i in 3:
		_cavalete(c, g, Vector3(-9.6 - i * 1.8, 0, -13.4), N_S, tela_cores, i)
	# --- Salão de Arte (corpo principal, metade oeste do bloco norte): cavaletes junto à divisória
	for i in 3:
		_cavalete(c, g, Vector3(-11.3 + i * 1.6, 0, -17.7), N_N, tela_cores, 3 + i)
	# --- Acervo (metade leste): mesa escura com telefone, máquina de escrever e livros + baú
	cx(g, madeira, Vector3(-6.3, 0.4, -19.0), Vector3(1.2, 0.8, 0.6), true, 1.0)
	cx(g, Castelinho.mat_cor(Color(0.85, 0.3, 0.12), 0.5), Vector3(-6.0, 0.9, -19.0), Vector3(0.34, 0.18, 0.3))          # máquina de escrever laranja
	cx(g, Castelinho.mat_cor(Color(0.6, 0.1, 0.1), 0.7), Vector3(-6.95, 0.93, -19.1), Vector3(0.18, 0.26, 0.14))        # livros
		# vitrine de discos no canto
	cx(g, madeira, Vector3(-5.9, 0.5, -19.8), Vector3(0.6, 1.0, 0.4), true, 1.0)
	# --- Sala do Pescador: mural (parede sul, voltada ao norte), faixa de areia, corda amarela, conchas
	var zm := -14.24
	g.inte.quad_uv(c.m.mural, Vector3(-10.5, 0.55, zm), Vector3(-6.9, 0.55, zm), Vector3(-6.9, 2.45, zm), Vector3(-10.5, 2.45, zm), N_N,
		Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0))
	var areia: Material = Castelinho.mat_tri("areia", Vector3(2, 2, 2))
	g.inte.quad(areia, Vector3(-10.7, 0.03, -14.25), Vector3(-6.7, 0.03, -14.25), Vector3(-6.7, 0.03, -15.0), Vector3(-10.7, 0.03, -15.0), Vector3.UP)
	cx(g, c.m.corda, Vector3(-8.7, 0.06, -15.02), Vector3(4.0, 0.06, 0.08))
	for i in 7:
		var x := -10.3 + i * 0.6 + 0.1 * float(i % 2)
		cx(g, Castelinho.mat_cor(Color(0.85, 0.8, 0.7), 0.9), Vector3(x, 0.1, -14.55 - 0.1 * float(i % 3)), Vector3(0.2, 0.14, 0.16))
	cx(g, Castelinho.mat_cor(Color(0.35, 0.4, 0.35), 0.9), Vector3(-7.4, 0.12, -14.95), Vector3(0.5, 0.18, 0.34))          # tartaruga
	cx(g, Castelinho.mat_cor(Color(0.6, 0.62, 0.66), 0.9), Vector3(-9.6, 0.15, -14.75), Vector3(0.5, 0.26, 0.2))          # boto de pano
	# bancos baixos de madeira
	cx(g, madeira, Vector3(-7.9, 0.25, -16.3), Vector3(1.4, 0.5, 0.4), true, 1.0)
	# --- Povos Originários (anexo): vitrine longa de conchas/sambaqui
	cx(g, madeira, Vector3(-24.1, 0.45, -13.4), Vector3(2.0, 0.9, 0.7), true, 1.0)
	cx(g, c.m.vidro, Vector3(-24.1, 1.0, -13.4), Vector3(1.9, 0.2, 0.62))
	for i in 9:
		cx(g, Castelinho.mat_cor(Color(0.9, 0.86, 0.78), 0.9), Vector3(-24.9 + i * 0.2, 0.96, -13.4 + 0.12 * float((i % 3) - 1)), Vector3(0.12, 0.08, 0.12))
	cx(g, madeira, Vector3(-23.4, 0.3, -14.3), Vector3(1.2, 0.6, 0.4), true, 1.0)
	# --- Meio Ambiente (bloco do pátio): areia, osso de baleia, cartaz
	g.inte.quad(areia, Vector3(-24.0, 0.03, -16.8), Vector3(-21.4, 0.03, -16.8), Vector3(-21.4, 0.03, -15.1), Vector3(-24.0, 0.03, -15.1), Vector3.UP)
	cx(g, Castelinho.mat_cor(Color(0.88, 0.85, 0.78), 0.9), Vector3(-21.8, 0.2, -17.6), Vector3(1.0, 0.4, 0.4))          # vértebra de baleia
	cx(g, Castelinho.mat_cor(Color(0.88, 0.85, 0.78), 0.9), Vector3(-21.3, 0.55, -17.6), Vector3(0.5, 0.35, 0.3))
	cx(g, Castelinho.mat_cor(Color(0.9, 0.9, 0.92), 0.6), Vector3(-24.5, 1.6, -19.2), Vector3(0.04, 1.5, 0.8))            # banner de educação ambiental
	# --- corredor da Secretaria: portas com plaquinhas, mesa e planta
	for i in 5:
		var x := -22.0 + i * 2.6
		if absf(x + 22.8) < 1.0 or absf(x + 8.5) < 1.2:
			continue
		g.inte.quad(c.m.porta, Vector3(x - 0.45, 0.0, -20.89), Vector3(x + 0.45, 0.0, -20.89), Vector3(x + 0.45, 2.05, -20.89), Vector3(x - 0.45, 2.05, -20.89), N_N, Vector2(1, 1))
		cx(g, c.m.branco, Vector3(x, 1.7, -20.9), Vector3(0.3, 0.1, 0.02))
	cx(g, madeira, Vector3(-6.2, 0.4, -22.5), Vector3(1.2, 0.8, 0.6), true, 1.0)
	cx(g, c.m.verde_folha, Vector3(-5.8, 0.55, -21.3), Vector3(0.3, 1.1, 0.3))
	# --- Sala Medieval (ala dos fundos)
	_sala_medieval(c, g)


static func _cavalete(c: Castelinho, g: Castelinho.Grupo, p: Vector3, frente: Vector3, cores: Array, i: int) -> void:
	var madeira: Material = Castelinho.mat_cor(Color(0.78, 0.6, 0.38), 0.9)
	var s := frente
	var lado := Vector3(-s.z, 0, s.x)
	for k in [-1, 1]:
		cx(g, madeira, p + lado * 0.4 * k + Vector3(0, 0.55, 0), Vector3(0.05 if absf(s.z) > 0.5 else 0.05, 1.1, 0.05))
	var tela := p + Vector3(0, 1.25, 0) + s * 0.06
	var tam := Vector3(0.95, 1.15, 0.05) if absf(s.z) > 0.5 else Vector3(0.05, 1.15, 0.95)
	cx(g, Castelinho.mat_cor(Color(0.1, 0.07, 0.07), 0.8), tela, tam)
	# manchas de cor (retrato impressionista)
	for k in 5:
		var cor: Color = cores[(i + k) % cores.size()]
		var off := lado * (0.3 * float((k * 3) % 5 - 2) / 2.0) + Vector3(0, 0.25 * float((k * 2) % 5 - 2) / 2.0, 0)
		var t2 := Vector3(0.3, 0.3, 0.02) if absf(s.z) > 0.5 else Vector3(0.02, 0.3, 0.3)
		cx(g, Castelinho.mat_cor(cor, 0.8), tela + s * 0.03 + off, t2)


static func _sala_medieval(c: Castelinho, g: Castelinho.Grupo) -> void:
	var madeira: Material = c.m.madeira
	var ferro: Material = c.m.ferro
	var pe: Material = c.m.parede_int
	# lareira de blocos (parede norte, x=-14,2): corpo + capelo trapezoidal em degraus até o forro
	var zf := -29.1
	cx(g, pe, Vector3(-14.2, 0.25, zf + 0.35), Vector3(2.4, 0.5, 0.7), true)
	cx(g, pe, Vector3(-15.2, 1.0, zf + 0.35), Vector3(0.4, 1.0, 0.7))
	cx(g, pe, Vector3(-13.2, 1.0, zf + 0.35), Vector3(0.4, 1.0, 0.7))
	cx(g, pe, Vector3(-14.2, 1.65, zf + 0.35), Vector3(2.0, 0.3, 0.7))
	cx(g, pe, Vector3(-14.2, 2.1, zf + 0.3), Vector3(1.6, 0.6, 0.6))
	cx(g, pe, Vector3(-14.2, 2.75, zf + 0.25), Vector3(1.1, 0.7, 0.5))
	g.inte.col(Vector3(-15.4, 0, zf), Vector3(-13.0, 1.8, zf + 0.7))
	cx(g, c.m.escuro, Vector3(-14.2, 0.9, zf + 0.04), Vector3(1.2, 0.8, 0.04))               # boca da lareira
	cx(g, Castelinho.mat_luz(Color(1.0, 0.45, 0.1), 1.2), Vector3(-14.2, 0.2, zf + 0.25), Vector3(0.5, 0.22, 0.2))   # brasas
	# escudos redondos + machados/espadas cruzados
	for p in [Vector3(-14.2, 2.0, zf + 0.72), Vector3(-11.9, 2.0, zf + 0.06), Vector3(-9.0, 2.0, zf + 0.06)]:
		var n := N_S if p.z < -28.0 else N_L
		disco(g.inte, Castelinho.mat_cor(Color(0.55, 0.57, 0.6), 0.4), p, n, 0.4, 10)
		disco(g.inte, Castelinho.mat_cor(Color(0.3, 0.32, 0.36), 0.5), p + n * 0.01, n, 0.14, 8)
	# lanças e estandartes na parede oeste/leste
	for x in [-10.5, -10.0, -9.5]:
		cx(g, madeira, Vector3(x, 1.4, -23.65), Vector3(0.05, 2.5, 0.05))
		cx(g, c.m.ferro, Vector3(x, 2.75, -23.65), Vector3(0.07, 0.3, 0.07))
	# tronos (dois), encosto alto de madeira escura
	for z in [-27.0, -28.2]:
		cx(g, madeira, Vector3(-9.2, 0.35, z), Vector3(0.7, 0.7, 0.7), true, 1.0)
		cx(g, madeira, Vector3(-8.9, 1.2, z), Vector3(0.12, 1.4, 0.7), false, 1.0)
		cx(g, c.m.bordo, Vector3(-9.2, 0.75, z), Vector3(0.6, 0.1, 0.6))
	# mesa grande com cadeiras
	cx(g, madeira, Vector3(-13.2, 0.78, -26.0), Vector3(3.0, 0.1, 1.0), false, 1.0)
	g.inte.col(Vector3(-14.7, 0, -26.5), Vector3(-11.7, 0.9, -25.5))
	for dx in [-1.3, 1.3]:
		for dz in [-0.4, 0.4]:
			cx(g, madeira, Vector3(-13.2 + dx, 0.39, -26.0 + dz), Vector3(0.1, 0.78, 0.1))
	for i in 3:
		var x := -14.2 + i * 1.0
		for dz in [-0.95, 0.95]:
			cx(g, madeira, Vector3(x, 0.25, -26.0 + dz), Vector3(0.45, 0.5, 0.45), true, 1.0)
			cx(g, madeira, Vector3(x, 0.7, -26.0 + dz * 1.1), Vector3(0.45, 0.5, 0.06), false, 1.0)
	# tochas (arandelas) ao lado da porta de saída e da lareira
	for p in [Vector3(-11.4, 1.9, -29.05), Vector3(-9.0, 1.9, -29.05), Vector3(-16.4, 1.9, -24.5)]:
		cx(g, ferro, p, Vector3(0.1, 0.5, 0.1))
		cx(g, Castelinho.mat_luz(Color(1.0, 0.55, 0.15), 1.6), p + Vector3(0, 0.4, 0), Vector3(0.14, 0.24, 0.14))
		c.luzes.append({"pos": p + Vector3(0, 0.6, 0.3), "sala": "medieval_tocha"})
	# baú de ferro
	cx(g, madeira, Vector3(-9.7, 0.25, -24.3), Vector3(0.5, 0.5, 0.8), true, 1.0)


# ------------------------------------------------------------------ E1975: casa de veraneio
static func _veraneio_1975(c: Castelinho) -> void:
	var g := c.g_1975
	var madeira: Material = c.m.madeira
	var tecido := Castelinho.mat_cor(Color(0.78, 0.45, 0.2), 0.95)
	var tecido2 := Castelinho.mat_cor(Color(0.28, 0.5, 0.45), 0.95)
	var tapete := Castelinho.mat_cor(Color(0.7, 0.2, 0.18), 1.0)
	var palha := Castelinho.mat_cor(Color(0.8, 0.7, 0.45), 1.0)
	# Sala (antiga Sala Medieval): tapete, sofá, poltronas, mesa de centro, estante, rádio
	g.inte.quad(tapete, Vector3(-14.4, 0.02, -27.4), Vector3(-10.4, 0.02, -27.4), Vector3(-10.4, 0.02, -24.8), Vector3(-14.4, 0.02, -24.8), Vector3.UP)
	cx(g, tecido, Vector3(-12.4, 0.35, -28.6), Vector3(2.2, 0.7, 0.9), true)
	cx(g, tecido, Vector3(-12.4, 0.75, -28.95), Vector3(2.2, 0.5, 0.2))
	cx(g, tecido2, Vector3(-15.5, 0.3, -26.3), Vector3(0.8, 0.6, 0.8), true)
	cx(g, tecido2, Vector3(-9.7, 0.3, -26.3), Vector3(0.8, 0.6, 0.8), true)
	cx(g, madeira, Vector3(-12.4, 0.2, -26.1), Vector3(1.1, 0.4, 0.6), true, 1.0)
	cx(g, madeira, Vector3(-16.2, 1.0, -24.5), Vector3(0.45, 2.0, 1.2), true, 1.0)
	cx(g, Castelinho.mat_cor(Color(0.55, 0.35, 0.2), 0.7), Vector3(-16.2, 0.6, -24.5), Vector3(0.3, 0.3, 0.7))
	cx(g, palha, Vector3(-10.0, 0.5, -24.2), Vector3(0.5, 1.0, 0.5))         # cadeira de palha
	# bilhete de praia: guarda-sol dobrado, boia, prancha encostada
	cx(g, Castelinho.mat_cor(Color(0.9, 0.3, 0.3), 0.9), Vector3(-9.0, 0.5, -28.7), Vector3(0.5, 1.0, 0.1))
	cx(g, Castelinho.mat_cor(Color(0.95, 0.85, 0.3), 0.9), Vector3(-9.4, 0.35, -28.7), Vector3(0.5, 0.7, 0.1))
	# corredor/hall: banco e cabideiro
	cx(g, madeira, Vector3(-9.0, 0.25, -13.4), Vector3(1.4, 0.5, 0.4), true, 1.0)
	cx(g, madeira, Vector3(-14.8, 0.9, -13.4), Vector3(0.4, 1.8, 0.1))
	# Sala do Pescador em 1975: redes de pesca e caixas
	cx(g, palha, Vector3(-8.7, 0.3, -15.9), Vector3(1.2, 0.6, 0.8), true)
	cx(g, Castelinho.mat_cor(Color(0.45, 0.55, 0.4), 0.9), Vector3(-10.0, 0.25, -16.6), Vector3(0.9, 0.5, 0.6), true)


# ------------------------------------------------------------------ nós avulsos
## Pinguim empalhado: corpo, barriga, cabeça e dois olhos que o nível faz seguir o jogador.
static func criar_pinguim() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Pinguim"
	var m := Malha.new()
	var preto := Castelinho.mat_cor(Color(0.07, 0.07, 0.09), 0.8)
	var branco := Castelinho.mat_cor(Color(0.93, 0.93, 0.92), 0.8)
	var bico := Castelinho.mat_cor(Color(0.9, 0.55, 0.15), 0.8)
	m.caixa(preto, Vector3(-0.17, 0.0, -0.13), Vector3(0.17, 0.62, 0.13), Malha.F_TODAS)
	m.caixa(branco, Vector3(-0.13, 0.05, 0.12), Vector3(0.13, 0.55, 0.15), Malha.F_TODAS)
	m.caixa(preto, Vector3(-0.12, 0.62, -0.11), Vector3(0.12, 0.84, 0.11), Malha.F_TODAS)
	m.caixa(branco, Vector3(-0.1, 0.64, 0.1), Vector3(0.1, 0.78, 0.12), Malha.F_TODAS)
	m.caixa(bico, Vector3(-0.025, 0.7, 0.11), Vector3(0.025, 0.74, 0.25), Malha.F_TODAS)
	m.caixa(preto, Vector3(-0.27, 0.3, -0.05), Vector3(-0.17, 0.58, 0.05), Malha.F_TODAS)
	m.caixa(preto, Vector3(0.17, 0.3, -0.05), Vector3(0.27, 0.58, 0.05), Malha.F_TODAS)
	m.construir_instancia(raiz, "Corpo", 1)
	for lado in [-1, 1]:
		var olho := Node3D.new()
		olho.name = "Olho_E" if lado == -1 else "Olho_D"
		olho.position = Vector3(0.055 * lado, 0.77, 0.115)
		raiz.add_child(olho)
		var mm := Malha.new()
		mm.caixa(Castelinho.mat_cor(Color(1, 1, 1), 0.3), Vector3(-0.022, -0.022, 0), Vector3(0.022, 0.022, 0.012), Malha.F_TODAS)
		mm.caixa(Castelinho.mat_cor(Color(0, 0, 0), 0.2), Vector3(-0.011, -0.011, 0.01), Vector3(0.011, 0.011, 0.02), Malha.F_TODAS)
		mm.construir_instancia(olho, "Malha", 1)
	return raiz


## Armadura de ferro (cavaleiro) com elmo, peitoral, braços e pernas.
static func criar_armadura() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Armadura"
	var m := Malha.new()
	var aco := Castelinho.mat_cor(Color(0.52, 0.55, 0.6), 0.35)
	var escuro := Castelinho.mat_cor(Color(0.2, 0.22, 0.26), 0.5)
	m.caixa(aco, Vector3(-0.14, 0.0, -0.12), Vector3(0.14, 0.82, 0.12), Malha.F_TODAS)         # pernas
	m.caixa(escuro, Vector3(-0.02, 0.0, -0.12), Vector3(0.02, 0.82, 0.12), Malha.F_TODAS)
	m.caixa(aco, Vector3(-0.22, 0.82, -0.14), Vector3(0.22, 1.35, 0.14), Malha.F_TODAS)       # peitoral
	m.caixa(aco, Vector3(-0.35, 1.05, -0.08), Vector3(-0.22, 1.35, 0.08), Malha.F_TODAS)      # braços
	m.caixa(aco, Vector3(0.22, 1.05, -0.08), Vector3(0.35, 1.35, 0.08), Malha.F_TODAS)
	m.caixa(aco, Vector3(-0.13, 1.35, -0.13), Vector3(0.13, 1.62, 0.13), Malha.F_TODAS)       # elmo
	m.caixa(escuro, Vector3(-0.1, 1.45, 0.12), Vector3(0.1, 1.5, 0.14), Malha.F_TODAS)        # viseira
	m.caixa(aco, Vector3(-0.03, 1.62, -0.1), Vector3(0.03, 1.74, 0.1), Malha.F_TODAS)         # crista
	m.caixa(escuro, Vector3(0.36, 0.5, -0.02), Vector3(0.4, 1.7, 0.02), Malha.F_TODAS)        # lança
	m.construir_instancia(raiz, "Corpo", 1)
	return raiz


## Telefone antigo de disco (preto) para ser interagível.
static func criar_telefone() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Telefone"
	var m := Malha.new()
	var preto := Castelinho.mat_cor(Color(0.06, 0.06, 0.07), 0.35)
	m.caixa(preto, Vector3(-0.11, 0.0, -0.1), Vector3(0.11, 0.1, 0.1), Malha.F_TODAS)
	m.caixa(preto, Vector3(-0.15, 0.1, -0.03), Vector3(0.15, 0.14, 0.03), Malha.F_TODAS)
	m.caixa(Castelinho.mat_cor(Color(0.8, 0.7, 0.4), 0.4), Vector3(-0.04, 0.1, 0.0), Vector3(0.04, 0.105, 0.07), Malha.F_TODAS)
	m.construir_instancia(raiz, "Corpo", 1)
	return raiz


## Recortes de papelão desenhados em código (Image). tipo: "visitante", "pescador", "quico".
## Estilo: silhueta chapada com contorno de papelão. 64 x 128 px, filtro nearest.
static func textura_recorte(tipo: String, verso := false) -> ImageTexture:
	var w := 64
	var h := 128
	var papelao := Color(0.72, 0.56, 0.36)
	var fig := Image.create(w, h, false, Image.FORMAT_RGBA8)
	fig.fill(Color(0, 0, 0, 0))
	var formas: Array = []      # [tipo, rect/centro, cor]
	match tipo:
		"visitante":
			formas = [
				["c", Vector2i(32, 20), 15, Color(0.95, 0.78, 0.62)],       # cabeça
				["r", Rect2i(14, 36, 36, 44), Color(0.2, 0.5, 0.85)],        # camisa
				["r", Rect2i(8, 38, 8, 34), Color(0.2, 0.5, 0.85)],          # braços
				["r", Rect2i(48, 38, 8, 34), Color(0.2, 0.5, 0.85)],
				["r", Rect2i(18, 80, 12, 44), Color(0.2, 0.2, 0.3)],         # pernas
				["r", Rect2i(34, 80, 12, 44), Color(0.2, 0.2, 0.3)],
				["r", Rect2i(18, 4, 28, 8), Color(0.35, 0.2, 0.1)],           # cabelo
			]
		"pescador":
			formas = [
				["c", Vector2i(32, 24), 13, Color(0.9, 0.7, 0.55)],
				["r", Rect2i(10, 14, 44, 6), Color(0.45, 0.3, 0.12)],         # chapéu (aba)
				["r", Rect2i(20, 4, 24, 12), Color(0.45, 0.3, 0.12)],
				["r", Rect2i(12, 40, 40, 48), Color(0.95, 0.7, 0.15)],        # capa amarela
				["r", Rect2i(6, 42, 8, 32), Color(0.95, 0.7, 0.15)],
				["r", Rect2i(50, 42, 8, 32), Color(0.95, 0.7, 0.15)],
				["r", Rect2i(16, 88, 14, 36), Color(0.15, 0.2, 0.15)],        # botas
				["r", Rect2i(34, 88, 14, 36), Color(0.15, 0.2, 0.15)],
			]
		"quico":
			formas = [
				["c", Vector2i(32, 70), 26, Color(0.78, 0.78, 0.76)],         # corpo de quero-quero
				["c", Vector2i(32, 36), 16, Color(0.9, 0.9, 0.88)],           # cabeça
				["r", Rect2i(30, 8, 4, 16), Color(0.1, 0.1, 0.1)],            # penacho
				["r", Rect2i(32, 38, 16, 5), Color(0.95, 0.55, 0.1)],         # bico
				["r", Rect2i(24, 96, 4, 30), Color(0.9, 0.5, 0.1)],           # pernas
				["r", Rect2i(38, 96, 4, 30), Color(0.9, 0.5, 0.1)],
			]
	# contorno de papelão: desenha cada forma ampliada em 3 px, depois as formas com as cores
	for f in formas:
		_desenhar_forma(fig, f, 3, papelao)
	for f in formas:
		_desenhar_forma(fig, f, 0, Color(0, 0, 0, 0))
	# rostos
	match tipo:
		"visitante":
			fig.fill_rect(Rect2i(26, 17, 3, 3), Color.BLACK)
			fig.fill_rect(Rect2i(35, 17, 3, 3), Color.BLACK)
			fig.fill_rect(Rect2i(26, 25, 12, 2), Color.BLACK)         # sorriso
			fig.fill_rect(Rect2i(24, 23, 2, 2), Color.BLACK)
			fig.fill_rect(Rect2i(38, 23, 2, 2), Color.BLACK)
		"pescador":
			fig.fill_rect(Rect2i(26, 22, 3, 3), Color.BLACK)
			fig.fill_rect(Rect2i(35, 22, 3, 3), Color.BLACK)
			fig.fill_rect(Rect2i(28, 30, 8, 2), Color(0.5, 0.2, 0.2))
		"quico":
			fig.fill_rect(Rect2i(26, 32, 4, 4), Color.BLACK)
			fig.fill_rect(Rect2i(36, 32, 4, 4), Color.BLACK)
			fig.fill_rect(Rect2i(20, 56, 24, 4), Color(0.1, 0.1, 0.1))   # peito preto
	if verso:
		# verso do papelão: a mesma silhueta em papelão cru, sem desenho
		for y in h:
			for x in w:
				if fig.get_pixel(x, y).a > 0.5:
					var ruido := 0.04 * float((x * 7 + y * 13) % 5) / 4.0
					fig.set_pixel(x, y, Color(0.62 - ruido, 0.47 - ruido, 0.3 - ruido))
	return ImageTexture.create_from_image(fig)


static func _desenhar_forma(img: Image, f: Array, expandir: int, cor_forca: Color) -> void:
	var cor: Color = cor_forca if expandir > 0 else f[f.size() - 1]
	if f[0] == "r":
		var r: Rect2i = f[1]
		img.fill_rect(Rect2i(r.position.x - expandir, r.position.y - expandir, r.size.x + expandir * 2, r.size.y + expandir * 2).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), cor)
	else:
		var c: Vector2i = f[1]
		var raio: int = f[2] + expandir
		for y in range(maxi(0, c.y - raio), mini(img.get_height(), c.y + raio + 1)):
			for x in range(maxi(0, c.x - raio), mini(img.get_width(), c.x + raio + 1)):
				if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= raio * raio:
					img.set_pixel(x, y, cor)
