class_name BotaoGel
extends Button
## Botão "gel" dos anos 2000: cor chapada, contorno grosso, reflexo branco na metade de cima,
## sombra dura e "boing" (cresce) ao passar o mouse.
##
##   var b := BotaoGel.new("Começar a visita", Flash.VERDE, 34)
##   b.pressed.connect(...)
##
## Ele usa Audio.sfx("clique") ao clicar e Audio.sfx("boing") ao passar o mouse.

var cor := Flash.AZUL
var tamanho_fonte := 28
var som_hover := true
var margem_h := 28           # margem interna esquerda/direita (botões lado a lado usam menos)
var _brilho: Panel
var _tween: Tween


func _init(texto := "", cor_botao := Flash.AZUL, tam_fonte := 28) -> void:
	text = texto
	cor = cor_botao
	tamanho_fonte = tam_fonte


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", Flash.fonte_titulo())
	add_theme_font_size_override("font_size", tamanho_fonte)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color("FFF6C0"))
	add_theme_color_override("font_disabled_color", Color("DDE2EA"))
	add_theme_color_override("font_outline_color", Flash.NAVY)
	add_theme_constant_override("outline_size", maxi(4, tamanho_fonte / 6))
	_aplicar_estilos()

	_brilho = Panel.new()
	_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.34)
	sb.set_corner_radius_all(14)
	_brilho.add_theme_stylebox_override("panel", sb)
	add_child(_brilho)
	resized.connect(_ao_redimensionar)
	_ao_redimensionar()

	mouse_entered.connect(_ao_entrar)
	mouse_exited.connect(_ao_sair)
	button_down.connect(func(): Audio.sfx("clique"))


func definir_cor(nova: Color) -> void:
	cor = nova
	if is_inside_tree():
		_aplicar_estilos()


func _aplicar_estilos() -> void:
	var raio := 22
	var normal := Flash.caixa(cor, Flash.NAVY, raio, 5)
	var hover := Flash.caixa(cor.lightened(0.16), Flash.NAVY, raio, 5)
	var pressionado := Flash.caixa(cor.darkened(0.14), Flash.NAVY, raio, 5)
	pressionado.shadow_offset = Vector2(0, 1)
	var desativado := Flash.caixa(Flash.dessaturar(cor, 0.85).lightened(0.2), Color("6B7280"), raio, 5, false)
	for s: StyleBoxFlat in [normal, hover, pressionado, desativado]:
		s.content_margin_left = margem_h
		s.content_margin_right = margem_h
		s.content_margin_top = 10
		s.content_margin_bottom = 14
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressionado)
	add_theme_stylebox_override("disabled", desativado)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _ao_redimensionar() -> void:
	pivot_offset = size / 2.0
	if _brilho:
		_brilho.position = Vector2(10, 7)
		_brilho.size = Vector2(maxf(0.0, size.x - 20.0), maxf(0.0, size.y * 0.42))


func _ao_entrar() -> void:
	if disabled:
		return
	if som_hover:
		Audio.sfx("boing", -14.0)
	_animar(1.07)


func _ao_sair() -> void:
	_animar(1.0)


func _animar(escala: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * escala, 0.18)
