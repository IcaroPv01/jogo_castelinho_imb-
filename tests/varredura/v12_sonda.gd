extends SceneTree
## Sonda v12: colisor sob o gatilho 21 (Sala Medieval) na visita 1, e andar até o centro a partir da porta.
const NIVEL := "res://world/niveis/castelinho.tscn"

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	var GameState = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GameState.novo_jogo()
	GameState.jogando = true
	GameState.visita = 1
	await main.carregar_mundo(NIVEL, "Spawn")
	for i in 25:
		await physics_frame
	var p = main.player
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = Vector3(-12.6, 0.5, -25.5)
	q.collision_mask = 1
	for h in espaco.intersect_point(q, 8):
		var c = h["collider"]
		print("ponto (-12.6,0.5,-25.5) dentro de: ", c.get_path(), " pai ", c.get_parent().name, " pai2 ", c.get_parent().get_parent().name)
	for ch in main.mundo.get_child(0).find_children("Col", "StaticBody3D", true, false):
		var gp: Vector3 = ch.global_position
		if absf(gp.x + 12.6) < 4.0 and absf(gp.z + 25.5) < 4.0:
			print("colisor Col perto: ", ch.get_path(), " pos ", gp)
	# andar a pé da porta (-12.6,-24.0) até o centro (-12.6,-25.5) e para além
	p.global_position = Vector3(-12.6, 0.1, -23.5)
	p.velocity = Vector3.ZERO
	for i in 24:
		await physics_frame
	Input.action_press("frente")
	for i in 150:
		p.rotation.y = atan2(-(-12.6 - p.global_position.x), -(-27.0 - p.global_position.z))
		await physics_frame
	Input.action_release("frente")
	for i in 5:
		await physics_frame
	print("andou de (-12.6,-23.5) para o sul: pos ", p.global_position, " chão ", p.is_on_floor(), " sala ", GameState.sala_atual)
	quit(0)
