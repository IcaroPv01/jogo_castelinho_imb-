class_name Dedicatoria
extends CanvasLayer
## Créditos simples e, depois, a tela de dedicatória (V2_ROTEIRO §1), obrigatória no fim do jogo.
##
##   await Dedicatoria.mostrar().terminou          # créditos + dedicatória
##   ... depois o título (o nível/main decide). Ou: Dedicatoria.mostrar(true) já recarrega a cena principal.
##
## FUNDO PRETO, SEM SUSTO, SEM MÚSICA ALTA: ao abrir, `Audio.silenciar()`; nenhum efeito sonoro. Os créditos
## rolam sozinhos (~14 s; Esc/Enter/clique pulam depois de 2 s). A dedicatória aparece linha a linha, em silêncio, e
## só termina com clique/Enter DEPOIS de ~6 s (o aviso "Clique para continuar" só surge então). O texto é fixo e
## igual ao do roteiro: `Dedicatoria.TEXTO_1` e `TEXTO_2`.
## Tito é ficção; o aviso diz isso, e diz a quem recorrer (Disque 100, Conselho Tutelar).

signal terminou

const TEXTO_1 := "Tito é um personagem fictício. As crianças que sofrem violência e abandono não são."
const TEXTO_2 := "Se você desconfia de que uma criança está em perigo: Disque 100 (Direitos Humanos, gratuito, 24h) ou procure o Conselho Tutelar da sua cidade."
const ESPERA_DEDICATORIA := 6.0
const TEMPO_CREDITOS := 14.0
const CREDITOS := [
	["CASTELINHO: VISITA GUIADA", 56],
	["", 20],
	["Um jogo feito por amigos, por diversão.", 28],
	["Inspirado no Castelinho de Imbé (RS),", 26],
	["Casa de Cultura e Museu Municipal.", 26],
	["", 20],
	["O \"Programa Municipal de Memória Interativa\",", 24],
	["a Turma da Memória e todos os personagens são fictícios.", 24],
	["Nenhuma instituição ou pessoa real aparece neste jogo.", 24],
	["", 20],
	["Feito com Godot Engine.", 24],
	["Fontes: Baloo 2, Comic Neue, VT323 e Arimo (SIL OFL).", 22],
	["Sons e imagens gerados por código.", 22],
	["", 20],
	["Obrigado por visitar.", 30],
]

var voltar_ao_titulo := false
var fase := "creditos"        # "creditos" | "dedicatoria" | "fim"
var _t := 0.0
var _t_fase := 0.0
var _feito := false
var _fundo: ColorRect
var _cred: VBoxContainer
var _ded: Control
var _rt1: RichTextLabel
var _rt2: RichTextLabel
var _dica: Label


static func mostrar(voltar := false) -> Dedicatoria:
	var d := Dedicatoria.new()
	d.voltar_ao_titulo = voltar
	Flash.raiz().add_child.call_deferred(d)
	return d


## O texto da dedicatória como o jogador o lê (sem marcação), para conferir com o roteiro.
func texto_dedicatoria() -> String:
	return _rt1.get_parsed_text() + "\n" + _rt2.get_parsed_text()


func _ready() -> void:
	layer = 125   # acima de tudo, inclusive da Morte e do FimDemo (120)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.silenciar(1.5)
	Flash.abrir_ui()
	_construir()


