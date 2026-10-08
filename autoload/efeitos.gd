extends CanvasLayer
## Pós-processamento de tela ligado a GameState.corruption + moldura do Visor do Tempo.
##
## Camada 5: fica ABAIXO do HUD (10), das telas de UI e da Transicao (100).
## Em corruption 0 (e sem pulso/visor) a camada some e a imagem fica intacta (Ato I limpo).
## Subindo: pixelização leve, dithering/menos cores, dessaturação, vinheta, grão, aberração
## cromática e, acima de ~0.5, linhas de glitch. Detalhes no shader (shaders/pos_processamento).
##
## API estável:
##   Efeitos.pulso(intensidade, dur)   glitch forte momentâneo (susto). 1.0 = forte.
##   Efeitos.visor(ativo)              moldura do Visor (plástico vermelho, sépia, legenda, clique)
##                                     V2: a legenda mostra o ano do disco ("1967", "????" para o sem data) e,
##                                     com GameState.atencao > 0 (visita 3+), as lentes avermelham e pulsam
## Extras:
##   Efeitos.flash(dur, cor, forca)    clarão de cor sobre a imagem (não cobre o HUD)
##   Efeitos.aviso(texto, dur)         aviso curto no alto da tela, some sozinho (não é fala)
##   Efeitos.legenda_visor(texto)      frase didática embaixo do ano ("Em 1950, aqui era só areia!")
##   Efeitos.material_psx(cor, tex)    ShaderMaterial PSX (vertex snapping) que segue a corruption

const SHADER_POS := preload("res://shaders/pos_processamento.gdshader")
const SHADER_PSX := preload("res://shaders/psx_material.gdshader")

var corrupcao_visual := 0.0      # corruption suavizada (o que o shader está usando)
var visor_ativo := false

var _alvo_c := 0.0
var _pulso := 0.0
var _visor := 0.0
var _visor_alvo := 0.0
var _atencao := 0.0              # GameState.atencao suavizada (o que o shader usa)
var _rect: ColorRect
var _mat: ShaderMaterial
var _flash: ColorRect
var _tween_pulso: Tween
var _tween_flash: Tween
var _painel_legenda: PanelContainer
var _lbl_ano: Label
var _lbl_extra: Label
var _lbl_aviso: Label            # aviso curto no alto da tela (Efeitos.aviso)
var _tween_aviso: Tween
var _psx: Array[ShaderMaterial] = []
var _aquecendo := 0              # quadros em que o pós-processamento fica ligado só para compilar o shader


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_POS
	_rect = ColorRect.new()
	_rect.name = "PosProcessamento"
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	add_child(_rect)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)

	_montar_legenda()
	_montar_aviso()

	_alvo_c = GameState.corruption
	corrupcao_visual = _alvo_c
	GameState.corruption_mudou.connect(_on_corruption)
	GameState.epoca_mudou.connect(_on_epoca)


func _process(dt: float) -> void:
	# interpola suavemente (aproximação proporcional com velocidade mínima: chega exato)
	corrupcao_visual = move_toward(corrupcao_visual, _alvo_c, maxf(absf(_alvo_c - corrupcao_visual) * 3.0, 0.08) * dt)
	_visor = move_toward(_visor, _visor_alvo, dt * (7.0 if _visor_alvo > _visor else 9.0))
	_atencao = move_toward(_atencao, GameState.atencao if _visor_alvo > 0.5 else 0.0, dt * 2.5)
	var ligado := corrupcao_visual > 0.003 or _pulso > 0.002 or _visor > 0.002 or _aquecendo > 0
	if _aquecendo > 0:
		_aquecendo -= 1
	if ligado != _rect.visible:
		_rect.visible = ligado
	if ligado:
		_mat.set_shader_parameter("corrupcao", corrupcao_visual)
		_mat.set_shader_parameter("pulso", _pulso)
		_mat.set_shader_parameter("visor", _visor)
		_mat.set_shader_parameter("atencao", _atencao)


## Liga o pós-processamento por alguns quadros (com a tela de carregamento por cima) para o shader ser compilado
## agora, e não na primeira vez em que o jogador segurar Q ou levar um susto.
func aquecer() -> void:
	_aquecendo = 3


func _on_corruption(v: float) -> void:
	_alvo_c = v
	for m in _psx:
		m.set_shader_parameter("snap", _snap_para(v))


