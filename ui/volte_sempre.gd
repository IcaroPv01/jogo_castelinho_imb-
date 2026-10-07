class_name VolteSempre
extends CanvasLayer
## Placa "Obrigado pela visita! Volte sempre!" (V2 §2 e §8.2), estilo Flash, entre o fim de uma visita e o começo da
## seguinte (só nas visitas 1->2 e 2->3).
##
##   GameState.comecar_visita(n + 1)
##   await VolteSempre.mostrar().terminou        # clique/Enter (depois de ~1,5 s) ou sozinha em ~9 s
##   Transicao.ir_para("res://world/niveis/castelinho.tscn", "Spawn")
##
## `mostrar(vez)`: `vez` 0 = automático (a primeira chamada da partida é a normal, a segunda em diante é a ESTRANHA;
## a contagem fica na flag `volte_sempre_vezes`, e GameState.visita >= 3 também conta como a segunda). Na versão
## estranha o texto treme, as letras escorregam, as cores perdem a vida e o Bentinho (a versão corrompida do
## mascote) está torto, perto demais e cresce devagar. Cobre a tela inteira (camada 110, acima da Transicao).

signal terminou

var estranho := false
var _vez := 0
var _feito := false
var _t := 0.0
var _pronto_em := 1.5
var _pos_base := {}
var _fundo: ColorRect
var _placa: Control
var _l1: Label
var _l2: Label
var _mascote: TextureRect
var _dica: Label
var _passo_anterior := -1
var _prox_piscar := 1.5


static func mostrar(vez := 0) -> VolteSempre:
	var v := VolteSempre.new()
	v._vez = vez
	Flash.raiz().add_child.call_deferred(v)
	return v


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _vez <= 0:
		var n := int(GameState.flag("volte_sempre_vezes", 0)) + 1
		GameState.set_flag("volte_sempre_vezes", n)
		_vez = n
		estranho = n >= 2 or GameState.visita >= 3
	else:
		estranho = _vez >= 2
	_construir()
	Flash.abrir_ui()
	if estranho:
		Audio.sfx("glitch", -9.0, 0.7)
		Audio.sfx("sussurro", -14.0, 0.8)
	else:
		Audio.sfx("fanfarra", -9.0)
	_placa.scale = Vector2(0.7, 0.7)
	_placa.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_placa, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_placa, "modulate:a", 1.0, 0.25)


func _cor(c: Color) -> Color:
	return Flash.dessaturar(c, 0.7) if estranho else c


func _construir() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color("12162E") if estranho else Flash.CEU
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)
	# raios de sol / listras de fundo (o fundo de "animação de abertura" dos anos 2000)
	var raios := Control.new()
	raios.set_anchors_preset(Control.PRESET_FULL_RECT)
	raios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estranho_l := estranho
	raios.draw.connect(func():
		var c := raios.size / 2.0
		var cor := Color(1, 1, 1, 0.10) if not estranho_l else Color(0.5, 0.55, 0.8, 0.05)
		for i in 14:
			var a0 := TAU * i / 14.0
			var a1 := a0 + TAU / 28.0
			raios.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 1600.0, c + Vector2(cos(a1), sin(a1)) * 1600.0]), cor))
	add_child(raios)

	_placa = Control.new()
	_placa.anchor_left = 0.5
	_placa.anchor_right = 0.5
	_placa.anchor_top = 0.5
	_placa.anchor_bottom = 0.5
	_placa.offset_left = -470.0
	_placa.offset_right = 470.0
	_placa.offset_top = -250.0
	_placa.offset_bottom = 250.0
	_placa.pivot_offset = Vector2(470, 250)
	add_child(_placa)

	# a placa: tábua creme com contorno grosso, duas cordinhas e uma fita no alto
	for x in [140.0, 800.0]:
		var corda := ColorRect.new()
		corda.color = Color("7A5A3A") if not estranho else Color("46382A")
		corda.position = Vector2(x, -120.0)
		corda.size = Vector2(8, 170)
		_placa.add_child(corda)
	var tabua := Panel.new()
	tabua.size = Vector2(940, 400)
	tabua.position = Vector2(0, 50)
	tabua.add_theme_stylebox_override("panel", Flash.caixa(_cor(Flash.CREME), Flash.NAVY, 36, 9))
	_placa.add_child(tabua)
	var fita := Panel.new()
	fita.size = Vector2(560, 74)
	fita.position = Vector2(190, 6)
	fita.add_theme_stylebox_override("panel", Flash.caixa(_cor(Flash.VERMELHO), Flash.NAVY, 22, 6))
	_placa.add_child(fita)
	var fita_txt := Label.new()
	fita_txt.text = "VISITA GUIADA"
	fita_txt.position = fita.position
	fita_txt.size = fita.size
	fita_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fita_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fita_txt.add_theme_font_override("font", Flash.fonte_titulo())
	fita_txt.add_theme_font_size_override("font_size", 38)
	fita_txt.add_theme_constant_override("outline_size", 8)
	fita_txt.add_theme_color_override("font_outline_color", Flash.NAVY)
	_placa.add_child(fita_txt)

	_l1 = _texto("Obrigado pela visita!", Vector2(40, 130), Vector2(560, 120), 56, _cor(Flash.AZUL))
	_l2 = _texto("Volte sempre!", Vector2(40, 250), Vector2(560, 140), 84, _cor(Flash.LARANJA))
	_pos_base[_l1] = _l1.position
	_pos_base[_l2] = _l2.position

	_mascote = Flash.imagem(Flash.mascote("bentinho", false), Vector2(300, 300), Vector2(610, 110))
	_mascote.pivot_offset = Vector2(150, 300)
	_pos_base[_mascote] = _mascote.position
	_placa.add_child(_mascote)
	if estranho:
		_mascote.texture = Flash.mascote("bentinho", true)
		_mascote.rotation = deg_to_rad(9.0)
		_mascote.position += Vector2(-40, 6)
		_pos_base[_mascote] = _mascote.position

	_dica = Label.new()
	_dica.text = "Clique ou aperte Enter para continuar"
	_dica.anchor_left = 0.5
	_dica.anchor_right = 0.5
	_dica.anchor_top = 1.0
	_dica.anchor_bottom = 1.0
	_dica.offset_left = -300.0
	_dica.offset_right = 300.0
	_dica.offset_top = -64.0
	_dica.offset_bottom = -24.0
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_override("font", Flash.fonte_sistema())
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.8) if not estranho else Color(1, 1, 1, 0.35))
	_dica.add_theme_constant_override("outline_size", 0)
	_dica.modulate.a = 0.0
	add_child(_dica)

	# estrelinhas voando (só na versão alegre)
	if not estranho:
		var tex := Flash.icone("estrela")
		for i in 10:
			var s := Flash.imagem(tex, Vector2(48, 48), Vector2(randf_range(40, 1200), randf_range(30, 680)))
			s.pivot_offset = s.size / 2.0
			s.modulate = Color(1, 1, 1, 0.8)
			add_child(s)
			move_child(s, _fundo.get_index() + 2)   # atrás da placa
			var tw := create_tween().set_loops()
			tw.tween_property(s, "rotation", 0.5, randf_range(0.6, 1.2))
			tw.tween_property(s, "rotation", -0.5, randf_range(0.6, 1.2))


