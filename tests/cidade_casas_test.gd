extends SceneTree
## Teste automático (headless) do miolo da Rua das casas de veraneio (Módulo 14, lugar "casas"): a tarefa passo a passo (cartaz,
## número, bilhete, chave, portão, casa), as duas pistas (contam uma vez), SEM disco só a pista 1 e o aviso para voltar com o
## Visor, COM disco as duas (a mala só existe em 1967), a voz da mãe, a dica quando demora, concluir (grava a flag e volta ao
## Castelinho) e sair livre (não prende). O contrato geral da base (Spawn, borda, HUD...) é do `cidade_test.gd`.
## Uso: godot --headless -s res://tests/cidade_casas_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var Obj: GDScript
var G: Node


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


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	G = root.get_node("/root/Guia")
	Obj = load("res://world/objetivo.gd")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	await _sem_disco()
	await _com_disco()
	main.queue_free()
	await process_frame
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _entrar(com_disco: bool, flags: Array = []) -> Node:
	GS.novo_jogo()
	for f in flags:
		GS.set_flag(f, true)
	if "pista_casas_caderno" in flags:
		GS.somar("pistas_tito")
	GS.jogando = true
	main.hud.visible = true
	GS.visita = 2
	GS.entrar_sala(23)
	GS.set_flag("tem_visor", true)
	GS.discos.clear()
	if com_disco:
		GS.ganhar_disco(GS.Epoca.E1967)
	await main.carregar_mundo(GS.CIDADE["casas"]["cena"], "Spawn")
	await _frames(8)
	G.cancelar()
	return main.mundo.get_child(0)


func _usar(nivel: Node, nome: String) -> void:
	var it: Node = nivel.find_child(nome, true, false)
	_checar(it != null and it.has_method("interagir"), "existe o interagível %s" % nome)
	if it != null:
		it.interagir(main.player)
	G.cancelar()
	await _frames(2)


func _passo(nivel: Node) -> int:
	return int(nivel.passo_atual())


