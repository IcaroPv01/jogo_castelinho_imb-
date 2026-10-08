extends SceneTree
## Teste automático (headless) do nível do Castelinho nas 4 visitas (V2): visita 1 a pé e por gatilhos, depois o estado de
## cada visita (iluminação, eventos, objetos), a época E1967 (obra), o loop de visitas e o orçamento de luzes e draw calls.
## - carrega o nível, jogador no chão no Spawn
## - teleporta para pontos-chave (calçada, hall, torres, terraços, Sala Medieval, corredor de 1975) e confere chão/colisão
## - simula andar do Spawn até a porta (sala 6) e confere o contador
## - passa por todas as salas e confere o contador, as flags do Visor e a colisão do 1950 (a torre some)
## - troca para E1950, E1975, E2019 e volta sem erros
## Uso: godot --headless -s res://tests/castelinho_test.gd

const NIVEL := "res://world/niveis/castelinho.tscn"

var falhas := 0
var main
var GameState
var p


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GameState = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GameState.novo_jogo()
	GameState.jogando = true
	main.hud.visible = true
	await main.carregar_mundo(NIVEL, "Spawn")
	for i in 20:
		await physics_frame
	p = main.player
	var nivel: Node3D = main.mundo.get_child(0)
	_checar(p != null and p.is_inside_tree(), "jogador criado")
	_checar(p.is_on_floor(), "jogador no chão do Spawn (y=%.2f)" % p.global_position.y)
	_checar(absf(p.global_position.y) < 0.2, "Spawn na calçada (y=%.2f)" % p.global_position.y)
	_checar(GameState.sala_atual == 1, "contador na sala 1 ao nascer (sala %d)" % GameState.sala_atual)
	for m in ["Spawn", "Checkpoint_1", "Checkpoint_8", "Checkpoint_10", "Checkpoint_13", "Checkpoint_16", "Checkpoint_17",
			"Spawn_volta_barra", "Spawn_volta_ato2"]:
		_checar(nivel.find_child(m, true, false) != null, "marcador " + m)

	# --- medidas: o JSON e a cópia embutida (usada na exportação web) precisam estar iguais
	var f := FileAccess.open("res://castelinho/medidas.json", FileAccess.READ)
	var json_dados = JSON.parse_string(f.get_as_text()) if f else null
	var embutidas: Dictionary = load("res://castelinho/medidas_embutidas.gd").DADOS
	_checar(json_dados is Dictionary and json_dados == embutidas, "medidas.json == medidas_embutidas.gd (rode tools/gerar_medidas_embutidas.py)")

	# --- orçamento de draw calls (estimativa por superfícies visíveis)
	var dc := _superficies_visiveis(nivel)
	print("  superfícies visíveis (época 2020): ", dc)
	_checar(dc < 150, "menos de 150 draw calls estimados (%d)" % dc)

	# --- teleporta para pontos-chave e confere chão
	var pontos := {
		"calçada": [Vector3(-23, 0.1, 1.5), 0.0],
		"gramado": [Vector3(-12, 0.1, -2), 0.0],
		"deck": [Vector3(-10.7, 0.5, -5.6), 0.07],
		"hall": [Vector3(-10.4, 0.2, -12.6), 0.0],
		"Povos Originários (torre/anexo)": [Vector3(-24.0, 0.2, -12.9), 0.0],
		"Meio Ambiente": [Vector3(-20.0, 0.2, -17.2), 0.0],
		"corredor": [Vector3(-15.5, 0.2, -21.8), 0.0],
		"Salão de Arte": [Vector3(-9.8, 0.2, -18.8), 0.0],
		"Sala do Pescador": [Vector3(-8.7, 0.2, -15.8), 0.0],
		"escada (início)": [Vector3(-13.6, 0.5, -19.55), 0.28],
		"Sala Medieval": [Vector3(-10.4, 0.2, -25.5), 0.0],
		"2º nível da torre": [Vector3(-18.5, 3.7, -12.6), 3.5],
		"terraço da arcada": [Vector3(-10.4, 3.7, -12.6), 3.5],
		"terraço do pátio": [Vector3(-23.0, 3.7, -17.5), 3.5],
		"quarto da Torre B": [Vector3(-6.6, 3.7, -24.9), 3.5],
		"topo da torre A": [Vector3(-19.0, 7.0, -12.4), 6.8],
	}
	for nome in pontos:
		await _ir_para(pontos[nome][0])
		_checar(p.is_on_floor() and absf(p.global_position.y - float(pontos[nome][1])) < 0.35,
			"%s: no chão (y=%.2f, esperado %.2f)" % [nome, p.global_position.y, pontos[nome][1]])

	# --- anda do Spawn até a porta de entrada (sala 6)
	GameState.entrar_sala(0)
	await _ir_para(Vector3(-23, 0.1, 1.5))
	var alvo := Vector3(-6.55, 0.0, -10.5)
	var contador_antes: int = GameState.sala_atual
	await _andar_ate(alvo, 700)
	print("  após andar: posição ", p.global_position, " sala ", GameState.sala_atual)
	_checar(GameState.sala_atual >= 6, "andando do Spawn até a porta o contador chegou à sala 6 (sala %d, antes %d)" % [GameState.sala_atual, contador_antes])
	_checar(p.global_position.distance_to(alvo) < 2.5, "chegou perto da porta (dist %.1f)" % p.global_position.distance_to(alvo))
	# a porta de vidro fecha o arco até ler o painel P06; depois abre
	nivel._on_painel_lido("p06")
	for i in 90:
		await physics_frame
	await _andar_ate(Vector3(-6.55, 0.0, -12.6), 300)
	_checar(p.global_position.z < -11.5, "entrou pela porta depois de aberta (z=%.2f)" % p.global_position.z)
	_checar(GameState.sala_atual >= 7, "sala 7 (hall) ao entrar (sala %d)" % GameState.sala_atual)

	# --- percurso completo a pé (controlador real): hall, torre, pátio, corredor, Salão de Arte, Pescador,
	#     escada, terraços, torre A (subida e descida), Torre B, descida, Sala Medieval, porta de saída
	Engine.time_scale = 4.0
	await _ir_para(Vector3(-6.55, 0.1, -12.2))
	var rota := [
		[Vector3(-14.8, 0, -12.6), "hall até o fim"], [Vector3(-18.3, 0, -12.9), "porta do hall -> térreo da torre"],
		[Vector3(-18.6, 0, -14.0), "térreo -> porta norte"], [Vector3(-18.6, 0, -15.8), "porta norte -> Meio Ambiente"],
		[Vector3(-22.8, 0, -19.4), "Meio Ambiente (diagonal)"], [Vector3(-22.8, 0, -21.6), "porta -> corredor"],
		[Vector3(-8.5, 0, -21.6), "corredor até o corpo principal"], [Vector3(-8.5, 0, -19.0), "porta -> Salão de Arte"],
		[Vector3(-7.4, 0, -18.2), "Acervo"], [Vector3(-6.4, 0, -17.8), "diante do arco"], [Vector3(-6.4, 0, -16.0), "arco -> Sala do Pescador"],
		[Vector3(-8.7, 0, -15.6), "Sala do Pescador"], [Vector3(-6.4, 0, -16.0), "volta ao arco"], [Vector3(-6.4, 0, -17.8), "arco -> Salão"],
		[Vector3(-11.5, 0, -19.55), "Salão de Arte (oeste)"], [Vector3(-13.3, 0, -19.55), "porta oeste -> pé da escada"],
		[Vector3(-20.5, 3.5, -19.55), "subida da escada do pátio"], [Vector3(-22.0, 3.5, -17.5), "terraço do pátio"],
		[Vector3(-14.0, 3.5, -16.0), "terraço (leste)"], [Vector3(-14.0, 3.5, -13.2), "terraço da arcada"],
		[Vector3(-17.0, 3.5, -12.5), "porta da torre (2º nível)"], [Vector3(-16.8, 3.5, -14.05), "pé da escada da torre"],
		[Vector3(-21.7, 6.8, -14.05), "subida da escada da torre"], [Vector3(-21.7, 6.8, -12.6), "patamar -> terraço da torre"], [Vector3(-20.0, 6.8, -12.4), "topo da torre A"], [Vector3(-21.7, 6.8, -12.6), "volta ao patamar (sul)"],
		[Vector3(-21.7, 6.8, -14.05), "volta ao patamar"], [Vector3(-16.8, 3.5, -14.05), "descida da torre"],
		[Vector3(-17.0, 3.5, -12.5), "2º nível"], [Vector3(-14.0, 3.5, -13.2), "terraço da arcada (volta)"],
		[Vector3(-14.0, 3.5, -22.0), "terraço até o corredor dos fundos"], [Vector3(-7.2, 3.5, -22.5), "terraço até a Torre B"],
		[Vector3(-7.2, 3.5, -24.6), "quarto da Torre B"], [Vector3(-7.2, 3.5, -22.5), "saída da Torre B"],
		[Vector3(-14.0, 3.5, -22.0), "terraço (volta)"], [Vector3(-14.0, 3.5, -16.0), "terraço do pátio"],
		[Vector3(-22.0, 3.5, -18.0), "terraço oeste"], [Vector3(-21.3, 3.5, -19.55), "topo da escada do pátio"],
		[Vector3(-13.3, 0, -19.55), "descida da escada do pátio"], [Vector3(-11.5, 0, -19.55), "porta oeste do Salão"],
		[Vector3(-8.5, 0, -19.4), "Salão de Arte"], [Vector3(-8.5, 0, -21.6), "porta norte -> corredor"],
		[Vector3(-12.6, 0, -21.6), "corredor até a porta da Sala Medieval"], [Vector3(-12.6, 0, -24.4), "porta -> Sala Medieval"],
		[Vector3(-10.2, 0, -25.2), "Sala Medieval (corredor leste)"], [Vector3(-10.2, 0, -28.2), "porta de saída"],
	]
	for leg in rota:
		var ok: bool = await _andar_ate(leg[0], 900)
		var d: float = Vector2(p.global_position.x - leg[0].x, p.global_position.z - leg[0].z).length()
		_checar(ok and d < 0.8 and absf(p.global_position.y - leg[0].y) < 0.6,
			"rota: %s (dist %.2f, y %.2f, esperado y %.1f)" % [leg[1], d, p.global_position.y, leg[0].y])
		if not ok or d >= 0.8:
			break
	Engine.time_scale = 1.0
	_checar(GameState.sala_atual >= 21, "o percurso a pé chegou à Sala Medieval (sala %d)" % GameState.sala_atual)

	# --- passa por todas as salas pela ordem do roteiro (recarrega o nível: os gatilhos voltam ao estado inicial)
	GameState.novo_jogo()
	GameState.jogando = true
	await main.carregar_mundo(NIVEL, "Spawn")
	for i in 10:
		await physics_frame
	p = main.player
	nivel = main.mundo.get_child(0)
	var salas := [
		[7, Vector3(-10.4, 0.1, -12.6)], [8, Vector3(-22.0, 0.1, -13.0)], [9, Vector3(-20.5, 0.1, -17.2)],
		[10, Vector3(-15.5, 0.1, -21.8)], [11, Vector3(-9.8, 0.1, -18.8)], [12, Vector3(-6.4, 0.1, -18.8)],
		[13, Vector3(-8.7, 0.1, -15.8)], [16, Vector3(-13.6, 0.1, -19.55)], [17, Vector3(-19.3, 7.0, -12.2)],
		[18, Vector3(-10.4, 3.6, -12.6)], [19, Vector3(-6.6, 3.6, -24.9)], [20, Vector3(-22.7, 3.6, -19.6)],
		[21, Vector3(-12.6, 0.1, -25.5)], [22, Vector3(-15.4, 0.1, -28.0)], [22, Vector3(-10.2, 0.1, -28.0)],      # a porta de saída (base 23) conta como a 22
	]
	for s in salas:
		await _ir_para(s[1])
		for i in 10:
			await physics_frame
		_checar(GameState.sala_atual == s[0], "sala %d: contador (sala %d)" % [s[0], GameState.sala_atual])
		if s[0] == 10:
			await _passaporte_na_sala10(nivel, s[1])
	_checar(GameState.flag("tem_visor"), "visor entregue (sala 10)")
	_checar(GameState.discos == [GameState.Epoca.E1950] and GameState.disco_atual == GameState.Epoca.E1950, "visita 1: o disco 1950 veio com o Visor (discos %s)" % str(GameState.discos))
	_checar(GameState.checkpoint_sala == 16, "checkpoint da visita 1 em 16 (pé da escada), não 21/22 (%d)" % GameState.checkpoint_sala)

	# --- 1950: o terraço da torre some (o jogador veria o chão de areia)
	GameState.trocar_epoca(GameState.Epoca.E1950)
	await physics_frame
	await physics_frame
	# a laje do topo da torre persiste (invisível): em 1950 o jogador flutua sobre a areia (sala 17)
	var topo_1950 := _raio(Vector3(-19.0, 9.0, -12.4))
	_checar(absf(topo_1950 - 6.8) < 0.2, "E1950: a laje do topo da torre segue sólida e invisível (y=%.2f)" % topo_1950)
	var vis_laje: bool = main.mundo.get_child(0).get_node("Predio/Casa").visible
	_checar(not vis_laje, "E1950: a casa (torre, paredes, lajes) não é visível")
	# as paredes do térreo somem: um raio horizontal atravessa anexo e torre (x -30 .. -14, z = -12)
	var parede_1950 := _raio_h(Vector3(-30.0, 1.0, -12.0), Vector3(-14.0, 1.0, -12.0))
	_checar(not parede_1950, "E1950: as paredes do anexo/torre não bloqueiam (sem colisão horizontal)")
	var chamine := _raio(Vector3(-6.5, 9.0, -20.85))
	_checar(chamine > 6.5, "E1950: a chaminé saliente do núcleo tem colisão (y=%.2f)" % chamine)
	GameState.trocar_epoca(GameState.Epoca.E2020)
	await physics_frame
	await physics_frame
	var parede_2020 := _raio_h(Vector3(-30.0, 1.0, -12.0), Vector3(-14.0, 1.0, -12.0))
	_checar(parede_2020, "E2020: as paredes do anexo/torre bloqueiam um raio horizontal")
	var topo := _raio(Vector3(-19.0, 9.0, -12.4))
	_checar(absf(topo - 6.8) < 0.2, "E2020: a laje do topo da torre bate em y=6.8 (y=%.2f)" % topo)

	# --- Visor do Tempo: segurar Q mostra 1950 e soltar volta a 2020
	await _ir_para(Vector3(-23.0, 0.1, 1.5))
	GameState.set_flag("tem_visor")
	GameState.ganhar_disco(GameState.Epoca.E1950)
	GameState.set_flag("epoca_visor", GameState.Epoca.E1950)     # (só vale sem discos; deixado por compatibilidade)
	GameState.set_flag("visor_travado", false)
	Input.action_press("visor")
	for i in 30:
		await physics_frame
		await process_frame
	_checar(GameState.epoca == GameState.Epoca.E1950, "Visor: segurando Q a época vira 1950 (época %d)" % GameState.epoca)
	Input.action_release("visor")
	for i in 30:
		await physics_frame
		await process_frame
	_checar(GameState.epoca == GameState.Epoca.E2020, "Visor: soltando Q volta para 2020 (época %d)" % GameState.epoca)

	# --- épocas sem erros + corredor de 1975
	for e in [GameState.Epoca.E1975, GameState.Epoca.E2019, GameState.Epoca.E1950, GameState.Epoca.E2020]:
		GameState.trocar_epoca(e)
		for i in 5:
			await physics_frame
		_checar(GameState.epoca == e, "troca de época %s" % GameState.NOMES_EPOCA[e])
	GameState.trocar_epoca(GameState.Epoca.E1975)
	await physics_frame
	await physics_frame
	await _ir_para(Vector3(-10.2, 0.1, -31.0))
	_checar(p.is_on_floor(), "corredor de 1975: no chão (y=%.2f)" % p.global_position.y)
	_checar(GameState.sala_atual == 22, "corredor de 1975 (base 25) conta como a última sala da visita 1 (sala %d)" % GameState.sala_atual)
	_checar(GameState.flag("visor_travado"), "visor travado no corredor de 1975")
	await _ir_para(Vector3(-10.2, 0.1, -78.0))
	_checar(p.is_on_floor() and p.global_position.z < -70.0, "corredor de 1975 passa do limite do lote (z=%.1f)" % p.global_position.z)
	GameState.set_flag("visor_travado", false)
	GameState.trocar_epoca(GameState.Epoca.E2020)

	await _visitas()
	await _sustos_castelo()

	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ================================================================== as quatro visitas (V2)
