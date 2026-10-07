extends SceneTree
## QA (headless): um bloco por bug corrigido na rodada de testes (ver docs/BUGS.md; o id do bug vem no título).
##  B01 "Continuar" ignorava o checkpoint (sempre nascia no Spawn do Castelinho, nunca no Ato II, e herdava a
##      época e a sala da partida anterior; no checkpoint 25 o jogador nascia no vazio)
##  B02 nova partida / voltar ao título herdava a corrupção do fim da anterior (sem sinal para Efeitos e Audio)
##  B03 soltar o Visor (Q) com o jogador dentro de uma parede que reaparece o prendia para sempre
##  B04 flag "saindo_para_barra" salva e nunca limpa (mural "ocupado" para sempre depois de um save no meio)
##  B05 Esc/X no meio do quiz final contava como "lido" e dava o diploma sem terminar o quiz
##  B06 trocar de nível com Q apertado deixava a época em 1950 no nível seguinte
##  B07 Enter na tela de título com jogo salvo recomeçava e apagava o save
##  B13 os portões do oeste da Sala Medieval e a porta leste do Salão de Arte eram só pintura (sem colisão): dava para
##      entrar no prédio pelos fundos do lote e pular as salas 7 a 20 (inclusive o Visor)
##  B12 o aviso "[E] ..." e a barra de fôlego do jogador anterior ficavam na tela depois da troca de nível
##  B08 tela "Carregando..." + aquecimento: fluxo, restauração do estado e eventos só depois que ela some
## Uso: godot --headless -s res://tests/qa_logica_test.gd
## Obs.: classes e autoloads são acessados por load()/get_node em runtime (ver tests/ui_test.gd).

const CASTELINHO := "res://world/niveis/castelinho.tscn"
const ATO2 := "res://world/niveis/ato2.tscn"
const BARRA := "res://world/niveis/barra.tscn"

var falhas := 0
var GS
var main
var p


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await _b01_continuar()
	await _b02_corrupcao_nova_partida()
	await _b03_preso_ao_soltar_visor()
	await _b05_quiz_final_esc()
	await _b06_visor_troca_de_nivel()
	await _b07_enter_com_save()
	await _b12_hud_ao_trocar_de_nivel()
	await _b13_entradas_fechadas()
	await _b08_carregamento()
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
		await physics_frame


