extends SceneTree
## Varredura v34 (QA automatizado, só leitura do jogo): Castelinho visitas 3 e 4, Ato II (salas 55-60) e saída para o porão.
## Anda a pé pelas rotas (controlador real), confere o número de sala de cada gatilho, cruzamento de gatilhos,
## bloqueio da escada, ida e volta do Ato II, eventos por sala, fim da visita 4 -> porão.
## Uso: timeout 300 godot --headless -s res://tests/varredura/v34.gd

const NIVEL := "res://world/niveis/castelinho.tscn"

var falhas := 0
var main
var GameState
var Transicao
var p
var nivel


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GameState = root.get_node("/root/GameState")
	Transicao = root.get_node("/root/Transicao")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	await _visita3()
	await _visita4()
	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ================================================================== visita 3 (salas 45-66) e Ato II (55-60)
func _visita3() -> void:
	print("-- visita 3")
	await _carregar(3, {"tem_lanterna": true, "porta_entrada_aberta": true})
	_checar(GameState.sala_atual == 45, "V3: calçada = sala 45 (%d)" % GameState.sala_atual)
	_checar(p.is_on_floor(), "V3: jogador no chão do Spawn (y %.2f)" % p.global_position.y)
	_sobreposicoes("V3")
	_checar(p.lanterna.visible, "V3: lanterna ligada")

	# pré-Ato II: calçada -> porta -> hall -> torre -> corredor -> Salão -> Acervo -> Pescador -> porta do Ato II
	await _varrer([[Vector3(-24.5, 0.1, -4.6), 46, "gramado (2)"], [Vector3(-22.5, 0.1, -9.2), 47, "lateral (3)"],
		[Vector3(-10.7, 0.5, -5.6), 48, "deck (4)"], [Vector3(-8.0, 0.1, -9.0), 49, "arcada (5)"],
		[Vector3(-23.0, 0.1, 1.2), 45, "calçada (1)"]])
	var rota: Array = [
		[Vector3(-6.55, 0, -10.5), 50, "porta de entrada (6)"],
		[Vector3(-6.55, 0, -12.2), 51, "hall (7)"],
		[Vector3(-18.3, 0, -12.9), 52, "Povos/torre térreo (8)"],
		[Vector3(-18.6, 0, -15.8), 53, "Meio Ambiente (9)"],
		[Vector3(-22.8, 0, -21.6), 54, "corredor (10)"],
		[Vector3(-8.5, 0, -21.6), 54, "corredor até o Salão"],
		[Vector3(-8.5, 0, -19.0), 55, "Salão de Arte (11)"],
		[Vector3(-6.4, 0, -17.8), 56, "Acervo (12)"],
		[Vector3(-6.4, 0, -16.0), 57, "arco -> Pescador (13)"],
		[Vector3(-8.7, 0, -15.6), 57, "Sala do Pescador"],
		[Vector3(-6.4, 0, -16.0), 57, "volta ao arco"],
		[Vector3(-6.4, 0, -17.8), 56, "Acervo (volta)"],
		[Vector3(-11.0, 0, -18.0), 55, "diante da porta do Ato II (11)"],
	]
	for leg in rota:
		await _andar(leg[0], 900, "V3 " + leg[2], leg[1])
		if not _ultimo_ok:
			break
	_checar(GameState.flag("evt_v3_sala1"), "V3: evento da sala 1 (Quico e lanterna) disparou")
	_checar(GameState.flag("evt_v3_sala11"), "V3: evento da sala 11 (Salão) disparou")
	_checar(GameState.flag("evt_v3_dica1967"), "V3: dica do disco 1967 na sala 12 disparou")
	_checar(nivel._bloqueio_escada != null, "V3: escada do pátio interditada antes do Ato II")
	_checar_bloqueio("V3")
	_checar(nivel._porta_ato2 != null, "V3: porta do Ato II existe")
	# contorno: pelo corredor de trás (z -21.6) dá para chegar ao pé da escada sem passar pela porta do Salão?
	await _ir_para(Vector3(-12.6, 0.1, -21.6))
	var contorno: bool = await _andar_ate(Vector3(-13.6, 0.1, -19.55), 400)
	_checar(not contorno, "V3: o pé da escada do pátio não é alcançável pelo corredor de trás (contornável se 'chegou')")
	await _ir_para(Vector3(-11.0, 0.1, -18.0))

	# entrar no Ato II pela porta nova
	var antigo: Node = nivel
	nivel._porta_ato2.interagir(p)
	var trocou: bool = await _esperar_troca(antigo)
	_checar(trocou, "Ato II: a porta leva para a cena do Ato II")
	if not trocou:
		return
	await _ato2()

	# volta ao Castelinho (topo da Torre A)
	await _visita3_depois_ato2()


