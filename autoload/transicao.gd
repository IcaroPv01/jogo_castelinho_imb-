extends CanvasLayer
## Fade preto e troca de "mundo" (nível). A cena principal (grupo "main") faz a troca de fato.

signal escureceu
signal clareou

var _rect: ColorRect
var ocupado := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func fade_out(dur := 0.6, cor := Color.BLACK) -> void:
	_rect.color = Color(cor.r, cor.g, cor.b, _rect.color.a)
	var t := create_tween()
	t.tween_property(_rect, "color:a", 1.0, dur)
	await t.finished
	escureceu.emit()


func fade_in(dur := 0.6) -> void:
	var t := create_tween()
	t.tween_property(_rect, "color:a", 0.0, dur)
	await t.finished
	clareou.emit()


## Troca o mundo atual por outra cena de nível. `spawn` = nome do Marker3D de chegada.
func ir_para(caminho_cena: String, spawn := "Spawn", dur := 0.6) -> void:
	if ocupado:
		return
	ocupado = true
	await fade_out(dur)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		await main.carregar_mundo(caminho_cena, spawn)
	await fade_in(dur)
	ocupado = false
