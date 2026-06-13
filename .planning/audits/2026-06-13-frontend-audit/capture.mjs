// Headless visual + console capture for SysNDD public pages.
// Run from app/ so the `playwright` module resolves. Output -> ../.planning/audits/.../screenshots + capture.json
import pw from '/home/bernt-popp/development/sysndd/app/node_modules/playwright/index.js';
const { chromium } = pw;
import { mkdirSync, writeFileSync } from 'node:fs';

const BASE = 'http://localhost:5173';
const OUT = '/home/bernt-popp/development/sysndd/.planning/audits/2026-06-13-frontend-audit';
const SHOTS = `${OUT}/screenshots`;
mkdirSync(SHOTS, { recursive: true });

const PAGES = [
  ['home', '/'],
  ['entities', '/Entities?sort=%2Bentity_id&page_size=10'],
  ['genes', '/Genes?sort=%2Bsymbol&page_after=0&page_size=10'],
  ['phenotypes', '/Phenotypes?sort=entity_id&filter=all(modifier_phenotype_id,HP:0001249)&page_size=10'],
  ['panels', '/Panels/All/All'],
  ['curationcomparisons', '/CurationComparisons'],
  ['curationcomparisons-similarity', '/CurationComparisons/Similarity'],
  ['curationcomparisons-table', '/CurationComparisons/Table'],
  ['phenotypecorrelations', '/PhenotypeCorrelations'],
  ['phenotypefunctionalcorrelation', '/PhenotypeFunctionalCorrelation'],
  ['variantcorrelations', '/VariantCorrelations'],
  ['entriesovertime', '/EntriesOverTime'],
  ['publicationsndd', '/PublicationsNDD'],
  ['pubtatorndd', '/PubtatorNDD'],
  ['genenetworks', '/GeneNetworks'],
  ['nddscore', '/NDDScore?sort=%2Brank&page_size=10'],
  ['nddscore-modelcard', '/NDDScore/ModelCard'],
  ['about', '/About'],
  ['documentation', '/Documentation'],
  ['mcp', '/mcp'],
  ['api', '/API'],
  ['login', '/Login'],
  ['register', '/Register'],
  ['gene-detail', '/Genes/ARID1B'],
  ['entity-detail', '/Entities/1'],
];

// table/data-heavy pages we also capture at mobile width
const MOBILE = new Set(['home', 'entities', 'genes', 'phenotypes', 'panels', 'nddscore', 'gene-detail', 'curationcomparisons']);

const results = [];

const browser = await chromium.launch({ args: ['--no-sandbox'] });

async function capture(name, path, width, height, suffix) {
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  // Pre-acknowledge the first-visit usage/privacy banner so it doesn't overlay every capture.
  await ctx.addInitScript(() => { try { localStorage.setItem('banner_acknowledged', 'true'); } catch {} });
  const page = await ctx.newPage();
  const consoleErrors = [];
  const consoleWarnings = [];
  const pageErrors = [];
  const failedRequests = [];
  page.on('console', (m) => {
    if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 300));
    else if (m.type() === 'warning') consoleWarnings.push(m.text().slice(0, 200));
  });
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 300)));
  page.on('requestfailed', (r) => failedRequests.push(`${r.method()} ${r.url().slice(0, 120)} :: ${r.failure()?.errorText}`));
  const t0 = Date.now();
  let status = null;
  try {
    const resp = await page.goto(`${BASE}${path}`, { waitUntil: 'domcontentloaded', timeout: 45000 });
    status = resp?.status() ?? null;
    // give SPA + async data/charts time to settle
    try { await page.waitForLoadState('networkidle', { timeout: 12000 }); } catch {}
    await page.waitForTimeout(1500);
  } catch (e) {
    pageErrors.push(`NAV_FAIL: ${String(e).slice(0, 200)}`);
  }
  const loadMs = Date.now() - t0;
  const file = `${SHOTS}/${name}${suffix}.png`;
  try { await page.screenshot({ path: file, fullPage: true }); } catch (e) { pageErrors.push(`SHOT_FAIL: ${String(e).slice(0,120)}`); }
  // lightweight DOM metrics for the design rating
  let metrics = {};
  try {
    metrics = await page.evaluate(() => {
      const docH = document.documentElement.scrollHeight;
      const imgsNoAlt = [...document.images].filter((i) => !i.alt && !i.getAttribute('aria-hidden')).length;
      const buttonsNoLabel = [...document.querySelectorAll('button')].filter((b) => !b.textContent.trim() && !b.getAttribute('aria-label') && !b.title).length;
      const h1 = document.querySelectorAll('h1').length;
      const tables = document.querySelectorAll('table').length;
      const title = document.title;
      const metaDesc = document.querySelector('meta[name=description]')?.content || null;
      return { docH, imgsNoAlt, buttonsNoLabel, h1Count: h1, tables, title, metaDesc };
    });
  } catch {}
  await ctx.close();
  return { name, path, viewport: `${width}x${height}${suffix}`, status, loadMs, consoleErrors, consoleWarnings: consoleWarnings.slice(0, 10), pageErrors, failedRequests, metrics, screenshot: file };
}

for (const [name, path] of PAGES) {
  process.stdout.write(`>>> ${name} ${path}\n`);
  const desktop = await capture(name, path, 1440, 900, '');
  results.push(desktop);
  if (MOBILE.has(name)) {
    const mobile = await capture(name, path, 390, 844, '-mobile');
    results.push(mobile);
  }
}

await browser.close();
writeFileSync(`${OUT}/capture.json`, JSON.stringify(results, null, 2));

// concise console summary
console.log('\n=== CAPTURE SUMMARY ===');
for (const r of results) {
  if (r.viewport.includes('mobile')) continue;
  console.log(
    `${r.name.padEnd(34)} status=${r.status} load=${r.loadMs}ms ` +
    `err=${r.consoleErrors.length} pageErr=${r.pageErrors.length} reqFail=${r.failedRequests.length} ` +
    `h1=${r.metrics.h1Count ?? '?'} imgNoAlt=${r.metrics.imgsNoAlt ?? '?'} btnNoLabel=${r.metrics.buttonsNoLabel ?? '?'}`
  );
}
console.log('=== DONE ===');
