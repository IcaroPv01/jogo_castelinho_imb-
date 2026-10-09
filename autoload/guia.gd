extends CanvasLayer
## Caixa de fala dos mascotes (Turma da Memória), estilo balão de Flash dos anos 2000:
## retrato do mascote, nome, texto "datilografado" e um blip por letra (Audio.sfx("blip_<personagem>")).
##
## API estável:
##   await Guia.falar("bentinho", ["Oi!", "Bem-vindo!"])        # o jogador continua andando; avança sozinho
##   await Guia.falar("taina", [...], true)                      # bloqueia o movimento até acabar
##   await Guia.falar_engasgado("bentinho", [...])               # sala 11: a voz engasga e repete
##   Guia.ocupado() -> bool          true se há fala na tela ou na fila
##   Guia.avancar()                  o mesmo que apertar espaço/Enter/clique (útil em testes)
##   Guia.cancelar()                 descarta a fala atual e a fila (troca de nível, morte)
## Sinal `fala_terminou`: emitido ao fim de cada chamada de falar().
## Personagens: "bentinho" (boto), "taina" (tainha), "quico" (quero-quero),
##   "sistema" (caixa cinza institucional, sem retrato), "???" (texto vermelho em VT323, sem retrato).
##
## Avanço: espaço, Enter ou clique. Com bloquear=false a fala também some sozinha depois de um tempo.
## Várias chamadas seguidas entram numa fila e são mostradas em ordem.
##
## Corrupção (GameState.corruption): acima de ~0.3 aparecem letras trocadas (o→0, a→4), o retrato
## "pisca" para a versão corrompida e a voz às vezes engasga ("vi-vi-vi-visita"). Quanto maior,
## mais frequente; a partir de ~0.6 a caixa perde as cores.

signal fala_terminou
signal linha_mostrada(personagem: String, texto: String)

class Fala extends RefCounted:
	signal terminou
	var personagem := ""
	var linhas: Array = []
	var bloquear := false
	var engasgar := false
	var concluida := false

const LARGURA := 1000.0
const ALTURA := 156.0
const CPS := 38.0   # letras por segundo
const CARENCIA := 0.25   # ignora "avançar" logo que a linha aparece (evita pular sem querer)

const PERSONAGENS := {
	"bentinho": {"nome": "Bentinho", "retrato": "bentinho", "blip": "blip_bentinho", "cor": Color("2D8CFF"),
		"balao": Color("FFF6DA"), "moldura": Color("BFE3FF"), "pitch": 1.0},
	"taina": {"nome": "Tainá", "retrato": "taina", "blip": "blip_taina", "cor": Color("FF5FA2"),
		"balao": Color("FFE6F1"), "moldura": Color("FFD0E4"), "pitch": 1.0},
	"quico": {"nome": "Quico", "retrato": "quico", "blip": "blip_quico", "cor": Color("FF9A2E"),
		"balao": Color("FFF3C9"), "moldura": Color("FFE29A"), "pitch": 1.0},
	"sistema": {"nome": "SISTEMA", "retrato": "", "blip": "blip_sistema", "cor": Color("5B6577"),
		"balao": Color("DADDE3"), "moldura": Color("DADDE3"), "pitch": 1.0},
	"???": {"nome": "???", "retrato": "", "blip": "blip_misterio", "cor": Color("5A0A12"),
		"balao": Color("0B0508"), "moldura": Color("0B0508"), "pitch": 1.0},
}

var _fila: Array[Fala] = []
var _pendentes := 0          # falas ainda não concluídas (na fila + a que está na tela)
var _processando := false
var _cancelar := false
var _ativo := false          # há uma fala na tela
var _digitando := false
var _esperando := false
var _pular := false
var _pedido_avanco := false
var _t_linha := 0.0          # segundos desde que a linha atual apareceu
var _personagem := ""
var _bloqueante := false     # a fala atual trava o jogador?
var _retrato_corrompido := false
var _t_glitch := 0.0         # tempo restante do retrato forçado como corrompido
var _prox_glitch := 1.5
var _tween_caixa: Tween
var _largura := LARGURA      # largura da caixa; no celular encolhe para terminar antes dos botões de toque
var _layout_celular := false

var _raiz: Control
var _caixa: Control
var _balao: Panel
var _texto: Label
var _cauda: Control
var _marco: Panel
var _retrato: TextureRect
var _tag: PanelContainer
var _nome: Label
var _seta: Control


