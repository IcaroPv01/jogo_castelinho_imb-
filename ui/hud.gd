class_name HUD
extends CanvasLayer
## HUD do jogo: contador de salas (estilo Spooky's), mira, aviso de interação, stamina.
## O estilo visual Flash (fontes, molduras) é aplicado pelo tema; aqui só a estrutura.
## V2: o contador diz "VISITA 2 · SALA 27" (no porão, só "SALA 87"); a faixa de discos do Visor (FaixaDiscos, canto
## de baixo à esquerda) e o olho da atenção (OlhoAtencao, no alto, no meio) vivem aqui.

var lbl_sala: Label
var lbl_aviso: Label
var mira: Label
var barra_stamina: ProgressBar
var lbl_pausa: Label
var menu_pausa: MenuPausa
## Contador das pistas do Tito (canto de cima à direita): escondido até a primeira.
var pistas_box: Control
var _lbl_pistas_n: Label
var _lbl_pistas_aviso: Label
var _n_pistas := 0
var _tween_pista: Tween
var lbl_passaporte: Label
var faixa_discos: FaixaDiscos
var olho: OlhoAtencao
## Só existem no celular (Celular.ativo): controles de toque e aviso "vire o celular". O HUD cria e libera.
var controles: ControlesToque
var aviso_retrato: AvisoRetrato
var _t_glitch := 0.0


func _ready() -> void:
	layer = 10
	lbl_sala = Label.new()
	lbl_sala.name = "Sala"
	lbl_sala.position = Vector2(24, 18)
	lbl_sala.add_theme_font_override("font", Flash.fonte_titulo())
	lbl_sala.add_theme_font_size_override("font_size", 36)
	lbl_sala.add_theme_color_override("font_outline_color", Flash.NAVY)
	lbl_sala.add_theme_constant_override("outline_size", 10)
	add_child(lbl_sala)

	lbl_passaporte = Label.new()
	lbl_passaporte.name = "Passaporte"
	lbl_passaporte.position = Vector2(26, 66)
	lbl_passaporte.add_theme_font_override("font", Flash.fonte_texto())
	lbl_passaporte.add_theme_font_size_override("font_size", 22)
	lbl_passaporte.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	lbl_passaporte.add_theme_color_override("font_outline_color", Flash.NAVY)
	lbl_passaporte.add_theme_constant_override("outline_size", 7)
	lbl_passaporte.visible = false
	add_child(lbl_passaporte)

	mira = Label.new()
	mira.text = "·"
	mira.add_theme_font_size_override("font_size", 40)
	mira.add_theme_constant_override("outline_size", 3)
	mira.set_anchors_preset(Control.PRESET_CENTER)
	mira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mira.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mira.position -= Vector2(20, 28)
	mira.size = Vector2(40, 40)
	add_child(mira)

	lbl_aviso = Label.new()
	lbl_aviso.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_aviso.position = Vector2(-300, -170)
	lbl_aviso.size = Vector2(600, 40)
	lbl_aviso.add_theme_font_override("font", Flash.fonte_texto())
	lbl_aviso.add_theme_font_size_override("font_size", 26)
	lbl_aviso.add_theme_color_override("font_outline_color", Flash.NAVY)
	lbl_aviso.add_theme_constant_override("outline_size", 8)
	add_child(lbl_aviso)

	barra_stamina = ProgressBar.new()
	barra_stamina.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barra_stamina.position = Vector2(-100, -40)
	barra_stamina.size = Vector2(200, 12)
	barra_stamina.show_percentage = false
	barra_stamina.max_value = 1.0
	barra_stamina.value = 1.0
	barra_stamina.visible = false
	add_child(barra_stamina)

	Opcoes.carregar()
	menu_pausa = MenuPausa.new()
	menu_pausa.name = "MenuPausa"
	# camada própria, acima das legendas e UIs dos níveis (até 90), mas abaixo da Transição (100)
	var camada_pausa := CanvasLayer.new()
	camada_pausa.name = "CamadaPausa"
	camada_pausa.layer = 96
	add_child(camada_pausa)
	camada_pausa.add_child(menu_pausa)
	lbl_pausa = menu_pausa.lbl_pausa   # (o _ready do menu já rodou ao entrar na árvore)

	_construir_pistas()
	faixa_discos = FaixaDiscos.new()
	faixa_discos.name = "FaixaDiscos"
	add_child(faixa_discos)
	olho = OlhoAtencao.new()
	olho.name = "OlhoAtencao"
	add_child(olho)

	GameState.flag_mudou.connect(_on_flag)
	GameState.sala_mudou.connect(_on_sala)
	GameState.visita_mudou.connect(func(_v): _on_sala(GameState.sala_atual))
	_on_sala(GameState.sala_atual)
	get_viewport().size_changed.connect(func():
		Celular.recalcular_margens()
		_reposicionar())
	_sincronizar_toque.call_deferred()


