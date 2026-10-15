class_name CacasCastelo
extends RefCounted
## Caças dos discos 1967, 1975 e 2019 no Castelinho (módulo 2, parte 2). O Passaporte do 1950 (visita 1) segue em
## castelinho.gd; aqui vive o resto. Tabela de achados e flags: `GameState.CACAS` (flag = prefixo + id).
##
##   1967 (V2, vê com o disco 1950):  3 vestígios da casa original: pilha de pedra grés, o miolo da casa (chaminé grande e
##                                    janela gradeada) e a areia nua sem vizinhos. A vitrine do Acervo só abre com os 3.
##   1975 (V3, vê com o disco 1967):  3 marcas do Tito na obra: o Tito brincando e o buraco no muro (já existiam como
##                                    pistas) e a pazinha na areia. O disco do pedestal só aparece com os 3.
##   2019 (V4, vê com o disco 1975):  3 marcas de altura a lápis, "TITO 6, 7, 8", em salas diferentes. O painel solto só
##                                    se abre com os 3.
##   sem data (porão): `porao.gd` (é outro nível).
##
## Cada achado: Epocas.marcar (só se vê com o disco do Visor certo), brilho que pisca, flag, som, fala curta e o contador
## do HUD. Fatos históricos dos vestígios de 1950: docs/pesquisa/castelinho.md §2.3 (pedra de barco pelo Tramandaí [1];
## "de início era só esse miolo, as torres vieram em momentos diferentes" [1]; foto antiga: núcleo sem torres, chaminé
## grande, janela gradeada, terreno de areia nua quase sem vizinhos [OBS. FOTO]). Nada aqui é inventado como fato.
## Tito é FICTÍCIO; só sugestão, nada de violência.

const E1950 := 0
const E1975 := 1
const E2019 := 2
const E1967 := 4

## Só se geram objetos NOVOS aqui; "tito" e "buraco" da caça do 1975 são as pistas de 1967 de sempre (existente = true).
## `quem` = quem fala ao achar. `dica` = o que se diz quando ainda falta. `pos` = origem do objeto no nível.
const ITENS := {
	E1967: {
		"pedra_gres": {"texto": "Examinar a pilha de pedra", "pos": Vector3(-3.4, 0.0, -13.0), "tam": Vector3(1.5, 1.0, 1.5),
			"interno": false, "quem": "bentinho",
			"fala": ["Uma pilha de pedra grés, na areia!", "A pedra do Castelinho veio de barco pelo rio Tramandaí."],
			"dica": "Uma pilha de pedra brilha na areia, a leste da casa de 1950."},
		"casa_miolo": {"texto": "Examinar a casa original", "pos": Vector3(-6.55, 1.45, -21.45), "tam": Vector3(1.5, 2.9, 0.5),
			"interno": false, "quem": "bentinho",
			"fala": ["A casa de 1950 era só o miolo: sem torres, com uma chaminé grande e uma janelinha gradeada lá no alto.", "As torres vieram depois, em momentos diferentes."],
			"dica": "A casinha de 1950 é só o miolo do prédio. Procure a chaminé grande, nos fundos."},
		"areia_nua": {"texto": "Examinar o terreno vazio", "pos": Vector3(-25.2, 0.0, -2.4), "tam": Vector3(1.0, 1.7, 1.0),
			"interno": false, "quem": "bentinho",
			"fala": ["Areia, só areia! Na foto antiga do museu, a casa aparece num terreno de areia nua, quase sem vizinhos.", "Dá a ideia de como era Imbé nos anos 1950."],
			"dica": "Perto da calçada, na areia do terreno, uma estaca marca o lote vazio."},
	},
	E1975: {
		"tito": {"existente": true, "dica": "O Tito brinca de castelo na areia, perto da casa de 1967. Acene para ele."},
		"buraco": {"existente": true, "dica": "Tem um buraco do tamanho de uma criança no muro da obra, perto da calçada."},
		"balde": {"texto": "Examinar a pazinha", "pos": Vector3(-17.0, 0.0, -7.2), "tam": Vector3(1.0, 0.8, 1.0),
			"interno": false, "quem": "sistema",
			"fala": ["Uma pazinha amarela e um baldinho azul, esquecidos na areia da obra.", "Do tamanho certo para um menino."],
			"dica": "Brinquedos de criança ficaram na areia, ao pé da Torre A."},
	},
	E2019: {
		"tito_6": {"texto": "Olhar o risco na parede", "pos": Vector3(-11.6, 1.0, -20.06), "yaw": 0.0, "n": 6,
			"tam": Vector3(1.0, 0.8, 0.5), "interno": true, "quem": "???",
			"fala": ["Um risco de lápis na parede: \"TITO 6\".", "Alguém media o menino aqui."],
			"dica": "Uma marca de lápis está na parede do Salão de Arte."},
		"tito_7": {"texto": "Olhar o risco na parede", "pos": Vector3(-16.53, 1.08, -27.6), "yaw": 90.0, "n": 7,
			"tam": Vector3(0.5, 0.8, 1.0), "interno": true, "quem": "???",
			"fala": ["\"TITO 7\". O risco está mais alto.", "Ele crescia, ano a ano, dentro deste prédio."],
			"dica": "Uma marca de lápis está na parede da Sala Medieval."},
		"tito_8": {"texto": "Olhar o risco na parede", "pos": Vector3(-24.55, 1.16, -17.8), "yaw": 90.0, "n": 8,
			"tam": Vector3(0.5, 0.8, 1.0), "interno": true, "quem": "???",
			"fala": ["\"TITO 8\". Mais um risco, mais alto.", "A letra é de criança."],
			"dica": "Uma marca de lápis está na parede da sala do Meio Ambiente."},
	},
}

