extends Node
## Teste de cenas NO NAVEGADOR (WebGL2): vira a cena principal só num build de teste (tools/testar_web_cenas.sh).
## Carrega cada nível pelo Main, olha por cada câmera Cam_* e imprime "CENA_OK"/"FIM_WEB_CENAS" no console.
## Erros de compilação de shader no WebGL aparecem no console do navegador (o script Python os coleta).

const CENAS := [
	# [cena, visita, época, flags, câmeras]
	["res://world/niveis/castelinho.tscn", 4, 3, ["tem_visor"], ["Cam_porta_porao", "Cam_frontal"]],
	["res://world/niveis/castelinho.tscn", 4, 2, ["tem_visor"], ["Cam_escada2019"]],
	["res://world/niveis/castelinho.tscn", 2, 4, ["tem_visor"], ["Cam_drone", "Cam_spawn"]],
	["res://world/niveis/porao.tscn", 5, 3, [], []],
	["res://world/niveis/braco_morto.tscn", 5, 3, [], ["Cam_margem", "Cam_lapide", "Cam_tito"]],
	["res://world/niveis/ato2.tscn", 3, 3, [], ["Cam_56", "Cam_58"]],
	["res://world/niveis/barra.tscn", 2, 3, [], []],
]


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var gs = get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if main.tela_titulo:
		main.tela_titulo.queue_free()
	for c in CENAS:
		gs.novo_jogo()
		gs.visita = c[1]
		for f in c[3]:
			gs.set_flag(f)
		await main.carregar_mundo(c[0], "Spawn")
		gs.trocar_epoca(c[2])
		var nivel: Node = main.mundo.get_child(0)
		var cams: Array = c[4]
		if cams.is_empty():
			await _quadros(40)
		for nome in cams:
			var m := nivel.find_child(nome, true, false) as Node3D
			if m == null:
				print("CENA_AVISO sem câmera ", nome, " em ", c[0])
				continue
			var cam := Camera3D.new()
			nivel.add_child(cam)
			cam.global_transform = m.global_transform
			cam.current = true
			await _quadros(30)
			cam.queue_free()
		print("CENA_OK ", c[0], " visita ", c[1], " época ", c[2])
	print("FIM_WEB_CENAS")


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame
