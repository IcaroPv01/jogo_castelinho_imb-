extends SceneTree
## Teste automático (headless) do Mapa da Visita: ação "mapa" (M), Objetivo.atual() e seus extras, dados_mapa() do
## Castelinho (salas 1 a 22 com andar, número global por visita), abrir/fechar com a flag ui_aberta, o botão do menu de
## pausa e as mensagens das áreas sem mapa (porão, Ato II, Barra).
## Uso: godot --headless -s res://tests/mapa_test.gd

var falhas := 0
var GS
var Obj
var MapaC
var main


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("GameState")
	Obj = load("res://world/objetivo.gd")
	MapaC = load("res://ui/mapa.gd")
	GS.novo_jogo()
	GS.jogando = false

	print("-- ação do teclado")
	_checar(InputMap.has_action("mapa"), "ação 'mapa' existe")
	var tem_m := false
	for ev in InputMap.action_get_events("mapa"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_M:
			tem_m = true
	_checar(tem_m, "ação 'mapa' tem a tecla M")

	print("-- Objetivo")
	for v in [1, 2, 3, 4]:
		GS.novo_jogo()
		GS.visita = v
		var t: String = Obj.atual()
		_checar(t != "", "visita %d tem objetivo: %s" % [v, t])
	GS.novo_jogo()
	GS.visita = 1
	GS.set_flag("passaporte_lancado", true)
	_checar(String(Obj.atual()).contains("Passaporte"), "visita 1 com passaporte em andamento fala do Passaporte")
	GS.discos.append(GS.Epoca.E1950)
	GS.sala_maxima = 12
	_checar(String(Obj.atual()).contains("escada"), "visita 1 passando do corredor: procure a escada")
	GS.sala_maxima = 21
	_checar(String(Obj.atual()).contains("quiz"), "visita 1 na Sala Medieval: quiz final")
	GS.discos.clear()
	GS.sala_maxima = 0
	GS.visita = 2
	_checar(String(Obj.atual()).contains("Acervo"), "visita 2 sem disco manda ao Acervo")
	GS.visita = 3
	GS.set_flag("tem_lanterna", true)
	GS.set_flag("v3_ato2_feito", true)
	_checar(String(Obj.atual()).contains("Torre A"), "visita 3 depois do Ato II manda à Torre A")
	GS.visita = 4
	GS.ganhar_disco(GS.Epoca.E2019)
	_checar(String(Obj.atual()).to_lower().contains("porão"), "visita 4 com o disco 2019 manda descer ao porão")
	var antes: String = Obj.atual()
	var vazio := func() -> String: return ""
	var meu := func() -> String: return "Caça ao disco: teste"
	var outro := func() -> String: return "Outro"
	Obj.extras.append(vazio)
	_checar(Obj.atual() == antes, "extra que devolve vazio é ignorado")
	Obj.extras.append(meu)
	Obj.extras.append(outro)
	_checar(Obj.atual() == "Caça ao disco: teste", "o primeiro extra com texto vence")
	Obj.extras.clear()
	_checar(Obj.atual() == antes, "sem extras volta ao objetivo normal")

	print("-- sem nível: mensagens")
	GS.novo_jogo()
	GS.jogando = false

	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true

	print("-- teste.tscn (sem dados_mapa)")
	await main.carregar_mundo("res://world/niveis/teste.tscn", "Spawn")
	var d: Dictionary = MapaC.obter_dados()
	_checar(d.get("tipo") == "ausente" and d.get("msg") == "Esta área não consta no mapa.", "nível sem dados_mapa: 'Esta área não consta no mapa.'")

	print("-- Castelinho, visita 1")
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	for i in 10:
		await physics_frame
	var nivel: Node = main.mundo.get_child(0)
	_checar(nivel.has_method("dados_mapa"), "Castelinho tem dados_mapa()")
	d = MapaC.obter_dados()
	_checar(d.get("tipo") == "castelinho", "tipo castelinho")
	var por_base := {}
	for s: Dictionary in d.salas:
		por_base[int(s.base)] = s
	var faltam: Array = []
	for b in range(1, 23):
		if not por_base.has(b) or not (int(por_base[b].andar) in [0, 1, 2]) or str(por_base[b].nome) == "":
			faltam.append(b)
	_checar(faltam.is_empty(), "salas 1..22 com nome e andar (faltam: %s)" % str(faltam))
	_checar(int(por_base[17].andar) == 2 and int(por_base[18].andar) == 1 and int(por_base[12].andar) == 0, "andares: térreo, andar de cima e torre")
	_checar(int(por_base[12].global) == 12 and int(por_base[22].global) == 22, "visita 1: número global = base")
	_checar(d.predio[0].size() >= 6 and d.predio[2].size() >= 1, "contorno do prédio por andar")
	_checar(int(d.base_proxima) >= 1, "tem próxima sala (%d)" % int(d.base_proxima))
	_checar(d.jogador.has("x") and d.jogador.has("dx"), "posição e direção do jogador")
	_checar(int(d.base_atual) == 1, "jogador no Spawn = sala 1 (%d)" % int(d.base_atual))
	var rota_v1: Array = d.rota
	_checar(rota_v1.size() >= 18 and rota_v1[0] == 1, "rota da visita 1")
	# andando para o hall a sala atual muda
	main.player.global_position = Vector3(-10.4, 0.2, -12.6)
	GS.entrar_sala(7)
	d = MapaC.obter_dados()
	_checar(int(d.base_atual) == 7, "no hall = sala 7 (%d)" % int(d.base_atual))
	_checar(int(d.base_proxima) == 8, "depois do hall a próxima é a 8 (%d)" % int(d.base_proxima))
	main.player.global_position = Vector3(-19.0, 7.0, -12.4)
	d = MapaC.obter_dados()
	_checar(int(d.jogador.andar) == 2, "no topo da torre: andar 2")

	print("-- abrir e fechar")
	main.player.global_position = Vector3(-10.4, 0.2, -12.6)
	GS.flags.erase("ui_aberta")
	var ev := InputEventAction.new()
	ev.action = "mapa"
	ev.pressed = true
	main.hud._unhandled_input(ev)
	await process_frame
	await process_frame
	var mapa = MapaC.atual
	_checar(mapa != null and mapa.is_inside_tree(), "tecla M abre o mapa")
	_checar(GS.flag("ui_aberta"), "abrir liga ui_aberta")
	_checar(not main.player.pode_mover, "jogador travado com o mapa aberto")
	_checar(mapa.tipo == "castelinho" and mapa.andar == 0 and mapa.objetivo != "", "mapa leu os dados e o objetivo")
	_checar(MapaC.abrir() == mapa, "abrir de novo devolve o mesmo mapa")
	mapa.selecionar_andar(1)
	_checar(mapa.andar == 1, "trocar de andar")
	mapa.selecionar_andar(7)
	_checar(mapa.andar == 1, "andar inexistente é ignorado")
	# clique logo depois de abrir não fecha (clique emulado do toque)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	clique.position = Vector2(5, 5)
	mapa._ao_entrada(clique)
	_checar(not mapa._fechado, "clique dentro da guarda não fecha")
	await create_timer(0.5).timeout
	var ev_m := InputEventAction.new()
	ev_m.action = "mapa"
	ev_m.pressed = true
	mapa._unhandled_input(ev_m)
	await process_frame
	await process_frame
	_checar(MapaC.atual == null and not GS.flag("ui_aberta"), "M de novo fecha e solta ui_aberta")
	_checar(main.player.pode_mover, "jogador solto depois de fechar")
	# Esc fecha
	MapaC.abrir()
	await process_frame
	await process_frame
	mapa = MapaC.atual
	_checar(mapa != null and GS.flag("ui_aberta"), "abre de novo")
	var ev_esc := InputEventAction.new()
	ev_esc.action = "pausa"
	ev_esc.pressed = true
	mapa._unhandled_input(ev_esc)
	await process_frame
	await process_frame
	_checar(MapaC.atual == null and not GS.flag("ui_aberta"), "Esc fecha")
	# toque/clique depois da guarda fecha
	MapaC.abrir()
	await process_frame
	await process_frame
	mapa = MapaC.atual
	await create_timer(0.5).timeout
	mapa._ao_entrada(clique)
	await process_frame
	await process_frame
	_checar(MapaC.atual == null and not GS.flag("ui_aberta"), "clique fora das abas fecha")
	# não abre sem jogar nem com outra tela aberta
	GS.set_flag("ui_aberta", true)
	_checar(MapaC.abrir() == null, "não abre com outra tela aberta")
	GS.flags.erase("ui_aberta")
	GS.jogando = false
	_checar(MapaC.abrir() == null, "não abre fora do jogo")
	GS.jogando = true

	print("-- menu de pausa")
	var menu = main.hud.menu_pausa
	_checar(menu.btn_mapa != null and menu.btn_mapa.text == "Mapa", "botão 'Mapa' no menu")
	menu.mostrar(true, 0)
	menu.btn_mapa.pressed.emit()
	await process_frame
	await process_frame
	_checar(MapaC.atual != null and GS.flag("ui_aberta"), "botão do menu abre o mapa")
	MapaC.atual.fechar()
	await process_frame
	await process_frame
	menu.mostrar(false, 0)
	_checar(MapaC.atual == null and not GS.flag("ui_aberta"), "fechou")

	print("-- visitas 3 e 4 (numeração e dados)")
	for v in [3, 4]:
		GS.novo_jogo()
		GS.jogando = true
		GS.visita = v
		GS.set_flag("tem_lanterna", true)
		await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
		for i in 6:
			await physics_frame
		d = MapaC.obter_dados()
		por_base.clear()
		for s: Dictionary in d.salas:
			por_base[int(s.base)] = s
		var ok_todas := true
		for b in range(1, 23):
			ok_todas = ok_todas and por_base.has(b)
		_checar(ok_todas and int(d.visita) == v, "visita %d: salas 1..22" % v)
		if v == 3:
			_checar(int(por_base[1].global) == 45 and int(por_base[11].global) == 55, "visita 3: SALA 45 a 55 (%d, %d)" % [int(por_base[1].global), int(por_base[11].global)])
			_checar(int(d.base_proxima) == 11, "visita 3 antes do Ato II: a próxima é o Salão de Arte (%d)" % int(d.base_proxima))
		else:
			_checar(int(por_base[1].global) == 67 and int(por_base[22].global) == 79, "visita 4: SALA 67 a 79")
			_checar(int(d.base_proxima) == 8, "visita 4 sem o disco 2019: a próxima é a Sala dos Povos (%d)" % int(d.base_proxima))
		MapaC.abrir(true)   # (a fala de abertura da visita pode estar travando o jogador: o botão do menu força)
		await process_frame
		await process_frame
		_checar(MapaC.atual != null and MapaC.atual.visita == v, "mapa abre na visita %d" % v)
		MapaC.atual.fechar()
		await process_frame
		await process_frame

	print("-- áreas sem mapa")
	GS.novo_jogo()
	GS.jogando = true
	for par in [["res://world/niveis/porao.tscn", "porao", "Este andar não consta na planta."],
			["res://world/niveis/ato2.tscn", "fora", "Esta área não consta no mapa!"],
			["res://world/niveis/barra.tscn", "fora", "Esta área não consta no mapa!"]]:
		await main.carregar_mundo(par[0], "Spawn")
		for i in 4:
			await physics_frame
		d = MapaC.obter_dados()
		_checar(d.get("tipo") == par[1] and d.get("msg") == par[2], "%s: '%s'" % [str(par[0]).get_file(), par[2]])
		MapaC.abrir(true)
		await process_frame
		await process_frame
		_checar(MapaC.atual != null and MapaC.atual.objetivo != "", "mapa abre em %s" % str(par[0]).get_file())
		MapaC.atual.fechar()
		await process_frame
		await process_frame

	main.queue_free()
	await process_frame
	print("Mapa: %s" % ("OK" if falhas == 0 else "%d falha(s)" % falhas))
	quit(1 if falhas > 0 else 0)


func _checar(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		falhas += 1
		print("  FALHOU  ", msg)
