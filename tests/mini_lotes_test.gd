extends SceneTree
## Teste do minigame "Planejar a cidade" (lotes, Módulo 16), headless: a porta existe na visita 3 e dá para ficar a 1,5 m dela;
## o jogo carimba os 6 lotes (errar só repete), a música para no 5º, a virada deixa a planta vazia, e vencer dá a pista do
## Tito (flags, contador, selo); pular não dá nada.
## Uso: godot --headless -s res://tests/mini_lotes_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

const NIVEL := "res://world/niveis/mini_lotes.tscn"
const CASTELINHO := "res://world/niveis/castelinho.tscn"
const TESTE := "res://world/niveis/teste.tscn"

var falhas := 0
var GS: Node
var Gui: Node
var Au: Node
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	Gui = root.get_node("/root/Guia")
	Au = root.get_node("/root/Audio")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true

	await _porta_no_castelinho()
	await _passada_completa()
	await _passada_pular()

	Engine.time_scale = 1.0
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 1500) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		Gui.avancar()
		await physics_frame
	return cond.call()


func _vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


func _livre(espaco: PhysicsDirectSpaceState3D, forma: Shape3D, desloc: Vector3, pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), pos + desloc)
	return espaco.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------------------- a porta no Castelinho (visita 3)
func _porta_no_castelinho() -> void:
	print("-- castelinho visita 3: a porta do minigame")
	GS.comecar_visita(3)
	await main.carregar_mundo(CASTELINHO, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(10)
	var porta := nivel.find_child("Mini_lotes", true, false) as Node3D
	_checar(porta != null, "o Interagivel Mini_lotes existe na visita 3")
	var volta := nivel.find_child("Spawn_volta_mini_lotes", true, false) as Node3D
	_checar(volta != null, "o marcador Spawn_volta_mini_lotes existe")
	if porta == null or volta == null:
		return
	var dist := Vector2(porta.global_position.x - volta.global_position.x, porta.global_position.z - volta.global_position.z).length()
	_checar(absf(dist - 1.5) < 0.2, "o jogador volta a 1,5 m da porta (%.2f m)" % dist)
	# o jogador cabe ali (cápsula livre) e o raio de interação, olhando de frente, acha a porta
	var cs: CollisionShape3D
	for c in player.get_children():
		if c is CollisionShape3D:
			cs = c
	var espaco: PhysicsDirectSpaceState3D = nivel.get_world_3d().direct_space_state
	_checar(_livre(espaco, cs.shape, cs.position, volta.global_position), "a cápsula do jogador cabe no ponto de volta")
	# caminho a pé: do meio do Salão de Arte (sala 11) até o ponto da porta, em linha reta, sem parede
	var livre_todo := true
	var x := -9.8
	while x <= volta.global_position.x:
		if not _livre(espaco, cs.shape, cs.position, Vector3(x, 0.1, volta.global_position.z)):
			livre_todo = false
		x += 0.2
	_checar(livre_todo, "dá para chegar a pé do Salão de Arte até a porta")
	player.global_position = volta.global_position
	player.rotation.y = volta.rotation.y
	player.cabeca.rotation.x = 0.0
	await _frames(3)
	player.raio.force_raycast_update()
	var alvo: Object = player.raio.get_collider() if player.raio.is_colliding() else null
	_checar(alvo != null and (alvo == porta or (alvo is Node and (alvo as Node).name == "Mini_lotes")), "o raio do jogador acerta a porta a 1,5 m (%s)" % [alvo])
	# a porta não ocupa a sala 11 (Ato II) nem a 17 (disco 1975)
	_checar(int(load("res://world/niveis/castelinho_minigames.gd").ENTRADAS["lotes"]["sala"]) not in [11, 17], "a sala da porta não é a 11 nem a 17")


# ---------------------------------------------------------------------------- jogo completo
func _carregar() -> void:
	GS.comecar_visita(3)
	GS.contadores.erase("pistas_tito")
	GS.flags.erase("mini_lotes_feito")
	GS.flags.erase("pista_mini_lotes")
	GS.selos.erase("mini_lotes")
	await main.carregar_mundo(NIVEL, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.destino = TESTE        # o Castelinho não precisa carregar aqui
	await _frames(10)


func _passada_completa() -> void:
	print("-- lotes: os 6 carimbos")
	await _carregar()
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	_checar(nivel.id == "lotes" and nivel.quem_fala == "taina", "id lotes, fala da Tainá")
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")
	_checar(not player.pode_mover, "o jogador fica parado")
	_checar(nivel._lbl_placar.text == "Lotes 0/6", "placar Lotes 0/6 (%s)" % nivel._lbl_placar.text)
	_checar(nivel._planta != null and nivel._ranchos.size() == 6 and nivel._casas.size() == 6, "planta com 6 lotes, ranchos e casinhas")
	_checar(nivel._carrinho != null, "o carrinho de madeira está na planta")
	_checar(abs(GS.corruption - 0.08) < 0.02, "corrupção baixa (%.2f)" % GS.corruption)
	var ok: bool = await _ate(func(): return nivel.fase == nivel.Fase.CARIMBAR, 3000)
	_checar(ok, "depois da fala, o carimbo começa a andar")

	# errar só repete
	ok = await _ate(func(): return not nivel.carimbo_sobre_lote(), 600)
	nivel.acionar()
	await _frames(3)
	_checar(nivel.erros == 1 and nivel.lotes_feitos == 0, "carimbo fora do lote: só repete (erros=%d)" % nivel.erros)
	ok = await _ate(func(): return nivel.fase == nivel.Fase.CARIMBAR, 600)
	_checar(ok, "e o carimbo volta a andar")

	for n in range(1, 7):
		_checar(nivel.lote_atual() == n - 1, "lote %d é o da vez" % n)
		ok = await _ate(func(): return nivel.carimbo_sobre_lote(), 1200)
		_checar(ok, "lote %d: o carimbo chega em cima do lote" % n)
		nivel.acionar()
		ok = await _ate(func(): return nivel.lotes_feitos == n, 600)
		_checar(ok, "lote %d carimbado (%s)" % [n, nivel._lbl_placar.text])
		await _frames(30)
		_checar(not nivel._ranchos[n - 1].visible and nivel._casas[n - 1].visible, "lote %d: rancho some e casinha de projeto aparece" % n)
		if n == 5:
			ok = await _ate(func(): return nivel.fase == nivel.Fase.CARIMBAR, 2400)
			_checar(Au.musica_atual() == "", "do 5º lote em diante a música para")
			_checar(nivel._nivel_luz < 0.6, "e a luz caiu (%.2f)" % nivel._nivel_luz)
		elif n < 6:
			ok = await _ate(func(): return nivel.fase == nivel.Fase.CARIMBAR, 2400)
	ok = await _ate(func(): return nivel.fase == nivel.Fase.VIRADA, 2400)
	_checar(ok, "depois do 6º lote vem a virada")
	ok = await _ate(func(): return nivel.get_node_or_null("Planta/BarcoVirado") != null, 2400)
	_checar(ok, "a planta fica vazia e aparece um barco virado")
	var casas_visiveis := 0
	for c in nivel._casas:
		if c.visible:
			casas_visiveis += 1
	_checar(casas_visiveis == 0, "as casinhas de projeto sumiram (%d visíveis)" % casas_visiveis)
	_checar(nivel._carrinho.visible, "o carrinho continua lá")
	var marcas := 0
	for m in nivel._marcas:
		if m.visible:
			marcas += 1
	_checar(marcas == 6, "6 marcas escuras de onde havia ranchos")
	ok = await _ate(func(): return main.nivel_atual == TESTE and not _vivo(), 6000)
	_checar(ok, "volta ao nível de destino")
	if not ok:
		print("    id=", nivel.get_instance_id(), " fase=", nivel.fase if _vivo() else -1, " terminado=", nivel.terminado if _vivo() else "?", " atual=", main.nivel_atual, " guia ocupado=", Gui.ocupado())
	await _frames(20)
	_checar(GS.flag("mini_lotes_feito") == true, "flag mini_lotes_feito")
	_checar(GS.flag("pista_mini_lotes") == true, "flag pista_mini_lotes")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1 (%d)" % int(GS.contadores.get("pistas_tito", 0)))
	_checar("mini_lotes" in GS.selos, "selo mini_lotes")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao sair")


func _passada_pular() -> void:
	print("-- lotes: pular não dá pista")
	await _carregar()
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	var ok: bool = await _ate(func(): return nivel.fase == nivel.Fase.CARIMBAR, 3000)
	_checar(ok, "o jogo começou")
	var id_nivel: int = nivel.get_instance_id()
	nivel.pular()
	ok = await _ate(func(): return main.nivel_atual == TESTE and not is_instance_id_valid(id_nivel), 3000)
	_checar(ok, "pular volta ao destino")
	await _frames(10)
	_checar(not GS.flag("mini_lotes_feito") and not GS.flag("pista_mini_lotes"), "pular não marca flags")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0, "pular não dá pista do Tito")
	_checar(not ("mini_lotes" in GS.selos), "pular não dá selo")
