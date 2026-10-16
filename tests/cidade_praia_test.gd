extends SceneTree
## Teste automático (headless) da PRAIA DE IMBÉ (Módulo 14, `world/niveis/cidade_praia.gd`): carrega, a trilha de pegadas e o raio de
## interação funcionam andando de verdade (não fica preso), os 4 achados em qualquer ordem, a pista conta uma vez só (e só no 4º),
## o sino e as dicas, o mar/zona molhada não afoga nem mata, a borda segura o jogador antes da água funda, o portão só conclui depois
## da pista (antes só sai, e o progresso fica), concluir grava a flag e volta à calçada, e o orçamento web (luzes e malhas).
## Uso: godot --headless -s res://tests/cidade_praia_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var Obj: GDScript
var mortes := 0
var extras0 := 0

const IDS := ["chinelo", "bola", "pazinha", "balde"]


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _guia() -> Node:
	return root.get_node("/root/Guia")


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Obj = load("res://world/objetivo.gd")
	GS.jogador_morreu.connect(func(_c: String) -> void: mortes += 1)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	extras0 = Obj.extras.size()
	await _carregar()
	var nivel: Node = main.mundo.get_child(0)
	await _cenario(nivel)
	await _trilha_a_pe(nivel)
	await _sino_e_dicas(nivel)
	await _mar_nao_afoga(nivel)
	await _achados_e_pista(nivel)
	await _portao_antes_e_depois()
	await _reentrada()
	_guia().cancelar()
	main.queue_free()
	await process_frame
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


## Carrega a praia como o jogo faz (visita 2, calçada da sala 23).
func _carregar() -> void:
	GS.visita = 2
	GS.entrar_sala(23)
	await main.carregar_mundo(GS.CIDADE["praia"]["cena"], "Spawn")
	await _frames(8)
	var nivel: Node = main.mundo.get_child(0)
	nivel.atraso_final = 0.0


func _nivel() -> Node:
	return main.mundo.get_child(0)


# ============================================================================ cenário
func _cenario(nivel: Node) -> void:
	print("-- carrega e monta o cenário")
	_checar(main.nivel_atual == "res://world/niveis/cidade_praia.tscn" and nivel.id == "praia", "carrega a Praia (id 'praia')")
	_checar(nivel.hora == 3 and nivel.clima == 2, "noite e ressaca")
	_checar(nivel.find_child("MarPerto", true, false) != null and nivel.find_child("MarLonge", true, false) != null, "tem mar (perto e longe)")
	var esp: MeshInstance3D = nivel.find_child("Espraiado", true, false) as MeshInstance3D
	_checar(esp != null and esp.material_override is ShaderMaterial, "tem a água que avança e recua (sombreador)")
	for nome in ["Dunas", "Capim", "Pegadas_E", "Pegadas_D", "Pecas", "RedeDePesca", "Predios", "Janelas", "Lampadas", "Brilhos", "Feixes", "Calcadao"]:
		_checar(nivel.find_child(nome, true, false) != null, "tem '%s'" % nome)
	_checar(nivel.find_child("ColisaoCasco", true, false) != null, "o casco encalhado tem colisão (não se entra no esqueleto)")
	_checar(nivel.find_children("*", "Area3D", true, false).is_empty(), "sem nenhum volume de área (nada que afogue)")
	# orçamento web
	var luzes := 0
	var malhas := 0
	var multi := 0
	for n in nivel.find_children("*", "Node", true, false):
		if n is Light3D:
			luzes += 1
		elif n is MeshInstance3D:
			malhas += 1
		elif n is MultiMeshInstance3D:
			multi += 1
	_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
	_checar(malhas + multi <= 90, "poucas chamadas de desenho (%d malhas + %d MultiMesh)" % [malhas, multi])
	# o texto da placa cita só o que está pesquisado e a prefeitura é a fictícia
	var txt := ""
	for l in nivel.TEXTO_PLACA:
		txt += str(l) + "\n"
	_checar(txt.contains("PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA") and txt.contains("Cemitério dos Navegantes") and txt.contains("1836") and txt.contains("1902"),
		"placa: prefeitura fictícia e só os fatos de historia_imbe.md §7.1")
	_checar(not txt.to_lower().contains("miguel") and not txt.contains("2024"), "placa: nada do Caso Miguel nem da enchente de 2024")
	# objetos e interativos
	var area: Rect2 = nivel.area
	for id in IDS:
		var o: Node3D = nivel.find_child("Obj_" + id, true, false) as Node3D
		var it: Node = nivel.find_child("Achado_" + id, true, false)
		_checar(o != null and it != null and area.has_point(Vector2(o.global_position.x, o.global_position.z)), "'%s': objeto e interativo dentro da AREA" % id)
	_checar(nivel.find_child("PlacaPraia", true, false) != null, "a placa da prefeitura pode ser lida (E)")
	# objetivo / Mapa
	var obj_txt: String = Obj.atual()
	_checar(obj_txt.begins_with("Objetos: 0/4") and obj_txt.contains("sino"), "objetivo no Mapa: '%s'" % obj_txt)
	_checar(not GS.flag("pista_praia_balde") and not GS.cidade_feita("praia"), "começa sem pista e sem lugar feito")
	# a água não chega à borda de colisão: a borda do norte fica antes do mar fundo
	var borda: Node3D = nivel.find_child("Borda_N", true, false) as Node3D
	_checar(borda != null and borda.global_position.z >= nivel.Z_COSTA - 1.5, "a borda norte fica junto da costa, antes da água funda")


