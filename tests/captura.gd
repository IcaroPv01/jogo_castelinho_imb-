extends SceneTree
## Tira capturas de tela de um nível (precisa de renderização: rode com xvfb-run).
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura.gd -- \
##       <cena.tscn> <saida_prefixo> [spawn] [epoca 0-3] [corruption 0-1] [yaw_graus,...]
## Gera <saida_prefixo>_<yaw>.png para cada ângulo. Não é um teste (não roda em tools/testar.sh).


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var cena: String = a[0]
	var saida: String = a[1]
	var spawn: String = a[2] if a.size() > 2 else "Spawn"
	var epoca := int(a[3]) if a.size() > 3 else 3
	var corr := float(a[4]) if a.size() > 4 else 0.0
	var yaws: Array = Array(a[5].split(",")) if a.size() > 5 else ["0"]
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	gs.jogando = false
	main.hud.visible = true
	await main.carregar_mundo(cena, spawn)
	gs.definir_corruption_manual(corr)
	gs.trocar_epoca(epoca)
	for i in 30:
		await process_frame
	var base_yaw: float = main.player.rotation_degrees.y
	for y in yaws:
		main.player.rotation_degrees.y = base_yaw + float(y)
		for i in 8:
			await process_frame
		var img := root.get_texture().get_image()
		var arq := "%s_%s.png" % [saida, str(y).replace("-", "m")]
		img.save_png(arq)
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("captura: ", arq, "  draw calls: ", dc, "  triangulos: ", prim)
	quit()
