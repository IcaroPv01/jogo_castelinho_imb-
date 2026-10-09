class_name MenuPausa
extends Control
## Menu de pausa (Esc): Continuar, Opções (volume e sensibilidade) e Voltar ao título (com confirmação).
## Estilo "Flash educativo" (BotaoGel). Vive dentro do HUD, que roda mesmo com a árvore pausada.
## Quem pausa/despausa é o main.gd (mouse solto = pausa); aqui só mostramos o menu e recapturamos o mouse
## DENTRO do clique em "Continuar" (o navegador exige um gesto do usuário para o pointer lock).

var lbl_pausa: Label            # título "PAUSADO" (o HUD e os testes usam a visibilidade dele)
var btn_continuar: BotaoGel
var _lbl_pistas: Label
var _pag_principal: VBoxContainer
var _pag_opcoes: VBoxContainer
var _pag_confirma: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP   # clique no fundo não vaza para o jogo
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.08, 0.22, 0.6)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var painel := PanelContainer.new()
	var caixa := Flash.caixa(Flash.CREME, Flash.NAVY, 28, 6)
	caixa.content_margin_left = 44
	caixa.content_margin_right = 44
	caixa.content_margin_top = 26
	caixa.content_margin_bottom = 34
	painel.add_theme_stylebox_override("panel", caixa)
	painel.custom_minimum_size = Vector2(460, 0)
	centro.add_child(painel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	painel.add_child(col)

	lbl_pausa = Label.new()
	lbl_pausa.text = "PAUSADO"
	lbl_pausa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pausa.add_theme_font_override("font", Flash.fonte_titulo())
	lbl_pausa.add_theme_font_size_override("font_size", 52)
	lbl_pausa.add_theme_color_override("font_outline_color", Flash.NAVY)
	lbl_pausa.add_theme_constant_override("outline_size", 14)
	col.add_child(lbl_pausa)
	_lbl_pistas = _rotulo("", 24)
	_lbl_pistas.add_theme_color_override("font_color", Color("9A5B00"))
	col.add_child(_lbl_pistas)

	_pag_principal = _pagina(col)
	btn_continuar = _botao(_pag_principal, "Continuar", Flash.VERDE, _continuar)
	_botao(_pag_principal, "Opções", Flash.AZUL, func(): _ir("opcoes"))
	_botao(_pag_principal, "Voltar ao título", Flash.LARANJA, func(): _ir("confirma"))

	_pag_opcoes = _pagina(col)
	_pag_opcoes.add_child(_rotulo("Volume geral", 24))
	_pag_opcoes.add_child(_slider(0.0, 1.0, Opcoes.volume, func(v: float):
		Opcoes.definir_volume(v)))
	_pag_opcoes.add_child(_rotulo("Sensibilidade do mouse", 24))
	_pag_opcoes.add_child(_slider(Opcoes.SENS_MIN, Opcoes.SENS_MAX, GameState.sensibilidade, func(v: float):
		GameState.sensibilidade = v))
	_botao(_pag_opcoes, "Voltar", Flash.AZUL, func():
		Opcoes.salvar()
		_ir("principal"))

	_pag_confirma = _pagina(col)
	var aviso := _rotulo("Tem certeza? O progresso desde o último checkpoint se perde.", 24)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(380, 0)
	_pag_confirma.add_child(aviso)
	_botao(_pag_confirma, "Sim, voltar ao título", Flash.VERMELHO, voltar_ao_titulo)
	_botao(_pag_confirma, "Não, continuar aqui", Flash.VERDE, func(): _ir("principal"))
	_ir("principal")


func _rotulo(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Flash.fonte_texto())
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Flash.NAVY)
	return l


func _pagina(pai: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pai.add_child(v)
	return v


func _botao(pai: Control, texto: String, cor: Color, ao_clicar: Callable) -> BotaoGel:
	var b := BotaoGel.new(texto, cor, 30)
	b.custom_minimum_size = Vector2(0, 66)
	b.pressed.connect(ao_clicar)
	pai.add_child(b)
	return b


## Barra deslizante no estilo Flash (trilho azul-marinho, preenchimento amarelo, bolinha branca).
func _slider(minimo: float, maximo: float, valor: float, ao_mudar: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = 0.01
	s.value = valor
	s.custom_minimum_size = Vector2(0, 36)
	s.focus_mode = Control.FOCUS_NONE
	var trilho := Flash.caixa(Flash.NAVY, Flash.NAVY, 8, 2, false)
	trilho.content_margin_top = 7
	trilho.content_margin_bottom = 7
	var cheio := Flash.caixa(Flash.AMARELO, Flash.NAVY, 8, 2, false)
	cheio.content_margin_top = 7
	cheio.content_margin_bottom = 7
	s.add_theme_stylebox_override("slider", trilho)
	s.add_theme_stylebox_override("grabber_area", cheio)
	s.add_theme_stylebox_override("grabber_area_highlight", cheio)
	var bola := _textura_bola(Color.WHITE)
	s.add_theme_icon_override("grabber", bola)
	s.add_theme_icon_override("grabber_highlight", bola)
	s.add_theme_icon_override("grabber_disabled", bola)
	s.value_changed.connect(ao_mudar)
	return s


func _textura_bola(cor: Color) -> ImageTexture:
	var d := 30
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d / 2.0 - 0.5, d / 2.0 - 0.5)
	for y in d:
		for x in d:
			var r := Vector2(x, y).distance_to(c)
			if r <= 14.0:
				img.set_pixel(x, y, Flash.NAVY if r > 10.5 else cor)
	return ImageTexture.create_from_image(img)


func _ir(pagina: String) -> void:
	_pag_principal.visible = pagina == "principal"
	_pag_opcoes.visible = pagina == "opcoes"
	_pag_confirma.visible = pagina == "confirma"


## Mostra/esconde o menu; `pistas` = quantas pistas do Tito já foram achadas (0 = linha escondida).
func mostrar(v: bool, pistas: int = 0) -> void:
	visible = v
	if v:
		_ir("principal")
		_lbl_pistas.text = "Pistas do Tito: %d" % pistas
		_lbl_pistas.visible = pistas > 0


## Recaptura o mouse dentro do clique (exigência do navegador); o main.gd despausa no quadro seguinte.
func _continuar() -> void:
	Opcoes.salvar()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Mesmo caminho de volta ao título do Braço Morto: zera a UI, desliga o jogo e recarrega a cena principal.
func voltar_ao_titulo() -> void:
	Opcoes.salvar()
	Flash.resetar_ui()
	GameState.jogando = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Transicao.fade_in(0.05)   # o nível pode ter deixado a Transicao escura
	var arvore := get_tree()
	if arvore.current_scene:
		arvore.reload_current_scene.call_deferred()


## Esc dentro do menu: volta da subpágina, ou continua. (O Esc que ABRE a pausa chega aqui com o menu ainda invisível.)
func _unhandled_input(e: InputEvent) -> void:
	if not visible or not e.is_action_pressed("pausa"):
		return
	get_viewport().set_input_as_handled()
	if _pag_principal.visible:
		_continuar()
	else:
		if _pag_opcoes.visible:
			Opcoes.salvar()
		_ir("principal")
