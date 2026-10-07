class_name TitoCastelinho
extends RefCounted
## Tudo do Tito (personagem FICTÍCIO, 9 anos) que o Castelinho precisa desenhar: a figura low-poly da época E1967,
## os desenhos de giz de cera, o cartaz de PROCURA-SE, as marcas de altura e os pequenos objetos (balde, disco).
##
## As texturas oficiais vêm do agente Visor/UI em assets/ui/tito/ (desenho_1..7.png, procura_se.png,
## marcas_altura.png). Se o arquivo ainda não existe, `textura()` gera um PLACEHOLDER por código (mesmo estilo,
## giz de cera, "T" assinado ao contrário) e o jogo segue funcionando; quando o arquivo aparece, ele vence.
##
## Estética (docs/PLANO.md §3 e V2 §1): boneco PS1 de caixas, rosto de dois pontos; nada realista, nada gráfico.

const PASTA := "res://assets/ui/tito/"
static var _cache := {}

# ------------------------------------------------------------------ texturas (arquivo oficial ou placeholder)
static func textura(nome: String) -> Texture2D:
	if _cache.has(nome):
		return _cache[nome]
	var tex: Texture2D = null
	var caminho := PASTA + nome + ".png"
	if ResourceLoader.exists(caminho):
		tex = load(caminho)
	if tex == null:
		tex = _gerar(nome)
	_cache[nome] = tex
	return tex


## true se o arquivo oficial existe (senão a textura é o placeholder daqui).
static func tem_oficial(nome: String) -> bool:
	return ResourceLoader.exists(PASTA + nome + ".png")


static func _gerar(nome: String) -> Texture2D:
	var img: Image
	match nome:
		"procura_se":
			img = _img_procura_se()
		"marcas_altura":
			img = _img_marcas()
		_:
			var n := int(nome.trim_prefix("desenho_")) if nome.begins_with("desenho_") else 1
			img = _img_desenho(clampi(n, 1, 7))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ primitivas de desenho (giz de cera)
static func _px(img: Image, x: int, y: int, cor: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, cor)


static func _ret(img: Image, x0: int, y0: int, w: int, h: int, cor: Color) -> void:
	img.fill_rect(Rect2i(x0, y0, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height())), cor)


static func _linha(img: Image, a: Vector2, b: Vector2, cor: Color, esp := 2) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(maxi(n, 1)))
		_ret(img, int(p.x) - esp / 2, int(p.y) - esp / 2, esp, esp, cor)


static func _circ(img: Image, c: Vector2, r: float, cor: Color, cheio := false, esp := 2) -> void:
	if cheio:
		for y in range(int(c.y - r), int(c.y + r) + 1):
			for x in range(int(c.x - r), int(c.x + r) + 1):
				if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r * r:
					_px(img, x, y, cor)
		return
	var passos := int(r * 6.0) + 8
	for i in passos:
		var a := TAU * float(i) / float(passos)
		_ret(img, int(c.x + cos(a) * r) - esp / 2, int(c.y + sin(a) * r) - esp / 2, esp, esp, cor)


## Boneco palito.
static func _palito(img: Image, base: Vector2, alt: float, cor: Color) -> void:
	var cab := base + Vector2(0, -alt * 0.78)
	_circ(img, cab, alt * 0.12, cor, false, 2)
	_linha(img, base + Vector2(0, -alt * 0.66), base + Vector2(0, -alt * 0.32), cor, 2)
	_linha(img, base + Vector2(-alt * 0.2, -alt * 0.5), base + Vector2(alt * 0.2, -alt * 0.5), cor, 2)
	_linha(img, base + Vector2(0, -alt * 0.32), base + Vector2(-alt * 0.14, 0), cor, 2)
	_linha(img, base + Vector2(0, -alt * 0.32), base + Vector2(alt * 0.14, 0), cor, 2)


