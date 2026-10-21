extends SceneTree
## Teste automático (headless) do minigame "Um, dois, três, pescador!" (Módulo 16) e da porta dele na Ponte à noite (Módulo 14).
## Segura/solta a ação (Input.action_press/release) e confere: vencer pelos 3 trechos (sem ser apanhado, soltando em "TRÊS"), a
## virada (pescadores olham todos para o mesmo lugar atrás do jogador, uma figura branca, a sandália), flags/pista/selo, o apanhado
## (a câmera volta ao começo do TRECHO atual), a contagem mais lenta no 3º apanhado seguido e que pular() não dá nada. Depois
## confere que a porta existe na Ponte, que o ponto de volta está livre e dentro da AREA e que o raio do jogador acerta a porta.
## Uso: godot --headless -s res://tests/mini_ponte_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

const MINI := "res://world/niveis/mini_ponte.tscn"
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
	Engine.time_scale = 5.0
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
	await _passada_apanhado_e_pula()
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
func _ate_falando(cond: Callable, max_frames := 9000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		if Gui.ocupado():
			Gui.avancar()
		await process_frame
	return cond.call()


## Fora do apanhado e de volta ao começo do trecho 2 (z=-8). (função própria: o lambda com a conta inline derrubava o Godot)
func _voltou_ao_comeco() -> bool:
	var fase: int = nivel.fase_atual()
	var z: float = nivel.posicao_z()
	return fase != 5 and absf(z + 8.0) < 0.01


## Segura a ação até a condição valer (e solta na hora: um quadro a mais segurando já poderia mudar o resultado).
func _segurar_ate(cond: Callable, max_frames := 9000) -> bool:
	Input.action_press("interagir")
	var ok: bool = false
	for i in max_frames:
		if cond.call() or not _vivo():
			ok = true
			break
		if Gui.ocupado():
			Gui.avancar()
		await process_frame
	Input.action_release("interagir")
	return ok and _vivo()


func _vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


func _carregar(trecho_ini := 1) -> void:
	await main.carregar_mundo(MINI, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.destino = DESTINO     # a Ponte não precisa carregar aqui
	nivel.trecho_inicial = trecho_ini     # (lido só depois da fala de abertura)
	await _frames(10)


## O jogador "esperto": segura enquanto a contagem ainda não chegou ao "TRÊS" e solta daí em diante.
func _esperto() -> void:
	if nivel.palavra < 3 and not nivel.pescadores_virados:
		Input.action_press("interagir")
	else:
		Input.action_release("interagir")


func _passada_vitoria() -> void:
	print("-- ponte: 3 trechos soltando em TRÊS, virada e vitória")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	GS.set_flag("mini_ponte_feito", false)
	GS.set_flag("pista_mini_ponte", false)
	GS.selos.erase("mini_ponte")
	await _carregar()
	_checar(nivel.id == "ponte" and nivel.quem_fala == "taina", "id e quem_fala")
	_checar(nivel.destino == DESTINO, "destino ajustável (o padrão é a cidade_ponte)")
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")
	_checar(not player.pode_mover, "jogador parado")
	_checar(nivel.get_node_or_null("Pescador7") != null and nivel.get_node_or_null("Pescador8") == null, "7 pescadores")
	_checar(nivel.get_node_or_null("FiguraBranca") == null, "a figura branca só aparece na virada")
	_checar(not nivel.get_node("Sandalia").visible, "a sandália só aparece na virada")
	var luzes := 0
	for n in nivel.find_children("*", "OmniLight3D", true, false):
		luzes += 1
	_checar(luzes == 1, "só uma luz de verdade na cena (%d)" % luzes)
	var ok: bool = await _ate_falando(func(): return nivel.trecho >= 1 and nivel.palavra >= 1)
	_checar(ok, "a fala passa e a 1ª contagem começa")
	var z0: float = nivel.posicao_z()

	# trecho por trecho, sem nunca ser apanhado
	var trechos_vistos := {}
	var viu_virados := false
	var z_antes: float = z0
	var andou_para_frente := true
	var frames := 0
	while not nivel.virada_ativa and frames < 20000 and _vivo():
		_esperto()
		trechos_vistos[int(nivel.trecho)] = true
		if nivel.pescadores_virados:
			viu_virados = true
		if nivel.posicao_z() > z_antes + 0.001 and nivel.apanhados_total == 0:
			andou_para_frente = false
		z_antes = nivel.posicao_z()
		if Gui.ocupado():
			Gui.avancar()
		await process_frame
		frames += 1
	Input.action_release("interagir")
	_checar(nivel.virada_ativa, "a virada começa depois do 3º poste")
	_checar(trechos_vistos.has(1) and trechos_vistos.has(2) and trechos_vistos.has(3), "passou pelos trechos 1, 2 e 3")
	_checar(viu_virados, "os pescadores se viraram para o jogador durante o jogo")
	_checar(nivel.apanhados_total == 0, "soltando em TRÊS ninguém apanha (%d)" % nivel.apanhados_total)
	_checar(andou_para_frente, "a câmera só andou para a frente (-z)")
	_checar(is_equal_approx(nivel.posicao_z(), -24.0), "chegou ao 3º poste (z=%.2f)" % nivel.posicao_z())
	_checar(nivel._lamp_mat[2].albedo_color.is_equal_approx(nivel.COR_LAMPADA), "o poste apagado acendeu ao chegar")
	# a virada: todos olham para o MESMO lugar (+z), não para o jogador
	ok = await _ate_falando(func(): return nivel.pescadores_para_tras, 6000)
	_checar(ok, "virada: os pescadores olham para trás do jogador")
	await _frames(40)
	var mesmos := true
	for i in 7:
		var y: float = nivel.get_node("Pescador%d" % (i + 1)).rotation.y
		if absf(y - TAU) > 0.05:
			mesmos = false
	_checar(mesmos, "todos com o mesmo yaw (+z)")
	_checar(not nivel.pescadores_virados, "...e não para o jogador")
	_checar(nivel.get_node("Sandalia").visible, "a sandália aparece no guarda-corpo")
	ok = await _ate_falando(func(): return nivel.get_node_or_null("FiguraBranca") != null, 6000)
	_checar(ok, "a figura branca aparece")
	if ok:
		var fig: Node3D = nivel.get_node("FiguraBranca")
		_checar(not fig.ativa, "a figura fica parada (ativa=false)")
		_checar(nivel.find_children("*", "FiguraBranca", true, false).size() == 1, "UMA figura só")
		_checar(fig.global_position.z > 0.0, "atrás do ponto de partida, bem longe do jogador (z=%.1f)" % fig.global_position.z)
	_checar(not GS.flag("mini_ponte_feito"), "ainda sem vitória durante a virada")
	ok = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 12000)
	if not ok:
		print("  (estado: terminado=%s cancelado=%s guia=%s nivel_atual=%s vivo=%s)" % [nivel.terminado, nivel.cancelado, Gui.ocupado(), main.nivel_atual, _vivo()])
	_checar(ok, "volta ao destino depois da fala final")
	await _frames(20)
	_checar(GS.flag("mini_ponte_feito") == true, "flag mini_ponte_feito")
	_checar(GS.flag("pista_mini_ponte") == true, "flag pista_mini_ponte")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1 (%d)" % int(GS.contadores.get("pistas_tito", 0)))
	_checar(GS.selos.has("mini_ponte"), "selo mini_ponte")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao sair")


func _passada_apanhado_e_pula() -> void:
	print("-- ponte: apanhado volta ao começo do trecho; 3 seguidos facilitam; pular não dá nada")
	GS.set_flag("mini_ponte_feito", false)
	GS.set_flag("pista_mini_ponte", false)
	GS.selos.erase("mini_ponte")
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _carregar(2)
	var ok: bool = await _ate_falando(func(): return nivel.palavra >= 1 and nivel.trecho == 2)
	_checar(ok, "começa direto no trecho 2 (o parâmetro do teste)")
	_checar(is_equal_approx(nivel.posicao_z(), -8.0), "o trecho 2 começa em z=-8 (%.2f)" % nivel.posicao_z())
	_checar(nivel.inicio_do_trecho() == -8.0, "inicio_do_trecho = -8")

	# segurando sempre: anda e é apanhado quando eles terminam de virar
	ok = await _segurar_ate(func(): return nivel.apanhados_total >= 1)
	_checar(ok and nivel.apanhados_total == 1, "segurar na hora em que eles viram = apanhado")
	_checar(nivel.palavra == 4 and nivel.pescadores_virados, "...e eles estavam olhando para o jogador")
	ok = await _ate_falando(_voltou_ao_comeco, 6000)
	_checar(ok, "a câmera voltou ao começo do trecho atual (z=%.2f)" % nivel.posicao_z())
	_checar(nivel.trecho == 2, "continua no trecho 2 (não perdeu trecho)")
	_checar(nivel.apanhados_seguidos == 1 and not nivel.lenta, "1 apanhado: ainda sem facilitar")
	# mais dois seguidos: a contagem fica mais lenta
	ok = await _ate_falando(func(): return nivel.fase_atual() == 0 or nivel.fase_atual() == 1, 6000)
	ok = await _segurar_ate(func(): return nivel.facilitadas >= 1, 20000)
	_checar(ok and nivel.apanhados_total == 3, "no 3º apanhado seguido... (apanhados=%d)" % nivel.apanhados_total)
	_checar(nivel.lenta and nivel.facilitadas == 1 and nivel.apanhados_seguidos == 0, "...a contagem fica mais lenta (lenta=true, seguidos zerado)")
	_checar(nivel.trecho == 2, "nunca perdeu mais que o começo do trecho")
	# soltando em TRÊS: a próxima contagem é lenta e ninguém apanha
	var antes: int = nivel.apanhados_total
	var k_ok := false
	var visto_lenta := 0.0
	for i in 9000:
		_esperto()
		if nivel.lenta and nivel.contagem_ultima > visto_lenta:
			visto_lenta = nivel.contagem_ultima
		if Gui.ocupado():
			Gui.avancar()
		if nivel.trecho == 3:
			break
		await process_frame
	Input.action_release("interagir")
	k_ok = visto_lenta > 1.0
	_checar(k_ok, "contagem lenta usada (%.2f s, mínimo normal seria 1.5)" % visto_lenta)
	_checar(nivel.apanhados_total == antes, "soltando a tempo não apanha")
	_checar(nivel.trecho == 3 and not nivel.lenta, "o trecho 2 acaba e começa o 3 (lenta volta ao normal)")
	_checar(nivel.apanhados_seguidos == 0, "um trecho limpo zera os apanhados seguidos")

	# pular: nada é ganho
	nivel.pular()
	ok = await _ate_falando(func(): return main.nivel_atual == DESTINO and not _vivo(), 9000)
	_checar(ok, "pular volta ao destino")
	await _frames(10)
	_checar(not GS.flag("mini_ponte_feito") and not GS.flag("pista_mini_ponte"), "pular não marca feito nem pista")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0, "pular não soma pistas_tito")
	_checar(not GS.selos.has("mini_ponte"), "pular não dá selo")
	_checar(GS.corruption_manual == -1.0, "corrupção manual liberada ao pular")


