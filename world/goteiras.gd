class_name Goteiras
extends RefCounted
## Goteiras do teto das salas do porão (V2 §6.1): em 2 ou 3 pontos de cada sala uma gota se solta do teto, cai e bate no
## chão ou na água (com um aneizinho de respingo). A queda é SINCRONIZADA com o loop de ambiente "goteira"
## (assets/audio/goteira.ogg, 6 s, pingos em 0,4 / 1,55 / 2,9 / 3,7 / 4,95 s; tools/gerar_audio.py): cada ponto
## assume um desses pingos e a gota é solta no instante certo para BATER junto com o som (Audio.posicao_ambiente).
## Sem o loop tocando (testes, mudo) um relógio próprio de 6 s faz o mesmo.
##
## Gancho: `Goteiras.criar(ctx_da_sala, nivel)` ao montar cada sala (porao.gd `_carregar_sala`). Tudo é filho da raiz da
## sala e some com ela. Nada na sala 95 (quarto do Tito, seco). Barato para a web: no máximo 3 pontos x 2
## CPUParticles3D de 1 partícula por sala (2 pontos no modo leve do celular).

const CICLO := 6.0
## Instantes (s) dos pingos no loop goteira.ogg.
const IMPACTOS: Array[float] = [0.4, 1.55, 2.9, 3.7, 4.95]
const G := 9.8
const SALA_QUARTO_IDX := 14          # sala 95: quarto seco
const FOLGA_TETO := 0.08             # a gota nasce um pouco dentro do teto (escondida pela laje)
## Altura do teto (local) de cada tipo de sala, no lado das paredes (nas abóbadas é a altura do arranque).
const TETO := {
	"abobada": 2.7, "colunas": 4.4, "cisterna": 5.0, "desenhos": 3.4, "crianca": 2.7, "pedras": 4.2, "alagado": 3.0,
	"arcos": 3.8, "telefone": 2.9, "poco": 4.6, "bifurcacao": 3.6,
}
const ALT_ESCADA := 3.4
const COR_GOTA := Color(0.72, 0.86, 0.9, 0.85)

static var _tex_anel: Texture2D


## Cria o nó "Goteiras" na sala `c` (Ctx de PoraoSalas). Devolve null se a sala não tem goteira (quarto do Tito).
static func criar(c, nivel: Node) -> Node3D:
	if c == null or c.raiz == null or c.idx == SALA_QUARTO_IDX or c.tipo == "quarto_tito":
		return null
	if c.raiz.get_node_or_null("Goteiras") != null:
		return c.raiz.get_node_or_null("Goteiras")
	var sala := Sala.new()
	sala.name = "Goteiras"
	sala.c = c
	sala.nivel = nivel
	c.raiz.add_child(sala)
	sala.montar()
	return sala


## Quantos pontos de gota cada sala tem (2 ou 3; 2 no modo leve do celular).
static func quantos(idx: int) -> int:
	if Celular.ativo:
		return 2
	return 2 + (idx % 2)


static func _textura_anel() -> Texture2D:
	if _tex_anel == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
				var a := smoothstep(0.55, 0.72, d) * (1.0 - smoothstep(0.86, 0.98, d))
				img.set_pixel(x, y, Color(0.85, 0.95, 1.0, a))
		_tex_anel = ImageTexture.create_from_image(img)
	return _tex_anel


## true se `t` (s no ciclo) foi atravessado ao ir de `a` para `b` (com a volta do loop).
static func cruzou(a: float, b: float, t: float) -> bool:
	if b >= a:
		return a < t and t <= b
	return t > a or t <= b


