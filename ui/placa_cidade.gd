class_name PlacaCidade
extends CanvasLayer
## PLACA DA PREFEITURA (fictícia) NA CALÇADA: o "roteiro da cidade" do Módulo 14. É o folheto do "Programa Municipal de Memória
## Interativa" (mesmo estilo do Mapa da Visita, `ui/mapa.gd`) com os 5 lugares de `GameState.CIDADE` e o estado de cada um:
## FECHADO ("abre depois da Visita N"), ABERTO ou FEITO. Escolhe-se com clique/toque ou as teclas 1 a 5; ao escolher vai para a cena
## do lugar (`Transicao.ir_para(cena, "Spawn")`). Fecha com Esc, E ou o botão Fechar. Funciona no celular (só controles de interface,
## sem teclas). Enquanto está aberta liga `ui_aberta` (Flash.abrir_ui) e trava o jogador.
##
##   PlacaCidade.abrir()                  abre (devolve a PlacaCidade, ou null se não pode agora)     PlacaCidade.atual
##   PlacaCidade.abrir(true)              pula as checagens (testes)
##   placa.escolher(i)                    escolhe a linha i (0..4 = teclas 1..5); true se foi para o lugar
##   placa.fechar()                       fecha
##   PlacaCidade.estado(id)               "fechado" | "aberto" | "feito"
##   PlacaCidade.montar_3d(pai, pos, yaw) a placa de verdade na calçada (poste + tabuleta + Interagivel "E"); usada em castelinho.gd
##
## A prefeitura é FICTÍCIA ("Programa Municipal de Memória Interativa"): não representa a Prefeitura de Imbé.

signal escolheu(id: String)

const CAMADA := 42
const GUARDA_MS := 400          # o clique emulado que abriu a placa não pode fechá-la (nem escolher) na hora
const TINTA := Flash.NAVY
const PAPEL := Color("F1E4C3")
const SALA_NORMAL := Color("FFFCEF")
const SALA_VISTA := Color("D0EBBD")
const SALA_FECHADA := Color("DCCB9C")
const SALA_AQUI := Color("C3E2FF")
const VERDE_ESCURO := Color("2F8F2A")
const LARG := 960.0
const ALT := 704.0

static var atual: PlacaCidade = null

var linhas: Array[Dictionary] = []      # {id, estado, botao, texto_estado}
var _fechado := false
var _aberto_ms := 0
var _fundo: ColorRect
var _folha: Panel
var _aviso: Label


# ================================================================ API estática
static func estado(id: String) -> String:
	if GameState.cidade_feita(id):
		return "feito"
	return "aberto" if GameState.cidade_aberta(id) else "fechado"


## "abre depois da Visita 2" / "aberto" / "feito".
static func texto_estado(id: String) -> String:
	match estado(id):
		"feito":
			return "FEITO"
		"aberto":
			return "ABERTO"
	return "abre depois da Visita %d" % int(GameState.CIDADE[id]["depois_da_visita"])


static func pode_abrir() -> bool:
	if atual != null and is_instance_valid(atual):
		return false
	if not GameState.jogando or GameState.flag("ui_aberta"):
		return false
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or arv.paused:
		return false
	var p := arv.get_first_node_in_group("player")
	if p and ("pode_mover" in p) and not bool(p.get("pode_mover")):
		return false
	return not Guia.bloqueando()


## Abre a placa. `forcar` pula as checagens (testes). Devolve null se não pôde.
static func abrir(forcar := false) -> PlacaCidade:
	if atual != null and is_instance_valid(atual):
		return atual
	if not forcar and not pode_abrir():
		return null
	var p := PlacaCidade.new()
	atual = p
	Flash.raiz().add_child.call_deferred(p)
	return p


# ================================================================ ciclo de vida
func _ready() -> void:
	layer = CAMADA
	name = "PlacaCidade"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_aberto_ms = Time.get_ticks_msec()
	Flash.abrir_ui()
	Audio.sfx("clique", -6.0, 1.3)


func _exit_tree() -> void:
	if not _fechado:
		_fechado = true
		Flash.fechar_ui()
	if atual == self:
		atual = null


func _process(_dt: float) -> void:
	if not GameState.jogando:
		fechar()


func fechar() -> void:
	if _fechado:
		return
	_fechado = true
	if atual == self:
		atual = null
	Audio.sfx("clique", -6.0, 0.9)
	Flash.fechar_ui()
	queue_free()