func _passada_porta() -> void:
	print("-- ponte: a porta na Ponte à noite (Módulo 14)")
	GS.novo_jogo()
	GS.jogando = true
	GS.visita = 3
	GS.entrar_sala(GS.sala_global(1))
	main.hud.visible = true
	await main.carregar_mundo(GS.CIDADE["ponte"]["cena"], "Spawn")
	await _frames(20)
	var c: Node = main.mundo.get_child(0)
	player = main.player
	root.get_node("/root/Guia").cancelar()
	var porta: Node3D = c.find_child("Mini_ponte", true, false)
	_checar(porta != null, "Interagivel Mini_ponte existe na Ponte")
	var volta: Node3D = c.find_child("Spawn_volta_mini_ponte", true, false)
	_checar(volta != null, "marcador Spawn_volta_mini_ponte")
	if porta == null or volta == null:
		return
	_checar(porta.get_node_or_null("VisualPonte") != null, "o visual do balde com lanterna existe")
	_checar(porta.get_node_or_null("Marca") != null and porta.get_node("Marca").visible, "o ! amarelo está à vista")
	_checar(porta.find_child("PARADO!", true, false) != null or porta.get_node("VisualPonte").get_child_count() > 5, "a plaquinha existe")
	# a porta fica perto do Spawn e visível de lá (poucos metros à frente, ao lado)
	var spawn: Node3D = c.get_node("Spawn")
	var d_spawn: float = Vector2(porta.global_position.x - spawn.global_position.x, porta.global_position.z - spawn.global_position.z).length()
	_checar(d_spawn < 8.0, "a porta fica a poucos metros do Spawn (%.1f m)" % d_spawn)
	var dx: float = porta.global_position.x - spawn.global_position.x
	var dz: float = spawn.global_position.z - porta.global_position.z      # para -z = à frente
	_checar(dz > 0.0 and absf(dx) < dz * 1.2, "está à frente do Spawn, dentro do campo de visão (dx=%.1f, dz=%.1f)" % [dx, dz])
	# orçamento da Ponte: nenhuma luz nova (1 Sol + 5 luzes)
	var luzes := 0
	for n in c.find_children("*", "OmniLight3D", true, false):
		luzes += 1
	_checar(luzes <= 5, "a porta não somou luz: %d OmniLight3D (máx. 5)" % luzes)
	# o ponto de volta fica DENTRO da AREA, longe das paredes/guarda-corpo, com a cápsula livre
	var a: Rect2 = c.area
	var vp: Vector3 = volta.global_position
	_checar(a.grow(-1.5).has_point(Vector2(vp.x, vp.z)), "o ponto de volta está dentro da AREA, a mais de 1,5 m da borda")
	_checar(absf(absf(vp.x) - 5.35) > 1.0 or absf(vp.z) > 45.0, "e longe do guarda-corpo")
	player.global_transform = volta.global_transform
	player.velocity = Vector3.ZERO
	await _frames(20)
	_checar(not player._sobrepoe_mundo(player.global_position), "a cápsula do jogador fica livre no ponto de volta")
	_checar(player.is_on_floor() and absf(player.global_position.y) < 0.2, "jogador no chão (y=%.2f)" % player.global_position.y)
	var dist: float = Vector2(player.global_position.x - porta.global_position.x, player.global_position.z - porta.global_position.z).length()
	_checar(dist > 1.2 and dist < 1.9, "o ponto de volta fica a ~1,5 m da porta (%.2f m)" % dist)
	# com o yaw do marcador e a cabeça nivelada, o raio já acerta a porta (sem precisar olhar para baixo)
	player.cabeca.rotation.x = 0.0
	await _frames(3)
	player.raio.force_raycast_update()
	_checar(player.raio.get_collider() == porta, "o raio nivelado, no yaw da volta, acerta o Mini_ponte (%s)" % str(player.raio.get_collider()))
	player.camera.look_at(porta.global_position, Vector3.UP)
	player.raio.force_raycast_update()
	_checar(player.raio.get_collider() == porta, "o raio do jogador olhando a porta acerta o Mini_ponte (%s)" % str(player.raio.get_collider()))
	var dist2: float = player.camera.global_position.distance_to(porta.global_position)
	_checar(dist2 < 2.4, "dentro do alcance de interação (%.2f m)" % dist2)
	# a cena do minigame carrega a partir da porta (entrar) sem erro
	_checar(load(c.get_script().resource_path) != null and ResourceLoader.exists("res://world/niveis/mini_ponte.tscn"), "a cena mini_ponte.tscn existe")
