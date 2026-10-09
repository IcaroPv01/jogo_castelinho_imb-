class_name FaixaDiscos
extends Control
## Faixa de discos do Visor do Tempo (V2 §4.1), no canto de baixo à esquerda do HUD, estilo Flash:
## uma plaquinha creme com os discos que o jogador TEM (colorido, com furo e brilho), o selecionado em destaque
## (maior, erguido, dentro de um cursor amarelo que "desliza" de um disco para o outro) e o número da tecla (1..5)
## de cada um. Um disco novo aparece "pulando". Com o Visor bloqueado (atenção cheia, V2 §4.3) a faixa escurece e
## um anel mostra os segundos que faltam.
##
## É só leitura: escuta `GameState.discos_mudou` (e lê `GameState.discos` / `disco_atual`); quem seleciona é o
## `Visor` (teclas 1..5 e rolagem). O HUD a instancia; pode ser usada sozinha: `add_child(FaixaDiscos.new())`.

const ORDEM: Array[int] = [0, 4, 1, 2, 5]   # = Visor.ORDEM_DISCOS (E1950, E1967, E1975, E2019, ESEMDATA)
const LARG_SLOT := 78.0
const ALT := 108.0
const MARGEM := 24.0
const COR_DISCO := {0: Color("FFD23F"), 4: Color("5CCB4A"), 1: Color("FF9A2E"), 2: Color("2D8CFF"), 5: Color("3A2A5C")}
const ROTULO := {0: "1950", 4: "1967", 1: "1975", 2: "2019", 5: "????"}

var _meus: Array[int] = []        # épocas que o jogador tem, na ordem das teclas
var _cursor_x := -1.0              # posição (x do centro) do cursor, suavizada
var _pop := {}                     # época -> 0..1 (animação de entrada)
var _t := 0.0
var _caixa: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa = Flash.caixa(Color(Flash.CREME.r, Flash.CREME.g, Flash.CREME.b, 0.93), Flash.NAVY, 18, 4)
	GameState.discos_mudou.connect(_atualizar)
	_atualizar()
	if _meus.size() > 0:   # já tinha discos ao abrir: sem animação de entrada
		_pop.clear()
		_cursor_x = _alvo_x()


## Épocas que aparecem na faixa (para testes).
func discos_mostrados() -> Array[int]:
	return _meus


func _atualizar() -> void:
	var antigos := _meus.duplicate()
	_meus.clear()
	for ep in ORDEM:
		if ep in GameState.discos:
			_meus.append(ep)
	for ep in _meus:
		if ep not in antigos:
			_pop[ep] = 0.0
			if not antigos.is_empty() or _t > 0.0:
				Audio.sfx("selo", -6.0)
	var n := _meus.size()
	visible = n > 0
	size = Vector2(n * LARG_SLOT + 20.0, ALT + 12.0)
	_posicionar()
	queue_redraw()


## Canto de baixo à esquerda (calculado do tamanho da janela: sem anchors, que dependem do pai).
## No celular vai para o alto à esquerda, abaixo do contador de salas: o canto de baixo é do analógico.
func _posicionar() -> void:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	if Celular.ativo:
		var m := Celular.margens()
		position = Vector2(m.x + 12.0, m.y + 118.0)
		return
	position = Vector2(MARGEM, vp.y - MARGEM - size.y)


## Qual slot do Visor (0..4, a ordem das teclas 1..5) está sob o ponto `pos` (coordenadas do canvas)? -1 = nenhum.
## Usado pelos controles de toque: tocar num disco seleciona.
func slot_em(pos: Vector2) -> int:
	if not visible or _meus.is_empty():
		return -1
	var local := pos - global_position
	if local.y < -4.0 or local.y > size.y + 4.0 or local.x < 0.0 or local.x > size.x:
		return -1
	var i := int(floor((local.x - 10.0) / LARG_SLOT))
	if i < 0 or i >= _meus.size():
		return -1
	return ORDEM.find(_meus[i])


func _alvo_x() -> float:
	var i := _meus.find(GameState.disco_atual)
	if i < 0:
		return -1.0
	return 10.0 + LARG_SLOT * (i + 0.5)


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	_posicionar()
	var alvo := _alvo_x()
	if alvo >= 0.0:
		_cursor_x = alvo if _cursor_x < 0.0 else lerpf(_cursor_x, alvo, 1.0 - exp(-dt * 16.0))   # o "slide"
	for ep in _pop.keys():
		_pop[ep] = minf(1.0, _pop[ep] + dt * 3.2)
		if _pop[ep] >= 1.0:
			_pop.erase(ep)
	queue_redraw()