func _tecla(k: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame


func _novo_castelinho() -> void:
	GS.novo_jogo()
	GS.jogando = true
	await main.carregar_mundo(CASTELINHO, "Spawn")
	await _frames(20)
	p = main.player


# ---------------------------------------------------------------- B01
func _b01_continuar() -> void:
	print("-- B01 Continuar a partir de cada checkpoint (4 visitas, Ato II, porão, Braço Morto)")
	const PORAO := "res://world/niveis/porao.tscn"
	const BRACO := "res://world/niveis/braco_morto.tscn"
	# [checkpoint, cena, marcador, visita esperada]
	var casos := [[1, CASTELINHO, "Checkpoint_1", 1], [10, CASTELINHO, "Checkpoint_10", 1], [16, CASTELINHO, "Checkpoint_16", 1],
		[23, CASTELINHO, "Checkpoint_23", 2], [32, CASTELINHO, "Checkpoint_32", 2], [38, CASTELINHO, "Checkpoint_38", 2],
		[45, CASTELINHO, "Checkpoint_45", 3], [54, CASTELINHO, "Checkpoint_54", 3], [55, ATO2, "Checkpoint_55", 3],
		[61, CASTELINHO, "Checkpoint_61", 3], [67, CASTELINHO, "Checkpoint_67", 4], [72, CASTELINHO, "Checkpoint_72", 4],
		[77, CASTELINHO, "Checkpoint_77", 4], [81, PORAO, "Checkpoint_81", 5], [95, PORAO, "Checkpoint_95", 5], [100, BRACO, "Spawn", 5]]
	for c in casos:
		GS.novo_jogo()
		GS.checkpoint_sala = c[0]
		GS.set_flag("tem_visor")
		GS.set_flag("tem_lanterna")
		GS.set_flag("saindo_para_barra", true)          # save antigo com a flag presa (B04)
		# estado "sujo" da partida anterior: não pode vazar para a que continua
		GS.sala_atual = 30
		GS.visita = 1 if c[3] != 1 else 4
		GS.epoca = GS.Epoca.E1950
		GS.corruption = 0.6
		# a cena de destino pode não existir ainda (porão/Braço Morto são de outro agente): só confere o contrato
		var destino: Array = GS.preparar_continuar()
		_checar(destino[0] == c[1] and destino[1] == c[2], "checkpoint %d: preparar_continuar -> %s %s" % [c[0], str(destino[0]).get_file(), destino[1]])
		_checar(GS.visita == c[3] and GS.epoca == GS.Epoca.E2020 and GS.sala_atual == 0, "checkpoint %d: visita %d e época de hoje restauradas (visita %d)" % [c[0], c[3], GS.visita])
		if c[1] != CASTELINHO and (not ResourceLoader.exists(c[1])):
			continue
		if c[1] != CASTELINHO:
			continue          # Ato II / porão / Braço Morto: os níveis têm os próprios testes
		GS.sala_atual = 30
		GS.epoca = GS.Epoca.E1950
		GS.corruption = 0.6
		GS.flags["tem_visor"] = true
		GS.flags["tem_lanterna"] = true
		GS.flags["saindo_para_barra"] = true
		await main._comecar(true)
		await _frames(40)
		p = main.player
		var nivel: Node3D = main.mundo.get_child(0)
		var marcador := nivel.find_child(c[2], true, false) as Node3D
		_checar(main.nivel_atual == c[1], "checkpoint %d: nível %s" % [c[0], c[1].get_file()])
		_checar(marcador != null and Vector2(p.global_position.x - marcador.global_position.x, p.global_position.z - marcador.global_position.z).length() < 1.6,
			"checkpoint %d: jogador no marcador %s (%s)" % [c[0], c[2], str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1)))])
		_checar(p.is_on_floor() and p.global_position.y > -0.5, "checkpoint %d: no chão (y=%.2f)" % [c[0], p.global_position.y])
		_checar(GS.sala_atual == c[0], "checkpoint %d: contador na sala %d (sala %d)" % [c[0], c[0], GS.sala_atual])
		_checar(GS.visita == c[3] and nivel.visita == c[3], "checkpoint %d: visita %d no nível" % [c[0], c[3]])
		_checar(GS.jogando, "checkpoint %d: jogando" % c[0])
		_checar(not GS.flags.has("saindo_para_barra"), "checkpoint %d: flag saindo_para_barra limpa (B04)" % c[0])
		_checar(GS.epoca == GS.Epoca.E2020, "checkpoint %d: época de hoje (época %d)" % [c[0], GS.epoca])
		_checar(GS.corruption <= GS.corruption_por_sala(c[0]) + 0.001, "checkpoint %d: corrupção da sala, não a da partida anterior (%.2f)" % [c[0], GS.corruption])
		# a morte no Castelinho volta ao mesmo lugar: o main usa "Checkpoint_%d" % checkpoint_sala (nome global)
		_checar(nivel.find_child("Checkpoint_%d" % GS.checkpoint_sala, true, false) != null, "checkpoint %d: marcador pelo número global existe" % c[0])
	GS.set_flag("visor_travado", false)


# ---------------------------------------------------------------- B02
func _b02_corrupcao_nova_partida() -> void:
	print("-- B02 nova partida zera a corrupção COM sinal")
	GS.sala_atual = 70
	GS._atualizar_corruption()
	_checar(GS.corruption > 0.4, "corrupção alta no fim da demo (%.2f)" % GS.corruption)
	var efeitos = root.get_node("/root/Efeitos")
	await process_frame
	_checar(efeitos._alvo_c > 0.4, "Efeitos acompanhou (%.2f)" % efeitos._alvo_c)
	var vistos := []
	var f := func(v: float) -> void: vistos.append(v)
	GS.corruption_mudou.connect(f)
	GS.novo_jogo()
	GS.corruption_mudou.disconnect(f)
	_checar(vistos == [0.0], "novo_jogo avisou a corrupção 0 (%s)" % str(vistos))
	_checar(is_equal_approx(efeitos._alvo_c, 0.0), "Efeitos voltou a 0 (%.2f)" % efeitos._alvo_c)
	# voltar ao título depois do "Fim da demonstração" recarrega a cena principal
	GS.sala_atual = 70
	GS._atualizar_corruption()
	GS.epoca = GS.Epoca.E1950
	var outro = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(outro)
	await process_frame
	_checar(is_equal_approx(GS.corruption, 0.0) and GS.sala_atual == 0 and GS.epoca == GS.Epoca.E2020 and not GS.jogando,
		"cena principal nova começa limpa (corrupção %.2f, sala %d, época %d)" % [GS.corruption, GS.sala_atual, GS.epoca])
	outro.queue_free()
	await process_frame