## Contagem por disco ("Vestígio 2 de 3!") e a fala do 3º achado, que aponta para onde está o disco.
const UNIDADE := {E1967: "Vestígio", E1975: "Marca", E2019: "Medida"}
const FIM := {
	E1967: ["Três vestígios de 1950! Agora sim.", "Volte à vitrine do Acervo, depois do Salão de Arte: ela deve abrir."],
	E1975: ["As marcas se juntam: pezinhos saem do buraco no muro, passam pela pazinha e vão até a Torre A.", "No topo da torre, alguma coisa brilha."],
	E2019: ["Seis, sete, oito. E depois a régua para de subir.", "O resto ficou na Sala dos Povos Originários, atrás do painel torto."],
}
const QUEM_FIM := {E1967: "bentinho", E1975: "sistema", E2019: "???"}
## O que o jogador precisa fazer (usado nas falas de "falta"): o disco do Visor e a tecla dele.
const COMO := {E1967: "Aperte 1 e Q (disco de 1950).", E1975: "Aperte 2 e Q (disco de 1967).", E2019: "Aperte 3 e Q (disco de 1975)."}

var n: Node3D                 # o nível (castelinho.gd)
var visita: int
var itens := {}               # "<disco>:<id>" -> [raiz, interagível]
var _t := 0.0
var _trilha: Node3D


func _init(nivel: Node3D, v: int) -> void:
	n = nivel
	visita = v


## Cria os objetos que faltam das caças já abertas nesta visita (e ainda não achados). Só os objetos novos: o Tito
## brincando e o buraco ficam no `_montar_epoca_1967` do nível, que chama `achar()`.
func montar() -> void:
	for d in ITENS:
		if GameState.discos.has(d) or visita < int(GameState.CACAS[d]["visita"]):
			continue
		for id in ITENS[d]:
			var info: Dictionary = ITENS[d][id]
			if info.get("existente", false) or GameState.caca_tem(d, id):
				continue
			_criar(d, id, info)
	if visita >= 3 and GameState.caca_completa(E1975) and not GameState.discos.has(E1975):
		trilha_ate_torre()


