# Plano do jogo: Castelinho de Imbé

> Documento-mestre do projeto. Base: `docs/pesquisa/castelinho.md`, `docs/pesquisa/historia_imbe.md` e `docs/pesquisa/spookys_e_referencias.md`.
> **Status:** rascunho v0.1 (04/10/2026). Tudo aqui está aberto a revisão. As perguntas no fim (§12) decidem os pontos em aberto.

---

## 1. A ideia em uma frase

Um "jogo educativo da prefeitura" que faz uma visita guiada pelo Castelinho de Imbé contando a história da cidade, sala por sala. Aos poucos a visita para de fazer sentido, o prédio começa a mudar e o jogador acaba descendo para uma masmorra que **não está na planta**.

**Título provisório:** *Castelinho: Visita Guiada* (alternativas: *Conheça Imbé!*, *Costela-de-Adão*).

---

## 2. O que a pesquisa revelou (e por que muda o plano)

| Descoberta | Consequência para o jogo |
|---|---|
| O Castelinho existe e é hoje a **Casa de Cultura e Museu Municipal**, com **visitas guiadas às torres aos sábados**. | O formato "visita guiada educativa" não é invenção: é o que acontece de verdade no prédio. A abertura do jogo pode ser fiel ao uso real. |
| Foi erguido **aos poucos, por uma pessoa só** (1950 a 1975), com pedra trazida **de barco pelo rio Tramandaí**. O núcleo original **não tinha torres**. | Temos **4 versões reais** do prédio: núcleo de 1950, castelo pronto (1975), ruína de 2019 e museu de 2020+. O jogo pode alternar entre elas, e isso é fiel *e* assustador (ver §5). |
| **Não há porão, túnel ou lenda** documentados. O terreno é areia com lençol freático raso. | A masmorra é **licença criativa assumida**. Isso vira tema da história: "o que não está na planta". |
| Não existe planta baixa pública. Há só fotos e as medidas de **290 m² construídos num lote de mais de 900 m²**. | A fidelidade depende de uma **visita presencial com medições** (§9). Até lá, modelamos por foto, com medidas fáceis de corrigir. |
| A história de Imbé tem ganchos reais fortes: a **cidade-jardim de 1939** construída após **remover os pescadores** que moravam ali, os **botos** que "sinalizam" aos pescadores, naufrágios ("Cemitério dos Navegantes"), afogamentos na barra e a enchente de 2024. | O roteiro educativo usa fatos reais. O terror nasce de **contradições nesses fatos**, não de crimes inventados sobre pessoas reais. |
| Spooky's funciona por: guia fofa constante, sustos falsos que baixam a guarda, **monstros com uma regra cada**, salas pré-fabricadas embaralhadas e um contador de salas. | Copiamos a **estrutura**, não o conteúdo: contador de salas, guia mascote e criaturas com regras. As criaturas vêm do litoral gaúcho. |

---

## 3. Regras de fidelidade e de ética (inegociáveis)

1. **Prédio fiel:** a volumetria, os materiais, as cores, as aberturas, a arcada de 4 arcos, as 2 torres e a torreta, as ameias e as mísulas seguem as fotos e as medidas. Toda invenção (masmorra, passagens, salas extras) fica **dentro de um "espaço impossível"** que o próprio jogo marca como impossível.
2. **Pessoas reais nunca ligadas ao sobrenatural ou a crimes.** O construtor real (Walmyr Roszanyi), a família dele, os prefeitos, os pioneiros e os botos com nome real **não** viram vilões. O antagonista é uma entidade fictícia ("o Mestre de Obras", ver §6).
3. **A instituição do jogo é fictícia.** O narrador é o "Programa Municipal de Memória Interativa", um programa inventado. **Não** usamos o brasão, a marca ou o nome oficial da Prefeitura de Imbé. A tela inicial traz um aviso de ficção.
4. **Fora do jogo:** o Caso Miguel (2021) e qualquer outro crime real com vítimas identificáveis.
5. **Direitos:**
   - As fotos de imprensa servem só de referência privada e não entram no repositório nem no jogo.
   - O hino municipal tem autoria (letra e melodia). Usamos um **jingle original nosso**, não o hino.
   - Assets entram só com licença CC0/MIT, ou CC-BY com crédito registrado em `CREDITS.md`.
6. **Autorização:** antes de publicar, pedir à Secretaria de Cultura de Imbé autorização de uso da imagem do prédio. Ver §10.

