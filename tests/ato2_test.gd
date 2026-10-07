extends SceneTree
## Teste automático do trecho Ato II da visita 3 (headless): Efeitos, Visor do Tempo, salas 55 a 60, regra da
## Figura Branca, morte/checkpoint e a volta ao Castelinho (sala 61).
## Uso: godot --headless -s res://tests/ato2_test.gd
## Atenção: não referencie classes do jogo (Visor, FiguraBranca...) por nome neste arquivo: o script de
## teste compila antes dos autoloads existirem. Use load("res://...") em tempo de execução.

var falhas := 0
var GS: Node
var Ef: Node
var Gui: Node
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0   # o teste anda ~40 s de jogo: acelera
	GS = root.get_node("/root/GameState")
	Ef = root.get_node("/root/Efeitos")
	Gui = root.get_node("/root/Guia")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.set_flag("tem_visor", true)
	await _carregar_ato2()

	await _teste_chao_e_marcadores()
	await _teste_efeitos()
	await _teste_visor()
	await _teste_caminhada()
	await _teste_perseguicao_e_morte()
	await _teste_fim_demo()
	await _teste_regra_figura()

	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Espera até `cond` ser verdadeira (até `max_frames` quadros de física). Devolve se foi.
func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _carregar_ato2() -> void:
	GS.comecar_visita(3)
	await main.carregar_mundo("res://world/niveis/ato2.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	nivel.destino = "res://world/niveis/teste.tscn"   # o Castelinho é de outro agente (e outro teste)
	player = main.player
	await _frames(10)


## Anda (frente) até `p` no plano xz. Falha se não chegar a tempo (preso).
func _ir_ate(p: Vector3, tol := 0.7, max_s := 30.0) -> bool:
	var chegou := false
	for i in int(max_s * 60.0):
		var d: Vector3 = p - player.global_position
		d.y = 0.0
		if d.length() <= tol:
			chegou = true
			break
		player.rotation.y = atan2(-d.x, -d.z)
		Input.action_press("frente")
		await physics_frame
	Input.action_release("frente")
	await physics_frame
	return chegou


# ============================================================================
func _teste_chao_e_marcadores() -> void:
	print("-- chão e marcadores")
	_checar(player.is_on_floor(), "jogador no chão do hall (y=%.2f)" % player.global_position.y)
	_checar(absf(player.global_position.y) < 0.05, "altura do chão = 0")
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")
	_checar(nivel.get_node_or_null("Checkpoint_55") != null, "marcador Checkpoint_55")
	_checar(GS.sala_atual == 55, "começa na sala 55 (sala %d)" % GS.sala_atual)
	_checar(nivel.has_method("ao_morrer") and nivel.has_method("iniciar"), "contrato iniciar/ao_morrer")
	_checar(abs(GS.corruption - 0.37) < 0.02, "corruption da sala 55 = %.2f" % GS.corruption)


func _teste_efeitos() -> void:
	print("-- efeitos")
	_checar(Ef.layer == 5 and Ef.layer < main.hud.layer, "camada de efeitos (5) abaixo do HUD (%d)" % main.hud.layer)
	GS.definir_corruption_manual(0.0)
	await _frames(120)
	_checar(not Ef._rect.visible, "corruption 0: pós-processamento desligado (imagem intacta)")
	GS.definir_corruption_manual(0.5)
	await _frames(60)
	_checar(Ef._rect.visible and absf(Ef.corrupcao_visual - 0.5) < 0.01, "corruption 0.5: efeito ligado e interpolado (%.2f)" % Ef.corrupcao_visual)
	GS.definir_corruption_manual(-1.0)
	await _frames(60)
	_checar(absf(Ef.corrupcao_visual - GS.corruption) < 0.01, "volta à curva por sala (%.2f)" % Ef.corrupcao_visual)
	Ef.pulso(1.0, 0.3)
	_checar(Ef._pulso > 0.9, "pulso dispara")
	await _frames(120)
	_checar(Ef._pulso < 0.01, "pulso decai")
	var m = Ef.material_psx(Color.WHITE)
	_checar(m is ShaderMaterial and m.get_shader_parameter("snap") > 100.0, "material_psx criado")


func _teste_visor() -> void:
	print("-- visor do tempo")
	var visor_gd = load("res://world/visor.gd")
	var v1 = visor_gd.instalar(nivel)
	var v2 = visor_gd.instalar(nivel)
	_checar(v1 == v2 and get_nodes_in_group("visor_tempo").size() == 1, "Visor.instalar é idempotente")
	GS.set_flag("visor_travado", false)
	Input.action_press("visor")
	var ok: bool = await _ate(func(): return GS.epoca == GS.Epoca.E1950, 120)
	_checar(ok, "segurar Q troca para 1950")
	_checar(Ef.visor_ativo, "moldura do visor ligada")
	_checar(Ef._lbl_ano.text == "1950", "legenda mostra o ano (%s)" % Ef._lbl_ano.text)
	_checar(not nivel._raiz_hall.visible, "em 1950 o hall some")
	await _frames(60)
	_checar(player.global_position.y < -0.015, "sem o piso do hall, o jogador pousa na areia (y=%.3f)" % player.global_position.y)
	Input.action_release("visor")
	ok = await _ate(func(): return GS.epoca == GS.Epoca.E2020, 240)
	_checar(ok, "soltar Q volta para 2020")
	_checar(not Ef.visor_ativo and nivel._raiz_hall.visible, "moldura desligada e hall de volta")
	await _frames(60)
	_checar(absf(player.global_position.y) < 0.05, "jogador volta ao piso (y=%.3f)" % player.global_position.y)
	# visor travado: a época não volta
	GS.set_flag("visor_travado", true)
	Input.action_press("visor")
	await _ate(func(): return GS.epoca == GS.Epoca.E1950, 240)
	await _frames(40)
	Input.action_release("visor")
	await _frames(80)
	_checar(GS.epoca == GS.Epoca.E1950 and not Ef.visor_ativo, "visor_travado: a época não volta ao soltar Q")
	nivel._resetar_estado()
	player.global_position = nivel.get_node("Spawn").global_position
	await _frames(30)
	_checar(GS.epoca == GS.Epoca.E2020 and not GS.flag("visor_travado"), "reset restaura época e flag")


func _teste_caminhada() -> void:
	print("-- caminhada 55 -> 59")
	_checar(GS.sala_atual == 55, "sala 55")
	var ok: bool = await _ir_ate(Vector3(0, 0, -6.0))
	_checar(ok and nivel._porta_hall_aberta, "a porta do hall abre quando o jogador se aproxima")
	ok = await _ir_ate(Vector3(0, 0, -19.0))
	_checar(ok, "atravessa a porta do hall")
	_checar(GS.sala_atual == 56, "sala 56 (sala %d)" % GS.sala_atual)
	_checar(GS.epoca == GS.Epoca.E1950 and GS.flag("visor_travado"), "a porta abre para 1950 e o visor trava")
	_checar(not nivel._raiz_hall.visible, "o hall desapareceu atrás do jogador")
	var f = nivel.figura
	_checar(not f.ativa and f.visible, "a figura espera parada na duna")
	_checar(f.global_position.distance_to(player.global_position) > 25.0, "figura longe, numa duna (%.0f m)" % f.global_position.distance_to(player.global_position))
	# cercar a figura da duna: ela some e reaparece mais longe
	var pos_duna: Vector3 = f.global_position
	player.global_position = Vector3(pos_duna.x, pos_duna.y + 1.0, pos_duna.z + 7.0)
	player.rotation.y = 0.0
	player.cabeca.rotation.x = 0.0
	await _frames(30)
	for i in 200:
		player.global_position.z -= 0.04
		await physics_frame
		if f.sumida:
			break
	_checar(f.sumida, "56: a figura da duna some quando o jogador a cerca olhando")
	await _ate(func(): return not f.sumida, 300)
	_checar(f.visible and f.global_position.distance_to(player.global_position) > 6.0, "56: reaparece mais longe (%.0f m)" % f.global_position.distance_to(player.global_position))
	player.global_position = Vector3(0, 0.3, -40.0)
	player.rotation.y = 0.0
	await _frames(30)
	ok = await _ir_ate(Vector3(0, 0, -71.5), 0.7, 40.0)
	_checar(ok, "caminha pelas dunas até o núcleo de 1950")
	ok = await _ir_ate(Vector3(0, 0, -74.0))
	_checar(ok and GS.sala_atual == 57, "entra na casa de 1950: sala 57 (sala %d)" % GS.sala_atual)
	_checar(f.ativa and f.global_position.distance_to(Vector3(-6, 0, -75)) < 1.5, "a Figura Branca ativa na casa")
	f.ativa = false   # só para atravessar a casa sem ser pego
	ok = await _ir_ate(Vector3(-2.0, 0, -76.4))
	_checar(ok, "cruza a casa até a porta dos fundos")
	ok = await _ir_ate(Vector3(-2.0, 0, -80.0))
	_checar(ok and GS.sala_atual == 58, "entra na arcada: sala 58 (sala %d)" % GS.sala_atual)
	ok = await _ir_ate(Vector3(-1.8, 0, -92.0))
	_checar(ok and nivel._chase_ativo, "a perseguição começa dentro da arcada")
	_checar(f.velocidade > 3.0 and f.ativa and f.visible, "figura atrás do jogador (vel %.1f)" % f.velocidade)
	f.ativa = false
	var zf: float = f.global_position.z
	_checar(zf > player.global_position.z + 8.0, "figura nasce atrás (%.0f m)" % (zf - player.global_position.z))
	ok = await _ir_ate(Vector3(-1.8, 0, -117.0), 0.7, 40.0)
	_checar(ok and GS.sala_atual == 59, "chega na sala 59 (sala %d)" % GS.sala_atual)
	player.rotation.y = 0.0
	player.cabeca.rotation.x = 0.0
	await _ir_ate(Vector3(-1.8, 0, -119.4), 0.3)
	player.rotation.y = 0.0
	await _frames(10)
	_checar(player._alvo == nivel._interagivel_final, "o raio do jogador acha a porta (Interagivel)")
	_checar(abs(GS.corruption - 0.40) < 0.02, "corruption da sala 59 = %.2f" % GS.corruption)


func _teste_perseguicao_e_morte() -> void:
	print("-- perseguição e morte")
	var f = nivel.figura
	var mortes_antes: int = GS.contadores.get("mortes", 0)
	var causa := [""]
	GS.jogador_morreu.connect(func(c): causa[0] = c)
	# jogador de costas, figura 5 m atrás no corredor
	player.global_position = Vector3(-1.8, 0.1, -100.0)
	player.rotation.y = 0.0   # olhando para frente (-z); a figura vem de +z
	nivel._chase_ativo = true
	f.reiniciar(Vector3(-1.8, 0.05, -95.0), true)
	f.velocidade = 4.0
	var ok: bool = await _ate(func(): return f.matou, 600)
	_checar(ok and causa[0] == "figura_branca", "encostou sem ser olhada: matar_jogador('figura_branca')")
	_checar(GS.contadores.get("mortes", 0) == mortes_antes + 1, "contador de mortes subiu")
	# ao_morrer: fade vermelho, (tela de morte), volta ao Checkpoint_55
	ok = await _ate(func(): return nivel._morrendo, 60)
	_checar(ok, "ao_morrer do nível foi chamado pelo Main")
	var viu_morte := [false]
	ok = await _ate(func():
		for n in root.get_children():
			if n.has_method("continuar") and n.has_signal("terminou"):
				viu_morte[0] = true
		_destravar_ui()
		return not nivel._morrendo, 1500)
	_checar(viu_morte[0], "a tela de morte da UI (Morte) apareceu")
	_checar(ok, "sequência de morte terminou")
	var cp: Vector3 = nivel.get_node("Checkpoint_55").global_position
	_checar(player.global_position.distance_to(cp) < 0.6, "volta ao Checkpoint_55 (%s)" % str(player.global_position))
	_checar(GS.sala_atual == 55 and GS.epoca == GS.Epoca.E2020, "sala 55 e época 2020 restauradas")
	_checar(player.pode_mover and not f.matou and not f.ativa, "jogador livre, figura reiniciada")
	_checar(is_equal_approx(Transicao_alfa(), 0.0), "tela clareou depois da morte")


func Transicao_alfa() -> float:
	var t: Node = root.get_node("/root/Transicao")
	return t._rect.color.a


## Se a tela de morte da UI (Morte) estiver esperando o jogador, continua por ele.
func _destravar_ui() -> void:
	Gui.avancar()
	for n in root.get_children():
		if n.has_method("continuar") and n.has_signal("terminou"):
			n.continuar()
			return


func _teste_fim_demo() -> void:
	print("-- sala 60: a porta devolve o jogador ao Castelinho (sala 61)")
	player.global_position = Vector3(-1.8, 0.1, -119.4)
	player.rotation.y = 0.0
	await _frames(10)
	GS.set_flag("visor_travado", true)
	GS.trocar_epoca(GS.Epoca.E1950)
	_checar(nivel.spawn_destino == "Spawn_volta_ato2", "a volta ao Castelinho é em Spawn_volta_ato2")
	nivel._abrir_porta_final(player)
	await _frames(5)
	_checar(GS.sala_atual == 60, "abrir a porta entra na sala 60 (sala %d)" % GS.sala_atual)
	var ok: bool = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == "res://world/niveis/teste.tscn", 3000)
	_checar(ok, "depois da tela preta e da voz corrompida, troca para o destino (Castelinho, aqui o nível de teste)")
	await _frames(30)
	_checar(GS.sala_atual == 61, "volta ao Castelinho na sala 61 (sala %d)" % GS.sala_atual)
	_checar(GS.flag("v3_ato2_feito"), "flag v3_ato2_feito ligada na volta")
	_checar(not GS.flag("visor_travado") and GS.epoca == GS.Epoca.E2020, "época e Visor liberados na volta")
	load("res://ui/flash.gd").resetar_ui()