func _ato2() -> void:
	print("-- Ato II")
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(_script_de(nivel).ends_with("ato2.gd"), "Ato II: cena carregada (%s)" % _script_de(nivel))
	await _frames(20)
	_checar(p.is_on_floor(), "Ato II: jogador no chão do Spawn (y %.2f)" % p.global_position.y)
	_checar(GameState.sala_atual == 55, "Ato II: entrada = sala 55 (%d)" % GameState.sala_atual)
	await _andar(Vector3(0, 0.1, -16.5), 900, "Ato II hall -> dunas", 56)
	_checar(GameState.epoca == GameState.Epoca.E1950, "Ato II: sala 56 põe a época em 1950 (%d)" % GameState.epoca)
	_checar(GameState.flag("visor_travado"), "Ato II: Visor travado nas dunas")
	await _andar(Vector3(0, 0.1, -74.0), 1200, "Ato II dunas -> casa", 57)
	# a figura da casa vai para a porta dos fundos (pontos_caminho): andar até lá pode acabar em morte (mecânica do jogo)
	var figura_casa = nivel.figura
	print("  casa: figura pos %s, matou %s" % [str(figura_casa.global_position), str(figura_casa.matou)])
	await _ir_para(Vector3(-1.8, 0.1, -78.9))
	_checar(GameState.sala_atual == 58, "Ato II: teleporte para a arcada entra na sala 58 (%d)" % GameState.sala_atual)
	await _andar(Vector3(-1.8, 0.1, -118.0), 1500, "Ato II arcada -> fim da arcada", 59)
	await _andar(Vector3(-1.8, 0.1, -120.4), 300, "Ato II diante da porta final", 59)
	_checar(nivel._interagivel_final != null, "Ato II: porta final existe")
	if nivel._interagivel_final:
		nivel._interagivel_final.interagir(p)
	var ok: bool = await _esperar_troca(nivel)
	_checar(ok, "Ato II: a porta final devolve ao Castelinho")


