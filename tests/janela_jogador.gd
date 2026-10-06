extends SceneTree
## QA "jogador de verdade": precisa de uma janela (o headless não captura o mouse), por isso NÃO roda em tools/testar.sh.
## Clica no botão do título, anda com W/Shift, olha para os painéis, aperta E/Esc/Q de verdade (eventos de teclado e
## de mouse enviados por Input.parse_input_event) e confere a tela de carregamento, o mouse, a pausa, a morte e o save.
##
## Uso: bash tools/testar_janela.sh      (ou: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##                                          -s res://tests/janela_jogador.gd)
## Obs.: scripts `extends SceneTree` não podem citar as classes do jogo pelo nome (ver tests/ui_test.gd).

const CASTELINHO := "res://world/niveis/castelinho.tscn"

var falhas := 0
var GS
var main
var p
var nivel


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	if DisplayServer.get_name() == "headless":
		print("Este teste precisa de janela (xvfb-run). Pulando.")
		quit(0)
		return
	GS = root.get_node("/root/GameState")
	await _a_titulo_e_carregamento()
	await _b_paineis_e_esc()
	await _c_pausa()
	await _d_visor_em_paredes()
	await _e_correr_ate_cansar()
	await _f_morte_no_ato2()
	await _g_continuar_pelo_botao()
	await _h_mural_barra_e_volta()
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ---------------------------------------------------------------- utilitários
func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _segundos(s: float) -> void:
	await create_timer(s).timeout


func _tecla(k: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await process_frame


func _toque(k: int) -> void:
	await _tecla(k, true)
	await _tecla(k, false)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)
	await process_frame


func _clique(pos: Vector2) -> void:
	await _mouse(pos, true)
	await _mouse(pos, false)


func _olhar(alvo: Vector3) -> void:
	var d: Vector3 = alvo - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _ir(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _frames(6)


func _novo_main() -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)


func _esperar_jogo(max_s := 90.0) -> void:
	var t := 0.0
	while not GS.jogando and t < max_s:
		await process_frame
		t += 1.0 / maxf(Engine.get_frames_per_second(), 1.0)
	await _frames(10)
	p = main.player
	nivel = main.mundo.get_child(0) if main.mundo.get_child_count() > 0 else null


# ---------------------------------------------------------------- A: título -> carregando -> jogo
func _a_titulo_e_carregamento() -> void:
	print("-- A. clicar em 'Começar a visita' (985, 590)")
	GS.novo_jogo()
	await _novo_main()
	_checar(is_instance_valid(main.tela_titulo), "a tela de título está na tela")
	var TelaCarregando = load("res://ui/tela_carregando.gd")
	var t0 := Time.get_ticks_msec()
	await _clique(Vector2(985, 590))
	_checar(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "o clique capturou o mouse")
	await _frames(3)
	_checar(is_instance_valid(TelaCarregando.ultima), "a tela 'Carregando...' apareceu logo depois do clique (%d ms)" % (Time.get_ticks_msec() - t0))
	_checar(not GS.jogando, "ainda carregando: o jogo não começou")
	await _esperar_jogo()
	print("  (clique até o jogo: %d ms)" % (Time.get_ticks_msec() - t0))
	_checar(GS.jogando and p != null, "o jogo começou")
	_checar(not is_instance_valid(TelaCarregando.ultima), "a tela de carregamento sumiu")
	_checar(GS.sala_atual == 1 and main.hud.lbl_sala.text == "SALA 01", "HUD mostra SALA 01 ('%s')" % main.hud.lbl_sala.text)
	await _segundos(0.6)
	_checar(root.get_node("/root/Guia").ocupado(), "o Bentinho começou a falar")
	_checar(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused, "mouse capturado, jogo sem pausa")
	_checar(p.is_on_floor(), "jogador no chão")
	# andar para a frente com W de verdade
	var z0: float = p.global_position.z
	await _tecla(KEY_W, true)
	await _segundos(1.0)
	await _tecla(KEY_W, false)
	_checar(absf(p.global_position.z - z0) + absf(p.global_position.x + 23.0) > 1.0, "W faz o jogador andar (%s)" % str(p.global_position))
	root.get_node("/root/Guia").cancelar()


# ---------------------------------------------------------------- B: painéis, E, Esc
func _painel_aberto() -> Node:
	for n in root.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("painel_ui.gd"):
			return n
	return null