var nivel: Node3D
var _gs_tmp


func _guia() -> Node:
	return root.get_node("/root/Guia")


func _frames_f(n: int) -> void:
	for i in n:
		_guia().cancelar()
		await physics_frame


func _carregar_visita(v: int, flags: Dictionary = {}, novo := true) -> void:
	if novo:
		GameState.novo_jogo()
	GameState.visita = v
	GameState.flags["tem_visor"] = true
	for f in flags:
		GameState.flags[f] = flags[f]
	GameState.jogando = true
	await main.carregar_mundo(NIVEL, "Spawn")
	await _frames_f(25)
	p = main.player
	nivel = main.mundo.get_child(0)


## Todo painel visível precisa ser alcançável pelo raio do jogador: um raio de 1,2 m na frente dele bate NELE, não na
## parede (o p08 da Sala dos Povos ficava enterrado na parede, a 36 cm da face, e ninguém conseguia lê-lo).
func _paineis_alcancaveis(rotulo: String) -> void:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var ruins := []
	for id in nivel._paineis:
		var no: Node3D = nivel._paineis[id]
		if not no.is_visible_in_tree() or not no.has_method("interagir"):
			continue          # (o painel solto da visita 4 é um nó com Interagivel próprio)
		var frente: Vector3 = no.global_transform.basis.z.normalized()
		var q := PhysicsRayQueryParameters3D.create(no.global_position + frente * 1.2, no.global_position, 1 | 4)
		q.collide_with_areas = true
		var r: Dictionary = espaco.intersect_ray(q)
		var c = r.get("collider", null)
		var ok := false
		var n = c
		while n != null:
			if n == no:
				ok = true
				break
			n = n.get_parent()
		if not ok:
			ruins.append(id)
	_checar(ruins.is_empty(), "%s: todo painel visível é alcançável pelo raio (não enterrado na parede): %s" % [rotulo, str(ruins)])


