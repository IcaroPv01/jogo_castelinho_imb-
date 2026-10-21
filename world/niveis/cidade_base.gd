class_name CidadeBase
extends Node3D
## BASE DOS LUGARES DA CIDADE (Módulo 14: "mais partes da cidade"). Cada lugar (`cidade_casas`, `cidade_barra`, `cidade_ponte`,
## `cidade_praia`, `cidade_rodoviaria`) é uma cena PEQUENA e OPCIONAL, entrada pela placa da prefeitura fictícia na calçada do
## Castelinho (`ui/placa_cidade.gd`) e que volta para a mesma calçada. NÃO confundir com `barra.gd` (o flashback da tarrafa, V2).
##
## COMO FAZER UM LUGAR (a subclasse só preenche ganchos; o arquivo `cidade_<id>.gd` é do dono do lugar):
##   extends CidadeBase
##   func _configurar() -> void:      # 1º: dados do lugar (id, rotulo, area, hora, clima, spawn, ...)
##   func _construir() -> void:       # cenário (filhos deste nó); roda no _ready, depois do chão, da borda e do portão
##   func _tarefa() -> void:          # lógica da tarefa e do objetivo; roda em `iniciar` (o jogador já existe)
##   func _material_chao() -> Material  # (opcional) outro chão
## O que a base já entrega: ambiente (céu, Sol/Lua, névoa; `aplicar_ambiente(hora, clima)` troca em tempo de jogo), chão com
## colisão do tamanho da AREA, BORDA invisível (colisão alta ao redor da AREA), REDE DE SEGURANÇA (y < QUEDA_Y ou fora da AREA
## devolve o jogador ao Spawn), HUD "CIDADE · <ROTULO>" (o contador de salas e a sala atual não mudam), portão "Voltar ao
## Castelinho" perto do Spawn, `pista()`, `concluir()`, `sair()`, objetivo no Mapa (`definir_objetivo`) e `dados_mapa()`.
##
## Contrato com o Main (igual a barra.gd/braco_morto.gd): marcador `Spawn`, `iniciar(p: Player)`. Não mexe em sala, visita nem
## época do Castelinho. Lê/escreve: flags `pista_<id>` + contador `pistas_tito` (pistas), `cidade_<id>_feito` (concluir).
## A tabela do lugar está em `GameState.CIDADE[id]` (cena, rótulo, quando abre, pistas, texto).
## Orçamento web: poucos draw calls (agrupe com MultiMesh), no máximo 6 luzes, sem sombras.

signal concluiu
signal saiu

enum Hora { DIA, FIM_DE_TARDE, ENTARDECER, NOITE }
enum Clima { LIMPO, NEBLINA, RESSACA }

## Cair abaixo disso (ou sair da AREA) devolve o jogador ao Spawn.
const QUEDA_Y := -8.0
const ALTURA_BORDA := 10.0
const ESPESSURA_BORDA := 1.0
## Fora da AREA por mais que isso (m) = rede de segurança (a borda de colisão já segura quem anda normalmente).
const FOLGA_AREA := 1.0

