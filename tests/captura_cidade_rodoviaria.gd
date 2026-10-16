extends SceneTree
## Captura da Rodoviária (Módulo 14; precisa de renderização: xvfb-run; fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cidade_rodoviaria.gd -- <saida.png> [chave=valor ...]
## Chaves: epoca=2020|1967|sem|1950 (padrão 2020), x= z= (posição do jogador), yaw= (graus; 0 = olha para -z, -90 = leste), pitch= (graus),
##         visor=1 (liga a moldura do Visor), estado=placas|aberto (adianta a tarefa), w= h= (tamanho), cartaz=1 (abre o cartaz na tela)
## ATENÇÃO: escreve em user://save.json (como o jogo).

var gs: Node
var main: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0]
	var o := {"epoca": "2020", "x": "-21", "z": "4", "yaw": "-90", "pitch": "0", "w": "1280", "h": "720"}
	for i in range(1, a.size()):
		var kv: PackedStringArray = a[i].split("=")
		o[kv[0]] = kv[1]
	root.size = Vector2i(int(o["w"]), int(o["h"]))
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.visita = 4
	gs.sala_maxima = 78
	gs.set_flag("tem_visor", true)
	for e in [gs.Epoca.E1950, gs.Epoca.E1967, gs.Epoca.E1975, gs.Epoca.E2019, gs.Epoca.ESEMDATA]:
		gs.ganhar_disco(e)
	gs.jogando = true
	main.hud.visible = true
	main.set_process(false)      # sem mouse capturado (xvfb) o main pausaria o jogo
	await main.carregar_mundo(gs.CIDADE["rodoviaria"]["cena"], "Spawn")
	for i in 12:
		await physics_frame
	var nivel: Node = main.mundo.get_child(0)
	var epoca: int = {"2020": gs.Epoca.E2020, "1967": gs.Epoca.E1967, "sem": gs.Epoca.ESEMDATA, "1950": gs.Epoca.E1950}[o["epoca"]]
	gs.trocar_epoca(epoca)
	if str(o.get("visor", "0")) == "1":
		root.get_node("/root/Efeitos").visor(true)
	if o.get("estado", "") in ["placas", "aberto"]:
		for pid in ["tramandai", "osorio", "poa"]:
			nivel.pegar_placa(pid)
		nivel.pendurar_placas()
		if o["estado"] == "aberto":
			nivel._persiana.scale.y = 0.05
			nivel._luz_guiche.light_energy = 1.4
	main.player.global_position = Vector3(float(o["x"]), 0.1, float(o["z"]))
	main.player.rotation_degrees.y = float(o["yaw"])
	main.player.cabeca.rotation_degrees.x = float(o["pitch"])
	if str(o.get("cartaz", "0")) == "1":
		nivel._ler_cartaz()
	for i in 40:
		root.get_node("/root/Guia").cancelar()
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("foto: ", saida, "  draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit(0)
