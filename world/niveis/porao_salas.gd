class_name PoraoSalas
extends RefCounted
## Salas pré-fabricadas do porão (V2_ROTEIRO §6.1). Cada tipo é uma função estática que monta, POR CÓDIGO, uma sala
## inteira num `Ctx` (geometria fundida por material na `Malha` do Castelinho: poucos draw calls para a web).
##
## QUADRO DE UMA SALA (coordenadas locais da raiz da sala):
##   - a entrada fica na origem, olhando para -Z; o interior vai de z = 0 a z = -L, de x = -w/2 a x = +w/2;
##   - a "lâmina de entrada" (parede de T = 0,6 m com uma abertura em arco no centro) fica em z = 0 .. +T,
##     ou seja, ocupa o lugar do FIM da sala anterior. Por isso uma sala não constrói parede de saída: a saída
##     dela é a lâmina da próxima (e a última sala constrói a sua, ver `lamina_saida`);
##   - a próxima sala nasce em (dx, dy, -L - T) da atual, sem giro: as salas se encadeiam em linha reta
##     (a escada desce/sobe `dy`), o que torna trivial carregar a próxima e descarregar a anterior.
##
## Cada sala pode ter: luzes (no máximo 2, orçamento de 6 luzes na web), uma porta de entrada que se fecha atrás do
## jogador, um ponto de voz do Tito, pistas (nós marcados por época), pontos da Figura Branca e da Costela e a
## área de afogamento (bifurcação errada). O `porao.gd` lê tudo isso do `Ctx`.

const MalhaGd := preload("res://castelinho/malha.gd")
const MurosGd := preload("res://castelinho/muros.gd")

const T := 0.6                       # espessura das paredes e da lâmina de entrada
const PORTA_L := 2.4                 # largura da abertura de passagem
const PORTA_VS := 2.3                # imposta do arco
const PORTA_VC := 2.9                # fecho do arco

## Os 11 tipos sorteáveis, a bifurcação (sala da voz), o quarto do Tito e a escada que sobe (sala 99).
const TIPOS_SORTEIO: Array[String] = ["abobada", "colunas", "cisterna", "escada", "desenhos", "crianca", "pedras",
	"alagado", "arcos", "telefone", "poco"]

## Medidas de cada tipo: w (largura interna), L (comprimento), dy (desnível da saída), base_agua (cota local onde a
## água do nível 0 repousa; o plano sobe a partir dela) e `agua` (false = a sala não alaga: o quarto seco).
const DIMS := {
	"abobada": {"w": 3.4, "L": 14.0, "dy": 0.0, "base_agua": 0.0},
	"colunas": {"w": 11.0, "L": 13.0, "dy": 0.0, "base_agua": 0.0},
	"cisterna": {"w": 12.0, "L": 14.0, "dy": 0.0, "base_agua": -1.2},
	"escada": {"w": 3.6, "L": 11.0, "dy": -3.2, "base_agua": -3.2},
	"desenhos": {"w": 8.0, "L": 10.0, "dy": 0.0, "base_agua": 0.0},
	"crianca": {"w": 6.0, "L": 8.0, "dy": 0.0, "base_agua": 0.0},
	"pedras": {"w": 9.0, "L": 12.0, "dy": 0.0, "base_agua": 0.0},
	"alagado": {"w": 4.4, "L": 16.0, "dy": 0.0, "base_agua": -0.55},
	"arcos": {"w": 7.0, "L": 16.0, "dy": 0.0, "base_agua": 0.0},
	"telefone": {"w": 5.0, "L": 7.0, "dy": 0.0, "base_agua": 0.0},
	"poco": {"w": 9.0, "L": 11.0, "dy": 0.0, "base_agua": 0.0},
	"bifurcacao": {"w": 9.0, "L": 12.0, "dy": 0.0, "base_agua": 0.0},
	"quarto_tito": {"w": 6.5, "L": 8.0, "dy": 0.0, "base_agua": 0.0, "agua": false},
	"escada_sobe": {"w": 3.6, "L": 12.0, "dy": 3.4, "base_agua": 0.0},
}

static var _shader_pedra: Shader
static var _cache := {}


## O quarto do Tito e os slides do último dia ficam em outro arquivo (carregado só quando preciso).
static func _quarto() -> GDScript:
	if not _cache.has("quarto"):
		_cache["quarto"] = load("res://world/niveis/porao_quarto.gd")
	return _cache["quarto"]


# ============================================================================ contexto de uma sala
class Ctx:
	extends RefCounted
	var raiz: Node3D
	var tipo := ""
	var idx := 0                     # 0..18 (sala = 81 + idx)
	var sala := 81
	var rng := RandomNumberGenerator.new()
	var w := 4.0
	var L := 10.0
	var dy := 0.0
	var base_agua := 0.0
	var agua := true                 # false: o quarto do Tito não alaga
	var w_prev := 4.0
	var piso_y := 0.0                # cota local do piso na entrada
	var lamina_saida := false        # a última sala constrói a própria parede de saída (com abertura)
	var porta_aberta := true         # a porta de entrada nasce aberta (a da sala 96 nasce trancada)
	# geometria fundida
	var pedra: Malha
	var piso: Malha
	var madeira: Malha
	var papel: Malha
	var vc: Malha                    # cor de vértice, com luz
	var luz: Malha                   # cor de vértice, sem luz (chamas, vidros acesos, discos)
	var mats := {}                   # "pedra", "piso", "madeira", "papel": materiais DESTA sala (agua_y por sala)
	# o que a sala oferece ao nível
	var luzes: Array[OmniLight3D] = []
	var porta: Node3D                # a folha que desce atrás do jogador
	var porta_corpo: CollisionShape3D
	var voz := {}                    # {"pos": Vector3, "certa": bool}
	var pistas: Array = []           # {"id": String, "no": Node3D, "epocas": Array}
	var pontos := {}                 # nome -> Vector3 (locais): "figura", "saida", "costela"...
	var afogar: Area3D               # bifurcação errada
	var interativos: Array = []
	var com_costela := false
	var com_figura := false
	var ultimo := 0                  # 96..99 nas salas do último dia
	var tito_slides: Array = []      # nós de slides (Epocas ESEMDATA), só para testes
	var nos_agua_alvo := []          # nós que precisam do nível da água (ex.: "balde" boiando)
	var piso_fn := Callable()        # func(z) -> y local do piso (para a Figura reaparecer)

	func col(a: Vector3, b: Vector3) -> void:
		pedra.col(a, b)


# ============================================================================ materiais
static func _shader() -> Shader:
	if _shader_pedra == null:
		_shader_pedra = load("res://shaders/porao_pedra.gdshader") as Shader
	return _shader_pedra


static func _textura(nome: String, falsa: Callable) -> Texture2D:
	var t := Ato2Pecas.externa(nome)
	if t == null:
		t = falsa.call()
	return t


## Material de pedra do porão (shader `porao_pedra`). `tam` = metros por repetição da textura.
static func _mat_pedra(tex: Texture2D, tam: float, tom: Color, umidade: float, ao := 0.45) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader()
	m.set_shader_parameter("textura", tex)
	m.set_shader_parameter("escala", Vector3(1.0 / tam, 1.0 / tam, 1.0 / tam))
	m.set_shader_parameter("tom", tom)
	m.set_shader_parameter("umidade", umidade)
	m.set_shader_parameter("ao_forca", ao)
	return m


