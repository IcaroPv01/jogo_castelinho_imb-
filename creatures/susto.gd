class_name Susto
extends RefCounted
## Susto que NÃO mata (helper reutilizável). Uma Figura Branca só visual (sem física, sem IA, fora do grupo
## "figura_branca") ou uma silhueta de criança aparece de repente, o som toca, a tela dá um tranco e ela some.
##
##   Susto.disparar(self, "porao_j3", {"angulo": 180.0, "frente": 1.0})
##
## Cada susto acontece UMA vez por partida (flag `susto_<chave>` no GameState; a morte não o devolve).
## É ignorado se o jogador está morrendo/afogando/saindo (propriedades `morrendo`, `afogando`, `_saindo` do `nivel`, se
## existirem) ou com UI aberta. Opções (todas opcionais):
##   "pos": Vector3 global (senão: à frente da câmera por `frente` m, girado `angulo` graus: 0 frente, 180 atrás)
##   "frente" 1.8, "angulo" 0.0, "duracao" 0.6 (s visível; 0,4 a 0,8), "volume_db" 0.0, "sfx" "susto" ("" = mudo)
##   "apagar": s com as `luzes` apagadas antes (0 = não apaga), "sfx_antes": som quando apaga ("porta" etc.)
##   "silhueta": true = vulto pequeno de criança em vez da Figura; "emergir": true = sobe da água e afunda;
##   "cair": true = despenca de cima; "tranco" 1.0 (força do tranco de câmera), "pulso" 0.35 (glitch leve),
##   "escala" 1.0 (a Figura é só a cabeça pequena: aumenta para o rosto encher a tela), "flash": true (só um corte preto
##   no FIM; na revelação nunca há clarão). Colada na câmera (< ~1,2 m) a Figura é abaixada para o ROSTO ficar na altura
##   dos olhos; mais longe (> ~2 m) ela PISA no chão (raycast para baixo) e inclina a cabeça para o rosto "olhar" o
##   jogador; entre os dois, mistura. Sem "pos", o ponto é ajustado (`_ponto_livre`) para a Figura não nascer dentro de
##   parede/arco: inteira, com linha de visão livre até a câmera e folga em volta.
## Devolve true se o susto foi disparado.

const FLAG := "susto_"


static func ja_aconteceu(chave: String) -> bool:
	return bool(GameState.flag(FLAG + chave))


static func permitido(nivel: Node, chave: String) -> bool:
	if nivel == null or not is_instance_valid(nivel) or not nivel.is_inside_tree():
		return false
	if ja_aconteceu(chave) or GameState.flag("ui_aberta"):
		return false
	for p in ["morrendo", "afogando", "_saindo"]:
		if nivel.get(p) == true:
			return false
	var jogador := nivel.get_tree().get_first_node_in_group("player") as Node3D
	return jogador != null and jogador.get("pode_mover") != false


static func disparar(nivel: Node, chave: String, o: Dictionary = {}) -> bool:
	if not permitido(nivel, chave):
		return false
	GameState.set_flag(FLAG + chave, true)
	_rodar(nivel, o)
	return true


