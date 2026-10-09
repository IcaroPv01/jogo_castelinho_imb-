extends SceneTree
## Teste automático (headless) do modo celular (módulo 8): controles de toque, pausa por botão (sem depender do
## ponteiro), aviso de retrato, opção "Controles de toque" e desktop sem nenhum controle.
## Uso: godot --headless -s res://tests/celular_test.gd
##
## Os toques são injetados nos métodos públicos (processar_toque / processar_arraste), os mesmos que o _input chama.
## O headless não tem janela de verdade: por isso o main.deve_pausar()/_atualizar_pausa() são chamados à mão.

var falhas := 0
var GS
var main
var hud
var Cel


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Cel = load("res://ui/celular.gd")
	_gravar_modo_auto()   # um teste/jogo anterior pode ter deixado "sempre" em user://opcoes.cfg
	Cel.modo = "auto"
	Cel.ativo = false
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	hud = main.hud
	await main.carregar_mundo("res://world/niveis/teste.tscn", "Spawn")
	for i in 10:
		await physics_frame

	await _teste_desktop()
	await _teste_pausa_sem_ponteiro()
	await _teste_analogico()
	await _teste_olhar()
	await _teste_botoes()
	await _teste_visor_e_faixa()
	await _teste_toque_avanca_fala()
	await _teste_pausa_e_continuar()
	await _teste_retrato()
	await _teste_opcao()
	await _teste_textos()

	Cel.modo = "auto"
	Cel.ativo = false
	Cel.aplicar_ambiente()
	Cel.pausa_toque = false
	Cel.retrato = false
	_gravar_modo_auto()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


## Garante "controles_toque = auto" no arquivo de opções (o teste mexe no modo e não pode contaminar os outros).
func _gravar_modo_auto() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://opcoes.cfg")
	cfg.set_value("opcoes", "controles_toque", "auto")
	cfg.save("user://opcoes.cfg")


func _ligar_celular() -> void:
	Cel.ativo = true
	Cel.pausa_toque = false
	await process_frame
	await process_frame
	await process_frame


# ---------------------------------------------------------------- desktop
func _teste_desktop() -> void:
	print("-- desktop: nenhum controle, regras de sempre")
	await process_frame
	await process_frame
	_checar(not Cel.ativo, "headless/desktop: Celular.ativo falso")
	_checar(hud.controles == null and hud.aviso_retrato == null, "desktop não cria controles de toque nem aviso de retrato")
	_checar(not Cel.olhar_liberado() or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "olhar_liberado segue o mouse capturado")
	# (o headless não guarda o modo CAPTURED do mouse: o caminho com a janela real é o tests/janela_jogador.gd)
	Cel.soltar_mouse()
	_checar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and main.deve_pausar(), "desktop: mouse solto pausa (como antes)")
	_checar(Cel.dica("teclado", "toque") == "teclado" and Cel.adaptar("segure Q") == "segure Q", "textos de teclado no desktop")
	var tem_clique := false
	for ev in InputMap.action_get_events("interagir"):
		if ev is InputEventMouseButton:
			tem_clique = true
	_checar(tem_clique, "desktop: o clique do mouse ainda interage")


