extends SceneTree
## Varredura QA (save / Continuar). Uso: timeout 300 godot --headless -s res://tests/varredura/save.gd
## Obs.: outros processos godot podem gravar user://save.json ao mesmo tempo; divergências de disco são repetidas isoladas.

const CASTELINHO := "res://world/niveis/castelinho.tscn"
const ATO2 := "res://world/niveis/ato2.tscn"
const PORAO := "res://world/niveis/porao.tscn"
const BRACO := "res://world/niveis/braco_morto.tscn"

var falhas := 0
var GS
var main


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	_b_mapa_visitas()
	await _a_continuar_cada_checkpoint()
	_b_saves_ruins()
	_c_novo_jogo_e_tem_save()
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ---------------------------------------------------------------- utilitários
func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _escrever(txt: String) -> void:
	var f := FileAccess.open(GS.ARQUIVO_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()


## Destino esperado de um checkpoint, pela regra escrita em game_state.gd (independente da implementação).
func _esperado(cp: int) -> Array:
	if cp >= 100:
		return [BRACO, "Spawn", 5]
	if cp >= 81:
		var melhor := 81
		for c in [86, 91, 95, 96]:
			if cp >= c:
				melhor = c
		return [PORAO, "Checkpoint_%d" % melhor, 5]
	if cp == 55:
		return [ATO2, "Checkpoint_55", 3]
	var v := 1 if cp <= 22 else (2 if cp <= 44 else (3 if cp <= 66 else 4))
	return [CASTELINHO, "Checkpoint_%d" % cp, v]


## Y do chão logo abaixo de `pos` (ou -999 se não há chão).
func _chao_em(pos: Vector3) -> float:
	var sp: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var r: Dictionary = sp.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), pos + Vector3(0, -1.0, 0), 1))
	if r.is_empty():
		return -999.0
	return r["position"].y


## true se a cápsula do jogador (raio 0,28 m, altura 1,7 m) cabe em `pos` sem bater em parede.
func _livre(pos: Vector3) -> bool:
	var sp: PhysicsDirectSpaceState3D = main.player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.28
	forma.height = 1.7
	q.shape = forma
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.97, 0))
	q.collision_mask = 1
	return sp.intersect_shape(q, 1).is_empty()


# ---------------------------------------------------------------- A: continuar em cada checkpoint
func _a_continuar_cada_checkpoint() -> void:
	print("-- A Continuar em cada checkpoint (SALAS_CHECKPOINT + 55 + 100)")
	var cps: Array = GS.SALAS_CHECKPOINT.duplicate()
	cps.append(55)
	cps.append(100)
	for cp in cps:
		await _caso(int(cp))


