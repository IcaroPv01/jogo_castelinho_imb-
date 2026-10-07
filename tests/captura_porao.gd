extends SceneTree
## Capturas do porão (precisa de renderização: xvfb-run). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_porao.gd -- \
##       <prefixo> <semente> <idx,idx,...> [nivel_agua 0-3] [epoca 0-5] [vista: ini|meio|costas]
## Para cada sala (índice 0..18) teleporta o jogador e salva <prefixo>_<idx>.png, com draw calls e luzes.
## Não é um teste (não roda em tools/testar.sh).

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var pref: String = a[0]
	var sem := int(a[1])
	var idxs: Array = Array(a[2].split(","))
	var agua := int(a[3]) if a.size() > 3 else -1
	var epoca := int(a[4]) if a.size() > 4 else 3
	var vista: String = a[5] if a.size() > 5 else "ini"
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.set_flag("porao_semente", sem)
	gs.set_flag("tem_lanterna")          # no jogo o jogador chega ao porão com a lanterna da visita 3
	gs.comecar_visita(5)
	gs.jogando = false
	await main.carregar_mundo("res://world/niveis/porao.tscn", "Spawn")
	var nivel = main.mundo.get_child(0)
	main.hud.visible = true
	for k in idxs:
		var i := int(k)
		nivel.ir_para_sala(i)
		if agua >= 0:
			nivel.nivel_agua = agua
			nivel.prof = nivel.PROF_AGUA[agua]
		gs.definir_corruption_manual(0.5)
		gs.trocar_epoca(epoca)
		var c = nivel.salas[i]
		var p: Vector3
		match vista:
			"meio": p = c.raiz.to_global(Vector3(0, 0.05, -c.L * 0.45))
			"fim": p = c.raiz.to_global(Vector3(0, c.dy + 0.05, -c.L + 2.0))
			_: p = c.raiz.to_global(Vector3(0, 0.05, -1.4))
		main.player.global_position = p
		main.player.rotation.y = PI if vista == "fim" else 0.0
		main.player.cabeca.rotation.x = 0.0
		for f in 14:
			await process_frame
		var img := root.get_texture().get_image()
		var arq := "%s_%d_%s.png" % [pref, i, c.tipo]
		img.save_png(arq)
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("captura: ", arq, "  draw calls: ", dc, "  triangulos: ", prim, "  luzes: ", nivel.total_luzes_visiveis())
	quit()
