class_name ZonasPerigo
extends RefCounted
## ZONAS DE PERIGO do Visor (módulo 2, parte 3, pedido do Icaro: "meio injusto, quero explorar valendo, com jumpscares e a
## perseguição em certas partes"). A atenção do Visor e a Figura do slide SÓ agem dentro destas salas; fora delas o Q é livre
## (a atenção fica em zero, nenhuma Figura no slide, nenhuma perseguição vinda do Visor).
##
## Números GLOBAIS de sala (os que o HUD mostra), por visita. Porão (visita 5): continua valendo em todas as salas.
##   Visita 3: 57 e 58  (Ato II: dentro do núcleo de 1950 e a arcada; já têm a Figura e a perseguição da arcada).
##   Visita 4: 74, 77 e 80  (74 = corredor, onde o menino some ao ser olhado; 77 = o trecho longo da escada, terraço e Pescador,
##             o maior; 80 = o hall com a porta zebrada que dá no porão, onde a perseguição final do Visor termina bem).
## A visita 4 comprime as 22 salas-base nas globais 67..80 (castelinho.gd `V4_SALAS`); as salas 72 (Povos, disco de 2019) e as
## das caças (TITO 6/7/8: salas 75, 78 e 73) ficam de FORA de propósito: ali o Q é de graça para achar as marcas.
## "Preso no Visor" (Visor.preso) conta como zona de perigo enquanto dura, em qualquer sala.

const SALAS := {
	3: [57, 58],
	4: [74, 77, 80],
}


## `sala` (global) é zona de perigo na visita `visita`? Porão (5): sempre.
static func eh_perigo(visita: int, sala: int) -> bool:
	if visita == 5:
		return true
	return sala in SALAS.get(visita, [])


## O jogador está agora numa zona de perigo (ou preso no Visor)?
static func ativa() -> bool:
	return Visor.preso() or eh_perigo(GameState.visita, GameState.sala_atual)