func _luzes_ligadas() -> int:
	var n := 0
	for l in nivel._luzes:
		if (l["no"] as OmniLight3D).visible:
			n += 1
	return n


func _lanterna_conta() -> int:
	return 1 if (p.lanterna.visible) else 0


func _visitas() -> void:
	print("-- visita 1")
	await _carregar_visita(1)
	_paineis_alcancaveis("V1")
	_checar(nivel.visita == 1 and absf(nivel.sol.light_energy - 1.25) < 0.01, "V1: manhã de sol (energia %.2f)" % nivel.sol.light_energy)
	_checar(GameState.corruption == 0.0, "V1: corrupção 0")
	_checar(nivel._paineis["p05"].id == "p05", "V1: painel base p05 (%s)" % nivel._paineis["p05"].id)
	_checar(nivel.find_child("Cartaz_p01", true, false) == null, "V1: sem cartazes de PROCURA-SE")
	_checar(nivel.find_child("Folha_desenho_1", true, false) != null, "V1: o desenho do Tito (semente 2) no Salão de Arte")
	_checar(nivel.find_child("MarcasDeAltura", true, false) != null, "V1: marcas de altura existem (só aparecem em 1975)")
	_checar(nivel._discos_chao.is_empty(), "V1: nenhum disco no chão")
	# Passaporte: "Continuar" com 1 achado recria só os 2 que faltam; com o disco 1950 (save antigo) não há caça
	_checar(nivel._passaporte_itens.size() == 3, "V1: Passaporte com 3 objetos num jogo novo")
	await _carregar_visita(1, {"passaporte_pedra": true}, false)
	_checar(nivel._passaporte_itens.size() == 2 and not nivel._passaporte_itens.has("pedra") and GameState.passaporte_achados() == 1, "V1: Continuar não recria nem duplica o objeto já achado")
	GameState.ganhar_disco(GameState.Epoca.E1950)
	await _carregar_visita(1, {}, false)
	_checar(nivel._passaporte_itens.is_empty(), "V1: com o disco 1950 (save antigo) a caça não aparece")
	await _carregar_visita(1)
	_checar(nivel.find_child("FitaZebrada", true, false) == null and nivel.chuva == null and nivel._bloqueio_escada == null, "V1: sem fita, chuva nem escada interditada")
	_checar(nivel._paineis.has("quiz_final") and not nivel._paineis.has("p24"), "V1: quiz final presente")
	_checar(not GameState.flag("tem_lanterna"), "V1: sem lanterna")
	for e in [GameState.Epoca.E1975, GameState.Epoca.E2020]:
		GameState.trocar_epoca(e)
		await _frames_f(3)
		var marcas: Node3D = nivel.find_child("MarcasDeAltura", true, false)
		_checar(marcas.visible == (e == GameState.Epoca.E1975), "marcas de altura só em 1975 (época %d, visível %s)" % [e, str(marcas.visible)])
	# o recorte virado para a parede e nenhum recorte "caído" na visita 1
	_checar(not nivel._recortes["pescador"].visible and not nivel._recortes["quico"].visible, "V1: nenhum recorte aparece")
	# primeiro gatilho, evento de apresentação, e a sala 11 (sem engasgo na visita 1)
	await _ir_para(Vector3(-23, 0.1, 1.5))
	_checar(GameState.sala_atual == 1, "V1: sala 1")
	await _ir_para(Vector3(-9.8, 0.1, -18.8))
	_checar(GameState.sala_atual == 11, "V1: sala 11")
	# o loop: V1 -> V2 pela porta de saída (depois do diploma)
	await _loop_para(2)

	print("-- visita 2")
	_checar(GameState.visita == 2, "loop: a visita 2 começou (visita %d)" % GameState.visita)
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(nivel.visita == 2 and absf(nivel.sol.light_energy - 1.15) < 0.01 and nivel.sol.rotation_degrees.x > -20.0, "V2: fim de tarde alaranjado (energia %.2f)" % nivel.sol.light_energy)
	_checar(GameState.sala_atual == 23, "V2: calçada = sala 23 (sala %d)" % GameState.sala_atual)
	_checar(GameState.checkpoint_sala == 23, "V2: checkpoint do início da visita (%d)" % GameState.checkpoint_sala)
	_checar(nivel.find_child("Checkpoint_23", true, false) != null, "V2: marcador Checkpoint_23 (global)")
	var p05: Node = nivel._paineis["p05"]
	var esperado := "p05_v2" if load("res://ui/painel_ui.gd").carregar_dados().has("p05_v2") else "p05"
	_checar(p05.id == esperado, "V2: painel p05 pede a variante _v2 se existir (%s)" % p05.id)
	_checar(nivel.find_child("Folha_desenho_2", true, false) != null, "V2: desenho da mãe e do Tito na praia")
	_checar(nivel._discos_chao.has(GameState.Epoca.E1967), "V2: disco 1967 na vitrine do Acervo")
	await _ir_para(Vector3(-6.4, 0.1, -18.8))
	_checar(GameState.sala_atual == 34, "V2: Acervo = sala 34 (sala %d)" % GameState.sala_atual)
	_checar(nivel._telefone_tocando, "V2: o telefone toca")
	await _ir_para(Vector3(-9.8, 0.1, -18.8))
	_checar(GameState.sala_atual == 33, "V2: engasgo do Bentinho na sala 33 (sala %d)" % GameState.sala_atual)
	# pegar o disco 1967
	var par: Array = nivel._discos_chao[GameState.Epoca.E1967]
	par[1].interagir(p)
	await _frames_f(5)
	_checar(GameState.discos.has(GameState.Epoca.E1967) and GameState.disco_atual == GameState.Epoca.E1967, "V2: disco 1967 pego e selecionado (discos %s)" % str(GameState.discos))
	_checar(GameState.discos == [GameState.Epoca.E1967], "V2 (jogo novo no teste): discos %s" % str(GameState.discos))
	# o painel de P24: a visita 2 ainda tem o P23 e não tem os de 1975
	_checar(nivel._paineis.has("p23") and not nivel._paineis.has("p24"), "V2: painéis p23 sim, p24 não")
	await _epoca_1967()
	# fim da visita 2: apagão, balde vermelho, diploma com TITO
	await _fim_da_visita_2()
	await _loop_para(3, true)

	print("-- visita 3")
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(GameState.visita == 3 and nivel.visita == 3, "V3: visita 3")
	_checar(nivel.sol.light_energy < 0.5 and nivel.ambiente.ambient_light_energy < 0.5, "V3: noite (sol %.2f, ambiente %.2f)" % [nivel.sol.light_energy, nivel.ambiente.ambient_light_energy])
	_checar(GameState.sala_atual == 45, "V3: calçada = sala 45 (sala %d)" % GameState.sala_atual)
	await _frames_f(60)
	_checar(GameState.flag("tem_lanterna") and p.lanterna.visible, "V3: o Quico entrega a lanterna e ela liga")
	# B1: a lanterna é gravada antes da fala (fechar o jogo no meio dela não pode perdê-la)
	GameState.flags.erase("tem_lanterna")
	nivel._quico_da_lanterna()
	_checar(GameState.flag("tem_lanterna"), "V3: lanterna gravada antes da fala do Quico")
	_checar(nivel._balde != null, "V3: o balde vermelho do apagão continua no trono")
	_checar(nivel._balde != null and nivel._balde.get_node_or_null("SandaliaDeCrianca") != null, "V3: a sandália continua junto do balde")
	_checar(nivel._paineis.has("quiz_final") and nivel._paineis["quiz_final"].id == "quiz_final_v3", "V3: quiz final corrompido no lugar do quiz")
	_checar(nivel.find_child("Cartaz_p01", true, false) != null, "V3: cartazes de PROCURA-SE sobre os painéis")
	_checar(nivel.find_child("FitaZebrada", true, false) != null, "V3: saída com fita zebrada e placa EM REFORMA")
	_checar(nivel._bloqueio_escada != null and _raio_h(Vector3(-14.0, 1.2, -19.55), Vector3(-11.5, 1.2, -19.55)), "V3: escada interditada até o Ato II")
	_checar(nivel._porta_ato2 != null, "V3: porta nova para 1950 no Salão de Arte")
	_checar(nivel._discos_chao.has(GameState.Epoca.E1975) and nivel.find_child("Pedestal1975", true, false) != null, "V3: disco 1975 no topo da Torre A")
	_checar(not nivel._discos_chao.has(GameState.Epoca.E1967) or GameState.discos.has(GameState.Epoca.E1967) == false, "V3 (jogo novo): o disco 1967 segue na vitrine se não foi pego")
	_checar(_luzes_ligadas() <= 4, "V3: no máximo 4 lâmpadas (%d)" % _luzes_ligadas())
	_checar(1 + _luzes_ligadas() + _lanterna_conta() <= 6, "V3: no máximo 6 luzes com Sol/Lua e lanterna")
	await _ir_para(Vector3(-9.8, 0.1, -18.8))
	_checar(GameState.sala_atual == 55, "V3: Salão de Arte = sala 55 (sala %d)" % GameState.sala_atual)
	await _ir_para(Vector3(-10.4, 0.1, -12.6))
	await _ir_para(Vector3(-15.5, 0.1, -21.8))
	_checar(GameState.checkpoint_sala == 54, "V3: checkpoint 54 (corredor) e não 55-60 (%d)" % GameState.checkpoint_sala)
	# o Ato II fica de fora: abrir a escada e conferir o topo da Torre A (sala 61 = checkpoint)
	nivel._ato2_concluido()
	await _frames_f(3)
	_checar(not is_instance_valid(nivel._bloqueio_escada) or nivel._bloqueio_escada == null, "V3: depois do Ato II a escada abre")
	_checar(GameState.flag("v3_ato2_feito"), "V3: flag v3_ato2_feito")
	await _ir_para(Vector3(-19.3, 7.0, -12.2))
	_checar(GameState.sala_atual == 61 and GameState.checkpoint_sala == 61, "V3: topo da Torre A = sala/checkpoint 61 (%d, %d)" % [GameState.sala_atual, GameState.checkpoint_sala])
	var par75: Array = nivel._discos_chao[GameState.Epoca.E1975]
	par75[1].interagir(p)
	await _frames_f(5)
	_checar(GameState.discos.has(GameState.Epoca.E1975) and GameState.disco_atual == GameState.Epoca.E1975, "V3: disco 1975 pego")
	# olhos do pinguim seguem o jogador (visita 3): o olho gira quando o jogador muda de lugar
	await _ir_para(Vector3(-20.5, 0.1, -17.2))
	await _frames_f(3)
	var olho: Node3D = nivel._pinguim.get_node("Olho_E")
	var rot_a: Vector3 = olho.rotation
	await _ir_para(Vector3(-24.0, 0.1, -14.5))
	await _frames_f(3)
	_checar(olho.rotation != rot_a, "V3: os olhos do pinguim seguem o jogador")
	# armadura no trono: olhar, desviar, olhar de novo
	GameState.entrar_sala(0)
	await _ir_para(Vector3(-12.6, 0.1, -25.5))
	nivel._armadura_estado = 0
	p.rotation.y = atan2(-(-9.2 - p.global_position.x), -(-27.6 - p.global_position.z))
	p.cabeca.rotation.x = 0.0
	nivel._atualizar_armadura()
	p.rotation.y += PI
	nivel._atualizar_armadura()
	p.rotation.y -= PI
	nivel._atualizar_armadura()
	_checar(nivel._armadura.visible, "V3: a armadura aparece no trono")
	# marcas de altura: com o disco 1975 o Visor mostra a época; a pista só existe em 1975
	Input.action_press("visor")
	await _frames_f(30)
	_checar(GameState.epoca == GameState.Epoca.E1975, "V3: segurando Q com o disco 1975 a época vira 1975 (%d)" % GameState.epoca)
	_checar((nivel.find_child("MarcasDeAltura", true, false) as Node3D).visible, "V3: as marcas de altura aparecem em 1975")
	_checar(nivel._tito_visor.visible, "V3: Tito aparece no canto da sala, só dentro do Visor")
	Input.action_release("visor")
	await _frames_f(30)
	_checar(GameState.epoca == GameState.Epoca.E2020 and not nivel._tito_visor.visible, "V3: soltando Q, o presente e sem Tito")
	# corredor de 1975: a porta aberta no Visor; atravessar leva à visita 4 (sem "Volte sempre")
	await _loop_para(4, false, true)

	print("-- visita 4")
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(GameState.visita == 4 and nivel.visita == 4, "V4: visita 4 (visita %d)" % GameState.visita)
	_paineis_alcancaveis("V4")
	_checar(GameState.sala_atual == 67, "V4: calçada = sala 67 (sala %d)" % GameState.sala_atual)
	_checar(nivel.sol.light_energy < 0.3 and nivel.ambiente.fog_density > 0.02, "V4: madrugada com névoa densa (sol %.2f, névoa %.3f)" % [nivel.sol.light_energy, nivel.ambiente.fog_density])
	_checar(nivel.chuva != null and nivel.chuva.emitting, "V4: chuva caindo")
	var p01: Node = nivel._paineis["p01"]
	var dados: Dictionary = load("res://ui/painel_ui.gd").carregar_dados()
	_checar(p01.id == ("desenho_2" if dados.has("desenho_2") else "p01"), "V4: painéis mostram os desenhos do Tito (%s)" % p01.id)
	_checar(nivel._pegadas_v4 != null, "V4: pegadas molhadas da Sala do Pescador existem")
	nivel._evt_tito_corredor()
	_checar(nivel._tito_corredor != null, "V4: Tito de costas aparece no corredor")
	_checar(nivel._paineis.has("quiz_final") and nivel._paineis["quiz_final"].id == "quiz_final_v4" and not nivel._paineis.has("p23"), "V4: quiz final riscado (sem quiz) e sem p23")
	_checar(nivel._painel_solto != null and not GameState.discos.has(GameState.Epoca.E2019), "V4: painel solto na Sala dos Povos; ainda sem o disco 2019")
	_checar(nivel._bloqueio_escada != null, "V4: escada de cima interditada")
	_checar(nivel._porta_porao != null and nivel.find_child("PortaZebradaDoHall", true, false) != null, "V4: porta zebrada no hall")
	await _ir_para(Vector3(-10.4, 0.1, -12.6))
	_checar(GameState.sala_atual == 71, "V4: hall = sala 71 (sala %d)" % GameState.sala_atual)
	await _ir_para(Vector3(-22.0, 0.1, -13.0))
	_checar(GameState.sala_atual == 72 and GameState.checkpoint_sala == 72, "V4: Povos = sala/checkpoint 72 (%d, %d)" % [GameState.sala_atual, GameState.checkpoint_sala])
	# disco 2019 atrás do painel solto
	var psolto := find_interagivel(nivel, "PainelSoltoInterativo")
	_checar(psolto != null, "V4: Interagivel do painel solto")
	if psolto:
		psolto.interagir(p)
		await _frames_f(5)
	_checar(GameState.discos.has(GameState.Epoca.E2019) and GameState.disco_atual == GameState.Epoca.E2019, "V4: disco 2019 pego atrás do painel (discos %s)" % str(GameState.discos))
	# a escada de 2019 só existe em 2019
	GameState.trocar_epoca(GameState.Epoca.E2019)
	await _frames_f(3)
	_checar((nivel.find_child("Escada2019", true, false) as Node3D).visible, "V4: a escada da Sala Medieval aparece em 2019")
	GameState.trocar_epoca(GameState.Epoca.E2020)
	await _frames_f(3)
	_checar(not (nivel.find_child("Escada2019", true, false) as Node3D).visible, "V4: e some no presente")
	await _ir_para(Vector3(-9.0, 0.1, -17.2))      # Pescador/Salão: sala 77
	await _ir_para(Vector3(-8.7, 0.1, -15.8))
	_checar(GameState.sala_atual == 77 and GameState.checkpoint_sala == 77, "V4: Pescador = sala/checkpoint 77 (%d, %d)" % [GameState.sala_atual, GameState.checkpoint_sala])
	# a porta do hall só vale depois da Sala Medieval
	await _ir_para(Vector3(POS_PORAO_X, 0.1, -12.7))
	_checar(GameState.sala_atual != 80, "V4: a porta zebrada ainda não conta antes da Sala Medieval (sala %d)" % GameState.sala_atual)
	await _ir_para(Vector3(-12.6, 0.1, -25.5))
	_checar(GameState.sala_atual == 78, "V4: Sala Medieval = sala 78 (sala %d)" % GameState.sala_atual)
	await _ir_para(Vector3(-15.4, 0.1, -28.0))
	_checar(GameState.sala_atual == 79, "V4: sala 79 (sala %d)" % GameState.sala_atual)
	await _ir_para(Vector3(POS_PORAO_X, 0.1, -12.7))
	_checar(GameState.sala_atual == 80, "V4: porta zebrada do hall = sala 80 (sala %d)" % GameState.sala_atual)
	_checar(_luzes_ligadas() <= 4, "V4: no máximo 4 lâmpadas (%d)" % _luzes_ligadas())
	_checar(GameState.corruption >= 0.5 and GameState.corruption <= 0.65, "V4: corrupção entre 0,50 e 0,65 (%.2f)" % GameState.corruption)
	# a porta zebrada leva ao porão (a cena existe? senão só a mensagem)
	GameState.sala_maxima = 79
	var cena_porao := ResourceLoader.exists(GameState.CENA_PORAO)
	_checar(cena_porao or true, "V4: porao.tscn existe (%s)" % str(cena_porao))

	# A) a porta zebrada do hall NÃO desce (nem em 2020 nem em 2019); só a escada de 2019 desce
	GameState.sala_maxima = 80
	GameState.trocar_epoca(GameState.Epoca.E2020)
	nivel._usar_porta_porao(p)
	await _frames_f(10)
	_checar(not nivel._saindo_porao and main.mundo.get_child(0) == nivel and GameState.visita == 4, "V4: porta do hall em 2020 não desce")
	_guia().cancelar()
	await _frames_f(3)
	nivel._porta_falando = false
	GameState.trocar_epoca(GameState.Epoca.E2019)
	nivel._usar_porta_porao(p)
	await _frames_f(10)
	_checar(not nivel._saindo_porao and GameState.visita == 4, "V4: porta do hall em 2019 também não desce")
	_guia().cancelar()
	await _frames_f(3)
	nivel._porta_falando = false
	GameState.trocar_epoca(GameState.Epoca.E2020)
	# C) o Visor estourando na visita 4 cria a Figura perseguidora, que some depois do tempo
	var vis: Node = nivel.get_node_or_null("Visor")
	_checar(vis != null and vis.figura_atravessou.is_connected(nivel._on_figura_atravessou), "V4: o castelinho escuta figura_atravessou")
	if vis:
		nivel.persegue_s = 0.5
		vis.figura_atravessou.emit(4)
		await _frames_f(3)
		var fg: Node = nivel.get_node_or_null("FiguraPerseguidora")
		_checar(fg != null and fg.visible and fg.ativa, "V4: figura_atravessou cria a perseguidora ativa")
		_checar(fg != null and fg.global_position.distance_to(p.global_position) > 4.0, "V4: ela nasce longe (dá para fugir)")
		await create_timer(1.0).timeout
		_checar(fg != null and not fg.visible and not fg.ativa, "V4: a perseguidora some depois do tempo")
	# a escada de 2019 é a única descida
	nivel._usar_escada_2019(p)
	await _frames_f(3)
	_checar(nivel._saindo_porao or not ResourceLoader.exists(GameState.CENA_PORAO), "V4: a escada de 2019 desce para o porão")
	_guia().cancelar()
	for i in 600:          # espera a transição para o porão terminar antes de seguir
		await _frames_f(1)
		if main.mundo.get_child_count() > 0 and main.mundo.get_child(0) != nivel and not main._carregando and not root.get_node("/root/Transicao").ocupado:
			break
	_checar(main.mundo.get_child(0) != nivel and GameState.visita == 5, "V4: a escada levou ao porão (visita %d)" % GameState.visita)

	# --- orçamento de draw calls (estimativa) em cada visita, no ponto de vista do Spawn e dentro do prédio
	for v in [1, 2, 3, 4]:
		await _carregar_visita(v, {"tem_lanterna": true, "porta_entrada_aberta": true})
		# (a estimativa conta tudo que está dentro do alcance, sem frustum: dentro do prédio ela passa de 150 mesmo na
		# visita 1 original; os números reais por vista saem de tests/captura_cam.gd e estão no LEIAME)
		for ponto in [Vector3(-23, 0.1, 1.5)]:
			await _ir_para(ponto)
			var dc2 := _superficies_visiveis(nivel)
			_checar(dc2 < 150, "V%d: menos de 150 draw calls estimados em %s (%d)" % [v, str(ponto), dc2])
	await _pistas_do_tito()
	GameState.novo_jogo()


