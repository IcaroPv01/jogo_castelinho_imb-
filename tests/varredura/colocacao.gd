extends SceneTree
## Verificador automático de COLOCAÇÃO de objetos 3D (fora do CI). Constrói cada nível/visita com o registro de `Malha`
## ligado (castelinho/malha.gd), varre a árvore de nós (castelinho/registro.gd) e roda as checagens de
## tests/varredura/colocacao_lib.gd: flutuando, enfiado/atravessa parede, fora da sala, z-fighting, frestas, degraus
## de piso, continuidade entre visitas/épocas.
## Uso: godot --headless -s res://tests/varredura/colocacao.gd [-- castelo ato2 barra porao braco]
## Saída: tests/varredura/saida/colocacao.json e colocacao.md (pasta ignorada pelo git).

const LIB := "res://tests/varredura/colocacao_lib.gd"
const SAIDA := "res://tests/varredura/saida/"

var GS
var main
var lib_gd: GDScript
var Malha: GDScript
var Registro: GDScript
var todos: Array = []                 # achados brutos
var tempos := {}
var inventario := {}                  # "nivel" -> {etiquetas}
var snapshots := {}                   # nivel -> {visita -> {etiqueta -> aabb centro}}
var t_ini := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	t_ini = Time.get_ticks_msec()
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	lib_gd = load(LIB)
	Malha = load("res://castelinho/malha.gd")
	Registro = load("res://castelinho/registro.gd")
	var quais: Array = []
	for a in OS.get_cmdline_user_args():
		quais.append(a)
	if quais.is_empty():
		quais = ["castelo", "ato2", "barra", "porao", "braco"]
	if "castelo" in quais:
		for v in [1, 2, 3, 4]:
			await _cenario_castelo(v)
	if "ato2" in quais:
		await _cenario_ato2()
	if "barra" in quais:
		await _cenario_barra()
	if "porao" in quais:
		await _cenario_porao()
	if "braco" in quais:
		await _cenario_braco()
	_continuidade()
	_escrever()
	print("TOTAL %.1f s" % ((Time.get_ticks_msec() - t_ini) / 1000.0))
	quit(0)


# ============================================================================ cenários
func _preparar_estado(visita: int, flags := {}) -> void:
	GS.novo_jogo()
	GS.visita = visita
	GS.flags["tem_visor"] = true
	for f in flags:
		GS.flags[f] = flags[f]
	GS.jogando = true
	main.hud.visible = true


func _carregar(caminho: String, nivel_nome: String) -> Node:
	Malha.ligar(nivel_nome)
	await main.carregar_mundo(caminho, "Spawn")
	for i in 3:
		await process_frame
	return main.mundo.get_child(0)


func _cenario_castelo(v: int) -> void:
	var t0 := Time.get_ticks_msec()
	_preparar_estado(v, {"tem_lanterna": v >= 3})
	var nivel: Node = await _carregar("res://world/niveis/castelinho.tscn", "castelo")
	Registro.varrer(nivel, "castelo")
	var salas := _salas_triggers(nivel)
	_analisar("castelo", v, salas)
	tempos["castelo_v%d" % v] = (Time.get_ticks_msec() - t0) / 1000.0


func _cenario_ato2() -> void:
	var t0 := Time.get_ticks_msec()
	_preparar_estado(3)
	var nivel: Node = await _carregar("res://world/niveis/ato2.tscn", "ato2")
	Registro.varrer(nivel, "ato2")
	_analisar("ato2", 3, _salas_triggers(nivel))
	tempos["ato2"] = (Time.get_ticks_msec() - t0) / 1000.0


func _cenario_barra() -> void:
	var t0 := Time.get_ticks_msec()
	_preparar_estado(2)
	var nivel: Node = await _carregar("res://world/niveis/barra.tscn", "barra")
	Registro.varrer(nivel, "barra")
	_analisar("barra", 2, Callable())
	tempos["barra"] = (Time.get_ticks_msec() - t0) / 1000.0


func _cenario_porao() -> void:
	var t0 := Time.get_ticks_msec()
	_preparar_estado(5)
	GS.set_flag("porao_semente", 4242)
	var nivel: Node = await _carregar("res://world/niveis/porao.tscn", "porao")
	for i in nivel.N:
		nivel._carregar_sala(i)
	await process_frame
	Registro.varrer(nivel, "porao")
	_analisar("porao", 5, Callable())
	tempos["porao"] = (Time.get_ticks_msec() - t0) / 1000.0


