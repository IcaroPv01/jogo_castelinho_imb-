class_name PainelDebug
extends CanvasLayer
## Painel do modo debug (módulo 9). Só existe quando `Debug.ligado` (o main.gd cria). Para testar o jogo sem sofrer:
## imortal, Figura desligada, atenção congelada, informações na tela, "ganhar tudo", pular para uma sala e ver os finais.
##
## Abre/fecha com a tecla ' (apóstrofo; no teclado ABNT2 é a tecla à esquerda do 1) ou, no celular, com o botão "DBG"
## no topo da tela. Ao abrir o jogo pausa (desktop: solta o mouse; celular: pausa por botão) e ao fechar volta.
## O mouse só é mexido por Celular.soltar_mouse()/capturar_mouse().
## Funciona também na tela de título (aí não mexe em mouse nem em pausa).

const FONTE := 22
const LARG_PAINEL := 980.0

var aberto := false

var _fundo: ColorRect
var _caixa: PanelContainer
var _dbg: PanelContainer
var _dbg_rotulo: Label
var _info: Label
var _checks: Dictionary = {}          # nome da variável do Debug -> CheckBox
var _lugar: OptionButton
var _sala: SpinBox
var _destino: Label
var _mexeu_no_mouse := false
var _mexeu_na_pausa := false
var _t_info := 0.0


func _init() -> void:
	layer = 135      # acima do menu de pausa (96), da Transição (100), de Morte/FimDemo (120) e da Dedicatória (125) e do "Carregando" (130)
	name = "PainelDebug"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_montar_painel()
	_montar_botao_dbg()
	_montar_info()
	_fundo.visible = false
	_caixa.visible = false
	_atualizar_ui()


# ================================================================ montagem
func _montar_painel() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.72)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_caixa = PanelContainer.new()
	_caixa.set_anchors_preset(Control.PRESET_CENTER)
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caixa.custom_minimum_size = Vector2(LARG_PAINEL, 0)
	add_child(_caixa)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	_caixa.add_child(margem)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 10)
	margem.add_child(raiz)

	var titulo := _rotulo("MODO DEBUG  (tecla '  ou botão DBG para fechar)", FONTE + 4)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(titulo)

	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 28)
	raiz.add_child(colunas)
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 8)
	esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colunas.add_child(esq)
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", 8)
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colunas.add_child(dir)

	# ---- coluna da esquerda: chaves, ganhar tudo, finais
	esq.add_child(_rotulo("Chaves", FONTE))
	_check(esq, "imortal", "Imortal (nada mata você)")
	_check(esq, "figura_off", "Figura Branca desligada")
	_check(esq, "atencao_congelada", "Atenção do Visor congelada")
	_check(esq, "info", "Mostrar informações na tela")
	esq.add_child(_botao("Ganhar tudo (5 discos, lanterna, Visor)", func(): Debug.ganhar_tudo()))
	esq.add_child(_rotulo("Ver um final (vai para o Braço Morto)", FONTE))
	esq.add_child(_botao("Final: Encontrado", func(): _final("encontrado")))
	esq.add_child(_botao("Final: Visita concluída", func(): _final("visita_concluida")))
	esq.add_child(_botao("Final: Sala 101", func(): _final("sala_101")))

	# ---- coluna da direita: pular
	dir.add_child(_rotulo("Pular para", FONTE))
	_lugar = OptionButton.new()
	_estilo(_lugar)
	for n in Debug.NOMES_LUGAR:
		_lugar.add_item(n)
	_lugar.item_selected.connect(_ao_escolher_lugar)
	dir.add_child(_lugar)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	dir.add_child(linha)
	linha.add_child(_rotulo("Sala", FONTE))
	linha.add_child(_botao("-", func(): _sala.value -= 1, 56))
	_sala = SpinBox.new()
	_sala.min_value = 1
	_sala.max_value = 100
	_sala.step = 1
	_sala.value = 1
	_sala.custom_minimum_size = Vector2(150, 48)
	_sala.get_line_edit().add_theme_font_size_override("font_size", FONTE)
	_sala.value_changed.connect(_ao_mudar_sala)
	linha.add_child(_sala)
	linha.add_child(_botao("+", func(): _sala.value += 1, 56))
	linha.add_child(_botao("+5", func(): _sala.value += 5, 64))
	_destino = _rotulo("", FONTE - 3)
	_destino.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_destino.custom_minimum_size = Vector2(380, 84)
	dir.add_child(_destino)
	dir.add_child(_botao("Ir para lá", _pular))

	raiz.add_child(_botao("Fechar", fechar))
	_ao_escolher_lugar(0)