# ---------------------------------------------------------------- API
## Glitch forte momentâneo: use em sustos. `intensidade` 0..1 (pode passar de 1 para exagerar).
func pulso(intensidade := 1.0, dur := 0.3) -> void:
	if _tween_pulso and _tween_pulso.is_valid():
		_tween_pulso.kill()
	_pulso = clampf(maxf(intensidade, _pulso * 0.5), 0.0, 1.5)
	_tween_pulso = create_tween()
	_tween_pulso.tween_property(self, "_pulso", 0.0, maxf(dur, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Liga/desliga a moldura do Visor do Tempo (plástico vermelho, dois olhos, sépia, legenda).
## Toca o clique de slide e dá um clarão. A época mostrada na legenda vem de GameState.epoca.
func visor(ativo: bool) -> void:
	if ativo == visor_ativo:
		return
	visor_ativo = ativo
	_visor_alvo = 1.0 if ativo else 0.0
	_painel_legenda.visible = ativo
	if ativo:
		_atualizar_legenda()
		_lbl_extra.text = ""
		_lbl_extra.visible = false
	flash(0.3, Color(1.0, 0.97, 0.9), 0.85)
	Audio.sfx("slide")


## Frase didática sob o ano da legenda do Visor ("" apaga).
func legenda_visor(texto: String) -> void:
	_lbl_extra.text = texto
	_lbl_extra.visible = texto != ""


## Aviso curto e discreto no alto da tela (não bloqueia nada, some sozinho). Não é fala de personagem.
func aviso(texto: String, dur := 2.0) -> void:
	if _lbl_aviso == null:
		return
	if _tween_aviso and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_lbl_aviso.text = texto
	_lbl_aviso.modulate.a = 1.0
	_lbl_aviso.visible = true
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(maxf(dur, 0.2))
	_tween_aviso.tween_property(_lbl_aviso, "modulate:a", 0.0, 0.5)
	_tween_aviso.tween_callback(func(): _lbl_aviso.visible = false)


## Clarão por cima da imagem (abaixo do HUD). `forca` = opacidade inicial.
func flash(dur := 0.3, cor := Color.WHITE, forca := 1.0) -> void:
	if _tween_flash and _tween_flash.is_valid():
		_tween_flash.kill()
	_flash.color = Color(cor.r, cor.g, cor.b, clampf(forca, 0.0, 1.0))
	_tween_flash = create_tween()
	_tween_flash.tween_property(_flash, "color:a", 0.0, maxf(dur, 0.02)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Material PSX (shaders/psx_material.gdshader) cujo vertex snapping piora com a corruption.
func material_psx(cor := Color.WHITE, textura: Texture2D = null, escala_uv := Vector2.ONE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_PSX
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("escala_uv", escala_uv)
	m.set_shader_parameter("snap", _snap_para(GameState.corruption))
	if textura:
		m.set_shader_parameter("tex", textura)
		m.set_shader_parameter("usa_tex", true)
	_psx.append(m)
	return m


func _snap_para(c: float) -> float:
	return lerpf(900.0, 110.0, smoothstep(0.1, 0.9, c))


# ---------------------------------------------------------------- aviso curto
func _montar_aviso() -> void:
	_lbl_aviso = Label.new()
	_lbl_aviso.name = "Aviso"
	_lbl_aviso.visible = false
	_lbl_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_aviso.offset_top = 120.0   # abaixo do olho da atenção
	_lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_aviso.add_theme_font_size_override("font_size", 18)
	_lbl_aviso.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_lbl_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_aviso.add_theme_constant_override("outline_size", 6)
	add_child(_lbl_aviso)


# ---------------------------------------------------------------- legenda do Visor
func _montar_legenda() -> void:
	_painel_legenda = PanelContainer.new()
	_painel_legenda.name = "LegendaVisor"
	_painel_legenda.visible = false
	_painel_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_legenda.anchor_left = 1.0
	_painel_legenda.anchor_right = 1.0
	_painel_legenda.offset_left = -24.0
	_painel_legenda.offset_right = -24.0
	_painel_legenda.offset_top = 22.0
	_painel_legenda.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.92, 0.74)
	sb.border_color = Color(0.25, 0.05, 0.05)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	_painel_legenda.add_theme_stylebox_override("panel", sb)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 0)
	_painel_legenda.add_child(caixa)
	var tit := Label.new()
	tit.text = "VISOR DO TEMPO"
	tit.add_theme_font_size_override("font_size", 12)
	tit.add_theme_color_override("font_color", Color(0.5, 0.1, 0.1))
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(tit)
	_lbl_ano = Label.new()
	_lbl_ano.add_theme_font_size_override("font_size", 40)
	_lbl_ano.add_theme_color_override("font_color", Color(0.15, 0.04, 0.04))
	_lbl_ano.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(_lbl_ano)
	_lbl_extra = Label.new()
	_lbl_extra.add_theme_font_size_override("font_size", 14)
	_lbl_extra.add_theme_color_override("font_color", Color(0.25, 0.08, 0.08))
	_lbl_extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_extra.visible = false
	caixa.add_child(_lbl_extra)
	add_child(_painel_legenda)


func _atualizar_legenda() -> void:
	_lbl_ano.text = str(GameState.NOMES_EPOCA.get(int(GameState.epoca), "????"))


func _on_epoca(_e: int) -> void:
	if visor_ativo:
		_atualizar_legenda()
