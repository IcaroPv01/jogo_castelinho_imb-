class_name MiniCaderno
extends MiniGameBase
## Minigame "Os desenhos do Tito" (Módulo 16): o minigame CALMO e triste, sem susto. Entrada: um caderno de desenho aberto sobre
## um degrau, na Rua das casas de veraneio (Módulo 14, `cidade_casas.gd`, perto do Spawn).
##
## Cena: o quarto de uma criança de veraneio, fim de tarde, luz quente. Uma escrivaninha de tampo inclinado com UMA folha grande de
## caderno e um lápis de cor (a câmera fica parada olhando a folha, como em `mini_lotes.gd`).
## UMA ação, MANTIDA (Input.is_action_pressed("interagir"): clique, [E] ou o botão Interagir no celular):
##   - SEGURAR = o lápis RISCA; SOLTAR = o lápis levanta.
##   - O lápis anda SOZINHO, em velocidade constante, por um caminho pontilhado. Os trechos de TRAÇO (pontinhos cinza-claros)
##     são para riscar; os trechos VAZIO (pontinhos miúdos) são o lápis passando pelo ar: soltar. Segurar no vazio só rabisca.
##   - Cobrir >= 70% do traço "vence" o desenho; errar só deixa o desenho mais torto. Nunca há falha de verdade: os 3 desenhos
##     sempre acontecem, e quem chega ao fim ganha a pista (como na tarrafa da Barra).
##   - 3 desenhos de ~15 s, bem de criança: (1) a casa de veraneio com sol, (2) um barquinho e a ponte, (3) o menino de mãos dadas
##     com uma figura alta e branca. A cada desenho a Tainá comenta curto.
## Virada (desenho 3): quando o jogador solta o lápis no último traço, o lápis continua riscando SOZINHO: uma trilha de pontinhos
## até uma casinha bem longe, no outro canto da folha, e escreve devagar "TITO" (o T da frente está de cabeça para baixo, como no
## caderno da pista da Rua das casas). A Tainá: "Ele desenhou pra voltar pra casa?". Só sugestão: Tito é FICTÍCIO, nada violento,
## nada de susto. Nenhum fato histórico novo (arte de criança fictícia); a ponte é só a de três pistas de historia_imbe.md §6.
## Para testes: `desenho`, `fase`, `no_traco`, `segurando`, `cobertura`, `coberturas`, `vencidos`, `texto_escrito`, `casa_longe`.

signal desenho_pronto(numero: int, cobertura: float)

enum Fase { INTRO, ESPERA, DESENHAR, COMENTAR, VIRADA, FIM }

const TOTAL := 3
const FOLHA_U := 320.0              # a folha em "unidades" (1 unidade = 1 cm da folha de 3,2 x 2,2 m)
const FOLHA_V := 220.0
const UNID := 0.01                  # metros por unidade
const PX := 2.4                     # pixels da textura por unidade
const TEX_W := 768
const TEX_H := 528
const PLANTA_POS := Vector3(0, 1.15, -1.9)
const INCLINACAO := 45.0
const MIN_COBERTURA := 0.7          # 70% do traço riscado vence o desenho
const R_TINTA := 2.7                # raio do giz de cera (unidades)
const LEVANTA := 0.16               # altura do lápis no ar (m)
const T_INVERTIDO := true           # o 1º T de "TITO" de cabeça para baixo, como no caderno da Rua das casas
const LUZ_LAMPADA := 1.7
const LUZ_AMBIENTE := 0.8

const FALA_INTRO: Array = [
	"Esse é o quarto do Tito, o menino que veraneava aqui. Ele deixou o caderno de desenhos.",
	"Cada folha tem um desenho pontilhado. O lápis anda sozinho: segure para riscar quando for traço, e solte nos vazios.",
	"Não precisa ficar perfeito. Desenho de criança nunca é.",
]
const FALAS_DESENHO := {
	1: {"bom": ["Uma casinha de veraneio, com sol.", "Do jeito que ele via aqui da janela."],
		"torto": ["Ficou meio torto, mas dá para ver a casa e o sol.", "É assim que criança desenha."]},
	2: {"bom": ["Um barquinho e a ponte, com as três pistas lado a lado.", "Ele devia olhar muito para a água."],
		"torto": ["Um barquinho e a ponte, meio tortos.", "A água também não parava quieta."]},
}
const FALA_TITO: Array = ["Ele desenhou pra voltar pra casa?"]

var fase := Fase.INTRO
var desenho := 0                    # 1..3 (0 antes de começar)
var no_traco := false               # o lápis está num trecho de TRAÇO agora?
var segurando := false              # o jogador está segurando a ação (e ela vale)?
var cobertura := 0.0                # 0..1 do traço do desenho atual já riscado
var coberturas: Array = []          # cobertura final de cada desenho feito
var vencidos := 0                   # desenhos com >= 70%
var texto_escrito := ""             # o que o lápis escreveu sozinho ("TITO")
var casa_longe := false             # a casinha distante já foi riscada pelo lápis sozinho
var pontos_auto := 0                # carimbos que o lápis deu sozinho (para testes)

