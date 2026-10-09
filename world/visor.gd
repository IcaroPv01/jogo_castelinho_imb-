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
##   - Visitas 1 e 2: o Visor é um brinquedo, sem risco nenhum (a atenção fica em zero, nenhuma Figura).
##   - Enquanto o Q está apertado, `GameState.atencao` sobe (cheio em 10 s na visita 3, 7 s na 4 e 5 s no porão
##     = `TEMPO_ENCHER`); ao soltar, cai rápido (`TEMPO_ESVAZIAR` = 4 s do máximo a zero). Quem escreve é só este script
##     (e nada escreve com `Debug.atencao_congelada`).
##   - Depois de um estouro e do fim do bloqueio, `GRACA_S` = 6 s de graça: a atenção não sobe.
##   - O HUD mostra um olho (ui/olho_atencao.gd) e o batimento "atencao" acelera (um som por batida).
##   - A Figura Branca aparece DENTRO do slide (só com Q apertado e atenção > `ATENCAO_MIN_FIGURA` = 0,35) como um
##     corpo no MUNDO, não uma imagem colada na câmera: é uma FiguraBranca `somente_visual` (sem IA, sem colisão, sem
##     matar) com teste de profundidade normal, então as paredes a escondem. Ela fica sobre o RASTRO do jogador
##     (world/rastro.gd), ~14 m atrás ao longo do caminho que ele andou, e anda por esse caminho em direção a ele
##     conforme a atenção sobe (para a 2,5 m na visita 3 e a 5 m nas 4 e 5, onde ela vai atravessar), recua quando cai.
##     Como o rastro é por onde o jogador andou, ela nunca é posta atrás de uma parede; sem ~5 m de rastro, não aparece.
##   - No máximo: susto (Efeitos.pulso forte + som "susto"), o Visor é arrancado da mão e fica BLOQUEADO por
##     `BLOQUEIO_S` = 10 s (`Visor.bloqueado()`, `Visor.bloqueio_restante()`); a atenção volta a zero.
##   - SINAL DE INSTÂNCIA `figura_atravessou(visita)`: emitido no susto, nas visitas 4 e 5 (porão), para o nível
##     soltar a Figura Branca "de verdade" EXATAMENTE onde a do slide estava (`pos_figura_slide()`: um ponto do rastro,
##     nunca atrás do jogador por mágica). Uso no nível:
##         Visor.instalar(self).figura_atravessou.connect(func(_v): _soltar_figura())
##     (na visita 3 o susto não solta nada: só pulso, som e bloqueio; é só susto). `atencao_cheia(visita)` sai em todas.
##   - Debug (ui/debug.gd): `figura_off` = a Figura do slide nunca aparece; `atencao_congelada` = o Visor não mexe na atenção.
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
const TEMPO_ENCHER := {3: 10.0, 4: 7.0, 5: 5.0}
const TEMPO_ESVAZIAR := 4.0   # s para esvaziar do máximo a zero depois de soltar o Q
const BLOQUEIO_S := 10.0
const GRACA_S := 6.0          # s depois do bloqueio em que a atenção não sobe
const ATENCAO_MIN_FIGURA := 0.35   # abaixo disso a Figura ainda não aparece no slide
const DIST_FIGURA_LONGE := 14.0    # m de rastro atrás do jogador quando ela surge
const DIST_FIGURA_PERTO_V3 := 2.5  # m onde ela para na visita 3 (só susto)
const DIST_FIGURA_PERTO := 5.0     # m onde ela para nas visitas 4 e 5 (vai atravessar e perseguir: dá folga para fugir)
const RASTRO_MIN := 5.0            # m de rastro mínimos para a Figura aparecer
const VEL_FIGURA_SLIDE := 2.5      # m/s: o quanto ela anda pelo rastro no slide

static var _bloqueio := 0.0   # s restantes (estático: atravessa a troca de nível)
static var _graca := 0.0      # s de graça que restam (a atenção não sobe)

var ativo := false
var figura_visivel := false   # a Figura está sendo mostrada no slide agora (para testes)
var _ultima_troca := -10.0
var _epoca_mostrada := -1
var _epoca_antes := 0   # época de antes de ligar (com `visor_travado`, soltar o Q volta para ela)
var _aviso_disco_t := 0.0   # s até poder avisar de novo "sem esse disco"
var _figura: FiguraBranca     # a Figura do slide (somente visual, no mundo)
var _rastro: Rastro
var _s_fig := 0.0             # onde ela está no rastro (coordenada de arco)
var _fig_no_mundo := false
var _pos_fig := Vector3.ZERO
var _tem_pos_fig := false
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
	_graca = 0.0


static func atencao_ligada() -> bool:
	return TEMPO_ENCHER.has(GameState.visita)