# ============================================================================ sem o disco de 1967
func _sem_disco() -> void:
	print("-- Rua das casas SEM o disco de 1967")
	var nivel: Node = await _entrar(false)
	var Passo: Dictionary = {"CARTAZ": 0, "NUMERO": 1, "CHAVE": 2, "PORTAO": 3, "CASA": 4, "MALA": 5, "FIM": 6}
	_checar(nivel.id == "casas", "carregou a cena casas")
	# orçamento
	var luzes := 0
	var malhas := 0
	var multis := 0
	for n in nivel.find_children("*", "Node", true, false):
		if n is Light3D:
			luzes += 1
		elif n is MultiMeshInstance3D:
			multis += 1
		elif n is MeshInstance3D and (n as MeshInstance3D).visible:
			malhas += 1
	_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
	_checar(malhas <= 70 and multis <= 5, "poucas malhas (%d) e MultiMesh (%d)" % [malhas, multis])
	# 8 casas, com os números fora de ordem
	var nums: Array = []
	for c in nivel.get_children():
		if str(c.name).begins_with("Casa_"):
			nums.append(str(c.name).substr(5))
	_checar(nums.size() == 8 and "7" in nums and "36" in nums and "18" in nums, "8 casas de veraneio (%s)" % str(nums))
	var ordenado: Array = nums.duplicate()
	ordenado.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	_checar(nums != ordenado, "os números estão fora de ordem")
	_checar(nivel.find_child("LuzJanela36", true, false) != null, "a casa 36 tem a luz acesa")
	_checar(nivel._brilhos.size() == 4 and nivel.find_child("BrilhoCartaz", true, false).visible, "pistas e itens têm brilho dourado que chama o olho (cartaz, chave, caderno, mala)")
	# passo 0: o cartaz
	_checar(_passo(nivel) == Passo["CARTAZ"] and Obj.atual().contains("cartaz"), "passo 1: o objetivo manda achar o cartaz (%s)" % Obj.atual())
	_checar(nivel.find_child("Cartaz", true, false) != null and nivel.find_child("IntCartaz", true, false) != null, "há o cartaz num poste")
	var p1: String = Obj.atual()
	# casa errada (luz acesa): nada muda
	await _usar(nivel, "IntPortao_36")
	await _usar(nivel, "IntPortao_9")
	_checar(_passo(nivel) == Passo["CARTAZ"] and not GS.flag("casas_cartaz"), "olhar casas erradas não adianta nem estraga")
	await _usar(nivel, "IntCartaz")
	nivel._process(0.0)
	_checar(not nivel.find_child("BrilhoCartaz", true, false).visible, "achado o cartaz, o brilho apaga")
	_checar(GS.flag("casas_cartaz") and _passo(nivel) == Passo["NUMERO"], "ler o cartaz dá o número (passo 2)")
	_checar(Obj.atual() != p1 and Obj.atual().contains("7") and Obj.atual().contains("balde"), "o objetivo muda: casa 7, balde vermelho (%s)" % Obj.atual())
	# o balde vermelho existe só no quintal do 7
	_checar(nivel.find_child("IntBalde", true, false) != null, "o balde vermelho do quintal do 7 existe")
	# vaso da própria 7 é a pegadinha: nada
	await _usar(nivel, "IntVaso_7")
	_checar(not GS.flag("casas_chave"), "o vaso da 7 é só terra (pegadinha)")
	# portão da 7: trancado, bilhete
	await _usar(nivel, "IntPortao_7")
	_checar(GS.flag("casas_bilhete") and _passo(nivel) == Passo["CHAVE"] and Obj.atual().contains("FRENTE"), "o bilhete manda procurar na casa de FRENTE (%s)" % Obj.atual())
	_checar(not GS.flag("casas_portao"), "sem a chave o portão não abre")
	var col: CollisionShape3D = nivel._portao_col
	_checar(col != null and not col.disabled, "o portão fechado bloqueia")
	# vaso de outra casa: nada; o da 18 (de frente): a chave
	await _usar(nivel, "IntVaso_72")
	_checar(not GS.flag("casas_chave"), "o vaso de outra casa não tem a chave")
	var n18: Node3D = nivel.find_child("Casa_18", true, false)
	var n7: Node3D = nivel.find_child("Casa_7", true, false)
	_checar(n18.global_position.z < 0.0 and n7.global_position.z > 0.0, "a 18 fica do outro lado da rua em relação à 7")
	await _usar(nivel, "IntVaso_18")
	_checar(GS.flag("casas_chave") and _passo(nivel) == Passo["PORTAO"], "o vaso da 18 esconde a chave (passo 4)")
	await _usar(nivel, "IntPortao_9")
	_checar(not GS.flag("casas_portao"), "a chave não abre outra casa")
	await _usar(nivel, "IntPortao_7")
	_checar(GS.flag("casas_portao") and _passo(nivel) == Passo["CASA"], "com a chave o portão abre (passo 5)")
	_checar(nivel._portao_col.disabled, "o portão aberto deixa de bloquear")
	await create_timer(1.8).timeout
	_checar(nivel._porta_col.disabled and absf(nivel._porta_folha.rotation.y) > 1.0, "a porta da casa fica encostada (aberta)")
	# dica quando demora
	nivel.tempo_passo = 61.0
	nivel._process(0.0)
	_checar(Obj.atual().contains("Dica:"), "demorou: o Mapa mostra uma dica (%s)" % Obj.atual().replace("\n", " | "))
	_checar(G.ocupado() and nivel.dicas_faladas == 1, "e a Tainá/o Bentinho falam a dica")
	G.cancelar()
	nivel.tempo_passo = 0.0
	# dentro da casa, a mãe só fala em 1967 (sem disco, aviso para voltar)
	var dentro: Vector3 = nivel._casa7.to_global(Vector3(-2.4, 0.1, -2.0))
	main.player.global_position = dentro
	await _frames(3)
	nivel._process(0.0)
	_checar(nivel.dentro_casa, "o jogador está dentro da casa 7")
	main.player.global_position = nivel._casa7.to_global(Vector3(2.0, 0.1, -2.5))
	await _frames(3)
	nivel._process(0.0)
	_checar(nivel.no_quarto and nivel._legenda_lbl.text.contains("som abafado"), "no quarto sem o disco: o som abafado e a Tainá mandam voltar com o Visor")
	G.cancelar()
	_checar(nivel.chamadas_mae == 0, "sem 1967 a mãe não chama")
	# a pista 1 (2020) e só ela
	var g20: Node3D = nivel._grupo20
	var g67: Node3D = nivel._grupo67
	_checar(g20.is_visible_in_tree() and not g67.is_visible_in_tree(), "hoje: o caderno aparece e o quarto vivo de 1967 não")
	var n0: int = int(GS.contadores.get("pistas_tito", 0))
	await _usar(nivel, "IntCaderno")
	_checar(GS.flag("pista_casas_caderno") and int(GS.contadores.get("pistas_tito", 0)) == n0 + 1, "o caderno é a pista 1 (+1)")
	await _usar(nivel, "IntCaderno")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == n0 + 1, "contar uma vez só")
	_checar(_passo(nivel) == Passo["MALA"] and Obj.atual().contains("Acervo"), "sem disco: o objetivo manda voltar com o disco do Acervo (%s)" % Obj.atual())
	_checar(not GS.flag("pista_casas_mala") and not GS.cidade_feita("casas"), "a mala não vale sem o disco e o lugar não termina")
	# sem disco o Visor não mostra 1967 (Q não faz nada): a época continua 2020
	_checar(GS.epoca == GS.Epoca.E2020, "a época continua 2020")
	nivel._fim_se_completo()
	await _frames(5)
	_checar(not GS.cidade_feita("casas") and main.nivel_atual == GS.CIDADE["casas"]["cena"], "concluir só com as duas pistas")
	# sair é livre
	nivel.find_child("PortaoVolta", true, false).interagir(main.player)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 600)
	_checar(voltou and not GS.cidade_feita("casas"), "dá para sair sem concluir (não prende)")
	await _frames(8)


