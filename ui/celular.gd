class_name Celular
extends RefCounted
## Modo celular (módulo 8): controles de toque na tela, sem depender do ponteiro capturado (o iPhone não tem).
## Tudo estático, como o Opcoes. Em desktop `ativo` é falso e NADA muda: os atalhos abaixo (capturar_mouse etc.)
## fazem exatamente o que o código antigo fazia.
##
##   Celular.ativo               true = tela de toque ligada (controles, pausa por botão, retrato avisa)
##   Celular.modo                "auto" | "sempre" | "nunca" (opção do jogador, guardada pelo Opcoes)
##   Celular.detectar()          reavalia `ativo` a partir do modo (e da página, na web)
##   Celular.capturar_mouse() / soltar_mouse()   no celular não fazem nada (sem pointer lock)
##   Celular.olhar_liberado()    o jogador pode olhar/agir? (celular ligado OU mouse capturado)
##   Celular.dica(teclado, toque)  texto de dica conforme o aparelho
##   Celular.adaptar(texto)      troca "segure Q" etc. por "segure o botão Visor" no celular
##   Celular.margens()           Vector4(esq, topo, dir, baixo) da área segura (entalhe) em unidades do canvas

const MODOS: Array[String] = ["auto", "sempre", "nunca"]
const ESCALA_UI := 1.35        # aumento da interface durante o jogo (limitado pela proporção da tela)
const MARGEM_MIN := 12.0       # margem mínima das bordas, em unidades do canvas

static var ativo := false
static var modo := "auto"
## Pausa pelo botão do celular (no desktop quem pausa é o mouse solto).
static var pausa_toque := false
## O celular está em pé (altura > largura): o aviso "vire o celular" cobre tudo e o jogo pausa.
static var retrato := false

## Raios dos botões de toque (ControlesToque) e deslocamento do botão mais à esquerda do aglomerado (Visor/Correr).
const R_GRANDE := 56.0
const R_MEDIO := 47.0
const BOTOES_ESQ := 132.0

## Perfil de qualidade do celular (aplicar_qualidade).
const ESCALA_3D := 0.7
const FPS_MAX := 30
const MAX_OMNI := 3            # OmniLight3D ligadas ao mesmo tempo no Castelinho
const FATOR_PARTICULAS := 0.5

static var _m_cache := Vector4(MARGEM_MIN, MARGEM_MIN, MARGEM_MIN, MARGEM_MIN)
static var _m_hora := -10.0
static var _eh_ios := -1       # -1 ainda não perguntou, 0 não, 1 sim


# ---------------------------------------------------------------- detecção
## Reavalia `ativo`. `sempre`/`nunca` mandam; `auto` pergunta à página (web) ou ao sistema (Android/iOS nativo).
static func detectar() -> bool:
	var antes := ativo
	match modo:
		"sempre":
			ativo = true
		"nunca":
			ativo = false
		_:
			ativo = _detectar_auto()
	if ativo != antes:
		_ao_mudar(antes)
	aplicar_ambiente()
	return ativo


static func _detectar_auto() -> bool:
	if OS.get_cmdline_user_args().has("--celular"):
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("window.castelinhoToque ? window.castelinhoToque() : false", true)
		return r == true
	return OS.has_feature("mobile")


static func _ao_mudar(antes: bool) -> void:
	if ativo and not antes:
		# desktop -> celular com o jogo rodando: o mouse deixa de mandar, então fica pausado até apertar Continuar
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pausa_toque = _jogando()
	elif antes and not ativo:
		pausa_toque = false
		retrato = false
		Input.action_release("correr")
		Input.action_release("visor")
		for a in ["frente", "tras", "esquerda", "direita"]:
			Input.action_release(a)


static func _jogando() -> bool:
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or not arv.root.has_node("GameState"):
		return false
	return bool(arv.root.get_node("GameState").jogando)


## Ajusta o que depende de `ativo`: o clique do mouse deixa de ser "interagir" (um toque qualquer virava clique
## emulado e interagia sem querer) e a escala volta a 1.0 se desligou.
static func aplicar_ambiente() -> void:
	if InputMap.has_action("interagir"):
		var tem := false
		for ev in InputMap.action_get_events("interagir"):
			if ev is InputEventMouseButton:
				tem = true
				if ativo:
					InputMap.action_erase_event("interagir", ev)
		if not ativo and not tem:
			var clique := InputEventMouseButton.new()
			clique.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event("interagir", clique)
	if not ativo:
		aplicar_escala(false)
	aplicar_qualidade()


## Interface maior durante o jogo (texto legível no celular). `jogo` = jogando, sem tela cheia aberta nem pausa:
## títulos, painéis, diploma e menus foram desenhados para 1280x720 e ficam na escala 1.0.
## A escala é limitada pela proporção da tela para o canvas nunca ficar mais estreito que ~1040 (balão da Guia).
static func aplicar_escala(jogo: bool) -> void:
	var raiz := _raiz()
	if raiz == null:
		return
	var f := 1.0
	if ativo and retrato:
		f = 1280.0 / 560.0   # em pé o canvas teria 1280 de largura: o aviso "vire o celular" precisa ficar legível
	elif ativo and jogo:
		var tam := Vector2(DisplayServer.window_get_size())
		var a: float = tam.x / tam.y if tam.y > 0.0 else 16.0 / 9.0
		f = clampf(0.69 * a, 1.0, ESCALA_UI)
	if not is_equal_approx(raiz.content_scale_factor, f):
		raiz.content_scale_factor = f


static func _raiz() -> Window:
	var arv := Engine.get_main_loop() as SceneTree
	return arv.root if arv else null


