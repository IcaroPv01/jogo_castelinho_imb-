class_name Morte
extends CanvasLayer
## Tela de "morte": "Ops! Você se perdeu da visita! Tente de novo!" em estilo Flash, com glitch vermelho.
##
## Uso (ex.: no main.gd, ao receber GameState.jogador_morreu):
##   var m := Morte.mostrar(causa)
##   await m.terminou          # o jogador apertou espaço/Enter/clique (ou passou `auto_seg`)
##   ... recarrega o checkpoint ...
## A tela se remove sozinha depois de `terminou`. Solta o mouse enquanto aparece (modal).

signal terminou

var causa := ""
var auto_seg := 0.0       # > 0: continua sozinha depois desse tempo (0 = espera o jogador)

var _feito := false
var _t := 0.0
var _prox_glitch := 0.4
var _vermelho: ColorRect
var _cartao: Control
var _titulo: Label
var _fantasma_v: Label
var _fantasma_c: Label
var _mascote: TextureRect
var _barras: Array[ColorRect] = []
var _corrompido := false
var _pronto_em := 0.7     # ignora cliques logo no começo (o jogador pode estar apertando botões)


static func mostrar(motivo := "", auto := 0.0) -> Morte:
	var m: Morte = load("res://ui/morte.tscn").instantiate()
	m.causa = motivo
	m.auto_seg = auto
	Flash.raiz().add_child.call_deferred(m)
	return m


func _ready() -> void:
	layer = 120   # acima da Transicao (100): o nível costuma escurecer a tela antes
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	Flash.abrir_ui()
	Audio.sfx("susto", -4.0)
	Audio.sfx("glitch")
	_cartao.scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(_cartao, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("12060B")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	# linhas de varredura (scanlines) por cima de tudo
	var linhas := Control.new()
	linhas.set_anchors_preset(Control.PRESET_FULL_RECT)
	linhas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linhas.draw.connect(func():
		for y in range(0, int(linhas.size.y), 4):
			linhas.draw_rect(Rect2(0, y, linhas.size.x, 1.5), Color(0, 0, 0, 0.25)))
	add_child(linhas)

	_cartao = Control.new()
	_cartao.anchor_left = 0.5
	_cartao.anchor_right = 0.5
	_cartao.anchor_top = 0.5
	_cartao.anchor_bottom = 0.5
	_cartao.offset_left = -440.0
	_cartao.offset_right = 440.0
	_cartao.offset_top = -270.0
	_cartao.offset_bottom = 270.0
	_cartao.pivot_offset = Vector2(440, 270)
	add_child(_cartao)

	var painel := Panel.new()
	painel.size = Vector2(880, 540)
	painel.add_theme_stylebox_override("panel", Flash.caixa(Flash.CREME, Flash.NAVY, 30, 8))
	_cartao.add_child(painel)
	var barra := Panel.new()
	barra.size = Vector2(880, 60)
	var sb := Flash.caixa(Flash.VERMELHO, Flash.NAVY, 30, 8, false)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	barra.add_theme_stylebox_override("panel", sb)
	_cartao.add_child(barra)
	var cab := Label.new()
	cab.text = "Visita Guiada  -  Aviso"
	cab.position = Vector2(26, 6)
	cab.size = Vector2(600, 48)
	cab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cab.add_theme_font_override("font", Flash.fonte_titulo())
	cab.add_theme_font_size_override("font_size", 26)
	cab.add_theme_constant_override("outline_size", 6)
	_cartao.add_child(cab)

	# o título "Ops!" com dois fantasmas (vermelho e ciano) que tremem: o glitch
	_fantasma_c = _titulo_label("Ops!", Color("00E5FF"))
	_fantasma_v = _titulo_label("Ops!", Color("FF1F2D"))
	_titulo = _titulo_label("Ops!", Flash.AMARELO)
	_titulo.add_theme_color_override("font_outline_color", Flash.NAVY)
	_titulo.add_theme_constant_override("outline_size", 20)

	var l1 := Label.new()
	l1.text = "Você se perdeu da visita!"
	l1.position = Vector2(40, 252)
	l1.size = Vector2(540, 100)
	l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l1.add_theme_font_override("font", Flash.fonte_titulo())
	l1.add_theme_font_size_override("font_size", 46)
	l1.add_theme_color_override("font_color", Flash.NAVY)
	l1.add_theme_constant_override("outline_size", 0)
	_cartao.add_child(l1)
	var l2 := Label.new()
	l2.text = "Tente de novo!"
	l2.position = Vector2(40, 348)
	l2.size = Vector2(540, 60)
	l2.add_theme_font_override("font", Flash.fonte_texto())
	l2.add_theme_font_size_override("font_size", 38)
	l2.add_theme_color_override("font_color", Color("C23B2E"))
	l2.add_theme_constant_override("outline_size", 0)
	_cartao.add_child(l2)

	_mascote = Flash.imagem(Flash.mascote("bentinho"), Vector2(270, 270), Vector2(590, 90))
	_cartao.add_child(_mascote)

	var btn := BotaoGel.new("Tentar de novo", Flash.VERDE, 32)
	btn.position = Vector2(40, 442)
	btn.size = Vector2(330, 72)
	btn.pressed.connect(continuar)
	_cartao.add_child(btn)
	var dica := Label.new()
	dica.text = "Espaço, Enter ou clique para continuar"
	dica.position = Vector2(390, 458)
	dica.size = Vector2(470, 40)
	dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica.add_theme_font_override("font", Flash.fonte_sistema())
	dica.add_theme_font_size_override("font_size", 16)
	dica.add_theme_color_override("font_color", Color("7A8394"))
	dica.add_theme_constant_override("outline_size", 0)
	_cartao.add_child(dica)

	# barras horizontais vermelhas do glitch (ficam escondidas até sortear)
	for i in 4:
		var b := ColorRect.new()
		b.color = Color(1, 0.05, 0.1, 0.5)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.visible = false
		add_child(b)
		_barras.append(b)
	_vermelho = ColorRect.new()
	_vermelho.color = Color(1, 0, 0, 0.0)
	_vermelho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vermelho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vermelho)


