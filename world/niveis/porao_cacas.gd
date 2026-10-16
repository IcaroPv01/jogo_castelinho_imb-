class_name PoraoCacas
extends RefCounted
## Caça do disco SEM DATA (módulo 2, parte 2): 3 desenhos de giz do Tito que ainda restam em 2019, em 3 salas do porão
## antes do quarto (82, 85 e 88). Só se veem com o disco de 2019 (tecla 4, Q). O disco do quarto (sala 95) só aparece
## com os 3. Tabela de flags: `GameState.CACAS[ESEMDATA]` (caca_semdata_<id>).
## As salas do porão fecham atrás do jogador (one-way): se faltar algum desenho ao chegar no quarto, os que faltam
## aparecem também na parede do quarto, para a caça sempre poder ser terminada (nada trava).
## Tom: triste. Tito é FICTÍCIO; só sugestão.

const SalasGd := preload("res://world/niveis/porao_salas.gd")
const CastelinhoGd := preload("res://world/niveis/castelinho.gd")
const E2019 := 2
const SEMDATA := 5
const IDX_QUARTO := 14

## idx da sala -> {id, pos local, normal, desenho (textura 1..7), fala}
const ITENS := {
	1: {"id": "desenho_a", "pos": Vector3(-1.68, 1.45, -7.0), "normal": Vector3.RIGHT, "n": 2,
		"fala": "Um menino e a mãe, de mãos dadas na praia. O giz já desbotou."},
	4: {"id": "desenho_b", "pos": Vector3(2.98, 1.5, -3.8), "normal": Vector3.LEFT, "n": 4,
		"fala": "Um menino pequeno debaixo de um castelo enorme. O castelo é maior do que ele."},
	7: {"id": "desenho_c", "pos": Vector3(-2.48, 1.5, -3.0), "normal": Vector3.RIGHT, "n": 1,
		"fala": "Uma casinha com a janela acesa. Assinado: TITO, com o T ao contrário."},
}
## Onde os desenhos que faltam reaparecem no quarto (parede direita, antes da cama).
const RESERVA_Z := {"desenho_a": -4.6, "desenho_b": -5.6, "desenho_c": -6.6}
const FIM := "Os desenhos acabam aqui. O último mostra uma porta e uma cama pequena: o quarto dele fica adiante."
const COMO := "Pela lente do disco de 2019 (tecla 4, e Q), ainda há desenhos de giz nas paredes."


## Chamado por `porao._criar_extras(c)` ao montar cada sala.
static func criar(nivel: Node, c) -> void:
	if GameState.caca_completa(SEMDATA):
		return
	if ITENS.has(c.idx):
		var d: Dictionary = ITENS[c.idx]
		if not GameState.caca_tem(SEMDATA, d["id"]):
			_item(nivel, c, d["id"], d["pos"], d["normal"], d["n"], d["fala"])
	elif c.idx == IDX_QUARTO:
		var w: float = c.w
		for k in ITENS:
			var d: Dictionary = ITENS[k]
			if GameState.caca_tem(SEMDATA, d["id"]):
				continue
			_item(nivel, c, d["id"], Vector3(w * 0.5 - 0.02, 1.5, RESERVA_Z[d["id"]]), Vector3.LEFT, d["n"], d["fala"])


