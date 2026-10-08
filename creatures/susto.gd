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
##   "silhueta": true = vulto pequeno de criança em vez da Figura; "emergir": m que sobem da água (pos.y = a superfície);
##   "cair": true = despenca de cima; "tranco" 1.0 (força do tranco de câmera), "pulso" 1.5, "flash": true.
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
		frente = frente.normalized().rotated(Vector3.UP, deg_to_rad(float(o.get("angulo", 0.0))))
		pos = jogador.global_position + frente * float(o.get("frente", 1.8))
	var no: Node3D
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
	if no is FiguraBranca:
		no.remove_from_group("figura_branca")
		no.set_physics_process(false)             # só visual: não anda, não vira, não mata
		no.olhada = true                          # pose congelada, "estalada"
	var topo := pos
	var para := jogador.global_position - pos
	no.rotation.y = atan2(-para.x, -para.z)
	var emergir: float = o.get("emergir", 0.0)
	if emergir > 0.0:
		no.global_position = pos - Vector3(0, 2.4, 0)
	elif o.get("cair", false):
		no.global_position = pos + Vector3(0, 1.6, 0)
	else:
		no.global_position = pos
	var vol: float = o.get("volume_db", 0.0)
	var som: String = o.get("sfx", "susto")
	if som != "":
		Audio.sfx(som, vol)
	Efeitos.pulso(float(o.get("pulso", 1.5)), 0.5)
	if o.get("flash", true):
		Efeitos.flash(0.18, Color(1, 1, 1), 0.35)
	_tranco(cam, float(o.get("tranco", 1.0)))
	var dur := clampf(float(o.get("duracao", 0.6)), 0.3, 1.0)
	if emergir > 0.0:
		var alto := pos.y - emergir
		var tw2 := nivel.create_tween()
		tw2.tween_property(no, "global_position:y", alto, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(maxf(dur - 0.5, 0.05))
		tw2.tween_property(no, "global_position:y", pos.y - 2.4, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	elif o.get("cair", false):
		var tw3 := nivel.create_tween()
		tw3.tween_property(no, "global_position:y", topo.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await arvore.create_timer(dur, false).timeout
	if is_instance_valid(no):
		no.queue_free()
	if o.get("flash", true):
		Efeitos.flash(0.12, Color(0, 0, 0), 0.5)         # corte seco


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
