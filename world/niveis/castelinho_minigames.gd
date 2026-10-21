class_name MinigamesCastelo
extends RefCounted
## Entradas dos minigames do Módulo 16 dentro do Castelinho (um objeto "Jogar" por minigame, no caminho da visita).
## Cada minigame é uma cena própria (`world/niveis/mini_<id>.tscn`, base `minigame_base.gd`); aqui só vive a PORTA:
##   - um Interagivel com um "!" amarelo que pulsa (some quando o jogador vence);
##   - ao entrar na sala (`ao_entrar(base)`) o mascote avisa uma vez (fala `aviso`) e o Mapa (M) diz o que fazer;
##   - um Marker3D "Spawn_volta_mini_<id>" onde o jogador reaparece quando o minigame acaba ou é pulado.
## Vencer = flag `mini_<id>_feito` (+ pista `pista_mini_<id>` e selo, feitos pela base). Pular não ganha nada e a porta continua.
## Tabela: `visita` (1..4), `sala` = sala BASE (1..22) onde o aviso fala e o Mapa aponta, `pos`/`tam` = onde fica a porta
## no nível (a origem do Interagivel), `volta`/`yaw` = onde o jogador reaparece (de frente para a porta, 1,5 m na frente).
## `epocas` = [] (sempre) ou lista de épocas em que a porta existe (Epocas.marcar). `ativo` = false esconde a porta enquanto
## o minigame não existe. Os fatos usados nos minigames têm fonte em docs/pesquisa/.

const ENTRADAS := {
	"lanchao": {"ativo": true, "visita": 2, "sala": 13, "pos": Vector3(-5.45, 1.5, -15.0), "tam": Vector3(0.9, 1.3, 1.5),
		"texto": "Ler a gravura do barco", "cena": "res://world/niveis/mini_lanchao.tscn",
		"quem": "taina", "aviso": ["Tem uma gravura de barco aqui! Dá vontade de entrar nela..."],
		"mapa": "Jogue o minigame da gravura do barco (Sala do Pescador).",
		"volta": Vector3(-6.95, 0.1, -15.0), "yaw": -90.0, "epocas": [3]},   # parede leste da Sala do Pescador; época 3 = E2020 (museu)
	"quico": {"ativo": true, "visita": 1, "sala": 5, "pos": Vector3(-6.6, 1.4, -6.4), "tam": Vector3(1.9, 1.7, 0.8),
		"texto": "Jogar com o Quico", "cena": "res://world/niveis/mini_quico.tscn",
		"quem": "quico", "aviso": ["PIII! Quer brincar de Quico Diz? É rapidinho!"],
		"mapa": "Jogue Quico Diz com o Quico.",
		"volta": Vector3(-7.66, 0.1, -5.34), "yaw": -45.0, "epocas": [3]},   # gramado entre o deck e a porta (sala 5); 3 = E2020
	"lotes": {"ativo": true, "visita": 3, "sala": 12, "pos": Vector3(-7.3, 1.5, -20.0), "tam": Vector3(1.0, 0.9, 0.6),
		"texto": "Planejar a cidade", "cena": "res://world/niveis/mini_lotes.tscn",
		"quem": "taina", "aviso": ["Um mapa de loteamento! Vamos planejar a cidade-jardim?"],
		"mapa": "Jogue o minigame do mapa de loteamento.",
		"volta": Vector3(-7.3, 0.1, -18.5), "yaw": 0.0, "epocas": [3]},
	# Ponte à noite (Módulo 14, `cidade_ponte.gd` chama `porta_em(self, "ponte")`): visita 0 = não é do Castelinho.
	# Fica no lado oeste, perto do Spawn (0, 50): visível de lá. Quem olha para o oeste (-x) é yaw 90.
	"ponte": {"ativo": true, "visita": 0, "sala": 0, "pos": Vector3(-3.2, 0.95, 46.0), "tam": Vector3(0.9, 1.9, 0.9),
		"texto": "Brincar de um, dois, três, pescador", "cena": "res://world/niveis/mini_ponte.tscn",
		"quem": "taina", "aviso": ["Um balde com lanterna e uma plaquinha! Dá vontade de brincar de um, dois, três..."],
		"mapa": "Brinque de um, dois, três, pescador (balde com lanterna, perto de onde você chegou).",
		"volta": Vector3(-1.7, 0.1, 46.0), "yaw": 90.0, "epocas": []},
	# Rua das casas de veraneio (Módulo 14, `cidade_casas.gd` chama `porta_em(self, "caderno")`): visita 0 = não é do Castelinho.
	# Um caderno aberto num degrau da calçada sul, a ~7 m do Spawn (-24, 0): visível de lá. Quem olha para o sul (+z) é yaw 180.
	"caderno": {"ativo": true, "visita": 0, "sala": 0, "pos": Vector3(-16.6, 0.8, 3.1), "tam": Vector3(1.3, 0.8, 0.9),
		"texto": "Folhear o caderno de desenhos", "cena": "res://world/niveis/mini_caderno.tscn",
		"quem": "taina", "aviso": ["Um caderno de desenhos aberto no degrau! Dá vontade de folhear..."],
		"mapa": "Folheie o caderno de desenhos (no degrau, perto de onde você chegou).",
		"volta": Vector3(-16.6, 0.1, 1.6), "yaw": 180.0, "epocas": []},
}