---

## 4. Estrutura do jogo (inspirada no Spooky's)

Um **contador de salas** no canto da tela ("Sala 01/100") marca a visita. Cada "sala" é um trecho curto: um cômodo, um corredor, um lance de escada ou um pedaço do jardim. São **100 salas** no jogo completo, divididas em 4 atos. A primeira versão jogável (MVP, §8) cobre só as salas 1 a 30.

| Ato | Salas | Nome | Tom | Onde se passa |
|---|---|---|---|---|
| I | 1 a 25 | **"Bem-vindo ao Castelinho!"** | Fofo, colorido, educativo, estilo anos 2000 | Jardim, arcada e salas térreas do museu atual (2020+), com painéis sobre a história de Imbé |
| II | 26 a 50 | **"Informações Atualizadas"** | Estranho: os painéis se contradizem e a guia se corrige | O mesmo prédio, alternando entre as versões de 1950 e de 1975 |
| III | 51 a 75 | **"Fechado para Reforma"** | Terror: perseguições, escuro, vento, inverno fora de temporada | A ruína de 2019 (telhas soltas, mato) e as **torres** |
| IV | 76 a 100 | **"Fora da Planta"** | Horror pleno, sem guia | **Masmorra**: salas geradas por embaralhamento, areia, água, conchas, cascos de navio |

### 4.1 Ato I: salas educativas (todas com fato verificado)

Cada painel traz um fato, uma ilustração e um mini-quiz opcional. Ao acertar, o jogador ganha um "selo".

| Sala | Tema do painel | Fato real (fonte: `historia_imbe.md`) | Semente creepy (sutil) |
|---|---|---|---|
| 1 | Jardim: "Este é o Castelinho!" | Casa de Cultura desde 23/12/2020 | Uma figura de papelão de um "visitante" sorridente está virada para a parede |
| 3 | Povos originários e sambaquis | Sambaquis do litoral norte | O painel diz "sambaquis eram usados como **moradia**". Na verdade também eram **cemitérios** (corrigido no Ato II) |
| 5 | De onde vem o nome Imbé? | Cipó-imbé / costela-de-Adão | Uma folha de costela-de-Adão real brota no canto do painel |
| 7 | Garibaldi e o lanchão Seival (1839) | Barco arrastado por terra até a barra | Rastro de arrasto no chão da sala |
| 9 | A cidade-jardim de 1939 | Loteamento de Ubatuba de Faria | O painel diz que os pescadores "foram **acomodados**" |
| 11 | Os botos e a pesca cooperativa | Patrimônio Cultural do Brasil desde 11/03/2026 | O boto do painel tem a nadadeira cortada e os olhos acompanham o jogador |
| 13 | A ponte | Ponte Giuseppe Garibaldi | O áudio da guia "engasga" e repete uma frase |
| 15 | Quem construiu o Castelinho? | Pedra trazida de barco, obra de décadas | Nenhum nome é citado. Uma placa diz "Construtor: _____" |
| 17 | A emancipação (1988) | Lei 8.600, de 09/05/1988 | Data correta. A guia comemora com confete |
| 20 | Sala do Pescador (cômodo real) | Mural e fauna marinha do acervo | Primeiro susto de papelão: um pescador de recorte cai da porta |
| 25 | Sala Medieval (cômodo real, com tronos) | Feira medieval (evento real) | Um dos tronos está **ocupado** por uma armadura que não estava lá |

### 4.2 Ato II: contradições

- **Os painéis voltam reescritos:** "Sambaquis eram cemitérios", "Os pescadores foram **removidos**", "Afogamentos na barra: Imbé concentra 13% das mortes do estudo". São fatos reais, ditos sem o verniz turístico.
- **O prédio pisca entre versões:** ao passar por uma porta, o jogador sai no **núcleo de 1950**, uma casa de pedra sem torres, sozinha na areia, sem cidade em volta (fiel à foto antiga).
- **A guia começa a se corrigir** e pede desculpas pelos "dados desatualizados".
- **Primeiro perseguidor de verdade** (sala 40): a Figura Branca (§6).

### 4.3 Ato III: fechado para reforma

- **Versão 2019 do prédio** (fiel à foto aérea): fibrocimento solto, arcada aberta, mato alto, céu cinza, vento constante.
- **Subida às torres:** as escadas das torres são o primeiro "espaço impossível". A subida dura mais andares do que a torre tem.
- **Mecânicas novas:** lanterna, stamina e esconderijo.
- **A guia some.** O som ambiente passa a ser o jingle tocado cada vez mais devagar.

