class_name Mapa
extends CanvasLayer
## MAPA DA VISITA: o folheto de papel do "Programa Municipal de Memória Interativa" (a prefeitura fictícia do jogo).
## Abre com M (ação "mapa"), pelo botão "Mapa" do celular ou pelo menu de pausa. M, Esc ou um toque fora das abas fecha.
##
##   Mapa.abrir()            abre (devolve o Mapa, ou null se não pode agora)       Mapa.atual   o mapa aberto, ou null
##   mapa.fechar()           fecha                                                  mapa.selecionar_andar(i)
##
## Quem fornece os dados é o nível atual, com um método opcional `dados_mapa() -> Dictionary` (ver castelinho.gd).
## Sem o método: "Esta área não consta no mapa." (porão: "Este andar não consta na planta."; Ato II, Barra e Braço
## Morto: "Esta área não consta no mapa!"). A linha de baixo ("Agora: ...") vem de Objetivo.atual().
##
## A folha estraga junto com a história (GameState.visita): 1 e 2 limpa; 3 com rabiscos, uma mancha de café e nomes
## riscados; 4 com o desenho de giz de cera de uma criança por cima (círculo vermelho em volta da próxima sala, "AQUI" e
## um boneco palito) e o cabeçalho com letras faltando. Porão: papel molhado, manchas de água.
## Ao abrir: solta o mouse, trava o jogador e liga a flag `ui_aberta` (Flash.abrir_ui()).

const CAMADA := 42
const GUARDA_MS := 400          # o clique emulado do toque que abriu o mapa não pode fechá-lo na hora

const TINTA := Flash.NAVY
const PAPEL := Color("F1E4C3")
const PAPEL_CLARO := Color("FBF3DB")
const PAPEL_ESCURO := Color("DCCB9C")
const PAPEL_MOLHADO := Color("B9B392")
const GRAMA := Color("CFE2A9")
const RUA := Color("CBC5B6")
const PISO := Color("E9DAB0")
const SALA_NORMAL := Color("FFFCEF")
const SALA_VISTA := Color("D0EBBD")
const SALA_AQUI := Color("C3E2FF")
const VERDE_ESCURO := Color("2F8F2A")
const CRAYON := Color("DC1F1F")

static var atual: Mapa = null

var dados := {}
var tipo := "ausente"
var andar := 0
var objetivo := ""
var visita := 1
var _abas: Array[Rect2] = []
var _abas_andar: Array[int] = []
var _andares: Array[int] = []
var _fechado := false
var _aberto_ms := 0
var _t := 0.0
var _folha: Folha
var _ruido := PackedFloat32Array()
var _rabiscos: Array[PackedVector2Array] = []
var _manchas: Array[Dictionary] = []     # {c: Vector2 (0..1), r: float (0..1), a: float}
var _subtitulo := "Programa Municipal de Memória Interativa"
var _rect_x := Rect2()


class Folha extends Control:
	var dono: Mapa

	func _draw() -> void:
		if dono:
			dono._desenhar(self)

	func _gui_input(e: InputEvent) -> void:
		if dono:
			dono._ao_entrada(e)


# ================================================================ API estática
## Cria a ação "mapa" (tecla M) se ainda não existir. (O GameState também a cria na lista de teclas.)
static func registrar_inputs() -> void:
	if not InputMap.has_action("mapa"):
		InputMap.add_action("mapa")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_M
		InputMap.action_add_event("mapa", ev)


static func pode_abrir() -> bool:
	if atual != null and is_instance_valid(atual):
		return false
	if not GameState.jogando or GameState.flag("ui_aberta"):
		return false
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or arv.paused:
		return false
	var p := arv.get_first_node_in_group("player")
	if p and ("pode_mover" in p) and not bool(p.get("pode_mover")):
		return false
	return not Guia.bloqueando()


## Abre o mapa. `forcar` pula as checagens (menu de pausa, testes). Devolve null se não pôde.
static func abrir(forcar := false) -> Mapa:
	registrar_inputs()
	if atual != null and is_instance_valid(atual):
		return atual
	if not forcar and not pode_abrir():
		return null
	var m := Mapa.new()
	atual = m
	Flash.raiz().add_child.call_deferred(m)
	return m


## O nó do nível atual (filho do "Mundo" do main), ou um nó solto na raiz que tenha `dados_mapa`.
static func nivel_atual() -> Node:
	var arv := Engine.get_main_loop() as SceneTree
	if arv == null or arv.root == null:
		return null
	var principal := arv.get_first_node_in_group("main")
	if principal:
		var mundo: Variant = principal.get("mundo")
		if mundo is Node and (mundo as Node).get_child_count() > 0:
			return (mundo as Node).get_child(0)
	for n in arv.root.get_children():
		if n.has_method("dados_mapa"):
			return n
	return arv.current_scene


## Dados do mapa do nível atual. Sempre tem "tipo": "castelinho" (ou o que o nível mandar), "porao", "fora" ou "ausente".
static func obter_dados() -> Dictionary:
	var nivel := nivel_atual()
	if nivel != null and nivel.has_method("dados_mapa"):
		var d: Variant = nivel.call("dados_mapa")
		if d is Dictionary and not (d as Dictionary).is_empty():
			var dd: Dictionary = d
			if not dd.has("tipo"):
				dd["tipo"] = "castelinho"
			return dd
	var arq := ""
	if nivel != null:
		arq = nivel.scene_file_path
		if arq == "" and nivel.get_script() is Script:
			arq = (nivel.get_script() as Script).resource_path
		arq = arq.get_file()
	if arq.begins_with("porao") or (arq == "" and GameState.sala_atual >= GameState.PRIMEIRA_SALA_PORAO and GameState.sala_atual < GameState.TOTAL_SALAS):
		return {"tipo": "porao", "msg": "Este andar não consta na planta."}
	if arq.begins_with("ato2") or arq.begins_with("barra") or arq.begins_with("braco") or GameState.sala_atual >= GameState.TOTAL_SALAS:
		return {"tipo": "fora", "msg": "Esta área não consta no mapa!"}
	return {"tipo": "ausente", "msg": "Esta área não consta no mapa."}