func _visita3_depois_ato2() -> void:
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(_script_de(nivel).ends_with("castelinho.gd"), "volta do Ato II: cena do Castelinho (%s)" % _script_de(nivel))
	_checar(GameState.visita == 3 and nivel.visita == 3, "volta do Ato II: visita 3")
	_checar(GameState.flag("v3_ato2_feito"), "volta do Ato II: flag v3_ato2_feito")
	_checar(GameState.sala_atual == 61 and GameState.checkpoint_sala == 61, "volta do Ato II: sala/checkpoint 61 (%d, %d)" % [GameState.sala_atual, GameState.checkpoint_sala])
	_checar(nivel._bloqueio_escada == null, "volta do Ato II: escada do pátio liberada")
	_checar(nivel._porta_ato2 == null and nivel.find_child("PortaPara1950", true, false) == null, "volta do Ato II: porta nova removida")
	_checar(GameState.epoca == GameState.Epoca.E2020 and not GameState.flag("visor_travado"), "volta do Ato II: época 2020 e Visor destravado")
	var mk: Node3D = nivel.find_child("Spawn_volta_ato2", true, false)
	_checar(mk != null and p.global_position.distance_to(mk.global_position) < 2.5, "volta do Ato II: nasce no Spawn_volta_ato2 (%s)" % str(p.global_position))
	await _frames(40)
	_checar(p.is_on_floor() and absf(p.global_position.y - 6.9) < 0.5, "volta do Ato II: no topo da Torre A sem cair (y %.2f)" % p.global_position.y)
	# disco 1975 no pedestal do topo (para o Visor mostrar 1975 mais adiante)
	var par75: Array = nivel._discos_chao[GameState.Epoca.E1975]
	par75[1].interagir(p)
	await _frames(5)
	_checar(GameState.discos.has(GameState.Epoca.E1975), "V3: disco 1975 pego no topo da Torre A")

	# descida: escada da torre, terraço, Torre B, pátio, Salão, Sala Medieval, saída (fita)
	var rota: Array = [
		[Vector3(-21.7, 6.8, -14.05), 61, "topo -> escada da torre"],
		[Vector3(-16.8, 3.5, -14.05), 61, "pé da escada da torre"],
		[Vector3(-17.0, 3.5, -12.5), 61, "2º nível"],
		[Vector3(-14.0, 3.5, -13.2), 62, "terraço da arcada (18)"],
		[Vector3(-14.0, 3.5, -22.0), 62, "terraço até o corredor dos fundos"],
		[Vector3(-7.2, 3.5, -22.5), 62, "terraço até a Torre B"],
		[Vector3(-7.2, 3.5, -24.6), 63, "quarto da Torre B (19)"],
		[Vector3(-7.2, 3.5, -22.5), 63, "saída da Torre B"],
		[Vector3(-14.0, 3.5, -16.0), 63, "terraço do pátio"],
		[Vector3(-22.0, 3.5, -18.0), 63, "terraço oeste"],
		[Vector3(-21.3, 3.5, -19.55), 64, "topo da escada do pátio (20)"],
		[Vector3(-13.3, 0.0, -19.55), 64, "pé da escada do pátio (16 já desligado: contador segue em 64)"],
		[Vector3(-11.5, 0.0, -19.55), 55, "Salão (11)"],
		[Vector3(-8.5, 0.0, -21.6), 54, "corredor (10)"],
		[Vector3(-12.6, 0.0, -21.6), 54, "corredor até a Sala Medieval"],
		[Vector3(-12.6, 0.0, -24.4), 65, "porta -> Sala Medieval (21)"],
		[Vector3(-10.2, 0.0, -25.2), 65, "Sala Medieval (corredor leste)"],
		[Vector3(-10.2, 0.0, -28.2), 66, "porta de saída (23, com fita)"],
	]
	for leg in rota:
		await _andar(leg[0], 900, "V3 pós-Ato " + leg[2], leg[1])
		if not _ultimo_ok:
			break
		if leg[2].begins_with("Sala Medieval (corredor leste)"):
			await _fundo_medieval(66)
	_checar(GameState.flag("evt_v3_sala19"), "V3: evento da sala 19 (quarto da Torre B) disparou")
	_checar(nivel._recortes["quico"].visible, "V3: o Quico-recorte surge perto do quarto da Torre B (sala 19)")
	_checar(GameState.flag("evt_v3_sala23"), "V3: evento da saída (23) disparou")
	_checar(GameState.flag("evt_v3_sala17") or GameState.flag("v3_ato2_feito"), "V3: sala 17 não quebra o Ato II")

	# Visor: segurar Q com o disco 1975 tira a fita e deixa atravessar o corredor de 1975
	print("  visor: discos %s, disco_atual %d, travado %s, bloqueado %s, atencao %.2f, pos %s" % [str(GameState.discos), GameState.disco_atual, str(GameState.flag("visor_travado")), "-", GameState.atencao, str(p.global_position)])
	Input.action_press("visor")
	await _frames(60)
	_checar(GameState.epoca == GameState.Epoca.E1975, "V3: segurando Q na saída a época vira 1975 (%d)" % GameState.epoca)
	await _andar(Vector3(-10.2, 0.1, -31.0), 600, "V3 corredor de 1975 (25)", 66)
	Input.action_release("visor")
	await _frames(30)
	_checar(GameState.flag("visor_travado") and GameState.epoca == GameState.Epoca.E1975, "V3: no corredor de 1975 o Visor trava em 1975")
	await _andar(Vector3(-10.2, 0.1, -79.5), 1200, "V3 corredor de 1975 até a porta final", 66)
	_checar(nivel._porta_saida_1975 != null, "V3: porta final do corredor de 1975 existe")
	if nivel._porta_saida_1975:
		nivel._porta_saida_1975.interagir(p)
	var ok: bool = await _esperar_troca(nivel)
	_checar(ok, "V3: a porta final do corredor de 1975 leva à visita 4")


