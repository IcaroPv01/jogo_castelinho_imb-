class_name SustosCaminho
extends Node
## Sustos garantidos NO CAMINHO OBRIGATÓRIO do Castelinho (os outros ficavam fora da rota ou dependiam de olhar certo).
## Cada um acontece UMA vez por partida (flag "susto_<chave>", a mesma do Susto) e só dispara quando o jogador está livre:
## sem fala do Guia, sem UI aberta, sem Visor ligado e sem Figura perseguindo (adia, como o `_susto_castelo`).
## Visita 1: nenhum. Visita 2: só as piadas de papelão (nada aqui).
##
##   visita 3, corredor da Secretaria (base 10, sala 54): o fantasma do Tito (pálido, molhado, translúcido) cruza correndo
##             o fundo do corredor quando o jogador olha para lá (chave "v3_tito_corredor");
##   visita 3, Sala Medieval (base 21/22): a armadura aparece quando o jogador PASSOU por ela e olha de volta, mesmo que
##             nunca tenha feito o "olhar - desviar - olhar" do `_atualizar_armadura` (chave "v3_armadura");
##   visita 4, hall (base 7, sala 71): um relâmpago revela a Figura parada fora da janela leste, olhando para dentro
##             (chave "v4_relampago_janela").
##
## Gancho: `SustosCaminho.instalar(self)` no `iniciar()` do castelinho.gd (o nó escuta GameState.sala_mudou).

const CHAVES: Array[String] = ["v3_tito_corredor", "v3_armadura", "v4_relampago_janela"]
const ESPERA_MAX := 40.0             # s esperando o jogador ficar livre e olhar; depois desiste até a próxima entrada na sala
const BASE_CORREDOR := 10
const BASE_HALL := 7
const FIM_CORREDOR := Vector3(-8.3, 0.0, -21.9)      # fundo (leste) do corredor da Secretaria
const JANELA_HALL := Vector3(-5.0, 1.55, -13.0)      # janela gradeada do hall (fachada leste)
const FORA_JANELA := Vector3(-3.3, 0.0, -13.0)       # onde a Figura fica, na calçada da Av. Nilza
const POS_ARMADURA := Vector3(-9.2, 1.0, -27.6)

var nivel: Node
var visita := 0
var _esperando := {}                 # chave -> true enquanto há uma espera em andamento
var _arm_afastou := false


static func instalar(n: Node) -> SustosCaminho:
	var s := SustosCaminho.new()
	s.name = "SustosCaminho"
	s.nivel = n
	n.add_child(s)
	return s


func _ready() -> void:
	visita = int(nivel.get("visita"))
	GameState.sala_mudou.connect(_ao_mudar_sala)


func _exit_tree() -> void:
	if GameState.sala_mudou.is_connected(_ao_mudar_sala):
		GameState.sala_mudou.disconnect(_ao_mudar_sala)


static func ja_aconteceu(chave: String) -> bool:
	return Susto.ja_aconteceu(chave)


func _ao_mudar_sala(n: int) -> void:
	if nivel == null or not is_instance_valid(nivel):
		return
	if visita == 3 and n == int(nivel.call("_global", BASE_CORREDOR)):
		_tentar("v3_tito_corredor", n, Vector3(FIM_CORREDOR.x, 1.0, FIM_CORREDOR.z), 4.0, 16.0)
	elif visita == 4 and n == int(nivel.call("_global", BASE_HALL)):
		_tentar("v4_relampago_janela", n, JANELA_HALL, 2.5, 14.0)


## Espera o jogador ficar livre e olhando para `alvo` (de `dmin` a `dmax` m) e então dispara. Uma espera por chave.
func _tentar(chave: String, sala: int, alvo: Vector3, dmin: float, dmax: float) -> void:
	if ja_aconteceu(chave) or _esperando.get(chave, false):
		return
	_esperando[chave] = true
	var t := 0.0
	while t < ESPERA_MAX:
		await get_tree().create_timer(0.25, false).timeout
		t += 0.25
		if not is_inside_tree() or not _jogador_ok() or ja_aconteceu(chave) or GameState.sala_atual != sala or _saindo():
			break
		if not livre() or not _olhando(alvo, dmin, dmax):
			continue
		forcar(chave)
		break
	_esperando.erase(chave)


# ================================================================== condições
func _jogador() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


func _jogador_ok() -> bool:
	var p := _jogador()
	return p != null and is_instance_valid(p)


func _saindo() -> bool:
	for p in ["_saindo_barra", "_saindo_visita", "_saindo_ato2", "_saindo_porao"]:
		if nivel.get(p) == true:
			return true
	return false


