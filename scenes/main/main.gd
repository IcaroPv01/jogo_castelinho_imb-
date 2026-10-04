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
	b.text = "CLIQUE PARA COMEÇAR"
	b.set_anchors_preset(Control.PRESET_CENTER)
	b.position = Vector2(-180, -30)
	b.size = Vector2(360, 60)
	b.pressed.connect(func(): c.emit_signal("comecar", false))
	c.add_child(b)
	return c


## `continuar` = carregar a partir do checkpoint salvo.
func _comecar(continuar := false) -> void:
	# Precisa ser chamado dentro do evento de clique (regra do navegador para mouse e áudio).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not continuar:
		GameState.novo_jogo()
	tela_titulo.queue_free()
	hud.visible = true
	GameState.jogando = true
	var nivel := PRIMEIRO_NIVEL if ResourceLoader.exists(PRIMEIRO_NIVEL) else NIVEL_TESTE
	if OS.has_feature("nivel_teste") or OS.get_cmdline_user_args().has("--teste"):
		nivel = NIVEL_TESTE
	await carregar_mundo(nivel, "Spawn")


func carregar_mundo(caminho: String, spawn := "Spawn") -> void:
	for c in mundo.get_children():
		c.queue_free()
	await get_tree().process_frame
	var cena: PackedScene = load(caminho)
	var nivel: Node3D = cena.instantiate()
	mundo.add_child(nivel)
	nivel_atual = caminho
	player = Player.new()
	player.name = "Player"
	mundo.add_child(player)
	var marcador := nivel.find_child(spawn, true, false) as Node3D
	if marcador == null and nivel.has_method("ponto_spawn"):
		marcador = nivel.ponto_spawn(spawn)
	if marcador:
		player.global_transform = marcador.global_transform
	hud.conectar_player(player)
	if nivel.has_method("iniciar"):
		nivel.iniciar(player)


func _unhandled_input(e: InputEvent) -> void:
	if not GameState.jogando:
		return
	if GameState.flag("ui_aberta"):
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("pausa") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_dt: float) -> void:
	# Esc/Alt-Tab soltam o mouse no navegador: tratamos como pausa.
	if not GameState.jogando or DisplayServer.get_name() == "headless":
		return
	# Telas de leitura/quiz soltam o mouse de propósito: não contam como pausa.
	var pausado := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not GameState.flag("ui_aberta")
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
	await carregar_mundo(nivel_atual, "Checkpoint_%d" % GameState.checkpoint_sala)
	await Transicao.fade_in(1.0)
