class_name MedidasEmbutidas
extends RefCounted
## GERADO por tools/gerar_medidas_embutidas.py a partir de castelinho/medidas.json. NÃO edite à mão.
## Cópia usada quando o JSON não está no pacote da exportação web.

const DADOS := {
	"_comentario": "Medidas do Castelinho JÁ NO SISTEMA DO GODOT (x = leste, z = sul, y = altura; origem = esquina Garibaldi x Nilza). Convertidas de docs/pesquisa/medidas_estimadas.json por pos = (-X, Z, -Y) e CORRIGIDAS pelas fotos (ver castelinho/LEIAME.md). Retângulos são [min, max]. Unidades em metros.",
	"_correcoes_pelas_fotos": [
		"Torre A: o relatório dava ~5 m até as ameias; no drone/frontal ela passa 2 pavimentos acima do parapeito da arcada (4,4 m). Adotado: ameias a 7,8 m, torreta com ápice a 9,9 m (conferido contra as capturas de drone e frontal).",
		"A arcada começa na esquina da fachada leste (arco de entrada colado no canto) e segue para oeste até a Torre A: 5 arcos (1 de entrada com 1,9 m + 4 de 1,3 m), 10,8 m no total. O croqui a punha atrás da torre.",
		"A torreta (cobertura piramidal) é a quina SE da Torre A, ~2,1 m de seção, e não uma torre à parte: sobe ~2 m acima das ameias da torre.",
		"Anexo ameado (2 pares de janelas geminadas) e pavilhão de canto a oeste da Torre A, na mesma linha da fachada sul (fotos 2019 e hibisco 2026).",
		"Alturas da Torre B ~0,85 x a da Torre A (drone): ameias a 6,5 m, ápice da torreta a 8,5 m."
	],
	"lote": {
		"x": [
			-30.0,
			0.0
		],
		"z": [
			-34.0,
			0.0
		]
	},
	"parede": {
		"espessura": 0.4,
		"espessura_interna": 0.22
	},
	"alturas": {
		"laje": 3.5,
		"pe_direito": 3.2,
		"parapeito_arcada": 4.4,
		"merlao": 0.3
	},
	"volumes": {
		"galeria": {
			"x": [
				-15.8,
				-5.0
			],
			"z": [
				-14.0,
				-11.0
			],
			"topo_parede": 4.0
		},
		"corpo_principal": {
			"x": [
				-12.5,
				-5.0
			],
			"z": [
				-20.5,
				-14.0
			],
			"beiral_leste": 4.2,
			"cota_alta_oeste": 5.5,
			"beiral_projecao": 0.7
		},
		"torre_a": {
			"x": [
				-22.6,
				-15.8
			],
			"z": [
				-15.0,
				-11.0
			],
			"piso_terraco": 6.8,
			"topo_parede": 7.4,
			"torreta": {
				"x": [
					-17.9,
					-15.8
				],
				"z": [
					-13.1,
					-11.0
				],
				"topo_fuste": 8.4,
				"apice": 9.9
			}
		},
		"anexo": {
			"x": [
				-26.8,
				-22.6
			],
			"z": [
				-15.0,
				-11.0
			],
			"topo_parede": 4.0
		},
		"pavilhao": {
			"x": [
				-28.6,
				-26.8
			],
			"z": [
				-13.0,
				-11.0
			],
			"topo_fuste": 4.5,
			"apice": 5.8
		},
		"bloco_patio": {
			"x": [
				-25.0,
				-12.5
			],
			"z": [
				-20.5,
				-15.0
			]
		},
		"corredor": {
			"x": [
				-25.0,
				-5.0
			],
			"z": [
				-23.5,
				-20.5
			]
		},
		"ala_fundos": {
			"x": [
				-17.0,
				-8.2
			],
			"z": [
				-29.5,
				-23.5
			],
			"beiral": 3.6,
			"cota_alta": 4.6
		},
		"torre_b": {
			"x": [
				-8.2,
				-5.0
			],
			"z": [
				-26.7,
				-23.5
			],
			"topo_parede": 6.2,
			"piso_terraco": 5.9,
			"torreta": {
				"x": [
					-6.6,
					-5.0
				],
				"z": [
					-25.1,
					-23.5
				],
				"topo_fuste": 7.0,
				"apice": 8.5
			}
		}
	},
	"arcos_fachada_sul": {
		"plano_z": -11.0,
		"arcos": [
			{
				"x": -6.55,
				"w": 1.9,
				"imposta": 1.7,
				"coroa": 2.4,
				"nota": "entrada (vidro com porta, E2020)"
			},
			{
				"x": -8.8,
				"w": 1.3,
				"imposta": 1.85,
				"coroa": 2.4
			},
			{
				"x": -10.75,
				"w": 1.3,
				"imposta": 1.85,
				"coroa": 2.4
			},
			{
				"x": -12.7,
				"w": 1.3,
				"imposta": 1.85,
				"coroa": 2.4
			},
			{
				"x": -14.65,
				"w": 1.3,
				"imposta": 1.85,
				"coroa": 2.4
			}
		]
	},
	"fachada_leste": {
		"plano_x": -5.0,
		"janelas": [
			{
				"z": -13.0,
				"w": 0.9,
				"h": 1.4,
				"base": 0.95
			},
			{
				"z": -16.4,
				"w": 0.9,
				"h": 1.4,
				"base": 0.95
			}
		],
		"porta": {
			"z": -19.4,
			"w": 1.6,
			"imposta": 1.7,
			"coroa": 2.2
		},
		"letreiro": {
			"z": -15.0,
			"base": 2.6,
			"w": 2.1,
			"h": 0.45
		},
		"frestas": {
			"z": [
				-14.7,
				-16.0,
				-17.9
			],
			"base": 3.2,
			"w": 0.12,
			"h": 0.35
		},
		"janela_alta": {
			"z": -19.6,
			"w": 0.6,
			"h": 1.1,
			"base": 2.9
		}
	},
	"ameias": {
		"largura": 0.37,
		"altura": 0.4,
		"espessura": 0.32,
		"passo": 0.62
	},
	"cornija": {
		"altura_faixa": 0.405,
		"projecao": 0.13,
		"passo_misulas": 0.3,
		"largura_misula": 0.15,
		"capa": 0.135
	},
	"coberturas": {
		"inclinacao_fibrocimento_graus": 10.0,
		"piramidal_torres_graus": 43.0
	},
	"chamines": [
		{
			"x": -13.4,
			"z": -15.8,
			"w": 0.9,
			"base": 3.5,
			"topo": 7.0
		},
		{
			"x": -14.2,
			"z": -30.0,
			"w": 0.8,
			"base": 0.0,
			"topo": 6.3
		}
	],
	"cores": {
		"bloco_a": "#A8583F",
		"bloco_b": "#C9806A",
		"junta": "#CDBBA6",
		"madeira": "#3B2A22",
		"fibrocimento": "#9A9A96"
	}
}
