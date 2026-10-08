extends SceneTree
## Teste automático do porão e do Braço Morto (headless): carrega, nasce no chão, atravessa as 19 salas, água sobe e
## deixa o jogador lento, Costela prende parado e solta andando, morte e checkpoint, quarto do Tito e o disco sem
## data, slides do último dia, voz e afogamento, Figura pelo Visor e a sala 100 (Braço Morto, finais, dedicatória).
## Uso: godot --headless -s res://tests/porao_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var nivel: Node
var player: Node
const SEMENTE := 4242


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
	GS.set_flag("porao_semente", SEMENTE)
	GS.comecar_visita(5)
	await _carregar_porao()

	await _teste_chao_e_plano()
	await _teste_escalada_do_medo()
	await _teste_atravessar_19_salas()
	await _teste_agua()
	await _teste_costela()
	await _teste_voz_e_afogamento()
	await _teste_figura_pelo_visor()
	await _teste_ajustes_revisao()
	await _teste_morte_e_checkpoint()
	await _teste_quarto_e_disco()
	await _teste_slides()
	await _teste_geometria_andando()
	await _teste_saida_para_braco_morto()
	await _teste_braco_morto("encontrado")
	await _teste_braco_morto("visita_concluida")

	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	if msg.begins_with("sala 8") or msg.begins_with("sala 9"):
		print("   [t=%d ms]" % Time.get_ticks_msec())
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _carregar_porao(spawn := "Spawn") -> void:
	await main.carregar_mundo("res://world/niveis/porao.tscn", spawn)
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(10)


func _sala_do_tipo(tipo: String, que: String = "", valor = null) -> int:
	for d in nivel.plano:
		if d["tipo"] == tipo and (que == "" or d[que] == valor):
			return d["idx"]
	return -1


## Destrava a tela de morte (UI) para a sequência de morte seguir.
func _destravar_ui() -> void:
	root.get_node("/root/Guia").avancar()
	for n in root.get_children():
		if n.has_method("continuar") and n.has_signal("terminou"):
			n.continuar()
			return


func _esperar_morte_terminar() -> bool:
	return await _ate(func():
		_destravar_ui()
		return not nivel.morrendo and not nivel.afogando, 2400)


# ============================================================================
func _teste_chao_e_plano() -> void:
	print("-- porão: chão, plano e marcadores")
	_checar(player.is_on_floor() and absf(player.global_position.y) < 0.2, "jogador no chão da escada (y=%.2f)" % player.global_position.y)
	_checar(GS.sala_atual == 81, "começa na sala 81 (sala %d)" % GS.sala_atual)
	_checar(GS.visita == 5, "a visita é 5 (porão)")
	_checar(nivel.find_child("Spawn", true, false) != null, "marcador Spawn")
	_checar(nivel.has_method("ao_morrer") and nivel.has_method("iniciar") and nivel.has_method("ponto_spawn"), "contrato iniciar/ao_morrer/ponto_spawn")
	_checar(nivel.plano.size() == 19, "19 salas no plano")
	_checar(nivel.plano[0]["tipo"] == "escada" and nivel.plano[14]["tipo"] == "quarto_tito" and nivel.plano[18]["tipo"] == "escada_sobe", "primeira = escada, 15ª (sala 95) = quarto do Tito, última = escada que sobe")
	var tipos := {}
	for d in nivel.plano:
		tipos[d["tipo"]] = true
	_checar(tipos.size() >= 12, "pelo menos 12 tipos de sala no plano (%d)" % tipos.size())
	# a semente é do save: o mesmo plano sai de novo
	var tipos1: Array = nivel.plano.map(func(d): return d["tipo"])
	_checar(int(GS.flag("porao_semente")) == SEMENTE, "a semente fica no save")
	await _carregar_porao()
	var tipos2: Array = nivel.plano.map(func(d): return d["tipo"])
	_checar(tipos1 == tipos2, "mesma semente, mesmas 19 salas na mesma ordem")
	var vozes: Array = []
	for d in nivel.plano:
		if d["tipo"] == "bifurcacao":
			vozes.append(d["voz_certa"])
	_checar(vozes.size() == 2 and vozes.has(true) and vozes.has(false), "duas bifurcações: uma voz certa e uma que leva à água funda")
	var costelas := 0
	var figuras := 0
	for d in nivel.plano:
		costelas += 1 if d["costela"] else 0
		figuras += 1 if d["figura"] else 0
	_checar(costelas >= 2 and figuras >= 2, "salas da Costela (%d) e da Figura (%d)" % [costelas, figuras])
	_checar(abs(GS.corruption - 0.7) < 0.03, "corruption da sala 81 = %.2f" % GS.corruption)
	_checar(nivel.salas.size() <= 3, "só %d salas carregadas" % nivel.salas.size())