# ================================================================== visita 4 (salas 67-80) e porão
func _visita4() -> void:
	print("-- visita 4")
	nivel = main.mundo.get_child(0)
	p = main.player
	_checar(_script_de(nivel).ends_with("castelinho.gd") and GameState.visita == 4 and nivel.visita == 4, "V4: visita 4 carregada (visita %d)" % GameState.visita)
	_checar(GameState.sala_atual == 67, "V4: calçada = sala 67 (%d)" % GameState.sala_atual)
	_checar(nivel.chuva != null and nivel.chuva.emitting, "V4: chuva caindo")
	_checar(nivel._bloqueio_escada != null, "V4: escada de cima interditada")
	_checar(nivel._porta_porao != null, "V4: porta zebrada do hall existe")
	_sobreposicoes("V4")
	_checar_bloqueio("V4")

	await _varrer([[Vector3(-24.5, 0.1, -4.6), 68, "gramado (2)"], [Vector3(-22.5, 0.1, -9.2), 68, "lateral (3)"],
		[Vector3(-10.7, 0.5, -5.6), 69, "deck (4)"], [Vector3(-8.0, 0.1, -9.0), 70, "arcada (5)"],
		[Vector3(-23.0, 0.1, 1.2), 67, "calçada (1)"]])
	var rota: Array = [
		[Vector3(-6.55, 0, -10.5), 70, "porta de entrada (5/6)"],
		[Vector3(-6.55, 0, -12.2), 71, "hall (7)"],
		[Vector3(-14.8, 0, -12.6), 71, "hall até o fim (porta zebrada ainda não conta)"],
		[Vector3(-18.3, 0, -12.9), 72, "Povos (8)"],
		[Vector3(-18.6, 0, -15.8), 73, "Meio Ambiente (9)"],
		[Vector3(-22.8, 0, -21.6), 74, "corredor (10)"],
		[Vector3(-8.5, 0, -21.6), 74, "corredor até o Salão"],
		[Vector3(-8.5, 0, -19.0), 75, "Salão de Arte (11)"],
		[Vector3(-6.4, 0, -17.8), 76, "Acervo (12)"],
		[Vector3(-6.4, 0, -16.0), 77, "arco (dentro da zona do Pescador)"],
		[Vector3(-8.7, 0, -15.6), 77, "Sala do Pescador (13)"],
		[Vector3(-6.4, 0, -16.0), 77, "volta ao arco"],
		[Vector3(-6.4, 0, -17.8), 76, "Acervo (volta)"],
		[Vector3(-8.5, 0, -19.0), 75, "volta ao Salão"],
		[Vector3(-8.5, 0, -21.6), 74, "corredor"],
		[Vector3(-12.6, 0, -21.6), 74, "corredor até a Sala Medieval"],
		[Vector3(-12.6, 0, -24.4), 78, "porta -> Sala Medieval (21)"],
		[Vector3(-10.2, 0, -25.2), 78, "Sala Medieval (corredor leste)"],
		[Vector3(-10.2, 0, -28.2), 79, "porta de saída (23)"],
		[Vector3(-10.2, 0, -25.2), 78, "Sala Medieval (leste, volta; o Museu_2020 barra a reta)"],
		[Vector3(-12.6, 0, -24.4), 78, "volta à porta da Sala Medieval"],
		[Vector3(-12.6, 0, -21.6), 74, "volta ao corredor"],
		[Vector3(-22.8, 0, -21.6), 74, "corredor até o fundo"],
		[Vector3(-22.8, 0, -19.4), 74, "pátio fora da zona 9 (sala não muda)"],
		[Vector3(-18.6, 0, -15.8), 73, "Meio Ambiente (volta)"],
		[Vector3(-18.3, 0, -12.9), 72, "Povos (volta)"],
		[Vector3(-14.0, 0, -12.9), 80, "porta zebrada do hall (80)"],
	]
	var i := 0
	for leg in rota:
		i += 1
		await _andar(leg[0], 900, "V4 " + leg[2], leg[1])
		if i == 3:
			_checar(GameState.sala_atual == 71, "V4: a porta zebrada ainda não conta antes da Sala Medieval (%d)" % GameState.sala_atual)
		if i == 4:
			var psolto: Node = nivel.find_child("PainelSoltoInterativo", true, false)
			_checar(psolto != null, "V4: painel solto (Povos) existe")
			if psolto:
				psolto.interagir(p)
				await _frames(5)
			_checar(GameState.discos.has(GameState.Epoca.E2019), "V4: disco 2019 atrás do painel solto")
		if leg[2].begins_with("Sala Medieval (corredor leste)"):
			await _fundo_medieval(79)
		if not _ultimo_ok:
			break

	print("  flags V4: ", str(GameState.flags.keys().filter(func(k): return str(k).begins_with("evt_v4"))))
	_checar(GameState.flag("evt_v4_sala7") and GameState.flag("evt_v4_sala8"), "V4: eventos das salas 7 e 8 (hall e Povos) dispararam")
	_checar(GameState.flag("evt_v4_sala21"), "V4: evento da Sala Medieval (21) disparou")
	_checar(GameState.flag("evt_v4_sala23"), "V4: evento da saída (23) disparou")
	_checar(GameState.flag("evt_v4_sala80"), "V4: evento da porta zebrada (80) disparou")
	_checar(GameState.sala_maxima >= 78, "V4: sala máxima >= 78 antes da porta (%d)" % GameState.sala_maxima)
	_checar(GameState.corruption >= 0.5 and GameState.corruption <= 0.65, "V4: corrupção entre 0,50 e 0,65 (%.2f)" % GameState.corruption)

	# escada de 2019 só existe em 2019 (conferência visual; a descida pela escada é o mesmo código do porão)
	GameState.trocar_epoca(GameState.Epoca.E2019)
	await _frames(3)
	var esc: Node3D = nivel.find_child("Escada2019", true, false)
	_checar(esc != null and esc.visible, "V4: escada de 2019 visível em 2019")
	GameState.trocar_epoca(GameState.Epoca.E2020)
	await _frames(3)

	# fim da visita 4: a porta zebrada desce ao porão
	_checar(nivel._porta_porao != null, "V4: porta zebrada existe antes de descer")
	nivel._porta_porao.interagir(p)
	var ok: bool = await _esperar_troca(nivel)
	_checar(ok, "V4: a porta zebrada leva ao porão")
	if ok:
		var porao: Node3D = main.mundo.get_child(0)
		_checar(_script_de(porao).ends_with("porao.gd"), "porão: cena carregada (%s)" % _script_de(porao))
		_checar(GameState.visita == 5, "porão: visita 5 começou (%d)" % GameState.visita)
		p = main.player
		await _frames(40)
		_checar(p.is_on_floor(), "porão: jogador no chão do Spawn (y %.2f)" % p.global_position.y)
		print("  porão: sala ", GameState.sala_atual)