# ============================================================================ regra da figura
func _teste_regra_figura() -> void:
	print("-- regra da Figura Branca (arena plana)")
	GS.jogador_morreu.disconnect(main._on_morte)
	await main.carregar_mundo("res://world/niveis/teste.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(10)
	player.global_position = Vector3(0, 0.1, 2.0)
	player.rotation.y = 0.0   # olhando para -z
	var f = load("res://creatures/figura_branca.gd").new()
	f.velocidade = 2.2
	nivel.add_child(f)
	f.global_position = Vector3(0, 0.1, -10.0)
	await _frames(20)
	var p0: Vector3 = f.global_position

	# olhando: não se move
	await _frames(90)
	_checar(f.olhada, "figura está sendo olhada")
	_checar(f.global_position.distance_to(p0) < 0.05, "OLHANDO: a figura não se move (%.3f m)" % f.global_position.distance_to(p0))

	# de costas: se aproxima
	player.rotation.y = PI
	var d0: float = f.global_position.distance_to(player.global_position)
	await _frames(60)
	var d1: float = f.global_position.distance_to(player.global_position)
	_checar(not f.olhada, "figura não está sendo olhada")
	_checar(d0 - d1 > 1.5, "DE COSTAS: a figura se aproxima (%.1f m -> %.1f m)" % [d0, d1])

	# linha de visão bloqueada por uma parede: conta como não olhada
	f.global_position = Vector3(0, 0.1, -10.0)
	f.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	var parede := Construtor.caixa(nivel, Vector3(6, 3, 0.3), Vector3(0, 1.5, -6.0), Construtor.material(Color.GRAY), true)
	await _frames(10)
	_checar(not f.olhada, "parede entre os dois: não conta como olhada")
	parede.queue_free()
	await _frames(5)

	# apagão: no escuro ela é "não olhada" e o modelo some
	f.global_position = Vector3(0, 0.1, -10.0)
	await _frames(5)
	_checar(f.olhada, "voltou a ser olhada sem a parede")
	f.escuro = true
	await _frames(5)
	_checar(not f.olhada and not f._modelo.visible, "escuro: não é vista e o modelo some")
	f.escuro = false
	await _frames(5)

	# cercar: o jogador se aproxima olhando -> ela some e reaparece no ponto configurado
	f.global_position = Vector3(0, 0.1, -9.0)
	f.velocity = Vector3.ZERO
	f.tempo_reaparecer = 0.4
	f.pontos_reaparecer = [Vector3(0, 0.1, -40.0)]
	player.global_position = Vector3(0, 0.1, -3.0)
	player.rotation.y = 0.0
	var sumiu_em := [Vector3.ZERO]
	f.sumiu.connect(func(onde): sumiu_em[0] = onde)
	for i in 120:
		player.global_position.z -= 0.05
		await physics_frame
		if f.sumida:
			break
	_checar(f.sumida and not f.visible, "APROXIMANDO OLHANDO: a figura some")
	_checar(sumiu_em[0].distance_to(player.global_position) < 2.8, "sumiu a menos de ~2,5 m (%.2f)" % sumiu_em[0].distance_to(player.global_position))
	await _ate(func(): return not f.sumida, 240)
	_checar(f.visible and f.global_position.distance_to(Vector3(0, 0.1, -40.0)) < 0.5, "reaparece no ponto configurado (%s)" % str(f.global_position))

	# reaparecimento padrão: mais longe na mesma direção
	f.pontos_reaparecer = []
	f.distancia_reaparecer = 12.0
	f.global_position = Vector3(0, 0.1, -17.0)
	f.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.1, -15.0)
	player.rotation.y = 0.0
	await _frames(5)
	await _ate(func(): return f.sumida, 60)
	await _ate(func(): return not f.sumida, 240)
	var dist_nova: float = f.global_position.distance_to(player.global_position)
	_checar(dist_nova > 8.0, "reaparece mais longe (%.1f m)" % dist_nova)

	# estática (sala 56): parada, mas some se cercada
	f.pontos_reaparecer = [Vector3(0, 0.1, -45.0)]
	f.ativa = false
	f.global_position = Vector3(0, 0.1, -25.0)
	player.global_position = Vector3(0, 0.1, -19.0)
	player.rotation.y = PI
	await _frames(10)
	var pz: Vector3 = f.global_position
	await _frames(60)
	_checar(f.global_position.distance_to(pz) < 0.05 and not f.olhada, "ativa=false: parada mesmo sem ser olhada")
	f.queue_free()
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
