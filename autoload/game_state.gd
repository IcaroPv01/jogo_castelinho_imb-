extends Node
## Estado global do jogo. Contrato central: outros sistemas leem daqui e escutam os sinais.
##
## - sala_atual: contador de salas (1..TOTAL_SALAS), estilo Spooky's.
## - corruption: 0..1, controla shader PSX, névoa, áudio e falhas de UI (ver docs/PLANO.md §7.4).
## - epoca: camada de tempo do Castelinho (Visor do Tempo, PLANO §5.1).
## - contadores: contagens invisíveis que decidem finais.

signal sala_mudou(numero: int)
signal corruption_mudou(valor: float)
signal epoca_mudou(epoca: int)
signal flag_mudou(nome: String, valor: Variant)
signal jogador_morreu(causa: String)

enum Epoca { E1950, E1975, E2019, E2020 }
const NOMES_EPOCA := {Epoca.E1950: "1950", Epoca.E1975: "1975", Epoca.E2019: "2019", Epoca.E2020: "hoje"}

const TOTAL_SALAS := 100      # jogo completo
const SALAS_DEMO := 30        # MVP
const ARQUIVO_SAVE := "user://save.json"

var sala_atual: int = 0
var sala_maxima: int = 0
var corruption: float = 0.0
var corruption_manual: float = -1.0   # >= 0 sobrescreve a curva por sala (cenas especiais)
var epoca: int = Epoca.E2020
var flags: Dictionary = {}            # ex.: "tem_visor", "tem_lanterna", "viu_flashback_barra"
var selos: Array[String] = []         # selos do quiz (Ato I)
var contadores := {"paineis_lidos": 0, "quiz_acertos": 0, "mortes": 0, "sustos": 0}
var checkpoint_sala: int = 1
var sensibilidade: float = 1.0
var jogando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_registrar_inputs()
	carregar()


# ---------------------------------------------------------------- salas
func entrar_sala(numero: int) -> void:
	if numero == sala_atual:
		return
	sala_atual = numero
	sala_maxima = max(sala_maxima, numero)
	if numero % 5 == 1 or numero == 1:
		checkpoint_sala = max(checkpoint_sala, numero)
	sala_mudou.emit(numero)
	_atualizar_corruption()
	salvar()


## Curva de corrupção por sala (só MVP; ajustar quando houver as 100 salas).
## Salas 1-12 limpas, 13-25 sobem devagar, 26-30 sobem rápido.
func corruption_por_sala(n: int) -> float:
	if n <= 12:
		return 0.0
	if n <= 25:
		return remap(n, 12, 25, 0.0, 0.25)
	if n <= 30:
		return remap(n, 25, 30, 0.3, 0.6)
	return clampf(remap(n, 30, TOTAL_SALAS, 0.6, 1.0), 0.0, 1.0)


func definir_corruption_manual(v: float) -> void:
	corruption_manual = v
	_atualizar_corruption()


func _atualizar_corruption() -> void:
	var alvo := corruption_manual if corruption_manual >= 0.0 else corruption_por_sala(sala_atual)
	if not is_equal_approx(alvo, corruption):
		corruption = alvo
		corruption_mudou.emit(corruption)


# ---------------------------------------------------------------- épocas
func trocar_epoca(nova: int) -> void:
	if nova == epoca:
		return
	epoca = nova
	epoca_mudou.emit(epoca)


# ---------------------------------------------------------------- flags
func set_flag(nome: String, valor: Variant = true) -> void:
	flags[nome] = valor
	flag_mudou.emit(nome, valor)
	salvar()


func flag(nome: String, padrao: Variant = false) -> Variant:
	return flags.get(nome, padrao)


func somar(contador: String, qtd: int = 1) -> void:
	contadores[contador] = contadores.get(contador, 0) + qtd


func ganhar_selo(id: String) -> void:
	if id not in selos:
		selos.append(id)
		salvar()


func matar_jogador(causa: String) -> void:
	somar("mortes")
	jogador_morreu.emit(causa)


# ---------------------------------------------------------------- save (user:// = IndexedDB na web)
func salvar() -> void:
	var dados := {
		"sala_maxima": sala_maxima, "checkpoint_sala": checkpoint_sala, "flags": flags,
		"selos": selos, "contadores": contadores, "sensibilidade": sensibilidade,
	}
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados))


func carregar() -> void:
	if not FileAccess.file_exists(ARQUIVO_SAVE):
		return
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.READ)
	var dados = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(dados) != TYPE_DICTIONARY:
		return
	sala_maxima = int(dados.get("sala_maxima", 0))
	checkpoint_sala = int(dados.get("checkpoint_sala", 1))
	flags = dados.get("flags", {})
	selos.assign(dados.get("selos", []))
	contadores.merge(dados.get("contadores", {}), true)
	sensibilidade = float(dados.get("sensibilidade", 1.0))


func tem_save() -> bool:
	return checkpoint_sala > 1


func novo_jogo() -> void:
	sala_atual = 0
	sala_maxima = 0
	checkpoint_sala = 1
	corruption = 0.0
	corruption_manual = -1.0
	epoca = Epoca.E2020
	flags = {}
	selos.clear()
	contadores = {"paineis_lidos": 0, "quiz_acertos": 0, "mortes": 0, "sustos": 0}
	salvar()


# ---------------------------------------------------------------- inputs (definidos em código: evita erro de formato no project.godot)
func _registrar_inputs() -> void:
	var teclas := {
		"frente": [KEY_W, KEY_UP], "tras": [KEY_S, KEY_DOWN],
		"esquerda": [KEY_A, KEY_LEFT], "direita": [KEY_D, KEY_RIGHT],
		"correr": [KEY_SHIFT], "interagir": [KEY_E], "visor": [KEY_Q],
		"lanterna": [KEY_F], "pausa": [KEY_ESCAPE, KEY_P], "avancar_dialogo": [KEY_SPACE, KEY_ENTER],
	}
	for acao in teclas:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for k in teclas[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(acao, ev)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interagir", clique)
