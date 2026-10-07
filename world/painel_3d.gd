class_name Painel3D
extends Interagivel
## Painel educativo no mundo: placa colorida com moldura amarela e azul (cara de "jogo da prefeitura"),
## título, ícone e, se houver, a plaquinha "QUIZ!". Interagir ([E] ou clique) abre a tela de leitura
## (PainelUI), que solta o mouse, trava o jogador e mostra o texto e o quiz.
## Conteúdo em data/paineis.json, chave = id (ex.: "p01"; "quiz_final" para o quiz da sala 22).
##
##   var p := Painel3D.new("p01"); p.position = ...; nivel.add_child(p)
##   p.lido.connect(func(id): ...)     # emitido quando o jogador fecha a leitura (e o quiz, se houver)
##
## A frente da placa é o eixo +Z local (o jogador a vê olhando para -Z local): gire com rotation.y.
## Tamanho: 1,6 x 1,1 m, centrada na origem. A placa acompanha GameState.corruption: perde cor
## e o título ganha letras trocadas.
##
## V2 (docs/V2_ROTEIRO.md §8.4):
##   - Variantes por visita: Painel3D.new("p05_v2"). Se a variante não existir no JSON, vale "p05" (PainelUI.dados()).
##     v2 e v3 usam a placa cinza "seca"; v3 ganha o carimbo "EM REVISÃO"; v4 mostra o título riscado, uma palavra
##     (ou "…") e o desenho do Tito em destaque (campos `riscado` e `desenho` do JSON).
##   - Imagens: Painel3D.new("desenho_1".."desenho_7" | "procura_se" | "marcas_altura") é uma folha de papel colada
##     na parede (largura `largura_m` do JSON, altura pela proporção da imagem; a frente é +Z). Interagir abre a
##     visualização (PainelUI) com a legenda.

signal lido(id: String)

const LARG := 1.5
const ALT := 1.0
const TAM_TEXTO := Vector2(1.5, 1.0)

var id := ""
var _visual: Node3D
var _check: Sprite3D
var _estrelas: Array[Sprite3D] = []
## > 0: a placa some a mais de `alcance` metros (visibility_range_end em todas as peças, reaplicado a cada
## reconstrução por corruption). Cada placa tem ~12 superfícies: sem isso, um nível com 25 painéis passa de 300
## draw calls assim que a corruption muda (a placa se reconstrói e as peças novas não tinham alcance).
var alcance := 0.0
var _st: SurfaceTool
static var _MAT_PLACA: ShaderMaterial = null
var _foi_lido := false
var _t := 0.0
var _tem_quiz := false
var _seco := false
var _imagem := false


func _init(id_painel := "p00") -> void:
	var d := PainelUI.dados(id_painel)
	var tam_caixa := Vector3(LARG + 0.12, ALT + 0.12, 0.16)
	if str(d.get("tipo", "")) == "imagem":
		var tam_papel := _tamanho_folha(d)
		tam_caixa = Vector3(tam_papel.x, tam_papel.y, 0.12)
	super._init("Ler painel", tam_caixa)
	id = id_painel
	_tem_quiz = d.has("quiz")
	_seco = bool(d.get("seco", false))
	_imagem = str(d.get("tipo", "")) == "imagem"
	if _imagem:
		texto_interacao = {"procura_se": "Ler o cartaz", "marcas_altura": "Ver as marcas"}.get(id_painel, "Ver o desenho")
	elif id == "quiz_final":
		texto_interacao = "Fazer o quiz final"
	elif _tem_quiz:
		texto_interacao = "Ler painel e fazer o quiz"


func _ready() -> void:
	_construir()
	GameState.corruption_mudou.connect(_ao_mudar_corruption)


func _ao_mudar_corruption(_v: float) -> void:
	_construir()


