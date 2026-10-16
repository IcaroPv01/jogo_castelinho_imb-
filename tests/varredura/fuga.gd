extends SceneTree
## Varredura "fuga": caminhante caótico com o controlador REAL do jogador para achar buracos de colisão:
##   A) VAZIO (caiu abaixo do chão mais baixo - 6 m, ou > 4 s sem tocar o chão)
##   B) FORA DOS LIMITES (fora da caixa das colisões do nível, sem contar as dunas gigantes)
##   C) PRESO NA PAREDE (cápsula enfiada no mundo > 1 s; ou tecla segurada 3 s e andou < 0,1 m enfiado)
##   D) SOFT-LOCK (andou < 0,3 m em 6 s de entradas variadas, no chão, sem sobrepor)
## Também mede as dunas do Ato II (até onde dá para andar, e quanto leva para cair pela borda).
## Salta "baixo" (apogeu 1,0 m) às vezes, e no Castelinho vira a época no meio da caminhada (Q apertado/solto).
## Uso: timeout 900 godot --headless -s res://tests/varredura/fuga.gd -- <níveis> [--seg=14] [--max=40] [--sem-pulo]
##   níveis: c1 c2 c3 c4 (visitas do Castelinho) ato2 barra porao braco (padrão: todos)
##   --epocas=0,3 limita as épocas do Castelinho (0=1950 1=1975 2=2019 3=hoje 4=1967 5=????)
## Saída: tests/varredura/saida/fuga.md

const CASTELINHO := "res://world/niveis/castelinho.tscn"
const ATO2 := "res://world/niveis/ato2.tscn"
const BARRA := "res://world/niveis/barra.tscn"
const PORAO := "res://world/niveis/porao.tscn"
const BRACO := "res://world/niveis/braco_morto.tscn"
const DT := 1.0 / 60.0
var PULO_BAIXO := 6.0   # padrão: apogeu 1,0 m; o real é ~0,37 m (--pulo=3.5)

var GS
var main
var p
var nivel
var seg := 14.0
var max_starts := 40
var com_pulo := true
var com_rede := false      # --com-rede: deixa a RedeSeguranca (resgate automático) ligada
var dir_dunas := true
var epocas_sel: Array = [0, 1, 2, 3, 4, 5]
var rng := RandomNumberGenerator.new()

# estado da cena atual
var rot := ""               # "c3 / 1975"
var caixa := AABB()
var y_vazio := -10.0
var spawn_pos := Vector3.ZERO
var achados := {}           # chave -> dict
var linhas_extra: Array = []
var _recarregar := false


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var niveis: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seg="):
			seg = float(a.substr(6))
		elif a.begins_with("--max="):
			max_starts = int(a.substr(6))
		elif a.begins_with("--pulo="):
			PULO_BAIXO = float(a.substr(7))
		elif a == "--com-rede":
			com_rede = true
		elif a == "--sem-pulo":
			com_pulo = false
		elif a.begins_with("--epocas="):
			epocas_sel = []
			for s in a.substr(9).split(","):
				epocas_sel.append(int(s))
		elif not a.begins_with("--"):
			niveis.append(a)
	if niveis.is_empty():
		niveis = ["c1", "c2", "c3", "c4", "ato2", "barra", "porao", "braco"]
	load("res://ui/debug.gd").imortal = true
	load("res://ui/debug.gd").figura_off = true
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	Engine.time_scale = 8.0
	rng.seed = 12345
	for n in niveis:
		match n:
			"c1", "c2", "c3", "c4":
				for e in epocas_sel:
					await _cenario(CASTELINHO, int(n.substr(1)), e, n)
			"ato2":
				await _cenario(ATO2, 3, GS.Epoca.E1950, n)
				await _dunas()
			"barra":
				await _cenario(BARRA, 2, GS.Epoca.E2020, n)
			"porao":
				await _cenario(PORAO, 5, GS.Epoca.E2020, n)
			"braco":
				await _cenario(BRACO, 5, GS.Epoca.E2020, n)
	Engine.time_scale = 1.0
	_relatorio()
	quit(0)


# ================================================================== carga
func _carregar(caminho: String, visita: int, epoca: int) -> void:
	GS.novo_jogo()
	GS.visita = visita
	GS.jogando = true
	GS.flags["tem_visor"] = true
	GS.flags["tem_lanterna"] = true
	GS.flags["porta_entrada_aberta"] = true
	if caminho == PORAO:
		GS.flags["porao_semente"] = 1
	main.hud.visible = true
	await main.carregar_mundo(caminho, "Spawn")
	for i in 25:
		root.get_node("/root/Guia").cancelar()
		await physics_frame
	p = main.player
	nivel = main.mundo.get_child(0)
	var rede: Node = nivel.get_node_or_null("RedeSeguranca")
	if rede and not com_rede:
		rede.process_mode = Node.PROCESS_MODE_DISABLED
	GS.trocar_epoca(epoca)
	for i in 6:
		await physics_frame
	_recarregar = false