static func mat_vc() -> StandardMaterial3D:
	if _cache.has("vc"):
		return _cache["vc"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	_cache["vc"] = m
	return m


static func mat_luz() -> StandardMaterial3D:
	if _cache.has("luz"):
		return _cache["luz"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	_cache["luz"] = m
	return m


## Cria os materiais da sala (cópias por sala: `agua_y` e `piso_y` são só dela).
static func _materiais(c: Ctx) -> void:
	var t_parede := _textura("parede_castelinho", Ato2Pecas.tex_pedra)
	var t_piso := _textura("piso_pedra", Ato2Pecas.tex_piso_pedra)
	var t_mad := _textura("madeira_escura", Ato2Pecas.tex_madeira)
	var t_papel := _textura("reboco", Ato2Pecas.tex_reboco)
	var seco: bool = not c.agua
	c.mats["pedra"] = _mat_pedra(t_parede, 1.48, Color(0.64, 0.53, 0.52), 0.15 if seco else 0.75)
	c.mats["piso"] = _mat_pedra(t_piso, 2.0, Color(0.72, 0.68, 0.68), 0.15 if seco else 0.8, 0.3)
	c.mats["madeira"] = _mat_pedra(t_mad, 1.0, Color(1.0, 0.88, 0.78), 0.1 if seco else 0.6, 0.3)
	c.mats["papel"] = _mat_pedra(t_papel, 1.2, Color(0.82, 0.70, 0.50), 0.05, 0.25)
	# Uma Malha só por sala: ela já separa uma superfície por material (pedra, piso, madeira, papel, objetos, brilhos)
	c.pedra = MalhaGd.new()
	c.piso = c.pedra
	c.madeira = c.pedra
	c.papel = c.pedra
	c.vc = c.pedra
	c.luz = c.pedra


## Passa a cota (mundo) da água e do piso para os shaders da sala.
static func definir_agua(c: Ctx, agua_y_mundo: float, piso_y_mundo: float) -> void:
	for k in c.mats:
		var m := c.mats[k] as ShaderMaterial
		m.set_shader_parameter("agua_y", agua_y_mundo if c.agua else -1000.0)
		m.set_shader_parameter("piso_y", piso_y_mundo)


# ============================================================================ API principal
## Monta a sala `c.tipo` dentro de `c.raiz` (já adicionada à árvore pelo chamador, ou não: tanto faz).
static func construir(c: Ctx) -> void:
	var d: Dictionary = DIMS[c.tipo]
	c.w = d["w"]
	c.L = d["L"]
	c.dy = d["dy"]
	c.base_agua = d["base_agua"]
	c.agua = d.get("agua", true)
	c.piso_fn = func(_z: float) -> float: return 0.0
	_materiais(c)
	match c.tipo:
		"abobada": _abobada(c)
		"colunas": _colunas(c)
		"cisterna": _cisterna(c)
		"escada": _escada(c, false)
		"escada_sobe": _escada(c, true)
		"desenhos": _desenhos(c)
		"crianca": _crianca(c)
		"pedras": _pedras(c)
		"alagado": _alagado(c)
		"arcos": _arcos(c)
		"telefone": _telefone(c)
		"poco": _poco(c)
		"bifurcacao": _bifurcacao(c)
		"quarto_tito": _quarto().quarto(c)
	if c.ultimo > 0:
		_quarto().vinheta(c)
	_porta_entrada(c)
	_finalizar(c)


## Transforma a Malha acumulada em UM MeshInstance3D (uma superfície por material) e cria a colisão.
static func _finalizar(c: Ctx) -> void:
	c.pedra.construir_instancia(c.raiz, "Geometria")
	c.pedra.construir_colisao(c.raiz, "Colisao")


# ============================================================================ peças de geometria
static func caixa(m: Malha, mat: Material, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float,
		cor := Color.WHITE, faces := Malha.F_SEM_BASE) -> void:
	m.caixa(mat, Vector3(x0, y0, z0), Vector3(x1, y1, z1), faces, 0.0, cor)


## Caixa SÓLIDA (malha + colisão) numa das malhas da sala.
static func solida(c: Ctx, m: Malha, mat: Material, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float,
		cor := Color.WHITE) -> void:
	m.caixa(mat, Vector3(x0, y0, z0), Vector3(x1, y1, z1), Malha.F_SEM_BASE, 0.0, cor)
	c.col(Vector3(x0, y0, z0), Vector3(x1, y1, z1))


## Piso com colisão (só a face de cima visível), com uma leve variação de tom por ladrilho para quebrar a repetição.
static func piso_quad(c: Ctx, x0: float, x1: float, z0: float, z1: float, y: float, m: Malha = null, mat: Material = null) -> void:
	var mm: Malha = m if m else c.piso
	var mt: Material = mat if mat else c.mats["piso"]
	mm.caixa(mt, Vector3(x0, y - 0.5, z0), Vector3(x1, y, z1), Malha.F_PY, 0.0, Color.WHITE)
	c.col(Vector3(x0, y - 0.5, z0), Vector3(x1, y, z1))


static func teto_plano(c: Ctx, x0: float, x1: float, z0: float, z1: float, y: float, m: Malha = null, mat: Material = null) -> void:
	var mm: Malha = m if m else c.pedra
	var mt: Material = mat if mat else c.mats["pedra"]
	mm.quad(mt, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.DOWN)


## Abóbada de berço (arco abatido) entre z0 e z1: da imposta `y_imp` ao fecho `y_fecho`. Faixas de nervura opcionais.
static func abobada_berco(c: Ctx, z0: float, z1: float, y_imp: float, y_fecho: float, seg := 8, nervuras: Array = []) -> void:
	var larg := c.w
	var f := y_fecho - y_imp
	var R := (larg * larg / 4.0 + f * f) / (2.0 * f)
	var cy := y_fecho - R
	var m := c.pedra
	var mp: Material = c.mats["pedra"]
	var ys: Array[float] = []
	var xs: Array[float] = []
	for k in seg + 1:
		var x := -larg * 0.5 + larg * float(k) / seg
		xs.append(x)
		ys.append(cy + sqrt(maxf(R * R - x * x, 0.0)))
	for k in seg:
		m.quad_auto(mp, Vector3(xs[k], ys[k], z0), Vector3(xs[k + 1], ys[k + 1], z0), Vector3(xs[k + 1], ys[k + 1], z1), Vector3(xs[k], ys[k], z1), Vector3.DOWN)
	# nervuras: faixas escuras e salientes (0,06 m) coladas ao intradorso
	for zc in nervuras:
		var za: float = zc - 0.28
		var zb: float = zc + 0.28
		var cor := Color(0.66, 0.62, 0.62)
		for k in seg:
			var a := Vector3(xs[k], ys[k] - 0.07, za)
			var b := Vector3(xs[k + 1], ys[k + 1] - 0.07, za)
			var d := Vector3(xs[k], ys[k] - 0.07, zb)
			var e := Vector3(xs[k + 1], ys[k + 1] - 0.07, zb)
			m.quad_auto(mp, a, b, e, d, Vector3.DOWN, Vector2.ZERO, cor)
			# faces laterais da nervura (escurecem a borda)
			m.quad_auto(mp, Vector3(xs[k], ys[k], za), Vector3(xs[k + 1], ys[k + 1], za), b, a, Vector3(0, 0, -1), Vector2.ZERO, cor * 0.8)
			m.quad_auto(mp, Vector3(xs[k], ys[k], zb), Vector3(xs[k + 1], ys[k + 1], zb), e, d, Vector3(0, 0, 1), Vector2.ZERO, cor * 0.8)


## Faixa de uma aresta de sombra/mancha em parede ou piso (quad plano de cor) para sujeira e marcas.
static func mancha(c: Ctx, centro: Vector3, normal: Vector3, larg: float, alt: float, cor: Color) -> void:
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
	var u := normal.cross(up).normalized()
	var v := u.cross(normal).normalized()
	var p := centro + normal * 0.02
	c.vc.quad(mat_vc(), p - u * larg * 0.5 - v * alt * 0.5, p + u * larg * 0.5 - v * alt * 0.5,
		p + u * larg * 0.5 + v * alt * 0.5, p - u * larg * 0.5 + v * alt * 0.5, normal, Vector2.ZERO, cor)


# ============================================================================ casca: piso, paredes laterais, lâmina de entrada
## Opções (`o`): "h" (altura da parede reta), "topo" (altura da lâmina de entrada), "y1b" (topo inclinado: altura da
## parede na entrada; `h` vale na saída), "base" (cota da base das paredes), "esq"/"dir" (aberturas das paredes
## laterais, no formato de `Muros.ab`, com u = z absoluto), "sem_piso" (a sala monta o próprio piso).
static func casca(c: Ctx, o: Dictionary = {}) -> void:
	var w := c.w
	var L := c.L
	var h: float = o.get("h", 3.4)
	var topo: float = o.get("topo", maxf(h, o.get("y1b", h)))
	var base: float = o.get("base", minf(0.0, c.dy) - 0.5)
	var mp: Material = c.mats["pedra"]
	var opc_e := {}
	if o.has("y1b"):
		opc_e["y1b"] = o["y1b"]
	for lado in [-1, 1]:
		var abs_: Array = o.get("esq" if lado < 0 else "dir", [])
		MurosGd.muro_z(c.pedra, c.pedra, mp, mp, lado * (w * 0.5 + T), -L, 0.0, lado, T, base, h, abs_, opc_e)
	# lâmina de entrada
	var X := maxf(w, c.w_prev) * 0.5 + T
	var aber := [MurosGd.ab(0.0, PORTA_L, c.piso_y, c.piso_y + PORTA_VS, c.piso_y + PORTA_VC, "arco")]
	MurosGd.muro_x(c.pedra, c.pedra, mp, mp, T, -X, X, 1, T, base, c.piso_y + maxf(topo, PORTA_VC + 0.4), aber, {})
	if not o.get("sem_piso", false):
		piso_quad(c, -w * 0.5, w * 0.5, -L, 0.0, c.piso_y)
	if c.lamina_saida:
		var ab2 := [MurosGd.ab(0.0, PORTA_L, c.dy, c.dy + PORTA_VS, c.dy + PORTA_VC, "arco")]
		MurosGd.muro_x(c.pedra, c.pedra, mp, mp, -L, -X, X, 1, T, base, c.dy + maxf(topo, PORTA_VC + 0.4), ab2, {})


# ============================================================================ porta de entrada (a que se fecha atrás do jogador)
## Folha de tábuas com o topo em arco, encaixada na abertura da lâmina: desce (fecha) quando o jogador entra.
static func _porta_entrada(c: Ctx) -> void:
	var porta := Node3D.new()
	porta.name = "Porta"
	porta.position = Vector3(0, c.piso_y, T * 0.5)
	c.raiz.add_child(porta)
	var m: Malha = MalhaGd.new()
	var mv := mat_vc()
	# perfil do topo (arco abatido) e tábuas verticais de 0,3 m
	var pf := MurosGd.perfil("arco", -PORTA_L * 0.5 + 0.02, PORTA_L * 0.5 - 0.02, PORTA_VS, PORTA_VC)
	var n_tabuas := 8
	var larg := (PORTA_L - 0.04) / n_tabuas
	for i in n_tabuas:
		var xa := -PORTA_L * 0.5 + 0.02 + i * larg
		var xb := xa + larg
		var ya := _altura_perfil(pf, xa)
		var yb := _altura_perfil(pf, xb)
		var cor := Color(0.30, 0.20, 0.13) * (0.8 + 0.25 * float((i * 7) % 3) / 2.0)
		for lado in [1.0, -1.0]:
			var z: float = 0.12 * lado
			m.quad(mv, Vector3(xa, 0, z), Vector3(xb, 0, z), Vector3(xb, yb, z), Vector3(xa, ya, z), Vector3(0, 0, lado), Vector2.ZERO, cor)
	# faixas de ferro e o aro
	for y in [0.6, 1.8]:
		m.caixa(mv, Vector3(-PORTA_L * 0.5 + 0.02, y - 0.06, -0.14), Vector3(PORTA_L * 0.5 - 0.02, y + 0.06, 0.14), Malha.F_TODAS, 0.0, Color(0.07, 0.07, 0.08))
	m.construir_instancia(porta, "Folha")
	# colisão da porta fechada (desligada enquanto a porta está aberta)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(PORTA_L, PORTA_VC, 0.3)
	cs.shape = bs
	cs.position = Vector3(0, PORTA_VC * 0.5, 0)
	cs.disabled = c.porta_aberta
	sb.add_child(cs)
	porta.add_child(sb)
	c.porta = porta
	c.porta_corpo = cs
	porta.position.y = c.piso_y + (PORTA_VC + 0.3 if c.porta_aberta else 0.0)


static func _altura_perfil(pf: PackedVector2Array, x: float) -> float:
	for i in pf.size() - 1:
		if x >= pf[i].x - 0.0001 and x <= pf[i + 1].x + 0.0001:
			var t := (x - pf[i].x) / maxf(pf[i + 1].x - pf[i].x, 0.0001)
			return lerpf(pf[i].y, pf[i + 1].y, t)
	return pf[pf.size() - 1].y


# ============================================================================ luzes, tochas e objetos pequenos
## Suporte de ferro com chama e UMA luz (omni). `lado`: -1 parede esquerda, +1 direita, 0 solta (no centro).
static func tocha(c: Ctx, pos: Vector3, lado := 0, energia := 1.5, alcance := 8.5, cor := Color(1.0, 0.62, 0.28)) -> OmniLight3D:
	var mv := mat_vc()
	caixa(c.vc, mv, pos.x - 0.05, pos.y - 0.28, pos.z - 0.05, pos.x + 0.05, pos.y + 0.12, pos.z + 0.05, Color(0.09, 0.08, 0.07))
	caixa(c.vc, mv, pos.x - 0.12, pos.y + 0.1, pos.z - 0.12, pos.x + 0.12, pos.y + 0.18, pos.z + 0.12, Color(0.09, 0.08, 0.07))
	# chama em duas pirâmides com cor de vértice (revisão V2: antes eram brancas e pareciam facas): a de fora vai de
	# laranja na base a vermelho escuro na ponta, a de dentro de amarelo quase branco a laranja
	chama(c.luz, Vector3(pos.x, pos.y + 0.18, pos.z), 0.15, 0.36, Color(1.0, 0.55, 0.12), Color(0.75, 0.16, 0.04))
	chama(c.luz, Vector3(pos.x, pos.y + 0.18, pos.z), 0.08, 0.26, Color(1.0, 0.93, 0.62), Color(1.0, 0.6, 0.15))
	var l := OmniLight3D.new()
	l.position = pos + Vector3(-lado * 0.45, 0.45, 0.0)
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	l.set_meta("energia_base", energia)
	c.raiz.add_child(l)
	c.luzes.append(l)
	return l


## Pirâmide de 4 faces com cor de vértice da base (`cb`) à ponta (`cp`), levemente torcida (não fica "de régua").
static func chama(m: Malha, base: Vector3, w: float, h: float, cb: Color, cp: Color) -> void:
	var ap := base + Vector3(w * 0.12, h, -w * 0.08)
	var r := w * 0.5
	var p := [base + Vector3(-r, 0, -r), base + Vector3(r, 0, -r), base + Vector3(r, 0, r), base + Vector3(-r, 0, r)]
	for i in 4:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		var fora := ((a + b) * 0.5 - base)
		fora.y = 0.0
		m.tri_cores(mat_luz(), a, b, ap, fora, cb, cb, cp)


static func luz_solta(c: Ctx, pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	l.set_meta("energia_base", energia)
	c.raiz.add_child(l)
	c.luzes.append(l)
	return l


static func rotulo(c: Ctx, texto: String, pos: Vector3, rot_y: float, tam: int, cor: Color, pixel := 0.004) -> Label3D:
	var l := Construtor.rotulo(c.raiz, texto, pos, tam, cor)
	l.rotation_degrees.y = rot_y
	l.pixel_size = pixel
	l.shaded = false
	return l


## Quad com textura (desenhos de criança, cartazes) colado numa parede: `normal` aponta para o jogador.
static func quadro(c: Ctx, tex: Texture2D, pos: Vector3, normal: Vector3, larg: float, alt: float, rot_z_graus := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(larg, alt)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = m
	mi.position = pos + normal * 0.03
	mi.basis = Basis.looking_at(-normal, Vector3.UP)
	mi.rotate_object_local(Vector3.BACK, deg_to_rad(rot_z_graus))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.raiz.add_child(mi)
	return mi


# ============================================================================ desenhos do Tito (V2 §5)
## Textura do desenho `n` (1..7): a do agente Visor/UI (`assets/ui/tito/desenho_N.png`) ou, se ainda não existir, um
## rascunho em giz de cera gerado aqui (cabeça, corpo, assinatura "TITO" com o T ao contrário).
static func tex_desenho(n: int) -> Texture2D:
	var chave := "desenho_%d" % n
	if _cache.has(chave):
		return _cache[chave]
	var caminho := "res://assets/ui/tito/desenho_%d.png" % n
	var t: Texture2D = null
	if ResourceLoader.exists(caminho):
		t = load(caminho) as Texture2D
	if t == null:
		t = _rascunho(n)
	_cache[chave] = t
	return t


static func _rascunho(n: int) -> Texture2D:
	const W := 96
	const H := 72
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.93, 0.9, 0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6700 + n
	for i in 40:    # papel manchado
		img.set_pixel(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1), Color(0.86, 0.82, 0.72))
	var linha := func(a: Vector2, b: Vector2, cor: Color) -> void:
		var passos := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
		for i in passos + 1:
			var p := a.lerp(b, float(i) / passos)
			for dx in 2:
				for dy in 2:
					var x := int(p.x) + dx
					var y := int(p.y) + dy
					if x >= 0 and y >= 0 and x < W and y < H:
						img.set_pixel(x, y, cor)
	var preto := Color(0.12, 0.1, 0.12)
	var azul := Color(0.1, 0.25, 0.75)
	var verm := Color(0.8, 0.12, 0.1)
	match n:
		4, 5:    # muita água azul e um boneco pequeno no meio
			for y in range(44, H, 3):
				linha.call(Vector2(4, y), Vector2(W - 4, y + rng.randi_range(-2, 2)), azul)
			linha.call(Vector2(46, 28), Vector2(46, 42), preto)
			linha.call(Vector2(40, 33), Vector2(52, 33), preto)
		6:       # página toda preta com dois olhos
			img.fill(Color(0.05, 0.04, 0.06))
			for e in [Vector2(34, 34), Vector2(62, 34)]:
				for dx in range(-6, 7):
					for dy in range(-4, 5):
						if dx * dx / 36.0 + dy * dy / 16.0 <= 1.0:
							img.set_pixel(int(e.x) + dx, int(e.y) + dy, Color(0.95, 0.95, 0.9))
		_:       # castelo com sol e boneco palito
			linha.call(Vector2(26, 56), Vector2(26, 28), preto)
			linha.call(Vector2(26, 28), Vector2(60, 28), preto)
			linha.call(Vector2(60, 28), Vector2(60, 56), preto)
			linha.call(Vector2(26, 56), Vector2(60, 56), preto)
			linha.call(Vector2(26, 28), Vector2(26, 20), preto)
			linha.call(Vector2(60, 28), Vector2(60, 20), preto)
			for k in 5:
				linha.call(Vector2(76 + k * 2, 10), Vector2(84, 16 + k * 3), verm)
			linha.call(Vector2(72, 54), Vector2(72, 40), preto)
			linha.call(Vector2(66, 46), Vector2(78, 46), preto)
	# assinatura TITO (o T ao contrário) no canto
	linha.call(Vector2(8, 66), Vector2(16, 66), preto)
	linha.call(Vector2(12, 58), Vector2(12, 66), preto)
	return ImageTexture.create_from_image(img)


# ============================================================================ 1. corredor de abóbada
static func _abobada(c: Ctx) -> void:
	var h := 2.7
	var topo := 3.9
	casca(c, {"h": h, "topo": topo})
	var nerv := [-1.8, -5.3, -8.8, -12.3]
	abobada_berco(c, -c.L, 0.0, h, topo, 8, nerv)
	var mv := mat_vc()
	# pilastras sob as nervuras (reentrâncias das paredes)
	for z in nerv:
		for lado in [-1, 1]:
			solida(c, c.pedra, c.mats["pedra"], lado * (c.w * 0.5 - 0.22) - 0.22, 0.0, z - 0.3, lado * (c.w * 0.5 - 0.22) + 0.22, h, z + 0.3, Color(0.85, 0.82, 0.82))
	# entulho e tábuas apodrecidas encostadas nas paredes (sem bloquear)
	var r := c.rng
	for i in 5:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var z := -2.5 - i * 2.4 + r.randf_range(-0.4, 0.4)
		var s := r.randf_range(0.18, 0.4)
		caixa(c.vc, mv, lado * (c.w * 0.5 - 0.3) - s, 0.0, z - s, lado * (c.w * 0.5 - 0.3) + s, s * 1.2, z + s, Color(0.38, 0.32, 0.3) * r.randf_range(0.8, 1.1))
	for z in [-4.2, -10.0]:
		mancha(c, Vector3(-c.w * 0.5 + 0.02, 1.6, z), Vector3.RIGHT, 0.7, 2.6, Color(0.1, 0.15, 0.13, 1.0))
	tocha(c, Vector3(-c.w * 0.5 + 0.12, 1.9, -4.0), -1, 1.6, 9.0)
	tocha(c, Vector3(c.w * 0.5 - 0.12, 1.9, -10.5), 1, 1.4, 9.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 2.0)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 2. sala de colunas
static func _colunas(c: Ctx) -> void:
	var h := 4.4
	casca(c, {"h": h})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mv := mat_vc()
	var mp: Material = c.mats["pedra"]
	for fila in [-2.9, 2.9]:
		for z in [-2.6, -5.6, -8.6, -11.6]:
			solida(c, c.pedra, mp, fila - 0.45, 0.0, z - 0.45, fila + 0.45, h - 0.3, z + 0.45, Color(0.9, 0.86, 0.86))
			caixa(c.pedra, mp, fila - 0.7, 0.0, z - 0.7, fila + 0.7, 0.28, z + 0.7, Color(0.75, 0.72, 0.72))          # base
			caixa(c.pedra, mp, fila - 0.7, h - 0.62, z - 0.7, fila + 0.7, h - 0.3, z + 0.7, Color(0.75, 0.72, 0.72))   # capitel
	# vigas de madeira cruzando o teto
	var mm: Material = c.mats["madeira"]
	for z in [-2.6, -5.6, -8.6, -11.6]:
		caixa(c.madeira, mm, -c.w * 0.5, h - 0.34, z - 0.18, c.w * 0.5, h, z + 0.18, Color(0.8, 0.75, 0.7))
	# entulho no chão
	for i in 6:
		var x := c.rng.randf_range(-c.w * 0.5 + 0.6, c.w * 0.5 - 0.6)
		var z := c.rng.randf_range(-c.L + 1.0, -1.5)
		if absf(absf(x) - 2.9) < 0.9 or absf(x) < 1.0:
			continue
		var s := c.rng.randf_range(0.2, 0.45)
		caixa(c.vc, mv, x - s, 0.0, z - s, x + s, s, z + s, Color(0.36, 0.3, 0.28))
	tocha(c, Vector3(-c.w * 0.5 + 0.12, 2.0, -3.5), -1, 1.4, 11.0)
	tocha(c, Vector3(c.w * 0.5 - 0.12, 2.0, -9.5), 1, 1.2, 11.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.8)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.4, -c.L + 0.8)


# ============================================================================ 3. cisterna (passarela sobre o poço d'água)
static func _cisterna(c: Ctx) -> void:
	var h := 5.0
	var fundo := -2.6
	var half := 1.4              # meia largura da passarela
	casca(c, {"h": h, "sem_piso": true, "base": fundo - 0.3})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mp: Material = c.mats["pedra"]
	var mpi: Material = c.mats["piso"]
	# passarela (topo em y=0) e fundos dos poços
	piso_quad(c, -half, half, -c.L, 0.0, 0.0)
	for lado in [-1, 1]:
		var x0: float = half if lado > 0 else -c.w * 0.5
		var x1: float = c.w * 0.5 if lado > 0 else -half
		c.piso.caixa(mpi, Vector3(x0, fundo - 0.5, -c.L), Vector3(x1, fundo, 0.0), Malha.F_PY, 0.0, Color(0.6, 0.6, 0.6))
		c.col(Vector3(x0, fundo - 0.5, -c.L), Vector3(x1, fundo, 0.0))          # o fundo do poço tem chão: ninguém cai sem fim
		# parede lateral da passarela (voltada para o poço) e meio-fio que impede de cair
		var xe: float = lado * half
		c.pedra.quad(mp, Vector3(xe, fundo, -c.L), Vector3(xe, fundo, 0.0), Vector3(xe, 0.0, 0.0), Vector3(xe, 0.0, -c.L), Vector3(lado, 0, 0), Vector2.ZERO, Color(0.8, 0.8, 0.8))
		# (na sala 98 o meio-fio do lado direito tem uma falha de 0,8 m: é onde a passarela do último dia se apoia)
		var tem_ponte: bool = c.ultimo == 98 and lado > 0
		var segs := [[-c.L, 0.0]] if not tem_ponte else [[-c.L, -5.9], [-5.1, 0.0]]
		for sg in segs:
			c.col(Vector3(xe - 0.05 * lado - 0.1, -0.3, sg[0]), Vector3(xe + 0.1 + 0.05 * lado, 1.1, sg[1]))
			caixa(c.pedra, mp, minf(xe - 0.18, xe + 0.18), 0.0, sg[0], maxf(xe - 0.18, xe + 0.18), 0.42, sg[1], Color(0.7, 0.68, 0.68))
	# colunas saindo do fundo do poço até o teto
	for lado in [-1, 1]:
		for z in [-3.6, -7.2, -10.8]:
			var x: float = lado * 4.4
			caixa(c.pedra, mp, x - 0.5, fundo, z - 0.5, x + 0.5, h - 0.3, z + 0.5, Color(0.85, 0.82, 0.82))
			caixa(c.pedra, mp, x - 0.75, h - 0.6, z - 0.75, x + 0.75, h - 0.3, z + 0.75, Color(0.7, 0.68, 0.68))
	if c.ultimo == 98:
		_ponte_semdata(c, half, fundo)
		# quem cai pelo vão do meio-fio (sem a ponte) cai na água do poço: afogamento, como na bifurcação errada
		var area := Area3D.new()
		area.name = "AguaPoco"
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(c.w * 0.5 - half, 1.6, c.L)
		cs.shape = bs
		cs.position = Vector3((half + c.w * 0.5) * 0.5, -1.4, -c.L * 0.5)
		area.add_child(cs)
		c.raiz.add_child(area)
		c.afogar = area
	tocha(c, Vector3(-half + 0.0, 1.5, -4.5), 0, 1.5, 12.0)
	tocha(c, Vector3(half - 0.0, 1.5, -10.0), 0, 1.3, 12.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.5)
	c.pontos["voz"] = Vector3(0, 1.4, -c.L + 0.8)
	c.piso_fn = func(_z: float) -> float: return 0.0


## Sala 98: uma plataforma do outro lado de um vão de 1,4 m, no poço, com uma sandália pequena. Só o Visor com o disco
## sem data mostra a passarela de tábuas que ligava as duas margens (a passagem existe só nesse dia).
static func _ponte_semdata(c: Ctx, half: float, fundo: float) -> void:
	var mp: Material = c.mats["pedra"]
	var mv := mat_vc()
	var x0 := half + 1.4
	var x1 := x0 + 2.6
	# plataforma sobre pilar, no nível da passarela
	c.pedra.caixa(mp, Vector3(x0, fundo, -6.5), Vector3(x1, 0.0, -4.5), Malha.F_SEM_BASE, 0.0, Color(0.8, 0.78, 0.78))
	c.col(Vector3(x0, fundo, -6.5), Vector3(x1, 0.0, -4.5))
	# a sandália pequena, azul, de tira amarela (a outra do par que veio na rede da Barra)
	var sand := Node3D.new()
	sand.name = "SandaliaPorao"
	sand.position = Vector3((x0 + x1) * 0.5 + 0.4, 0.0, -5.5)
	sand.rotation_degrees.y = 30.0
	c.raiz.add_child(sand)
	var m: Malha = MalhaGd.new()
	m.caixa(mv, Vector3(-0.045, 0.0, -0.1), Vector3(0.045, 0.025, 0.1), Malha.F_SEM_BASE, 0.0, Color(0.3, 0.52, 0.9))
	m.caixa(mv, Vector3(-0.045, 0.025, -0.03), Vector3(0.045, 0.04, 0.0), Malha.F_SEM_BASE, 0.0, Color(0.95, 0.8, 0.2))
	m.construir_instancia(sand, "Sandalia")
	c.pontos["sandalia"] = sand.position + Vector3(0, 0.1, 0)
	# a passarela: só na época sem data (visual + colisão)
	var ponte := Node3D.new()
	ponte.name = "PasserelaSemData"
	c.raiz.add_child(ponte)
	var mb: Malha = MalhaGd.new()
	mb.caixa(mv, Vector3(half - 0.2, -0.12, -5.9), Vector3(x0 + 0.2, 0.0, -5.1), Malha.F_SEM_BASE, 0.0, Color(0.5, 0.34, 0.2))
	for k in 4:
		mb.caixa(mv, Vector3(half - 0.2 + k * 0.45, 0.0, -5.9), Vector3(half - 0.2 + k * 0.45 + 0.04, 0.02, -5.1), Malha.F_SEM_BASE, 0.0, Color(0.3, 0.2, 0.12))
	mb.col(Vector3(half - 0.2, -0.3, -5.9), Vector3(x0 + 0.2, 0.0, -5.1))
	mb.construir_instancia(ponte, "Tabuas")
	mb.construir_colisao(ponte, "ColisaoPonte")
	Epocas.marcar(ponte, [GameState.Epoca.ESEMDATA])
	c.pistas.append({"id": "ponte_semdata", "no": ponte, "epocas": [GameState.Epoca.ESEMDATA]})


# ============================================================================ 4. escada (desce ou sobe)
static func _escada(c: Ctx, sobe: bool) -> void:
	var dy := c.dy
	var L := c.L
	var w := c.w
	var alt := 3.4
	var z_ini := 1.6                       # patamar de entrada
	var z_fim := L - 1.6                   # início do patamar de saída
	var n := 12
	# paredes com topo inclinado, paralelo à escada
	var topo_saida := alt + dy
	casca(c, {"h": topo_saida, "y1b": alt, "sem_piso": true, "base": minf(0.0, dy) - 0.5, "topo": maxf(alt, topo_saida)})
	var mp: Material = c.mats["pedra"]
	var mpi: Material = c.mats["piso"]
	# patamares
	piso_quad(c, -w * 0.5, w * 0.5, -z_ini, 0.0, 0.0)
	piso_quad(c, -w * 0.5, w * 0.5, -L, -z_fim, dy)
	# degraus (visual) e rampa (colisão)
	var tread := (z_fim - z_ini) / n
	for i in n:
		var za := -z_ini - i * tread
		var zb := za - tread
		var y_top := dy * float(i + 1) / n
		var cor := Color(0.78, 0.74, 0.74) * (0.9 + 0.12 * float(i % 2))
		c.piso.caixa(mpi, Vector3(-w * 0.5, y_top - 0.3 if not sobe else y_top - 0.3, zb), Vector3(w * 0.5, y_top, za), Malha.F_PY | Malha.F_NZ | Malha.F_PZ, 0.0, cor)
	# a base fica abaixo do ponto mais baixo (se subisse junto com dy, o pé da rampa viraria uma parede vertical)
	var base_r := minf(0.0, dy) - 0.5
	var rampa := PackedVector3Array([
		Vector3(-w * 0.5, 0.0, -z_ini), Vector3(w * 0.5, 0.0, -z_ini), Vector3(-w * 0.5, dy, -z_fim), Vector3(w * 0.5, dy, -z_fim),
		Vector3(-w * 0.5, base_r, -z_ini), Vector3(w * 0.5, base_r, -z_ini), Vector3(-w * 0.5, base_r, -z_fim), Vector3(w * 0.5, base_r, -z_fim)])
	c.pedra.rampa(rampa)
	# teto inclinado
	c.pedra.quad_auto(mp, Vector3(-w * 0.5, alt, 0.0), Vector3(w * 0.5, alt, 0.0), Vector3(w * 0.5, topo_saida, -L), Vector3(-w * 0.5, topo_saida, -L), Vector3.DOWN)
	# corrimão de ferro de um lado
	var mv := mat_vc()
	var lado_corr := 1.0
	for i in range(0, n + 1, 3):
		var za := -z_ini - i * tread
		var y := dy * float(i) / n
		caixa(c.vc, mv, lado_corr * (w * 0.5 - 0.2) - 0.03, y, za - 0.03, lado_corr * (w * 0.5 - 0.2) + 0.03, y + 0.9, za + 0.03, Color(0.1, 0.1, 0.11))
	c.pedra.caixa(mv, Vector3(lado_corr * (w * 0.5 - 0.2) - 0.03, 0.9, -z_ini), Vector3(lado_corr * (w * 0.5 - 0.2) + 0.03, 0.96, 0.0), Malha.F_TODAS, 0.0, Color(0.1, 0.1, 0.11))
	tocha(c, Vector3(-w * 0.5 + 0.12, 2.0, -1.0), -1, 1.5, 9.0)
	if sobe:
		# luz fria do luar vinda do alto (a saída para o Braço Morto)
		luz_solta(c, Vector3(0, dy + 2.0, -L + 1.0), Color(0.55, 0.65, 0.95), 1.5, 9.0)
	else:
		tocha(c, Vector3(w * 0.5 - 0.12, dy + 1.9, -L + 2.0), 1, 1.3, 9.0)
	c.piso_fn = func(z: float) -> float:
		var u := clampf((-z - z_ini) / (z_fim - z_ini), 0.0, 1.0)
		return dy * u
	c.pontos["figura"] = Vector3(0, dy + 0.05, -L + 2.0)
	c.pontos["voz"] = Vector3(0, dy + 1.4, -L + 0.8)


# ============================================================================ 5. sala dos desenhos
static func _desenhos(c: Ctx) -> void:
	var h := 3.4
	casca(c, {"h": h})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mv := mat_vc()
	# mesinha de criança no centro, giz de cera espalhado e um banquinho
	solida(c, c.madeira, c.mats["madeira"], -0.7, 0.0, -5.4, 0.7, 0.55, -4.4, Color(0.9, 0.8, 0.7))
	solida(c, c.madeira, c.mats["madeira"], -0.4, 0.0, -3.9, 0.0, 0.3, -3.5, Color(0.8, 0.7, 0.6))
	var cores := [Color(0.85, 0.15, 0.12), Color(0.15, 0.3, 0.85), Color(0.95, 0.8, 0.15), Color(0.2, 0.65, 0.25)]
	for i in 4:
		caixa(c.vc, mv, -0.5 + i * 0.28, 0.55, -5.1 + (i % 2) * 0.2, -0.4 + i * 0.28 + 0.14, 0.58, -4.95 + (i % 2) * 0.2 + 0.03, cores[i])
	# desenhos nas paredes (de 4 a 7: V2 §5): vão ficando piores
	var rng := c.rng
	var seq := [4, 5, 6, 7, 5, 4, 6, 7]
	var pos := [
		[Vector3(-c.w * 0.5 + 0.02, 1.7, -2.2), Vector3.RIGHT], [Vector3(-c.w * 0.5 + 0.02, 1.6, -4.7), Vector3.RIGHT],
		[Vector3(-c.w * 0.5 + 0.02, 1.8, -7.3), Vector3.RIGHT], [Vector3(-c.w * 0.5 + 0.02, 1.5, -9.0), Vector3.RIGHT],
		[Vector3(c.w * 0.5 - 0.02, 1.7, -2.8), Vector3.LEFT], [Vector3(c.w * 0.5 - 0.02, 1.5, -5.3), Vector3.LEFT],
		[Vector3(c.w * 0.5 - 0.02, 1.8, -7.8), Vector3.LEFT], [Vector3(0.0, 1.8, -c.L + 0.02), Vector3.BACK]]
	for i in seq.size():
		var tam := 1.05 + rng.randf() * 0.3
		quadro(c, tex_desenho(seq[i]), pos[i][0], pos[i][1], tam, tam * 0.75, rng.randf_range(-6.0, 6.0))
	# o desenho escondido: a mulher branca na janela da torre, só aparece com o disco de 1967
	var oculto := quadro(c, tex_desenho(3), Vector3(c.w * 0.5 - 0.02, 1.2, -9.2), Vector3.LEFT, 1.1, 0.82, 3.0)
	Epocas.marcar(oculto, [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA])
	c.pistas.append({"id": "desenho_porao", "no": oculto, "epocas": [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA]})
	var nota := rotulo(c, "ELE VEM", Vector3(c.w * 0.5 - 0.03, 0.9, -9.2), 270.0, 36, Color(0.15, 0.3, 0.85, 0.9), 0.004)
	Epocas.marcar(nota, [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA])
	tocha(c, Vector3(-c.w * 0.5 + 0.12, 2.2, -3.2), -1, 1.4, 10.0)
	tocha(c, Vector3(c.w * 0.5 - 0.12, 2.2, -7.0), 1, 1.2, 10.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.5)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 6. quarto de criança dos anos 60 (impossível)
static func _crianca(c: Ctx) -> void:
	var h := 2.7
	casca(c, {"h": h, "sem_piso": true})
	# papel de parede listrado por cima da pedra: faixas verticais de tons alternados nas paredes laterais
	var mpa: Material = c.mats["papel"]
	for lado in [-1, 1]:
		var x: float = lado * (c.w * 0.5 - 0.015)
		var k := 0
		var z := 0.0
		while z > -c.L + 0.01:
			var z2 := maxf(z - 0.5, -c.L)
			var cor := Color(1, 1, 1) if k % 2 == 0 else Color(0.85, 0.78, 0.7)
			c.papel.quad(mpa, Vector3(x, 0.0, z), Vector3(x, 0.0, z2), Vector3(x, h - 0.15, z2), Vector3(x, h - 0.15, z), Vector3(-lado, 0, 0), Vector2.ZERO, cor)
			z = z2
			k += 1
	# assoalho de tábuas (madeira, não pedra): o quarto é impossível e está de pé no meio da masmorra
	c.madeira.caixa(c.mats["madeira"], Vector3(-c.w * 0.5, -0.5, -c.L), Vector3(c.w * 0.5, 0.0, 0.0), Malha.F_PY, 0.0, Color(0.9, 0.85, 0.8))
	c.col(Vector3(-c.w * 0.5, -0.5, -c.L), Vector3(c.w * 0.5, 0.0, 0.0))
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h, c.papel, mpa)
	var mv := mat_vc()
	var mm: Material = c.mats["madeira"]
	# cama de solteiro encostada na parede esquerda, com colcha desbotada
	solida(c, c.madeira, mm, -c.w * 0.5, 0.0, -5.6, -c.w * 0.5 + 0.95, 0.35, -3.2, Color(0.9, 0.8, 0.7))
	caixa(c.vc, mv, -c.w * 0.5 + 0.04, 0.35, -5.5, -c.w * 0.5 + 0.9, 0.5, -3.3, Color(0.35, 0.5, 0.65))
	caixa(c.vc, mv, -c.w * 0.5 + 0.1, 0.5, -3.7, -c.w * 0.5 + 0.8, 0.58, -3.3, Color(0.85, 0.83, 0.78))
	# baú de brinquedos, cavalinho de balanço e prateleira
	solida(c, c.madeira, mm, c.w * 0.5 - 0.7, 0.0, -2.6, c.w * 0.5, 0.45, -1.6, Color(0.7, 0.35, 0.3))
	caixa(c.vc, mv, 0.9, 0.35, -5.8, 1.4, 0.7, -5.2, Color(0.5, 0.32, 0.2))           # cavalinho: corpo
	caixa(c.vc, mv, 1.2, 0.6, -5.55, 1.55, 1.0, -5.4, Color(0.5, 0.32, 0.2))
	caixa(c.vc, mv, 0.85, 0.0, -5.85, 0.95, 0.3, -5.15, Color(0.3, 0.2, 0.12))
	caixa(c.vc, mv, 1.35, 0.0, -5.85, 1.45, 0.3, -5.15, Color(0.3, 0.2, 0.12))
	caixa(c.vc, mv, c.w * 0.5 - 0.3, 1.5, -6.6, c.w * 0.5 - 0.02, 1.56, -5.4, Color(0.4, 0.28, 0.18))
	for i in 3:
		caixa(c.vc, mv, c.w * 0.5 - 0.26, 1.56, -6.5 + i * 0.35, c.w * 0.5 - 0.1, 1.76 + (i % 2) * 0.1, -6.3 + i * 0.35, [Color(0.8, 0.2, 0.15), Color(0.2, 0.4, 0.8), Color(0.9, 0.8, 0.2)][i])
	# a "janela" pintada na parede do fundo: moldura e um céu azul falso
	caixa(c.vc, mv, -0.85, 1.0, -c.L + 0.02, 0.85, 2.25, -c.L + 0.1, Color(0.9, 0.88, 0.8))
	caixa(c.luz, mat_luz(), -0.7, 1.15, -c.L + 0.1, 0.7, 2.1, -c.L + 0.12, Color(0.35, 0.5, 0.78), Malha.F_PZ)
	# marcas de altura a lápis no batente (aparecem só no disco de 1975; "TITO 6, 7, 8, 9" e depois nada)
	var marcas := Node3D.new()
	marcas.name = "MarcasAltura"
	c.raiz.add_child(marcas)
	var mm2: Malha = MalhaGd.new()
	for i in 4:
		mm2.caixa(mat_vc(), Vector3(c.w * 0.5 - 0.03, 0.9 + i * 0.1, -0.9 - 0.0), Vector3(c.w * 0.5 - 0.0, 0.915 + i * 0.1, -0.5), Malha.F_TODAS, 0.0, Color(0.25, 0.25, 0.3))
	mm2.construir_instancia(marcas, "Riscos")
	for i in 4:
		var l := rotulo(c, "TITO %d" % (6 + i), Vector3(c.w * 0.5 - 0.04, 0.93 + i * 0.1, -0.7), 270.0, 14, Color(0.25, 0.25, 0.3), 0.0016)
		l.reparent(marcas, true)
	Epocas.marcar(marcas, [GameState.Epoca.E1975, GameState.Epoca.ESEMDATA])
	c.pistas.append({"id": "marcas_porao", "no": marcas, "epocas": [GameState.Epoca.E1975, GameState.Epoca.ESEMDATA]})
	# lâmpada de teto: luz quente de quarto (a única)
	luz_solta(c, Vector3(0, h - 0.4, -4.0), Color(1.0, 0.82, 0.55), 1.4, 8.0)
	caixa(c.luz, mat_luz(), -0.1, h - 0.3, -4.1, 0.1, h - 0.15, -3.9, Color(1.0, 0.9, 0.6), Malha.F_TODAS)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.4)
	c.pontos["voz"] = Vector3(0, 1.2, -c.L + 0.8)