### 4.4 Ato IV: fora da planta (masmorra)

- **A descida:** o jogador desce por um alçapão sob o piso de pedra irregular. É um porão que não existe e não poderia existir em terreno de areia, e o jogo deixa isso claro.
- **As salas da masmorra:**
  - montadas por **embaralhamento de salas pré-fabricadas**, à moda do Spooky's;
  - feitas da **mesma pedra avermelhada do Castelinho**, como se a obra nunca tivesse parado;
  - com camadas que descem: blocos de pedra, depois areia molhada, conchas (sambaqui), água e por fim cascos de navio.
- **Clímax:** o encontro com o Mestre de Obras e a revelação de que a masmorra é o castelo **continuando a se construir**.

---

## 5. Mecânica-assinatura: as "camadas de tempo"

O prédio real teve 4 estados documentados. O jogo usa cada um como cenário, e a troca entre eles é o principal truque de terror sem trair a fidelidade:

| Camada | Base real | Visual |
|---|---|---|
| **1950: núcleo** | Foto antiga do museu: dois volumes, telhado de duas águas, chaminé, areia nua | Sépia, vento, isolamento |
| **1975: castelo completo** | Torres e arcada prontas, casa de veraneio | Luz de verão, mobília de época |
| **2019: ruína** | Foto aérea de 2019: telhado de fibrocimento degradado, arcos abertos | Cinza, úmido, mato |
| **2020+: museu** | Fotos de 2026: vitrines, hortênsias, painéis | Cores vivas, "institucional" |

Em Godot, cada camada é uma variação do mesmo modelo: os objetos ganham um marcador de época e são ligados ou desligados conforme a camada. Por isso o castelo é modelado **uma vez só**, de forma modular (§7.3).

---

## 6. A guia, as criaturas e as regras

**Guia (equivalente à Spooky):** **"Bentinho"** (nome provisório), um boto-mascote de desenho animado, como os de prefeitura. Ele **não muda de aparência**, só de discurso: animado no Ato I, nervoso no Ato II, mudo e ausente no Ato III, e no Ato IV volta como gravação corrompida.

**Criaturas:** cada uma tem **uma regra** que o jogador descobre. Todas são inspiradas no folclore e na história do litoral, sem pessoas reais.

| Criatura | Inspiração | Regra | Onde aparece |
|---|---|---|---|
| **Os Recortes** | Papelão do Spooky's e visitantes de museu | Inofensivos: só assustam. Um deles **não é recorte**, e o jogador só descobre tarde demais | Ato I e II |
| **A Figura Branca** | Lenda "A Aparição" do Passo da Mãe Rosa (c. 1936) | Some quando o jogador tenta **cercá-la**, ou seja, se aproxima olhando para ela. Avança quando o jogador **dá as costas** | Ato II e III |
| **A Costela-de-Adão** | A planta que dá nome à cidade | Cresce enquanto o jogador **fica parado**. Ficar imóvel prende o jogador | Ato III |
| **Os Náufragos** | Minuano (1836), Meteoro (1902) e o "Cemitério dos Navegantes" | Só se movem quando **a água sobe**. O nível da água é cíclico, e o jogador tem que atravessar na maré baixa | Ato IV |
| **O Boto da Nadadeira Cortada** | A pesca cooperativa: o boto "sinaliza" aos pescadores | Não é inimigo: **sinaliza o caminho certo** com a cabeça. Num momento, sinaliza o errado | Ato IV |
| **O Mestre de Obras** (chefe) | O tema "obra de uma vida que nunca termina" (entidade **fictícia**, sem nome nem rosto de pessoa real) | Ouve barulho: assentar pedra faz eco. O jogador avança quando ele **está martelando** e para quando ele para | Ato IV, final |

### Finais

São 3 finais, decididos por uma contagem invisível, como no Spooky's:

1. **"Visita concluída":** o jogador fugiu. O museu reabre normalmente.
2. **"Dados atualizados":** o jogador leu todos os painéis do Ato II. A guia agradece por ele "conhecer a história verdadeira".
3. **"Mais um andar":** o jogador entregou pedras ao Mestre de Obras. O castelo ganha uma torre nova na última imagem.

---

## 7. Técnica

### 7.1 Base

