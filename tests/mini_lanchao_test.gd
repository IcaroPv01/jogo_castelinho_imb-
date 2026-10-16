extends SceneTree
## Teste do minigame "O Lanchão" (Módulo 16): a porta na Sala do Pescador (visita 2), as 8 puxadas no ritmo, a virada
## (os bois seguem sem ninguém), a pegada de criança, a pista/selo e o pular (que não dá nada).
## Uso: godot --headless -s res://tests/mini_lanchao_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

const CENA := "res://world/niveis/mini_lanchao.tscn"

var falhas := 0
var GS: Node
var Gui: Node
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Gui = root.get_node("/root/Guia")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true

	await _porta()
	await _vitoria()
	await _pular()

	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _ate(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _carregar() -> void:
	await main.carregar_mundo(CENA, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.destino = "res://world/niveis/teste.tscn"   # o Castelinho não precisa estar de pé aqui
	await _frames(5)


func nivel_vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


# ---------------------------------------------------------------- a porta no Castelinho (visita 2)
func _porta() -> void:
	print("-- lanchão: a porta na Sala do Pescador (visita 2)")
	GS.novo_jogo()
	GS.comecar_visita(2)
	GS.flags["tem_visor"] = true
	GS.jogando = true
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	await _frames(25)
	var cas: Node = main.mundo.get_child(0)
	var it: Node3D = cas.get_node_or_null("Mini_lanchao")
	_checar(it != null, "Interagivel Mini_lanchao existe na visita 2")
	var mk: Node3D = cas.get_node_or_null("Spawn_volta_mini_lanchao")
	_checar(mk != null, "marcador Spawn_volta_mini_lanchao existe")
	if it == null or mk == null:
		return
	_checar(it.get_node_or_null("VisualLanchao") != null, "a gravura (moldura + papel) existe")
	var d: float = Vector2(it.global_position.x - mk.global_position.x, it.global_position.z - mk.global_position.z).length()
	_checar(absf(d - 1.5) < 0.2, "o jogador volta a ~1,5 m da gravura (%.2f m)" % d)
	# o jogador pode mesmo ficar ali: põe o corpo no marcador, deixa a física assentar e confere que ele não foi empurrado
	var p: Node3D = main.player
	p.global_position = mk.global_position
	p.global_rotation.y = mk.global_rotation.y
	for i in 20:
		await physics_frame
	var desvio: float = Vector2(p.global_position.x - mk.global_position.x, p.global_position.z - mk.global_position.z).length()
	_checar(desvio < 0.1 and p.is_on_floor(), "jogador fica em pé no ponto de volta, no chão (desvio %.2f)" % desvio)
	# o raio do jogador (alcance) acerta a gravura estando ali, olhando para ela
	var espaco: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var olho: Vector3 = p.camera.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(olho, olho + (-p.camera.global_transform.basis.z) * 3.0, 1 | 4)
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var h: Dictionary = espaco.intersect_ray(q)
	_checar(not h.is_empty() and h["collider"] == it, "olhando de frente, o raio acerta a gravura (%s)" % str(h.get("collider")))
	# nada no caminho: o corpo não bate em nada entre o ponto e a parede (parede a ~1,5 m)
	var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(olho, olho + Vector3(1, 0, 0) * 3.0, 1)
	var h2: Dictionary = espaco.intersect_ray(q2)
	_checar(not h2.is_empty() and absf(h2["position"].x - it.global_position.x) < 0.3, "a parede está logo atrás da gravura (x=%.2f)" % float(h2.get("position", Vector3.ZERO).x))


# ---------------------------------------------------------------- jogar de verdade
func _vitoria() -> void:
	print("-- lanchão: 8 puxadas certas")
	Engine.time_scale = 3.0
	GS.set_flag("mini_lanchao_feito", false)
	GS.set_flag("pista_mini_lanchao", false)
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar()
	_checar(nivel.id == "lanchao", "id = lanchao")
	_checar(not player.pode_mover, "o jogador fica parado")
	_checar(nivel.puxadas == 0, "começa sem puxadas")
	# a Tainá explica (3 falas)
	var ok: bool = await _ate(func():
		Gui.avancar()
		return not Gui.ocupado(), 1500)
	_checar(ok, "a Tainá termina de explicar")
	# um aperto fora da janela só atrasa
	await _frames(30)
	var x0: float = float(nivel._com.position.x)
	ok = await _ate(func(): return nivel.esta_na_janela() or nivel._tc > 0.5, 600)
	if nivel._tc < 1.0 and nivel._tc > 0.0:
		nivel.acionar()      # cedo demais
		_checar(nivel.erros >= 1 and nivel.puxadas == 0, "apertar cedo é erro e não puxa (erros %d)" % nivel.erros)
	# agora as 8 puxadas, cada uma na hora do passo
	for n in range(1, 9):
		ok = await _ate(func(): return nivel.esta_na_janela(), 1200)
		_checar(ok, "puxada %d: a janela abriu" % n)
		nivel.acionar()
		ok = await _ate(func(): return nivel.puxadas == n, 60)
		_checar(ok, "puxada %d contou (puxadas %d)" % [n, nivel.puxadas])
	await _ate(func(): return absf(float(nivel._com.position.x) - 8 * float(nivel.PASSO)) < 0.05, 300)
	_checar(float(nivel._com.position.x) > x0 + 8 * float(nivel.PASSO) - 0.1, "o comboio andou 8 passos (x=%.2f)" % float(nivel._com.position.x))
	# a virada: o barco entra na água, os homens sentam, mas os bois seguem no ritmo
	ok = await _ate(func(): return nivel._na_agua, 900)
	_checar(ok, "o barco chega à água")
	ok = await _ate(func(): return nivel._homens_sentados, 900)
	_checar(ok, "os homens param e sentam")
	_checar(nivel._fantasma and not nivel._ativo_ciclo, "os bois seguem no ritmo sozinhos")
	var tens_max := 0.0
	var batidas := 0
	var antes: float = nivel._tc
	for i in 240:
		await process_frame
		tens_max = maxf(tens_max, float(nivel._tens))
		if nivel._tc < antes - 1.0:
			batidas += 1
		antes = nivel._tc
	_checar(tens_max > 0.8, "a corda continua esticando sozinha (tensão %.2f)" % tens_max)
	_checar(not nivel.esta_na_janela(), "ninguém mais aperta: não há janela")
	# a Tainá: 'Já acabou. Quem ainda está puxando?'; avança as falas
	ok = await _ate(func():
		Gui.avancar()
		return nivel._pegada != null, 2400)
	_checar(ok, "aparece a pegada de criança na lama")
	var n_pegadas := 0
	for c in nivel.get_children():
		if c.name.begins_with("PegadaTito") or c.name == "Pegada":
			n_pegadas += 1
	_checar(n_pegadas == 1, "exatamente 1 pegada (%d)" % n_pegadas)
	# fala_fim, flags, pista, selo e volta
	ok = await _ate(func():
		Gui.avancar()
		return GS.flag("mini_lanchao_feito"), 4000)
	_checar(ok, "flag mini_lanchao_feito")
	_checar(GS.flag("pista_mini_lanchao"), "flag pista_mini_lanchao")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1 (%d -> %d)" % [pistas0, int(GS.contadores.get("pistas_tito", 0))])
	_checar(("mini_lanchao" in GS.selos), "selo mini_lanchao")
	ok = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == "res://world/niveis/teste.tscn", 4000)
	_checar(ok, "volta ao destino")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao sair")


# ---------------------------------------------------------------- pular
func _pular() -> void:
	print("-- lanchão: pular não dá nada")
	Engine.time_scale = 1.0
	GS.set_flag("mini_lanchao_feito", false)
	GS.set_flag("pista_mini_lanchao", false)
	GS.selos.erase("mini_lanchao")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar()
	await _frames(10)
	nivel.pular()
	await _frames(5)
	_checar(nivel.cancelado and nivel.terminado, "pular cancela o minigame")
	await _ate(func(): return main.nivel_atual == "res://world/niveis/teste.tscn", 1200)
	_checar(not GS.flag("mini_lanchao_feito"), "pular não marca feito")
	_checar(not GS.flag("pista_mini_lanchao") and int(GS.contadores.get("pistas_tito", 0)) == pistas0, "pular não dá pista")
	_checar(not ("mini_lanchao" in GS.selos), "pular não dá selo")
