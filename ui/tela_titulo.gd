class_name TelaTitulo
extends Control
## Tela de título: "jogo educativo da prefeitura" dos anos 2000 (programa FICTÍCIO), com a Turma da Memória.
## Sinal `comecar(continuar: bool)`: emitido NO MESMO EVENTO do clique no botão (o navegador exige um
## evento do usuário para capturar o mouse e liberar o áudio; o main.gd faz isso dentro do handler).
##
## O botão "Continuar" só aparece se GameState.tem_save(). Enter/Espaço: continua se há save, senão começa.
## Música: Audio.musica("jingle") (o jingle institucional alegre).

signal comecar(continuar: bool)

const LARGURA := 1280.0
const ALTURA := 720.0

var _iniciado := false
var _t := 0.0
var _palco: Control
var _titulo: Label
var _mascotes: Array[Control] = []
var _base_y: Array[float] = []
var _btn_comecar: BotaoGel
var _btn_continuar: BotaoGel


# ================================================================ cenário (céu, nuvens, morros, castelo)
class Cenario extends Control:
	var t := 0.0
	var _acum := 0.0

	func _process(dt: float) -> void:
		t += dt
		_acum += dt
		if _acum >= 1.0 / 12.0:   # 12 fps, como uma animação de Flash
			_acum = 0.0
			queue_redraw()

	func _contorno_rect(r: Rect2, cor: Color, borda := 6.0) -> void:
		draw_rect(r, cor)
		draw_rect(r, Flash.NAVY, false, borda)

	func _nuvem(c: Vector2, esc: float) -> void:
		var bolas := [Vector2(-46, 6), Vector2(-14, -12), Vector2(26, -6), Vector2(54, 8), Vector2(6, 10)]
		var raios := [24.0, 32.0, 28.0, 22.0, 28.0]
		for i in bolas.size():
			draw_circle(c + bolas[i] * esc, (raios[i] + 5.0) * esc, Flash.NAVY)
		for i in bolas.size():
			draw_circle(c + bolas[i] * esc, raios[i] * esc, Color.WHITE)
		draw_rect(Rect2(c + Vector2(-60, 6) * esc, Vector2(130, 26) * esc), Color.WHITE)

	func _arco(x: float, y_base: float, larg: float, alt: float) -> void:
		var pts := PackedVector2Array([Vector2(x, y_base)])
		var raio := larg / 2.0
		pts.append(Vector2(x, y_base - alt + raio))
		for i in range(1, 12):
			var a := PI + PI * i / 12.0
			pts.append(Vector2(x + raio + cos(a) * raio, y_base - alt + raio + sin(a) * raio))
		pts.append(Vector2(x + larg, y_base - alt + raio))
		pts.append(Vector2(x + larg, y_base))
		draw_colored_polygon(pts, Color("4A2A22"))
		var contorno := PackedVector2Array(pts)
		contorno.append(pts[0])
		draw_polyline(contorno, Flash.NAVY, 4.0)

	## Polígono chapado com contorno grosso (estilo Flash).
	func _poli(pts: PackedVector2Array, cor: Color, borda := 4.0) -> void:
		draw_colored_polygon(pts, cor)
		var c := PackedVector2Array(pts)
		c.append(pts[0])
		draw_polyline(c, Flash.NAVY, borda)

	## Faixa de mísulas com arquinhos + ameias sobre o topo [x0, x1] em y (como no prédio de verdade).
	func _coroa(x0: float, x1: float, y: float, cor: Color, esc: float) -> void:
		var faixa := 9.0 * esc
		draw_rect(Rect2(x0, y, x1 - x0, faixa), Color("5A2E25"))
		var passo := 11.0 * esc
		var x := x0 + 2.0
		while x + passo * 0.5 < x1:
			draw_rect(Rect2(x, y, 4.0 * esc, faixa), cor)
			draw_circle(Vector2(x + passo * 0.5 + 2.0 * esc, y + 2.0 * esc), passo * 0.32, cor)
			x += passo
		draw_rect(Rect2(x0, y, x1 - x0, 3.0 * esc), cor)
		draw_rect(Rect2(x0, y, x1 - x0, faixa), Flash.NAVY, false, 3.0)
		var m := 7.0 * esc
		var xm := x0
		while xm + m <= x1 + 0.5:
			_contorno_rect(Rect2(xm, y - 9.0 * esc, m, 9.0 * esc), cor, 3.0)
			xm += m * 1.75

	## Pirâmide (cobertura das torretas) sobre o topo [x0, x1] em y.
	func _piramide(x0: float, x1: float, y: float, alt: float) -> void:
		_poli(PackedVector2Array([Vector2(x0 - 4, y), Vector2(x1 + 4, y), Vector2((x0 + x1) * 0.5, y - alt)]), Color("5E4B42"))

	## Janela estreita em arco (escura).
	func _janela(x: float, y: float, w: float, h: float) -> void:
		var pts := PackedVector2Array([Vector2(x, y + h), Vector2(x, y + w * 0.5)])
		for i in range(1, 8):
			var a := PI + PI * i / 8.0
			pts.append(Vector2(x + w * 0.5 + cos(a) * w * 0.5, y + w * 0.5 + sin(a) * w * 0.5))
		pts.append(Vector2(x + w, y + w * 0.5))
		pts.append(Vector2(x + w, y + h))
		_poli(pts, Color("3A2420"), 2.5)

	## O Castelinho visto da Av. Garibaldi (foto frontal de 2026), simplificado: pavilhão, anexo ameado, Torre A com a
	## torreta esbelta de cobertura piramidal, arcada de 5 arcos e, atrás, o corpo do letreiro com telhado e a Torre B.
	func _castelo(cx: float, base: float, esc: float) -> void:
		var pedra := Flash.PEDRA
		var pedra_e := Color("B66A55")
		var fundo := Color("A55C49")
		var hx := 17.0 * esc            # px por metro (horizontal, comprimido como desenho)
		var vy := 21.5 * esc            # px por metro (vertical)
		var x0 := cx - 200.0 * esc
		var X := func(mx: float) -> float: return x0 + mx * hx
		var Y := func(my: float) -> float: return base - my * vy
		# --- atrás: Torre B (com torreta) e corpo do letreiro com telhado de uma água e chaminé
		var tb0: float = X.call(20.2)
		var tb1: float = X.call(23.6)
		_contorno_rect(Rect2(tb0, Y.call(7.2), tb1 - tb0, base - Y.call(7.2)), fundo)
		_coroa(tb0, tb1, Y.call(7.2), fundo, esc)
		var tt0: float = X.call(22.0)
		_contorno_rect(Rect2(tt0, Y.call(8.0), tb1 - tt0, Y.call(7.2) - Y.call(8.0)), fundo)
		_piramide(tt0, tb1, Y.call(8.0), 0.9 * vy)
		_janela(X.call(21.0), Y.call(6.4), 0.4 * hx * 2.0, 1.0 * vy)
		var ch: float = X.call(15.9)
		_contorno_rect(Rect2(ch, Y.call(7.0), 1.0 * hx, Y.call(5.0) - Y.call(7.0)), fundo)
		_piramide(ch - 2, ch + 1.0 * hx + 2, Y.call(7.0), 0.5 * vy)
		_poli(PackedVector2Array([Vector2(X.call(16.0), Y.call(5.5)), Vector2(X.call(24.0), Y.call(4.4)), Vector2(X.call(24.0), base),
			Vector2(X.call(16.0), base)]), fundo)
		_poli(PackedVector2Array([Vector2(X.call(15.6), Y.call(5.75)), Vector2(X.call(24.6), Y.call(4.5)), Vector2(X.call(24.6), Y.call(4.25)),
			Vector2(X.call(15.6), Y.call(5.5))]), Color("8C8C88"), 3.0)
		# --- pavilhão de canto (torreta baixa) e anexo ameado com dois pares de janelas em arco
		var pv1: float = X.call(1.8)
		_contorno_rect(Rect2(X.call(0.0), Y.call(4.5), pv1 - X.call(0.0), base - Y.call(4.5)), pedra_e)
		_piramide(X.call(0.0), pv1, Y.call(4.5), 1.3 * vy)
		var an1: float = X.call(6.0)
		_contorno_rect(Rect2(pv1, Y.call(4.0), an1 - pv1, base - Y.call(4.0)), pedra)
		_coroa(pv1, an1, Y.call(4.0), pedra, esc)
		for jx in [2.4, 3.2, 4.4, 5.2]:
			_janela(X.call(jx), Y.call(2.4), 0.5 * hx, 1.5 * vy)
		# --- Torre A + torreta esbelta na quina
		var ta1: float = X.call(12.8)
		_contorno_rect(Rect2(an1, Y.call(7.4), ta1 - an1, base - Y.call(7.4)), pedra)
		_coroa(an1, X.call(10.7), Y.call(7.4), pedra, esc)
		var tor0: float = X.call(10.7)
		_contorno_rect(Rect2(tor0, Y.call(9.2), ta1 - tor0, base - Y.call(9.2)), pedra_e)
		_coroa(tor0, ta1, Y.call(9.2), pedra_e, esc)
		_piramide(tor0, ta1, Y.call(9.2) - 9.0 * esc, 1.1 * vy)
		_janela(X.call(11.5), Y.call(8.6), 0.4 * hx * 1.6, 0.9 * vy)
		_janela(X.call(8.0), Y.call(5.8), 0.45 * hx * 1.6, 1.4 * vy)
		_janela(X.call(8.8), Y.call(5.8), 0.45 * hx * 1.6, 1.4 * vy)
		_janela(X.call(7.0), Y.call(2.4), 0.3 * hx * 1.6, 0.9 * vy)
		# bandeirinha na ponta da torreta
		var topo := Vector2((tor0 + ta1) * 0.5, Y.call(9.2) - 9.0 * esc - 1.1 * vy)
		draw_line(topo, topo + Vector2(0, -30 * esc), Flash.NAVY, 4.0)
		var bw := sin(t * 7.0) * 3.0
		draw_colored_polygon(PackedVector2Array([topo + Vector2(2, -30 * esc), topo + Vector2(30 * esc, -23 * esc + bw), topo + Vector2(2, -15 * esc)]), Flash.VERMELHO)
		# --- arcada de 5 arcos (o de entrada, no canto leste, é mais largo) com parapeito ameado
		var ar1: float = X.call(23.6)
		_contorno_rect(Rect2(ta1, Y.call(4.0), ar1 - ta1, base - Y.call(4.0)), pedra)
		_coroa(ta1, ar1, Y.call(4.0), pedra, esc)
		for i in 4:
			_arco(X.call(13.5 + i * 2.05), base, 1.3 * hx, 2.4 * vy)
		_arco(X.call(21.4), base, 1.9 * hx, 2.4 * vy)

	func _hortensias(x: float, y: float) -> void:
		for i in 5:
			var o := Vector2(cos(i * 1.3) * 14, sin(i * 2.1) * 8)
			draw_circle(Vector2(x, y) + o, 11, Flash.NAVY)
		for i in 5:
			var o := Vector2(cos(i * 1.3) * 14, sin(i * 2.1) * 8)
			draw_circle(Vector2(x, y) + o, 8, Color("7FA8FF") if i % 2 == 0 else Color("DDE8FF"))

	func _draw() -> void:
		var s := size
		var n := 30
		for i in n:
			draw_rect(Rect2(0, s.y * i / n, s.x, s.y / n + 1.0), Flash.CEU.lerp(Color("D8F1FF"), float(i) / (n - 1)))
		# sol com raios girando
		var sol := Vector2(s.x * 0.5 - 520.0, 225.0)
		for i in 12:
			var a := t * 0.5 + i * TAU / 12.0
			var p1 := sol + Vector2(cos(a - 0.1), sin(a - 0.1)) * 78.0
			var p2 := sol + Vector2(cos(a + 0.1), sin(a + 0.1)) * 78.0
			var p3 := sol + Vector2(cos(a), sin(a)) * 118.0
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color("FFE680"))
		draw_circle(sol, 66.0, Flash.NAVY)
		draw_circle(sol, 60.0, Flash.AMARELO)
		# nuvens
		for i in 5:
			var x := fposmod(80.0 + i * 330.0 + t * (14.0 + i * 3.0), s.x + 400.0) - 200.0
			_nuvem(Vector2(x, 150.0 + (i % 3) * 70.0), 0.8 + 0.12 * (i % 3))
		# morro de trás
		var far := PackedVector2Array()
		var x0 := 0.0
		while x0 <= s.x + 40.0:
			far.append(Vector2(x0, s.y - 235.0 + sin(x0 * 0.005 + 1.0) * 30.0))
			x0 += 40.0
		var poly := PackedVector2Array(far)
		poly.append(Vector2(s.x + 40.0, s.y))
		poly.append(Vector2(0, s.y))
		draw_colored_polygon(poly, Color("78D96A"))
		draw_polyline(far, Flash.NAVY, 6.0)
		# castelo (fiel: torre grande, torre menor, arcada de 4 arcos, ameias)
		_castelo(s.x * 0.5 + 345.0, s.y - 214.0, 0.96)
		# morro da frente
		var near := PackedVector2Array()
		x0 = 0.0
		while x0 <= s.x + 40.0:
			near.append(Vector2(x0, s.y - 165.0 + sin(x0 * 0.007 + 3.0) * 26.0))
			x0 += 40.0
		var poly2 := PackedVector2Array(near)
		poly2.append(Vector2(s.x + 40.0, s.y))
		poly2.append(Vector2(0, s.y))
		draw_colored_polygon(poly2, Color("43B84B"))
		draw_polyline(near, Flash.NAVY, 6.0)
		# hortênsias (o jardim do Castelinho tem hortênsias de verdade)
		for hx in [90.0, 210.0, 330.0, 980.0, 1100.0, 1190.0]:
			var cx: float = s.x * 0.5 - 640.0 + hx
			_hortensias(cx, s.y - 165.0 + sin(cx * 0.007 + 3.0) * 26.0 + 24.0)