# ============================================================================ andar de verdade
func _para(p: Variant, alvo: Vector3) -> void:
	p.rotation.y = atan2(-(alvo.x - p.global_position.x), -(alvo.z - p.global_position.z))
	p.cabeca.rotation.x = 0.0


## Anda até `alvo` (plano XZ) segurando "frente". Devolve se chegou a `tol` m dentro do limite de quadros.
func _anda_ate(alvo: Vector3, tol := 0.7, max_frames := 900) -> bool:
	var p: Variant = main.player
	Input.action_press("frente")
	var chegou := false
	for i in max_frames:
		var d := Vector2(alvo.x - p.global_position.x, alvo.z - p.global_position.z).length()
		if d <= tol:
			chegou = true
			break
		_para(p, alvo)
		await physics_frame
	Input.action_release("frente")
	await physics_frame
	return chegou


func _trilha_a_pe(nivel: Node) -> void:
	print("-- anda a trilha de ponta a ponta, sem ficar preso, e o raio de interação acha cada objeto")
	var p: Variant = main.player
	var tomou_queda: int = nivel.quedas
	# a 1,2 m de cada objeto, olhando para ele: o jogador tem que ver o interativo
	for id in IDS:
		var def: Dictionary = {}
		for d: Dictionary in nivel.OBJETOS:
			if d["id"] == id:
				def = d
		var pos: Vector3 = def["pos"]
		# sobe a trilha pelos pontos até ficar a ~1,2 m do objeto (a trilha passa por cima dele)
		var seguir: Array = []
		for w: Vector3 in nivel.TRILHA:
			seguir.append(w)
		var ate := seguir.find(pos)
		_checar(ate >= 0, "'%s' está na trilha" % id)
		var j: int = _proximo_ponto
		while j <= ate:
			var w: Vector3 = seguir[j]
			var alvo: Vector3 = w if j < ate else w + (seguir[j - 1] - w).normalized() * 1.2
			var ok: bool = await _anda_ate(alvo)
			if not ok:
				_checar(false, "chegou ao ponto %d da trilha (%.1f, %.1f); parou em (%.1f, %.1f)" % [j, w.x, w.z, p.global_position.x, p.global_position.z])
				return
			j += 1
		_proximo_ponto = ate + 1
		# olha para o objeto de 1,2 m
		_para(p, pos)
		var dist := Vector2(pos.x - p.global_position.x, pos.z - p.global_position.z).length()
		p.cabeca.rotation.x = -atan2(1.55 - 0.1, maxf(dist, 0.3))
		await _frames(3)
		var alvo_it: Node = p._alvo
		_checar(alvo_it != null and alvo_it.name == "Achado_" + id, "'%s': o raio do jogador aponta o interativo (E)" % id)
	_checar(nivel.quedas == tomou_queda, "a rede de segurança não precisou agir na caminhada (quedas = %d)" % nivel.quedas)
	_checar(p.global_position.y > -0.5 and p.is_on_floor(), "o jogador terminou de pé na areia")
	# a trilha chega à beira da água e acaba no mar
	await _anda_ate(Vector3(11.5, 0.0, -23.0), 0.8)
	_checar(p.global_position.z < -20.0 and p.global_position.z > nivel.area.position.y - 1.0, "foi até a zona molhada, perto do fim da areia")
	Input.action_release("frente")
	p.cabeca.rotation.x = 0.0


var _proximo_ponto := 0