func _caso(cp: int) -> void:
	var esp := _esperado(cp)
	var tag := "cp %d" % cp
	GS.novo_jogo()
	GS.checkpoint_sala = cp
	GS.ganhar_disco(0)
	GS.ganhar_disco(2)
	GS.set_flag("tem_visor")
	GS.set_flag("tem_lanterna")
	GS.set_flag("saindo_para_barra", true)
	GS.checkpoint_sala = cp
	GS.salvar()
	# "reabrir o jogo": suja a memória e recarrega do disco
	GS.sala_atual = 30
	GS.epoca = GS.Epoca.E1950
	GS.corruption = 0.6
	GS.visita = 4
	GS.checkpoint_sala = 1
	GS.discos.clear()
	GS.carregar()
	_checar(GS.checkpoint_sala == cp, "%s: carregar() lê o checkpoint do disco (%d) [se falhar, repetir isolado]" % [tag, GS.checkpoint_sala])
	var dest: Array = GS.preparar_continuar()
	_checar(dest[0] == esp[0] and dest[1] == esp[1], "%s: destino %s %s (esperado %s %s)" % [tag, str(dest[0]).get_file(), dest[1], str(esp[0]).get_file(), esp[1]])
	_checar(GS.visita == esp[2], "%s: visita %d (esperada %d)" % [tag, GS.visita, esp[2]])
	_checar(GS.epoca == GS.Epoca.E2020 and GS.sala_atual == 0, "%s: época de hoje e sala zerada antes de carregar" % tag)
	_checar(GS.discos == [0, 2] and GS.disco_atual == 2, "%s: discos preservados (%s, atual %d)" % [tag, str(GS.discos), GS.disco_atual])
	_checar(GS.flag("tem_visor") == true and GS.flag("tem_lanterna") == true and not GS.flags.has("saindo_para_barra"),
		"%s: flags preservadas e saindo_para_barra limpa" % tag)
	await main._comecar(true)
	await _frames(120)
	var p = main.player
	var nivel: Node3D = main.mundo.get_child(0)
	_checar(main.nivel_atual == esp[0], "%s: nível carregado %s" % [tag, str(main.nivel_atual).get_file()])
	var m: Node3D = nivel.find_child(esp[1], true, false) as Node3D
	if m == null and nivel.has_method("ponto_spawn"):
		m = nivel.ponto_spawn(esp[1]) as Node3D
	_checar(m != null, "%s: marcador %s existe no nível" % [tag, esp[1]])
	if m != null:
		var dxz := Vector2(p.global_position.x - m.global_position.x, p.global_position.z - m.global_position.z).length()
		_checar(dxz < 1.6, "%s: jogador sobre o marcador (%.2f m de distância)" % [tag, dxz])
	var hy := _chao_em(p.global_position)
	_checar(p.is_on_floor() and hy > -900.0 and absf(hy - p.global_position.y) < 0.25,
		"%s: sobre chão (y jogador %.2f, chão %.2f, on_floor %s)" % [tag, p.global_position.y, hy, str(p.is_on_floor())])
	_checar(p.global_position.y > -0.5, "%s: não caiu após 120 frames (y %.2f)" % [tag, p.global_position.y])
	_checar(_livre(p.global_position), "%s: não está dentro de parede" % tag)
	_checar(GS.sala_atual == cp, "%s: sala_atual == checkpoint após 120 frames (sala %d)" % [tag, GS.sala_atual])
	_checar(absf(GS.corruption - GS.corruption_por_sala(cp)) < 0.01,
		"%s: corrupção = curva da sala %d (%.2f, esperado %.2f)" % [tag, cp, GS.corruption, GS.corruption_por_sala(cp)])
	_checar(GS.epoca == GS.Epoca.E2020, "%s: época de hoje (época %d)" % [tag, GS.epoca])
	_checar(GS.visita == esp[2], "%s: GameState.visita %d após carregar" % [tag, GS.visita])
	var vn: Variant = nivel.get("visita")
	_checar(vn == null or int(vn) == esp[2], "%s: visita do nível = %s (esperada %d)" % [tag, str(vn), esp[2]])
	_checar(GS.jogando, "%s: jogando = true" % tag)
	_checar(GS.discos == [0, 2] and GS.flag("tem_visor") == true, "%s: discos e flags intactos após carregar o nível" % tag)


# ---------------------------------------------------------------- B: mapa de visitas
func _b_mapa_visitas() -> void:
	print("-- B mapa visita_da_sala e SALAS_CHECKPOINT")
	var ok := true
	for n in range(1, 101):
		var e := 5 if n >= 81 else (1 if n <= 22 else (2 if n <= 44 else (3 if n <= 66 else 4)))
		if GS.visita_da_sala(n) != e:
			ok = false
			print("    sala %d: visita_da_sala=%d esperado=%d" % [n, GS.visita_da_sala(n), e])
	_checar(ok, "visita_da_sala: 1..22 v1, 23..44 v2, 45..66 v3, 67..80 v4, 81+ porão (5)")
	var lista: Array = GS.SALAS_CHECKPOINT
	var ordenada := true
	for i in range(1, lista.size()):
		if int(lista[i]) <= int(lista[i - 1]):
			ordenada = false
	_checar(ordenada, "SALAS_CHECKPOINT em ordem crescente (%s)" % str(lista))