static func _item(nivel: Node, c, id: String, pos: Vector3, normal: Vector3, n: int, fala: String) -> void:
	var raiz := Node3D.new()
	raiz.name = "Caca_%s" % id
	c.raiz.add_child(raiz)
	var q := SalasGd.quadro(c, SalasGd.tex_desenho(n), pos, normal, 0.9, 0.68, -2.0)
	q.reparent(raiz, true)
	var brilho := Sprite3D.new()
	brilho.name = "Brilho"
	brilho.texture = CastelinhoGd._tex_brilho()
	brilho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	brilho.shaded = false
	brilho.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	brilho.pixel_size = 0.022
	brilho.modulate = Color(0.8, 0.9, 1.0)
	brilho.position = pos + normal * 0.12 + Vector3(0, 0.38, 0)
	raiz.add_child(brilho)
	var feixe := FeixeCaca.criar(1.5, Color(0.8, 0.9, 1.0), 0.7)       # sala baixa: o feixe sobe do desenho até o teto
	feixe.position = pos + normal * 0.25 + Vector3(0, 0.3, 0)
	raiz.add_child(feixe)
	FeixeCaca.registrar(raiz, SEMDATA, id)
	var it := Interagivel.new("Olhar o desenho", Vector3(0.9, 0.9, 0.9) + Vector3(absf(normal.x), 0, absf(normal.z)) * -0.4, Callable())
	it.name = "InterCaca_%s" % id
	it.position = pos + normal * 0.3
	it.acao = func(_p: Node) -> void: achar(nivel, c, id, fala)
	c.raiz.add_child(it)
	c.interativos.append(it)
	Epocas.marcar(raiz, [E2019])
	Epocas.marcar(it, [E2019])
	var tw := brilho.create_tween().set_loops()       # o tween morre junto com o brilho
	tw.tween_property(brilho, "scale", Vector3.ONE * 1.8, 0.9)
	tw.tween_property(brilho, "scale", Vector3.ONE * 0.8, 0.9)
	var mat := feixe.material_override as StandardMaterial3D
	var tf := feixe.create_tween().set_loops()
	tf.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.55, 0.95, 1.1)
	tf.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.95, 0.55, 1.1)


static func achar(nivel: Node, c, id: String, fala: String) -> void:
	if not GameState.caca_achar(SEMDATA, id):
		return
	for no in [c.raiz.get_node_or_null("Caca_" + id), c.raiz.find_child("InterCaca_" + id, false, false)]:
		if is_instance_valid(no):
			(no as Node).queue_free()
	Audio.sfx("selo")
	var n := GameState.caca_achados(SEMDATA)
	var total := GameState.caca_total(SEMDATA)
	if n >= total:
		nivel._mostrar_legenda("%s  (Desenho %d de %d)\n%s" % [fala, n, total, FIM], 7.0, 2)
		revelar_disco(nivel)
	else:
		nivel._mostrar_legenda("%s  (Desenho %d de %d)" % [fala, n, total], 4.5, 2)


## O disco do quarto aparece (o Interagivel só nasce com os 3 achados).
static func revelar_disco(nivel: Node) -> void:
	if not nivel.salas.has(IDX_QUARTO) or GameState.Epoca.ESEMDATA in GameState.discos:
		return
	var c = nivel.salas[IDX_QUARTO]
	if c.raiz.find_child("InteragivelDisco", false, false) != null:
		return
	var disco = c.raiz.get_node_or_null("Disco")
	if disco:
		disco.visible = true
	var di := Interagivel.new("Pegar o disco", Vector3(0.5, 0.4, 0.5), nivel._pegar_disco.bind(c))
	di.position = c.pontos["disco"]
	di.name = "InteragivelDisco"
	c.raiz.add_child(di)
	c.interativos.append(di)


## Números GLOBAIS das salas do porão onde ainda falta um desenho (para o mapa/objetivo). Quem já chegou ao quarto (as salas
## fecham atrás): os que faltam estão na parede do quarto (sala 81 + IDX_QUARTO).
static func salas_faltando(d: int) -> Array:
	var r: Array = []
	if d != SEMDATA:
		return r
	var quarto: int = GameState.PRIMEIRA_SALA_PORAO + IDX_QUARTO
	for k in ITENS:
		if GameState.caca_tem(SEMDATA, ITENS[k]["id"]):
			continue
		var sala: int = GameState.PRIMEIRA_SALA_PORAO + int(k)
		if GameState.sala_atual >= quarto or GameState.sala_atual > sala:
			sala = quarto
		if not r.has(sala):
			r.append(sala)
	r.sort()
	return r


## Chamado por `porao._ao_entrar_sala(i)`: a dica do Visor na sala 82 e o aviso dos desenhos do quarto.
static func ao_entrar(nivel: Node, i: int) -> void:
	if GameState.caca_completa(SEMDATA) or not GameState.discos.has(E2019):
		return
	if i == 1 and not GameState.flag("caca_semdata_dica"):
		GameState.set_flag("caca_semdata_dica", true)
		nivel._mostrar_legenda(COMO, 5.0, 2)
	elif i == IDX_QUARTO and not GameState.flag("caca_semdata_reserva"):
		GameState.set_flag("caca_semdata_reserva", true)
		nivel._mostrar_legenda("Os desenhos que ficaram para trás estão aqui, na parede do quarto.", 5.0, 2)
