extends CidadeBase
## LUGAR DA CIDADE: Rodoviária, fim da temporada (Módulo 14). ESQUELETO: a base (`cidade_base.gd`) já dá ambiente, chão, borda invisível, rede de
## segurança, HUD, portão "Voltar ao Castelinho", pistas e `concluir()`. O MIOLO (cenário, tarefa, textos) é do agente deste lugar:
## troque tudo o que estiver marcado "TODO miolo" e mantenha os ganchos `_configurar()`, `_construir()` e `_tarefa()`.
## A rodoviária no fim da temporada de 1967, vista só pelo Visor (disco de 1967); em 2020 é um lugar vazio. Tarefa do miolo: achar a mala e o cartaz de PROCURA-SE que a mãe pregou antes do último ônibus. Sem nome de empresa real.
## Tabela: `GameState.CIDADE["rodoviaria"]` (abre depois da visita 4; pistas: rodoviaria_cartaz). Teste: `tests/cidade_rodoviaria_test.gd` (crie).


func _configurar() -> void:
	id = "rodoviaria"
	area = Rect2(-25.0, -15.0, 50.0, 30.0)       # AREA jogável (x, z, largura, profundidade); a borda invisível e a rede de segurança usam isto
	hora = Hora.FIM_DE_TARDE
	clima = Clima.LIMPO
	spawn_pos = Vector3(-20.0, 0.1, 8.0)
	spawn_yaw = -90.0
	usa_visor = true          # 1967 só aparece pelo Visor (tecla Q com o disco de 1967)


func _material_chao() -> Material:
	return mat_calcada()


func _construir() -> void:
	# TODO miolo: plataforma, guichê, bancos, o último ônibus. O que é de 1967 leva Epocas.marcar(no, [GameState.Epoca.E1967]).
	Construtor.caixa(self, Vector3(10.0, 3.0, 5.0), Vector3(0.0, 1.5, -11.0), Ato2Pecas.mat_cor(Color(0.75, 0.75, 0.7)), true, "GuichePlaceholder")
	poste(Vector3(-14.0, 0.0, -6.0))


func _tarefa() -> void:
	# TODO miolo: a tarefa de verdade (achar, abrir, escolher, escapar) e o texto do objetivo que o Mapa (M) mostra em "Agora:".
	definir_objetivo("Ligue o Visor (Q, disco de 1967) e ache o cartaz de PROCURA-SE.")
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	var m0 := _marca_teste(Vector3(0.0, 0.0, -4.0), "PistaTeste0")
	var i0 := interagivel("Olhar o cartaz", Vector3(0.0, 0.0, -4.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("rodoviaria_cartaz", ["[placeholder] O cartaz de PROCURA-SE, recém-pregado."]))
	Epocas.marcar(m0, [GameState.Epoca.E1967])       # a pista só existe em 1967 (pelo Visor)
	Epocas.marcar(i0, [GameState.Epoca.E1967])
	# TODO miolo: quando a tarefa de verdade acabar, chame concluir() (grava "cidade_rodoviaria_feito" e volta à calçada).
	_marca_teste(Vector3(10.0, 0.0, 2.0), "TarefaTeste", Color(0.2, 1.0, 0.4))
	interagivel("Achar a mala (tarefa de teste)", Vector3(10.0, 0.0, 2.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: concluir())


## Cubo de teste bem visível (placeholder). TODO miolo: apague.
func _marca_teste(pos: Vector3, nome: String, cor := Color(1.0, 0.1, 0.9)) -> MeshInstance3D:
	return Construtor.caixa(self, Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 0.25, 0.0), Ato2Pecas.mat_cor(cor, true), false, nome)
