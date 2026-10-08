extends SceneTree
## QA varredura v12 (Castelinho, visitas 1 e 2): cada gatilho de sala, quedas/travamentos ao andar, falas do Guia.
## Uso: timeout 300 godot --headless -s res://tests/varredura/v12.gd

const NIVEL := "res://world/niveis/castelinho.tscn"
const CALCADA := Vector3(-23.0, 0.1, 1.5)
const ORDEM := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 16, 17, 18, 19, 20, 21, 22, 23, 25]

var falhas: int = 0
var infos: Array = []
var GameState
var Guia
var main
var p
var nivel
var falas: Array = []
var saidas: Array = []


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GameState = root.get_node("/root/GameState")
	Guia = root.get_node("/root/Guia")
	Guia.linha_mostrada.connect(_on_linha)
	GameState.sala_mudou.connect(_on_sala)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GameState.novo_jogo()
	GameState.jogando = true
	main.hud.visible = true
	for v in [1, 2]:
		await _varrer_visita(v)
	await _flashback_barra()
	for v in [1, 2]:
		await _walk(v)
	print("")
	print("== INFO ==")
	for s in infos:
		print("  ", s)
	print("== FALAS CAPTURADAS ==")
	for f in falas:
		print("  [sala %s] %s: %s" % [str(f[0]), f[1], f[2]])
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _on_linha(pers: String, texto: String) -> void:
	falas.append([GameState.sala_atual, pers, texto])


func _on_sala(n: int) -> void:
	saidas.append(n)


func _esperar(n: int) -> void:
	for i in n:
		await physics_frame


func _carregar(v: int, flags: Dictionary = {}, spawn := "Spawn") -> void:
	GameState.novo_jogo()
	GameState.visita = v
	GameState.flags["tem_visor"] = true
	for f in flags:
		GameState.flags[f] = flags[f]
	GameState.jogando = true
	await main.carregar_mundo(NIVEL, spawn)
	await _esperar(25)
	p = main.player
	nivel = main.mundo.get_child(0)


## sala global esperada para um gatilho base (visita 1: base; visita 2: base + 22; base > 22 vale a 22, como em _global)
func _esp(v: int, b: int) -> int:
	return mini(b, 22) + (v - 1) * 22


func _dentro(t, pos: Vector3) -> bool:
	var tam: Vector3 = t.tamanho
	var c: Vector3 = t.global_position + Vector3(0, tam.y * 0.5, 0)
	var d: Vector3 = (pos - c).abs()
	return d.x <= tam.x * 0.5 and d.y <= tam.y * 0.5 and d.z <= tam.z * 0.5


