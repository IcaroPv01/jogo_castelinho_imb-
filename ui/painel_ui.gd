class_name PainelUI
extends CanvasLayer
## Tela de leitura dos painéis educativos (e dos quizzes), estilo "janela de jogo educativo em Flash".
## Fica sob a árvore (adicionada ao root), então não precisa de autoload.
##
##   var ui := PainelUI.mostrar("p02")       # abre sem precisar de um Painel3D
##   await ui.fechado                          # emitido quando o jogador fecha (depois do quiz, se houver)
##   PainelUI.dados("p02") -> Dictionary      # conteúdo de data/paineis.json
##
## Ao abrir: solta o mouse, trava o jogador e liga a flag `ui_aberta` (via Flash.abrir_ui()).
## Ao fechar: recaptura o mouse e emite `fechado(id)`. `concluido` diz se o jogador foi até o fim (quiz terminado).
## Quiz: acerto -> Audio.sfx("acerto"), estrelinhas, GameState.ganhar_selo(selo) e
## GameState.somar("quiz_acertos"). Erro -> Audio.sfx("erro") e tenta de novo.
## Teclas: espaço/Enter = botão principal, 1/2/3 ou A/B/C = respostas, Esc = fechar.
## Para testes: `responder(indice)`, `avancar()` e `fechar()` fazem o que os cliques fazem.
##
## V2 (docs/V2_ROTEIRO.md §3 e §8.4):
##   - Variantes por visita: `PainelUI.dados("p05_v2")`. Se o id `pNN_vK` não existir no JSON, cai para `pNN`
##     (`PainelUI.id_efetivo()` devolve o id que valeu). v2 = fato real sem verniz, v3 = institucional frio com
##     "carimbo", v4 = quase sem texto: título riscado e o desenho do Tito em destaque (campos `riscado`, `desenho`).
##   - Imagens: entradas com `imagem` (desenho_1..7, procura_se, marcas_altura) abrem uma visualização da folha
##     (gerada por tools/gerar_desenhos.py) com a legenda ao lado, em vez de painel com ícone e anfitrião.

signal fechado(id: String)
signal quiz_respondido(id: String, correta: bool)

const CAMINHO_JSON := "res://data/paineis.json"
const LARGURA := 1040.0
const ALTURA := 620.0
const FRASES_ACERTO := ["Acertou, guri!", "Isso mesmo!", "É isso aí!", "Mandou bem!"]
const FRASES_ERRO := ["Quase! Tenta de novo!", "Hmm, não foi dessa vez!", "Opa! Pensa mais um pouquinho!"]

static var atual: PainelUI = null
static var _json := {}

var id := ""
var dados_painel := {}
var _perguntas: Array = []
var _q := 0
var _erros_na_pergunta := 0
var _respondida := false
var _em_quiz := false
var _digitando := false
var _fechando := false
## true se o jogador chegou ao fim: leu o painel (sem quiz) ou terminou o quiz. Esc/X no meio do quiz deixa false.
var concluido := false
var _quiz_terminado := false
var _lista_botoes: Array[BotaoGel] = []
var _seco := false
var _imagem: Texture2D = null       # desenho/cartaz mostrado no lugar do ícone (tipo "imagem" ou painel v4)
var _riscado := false
var _corr := 0.0
var _dessat := 0.0

var _fundo: ColorRect
var _janela: Control
var _texto: Label
var _titulo: Label
var _btn_principal: BotaoGel
var _area_texto: Control
var _area_quiz: Control
var _pergunta_lbl: Label
var _feedback: Label
var _progresso: Label
var _icone: TextureRect
var _host: TextureRect
var _tween_texto: Tween
var _fonte_lbl: Label
var _t := 0.0


class Brilhos extends Control:
	## Estrelinhas piscando em volta do ícone (decoração).
	var cor := Color("FFD23F")

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var posicoes := [Vector2(10, 30), Vector2(215, 20), Vector2(228, 160), Vector2(20, 178)]
		for i in posicoes.size():
			var f := 0.55 + 0.45 * sin(t * 4.0 + i * 1.7)
			var r := (9.0 + 5.0 * (i % 3)) * f
			var pts := Flash.pontos_estrela(posicoes[i], r, r * 0.42, t * 0.6 + i)
			draw_colored_polygon(pts, cor)
			pts.append(pts[0])
			draw_polyline(pts, Flash.NAVY, 2.0)


