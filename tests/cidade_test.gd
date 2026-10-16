extends SceneTree
## Teste automático (headless) da FUNDAÇÃO da cidade (Módulo 14, "mais partes da cidade"): a tabela `GameState.CIDADE`, a abertura
## por visita, a base `CidadeBase` (via os 5 esqueletos: Spawn, portão, AREA, borda invisível, rede de segurança, HUD, pista uma
## vez só, concluir/sair e a volta ao Castelinho, objetivo e Mapa), a placa da calçada (3D e folheto) e a volta com visita e época
## intactas. NÃO depende do miolo dos lugares (placeholders): só do contrato da base. Cada lugar tem (ou terá) o seu
## `tests/cidade_<id>_test.gd` para o miolo; o `tools/testar.sh` roda todos pelo glob `tests/*_test.gd`.
## Uso: godot --headless -s res://tests/cidade_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var Obj: GDScript
var MapaC: GDScript
var PlacaC: GDScript

## O que cada esqueleto declara (hora/clima/Visor); o miolo pode mudar a hora (a Barra vira noite) e então atualiza esta tabela.
const ESPERADO := {
	"casas": {"hora": 1, "clima": 0, "visor": true},         # Hora.FIM_DE_TARDE
	"barra": {"hora": 2, "clima": 0, "visor": false},        # Hora.ENTARDECER
	"ponte": {"hora": 3, "clima": 0, "visor": false},        # Hora.NOITE
	"praia": {"hora": 3, "clima": 2, "visor": false},        # Hora.NOITE + Clima.RESSACA
	"rodoviaria": {"hora": 1, "clima": 0, "visor": true},
}


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
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


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Obj = load("res://world/objetivo.gd")
	MapaC = load("res://ui/mapa.gd")
	PlacaC = load("res://ui/placa_cidade.gd")
	_tabela()
	_abertura()
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	await _esqueletos()
	await _placa()
	main.queue_free()
	await process_frame
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ============================================================================ tabela
func _tabela() -> void:
	print("-- GameState.CIDADE")
	GS.novo_jogo()      # (o save do user dir pode ter sobras de outra execução)
	_checar(GS.CIDADE_ORDEM.size() == 5 and GS.CIDADE.size() == 5, "5 lugares")
	var ids_pista := {}
	var vistas := {"casas": 1, "barra": 2, "ponte": 3, "praia": 2, "rodoviaria": 4}
	var n_pistas := {"casas": 2, "barra": 1, "ponte": 1, "praia": 1, "rodoviaria": 1}
	for id in GS.CIDADE_ORDEM:
		var d: Dictionary = GS.CIDADE[id]
		_checar(ResourceLoader.exists(d["cena"]) and d["cena"] == "res://world/niveis/cidade_%s.tscn" % id, "%s: cena existe" % id)
		_checar(str(d["rotulo"]) != "" and str(d["texto"]) != "", "%s: rótulo e texto" % id)
		_checar(int(d["depois_da_visita"]) == vistas[id], "%s: abre depois da visita %d" % [id, vistas[id]])
		_checar((d["pistas"] as Array).size() == n_pistas[id], "%s: %d pista(s)" % [id, n_pistas[id]])
		for p in d["pistas"]:
			_checar(not ids_pista.has(p), "pista '%s' é única" % p)
			ids_pista[p] = true
			_checar(not GS.flags.has("pista_" + p), "pista '%s' não começa achada" % p)
	_checar(GS.cidade_pistas_total() == 6 and ids_pista.size() == 6, "a cidade dá 6 pistas")
	_checar(GS.PISTAS_BASE + GS.cidade_pistas_total() == 21, "total do jogo: 15 + 6 = 21")
	var salvar: GDScript = load("res://world/niveis/braco_salvar.gd")
	var braco: GDScript = load("res://world/niveis/braco_morto.gd")
	_checar(salvar.PISTAS_SALVAR == 16, "final secreto pede 16 pistas (de 21)")
	_checar(braco.PISTAS_ENCONTRADO == 8, "o 'Encontrado' continua pedindo 8")
	_checar(salvar.PISTAS_SALVAR <= GS.PISTAS_BASE + GS.cidade_pistas_total(), "o secreto é alcançável")


