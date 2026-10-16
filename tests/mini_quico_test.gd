extends SceneTree
## Teste automático (headless) do minigame "Quico Diz" (Módulo 16) e da porta dele no Castelinho (visita 1).
## Joga as 4 rodadas chamando acionar() nos instantes certos (os intervalos vêm de `padrao_atual()`), confere o erro que repete
## a rodada, o 3º erro que facilita, a virada (resposta de fora de campo, sem o jogador repetir), a vitória (flags, pista,
## selo) e que pular() não dá nada. Depois confere que a porta existe na V1 e que o jogador alcança o Interagivel a 1,5 m.
## Uso: godot --headless -s res://tests/mini_quico_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

const MINI := "res://world/niveis/mini_quico.tscn"
const DESTINO := "res://world/niveis/teste.tscn"

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
	await _passada_facilita_e_pula()
	Engine.time_scale = 1.0
	await _passada_porta()

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


func _ate(cond: Callable, max_frames := 4000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## Avança as falas do Guia (quando houver) até a condição valer.
func _ate_falando(cond: Callable, max_frames := 9000) -> bool:
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
	nivel.destino = DESTINO     # o Castelinho não precisa carregar aqui
	await _frames(10)


## Aperta a ação nos intervalos dados (s de jogo). `escala` > 1 = mais lento.
func _tocar(intervalos: Array, escala := 1.0) -> void:
	nivel.acionar()
	for iv in intervalos:
		await create_timer(float(iv) * escala).timeout
		nivel.acionar()


func _passada_vitoria() -> void:
	print("-- quico: 4 rodadas, erro que repete, virada e vitória")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	GS.set_flag("mini_quico_feito", false)
	GS.set_flag("pista_mini_quico", false)
	await _carregar()
	_checar(nivel.id == "quico" and nivel.quem_fala == "quico", "id e quem_fala")
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")
	_checar(nivel.get_node_or_null("Quico") != null, "o Quico existe na cena")
	_checar(not player.pode_mover, "jogador parado")
	var ok: bool = await _ate_falando(func(): return nivel.rodada >= 1)
	_checar(ok, "a fala inicial passa e a rodada 1 começa")

	var esperado := [2, 3, 4, 5]
	for r in 4:
		ok = await _ate_falando(func(): return nivel.ouvindo and nivel.rodada == r + 1)
		_checar(ok, "rodada %d: a vez do jogador" % (r + 1))
		var pad: Array = nivel.padrao_atual()
		_checar(pad.size() == esperado[r] and nivel.tipos_atual().size() == r + 3, "rodada %d: %d batidas (%d intervalos)" % [r + 1, r + 3, pad.size()])
		if r == 0:
			# primeiro erro: ritmo todo igual (o padrão tem um intervalo longo): a rodada repete
			var errado: Array = []
			for i in pad.size():
				errado.append(0.25)
			await _tocar(errado)
			ok = await _ate_falando(func(): return nivel.erros_seguidos == 1 and not nivel.ouvindo)
			_checar(ok and nivel.rodada == 1, "ritmo errado: erro 1, ainda na rodada 1")
			ok = await _ate_falando(func(): return nivel.ouvindo and nivel.rodada == 1 and nivel.erros_seguidos == 1)
			_checar(ok, "a rodada 1 repete (o Quico apita de novo)")
			pad = nivel.padrao_atual()
		await _tocar(pad)
		ok = await _ate_falando(func(): return nivel.rodada > r + 1 or nivel.virada_ativa)
		_checar(ok, "rodada %d acertada" % (r + 1))
		_checar(nivel.facilitadas == 0, "sem facilitar (facilitadas=%d)" % nivel.facilitadas)

	# virada: o jogador não repete; respondem duas vezes de fora de campo
	_checar(nivel.virada_ativa and not nivel.ouvindo, "virada: o Quico apita e o jogador só escuta")
	var toques0: int = nivel._toques.size()
	nivel.acionar()
	_checar(nivel._toques.size() == toques0 and not nivel.ouvindo, "aperto na virada não conta")
	ok = await _ate_falando(func(): return nivel.respostas_de_fora >= 2, 9000)
	_checar(ok and not nivel.ouvindo, "a resposta de fora de campo vem duas vezes (%d)" % nivel.respostas_de_fora)
	_checar(nivel.padrao_atual() == nivel.intervalos_de([0, 0, 1]), "o ritmo respondido é o mesmo do Quico")
	_checar(not GS.flag("mini_quico_feito"), "ainda sem vitória durante a virada")
	ok = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 12000)
	if not ok:
		print("  (estado: terminado=%s cancelado=%s guia_ocupado=%s nivel_atual=%s vivo=%s)" % [nivel.terminado, nivel.cancelado, Gui.ocupado(), main.nivel_atual, _vivo()])
	_checar(ok, "volta ao destino depois de \"Não fui eu.\"")
	await _frames(20)
	_checar(GS.flag("mini_quico_feito") == true, "flag mini_quico_feito")
	_checar(GS.flag("pista_mini_quico") == true, "flag pista_mini_quico")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1 (%d)" % int(GS.contadores.get("pistas_tito", 0)))
	_checar(GS.selos.has("mini_quico"), "selo mini_quico")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao sair")


