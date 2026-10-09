extends SceneTree
## Captura da Figura Branca ANDANDO (sequência de quadros) (precisa de renderização: xvfb-run). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_figura_mov.gd -- <prefixo>
## Salva <prefixo>_00.png ... _07.png (ela anda; angulo_visao=0 para nunca contar como olhada). Não é um teste.

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var pref: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.18)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.03, 0.04)
	env.fog_density = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	# chão e corredor
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.25, 0.27, 0.28)
	var chao := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(6, 40)
	chao.mesh = pl
	chao.material_override = pm
	chao.position = Vector3(0, 0, -14)
	root.add_child(chao)
	for lado in [-3.0, 3.0]:
		var par := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 3.0, 40)
		par.mesh = bm
		par.material_override = pm
		par.position = Vector3(lado, 1.5, -14)
		root.add_child(par)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(6, 1, 40)
	cs.shape = bx
	cs.position = Vector3(0, -0.5, -14)
	sb.add_child(cs)
	root.add_child(sb)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.9, 0.8, 0.6)
	luz.light_energy = 1.2
	luz.omni_range = 8.0
	luz.position = Vector3(0, 2.6, -1)
	root.add_child(luz)
	var cam := Camera3D.new()
	cam.fov = 75
	cam.position = Vector3(0, 1.6, 0)
	root.add_child(cam)
	cam.current = true
	var jog := Node3D.new()   # alvo da Figura (grupo player), na posição da câmera
	jog.position = cam.position - Vector3(0, 1.6, 0)
	jog.add_to_group("player")
	root.add_child(jog)
	var fig = load("res://creatures/figura_branca.gd").new()
	fig.som_ativo = false
	root.add_child(fig)
	fig.angulo_visao = 0.0   # nunca "olhada": ela anda sempre
	fig.velocidade = 1.5
	fig.global_position = Vector3(0, 0, -6.5)
	fig.rotation.y = PI
	for f in 5:
		await process_frame
	for k in 8:
		var t := 0.0
		while t < 0.22:
			t += 0.016
			await process_frame
		var arq := "%s_%02d.png" % [pref, k]
		root.get_texture().get_image().save_png(arq)
		print("captura: ", arq, " z=", fig.global_position.z, " movendo=", fig._movendo)
	quit()
