class_name FimDemo
extends CanvasLayer
## Tela "FIM DA DEMONSTRAÇÃO — Sala 30/100": estatísticas (selos, painéis lidos, mortes) e
## botão "Voltar ao início", que recarrega a cena principal (main) e volta à tela de título.
##
## Uso (nível Ato II, ao abrir a porta da sala 30, depois da voz do Bentinho):
##   FimDemo.mostrar()
## Ela solta o mouse (modal). Voltar ao início: Flash.resetar_ui() + reload_current_scene().

var _janela: Control
var _t := 0.0
var _voltando := false
var _prox_glitch := 1.0
var _mascote: TextureRect


## Texto das estatísticas (também usado nos testes).
func texto_estatisticas() -> String:
	var selos := mini(GameState.selos.size(), Flash.TOTAL_SELOS)
	return "Selos: %d de %d\nPainéis lidos: %d\nMortes: %d" % [selos, Flash.TOTAL_SELOS,
		int(GameState.contadores.get("paineis_lidos", 0)), int(GameState.contadores.get("mortes", 0))]


static func mostrar() -> FimDemo:
	var f: FimDemo = load("res://ui/fim_demo.tscn").instantiate()
	Flash.raiz().add_child.call_deferred(f)
	return f


func _ready() -> void:
	layer = 120   # acima da Transicao (100): o nível escurece a tela antes de mostrar o fim
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	Flash.abrir_ui()
	Audio.sfx("fanfarra", -6.0)
	_janela.modulate.a = 0.0
	create_tween().tween_property(_janela, "modulate:a", 1.0, 0.8)


func _rotulo(pai: Control, texto: String, pos: Vector2, tam: Vector2, fonte: Font, fonte_tam: int, cor: Color, contorno := 0, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.size = tam
	l.horizontal_alignment = alinhar
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", fonte_tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Flash.NAVY)
	l.add_theme_constant_override("outline_size", contorno)
	pai.add_child(l)
	return l


func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color("0E1130")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	_janela = Control.new()
	_janela.anchor_left = 0.5
	_janela.anchor_right = 0.5
	_janela.anchor_top = 0.5
	_janela.anchor_bottom = 0.5
	_janela.offset_left = -520.0
	_janela.offset_right = 520.0
	_janela.offset_top = -330.0
	_janela.offset_bottom = 330.0
	add_child(_janela)

	var painel := Panel.new()
	painel.size = Vector2(1040, 660)
	painel.add_theme_stylebox_override("panel", Flash.caixa(Flash.CREME, Flash.NAVY, 30, 8))
	_janela.add_child(painel)
	var barra := Panel.new()
	barra.size = Vector2(1040, 70)
	var sb := Flash.caixa(Flash.AZUL, Flash.NAVY, 30, 8, false)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	barra.add_theme_stylebox_override("panel", sb)
	_janela.add_child(barra)
	_rotulo(_janela, "FIM DA DEMONSTRAÇÃO — Sala 30/100", Vector2(20, 4), Vector2(1000, 62), Flash.fonte_titulo(), 44, Color.WHITE, 8)

	_rotulo(_janela, "Boletim da visita", Vector2(40, 96), Vector2(560, 50), Flash.fonte_titulo(), 36, Flash.LARANJA, 0, HORIZONTAL_ALIGNMENT_LEFT)

	var selos := mini(GameState.selos.size(), Flash.TOTAL_SELOS)
	var linhas := [
		["Selos", "%d de %d" % [selos, Flash.TOTAL_SELOS], Flash.AMARELO],
		["Painéis lidos", str(int(GameState.contadores.get("paineis_lidos", 0))), Flash.VERDE],
		["Mortes", str(int(GameState.contadores.get("mortes", 0))), Flash.VERMELHO],
	]
	for i in linhas.size():
		var y := 160.0 + i * 92.0
		var cartao := Panel.new()
		cartao.position = Vector2(40, y)
		cartao.size = Vector2(600, 76)
		cartao.add_theme_stylebox_override("panel", Flash.caixa(Color.WHITE, Flash.NAVY, 20, 5, false))
		_janela.add_child(cartao)
		var bolinha := Panel.new()
		bolinha.position = Vector2(58, y + 12)
		bolinha.size = Vector2(52, 52)
		bolinha.add_theme_stylebox_override("panel", Flash.caixa(linhas[i][2], Flash.NAVY, 26, 4, false))
		_janela.add_child(bolinha)
		_rotulo(_janela, linhas[i][0], Vector2(126, y), Vector2(320, 76), Flash.fonte_texto(), 32, Flash.NAVY, 0, HORIZONTAL_ALIGNMENT_LEFT)
		_rotulo(_janela, linhas[i][1], Vector2(430, y), Vector2(190, 76), Flash.fonte_titulo(), 40, Flash.NAVY, 0, HORIZONTAL_ALIGNMENT_RIGHT)

	_mascote = Flash.imagem(Flash.mascote("bentinho", true), Vector2(300, 300), Vector2(690, 110))
	_janela.add_child(_mascote)

	_rotulo(_janela, "Obrigado pela visita... A visita continua...", Vector2(40, 452), Vector2(960, 50), Flash.fonte_erro(), 38, Color("D0141E"))
	_rotulo(_janela, "Esta é uma demonstração: a visita completa tem 100 salas.", Vector2(40, 498), Vector2(960, 36), Flash.fonte_texto(), 24, Color("4B5568"))

	var btn := BotaoGel.new("Voltar ao início", Flash.AZUL, 34)
	btn.size = Vector2(360, 76)
	btn.position = Vector2(340, 556)
	btn.pressed.connect(voltar_ao_inicio)
	_janela.add_child(btn)


func voltar_ao_inicio() -> void:
	if _voltando:
		return
	_voltando = true
	Audio.silenciar(0.3)
	Flash.resetar_ui()
	GameState.jogando = false
	Celular.soltar_mouse()
	get_tree().paused = false
	Transicao.fade_in(0.05)   # o nível costuma deixar a Transicao toda preta: limpa antes de recarregar
	var arvore := get_tree()
	queue_free()
	if arvore.current_scene:
		arvore.reload_current_scene()


func _process(dt: float) -> void:
	_t += dt
	# o Bentinho corrompido "pisca" para a versão normal de vez em quando
	_prox_glitch -= dt
	if _prox_glitch <= 0.0 and _mascote:
		_prox_glitch = randf_range(0.8, 2.4)
		_mascote.texture = Flash.mascote("bentinho", randf() < 0.75)
		_mascote.position.x = 690.0 + randf_range(-4, 4)


func _input(e: InputEvent) -> void:
	if _voltando:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.is_action_pressed("avancar_dialogo"):
		voltar_ao_inicio()
		get_viewport().set_input_as_handled()