# ============================================================================ sino e dicas
func _sino_e_dicas(nivel: Node) -> void:
	print("-- sino e dicas")
	var p: Variant = main.player
	p.global_position = Vector3(0.0, 0.1, 15.0)
	p.velocity = Vector3.ZERO
	await _frames(3)
	var fonte: Vector3 = nivel.fonte_do_sino()
	# o próximo objeto (o mais perto) é o chinelo ou a pazinha...; o sino soa a uns 12 m dele, do lado de lá
	var mais_perto := INF
	var alvo := Vector3.ZERO
	for d: Dictionary in nivel.OBJETOS:
		var dd: float = (d["pos"] as Vector3).distance_to(p.global_position)
		if dd < mais_perto:
			mais_perto = dd
			alvo = d["pos"]
	var f2 := Vector2(fonte.x - alvo.x, fonte.z - alvo.z).length()
	_checar(absf(f2 - 12.0) < 0.5, "o sino soa a ~12 m do objeto mais perto (%.1f)" % f2)
	var de_p := Vector2(alvo.x - p.global_position.x, alvo.z - p.global_position.z)
	var da_f := Vector2(fonte.x - p.global_position.x, fonte.z - p.global_position.z)
	_checar(de_p.normalized().dot(da_f.normalized()) > 0.95, "e do lado do objeto (dá a direção)")
	_checar(nivel.find_child("Sino", true, false) is AudioStreamPlayer3D, "tem o player 3D do sino")
	# dicas: a 1ª é geral, as seguintes apontam o próximo achado; falam pela Guia
	_guia().cancelar()
	await _frames(15)
	var antes: int = nivel.dicas_dadas
	nivel.dar_dica()
	_checar(nivel.dicas_dadas == antes + 1 and _guia().ocupado(), "dar_dica() fala pela Guia (Tainá/Bentinho)")
	_guia().cancelar()
	await _frames(15)
	nivel.dar_dica()
	_checar(_guia().ocupado(), "a dica seguinte também fala")
	_guia().cancelar()
	await _frames(15)
	# a espera de verdade: depois do tempo sem achar nada vem sozinha
	nivel._ocioso = 0.0
	nivel._proxima_dica = 0.05
	var n0: int = nivel.dicas_dadas
	var veio: bool = await _ate(func() -> bool: return nivel.dicas_dadas > n0, 300)
	_checar(veio, "demorando, a dica vem sozinha")
	_guia().cancelar()
	await _frames(15)


# ============================================================================ o mar não afoga
func _mar_nao_afoga(nivel: Node) -> void:
	print("-- mar e zona molhada: sem afogamento, sem morte, sem teleporte")
	var p: Variant = main.player
	var q0: int = nivel.quedas
	var m0 := mortes
	var mortes_cont0: int = int(GS.contadores.get("mortes", 0))
	# na ponta mais molhada da AREA, parado, durante mais de um ciclo da maré (10 s = 600 quadros)
	p.global_position = Vector3(4.0, 0.1, nivel.area.position.y + 0.6)
	p.velocity = Vector3.ZERO
	await _frames(660)
	_checar(mortes == m0 and int(GS.contadores.get("mortes", 0)) == mortes_cont0, "um ciclo inteiro da maré na beira d'água: nenhuma morte")
	_checar(nivel.quedas == q0, "e sem rede de segurança (não foi teletransportado)")
	_checar(p.is_on_floor() and p.global_position.y > -0.2, "continua de pé na areia, sem afundar")
	# andando contra o mar: a borda segura antes da água funda
	Input.action_press("frente")
	p.rotation.y = 0.0
	await _frames(120)
	Input.action_release("frente")
	_checar(p.global_position.z >= nivel.area.position.y - 1.0, "andar para o mar para na borda (z = %.1f)" % p.global_position.z)
	_checar(mortes == m0 and nivel.quedas == q0, "continua sem morte e sem queda")
	# a rede de segurança ainda cobre quem passa da borda
	p.global_position = Vector3(0.0, 0.5, -40.0)
	var voltou: bool = await _ate(func() -> bool: return p.global_position.distance_to(nivel.ponto_spawn("Spawn").global_position) < 1.5, 120)
	_checar(voltou and nivel.quedas == q0 + 1, "se passar da borda, volta ao Spawn")
	await _frames(5)


