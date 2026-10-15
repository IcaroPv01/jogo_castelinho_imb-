extends SceneTree
## Regressão de COLOCAÇÃO de objetos 3D (módulo 10): constrói o Castelinho (4 visitas), Ato II, Barra, porão (81-99) e
## Braço Morto com o registro de `Malha` ligado e roda as checagens de tests/varredura/colocacao_lib.gd.
## FALHA se aparecer um achado "real" (não intencional e fora da lista EXCECOES da lib) de:
##   flutuando, enfiado, atravessa_parede, zfighting.
## (frestas, degraus de piso e continuidade só aparecem no relatório completo: tests/varredura/colocacao.gd.)
## Para aceitar um achado de propósito: acrescente uma entrada, COM O MOTIVO, em `EXCECOES` (colocacao_lib.gd).
## Uso: godot --headless -s res://tests/colocacao_test.gd   (~15 s)

const LIB := "res://tests/varredura/colocacao_lib.gd"
const TIPOS_QUE_FALHAM := ["flutuando", "enfiado", "atravessa_parede", "zfighting"]

var falhas := 0
var GS
var main
var Malha: GDScript
var Registro: GDScript
var lib_gd: GDScript
var total_intencionais := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	Malha = load("res://castelinho/malha.gd")
	Registro = load("res://castelinho/registro.gd")
	lib_gd = load(LIB)
	_checar(Malha.registrar == false, "registro desligado por padrão")
	for v in [1, 2, 3, 4]:
		await _nivel("res://world/niveis/castelinho.tscn", "castelo", v, {"tem_lanterna": v >= 3})
	await _nivel("res://world/niveis/ato2.tscn", "ato2", 3, {})
	await _nivel("res://world/niveis/barra.tscn", "barra", 2, {})
	await _nivel("res://world/niveis/porao.tscn", "porao", 5, {"porao_semente": 4242})
	await _nivel("res://world/niveis/braco_morto.tscn", "braco", 5, {})
	for lugar in ["casas", "barra", "ponte", "praia", "rodoviaria"]:      # Módulo 14: lugares da cidade (usam nome automático)
		await _nivel("res://world/niveis/cidade_%s.tscn" % lugar, "cidade_" + lugar, 4, {}, 5)
	Malha.desligar()
	Malha.limpar()
	print("  (achados intencionais/exceções ignorados: %d)" % total_intencionais)
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _nivel(caminho: String, nome: String, visita: int, flags: Dictionary, minimo := 100) -> void:
	GS.novo_jogo()
	GS.visita = visita
	GS.flags["tem_visor"] = true
	for f in flags:
		GS.flags[f] = flags[f]
	GS.jogando = true
	main.hud.visible = true
	Malha.ligar(nome)
	await main.carregar_mundo(caminho, "Spawn")
	for i in 3:
		await process_frame
	var nivel: Node = main.mundo.get_child(0)
	if nome == "porao":
		for i in nivel.N:
			nivel._carregar_sala(i)
		await process_frame
	Registro.varrer(nivel, nome)
	var lib = lib_gd.new()
	lib.preparar(Malha.registro, Malha.materiais, {"nivel": nome, "visita": visita, "sala_fn": Callable()})
	_checar(Malha.registro.size() > minimo, "%s v%d: registro com %d entradas" % [nome, visita, Malha.registro.size()])
	lib.checar_flutuando()
	lib.checar_enfiado()
	lib.checar_zfight()
	for a in lib.achados:
		if a["tipo"] not in TIPOS_QUE_FALHAM:
			continue
		if a["provavel_intencional"]:
			total_intencionais += 1
			continue
		_checar(false, "%s v%d %s '%s' %s cm em %s | %s" % [nome, visita, a["tipo"], a["etiqueta"], str(a["medida_cm"]), a["arquivo"], a["detalhe"]])
	Malha.desligar()


func _checar(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("  FALHA ", msg)
