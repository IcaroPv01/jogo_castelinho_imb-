class_name MiniLotes
extends MiniGameBase
## Minigame "Planejar a cidade" (Módulo 16): flashback do loteamento da cidade-jardim de 1939, no escritório de uma prefeitura
## FICTÍCIA (Programa Municipal de Memória Interativa). Entrada: mapa emoldurado no Acervo do Castelinho (visita 3).
##
## Começa como jogo educativo alegre da Tainá e termina pesado (PLANO §4.5: trecho pesado, sem piada no fim, sem gore):
##   - UMA ação (clique, [E] ou Interagir): um carimbo vai e vem sobre o lote da vez, cada vez mais rápido; quando o lote fica
##     VERDE, aperta e carimba "APROVADO". Errar só repete (a janela até aumenta). Nunca há falha de verdade.
##   - Cada carimbo faz o rancho de pescador do lote sumir num puf e põe uma casinha de "projeto" no lugar (6 lotes).
##   - O tom cai: no 3º a Tainá hesita; do 5º em diante a música para, a luz cai e ela fala curto.
##   - Virada: as casinhas somem, a planta fica com ruas e praças limpas e vazias; nas margens ficam as marcas escuras de onde
##     havia ranchos e um barco virado; um último carimbo aparece sozinho no canto. Nenhuma pessoa é mostrada.
## Só fatos da pesquisa (docs/pesquisa/historia_imbe.md §5): a cidade-jardim foi loteada em 1939 e os pescadores que já moravam
## ali foram reassentados do outro lado do rio. Nada além disso é afirmado, e ninguém real é nomeado.
## Uma única pista do Tito (fictício, só sugestão): um carrinho de brinquedo de madeira que ficou num dos lotes.

signal lote_carimbado(numero: int)

enum Fase { INTRO, ESPERA, CARIMBAR, FALA, VIRADA, FIM }

const TOTAL := 6
const LARGURA := 3.2                # a planta (m): x de -1,6 a 1,6, z de -1,0 a 1,0 (no plano da prancheta)
const PROFUNDIDADE := 2.0
const VARREDURA := 1.45             # o carimbo vai de -1,45 a +1,45 em x
const ALTURA_CARIMBO := 0.34
const JANELA_BASE := 0.36           # meia-largura (m) em que o carimbo vale; cresce 0,05 a cada erro no mesmo lote (até +0,2)
const LOTE_TAM := Vector2(0.6, 0.36)
const PLANTA_POS := Vector3(0, 1.15, -1.9)
const INCLINACAO := 45.0
const LUZ_LAMPADA := 2.2
const LUZ_AMBIENTE := 0.55
const LOTE_DO_CARRINHO := 3         # índice (0..5) do lote onde o carrinho do Tito ficou
## Lotes na ordem de jogo: posição no plano da planta (x, z) e velocidade do carimbo (m/s).
const LOTES: Array = [
	{"x": -0.95, "z": -0.55, "vel": 0.8}, {"x": 0.95, "z": -0.55, "vel": 1.0},
	{"x": -0.95, "z": -0.02, "vel": 1.2}, {"x": 0.95, "z": -0.02, "vel": 1.4},
	{"x": -0.95, "z": 0.50, "vel": 1.6}, {"x": 0.95, "z": 0.50, "vel": 1.8},
]

const FALA_INTRO: Array = [
	"Bem-vindo ao Departamento de Planejamento! Eu sou a Tainá, a estagiária!",
	"Hoje a gente vai planejar a cidade! Uma cidade-jardim, com ruas curvas e praças!",
	"É fácil: o carimbo vai e vem. Quando o lote ficar VERDE, aperte para carimbar APROVADO!",
]
## Comentários depois de cada carimbo: animada, depois hesita, depois curta e sem piada.
const FALA_LOTE: Array = [
	["CARIMBOU! Que carimbo bonito!", "Viu o ranchinho? Puf! Virou casinha de projeto!"],
	["Mais uma casinha! Ruas curvas, praças, ar puro...", "Uma cidade-jardim! Bonita de longe, né?"],
	["Esse tinha uma rede pendurada...", "...Tinha gente aqui, né? Hm.", "Não. Era só um rancho. Segue o jogo!"],
	["Tem um carrinho de madeira no chão. Ficou para trás.", "Não está no projeto. Vamos ao próximo."],
	["...Eu não escuto mais nada."],
	["O último."],
]

var fase := Fase.INTRO
var lotes_feitos := 0
var erros := 0                      # erros no total (só para quem testa)