# ============================================================================ 7. pedras empilhadas (zigue-zague)
static func _pedras(c: Ctx) -> void:
	var h := 4.2
	casca(c, {"h": h})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mp: Material = c.mats["pedra"]
	var mv := mat_vc()
	# três muros de blocos, cada um deixando uma passagem de 2,6 m, alternando lados
	var zs := [-3.2, -6.2, -9.2]
	for i in zs.size():
		var z: float = zs[i]
		var lado := -1.0 if i % 2 == 0 else 1.0
		var x0: float = -c.w * 0.5 if lado < 0 else -c.w * 0.5 + 2.6
		var x1: float = c.w * 0.5 - 2.6 if lado < 0 else c.w * 0.5
		var altura := 2.6 + c.rng.randf() * 0.8
		# fiadas irregulares
		var y := 0.0
		while y < altura:
			var alt_f := c.rng.randf_range(0.5, 0.8)
			var xa := x0 + c.rng.randf_range(0.0, 0.25)
			var xb := x1 - c.rng.randf_range(0.0, 0.25)
			c.pedra.caixa(mp, Vector3(xa, y, z - 0.55), Vector3(xb, y + alt_f, z + 0.55), Malha.F_SEM_BASE, 0.0, Color(0.7, 0.66, 0.66) * c.rng.randf_range(0.85, 1.1))
			y += alt_f
		c.col(Vector3(x0, 0.0, z - 0.55), Vector3(x1, altura + 0.5, z + 0.55))
	# escombros soltos
	for i in 10:
		var x := c.rng.randf_range(-c.w * 0.5 + 0.4, c.w * 0.5 - 0.4)
		var z := c.rng.randf_range(-c.L + 0.8, -0.8)
		var s := c.rng.randf_range(0.15, 0.4)
		caixa(c.vc, mv, x - s, 0.0, z - s, x + s, s * 1.1, z + s, Color(0.36, 0.31, 0.29))
	tocha(c, Vector3(-c.w * 0.5 + 0.12, 2.2, -1.6), -1, 1.4, 11.0)
	tocha(c, Vector3(c.w * 0.5 - 0.12, 2.2, -10.4), 1, 1.2, 11.0)
	c.pontos["figura"] = Vector3(-1.0, 0.05, -c.L + 1.3)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 8. corredor alagado