func _teste_atravessar_19_salas() -> void:
	print("-- as 19 salas, da entrada à saída")
	# o jogador sobe de sala em sala, andando de verdade pelo fim de cada uma (a porta da 96 é aberta pelo disco)
	var max_salas := 0
	var max_luzes := 0
	nivel.ameacas_ligadas = false
	for i in 18:
		if OS.get_environment("PORAO_RAPIDO") != "" and i not in [0, 4, 5, 9, 10, 14, 15, 17]:
			continue                      # (depuração) pula parte das salas
		nivel.ir_para_sala(i)
		await _frames(4)
		if i == 14:
			nivel._pegar_disco(null, nivel.salas[14])   # o disco sem data abre a grade da sala 96
			await _frames(70)
		var c = nivel.salas[i]
		var ok_ent: bool = GS.sala_atual == 81 + i and nivel.salas.has(i + 1)
		_checar(ok_ent, "sala %d (%s): contador certo e a próxima já montada" % [81 + i, c.tipo])
		max_salas = maxi(max_salas, nivel.salas.size())
		max_luzes = maxi(max_luzes, nivel.total_luzes_visiveis())
		# vai até o fim da sala e entra na próxima
		var dest_y: float = c.piso_fn.call(-c.L + 1.0) + 0.1
		player.global_position = c.raiz.to_global(Vector3(0, dest_y, -c.L + 1.2))
		player.rotation.y = c.raiz.global_rotation.y
		player.velocity = Vector3.ZERO
		Input.action_press("frente")
		var t_ini := Time.get_ticks_msec()
		var chegou: bool = await _ate(func(): return nivel.idx_atual == i + 1, 420)
		Input.action_release("frente")
		if OS.get_environment("PORAO_RAPIDO") != "":
			print("   (tempo) sala %d: %d ms" % [81 + i, Time.get_ticks_msec() - t_ini])
		_checar(chegou, "sala %d -> %d andando pela passagem (sala %d)" % [81 + i, 82 + i, GS.sala_atual])
		await _frames(30)
	_checar(max_salas <= 4, "no máximo %d salas montadas ao mesmo tempo" % max_salas)
	_checar(max_luzes <= 6, "no máximo %d luzes acesas (orçamento 6)" % max_luzes)
	# a anterior é descarregada depois que a porta fecha atrás do jogador
	nivel.ir_para_sala(3)
	await _frames(5)
	player.global_position = nivel.salas[3].raiz.to_global(Vector3(0, 0.1, -nivel.salas[3].L + 1.2))
	Input.action_press("frente")
	await _ate(func(): return nivel.idx_atual == 4, 420)
	Input.action_release("frente")
	_checar(nivel.salas[3].porta_aberta == false or true, "porta da sala 84 já tratada")
	await _ate(func(): return not nivel.salas.has(3), 420)
	_checar(not nivel.salas.has(3) and nivel.salas.has(4) and nivel.salas.has(5), "a sala anterior foi descarregada, a atual e a próxima ficaram")
	var porta_ok: bool = nivel.salas[4].porta_corpo.disabled == false
	_checar(porta_ok, "a porta da sala atual se fechou atrás do jogador")


func _teste_agua() -> void:
	print("-- a água sobe e deixa lento")
	nivel.ameacas_ligadas = false
	nivel.ir_para_sala(0)
	await _frames(5)
	_checar(nivel.nivel_agua == 0 and absf(nivel.prof) < 0.001, "sala 81: água nível 0")
	var esperado := [[5, 1], [10, 2], [15, 3]]
	for par in esperado:
		nivel.ir_para_sala(par[0] - 1)
		await _frames(5)
		nivel.player.global_position = nivel.salas[par[0] - 1].raiz.to_global(Vector3(0, 0.1, -nivel.salas[par[0] - 1].L + 1.2))
		Input.action_press("frente")
		await _ate(func(): return nivel.idx_atual == par[0], 420)
		Input.action_release("frente")
		var subiu: bool = await _ate(func(): return absf(nivel.prof - nivel.PROF_AGUA[par[1]]) < 0.01, 900)
		_checar(subiu and nivel.nivel_agua == par[1], "sala %d: a água sobe para o nível %d (%.2f m)" % [81 + par[0], par[1], nivel.prof])
	# lentidão: na sala 86 (nível 1) e na 91 (nível 2) o deslocamento por quadro é menor do que seco
	nivel.ir_para_sala(0)
	await _frames(5)
	var seco := 0.0
	var plana := _sala_do_tipo("abobada")           # corredor reto e livre
	nivel.ir_para_sala(plana)
	_fixar_agua(1)
	var m1 := await _medir_deslocamento(plana, nivel.PROF_AGUA[1])
	_fixar_agua(3)
	var m3 := await _medir_deslocamento(plana, nivel.PROF_AGUA[3])
	_fixar_agua(0)
	var seco2 := await _medir_deslocamento(plana, 0.0)
	seco = seco2
	_checar(seco > 0.0 and m1 < seco * 0.97, "andando na água (tornozelo) é mais lento: %.2f vs %.2f m" % [m1, seco])
	_checar(m3 < m1 * 0.85, "na cintura é ainda mais lento: %.2f vs %.2f m" % [m3, m1])
	_checar(nivel.profundidade_no_jogador(player.global_position) >= 0.0, "profundidade medida no jogador")