- **Godot 4.x** (versão a confirmar com você, ver §12), renderer **Forward+**. A névoa volumétrica da masmorra exige esse renderer.
- **GDScript.** Nenhuma linguagem extra.
- **Plataforma inicial:** PC (Windows/Linux). Exportação web fica para depois, porque não tem névoa volumétrica.

### 7.2 Estrutura de pastas proposta

```
project.godot
autoload/       GameState.gd (sala atual, corruption 0-1, camada de tempo, contagens invisíveis)
                Audio.gd, Save.gd
player/         Player.tscn (CharacterBody3D: andar, correr, stamina, lanterna, interagir)
castelinho/     peças modulares (paredes, arcos, ameias, torres) + Castelinho.tscn montado
rooms/          act1/ act2/ act3/ act4/  (cada sala: uma cena com Marker3D de entrada e saída)
creatures/      FiguraBranca/, Costela/, Naufrago/, MestreDeObras/
ui/             HUD (contador de salas), Painel (texto educativo + quiz), Dialogo da guia
shaders/        psx.gdshader, dither.gdshader (intensidade ligada a GameState.corruption)
assets/         texturas, sons, fontes + _licenses/
docs/           este plano, pesquisa, CREDITS.md
tools/          gerar_castelinho.py (Blender headless)
```

### 7.3 Como modelar o Castelinho fiel (sem você precisar modelar à mão)