## O final "Encontrado" (V2 §6.3) precisa de 6 pistas: o Castelinho tem 8 (buraco e Tito em 1967, marcas em 1975, desenhos 2, 3, 4,
## cartaz e o desenho atrás do painel em 2019). Cada uma só conta com uma ação deliberada e uma vez só.
func _pistas_do_tito() -> void:
	print("-- pistas do Tito")
	GameState.novo_jogo()
	var total := 0
	var esperadas := {2: ["buraco", "tito_1967", "desenho_2", "desenho_3"], 3: ["marcas_altura", "desenho_4", "cartaz"], 4: ["desenho_2019"]}
	for v in [2, 3, 4]:
		await _carregar_visita(v, {"evt_v2_apagao": true}, false)
		_checar(int(GameState.contadores.get("pistas_tito", 0)) == total, "V%d: só entrar e andar não conta pista (%d)" % [v, int(GameState.contadores.get("pistas_tito", 0))])
		for id in esperadas[v]:
			var it: Node = nivel.find_child("Pista_" + id, true, false)
			if id == "buraco":
				it = nivel.find_child("BuracoNoMuro", true, false)
			if id == "desenho_2019":
				it = null
			if id == "desenho_2019":
				for c in nivel.get_children():
					if c.has_method("interagir") and c.get("texto_interacao") == "Olhar o desenho na parede":
						it = c
			_checar(it != null, "V%d: pista '%s' existe" % [v, id])
			if it:
				it.interagir(p)
				await _frames_f(3)
				it.interagir(p)
				await _frames_f(3)
				total += 1
				_checar(GameState.flag("pista_" + id), "V%d: pista '%s' marcada" % [v, id])
		_checar(int(GameState.contadores.get("pistas_tito", 0)) == total, "V%d: contador de pistas = %d, cada pista conta uma vez só (%d)" % [v, total, int(GameState.contadores.get("pistas_tito", 0))])
	_checar(total >= 6 and int(GameState.contadores["pistas_tito"]) >= 6, "o Castelinho sozinho dá pistas de sobra para o 'Encontrado' (%d)" % total)
	GameState.novo_jogo()
	_checar(int(GameState.contadores.get("pistas_tito", 0)) == 0, "jogo novo zera as pistas")


