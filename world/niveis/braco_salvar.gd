class_name BracoSalvar
extends Node
## FINAL SECRETO "SALVAR O TITO" (Módulo 13, plano do playtest do Bernardo, fase C). Mora no Braço Morto
## (world/niveis/braco_morto.gd), que cria este nó em `_ready` e o chama em `iniciar`.
##
## COMO SE DESTRAVA: `pistas_tito >= PISTAS_SALVAR` (20 de 26, contando as 6 pistas da cidade do Módulo 14 e as 5 dos minigames do Módulo 16; o "Encontrado" pede 8). Nesse instante uma coluna de luz
## se acende no meio do lago e o pedalinho amarelo do atracadouro (o do balde vermelho) deixa de estar preso.
##
## O QUE O JOGADOR FAZ:
##   1. Embarca no pedalinho amarelo (E na margem) e pedala até a luz (andar + mouse; o barco é o jogador, sem física
##      de gravidade; os pontilhões e os outros cisnes batem). Voltar ao atracadouro e apertar E desce.
##   2. Perto da luz, o Visor (disco de 1967 ou sem data) mostra o Tito de 1967 sozinho num pedalinho, de costas, no fim
##      da tarde, e, do outro lado da água, a Figura Branca olhando para ele. Segurar o olhar nele, com o Visor, soma
##      `OLHAR_TOTAL` segundos (não precisam ser seguidos): "Ninguém olhou na água" vira "alguém olhou".
##   3. O Visor segue a atenção de sempre (sobe com o Q ligado): se encher, a Figura "atravessa", o Visor é arrancado da
##      mão por 10 s e a água empurra o barco de volta (`DIST_PUXAO` m na direção do atracadouro). O progresso fica.
##   4. Completo o olhar: a mãe chama ao longe, o Tito agradece, a Figura afunda e ele volta pedalando para a margem,
##      no fim de tarde de 1967. Fim "tito_salvo": título, cartão, dedicatória (Disque 100) como nos outros.
## Nada violento: o Tito nunca aparece na água, só num pedalinho ao entardecer (o peso é o que o jogador já sabe).
##
## Contratos: LÊ `pistas_tito`, `GameState.epoca`. ESCREVE flag `final_tito_salvo`, `visor_travado`/`visor_calmo`
## (só durante a cena final), e no nível `final`, `cena_feita`. Visor: a flag `visor_calmo` zera a atenção.

signal embarcou
signal desembarcou
signal puxado
signal concluiu

const PedalinhoGd := preload("res://castelinho/pedalinho.gd")
const QuartoGd := preload("res://world/niveis/porao_quarto.gd")

const PISTAS_SALVAR := 20      # era 12 de 15; o Módulo 14 (cidade) somou 6 pistas (21) e o 16 (minigames) mais 5: 26 no total
const AGUA_Y := -0.3
const POS_DOCA := Vector3(35.0, AGUA_Y, -11.4)      # o pedalinho amarelo atracado (entre o último cisne e a rampa)
const POS_Q := Vector3(-10.0, AGUA_Y, -28.0)        # onde a luz se acende e onde o Tito de 1967 está
const VEL_MAX := 2.6
const VEL_RE := 1.3
const ACEL := 3.2
const ALTURA_OLHOS_BARCO := 1.0
const LIMITE_X := 94.0
const LIMITE_Z0 := -40.5                              # fim do lago (-44) menos a folga do casco
const LIMITE_Z1 := -9.7                               # a margem tem parede: o clamp só cobre o que ela não cobre
const OLHAR_TOTAL := 9.0
const OLHAR_DIST := 30.0
const OLHAR_ANGULO := 0.42                            # rad (~24°) entre a mira e o Tito
const DIST_PUXAO := 24.0
const DIST_DESCER := 4.0
const EPOCAS_TITO: Array[int] = [5, 4]               # ESEMDATA, E1967 (as mesmas do Tito da margem)

