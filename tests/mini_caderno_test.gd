extends SceneTree
## Teste automático (headless) do minigame "Os desenhos do Tito" (Módulo 16) e da porta dele na Rua das casas (Módulo 14).
## Segura/solta a ação (Input.action_press/release) seguindo `no_traco`: vence os 3 desenhos, confere a cobertura >= 70%, a
## virada (o lápis continua sozinho depois do último traço e escreve "TITO"), a vitória (flags, pista, selo) e a volta. Depois
## um jogo sem apertar NADA: cada desenho ainda avança (nunca trava) e ganha cobertura baixa. Pular não dá nada. Por fim a
## porta: o Interagivel Mini_caderno existe na Rua das casas, perto do Spawn e visível de lá, o Spawn_volta_mini_caderno está
## dentro da AREA, longe de paredes (cápsula livre) e o raio do jogador acerta a porta a 1,5 m.
## Uso: godot --headless -s res://tests/mini_caderno_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

const MINI := "res://world/niveis/mini_caderno.tscn"
const DESTINO := "res://world/niveis/teste.tscn"
const CASAS := "res://world/niveis/cidade_casas.tscn"
const DESENHAR := 2     # MiniCaderno.Fase.DESENHAR
const VIRADA := 4
const FIM := 5

var falhas := 0
var GS: Node
var Gui: Node
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 10.0
	GS = root.get_node("/root/GameState")
	Gui = root.get_node("/root/Guia")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	main.aquecer_ativo = false
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true

	await _passada_vitoria()
	await _passada_errar_tudo()
	await _passada_pular()
	Engine.time_scale = 1.0
	await _passada_porta()

	Input.action_release("interagir")
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Avança as falas do Guia (quando houver) até a condição valer.
func _ate_falando(cond: Callable, max_frames := 20000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		if Gui.ocupado():
			Gui.avancar()
		await process_frame
	return cond.call()


func _carregar() -> void:
	await main.carregar_mundo(MINI, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.destino = DESTINO     # a Rua das casas não precisa carregar aqui
	await _frames(10)


func _vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


## Segura a ação quando o lápis está num trecho de TRAÇO e solta nos vazios, até o desenho `n` acabar.
## `seguir` = false: nunca aperta nada.
func _jogar_desenho(n: int, seguir := true) -> void:
	for i in 40000:
		if not _vivo() or nivel.desenho != n or nivel.fase != DESENHAR:
			break
		var quer: bool = seguir and bool(nivel.no_traco)
		if quer and not Input.is_action_pressed("interagir"):
			Input.action_press("interagir")
		elif not quer and Input.is_action_pressed("interagir"):
			Input.action_release("interagir")
		await process_frame
	Input.action_release("interagir")
	await process_frame


func _passada_vitoria() -> void:
	print("-- caderno: 3 desenhos, virada e vitória")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	GS.set_flag("mini_caderno_feito", false)
	GS.set_flag("pista_mini_caderno", false)
	GS.selos.erase("mini_caderno")
	await _carregar()
	_checar(nivel.id == "caderno" and nivel.quem_fala == "taina", "id e quem_fala")
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")
	_checar(nivel.destino == DESTINO and load(MINI).instantiate().destino == CASAS, "o destino padrão é a Rua das casas")
	_checar(nivel.fala_fim.size() >= 1, "tem fala_fim")
	_checar(not player.pode_mover, "jogador parado")
	_checar(nivel.get_node_or_null("Folha/Papel") != null and nivel.get_node_or_null("Folha/Lapis") != null, "a folha e o lápis existem")
	var luzes := 0
	for n in nivel.find_children("*", "Light3D", true, false):
		luzes += 1
	_checar(luzes <= 3, "poucas luzes (%d)" % luzes)

	for n in range(1, 4):
		var ok: bool = await _ate_falando(func(): return nivel.desenho == n and nivel.fase == DESENHAR)
		_checar(ok, "desenho %d: a folha está pronta e o lápis começa a andar" % n)
		var dur: float = nivel.duracao()
		_checar(dur > 13.0 and dur < 18.0, "desenho %d dura ~15 s (%.1f s, traço %.0f de %.0f unidades)" % [n, dur, nivel.total_traco(), nivel.comprimento()])
		var viu_traco := false
		var viu_vazio := false
		var s0: float = nivel.progresso()
		# joga o desenho: segura quando é traço
		var tempo0 := Time.get_ticks_msec()
		for i in 40000:
			if not _vivo() or nivel.desenho != n or nivel.fase != DESENHAR:
				break
			if nivel.no_traco:
				viu_traco = true
			else:
				viu_vazio = true
			var quer: bool = bool(nivel.no_traco)
			if quer and not Input.is_action_pressed("interagir"):
				Input.action_press("interagir")
			elif not quer and Input.is_action_pressed("interagir"):
				Input.action_release("interagir")
			await process_frame
		_checar(viu_traco and viu_vazio, "desenho %d: tem trechos de TRAÇO e de VAZIO" % n)
		_checar(nivel.progresso() > s0, "o lápis andou sozinho")
		if n < 3:
			# depois do último traço o jogador solta: a cobertura final vale
			Input.action_release("interagir")
			ok = await _ate_falando(func(): return nivel.coberturas.size() >= n)
			_checar(ok and float(nivel.coberturas[n - 1]) >= 0.7, "desenho %d: cobertura %.0f%% (>= 70%%) vence" % [n, float(nivel.coberturas[n - 1]) * 100.0])
			_checar(nivel.vencidos == n, "desenhos vencidos: %d" % nivel.vencidos)
		else:
			# desenho 3: o jogador solta no último traço e o lápis continua SOZINHO
			Input.action_release("interagir")
			ok = await _ate_falando(func(): return nivel.coberturas.size() >= 3)
			_checar(ok and float(nivel.coberturas[2]) >= 0.7, "desenho 3: cobertura %.0f%% (>= 70%%)" % [float(nivel.coberturas[2]) * 100.0])
			_checar(nivel.vencidos == 3, "os 3 desenhos vencidos")
			ok = await _ate_falando(func(): return nivel.fase == VIRADA)
			_checar(ok and not Input.is_action_pressed("interagir"), "virada: o jogador soltou o lápis")
			_checar(nivel.texto_escrito == "" and not nivel.casa_longe, "ainda não escreveu nada")
			var p0: int = nivel.pontos_auto
			await _frames(30)
			_checar(nivel.pontos_auto > p0 and not Input.is_action_pressed("interagir"), "o lápis risca SOZINHO (carimbos %d -> %d)" % [p0, nivel.pontos_auto])
			# apertar durante a virada não muda nada
			Input.action_press("interagir")
			var p1: int = nivel.pontos_auto
			await _frames(30)
			Input.action_release("interagir")
			_checar(nivel.pontos_auto > p1 and nivel.fase == VIRADA, "o lápis segue sozinho, o jogador não controla mais")
			ok = await _ate_falando(func(): return nivel.fase == FIM, 40000)
			_checar(ok and nivel.casa_longe, "a casinha longe foi riscada")
			_checar(nivel.texto_escrito == "TITO", "escreveu TITO (%s)" % nivel.texto_escrito)
	var ok_f: bool = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 30000)
	_checar(ok_f, "volta ao destino")
	await _frames(20)
	_checar(GS.flag("mini_caderno_feito") == true, "flag mini_caderno_feito")
	_checar(GS.flag("pista_mini_caderno") == true, "flag pista_mini_caderno")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1 (%d)" % int(GS.contadores.get("pistas_tito", 0)))
	_checar(GS.selos.has("mini_caderno"), "selo mini_caderno")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao sair")


func _passada_errar_tudo() -> void:
	print("-- caderno: não apertar nada nunca trava (cada desenho avança)")
	GS.set_flag("mini_caderno_feito", false)
	GS.set_flag("pista_mini_caderno", false)
	GS.selos.erase("mini_caderno")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar()
	for n in range(1, 4):
		var ok: bool = await _ate_falando(func(): return nivel.desenho == n and nivel.fase == DESENHAR)
		_checar(ok, "desenho %d começa" % n)
		await _jogar_desenho(n, false)
		ok = await _ate_falando(func(): return nivel.coberturas.size() >= n)
		_checar(ok and float(nivel.coberturas[n - 1]) < 0.05, "desenho %d: sem riscar, cobertura %.0f%% (< 70%%) e mesmo assim avança" % [n, float(nivel.coberturas[n - 1]) * 100.0])
	_checar(nivel.vencidos == 0, "nenhum desenho vencido")
	var ok2: bool = await _ate_falando(func(): return nivel.fase == FIM, 40000)
	_checar(ok2 and nivel.texto_escrito == "TITO", "a virada acontece mesmo assim")
	ok2 = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 30000)
	_checar(ok2, "volta ao destino")
	await _frames(20)
	_checar(GS.flag("mini_caderno_feito") and GS.flag("pista_mini_caderno"), "terminar os 3 desenhos (até errando tudo) dá a pista")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1")

	# segurar o tempo todo: no vazio só rabisca; a cobertura chega a 100% mas nada trava
	print("-- caderno: segurar o tempo todo também não trava")
	await _carregar()
	var ok: bool = await _ate_falando(func(): return nivel.desenho == 1 and nivel.fase == DESENHAR)
	Input.action_press("interagir")
	for i in 40000:
		if not _vivo() or nivel.fase != DESENHAR:
			break
		await process_frame
	Input.action_release("interagir")
	ok = await _ate_falando(func(): return nivel.coberturas.size() >= 1)
	_checar(ok and float(nivel.coberturas[0]) > 0.95, "segurar sempre cobre todo o traço (%.0f%%)" % [float(nivel.coberturas[0]) * 100.0])
	nivel.pular()
	await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 9000)
	await _frames(10)