func _construir() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	# --- créditos
	_cred = VBoxContainer.new()
	_cred.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cred.add_theme_constant_override("separation", 6)
	_cred.alignment = BoxContainer.ALIGNMENT_CENTER
	_cred.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for linha in CREDITOS:
		var l := Label.new()
		l.text = linha[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", Flash.fonte_titulo() if linha[1] > 40 else Flash.fonte_sistema())
		l.add_theme_font_size_override("font_size", linha[1])
		l.add_theme_color_override("font_color", Color(0.86, 0.87, 0.9))
		l.add_theme_constant_override("outline_size", 0)
		_cred.add_child(l)
	add_child(_cred)
	_cred.modulate.a = 0.0

	# --- dedicatória
	_ded = Control.new()
	_ded.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ded.visible = false
	add_child(_ded)
	_rt1 = _rotulo_rico(TEXTO_1, 40, Color(0.93, 0.93, 0.95), -230.0, 120.0)
	_rt2 = _rotulo_rico(TEXTO_2, 34, Color(0.82, 0.83, 0.88), -90.0, 230.0)
	_rt1.modulate.a = 0.0
	_rt2.modulate.a = 0.0
	_dica = Label.new()
	_dica.text = "Clique ou aperte Enter para continuar"
	_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.anchor_left = 0.5
	_dica.anchor_right = 0.5
	_dica.offset_left = -300.0
	_dica.offset_right = 300.0
	_dica.offset_top = -70.0
	_dica.offset_bottom = -30.0
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_override("font", Flash.fonte_sistema())
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	_dica.add_theme_constant_override("outline_size", 0)
	_dica.modulate.a = 0.0
	_ded.add_child(_dica)


func _rotulo_rico(texto: String, tam: int, cor: Color, y: float, alt: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 0.5
	r.anchor_bottom = 0.5
	r.offset_left = -480.0
	r.offset_right = 480.0
	r.offset_top = y
	r.offset_bottom = y + alt + 60.0
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Arimo-Latin.ttf")
	fv.variation_opentype = {Flash._tag_wght(): 500.0}
	var fb := FontVariation.new()
	fb.base_font = fv.base_font
	fb.variation_opentype = {Flash._tag_wght(): 700.0}
	r.add_theme_font_override("normal_font", fv)
	r.add_theme_font_override("bold_font", fb)
	r.add_theme_font_size_override("normal_font_size", tam)
	r.add_theme_font_size_override("bold_font_size", tam)
	r.add_theme_color_override("default_color", cor)
	var bb := texto
	for destaque in ["Disque 100", "Conselho Tutelar"]:
		bb = bb.replace(destaque, "[b][color=#ffffff]%s[/color][/b]" % destaque)
	r.text = "[center]%s[/center]" % bb
	_ded.add_child(r)
	return r


func _process(dt: float) -> void:
	if _feito:
		return
	_t += dt
	_t_fase += dt
	match fase:
		"creditos":
			# entra, fica e sai, sem pressa; nada de som
			_cred.modulate.a = clampf(_t_fase / 1.5, 0.0, 1.0) * clampf((TEMPO_CREDITOS - _t_fase) / 1.5, 0.0, 1.0)
			if _t_fase >= TEMPO_CREDITOS:
				_ir_para_dedicatoria()
		"dedicatoria":
			_rt1.modulate.a = clampf((_t_fase - 0.8) / 1.8, 0.0, 1.0)
			_rt2.modulate.a = clampf((_t_fase - 3.2) / 1.8, 0.0, 1.0)
			_dica.modulate.a = clampf((_t_fase - ESPERA_DEDICATORIA) / 1.0, 0.0, 1.0) * (0.55 + 0.25 * sin(_t * 2.0))


func _ir_para_dedicatoria() -> void:
	fase = "dedicatoria"
	_t_fase = 0.0
	_cred.visible = false
	_ded.visible = true


## Pula os créditos (depois de 2 s). Na dedicatória só vale depois de ESPERA_DEDICATORIA.
func avancar() -> void:
	if _feito:
		return
	if fase == "creditos":
		if _t_fase >= 2.0:
			_ir_para_dedicatoria()
	elif fase == "dedicatoria" and _t_fase >= ESPERA_DEDICATORIA:
		_terminar()


func _terminar() -> void:
	_feito = true
	fase = "fim"
	Audio.silenciar(0.2)
	Flash.resetar_ui()          # a cena final acabou: o jogo volta ao título; o mouse fica solto
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	terminou.emit()
	if voltar_ao_titulo:
		GameState.jogando = false
		get_tree().paused = false
		Transicao.fade_in(0.05)
		var arvore := get_tree()
		queue_free()
		if arvore.current_scene:
			arvore.reload_current_scene()
		return
	var t := create_tween()
	t.tween_property(_ded, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


func _input(e: InputEvent) -> void:
	if _feito:
		return
	var pedido := false
	if e is InputEventKey and e.pressed and not e.echo:
		pedido = e.is_action_pressed("avancar_dialogo") or e.is_action_pressed("interagir")
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pedido = true
	if pedido:
		avancar()
		get_viewport().set_input_as_handled()