class Cauda extends Control:
	var cor_fundo := Color.WHITE
	var cor_borda := Color("1B2250")

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(46, 6), Vector2(0, 30), Vector2(46, 50)])
		draw_colored_polygon(pts, cor_fundo)
		draw_polyline(PackedVector2Array([Vector2(46, 6), Vector2(0, 30), Vector2(46, 50)]), cor_borda, 5.0, true)
		draw_rect(Rect2(34, 8, 16, 40), cor_fundo)


class Seta extends Control:
	var cor := Color("2D8CFF")

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(26, 0), Vector2(13, 18)])
		draw_colored_polygon(pts, cor)
		draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(26, 0), Vector2(13, 18), Vector2(0, 0)]), Color("1B2250"), 3.0, true)


func _ready() -> void:
	layer = 20
	_construir()
	GameState.jogador_morreu.connect(func(_c): cancelar())


# ================================================================ API pública
func falar(personagem: String, linhas: Array, bloquear := false, engasgar := false) -> void:
	var f := Fala.new()
	f.personagem = personagem
	f.linhas = linhas.duplicate()
	f.bloquear = bloquear
	f.engasgar = engasgar
	_fila.append(f)
	_pendentes += 1
	_processar_fila()
	if not f.concluida:
		await f.terminou


func falar_engasgado(personagem: String, linhas: Array, bloquear := false) -> void:
	await falar(personagem, linhas, bloquear, true)


func ocupado() -> bool:
	return _pendentes > 0


## Há um balão na tela? / ele trava o jogador? (o celular usa para decidir o que um toque faz)
func visivel() -> bool:
	return _ativo


func bloqueando() -> bool:
	return _ativo and _bloqueante


func avancar() -> void:
	if not _ativo or _t_linha < CARENCIA:
		return
	if _digitando:
		_pular = true
	elif _esperando:
		_pedido_avanco = true


func cancelar() -> void:
	_cancelar = true
	for f in _fila:
		_concluir(f)
	_fila.clear()
	if not _processando:
		_cancelar = false
		_ocultar()


# ================================================================ fila e execução
func _processar_fila() -> void:
	if _processando:
		return
	_processando = true
	while not _fila.is_empty():
		var f: Fala = _fila.pop_front()
		await _executar(f)
		_concluir(f)
		fala_terminou.emit()
	_processando = false
	_cancelar = false
	_ocultar()


func _concluir(f: Fala) -> void:
	if not f.concluida:
		f.concluida = true
		_pendentes = maxi(0, _pendentes - 1)
		f.terminou.emit()


func _executar(f: Fala) -> void:
	_bloqueante = f.bloquear
	if f.bloquear:
		Flash.travar_jogador(true)
	var cfg := _config(f.personagem)
	for linha in f.linhas:
		if _cancelar:
			break
		await _mostrar_linha(f, cfg, str(linha))
	if f.bloquear:
		Flash.travar_jogador(false)


func _mostrar_linha(f: Fala, cfg: Dictionary, linha: String) -> void:
	_personagem = f.personagem
	var corr := GameState.corruption
	var info := _preparar_texto(f, linha, corr)
	_ajustar_largura()
	_estilizar(cfg, corr, str(info.texto).length())   # antes do texto: com autowrap, o tamanho do Label precisa estar certo primeiro
	_texto.text = info.texto
	_texto.visible_characters = 0
	_ativo = true
	_t_linha = 0.0
	_pular = false
	_pedido_avanco = false
	_mostrar()
	linha_mostrada.emit(f.personagem, info.texto)
	await _digitar(f, cfg, info, corr)
	_esperando = true
	_pedido_avanco = false
	var limite := 40.0 if f.bloquear else clampf(1.5 + 0.05 * str(info.texto).length(), 2.2, 8.0)
	var t := 0.0
	while not _pedido_avanco and not _cancelar and t < limite:
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time()
	_esperando = false


func _preparar_texto(f: Fala, linha: String, corr: float) -> Dictionary:
	var texto := Flash.corromper(Celular.adaptar(linha), corr)
	var info := {"texto": texto, "ini": -1, "fim": -1}
	var engasga := f.engasgar or (corr > 0.45 and randf() < (corr - 0.3) * 0.5)
	if engasga and f.personagem not in ["sistema", "???"]:
		info = Flash.engasgar(texto)
	return info


