class_name MiniGameBase
extends Node3D
## Base dos minigames do Módulo 16 (a mesma receita da tarrafa da Barra, `barra.gd`): cena pequena e própria, Tainá/Quico
## explicam, UMA ação só (clique, [E] ou o botão Interagir do celular = ação "interagir"), rodadas curtas, uma virada
## estranha no fim. O jogador não anda: a câmera fica parada olhando o "palco" (`ponto_jogador()`, `alvo_olhar()`).
##
## COMO ESCREVER UM MINIGAME (herde desta classe, um arquivo + uma .tscn mínima como `barra.tscn`):
##   - `id` (const-like): "lanchao", "quico", "lotes", "ponte", "caderno". Vira flag `mini_<id>_feito`, pista `pista_mini_<id>`
##     e selo `mini_<id>`.
##   - `_montar()`: cria o cenário (céu, chão, props) por código. Use `ambiente(...)` para céu/neblina.
##   - `_rodar() -> bool`: coroutine do jogo todo; devolve true se o jogador venceu. TODO await passa por `esperar()` ou
##     `esperar_acao()`: eles devolvem false se o jogador PULOU, e aí você faz `return false` na hora.
##       if not await falar("taina", [...]): return false
##       if not await esperar(1.5): return false
##   - `acionar()`: o que a ação do jogador chama (público: os testes chamam). Padrão: marca `_acao_pendente` para o
##     `esperar_acao()`; sobrescreva se o jogo for em tempo real e quiser reagir no mesmo quadro (leia `acao_vale()`).
##   - `fala_fim`: linhas ditas ao vencer, `quem_fala`: personagem do Guia. `dica_texto(pc, toque)`: texto grande no pé da tela.
## Regras (iguais às da Barra): vencer = 1 pista do Tito (uma vez) + selo; pular = nada, e a entrada continua lá para jogar
## de novo. Corrupção fica baixa e volta à curva ao sair. Ninguém é ferido: a virada é só sugestão.
signal terminou(venceu: bool)

const CASTELINHO := "res://world/niveis/castelinho.tscn"
const SPAWN_DE_VOLTA := "Spawn_volta_mini_"   # + id; criado por MinigamesCastelo no Castelinho

@export var destino := CASTELINHO
@export var corrupcao := 0.1

var id := "mini"
var quem_fala := "taina"
var fala_fim: Array = []
var player: Player
var cancelado := false
var terminado := false
var _acao_pendente := false
var _desde_inicio := 0.0
var _camada: CanvasLayer
var _lbl_placar: Label
var _lbl_dica: Label
var _btn_pular: Button
var _cortina: ColorRect
var env: Environment


func _init() -> void:
	var mk := Marker3D.new()      # o Main procura "Spawn"; iniciar() move o jogador para `ponto_jogador()`
	mk.name = "Spawn"
	add_child(mk)


# ============================================================================ contrato com o Main
func iniciar(p: Player) -> void:
	player = p
	player.pode_mover = false
	GameState.definir_corruption_manual(corrupcao)
	_criar_hud()
	_montar()
	var ponto := ponto_jogador()
	player.global_position = ponto
	player.olhar_para(alvo_olhar())
	_rodar_tudo()


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.definir_corruption_manual(-1.0)
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)


## RedeSeguranca: o jogador fica parado de propósito; não há o que resgatar.
func rede_seguranca_ativa() -> bool:
	return false


# ============================================================================ para sobrescrever
func _montar() -> void:
	pass


func _rodar() -> bool:
	return true


func ponto_jogador() -> Vector3:
	return Vector3(0, 0.1, 0)


func alvo_olhar() -> Vector3:
	return Vector3(0, 1.5, -10)


## Hora de apertar? (os jogos em tempo real consultam isto em `acionar`.) Ignora o clique que só passou a fala.
func acao_vale() -> bool:
	return not terminado and not cancelado and _desde_inicio > 0.4 and not Guia.ocupado()


func acionar() -> void:
	if acao_vale():
		_acao_pendente = true


# ============================================================================ ajudas
func falar(quem: String, linhas: Array) -> bool:
	await Guia.falar(quem, linhas, true)
	return not cancelado


func esperar(seg: float) -> bool:
	var t := 0.0
	while t < seg and not cancelado:
		await get_tree().process_frame
		t += get_process_delta_time()
	return not cancelado


