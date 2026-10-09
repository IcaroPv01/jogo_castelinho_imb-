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
  page.on('console', (m) => {
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

  for (let i = 0; i < 3; i++) {
    await page.touchscreen.tap(W / 2, H / 2);
    await sleep(1500);
  }
  await foto('03_fala.png');

  // analógico: toque na metade esquerda, arrasta para cima por 2 s (CDP), foto com o dedo ainda no vidro
  const x0 = W * 0.18, y0 = H * 0.72, subida = 150, passos_mov = 20;
  passo(`analógico: toque em (${x0}, ${y0}) e subida de ${subida}px em 2 s`);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: x0, y: y0, id: 1 }] });
  for (let i = 1; i <= passos_mov; i++) {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove', touchPoints: [{ x: x0, y: y0 - (subida * i) / passos_mov, id: 1 }],
    });
    await sleep(100);
  }
  await foto('04_andou.png');
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(1000);

  passo('toque no botão de pausa (canto superior direito)');
  await page.touchscreen.tap(W - 46, 46);
  await sleep(1500);
  await foto('05_pausa.png');

  passo('viewport 390x844 (retrato)');
  await page.setViewportSize({ width: 390, height: 844 });
  await sleep(4000);
  await foto('06_retrato.png');

  await browser.close();

  const cab = `# console: ${console_linhas.length} linhas de error/warning (uniques: ${new Set(console_linhas).size})`;
  fs.writeFileSync(path.join(PASTA_SAIDA, 'console.txt'), [cab, ...console_linhas].join('\n') + '\n');
  fs.writeFileSync(path.join(PASTA_SAIDA, 'passos.txt'), passos.join('\n') + '\n');
  console.log(cab);
  const unicos = [...new Set(console_linhas)];
  unicos.slice(0, 5).forEach((l) => console.log('  ' + l.slice(0, 300)));
  console.log(`fim em ${tempo()}`);
})().catch((e) => {
  console.error('FALHA:', e && e.stack ? e.stack : e);
  process.exit(1);
});