## Céus. sol = direção PARA o Sol/Lua (como em barra.gd). Cores em Color; energias em float.
const CEUS := {
	Hora.DIA: {"topo": Color(0.28, 0.5, 0.88), "horizonte": Color(0.78, 0.86, 0.95), "chao_h": Color(0.74, 0.8, 0.85),
		"chao_b": Color(0.3, 0.3, 0.32), "amb": Color(0.66, 0.7, 0.76), "amb_e": 0.95, "sol_cor": Color(1.0, 0.95, 0.82),
		"sol_e": 1.1, "sol": Vector3(-0.4, 0.75, -0.5), "nevoa": Color(0.76, 0.84, 0.92)},
	Hora.FIM_DE_TARDE: {"topo": Color(0.2, 0.3, 0.58), "horizonte": Color(1.0, 0.74, 0.46), "chao_h": Color(0.9, 0.64, 0.44),
		"chao_b": Color(0.28, 0.2, 0.22), "amb": Color(0.64, 0.52, 0.48), "amb_e": 0.85, "sol_cor": Color(1.0, 0.72, 0.44),
		"sol_e": 1.2, "sol": Vector3(-0.62, 0.28, -0.78), "nevoa": Color(0.92, 0.7, 0.52)},
	Hora.ENTARDECER: {"topo": Color(0.13, 0.15, 0.36), "horizonte": Color(1.0, 0.55, 0.28), "chao_h": Color(0.95, 0.5, 0.3),
		"chao_b": Color(0.25, 0.14, 0.2), "amb": Color(0.6, 0.42, 0.42), "amb_e": 0.75, "sol_cor": Color(1.0, 0.62, 0.34),
		"sol_e": 0.9, "sol": Vector3(-0.62, 0.10, -0.78), "nevoa": Color(0.9, 0.55, 0.4)},
	Hora.NOITE: {"topo": Color(0.012, 0.02, 0.07), "horizonte": Color(0.07, 0.09, 0.18), "chao_h": Color(0.04, 0.05, 0.1),
		"chao_b": Color(0.02, 0.025, 0.05), "amb": Color(0.3, 0.36, 0.55), "amb_e": 0.9, "sol_cor": Color(0.55, 0.65, 0.95),
		"sol_e": 0.35, "sol": Vector3(0.3, 0.8, -0.5), "nevoa": Color(0.04, 0.06, 0.12)},
}
## Névoa por clima: [início, fim] em metros (profundidade) e quanto escurecer o céu/luz.
const NEVOAS := {Clima.LIMPO: [70.0, 420.0, 1.0], Clima.NEBLINA: [4.0, 70.0, 0.9], Clima.RESSACA: [10.0, 120.0, 0.78]}

# --- dados do lugar: a subclasse muda em `_configurar()`
var id := ""                                  # chave de GameState.CIDADE ("casas", "barra", ...)
var rotulo := ""                              # nome curto (HUD "CIDADE · <rótulo>"); vazio = o da tabela
var area := Rect2(-30.0, -30.0, 60.0, 60.0)   # AREA jogável: (x, z, largura em x, profundidade em z)
var hora: int = Hora.FIM_DE_TARDE
var clima: int = Clima.LIMPO
var spawn_pos := Vector3(0.0, 0.1, 0.0)
var spawn_yaw := 0.0                          # graus; 0 = olhando para -z
var portao_pos := Vector3.INF                 # INF = perto do Spawn (à frente, à direita)
var ambiente_audio := ""                      # nome em Audio.ambiente ("mar", "rio", "chuva", "" = nenhum)
var corrupcao := 0.1                          # GameState.definir_corruption_manual (0.1 = quase limpo, como a Barra)
var usa_visor := false                        # instala o Visor do Tempo (épocas via Q; precisa de discos)

# --- estado
var player: Player
var env: Environment
var sol_luz: DirectionalLight3D
var _quedas_fallback := 0
## Quantas vezes uma rede de segurança agiu neste lugar (a do Módulo 1, `RedeSeguranca`, ou a reserva abaixo). Para testes.
var quedas: int:
	get:
		var r: RedeSeguranca = RedeSeguranca.atual
		return _quedas_fallback + (r.resgates if r != null and r.nivel == self else 0)
var _saindo := false
var _objetivo := ""
var _cb_objetivo: Callable
var _hud_texto := ""
var _portao: Node3D


func _ready() -> void:
	_configurar()
	if id == "":
		push_warning("CidadeBase: a subclasse não definiu `id` em _configurar()")
	if rotulo == "" and GameState.CIDADE.has(id):
		rotulo = str(GameState.CIDADE[id]["rotulo"])
	aplicar_ambiente(hora, clima)
	_chao()
	_borda()
	_marcadores()
	_criar_portao()
	_hud_texto = "CIDADE · " + rotulo.to_upper()
	_construir()