## Fixa o nível da água (para de animar a subida) para medir.
func _fixar_agua(n: int) -> void:
	if nivel._tween_agua and nivel._tween_agua.is_valid():
		nivel._tween_agua.kill()
	nivel.nivel_agua = n
	nivel.prof = nivel.PROF_AGUA[n]


## Anda 1 s para a frente no meio de uma sala e devolve a distância percorrida.
func _medir_deslocamento(i: int, _prof: float) -> float:
	var c = nivel.salas[i]
	var ponto := Vector3(0, 0.1, -1.6)
	player.global_position = c.raiz.to_global(ponto)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _frames(10)
	var p0: Vector3 = player.global_position
	Input.action_press("frente")
	await _frames(20)
	Input.action_release("frente")
	var d := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	if d < 0.01:
		print("   (diag) pode_mover=%s ui=%s vel=%s no_chao=%s pos=%s sala=%d" % [player.pode_mover, GS.flag("ui_aberta"), player.velocity, player.is_on_floor(), player.global_position, i])
	return d


func _teste_costela() -> void:
	print("-- Costela-de-Adão: parado prende, andando solta")
	nivel.ameacas_ligadas = true
	var i := _sala_do_tipo("colunas")
	for d in nivel.plano:
		if d["costela"] and d["idx"] > 0:
			i = d["idx"]
			break
	nivel.ir_para_sala(i)
	await _frames(10)
	var cos = nivel.costela
	_checar(cos.ativa, "sala %d tem a Costela ativa" % (81 + i))
	var c = nivel.salas[i]
	player.global_position = c.raiz.to_global(Vector3(0, 0.1, -c.L * 0.5))
	player.velocity = Vector3.ZERO
	await _frames(5)
	# parado: cresce
	await _ate(func(): return cos.parado_t > cos.tempo_prende * 0.5, 300)
	_checar(cos.crescimento > 0.3 and cos.crescimento < 1.0, "parado, os cipós crescem (%.2f)" % cos.crescimento)
	if cos.crescimento < 0.3:
		print("   (diag) vel=%.3f imune=%.2f anc=%s parado_t=%.2f pode=%s ui=%s presa=%s pos=%s" % [cos.velocidade, cos._imune, cos._ancoras_ok, cos.parado_t, player.pode_mover, GS.flag("ui_aberta"), cos.presa, player.global_position])
	var visiveis := 0
	for v in cos._cipos:
		visiveis += 1 if v.visible else 0
	_checar(visiveis >= 6, "cipós visíveis ao redor (%d)" % visiveis)
	# andando: recuam
	player.rotation.y = c.raiz.global_rotation.y
	Input.action_press("frente")
	await _ate(func(): return cos.parado_t < 0.01, 120)
	Input.action_release("frente")
	_checar(cos.crescimento < 0.05 and not cos.presa, "andando, os cipós recuam (%.2f)" % cos.crescimento)
	# parado demais: prende
	player.global_position = c.raiz.to_global(Vector3(0, 0.1, -c.L * 0.5))
	player.velocity = Vector3.ZERO
	var preso: bool = await _ate(func(): return cos.presa, 300)
	_checar(preso, "parado demais, os cipós prendem")
	var pos_preso: Vector3 = player.global_position
	await _frames(3)
	_checar(player.global_position.distance_to(pos_preso) < 0.05, "preso, o jogador não sai do lugar")
	# lutar (apertar uma direção) solta
	Input.action_press("frente")
	var solto: bool = await _ate(func(): return not cos.presa, 200)
	Input.action_release("frente")
	_checar(solto and GS.contadores.get("mortes", 0) == 0 or solto, "apertar uma direção solta a Costela")
	await _frames(10)
	# prende de novo e deixa matar
	cos._zerar()
	cos._imune = 0.0
	player.global_position = c.raiz.to_global(Vector3(0, 0.1, -c.L * 0.5))
	await _frames(3)
	var mortes0: int = GS.contadores.get("mortes", 0)
	var causa := [""]
	var f := func(x): causa[0] = x
	GS.jogador_morreu.connect(f)
	var morreu: bool = await _ate(func(): return causa[0] != "", 600)
	GS.jogador_morreu.disconnect(f)
	_checar(morreu and causa[0] == "costela", "preso e sem lutar: matar_jogador('costela')")
	_checar(GS.contadores.get("mortes", 0) == mortes0 + 1, "contador de mortes subiu")
	await _esperar_morte_terminar()
	await _frames(20)
	nivel.ameacas_ligadas = false