# ============================================================================ abertura por visita
func _abertura() -> void:
	print("-- abertura por visita")
	GS.novo_jogo()
	_checar(GS.cidade_pendentes().is_empty() and not GS.cidade_algum_aberto(), "visita 1: nada aberto (sem placa)")
	var casos := [
		[2, 0, ["casas"]],
		[3, 0, ["casas", "barra", "praia"]],
		[4, 70, ["casas", "barra", "ponte", "praia"]],
		[4, 77, ["casas", "barra", "ponte", "praia"]],
		[4, 78, ["casas", "barra", "ponte", "praia", "rodoviaria"]],      # visita 4 concluída = chegou à Sala Medieval
		[5, 0, ["casas", "barra", "ponte", "praia", "rodoviaria"]],
	]
	for c in casos:
		GS.novo_jogo()
		GS.visita = c[0]
		GS.sala_maxima = c[1]
		var abertos: Array = []
		for id in GS.CIDADE_ORDEM:
			if GS.cidade_aberta(id):
				abertos.append(id)
		_checar(abertos == c[2], "visita %d (sala máxima %d): abertos %s" % [c[0], c[1], str(abertos)])
		_checar(GS.cidade_pendentes() == c[2], "  pendentes = abertos e não feitos")
	GS.novo_jogo()
	GS.visita = 2
	_checar(GS.cidade_algum_aberto() and not GS.cidade_feita("casas"), "visita 2: há lugar aberto e nenhum feito")
	GS.set_flag("cidade_casas_feito", true)
	_checar(GS.cidade_feita("casas") and GS.cidade_pendentes().is_empty(), "feito sai dos pendentes")
	_checar(not GS.cidade_aberta("xyz") and not GS.cidade_feita("xyz"), "id inexistente: fechado e não feito")
	# debug: ganhar tudo
	GS.novo_jogo()
	GS.cidade_concluir_tudo()
	_checar(GS.cidade_pistas_achadas() == 6 and int(GS.contadores["pistas_tito"]) == 6, "cidade_concluir_tudo: 6 pistas contadas")
	GS.cidade_concluir_tudo()
	_checar(int(GS.contadores["pistas_tito"]) == 6, "e não conta de novo")
	GS.novo_jogo()


