class_name ControlesToque
extends CanvasLayer
## Controles de toque para celular (módulo 8). Só existe quando `Celular.ativo` (o HUD cria e libera).
##
##   - Analógico flutuante nos 40% da esquerda: a base nasce onde o dedo pousa. Anda por Input.action_press de
##     "frente/tras/esquerda/direita" com força analógica (o Input.get_vector do Player e da costela continua valendo).
##   - Arrastar no resto da tela olha (Player.girar_olhar).
##   - Botões grandes embaixo à direita: Interagir, Correr (liga/desliga), Lanterna, Visor (segurar).
##     Pausa e Tela cheia no canto de cima à direita.
##   - Tocar num disco da faixa seleciona o disco (Visor.selecionar_slot).
##   - Toque rápido (< 0,3 s e < 24 px) na área de olhar avança a fala da Guia; com um balão que TRAVA o jogador,
##     qualquer toque avança.
##
## O toque é tratado aqui (InputEventScreenTouch/Drag, por índice de dedo, vários ao mesmo tempo). O clique de mouse
## emulado que o Godot gera junto é ignorado pelo Player e pela Guia quando `Celular.ativo`.
## Visual: estilo "Flash educativo", discreto (creme/azul-marinho semitransparente).

const RAIO_STICK := 74.0
const ZONA_STICK := 0.4          # fração da largura (a partir da esquerda) onde o analógico nasce
const ZONA_MORTA := 0.16
const TOQUE_S := 0.3
const TOQUE_PX := 24.0
const FOLGA := 10.0              # tolerância extra ao acertar um botão com o dedo
const R_GRANDE := Celular.R_GRANDE
const R_MEDIO := Celular.R_MEDIO
const ALFA := 0.6

## HUD.modo_cinema: esconde tudo.
var cinema := false
## Faixa de discos do HUD (para tocar num disco).
var faixa: FaixaDiscos
## Visível/ativo agora (jogando, sem tela cheia aberta, sem pausa).
var ligado := false
## Só para testes: tamanho de canvas fingido (no headless a janela não muda de tamanho).
var tam_forcado := Vector2.ZERO

var _tela: Control
var _dedos := {}                 # índice do dedo -> {t: tipo, ...}
var _stick_idx := -1
var _stick_base := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _vec := Vector2.ZERO         # -1..1 (x direita, y para baixo)
var _correr := false
var _visor_idx := -1
var _tem_alvo := false
var _player: Player
var _t := 0.0


class Tela extends Control:
	var dono: ControlesToque

	func _draw() -> void:
		if dono:
			dono._desenhar(self)


func _init() -> void:
	# Acima do HUD (10) e ABAIXO da caixa da Guia (20): o balão de fala cobre os botões em vez de ser coberto por eles.
	# A pausa (96), a Transição (100) e o aviso de retrato (128) ficam por cima de tudo.
	layer = 15
	name = "ControlesToque"


func _ready() -> void:
	_tela = Tela.new()
	(_tela as Tela).dono = self
	_tela.name = "Tela"
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.visible = false
	add_child(_tela)


func _exit_tree() -> void:
	_soltar_tudo()
	Celular.aplicar_escala(false)


# ================================================================ estado
func _deve_mostrar() -> bool:
	return Celular.ativo and GameState.jogando and not GameState.flag("ui_aberta") \
		and not get_tree().paused and not cinema and not Celular.retrato


func tamanho() -> Vector2:
	if tam_forcado != Vector2.ZERO:
		return tam_forcado
	return get_viewport().get_visible_rect().size


func _process(dt: float) -> void:
	_t += dt
	var quer := _deve_mostrar()
	Celular.aplicar_escala(quer)
	if quer != ligado:
		ligado = quer
		_tela.visible = quer
		if not quer:
			_soltar_tudo()
	if not ligado:
		return
	if _player == null or not is_instance_valid(_player):
		_achar_player()
	if _stick_idx >= 0:
		_aplicar_acoes()   # reafirma (outro código pode ter soltado a ação)
	_tela.queue_redraw()