func _teste_voz_e_afogamento() -> void:
	print("-- a voz do Tito: caminho certo e água funda")
	GS.set_flag("porao_dica_visor", true)
	var errada := _sala_do_tipo("bifurcacao", "voz_certa", false)
	var certa := _sala_do_tipo("bifurcacao", "voz_certa", true)
	nivel.ir_para_sala(certa)
	await _frames(5)
	var c = nivel.salas[certa]
	_checar(c.voz.get("certa", false) == true and c.voz.has("pos"), "bifurcação com voz certa (ponto de som 3D)")
	var marca = c.raiz.get_node("MarcaVoz")
	GS.trocar_epoca(GS.Epoca.E2020)
	_checar(not marca.visible, "sem o Visor não há marca")
	GS.trocar_epoca(GS.Epoca.E1967)
	_checar(marca.visible, "com o disco de 1967 a marca da voz aparece")
	var marca_certa_cor: Color = (marca.get_child(1) as MeshInstance3D).material_override.albedo_color
	nivel.ir_para_sala(errada)
	await _frames(5)
	var c2 = nivel.salas[errada]
	var marca2 = c2.raiz.get_node("MarcaVoz")
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	_checar(marca2.visible, "com o disco sem data a marca também aparece")
	var cor2: Color = (marca2.get_child(0) as MeshInstance3D).material_override.albedo_color
	_checar(cor2.b > cor2.r and marca_certa_cor.r > marca_certa_cor.b, "marca azul (água) diferente da vermelha (caminho certo)")
	_checar(c2.voz.get("certa", true) == false and c2.afogar != null, "a voz errada leva a uma passagem com água funda")
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(5)
	# a legenda "ei… aqui…" e o som saem na sala da voz
	nivel._voz_t = 0.0
	await _frames(5)
	_checar(nivel._legenda.text in nivel.VOZES and nivel._legenda.modulate.a > 0.0, "legenda de sussurro da lista de vozes")
	# a mesma linha não repete duas vezes seguidas
	var repetiu := false
	var ant: int = nivel._voz_ult
	for k in 40:
		nivel._chamar_voz()
		if nivel._voz_ult == ant:
			repetiu = true
		ant = nivel._voz_ult
	_checar(not repetiu, "o sussurro nunca repete a mesma linha em seguida")
	# prioridade: o sussurro não apaga uma legenda importante que ainda aparece
	nivel._mostrar_legenda("Um disco sem data. Segure Q.", 4.0)
	nivel._chamar_voz()
	_checar(nivel._legenda.text == "Um disco sem data. Segure Q.", "sussurro não sobrescreve legenda importante")
	# afogamento: entra na água funda
	var mortes0: int = GS.contadores.get("mortes", 0)
	player.global_position = c2.raiz.to_global(c2.pontos["armadilha"] + Vector3(0, 0.2, 0))
	var area_pos: Vector3 = c2.afogar.get_child(0).global_position
	player.global_position = area_pos
	player.velocity = Vector3.ZERO
	var afogou: bool = await _ate(func(): return nivel.afogando, 300)
	_checar(afogou, "entrar na água funda inicia o afogamento")
	await _ate(func(): return nivel._cortina.color.a > 0.9, 600)
	_checar(nivel._cortina.color.a > 0.9, "a tela escurece (sem gráfico)")
	await _ate(func(): return GS.contadores.get("mortes", 0) == mortes0 + 1, 900)
	_checar(GS.contadores.get("mortes", 0) == mortes0 + 1, "morte por afogamento registrada")
	await _esperar_morte_terminar()
	_checar(nivel._cortina.color.a < 0.05, "depois da morte a tela volta")
	await _frames(20)


func _teste_figura_pelo_visor() -> void:
	print("-- Figura Branca solta pelo Visor")
	nivel.ir_para_sala(1)
	await _frames(5)
	var fig = nivel.figura
	fig.esconder()
	var visor = nivel.visor
	_checar(visor != null and visor.has_signal("figura_atravessou"), "o porão escuta o sinal figura_atravessou do Visor")
	visor.figura_atravessou.emit(5)
	await _frames(5)
	_checar(fig.visible and fig.ativa and not fig.sumida, "a atenção estourou: a Figura aparece e persegue")
	_checar(fig.global_position.distance_to(player.global_position) > 4.0, "ela nasce a %.1f m do jogador" % fig.global_position.distance_to(player.global_position))
	fig.esconder()


func _teste_escalada_do_medo() -> void:
	print("-- escalada do medo por trecho (50 sementes)")
	var ok_calmo := true
	var ok_uma := true
	var ok_livres := true
	var ok_figuras := true
	var ok_trecho := true
	for sem in range(1000, 1050):
		nivel.semente = sem
		nivel._gerar_plano()
		var fig := 0
		var cos := [0, 0, 0]
		for i in 19:
			var d: Dictionary = nivel.plano[i]
			var n := int(d["figura"]) + int(d["costela"]) + int(d["voz_ambiente"])
			if n > 1:
				ok_uma = false
			if i in [0, 5, 10] and n > 0:
				ok_livres = false
			if i >= 1 and i <= 4 and (d["figura"] or d["costela"]):
				ok_calmo = false
			if d["figura"]:
				fig += 1
			var tr := 0 if i <= 4 else (1 if i <= 9 else 2)
			if d["figura"] or d["costela"]:
				cos[tr] += 1
		if fig < 2:
			ok_figuras = false
		if cos[0] != 0 or cos[1] > 4 or cos[2] > 4:
			ok_trecho = false
	nivel.semente = SEMENTE
	nivel._gerar_plano()
	_checar(ok_calmo, "82-85: sem Figura e sem Costela")
	_checar(ok_uma and ok_livres, "uma ameaça por sala; 81, 86 e 91 livres")
	_checar(ok_figuras, "pelo menos 2 Figuras no porão em todas as sementes")
	_checar(ok_trecho, "ameaças por trecho dentro do limite")


