class_name MinigamesCastelo
extends RefCounted
## Entradas dos minigames do Módulo 16 dentro do Castelinho (um objeto "Jogar" por minigame, no caminho da visita).
## Cada minigame é uma cena própria (`world/niveis/mini_<id>.tscn`, base `minigame_base.gd`); aqui só vive a PORTA:
##   - um Interagivel com um "!" amarelo que pulsa (some quando o jogador vence);
##   - ao entrar na sala (`ao_entrar(base)`) o mascote avisa uma vez (fala `aviso`) e o Mapa (M) diz o que fazer;
##   - um Marker3D "Spawn_volta_mini_<id>" onde o jogador reaparece quando o minigame acaba ou é pulado.
## Vencer = flag `mini_<id>_feito` (+ pista `pista_mini_<id>` e selo, feitos pela base). Pular não ganha nada e a porta continua.
## Tabela: `visita` (1..4), `sala` = sala BASE (1..22) onde o aviso fala e o Mapa aponta, `pos`/`tam` = onde fica a porta
## no nível (a origem do Interagivel), `volta`/`yaw` = onde o jogador reaparece (de frente para a porta, 1,5 m na frente).
## `epocas` = [] (sempre) ou lista de épocas em que a porta existe (Epocas.marcar). `ativo` = false esconde a porta enquanto
## o minigame não existe. Os fatos usados nos minigames têm fonte em docs/pesquisa/.

const ENTRADAS := {
	"lanchao": {"ativo": false, "visita": 2, "sala": 13, "pos": Vector3(0, 1.5, 0), "tam": Vector3(2.0, 2.0, 0.6),
		"texto": "Ler a gravura do barco", "cena": "res://world/niveis/mini_lanchao.tscn",
		"quem": "taina", "aviso": ["Tem uma gravura de barco aqui! Dá vontade de entrar nela..."],
		"mapa": "Jogue o minigame da gravura do barco (Sala do Pescador).",
		"volta": Vector3(0, 0.1, 1.5), "yaw": 0.0, "epocas": []},
	"quico": {"ativo": false, "visita": 1, "sala": 16, "pos": Vector3(0, 1.5, 0), "tam": Vector3(1.0, 1.0, 1.0),
		"texto": "Jogar com o Quico", "cena": "res://world/niveis/mini_quico.tscn",
		"quem": "quico", "aviso": ["PIII! Quer brincar de Quico Diz? É rapidinho!"],
		"mapa": "Jogue Quico Diz com o Quico.",
		"volta": Vector3(0, 0.1, 1.5), "yaw": 0.0, "epocas": []},
	"lotes": {"ativo": false, "visita": 3, "sala": 13, "pos": Vector3(0, 1.5, 0), "tam": Vector3(2.0, 2.0, 0.6),
		"texto": "Planejar a cidade", "cena": "res://world/niveis/mini_lotes.tscn",
		"quem": "taina", "aviso": ["Um mapa de loteamento! Vamos planejar a cidade-jardim?"],
		"mapa": "Jogue o minigame do mapa de loteamento.",
		"volta": Vector3(0, 0.1, 1.5), "yaw": 0.0, "epocas": []},
	# Dependem do Módulo 14 (Ponte e Rua das casas): ficam em outro nível, não aqui.
}

var _c: Node3D
var _visita := 1
var _portas: Dictionary = {}      # id -> Interagivel
var _avisados: Dictionary = {}


func _init(castelinho: Node3D, visita: int) -> void:
	_c = castelinho
	_visita = visita


func montar() -> void:
	for id: String in ENTRADAS:
		var e: Dictionary = ENTRADAS[id]
		if not bool(e["ativo"]) or int(e["visita"]) != _visita:
			continue
		var it := Interagivel.new(e["texto"], e["tam"], func(_p: Node) -> void: entrar(id))
		it.name = "Mini_" + id
		it.position = e["pos"]
		_c.add_child(it)
		var marca := Construtor.rotulo(it, "!", Vector3(0, 0.9, 0), 90, Color(1.0, 0.85, 0.2))
		marca.pixel_size = 0.008
		marca.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marca.no_depth_test = true
		marca.outline_size = 16
		marca.outline_modulate = Color(0.2, 0.05, 0.0)
		marca.name = "Marca"
		var tw := it.create_tween().set_loops()
		tw.tween_property(marca, "position:y", 1.05, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(marca, "position:y", 0.85, 0.5).set_trans(Tween.TRANS_SINE)
		var mk := Marker3D.new()
		mk.name = SPAWN_PREFIXO + id
		mk.position = e["volta"]
		mk.rotation_degrees.y = float(e["yaw"])
		_c.add_child(mk)
		if (e["epocas"] as Array).size() > 0:
			Epocas.marcar(it, e["epocas"])
		_portas[id] = it
		_atualizar_marca(id)
	if not _portas.is_empty():
		# tira os Callables de níveis já destruídos antes de plugar o novo
		for i in range(Objetivo.extras.size() - 1, -1, -1):
			if not Objetivo.extras[i].is_valid():
				Objetivo.extras.remove_at(i)
		Objetivo.extras.append(objetivo)


const SPAWN_PREFIXO := "Spawn_volta_mini_"


func feito(id: String) -> bool:
	return GameState.flag("mini_%s_feito" % id)


func _atualizar_marca(id: String) -> void:
	var it: Interagivel = _portas.get(id)
	if it and is_instance_valid(it):
		var m := it.get_node_or_null("Marca")
		if m:
			m.visible = not feito(id)
		it.texto_interacao = ENTRADAS[id]["texto"] + (" (de novo)" if feito(id) else "")


func entrar(id: String) -> void:
	if Transicao.ocupado:
		return
	GameState.set_flag("mini_visitou_" + id, true)
	await Transicao.ir_para(ENTRADAS[id]["cena"], "Spawn")


## O mascote avisa uma vez por visita ao entrar na sala certa (chamado por castelinho.gd `_evento`).
func ao_entrar(base: int) -> void:
	for id: String in _portas:
		var e: Dictionary = ENTRADAS[id]
		if int(e["sala"]) != base or feito(id) or _avisados.has(id):
			continue
		_avisados[id] = true
		await Guia.falar(e["quem"], e["aviso"])


## Mapa da Visita (M): só fala enquanto o jogador está na sala da porta e ainda não venceu, para não esconder o caminho.
func objetivo() -> String:
	if not is_instance_valid(_c):
		return ""
	for id: String in _portas:
		var e: Dictionary = ENTRADAS[id]
		if not feito(id) and GameState.sala_atual == _c.call("_global", int(e["sala"])):
			return e["mapa"]
	return ""