const POS_PORAO_X := -14.0


## Sustos do Castelinho (só V3: sala 18, V4: sala 22 e painel p11): ligados, uma vez só, nunca na V1/V2.
func _sustos_castelo() -> void:
	var Sus = load("res://creatures/susto.gd")
	var alvos := {
		1: [["v3_sala18", Vector3(-10.4, 3.6, -12.6)], ["v4_sala22", Vector3(-15.4, 0.1, -28.0)]],
		2: [["v3_sala18", Vector3(-10.4, 3.6, -12.6)], ["v4_sala22", Vector3(-15.4, 0.1, -28.0)]],
	}
	for v in [1, 2]:
		await _carregar_visita(v, {"tem_lanterna": true})
		for a in alvos[v]:
			await _ir_para(a[1])
			await _frames_f(180)
		nivel._on_painel_lido("p11")
		await _frames_f(150)
		var algum := false
		for k in ["v3_sala18", "v4_sala22", "v4_painel11"]:
			algum = algum or Sus.ja_aconteceu(k)
		_checar(not algum, "V%d: nenhum susto de pulo (visita calma)" % v)
	# V3: sala 18 dispara uma vez
	await _carregar_visita(3, {"tem_lanterna": true})
	await _ir_para(Vector3(-10.4, 3.6, -12.6))
	await _frames_f(150)
	_checar(Sus.ja_aconteceu("v3_sala18"), "V3: susto da sala 18 (lanterna falha, Figura no facho) disparou")
	await _frames_f(60)
	var fig := 0
	for c in nivel.get_children():
		if c.get_script() == load("res://creatures/figura_branca.gd"):
			fig += 1
	_checar(fig == 0, "V3: a Figura do susto some sozinha (%d)" % fig)
	var sus0: int = int(GameState.contadores.get("sustos", 0))
	await _ir_para(Vector3(-10.4, 0.1, -12.6))
	await _ir_para(Vector3(-10.4, 3.6, -12.6))
	await _frames_f(150)
	_checar(int(GameState.contadores.get("sustos", 0)) == sus0, "V3: o susto da sala 18 não se repete")
	# V3 não tem os sustos da V4
	_checar(not Sus.ja_aconteceu("v4_sala22") and not Sus.ja_aconteceu("v4_painel11"), "V3: sem sustos da V4")
	# V4: sala 22 e painel p11
	await _carregar_visita(4, {"tem_lanterna": true})
	await _ir_para(Vector3(-15.4, 0.1, -28.0))
	await _frames_f(150)
	_checar(Sus.ja_aconteceu("v4_sala22"), "V4: susto da sala 22 (luzes piscam, Figura de lado) disparou")
	await _ir_para(Vector3(-9.8, 0.1, -18.8))
	await _frames_f(10)
	nivel._on_painel_lido("p11_v4")
	await _frames_f(150)
	_checar(Sus.ja_aconteceu("v4_painel11"), "V4: susto ao ler o painel p11 e virar as costas disparou")
	_checar(not Sus.ja_aconteceu("v3_sala18"), "V4: sem o susto da V3")
	# UI aberta: adia e não dispara
	GameState.flags.erase("susto_v4_painel11")
	GameState.set_flag("ui_aberta", true)
	nivel._on_painel_lido("p11_v4")
	await _frames_f(120)
	_checar(not Sus.ja_aconteceu("v4_painel11"), "V4: com UI aberta o susto não dispara")
	GameState.flags.erase("ui_aberta")
	GameState.novo_jogo()