# ============================================================================ ganchos (a subclasse sobrescreve)
## Defina aqui `id`, `rotulo` (opcional), `area`, `hora`, `clima`, `spawn_pos`, `spawn_yaw`, `ambiente_audio`, `usa_visor`...
func _configurar() -> void:
	pass


## Cenário do lugar. O chão, a borda, o Spawn e o portão de volta já existem.
func _construir() -> void:
	pass


## Tarefa do lugar (roda quando o jogador já está na cena). Chame `definir_objetivo(...)`, `pista(...)` e `concluir()`.
func _tarefa() -> void:
	pass


## Chão da AREA (visual + colisão). Sobrescreva para outro material.
func _material_chao() -> Material:
	return mat_asfalto()


# ============================================================================ contrato com o Main
func iniciar(p: Player) -> void:
	player = p
	GameState.definir_corruption_manual(corrupcao)
	if ambiente_audio != "":
		Audio.ambiente(ambiente_audio, -10.0, 2.0)
	if usa_visor:
		Visor.instalar(self)
	_cb_objetivo = Callable(self, "_texto_objetivo")
	Objetivo.extras.insert(0, _cb_objetivo)     # na frente da caça dos discos: aqui o objetivo é o do lugar
	var vigia := Vigia.new()                     # rede de segurança e HUD, sem ocupar o _process/_physics_process da subclasse
	vigia.name = "Vigia"
	vigia.dono = self
	add_child(vigia)
	_atualizar_hud()
	_tarefa()


func _exit_tree() -> void:
	if _cb_objetivo != Callable():
		Objetivo.extras.erase(_cb_objetivo)
	if is_instance_valid(GameState):
		GameState.definir_corruption_manual(-1.0)
	if is_instance_valid(Audio) and ambiente_audio != "":
		Audio.ambiente("", -8.0, 0.5)
	_restaurar_hud()


func ponto_spawn(nome: String) -> Node3D:
	return find_child(nome, true, false) as Node3D


## Mapa (M): "Cidade · <rótulo>" em vez de "Esta área não consta no mapa!".
func dados_mapa() -> Dictionary:
	return {"tipo": "fora", "msg": "Cidade · " + rotulo}


# ============================================================================ pistas, objetivo, saídas
## Ids das pistas deste lugar (GameState.CIDADE[id]["pistas"]).
func pistas_do_lugar() -> Array:
	return GameState.CIDADE[id]["pistas"] if GameState.CIDADE.has(id) else []


## Pista do Tito: conta UMA vez (flag "pista_<id>" + contador "pistas_tito", como castelinho.gd:_pista) e fala a linha
## (`fala` = textos da Guia; pode ser vazia). Só aceita ids listados em GameState.CIDADE[id]["pistas"]. Devolve true se era nova.
## Conta antes de falar: quem não der `await` também conta.
func pista(pista_id: String, fala: Array = [], quem := "sistema") -> bool:
	if not (pista_id in pistas_do_lugar()):
		push_warning("CidadeBase.pista: '%s' não está nas pistas de '%s' em GameState.CIDADE" % [pista_id, id])
		return false
	var nova: bool = not GameState.flag("pista_" + pista_id)
	if nova:
		GameState.set_flag("pista_" + pista_id, true)
		GameState.somar("pistas_tito")
	if not fala.is_empty():
		await Guia.falar(quem, fala)
	return nova


## O que o Mapa mostra em "Agora:" enquanto o jogador está aqui.
func definir_objetivo(texto: String) -> void:
	_objetivo = texto


func _texto_objetivo() -> String:
	if GameState.cidade_feita(id):
		return "Aqui está tudo certo. Volte ao Castelinho pelo portão."
	return _objetivo if _objetivo != "" else "Explore o lugar."


## Termina o lugar: grava "cidade_<id>_feito" e volta ao Castelinho, à calçada da visita atual (Spawn_volta_cidade).
func concluir() -> void:
	if _saindo:
		return
	_saindo = true
	GameState.set_flag("cidade_%s_feito" % id, true)
	concluiu.emit()
	if not _voltar():
		_saindo = false      # a troca foi recusada (outra já em andamento): este nível continua vivo


