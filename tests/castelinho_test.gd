extends SceneTree
## Teste automático (headless) do nível do Castelinho (salas 1-25).
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
	for m in ["Spawn", "Checkpoint_1", "Checkpoint_6", "Checkpoint_16", "Checkpoint_25", "Spawn_volta_barra"]:
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
		[21, Vector3(-12.6, 0.1, -25.5)], [22, Vector3(-15.4, 0.1, -28.0)], [23, Vector3(-10.2, 0.1, -28.0)],
	]
	for s in salas:
		await _ir_para(s[1])
		for i in 10:
			await physics_frame
		_checar(GameState.sala_atual == s[0], "sala %d: contador (sala %d)" % [s[0], GameState.sala_atual])
	_checar(GameState.flag("tem_visor"), "visor entregue (sala 10)")
	_checar(int(GameState.flag("epoca_visor", -1)) == GameState.Epoca.E1975, "epoca_visor = 1975 (salas 23-24)")

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
	GameState.set_flag("epoca_visor", GameState.Epoca.E1950)
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
	_checar(GameState.sala_atual == 25, "sala 25 no corredor de 1975 (sala %d)" % GameState.sala_atual)
	_checar(GameState.flag("visor_travado"), "visor travado no corredor de 1975")
	await _ir_para(Vector3(-10.2, 0.1, -78.0))
	_checar(p.is_on_floor() and p.global_position.z < -70.0, "corredor de 1975 passa do limite do lote (z=%.1f)" % p.global_position.z)
	GameState.set_flag("visor_travado", false)
	GameState.trocar_epoca(GameState.Epoca.E2020)

	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


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
