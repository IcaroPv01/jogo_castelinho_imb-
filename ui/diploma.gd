class_name Diploma
extends CanvasLayer
## Diploma do "falso final" do Ato I (sala 22): "Parabéns! Você concluiu a Visita Guiada!".
## Nome em branco, uma estrela para cada selo conquistado, confete e fanfarra.
##
## Como usar (no nível, ao fechar o quiz_final):
##   var d := Diploma.mostrar()      # instancia ui/diploma.tscn sob o root e abre como modal
##   await d.fechado                  # o jogador clicou em "Continuar"
## Ou instancie a cena à mão: load("res://ui/diploma.tscn").instantiate() e add_child() — ela se abre sozinha.
## Solta o mouse e trava o jogador enquanto estiver aberto (Flash.abrir_ui / fechar_ui).

signal fechado

const LARGURA := 900.0
const ALTURA := 640.0

var _fechando := false
var _janela: Control
var _confete: Control
var _t := 0.0


class Estrelas extends Control:
	var ganhas := 0
	var total := 6

	func _draw() -> void:
		var passo := size.x / total
		for i in total:
			var c := Vector2(passo * (i + 0.5), size.y / 2.0)
			var pts := Flash.pontos_estrela(c, 30.0, 13.0)
			if i < ganhas:
				draw_colored_polygon(pts, Flash.AMARELO)
			else:
				draw_colored_polygon(pts, Color("E4E1D4"))
			pts.append(pts[0])
			draw_polyline(pts, Flash.NAVY if i < ganhas else Color("A9A596"), 4.0)


class Enfeite extends Control:
	func _draw() -> void:
		for c in [Vector2(40, 40), Vector2(size.x - 40, 40), Vector2(40, size.y - 40), Vector2(size.x - 40, size.y - 40)]:
			var pts := Flash.pontos_estrela(c, 22.0, 9.0)
			draw_colored_polygon(pts, Color("E8B100"))
			pts.append(pts[0])
			draw_polyline(pts, Flash.NAVY, 3.0)


class Confete extends Control:
	var parts: Array = []
	var tempo := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cores := [Flash.VERMELHO, Flash.AMARELO, Flash.AZUL, Flash.VERDE, Flash.ROSA, Flash.LARANJA]
		for i in 90:
			parts.append({"p": Vector2(randf() * 1400.0 - 60.0, -randf() * 900.0), "v": Vector2(randf_range(-20, 20), randf_range(90, 220)),
				"r": randf() * TAU, "rv": randf_range(-6, 6), "c": cores[i % cores.size()], "s": Vector2(randf_range(8, 16), randf_range(14, 24)),
				"f": randf() * TAU})

	func _process(dt: float) -> void:
		tempo += dt
		for q in parts:
			q.p += q.v * dt + Vector2(sin(tempo * 2.0 + q.f) * 30.0 * dt, 0.0)
			q.r += q.rv * dt
			if q.p.y > size.y + 30.0:
				q.p = Vector2(randf() * size.x, -20.0)
		queue_redraw()

	func _draw() -> void:
		for q in parts:
			draw_set_transform(q.p, q.r, Vector2(1.0, absf(cos(tempo * 3.0 + q.f)) * 0.8 + 0.2))
			draw_rect(Rect2(-q.s / 2.0, q.s), q.c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func mostrar() -> Diploma:
	var d: Diploma = load("res://ui/diploma.tscn").instantiate()
	Flash.raiz().add_child.call_deferred(d)
	return d


func _ready() -> void:
	layer = 110   # acima da Transicao (100), caso o nível esteja em fade
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	Flash.abrir_ui()
	Audio.sfx("fanfarra")
	get_tree().create_timer(0.25).timeout.connect(func(): Audio.sfx("confete"))
	_janela.scale = Vector2(0.7, 0.7)
	_janela.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_janela, "modulate:a", 1.0, 0.2)
	t.tween_property(_janela, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rotulo(texto: String, pos: Vector2, tam: Vector2, fonte: Font, fonte_tam: int, cor: Color, contorno := 0, cor_contorno := Flash.NAVY) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.size = tam
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", fonte_tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", cor_contorno)
	l.add_theme_constant_override("outline_size", contorno)
	_janela.add_child(l)
	return l


func _mascote(nome: String, pos: Vector2, lado: float, espelhar := false) -> void:
	_janela.add_child(Flash.imagem(Flash.mascote(nome), Vector2(lado, lado), pos, espelhar))


