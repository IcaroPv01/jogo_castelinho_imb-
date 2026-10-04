#!/usr/bin/env python3
"""Gera castelinho/medidas_embutidas.gd a partir de castelinho/medidas.json.

Por quê: a exportação web só empacota os .json listados em `include_filter` (export_presets.cfg) e
`castelinho/medidas.json` não está lá. O gerador do Castelinho lê o JSON em tempo de execução e, se o
arquivo não existir no pacote, usa esta cópia embutida (um script .gd é sempre exportado).
O teste tests/castelinho_test.gd confere se as duas cópias estão iguais: rode este script depois de editar o JSON.
"""
import json
import os

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
origem = os.path.join(RAIZ, "castelinho", "medidas.json")
destino = os.path.join(RAIZ, "castelinho", "medidas_embutidas.gd")
with open(origem, encoding="utf-8") as f:
    dados = json.load(f)


def para_float(v):
    # JSON.parse_string do Godot devolve todo número como float: espelha isso aqui
    if isinstance(v, bool):
        return v
    if isinstance(v, int):
        return float(v)
    if isinstance(v, list):
        return [para_float(x) for x in v]
    if isinstance(v, dict):
        return {k: para_float(x) for k, x in v.items()}
    return v


corpo = json.dumps(para_float(dados), indent="\t", ensure_ascii=False)
with open(destino, "w", encoding="utf-8") as f:
    f.write("class_name MedidasEmbutidas\nextends RefCounted\n")
    f.write("## GERADO por tools/gerar_medidas_embutidas.py a partir de castelinho/medidas.json. NÃO edite à mão.\n")
    f.write("## Cópia usada quando o JSON não está no pacote da exportação web.\n\n")
    f.write("const DADOS := " + corpo + "\n")
print("gerado:", destino)