var _folha: Node3D
var _lapis: Node3D
var _lapis_corpo: Node3D
var _sombra: MeshInstance3D
var _mat_corpo: StandardMaterial3D
var _mat_ponta: StandardMaterial3D
var _lampada: OmniLight3D
var _sol_luz: DirectionalLight3D
var _mats: Dictionary = {}
var _brushes: Dictionary = {}
var _img: Image
var _tex: ImageTexture
var _base: Image
var _sujo := false
var _dados: Dictionary = {}
var _vel := 48.0
var _P := PackedVector2Array()      # o caminho todo (traços e vazios)
var _cum := PackedFloat32Array()    # comprimento acumulado até cada ponto
var _tipo := PackedInt32Array()     # por aresta: 1 = traço, 0 = vazio
var _cor_ar := PackedInt32Array()   # por aresta: índice do traço (no vazio, o do próximo)
var _L := 0.0
var _total_traco := 0.0
var _s := 0.0                       # onde o lápis está no caminho (unidades)
var _cobertos := 0.0
var _auto: Array = []               # a parte final feita sozinha: {rs, vel, tinta, pont, cor}
var _auto_i := 0
var _auto_u := 0.0
var _auto_k := 0
var _auto_fim := false
var _auto_tinta := false
var _auto_cor := Color.WHITE
var _pos_auto := Vector2.ZERO
var _lift := LEVANTA
var _nivel_luz := 1.0
var _olhou := false
var _pregados: Array = []


func _init() -> void:
	super()      # a base cria o marcador "Spawn" no _init: a filha precisa chamá-lo
	id = "caderno"
	quem_fala = "taina"
	corrupcao = 0.06
	destino = "res://world/niveis/cidade_casas.tscn"
	fala_fim = ["Um caminho de pontinhos até a casinha.", "Acho que o Tito só queria voltar."]


# ============================================================================ pontos de vista
func ponto_jogador() -> Vector3:
	return Vector3(0, 0.1, -0.2)


func alvo_olhar() -> Vector3:
	return PLANTA_POS


# ============================================================================ os desenhos (dados estáticos)
## O desenho `n` (1..3): papel, cor da guia e os TRAÇOS (cada um com sua cor); entre dois traços o lápis passa pelo ar (vazio).
## Coordenadas em unidades da folha (x 0..320, y 0..220, y para baixo). `vel` em unidades/s, constante dentro do desenho.
static func dados(n: int) -> Dictionary:
	match n:
		1:
			return {"papel": Color(0.96, 0.92, 0.82), "pauta": true, "guia": Color(0.62, 0.62, 0.67), "vel": 48.0, "tracos": [
				{"cor": Color(0.86, 0.26, 0.2), "pts": _t([Vector2(110, 142), Vector2(150, 108), Vector2(190, 142)], 1.0)},
				{"cor": Color(0.88, 0.5, 0.14), "pts": _t([Vector2(190, 148), Vector2(190, 186), Vector2(110, 186), Vector2(110, 148)], 2.0)},
				{"cor": Color(0.2, 0.4, 0.82), "pts": _t([Vector2(160, 186), Vector2(160, 160), Vector2(140, 160), Vector2(140, 186)], 3.0)},
				{"cor": Color(0.9, 0.68, 0.08), "pts": _t([Vector2(127, 150), Vector2(115, 150), Vector2(115, 162), Vector2(127, 162), Vector2(127, 150)], 4.0)},
				{"cor": Color(1.0, 0.62, 0.0), "pts": _t(_circ(Vector2(250, 62), 14.0, 90.0), 5.0)},
			]}
		2:
			return {"papel": Color(0.93, 0.95, 0.96), "pauta": true, "guia": Color(0.6, 0.62, 0.68), "vel": 48.0, "tracos": [
				{"cor": Color(0.78, 0.22, 0.18), "pts": _t([Vector2(170, 150), Vector2(142, 178), Vector2(88, 178), Vector2(60, 150)], 1.0)},
				{"cor": Color(0.5, 0.32, 0.16), "pts": _t([Vector2(115, 148), Vector2(115, 92), Vector2(152, 138)], 2.0)},
				{"cor": Color(0.3, 0.36, 0.55), "pts": _t(_curva(Vector2(190, 160), Vector2(245, 84), Vector2(300, 160), 18), 3.0)},
				{"cor": Color(0.2, 0.5, 0.86), "pts": _t(_onda(292.0, 200.0, 196.0, 5.0, 28.0), 4.0)},
				{"cor": Color(0.2, 0.5, 0.86), "pts": _t(_onda(170.0, 90.0, 205.0, 5.0, 28.0), 5.0)},
			]}
		_:
			var boy := Color(1.0, 0.82, 0.35)
			var alta := Color(0.98, 0.98, 1.0)
			return {"papel": Color(0.2, 0.24, 0.4), "pauta": false, "guia": Color(0.6, 0.64, 0.78), "vel": 52.0, "tracos": [
				{"cor": boy, "pts": _t(_circ(Vector2(90, 108), 12.0, -90.0), 1.0)},
				{"cor": boy, "pts": _t([Vector2(90, 136), Vector2(90, 168), Vector2(76, 204)], 2.0)},
				{"cor": boy, "pts": _t([Vector2(90, 168), Vector2(104, 204)], 3.0)},
				{"cor": boy, "pts": _t([Vector2(90, 148), Vector2(130, 160), Vector2(226, 108)], 4.0)},
				{"cor": alta, "pts": _t(_circ(Vector2(228, 34), 12.0, -90.0), 5.0)},
				{"cor": alta, "pts": _t([Vector2(228, 64), Vector2(228, 198)], 6.0)},
			]}


