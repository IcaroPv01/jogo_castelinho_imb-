class_name Opcoes
extends RefCounted
## Opções do jogador (volume geral e sensibilidade do mouse), guardadas em user://opcoes.cfg (IndexedDB na web).
## O volume vai direto para o bus Master; a sensibilidade é o multiplicador GameState.sensibilidade (1.0 = normal).

const ARQUIVO := "user://opcoes.cfg"
const SENS_MIN := 0.3
const SENS_MAX := 2.0

static var volume: float = 1.0   # 0..1 (linear)


## Lê o arquivo e aplica. Chamada uma vez, quando o HUD nasce. Sem arquivo/erro: valores padrão.
static func carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		volume = clampf(float(cfg.get_value("opcoes", "volume", 1.0)), 0.0, 1.0)
		GameState.sensibilidade = clampf(float(cfg.get_value("opcoes", "sensibilidade", GameState.sensibilidade)), SENS_MIN, SENS_MAX)
	aplicar_volume()


static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("opcoes", "volume", volume)
	cfg.set_value("opcoes", "sensibilidade", GameState.sensibilidade)
	cfg.save(ARQUIVO)


static func definir_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	aplicar_volume()


static func aplicar_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