var _planta: Node3D
var _carimbo: Node3D
var _guia: MeshInstance3D           # o "sombra" do carimbo no papel: onde ele cairia
var _marco: Node3D                  # moldura do lote da vez
var _lampada: OmniLight3D
var _sol_luz: DirectionalLight3D
var _mat_marco: StandardMaterial3D
var _mat_guia: StandardMaterial3D
var _mats: Dictionary = {}
var _fundos: Array = []             # MeshInstance3D do fundo de cada lote
var _fundos_mat: Array = []
var _ranchos: Array = []
var _casas: Array = []
var _marcas: Array = []             # retângulo escuro "onde havia um rancho" (aparece na virada)
var _imprints: Array = []
var _carrinho: Node3D
var _lote_atual := 0
var _erros_lote := 0
var _x_carimbo := 0.0
var _t_var := 0.0
var _vel := 1.0
var _x_no_aperto := 0.0
var _ok_no_aperto := false
var _t := 0.0
var _nivel_luz := 1.0
var _flick := 0.0
var _olhou := false
var _msg_dica_pc := ""
var _msg_dica_toque := ""


func _init() -> void:
	super()      # a base cria o marcador "Spawn" no _init: a filha precisa chamá-lo
	id = "lotes"
	quem_fala = "taina"
	corrupcao = 0.08
	fala_fim = ["Um carrinho de madeira ficou para trás.", "Vai ver alguém ainda procura por ele."]


# ============================================================================ pontos de vista
func ponto_jogador() -> Vector3:
	return Vector3(0, 0.1, -0.2)


func alvo_olhar() -> Vector3:
	return PLANTA_POS


# ============================================================================ planta (textura desenhada por código)
## Desenha a planta da cidade-jardim vista de cima (ruas curvas, praças, quadras, o rio embaixo). Estática: o mapa
## emoldurado do Castelinho usa a mesma imagem em tamanho menor.
static func textura_planta(larg := 512, alt := 320) -> ImageTexture:
	var k := float(larg) / LARGURA
	var img := Image.create(larg, alt, false, Image.FORMAT_RGB8)
	var papel := Color(0.93, 0.88, 0.74)
	var tinta := Color(0.36, 0.27, 0.2)
	img.fill(papel)
	# rio (embaixo) com margem ondulada
	var azul := Color(0.6, 0.71, 0.76)
	var onda := Color(0.78, 0.86, 0.88)
	for px in larg:
		var x := float(px) / k - 1.6
		var z_margem := 0.83 + 0.025 * sin(x * 2.2)
		var v0 := int((z_margem + 1.0) * k)
		img.fill_rect(Rect2i(px, v0, 1, alt - v0), azul)
		img.fill_rect(Rect2i(px, v0 - 1, 1, 2), tinta)
		if int(x * 9.0 + 100.0) % 7 == 0:
			for r in 3:
				img.fill_rect(Rect2i(px, v0 + int((0.06 + 0.06 * r) * k), maxi(1, int(0.03 * k)), 1), onda)
	# quadras (verde claro) e subdivisões dos lotes de fundo
	var quadra := Color(0.84, 0.85, 0.66)
	for cx in [-0.93, 0.93]:
		for cz in [-0.55, -0.02, 0.50]:
			_ret(img, k, cx - 0.46, cz - 0.23, cx + 0.46, cz + 0.23, quadra)
	for cz in [-0.55, 0.50]:
		_ret(img, k, -0.42, cz - 0.23, 0.42, cz + 0.23, quadra)
		for i in 6:
			_ret(img, k, -0.42 + 0.14 * i, cz - 0.23, -0.42 + 0.14 * i + 0.006, cz + 0.23, Color(0.62, 0.6, 0.45))
	# ruas: primeiro o contorno, depois o miolo claro (os cruzamentos se juntam)
	var ruas: Array = _ruas()
	for r: PackedVector2Array in ruas:
		_linha(img, k, r, 0.075, tinta)
	for r: PackedVector2Array in ruas:
		_linha(img, k, r, 0.058, Color(0.98, 0.95, 0.87))
	# praças: rotatórias verdes com copas de árvore
	var verde := Color(0.46, 0.64, 0.38)
	var verde_esc := Color(0.3, 0.5, 0.28)
	for p in [Vector3(0.0, -0.065, 0.17), Vector3(-0.18, -0.78, 0.11), Vector3(0.18, 0.5, 0.11)]:
		_disco(img, k, p.x, p.y, p.z + 0.012, tinta)
		_disco(img, k, p.x, p.y, p.z, verde)
		for a in 5:
			var ang := float(a) * TAU / 5.0 + 0.4
			_disco(img, k, p.x + cos(ang) * p.z * 0.5, p.y + sin(ang) * p.z * 0.5, p.z * 0.22, verde_esc)
	# borda dupla do papel
	_ret(img, k, -1.57, -0.97, 1.57, -0.962, tinta)
	_ret(img, k, -1.57, 0.97, 1.57, 0.978, tinta)
	_ret(img, k, -1.57, -0.97, -1.562, 0.978, tinta)
	_ret(img, k, 1.562, -0.97, 1.57, 0.978, tinta)
	return ImageTexture.create_from_image(img)