1. **Um arquivo de medidas:** `castelinho/medidas.json` guarda as larguras, alturas, posições das torres, aberturas e espessura das paredes. Hoje os valores são estimados das fotos. Depois da visita presencial, você corrige os números.
2. **Geração por script:** um script Python roda o **Blender sem interface** aqui na nuvem, gera o modelo a partir das medidas e exporta em `.glb` para o Godot. Quando uma medida muda, basta regenerar.
3. **Textura da pedra:** primeiro uma textura CC0 de tijolo/arenito (ambientCG ou Poly Haven) tingida no tom das fotos (#A8583F a #C9806A, juntas claras e grossas). Depois, a sua foto de 1 m² da parede real.
4. **Validação visual:** renderizo o modelo nos mesmos ângulos das fotos de referência e mostro os dois lado a lado para você aprovar.

### 7.4 Um botão controla o terror: `corruption`

O valor `GameState.corruption` vai de 0 a 1 ao longo das 100 salas e controla tudo ao mesmo tempo:

- **Imagem:** na intensidade do shader PSX (tremor de vértices, resolução menor, pontilhado), na saturação e no grão.
- **Névoa:** na densidade e na cor.
- **Som:** no tom e na velocidade do jingle, e no reverb.
- **Texto:** em erros de digitação nos painéis e em quanto a interface falha.

### 7.5 Addons (todos MIT, a confirmar na instalação)

- **Diálogo:** Dialogue Manager (Nathan Hoad), para a guia e os painéis.
- **Visual PS1:** shader PSX baseado em `psx_visuals_gd4` (MIT).
- **Controlador do jogador:** escrito por nós (cerca de 200 linhas). Os repositórios citados na pesquisa servem só de consulta.
- **Masmorra:** gerador próprio simples que **embaralha salas pré-fabricadas**. Não precisa de WFC.

---

## 8. Roteiro de construção (marcos)

Cada marco termina com algo que **você abre no Godot e testa**, e com uma revisão sua antes de seguir.

| Marco | Entrega | Você revisa |
|---|---|---|
| **M0: Fundação** | Projeto Godot criado, pastas, `GameState`, jogador andando numa sala cinza, contador de salas | Abre e anda |
| **M1: Castelinho v1** | Modelo gerado das medidas estimadas, jardim, texturas CC0, comparação lado a lado com as fotos | Fidelidade do exterior |
| **M2: Ato I jogável** | Salas 1 a 25: painéis educativos com quiz, guia Bentinho, sustos de papelão | Tom "jogo da prefeitura", textos históricos |
| **M3: Corruption + camadas de tempo** | Shader PSX progressivo, camadas 1950/1975/2019, Ato II | Se a virada de tom funciona |
| **M4: Primeira criatura** | Figura Branca com IA e regra, morte e checkpoint | Se dá medo de verdade |
| **MVP (M0 a M4)** | **Salas 1 a 30 jogáveis**, exportáveis para Windows | Teste com amigos |
| **M5: Ato III** | Torres impossíveis, ruína de 2019, lanterna, stamina, Costela-de-Adão | |
| **M6: Ato IV** | Gerador da masmorra, Náufragos, Boto, Mestre de Obras, finais | |
| **M7: Polimento** | Áudio, menus, opções, créditos, revisão de licenças, build final | |

**Como a IA divide o trabalho:**
- **Opus:** planeja e revisa.
- **Sonnet:** escreve código e cenas.
- **Haiku:** tarefas repetitivas, como textos de painéis, a planilha de créditos e a conferência de licenças.

Tudo é commitado no GitHub, e você revisa cada marco.

**Testes aqui na nuvem:** instalo o Godot e o Blender no container. Com eles, valido que as cenas carregam sem erro e tiro capturas de tela para você revisar antes de abrir no seu computador.

---

## 9. Lição de casa presencial (para fidelidade de verdade)

A Casa de Cultura abre **de segunda a sexta (8h-12h e 13h30-17h30)**, com **visita guiada às torres aos sábados (9h-17h)**. Endereço: Av. Nilza Costa Godoy esq. Av. Garibaldi, Centro, Imbé. Checklist completo em `pesquisa/castelinho.md` §6. O essencial:

1. **Fotos:** as 4 fachadas de frente, sem inclinar o celular, e os 4 lados de cada torre.
2. **Medidas com trena:**
   - comprimento de cada fachada;
   - altura de uma porta, da arcada e do parapeito;
   - largura dos pilares;
   - espessura de parede (mede-se no vão de uma janela).
3. **Tamanho do bloco de pedra:** foto de um bloco ao lado de uma régua.
4. **Interior:** como se sobe às torres (escada de pedra? de madeira? caracol?), quantos níveis cada torre tem e um croqui à mão da sequência de salas.
5. **Texturas:** foto de 1 m² de parede, do piso de pedra, de uma porta e de uma janela, em dia nublado (luz difusa).
6. **Vídeo:** um vídeo lento andando por dentro, para usar como referência de escala.

Quando voltar, mande tudo, que eu atualizo o `medidas.json`.

---

## 10. Riscos

| Risco | Mitigação |
|---|---|
| **Escopo grande** para um projeto solo com IA | MVP de 30 salas primeiro. As 100 salas só depois do teste. |
| **Imagem de um prédio público em jogo de terror** | Avisar a Secretaria de Cultura e pedir autorização por escrito antes de publicar. Prefeitura fictícia e aviso de ficção. Uma exposição positiva pode até interessar ao museu. |
| **Falta de medidas reais** | Modelo paramétrico: corrigir números não exige refazer nada. |
| **Licenças de assets** | `CREDITS.md` desde o primeiro asset. Só CC0/MIT, ou CC-BY com crédito. |
| **Versão do Godot** diferente da sua | Fixar a mesma versão no container e no seu PC. |
| **Jump scares baratos** | Seguir o Spooky's: regras legíveis, silêncio e pausas. Os sustos reais são poucos e bem colocados. |

---

## 11. Próximos passos imediatos

1. Você responde às perguntas da §12.
2. Começo o **M0** (projeto Godot base) e o **M1** (Castelinho gerado das fotos), no ramo `claude/confident-euler-tlf6z1`.
3. Você agenda uma visita de sábado ao Castelinho para o levantamento da §9.

---

## 12. Perguntas para você (decidem o rumo)

1. **Versão do Godot:** qual está instalada no seu computador? Aparece em *Ajuda → Sobre*. O ideal é 4.4 ou mais nova.
2. **Público e publicação:** o jogo é para você e amigos, para a itch.io/Steam ou para mostrar à própria prefeitura? Isso muda o cuidado com autorização e o nível de terror.
3. **Nível de terror:** "Spooky's" (sustos com humor) ou mais pesado, tipo "Puppet Combo" (sangue, perturbador)?
4. **A guia:** gosta do boto-mascote "Bentinho"? Tem outra ideia de nome ou de bicho, como uma tainha ou um quero-quero?
5. **Tamanho:** MVP de 30 salas primeiro, e só então o jogo inteiro de 100? Ou prefere um jogo curto e fechado, com umas 40 salas?
6. **Visita presencial:** consegue ir ao Castelinho num sábado para fotos e medidas? Se não, seguimos só com fotos da internet e Street View, com menos precisão.
7. **Idioma:** só português ou também inglês?
8. **Visual do Ato I:** "jogo educativo em Flash dos anos 2000" (cores chapadas, fonte Comic Sans) ou "app de museu moderno" (limpo, institucional)?