func _cenario_braco() -> void:
	var t0 := Time.get_ticks_msec()
	_preparar_estado(5)
	var nivel: Node = await _carregar("res://world/niveis/braco_morto.tscn", "braco")
	Registro.varrer(nivel, "braco")
	_analisar("braco", 5, Callable())
	tempos["braco"] = (Time.get_ticks_msec() - t0) / 1000.0


# ============================================================================ análise
const NOMES_SALA := {1: "calçada", 2: "gramado", 3: "lateral da torre", 4: "deck", 5: "arcada", 6: "porta de entrada", 7: "hall",
	8: "Povos/torre térreo", 9: "Meio Ambiente", 10: "corredor", 11: "Salão de Arte", 12: "Acervo", 13: "Pescador", 16: "pé da escada",
	17: "topo da Torre A", 18: "terraço da arcada", 19: "Torre B", 20: "terraço do pátio", 21: "Sala Medieval", 22: "saída", 23: "porta de saída",
	25: "corredor 1975", 80: "porta do porão"}


func _salas_triggers(nivel: Node) -> Callable:
	var lst: Array = []
	for t in nivel.find_children("*", "Area3D", true, false):
		if t.get("numero") != null and t.get("tamanho") != null:
			lst.append([t.get("numero"), (t as Node3D).global_position, t.get("tamanho")])
	return func(p: Vector3) -> String:
		var melhor := ""
		var bd := 1e9
		for t in lst:
			var c: Vector3 = t[1]
			var tam: Vector3 = t[2]
			var dx := maxf(0.0, absf(p.x - c.x) - tam.x * 0.5)
			var dz := maxf(0.0, absf(p.z - c.z) - tam.z * 0.5)
			var dy := 0.0
			if p.y < c.y - 0.5:
				dy = c.y - 0.5 - p.y
			elif p.y > c.y + tam.y + 0.8:
				dy = p.y - (c.y + tam.y + 0.8)
			var d := sqrt(dx * dx + dz * dz) + dy * 2.0
			if d < bd:
				bd = d
				melhor = "sala %d (%s)%s" % [t[0], NOMES_SALA.get(t[0], "?"), "" if d < 0.05 else " ~%.0f m" % d]
		return melhor


