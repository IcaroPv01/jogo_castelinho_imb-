class_name MobiliaCastelinho
extends RefCounted
## Mobília e acervo do Castelinho, combinados na malha por época:
##  - E2020 (museu): cavaletes com telas, vitrines, mesas de acervo, tronos, lareira, escudos, tochas, mural do pescador
##  - E1975 (casa de veraneio): sofá, poltronas, tapete, mesa, estante, abajur, TV, quadro (mesmo cômodo da Sala Medieval)
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


## Escudo redondo de madeira com aro e umbo de ferro (parede da Sala Medieval).
static func _escudo_redondo(g: Castelinho.Grupo, c: Vector3, n: Vector3, r: float) -> void:
	var _et := Malha.abrir("escudo_redondo_%d_%d" % [roundi(c.x * 10.0), roundi(c.y * 10.0)])
	disco(g.inte, Castelinho.mat_cor(Color(0.26, 0.27, 0.3), 0.5), c, n, r * 1.12, 12)
	disco(g.inte, Castelinho.mat_cor(Color(0.46, 0.3, 0.18), 0.9), c + n * 0.01, n, r, 12)
	disco(g.inte, Castelinho.mat_cor(Color(0.6, 0.6, 0.62), 0.4), c + n * 0.02, n, r * 0.28, 8)
	# tábuas (faixas verticais escuras)
	var u := Vector3.UP.cross(n).normalized()
	for k: float in [-0.5, 0.0, 0.5]:
		var a: Vector3 = c + n * 0.015 + u * (k * r - 0.008)
		var b: Vector3 = c + n * 0.015 + u * (k * r + 0.008)
		var hh := sqrt(maxf(r * r - k * r * k * r, 0.0)) * 0.95
		g.inte.quad(Castelinho.mat_cor(Color(0.3, 0.19, 0.12), 0.9), a - Vector3(0, hh, 0), b - Vector3(0, hh, 0), b + Vector3(0, hh, 0), a + Vector3(0, hh, 0), n)
	Malha.fechar(_et)


## Haste fina no plano da parede, de `a` a `b` (cabos, lâminas).
static func _haste(ma: Malha, mat: Material, a: Vector3, b: Vector3, n: Vector3, larg: float) -> void:
	var d := (b - a).normalized()
	var lado := d.cross(n).normalized() * larg * 0.5
	ma.quad(mat, a - lado, b - lado, b + lado, a + lado, n)


## Dois machados cruzados atrás de um escudo.
static func _machados(g: Castelinho.Grupo, c: Vector3, n: Vector3, L: float) -> void:
	var _et := Malha.abrir("machados_cruzados_%d" % roundi(c.x * 10.0))
	var u := Vector3.UP.cross(n).normalized()
	var cabo := Castelinho.mat_cor(Color(0.32, 0.2, 0.12), 0.9)
	var ferro := Castelinho.mat_cor(Color(0.55, 0.56, 0.6), 0.4)
	for sx in [-1.0, 1.0]:
		var a: Vector3 = c + (-u * sx - Vector3.UP).normalized() * L * 0.75
		var b: Vector3 = c + (u * sx + Vector3.UP).normalized() * L
		_haste(g.inte, cabo, a, b, n, 0.05)
		# lâmina em leque na ponta de cima
		var lado: Vector3 = u * sx
		g.inte.tri(ferro, b - Vector3(0, 0.12, 0) + n * 0.005, b + lado * 0.22 + Vector3(0, 0.12, 0) + n * 0.005,
			b + lado * 0.22 - Vector3(0, 0.22, 0) + n * 0.005, n)
	Malha.fechar(_et)


## Duas espadas cruzadas (lâminas claras, guardas escuras).
static func _espadas(g: Castelinho.Grupo, c: Vector3, n: Vector3, L: float) -> void:
	var _et := Malha.abrir("espadas_cruzadas_%d" % roundi(c.x * 10.0))
	var u := Vector3.UP.cross(n).normalized()
	var lamina := Castelinho.mat_cor(Color(0.75, 0.76, 0.8), 0.3)
	var guarda := Castelinho.mat_cor(Color(0.35, 0.25, 0.12), 0.6)
	for sx in [-1.0, 1.0]:
		var dirv: Vector3 = (u * sx + Vector3.UP).normalized()
		var a: Vector3 = c - dirv * L * 0.55
		var b: Vector3 = c + dirv * L * 0.6
		_haste(g.inte, lamina, a, b, n, 0.045)
		var gc: Vector3 = a + dirv * 0.16
		_haste(g.inte, guarda, gc - dirv.cross(n) * 0.12, gc + dirv.cross(n) * 0.12, n, 0.04)
	Malha.fechar(_et)