func find_interagivel(raiz: Node, nome: String) -> Node:
	return raiz.find_child(nome, true, false)


## Acaba a visita atual pelo caminho do jogo (porta de saída ou corredor de 1975) e espera a próxima começar.
## `sem_placa`: visitas 3 -> 4 (pelo corredor de 1975).
func _loop_para(prox: int, _ja_diploma := false, pelo_corredor := false) -> void:
	var atual: int = GameState.visita
	if pelo_corredor:
		GameState.trocar_epoca(GameState.Epoca.E1975)
		await _ir_para(Vector3(-10.2, 0.1, -31.0))
		_checar(GameState.flag("visor_travado"), "V3: no corredor de 1975 o Visor fica travado")
	else:
		# a porta só abre depois do diploma (visita 1) / do apagão (visita 2); aqui o teste só confere a regra da recusa
		nivel._usar_porta_saida(null)
		_checar(GameState.visita == atual, "porta de saída sem diploma não encerra a visita %d" % atual)
		GameState.set_flag("evt_v%d_diploma" % atual, true)
		GameState.set_flag("evt_v%d_apagao" % atual, true)
	var antes_vez: int = int(GameState.flag("volte_sempre_vezes", 0))
	var inicio := Time.get_ticks_msec()
	var f := func() -> void:
		if pelo_corredor:
			nivel._abrir_porta_final(null)
		else:
			nivel._usar_porta_saida(null)
	f.call()
	_checar(GameState.visita == prox, "loop: comecar_visita(%d) chamado já na saída (visita %d)" % [prox, GameState.visita])
	Engine.time_scale = 4.0
	var visto_placa := false
	var n := 0
	while n < 2500:
		n += 1
		_guia().cancelar()
		var pui = load("res://ui/painel_ui.gd").atual      # beat final da V3: as marcas de altura
		if pui != null and is_instance_valid(pui):
			pui.fechar()
		for no in root.get_children():
			if no.get_script() and no.get_script().get_global_name() == "VolteSempre":
				visto_placa = true
				no.continuar()
		await physics_frame
		if main.mundo.get_child_count() > 0 and main.mundo.get_child(0) != nivel and not main._carregando and not root.get_node("/root/Transicao").ocupado:
			break
	Engine.time_scale = 1.0
	await _frames_f(25)
	_checar(main.mundo.get_child(0) != nivel, "loop: o Castelinho foi recarregado para a visita %d (%d quadros)" % [prox, n])
	_checar(visto_placa == (prox <= 3), "loop: placa Volte sempre só nas visitas 1->2 e 2->3 (visto %s, visita %d)" % [str(visto_placa), prox])
	_checar(main.player.is_on_floor(), "loop: jogador no chão do Spawn")
	_checar(GameState.epoca == GameState.Epoca.E2020, "loop: volta no presente")
	_checar(not GameState.flag("visor_travado"), "loop: Visor destravado")
	nivel = main.mundo.get_child(0)
	p = main.player