static func _alagado(c: Ctx) -> void:
	var h := 3.0
	var topo := 4.1
	var fundo := -0.55
	casca(c, {"h": h, "topo": topo, "sem_piso": true, "base": fundo - 0.5})
	abobada_berco(c, -c.L, 0.0, h, topo, 8, [-2.0, -5.0, -8.0, -11.0, -14.0])
	var rampa_z := 1.8
	# piso: rampa de descida, trecho afundado e rampa de subida
	var mpi: Material = c.mats["piso"]
	var w := c.w
	c.piso.caixa(mpi, Vector3(-w * 0.5, fundo - 0.5, -c.L + rampa_z), Vector3(w * 0.5, fundo, -rampa_z), Malha.F_PY, 0.0, Color(0.7, 0.7, 0.7))
	c.col(Vector3(-w * 0.5, fundo - 0.5, -c.L + rampa_z), Vector3(w * 0.5, fundo, -rampa_z))
	c.piso.quad(mpi, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, fundo, -rampa_z), Vector3(-w * 0.5, fundo, -rampa_z), Vector3.UP)
	c.piso.quad(mpi, Vector3(-w * 0.5, fundo, -c.L + rampa_z), Vector3(w * 0.5, fundo, -c.L + rampa_z), Vector3(w * 0.5, 0, -c.L), Vector3(-w * 0.5, 0, -c.L), Vector3.UP)
	c.pedra.rampa(PackedVector3Array([Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, fundo, -rampa_z), Vector3(w * 0.5, fundo, -rampa_z),
		Vector3(-w * 0.5, fundo - 0.5, 0), Vector3(w * 0.5, fundo - 0.5, 0), Vector3(-w * 0.5, fundo - 0.5, -rampa_z), Vector3(w * 0.5, fundo - 0.5, -rampa_z)]))
	c.pedra.rampa(PackedVector3Array([Vector3(-w * 0.5, 0, -c.L), Vector3(w * 0.5, 0, -c.L), Vector3(-w * 0.5, fundo, -c.L + rampa_z), Vector3(w * 0.5, fundo, -c.L + rampa_z),
		Vector3(-w * 0.5, fundo - 0.5, -c.L), Vector3(w * 0.5, fundo - 0.5, -c.L), Vector3(-w * 0.5, fundo - 0.5, -c.L + rampa_z), Vector3(w * 0.5, fundo - 0.5, -c.L + rampa_z)]))
	var mv := mat_vc()
	# vigas caídas na água e uma boia de cortiça: textura de abandono
	caixa(c.vc, mv, -1.4, fundo, -6.0, 1.0, fundo + 0.22, -5.7, Color(0.28, 0.2, 0.14))
	caixa(c.vc, mv, 0.2, fundo, -10.0, 1.8, fundo + 0.2, -9.7, Color(0.28, 0.2, 0.14))
	tocha(c, Vector3(-w * 0.5 + 0.12, 1.9, -5.0), -1, 1.3, 9.0)
	tocha(c, Vector3(w * 0.5 - 0.12, 1.9, -12.0), 1, 1.2, 9.0)
	c.piso_fn = func(z: float) -> float:
		return fundo if (z < -rampa_z and z > -c.L + rampa_z) else 0.0
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.0)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 9. galeria de arcos (como a arcada do Ato II)
static func _arcos(c: Ctx) -> void:
	var h := 3.8
	var w := c.w
	var aber := []
	for k in 4:
		aber.append(MurosGd.ab(-2.4 - k * 3.6, 2.4, 0.0, 2.6, 3.3, "arco"))
	casca(c, {"h": h, "dir": aber})
	teto_plano(c, -w * 0.5, w * 0.5, -c.L, 0.0, h)
	var mp: Material = c.mats["pedra"]
	var mv := mat_vc()
	var mm: Material = c.mats["madeira"]
	for i in 8:
		caixa(c.madeira, mm, -w * 0.5, h - 0.3, -1.2 - i * 2.0 - 0.15, w * 0.5, h, -1.2 - i * 2.0 + 0.15, Color(0.8, 0.75, 0.7))
	# as nichos atrás dos arcos: salinhas de 2,2 m de fundo, escuras, cada uma com seu entulho
	for k in 4:
		var zc: float = -2.4 - k * 3.6
		var x0 := w * 0.5 + T
		var x1 := x0 + 2.2
		c.pedra.quad(mp, Vector3(x1, 0, zc + 1.6), Vector3(x1, 0, zc - 1.6), Vector3(x1, h - 0.4, zc - 1.6), Vector3(x1, h - 0.4, zc + 1.6), Vector3.LEFT, Vector2.ZERO, Color(0.6, 0.6, 0.6))
		for s in [-1.0, 1.0]:
			c.pedra.quad(mp, Vector3(x0, 0, zc + s * 1.6), Vector3(x1, 0, zc + s * 1.6), Vector3(x1, h - 0.4, zc + s * 1.6), Vector3(x0, h - 0.4, zc + s * 1.6), Vector3(0, 0, -s), Vector2.ZERO, Color(0.6, 0.6, 0.6))
		c.piso.caixa(c.mats["piso"], Vector3(x0, -0.5, zc - 1.6), Vector3(x1, 0.0, zc + 1.6), Malha.F_PY, 0.0, Color(0.6, 0.6, 0.6))
		c.col(Vector3(x0, -0.5, zc - 1.6), Vector3(x1, 0.0, zc + 1.6))
		c.col(Vector3(x1, 0.0, zc - 1.6), Vector3(x1 + 0.3, 3.0, zc + 1.6))
		c.pedra.quad(mp, Vector3(x0, h - 0.4, zc - 1.6), Vector3(x1, h - 0.4, zc - 1.6), Vector3(x1, h - 0.4, zc + 1.6), Vector3(x0, h - 0.4, zc + 1.6), Vector3.DOWN)
		for s in [-1.0, 1.0]:
			c.col(Vector3(x0, 0.0, zc + s * 1.6 - 0.1), Vector3(x1, 3.0, zc + s * 1.6 + 0.1))
		piso_quad(c, w * 0.5, x0, zc - 1.2, zc + 1.2, 0.0)
		var e := c.rng.randf_range(0.2, 0.4)
		caixa(c.vc, mv, x0 + 0.6, 0.0, zc - e, x0 + 0.6 + e * 2.0, e * 1.3, zc + e, Color(0.34, 0.3, 0.28))
	# pegadas pequenas e molhadas: só o disco de 1967 as mostra (uma pista)
	var pegadas := Node3D.new()
	pegadas.name = "Pegadas"
	c.raiz.add_child(pegadas)
	var mp2: Malha = MalhaGd.new()
	for i in 8:
		var z := -2.0 - i * 1.7
		var x := 0.35 if i % 2 == 0 else -0.35
		mp2.quad(mat_luz(), Vector3(x - 0.09, 0.03, z), Vector3(x + 0.09, 0.03, z), Vector3(x + 0.09, 0.03, z - 0.22), Vector3(x - 0.09, 0.03, z - 0.22), Vector3.UP, Vector2.ZERO, Color(0.35, 0.65, 0.95))
	mp2.construir_instancia(pegadas, "Pegadas")
	Epocas.marcar(pegadas, [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA])
	c.pistas.append({"id": "pegadas_porao", "no": pegadas, "epocas": [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA]})
	tocha(c, Vector3(-w * 0.5 + 0.12, 2.3, -3.5), -1, 1.5, 11.0)
	tocha(c, Vector3(-w * 0.5 + 0.12, 2.3, -11.5), -1, 1.3, 11.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.5)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 10. sala do telefone