## Cria/libera os controles de toque conforme `Celular.ativo` (a opção "Controles de toque" vale na hora).
func _sincronizar_toque() -> void:
	if not is_inside_tree():
		return
	if Celular.ativo:
		if controles == null:
			controles = ControlesToque.new()
			controles.faixa = faixa_discos
			controles.cinema = _cinema
			add_child(controles)
		if aviso_retrato == null and get_parent():
			aviso_retrato = AvisoRetrato.new()
			get_parent().add_child(aviso_retrato)
	else:
		if controles:
			controles.queue_free()
			controles = null
		if aviso_retrato:
			aviso_retrato.queue_free()
			aviso_retrato = null
	var ligado: bool = controles != null
	if ligado != _toque_aplicado:
		_toque_aplicado = ligado
		Celular.aplicar_ambiente()
		_reposicionar()


var _toque_aplicado := false


## No celular o contador de salas e as pistas respeitam a área segura (entalhe) e deixam o canto de cima à direita
## para os botões de pausa e tela cheia. Desktop: posições originais.
func _reposicionar() -> void:
	if Celular.ativo:
		var m := Celular.margens()
		lbl_sala.position = Vector2(m.x + 12.0, m.y)
		lbl_passaporte.position = Vector2(m.x + 14.0, m.y + 50.0)
		pistas_box.position = Vector2(-170.0 - m.z, m.y + 78.0)
	else:
		lbl_sala.position = Vector2(24, 18)
		lbl_passaporte.position = Vector2(26, 66)
		pistas_box.position = Vector2(-190, 16)


func conectar_player(p: Player) -> void:
	# jogador novo (troca de nível, morte): o aviso "[E] ..." e a barra de fôlego do anterior não podem ficar na tela,
	# porque o novo jogador só emite os sinais quando o valor MUDA
	lbl_aviso.text = ""
	barra_stamina.value = 1.0
	barra_stamina.visible = false
	barra_stamina.modulate = Color.WHITE
	_sincronizar_pistas()
	p.alvo_mudou.connect(func(t: String): lbl_aviso.text = (Celular.dica("[E] ", "") + t) if t != "" else "")
	p.stamina_mudou.connect(func(v: float):
		barra_stamina.value = v
		barra_stamina.visible = v < 0.999
		barra_stamina.modulate = Color(1, 0.4, 0.4) if p.cansado else Color.WHITE)


## Cenas de cinema (final do Braço Morto): esconde faixa de discos, contador de pistas, mira e aviso, para a imagem ficar
## limpa. `manter_sala` deixa o rótulo da sala (detalhe de terror). `modo_cinema(false)` devolve tudo ao estado normal.
var _cinema := false


func modo_cinema(ligado: bool, manter_sala := false) -> void:
	_cinema = ligado
	if controles:
		controles.cinema = ligado
	mira.visible = not ligado
	lbl_aviso.visible = not ligado
	lbl_sala.visible = (not ligado) or manter_sala
	faixa_discos.visible = (not ligado) and faixa_discos.discos_mostrados().size() > 0
	pistas_box.visible = (not ligado) and _n_pistas > 0


## "VISITA 2 · SALA 27"; no porão (salas 81+) só "SALA 87". `n` pode ser um número errado (glitch da corrupção).
func texto_sala(n: int) -> String:
	if n <= 0:
		return ""
	var visita := GameState.visita_da_sala(GameState.sala_atual if GameState.sala_atual > 0 else n)
	if visita >= 5:
		return "SALA %02d" % n
	return "VISITA %d · SALA %02d" % [visita, n]


func _on_sala(n: int) -> void:
	lbl_sala.text = texto_sala(n)
	_t_glitch = 0.0


## Corrupção alta: de vez em quando o contador de salas mostra um número errado por um instante
## (a interface "mente sobre o progresso", PLANO §7.4).
func _process(dt: float) -> void:
	if Celular.ativo != (controles != null):
		_sincronizar_toque()
	_atualizar_passaporte()
	_sincronizar_pistas()
	if GameState.sala_atual <= 0 or not visible:
		return
	if _t_glitch > 0.0:
		_t_glitch -= dt
		if _t_glitch <= 0.0:
			lbl_sala.text = texto_sala(GameState.sala_atual)
		return
	var c := GameState.corruption
	if c > 0.35 and randf() < dt * remap(c, 0.35, 1.0, 0.03, 0.4):
		_t_glitch = randf_range(0.08, 0.25)
		lbl_sala.text = texto_sala(randi_range(1, 99))