# ============================================================================ os 5 esqueletos
func _esqueletos() -> void:
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.set_flag("tem_visor", true)
	var extras0: int = Obj.extras.size()
	var primeiro := true
	for id in GS.CIDADE_ORDEM:
		print("-- lugar: %s" % id)
		GS.visita = 2
		GS.entrar_sala(23)       # calçada da visita 2 (para conferir o HUD na volta)
		GS.discos.clear()
		GS.ganhar_disco(GS.Epoca.E1967)
		var cena: String = GS.CIDADE[id]["cena"]
		await main.carregar_mundo(cena, "Spawn")
		await _frames(8)
		var nivel: Node = main.mundo.get_child(0)
		_checar(main.nivel_atual == cena and nivel.has_method("voltar_ao_spawn") and nivel.id == id, "carrega e tem id '%s'" % id)
		var esp: Dictionary = ESPERADO[id]
		_checar(nivel.hora == esp["hora"] and nivel.clima == esp["clima"], "hora %d / clima %d como no esqueleto" % [nivel.hora, nivel.clima])
		_checar((nivel.find_child("Visor", true, false) != null) == bool(esp["visor"]), "Visor instalado = %s" % str(esp["visor"]))
		# Spawn, portão, AREA
		var mk: Node3D = nivel.find_child("Spawn", true, false)
		_checar(mk != null, "tem o marcador Spawn")
		var area: Rect2 = nivel.area
		_checar(area.size.x > 10.0 and area.size.y > 10.0, "AREA de %.0f x %.0f m" % [area.size.x, area.size.y])
		_checar(mk != null and area.has_point(Vector2(mk.global_position.x, mk.global_position.z)), "o Spawn está dentro da AREA")
		var portao: Node3D = nivel.find_child("Portao", true, false)
		var volta: Node = nivel.find_child("PortaoVolta", true, false)
		_checar(portao != null and volta != null and volta.has_method("interagir") and volta.texto_interacao == "Voltar ao Castelinho", "portão 'Voltar ao Castelinho' (Interagivel)")
		_checar(portao != null and mk != null and portao.global_position.distance_to(mk.global_position) < 6.0, "o portão fica perto do Spawn")
		_checar(portao != null and area.has_point(Vector2(portao.global_position.x, portao.global_position.z)), "o portão está dentro da AREA")
		_checar(main.player != null and mk != null and main.player.global_position.distance_to(mk.global_position) < 0.8, "o jogador nasce no Spawn")
		_checar(main.player.is_on_floor(), "o jogador pisa no chão")
		# ambiente e orçamento
		_checar(nivel.env != null and nivel.sol_luz != null, "ambiente (céu, névoa, Sol)")
		var luzes := 0
		var malhas := 0
		for n in nivel.find_children("*", "Node", true, false):
			if n is Light3D:
				luzes += 1
			elif n is MeshInstance3D:
				malhas += 1
		_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
		_checar(malhas <= 120, "poucas malhas no esqueleto (%d)" % malhas)
		# borda invisível
		await _checar_borda(nivel)
		# HUD, objetivo, Mapa
		_checar(main.hud.lbl_sala.text == "CIDADE · " + str(GS.CIDADE[id]["rotulo"]).to_upper(), "HUD: '%s'" % main.hud.lbl_sala.text)
		_checar(GS.sala_atual == 23 and GS.visita == 2, "o contador de salas e a visita não mudam")
		_checar(Obj.extras.size() == extras0 + 1 and Obj.atual() == nivel._texto_objetivo() and Obj.atual() != "", "objetivo do lugar no Mapa: '%s'" % Obj.atual())
		var dm: Dictionary = MapaC.obter_dados()
		_checar(dm.get("msg") == "Cidade · " + str(GS.CIDADE[id]["rotulo"]), "Mapa: '%s'" % str(dm.get("msg")))
		if primeiro:
			MapaC.abrir(true)
			await _frames(3)
			_checar(MapaC.atual != null and MapaC.atual.objetivo == nivel._texto_objetivo(), "o Mapa abre e mostra o objetivo do lugar")
			MapaC.atual.fechar()
			await _frames(3)
		# pistas: uma vez só
		var antes: int = int(GS.contadores.get("pistas_tito", 0))
		var pistas: Array = nivel.pistas_do_lugar()
		for pid in pistas:
			var nova1: bool = await nivel.pista(pid, [])
			var nova2: bool = await nivel.pista(pid, [])
			_checar(nova1 and not nova2 and GS.flag("pista_" + pid), "pista '%s' conta uma vez só" % pid)
		_checar(int(GS.contadores.get("pistas_tito", 0)) == antes + pistas.size(), "contador pistas_tito +%d" % pistas.size())
		var x: bool = await nivel.pista("pista_que_nao_existe", [])
		_checar(not x and int(GS.contadores.get("pistas_tito", 0)) == antes + pistas.size(), "pista fora da tabela não conta")
		await _frames(3)
		# rede de segurança
		var q0: int = nivel.quedas
		main.player.global_position = Vector3(mk.global_position.x, -20.0, mk.global_position.z)
		var voltou: bool = await _ate(func() -> bool: return main.player.global_position.y > -2.0 and main.player.global_position.distance_to(mk.global_position) < 1.5, 120)
		_checar(voltou and nivel.quedas == q0 + 1, "cair (y < -8) devolve ao Spawn")
		main.player.global_position = Vector3(area.end.x + 8.0, 0.5, area.end.y + 8.0)
		voltou = await _ate(func() -> bool: return main.player.global_position.distance_to(mk.global_position) < 1.5, 120)
		_checar(voltou and nivel.quedas == q0 + 2, "sair da AREA devolve ao Spawn")
		# concluir (praia: sair pelo portão, sem concluir)
		var sai_pelo_portao: bool = id == "praia"
		if sai_pelo_portao:
			volta.interagir(main.player)
		else:
			nivel.concluir()
		var voltou_castelo: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not Transicao_ocupado(), 600)
		_checar(voltou_castelo, "%s: volta ao Castelinho" % ("sair" if sai_pelo_portao else "concluir"))
		await _frames(10)
		_checar(GS.cidade_feita(id) == (not sai_pelo_portao), "flag cidade_%s_feito %s" % [id, "NÃO gravada ao sair" if sai_pelo_portao else "gravada"])
		var castelo: Node = main.mundo.get_child(0)
		var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
		_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chega na calçada (Spawn_volta_cidade)")
		_checar(GS.visita == 2 and GS.epoca == GS.Epoca.E2020 and GS.sala_atual == 23, "visita, época e sala intactas")
		_checar(main.hud.lbl_sala.text == "VISITA 2 · SALA 23", "HUD volta a 'VISITA 2 · SALA 23' (%s)" % main.hud.lbl_sala.text)
		_checar(Obj.extras.size() == extras0 and int(GS.corruption_manual) == -1, "limpou o objetivo e a corrupção manual ao sair")
		primeiro = false
	_checar(GS.cidade_pistas_achadas() == 6, "os 5 lugares deram 6 pistas")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == 6, "contador pistas_tito = 6")