## Castelinho infantil: corpo, duas torres de ameias, porta e janelas.
static func _castelo(img: Image, x: int, y: int, w: int, h: int, cor: Color, janela := Color(0.2, 0.3, 0.6)) -> void:
	_ret(img, x, y + h / 3, w, h * 2 / 3, cor)
	_ret(img, x, y, w / 4, h, cor)
	_ret(img, x + w - w / 4, y, w / 4, h, cor)
	for t in [x, x + w - w / 4]:
		for k in 3:
			_ret(img, t + k * (w / 12), y - 5, maxi(2, w / 16), 6, cor)
	_ret(img, x + w / 2 - 5, y + h - 16, 10, 16, Color(0.35, 0.2, 0.1))
	_ret(img, x + w / 4 + 5, y + h / 2, 6, 8, janela)
	_ret(img, x + w - w / 4 - 11, y + h / 2, 6, 8, janela)


## Assinatura "TITO" com o T ao contrário (de cabeça para baixo), em giz de cera.
static func _assinatura(img: Image, x: int, y: int, cor: Color, escala := 1) -> void:
	var s := escala
	# T de cabeça para baixo: haste vertical com a barra EMBAIXO
	_ret(img, x + 3 * s, y, 2 * s, 10 * s, cor)
	_ret(img, x, y + 9 * s, 8 * s, 2 * s, cor)
	# I
	_ret(img, x + 11 * s, y, 2 * s, 11 * s, cor)
	# T normal
	_ret(img, x + 15 * s, y, 8 * s, 2 * s, cor)
	_ret(img, x + 18 * s, y, 2 * s, 11 * s, cor)
	# O
	_ret(img, x + 26 * s, y, 8 * s, 2 * s, cor)
	_ret(img, x + 26 * s, y + 9 * s, 8 * s, 2 * s, cor)
	_ret(img, x + 26 * s, y, 2 * s, 11 * s, cor)
	_ret(img, x + 32 * s, y, 2 * s, 11 * s, cor)


static func _papel(w: int, h: int, cor := Color(0.97, 0.95, 0.86)) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(cor)
	var r := RandomNumberGenerator.new()
	r.seed = 1967
	for i in (w * h) / 40:
		var v := r.randf_range(-0.04, 0.0)
		_px(img, r.randi() % w, r.randi() % h, Color(cor.r + v, cor.g + v, cor.b + v))
	# borda irregular (papel rasgado do caderno)
	for x in w:
		_px(img, x, 0, Color(0.8, 0.78, 0.7))
		_px(img, x, h - 1, Color(0.8, 0.78, 0.7))
	for y in h:
		_px(img, 0, y, Color(0.8, 0.78, 0.7))
		_px(img, w - 1, y, Color(0.8, 0.78, 0.7))
	return img