static func _telefone(c: Ctx) -> void:
	var h := 2.9
	casca(c, {"h": h})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mv := mat_vc()
	var mm: Material = c.mats["madeira"]
	# mesa de escritório com o telefone preto de disco; cadeira caída; calendário na parede
	solida(c, c.madeira, mm, -1.1, 0.0, -4.6, 1.1, 0.78, -3.6, Color(0.85, 0.75, 0.7))
	caixa(c.vc, mv, -0.3, 0.78, -4.3, 0.3, 0.92, -3.95, Color(0.05, 0.05, 0.06))
	caixa(c.vc, mv, -0.34, 0.9, -4.35, 0.34, 0.96, -4.2, Color(0.07, 0.07, 0.08))
	caixa(c.vc, mv, 0.7, 0.0, -3.1, 1.2, 0.5, -2.6, Color(0.3, 0.2, 0.14))
	caixa(c.vc, mv, 0.7, 0.5, -3.1, 1.2, 0.58, -2.6, Color(0.3, 0.2, 0.14))
	# calendário: MARÇO 1967 com o 12 circulado (a data do PROCURA-SE)
	caixa(c.vc, mv, -0.45, 1.3, -c.L + 0.03, 0.45, 1.95, -c.L + 0.06, Color(0.92, 0.9, 0.82))
	rotulo(c, "MARÇO 1967", Vector3(0, 1.88, -c.L + 0.075), 0.0, 22, Color(0.5, 0.1, 0.1), 0.0025).rotation_degrees.y = 0.0
	rotulo(c, "12", Vector3(0.1, 1.6, -c.L + 0.075), 0.0, 40, Color(0.8, 0.1, 0.1), 0.0025)
	# o telefone toca e a mãe fala (interativo, criado pelo nível: precisa do `usado`)
	c.pontos["telefone"] = Vector3(0, 0.95, -4.1)
	luz_solta(c, Vector3(0, h - 0.3, -3.6), Color(1.0, 0.78, 0.5), 1.3, 7.0)
	caixa(c.luz, mat_luz(), -0.08, h - 0.2, -3.68, 0.08, h - 0.08, -3.52, Color(1.0, 0.85, 0.55), Malha.F_TODAS)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.0)
	c.pontos["costela"] = Vector3(0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.3, -c.L + 0.8)