func _montar_botao_dbg() -> void:
	_dbg = PanelContainer.new()
	_dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE      # o toque é tratado no _input (os controles de toque pegam tudo antes da interface)
	_dbg.custom_minimum_size = Vector2(92, 46)
	var sb := Flash.caixa(Color(0.15, 0.05, 0.05, 0.85), Color(1, 0.4, 0.3), 10, 3, false)
	_dbg.add_theme_stylebox_override("panel", sb)
	_dbg_rotulo = _rotulo("DBG", FONTE)
	_dbg_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dbg_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dbg.add_child(_dbg_rotulo)
	add_child(_dbg)
	_dbg.visible = false


func _montar_info() -> void:
	_info = _rotulo("", 17)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	_info.visible = false
	add_child(_info)


func _rotulo(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	return l


func _estilo(c: Control) -> void:
	c.custom_minimum_size.y = 48
	c.add_theme_font_size_override("font_size", FONTE)


func _botao(texto: String, cb: Callable, larg := 0) -> Button:
	var b := Button.new()
	b.text = texto
	_estilo(b)
	if larg > 0:
		b.custom_minimum_size.x = larg
	b.pressed.connect(cb)
	return b


func _check(pai: Control, var_nome: String, texto: String) -> void:
	var c := CheckBox.new()
	c.text = texto
	_estilo(c)
	c.toggled.connect(func(v: bool): Debug.definir_chave(var_nome, v))
	pai.add_child(c)
	_checks[var_nome] = c


# ================================================================ abrir / fechar
func alternar() -> void:
	if aberto:
		fechar()
	else:
		abrir()


func abrir() -> void:
	if aberto:
		return
	aberto = true
	_atualizar_ui()
	_fundo.visible = true
	_caixa.visible = true
	# só pausa de verdade se a partida está rolando (no título não há o que pausar)
	_mexeu_no_mouse = false
	_mexeu_na_pausa = false
	if GameState.jogando and not GameState.flag("ui_aberta"):
		if Celular.ativo:
			if not Celular.pausa_toque:
				Celular.pausa_toque = true
				_mexeu_na_pausa = true
		else:
			Celular.soltar_mouse()
			_mexeu_no_mouse = true


## Chame a partir de um evento de tecla/clique: o navegador exige isso para recapturar o mouse.
func fechar() -> void:
	if not aberto:
		return
	aberto = false
	_fundo.visible = false
	_caixa.visible = false
	get_viewport().gui_release_focus()
	if _mexeu_na_pausa:
		Celular.pausa_toque = false
	if _mexeu_no_mouse and GameState.jogando:
		Celular.capturar_mouse()
	_mexeu_no_mouse = false
	_mexeu_na_pausa = false


func _atualizar_ui() -> void:
	for nome in _checks:
		(_checks[nome] as CheckBox).set_pressed_no_signal(Debug.chave(nome))


# ================================================================ ações
func _ao_escolher_lugar(idx: int) -> void:
	_sala.min_value = Debug.FAIXAS[idx][0]
	_sala.max_value = Debug.FAIXAS[idx][1]
	_sala.value = _sala.min_value
	_mostrar_destino()


func _ao_mudar_sala(_v: float) -> void:
	_mostrar_destino()


func _mostrar_destino() -> void:
	var d := Debug.destino(_lugar.selected, int(_sala.value))
	_destino.text = d["texto"]


func _pular() -> void:
	var lugar := _lugar.selected
	var sala := int(_sala.value)
	fechar()
	Debug.pular(lugar, sala)


func _final(qual: String) -> void:
	fechar()
	Debug.pular_final(qual)


# ================================================================ entrada
func _input(e: InputEvent) -> void:
	if not Debug.ligado:
		return
	if Debug.tecla_painel(e):
		alternar()
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenTouch and e.pressed and _dbg.visible:
		if Rect2(_dbg.global_position, _dbg.size).grow(10.0).has_point(e.position):
			alternar()
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	_dbg.visible = Debug.ligado and Celular.ativo
	if _dbg.visible:
		var vp := get_viewport().get_visible_rect().size
		var m := Celular.margens()
		_dbg.size = _dbg.custom_minimum_size
		_dbg.position = Vector2(vp.x * 0.5 - _dbg.size.x * 0.5, m.y)
	_info.visible = Debug.ligado and Debug.info
	if not _info.visible:
		return
	var vp2 := get_viewport().get_visible_rect().size
	_info.position = Vector2(vp2.x * 0.5 + 60.0, Celular.margens().y + 2.0)
	_t_info += dt
	if _t_info >= 0.2:
		_t_info = 0.0
		_info.text = texto_info()


## "sala 12 | época 1950 | visita 1 | 60 qps" (público para o teste).
func texto_info() -> String:
	var nome_epoca: String = GameState.NOMES_EPOCA.get(GameState.epoca, str(GameState.epoca))
	return "sala %d | época %s | visita %d | %d qps" % [GameState.sala_atual, nome_epoca, GameState.visita,
		int(Engine.get_frames_per_second())]
