class_name FlashAgua
extends RefCounted
## Lampejos de água subindo ao redor do jogador (visita 4, sala 80: "Ouça. A água desce por aqui."): 3 clarões rápidos
## (~0,2 s, a cada ~0,4 s) de um anel de água azul-esverdeada translúcida que sobe do piso até ~1,3 m e some, com o som
## "agua_sobe" e um clarão azul-esverdeado na tela. Nada fica na cena depois (tudo é filho de um nó "FlashAgua" que se apaga).
##
##   FlashAgua.na_linha(self, "Ouça. A água desce por aqui.")   # liga os lampejos a essa linha da fala do Guia
##   FlashAgua.disparar(self)                       # ou dispara direto
##
## Barato para a web: dois MeshInstance3D por lampejo (anel aberto + tampa), material sem luz, sem partículas.

const N_LAMPEJOS := 3
const INTERVALO := 0.4               # s entre o começo de um lampejo e o do seguinte
const DUR_MIN := 0.15
const DUR_MAX := 0.25
const ALTURA := 1.3                  # m: até onde a água sobe
const RAIO := 3.4                    # m: o anel em volta do jogador
const COR := Color(0.08, 0.5, 0.56)
const COR_CLARAO := Color(0.1, 0.55, 0.6)
const SHADER := preload("res://shaders/flash_agua.gdshader")


## Quando o Guia mostrar a linha `linha`, dispara os lampejos (uma vez só). Na visita 4 o texto do Guia chega CORROMPIDO
## ("4 água desce por 4qu1"), por isso a comparação é por tamanho + semelhança, não por igualdade.
static func na_linha(nivel: Node, linha: String) -> void:
	var guia: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Guia")
	if guia == null or not guia.has_signal("linha_mostrada"):
		return
	var estado := {"cb": Callable()}
	estado["cb"] = func(_quem: String, texto: String) -> void:
		if not mesma_linha(texto, linha):
			return
		guia.linha_mostrada.disconnect(estado["cb"])
		if is_instance_valid(nivel):
			disparar(nivel)
	guia.linha_mostrada.connect(estado["cb"])
	# se a fala nunca chegar nessa linha (cancelada), o gancho expira em 60 s e não fica preso
	guia.get_tree().create_timer(60.0, false).timeout.connect(func() -> void:
		if guia.linha_mostrada.is_connected(estado["cb"]):
			guia.linha_mostrada.disconnect(estado["cb"]))


## `texto` é `linha` (talvez com letras trocadas por números pela corrupção, mesmo tamanho)?
static func mesma_linha(texto: String, linha: String) -> bool:
	if texto == linha:
		return true
	if texto.length() != linha.length() or linha.is_empty():
		return false
	var iguais := 0
	for i in linha.length():
		if texto[i] == linha[i]:
			iguais += 1
	return float(iguais) / float(linha.length()) >= 0.6


## Os 3 lampejos em volta de `jogador` (senão, o do grupo "player"). Devolve quando acabou e o nó foi apagado.
static func disparar(nivel: Node, jogador: Node3D = null) -> void:
	if nivel == null or not is_instance_valid(nivel) or not nivel.is_inside_tree():
		return
	var arvore := nivel.get_tree()
	if jogador == null:
		jogador = arvore.get_first_node_in_group("player") as Node3D
	if jogador == null:
		return
	var raiz := Node3D.new()
	raiz.name = "FlashAgua"
	nivel.add_child(raiz)
	for i in N_LAMPEJOS:
		if not is_instance_valid(raiz) or not is_instance_valid(jogador):
			break
		_lampejo(raiz, jogador, i)
		await arvore.create_timer(INTERVALO, false).timeout
	await arvore.create_timer(0.3, false).timeout       # o último lampejo ainda está sumindo
	if is_instance_valid(raiz):
		raiz.queue_free()


static func _lampejo(raiz: Node3D, jogador: Node3D, i: int) -> void:
	var dur := randf_range(DUR_MIN, DUR_MAX)
	var partes := montar(raiz, jogador.global_position)
	posicionar(partes, 0.0, 0.0)
	var tw := raiz.create_tween()
	tw.tween_method(func(k: float) -> void:
		posicionar(partes, k, sin(clampf(k, 0.0, 1.0) * PI) * 0.6), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(partes["no"]):
			(partes["no"] as Node).queue_free())
	Efeitos.flash(dur * 0.9, COR_CLARAO, 0.32)
	Audio.sfx("agua_sobe", -5.0 - i, 1.0 + 0.12 * i)


## Monta o anel + a tampa em `centro` (no piso). Devolve {no, anel, tampa, mat}. Público para o teste e as capturas.
static func montar(pai: Node3D, centro: Vector3) -> Dictionary:
	var no := Node3D.new()
	no.name = "Lampejo"
	pai.add_child(no)
	no.global_position = centro
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("cor", COR)
	mat.set_shader_parameter("alfa", 0.0)
	var anel_malha := CylinderMesh.new()
	anel_malha.top_radius = RAIO
	anel_malha.bottom_radius = RAIO
	anel_malha.height = ALTURA
	anel_malha.radial_segments = 20
	anel_malha.rings = 1
	anel_malha.cap_top = false
	anel_malha.cap_bottom = false
	var anel := MeshInstance3D.new()
	anel.mesh = anel_malha
	anel.material_override = mat
	anel.position.y = ALTURA * 0.5
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base := Node3D.new()                     # pivô no piso: a escala em y faz o anel crescer a partir do chão
	base.name = "Anel"
	base.add_child(anel)
	no.add_child(base)
	var tampa_malha := CylinderMesh.new()
	tampa_malha.top_radius = RAIO
	tampa_malha.bottom_radius = RAIO
	tampa_malha.height = 0.01
	tampa_malha.radial_segments = 20
	tampa_malha.rings = 1
	var tampa := MeshInstance3D.new()
	tampa.name = "Tampa"
	tampa.mesh = tampa_malha
	tampa.material_override = mat
	tampa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(tampa)
	return {"no": no, "anel": base, "tampa": tampa, "mat": mat}


## `k` 0..1: quanto a água já subiu (0 = piso, 1 = ALTURA); `alfa` = opacidade.
static func posicionar(partes: Dictionary, k: float, alfa: float) -> void:
	var nivel_y := lerpf(0.02, ALTURA, clampf(k, 0.0, 1.0))
	if is_instance_valid(partes["anel"]):
		(partes["anel"] as Node3D).scale.y = maxf(nivel_y / ALTURA, 0.02)
		(partes["tampa"] as Node3D).position.y = nivel_y
		(partes["mat"] as ShaderMaterial).set_shader_parameter("alfa", alfa)
