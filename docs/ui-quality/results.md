# UI quality results (merged branch `ui/quality-2026-11`)

All six fix branches merged into `ui/quality-2026-11`, plus the integration and
review fixes listed below. Measured with the protocol in `protocol.md` on the
`sysndd_uiaudit` stack (http://localhost:8091), rebuilt from the merged branch.

- **Before:** the original audit runs (`out/public-s0..s5`, `out/curation-a..c`,
  `out/admin-a..b`; Lighthouse `out/public-lh*`, `out/curation-lh*`, `out/admin-lh`),
  built from `dcbf1fe3`.
- **After:** `out/final-s0..s9` (10 parallel shards, all 65 pages, 3 viewports),
  Lighthouse `out/final-lh0..2` (3 shards, desktop + mobile presets), and
  `out/final-retime` (18 pages re-run one at a time, see "Timing" below). Summaries:
  `out/final-summary.md`, `out/final-retime-summary.md`. After-ratings:
  `out/final-s0/ratings.json`.

## Headline

| Check | Before | After |
|---|---|---|
| Pages passing every threshold (metrics + Lighthouse) | 6 of 41 public pages, few elsewhere | 29 of 65 in the parallel run; every remaining failure is a "usable > 2.5 s" timing taken under 10-shard load, and all 18 such pages pass when re-run alone |
| axe serious/critical violations | 163 elements on 26 pages | 0 on all 65 pages |
| Lighthouse accessibility, worst page | 90 (manage-about mobile) | 96 (view-logs mobile); 62 of 65 pages score 100 on both presets |
| Lighthouse performance, worst page desktop / mobile | 63 / 37 (gene networks) | 98 / 86 (gene-arid1b / entities) |
| Worst load layout shift (any viewport) | 0.501 (Manage Ontology Mappings) | 0.049 (analysis) |
| Longest load long-task total @1366 | 8,023 ms (gene networks) | 203 ms |
| Pages with overflow / cut-off flagged @1366 or @390 | 19 | 4, all tool false positives (see "Tool caveats") |
| Console errors | 0 | 0 |
| Lowest rating on any aspect | 1 | 3 (four pages, listed under open items) |

## Per page

Columns: Lighthouse performance/accessibility (desktop and mobile presets); worst
load CLS across 1920/1366/390; long tasks during load at 1366 (count/total ms); time
until the page is usable at 1366 (re-timed value where re-run alone); real overflow
and cut-off at 1366/390 (page overflow, content past the viewport, clipped text
without a title, interactive elements covered by something other than the fixed
navbar/footer); axe serious + critical; rating min/average over the seven aspects
(hierarchy, clarity, consistency, responsiveness, feedback, snappiness,
accessibility; 1-5).

| page | role | LH desktop P/A | LH mobile P/A | worst load CLS | long tasks @1366 n/ms | usable ms @1366 | overflow 1366/390 | axe serious+crit | rating min/avg |
|---|---|---|---|---|---|---|---|---|---|
| `home` | public | 100/100 → 100/100 | 99/100 → 94/100 | 0 → 0 | 2/235 → 0/0 | 466 → 132 | 0/0 → 0/0 | 0 → 0 | 3/3.7 → 4/4.3 |
| `phenotype-clusters` | public | 96/100 → 100/100 | 73/100 → 97/100 | 0.234 → 0.025 | 1/115 → 1/51 | 3547 → 876 | 0/0 → 0/0 | 0 → 0 | 1/2.9 → 4/4.0 |
| `pubtator-genes` | public | 100/91 → 100/100 | 99/97 → 99/100 | 0.029 → 0.037 | 3/332 → 2/151 | 2626 → 1884 | 0/0 → 0/0 | 3 → 0 | 2/3.0 → 4/4.0 |
| `mcp` | public | 100/100 → 100/100 | 96/100 → 100/100 | 0.022 → 0 | 1/72 → 0/0 | 156 → 79 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.1 |
| `not-found` | public | 100/100 → 100/100 | 100/100 → 99/100 | 0 → 0 | 1/92 → 0/0 | 199 → 79 | 0/0 → 0/0 | 0 → 0 | 3/3.9 → 4/4.3 |
| `variation-suggestions` | CURATOR | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 1/151 → 1/65 | 313 → 241 | 0/0 → 0/0 | 0 → 0 | 3/3.9 → 4/4.0 |
| `manage-llm` | ADMIN | 100/97 → 100/100 | 98/100 → 98/100 | 0.081 → 0 | 3/259 → 1/97 | 1728 → 293 | 0/0 → 0/0 | 1 → 0 | 2/3.0 → 4/4.0 |
| `about` | public | 100/98 → 100/100 | 96/98 → 100/100 | 0 → 0 | 1/91 → 1/78 | 479 → 194 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.0 |
| `admin-statistics` | ADMIN | 100/95 → 100/100 | 95/94 → 100/100 | 0 → 0.019 | 1/149 → 1/87 | 1394 → 909 | 12/0 → 12/0 | 1 → 0 | 2/3.1 → 4/4.0 |
| `analysis` | public | 94/100 → 100/100 | 86/100 → 99/100 | 0.249 → 0.049 | 1/84 → 2/104 | 4390 → 1309 | 0/0 → 0/0 | 0 → 0 | 1/2.9 → 4/4.0 |
| `api` | public | 100/98 → 100/98 | 99/98 → 97/98 | 0.017 → 0.018 | 2/263 → 2/128 | 4301 → 775 | 0/0 → 0/0 | 0 → 0 | 2/3.3 → 4/4.0 |
| `approve-review` | CURATOR | 99/100 → 99/100 | 83/100 → 91/100 | 0.001 → 0.041 | 2/514 → 1/98 | 1838 → 515 | 2/0 → 0/0 | 1 → 0 | 2/3.1 → 4/4.1 |
| `approve-status` | CURATOR | 100/100 → 100/100 | 95/100 → 87/100 | 0.001 → 0.041 | 2/384 → 1/79 | 1016 → 378 | 4/0 → 0/0 | 1 → 0 | 3/3.3 → 4/4.1 |
| `approve-user` | CURATOR | 100/97 → 100/100 | 100/97 → 100/100 | 0 → 0 | 1/133 → 0/0 | 373 → 452 | 0/0 → 0/0 | 1 → 0 | 3/3.7 → 4/4.0 |
| `comparisons` | public | 100/100 → 100/100 | 100/100 → 94/100 | 0.141 → 0.017 | 2/186 → 1/66 | 1129 → 568 | 0/0 → 0/0 | 0 → 0 | 2/3.4 → 3/3.9 |
| `comparisons-similarity` | public | 100/100 → 100/100 | 97/100 → 94/100 | 0.063 → 0.031 | 1/79 → 1/57 | 1698 → 205 | 0/0 → 0/0 | 0 → 0 | 2/3.4 → 4/4.0 |
| `comparisons-table` | public | 96/100 → 100/100 | 96/97 → 96/97 | 0.077 → 0.042 | 2/197 → 0/0 | 2049 → 948 | 0/0 → 0/0 | 0 → 0 | 3/3.6 → 4/4.0 |
| `create-entity` | CURATOR | 100/100 → 100/100 | 100/100 → 98/100 | 0 → 0 | 1/96 → 0/0 | 258 → 93 | 2/2 → 2/2 | 0 → 0 | 3/3.7 → 4/4.0 |
| `data-releases` | public | 100/100 → 100/100 | 92/100 → 100/100 | 0.145 → 0 | 1/85 → 1/55 | 172 → 112 | 0/0 → 0/0 | 1 → 0 | 2/3.6 → 4/4.1 |
| `documentation` | public | 99/100 → 100/100 | 79/100 → 100/100 | 0 → 0 | 1/90 → 1/53 | 204 → 107 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.0 |
| `entities` | public | 98/100 → 100/100 | 86/100 → 86/100 | 0.001 → 0 | 2/464 → 2/191 | 1053 → 365 | 9/0 → 0/0 | 1 → 0 | 3/3.4 → 4/4.1 |
| `entity` | public | 88/97 → 100/100 | 64/96 → 100/100 | 0.175 → 0.003 | 1/112 → 0/0 | 213 → 103 | 0/1 → 0/0 | 2 → 0 | 3/3.3 → 4/4.0 |
| `entries-over-time` | public | 100/96 → 100/100 | 97/96 → 100/100 | 0.029 → 0 | 1/105 → 1/54 | 3306 → 331 | 0/0 → 0/0 | 1 → 0 | 2/3.4 → 4/4.0 |
| `gene-arid1b` | public | 99/100 → 98/100 | 94/96 → 96/100 | 0.093 → 0.028 | 5/393 → 0/0 | 15674 → 603 | 0/0 → 0/0 | 0 → 0 | 3/3.1 → 4/4.0 |
| `gene-fbxo11` | public | 98/100 → 100/100 | 97/96 → 93/100 | 0.083 → 0.021 | 2/139 → 0/0 | 573 → 229 | 1/0 → 0/0 | 0 → 0 | 3/3.1 → 4/4.0 |
| `gene-networks` | public | 63/100 → 100/100 | 37/100 → 89/100 | 0.05 → 0.032 | 10/8023 → 1/203 | 14683 → 1126 | 10/12 → 0/0 | 2 → 0 | 1/2.7 → 4/4.0 |
| `gene-reviews` | CURATOR | 63/100 → 100/100 | 69/100 → 98/100 | – → 0.006 | – → 2/156 | – → 454 | None/None → 0/0 | 0 → 0 | 1/2.7 → 4/4.1 |
| `genes` | public | 99/100 → 100/100 | 85/100 → 88/100 | 0.001 → 0 | 2/479 → 1/149 | 1067 → 454 | 0/0 → 0/0 | 0 → 0 | 3/3.6 → 4/4.1 |
| `home-first-visit` | public | 100/100 → 100/100 | 99/100 → 95/100 | 0.001 → 0 | 2/259 → 1/60 | 827 → 996 | 0/0 → 0/0 | 0 → 0 | 4/4.0 → 4/4.0 |
| `login` | public | 99/100 → 100/100 | 78/100 → 99/100 | 0 → 0 | 1/66 → 0/0 | 118 → 73 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.4 |
| `manage-about` | ADMIN | 100/91 → 100/100 | 96/90 → 99/100 | 0.114 → 0.004 | 2/362 → 1/74 | 1742 → 137 | 0/0 → 0/0 | 2 → 0 | 2/2.9 → 3/3.9 |
| `manage-analysis-releases` | ADMIN | 100/100 → 100/100 | 100/100 → 100/100 | 0.036 → 0.042 | 1/147 → 1/69 | 884 → 468 | 1/0 → 0/0 | 0 → 0 | 2/3.0 → 4/4.0 |
| `manage-annotations` | ADMIN | 100/99 → 100/100 | 92/99 → 100/100 | 0.126 → 0.019 | 1/179 → 1/71 | 2063 → 757 | 0/0 → 0/0 | 0 → 0 | 2/3.3 → 4/4.0 |
| `manage-backups` | ADMIN | 100/97 → 100/100 | 100/96 → 97/100 | 0.059 → 0.019 | 1/147 → 1/69 | 333 → 142 | 0/0 → 0/0 | 1 → 0 | 3/3.6 → 4/4.0 |
| `manage-metadata` | ADMIN | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 1/114 → 1/67 | 3295 → 114 | 0/0 → 0/0 | 0 → 0 | 4/4.1 → 4/4.0 |
| `manage-nddscore` | ADMIN | 94/96 → 100/100 | 80/95 → 100/100 | 0.466 → 0.02 | 1/123 → 1/54 | 438 → 210 | 0/0 → 0/0 | 1 → 0 | 2/3.1 → 4/4.0 |
| `manage-ontology` | ADMIN | 100/93 → 100/100 | 95/91 → 96/100 | 0.041 → 0.044 | 2/389 → 1/55 | 653 → 65 | 0/4 → 0/0 | 2 → 0 | 2/3.3 → 4/4.0 |
| `manage-ontology-mappings` | ADMIN | 97/96 → 100/100 | 86/95 → 100/100 | 0.501 → 0.022 | 1/91 → 1/72 | 18334 → 173 | 0/0 → 0/0 | 1 → 0 | 2/3.1 → 4/4.0 |
| `manage-pubtator` | ADMIN | 100/100 → 100/100 | 100/100 → 99/100 | 0 → 0 | 1/157 → 1/78 | 325 → 191 | 0/0 → 0/0 | 0 → 0 | 4/4.1 → 4/4.0 |
| `manage-rereview` | CURATOR | 100/100 → 100/100 | 97/100 → 100/100 | 0.016 → 0.002 | 1/144 → 1/62 | 937 → 1856 | 0/0 → 0/0 | 0 → 0 | 2/3.4 → 4/4.0 |
| `manage-user` | ADMIN | 100/92 → 100/100 | 98/91 → 100/100 | 0 → 0 | 1/168 → 1/56 | 317 → 96 | 0/0 → 0/0 | 2 → 0 | 2/3.4 → 4/4.0 |
| `modify-entity` | CURATOR | 100/100 → 100/100 | 99/100 → 100/100 | 0 → 0 | 2/469 → 1/54 | 686 → 134 | 0/0 → 0/0 | 0 → 0 | 2/3.6 → 4/4.0 |
| `nddscore` | public | 98/100 → 100/100 | 93/100 → 94/100 | 0.131 → 0 | 2/371 → 2/233 | 908 → 990 | 1/0 → 0/0 | 0 → 0 | 3/3.6 → 3/3.9 |
| `nddscore-gene` | public | 99/91 → 100/100 | 72/90 → 96/100 | 0.127 → 0 | 2/257 → 1/76 | 253 → 234 | 0/0 → 0/0 | 3 → 0 | 3/3.7 → 4/4.0 |
| `nddscore-modelcard` | public | 100/100 → 100/100 | 100/100 → 98/100 | 0 → 0 | 1/93 → 1/61 | 196 → 125 | 0/0 → 0/0 | 0 → 0 | 2/3.9 → 4/4.0 |
| `ontology` | public | 97/94 → 100/100 | 52/94 → 99/100 | 0.334 → 0.021 | 2/184 → 0/0 | 2382 → 388 | 1/0 → 0/0 | 2 → 0 | 3/3.3 → 4/4.0 |
| `panels` | public | 100/100 → 100/100 | 89/100 → 96/100 | 0.001 → 0 | 2/498 → 1/51 | 2482 → 475 | 21/0 → 0/0 | 0 → 0 | 2/3.4 → 4/4.0 |
| `password-reset` | public | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 1/100 → 0/0 | 186 → 78 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.1 |
| `phenotype-correlations` | public | 100/100 → 100/100 | 100/100 → 100/100 | 0.036 → 0 | 1/103 → 0/0 | 1612 → 93 | 0/0 → 38/3 | 0 → 0 | 2/3.6 → 4/4.0 |
| `phenotype-counts` | public | 100/100 → 100/100 | 99/100 → 100/100 | 0.032 → 0 | 1/87 → 0/0 | 2931 → 397 | 0/0 → 0/0 | 0 → 0 | 2/3.6 → 4/4.0 |
| `phenotype-functional` | public | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 1/128 → 1/51 | 3053 → 704 | 0/0 → 0/0 | 0 → 0 | 2/3.4 → 4/4.0 |
| `phenotypes` | public | 99/100 → 100/100 | 87/100 → 90/100 | 0.135 → 0 | 2/407 → 1/105 | 1106 → 773 | 9/0 → 0/0 | 1 → 0 | 3/3.3 → 4/4.0 |
| `publications` | public | 98/100 → 100/100 | 96/100 → 100/100 | 0.001 → 0.036 | 2/207 → 0/0 | 716 → 599 | 7/17 → 1/0 | 0 → 0 | 3/3.7 → 4/4.0 |
| `publications-stats` | public | 100/91 → 100/100 | 100/90 → 100/100 | 0.039 → 0 | 1/86 → 1/81 | 2528 → 1899 | 0/0 → 0/0 | 2 → 0 | 2/3.3 → 4/4.0 |
| `publications-timeplot` | public | 100/96 → 100/100 | 99/96 → 100/100 | 0.028 → 0 | 1/152 → 0/0 | 4714 → 705 | 0/0 → 0/0 | 1 → 0 | 2/3.4 → 3/3.9 |
| `pubtator` | public | 100/100 → 100/100 | 97/100 → 100/100 | 0 → 0.037 | 2/141 → 0/0 | 680 → 556 | 52/52 → 0/0 | 0 → 0 | 2/3.3 → 4/4.0 |
| `pubtator-stats` | public | 100/93 → 100/100 | 100/92 → 100/100 | 0.012 → 0.005 | 1/80 → 1/61 | 8404 → 429 | 0/0 → 0/0 | 2 → 0 | 2/3.1 → 4/4.0 |
| `register` | public | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 1/104 → 0/0 | 206 → 86 | 0/0 → 0/0 | 0 → 0 | 4/4.3 → 4/4.0 |
| `review` | REVIEWER | 99/93 → 100/100 | 84/92 → 91/100 | 0 → 0 | 3/400 → 1/109 | 966 → 1456 | 5/1 → 0/0 | 2 → 0 | 3/3.1 → 4/4.0 |
| `review-instructions` | REVIEWER | 100/100 → 100/100 | 100/100 → 100/100 | 0 → 0 | 2/196 → 0/0 | 358 → 106 | 0/0 → 0/0 | 0 → 0 | 5/5.0 → 4/4.0 |
| `search` | public | 98/100 → 100/100 | 96/96 → 95/100 | 0.083 → 0.021 | 3/216 → 0/0 | 2682 → 1193 | 1/0 → 0/0 | 0 → 0 | 3/3.1 → 4/4.0 |
| `user` | REVIEWER | 100/96 → 100/100 | 99/95 → 100/100 | 0 → 0 | 1/101 → 1/54 | 172 → 127 | 0/0 → 0/0 | 1 → 0 | 3/3.7 → 4/4.0 |
| `variant-correlations` | public | 100/100 → 100/100 | 99/100 → 100/100 | 0.032 → 0 | 1/110 → 1/65 | 803 → 1189 | 0/0 → 0/0 | 0 → 0 | 2/3.7 → 4/4.0 |
| `variant-counts` | public | 100/100 → 100/100 | 100/100 → 100/100 | 0.032 → 0 | 1/116 → 1/54 | 1047 → 515 | 0/0 → 0/0 | 0 → 0 | 2/3.7 → 4/4.0 |
| `view-logs` | ADMIN | 100/96 → 100/100 | 86/91 → 89/96 | 0.014 → 0 | 2/359 → 2/197 | 210 → 182 | 4/0 → 0/0 | 1 → 0 | 2/3.3 → 4/4.0 |

## Commits on `ui/quality-2026-11` after the audit commit `dcbf1fe3`

| Commit | What |
|---|---|
| `af055e4e` `ff8310ef` `7d92876e` `6128c87d` `d766b1ec` `287e8c35` | `--no-ff` merges of `fix/ui-shell-pages`, `-tables`, `-analyses-data`, `-analyses-clusters`, `-curation`, `-admin` (no conflicts) |
| `5614d52a` | The merge pushed two files over the 600-line code-quality ceiling; search pan/zoom moved to `networkSelection.ts`, the summary placeholder reuses the global shimmer |
| `625316d3` | The admin and table helper copies re-export the shared `displayFormat`/`dateUtils` helpers (their own comments said to, once F0 landed); "Showing 41–40 of 30" guard; Home role-redirect toast accepts only a route path and a known role |
| `a69b41a5` | "Approve all N" and its dialog counted the filtered rows while `approve/all` approves every pending row |
| `b4edb5e0` | Review round 1 (see below) |
| `eafc3788` | Review round 2 and narrow-window layout (navbar below 1,200 px, fixed-table minimum width, entity hero reserve per breakpoint) |
| `9e9e1e55` | The table minimum width now reaches the `<table>` (BTable replaces `table-attrs`) |
| `a51de32a` | Header and chip overlaps found in the final screenshots; documentation text for the changed labels |

## Tests

| Suite | Result |
|---|---|
| `vitest run` (all, at `a51de32a`) | 350 files, 2,768 passed, 2 todo |
| `vue-tsc --noEmit` | clean |
| `eslint` | 0 errors, 253 warnings (same count as the base) |
| `vite build` | OK |
| `make code-quality-audit` | clean |
| `make test-api-fast` (API files changed: `na="null"` serializers, `field_key_label`) | 9,201 passed, 0 failed; skips are the documented local-profile skips |

Every bug fix after the merge has a test that fails without it (checked by stashing
the fix): display helpers, toast guard, Approve all count, NaN year card, FDR "—",
gene-structure race, log time/duration, tiny NDDScore metrics, freshness pills,
search-box name, fixed-table min width on the real `<table>`.

## Adversarial review

- **ponytail-review** of the merged diff: duplicated display helpers drifting apart
  (the table copy guarded `last < first`, the shared one did not; the shared
  `formatCount` printed `"4200"` for a string) - fixed by consolidating; free text from
  `?denied=` reaching a toast - fixed; network layout worker not cancelled on leave -
  fixed in round 2.
- **Gemini** (`gemini-4-neon-xhigh` via `agy`, diff fed through stream-json in four
  parts because the first prompt was truncated at ~190 KB). 52 findings; confirmed and
  fixed: Approve all count vs filters (high), gene change during the Ensembl fetch
  skipped the new gene, "Publications NaN", missing correlation printed `0.00`, charts
  and spinners left-aligned after `#app` lost `text-align`, FDR `''` read as
  `< 1e-300`, fixed-width columns collapsing to 0 px at 768-1,100 px (Manage Users name
  over e-mail, approval tables cutting off Actions), role toast not shown when already
  on Home, worker without abort/`messageerror`, log duration "missing" styled as slow,
  fractional-second timestamps read as local time, "0 log entries" while loading, the
  two Claude copy buttons sharing one "Copied" state and the copy not announced,
  backups showing rows under the spinner, tiny NDDScore metrics as `0`, freshness pill
  "Entered —", NCBI failures counted as genes, pagers hidden while stranded on page 2,
  Escape closing a modal mid-save, native e-mail validation hiding the form error,
  repeated sign-in failure not re-announced, missing loading announcements, entity hero
  reserve at 576-991 px (CLS 0.16 -> 0.03), PubTator gene chips overflowing into the
  next column.
- Declined after checking: `.btn-xs` colour override (only outline buttons use it),
  `SectionEditor` padding (`BCardBody` present), chart tooltips clipped by the scroll
  wrapper (they reposition inside the container), Manage Users presets (presets store
  every key, so extra filters do deactivate them), StatCard decimals/null delta (callers
  pass `decimals`; delta is computed client-side and never null), annotation date
  fallbacks (callers guard the input), Modify Entity exact-id-first search (deliberate),
  pager `align="right"` (prop is typed `start|center|end|fill`), phenotype-cluster
  500 ms race (same path as before the change), `role="button"` on the approval synopsis
  and help badges (left as the curation branch chose; Enter/Space only open the same
  popover that focus already opens).

## Findings closed and open

The audit files list 134 finding ids (PUB 34, CUR 32, ADM 28, S 40). All P1 and P2
findings are closed by the six branches and the commits above; the measurement table
shows no remaining threshold failure except timing under parallel load. Open:

| # | Page | Item | Severity |
|---|---|---|---|
| 1 | gene-networks | The network is drawn on request ("Show interactive network"). Needs the maintainer's decision; auto-drawing costs Lighthouse ~61 desktop / 69 mobile until the API serves a precomputed display layout (the real fix) | decision |
| 2 | comparisons | Two identical "?" badges next to "Overlap" (UpSet help and evidence-tier help) | P3 |
| 3 | nddscore | Filter selects truncate their "Any …" placeholders at 1366 px | P3 |
| 4 | publications-timeplot | On a phone the chart scrolls sideways and the data starts off-screen | P3 |
| 5 | manage-about | On a phone long section titles are ellipsized (title attribute present) | P3 |
| 6 | approve-review/-status | At 576-767 px (between phone and protocol widths) the card list causes CLS ~0.16 on load; 390 px is 0.041 | P3 |
| 7 | entity | At 800 px other sections still shift ~0.07 on load (hero fixed); protocol widths are <= 0.003 | P3 |
| 8 | manage-ontology / manage-user | Under heavy host load the delayed spinner sits over the empty table for up to 400 ms and the table body grows on arrival (CLS 0.35 measured once under 10-shard load, 0.01 alone) | P3 |
| 9 | manage-analysis-releases | Table busy state uses raw `loading` while the "Loading releases…" line uses the 300 ms delay, so both can show for up to 400 ms | P3 |
| 10 | API consumers | `na="null"` changes the JSON type of missing values on the entity review/status, release, backup and admin routes from `"NA"` to `null`; the app handles both, external clients that test for `"NA"` need a release note | release note |

## Timing

The parallel run (10 shards on a host at load average 30-60 from other work) put 14
pages over the 2.5 s "usable" threshold on their first viewport. Re-run one page at a
time (`out/final-retime`), all 18 slow or late-fixed pages are usable in 64-1,418 ms on
every viewport and none fails any threshold. The per-page table uses the re-timed value
where one exists.

## Tool caveats (still flagged, not defects)

- `obscured` entries for Bootstrap `btn-check` radios (the label sits over the hidden
  input) on Create Entity and Admin Statistics.
- `obscured` correlogram cells on Phenotype correlations: cells without a value have no
  fill, so `elementFromPoint` falls through them.
- `obscured` on Publications: the verified-check icon inside the PMID link.
- Rows covered by the fixed navbar/footer are excluded from the overflow column above.
- "usable" can fire on the page heading before data on a loaded host (entity at 390 px
  showed skeletons in the parallel screenshot, 332 ms and fully loaded alone).

## Narrow widths (outside the protocol viewports)

Probed at 1024x768, 800x1000 and 600x900 because the review found fixed-width tables
collapsing there. After the fixes: no content past the viewport and no clipped text on
the approval, review, Manage Users, Manage Ontology and releases pages; wide tables
scroll inside their card; the navbar collapses below 1,200 px (at 1024 px the Curation,
Review and user menus used to sit past the right edge).

## Documentation

- `make docs-screenshots` (stack `sysndd_playwright_*` on :8088, torn down after;
  `api/config.yml` and `.env` did not exist in this worktree before and were removed
  again, so the tree is as before). Five captures failed on changed UI and were fixed in
  the screenshot manifest/helpers: the reset-email placeholder, the gene page row class,
  the "Approve all N" button names and the re-review "New batch" button (formerly a
  badge).
- 82 screenshots captured; 16 differed from the committed ones by under 1 % of pixels
  with the same size (browser 151 -> 159 font rendering, live data) and were restored
  with their provenance entries; 66 changed screenshots are kept. `make
  verify-doc-screenshots` passes.
- Text updated: Approve all (button and dialog now count every pending row), the
  re-review "New batch" button, "Show interactive network", and menus collapsing below
  1,200 px.
