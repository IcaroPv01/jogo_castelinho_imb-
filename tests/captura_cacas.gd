extends SceneTree
## Captura dos objetos das caças dos discos 1967, 1975 e 2019 (Castelinho). Rode com xvfb-run (não é teste).
## Uso: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cacas.gd -- <pasta_saida>
## Gera <pasta>/caca_<id>.png, um por objeto, vistos com o Visor no disco certo.

const ITENS := [
	# [visita, época que mostra (Epoca), id, de onde olhar (offset XZ do objeto)]
	[2, 0, 4, "pedra_gres", Vector3(1.8, 0, 1.4)], [2, 0, 4, "casa_miolo", Vector3(0.0, 0, -4.5)], [2, 0, 4, "areia_nua", Vector3(1.8, 0, 1.4)],
	[3, 4, 1, "balde", Vector3(1.8, 0, 1.4)],
	[4, 1, 2, "tito_6", Vector3(0.0, 0, 2.0)], [4, 1, 2, "tito_7", Vector3(0.0, 0, 2.0)], [4, 1, 2, "tito_8", Vector3(0.0, 0, 2.0)],
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
		var alvo: Vector3 = raiz.global_position + Vector3(0, 0.9 if it[3] != "casa_miolo" else 3.4, 0)
		if it[3].begins_with("tito_"):
			alvo = raiz.global_position + Vector3(0, 0.15, 0)
		var de: Vector3 = raiz.global_position + (raiz.global_transform.basis * Vector3(it[4].x, 0, it[4].z) if it[3].begins_with("tito_") else it[4])
		main.player.global_position = Vector3(de.x, 0.1, de.z)
		main.player.rotation_degrees.y = rad_to_deg(atan2(-(alvo.x - de.x), -(alvo.z - de.z)))
		main.player.cabeca.rotation_degrees.x = -rad_to_deg(atan2(1.6 - alvo.y, Vector2(alvo.x - de.x, alvo.z - de.z).length()))
		gs.trocar_epoca(it[1])
		for i in 40:
			await process_frame
		root.get_texture().get_image().save_png("%s/caca_%s.png" % [pasta, it[3]])
		print("captura: ", it[3])
	await _trilha(main, gs, pasta)
	await _porao(main, gs, pasta)
	quit()


## As pegadas de criança do buraco até a Torre A (visita 3, caça do 1975 completa), vistas com o disco de 1967.
func _trilha(main, gs, pasta: String) -> void:
	gs.novo_jogo()
	gs.jogando = false
	gs.visita = 3
	gs.flags["tem_visor"] = true
	gs.flags["tem_lanterna"] = true
	gs.discos.assign([0, 4])
	gs.disco_atual = 4
	gs.caca_concluir(1)
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	var de := Vector3(-22.6, 0.1, -2.2)
	var alvo := Vector3(-18.0, 0.0, -8.0)
	main.player.global_position = de
	main.player.rotation_degrees.y = rad_to_deg(atan2(-(alvo.x - de.x), -(alvo.z - de.z)))
	main.player.cabeca.rotation_degrees.x = -rad_to_deg(atan2(1.6, Vector2(alvo.x - de.x, alvo.z - de.z).length())) - 4.0
	gs.trocar_epoca(4)
	for i in 40:
		root.get_node("Guia").cancelar()
		await process_frame
	root.get_texture().get_image().save_png("%s/caca_pegadas_1967.png" % pasta)
	print("captura: pegadas")


## Os 3 desenhos do porão (salas 82, 85 e 88), vistos com o disco de 2019.
func _porao(main, gs, pasta: String) -> void:
	gs.novo_jogo()
	gs.jogando = false
	gs.flags["tem_visor"] = true
	gs.discos.assign([0, 4, 1, 2])
	gs.disco_atual = 2
	gs.comecar_visita(5)
	await main.carregar_mundo("res://world/niveis/porao.tscn", "Spawn")
	var nivel = main.mundo.get_child(0)
	nivel.ameacas_ligadas = false
	var casos := [[1, "desenho_a", Vector3.RIGHT], [4, "desenho_b", Vector3.LEFT], [7, "desenho_c", Vector3.RIGHT]]
	for c in casos:
		nivel.ir_para_sala(c[0])
		for i in 8:
			await process_frame
		var sala = nivel.salas[c[0]]
		var it: Node3D = sala.raiz.find_child("InterCaca_" + c[1], true, false)
		var alvo: Vector3 = it.global_position - (sala.raiz.global_transform.basis * c[2]) * 0.3
		var n_mundo: Vector3 = sala.raiz.global_transform.basis * c[2]
		var de: Vector3 = alvo + n_mundo * 2.0
		main.player.global_position = Vector3(de.x, sala.raiz.global_position.y + 0.1, de.z)
		main.player.velocity = Vector3.ZERO
		main.player.rotation.y = atan2(n_mundo.x, n_mundo.z)
		main.player.cabeca.rotation.x = -atan2(1.6 - (alvo.y - sala.raiz.global_position.y), 2.0)
		gs.trocar_epoca(2)
		for i in 30:
			await process_frame
		root.get_texture().get_image().save_png("%s/caca_porao_%s.png" % [pasta, c[1]])
		print("captura: ", c[1])
		gs.trocar_epoca(3)
