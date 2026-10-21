extends SceneTree
## Capturas do pedalinho e do final secreto "salvar o Tito" (precisa de renderização: xvfb-run). Não é um teste (fora do CI).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_pedalinho.gd -- <modo> <pasta_saida>
## Modos: doca | barco | olhar | cena

var gs: Node
var main: Node
var pasta := ""
var nivel: Node3D
var player: Node3D
var salvar: Node


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
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.comecar_visita(5)
	await main.carregar_mundo("res://world/niveis/braco_morto.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	salvar = nivel.salvar
	main.hud.visible = true
	nivel.voltar_ao_titulo = false
	gs.set_flag("tem_visor", true)
	for ep in [4, 5]:
		gs.ganhar_disco(ep)
	gs.contadores["pistas_tito"] = 20
	for i in 20:
		await process_frame
	var q: Vector3 = salvar.POS_Q
	match modo:
		"doca":
			player.global_position = Vector3(33.5, 0.05, -6.7)
			player.look_at_from_position(player.global_position, Vector3(35.0, 0.4, -11.4))
			await _foto("doca_perto", 6)
			player.global_position = Vector3(28.0, 0.05, -5.0)
			player.look_at_from_position(player.global_position, Vector3(34.0, 0.3, -11.0))
			player.cabeca.rotation.x = -0.1
			await _foto("doca_longe", 6)
			player.global_position = Vector3(10.0, 0.05, -5.0)
			player.rotation.y = deg_to_rad(15)
			player.cabeca.rotation.x = 0.05
			await _foto("lago_com_luz", 6)
		"barco":
			salvar._colocar_no_barco(salvar.POS_DOCA, 0.0)
			await _foto("barco_doca", 8)
			player.cabeca.rotation.x = -0.6
			await _foto("barco_olhando_baixo", 6)
			player.cabeca.rotation.x = 0.0
			player.global_position = Vector3(q.x + 40.0, player.global_position.y, q.z + 8.0)
			player.rotation.y = deg_to_rad(90 + 12)
			await _foto("barco_luz_longe", 8)
			player.global_position = Vector3(q.x + 14.0, player.global_position.y, q.z + 2.0)
			player.rotation.y = deg_to_rad(90 + 8)
			await _foto("barco_luz_perto", 8)
		"olhar":
			salvar._colocar_no_barco(Vector3(q.x + 10.0, 0.0, q.z + 1.0), 0.0)
			player.look_at_from_position(player.global_position, Vector3(q.x, 0.8, q.z))
			await process_frame
			gs.trocar_epoca(gs.Epoca.E1967)
			await _foto("olhar_1967_10m", 10)
			player.global_position = Vector3(q.x + 5.0, player.global_position.y, q.z + 0.5)
			player.look_at_from_position(player.global_position, Vector3(q.x, 0.8, q.z))
			await _foto("olhar_1967_5m", 8)
			# a Figura do outro lado da água
			var f: Vector3 = salvar.fig67.global_position
			player.global_position = Vector3(q.x + 6.0, player.global_position.y, q.z - 2.0)
			player.look_at_from_position(player.global_position, Vector3(f.x, 1.2, f.z))
			await _foto("olhar_1967_figura", 8)
			player.look_at_from_position(player.global_position, Vector3(q.x, 0.8, q.z))
			gs.trocar_epoca(gs.Epoca.E2020)
			await _foto("olhar_2020_mesmo_lugar", 8)
		"cena":
			salvar.depurar_cena_final(11.0)
			for k in 30:
				await _esperar(1.4)
				await _foto("cena_%02d" % k, 1)
				if nivel.encerrando and nivel._cortina.color.a > 0.95:
					break
			await _esperar(3.0)
			await _foto("cena_titulo", 1)
			await _esperar(5.0)
			await _foto("cena_cartao", 1)
	quit()