# ================================================================== utilitários
var _ultimo_ok := true


func _guia() -> Node:
	return root.get_node("/root/Guia")


func _frames(n: int) -> void:
	for i in n:
		_guia().cancelar()
		await physics_frame


func _script_de(no: Node) -> String:
	var s: Script = no.get_script()
	return s.resource_path if s else ""


func _carregar(v: int, flags: Dictionary) -> void:
	GameState.novo_jogo()
	GameState.visita = v
	GameState.flags["tem_visor"] = true
	for f in flags:
		GameState.flags[f] = flags[f]
	GameState.jogando = true
	main.hud.visible = true
	await main.carregar_mundo(NIVEL, "Spawn")
	await _frames(25)
	p = main.player
	nivel = main.mundo.get_child(0)


## Espera a troca de cena (Transicao.ir_para) terminar. Devolve true se o nível mudou.
func _esperar_troca(antigo: Node, max_frames := 2500) -> bool:
	Engine.time_scale = 4.0
	var n := 0
	while n < max_frames:
		n += 1
		_guia().cancelar()
		await physics_frame
		if main.mundo.get_child_count() > 0 and main.mundo.get_child(0) != antigo and not main._carregando and not Transicao.ocupado:
			break
	Engine.time_scale = 1.0
	await _frames(25)
	return main.mundo.get_child_count() > 0 and main.mundo.get_child(0) != antigo