func _cenario(caminho: String, visita: int, epoca: int, nome: String) -> void:
	rot = "%s / %s" % [nome, GS.NOMES_EPOCA[epoca] if caminho == CASTELINHO else "-"]
	print("== ", rot)
	await _carregar(caminho, visita, epoca)
	spawn_pos = p.global_position
	_calcular_caixa()
	var starts: Array = _pontos_partida()
	print("  caixa %s  y_vazio %.1f  pontos de partida %d" % [str(caixa), y_vazio, starts.size()])
	if OS.get_environment("FUGA_SPAWN") != "":      # só o Spawn (caminhada contínua longa, sem teleporte entre salas)
		starts = starts.filter(func(e): return e["nome"] == "Spawn")
	var usados := 0
	for st in starts:
		if usados >= max_starts:
			break
		if _recarregar:
			await _carregar(caminho, visita, epoca)
		usados += 1
		await _episodio(st, caminho == CASTELINHO, epoca)


# ================================================================== geometria do nível
func _calcular_caixa() -> void:
	var primeiro := true
	var enormes: Array = []
	for cs in nivel.find_children("*", "CollisionShape3D", true, false):
		var c: CollisionShape3D = cs
		if c.shape == null or c.disabled:
			continue
		var par: Node = c.get_parent()
		if not (par is StaticBody3D):
			continue
		var m: ArrayMesh = c.shape.get_debug_mesh()
		if m == null:
			continue
		var a: AABB = c.global_transform * m.get_aabb()
		if a.size.x > 150.0 and a.size.z > 150.0 and a.size.y > 2.0:
			enormes.append("%s %s" % [str(par.name), str(a)])
			continue
		if primeiro:
			caixa = a
			primeiro = false
		else:
			caixa = caixa.merge(a)
	if not enormes.is_empty():
		linhas_extra.append("%s: colisores enormes ignorados na caixa: %s" % [rot, str(enormes)])
		print("  enormes: ", enormes)


func _chao_em(pt: Vector3, de_cima := 0.4) -> float:
	var q := PhysicsRayQueryParameters3D.create(pt + Vector3(0, de_cima, 0), pt + Vector3(0, -40, 0), 1)
	var r: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return (r["position"] as Vector3).y if not r.is_empty() else -999.0


func _pontos_partida() -> Array:
	var lista: Array = []
	var min_y: Array = [1e9]
	var vistos := {}
	var add := func(pos: Vector3, yaw: float, rotulo: String, rayo: bool) -> void:
		var y: float = pos.y
		if rayo:
			y = _chao_em(pos, 0.3)
			if y < -900.0:
				return
		var k := "%d,%d,%d" % [roundi(pos.x), roundi(y), roundi(pos.z)]
		if vistos.has(k):
			return
		vistos[k] = true
		min_y[0] = minf(min_y[0], y)
		lista.append({"pos": Vector3(pos.x, y + 0.05, pos.z), "yaw": yaw, "nome": rotulo})
	for m in nivel.find_children("*", "Marker3D", true, false):
		var n: String = str(m.name)
		if n.begins_with("Checkpoint_") or n.begins_with("Cam_") or n.begins_with("Spawn"):
			add.call(m.global_position, m.global_rotation.y, n, true)
	for a in nivel.find_children("*", "Area3D", true, false):
		var ar: Area3D = a
		for ch in ar.get_children():
			if ch is CollisionShape3D and ch.shape is BoxShape3D:
				var c: Vector3 = (ch as Node3D).global_position
				add.call(c, rng.randf() * TAU, "area:" + str(ar.name), true)
	lista.shuffle()
	var y_max_ok: float = -1e9
	for e in lista:
		y_max_ok = maxf(y_max_ok, e["pos"].y)
	var grade: Array = []
	var zona: AABB = caixa      # FUGA_ZONA="x0,z0,x1,z1": só essa região (o Castelinho tem chão de 600 m)
	var zs: PackedStringArray = OS.get_environment("FUGA_ZONA").split(",")
	if zs.size() == 4:
		zona = AABB(Vector3(float(zs[0]), caixa.position.y, float(zs[1])), Vector3(float(zs[2]) - float(zs[0]), caixa.size.y, float(zs[3]) - float(zs[1])))
	var gx: float = zona.position.x + 1.0
	while gx < zona.end.x:
		var gz: float = zona.position.z + 1.0
		while gz < zona.end.z:
			var y: float = _chao_em(Vector3(gx, caixa.end.y + 1.0, gz), 0.0)
			if y > -900.0 and y <= y_max_ok + 0.5 and not p._sobrepoe_mundo(Vector3(gx, y + 0.05, gz)):
				grade.append({"pos": Vector3(gx, y + 0.05, gz), "yaw": rng.randf() * TAU, "nome": "grade"})
				min_y[0] = minf(min_y[0], y)
			gz += 1.5
		gx += 1.5
	grade.shuffle()
	lista = lista.slice(0, max_starts / 2) + grade
	if lista.is_empty():
		add.call(spawn_pos, p.rotation.y, "Spawn", false)
	y_vazio = min_y[0] - 6.0
	return lista