## Um traço de pontos, com um tremidinho de mão de criança (as pontas ficam onde estão).
static func _t(pts: Array, semente: float) -> PackedVector2Array:
	var bruto := PackedVector2Array(pts)
	var out := PackedVector2Array()
	out.append(bruto[0])
	var acum := 0.0
	for i in range(1, bruto.size()):
		var a: Vector2 = bruto[i - 1]
		var b: Vector2 = bruto[i]
		var d: float = a.distance_to(b)
		var n := maxi(1, int(d / 6.0))
		var nor: Vector2 = (b - a).orthogonal().normalized()
		for k in range(1, n + 1):
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			acum += d / float(n)
			if not (i == bruto.size() - 1 and k == n):
				p += nor * sin(acum * 0.23 + semente) * 0.9
			out.append(p)
	return out


## Círculo inteiro a partir do ângulo `a0` (graus; -90 = topo, 90 = base, y para baixo).
static func _circ(c: Vector2, r: float, a0: float) -> Array:
	var out: Array = []
	for i in 29:
		var a := deg_to_rad(a0) + float(i) * TAU / 28.0
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _curva(a: Vector2, c: Vector2, b: Vector2, n: int) -> Array:
	var out: Array = []
	for i in n + 1:
		var t := float(i) / float(n)
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


static func _onda(x0: float, x1: float, y: float, amp: float, comp: float) -> Array:
	var out: Array = []
	var n := int(absf(x1 - x0) / 3.0)
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / float(n))
		out.append(Vector2(x, y + amp * sin(absf(x - x0) / comp * TAU)))
	return out