func _digitar(f: Fala, cfg: Dictionary, info: Dictionary, corr: float) -> void:
	var texto: String = info.texto
	var total := texto.length()
	var ini: int = info.ini
	var fim: int = info.fim
	var corte := -1
	var repeticoes := 0
	if f.engasgar and total > 12:
		corte = int(total * randf_range(0.45, 0.75))
		repeticoes = 2
	_digitando = true
	var i := 0
	var cont_blip := 0
	while i < total:
		if _pular or _cancelar:
			break
		i += 1
		_texto.visible_characters = i
		var ch := texto[i - 1]
		var no_engasgo := ini >= 0 and i - 1 >= ini and i - 1 < fim
		var d := 1.0 / CPS * (1.0 + corr * 0.5)
		if ch in ".!?":
			d += 0.2
		elif ch in ",;:":
			d += 0.1
		if no_engasgo:
			d = 0.07
		if ch != " ":
			cont_blip += 1
			if cont_blip % 2 == 1 or no_engasgo:
				var pitch := randf_range(0.93, 1.07) * (0.62 if no_engasgo else 1.0)
				Audio.sfx(cfg.blip, 0.0, pitch)
		if i == corte and repeticoes > 0:
			repeticoes -= 1
			await _rebobinar(i)
			i = maxi(0, i - 14)
			continue
		await get_tree().create_timer(d, false).timeout
	_texto.visible_characters = -1
	_digitando = false


## Efeito de "engasgo": a voz trava, o retrato corrompe, as letras voltam atrás e são digitadas de novo.
func _rebobinar(de: int) -> void:
	_t_glitch = 0.7
	_retrato_corrompido = true
	_atualizar_retrato()
	Audio.sfx("glitch", -6.0, randf_range(0.9, 1.1))
	if Efeitos.has_method("pulso"):
		Efeitos.pulso(0.5, 0.25)
	await get_tree().create_timer(0.3, false).timeout
	var n := maxi(0, de - 14)
	for k in range(de, n, -1):
		_texto.visible_characters = k
		await get_tree().create_timer(0.018, false).timeout
	await get_tree().create_timer(0.12, false).timeout


# ================================================================ aparência
func _config(personagem: String) -> Dictionary:
	if PERSONAGENS.has(personagem):
		return PERSONAGENS[personagem]
	return {"nome": personagem.capitalize(), "retrato": "", "blip": "blip_sistema", "cor": Color("5B6577"),
		"balao": Color("DADDE3"), "moldura": Color("DADDE3"), "pitch": 1.0}


func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.visible = false
	add_child(_raiz)

	_caixa = Control.new()
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.anchor_left = 0.5
	_caixa.anchor_right = 0.5
	_caixa.anchor_top = 1.0
	_caixa.anchor_bottom = 1.0
	_caixa.offset_left = -LARGURA / 2.0
	_caixa.offset_right = LARGURA / 2.0
	_caixa.offset_top = -ALTURA - 30.0
	_caixa.offset_bottom = -30.0
	_raiz.add_child(_caixa)

	_balao = Panel.new()
	_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao.position = Vector2(150, 0)
	_balao.size = Vector2(LARGURA - 150, ALTURA)
	_caixa.add_child(_balao)

	_texto = Label.new()
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_override("font", Flash.fonte_texto())
	_texto.add_theme_font_size_override("font_size", 28)
	_texto.add_theme_color_override("font_color", Flash.NAVY)
	_texto.add_theme_constant_override("outline_size", 0)
	_texto.add_theme_constant_override("line_spacing", -2)
	_caixa.add_child(_texto)

	_cauda = Cauda.new()
	_cauda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cauda.size = Vector2(52, 56)
	_cauda.position = Vector2(114, 46)
	_caixa.add_child(_cauda)

	_marco = Panel.new()
	_marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marco.position = Vector2(0, -40)
	_marco.size = Vector2(150, 150)
	_marco.pivot_offset = Vector2(75, 150)
	_caixa.add_child(_marco)

	_retrato = Flash.imagem(null, Vector2(134, 134), Vector2(8, 8))
	_marco.add_child(_retrato)

	_tag = PanelContainer.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.position = Vector2(182, -24)
	_nome = Label.new()
	_nome.add_theme_font_override("font", Flash.fonte_titulo())
	_nome.add_theme_font_size_override("font_size", 24)
	_nome.add_theme_color_override("font_color", Color.WHITE)
	_nome.add_theme_color_override("font_outline_color", Flash.NAVY)
	_nome.add_theme_constant_override("outline_size", 5)
	_tag.add_child(_nome)
	_caixa.add_child(_tag)

	_seta = Seta.new()
	_seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seta.size = Vector2(26, 18)
	_seta.position = Vector2(LARGURA - 56, ALTURA - 40)
	_seta.visible = false
	_caixa.add_child(_seta)