## Escolhe a linha `i` (0..4). Fechado: aviso e nada mais. Aberto/feito: fecha o folheto e vai para a cena do lugar.
func escolher(i: int) -> bool:
	if _fechado or i < 0 or i >= linhas.size():
		return false
	var id: String = linhas[i]["id"]
	if estado(id) == "fechado":
		_aviso.text = "Ainda fechado: abre depois da Visita %d." % int(GameState.CIDADE[id]["depois_da_visita"])
		Audio.sfx("erro", -8.0)
		return false
	var cena: String = GameState.CIDADE[id]["cena"]
	if not ResourceLoader.exists(cena):
		_aviso.text = "Este lugar ainda não foi instalado."
		Audio.sfx("erro", -8.0)
		return false
	_fechado = true
	if atual == self:
		atual = null
	Audio.sfx("clique", -4.0, 1.1)
	Flash.fechar_ui()
	escolheu.emit(id)
	queue_free()
	Transicao.ir_para(cena, "Spawn")     # sem await: a placa some e a troca de nível segue
	return true


# ================================================================ montagem
func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.name = "Fundo"
	_fundo.color = Color(TINTA, 0.68)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_folha = Panel.new()
	_folha.name = "Folha"
	_folha.anchor_left = 0.5
	_folha.anchor_right = 0.5
	_folha.anchor_top = 0.5
	_folha.anchor_bottom = 0.5
	_folha.offset_left = -LARG * 0.5
	_folha.offset_right = LARG * 0.5
	_folha.offset_top = -ALT * 0.5
	_folha.offset_bottom = ALT * 0.5
	_folha.mouse_filter = Control.MOUSE_FILTER_STOP
	_folha.add_theme_stylebox_override("panel", Flash.caixa(PAPEL, TINTA, 10, 5, true))
	add_child(_folha)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 30)
	margem.add_theme_constant_override("margin_top", 16)
	margem.add_theme_constant_override("margin_bottom", 16)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(coluna)

	coluna.add_child(_rotulo("PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA", Flash.fonte_texto(), 20, Color(TINTA, 0.75)))
	coluna.add_child(_rotulo("ROTEIRO DA CIDADE", Flash.fonte_titulo(), 44, TINTA))
	var sub := _rotulo("Lugares para visitar por conta própria. Nada é obrigatório: o Castelinho continua esperando.", Flash.fonte_texto(), 20, Color(TINTA, 0.85))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(sub)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 7)
	lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(lista)
	for i in GameState.CIDADE_ORDEM.size():
		lista.add_child(_linha(i, GameState.CIDADE_ORDEM[i]))

	_aviso = _rotulo("", Flash.fonte_texto(), 21, Color("B3261E"))
	_aviso.custom_minimum_size.y = 26
	coluna.add_child(_aviso)

	var rodape := HBoxContainer.new()
	rodape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(rodape)
	var dica := _rotulo(Celular.dica("Teclas 1 a 5 escolhem · Esc ou E fecham", "Toque num lugar para ir"), Flash.fonte_texto(), 19, Color(TINTA, 0.7))
	dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rodape.add_child(dica)
	var fechar_b := Button.new()
	fechar_b.name = "Fechar"
	fechar_b.text = "Fechar"
	fechar_b.focus_mode = Control.FOCUS_NONE
	fechar_b.custom_minimum_size = Vector2(170, 52)
	fechar_b.add_theme_font_override("font", Flash.fonte_titulo())
	fechar_b.add_theme_font_size_override("font_size", 26)
	fechar_b.add_theme_color_override("font_color", Color.WHITE)
	fechar_b.add_theme_color_override("font_hover_color", Color.WHITE)
	fechar_b.add_theme_color_override("font_pressed_color", Color.WHITE)
	fechar_b.add_theme_stylebox_override("normal", Flash.caixa(Flash.AZUL, TINTA, 12, 3, false))
	fechar_b.add_theme_stylebox_override("hover", Flash.caixa(Flash.AZUL_CLARO, TINTA, 12, 3, false))
	fechar_b.add_theme_stylebox_override("pressed", Flash.caixa(Flash.AZUL_CLARO, TINTA, 12, 3, false))
	fechar_b.pressed.connect(func() -> void:
		if Time.get_ticks_msec() - _aberto_ms >= GUARDA_MS:
			fechar())
	rodape.add_child(fechar_b)


