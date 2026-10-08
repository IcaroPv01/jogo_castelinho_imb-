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
signal visita_mudou(visita: int)
signal discos_mudou()
signal atencao_mudou(valor: float)

## Épocas novas vão sempre no FIM do enum (os inteiros 0..3 aparecem em saves e ferramentas de captura).
enum Epoca { E1950, E1975, E2019, E2020, E1967, ESEMDATA }
const NOMES_EPOCA := {Epoca.E1950: "1950", Epoca.E1975: "1975", Epoca.E2019: "2019", Epoca.E2020: "hoje",
	Epoca.E1967: "1967", Epoca.ESEMDATA: "????"}

## Versão 2 (docs/V2_ROTEIRO.md §2): quatro visitas ao mesmo Castelinho e depois o porão.
## No Castelinho os gatilhos são numerados pela sala BASE (1..22); a sala global = base + DESLOCAMENTO_VISITA.
const DESLOCAMENTO_VISITA := {1: 0, 2: 22, 3: 44, 4: 66}
const SALAS_POR_VISITA := 22
const PRIMEIRA_SALA_PORAO := 81

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
var visita: int = 1                   # 1..4 (5 = porão)
var discos: Array[int] = []           # épocas dos discos do Visor que o jogador tem (V2 §4.1)
var disco_atual: int = -1             # época do disco selecionado (-1 = nenhum)
var atencao: float = 0.0              # 0..1: "do outro lado, algo percebe você" (V2 §4.3); escrito pelo Visor


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
	if numero in SALAS_CHECKPOINT:
		checkpoint_sala = max(checkpoint_sala, numero)
	sala_mudou.emit(numero)
	_atualizar_corruption()
	salvar()


## Checkpoints da V2 (números GLOBAIS de sala; o marcador do nível é "Checkpoint_<n>"). Um no início de cada visita
## (base 1) e mais dois por visita, em salas base fixas: visitas 1 e 2 = bases 10 (corredor) e 16 (pé da escada);
## visita 3 = base 10 e base 17 (topo da Torre A, onde o Ato II devolve o jogador; as globais 55 a 60 são do trecho
## do Ato II e NÃO podem ser checkpoint do Castelinho); visita 4 = bases 8 (Povos) e 13 (Pescador), já comprimidas na
## numeração 67..80 (ver world/niveis/castelinho.gd, V4_SALAS). Porão: 81 (entrada), 86, 91, 95 (o quarto do Tito) e 96 (o porão cria `Checkpoint_N` sob demanda).
## O trecho do Ato II (55) tem checkpoint gravado por quem o dispara. A Braço Morto (100) entra na lista: antes ninguém
## o gravava e "Continuar" depois do fim voltava ao porão (sala 96).
const SALAS_CHECKPOINT := [1, 10, 16, 23, 32, 38, 45, 54, 61, 67, 72, 77, 81, 86, 91, 95, 96, 100]
## Cenas de destino do "Continuar" (o Porão cria os marcadores; se não existirem, o main cai no "Spawn").
const CENA_CASTELINHO := "res://world/niveis/castelinho.tscn"
const CENA_ATO2 := "res://world/niveis/ato2.tscn"
const CENA_PORAO := "res://world/niveis/porao.tscn"
const CENA_BRACO := "res://world/niveis/braco_morto.tscn"
## Checkpoint gravado ao abrir a porta do Ato II (visita 3, base 11 = sala 55).
const CHECKPOINT_ATO2 := 55


## Curva de corrupção por sala (V2_ROTEIRO §2): a visita 1 é limpa do começo ao fim (ritmo lento, pedido do Icaro).
func corruption_por_sala(n: int) -> float:
	if n <= 22:
		return 0.0
	if n <= 44:
		return remap(n, 23, 44, 0.10, 0.22)
	if n <= 66:
		return remap(n, 45, 66, 0.30, 0.45)
	if n <= 80:
		return remap(n, 67, 80, 0.50, 0.65)
	return clampf(remap(n, 81, TOTAL_SALAS, 0.70, 1.0), 0.0, 1.0)


# ---------------------------------------------------------------- visitas (V2)
## Sala global de um gatilho do Castelinho numerado pela sala base (1..22), na visita atual.
func sala_global(base: int) -> int:
	return base + DESLOCAMENTO_VISITA.get(visita, 0)


func entrar_sala_base(base: int) -> void:
	entrar_sala(sala_global(base))


func visita_da_sala(n: int) -> int:
	if n >= PRIMEIRA_SALA_PORAO:
		return 5
	return clampi((n - 1) / SALAS_POR_VISITA + 1, 1, 4)


func comecar_visita(n: int) -> void:
	visita = n
	visita_mudou.emit(visita)
	salvar()


