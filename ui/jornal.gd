class_name Jornal
extends CanvasLayer
## Recorte de jornal amarelado em tela cheia, entre o fim da visita 2 e o começo da visita 3: o único momento em que o
## jogo diz, em letra de imprensa, que o Tito sumiu (jornal FICTÍCIO, de um litoral norte genérico; nada de caso real).
##
##   await Jornal.exibir_uma_vez()      # só uma vez por save (flag "jornal_1967_visto"); volta quando o jogador fecha
##   Jornal.mostrar()                   # ou direto, devolvendo o nó (sinal `terminou`)
##
## Fecha com clique, toque, E, Espaço ou Enter, mas só depois de MIN_LEITURA s (a dica aparece nessa hora). Enquanto
## está aberto liga `ui_aberta` (Flash.abrir_ui) e trava o jogador. Cobre a tela inteira (camada 110, como a VolteSempre).
## O retrato é o da arte do cartaz de PROCURA-SE (TitoCastelinho), em tons de sépia.

signal terminou

const FLAG := "jornal_1967_visto"
const MIN_LEITURA := 3.0
const MASTRO := "FOLHA DO VERANEIO"
const DATA := "Litoral Norte · terça-feira, 14 de março de 1967"
const MANCHETE := "MENINO DE 9 ANOS DESAPARECE NO IMBÉ"
const CORPO := "Tito, 9 anos, filho de veranistas, não voltou para casa no domingo (12). Foi visto pela última vez brincando na areia perto da obra do castelinho, com um balde vermelho. Pescadores e voluntários procuram nas margens do Braço Morto. A família pede informações pelo fone 4-27."
const RODAPE := "jornal fictício · Castelinho: Visita Guiada"
const PAPEL := Color(0.87, 0.79, 0.57)
const TINTA := Color(0.14, 0.11, 0.08)
const LARG := 1040.0
const ALT := 640.0
const FONTE_CORPO := 27
const FONTE_MIN := 14           # nada na página fica menor que isso (legível no celular)

var _feito := false
var _t := 0.0
var _fundo: ColorRect
var _folha: Control
var _dica: Label


## Mostra o recorte uma única vez por save. Sem await o jogo não espera; com await volta quando o jogador fecha.
static func exibir_uma_vez() -> void:
	if GameState.flag(FLAG):
		return
	GameState.set_flag(FLAG, true)
	var j := mostrar()
	await j.terminou


