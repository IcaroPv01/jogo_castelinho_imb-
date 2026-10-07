class_name Visor
extends Node
## Lógica do Visor do Tempo 2.0 (V2_ROTEIRO §4, PLANO §5.1).
##
## DISCOS (V2 §4.1): o jogador tem até cinco discos (`GameState.discos`, épocas); `GameState.disco_atual` é o
## selecionado. Teclas 1..5 escolhem o disco fixo (1 = 1950, 2 = 1967, 3 = 1975, 4 = 2019, 5 = sem data; sem
## aquele disco, nada acontece) e a rolagem do mouse passa entre os discos que o jogador tem. As ações de input
## ("disco_1".."disco_5", "disco_prox", "disco_ant") são criadas aqui, em código (`Visor.registrar_inputs()`).
##
## SEGURAR Q mostra a época do disco selecionado (moldura com o ano: "1967", "????" para o disco sem data);
## soltar volta para E2020, a não ser que a flag `visor_travado` esteja ligada (o Visor "mente"). Sem disco, o Q
## não faz nada. Compatibilidade com os níveis do MVP: sem NENHUM disco, mas com a flag `epoca_visor` definida, o
## Q usa essa época (a flag só vale enquanto não há discos). `tem_visor` (flag) ou ter algum disco libera o Visor.
## Trocar de disco com o Q apertado troca a época na hora (clarão e "slide").
##
## ATENÇÃO (V2 §4.3), da visita 3 em diante (`GameState.visita >= 3`, 5 = porão): "do outro lado, algo percebe você".
##   - Enquanto o Q está apertado, `GameState.atencao` sobe (cheio em ~6 s na visita 3, ~4 s na 4 e ~3 s no porão
##     = `TEMPO_ENCHER`); ao soltar, cai devagar (`TEMPO_ESVAZIAR`). Quem escreve é só este script.
##   - O HUD mostra um olho (ui/olho_atencao.gd) e o batimento "atencao" acelera (um som por batida).
##   - A Figura Branca aparece DENTRO do slide (só com Q apertado), cada vez mais perto da lente
##     (`FiguraSlide`, um visual próprio, sem IA: não entra no grupo "figura_branca" e não mata ninguém).
##   - No máximo: susto (Efeitos.pulso forte + som "susto"), o Visor é arrancado da mão e fica BLOQUEADO por
##     `BLOQUEIO_S` = 10 s (`Visor.bloqueado()`, `Visor.bloqueio_restante()`); a atenção volta a zero.
##   - SINAL DE INSTÂNCIA `figura_atravessou(visita)`: emitido no susto, nas visitas 4 e 5 (porão), para o nível
##     soltar a Figura Branca "de verdade". Uso no nível do porão:
##         Visor.instalar(self).figura_atravessou.connect(func(_v): _soltar_figura())
##     (na visita 3 o susto não solta nada: só pulso, som e bloqueio). `atencao_cheia(visita)` sai em todas.
##
## Como usar (cada nível que quiser o Visor), em `_ready()` ou `iniciar(player)`:
##     Visor.instalar(self)
## É idempotente: se já existe um Visor na árvore (ou se o integrador o registrar como autoload), reaproveita o
## existente. Ao sair do nível (ou ao soltar), a época volta para E2020 (correção do bug B06 em docs/BUGS.md) e a
## atenção zera. O bloqueio de 10 s é estático: atravessa a troca de nível.

signal ativado(epoca: int)
signal desativado(epoca: int)
signal disco_trocado(epoca: int)
signal atencao_cheia(visita: int)
signal figura_atravessou(visita: int)
signal bloqueio_mudou(bloqueado: bool)

const GRUPO := "visor_tempo"
const INTERVALO_MIN := 0.12   # s entre trocas (evita metralhar o clique)

## Ordem fixa dos discos: a tecla n escolhe ORDEM_DISCOS[n - 1].
## (inteiros do enum GameState.Epoca: E1950 = 0, E1975 = 1, E2019 = 2, E2020 = 3, E1967 = 4, ESEMDATA = 5)
const ORDEM_DISCOS: Array[int] = [0, 4, 1, 2, 5]
## Segundos com o Q apertado até a atenção encher, por visita (5 = porão).
const TEMPO_ENCHER := {3: 6.0, 4: 4.0, 5: 3.0}
const TEMPO_ESVAZIAR := 9.0   # s para esvaziar do máximo a zero depois de soltar o Q
const BLOQUEIO_S := 10.0
const ATENCAO_MIN_FIGURA := 0.12   # abaixo disso a Figura ainda não aparece no slide

static var _bloqueio := 0.0   # s restantes (estático: atravessa a troca de nível)

var ativo := false
var figura_visivel := false   # a Figura está sendo mostrada no slide agora (para testes)
var _ultima_troca := -10.0
var _epoca_mostrada := -1
var _figura: Node3D
var _lado := 1.0
var _bat_t := 0.0
var _aviso_t := 0.0


