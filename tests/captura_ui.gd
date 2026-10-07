extends SceneTree
## Tira capturas de tela da UI (precisa de renderização: rode com xvfb-run). Não é um teste.
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_ui.gd -- \
##       <modo> <saida.png> [corruption 0-1] [extra]
## Modos:
##   titulo | titulo_save     tela de título (com/sem botão "Continuar")
##   painel [id]             tela de leitura (padrão p02)        extra = id
##   quiz [id]               tela de leitura já na pergunta       extra = id
##   quiz_ok [id]            quiz com a resposta certa marcada
##   guia [personagem]       caixa de fala (bentinho|taina|quico|sistema|???)
##   placa [id]              placa 3D do painel
##   diploma | morte | fim   telas finais
## V2:
##   volte [vez]             placa "Volte sempre!" (vez 1 = alegre, 2 = estranha)
##   telefone                a voz da mãe (caixa "???" com chiado)
##   creditos | dedicatoria  créditos e a tela de dedicatória (Disque 100)
##   hud [atencao]           HUD "VISITA 3 · SALA 55", faixa de discos e olho (extra = atenção 0..1)
##   visor [atencao]         cena 3D com o Visor ligado (disco 1967), Figura no slide e olho (extra = atenção 0..1)


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	var saida: String = a[1]
	var corr := float(a[2]) if a.size() > 2 else 0.0
	var extra: String = a[3] if a.size() > 3 else ""
	root.size = Vector2i(1280, 720)
	var gs = root.get_node("/root/GameState")
	var Flash = load("res://ui/flash.gd")
	gs.novo_jogo()
	gs.definir_corruption_manual(corr)
	var espera := 0.6

	match modo:
		"titulo", "titulo_save":
			if modo == "titulo_save":
				gs.checkpoint_sala = 6
			var t = load("res://ui/tela_titulo.tscn").instantiate()
			root.add_child(t)
			espera = 1.2
		"painel", "quiz", "quiz_ok":
			var PainelUI = load("res://ui/painel_ui.gd")
			var id := extra if extra != "" else "p02"
			var ui = PainelUI.mostrar(id)
			await create_timer(0.5).timeout
			if modo != "painel":
				ui.avancar()
				ui.avancar()
				if modo == "quiz_ok":
					ui.responder(int(PainelUI.dados(id).quiz.correta if PainelUI.dados(id).quiz is Dictionary else PainelUI.dados(id).quiz[0].correta))
				else:
					ui.responder(0)
			espera = 0.9
		"guia":
			var Guia = root.get_node("/root/Guia")
			var pers := extra if extra != "" else "bentinho"
			Guia.falar(pers, ["Oi! Eu sou o Bentinho! Bem-vindo à Visita Guiada do Castelinho! Vamos aprender muita coisa juntos?"])
			espera = 2.2
		"placa":
			_cena_3d(extra if extra != "" else "p02")
			espera = 0.8
		"diploma":
			gs.ganhar_selo("a")
			gs.ganhar_selo("b")
			gs.ganhar_selo("c")
			gs.ganhar_selo("d")
			load("res://ui/diploma.gd").mostrar()
			espera = 1.4
		"volte":
			load("res://ui/volte_sempre.gd").mostrar(int(extra) if extra != "" else 1)
			espera = 2.4
		"telefone":
			var Tel = load("res://ui/telefone.gd")
			Tel.tocar(["Alô? É do Castelinho?", "O meu filho... ele vinha sempre brincar aí na obra... vocês viram o Tito?"], false)
			espera = 1.8
		"creditos", "dedicatoria":
			var d = load("res://ui/dedicatoria.gd").mostrar()
			await create_timer(0.3).timeout
			if modo == "dedicatoria":
				d._ir_para_dedicatoria()
				d._t_fase = 7.0
			else:
				d._t_fase = 5.0
			espera = 0.5
		"hud":
			_cena_hud(float(extra) if extra != "" else 0.0)
			espera = 0.9
		"visor":
			await _cena_visor(float(extra) if extra != "" else 0.6)
			espera = 0.1
		"morte":
			load("res://ui/morte.gd").mostrar("teste")
			espera = 1.0
		"fim":
			gs.contadores.paineis_lidos = 17
			gs.contadores.mortes = 2
			gs.ganhar_selo("a")
			gs.ganhar_selo("b")
			load("res://ui/fim_demo.gd").mostrar()
			espera = 1.4
	await create_timer(espera).timeout
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(saida)
	print("captura: ", saida)
	quit()


func _cena_3d(id: String) -> void:
	var Painel3D = load("res://world/painel_3d.gd")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.42, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.7
	env.environment = e
	mundo.add_child(env)
	var parede := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6, 3, 0.2)
	parede.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("A8583F")
	parede.material_override = m
	parede.position = Vector3(0, 1.4, -0.16)
	mundo.add_child(parede)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-30, -20, 0)
	mundo.add_child(luz)
	var p = Painel3D.new(id)
	p.position = Vector3(0, 1.4, 0)
	mundo.add_child(p)
	var cam := Camera3D.new()
	cam.position = Vector3(0.3, 1.5, 2.2)
	cam.fov = 60
	mundo.add_child(cam)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.current = true


func _cena_hud(atencao: float) -> void:
	var gs = root.get_node("/root/GameState")
	var fundo := ColorRect.new()
	fundo.color = Color("6E7F8F")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fundo)
	gs.visita = 3
	gs.entrar_sala(55)
	for ep in [0, 4, 1]:
		gs.ganhar_disco(ep)
	gs.selecionar_disco(4)
	var hud = load("res://ui/hud.gd").new()
	root.add_child(hud)
	gs.definir_atencao(atencao)


func _cena_visor(atencao: float) -> void:
	var gs = root.get_node("/root/GameState")
	var VisorCls = load("res://world/visor.gd")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.1, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.8
	env.environment = e
	mundo.add_child(env)
	# um corredor de pedra: chão e duas paredes
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("A8583F")
	for par in [[Vector3(0, -0.05, -10), Vector3(6, 0.1, 26)], [Vector3(-3, 1.5, -10), Vector3(0.2, 3, 26)], [Vector3(3, 1.5, -10), Vector3(0.2, 3, 26)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = par[1]
		m.mesh = b
		m.material_override = mat
		m.position = par[0]
		mundo.add_child(m)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -20, 0)
	mundo.add_child(luz)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.55, 2)
	cam.fov = 72
	mundo.add_child(cam)
	cam.current = true
	var fundo_hud = load("res://ui/hud.gd").new()
	root.add_child(fundo_hud)
	gs.visita = 3
	gs.entrar_sala(55)
	for ep in [0, 4, 1]:
		gs.ganhar_disco(ep)
	gs.selecionar_disco(4)
	gs.set_flag("tem_visor")
	var v = VisorCls.instalar(mundo)
	Input.action_press("visor")
	await create_timer(0.5).timeout
	gs.definir_atencao(atencao)
	await create_timer(0.35).timeout
	gs.definir_atencao(atencao)
