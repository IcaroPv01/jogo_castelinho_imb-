'use strict';
// Abre o build Web REAL do jogo no Chromium com emulação de celular (844x390, toque), tira fotos das
// etapas (título, jogo, fala, andar com o analógico, pausa, retrato) e grava os erros do console.
// Uso: node tools/testar_web_celular.js <pasta_build> <pasta_saida>
// O servidor (com COOP/COEP) é subido por tools/testar_web_celular.sh em http://localhost:$PORTA_WEB.
// BOTAO_INICIO="x,y" (frações da tela) aponta o botão de começar do título.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const [, , PASTA_BUILD, PASTA_SAIDA] = process.argv;
if (!PASTA_BUILD || !PASTA_SAIDA) {
  console.error('uso: node tools/testar_web_celular.js <pasta_build> <pasta_saida>');
  process.exit(2);
}
const PORTA = process.env.PORTA_WEB || '8772';
const URL_JOGO = `http://localhost:${PORTA}/index.html?celular=1`;
const [INI_X, INI_Y] = (process.env.BOTAO_INICIO || '0.72,0.836').split(',').map(Number);
const W = 844, H = 390;
const UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) ' +
  'Chrome/141.0.0.0 Mobile Safari/537.36';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function carregarPlaywright() {
  try { return require('playwright'); } catch (e) { /* cai no global */ }
  return require(path.join(execSync('npm root -g').toString().trim(), 'playwright'));
}

function acharChromium() {
  const base = '/opt/pw-browsers';
  if (!fs.existsSync(base)) return undefined;
  const dirs = fs.readdirSync(base).filter((d) => /^chromium-\d+$/.test(d)).sort().reverse();
  for (const d of dirs) {
    const exe = path.join(base, d, 'chrome-linux', 'chrome');
    if (fs.existsSync(exe)) return exe;
  }
  return undefined;
}