func _texto(txt: String, pos: Vector2, tam: Vector2, tamanho_fonte: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = tam
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", Flash.fonte_titulo())
	l.add_theme_font_size_override("font_size", tamanho_fonte)
	l.set_meta("fonte_base", tamanho_fonte)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Flash.NAVY)
	l.add_theme_constant_override("outline_size", 14)
	l.pivot_offset = tam / 2.0
	_placa.add_child(l)
	_caber(l)
	return l


## Encolhe a fonte até o texto caber numa linha da caixa (revisão V2: na versão estranha "Obrigado... pela... visita"
## e "Volte sempre..." quebravam em duas linhas e se atropelavam, com "sempre..." caindo fora da placa).
func _caber(l: Label) -> void:
	var fonte := l.get_theme_font("font")
	var tam: int = l.get_meta("fonte_base", 56)
	while tam > 20 and fonte.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 28.0 > l.size.x:
		tam -= 2
	l.add_theme_font_size_override("font_size", tam)


func _process(dt: float) -> void:
	if _feito:
		return
	_t += dt
	_pronto_em -= dt
	_dica.modulate.a = clampf((_t - 1.5) * 1.5, 0.0, 1.0)
	var passo := int(_t * 12.0)   # a animação anda em 12 quadros por segundo (tremidinha de Flash)
	if passo != _passo_anterior:
		_passo_anterior = passo
		if estranho:
			_tremer()
		else:
			_mascote.rotation = sin(_t * 3.0) * 0.05
			_mascote.position.y = _pos_base[_mascote].y + absf(sin(_t * 4.0)) * -14.0
			_l2.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 5.0))
	if estranho:
		# o Bentinho cresce devagar, sem tirar os olhos de quem lê
		var k := 1.0 + clampf(_t * 0.015, 0.0, 0.15)
		_mascote.scale = Vector2.ONE * k
	var limite := 9.0
	if _t >= limite:
		continuar()


## Versão estranha: letras escorregam, o texto treme, às vezes lê outra coisa e o mascote pisca para o normal.
func _tremer() -> void:
	for l in [_l1, _l2]:
		l.position = _pos_base[l] + Vector2(randf_range(-4, 4), randf_range(-3, 3))
		l.rotation = randf_range(-0.012, 0.012)
	_prox_piscar -= 1.0 / 12.0
	if _prox_piscar <= 0.0:
		_prox_piscar = randf_range(0.8, 2.4)
		var forte := randf() < 0.45
		_l2.text = "Volte sempre..." if forte else "Volte sempre!"
		_l1.text = "Obrigado pela visita!" if randf() < 0.7 else "Obrigado... pela... visita"
		_caber(_l1)
		_caber(_l2)
		_mascote.texture = Flash.mascote("bentinho", randf() < 0.8)
		if forte:
			Audio.sfx("glitch", -12.0, randf_range(0.7, 1.0))


func continuar() -> void:
	if _feito:
		return
	_feito = true
	Flash.fechar_ui()
	terminou.emit()
	var t := create_tween()
	t.tween_property(_fundo, "color:a", 0.0, 0.25)
	for c in get_children():
		if c is CanvasItem:
			t.parallel().tween_property(c, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _input(e: InputEvent) -> void:
	if _feito or _pronto_em > 0.0:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.is_action_pressed("avancar_dialogo") or e.is_action_pressed("interagir")):
		continuar()
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		continuar()
		get_viewport().set_input_as_handled()