## Volta ao Castelinho sem concluir (portão "Voltar ao Castelinho").
func sair() -> void:
	if _saindo:
		return
	_saindo = true
	saiu.emit()
	if not _voltar():
		_saindo = false


## Começa a troca para o Castelinho (sem `await`: este nó é destruído na troca). false = recusada.
func _voltar() -> bool:
	if Transicao.ocupado:
		return false
	Transicao.ir_para(GameState.CENA_CASTELINHO, "Spawn_volta_cidade")
	return true


## O main chama quando o jogador morre (Visor/Figura, se o lugar os usar): sem tela de morte nem checkpoint, volta ao Spawn.
## O dono do lugar pode sobrescrever.
func ao_morrer() -> void:
	voltar_ao_spawn()


# ============================================================================ rede de segurança
## Filho do nível que chama `_vigiar()` a cada quadro de física (assim a subclasse fica livre para usar _process/_physics_process).
class Vigia extends Node:
	var dono: CidadeBase

	func _physics_process(_dt: float) -> void:
		if dono != null and is_instance_valid(dono):
			dono._vigiar()


## Limites para a `RedeSeguranca` do Módulo 1 (instalada por `main.carregar_mundo` em todo nível): a AREA do lugar.
func limites_mapa() -> AABB:
	return AABB(Vector3(area.position.x, QUEDA_Y + 5.0, area.position.y), Vector3(area.size.x, 40.0, area.size.y))


func _vigiar() -> void:
	_atualizar_hud_se_mudou()
	if player == null or not is_instance_valid(player) or not player.is_inside_tree() or _saindo:
		return
	# a rede do Módulo 1 cuida de queda, fora do mapa e parede; a reserva abaixo só vale sem ela (nível montado à mão)
	var r: RedeSeguranca = RedeSeguranca.atual
	if r != null and r.nivel == self:
		return
	var p := player.global_position
	if p.y < QUEDA_Y or not area.grow(FOLGA_AREA).has_point(Vector2(p.x, p.z)):
		voltar_ao_spawn()


## Devolve o jogador ao Spawn (queda ou fora da AREA).
func voltar_ao_spawn() -> void:
	var mk := ponto_spawn("Spawn")
	if player == null or mk == null:
		return
	_quedas_fallback += 1
	player.global_transform = mk.global_transform
	player.velocity = Vector3.ZERO
	Efeitos.pulso(0.3, 0.25)


# ============================================================================ ambiente
## (Re)aplica céu, Sol/Lua e névoa: `h` = Hora.*, `c` = Clima.*. Pode ser chamado de novo para a Barra virar noite.
func aplicar_ambiente(h: int, c: int = Clima.LIMPO) -> void:
	hora = h
	clima = c
	var d: Dictionary = CEUS[h]
	var nev: Array = NEVOAS[c]
	var esc: float = nev[2]
	if env == null:
		var we := WorldEnvironment.new()
		we.name = "Ambiente"
		env = Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_curve = 1.3
		env.fog_sky_affect = 0.0       # senão a névoa pinta o céu todo de uma cor chapada
		we.environment = env
		add_child(we)
		sol_luz = DirectionalLight3D.new()
		sol_luz.name = "Sol"
		sol_luz.shadow_enabled = false
		add_child(sol_luz)
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	mat.sky_top_color = _escurecer(d["topo"], esc)
	mat.sky_horizon_color = _escurecer(d["horizonte"], esc)
	mat.ground_horizon_color = _escurecer(d["chao_h"], esc)
	mat.ground_bottom_color = d["chao_b"]
	mat.sky_curve = 0.18
	mat.ground_curve = 0.1
	mat.sun_angle_max = 14.0
	mat.sun_curve = 0.12
	env.ambient_light_color = d["amb"]
	env.ambient_light_energy = float(d["amb_e"]) * lerpf(1.0, esc, 0.5)
	env.fog_light_color = _escurecer(d["nevoa"], esc)
	env.fog_depth_begin = nev[0]
	env.fog_depth_end = nev[1]
	sol_luz.light_color = d["sol_cor"]
	sol_luz.light_energy = float(d["sol_e"]) * esc
	var dir := (d["sol"] as Vector3).normalized()
	sol_luz.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), Vector3.ZERO)


