extends CidadeBase
## LUGAR DA CIDADE: Calçadão da Barra (Módulo 14). ESQUELETO: a base (`cidade_base.gd`) já dá ambiente, chão, borda invisível, rede de
## segurança, HUD, portão "Voltar ao Castelinho", pistas e `concluir()`. O MIOLO (cenário, tarefa, textos) é do agente deste lugar:
## troque tudo o que estiver marcado "TODO miolo" e mantenha os ganchos `_configurar()`, `_construir()` e `_tarefa()`.
## A Barra de Imbé para andar à vontade, de dia e de noite (`aplicar_ambiente(Hora.DIA, ...)` troca o céu): quiosques fechados, molhe, pescadores. Tarefa do miolo: jogar a tarrafa de novo e achar o pescador que viu um menino. NÃO é o flashback `barra.gd` (V2), que não muda.
## Tabela: `GameState.CIDADE["barra"]` (abre depois da visita 2; pistas: barra_pescador). Teste: `tests/cidade_barra_test.gd` (crie).


func _configurar() -> void:
	id = "barra"
	area = Rect2(-40.0, -15.0, 80.0, 30.0)       # AREA jogável (x, z, largura, profundidade); a borda invisível e a rede de segurança usam isto
	hora = Hora.ENTARDECER
	clima = Clima.LIMPO
	spawn_pos = Vector3(-34.0, 0.1, 0.0)
	spawn_yaw = -90.0
	ambiente_audio = "mar"


func _material_chao() -> Material:
	return mat_calcada()


func _construir() -> void:
	# TODO miolo: calçadão, quiosques fechados, molhe, água, pescadores, a tarrafa. Cuidado: a água deve ficar FORA da AREA
	# (ou atrás da borda), senão o jogador cai ou atravessa.
	Construtor.caixa(self, Vector3(6.0, 3.0, 4.0), Vector3(-8.0, 1.5, -11.0), Ato2Pecas.mat_cor(Color(0.7, 0.8, 0.85)), true, "QuiosquePlaceholder")
	poste(Vector3(-20.0, 0.0, 6.0))


func _tarefa() -> void:
	# TODO miolo: a tarefa de verdade (achar, abrir, escolher, escapar) e o texto do objetivo que o Mapa (M) mostra em "Agora:".
	definir_objetivo("Ache o pescador que viu um menino.")
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	_marca_teste(Vector3(-14.0, 0.0, 4.0), "PistaTeste0")
	interagivel("Falar com o pescador", Vector3(-14.0, 0.0, 4.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("barra_pescador", ["[placeholder] Um pescador viu um menino."]))
	# TODO miolo: quando a tarefa de verdade acabar, chame concluir() (grava "cidade_barra_feito" e volta à calçada).
	_marca_teste(Vector3(10.0, 0.0, 0.0), "TarefaTeste", Color(0.2, 1.0, 0.4))
	interagivel("Jogar a tarrafa (tarefa de teste)", Vector3(10.0, 0.0, 0.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: concluir())


## Cubo de teste bem visível (placeholder). TODO miolo: apague.
func _marca_teste(pos: Vector3, nome: String, cor := Color(1.0, 0.1, 0.9)) -> MeshInstance3D:
	return Construtor.caixa(self, Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 0.25, 0.0), Ato2Pecas.mat_cor(cor, true), false, nome)
