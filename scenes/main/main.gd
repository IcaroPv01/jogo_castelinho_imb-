extends Node
## Raiz do jogo. Mostra a tela de título, carrega "mundos" (níveis) e cuida de mouse e pausa.
## Níveis: cenas Node3D com Marker3D chamados "Spawn" (ou outro nome passado em carregar_mundo).

const PRIMEIRO_NIVEL := "res://world/niveis/castelinho.tscn"
const NIVEL_TESTE := "res://world/niveis/teste.tscn"

var mundo: Node3D
var hud: HUD
var player: Player
var tela_titulo: Control
var nivel_atual := ""
## Mostra a tela "Carregando..." e "aquece" os materiais (renderiza o nível por trás dela) antes de entregar o jogo.
## No headless não há o que desenhar, então fica desligado; os testes ligam à mão para conferir o fluxo.
var aquecer_ativo := DisplayServer.get_name() != "headless"
var _carregando := false


func _ready() -> void:
	add_to_group("main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mundo = Node3D.new()
	mundo.name = "Mundo"
	mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(mundo)
	hud = HUD.new()
	hud.visible = false
	add_child(hud)
	GameState.jogador_morreu.connect(_on_morte)
	# voltou do "Fim da demonstração" (reload da cena): zera sala, corrupção e época da partida anterior
	GameState.jogando = false
	GameState.resetar_sessao()
	Guia.cancelar()
	_mostrar_titulo()


func _mostrar_titulo() -> void:
	var cena := load("res://ui/tela_titulo.tscn") if ResourceLoader.exists("res://ui/tela_titulo.tscn") else null
	if cena:
		tela_titulo = cena.instantiate()
	else:
		tela_titulo = _titulo_simples()
	add_child(tela_titulo)
	if tela_titulo.has_signal("comecar"):
		tela_titulo.connect("comecar", _comecar)


func _titulo_simples() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_user_signal("comecar", [{"name": "continuar", "type": TYPE_BOOL}])
	var b := Button.new()
	b.text = Celular.dica("CLIQUE PARA COMEÇAR", "TOQUE PARA COMEÇAR")
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.position = Vector2(-180, -30)
	b.size = Vector2(360, 60)
	b.pressed.connect(func(): c.emit_signal("comecar", false))
	c.add_child(b)
	return c


## `continuar` = carregar a partir do checkpoint salvo.
func _comecar(continuar := false) -> void:
	# Precisa ser chamado dentro do evento de clique (regra do navegador para mouse e áudio).
	if _carregando:
		return
	Celular.pausa_toque = false
	Celular.capturar_mouse()
	var nivel := PRIMEIRO_NIVEL if ResourceLoader.exists(PRIMEIRO_NIVEL) else NIVEL_TESTE
	var spawn := "Spawn"
	if continuar:
		var destino := GameState.preparar_continuar()
		if ResourceLoader.exists(destino[0]):
			nivel = destino[0]
			spawn = destino[1]
	else:
		GameState.novo_jogo()
	if OS.has_feature("nivel_teste") or OS.get_cmdline_user_args().has("--teste"):
		nivel = NIVEL_TESTE
		spawn = "Spawn"
	hud.visible = true
	# a tela "Carregando..." nasce no mesmo quadro em que o título some (ver carregar_mundo)
	await carregar_mundo(nivel, spawn)
	if is_instance_valid(tela_titulo):
		tela_titulo.queue_free()
	GameState.jogando = true


## Troca o mundo atual pela cena `caminho`, com o jogador no marcador `spawn` (se não existir, tenta "Spawn").
## Com `aquecer_ativo`: tela "Carregando..." primeiro (desenhada ANTES do trabalho pesado) e, no fim, um aquecimento
## dos shaders por trás dela; só então devolve o controle. O mesmo vale para as trocas de nível (Transicao).
func carregar_mundo(caminho: String, spawn := "Spawn") -> void:
	_carregando = true
	var t0 := Time.get_ticks_msec()
	var tela: TelaCarregando = null
	if aquecer_ativo:
		tela = TelaCarregando.mostrar(self)
		if is_instance_valid(tela_titulo):
			tela_titulo.queue_free()     # a tela de carregamento (camada 130) já cobre o título no mesmo quadro
		await tela.aguardar_desenho()
		tela.definir(0.12, "Arrumando o mundo")
	Guia.cancelar()   # fala que sobrou na fila do nível anterior não pode vazar (nem segurar Guia.ocupado()) no novo
	for c in mundo.get_children():
		c.queue_free()
	await get_tree().process_frame
	if tela:
		tela.definir(0.2, "Lendo a planta do prédio")
		await get_tree().process_frame
	var cena: PackedScene = load(caminho)
	if tela:
		tela.definir(0.4, "Montando as salas")
		await get_tree().process_frame
	var nivel: Node3D = cena.instantiate()
	mundo.add_child(nivel)
	nivel_atual = caminho
	if nivel.has_signal("fim"):   # Braço Morto: guarda o final visto (a tela de título muda)
		nivel.connect("fim", Finais.registrar)
	player = Player.new()
	player.name = "Player"
	mundo.add_child(player)
	var marcador := nivel.find_child(spawn, true, false) as Node3D
	if marcador == null and nivel.has_method("ponto_spawn"):
		marcador = nivel.ponto_spawn(spawn)
	if marcador == null and spawn != "Spawn":
		push_warning("main: marcador '%s' não existe em %s; usando 'Spawn'" % [spawn, caminho])
		marcador = nivel.find_child("Spawn", true, false) as Node3D
	var destino := marcador.global_transform if marcador else Transform3D.IDENTITY
	player.global_transform = destino
	hud.conectar_player(player)
	if tela:
		# Durante o aquecimento o jogador fica "estacionado" bem acima do mapa: se ficasse no Spawn, os gatilhos de sala
		# disparariam (e a Guia começaria a falar) atrás da tela de carregamento. Mudar a camada de colisão não
		# adianta: o Godot só cria o par corpo/área quando o corpo entra de verdade.
		player.global_position = destino.origin + Vector3(0, 300, 0)
		tela.definir(0.62, "Preparando as luzes")
		await get_tree().process_frame
		await _aquecer(nivel, tela, destino)
		await tela.finalizar()
		player.global_transform = destino
		player.velocity = Vector3.ZERO
		player.set_physics_process(true)
	if nivel.has_method("iniciar"):
		nivel.iniciar(player)
	if tela:
		await tela.desaparecer()
	_carregando = false
	if aquecer_ativo:
		print("[carga] %s pronto em %d ms" % [caminho.get_file(), Time.get_ticks_msec() - t0])


## Renderiza o nível por trás da tela de carregamento: a 1ª vez que cada material aparece, o GPU compila o shader
## dele (vários segundos no navegador). Passa por alguns pontos de vista do próprio nível (`pontos_aquecer()`,
## opcional: Array de {"transform": Transform3D, "epoca": int opcional}) para o jogo não engasgar depois.
func _aquecer(nivel: Node3D, tela: TelaCarregando, destino: Transform3D) -> void:
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 200.0
	mundo.add_child(cam)
	var epoca0: int = GameState.epoca
	# o jogador fica parado (não cai quando a época remove o chão)
	player.set_physics_process(false)
	var pontos: Array = [{"transform": destino * Transform3D(Basis(), Vector3(0, Player.ALTURA_OLHOS, 0))}]
	if nivel.has_method("pontos_aquecer"):
		pontos.append_array(nivel.pontos_aquecer())
	else:
		for filho in nivel.get_children():
			if filho is Marker3D and filho.name.begins_with("Cam_") and pontos.size() < 5:
				pontos.append({"transform": (filho as Marker3D).global_transform})
	for i in pontos.size():
		var pt: Dictionary = pontos[i]
		if pt.has("epoca") and int(pt["epoca"]) != GameState.epoca:
			GameState.trocar_epoca(int(pt["epoca"]))
		cam.global_transform = pt["transform"]
		cam.make_current()
		tela.definir(remap(i, 0, pontos.size(), 0.66, 0.95), "Preparando as salas")
		await get_tree().process_frame
	if GameState.epoca != epoca0:
		GameState.trocar_epoca(epoca0)
	Efeitos.aquecer()
	tela.definir(0.97, "Quase pronto")
	await get_tree().process_frame
	player.camera.make_current()
	cam.queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if not GameState.jogando:
		return
	if GameState.flag("ui_aberta"):
		return
	if Celular.ativo:
		# celular: não há captura de mouse; Esc/P (teclado externo) pausam, e o toque é dos controles
		if e.is_action_pressed("pausa"):
			Celular.pausa_toque = true
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("pausa") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Alt-Tab no desktop: o mouse continua "capturado" e o jogo seguia rodando (a Figura Branca matava o jogador com a
## janela em segundo plano). Perder o foco solta o mouse, e o `_process` abaixo trata como pausa.
## No celular (sem captura de mouse) perder o foco liga a pausa por botão.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not GameState.jogando or GameState.flag("ui_aberta"):
			return
		if Celular.ativo:
			Celular.pausa_toque = true
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_dt: float) -> void:
	# Esc/Alt-Tab soltam o mouse no navegador: tratamos como pausa.
	if not GameState.jogando or DisplayServer.get_name() == "headless":
		return
	_atualizar_pausa()


## O jogo deve estar pausado agora? Desktop: mouse solto (menos nas telas de leitura/quiz, que soltam de propósito).
## Celular: só o botão de pausa (ou o aviso "vire o celular"), nunca o estado do ponteiro.
func deve_pausar() -> bool:
	if GameState.flag("ui_aberta"):
		return false
	if Celular.ativo:
		return Celular.pausa_toque or Celular.retrato
	return Input.mouse_mode != Input.MOUSE_MODE_CAPTURED


func _atualizar_pausa() -> void:
	var pausado: bool = deve_pausar()
	if get_tree().paused != pausado:
		get_tree().paused = pausado
		hud.mostrar_pausa(pausado)


func _on_morte(_causa: String) -> void:
	# Volta ao último checkpoint do mesmo nível. Níveis podem sobrescrever com `ao_morrer()`.
	var nivel := mundo.get_child(0) if mundo.get_child_count() > 0 else null
	if nivel and nivel.has_method("ao_morrer"):
		nivel.ao_morrer()
		return
	await Transicao.fade_out(0.2, Color(0.4, 0, 0))
	var tela := Morte.mostrar(_causa)
	await tela.terminou
	await carregar_mundo(nivel_atual, "Checkpoint_%d" % GameState.checkpoint_sala)
	await Transicao.fade_in(1.0)