# ---------------------------------------------------------------- mouse
static func capturar_mouse() -> void:
	if not ativo:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func soltar_mouse() -> void:
	if not ativo:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## O jogador pode olhar e agir? No celular sempre; no desktop só com o mouse capturado.
static func olhar_liberado() -> bool:
	return ativo or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- textos
## Texto de dica: `teclado` no desktop, `toque` no celular.
static func dica(teclado: String, toque: String) -> String:
	return toque if ativo else teclado


const _TROCAS: Array = [
	["segure Q", "segure o botão Visor"], ["Segure Q", "Segure o botão Visor"],
	["(Q)", "(botão Visor)"],
	["Aperta F para ligar e desligar", "Toque em Lanterna para ligar e desligar"],
	["Aperte 1 a 5 (ou a rolagem do mouse) para trocar de disco", "Toque nos discos, no canto, para trocar"],
	["Esc solta o mouse e pausa a visita.", "O botão de pausa, no canto, para a visita."],
	["Aperte E (ou clique) para ler os painéis!", "Toque em Interagir para ler os painéis!"],
	["Segure Shift para correr, mas o fôlego acaba!", "Toque em Correr para correr, mas o fôlego acaba!"],
	["Clique ou [E] para lançar a tarrafa", "Toque em Interagir para lançar a tarrafa"],
	["(clique ou E)", "(toque em Interagir)"],
	["tecla 5", "disco 5"],
]

## Borda esquerda (x) do aglomerado de botões da direita, em unidades do canvas de largura `vp_larg`.
## A caixa de fala da Guia termina antes dela para os botões não cobrirem o texto.
static func borda_botoes(vp_larg: float) -> float:
	var m := margens()
	return vp_larg - m.z - R_GRANDE - 6.0 - BOTOES_ESQ - R_MEDIO - 10.0


# ---------------------------------------------------------------- qualidade (só no celular)
static var _qualidade := false

## Perfil leve: 3D a 70% da resolução (a interface continua nítida), 30 quadros por segundo.
## No desktop não faz nada (e desfaz se o modo celular foi desligado depois).
static func aplicar_qualidade() -> void:
	var raiz := _raiz()
	if ativo and not _qualidade:
		_qualidade = true
		if raiz:
			raiz.scaling_3d_scale = ESCALA_3D
		Engine.max_fps = FPS_MAX
	elif not ativo and _qualidade:
		_qualidade = false
		if raiz:
			raiz.scaling_3d_scale = 1.0
		Engine.max_fps = 0


## Quantas OmniLight3D ligadas no máximo (no celular, no máximo MAX_OMNI).
static func limite_luzes(n: int) -> int:
	return mini(n, MAX_OMNI) if ativo else n


## Metade das partículas de CPU no celular (chamar depois de definir `amount`).
static func reduzir_particulas(p: CPUParticles3D) -> void:
	if ativo:
		p.amount = maxi(1, int(p.amount * FATOR_PARTICULAS))


## Troca referências a teclas por botões da tela (só no celular; no desktop devolve o texto como veio).
static func adaptar(texto: String) -> String:
	if not ativo:
		return texto
	for par in _TROCAS:
		if texto.contains(par[0]):
			texto = texto.replace(par[0], par[1])
	return texto


# ---------------------------------------------------------------- tela
## iPhone/iPad no Safari: sem tela cheia pela página (só "Adicionar à Tela de Início").
static func eh_ios() -> bool:
	if _eh_ios < 0:
		_eh_ios = 0
		if OS.has_feature("web"):
			var r: Variant = JavaScriptBridge.eval("window.castelinhoIOS ? window.castelinhoIOS() : false", true)
			_eh_ios = 1 if r == true else 0
	return _eh_ios == 1


## Esquece o cache das margens (a tela girou ou mudou de tamanho).
static func recalcular_margens() -> void:
	_m_hora = -10.0


## Área segura (entalhe, barra de gestos) em unidades do canvas, MAIS a margem mínima. Recalcula no máximo 1x/s.
static func margens() -> Vector4:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _m_hora > 1.0:
		_m_hora = agora
		_m_cache = _calcular_margens()
	return _m_cache


static func _calcular_margens() -> Vector4:
	var m := Vector4.ZERO
	var raiz := _raiz()
	var vp := raiz.get_visible_rect().size if raiz else Vector2(1280, 720)
	if OS.has_feature("web"):
		var js: Variant = JavaScriptBridge.eval("window.castelinhoSeguro ? window.castelinhoSeguro() : ''", true)
		var dados: Variant = JSON.parse_string(str(js)) if js != null and str(js) != "" else null
		if dados is Dictionary:
			var w: float = maxf(1.0, float(dados.get("w", 1.0)))
			var h: float = maxf(1.0, float(dados.get("h", 1.0)))
			var rx := vp.x / w
			var ry := vp.y / h
			m = Vector4(float(dados.get("l", 0.0)) * rx, float(dados.get("t", 0.0)) * ry,
				float(dados.get("r", 0.0)) * rx, float(dados.get("b", 0.0)) * ry)
	elif OS.has_feature("mobile"):
		var tela := Vector2(DisplayServer.screen_get_size())
		var seguro := Rect2(DisplayServer.get_display_safe_area())
		if tela.x > 0.0 and tela.y > 0.0 and seguro.size.x > 0.0:
			var rx := vp.x / tela.x
			var ry := vp.y / tela.y
			m = Vector4(seguro.position.x * rx, seguro.position.y * ry,
				(tela.x - seguro.end.x) * rx, (tela.y - seguro.end.y) * ry)
	var minimo := Vector4(MARGEM_MIN, MARGEM_MIN, MARGEM_MIN, MARGEM_MIN)
	return Vector4(maxf(m.x, minimo.x), maxf(m.y, minimo.y), maxf(m.z, minimo.z), maxf(m.w, minimo.w))
