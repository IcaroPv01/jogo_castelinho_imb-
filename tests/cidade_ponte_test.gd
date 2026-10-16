extends SceneTree
## Teste automático (headless) do miolo da PONTE À NOITE (Módulo 14, `world/niveis/cidade_ponte.gd`): carrega e é comprida e
## caminhável de ponta a ponta, orçamento (luzes, malhas), a contagem dos postes, a pista da grade (conta uma vez só, é alcançável
## pelo raio do jogador), a Figura (some cercada, some de vez depois de 2 sumiços, volta no portão depois da pista), os pescadores
## (parados enquanto olhados, viram quando saem da tela, susto leve ao olhar para trás), o portão (sem pista = só sai; com pista =
## conclui e grava a flag) e a rede de segurança. O genérico da base (borda, HUD, Mapa, volta à calçada) está em cidade_test.gd.
## Uso: godot --headless -s res://tests/cidade_ponte_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var nivel: Node
const MODO_JOGADOR := 1        # CidadePonte.Olhar.JOGADOR
const MODO_AGUA := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	await _estrutura()
	await _postes_e_pista()
	await _pescadores()
	await _figura()
	await _depois_da_pista()
	await _saidas()
	main.queue_free()
	await process_frame
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


## Novo jogo na visita 3 (a ponte abre depois dela) e entra na ponte.
func _entrar() -> void:
	GS.novo_jogo()
	GS.jogando = true
	GS.visita = 3
	GS.entrar_sala(GS.sala_global(1))
	main.hud.visible = true
	await main.carregar_mundo(GS.CIDADE["ponte"]["cena"], "Spawn")
	await _frames(8)
	nivel = main.mundo.get_child(0)
	root.get_node("/root/Guia").cancelar()


func _jogador_em(x: float, z: float, yaw_graus: float) -> void:
	var p: Node3D = main.player
	p.global_position = Vector3(x, 0.1, z)
	p.rotation = Vector3(0.0, deg_to_rad(yaw_graus), 0.0)
	p.cabeca.rotation.x = 0.0
	p.velocity = Vector3.ZERO


func _olhar_para(alvo: Vector3) -> void:
	var p: Node3D = main.player
	var d: Vector3 = alvo - p.global_position
	p.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
	p.cabeca.rotation.x = 0.0


## Cápsula do jogador andando em linha reta: true se nada barra o caminho.
func _caminho_livre(x: float, z0: float, z1: float) -> bool:
	var espaco: PhysicsDirectSpaceState3D = nivel.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), Vector3(x, 1.0, z0))
	q.motion = Vector3(0.0, 0.0, z1 - z0)
	q.collision_mask = 1
	var r: PackedFloat32Array = espaco.cast_motion(q)
	return r.size() >= 1 and r[0] >= 0.999


