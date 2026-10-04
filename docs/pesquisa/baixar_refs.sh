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

# --- Rodada 2 (geometria e fotos): mais angulos do Castelinho -------------------------------
# webp: baixa e converte para jpg (precisa de python3 com Pillow; se faltar, o arquivo .webp fica como veio).
baixar_webp() { curl -fsSL -o "$1.webp" "$2" && { python3 -c "from PIL import Image;Image.open('$1.webp').convert('RGB').save('$1',quality=92)" 2>/dev/null && rm "$1.webp"; echo "ok  $1"; } || echo "ERRO $1"; }
baixar_ua() { curl -fsSL -A "Mozilla/5.0" -o "$1" "$2" && echo "ok  $1" || echo "ERRO $1"; }
# Castelo (exterior, interior, drones, quadros de video do YouTube = miniaturas i.ytimg/img.youtube)
baixar lnr_2019_passagem_arco_marques.jpg                         https://litoralnarede.com.br/wp-content/uploads/2019/10/021019-CASTELINHO-IMBE-MAURICIO-MARQUES.jpg
baixar lnr_2019_arcada_ameias_marques3.jpg                        https://litoralnarede.com.br/wp-content/uploads/2019/10/021019-CASTELINHO-IMBE-MAURICIO-MARQUES-3.jpg
baixar jpl_2021_aerea_drone_fachadas.jpg                          https://jplitoral.com.br/wp-content/uploads/2021/02/Castelinho.jpg
baixar_webp lnr_2026_frontal_esquina_ivan.jpg                          https://litoralnarede.com.br/wp-content/uploads/2026/03/0203026-CASTELINHO-CULTURA-IMBE-IVAN-DE-ANDRADE-PMI.webp
baixar_webp dpn_2020_frontal_torre_arcada_ivan.jpg                     https://dapraianews.com.br/Imagens/Casa-de-Cultura-de-Imbe-recebera-Noite-de-Natal-no-Castelo-foto-Ivan-de-Andrade-1536x1026_1.webp
baixar dim_2026_torre_ameias_hibisco.jpg                          https://jornaldimensao.com.br/wp-content/uploads/2026/02/640138686_939898978598244_3197493495157194839_n.jpg
baixar ci_2025_sala_lareira_escudos.jpg                           https://www.correiodoimbe.com.br/uploads/images/2025/08/conselho-municipal-de-cultura-realiza-reuniao-ordinaria-no-castelinho-da-cultura-ec1d2.jpeg
baixar interior_meio_ambiente_piso_pedra_2020_jplitoral.jpg       https://jplitoral.com.br/wp-content/uploads/2020/12/Cultura_03.jpeg
baixar interior_porta_arco_nicho_2020_jplitoral.jpg               https://jplitoral.com.br/wp-content/uploads/2020/12/Cultura_04.jpeg
baixar textura_tijolo_mesa_acervo_beta.jpg                        https://www.betaredacao.com.br/wp-content/uploads/2026/05/Caroline-Lopes-0098.jpg
baixar yt_mundoreverso_capa_torre.jpg                             https://img.youtube.com/vi/gdSWn3uetmQ/maxresdefault.jpg
baixar yt_ondatv_torre_passagem.jpg                               https://img.youtube.com/vi/Ynl65ZnIXTk/hq1.jpg
baixar yt_ondatv_escudo_espadas_parede.jpg                        https://img.youtube.com/vi/Ynl65ZnIXTk/hq3.jpg
baixar yt_vonhelden_porta_4vidros_torre.jpg                       https://img.youtube.com/vi/UWYzbOUIG7E/hq2.jpg
baixar yt_radiok_porta_interna_4vidros.jpg                        https://img.youtube.com/vi/AVcu4417D1U/hq3.jpg
baixar yt_vernissage_sala_lareira_arcos.jpg                       https://img.youtube.com/vi/WFzT5wrk1xA/hq1.jpg
baixar yt_vernissage_arcos_interno.jpg                            https://img.youtube.com/vi/WFzT5wrk1xA/hq2.jpg
baixar yt_festivalmedieval_arcada_parapeito.jpg                   https://img.youtube.com/vi/j5lm5-GB74k/hqdefault.jpg

