extends SceneTree
## Varredura QA da Barra (flashback visita 2) + mural do Castelinho. Headless.
## Uso: timeout 300 godot --headless -s res://tests/varredura/barra.gd

const BARRA := "res://world/niveis/barra.tscn"
const CASTELINHO := "res://world/niveis/castelinho.tscn"
const XMIN := -2.6
const XMAX := 2.6
const ZMIN := -2.4
const ZMAX := 9.4

var falhas := 0
var oks := 0
var GS: Node
var Gui: Node
var Tr: Node
var main: Node
var nivel
var player: Node
var _vetor := {"frente": Vector2(0, -1), "tras": Vector2(0, 1), "esquerda": Vector2(-1, 0), "direita": Vector2(1, 0)}


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	Gui = root.get_node("/root/Guia")
	Tr = root.get_node("/root/Transicao")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	await _caminhada()
	await _sequencia_real()
	await _falhas_e_morte()
	await _save_continue()
	Engine.time_scale = 1.0
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
	print("RESUMO: %d ok, %d FALHA(S)" % [oks, falhas])
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	if cond:
		oks += 1
		print("  ok    " + msg)
	else:
		falhas += 1
		print("  FALHA " + msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _carregar_barra(espera_max := 0.6) -> void:
	GS.comecar_visita(2)
	await main.carregar_mundo(BARRA, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.espera_min = espera_max * 0.5
	nivel.espera_max = espera_max
	await _frames(10)


func _apertar_lancar() -> void:
	Input.action_press("interagir")
	await _frames(3)
	Input.action_release("interagir")
	await _frames(2)


func _nos(n: Node, acc: Array) -> Array:
	acc.append(n)
	for c in n.get_children():
		_nos(c, acc)
	return acc


func _fechar_morte() -> bool:
	for n in _nos(root, []):
		var sc = n.get_script()
		if sc and sc.resource_path == "res://ui/morte.gd":
			n.continuar()
			return true
	return false


## Quanto o jogador ainda anda em direção u (unitário) antes de bater na caixa invisível.
func _livre(p: Vector2, u: Vector2) -> float:
	var t := 1e9
	if u.x > 0.001:
		t = minf(t, (XMAX - p.x) / u.x)
	elif u.x < -0.001:
		t = minf(t, (XMIN - p.x) / u.x)
	if u.y > 0.001:
		t = minf(t, (ZMAX - p.y) / u.y)
	elif u.y < -0.001:
		t = minf(t, (ZMIN - p.y) / u.y)
	return t


# ============================================================ 1. caminhada
func _caminhada() -> void:
	print("-- 1. caminhada: 4 pontos x 8 direções x 2.5 s (sem sinal do boto)")
	GS.set_flag("viu_flashback_barra", false)
	await _carregar_barra(999.0)
	await _ate(func():
		Gui.avancar()
		return nivel.fase == nivel.Fase.ESPERA, 1500)
	var pontos := [Vector3(0, 0.1, -1.0), Vector3(-2.0, 0.1, -1.5), Vector3(2.2, 0.1, 6.0), Vector3(-1.5, 0.1, 8.6)]
	var dirs := [["frente"], ["frente", "direita"], ["direita"], ["tras", "direita"],
		["tras"], ["tras", "esquerda"], ["esquerda"], ["frente", "esquerda"]]
	for p0 in pontos:
		player.global_position = p0
		await _frames(30)
		_checar(player.is_on_floor() and absf(player.global_position.y) < 0.1,
			"ponto %s: no chão (y=%.2f, on_floor=%s)" % [str(p0), player.global_position.y, str(player.is_on_floor())])
		for acoes in dirs:
			player.global_position = p0
			await _frames(20)
			var ini: Vector3 = player.global_position
			var vx: float = 0.0
			var vz: float = 0.0
			for a in acoes:
				var v: Vector2 = _vetor[a]
				vx += v.x
				vz += v.y
			var u := Vector2(vx, vz).normalized()
			var ymin: float = 1e9
			var ymax: float = -1e9
			for a in acoes:
				Input.action_press(a)
			for i in 150:
				await physics_frame
				ymin = minf(ymin, player.global_position.y)
				ymax = maxf(ymax, player.global_position.y)
			for a in acoes:
				Input.action_release(a)
			await _frames(3)
			var fim: Vector3 = player.global_position
			var deslocou := Vector2(fim.x - ini.x, fim.z - ini.z).length()
			var livre := _livre(Vector2(ini.x, ini.z), u)
			var esperado := minf(livre, 7.0)
			var rotulo := "%s %s" % [str(p0), str(acoes)]
			_checar(ymin > -0.2 and ymax < 0.4, "%s: y estável [%.2f..%.2f]" % [rotulo, ymin, ymax])
			_checar(not (livre > 1.0 and deslocou < 0.3), "%s: não preso (andou %.2f, livre %.2f)" % [rotulo, deslocou, livre])
			_checar(fim.x > -3.1 and fim.x < 3.1 and fim.z > -3.2 and fim.z < 10.2, "%s: dentro da área (%s)" % [rotulo, str(fim)])
			if deslocou < esperado * 0.5 and livre > 1.0:
				print("  AVISO %s: andou pouco (%.2f de ~%.2f)" % [rotulo, deslocou, esperado])


# ============================================================ 2. sequência real
func _sequencia_real() -> void:
	print("-- 2. sequência real: mural do Castelinho -> Barra (3 lances) -> Castelinho")
	GS.novo_jogo()
	GS.comecar_visita(2)
	await main.carregar_mundo(CASTELINHO, "Spawn")
	var castelo = main.mundo.get_child(0)
	await _frames(30)
	_checar(castelo.find_child("Spawn_volta_barra", true, false) != null, "castelinho tem Spawn_volta_barra")
	castelo._usar_mural(null)
	var ok: bool = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == BARRA, 2400)
	_checar(ok, "mural leva à Barra")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.espera_min = 0.3
	nivel.espera_max = 0.6
	_checar(GS.sala_atual == 36 and main.hud.lbl_sala.text.contains("36"), "sala 36 ao entrar na Barra (%d)" % GS.sala_atual)
	ok = await _ate(func():
		Gui.avancar()
		return nivel.fase == nivel.Fase.ESPERA, 1500)
	_checar(ok, "intro da Tainá termina e o minigame começa")
	for n in [1, 2]:
		ok = await _ate(func(): return nivel.janela_aberta, 1500)
		_checar(ok, "lance %d: janela abre" % n)
		await _apertar_lancar()
		ok = await _ate(func(): return nivel.lances == n, 600)
		_checar(ok and nivel.tainhas > 0, "lance %d conta (tainhas=%d)" % [n, nivel.tainhas])
	ok = await _ate(func(): return nivel.janela_aberta, 1500)
	_checar(ok, "3º lance: janela abre")
	await _apertar_lancar()
	ok = await _ate(func(): return nivel.fase == nivel.Fase.PUXADO, 600)
	_checar(ok, "3º lance: fase PUXADO")
	_checar(nivel.lances == 3 and nivel.tainhas == 11, "placar 3 lances / 11 tainhas (lances=%d tainhas=%d)" % [nivel.lances, nivel.tainhas])
	var rede = nivel._rede_jogador
	_checar(rede != null and rede.get_node_or_null("Sandalia") != null, "rede do 3º lance traz sandália")
	_checar(GS.flag("viu_sandalia_barra") == true, "flag viu_sandalia_barra")
	var sustos0: int = GS.contadores.get("sustos", 0)
	ok = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == CASTELINHO, 2400)
	_checar(ok, "volta ao Castelinho")
	await _frames(30)
	castelo = main.mundo.get_child(0)
	player = main.player
	var mk = castelo.find_child("Spawn_volta_barra", true, false)
	_checar(mk != null and player.global_position.distance_to(mk.global_position) < 1.0,
		"chega no Spawn_volta_barra (%s)" % str(player.global_position))
	_checar(GS.flag("viu_flashback_barra") == true, "flag viu_flashback_barra")
	_checar(GS.sala_atual == 37 and main.hud.lbl_sala.text.contains("37"), "sala 37 e HUD 37 (%d)" % GS.sala_atual)
	_checar(castelo.get("_triggers")[13].monitoring == false, "gatilho 13 desligado na volta")
	_checar(GS.corruption_manual == -1.0, "corruption manual liberada ao sair")
	_checar(not Tr.ocupado, "Transicao livre")
	ok = await _ate(func(): return GS.contadores.get("sustos", 0) > sustos0, 600)
	_checar(ok and GS.contadores.get("sustos", 0) == sustos0 + 1, "recorte do pescador cai na volta (susto +1)")
	castelo._usar_mural(null)
	await _frames(120)
	_checar(main.nivel_atual == CASTELINHO and GS.sala_atual == 37 and not Tr.ocupado, "mural não reabre a Barra depois")