func _titulo_label(txt: String, cor: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = Vector2(40, 70)
	l.size = Vector2(540, 170)
	l.add_theme_font_override("font", Flash.fonte_titulo())
	l.add_theme_font_size_override("font_size", 150)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", 0)
	_cartao.add_child(l)
	return l


func continuar() -> void:
	if _feito:
		return
	_feito = true
	Flash.fechar_ui()
	terminou.emit()
	var t := create_tween()
	for c in get_children():
		if c is CanvasItem:
			t.parallel().tween_property(c, "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)


func _process(dt: float) -> void:
	if _feito:
		return
	_t += dt
	_pronto_em -= dt
	if auto_seg > 0.0 and _t >= auto_seg:
		continuar()
		return
	# tremida de glitch: fantasmas deslocados, cartão tremendo, barras e flashes vermelhos
	var forte := randf() < 0.18
	var passo := Vector2(randf_range(-12, 12), randf_range(-3, 3)) if forte else Vector2(sin(_t * 9.0) * 3.0, 0)
	_fantasma_v.position = Vector2(40, 70) + passo
	_fantasma_c.position = Vector2(40, 70) - passo
	_vermelho.color.a = 0.28 if (forte and randf() < 0.4) else maxf(0.0, _vermelho.color.a - dt * 2.0)
	_prox_glitch -= dt
	if _prox_glitch <= 0.0:
		_prox_glitch = randf_range(0.25, 1.1)
		_corrompido = not _corrompido and randf() < 0.6
		_mascote.texture = Flash.mascote("bentinho", _corrompido)
		if randf() < 0.5:
			Audio.sfx("glitch", -9.0, randf_range(0.8, 1.3))
		for b in _barras:
			b.visible = randf() < 0.6
			if b.visible:
				b.position = Vector2(0, randf() * get_viewport().get_visible_rect().size.y)
				b.size = Vector2(get_viewport().get_visible_rect().size.x, randf_range(6, 46))
	elif _prox_glitch < 0.2:
		for b in _barras:
			b.visible = false


func _input(e: InputEvent) -> void:
	if _feito or _pronto_em > 0.0:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.is_action_pressed("avancar_dialogo") or e.is_action_pressed("interagir")):
		continuar()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		continuar()
		get_viewport().set_input_as_handled()