static func _rodar(nivel: Node, o: Dictionary) -> void:
	var arvore := nivel.get_tree()
	var apagar: float = o.get("apagar", 0.0)
	var luzes: Array = o.get("luzes", [])
	var estavam := []
	if apagar > 0.0:
		for l in luzes:
			if is_instance_valid(l):
				estavam.append([l, l.visible])
				l.visible = false
		if o.get("sfx_antes", "") != "":
			Audio.sfx(o["sfx_antes"], -2.0)
		await arvore.create_timer(apagar, false).timeout
		for par in estavam:
			if is_instance_valid(par[0]):
				par[0].visible = par[1]
	if not is_instance_valid(nivel) or not nivel.is_inside_tree():
		return
	var jogador := nivel.get_tree().get_first_node_in_group("player") as Node3D
	if jogador == null or nivel.get("morrendo") == true or nivel.get("afogando") == true or nivel.get("_saindo") == true:
		return
	var cam: Camera3D = jogador.get("camera")
	var pos: Vector3
	if o.has("pos"):
		pos = o["pos"]
	else:
		var frente := -cam.global_transform.basis.z
		frente.y = 0.0
		frente = frente.normalized()
		pos = jogador.global_position + frente.rotated(Vector3.UP, deg_to_rad(float(o.get("angulo", 0.0)))) * float(o.get("frente", 1.8))
		if not o.get("silhueta", false):
			pos = _ponto_livre(nivel, cam, jogador, frente, float(o.get("angulo", 0.0)), float(o.get("frente", 1.8)), pos)
	var no: Node3D
	var escala: float = o.get("escala", 1.0)
	if o.get("silhueta", false):
		no = _silhueta()
	else:
		var f := FiguraBranca.new()
		f.ativa = false
		f.som_ativo = false
		f.collision_layer = 0
		f.collision_mask = 0
		no = f
	nivel.add_child(no)
	var y_final := pos.y
	if no is FiguraBranca:
		no.remove_from_group("figura_branca")
		no.set_physics_process(false)             # só visual: não anda, não vira, não mata
		no.olhada = true                          # pose congelada, "estalada"
		no._mat.set_shader_parameter("brilho", 1.5)       # mais clara só durante o susto
		no.scale = Vector3.ONE * escala
		# o rosto fica a ~2,12 m do pé. Colada na câmera: rosto na altura dos olhos. Longe: pés no piso e cabeça
		# inclinada para baixo (o rosto continua "olhando" o jogador). Entre 1,2 e 2,0 m: mistura.
		var dist_h := Vector2(pos.x - jogador.global_position.x, pos.z - jogador.global_position.z).length()
		var piso := _piso_em(nivel, pos, jogador.global_position.y)
		var t_piso := smoothstep(1.2, 2.0, dist_h)
		y_final = lerpf(cam.global_position.y - 2.12 * escala, piso, t_piso)
		var rosto_y := y_final + 2.12 * escala
		no.inclinar_cabeca(atan2(rosto_y - cam.global_position.y, maxf(dist_h, 0.3)))
	var para := jogador.global_position - pos
	no.rotation.y = atan2(-para.x, -para.z)         # de frente para quem olha
	var emergir: bool = o.get("emergir", false)
	if emergir:
		no.global_position = Vector3(pos.x, y_final - 2.4 * escala, pos.z)
	elif o.get("cair", false):
		no.global_position = Vector3(pos.x, y_final + 1.6, pos.z)
	else:
		no.global_position = Vector3(pos.x, y_final, pos.z)
	var vol: float = o.get("volume_db", 0.0)
	var som: String = o.get("sfx", "susto")
	if som != "":
		Audio.sfx(som, vol)
	Efeitos.pulso(float(o.get("pulso", 0.35)), 0.4)
	_tranco(cam, float(o.get("tranco", 1.0)))
	var dur := clampf(float(o.get("duracao", 0.6)), 0.3, 1.0)
	if emergir:
		var tw2 := nivel.create_tween()
		tw2.tween_property(no, "global_position:y", y_final, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(maxf(dur - 0.5, 0.05))
		tw2.tween_property(no, "global_position:y", y_final - 2.4 * escala, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif o.get("cair", false):
		var tw3 := nivel.create_tween()
		tw3.tween_property(no, "global_position:y", y_final, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await arvore.create_timer(dur, false).timeout
	if is_instance_valid(no):
		no.queue_free()
	if o.get("flash", true):
		Efeitos.flash(0.12, Color(0, 0, 0), 0.6)         # corte seco, preto, só no fim


## Altura do piso em `pos` (raycast para baixo no mundo; senão `y_padrao`, o pé do jogador).
static func _piso_em(nivel: Node, pos: Vector3, y_padrao: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(pos.x, y_padrao + 1.2, pos.z), Vector3(pos.x, y_padrao - 1.5, pos.z), 1)
	q.collide_with_areas = false
	var h: Dictionary = nivel.get_world_3d().direct_space_state.intersect_ray(q)
	return float(h.position.y) if not h.is_empty() else y_padrao


static func _linha_livre(nivel: Node, de: Vector3, para: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, para, 1)
	q.collide_with_areas = false
	return nivel.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A Figura (~0,55 m de folga em volta, 2,4 m de altura) cabe em `p`? Piso por perto, linha de visão livre da câmera até
## os pés, o peito e a cabeça, e folga horizontal em volta (nada de nascer dentro de parede ou arco).
static func _cabe(nivel: Node, cam: Camera3D, y_pe: float, p: Vector3) -> bool:
	var piso := _piso_em(nivel, p, y_pe)
	if absf(piso - y_pe) > 0.8:
		return false
	var base := Vector3(p.x, piso, p.z)
	for h: float in [0.3, 1.2, 2.2]:
		if not _linha_livre(nivel, cam.global_position, base + Vector3.UP * h):
			return false
	for k in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 8.0) * 0.55
		for h: float in [0.5, 1.4, 2.2]:
			if not _linha_livre(nivel, base + Vector3.UP * h, base + Vector3.UP * h + d):
				return false
	return true


## Ponto onde a Figura aparece: o pedido (`angulo`, `frente`) se couber; senão o mais próximo que couber (primeiro varia
## o ângulo, sem sair do campo de visão se o pedido estava nele, depois encurta a distância até ~1 m). Se nada couber, o pedido.
static func _ponto_livre(nivel: Node, cam: Camera3D, jogador: Node3D, frente: Vector3, angulo: float, dist: float, pedido: Vector3) -> Vector3:
	var y_pe := jogador.global_position.y
	for f in [1.0, 0.88, 0.76, 0.64, 0.52, 0.44]:
		var d: float = dist * f
		if d < 1.0 and f < 1.0:
			break
		for da in [0.0, 12.0, -12.0, 24.0, -24.0, 36.0, -36.0, 50.0, -50.0]:
			var a: float = angulo + da
			if absf(angulo) <= 60.0 and absf(a) > maxf(32.0, absf(angulo)):
				continue                     # pedida na frente/de lado: tem que continuar no campo de visão
			var p := jogador.global_position + frente.rotated(Vector3.UP, deg_to_rad(a)) * d
			if _cabe(nivel, cam, y_pe, p):
				return p
	return pedido


## Tranco curto de câmera: giro de lado e aperto de FOV que voltam rápido.
static func _tranco(cam: Camera3D, forca: float) -> void:
	if cam == null or forca <= 0.0 or not cam.is_inside_tree():
		return
	var fov0 := cam.fov
	var tw := cam.create_tween().set_parallel()
	cam.rotation.z = 0.09 * forca
	cam.fov = fov0 - 9.0 * forca
	tw.tween_property(cam, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "fov", fov0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Vulto pequeno, da altura de uma criança (~1 m), preto e sem luz.
static func _silhueta() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "SilhuetaSusto"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.01, 0.01, 0.015)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.2
	corpo.height = 0.85
	var mi := MeshInstance3D.new()
	mi.mesh = corpo
	mi.material_override = m
	mi.position.y = 0.43
	raiz.add_child(mi)
	var cab := SphereMesh.new()
	cab.radius = 0.15
	cab.height = 0.3
	var mc := MeshInstance3D.new()
	mc.mesh = cab
	mc.material_override = m
	mc.position.y = 1.0
	raiz.add_child(mc)
	return raiz