# ---------------------------------------------------------------- B03
func _preso(pos: Vector3) -> bool:
	## true se, depois de soltar o Visor com o jogador em `pos`, ele não consegue mais sair do lugar.
	GS.trocar_epoca(GS.Epoca.E1950)
	await physics_frame
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _frames(3)
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(10)
	var p0: Vector3 = p.global_position
	var melhor := 0.0
	for dir in [0.0, 90.0, 180.0, 270.0]:
		p.global_position = p0
		p.rotation.y = deg_to_rad(dir)
		Input.action_press("frente")
		await _frames(25)
		Input.action_release("frente")
		melhor = maxf(melhor, p.global_position.distance_to(p0))
		await physics_frame
	return melhor < 0.5 or p._sobrepoe_mundo(p0)


func _b03_preso_ao_soltar_visor() -> void:
	print("-- B03 soltar o Visor dentro de uma parede")
	await _novo_castelinho()
	var presos := []
	# pontos dentro de paredes do térreo (aparecem quando a casa volta em 2020)
	for pos in [Vector3(-27, 0.1, -12), Vector3(-24, 0.1, -14), Vector3(-20, 0.1, -20), Vector3(-14, 0.1, -26),
			Vector3(-9, 0.1, -28), Vector3(-6, 0.1, -20), Vector3(-7, 0.1, -24), Vector3(-15, 0.1, -29),
			Vector3(-16, 0.1, -14), Vector3(-9, 0.1, -26)]:
		if await _preso(pos):
			presos.append(pos)
	_checar(presos.is_empty(), "nenhum dos 10 pontos de parede prende o jogador (presos: %s)" % str(presos))
	# desprender() é idempotente fora de paredes
	await _frames(5)
	p.global_position = Vector3(-23, 0.1, 1.5)
	await _frames(10)
	var antes: Vector3 = p.global_position
	_checar(not p.desprender() and p.global_position == antes, "desprender() não mexe em quem está livre")


# ---------------------------------------------------------------- B05
func _b05_quiz_final_esc() -> void:
	print("-- B05 Esc no meio do quiz final")
	var Painel3D = load("res://world/painel_3d.gd")
	var PainelUI = load("res://ui/painel_ui.gd")
	var placa = Painel3D.new("quiz_final")
	root.add_child(placa)
	await process_frame
	var lidos := []
	placa.lido.connect(func(i): lidos.append(i))
	placa.interagir(null)
	await process_frame
	await process_frame
	var ui = PainelUI.atual
	_checar(ui != null, "tela do quiz final abriu")
	await create_timer(2.6).timeout       # espera o texto "digitar"
	ui.avancar()                          # "Fazer o quiz!"
	_checar(ui._em_quiz, "entrou no quiz")
	await _tecla(KEY_ESCAPE)
	_checar(not ui.concluido and not GS.flag("ui_aberta"), "Esc fechou a tela sem concluir")
	await create_timer(0.3).timeout
	_checar(lidos.is_empty(), "Esc no meio do quiz não emite lido (%s)" % str(lidos))
	# agora até o fim
	placa.interagir(null)
	await process_frame
	await process_frame
	ui = PainelUI.atual
	await create_timer(2.6).timeout
	ui.avancar()
	for i in 3:
		var perguntas: Array = PainelUI.dados("quiz_final")["quiz"]
		ui.responder(int(perguntas[i]["correta"]))
		ui.avancar()
	await create_timer(0.3).timeout
	_checar(lidos == ["quiz_final"], "terminando o quiz, lido é emitido uma vez (%s)" % str(lidos))
	placa.queue_free()
	await process_frame


# ---------------------------------------------------------------- B06
func _b06_visor_troca_de_nivel() -> void:
	print("-- B06 trocar de nível com Q apertado")
	await _novo_castelinho()
	GS.set_flag("tem_visor")
	GS.set_flag("epoca_visor", GS.Epoca.E1950)
	GS.set_flag("visor_travado", false)
	Input.action_press("visor")
	for i in 20:
		await process_frame
	_checar(GS.epoca == GS.Epoca.E1950, "segurando Q: época 1950")
	await main.carregar_mundo(BARRA, "Spawn")       # o nível (e o Visor) são destruídos com Q ainda apertado
	await _frames(3)
	_checar(GS.epoca == GS.Epoca.E2020, "no nível seguinte a época voltou a hoje (época %d)" % GS.epoca)
	Input.action_release("visor")
	GS.set_flag("tem_visor", false)
	await main.carregar_mundo(CASTELINHO, "Spawn_volta_barra")
	await _frames(5)