# ---------------------------------------------------------------- API estática
## Garante um Visor dentro de `pai` (ou já em qualquer lugar da árvore) e o devolve.
static func instalar(pai: Node) -> Visor:
	for n in pai.get_tree().get_nodes_in_group(GRUPO):
		return n as Visor
	var v := Visor.new()
	v.name = "Visor"
	pai.add_child(v)
	return v


## Cria as ações de input do Visor (sem mexer no project.godot). Idempotente.
static func registrar_inputs() -> void:
	for i in 5:
		var nome := "disco_%d" % (i + 1)
		if not InputMap.has_action(nome):
			InputMap.add_action(nome)
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_1 + i
			InputMap.action_add_event(nome, ev)
			var kp := InputEventKey.new()
			kp.physical_keycode = KEY_KP_1 + i
			InputMap.action_add_event(nome, kp)
	for par in [["disco_prox", MOUSE_BUTTON_WHEEL_UP], ["disco_ant", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(par[0]):
			InputMap.add_action(par[0])
			var m := InputEventMouseButton.new()
			m.button_index = par[1]
			InputMap.action_add_event(par[0], m)


static func bloqueado() -> bool:
	return _bloqueio > 0.0


static func bloqueio_restante() -> float:
	return _bloqueio


## Zera o bloqueio (nova partida, testes).
static func resetar_estado() -> void:
	_bloqueio = 0.0


static func atencao_ligada() -> bool:
	return TEMPO_ENCHER.has(GameState.visita)


# ---------------------------------------------------------------- ciclo de vida
func _ready() -> void:
	add_to_group(GRUPO)
	registrar_inputs()
	if GameState.sala_atual <= 0:   # nova partida (ainda sem sala): nada de bloqueio herdado
		_bloqueio = 0.0


func _input(e: InputEvent) -> void:
	if GameState.flag("ui_aberta") or not _tem_visor():
		return
	if e is InputEventKey or e is InputEventMouseButton:
		for i in 5:
			if e.is_action_pressed("disco_%d" % (i + 1), false):
				selecionar_slot(i)
				return
		if e.is_action_pressed("disco_prox"):
			ciclar(1)
		elif e.is_action_pressed("disco_ant"):
			ciclar(-1)


func _process(dt: float) -> void:
	var quer := _quer_ligar()
	var agora := Time.get_ticks_msec() / 1000.0
	if quer != ativo and agora - _ultima_troca >= INTERVALO_MIN:
		_ultima_troca = agora
		if quer:
			_ligar()
		else:
			_desligar()
	elif ativo:
		_acompanhar_disco()
	_aviso_t = maxf(0.0, _aviso_t - dt)
	if _bloqueio > 0.0:
		var antes := _bloqueio
		_bloqueio = maxf(0.0, _bloqueio - dt)
		if antes > 0.0 and _bloqueio <= 0.0:
			Audio.sfx("clique", -4.0, 1.4)   # o Visor "volta para a mão"
			bloqueio_mudou.emit(false)
	_atualizar_atencao(dt)
	_atualizar_batimento(dt)
	_atualizar_figura(dt)


func _exit_tree() -> void:
	# O nível acabou com o Visor ligado (ex.: transição): desliga a moldura e devolve a época de hoje. Sem isso o
	# nível seguinte nascia em 1950 e o novo Visor, achando que já estava desligado, nunca a corrigia (bug B06).
	if ativo:
		ativo = false
		if is_instance_valid(Efeitos):
			Efeitos.visor(false)
		if is_instance_valid(GameState) and not GameState.flag("visor_travado"):
			GameState.trocar_epoca(GameState.Epoca.E2020)
	if is_instance_valid(GameState):
		GameState.definir_atencao(0.0)
	if is_instance_valid(_figura):
		_figura.queue_free()


# ---------------------------------------------------------------- discos
func _tem_visor() -> bool:
	return bool(GameState.flag("tem_visor")) or not GameState.discos.is_empty()


## Época que o Q mostra agora (-1 = nenhuma: o Q não faz nada).
func epoca_alvo() -> int:
	var d := GameState.disco_atual
	if d >= 0 and d in GameState.discos:
		return d
	if GameState.discos.is_empty() and GameState.flags.has("epoca_visor"):
		return int(GameState.flag("epoca_visor"))   # níveis do MVP, sem discos
	return -1


## Escolhe o disco da tecla `slot` (0..4). Devolve false se o jogador não tem esse disco.
func selecionar_slot(slot: int) -> bool:
	if slot < 0 or slot >= ORDEM_DISCOS.size():
		return false
	var ep: int = ORDEM_DISCOS[slot]
	if ep not in GameState.discos:
		Audio.sfx("erro", -14.0, 1.3)
		return false
	_escolher(ep)
	return true


## Passa para o próximo (+1) ou anterior (-1) disco que o jogador tem, em volta.
func ciclar(sentido: int) -> void:
	var meus: Array[int] = []
	for ep in ORDEM_DISCOS:
		if ep in GameState.discos:
			meus.append(ep)
	if meus.is_empty():
		return
	var i := meus.find(GameState.disco_atual)
	i = 0 if i < 0 else posmod(i + sentido, meus.size())
	_escolher(meus[i])


func _escolher(ep: int) -> void:
	if ep == GameState.disco_atual:
		return
	GameState.selecionar_disco(ep)
	Audio.sfx("slide", -8.0, randf_range(1.15, 1.3))
	disco_trocado.emit(ep)


## Q apertado e o disco mudou: troca a época na hora (um "slide" novo).
func _acompanhar_disco() -> void:
	var alvo := epoca_alvo()
	if alvo >= 0 and alvo != _epoca_mostrada:
		_epoca_mostrada = alvo
		GameState.trocar_epoca(alvo)
		Efeitos.flash(0.18, Color(1.0, 0.97, 0.9), 0.6)
		Efeitos.legenda_visor("")
		Audio.sfx("slide", -3.0)
		ativado.emit(alvo)


# ---------------------------------------------------------------- Q
func _quer_ligar() -> bool:
	if not _tem_visor() or GameState.flag("ui_aberta"):
		return false
	var q := Input.is_action_pressed("visor")
	if q and _bloqueio > 0.0:
		if _aviso_t <= 0.0:   # "o Visor não responde": um tique surdo, no máximo uma vez por segundo
			_aviso_t = 1.0
			Audio.sfx("erro", -12.0, 0.8)
		return false
	return q and epoca_alvo() >= 0


func _ligar() -> void:
	ativo = true
	_lado = -1.0 if randf() < 0.5 else 1.0
	var alvo := epoca_alvo()
	_epoca_mostrada = alvo
	GameState.trocar_epoca(alvo)
	Efeitos.visor(true)
	ativado.emit(alvo)


func _desligar() -> void:
	ativo = false
	_epoca_mostrada = -1
	if not GameState.flag("visor_travado"):
		GameState.trocar_epoca(GameState.Epoca.E2020)
	Efeitos.visor(false)
	desativado.emit(int(GameState.epoca))


# ---------------------------------------------------------------- atenção
func _atualizar_atencao(dt: float) -> void:
	var enche: float = TEMPO_ENCHER.get(GameState.visita, 0.0)
	if enche <= 0.0:   # visitas 1 e 2: o Visor é só um brinquedo
		if GameState.atencao > 0.0:
			GameState.definir_atencao(0.0)
		return
	var a := GameState.atencao
	if ativo:
		a += dt / enche
	else:
		a -= dt / TEMPO_ESVAZIAR
	GameState.definir_atencao(a)
	if ativo and GameState.atencao >= 1.0:
		_estourar()


## Atenção no máximo: a Figura "atravessa" o Visor. Pulso forte, susto, o Visor sai da mão por BLOQUEIO_S.
func _estourar() -> void:
	var v := GameState.visita
	GameState.definir_atencao(0.0)
	_bloqueio = BLOQUEIO_S
	_ultima_troca = Time.get_ticks_msec() / 1000.0
	_desligar()
	Efeitos.pulso(1.5, 0.9)
	Efeitos.flash(0.6, Color(1, 1, 1), 1.0)
	Audio.sfx("susto")
	GameState.somar("sustos")
	atencao_cheia.emit(v)
	bloqueio_mudou.emit(true)
	if v >= 4:
		figura_atravessou.emit(v)


func _atualizar_batimento(dt: float) -> void:
	var a := GameState.atencao
	if a < 0.06:
		_bat_t = 0.0
		return
	_bat_t -= dt
	if _bat_t <= 0.0:
		_bat_t = lerpf(1.15, 0.30, a)
		Audio.sfx("atencao", lerpf(-16.0, -1.0, a), lerpf(0.92, 1.12, a))


# ---------------------------------------------------------------- a Figura dentro do slide
func _atualizar_figura(dt: float) -> void:
	var a := GameState.atencao
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var mostrar := ativo and a > ATENCAO_MIN_FIGURA and cam != null
	figura_visivel = mostrar
	if not mostrar:
		if is_instance_valid(_figura) and _figura.visible:
			_figura.visible = false
		return
	if not is_instance_valid(_figura):
		_figura = FiguraSlide.new()
		add_child(_figura)
	var t := inverse_lerp(ATENCAO_MIN_FIGURA, 1.0, a)
	var frente := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z)
	frente = frente.normalized() if frente.length() > 0.001 else Vector3.FORWARD
	# revisão V2: ela para a ~2,6 m e se DEBRUÇA sobre a lente (antes chegava a 1,15 m em pé e a cabeça saía do quadro:
	# no pico do susto o slide mostrava só duas colunas rosadas)
	var dist := lerpf(15.0, 2.6, pow(t, 1.4))
	var dir := frente.rotated(Vector3.UP, deg_to_rad(lerpf(32.0, 0.0, t) * _lado))
	var pos := cam.global_position + dir * dist
	pos.y = cam.global_position.y - 1.55   # os pés no chão (altura dos olhos do jogador)
	if t > 0.7:   # tremida de quem está quase em cima da lente
		pos += Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * (t - 0.7) * 0.2
	_figura.global_position = pos
	_figura.look_at(Vector3(cam.global_position.x, pos.y, cam.global_position.z), Vector3.UP)
	_figura.rotate_object_local(Vector3.RIGHT, -deg_to_rad(48.0) * smoothstep(0.5, 1.0, t))
	_figura.scale = Vector3(1.0, lerpf(1.0, 1.18, t), 1.0)
	_figura.visible = not (t > 0.5 and randf() < t * 0.12)   # pisca (glitch) quando está perto
	(_figura as FiguraSlide).intensidade = t


## Visual da Figura Branca só para o slide: silhueta alta, branca, sem rosto, com véu. Sem física, sem IA, sem grupo.
## Desenhada por cima de tudo (sem teste de profundidade): é uma imagem no slide, não um corpo no mundo.
class FiguraSlide extends Node3D:
	var intensidade := 0.0
	var _t := randf() * 6.0
	var _veu: Node3D
	var _braco_e: Node3D
	var _braco_d: Node3D

	func _ready() -> void:
		var corpo := _material(0.93)
		var tecido := _material(0.5)
		var m := Node3D.new()
		m.scale = Vector3(1.0, 1.12, 1.0)
		add_child(m)
		var saia := CylinderMesh.new()
		saia.top_radius = 0.16
		saia.bottom_radius = 0.44
		saia.height = 1.4
		saia.radial_segments = 12
		saia.rings = 1
		_peca(m, saia, Vector3(0, 0.7, 0), corpo)
		var tronco := CapsuleMesh.new()
		tronco.radius = 0.15
		tronco.height = 0.78
		tronco.radial_segments = 10
		tronco.rings = 3
		_peca(m, tronco, Vector3(0, 1.68, 0), corpo)
		var cab := SphereMesh.new()
		cab.radius = 0.11
		cab.height = 0.22
		cab.radial_segments = 10
		cab.rings = 6
		_peca(m, cab, Vector3(0.03, 2.16, 0), corpo, Vector3(0, 0, deg_to_rad(-12)), Vector3(0.85, 1.25, 0.9))
		var braco := CapsuleMesh.new()
		braco.radius = 0.04
		braco.height = 1.25
		braco.radial_segments = 6
		braco.rings = 2
		_braco_e = Node3D.new()
		_braco_e.position = Vector3(-0.2, 1.9, 0)
		m.add_child(_braco_e)
		_peca(_braco_e, braco, Vector3(-0.06, -0.55, 0), corpo, Vector3(0, 0, deg_to_rad(6)))
		_braco_d = Node3D.new()
		_braco_d.position = Vector3(0.2, 1.9, 0)
		m.add_child(_braco_d)
		_peca(_braco_d, braco, Vector3(0.06, -0.55, 0), corpo, Vector3(0, 0, deg_to_rad(-6)))
		_veu = Node3D.new()
		m.add_child(_veu)
		var veu := CylinderMesh.new()
		veu.top_radius = 0.18
		veu.bottom_radius = 0.66
		veu.height = 2.3
		veu.radial_segments = 14
		veu.rings = 1
		veu.cap_top = false
		veu.cap_bottom = false
		_peca(_veu, veu, Vector3(0, 1.15, 0.02), tecido)

	func _process(dt: float) -> void:
		_t += dt
		if _veu:
			_veu.rotation.z = sin(_t * 1.3) * 0.05
			_veu.scale = Vector3(1.0 + 0.05 * sin(_t * 2.1), 1.0, 1.0 + 0.05 * cos(_t * 1.7))
		if _braco_e:
			# os braços sobem devagar conforme ela chega perto (abre os braços para o visor)
			_braco_e.rotation.z = lerpf(0.0, -1.2, intensidade) + sin(_t * 1.1) * 0.05
			_braco_d.rotation.z = lerpf(0.0, 1.2, intensidade) + sin(_t * 1.1 + 1.7) * 0.05

	static func _material(alfa: float) -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.96, 0.97, 1.0, alfa)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.render_priority = 20
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return mat

	func _peca(pai: Node3D, malha: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, escala := Vector3.ONE) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = malha
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		mi.scale = escala
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)