## Uma linha reta amostrada de 1 em 1 unidade (usada pelo trecho feito sozinho).
static func _amostrar(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var d: float = a.distance_to(b)
		var pos := 1.0 - carry
		while pos <= d:
			out.append(a.lerp(b, pos / d))
			pos += 1.0
		carry = d - (pos - 1.0)
	if out[out.size() - 1] != pts[pts.size() - 1]:
		out.append(pts[pts.size() - 1])
	return out


## O que o lápis faz sozinho depois do último traço: trilha de pontinhos até a casinha longe, a casinha, e "TITO" devagar.
static func auto_virada() -> Array:
	var cor := Color(1.0, 0.86, 0.5)
	var trilha := _t([Vector2(228, 198), Vector2(200, 213), Vector2(120, 214), Vector2(40, 214), Vector2(26, 170), Vector2(24, 110), Vector2(30, 66)], 7.0)
	var casa: Array = [
		[Vector2(19, 62), Vector2(19, 48), Vector2(43, 48), Vector2(43, 62), Vector2(19, 62)],      # paredes
		[Vector2(15, 48), Vector2(31, 35), Vector2(47, 48)],                                          # telhado
		[Vector2(28, 62), Vector2(28, 54), Vector2(34, 54), Vector2(34, 62)],                         # porta
	]
	var x0 := 62.0
	var y0 := 38.0
	var letras: Array = []
	if T_INVERTIDO:
		letras.append([Vector2(x0, y0 + 18.0), Vector2(x0 + 12.0, y0 + 18.0)])
		letras.append([Vector2(x0 + 6.0, y0 + 18.0), Vector2(x0 + 6.0, y0)])
	else:
		letras.append([Vector2(x0, y0), Vector2(x0 + 12.0, y0)])
		letras.append([Vector2(x0 + 6.0, y0), Vector2(x0 + 6.0, y0 + 18.0)])
	letras.append([Vector2(x0 + 22.0, y0), Vector2(x0 + 22.0, y0 + 18.0)])                          # I
	letras.append([Vector2(x0 + 32.0, y0), Vector2(x0 + 44.0, y0)])                                  # T
	letras.append([Vector2(x0 + 38.0, y0), Vector2(x0 + 38.0, y0 + 18.0)])
	var o: Array = []
	for i in 25:
		var a := -PI * 0.5 + float(i) * TAU / 24.0
		o.append(Vector2(x0 + 54.0 + cos(a) * 6.0, y0 + 9.0 + sin(a) * 9.0))                        # O
	letras.append(o)
	var lista: Array = [{"pts": trilha, "vel": 150.0, "tinta": true, "pont": true, "cor": cor, "nome": "trilha"}]
	var ultimo: Vector2 = trilha[trilha.size() - 1]
	for g in casa:
		var pts := PackedVector2Array(g)
		lista.append({"pts": PackedVector2Array([ultimo, pts[0]]), "vel": 110.0, "tinta": false, "pont": false, "cor": cor, "nome": "voo"})
		lista.append({"pts": pts, "vel": 60.0, "tinta": true, "pont": false, "cor": cor, "nome": "casa"})
		ultimo = pts[pts.size() - 1]
	for g in letras:
		var pts := PackedVector2Array(g)
		lista.append({"pts": PackedVector2Array([ultimo, pts[0]]), "vel": 110.0, "tinta": false, "pont": false, "cor": cor, "nome": "voo"})
		lista.append({"pts": pts, "vel": 40.0, "tinta": true, "pont": false, "cor": cor, "nome": "letra"})
		ultimo = pts[pts.size() - 1]
	for seg: Dictionary in lista:
		seg["rs"] = _amostrar(seg["pts"])
	return lista


# ============================================================================ o caminho do desenho atual
func _construir_caminho() -> void:
	_P = PackedVector2Array()
	_cum = PackedFloat32Array()
	_tipo = PackedInt32Array()
	_cor_ar = PackedInt32Array()
	_total_traco = 0.0
	var tracos: Array = _dados["tracos"]
	for k in tracos.size():
		var pts: PackedVector2Array = (tracos[k] as Dictionary)["pts"]
		if k == 0:
			_P.append(pts[0])
			_cum.append(0.0)
		else:
			_empurrar(pts[0], 0, k)
		for j in range(1, pts.size()):
			_empurrar(pts[j], 1, k)
	_L = _cum[_cum.size() - 1]


func _empurrar(p: Vector2, tipo: int, k: int) -> void:
	var d: float = _P[_P.size() - 1].distance_to(p)
	if d < 0.001:
		return
	_cum.append(_cum[_cum.size() - 1] + d)
	_P.append(p)
	_tipo.append(tipo)
	_cor_ar.append(k)
	if tipo == 1:
		_total_traco += d


func _idx(s: float) -> int:
	return clampi(_cum.bsearch(s) - 1, 0, _tipo.size() - 1)


func _ponto_em(s: float) -> Vector2:
	var i := _idx(s)
	var seg: float = _cum[i + 1] - _cum[i]
	var t := 0.0 if seg <= 0.0 else clampf((s - _cum[i]) / seg, 0.0, 1.0)
	return _P[i].lerp(_P[i + 1], t)


func _cor_traco(i: int) -> Color:
	return ((_dados["tracos"] as Array)[_cor_ar[i]] as Dictionary)["cor"]


## Comprimento total do caminho (unidades), do traço, e quanto tempo o desenho dura (s). Para testes e ajustes.
func comprimento() -> float:
	return _L


func total_traco() -> float:
	return _total_traco


func duracao() -> float:
	return _L / _vel


func progresso() -> float:
	return _s / maxf(_L, 0.001)


# ============================================================================ a folha (textura desenhada por código)
func _brush(cor: Color, raio_px: float, variante: int, alfa := 0.92) -> Image:
	var chave := "%s|%.1f|%d|%.2f" % [cor.to_html(), raio_px, variante, alfa]
	if _brushes.has(chave):
		return _brushes[chave]
	var d := int(ceil(raio_px * 2.0)) + 3
	var im := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (variante + 1) + int(raio_px * 10.0)
	var c := float(d - 1) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(float(x) - c, float(y) - c).length()
			var a := clampf((raio_px + 0.5 - dist) / 1.4, 0.0, 1.0)
			if a > 0.0:
				a *= alfa * (0.78 + 0.22 * rng.randf())
				im.set_pixel(x, y, Color(cor.r, cor.g, cor.b, a))
	_brushes[chave] = im
	return im


func _carimbar(img: Image, p: Vector2, brush: Image) -> void:
	var w := brush.get_width()
	img.blend_rect(brush, Rect2i(0, 0, w, w), Vector2i(int(p.x * PX) - w / 2, int(p.y * PX) - w / 2))


## Monta a folha do desenho `n`: papel (com pauta de caderno nos dois primeiros), o caminho pontilhado e a marca de início.
func _preparar(n: int) -> void:
	_dados = dados(n)
	_vel = float(_dados["vel"])
	_construir_caminho()
	_s = 0.0
	_cobertos = 0.0
	cobertura = 0.0
	no_traco = false
	_base = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var papel: Color = _dados["papel"]
	_base.fill(papel)
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + n
	for i in 700:
		var f := 0.94 + 0.06 * rng.randf()
		_base.set_pixel(rng.randi_range(0, TEX_W - 1), rng.randi_range(0, TEX_H - 1), Color(papel.r * f, papel.g * f, papel.b * f, 1.0))
	if bool(_dados["pauta"]):
		for k in 14:
			_base.fill_rect(Rect2i(0, int((26.0 + float(k) * 14.0) * PX), TEX_W, 1), Color(0.7, 0.8, 0.92))
		_base.fill_rect(Rect2i(int(30.0 * PX), 0, 1, TEX_H), Color(0.92, 0.62, 0.64))
	var guia: Color = _dados["guia"]
	var s := 0.0
	while s < _L:
		var traco := _tipo[_idx(s)] == 1
		_carimbar(_base, _ponto_em(s), _brush(guia if traco else guia.lerp(papel, 0.45), 2.9 if traco else 1.5, 0, 0.95))
		s += 3.6 if traco else 9.0
	_carimbar(_base, _P[0], _brush(Color(0.35, 0.75, 0.42), 6.5, 1, 0.9))
	_img.copy_from(_base)
	_sujo = true
	_pos_repouso_para_inicio()
	_pintar_lapis(_cor_traco(0))


func _pos_repouso_para_inicio() -> void:
	if _lapis != null:
		_lapis.position = _posicao_folha(_P[0]) + Vector3(0, LEVANTA, 0)


func _posicao_folha(p: Vector2) -> Vector3:
	return Vector3((p.x - FOLHA_U * 0.5) * UNID, 0.0, (p.y - FOLHA_V * 0.5) * UNID)


# ============================================================================ cenário
func _cor(c: Color, sem_luz := false, emissao := 0.0) -> StandardMaterial3D:
	var chave := "%s|%s|%s" % [c.to_html(true), sem_luz, emissao]
	if not _mats.has(chave):
		_mats[chave] = Ato2Pecas.mat_cor(c, sem_luz, emissao)
	return _mats[chave]


func _montar() -> void:
	ambiente(Color(0.3, 0.32, 0.55), Color(1.0, 0.72, 0.45), Color(0.45, 0.32, 0.25), 0.0, 0.5)
	env.ambient_light_color = Color(0.9, 0.66, 0.48)
	env.ambient_light_energy = LUZ_AMBIENTE
	for c in get_children():
		if c is DirectionalLight3D:
			_sol_luz = c
			_sol_luz.light_energy = 0.3
			_sol_luz.light_color = Color(1.0, 0.76, 0.5)
	_quarto()
	_mobilia()
	_escrivaninha()
	_folha_e_lapis()
	_luminaria()


func _quarto() -> void:
	var madeira := Ato2Pecas.mat_tri("caderno_chao", Color(0.66, 0.5, 0.36), Ato2Pecas.tex_madeira(), 0.7)
	var parede := _cor(Color(0.93, 0.82, 0.6))
	var faixa := _cor(Color(0.74, 0.55, 0.46))
	var forro := _cor(Color(0.9, 0.84, 0.72))
	Construtor.caixa(self, Vector3(9, 0.2, 9), Vector3(0, -0.1, -1.6), madeira, true, "Chao")
	Construtor.caixa(self, Vector3(9, 3.3, 0.2), Vector3(0, 1.65, -4.3), parede, false, "ParedeFundo")
	Construtor.caixa(self, Vector3(0.2, 3.3, 9), Vector3(-4.4, 1.65, -1.6), parede, false)
	Construtor.caixa(self, Vector3(0.2, 3.3, 9), Vector3(4.4, 1.65, -1.6), parede, false)
	Construtor.caixa(self, Vector3(9, 0.2, 9), Vector3(0, 3.3, -1.6), forro, false)
	Construtor.caixa(self, Vector3(9, 3.3, 0.2), Vector3(0, 1.65, 2.8), parede, false)
	Construtor.caixa(self, Vector3(9, 0.9, 0.06), Vector3(0, 0.45, -4.17), faixa, false)      # barrado
	Construtor.caixa(self, Vector3(9, 0.06, 0.1), Vector3(0, 0.92, -4.15), _cor(Color(0.95, 0.9, 0.8)), false)
	# janela do fim de tarde (o brilho laranja é o que acende o quarto)
	var moldura := _cor(Color(0.96, 0.94, 0.9))
	Construtor.caixa(self, Vector3(1.5, 1.3, 0.03), Vector3(2.5, 1.95, -4.18), _cor(Color(1.0, 0.7, 0.36), true), false, "Janela")
	Construtor.caixa(self, Vector3(1.6, 0.08, 0.06), Vector3(2.5, 2.62, -4.15), moldura, false)
	Construtor.caixa(self, Vector3(1.6, 0.08, 0.06), Vector3(2.5, 1.28, -4.15), moldura, false)
	Construtor.caixa(self, Vector3(0.08, 1.42, 0.06), Vector3(1.74, 1.95, -4.15), moldura, false)
	Construtor.caixa(self, Vector3(0.08, 1.42, 0.06), Vector3(3.26, 1.95, -4.15), moldura, false)
	Construtor.caixa(self, Vector3(0.05, 1.3, 0.05), Vector3(2.5, 1.95, -4.14), moldura, false)
	Construtor.caixa(self, Vector3(1.5, 0.05, 0.05), Vector3(2.5, 1.95, -4.14), moldura, false)
	for lado in [-1.0, 1.0]:
		Construtor.caixa(self, Vector3(0.34, 1.6, 0.08), Vector3(2.5 + lado * 1.0, 1.9, -4.1), _cor(Color(0.9, 0.62, 0.58)), false)
	# tapete redondo-ish no chão
	Construtor.caixa(self, Vector3(2.8, 0.02, 1.9), Vector3(0, 0.01, -0.9), _cor(Color(0.55, 0.68, 0.74)), false, "Tapete")


func _mobilia() -> void:
	# cama no canto, com ursinho de pelúcia
	Construtor.caixa(self, Vector3(1.9, 0.35, 1.0), Vector3(-3.2, 0.18, -3.6), _cor(Color(0.55, 0.38, 0.26)), false, "Cama")
	Construtor.caixa(self, Vector3(1.8, 0.2, 0.92), Vector3(-3.2, 0.45, -3.6), _cor(Color(0.55, 0.7, 0.82)), false)
	Construtor.caixa(self, Vector3(0.5, 0.12, 0.7), Vector3(-3.85, 0.62, -3.6), _cor(Color(0.97, 0.94, 0.88)), false)
	var urso := _cor(Color(0.72, 0.5, 0.32))
	Ato2Pecas.malha(self, SphereMesh.new(), Vector3(-3.1, 0.68, -3.6), urso, Vector3.ZERO, Vector3(0.2, 0.2, 0.2))
	Ato2Pecas.malha(self, SphereMesh.new(), Vector3(-3.1, 0.86, -3.6), urso, Vector3.ZERO, Vector3(0.14, 0.14, 0.14))
	# estante com um barquinho de brinquedo e blocos
	Construtor.caixa(self, Vector3(1.6, 0.05, 0.3), Vector3(-0.8, 1.35, -4.12), _cor(Color(0.5, 0.34, 0.22)), false)
	Construtor.caixa(self, Vector3(0.45, 0.1, 0.16), Vector3(-1.25, 1.43, -4.12), _cor(Color(0.78, 0.25, 0.2)), false)
	Construtor.caixa(self, Vector3(0.02, 0.28, 0.02), Vector3(-1.25, 1.62, -4.12), _cor(Color(0.4, 0.28, 0.16)), false)
	Construtor.caixa(self, Vector3(0.16, 0.2, 0.01), Vector3(-1.19, 1.63, -4.12), _cor(Color(0.97, 0.9, 0.5)), false)
	for i in 3:
		Construtor.caixa(self, Vector3(0.14, 0.14, 0.14), Vector3(-0.55 + float(i) * 0.17, 1.45, -4.12), _cor([Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.25)][i]), false)
	# mesa lateral com a caixa de giz de cera e um copo de lápis
	Construtor.caixa(self, Vector3(1.0, 0.75, 0.62), Vector3(2.9, 0.375, -1.5), _cor(Color(0.6, 0.42, 0.3)), false, "MesaLateral")
	Construtor.caixa(self, Vector3(0.44, 0.05, 0.26), Vector3(2.7, 0.78, -1.5), _cor(Color(0.9, 0.8, 0.45)), false)
	var giz := CylinderMesh.new()
	giz.top_radius = 0.022
	giz.bottom_radius = 0.022
	giz.height = 0.22
	giz.radial_segments = 6
	var cores: Array = [Color(0.9, 0.25, 0.22), Color(0.2, 0.5, 0.86), Color(1.0, 0.8, 0.2), Color(0.3, 0.7, 0.4), Color(0.9, 0.5, 0.15)]
	for i in cores.size():
		Ato2Pecas.malha(self, giz, Vector3(3.0 + float(i % 2) * 0.05, 0.795 + float(i) * 0.002, -1.7 + float(i) * 0.07), _cor(cores[i]), Vector3(0, 12.0 * float(i), 90))
	var copo := CylinderMesh.new()
	copo.top_radius = 0.07
	copo.bottom_radius = 0.06
	copo.height = 0.16
	copo.radial_segments = 10
	Ato2Pecas.malha(self, copo, Vector3(3.15, 0.83, -1.3), _cor(Color(0.4, 0.55, 0.7)))
	var lap := CylinderMesh.new()
	lap.top_radius = 0.012
	lap.bottom_radius = 0.012
	lap.height = 0.28
	lap.radial_segments = 5
	for i in 3:
		Ato2Pecas.malha(self, lap, Vector3(3.13 + float(i) * 0.02, 0.98, -1.3), _cor(cores[i]), Vector3(10.0 * float(i - 1), 0, 8.0 * float(i - 1)))


