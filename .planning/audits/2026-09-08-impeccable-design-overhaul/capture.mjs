import pw from '/home/bernt-popp/development/sysndd/app/node_modules/playwright/index.js';
const { chromium } = pw;
import { mkdirSync, writeFileSync } from 'node:fs';

const BASE = 'https://sysndd.dbmr.unibe.ch';
const OUT = '/home/bernt-popp/development/sysndd/.planning/audits/2026-09-08-impeccable-design-overhaul';
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
  ['phenotypecounts', '/PhenotypeCorrelations/PhenotypeCounts'],
  ['phenotypeclusters', '/PhenotypeCorrelations/PhenotypeClusters'],
  ['nddscore', '/NDDScore'],
];

const results = [];
const browser = await chromium.launch({ args: ['--no-sandbox'] });

async function capture(name, path, width, height, suffix) {
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
  await ctx.addInitScript(() => {
    try {
      localStorage.setItem('banner_acknowledged', 'true');
      localStorage.setItem('disclaimer_accepted', 'true');
    } catch {}
  });
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
    try { await page.waitForLoadState('networkidle', { timeout: 15000 }); } catch {}
    await page.waitForTimeout(2000);
  } catch (e) {
    pageErrors.push(`NAV_FAIL: ${String(e).slice(0, 200)}`);
  }
  const loadMs = Date.now() - t0;
  const file = `${SHOTS}/${name}${suffix}.png`;
  try {
    await page.screenshot({ path: file, fullPage: true });
  } catch (e) {
    pageErrors.push(`SHOT_FAIL: ${String(e).slice(0, 120)}`);
  }

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
  return { name, path, url: `${BASE}${path}`, viewport: `${width}x${height}${suffix}`, status, loadMs, consoleErrors, consoleWarnings: consoleWarnings.slice(0, 10), pageErrors, failedRequests, metrics, screenshot: file };
}

for (const [name, path] of PAGES) {
  process.stdout.write(`>>> [desktop] ${name} ${path}\n`);
  const desktop = await capture(name, path, 1440, 900, '');
  results.push(desktop);
  process.stdout.write(`>>> [mobile] ${name} ${path}\n`);
  const mobile = await capture(name, path, 390, 844, '-mobile');
  results.push(mobile);
}

await browser.close();
writeFileSync(`${OUT}/capture.json`, JSON.stringify(results, null, 2));
process.stdout.write(`=== CAPTURE COMPLETE (${results.length} captures) ===\n`);