static func mostrar() -> Jornal:
	var j := Jornal.new()
	Flash.raiz().add_child.call_deferred(j)
	return j


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	Flash.abrir_ui()
	Audio.sfx("slide", -8.0, 0.8)
	_fundo.modulate.a = 0.0
	_folha.modulate.a = 0.0
	var pos := _folha.position
	_folha.position = pos + Vector2(0, 40)
	var t := create_tween().set_parallel()
	t.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	t.tween_property(_folha, "modulate:a", 1.0, 0.6)
	t.tween_property(_folha, "position", pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fonte de imprensa: Arimo (a fonte "institucional" do jogo) bem pesada, o mais perto de um título de jornal que há aqui.
static func _fonte(peso: float, emb := 0.0) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load(Flash.CAMINHO_FONTES + "Arimo-Latin.ttf")
	fv.variation_opentype = {Flash._tag_wght(): peso}
	fv.variation_embolden = emb
	return fv


func _rotulo(texto: String, pos: Vector2, tam: Vector2, fonte: Font, tamanho: int, cor := TINTA, alinhar := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART       # antes do texto e do tamanho: senão o tamanho mínimo vence
	l.horizontal_alignment = alinhar
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", maxi(tamanho, FONTE_MIN))
	l.add_theme_color_override("font_color", cor)
	l.add_theme_constant_override("outline_size", 0)
	l.text = texto
	l.position = pos
	l.size = tam
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(l)
	return l


func _linha(y: float, espessura: float) -> void:
	var r := ColorRect.new()
	r.color = TINTA
	r.position = Vector2(28, y)
	r.size = Vector2(LARG - 56, espessura)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(r)


func _construir() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0.04, 0.035, 0.03, 0.96)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_folha = Panel.new()
	_folha.anchor_left = 0.5
	_folha.anchor_right = 0.5
	_folha.anchor_top = 0.5
	_folha.anchor_bottom = 0.5
	_folha.offset_left = -LARG * 0.5
	_folha.offset_right = LARG * 0.5
	_folha.offset_top = -ALT * 0.5 - 14.0
	_folha.offset_bottom = ALT * 0.5 - 14.0
	_folha.pivot_offset = Vector2(LARG, ALT) * 0.5
	_folha.rotation = deg_to_rad(-0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPEL
	sb.border_color = Color(0.36, 0.27, 0.15)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(6, 10)
	(_folha as Panel).add_theme_stylebox_override("panel", sb)
	add_child(_folha)

	# envelhecimento: bordas escurecidas, dobras e a marca de um copo (um Control que desenha por cima do papel)
	var vel := Control.new()
	vel.set_anchors_preset(Control.PRESET_FULL_RECT)
	vel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vel.draw.connect(func() -> void:
		var tam := vel.size
		for i in 14:
			var a := 0.2 * pow(1.0 - float(i) / 14.0, 2.0)
			var cor := Color(0.45, 0.28, 0.08, a)
			vel.draw_rect(Rect2(i * 3, 0, 3, tam.y), cor)
			vel.draw_rect(Rect2(tam.x - (i + 1) * 3, 0, 3, tam.y), cor)
			vel.draw_rect(Rect2(0, i * 3, tam.x, 3), cor)
			vel.draw_rect(Rect2(0, tam.y - (i + 1) * 3, tam.x, 3), cor)
		vel.draw_rect(Rect2(0, tam.y * 0.5 - 1, tam.x, 2), Color(0.3, 0.2, 0.08, 0.13))
		vel.draw_rect(Rect2(tam.x * 0.5 - 1, 0, 2, tam.y), Color(0.3, 0.2, 0.08, 0.1))
		vel.draw_arc(Vector2(tam.x - 120, tam.y - 100), 46.0, 0.0, TAU, 40, Color(0.4, 0.24, 0.08, 0.16), 5.0))
	_folha.add_child(vel)

	var f_mastro := _fonte(800.0, 0.5)
	var f_cab := _fonte(700.0, 0.35)
	var f_txt := _fonte(500.0)
	_rotulo(MASTRO, Vector2(28, 10), Vector2(LARG - 56, 70), f_mastro, 58)
	_linha(84, 4)
	_rotulo(DATA, Vector2(28, 92), Vector2(LARG - 56, 30), f_txt, 20)
	_linha(126, 2)
	_rotulo(MANCHETE, Vector2(34, 140), Vector2(LARG - 68, 110), f_cab, 46)
	_linha(258, 2)

	# retrato: a arte do cartaz de PROCURA-SE em sépia, com a moldura de uma foto de jornal
	var moldura := Panel.new()
	moldura.position = Vector2(34, 278)
	moldura.size = Vector2(236, 312)
	var sbm := StyleBoxFlat.new()
	sbm.bg_color = Color(0.3, 0.22, 0.12)
	sbm.set_border_width_all(0)
	moldura.add_theme_stylebox_override("panel", sbm)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_folha.add_child(moldura)
	var retrato := TextureRect.new()
	retrato.texture = TitoCastelinho.textura("procura_se")
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.position = Vector2(5, 5)
	retrato.size = Vector2(226, 302)
	retrato.modulate = Color(0.92, 0.82, 0.62)
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(retrato)

	_rotulo(CORPO, Vector2(296, 282), Vector2(LARG - 296 - 34, 290), f_txt, FONTE_CORPO, TINTA, HORIZONTAL_ALIGNMENT_LEFT).add_theme_constant_override("line_spacing", 6)
	_rotulo(RODAPE, Vector2(28, ALT - 40), Vector2(LARG - 56, 26), f_txt, FONTE_MIN, Color(TINTA, 0.65))

	_dica = Label.new()
	_dica.text = Celular.dica("Clique, E ou Espaço para continuar", "Toque para continuar")
	_dica.anchor_left = 0.5
	_dica.anchor_right = 0.5
	_dica.anchor_top = 1.0
	_dica.anchor_bottom = 1.0
	_dica.offset_left = -320.0
	_dica.offset_right = 320.0
	_dica.offset_top = -52.0
	_dica.offset_bottom = -16.0
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_override("font", Flash.fonte_sistema())
	_dica.add_theme_font_size_override("font_size", 18)
	_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_dica.modulate.a = 0.0
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dica)


func _process(dt: float) -> void:
	if _feito:
		return
	_t += dt
	_dica.modulate.a = clampf((_t - MIN_LEITURA) * 2.0, 0.0, 1.0)


## Já passou o tempo mínimo de leitura (a dica de "continuar" está na tela)?
func pode_fechar() -> bool:
	return not _feito and _t >= MIN_LEITURA


func continuar() -> void:
	if _feito:
		return
	_feito = true
	Flash.fechar_ui()
	terminou.emit()
	var t := create_tween().set_parallel()
	t.tween_property(_folha, "modulate:a", 0.0, 0.3)
	t.tween_property(_fundo, "modulate:a", 0.0, 0.3)
	t.tween_property(_dica, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)


func _input(e: InputEvent) -> void:
	if _feito or not pode_fechar():
		return
	var avanca := false
	if e is InputEventKey and e.pressed and not e.echo:
		avanca = e.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or e.is_action_pressed("interagir") or e.is_action_pressed("avancar_dialogo")
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		avanca = true
	elif e is InputEventScreenTouch and e.pressed:
		avanca = true
	if avanca:
		continuar()
		get_viewport().set_input_as_handled()
