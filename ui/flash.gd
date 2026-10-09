class_name Flash
extends RefCounted
## Ajudantes visuais do estilo "Flash educativo dos anos 2000" (cores chapadas, contorno grosso,
## botões gel) e da corrupção da interface. Tudo estático: use `Flash.xxx()` em qualquer lugar.
##
## Cores:   Flash.AZUL, Flash.AMARELO, Flash.VERDE, Flash.VERMELHO, Flash.CREME, Flash.NAVY...
## Fontes:  Flash.fonte_titulo(), fonte_texto(), fonte_erro(), fonte_sistema()
## Imagens: Flash.mascote("bentinho", corrompido), Flash.icone("castelo")
## Texto:   Flash.corromper(texto, corruption), Flash.engasgar(texto)
## Modais:  Flash.abrir_ui() / Flash.fechar_ui()  (solta o mouse, trava o jogador, flag ui_aberta)

const NAVY := Color("1B2250")
const AZUL := Color("2D8CFF")
const AZUL_CLARO := Color("8FD0FF")
const CEU := Color("5BB8FF")
const AMARELO := Color("FFD23F")
const VERDE := Color("5CCB4A")
const VERMELHO := Color("FF5A4F")
const LARANJA := Color("FF9A2E")
const ROSA := Color("FF5FA2")
const CREME := Color("FFF6DA")
const BRANCO := Color.WHITE
const PEDRA := Color("C9806A")

const LIMIAR_CORRUPCAO := 0.3   # acima disso a interface começa a falhar
const TOTAL_SELOS := 6          # 3 quizzes das salas 2/5/8 + 3 perguntas do quiz final

const CAMINHO_FONTES := "res://assets/fonts/"
const CAMINHO_MASCOTES := "res://assets/ui/mascotes/"
const CAMINHO_ICONES := "res://assets/ui/icones/"

static var _fontes := {}
static var _texturas := {}
static var _modais := 0


# ---------------------------------------------------------------- fontes
## Baloo 2 ExtraBold: títulos, botões, contadores.
static func fonte_titulo() -> Font:
	if not _fontes.has("titulo"):
		var fv := FontVariation.new()
		fv.base_font = load(CAMINHO_FONTES + "Baloo2-Latin.ttf")
		fv.variation_opentype = {_tag_wght(): 800.0}
		_fontes["titulo"] = fv
	return _fontes["titulo"]


## Comic Neue Bold: texto corrido, balões, painéis.
static func fonte_texto() -> Font:
	if not _fontes.has("texto"):
		_fontes["texto"] = load(CAMINHO_FONTES + "ComicNeue-Bold.ttf")
	return _fontes["texto"]


## VT323: erros de sistema e texto corrompido.
static func fonte_erro() -> Font:
	if not _fontes.has("erro"):
		_fontes["erro"] = load(CAMINHO_FONTES + "VT323-Latin.ttf")
	return _fontes["erro"]


## Arimo: a moldura institucional da "prefeitura" (a parte sem graça).
static func fonte_sistema() -> Font:
	if not _fontes.has("sistema"):
		var fv := FontVariation.new()
		fv.base_font = load(CAMINHO_FONTES + "Arimo-Latin.ttf")
		fv.variation_opentype = {_tag_wght(): 500.0}
		_fontes["sistema"] = fv
	return _fontes["sistema"]


static func _tag_wght() -> int:
	return (0x77 << 24) | (0x67 << 16) | (0x68 << 8) | 0x74   # "wght"


# ---------------------------------------------------------------- imagens
static func textura(caminho: String) -> Texture2D:
	if not _texturas.has(caminho):
		_texturas[caminho] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _texturas[caminho]


## nome: "bentinho", "taina" ou "quico".
static func mascote(nome: String, corrompido := false) -> Texture2D:
	var arq := nome + ("_corrompido" if corrompido else "")
	return textura(CAMINHO_MASCOTES + arq + ".svg")


static func icone(nome: String) -> Texture2D:
	return textura(CAMINHO_ICONES + nome + ".svg")


## TextureRect já configurado (a ordem importa: expand_mode antes de size, senão o tamanho mínimo da
## textura vence). `tam` é o tamanho final em pixels.
static func imagem(tex: Texture2D, tam: Vector2, pos := Vector2.ZERO, espelhar := false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.flip_h = espelhar
	tr.position = pos
	tr.size = tam
	return tr


# ---------------------------------------------------------------- estilos
## Caixa chapada com contorno grosso e sombra dura (estilo vetor Flash).
static func caixa(fundo: Color, borda := NAVY, raio := 18, largura_borda := 4, sombra := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura_borda)
	s.set_corner_radius_all(raio)
	s.corner_detail = 8
	if sombra:
		s.shadow_color = Color(NAVY.r, NAVY.g, NAVY.b, 0.55)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, 5)
	return s