## Placeholder dos 7 desenhos do V2_ROTEIRO §5. 128 x 96 px.
static func _img_desenho(n: int) -> Image:
	var w := 128
	var h := 96
	var img := _papel(w, h, Color(0.07, 0.07, 0.08) if n == 6 else Color(0.97, 0.95, 0.86))
	var preto := Color(0.15, 0.15, 0.2)
	var vermelho := Color(0.85, 0.2, 0.18)
	var amarelo := Color(0.98, 0.82, 0.2)
	var azul := Color(0.2, 0.4, 0.85)
	var verde := Color(0.25, 0.65, 0.3)
	var cinza := Color(0.55, 0.55, 0.58)
	match n:
		1:   # castelo com sol e boneco palito
			_circ(img, Vector2(108, 16), 9, amarelo, true)
			for k in 8:
				var a := TAU * float(k) / 8.0
				_linha(img, Vector2(108, 16) + Vector2(cos(a), sin(a)) * 12, Vector2(108, 16) + Vector2(cos(a), sin(a)) * 18, amarelo, 2)
			_castelo(img, 26, 28, 56, 44, vermelho)
			_ret(img, 0, 72, w, 6, verde)
			_palito(img, Vector2(98, 72), 30, preto)
			_assinatura(img, 8, 80, azul)
		2:   # ele e a mãe na praia
			_circ(img, Vector2(20, 16), 8, amarelo, true)
			_ret(img, 0, 66, w, 30, Color(0.95, 0.85, 0.5))
			_ret(img, 0, 50, w, 16, azul)
			_palito(img, Vector2(52, 74), 44, preto)       # mãe (maior)
			_linha(img, Vector2(44, 74), Vector2(60, 74), preto, 2)   # saia
			_palito(img, Vector2(76, 76), 26, preto)       # ele
			_linha(img, Vector2(58, 54), Vector2(72, 58), preto, 2)   # mãos dadas
			_assinatura(img, 84, 82, vermelho)
		3:   # castelo com uma mulher branca na janela da torre
			_castelo(img, 30, 14, 60, 62, cinza)
			_ret(img, 36, 28, 12, 18, Color(0.1, 0.1, 0.14))      # janela da torre
			_ret(img, 39, 31, 6, 14, Color(0.97, 0.97, 0.97))     # mulher branca
			_circ(img, Vector2(42, 30), 3, Color(0.97, 0.97, 0.97), true)
			_ret(img, 0, 76, w, 6, verde)
			_palito(img, Vector2(104, 76), 26, preto)
			_assinatura(img, 6, 82, azul)
		4:   # ele embaixo do castelo, e o castelo em cima dele, todo em pedra
			for yy in range(6, 60, 8):
				for xx in range(10, 118, 14):
					_ret(img, xx + (yy / 8 % 2) * 7, yy, 12, 7, Color(0.45, 0.45, 0.5))
			_ret(img, 0, 66, w, 30, Color(0.4, 0.3, 0.2))
			_palito(img, Vector2(64, 92), 22, preto)
			_assinatura(img, 6, 84, vermelho)
		5:   # muita água azul, e ele pequeno no meio
			for yy in range(0, h, 6):
				for xx in range(-8, w, 14):
					_linha(img, Vector2(xx, yy + 4), Vector2(xx + 7, yy), azul, 2)
					_linha(img, Vector2(xx + 7, yy), Vector2(xx + 14, yy + 4), azul, 2)
			_palito(img, Vector2(64, 56), 14, preto)
			_assinatura(img, 6, 82, vermelho)
		6:   # página toda preta, com dois olhos
			var branco := Color(0.96, 0.96, 0.96)
			_circ(img, Vector2(46, 46), 9, branco, true)
			_circ(img, Vector2(82, 46), 9, branco, true)
			_circ(img, Vector2(46, 48), 4, Color(0.05, 0.05, 0.06), true)
			_circ(img, Vector2(82, 48), 4, Color(0.05, 0.05, 0.06), true)
			_assinatura(img, 8, 82, Color(0.5, 0.5, 0.55))
		7:   # o jogador, de costas, com o Visor na mão
			_ret(img, 46, 36, 36, 46, azul)                       # costas (casaco)
			_circ(img, Vector2(64, 28), 12, Color(0.35, 0.22, 0.12), true)   # cabeça de costas
			_ret(img, 82, 54, 10, 8, vermelho)                    # Visor (plástico vermelho)
			_circ(img, Vector2(85, 58), 2, Color(1, 1, 1), true)
			_ret(img, 50, 82, 10, 12, preto)
			_ret(img, 68, 82, 10, 12, preto)
			_assinatura(img, 6, 82, vermelho)
	# quatro riscos de giz por cima (aspecto de giz de cera)
	var r := RandomNumberGenerator.new()
	r.seed = 100 + n
	for i in 90:
		var xx := r.randi() % w
		var yy := r.randi() % h
		var c := img.get_pixel(xx, yy)
		_px(img, xx, yy, c.lerp(Color(1, 1, 1), 0.12))
	return img


# ------------------------------------------------------------------ fonte bitmap 5x7 (cartaz e marcas)
const _FONTE := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "00100", "00100", "00100"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"/": ["00001", "00001", "00010", "00100", "01000", "10000", "10000"],
	".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
	" ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}


static func _texto(img: Image, texto: String, x: int, y: int, escala: int, cor: Color) -> int:
	var cx := x
	for ch in texto:
		var g: Array = _FONTE.get(ch, _FONTE[" "])
		for ly in 7:
			var linha: String = g[ly]
			for lx in 5:
				if linha[lx] == "1":
					_ret(img, cx + lx * escala, y + ly * escala, escala, escala, cor)
		cx += 6 * escala
	return cx - x


static func _largura_texto(texto: String, escala: int) -> int:
	return texto.length() * 6 * escala - escala