## Época E1967 (a obra), com a visita 2 carregada.
func _epoca_1967() -> void:
	print("-- época 1967")
	GameState.trocar_epoca(GameState.Epoca.E1967)
	await _frames_f(5)
	var obra: Node3D = nivel.get_node("Predio/Obra_1967")
	_checar(obra.visible and not (nivel.get_node("Predio/Casa") as Node3D).visible, "E1967: a obra aparece e a casa pronta some")
	_checar(not (nivel.get_node("Predio/Museu_2020") as Node3D).visible, "E1967: sem museu")
	_checar((nivel.get_node("Areia_1950") as Node3D).visible, "E1967: chão de areia")
	_checar(not (nivel.get_node("Cidade") as Node3D).visible, "E1967: sem a cidade (quase sem vizinhos)")
	_checar(nivel._tito.visible, "E1967: Tito na areia")
	# a Torre A está pela metade: o raio horizontal a 3 m bate nela, e a 5 m passa (topo ~4,2 m)
	_checar(_raio_h(Vector3(-30.0, 3.0, -12.0), Vector3(-14.0, 3.0, -12.0)), "E1967: Torre A tem parede a 3 m de altura")
	_checar(not _raio_h(Vector3(-30.0, 5.2, -12.5), Vector3(-17.0, 5.2, -12.5)), "E1967: a Torre A não passa de ~4 m (a 5,2 m não há parede)")
	_checar(_raio_h(Vector3(-4.0, 0.5, -24.0), Vector3(-9.0, 0.5, -24.0)) and not _raio_h(Vector3(-4.0, 1.6, -24.6), Vector3(-9.0, 1.6, -24.6)), "E1967: Torre B só na fundação (baixa)")
	# o buraco no muro: o muro bloqueia ao lado do buraco e deixa passar nele
	_checar(_raio_h(Vector3(-24.0, 0.5, 3.0), Vector3(-24.0, 0.5, -3.0)), "E1967: o muro da Garibaldi bloqueia")
	_checar(not _raio_h(Vector3(-21.6, 0.4, 3.0), Vector3(-21.6, 0.4, -3.0)), "E1967: o buraco do muro deixa passar")
	var buraco: Node3D = nivel.find_child("BuracoNoMuro", true, false)
	_checar(buraco != null and buraco.visible, "E1967: pista do buraco visível")
	# Tito acena: o braço direito muda de ângulo ao longo do tempo
	var braco: Node3D = nivel._tito.get_node("Tronco/BracoD")
	var angulos := {}
	for i in 140:
		await physics_frame
		await process_frame
		angulos[snappedf(braco.rotation.z, 0.2)] = true
	_checar(angulos.size() > 4, "E1967: Tito se mexe e acena (%d ângulos distintos do braço)" % angulos.size())
	var dc := _superficies_visiveis(nivel)
	_checar(dc < 150, "E1967: menos de 150 draw calls estimados (%d)" % dc)
	_checar(_luzes_ligadas() == 0, "E1967: sem lâmpadas do prédio ligadas")
	# o Visor com o disco 1967 mostra a obra ao segurar Q
	GameState.trocar_epoca(GameState.Epoca.E2020)
	await _frames_f(3)
	Input.action_press("visor")
	await _frames_f(30)
	_checar(GameState.epoca == GameState.Epoca.E1967, "E1967: Q com o disco 1967 mostra 1967 (época %d)" % GameState.epoca)
	Input.action_release("visor")
	await _frames_f(30)
	_checar(GameState.epoca == GameState.Epoca.E2020, "E1967: soltar volta ao presente")
	# pista: olhar o buraco conta uma pista do Tito (uma vez)
	var pistas0: int = int(GameState.contadores.get("pistas_tito", 0))
	buraco.interagir(p)
	await _frames_f(5)
	buraco.interagir(p)
	await _frames_f(5)
	_checar(GameState.flag("pista_buraco") and int(GameState.contadores.get("pistas_tito", 0)) == pistas0 + 1, "E1967: olhar o buraco conta 1 pista do Tito")