func Transicao_ocupado() -> bool:
	return bool(root.get_node("/root/Transicao").ocupado)


## Quatro caixas de colisão altas por FORA da AREA; um raio de dentro para fora nos 4 lados bate nelas; nenhum ponto da AREA é bloqueado.
func _checar_borda(nivel: Node) -> void:
	var area: Rect2 = nivel.area
	for nome in ["Borda_N", "Borda_S", "Borda_O", "Borda_L"]:
		var b := nivel.find_child(nome, true, false) as StaticBody3D
		_checar(b != null, "borda %s" % nome)
		if b != null:
			var f := b.get_child(0) as CollisionShape3D
			var tam: Vector3 = (f.shape as BoxShape3D).size
			_checar(tam.y >= 6.0 and not area.grow(-0.05).has_point(Vector2(b.global_position.x, b.global_position.z)), "  %s: alta (%.0f m) e fora da AREA" % [nome, tam.y])
	var c := area.get_center()
	var espaco: PhysicsDirectSpaceState3D = nivel.get_world_3d().direct_space_state
	var raios := {"N": [Vector3(c.x, 1.0, area.position.y + 1.0), Vector3(c.x, 1.0, area.position.y - 3.0)],
		"S": [Vector3(c.x, 1.0, area.end.y - 1.0), Vector3(c.x, 1.0, area.end.y + 3.0)],
		"O": [Vector3(area.position.x + 1.0, 1.0, c.y), Vector3(area.position.x - 3.0, 1.0, c.y)],
		"L": [Vector3(area.end.x - 1.0, 1.0, c.y), Vector3(area.end.x + 3.0, 1.0, c.y)]}
	var todos := true
	for lado in raios:
		var q := PhysicsRayQueryParameters3D.create(raios[lado][0], raios[lado][1], 1)
		var r := espaco.intersect_ray(q)
		var bateu: bool = not r.is_empty() and str((r["collider"] as Node).name).begins_with("Borda_")
		todos = todos and bateu
	# (o raio passa por cima de objetos do miolo? Não importa: só confirmo que a borda existe e segura)
	_checar(todos, "um raio de dentro para fora bate na borda nos 4 lados")