## Vai até o painel `id`, olha para ele e aperta E. Espera o texto terminar de "digitar".
func _abrir_painel(id: String) -> void:
	var pn: Node3D = nivel._paineis[id]
	await _ir(pn.global_position + pn.global_transform.basis.z * 1.6 + Vector3(0, -1.4, 0))
	_olhar(pn.global_position)
	await _frames(6)
	await _toque(KEY_E)
	await _frames(4)
	await _segundos(2.6)


func _livre() -> bool:
	return not GS.flag("ui_aberta") and p.pode_mover and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused


func _b_paineis_e_esc() -> void:
	print("-- B. ler painéis com E, Esc e abrir/fechar rápido")
	var pn: Node3D = nivel._paineis["p01"]
	await _ir(pn.global_position + Vector3(0, -1.4, 1.6))
	_olhar(pn.global_position)
	await _frames(6)
	_checar(main.hud.lbl_aviso.text.begins_with("[E]"), "aviso de interação: '%s'" % main.hud.lbl_aviso.text)
	await _toque(KEY_E)
	await _frames(4)
	_checar(GS.flag("ui_aberta") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not p.pode_mover, "E abre o painel (mouse livre, jogador travado)")
	var abertos := 0
	for n in root.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("painel_ui.gd"):
			abertos += 1
	_checar(abertos == 1, "só uma tela de leitura aberta (%d)" % abertos)
	await _segundos(2.6)
	await _toque(KEY_E)        # com o texto já digitado, E = "Entendi!": fecha (painel sem quiz)
	await _frames(4)
	_checar(_livre(), "E dentro do painel fecha; mouse volta capturado e o jogador anda")
	# abrir e fechar rápido com Esc, 12 vezes
	var ok := true
	for i in 12:
		await _toque(KEY_E)
		await _frames(3)
		await _toque(KEY_ESCAPE)
		await _frames(3)
		if not _livre():
			ok = false
			print("    falhou na repetição %d: ui_aberta=%s pode_mover=%s mouse=%d paused=%s" % [i, GS.flag("ui_aberta"), p.pode_mover, Input.mouse_mode, paused])
			break
	_checar(ok, "abrir (E) e fechar (Esc) 12 vezes seguidas não trava nada")
	# E, Esc e E no mesmo quadro
	Input.parse_input_event(_ev_tecla(KEY_E, true))
	Input.parse_input_event(_ev_tecla(KEY_E, false))
	Input.parse_input_event(_ev_tecla(KEY_E, true))
	Input.parse_input_event(_ev_tecla(KEY_E, false))
	await _frames(4)
	_checar(_painel_aberto() != null and GS.flag("ui_aberta"), "E duas vezes no mesmo quadro abre uma tela só")
	await _toque(KEY_ESCAPE)
	await _frames(4)
	_checar(_livre(), "...e o Esc libera tudo")
	# clique do mouse (ação 'interagir') abre o painel; Esc fecha
	await _clique(Vector2(640, 360))
	await _frames(4)
	_checar(GS.flag("ui_aberta"), "clicar também abre o painel")
	await _toque(KEY_ESCAPE)
	await _frames(4)
	_checar(_livre(), "Esc fecha o painel aberto pelo clique")
	# quiz do painel 02 por teclado: errar, acertar, terminar
	await _abrir_painel("p02")
	await _toque(KEY_SPACE)        # "Fazer o quiz!"
	await _frames(2)
	var pq: Dictionary = load("res://ui/painel_ui.gd").dados("p02")["quiz"]
	var correta := int(pq["correta"])
	var errada := (correta + 1) % 3
	await _toque([KEY_1, KEY_2, KEY_3][errada])
	_checar(not GS.selos.has(str(pq["selo"])), "resposta errada não dá selo")
	await _toque([KEY_1, KEY_2, KEY_3][correta])
	_checar(GS.selos.has(str(pq["selo"])), "resposta certa dá o selo '%s'" % str(pq["selo"]))
	await _toque(KEY_SPACE)        # "Terminar"
	await _frames(4)
	_checar(_livre(), "quiz terminado: tudo liberado")
	# o mesmo quiz, mas fechado com Esc no meio: nada fica preso
	await _abrir_painel("p05")
	await _toque(KEY_SPACE)
	await _frames(2)
	await _toque(KEY_ESCAPE)
	await _frames(4)
	_checar(_livre(), "Esc no meio de um quiz libera tudo")