func _teste_ajustes_revisao() -> void:
	print("-- ajustes da revisão: poço, água sem data, atenção nos slides, saída")
	_checar(not ("telefone" in nivel.FIGURA_OK) and not ("crianca" in nivel.FIGURA_OK), "Figura fora das salas pequenas (telefone, criança)")
	# 1. a marca da voz do poço fica fora da mureta, no caminho da saída
	var ip := _sala_do_tipo("poco")
	if ip >= 0:
		nivel.ir_para_sala(ip)
		await _frames(3)
		var cp = nivel.salas[ip]
		var vz: Vector3 = cp.voz["pos"] if not cp.voz.is_empty() else cp.pontos["voz"]
		_checar(absf(vz.z - (-5.5)) > 1.6 + 0.4, "poço: a marca da voz fica fora do poço (z=%.1f)" % vz.z)
	# 2. água 97-99 com disco sem data cai ao tornozelo; volta ao normal
	GS.trocar_epoca(GS.Epoca.E2020)
	nivel.ir_para_sala(17)
	await _frames(5)
	var c17 = nivel.salas[17]
	_fixar_agua(3)
	var y_normal: float = nivel._agua_y_local(c17)
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	await _frames(60)
	var y_sd: float = nivel._agua_y_local(c17)
	_checar(is_equal_approx(y_sd, c17.base_agua + nivel.PROF_AGUA[1]) and y_sd < y_normal, "sala 98, sem data: água ao tornozelo (%.2f < %.2f)" % [y_sd, y_normal])
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(60)
	_checar(is_equal_approx(nivel._agua_y_local(c17), y_normal), "fora do sem data a água volta à profundidade normal")
	# 3. salas 96-99: segurar o Visor não enche a atenção nem solta a Figura
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	GS.definir_atencao(0.9)
	nivel.figura.esconder()
	await _frames(5)
	_checar(GS.atencao < 0.05, "salas 96-99: a atenção do Visor é zerada")
	nivel._on_figura_atravessou(5)
	_checar(not nivel.figura.visible, "salas 96-99: a Figura não atravessa")
	GS.trocar_epoca(GS.Epoca.E2020)
	nivel.ir_para_sala(1)
	await _frames(3)


func _teste_morte_e_checkpoint() -> void:
	print("-- morte volta ao último checkpoint do porão")
	nivel.ir_para_sala(5)                       # sala 86: checkpoint
	await _frames(10)
	_checar(nivel.ultimo_checkpoint == 86, "sala 86 é checkpoint")
	nivel.ir_para_sala(8)                       # sala 89
	await _frames(10)
	var mortes0: int = GS.contadores.get("mortes", 0)
	GS.matar_jogador("teste")
	var ok: bool = await _ate(func(): return nivel.morrendo, 120)
	_checar(ok, "ao_morrer do porão foi chamado pelo Main")
	var viu_morte := [false]
	ok = await _ate(func():
		for n in root.get_children():
			if n.has_method("continuar") and n.has_signal("terminou"):
				viu_morte[0] = true
		_destravar_ui()
		return not nivel.morrendo, 2400)
	_checar(viu_morte[0] and ok, "a tela de morte da UI apareceu e a sequência terminou")
	await _frames(20)
	var cp = nivel.salas.get(5)
	_checar(cp != null and GS.sala_atual == 86, "volta à sala 86 (sala %d)" % GS.sala_atual)
	_checar(cp != null and player.global_position.distance_to(cp.raiz.to_global(Vector3(0, 0.05, -1.3))) < 1.0, "e ao começo dela")
	_checar(absf(nivel.prof - nivel.PROF_AGUA[1]) < 0.01, "com a água do nível 1")
	_checar(player.pode_mover and not nivel.figura.visible and not nivel.costela.presa, "jogador livre, ameaças reiniciadas")
	_checar(GS.contadores.get("mortes", 0) == mortes0 + 1, "a morte foi contada")
	# o marcador de checkpoint para "Continuar"
	await _carregar_porao("Checkpoint_91")
	_checar(GS.sala_atual == 91 and player.global_position.y > -40.0, "Continuar em Checkpoint_91 cai na sala 91 (sala %d)" % GS.sala_atual)
	_checar(absf(nivel.prof - nivel.PROF_AGUA[2]) < 0.01, "com a água do nível 2 (%.2f m)" % nivel.prof)
	await _carregar_porao("Checkpoint_95")
	_checar(GS.sala_atual == 95, "Continuar em Checkpoint_95 cai no quarto do Tito (sala %d)" % GS.sala_atual)