# ============================================================================ 11. poço
static func _poco(c: Ctx) -> void:
	var h := 4.6
	casca(c, {"h": h})
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mp: Material = c.mats["pedra"]
	var mv := mat_vc()
	var zc := -5.5
	var r := 1.6
	# meio-fio do poço (4 muretas de 0,9 m, com colisão alta) e a boca escura
	solida(c, c.pedra, mp, -r, 0.0, zc - r, r, 0.95, zc - r + 0.45, Color(0.8, 0.78, 0.78))
	solida(c, c.pedra, mp, -r, 0.0, zc + r - 0.45, r, 0.95, zc + r, Color(0.8, 0.78, 0.78))
	solida(c, c.pedra, mp, -r, 0.0, zc - r + 0.45, -r + 0.45, 0.95, zc + r - 0.45, Color(0.8, 0.78, 0.78))
	solida(c, c.pedra, mp, r - 0.45, 0.0, zc - r + 0.45, r, 0.95, zc + r - 0.45, Color(0.8, 0.78, 0.78))
	c.col(Vector3(-r, 0.0, zc - r), Vector3(r, 1.6, zc + r))
	c.pedra.quad(mp, Vector3(-r + 0.45, 0.95, zc - r + 0.45), Vector3(r - 0.45, 0.95, zc - r + 0.45), Vector3(r - 0.45, 0.95, zc + r - 0.45), Vector3(-r + 0.45, 0.95, zc + r - 0.45), Vector3.UP, Vector2.ZERO, Color(0.02, 0.03, 0.03))
	caixa(c.luz, mat_luz(), -r + 0.45, 0.6, zc - r + 0.45, r - 0.45, 0.62, zc + r - 0.45, Color(0.04, 0.12, 0.14), Malha.F_PY)
	# viga com roldana e um balde vermelho pendurado (o balde do Tito)
	caixa(c.madeira, c.mats["madeira"], -r - 0.2, 3.2, zc - 0.12, r + 0.2, 3.5, zc + 0.12, Color(0.8, 0.72, 0.66))
	caixa(c.vc, mv, -0.02, 1.6, zc - 0.02, 0.02, 3.2, zc + 0.02, Color(0.55, 0.45, 0.3))
	caixa(c.vc, mv, -0.17, 1.1, zc - 0.17, 0.17, 1.6, zc + 0.17, Color(0.8, 0.12, 0.1))
	for lado in [-1, 1]:
		caixa(c.pedra, mp, lado * (r + 0.2) - 0.1, 0.0, zc - 0.1, lado * (r + 0.2) + 0.1, 3.5, zc + 0.1, Color(0.75, 0.72, 0.72))
	# a mão pequena na borda, só no disco de 1967 (uma pista)
	var mao := rotulo(c, "✋", Vector3(0, 0.96, zc + r - 0.2), 0.0, 40, Color(0.35, 0.65, 0.95, 0.9), 0.004)
	mao.rotation_degrees.x = -90.0
	Epocas.marcar(mao, [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA])
	c.pistas.append({"id": "mao_poco", "no": mao, "epocas": [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA]})
	luz_solta(c, Vector3(0, 0.5, zc), Color(0.3, 0.55, 0.65), 1.2, 6.0)     # brilho frio vindo do poço
	tocha(c, Vector3(-c.w * 0.5 + 0.12, 2.4, -2.0), -1, 1.3, 10.0)
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.4)
	c.pontos["costela"] = Vector3(-3.0, 0.0, -c.L * 0.5)
	c.pontos["voz"] = Vector3(0, 1.4, -c.L + 2.4)      # no caminho da saída, no chão fora da mureta (não sobre o poço)