func _analisar(nivel: String, visita: int, sala_fn: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	var lib = lib_gd.new()
	lib.preparar(Malha.registro, Malha.materiais, {"nivel": nivel, "visita": visita, "sala_fn": sala_fn})
	var t1 := Time.get_ticks_msec()
	lib.checar_flutuando()
	var t2 := Time.get_ticks_msec()
	lib.checar_enfiado()
	var t3 := Time.get_ticks_msec()
	lib.checar_zfight()
	var t4 := Time.get_ticks_msec()
	lib.checar_frestas()
	var t5 := Time.get_ticks_msec()
	lib.checar_degraus()
	var t6 := Time.get_ticks_msec()
	print("[%s v%d] entradas %d, objetos(clusters) %d | prep %d ms, flut %d, enf %d, zf %d, fresta %d, degrau %d | achados %d" % [nivel, visita,
		Malha.registro.size(), lib._clusters.size(), t1 - t0, t2 - t1, t3 - t2, t4 - t3, t5 - t4, t6 - t5, lib.achados.size()])
	todos.append_array(lib.achados)
	var dbg := OS.get_environment("COLOC_DEBUG")
	if dbg != "" and visita == int(OS.get_environment("COLOC_DEBUG_V") if OS.get_environment("COLOC_DEBUG_V") != "" else visita):
		lib.depurar(dbg.split(","))
	# inventário e snapshot para a continuidade
	var inv: Dictionary = Malha.info_por_etiqueta()
	var snap := {}
	for e in lib.es:
		var ee = e
		if ee.obj:
			var k: String = ee.et
			if not snap.has(k):
				snap[k] = AABB(ee.mn, ee.mx - ee.mn)
			else:
				snap[k] = (snap[k] as AABB).merge(AABB(ee.mn, ee.mx - ee.mn))
	if not snapshots.has(nivel):
		snapshots[nivel] = {}
	snapshots[nivel][visita] = snap
	if not inventario.has(nivel):
		inventario[nivel] = {}
	for k in snap:
		inventario[nivel][k] = true


func _continuidade() -> void:
	for nivel in snapshots:
		var por_v: Dictionary = snapshots[nivel]
		if por_v.size() < 2:
			continue
		var vs: Array = por_v.keys()
		vs.sort()
		var todas_et := {}
		for v in vs:
			for k in por_v[v]:
				todas_et[k] = true
		for k in todas_et:
			var presentes: Array = []
			for v in vs:
				if por_v[v].has(k):
					presentes.append(v)
			if presentes.size() < vs.size():
				var aa: AABB = por_v[presentes[0]][k]
				todos.append(_achado_simples("continuidade", "B", nivel, presentes[0], k, aa.get_center(), 0.0,
					"objeto existe só nas visitas %s (de %s)" % [str(presentes), str(vs)], true, "pode ser conteúdo específico da visita"))
			for i in range(1, presentes.size()):
				var a: AABB = por_v[presentes[0]][k]
				var b: AABB = por_v[presentes[i]][k]
				var d := a.get_center().distance_to(b.get_center())
				var ds := a.size.distance_to(b.size)
				if d > 0.05 or ds > 0.05:
					todos.append(_achado_simples("continuidade", "M", nivel, presentes[i], k, b.get_center(), maxf(d, ds) * 100.0,
						"muda de posição/tamanho entre visita %d e %d: centro %.2f m, tamanho %.2f m" % [presentes[0], presentes[i], d, ds], false, ""))


func _achado_simples(tipo: String, grav: String, nivel: String, visita: int, et: String, p: Vector3, cm: float, desc: String, intenc: bool, motivo: String) -> Dictionary:
	return {"tipo": tipo, "gravidade": grav, "nivel": nivel, "visita": visita, "epocas": ["?"], "sala": "", "etiqueta": et, "no": "",
		"posicao": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "medida_cm": snappedf(cm, 0.1), "detalhe": desc,
		"arquivo": "", "pilha": "", "provavel_intencional": intenc, "motivo": motivo}


# ============================================================================ relatório
func _consolidar() -> Array:
	# mesma coisa em várias visitas: junta
	var mapa := {}
	var ordem: Array = []
	for a in todos:
		var d: Dictionary = a
		var pos: Array = d["posicao"]
		var chave := "%s|%s|%s|%s|%.1f,%.1f,%.1f|%s" % [d["tipo"], d["nivel"], d["etiqueta"], d.get("outro", ""), pos[0], pos[1], pos[2], d["arquivo"]]
		if mapa.has(chave):
			var m: Dictionary = mapa[chave]
			if not (d["visita"] in m["visitas"]):
				m["visitas"].append(d["visita"])
		else:
			var m := d.duplicate(true)
			m["visitas"] = [d["visita"]]
			m.erase("visita")
			mapa[chave] = m
			ordem.append(m)
	return ordem


func _escrever() -> void:
	var lista := _consolidar()
	var peso := {"A": 0, "M": 1, "B": 2}
	lista.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["provavel_intencional"] != y["provavel_intencional"]:
			return not x["provavel_intencional"]
		if peso[x["gravidade"]] != peso[y["gravidade"]]:
			return peso[x["gravidade"]] < peso[y["gravidade"]]
		return float(x["medida_cm"]) > float(y["medida_cm"]))
	var contagem := {}
	for a in lista:
		var k: String = "%s%s" % [a["tipo"], " (provável intencional)" if a["provavel_intencional"] else ""]
		contagem[k] = contagem.get(k, 0) + 1
	var dur := (Time.get_ticks_msec() - t_ini) / 1000.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var json := {"gerado_em": Time.get_datetime_string_from_system(), "duracao_s": dur, "tempos_s": tempos, "contagem": contagem, "achados": lista}
	var f := FileAccess.open(SAIDA + "colocacao.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json, "  "))
	f.close()
	var md := PackedStringArray()
	md.append("# Verificador de colocação\n")
	md.append("Duração: %.1f s. Achados: %d (únicos).\n" % [dur, lista.size()])
	md.append("## Contagem por tipo\n")
	for k in contagem:
		md.append("- %s: %d" % [k, contagem[k]])
	md.append("\n## Achados (reais primeiro; A = alta, M = média, B = baixa)\n")
	md.append("| tipo | grav | nível | visitas | épocas | sala | etiqueta | medida (cm) | arquivo:linha | intencional? | detalhe |")
	md.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for a in lista:
		md.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [a["tipo"], a["gravidade"], a["nivel"], str(a["visitas"]), ",".join(PackedStringArray(a["epocas"])), a["sala"],
			a["etiqueta"], a["medida_cm"], a["arquivo"], ("sim: " + a["motivo"]) if a["provavel_intencional"] else "não", String(a["detalhe"]).replace("|", "/")])
	var f2 := FileAccess.open(SAIDA + "colocacao.md", FileAccess.WRITE)
	f2.store_string("\n".join(md))
	f2.close()
	print("CONTAGEM ", contagem)