# ---------------------------------------------------------------- celular: sem pausa pelo ponteiro
func _teste_pausa_sem_ponteiro() -> void:
	print("-- celular: criar controles e não pausar pelo mouse")
	await _ligar_celular()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_checar(hud.controles != null and hud.controles.is_inside_tree(), "controles de toque criados")
	_checar(hud.aviso_retrato != null, "aviso de retrato criado")
	_checar(hud.controles.layer > hud.layer and hud.controles.layer < 20, "camada acima do HUD e abaixo do balão da Guia")
	_checar(hud.controles.ligado, "controles ligados com o jogo rodando")
	_checar(Cel.olhar_liberado(), "olhar liberado sem mouse capturado")
	_checar(not main.deve_pausar(), "mouse solto NÃO pausa no celular")
	main._atualizar_pausa()
	_checar(not paused, "árvore não pausada")
	Cel.capturar_mouse()
	_checar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "capturar_mouse não faz nada no celular")
	var tem_clique := false
	for ev in InputMap.action_get_events("interagir"):
		if ev is InputEventMouseButton:
			tem_clique = true
	_checar(not tem_clique, "celular: clique emulado não é mais 'interagir'")
	_checar(Cel.dica("teclado", "toque") == "toque", "dica de toque no celular")
	Cel.aplicar_ambiente()
	_checar(is_equal_approx(root.scaling_3d_scale, 0.7) and Engine.max_fps == 30, "perfil leve: 3D a 70% e 30 fps")
	_checar(Cel.limite_luzes(5) == 3 and Cel.limite_luzes(2) == 2, "no máximo 3 OmniLight no celular")
	var part := CPUParticles3D.new()
	part.amount = 100
	Cel.reduzir_particulas(part)
	_checar(part.amount == 50, "partículas pela metade")
	part.free()
	var m: Vector4 = Cel.margens()
	_checar(m.x >= Cel.MARGEM_MIN and m.w >= Cel.MARGEM_MIN, "margens com mínimo")


# ---------------------------------------------------------------- analógico
func _teste_analogico() -> void:
	print("-- analógico anda")
	var c = hud.controles
	var p = main.player
	var antes: Vector3 = p.global_position
	_checar(c.processar_toque(0, Vector2(160, 380), true), "toque na esquerda é do analógico")
	c.processar_arraste(0, Vector2(160, 305), Vector2(0, -75))
	_checar(Input.get_action_strength("frente") > 0.8, "arrastar para cima aperta 'frente' (%.2f)" % Input.get_action_strength("frente"))
	_checar(Input.get_action_strength("tras") == 0.0, "'tras' solta")
	for i in 40:
		await physics_frame
	var andou: float = p.global_position.distance_to(antes)
	_checar(andou > 0.8, "jogador andou %.2f m" % andou)
	c.processar_arraste(0, Vector2(240, 380), Vector2(80, 75))
	_checar(Input.get_action_strength("direita") > 0.5 and Input.get_action_strength("frente") == 0.0, "analógico para a direita")
	c.processar_toque(0, Vector2(240, 380), false)
	_checar(Input.get_action_strength("frente") == 0.0 and Input.get_action_strength("direita") == 0.0, "soltar o dedo solta as ações")


# ---------------------------------------------------------------- olhar
func _teste_olhar() -> void:
	print("-- arrastar olha")
	var c = hud.controles
	var p = main.player
	var yaw0: float = p.rotation.y
	var pitch0: float = p.cabeca.rotation.x
	c.processar_toque(1, Vector2(900, 250), true)
	c.processar_arraste(1, Vector2(1000, 280), Vector2(100, 30))
	c.processar_toque(1, Vector2(1000, 280), false)
	_checar(absf(p.rotation.y - yaw0) > 0.3, "arrasto horizontal girou (%.2f rad)" % (p.rotation.y - yaw0))
	_checar(absf(p.cabeca.rotation.x - pitch0) > 0.05, "arrasto vertical inclinou a cabeça")
	var yaw1: float = p.rotation.y
	p.pode_mover = false
	c.processar_toque(1, Vector2(900, 250), true)
	c.processar_arraste(1, Vector2(1000, 250), Vector2(100, 0))
	c.processar_toque(1, Vector2(1000, 250), false)
	p.pode_mover = true
	_checar(is_equal_approx(p.rotation.y, yaw1), "jogador travado não gira")
	# mouse emulado do toque não gira nem interage
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(200, 0)
	ev.device = InputEvent.DEVICE_ID_EMULATION
	p._unhandled_input(ev)
	_checar(is_equal_approx(p.rotation.y, yaw1), "mouse emulado não gira no celular")