## Espera o jogador apertar a ação. `limite` (s) > 0: devolve true mesmo sem ação ao estourar (veja `_acao_pendente`).
func esperar_acao(limite := 0.0) -> bool:
	_acao_pendente = false
	var t := 0.0
	while not _acao_pendente and not cancelado and (limite <= 0.0 or t < limite):
		await get_tree().process_frame
		t += get_process_delta_time()
	var apertou := _acao_pendente
	_acao_pendente = false
	return apertou and not cancelado


func placar(texto: String) -> void:
	_lbl_placar.text = texto


func dica(pc: String, toque: String) -> void:
	_lbl_dica.text = Celular.dica(pc, toque) if pc != "" else ""
	_lbl_dica.visible = pc != ""


func ambiente(topo: Color, horizonte: Color, neblina: Color, dens := 0.02, luz := 1.0) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = topo
	mat.sky_horizon_color = horizonte
	mat.ground_horizon_color = horizonte
	mat.ground_bottom_color = neblina
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizonte.lerp(Color.WHITE, 0.3)
	env.ambient_light_energy = luz
	env.fog_enabled = true
	env.fog_light_color = neblina
	env.fog_density = dens
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 35, 0)
	sol.light_energy = 0.8 * luz
	add_child(sol)


func escurecer(alfa: float, dur := 0.6) -> void:
	create_tween().tween_property(_cortina, "color:a", alfa, dur)


# ============================================================================ fluxo
func _rodar_tudo() -> void:
	await get_tree().process_frame
	var venceu: bool = await _rodar()
	if not cancelado:
		_encerrar(venceu)


func _process(dt: float) -> void:
	_desde_inicio += dt
	if player and not terminado and Input.is_action_just_pressed("interagir"):
		acionar()


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_BACKSPACE:
		pular()


## Pula o minigame (botão ou Backspace): nada é ganho e o jogador volta para tentar de novo quando quiser.
func pular() -> void:
	if terminado:
		return
	cancelado = true
	terminado = true
	Guia.cancelar()
	await _voltar()


func _encerrar(venceu: bool) -> void:
	terminado = true
	if venceu:
		GameState.set_flag("mini_%s_feito" % id, true)
		if not GameState.flag("pista_mini_" + id):
			GameState.set_flag("pista_mini_" + id, true)
			GameState.somar("pistas_tito")
		GameState.ganhar_selo("mini_" + id)
		if not fala_fim.is_empty():
			await Guia.falar(quem_fala, fala_fim, true)
	terminou.emit(venceu)
	await _voltar()


func _voltar() -> void:
	await Transicao.ir_para(destino, SPAWN_DE_VOLTA + id)


func _criar_hud() -> void:
	_camada = CanvasLayer.new()
	_camada.name = "MinigameUI"
	_camada.layer = 8
	add_child(_camada)
	_lbl_placar = Label.new()
	_lbl_placar.anchor_left = 1.0
	_lbl_placar.anchor_right = 1.0
	_lbl_placar.offset_left = -24.0
	_lbl_placar.offset_right = -24.0
	_lbl_placar.offset_top = 22.0
	_lbl_placar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_estilo(_lbl_placar, 28)
	_camada.add_child(_lbl_placar)
	_lbl_dica = Label.new()
	_lbl_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_dica.offset_top = -150.0
	_estilo(_lbl_dica, 30)
	_lbl_dica.visible = false
	_camada.add_child(_lbl_dica)
	# botão Pular: sempre à vista (no PC o mouse está preso: Backspace; no celular, toque)
	var pular_camada := CanvasLayer.new()
	pular_camada.layer = 14
	add_child(pular_camada)
	_btn_pular = Button.new()
	_btn_pular.text = Celular.dica("Pular [Backspace]", "Pular")
	_btn_pular.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_btn_pular.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_btn_pular.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_btn_pular.offset_left = -24.0
	_btn_pular.offset_right = -24.0
	_btn_pular.offset_top = -24.0
	_btn_pular.offset_bottom = -24.0
	_btn_pular.add_theme_font_size_override("font_size", 20)
	_btn_pular.focus_mode = Control.FOCUS_NONE
	_btn_pular.pressed.connect(pular)
	pular_camada.add_child(_btn_pular)
	var preta := CanvasLayer.new()
	preta.layer = 15
	add_child(preta)
	_cortina = ColorRect.new()
	_cortina.color = Color(0.0, 0.03, 0.06, 0.0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	preta.add_child(_cortina)


func _estilo(l: Label, tam: int) -> void:
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