func _teleporte(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _esperar(24)


func _varrer_visita(v: int) -> void:
	print("-- varredura gatilhos: visita ", v)
	falas.clear()
	await _carregar(v)
	var sala0: int = GameState.sala_atual
	_checar(sala0 == _esp(v, 1), "V%d: nascer na calçada = sala %d (sala %d)" % [v, _esp(v, 1), sala0])
	_checar(p.is_on_floor(), "V%d: jogador no chão ao nascer" % v)
	var visto19 := false
	for b in ORDEM:
		if not nivel._triggers.has(b):
			infos.append("V%d: sem gatilho base %d" % [v, b])
			continue
		var t = nivel._triggers[b]
		var alvo: Vector3 = t.global_position + Vector3(0, 0.1, 0)
		# saia de dentro do gatilho alvo antes de teleportar (senão body_entered não dispara)
		if _dentro(t, p.global_position):
			await _teleporte(CALCADA if not _dentro(t, CALCADA) else Vector3(-24.5, 0.1, -4.6))
		var ants: int = GameState.sala_atual
		var extras := []
		for u in nivel._triggers:
			if u != b and _dentro(nivel._triggers[u], alvo):
				extras.append(u)
		var eh_25: bool = b == 25
		await _teleporte(alvo)
		var esperado: int = _esp(v, b)
		if b == 20 and not visto19:
			esperado = ants            # gatilho 20 só liga depois da 19
		if eh_25:
			esperado = ants            # corredor de 1975: só ativo na época 1975
		var y_ok: bool = absf(p.global_position.y - alvo.y) < 0.6 and p.is_on_floor()
		var caiu: bool = p.global_position.y < -1.0
		if extras.is_empty():
			_checar(GameState.sala_atual == esperado,
				"V%d gatilho %d: sala %d (esperado %d, antes %d)" % [v, b, GameState.sala_atual, esperado, ants])
		else:
			infos.append("V%d gatilho %d sobreposto a %s: sala %d (esperado %d)" % [v, b, str(extras), GameState.sala_atual, esperado])
		if b == 21:
			infos.append("V%d gatilho 21: centro (-12.6,-25.5) cai dentro da vitrine do Museu_2020 (0,9 m); teleporte prende o jogador, andar a pé para em z=-24.7" % v)
		else:
			_checar(y_ok and not caiu, "V%d gatilho %d: no chão no centro (y %.2f, alvo %.2f, chão %s)" % [v, b, p.global_position.y, alvo.y, str(p.is_on_floor())])
		if b == 19:
			visto19 = true
	_checar(GameState.epoca == GameState.Epoca.E2020, "V%d: a varredura inteira manteve a época 2020 (época %d)" % [v, GameState.epoca])
	# espera as falas da fila (cada linha tem seus segundos)
	var n := 0
	while Guia.ocupado() and n < 3600:
		await physics_frame
		n += 1
	await _esperar(30)
	if v == 2:
		_checar(nivel._telefone_tocando, "V2: o telefone toca ao entrar na sala 12 (tocando %s)" % str(nivel._telefone_tocando))
	var esperadas := _falas_esperadas(v)
	for item in esperadas:
		var achou := false
		for f in falas:
			if f[1] == item[1] and str(f[2]).contains(item[2]):
				achou = true
		_checar(achou, "V%d: fala do Guia '%s' (sala %d) apareceu" % [v, item[2], item[0]])


## Falas que cada sala deve disparar (lidas de castelinho.gd, _evt_sala*). [sala base, personagem, trecho do texto]
func _falas_esperadas(v: int) -> Array:
	if v == 1:
		return [[1, "bentinho", "Oi! Eu sou o Bentinho!"], [2, "taina", "Eu sou a Tainá"], [4, "quico", "Eu sou o Quico"],
			[9, "bentinho", "Olha só o pinguim"], [10, "bentinho", "Presente! O Visor"], [11, "bentinho", "Este é o Salão de Arte"]]
	return [[1, "bentinho", "Bem-vindo de volta"], [11, "bentinho", "Salão de Arte"], [12, "sistema", "Tem um disco numa vitrine"],
		[13, "taina", "não sou pescada"]]


func _flashback_barra() -> void:
	print("-- flashback da Barra (visita 2, volta em Spawn_volta_barra)")
	falas.clear()
	await _carregar(2, {"viu_flashback_barra": true}, "Spawn_volta_barra")
	_checar(GameState.sala_atual == 37, "V2 volta da Barra: sala 37 (sala %d)" % GameState.sala_atual)
	_checar(nivel._triggers.has(13) and not nivel._triggers[13].monitoring, "V2 volta da Barra: gatilho 13 desligado (nasce dentro dele)")
	await _esperar_falas()
	_checar(GameState.sala_atual == 37, "V2 volta da Barra: sem regressão de sala ao ficar em 13 (sala %d)" % GameState.sala_atual)
	_checar(_tem_fala("bentinho", "Te peguei"), "V2 volta da Barra: susto do Pescador 'Te peguei' (falas %d)" % falas.size())
	# o jogador sai do gatilho 13 e volta: não pode regredir para 35 (13 segue desligado nesta carga)
	await _teleporte(Vector3(-13.3, 0.1, -19.55))
	await _teleporte(nivel._triggers[13].global_position + Vector3(0, 0.1, 0))
	_checar(GameState.sala_atual != 35, "V2 volta da Barra: entrar de novo em 13 não regride para 35 (sala %d)" % GameState.sala_atual)
	# recarga pelo checkpoint 16 (pé da escada), com o save da Barra já gravado (evt_v2_sala15 = feito): o 13 volta a valer?
	await _carregar(2, {"viu_flashback_barra": true, "evt_v2_sala15": true}, "Checkpoint_16")
	infos.append("V2 recarga no Checkpoint_16: sala %d, gatilho 13 monitoring=%s" % [GameState.sala_atual, str(nivel._triggers[13].monitoring)])
	await _teleporte(nivel._triggers[13].global_position + Vector3(0, 0.1, 0))
	_checar(GameState.sala_atual != 35, "V2 recarga (save depois da Barra): entrar em 13 não pode regredir a sala 38 para 35 (sala %d)" % GameState.sala_atual)


func _esperar_falas() -> void:
	var n := 0
	while n < 600:
		await physics_frame
		n += 1
		if n > 120 and not Guia.ocupado():
			break


func _tem_fala(pers: String, trecho: String) -> bool:
	for f in falas:
		if f[1] == pers and str(f[2]).contains(trecho):
			return true
	return false


## Andar a pé pelo térreo (mesmos pontos do castelinho_test): quedas, travamento e sala a cada perna. V1 e V2.
func _walk(v: int) -> void:
	print("-- andar entre salas (visita ", v, ", térreo)")
	await _carregar(v)
	Engine.time_scale = 2.0
	await _teleporte(CALCADA)
	var pernas := [
		[Vector3(-6.55, 0.0, -10.5), 6, "Spawn -> porta (6)"],
		[Vector3(-6.55, 0.0, -12.6), 7, "porta -> hall (7)"],
		[Vector3(-14.8, 0.0, -12.6), 7, "hall até o fim (7)"],
		[Vector3(-18.3, 0.0, -12.9), 8, "porta do hall -> Povos (8)"],
		[Vector3(-18.6, 0.0, -14.0), 8, "Povos -> porta norte (8)"],
		[Vector3(-18.6, 0.0, -15.8), 9, "porta norte -> Meio Ambiente (9)"],
		[Vector3(-22.8, 0.0, -21.6), 10, "Meio Ambiente -> corredor (10)"],
		[Vector3(-8.5, 0.0, -19.0), 11, "Salão de Arte (11)"],
		[Vector3(-7.4, 0.0, -18.2), 12, "Acervo (12)"],
		[Vector3(-6.4, 0.0, -16.0), 13, "Pescador (13)"],
		[Vector3(-6.4, 0.0, -17.8), 12, "volta ao Acervo (12)"],
		[Vector3(-11.5, 0.0, -19.55), 11, "Salão oeste (11)"],
		[Vector3(-13.3, 0.0, -19.55), 16, "pé da escada (16)"],
		[Vector3(-8.5, 0.0, -19.0), 11, "volta ao Salão (11)"],
		[Vector3(-8.5, 0.0, -21.6), 10, "porta -> corredor (10)"],
		[Vector3(-12.6, 0.0, -21.6), 10, "corredor até a Sala Medieval (10)"],
		[Vector3(-12.6, 0.0, -24.4), 21, "porta -> Sala Medieval (21)"],
		[Vector3(-10.2, 0.0, -25.2), 21, "Sala Medieval leste (21)"],
		[Vector3(-10.2, 0.0, -28.2), 23, "porta de saída (23)"],
	]
	for leg in pernas:
		var r: Dictionary = await _andar(leg[0], 900)
		var d: float = Vector2(p.global_position.x - leg[0].x, p.global_position.z - leg[0].z).length()
		var ok: bool = r["chegou"] and d < 0.8
		_checar(ok and r["min_y"] > -1.0, "V%d perna %s: chegou=%s preso=%s dist %.2f minY %.2f sala %d" % [v, leg[2], str(r["chegou"]), str(r["preso"]), d, r["min_y"], GameState.sala_atual])
		if not ok:
			break
		_checar(GameState.sala_atual == _esp(v, leg[1]), "V%d perna %s: sala %d (esperado %d)" % [v, leg[2], GameState.sala_atual, _esp(v, leg[1])])
		if leg[1] == 6:
			# a porta de vidro fecha o arco até ler o P06 (como no castelinho_test)
			nivel._on_painel_lido("p06")
			await _esperar(90)
	Engine.time_scale = 1.0
	if v == 1:
		# corredor de 1975 visto da visita 1 em 2020: não pode ativar 1975 nem travar o visor (saída ainda fechada)
		await _teleporte(Vector3(-10.2, 0.1, -27.0))
		var r2: Dictionary = await _andar(Vector3(-10.2, 0.1, -31.0), 300)
		infos.append("V1 em 2020: andar até o corredor 1975 -> chegou=%s, sala %d, época %d, visor_travado=%s" % [str(r2["chegou"]), GameState.sala_atual, GameState.epoca, str(GameState.flag("visor_travado"))])
		_checar(not (GameState.epoca == GameState.Epoca.E1975 or GameState.flag("visor_travado")), "V1 em 2020: o corredor 1975 não muda a época nem trava o Visor")


func _andar(alvo: Vector3, max_frames: int) -> Dictionary:
	Input.action_press("frente")
	var f: int = 0
	var chegou := false
	var preso := false
	var min_y: float = 99.0
	var marca: Vector3 = p.global_position
	while f < max_frames:
		var d: Vector3 = alvo - p.global_position
		d.y = 0.0
		if d.length() < 0.45:
			chegou = true
			break
		p.rotation.y = atan2(-d.x, -d.z)
		await physics_frame
		f += 1
		min_y = minf(min_y, p.global_position.y)
		if f % 60 == 0:
			if p.global_position.distance_to(marca) < 0.15:
				preso = true
				break
			marca = p.global_position
	Input.action_release("frente")
	await physics_frame
	return {"chegou": chegou, "preso": preso, "min_y": min_y, "frames": f}


func _checar(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