class Brilho extends Control:
	## Estrelinhas piscando em volta do título.
	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := floorf(Time.get_ticks_msec() / 83.0) / 12.0
		var pos := [Vector2(60, 120), Vector2(1210, 120), Vector2(250, 170), Vector2(1030, 168), Vector2(640, 6), Vector2(1110, 14)]
		for i in pos.size():
			var f := 0.5 + 0.5 * sin(t * 5.0 + i * 1.9)
			var r := 10.0 + 14.0 * f
			var pts := Flash.pontos_estrela(pos[i], r, r * 0.4, t * 0.5 + i)
			draw_colored_polygon(pts, Flash.AMARELO if i % 2 == 0 else Color.WHITE)
			pts.append(pts[0])
			draw_polyline(pts, Flash.NAVY, 2.5)


# ================================================================ montagem
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var cenario := Cenario.new()
	cenario.set_anchors_preset(Control.PRESET_FULL_RECT)
	cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cenario)

	# palco 1280x720 ancorado no centro de baixo (o cenário cobre o resto da janela)
	_palco = Control.new()
	_palco.anchor_left = 0.5
	_palco.anchor_right = 0.5
	_palco.anchor_top = 1.0
	_palco.anchor_bottom = 1.0
	_palco.offset_left = -LARGURA / 2.0
	_palco.offset_right = LARGURA / 2.0
	_palco.offset_top = -ALTURA
	_palco.offset_bottom = 0.0
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	_montar_faixa_institucional()
	_montar_titulo()
	_montar_mascotes()
	_montar_botoes()
	_montar_rodape()

	Audio.musica("jingle", 0.5)


