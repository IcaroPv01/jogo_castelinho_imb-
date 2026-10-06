class_name HUD
extends CanvasLayer
## HUD do jogo: contador de salas (estilo Spooky's), mira, aviso de interação, stamina.
## O estilo visual Flash (fontes, molduras) é aplicado pelo tema; aqui só a estrutura.

var lbl_sala: Label
var lbl_aviso: Label
var mira: Label
var barra_stamina: ProgressBar
var lbl_pausa: Label
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

	lbl_pausa = Label.new()
	lbl_pausa.text = "PAUSADO\nClique para continuar"
	lbl_pausa.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_pausa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pausa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_pausa.add_theme_font_override("font", Flash.fonte_titulo())
	lbl_pausa.add_theme_font_size_override("font_size", 52)
	lbl_pausa.add_theme_color_override("font_outline_color", Flash.NAVY)
	lbl_pausa.add_theme_constant_override("outline_size", 14)
	lbl_pausa.visible = false
	add_child(lbl_pausa)

	GameState.sala_mudou.connect(_on_sala)
	_on_sala(GameState.sala_atual)


func conectar_player(p: Player) -> void:
	# jogador novo (troca de nível, morte): o aviso "[E] ..." e a barra de fôlego do anterior não podem ficar na tela,
	# porque o novo jogador só emite os sinais quando o valor MUDA
	lbl_aviso.text = ""
	barra_stamina.value = 1.0
	barra_stamina.visible = false
	barra_stamina.modulate = Color.WHITE
	p.alvo_mudou.connect(func(t: String): lbl_aviso.text = ("[E] " + t) if t != "" else "")
	p.stamina_mudou.connect(func(v: float):
		barra_stamina.value = v
		barra_stamina.visible = v < 0.999
		barra_stamina.modulate = Color(1, 0.4, 0.4) if p.cansado else Color.WHITE)


func _on_sala(n: int) -> void:
	lbl_sala.text = "SALA %02d" % n if n > 0 else ""
	_t_glitch = 0.0


## Corrupção alta: de vez em quando o contador de salas mostra um número errado por um instante
## (a interface "mente sobre o progresso", PLANO §7.4).
func _process(dt: float) -> void:
	if GameState.sala_atual <= 0 or not visible:
		return
	if _t_glitch > 0.0:
		_t_glitch -= dt
		if _t_glitch <= 0.0:
			lbl_sala.text = "SALA %02d" % GameState.sala_atual
		return
	var c := GameState.corruption
	if c > 0.35 and randf() < dt * remap(c, 0.35, 1.0, 0.03, 0.4):
		_t_glitch = randf_range(0.08, 0.25)
		lbl_sala.text = "SALA %02d" % randi_range(1, 99)


func mostrar_pausa(v: bool) -> void:
	lbl_pausa.visible = v