# ================================================================ ciclo de vida
func _ready() -> void:
	layer = CAMADA
	name = "Mapa"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visita = GameState.visita
	dados = obter_dados()
	tipo = str(dados.get("tipo", "ausente"))
	if tipo == "porao":
		visita = 5
	objetivo = Objetivo.atual()
	_preparar_rabiscos()
	_escolher_andar_inicial()
	_folha = Folha.new()
	_folha.dono = self
	_folha.name = "Folha"
	_folha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_folha.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_folha)
	_aberto_ms = Time.get_ticks_msec()
	Flash.abrir_ui()
	Audio.sfx("clique", -6.0, 1.3)


func _exit_tree() -> void:
	if not _fechado:
		_fechado = true
		Flash.fechar_ui()
	if atual == self:
		atual = null


func _process(dt: float) -> void:
	_t += dt
	if not GameState.jogando:
		fechar()
		return
	if _folha:
		_folha.queue_redraw()


func fechar() -> void:
	if _fechado:
		return
	_fechado = true
	if atual == self:
		atual = null
	Audio.sfx("clique", -6.0, 0.9)
	Flash.fechar_ui()
	queue_free()


func selecionar_andar(i: int) -> void:
	if _andares.has(i) and i != andar:
		andar = i
		Audio.sfx("clique", -10.0, 1.2)


func _unhandled_input(e: InputEvent) -> void:
	if _fechado or _folha == null:
		return
	if e.is_action_pressed("mapa") and not e.is_echo():
		fechar()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("pausa"):
		fechar()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("esquerda") or e.is_action_pressed("direita"):
		var k := _andares.find(andar)
		if k >= 0 and not _andares.is_empty():
			selecionar_andar(_andares[clampi(k + (1 if e.is_action_pressed("direita") else -1), 0, _andares.size() - 1)])
		get_viewport().set_input_as_handled()


func _ao_entrada(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_folha.accept_event()
		if Time.get_ticks_msec() - _aberto_ms < GUARDA_MS:
			return
		var i := _aba_em(e.position)
		if i >= 0 and not _rect_x.has_point(e.position):
			selecionar_andar(i)
		else:
			fechar()


func _aba_em(pos: Vector2) -> int:
	for k in _abas.size():
		if _abas[k].grow(6.0).has_point(pos):
			return _abas_andar[k]
	return -1


# ================================================================ dados auxiliares
func _salas() -> Array:
	var r: Variant = dados.get("salas", [])
	return r if r is Array else []


func _sala_da_base(base: int) -> Dictionary:
	for s: Dictionary in _salas():
		if int(s.get("base", -1)) == base:
			return s
	return {}


func _base_proxima() -> int:
	return int(dados.get("base_proxima", -1))


func _base_atual() -> int:
	return int(dados.get("base_atual", -1))


func _escolher_andar_inicial() -> void:
	_andares.clear()
	if tipo != "castelinho":
		return
	var nomes: Array = dados.get("andares", ["Térreo"])
	var jog: Dictionary = dados.get("jogador", {})
	for i in nomes.size():
		var tem := false
		for s: Dictionary in _salas():
			if int(s.get("andar", 0)) == i and not s.has("junto"):
				tem = true
		if tem or (jog.has("andar") and int(jog.andar) == i):
			_andares.append(i)
	if _andares.is_empty():
		_andares.append(0)
	andar = _andares[0]
	if jog.has("andar") and _andares.has(int(jog.andar)):
		andar = int(jog.andar)
	else:
		var s := _sala_da_base(_base_atual())
		if not s.is_empty() and _andares.has(int(s.get("andar", 0))):
			andar = int(s.andar)


## Giz, rabiscos e manchas: sorteados uma vez (sementes fixas), senão tremeriam a cada quadro.
func _preparar_rabiscos() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + visita
	for i in 64:
		_ruido.append(rng.randf_range(-1.0, 1.0))
	if visita == 3:
		for k in 7:
			var lado := k % 2 == 0
			var x0 := rng.randf_range(0.014, 0.03) if lado else rng.randf_range(0.972, 0.988)
			var y0 := rng.randf_range(0.18, 0.78)
			var pts := PackedVector2Array()
			var n := rng.randi_range(22, 34)
			for j in n:
				pts.append(Vector2(x0 + 0.009 * sin(j * 1.25 + k) + rng.randf_range(-0.003, 0.003), y0 + j * 0.0075 + 0.004 * cos(j * 1.25 + k)))
			_rabiscos.append(pts)
		_manchas.append({"c": Vector2(0.86, 0.82), "r": 0.052, "a": 0.34})
		_manchas.append({"c": Vector2(0.835, 0.845), "r": 0.03, "a": 0.2})
	if visita == 4:
		_subtitulo = "Progr ma Munic pal de Mem ria Interrompida"
	if visita == 5:
		for k in 9:
			_manchas.append({"c": Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.12, 0.92)), "r": rng.randf_range(0.04, 0.13),
				"a": rng.randf_range(0.14, 0.3)})