func _montar_faixa_institucional() -> void:
	var faixa := Panel.new()
	faixa.position = Vector2(-400, -20)
	faixa.size = Vector2(LARGURA + 800, 66)
	faixa.add_theme_stylebox_override("panel", Flash.caixa(Color("14307A"), Flash.NAVY, 0, 5, false))
	_palco.add_child(faixa)
	# emblema genérico (círculo com estrela). NÃO é o brasão de nenhum município.
	var emb := Panel.new()
	emb.position = Vector2(22, 7)
	emb.size = Vector2(36, 36)
	emb.add_theme_stylebox_override("panel", Flash.caixa(Flash.AMARELO, Color.WHITE, 18, 3, false))
	_palco.add_child(emb)
	_palco.add_child(Flash.imagem(Flash.icone("estrela"), Vector2(28, 28), Vector2(26, 11)))
	var l := Label.new()
	l.text = "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA"
	l.position = Vector2(72, 6)
	l.size = Vector2(760, 36)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Flash.fonte_sistema())
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	_palco.add_child(l)
	var l2 := Label.new()
	l2.text = "Visita Guiada Interativa  |  Versão 1.0  |  Melhor visualizado em 800x600"
	l2.position = Vector2(LARGURA - 700, 6)
	l2.size = Vector2(680, 36)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l2.add_theme_font_override("font", Flash.fonte_sistema())
	l2.add_theme_font_size_override("font_size", 15)
	l2.add_theme_color_override("font_color", Color("AFC4FF"))
	l2.add_theme_constant_override("outline_size", 0)
	_palco.add_child(l2)