static func _ruas() -> Array:
	var ruas: Array = []
	var avenida := PackedVector2Array()
	var z := -0.95
	while z <= 0.8:
		avenida.append(Vector2(0.18 * sin(z * 2.4 + 0.4), z))
		z += 0.04
	ruas.append(avenida)
	for par in [[-0.285, 0.0], [0.24, 1.5], [0.77, 0.6]]:
		var rua := PackedVector2Array()
		var x := -1.55
		while x <= 1.55:
			rua.append(Vector2(x, float(par[0]) + 0.05 * sin(x * 2.6 + float(par[1]))))
			x += 0.05
		ruas.append(rua)
	for lado in [-1.0, 1.0]:
		var v := PackedVector2Array()
		var zz := -0.95
		while zz <= 0.8:
			v.append(Vector2(lado * 1.4 + 0.05 * sin(zz * 3.0 + lado), zz))
			zz += 0.05
		ruas.append(v)
	var anel := PackedVector2Array()
	for i in 49:
		var a := float(i) * TAU / 48.0
		anel.append(Vector2(cos(a) * 0.33, -0.065 + sin(a) * 0.27))
	ruas.append(anel)
	return ruas


## `pts` em metros no plano da planta (x, z); desenha quadradinhos ao longo da linha.
static func _linha(img: Image, k: float, pts: PackedVector2Array, esp_m: float, cor: Color) -> void:
	var esp := maxi(1, roundi(esp_m * k))
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, int(a.distance_to(b) * k))
		for s in n + 1:
			var p := a.lerp(b, float(s) / float(n))
			img.fill_rect(Rect2i(int((p.x + 1.6) * k) - esp / 2, int((p.y + 1.0) * k) - esp / 2, esp, esp), cor)


static func _ret(img: Image, k: float, x0: float, z0: float, x1: float, z1: float, cor: Color) -> void:
	var px := int((x0 + 1.6) * k)
	var py := int((z0 + 1.0) * k)
	img.fill_rect(Rect2i(px, py, maxi(1, int((x1 - x0) * k)), maxi(1, int((z1 - z0) * k))), cor)


static func _disco(img: Image, k: float, cx: float, cz: float, r: float, cor: Color) -> void:
	var rp := r * k
	var ox := (cx + 1.6) * k
	var oy := (cz + 1.0) * k
	for py in range(int(oy - rp) - 1, int(oy + rp) + 2):
		for px in range(int(ox - rp) - 1, int(ox + rp) + 2):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				if Vector2(px - ox, py - oy).length() <= rp:
					img.set_pixel(px, py, cor)


# ============================================================================ cenário
func _cor(c: Color, sem_luz := false, emissao := 0.0) -> StandardMaterial3D:
	var chave := "%s|%s|%s" % [c.to_html(true), sem_luz, emissao]
	if not _mats.has(chave):
		_mats[chave] = Ato2Pecas.mat_cor(c, sem_luz, emissao)
	return _mats[chave]


func _montar() -> void:
	ambiente(Color(0.04, 0.03, 0.04), Color(0.3, 0.2, 0.12), Color(0.05, 0.035, 0.03), 0.0, 0.3)
	env.ambient_light_color = Color(0.6, 0.42, 0.3)
	env.ambient_light_energy = LUZ_AMBIENTE
	for c in get_children():
		if c is DirectionalLight3D:
			_sol_luz = c
			_sol_luz.light_energy = 0.18
			_sol_luz.light_color = Color(1.0, 0.85, 0.65)
	_sala()
	_prancheta()
	_lotes_e_ranchos()
	_carimbo_e_guia()
	_lampada_pendente()