func _escrivaninha() -> void:
	_folha = Node3D.new()
	_folha.name = "Folha"
	_folha.position = PLANTA_POS
	_folha.rotation_degrees.x = INCLINACAO
	add_child(_folha)
	var madeira := _cor(Color(0.5, 0.34, 0.22))
	Construtor.caixa(_folha, Vector3(FOLHA_U * UNID + 0.24, 0.07, FOLHA_V * UNID + 0.24), Vector3(0, -0.04, 0), madeira, false, "Tampo")
	# pernas: altas atrás, baixas na frente
	var perna := _cor(Color(0.4, 0.27, 0.18))
	for lado in [-1.5, 1.5]:
		Construtor.caixa(self, Vector3(0.1, 1.55, 0.1), Vector3(lado, 0.775, -2.62), perna, false)
		Construtor.caixa(self, Vector3(0.1, 0.42, 0.1), Vector3(lado, 0.21, -1.22), perna, false)


func _folha_e_lapis() -> void:
	_img = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.96, 0.92, 0.82))
	_tex = ImageTexture.create_from_image(_img)
	var plano := PlaneMesh.new()
	plano.size = Vector2(FOLHA_U * UNID, FOLHA_V * UNID)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _tex
	mat.albedo_color = Color(0.97, 0.93, 0.88)       # o fim de tarde esquenta o papel
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var papel := Ato2Pecas.malha(_folha, plano, Vector3.ZERO, mat)
	papel.name = "Papel"
	# o lápis de cor: ponta na origem do nó, corpo ao longo de +Y, inclinado como na mão de quem escreve
	_lapis = Node3D.new()
	_lapis.name = "Lapis"
	_folha.add_child(_lapis)
	_lapis_corpo = Node3D.new()
	_lapis.add_child(_lapis_corpo)
	_lapis_corpo.basis = Basis(Quaternion(Vector3.UP, Vector3(0.85, 0.5, 0.25).normalized()))
	_mat_corpo = Ato2Pecas.mat_cor(Color(0.86, 0.26, 0.2))
	_mat_ponta = Ato2Pecas.mat_cor(Color(0.86, 0.26, 0.2))
	var madeira_ponta := _cor(Color(0.93, 0.78, 0.55))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.0
	cone.height = 0.09
	cone.radial_segments = 8
	Ato2Pecas.malha(_lapis_corpo, cone, Vector3(0, 0.045, 0), madeira_ponta)
	var grafite := CylinderMesh.new()
	grafite.top_radius = 0.012
	grafite.bottom_radius = 0.0
	grafite.height = 0.035
	grafite.radial_segments = 8
	Ato2Pecas.malha(_lapis_corpo, grafite, Vector3(0, 0.0175, 0), _mat_ponta)
	var corpo := CylinderMesh.new()
	corpo.top_radius = 0.03
	corpo.bottom_radius = 0.03
	corpo.height = 0.55
	corpo.radial_segments = 6
	Ato2Pecas.malha(_lapis_corpo, corpo, Vector3(0, 0.365, 0), _mat_corpo)
	var anel := CylinderMesh.new()
	anel.top_radius = 0.032
	anel.bottom_radius = 0.032
	anel.height = 0.05
	anel.radial_segments = 8
	Ato2Pecas.malha(_lapis_corpo, anel, Vector3(0, 0.665, 0), _cor(Color(0.75, 0.75, 0.78)))
	var borracha := CylinderMesh.new()
	borracha.top_radius = 0.03
	borracha.bottom_radius = 0.03
	borracha.height = 0.05
	borracha.radial_segments = 8
	Ato2Pecas.malha(_lapis_corpo, borracha, Vector3(0, 0.715, 0), _cor(Color(0.93, 0.6, 0.62)))
	# sombrinha no papel: mostra se o lápis está no ar
	var disco := CylinderMesh.new()
	disco.top_radius = 0.04
	disco.bottom_radius = 0.04
	disco.height = 0.002
	disco.radial_segments = 12
	var msomb := StandardMaterial3D.new()
	msomb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	msomb.albedo_color = Color(0.0, 0.0, 0.0, 0.18)
	msomb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sombra = Ato2Pecas.malha(_folha, disco, Vector3(0, 0.004, 0), msomb)
	_sombra.name = "SombraLapis"