# ---------------------------------------------------------------- B07
func _b07_enter_com_save() -> void:
	print("-- B07 Enter na tela de título")
	var recebido := []
	root.get_node("/root/Guia").cancelar()      # falas ativas do teste anterior engolem o Enter (Guia._input)
	for tem_save in [true, false]:
		GS.novo_jogo()
		GS.checkpoint_sala = 11 if tem_save else 1
		var titulo = load("res://ui/tela_titulo.tscn").instantiate()
		root.add_child(titulo)
		titulo.connect("comecar", func(c): recebido.append(c))
		await process_frame
		await _tecla(KEY_ENTER)
		titulo.queue_free()
		await process_frame
	_checar(recebido == [true, false], "Enter continua se há save e começa se não há (%s)" % str(recebido))


# ---------------------------------------------------------------- B12
func _b12_hud_ao_trocar_de_nivel() -> void:
	print("-- B12 HUD limpo ao trocar de nível")
	await _novo_castelinho()
	main.hud.lbl_aviso.text = "[E] Olhar o mural"
	main.hud.barra_stamina.visible = true
	main.hud.barra_stamina.value = 0.2
	await main.carregar_mundo(BARRA, "Spawn")
	await _frames(5)
	_checar(main.hud.lbl_aviso.text == "", "aviso '[E] ...' do nível anterior some ('%s')" % main.hud.lbl_aviso.text)
	_checar(not main.hud.barra_stamina.visible, "barra de fôlego do jogador anterior some")
	await main.carregar_mundo(CASTELINHO, "Spawn")
	await _frames(5)


# ---------------------------------------------------------------- B13
func _livre_no_chao(x: float, z: float) -> bool:
	var sp: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.28
	forma.height = 1.7
	q.shape = forma
	q.transform = Transform3D(Basis(), Vector3(x, 0.97, z))
	q.collision_mask = 1
	if not sp.intersect_shape(q, 1).is_empty():
		return false
	var r := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 0.6, z), Vector3(x, -0.5, z), 1))
	return not r.is_empty() and absf(r["position"].y) < 0.25


## Salas (gatilhos) que um jogador a pé alcança no térreo a partir do Spawn (grade de 0,5 m).
func _salas_alcancaveis() -> Array:
	var passo := 0.5
	var x0 := -30.0
	var z0 := -34.0
	var nx := int(32.5 / passo)
	var nz := int(37.0 / passo)
	var visto := {}
	var fila: Array = [Vector2i(int((-23.0 - x0) / passo), int((1.5 - z0) / passo))]
	visto[fila[0]] = true
	var i := 0
	while i < fila.size():
		var c: Vector2i = fila[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x > nx or n.y > nz or visto.has(n):
				continue
			if _livre_no_chao(x0 + n.x * passo, z0 + n.y * passo):
				visto[n] = true
				fila.append(n)
	var salas := []
	var nivel: Node3D = main.mundo.get_child(0)
	for n in nivel._triggers:
		var t = nivel._triggers[n]
		if t.position.y > 1.0:
			continue       # gatilhos de terraço (y 3,5 ou 6,8): não são do térreo
		for k in visto:
			var l: Vector3 = t.to_local(Vector3(x0 + k.x * passo, 0.5, z0 + k.y * passo))
			if absf(l.x) <= t.tamanho.x * 0.5 and absf(l.z) <= t.tamanho.z * 0.5:
				salas.append(n)
				break
	return salas


func _b13_entradas_fechadas() -> void:
	print("-- B13 o prédio só se entra pela porta de vidro")
	await _novo_castelinho()
	var sp: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for par in [["portão oeste 1 (z -24.8)", Vector3(-19.5, 0, -24.8), Vector3(-15.0, 0, -24.8)],
			["portão oeste 2 (z -26.6)", Vector3(-19.5, 0, -26.6), Vector3(-15.0, 0, -26.6)],
			["porta leste (z -19.4)", Vector3(-2.0, 0, -19.4), Vector3(-8.0, 0, -19.4)]]:
		var bloqueado := true
		for dz in [-0.5, 0.0, 0.5]:
			for y in [0.2, 1.0, 1.8, 2.1]:
				var de: Vector3 = par[1] + Vector3(0, y, dz)
				var ate: Vector3 = par[2] + Vector3(0, y, dz)
				if sp.intersect_ray(PhysicsRayQueryParameters3D.create(de, ate, 1)).is_empty():
					bloqueado = false
		_checar(bloqueado, "%s tem colisão" % par[0])
	GS.trocar_epoca(GS.Epoca.E1975)         # sem a cerca do museu (só em 2020)
	await _frames(3)
	var leste_1975 := true
	for y in [0.2, 1.0, 1.8]:
		if sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2.0, y, -19.4), Vector3(-8.0, y, -19.4), 1)).is_empty():
			leste_1975 = false
	_checar(leste_1975, "porta leste tem colisão também em 1975")
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(3)
	var fechada := _salas_alcancaveis()
	print("  (porta de vidro fechada: salas do térreo alcançáveis = %s)" % str(fechada))
	for n in [7, 9, 10, 11, 12, 13, 16, 21, 22, 23]:
		_checar(not fechada.has(n), "sala %d NÃO alcançável por fora com a porta de vidro fechada" % n)
	main.mundo.get_child(0)._abrir_porta_entrada(true)
	await _frames(4)
	var aberta := _salas_alcancaveis()
	for n in [7, 9, 10, 11, 12, 13, 16, 21, 22, 23]:
		_checar(aberta.has(n), "sala %d alcançável a pé com a porta aberta" % n)


