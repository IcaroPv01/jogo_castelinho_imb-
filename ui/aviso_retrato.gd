class_name AvisoRetrato
extends CanvasLayer
## "Vire o celular para jogar deitado": cobre tudo quando o celular está em pé (altura > largura).
## Atualiza `Celular.retrato`, que o main.gd usa para pausar o jogo. Só existe com `Celular.ativo` (o HUD cria).

## Só para testes: tamanho de canvas fingido (no headless a janela não muda de tamanho).
var tam_forcado := Vector2.ZERO

var _fundo: ColorRect
var _icone: Control
var _t := 0.0


class Icone extends Control:
	var t := 0.0

	func _draw() -> void:
		var c := size / 2.0
		var giro := sin(t * 2.0) * 0.5 - 0.3   # o celular "deita" e levanta
		draw_set_transform(c, giro, Vector2.ONE)
		var r := Rect2(Vector2(-26, -44), Vector2(52, 88))
		draw_rect(r.grow(5), Flash.CREME, true)
		draw_rect(r.grow(5), Flash.NAVY, false, 4.0)
		draw_rect(r, Flash.CEU, true)
		draw_circle(Vector2(0, 34), 5.0, Flash.NAVY)
		draw_set_transform(c, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, 82.0, -0.6, 1.9, 24, Flash.AMARELO, 7.0, true)   # seta de giro
		var ponta := Vector2(cos(1.9), sin(1.9)) * 82.0
		var dir := Vector2(-sin(1.9), cos(1.9))
		var lado := Vector2(cos(1.9), sin(1.9))
		draw_colored_polygon(PackedVector2Array([ponta + dir * 20.0, ponta + lado * 14.0, ponta - lado * 14.0]), Flash.AMARELO)


func _init() -> void:
	layer = 128   # acima de tudo, menos da tela de carregamento (130)
	name = "AvisoRetrato"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(Flash.NAVY.r * 0.5, Flash.NAVY.g * 0.5, Flash.NAVY.b * 0.5, 0.98)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP   # não deixa toque passar para o jogo
	_fundo.visible = false
	add_child(_fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.add_child(centro)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_child(col)
	_icone = Icone.new()
	_icone.custom_minimum_size = Vector2(220, 200)
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_icone)
	for linha in [["Vire o celular", 54], ["para jogar deitado", 40]]:
		var l := Label.new()
		l.text = linha[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", Flash.fonte_titulo())
		l.add_theme_font_size_override("font_size", linha[1])
		l.add_theme_color_override("font_color", Flash.CREME)
		l.add_theme_color_override("font_outline_color", Flash.NAVY)
		l.add_theme_constant_override("outline_size", 12)
		col.add_child(l)


func _exit_tree() -> void:
	Celular.retrato = false


## O canvas está em pé?
func em_pe() -> bool:
	var tam := tam_forcado if tam_forcado != Vector2.ZERO else get_viewport().get_visible_rect().size
	return tam.y > tam.x


func _process(dt: float) -> void:
	var pe := Celular.ativo and em_pe()
	if pe != Celular.retrato:
		Celular.retrato = pe
		Celular.aplicar_escala(false)   # em pé o canvas fica mais estreito (texto legível); deitado, os controles reajustam
	if _fundo.visible != pe:
		_fundo.visible = pe
	if pe:
		_t += dt
		(_icone as Icone).t = _t
		_icone.queue_redraw()