# ================================================================ API estática
static func carregar_dados() -> Dictionary:
	if _json.is_empty():
		var f := FileAccess.open(CAMINHO_JSON, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_json = d
		if _json.is_empty():
			push_warning("PainelUI: não consegui ler %s" % CAMINHO_JSON)
			_json = {"_vazio": true}
	return _json


## Id que de fato vale no JSON: o próprio, ou (variante `pNN_vK` inexistente) o painel base `pNN`.
static func id_efetivo(id_painel: String) -> String:
	var tudo := carregar_dados()
	if tudo.has(id_painel):
		return id_painel
	var i := id_painel.rfind("_v")
	if i > 0 and id_painel.substr(i + 2).is_valid_int():
		var base_id := id_painel.substr(0, i)
		if tudo.has(base_id):
			return base_id
	return id_painel


## Conteúdo de um painel (resolve variante inexistente e "alias"). Id desconhecido -> painel genérico "em construção".
static func dados(id_painel: String) -> Dictionary:
	var d: Variant = carregar_dados().get(id_efetivo(id_painel), null)
	if d is Dictionary:
		if d.has("alias"):
			return dados(str(d.alias))
		return d
	return {"titulo": "Painel em construção", "texto": "Este painel (%s) ainda está sendo escrito pela equipe do programa." % id_painel,
		"fonte": "", "icone": "interrogacao", "anfitriao": "bentinho"}


## Abre a tela de leitura. Se já houver uma aberta, devolve a mesma.
static func mostrar(id_painel: String) -> PainelUI:
	if atual != null and is_instance_valid(atual):
		return atual
	var ui := PainelUI.new()
	ui.id = id_painel
	atual = ui
	Flash.raiz().add_child.call_deferred(ui)
	return ui


# ================================================================ construção
func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	dados_painel = dados(id)
	_corr = GameState.corruption
	_dessat = Flash.fator_dessat(_corr)
	_seco = bool(dados_painel.get("seco", false))
	_riscado = bool(dados_painel.get("riscado", false))
	_imagem = _carregar_imagem()
	var q: Variant = dados_painel.get("quiz", null)
	if q is Array:
		_perguntas = q
	elif q is Dictionary:
		_perguntas = [q]
	_construir()
	Flash.abrir_ui()
	if not GameState.flag("lido_" + id):
		GameState.somar("paineis_lidos")
		GameState.set_flag("lido_" + id, true)
	_animar_entrada()
	_digitar_texto()


func _cor(c: Color) -> Color:
	return Flash.dessaturar(c, _dessat)


func _construir() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(Flash.NAVY.r, Flash.NAVY.g, Flash.NAVY.b, 0.62)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_janela = Control.new()
	_janela.anchor_left = 0.5
	_janela.anchor_right = 0.5
	_janela.anchor_top = 0.5
	_janela.anchor_bottom = 0.5
	_janela.offset_left = -LARGURA / 2.0
	_janela.offset_right = LARGURA / 2.0
	_janela.offset_top = -ALTURA / 2.0
	_janela.offset_bottom = ALTURA / 2.0
	_janela.pivot_offset = Vector2(LARGURA / 2.0, ALTURA / 2.0)
	add_child(_janela)

	var cor_fundo := Color("EEF0F3") if _seco else Flash.CREME
	var corpo := Panel.new()
	corpo.size = Vector2(LARGURA, ALTURA)
	corpo.add_theme_stylebox_override("panel", Flash.caixa(_cor(cor_fundo), Flash.NAVY, 28, 6))
	_janela.add_child(corpo)

	# ---- barra de título
	var barra := Panel.new()
	barra.size = Vector2(LARGURA, 78)
	var sb_barra := Flash.caixa(_cor(Color("5B6577") if _seco else Flash.AZUL), Flash.NAVY, 28, 6, false)
	sb_barra.corner_radius_bottom_left = 0
	sb_barra.corner_radius_bottom_right = 0
	barra.add_theme_stylebox_override("panel", sb_barra)
	_janela.add_child(barra)

	var chip := PanelContainer.new()
	chip.position = Vector2(26, 20)
	var sb_chip := Flash.caixa(_cor(Flash.AMARELO), Flash.NAVY, 14, 4, false)
	sb_chip.content_margin_left = 12
	sb_chip.content_margin_right = 12
	sb_chip.content_margin_top = 0
	sb_chip.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", sb_chip)
	var chip_lbl := Label.new()
	chip_lbl.text = _rotulo_painel()
	chip_lbl.add_theme_font_override("font", Flash.fonte_titulo())
	chip_lbl.add_theme_font_size_override("font_size", 22)
	chip_lbl.add_theme_color_override("font_color", Flash.NAVY)
	chip_lbl.add_theme_constant_override("outline_size", 0)
	chip.add_child(chip_lbl)
	_janela.add_child(chip)

	_titulo = Label.new()
	_titulo.position = Vector2(chip.position.x + 150, 8)
	_titulo.size = Vector2(LARGURA - 150 - 150, 62)
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo.clip_text = true
	var titulo_txt := str(dados_painel.get("titulo", ""))
	_titulo.text = titulo_txt if _seco else Flash.corromper(titulo_txt, _corr)
	var fonte_tit: Font = Flash.fonte_sistema() if _seco else (Flash.fonte_erro() if _corr >= 0.75 else Flash.fonte_titulo())
	_titulo.add_theme_font_override("font", fonte_tit)
	_titulo.add_theme_font_size_override("font_size", 32 if _corr < 0.75 else 40)
	_titulo.add_theme_color_override("font_color", Color.WHITE)
	_titulo.add_theme_color_override("font_outline_color", Flash.NAVY)
	_titulo.add_theme_constant_override("outline_size", 0 if _seco else 7)
	_janela.add_child(_titulo)
	if _riscado:
		_riscar_titulo()

	var fechar_btn := BotaoGel.new("X", Flash.VERMELHO, 24)
	fechar_btn.position = Vector2(LARGURA - 78, 12)
	fechar_btn.size = Vector2(54, 54)
	fechar_btn.pressed.connect(fechar)
	_janela.add_child(fechar_btn)

	# ---- coluna da esquerda: imagem (desenho, cartaz) OU ícone (e anfitrião)
	var anfitriao := str(dados_painel.get("anfitriao", "bentinho"))
	var tem_host := anfitriao in ["bentinho", "taina", "quico"]
	var x_texto := 300.0
	if _imagem != null:
		x_texto = 506.0
		_montar_imagem()
	else:
		_montar_icone_e_anfitriao(tem_host, anfitriao)

	# ---- área de texto (página)
	_area_texto = Control.new()
	_area_texto.position = Vector2(x_texto, 98)
	_area_texto.size = Vector2(LARGURA - x_texto - 28, 420)
	_janela.add_child(_area_texto)
	var folha := Panel.new()
	folha.size = Vector2(_area_texto.size.x, 340)
	folha.add_theme_stylebox_override("panel", Flash.caixa(Color.WHITE if not _seco else Color("F8F9FB"), Flash.NAVY, 20, 4, false))
	_area_texto.add_child(folha)
	_texto = Label.new()
	_texto.position = Vector2(24, 18)
	_texto.size = Vector2(_area_texto.size.x - 48, 304)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var bruto := str(dados_painel.get("texto", ""))
	_texto.text = bruto if _seco else Flash.corromper(bruto, _corr)
	var fonte_corpo: Font = Flash.fonte_sistema() if _seco else (Flash.fonte_erro() if _corr >= 0.6 else Flash.fonte_texto())
	_texto.add_theme_font_override("font", fonte_corpo)
	var n_chars := _texto.text.length()
	var tam_corpo := 32 if n_chars < 200 else (29 if n_chars < 280 else 27)
	_texto.add_theme_font_size_override("font_size", 26 if _seco else (36 if _corr >= 0.6 and n_chars < 260 else (32 if _corr >= 0.6 else tam_corpo)))
	if _riscado:   # v4: quase sem texto: uma palavra grande, torta, no meio da folha
		_texto.add_theme_font_override("font", Flash.fonte_erro())
		_texto.add_theme_font_size_override("font_size", 120 if n_chars < 12 else 56)
		_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_texto.rotation = deg_to_rad(-2.5)
		_texto.pivot_offset = _texto.size / 2.0
	_texto.add_theme_color_override("font_color", Color("20242E") if _seco else _cor(Flash.NAVY))
	_texto.add_theme_constant_override("outline_size", 0)
	_texto.add_theme_constant_override("line_spacing", 2)
	_area_texto.add_child(_texto)
	if not _seco and not _riscado:
		var etiqueta := PanelContainer.new()
		etiqueta.position = Vector2(20, -22)
		etiqueta.rotation = deg_to_rad(-3.0)
		var sb_e := Flash.caixa(_cor(Flash.LARANJA), Flash.NAVY, 14, 4, false)
		sb_e.content_margin_left = 12
		sb_e.content_margin_right = 12
		sb_e.content_margin_top = 0
		sb_e.content_margin_bottom = 2
		etiqueta.add_theme_stylebox_override("panel", sb_e)
		var el := Label.new()
		el.text = ("NA FOLHA" if _imagem != null else "VOCÊ SABIA?") if _perguntas.is_empty() else "HORA DO QUIZ!"
		el.add_theme_font_override("font", Flash.fonte_titulo())
		el.add_theme_font_size_override("font_size", 20)
		el.add_theme_constant_override("outline_size", 4)
		etiqueta.add_child(el)
		_area_texto.add_child(etiqueta)

	var fonte_txt := _texto_fonte()
	if fonte_txt != "":
		var lf := Label.new()
		lf.position = Vector2(x_texto, 448)
		lf.size = Vector2(LARGURA - x_texto - 28, 60)
		lf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lf.text = fonte_txt
		lf.add_theme_font_override("font", Flash.fonte_sistema())
		lf.add_theme_font_size_override("font_size", 15)
		lf.add_theme_color_override("font_color", Color("5B6577"))
		lf.add_theme_constant_override("outline_size", 0)
		_janela.add_child(lf)
		_fonte_lbl = lf

	# ---- área do quiz (criada vazia; montada quando o jogador clica em "Fazer o quiz!")
	_area_quiz = Control.new()
	_area_quiz.position = _area_texto.position
	_area_quiz.size = _area_texto.size
	_area_quiz.visible = false
	_janela.add_child(_area_quiz)

	if str(dados_painel.get("carimbo", "")) != "":
		_montar_carimbo(str(dados_painel.carimbo), x_texto)

	# ---- rodapé
	var dica := Label.new()
	dica.text = "Espaço ou Enter: continuar     Esc: fechar" if _imagem == null else "Esc: fechar"
	dica.position = Vector2(x_texto, 528)
	dica.size = Vector2(420 if _imagem == null else 200, 40)
	dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica.add_theme_font_override("font", Flash.fonte_sistema())
	dica.add_theme_font_size_override("font_size", 15)
	dica.add_theme_color_override("font_color", Color("7A8394"))
	dica.add_theme_constant_override("outline_size", 0)
	_janela.add_child(dica)

	_btn_principal = BotaoGel.new(_texto_botao(), _cor(Flash.VERDE) if not _seco else Color("7F8896"), 30)
	_btn_principal.position = Vector2(LARGURA - 28 - 290, 524)
	_btn_principal.size = Vector2(290, 70)
	_btn_principal.pressed.connect(avancar)
	_janela.add_child(_btn_principal)


func _rotulo_painel() -> String:
	if id == "quiz_final":
		return "QUIZ FINAL"
	if str(dados_painel.get("tipo", "")) == "imagem":
		return {"procura_se": "CARTAZ", "marcas_altura": "MARCAS"}.get(id, "DESENHO")
	var n := id.trim_prefix("p").get_slice("_", 0)
	return "PAINEL " + n if n.is_valid_int() else "PAINEL"


func _texto_botao() -> String:
	if str(dados_painel.get("tipo", "")) == "imagem":
		return "Fechar"
	if _riscado:
		return "..."
	if _seco:
		return "Entendido"
	return "Fazer o quiz!" if not _perguntas.is_empty() else "Entendi!"


func _texto_fonte() -> String:
	var f := str(dados_painel.get("fonte", "")).strip_edges()
	if f == "":
		return ""
	var dominios: Array[String] = []
	for url in f.split(" ", false):
		var d := url.replace("https://", "").replace("http://", "").replace("www.", "").get_slice("/", 0)
		if d not in dominios:
			dominios.append(d)
	return "Fonte: " + ", ".join(dominios)


# ================================================================ V2: imagem, título riscado, carimbo
## Textura do desenho/cartaz: o próprio painel (`imagem`) ou o desenho citado por um painel v4 (`desenho`).
func _carregar_imagem() -> Texture2D:
	var caminho := str(dados_painel.get("imagem", ""))
	if caminho == "" and str(dados_painel.get("desenho", "")) != "":
		caminho = str(dados(str(dados_painel.desenho)).get("imagem", ""))
	return Flash.textura(caminho) if caminho != "" else null


func _montar_imagem() -> void:
	var caixa := Vector2(430, 410)
	var moldura := Panel.new()
	moldura.position = Vector2(40, 98)
	moldura.size = caixa + Vector2(24, 24)
	moldura.pivot_offset = moldura.size / 2.0
	moldura.rotation = deg_to_rad(-1.2)
	var papel := Color("F4EEDC") if not _seco else Color("DADDE3")
	moldura.add_theme_stylebox_override("panel", Flash.caixa(_cor(papel), Flash.NAVY, 6, 5))
	_janela.add_child(moldura)
	var tam := _imagem.get_size()
	var k := minf(caixa.x / tam.x, caixa.y / tam.y)
	var alvo := tam * k
	var tr := Flash.imagem(_imagem, alvo, (moldura.size - alvo) / 2.0)
	moldura.add_child(tr)
	_icone = null


func _montar_icone_e_anfitriao(tem_host: bool, anfitriao: String) -> void:
	var moldura := Panel.new()
	moldura.position = Vector2(48, 98)
	moldura.size = Vector2(220, 200)
	moldura.add_theme_stylebox_override("panel", Flash.caixa(_cor(Color("DCEEFF")) if not _seco else Color("D7DAE0"), Flash.NAVY, 100, 5))
	_janela.add_child(moldura)
	_icone = Flash.imagem(Flash.icone(str(dados_painel.get("icone", "interrogacao"))), Vector2(150, 150), Vector2(48 + 35, 98 + 25))
	_icone.pivot_offset = Vector2(75, 75)
	if _seco or _dessat > 0.0:
		_icone.modulate = Color.WHITE.lerp(Color(0.62, 0.64, 0.7), maxf(_dessat, 0.8 if _seco else 0.0))
	_janela.add_child(_icone)
	var brilhos := Brilhos.new()
	brilhos.position = Vector2(38, 90)
	brilhos.size = Vector2(240, 210)
	brilhos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brilhos.cor = _cor(Flash.AMARELO)
	_janela.add_child(brilhos)

	if tem_host:
		var corrompido := _corr >= 0.45 or (_corr > Flash.LIMIAR_CORRUPCAO and randf() < 0.4)
		var cfg: Dictionary = Guia.PERSONAGENS[anfitriao]
		var molduraH := Panel.new()
		molduraH.position = Vector2(60, 318)
		molduraH.size = Vector2(196, 196)
		molduraH.add_theme_stylebox_override("panel", Flash.caixa(_cor(cfg.moldura), Flash.NAVY, 98, 5))
		_janela.add_child(molduraH)
		_host = Flash.imagem(Flash.mascote(cfg.retrato, corrompido), Vector2(180, 180), Vector2(68, 326))
		_host.pivot_offset = Vector2(90, 180)
		_janela.add_child(_host)
		var nome_chip := PanelContainer.new()
		var sb_n := Flash.caixa(_cor(cfg.cor), Flash.NAVY, 14, 4, false)
		sb_n.content_margin_left = 14
		sb_n.content_margin_right = 14
		sb_n.content_margin_top = 0
		sb_n.content_margin_bottom = 2
		nome_chip.add_theme_stylebox_override("panel", sb_n)
		var nome_lbl := Label.new()
		nome_lbl.text = cfg.nome
		nome_lbl.add_theme_font_override("font", Flash.fonte_titulo())
		nome_lbl.add_theme_font_size_override("font_size", 22)
		nome_lbl.add_theme_constant_override("outline_size", 4)
		nome_chip.add_child(nome_lbl)
		nome_chip.position = Vector2(100, 496)
		_janela.add_child(nome_chip)


## v4: dois riscos de caneta por cima do título, como quem apaga o que estava escrito.
func _riscar_titulo() -> void:
	var fonte_t: Font = _titulo.get_theme_font("font")
	var tam: int = _titulo.get_theme_font_size("font_size")
	var larg := minf(fonte_t.get_string_size(_titulo.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 16.0, _titulo.size.x)
	for k in 2:
		var r := ColorRect.new()
		r.color = Color(0.08, 0.06, 0.08, 0.92)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(larg, 5)
		r.position = Vector2(_titulo.position.x - 6, _titulo.position.y + 28 + k * 7)
		r.pivot_offset = Vector2(0, 2.5)
		r.rotation = deg_to_rad(-1.4 + k * 2.6)
		_janela.add_child(r)


## "EM REVISÃO": carimbo vermelho torto sobre a folha (v3).
func _montar_carimbo(texto: String, x_texto: float) -> void:
	var c := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.0)
	sb.border_color = Color("B3261E")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	c.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", Flash.fonte_titulo())
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color("B3261E"))
	l.add_theme_constant_override("outline_size", 0)
	c.add_child(l)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(LARGURA - 300.0, 360.0)
	c.pivot_offset = Vector2(140, 25)
	c.rotation = deg_to_rad(-8.0)
	c.modulate.a = 0.82
	_janela.add_child(c)