# ---------------------------------------------------------------- visual
## As caixas da moldura vão para uma só malha (_st, cor de vértice + brilho no alfa, shaders/placa_cor.gdshader):
## 1 draw call por placa em vez de 7. Interiores com 6 a 8 placas por perto ficavam acima de 150 draw calls.
func _caixa(tam: Vector3, pos: Vector3, cor: Color, brilho := 0.3) -> void:
	var h := tam * 0.5
	var c := Color(cor.r, cor.g, cor.b, brilho)
	_st.set_color(c)
	# 6 faces: [normal, eixo u, eixo v]
	for f in [[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
			[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
			[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1] * h
		var v: Vector3 = f[2] * h
		var o: Vector3 = pos + n * h
		var q := [o - u - v, o + u - v, o + u + v, o - u + v]
		_st.set_normal(n)
		for i in [0, 2, 1, 0, 3, 2]:
			_st.add_vertex(q[i])


func _fechar_caixas() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Moldura"
	mi.mesh = _st.commit()
	mi.material_override = _MAT_PLACA
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)


func _rotulo(texto: String, pos: Vector3, tamanho: int, cor: Color, fonte: Font, largura := 0.0, contorno := 8) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font = fonte
	l.font_size = tamanho
	l.pixel_size = 0.0034
	l.modulate = cor
	l.outline_modulate = Flash.NAVY
	l.outline_size = contorno
	l.line_spacing = -8.0
	l.double_sided = false
	l.shaded = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.position = pos
	if largura > 0.0:
		l.width = largura / l.pixel_size
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_visual.add_child(l)
	return l


func _sprite(nome_tex: Texture2D, pos: Vector3, tam_m: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = nome_tex
	if nome_tex:
		s.pixel_size = tam_m / float(nome_tex.get_width())
	s.shaded = false
	s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.position = pos
	_visual.add_child(s)
	return s


func _construir() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_estrelas.clear()
	if _imagem:
		_construir_imagem(PainelUI.dados(id))
		return
	if _MAT_PLACA == null:
		_MAT_PLACA = ShaderMaterial.new()
		_MAT_PLACA.shader = preload("res://shaders/placa_cor.gdshader")
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var d := PainelUI.dados(id)
	var corr := GameState.corruption
	var t := Flash.fator_dessat(corr)
	var c_ext := Color("9AA0AA") if _seco else Flash.AMARELO
	var c_int := Color("5B6577") if _seco else Flash.AZUL
	var c_papel := Color("EEF0F3") if _seco else Flash.CREME
	c_ext = Flash.dessaturar(c_ext, t)
	c_int = Flash.dessaturar(c_int, t)
	c_papel = Flash.dessaturar(c_papel, t)

	# contorno grosso (caixa azul-marinho atrás) + moldura + miolo
	_caixa(Vector3(LARG + 0.12, ALT + 0.12, 0.05), Vector3(0, 0, -0.012), Flash.NAVY, 0.05)
	_caixa(Vector3(LARG + 0.04, ALT + 0.04, 0.06), Vector3(0, 0, 0.0), c_ext)
	_caixa(Vector3(LARG - 0.08, ALT - 0.08, 0.07), Vector3(0, 0, 0.005), c_int)
	_caixa(Vector3(LARG - 0.2, ALT - 0.2, 0.075), Vector3(0, 0, 0.01), c_papel, 0.1)
	# faixa do título
	_caixa(Vector3(LARG - 0.2, 0.37, 0.08), Vector3(0, 0.225, 0.0125), c_int)
	_caixa(Vector3(LARG - 0.2, 0.025, 0.082), Vector3(0, 0.0, 0.0125), Flash.NAVY, 0.05)

	var titulo := str(d.get("titulo", id))
	if not _seco:
		titulo = Flash.corromper(titulo, corr)
	var fonte := Flash.fonte_sistema() if _seco else (Flash.fonte_erro() if corr >= 0.75 else Flash.fonte_titulo())
	var tam := 34 if corr < 0.75 else 44
	_rotulo(titulo, Vector3(0, 0.225, 0.062), tam if not _seco else 30, Color.WHITE, fonte, LARG - 0.34, 0 if _seco else 7)
	var riscado := bool(d.get("riscado", false))
	if riscado:
		_riscar_titulo()

	# ícone + etiqueta (v4: o desenho do Tito no lugar do ícone, e a palavra no lugar da etiqueta)
	var desenho := Flash.textura(str(PainelUI.dados(str(d.get("desenho", ""))).get("imagem", ""))) if riscado else null
	if desenho != null:
		_sprite(desenho, Vector3(-0.42, -0.18, 0.059), 0.4)
		_rotulo(str(d.get("texto", "…")), Vector3(0.24, -0.16, 0.062), 90, Color("20242E"), Flash.fonte_erro(), 0.6, 0)
	else:
		var icone := Flash.icone(str(d.get("icone", "interrogacao")))
		var spr := _sprite(icone, Vector3(-0.43, -0.2, 0.059), 0.4)
		if _seco or t > 0.0:
			spr.modulate = Color.WHITE.lerp(Color(0.6, 0.62, 0.68), maxf(t, 0.8 if _seco else 0.0))
		var rotulo_n := id.trim_prefix("p").get_slice("_", 0)
		if id == "quiz_final":
			rotulo_n = "FINAL"
		var cor_texto := Flash.dessaturar(Flash.NAVY, t * 0.5)
		if str(d.get("carimbo", "")) == "":   # com carimbo o título já diz "Painel NN"
			_rotulo("PAINEL " + rotulo_n if rotulo_n.is_valid_int() else rotulo_n, Vector3(0.2, -0.1, 0.062), 38 if not _seco else 30,
				cor_texto, Flash.fonte_sistema() if _seco else Flash.fonte_titulo(), 0.0, 0)
	if str(d.get("carimbo", "")) != "":
		_carimbo(str(d.carimbo))
	if desenho != null:
		pass
	elif _tem_quiz:
		_caixa(Vector3(0.42, 0.14, 0.08), Vector3(0.26, -0.3, 0.0125), Flash.dessaturar(Flash.LARANJA, t))
		_rotulo("QUIZ!", Vector3(0.26, -0.3, 0.056), 38, Color.WHITE, Flash.fonte_titulo(), 0.0, 8)
	elif not _seco:
		_rotulo("Toque para ler", Vector3(0.26, -0.3, 0.062), 22, Flash.dessaturar(Color("5B6577"), t), Flash.fonte_texto(), 0.0, 0)

	# estrelinhas de enfeite nos cantos (somem se já foi lido)
	if not _seco:
		for p in [Vector3(-0.72, 0.5, 0.07), Vector3(0.72, -0.5, 0.07)]:
			var e := _sprite(Flash.icone("estrela"), p, 0.12)
			e.modulate = Color.WHITE.lerp(Color(0.6, 0.6, 0.6), t)
			_estrelas.append(e)

	_fechar_caixas()
	_check = _sprite(Flash.icone("check"), Vector3(0.62, -0.38, 0.075), 0.2)
	_check.visible = _foi_lido
	set_process(not _seco)
	if alcance > 0.0:
		_aplicar_alcance(_visual)


## v4: dois riscos de caneta sobre o título (o que estava escrito foi apagado).
func _riscar_titulo() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.07, 0.05, 0.07)
	for k in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(LARG - 0.3, 0.014, 0.004)
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(0.0, 0.225 + (k - 0.5) * 0.05, 0.072)
		mi.rotation = Vector3(0, 0, deg_to_rad(-1.6 + k * 3.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)


## v3: carimbo vermelho "EM REVISÃO" dentro de um filete, no canto da folha.
func _carimbo(texto: String) -> void:
	var pos := Vector3(0.22, -0.2, 0.062)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("B3261E")
	var lado := [[Vector3(0.0, 0.06, 0.0), Vector3(0.62, 0.012, 0.004)], [Vector3(0.0, -0.06, 0.0), Vector3(0.62, 0.012, 0.004)],
		[Vector3(0.31, 0.0, 0.0), Vector3(0.012, 0.12, 0.004)], [Vector3(-0.31, 0.0, 0.0), Vector3(0.012, 0.12, 0.004)]]
	var cx := Node3D.new()
	cx.position = pos
	cx.rotation = Vector3(0, 0, deg_to_rad(-5.0))
	_visual.add_child(cx)
	for l in lado:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = l[1]
		mi.mesh = bm
		mi.material_override = mat
		mi.position = l[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cx.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = texto
	lbl.font = Flash.fonte_titulo()
	lbl.font_size = 34
	lbl.pixel_size = 0.0034
	lbl.modulate = Color("B3261E")
	lbl.outline_size = 0
	lbl.shaded = false
	lbl.double_sided = false
	lbl.position = Vector3(0, 0, 0.004)
	cx.add_child(lbl)


# ---------------------------------------------------------------- folha de papel (desenhos, cartaz, marcas)
## Tamanho no mundo (m) de uma entrada "tipo: imagem": largura do JSON e altura pela proporção da imagem.
static func _tamanho_folha(d: Dictionary) -> Vector2:
	var larg := float(d.get("largura_m", 0.9))
	var tex := Flash.textura(str(d.get("imagem", "")))
	var prop := 1.0
	if tex != null and tex.get_width() > 0:
		prop = float(tex.get_height()) / float(tex.get_width())
	return Vector2(larg, larg * prop)


func _construir_imagem(d: Dictionary) -> void:
	var tam := _tamanho_folha(d)
	var tex := Flash.textura(str(d.get("imagem", "")))
	var corr := GameState.corruption
	var tinta := lerpf(1.0, 0.62, clampf(corr, 0.0, 1.0))
	# sombra fina atrás do papel (a folha está colada na parede, quase rente)
	var sombra := MeshInstance3D.new()
	var sm := QuadMesh.new()
	sm.size = tam + Vector2(0.03, 0.03)
	sombra.mesh = sm
	var ms := StandardMaterial3D.new()
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ms.albedo_color = Color(0, 0, 0, 0.35)
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra.material_override = ms
	sombra.position = Vector3(0.012, -0.014, 0.001)
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(sombra)
	# o papel: com um pouco de brilho próprio, para ler na sala escura, mas ainda reagindo à lanterna
	var papel := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = tam
	papel.mesh = qm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(tinta, tinta, tinta)
	mp.roughness = 1.0
	mp.cull_mode = BaseMaterial3D.CULL_BACK
	mp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if tex != null:
		mp.albedo_texture = tex
		mp.emission_enabled = true
		mp.emission_texture = tex
		mp.emission_energy_multiplier = 0.28 * tinta
		if tex.get_image() != null and tex.get_image().detect_alpha() != Image.ALPHA_NONE:
			mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mp.alpha_scissor_threshold = 0.5
	papel.material_override = mp
	papel.position = Vector3(0, 0, 0.004)
	papel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(papel)
	# fita adesiva nos cantos de cima (menos nas marcas de altura, que são riscos na própria parede)
	if id != "marcas_altura":
		var fita := StandardMaterial3D.new()
		fita.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fita.albedo_color = Color(0.93, 0.88, 0.62, 0.7)
		fita.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for sinal in [-1.0, 1.0]:
			var f := MeshInstance3D.new()
			var fm := QuadMesh.new()
			fm.size = Vector2(0.11, 0.035)
			f.mesh = fm
			f.material_override = fita
			f.position = Vector3(sinal * (tam.x / 2.0 - 0.03), tam.y / 2.0 - 0.012, 0.006)
			f.rotation = Vector3(0, 0, deg_to_rad(-sinal * 38.0))
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visual.add_child(f)
	# um leve desalinho (cada folha tem o seu, sempre o mesmo para o mesmo id)
	_visual.rotation.z = deg_to_rad(float(id.hash() % 300) / 100.0 - 1.5) if id != "marcas_altura" else 0.0
	_check = null
	set_process(false)
	if alcance > 0.0:
		_aplicar_alcance(_visual)


func _aplicar_alcance(no: Node) -> void:
	if no is GeometryInstance3D:
		(no as GeometryInstance3D).visibility_range_end = alcance
	for c in no.get_children():
		_aplicar_alcance(c)


func _process(dt: float) -> void:
	_t += dt
	for i in _estrelas.size():
		var e := _estrelas[i]
		if is_instance_valid(e):
			e.rotation.z = sin(_t * 2.0 + i) * 0.35
			e.scale = Vector3.ONE * (1.0 + 0.18 * sin(_t * 4.0 + i * 2.0))
			e.visible = not _foi_lido


# ---------------------------------------------------------------- interação
func interagir(player: Node) -> void:
	if GameState.flag("ui_aberta"):
		return
	super.interagir(player)            # som de clique + sinal `usado`
	var ui := PainelUI.mostrar(id)
	await ui.fechado
	_foi_lido = true
	if _check:
		_check.visible = true
	# Esc/X no meio do quiz fecha a tela mas não vale como "lido" (senão o quiz final dava o diploma sem terminar)
	if ui.concluido:
		lido.emit(id)