func _criar(d: int, id: String, info: Dictionary) -> void:
	var raiz := Node3D.new()
	raiz.name = "Caca_%d_%s" % [d, id]
	raiz.position = info["pos"]
	raiz.rotation_degrees.y = float(info.get("yaw", 0.0))
	var modelo := _modelo(id, info)
	modelo.name = "Modelo"
	raiz.add_child(modelo)
	var brilho := Sprite3D.new()
	brilho.name = "Brilho"
	brilho.texture = n._tex_brilho()
	brilho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	brilho.shaded = false
	brilho.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	brilho.pixel_size = 0.02 if id == "casa_miolo" else 0.014
	brilho.position = _pos_brilho(id)
	brilho.modulate = Color(1.0, 0.9, 0.35) if d != E2019 else Color(0.8, 0.9, 1.0)
	raiz.add_child(brilho)
	n.add_child(raiz)
	if info.get("interno", false):
		n._camada_interna(raiz)
	var ep := _epoca_que_mostra(d)
	Epocas.marcar(raiz, [ep])
	var it := Interagivel.new(info["texto"], info["tam"], Callable())
	it.name = "InterCaca_%d_%s" % [d, id]
	it.position = _pos_interagivel(id, info)
	it.acao = func(_p: Node) -> void: achar(d, id)
	n.add_child(it)
	Epocas.marcar(it, [ep])
	itens["%d:%s" % [d, id]] = [raiz, it]


## A época em que o objeto aparece = a do disco anterior da caça.
static func _epoca_que_mostra(d: int) -> int:
	return int(GameState.CACAS[d]["previo"])


## O brilho fica acima do objeto (a chaminé e a estaca são altas; as marcas na parede ficam coladas nela).
static func _pos_brilho(id: String) -> Vector3:
	match id:
		"casa_miolo":
			return Vector3(0, 0.3, -0.25)
		"areia_nua":
			return Vector3(0.12, 1.3, 0.0)
		"pedra_gres":
			return Vector3(0.3, 0.75, 0.2)
		"balde":
			return Vector3(0.1, 0.5, 0.1)
		_:
			return Vector3(0.0, 0.25, 0.08)        # as marcas de altura


func _pos_interagivel(id: String, info: Dictionary) -> Vector3:
	var p: Vector3 = info["pos"]
	match id:
		"pedra_gres":
			return p + Vector3(0, 0.45, 0)
		"areia_nua":
			return p + Vector3(0, 0.85, 0)
		"balde":
			return p + Vector3(0, 0.35, 0)
		"casa_miolo":
			return p
		_:
			# marca na parede: o Interagivel fica na frente dela (~20 cm), para o raio bater nele antes da parede
			var b := Basis.from_euler(Vector3(0, deg_to_rad(float(info["yaw"])), 0))
			return p + b * Vector3(0, 0, 0.2)


# ---------------------------------------------------------------- achar
## O jogador achou o objeto `id` da caça de `d`. Registra, avisa e, no 3º, aponta para o disco. Idempotente.
## `dizer_fato` = false nos itens que já têm fala própria (o Tito brincando e o buraco, que são pistas).
## Achados de uma visita ANTERIOR à da caça não contam (o Tito e o buraco existem desde a visita 2).
func achar(d: int, id: String, dizer_fato := true) -> void:
	if not GameState.CACAS.has(d) or GameState.visita < int(GameState.CACAS[d]["visita"]) or GameState.caca_tem(d, id):
		return
	var info: Dictionary = ITENS[d][id]
	var chave := "%d:%s" % [d, id]
	for no in itens.get(chave, []):
		if is_instance_valid(no):
			(no as Node).queue_free()
	itens.erase(chave)
	GameState.caca_achar(d, id)
	Audio.sfx("selo")
	Efeitos.flash(0.2, Color(1, 0.95, 0.6), 0.3)
	var achados := GameState.caca_achados(d)
	var total := GameState.caca_total(d)
	var linhas: Array = []
	if dizer_fato and info.has("fala"):
		linhas = (info["fala"] as Array).duplicate()
	linhas.append("%s %d de %d!" % [UNIDADE[d], achados, total])
	var completa := achados >= total
	if completa:
		linhas.append_array(FIM[d])
		n._caca_completa(d)       # o efeito (disco que aparece, pegadas) acontece já; a fala vem junto
	var quem: String = str(info.get("quem", QUEM_FIM[d]))
	if completa:
		quem = QUEM_FIM[d]
	await Guia.falar(quem, linhas)