func _montar_titulo() -> void:
	var brilho := Brilho.new()
	brilho.size = Vector2(LARGURA, 200)
	brilho.position = Vector2(0, 50)
	brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.add_child(brilho)

	_titulo = Label.new()
	_titulo.text = "Castelinho: Visita Guiada"
	_titulo.position = Vector2(0, 62)
	_titulo.size = Vector2(LARGURA, 124)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_override("font", Flash.fonte_titulo())
	_titulo.add_theme_font_size_override("font_size", 92)
	_titulo.add_theme_color_override("font_color", Flash.AMARELO)
	_titulo.add_theme_color_override("font_outline_color", Flash.NAVY)
	_titulo.add_theme_constant_override("outline_size", 22)
	_titulo.add_theme_color_override("font_shadow_color", Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, 0.55))
	_titulo.add_theme_constant_override("shadow_offset_y", 8)
	_titulo.add_theme_constant_override("shadow_outline_size", 22)
	_palco.add_child(_titulo)

	var fita := PanelContainer.new()
	var sb := Flash.caixa(Flash.LARANJA, Flash.NAVY, 24, 5)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 2
	sb.content_margin_bottom = 8
	fita.add_theme_stylebox_override("panel", sb)
	var sub := Label.new()
	sub.text = "Programa Municipal de Memória Interativa"
	sub.add_theme_font_override("font", Flash.fonte_titulo())
	sub.add_theme_font_size_override("font_size", 34)
	sub.add_theme_color_override("font_color", Color.WHITE)
	sub.add_theme_color_override("font_outline_color", Flash.NAVY)
	sub.add_theme_constant_override("outline_size", 8)
	fita.add_child(sub)
	_palco.add_child(fita)
	fita.position = Vector2(LARGURA / 2.0 - 365.0, 192)
	fita.size = Vector2(730, 56)
	fita.rotation = deg_to_rad(-1.2)


