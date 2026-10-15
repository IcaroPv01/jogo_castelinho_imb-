class_name Debug
extends RefCounted
## Modo debug (módulo 9): só para testar. Desligado por padrão; um jogador normal nunca vê.
## Liga com `?debug=1` no endereço (Web) ou `--debug` na linha de comando. O painel (ui/painel_debug.gd) muda as chaves.
## Nada daqui vai para o save (user://save.json): as chaves vivem só na memória da partida.
##
## Quem lê:
##   - `Debug.imortal`            → GameState.matar_jogador ignora a morte; a Figura não mata.
##   - `Debug.figura_off`         → toda FiguraBranca fica escondida e parada; o Visor não mostra a Figura no slide.
##   - `Debug.atencao_congelada`  → o Visor não muda `GameState.atencao`.
##   - `Debug.info`               → HUD de debug com sala, época, visita e qps.
##   - `Debug.pular_cidade(id)`   → vai direto a um lugar da cidade (Módulo 14), sem esperar a visita que o abre.

static var ligado := false
static var imortal := false
static var figura_off := false
static var atencao_congelada := false
static var info := false

## Save à parte: com o debug ligado o GameState lê e grava aqui (user://save.json nunca é tocado).
const ARQUIVO_SAVE := "user://save_debug.json"

## Faixas de sala de cada "lugar" do menu de pulo: [primeira sala, última sala]. Visitas 1 a 4 = prédio; 5 = porão; 6 = Braço Morto.
const FAIXAS: Array = [[1, 22], [23, 44], [45, 66], [67, 80], [81, 99], [100, 100]]
const NOMES_LUGAR: Array[String] = ["Visita 1 (salas 1 a 22)", "Visita 2 (salas 23 a 44)", "Visita 3 (salas 45 a 66)",
	"Visita 4 (salas 67 a 80)", "Porão (salas 81 a 99)", "Braço Morto (sala 100)"]
## Sala 55 não está em SALAS_CHECKPOINT (é o trecho do Ato II, visita 3, salas 55 a 60), mas "Continuar" a entende.
const CHECKPOINT_EXTRA: Array[int] = [55]
const FINAIS: Array[String] = ["encontrado", "visita_concluida", "sala_101", "tito_salvo"]


# ---------------------------------------------------------------- ligar
## Liga o modo debug se a página tem `?debug=1` (Web) ou a linha de comando tem `--debug`. Nunca desliga.
## Chamada uma vez, no _ready do GameState (antes de ler o save, que depende de `ligado`).
static func detectar() -> bool:
	if ligado:
		return true
	if OS.get_cmdline_user_args().has("--debug") or OS.get_cmdline_args().has("--debug"):
		ligado = true
	elif OS.has_feature("web"):
		ligado = _js_bool("[\"1\", \"true\", \"sim\"].indexOf(new URLSearchParams(window.location.search).get(\"debug\")) >= 0")
	return ligado


## O eval do Godot devolve o booleano da página como número (ver Celular._js_bool): a página devolve 1/0.
static func _js_bool(expr: String) -> bool:
	var r: Variant = JavaScriptBridge.eval("(%s) ? 1 : 0" % expr, true)
	return (r is int or r is float or r is bool) and int(r) == 1


## Liga/desliga para esta sessão (gesto escondido da tela de título). Troca o arquivo de save e recarrega o estado.
## Desligar também apaga as chaves (imortal etc.). Quem chama recarrega a cena para a tela de título refletir o save novo.
static func definir_ligado(on: bool) -> void:
	if on == ligado:
		return
	ligado = on
	if not on:
		imortal = false
		figura_off = false
		atencao_congelada = false
		info = false
	_gs().recarregar_save()


## Lê/escreve uma das chaves pelo nome ("imortal", "figura_off", "atencao_congelada", "info").
static func chave(nome: String) -> bool:
	match nome:
		"imortal": return imortal
		"figura_off": return figura_off
		"atencao_congelada": return atencao_congelada
		"info": return info
	return false


static func definir_chave(nome: String, valor: bool) -> void:
	match nome:
		"imortal": imortal = valor
		"figura_off": figura_off = valor
		"atencao_congelada": atencao_congelada = valor
		"info": info = valor


static func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