var ativo := false          # o jogador está no pedalinho
var concluindo := false     # a cena final começou
var liberado := false       # as pistas bastam: a luz está acesa
var olhar := 0.0            # 0..1, quanto do olhar já foi dado

var nivel                   # o Braço Morto (sem tipo: acessa membros do script dele)
var player: Player
var barco: Node3D           # o pedalinho amarelo (fica no atracadouro e vira o barco do jogador)
var swan67: Node3D          # o pedalinho de 1967, com o Tito dentro
var tito67: Node3D
var fig67: FiguraBranca
var interagivel: Interagivel

var _visor: Visor
var _luz: Node3D
var _coluna: MeshInstance3D
var _mancha: MeshInstance3D
var _omni: OmniLight3D
var _vel := Vector3.ZERO
var _t := 0.0
var _fase_pedal := 0.0
var _splash_t := 0.0
var _perto_doca := false
var _ocupado := false       # fade em andamento (embarcar, descer, ser puxado)
var _avisou_perto := false
var _avisou_olhando := false
var _marcos := 0
var _luz_fim := false       # Tito já partiu: a luz do lago se apaga e não volta
var _seguir: Node3D
var _proa := 0.0            # para onde o pedalinho aponta (segue o movimento, não o olhar)


# ============================================================================ montagem (chamada no _ready do nível)
func montar(n: Node3D) -> void:
	nivel = n
	name = "BracoSalvar"
	n.add_child(self)
	_montar_barco_da_doca()
	_montar_luz()
	_montar_1967()


## O pedalinho amarelo atracado, com o balde vermelho do Tito, e a área de interação na margem.
func _montar_barco_da_doca() -> void:
	barco = PedalinhoGd.criar(Color(0.97, 0.82, 0.2), Color(0.98, 0.9, 0.35), Color(0.85, 0.2, 0.15), true)
	barco.name = "PedalinhoAmarelo"
	nivel.add_child(barco)
	barco.position = POS_DOCA
	# a corda para a margem
	var corda := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 2.9)
	corda.mesh = bm
	corda.material_override = Construtor.material(Color(0.2, 0.18, 0.15), 0.9)
	corda.position = Vector3(POS_DOCA.x, AGUA_Y + 0.55, POS_DOCA.z + 1.7)
	nivel.add_child(corda)
	interagivel = Interagivel.new("Pedalinho amarelo", Vector3(3.0, 2.2, 3.0), _embarcar)
	interagivel.name = "EmbarcarPedalinho"
	interagivel.position = Vector3(POS_DOCA.x, 1.1, -9.0)
	nivel.add_child(interagivel)