var _c: Node3D
var _visita := 1
var _portas: Dictionary = {}      # id -> Interagivel
var _avisados: Dictionary = {}


func _init(castelinho: Node3D, visita: int) -> void:
	_c = castelinho
	_visita = visita


func montar() -> void:
	for id: String in ENTRADAS:
		var e: Dictionary = ENTRADAS[id]
		if not bool(e["ativo"]) or int(e["visita"]) != _visita:
			continue
		_portas[id] = porta_em(_c, id)
	if not _portas.is_empty():
		# tira os Callables de níveis já destruídos antes de plugar o novo
		for i in range(Objetivo.extras.size() - 1, -1, -1):
			if not Objetivo.extras[i].is_valid():
				Objetivo.extras.remove_at(i)
		Objetivo.extras.append(objetivo)


## Cria a porta de UM minigame em qualquer nível (o Castelinho usa `montar()`; os lugares da cidade chamam isto no seu
## `_construir`, com `visita` 0 na tabela): Interagivel + "!" amarelo (some ao vencer) + visual + `Spawn_volta_mini_<id>`.
## A cena do minigame volta ao nível de onde saiu (`MiniGameBase.destino` na filha) nesse marcador.
static func porta_em(pai: Node3D, id: String) -> Interagivel:
	var e: Dictionary = ENTRADAS[id]
	var it := Interagivel.new(e["texto"], e["tam"], func(_p: Node) -> void: entrar(id))
	it.name = "Mini_" + id
	it.position = e["pos"]
	pai.add_child(it)
	var marca := Construtor.rotulo(it, "!", Vector3(0, 0.9, 0), 90, Color(1.0, 0.85, 0.2))
	marca.pixel_size = 0.008
	marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marca.no_depth_test = true
	marca.outline_size = 16
	marca.outline_modulate = Color(0.2, 0.05, 0.0)
	marca.name = "Marca"
	match id:
		"quico": _visual_quico(it, Vector3.ZERO, float(e["yaw"]))
		"lanchao": _visual_lanchao(it, Vector3.ZERO)
		"lotes": _visual_lotes(it, Vector3.ZERO)
		"caderno": _visual_caderno(it, Vector3.ZERO)
		"ponte": _visual_ponte(it, Vector3.ZERO)
	var tw := it.create_tween().set_loops()
	tw.tween_property(marca, "position:y", 1.05, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(marca, "position:y", 0.85, 0.5).set_trans(Tween.TRANS_SINE)
	var mk := Marker3D.new()
	mk.name = SPAWN_PREFIXO + id
	mk.position = e["volta"]
	mk.rotation_degrees.y = float(e["yaw"])
	pai.add_child(mk)
	if (e["epocas"] as Array).size() > 0:
		Epocas.marcar(it, e["epocas"])
	marca.visible = not feito(id)
	it.texto_interacao = str(e["texto"]) + (" (de novo)" if feito(id) else "")
	return it


const SPAWN_PREFIXO := "Spawn_volta_mini_"


static func feito(id: String) -> bool:
	return GameState.flag("mini_%s_feito" % id)


static func entrar(id: String) -> void:
	if Transicao.ocupado:
		return
	GameState.set_flag("mini_visitou_" + id, true)
	await Transicao.ir_para(ENTRADAS[id]["cena"], "Spawn")


## O mascote avisa uma vez por visita ao entrar na sala certa (chamado por castelinho.gd `_evento`).
func ao_entrar(base: int) -> void:
	for id: String in _portas:
		var e: Dictionary = ENTRADAS[id]
		if int(e["sala"]) != base or feito(id) or _avisados.has(id):
			continue
		_avisados[id] = true
		await Guia.falar(e["quem"], e["aviso"])


## Mapa da Visita (M): só fala enquanto o jogador está na sala da porta e ainda não venceu, para não esconder o caminho.
func objetivo() -> String:
	if not is_instance_valid(_c):
		return ""
	for id: String in _portas:
		var e: Dictionary = ENTRADAS[id]
		if not feito(id) and GameState.sala_atual == _c.call("_global", int(e["sala"])):
			return e["mapa"]
	return ""


## Visual da porta do Quico: um quadro de avisos de madeira "QUICO DIZ" com um apito grande pendurado, de frente para
## quem chega (`yaw` = o mesmo yaw do jogador na volta). `pai` é o Interagivel (origem = centro do quadro), então tudo
## some junto com ele fora da época do presente.
static func _visual_quico(pai: Node3D, pos: Vector3, yaw: float) -> void:
	var raiz := Node3D.new()
	raiz.name = "VisualQuico"
	raiz.position = pos
	raiz.rotation_degrees.y = yaw
	pai.add_child(raiz)
	var chao := -pai.position.y     # o chão, em coordenadas locais do Interagivel
	var madeira := Ato2Pecas.mat_cor(Color(0.42, 0.28, 0.17))
	var placa := Ato2Pecas.mat_cor(Color(0.98, 0.84, 0.32))
	var apito_mat := Ato2Pecas.mat_cor(Color(0.88, 0.58, 0.2))
	for lado in [-1.0, 1.0]:
		Construtor.caixa(raiz, Vector3(0.12, 0.55 - chao, 0.12), Vector3(lado * 0.8, (chao + 0.55) * 0.5, 0.0), madeira, true)
	Construtor.caixa(raiz, Vector3(1.9, 0.7, 0.08), Vector3(0, 0.1, 0), placa, false, "Quadro")
	var t := Construtor.rotulo(raiz, "QUICO DIZ", Vector3(0, 0.2, 0.05), 64, Color(0.35, 0.1, 0.05))
	t.pixel_size = 0.0052
	var t2 := Construtor.rotulo(raiz, "toque o apito!", Vector3(0, -0.07, 0.05), 40, Color(0.45, 0.2, 0.1))
	t2.pixel_size = 0.0042
	# o apito: corpo cilíndrico deitado e bocal, pendurado por um cordão
	var corpo := CylinderMesh.new()
	corpo.top_radius = 0.17
	corpo.bottom_radius = 0.17
	corpo.height = 0.4
	corpo.radial_segments = 14
	Ato2Pecas.malha(raiz, corpo, Vector3(0.04, -0.52, 0.12), apito_mat, Vector3(0, 0, 90))
	var bocal := BoxMesh.new()
	bocal.size = Vector3(0.28, 0.1, 0.16)
	Ato2Pecas.malha(raiz, bocal, Vector3(-0.3, -0.49, 0.12), apito_mat)
	Construtor.caixa(raiz, Vector3(0.02, 0.3, 0.02), Vector3(0, -0.33, 0.1), Ato2Pecas.mat_cor(Color(0.2, 0.15, 0.1)), false)


## Visual da porta do Lanchão: uma gravura emoldurada na parede leste da Sala do Pescador (virada para o oeste, -90 graus),
## papel envelhecido com o desenho a nanquim de um barco, dois bois e uma corda. `pai` é o Interagivel (origem = centro).
static func _visual_lanchao(pai: Node3D, pos: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "VisualLanchao"
	raiz.position = pos
	raiz.rotation_degrees.y = -90.0
	pai.add_child(raiz)
	var moldura := Construtor.material(Color(0.22, 0.14, 0.09), 0.8)
	Construtor.caixa(raiz, Vector3(1.1, 0.07, 0.05), Vector3(0, 0.4, 0), moldura, false)
	Construtor.caixa(raiz, Vector3(1.1, 0.07, 0.05), Vector3(0, -0.4, 0), moldura, false)
	Construtor.caixa(raiz, Vector3(0.07, 0.87, 0.05), Vector3(-0.515, 0, 0), moldura, false)
	Construtor.caixa(raiz, Vector3(0.07, 0.87, 0.05), Vector3(0.515, 0, 0), moldura, false)
	var papel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.96, 0.73)
	papel.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _textura_gravura_lanchao()
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	papel.material_override = mat
	papel.position = Vector3(0, 0, 0.012)
	papel.name = "Papel"
	raiz.add_child(papel)
	var placa := Construtor.rotulo(raiz, "Lanchão Seival, 1839", Vector3(0, -0.52, 0.02), 30, Color(0.15, 0.1, 0.07))
	placa.pixel_size = 0.0028
	placa.name = "Legenda"


static func _textura_gravura_lanchao() -> Texture2D:
	const W := 192
	const H := 146
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1839
	for y in H:
		for x in W:
			var borda := minf(minf(x, W - 1 - x), minf(y, H - 1 - y)) / 14.0
			var m := 0.84 + rng.randf() * 0.05 - (1.0 - clampf(borda, 0.0, 1.0)) * 0.16
			img.set_pixel(x, y, Color(0.9 * m, 0.82 * m, 0.64 * m))
	var tinta := Color(0.18, 0.12, 0.09)
	# água (linhas onduladas) e margem
	for k in 4:
		for x in range(8, W - 8):
			var yy := 100 + k * 8 + int(sin(x * 0.2 + k) * 2.0)
			if yy < H - 8:
				img.set_pixel(x, yy, tinta.lightened(0.25))
	_linha_g(img, Vector2i(8, 96), Vector2i(W - 8, 96), tinta)
	# lanchão: casco, proa, bancos, mastro curto
	for y in range(76, 92):
		var recuo := (y - 76) / 2
		for x in range(40 + recuo, 112 - recuo / 2):
			img.set_pixel(x, y, tinta.lightened(0.15 if y > 82 else 0.0))
	_linha_g(img, Vector2i(112, 76), Vector2i(124, 70), tinta)
	_linha_g(img, Vector2i(38, 76), Vector2i(126, 76), tinta)
	_linha_g(img, Vector2i(76, 76), Vector2i(76, 40), tinta)
	_linha_g(img, Vector2i(76, 42), Vector2i(98, 74), tinta)
	# dois bois (corpo, pernas, chifres) e a corda esticada até a proa
	for b in 2:
		var x0 := 140 + b * 22
		for y in range(74, 86):
			for x in range(x0, x0 + 18):
				img.set_pixel(x, y, tinta)
		for dx in [1, 5, 12, 16]:
			_linha_g(img, Vector2i(x0 + dx, 86), Vector2i(x0 + dx, 96), tinta)
		_linha_g(img, Vector2i(x0 + 18, 74), Vector2i(x0 + 24, 80), tinta)
		_linha_g(img, Vector2i(x0 + 20, 74), Vector2i(x0 + 22, 68), tinta)
	_linha_g(img, Vector2i(124, 70), Vector2i(140, 78), tinta)
	# três homenzinhos ao lado
	for i in 3:
		var hx := 28 + i * 11
		_linha_g(img, Vector2i(hx, 78), Vector2i(hx, 92), tinta)
		for dy in range(-3, 1):
			img.set_pixel(hx + 1, 74 + dy, tinta)
			img.set_pixel(hx - 1, 74 + dy, tinta)
	return ImageTexture.create_from_image(img)


static func _linha_g(img: Image, a: Vector2i, b: Vector2i, cor: Color) -> void:
	var passos := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in passos + 1:
		var t := float(i) / maxf(passos, 1)
		var p := Vector2(a).lerp(Vector2(b), t)
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, cor)


