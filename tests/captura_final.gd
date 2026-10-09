extends SceneTree
## Capturas dos finais (precisa de renderização: xvfb-run). Não é um teste (fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_final.gd -- <modo> <pasta_saida>
## Modos: titulos | pausa | encontrado | visita_concluida | sala_101 | chegada
## "titulos" faz backup de user://finais.cfg e restaura no fim.

var gs: Node
var main: Node
var pasta := ""
var nivel: Node3D
var player: Node3D


func _initialize() -> void:
	_rodar.call_deferred()


func _foto(nome: String, frames := 8) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])
	print("foto: ", nome)


func _esperar(seg: float) -> void:
	await create_timer(seg, true).timeout


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	pasta = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	match modo:
		"titulos": await _titulos()
		"pausa": await _pausa()
		"chegada": await _braco(modo)
		_: await _braco(modo)
	quit()


func _titulos() -> void:
	var cam := ProjectSettings.globalize_path("user://finais.cfg")
	var bak := cam + ".bak_captura"
	var tinha := FileAccess.file_exists(cam)
	if tinha:
		DirAccess.copy_absolute(cam, bak)
	var Finais = load("res://ui/finais.gd")
	for f in ["encontrado", "visita_concluida", "sala_101"]:
		if FileAccess.file_exists(cam):
			DirAccess.remove_absolute(cam)
		Finais.registrar(f)
		gs.novo_jogo()
		var t = load("res://ui/tela_titulo.tscn").instantiate()
		root.add_child(t)
		await _esperar(1.5)
		await _foto("titulo_" + f)
		t.queue_free()
		await process_frame
	# os três vistos
	if FileAccess.file_exists(cam):
		DirAccess.remove_absolute(cam)
	for f in ["encontrado", "visita_concluida", "sala_101"]:
		Finais.registrar(f)
	var t2 = load("res://ui/tela_titulo.tscn").instantiate()
	root.add_child(t2)
	await _esperar(1.5)
	await _foto("titulo_todos")
	if FileAccess.file_exists(cam):
		DirAccess.remove_absolute(cam)
	if tinha:
		DirAccess.copy_absolute(bak, cam)
		DirAccess.remove_absolute(bak)


func _pausa() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	await main.carregar_mundo("res://world/niveis/braco_morto.tscn", "Spawn")
	main.hud.visible = true
	gs.contadores["pistas_tito"] = 5
	for i in 20:
		await process_frame
	main.hud._pista_nova()
	await _esperar(0.12)
	await _foto("hud_pista_pulso", 1)
	await _esperar(2.0)
	await _foto("hud_pista_repouso", 1)
	main.hud.mostrar_pausa(true)
	await _foto("pausa_principal", 6)
	main.hud.menu_pausa._ir("opcoes")
	await _foto("pausa_opcoes", 6)
	main.hud.menu_pausa._ir("confirma")
	await _foto("pausa_confirma", 6)