## Cartaz de PROCURA-SE (placeholder). 96 x 128 px: o rosto é um desenho de giz, sem realismo.
static func _img_procura_se() -> Image:
	var w := 96
	var h := 128
	var img := _papel(w, h, Color(0.94, 0.92, 0.84))
	var preto := Color(0.12, 0.12, 0.14)
	var vermelho := Color(0.7, 0.12, 0.1)
	var t1 := "PROCURA-SE"
	_texto(img, t1, (w - _largura_texto(t1, 1)) / 2 - 1, 6, 1, vermelho)
	_ret(img, 6, 17, w - 12, 2, vermelho)
	# retrato de giz: moldura, cabeça redonda, cabelo, dois pontos de olho
	_ret(img, 20, 24, 56, 50, Color(0.8, 0.78, 0.7))
	_ret(img, 22, 26, 52, 46, Color(0.9, 0.88, 0.8))
	_circ(img, Vector2(48, 52), 17, Color(0.93, 0.75, 0.6), true)
	_ret(img, 31, 34, 34, 8, Color(0.3, 0.2, 0.1))
	_ret(img, 41, 50, 3, 3, preto)
	_ret(img, 53, 50, 3, 3, preto)
	_ret(img, 43, 59, 10, 2, preto)
	var t2 := "TITO"
	_texto(img, t2, (w - _largura_texto(t2, 2)) / 2, 80, 2, preto)
	var t3 := "9 ANOS"
	_texto(img, t3, (w - _largura_texto(t3, 1)) / 2, 98, 1, preto)
	var t4 := "DESAPARECIDO"
	_texto(img, t4, (w - _largura_texto(t4, 1)) / 2, 108, 1, preto)
	var t5 := "DESDE 12/03/1967"
	_texto(img, t5, (w - _largura_texto(t5, 1)) / 2 + 1, 118, 1, preto)
	return img


## Marcas de altura a lápis na parede (placeholder): "TITO 6", "TITO 7", "TITO 8", "TITO 9" e depois nada.
## 64 x 96 px, fundo transparente (o nível só mostra em E1975).
static func _img_marcas() -> Image:
	var w := 64
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var lapis := Color(0.28, 0.27, 0.3, 0.95)
	var alturas := [78, 60, 44, 30]       # de baixo para cima: 6, 7, 8, 9 anos
	var anos := ["6", "7", "8", "9"]
	for i in 4:
		var y: int = alturas[i]
		_ret(img, 2, y, 26, 2, lapis)
		_texto(img, "TITO " + String(anos[i]), 31, y - 6, 1, lapis)
	# a última marca fica mais fraca: depois do 9, nada
	_ret(img, 2, 14, 12, 1, Color(0.28, 0.27, 0.3, 0.35))
	return img


# ------------------------------------------------------------------ quads de textura (cartazes, desenhos, marcas)
## Folha de papel/decalque pendurado. `largura` em metros; a altura segue a proporção da textura.
## `yaw` em graus: a frente do quad olha para +Z local rodado por `yaw` (como os painéis). Folga de 3 cm.
static func folha(pai: Node, nome: String, pos: Vector3, yaw: float, largura: float, camada := 2, recorte := false, roll := 0.0) -> MeshInstance3D:
	var tex := textura(nome)
	var alt := largura * float(tex.get_height()) / float(tex.get_width())
	var mi := MeshInstance3D.new()
	mi.name = "Folha_" + nome
	var qm := QuadMesh.new()
	qm.size = Vector2(largura, alt)
	mi.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	if recorte:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(0, yaw, roll)
	mi.layers = camada
	pai.add_child(mi)
	return mi


## Cartaz de PROCURA-SE colado "por cima" de um painel, levemente torto. Revisão V2: tamanho de folha A3 (50 cm) e
## cobrindo um terço do texto do painel (antes 34 cm no canto: a 3 m, à noite, não se lia que era um cartaz).
static func cartaz_sobre(pai: Node, painel: Node3D, canto := 1, roll := 4.0) -> MeshInstance3D:
	var yaw := painel.rotation_degrees.y
	var b := Basis.from_euler(Vector3(0, deg_to_rad(yaw), 0))
	var off := b * Vector3(0.4 * canto, -0.08, 0.11)
	return folha(pai, "procura_se", painel.position + off, yaw, 0.5, 2 if _dentro(painel.position) else 1, false, roll * canto)


static func _dentro(p: Vector3) -> bool:
	return p.x < -5.0 and p.z < -11.0