func _achar_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_tem_alvo = false
	if _player:
		_player.alvo_mudou.connect(func(t: String): _tem_alvo = t != "")


func _tem_lanterna() -> bool:
	return bool(GameState.flag("tem_lanterna"))


func _tem_visor() -> bool:
	if get_tree().get_first_node_in_group(Visor.GRUPO) == null:
		return false
	return bool(GameState.flag("tem_visor")) or not GameState.discos.is_empty()


# ================================================================ layout
## Botões: id -> {c: centro, r: raio}. Só os que existem agora (lanterna e visor dependem do progresso).
func layout() -> Dictionary:
	var vp := tamanho()
	var m := Celular.margens()
	var d := {}
	var inter := Vector2(vp.x - m.z - R_GRANDE - 6.0, vp.y - m.w - R_GRANDE - 6.0)
	d["interagir"] = {"c": inter, "r": R_GRANDE}
	d["correr"] = {"c": inter + Vector2(-(Celular.BOTOES_ESQ - 4.0), 14.0), "r": R_MEDIO}
	if _tem_lanterna():
		d["lanterna"] = {"c": inter + Vector2(-4.0, -122.0), "r": R_MEDIO}
	if _tem_visor():
		d["visor"] = {"c": inter + Vector2(-Celular.BOTOES_ESQ, -98.0), "r": R_MEDIO}
	var pausa := Vector2(vp.x - m.z - 34.0, m.y + 34.0)
	d["pausa"] = {"c": pausa, "r": 30.0}
	d["tela"] = {"c": pausa + Vector2(-76.0, 0.0), "r": 26.0}
	return d


func _acertou(b: Dictionary, pos: Vector2) -> bool:
	return pos.distance_to(b.c) <= float(b.r) + FOLGA


# ================================================================ entrada
func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if processar_toque(e.index, e.position, e.pressed):
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if processar_arraste(e.index, e.position, e.relative):
			get_viewport().set_input_as_handled()


## Dedo `idx` tocou (pressed) ou soltou. Devolve true se os controles usaram o toque. (Público para os testes.)
func processar_toque(idx: int, pos: Vector2, pressed: bool) -> bool:
	if not ligado:
		return false
	if pressed:
		if _dedos.has(idx):
			return true
		var lay := layout()
		for id: String in ["pausa", "tela", "interagir", "correr", "lanterna", "visor"]:
			if lay.has(id) and _acertou(lay[id], pos):
				_dedos[idx] = {"t": "botao", "id": id}
				_acionar(id, idx)
				return true
		if faixa and is_instance_valid(faixa):
			var slot := faixa.slot_em(pos)
			if slot >= 0:
				_dedos[idx] = {"t": "faixa"}
				var visor := get_tree().get_first_node_in_group(Visor.GRUPO) as Visor
				if visor:
					visor.selecionar_slot(slot)
				return true
		if Guia.bloqueando():
			Guia.avancar()
			_dedos[idx] = {"t": "ignorar"}
			return true
		var d := {"t": "olhar", "t0": Time.get_ticks_msec(), "p0": pos, "mov": 0.0}
		if pos.x < tamanho().x * ZONA_STICK and _stick_idx < 0:
			d["t"] = "stick"
			_stick_idx = idx
			_stick_base = pos
			_stick_pos = pos
			_vec = Vector2.ZERO
		_dedos[idx] = d
		return true
	# soltou
	if not _dedos.has(idx):
		return false
	var dedo: Dictionary = _dedos[idx]
	_dedos.erase(idx)
	match str(dedo.t):
		"stick":
			_soltar_stick()
			_se_toque_rapido(dedo)
		"olhar":
			_se_toque_rapido(dedo)
		"botao":
			if dedo.id == "visor":
				_visor_idx = -1
				Input.action_release("visor")
	return true


