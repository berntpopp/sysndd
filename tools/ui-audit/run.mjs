#!/usr/bin/env node
// SysNDD UI-quality audit runner. See README.md and docs/ui-quality/protocol.md.
//   node tools/ui-audit/run.mjs [--base URL] [--pages id,id] [--roles public,ADMIN]
//        [--viewports 1920x1080,1366x768,390x844] [--no-lighthouse | --lighthouse-only] [--no-detect]
//        [--cdp-port 9333] [--out DIR]
// Shards may run in parallel with distinct --cdp-port and --out; run Lighthouse serially
// (--lighthouse-only) so CPU contention does not distort its scores.
import { createRequire } from 'node:module';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PAGES } from './pages.mjs';

const exec = promisify(execFile);
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '../..');
const require = createRequire(path.join(ROOT, 'app/package.json')); // Playwright + axe from app/node_modules
const { chromium } = require('@playwright/test');
const { default: AxeBuilder } = require('@axe-core/playwright');

const arg = (name, dflt) => {
  const i = process.argv.indexOf(`--${name}`);
  return i < 0 ? dflt : process.argv[i + 1];
};
const flag = (name) => process.argv.includes(`--${name}`);
const BASE = arg('base', 'http://localhost:8091').replace(/\/$/, '');
const VIEWPORTS = arg('viewports', '1920x1080,1366x768,390x844').split(',').map((v) => {
  const [width, height] = v.split('x').map(Number);
  return { name: v, width, height };
});
const OUT = path.resolve(arg('out', path.join(HERE, 'out', new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19))));
const ENV_FILE = arg('env', path.join(ROOT, 'stack/.env'));
const DETECT = arg('impeccable', `${process.env.HOME}/.claude/skills/impeccable/scripts/impeccable`);
const LIGHTHOUSE = arg('lighthouse-version', '12.8.2');
const CDP_PORT = Number(arg('cdp-port', '9333'));
const SETTLE_MS = 1500;
const DEFAULT_READY = 'main h1, main h2, main table tbody tr, .mobile-record-row, main .card-body, h1, .card-body';
const LOADERS = '.spinner-border, .spinner-grow, .b-skeleton, .placeholder-glow, [aria-busy="true"]';

const only = arg('pages') ? new Set(arg('pages').split(',')) : null;
const roles = arg('roles') ? new Set(arg('roles').split(',')) : null;
const pages = PAGES.filter((p) => (!only || only.has(p.id)) && (!roles || roles.has(p.role)));
if (!pages.length) throw new Error('no pages selected');

// Credentials: read from the stack .env, never printed or written to results.
const env = Object.fromEntries(fs.readFileSync(ENV_FILE, 'utf8').split('\n')
  .filter((l) => /^[A-Z_]+=/.test(l)).map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]));

