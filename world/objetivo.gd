class_name Objetivo
extends RefCounted
## "O que fazer agora": uma frase curta para o Mapa da Visita (ui/mapa.gd) e, se quiserem, para dicas na tela.
## Lê o GameState (visita, sala, flags, discos). Nunca conta o final do jogo.
##
##   Objetivo.atual() -> String        a frase de agora (nunca vazia)
##   Objetivo.extras: Array[Callable]  ponto de extensão: cada Callable não recebe nada e devolve String. O PRIMEIRO que
##                                     devolver texto não vazio vence (outros módulos plugam aqui a caça aos discos).
##                                     Quem plugar deve tirar o Callable da lista quando a caça acabar.

static var extras: Array[Callable] = []


static func atual() -> String:
	for c in extras:
		if c.is_valid():
			var r: Variant = c.call()
			if r is String and (r as String).strip_edges() != "":
				return r
	return _base()


static func _base() -> String:
	var r := _base_visita()
	# Módulo 14: na calçada, se há lugar da cidade aberto e ainda não feito e a visita não tem outro objetivo, aponta a placa
	if r == GENERICO and not GameState.cidade_pendentes().is_empty() and GameState.visita <= 4 \
			and GameState.sala_atual == GameState.sala_global(1):
		return "Cidade: placa na calçada."
	return r


const GENERICO := "Siga a visita guiada: leia os painéis."


static func _base_visita() -> String:
	var v: int = GameState.visita
	var sala: int = GameState.sala_atual
	if sala >= 100:
		return "Siga em frente."
	if v >= 5 or sala >= GameState.PRIMEIRA_SALA_PORAO:
		return "Siga em frente."
	match v:
		1: return _visita1()
		2: return _visita2()
		3: return _visita3()
		4: return _visita4()
	return GENERICO


## Até que sala BASE (1..22) o jogador já chegou nesta visita (0 = nenhuma).
static func _base_alcancada(v: int) -> int:
	return clampi(GameState.sala_maxima - int(GameState.DESLOCAMENTO_VISITA.get(v, 0)), 0, GameState.SALAS_POR_VISITA)


## Visitas 1 e 2: o caminho depois dos discos e do mural (o mesmo percurso nas duas).
static func _caminho_ate_o_quiz(v: int) -> String:
	var b: int = _base_alcancada(v)
	if b >= 21:
		return "Responda ao quiz final, no fundo da Sala Medieval."
	if b >= 16:
		return "Suba pela escada, passe pelo terraço e desça até a Sala Medieval."
	if b >= 11:
		return "Procure a escada da torre, pela porta do Salão de Arte."
	return GENERICO


static func _diploma(v: int) -> bool:
	return bool(GameState.flag("evt_v%d_diploma" % v))


static func _visita1() -> String:
	var ach: int = GameState.passaporte_achados()
	var total: int = GameState.PASSAPORTE_IDS.size()
	var tem_1950: bool = GameState.discos.has(GameState.Epoca.E1950)
	if not tem_1950 and GameState.flag("passaporte_lancado"):
		if ach >= total:
			return "Passaporte completo! Fale com o Bentinho no corredor (sala 10)."
		return "Passaporte do Museu: ache %d objeto%s nas salas 1 a 10 (%d/%d)." % [total - ach, "" if total - ach == 1 else "s", ach, total]
	if not _diploma(1):
		return _caminho_ate_o_quiz(1)
	return "Saia pela porta, ao fundo da Sala Medieval."


static func _visita2() -> String:
	if not GameState.discos.has(GameState.Epoca.E1967):
		return "Procure o disco no Acervo."
	if not GameState.flag("viu_flashback_barra"):
		return "Olhe o mural da Sala do Pescador."
	if not _diploma(2):
		return _caminho_ate_o_quiz(2)
	return "Saia pela porta, ao fundo da Sala Medieval."


static func _visita3() -> String:
	if not GameState.flag("tem_lanterna"):
		return "Fale com o Quico, na calçada."
	if not GameState.flag("v3_ato2_feito"):
		return "Vá ao Salão de Arte, no fim do corredor: há uma porta nova."
	if not GameState.discos.has(GameState.Epoca.E1975):
		return "Suba à Torre A: algo brilha lá em cima."
	return "Vá à saída, na Sala Medieval. O Visor mostra outro caminho."


static func _visita4() -> String:
	if not GameState.discos.has(GameState.Epoca.E2019):
		return "Procure o disco de 2019: um painel está solto na Sala dos Povos."
	return "Desça ao porão. Use o Visor com o disco de 2019 na Sala Medieval."