# ============================================================================ 12. bifurcação (a sala da voz)
## A saída é em frente. Numa parede lateral há uma passagem que desce para a água funda: a voz do Tito vem dela
## (`c.voz["certa"] == false`) ou da saída (`certa == true`). Afundar na passagem = afogamento.
static func _bifurcacao(c: Ctx) -> void:
	var h := 3.6
	var lado: int = c.pontos.get("lado_armadilha", 1)
	var zc := -8.2
	var aber := [MurosGd.ab(zc, 2.2, 0.0, 2.4, 3.0, "arco")]
	var op := {"h": h}
	op["esq" if lado < 0 else "dir"] = aber
	casca(c, op)
	teto_plano(c, -c.w * 0.5, c.w * 0.5, -c.L, 0.0, h)
	var mp: Material = c.mats["pedra"]
	var mpi: Material = c.mats["piso"]
	var mv := mat_vc()
	# colunas baixas e arcos cegos dão ritmo à sala; o corredor lateral é estreito e desce
	for z in [-3.0, -6.0, -9.5]:
		for s in [-1, 1]:
			if s == lado and absf(z - zc) < 2.0:
				continue
			solida(c, c.pedra, mp, s * (c.w * 0.5 - 0.5) - 0.3, 0.0, z - 0.3, s * (c.w * 0.5 - 0.5) + 0.3, h - 0.2, z + 0.3, Color(0.85, 0.82, 0.82))
	# corredor lateral (a armadilha): 2,4 m de largura, 5 m de comprimento, rampa que mergulha
	var x0: float = lado * (c.w * 0.5 + T)
	var comp := 5.0
	var x1: float = x0 + lado * comp
	var xa := minf(x0, x1)
	var xb := maxf(x0, x1)
	var zl := zc - 1.1
	var zr := zc + 1.1
	var fund := -1.9
	# paredes e teto do corredor
	for zz in [zl, zr]:
		var s2 := -1.0 if zz == zl else 1.0
		c.pedra.quad(mp, Vector3(xa, fund - 0.5, zz), Vector3(xb, fund - 0.5, zz), Vector3(xb, 2.8, zz), Vector3(xa, 2.8, zz), Vector3(0, 0, -s2), Vector2.ZERO, Color(0.7, 0.7, 0.7))
		c.col(Vector3(xa, fund - 0.5, zz - 0.2), Vector3(xb, 2.8, zz + 0.2))
	c.pedra.quad(mp, Vector3(xa, 2.8, zl), Vector3(xb, 2.8, zl), Vector3(xb, 2.8, zr), Vector3(xa, 2.8, zr), Vector3.DOWN, Vector2.ZERO, Color(0.7, 0.7, 0.7))
	c.pedra.quad(mp, Vector3(x1, fund - 0.5, zl), Vector3(x1, fund - 0.5, zr), Vector3(x1, 2.8, zr), Vector3(x1, 2.8, zl), Vector3(-lado, 0, 0), Vector2.ZERO, Color(0.5, 0.5, 0.5))
	c.col(Vector3(x1 - 0.2, fund - 0.5, zl), Vector3(x1 + 0.2, 2.8, zr))
	# piso: patamar de 1,4 m, rampa até o fundo (lâmina d'água escura sobe até aqui), resto submerso
	var xp := x0 + lado * 1.4
	var xq := x0 + lado * 3.4
	var xw: float = lado * c.w * 0.5      # o piso já começa na face interna da parede (sob a espessura)
	c.piso.quad(mpi, Vector3(xw, 0, zl), Vector3(xp, 0, zl), Vector3(xp, 0, zr), Vector3(xw, 0, zr), Vector3.UP)
	c.col(Vector3(minf(xw, xp), -0.5, zl), Vector3(maxf(xw, xp), 0.0, zr))
	c.piso.quad(mpi, Vector3(xp, 0, zl), Vector3(xq, fund, zl), Vector3(xq, fund, zr), Vector3(xp, 0, zr), Vector3.UP, Vector2.ZERO, Color(0.7, 0.7, 0.7))
	c.pedra.rampa(PackedVector3Array([Vector3(xp, 0, zl), Vector3(xp, 0, zr), Vector3(xq, fund, zl), Vector3(xq, fund, zr),
		Vector3(xp, fund - 0.5, zl), Vector3(xp, fund - 0.5, zr), Vector3(xq, fund - 0.5, zl), Vector3(xq, fund - 0.5, zr)]))
	c.piso.caixa(mpi, Vector3(minf(xq, x1), fund - 0.5, zl), Vector3(maxf(xq, x1), fund, zr), Malha.F_PY, 0.0, Color(0.5, 0.5, 0.5))
	c.col(Vector3(minf(xq, x1), fund - 0.5, zl), Vector3(maxf(xq, x1), fund, zr))
	# água preta ocupando a parte funda do corredor (um quad escuro, sem luz, na cota -0,35)
	c.luz.quad(mat_luz(), Vector3(xp, -0.35, zl), Vector3(x1, -0.35, zl), Vector3(x1, -0.35, zr), Vector3(xp, -0.35, zr), Vector3.UP, Vector2.ZERO, Color(0.01, 0.03, 0.035))
	# o gatilho do afogamento: a água já passa da cintura aqui
	var area := Area3D.new()
	area.name = "AguaFunda"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(absf(x1 - xq), 2.4, zr - zl)
	cs.shape = bs
	cs.position = Vector3((x1 + xq) * 0.5, fund + 1.2, zc)
	area.add_child(cs)
	c.raiz.add_child(area)
	c.afogar = area
	# luz fraca fria no fundo do corredor: chama a atenção (a armadilha é bonita)
	luz_solta(c, Vector3(x0 + lado * 2.2, 1.7, zc), Color(0.45, 0.75, 0.85), 1.1, 5.0)
	tocha(c, Vector3(-lado * (c.w * 0.5 - 0.12), 2.2, -3.5), -lado, 1.4, 11.0)
	var certa: bool = c.voz.get("certa", true)
	c.voz = {"pos": Vector3(x0 + lado * 3.6, 0.9, zc) if not certa else Vector3(0, 1.3, -c.L + 0.8), "certa": certa}
	c.pontos["figura"] = Vector3(0, 0.05, -c.L + 1.5)
	c.pontos["armadilha"] = Vector3(x0 + lado * 1.0, 0.0, zc)