## Aproxima uma cor do cinza conforme `t` (0..1). Usado pela corrupção (cai a saturação).
static func dessaturar(c: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var cinza := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	return Color(lerpf(c.r, cinza, t), lerpf(c.g, cinza, t), lerpf(c.b, cinza, t), c.a)


## Fator de dessaturação da interface para o valor atual de corruption (0 até ~0.3, depois sobe).
static func fator_dessat(corr: float) -> float:
	return clampf(remap(corr, LIMIAR_CORRUPCAO, 1.0, 0.0, 0.9), 0.0, 0.9)


# ---------------------------------------------------------------- texto corrompido
## Troca letras por homógrafos (o→0, a→4...). Probabilidade cresce com `corr`.
## Abaixo de LIMIAR_CORRUPCAO devolve o texto intacto.
static func corromper(texto: String, corr: float) -> String:
	if corr <= LIMIAR_CORRUPCAO:
		return texto
	var p := remap(corr, LIMIAR_CORRUPCAO, 1.0, 0.04, 0.42)
	var troca_basica := {"o": "0", "O": "0", "a": "4", "A": "4"}
	var troca_forte := {"e": "3", "E": "3", "i": "1", "s": "5", "l": "I", "t": "7"}
	var saida := ""
	for ch in texto:
		var t = troca_basica.get(ch)
		if t == null and corr > 0.5:
			t = troca_forte.get(ch)
		if t != null and randf() < p:
			saida += t
		else:
			saida += ch
	return saida


## "Engasgo": repete o início de uma palavra ("vi-vi-vi-visita"). Devolve {texto, ini, fim} onde
## ini/fim marcam (em caracteres) a região repetida, para o balão acelerar e chiar nela.
static func engasgar(texto: String) -> Dictionary:
	var palavras := texto.split(" ")
	var candidatas: Array[int] = []
	for i in palavras.size():
		var limpa := palavras[i].strip_edges()
		if limpa.length() >= 4 and limpa.unicode_at(0) > 64:
			candidatas.append(i)
	if candidatas.is_empty():
		return {"texto": texto, "ini": -1, "fim": -1}
	var alvo: int = candidatas[randi() % candidatas.size()]
	var palavra := palavras[alvo]
	var n := 2 if palavra.length() < 6 else 3
	var prefixo := palavra.substr(0, n)
	var rep := ""
	for k in randi_range(2, 3):
		rep += prefixo + "-"
	var antes := " ".join(palavras.slice(0, alvo))
	var ini := antes.length() + (1 if alvo > 0 else 0)
	palavras[alvo] = rep + palavra
	return {"texto": " ".join(palavras), "ini": ini, "fim": ini + rep.length()}


# ---------------------------------------------------------------- modais (telas de leitura, diploma...)
## Jogador: contador de travas em vez de um booleano, para dois sistemas poderem travar ao mesmo tempo.
static func travar_jogador(travar: bool) -> void:
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null:
		return
	var p := arv.get_first_node_in_group("player")
	if p == null or not ("pode_mover" in p):
		return
	var n: int = p.get_meta("travas_ui", 0) + (1 if travar else -1)
	n = maxi(0, n)
	p.set_meta("travas_ui", n)
	p.pode_mover = n == 0


## Abre uma tela modal: solta o mouse, trava o jogador e liga a flag `ui_aberta` (o main.gd não pausa).
static func abrir_ui() -> void:
	_modais += 1
	if _modais == 1:
		GameState.set_flag("ui_aberta", true)
		Celular.soltar_mouse()
	travar_jogador(true)


## Fecha a modal. Chame a partir de um evento de clique/tecla: o navegador exige isso para recapturar o mouse.
static func fechar_ui() -> void:
	_modais = maxi(0, _modais - 1)
	travar_jogador(false)
	if _modais == 0:
		if GameState.jogando:
			Celular.capturar_mouse()
		GameState.set_flag("ui_aberta", false)


static func resetar_ui() -> void:
	_modais = 0
	GameState.flags.erase("ui_aberta")


static func raiz() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Desenha uma estrela de 5 pontas (usada em recompensas, diploma e selos).
static func pontos_estrela(centro: Vector2, raio_ext: float, raio_int := -1.0, rot := -PI / 2.0) -> PackedVector2Array:
	if raio_int < 0.0:
		raio_int = raio_ext * 0.42
	var pts := PackedVector2Array()
	for i in 10:
		var r := raio_ext if i % 2 == 0 else raio_int
		var a := rot + i * PI / 5.0
		pts.append(centro + Vector2(cos(a), sin(a)) * r)
	return pts
