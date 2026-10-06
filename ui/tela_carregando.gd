class_name TelaCarregando
extends CanvasLayer
## Tela "Carregando..." no estilo Flash da prefeitura (mesma faixa azul, botões gel e mascote da tela de título).
##
## Aparece ANTES de o nível ser montado: o main.gd a cria, espera dois quadros para ela ser DESENHADA e só então
## carrega a cena e "aquece" os materiais por trás dela. Sem isso, o clique em "Começar a visita" deixava a tela de
## título congelada por vários segundos (montar o nível e compilar os shaders de todas as superfícies no 1º quadro),
## e no navegador parecia que o jogo tinha travado.
##
##   var tela := TelaCarregando.mostrar(self)
##   await tela.aguardar_desenho()         # já está na tela
##   tela.definir(0.5, "Montando o Castelinho")
##   await tela.encerrar()                 # "Pronto!" + fade curto e se remove (ou finalizar() e desaparecer() em separado)
##
## Camada 130: acima da Transicao (100), do Diploma (110) e da Morte (120).

signal desenhada

const LARGURA := 1280.0
const ALTURA := 720.0
const DICAS := [
	"Aperte E (ou clique) para ler os painéis!",
	"Segure Shift para correr, mas o fôlego acaba!",
	"Esc solta o mouse e pausa a visita.",
	"Cada quiz que você acerta vale um selo!",
]

static var ultima: TelaCarregando = null

var _raiz: Control
var _cenario: ColorRect
var _palco: Control
var _titulo: Label
var _passo: Label
var _dica: Label
var _barra_fill: Panel
var _barra_larg := 0.0
var _mascote: Control
var _base_y := 0.0
var _t := 0.0
var _valor := 0.0
var _alvo := 0.0
var _saindo := false
var _ja_desenhada := false


static func mostrar(pai: Node) -> TelaCarregando:
	if ultima != null and is_instance_valid(ultima) and not ultima._saindo:
		return ultima
	var t := TelaCarregando.new()
	ultima = t
	pai.add_child(t)
	return t


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construir()
	definir(0.04, "Abrindo as portas do Castelinho")
	_emitir_desenhada.call_deferred()


## Espera dois quadros: um para o layout e outro para a imagem ir de fato para a tela.
func _emitir_desenhada() -> void:
	var arvore := get_tree()
	if arvore == null:
		return
	await arvore.process_frame
	await arvore.process_frame
	_ja_desenhada = true
	desenhada.emit()


## Devolve quando a tela já foi desenhada (na hora, se já foi).
func aguardar_desenho() -> void:
	if not _ja_desenhada:
		await desenhada