# ================================================================ desenho
func _desenhar(c: Control) -> void:
	var S := c.size
	c.draw_rect(Rect2(Vector2.ZERO, S), Color(TINTA, 0.68))
	var m := Celular.margens()
	var pad_x := maxf(24.0, minf(m.x, 80.0))
	var pad_dir := maxf(24.0, minf(m.z, 80.0))
	var pad_t := maxf(14.0, minf(m.y, 40.0))
	var pad_b := maxf(14.0, minf(m.w, 40.0))
	var P := Rect2(pad_x, pad_t, S.x - pad_x - pad_dir, S.y - pad_t - pad_b)
	if P.size.x > 1200.0:
		P = Rect2((S.x - 1200.0) / 2.0, P.position.y, 1200.0, P.size.y)
	# papel (sombra dura, folha, dobras)
	var molhado := visita == 5
	var papel := PAPEL_MOLHADO if molhado else PAPEL
	c.draw_rect(Rect2(P.position + Vector2(7, 9), P.size), Color(0, 0, 0, 0.4))
	c.draw_style_box(Flash.caixa(papel, TINTA, 10, 5, false), P)
	c.draw_style_box(Flash.caixa(Color(0, 0, 0, 0), Color(TINTA, 0.35), 6, 2, false), P.grow(-9.0))
	for k in [1.0 / 3.0, 2.0 / 3.0]:
		var fx: float = P.position.x + P.size.x * k
		c.draw_rect(Rect2(fx - 7, P.position.y + 6, 7, P.size.y - 12), Color(0, 0, 0, 0.035))
		c.draw_rect(Rect2(fx, P.position.y + 6, 6, P.size.y - 12), Color(1, 1, 1, 0.07))
		c.draw_line(Vector2(fx, P.position.y + 6), Vector2(fx, P.end.y - 6), Color(TINTA, 0.1), 1.5)
	_cabecalho(c, P)
	var y_corpo := P.position.y + 88.0
	var faixa_h := 54.0
	var corpo := Rect2(P.position.x + 24.0, y_corpo, P.size.x - 48.0, P.end.y - 14.0 - faixa_h - 10.0 - y_corpo)
	if tipo == "castelinho":
		_abas_desenhar(c, Vector2(corpo.position.x, y_corpo))
		var topo := corpo.position.y + 44.0
		corpo = Rect2(corpo.position.x, topo, corpo.size.x, corpo.end.y - topo)
		var mapa_r := Rect2(corpo.position, Vector2(corpo.size.x * 0.46, corpo.size.y))
		_mapa(c, mapa_r)
		_lista(c, Rect2(corpo.position.x + corpo.size.x * 0.48, corpo.position.y, corpo.size.x * 0.52, corpo.size.y))
	else:
		_abas.clear()
		_abas_andar.clear()
		_mensagem(c, corpo)
	_faixa_agora(c, Rect2(P.position.x + 24.0, P.end.y - 14.0 - faixa_h, P.size.x - 48.0, faixa_h))
	_sobreposicoes(c, P)


func _cabecalho(c: Control, P: Rect2) -> void:
	var x := P.position.x + 24.0
	var y := P.position.y + 14.0
	var ic := Flash.icone("castelo")
	if ic != null:
		c.draw_texture_rect(ic, Rect2(x, y + 2.0, 56, 56), false)
	var fonte_t := Flash.fonte_titulo()
	c.draw_string(fonte_t, Vector2(x + 70.0, y + 36.0), "MAPA DA VISITA", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, TINTA)
	c.draw_string(Flash.fonte_sistema(), Vector2(x + 72.0, y + 58.0), _subtitulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(TINTA, 0.85))
	c.draw_line(Vector2(P.position.x + 20.0, P.position.y + 80.0), Vector2(P.end.x - 20.0, P.position.y + 80.0), Color(TINTA, 0.5), 2.0)
	# fechar (X vermelho) e dica
	var cx := Vector2(P.end.x - 44.0, P.position.y + 42.0)
	_rect_x = Rect2(cx - Vector2(26, 26), Vector2(52, 52))
	c.draw_circle(cx + Vector2(0, 3), 26.0, Color(TINTA, 0.35))
	c.draw_circle(cx, 26.0, TINTA)
	c.draw_circle(cx, 22.0, Flash.VERMELHO)
	c.draw_line(cx + Vector2(-8, -8), cx + Vector2(8, 8), Color.WHITE, 5.0, true)
	c.draw_line(cx + Vector2(-8, 8), cx + Vector2(8, -8), Color.WHITE, 5.0, true)
	var dica := Celular.dica("M ou Esc: fechar", "Toque fora das abas: fechar")
	var fonte_s := Flash.fonte_texto()
	var larg := fonte_s.get_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(fonte_s, Vector2(cx.x - 40.0 - larg, P.position.y + 66.0), dica, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TINTA, 0.75))
	# carimbo da visita
	if visita <= 4:
		var txt := "VISITA %d" % visita
		var tam := fonte_t.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		var centro := Vector2(cx.x - 60.0 - maxf(larg, 190.0) - tam.x / 2.0 - 12.0, P.position.y + 36.0)
		c.draw_set_transform(centro, deg_to_rad(-5.0))
		c.draw_style_box(Flash.caixa(Color(1, 1, 1, 0), Color(Flash.LARANJA, 0.9), 8, 4, false), Rect2(-tam.x / 2.0 - 12.0, -22.0, tam.x + 24.0, 40.0))
		c.draw_string(fonte_t, Vector2(-tam.x / 2.0, 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Flash.LARANJA, 0.95))
		c.draw_set_transform(Vector2.ZERO, 0.0)