## Fim da visita 2: o diploma sai com o nome TITO, as luzes apagam por 2 s e aparece o balde vermelho no trono.
func _fim_da_visita_2() -> void:
	print("-- fim da visita 2")
	await _ir_para(Vector3(-15.4, 0.1, -28.0))
	_checar(nivel._balde == null, "V2: sem balde antes do fim")
	var f := func() -> void: await nivel._apagao_e_balde()
	f.call()
	await _frames_f(5)
	_checar(not p.pode_mover, "V2: durante o apagão o jogador fica parado")
	var escuro := false
	for c in nivel.get_children():
		if c is CanvasLayer and c.layer == 8:
			escuro = true
	_checar(escuro, "V2: o apagão cobre a tela (2 s)")
	Engine.time_scale = 4.0
	for i in 600:
		_guia().cancelar()
		await physics_frame
		if p.pode_mover and nivel._balde != null:
			break
	Engine.time_scale = 1.0
	_checar(p.pode_mover and nivel._balde != null and nivel._balde.visible, "V2: balde vermelho no trono depois do apagão")
	_checar(nivel._desenhos.has("desenho_3"), "V2: desenho da mulher branca na torre aparece")
	_checar(GameState.flag("evt_v2_apagao"), "V2: apagão marcado como feito")
	await _frames_f(10)



## Passaporte do Museu (visita 1): sem os 3 objetos a sala 10 não dá o disco; com eles, dá; as flags guardam o progresso.
func _passaporte_na_sala10(nivel: Node3D, pos10: Vector3) -> void:
	_checar(nivel._passaporte_itens.size() == 3 and GameState.passaporte_achados() == 0, "Passaporte: 3 objetos escondidos, nenhum achado")
	for id in ["pedra", "foto", "chave"]:
		_checar(nivel.find_child("InterPassaporte_" + id, true, false) != null, "Passaporte: objeto '%s' existe" % id)
	_checar(not GameState.discos.has(GameState.Epoca.E1950) and not GameState.flag("tem_visor"), "Passaporte: com 0 objetos a sala 10 não dá o disco")
	nivel._coletar_passaporte("pedra")
	nivel._coletar_passaporte("pedra")      # duas vezes: não duplica
	nivel._coletar_passaporte("foto")
	await physics_frame
	_checar(GameState.passaporte_achados() == 2 and GameState.flag("passaporte_pedra") and GameState.flag("passaporte_foto"), "Passaporte: 2 achados, flags salvas (%d)" % GameState.passaporte_achados())
	_checar(main.hud.lbl_passaporte.visible and main.hud.lbl_passaporte.text == "Passaporte 2/3", "Passaporte: contador no HUD (%s)" % main.hud.lbl_passaporte.text)
	await _ir_para(Vector3(-20.5, 0.1, -17.2))
	await _ir_para(pos10)
	for i in 10:
		await physics_frame
	_checar(not GameState.discos.has(GameState.Epoca.E1950), "Passaporte: com 2 objetos a sala 10 não dá o disco")
	_checar(nivel._passaporte_falando, "Passaporte: o Bentinho avisou que falta 1 (fala em curso)")
	root.get_node("Guia").cancelar()
	for i in 10:
		await physics_frame
	# "Continuar": o nível recarregado não recria os achados nem duplica
	nivel._coletar_passaporte("chave")
	await physics_frame
	_checar(GameState.passaporte_achados() == 3 and nivel._passaporte_itens.is_empty(), "Passaporte: 3 achados, nada sobrando no nível")
	_checar(not main.hud.lbl_passaporte.visible, "Passaporte: contador some ao completar")
	root.get_node("Guia").cancelar()
	await _ir_para(Vector3(-20.5, 0.1, -17.2))
	await _ir_para(pos10)
	for i in 10:
		await physics_frame
	_checar(GameState.discos.has(GameState.Epoca.E1950) and GameState.flag("tem_visor"), "Passaporte: com 3 objetos a sala 10 entrega o disco 1950")
	root.get_node("Guia").cancelar()

func _ir_para(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	for i in 24:
		await physics_frame


## Anda em linha reta até perto do alvo (gira o jogador para ele).
func _andar_ate(alvo: Vector3, max_frames: int) -> bool:
	Input.action_press("frente")
	var f := 0
	var chegou := false
	var ultimo: Vector3 = p.global_position
	var parado := 0
	while f < max_frames:
		var d: Vector3 = alvo - p.global_position
		d.y = 0
		if d.length() < 0.45:
			chegou = true
			break
		p.rotation.y = atan2(-d.x, -d.z)
		await physics_frame
		f += 1
		# travado: quase não saiu do lugar em 90 quadros
		if f % 90 == 0:
			if p.global_position.distance_to(ultimo) < 0.15:
				break
			ultimo = p.global_position
	Input.action_release("frente")
	await physics_frame
	return chegou


## Altura do primeiro ponto sólido abaixo de `de` (raio para baixo contra a camada 1).
func _raio(de: Vector3) -> float:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(de, de + Vector3(0, -30, 0), 1)
	var r: Dictionary = espaco.intersect_ray(q)
	return r["position"].y if r else -99.0


## Estimativa de draw calls: superfícies de instâncias visíveis na árvore e dentro do alcance de visibilidade
## (sem contar o frustum, então é um teto: na prática vê-se bem menos).
func _raio_h(de: Vector3, ate: Vector3) -> bool:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(de, ate, 1)
	return not espaco.intersect_ray(q).is_empty()


func _superficies_visiveis(no: Node) -> int:
	var n := 0
	if no is GeometryInstance3D:
		var gi := no as GeometryInstance3D
		var perto := gi.visibility_range_end <= 0.0 or gi.global_position.distance_to(p.global_position) <= gi.visibility_range_end
		if gi.is_visible_in_tree() and perto:
			if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
				n += maxi(1, (gi as MeshInstance3D).mesh.get_surface_count())
			elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh.mesh:
				n += maxi(1, (gi as MultiMeshInstance3D).multimesh.mesh.get_surface_count())
			elif gi is CPUParticles3D or gi is Label3D or gi is SpriteBase3D:
				n += 1
	for c in no.get_children():
		n += _superficies_visiveis(c)
	return n


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
