class_name Relatorio
extends RefCounted
## Relatório de problema (menu de pausa > "Enviar relatório"): um texto curto, sem dados pessoais, que o jogador
## copia ou manda pelo WhatsApp para o Icaro. Tudo estático. `instalar()` liga o coletor de erros do motor
## (Logger, Godot 4.5+) e a trilha das últimas salas; `gerar()` monta o texto (nunca quebra: nó ausente = "?").

const MAX_ERROS := 8
const MAX_TRILHA := 12
const MAX_CHARS := 1400        # limite do texto (o link do WhatsApp aguenta isso com folga)
const MAX_ERRO_CHARS := 100    # cada erro é cortado neste tamanho

static var _mutex := Mutex.new()
static var _erros: Array[String] = []
static var _trilha: Array[String] = []   # "sala@tempo_s"
static var _instalado := false


## Idempotente: liga o coletor de erros e escuta GameState.sala_mudou.
static func instalar() -> void:
	if _instalado:
		return
	_instalado = true
	if OS.has_method("add_logger"):
		OS.call("add_logger", _ColetorErros.new())
	var gs := _gs()
	if gs and gs.has_signal("sala_mudou"):
		var cb := Callable(Relatorio, "registrar_sala")
		if not gs.is_connected("sala_mudou", cb):
			gs.connect("sala_mudou", cb)
		var atual: Variant = gs.get("sala_atual")
		if atual is int and int(atual) > 0:
			registrar_sala(int(atual))


## Guarda a sala visitada e o tempo (s desde que o programa abriu). Só as últimas MAX_TRILHA.
static func registrar_sala(n: int) -> void:
	_mutex.lock()
	_trilha.append("%d@%ds" % [n, int(Time.get_ticks_msec() / 1000.0)])
	while _trilha.size() > MAX_TRILHA:
		_trilha.pop_front()
	_mutex.unlock()


## Guarda um erro/aviso (pode vir de qualquer thread). Só os últimos MAX_ERROS.
static func registrar_erro(texto: String) -> void:
	var t := texto.replace("\n", " ").strip_edges()
	if t.length() > MAX_ERRO_CHARS:
		t = t.substr(0, MAX_ERRO_CHARS - 3) + "..."
	_mutex.lock()
	_erros.append(t)
	while _erros.size() > MAX_ERROS:
		_erros.pop_front()
	_mutex.unlock()


static func quantos_erros() -> int:
	_mutex.lock()
	var n := _erros.size()
	_mutex.unlock()
	return n


static func _gs() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null or arvore.root == null:
		return null
	return arvore.root.get_node_or_null("GameState")


## Lê uma propriedade do GameState; "?" se não existir.
static func _gv(gs: Node, nome: String) -> Variant:
	if gs == null or not (nome in gs):
		return "?"
	return gs.get(nome)


static func _versao() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "?")).strip_edges()
	return v if v != "" else "?"


static func _plataforma() -> String:
	var p := OS.get_name()
	p += ", celular: %s" % ("sim" if Celular.ativo else "nao")
	if OS.has_feature("web"):
		var ua: Variant = null
		if Engine.has_singleton("JavaScriptBridge"):
			ua = JavaScriptBridge.eval("navigator.userAgent", true)
		if ua is String and ua != "":
			p += ", " + (ua as String).substr(0, 90)
	return p


static func _nivel() -> String:
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return "?"
	var principal := arvore.get_first_node_in_group("main")
	if principal:
		var caminho: Variant = principal.get("nivel_atual")
		if caminho is String and caminho != "":
			return (caminho as String).get_file().get_basename()
	if arvore.current_scene:
		return str(arvore.current_scene.name)
	return "?"


static func _jogador() -> String:
	var arvore := Engine.get_main_loop() as SceneTree
	var j: Node3D = null
	if arvore:
		j = arvore.get_first_node_in_group("player") as Node3D
	if j == null or not j.is_inside_tree():
		return "?"
	var p := j.global_position
	return "%.1f, %.1f, %.1f" % [p.x, p.y, p.z]


static func _debug() -> String:
	if not Debug.ligado:
		return "off"
	var chaves: Array[String] = ["on"]
	if Debug.imortal:
		chaves.append("imortal")
	if Debug.figura_off:
		chaves.append("figura_off")
	if Debug.atencao_congelada:
		chaves.append("atencao_congelada")
	return " ".join(chaves)


static func gerar() -> String:
	var gs := _gs()
	var epoca: Variant = _gv(gs, "epoca")
	var nome_epoca := "?"
	if gs and epoca is int:
		var nomes: Variant = gs.get("NOMES_EPOCA")
		if nomes is Dictionary:
			nome_epoca = str((nomes as Dictionary).get(epoca, "?"))
	var atencao: Variant = _gv(gs, "atencao")
	var atencao_txt := "%.2f" % float(atencao) if (atencao is float or atencao is int) else "?"
	var mortes: Variant = "?"
	if gs:
		var cont: Variant = gs.get("contadores")
		if cont is Dictionary:
			mortes = (cont as Dictionary).get("mortes", "?")
	var linhas: Array[String] = []
	linhas.append("RELATORIO Castelinho - versao %s" % _versao())
	linhas.append("Data (UTC): %s" % Time.get_datetime_string_from_system(true, true))
	linhas.append("Plataforma: %s" % _plataforma())
	linhas.append("Nivel: %s | Sala %s | Visita %s | Epoca %s" % [_nivel(), str(_gv(gs, "sala_atual")),
		str(_gv(gs, "visita")), nome_epoca])
	linhas.append("Disco: %s | Atencao: %s | Checkpoint: sala %s | Mortes: %s" % [str(_gv(gs, "disco_atual")),
		atencao_txt, str(_gv(gs, "checkpoint_sala")), str(mortes)])
	linhas.append("Jogador: %s | qps: %d | Debug: %s" % [_jogador(), Engine.get_frames_per_second(), _debug()])
	_mutex.lock()
	var trilha := ", ".join(_trilha) if not _trilha.is_empty() else "?"
	var erros := _erros.duplicate()
	_mutex.unlock()
	linhas.append("Trilha (sala@tempo): %s" % trilha)
	if erros.is_empty():
		linhas.append("Erros: nenhum")
	else:
		linhas.append("Erros recentes:")
		for e in erros:
			linhas.append("- " + e)
	linhas.append("O que aconteceu: ")
	var texto := "\n".join(linhas)
	if texto.length() > MAX_CHARS:
		texto = texto.substr(0, MAX_CHARS - 3) + "..."
	return texto


## Link do WhatsApp com o texto (o jogador escolhe o contato).
static func link_whatsapp(texto: String) -> String:
	return "https://wa.me/?text=" + texto.uri_encode()


## Coletor: o motor chama estes métodos (possivelmente de outra thread) a cada erro/aviso/printerr.
class _ColetorErros extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		var msg := rationale if rationale != "" else code
		var tipo := "AVISO" if error_type == Logger.ERROR_TYPE_WARNING else "ERRO"
		Relatorio.registrar_erro("%s %s (%s:%d)" % [tipo, msg, file.get_file(), line])

	func _log_message(message: String, error: bool) -> void:
		if error:
			Relatorio.registrar_erro("ERR " + message)
