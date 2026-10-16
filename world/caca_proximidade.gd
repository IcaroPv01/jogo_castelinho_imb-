class_name CacaProximidade
extends Node
## PISTA DE PROXIMIDADE das caças dos discos (módulo 2, parte 3). Cada nível com caça (castelinho, porão) instala um:
##     CacaProximidade.instalar(self)
## Olha os itens do grupo "caca_item" (ver world/feixe_caca.gd) da caça ATIVA (`GameState.caca_ativa()`):
##   - a menos de RAIO m de um item que o jogador PODE ver agora (época certa): um "ping" suave que repete mais depressa
##     quanto mais perto (`intervalo()`: ~1,8 s a 10 m, ~0,35 s colado);
##   - a menos de RAIO m de um item que existe, mas em OUTRA época (Visor desligado ou disco errado): uma dica curta na tela,
##     UMA vez por item na sessão: "Algo brilha em outra época: ligue o Q." (ou "aperte N para trocar de disco").
## Sem item por perto, sem caça ativa, com fala da Guia ou tela aberta, não faz nada.

const RAIO := 10.0              # m
const INTERVALO_LONGE := 1.8    # s entre pings a RAIO m
const INTERVALO_PERTO := 0.35   # s entre pings colado no item
const GRUPO_NOS := "caca_proximidade"

static var _avisados := {}      # "<disco>:<id>" -> true (dica já dada nesta sessão)

var pings := 0                  # quantos pings já tocou (para testes)
var ultimo_alvo := ""           # chave "<disco>:<id>" do item que está pingando agora ("" = nenhum)
var ultima_dica := ""           # a última dica mostrada (para testes)
var _t := 0.0
var _prox_ping := 0.0
var _varrer := 0.0
var _dist := INF                # distância (m) do item mais perto que o jogador pode ver (INF = nenhum)
var _visor: Visor


static func instalar(pai: Node) -> CacaProximidade:
	for n in pai.get_tree().get_nodes_in_group(GRUPO_NOS):
		return n as CacaProximidade
	var c := CacaProximidade.new()
	c.name = "CacaProximidade"
	pai.add_child(c)
	return c


## Esquece as dicas já dadas (nova partida, testes).
static func resetar() -> void:
	_avisados.clear()


## Segundos entre pings à distância `d` (m): linear de INTERVALO_PERTO (0 m) a INTERVALO_LONGE (RAIO m).
static func intervalo(d: float) -> float:
	return lerpf(INTERVALO_PERTO, INTERVALO_LONGE, clampf(d / RAIO, 0.0, 1.0))


func _ready() -> void:
	add_to_group(GRUPO_NOS)


func _process(dt: float) -> void:
	_t += dt
	_prox_ping -= dt
	_varrer -= dt
	if _varrer <= 0.0:
		_varrer = 0.15
		_olhar()
	if _dist < RAIO and _prox_ping <= 0.0 and _pode():
		_prox_ping = intervalo(_dist)
		pings += 1
		var perto := 1.0 - clampf(_dist / RAIO, 0.0, 1.0)
		Audio.sfx("ping", lerpf(-9.0, 0.0, perto), lerpf(0.92, 1.18, perto))


func _pode() -> bool:
	return not GameState.flag("ui_aberta") and not Guia.ocupado()


## Varre os itens: acha o mais perto que se vê (para o ping) e dá a dica dos que estão em outra época.
func _olhar() -> void:
	_dist = INF
	ultimo_alvo = ""
	var d_ativo := GameState.caca_ativa()
	var jog := get_tree().get_first_node_in_group("player") as Node3D
	if d_ativo < 0 or jog == null:
		return
	for n in get_tree().get_nodes_in_group(FeixeCaca.GRUPO):
		var item := n as Node3D
		if item == null or int(item.get_meta("caca_disco", -1)) != d_ativo or not item.is_inside_tree():
			continue
		var d := item.global_position.distance_to(jog.global_position)
		if d >= RAIO:
			continue
		var chave := "%d:%s" % [d_ativo, str(item.get_meta("caca_id", ""))]
		if item.is_visible_in_tree():
			if d < _dist:
				_dist = d
				ultimo_alvo = chave
		elif not _avisados.has(chave) and _pode():
			_avisados[chave] = true
			ultima_dica = texto_dica(d_ativo)
			Efeitos.aviso(Celular.adaptar(ultima_dica), 4.0)


## "Algo brilha em outra época: ligue o Q." ou, com o Visor já ligado no disco errado, a tecla do disco certo.
static func texto_dica(d: int) -> String:
	var previo := int(GameState.CACAS[d]["previo"]) if GameState.CACAS.has(d) else -1
	var ligado := Input.is_action_pressed("visor")
	if ligado and previo >= 0 and GameState.disco_atual != previo:
		var slot := Visor.ORDEM_DISCOS.find(previo) + 1
		if slot > 0:
			return "Algo brilha em outra época: aperte %d para trocar de disco." % slot
	return "Algo brilha em outra época: ligue o Q."