# ---------------------------------------------------------------- B08
func _b08_carregamento() -> void:
	print("-- B08 tela de carregamento e aquecimento")
	var TelaCarregando = load("res://ui/tela_carregando.gd")
	main.aquecer_ativo = true
	GS.novo_jogo()
	GS.jogando = true
	var eventos := []
	var f_sala := func(n: int) -> void: eventos.append(["sala", n, is_instance_valid(TelaCarregando.ultima)])
	var f_epoca := func(e: int) -> void: eventos.append(["epoca", e])
	GS.sala_mudou.connect(f_sala)
	GS.epoca_mudou.connect(f_epoca)
	var t0 := Time.get_ticks_msec()
	var pronto := [false]
	var rodar := func() -> void:
		await main.carregar_mundo(CASTELINHO, "Spawn")
		pronto[0] = true
	rodar.call()
	await process_frame
	_checar(is_instance_valid(TelaCarregando.ultima), "a tela aparece no mesmo quadro em que o carregamento começa")
	while not pronto[0]:
		await process_frame
	await _frames(30)
	GS.sala_mudou.disconnect(f_sala)
	GS.epoca_mudou.disconnect(f_epoca)
	p = main.player
	print("  (carregamento levou %d ms em headless)" % (Time.get_ticks_msec() - t0))
	var trocas := eventos.filter(func(e): return e[0] == "epoca").size()
	_checar(trocas >= 4, "o aquecimento passou pelas épocas do nível (%d trocas)" % trocas)
	_checar(GS.epoca == GS.Epoca.E2020, "época restaurada (época %d)" % GS.epoca)
	var idx_sala := -1
	var idx_ultima_epoca := -1
	for i in eventos.size():
		if eventos[i][0] == "sala" and idx_sala < 0:
			idx_sala = i
		if eventos[i][0] == "epoca":
			idx_ultima_epoca = i
	_checar(idx_sala >= 0 and eventos[idx_sala][1] == 1 and idx_sala > idx_ultima_epoca,
		"o evento da sala 1 só dispara depois do aquecimento (%s)" % str(eventos))
	_checar(not is_instance_valid(TelaCarregando.ultima), "a tela foi removida")
	_checar(p.collision_layer == 2 and p.is_physics_processing(), "jogador restaurado (camada %d)" % p.collision_layer)
	var cams := 0
	for c in main.mundo.get_children():
		if c is Camera3D:
			cams += 1
	_checar(cams == 0, "a câmera de aquecimento foi removida (%d)" % cams)
	_checar(p.is_on_floor() and absf(p.global_position.y) < 0.3, "jogador no chão do Spawn (y=%.2f)" % p.global_position.y)
	# o mesmo em outros níveis (Ato II tem pontos próprios; a Barra usa as câmeras Cam_*)
	for nivel in [ATO2, BARRA]:
		await main.carregar_mundo(nivel, "Spawn")
		await _frames(10)
		_checar(is_instance_valid(main.player) and not is_instance_valid(TelaCarregando.ultima) and main.player.is_on_floor() or nivel == BARRA,
			"%s carregou com aquecimento (jogador no chão: %s)" % [nivel.get_file(), str(main.player.is_on_floor())])
	main.aquecer_ativo = false