func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_cenario = ColorRect.new()
	_cenario.color = Flash.CEU
	_cenario.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cenario.mouse_filter = Control.MOUSE_FILTER_STOP     # engole cliques: o jogo ainda não existe
	_raiz.add_child(_cenario)
	var faixa_chao := ColorRect.new()
	faixa_chao.color = Color("7BD865")
	faixa_chao.anchor_top = 0.82
	faixa_chao.anchor_right = 1.0
	faixa_chao.anchor_bottom = 1.0
	faixa_chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(faixa_chao)

	_palco = Control.new()
	_palco.anchor_left = 0.5
	_palco.anchor_right = 0.5
	_palco.anchor_top = 0.5
	_palco.anchor_bottom = 0.5
	_palco.offset_left = -LARGURA / 2.0
	_palco.offset_right = LARGURA / 2.0
	_palco.offset_top = -ALTURA / 2.0
	_palco.offset_bottom = ALTURA / 2.0
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_palco)

	# faixa institucional (a mesma da tela de título)
	var faixa := Panel.new()
	faixa.position = Vector2(-400, -20)
	faixa.size = Vector2(LARGURA + 800, 66)
	faixa.add_theme_stylebox_override("panel", Flash.caixa(Color("14307A"), Flash.NAVY, 0, 5, false))
	_palco.add_child(faixa)
	var l := Label.new()
	l.text = "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA"
	l.position = Vector2(72, 6)
	l.size = Vector2(760, 36)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Flash.fonte_sistema())
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 0)
	_palco.add_child(l)

	# mascote que pula em passos de 12 fps
	_mascote = Flash.imagem(Flash.mascote("bentinho"), Vector2(250, 250), Vector2(LARGURA / 2.0 - 125.0, 120))
	_mascote.pivot_offset = Vector2(125, 250)
	_base_y = _mascote.position.y
	_palco.add_child(_mascote)

	_titulo = Label.new()
	_titulo.text = "Carregando"
	_titulo.position = Vector2(0, 380)
	_titulo.size = Vector2(LARGURA, 100)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_override("font", Flash.fonte_titulo())
	_titulo.add_theme_font_size_override("font_size", 78)
	_titulo.add_theme_color_override("font_color", Flash.AMARELO)
	_titulo.add_theme_color_override("font_outline_color", Flash.NAVY)
	_titulo.add_theme_constant_override("outline_size", 20)
	_palco.add_child(_titulo)

	# barra de progresso "gel"
	var fundo := Panel.new()
	fundo.position = Vector2(LARGURA / 2.0 - 300.0, 494)
	fundo.size = Vector2(600, 44)
	fundo.add_theme_stylebox_override("panel", Flash.caixa(Color.WHITE, Flash.NAVY, 22, 5))
	_palco.add_child(fundo)
	_barra_larg = fundo.size.x - 10.0
	_barra_fill = Panel.new()
	_barra_fill.position = Vector2(fundo.position.x + 5.0, fundo.position.y + 5.0)
	_barra_fill.size = Vector2(0.0, fundo.size.y - 10.0)
	_barra_fill.add_theme_stylebox_override("panel", Flash.caixa(Flash.VERDE, Flash.NAVY, 17, 3, false))
	_palco.add_child(_barra_fill)

	_passo = Label.new()
	_passo.position = Vector2(0, 548)
	_passo.size = Vector2(LARGURA, 40)
	_passo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_passo.add_theme_font_override("font", Flash.fonte_texto())
	_passo.add_theme_font_size_override("font_size", 28)
	_passo.add_theme_color_override("font_color", Color.WHITE)
	_passo.add_theme_color_override("font_outline_color", Flash.NAVY)
	_passo.add_theme_constant_override("outline_size", 8)
	_palco.add_child(_passo)

	_dica = Label.new()
	_dica.text = "Dica do Bentinho: " + String(DICAS[randi() % DICAS.size()])
	_dica.position = Vector2(0, 640)
	_dica.size = Vector2(LARGURA, 36)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dica.add_theme_font_override("font", Flash.fonte_sistema())
	_dica.add_theme_font_size_override("font_size", 20)
	_dica.add_theme_color_override("font_color", Color.WHITE)
	_dica.add_theme_color_override("font_outline_color", Color("14522A"))
	_dica.add_theme_constant_override("outline_size", 6)
	_palco.add_child(_dica)


## `valor` 0..1 (a barra anda até lá) e a frase do passo atual.
func definir(valor: float, texto := "") -> void:
	_alvo = clampf(valor, 0.0, 1.0)
	if texto != "" and _passo:
		_passo.text = texto


func progresso() -> float:
	return _alvo


func _process(dt: float) -> void:
	_t += dt
	_valor = move_toward(_valor, _alvo, dt * 0.9)
	if _barra_fill:
		_barra_fill.size.x = maxf(0.0, _barra_larg * _valor)
	var passo := floorf(_t * 12.0) / 12.0
	var s := sin(passo * 5.0)
	if _mascote:
		_mascote.position.y = _base_y - maxf(0.0, s) * 16.0
		_mascote.scale = Vector2(1.0 + 0.02 * -s, 1.0 + 0.035 * s)
	_titulo.text = "Carregando" + ".".repeat(int(_t * 3.0) % 4)


## Barra cheia e "Pronto!" por um instante (o jogador vê que acabou).
func finalizar() -> void:
	if _saindo:
		return
	_alvo = 1.0
	_valor = 1.0
	if _barra_fill:
		_barra_fill.size.x = _barra_larg
	_passo.text = "Pronto!"
	await get_tree().create_timer(0.2).timeout


## Fade curto e remoção da tela.
func desaparecer() -> void:
	if _saindo:
		return
	_saindo = true
	_cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_raiz, "modulate:a", 0.0, 0.2)
	await t.finished
	if ultima == self:
		ultima = null
	queue_free()


func encerrar() -> void:
	await finalizar()
	await desaparecer()
