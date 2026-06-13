// Extract actionable Lighthouse findings (failing a11y/best-practice audits + key perf metrics) per page.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
const DIR = '/home/bernt-popp/development/sysndd/.planning/audits/2026-06-13-frontend-audit/lighthouse';
const files = readdirSync(DIR).filter((f) => f.endsWith('.json'));
const out = [];
for (const f of files) {
  let r;
  try { r = JSON.parse(readFileSync(`${DIR}/${f}`, 'utf8')); } catch { continue; }
  const cats = r.categories || {};
  const audits = r.audits || {};
  const score = (k) => (cats[k] && cats[k].score != null ? Math.round(cats[k].score * 100) : null);
  // failing audits in a11y + best-practices (score < 0.9 and scoreDisplayMode binary/numeric)
  const failing = [];
  for (const ref of [...(cats.accessibility?.auditRefs || []), ...(cats['best-practices']?.auditRefs || [])]) {
    const a = audits[ref.id];
    if (!a) continue;
    if (a.score != null && a.score < 0.9 && a.scoreDisplayMode !== 'notApplicable' && a.scoreDisplayMode !== 'informative') {
      const items = a.details?.items?.length || 0;
      failing.push(`${a.id}(${items})`);
    }
  }
  out.push({
    page: f.replace('.json', ''),
    perf: score('performance'), a11y: score('accessibility'), bp: score('best-practices'), seo: score('seo'),
    lcp_ms: Math.round(audits['largest-contentful-paint']?.numericValue || 0),
    tbt_ms: Math.round(audits['total-blocking-time']?.numericValue || 0),
    cls: +(audits['cumulative-layout-shift']?.numericValue || 0).toFixed(3),
    fcp_ms: Math.round(audits['first-contentful-paint']?.numericValue || 0),
    failing_audits: failing,
  });
}
out.sort((a, b) => (a.a11y ?? 100) - (b.a11y ?? 100));
writeFileSync(`${DIR}/findings.json`, JSON.stringify(out, null, 2));
console.log('PAGE'.padEnd(34), 'PERF A11Y  BP SEO   LCP   TBT  CLS  | failing a11y/bp audits');
for (const o of out) {
  console.log(
    o.page.padEnd(34),
    String(o.perf).padStart(4), String(o.a11y).padStart(4), String(o.bp).padStart(3), String(o.seo).padStart(3),
    String(o.lcp_ms).padStart(6), String(o.tbt_ms).padStart(5), String(o.cls).padStart(5),
    '|', o.failing_audits.join(', ') || '(none)'
  );
}