func _passada_pular() -> void:
	print("-- caderno: pular não dá pista")
	GS.set_flag("mini_caderno_feito", false)
	GS.set_flag("pista_mini_caderno", false)
	GS.selos.erase("mini_caderno")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar()
	var ok: bool = await _ate_falando(func(): return nivel.desenho == 1 and nivel.fase == DESENHAR)
	_checar(ok, "desenho 1 começa")
	nivel.pular()
	ok = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 9000)
	_checar(ok, "pular volta ao destino")
	await _frames(10)
	_checar(not GS.flag("mini_caderno_feito") and not GS.flag("pista_mini_caderno"), "pular não marca feito nem pista")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0, "pular não soma pistas_tito")
	_checar(not GS.selos.has("mini_caderno"), "pular não dá selo")


func _passada_porta() -> void:
	print("-- caderno: a porta na Rua das casas")
	GS.novo_jogo()
	GS.jogando = true
	GS.visita = 2
	GS.entrar_sala(23)
	await main.carregar_mundo(CASAS, "Spawn")
	await _frames(20)
	var c: Node = main.mundo.get_child(0)
	player = main.player
	var porta: Node3D = c.find_child("Mini_caderno", true, false)
	_checar(porta != null, "Interagivel Mini_caderno existe na Rua das casas")
	var volta: Node3D = c.find_child("Spawn_volta_mini_caderno", true, false)
	_checar(volta != null, "marcador Spawn_volta_mini_caderno")
	var spawn: Node3D = c.find_child("Spawn", true, false)
	if porta == null or volta == null or spawn == null:
		return
	_checar(porta.get_node_or_null("VisualCaderno") != null and porta.get_node_or_null("Marca") != null, "visual do caderno e o \"!\" amarelo")
	_checar("caderno" in str(porta.texto_interacao).to_lower(), "o texto da porta fala do caderno (%s)" % porta.texto_interacao)
	var area: Rect2 = c.area
	_checar(area.has_point(Vector2(volta.global_position.x, volta.global_position.z)), "o Spawn_volta_mini_caderno está dentro da AREA")
	_checar(area.has_point(Vector2(porta.global_position.x, porta.global_position.z)), "a porta está dentro da AREA")
	# perto do Spawn e visível de lá
	var d_spawn: float = Vector2(porta.global_position.x - spawn.global_position.x, porta.global_position.z - spawn.global_position.z).length()
	_checar(d_spawn < 12.0, "a porta fica perto do Spawn (%.1f m)" % d_spawn)
	var fw: Vector3 = -spawn.global_transform.basis.z
	var para: Vector3 = (porta.global_position - spawn.global_position)
	para.y = 0.0
	var ang: float = rad_to_deg(fw.angle_to(para.normalized()))
	_checar(ang < 35.0, "a porta está à frente de quem chega (%.0f graus do olhar)" % ang)
	# o jogador no ponto de volta: cápsula livre, no chão, longe de paredes
	player.global_transform = volta.global_transform
	player.velocity = Vector3.ZERO
	await _frames(20)
	_checar(player.is_on_floor() and absf(player.global_position.y) < 0.2, "jogador no chão (y=%.2f)" % player.global_position.y)
	var pos0: Vector3 = volta.global_position
	var andou: float = Vector2(player.global_position.x - pos0.x, player.global_position.z - pos0.z).length()
	_checar(andou < 0.05, "a cápsula não foi empurrada para fora de uma parede (%.3f m)" % andou)
	_checar(not player._sobrepoe_mundo(player.global_position, 0.04), "cápsula sem sobreposição com o mundo")
	var livre := true
	for k in 12:
		var a: float = float(k) * TAU / 12.0
		var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.9, 0), player.global_position + Vector3(0, 0.9, 0) + Vector3(cos(a), 0, sin(a)) * 0.6)
		q.collision_mask = 1
		if not c.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			livre = false
	_checar(livre, "nenhuma parede a menos de 0,6 m do ponto de volta")
	var dist: float = Vector2(player.global_position.x - porta.global_position.x, player.global_position.z - porta.global_position.z).length()
	_checar(dist > 1.3 and dist < 1.7, "o ponto de volta fica a ~1,5 m da porta (%.2f m)" % dist)
	player.camera.look_at(porta.global_position, Vector3.UP)
	player.raio.force_raycast_update()
	var alvo: Object = player.raio.get_collider()
	_checar(alvo == porta, "o raio do jogador acerta o Mini_caderno (%s)" % str(alvo))
	var dist2: float = player.camera.global_position.distance_to(porta.global_position)
	_checar(dist2 < 2.4, "dentro do alcance de interação (%.2f m)" % dist2)
	# de frente: o olhar do ponto de volta (yaw) já aponta para a porta
	var olhar: Vector3 = -volta.global_transform.basis.z
	var para2: Vector3 = porta.global_position - volta.global_position
	para2.y = 0.0
	_checar(olhar.angle_to(para2.normalized()) < deg_to_rad(10.0), "o yaw do ponto de volta aponta para a porta")
	# da posição do Spawn, um raio até a porta (mirando nela) chega sem parede no meio
	var da: Vector3 = spawn.global_position + Vector3(0, 1.6, 0)
	var q2 := PhysicsRayQueryParameters3D.create(da, porta.global_position + Vector3(0, 0.3, 0))
	q2.collision_mask = 1 | 4
	q2.collide_with_areas = false
	var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(q2)
	_checar(hit.is_empty() or hit.get("collider") == porta, "linha de visão do Spawn até a porta livre (%s)" % str(hit.get("collider")))
