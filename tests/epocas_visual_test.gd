extends SceneTree
## Épocas visualmente distintas (módulo 12): Tito vivo só em 1967 e fantasma depois (só visto em 1975 e 2019), props de
## 2019 só em 2019 e sem colisão, faixa "REABERTO" do presente por visita, subtítulo do Visor.
## Uso: godot --headless -s res://tests/epocas_visual_test.gd
## Obs.: autoloads e classes por get_node/load em runtime (ver tests/ui_test.gd).

const CASTELINHO := "res://world/niveis/castelinho.tscn"

var falhas := 0
var GS
var Ef
var main
var E: Dictionary = {}


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Ef = root.get_node("/root/Efeitos")
	E = {"1950": GS.Epoca.E1950, "1975": GS.Epoca.E1975, "2019": GS.Epoca.E2019, "2020": GS.Epoca.E2020, "1967": GS.Epoca.E1967}
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	await _visita(3)
	var n3: Node = main.mundo.get_child(0)
	await _tito_fantasma(n3)
	await _props_2019(n3)
	_faixa(n3, 3)
	await _subtitulo()
	await _visita(1)
	_faixa(main.mundo.get_child(0), 1)
	await _visita(2)
	_faixa(main.mundo.get_child(0), 2)
	await _visita(4)
	_faixa(main.mundo.get_child(0), 4)
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _visita(v: int) -> void:
	GS.novo_jogo()
	GS.visita = v
	GS.flags["tem_visor"] = true
	GS.flags["tem_lanterna"] = v >= 3
	GS.jogando = true
	main.hud.visible = true
	await main.carregar_mundo(CASTELINHO, "Spawn")
	for i in 3:
		await process_frame


func _epoca(nome: String) -> void:
	GS.trocar_epoca(E[nome])
	await process_frame


# ---------------------------------------------------------------- Tito fantasma
func _tito_fantasma(n: Node) -> void:
	print("-- Tito fantasma")
	var t: Node3D = n._tito_visor
	_checar(t != null, "visita 3 tem o Tito do Visor")
	if t == null:
		return
	_checar(t.has_meta("fantasma"), "o Tito do Visor é a variante fantasma")
	for par in [["1950", false], ["1967", false], ["1975", true], ["2019", true], ["2020", false]]:
		await _epoca(par[0])
		_checar(t.visible == par[1], "fantasma em %s: visível=%s (veio %s)" % [par[0], par[1], t.visible])
	# o Tito VIVO só existe em 1967
	var vivo: Node3D = n._tito
	for par in [["1950", false], ["1967", true], ["1975", false], ["2019", false], ["2020", false]]:
		await _epoca(par[0])
		_checar(vivo.visible == par[1], "Tito vivo em %s: visível=%s (veio %s)" % [par[0], par[1], vivo.visible])
	# pingos: CPU, poucas partículas, nada de GPUParticles3D
	var pingos := t.find_child("Pingos", true, false) as CPUParticles3D
	_checar(pingos != null and pingos.amount <= 12, "pingos do fantasma: CPUParticles3D com <= 12 partículas")
	_checar(t.find_children("*", "GPUParticles3D", true, false).is_empty(), "sem GPUParticles3D no fantasma")
	_checar(t.find_child("Poca", true, false) != null, "poça sob os pés do fantasma")
	# o Tito vivo continua com as cores normais (sem a meta)
	_checar(not vivo.has_meta("fantasma"), "o Tito de 1967 não é fantasma")