# ============================================================================ a placa na calçada
func _placa() -> void:
	print("-- placa da prefeitura na calçada")
	# visita 1: nenhum lugar aberto, nenhuma placa
	GS.novo_jogo()
	GS.jogando = true
	await main.carregar_mundo(GS.CENA_CASTELINHO, "Spawn")
	await _frames(5)
	var castelo: Node = main.mundo.get_child(0)
	_checar(castelo.find_child("PlacaCidade3D", true, false) == null, "visita 1: sem placa (nada aberto)")
	_checar(castelo.find_child("Spawn_volta_cidade", true, false) != null, "o Castelinho tem Spawn_volta_cidade")
	# visita 2: a placa aparece
	GS.novo_jogo()
	GS.jogando = true
	GS.visita = 2
	GS.entrar_sala(23)
	await main.carregar_mundo(GS.CENA_CASTELINHO, "Spawn")
	await _frames(8)
	castelo = main.mundo.get_child(0)
	var placa3d: Node3D = castelo.find_child("PlacaCidade3D", true, false)
	var it: Node = castelo.find_child("PlacaCidadeInteragivel", true, false)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(placa3d != null and it != null and it.has_method("interagir") and placa3d.visible, "visita 2: a placa existe e está visível")
	_checar(placa3d != null and vc != null and placa3d.global_position.distance_to(vc.global_position) < 4.0, "fica ao lado de onde o jogador volta")
	var sp: Node3D = castelo.find_child("Spawn", true, false)
	_checar(placa3d != null and sp != null and placa3d.global_position.distance_to(sp.global_position) < 6.0, "e perto do Spawn da calçada")
	GS.trocar_epoca(GS.Epoca.E1950)
	_checar(not placa3d.visible, "em 1950 (Visor) a placa não existe")
	GS.trocar_epoca(GS.Epoca.E2020)
	_checar(placa3d.visible, "de volta a hoje, a placa volta")
	# o folheto
	it.interagir(main.player)
	await _frames(4)
	var placa: Variant = PlacaC.atual
	_checar(placa != null and GS.flag("ui_aberta"), "E na placa abre o folheto")
	_checar(placa.linhas.size() == 5, "lista os 5 lugares")
	var est: Array = []
	for l in placa.linhas:
		est.append(l["estado"])
	_checar(est == ["aberto", "fechado", "fechado", "fechado", "fechado"], "visita 2: só 'casas' aberta (%s)" % str(est))
	_checar(placa.linhas[1]["texto_estado"] == "abre depois da Visita 2", "fechado diz 'abre depois da Visita 2'")
	_checar(placa.linhas[0]["texto_estado"] == "ABERTO", "aberto diz ABERTO")
	_checar(not placa.escolher(1) and placa._aviso.text.begins_with("Ainda fechado") and PlacaC.atual != null, "escolher um fechado só avisa")
	_checar(not placa.escolher(9) and not placa.escolher(-1), "linha inválida não faz nada")
	# Esc fecha
	var esc := InputEventAction.new()
	esc.action = "pausa"
	esc.pressed = true
	placa._unhandled_input(esc)
	await _frames(3)
	_checar(PlacaC.atual == null and not GS.flag("ui_aberta"), "Esc fecha e libera o jogo")
	# E fecha
	placa = PlacaC.abrir(true)
	await _frames(3)
	await _passa_guarda(placa)
	var tecla := InputEventKey.new()
	tecla.pressed = true
	tecla.physical_keycode = KEY_E
	placa._unhandled_input(tecla)
	await _frames(3)
	_checar(PlacaC.atual == null and not GS.flag("ui_aberta"), "E fecha")
	# visita 3 com a 'casas' feita: estados
	GS.visita = 3
	GS.set_flag("cidade_casas_feito", true)
	placa = PlacaC.abrir(true)
	await _frames(3)
	est = []
	for l in placa.linhas:
		est.append(l["estado"])
	_checar(est == ["feito", "aberto", "fechado", "aberto", "fechado"], "visita 3: casas feita, barra e praia abertas (%s)" % str(est))
	_checar(placa.linhas[0]["texto_estado"] == "FEITO" and placa.linhas[2]["texto_estado"] == "abre depois da Visita 3", "textos FEITO e 'abre depois da Visita 3'")
	placa.fechar()
	await _frames(3)
	# escolher com a tecla 2 (barra, aberta na visita 3): vai para a cena; sair pelo portão volta com visita e época intactas
	GS.trocar_epoca(GS.Epoca.E2020)
	placa = PlacaC.abrir(true)
	await _frames(3)
	await _passa_guarda(placa)
	var k2 := InputEventKey.new()
	k2.pressed = true
	k2.physical_keycode = KEY_2
	placa._unhandled_input(k2)
	var foi: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CIDADE["barra"]["cena"] and not Transicao_ocupado(), 600)
	_checar(foi and PlacaC.atual == null and not GS.flag("ui_aberta"), "tecla 2 vai para a cena da barra e fecha o folheto")
	await _frames(6)
	var lugar: Node = main.mundo.get_child(0)
	lugar.find_child("PortaoVolta", true, false).interagir(main.player)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not Transicao_ocupado(), 600)
	await _frames(8)
	castelo = main.mundo.get_child(0)
	vc = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(voltou and GS.visita == 3 and GS.epoca == GS.Epoca.E2020 and not GS.cidade_feita("barra"), "voltar sem concluir: visita 3, época de hoje, lugar não feito")
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "e de volta à calçada")
	_checar(castelo.find_child("PlacaCidade3D", true, false) != null, "a placa continua lá")
	# clique no botão
	placa = PlacaC.abrir(true)
	await _frames(3)
	await _passa_guarda(placa)
	(placa.linhas[3]["botao"] as Button).pressed.emit()
	foi = await _ate(func() -> bool: return main.nivel_atual == GS.CIDADE["praia"]["cena"] and not Transicao_ocupado(), 600)
	_checar(foi, "clicar (ou tocar) na linha da praia vai para a praia")
	await _frames(4)
	# fecha o botão de "ganhar tudo" do debug também não quebra a placa: debug já cobre. Fim.


## Espera passar a guarda anti-clique-duplo da placa (400 ms de relógio real).
func _passa_guarda(placa: Variant) -> void:
	while Time.get_ticks_msec() - int(placa._aberto_ms) < 450:
		await physics_frame