## Fala "ainda não": quantos faltam e a dica do primeiro que falta (ordem da tabela).
func falta_fala(d: int, abertura: String) -> void:
	var falta := GameState.caca_faltam(d)
	if falta.is_empty():
		return
	var info: Dictionary = ITENS[d][falta[0]]
	var quem: String = QUEM_FIM[d]
	if quem == "bentinho":
		quem = "sistema"
	var unid := String(UNIDADE[d]).to_lower()
	var plural := falta.size() > 1
	await Guia.falar(quem, [abertura, "Falta%s %d %s%s. %s" % ["m" if plural else "", falta.size(), unid, "s" if plural else "", info["dica"]], COMO[d]])


## Convite no começo da visita (sala 1): o contador do HUD já está na tela.
func lancar() -> void:
	match GameState.caca_ativa():
		E1967:
			await Guia.falar("bentinho", ["Hoje a visita tem um desafio!", "Ache 3 vestígios de 1950. Aperte 1 e depois Q: o que sobrou da casa original brilha no terreno."])
		E1975:
			await Guia.falar("sistema", ["Aviso: itens de 1967 ainda estão no terreno.", "Aperte 2 e Q e procure 3 marcas de criança."])
		E2019:
			await Guia.falar("???", ["Ele media a altura nas paredes.", "Aperte 3 e Q. Procure 3 medidas."])


# ---------------------------------------------------------------- animação
func animar(dt: float) -> void:
	_t += dt
	for k in itens:
		var raiz: Node3D = itens[k][0]
		if not is_instance_valid(raiz) or not raiz.visible:
			continue
		var b := raiz.get_node_or_null("Brilho") as Sprite3D
		if b:
			var f := pow(maxf(0.0, sin(_t * 2.2 + float(k.length()))), 4.0)
			b.scale = Vector3.ONE * (0.5 + 0.9 * f)
			b.rotation.z = _t * 1.5


# ---------------------------------------------------------------- modelos
func _modelo(id: String, info: Dictionary) -> Node3D:
	var r := Node3D.new()
	match id:
		"pedra_gres":
			_pilha_de_pedra(r)
		"areia_nua":
			_estaca(r)
		"balde":
			_pazinha(r)
		"casa_miolo":
			pass                        # o objeto é a própria chaminé de 1950 (só o brilho e o Interagivel)
		_:
			_marca_de_altura(r, int(info["n"]))
	return r


## Pilha de blocos de pedra grés (ferrugem/salmão, como os blocos do prédio), 3 + 2 + 1, levemente tortos.
func _pilha_de_pedra(r: Node3D) -> void:
	var cores := [Color(0.72, 0.4, 0.3), Color(0.66, 0.36, 0.27), Color(0.78, 0.46, 0.34), Color(0.6, 0.34, 0.26)]
	var k := 0
	for fileira in [[Vector3(-0.42, 0.0, -0.1), Vector3(0.0, 0.0, 0.0), Vector3(0.42, 0.0, 0.08)],
			[Vector3(-0.2, 0.22, -0.04), Vector3(0.22, 0.22, 0.04)], [Vector3(0.0, 0.44, 0.0)]]:
		for pos in fileira:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.46, 0.22, 0.3)
			n._peca(r, bm, cores[k % cores.size()], (pos as Vector3) + Vector3(0, 0.11, 0), Vector3(0, 6.0 * float(k % 3) - 6.0, 0))
			k += 1
	# um bloco solto na areia, ao lado
	var solto := BoxMesh.new()
	solto.size = Vector3(0.4, 0.2, 0.26)
	n._peca(r, solto, cores[1], Vector3(0.78, 0.1, 0.3), Vector3(0, 34, 0))


## Estaca de madeira com um pano vermelho amarrado: o marco do lote vazio.
func _estaca(r: Node3D) -> void:
	var haste := BoxMesh.new()
	haste.size = Vector3(0.07, 1.25, 0.07)
	n._peca(r, haste, Color(0.45, 0.32, 0.2), Vector3(0, 0.62, 0), Vector3(0, 12, 3))
	var pano := BoxMesh.new()
	pano.size = Vector3(0.26, 0.14, 0.012)
	n._peca(r, pano, Color(0.85, 0.12, 0.1), Vector3(0.12, 1.1, 0.0), Vector3(0, 0, -8))
	var monte := SphereMesh.new()
	monte.radius = 0.2
	monte.height = 0.14
	monte.radial_segments = 8
	monte.rings = 3
	n._peca(r, monte, Color(0.86, 0.78, 0.6), Vector3(0, 0.0, 0))