## A tecla do painel: apóstrofo (') ou a tecla à esquerda do 1 (teclado ABNT2 do Brasil: keycode apóstrofo; layouts
## em que o apóstrofo vem de outra tecla ainda batem pela posição física).
static func tecla_painel(e: InputEvent) -> bool:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return false
	return e.keycode == KEY_APOSTROPHE or e.physical_keycode == KEY_APOSTROPHE or e.physical_keycode == KEY_QUOTELEFT


# ---------------------------------------------------------------- ganhar tudo
## Os 5 discos do Visor, a lanterna e o Visor (as mesmas flags que o jogo normal grava) e os 5 lugares da cidade
## (Módulo 14) feitos, com as 6 pistas deles: o total de pistas do jogo chega a 21.
static func ganhar_tudo() -> void:
	var gs := _gs()
	gs.cidade_concluir_tudo()
	gs.flags.erase("lanterna_desligada")
	gs.set_flag("tem_lanterna", true)
	gs.set_flag("tem_visor", true)
	for ep in [gs.Epoca.E1950, gs.Epoca.E1967, gs.Epoca.E1975, gs.Epoca.E2019, gs.Epoca.ESEMDATA]:
		gs.caca_concluir(ep)          # as caças dos discos ficam feitas (nada trava a entrega)
		gs.ganhar_disco(ep)
	var p: Variant = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player")
	if p != null and p.get("lanterna") != null:
		p.lanterna.visible = true


# ---------------------------------------------------------------- pular
## Onde o pulo cai. `lugar` = índice de FAIXAS (0..5); `sala` global (vira a faixa do lugar se estiver fora).
## Não dá para nascer em qualquer sala: o jogo só tem pontos de chegada nos checkpoints, então cai no checkpoint mais
## próximo que seja menor ou igual à sala pedida (dentro do mesmo lugar). Devolve {cp, sala, lugar, visita, cena, marcador, exato, texto}.
static func destino(lugar: int, sala: int) -> Dictionary:
	var gs := _gs()
	lugar = clampi(lugar, 0, FAIXAS.size() - 1)
	var ini: int = FAIXAS[lugar][0]
	var fim: int = FAIXAS[lugar][1]
	sala = clampi(sala, ini, fim)
	var cp := ini
	for c in gs.SALAS_CHECKPOINT + CHECKPOINT_EXTRA:
		if c >= ini and c <= sala and c > cp:
			cp = c
	var cena: String = gs.CENA_CASTELINHO
	var nome := "Castelinho"
	if cp >= gs.TOTAL_SALAS:
		cena = gs.CENA_BRACO
		nome = "Braço Morto"
	elif cp >= gs.PRIMEIRA_SALA_PORAO:
		cena = gs.CENA_PORAO
		nome = "Porão"
	elif cp == gs.CHECKPOINT_ATO2:
		cena = gs.CENA_ATO2
		nome = "Ato II"
	var marcador := "Spawn" if cp >= gs.TOTAL_SALAS else "Checkpoint_%d" % cp
	var texto := "Vai para a sala %d (%s)." % [cp, nome]
	if cp != sala:
		texto = "Não dá para nascer na sala %d. Vai para a sala %d (%s), o ponto mais perto antes dela." % [sala, cp, nome]
	return {"cp": cp, "sala": sala, "lugar": lugar, "visita": gs.visita_da_sala(cp), "cena": cena, "marcador": marcador,
		"exato": cp == sala, "texto": texto}


static func lugar_da_sala(sala: int) -> int:
	for i in FAIXAS.size():
		if sala >= FAIXAS[i][0] and sala <= FAIXAS[i][1]:
			return i
	return 0


## Troca de fase: prepara o save de debug como se o checkpoint tivesse sido alcançado e carrega o nível.
## Funciona na tela de título também (fecha o título). Só age com o debug ligado.
static func pular(lugar: int, sala: int) -> Dictionary:
	var d := destino(lugar, sala)
	if not ligado:
		return d
	var gs := _gs()
	gs.checkpoint_sala = d["cp"]
	gs.sala_maxima = maxi(gs.sala_maxima, d["cp"])
	_dar_discos_anteriores(int(d["visita"]))
	var alvo: Array = gs.preparar_continuar()
	await _carregar(alvo[0], alvo[1])
	return d