# ============================================================================ estrutura
func _estrutura() -> void:
	print("-- estrutura da ponte")
	await _entrar()
	_checar(nivel.id == "ponte" and main.nivel_atual == GS.CIDADE["ponte"]["cena"], "carrega a cena da ponte")
	_checar(nivel.hora == 3 and nivel.env.fog_enabled and nivel.env.fog_depth_end > 80.0, "noite com neblina leve (névoa longa)")
	var area: Rect2 = nivel.area
	_checar(area.size.y >= 100.0 and area.size.x <= 14.0, "AREA estreita e comprida (%.0f x %.0f m)" % [area.size.x, area.size.y])
	var luzes := 0
	var malhas := 0
	var multis := 0
	var instancias := 0
	for n in nivel.find_children("*", "Node", true, false):
		if n is Light3D:
			luzes += 1
		elif n is MeshInstance3D and n.visible:
			malhas += 1
		elif n is MultiMeshInstance3D:
			multis += 1
			instancias += (n as MultiMeshInstance3D).multimesh.instance_count
	_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
	_checar(malhas + multis <= 110, "orçamento: %d malhas + %d MultiMesh (≈ draw calls, sem contar o gate/figura)" % [malhas, multis])
	_checar(multis >= 5 and instancias >= 100, "postes, lâmpadas, brilhos e pescadores em MultiMesh (%d instâncias)" % instancias)
	_checar(nivel.find_child("Pescadores", true, false) != null and nivel.pesc_yaw.size() == 7, "7 pescadores parados")
	# caminhável de ponta a ponta (o caminho do jogador e o lado direito) e barrado pelo parapeito
	_checar(_caminho_livre(0.0, 50.0, -60.0), "dá para andar do Spawn ao fim da ponte (centro)")
	_checar(_caminho_livre(-3.6, 50.0, -60.0), "e pelo lado dos pescadores")
	_checar(_caminho_livre(4.2, 40.0, -45.0), "e pelo lado direito (dos postes)")
	var espaco: PhysicsDirectSpaceState3D = nivel.get_world_3d().direct_space_state
	var r1 := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4.0, 0.6, 0.0), Vector3(7.0, 0.6, 0.0), 1))
	_checar(not r1.is_empty() and str((r1["collider"] as Node).get_parent().name) == "Grade_L", "o parapeito leste segura o jogador")
	var chao := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 2.0, -20.0), Vector3(0.0, -2.0, -20.0), 1))
	_checar(not chao.is_empty() and absf(float(chao["position"].y)) < 0.1, "o chão da ponte está no nível 0")
	# o objetivo e a Figura no começo
	_checar(nivel._texto_objetivo().contains("poste"), "objetivo fala dos postes: '%s'" % nivel._texto_objetivo())
	_checar(nivel.figura != null and nivel.figura.visible and nivel.figura.global_position.z < -40.0 and not nivel.figura.ativa, "a Figura espera parada na outra cabeceira")
	# a rede de segurança (borda e queda já estão em cidade_test): sair da AREA pelo lado
	var mk: Node3D = nivel.find_child("Spawn", true, false)
	var q0: int = nivel.quedas
	main.player.global_position = Vector3(9.0, 0.5, -10.0)
	var volta: bool = await _ate(func() -> bool: return main.player.global_position.distance_to(mk.global_position) < 1.5, 120)
	_checar(volta and nivel.quedas == q0 + 1, "sair pelo lado devolve ao Spawn (sem morte)")


# ============================================================================ postes e a pista
func _postes_e_pista() -> void:
	print("-- postes e pista da grade")
	await _entrar()
	_checar(nivel.postes_passados == 0, "começa sem postes passados")
	_checar(nivel._halo_pista != null and nivel._mat_halo_pista.albedo_color.a > 0.1, "a pista tem brilho azulado que chama o olho (de longe)")
	# parado ~60 s sem progresso: dica automática
	await _frames(30)
	root.get_node("/root/Guia").cancelar()
	nivel._sem_progresso = 61.0
	await _frames(3)
	_checar(nivel.dicas >= 1, "depois de ~60 s sem progresso vem uma dica automática")
	var passos := {30.0: 1, 10.0: 3, -5.0: 4, -25.0: 6, -40.0: 7}
	for z: float in passos:
		_jogador_em(0.0, z, 0.0)
		await _frames(4)
		_checar(nivel.postes_passados == passos[z], "em z=%.0f já passou %d postes (%d)" % [z, passos[z], nivel.postes_passados])
	_jogador_em(0.0, 40.0, 0.0)
	await _frames(4)
	_checar(nivel.postes_passados == 7, "voltar atrás não desconta nem repete")
	# chega perto do poste apagado: o objetivo muda para a grade
	_jogador_em(3.0, -24.4, -90.0)
	await _frames(4)
	_checar(nivel.perto_do_apagado and nivel._texto_objetivo().contains("grade"), "perto do apagado: '%s'" % nivel._texto_objetivo())
	# o raio do jogador acha a grade (E funciona de verdade)
	var achou: bool = await _ate(func() -> bool: return main.player._alvo == nivel._interagivel_pista, 30)
	_checar(achou and nivel._interagivel_pista.texto_interacao == "Examinar a grade", "olhando a grade aparece 'Examinar a grade'")
	# a pista conta uma vez só
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	nivel._interagivel_pista.interagir(main.player)
	await _frames(3)
	_checar(GS.flag("pista_ponte_figura") and int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "examinar a grade dá a pista 'ponte_figura' (+1)")
	nivel._interagivel_pista.interagir(main.player)
	await _frames(3)
	_checar(int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "examinar de novo não conta outra vez")
	_checar(nivel.pista_vista and nivel._texto_objetivo().contains("portão"), "o objetivo manda voltar ao portão: '%s'" % nivel._texto_objetivo())
	_checar(not GS.cidade_feita("ponte"), "achar a pista ainda não conclui (falta voltar ao portão)")


