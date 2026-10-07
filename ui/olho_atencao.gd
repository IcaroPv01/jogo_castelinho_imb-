class_name OlhoAtencao
extends Control
## O olho da atenção (V2 §4.3), no alto do HUD: um olho de desenho animado que vai se ABRINDO conforme
## `GameState.atencao` sobe (visita 3 em diante), com íris vermelha e, perto do máximo, veias. SEM número.
## Fechado e invisível com atenção 0; pulsa no ritmo do batimento. Só leitura (escuta `atencao_mudou`).
## O HUD o instancia; pode ser usado sozinho: `add_child(OlhoAtencao.new())`.

const LARG := 150.0
const ALT := 84.0

var _a := 0.0        # atenção suavizada (0..1)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -LARG / 2.0
	offset_right = LARG / 2.0
	offset_top = 14.0
	offset_bottom = 14.0 + ALT
	GameState.atencao_mudou.connect(func(_v): queue_redraw())
	visible = false


## Quanto o olho está aberto agora (0..1): para testes.
func abertura() -> float:
	return _a


func _process(dt: float) -> void:
	_t += dt
	_a = move_toward(_a, GameState.atencao, dt * 2.0)
	var deve := _a > 0.004
	if deve != visible:
		visible = deve
	if visible:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.004:
		return
	var a := _a
	var c := size / 2.0
	var pulso := 1.0 + 0.07 * a * sin(_t * (6.0 + 12.0 * a))
	var meia := 58.0 * pulso
	var h := lerpf(1.5, 30.0, pow(a, 0.8)) * pulso
	var alfa := clampf(a * 5.0, 0.0, 1.0)
	var topo := PackedVector2Array()
	var base := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var u := -1.0 + 2.0 * i / n
		var f := 1.0 - u * u
		topo.append(c + Vector2(u * meia, -h * f))
		base.append(c + Vector2(u * meia, h * 0.82 * f))
	var contorno := PackedVector2Array(topo)
	for i in range(n, -1, -1):
		contorno.append(base[i])
	if h > 3.0:
		draw_colored_polygon(contorno, Color(0.98, 0.94, 0.86, alfa))
		# íris vermelha e pupila (fenda), do tamanho que cabe dentro do olho
		var r_iris := minf(h * 0.82, 20.0)
		var olhar := Vector2(sin(_t * 0.9) * 8.0 * a, 0.0)
		draw_circle(c + olhar, r_iris, Color(0.80, 0.10, 0.12, alfa))
		draw_circle(c + olhar, r_iris * 0.62, Color(0.55, 0.03, 0.06, alfa))
		draw_rect(Rect2(c + olhar - Vector2(r_iris * 0.16, r_iris * 0.62), Vector2(r_iris * 0.32, r_iris * 1.24)), Color(0.04, 0.0, 0.02, alfa))
		draw_circle(c + olhar + Vector2(-r_iris * 0.3, -r_iris * 0.3), r_iris * 0.16, Color(1, 1, 1, alfa * 0.9))
		if a > 0.65:   # veias saltando do canto do olho
			var v := clampf(remap(a, 0.65, 1.0, 0.0, 1.0), 0.0, 1.0)
			for k in 5:
				var y := lerpf(-h * 0.6, h * 0.5, k / 4.0)
				var x0 := -meia * 0.92
				draw_line(c + Vector2(x0, y * 0.6), c + Vector2(x0 + (22.0 + 6.0 * k) * v, y * 0.35), Color(0.8, 0.1, 0.1, alfa * 0.8), 2.0)
				draw_line(c + Vector2(-x0, y * 0.6), c + Vector2(-x0 - (22.0 + 6.0 * k) * v, y * 0.35), Color(0.8, 0.1, 0.1, alfa * 0.8), 2.0)
	# pálpebras: o contorno do olho, em azul-marinho grosso (como o resto do HUD)
	draw_polyline(topo, Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, alfa), 5.0, true)
	draw_polyline(base, Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, alfa), 5.0, true)
	# cílios
	for i in 7:
		var u := -0.7 + 1.4 * i / 6.0
		var f := 1.0 - u * u
		var p := c + Vector2(u * meia, -h * f)
		draw_line(p, p + Vector2(u * 8.0, -9.0 - 4.0 * a), Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, alfa), 3.0)