static func _escurecer(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


# ============================================================================ chão, borda, marcadores, portão
func _chao() -> void:
	var c := area.get_center()
	# chão com colisão: a AREA mais uma faixa de 2 m (a borda invisível fica por cima dessa faixa)
	Construtor.caixa(self, Vector3(area.size.x + 4.0, 0.6, area.size.y + 4.0), Vector3(c.x, -0.3, c.y), _material_chao(), true, "Chao")
	# faixa visual além da borda, sem colisão e mais baixa: o fim da AREA nunca mostra o vazio
	Construtor.caixa(self, Vector3(area.size.x + 200.0, 0.2, area.size.y + 200.0), Vector3(c.x, -0.62, c.y),
		Ato2Pecas.mat_cor(Color(0.1, 0.11, 0.12)), false, "ChaoLonge")


## Quatro caixas de colisão altas e invisíveis ao redor da AREA (por fora dela).
func _borda() -> void:
	var a := area
	var e := ESPESSURA_BORDA
	var h := ALTURA_BORDA
	var c := a.get_center()
	var y := h * 0.5 - 1.0
	var lados := {
		"Borda_N": [Vector3(a.size.x + 2.0 * e, h, e), Vector3(c.x, y, a.position.y - e * 0.5)],
		"Borda_S": [Vector3(a.size.x + 2.0 * e, h, e), Vector3(c.x, y, a.end.y + e * 0.5)],
		"Borda_O": [Vector3(e, h, a.size.y), Vector3(a.position.x - e * 0.5, y, c.y)],
		"Borda_L": [Vector3(e, h, a.size.y), Vector3(a.end.x + e * 0.5, y, c.y)],
	}
	for nome: String in lados:
		Ato2Pecas.colisao_invisivel(self, lados[nome][0], lados[nome][1]).name = nome


func _marcadores() -> void:
	var s := Marker3D.new()
	s.name = "Spawn"
	s.position = spawn_pos
	s.rotation_degrees.y = spawn_yaw
	add_child(s)
	var cam := Marker3D.new()           # o main usa os "Cam_*" no aquecimento dos shaders
	cam.name = "Cam_spawn"
	cam.position = spawn_pos + Vector3(0, 1.55, 0)
	cam.rotation_degrees.y = spawn_yaw
	add_child(cam)


## Portão/placa "Voltar ao Castelinho" perto do Spawn: E (ou o botão Interagir no toque) chama `sair()`.
func _criar_portao() -> void:
	var pos := portao_pos
	if pos == Vector3.INF:
		pos = spawn_pos + Basis(Vector3.UP, deg_to_rad(spawn_yaw)) * Vector3(2.8, 0.0, -1.6)
	pos.y = 0.0
	_portao = Node3D.new()
	_portao.name = "Portao"
	_portao.position = pos
	var pa := Vector2(spawn_pos.x - pos.x, spawn_pos.z - pos.z)
	_portao.rotation.y = atan2(pa.x, pa.y)       # a face da placa (+z local) olha para o Spawn
	add_child(_portao)
	var madeira := Ato2Pecas.mat_cor(Color(0.32, 0.22, 0.14))
	var placa := Ato2Pecas.mat_cor(Color(0.1, 0.2, 0.42))
	Construtor.caixa(_portao, Vector3(0.22, 2.7, 0.22), Vector3(-1.65, 1.35, 0), madeira, true, "PostE")
	Construtor.caixa(_portao, Vector3(0.22, 2.7, 0.22), Vector3(1.65, 1.35, 0), madeira, true, "PostD")
	Construtor.caixa(_portao, Vector3(3.5, 0.6, 0.14), Vector3(0, 2.4, 0), placa, false, "Placa")
	var r := Construtor.rotulo(_portao, "VOLTAR AO CASTELINHO", Vector3(0, 2.4, 0.14), 64, Color(1, 0.97, 0.85))
	r.name = "Texto"
	r.double_sided = true
	var it := Interagivel.new("Voltar ao Castelinho", Vector3(3.0, 2.2, 0.8), func(_p: Node) -> void: sair())
	it.name = "PortaoVolta"
	it.position = Vector3(0, 1.1, 0)
	_portao.add_child(it)


# ============================================================================ HUD
func _hud() -> Node:
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if main and main.get("hud") and main.hud.get("lbl_sala"):
		return main.hud
	return null


func _atualizar_hud() -> void:
	var h := _hud()
	if h:
		h.lbl_sala.text = _hud_texto


## Mantém "CIDADE · <ROTULO>" no lugar do "VISITA n · SALA m" (o HUD reescreve o rótulo em glitches e a cada sala nova).
func _atualizar_hud_se_mudou() -> void:
	var h := _hud()
	if h and player != null and h.lbl_sala.text != _hud_texto:
		h.lbl_sala.text = _hud_texto
	if h and h.lbl_passaporte.visible:
		h.lbl_passaporte.visible = false      # o contador da caça dos discos (Castelinho) não vale na cidade


func _restaurar_hud() -> void:
	if not is_inside_tree():
		return
	var h := _hud()
	if h and h.has_method("texto_sala"):
		h.lbl_sala.text = h.texto_sala(GameState.sala_atual)
	if h and h.has_method("_atualizar_passaporte"):
		h._atualizar_passaporte()


# ============================================================================ ajudantes para os lugares
func interagivel(texto: String, pos: Vector3, tam: Vector3, acao: Callable) -> Interagivel:
	var it := Interagivel.new(texto, tam, acao)
	it.position = pos
	add_child(it)
	return it


func mat_asfalto() -> StandardMaterial3D:
	return Ato2Pecas.mat_tri("cidade_asfalto", Color(0.34, 0.34, 0.37), Ato2Pecas.tex_piso_pedra(), 0.22, 1.0)


func mat_calcada() -> StandardMaterial3D:
	return Ato2Pecas.mat_tri("cidade_calcada", Color(0.7, 0.68, 0.64), Ato2Pecas.tex_piso_pedra(), 0.5, 1.0)


func mat_areia(tom := 1.0) -> StandardMaterial3D:
	return Ato2Pecas.mat_tri("cidade_areia_%.2f" % tom, Color(tom, tom * 0.96, tom * 0.9), Ato2Pecas.tex_areia(), 0.22, 1.0)


## Poste de luz simples (haste, braço e lâmpada acesa sem luz de verdade). `com_luz` põe uma OmniLight (conte no máximo 6 por lugar).
func poste(pos: Vector3, altura := 5.0, com_luz := false) -> Node3D:
	var n := Node3D.new()
	n.name = "Poste"
	n.position = pos
	add_child(n)
	var ferro := Ato2Pecas.mat_cor(Color(0.22, 0.23, 0.25))
	var lamp := Ato2Pecas.mat_cor(Color(1.0, 0.86, 0.55), true, 1.0)
	Construtor.caixa(n, Vector3(0.14, altura, 0.14), Vector3(0, altura * 0.5, 0), ferro, true)
	Construtor.caixa(n, Vector3(0.9, 0.08, 0.1), Vector3(0.4, altura, 0), ferro, false)
	Construtor.caixa(n, Vector3(0.28, 0.1, 0.18), Vector3(0.8, altura - 0.08, 0), lamp, false)
	if com_luz:
		Construtor.luz(n, Vector3(0.8, altura - 0.4, 0), Color(1.0, 0.82, 0.5), 1.1, 9.0)
	return n
