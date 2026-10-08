extends SceneTree
## Varredura de console (QA estatico): carrega cada nivel de world/niveis (exceto teste) dentro do main,
## deixa rodar ~600 frames e imprime marcadores "=== NIVEL" para atribuir erros do log a cada cena.
## Uso: timeout 400 godot --headless -s res://tests/varredura/estatico_console.gd

const NIVEIS := [
	["res://world/niveis/castelinho.tscn", 1],
	["res://world/niveis/castelinho.tscn", 2],
	["res://world/niveis/castelinho.tscn", 3],
	["res://world/niveis/castelinho.tscn", 4],
	["res://world/niveis/ato2.tscn", 3],
	["res://world/niveis/barra.tscn", 1],
	["res://world/niveis/porao.tscn", 4],
	["res://world/niveis/braco_morto.tscn", 4],
]
const FRAMES := 600


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var GameState = root.get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	if is_instance_valid(main.tela_titulo):
		main.tela_titulo.queue_free()
	GameState.novo_jogo()
	GameState.jogando = true
	main.hud.visible = true
	for par in NIVEIS:
		var caminho: String = par[0]
		var visita: int = par[1]
		print("=== NIVEL %s visita %d" % [caminho, visita])
		GameState.comecar_visita(visita)
		await main.carregar_mundo(caminho, "Spawn")
		for i in FRAMES:
			await process_frame
		var p = main.player
		var ok_player: bool = p != null and p.is_inside_tree()
		print("=== FIM %s visita %d | player_ok=%s sala=%d nos_mundo=%d" % [
			caminho.get_file(), visita, str(ok_player), GameState.sala_atual, main.mundo.get_child_count()])
	print("=== VARREDURA CONCLUIDA")
	quit(0)
