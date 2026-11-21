#!/usr/bin/env node
// Turn a run's results.json into a Markdown report with pass/fail per threshold.
//   node tools/ui-audit/summarize.mjs out/<run>/results.json [> summary.md]
// Optional human ratings: out/<run>/ratings.json = { "<page id>": { "hierarchy": 4, ... } }
import fs from 'node:fs';
import path from 'node:path';

// Pass thresholds, kept in sync with docs/ui-quality/protocol.md section 4.
export const T = {
  lhPerfDesktop: 90, lhPerfMobile: 70, lhA11y: 95, lhBp: 95, lhSeoPublic: 90,
  cls: 0.05, interactionShift: 0.05, usableMs: 2500, maxEventMs: 200, longTaskMs: 300,
};

const files = process.argv.slice(2);
if (!files.length) { console.error('usage: summarize.mjs <results.json> [more results.json ...]'); process.exit(2); }
const file = files[0];
// Several runs (shards, or a --lighthouse-only pass) merge per page id.
const byId = new Map();
let base, generated;
for (const f of files) {
  const run = JSON.parse(fs.readFileSync(f, 'utf8'));
  ({ base, generated } = run);
  for (const r of run.results) {
    const prev = byId.get(r.id) || {};
    byId.set(r.id, { ...prev, ...r, viewports: { ...prev.viewports, ...r.viewports }, lighthouse: r.lighthouse || prev.lighthouse, axe: r.axe || prev.axe, impeccable: r.impeccable || prev.impeccable, errors: r.errors || prev.errors, failedRequests: r.failedRequests || prev.failedRequests });
  }
}
const results = [...byId.values()];
const ratingsFile = path.join(path.dirname(file), 'ratings.json');
const ratings = fs.existsSync(ratingsFile) ? JSON.parse(fs.readFileSync(ratingsFile, 'utf8')) : {};

const fmt = (v) => (v == null || Number.isNaN(v) ? '–' : v);
function check(r) {
  const fails = [];
  const d = r.lighthouse?.desktop || {}, m = r.lighthouse?.mobile || {};
  const vp = r.viewports['1366x768'] || Object.values(r.viewports)[0];
  if (d.perf != null && d.perf < T.lhPerfDesktop) fails.push(`LH perf desktop ${d.perf}`);
  if (m.perf != null && m.perf < T.lhPerfMobile) fails.push(`LH perf mobile ${m.perf}`);
  for (const [k, s] of [['desktop', d], ['mobile', m]]) {
    if (s.a11y != null && s.a11y < T.lhA11y) fails.push(`LH a11y ${k} ${s.a11y}`);
    if (s.bp != null && s.bp < T.lhBp) fails.push(`LH best-practices ${k} ${s.bp}`);
    if (r.role === 'public' && s.seo != null && s.seo < T.lhSeoPublic) fails.push(`LH SEO ${k} ${s.seo}`);
    if (s.error) fails.push(`LH ${k} error`);
  }
  const serious = (r.axe || []).filter((a) => a.impact === 'serious' || a.impact === 'critical');
  if (serious.length) fails.push(`axe serious/critical: ${serious.map((a) => a.id).join(', ')}`);
  for (const [name, v] of Object.entries(r.viewports)) {
    if (v.load.cls >= T.cls) fails.push(`CLS ${v.load.cls} @${name}`);
    if (v.load.flicker.length) fails.push(`flicker ${v.load.flicker.length} @${name}`);
    if (v.usableMs == null) fails.push(`never usable @${name}`);
    else if (v.usableMs > T.usableMs) fails.push(`usable ${v.usableMs} ms @${name}`);
    if (name !== '1920x1080') {
      const o = v.overflow;
      const n = (o.pageOverflowX > 0 ? 1 : 0) + o.pastViewport.length + o.clipped.length + o.obscured.length;
      if (n) fails.push(`overflow/cut-off ${n} @${name}`);
    }
  }
  for (const [name, i] of Object.entries(vp?.interactions || {})) {
    if (i.skipped) continue;
    if (i.shiftAll >= T.interactionShift) fails.push(`${name}: shift ${i.shiftAll}`);
    if (i.maxEventMs > T.maxEventMs) fails.push(`${name}: event ${i.maxEventMs} ms`);
    if (i.longTaskMs > T.longTaskMs) fails.push(`${name}: long tasks ${i.longTaskMs} ms`);
    if (i.flicker.length) fails.push(`${name}: flicker ${i.flicker.length}`);
  }
  if (r.errors?.length) fails.push(`console errors ${r.errors.length}`);
  return fails;
}