## Coluna de luz fria no meio do lago, mancha pulsante na água e uma luz de verdade (some até as pistas bastarem).
func _montar_luz() -> void:
	_luz = Node3D.new()
	_luz.name = "LuzDoLago"
	_luz.visible = false
	nivel.add_child(_luz)
	_luz.position = Vector3(POS_Q.x, AGUA_Y, POS_Q.z)
	# coluna: quad que gira para a câmera só em torno do eixo vertical, com degradê (forte na água, some no alto)
	var img := Image.create_empty(32, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var v: float = pow(float(y) / 127.0, 1.7)
		for x in 32:
			var h: float = pow(1.0 - absf(float(x) / 31.0 * 2.0 - 1.0), 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, v * h))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = Color(0.55, 0.85, 1.0, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.render_priority = 3
	var qm := QuadMesh.new()
	qm.size = Vector2(3.2, 18.0)
	_coluna = MeshInstance3D.new()
	_coluna.name = "Coluna"
	_coluna.mesh = qm
	_coluna.material_override = mat
	_coluna.position = Vector3(0, 9.0, 0)
	_coluna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_luz.add_child(_coluna)
	# mancha na água
	_mancha = PedalinhoGd.esteira()
	_mancha.name = "Mancha"
	_mancha.scale = Vector3(1.4, 1.0, 1.1)
	(_mancha.material_override as StandardMaterial3D).albedo_color = Color(0.6, 0.9, 1.0, 0.6)
	_luz.add_child(_mancha)
	var tw := _mancha.create_tween().set_loops()
	tw.tween_property(_mancha, "scale", Vector3(1.9, 1.0, 1.55), 2.2).from(Vector3(1.2, 1.0, 0.95)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_mancha, "scale", Vector3(1.2, 1.0, 0.95), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_omni = OmniLight3D.new()
	_omni.position = Vector3(0, 1.4, 0)
	_omni.light_color = Color(0.6, 0.85, 1.0)
	_omni.light_energy = 1.8
	_omni.omni_range = 11.0
	_omni.shadow_enabled = false
	_luz.add_child(_omni)


## O fim de tarde de 1967 em cima da luz: o Tito sozinho num pedalinho, de costas, e a Figura do outro lado da água.
func _montar_1967() -> void:
	swan67 = PedalinhoGd.criar(Color(0.93, 0.93, 0.9), Color(0.96, 0.96, 0.94), Color(0.2, 0.4, 0.75))
	swan67.name = "Pedalinho1967"
	nivel.add_child(swan67)
	swan67.position = POS_Q
	swan67.rotation.y = PI * 0.5         # a frente (-Z) vira para oeste: o jogador chega pelo leste e vê as costas dele
	tito67 = QuartoGd.menino(swan67, Vector3(0, 0.38, 0.12), 0.0, true, true)
	tito67.name = "Tito1967"
	Epocas.marcar(swan67, EPOCAS_TITO)
	fig67 = FiguraBranca.new()
	fig67.name = "Figura1967"
	fig67.somente_visual = true
	fig67.ativa = false
	fig67.som_ativo = false
	fig67.scale = Vector3.ONE * 1.2
	nivel.add_child(fig67)
	fig67.global_position = Vector3(POS_Q.x - 2.0, AGUA_Y - 0.15, POS_Q.z - 13.0)
	fig67.rotation.y = 0.0
	if fig67.get("_mat") != null:
		fig67._mat.set_shader_parameter("brilho", 1.9)
	Epocas.marcar(fig67, EPOCAS_TITO)


## Chamado no `iniciar` do nível, quando o jogador e o Visor já existem.
func jogador(p: Player, v: Visor) -> void:
	player = p
	_visor = v
	if v and not v.figura_atravessou.is_connected(_ao_atravessar):
		v.figura_atravessou.connect(_ao_atravessar)


# ============================================================================ embarcar, pedalar, descer
func _embarcar(_p: Node) -> void:
	if ativo or concluindo or _ocupado or player == null:
		return
	if bool(nivel.get("encerrando")) or bool(nivel.get("cena_feita")):
		return
	if not _pistas_bastam():
		nivel._mostrar_legenda("(preso com uma corrente de criança. Você ainda não sabe o bastante sobre ele.)", 4.5)
		return
	_ocupado = true
	await Transicao.fade_out(0.35)
	_colocar_no_barco(POS_DOCA, 0.0)
	_mostrar_alvo_vazio()
	nivel._mostrar_legenda("(o pedalinho amarelo. use os controles de andar para pedalar e olhe em volta; chegue na luz.)", 5.5)
	await Transicao.fade_in(0.5)
	_ocupado = false
	embarcou.emit()


func _pistas_bastam() -> bool:
	return int(GameState.contadores.get("pistas_tito", 0)) >= PISTAS_SALVAR


## Põe o jogador dentro do barco em `pos` (xz) com o olhar para `yaw`: assume o controle do corpo.
func _colocar_no_barco(pos: Vector3, yaw: float) -> void:
	ativo = true
	_vel = Vector3.ZERO
	player.set_physics_process(false)
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player.velocity = Vector3.ZERO
	player.pode_mover = true
	player.cabeca.position.y = ALTURA_OLHOS_BARCO
	player.global_position = Vector3(pos.x, AGUA_Y + PedalinhoGd.ALTURA_CONVES, pos.z)
	player.rotation.y = yaw
	player.cabeca.rotation.x = 0.0
	_proa = yaw
	barco.position = Vector3(pos.x, AGUA_Y, pos.z)
	barco.rotation.y = yaw


func _mostrar_alvo_vazio() -> void:
	player.alvo_mudou.emit("")      # o texto "Pedalinho amarelo" não fica preso na mira


func _descer() -> void:
	if not ativo or _ocupado or concluindo:
		return
	_ocupado = true
	await Transicao.fade_out(0.35)
	_soltar_corpo()
	player.global_position = Vector3(POS_DOCA.x, 0.05, -6.7)
	player.rotation.y = 0.0
	barco.position = POS_DOCA
	barco.rotation.y = 0.0
	await Transicao.fade_in(0.5)
	_ocupado = false
	desembarcou.emit()


## Devolve o corpo ao jogo normal (física, altura dos olhos, modo de movimento).
func _soltar_corpo() -> void:
	ativo = false
	_vel = Vector3.ZERO
	_perto_doca = false
	if player == null or not is_instance_valid(player):
		return
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.velocity = Vector3.ZERO
	player.cabeca.position.y = Player.ALTURA_OLHOS
	player.cabeca.rotation.z = 0.0
	player.set_physics_process(true)


func _unhandled_input(e: InputEvent) -> void:
	if ativo and not concluindo and not _ocupado and _perto_doca and e.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_descer()


func _physics_process(dt: float) -> void:
	_t += dt
	if not ativo or player == null or not is_instance_valid(player):
		return
	if concluindo or _ocupado:
		_vel = _vel.move_toward(Vector3.ZERO, ACEL * dt)
	else:
		var v := Input.get_vector("esquerda", "direita", "frente", "tras")
		var dir := player.transform.basis * Vector3(v.x, 0, v.y)
		dir.y = 0.0
		var alvo := Vector3.ZERO
		if dir.length() > 0.01:
			alvo = dir.normalized() * (VEL_RE if v.y > 0.1 and absf(v.x) < 0.1 else VEL_MAX) * minf(1.0, v.length())
		_vel = _vel.move_toward(alvo, ACEL * dt)
	if _vel.length() > 0.01:
		player.velocity = _vel
		player.move_and_slide()
	var p := player.global_position
	p.x = clampf(p.x, -LIMITE_X, LIMITE_X)
	p.z = clampf(p.z, LIMITE_Z0, LIMITE_Z1)
	var boia: float = sin(_t * 1.6) * 0.022
	p.y = AGUA_Y + PedalinhoGd.ALTURA_CONVES + boia
	player.global_position = p
	player.cabeca.rotation.z = sin(_t * 1.1) * 0.012
	barco.position = Vector3(p.x, AGUA_Y + boia, p.z)
	var rapido: float = Vector2(_vel.x, _vel.z).length()
	if rapido > 0.4 and not concluindo:
		var para_frente: float = _vel.normalized().dot(-player.global_transform.basis.z)
		if para_frente > -0.3:
			_proa = lerp_angle(_proa, atan2(-_vel.x, -_vel.z), 1.0 - exp(-2.5 * dt))
	barco.rotation.y = _proa
	_fase_pedal += rapido * dt * 2.6
	PedalinhoGd.pedalar(barco, _fase_pedal)
	if rapido > 0.5:
		_splash_t -= dt
		if _splash_t <= 0.0:
			_splash_t = 1.7
			Audio.sfx("splash", -26.0, randf_range(1.25, 1.5))
	# perto do atracadouro: E desce (aviso uma vez a cada aproximação)
	var d_doca := Vector2(p.x - POS_DOCA.x, p.z - POS_DOCA.z).length()
	var perto := d_doca < DIST_DESCER
	if perto and not _perto_doca and not concluindo and not _ocupado:
		nivel._mostrar_legenda("(E: descer do pedalinho.)", 2.5)
	_perto_doca = perto


# ============================================================================ a luz, o olhar e o puxão
func _process(dt: float) -> void:
	if player == null or nivel == null:
		return
	if not liberado and _pistas_bastam():
		liberado = true
		_luz.visible = true
		Audio.sfx("pista", -4.0)
		if not bool(nivel.get("encerrando")) and not bool(nivel.get("cena_feita")):
			nivel._mostrar_legenda("(uma luz se acendeu no meio do lago.)", 4.5)
	if _luz.visible and not _luz_fim:
		var forca: float = 0.35 + 0.65 * olhar
		(_coluna.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.30, 0.8, forca)
		_omni.light_energy = lerpf(1.2, 3.4, forca)
	if _seguir != null and is_instance_valid(_seguir):
		_olhar_para_suave(_seguir.global_position + Vector3(0, 0.7, 0), dt)
	if not ativo or concluindo or _ocupado:
		return
	var dq := Vector2(player.global_position.x - POS_Q.x, player.global_position.z - POS_Q.z).length()
	if dq < 32.0 and not _avisou_perto:
		_avisou_perto = true
		nivel._mostrar_legenda("(tem alguém ali, mas só o Visor mostra. Q liga; o disco de 1967 é a tecla 2.)", 5.5)
	if _olhando_tito():
		olhar = minf(1.0, olhar + dt / OLHAR_TOTAL)
		if not _avisou_olhando:
			_avisou_olhando = true
			nivel._mostrar_legenda("(é o Tito. ele está sozinho na água e não percebeu você. não desvie o olhar.)", 5.0)
		var marco: int = int(olhar * 3.0)
		if marco > _marcos and olhar < 1.0:
			_marcos = marco
			Audio.sfx("pista", -6.0, 0.9 + 0.1 * marco)
		if olhar >= 1.0:
			_concluir()


## O Visor mostra o Tito de 1967 e a mira está nele (a menos de `OLHAR_DIST`).
func _olhando_tito() -> bool:
	if GameState.epoca not in EPOCAS_TITO or not tito67.is_visible_in_tree():
		return false
	var cam: Camera3D = player.camera
	var alvo := tito67.global_position + Vector3(0, 0.8, 0)
	var dir := alvo - cam.global_position
	if dir.length() > OLHAR_DIST:
		return false
	return (-cam.global_transform.basis.z).angle_to(dir.normalized()) < OLHAR_ANGULO


## A atenção encheu no Visor: a Figura atravessa, o Visor sai da mão (10 s) e a água empurra o barco para trás.
func _ao_atravessar(_visita: int) -> void:
	if not ativo or concluindo or _ocupado:
		return
	_ocupado = true
	player.pode_mover = false
	nivel._mostrar_legenda("(a água te puxou para trás.)", 3.5)
	await Transicao.fade_out(0.4)
	var dir := Vector3(POS_DOCA.x - POS_Q.x, 0.0, POS_DOCA.z - POS_Q.z).normalized()
	var nova := Vector3(POS_Q.x, 0.0, POS_Q.z) + dir * DIST_PUXAO
	player.global_position.x = nova.x
	player.global_position.z = nova.z
	_vel = Vector3.ZERO
	player.rotation.y = atan2(-(POS_Q.x - nova.x), -(POS_Q.z - nova.z))     # de frente para a luz de novo
	player.cabeca.rotation.x = 0.0
	player.pode_mover = true
	await Transicao.fade_in(0.8)
	_ocupado = false
	puxado.emit()


# ============================================================================ o fim: tito_salvo
func _concluir() -> void:
	if concluindo:
		return
	concluindo = true
	nivel.final = "tito_salvo"
	nivel.cena_feita = true
	nivel._hud_cinema(true)
	player.pode_mover = false
	GameState.set_flag("visor_calmo", true)
	GameState.set_flag("visor_travado", true)       # soltar o Q no meio da cena devolveria a noite e estragaria tudo
	if GameState.epoca not in EPOCAS_TITO:
		GameState.trocar_epoca(GameState.Epoca.E1967)
	Audio.sfx("slide", -6.0)
	_seguir = tito67
	await _espera(1.8)
	# ele se vira devagar para o jogador
	var tw := create_tween()
	tw.tween_property(tito67, "rotation:y", PI, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	nivel._mostrar_legenda("Você ficou olhando.", 3.2, 36)
	await _espera(3.8)
	Audio.sfx("crianca_ei", -2.0)
	nivel._mostrar_legenda("(da calçada, uma voz de mulher:)\n— Titooo! Já pra casa!", 4.2, 32)
	await _espera(5.0)
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	nivel._mostrar_legenda("É a minha mãe.", 2.8, 36)
	await _espera(3.6)
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	nivel._mostrar_legenda("Obrigado por olhar na água.", 3.4, 36)
	await _espera(4.2)
	# a Figura perde o menino: afunda devagar e o lago aquieta
	Audio.sfx("figura_afunda", -6.0)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(fig67, "position:y", AGUA_Y - 3.4, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw2.tween_property(nivel.mat_agua, "shader_parameter/ondas", 0.0, 4.0)
	tw2.tween_property(nivel.mat_agua, "shader_parameter/velocidade", 0.06, 4.0)
	await _espera(2.4)
	# o pedalinho dele vira para a margem e vai embora
	var tw3 := create_tween()
	tw3.tween_property(swan67, "rotation:y", -PI * 0.5 - 0.35, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw3.parallel().tween_property(tito67, "rotation:y", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw3.finished
	_apagar_luz()
	var destino := Vector3(30.0, AGUA_Y, -17.0)
	var tw4 := create_tween()
	tw4.tween_method(_pedalar_embora.bind(swan67.position, destino), 0.0, 1.0, 12.0)
	await _espera(9.0)
	nivel.final = "tito_salvo"
	GameState.set_flag("final_tito_salvo", true)
	concluiu.emit()
	nivel._encerrar()


## A luz do lago se apaga devagar: quem estava preso foi para casa.
func _apagar_luz() -> void:
	_luz_fim = true
	var mat := _coluna.material_override as StandardMaterial3D
	var tw := create_tween().set_parallel()
	tw.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tw.tween_property(_omni, "light_energy", 0.0, 4.0)
	tw.tween_property(_mancha, "visible", false, 0.01).set_delay(4.0)


func _pedalar_embora(f: float, origem: Vector3, destino: Vector3) -> void:
	var s := f * f * (3.0 - 2.0 * f)
	var pos := origem.lerp(destino, s)
	pos.y = AGUA_Y + sin(_t * 1.6) * 0.02
	swan67.position = pos
	PedalinhoGd.pedalar(swan67, f * 60.0)


func _espera(seg: float) -> void:
	await get_tree().create_timer(seg, false).timeout


func _olhar_para_suave(ponto: Vector3, dt: float) -> void:
	var d := ponto - player.cabeca.global_position
	var yaw_alvo := atan2(-d.x, -d.z)
	var pitch_alvo := atan2(d.y, Vector2(d.x, d.z).length())
	var k: float = 1.0 - exp(-3.0 * dt)
	player.rotation.y = lerp_angle(player.rotation.y, yaw_alvo, k)
	player.cabeca.rotation.x = lerpf(player.cabeca.rotation.x, pitch_alvo, k)


# ============================================================================ apoio (debug e testes)
## Depuração/teste: embarca de uma vez e vai direto à cena final, a `dist` m a leste do Tito de 1967.
func depurar_cena_final(dist := 11.0) -> void:
	if player == null:
		return
	_colocar_no_barco(Vector3(POS_Q.x + dist, 0.0, POS_Q.z + 1.5), 0.0)
	player.rotation.y = atan2(-(POS_Q.x - player.global_position.x), -(POS_Q.z - player.global_position.z))
	_mostrar_alvo_vazio()
	liberado = true
	_luz.visible = true
	olhar = 1.0
	_concluir()


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.flags.erase("visor_calmo")
	if ativo:
		_soltar_corpo()