# ---------------------------------------------------------------- discos e atenção do Visor (V2 §4)
func ganhar_disco(epoca_disco: int) -> void:
	if epoca_disco not in discos:
		discos.append(epoca_disco)
		disco_atual = epoca_disco
		discos_mudou.emit()
		salvar()


func selecionar_disco(epoca_disco: int) -> void:
	if epoca_disco in discos and epoca_disco != disco_atual:
		disco_atual = epoca_disco
		discos_mudou.emit()


func definir_atencao(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if not is_equal_approx(v, atencao):
		atencao = v
		atencao_mudou.emit(atencao)


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
	Epocas.aplicar(get_tree(), epoca)
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
		"visita": visita, "discos": discos, "disco_atual": disco_atual,
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
	# um campo com tipo errado (save editado ou de outra versão) usa o padrão em vez de abortar a leitura dos demais
	sala_maxima = int(_campo(dados, "sala_maxima", 0))
	checkpoint_sala = clampi(int(_campo(dados, "checkpoint_sala", 1)), 1, TOTAL_SALAS)
	flags = _campo(dados, "flags", {})
	flags.erase("ui_aberta")
	selos.assign(_campo(dados, "selos", []).map(func(x): return str(x)))
	contadores.merge(_campo(dados, "contadores", {}), true)
	sensibilidade = float(_campo(dados, "sensibilidade", 1.0))
	visita = clampi(int(_campo(dados, "visita", 1)), 1, 5)
	discos.assign(_campo(dados, "discos", []).map(func(x): return int(x)))
	disco_atual = int(_campo(dados, "disco_atual", -1))


## Valor de `chave` no save se tiver o mesmo tipo de `padrao` (int e float valem como número); senão, `padrao`.
func _campo(dados: Dictionary, chave: String, padrao: Variant) -> Variant:
	var v: Variant = dados.get(chave, padrao)
	var numero := func(x): return typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT
	if typeof(v) == typeof(padrao) or (numero.call(v) and numero.call(padrao)):
		return v
	return padrao


func tem_save() -> bool:
	return checkpoint_sala > 1


func novo_jogo() -> void:
	resetar_sessao()
	sala_maxima = 0
	checkpoint_sala = 1
	flags = {}
	selos.clear()
	contadores = {"paineis_lidos": 0, "quiz_acertos": 0, "mortes": 0, "sustos": 0}
	visita = 1
	discos.clear()
	disco_atual = -1
	salvar()


## Zera o que só vale durante uma partida (sala, corrupção, época), SEM mexer no save. Chamada ao voltar para a
## tela de título e antes de "Continuar". Avisa quem escuta a corrupção (Efeitos, Audio): antes, o valor era
## trocado sem sinal e uma nova partida começava com o visual e a música corrompidos do fim da anterior.
func resetar_sessao() -> void:
	sala_atual = 0
	corruption_manual = -1.0
	epoca = Epoca.E2020
	atencao = 0.0
	flags.erase("ui_aberta")
	if not is_equal_approx(corruption, 0.0):
		corruption = 0.0
		corruption_mudou.emit(corruption)


## Prepara o estado para retomar do último checkpoint salvo. Devolve [cena, marcador de chegada].
## Restaura `visita` (a partir do número do checkpoint) e a época (sempre a de hoje: o Visor só mostra outras
## épocas enquanto Q está apertado). Mapa dos checkpoints (V2_ROTEIRO §2 e SALAS_CHECKPOINT):
##   1..22 / 23..44 / 45..66 / 67..80 -> Castelinho, "Checkpoint_<n>" (o nível cria o nome global da visita atual e
##                                        também o nome da sala base "Checkpoint_<base>")
##   55 (visita 3)                    -> Ato II, "Checkpoint_55" (trecho 55..60 da visita 3)
##   81..99                           -> Porão, "Checkpoint_<o maior de 81, 86, 91, 95, 96 que seja <= cp>"
##   100                              -> Braço Morto, "Spawn"
func preparar_continuar() -> Array:
	resetar_sessao()
	var cp := checkpoint_sala
	flags.erase("saindo_para_barra")
	flags.erase("visor_travado")
	visita = visita_da_sala(cp)
	visita_mudou.emit(visita)
	if cp >= TOTAL_SALAS:
		return [CENA_BRACO, "Spawn"]
	if cp >= PRIMEIRA_SALA_PORAO:
		var melhor := PRIMEIRA_SALA_PORAO
		for c in [86, 91, 95, 96]:
			if cp >= c:
				melhor = c
		return [CENA_PORAO, "Checkpoint_%d" % melhor]
	if cp == CHECKPOINT_ATO2:
		return [CENA_ATO2, "Checkpoint_%d" % CHECKPOINT_ATO2]
	return [CENA_CASTELINHO, "Checkpoint_%d" % cp]


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
