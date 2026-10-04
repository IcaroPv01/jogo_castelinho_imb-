# Plano do jogo: Castelinho de Imbé

> Documento-mestre do projeto. Base: `docs/pesquisa/castelinho.md`, `docs/pesquisa/historia_imbe.md` e `docs/pesquisa/spookys_e_referencias.md`.
> **Status:** rascunho **v0.2** (04/10/2026), já com as respostas do Icaro às perguntas da v0.1 (ver §12). Falta a aprovação final para começar o M0.

---

## 1. A ideia em uma frase

Um "jogo educativo da prefeitura" com cara de **Flash dos anos 2000** que faz uma visita guiada pelo Castelinho de Imbé contando a história da cidade, sala por sala. Objetos do museu levam a **flashbacks** em outros lugares de Imbé. Aos poucos a visita para de fazer sentido, o prédio começa a mudar e o jogador acaba descendo para uma masmorra que **não está na planta**.

**Título provisório:** *Castelinho: Visita Guiada* (alternativas: *Conheça Imbé!*, *Costela-de-Adão*).

**Decisões tomadas (v0.2):**
- **Público:** amigos.
- **Onde se joga:** no **navegador do computador**, via GitHub Pages. Nada para instalar.
- **Idioma:** só português.
- **Tom:** **sustos com humor** (Spooky's) com **trechos pesados e perturbadores** pontuais (§4.5).
- **Visual do começo:** **Flash educativo dos anos 2000**.
- **Tamanho:** MVP de 30 salas, depois expandimos para 100.
- **Modelagem:** **sem visita presencial** por enquanto. Usamos fotos online, satélite e OpenStreetMap.

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

### 4.5 Humor e peso: onde fica cada um

A base é **humor de Spooky's**: recortes de papelão, a Tainá fazendo piada de peixe, quiz com resposta absurda e o Quico apitando. Os **trechos pesados** são poucos, curtos e anunciados pela mudança de som (o jingle para). Neles não tem piada nenhuma.

| Trecho pesado | Por que pesa | Limite |
|---|---|---|
| Flashback do loteamento de 1939 | Remoção real de moradores. O jogador "aprova" lotes num minigame e vê os ranchos sumirem um a um | Sem gore. O horror é a burocracia alegre contra gente real (genérica, sem nomes) |
| Flashback do naufrágio de 1902 | Morte no mar, escuro, água subindo | Sem cadáveres explícitos. Silhuetas, vozes e a água |
| Sala do sambaqui (Ato IV) | Cemitério ancestral | Respeito: nada de "índio monstro". O horror é a profanação, e quem é punido é quem cava |
| Ato IV, perto do Mestre de Obras | Obsessão e trabalho sem fim: paredes com marcas de unha e pedras "assentadas" em formato de gente | Perturbador, mas sem sangue em excesso |

**Linhas que não cruzamos:** crimes reais, vítimas reais, a enchente de 2024 como espetáculo, povos indígenas como monstros e pessoas reais nomeadas.

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

### 5.1 As camadas dentro do jogo: o "Visor do Tempo"

As épocas não trocam sozinhas. O jogador **usa** a troca:

- **Ato I, ferramenta educativa:**
  - Bentinho entrega um **Visor do Tempo**, um visor de slides de plástico como os View-Master de criança, com a marca do "Programa Municipal".
  - Ao apertar `Q`, o jogador olha pelo visor e vê a sala como era em outra época, com uma legenda didática: "Em 1950, aqui era só areia!".
  - É um brinquedo e serve para achar selos escondidos.
- **Ato II, o visor começa a mentir:**
  - O jogador olha pelo visor e vê algo que não deveria estar lá: uma pessoa parada, uma porta que não existe.
  - Às vezes, ao baixar o visor, **a época não volta**.
- **Ato III, puzzle e fuga:**
  - Uma porta trancada em 2020 estava aberta em 1975.
  - Uma escada desabada em 2019 está inteira em 1950.
  - Para fugir de uma criatura, o jogador troca de época: ela some, mas outra coisa pode estar esperando.
- **Ato IV, sem visor:**
  - O visor quebra, e a masmorra não tem época.
  - Na parede há fotos de todas as épocas, inclusive **de épocas que ainda não aconteceram**.

### 5.2 Flashbacks: fora do castelo

O jogo **não fica preso ao lote**. Alguns objetos do acervo do museu (que existem de verdade, ver `castelinho.md` §3.10) abrem **flashbacks jogáveis** em outros lugares e épocas de Imbé.

Cada flashback é uma fase curta e linear, com o **mesmo truque de tom**: começa como "cena educativa" e termina estranha.

| Objeto do acervo (gatilho) | Flashback | Época | Começa como... | ...e vira |
|---|---|---|---|---|
| Ossos de baleia / conchas | **Sambaqui** na beira da lagoa | pré-colonial | Aula de arqueologia: "ajude a montar o sambaqui!" | O monte de conchas é também cemitério. As conchas estão quentes |
| Gravura de barco | **O lanchão Seival** arrastado por terra até a barra | 1839 | Minigame de puxar o barco com os bois | Na névoa, alguém continua puxando muito depois que todos pararam |
| Mapa de loteamento antigo | **Loteamento da cidade-jardim** | 1939 | Minigame de "planejar a cidade" com ruas curvas e praças | Cada lote marcado tem um rancho de pescador que precisa "sair". Trecho **pesado** (§4.5) |
| Mural da Sala do Pescador | **Barra do Tramandaí**: pesca com os botos | anos 1960/hoje | Minigame de tarrafa: lance a rede quando o boto sinalizar | O boto sinaliza na hora errada. O rio puxa |
| Foto da ponte | **Ponte Giuseppe Garibaldi** à noite | anos 1980 | Passeio de carro "turístico" | Pescadores de sardinha que não se mexem, sempre os mesmos |
| Telefone antigo do acervo | **Praia em pleno inverno**: guaritas fechadas, Av. Beira-Mar vazia | qualquer inverno | O telefone toca: "Alô? A temporada acabou?" | A cidade de 80 mil habitantes tem 16 mil. Todas as janelas estão fechadas, menos uma |
| Sino de navio | **Naufrágio** na costa ("Cemitério dos Navegantes") | 1902 | Painel sobre o navio Meteoro | O jogador está no convés. Trecho **pesado** (§4.5) |

**Fidelidade dos flashbacks:**
- Os lugares reais (barra, ponte, praia, guaritas) são modelados por foto, em versão simplificada.
- As pessoas são sempre genéricas ou fictícias.
- **Enchente de 2024:** **fora** como cena de terror. Foi recente, tem vítimas e afetou quem vai jogar. No máximo uma menção respeitosa num painel do Ato I.

---

## 6. A guia, as criaturas e as regras

**Guia (equivalente à Spooky):** **"Bentinho"**, um boto-mascote de desenho animado, como os de prefeitura. Ele **não muda de aparência**, só de discurso: animado no Ato I, nervoso no Ato II, mudo e ausente no Ato III, e no Ato IV volta como gravação corrompida.

**A Turma da Memória:** três mascotes do "Programa Municipal", no estilo Flash, que aparecem juntos na tela de título. Os nomes são provisórios.

| Mascote | Bicho | Papel no Ato I | Como vira |
|---|---|---|---|
| **Bentinho** | Boto | Guia principal, apresenta as salas | Fica nervoso, some e volta corrompido (acima) |
| **Tainá** | Tainha | Apresenta os **quizzes** ("Acertou, guri!") e os flashbacks da pesca | Ela é o peixe que boto e pescador caçam juntos. Aos poucos percebe isso. No flashback da barra, é ela na rede. É o trecho de **humor negro** |
| **Quico** | Quero-quero (ave-símbolo do RS) | "Fiscal" da visita: apita quando o jogador sai do caminho e guarda os **selos** | O quero-quero real ataca quem chega perto do ninho. Quico passa a "defender" a masmorra e vira um **perseguidor com regra**: no Ato III, o grito dele avisa onde o jogador está. Fica-se longe dos **ninhos** no chão |

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

- **Godot 4:** a versão estável mais recente. Ela fica fixada no projeto e no robô de publicação. Você baixa a mesma para editar no seu PC.
- **Renderer Compatibility (WebGL2):** é o **único** que roda no navegador. Na v0.1 o plano previa Forward+, e isso muda:
  - **Sem névoa volumétrica:** a masmorra usa névoa de profundidade simples, que combina com o visual PS1. Partículas por GPU e alguns efeitos de pós-processamento também ficam limitados (lista exata em `pesquisa/tecnico_web_e_estetica_flash.md`).
  - **Performance de navegador:** tudo low-poly, texturas pequenas, poucas luzes dinâmicas. O estilo PS1/Flash ajuda.
  - **Mouse e som:** o jogo pede um clique para começar. O navegador exige isso para capturar o mouse e tocar áudio.
- **GDScript.** Nenhuma linguagem extra.
- **Plataforma:** **navegador de computador**, via GitHub Pages. Celular fica fora.

### 7.1.1 Publicação automática (GitHub Pages)

1. Toda vez que algo entra na branch `main`, um **GitHub Action** baixa o Godot, exporta o jogo para Web e publica.
2. O jogo fica em `https://icaropv01.github.io/jogo_castelinho_imb-/`.
3. A exportação é **single-threaded**, a opção que funciona no GitHub Pages sem configuração extra de servidor.
4. Para funcionar, o **repositório precisa ser público**, porque o GitHub Pages gratuito não funciona em repositório privado. O GitHub Pro resolve isso e é grátis para estudantes pelo GitHub Education.
5. Também é preciso ligar **Settings → Pages → Source: GitHub Actions** uma única vez.

### 7.1.2 Organização do repositório

- **`main`:** sempre jogável. É o que está publicado.
- **Branches por marco:** uma branch de trabalho por marco (M0, M1...). Cada marco vira um **Pull Request** que você revisa e aprova antes de entrar na `main`.
- **Documentação:**
  - `docs/PLANO.md` é este documento.
  - `docs/pesquisa/` guarda as pesquisas.
  - `docs/CREDITS.md` lista todo asset de terceiros com a licença.
- **Fotos de imprensa:** só no computador local, nunca no git.

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

1. **Um arquivo de medidas:** `castelinho/medidas.json` guarda as larguras, alturas, posições das torres, aberturas e espessura das paredes. Fontes:
   - a pegada (contorno) vem do **OpenStreetMap** e da **imagem de satélite**;
   - as alturas e as aberturas vêm de **fotos online** com referência de escala (porta, pessoa, carro);
   - cada número registra de onde veio e a confiança (`pesquisa/medidas_estimadas.json`).

   Se um dia houver visita presencial, só se corrigem os números.
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
| **M0: Fundação** | Projeto Godot criado, pastas, `GameState`, jogador andando numa sala cinza, contador de salas, **publicação automática no GitHub Pages funcionando** | Abre o link no navegador e anda |
| **M1: Castelinho v1** | Modelo gerado das medidas estimadas, jardim, texturas CC0, comparação lado a lado com as fotos | Fidelidade do exterior |
| **M2: Ato I jogável** | Salas 1 a 25: painéis educativos com quiz, interface estilo Flash, Turma da Memória (Bentinho, Tainá, Quico), sustos de papelão | Tom "jogo da prefeitura", textos históricos |
| **M3: Corruption + Visor do Tempo** | Shader PSX progressivo, Visor do Tempo com as camadas 1950/1975/2019/2020, Ato II | Se a virada de tom funciona |
| **M3.5: Primeiro flashback** | Barra do Tramandaí: minigame da tarrafa com o boto | Se os flashbacks valem a pena |
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

## 9. Levantamento do prédio

**Decisão v0.2:** fazemos **sem visita presencial**. A pesquisa online cobre:
- satélite e OpenStreetMap para a planta;
- notícias, Mapillary e vídeos para as fachadas;
- fotos de interior das reportagens.

Os resultados ficam em `pesquisa/geometria_e_fotos.md`. O checklist abaixo continua aqui para quando (e se) houver uma visita.

### 9.1 Checklist para uma visita futura (opcional)

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
| **Imagem de um prédio público em jogo de terror** | O público é de amigos, mas o link do GitHub Pages é aberto. Prefeitura fictícia, aviso de ficção na tela inicial e nenhum brasão real. Se o jogo for divulgado além dos amigos, pedir autorização à Secretaria de Cultura. |
| **Fotos de imprensa no histórico do git** | Elas entraram por engano no 1º commit, e já foram tiradas da versão atual. **Antes de tornar o repositório público**, é preciso limpá-las do histórico (reescrever o histórico, o que pede a sua autorização). |
| **Falta de medidas reais** | Modelo paramétrico: corrigir números não exige refazer nada. |
| **Licenças de assets** | `CREDITS.md` desde o primeiro asset. Só CC0/MIT, ou CC-BY com crédito. |
| **Versão do Godot** diferente da sua | Fixar a mesma versão no container e no seu PC. |
| **Jump scares baratos** | Seguir o Spooky's: regras legíveis, silêncio e pausas. Os sustos reais são poucos e bem colocados. |

---

## 11. Próximos passos imediatos

1. ~~Você responde às perguntas da §12.~~ Feito.
2. **Você:**
   - torna o repositório público;
   - define `main` como branch padrão;
   - liga o GitHub Pages com Source = GitHub Actions.
3. **Você aprova este plano** no Pull Request.
4. Começo o **M0** (projeto Godot base + publicação no GitHub Pages) e depois o **M1** (Castelinho gerado das medidas online).

---

## 12. Perguntas e respostas

### Respostas do Icaro (v0.2)

| Pergunta | Resposta | Efeito no plano |
|---|---|---|
| Versão do Godot | Não sabe | Fixamos a estável mais recente e você baixa a mesma |
| Público | Amigos, via GitHub Pages no PC | Renderer Compatibility, deploy automático, repositório público |
| Nível de terror | Sustos com humor + partes pesadas e perturbadoras | §4.5 |
| Guia | Bentinho aprovado, e os outros personagens também | Turma da Memória (§6) |
| Tamanho | MVP e depois expandir | Mantido |
| Visita presencial | Não, por enquanto. Pesquisar fotos | §9 |
| Idioma | Só português | — |
| Visual do Ato I | Flash educativo | §7 e `pesquisa/tecnico_web_e_estetica_flash.md` |
| Extra: épocas | Usar as 4 versões dentro do jogo | Visor do Tempo (§5.1) |
| Extra: fora do castelo | Barra de Imbé etc., talvez em flashbacks | Flashbacks (§5.2) |

### Perguntas originais (v0.1)

1. **Versão do Godot:** qual está instalada no seu computador? Aparece em *Ajuda → Sobre*. O ideal é 4.4 ou mais nova.
2. **Público e publicação:** o jogo é para você e amigos, para a itch.io/Steam ou para mostrar à própria prefeitura? Isso muda o cuidado com autorização e o nível de terror.
3. **Nível de terror:** "Spooky's" (sustos com humor) ou mais pesado, tipo "Puppet Combo" (sangue, perturbador)?
4. **A guia:** gosta do boto-mascote "Bentinho"? Tem outra ideia de nome ou de bicho, como uma tainha ou um quero-quero?
5. **Tamanho:** MVP de 30 salas primeiro, e só então o jogo inteiro de 100? Ou prefere um jogo curto e fechado, com umas 40 salas?
6. **Visita presencial:** consegue ir ao Castelinho num sábado para fotos e medidas? Se não, seguimos só com fotos da internet e Street View, com menos precisão.
7. **Idioma:** só português ou também inglês?
8. **Visual do Ato I:** "jogo educativo em Flash dos anos 2000" (cores chapadas, fonte Comic Sans) ou "app de museu moderno" (limpo, institucional)?