# ---------------------------------------------------------------- 2019
func _props_2019(n: Node) -> void:
	print("-- props de 2019")
	var castelo: Node = n.castelo
	var ruina := castelo.find_child("Ruina_2019", false, false) as Node3D
	var textos := castelo.find_child("Textos_2019", false, false) as Node3D
	_checar(ruina != null, "grupo Ruina_2019 existe")
	_checar(textos != null, "Textos_2019 (cartaz, pichação, letreiro, placa) existe")
	if ruina == null or textos == null:
		return
	for par in [["1950", false], ["1967", false], ["1975", false], ["2019", true], ["2020", false]]:
		await _epoca(par[0])
		_checar(ruina.visible == par[1], "Ruina_2019 em %s: visível=%s" % [par[0], par[1]])
		_checar(textos.visible == par[1], "Textos_2019 em %s: visível=%s" % [par[0], par[1]])
	# sem colisão: os textos não têm corpo físico; a única colisão do grupo é o deck (baixa, até 0,1 m)
	_checar(textos.find_children("*", "CollisionObject3D", true, false).is_empty(), "Textos_2019 sem colisão")
	var alta := 0
	for cs in ruina.find_children("*", "CollisionShape3D", true, false):
		var sh := (cs as CollisionShape3D).shape as BoxShape3D
		if sh and (cs as CollisionShape3D).global_position.y + sh.size.y * 0.5 > 0.12:
			alta += 1
	_checar(alta == 0, "Ruina_2019 não tem colisão acima do deck (tábuas, mesas e fitas não bloqueiam): %d alta(s)" % alta)
	# conteúdo: malha da ruína, cartaz, letreiro, placa e pichação
	var ext := ruina.get_node_or_null("Ext") as MeshInstance3D
	_checar(ext != null and ext.get_aabb().size.x > 5.0, "malha externa da ruína existe")
	var tem_cartaz := textos.find_child("Folha_procura_se", true, false) != null
	_checar(tem_cartaz, "cartaz de PROCURA-SE na fachada")
	var textos_3d: Array[String] = []
	for l in textos.find_children("*", "Label3D", true, false):
		textos_3d.append((l as Label3D).text)
	for esperado in ["CHOPERIA", "INTERDITADO", "CADÊ O TITO?"]:
		_checar(esperado in textos_3d, "texto '%s' na ruína" % esperado)


# ---------------------------------------------------------------- faixa do presente
func _faixa(n: Node, visita: int) -> void:
	print("-- faixa REABERTO, visita %d" % visita)
	var f := n.castelo.find_child("FaixaReaberto", false, false) as Node3D
	if visita >= 4:
		_checar(f == null, "visita 4: sem faixa")
		return
	_checar(f != null, "visita %d: faixa existe" % visita)
	if f == null:
		return
	var textos: Array[String] = []
	for l in f.find_children("*", "Label3D", true, false):
		textos.append((l as Label3D).text)
	_checar("REABERTO" in textos, "faixa diz REABERTO")
	_checar(textos.any(func(t: String) -> bool: return t.contains("SÁBADOS") and t.contains("9h")), "faixa diz VISITAS GUIADAS AOS SÁBADOS · 9h–17h")
	if visita == 3:
		_checar(absf(f.rotation_degrees.z) > 5.0, "visita 3: faixa pende torta (rasgada)")
	else:
		_checar(absf(f.rotation_degrees.z) < 0.5, "visitas 1 e 2: faixa reta")
	_checar(f.find_children("*", "CollisionObject3D", true, false).is_empty(), "faixa sem colisão")
	GS.trocar_epoca(E["2020"])
	_checar(f.visible, "faixa visível no presente")
	GS.trocar_epoca(E["2019"])
	_checar(not f.visible, "faixa some em 2019")
	GS.trocar_epoca(E["1967"])
	_checar(not f.visible, "faixa some em 1967")
	GS.trocar_epoca(E["2020"])


# ---------------------------------------------------------------- legenda do Visor
func _subtitulo() -> void:
	print("-- subtítulo do Visor")
	Ef.visor(true)
	await _epoca("1967")
	var l: Label = Ef._lbl_epoca
	_checar(l.visible and l.text.contains("1967"), "legenda em 1967 traz '1967' (veio '%s')" % l.text)
	_checar(l.text.contains("Tito"), "legenda em 1967 fala do Tito")
	await _epoca("2019")
	_checar(l.visible and l.text.contains("ruína"), "legenda em 2019 fala da ruína (veio '%s')" % l.text)
	await _epoca("1975")
	_checar(l.text.contains("veraneio"), "legenda em 1975 fala da casa de veraneio")
	await _epoca("1950")
	_checar(l.text.contains("pedra"), "legenda em 1950 fala do núcleo de pedra")
	await _epoca("2020")
	_checar(l.text == "" and not l.visible, "no presente não há subtítulo")
	Ef.visor(false)
	await process_frame


func _checar(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("  FALHA ", msg)
	else:
		print("  ok  ", msg)