func _montar_mascotes() -> void:
	# nome, centro x, altura, atraso do balanço
	var lista := [["taina", 175.0, 270.0, 0.0], ["quico", 645.0, 280.0, 0.35], ["bentinho", 405.0, 340.0, 0.7]]
	for m in lista:
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size = Vector2(m[2], m[2])
		holder.position = Vector2(m[1] - m[2] / 2.0, 676.0 - m[2])
		holder.pivot_offset = Vector2(m[2] / 2.0, m[2])
		holder.set_meta("fase", m[3])
		holder.add_child(Flash.imagem(Flash.mascote(m[0]), holder.size))
		_palco.add_child(holder)
		_mascotes.append(holder)
		_base_y.append(holder.position.y)


func _montar_botoes() -> void:
	_btn_comecar = BotaoGel.new("Começar a visita", Flash.VERDE, 40)
	_btn_comecar.size = Vector2(400, 84)
	_btn_comecar.pressed.connect(func(): iniciar_visita(false))
	_palco.add_child(_btn_comecar)
	var tem_save: bool = GameState.tem_save()
	if tem_save:
		_btn_continuar = BotaoGel.new("Continuar", Flash.AZUL, 32)
		_btn_continuar.size = Vector2(260, 62)
		_btn_continuar.pressed.connect(func(): iniciar_visita(true))
		_palco.add_child(_btn_continuar)
		_btn_comecar.position = Vector2(785, 514)
		_btn_continuar.position = Vector2(855, 612)
	else:
		_btn_comecar.position = Vector2(785, 560)