## Pular de fase não pode travar na caça de um disco: quem cai na visita (ou no porão) `etapa` recebe os discos das
## etapas anteriores já com as caças feitas (1950 = visita 1, 1967 = visita 2, 1975 = 3, 2019 = 4, sem data = porão = 5).
## A caça da própria etapa fica por fazer. (GameState.CACAS tem a visita de cada disco.)
static func _dar_discos_anteriores(etapa: int) -> void:
	var gs := _gs()
	for ep in gs.CACAS:
		if int(gs.CACAS[ep]["visita"]) < etapa:
			gs.caca_concluir(ep)
			gs.ganhar_disco(ep)
			gs.set_flag("tem_visor", true)


## Cai direto num dos lugares da cidade (Módulo 14: "casas", "barra", "ponte", "praia", "rodoviaria"), ignorando a abertura por
## visita. Dá os 5 discos (o Visor precisa do de 1967 nas casas e na rodoviária). A volta ao
## Castelinho cai na calçada da visita atual do save de debug. Só age com o debug ligado. Devolve o nó do nível (ou null).
static func pular_cidade(id: String) -> Variant:
	var gs := _gs()
	if not ligado or not gs.CIDADE.has(id):
		return null
	_dar_discos_anteriores(6)      # os 5 discos (o Visor precisa do de 1967 nas casas e na rodoviária, mesmo antes de a visita que o dá)
	gs.set_flag("tem_visor", true)
	await _carregar(gs.CIDADE[id]["cena"], "Spawn")
	var arv := Engine.get_main_loop() as SceneTree
	var main: Variant = arv.get_first_node_in_group("main")
	return main.mundo.get_child(0) if main != null and main.mundo.get_child_count() > 0 else null


## Cai direto num dos finais do Braço Morto: "encontrado", "visita_concluida", "sala_101" ou o secreto "tito_salvo"
## (este embarca no pedalinho e começa a cena final, a ~11 m do Tito de 1967).
## (Dá tudo ao jogador, põe as pistas do Tito e dispara a cena; o resto roda como no jogo.) Devolve o nó do nível.
static func pular_final(final: String) -> Variant:
	if not ligado or not FINAIS.has(final):
		return null
	var gs := _gs()
	ganhar_tudo()
	gs.contadores["pistas_tito"] = 16 if final == "tito_salvo" else (8 if final == "encontrado" else 3)     # braco_morto.PISTAS_ENCONTRADO = 8, BracoSalvar.PISTAS_SALVAR = 16
	gs.checkpoint_sala = gs.TOTAL_SALAS
	gs.sala_maxima = gs.TOTAL_SALAS
	var alvo: Array = gs.preparar_continuar()
	await _carregar(alvo[0], alvo[1])
	var arv := Engine.get_main_loop() as SceneTree
	var main: Variant = arv.get_first_node_in_group("main")
	var nivel: Variant = main.mundo.get_child(0)
	await arv.process_frame
	var jogador: Variant = main.player
	if final == "tito_salvo":
		nivel.salvar.depurar_cena_final()
	elif final == "sala_101":
		var rampa_x: float = (nivel.RAMPA_X0 + nivel.RAMPA_X1) * 0.5
		jogador.global_position = Vector3(rampa_x, nivel.AGUA_Y - 0.2, nivel.LAGO_Z1 - nivel.DIST_AFUNDAR)
		jogador.rotation.y = 0.0
		nivel._afundar()
	else:
		var tito: Vector3 = nivel.POS_TITO
		jogador.global_position = Vector3(tito.x, 0.05, tito.z + 5.0)
		jogador.rotation.y = 0.0
		jogador.cabeca.rotation.x = 0.0
		gs.trocar_epoca(gs.Epoca.ESEMDATA)
		nivel._cena_tito()
	return nivel


## Carrega `cena` na raiz do jogo (main.gd), tirando a tela de título se ainda estiver nela.
static func _carregar(cena: String, marcador: String) -> void:
	var arv := Engine.get_main_loop() as SceneTree
	var main: Variant = arv.get_first_node_in_group("main")
	if main == null:
		return
	Celular.pausa_toque = false
	Celular.capturar_mouse()
	main.hud.visible = true
	await main.carregar_mundo(cena, marcador)
	if is_instance_valid(main.tela_titulo):
		main.tela_titulo.queue_free()
	_gs().jogando = true