func _braco(modo: String) -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	await main.carregar_mundo("res://world/niveis/braco_morto.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	main.hud.visible = true
	nivel.voltar_ao_titulo = false
	for i in 15:
		await process_frame
	gs.set_flag("tem_visor", true)
	if not gs.Epoca.ESEMDATA in gs.discos:
		gs.ganhar_disco(gs.Epoca.ESEMDATA)
	gs.contadores["pistas_tito"] = nivel.PISTAS_ENCONTRADO if modo == "encontrado" else 3
	var P: Vector3 = nivel.POS_TITO
	var L: Vector3 = nivel.POS_LAPIDE
	if modo == "chegada":
		await _esperar(2.5)
		await _foto("bm_chegada")
		player.global_position = Vector3(L.x - 1.5, 0.05, L.z + 3.0)
		player.look_at_from_position(player.global_position, Vector3(L.x, 0.4, L.z))
		player.cabeca.rotation.x = -0.1
		await _foto("bm_lapide_luz", 10)
		player.global_position = Vector3(L.x - 0.3, 0.05, L.z + 1.6)
		player.rotation.y = 0.0
		await _foto("bm_lapide_perto", 10)
		# vista do lago
		player.global_position = Vector3(0, 0.05, -4)
		player.rotation.y = 0.0
		await _foto("bm_lago", 10)
		return
	if modo == "sala_101":
		var r: float = (nivel.RAMPA_X0 + nivel.RAMPA_X1) * 0.5
		player.global_position = Vector3(r, 0.05, -6.5)
		player.rotation.y = 0.0
		await process_frame
		Input.action_press("frente")
		var n := 0
		while not nivel.encerrando and n < 900:
			await process_frame
			n += 1
		Input.action_release("frente")
		await _foto("s101_comeco_afundar", 1)
		await _esperar(3.5)
		await _foto("s101_descendo", 1)
		var t := 0.0
		while t < 25.0 and nivel.get_node_or_null("FundoDoLago") == null:
			await _esperar(0.25)
			t += 0.25
		await _esperar(2.5)
		var fd: Node3D = nivel.get_node("FundoDoLago")
		print("DBG cam ", player.camera.global_position, " pitch ", player.cabeca.rotation.x, " fundo ", fd.global_position, " shoe ", (fd.get_child(0) as Node3D).global_position, " fogend ", nivel.env.fog_depth_end)
		await _foto("s101_fundo_pecas", 1)
		if OS.get_environment("DBG_SEM_TINTA") != "":
			nivel._tinta.visible = false
			await _foto("s101_dbg_sem_tinta", 3)
		await _esperar(2.0)
		await _foto("s101_fundo_pecas2", 1)
		# dedos: tira fotos a cada 0.5s até a cortina fechar
		for i in 10:
			await _esperar(0.5)
			await _foto("s101_dedos_%d" % i, 1)
			if nivel._cortina.color.a > 0.95:
				break
		await _esperar(2.5)
		await _foto("s101_cartao_ou_titulo", 1)
		await _esperar(4.0)
		await _foto("s101_seguinte", 1)
		return
	# encontrado / visita_concluida: olhar para o Tito com o Visor
	gs.trocar_epoca(gs.Epoca.ESEMDATA)
	player.global_position = Vector3(P.x, 0.05, P.z + 5.0)
	player.rotation.y = 0.0
	player.cabeca.rotation.x = 0.0
	await _foto("%s_tito_sentado" % modo, 4)
	var n := 0
	while not nivel.cena_feita and n < 900:
		await process_frame
		n += 1
	await _esperar(2.5)
	await _foto("%s_tito_vira" % modo, 1)
	await _esperar(2.5)
	await _foto("%s_fala" % modo, 1)
	if modo == "encontrado":
		var t := 0.0
		while t < 30.0 and nivel._tito_em_pe == null:
			await _esperar(0.25)
			t += 0.25
		await _foto("enc_levanta", 1)
		# foto de lado: camera distante olhando o caminho e a Figura
		for k in 6:
			await _esperar(0.8)
			await _foto("enc_anda_%d" % k, 1)
		# vista da Figura através do lago (câmera livre, sem física, a 30 / 15 / 7 m dela)
		var fig: Node3D = nivel._figura
		if fig and fig.visible:
			player.set_physics_process(false)
			for d in [30.0, 15.0, 7.0]:
				var alvo: Vector3 = fig.global_position + Vector3(0, 1.4, 0)
				var pos := Vector3(alvo.x, 1.4, alvo.z + d)
				player.global_position = pos
				player.look_at(alvo, Vector3.UP)
				player.cabeca.rotation.x = 0.0
				await _foto("enc_figura_%dm" % int(d), 4)
			player.set_physics_process(true)
			player.global_position = Vector3(2.2, 0.05, -1.5)
		await _esperar(6.0)
		await _foto("enc_depois_sumiu", 1)
		# pegadas: olhar para elas
		player.global_position = Vector3(2.2, 0.8, -1.5)
		player.rotation.y = 0.0
		player.cabeca.rotation.x = -0.5
		await _foto("enc_pegadas", 6)
		await _esperar(8.0)
		await _foto("enc_final", 1)
	else:
		var t := 0.0
		while t < 30.0 and not nivel.encerrando:
			await _esperar(0.25)
			t += 0.25
		for k in 14:
			await _esperar(0.7)
			await _foto("vc_beat_%02d" % k, 1)
