extends SceneTree
## Varredura automática do PORÃO (QA headless). Procura: chão furado e paredes que faltam, quedas, a caminhada
## contínua 81 -> 99 -> Braço Morto, bifurcação, cisterna (sala 98) e a ponte, Visor na água, mortes por trecho,
## falas/eventos e o "Continuar" em cada checkpoint.
## Uso: timeout 300 godot --headless -s res://tests/varredura/porao.gd
## Saída: "ACHADO <gravidade> <id> ..." = possível bug (conferir o código); "  ok" = verificado.

const PORAO := "res://world/niveis/porao.tscn"
const BRACO := "res://world/niveis/braco_morto.tscn"
const SEMENTES := [4242, 7, 31337]

var GS: Node
var main: Node
var nivel: Node
var player: Node
var achados := 0
var oks := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.set_flag("tem_visor", true)
	GS.set_flag("porao_semente", SEMENTES[0])
	GS.comecar_visita(5)
	await _secao_chao_e_paredes()
	# PORAO_SEM_CAMINHADA=1 pula a caminhada contínua (ela pode derrubar o motor, ver porao_diag8.gd)
	if OS.get_environment("PORAO_SEM_CAMINHADA") == "":
		await _secao_caminhada()
	await _secao_bifurcacao()
	await _secao_cisterna()
	await _secao_visor_agua()
	await _secao_mortes()
	await _secao_falas()
	await _secao_checkpoints()
	await _secao_extras()
	Engine.time_scale = 1.0
	print("RESUMO: %d achado(s), %d ok" % [achados, oks])
	quit(0)


# ============================================================================ utilidades
func _achado(id: String, grav: String, msg: String) -> void:
	achados += 1
	print("ACHADO %s [%s] %s" % [grav, id, msg])


