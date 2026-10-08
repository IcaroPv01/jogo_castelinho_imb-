extends SceneTree
## Captura do Passaporte do Museu (visita 1): um objeto e o contador no HUD. Rode com xvfb-run (não é teste).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_passaporte.gd -- <saida.png> <pedra|foto|chave>


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0]
	var id: String = a[1] if a.size() > 1 else "pedra"
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.aquecer_ativo = false
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.jogando = false
	main.hud.visible = true
	gs.flags["passaporte_lancado"] = true
	gs.flags["passaporte_foto"] = id != "foto"
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	var nivel = main.mundo.get_child(0)
	var alvo: Vector3 = nivel.PASSAPORTE[id]["pos"]
	var de := alvo + Vector3(1.6, 0.9, 1.4)
	if id == "foto":
		de = alvo + Vector3(1.6, 0.6, 0.0)
	if id == "chave":
		de = alvo + Vector3(-1.2, 0.8, 1.2)
	main.player.global_position = Vector3(de.x, 0.1, de.z)
	main.player.rotation_degrees.y = rad_to_deg(atan2(-(alvo.x - de.x), -(alvo.z - de.z)))
	main.player.cabeca.rotation_degrees.x = -rad_to_deg(atan2(de.y - alvo.y, Vector2(alvo.x - de.x, alvo.z - de.z).length()))
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("captura: ", saida)
	quit()
