# ui-audit

Measures every SysNDD page per docs/ui-quality/protocol.md: load and interaction
layout shift, long tasks, event latency, flicker, time to usable, overflow and
cut-off at 1920x1080 / 1366x768 / 390x844, axe-core, impeccable detect, and
Lighthouse 12 desktop + mobile. Uses Playwright and axe from `app/node_modules`
(`cd app && npm ci` first) and needs the audit stack on http://localhost:8091.

    node tools/ui-audit/run.mjs --pages entities,gene-fbxo11 --out tools/ui-audit/out/run1
    node tools/ui-audit/summarize.mjs tools/ui-audit/out/run1/results.json > tools/ui-audit/out/run1/summary.md

Options: `--roles public,REVIEWER,CURATOR,ADMIN`, `--pages <ids from pages.mjs>`,
`--viewports 1366x768,390x844`, `--no-lighthouse`, `--lighthouse-only`, `--no-detect`,
`--cdp-port 9333`, `--base URL`, `--env stack/.env`.

Full audit in parallel: run browser-metric shards with `--no-lighthouse`, each with its
own `--cdp-port` and `--out`; run Lighthouse once, serially, with `--lighthouse-only`;
pass all results.json files to summarize.mjs (it merges per page id).
Cost: ~2 min per page for the browser metrics, ~1-2 min per page for Lighthouse.

Output (git-ignored): `out/<run>/results.json`, `out/<run>/<page>/<viewport>.png`,
`out/<run>/lighthouse/<page>-<preset>.json`. Human ratings: `out/<run>/ratings.json`.