## No celular a caixa de fala vai da margem esquerda até antes do aglomerado de botões (Visor/Correr/...), encolhendo
## e quebrando o texto em mais linhas. No desktop não mexe em nada.
func _ajustar_largura() -> void:
	if Celular.ativo:
		var vp := get_viewport().get_visible_rect().size
		var x0 := Celular.margens().x + 12.0
		_largura = clampf(Celular.borda_botoes(vp.x) - 8.0 - x0, 560.0, LARGURA)
		_caixa.anchor_left = 0.0
		_caixa.anchor_right = 0.0
		_caixa.offset_left = x0
		_caixa.offset_right = x0 + _largura
		_layout_celular = true
	elif _layout_celular:
		_largura = LARGURA
		_caixa.anchor_left = 0.5
		_caixa.anchor_right = 0.5
		_caixa.offset_left = -LARGURA / 2.0
		_caixa.offset_right = LARGURA / 2.0
		_layout_celular = false
	_seta.position.x = _largura - 56.0


func _estilizar(cfg: Dictionary, corr: float, n_letras := 0) -> void:
	var t := Flash.fator_dessat(corr)
	var tem_retrato: bool = cfg.retrato != ""
	var cor_balao: Color = Flash.dessaturar(cfg.balao, t)
	var cor_nome: Color = Flash.dessaturar(cfg.cor, t)
	var misterio: bool = _personagem == "???"
	var sistema: bool = _personagem == "sistema"

	var sb_balao: StyleBoxFlat
	if misterio:
		sb_balao = Flash.caixa(cor_balao, Color("7A0010"), 6, 4, false)
	elif sistema:
		sb_balao = Flash.caixa(cor_balao, Color("6B7280"), 6, 3, false)
	else:
		sb_balao = Flash.caixa(cor_balao, Flash.NAVY, 24, 5)
	_balao.add_theme_stylebox_override("panel", sb_balao)
	_balao.position.x = 150.0 if tem_retrato else 0.0
	_balao.size.x = _largura - _balao.position.x
	var margem := 28.0
	_texto.position = Vector2(_balao.position.x + margem, 12)
	_texto.size = Vector2(_balao.size.x - margem * 2.0 - 30.0, ALTURA - 24)
	_texto.pivot_offset = _texto.size / 2.0

	if misterio:
		_texto.add_theme_font_override("font", Flash.fonte_erro())
		_texto.add_theme_font_size_override("font_size", 38)
		_texto.add_theme_color_override("font_color", Color("E01B24"))
	elif sistema:
		_texto.add_theme_font_override("font", Flash.fonte_sistema())
		_texto.add_theme_font_size_override("font_size", 24)
		_texto.add_theme_color_override("font_color", Color("2B2F3A"))
	else:
		var erro_fonte: bool = corr >= 0.75 and randf() < 0.35
		_texto.add_theme_font_override("font", Flash.fonte_erro() if erro_fonte else Flash.fonte_texto())
		var base := 30 if n_letras <= 100 else (27 if n_letras <= 170 else 24)
		_texto.add_theme_font_size_override("font_size", int(base * 1.2) if erro_fonte else base)
		_texto.add_theme_color_override("font_color", Flash.dessaturar(Flash.NAVY, t * 0.5))

	_cauda.visible = tem_retrato
	(_cauda as Cauda).cor_fundo = cor_balao
	_cauda.queue_redraw()
	_marco.visible = tem_retrato
	var sb_marco := Flash.caixa(Flash.dessaturar(cfg.moldura, t), Flash.NAVY, 75, 5)
	_marco.add_theme_stylebox_override("panel", sb_marco)

	_tag.visible = not misterio
	_tag.position.x = (182.0 if tem_retrato else 26.0)
	var sb_tag := Flash.caixa(cor_nome, Flash.NAVY, 16, 4)
	sb_tag.content_margin_left = 16
	sb_tag.content_margin_right = 16
	sb_tag.content_margin_top = 0
	sb_tag.content_margin_bottom = 2
	_tag.add_theme_stylebox_override("panel", sb_tag)
	_nome.text = cfg.nome
	if sistema:
		_nome.add_theme_font_override("font", Flash.fonte_sistema())
		_nome.add_theme_font_size_override("font_size", 18)
		_nome.add_theme_constant_override("outline_size", 0)
	else:
		_nome.add_theme_font_override("font", Flash.fonte_titulo())
		_nome.add_theme_font_size_override("font_size", 24)
		_nome.add_theme_constant_override("outline_size", 5)
	_tag.size = Vector2.ZERO   # encolhe até o tamanho mínimo (o nome anterior pode ter sido maior)
	(_seta as Seta).cor = Flash.dessaturar(Flash.VERMELHO if misterio else Flash.AZUL, t)
	_seta.queue_redraw()

	_retrato_corrompido = tem_retrato and corr >= 0.8
	_t_glitch = 0.0
	_prox_glitch = randf_range(0.8, 2.0)
	_atualizar_retrato()


