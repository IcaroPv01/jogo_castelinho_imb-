#!/usr/bin/env bash
# Baixa as fotos de referência do Castelinho (uso privado, para modelagem).
# As fotos pertencem aos veículos citados em castelinho.md §8. Não redistribuir.
set -e
cd "$(dirname "$0")" && mkdir -p refs && cd refs
baixar() { curl -fsSL -o "$1" "$2" && echo "ok  $1" || echo "ERRO $1"; }
baixar aerea_2019_litoralnarede.jpg                 https://litoralnarede.com.br/wp-content/uploads/2019/10/021019-CASTELINHO-IMBE-Mauricio-Marques-1.jpg
baixar fachada_frontal_2026_beta.jpg                https://www.betaredacao.com.br/wp-content/uploads/2026/05/Caroline-Lopes-0233.jpg
baixar foto_antiga_nucleo_original_beta.jpg         https://www.betaredacao.com.br/wp-content/uploads/2026/05/Caroline-Lopes-0105.jpg
baixar interior_galeria_arco_porta_2026_beta.jpg    https://www.betaredacao.com.br/wp-content/uploads/2026/05/Caroline-Lopes-0138-1.jpg
baixar interior_sala_pescador_2026_beta.jpg         https://www.betaredacao.com.br/wp-content/uploads/2026/05/Caroline-Lopes-0151.jpg
baixar torres_fachada_lateral_2026_correiodoimbe.jpg https://www.correiodoimbe.com.br/uploads/images/2026/02/castelinho-da-cultura-em-imbe-estara-aberto-aos-sabados-para-visitacao.jpg
baixar janelas_grade_2020_jplitoral.jpg             https://jplitoral.com.br/wp-content/uploads/2020/12/Cultura_01.jpeg
baixar arcada_cornija_2020_jplitoral.jpg            https://jplitoral.com.br/wp-content/uploads/2020/12/Cultura_02.jpeg