func _pintar_lapis(c: Color) -> void:
	_mat_corpo.albedo_color = c
	_mat_ponta.albedo_color = c.darkened(0.1)


func _luminaria() -> void:
	Construtor.caixa(self, Vector3(0.02, 0.8, 0.02), Vector3(0, 2.9, -1.4), _cor(Color(0.1, 0.08, 0.07)), false)
	var bulbo := SphereMesh.new()
	Ato2Pecas.malha(self, bulbo, Vector3(0, 2.45, -1.4), _cor(Color(1.0, 0.88, 0.6), true), Vector3.ZERO, Vector3(0.18, 0.18, 0.18))
	_lampada = Construtor.luz(self, Vector3(0, 2.3, -1.2), Color(1.0, 0.8, 0.52), LUZ_LAMPADA, 7.5)
	_lampada.name = "Lampada"


## Prende na parede o desenho `n` já pronto (a cópia da folha), com fita amarela.
func _prender(n: int) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.76)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(_img.duplicate())
	m.albedo_color = Color(0.9, 0.86, 0.8)
	var pos := Vector3(-3.0 + float(n - 1) * 1.3, 2.3, -4.16)
	var mi := Ato2Pecas.malha(self, q, pos, m, Vector3(0, 0, (float(n) - 2.0) * 2.5))
	mi.name = "Pregado%d" % n
	Construtor.caixa(mi, Vector3(0.22, 0.06, 0.01), Vector3(0, 0.38, 0.01), _cor(Color(0.95, 0.85, 0.35)), false)
	_pregados.append(mi)