# ================================================================== episódio
func _episodio(st: Dictionary, castelo: bool, epoca_base: int) -> void:
	p.global_position = st["pos"]
	p.velocity = Vector3.ZERO
	p.rotation.y = st["yaw"]
	p.pode_mover = true
	if castelo:
		GS.trocar_epoca(epoca_base)
	for i in 3:
		await physics_frame
	var nivel_ini: Node = nivel
	var t := 0.0
	var prox_in := 0.0
	var prox_flip := rng.randf_range(2.0, 4.0)
	var no_ar := 0.0
	var sobrepoe := 0.0
	var seg_preso := 0.0     # tempo com tecla segurada, enfiado e sem mover
	var janela_t := 0.0
	var janela_ini: Vector3 = p.global_position
	var janela_max := 0.0
	var janela_ok := true
	var ultimo: Vector3 = p.global_position
	var hit_oob := false
	var hit_vazio := false
	var pressionadas: Array = []
	while t < seg:
		var gp := root.get_node("/root/Guia")
		gp.cancelar()
		# --- entradas
		if t >= prox_in:
			for a in pressionadas:
				Input.action_release(a)
			pressionadas = []
			prox_in = t + rng.randf_range(0.4, 1.3)
			p.rotation.y = rng.randf() * TAU
			var r := rng.randf()
			if r < 0.65:
				pressionadas.append("frente")
			elif r < 0.75:
				pressionadas.append("tras")
			elif r < 0.85:
				pressionadas.append("esquerda")
				pressionadas.append("frente")
			elif r < 0.95:
				pressionadas.append("direita")
				pressionadas.append("frente")
			else:
				pressionadas.append("frente")
				pressionadas.append("esquerda")
			if rng.randf() < 0.45:
				pressionadas.append("correr")
			for a in pressionadas:
				Input.action_press(a)
		if com_pulo and p.is_on_floor() and rng.randf() < 0.012:
			p.velocity.y = PULO_BAIXO
		if castelo and t >= prox_flip:
			prox_flip = t + rng.randf_range(1.5, 4.0)
			var nova: int = GS.Epoca.E2020 if GS.epoca != GS.Epoca.E2020 and rng.randf() < 0.6 else (epoca_base if rng.randf() < 0.7 else rng.randi() % 6)
			if nova == GS.epoca:
				nova = GS.Epoca.E2020 if epoca_base != GS.Epoca.E2020 else GS.Epoca.E1950
			GS.trocar_epoca(nova)
		await physics_frame
		t += DT
		# --- nível trocou (porta/gatilho): recarrega depois
		if is_instance_valid(p) and not p.is_physics_processing():
			linhas_extra.append("%s: jogador congelado por script (cena) na partida %s: recarregando" % [rot, st["nome"]])
			_recarregar = true
			break
		if not is_instance_valid(p) or main.mundo.get_child_count() == 0 or main.mundo.get_child(0) != nivel_ini or main._carregando:
			linhas_extra.append("%s: troca de nível durante o episódio em t=%.1f (partida %s)" % [rot, t, st["nome"]])
			_recarregar = true
			break
		var pos: Vector3 = p.global_position
		# teleporte de script: zera as janelas
		if pos.distance_to(ultimo) > 4.0:
			janela_ini = pos
			janela_t = 0.0
			janela_max = 0.0
			no_ar = 0.0
			sobrepoe = 0.0
			seg_preso = 0.0
		var movido := pos.distance_to(ultimo)
		ultimo = pos
		# --- A) vazio
		if pos.y < y_vazio:
			_achar("A-VAZIO", pos, st, "y %.1f < %.1f" % [pos.y, y_vazio])
			hit_vazio = true
			break
		if p.is_on_floor():
			no_ar = 0.0
		else:
			no_ar += DT
			if no_ar > 4.0:
				_achar("A-VAZIO", pos, st, "%.1f s sem chão (y %.1f)" % [no_ar, pos.y])
				hit_vazio = true
				break
		# --- B) fora dos limites
		if caixa.size != Vector3.ZERO and not hit_oob:
			var g := caixa.grow(1.0)
			if pos.x < g.position.x or pos.x > g.end.x or pos.z < g.position.z or pos.z > g.end.z or pos.y > g.end.y + 3.0:
				_achar("B-FORA", pos, st, "a %.1f m do Spawn" % Vector2(pos.x - spawn_pos.x, pos.z - spawn_pos.z).length())
				hit_oob = true   # continua andando: se for borda, o vazio (A) aparece depois
		# --- C) preso na parede
		var enfiado: bool = p._sobrepoe_mundo(pos)
		if enfiado:
			sobrepoe += DT
			if movido < 0.02 * 1.0 and pressionadas.has("frente"):
				seg_preso += DT
			else:
				seg_preso = maxf(0.0, seg_preso - DT)
			if sobrepoe > 1.0:
				_achar("C-PAREDE", pos, st, "enfiado %.1f s (época %s)" % [sobrepoe, GS.NOMES_EPOCA[GS.epoca]])
				break
			if seg_preso > 3.0:
				_achar("C-PAREDE", pos, st, "tecla 3 s sem mover enfiado")
				break
		else:
			sobrepoe = 0.0
			seg_preso = 0.0
		# --- D) soft-lock
		janela_t += DT
		janela_max = maxf(janela_max, Vector2(pos.x - janela_ini.x, pos.z - janela_ini.z).length())
		if not p.is_on_floor() or enfiado or not p.pode_mover or gp.ocupado():
			janela_ok = false
		if janela_t >= 6.0:
			if janela_ok and janela_max < 0.3:
				_achar("D-SOFTLOCK", pos, st, "andou %.2f m em 6 s" % janela_max)
				break
			janela_t = 0.0
			janela_max = 0.0
			janela_ini = pos
			janela_ok = true
	for a in pressionadas:
		Input.action_release(a)
	for a in ["frente", "tras", "esquerda", "direita", "correr", "visor"]:
		Input.action_release(a)
	await physics_frame