# ============================================================================ com o disco de 1967
func _com_disco() -> void:
	print("-- Rua das casas COM o disco de 1967 (progresso guardado em flags: portão aberto, caderno achado)")
	var nivel: Node = await _entrar(true, ["casas_cartaz", "casas_bilhete", "casas_chave", "casas_portao", "pista_casas_caderno"])
	# o progresso da visita anterior foi guardado nas flags
	_checar(GS.flag("casas_portao") and GS.flag("pista_casas_caderno") and nivel._portao_col.disabled, "voltou: portão continua aberto e o caderno já contado")
	_checar(nivel.passo_atual() == 5 and Obj.atual().contains("1967"), "o objetivo manda ligar o Visor em 1967 (%s)" % Obj.atual())
	var g20: Node3D = nivel._grupo20
	var g67: Node3D = nivel._grupo67
	_checar(g20.is_visible_in_tree() and not g67.is_visible_in_tree(), "em 2020 a mala não existe")
	# entrar e ligar o Visor (época 1967)
	main.player.global_position = nivel._casa7.to_global(Vector3(2.0, 0.1, -2.5))
	await _frames(4)
	nivel._process(0.0)
	G.cancelar()
	var hora0: int = int(nivel.hora)
	GS.trocar_epoca(GS.Epoca.E1967)
	await _frames(3)
	nivel._process(0.0)
	_checar(g67.is_visible_in_tree() and not g20.is_visible_in_tree(), "Visor em 1967: o quarto vivo aparece e o caderno some")
	_checar(int(nivel.hora) != hora0, "o céu esquenta em 1967")
	_checar(nivel.chamadas_mae == 1, "a mãe chama (só voz): — Titooo!")
	nivel._process(0.0)
	_checar(nivel.chamadas_mae == 1, "e chama uma vez só")
	_checar(nivel._grupo67.find_child("Luz1967", true, false) != null and nivel._grupo67.find_child("Luz1967", true, false).is_visible_in_tree(), "a luz do quarto vivo acende")
	# o Tito nunca aparece: nada com nome de menino/figura na cena
	var tito := false
	for n in nivel.find_children("*", "Node", true, false):
		var nm: String = str(n.name).to_lower()
		if nm.contains("tito") and not nm.contains("t_decabeca"):
			tito = true
		if nm.contains("figura") or nm.contains("menino"):
			tito = true
	_checar(not tito, "o Tito e a Figura não aparecem (só a voz da mãe)")
	# a mala: pista 2, e conclui
	var n0: int = int(GS.contadores.get("pistas_tito", 0))
	await _usar(nivel, "IntMala")
	_checar(GS.flag("pista_casas_mala") and int(GS.contadores.get("pistas_tito", 0)) == n0 + 1, "a mala é a pista 2 (+1)")
	await _usar(nivel, "IntMala")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == n0 + 1, "contar uma vez só")
	_checar(GS.flag("pista_casas_caderno") and GS.flag("pista_casas_mala"), "as duas pistas do lugar estão achadas")
	# a luz da varanda acende e o lugar termina (a fala é cancelada: o fim espera ~1 s)
	for i in 400:
		G.cancelar()
		if GS.cidade_feita("casas") or main.nivel_atual == GS.CENA_CASTELINHO:
			break
		await physics_frame
	_checar(GS.cidade_feita("casas"), "com as duas pistas, concluir() grava cidade_casas_feito")
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 900)
	_checar(voltou, "e volta ao Castelinho")
	await _frames(8)
	var castelo: Node = main.mundo.get_child(0)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chega na calçada")
	_checar(GS.epoca == GS.Epoca.E2020 and GS.visita == 2, "época de hoje e visita intactas")
	_checar(GS.cidade_pistas_achadas() >= 2, "as pistas ficaram guardadas")
	# entrar de novo depois de feito: objetivo "tudo certo" e sai sem prender
	GS.visita = 2
	await main.carregar_mundo(GS.CIDADE["casas"]["cena"], "Spawn")
	await _frames(6)
	var n2: Node = main.mundo.get_child(0)
	_checar(Obj.atual().begins_with("Aqui está tudo certo"), "refeito: o Mapa diz que está tudo certo")
	n2.find_child("PortaoVolta", true, false).interagir(main.player)
	_checar(await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 600), "e dá para sair de novo")
	await _frames(4)