## "Passaporte 1/3": só na visita 1, depois do convite do Bentinho, até completar (ou ter o disco 1950).
func _atualizar_passaporte() -> void:
	var n := GameState.passaporte_achados()
	var ativo: bool = GameState.visita == 1 and GameState.flag("passaporte_lancado") \
		and not GameState.discos.has(GameState.Epoca.E1950) and n < GameState.PASSAPORTE_IDS.size()
	lbl_passaporte.visible = ativo
	if ativo:
		lbl_passaporte.text = "Passaporte %d/%d" % [n, GameState.PASSAPORTE_IDS.size()]


func mostrar_pausa(v: bool) -> void:
	menu_pausa.mostrar(v, GameState.contadores.get("pistas_tito", 0))


# ---------------------------------------------------------------- pistas do Tito
## Um "T" de giz de cabeça para baixo (a assinatura do Tito): barra embaixo, haste para cima.
class IconeT extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(34, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var giz := Color(0.96, 0.95, 0.88)
		var sombra := Color(0.08, 0.1, 0.25, 0.8)
		for passo in [[sombra, Vector2(2, 2), 9.0], [giz, Vector2.ZERO, 5.0]]:
			var o: Vector2 = passo[1]
			var w: float = passo[2]
			draw_line(Vector2(4, 35) + o, Vector2(30, 34) + o, passo[0], w, true)    # barra (embaixo)
			draw_line(Vector2(17, 34) + o, Vector2(16, 5) + o, passo[0], w, true)    # haste (para cima)


func _construir_pistas() -> void:
	pistas_box = HBoxContainer.new()
	pistas_box.name = "PistasTito"
	pistas_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pistas_box.position = Vector2(-190, 16)
	pistas_box.size = Vector2(170, 50)
	pistas_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pistas_box.alignment = BoxContainer.ALIGNMENT_END
	pistas_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pistas_box.visible = false
	add_child(pistas_box)
	_lbl_pistas_aviso = Label.new()
	_lbl_pistas_aviso.text = "pista do Tito"
	_lbl_pistas_aviso.add_theme_font_override("font", Flash.fonte_texto())
	_lbl_pistas_aviso.add_theme_font_size_override("font_size", 20)
	_lbl_pistas_aviso.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	_lbl_pistas_aviso.add_theme_color_override("font_outline_color", Flash.NAVY)
	_lbl_pistas_aviso.add_theme_constant_override("outline_size", 6)
	_lbl_pistas_aviso.modulate.a = 0.0
	pistas_box.add_child(_lbl_pistas_aviso)
	pistas_box.add_child(IconeT.new())
	_lbl_pistas_n = Label.new()
	_lbl_pistas_n.add_theme_font_override("font", Flash.fonte_titulo())
	_lbl_pistas_n.add_theme_font_size_override("font_size", 34)
	_lbl_pistas_n.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	_lbl_pistas_n.add_theme_color_override("font_outline_color", Flash.NAVY)
	_lbl_pistas_n.add_theme_constant_override("outline_size", 9)
	pistas_box.add_child(_lbl_pistas_n)
	pistas_box.pivot_offset = Vector2(150, 25)


## Mostra o número certo sem animar (carregar save, nível novo, jogo novo zerando o contador).
func _sincronizar_pistas() -> void:
	var n: int = GameState.contadores.get("pistas_tito", 0)
	if n == _n_pistas:
		return
	_n_pistas = n
	_lbl_pistas_n.text = str(n)
	pistas_box.visible = n > 0 and not _cinema


## `set_flag` avisa ANTES de o contador somar: espera o fim do quadro para ler o número novo.
func _on_flag(nome: String, valor: Variant) -> void:
	if nome.begins_with("pista_") and valor == true:
		_pista_nova.call_deferred()


func _pista_nova() -> void:
	_sincronizar_pistas()
	if _n_pistas <= 0:
		return
	Audio.sfx("pista", -4.0)
	if _tween_pista:
		_tween_pista.kill()
	pistas_box.scale = Vector2.ONE
	_lbl_pistas_aviso.modulate.a = 1.0
	_lbl_pistas_n.modulate = Color(1.0, 0.95, 0.5)
	_tween_pista = create_tween().set_parallel(true)
	_tween_pista.tween_property(pistas_box, "scale", Vector2.ONE * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_pista.chain().tween_property(pistas_box, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	_tween_pista.tween_property(_lbl_pistas_n, "modulate", Color.WHITE, 1.2).set_delay(0.3)
	_tween_pista.tween_property(_lbl_pistas_aviso, "modulate:a", 0.0, 0.8).set_delay(2.2)
