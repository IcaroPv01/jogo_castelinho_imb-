extends SceneTree
## Captura de conferência com câmeras livres (Marker3D "Cam_*" do nível, com meta "fov" = campo de visão horizontal).
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cam.gd -- \
##       <cena.tscn> <saida_prefixo> <cam1,cam2,...> [epoca 0-3] [corruption 0-1]
## Gera <saida_prefixo>_<cam>.png. A câmera usa o transform do marcador (posição, direção e inclinação).
## Épocas: 0 = 1950, 1 = 1975, 2 = 2019, 3 = 2020. Não é um teste (não roda em tools/testar.sh).


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var cena: String = a[0]
	var saida: String = a[1]
	var cams: Array = Array(a[2].split(","))
	var epoca := int(a[3]) if a.size() > 3 else 3
	var corr := float(a[4]) if a.size() > 4 else 0.0
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false      # sem tela de carregamento nem aquecimento: a captura sai mais rápida
	await process_frame
	main.tela_titulo.queue_free()
	gs.jogando = false
	await main.carregar_mundo(cena, "Spawn")
	main.hud.visible = false
	gs.definir_corruption_manual(corr)
	gs.trocar_epoca(epoca)
	var nivel: Node3D = main.mundo.get_child(0)
	main.player.pode_mover = false
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.05
	cam.far = 400.0
	nivel.add_child(cam)
	for nome in cams:
		var mk := nivel.find_child(nome, true, false) as Node3D
		if mk == null:
			print("camera nao encontrada: ", nome)
			continue
		cam.global_transform = mk.global_transform
		cam.fov = float(mk.get_meta("fov", 70.0))
		cam.current = true
		for i in 12:
			root.get_node("/root/Guia").cancelar()
			await process_frame
		var img := root.get_texture().get_image()
		var arq := "%s_%s.png" % [saida, nome]
		img.save_png(arq)
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("captura: ", arq, "  draw calls: ", dc, "  triangulos: ", prim)
	quit()
