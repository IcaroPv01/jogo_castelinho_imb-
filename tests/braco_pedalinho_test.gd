extends SceneTree
## Teste automático do pedalinho e do final secreto "salvar o Tito" (Módulo 13, headless): montagem, travado sem pistas
## suficientes, luz que acende com 20 pistas, embarcar e pedalar (limites do lago, bater nos cisnes), descer, o olhar no
## Tito de 1967 (só com o Visor na época dele), o puxão quando a Figura atravessa, e a cena final até a dedicatória.
## Uso: godot --headless -s res://tests/braco_pedalinho_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var nivel: Node
var player: Node
var salvar: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.comecar_visita(5)
	GS.set_flag("tem_visor", true)
	for ep in [4, 5]:
		GS.ganhar_disco(ep)
	await _carregar()

	await _teste_montagem_e_trava()
	await _teste_embarcar_pedalar_descer()
	await _teste_olhar_e_puxao()
	await _teste_cena_final()
	await _teste_finais_e_debug()

	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


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


func _carregar() -> void:
	await main.carregar_mundo("res://world/niveis/braco_morto.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	salvar = nivel.salvar
	nivel.voltar_ao_titulo = false
	GS.flags.erase("final_tito_salvo")
	GS.flags.erase("visor_travado")
	GS.flags.erase("visor_calmo")
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(10)


func _teste_montagem_e_trava() -> void:
	print("-- pedalinho: montagem e trava por pistas")
	GS.contadores["pistas_tito"] = 3
	await _frames(5)
	_checar(salvar != null and salvar.barco != null and salvar.interagivel != null, "BracoSalvar montou o pedalinho amarelo e a área de embarque")
	_checar(not salvar.swan67.visible, "o pedalinho de 1967 não existe em 2020")
	_checar(not salvar._luz.visible and not salvar.liberado, "com 3 pistas a luz do lago está apagada")
	salvar.interagivel.interagir(player)
	_checar(not salvar.ativo and nivel._legenda.text.begins_with("(preso"), "com 3 pistas o pedalinho está preso (legenda), sem embarcar")
	await _frames(5)
	_checar(not salvar.ativo, "e continua preso")
	GS.contadores["pistas_tito"] = 20
	await _frames(5)
	_checar(salvar.liberado and salvar._luz.visible, "com 20 pistas a luz se acende no lago")
	_checar(salvar.POS_DOCA.distance_to(salvar.barco.position) < 0.01, "o pedalinho amarelo está no atracadouro")


func _teste_embarcar_pedalar_descer() -> void:
	print("-- pedalinho: embarcar, pedalar e descer")
	player.global_position = Vector3(35.0, 0.05, -6.7)
	player.rotation.y = 0.0
	await _frames(3)
	salvar.interagivel.interagir(player)
	var ok: bool = await _ate(func(): return salvar.ativo and not salvar._ocupado, 300)
	_checar(ok, "com 20 pistas, E embarca")
	_checar(not player.is_physics_processing(), "a física do jogador cede o corpo ao pedalinho")
	_checar(absf(player.global_position.y - (salvar.AGUA_Y + 0.52)) < 0.06, "o jogador fica no convés (y=%.2f)" % player.global_position.y)
	_checar(absf(player.cabeca.position.y - salvar.ALTURA_OLHOS_BARCO) < 0.01, "olhos mais baixos, sentado")
	# pedala para o norte (frente) e depois para o oeste, até perto da luz
	var z0: float = player.global_position.z
	Input.action_press("frente")
	await _frames(120)
	Input.action_release("frente")
	var z1: float = player.global_position.z
	_checar(z1 < z0 - 4.0, "pedalando para a frente o barco anda (z %.1f -> %.1f)" % [z0, z1])
	_checar(z1 > salvar.LIMITE_Z0, "e não passa do fim do lago")
	# vai para o oeste: bate nos cisnes ou passa por cima? precisa sair do lugar sem travar
	player.rotation.y = PI * 0.5
	var x0: float = player.global_position.x
	Input.action_press("frente")
	await _frames(240)
	Input.action_release("frente")
	var x1: float = player.global_position.x
	_checar(x1 < x0 - 8.0, "dá para atravessar o lago para o oeste (x %.1f -> %.1f)" % [x0, x1])
	_checar(player.global_position.y > salvar.AGUA_Y + 0.4, "o barco não afunda (y=%.2f)" % player.global_position.y)
	# bordas: empurra para o sul até a margem e para o oeste até o limite
	player.rotation.y = 0.0
	Input.action_press("tras")
	await _frames(600)
	Input.action_release("tras")
	_checar(player.global_position.z <= salvar.LIMITE_Z1 + 0.01, "não sobe na margem (z=%.2f)" % player.global_position.z)
	# volta ao atracadouro e desce
	player.global_position = Vector3(35.0, player.global_position.y, -11.4)
	await _frames(5)
	_checar(salvar._perto_doca, "perto do atracadouro: pode descer")
	salvar._descer()
	var ok2: bool = await _ate(func(): return not salvar.ativo and not salvar._ocupado, 300)
	_checar(ok2 and player.is_physics_processing(), "descer devolve o corpo ao jogador")
	_checar(absf(player.cabeca.position.y - 1.55) < 0.01, "e a altura dos olhos de pé")
	_checar(player.global_position.z > -8.0, "e o põe na margem (z=%.2f)" % player.global_position.z)


func _teste_olhar_e_puxao() -> void:
	print("-- pedalinho: o olhar no Tito de 1967 e o puxão")
	salvar.olhar = 0.0
	salvar.interagivel.interagir(player)
	await _ate(func(): return salvar.ativo and not salvar._ocupado, 300)
	var q: Vector3 = salvar.POS_Q
	# 12 m a leste, de frente para o Tito
	player.global_position = Vector3(q.x + 12.0, player.global_position.y, q.z)
	player.rotation.y = PI * 0.5
	player.cabeca.rotation.x = 0.0
	await _frames(10)
	_checar(not salvar._olhando_tito(), "em 2020 não há o que olhar")
	GS.trocar_epoca(GS.Epoca.E1967)
	await _frames(2)
	_checar(salvar.swan67.visible and salvar.tito67.is_visible_in_tree(), "em 1967 o pedalinho do Tito aparece")
	_checar(salvar.fig67.is_visible_in_tree(), "e a Figura do outro lado da água")
	var antes: float = salvar.olhar
	await _frames(60)
	_checar(salvar.olhar > antes + 0.05, "olhando para ele o olhar soma (%.2f)" % salvar.olhar)
	player.rotation.y = -PI * 0.5       # de costas para ele
	var parado: float = salvar.olhar
	await _frames(30)
	_checar(is_equal_approx(salvar.olhar, parado), "desviando o olhar nada soma")
	player.rotation.y = PI * 0.5
	# atenção cheia: a Figura atravessa e o barco é puxado de volta (o progresso fica)
	var visor: Node = nivel._visor
	var puxado := [false]
	salvar.puxado.connect(func(): puxado[0] = true)
	var guardado: float = salvar.olhar
	visor.figura_atravessou.emit(5)
	var ok: bool = await _ate(func(): return puxado[0], 600)
	var d: float = Vector2(player.global_position.x - q.x, player.global_position.z - q.z).length()
	_checar(ok and d > salvar.DIST_PUXAO - 2.0, "o puxão leva o barco para longe da luz (%.1f m)" % d)
	_checar(salvar.olhar >= guardado - 0.001, "o progresso do olhar fica")
	GS.trocar_epoca(GS.Epoca.E2020)
	salvar._soltar_corpo()
	salvar._ocupado = false
	await _frames(3)


func _teste_cena_final() -> void:
	print("-- pedalinho: cena final 'tito_salvo'")
	var fim := [""]
	nivel.fim.connect(func(f): fim[0] = f)
	GS.contadores["pistas_tito"] = 20
	var q: Vector3 = salvar.POS_Q
	salvar._colocar_no_barco(Vector3(q.x + 12.0, 0.0, q.z), PI * 0.5)
	GS.trocar_epoca(GS.Epoca.E1967)
	salvar.olhar = 0.995
	var ok: bool = await _ate(func(): return salvar.concluindo, 600)
	_checar(ok and nivel.final == "tito_salvo" and not player.pode_mover, "olhar completo: a cena final começa e o controle trava")
	_checar(GS.flag("visor_calmo") and GS.flag("visor_travado"), "Visor calmo e travado durante a cena")
	var ok2: bool = await _ate(func(): return nivel.dedicatoria != null, 12000)
	_checar(ok2 and fim[0] == "tito_salvo", "sinal fim('tito_salvo') e dedicatória")
	_checar(GS.flag("final_tito_salvo") and not GS.flag("final_encontrado"), "flag final_tito_salvo")
	_checar(salvar.fig67.position.y < -2.0, "a Figura afundou")
	_checar(nivel._titulo_final.text == "TITO VOLTOU PRA CASA", "título do final")
	if nivel.dedicatoria != null:
		nivel.dedicatoria.queue_free()
	load("res://ui/flash.gd").resetar_ui()
	GS.flags.erase("visor_travado")
	GS.flags.erase("visor_calmo")
	GS.trocar_epoca(GS.Epoca.E2020)


func _teste_finais_e_debug() -> void:
	print("-- final secreto: memória dos finais e atalho de debug")
	var Finais = load("res://ui/finais.gd")
	_checar(Finais.TODOS.has("tito_salvo") and Finais.SECRETO == "tito_salvo", "Finais conhece o final secreto")
	var Dbg = load("res://ui/debug.gd")
	_checar(Dbg.FINAIS.has("tito_salvo"), "o painel de debug lista o final secreto")
	# a trava do pedalinho não atrapalha o resto do nível
	await _carregar()
	GS.contadores["pistas_tito"] = 1
	nivel.salvar.player = player
	_checar(not nivel.salvar.ativo and nivel.salvar.olhar == 0.0, "nível novo: pedalinho parado")