# ================================================================ animação e texto
func _animar_entrada() -> void:
	_janela.scale = Vector2(0.82, 0.82)
	_janela.modulate.a = 0.0
	_fundo.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_fundo, "modulate:a", 1.0, 0.2)
	t.tween_property(_janela, "modulate:a", 1.0, 0.15)
	t.tween_property(_janela, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _digitar_texto() -> void:
	_texto.visible_ratio = 0.0
	_digitando = true
	var dur := clampf(_texto.text.length() / 75.0, 0.6, 2.4)
	_tween_texto = create_tween()
	_tween_texto.tween_property(_texto, "visible_ratio", 1.0, dur)
	_tween_texto.tween_callback(func(): _digitando = false)


func _process(dt: float) -> void:
	_t += dt
	# ícone e anfitrião "respiram" em passos de 12 fps (tremidinho de tween de Flash)
	var passo := floorf(_t * 12.0) / 12.0
	if _icone:
		_icone.scale = Vector2.ONE * (1.0 + 0.04 * sin(passo * 3.0))
		_icone.rotation = 0.05 * sin(passo * 1.7)
	if _host:
		_host.scale = Vector2(1.0, 1.0 + 0.025 * sin(passo * 4.0))


# ================================================================ interação
func avancar() -> void:
	if _fechando:
		return
	if _digitando:
		if _tween_texto:
			_tween_texto.kill()
		_texto.visible_ratio = 1.0
		_digitando = false
		return
	if _em_quiz:
		if _respondida:
			_proxima_pergunta()
		return
	if not _perguntas.is_empty():
		_iniciar_quiz()
	else:
		fechar()


func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	concluido = _perguntas.is_empty() or _quiz_terminado
	if atual == self:
		atual = null
	Flash.fechar_ui()     # recaptura o mouse: precisa rodar dentro do evento de clique/tecla
	Audio.sfx("clique", -4.0)
	var t := create_tween().set_parallel()
	t.tween_property(_janela, "modulate:a", 0.0, 0.12)
	t.tween_property(_janela, "scale", Vector2(0.92, 0.92), 0.12)
	t.tween_property(_fundo, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(queue_free)
	fechado.emit(id)


func _input(e: InputEvent) -> void:
	if _fechando:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if e.is_action_pressed("pausa"):
			fechar()
			get_viewport().set_input_as_handled()
		elif _em_quiz and not _respondida and k in [KEY_1, KEY_2, KEY_3, KEY_A, KEY_B, KEY_C]:
			var idx: int = [KEY_1, KEY_2, KEY_3].find(k)
			if idx < 0:
				idx = [KEY_A, KEY_B, KEY_C].find(k)
			responder(idx)
			get_viewport().set_input_as_handled()
		elif e.is_action_pressed("avancar_dialogo") or e.is_action_pressed("interagir"):
			avancar()
			get_viewport().set_input_as_handled()


# ================================================================ quiz
func _iniciar_quiz() -> void:
	_em_quiz = true
	_q = 0
	if _fonte_lbl:
		_fonte_lbl.visible = false
	_area_texto.visible = false
	_area_quiz.visible = true
	_montar_pergunta()


func _montar_pergunta() -> void:
	for c in _area_quiz.get_children():
		c.queue_free()
	_lista_botoes.clear()
	_respondida = false
	_erros_na_pergunta = 0
	var p: Dictionary = _perguntas[_q]

	if _perguntas.size() > 1:
		_progresso = Label.new()
		_progresso.text = "Pergunta %d de %d" % [_q + 1, _perguntas.size()]
		_progresso.position = Vector2(0, -4)
		_progresso.size = Vector2(_area_quiz.size.x, 30)
		_progresso.add_theme_font_override("font", Flash.fonte_titulo())
		_progresso.add_theme_font_size_override("font_size", 22)
		_progresso.add_theme_color_override("font_color", _cor(Flash.LARANJA))
		_progresso.add_theme_constant_override("outline_size", 0)
		_area_quiz.add_child(_progresso)

	_pergunta_lbl = Label.new()
	_pergunta_lbl.position = Vector2(0, 26)
	_pergunta_lbl.size = Vector2(_area_quiz.size.x, 84)
	_pergunta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pergunta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var enunciado := str(p.get("pergunta", ""))
	_pergunta_lbl.text = Flash.corromper(enunciado, _corr)
	_pergunta_lbl.add_theme_font_override("font", Flash.fonte_erro() if _corr >= 0.6 else Flash.fonte_titulo())
	_pergunta_lbl.add_theme_font_size_override("font_size", 38 if _corr >= 0.6 else 30)
	_pergunta_lbl.add_theme_color_override("font_color", _cor(Flash.NAVY))
	_pergunta_lbl.add_theme_constant_override("outline_size", 0)
	_area_quiz.add_child(_pergunta_lbl)

	var cores := [Flash.AZUL, Flash.LARANJA, Flash.ROSA]
	var opcoes: Array = p.get("opcoes", [])
	for i in opcoes.size():
		var b := BotaoGel.new("%s   %s" % ["ABC"[i], Flash.corromper(str(opcoes[i]), _corr)], _cor(cores[i % 3]), 25)
		b.position = Vector2(0, 118 + i * 74)
		b.size = Vector2(_area_quiz.size.x, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(responder.bind(i))
		_area_quiz.add_child(b)
		_lista_botoes.append(b)

	_feedback = Label.new()
	_feedback.position = Vector2(0, 344)
	_feedback.size = Vector2(_area_quiz.size.x, 76)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_override("font", Flash.fonte_texto())
	_feedback.add_theme_font_size_override("font_size", 24)
	_feedback.add_theme_color_override("font_color", _cor(Flash.NAVY))
	_feedback.add_theme_constant_override("outline_size", 0)
	_area_quiz.add_child(_feedback)

	_btn_principal.text = "Continuar"
	_btn_principal.disabled = true
	_btn_principal.definir_cor(_cor(Flash.VERDE))


## Responde à alternativa `indice` (0..2) da pergunta atual. Devolve true se acertou.
func responder(indice: int) -> bool:
	if not _em_quiz or _respondida or _q >= _perguntas.size():
		return false
	var p: Dictionary = _perguntas[_q]
	var correta := indice == int(p.get("correta", 0))
	var botao: BotaoGel = _lista_botoes[indice] if indice >= 0 and indice < _lista_botoes.size() else null
	quiz_respondido.emit(id, correta)
	if correta:
		_respondida = true
		Audio.sfx("acerto")
		GameState.somar("quiz_acertos")
		var selo := str(p.get("selo", ""))
		if selo != "":
			GameState.ganhar_selo(selo)
			get_tree().create_timer(0.35).timeout.connect(func(): Audio.sfx("selo", -3.0))
		for i in _lista_botoes.size():
			var b := _lista_botoes[i]
			b.disabled = i != indice
			if i == indice:
				b.definir_cor(_cor(Flash.VERDE))
		var frase: String = FRASES_ACERTO.pick_random()
		var extra := str(p.get("explicacao", ""))
		_feedback.text = Flash.corromper(frase + (" " + extra if extra != "" else ""), _corr)
		_feedback.add_theme_color_override("font_color", _cor(Color("1C7A2B")))
		_chuva_de_estrelas()
		_btn_principal.disabled = false
		_btn_principal.text = "Terminar" if _q >= _perguntas.size() - 1 else "Próxima"
	else:
		_erros_na_pergunta += 1
		Audio.sfx("erro")
		if botao:
			botao.disabled = true
			botao.definir_cor(Color("8E99A8"))
			_tremer(botao)
		_feedback.text = Flash.corromper(FRASES_ERRO.pick_random(), _corr)
		_feedback.add_theme_color_override("font_color", _cor(Color("B3261E")))
	return correta


func _proxima_pergunta() -> void:
	if _q >= _perguntas.size() - 1:
		_quiz_terminado = true
		fechar()
		return
	_q += 1
	_montar_pergunta()


func _tremer(c: Control) -> void:
	var x0 := c.position.x
	var t := create_tween()
	for d in [10.0, -10.0, 7.0, -7.0, 0.0]:
		t.tween_property(c, "position:x", x0 + d, 0.045)


## Estrelinhas animadas no meio da área do quiz quando o jogador acerta.
func _chuva_de_estrelas() -> void:
	var tex := Flash.icone("estrela")
	if tex == null:
		return
	var origem := _area_quiz.position + Vector2(_area_quiz.size.x * 0.5, 190)
	var grande := Flash.imagem(tex, Vector2(120, 120), origem - Vector2(60, 60))
	grande.pivot_offset = grande.size / 2.0
	grande.scale = Vector2.ZERO
	_janela.add_child(grande)
	var tg := create_tween()
	tg.tween_property(grande, "scale", Vector2.ONE * 1.3, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tg.parallel().tween_property(grande, "rotation", 0.5, 0.6)
	tg.tween_property(grande, "modulate:a", 0.0, 0.35)
	tg.tween_callback(grande.queue_free)
	for i in 10:
		var s := Flash.imagem(tex, Vector2(36, 36), origem - Vector2(18, 18))
		s.pivot_offset = s.size / 2.0
		_janela.add_child(s)
		var ang := TAU * i / 10.0 + randf() * 0.4
		var alvo := origem + Vector2(cos(ang), sin(ang)) * randf_range(150, 260) - s.size / 2.0
		var ts := create_tween().set_parallel()
		ts.tween_property(s, "position", alvo, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ts.tween_property(s, "rotation", randf_range(-3, 3), 0.7)
		ts.tween_property(s, "modulate:a", 0.0, 0.7).set_delay(0.25)
		ts.chain().tween_callback(s.queue_free)