## Brasão (escudo heráldico de ponta) verde-petróleo com borda dourada e uma águia escura estilizada.
static func _brasao(g: Castelinho.Grupo, c: Vector3, n: Vector3, w: float, h: float) -> void:
	var _et := Malha.abrir("brasao_aguia")
	var u := Vector3.UP.cross(n).normalized()
	var p := func(x: float, y: float, z := 0.0) -> Vector3:
		return c + u * x + Vector3(0, y, 0) + n * z
	var borda := Castelinho.mat_cor(Color(0.72, 0.6, 0.3), 0.5)
	var campo := Castelinho.mat_cor(Color(0.2, 0.38, 0.4), 0.8)
	var aguia := Castelinho.mat_cor(Color(0.08, 0.07, 0.07), 0.8)
	for camada in [[borda, 1.0, 0.0], [campo, 0.86, 0.01]]:
		var k: float = camada[1]
		var z: float = camada[2]
		var hw := w * 0.5 * k
		var top := h * 0.5 * k
		var meio := -h * 0.1 * k
		var pon := -h * 0.5 * k
		g.inte.quad(camada[0], p.call(-hw, top, z), p.call(hw, top, z), p.call(hw, meio, z), p.call(-hw, meio, z), n)
		g.inte.tri(camada[0], p.call(-hw, meio, z), p.call(hw, meio, z), p.call(0.0, pon, z), n)
	# águia: corpo, asas abertas e cabeça
	g.inte.quad(aguia, p.call(-0.05, 0.18, 0.02), p.call(0.05, 0.18, 0.02), p.call(0.07, -0.2, 0.02), p.call(-0.07, -0.2, 0.02), n)
	for sx in [-1.0, 1.0]:
		g.inte.tri(aguia, p.call(0.04 * sx, 0.1, 0.02), p.call(0.24 * sx, 0.24, 0.02), p.call(0.2 * sx, -0.06, 0.02), n)
		g.inte.tri(aguia, p.call(0.02 * sx, -0.18, 0.02), p.call(0.12 * sx, -0.3, 0.02), p.call(0.0, -0.24, 0.02), n)
	g.inte.tri(aguia, p.call(-0.05, 0.18, 0.02), p.call(0.05, 0.18, 0.02), p.call(0.0, 0.27, 0.02), n)
	Malha.fechar(_et)