## Pazinha amarela espetada na areia e baldinho azul de lado (brinquedo do Tito).
func _pazinha(r: Node3D) -> void:
	var cabo := BoxMesh.new()
	cabo.size = Vector3(0.035, 0.34, 0.035)
	n._peca(r, cabo, Color(0.95, 0.8, 0.12), Vector3(0, 0.2, 0), Vector3(0, 0, 14))
	var pa := BoxMesh.new()
	pa.size = Vector3(0.14, 0.015, 0.16)
	n._peca(r, pa, Color(0.95, 0.8, 0.12), Vector3(-0.05, 0.03, 0), Vector3(0, 0, 14))
	var balde := CylinderMesh.new()
	balde.top_radius = 0.1
	balde.bottom_radius = 0.075
	balde.height = 0.16
	balde.radial_segments = 8
	balde.rings = 1
	n._peca(r, balde, Color(0.2, 0.45, 0.88), Vector3(0.28, 0.09, 0.12), Vector3(0, 0, 80))
	var monte := SphereMesh.new()
	monte.radius = 0.16
	monte.height = 0.1
	monte.radial_segments = 8
	monte.rings = 2
	n._peca(r, monte, Color(0.86, 0.78, 0.6), Vector3(0, -0.02, 0))


## Risco horizontal de lápis com um tracinho de "régua" e o texto "TITO n" (a face aponta para +Z local do nó).
func _marca_de_altura(r: Node3D, num: int) -> void:
	var grafite := Color(0.2, 0.2, 0.28)
	var risco := BoxMesh.new()
	risco.size = Vector3(0.5, 0.014, 0.006)
	n._peca(r, risco, grafite, Vector3(0, 0, 0.003))
	var tick := BoxMesh.new()
	tick.size = Vector3(0.014, 0.1, 0.006)
	n._peca(r, tick, grafite, Vector3(-0.25, 0.043, 0.003))
	var l := Label3D.new()
	l.text = "TITO %d" % num
	l.font_size = 30
	l.pixel_size = 0.0045
	l.modulate = grafite
	l.outline_size = 0
	l.double_sided = false
	l.position = Vector3(0.0, 0.1, 0.006)
	r.add_child(l)


# ---------------------------------------------------------------- depois do 3º achado (1975): pegadas até a Torre A
## Pezinhos de criança só em 1967: saem do buraco no muro, passam pela pazinha e vão até o pé da Torre A.
## (O buraco já deixa passar em 1967: o caminho a pé até a torre vale; subir nela, só no presente.)
func trilha_ate_torre() -> void:
	if _trilha != null:
		return
	_trilha = Node3D.new()
	_trilha.name = "PegadasAteATorre1967"
	n.add_child(_trilha)
	var pts: Array[Vector3] = [Vector3(-21.6, 0.012, -1.6), Vector3(-17.4, 0.012, -6.6), Vector3(-16.5, 0.012, -10.2)]
	var passos := 9
	for i in passos:
		var f := float(i) / float(passos - 1)
		var a: Vector3 = _no_caminho(pts, f)
		var dir: Vector3 = _no_caminho(pts, minf(f + 0.06, 1.0)) - a
		if dir.length() < 0.01:
			dir = pts[2] - pts[1]
		dir = dir.normalized()
		var esquerdo: bool = i % 2 == 0
		var pos := a + Vector3(-dir.z, 0, dir.x) * 0.09 * (-1.0 if esquerdo else 1.0)
		_trilha.add_child(Pegada.criar(pos, dir, esquerdo, 0.3, 1.35))
	Epocas.marcar(_trilha, [E1967])


static func _no_caminho(pts: Array[Vector3], f: float) -> Vector3:
	if f < 0.5:
		return pts[0].lerp(pts[1], f * 2.0)
	return pts[1].lerp(pts[2], (f - 0.5) * 2.0)