## Dedo `idx` arrastou para `pos` (`rel` = quanto andou). Devolve true se os controles usaram o evento.
func processar_arraste(idx: int, pos: Vector2, rel: Vector2) -> bool:
	if not ligado or not _dedos.has(idx):
		return false
	var d: Dictionary = _dedos[idx]
	match str(d.t):
		"stick":
			d["mov"] = float(d.mov) + rel.length()
			_mover_stick(pos)
		"olhar":
			d["mov"] = float(d.mov) + rel.length()
			if _player and is_instance_valid(_player):
				_player.girar_olhar(rel, Player.SENS_TOQUE * GameState.sensibilidade)
	return true


func _se_toque_rapido(dedo: Dictionary) -> void:
	var dur := (Time.get_ticks_msec() - int(dedo.t0)) / 1000.0
	if dur < TOQUE_S and float(dedo.mov) < TOQUE_PX:
		Guia.avancar()


# ================================================================ analógico
func _mover_stick(pos: Vector2) -> void:
	var v := pos - _stick_base
	var forca := v.length()
	if forca > RAIO_STICK:   # base "puxada" pelo dedo: nunca fica longe demais
		_stick_base += v.normalized() * (forca - RAIO_STICK)
		v = pos - _stick_base
	_stick_pos = pos
	_vec = (v / RAIO_STICK).limit_length(1.0)
	_aplicar_acoes()


func _aplicar_acoes() -> void:
	var v := _vec
	if v.length() < ZONA_MORTA:
		v = Vector2.ZERO
	_acao("frente", maxf(-v.y, 0.0))
	_acao("tras", maxf(v.y, 0.0))
	_acao("esquerda", maxf(-v.x, 0.0))
	_acao("direita", maxf(v.x, 0.0))
	if _correr:
		Input.action_press("correr")


func _acao(nome: String, forca: float) -> void:
	if forca > 0.01:
		Input.action_press(nome, forca)
	else:
		Input.action_release(nome)


func _soltar_stick() -> void:
	_stick_idx = -1
	_vec = Vector2.ZERO
	for a in ["frente", "tras", "esquerda", "direita"]:
		Input.action_release(a)
	_correr = false      # soltou o analógico: para de correr
	Input.action_release("correr")


func _soltar_tudo() -> void:
	_dedos.clear()
	_soltar_stick()
	_visor_idx = -1
	Input.action_release("visor")


# ================================================================ botões
func _acionar(id: String, idx: int) -> void:
	match id:
		"interagir", "lanterna":
			Audio.sfx("clique", -8.0)
			pulsar_acao(id)
		"correr":
			_correr = not _correr
			if _correr:
				Input.action_press("correr")
			else:
				Input.action_release("correr")
		"visor":
			_visor_idx = idx
			Input.action_press("visor")
		"pausa":
			Audio.sfx("clique", -8.0)
			Celular.pausa_toque = true
		"tela":
			_tela_cheia()


## Aperta e solta uma ação (como uma tecla). A ação fica apertada por alguns quadros para o `is_action_just_pressed`
## de quem consulta no _process também enxergar.
func pulsar_acao(nome: String) -> void:
	var ev := InputEventAction.new()
	ev.action = nome
	ev.pressed = true
	ev.strength = 1.0
	Input.action_press(nome)        # estado (is_action_pressed / just_pressed) ...
	Input.parse_input_event(ev)     # ... e o evento para os _input/_unhandled_input
	get_tree().create_timer(0.07).timeout.connect(Input.action_release.bind(nome))


func _tela_cheia() -> void:
	if Celular.eh_ios():
		Efeitos.aviso("No iPhone: toque em Compartilhar e depois em Adicionar à Tela de Início", 4.5)
		return
	var modo := DisplayServer.window_get_mode()
	var cheia: bool = modo == DisplayServer.WINDOW_MODE_FULLSCREEN or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ================================================================ desenho