const rows = results.map((r) => {
  const d = r.lighthouse?.desktop || {}, m = r.lighthouse?.mobile || {};
  const vp = r.viewports['1366x768'] || Object.values(r.viewports)[0] || { load: { cls: '–', longTasks: '–', longTaskMs: '–' }, interactions: {} };
  const ov = (name) => { const o = r.viewports[name]?.overflow; return o ? (o.pageOverflowX > 0 ? 1 : 0) + o.pastViewport.length + o.clipped.length + o.obscured.length : '–'; };
  const inter = Object.values(vp.interactions || {}).filter((i) => !i.skipped);
  const axe = (r.axe || []).reduce((a, x) => ({ ...a, [x.impact]: (a[x.impact] || 0) + 1 }), {});
  const fails = check(r);
  return { r, fails, cells: [
    `\`${r.id}\``, r.role,
    `${fmt(d.perf)}/${fmt(d.a11y)}/${fmt(d.bp)}/${fmt(d.seo)}`, `${fmt(m.perf)}/${fmt(m.a11y)}/${fmt(m.bp)}/${fmt(m.seo)}`,
    `${fmt(m.lcpMs)} / ${fmt(m.cls)} / ${fmt(m.tbtMs)}`,
    fmt(vp.usableMs), vp.load.cls, Math.max(0, ...inter.map((i) => i.shiftAll)), `${vp.load.longTasks} / ${vp.load.longTaskMs}`,
    Math.max(0, ...inter.map((i) => i.maxEventMs)),
    Object.values(r.viewports).reduce((a, v) => a + v.load.flicker.length, 0) + inter.reduce((a, i) => a + i.flicker.length, 0),
    `${ov('1366x768')} / ${ov('390x844')}`,
    `${(axe.critical || 0) + (axe.serious || 0)} / ${(axe.moderate || 0) + (axe.minor || 0)}`,
    (r.impeccable || []).filter((f) => !f.advisory).length,
    fails.length ? `FAIL (${fails.length})` : 'PASS',
  ] };
});

const out = [];
out.push(`# UI quality audit\n\nBase: ${base} · generated ${generated} · ${results.length} pages · ${rows.filter((x) => !x.fails.length).length} pass\n`);
out.push('| page | role | LH desktop P/A/BP/SEO | LH mobile P/A/BP/SEO | mobile LCP ms / CLS / TBT ms | usable ms | load CLS | max interaction shift | long tasks n / ms | max event ms | flicker | overflow 1366 / 390 | axe serious+crit / other | impeccable | result |');
out.push(`|${'---|'.repeat(15)}`);
for (const x of rows) out.push(`| ${x.cells.join(' | ')} |`);
out.push('\n## Failures and evidence\n');
for (const { r, fails } of rows) {
  if (!fails.length && !r.errors?.length && !r.failedRequests?.length) continue;
  out.push(`### ${r.id} (${r.role}) — ${r.url}\n`);
  for (const f of fails) out.push(`- ${f}`);
  for (const [name, v] of Object.entries(r.viewports)) {
    const o = v.overflow;
    for (const e of [...o.pastViewport, ...o.clipped, ...o.obscured].slice(0, 6)) out.push(`  - @${name} ${e.el}${e.by ? ` under ${e.by}` : ''} "${e.text || ''}"`);
    for (const f of v.load.flicker.slice(0, 4)) out.push(`  - flicker @${name}: ${f.el} shown ${f.lifetime} ms "${f.text}"`);
    if (v.load.shiftSources.length) out.push(`  - shift sources @${name}: ${v.load.shiftSources.join(', ')}`);
  }
  for (const a of (r.axe || []).filter((a) => ['serious', 'critical'].includes(a.impact))) out.push(`  - axe ${a.id} (${a.impact}, ${a.nodes}): ${a.help} — ${a.targets.join(' | ')}`);
  for (const e of r.errors || []) out.push(`  - console: ${e}`);
  for (const e of r.failedRequests || []) out.push(`  - request: ${e}`);
  for (const f of (r.impeccable || []).filter((f) => !f.advisory).slice(0, 8)) out.push(`  - impeccable ${f.rule}: ${f.snippet || f.name || f.message} — \`${f.selector || ""}\``);
  out.push('');
}
if (Object.keys(ratings).length) {
  const aspects = ['hierarchy', 'clarity', 'consistency', 'responsiveness', 'feedback', 'snappiness', 'accessibility'];
  out.push('## Ratings (1-5)\n');
  out.push(`| page | ${aspects.join(' | ')} | note |`);
  out.push(`|${'---|'.repeat(aspects.length + 2)}`);
  for (const [id, rt] of Object.entries(ratings)) out.push(`| \`${id}\` | ${aspects.map((a) => fmt(rt[a])).join(' | ')} | ${rt.note || ''} |`);
}
process.stdout.write(out.join('\n') + '\n');