(async () => {
  const { chromium } = carregarPlaywright();
  fs.mkdirSync(PASTA_SAIDA, { recursive: true });
  const t0 = Date.now();
  const tempo = () => ((Date.now() - t0) / 1000).toFixed(1) + 's';
  const passos = [];
  const passo = (msg) => { const s = `[${tempo()}] ${msg}`; passos.push(s); console.log(s); };
  const console_linhas = [];

  const exe = acharChromium();
  passo(`chromium: ${exe || '(padrão do Playwright)'}`);
  const browser = await chromium.launch({
    executablePath: exe,
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const context = await browser.newContext({
    viewport: { width: W, height: H },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
    userAgent: UA,
  });
  const page = await context.newPage();
  const diag_linhas = [];
  page.on('console', (m) => {
    if (m.text().startsWith('[diag]')) diag_linhas.push(`[${tempo()}] ${m.text()}`);
    if (m.type() === 'error' || m.type() === 'warning') console_linhas.push(`[${m.type()}] ${m.text()}`);
  });
  page.on('pageerror', (e) => console_linhas.push(`[pageerror] ${e.message}`));
  page.on('requestfailed', (r) => console_linhas.push(`[requestfailed] ${r.url()} ${r.failure() ? r.failure().errorText : ''}`));
  page.on('crash', () => console_linhas.push('[crash] a página caiu'));

  const foto = async (nome) => {
    const buf = await page.screenshot({ path: path.join(PASTA_SAIDA, nome) });
    passo(`foto ${nome} (${buf.length} bytes)`);
    return buf.length;
  };

  // espera a tela ficar pronta: a foto deixa de ser "vazia" (canvas preto ocupa pouco no PNG)
  async function esperarPronta(maxMs, limiarBytes) {
    const ini = Date.now();
    while (Date.now() - ini < maxMs) {
      const buf = await page.screenshot();
      if (buf.length > limiarBytes) return true;
      await sleep(3000);
    }
    return false;
  }

  // espera o carregamento acabar: o tamanho da foto para de mudar em 2 amostras seguidas (aprox.)
  async function esperarCarregar(maxMs) {
    const ini = Date.now();
    let anterior = -1, iguais = 0, serie = [];
    while (Date.now() - ini < maxMs) {
      await sleep(4000);
      const n = (await page.screenshot()).length;
      serie.push(n);
      iguais = Math.abs(n - anterior) < anterior * 0.002 ? iguais + 1 : 0;
      anterior = n;
      if (iguais >= 2) break;
    }
    passo(`amostras pós-início (bytes): ${serie.join(', ')}`);
    return Date.now() - ini < maxMs;
  }


  // ---- leitura de pixels da foto (PNG 8 bits sem entrelaçamento, via zlib) para saber se o balão da Guia está na tela
  const zlib = require('zlib');
  function decodificarPng(buf) {
    let pos = 8, w = 0, h = 0, canais = 4; const idat = [];
    while (pos < buf.length) {
      const len = buf.readUInt32BE(pos), tipo = buf.toString('ascii', pos + 4, pos + 8);
      if (tipo === 'IHDR') { w = buf.readUInt32BE(pos + 8); h = buf.readUInt32BE(pos + 12); canais = buf[pos + 17] === 6 ? 4 : 3; }
      if (tipo === 'IDAT') idat.push(buf.subarray(pos + 8, pos + 8 + len));
      pos += 12 + len;
    }
    const raw = zlib.inflateSync(Buffer.concat(idat));
    const stride = w * canais, out = Buffer.alloc(h * stride);
    for (let y = 0; y < h; y++) {
      const f = raw[y * (stride + 1)];
      for (let x = 0; x < stride; x++) {
        const v = raw[y * (stride + 1) + 1 + x];
        const a = x >= canais ? out[y * stride + x - canais] : 0;
        const b = y > 0 ? out[(y - 1) * stride + x] : 0;
        const c = (x >= canais && y > 0) ? out[(y - 1) * stride + x - canais] : 0;
        let r = v;
        if (f === 1) r = v + a; else if (f === 2) r = v + b; else if (f === 3) r = v + ((a + b) >> 1);
        else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); r = v + (pa <= pb && pa <= pc ? a : (pb <= pc ? b : c)); }
        out[y * stride + x] = r & 255;
      }
    }
    return { w, h, canais, px: (x, y) => { const i = y * stride + x * canais; return [out[i], out[i + 1], out[i + 2]]; } };
  }
  // o balão é creme (FFF6DA) e ocupa a faixa de baixo; amostra vários pontos dentro dele (em px CSS)
  async function balaoVisivel() {
    const img = decodificarPng(await page.screenshot());
    const k = img.w / W;
    let n = 0;
    for (const [x, y] of [[300, 345], [380, 355], [450, 335], [520, 355], [330, 330]]) {
      const [r, g, b] = img.px(Math.round(x * k), Math.round(y * k));
      if (r > 245 && g > 235 && g < 252 && b > 205 && b < 232) n++;
    }
    return n >= 2;
  }

  const cdp = await context.newCDPSession(page);

  passo(`abrindo ${URL_JOGO}`);
  await page.goto(URL_JOGO, { waitUntil: 'load', timeout: 120000 });
  passo('página carregada (load)');
  const pronta = await esperarPronta(90000, 15000);
  passo(pronta ? 'título visível' : 'título não apareceu em 90 s (foto mesmo assim)');
  await foto('01_titulo.png');

  passo(`toque no começar (${INI_X * W}, ${INI_Y * H})`);
  await page.touchscreen.tap(INI_X * W, INI_Y * H);
  const tCarregar = Date.now();
  const fim = await esperarCarregar(120000);
  passo(`carregamento: ${fim ? 'terminou' : 'NÃO terminou em 120 s'} em ${((Date.now() - tCarregar) / 1000).toFixed(1)} s`);
  await foto('02_jogo.png');

  // ---- fala de abertura: toca na área de olhar até o balão (creme) sumir
  let toques = 0;
  for (; toques < 14; toques++) {
    if (!(await balaoVisivel())) break;
    await page.touchscreen.tap(W * 0.5, H * 0.25);
    await sleep(1400);
  }
  passo(`fala: ${toques} toques até o balão sumir (${(await balaoVisivel()) ? 'AINDA VISÍVEL' : 'sumiu'})`);
  await foto('03_apos_fala.png');

  // ---- olhar: o Painel 01 fica a (+3,4, -3,1) m do jogador, que olha ~28° para a esquerda dele: faltam 0,35 rad.
  // 0,35 rad / 0,005 rad por px do canvas / 1,37 px do canvas por px CSS = ~51 px CSS de arrasto para a direita.
  passo('olhar: arrasto de 51 px para a direita (vira ~0,35 rad para o Painel 01)');
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: W * 0.6, y: H * 0.4, id: 2 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: W * 0.6 + 25, y: H * 0.4, id: 2 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: W * 0.6 + 51, y: H * 0.4, id: 2 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(800);
  await foto('04_olhou.png');

  // ---- analógico: sobe 100 px e SEGURA em pulsos de 0,6 s até o botão Interagir brilhar (amarelo = há alvo).
  // (o tempo de jogo anda devagar com a GPU por software, então não dá para contar o caminho em segundos)
  const x0 = W * 0.18, y0 = H * 0.72, subida = 100;
  const R_INTERAGIR = [790, 337];   // centro do botão Interagir em px CSS (canvas 1154x533 -> 844x390)
  let cor_interagir = '';
  async function interagirBrilha() {
    const img = decodificarPng(await page.screenshot());
    const k = img.w / W;
    const [r, g, b] = img.px(Math.round(R_INTERAGIR[0] * k), Math.round((R_INTERAGIR[1] + 28) * k));
    cor_interagir = `${r},${g},${b}`;
    return r > 200 && g > 150 && b < 140 && r - b > 100;   // amarelo (alvo) contra o cinza/creme do botão parado
  }
  let pulsos = 0;
  for (; pulsos < 3; pulsos++) {   // (nos logs: o alvo aparece no 3º pulso)
    if (await interagirBrilha()) break;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0, id: 1 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0, y: y0 - subida, id: 1 }] });
    await sleep(600);
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await sleep(400);
  }
  passo(`analógico: ${pulsos} pulsos de 0,6 s; Interagir ${(await interagirBrilha()) ? 'BRILHA (alvo)' : 'não brilha'} (cor ${cor_interagir})`);
  await foto('06_perto_painel.png');

  // ---- painel: Interagir (brilha amarelo quando há alvo) abre a tela de leitura
  passo(`toque em Interagir (${R_INTERAGIR})`);
  await page.touchscreen.tap(R_INTERAGIR[0], R_INTERAGIR[1]);
  await sleep(3000);
  await foto('07_painel.png');
  // fecha: botão "Entendi!" (embaixo à direita da janela do painel); 3 toques (o 1º pode só terminar a digitação)
  for (let i = 0; i < 3; i++) {
    await page.touchscreen.tap(610, 330);
    await sleep(1500);
    if (i === 0) await foto('08_painel_apos_toque.png');
  }
  await foto('09_painel_fechado.png');

  // ---- analógico visível: dedo no vidro (o jogador anda para trás durante a foto, que demora)
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0 - 40, id: 1 }] });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: x0 + 20, y: y0 + 10, id: 1 }] });
  await sleep(500);
  await foto('09b_analogico_em_uso.png');
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(500);

  // ---- pausa: botão no canto de cima à direita
  passo('toque no botão de pausa (canto superior direito)');
  await page.touchscreen.tap(W - 46, 46);
  await sleep(1500);
  await foto('10_pausa.png');
  passo('toque em Opções');
  await page.touchscreen.tap(W / 2, 217);
  await sleep(1000);
  await foto('11_opcoes.png');
  passo('toque em Voltar e em Continuar');
  await page.touchscreen.tap(W / 2, 296);
  await sleep(800);
  await page.touchscreen.tap(W / 2, 171);
  await sleep(1500);
  await foto('12_continuou.png');

  passo('viewport 390x844 (retrato)');
  await page.setViewportSize({ width: 390, height: 844 });
  await sleep(4000);
  await foto('13_retrato.png');
  passo('viewport 844x390 de novo');
  await page.setViewportSize({ width: W, height: H });
  await sleep(3000);
  await foto('14_deitado_de_novo.png');

  await browser.close();

  const cab = `# console: ${console_linhas.length} linhas de error/warning (uniques: ${new Set(console_linhas).size})`;
  fs.writeFileSync(path.join(PASTA_SAIDA, 'console.txt'), [cab, ...console_linhas].join('\n') + '\n');
  fs.writeFileSync(path.join(PASTA_SAIDA, 'diag.txt'), diag_linhas.join('\n') + '\n');
  fs.writeFileSync(path.join(PASTA_SAIDA, 'passos.txt'), passos.join('\n') + '\n');
  console.log(cab);
  const unicos = [...new Set(console_linhas)];
  unicos.slice(0, 5).forEach((l) => console.log('  ' + l.slice(0, 300)));
  console.log(`fim em ${tempo()}`);
})().catch((e) => {
  console.error('FALHA:', e && e.stack ? e.stack : e);
  process.exit(1);
});