func _construir() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	_janela = Control.new()
	_janela.anchor_left = 0.5
	_janela.anchor_right = 0.5
	_janela.anchor_top = 0.5
	_janela.anchor_bottom = 0.5
	_janela.offset_left = -LARGURA / 2.0
	_janela.offset_right = LARGURA / 2.0
	_janela.offset_top = -ALTURA / 2.0
	_janela.offset_bottom = ALTURA / 2.0
	_janela.pivot_offset = Vector2(LARGURA / 2.0, ALTURA / 2.0)
	add_child(_janela)

	var papel := Panel.new()
	papel.size = Vector2(LARGURA, ALTURA)
	papel.add_theme_stylebox_override("panel", Flash.caixa(Color("FFF8E1"), Color("E8B100"), 26, 14))
	_janela.add_child(papel)
	var interna := Panel.new()
	interna.position = Vector2(18, 18)
	interna.size = Vector2(LARGURA - 36, ALTURA - 36)
	var sb := Flash.caixa(Color(0, 0, 0, 0), Flash.NAVY, 16, 3, false)
	sb.draw_center = false
	interna.add_theme_stylebox_override("panel", sb)
	_janela.add_child(interna)
	var enfeite := Enfeite.new()
	enfeite.size = Vector2(LARGURA, ALTURA)
	enfeite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.add_child(enfeite)

	_rotulo("PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA", Vector2(0, 34), Vector2(LARGURA, 26), Flash.fonte_sistema(), 17, Color("4B5568"))
	_rotulo("DIPLOMA DE VISITANTE", Vector2(0, 62), Vector2(LARGURA, 48), Flash.fonte_titulo(), 36, Flash.AZUL, 0)
	_rotulo("Parabéns!", Vector2(0, 108), Vector2(LARGURA, 110), Flash.fonte_titulo(), 92, Flash.LARANJA, 16)
	_rotulo("Você concluiu a Visita Guiada!", Vector2(0, 232), Vector2(LARGURA, 50), Flash.fonte_texto(), 38, Flash.NAVY)
	_rotulo("Certificamos que", Vector2(0, 292), Vector2(LARGURA, 30), Flash.fonte_texto(), 23, Color("4B5568"))

	# nome em branco (a linha de assinatura fica vazia)
	var linha := ColorRect.new()
	linha.color = Flash.NAVY
	linha.position = Vector2(LARGURA / 2.0 - 260.0, 352)
	linha.size = Vector2(520, 3)
	_janela.add_child(linha)
	_rotulo("(nome do visitante)", Vector2(0, 358), Vector2(LARGURA, 24), Flash.fonte_sistema(), 15, Color("8B93A3"))

	_rotulo("completou a visita ao Castelinho e conquistou", Vector2(0, 396), Vector2(LARGURA, 30), Flash.fonte_texto(), 23, Color("4B5568"))
	var estrelas := Estrelas.new()
	estrelas.total = Flash.TOTAL_SELOS
	estrelas.ganhas = mini(GameState.selos.size(), Flash.TOTAL_SELOS)
	estrelas.position = Vector2(LARGURA / 2.0 - 270.0, 428)
	estrelas.size = Vector2(540, 70)
	estrelas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.add_child(estrelas)
	_rotulo("%d de %d selos" % [estrelas.ganhas, Flash.TOTAL_SELOS], Vector2(0, 496), Vector2(LARGURA, 34), Flash.fonte_titulo(), 26, Flash.NAVY)

	_mascote("bentinho", Vector2(46, 108), 190)
	_mascote("taina", Vector2(LARGURA - 46 - 190, 112), 190, true)
	_mascote("quico", Vector2(30, 410), 130)
	_rotulo("Bentinho\nguia da visita", Vector2(LARGURA - 270, 520), Vector2(220, 60), Flash.fonte_texto(), 22, Color("4B5568"))

	var btn := BotaoGel.new("Continuar", Flash.VERDE, 32)
	btn.size = Vector2(300, 70)
	btn.position = Vector2(LARGURA / 2.0 - 150.0, ALTURA - 100.0)
	btn.pressed.connect(fechar)
	_janela.add_child(btn)

	_confete = Confete.new()
	_confete.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confete)


func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	Flash.fechar_ui()
	var t := create_tween().set_parallel()
	t.tween_property(_janela, "modulate:a", 0.0, 0.15)
	t.tween_property(_confete, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)
	fechado.emit()


func _input(e: InputEvent) -> void:
	if _fechando:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.is_action_pressed("avancar_dialogo") or e.is_action_pressed("interagir")):
		fechar()
		get_viewport().set_input_as_handled()