# Flashbacks (pasta refs/flashbacks/). Fotos modernas; as "antigo_*" sao quadros de videos/arquivos de Tramandai (Imbe nao tem foto antiga digitalizada acessivel).
mkdir -p flashbacks
baixar flashbacks/barra_tarrafeiros_dunas_yt.jpg                             https://img.youtube.com/vi/A8MaAaYfTPc/hqdefault.jpg
baixar flashbacks/barra_tarrafeiros_skyline_yt.jpg                           https://img.youtube.com/vi/8abDD28qSHE/maxresdefault.jpg
baixar flashbacks/barra_botos_espetaculo_litoralnarede_yt.jpg                https://img.youtube.com/vi/ZCkBgXMdWso/maxresdefault.jpg
baixar flashbacks/molhe_pescadores_pedras_yt.jpg                             https://img.youtube.com/vi/JRmgi4zGUyU/hqdefault.jpg
baixar flashbacks/molhe_tarrafa_rio_imbe_yt.jpg                              https://img.youtube.com/vi/JRmgi4zGUyU/hq3.jpg
baixar flashbacks/molhe_pedras_quiosques_imbe_yt.jpg                         https://img.youtube.com/vi/QmPs6SnnkJY/hqdefault.jpg
baixar flashbacks/molhe_pedras_pescador_yt.jpg                               https://img.youtube.com/vi/QmPs6SnnkJY/hq3.jpg
baixar flashbacks/barra_aerea_drone_ponta_yt.jpg                             https://img.youtube.com/vi/bF8tkncVHoE/hq2.jpg
baixar flashbacks/barra_aerea_2016_molhe_multidao_yt.jpg                     https://img.youtube.com/vi/l_ZT9ZRFYLU/maxresdefault.jpg
baixar flashbacks/barra_orla_rio_aerea_imbe_yt.jpg                           https://img.youtube.com/vi/Nr7fHZ9VAho/maxresdefault.jpg
baixar flashbacks/ponte_garibaldi_pista_grades_yt.jpg                        https://img.youtube.com/vi/cxoGtIo0in4/hq2.jpg
baixar flashbacks/ponte_garibaldi_cabeceira_yt.jpg                           https://img.youtube.com/vi/cxoGtIo0in4/hq1.jpg
baixar flashbacks/ponte_garibaldi_noite_aerea_yt.jpg                         https://img.youtube.com/vi/OauhZQLFvck/hq1.jpg
baixar flashbacks/ponte_garibaldi_noite_aerea2_yt.jpg                        https://img.youtube.com/vi/sep-ORQZVzI/hq3.jpg
baixar flashbacks/ponte_garibaldi_heliopere_blog.jpg                         https://www.heliopere.com/wp-content/uploads/2024/07/Descubra-a-Historia-da-Ponte-Giuseppe-Garibaldi-Um-Marco-Entre-Tramandai-e-Imbe-Blog-Helio-Pere-2.jpg
baixar flashbacks/ponte_garibaldi_obras_dimensaotv_yt.jpg                    https://img.youtube.com/vi/yIjVqt2cnZw/hq3.jpg
baixar flashbacks/praia_imbe_guaritas_beira_mar_aerea_yt.jpg                 https://img.youtube.com/vi/hndagdKHhDE/maxresdefault.jpg
baixar flashbacks/beira_mar_calcadao_guarita_azul_yt.jpg                     https://img.youtube.com/vi/K2_XXY1cyEM/maxresdefault.jpg
baixar flashbacks/beira_mar_calcadao_yt.jpg                                  https://img.youtube.com/vi/K2_XXY1cyEM/hq3.jpg
baixar flashbacks/praia_imbe_guarita_vermelha_yt.jpg                         https://img.youtube.com/vi/HsXWOzDEtas/hqdefault.jpg
baixar flashbacks/imbe_aerea_orla_cidade_yt.jpg                              https://img.youtube.com/vi/oExDT2OZRVU/maxresdefault.jpg
baixar flashbacks/imbe_aerea_beira_mar_yt.jpg                                https://img.youtube.com/vi/oExDT2OZRVU/hq1.jpg
baixar flashbacks/imbe_aerea_barra_yt.jpg                                    https://img.youtube.com/vi/oExDT2OZRVU/hq3.jpg
baixar flashbacks/imbe_aerea_avenidas_ruas_yt.jpg                            https://img.youtube.com/vi/1PLINys4O7c/hq2.jpg
baixar flashbacks/beira_mar_noite_aerea_yt.jpg                               https://img.youtube.com/vi/OauhZQLFvck/hq2.jpg
baixar flashbacks/antigo_tramandai_inicio_seculoXX_banhistas_yt.jpg          https://img.youtube.com/vi/vLsh7AnGl6Y/maxresdefault.jpg
baixar flashbacks/antigo_tramandai_familia_1920_yt.jpg                       https://img.youtube.com/vi/vLsh7AnGl6Y/hq2.jpg
baixar flashbacks/antigo_tramandai_carro_fordT_yt.jpg                        https://img.youtube.com/vi/3rNUPJDYm1w/hq3.jpg
baixar flashbacks/antigo_tramandai_cartao_postal_pavilhao_yt.jpg             https://img.youtube.com/vi/3rNUPJDYm1w/hqdefault.jpg
baixar flashbacks/antigo_tramandai_1950_filme_banhista_yt.jpg                https://img.youtube.com/vi/BxznUY-vxFw/hq3.jpg
baixar flashbacks/alagamento_2024_05_recanto_lagoa_tramandai.jpg             https://litoralnarede.com.br/wp-content/uploads/2024/05/160524-ALAGAMENTO-RECANTO-DA-LAGOA-TRAMANDAI-DEFESA-CIVIL.jpg
baixar flashbacks/ressaca_2024_05_beira_rio_aguapes.jpg                      https://litoralnarede.com.br/wp-content/uploads/2024/05/160524-RESSACA-BEIRA-RIO-TRAMANDAI-LTRL.jpg
baixar flashbacks/alagamento_imbe_jacare_2026_jplitoral.jpg                  https://jplitoral.com.br/wp-content/uploads/2026/07/jacare-imbe.jpg
baixar_webp flashbacks/alagamento_imbe_rua_chuva_dapraianews.jpg                  https://dapraianews.com.br/Imagens/chuva_1.webp
baixar flashbacks/alagamento_imbe_rio_transborda_correiopovo_yt.jpg          https://img.youtube.com/vi/6eJ4hG3TB7U/hq3.jpg
baixar flashbacks/alagamento_barra_imbe_dimensaotv_yt.jpg                    https://img.youtube.com/vi/dLM8yHMvwwY/maxresdefault.jpg
baixar flashbacks/alagamento_braco_morto_avenida_yt.jpg                      https://img.youtube.com/vi/8sPuZsOU-Fo/hq2.jpg
baixar flashbacks/seival_replica_guaiba_reporterguaibense.png                https://www.reporterguaibense.com.br/uploads/images/2022/08/reproducao-do-barco-de-giuseppe-garibaldi-atraca-em-guaiba-dbf19.png
baixar flashbacks/seival_gravura_garibaldi_yt.jpg                            https://img.youtube.com/vi/xxrqp3vd-sc/hq1.jpg
baixar flashbacks/seival_miniatura_pelotas_yt.jpg                            https://img.youtube.com/vi/xxrqp3vd-sc/hq3.jpg
baixar flashbacks/seival_replica_conves_yt.jpg                               https://img.youtube.com/vi/iXCam0F4zLg/hqdefault.jpg
baixar flashbacks/seival_casco_madeira_yt.jpg                                https://img.youtube.com/vi/9d6-RQATeao/hq2.jpg
baixar_ua flashbacks/alagamento_2024_05_imbe_terra.jpg                          https://p1.trrsf.com.br/image/fget/cf/1200/630/middle/images.terra.com/2024/05/16/1758907089-alagamentoimbe.jpg

# Satelite: Esri World Imagery so tem z<=18 neste local (z19+ devolve "Map data not yet available"). Mosaico 5x5 tiles z18 = satelite_z18.jpg
# (gerado por script local; ver geometria_e_fotos.md para a formula do tile). Nao e baixado aqui.