# ============================================================================ achados e pista
func _achados_e_pista(nivel: Node) -> void:
	print("-- 4 achados em qualquer ordem, pista uma vez só")
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	var ordem := ["balde", "pazinha", "chinelo", "bola"]      # ao contrário do da trilha
	var p: Variant = main.player
	for k in ordem.size():
		var id: String = ordem[k]
		var it: Node = nivel.find_child("Achado_" + id, true, false)
		_checar(it != null and it.has_method("interagir"), "'%s': interativo existe antes de achar" % id)
		if it == null:
			continue
		it.interagir(p)
		await _frames(3)
		_checar(nivel._achados == k + 1 and GS.flag("praia_achou_" + id), "'%s' achado: %d/4 (flag salva)" % [id, k + 1])
		if is_instance_valid(it):
			it.interagir(p)
		_checar(nivel._achados == k + 1, "achar de novo não conta")
		await _frames(2)
		_checar(nivel.find_child("Achado_" + id, true, false) == null, "'%s': o interativo sai depois de achado" % id)
		var obj_txt: String = Obj.atual()
		if k < 3:
			_checar(obj_txt.begins_with("Objetos: %d/4" % (k + 1)) and obj_txt.contains("Faltam"), "objetivo: '%s'" % obj_txt)
			_checar(not GS.flag("pista_praia_balde"), "a pista ainda não saiu (%d/4)" % (k + 1))
			_checar(int(GS.contadores.get("pistas_tito", 0)) == antes, "pistas_tito não mudou antes do 4º")
	await _frames(5)
	_checar(GS.flag("pista_praia_balde") and int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "4/4: a pista 'praia_balde' conta (+1)")
	_checar(nivel._pronto, "a tarefa está pronta (o portão vai concluir)")
	_checar(Obj.atual().begins_with("Objetos: 4/4") and Obj.atual().contains("portão"), "objetivo: '%s'" % Obj.atual())
	_checar(_guia().ocupado(), "a Tainá/o Bentinho falam da pista")
	var de_novo: bool = await nivel.pista("praia_balde", [])
	nivel._achar(0)
	nivel._achar(3)
	await _frames(3)
	_checar(not de_novo and int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "a pista não conta duas vezes")
	_guia().cancelar()
	await _frames(15)
	# depois da pista o sino guia de volta ao portão
	var fonte: Vector3 = nivel.fonte_do_sino()
	var portao: Node3D = nivel.find_child("Portao", true, false) as Node3D
	_checar(portao != null and Vector2(fonte.x - portao.global_position.x, fonte.z - portao.global_position.z).length() < 8.0, "pronto: o sino soa do lado do portão")
	_checar(not GS.cidade_feita("praia"), "ainda não concluiu (falta voltar ao portão)")


# ============================================================================ portão: sair x concluir
func _portao_antes_e_depois() -> void:
	print("-- portão: depois da pista conclui e volta à calçada")
	var nivel: Node = _nivel()
	var volta: Node = nivel.find_child("PortaoVolta", true, false)
	_checar(volta != null, "o portão existe")
	volta.interagir(main.player)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not root.get_node("/root/Transicao").ocupado, 900)
	_checar(voltou, "voltou ao Castelinho")
	await _frames(10)
	_checar(GS.cidade_feita("praia"), "a flag cidade_praia_feito foi gravada")
	var castelo: Node = main.mundo.get_child(0)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chegou na calçada (Spawn_volta_cidade)")
	_checar(GS.visita == 2 and GS.sala_atual == 23, "visita e sala intactas")
	_checar(Obj.extras.size() == extras0 and int(GS.corruption_manual) == -1, "limpou o objetivo e a corrupção manual")
	_checar(mortes == 0, "nenhuma morte em toda a praia")


## Reentrar depois de concluir: tudo já achado, sem interativos de achado; sair antes da pista não conclui e guarda o progresso.
func _reentrada() -> void:
	print("-- reentrada e progresso salvo")
	await _carregar()
	var nivel: Node = _nivel()
	_checar(nivel._achados == 4 and nivel.find_children("Achado_*", "", true, false).is_empty(), "concluída: já aparece tudo achado, sem interativos de achado")
	# jogo novo: sair no meio guarda o progresso e NÃO conclui
	GS.novo_jogo()
	GS.jogando = true
	await _carregar()
	nivel = _nivel()
	_checar(nivel._achados == 0 and nivel.find_children("Achado_*", "", true, false).size() == 4, "jogo novo: nada achado, 4 interativos")
	nivel.find_child("Achado_chinelo", true, false).interagir(main.player)
	nivel.find_child("Achado_bola", true, false).interagir(main.player)
	await _frames(3)
	nivel.find_child("PortaoVolta", true, false).interagir(main.player)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not root.get_node("/root/Transicao").ocupado, 900)
	_checar(voltou and not GS.cidade_feita("praia") and not GS.flag("pista_praia_balde"), "sair com 2/4 volta ao Castelinho sem concluir e sem pista")
	await _carregar()
	nivel = _nivel()
	_checar(nivel._achados == 2 and GS.flag("praia_achou_chinelo") and GS.flag("praia_achou_bola"), "ao voltar, os 2 achados continuam achados")
	_checar(nivel.find_children("Achado_*", "", true, false).size() == 2, "e só faltam 2 interativos")
	_checar(Obj.atual().begins_with("Objetos: 2/4"), "objetivo retomado: '%s'" % Obj.atual())
	# o portão ainda não conclui
	nivel.find_child("PortaoVolta", true, false).interagir(main.player)
	voltou = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not root.get_node("/root/Transicao").ocupado, 900)
	_checar(voltou and not GS.cidade_feita("praia"), "com 2/4 o portão continua só saindo")