# ---------------------------------------------------------------- B2: saves ruins / versão antiga
func _b_saves_ruins() -> void:
	print("-- D saves vazios, corrompidos, antigos")
	GS.checkpoint_sala = 77
	GS.visita = 4
	_escrever("")
	GS.carregar()
	_checar(GS.checkpoint_sala == 77, "save vazio: carregar não mexe na memória (cp %d)" % GS.checkpoint_sala)
	_escrever("{ quebrado")
	GS.carregar()
	_checar(GS.checkpoint_sala == 77, "save com JSON quebrado: carregar não mexe na memória (cp %d)" % GS.checkpoint_sala)
	_escrever("[1,2,3]")
	GS.carregar()
	_checar(GS.checkpoint_sala == 77, "save que é lista: ignorado (cp %d)" % GS.checkpoint_sala)
	# versão antiga: sem "visita" e sem "discos"
	GS.visita = 4
	GS.discos.assign([0, 1, 3])
	GS.disco_atual = 3
	_escrever('{"checkpoint_sala": 23, "sala_maxima": 25, "flags": {"tem_visor": true}}')
	GS.carregar()
	_checar(GS.checkpoint_sala == 23 and GS.flag("tem_visor") == true, "save antigo: checkpoint 23 e flags lidos")
	_checar(GS.visita == 1, "save antigo sem 'visita': visita volta ao padrão 1 (ficou %d)" % GS.visita)
	_checar(GS.discos.is_empty(), "save antigo sem 'discos': discos zerados (ficou %s)" % str(GS.discos))
	var dest: Array = GS.preparar_continuar()
	_checar(dest[1] == "Checkpoint_23" and GS.visita == 2, "save antigo: Continuar leva a Checkpoint_23 na visita 2 (%s, v%d)" % [dest[1], GS.visita])
	# discos null: o carregar() deve falhar só nessa linha, sem derrubar o resto
	_escrever('{"checkpoint_sala": 45, "discos": null, "disco_atual": 1}')
	GS.carregar()
	_checar(GS.checkpoint_sala == 45, "save com 'discos': null: checkpoint 45 lido antes do erro (%d)" % GS.checkpoint_sala)
	# flags com tipo errado
	_escrever('{"checkpoint_sala": 12, "flags": 5}')
	GS.carregar()
	_checar(GS.checkpoint_sala == 12, "save com 'flags': 5: checkpoint 12 lido (%d)" % GS.checkpoint_sala)
	_checar(typeof(GS.flags) == TYPE_DICTIONARY, "save com 'flags': 5: flags continua dicionário (%s)" % str(typeof(GS.flags)))
	# checkpoint 0 no arquivo
	_escrever('{"checkpoint_sala": 0}')
	GS.carregar()
	_checar(GS.checkpoint_sala >= 1, "save com checkpoint_sala 0 vira no mínimo 1 (ficou %d)" % GS.checkpoint_sala)
	# restaura um save sadio para não deixar lixo
	GS.novo_jogo()


# ---------------------------------------------------------------- C: novo jogo e tem_save
func _c_novo_jogo_e_tem_save() -> void:
	print("-- C novo_jogo apaga tudo; tem_save")
	GS.checkpoint_sala = 67
	GS.visita = 4
	GS.sala_maxima = 70
	GS.discos.assign([0, 1])
	GS.disco_atual = 1
	GS.selos.assign(["x"])
	GS.contadores["mortes"] = 5
	GS.flags["tem_visor"] = true
	GS.atencao = 0.5
	GS.salvar()
	GS.novo_jogo()
	var limpo := func() -> bool:
		return GS.checkpoint_sala == 1 and GS.visita == 1 and GS.sala_maxima == 0 and GS.discos.is_empty() \
			and GS.disco_atual == -1 and GS.selos.is_empty() and GS.flags.is_empty() \
			and int(GS.contadores["mortes"]) == 0 and is_equal_approx(GS.atencao, 0.0)
	_checar(limpo.call(), "novo_jogo zera memória (cp %d, visita %d, discos %s, flags %s)" % [GS.checkpoint_sala, GS.visita, str(GS.discos), str(GS.flags)])
	GS.checkpoint_sala = 1
	GS.discos.clear()
	GS.flags.clear()
	GS.carregar()
	_checar(limpo.call(), "novo_jogo gravou no disco (recarregado: cp %d, discos %s, flags %s)" % [GS.checkpoint_sala, str(GS.discos), str(GS.flags)])
	_checar(not GS.tem_save(), "tem_save() falso logo após novo_jogo")
	GS.checkpoint_sala = 2
	_checar(GS.tem_save(), "tem_save() verdadeiro com checkpoint 2")
	GS.checkpoint_sala = 1
	GS.novo_jogo()
