extends SceneTree
## Captura do minigame "Quico Diz" (precisa de renderização: rode com xvfb-run). Não é um teste.
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_quico.gd -- <saida_prefixo>
## Gera <prefixo>_fala.png, <prefixo>_batida.png (o Quico apitando) e <prefixo>_vez.png (a vez do jogador). Com o 2º argumento
## `virada`, vai direto para a virada e gera <prefixo>_virada.png (a resposta de fora de campo).


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0]
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var gui = root.get_node("/root/Guia")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.jogando = false     # (em janela sem foco o jogo pausaria sozinho)
	main.hud.visible = true
	await main.carregar_mundo("res://world/niveis/mini_quico.tscn", "Spawn")
	var n = main.mundo.get_child(0)
	n.destino = "res://world/niveis/teste.tscn"
	Engine.time_scale = 1.0
	if a.size() > 1 and a[1] == "virada":
		n.rodada_inicial = 5
		for i in 6000:
			if gui.ocupado():
				gui.avancar()
			if n.virada_ativa and n._ave.rotation_degrees.y > 30.0:
				for k in 14:
					await process_frame
				root.get_texture().get_image().save_png(saida + "_virada.png")
				break
			await process_frame
		quit()
		return
	# fala inicial (aparece o Quico com a caixa de texto)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(saida + "_fala.png")
	# avança as falas até a primeira batida
	var feito := false
	for i in 4000:
		if gui.ocupado():
			gui.avancar()
		if n._tipos.size() > 0 and n.get_node_or_null("Quico") and n._bico_sup.rotation_degrees.x < -10.0 and not feito:
			for k in 3:
				await process_frame
			root.get_texture().get_image().save_png(saida + "_batida.png")
			feito = true
		if n.ouvindo:
			break
		await process_frame
	n.acionar()
	for k in 6:
		await process_frame
	root.get_texture().get_image().save_png(saida + "_vez.png")
	quit()