func _atualizar_retrato() -> void:
	var cfg := _config(_personagem)
	if cfg.retrato == "":
		return
	_retrato.texture = Flash.mascote(cfg.retrato, _retrato_corrompido)


func _mostrar() -> void:
	if _tween_caixa:
		_tween_caixa.kill()
	# Se uma fala acabou de terminar, a caixa pode estar no meio do fade-out: traz de volta.
	var ja_visivel := _raiz.visible and _caixa.modulate.a > 0.5
	_raiz.visible = true
	_caixa.pivot_offset = Vector2(_largura / 2.0, ALTURA)
	if ja_visivel:
		_caixa.modulate.a = 1.0
		_caixa.scale = Vector2.ONE
		return
	_caixa.modulate.a = 0.0
	_caixa.scale = Vector2(0.94, 0.94)
	_tween_caixa = create_tween().set_parallel()
	_tween_caixa.tween_property(_caixa, "modulate:a", 1.0, 0.12)
	_tween_caixa.tween_property(_caixa, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ocultar() -> void:
	_ativo = false
	_digitando = false
	_esperando = false
	if not _raiz.visible:
		return
	if _tween_caixa:
		_tween_caixa.kill()
	_tween_caixa = create_tween()
	_tween_caixa.tween_property(_caixa, "modulate:a", 0.0, 0.12)
	_tween_caixa.tween_callback(func():
		if not _ativo:
			_raiz.visible = false)


# ================================================================ por quadro
var _acum_bob := 0.0


func _process(dt: float) -> void:
	if not _ativo:
		return
	_t_linha += dt
	_seta.visible = _esperando
	if _esperando:
		_seta.position.y = ALTURA - 40.0 + sin(Time.get_ticks_msec() / 160.0) * 4.0

	# "boca" do mascote: balança em passos de 12 fps enquanto fala (só um truque de squash and stretch)
	_acum_bob += dt
	if _acum_bob >= 1.0 / 12.0:
		_acum_bob = 0.0
		if _digitando and _marco.visible:
			var k := int(Time.get_ticks_msec() / 83) % 2
			_marco.scale = Vector2(1.0, 1.0 + 0.045 * k)
		else:
			_marco.scale = Vector2.ONE

	# retrato corrompido ocasional
	var corr := GameState.corruption
	if corr > Flash.LIMIAR_CORRUPCAO and _marco.visible and corr < 0.8:
		if _t_glitch > 0.0:
			_t_glitch -= dt
			if _t_glitch <= 0.0:
				_retrato_corrompido = false
				_atualizar_retrato()
		else:
			_prox_glitch -= dt
			if _prox_glitch <= 0.0:
				_prox_glitch = randf_range(1.2, 3.0) / (0.5 + corr)
				if randf() < remap(corr, Flash.LIMIAR_CORRUPCAO, 0.8, 0.25, 0.9):
					_t_glitch = randf_range(0.15, 0.5)
					_retrato_corrompido = true
					_atualizar_retrato()
	# tremida do texto quando está bem corrompido
	if corr > 0.55 and randf() < 0.06:
		_texto.position.x += randf_range(-2.5, 2.5)
		_texto.position.y += randf_range(-1.5, 1.5)
	elif corr > 0.55:
		_texto.position = _texto.position.lerp(Vector2(_balao.position.x + 28.0, 12), 0.5)


func _input(e: InputEvent) -> void:
	if not _ativo or GameState.flag("ui_aberta"):
		return
	var pedido := false
	if e is InputEventKey and e.pressed and not e.echo:
		pedido = e.is_action_pressed("avancar_dialogo")
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		# celular: o toque vira clique emulado em qualquer lugar (até no analógico); quem avança é o ControlesToque
		pedido = not (Celular.ativo and e.device == InputEvent.DEVICE_ID_EMULATION)
	if pedido:
		avancar()
		# Num balão que não trava o jogador, o clique também segue para o jogo (ex.: interagir com um painel).
		if _bloqueante or e is InputEventKey:
			get_viewport().set_input_as_handled()
