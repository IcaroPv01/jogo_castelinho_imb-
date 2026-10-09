class_name Finais
extends RefCounted
## Memória dos finais já vistos (muda a tela de título). Arquivo user://finais.cfg.
## Finais: "encontrado", "visita_concluida", "sala_101".

const CAMINHO := "user://finais.cfg"
const TODOS: Array[String] = ["encontrado", "visita_concluida", "sala_101"]


static func registrar(final: String) -> void:
	if not TODOS.has(final):
		return
	var cfg := ConfigFile.new()
	cfg.load(CAMINHO)   # se não existir, começa vazio
	var vistos: Array = cfg.get_value("finais", "vistos", [])
	if not vistos.has(final):
		vistos.append(final)
	cfg.set_value("finais", "vistos", vistos)
	cfg.set_value("finais", "ultimo", final)
	cfg.set_value("finais", "total", int(cfg.get_value("finais", "total", 0)) + 1)
	cfg.save(CAMINHO)


static func ultimo() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO) != OK:
		return ""
	return str(cfg.get_value("finais", "ultimo", ""))


static func vistos() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(CAMINHO) != OK:
		return []
	return cfg.get_value("finais", "vistos", [])