# ------------------------------------------------------------------ objetos
## Balde vermelho de praia (tronco de cone aberto). Raiz com base em y = 0.
static func criar_balde(escala := 1.0) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "BaldeVermelho"
	var m := Malha.new()
	var vermelho := Castelinho.mat_cor(Color(0.86, 0.1, 0.08), 0.5, true)
	var escuro := Castelinho.mat_cor(Color(0.3, 0.03, 0.03), 0.8)
	var h := 0.22 * escala
	EntornoCastelinho.prisma(m, vermelho, Vector3.ZERO, h, 0.1 * escala, 0.13 * escala, 8)
	_tampa(m, vermelho, Vector3(0, 0.002, 0), 0.1 * escala, 8, Vector3.DOWN)           # fundo
	_tampa(m, escuro, Vector3(0, h * 0.9, 0), 0.12 * escala, 8, Vector3.UP)           # boca escura, um pouco abaixo da borda
	# alça
	m.caixa(Castelinho.mat_cor(Color(0.9, 0.9, 0.9), 0.5), Vector3(-0.135 * escala, 0.2 * escala, -0.01 * escala), Vector3(0.135 * escala, 0.215 * escala, 0.01 * escala), Malha.F_TODAS)
	m.construir_instancia(raiz, "Malha", 1)
	return raiz


## Tampa circular (leque de triângulos) de um prisma.
static func _tampa(m: Malha, mat: Material, c: Vector3, r: float, lados: int, normal: Vector3) -> void:
	for k in lados:
		var a0 := TAU * float(k) / lados
		var a1 := TAU * float(k + 1) / lados
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		m.tri(mat, c, p0, p1, normal)


## Disco do Visor (CD de plástico vermelho com miolo claro) deitado, para vitrine e pedestal.
static func criar_disco(cor := Color(0.85, 0.12, 0.1)) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "DiscoVisor"
	var m := Malha.new()
	var plastico := Castelinho.mat_cor(cor, 0.35)
	var miolo := Castelinho.mat_cor(Color(0.95, 0.92, 0.8), 0.4)
	EntornoCastelinho.prisma(m, plastico, Vector3.ZERO, 0.012, 0.075, 0.075, 12)
	_tampa(m, plastico, Vector3(0, 0.012, 0), 0.075, 12, Vector3.UP)
	_tampa(m, plastico, Vector3(0, 0.0, 0), 0.075, 12, Vector3.DOWN)
	_tampa(m, miolo, Vector3(0, 0.0125, 0), 0.026, 8, Vector3.UP)
	m.construir_instancia(raiz, "Malha", 2)
	return raiz


# ------------------------------------------------------------------ a figura do Tito (só em E1967)
## Boneco PS1 de caixas: bermuda azul, camiseta clara, balde vermelho na mão esquerda, braço direito que acena.
## ~1,25 m de altura, olha para +Z local. Nós úteis: "BracoD" (acenar) e "Tronco" (cavar).
static func criar_tito() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Tito"
	var pele := Castelinho.mat_cor(Color(0.92, 0.72, 0.56), 0.9)
	var cabelo := Castelinho.mat_cor(Color(0.22, 0.14, 0.08), 0.9)
	var camisa := Castelinho.mat_cor(Color(0.93, 0.91, 0.82), 0.9)
	var bermuda := Castelinho.mat_cor(Color(0.14, 0.3, 0.72), 0.9)
	var preto := Castelinho.mat_cor(Color(0.04, 0.04, 0.05), 0.5)
	# pernas e bermuda
	var pernas := Malha.new()
	for lado in [-1.0, 1.0]:
		pernas.caixa(pele, Vector3(0.025 * lado + (0.0 if lado > 0 else -0.08), 0.0, -0.045), Vector3(0.025 * lado + (0.08 if lado > 0 else 0.0), 0.5, 0.045), Malha.F_TODAS)
		pernas.caixa(bermuda, Vector3(0.015 * lado + (0.0 if lado > 0 else -0.115), 0.4, -0.065), Vector3(0.015 * lado + (0.115 if lado > 0 else 0.0), 0.62, 0.065), Malha.F_TODAS)
	pernas.construir_instancia(raiz, "Pernas", 1)
	# tronco (nó próprio, para inclinar ao cavar): pivô no quadril
	var tronco := Node3D.new()
	tronco.name = "Tronco"
	tronco.position = Vector3(0, 0.62, 0)
	raiz.add_child(tronco)
	var tm := Malha.new()
	tm.caixa(camisa, Vector3(-0.14, 0.0, -0.08), Vector3(0.14, 0.38, 0.08), Malha.F_TODAS)
	tm.caixa(bermuda, Vector3(-0.145, -0.02, -0.085), Vector3(0.145, 0.04, 0.085), Malha.F_TODAS)
	# cabeça (cubo achatado), cabelo e dois pontos de olho (sem boca realista)
	tm.caixa(pele, Vector3(-0.1, 0.4, -0.09), Vector3(0.1, 0.62, 0.09), Malha.F_TODAS)
	tm.caixa(cabelo, Vector3(-0.108, 0.57, -0.098), Vector3(0.108, 0.66, 0.098), Malha.F_TODAS)
	tm.caixa(cabelo, Vector3(-0.108, 0.42, -0.098), Vector3(0.108, 0.6, -0.07), Malha.F_TODAS)
	tm.caixa(preto, Vector3(-0.05, 0.5, 0.088), Vector3(-0.03, 0.525, 0.094), Malha.F_TODAS)
	tm.caixa(preto, Vector3(0.03, 0.5, 0.088), Vector3(0.05, 0.525, 0.094), Malha.F_TODAS)
	# braço esquerdo (pendurado) e balde vermelho
	tm.caixa(pele, Vector3(-0.2, 0.06, -0.035), Vector3(-0.14, 0.34, 0.035), Malha.F_TODAS)
	tm.caixa(camisa, Vector3(-0.2, 0.26, -0.04), Vector3(-0.14, 0.38, 0.04), Malha.F_TODAS)
	tm.construir_instancia(tronco, "Malha", 1)
	var balde := criar_balde(1.0)
	balde.position = Vector3(-0.24, -0.2, 0.0)      # na mão esquerda (relativo ao tronco: pendurado na altura do quadril)
	tronco.add_child(balde)
	# braço direito: pivô no ombro; em repouso pende, acenando levanta
	var braco := Node3D.new()
	braco.name = "BracoD"
	braco.position = Vector3(0.17, 0.34, 0)
	tronco.add_child(braco)
	var bm := Malha.new()
	bm.caixa(camisa, Vector3(-0.03, -0.1, -0.04), Vector3(0.03, 0.0, 0.04), Malha.F_TODAS)
	bm.caixa(pele, Vector3(-0.03, -0.3, -0.035), Vector3(0.03, -0.1, 0.035), Malha.F_TODAS)
	bm.construir_instancia(braco, "Malha", 1)
	return raiz


## Animação do Tito (só roda quando visível): cava a areia por alguns segundos e depois acena para a câmera.
## `t` = tempo em segundos; `cam` = posição da câmera do jogador (global).
static func animar(tito: Node3D, t: float, cam: Vector3) -> void:
	var tronco := tito.get_node_or_null("Tronco") as Node3D
	var braco := tronco.get_node_or_null("BracoD") as Node3D if tronco else null
	if tronco == null or braco == null:
		return
	var d := cam - tito.global_position
	var alvo_yaw := atan2(d.x, d.z)
	tito.rotation.y = lerp_angle(tito.rotation.y, alvo_yaw, 0.08)
	var ciclo := fmod(t, 7.0)
	if ciclo < 3.5:
		# cavando: tronco inclinado, braço balançando perto do chão
		tronco.rotation.x = lerpf(tronco.rotation.x, 0.55 + 0.1 * sin(t * 6.0), 0.15)
		braco.rotation.z = lerpf(braco.rotation.z, 0.25 + 0.2 * sin(t * 6.0), 0.2)
		braco.rotation.x = lerpf(braco.rotation.x, -0.4, 0.2)
	else:
		# acenando: tronco reto, braço para cima balançando
		tronco.rotation.x = lerpf(tronco.rotation.x, 0.0, 0.15)
		braco.rotation.x = lerpf(braco.rotation.x, 0.0, 0.2)
		braco.rotation.z = lerpf(braco.rotation.z, 2.5 + 0.35 * sin(t * 9.0), 0.25)