# ============================================================================ luz e movimento
func _process(dt: float) -> void:
	super(dt)
	if _folha == null or _img == null:
		return
	if not _olhou and _desde_inicio > 0.5 and is_instance_valid(player):
		_olhou = true
		create_tween().tween_property(player.cabeca, "rotation:x", -0.3, 0.4)
	segurando = Input.is_action_pressed("interagir") and acao_vale()
	if not terminado and not cancelado:
		if fase == Fase.DESENHAR:
			_avancar(dt)
		elif fase == Fase.VIRADA:
			_avancar_auto(dt)
	_atualizar_lapis(dt)
	if is_instance_valid(_lampada):
		_lampada.light_energy = LUZ_LAMPADA * _nivel_luz
	if env:
		env.ambient_light_energy = LUZ_AMBIENTE * (0.55 + 0.45 * _nivel_luz)
	if _sujo:
		_sujo = false
		_tex.update(_img)


func _luz_nivel(alvo: float, dur: float) -> void:
	create_tween().tween_property(self, "_nivel_luz", alvo, dur)


## O lápis anda sozinho; segurar risca o trecho de traço (e só rabisca nos vazios).
func _avancar(dt: float) -> void:
	var resto := dt * _vel
	while resto > 0.0001 and _s < _L:
		var passo := minf(resto, 1.0)
		var s1 := minf(_s + passo, _L)
		var ds := s1 - _s
		var i := _idx(_s + ds * 0.5)
		if segurando:
			var p := _ponto_em(s1)
			if _tipo[i] == 1:
				_carimbar(_img, p, _brush(_cor_traco(i), R_TINTA * PX, randi() % 3))
				_cobertos += ds
			else:
				_carimbar(_img, p, _brush(Color(0.38, 0.38, 0.44), 1.0 * PX, 3, 0.7))
			_sujo = true
		_s = s1
		resto -= ds
	cobertura = _cobertos / maxf(_total_traco, 0.001)
	no_traco = _s < _L and _tipo[_idx(_s)] == 1