# ------------------------------------------------------------------ E2020
static func _museu(c: Castelinho) -> void:
	var g := c.g_museu
	var madeira: Material = c.m.madeira
	var tela_cores := [Color(0.85, 0.3, 0.45), Color(0.2, 0.7, 0.7), Color(0.95, 0.65, 0.2), Color(0.4, 0.3, 0.8), Color(0.9, 0.85, 0.3)]
	var claro: Material = Castelinho.mat_cor(Color(0.82, 0.62, 0.38), 0.9)
	var _et := Malha.abrir("")
	# --- hall (galeria): cavaletes com telas encostados na parede norte
	for i in 3:
		# (revisão V2: 0,5 m para o leste; o terceiro cobria metade da porta zebrada do porão, em x = -14, na visita 4)
		_cavalete(c, g, Vector3(-9.1 - i * 1.75, 0, -13.4), N_S, tela_cores, i)
	# --- Salão de Arte (corpo principal, metade oeste do bloco norte): cavaletes junto à divisória
	for i in 3:
		_cavalete(c, g, Vector3(-11.3 + i * 1.6, 0, -17.7), N_N, tela_cores, 3 + i)
	# --- Acervo (metade leste): mesa escura com telefone, máquina de escrever e livros + baú
	Malha.abrir("mesa_acervo")
	cx(g, madeira, Vector3(-6.3, 0.4, -19.0), Vector3(1.2, 0.8, 0.6), true, 1.0)
	Malha.abrir("maquina_escrever_acervo")
	cx(g, Castelinho.mat_cor(Color(0.85, 0.3, 0.12), 0.5), Vector3(-6.0, 0.9, -19.0), Vector3(0.34, 0.18, 0.3))          # máquina de escrever laranja
	Malha.abrir("livros_acervo")
	cx(g, Castelinho.mat_cor(Color(0.6, 0.1, 0.1), 0.7), Vector3(-6.95, 0.93, -19.1), Vector3(0.18, 0.26, 0.14))        # livros
		# vitrine de discos no canto
	Malha.abrir("vitrine_discos_acervo")
	cx(g, madeira, Vector3(-5.9, 0.5, -19.8), Vector3(0.6, 1.0, 0.4), true, 1.0)
	# --- Sala do Pescador: mural (parede sul, voltada ao norte), faixa de areia, corda amarela, conchas
	var zm := -14.24
	Malha.abrir("mural_pescador")
	g.inte.quad_uv(c.m.mural, Vector3(-10.5, 0.55, zm), Vector3(-6.9, 0.55, zm), Vector3(-6.9, 2.45, zm), Vector3(-10.5, 2.45, zm), N_N,
		Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0))
	var areia: Material = Castelinho.mat_tri("areia", Vector3(2, 2, 2))
	Malha.abrir("faixa_areia_pescador")
	g.inte.quad(areia, Vector3(-10.7, 0.03, -14.25), Vector3(-6.7, 0.03, -14.25), Vector3(-6.7, 0.03, -15.0), Vector3(-10.7, 0.03, -15.0), Vector3.UP)
	Malha.abrir("corda_amarela_pescador")
	cx(g, c.m.corda, Vector3(-8.7, 0.06, -15.02), Vector3(4.0, 0.06, 0.08))
	# conchas, tartaruga e boto de pano (artesanato da foto da sala): formas arredondadas, não caixas
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 13
	var branco_osso := Castelinho.mat_cor(Color.WHITE, 0.9)
	var cores_concha := [Color(0.92, 0.86, 0.76), Color(0.95, 0.78, 0.66), Color(0.86, 0.82, 0.8), Color(0.9, 0.7, 0.55)]
	for i in 7:
		Malha.abrir("concha_pescador_%d" % (i + 1))
		var x := -10.3 + i * 0.6 + 0.1 * float(i % 2)
		var cc: Color = cores_concha[i % cores_concha.size()]
		g.inte.bolha(branco_osso, Vector3(x, 0.08, -14.55 - 0.1 * float(i % 3)), Vector3(0.13, 0.07, 0.11), rnd, 6, 2, 0.15, cc, cc * Color(0.7, 0.68, 0.66))
	var casco := Castelinho.mat_cor(Color.WHITE, 0.9)
	Malha.abrir("tartaruga_pescador")
	g.inte.bolha(casco, Vector3(-7.4, 0.11, -14.95), Vector3(0.3, 0.1, 0.22), rnd, 7, 2, 0.1, Color(0.5, 0.4, 0.26), Color(0.26, 0.2, 0.14))
	g.inte.bolha(casco, Vector3(-7.05, 0.09, -14.95), Vector3(0.09, 0.06, 0.07), rnd, 5, 2, 0.1, Color(0.55, 0.5, 0.36), Color(0.3, 0.26, 0.18))
	Malha.abrir("boto_de_pano_pescador")
	g.inte.bolha(casco, Vector3(-9.6, 0.16, -14.75), Vector3(0.32, 0.11, 0.1), rnd, 7, 2, 0.08, Color(0.72, 0.74, 0.78), Color(0.45, 0.47, 0.52))
	g.inte.tri(casco, Vector3(-9.62, 0.24, -14.75), Vector3(-9.5, 0.24, -14.75), Vector3(-9.6, 0.36, -14.75), N_S, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color(0.6, 0.62, 0.66))
	# bancos baixos de madeira
	Malha.abrir("banco_baixo_pescador")
	cx(g, madeira, Vector3(-7.9, 0.25, -16.3), Vector3(1.4, 0.5, 0.4), true, 1.0)
	# --- Povos Originários (anexo): vitrine longa de conchas/sambaqui
	Malha.abrir("vitrine_povos_base")
	cx(g, madeira, Vector3(-24.1, 0.45, -13.4), Vector3(2.0, 0.9, 0.7), true, 1.0)
	Malha.abrir("vitrine_povos_vidro")
	cx(g, c.m.vidro, Vector3(-24.1, 1.0, -13.4), Vector3(1.9, 0.2, 0.62))
	for i in 9:
		Malha.abrir("sambaqui_concha_%d" % (i + 1))
		cx(g, Castelinho.mat_cor(Color(0.9, 0.86, 0.78), 0.9), Vector3(-24.9 + i * 0.2, 0.96, -13.4 + 0.12 * float((i % 3) - 1)), Vector3(0.12, 0.08, 0.12))
	Malha.abrir("banco_povos")
	cx(g, madeira, Vector3(-23.4, 0.3, -14.3), Vector3(1.2, 0.6, 0.4), true, 1.0)
	# --- Meio Ambiente (bloco do pátio): areia, osso de baleia, cartaz
	Malha.abrir("faixa_areia_meio_ambiente")
	g.inte.quad(areia, Vector3(-24.0, 0.03, -16.8), Vector3(-21.4, 0.03, -16.8), Vector3(-21.4, 0.03, -15.1), Vector3(-24.0, 0.03, -15.1), Vector3.UP)
	# vértebra de baleia (foto do Meio Ambiente): corpo, apófises laterais e espinho dorsal, cor de osso
	var osso_c := Color(0.9, 0.86, 0.78)
	var osso_s := Color(0.55, 0.5, 0.44)
	var rv := RandomNumberGenerator.new()
	rv.seed = 9
	var osso := Castelinho.mat_cor(Color.WHITE, 0.9)
	# centro em forma de tambor deitado (disco), asas laterais compridas e achatadas, espinho baixo e largo
	Malha.abrir("vertebra_baleia")
	g.inte.bolha(osso, Vector3(-21.8, 0.2, -17.6), Vector3(0.24, 0.2, 0.16), rv, 8, 3, 0.08, osso_c, osso_s)
	for sx in [-1.0, 1.0]:
		g.inte.bolha(osso, Vector3(-21.8 + 0.4 * sx, 0.24, -17.6), Vector3(0.24, 0.045, 0.1), rv, 6, 2, 0.1, osso_c, osso_s)
	g.inte.bolha(osso, Vector3(-21.8, 0.44, -17.66), Vector3(0.12, 0.12, 0.07), rv, 6, 2, 0.1, osso_c, osso_s)
	# banner enrolável de educação ambiental (genérico: ondas, folha e faixas de texto, sem marcas reais)
	var banner := Castelinho.mat_uv("banner_ambiental", Color.WHITE, 0.8)
	var bz0 := -19.6
	var bz1 := -18.8
	Malha.abrir("banner_ambiental")
	g.inte.quad_uv(banner, Vector3(-24.56, 0.75, bz1), Vector3(-24.56, 0.75, bz0), Vector3(-24.56, 2.4, bz0), Vector3(-24.56, 2.4, bz1), N_L,
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	cx(g, c.m.ferro, Vector3(-24.53, 0.72, (bz0 + bz1) * 0.5), Vector3(0.08, 0.06, 0.86))
	cx(g, c.m.ferro, Vector3(-24.53, 2.42, (bz0 + bz1) * 0.5), Vector3(0.05, 0.04, 0.84))
	# --- corredor da Secretaria: portas com plaquinhas, mesa e planta
	for i in 5:
		var x := -22.0 + i * 2.6
		if absf(x + 22.8) < 1.0 or absf(x + 8.5) < 1.2:
			continue
		Malha.abrir("porta_secretaria_%d" % (i + 1))
		g.inte.quad(c.m.porta, Vector3(x - 0.45, 0.0, -20.89), Vector3(x + 0.45, 0.0, -20.89), Vector3(x + 0.45, 2.05, -20.89), Vector3(x - 0.45, 2.05, -20.89), N_N, Vector2(1, 1))
		cx(g, c.m.branco, Vector3(x, 1.7, -20.9), Vector3(0.3, 0.1, 0.02))
	Malha.abrir("mesa_corredor")
	cx(g, madeira, Vector3(-6.2, 0.4, -22.5), Vector3(1.2, 0.8, 0.6), true, 1.0)
	# planta no vaso (corredor)
	Malha.abrir("vaso_planta_corredor")
	cx(g, Castelinho.mat_cor(Color(0.6, 0.32, 0.22), 0.9), Vector3(-5.8, 0.2, -21.3), Vector3(0.36, 0.4, 0.36))
	Malha.abrir("folhagem_planta_corredor")
	var rp := RandomNumberGenerator.new()
	rp.seed = 21
	var folha_vaso := Castelinho.mat_tri("folhagem", Vector3(0.8, 0.8, 0.8), Color(0.8, 1.0, 0.72))
	for k in 4:
		g.inte.bolha(folha_vaso, Vector3(-5.8 + rp.randf_range(-0.15, 0.15), 0.62 + k * 0.2, -21.3 + rp.randf_range(-0.15, 0.15)),
			Vector3(0.3, 0.2, 0.3) * (1.0 - k * 0.15), rp, 6, 2, 0.2, Color(1, 1, 1), Color(0.45, 0.5, 0.45))
	# --- Sala Medieval (ala dos fundos)
	Malha.fechar(_et)
	_sala_medieval(c, g)


static func _cavalete(c: Castelinho, g: Castelinho.Grupo, p: Vector3, frente: Vector3, cores: Array, i: int) -> void:
	var _et := Malha.abrir("cavalete_%d" % (i + 1))
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
	Malha.fechar(_et)


static func _sala_medieval(c: Castelinho, g: Castelinho.Grupo) -> void:
	var madeira: Material = c.m.madeira
	var ferro: Material = c.m.ferro
	var pe: Material = c.m.parede_int
	# lareira (parede norte, x=-14,2), como na foto da sala (ci_2025): lareira de blocos com boca escura e brasas, e
	# capelo trapezoidal CLARO subindo até o forro (o tom diferente da parede é o que faz a peça "ler")
	var zf := -29.1
	var capelo: Material = Castelinho.mat_tri("reboco", Vector3(1.2, 1.2, 1.2), Color(0.93, 0.86, 0.78))
	var _et := Malha.abrir("lareira_medieval")
	cx(g, pe, Vector3(-14.2, 0.25, zf + 0.35), Vector3(2.4, 0.5, 0.7), true)
	cx(g, pe, Vector3(-15.2, 1.0, zf + 0.35), Vector3(0.4, 1.0, 0.7))
	cx(g, pe, Vector3(-13.2, 1.0, zf + 0.35), Vector3(0.4, 1.0, 0.7))
	cx(g, madeira, Vector3(-14.2, 1.58, zf + 0.4), Vector3(2.5, 0.16, 0.8), false, 1.0)     # consolo de madeira
	g.inte.col(Vector3(-15.4, 0, zf), Vector3(-13.0, 1.8, zf + 0.7))
	cx(g, c.m.escuro, Vector3(-14.2, 0.9, zf + 0.04), Vector3(1.2, 0.8, 0.04))               # boca da lareira
	cx(g, Castelinho.mat_luz(Color(1.0, 0.45, 0.1), 1.2), Vector3(-14.2, 0.2, zf + 0.25), Vector3(0.5, 0.22, 0.2))   # brasas
	var yb := 1.66
	var yt := 3.4
	var fz := zf + 0.62
	var b0 := Vector3(-15.25, yb, fz)
	var b1 := Vector3(-13.15, yb, fz)
	var t1 := Vector3(-13.7, yt, fz - 0.12)
	var t0 := Vector3(-14.7, yt, fz - 0.12)
	g.inte.quad_auto(capelo, b0, b1, t1, t0, N_S)
	g.inte.quad_auto(capelo, b0, t0, Vector3(t0.x, yt, zf), Vector3(b0.x, yb, zf), N_O)
	g.inte.quad_auto(capelo, b1, t1, Vector3(t1.x, yt, zf), Vector3(b1.x, yb, zf), N_L)
	g.inte.quad_auto(capelo, b0, b1, Vector3(b1.x, yb, zf), Vector3(b0.x, yb, zf), Vector3.DOWN)
	# escudo redondo com machados cruzados no capelo; brasão (águia) e outro escudo na parede norte
	Malha.abrir("")
	_machados(g, Vector3(-14.2, 2.45, fz - 0.06), N_S, 0.75)
	_escudo_redondo(g, Vector3(-14.2, 2.45, fz - 0.05), N_S, 0.36)
	_brasao(g, Vector3(-11.9, 2.05, zf + 0.04), N_S, 0.62, 0.78)
	_espadas(g, Vector3(-9.0, 2.05, zf + 0.05), N_S, 0.7)
	_escudo_redondo(g, Vector3(-9.0, 2.05, zf + 0.06), N_S, 0.3)
	# lanças e estandartes na parede oeste/leste
	for x in [-10.5, -10.0, -9.5]:
		Malha.abrir("lanca_medieval_%d" % roundi((x + 10.5) * 2.0 + 1.0))
		cx(g, madeira, Vector3(x, 1.4, -23.65), Vector3(0.05, 2.5, 0.05))
		cx(g, c.m.ferro, Vector3(x, 2.75, -23.65), Vector3(0.07, 0.3, 0.07))
	# tronos (dois), encosto alto de madeira escura
	for z in [-27.0, -28.2]:
		Malha.abrir("trono_medieval_%d" % (1 if z > -27.5 else 2))
		cx(g, madeira, Vector3(-9.2, 0.35, z), Vector3(0.7, 0.7, 0.7), true, 1.0)
		cx(g, madeira, Vector3(-8.9, 1.2, z), Vector3(0.12, 1.4, 0.7), false, 1.0)
		cx(g, c.m.bordo, Vector3(-9.2, 0.75, z), Vector3(0.6, 0.1, 0.6))
	# mesa grande com cadeiras
	Malha.abrir("mesa_grande_medieval")
	cx(g, madeira, Vector3(-13.2, 0.78, -26.0), Vector3(3.0, 0.1, 1.0), false, 1.0)
	g.inte.col(Vector3(-14.7, 0, -26.5), Vector3(-11.7, 0.9, -25.5))
	for dx in [-1.3, 1.3]:
		for dz in [-0.4, 0.4]:
			cx(g, madeira, Vector3(-13.2 + dx, 0.39, -26.0 + dz), Vector3(0.1, 0.78, 0.1))
	for i in 3:
		var x := -14.2 + i * 1.0
		for dz in [-0.95, 0.95]:
			Malha.abrir("cadeira_medieval_%d_%s" % [i + 1, "n" if dz < 0 else "s"])
			cx(g, madeira, Vector3(x, 0.25, -26.0 + dz), Vector3(0.45, 0.5, 0.45), true, 1.0)
			cx(g, madeira, Vector3(x, 0.7, -26.0 + dz * 1.1), Vector3(0.45, 0.5, 0.06), false, 1.0)
	# tochas (arandelas) ao lado da porta de saída e da lareira
	for p in [Vector3(-11.4, 1.9, -29.05), Vector3(-9.0, 1.9, -29.05), Vector3(-16.4, 1.9, -24.5)]:
		Malha.abrir("tocha_medieval_%d" % roundi(absf(p.x)))
		cx(g, ferro, p, Vector3(0.1, 0.5, 0.1))
		cx(g, Castelinho.mat_luz(Color(1.0, 0.55, 0.15), 1.6), p + Vector3(0, 0.4, 0), Vector3(0.14, 0.24, 0.14))
		c.luzes.append({"pos": p + Vector3(0, 0.6, 0.3), "sala": "medieval_tocha"})
	# baú de ferro
	Malha.abrir("bau_medieval")
	cx(g, madeira, Vector3(-9.7, 0.25, -24.3), Vector3(0.5, 0.5, 0.8), true, 1.0)
	Malha.fechar(_et)


# ------------------------------------------------------------------ E1975: casa de veraneio
static func _veraneio_1975(c: Castelinho) -> void:
	var g := c.g_1975
	var madeira: Material = c.m.madeira
	var tecido := Castelinho.mat_cor(Color(0.78, 0.45, 0.2), 0.95)
	var tecido2 := Castelinho.mat_cor(Color(0.28, 0.5, 0.45), 0.95)
	var tapete := Castelinho.mat_cor(Color(0.7, 0.2, 0.18), 1.0)
	var palha := Castelinho.mat_cor(Color(0.8, 0.7, 0.45), 1.0)
	# Sala (antiga Sala Medieval) como casa de veraneio dos anos 70: tapete com barra, sofá de braços com
	# almofadas, poltronas, mesa de centro de pés palito, estante com livros, abajur de pé, TV de madeira e quadro
	var mostarda := Castelinho.mat_cor(Color(0.86, 0.62, 0.2), 0.95)
	var marrom := Castelinho.mat_cor(Color(0.4, 0.24, 0.14), 0.9)
	var _et := Malha.abrir("tapete_barra_1975")
	g.inte.quad(Castelinho.mat_cor(Color(0.45, 0.14, 0.1), 1.0), Vector3(-14.6, 0.015, -27.6), Vector3(-10.2, 0.015, -27.6), Vector3(-10.2, 0.015, -24.6), Vector3(-14.6, 0.015, -24.6), Vector3.UP)
	Malha.abrir("tapete_1975")
	g.inte.quad(tapete, Vector3(-14.4, 0.02, -27.4), Vector3(-10.4, 0.02, -27.4), Vector3(-10.4, 0.02, -24.8), Vector3(-14.4, 0.02, -24.8), Vector3.UP)
	# sofá (encosto na parede norte): base, encosto, braços, 3 almofadas, pés
	Malha.abrir("sofa_1975")
	cx(g, tecido, Vector3(-12.4, 0.3, -28.55), Vector3(2.2, 0.36, 0.9), true)
	cx(g, tecido, Vector3(-12.4, 0.72, -28.9), Vector3(2.2, 0.5, 0.2))
	for sx in [-1.0, 1.0]:
		cx(g, tecido, Vector3(-12.4 + 1.08 * sx, 0.5, -28.55), Vector3(0.22, 0.42, 0.9))
	for k in 3:
		cx(g, mostarda, Vector3(-13.07 + k * 0.67, 0.53, -28.5), Vector3(0.62, 0.1, 0.72))
	for p in [Vector3(-13.4, 0.06, -28.2), Vector3(-11.4, 0.06, -28.2), Vector3(-13.4, 0.06, -28.9), Vector3(-11.4, 0.06, -28.9)]:
		cx(g, madeira, p, Vector3(0.06, 0.12, 0.06))
	# poltronas
	for px in [-15.5, -9.7]:
		Malha.abrir("poltrona_1975_%s" % ("oeste" if px < -12.0 else "leste"))
		cx(g, tecido2, Vector3(px, 0.28, -26.3), Vector3(0.8, 0.34, 0.8), true)
		var fora := 1.0 if px > -12.0 else -1.0
		cx(g, tecido2, Vector3(px + 0.32 * fora, 0.65, -26.3), Vector3(0.16, 0.5, 0.8))
		for sz in [-1.0, 1.0]:
			cx(g, tecido2, Vector3(px, 0.48, -26.3 + 0.34 * sz), Vector3(0.8, 0.24, 0.12))
	# mesa de centro de pés palito com cinzeiro e vaso
	Malha.abrir("mesa_centro_1975")
	cx(g, madeira, Vector3(-12.4, 0.4, -26.1), Vector3(1.1, 0.05, 0.6), true, 1.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cx(g, madeira, Vector3(-12.4 + 0.45 * sx, 0.19, -26.1 + 0.22 * sz), Vector3(0.04, 0.38, 0.04))
	Malha.abrir("vaso_mesa_centro_1975")
	cx(g, Castelinho.mat_cor(Color(0.3, 0.55, 0.5), 0.4), Vector3(-12.6, 0.52, -26.1), Vector3(0.12, 0.2, 0.12))
	Malha.abrir("cinzeiro_mesa_centro_1975")
	cx(g, Castelinho.mat_cor(Color(0.8, 0.8, 0.78), 0.4), Vector3(-12.1, 0.44, -26.0), Vector3(0.14, 0.03, 0.14))
	# estante na parede oeste: caixa de madeira com prateleiras e lombadas coloridas
	Malha.abrir("estante_1975")
	cx(g, madeira, Vector3(-16.2, 1.0, -24.5), Vector3(0.45, 2.0, 1.2), true, 1.0)
	var lombadas := [Color(0.7, 0.2, 0.15), Color(0.2, 0.35, 0.6), Color(0.85, 0.7, 0.25), Color(0.25, 0.45, 0.3), Color(0.9, 0.88, 0.8)]
	for f in 3:
		var yy := 0.5 + f * 0.55
		var zz := -25.0
		var k := 0
		while zz < -24.0:
			var lw := 0.06 + 0.03 * float((k + f) % 3)
			cx(g, Castelinho.mat_cor(lombadas[(k + f * 2) % lombadas.size()], 0.8), Vector3(-15.96, yy + 0.14, zz + lw * 0.5), Vector3(0.02, 0.28 - 0.04 * float(k % 2), lw * 0.9))
			zz += lw
			k += 1
	Malha.abrir("radio_estante_1975")
	cx(g, Castelinho.mat_cor(Color(0.55, 0.35, 0.2), 0.7), Vector3(-15.96, 1.92, -24.5), Vector3(0.02, 0.18, 0.5))   # rádio
	# abajur de pé (cúpula laranja acesa) ao lado do sofá
	Malha.abrir("abajur_1975")
	cx(g, Castelinho.mat_cor(Color(0.15, 0.13, 0.12), 0.5), Vector3(-14.0, 0.75, -28.7), Vector3(0.04, 1.5, 0.04))
	cx(g, Castelinho.mat_cor(Color(0.15, 0.13, 0.12), 0.5), Vector3(-14.0, 0.02, -28.7), Vector3(0.3, 0.04, 0.3))
	cx(g, Castelinho.mat_luz(Color(1.0, 0.62, 0.25), 1.2), Vector3(-14.0, 1.55, -28.7), Vector3(0.36, 0.28, 0.36))
	# TV de madeira com tela esverdeada, no canto leste
	Malha.abrir("tv_1975")
	cx(g, marrom, Vector3(-9.0, 0.3, -24.4), Vector3(0.6, 0.6, 0.5), true, 1.0)
	cx(g, marrom, Vector3(-9.0, 0.85, -24.4), Vector3(0.62, 0.5, 0.5))
	g.inte.quad(Castelinho.mat_luz(Color(0.36, 0.45, 0.42), 0.6), Vector3(-9.22, 0.68, -24.12), Vector3(-8.84, 0.68, -24.12), Vector3(-8.84, 1.0, -24.12), Vector3(-9.22, 1.0, -24.12), N_S)
	# quadro de pôr do sol na parede norte, acima do sofá
	Malha.abrir("quadro_por_do_sol_1975")
	cx(g, madeira, Vector3(-12.4, 1.7, -29.08), Vector3(1.0, 0.62, 0.02))
	var por := [Color(0.95, 0.55, 0.25), Color(0.98, 0.78, 0.4), Color(0.3, 0.45, 0.6)]
	for k in 3:
		g.inte.quad(Castelinho.mat_cor(por[k], 0.9), Vector3(-12.85, 1.46 + k * 0.17, -29.035), Vector3(-11.95, 1.46 + k * 0.17, -29.035),
			Vector3(-11.95, 1.63 + k * 0.17, -29.035), Vector3(-12.85, 1.63 + k * 0.17, -29.035), N_S)
	Malha.abrir("cadeira_palha_1975")
	cx(g, palha, Vector3(-10.0, 0.5, -24.2), Vector3(0.5, 1.0, 0.5))         # cadeira de palha
	# bilhete de praia: guarda-sol dobrado, boia, prancha encostada
	Malha.abrir("guarda_sol_dobrado_1975")
	cx(g, Castelinho.mat_cor(Color(0.9, 0.3, 0.3), 0.9), Vector3(-9.0, 0.5, -28.7), Vector3(0.5, 1.0, 0.1))
	Malha.abrir("prancha_praia_1975")
	cx(g, Castelinho.mat_cor(Color(0.95, 0.85, 0.3), 0.9), Vector3(-9.4, 0.35, -28.7), Vector3(0.5, 0.7, 0.1))
	# corredor/hall: banco e cabideiro
	Malha.abrir("banco_hall_1975")
	cx(g, madeira, Vector3(-9.0, 0.25, -13.4), Vector3(1.4, 0.5, 0.4), true, 1.0)
	Malha.abrir("cabideiro_hall_1975")
	cx(g, madeira, Vector3(-14.8, 0.9, -13.4), Vector3(0.4, 1.8, 0.1))
	# Sala do Pescador em 1975: redes de pesca e caixas
	Malha.abrir("caixa_rede_pesca_1975")
	cx(g, palha, Vector3(-8.7, 0.3, -15.9), Vector3(1.2, 0.6, 0.8), true)
	Malha.abrir("caixa_verde_pescador_1975")
	cx(g, Castelinho.mat_cor(Color(0.45, 0.55, 0.4), 0.9), Vector3(-10.0, 0.25, -16.6), Vector3(0.9, 0.5, 0.6), true)
	Malha.fechar(_et)


# ------------------------------------------------------------------ nós avulsos
## Pinguim empalhado: corpo, barriga, cabeça e dois olhos que o nível faz seguir o jogador.
static func criar_pinguim() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Pinguim"
	var m := Malha.new()
	var preto := Castelinho.mat_cor(Color(0.07, 0.07, 0.09), 0.8)
	var branco := Castelinho.mat_cor(Color(0.93, 0.93, 0.92), 0.8)
	var bico := Castelinho.mat_cor(Color(0.9, 0.55, 0.15), 0.8)
	# pinguim-de-magalhães empalhado (foto do Meio Ambiente): corpo arredondado, barriga branca, nadadeiras
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1902
	var liso := Castelinho.mat_cor(Color.WHITE, 0.8)
	var p_c := Color(0.12, 0.12, 0.15)
	var p_s := Color(0.04, 0.04, 0.05)
	m.bolha(liso, Vector3(0, 0.34, 0), Vector3(0.17, 0.33, 0.15), rnd, 8, 3, 0.04, p_c, p_s)
	m.bolha(liso, Vector3(0, 0.3, 0.055), Vector3(0.13, 0.26, 0.11), rnd, 8, 3, 0.04, Color(0.95, 0.95, 0.93), Color(0.62, 0.62, 0.62))
	m.bolha(liso, Vector3(0, 0.72, 0.01), Vector3(0.11, 0.12, 0.11), rnd, 8, 3, 0.04, p_c, p_s)
	m.bolha(liso, Vector3(0, 0.5, 0.075), Vector3(0.12, 0.025, 0.07), rnd, 6, 2, 0.04, p_c, p_s)      # faixa preta no peito
	m.caixa(bico, Vector3(-0.025, 0.7, 0.09), Vector3(0.025, 0.74, 0.21), Malha.F_TODAS)
	for lado in [-1.0, 1.0]:
		m.bolha(liso, Vector3(0.18 * lado, 0.4, 0.0), Vector3(0.035, 0.17, 0.07), rnd, 6, 2, 0.05, p_c, p_s)
		m.bolha(liso, Vector3(0.07 * lado, 0.02, 0.06), Vector3(0.06, 0.025, 0.08), rnd, 6, 2, 0.05, Color(0.85, 0.55, 0.45), Color(0.5, 0.3, 0.25))
	m.construir_instancia(raiz, "Corpo", 2)
	for lado in [-1, 1]:
		var olho := Node3D.new()
		olho.name = "Olho_E" if lado == -1 else "Olho_D"
		olho.position = Vector3(0.055 * lado, 0.77, 0.115)
		raiz.add_child(olho)
		var mm := Malha.new()
		mm.caixa(Castelinho.mat_cor(Color(1, 1, 1), 0.3), Vector3(-0.022, -0.022, 0), Vector3(0.022, 0.022, 0.012), Malha.F_TODAS)
		mm.caixa(Castelinho.mat_cor(Color(0, 0, 0), 0.2), Vector3(-0.011, -0.011, 0.01), Vector3(0.011, 0.011, 0.02), Malha.F_TODAS)
		mm.construir_instancia(olho, "Malha", 2)
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
	m.construir_instancia(raiz, "Corpo", 2)
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
	m.construir_instancia(raiz, "Corpo", 2)
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
			# o mesmo Quico da interface (tools/gerar_mascotes.py): quero-quero branco de topete preto, babador
			# preto, asa pardo-acinzentada, olho vermelho, bico laranja com apito e pernas vermelhas
			formas = [
				["r", Rect2i(24, 98, 4, 28), Color(0.85, 0.25, 0.25)],        # pernas
				["r", Rect2i(36, 98, 4, 28), Color(0.85, 0.25, 0.25)],
				["c", Vector2i(32, 74), 25, Color(0.95, 0.95, 0.93)],         # corpo branco
				["r", Rect2i(30, 58, 22, 30), Color(0.6, 0.53, 0.45)],        # asa
				["c", Vector2i(30, 36), 15, Color(0.93, 0.93, 0.91)],         # cabeça
				["r", Rect2i(17, 22, 26, 8), Color(0.42, 0.44, 0.47)],        # coroa cinza
				["r", Rect2i(14, 8, 4, 18), Color(0.08, 0.08, 0.1)],          # topete (penacho para trás)
				["r", Rect2i(10, 6, 8, 4), Color(0.08, 0.08, 0.1)],
				["r", Rect2i(17, 47, 28, 9), Color(0.08, 0.08, 0.1)],         # babador preto
				["r", Rect2i(42, 34, 14, 5), Color(0.98, 0.62, 0.15)],        # bico
				["r", Rect2i(54, 38, 7, 4), Color(1.0, 0.85, 0.2)],           # apito
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
			fig.fill_rect(Rect2i(32, 29, 7, 7), Color(0.85, 0.15, 0.15))  # olho vermelho
			fig.fill_rect(Rect2i(34, 31, 3, 3), Color.BLACK)
			fig.fill_rect(Rect2i(54, 36, 3, 2), Color(0.1, 0.1, 0.1))     # ponta do bico
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