func _montar_rodape() -> void:
	var aviso := Label.new()
	aviso.text = "Obra de ficção. Não representa a Prefeitura de Imbé."
	aviso.position = Vector2(760, 694)
	aviso.size = Vector2(500, 22)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_override("font", Flash.fonte_sistema())
	aviso.add_theme_font_size_override("font_size", 16)
	aviso.add_theme_color_override("font_color", Color.WHITE)
	aviso.add_theme_color_override("font_outline_color", Color("14522A"))
	aviso.add_theme_constant_override("outline_size", 5)
	_palco.add_child(aviso)
	var contador := Label.new()
	contador.text = "Visitantes: 000027"
	contador.position = Vector2(20, 692)
	contador.size = Vector2(280, 26)
	contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	contador.add_theme_font_override("font", Flash.fonte_erro())
	contador.add_theme_font_size_override("font_size", 22)
	contador.add_theme_color_override("font_color", Color("FFF6C0"))
	contador.add_theme_color_override("font_outline_color", Color("14522A"))
	contador.add_theme_constant_override("outline_size", 5)
	_palco.add_child(contador)


# ================================================================ ação
## Emite `comecar`. Chamada pelos botões (dentro do evento de clique) e pela tecla Enter/Espaço.
func iniciar_visita(continuar: bool) -> void:
	if _iniciado:
		return
	_iniciado = true
	Audio.sfx("selo", -4.0)
	comecar.emit(continuar)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.is_action_pressed("avancar_dialogo"):
		# Com um jogo salvo, Enter/Espaço CONTINUA (antes recomeçava e apagava o save sem avisar)
		iniciar_visita(GameState.tem_save())
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	_t += dt
	# mascotes e título pulam em passos de 12 fps ("tremidinho" de tween de Flash)
	var passo := floorf(_t * 12.0) / 12.0
	for i in _mascotes.size():
		var fase: float = _mascotes[i].get_meta("fase", 0.0)
		var s := sin((passo + fase) * 3.2)
		_mascotes[i].position.y = _base_y[i] - maxf(0.0, s) * 14.0
		_mascotes[i].scale = Vector2(1.0 + 0.02 * -s, 1.0 + 0.035 * s)
	if _titulo:
		_titulo.position.y = 62.0 + sin(passo * 2.4) * 3.0