## Mapa antigo emoldurado na parede (porta do minigame "lotes"): a planta da cidade-jardim vista de cima, numa moldura de
## madeira com plaquinha. `pos` = centro da moldura relativo a `pai` (a origem do Interagivel); a parede fica 0,1 m atrás, em -z.
static func _visual_lotes(pai: Node3D, pos: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "MapaLoteamento"
	raiz.position = pos + Vector3(0, 0, -0.07)
	pai.add_child(raiz)
	var madeira := Ato2Pecas.mat_cor(Color(0.3, 0.19, 0.12))
	var moldura := Construtor.caixa(raiz, Vector3(0.92, 0.62, 0.05), Vector3.ZERO, madeira, false, "Moldura")
	var plano := QuadMesh.new()
	plano.size = Vector2(0.82, 0.512)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = MiniLotes.textura_planta(256, 160)
	mat.roughness = 1.0
	var papel := Ato2Pecas.malha(raiz, plano, Vector3(0, 0, 0.027), mat)
	papel.name = "Papel"
	var placa := Construtor.caixa(raiz, Vector3(0.62, 0.09, 0.03), Vector3(0, -0.39, 0.0), Ato2Pecas.mat_cor(Color(0.78, 0.66, 0.36)), false, "Placa")
	var txt := Construtor.rotulo(placa, "MAPA DE LOTEAMENTO \u2013 1939", Vector3(0, 0, 0.017), 40, Color(0.15, 0.1, 0.05))
	txt.pixel_size = 0.0016
	for n in [moldura, papel, placa, txt]:
		(n as VisualInstance3D).layers = 2     # interior (camada 2): sem o Sol de fora, como o resto do museu


## Porta do minigame da ponte: um balde de pescador com uma lanterna acesa em cima, uma vara encostada e uma plaquinha "PARADO!"
## numa estaca, de frente para quem volta (o jogador olha para -x, então o visual olha para +x: yaw 90). Só caixas e um brilho
## emissivo (sem luz nova: a Ponte tem orçamento de 1 Sol + 5 luzes). `pai` é o Interagivel (origem = 0,95 m do chão).
static func _visual_ponte(pai: Node3D, pos: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "VisualPonte"
	raiz.position = pos
	raiz.rotation_degrees.y = 90.0
	pai.add_child(raiz)
	var chao := -pai.position.y
	var balde_mat := Ato2Pecas.mat_cor(Color(0.2, 0.32, 0.48))
	var madeira := Ato2Pecas.mat_cor(Color(0.4, 0.27, 0.17))
	var ferro := Ato2Pecas.mat_cor(Color(0.1, 0.1, 0.12))
	var balde := CylinderMesh.new()
	balde.top_radius = 0.24
	balde.bottom_radius = 0.19
	balde.height = 0.5
	balde.radial_segments = 10
	balde.rings = 1
	Ato2Pecas.malha(raiz, balde, Vector3(0, chao + 0.25, 0), balde_mat).name = "Balde"
	# a lanterna: caixa emissiva com tampa e alça, e um brilho translúcido em volta (sem OmniLight)
	var topo := chao + 0.5
	Construtor.caixa(raiz, Vector3(0.2, 0.26, 0.2), Vector3(0, topo + 0.13, 0), Ato2Pecas.mat_cor(Color(1.0, 0.8, 0.4), true, 1.6), false, "Lanterna")
	Construtor.caixa(raiz, Vector3(0.24, 0.04, 0.24), Vector3(0, topo + 0.28, 0), ferro, false)
	Construtor.caixa(raiz, Vector3(0.24, 0.04, 0.24), Vector3(0, topo + 0.01, 0), ferro, false)
	var brilho := SphereMesh.new()
	brilho.radius = 0.4
	brilho.height = 0.8
	brilho.radial_segments = 10
	brilho.rings = 5
	Ato2Pecas.malha(raiz, brilho, Vector3(0, topo + 0.14, 0), Ato2Pecas.mat_cor(Color(1.0, 0.78, 0.35, 0.16), true)).name = "Brilho"
	# a vara de pesca encostada no balde
	Construtor.caixa(raiz, Vector3(0.03, 1.9, 0.03), Vector3(-0.32, chao + 0.95, -0.12), madeira, false, "Vara").rotation_degrees.z = 14.0
	# a estaca com a plaquinha "PARADO!" (no nível dos olhos: a leitura vem de longe)
	Construtor.caixa(raiz, Vector3(0.06, 1.45, 0.06), Vector3(0.42, chao + 0.72, 0.05), madeira, false, "Estaca")
	Construtor.caixa(raiz, Vector3(1.0, 0.36, 0.05), Vector3(0.42, chao + 1.4, 0.08), Ato2Pecas.mat_cor(Color(0.96, 0.9, 0.76)), false, "Plaquinha")
	var t := Construtor.rotulo(raiz, "PARADO!", Vector3(0.42, chao + 1.4, 0.115), 64, Color(0.75, 0.1, 0.08))
	t.pixel_size = 0.0034


## Porta do minigame do caderno (Rua das casas): um degrau de concreto na calçada com um caderno de capa mole aberto em cima e
## folhas de desenho coloridas soltas (uma delas no chão, no caminho). Só caixas finas, cores vivas com um pouco de emissivo
## (sem luz nova: a rua tem orçamento de luzes). `yaw` = o do jogador na volta: o caderno fica de frente para quem chega.
## `pai` é o Interagivel (origem = 0,8 m do chão).
static func _visual_caderno(pai: Node3D, pos: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "VisualCaderno"
	raiz.position = pos
	raiz.rotation_degrees.y = float(ENTRADAS["caderno"]["yaw"])
	pai.add_child(raiz)
	var chao := -pai.position.y
	var degrau_h := 0.36
	var topo := chao + degrau_h
	Construtor.caixa(raiz, Vector3(1.0, degrau_h, 0.56), Vector3(0, chao + degrau_h * 0.5, 0), Ato2Pecas.mat_cor(Color(0.72, 0.7, 0.66)), false, "Degrau")
	Construtor.caixa(raiz, Vector3(1.04, 0.04, 0.6), Vector3(0, topo + 0.01, 0), Ato2Pecas.mat_cor(Color(0.8, 0.78, 0.74)), false)
	var capa := Ato2Pecas.mat_cor(Color(0.2, 0.55, 0.8), false, 0.25)
	var papel := Ato2Pecas.mat_cor(Color(0.98, 0.96, 0.9), false, 0.3)
	var y0 := topo + 0.035
	Construtor.caixa(raiz, Vector3(0.7, 0.025, 0.5), Vector3(0, y0, 0), capa, false, "Capa")
	Construtor.caixa(raiz, Vector3(0.32, 0.02, 0.44), Vector3(-0.17, y0 + 0.02, 0), papel, false, "PaginaEsq")
	Construtor.caixa(raiz, Vector3(0.32, 0.02, 0.44), Vector3(0.17, y0 + 0.02, 0.0), papel, false, "PaginaDir")
	# rabiscos de giz nas páginas: sol, casinha e um traço
	var yp := y0 + 0.034
	Construtor.caixa(raiz, Vector3(0.07, 0.006, 0.07), Vector3(-0.25, yp, -0.12), Ato2Pecas.mat_cor(Color(1.0, 0.75, 0.1), false, 0.6), false, "Sol")
	Construtor.caixa(raiz, Vector3(0.12, 0.006, 0.09), Vector3(-0.14, yp, 0.07), Ato2Pecas.mat_cor(Color(0.9, 0.5, 0.15), false, 0.5), false)
	Construtor.caixa(raiz, Vector3(0.14, 0.006, 0.04), Vector3(-0.14, yp, -0.01), Ato2Pecas.mat_cor(Color(0.86, 0.26, 0.2), false, 0.5), false)
	Construtor.caixa(raiz, Vector3(0.22, 0.006, 0.02), Vector3(0.17, yp, 0.14), Ato2Pecas.mat_cor(Color(0.2, 0.5, 0.86), false, 0.5), false)
	Construtor.caixa(raiz, Vector3(0.1, 0.006, 0.1), Vector3(0.2, yp, -0.08), Ato2Pecas.mat_cor(Color(0.3, 0.7, 0.4), false, 0.5), false)
	# folhas soltas, de cores vivas: duas no degrau, uma voando na beira e duas no chão (o caminho até o caderno)
	var folhas: Array = [
		[Color(1.0, 0.55, 0.7), Vector3(0.46, topo + 0.04, 0.12), 18.0, 0.0], [Color(1.0, 0.9, 0.3), Vector3(-0.44, topo + 0.04, 0.16), -24.0, 0.0],
		[Color(0.5, 0.85, 1.0), Vector3(0.62, chao + 0.02, 0.5), 35.0, 0.0], [Color(1.0, 0.7, 0.3), Vector3(-0.3, chao + 0.02, 0.62), -12.0, 0.0],
		[Color(0.7, 1.0, 0.6), Vector3(0.1, chao + 0.02, 0.95), 70.0, 0.0],
	]
	for f: Array in folhas:
		var fl := Construtor.caixa(raiz, Vector3(0.34, 0.006, 0.25), f[1], Ato2Pecas.mat_cor(f[0], false, 0.45), false, "Folha")
		fl.rotation_degrees.y = float(f[2])
	# uma estaca ao lado com três desenhos presos (cores vivas, viradas de lado para ler de longe) e um brilho leve no caderno
	var madeira := Ato2Pecas.mat_cor(Color(0.45, 0.3, 0.18))
	Construtor.caixa(raiz, Vector3(0.05, 1.5, 0.05), Vector3(0.72, chao + 0.75, -0.12), madeira, false, "Estaca")
	var cores_f: Array = [Color(1.0, 0.45, 0.6), Color(1.0, 0.88, 0.25), Color(0.4, 0.8, 1.0)]
	for i in 3:
		var pr := Construtor.caixa(raiz, Vector3(0.36, 0.28, 0.01), Vector3(0.72, chao + 1.38 - float(i) * 0.3, -0.12), Ato2Pecas.mat_cor(cores_f[i], false, 0.6), false, "Desenho%d" % i)
		pr.rotation_degrees.y = 38.0 + float(i) * 22.0
	var brilho := SphereMesh.new()
	brilho.radius = 0.5
	brilho.height = 1.0
	brilho.radial_segments = 10
	brilho.rings = 5
	Ato2Pecas.malha(raiz, brilho, Vector3(0, topo + 0.1, 0), Ato2Pecas.mat_cor(Color(1.0, 0.9, 0.5, 0.12), true)).name = "Brilho"