## Sem fala do Guia, UI aberta, Visor ligado nem Figura perseguindo.
func livre() -> bool:
	if Guia.ocupado() or GameState.flag("ui_aberta"):
		return false
	var visor = nivel.get("_visor")
	if visor != null and is_instance_valid(visor) and visor.get("ativo") == true:
		return false
	for f in get_tree().get_nodes_in_group("figura_branca"):
		if f is Node3D and f.visible and f.get("ativa") == true:
			return false
	var p := _jogador()
	return p != null and p.pode_mover


func _olhando(alvo: Vector3, dmin: float, dmax: float, cos_min := 0.8) -> bool:
	var p := _jogador()
	if p == null:
		return false
	var d := alvo - p.camera.global_position
	var dist := d.length()
	return dist >= dmin and dist <= dmax and p.direcao_olhar().dot(d / maxf(dist, 0.001)) > cos_min


# ================================================================== os sustos
## Dispara o susto `chave` agora (sem esperar condição nenhuma, mas respeitando "uma vez"). Devolve true se disparou.
func forcar(chave: String) -> bool:
	if ja_aconteceu(chave):
		return false
	match chave:
		"v3_tito_corredor":
			return _tito_corredor()
		"v4_relampago_janela":
			return _relampago_janela()
		"v3_armadura":
			return _armadura()
	return false


func _marcar(chave: String) -> void:
	GameState.set_flag(Susto.FLAG + chave, true)


## Visita 3: o Tito, pálido e molhado, atravessa correndo o fundo do corredor (do sul para o norte) e some.
func _tito_corredor() -> bool:
	var p := _jogador()
	if p == null:
		return false
	_marcar("v3_tito_corredor")
	var fantasma := criar_fantasma()
	nivel.add_child(fantasma)
	var de := Vector3(FIM_CORREDOR.x, 0.0, FIM_CORREDOR.z + 1.25)
	var ate := Vector3(FIM_CORREDOR.x, 0.0, FIM_CORREDOR.z - 1.3)
	fantasma.position = de
	fantasma.rotation.y = atan2(ate.x - de.x, ate.z - de.z)
	Epocas.marcar(fantasma, [GameState.Epoca.E2020])
	Audio.sfx("splash", -8.0, 1.4)
	Audio.sfx("crianca_ei", -9.0)
	Efeitos.pulso(0.35, 0.3)
	var mat := fantasma.get_meta("material") as StandardMaterial3D
	var tw := nivel.create_tween()
	tw.tween_property(fantasma, "position:z", ate.z, 0.85)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.55)
	tw.tween_callback(fantasma.queue_free)
	return true


## O Tito do jogo (criar_tito) coberto por um material pálido, azulado e translúcido, sem luz (visível no escuro).
static func criar_fantasma() -> Node3D:
	var f := TitoCastelinho.criar_tito()
	f.name = "FantasmaTito"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.92, 0.96, 0.68)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cobrir(f, mat)
	f.set_meta("material", mat)
	return f


static func _cobrir(no: Node, mat: Material) -> void:
	if no is MeshInstance3D:
		(no as MeshInstance3D).material_override = mat
		(no as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in no.get_children():
		_cobrir(c, mat)


## Visita 4: relâmpago e, no mesmo instante, a Figura de pé do lado de fora da janela do hall, olhando para dentro.
func _relampago_janela() -> bool:
	if not Susto.disparar(nivel, "v4_relampago_janela", {"pos": FORA_JANELA, "duracao": 0.65, "sfx": "", "pulso": 0.25,
			"tranco": 0.0, "flash": false}):
		return false
	if nivel.has_method("_disparar_relampago"):
		nivel.call("_disparar_relampago")
	return true


## Visita 3: a armadura aparece quando o jogador já passou por ela (sala 22 em diante), olhou para outro lado e olha de volta.
func _armadura() -> bool:
	var arm := nivel.get("_armadura") as Node3D
	if arm == null or not is_instance_valid(arm) or int(nivel.get("_armadura_estado")) >= 3:
		return false
	_marcar("v3_armadura")
	nivel.set("_armadura_estado", 3)
	arm.visible = true
	Audio.sfx_3d("susto", arm.global_position)
	Efeitos.pulso(0.5, 0.3)
	GameState.somar("sustos")
	return true


func _process(_dt: float) -> void:
	if visita != 3 or nivel == null or not is_instance_valid(nivel) or ja_aconteceu("v3_armadura"):
		return
	if int(nivel.get("_armadura_estado")) >= 3 or not GameState.flag("v3_ato2_feito"):
		return
	if GameState.sala_atual < int(nivel.call("_global", 22)):
		return                       # ainda não passou pela Sala Medieval (o gatilho original cuida da 21)
	var p := _jogador()
	if p == null:
		return
	var d := POS_ARMADURA - p.camera.global_position
	if d.length() > 14.0:
		return
	var c := p.direcao_olhar().dot(d.normalized())
	if c < 0.15:
		_arm_afastou = true
	elif c > 0.62 and _arm_afastou and livre():
		_armadura()
