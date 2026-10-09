extends SceneTree
## Capturas do porão com câmera posicionada (precisa de renderização: xvfb-run). Não é um teste (fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_porao_vista.gd -- <pasta>
## Tira as vistas fixas de VISTAS (sala 87 correntes, 90 cela do giz, 98 slide) com o diálogo do sistema fechado.

# idx da sala (0 = 81) | nome | época | câmera local (x, z) | alvo local (x, y, z); "w" = metade da largura da sala
const VISTAS := [
	[6, "porao_87_correntes", 3, Vector2(0.9, -8.0), Vector3(-9.0, 1.9, -11.0)],
	[6, "porao_87_correntes_perto", 3, Vector2(0.6, -9.6), Vector3(-9.0, 1.7, -11.0)],
	[9, "porao_90_cela", 3, Vector2(-0.8, -6.0), Vector3(9.0, 1.4, -6.0)],
	[9, "porao_90_giz_perto", 3, Vector2(4.6, -6.0), Vector3(6.3, 1.5, -6.8)],
	[9, "porao_90_giz_perto2", 3, Vector2(4.6, -6.0), Vector3(6.3, 1.5, -5.2)],
	[9, "porao_90_giz_baixo", 3, Vector2(4.4, -6.4), Vector3(6.3, 0.8, -6.9)],
	[17, "porao_98_slide_ini", 5, Vector2(0.0, -1.4), Vector3(0.0, 1.4, -30.0)],
	[17, "porao_98_slide_meio", 5, Vector2(0.0, -6.0), Vector3(0.0, 1.4, -30.0)],
	[17, "porao_98_normal_meio", 3, Vector2(0.0, -6.0), Vector3(0.0, 1.4, -30.0)],
]


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var guia = root.get_node("/root/Guia")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.set_flag("tem_lanterna")
	gs.comecar_visita(5)
	gs.jogando = false
	await main.carregar_mundo("res://world/niveis/porao.tscn", "Spawn")
	var nivel = main.mundo.get_child(0)
	main.hud.visible = true
	var atual := -1
	for v in VISTAS:
		var i: int = v[0]
		if i != atual:
			nivel.ir_para_sala(i)
			atual = i
		if nivel.figura:
			nivel.figura.esconder()      # sem morte durante a captura
		if nivel.costela:
			nivel.costela.visible = false
			nivel.costela.set_physics_process(false)
		gs.definir_corruption_manual(0.5)
		gs.trocar_epoca(v[2])
		var c = nivel.salas[i]
		var cam: Vector2 = v[3]
		var alvo: Vector3 = v[4]
		var p: Vector3 = c.raiz.to_global(Vector3(cam.x, 0.05, cam.y))
		var a: Vector3 = c.raiz.to_global(alvo)
		main.player.global_position = p
		var d := a - (p + Vector3(0, 1.6, 0))
		main.player.rotation.y = atan2(-d.x, -d.z)
		main.player.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		for f in 6:
			await process_frame
		guia.cancelar()
		for f in 20:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [pasta, v[1]])
		print("captura: ", v[1], " w=", c.w, " L=", c.L, " dy=", c.dy)
	quit()