class Sala:
	extends Node3D

	var c
	var nivel: Node
	var pontos: Array = []          # {x, z, teto, impacto, queda, splash}
	var _ult := -1.0
	var _relogio := 0.0

	func montar() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8100 + int(c.idx)
		var n := Goteiras.quantos(int(c.idx))
		var mat_gota := StandardMaterial3D.new()
		mat_gota.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_gota.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_gota.albedo_color = Goteiras.COR_GOTA
		var mat_anel := StandardMaterial3D.new()
		mat_anel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_anel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_anel.vertex_color_use_as_albedo = true
		mat_anel.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat_anel.albedo_texture = Goteiras._textura_anel()
		for k in n:
			var lado := -1.0 if (k + int(c.idx)) % 2 == 0 else 1.0
			var folga: float = 0.7 if c.tipo != "cisterna" else 0.9
			var x: float = lado * (c.w * 0.5 - folga) if c.tipo != "cisterna" else lado * 0.9
			x += rng.randf_range(-0.25, 0.25) if c.tipo != "cisterna" else 0.0
			var z: float = -c.L * (0.2 + 0.28 * k + rng.randf_range(-0.05, 0.05))
			var ponto := {"x": x, "z": z, "teto": _teto(z) + Goteiras.FOLGA_TETO,
				"impacto": Goteiras.IMPACTOS[(int(c.idx) + k * 2) % Goteiras.IMPACTOS.size()]}
			ponto["queda"] = _criar_queda(mat_gota, ponto)
			ponto["splash"] = _criar_splash(mat_anel, ponto)
			pontos.append(ponto)

	func _teto(z: float) -> float:
		if c.tipo == "escada" or c.tipo == "escada_sobe":
			return Goteiras.ALT_ESCADA + float(c.dy) * (-z / float(c.L))
		return float(Goteiras.TETO.get(c.tipo, 3.0))

	func _criar_queda(mat: Material, ponto: Dictionary) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.name = "Gota"
		p.emitting = false
		p.one_shot = true
		p.amount = 1
		p.lifetime = 0.8
		p.explosiveness = 1.0
		p.direction = Vector3.DOWN
		p.spread = 0.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		p.gravity = Vector3(0, -Goteiras.G, 0)
		p.local_coords = false
		var m := SphereMesh.new()
		m.radius = 0.032
		m.height = 0.15
		m.radial_segments = 6
		m.rings = 3
		m.material = mat
		p.mesh = m
		p.position = Vector3(ponto["x"], ponto["teto"], ponto["z"])
		p.visibility_aabb = AABB(Vector3(-1, -7, -1), Vector3(2, 8, 2))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		return p

	func _criar_splash(mat: Material, ponto: Dictionary) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.name = "Respingo"
		p.emitting = false
		p.one_shot = true
		p.amount = 1
		p.lifetime = 0.6
		p.explosiveness = 1.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		p.gravity = Vector3.ZERO
		p.local_coords = false
		var m := PlaneMesh.new()
		m.size = Vector2(0.55, 0.55)
		m.material = mat
		p.mesh = m
		var curva := Curve.new()
		curva.add_point(Vector2(0.0, 0.25))
		curva.add_point(Vector2(1.0, 1.0))
		p.scale_amount_curve = curva
		var rampa := Gradient.new()
		rampa.set_color(0, Color(1, 1, 1, 0.8))
		rampa.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = rampa
		p.position = Vector3(ponto["x"], 0.0, ponto["z"])
		p.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		return p

	## y local do chão ou da água onde a gota bate.
	func superficie(ponto: Dictionary) -> float:
		var piso: float = c.piso_fn.call(ponto["z"])
		if c.tipo == "cisterna" and absf(float(ponto["x"])) < 1.3:
			return piso          # a passarela
		var agua := c.raiz.get_node_or_null("Agua") as MeshInstance3D
		if agua != null and agua.visible:
			return maxf(piso, agua.position.y)
		return piso

	## Tempo de queda (s) do teto até a superfície.
	func queda_s(ponto: Dictionary) -> float:
		var h := maxf(float(ponto["teto"]) - superficie(ponto), 0.3)
		return sqrt(2.0 * h / Goteiras.G)

	func _process(dt: float) -> void:
		_relogio = fposmod(_relogio + dt, Goteiras.CICLO)
		if nivel == null or not is_instance_valid(nivel):
			return
		var atual = nivel.get("idx_atual")
		if atual == null or int(c.idx) < int(atual) or int(c.idx) > int(atual) + 1:
			_ult = -1.0
			return
		var pos := _posicao()
		if _ult >= 0.0:
			for ponto in pontos:
				_tocar(ponto, _ult, pos)
		_ult = pos

	func _posicao() -> float:
		var audio := Engine.get_main_loop().root.get_node_or_null("Audio") as Node
		if audio != null and audio.has_method("posicao_ambiente"):
			var p: float = audio.posicao_ambiente("goteira")
			if p >= 0.0:
				return p
		return _relogio

	## Solta a gota (no instante em que ela precisa cair para bater no pingo) e o respingo (no pingo).
	func _tocar(ponto: Dictionary, de: float, ate: float) -> void:
		var tq := queda_s(ponto)
		var t_solta := fposmod(float(ponto["impacto"]) - tq, Goteiras.CICLO)
		if Goteiras.cruzou(de, ate, t_solta):
			soltar(ponto, tq)
		if Goteiras.cruzou(de, ate, float(ponto["impacto"])):
			respingar(ponto)

	func soltar(ponto: Dictionary, tq := -1.0) -> void:
		var q := ponto["queda"] as CPUParticles3D
		if not is_instance_valid(q):
			return
		q.lifetime = maxf(tq if tq > 0.0 else queda_s(ponto), 0.2)
		q.restart()
		q.emitting = true

	func respingar(ponto: Dictionary) -> void:
		var s := ponto["splash"] as CPUParticles3D
		if not is_instance_valid(s):
			return
		s.position.y = superficie(ponto) + 0.015
		s.restart()
		s.emitting = true
