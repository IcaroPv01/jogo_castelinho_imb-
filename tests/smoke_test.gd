extends SceneTree
## Teste automático (headless): carrega o jogo, começa, anda pelo nível e confere o contador de salas.
## Uso: godot --headless -s res://tests/smoke_test.gd -- [caminho_do_nivel]

var falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var GameState = root.get_node("/root/GameState")
	var args := OS.get_cmdline_user_args()
	var nivel: String = args[0] if args.size() > 0 else "res://world/niveis/teste.tscn"
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GameState.novo_jogo()
	GameState.jogando = true
	main.hud.visible = true
	await main.carregar_mundo(nivel, "Spawn")
	for i in 10:
		await physics_frame
	var p = main.player
	_checar(p != null and p.is_inside_tree(), "jogador criado")
	_checar(p.is_on_floor(), "jogador no chão (y=%.2f)" % p.global_position.y)
	# Anda para frente por 6 segundos.
	Input.action_press("frente")
	for i in 360:
		await physics_frame
	Input.action_release("frente")
	print("posição final: ", p.global_position, "  sala: ", GameState.sala_atual)
	_checar(GameState.sala_atual >= 2, "contador de salas avançou (sala %d)" % GameState.sala_atual)
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