## A parte final, feita sozinha pelo lápis (a virada do desenho 3).
func _avancar_auto(dt: float) -> void:
	if _auto_fim:
		return
	var seg: Dictionary = _auto[_auto_i]
	var rs: PackedVector2Array = seg["rs"]
	_auto_tinta = bool(seg["tinta"])
	_auto_cor = seg["cor"]
	_auto_u += dt * float(seg["vel"])
	var alvo := mini(int(_auto_u), rs.size() - 1)
	var pont: bool = bool(seg["pont"])
	while _auto_k < alvo:
		_auto_k += 1
		if _auto_tinta and (not pont or _auto_k % 6 == 0):
			var raio := 1.3 * PX if pont else 2.1 * PX
			_carimbar(_img, rs[_auto_k], _brush(_auto_cor, raio, randi() % 3))
			pontos_auto += 1
			_sujo = true
	_pos_auto = rs[_auto_k]
	if _auto_k >= rs.size() - 1:
		match str(seg["nome"]):
			"casa":
				casa_longe = _auto_i >= 6
		_auto_i += 1
		_auto_u = 0.0
		_auto_k = 0
		if _auto_i >= _auto.size():
			_auto_fim = true
			_auto_tinta = false
			texto_escrito = "TITO"
		else:
			_pos_auto = (_auto[_auto_i]["rs"] as PackedVector2Array)[0]


func _atualizar_lapis(dt: float) -> void:
	if _lapis == null:
		return
	var pos_u: Vector2
	var baixo := false
	var cor := _auto_cor
	if fase == Fase.VIRADA or fase == Fase.FIM:
		pos_u = _pos_auto
		baixo = _auto_tinta and fase == Fase.VIRADA
	else:
		pos_u = _ponto_em(_s) if _L > 0.0 else Vector2.ZERO
		baixo = segurando and fase == Fase.DESENHAR
		if _L > 0.0:
			cor = _cor_traco(_idx(_s))
	_pintar_lapis(cor)
	_lift = move_toward(_lift, 0.0 if baixo else LEVANTA, dt * 0.9)
	var p := _posicao_folha(pos_u)
	_lapis.position = p + Vector3(0, _lift, 0)
	_sombra.position = p + Vector3(0.02, 0.004, 0.02)
	_sombra.scale = Vector3.ONE * (1.0 + _lift * 4.0)


# ============================================================================ o jogo
func _rodar() -> bool:
	placar("Desenho 0/%d" % TOTAL)
	Audio.ambiente("mar", -22.0, 1.0)
	_preparar(1)
	if not await falar("taina", FALA_INTRO):
		return false
	for n in range(1, TOTAL + 1):
		desenho = n
		placar("Desenho %d/%d" % [n, TOTAL])
		if n > 1:
			_preparar(n)
			if not await esperar(0.9):
				return false
		_dica_riscar()
		fase = Fase.ESPERA
		if not await esperar(1.2):
			return false
		fase = Fase.DESENHAR
		while _s < _L - 0.01:
			if not await esperar(0.1):
				return false
		no_traco = false
		coberturas.append(cobertura)
		if cobertura >= MIN_COBERTURA:
			vencidos += 1
		desenho_pronto.emit(n, cobertura)
		dica("", "")
		if n < TOTAL:
			fase = Fase.COMENTAR
			if not await _comentar(n):
				return false
			_prender(n)
	return await _virada()


func _dica_riscar() -> void:
	dica("Segure o clique ou [E] para riscar o traço, solte nos vazios", "Segure o botão Interagir para riscar o traço, solte nos vazios")


func _comentar(n: int) -> bool:
	var bom := cobertura >= MIN_COBERTURA
	if not await esperar(0.7):
		return false
	var linhas: Array = (FALAS_DESENHO[n] as Dictionary)["bom" if bom else "torto"]
	if not await falar("taina", linhas):
		return false
	_luz_nivel(1.0 - 0.15 * float(n), 1.5)
	return true


## Desenho 3: o jogador solta o lápis no último traço e o lápis continua sozinho.
func _virada() -> bool:
	var t := 0.0
	while segurando and t < 2.5:
		if not await esperar(0.05):
			return false
		t += 0.05
	if not await esperar(1.1):
		return false
	GameState.definir_corruption_manual(0.12)
	_luz_nivel(0.62, 6.0)
	_auto = auto_virada()
	_auto_i = 0
	_auto_u = 0.0
	_auto_k = 0
	_auto_fim = false
	_pos_auto = (_auto[0]["rs"] as PackedVector2Array)[0]
	_auto_cor = (_auto[0] as Dictionary)["cor"]
	fase = Fase.VIRADA
	while not _auto_fim:
		if not await esperar(0.1):
			return false
	fase = Fase.FIM
	if not await esperar(1.2):
		return false
	_prender(TOTAL)
	if not await esperar(1.0):
		return false
	if not await falar("taina", FALA_TITO):
		return false
	return await esperar(0.8)