# ============================================================================ pescadores
func _pescadores() -> void:
	print("-- pescadores")
	await _entrar()
	var inicial: Array = nivel.pesc_yaw.duplicate()
	_checar(inicial.size() == 7, "sete pescadores")
	# de longe e olhando para eles: não se mexem
	_jogador_em(0.0, 20.0, 0.0)
	await _frames(240)
	_checar(nivel.pesc_yaw == inicial and not nivel.susto_feito, "olhados (do Spawn rumo a eles), ficam parados e sem susto (%d frames)" % 240)
	# passa por eles e vai embora olhando para a frente: ficam de costas para a tela e trocam de direção
	_jogador_em(0.0, -30.0, 0.0)
	var viraram: bool = await _ate(func() -> bool: return nivel.pesc_modo.count(MODO_JOGADOR) == 7, 400)
	_checar(viraram, "fora da tela, todos se viram para o jogador (%s)" % str(nivel.pesc_modo))
	var moveram := 0
	for i in 7:
		if absf(angle_difference(float(nivel.pesc_yaw[i]), float(inicial[i]))) > 0.5:
			moveram += 1
	_checar(moveram >= 6, "e a direção mudou de verdade (%d de 7)" % moveram)
	_checar(not nivel.susto_feito, "o susto só vem quando o jogador olha para trás")
	# olha para trás: vê todos virados, susto leve uma vez
	_jogador_em(0.0, -30.0, 180.0)
	await _frames(4)
	_checar(nivel.susto_feito, "olhar para trás e vê-los virados: susto leve")
	var vistos: Array = nivel.pesc_yaw.duplicate()
	await _frames(240)
	_checar(nivel.pesc_yaw == vistos, "enquanto olhados, não se mexem (4 s)")
	# olha de novo para a frente e depois para trás: estão virados para outro lado
	var modos: Array = nivel.pesc_modo.duplicate()
	_jogador_em(0.0, -30.0, 0.0)
	await _frames(300)
	var mudou := 0
	for i in 7:
		if nivel.pesc_modo[i] != modos[i]:
			mudou += 1
	_checar(mudou >= 6, "a cada vez que você olha de novo, outro lado (%d de 7 mudaram)" % mudou)


# ============================================================================ Figura (antes da pista)
func _figura() -> void:
	print("-- Figura Branca (antes da pista)")
	await _entrar()
	var f: Node3D = nivel.figura
	_checar(f.visible and f.global_position.distance_to(nivel.FIGURA_LONGE) < 0.5, "ela aparece ao longe, na outra cabeceira")
	# de longe, olhando: ela fica (só some quando cercada)
	_jogador_em(0.0, 20.0, 0.0)
	_olhar_para(f.global_position + Vector3.UP * 1.4)
	await _frames(60)
	_checar(not f.sumida and nivel.sumicos == 0, "de longe ela fica lá parada")
	# cerca: olhando de perto, some
	_jogador_em(0.0, -43.5, 0.0)
	_olhar_para(f.global_position + Vector3.UP * 1.4)
	var sumiu: bool = await _ate(func() -> bool: return nivel.sumicos >= 1, 120)
	_checar(sumiu and f.sumida, "cercada olhando a menos de %.0f m, ela SOME" % nivel.DIST_FIGURA)
	var voltou: bool = await _ate(func() -> bool: return not f.sumida, 600)
	_checar(voltou and f.visible and f.global_position.z < -52.0, "e reaparece mais longe (z=%.0f)" % f.global_position.z)
	# cerca de novo: some de vez
	_jogador_em(0.0, -52.0, 0.0)
	_olhar_para(f.global_position + Vector3.UP * 1.4)
	var sumiu2: bool = await _ate(func() -> bool: return nivel.sumicos >= 2, 120)
	_checar(sumiu2, "cercada outra vez, some de novo")
	var some_de_vez: bool = await _ate(func() -> bool: return f.sumida and not f.visible and nivel._ultima_vez, 600)
	await _frames(120)
	_checar(some_de_vez and f.sumida and not f.visible, "depois do 2º sumiço ela não volta mais")
	_checar(not f.matou and not f.ativa, "ela nunca mata nem persegue aqui")