# ---------------------------------------------------------------- ciclo de vida
func _ready() -> void:
	add_to_group(GRUPO)
	registrar_inputs()
	GameState.flag_mudou.connect(_on_flag)
	if GameState.sala_atual <= 0:   # nova partida (ainda sem sala): nada de bloqueio herdado
		_bloqueio = 0.0
		_graca = 0.0
	_rastro = Rastro.garantir(self)


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
	_aviso_disco_t = maxf(0.0, _aviso_disco_t - dt)
	if _bloqueio > 0.0:
		var antes := _bloqueio
		_bloqueio = maxf(0.0, _bloqueio - dt)
		if antes > 0.0 and _bloqueio <= 0.0:
			Audio.sfx("clique", -4.0, 1.4)   # o Visor "volta para a mão"
			_graca = GRACA_S
			bloqueio_mudou.emit(false)
	elif _graca > 0.0:
		_graca = maxf(0.0, _graca - dt)
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
		if is_instance_valid(GameState):
			GameState.trocar_epoca(_epoca_antes if GameState.flag("visor_travado") else GameState.Epoca.E2020)
	if is_instance_valid(GameState) and not Debug.atencao_congelada:
		GameState.definir_atencao(0.0)
	if is_instance_valid(_figura):
		_figura.queue_free()


## O nível travou o Visor com o Q apertado (ex.: entrou no corredor de 1975 olhando pelo Visor): a época de
## "antes" passa a ser a que o nível impôs. Adiado para o fim do quadro porque uns níveis ligam a flag antes de
## trocar a época e outros depois.
func _on_flag(nome: String, valor: Variant) -> void:
	if nome == "visor_travado" and bool(valor) and ativo:
		_capturar_travada.call_deferred()


func _capturar_travada() -> void:
	_epoca_antes = int(GameState.epoca)


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
		if _aviso_disco_t <= 0.0:   # legenda curta, sem dizer o ano (sem spoiler), no máximo a cada 3 s
			_aviso_disco_t = 3.0
			Efeitos.aviso("Você ainda não tem esse disco.")
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
	var alvo := epoca_alvo()
	_epoca_mostrada = alvo
	_epoca_antes = int(GameState.epoca)
	GameState.trocar_epoca(alvo)
	Efeitos.visor(true)
	ativado.emit(alvo)


func _desligar() -> void:
	ativo = false
	_epoca_mostrada = -1
	# travado (o Visor "mente"): volta para a época de antes, não para 2020 (senão o corredor some e o jogador fica preso)
	GameState.trocar_epoca(_epoca_antes if GameState.flag("visor_travado") else GameState.Epoca.E2020)
	Efeitos.visor(false)
	desativado.emit(int(GameState.epoca))


# ---------------------------------------------------------------- atenção
func _atualizar_atencao(dt: float) -> void:
	if Debug.atencao_congelada:   # debug: o Visor não mexe na atenção
		return
	var enche: float = TEMPO_ENCHER.get(GameState.visita, 0.0)
	if enche <= 0.0:   # visitas 1 e 2: o Visor é só um brinquedo
		if GameState.atencao > 0.0:
			GameState.definir_atencao(0.0)
		return
	var a := GameState.atencao
	if ativo and _graca <= 0.0:
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
## Onde a Figura do slide está agora (mundo), ou, se ela não estava aparecendo, um ponto do rastro a ~7 m atrás do
## jogador. `Vector3.INF` = não há onde pôr (rastro curto demais): o nível usa o próprio critério.
func pos_figura_slide() -> Vector3:
	if _tem_pos_fig:
		return _pos_fig
	if _rastro != null and is_instance_valid(_rastro) and _rastro.comprimento() >= RASTRO_MIN:
		return _rastro.ponto_atras(minf(7.0, _rastro.comprimento()))
	return Vector3.INF


func _dist_perto() -> float:
	return DIST_FIGURA_PERTO_V3 if GameState.visita == 3 else DIST_FIGURA_PERTO


func _atualizar_figura(dt: float) -> void:
	var a := GameState.atencao
	if _rastro == null or not is_instance_valid(_rastro):
		_rastro = Rastro.garantir(self)
	var mostrar := ativo and a > ATENCAO_MIN_FIGURA and atencao_ligada() and not Debug.figura_off \
		and _rastro.comprimento() >= RASTRO_MIN
	figura_visivel = mostrar
	if not mostrar:
		_fig_no_mundo = false
		if is_instance_valid(_figura) and _figura.visible:
			_figura.visible = false
			_figura.animar = false
		_tem_pos_fig = false   # (o estouro lê a posição antes deste ponto: ela vale só no quadro do susto)
		return
	if not is_instance_valid(_figura):
		_figura = FiguraBranca.new()
		_figura.name = "FiguraSlide"
		_figura.somente_visual = true
		_figura.ativa = false
		_figura.som_ativo = false
		add_child(_figura)
	var t := inverse_lerp(ATENCAO_MIN_FIGURA, 1.0, a)
	var disp := _rastro.comprimento()
	var gap := minf(lerpf(DIST_FIGURA_LONGE, _dist_perto(), t), disp)
	var s_alvo := _rastro.s_atual() - gap
	if not _fig_no_mundo:
		_fig_no_mundo = true
		_s_fig = s_alvo
	var antes := _s_fig
	_s_fig = move_toward(_s_fig, s_alvo, VEL_FIGURA_SLIDE * dt)
	_s_fig = maxf(_s_fig, _rastro.s_inicio())
	var pos := _rastro.ponto_em(_s_fig)
	_pos_fig = pos
	_tem_pos_fig = true
	_figura.global_position = pos
	var para := _rastro.pos_atual - pos
	if Vector2(para.x, para.z).length() > 0.05:
		_figura.rotation.y = atan2(-para.x, -para.z)
	_figura.animar = absf(_s_fig - antes) > 0.0001
	_figura.visible = not (t > 0.5 and randf() < t * 0.1)   # pisca (glitch) quando está perto