func _ev_tecla(k: int, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = pressed
	return ev


# ---------------------------------------------------------------- C: pausa com Esc (desktop)
func _c_pausa() -> void:
	print("-- C. pausa com Esc e retomada com clique")
	await _ir(Vector3(-23.0, 0.1, 1.5))
	p.rotation.y = 0.0
	await _toque(KEY_ESCAPE)
	await _frames(4)
	_checar(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and paused and main.hud.lbl_pausa.visible, "Esc solta o mouse, pausa e mostra 'PAUSADO'")
	var z0: float = p.global_position.z
	await _tecla(KEY_W, true)
	await _segundos(0.6)
	_checar(absf(p.global_position.z - z0) < 0.05, "pausado: o jogador não anda com W")
	await _tecla(KEY_W, false)
	await _clique(Vector2(640, 360))
	await _frames(4)
	_checar(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused and not main.hud.lbl_pausa.visible, "clique retoma o jogo")
	await _tecla(KEY_W, true)
	await _segundos(0.6)
	await _tecla(KEY_W, false)
	_checar(absf(p.global_position.z - z0) > 0.5, "depois de retomar, W anda de novo")
	# Esc com um painel aberto fecha o painel e NÃO pausa
	var pn: Node3D = nivel._paineis["p01"]
	await _ir(pn.global_position + Vector3(0, -1.4, 1.6))
	_olhar(pn.global_position)
	await _frames(6)
	await _toque(KEY_E)
	await _frames(3)
	await _toque(KEY_ESCAPE)
	await _frames(4)
	_checar(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc com painel aberto fecha o painel, sem pausar")
	# perder o foco da janela (Alt-Tab no desktop) também pausa
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(4)
	_checar(paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "perder o foco da janela pausa o jogo")
	await _clique(Vector2(640, 360))
	await _frames(4)
	_checar(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "e o clique retoma")
	# Esc duas vezes seguidas (pausa, e de novo) não deve travar
	await _toque(KEY_ESCAPE)
	await _toque(KEY_ESCAPE)
	await _frames(3)
	await _clique(Vector2(640, 360))
	await _frames(3)
	_checar(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc, Esc e clique: volta ao jogo")


# ---------------------------------------------------------------- D: Visor dentro das paredes
func _d_visor_em_paredes() -> void:
	print("-- D. segurar Q, entrar nas paredes e soltar")
	GS.set_flag("tem_visor")
	GS.set_flag("epoca_visor", GS.Epoca.E1950)
	GS.set_flag("visor_travado", false)
	var presos := 0
	for pos in [Vector3(-27, 0.1, -12), Vector3(-24, 0.1, -14), Vector3(-20, 0.1, -20), Vector3(-14, 0.1, -26), Vector3(-6, 0.1, -20)]:
		await _tecla(KEY_Q, true)
		await _frames(8)
		_checar(GS.epoca == GS.Epoca.E1950, "Q apertado: 1950")
		await _ir(pos)
		await _tecla(KEY_Q, false)
		await _frames(10)
		_checar(GS.epoca == GS.Epoca.E2020, "Q solto: de volta a hoje")
		var p0: Vector3 = p.global_position
		var melhor := 0.0
		for ang in [0.0, 90.0, 180.0, 270.0]:
			p.global_position = p0
			p.rotation.y = deg_to_rad(ang)
			await _tecla(KEY_W, true)
			await _frames(18)
			await _tecla(KEY_W, false)
			melhor = maxf(melhor, p.global_position.distance_to(p0))
		if melhor < 0.5:
			presos += 1
	_checar(presos == 0, "soltar Q dentro de paredes nunca prende o jogador (presos: %d de 5)" % presos)
	# Q muito rápido (apertar e soltar várias vezes)
	for i in 6:
		await _tecla(KEY_Q, true)
		await _tecla(KEY_Q, false)
	await _frames(12)
	_checar(GS.epoca == GS.Epoca.E2020 and not nivel.get_node("Visor").ativo, "Q metralhado: termina em 2020 com o Visor desligado (época %d)" % GS.epoca)


# ---------------------------------------------------------------- E: correr até cansar
func _e_correr_ate_cansar() -> void:
	print("-- E. correr até cansar")
	await _ir(Vector3(-23.0, 0.1, 1.5))
	p.stamina = 1.0
	p.cansado = false
	p.rotation.y = deg_to_rad(-90)      # de frente para o leste: a calçada é livre por uns 25 m
	await _tecla(KEY_SHIFT, true)
	await _tecla(KEY_W, true)
	var t := 0.0
	while not p.cansado and t < 9.0:
		await process_frame
		t += 1.0 / maxf(Engine.get_frames_per_second(), 1.0)
	_checar(p.cansado, "o fôlego acaba correndo (%.1f s)" % t)
	_checar(main.hud.barra_stamina.visible, "a barra de fôlego aparece")
	await _segundos(0.3)
	_checar(p.velocity.length() <= 3.1, "cansado: só consegue andar (%.1f m/s)" % p.velocity.length())
	await _tecla(KEY_W, false)
	await _tecla(KEY_SHIFT, false)
	await _segundos(1.0)
	_checar(p.stamina > 0.0, "o fôlego recarrega")


# ---------------------------------------------------------------- F: morrer no Ato II e voltar
func _f_morte_no_ato2() -> void:
	print("-- F. morrer no Ato II (Figura Branca) e continuar")
	await main.carregar_mundo("res://world/niveis/ato2.tscn", "Spawn")
	await _frames(20)
	p = main.player
	nivel = main.mundo.get_child(0)
	root.get_node("/root/Guia").cancelar()
	await _ir(Vector3(0, 0.1, -40))
	var mortes0: int = GS.contadores["mortes"]
	GS.matar_jogador("figura_branca")
	await _segundos(1.2)
	_checar(GS.flag("ui_aberta") and not p.pode_mover, "a tela de morte abriu (jogador travado)")
	await _toque(KEY_ENTER)
	await _segundos(1.5)
	_checar(not GS.flag("ui_aberta") and p.pode_mover and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Enter volta ao jogo com mouse e movimento")
	_checar(p.global_position.distance_to(nivel.get_node("Checkpoint_26").global_position) < 0.8, "de volta ao Checkpoint_26")
	_checar(GS.contadores["mortes"] == mortes0 + 1 and GS.sala_atual == 26, "mortes +1 e sala 26 (sala %d)" % GS.sala_atual)
	_checar(not paused, "sem pausa depois de morrer")
	# morrer duas vezes seguidas
	GS.matar_jogador("figura_branca")
	await _segundos(1.2)
	await _toque(KEY_SPACE)
	await _segundos(1.5)
	_checar(not GS.flag("ui_aberta") and p.pode_mover, "segunda morte: também volta")


# ---------------------------------------------------------------- G: Continuar pelo botão
func _g_continuar_pelo_botao() -> void:
	print("-- G. 'Continuar' pelo botão do título, com save no checkpoint 16")
	for cp in [16, 25]:
		GS.novo_jogo()
		GS.checkpoint_sala = cp
		GS.set_flag("tem_visor")
		GS.salvar()
		root.get_node("/root/Guia").cancelar()
		await _novo_main()
		_checar(GS.tem_save() and main.tela_titulo._btn_continuar != null, "o botão 'Continuar' existe (checkpoint %d)" % cp)
		var b: Control = main.tela_titulo._btn_continuar
		var centro: Vector2 = b.get_global_rect().get_center()
		await _clique(centro)
		await _esperar_jogo()
		_checar(GS.jogando and main.nivel_atual == CASTELINHO, "checkpoint %d: entrou no Castelinho" % cp)
		var mk: Node3D = nivel.find_child("Checkpoint_%d" % cp, true, false)
		_checar(p.global_position.distance_to(mk.global_position) < 1.0 and p.is_on_floor(), "checkpoint %d: no marcador, em pé (%s)" % [cp, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1)))])
		await _segundos(0.5)
		_checar(GS.sala_atual == cp and main.hud.lbl_sala.text == "SALA %02d" % cp, "checkpoint %d: HUD '%s'" % [cp, main.hud.lbl_sala.text])
		await _tecla(KEY_W, true)
		await _segundos(0.8)
		await _tecla(KEY_W, false)
		_checar(p.is_on_floor() and p.global_position.y > -0.5, "checkpoint %d: anda sem cair (y=%.2f)" % [cp, p.global_position.y])
		root.get_node("/root/Guia").cancelar()


# ---------------------------------------------------------------- H: mural -> Barra (3 lances) -> volta
func _h_mural_barra_e_volta() -> void:
	print("-- H. mural da Sala do Pescador, flashback da Barra jogado com E e volta ao Castelinho")
	GS.novo_jogo()
	GS.checkpoint_sala = 11
	GS.set_flag("tem_visor")
	root.get_node("/root/Guia").cancelar()
	await _novo_main()
	await _clique(main.tela_titulo._btn_continuar.get_global_rect().get_center())
	await _esperar_jogo()
	root.get_node("/root/Guia").cancelar()
	var mural: Node3D = nivel._mural
	await _ir(Vector3(-8.7, 0.1, -15.6))
	_olhar(mural.global_position)
	await _frames(6)
	_checar(main.hud.lbl_aviso.text == "[E] Olhar o mural", "aviso do mural: '%s'" % main.hud.lbl_aviso.text)
	await _toque(KEY_E)
	await _frames(4)
	_checar(not p.pode_mover and root.get_node("/root/Guia").ocupado(), "a Tainá fala e o jogador fica parado")
	# dispensa a fala (bloqueante): o 1º Espaço completa o texto que está sendo "digitado", o 2º fecha
	var t := 0.0
	while not main.nivel_atual.ends_with("barra.tscn") and t < 20.0:
		if root.get_node("/root/Guia").ocupado():
			await _toque(KEY_SPACE)
		await _segundos(0.5)
		t += 0.5
	_checar(main.nivel_atual.ends_with("barra.tscn"), "foi para a Barra (%.1f s)" % t)
	await _segundos(1.0)
	_checar(main.hud.lbl_aviso.text == "", "na Barra o aviso do mural não ficou na tela ('%s')" % main.hud.lbl_aviso.text)
	var barra = main.mundo.get_child(0)
	p = main.player
	# a Tainá explica (fala bloqueante): Espaço até liberar
	var guia = root.get_node("/root/Guia")
	t = 0.0
	while guia.ocupado() and t < 40.0:
		await _toque(KEY_SPACE)
		await _segundos(0.5)
		t += 0.6
	_checar(p.pode_mover, "a introdução acabou e o jogador está livre (%.0f s)" % t)
	# joga os lances: espera a janela do boto e aperta E
	var lances := 0
	t = 0.0
	while barra.fase != barra.Fase.PUXADO and barra.fase != barra.Fase.FIM and t < 90.0:
		if barra.janela_aberta:
			await _toque(KEY_E)
			await _segundos(1.5)
			t += 1.5
		else:
			await _frames(3)
			t += 0.05
	_checar(barra.fase == barra.Fase.PUXADO or barra.fase == barra.Fase.FIM or main.nivel_atual.ends_with("castelinho.tscn"),
		"os três lances foram jogados e o rio puxou (fase %d, %.0f s)" % [barra.fase if is_instance_valid(barra) else -1, t])
	t = 0.0
	while not main.nivel_atual.ends_with("castelinho.tscn") and t < 40.0:
		await _toque(KEY_SPACE)        # a Tainá: "...era eu na rede?" (bloqueante)
		await _segundos(0.5)
		t += 0.6
	_checar(main.nivel_atual.ends_with("castelinho.tscn"), "de volta ao Castelinho (%.0f s)" % t)
	await _segundos(4.0)
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(GS.flag("viu_flashback_barra") and GS.sala_atual >= 15, "flag da Barra ligada e sala %d" % GS.sala_atual)
	var q := 0.0
	while guia.ocupado() and q < 20.0:
		await _toque(KEY_SPACE)
		await _segundos(0.4)
		q += 0.5
	_checar(p.pode_mover and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused, "jogador livre e com o mouse capturado")
	_checar(p.global_position.distance_to(Vector3(-8.6, 0.0, -15.6)) < 2.0, "voltou à Sala do Pescador (%s)" % str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))))
	_checar(GS.epoca == GS.Epoca.E2020 and GS.corruption < 0.1, "época de hoje e corrupção da curva (%.2f)" % GS.corruption)
	# mural de novo: "Já vimos esse mural"
	_olhar(nivel._mural.global_position)
	await _frames(6)
	await _toque(KEY_E)
	await _frames(4)
	_checar(main.nivel_atual.ends_with("castelinho.tscn") and guia.ocupado() and p.pode_mover, "segunda vez no mural: só uma fala, sem ir à Barra")