func _sala() -> void:
	var madeira := Ato2Pecas.mat_tri("lotes_chao", Color(0.62, 0.46, 0.34), Ato2Pecas.tex_madeira(), 0.7)
	var parede := _cor(Color(0.36, 0.27, 0.21))
	var forro := _cor(Color(0.2, 0.15, 0.12))
	Construtor.caixa(self, Vector3(9, 0.2, 9), Vector3(0, -0.1, -1.6), madeira, true, "Chao")
	Construtor.caixa(self, Vector3(9, 3.3, 0.2), Vector3(0, 1.65, -4.3), parede, false, "ParedeFundo")
	Construtor.caixa(self, Vector3(0.2, 3.3, 9), Vector3(-4.4, 1.65, -1.6), parede, false)
	Construtor.caixa(self, Vector3(0.2, 3.3, 9), Vector3(4.4, 1.65, -1.6), parede, false)
	Construtor.caixa(self, Vector3(9, 0.2, 9), Vector3(0, 3.3, -1.6), forro, false)
	Construtor.caixa(self, Vector3(9, 3.3, 0.2), Vector3(0, 1.65, 2.8), parede, false)
	# rodapé de madeira escura e placa da prefeitura (fictícia) na parede do fundo
	Construtor.caixa(self, Vector3(9, 0.25, 0.06), Vector3(0, 0.125, -4.17), _cor(Color(0.2, 0.13, 0.09)), false)
	var placa := Construtor.caixa(self, Vector3(2.6, 0.7, 0.04), Vector3(1.3, 2.0, -4.17), _cor(Color(0.82, 0.76, 0.6)), false, "Placa")
	var t1 := Construtor.rotulo(placa, "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA", Vector3(0, 0.12, 0.03), 40, Color(0.2, 0.14, 0.1))
	t1.pixel_size = 0.0021
	var t2 := Construtor.rotulo(placa, "Departamento de Planejamento", Vector3(0, -0.14, 0.03), 40, Color(0.2, 0.14, 0.1))
	t2.pixel_size = 0.0024
	# cartaz de otimismo
	var cartaz := Construtor.caixa(self, Vector3(1.0, 0.7, 0.03), Vector3(-1.7, 2.0, -4.17), _cor(Color(0.86, 0.8, 0.62)), false, "Cartaz")
	var t3 := Construtor.rotulo(cartaz, "O FUTURO\nÉ PLANEJADO", Vector3(0, 0.0, 0.03), 56, Color(0.5, 0.15, 0.1))
	t3.pixel_size = 0.0028
	# estante com rolos de planta
	Construtor.caixa(self, Vector3(2.2, 0.05, 0.35), Vector3(-2.3, 1.1, -4.0), _cor(Color(0.3, 0.2, 0.14)), false)
	var rolo := CylinderMesh.new()
	rolo.top_radius = 0.07
	rolo.bottom_radius = 0.07
	rolo.height = 0.55
	rolo.radial_segments = 8
	for i in 6:
		Ato2Pecas.malha(self, rolo, Vector3(-3.2 + i * 0.34, 1.4, -4.0), _cor(Color(0.9, 0.85, 0.7)), Vector3(0, 0, 90.0 if i % 2 == 0 else 0.0))
	# mesa lateral com a almofada de tinta
	Construtor.caixa(self, Vector3(1.0, 0.8, 0.6), Vector3(2.7, 0.4, -1.4), _cor(Color(0.34, 0.23, 0.16)), false, "MesaLateral")
	Construtor.caixa(self, Vector3(0.3, 0.04, 0.2), Vector3(2.55, 0.82, -1.4), _cor(Color(0.55, 0.1, 0.1)), false)