# ============================================================================ depois da pista: apagão, Figura no portão
func _depois_da_pista() -> void:
	print("-- depois da pista")
	await _entrar()
	_jogador_em(3.0, -24.4, -90.0)
	await _frames(3)
	nivel._interagivel_pista.interagir(main.player)
	await _frames(3)
	_checar(nivel.pista_vista and GS.flag("pista_ponte_figura"), "pista achada")
	var apagou: bool = await _ate(func() -> bool: return nivel._apagao, 400)
	_checar(apagou, "as luzes caem por um instante")
	_checar(nivel._mat_lampada.albedo_color.v < 0.2, "lâmpadas apagadas durante o apagão")
	var fim: bool = await _ate(func() -> bool: return not nivel._apagao, 600)
	_checar(fim and nivel._mat_lampada.albedo_color.v > 0.5, "e voltam depois")
	var f: Node3D = nivel.figura
	_checar(f.visible and f.global_position.z > 20.0 and not f.ativa, "a Figura aparece lá no começo da ponte, parada (z=%.0f)" % f.global_position.z)
	_checar(nivel.sumicos == 0, "(a contagem de sumiços recomeça)")
	# volta andando até o portão: ela some quando cercada, duas vezes, e libera o caminho
	_jogador_em(0.0, 34.0, 0.0)
	_olhar_para(f.global_position + Vector3.UP * 1.4)
	var s1: bool = await _ate(func() -> bool: return nivel.sumicos >= 1, 120)
	_checar(s1, "chegando perto, ela some")
	var v1: bool = await _ate(func() -> bool: return not f.sumida, 600)
	_checar(v1 and f.visible, "e reaparece")
	_jogador_em(0.0, f.global_position.z - 7.0, 0.0)
	_olhar_para(f.global_position + Vector3.UP * 1.4)
	var s2: bool = await _ate(func() -> bool: return nivel.sumicos >= 2, 120)
	var fim2: bool = await _ate(func() -> bool: return f.sumida and not f.visible, 600)
	_checar(s2 and fim2, "e some de vez: o caminho até o portão fica livre")
	var mk: Node3D = nivel.find_child("Portao", true, false)
	_checar(_caminho_livre(-1.0, 50.0, 40.0) and mk != null, "o portão do começo continua alcançável")


# ============================================================================ portão: sair x concluir
func _saidas() -> void:
	print("-- portão")
	# sem pista: o portão só sai (não grava)
	await _entrar()
	nivel.find_child("PortaoVolta", true, false).interagir(main.player)
	var saiu: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not _ocupado(), 600)
	await _frames(8)
	_checar(saiu and not GS.cidade_feita("ponte"), "sem a pista, o portão só volta ao Castelinho (lugar não feito)")
	var castelo: Node = main.mundo.get_child(0)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chega na calçada")
	# com a pista: o portão conclui
	await _entrar()
	_jogador_em(3.0, -24.4, -90.0)
	await _frames(3)
	nivel._interagivel_pista.interagir(main.player)
	await _frames(3)
	_jogador_em(0.0, 46.0, 0.0)
	nivel.find_child("PortaoVolta", true, false).interagir(main.player)
	var fechou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not _ocupado(), 600)
	await _frames(8)
	_checar(fechou and GS.cidade_feita("ponte") and GS.flag("cidade_ponte_feito"), "com a pista, voltar ao portão conclui (cidade_ponte_feito)")
	castelo = main.mundo.get_child(0)
	vc = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "e volta à calçada")
	_checar(GS.visita == 3 and int(GS.contadores.get("pistas_tito", 0)) == 1, "visita intacta e 1 pista contada")
	# entrando de novo, já concluída: o Mapa diz que está tudo certo e o portão sai sem recontar
	await main.carregar_mundo(GS.CIDADE["ponte"]["cena"], "Spawn")
	await _frames(8)
	nivel = main.mundo.get_child(0)
	_checar(nivel._texto_objetivo().begins_with("Aqui está tudo certo"), "ponte já feita: o Mapa diz que está tudo certo")
	_checar(nivel.pista_vista and nivel.figura.visible and nivel.figura.global_position.z > 20.0, "e a Figura já espera no portão (sem refazer a tarefa)")


func _ocupado() -> bool:
	return bool(root.get_node("/root/Transicao").ocupado)