# ---------------------------------------------------------------- botões
func _teste_botoes() -> void:
	print("-- botões")
	var c = hud.controles
	var lay: Dictionary = c.layout()
	_checar(lay.has("interagir") and lay.has("correr") and lay.has("pausa") and lay.has("tela"), "botões básicos existem")
	_checar(not lay.has("lanterna") and not lay.has("visor"), "lanterna e visor escondidos sem o item")
	_checar(float(lay.interagir.r) * 2.0 >= 90.0 and float(lay.correr.r) * 2.0 >= 90.0, "botões grandes (>= 90 px)")
	var vp: Vector2 = c.tamanho()
	_checar(Vector2(lay.interagir.c).x + float(lay.interagir.r) <= vp.x and Vector2(lay.interagir.c).y + float(lay.interagir.r) <= vp.y, "interagir cabe na tela")
	# Correr: liga/desliga; soltar o analógico desliga
	c.processar_toque(2, lay.correr.c, true)
	c.processar_toque(2, lay.correr.c, false)
	_checar(Input.is_action_pressed("correr"), "Correr liga")
	c.processar_toque(0, Vector2(160, 380), true)
	c.processar_toque(0, Vector2(160, 380), false)
	_checar(not Input.is_action_pressed("correr"), "soltar o analógico desliga o Correr")
	# Interagir dispara a ação (e solta logo depois)
	c.processar_toque(3, lay.interagir.c, true)
	await process_frame   # o Input junta os eventos e solta no começo do quadro
	_checar(Input.is_action_pressed("interagir"), "Interagir aperta a ação")
	c.processar_toque(3, lay.interagir.c, false)
	for i in 8:
		await process_frame
	await create_timer(0.15).timeout
	_checar(not Input.is_action_pressed("interagir"), "Interagir solta a ação")
	# Lanterna só com o item
	GS.set_flag("tem_lanterna", true)
	await process_frame
	lay = c.layout()
	_checar(lay.has("lanterna"), "lanterna aparece com o item")
	var luz_antes: bool = main.player.lanterna.visible
	c.processar_toque(4, lay.lanterna.c, true)
	c.processar_toque(4, lay.lanterna.c, false)
	await process_frame
	_checar(main.player.lanterna.visible != luz_antes, "botão Lanterna liga/desliga a lanterna")
	main.player.lanterna.visible = luz_antes
	GS.set_flag("lanterna_desligada", not luz_antes)
	await create_timer(0.15).timeout


# ---------------------------------------------------------------- visor e faixa de discos
func _teste_visor_e_faixa() -> void:
	print("-- visor (segurar) e faixa de discos")
	var c = hud.controles
	var visor = load("res://world/visor.gd").instalar(main.mundo)
	GS.ganhar_disco(0)
	GS.ganhar_disco(2)
	await process_frame
	await process_frame
	var lay: Dictionary = c.layout()
	_checar(lay.has("visor"), "botão Visor aparece com discos")
	c.processar_toque(5, lay.visor.c, true)
	_checar(Input.is_action_pressed("visor"), "Visor: segurar aperta")
	c.processar_toque(5, lay.visor.c, false)
	_checar(not Input.is_action_pressed("visor"), "Visor: soltar solta")
	var f = hud.faixa_discos
	_checar(f.visible and f.discos_mostrados().size() == 2, "faixa mostra os 2 discos")
	var alvo: Vector2 = f.global_position + Vector2(10.0 + f.LARG_SLOT * 0.5, 40.0)
	var slot: int = f.slot_em(alvo)
	_checar(slot == 0, "slot_em acerta o 1o disco (slot %d)" % slot)
	var alvo2: Vector2 = f.global_position + Vector2(10.0 + f.LARG_SLOT * 1.5, 40.0)
	_checar(f.slot_em(alvo2) == 3, "slot_em acerta o 2o disco (2019 = slot 3, deu %d)" % f.slot_em(alvo2))
	_checar(f.slot_em(Vector2(-500, -500)) == -1, "fora da faixa = -1")
	_checar(GS.disco_atual == 2, "disco atual é o último ganho (2019)")
	c.processar_toque(6, alvo, true)
	c.processar_toque(6, alvo, false)
	_checar(GS.disco_atual == 0, "tocar no disco 1950 seleciona")
	_checar(visor != null, "visor existe")