## Anda em linha reta até o alvo, a pé (controlador real). Confere chegada, altura e número da sala.
func _andar(alvo: Vector3, max_frames: int, rotulo: String, sala_esp := -1) -> void:
	Engine.time_scale = 4.0
	var chegou: bool = await _andar_ate(alvo, max_frames)
	Engine.time_scale = 1.0
	var d := Vector2(p.global_position.x - alvo.x, p.global_position.z - alvo.z).length()
	var dy := absf(p.global_position.y - alvo.y)
	_ultimo_ok = chegou and d < 0.8 and dy < 0.6 and p.global_position.y > -3.0
	_checar(_ultimo_ok, "%s: chegou (dist %.2f, y %.2f de %.2f)" % [rotulo, d, p.global_position.y, alvo.y])
	if not _ultimo_ok:
		print("    diag: pos %s, alvo %s, pode_mover %s, guia ocupado %s" % [str(p.global_position), str(alvo), str(p.pode_mover), str(_guia().ocupado())])
		print("    diag: colisor à frente: %s" % _colisor_na_frente(alvo))
	if sala_esp >= 0:
		_checar(GameState.sala_atual == sala_esp, "%s: sala %d (esperado %d)" % [rotulo, GameState.sala_atual, sala_esp])


func _andar_ate(alvo: Vector3, max_frames: int) -> bool:
	Input.action_press("frente")
	var f := 0
	var chegou := false
	var ultimo: Vector3 = p.global_position
	while f < max_frames:
		_guia().cancelar()
		var d: Vector3 = alvo - p.global_position
		d.y = 0
		if d.length() < 0.45:
			chegou = true
			break
		if p.global_position.y < -3.0:
			break
		p.rotation.y = atan2(-d.x, -d.z)
		await physics_frame
		f += 1
		if f % 90 == 0:
			if p.global_position.distance_to(ultimo) < 0.15:
				break
			ultimo = p.global_position
	Input.action_release("frente")
	await physics_frame
	return chegou


## Teleporta para o centro de cada gatilho e confere o número da sala (pega os gatilhos que a rota a pé não passa).
func _varrer(lista: Array) -> void:
	for par in lista:
		await _ir_para(par[0])
		_checar(GameState.sala_atual == par[1], "gatilho %s: sala %d (esperado %d)" % [par[2], GameState.sala_atual, par[1]])