func _achar(tipo: String, pos: Vector3, st: Dictionary, detalhe: String) -> void:
	var chave := "%s|%s|%d,%d,%d" % [tipo, rot, floori(pos.x / 2.0), floori(pos.y / 2.0), floori(pos.z / 2.0)]
	if achados.has(chave):
		achados[chave]["n"] += 1
		return
	achados[chave] = {"tipo": tipo, "rot": rot, "pos": pos, "partida": st["nome"], "ppos": st["pos"], "epoca": GS.NOMES_EPOCA[GS.epoca],
		"det": detalhe, "n": 1, "sala": GS.sala_atual}
	print("  ACHADO %s [%s] pos (%.1f, %.1f, %.1f) partida %s (%.1f, %.1f, %.1f) %s" % [tipo, rot, pos.x, pos.y, pos.z, st["nome"], st["pos"].x, st["pos"].y, st["pos"].z, detalhe])


# ================================================================== dunas do Ato II
func _dunas() -> void:
	print("== ato2 dunas")
	await _carregar(ATO2, 3, GS.Epoca.E1950)
	var res: Array = []
	# extensão andável: raios para baixo (de y 40) numa linha perpendicular ao caminho
	for z in [-30.0, -60.0, -100.0]:
		for lado in [-1.0, 1.0]:
			var ult := 0.0
			var x := 0.0
			while x < 600.0:
				var q := PhysicsRayQueryParameters3D.create(Vector3(lado * x, 40.0, z), Vector3(lado * x, -30.0, z), 1)
				if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
					break
				ult = x
				x += 2.0
			res.append("z %d lado %s: chão contínuo até |x| = %.0f m" % [int(z), "E" if lado > 0 else "O", ult])
	# andar reto em 8 direções a partir de 3 pontos do caminho, correndo, até 240 s (ou parar 10 s)
	for ponto in [Vector3(0, 0.1, -30.0), Vector3(0, 0.1, -60.0)]:
		for k in 8:
			await _carregar(ATO2, 3, GS.Epoca.E1950)
			var yaw: float = k * TAU / 8.0
			p.global_position = ponto
			p.velocity = Vector3.ZERO
			p.rotation.y = yaw
			for i in 5:
				await physics_frame
			var t := 0.0
			var t_cai := -1.0
			var t_60 := -1.0
			var parado := 0.0
			var ult_pos: Vector3 = p.global_position
			var dmax := 0.0
			Input.action_press("frente")
			Input.action_press("correr")
			while t < 240.0:
				root.get_node("/root/Guia").cancelar()
				p.rotation.y = yaw
				p.stamina = 1.0
				await physics_frame
				t += DT
				if not is_instance_valid(p):
					break
				var pos: Vector3 = p.global_position
				if p.is_on_floor():
					dmax = maxf(dmax, Vector2(pos.x - ponto.x, pos.z - ponto.z).length())
				if t_cai < 0.0 and not p.is_on_floor() and pos.y < ponto.y - 8.0:
					t_cai = t
				if pos.y < ponto.y - 60.0:
					t_60 = t
					break
				parado = parado + DT if pos.distance_to(ult_pos) < 0.02 else 0.0
				ult_pos = pos
				if parado > 10.0:
					break
			Input.action_release("frente")
			Input.action_release("correr")
			res.append("de z %d rumo %3.0f graus: parou/terminou em t=%.0f s pos %s; chão até %.0f m do ponto; começou a cair (y-8) em t=%.0f; y-60 em t=%.0f (-1 = nunca)" % [
				int(ponto.z), rad_to_deg(yaw), t, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))), dmax, t_cai, t_60])
	for r in res:
		print("  ", r)
		linhas_extra.append("dunas: " + r)


