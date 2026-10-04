extends Node3D
## Nível de teste do M0: corredor de 5 salas cinzas. Serve para testar jogador, HUD e contador.


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.6, 0.7, 0.8)
	e.fog_density = 0.01
	env.environment = e
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sol)

	var chao := Construtor.material(Color(0.45, 0.42, 0.4))
	var parede := Construtor.material(Color(0.71, 0.39, 0.29))
	Construtor.caixa(self, Vector3(8, 0.2, 70), Vector3(0, -0.1, -25), chao)
	for i in 5:
		var z := -i * 12.0
		Construtor.caixa(self, Vector3(0.4, 3, 12), Vector3(-4, 1.5, z - 4), parede)
		Construtor.caixa(self, Vector3(0.4, 3, 12), Vector3(4, 1.5, z - 4), parede)
		var t := SalaTrigger.new(i + 1, Vector3(8, 3, 1))
		t.position = Vector3(0, 0, z + 1)
		add_child(t)
		Construtor.rotulo(self, "SALA %d" % (i + 1), Vector3(0, 2.6, z - 9.7), 64, Color.WHITE)
	var painel := Interagivel.new("Ler painel", Vector3(1.2, 1.2, 0.1), func(_p):
		Guia.falar("bentinho", ["Oi! Eu sou o Bentinho!", "Bem-vindo ao Castelinho!"]))
	painel.position = Vector3(3.7, 1.4, -3)
	painel.rotation_degrees.y = -90
	add_child(painel)
	Construtor.caixa(painel, Vector3(1.2, 1.2, 0.08), Vector3.ZERO, Construtor.material(Color(1, 0.9, 0.3)), false)

	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0.1, 3)
	add_child(spawn)