# ============================================================ 3. falhas e morte
func _falhas_e_morte() -> void:
	print("-- 3a. janela que fecha sem lance")
	GS.set_flag("viu_flashback_barra", false)
	await _carregar_barra(0.6)
	await _ate(func():
		Gui.avancar()
		return nivel.fase == nivel.Fase.ESPERA, 1500)
	var ok: bool = await _ate(func(): return nivel.janela_aberta, 1500)
	ok = await _ate(func(): return not nivel.janela_aberta, 600)
	ok = await _ate(func(): return nivel.janela_aberta, 1500)
	_checar(nivel.lances == 0 and nivel.tainhas == 0, "janela expirou: lance não conta (lances=%d)" % nivel.lances)
	_checar(ok, "depois de 'perdeu a hora' o boto sinaliza de novo")
	await _apertar_lancar()
	ok = await _ate(func(): return nivel.lances == 1, 600)
	_checar(ok, "lance depois do sinal repetido conta")

	print("-- 3b. lance no mesmo quadro em que a janela fecha (estado simulado: _fechar_janela + lancar)")
	ok = await _ate(func(): return nivel.janela_aberta, 1500)
	nivel._fechar_janela()
	nivel.lancar()
	await _frames(10)
	_checar(nivel.lances == 1 and nivel.tainhas == 5, "lance após fechar a janela NÃO conta (lances=%d tainhas=%d)" % [nivel.lances, nivel.tainhas])
	for i in 2:
		ok = await _ate(func(): return nivel.janela_aberta or nivel.fase == nivel.Fase.PUXADO, 1800)
		if nivel.fase == nivel.Fase.PUXADO:
			break
		await _apertar_lancar()
		await _frames(30)
	ok = await _ate(func(): return nivel.fase == nivel.Fase.PUXADO, 1200)
	_checar(ok and nivel.lances == 3 and nivel._rede_jogador != null,
		"após o lance perdido, 3 lances válidos e puxão com rede (lances=%d rede=%s)" % [nivel.lances, str(nivel._rede_jogador != null)])
	await _ate(func(): return main.nivel_atual == CASTELINHO, 2400)

	print("-- 3c. morte no meio da Barra (GameState.matar_jogador)")
	await _carregar_barra(0.6)
	await _ate(func():
		Gui.avancar()
		return nivel.fase == nivel.Fase.ESPERA, 1500)
	ok = await _ate(func(): return nivel.janela_aberta, 1500)
	var antigo_id: int = nivel.get_instance_id()
	GS.matar_jogador("varredura")
	ok = await _ate(func(): return _fechar_morte(), 600)
	_checar(ok, "tela de morte aparece")
	ok = await _ate(func():
		return main.mundo.get_child_count() > 0 and main.mundo.get_child(0).get_instance_id() != antigo_id and main.nivel_atual == BARRA, 1500)
	_checar(ok, "morte recarrega a Barra")
	if ok:
		nivel = main.mundo.get_child(0)
		player = main.player
		nivel.espera_min = 0.3
		nivel.espera_max = 0.6
		_checar(GS.sala_atual == 36 and nivel.lances == 0 and nivel.tainhas == 0, "após morte: sala 36, placar zerado")
		_checar(GS.flag("viu_flashback_barra") == false, "após morte: flag da Barra continua falsa")
		ok = await _ate(func():
			Gui.avancar()
			return nivel.fase == nivel.Fase.ESPERA, 1500)
		_checar(ok, "após morte: intro e minigame de novo")
		await _frames(300)
		_checar(nivel.fase != nivel.Fase.FIM, "após morte: sem sair sozinha da Barra")


# ============================================================ 4. save e Continuar
func _save_continue() -> void:
	print("-- 4. save no meio da Barra + Continuar")
	GS.novo_jogo()
	GS.comecar_visita(2)
	GS.entrar_sala(GS.sala_global(10))
	_checar(GS.checkpoint_sala == 32, "checkpoint 32 (corredor, visita 2) gravado (cp=%d)" % GS.checkpoint_sala)
	await _carregar_barra(0.6)
	await _frames(20)
	_checar(GS.sala_atual == 36 and GS.checkpoint_sala == 32, "Barra (sala 36) não troca o checkpoint (cp=%d)" % GS.checkpoint_sala)
	GS.resetar_sessao()
	GS.carregar()
	var destino: Array = GS.preparar_continuar()
	_checar(destino[0] == CASTELINHO and destino[1] == "Checkpoint_32", "Continuar -> %s %s" % [str(destino[0]), str(destino[1])])
	await main.carregar_mundo(destino[0], destino[1])
	await _frames(20)
	player = main.player
	var alvo := Vector3(-15.5, 0.1, -21.8)
	_checar(player.global_position.distance_to(alvo) < 1.0, "Continuar cai no corredor (%s)" % str(player.global_position))
	_checar(GS.flag("viu_flashback_barra") == false, "flag da Barra segue falsa: o mural volta a funcionar")