func _rotulo(texto: String, fonte: Font, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _linha(i: int, id: String) -> Button:
	var d: Dictionary = GameState.CIDADE[id]
	var est := estado(id)
	var b := Button.new()
	b.name = "Lugar_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 78)
	var fundo := SALA_FECHADA if est == "fechado" else (SALA_VISTA if est == "feito" else SALA_NORMAL)
	var passe := Flash.AZUL_CLARO if est != "fechado" else Color("E6D7AB")
	b.add_theme_stylebox_override("normal", Flash.caixa(fundo, TINTA, 10, 3, false))
	b.add_theme_stylebox_override("hover", Flash.caixa(passe, TINTA, 10, 3, false))
	b.add_theme_stylebox_override("pressed", Flash.caixa(passe, TINTA, 10, 3, false))
	b.add_theme_stylebox_override("focus", Flash.caixa(passe, TINTA, 10, 3, false))
	b.pressed.connect(func() -> void:
		if Time.get_ticks_msec() - _aberto_ms >= GUARDA_MS:
			escolher(i))

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 16)
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_bottom", 3)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var num := _rotulo(str(i + 1), Flash.fonte_titulo(), 40, Color(TINTA, 0.9 if est != "fechado" else 0.5))
	num.custom_minimum_size.x = 40
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(num)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_rotulo(str(d["rotulo"]), Flash.fonte_titulo(), 26, Color(TINTA, 1.0 if est != "fechado" else 0.55)))
	var desc := _rotulo(str(d["texto"]) if est != "fechado" else "Ainda sem visitas guiadas neste trecho.", Flash.fonte_texto(), 17, Color(TINTA, 0.8 if est != "fechado" else 0.5))
	desc.clip_text = true
	v.add_child(desc)

	var cor_est := VERDE_ESCURO if est == "feito" else (Color("1F5FBF") if est == "aberto" else Color(TINTA, 0.55))
	var lbl := _rotulo(texto_estado(id), Flash.fonte_titulo(), 22, cor_est)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(lbl)
	if est == "feito":
		var marca := Marca.new()
		marca.custom_minimum_size = Vector2(40, 40)
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(marca)
	linhas.append({"id": id, "estado": est, "botao": b, "texto_estado": texto_estado(id)})
	return b


## O "✓" desenhado (a fonte do jogo não tem esse caractere): bolinha verde com um visto branco.
class Marca extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 17.0, Color("2F8F2A"))
		draw_arc(c, 17.0, 0.0, TAU, 28, Flash.NAVY, 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(-8, 1), c + Vector2(-2, 8), c + Vector2(9, -7)]), Color.WHITE, 4.0)


# ================================================================ entrada
func _unhandled_input(e: InputEvent) -> void:
	if _fechado or _folha == null:
		return
	if e.is_action_pressed("pausa"):
		fechar()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("interagir"):
			fechar()
			get_viewport().set_input_as_handled()
			return
		var k: int = e.physical_keycode
		var idx := -1
		if k >= KEY_1 and k <= KEY_5:
			idx = k - KEY_1
		elif k >= KEY_KP_1 and k <= KEY_KP_5:
			idx = k - KEY_KP_1
		if idx >= 0 and Time.get_ticks_msec() - _aberto_ms >= GUARDA_MS:
			escolher(idx)
			get_viewport().set_input_as_handled()


# ================================================================ a placa na calçada (3D)
## Tabuleta azul da "prefeitura" num poste de madeira, com um Interagivel (E / Interagir no toque). `yaw` em graus
## (0 = a face olha para +z; -90 = olha para -x). Devolve o Interagivel. Quem chama decide se a cria (só com lugar aberto).
static func montar_3d(pai: Node3D, pos: Vector3, yaw: float) -> Interagivel:
	var raiz := Node3D.new()
	raiz.name = "PlacaCidade3D"
	raiz.position = pos
	raiz.rotation_degrees.y = yaw
	pai.add_child(raiz)
	var madeira := Ato2Pecas.mat_cor(Color(0.34, 0.24, 0.15))
	var azul := Ato2Pecas.mat_cor(Color(0.16, 0.32, 0.66))
	var amarelo := Ato2Pecas.mat_cor(Color(1.0, 0.82, 0.25))
	Construtor.caixa(raiz, Vector3(0.14, 2.3, 0.14), Vector3(-0.8, 1.15, 0), madeira, true, "PostE")
	Construtor.caixa(raiz, Vector3(0.14, 2.3, 0.14), Vector3(0.8, 1.15, 0), madeira, true, "PostD")
	Construtor.caixa(raiz, Vector3(1.9, 1.15, 0.08), Vector3(0, 1.65, 0), azul, false, "Tabuleta")
	Construtor.caixa(raiz, Vector3(1.9, 0.07, 0.1), Vector3(0, 2.25, 0), amarelo, false, "Faixa")
	var t1 := Construtor.rotulo(raiz, "PROGRAMA MUNICIPAL", Vector3(0, 2.02, 0.05), 30, Color(1.0, 0.96, 0.85))
	t1.double_sided = true
	var t2 := Construtor.rotulo(raiz, "ROTEIRO DA CIDADE", Vector3(0, 1.7, 0.05), 38, Color(1.0, 0.82, 0.25))
	t2.double_sided = true
	var t3 := Construtor.rotulo(raiz, "Lugares para visitar", Vector3(0, 1.38, 0.05), 30, Color(1.0, 0.96, 0.85))
	t3.double_sided = true
	var it := Interagivel.new("Ler a placa da prefeitura", Vector3(2.0, 1.8, 0.8), func(_p: Node) -> void: PlacaCidade.abrir())
	it.name = "PlacaCidadeInteragivel"
	it.position = Vector3(0, 1.2, 0)
	raiz.add_child(it)
	return it