async function session(role) {
  if (role === 'public') return null;
  const body = JSON.stringify({ user_name: env[`DEMO_${role}_USER`], password: env[`DEMO_${role}_PASSWORD`] });
  const auth = await fetch(`${BASE}/api/auth/authenticate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body });
  if (!auth.ok) throw new Error(`sign-in failed for ${role}: HTTP ${auth.status}`);
  const t = await auth.json();
  const token = Array.isArray(t) ? t[0] : t;
  const user = await (await fetch(`${BASE}/api/auth/signin`, { headers: { Authorization: `Bearer ${token}` } })).text();
  return { token, user };
}

const probes = fs.readFileSync(path.join(HERE, 'probes.js'), 'utf8');

async function timeToUsable(page, ready) {
  // ms from navigation start until the ready selector is visible and no loader is visible.
  return page.waitForFunction(([r, l]) => {
    const vis = (el) => { const b = el.getBoundingClientRect(); return b.width > 0 && b.height > 0 && getComputedStyle(el).visibility !== 'hidden'; };
    const ok = [...document.querySelectorAll(r)].some(vis) && ![...document.querySelectorAll(l)].some(vis);
    return ok ? performance.now() : false;
  }, [ready, LOADERS], { timeout: 30000, polling: 'raf' }).then((h) => h.jsonValue()).catch(() => null);
}

const snapshot = (page) => page.evaluate(() => ({
  shifts: window.__ua.shifts.length, longtasks: window.__ua.longtasks.length,
  events: window.__ua.events.length, flicker: window.__ua.flicker.length,
}));

function window_(ua, from) {
  const shifts = ua.shifts.slice(from.shifts);
  const lt = ua.longtasks.slice(from.longtasks);
  return {
    cls: +shifts.filter((s) => !s.recentInput).reduce((a, s) => a + s.value, 0).toFixed(4),
    shiftAll: +shifts.reduce((a, s) => a + s.value, 0).toFixed(4), // includes shifts right after input
    shiftSources: [...new Set(shifts.filter((s) => s.value > 0.001).flatMap((s) => s.sources))].slice(0, 8),
    longTasks: lt.length, longTaskMs: Math.round(lt.reduce((a, t) => a + t.d, 0)),
    maxEventMs: Math.max(0, ...ua.events.slice(from.events).map((e) => e.d)),
    flicker: ua.flicker.slice(from.flicker).filter((f) => !f.loader),
    loaderFlashes: ua.flicker.slice(from.flicker).filter((f) => f.loader && f.lifetime < 300).length,
  };
}

const firstVisible = async (page, selector) => {
  for (const h of await page.$$(selector)) if (await h.isVisible() && await h.isEnabled()) return h;
  return null;
};
const INTERACTIONS = {
  filter: async (page) => {
    const h = await firstVisible(page, 'input[aria-label^="Filter"], input[placeholder="Search any field..."], input[type="search"]');
    if (!h) return false;
    await h.click(); await h.type('FBX', { delay: 60 }); return true;
  },
  paginate: async (page) => {
    const h = await firstVisible(page, '[aria-label="Go to next page"]:not([aria-disabled="true"])');
    if (!h) return false;
    await h.click(); return true;
  },
  tab: async (page) => {
    const h = await firstVisible(page, '[role="tab"][aria-selected="false"]');
    if (!h) return false;
    await h.click(); return true;
  },
  modal: async (page, p) => {
    const h = p.modal && await firstVisible(page, p.modal);
    if (!h) return false;
    await h.click();
    await page.waitForSelector('.modal.show, [role="dialog"]', { timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(SETTLE_MS);
    await page.keyboard.press('Escape'); return true;
  },
};

async function auditPage(ctx, p, sess) {
  const res = { id: p.id, role: p.role, url: BASE + p.path, viewports: {} };
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e.message).slice(0, 200)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text().slice(0, 200)); });
  const failed = [];
  page.on('response', (r) => { if (r.status() >= 400 && r.url().startsWith(BASE)) failed.push(`${r.status()} ${r.url().replace(BASE, '')}`.slice(0, 160)); });
  page.setDefaultTimeout(5000);
  await page.addInitScript(probes);
  // The usage-policy dialog shows once per browser; audit it only on pages marked firstVisit.
  await page.addInitScript((first) => {
    if (first) localStorage.removeItem('sysndd-disclaimer');
    else localStorage.setItem('sysndd-disclaimer', JSON.stringify({ isAcknowledged: true, acknowledgmentTimestamp: '2026-01-01T00:00:00Z' }));
  }, !!p.firstVisit);
  if (sess) await page.addInitScript(([t, u]) => { localStorage.setItem('token', t); localStorage.setItem('user', u); }, [sess.token, sess.user]);

  for (const vp of VIEWPORTS) {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    const t0 = Date.now();
    const nav = await page.goto(res.url, { waitUntil: 'domcontentloaded', timeout: 60000 }).catch((e) => ({ status: () => String(e.message).slice(0, 80) }));
    const usableMs = await timeToUsable(page, p.ready || (p.firstVisit ? '.modal.show' : DEFAULT_READY));
    const stuckLoaders = usableMs == null ? await page.evaluate((l) => [...document.querySelectorAll(l)].filter((e) => e.getBoundingClientRect().width > 0).map((e) => window.__ua.sel(e)).slice(0, 5), LOADERS) : [];
    await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => {});
    await page.waitForTimeout(SETTLE_MS);
    const ua0 = await page.evaluate(() => window.__ua);
    const v = {
      stuckLoaders, status: nav?.status?.(), finalUrl: page.url().replace(BASE, ''), usableMs: usableMs && Math.round(usableMs),
      wallMs: Date.now() - t0, lcpMs: Math.round(ua0.lcp), load: window_(ua0, { shifts: 0, longtasks: 0, events: 0, flicker: 0 }),
      overflow: await page.evaluate(() => window.__ua.overflow()), interactions: {},
    };
    if (vp.name === '1366x768') {
      for (const [name, fn] of Object.entries(INTERACTIONS)) {
        const from = await snapshot(page);
        const ran = await fn(page, p).catch((e) => `error: ${String(e.message).slice(0, 80)}`);
        if (ran !== true) { v.interactions[name] = { skipped: ran || 'not present' }; continue; }
        await page.waitForLoadState('networkidle', { timeout: 4000 }).catch(() => {});
        await page.waitForTimeout(SETTLE_MS);
        v.interactions[name] = window_(await page.evaluate(() => window.__ua), from);
      }
      // axe on the freshly loaded page (interactions may have left filters/tabs changed)
      await page.goto(res.url, { waitUntil: 'networkidle', timeout: 60000 }).catch(() => {});
      await timeToUsable(page, p.ready || DEFAULT_READY);
      await page.waitForTimeout(SETTLE_MS);
      const axe = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice']).analyze();
      res.axe = axe.violations.map((x) => ({ id: x.id, impact: x.impact, nodes: x.nodes.length, help: x.help, targets: x.nodes.slice(0, 3).map((n) => n.target.join(' ')) }));
      if (!flag('no-detect')) res.impeccable = await detect(page);
    }
    const dir = path.join(OUT, p.id);
    fs.mkdirSync(dir, { recursive: true });
    await page.screenshot({ path: path.join(dir, `${vp.name}.png`), fullPage: true }).catch(() => {});
    res.viewports[vp.name] = v;
  }
  res.errors = [...new Set(errors)].slice(0, 20);
  res.failedRequests = [...new Set(failed)].slice(0, 20);
  await page.close();
  return res;
}

async function detect(page) {
  // impeccable detect scans the live tab over CDP, so authenticated state is kept.
  try {
    const { stdout } = await exec(DETECT, ['detect', '--cdp', String(CDP_PORT), '--target', page.url(), '--json'], { cwd: path.join(ROOT, 'app'), maxBuffer: 1 << 26 }).catch((e) => e);
    const json = JSON.parse(stdout);
    const list = Array.isArray(json) ? json : json.findings || json.results?.flatMap((r) => r.findings || []) || [];
    return list.map((f) => ({ rule: f.antipattern || f.rule, severity: f.severity, advisory: f.severity === 'advisory', name: f.name, snippet: (f.snippet || '').slice(0, 120), selector: (f.selector || '').slice(0, 160) }));
  } catch (e) {
    return [{ rule: 'detect-error', message: String(e.message).slice(0, 160) }];
  }
}

async function lighthouse(p, preset) {
  const file = path.join(OUT, 'lighthouse', `${p.id}-${preset}.json`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const args = ['-y', `lighthouse@${LIGHTHOUSE}`, BASE + p.path, `--port=${CDP_PORT}`, '--disable-storage-reset',
    '--only-categories=performance,accessibility,best-practices,seo', '--output=json', `--output-path=${file}`, '--quiet'];
  if (preset === 'desktop') args.push('--preset=desktop');
  try {
    await exec('npx', args, { env: { ...process.env, CHROME_PATH: chromium.executablePath() }, maxBuffer: 1 << 26, timeout: 180000 });
    const r = JSON.parse(fs.readFileSync(file, 'utf8'));
    const score = (k) => (r.categories[k]?.score == null ? null : Math.round(r.categories[k].score * 100));
    const num = (k) => r.audits[k]?.numericValue;
    return {
      perf: score('performance'), a11y: score('accessibility'), bp: score('best-practices'), seo: score('seo'),
      lcpMs: Math.round(num('largest-contentful-paint') || 0), cls: +(num('cumulative-layout-shift') || 0).toFixed(4),
      tbtMs: Math.round(num('total-blocking-time') || 0), report: path.relative(OUT, file),
    };
  } catch (e) {
    return { error: String(e.stderr || e.message).split('\n').filter(Boolean).pop()?.slice(0, 200) };
  }
}

fs.mkdirSync(OUT, { recursive: true });
const results = [];
for (const role of [...new Set(pages.map((p) => p.role))]) {
  // A persistent context is the browser's default context, so the Lighthouse and
  // impeccable tabs opened over CDP share this role's localStorage.
  const profile = fs.mkdtempSync(path.join(OUT, `.profile-${role}-`));
  const ctx = await chromium.launchPersistentContext(profile, { headless: true, args: [`--remote-debugging-port=${CDP_PORT}`] });
  let sess = await session(role);
  let signedAt = Date.now();
  {
    // Seed this profile's storage for the Lighthouse tabs, which get no init scripts.
    const pg = await ctx.newPage();
    await pg.goto(BASE + '/', { waitUntil: 'domcontentloaded' });
    await pg.evaluate((s) => {
      localStorage.setItem('sysndd-disclaimer', JSON.stringify({ isAcknowledged: true, acknowledgmentTimestamp: '2026-01-01T00:00:00Z' }));
      if (s) { localStorage.setItem('token', s.token); localStorage.setItem('user', s.user); }
    }, sess);
    await pg.close();
  }
  for (const p of pages.filter((x) => x.role === role)) {
    if (sess && Date.now() - signedAt > 40 * 60000) { sess = await session(role); signedAt = Date.now(); } // tokens last 60 min
    process.stderr.write(`[ui-audit] ${role} ${p.path}\n`);
    const r = flag('lighthouse-only') ? { id: p.id, role: p.role, url: BASE + p.path, viewports: {} } : await auditPage(ctx, p, sess);
    if (!flag('no-lighthouse')) r.lighthouse = { desktop: await lighthouse(p, 'desktop'), mobile: await lighthouse(p, 'mobile') };
    results.push(r);
    fs.writeFileSync(path.join(OUT, 'results.json'), JSON.stringify({ base: BASE, viewports: VIEWPORTS.map((v) => v.name), generated: new Date().toISOString(), results }, null, 2));
  }
  await ctx.close();
  fs.rmSync(profile, { recursive: true, force: true });
}
process.stdout.write(`${path.join(OUT, 'results.json')}\n`);