# ---------------------------------------------------------------- toque rápido avança a fala
func _teste_toque_avanca_fala() -> void:
	print("-- toque avança a fala da Guia")
	var c = hud.controles
	var guia = root.get_node("/root/Guia")
	guia.falar("bentinho", ["Oi!"], true)
	for i in 120:
		await process_frame
		if guia.bloqueando():
			break
	_checar(guia.bloqueando(), "fala bloqueante na tela")
	var borda: float = Cel.borda_botoes(c.tamanho().x)
	_checar(guia._caixa.offset_right < borda and guia._caixa.offset_left >= 0.0, "balão termina antes dos botões (%.0f < %.0f)" % [guia._caixa.offset_right, borda])
	await create_timer(0.6).timeout
	var tempo := 0
	c.processar_toque(7, Vector2(700, 300), true)   # com balão bloqueante, qualquer toque avança
	c.processar_toque(7, Vector2(700, 300), false)
	for i in 60:
		await process_frame
		if not guia.ocupado():
			break
		tempo += 1
	_checar(not guia.ocupado(), "toque avançou/fechou a fala (%d quadros)" % tempo)
	# clique emulado não avança sozinho no celular
	guia.falar("bentinho", ["Segunda fala"], false)
	for i in 60:
		await process_frame
		if guia.visivel():
			break
	await create_timer(0.5).timeout
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.device = InputEvent.DEVICE_ID_EMULATION
	guia._input(ev)
	_checar(not guia._pedido_avanco and not guia._pular, "clique emulado ignorado pela Guia no celular")
	# toque rápido na área de olhar avança
	c.processar_toque(8, Vector2(1000, 300), true)
	c.processar_toque(8, Vector2(1002, 301), false)
	for i in 40:
		await process_frame
		if not guia.ocupado():
			break
	_checar(not guia.ocupado(), "toque rápido na área de olhar avança a fala")
	guia.cancelar()
	await process_frame


# ---------------------------------------------------------------- pausa e continuar
func _teste_pausa_e_continuar() -> void:
	print("-- botão de pausa e Continuar")
	var c = hud.controles
	var lay: Dictionary = c.layout()
	c.processar_toque(9, lay.pausa.c, true)
	c.processar_toque(9, lay.pausa.c, false)
	_checar(Cel.pausa_toque, "botão de pausa liga pausa_toque")
	main._atualizar_pausa()
	_checar(paused and hud.menu_pausa.visible, "jogo pausado e menu visível")
	await process_frame
	await process_frame
	_checar(not c.ligado, "controles somem durante a pausa")
	_checar(Input.get_action_strength("frente") == 0.0, "nenhuma ação presa")
	hud.menu_pausa._continuar()
	_checar(not Cel.pausa_toque, "Continuar limpa pausa_toque")
	main._atualizar_pausa()
	_checar(not paused and not hud.menu_pausa.visible, "jogo volta")
	await process_frame
	await process_frame
	_checar(c.ligado, "controles voltam")
	# perder o foco da aba pausa
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_checar(Cel.pausa_toque, "perder o foco liga a pausa no celular")
	Cel.pausa_toque = false
	main._atualizar_pausa()
	await process_frame
	# tela cheia aberta (painel): não pausa
	GS.set_flag("ui_aberta", true)
	Cel.pausa_toque = true
	_checar(not main.deve_pausar(), "painel aberto não pausa")
	await process_frame
	_checar(not c.ligado, "controles somem com painel aberto")
	GS.flags.erase("ui_aberta")
	Cel.pausa_toque = false
	await process_frame
	await process_frame