func _ir_para(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _frames(24)


## Altura do primeiro ponto sólido abaixo de `de`.
func _raio(de: Vector3) -> float:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(de, de + Vector3(0, -30, 0), 1)
	var r: Dictionary = espaco.intersect_ray(q)
	return r["position"].y if r else -99.0


func _raio_h(de: Vector3, ate: Vector3) -> bool:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(de, ate, 1)
	return not espaco.intersect_ray(q).is_empty()


## A escada do pátio (a da Torre A) precisa estar fechada por inteiro: um raio horizontal atravessando a passagem
## entre o Salão e o pé da escada tem de bater em algo em toda a largura (senão dá para contornar a fita).
func _checar_bloqueio(rotulo: String) -> void:
	var furos: Array = []
	for z in [-18.3, -18.6, -18.9, -19.55, -20.2]:
		for y in [0.5, 1.2]:
			if not _raio_h(Vector3(-13.6, y, z), Vector3(-11.2, y, z)):
				furos.append("z%.2f/y%.1f" % [z, y])
	_checar(furos.is_empty(), "%s: a passagem da escada do pátio não tem furo (furos: %s)" % [rotulo, str(furos)])


## Fundo da Sala Medieval (gatilho 22, x -15,4). Em 2020 o 'Museu_2020' (vitrine/coluna) pode barrar a passagem:
## se barrar, confere a pé na época 2019 (o museu some) e volta para 2020.
func _fundo_medieval(sala_esp: int) -> void:
	var alvo := Vector3(-15.4, 0.0, -28.0)
	var ok: bool = await _andar_ate(alvo, 600)
	if ok:
		_checar(GameState.sala_atual == sala_esp, "fundo da Sala Medieval (22) a pé em 2020: sala %d (esperado %d)" % [GameState.sala_atual, sala_esp])
		return
	print("  obs: fundo da Sala Medieval (22) barrado a pé em 2020 (pos %s, colisor %s)" % [str(p.global_position), _colisor_na_frente(alvo)])
	GameState.trocar_epoca(GameState.Epoca.E2019)
	await _frames(3)
	var ok2: bool = await _andar_ate(alvo, 600)
	_checar(ok2 and GameState.sala_atual == sala_esp, "fundo da Sala Medieval (22) alcançável a pé em 2019 (sala %d, pos %s)" % [GameState.sala_atual, str(p.global_position)])
	GameState.trocar_epoca(GameState.Epoca.E2020)
	await _frames(3)


func _colisor_na_frente(alvo: Vector3) -> String:
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var de: Vector3 = p.global_position + Vector3(0, 0.5, 0)
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(de, alvo + Vector3(0, 0.5, 0), 1)
	var r: Dictionary = espaco.intersect_ray(q)
	if r.is_empty():
		return "nada (livre)"
	var c: Object = r["collider"]
	return "%s em %s (%s)" % [str(c.name), str(r["position"]), str(c.get_path())]


func _cruza(a, b) -> bool:
	var ca: Vector3 = a.position + Vector3(0, a.tamanho.y * 0.5, 0)
	var cb: Vector3 = b.position + Vector3(0, b.tamanho.y * 0.5, 0)
	var ea: Vector3 = a.tamanho * 0.5
	var eb: Vector3 = b.tamanho * 0.5
	var d: Vector3 = (ca - cb).abs()
	return d.x < ea.x + eb.x and d.y < ea.y + eb.y and d.z < ea.z + eb.z


## Gatilhos cujas caixas se cruzam: dentro da zona comum, a sala que vale depende da ordem de entrada (informativo).
func _sobreposicoes(rotulo: String) -> void:
	var ids: Array = nivel._triggers.keys()
	var pares: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a = nivel._triggers[ids[i]]
			var b = nivel._triggers[ids[j]]
			if _cruza(a, b):
				pares.append("%d/%d" % [ids[i], ids[j]])
	print("  %s: gatilhos que se cruzam (zona comum, ordem de entrada decide): %s" % [rotulo, str(pares)])


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