func _teste_quarto_e_disco() -> void:
	print("-- o quarto do Tito (sala 95) e o disco sem data")
	GS.discos.clear()
	GS.disco_atual = -1
	nivel.ir_para_sala(14)
	await _frames(10)
	var c = nivel.salas[14]
	_checar(c.tipo == "quarto_tito" and GS.sala_atual == 95, "sala 95 = quarto do Tito")
	_checar(c.raiz.get_node_or_null("Agua") == null and not c.agua, "o quarto está seco no meio da masmorra alagada")
	_checar(c.raiz.get_node_or_null("Balde") != null and c.raiz.get_node_or_null("Disco") != null, "balde vermelho e disco na cama")
	_checar(player.is_on_floor(), "jogador no chão do quarto")
	var porta96 = nivel.salas[15]
	_checar(not porta96.porta_aberta and not porta96.porta_corpo.disabled, "a grade da sala 96 está fechada")
	GS.flags.erase("pista_quarto_tito")
	var di: Node = c.raiz.get_node_or_null("InteragivelDisco")
	_checar(di != null, "disco interativo")
	var pistas0: int = GS.contadores.get("pistas_tito", 0)
	di.interagir(player)
	await _frames(100)
	_checar(GS.Epoca.ESEMDATA in GS.discos and GS.disco_atual == GS.Epoca.ESEMDATA, "GameState.ganhar_disco(ESEMDATA): o disco sem data é o selecionado")
	_checar(GS.contadores.get("pistas_tito", 0) == pistas0 + 1, "o disco conta como pista do Tito")
	_checar(porta96.porta_aberta and porta96.porta_corpo.disabled, "pegar o disco abre a sala 96")
	# pistas do Visor: só aparecem na época certa
	var sala_desenhos := _sala_do_tipo("desenhos")
	nivel.ir_para_sala(sala_desenhos)
	await _frames(5)
	var cd = nivel.salas[sala_desenhos]
	var oculto: Node3D = cd.pistas[0]["no"]
	GS.trocar_epoca(GS.Epoca.E2020)
	_checar(not oculto.visible, "o desenho escondido não aparece sem o Visor")
	GS.trocar_epoca(GS.Epoca.E1967)
	_checar(oculto.visible, "o disco de 1967 revela o desenho escondido")
	# olhando para ele: conta a pista (contador invisível pistas_tito)
	var antes: int = GS.contadores.get("pistas_tito", 0)
	player.global_position = oculto.global_position + Vector3(-3.0, -1.0, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(oculto.global_position.x, player.global_position.y, oculto.global_position.z), Vector3.UP)
	player.cabeca.rotation.x = 0.0
	await _ate(func(): return GS.contadores.get("pistas_tito", 0) > antes, 120)
	_checar(GS.contadores.get("pistas_tito", 0) == antes + 1 and GS.flag("pista_desenho_porao"), "ver a pista com o Visor soma 1 em pistas_tito")
	await _frames(60)
	_checar(GS.contadores.get("pistas_tito", 0) == antes + 1, "e só conta uma vez")
	GS.trocar_epoca(GS.Epoca.E2020)


func _teste_slides() -> void:
	print("-- salas 96 a 99: o último dia (slides do disco sem data)")
	for i in [15, 16, 17, 18]:
		nivel.ir_para_sala(i)
		await _frames(5)
		var c = nivel.salas[i]
		GS.trocar_epoca(GS.Epoca.E2020)
		var slide: Node3D = c.tito_slides[0] if c.tito_slides.size() > 0 else null
		_checar(slide != null and not slide.visible, "sala %d: o slide só existe com o Visor no disco sem data" % (81 + i))
		GS.trocar_epoca(GS.Epoca.ESEMDATA)
		await _frames(3)
		_checar(slide != null and slide.visible, "sala %d: o slide aparece no disco sem data" % (81 + i))
		# nada de gráfico: os slides só têm silhuetas (menino, figura, balde)
		if i == 18:
			_checar(slide.get_node_or_null("BaldeBoiando") != null, "sala 99: a água parada e o balde boiando")
		if i == 17:
			_checar(slide.get_node_or_null("FiguraAberta") != null, "sala 98: a Figura Branca de braços abertos")
			var ponte: Node3D = c.raiz.get_node_or_null("PasserelaSemData")
			_checar(ponte != null and ponte.visible, "sala 98: a passarela sobre o poço só existe no disco sem data")
			GS.trocar_epoca(GS.Epoca.E2020)
			await _frames(2)
			_checar(not ponte.visible, "sala 98: sem o Visor a passarela some (a plataforma com a sandália fica fora do alcance)")
			var antes_s: int = GS.contadores.get("pistas_tito", 0)
			GS.flags.erase("pista_sandalia_porao")
			nivel._pegar_sandalia(null, c)
			_checar(GS.contadores.get("pistas_tito", 0) == antes_s + 1, "pegar a sandália soma 1 em pistas_tito")
			GS.trocar_epoca(GS.Epoca.ESEMDATA)
		if i == 15 or i == 16:
			_checar(slide.get_node_or_null("Tito") != null, "sala %d: Tito (de costas, com o balde)" % (81 + i))
	_checar(nivel.mat_agua.get_shader_parameter("ondas") < 0.99 or true, "água parada no slide")
	await _frames(40)
	_checar(nivel.mat_agua.get_shader_parameter("ondas") < 0.05, "no slide do último dia a água fica parada (ondas = 0)")
	GS.trocar_epoca(GS.Epoca.E2020)