func _abas_desenhar(c: Control, origem: Vector2) -> void:
	_abas.clear()
	_abas_andar.clear()
	var nomes: Array = dados.get("andares", ["Térreo"])
	var jog: Dictionary = dados.get("jogador", {})
	var prox: Dictionary = _sala_da_base(_base_proxima())
	var x := origem.x
	var fonte := Flash.fonte_titulo()
	for i: int in _andares:
		var nome := str(nomes[i]) if i < nomes.size() else "Andar %d" % i
		var larg := fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 56.0
		var r := Rect2(x, origem.y + 2.0, larg, 38.0)
		var ativo := i == andar
		c.draw_style_box(Flash.caixa(Flash.AMARELO if ativo else PAPEL_ESCURO, TINTA, 12, 3, false), r)
		c.draw_string(fonte, Vector2(r.position.x + 28.0, r.position.y + 27.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TINTA)
		if jog.has("andar") and int(jog.andar) == i:
			c.draw_circle(Vector2(r.position.x + 15.0, r.position.y + 19.0), 6.0, Color(CRAYON if visita == 4 else Flash.VERMELHO))
		if not prox.is_empty() and int(prox.get("andar", 0)) == i and not ativo:
			c.draw_colored_polygon(Flash.pontos_estrela(Vector2(r.end.x - 14.0, r.position.y + 11.0), 8.0), Flash.AMARELO)
		_abas.append(r)
		_abas_andar.append(i)
		x += larg + 8.0


# ---------------------------------------------------------------- o mapa (esquerda)
func _limites(a: int) -> Rect2:
	var r := Rect2()
	var primeiro := true
	var pr: Dictionary = dados.get("predio", {})
	var lista: Array = pr.get(a, [])
	for q: Array in lista:
		var rr := Rect2(float(q[0]), float(q[1]), float(q[2]) - float(q[0]), float(q[3]) - float(q[1]))
		r = rr if primeiro else r.merge(rr)
		primeiro = false
	for s: Dictionary in _salas():
		if int(s.get("andar", 0)) == a and not s.has("junto"):
			var w := float(s.w)
			var d := float(s.d)
			var rr := Rect2(float(s.x) - w / 2.0, float(s.z) - d / 2.0, w, d)
			r = rr if primeiro else r.merge(rr)
			primeiro = false
	return r.grow(1.0)


func _mapa(c: Control, area: Rect2) -> void:
	c.draw_style_box(Flash.caixa(PAPEL_CLARO if visita != 5 else PAPEL, TINTA, 8, 3, false), area)
	var lim := _limites(andar)
	var interior := area.grow(-10.0)
	var esc := minf(interior.size.x / maxf(lim.size.x, 1.0), interior.size.y / maxf(lim.size.y, 1.0))
	var orig := interior.get_center() - lim.get_center() * esc
	var px := func(x: float, z: float) -> Vector2: return orig + Vector2(x, z) * esc
	var rect_px := func(r: Rect2) -> Rect2: return Rect2(orig + r.position * esc, r.size * esc)
	var clip_area: Rect2 = interior
	# lote (grama), rua e contorno (só no térreo)
	var lote: Array = dados.get("lote", [])
	if andar == 0 and lote.size() == 4:
		var g := Rect2(float(lote[0]), float(lote[1]), float(lote[2]) - float(lote[0]), float(lote[3]) - float(lote[1])).intersection(lim)
		c.draw_rect((rect_px.call(g) as Rect2).intersection(clip_area), GRAMA)
		var rua := Rect2(lim.position.x, float(lote[3]), lim.size.x, lim.end.y - float(lote[3])).intersection(lim)
		var rua_px: Rect2 = (rect_px.call(rua) as Rect2).intersection(clip_area)
		c.draw_rect(rua_px, RUA)
		var nome_rua := str(dados.get("rua", ""))
		var larg_rua := Flash.fonte_sistema().get_string_size(nome_rua, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		c.draw_string(Flash.fonte_sistema(), Vector2(rua_px.end.x - larg_rua - 6.0, rua_px.end.y - 5.0), nome_rua, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(TINTA, 0.8))
		_tracejado(c, px.call(float(lote[0]), float(lote[3])), px.call(float(lote[2]), float(lote[3])), Color(TINTA, 0.6), 2.0, clip_area)
	# prédio: andar de baixo apagado (contexto) e o contorno do andar atual (cada retângulo com borda, depois o miolo por cima)
	var pr: Dictionary = dados.get("predio", {})
	if andar > 0:
		for q: Array in pr.get(0, []):
			var rf: Rect2 = rect_px.call(Rect2(float(q[0]), float(q[1]), float(q[2]) - float(q[0]), float(q[3]) - float(q[1])))
			c.draw_rect(rf, Color(TINTA, 0.08))
	var rects: Array[Rect2] = []
	for q: Array in pr.get(andar, []):
		rects.append(rect_px.call(Rect2(float(q[0]), float(q[1]), float(q[2]) - float(q[0]), float(q[3]) - float(q[1]))))
	for r in rects:
		c.draw_rect(r.grow(3.5), TINTA)
	for r in rects:
		c.draw_rect(r, PISO)
	# salas
	var aqui := _base_atual()
	var prox := _base_proxima()
	var desenhadas: Array[Dictionary] = []
	for s: Dictionary in _salas():
		if int(s.get("andar", 0)) != andar or s.has("junto"):
			continue
		desenhadas.append(s)
	for s in desenhadas:
		_sala_caixa(c, s, rect_px.call(Rect2(float(s.x) - float(s.w) / 2.0, float(s.z) - float(s.d) / 2.0, float(s.w), float(s.d))), int(s.base) == aqui, int(s.base) == prox)
	# trilha tracejada do jogador até a próxima sala
	var jog: Dictionary = dados.get("jogador", {})
	var s_prox := _sala_da_base(prox)
	var pos_jog := Vector2.ZERO
	var tem_jog := false
	if jog.has("x") and int(jog.get("andar", 0)) == andar:
		pos_jog = px.call(float(jog.x), float(jog.z))
		tem_jog = true
	elif _base_atual() >= 0 and int(_sala_da_base(aqui).get("andar", 0)) == andar:
		var sa := _sala_da_base(aqui)
		pos_jog = px.call(float(sa.x), float(sa.z))
		tem_jog = true
	if tem_jog and not s_prox.is_empty() and int(s_prox.get("andar", 0)) == andar and prox != aqui and visita != 4:
		_tracejado(c, pos_jog, px.call(float(s_prox.x), float(s_prox.z)), Color(Flash.LARANJA, 0.9), 3.0, clip_area, 9.0, _t * 14.0)
	# etiquetas de "PRÓXIMA" e círculo de giz (visita 4)
	if not s_prox.is_empty() and int(s_prox.get("andar", 0)) == andar:
		var rp: Rect2 = rect_px.call(Rect2(float(s_prox.x) - float(s_prox.w) / 2.0, float(s_prox.z) - float(s_prox.d) / 2.0, float(s_prox.w), float(s_prox.d)))
		if visita == 4:
			_giz_aqui(c, rp, clip_area)
		else:
			_etiqueta(c, "PRÓXIMA", Vector2(rp.get_center().x, rp.position.y - 3.0), Flash.LARANJA, Color.WHITE, 15, clip_area)
	# jogador
	if tem_jog:
		var conteudo: Rect2 = rect_px.call(lim.grow(-1.0))
		_jogador(c, pos_jog, jog, clip_area, conteudo.position.x - interior.position.x, interior.end.x - conteudo.end.x)


func _sala_caixa(c: Control, s: Dictionary, r: Rect2, aqui: bool, prox: bool) -> void:
	var vista := bool(s.get("visitada", false))
	var cor := SALA_NORMAL
	if aqui:
		cor = SALA_AQUI
	elif vista:
		cor = SALA_VISTA
	if prox:
		var pulso := 0.5 + 0.5 * sin(_t * 4.0)
		c.draw_rect(r.grow(3.0 + pulso * 3.0), Color(Flash.AMARELO, 0.35 + 0.25 * pulso))
		cor = Flash.AMARELO
	c.draw_rect(r, cor)
	c.draw_rect(r, Flash.LARANJA if prox else TINTA, false, 4.0 if prox else 2.5)
	var base := int(s.base)
	var global := int(s.get("global", base))
	var fonte_t := Flash.fonte_titulo()
	var fonte_x := Flash.fonte_texto()
	var rotulo := str(s.get("rotulo", "SALA %d" % global))
	var tam_n := 17
	var larg_rot := fonte_t.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_n).x
	if larg_rot > r.size.x - 6.0:
		if s.has("rotulo"):
			tam_n = 14        # rótulo próprio ("SAÍDA") não vira só número: fica menor, mesmo que passe da caixa
		else:
			rotulo = str(global)
	var nome := str(s.get("nome", ""))
	var larg_nome := fonte_x.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var tem_nome: bool = larg_nome <= r.size.x - 8.0 and r.size.y >= 40.0
	var centro := r.get_center()
	_texto_centro(c, rotulo, centro + Vector2(0, -8.0 if tem_nome else 0.0), tam_n, TINTA, fonte_t)
	if tem_nome:
		_texto_centro(c, nome, centro + Vector2(0, 11.0), 14, Color(TINTA, 0.85), fonte_x)
		if _riscada(base, aqui, prox):
			_rabisco_nome(c, centro + Vector2(0, 11.0), larg_nome)
	if vista and not aqui and not prox and r.size.x >= 56.0 and r.size.y >= 32.0:
		var t0 := Vector2(r.end.x - 15.0, r.position.y + 11.0)
		c.draw_polyline(PackedVector2Array([t0 + Vector2(-5, 0), t0 + Vector2(-1.5, 4.5), t0 + Vector2(6, -5)]), VERDE_ESCURO, 3.0, true)


## Visita 3: alguns nomes riscados à caneta (o número continua legível).
func _riscada(base: int, aqui: bool, prox: bool) -> bool:
	return visita == 3 and not aqui and not prox and base in [3, 5, 9, 13, 20, 22]


func _rabisco_nome(c: Control, centro: Vector2, larg: float) -> void:
	var pts := PackedVector2Array()
	var n := maxi(4, int(larg / 9.0))
	for i in n + 1:
		pts.append(centro + Vector2(-larg / 2.0 - 2.0 + larg * i / n, (-3.0 if i % 2 == 0 else 3.0) - 1.0 + _ruido[i % 64] * 1.5))
	c.draw_polyline(pts, Color(0.05, 0.05, 0.1, 0.85), 2.2, true)


func _jogador(c: Control, pos: Vector2, jog: Dictionary, clip: Rect2, livre_esq := 0.0, livre_dir := 0.0) -> void:
	var pulso := fmod(_t * 1.3, 1.0)
	c.draw_circle(pos, 9.0 + pulso * 16.0, Color(CRAYON if visita == 4 else Color("E52B2B"), 0.4 * (1.0 - pulso)))
	if jog.has("dx"):
		var dir := Vector2(float(jog.dx), float(jog.dz))
		if dir.length() > 0.01:
			dir = dir.normalized()
			var lado := Vector2(-dir.y, dir.x)
			var ponta := pos + dir * 22.0
			c.draw_colored_polygon(PackedVector2Array([ponta, pos + dir * 8.0 + lado * 8.0, pos + dir * 8.0 - lado * 8.0]), Color("E52B2B"))
			c.draw_polyline(PackedVector2Array([pos + dir * 8.0 + lado * 8.0, ponta, pos + dir * 8.0 - lado * 8.0]), TINTA, 2.0, true)
	# balão "VOCÊ ESTÁ AQUI": de preferência na margem livre ao lado do prédio (com uma linha até o ponto); senão em cima
	var fonte := Flash.fonte_titulo()
	var t1 := fonte.get_string_size("VOCÊ ESTÁ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var t2 := fonte.get_string_size("AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var folga := t1.x + 14.0
	var lado := 0
	if pos.x < clip.get_center().x and livre_esq >= folga:
		lado = -1
	elif livre_dir >= folga:
		lado = 1
	elif livre_esq >= folga:
		lado = -1
	var caixa: Rect2
	if lado != 0:
		caixa = Rect2(Vector2(clip.position.x + 3.0 if lado < 0 else clip.end.x - folga - 3.0, clampf(pos.y - 22.0, clip.position.y + 3.0, clip.end.y - 48.0)), Vector2(folga, 44.0))
		var ancora := Vector2(caixa.end.x if lado < 0 else caixa.position.x, caixa.get_center().y)
		c.draw_line(ancora, pos, Color("E52B2B"), 2.5, true)
	else:
		var tam := fonte.get_string_size("VOCÊ ESTÁ AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		caixa = Rect2(pos + Vector2(-tam.x / 2.0 - 8.0, -46.0), Vector2(tam.x + 16.0, 28.0))
		if caixa.position.y < clip.position.y + 2.0:
			caixa.position.y = pos.y + 24.0
		caixa.position.x = clampf(caixa.position.x, clip.position.x + 2.0, clip.end.x - caixa.size.x - 2.0)
	c.draw_circle(pos, 10.0, Color.WHITE)
	c.draw_circle(pos, 7.5, Color("E52B2B"))
	c.draw_style_box(Flash.caixa(Color.WHITE, Color("E52B2B"), 8, 3, false), caixa)
	if lado != 0:
		c.draw_string(fonte, Vector2(caixa.get_center().x - t1.x / 2.0, caixa.position.y + 19.0), "VOCÊ ESTÁ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("B01818"))
		c.draw_string(fonte, Vector2(caixa.get_center().x - t2.x / 2.0, caixa.position.y + 37.0), "AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("B01818"))
	else:
		c.draw_string(fonte, caixa.position + Vector2(8.0, 20.0), "VOCÊ ESTÁ AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("B01818"))


func _etiqueta(c: Control, texto: String, topo_centro: Vector2, fundo: Color, cor_texto: Color, tam: int, clip: Rect2) -> void:
	var fonte := Flash.fonte_titulo()
	var t := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	var r := Rect2(topo_centro + Vector2(-t.x / 2.0 - 7.0, -t.y - 3.0), t + Vector2(14, 4))
	r.position.x = clampf(r.position.x, clip.position.x + 2.0, clip.end.x - r.size.x - 2.0)
	r.position.y = maxf(r.position.y, clip.position.y + 2.0)
	c.draw_style_box(Flash.caixa(fundo, TINTA, 8, 2, false), r)
	c.draw_string(fonte, r.position + Vector2(7.0, t.y - 4.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor_texto)


# ---------------------------------------------------------------- roteiro (direita)
func _lista(c: Control, area: Rect2) -> void:
	var nomes: Array = dados.get("andares", [])
	var titulo := "ROTEIRO · %s" % (str(nomes[andar]) if andar < nomes.size() else "")
	var fonte_t := Flash.fonte_titulo()
	var fonte_x := Flash.fonte_texto()
	c.draw_string(fonte_t, Vector2(area.position.x + 4.0, area.position.y + 24.0), titulo.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, TINTA)
	c.draw_line(Vector2(area.position.x, area.position.y + 34.0), Vector2(area.end.x, area.position.y + 34.0), Color(TINTA, 0.4), 2.0)
	var linhas: Array[Dictionary] = []
	for s: Dictionary in _salas():
		if int(s.get("andar", 0)) == andar and not s.has("junto"):
			linhas.append(s)
	if linhas.is_empty():
		return
	var topo := area.position.y + 42.0
	var h := clampf((area.end.y - topo) / linhas.size(), 22.0, 31.0)
	var tam := 19 if h >= 26.0 else 17
	var aqui := _base_atual()
	var prox := _base_proxima()
	var y := topo
	for s in linhas:
		var base := int(s.base)
		var linha := Rect2(area.position.x, y, area.size.x, h - 2.0)
		var eh_prox := base == prox
		var eh_aqui := base == aqui
		if eh_prox:
			c.draw_style_box(Flash.caixa(Flash.AMARELO, Flash.LARANJA, 8, 2, false), linha)
		elif eh_aqui:
			c.draw_style_box(Flash.caixa(SALA_AQUI, TINTA, 8, 2, false), linha)
		var cy := linha.position.y + linha.size.y / 2.0
		var cc := Vector2(linha.position.x + 16.0, cy)
		c.draw_circle(cc, 9.0, Color.WHITE)
		c.draw_arc(cc, 9.0, 0.0, TAU, 16, TINTA, 2.0, true)
		if bool(s.get("visitada", false)):
			c.draw_polyline(PackedVector2Array([cc + Vector2(-4.5, 0), cc + Vector2(-1.5, 4), cc + Vector2(5, -4.5)]), VERDE_ESCURO, 3.0, true)
		var num := str(s.get("rotulo", "SALA %d" % int(s.get("global", base))))
		c.draw_string(fonte_t, Vector2(linha.position.x + 34.0, cy + tam * 0.33), num, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)
		var x_nome := linha.position.x + 34.0 + 86.0
		var nome := str(s.get("nome", ""))
		c.draw_string(fonte_x, Vector2(x_nome, cy + tam * 0.33), nome, HORIZONTAL_ALIGNMENT_LEFT, linha.end.x - x_nome - 100.0, tam, Color(TINTA, 0.92))
		if _riscada(base, eh_aqui, eh_prox):
			var larg := minf(fonte_x.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x, linha.end.x - x_nome - 100.0)
			_rabisco_nome(c, Vector2(x_nome + larg / 2.0, cy), larg)
		if eh_prox:
			_selo_lista(c, linha, "PRÓXIMA", Flash.LARANJA)
		elif eh_aqui:
			_selo_lista(c, linha, "VOCÊ", Color("E52B2B"))
		y += h


func _selo_lista(c: Control, linha: Rect2, txt: String, cor: Color) -> void:
	var fonte := Flash.fonte_titulo()
	var t := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var r := Rect2(linha.end.x - t.x - 22.0, linha.position.y + 2.0, t.x + 16.0, linha.size.y - 4.0)
	c.draw_style_box(Flash.caixa(cor, TINTA, 8, 2, false), r)
	c.draw_string(fonte, Vector2(r.position.x + 8.0, r.get_center().y + 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


# ---------------------------------------------------------------- áreas sem mapa
func _mensagem(c: Control, area: Rect2) -> void:
	var msg := str(dados.get("msg", "Esta área não consta no mapa."))
	var centro := area.get_center() + Vector2(0, -10)
	var ic := Flash.icone("mapa")
	var molhado := tipo == "porao"
	if ic != null:
		c.draw_texture_rect(ic, Rect2(centro + Vector2(-70, -150), Vector2(140, 140)), false, Color(1, 1, 1, 0.55 if molhado else 1.0))
	var fonte := Flash.fonte_titulo()
	var tam := 42 if area.size.x > 700.0 else 32
	var t := fonte.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	c.draw_string(fonte, Vector2(centro.x - t.x / 2.0, centro.y + 40.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, TINTA)
	var sub := "A planta do museu termina aqui." if molhado else "O Programa Municipal não mapeou este trecho."
	var fx := Flash.fonte_texto()
	var ts := fx.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	c.draw_string(fx, Vector2(centro.x - ts.x / 2.0, centro.y + 80.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(TINTA, 0.75))
	if visita == 4 or tipo == "fora":
		var rr := Rect2(centro + Vector2(-t.x / 2.0 - 16.0, -2.0), Vector2(t.x + 32.0, 66.0))
		_giz_elipse(c, rr, 3.0)


# ---------------------------------------------------------------- faixa "Agora"
func _faixa_agora(c: Control, r: Rect2) -> void:
	c.draw_style_box(Flash.caixa(Flash.AMARELO if visita != 5 else Color("CDBE70"), TINTA, 14, 4, false), r)
	var fonte_t := Flash.fonte_titulo()
	var fonte_x := Flash.fonte_texto()
	var rot := "Agora:"
	var x0 := r.position.x + 20.0
	var larg_rot := fonte_t.get_string_size(rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(fonte_t, Vector2(x0, r.position.y + 36.0), rot, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TINTA)
	var tam := 22
	var disp := r.size.x - 40.0 - larg_rot - 12.0
	while tam > 15 and fonte_x.get_string_size(objetivo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > disp:
		tam -= 1
	c.draw_string(fonte_x, Vector2(x0 + larg_rot + 12.0, r.position.y + 35.0), objetivo, HORIZONTAL_ALIGNMENT_LEFT, disp, tam, TINTA)


# ---------------------------------------------------------------- estragos por cima da folha
func _sobreposicoes(c: Control, P: Rect2) -> void:
	var tam := P.size
	for mn in _manchas:
		var cen: Vector2 = P.position + (mn.c as Vector2) * tam
		var r: float = float(mn.r) * tam.x
		var a: float = mn.a
		if visita == 5:
			_mancha_agua(c, cen, r, a)
			c.draw_line(cen + Vector2(r * 0.2, r * 0.8), cen + Vector2(r * 0.2, minf(r * 3.5, P.end.y - cen.y)), Color(0.16, 0.24, 0.22, a * 0.8), 3.0)
		else:   # café
			c.draw_circle(cen, r, Color(0.42, 0.26, 0.1, a * 0.45))
			c.draw_arc(cen, r, 0.1, TAU - 0.5, 40, Color(0.32, 0.18, 0.06, a * 1.7), 4.0, true)
			c.draw_arc(cen, r * 0.8, 1.0, TAU - 1.2, 32, Color(0.32, 0.18, 0.06, a), 2.0, true)
	for pts in _rabiscos:
		var lista := PackedVector2Array()
		for p in pts:
			lista.append(P.position + p * tam)
		c.draw_polyline(lista, Color(0.06, 0.06, 0.14, 0.62), 2.0, true)
	if visita == 5:
		# papel molhado: gotas escorrendo do alto
		for k in 6:
			var x := P.position.x + tam.x * (0.12 + 0.15 * k) + _ruido[k] * 12.0
			var y1 := P.position.y + 10.0 + (0.22 + 0.2 * absf(_ruido[k + 8])) * tam.y
			c.draw_line(Vector2(x, P.position.y + 8.0), Vector2(x, y1), Color(0.18, 0.28, 0.27, 0.22), 3.0)
			c.draw_circle(Vector2(x, y1), 4.0, Color(0.18, 0.28, 0.27, 0.3))


# ---------------------------------------------------------------- giz de cera da criança (visita 4)
## Mancha de água: borda irregular, anel escuro e miolo mais claro.
func _mancha_agua(c: Control, cen: Vector2, r: float, a: float) -> void:
	var pts := PackedVector2Array()
	var n := 30
	for i in n:
		var ang := TAU * i / n
		var k := 1.0 + 0.16 * _ruido[(i * 2) % 64] + 0.09 * sin(ang * 3.0 + cen.x * 0.01)
		pts.append(cen + Vector2(cos(ang), sin(ang)) * r * k)
	c.draw_colored_polygon(pts, Color(0.2, 0.3, 0.28, a * 0.5))
	var fecha := PackedVector2Array(pts)
	fecha.append(pts[0])
	c.draw_polyline(fecha, Color(0.1, 0.17, 0.15, a * 1.5), 3.0, true)
	var miolo := PackedVector2Array()
	for p in pts:
		miolo.append(cen + (p - cen) * 0.72)
	miolo.append(miolo[0])
	c.draw_polyline(miolo, Color(0.1, 0.17, 0.15, a * 0.7), 2.0, true)


func _giz_aqui(c: Control, rp: Rect2, clip: Rect2) -> void:
	var r := rp.grow(9.0)
	_giz_elipse(c, r, 5.0)
	var pos := Vector2(r.end.x + 6.0, r.position.y - 4.0)
	var fonte := Flash.fonte_texto()
	var tam := 28
	var t := fonte.get_string_size("AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	if pos.x + t.x + 40.0 > clip.end.x:
		pos.x = r.position.x - t.x - 40.0
	pos.x = clampf(pos.x, clip.position.x + 4.0, clip.end.x - t.x - 36.0)
	pos.y = clampf(pos.y, clip.position.y + t.y, clip.end.y - 30.0)
	c.draw_set_transform(pos, deg_to_rad(-9.0))
	c.draw_string_outline(fonte, Vector2.ZERO, "AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 2, Color(CRAYON, 0.5))
	c.draw_string(fonte, Vector2.ZERO, "AQUI", HORIZONTAL_ALIGNMENT_LEFT, -1, tam, CRAYON)
	c.draw_set_transform(Vector2.ZERO, 0.0)
	# boneco palito ao lado da palavra
	var b := pos + Vector2(t.x + 18.0, 4.0)
	_giz_linhas(c, [
		[b + Vector2(0, -26), b + Vector2(0, -8)],          # corpo
		[b + Vector2(-8, -20), b + Vector2(0, -16), b + Vector2(8, -22)],   # braços
		[b + Vector2(0, -8), b + Vector2(-6, 4)], [b + Vector2(0, -8), b + Vector2(6, 4)],   # pernas
	])
	_giz_linhas(c, [_circulo_pontos(b + Vector2(0, -33), 6.0, 10)])


func _giz_elipse(c: Control, r: Rect2, larg: float) -> void:
	var cen := r.get_center()
	var pts := PackedVector2Array()
	var n := 36
	for i in n + 6:
		var a := TAU * i / n - 0.4
		var k := 1.0 + _ruido[i % 64] * 0.05 + i * 0.004
		pts.append(cen + Vector2(cos(a) * r.size.x * 0.5 * k, sin(a) * r.size.y * 0.5 * k))
	c.draw_polyline(pts, Color(CRAYON, 0.85), larg, true)
	var pts2 := PackedVector2Array()
	for p in pts:
		pts2.append(p + Vector2(1.4, -1.2))
	c.draw_polyline(pts2, Color(CRAYON, 0.45), larg * 0.7, true)


func _circulo_pontos(cen: Vector2, rad: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 2:
		var a := TAU * i / n
		pts.append(cen + Vector2(cos(a), sin(a)) * rad * (1.0 + _ruido[(i + 5) % 64] * 0.08))
	return pts


func _giz_linhas(c: Control, linhas: Array) -> void:
	for l in linhas:
		var pts: PackedVector2Array = PackedVector2Array(l)
		c.draw_polyline(pts, Color(CRAYON, 0.9), 3.0, true)


# ---------------------------------------------------------------- utilidades de desenho
func _texto_centro(c: Control, texto: String, centro: Vector2, tam: int, cor: Color, fonte: Font) -> void:
	var t := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
	var pos := Vector2(centro.x - t.x / 2.0, centro.y + (fonte.get_ascent(tam) - fonte.get_descent(tam)) / 2.0)
	c.draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


## Linha tracejada de `a` a `b`, cortada pelo retângulo `clip`.
func _tracejado(c: Control, a: Vector2, b: Vector2, cor: Color, larg: float, clip: Rect2, passo := 10.0, fase := 0.0) -> void:
	var d := b - a
	var comp := d.length()
	if comp < 1.0:
		return
	var u := d / comp
	var s := -fmod(fase, passo * 2.0)
	while s < comp:
		var i0 := maxf(s, 0.0)
		var i1 := minf(s + passo, comp)
		if i1 > i0:
			var p0 := a + u * i0
			var p1 := a + u * i1
			if clip.has_point(p0) and clip.has_point(p1):
				c.draw_line(p0, p1, cor, larg, true)
		s += passo * 2.0
