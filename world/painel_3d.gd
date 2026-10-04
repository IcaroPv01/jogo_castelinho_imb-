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

signal lido(id: String)

const LARG := 1.5
const ALT := 1.0
const TAM_TEXTO := Vector2(1.5, 1.0)

var id := ""
var _visual: Node3D
var _check: Sprite3D
var _estrelas: Array[Sprite3D] = []
var _foi_lido := false
var _t := 0.0
var _tem_quiz := false
var _seco := false


func _init(id_painel := "p00") -> void:
	super._init("Ler painel", Vector3(LARG + 0.12, ALT + 0.12, 0.16))
	id = id_painel
	var d := PainelUI.dados(id)
	_tem_quiz = d.has("quiz")
	_seco = bool(d.get("seco", false))
	if id == "quiz_final":
		texto_interacao = "Fazer o quiz final"
	elif _tem_quiz:
		texto_interacao = "Ler painel e fazer o quiz"


func _ready() -> void:
	_construir()
	GameState.corruption_mudou.connect(_ao_mudar_corruption)


func _ao_mudar_corruption(_v: float) -> void:
	_construir()


# ---------------------------------------------------------------- visual
func _mat(cor: Color, brilho := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = brilho
	return m


func _caixa(tam: Vector3, pos: Vector3, cor: Color, brilho := 0.3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _mat(cor, brilho)
	mi.position = pos
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

	# ícone + etiqueta
	var icone := Flash.icone(str(d.get("icone", "interrogacao")))
	var spr := _sprite(icone, Vector3(-0.43, -0.2, 0.059), 0.4)
	if _seco or t > 0.0:
		spr.modulate = Color.WHITE.lerp(Color(0.6, 0.62, 0.68), maxf(t, 0.8 if _seco else 0.0))
	var rotulo_n := id.trim_prefix("p").get_slice("_", 0)
	if id == "quiz_final":
		rotulo_n = "FINAL"
	var cor_texto := Flash.dessaturar(Flash.NAVY, t * 0.5)
	_rotulo("PAINEL " + rotulo_n if rotulo_n.is_valid_int() else rotulo_n, Vector3(0.2, -0.1, 0.062), 38 if not _seco else 30,
		cor_texto, Flash.fonte_sistema() if _seco else Flash.fonte_titulo(), 0.0, 0)
	if _tem_quiz:
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

	_check = _sprite(Flash.icone("check"), Vector3(0.62, -0.38, 0.075), 0.2)
	_check.visible = _foi_lido
	set_process(not _seco)


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
	lido.emit(id)
