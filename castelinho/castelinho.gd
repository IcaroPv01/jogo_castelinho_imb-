class_name Castelinho
extends Node3D
## Gerador paramétrico do Castelinho de Imbé (Casa de Cultura e Museu), construído inteiro por código.
##
## Uso:
##   var c := Castelinho.new()
##   add_child(c)              # _ready() chama construir()
##
## - Lê castelinho/medidas.json (coordenadas do Godot: x = leste, z = sul, y = altura).
## - Junta a geometria estática por material (classe Malha): poucas MeshInstance3D, colisão em caixas.
## - Camadas de tempo via Epocas.marcar: casa completa (1975/2019/2020), museu (2020), núcleo (1950),
##   ruína (2019), mobília de 1975, obra de 1967 (ObraCastelinho). Nós não marcados existem em todas as épocas.
## - Malhas internas ficam na camada visual 2 (o Sol, cull_mask = 1, não as ilumina: só luz ambiente
##   e as luzes quentes de dentro). Malhas externas ficam na camada 1.
## - Detalhes de layout em castelinho/LEIAME.md.

const ARQ_MEDIDAS := "res://castelinho/medidas.json"
const T := 0.40            # espessura de parede externa
const TI := 0.22           # espessura de parede interna
const Y_LAJE := 3.5        # topo das lajes/terraços (arcada, pátio, corredor)
const Y_TETO := 3.2        # forro dos cômodos sob a laje
const Y_TETO_CORPO := 3.9  # forro do corpo principal (pé-direito alto, beiral a 4,2 m)
const Y_TORRE_PISO2 := 3.5
const Y_TORRE_TERRACO := 6.5
const TAMANHO_TEXTURA_PAREDE := Vector3(1.48, 1.485, 1.48)

static var medidas := {}
static var _cache := {}


class Grupo:
	extends RefCounted
	var nome := ""
	var epocas: Array = []
	var ext := Malha.new()      # faces voltadas para fora (camada 1: recebem o Sol)
	var inte := Malha.new()     # faces de dentro (camada 2: sem Sol)
	var col_sempre := Malha.new()   # colisão ELEVADA (lajes e parapetos de terraço): fica ligada em todas as épocas,
									# então em 1950 quem está no topo da torre flutua sobre o chão de areia (sala 17)
	var idx_ext := {}
	var idx_int := {}
	var no: Node3D
	var mi_ext: MeshInstance3D
	var mi_int: MeshInstance3D

	func _init(n: String, e: Array) -> void:
		nome = n
		epocas = e
		for par in [[ext, "/ext"], [inte, "/int"], [col_sempre, "/col_sempre"]]:   # rótulos do registro (ver malha.gd)
			(par[0] as Malha).rotulo = n + par[1]
			(par[0] as Malha).epocas = e

	func finalizar(pai: Node3D) -> void:
		no = Node3D.new()
		no.name = nome
		pai.add_child(no)
		mi_ext = ext.construir_instancia(no, "Ext", 1, idx_ext)
		mi_int = inte.construir_instancia(no, "Int", 2, idx_int)
		var c := Malha.new()
		c.colisoes = ext.colisoes + inte.colisoes
		c.convexas = ext.convexas + inte.convexas
		c.construir_colisao(no, "Col")
		if not epocas.is_empty():
			Epocas.marcar(no, epocas)
		if not col_sempre.colisoes.is_empty():
			col_sempre.construir_colisao(pai, nome + "_ColSempre")

	func triangulos() -> int:
		return ext.triangulos + inte.triangulos


var m := {}                    # materiais (nome -> Material)
var g_base: Grupo              # casa completa: existe em 1975, 2019 e 2020
var g_museu: Grupo             # só 2020: vidros, deck, hortênsias, letreiros, cerca de corda
var g_1975: Grupo              # só 1975: arcos abertos, mobília de veraneio
var g_2019: Grupo              # só 2019: ruína (telhado quebrado, mato)
var g_1950: Grupo              # só 1950: núcleo original de pedra
var g_1967: Grupo              # só 1967: o Castelinho em obra (castelinho/obra.gd, licença criativa)
var obra := {}                 # dados da obra para o nível: volumes (sombras), tito_pos, buraco_pos
var porta_entrada: Node3D      # porta de vidro do arco de entrada (E2020); o nível a abre na sala 6
var luzes: Array = []          # pontos de luz internos [{pos, sala}]: o nível cria no máximo ~5 OmniLight3D ativas
var construido := false
var triangulos_total := 0