# ---------------------------------------------------------------- retrato
func _teste_retrato() -> void:
	print("-- aviso de retrato (390x844)")
	var av = hud.aviso_retrato
	av.tam_forcado = Vector2(390, 844)
	hud.controles.tam_forcado = Vector2(390, 844)
	await process_frame
	await process_frame
	_checar(Cel.retrato, "Celular.retrato verdadeiro em pé")
	_checar(av.get_child(0).visible, "aviso visível")
	var achou := false
	for n in av.find_children("*", "Label", true, false):
		if (n as Label).text.contains("Vire o celular"):
			achou = true
	_checar(achou, "texto 'Vire o celular'")
	_checar(av.layer == 128, "aviso na camada 128")
	_checar(main.deve_pausar(), "retrato pausa o jogo")
	_checar(not hud.controles.ligado, "controles escondidos em pé")
	av.tam_forcado = Vector2(844, 390)
	hud.controles.tam_forcado = Vector2.ZERO
	await process_frame
	await process_frame
	_checar(not Cel.retrato and not main.deve_pausar(), "deitado: volta ao normal")
	av.tam_forcado = Vector2.ZERO
	var lay: Dictionary = hud.controles.layout()
	hud.controles.tam_forcado = Vector2(844, 390)
	lay = hud.controles.layout()
	var cabe := true
	for id: String in lay:
		var b: Dictionary = lay[id]
		var cc: Vector2 = b.c
		if cc.x - float(b.r) < 0.0 or cc.y - float(b.r) < 0.0 or cc.x + float(b.r) > 844.0 or cc.y + float(b.r) > 390.0:
			cabe = false
	_checar(cabe, "botões cabem em 844x390")
	hud.controles.tam_forcado = Vector2.ZERO


# ---------------------------------------------------------------- opção "Controles de toque"
func _teste_opcao() -> void:
	print("-- opção Controles de toque")
	var Op = load("res://ui/opcoes.gd")
	Op.definir_controles("nunca")
	await process_frame
	await process_frame
	_checar(not Cel.ativo and hud.controles == null and hud.aviso_retrato == null, "'Nunca' remove os controles na hora")
	_checar(is_equal_approx(root.scaling_3d_scale, 1.0) and Engine.max_fps == 0, "'Nunca' desfaz o perfil leve")
	Op.definir_controles("sempre")
	await process_frame
	await process_frame
	_checar(Cel.ativo and hud.controles != null, "'Sempre' cria os controles na hora")
	_checar(Cel.pausa_toque, "ligar o modo celular com o jogo rodando fica pausado até Continuar")
	Cel.pausa_toque = false   # (o _continuar() do menu salvaria o modo "sempre" no arquivo)
	Op.definir_controles("auto")
	await process_frame
	await process_frame
	_checar(not Cel.ativo and hud.controles == null, "'Automático' no desktop = sem controles")
	_checar(Cel.modo == "auto", "modo voltou a auto")
	# a página de opções tem os 3 botões
	var botoes: Dictionary = hud.menu_pausa._botoes_toque
	_checar(botoes.size() == 3 and botoes.has("auto") and botoes.has("sempre") and botoes.has("nunca"), "menu tem os 3 botões")
	(botoes["nunca"] as BaseButton).emit_signal("pressed")
	_checar(Cel.modo == "nunca", "botão 'Nunca' muda o modo")
	(botoes["auto"] as BaseButton).emit_signal("pressed")
	_checar(Cel.modo == "auto", "botão 'Automático' muda o modo")
	await process_frame
	_checar(not paused, "jogo não ficou pausado")


# ---------------------------------------------------------------- textos
func _teste_textos() -> void:
	print("-- textos de dica")
	Cel.ativo = true
	_checar(Cel.adaptar("Segure Q para ver").contains("Visor") and not Cel.adaptar("Segure Q para ver").contains(" Q "), "'Segure Q' vira botão Visor")
	_checar(not Cel.adaptar("Aperta F para ligar e desligar").contains(" F "), "dica da lanterna adaptada")
	_checar(Cel.adaptar("texto sem tecla") == "texto sem tecla", "texto neutro intacto")
	Cel.ativo = false
	await process_frame


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