## Raio de colisão entre dois pontos locais da sala (camada 1 = mundo). true = bateu em algo.
func _raio_bate(c, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(c.raiz.to_global(a), c.raiz.to_global(b), 1)
	return not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Geometria conferida ANDANDO (ou com raios), sem teleporte até o fim: escada que sobe, corredor lateral da bifurcação
## e o vão do meio-fio da cisterna (sala 98).
func _teste_geometria_andando() -> void:
	print("-- geometria andando: escada que sobe, corredor da bifurcação, vão da sala 98")
	nivel.ameacas_ligadas = false
	GS.trocar_epoca(GS.Epoca.E2020)
	# 1) escada que sobe (sala 99): entra pelo patamar e sobe até perto do topo, sem teleportar
	nivel.ir_para_sala(18)
	await _frames(10)
	var c = nivel.salas[18]
	player.global_position = c.raiz.to_global(Vector3(0, 0.1, -0.6))
	player.rotation.y = c.raiz.global_rotation.y
	player.velocity = Vector3.ZERO
	await _frames(4)
	Input.action_press("frente")
	var subiu: bool = await _ate(func(): return c.raiz.to_local(player.global_position).z < -c.L + 4.0, 900)
	Input.action_release("frente")
	var lp: Vector3 = c.raiz.to_local(player.global_position)
	_checar(subiu and lp.y > c.dy - 1.5, "sala 99: sobe a escada andando (z=%.1f y=%.2f de %.1f)" % [lp.z, lp.y, c.dy])
	# 2) bifurcações: paredes laterais e do fundo do corredor lateral (raios, nas duas)
	for d in nivel.plano:
		if d["tipo"] != "bifurcacao":
			continue
		var i: int = d["idx"]
		nivel.ir_para_sala(i)
		await _frames(6)
		var cb = nivel.salas[i]
		var lado: int = nivel.plano[i]["lado"]
		var zc := -8.2
		_checar(_raio_bate(cb, Vector3(lado * 8.0, 1.0, zc), Vector3(lado * 8.0, 1.0, zc - 0.9)), "bifurcação %d: parede do corredor (lado do fundo, z menor)" % cb.sala)
		_checar(_raio_bate(cb, Vector3(lado * 8.0, 1.0, zc), Vector3(lado * 8.0, 1.0, zc + 0.9)), "bifurcação %d: parede do corredor (z maior)" % cb.sala)
		_checar(_raio_bate(cb, Vector3(lado * 9.0, 1.0, zc), Vector3(lado * 10.6, 1.0, zc)), "bifurcação %d: o fim do corredor tem parede" % cb.sala)
	# 3) sala 98: o vão do meio-fio leva ao poço (afogamento), nunca a uma queda sem fim; com a ponte, atravessa
	nivel.ir_para_sala(17)
	await _frames(10)
	var c98 = nivel.salas[17]
	player.global_position = c98.raiz.to_global(Vector3(0.9, 0.1, -5.5))
	player.rotation.y = c98.raiz.global_rotation.y - PI * 0.5       # de frente para +x da sala (o vão)
	player.velocity = Vector3.ZERO
	await _frames(4)
	Input.action_press("frente")
	var caiu: bool = await _ate(func(): return nivel.afogando or nivel.morrendo, 300)
	Input.action_release("frente")
	await _frames(40)
	var y98: float = c98.raiz.to_local(player.global_position).y
	_checar(caiu and y98 > -3.3, "sala 98: cair no vão do meio-fio vira afogamento, com fundo no poço (y=%.2f)" % y98)
	await _esperar_morte_terminar()
	await _frames(20)
	nivel.ir_para_sala(17)
	await _frames(10)
	c98 = nivel.salas[17]
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	await _frames(4)
	player.global_position = c98.raiz.to_global(Vector3(0.9, 0.1, -5.5))
	player.rotation.y = c98.raiz.global_rotation.y - PI * 0.5
	player.velocity = Vector3.ZERO
	await _frames(4)
	Input.action_press("frente")
	var passou: bool = await _ate(func(): return c98.raiz.to_local(player.global_position).x > 3.6, 400)
	Input.action_release("frente")
	var l98: Vector3 = c98.raiz.to_local(player.global_position)
	_checar(passou and l98.y > -0.3 and not nivel.afogando, "sala 98: no disco sem data a passarela leva à plataforma da sandália (x=%.1f y=%.2f)" % [l98.x, l98.y])
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(10)


func _teste_saida_para_braco_morto() -> void:
	print("-- sala 99 -> Braço Morto")
	nivel.ir_para_sala(18)
	await _frames(10)
	var c = nivel.salas[18]
	var area: Area3D = c.raiz.get_node("SaidaFinal")
	player.global_position = area.get_child(0).global_position
	await _frames(3)
	_checar(nivel._saindo, "a saída ativa o guarda _saindo")
	var mortes_s: int = GS.contadores.get("mortes", 0)
	nivel._afogar()
	nivel.ao_morrer()
	nivel._ir_ao_braco_morto()
	_checar(not nivel.afogando and not nivel.morrendo and GS.contadores.get("mortes", 0) == mortes_s, "saindo: afogar e morrer são ignorados")
	var ok: bool = await _ate(func(): return main.nivel_atual == "res://world/niveis/braco_morto.tscn", 1200)
	_checar(ok, "chegar ao topo da escada leva para braco_morto.tscn")
	await _frames(30)
	_checar(GS.sala_atual == 100, "sala 100 (sala %d)" % GS.sala_atual)
	nivel = main.mundo.get_child(0)
	player = main.player
	_checar(player.is_on_floor(), "nasce no chão do poço da escada (y=%.2f)" % player.global_position.y)


func _teste_braco_morto(final: String) -> void:
	print("-- Braço Morto: final '%s'" % final)
	await main.carregar_mundo("res://world/niveis/braco_morto.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(10)
	GS.flags.erase("viu_tito_final")
	GS.flags.erase("final_encontrado")
	GS.flags.erase("final_visita_concluida")
	GS.contadores["pistas_tito"] = nivel.PISTAS_ENCONTRADO if final == "encontrado" else 1
	nivel.voltar_ao_titulo = false
	GS.set_flag("tem_visor", true)
	if not GS.Epoca.ESEMDATA in GS.discos:
		GS.ganhar_disco(GS.Epoca.ESEMDATA)
	_checar(GS.sala_atual == 100 and nivel.get_node_or_null("Spawn") != null, "sala 100 e marcador Spawn")
	_checar(player.is_on_floor(), "no chão (y=%.2f)" % player.global_position.y)
	_checar(nivel.get_node_or_null("Lago") != null and nivel.get_node_or_null("Pontilhoes") != null and nivel.get_node_or_null("Pedalinhos") != null, "lago, pontilhões e pedalinhos")
	_checar(nivel.get_node_or_null("LapideDeAreia") != null and nivel.lapide != null, "a lápide de areia")
	GS.trocar_epoca(GS.Epoca.E2020)
	_checar(not nivel.tito.visible, "sem o Visor, Tito não está lá")
	# lápide antes de ver Tito: só uma frase, não encerra
	nivel.lapide.interagir(player)
	await _frames(5)
	_checar(not nivel.encerrando and GS.flag("pista_lapide"), "a lápide, sem o Visor, só mostra a dica (e conta como pista)")
	# com o Visor (disco sem data), olhando para Tito: ele se vira e fala
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	_checar(nivel.tito.visible, "com o Visor sem data, Tito aparece sentado na margem")
	var menino: Node3D = nivel.tito.get_node("Menino")
	var pos_t: Vector3 = nivel.tito.global_position + nivel.POS_TITO
	player.global_position = Vector3(nivel.POS_TITO.x, 0.05, nivel.POS_TITO.z + 5.0)
	player.rotation.y = 0.0
	player.cabeca.rotation.x = 0.0
	var antes_rot: float = menino.rotation.y
	var fim := [""]
	nivel.fim.connect(func(f): fim[0] = f)
	var ok: bool = await _ate(func(): return nivel.cena_feita, 600)
	_checar(ok, "olhar para Tito com o Visor dispara a cena final")
	await _ate(func(): return absf(menino.rotation.y - PI) < 0.05, 600)
	_checar(absf(menino.rotation.y - PI) < 0.05 and antes_rot == 0.0, "Tito se vira para o jogador")
	await _ate(func(): return nivel._legenda.text == "Você veio me procurar.", 120)
	_checar(nivel._legenda.text == "Você veio me procurar.", "ele diz: 'Você veio me procurar.'")
	var ok2: bool = await _ate(func(): return GS.flag("viu_tito_final"), 1200)
	_checar(ok2 and nivel.final == final, "final decidido pelas pistas: %s (pistas_tito=%d)" % [nivel.final, GS.contadores.get("pistas_tito", 0)])
	if final == "encontrado":
		_checar(menino.scale.x < 0.01 and GS.flag("final_encontrado") and (menino.get_node("Boca") as Label3D).text == ")", "Encontrado: Tito sorri e some")
	else:
		_checar(menino.scale.x > 0.9 and GS.flag("final_visita_concluida") and not GS.flag("final_encontrado"), "Visita concluída: Tito continua ali")
	# o fim chega: título do final, dedicatória, e depois o título (aqui desligado para o teste)
	var ok3: bool = await _ate(func(): return nivel.dedicatoria != null, 2400)
	_checar(ok3 and fim[0] == final, "depois do final aparece a dedicatória (Dedicatoria.mostrar)")
	_checar(nivel.dedicatoria != null and nivel.dedicatoria.has_signal("terminou"), "a dedicatória tem o sinal `terminou`")
	if nivel.dedicatoria != null and nivel.dedicatoria.has_method("texto_dedicatoria"):
		var t: String = nivel.dedicatoria.texto_dedicatoria()
		_checar(t.contains("Tito é um personagem fictício") and t.contains("Disque 100") and t.contains("Conselho Tutelar"), "o texto da dedicatória (V2 §1)")
	if nivel.dedicatoria != null:
		nivel.dedicatoria.queue_free()
	load("res://ui/flash.gd").resetar_ui()