static func carregar_medidas() -> Dictionary:
	if medidas.is_empty():
		var f := FileAccess.open(ARQ_MEDIDAS, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if typeof(d) == TYPE_DICTIONARY:
				medidas = d
		if medidas.is_empty():
			# a exportação web não empacota castelinho/medidas.json (fora do include_filter): usa a cópia embutida
			medidas = MedidasEmbutidas.DADOS.duplicate(true)
	return medidas


static func ep_casa() -> Array:
	return [GameState.Epoca.E1975, GameState.Epoca.E2019, GameState.Epoca.E2020]


func _ready() -> void:
	if not construido:
		construir()


func construir() -> void:
	construido = true
	carregar_medidas()
	_criar_materiais()
	g_base = Grupo.new("Casa", ep_casa())
	g_museu = Grupo.new("Museu_2020", [GameState.Epoca.E2020])
	g_1975 = Grupo.new("Veraneio_1975", [GameState.Epoca.E1975])
	g_2019 = Grupo.new("Ruina_2019", [GameState.Epoca.E2019])
	g_1950 = Grupo.new("Nucleo_1950", [GameState.Epoca.E1950])
	g_1967 = Grupo.new("Obra_1967", [GameState.Epoca.E1967])
	CascoCastelinho.construir(self)
	InteriorCastelinho.construir(self)
	ExtrasCastelinho.construir(self)
	obra = ObraCastelinho.construir(self)
	for g in [g_base, g_museu, g_1975, g_2019, g_1950, g_1967]:
		g.finalizar(self)
		triangulos_total += g.triangulos()
	if not GameState.epoca_mudou.is_connected(_on_epoca):
		GameState.epoca_mudou.connect(_on_epoca)
	_on_epoca(GameState.epoca)


## 2019: a parede ganha musgo e manchas (troca só o material da superfície-base, sem refazer a malha).
func _on_epoca(e: int) -> void:
	var ruina: bool = e == GameState.Epoca.E2019
	for par in [[g_base.mi_ext, g_base.idx_ext], [g_base.mi_int, g_base.idx_int], [g_1950.mi_ext, g_1950.idx_ext]]:
		var mi: MeshInstance3D = par[0]
		if mi == null:
			continue
		if par[1].has(m.parede_base):
			mi.mesh.surface_set_material(par[1][m.parede_base], m.parede_musgo if ruina else m.parede_base)
		if par[1].has(m.parede_int_base):
			mi.mesh.surface_set_material(par[1][m.parede_int_base], m.parede_int_musgo if ruina else m.parede_int_base)


# ---------------------------------------------------------------- materiais
static func _tex(nome: String) -> Texture2D:
	var p := "res://assets/textures/%s.png" % nome
	return load(p) if ResourceLoader.exists(p) else null


## Material com mapeamento triplanar de mundo (paredes/pisos: não precisam de UV). `tam` = metros por repetição.
## Com `cor` diferente de branco devolve uma variante que a Malha funde no material-base (cor de vértice).
static func mat_tri(nome: String, tam: Vector3, cor := Color.WHITE, rug := 0.95) -> StandardMaterial3D:
	var chave := "tri|%s|%s" % [nome, tam]
	var base: StandardMaterial3D
	if _cache.has(chave):
		base = _cache[chave]
	else:
		base = StandardMaterial3D.new()
		base.roughness = rug
		var t := _tex(nome)
		if t:
			base.albedo_texture = t
		base.uv1_triplanar = true
		base.uv1_world_triplanar = true
		base.uv1_scale = Vector3(1.0 / tam.x, 1.0 / tam.y, 1.0 / tam.z)
		base.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		base.vertex_color_use_as_albedo = true
		_cache[chave] = base
	if cor == Color.WHITE:
		return base
	var k2 := "%s|%s" % [chave, cor.to_html()]
	if _cache.has(k2):
		return _cache[k2]
	var v := base.duplicate() as StandardMaterial3D
	v.albedo_color = cor
	v.set_meta("vc_base", base)
	v.set_meta("vc", cor)
	_cache[k2] = v
	return v


## Parede de blocos (shaders/parede_tri.gdshader): triplanar de mundo + oclusão falsa no pé da parede.
## Mesma convenção de mat_tri: com `cor` diferente de branco devolve uma variante fundida por cor de vértice.
static func mat_parede(nome: String, tam: Vector3, cor := Color.WHITE, ao_forca := 0.36, ao_altura := 1.5) -> Material:
	var chave := "parede|%s|%s|%s|%s" % [nome, tam, ao_forca, ao_altura]
	var base: ShaderMaterial
	if _cache.has(chave):
		base = _cache[chave]
	else:
		base = ShaderMaterial.new()
		base.shader = preload("res://shaders/parede_tri.gdshader")
		var t := _tex(nome)
		if t:
			base.set_shader_parameter("textura", t)
		base.set_shader_parameter("escala", Vector3(1.0 / tam.x, 1.0 / tam.y, 1.0 / tam.z))
		base.set_shader_parameter("ao_forca", ao_forca)
		base.set_shader_parameter("ao_altura", ao_altura)
		_cache[chave] = base
	if cor == Color.WHITE:
		return base
	var k2 := "%s|%s" % [chave, cor.to_html()]
	if _cache.has(k2):
		return _cache[k2]
	var v := base.duplicate() as ShaderMaterial
	v.set_shader_parameter("tom", cor)
	v.set_meta("vc_base", base)
	v.set_meta("vc", cor)
	_cache[k2] = v
	return v


## Material com UV explícita (telhados, forro, portas, letreiros).
static func mat_uv(nome: String, cor := Color.WHITE, rug := 0.95, alfa := "", dupla := false) -> StandardMaterial3D:
	var chave := "uv|%s|%s|%s|%s" % [nome, cor.to_html(), alfa, dupla]
	if _cache.has(chave):
		return _cache[chave]
	var mt := StandardMaterial3D.new()
	mt.albedo_color = cor
	mt.roughness = rug
	var t := _tex(nome) if nome != "" else null
	if t:
		mt.albedo_texture = t
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if alfa == "scissor":
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mt.alpha_scissor_threshold = 0.5
	elif alfa == "blend":
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if dupla:
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[chave] = mt
	return mt


## Material de cor lisa. Todas as cores iguais em transparência/dupla face viram uma só superfície (cor de vértice).
static func mat_cor(cor: Color, rug := 0.9, dupla := false) -> StandardMaterial3D:
	var chave := "cor|%s|%s|%s" % [cor.to_html(true), rug, dupla]
	if _cache.has(chave):
		return _cache[chave]
	var alfa := cor.a < 0.99
	var kb := "vcbase|%s|%s" % [alfa, dupla]
	var base: StandardMaterial3D
	if _cache.has(kb):
		base = _cache[kb]
	else:
		base = StandardMaterial3D.new()
		base.roughness = rug
		base.vertex_color_use_as_albedo = true
		if alfa:
			base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if dupla:
			base.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[kb] = base
	var mt := base.duplicate() as StandardMaterial3D
	mt.albedo_color = cor
	mt.set_meta("vc_base", base)
	mt.set_meta("vc", cor)
	_cache[chave] = mt
	return mt


## Brilho sem sombreamento (lâmpadas, brasas, tochas): uma só superfície com cor de vértice.
## Vidro translúcido de duas faces com emissão (desligada = preta). Um material por instância do prédio.
static func mat_vidro(cor: Color, rug: float) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = cor
	mt.roughness = rug
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.emission_enabled = true
	mt.emission = Color.BLACK
	return mt


static func mat_luz(cor: Color, _energia := 1.6) -> StandardMaterial3D:
	var chave := "luz|%s" % cor.to_html()
	if _cache.has(chave):
		return _cache[chave]
	var base: StandardMaterial3D
	if _cache.has("luzbase"):
		base = _cache["luzbase"]
	else:
		base = StandardMaterial3D.new()
		base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		base.vertex_color_use_as_albedo = true
		_cache["luzbase"] = base
	var mt := base.duplicate() as StandardMaterial3D
	mt.albedo_color = cor
	mt.set_meta("vc_base", base)
	mt.set_meta("vc", cor)
	_cache[chave] = mt
	return mt


func _criar_materiais() -> void:
	m = {
		# todas as variantes da parede compartilham UMA superfície (cor de vértice); em 2019 a base troca por musgo
		# interior: textura própria (blocos mais claros, junta cinza grossa, como nas fotos de dentro)
		"parede_base": mat_parede("parede_castelinho", TAMANHO_TEXTURA_PAREDE),
		"parede_musgo": mat_parede("parede_castelinho_musgo", TAMANHO_TEXTURA_PAREDE),
		"parede_int_base": mat_parede("parede_interna", TAMANHO_TEXTURA_PAREDE, Color.WHITE, 0.3, 1.0),
		"parede_int_musgo": mat_parede("parede_castelinho_musgo", TAMANHO_TEXTURA_PAREDE, Color.WHITE, 0.3, 1.0),
		"parede": mat_parede("parede_castelinho", TAMANHO_TEXTURA_PAREDE, Color(0.97, 0.97, 0.97)),
		"parede_int": mat_parede("parede_interna", TAMANHO_TEXTURA_PAREDE, Color(1.0, 0.94, 0.88), 0.3, 1.0),
		"parede_1950": mat_parede("parede_nucleo", TAMANHO_TEXTURA_PAREDE, Color(0.97, 0.97, 0.97)),
		"tabuas": mat_uv("tabuas_claras"),
		"parede_sombra": mat_parede("parede_castelinho", TAMANHO_TEXTURA_PAREDE, Color(0.36, 0.3, 0.29)),
		"parede_clara": mat_parede("parede_castelinho", TAMANHO_TEXTURA_PAREDE),
		"piso": mat_tri("piso_pedra", Vector3(2.0, 2.0, 2.0), Color(1.0, 0.96, 0.92)),
		"reboco": mat_tri("reboco", Vector3(2.0, 2.0, 2.0)),
		"laje": mat_tri("reboco", Vector3(2.0, 2.0, 2.0), Color(0.72, 0.72, 0.7)),
		"madeira": mat_tri("madeira_escura", Vector3(1.0, 1.0, 1.0)),
		"forro": mat_uv("forro_madeira", Color(0.82, 0.78, 0.74)),
		"porta": mat_uv("madeira_porta"),
		"fibro": mat_uv("fibrocimento"),
		"telha": mat_uv("telha_escura"),
		"grade": mat_uv("grade_losango", Color.WHITE, 0.6, "scissor", true),
		"veneziana": mat_uv("veneziana", Color.WHITE, 0.9, "scissor", true),
		"letreiro": mat_uv("letreiro_castelinho", Color.WHITE, 0.5, "blend", true),
		# vidros com material próprio (sem cor de vértice) e emissão já ligada em preto: na visita 3 o nível acende as
		# janelas vistas de fora trocando só a cor da emissão (sem recompilar shader). Revisão V2.
		"vidro": mat_vidro(Color(0.55, 0.72, 0.78, 0.26), 0.1),
		"vidro_verde": mat_vidro(Color(0.35, 0.55, 0.4, 0.7), 0.2),
		"vidro_ambar": mat_vidro(Color(0.95, 0.7, 0.2, 0.8), 0.2),
		"ferro": mat_cor(Color(0.1, 0.1, 0.11), 0.5),
		"escuro": mat_cor(Color(0.04, 0.035, 0.035), 1.0, true),
		"luz": mat_luz(Color(1.0, 0.88, 0.62), 1.4),
		"mural": mat_uv("mural_pescador", Color.WHITE, 1.0),
		"deck": mat_uv("deck_madeira"),
		"branco": mat_cor(Color(0.92, 0.92, 0.9), 0.9),
		"bordo": mat_cor(Color(0.45, 0.1, 0.16), 0.9),
		"verde_folha": mat_cor(Color(0.22, 0.42, 0.2), 1.0),
		"flor_azul": mat_cor(Color(0.45, 0.55, 0.9), 1.0),
		"flor_branca": mat_cor(Color(0.88, 0.9, 0.92), 1.0),
		"flor_rosa": mat_cor(Color(0.85, 0.5, 0.7), 1.0),
		"corda": mat_cor(Color(0.82, 0.74, 0.55), 1.0, true),
	}


# ---------------------------------------------------------------- ajudantes de construção
## [Malha, Material] do lado "ext" (voltado ao Sol) ou "int" (interior).
func sel(g: Grupo, lado: String, mat_ext_alt: Material = null) -> Array:
	if lado == "ext":
		return [g.ext, mat_ext_alt if mat_ext_alt else m.parede]
	return [g.inte, mat_ext_alt if mat_ext_alt else m.parede_int]


## Parede ao longo de X (z fixo). `a`<`b`. fora: +1 = face "e" voltada para +z.
func parede_x(g: Grupo, z_ext: float, a: float, b: float, fora: int, y0: float, y1: float, ab: Array = [],
		lado_e := "ext", lado_i := "int", opc: Dictionary = {}, t := T) -> void:
	var se := sel(g, lado_e, opc.get("mat_e"))
	var si := sel(g, lado_i, opc.get("mat_i"))
	Muros.muro_x(se[0], si[0], se[1], si[1], z_ext, a, b, fora, t, y0, y1, ab, opc)


func parede_z(g: Grupo, x_ext: float, a: float, b: float, fora: int, y0: float, y1: float, ab: Array = [],
		lado_e := "ext", lado_i := "int", opc: Dictionary = {}, t := T) -> void:
	var se := sel(g, lado_e, opc.get("mat_e"))
	var si := sel(g, lado_i, opc.get("mat_i"))
	Muros.muro_z(se[0], si[0], se[1], si[1], x_ext, a, b, fora, t, y0, y1, ab, opc)


static func pt(o: Vector3, u: Vector3, n: Vector3, uu: float, y: float, prof := 0.0) -> Vector3:
	return o + u * uu + Vector3(0, y, 0) - n * prof


## Caixa alinhada a uma parede: u de u0 a u1, s de s0 a s1 (para fora = +), y de y0 a y1.
func caixa_u(ma: Malha, mat: Material, o: Vector3, u: Vector3, n: Vector3, u0: float, u1: float, s0: float, s1: float,
		y0: float, y1: float, faces := Malha.F_TODAS, uv_tam := 0.0) -> void:
	var a := o + u * u0 + n * s0 + Vector3(0, y0, 0)
	var b := o + u * u1 + n * s1 + Vector3(0, y1, 0)
	ma.caixa(mat, a, b, faces, uv_tam)


## Cornija de mísulas: capa contínua + fileira de blocos salientes sob o topo `topo` (projeção para fora).
## Sem sombras dinâmicas na web, o fundo entre as mísulas é pintado mais escuro para a faixa "ler" como na foto.
func cornija(g: Grupo, o: Vector3, u: Vector3, n: Vector3, L: float, topo: float, ext_ini := true, ext_fim := true) -> void:
	var cd: Dictionary = medidas.get("cornija", {})
	var proj: float = cd.get("projecao", 0.13)
	var capa: float = cd.get("capa", 0.135)
	var faixa: float = cd.get("altura_faixa", 0.405) - capa
	var passo: float = cd.get("passo_misulas", 0.30)
	var larg: float = cd.get("largura_misula", 0.15)
	var mat: Material = m.parede
	var y_a := topo - capa - faixa
	var y_b := topo - capa
	g.ext.quad(m.parede_sombra, pt(o, u, n, 0.0, y_a, -0.006), pt(o, u, n, L, y_a, -0.006), pt(o, u, n, L, y_b, -0.006), pt(o, u, n, 0.0, y_b, -0.006), n)
	caixa_u(g.ext, mat, o, u, n, -proj if ext_ini else 0.0, L + (proj if ext_fim else 0.0), 0.0, proj, topo - capa, topo)
	var nm := int(floor((L - 0.1) / passo))
	if nm < 1:
		return
	var ini := (L - (nm - 1) * passo) * 0.5
	for i in nm:
		var c := ini + i * passo
		caixa_u(g.ext, m.parede_clara, o, u, n, c - larg * 0.5, c + larg * 0.5, 0.0, proj, y_a, y_b)
	# arcuação: entre duas mísulas, um arquinho (o vão escuro fica com topo em arco, como nas fotos)
	for i in nm - 1:
		var esq := ini + i * passo + larg * 0.5
		var dir := ini + (i + 1) * passo - larg * 0.5
		_arquinho(g.ext, o, u, n, esq, dir, y_b, proj)


## Tímpano claro de um arquinho entre mísulas, no plano da frente das mísulas (`proj` para fora da parede).
func _arquinho(ma: Malha, o: Vector3, u: Vector3, n: Vector3, esq: float, dir: float, y_topo: float, proj: float) -> void:
	var r := (dir - esq) * 0.5
	if r <= 0.01:
		return
	var xm := (esq + dir) * 0.5
	var ys := y_topo - r - 0.025
	var mat: Material = m.parede_clara
	var pts: Array = []
	for k in 5:
		var a := PI - PI * float(k) / 4.0
		pts.append(pt(o, u, n, xm + cos(a) * r, ys + sin(a) * r, -proj))
	var tl := pt(o, u, n, esq, y_topo, -proj)
	var tr := pt(o, u, n, dir, y_topo, -proj)
	ma.tri(mat, tl, pts[0], pts[1], n)
	ma.tri(mat, tl, pts[1], pts[2], n)
	ma.tri(mat, tl, pts[2], tr, n)
	ma.tri(mat, tr, pts[2], pts[3], n)
	ma.tri(mat, tr, pts[3], pts[4], n)


## Arquivolta: faixa saliente em torno de um arco (aduelas), mais clara que a parede.
func arquivolta(g: Grupo, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, vs: float, vc: float, tipo := "arco", larg := 0.13) -> void:
	var pf := Muros.perfil(tipo, uc - w * 0.5, uc + w * 0.5, vs, vc)
	for i in pf.size() - 1:
		var t := (pf[i + 1] - pf[i]).normalized()
		var nr := Vector2(-t.y, t.x)
		var a := pt(o, u, n, pf[i].x, pf[i].y, -0.03)
		var b := pt(o, u, n, pf[i + 1].x, pf[i + 1].y, -0.03)
		var c2 := pt(o, u, n, pf[i + 1].x + nr.x * larg, pf[i + 1].y + nr.y * larg, -0.03)
		var d := pt(o, u, n, pf[i].x + nr.x * larg, pf[i].y + nr.y * larg, -0.03)
		g.ext.quad(m.parede_clara, a, b, c2, d, n)


## Ameias (merlões) sobre o topo `topo` de um muro de espessura T (face externa em `o`).
func merloes(g: Grupo, o: Vector3, u: Vector3, n: Vector3, L: float, topo: float) -> void:
	var md: Dictionary = medidas.get("ameias", {})
	var w: float = md.get("largura", 0.33)
	var h: float = md.get("altura", 0.30)
	var esp: float = md.get("espessura", 0.30)
	var passo: float = md.get("passo", 0.58)
	var qtd := maxi(1, int(round((L + passo - w) / passo)))
	var p := 0.0 if qtd == 1 else (L - w) / (qtd - 1)
	var corpo := h - 0.06
	for i in qtd:
		var u0 := (L - w) * 0.5 if qtd == 1 else i * p
		caixa_u(g.ext, m.parede, o, u, n, u0, u0 + w, -esp, 0.0, topo, topo + corpo, Malha.F_SEM_BASE)
		caixa_u(g.ext, m.parede, o, u, n, u0 - 0.02, u0 + w + 0.02, -esp - 0.02, 0.02, topo + corpo, topo + h, Malha.F_SEM_BASE)


## Parapeito ameado completo (muro sólido do piso `y_base` até `topo` + cornija + ameias). Colisão alta contínua.
func parapeito(g: Grupo, o: Vector3, u: Vector3, n: Vector3, L: float, y_base: float, topo: float,
		com_cornija := true, com_ameias := true, t := T, mat_e: Material = null, mat_i: Material = null) -> void:
	var me: Material = mat_e if mat_e else m.parede
	var mi: Material = mat_i if mat_i else m.parede
	Muros.muro(g.ext, g.ext, me, mi, o, u, n, L, t, y_base, topo, [], {"tampa": true, "col": false, "mat_topo": me})
	g.col_sempre.col(pt(o, u, n, 0, y_base, 0), pt(o, u, n, L, y_base + 1.5, t))
	if com_cornija:
		cornija(g, o, u, n, L, topo)
	if com_ameias:
		merloes(g, o, u, n, L, topo)


## Laje (placa) retangular com faces de cima (terraço externo "ext" ou piso interno "int") e de baixo (forro).
func laje(g: Grupo, x0: float, x1: float, z0: float, z1: float, y_topo: float, esp := 0.3, topo := "ext", colisao := true) -> void:
	var p0 := Vector3(x0, y_topo - esp, z0)
	var p1 := Vector3(x1, y_topo, z1)
	if topo == "ext":
		g.ext.caixa(m.laje, p0, p1, Malha.F_PY)
	elif topo == "int":
		g.inte.caixa(m.piso, p0, p1, Malha.F_PY)
	g.inte.caixa(m.forro, p0, p1, Malha.F_NY, 1.5)
	if colisao:
		g.col_sempre.col(p0, p1)


## Forro (só a face de baixo), sem colisão.
func forro(g: Grupo, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	g.inte.caixa(m.forro, Vector3(x0, y - 0.05, z0), Vector3(x1, y, z1), Malha.F_NY, 1.5)


## Piso de pedra interno (visual; a colisão é o chão do nível).
func piso(g: Grupo, x0: float, x1: float, z0: float, z1: float, y := 0.012) -> void:
	g.inte.quad(m.piso, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP)


## Vigas de madeira escura aparentes sob o forro. eixo "x": vigas correm ao longo de x, espaçadas em z.
func vigas(g: Grupo, x0: float, x1: float, z0: float, z1: float, y_forro: float, eixo := "z", passo := 1.4, larg := 0.14, alt := 0.2) -> void:
	if eixo == "z":
		var n := maxi(1, int(round((x1 - x0) / passo)))
		for i in n:
			var x := x0 + (i + 0.5) * (x1 - x0) / n
			g.inte.caixa(m.madeira, Vector3(x - larg * 0.5, y_forro - alt, z0), Vector3(x + larg * 0.5, y_forro, z1), Malha.F_TODAS - Malha.F_PY, 1.0)
	else:
		var n := maxi(1, int(round((z1 - z0) / passo)))
		for i in n:
			var z := z0 + (i + 0.5) * (z1 - z0) / n
			g.inte.caixa(m.madeira, Vector3(x0, y_forro - alt, z - larg * 0.5), Vector3(x1, y_forro, z + larg * 0.5), Malha.F_TODAS - Malha.F_PY, 1.0)


## Decalque escuro no formato de uma abertura (fresta cega): barato, sem recorte na parede.
func decalque_vao(ma: Malha, mat: Material, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, vs: float, vc: float, tipo: String, desloc := 0.012) -> void:
	var pf := Muros.perfil(tipo, uc - w * 0.5, uc + w * 0.5, vs, vc)
	var centro := pt(o, u, n, uc, v0, -desloc)
	for i in pf.size() - 1:
		var a := pt(o, u, n, pf[i].x, pf[i].y, -desloc)
		var b := pt(o, u, n, pf[i + 1].x, pf[i + 1].y, -desloc)
		ma.tri(mat, centro, a, b, n)
	var bl := pt(o, u, n, uc - w * 0.5, v0, -desloc)
	var br := pt(o, u, n, uc + w * 0.5, v0, -desloc)
	ma.tri(mat, centro, br, bl, n)
	ma.tri(mat, centro, bl, pt(o, u, n, pf[0].x, pf[0].y, -desloc), n)
	ma.tri(mat, centro, pt(o, u, n, pf[pf.size() - 1].x, pf[pf.size() - 1].y, -desloc), br, n)


## Janela com grade de losangos, vidro e venezianas abertas dos lados (como na fachada leste).
func janela_grade(g: Grupo, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, h: float, venezianas := true) -> void:
	var e := g.ext
	# vidro e grade (recuados)
	var a := pt(o, u, n, uc - w * 0.5, v0, 0.12)
	var b := pt(o, u, n, uc + w * 0.5, v0, 0.12)
	var c := pt(o, u, n, uc + w * 0.5, v0 + h, 0.12)
	var d := pt(o, u, n, uc - w * 0.5, v0 + h, 0.12)
	e.quad(m.vidro, a, b, c, d, n)
	var a2 := pt(o, u, n, uc - w * 0.5, v0, 0.08)
	var b2 := pt(o, u, n, uc + w * 0.5, v0, 0.08)
	var c2 := pt(o, u, n, uc + w * 0.5, v0 + h, 0.08)
	var d2 := pt(o, u, n, uc - w * 0.5, v0 + h, 0.08)
	e.quad(m.grade, a2, b2, c2, d2, n, Vector2(w, h))
	# peitoril de pedra
	caixa_u(e, m.parede, o, u, n, uc - w * 0.5 - 0.08, uc + w * 0.5 + 0.08, 0.0, 0.14, v0 - 0.07, v0)
	if venezianas:
		var lw := 0.46
		for lado in [-1, 1]:
			var ua: float = uc + lado * (w * 0.5)
			var ub: float = uc + lado * (w * 0.5 + lw)
			var q0 := pt(o, u, n, ua, v0 - 0.04, -0.03)
			var q1 := pt(o, u, n, ub, v0 - 0.04, -0.03)
			var q2 := pt(o, u, n, ub, v0 + h + 0.04, -0.03)
			var q3 := pt(o, u, n, ua, v0 + h + 0.04, -0.03)
			e.quad(m.veneziana, q0, q1, q2, q3, n, Vector2(lw, h + 0.08))


## Folha de veneziana fechada (quadro de madeira com ripas) sobre a parede, sem abertura.
func veneziana_fechada(g: Grupo, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, h: float, mat_folha: Material = null) -> void:
	var q0 := pt(o, u, n, uc - w * 0.5, v0, -0.03)
	var q1 := pt(o, u, n, uc + w * 0.5, v0, -0.03)
	var q2 := pt(o, u, n, uc + w * 0.5, v0 + h, -0.03)
	var q3 := pt(o, u, n, uc - w * 0.5, v0 + h, -0.03)
	if mat_folha:
		# folhas de tábua (núcleo de 1950): duas folhas com fresta e verga de pedra clara
		g.ext.quad(mat_folha, q0, q1, q2, q3, n, Vector2(1.0, 1.0))
		caixa_u(g.ext, m.escuro, o, u, n, uc - 0.012, uc + 0.012, 0.0, 0.035, v0, v0 + h)
		caixa_u(g.ext, m.parede_clara, o, u, n, uc - w * 0.5 - 0.1, uc + w * 0.5 + 0.1, 0.0, 0.06, v0 + h, v0 + h + 0.14)
		caixa_u(g.ext, m.parede, o, u, n, uc - w * 0.5 - 0.06, uc + w * 0.5 + 0.06, 0.0, 0.12, v0 - 0.06, v0)
		return
	g.ext.quad(m.veneziana, q0, q1, q2, q3, n, Vector2(w * 0.5, h))
	# fundo escuro (a veneziana tem recorte em losango)
	var r0 := pt(o, u, n, uc - w * 0.5, v0, -0.015)
	var r1 := pt(o, u, n, uc + w * 0.5, v0, -0.015)
	var r2 := pt(o, u, n, uc + w * 0.5, v0 + h, -0.015)
	var r3 := pt(o, u, n, uc - w * 0.5, v0 + h, -0.015)
	g.ext.quad(m.escuro, r0, r1, r2, r3, n)
	caixa_u(g.ext, m.parede, o, u, n, uc - w * 0.5 - 0.06, uc + w * 0.5 + 0.06, 0.0, 0.12, v0 - 0.06, v0)


## Janela estreita em arco (ogival ou abatido) com vidro colorido; opcionalmente duas folhas de veneziana.
func janela_arco(g: Grupo, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, vs: float, vc: float, tipo: String,
		vidro := "vidro_verde", lado_e := "ext") -> void:
	var ma: Malha = g.ext if lado_e == "ext" else g.inte
	var pf := Muros.perfil(tipo, uc - w * 0.5, uc + w * 0.5, vs, vc)
	var centro := pt(o, u, n, uc, v0, 0.14)
	for i in pf.size() - 1:
		ma.tri(m[vidro], centro, pt(o, u, n, pf[i].x, pf[i].y, 0.14), pt(o, u, n, pf[i + 1].x, pf[i + 1].y, 0.14), n)
	ma.tri(m[vidro], centro, pt(o, u, n, uc + w * 0.5, v0, 0.14), pt(o, u, n, uc - w * 0.5, v0, 0.14), n)
	ma.tri(m[vidro], centro, pt(o, u, n, uc - w * 0.5, v0, 0.14), pt(o, u, n, pf[0].x, pf[0].y, 0.14), n)
	ma.tri(m[vidro], centro, pt(o, u, n, pf[pf.size() - 1].x, pf[pf.size() - 1].y, 0.14), pt(o, u, n, uc + w * 0.5, v0, 0.14), n)
	# caixilho vertical central escuro
	caixa_u(ma, m.ferro, o, u, n, uc - 0.01, uc + 0.01, -0.0, 0.16, v0, vs, Malha.F_TODAS)


## Folha de porta de madeira (quadro retangular) paralela à parede.
func folha_porta(ma: Malha, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, h: float, prof: float, vidros := false) -> void:
	var a := pt(o, u, n, uc - w * 0.5, v0, prof)
	var b := pt(o, u, n, uc + w * 0.5, v0, prof)
	var c := pt(o, u, n, uc + w * 0.5, v0 + h, prof)
	var d := pt(o, u, n, uc - w * 0.5, v0 + h, prof)
	ma.quad(m.porta, a, b, c, d, n, Vector2(1.0, 1.0))
	if vidros:
		# quatro vidros quadrados (2x2) por folha, no alto
		for i in 2:
			for j in 2:
				var cu := uc - w * 0.22 + i * w * 0.44
				var cy := v0 + h * 0.66 + j * 0.2 - 0.1
				var q0 := pt(o, u, n, cu - 0.07, cy - 0.07, prof - 0.012)
				var q1 := pt(o, u, n, cu + 0.07, cy - 0.07, prof - 0.012)
				var q2 := pt(o, u, n, cu + 0.07, cy + 0.07, prof - 0.012)
				var q3 := pt(o, u, n, cu - 0.07, cy + 0.07, prof - 0.012)
				ma.quad(m.luz, q0, q1, q2, q3, n)


## Porta dupla em arco: duas folhas com a forma do vão (arco) coladas ao plano, fechadas.
func porta_arco_fechada(ma: Malha, o: Vector3, u: Vector3, n: Vector3, uc: float, w: float, v0: float, vs: float, vc: float, prof := 0.16, vidros := true) -> void:
	var pf := Muros.perfil("arco", uc - w * 0.5, uc + w * 0.5, vs, vc)
	var centro := pt(o, u, n, uc, v0, prof)
	var uvf := func(uu: float, y: float) -> Vector2:
		return Vector2(uu * 1.1, -y * 1.1)
	for i in pf.size() - 1:
		ma.tri(m.porta, centro, pt(o, u, n, pf[i].x, pf[i].y, prof), pt(o, u, n, pf[i + 1].x, pf[i + 1].y, prof), n,
			uvf.call(uc, v0), uvf.call(pf[i].x, pf[i].y), uvf.call(pf[i + 1].x, pf[i + 1].y))
	var bl := pt(o, u, n, uc - w * 0.5, v0, prof)
	var br := pt(o, u, n, uc + w * 0.5, v0, prof)
	var p0 := pf[0]
	var pn := pf[pf.size() - 1]
	ma.tri(m.porta, centro, br, bl, n, uvf.call(uc, v0), uvf.call(uc + w * 0.5, v0), uvf.call(uc - w * 0.5, v0))
	ma.tri(m.porta, centro, bl, pt(o, u, n, p0.x, p0.y, prof), n, uvf.call(uc, v0), uvf.call(uc - w * 0.5, v0), uvf.call(p0.x, p0.y))
	ma.tri(m.porta, centro, pt(o, u, n, pn.x, pn.y, prof), br, n, uvf.call(uc, v0), uvf.call(pn.x, pn.y), uvf.call(uc + w * 0.5, v0))
	# fresta central escura entre as folhas
	caixa_u(ma, m.escuro, o, u, n, uc - 0.012, uc + 0.012, 0.0, prof + 0.02, v0, vs + (vc - vs) * 0.6, Malha.F_PX | Malha.F_NX | Malha.F_PZ | Malha.F_NZ)
	if vidros:
		for lado in [-1, 1]:
			for j in 2:
				var cu: float = uc + lado * w * 0.22
				var cy := vs - 0.05 + j * 0.28
				ma.quad(m.luz, pt(o, u, n, cu - 0.09, cy - 0.09, prof - 0.012), pt(o, u, n, cu + 0.09, cy - 0.09, prof - 0.012),
					pt(o, u, n, cu + 0.09, cy + 0.09, prof - 0.012), pt(o, u, n, cu - 0.09, cy + 0.09, prof - 0.012), n)


## Marca um nó para existir só em certas épocas (atalho).
static func so_em(no: Node, epocas: Array) -> void:
	Epocas.marcar(no, epocas)