func _draw() -> void:
	if _meus.is_empty():
		return
	var bloq: bool = Visor.bloqueado()
	draw_style_box(_caixa, Rect2(Vector2.ZERO, size))
	var base_y := 12.0
	# cursor amarelo que desliza até o disco selecionado
	if _cursor_x >= 0.0:
		var cr := Rect2(_cursor_x - LARG_SLOT * 0.46, base_y - 4.0, LARG_SLOT * 0.92, ALT - 6.0)
		draw_style_box(Flash.caixa(Flash.AMARELO if not bloq else Color("9AA0AA"), Flash.NAVY, 14, 4, false), cr)
	var fonte_n := Flash.fonte_titulo()
	for i in _meus.size():
		var ep: int = _meus[i]
		var sel: bool = ep == GameState.disco_atual
		var cx := 10.0 + LARG_SLOT * (i + 0.5)
		var pop: float = _pop.get(ep, 1.0)
		var esc := (1.12 if sel else 0.86) * (1.0 if pop >= 1.0 else _overshoot(pop))
		var raio := 26.0 * esc
		var cy := base_y + 40.0 - (6.0 if sel else 0.0) - (0.0 if pop >= 1.0 else 30.0 * (1.0 - pop))
		cy += sin(_t * 3.0 + i) * (1.2 if sel else 0.0)
		_disco(Vector2(cx, cy), raio, COR_DISCO.get(ep, Color.GRAY), sel, bloq)
		# número da tecla (bolinha no canto de cima à esquerda do slot); no celular não há teclas
		if not Celular.ativo:
			var tag := Vector2(cx - 24.0, base_y + 6.0)
			draw_circle(tag, 11.0, Flash.NAVY)
			draw_circle(tag, 9.0, Color.WHITE)
			draw_string(fonte_n, tag + Vector2(-5.0, 6.0), str(ORDEM.find(ep) + 1), HORIZONTAL_ALIGNMENT_CENTER, 10.0, 16, Flash.NAVY)
		# ano embaixo
		var txt: String = ROTULO.get(ep, "")
		var ponta := Vector2(cx - 34.0, base_y + 86.0)
		draw_string_outline(fonte_n, ponta, txt, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 20, 6, Flash.NAVY)
		draw_string(fonte_n, ponta, txt, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 20, Color.WHITE if not bloq else Color("C8CCD4"))
	# dica discreta de teclas, logo acima da plaquinha (não ocupa espaço de outra UI)
	var dica := Celular.dica("1–5 ou rodinha: trocar · segure Q: ver", "toque no disco: trocar · segure Visor: ver") \
		if _meus.size() >= 2 else Celular.dica("segure Q: ver", "segure Visor: ver")
	var fd := Flash.fonte_titulo()
	var tam_dica := 22 if Celular.ativo else 15   # no celular: pelo menos do tamanho do ano dos discos (20)
	var borda_dica := 7 if Celular.ativo else 5
	draw_string_outline(fd, Vector2(4.0, -6.0), dica, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam_dica, borda_dica, Color(0, 0, 0, 0.8))
	draw_string(fd, Vector2(4.0, -6.0), dica, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam_dica, Color(1, 1, 1, 0.9))
	if bloq:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.1, 0.35))
		var frac := clampf(Visor.bloqueio_restante() / Visor.BLOQUEIO_S, 0.0, 1.0)
		var c := Vector2(size.x - 2.0, 4.0)
		draw_circle(c, 15.0, Flash.NAVY)
		draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 28, Color("FF5A4F"), 6.0)


static func _overshoot(p: float) -> float:
	# entrada com "overshoot" (estilo tween de Flash): 0 -> ~1.1 -> 1
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)


func _disco(c: Vector2, r: float, cor: Color, sel: bool, bloq: bool) -> void:
	if bloq:
		cor = Flash.dessaturar(cor, 0.85)
	elif not sel:
		cor = Flash.dessaturar(cor, 0.25)
	draw_circle(c, r + 3.0, Flash.NAVY)
	draw_circle(c, r, cor)
	draw_arc(c, r * 0.66, 0.0, TAU, 28, cor.darkened(0.3), 3.0)
	draw_arc(c, r * 0.82, -2.5, -1.2, 12, Color(1, 1, 1, 0.75), 3.5)      # brilho
	draw_circle(c, r * 0.30, Color("F4F0E4"))
	draw_circle(c, r * 0.30 + 1.5, Flash.NAVY, false, 2.0)
	draw_circle(c, r * 0.12, Flash.NAVY)