# ================================================================== relatório
func _relatorio() -> void:
	var f := FileAccess.open(_arq_saida(), FileAccess.WRITE)
	if f == null:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/varredura/saida"))
		f = FileAccess.open(_arq_saida(), FileAccess.WRITE)
	var s := "# fuga (caminhante caótico)\n\n"
	var por_tipo := {}
	var grupos := {}
	for k in achados:
		var a: Dictionary = achados[k]
		por_tipo[a["tipo"]] = por_tipo.get(a["tipo"], 0) + 1
		var pos: Vector3 = a["pos"]
		var gk := "%s|%s|%d,%d" % [a["tipo"], a["rot"].split(" / ")[0], floori(pos.x / 8.0), floori(pos.z / 8.0)]
		if not grupos.has(gk):
			grupos[gk] = []
		grupos[gk].append(a)
	s += "Totais (células de 2 m): %s\n\n" % str(por_tipo)
	s += "## Aglomerados (8 m)\n\n| tipo | nível | n | pos exemplo | épocas | partida | detalhe |\n|---|---|---|---|---|---|---|\n"
	var ks: Array = grupos.keys()
	ks.sort()
	for gk in ks:
		var g: Array = grupos[gk]
		var a0: Dictionary = g[0]
		var eps := {}
		var rots := {}
		for a in g:
			eps[a["epoca"]] = true
			rots[a["rot"]] = true
		var pp: Vector3 = a0["pos"]
		s += "| %s | %s | %d | (%.1f, %.1f, %.1f) | %s | %s | %s |\n" % [a0["tipo"], ", ".join(rots.keys()), g.size(), pp.x, pp.y, pp.z,
			",".join(eps.keys()), a0["partida"], a0["det"]]
	s += "\n## Todos os achados\n\n"
	for k in achados:
		var a: Dictionary = achados[k]
		var pp: Vector3 = a["pos"]
		var sp: Vector3 = a["ppos"]
		s += "- %s [%s] época %s sala %d pos (%.1f, %.1f, %.1f) partida %s (%.1f, %.1f, %.1f) x%d: %s\n" % [a["tipo"], a["rot"], a["epoca"], a["sala"], pp.x, pp.y, pp.z, a["partida"], sp.x, sp.y, sp.z, a["n"], a["det"]]
	s += "\n## Notas\n\n"
	for l in linhas_extra:
		s += "- " + l + "\n"
	f.store_string(s)
	f.close()
	print("\n==== RESUMO ====")
	print("totais: ", por_tipo)
	for gk in ks:
		var g: Array = grupos[gk]
		var a0: Dictionary = g[0]
		var pp: Vector3 = a0["pos"]
		print("%s  %s  n=%d  (%.1f, %.1f, %.1f)  %s  partida %s" % [a0["tipo"], a0["rot"], g.size(), pp.x, pp.y, pp.z, a0["det"], a0["partida"]])


func _arq_saida() -> String:
	var suf := OS.get_environment("FUGA_SUFIXO")
	return "res://tests/varredura/saida/fuga%s.md" % (("_" + suf) if suf != "" else "")