func _desenhar(c: Control) -> void:
	var lay := layout()
	var vp := tamanho()
	var m := Celular.margens()
	# analógico: anel de dica quando parado; base + bolinha quando em uso
	if _stick_idx < 0:
		var dica := Vector2(m.x + 24.0 + RAIO_STICK, vp.y - m.w - 24.0 - RAIO_STICK)
		c.draw_arc(dica, RAIO_STICK, 0.0, TAU, 40, Color(Flash.CREME, 0.22), 4.0, true)
		c.draw_circle(dica, 22.0, Color(Flash.CREME, 0.12))
	else:
		c.draw_circle(_stick_base, RAIO_STICK, Color(Flash.CREME, 0.16))
		c.draw_arc(_stick_base, RAIO_STICK, 0.0, TAU, 40, Color(Flash.NAVY, 0.6), 6.0, true)
		c.draw_arc(_stick_base, RAIO_STICK, 0.0, TAU, 40, Color(Flash.CREME, 0.55), 3.0, true)
		var knob := _stick_base + _vec * RAIO_STICK
		c.draw_circle(knob, 34.0, Color(Flash.NAVY, 0.7))
		c.draw_circle(knob, 30.0, Color(Flash.CREME, 0.7))
	# botões
	for id: String in lay:
		var b: Dictionary = lay[id]
		var centro: Vector2 = b.c
		var raio: float = b.r
		var fundo := Color(Flash.CREME, ALFA)
		var pressionado := false
		for d in _dedos.values():
			if d.t == "botao" and d.id == id:
				pressionado = true
		match id:
			"interagir":
				if _tem_alvo:
					var pulso := 0.5 + 0.5 * sin(_t * 6.0)
					c.draw_circle(centro, raio + 8.0 + pulso * 6.0, Color(Flash.AMARELO, 0.25 + 0.2 * pulso))
					fundo = Color(Flash.AMARELO, 0.78)
			"correr":
				if _correr:
					fundo = Color(Flash.VERDE, 0.78)
			"lanterna":
				if _player and is_instance_valid(_player) and _player.lanterna.visible:
					fundo = Color(Flash.AMARELO, 0.7)
			"visor":
				if pressionado:
					fundo = Color(Flash.AZUL_CLARO, 0.85)
		if pressionado:
			fundo = fundo.darkened(0.12)
			raio *= 0.94
		c.draw_circle(centro + Vector2(0, 4), raio + 2.0, Color(Flash.NAVY, 0.3))   # sombra dura
		c.draw_circle(centro, raio + 3.0, Color(Flash.NAVY, 0.8))
		c.draw_circle(centro, raio, fundo)
		c.draw_arc(centro + Vector2(0, -raio * 0.18), raio * 0.7, PI * 1.15, PI * 1.85, 14, Color(1, 1, 1, 0.45), 4.0, true)
		match id:
			"pausa":
				c.draw_rect(Rect2(centro + Vector2(-11, -13), Vector2(8, 26)), Flash.NAVY)
				c.draw_rect(Rect2(centro + Vector2(3, -13), Vector2(8, 26)), Flash.NAVY)
			"tela":
				_icone_tela_cheia(c, centro)
			_:
				_rotulo(c, centro, raio, id)


func _rotulo(c: Control, centro: Vector2, raio: float, id: String) -> void:
	var txt: String = {"interagir": "Interagir", "correr": "Correr", "lanterna": "Lanterna", "visor": "Visor"}.get(id, id)
	var fonte := Flash.fonte_titulo()
	var tam := 22
	var larg := raio * 1.7
	while tam > 12 and fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > larg:
		tam -= 1
	var alt := fonte.get_ascent(tam) - fonte.get_descent(tam) * 0.2
	var ponto := centro + Vector2(-larg / 2.0, alt / 2.0 - 2.0)
	c.draw_string_outline(fonte, ponto, txt, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, 6, Color(Flash.CREME, 0.9))
	c.draw_string(fonte, ponto, txt, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, Flash.NAVY)


func _icone_tela_cheia(c: Control, centro: Vector2) -> void:
	var s := 12.0
	var l := 7.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var canto := centro + Vector2(sx * s, sy * s)
			c.draw_line(canto, canto - Vector2(sx * l, 0), Flash.NAVY, 4.0)
			c.draw_line(canto, canto - Vector2(0, sy * l), Flash.NAVY, 4.0)
