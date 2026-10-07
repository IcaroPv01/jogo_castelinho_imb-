extends SceneTree
## Captura de conferência com câmeras livres (Marker3D "Cam_*" do nível, com meta "fov" = campo de visão horizontal).
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cam.gd -- \
##       <cena.tscn> <saida_prefixo> <cam1,cam2,...> [epoca 0-4] [corruption 0-1] [visita 1-4] [flags a,b,c]
## Gera <saida_prefixo>_<cam>.png. A câmera usa o transform do marcador (posição, direção e inclinação).
## Épocas: 0 = 1950, 1 = 1975, 2 = 2019, 3 = 2020, 4 = 1967. `visita` (V2): estado do Castelinho (padrão 1; a partir da 3
## a lanterna vai ligada). `flags`: flags de GameState ligadas antes de montar o nível (ex.: tem_visor,v3_ato2_feito).
## Revisão V2: o jogador vai junto com a câmera (a lanterna e as lâmpadas mais próximas acompanham, como no jogo) e não
## dispara os gatilhos de sala. Variável de ambiente RELAMPAGO=0..1 (visita 4) congela um relâmpago naquela força.
## Não é um teste (não roda em tools/testar.sh).


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var cena: String = a[0]
	var saida: String = a[1]
	var cams: Array = Array(a[2].split(","))
	var epoca := int(a[3]) if a.size() > 3 else 3
	var corr := float(a[4]) if a.size() > 4 else 0.0
	var visita := int(a[5]) if a.size() > 5 else 1
	var flags: Array = Array(a[6].split(",")) if a.size() > 6 else []
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false      # sem tela de carregamento nem aquecimento: a captura sai mais rápida
	await process_frame
	main.tela_titulo.queue_free()
	gs.jogando = false
	gs.visita = visita
	if visita >= 3:
		gs.flags["tem_lanterna"] = true
	for f in flags:
		if f != "":
			gs.flags[f] = true
	await main.carregar_mundo(cena, "Spawn")
	main.hud.visible = false
	gs.definir_corruption_manual(corr)
	gs.trocar_epoca(epoca)
	var nivel: Node3D = main.mundo.get_child(0)
	main.player.pode_mover = false
	main.player.collision_layer = 0     # os gatilhos de sala não veem o jogador (a captura não dispara eventos)
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
		# a lanterna (visita 3+) e as lâmpadas mais próximas seguem a câmera de captura, como no jogo
		main.player.global_position = mk.global_position - Vector3(0, 1.55, 0)
		if main.player.lanterna.visible and main.player.lanterna.get_parent() != cam:
			main.player.lanterna.reparent(cam, false)
		if nivel.has_method("_atualizar_luzes"):
			nivel._atualizar_luzes()
		if OS.get_environment("RELAMPAGO") != "" and "_clarao" in nivel:
			nivel._t_relampago = 999.0       # visita 4: congela um relâmpago na força pedida (ex.: RELAMPAGO=0.85)
			nivel._clarao = float(OS.get_environment("RELAMPAGO"))
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