func _ok(msg: String) -> void:
	oks += 1
	print("  ok   " + msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _atualizar_refs() -> void:
	nivel = main.mundo.get_child(0)
	player = main.player


func _carregar_porao(spawn := "Spawn") -> void:
	await main.carregar_mundo(PORAO, spawn)
	_atualizar_refs()
	await _frames(10)


## Jogador abaixo do piso normal da sala atual (a escada desce 3,2 m): caiu.
func _caiu() -> bool:
	if nivel == null or not is_instance_valid(nivel) or not is_instance_valid(player):
		return false
	var c = nivel.salas.get(nivel.idx_atual, null)
	if c == null or not is_instance_valid(c.raiz):
		return false
	return player.global_position.y < c.raiz.global_position.y + minf(0.0, c.dy) - 1.0


## Põe o jogador num ponto local da sala, virado para `giro` (0 = para -Z, -PI/2 = para +X).
func _posicionar_local(c, p: Vector3, giro: float) -> void:
	player.global_position = c.raiz.to_global(p)
	player.rotation = Vector3(0.0, c.raiz.global_rotation.y + giro, 0.0)
	player.velocity = Vector3.ZERO
	await _frames(4)


## Anda para a frente por `n` quadros (com time_scale 4 cada quadro é 0,2 m).
func _andar_q(n: int) -> void:
	Input.action_press("frente")
	await _frames(n)
	Input.action_release("frente")


func _destravar_ui() -> void:
	root.get_node("/root/Guia").avancar()
	for n in root.get_children():
		if n.has_method("continuar") and n.has_signal("terminou"):
			n.continuar()
			return


func _esperar_morte() -> bool:
	return await _ate(func():
		_destravar_ui()
		return not nivel.morrendo, 3000)


func _interativo(c, inicio: String):
	for it in c.interativos:
		if is_instance_valid(it) and str(it.texto_interacao).begins_with(inicio):
			return it
	return null


# ============================================================================ 1. chão e paredes (varredura estática)
## Raio para baixo em grade sobre cada sala (buracos no chão) e raio horizontal de cada lado (paredes que faltam).
func _varrer_sala(i: int) -> Array:
	var c = nivel.salas[i]
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var w: float = c.w
	var L: float = c.L
	var furos: Array = []
	var x := -w * 0.5 + 0.25
	while x <= w * 0.5 - 0.25:
		var z := -L + 0.25
		while z <= -0.25:
			var y0: float = c.piso_fn.call(z)
			var q := PhysicsRayQueryParameters3D.create(c.raiz.to_global(Vector3(x, y0 + 1.2, z)), c.raiz.to_global(Vector3(x, y0 - 2.5, z)), 1)
			# o poço da cisterna é barrado pelo meio-fio: só conta o que dá para pisar
			if space.intersect_ray(q).is_empty() and not (c.tipo == "cisterna" and absf(x) > 1.4):
				furos.append("(%.1f,%.1f)" % [x, z])
			z += 0.5
		x += 0.5
	var paredes: Array = []
	for zf in [0.2, 0.5, 0.8]:
		var zc: float = -L * float(zf)
		var y1: float = float(c.piso_fn.call(zc)) + 1.0
		for lado in [-1.0, 1.0]:
			var q2 := PhysicsRayQueryParameters3D.create(c.raiz.to_global(Vector3(0.0, y1, zc)), c.raiz.to_global(Vector3(lado * (w * 0.5 + 3.0), y1, zc)), 1)
			var hit: Dictionary = space.intersect_ray(q2)
			var bom := false
			if not hit.is_empty():
				var pl: Vector3 = c.raiz.to_local(hit["position"])
				bom = absf(pl.x) >= w * 0.5 - 0.05 and absf(pl.x) <= w * 0.5 + 1.3
			if not bom:
				paredes.append("z=%.1f lado=%d" % [zc, int(lado)])
	return [furos, paredes]


func _secao_chao_e_paredes() -> void:
	print("-- 1. chão e paredes das 19 salas, três sementes (varredura por raio)")
	var total_furos := 0
	var total_paredes := 0
	for s in SEMENTES:
		GS.set_flag("porao_semente", s)
		await _carregar_porao()
		nivel.ameacas_ligadas = false
		var tipos := []
		for i in nivel.N:
			nivel.ir_para_sala(i)
			await _frames(4)
			var c = nivel.salas[i]
			var r: Array = _varrer_sala(i)
			tipos.append(c.tipo)
			total_furos += r[0].size()
			total_paredes += r[1].size()
			if r[0].size() > 0:
				_achado("buraco", "A", "semente %d sala %d (%s): %d pontos sem chão, ex %s" % [s, 81 + i, c.tipo, r[0].size(), str(r[0].slice(0, 4))])
			if r[1].size() > 0:
				print("   info semente %d sala %d (%s): raio não acha parede em %s (pilar, móvel ou arcada?)" % [s, 81 + i, c.tipo, str(r[1])])
		print("   semente %d: %s" % [s, str(tipos)])
	if total_furos == 0:
		_ok("nenhum buraco no chão nas 3 sementes (19 salas)")
	if total_paredes == 0:
		_ok("paredes achadas por raio em todas as salas (exceto as aberturas previstas)")


# ============================================================================ 2. caminhada contínua 81 -> 99 -> Braço Morto
func _secao_caminhada() -> void:
	print("-- 2. caminhada contínua da sala 81 até o Braço Morto (sem teletransporte; o disco é pego no quarto)")
	GS.set_flag("porao_semente", SEMENTES[0])
	GS.discos.clear()
	GS.disco_atual = -1
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	var vistas: Array = []
	var pos_ref: Vector3 = player.global_position
	var f := 0
	var disco_feito := false
	var saiu := false
	var preso := false
	var caiu := false
	var tentativas := 0
	var desvio := 0.0          # desvio da mira (rad) quando o jogador travou
	var desvio_t := 0
	var idx_ref := -2
	Input.action_press("frente")
	while f < 12000:
		await physics_frame
		f += 1
		if not is_instance_valid(nivel) or main.nivel_atual != PORAO:
			saiu = main.nivel_atual == BRACO
			break
		var idx: int = nivel.idx_atual
		if idx >= 0 and (vistas.is_empty() or vistas[-1] != idx):
			vistas.append(idx)
		if idx == 14 and not disco_feito:
			disco_feito = true
			Input.action_release("frente")
			await _frames(5)
			var c14 = nivel.salas[14]
			var di = c14.raiz.get_node_or_null("InteragivelDisco")
			if di:
				di.interagir(player)
			await _ate(func(): return nivel.salas.has(15) and nivel.salas[15].porta_aberta, 300)
			Input.action_press("frente")
		# guia de rumo: mira o centro da saída da sala atual (a passagem fica no meio da parede do fundo)
		if idx >= 0 and nivel.salas.has(idx):
			var cl = nivel.salas[idx]
			var alvo: Vector3 = cl.raiz.to_global(Vector3(0.0, float(cl.piso_fn.call(-cl.L)) + 0.1, -cl.L - 2.5))
			var dv: Vector3 = alvo - player.global_position
			dv.y = 0.0
			if dv.length() > 0.05:
				player.rotation.y = atan2(-dv.x, -dv.z) + desvio
		if _caiu():
			caiu = true
			_achado("queda", "A", "caiu na sala %d (y=%.2f) andando em frente" % [81 + idx, player.global_position.y])
			break
		if desvio_t > 0:
			desvio_t -= 1
			if desvio_t == 0:
				desvio = 0.0
		if f % 40 == 0:
			# progresso = afastar-se 1 m do ponto de referência (oscilar no lugar não conta)
			if player.global_position.distance_to(pos_ref) < 1.0 and idx == idx_ref:
				tentativas += 1
				if tentativas > 6:
					preso = true
					_achado("preso", "A", "travado na sala %d (idx %d) mesmo desviando da mira: local %s" % [81 + idx, idx, str(nivel.salas[idx].raiz.to_local(player.global_position)) if idx >= 0 else "?"])
					break
				desvio = 1.2 if tentativas % 2 == 1 else -1.2
				desvio_t = 60
			else:
				tentativas = 0
				pos_ref = player.global_position
			idx_ref = idx
	Input.action_release("frente")
	var em_ordem := true
	for k in vistas.size():
		if vistas[k] != k:
			em_ordem = false
	if not caiu and not preso:
		if vistas.size() == 19 and em_ordem:
			_ok("as 19 salas entram em ordem, andando (81..99)")
		else:
			_achado("ordem", "M", "salas vistas %s" % str(vistas))
	if saiu:
		_ok("passou a sala 99 e foi para o Braço Morto andando")
	elif not caiu and not preso:
		_achado("saida", "A", "não chegou ao Braço Morto (último idx %s, nivel %s)" % [str(vistas.back() if vistas.size() > 0 else -1), str(main.nivel_atual)])
	if saiu:
		await _morte_braco()


func _morte_braco() -> void:
	await _frames(90)
	if main.nivel_atual != BRACO:
		return
	_atualizar_refs()
	var m0: int = GS.contadores.get("mortes", 0)
	GS.matar_jogador("teste_braco")
	await _ate(func():
		_destravar_ui()
		return main.nivel_atual == BRACO and not main._carregando and GS.contadores.get("mortes", 0) == m0 + 1, 3000)
	await _frames(60)
	_atualizar_refs()
	if player.is_on_floor():
		_ok("morte no Braço Morto: volta com o jogador no chão")
	else:
		_achado("morte_braco", "M", "após morrer no Braço Morto o jogador não está no chão (y=%.2f)" % player.global_position.y)


# ============================================================================ 3. bifurcação (lado +1 e lado -1)
func _secao_bifurcacao() -> void:
	print("-- 3. bifurcação (sala da voz): entrada, parede do fundo e fim do corredor lateral, dois lados")
	for sem in [4242, 7]:
		GS.set_flag("porao_semente", sem)
		await _carregar_porao()
		nivel.ameacas_ligadas = false
		var idx := -1
		for d in nivel.plano:
			if d["tipo"] == "bifurcacao":
				idx = d["idx"]
				break
		nivel.ir_para_sala(idx)
		await _frames(5)
		var c = nivel.salas[idx]
		var lado: int = int(c.pontos["lado_armadilha"])
		var zc := -8.2
		var tag := "semente %d lado %d" % [sem, lado]
		var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
		# a) a abertura da parede deixa entrar no corredor (andando do centro da sala)
		await _posicionar_local(c, Vector3(0.0, 0.1, zc), -PI * 0.5 * lado)
		await _andar_q(30)
		var pl: Vector3 = c.raiz.to_local(player.global_position)
		if absf(pl.x) > 5.0 and not _caiu():
			_ok("%s: a abertura deixa entrar no corredor lateral (x=%.2f)" % [tag, pl.x])
		else:
			_achado("entrada_bifurcacao", "A", "%s: não consegue entrar no corredor lateral (x=%.2f, y=%.2f)" % [tag, pl.x, player.global_position.y])
		# b) parede do fundo do corredor (z = zc - 1,1): tem que bater um raio
		var q := PhysicsRayQueryParameters3D.create(c.raiz.to_global(Vector3(lado * 5.8, 1.0, zc)), c.raiz.to_global(Vector3(lado * 5.8, 1.0, zc - 3.0)), 1)
		var hit: Dictionary = space.intersect_ray(q)
		var fundo_ok := false
		if not hit.is_empty():
			var ph: Vector3 = c.raiz.to_local(hit["position"])
			fundo_ok = absf(ph.z - (zc - 1.1)) < 0.3
		if fundo_ok:
			_ok("%s: parede do fundo do corredor tem colisão" % tag)
		else:
			_achado("corredor_parede", "A", "%s: a parede do fundo do corredor (z=%.1f) NÃO tem colisão (raio sem acerto)" % [tag, zc - 1.1])
		# c) andando de verdade para o fundo: não pode atravessar
		await _posicionar_local(c, Vector3(lado * 5.6, 0.1, zc + 0.2), 0.0)
		await _andar_q(20)
		if _caiu():
			_achado("corredor_queda", "A", "%s: anda do patamar para o fundo (-Z) e cai (y=%.2f): sem parede, sem morte" % [tag, player.global_position.y])
		else:
			_ok("%s: andando para o fundo para na parede (z=%.2f)" % [tag, c.raiz.to_local(player.global_position).z])
		# d) fim do corredor (x = lado*10,1)
		var q2 := PhysicsRayQueryParameters3D.create(c.raiz.to_global(Vector3(lado * 7.0, 1.0, zc)), c.raiz.to_global(Vector3(lado * 11.5, 1.0, zc)), 1)
		var hit2: Dictionary = space.intersect_ray(q2)
		var fim_ok := false
		if not hit2.is_empty():
			var p2: Vector3 = c.raiz.to_local(hit2["position"])
			fim_ok = absf(p2.x - lado * 10.1) < 0.3
		if fim_ok:
			_ok("%s: fim do corredor lateral tem parede" % tag)
		else:
			_achado("corredor_fim", "M", "%s: fim do corredor lateral (x=%.1f) sem colisão (o afogamento mata antes, mas o vazio é real)" % [tag, lado * 10.1])


# ============================================================================ 4. cisterna (sala 98): vão, ponte e Visor
func _secao_cisterna() -> void:
	print("-- 4. cisterna (sala 98): meio-fio, vão, passarela com e sem o Visor")
	GS.trocar_epoca(GS.Epoca.E2020)
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	nivel.ir_para_sala(17)
	await _frames(5)
	var c = nivel.salas[17]
	var y_ref: float = c.raiz.global_position.y
	# A) sem o Visor, meio-fio inteiro (z = -3,5): o jogador tem que parar na borda
	await _posicionar_local(c, Vector3(0.6, 0.1, -3.5), -PI * 0.5)
	await _andar_q(40)
	if _caiu():
		_achado("meio_fio", "A", "sem Visor, em z=-3,5 (meio-fio inteiro) o jogador cai no poço")
	elif player.global_position.x - c.raiz.global_position.x > 1.8:
		_achado("meio_fio", "M", "sem Visor, o meio-fio em z=-3,5 não barra (x=%.2f)" % c.raiz.to_local(player.global_position).x)
	else:
		_ok("sem Visor, o meio-fio em z=-3,5 barra o jogador (x=%.2f)" % c.raiz.to_local(player.global_position).x)
	# B) sem o Visor, no vão do meio-fio (z = -5,5): o jogador cai
	await _posicionar_local(c, Vector3(0.6, 0.1, -5.5), -PI * 0.5)
	var m0: int = GS.contadores.get("mortes", 0)
	await _andar_q(40)
	if _caiu():
		var y1: float = player.global_position.y
		await _frames(120)
		var mais: bool = player.global_position.y < y1 - 0.5
		var mortes_extra: int = GS.contadores.get("mortes", 0) - m0
		_achado("vao_poco", "A", "sem Visor, andando pelo vão do meio-fio (z=-5,5) o jogador cai no poço (y=%.2f, continua caindo=%s, mortes novas=%d): nada o mata nem o devolve" % [player.global_position.y, str(mais), mortes_extra])
	else:
		_ok("sem Visor, o vão do meio-fio não deixa cair")
	# C) sem o Visor, a passarela (ColisaoPonte) não pode ser sólida: cai do alto sobre x = 2,0
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	nivel.ir_para_sala(17)
	await _frames(5)
	c = nivel.salas[17]
	var ponte: Node3D = c.raiz.get_node_or_null("PasserelaSemData")
	if ponte and not ponte.visible:
		_ok("sem Visor a passarela fica invisível")
	await _posicionar_local(c, Vector3(2.0, 0.8, -5.5), 0.0)
	await _frames(70)
	if player.global_position.y > y_ref - 0.5:
		_achado("ponte_fantasma", "M", "sem Visor a passarela invisível ainda é sólida: o jogador para em y=%.2f sobre x=2,0" % player.global_position.y)
	else:
		_ok("sem Visor a passarela não tem colisão (cai em y=%.2f)" % player.global_position.y)
	# D) com o disco sem data a passarela existe e dá para atravessar até a plataforma (x >= 2,8)
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	nivel.ir_para_sala(17)
	await _frames(5)
	c = nivel.salas[17]
	ponte = c.raiz.get_node_or_null("PasserelaSemData")
	if ponte == null or not ponte.visible:
		_achado("ponte_semdata", "A", "com o disco sem data a passarela não aparece")
	await _posicionar_local(c, Vector3(0.6, 0.1, -5.5), -PI * 0.5)
	await _andar_q(25)
	var lx: float = c.raiz.to_local(player.global_position).x
	if _caiu() or lx < 3.0:
		_achado("ponte_semdata", "A", "com o disco sem data não atravessa a passarela (x=%.2f, y=%.2f)" % [lx, player.global_position.y])
	else:
		_ok("com o disco sem data atravessa a passarela até a plataforma (x=%.2f)" % lx)
	GS.trocar_epoca(GS.Epoca.E2020)


# ============================================================================ 5. Visor e água
## Anda `n` quadros para a frente e devolve a distância horizontal percorrida.
func _medir_q(n: int) -> float:
	var p0: Vector3 = player.global_position
	Input.action_press("frente")
	await _frames(n)
	Input.action_release("frente")
	return Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()


func _secao_visor_agua() -> void:
	print("-- 5. água nível 3 (sala 96): lentidão, Visor trocando de época, passos sem afundar")
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	GS.trocar_epoca(GS.Epoca.E2020)
	nivel.ir_para_sala(15)
	await _frames(5)
	# ir_para_sala com salto de nível faz a água SUBIR em 6 s (no jogo, isso não acontece aqui): fixa o nível 3
	if nivel._tween_agua and nivel._tween_agua.is_valid():
		nivel._tween_agua.kill()
	nivel.nivel_agua = 3
	nivel.prof = nivel.PROF_AGUA[3]
	var c = nivel.salas[15]
	await _posicionar_local(c, Vector3(0.0, 0.1, -3.0), 0.0)
	var d_agua: float = await _medir_q(12)
	var y_agua: float = player.global_position.y
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	await _posicionar_local(c, Vector3(0.0, 0.1, -3.0), 0.0)
	var d_seca: float = await _medir_q(12)
	print("   %d quadros: com água (E2020) %.2f m, sem a água (ESEMDATA) %.2f m" % [12, d_agua, d_seca])
	if d_agua < d_seca * 0.8:
		_ok("na água (nível 3) anda mais devagar que sem a água (%.2f vs %.2f m)" % [d_agua, d_seca])
	else:
		_achado("agua_lenta", "M", "na água nível 3 o passo não diminui (%.2f vs %.2f m)" % [d_agua, d_seca])
	if y_agua < c.raiz.global_position.y - 0.2:
		_achado("afunda", "A", "na água o jogador afundou (y=%.2f)" % y_agua)
	# trocar a época com o jogador dentro d'água: não pode prender nem afundar
	for ep in [GS.Epoca.E1967, GS.Epoca.E2020, GS.Epoca.ESEMDATA, GS.Epoca.E2020, GS.Epoca.E1967]:
		GS.trocar_epoca(ep)
		await _posicionar_local(c, Vector3(0.0, 0.1, -3.0), 0.0)
		var passo: float = await _medir_q(10)
		var y: float = player.global_position.y
		if absf(y - c.raiz.global_position.y) > 0.25 or passo < 0.2:
			_achado("visor_agua", "A", "época %d com o jogador na água: y=%.2f passo=%.2f em 10 quadros (preso ou afundou)" % [ep, y, passo])
		else:
			_ok("época %d com o jogador na água: anda (%.2f m em 10 quadros) e não afunda (y=%.2f)" % [ep, passo, y])
	GS.trocar_epoca(GS.Epoca.E2020)
	# sala 97 (arcos), água nível 3, no disco sem data: a superfície fica visível e não atrasa
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	nivel.ir_para_sala(16)
	await _frames(5)
	var c16 = nivel.salas[16]
	var ag: Node3D = c16.raiz.get_node_or_null("Agua")
	await _posicionar_local(c16, Vector3(0.0, 0.1, -3.0), 0.0)
	var d16: float = await _medir_q(12)
	if ag and ag.visible and d16 > d_agua / 0.8:
		_achado("semdata_agua", "B", "no disco sem data a água da sala 97 segue VISÍVEL e sem lentidão (%.2f m em 12 quadros; na 96 ela some). Contradiz o comentário de _lentidao_da_agua" % d16)
	GS.trocar_epoca(GS.Epoca.E2020)


# ============================================================================ 6. mortes e respawn por trecho
func _secao_mortes() -> void:
	print("-- 6. morte em cada trecho: volta ao último checkpoint PASSADO, no chão, com a água certa")
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	# [sala de morte (idx), checkpoint esperado (idx)]; o jogador passa pelos checkpoints antes, como na partida
	var casos := [[1, 0], [3, 0], [6, 5], [8, 5], [11, 10], [13, 10], [14, 14], [16, 15], [18, 15]]
	for par in casos:
		for k in [0, 5, 10, 14, 15]:
			if k <= par[0]:
				nivel.ir_para_sala(k)
				await _frames(4)
		nivel.ir_para_sala(par[0])
		await _frames(10)
		var m0: int = GS.contadores.get("mortes", 0)
		GS.matar_jogador("teste")
		await _ate(func(): return nivel.morrendo, 180)
		await _esperar_morte()
		await _frames(30)
		var cp = nivel.salas.get(par[1], null)
		var sala_ok: bool = GS.sala_atual == 81 + par[1]
		var chao: bool = player.is_on_floor()
		var perto := false
		if cp != null:
			perto = player.global_position.distance_to(cp.raiz.to_global(Vector3(0, cp.piso_fn.call(-1.3) + 0.05, -1.3))) < 1.5
		var mortes_ok: bool = GS.contadores.get("mortes", 0) == m0 + 1
		var agua_ok: bool = absf(nivel.prof - nivel.PROF_AGUA[nivel.nivel_da_sala(81 + par[1])]) < 0.01
		var msg := "morreu na sala %d -> sala %d (sala atual %d, chão=%s, perto do começo=%s, água=%s, mortes=%s)" % [81 + par[0], 81 + par[1], GS.sala_atual, str(chao), str(perto), str(agua_ok), str(mortes_ok)]
		if sala_ok and chao and perto and agua_ok and mortes_ok and player.pode_mover:
			_ok(msg)
		else:
			_achado("morte_trecho", "A", msg)


# ============================================================================ 9. escada que sobe e arcadas
func _secao_extras() -> void:
	print("-- 9. escada que sobe (sala 99) andando da entrada; arcadas da sala 'arcos'")
	GS.set_flag("porao_semente", SEMENTES[0])
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	nivel.ir_para_sala(18)
	await _frames(5)
	var c = nivel.salas[18]
	await _posicionar_local(c, Vector3(0.0, 0.1, -1.4), 0.0)
	await _andar_q(60)
	var pl: Vector3 = c.raiz.to_local(player.global_position)
	if pl.z < -3.0 and pl.y > 1.0:
		_ok("escada que sobe: andando da entrada, o jogador sobe (z=%.2f, y=%.2f)" % [pl.z, pl.y])
	else:
		_achado("escada_sobe", "A", "escada que sobe (sala 99): a entrada é bloqueada, o jogador para em z=%.2f, y=%.2f. Não há como chegar ao Braço Morto andando" % [pl.z, pl.y])
	# arcadas: a abertura leva ao nicho (chão, sem vazio)
	GS.set_flag("porao_semente", SEMENTES[0])
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	var ia := -1
	for d in nivel.plano:
		if d["tipo"] == "arcos":
			ia = d["idx"]
			break
	nivel.ir_para_sala(ia)
	await _frames(5)
	var ca = nivel.salas[ia]
	await _posicionar_local(ca, Vector3(2.0, 0.1, -3.2), -PI * 0.5)
	await _andar_q(25)
	var pa: Vector3 = ca.raiz.to_local(player.global_position)
	if _caiu():
		_achado("arcada", "A", "arcada (sala %d): andando por uma abertura o jogador cai (x=%.2f, y=%.2f)" % [81 + ia, pa.x, player.global_position.y])
	elif pa.x > 4.6:
		_ok("arcada (sala %d): a abertura leva ao nicho sem queda (x=%.2f)" % [81 + ia, pa.x])
	else:
		_achado("arcada", "M", "arcada (sala %d): não passa pela abertura (x=%.2f)" % [81 + ia, pa.x])


# ============================================================================ 7. falas e eventos
func _secao_falas() -> void:
	print("-- 7. falas e eventos: voz do Tito por sala, telefone, sandália")
	await _carregar_porao()
	nivel.ameacas_ligadas = false
	var com_voz := 0
	var voz_ok := 0
	for i in nivel.N:
		nivel.ir_para_sala(i)
		await _frames(3)
		var c = nivel.salas[i]
		if c.voz.is_empty():
			continue
		com_voz += 1
		nivel._voz_t = 0.0
		await _frames(3)
		if nivel._legenda.text == "ei… aqui…":
			voz_ok += 1
		else:
			_achado("voz", "M", "sala %d (%s) tem voz mas a legenda não aparece (texto '%s')" % [81 + i, c.tipo, nivel._legenda.text])
	if voz_ok == com_voz:
		_ok("voz do Tito em %d salas: legenda 'ei… aqui…' em todas" % com_voz)
	# telefone (sala do telefone)
	var it_tel_idx := -1
	for d in nivel.plano:
		if d["tipo"] == "telefone":
			it_tel_idx = d["idx"]
			break
	if it_tel_idx >= 0:
		nivel.ir_para_sala(it_tel_idx)
		await _frames(5)
		var ct = nivel.salas[it_tel_idx]
		var tel = _interativo(ct, "Atender")
		if tel == null:
			_achado("telefone", "A", "sala do telefone sem o interativo 'Atender'")
		else:
			tel.interagir(player)
			var ok_t: bool = await _ate(func():
				_destravar_ui()
				return GS.flag("pista_telefone"), 900)
			if ok_t:
				_ok("telefone atendido: conta a pista")
			else:
				_achado("telefone", "M", "atender o telefone não registra a pista")
	else:
		print("   (sem sala do telefone nesta semente)")
	# sandália (sala 98): só pegar com o disco sem data
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	nivel.ir_para_sala(17)
	await _frames(5)
	var c17 = nivel.salas[17]
	var sa = _interativo(c17, "Pegar a sandália")
	if sa == null:
		_achado("sandalia", "M", "sala 98 sem o interativo da sandália")
	else:
		var antes: int = GS.contadores.get("pistas_tito", 0)
		sa.interagir(player)
		await _frames(5)
		if GS.flag("pista_sandalia_porao") and GS.contadores.get("pistas_tito", 0) == antes + 1:
			_ok("sandália pega: pista conta 1 em pistas_tito")
		else:
			_achado("sandalia", "M", "pegar a sandália não registra a pista")
	GS.trocar_epoca(GS.Epoca.E2020)


# ============================================================================ 8. Continuar em cada checkpoint
func _secao_checkpoints() -> void:
	print("-- 8. Continuar: preparar_continuar + carregar_mundo em 81, 86, 91, 95, 96")
	GS.trocar_epoca(GS.Epoca.E2020)
	for cp in [81, 86, 91, 95, 96]:
		GS.checkpoint_sala = cp
		var r: Array = GS.preparar_continuar()
		await main.carregar_mundo(r[0], r[1])
		_atualizar_refs()
		await _frames(20)
		var idx: int = cp - 81
		var c = nivel.salas.get(idx, null)
		if c == null:
			_achado("continuar", "A", "Continuar em %d: a sala %d não foi montada" % [cp, cp])
			continue
		var esperado: Vector3 = c.raiz.to_global(Vector3(0, c.piso_fn.call(-1.1) + 0.1, -1.1))
		var dist: float = player.global_position.distance_to(esperado)
		var msg := "Continuar em %d (marcador %s): sala_atual=%d, chão=%s, a %.2f m do marcador, água nível %d" % [cp, r[1], GS.sala_atual, str(player.is_on_floor()), dist, nivel.nivel_agua]
		var ok_all: bool = r[0] == PORAO and GS.sala_atual == cp and player.is_on_floor() and dist < 1.0 and nivel.nivel_agua == nivel.nivel_da_sala(cp)
		if ok_all:
			_ok(msg)
		else:
			_achado("continuar", "A", msg)
		var caiu_antes: bool = _caiu()
		await _andar_q(20)
		if caiu_antes or _caiu():
			_achado("continuar_queda", "A", "Continuar em %d: anda e cai" % cp)
