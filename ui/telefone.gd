class_name Telefone
extends Node
## A voz da mãe do Tito no telefone do acervo (V2 §3.2). Ela é FICÇÃO e nunca tem nome: só voz, num fio ruim.
##
##   await Telefone.tocar(["Alô? É do Castelinho?",
##       "O meu filho... ele vinha sempre brincar aí na obra...", "Vocês viram o Tito?"]).terminou
##
## Toca o telefone (som "telefone"), atende (clique) e mostra cada linha na caixa "???" do Guia (VT323 vermelho sobre
## preto), com o som "telefone_voz" (murmúrio de ruído filtrado, nada de voz sintetizada) e CHIADO: algumas letras
## viram `#`, `%`, `·` e a linha às vezes falha no meio ("Vocês vi%%%u o Ti·o?"). O jogador fica travado durante a
## ligação (as falas são bloqueantes, o botão de avançar é o do Guia). Desliga com um clique e `terminou` sai.
##   Telefone.tocar(linhas, false)   sem o toque (quando o nível já tocou o telefone)
##   Telefone.chiar(texto, forca)    a função de chiado (estática, para testes)
## Texto original sempre inteiro em `Telefone.linhas_limpas` (a legenda real fica na tela, sem esconder o que ela diz).

signal terminou

var linhas_limpas: Array = []
var _com_toque := true
var _executando := false
var _feito := false
var _faixa: CanvasLayer         # revisão V2: plaquinha "LIGAÇÃO" com o fone e a onda de chiado, sobre a caixa do Guia
var _onda: Control
var _t := 0.0
var _passo := -1
var _falando := false


static func tocar(linhas: Array, com_toque := true) -> Telefone:
	var t := Telefone.new()
	t.linhas_limpas = linhas.duplicate()
	t._com_toque = com_toque
	Flash.raiz().add_child.call_deferred(t)
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_executar()


func _executar() -> void:
	if _executando:
		return
	_executando = true
	if _com_toque:
		Audio.sfx("telefone")
		await get_tree().create_timer(2.3, false).timeout
		Audio.sfx("clique", -2.0, 0.8)
		await get_tree().create_timer(0.35, false).timeout
	_montar_faixa()
	for i in linhas_limpas.size():
		Audio.sfx("telefone_voz")
		Efeitos.pulso(0.25, 0.3)
		_falando = true
		await Guia.falar("???", [chiar(str(linhas_limpas[i]), 0.07 + 0.04 * i)], true)
		_falando = false
		if i < linhas_limpas.size() - 1:
			Audio.sfx("chiado_radio", -10.0)
	Audio.sfx("clique", -2.0, 0.7)
	Audio.sfx("chiado_radio", -6.0)   # o fio cai
	await get_tree().create_timer(0.5, false).timeout
	_feito = true
	terminou.emit()
	if is_instance_valid(_faixa):
		_faixa.queue_free()
	queue_free()


## Plaquinha em cima da caixa de fala: um fone de gancho (desenhado, contorno grosso de Flash) e uma onda de chiado
## que treme a 12 quadros por segundo, mais alta quando a voz está falando. Diz "telefone" sem precisar de texto.
func _montar_faixa() -> void:
	_faixa = CanvasLayer.new()
	_faixa.layer = 21              # logo acima da caixa do Guia (20)
	add_child(_faixa)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(raiz)
	_onda = Control.new()
	_onda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_onda.anchor_left = 0.5
	_onda.anchor_right = 0.5
	_onda.anchor_top = 1.0
	_onda.anchor_bottom = 1.0
	_onda.offset_left = -500.0
	_onda.offset_right = -160.0
	_onda.offset_top = -232.0
	_onda.offset_bottom = -178.0
	raiz.add_child(_onda)
	_onda.draw.connect(_desenhar_faixa)
	var rotulo := Label.new()
	rotulo.text = "LIGAÇÃO · LINHA 4-27"
	rotulo.position = Vector2(60, 4)
	rotulo.add_theme_font_override("font", Flash.fonte_erro())
	rotulo.add_theme_font_size_override("font_size", 20)
	rotulo.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
	_onda.add_child(rotulo)


func _process(dt: float) -> void:
	_t += dt
	var p := int(_t * 12.0)
	if p != _passo and is_instance_valid(_onda):
		_passo = p
		_onda.queue_redraw()


func _desenhar_faixa() -> void:
	var r := Rect2(Vector2.ZERO, _onda.size)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.04, 0.0, 0.01, 0.92)
	fundo.border_color = Color(0.55, 0.05, 0.08)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(8)
	_onda.draw_style_box(fundo, r)
	# o fone (gancho): duas conchas e o cabo, em vermelho com contorno escuro
	var c := Vector2(30, r.size.y * 0.5)
	var fone := PackedVector2Array([c + Vector2(-16, -8), c + Vector2(-10, -14), c + Vector2(10, -14), c + Vector2(16, -8),
		c + Vector2(11, -3), c + Vector2(6, -8), c + Vector2(-6, -8), c + Vector2(-11, -3)])
	_onda.draw_colored_polygon(fone, Color(0.9, 0.2, 0.2))
	_onda.draw_polyline(fone + PackedVector2Array([fone[0]]), Color(0.2, 0.0, 0.02), 2.0)
	_onda.draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 10)), Color(0.9, 0.2, 0.2))
	_onda.draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 10)), Color(0.2, 0.0, 0.02), false, 2.0)
	# a onda: ruído em degraus (pixelado), mais alto quando a voz fala
	var amp := 9.0 if _falando else 2.5
	var pts := PackedVector2Array()
	var x := 60.0
	var y0 := r.size.y - 14.0
	while x < r.size.x - 10.0:
		pts.append(Vector2(x, y0 + randf_range(-amp, amp)))
		x += 6.0
	if pts.size() > 1:
		_onda.draw_polyline(pts, Color(0.95, 0.3, 0.3, 0.85), 2.0)


## Chiado da linha: `forca` (0..1) é a chance de cada letra virar ruído; uma falha curta pode comer um pedaço.
static func chiar(texto: String, forca := 0.08) -> String:
	var ruido := ["#", "%", "·", "~", "*"]
	var saida := ""
	var falha := 0
	for ch in texto:
		if falha > 0:
			falha -= 1
			saida += ruido[randi() % ruido.size()] if ch != " " else " "
			continue
		if ch != " " and ch not in ".,?!" and randf() < forca:
			saida += ruido[randi() % ruido.size()]
			if randf() < 0.18:
				falha = randi_range(1, 3)
		else:
			saida += ch
	return saida