func _prancheta() -> void:
	_planta = Node3D.new()
	_planta.name = "Planta"
	_planta.position = PLANTA_POS
	_planta.rotation_degrees.x = INCLINACAO
	add_child(_planta)
	var madeira := _cor(Color(0.36, 0.24, 0.16))
	Construtor.caixa(_planta, Vector3(LARGURA + 0.16, 0.07, PROFUNDIDADE + 0.16), Vector3(0, -0.04, 0), madeira, false, "MoldurPlanta")
	var plano := PlaneMesh.new()
	plano.size = Vector2(LARGURA, PROFUNDIDADE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = textura_planta()
	mat.albedo_color = Color(0.82, 0.8, 0.78)      # a lâmpada estoura o papel claro
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var papel := Ato2Pecas.malha(_planta, plano, Vector3.ZERO, mat)
	papel.name = "Papel"
	# pernas (a prancheta é alta atrás e baixa na frente)
	var m_perna := _cor(Color(0.28, 0.19, 0.13))
	for lado in [-1.5, 1.5]:
		Construtor.caixa(self, Vector3(0.1, 1.55, 0.1), Vector3(lado, 0.775, -2.62), m_perna, false)
		Construtor.caixa(self, Vector3(0.1, 0.42, 0.1), Vector3(lado, 0.21, -1.22), m_perna, false)
	# título na água do rio, de pé na planta
	var titulo := Construtor.rotulo(_planta, "PLANTA DA CIDADE-JARDIM", Vector3(-0.7, 0.012, 0.9), 48, Color(0.97, 0.94, 0.82))
	titulo.rotation_degrees.x = -90.0
	titulo.pixel_size = 0.0026
	titulo.double_sided = false


func _lotes_e_ranchos() -> void:
	for i in TOTAL:
		var d: Dictionary = LOTES[i]
		var yaw := float((i * 13) % 25 - 12)
		var no := Node3D.new()
		no.name = "Lote%d" % (i + 1)
		no.position = Vector3(d.x, 0.0, d.z)
		_planta.add_child(no)
		Construtor.caixa(no, Vector3(LOTE_TAM.x + 0.04, 0.006, LOTE_TAM.y + 0.04), Vector3(0, 0.003, 0), _cor(Color(0.3, 0.22, 0.15)), false)
		var mat_fundo := Ato2Pecas.mat_cor(Color(0.86, 0.79, 0.52))
		_fundos_mat.append(mat_fundo)
		_fundos.append(Construtor.caixa(no, Vector3(LOTE_TAM.x, 0.01, LOTE_TAM.y), Vector3(0, 0.006, 0), mat_fundo, false, "Fundo"))
		var num := Construtor.rotulo(no, str(i + 1), Vector3(-LOTE_TAM.x * 0.5 + 0.06, 0.013, LOTE_TAM.y * 0.5 - 0.06), 40, Color(0.25, 0.17, 0.1))
		num.rotation_degrees.x = -90.0
		num.pixel_size = 0.0022
		# a marca escura "onde havia um rancho" (só aparece na virada)
		var marca := Construtor.caixa(no, Vector3(0.34, 0.004, 0.24), Vector3(0, 0.0125, 0.0), _cor(Color(0.2, 0.14, 0.09)), false, "Marca")
		marca.rotation_degrees.y = yaw
		marca.visible = false
		_marcas.append(marca)
		var rancho := _criar_rancho()
		rancho.position = Vector3(0, 0.011, 0)
		rancho.rotation_degrees.y = yaw
		no.add_child(rancho)
		_ranchos.append(rancho)
		var casa := _criar_casa()
		casa.position = Vector3(0, 0.011, 0)
		casa.rotation_degrees.y = yaw * 0.3
		casa.scale = Vector3.ZERO
		casa.visible = false
		no.add_child(casa)
		_casas.append(casa)
	# o carrinho de brinquedo de madeira que ficou para trás (única pista do Tito): só o objeto, ao lado do rancho
	var lote: Node3D = _planta.get_node("Lote%d" % (LOTE_DO_CARRINHO + 1))
	_carrinho = _criar_carrinho()
	_carrinho.position = Vector3(0.2, 0.011, 0.1)
	_carrinho.rotation_degrees.y = 25.0
	lote.add_child(_carrinho)


## Cabana de caixas de pescador: corpo de tábuas, telhado de palha e uma caixa ao lado. Nenhuma pessoa.
func _criar_rancho() -> Node3D:
	var r := Node3D.new()
	r.name = "Rancho"
	Construtor.caixa(r, Vector3(0.26, 0.1, 0.18), Vector3(0, 0.05, 0), _cor(Color(0.45, 0.3, 0.18)), false)
	var telhado := PrismMesh.new()
	telhado.size = Vector3(0.32, 0.09, 0.24)
	Ato2Pecas.malha(r, telhado, Vector3(0, 0.145, 0), _cor(Color(0.66, 0.54, 0.28)))
	Construtor.caixa(r, Vector3(0.05, 0.07, 0.01), Vector3(0.05, 0.035, 0.095), _cor(Color(0.15, 0.1, 0.07)), false)
	Construtor.caixa(r, Vector3(0.08, 0.07, 0.08), Vector3(-0.2, 0.035, 0.05), _cor(Color(0.68, 0.55, 0.36)), false)
	Construtor.caixa(r, Vector3(0.07, 0.05, 0.07), Vector3(-0.21, 0.095, 0.05), _cor(Color(0.6, 0.48, 0.3)), false)
	return r


## Casinha de "projeto": branca, de telhado vermelho, limpinha.
func _criar_casa() -> Node3D:
	var c := Node3D.new()
	c.name = "CasaProjeto"
	Construtor.caixa(c, Vector3(0.2, 0.1, 0.16), Vector3(0, 0.05, 0), _cor(Color(0.95, 0.93, 0.88)), false)
	var telhado := PrismMesh.new()
	telhado.size = Vector3(0.24, 0.08, 0.2)
	Ato2Pecas.malha(c, telhado, Vector3(0, 0.14, 0), _cor(Color(0.78, 0.22, 0.16)))
	Construtor.caixa(c, Vector3(0.04, 0.06, 0.01), Vector3(0, 0.03, 0.085), _cor(Color(0.2, 0.4, 0.75)), false)
	return c


## Carrinho de brinquedo de madeira (maior que o real, para ler de longe): um objeto pequeno e comum.
func _criar_carrinho() -> Node3D:
	var c := Node3D.new()
	c.name = "CarrinhoDeMadeira"
	Construtor.caixa(c, Vector3(0.14, 0.04, 0.07), Vector3(0, 0.04, 0), _cor(Color(0.78, 0.36, 0.2)), false)
	Construtor.caixa(c, Vector3(0.07, 0.035, 0.06), Vector3(-0.01, 0.077, 0), _cor(Color(0.88, 0.7, 0.4)), false)
	var roda := CylinderMesh.new()
	roda.top_radius = 0.022
	roda.bottom_radius = 0.022
	roda.height = 0.015
	roda.radial_segments = 8
	for dx in [-0.045, 0.045]:
		for dz in [-0.04, 0.04]:
			Ato2Pecas.malha(c, roda, Vector3(dx, 0.022, dz), _cor(Color(0.1, 0.07, 0.05)), Vector3(90, 0, 0))
	return c


func _carimbo_e_guia() -> void:
	_carimbo = Node3D.new()
	_carimbo.name = "Carimbo"
	_carimbo.visible = false
	_planta.add_child(_carimbo)
	Construtor.caixa(_carimbo, Vector3(0.32, 0.035, 0.2), Vector3(0, 0.0175, 0), _cor(Color(0.62, 0.1, 0.1)), false)
	Construtor.caixa(_carimbo, Vector3(0.26, 0.06, 0.15), Vector3(0, 0.065, 0), _cor(Color(0.3, 0.2, 0.13)), false)
	var cabo := CylinderMesh.new()
	cabo.top_radius = 0.028
	cabo.bottom_radius = 0.034
	cabo.height = 0.16
	cabo.radial_segments = 8
	Ato2Pecas.malha(_carimbo, cabo, Vector3(0, 0.175, 0), _cor(Color(0.34, 0.22, 0.14)))
	var bola := SphereMesh.new()
	bola.radius = 0.05
	bola.height = 0.1
	bola.radial_segments = 10
	bola.rings = 5
	Ato2Pecas.malha(_carimbo, bola, Vector3(0, 0.27, 0), _cor(Color(0.4, 0.26, 0.16)))
	_mat_guia = Ato2Pecas.mat_cor(Color(0.95, 0.25, 0.15, 0.5), true)
	var plano := PlaneMesh.new()
	plano.size = Vector2(0.32, 0.2)
	_guia = Ato2Pecas.malha(_planta, plano, Vector3(0, 0.016, 0), _mat_guia)
	_guia.visible = false
	# moldura do lote da vez (amarela; verde quando o carimbo está em cima)
	_mat_marco = Ato2Pecas.mat_cor(Color(1.0, 0.85, 0.2), true)
	_marco = Node3D.new()
	_marco.name = "Marco"
	_marco.visible = false
	_planta.add_child(_marco)
	var w := LOTE_TAM.x + 0.1
	var h := LOTE_TAM.y + 0.1
	for lado in [-1.0, 1.0]:
		Construtor.caixa(_marco, Vector3(w, 0.008, 0.025), Vector3(0, 0.018, lado * h * 0.5), _mat_marco, false)
		Construtor.caixa(_marco, Vector3(0.025, 0.008, h), Vector3(lado * w * 0.5, 0.018, 0), _mat_marco, false)


func _lampada_pendente() -> void:
	Construtor.caixa(self, Vector3(0.02, 0.8, 0.02), Vector3(0, 2.9, -1.4), _cor(Color(0.1, 0.08, 0.07)), false)
	var abajur := CylinderMesh.new()
	abajur.top_radius = 0.06
	abajur.bottom_radius = 0.32
	abajur.height = 0.24
	abajur.radial_segments = 12
	abajur.rings = 1
	Ato2Pecas.malha(self, abajur, Vector3(0, 2.4, -1.4), _cor(Color(0.2, 0.3, 0.22)))
	Ato2Pecas.malha(self, SphereMesh.new(), Vector3(0, 2.28, -1.4), _cor(Color(1.0, 0.85, 0.55), true), Vector3.ZERO, Vector3(0.12, 0.12, 0.12))
	_lampada = Construtor.luz(self, Vector3(0, 2.2, -1.2), Color(1.0, 0.82, 0.55), LUZ_LAMPADA, 7.0)
	_lampada.name = "Lampada"


# ============================================================================ luz e movimento
func _process(dt: float) -> void:
	super(dt)
	_t += dt
	if not _olhou and _desde_inicio > 0.5 and is_instance_valid(player):
		_olhou = true
		create_tween().tween_property(player.cabeca, "rotation:x", -0.3, 0.4)
	if lotes_feitos >= 2 and randf() < dt * 0.35:
		_flick = 0.55 + 0.2 * randf()
	_flick = move_toward(_flick, 0.0, dt * 3.0)
	if is_instance_valid(_lampada):
		_lampada.light_energy = LUZ_LAMPADA * _nivel_luz * (1.0 - _flick)
	if env:
		env.ambient_light_energy = LUZ_AMBIENTE * (0.35 + 0.65 * _nivel_luz)
	if is_instance_valid(_sol_luz):
		_sol_luz.light_energy = 0.18 * _nivel_luz
	if fase == Fase.CARIMBAR:
		_t_var += dt * _vel
		_x_carimbo = -VARREDURA + pingpong(_t_var, 2.0 * VARREDURA)
		_carimbo.position.x = _x_carimbo
		_guia.position.x = _x_carimbo
		var dentro := carimbo_sobre_lote()
		var pulso := 0.5 + 0.5 * sin(_t * 9.0)
		_mat_marco.albedo_color = Color(0.2, 1.0, 0.35) if dentro else Color(1.0, 0.8, 0.15).lerp(Color(1.0, 0.45, 0.1), pulso)
		_mat_guia.albedo_color = Color(0.2, 0.9, 0.3, 0.6) if dentro else Color(0.95, 0.25, 0.15, 0.45)
		_marco.scale = Vector3.ONE * (1.06 if dentro else 1.0)
		var fundo: StandardMaterial3D = _fundos_mat[_lote_atual]
		fundo.albedo_color = Color(0.55, 0.85, 0.4) if dentro else Color(0.86, 0.79, 0.52)


func _luz_nivel(alvo: float, dur: float) -> void:
	create_tween().tween_property(self, "_nivel_luz", alvo, dur)


## O carimbo está em cima do lote da vez? (os testes e o jogador usam o mesmo critério)
func carimbo_sobre_lote() -> bool:
	if fase != Fase.CARIMBAR:
		return false
	return absf(_x_carimbo - float((LOTES[_lote_atual] as Dictionary).x)) <= _janela()


func _janela() -> float:
	return JANELA_BASE + minf(0.05 * float(_erros_lote), 0.2)


func lote_atual() -> int:
	return _lote_atual


func acionar() -> void:
	if not acao_vale():
		return
	if fase == Fase.CARIMBAR:
		_x_no_aperto = _x_carimbo
		_ok_no_aperto = carimbo_sobre_lote()
		super()


# ============================================================================ o jogo
func _rodar() -> bool:
	placar("Lotes 0/%d" % TOTAL)
	Audio.musica("jingle_0", 0.6)
	if not await falar("taina", FALA_INTRO):
		return false
	for i in TOTAL:
		_lote_atual = i
		_erros_lote = 0
		_marco.position = Vector3((LOTES[i] as Dictionary).x, 0.0, (LOTES[i] as Dictionary).z)
		_marco.visible = true
		if not await esperar(0.4):
			return false
		_iniciar_varredura(i)
		_dica_carimbar()
		while true:
			if not await esperar_acao():
				return false
			if _ok_no_aperto:
				break
			if not await _errou():
				return false
		dica("", "")
		if not await _carimbar(i):
			return false
		if not await falar("taina", FALA_LOTE[i]):
			return false
		if not await _depois_do_lote(i):
			return false
	return await _virada()


func _dica_carimbar() -> void:
	dica("Clique ou [E] para carimbar APROVADO quando o lote ficar VERDE", "Toque em Interagir para carimbar quando o lote ficar VERDE")


func _iniciar_varredura(i: int) -> void:
	var d: Dictionary = LOTES[i]
	_vel = float(d.vel)
	_t_var = 2.0 * VARREDURA if float(d.x) < 0.0 else 0.0
	_x_carimbo = -VARREDURA + pingpong(_t_var, 2.0 * VARREDURA)
	_ok_no_aperto = false
	_carimbo.position = Vector3(_x_carimbo, ALTURA_CARIMBO, float(d.z))
	_guia.position = Vector3(_x_carimbo, 0.016, float(d.z))
	_carimbo.visible = true
	_guia.visible = true
	fase = Fase.CARIMBAR


## Errou: o carimbo cai fora do lote e sobe de novo. Só repete; a janela aumenta um pouco.
func _errou() -> bool:
	_erros_lote += 1
	erros += 1
	fase = Fase.FALA
	var tw := create_tween()
	tw.tween_property(_carimbo, "position:y", 0.05, 0.1)
	tw.tween_property(_carimbo, "position:y", ALTURA_CARIMBO, 0.25)
	if _lote_atual < 4:
		Audio.sfx("erro")
	dica("Quase! Espere o lote ficar VERDE.", "Quase! Espere o lote ficar VERDE.")
	if not await esperar(0.7):
		return false
	_ok_no_aperto = false
	_dica_carimbar()
	fase = Fase.CARIMBAR
	return true


func _carimbar(i: int) -> bool:
	fase = Fase.FALA
	var d: Dictionary = LOTES[i]
	_carimbo.position.x = float(d.x)
	_guia.position.x = float(d.x)
	_guia.visible = false
	var tw := create_tween()
	tw.tween_property(_carimbo, "position:y", 0.045, 0.12)
	if not await esperar(0.13):
		return false
	Audio.sfx("selo", -2.0 if i < 4 else -7.0)
	var yaw := float((i * 7) % 11 - 5)
	_imprimir(Vector3(float(d.x), 0.02, float(d.z)), yaw, 1.0)
	_puf(Vector3(float(d.x), 0.1, float(d.z)))
	# o rancho some e a casinha de projeto aparece
	var rancho: Node3D = _ranchos[i]
	var tr := create_tween()
	tr.tween_property(rancho, "scale", Vector3.ZERO, 0.18)
	tr.tween_callback(rancho.hide)
	var casa: Node3D = _casas[i]
	casa.visible = true
	var tc := create_tween()
	tc.tween_interval(0.12)
	tc.tween_property(casa, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(_fundos_mat[i] as StandardMaterial3D).albedo_color = Color(0.7, 0.8, 0.55)
	if i < 3:
		Audio.sfx("acerto", -6.0)
	create_tween().tween_property(_carimbo, "position:y", ALTURA_CARIMBO, 0.3)
	lotes_feitos = i + 1
	placar("Lotes %d/%d" % [lotes_feitos, TOTAL])
	lote_carimbado.emit(lotes_feitos)
	if not await esperar(0.5):
		return false
	_carimbo.visible = false
	_marco.visible = false
	fase = Fase.ESPERA
	return true


## Ajusta o clima depois de cada lote: a luz cai e, a partir do 5º, tudo silencia.
func _depois_do_lote(i: int) -> bool:
	match i:
		1:
			GameState.definir_corruption_manual(0.12)
		2:
			GameState.definir_corruption_manual(0.16)
			_luz_nivel(0.8, 1.0)
		3:
			# o jingle e o ambiente param (o resto é silêncio); a luz cai
			GameState.definir_corruption_manual(0.2)
			Audio.silenciar(1.2)
			Audio.ambiente("")
			_luz_nivel(0.5, 1.5)
		4:
			GameState.definir_corruption_manual(0.24)
			_luz_nivel(0.36, 1.2)
	return await esperar(0.3)


## Gotinhas de poeira (o rancho some "num puf").
func _puf(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, -0.15, 0)
	var esf := SphereMesh.new()
	esf.radius = 0.06
	esf.height = 0.12
	esf.radial_segments = 6
	esf.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	esf.material = m
	p.mesh = esf
	var g := Gradient.new()
	g.set_color(0, Color(0.92, 0.86, 0.72, 0.9))
	g.set_color(1, Color(0.92, 0.86, 0.72, 0.0))
	p.color_ramp = g
	_planta.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(p.queue_free)


## O "APROVADO" vermelho no papel: moldura e texto.
func _imprimir(pos: Vector3, yaw: float, escala: float) -> Node3D:
	var no := Node3D.new()
	no.name = "Aprovado"
	no.position = pos
	no.rotation_degrees.y = yaw
	_planta.add_child(no)
	var vermelho := _cor(Color(0.78, 0.1, 0.12), true)
	var w := 0.5 * escala
	var h := 0.17 * escala
	var e := 0.012 * escala
	Construtor.caixa(no, Vector3(w, 0.004, e), Vector3(0, 0, h * 0.5), vermelho, false)
	Construtor.caixa(no, Vector3(w, 0.004, e), Vector3(0, 0, -h * 0.5), vermelho, false)
	Construtor.caixa(no, Vector3(e, 0.004, h), Vector3(w * 0.5, 0, 0), vermelho, false)
	Construtor.caixa(no, Vector3(e, 0.004, h), Vector3(-w * 0.5, 0, 0), vermelho, false)
	var txt := Construtor.rotulo(no, "APROVADO", Vector3(0, 0.003, 0), 64, Color(0.78, 0.1, 0.12))
	txt.rotation_degrees.x = -90.0
	txt.pixel_size = 0.0024 * escala
	txt.double_sided = false
	_imprints.append(no)
	return no


# ============================================================================ a virada
func _virada() -> bool:
	fase = Fase.VIRADA
	GameState.definir_corruption_manual(0.27)
	_luz_nivel(0.3, 2.0)
	if not await esperar(1.6):
		return false
	# as casinhas somem uma a uma; ficam só as marcas escuras de onde havia ranchos
	for i in TOTAL:
		var casa: Node3D = _casas[i]
		var tw := create_tween()
		tw.tween_property(casa, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(casa.hide)
		var marca: Node3D = _marcas[i]
		marca.visible = true
		(_fundos_mat[i] as StandardMaterial3D).albedo_color = Color(0.4, 0.31, 0.21)
		if not await esperar(0.45):
			return false
	for im: Node3D in _imprints:
		var ti := create_tween()
		ti.tween_property(im, "scale", Vector3.ZERO, 0.6)
	if not await esperar(1.0):
		return false
	_barco_virado()
	if not await esperar(1.6):
		return false
	# o último carimbo aparece sozinho, no canto da planta
	_carimbo.position = Vector3(1.18, 0.55, -0.86)
	_carimbo.visible = true
	var tg := create_tween()
	tg.tween_property(_carimbo, "position:y", 0.045, 1.3).set_trans(Tween.TRANS_SINE)
	if not await esperar(1.35):
		return false
	Audio.sfx("selo", -6.0)
	_imprimir(Vector3(1.18, 0.02, -0.86), 11.0, 1.2)
	create_tween().tween_property(_carimbo, "position:y", 0.55, 0.9)
	if not await esperar(1.6):
		return false
	_carimbo.visible = false
	if not await falar("taina", ["Todo mundo foi para outro lugar.", "Disseram que foi melhor assim."]):
		return false
	fase = Fase.FIM
	return await esperar(1.2)


## Um barco virado na margem do rio (só o objeto, sem ninguém).
func _barco_virado() -> void:
	var b := Node3D.new()
	b.name = "BarcoVirado"
	b.position = Vector3(1.15, 0.0, 0.74)
	b.rotation_degrees.y = -14.0
	_planta.add_child(b)
	var casco := SphereMesh.new()
	casco.radial_segments = 12
	casco.rings = 6
	Ato2Pecas.malha(b, casco, Vector3(0, 0.0, 0), _cor(Color(0.22, 0.3, 0.36)), Vector3.ZERO, Vector3(0.34, 0.1, 0.13))
	Construtor.caixa(b, Vector3(0.5, 0.012, 0.018), Vector3(0, 0.1, 0), _cor(Color(0.5, 0.38, 0.25)), false)
	b.scale = Vector3(0.01, 0.01, 0.01)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