func _vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


func _passada_facilita_e_pula() -> void:
	print("-- quico: 3 erros facilitam; pular não dá pista")
	GS.set_flag("mini_quico_feito", false)
	GS.set_flag("pista_mini_quico", false)
	GS.selos.erase("mini_quico")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar()
	var ok: bool = await _ate_falando(func(): return nivel.ouvindo)
	_checar(ok, "rodada 1 começa")
	for e in 3:
		ok = await _ate_falando(func(): return nivel.ouvindo)
		_checar(ok, "tentativa %d" % (e + 1))
		var errado: Array = []
		for i in nivel.padrao_atual().size():
			errado.append(0.2)
		await _tocar(errado)
		ok = await _ate_falando(func(): return nivel.erros_total == e + 1 or nivel.facilitadas > 0)
	_checar(nivel.erros_total == 3, "3 erros seguidos (%d)" % nivel.erros_total)
	ok = await _ate_falando(func(): return nivel.facilitadas == 1 and nivel.rodada == 2)
	_checar(ok, "no 3º erro o Quico facilita: a rodada passa e vai para a 2")
	# sem apertar nada, a rodada também acaba perdendo (não trava): checa só que ela volta a pedir
	ok = await _ate_falando(func(): return nivel.ouvindo and nivel.rodada == 2)
	_checar(ok, "rodada 2 pede o ritmo")
	nivel.pular()
	ok = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 9000)
	_checar(ok, "pular volta ao destino")
	await _frames(10)
	_checar(not GS.flag("mini_quico_feito") and not GS.flag("pista_mini_quico"), "pular não marca feito nem pista")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0, "pular não soma pistas_tito")
	_checar(not GS.selos.has("mini_quico"), "pular não dá selo")

	# julgar: tolerância de 35%
	var cls = load("res://world/niveis/mini_quico.gd")
	_checar(cls.julgar([0.0, 0.55, 1.5], [0.5, 1.0]), "julgar: dentro da tolerância")
	_checar(not cls.julgar([0.0, 0.2, 1.2], [0.5, 1.0]), "julgar: curto demais")
	_checar(not cls.julgar([0.0, 0.5], [0.5, 1.0]), "julgar: faltou aperto")


func _passada_porta() -> void:
	print("-- quico: a porta no Castelinho (visita 1)")
	GS.novo_jogo()
	GS.jogando = true
	GS.comecar_visita(1)
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	await _frames(20)
	var c: Node = main.mundo.get_child(0)
	player = main.player
	var porta: Node3D = c.find_child("Mini_quico", true, false)
	_checar(porta != null, "Interagivel Mini_quico existe na visita 1")
	var volta: Node3D = c.find_child("Spawn_volta_mini_quico", true, false)
	_checar(volta != null, "marcador Spawn_volta_mini_quico")
	if porta == null or volta == null:
		return
	_checar(porta.get_node_or_null("VisualQuico") != null, "o visual do quadro QUICO DIZ existe")
	# o jogador em pé no ponto de volta, olhando para a porta, a ~1,5 m, a alcança com o raio
	player.global_transform = volta.global_transform
	player.velocity = Vector3.ZERO
	await _frames(20)
	var dist: float = Vector2(player.global_position.x - porta.global_position.x, player.global_position.z - porta.global_position.z).length()
	_checar(dist > 1.2 and dist < 1.9, "o ponto de volta fica a ~1,5 m da porta (%.2f m)" % dist)
	_checar(player.is_on_floor() and absf(player.global_position.y) < 0.2, "jogador no chão (y=%.2f)" % player.global_position.y)
	player.camera.look_at(porta.global_position, Vector3.UP)
	player.raio.force_raycast_update()
	var alvo: Object = player.raio.get_collider()
	_checar(alvo == porta, "o raio do jogador acerta o Mini_quico (%s)" % str(alvo))
	var dist2: float = player.camera.global_position.distance_to(porta.global_position)
	_checar(dist2 < 2.4, "dentro do alcance de interação (%.2f m)" % dist2)
