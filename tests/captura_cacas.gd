extends SceneTree
## Captura dos objetos das caças dos discos 1967, 1975 e 2019 (Castelinho). Rode com xvfb-run (não é teste).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cacas.gd -- <pasta_saida>
## Gera <pasta>/caca_<id>.png, um por objeto, vistos com o Visor no disco certo.

const ITENS := [
	# [visita, época que mostra (Epoca), id, de onde olhar (offset XZ do objeto)]
	[2, 0, 4, "pedra_gres", Vector3(1.8, 0, 1.4)], [2, 0, 4, "casa_miolo", Vector3(1.5, 0, -2.4)], [2, 0, 4, "areia_nua", Vector3(1.8, 0, 1.4)],
	[3, 4, 1, "balde", Vector3(1.8, 0, 1.4)],
	[4, 1, 2, "tito_6", Vector3(0.0, 0, 1.4)], [4, 1, 2, "tito_7", Vector3(1.4, 0, 0)], [4, 1, 2, "tito_8", Vector3(1.4, 0, 0)],
]


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.aquecer_ativo = false
	main.tela_titulo.queue_free()
	main.hud.visible = true
	for it in ITENS:
		gs.novo_jogo()
		gs.jogando = false
		gs.visita = it[0]
		gs.flags["tem_visor"] = true
		gs.flags["tem_lanterna"] = it[0] >= 3
		gs.discos.assign([it[1]])
		gs.disco_atual = it[1]
		await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
		var nivel = main.mundo.get_child(0)
		var raiz: Node3D = nivel.find_child("Caca_%d_%s" % [it[2], it[3]], true, false)
		var alvo: Vector3 = raiz.global_position + Vector3(0, 0.9 if it[3] != "casa_miolo" else 1.6, 0)
		if it[3].begins_with("tito_"):
			alvo = raiz.global_position + Vector3(0, 0.05, 0)
		var de: Vector3 = raiz.global_position + (raiz.global_transform.basis * Vector3(it[4].x, 0, it[4].z) if it[3].begins_with("tito_") else it[4])
		main.player.global_position = Vector3(de.x, 0.1, de.z)
		main.player.rotation_degrees.y = rad_to_deg(atan2(-(alvo.x - de.x), -(alvo.z - de.z)))
		main.player.cabeca.rotation_degrees.x = -rad_to_deg(atan2(1.6 - alvo.y, Vector2(alvo.x - de.x, alvo.z - de.z).length()))
		gs.trocar_epoca(it[1])
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png("%s/caca_%s.png" % [pasta, it[3]])
		print("captura: ", it[3])
	quit()
