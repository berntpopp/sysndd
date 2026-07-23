# Changelog

All notable changes to SysNDD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

## [Unreleased]

### Fixed

- **Public analysis snapshots now self-heal after a mid-runtime data change** (GeneNetworks, PhenotypeFunctionalCorrelation, phenotype/functional clustering, correlations). `source_data_version` is a hash of live curation counts/dates, so any approval/edit after API startup flips it and marks every active snapshot `source_version_mismatch`. Previously the ONLY thing that re-enqueued a non-current snapshot was the startup bootstrap, so the public endpoints returned a *permanent* HTTP 503 ("This analysis is being prepared and will appear here shortly") with nothing actually preparing it — until the next API restart. The serving path (`service_analysis_snapshot_read()`) now enqueues a best-effort, throttled, dedup-safe refresh of all presets (`service_analysis_snapshot_selfheal_on_serve()`, reusing the proven bootstrap submit path) whenever it observes a missing / stale / source-version- or schema-mismatched snapshot, so the "being prepared" promise becomes true and client polls converge to 200 without operator action. Throttled to one enqueue per process per `ANALYSIS_SNAPSHOT_SELFHEAL_THROTTLE_SECONDS` (default 60s); disable with `ANALYSIS_SNAPSHOT_SELFHEAL_ON_SERVE=false`. The self-heal is non-throwing — a submit failure never turns a 503 into a 500.

### Added

- Offline unit tests for the serve-time self-heal (`test-unit-analysis-snapshot-selfheal.R`: enqueue semantics, throttle window, disable gate, best-effort error swallowing) and read-service trigger wiring (`test-endpoint-analysis-snapshot-read.R`: fires on missing/stale/mismatch, not on 200/400, and never escalates a 503 to a 500).

## [0.28.2] — 2026-07-04

Hardening follow-ups to the v0.28.1 OMIM-NDD descendant expansion, from a deep code review.

### Fixed

- **Durable OMIM-NDD refresh now honors `OMIM_NDD_SEED_TERM`**: the refresh path (`comparisons-functions.R`) called `adapt_genemap2_for_comparisons()` with the hardcoded default seed, while the db-prep script and the `GET /api/comparisons/sources` provenance both read the `OMIM_NDD_SEED_TERM` env var — so an operator who set a non-default seed got provenance that disagreed with the imported set. Both paths now resolve the seed through a single helper, `omim_ndd_seed_term()`.
- **Descendant-resolution failure is now observable**: `hpo_all_children_from_term_api()` (the JAX `/descendants` fetch behind `omim_ndd_resolve_terms()`) previously swallowed network/parse errors and silently returned seed-only — re-introducing the exact under-capture bug v0.28.1 fixed. It now emits a `warning()` on any fetch error or empty/malformed response, so a degraded refresh shows up in worker logs. It also normalizes term ids (trim/`NA`/blank) before filtering.
- **Bounded the JAX request**: the fetch used raw `jsonlite::fromJSON()` (only the global 60 s connection timeout) inside a durable worker job; it now uses a bounded `httr2` request (`req_timeout` + one retry) so a stalled ontology API fails fast instead of tying up a worker.

### Added

- Offline unit tests for the seed/descendant resolution chain (`omim_ndd_seed_term`, `omim_ndd_resolve_terms`, `hpo_all_children_from_term_api`) covering success, empty/malformed, and failure branches with mocked `httr2` (`test-unit-omim-ndd-descendants.R`).

## [0.28.1] — 2026-07-04

Follow-ups to the v0.28.0 comparison work.

### Fixed

- **OMIM-NDD comparator now includes the seed term's HPO descendants, not just the exact seed** (follow-up to #502): `adapt_genemap2_for_comparisons()` filtered `hpo_id == seed_term` on HPO's `phenotype_to_genes.txt`, on the assumption that the file is upward-propagated. It is not — a disease annotated only with a specific descendant term (e.g. `HP:0001249` "Intellectual disability") does **not** also carry the ancestor seed `HP:0012759` "Neurodevelopmental abnormality", so the single-seed filter silently dropped it. Measured against the current HPO release, the seed-only filter matched 2216 OMIM diseases while the seed + its 48 descendants match 2844 — ~628 NDD diseases (including ~25 annotated with intellectual disability) were missing. The adapter now expands the seed to its full descendant set via `omim_ndd_resolve_terms()` (JAX ontology `/descendants` API via `hpo_all_children_from_term_api()`, degrading to seed-only on failure) and filters `hpo_id %in% ndd_terms` — matching the kidney-genetics pipeline and this repo's own db-side data-prep script, which already did `HPO_all_children_from_term()` + `filter(hpo_id %in% ndd_phenotypes)` (only the API side was out of sync). `omim_ndd_seed_sweep()` inherits the fix (each seed expands to its subtree). Regression-guarded by a descendant-only fixture case in `test-unit-comparisons-functions.R`. Worker-executed; restart the worker after deploy.
- **`normalize_comparison_categories()` ndd_genehub docstring** corrected to spell out the actual differentiated Tier→ClinGen mapping (Tier 1/AR→Definitive, Tier 2→Moderate, Tier 3/4/Missense/Unclassified→Limited) instead of the stale "all entries → Definitive" (#504).

## [0.28.0] — 2026-07-04

Curation-comparison source repair + refresh hardening, and the upstream half of #502 (configurable OMIM-NDD seed). The single dead comparison source (`geisinger_DBD`) had been blocking every production comparison refresh; the refresh is now resilient so no single dead upstream can freeze the comparator again.

### Fixed

- **`geisinger_DBD` comparison source repaired** (was a hard production blocker): the Developmental Brain Disorders database moved from the now-404 `dbd.geisingeradmi.org` CSV to NDD GeneHub. Migration `038_update_geisinger_dbd_source.sql` repoints the source to `https://nddgenehub.org/files/Full-Data.csv`, and the parser (`parse_ndd_genehub_csv()`) was rewritten to aggregate that canonical case-level export per gene (phenotype union, distinct PubMed IDs, derived inheritance). Because the historical refresh was all-or-nothing, this one 404 had been aborting the whole refresh. Verified end-to-end against the live 4.9 MB file.
- **Dead HPO term API replaced across the codebase**: the retired `hpo.jax.org/api/hpo/term` endpoint (and its old nested JSON shape) is replaced by the JAX ontology API `https://ontology.jax.org/api/hp/terms/{id}` in `db/config/db_config.R` (`hpo_term_api_base`), the db-prep HPO helpers, and the (unused) `api/functions/hpo-functions.R` variants. Descendant sets now come from a single `/descendants` call instead of a recursive per-term walk. HPO term browse outlinks moved to `https://hpo.jax.org/browse/term/{id}` (the `/app/` prefix was dropped in the HPO site rebuild); updated in `jobs_endpoints.R`, `analysis-snapshot-service.R`, and `EntityView.vue`.
- **`comparisons_update_async` not found on the durable worker**: `create_job()` submits `comparisons_update` as a durable System B job, but the comparisons/OMIM write-path functions were only sourced into the mirai daemon pool (`setup_workers.R`), never into the durable worker's `bootstrap_load_modules()` list. The passthrough handler's `base::get("comparisons_update_async")` therefore always failed with "object … not found", so the refresh never ran. `omim-functions.R`, `comparisons-sources.R`, `comparisons-parsers.R`, and `comparisons-functions.R` are now registered in `api/bootstrap/load_modules.R` (loaded by both the API and the durable worker). Restart the worker after deploy.
- **`ndd_database_comparison` schema drift on restored databases** (migration `039`): a `dbWriteTable`-style restore recreates the table with `comparison_id` as a `DOUBLE` PRIMARY KEY (no AUTO_INCREMENT), narrow auto-sized VARCHARs (`version(34)`, `publication_id(341)`, …), and a dropped `granularity` column — so the refresh fails with "Data too long for column 'version'" or a PK violation (the new per-list re-insert relies on AUTO_INCREMENT). Migration `039` idempotently re-asserts the intended migration-009/012 schema (re-adds `granularity`, converts `comparison_id` to `INT AUTO_INCREMENT`, widens the text columns). Verified end-to-end: a full Administrator-triggered refresh imported 18,668 rows from 7 sources with the rewritten geisinger parser (whose per-gene PubMed-ID lists reach ~1 KB, which is exactly why the `publication_id` TEXT widening was required).
- **`test-external-pubmed.R` sources the PubMed XML parser explicitly** (pre-existing gap surfaced by running the full `make ci-local` gate): the guard-source inside `publication-functions.R` uses base `source(local = TRUE)`, which does not surface `table_articles_from_xml` into the `test_that` scope, so the three parser unit tests errored under the full R lane after the #500 parser split. The test now sources `functions/pubmed-xml-parser.R` via `source_api_file(local = FALSE)`, mirroring how it already sources `genereviews-functions.R`. Test-only; no runtime change.

### Changed

- **Comparison refresh is resilient (per-list replace), not all-or-nothing**: each source downloads/parses independently; a failed source keeps its previously-imported rows and is named in `comparisons_metadata.last_refresh_error`, and the job reports `partial` (some failed) or `success` (all OK), only failing outright when every source fails. `comparisons_refresh_outcome()` is the single decision point. `comparison_id` is left to AUTO_INCREMENT so retained rows never collide with the per-list re-insert. The durable worker sources comparisons code at worker startup, so restart the worker before a refresh reflects code changes.
- **`comparisons-functions.R` split**: the per-source parsers + `standardize_comparison_data` were extracted into `api/functions/comparisons-parsers.R` and the OMIM-NDD adapter/sweep into `api/functions/comparisons-omim.R` (all registered in `api/bootstrap/load_modules.R`, guard-sourced from `comparisons-functions.R`) so every file stays under the 600-line ceiling.

### Added

- **Live source-provenance panel + `geisinger_DBD` → `ndd_genehub` rename**: the curation-comparison table's provenance popover (source list, download URLs, and the "last update" date) is now populated from a new `GET /api/comparisons/sources` endpoint (driven by `comparisons_config` + `comparisons_metadata`) instead of hardcoded, drift-prone text — so it always shows the current URLs and refresh date. The source is surfaced everywhere as **NDD GeneHub**, and the internal source key/`list` value was renamed `geisinger_DBD` → `ndd_genehub` (migration `040`, parser, dispatch, and frontend columns) to remove the stale "geisinger" identifier from the API `list` field, exports, and column keys.
- **Configurable OMIM-NDD seed + sensitivity sweep (#502)**: `adapt_genemap2_for_comparisons(seed_term = "HP:0012759")` makes the NDD definition a documented parameter (default reproduces the published set), and `omim_ndd_seed_sweep()` produces a per-seed report (gene-set size + SysNDD coverage gap) over narrow/default/broad seeds. The db-prep script reads the same seed from `OMIM_NDD_SEED_TERM`. Downstream API exposure of the variant sets remains a separate follow-up per #502.
- **NDD GeneHub evidence tiers surfaced as the comparison `category`**: `parse_ndd_genehub_csv()` now labels each gene with its NDD GeneHub evidence tier (`AR` / `Tier 1`–`Tier 4` / `Missense`, else `Unclassified`) instead of a flat placeholder, via `ndd_genehub_category_lookup()` reading the two sibling exports `Full-LoF-Table-Data.csv` (LoF tier 1–4 / `AR`) and `Full-Missense-Table-Data.csv` — the case-level `Full-Data.csv` has no tier column, and the LoF tier wins over Missense when a gene is in both. Verified live against the current NDD GeneHub tables (e.g. 612 Missense, 286 AR, 262 Tier 1, 192 Tier 4, 128 Tier 3, 96 Tier 2).

## [0.27.3] — 2026-07-03

Post-deploy fix release completing the `publication_date_backfill` work from #494. Closes #499. Closes #500.

### Fixed

- **NCBI API key now reaches the containers** (#499, follow-on to #494/#496): `docker-compose.yml` uses explicit `environment:` maps, so `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` in `.env` were never visible inside `api`, `worker`, or `worker-maintenance` — the backfill still ran anonymous (3 req/s). The two vars are now mapped into all three egress services (mirroring `GEMINI_API_KEY`). `pubtatornidd-cron` is intentionally excluded (backend-only network, DB-only enqueue, no egress). Set `NCBI_API_KEY` in the deployed `.env` and restart the workers.
- **GeneReviews publication dates can finally be verified** (#500, real cause behind #494): the shared PubMed EFetch parser matched `//PubmedArticle` only, so GeneReviews chapters — returned by EFetch as `<PubmedBookArticle>/<BookDocument>` and a large, permanent share of SysNDD references (~393 of ~553 unverified) — yielded 0 rows and were permanently "not retrievable". Once the non-book targets were verified, every subsequent run targeted only the unresolvable book records and the systemic-outage guard failed the whole job with 0 writes, on every run. The parser (now in `api/functions/pubmed-xml-parser.R`) parses book records with a `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate` date ladder (reusing the `pubmed`/`pubmed_partial` vocabulary), and the backfill now distinguishes `unresolved` (parse-empty data condition) from `failed` (transport/infra), firing the systemic-outage guard only on wholesale transport failure. Worker-executed code changed — restart `worker`/`worker-maintenance` after deploy.

## [0.27.2] — 2026-07-03

Post-deploy fix release resolving two production issues found while verifying v0.27.1. Closes #494, #495.

### Fixed

- **`publication_date_backfill` no longer 429s itself into a whole-job "systemic outage"** (#494, follow-on to #489): the PubMed EUtils helpers (`pubmed_fetch_xml`/`pubmed_esearch_count`) now route their query params through `pubmed_eutils_query()`, which attaches an NCBI `api_key` (plus optional `email`/`tool`) from `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` when set — raising the per-IP EUtils cap from the anonymous 3 req/s to 10 req/s — and the backfill self-throttles at a key-aware `pubmed_min_request_interval()`. Without a key the previous 200-id EFetch batch 429'd, the per-PMID fallback hammered a throttled endpoint (shared with the pubtator cron on the same IP), every PMID errored, and the systemic-outage guard failed the run with nothing written. Set `NCBI_API_KEY` in the worker `.env` and restart `worker-maintenance`.
- **The largest phenotype cluster's AI summary validates again** (#495, follow-on to #490): the phenotype LLM-judge grounded against only the top-15 phenotypes by `|v.test|`; for the ~1000-entity "pure/isolated intellectual disability + seizures" cluster the top-15 are dominated by strong depletions (heart, genitourinary, skeletal — all *absent*), so genuinely enriched, cluster-defining phenotypes (Seizures +8.2, ID-profound +8.2, Behavioral +7.7, Microcephaly +4.1) fell out of the judge's view and it hard-rejected the generator's correctly-grounded mentions of them as "fabricated". `build_phenotype_judge_prompt()` now lists ENRICHED and DEPLETED phenotypes separately (both `|v.test| > 2`, mirroring the generator) so an enriched term is never crowded out. Verified with a live Gemini A/B on the real cluster (old top-15 judge → reject, new judge → accept) and corroborated by independent Claude and Codex judging of the full data. Judge-only change — `LLM_SUMMARY_PROMPT_VERSION` intentionally unchanged; recover a cached terminal-`rejected` cluster with `POST /api/admin/analysis/snapshots/refresh?analysis_type=phenotype_clusters&force=true` after restarting the worker.

## [0.27.1] — 2026-07-03

Post-deploy fix release resolving the batch of issues the deployment agent filed against the v0.27.0 analysis-snapshot / clustering / LLM-summary work. Closes #483, #484, #485, #486, #488, #489, #490.

### Fixed

- **Analysis snapshots now rebuild on a snapshot-schema bump** (#483): `analysis_snapshot_status_code()` classifies a stored `schema_version` other than the code's `ANALYSIS_SNAPSHOT_SCHEMA_VERSION` as `schema_version_mismatch` (checked after `source_version_mismatch`), so the auto-bootstrap / admin refresh re-enqueue the preset and it self-heals on the next deploy instead of silently serving the old schema.
- **`publication_date_backfill` persists dates again** (#489): removed the SAVEPOINT-probe transaction detection that false-positived on a fresh autocommit connection (throwing `SAVEPOINT ... does not exist` and failing the whole job after fetching every PMID). Verified dates are now written in committed batches (`backfill_write_updates`, `write_batch_size`/`manage_transaction`), so partial progress persists across a mid-run outage and re-runs resume idempotently; `max_attempts` raised 1 → 2.
- **Heavy maintenance jobs no longer head-of-line block interactive work** (#486): `async-job-service.R` routes bulk/external maintenance job types to a dedicated `maintenance` queue lane (drained by a new `worker-maintenance` container; dev runs one combined worker) and corrects an inverted priority (batch backfill previously outranked interactive `llm_generation`/`clustering`). Interactive < maintenance < default priority tiers.
- **LLM cluster summaries stay consistent with the published snapshot** (#485, #488): the summary cache is now keyed on `cluster_hash` **plus** `LLM_SUMMARY_PROMPT_VERSION` so a future summary-prompt change invalidates unchanged-membership clusters instead of serving them stale (the version stays `1.0` this release — only the judge changed, so existing validated summaries remain accurate and keep serving), orphaned `is_current` rows whose hash left the snapshot are retired on refresh, and Administrator `POST /api/llm/regenerate` is driven from the published snapshot (reads `service_analysis_snapshot_shape_clusters` instead of recomputing clustering, which had produced non-matching hashes that blanked every cluster) with a real `force` path and a 409 when no public snapshot exists.
- **Judge-rejected cluster summaries are a distinct terminal state, not "being prepared" forever** (#490): `get_cluster_summary()` returns HTTP 200 `{summary_available:false, validation_status:"rejected", reason}`, both the phenotype and functional analysis views render an explicit "AI summary could not be validated for this cluster" card, the judge reason is persisted to `llm_generation_log`, and very large heterogeneous clusters get a relaxed gestalt judge instruction.
- **Corrected `refresh-analysis-snapshots.R` operator usage comment** (#484): documented the working `make refresh-analysis-snapshots` / stdin form instead of a `docker exec … /app/scripts/…` path that cannot exist (`scripts/` is excluded from the image and the container is non-root).

## [0.27.0] — 2026-07-03

Feature release: verifiable literature publication dates, scientifically-corrected + validated gene/phenotype clustering surfaced by a new in-app **Cluster validation** card, plus base-image/dependency bumps. Closes #457, #458, #459, #460.

### Added

- **Cluster validation card** on the functional (`/GeneNetworks`, `/Analysis`) and phenotype (`/PhenotypeCorrelations/PhenotypeClusters`) analysis pages: shows the partition metrics (weighted **modularity** for functional Leiden / **mean silhouette + data-driven k** for phenotype MCA-HCPC) and per-cluster **bootstrap-Jaccard stability** bands (`stable ≥0.75 · doubtful · weak · dissolved <0.5`) with the DB release label. Accessible (band label + numeric value, never colour-only); hides itself for snapshots built before validation existed. Frontend-only — the metrics were already served by the API. (#457, #458, #459)
- **Verified publication dates** end-to-end: the `publication_refresh` async job persists `publication_date_source`; a durable `publication_date_backfill` async job plus Administrator endpoints (`POST`/`GET /api/admin/publications/verify-dates[/status]`) let an operator run + inspect the one-time backfill; MCP publication outputs carry a `pubmed_verified` confidence flag and a year-bearing `recommended_citation`. (#460)
- **Cluster-validation metrics persisted in analysis snapshots** (migration `037_add_analysis_snapshot_validation.sql`): weighted-modularity + per-cluster Jaccard (functional), silhouette + data-driven k + per-cluster Jaccard (phenotype), and a human-facing DB release label, exposed read-only through the API (`meta.snapshot.validation`, a serve-time `validation_hash`, `db_release`) and MCP. (#457, #458, #459)

### Changed

- Functional Leiden now optimises **weighted** modularity on STRING `combined_score` and runs to convergence (`n_iterations = -1`); phenotype HCPC selects **k from the data** (was a hardcoded `k = 5`) and enforces `min_size`. (#457, #458)
- Bumped `rocker/r-ver` **4.6.0 → 4.6.1** (API base image; Ubuntu 24.04 noble unchanged) and `axllent/mailpit` **v1.30.2 → v1.30.3** (dev + Playwright compose mail sink). Supersedes #480, #481.
- Refactored the functional and phenotype cluster views under the 600-line ceiling — extracted `FunctionalClusterTablePanel.vue` / `PhenotypeClusterVariableTable.vue` table panels, `useFunctionalClusterTable` / `usePhenotypeClusterTable` composables, and a shared `useClusterSummary` composable — with no behaviour change.

### Fixed

- Verified-date backfill now **fails observably** on a systemic PubMed/worker outage (classed `publication_backfill_systemic_failure` when every targeted PMID errors) instead of a false "success"; surfaces `skipped_count`/`skipped_pmids`/`skipped_errors`. (#460)
- `cluster_max_jaccard()` returns `NA` (not `-Inf`) when a reference cluster is absent from a subsample, and per-cluster Jaccard counts only effective (non-NA) resamples. (#457, #458, #459)
- A serve-time `validation_hash` binds the served partition-validation metadata (which `payload_hash` intentionally excludes) so clients can detect a validation-only change; the Compose `CACHE_VERSION` default was bumped `2 → 3` so a redeploy invalidates the memoised cluster partitions from the old algorithms. (#457, #458, #459)

## [0.26.7] — 2026-06-30

Patch release: faceted-table column-header tooltips now show the correct "unique filtered/total" counts after an interactive filter (Entities, Genes, Phenotypes, PubtatorNDD genes, curation comparisons).

### Fixed

- **Column-header distinct-count tooltips were stuck at the global total after filtering**: applying a filter (e.g. Category → Definitive on `/Entities`) left the header tooltip showing `4200/4200` (and `3215/3215` for genes) instead of `count_filtered/count` (`1997/4200`, `1802/3215`). The data was correct end-to-end — the API returned the right `count_filtered` and the component's `fields` held it — but the rendered tooltip body never updated. Root cause: bootstrap-vue-next's `v-b-tooltip` directive only re-renders its floating popover body when `binding.value` changes (`hasBindingChanged` compares `[modifiers, value]`); the tables bound the text via the reactive `:title` **attribute**, so `binding.value` stayed `undefined` and the popover body froze at its first render (which is why a fresh page-load with the filter already in the URL looked fine). The five faceted count tables now bind the tooltip through the directive **value** (`v-b-tooltip.hover.bottom="getTooltipText(field)"`), so the counts update reactively. Guarded by `app/src/components/tables/columnHeaderTooltipReactivity.spec.ts`, which exercises the real directive both ways.

## [0.26.6] — 2026-06-30

Patch release: Force Apply on a blocked OMIM dictionary update no longer crashes with `$ operator is invalid for atomic vectors`, and the blocked-ontology banner now explains its two tables and links every version out to OMIM (#476, follow-up to #470/#474).

### Fixed

- **Force Apply crashed with `$ operator is invalid for atomic vectors`**: a blocked `omim_update` result carries `critical_entities`/`auto_fixes` as `purrr::transpose()` arrays, but `get_job_status(result_mode="full")` and the async worker both decode with `jsonlite::fromJSON(simplifyVector=TRUE)`, which collapses each array-of-objects into a **data.frame**. The force-apply payload helpers iterated those with `vapply(table, \(x) x$field, ...)` — over a data.frame that walks **columns** (atomic vectors), so the job died before the database write ever ran. The helpers were extracted to `api/functions/async-job-force-apply-payload.R` and now normalize any shape (data.frame, list-of-records, or empty) into a uniform tibble before column access, with data-shape regression tests covering the gap that let this ship.

### Changed

- **Blocked-ontology banner UX** (`ManageAnnotations` → Updating Ontology Annotations): the banner now explains why it shows two tables (critical entities need manual review; auto-fixable remappings are applied automatically on Force Apply), adds a **Disease** column to the auto-fixable table, and renders every version cell in both tables as an OMIM outlink (via the central `ontologyOutlink()` helper) with the `_N` version suffix stripped from the URL while the full versioned id stays visible as the label. The e2e fixture and admin blocked-banner spec were enriched to cover the new UI.

## [0.26.5] — 2026-06-30

Patch release: security update — four vulnerable transitive npm dependencies in the frontend lockfile are bumped to their patched versions, closing nine Dependabot alerts. Lockfile-only; no source, public-API, or behavioural changes.

### Security

- **Patched four vulnerable transitive npm dependencies** flagged by Dependabot (`app/package-lock.json` only — each parent's existing semver range already permitted the patched release, so no `package.json` change was needed and `npm update` resolves them):
  - **`undici` 7.25.0 → 7.28.0** — closes six alerts, including high-severity cross-origin request routing via SOCKS5 proxy pool reuse (GHSA-hm92-r4w5-c3mj) and TLS certificate-validation bypass in the SOCKS5 ProxyAgent (GHSA-vmh5-mc38-953g), plus Set-Cookie and cache-related issues. Dev/test only (pulled in by jsdom via vitest).
  - **`form-data` 4.0.5 → 4.0.6** — high-severity CRLF injection via unescaped multipart field names and filenames (GHSA-hmw2-7cc7-3qxx). Runtime, via axios.
  - **`@babel/core` 7.29.0 → 7.29.7** — arbitrary file read via `sourceMappingURL` comment (GHSA-4x5r-pxfx-6jf8). Build only, via vite-plugin-pwa → workbox-build.
  - **`esbuild` 0.27.7 → 0.28.1** — arbitrary file read when running the dev server on Windows (GHSA-g7r4-m6w7-qqqr). Build only, via vite.
- `npm audit` now reports **0 vulnerabilities**. Verified against the bumped lockfile with the production build, `type-check`/`type-check:strict`, vitest (1651 pass), eslint (0 errors), and the MSW↔OpenAPI verifier.

## [0.26.4] — 2026-06-30

Patch release: a blocked OMIM dictionary update no longer freezes the disease dictionary — brand-new terms are applied additively each cycle while critical entity-referenced changes await Force Apply — plus correctness fixes for Force Apply and the blocked-dictionary status banner (#470, #474).

### Added

- **Additive auto-apply for blocked OMIM dictionary updates** (#470): when an `omim_update` job is blocked by critical, entity-referenced changes, all brand-new, entity-unreferenced terms are now inserted additively (idempotent live anti-join inside the FK-disabled transaction; best-effort — an insert failure is logged and never turns the blocked job into a job failure) so the dictionary keeps growing each night instead of freezing. A successful additive insert chains the disease cross-ontology mapping refresh. A recurring `blocked` status is a standing-review flag, **not** a freeze; resolve the flagged entity-referenced changes via Force Apply.

### Fixed

- **Force Apply could never resolve a blocked OMIM update**: `PUT /api/admin/force_apply_ontology` looked up the blocked job with `get_job_status()` in summary mode, which omits the parsed `result_json`, so the "was the job blocked?" check always failed with `409 Referenced job was not blocked`. It now reads the job in `full` mode.
- **The blocked-dictionary banner stayed "blocked" after a successful Force Apply**: a resolved block kept re-asserting `blocked`/`stale` on every `/ManageAnnotations` load while its pending CSV lingered on disk (≤ 48 h). `derive_ontology_dictionary_status()` now excludes blocked jobs at or before the most recent successful apply.
- **`max_omim_id` could report a non-OMIM identifier**: a plain lexical `MAX()` over the mixed-prefix `disease_ontology_set` ranked `Orphanet:…` above `OMIM:…`; the lookup is now scoped to OMIM ids.
- **Additive apply no longer leaves a transaction open on the empty-insert branch** (a `return()` inside the `dbWithTransaction` block bypassed the commit on a shared connection), and the additive integration tests now actually run against a real connection instead of skipping/erroring on a nested transaction.
- **The MSW↔OpenAPI verifier (`make lint-app`) failed** on the `/api/admin/ontology/dictionary-status` handler because its mount map lacked the `/api/admin/ontology` and `/api/admin/analysis` sub-routers; both are now mapped before `/api/admin`.

## [0.26.3] — 2026-06-29

Patch release: analysis snapshots self-heal when stale, and the phenotype-cluster p-value / v-test columns render again.

### Fixed

- **Public analysis pages got permanently stuck on "This analysis is being prepared…" / `503` once their snapshot aged past 7 days** (GeneNetworks, Phenotype Clustering, Phenotype–Functional Correlation, and the other analysis presets): the startup self-heal (#420/#440) only re-built snapshots that were *missing*. Its skip probe, `analysis_snapshot_public_exists()`, returned TRUE for *any* public-ready row — including a `snapshot_stale` or `source_version_mismatch` one — so a stale snapshot was treated as "already present" and never re-enqueued, serving a 503 forever until an operator forced a rebuild. The bootstrap (and the non-`force` admin refresh) now use a staleness-aware probe, `analysis_snapshot_public_current()`, which only skips a preset whose active snapshot is genuinely current (`status_code == "available"`). Stale / version-mismatched snapshots now self-heal on the next API restart, exactly like missing ones. Regression-guarded by `test-unit-analysis-snapshot-repository.R` and `test-unit-analysis-snapshot-bootstrap.R`.
- **Phenotype Clustering "p-value" and "v-test" columns rendered blank**: the MCA stats arrive with dotted keys (`p.value`, `v.test`), and BootstrapVueNext's `BTable` renders an empty cell for a dotted field key (and Vue parses a `#cell-p.value` slot name as `cell-p` + a `value` modifier), so neither the column nor a custom cell slot could show the values. The rows are now normalized to flat aliases (`p_value`, `v_test`) via `normalizePhenotypeClusterRows()` before they reach the table, with the original dotted keys preserved for the Excel export. Regression-guarded by `phenotypeClusterTable.spec.ts` and `AnalysesPhenotypeClusters.spec.ts`.
- **The Phenotype–Functional Correlation page showed a raw "Request failed with status code 503" toast** while its snapshot was being prepared, instead of the friendly "being prepared" panel + retry shown by its sibling analysis pages. It now classifies the snapshot-preparing 503 via `isSnapshotPreparingError()` and renders the same graceful state. Covered by a new `AnalysesPhenotypeFunctionalCorrelation.spec.ts`.

### Dependencies

- Bumped the app production-minor-patch group (#472): `@unhead/vue` 3.1.4 → 3.1.6, `swagger-ui` / `swagger-ui-dist` 5.32.7 → 5.32.8, `vue` 3.5.35 → 3.5.39.
- Bumped the app dev-dependencies group (#473, 11 updates): `@axe-core/playwright` 4.11.3 → 4.12.1, `@playwright/test` 1.61.0 → 1.61.1, `@types/node` 26.0.0 → 26.0.1, `@vue/compiler-sfc` 3.5.35 → 3.5.39, `axios` 1.18.0 → 1.18.1, `eslint` 10.5.0 → 10.6.0, `globals` 17.6.0 → 17.7.0, `postcss` 8.5.15 → 8.5.16, `prettier` 3.8.4 → 3.9.3, `typescript-eslint` 8.61.1 → 8.62.0, `vite` 7.3.5 → 7.3.6.

## [0.26.2] — 2026-06-29

Patch release: restore the column-statistics header tooltips across all public tables and make the underlying counts correct everywhere.

### Fixed

- **Phenotypes / Genes column-header hover tooltips were missing** (regression surfaced after the v0.26.1 filter fixes): bootstrap-vue-next renders the `v-b-tooltip` popover as a child *inside* the `<th>`, and fixed-layout tables set `overflow: hidden` on header cells (for label ellipsis), which clipped the popover invisible. Only the Entities table escaped this, via an override scoped to `.entities-table`. The un-clip rule now lives once in `_tables.scss` and covers every public surface (`:is(.entities-table, .public-data-table) th.b-table-sortable-column`), so Phenotypes, Genes and the PubTator gene table show their "unique filtered/total values" hover again. The redundant per-component override was removed.
- **Curation comparisons table showed `0/<total>` for every column**: the `/api/comparisons` endpoint computed each column's total distinct `count` but never `count_filtered`, so the filtered side of the tooltip was always 0. A shared `fspec_merge_filtered_counts()` helper now computes `count_filtered` (distinct values after the active filter, joined by key) and is applied consistently across the entity, gene, phenotype, variant and comparisons endpoints — replacing four duplicated, position-based assignments (which also carried a latent ordering risk).
- **Curation comparisons column labels rendered with wrong casing** ("Sysndd", "Panelapp", "Omim ndd"): the component overwrote its curated labels with the backend's generic `str_to_sentence(key)` labels. The curated source labels (SysNDD, Gene2Phenotype, PanelApp, SFARI, OMIM NDD, …) are now re-applied over the backend field spec while keeping its count facets.
- **Some host-run R unit tests could not load the split helper modules** (`test-unit-endpoint-functions.R`: was `FAIL 9`): the `helper-functions.R` compatibility shim relied on a test helper that is out of scope when the shim is sourced into `globalenv`. It now resolves its sibling modules relative to its own file location, independent of caller environment or working directory (`FAIL 0 | PASS 57`).

### Changed

- Frontend column-header tooltip text is generated by the shared `useColumnTooltip` composable on all faceted tables (standard `getTooltipText`; guarded `getCompactTooltipText` for analysis tables whose columns may lack counts), removing duplicated inline expressions.
- Extracted `generate_comparisons_list()` into `api/functions/comparisons-list.R` (registered in `load_modules.R`), keeping `endpoint-functions.R` well under the file-size ceiling.

## [0.26.1] — 2026-06-29

Patch release: public table filter fixes and dependency maintenance.

### Fixed

- **Phenotypes table froze when filtering by Category** (#466): `filtered()` reassigned `this.filter` to a fresh object (via `applyPhenotypeLogicMode()`), which re-fired the deep `filter` watcher → `filtered()` → reassign → an infinite "Maximum recursive updates" loop that hung the page on any filter change. The AND/OR logic mode is now applied in place (idempotent), so the object reference is stable and the watcher settles. Regression test added.
- **Curation comparisons Table filters reverted to stale results** (#467): the table applied every browse response with no guard, so a slow earlier (unfiltered) request could resolve after a newer filtered one and clobber it ("filter to a gene, then it reverts"). The load now carries a monotonic serial id and drops superseded responses (the same lightweight guard `PanelsTable` uses). Regression test added. The same stale-response race was also swept across the other server-paginated tables: `PublicationsNDDTable` and the admin `ManageOntology` table had hand-rolled per-params dedup but no stale guard — both were migrated to the shared `createTableRequestCoordinator` (dedupe + `isCurrent` stale-drop), which also removed their bespoke dedup. `TablesEntities`/`TablesGenes`/`TablesPhenotypes` already used the coordinator; `PanelsTable` already had a serial guard. (`PubtatorNDDTable` is the remaining gap, deferred to a dedicated refactor so its 900+-line SFC can be modularised first rather than grown.)

### Added

- **Administrator view "Manage Ontology Mappings"** (`/ManageOntologyMappings`): an admin surface to monitor and trigger the disease cross-ontology mapping refresh. Shows the latest build provenance (MONDO release, term/xref/mapping/disease counts, status, duration) from `GET /api/admin/ontology/mappings/status`, a prominent cold-start warning when no build exists yet, and a "Refresh now" button (`POST /api/admin/ontology/mappings/refresh?force=true`) with live job progress. The mappings still populate automatically on startup (bootstrap), weekly (cron), and after an operator ontology refresh — this view adds operator visibility and a manual trigger.

### Dependencies

- Bumped the production-minor-patch app dependency group (4 updates, #461), the dev-dependencies app group (2 updates, #462), `@types/node` 25 → 26 (#463), the Docker Compose images group (mysql 8.4.9 → 8.4.10, mailpit v1.30.1 → v1.30.2, #464), and `actions/checkout` 6 → 7 in CI (#465).

## [0.26.0] — 2026-06-20

Minor release: disease cross-ontology mappings (MONDO / Orphanet / OMIM / DOID / UMLS / MedGen / NCIT / GARD / EFO) across database, API, and frontend, in lockstep across app, API, and DB schema versions.

### Added

- **Disease cross-ontology mappings** (#454): every SysNDD disease now carries provenance-tracked cross-references to external disease ontologies, anchored on MONDO as the hub (a disease's OMIM id resolves to MONDO via SSSOM, and MONDO's xrefs supply Orphanet/DOID/UMLS/etc.).
  - **Database** (migration `036`): a normalized `disease_ontology_mapping` store (source of truth, with `predicate`/`source`/`release_version`), a local `mondo_term`/`mondo_xref` index, a build-provenance table, and refreshed projection columns (`UMLS`/`MedGen`/`NCIT`/`GARD`/`ontology_mapping_release`) on `disease_ontology_set`. The cross-charset join key is utf8mb3-pinned; `ndd_entity_view` is intentionally untouched.
  - **Ingestion & refresh**: a durable `disease_ontology_mapping_refresh` async job (single-flight `GET_LOCK`, transactional rebuild, conditional-GET no-op, provenance meta rows); Administrator endpoints `POST/GET /api/admin/ontology/mappings/*`; a weekly `ontology-mapping-cron` sidecar; a staggered startup bootstrap; and a re-trigger after operator ontology refreshes so the projection columns can't drift. Validated end-to-end on real MONDO data (release 2026-06-02, ~40,645 mappings across ~6,766 diseases).
  - **Read API**: a cheap, public, DB-only `GET /api/disease/mappings?entity_id=|disease_ontology_id=` that resolves entities through `ndd_entity_view` (public surface only). `/api/ontology` also now returns the new columns.
  - **Frontend**: the Entities list row expansion gains an inline ontology outlink strip, and the Entity detail page gains a "Linked disease ontologies" card (`EntityOntologiesCard`), both rendering external outlinks via a central URL-template module (`ontology_links.ts`) and a typed client that normalizes the API's array-wrapped scalars.

### Operational

- New env vars: `DISEASE_ONTOLOGY_MONDO_OBO_URL` / `_SSSOM_URL`, `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP` (default true), `DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_STAGGER_SECONDS` (default 360), `ONTOLOGY_MAPPING_REFRESH_AT` / `_DOW`, and `EXTERNAL_PROXY_MONDO_*` budget tuning for the ~50–80 MB MONDO artifacts. The worker must be restarted on deploy to source the new job handler; the cron sidecar is DB-only while the worker (which runs the job) needs egress.
- **Database schema version → 0.26.0** (ships migration `036`): set `DB_VERSION=0.26.0` on deploy (`./db/scripts/update-db-version.sh 0.26.0 >> .env`) so the App and `/api/version` report the deployed schema version.

## [0.25.2] — 2026-06-16

Patch release: LLM cluster-summary judge robustness and startup job scheduling.

### Fixed

- **Phenotype judge permanently rejecting legitimate clusters** (#448): a sparse, depletion-defined cluster (e.g. the "mild, predominantly non-syndromic" phenotype cluster) had no correction path — the judge prompt treated any grounded clinical synthesis beyond the verbatim enriched terms as fabrication, and the verdict could never correct the main summary text, so the row was rejected forever. The verdict type now carries an optional `corrected_summary`, applied via `apply_judge_corrections()`, so isolated molecular phrasing or a single over-reaching label is salvaged via `accept_with_corrections` instead of `reject`. The phenotype judge prompt now explicitly allows grounded clinical synthesis of the listed phenotypes while preserving the hard-reject rules (fundamentally molecular summaries, direction inversion, fabricated specific phenotypes, and < 50% grounding) — no grounding threshold is loosened. The admin LLM cache view now surfaces the judge verdict, reasoning, and applied corrections (badge column + detail panel), reading both the top-level (accepted) and nested `validation` (rejected) persisted shapes. `llm-judge.R` was brought back under the file-size ceiling by extracting the prompt builders to `functions/llm-judge-prompts.R`.

### Performance

- **Staggered startup analysis-snapshot bootstrap** (#447): on a fresh start the bootstrap enqueued all snapshot presets plus the PubtatorNDD nightly as claim-eligible at the same instant, so the heavy `functional_clusters` build (recursive STRING enrichment) contended for the shared DB pool / CPU and could outrun its worker lease. The startup bootstrap now staggers heavy builds using the existing `async_jobs.scheduled_at` claim gate: heavy presets get a `scheduled_at` offset (`ANALYSIS_SNAPSHOT_BOOTSTRAP_STAGGER_SECONDS`, default 120s; `0` disables) while light presets stay immediately eligible, and the PubtatorNDD nightly bootstrap is offset separately (`PUBTATORNIDD_BOOTSTRAP_STAGGER_SECONDS`, default 240s). Only the automatic startup path staggers — the admin `force` refresh and the operator script submit immediately. No schema change and no extra worker.

## [0.25.1] — 2026-06-15

Patch release: reliability and UX fixes for the analysis-snapshot subsystem (GeneNetworks / phenotype clusters) and the LLM cluster summaries.

### Fixed

- **GeneNetworks cluster selection** (#441): selecting a functional cluster showed neither its AI summary nor its enrichment table. The snapshot endpoint serialises `cluster` as a string (`"1"`) while the network graph emits numeric ids (`[1]`), so the strict-equality lookups never matched and the summary fetch never fired. Cluster-id comparisons now coerce both sides; the same hardening is applied to the phenotype clusters view.
- **Analysis snapshots could fail permanently after a deploy** (#440): heavy snapshot builds (e.g. `functional_clusters`' recursive STRING enrichment) could outrun the worker lease under startup contention and were reaped to `LEASE_EXPIRED` with no retry, so the page 503'd indefinitely. Snapshot refresh jobs are now retryable (`max_attempts = 3`) and the stale-lease reaper requeues them — the startup bootstrap self-heals.
- **"Analysis being prepared" state for GeneNetworks** (#440): a `snapshot_missing` 503 now renders a friendly "being prepared / Check again" panel instead of a raw error toast, matching the network graph and phenotype views. Also fixed `isSnapshotPreparingError`, which only matched a bare-string problem `code` and never the real `["snapshot_missing"]` array shape — so the preparing state previously never triggered against the live API.
- **Rejected LLM cluster summaries are now debuggable** (#443): the LLM-as-judge's verdict and reasoning are persisted on the rejected cache row (internal QA metadata embedded in `summary_json`) instead of being discarded, so a persistently-rejected cluster can be diagnosed.

## [0.25.0] — 2026-06-14

Minor release: surface the read-only SysNDD MCP service in the UI — a footer icon beside the API/Swagger link and an expanded `/mcp` information page with client setup instructions.

### Added

- **MCP footer icon** beside the API/Swagger icon in the footer, linking to the `/mcp` information page. Uses the official Model Context Protocol logomark (MIT / public-domain geometric mark, recolored to the SysNDD brand) served from `/img/mcp.svg`.
- **Expanded `/mcp` information page**: per-client setup for coding clients (Claude Code `claude mcp add --transport http`, Claude Desktop, Cursor) and browser chatbots (Claude.ai custom connectors, ChatGPT developer-mode connectors), a read-only tool catalog, recommended workflow, and clearer transport/safety notes.

### Fixed

- **MCP footer asset path collision**: the footer logo is served from `/img/mcp.svg` instead of `/mcp.svg`. The dev Vite `/mcp` proxy (and production `/mcp` routing) forwards the `/mcp` prefix to the MCP transport, which returns `405` on a `GET`, so the icon silently fell back to the app icon.

## [0.24.0] — 2026-06-14

Minor release: public analysis snapshots now auto-bootstrap on startup so a fresh deploy heals on its own, plus Administrator refresh/status endpoints and a friendlier "being prepared" frontend state (#420).

### Added

- **Startup auto-bootstrap for analysis snapshots** (#420): after migrations, `analysis_snapshot_bootstrap_on_startup()` idempotently enqueues `analysis_snapshot_refresh` jobs for any supported preset lacking an active public-ready snapshot, so `/GeneNetworks` and `/PhenotypeClusters` heal automatically after a fresh deploy instead of serving 503 `snapshot_missing`. Gated by `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP` (default on), existence-checked (a restart with snapshots already present enqueues nothing), dedup-safe, and never crashes boot. Mirrors the #421 PubtatorNDD bootstrap pattern.
- **Administrator snapshot endpoints** (#420): `POST /api/admin/analysis/snapshots/refresh` (optional `analysis_type`, optional `force`) submits the refresh jobs and returns their ids; `GET /api/admin/analysis/snapshots/status` reports per-preset state (missing / available / stale / source_version_mismatch) with timestamps and row counts — letting an operator rebuild/inspect snapshots without SSH or `docker exec`. Non-admin callers get 403.
- **Frontend "analysis is being prepared" state** (#420): GeneNetworks and PhenotypeClusters now render a friendly retry panel when the API returns a snapshot 503, instead of a raw `AxiosError` and an empty page.

### Changed

- All three snapshot submit paths — the startup hook, the new admin endpoint, and the operator script `scripts/refresh-analysis-snapshots.R` (now `force=TRUE`) — share one `service_analysis_snapshot_submit_refresh()` function. The shared submit/status/bootstrap functions live in a focused new `services/analysis-snapshot-refresh-service.R` to keep the service files under the 600-line ceiling.

## [0.23.0] — 2026-06-14

Minor release: Administrator-views UX hardening and maintainability (audit follow-through to >9/10).

### Added

- **Per-view document titles** on the Administrator views (ManageUser/Ontology/Annotations/About/Backups/Pubtator/LLM/NDDScore/Metadata/AdminStatistics), via `useHead` — they previously rendered the generic "SysNDD |". Renders e.g. "Manage Users | SysNDD …".
- **Confirmation modals** replace native browser dialogs in the app's modal language: a `SavePresetModal` for naming a filter preset (was `window.prompt()` in ManageUser), a reusable `ConfirmActionModal` for the large-log-export gate (was `window.confirm()` in the logs table), and a confirmation gate (`useConfirmGate`) before the four heavy/irreversible ManageAnnotations operations (ontology update, force-apply, comparisons refresh, refresh-all).
- **Server-side "refresh all" for publications** — `POST /api/admin/publications/refresh` accepts `all=true` to enumerate the whole corpus server-side; the client no longer pulls every PMID. An empty request still 400s (safety guard).

### Changed

- **Gemini cost estimate is no longer hardcoded.** The LLM-admin cache cost estimate is centralized in the model catalog (`llm_model_pricing()` with per-model `price_input/output_per_million`) and keyed off the active model (`get_default_gemini_model()`), removing the stale "Gemini 2.0 Flash" rate.

### Fixed

- **Developer-reference version display** (`/API`) rendered the API and Database versions as raw Plumber 1-element arrays (`v[ "0.22.0" ]`) with a stray `[ "unknown" ]` commit badge (the badge guard `!== 'unknown'` never matched the array). The `/api/version` client now unwraps the array-wrapped scalars, so the versions render as plain `v0.22.0` / `v1.0.0` with the commit badge correctly hidden when unknown.

### Internal

- **`TablesLogs.vue` split** (1160 → 378 lines) into a `useLogTable` composable + `LogFilterToolbar` child + `logTableConfig`; file-size baseline ratcheted down.
- Job-status watchers in ManageAnnotations extracted to `useAnnotationJobReactions`; preset state moved into `useUserData` — both to keep oversized SFCs under the file-size baseline while adding behaviour.
- Documented that a durable HTTP job-cancel route is absent (the service layer supports cancellation but no endpoint exposes it) — recorded as a future change.

## [0.22.0] — 2026-06-14

Minor release: PubTatorNDD performance, stability, and automatic nightly updates.

- **Performance** — precomputed `pubtator_gene_summary` table (migration 035) replaces per-request `collect()`+`tidyr::nest()`; `/pubtator/genes` drops from ~800ms to ~100ms (Stats path 83ms) and the payload shrinks ~3×. Missing annotation/search-cache indexes added (migration 034).
- **Stability / bug fixes** — repaired the enrichment refresh (the NDD-corpus probe `@DISEASE_neurodevelopmental` silently returned 0; now `@DISEASE_Neurodevelopmental_Disorders`); fixed the worker external-time budget never resetting per job (which broke every external-calling job after the first); corrected the `publication_count`/`entities_count` double-count from the view's gene×publication×entity fan-out (now distinct counts, consistent with `pmids`).
- **Automatic updates** — new `pubtatornidd-cron` Compose sidecar enqueues a durable `pubtatornidd_nightly` job that incrementally fetches new publications, refreshes enrichment, and refreshes the summary table; single-flighted via a MySQL advisory lock.
- **Gene listing** — graceful degradation with a deterministic `-publication_count` fallback and an `enrichmentStatus` meta flag when no enrichment snapshot exists.
- **Frontend** — PubTatorNDD annotation-parse + gene-symbol caches are now bounded LRU; Stats chart re-render debounced; stale per-gene publication cache cleared on filter/sort; component split under the size baseline.

## [0.21.9] — 2026-06-14

Patch release: home-page performance — keep heavy libraries off the landing-page critical path.

### Changed

- **Home page no longer downloads ~600 KB of unused code.** `HomeView.vue` imported from the `@/composables` barrel, which statically re-exports heavy composables (`use3DStructure` → `ngl` 1.3 MB, `useMarkdownRenderer` 0.7 MB, `useCytoscape`/`useNetworkData` → d3, exceljs). Rollup cannot tree-shake the barrel, so the home route chunk eagerly pulled all of that in. Importing the two light composables (`useToast`, `useText`) directly bypasses the barrel; home JS payload dropped 740 → 211 KiB (−71%) and main-thread blocking from those modules executing went to ~0. This directly targets the mobile-Lighthouse LCP and TBT losses.
- **`gsap` is loaded lazily** (and split out of the `viz` chunk) — it is only needed for the home count-up animation that runs after statistics load, so it no longer sits on the first-load critical path; it degrades gracefully to instant numbers if not yet ready.
- **Leaner PWA precache.** The service worker no longer precaches the largest route-only chunks (`ngl`, `exceljs`, Swagger/`ApiView`, markdown) on first visit; they are runtime-cached on demand instead. First-visit background precache dropped 8.59 → 4.76 MB (−45%).

### Internal

- `app/.gitignore` now robustly ignores build output (`dist`, `dist-*`, `stats.html`, `*.tsbuildinfo`, `.lighthouseci`).

## [0.21.8] — 2026-06-13

Patch release: a public-page design + accessibility pass, plus review fixes.

### Changed

- **Accessibility lifted across all public pages (Lighthouse a11y mean 96.6 → 99.8; 23/25 pages now score 100; best-practices and SEO 100 on all 25).** Root-caused and fixed app-wide issues via shared components: the `heading-order` failure (the first-visit `DisclaimerDialog` used `h5`/`h6` → now `h2`/`h3`); `td-has-header` on every data table (filter-row cells marked `role="presentation"`); `select-name` and `button-name` on filter/page-size selects and icon controls; and `aria-prohibited-attr` (636 instances) on the gene-detail protein-domain lollipop SVG. The shared `TableShell`/`AnalysisShell` were moved onto the design tokens (neutral/`--border-subtle`/radius/shadow/brand blue) and each public page now has exactly one route-level `<h1>` (`TableShell` gained a `heading-level` prop, default `2`).
- **Low-contrast chips replaced with an AA token system.** Ad-hoc pastel chips that failed WCAG AA (e.g. Bootstrap blue `#0d6efd` on `#e7f1ff` ≈ 3:1, ~29 instances on PubTator) were replaced with shared `.sysndd-chip--*` classes in `app/src/assets/scss/partials/_chips.scss`; the app-wide `.text-muted` was aligned to `--neutral-700`.
- **Analyses menu:** the "Correlation matrix" entry was renamed to **"Phenotype–function correlation"** and moved to the end of the Analyses dropdown, and the page is now standalone (its misleading cross-link tabs, which navigated away to the phenotype correlogram, were removed).

### Fixed

- **Detail-page section cards size to their content again.** A layout-stability change had reserved a large fixed `min-height` on resolved cards, which made sparse cards (e.g. a Phenotypes card with one term) render as tall empty boxes with uneven heights; the reservation now applies only to the loading skeleton, so cards adapt to content (e.g. a Phenotypes card on `/Entities/1317` dropped from 288px to 107px).
- **The analysis correlation/matrix charts render again.** An attempted responsive-width change computed the SVG size before its container was laid out, so the D3 matrices (Curation similarity, phenotype/variant correlograms, time plot, phenotype–function correlation) rendered no SVG or at the wrong size; the chart sizing was reverted to its working approach.

### Internal

- Recorded the justified file-size growth from the accessibility/token additions in `scripts/code-quality-file-size-baseline.tsv` (added lines are necessary ARIA labels, roles, token styles, and chip classes rather than new behavior). Full audit, spec, plan, and before/after evidence live under `.planning/audits/2026-06-13-frontend-audit/`.

## [0.21.7] — 2026-06-13

Patch release removing the floating help/feedback widget and its backing "Cite" endpoint.

### Removed

- **The floating smiley help/feedback widget (`HelperBadge`) is gone from every page.** A fixed bottom-right green circle with a `bi-emoji-smile` icon opened a dropdown of Cite / Like / Improve / Docs / Help actions. It was lightly used and clashed with SysNDD's quiet, table-first visual direction, so it has been removed from the global app shell (`App.vue`) and deleted. Documentation and Help destinations remain reachable from the footer.
- **The `internet_archive` "Cite" endpoint and all of its supporting code are removed.** The widget's *Cite* action called `GET /api/external/internet_archive`, which forwarded the current page URL to archive.org's SPN2 (Save Page Now) API. With the widget gone the endpoint had no remaining caller, so the route (`api/endpoints/external_endpoints.R`), its backing functions (`api/functions/external-functions.R` — `post_url_archive` / `is_valid_archive_url`), the typed frontend client (`createInternetArchiveSnapshot` in `app/src/api/external.ts`) and its tests, the `test-unit-archive-url.R` unit test, the endpoint-checklist row, the docs section, and the now-unused `archive_access_key` / `archive_secret_key` / `archive_base_url` config keys have all been removed. The gnomAD / UniProt / Ensembl / AlphaFold / MGI / RGD external-proxy endpoints are unaffected. Verified in a restarted stack: `GET /api/external/internet_archive` returns `404` while the kept proxy endpoints still return `200`.

## [0.21.6] — 2026-06-13

Patch release unifying the Genes/Entities detail-page card borders with the rest of the app.

### Fixed

- **Detail-page cards no longer use a heavy black border.** The Genes (`/Genes/:symbol`) and Entities (`/Entities/:entity_id`) detail pages — plus the Ontology view (`/Ontology/:disease_term`) and the admin Job History card — wrapped their cards in `border-variant="dark"`, which rendered a heavy near-black Bootstrap border (`#212529`) that clashed with the home page and the public `/Entities`/`/Genes` tables. They now use the app-wide subtle surface border (pale blue-gray, `#d9e0ea`), so the detail/admin cards match the home hero/panels and the reference tables. This aligns with the visual design guide ("borders: pale neutral/blue-gray lines with low visual weight"; "avoid heavy black/dark borders"). The change is presentation-only — verified with Playwright at `1440px` and `390px`, every visible detail-page card border now computes to `rgb(217, 224, 234)` (`#d9e0ea`) with no remaining visible dark card borders.

### Changed

- **Introduced a canonical `--border-subtle` design token (`#d9e0ea`) and a `.border-subtle` utility class.** The ~30 component stylesheets that previously hard-coded the `1px solid #d9e0ea` panel border (home, user, analyses, curation, and form/wizard surfaces) now reference the token, giving the subtle surface border a single source of truth. The migration is value-identical; no surface changes appearance except the detail/admin cards described above.

## [0.21.5] — 2026-06-13

Patch release making the global search input look consistent between the home hero and the navbar.

### Fixed

- **The global search input now looks the same on every page.** The shared `SearchCombobox` rendered with two divergent looks: the home (`/`) hero variant used a heavy black input border (`border-dark`) and a dark/neutral action button (`btn-outline-dark`), while the navbar variant (shown on `/Entities`, `/Genes`, and all non-home routes) used the medical-blue action button but was passed a literal `placeholder-string="..."`, so it displayed a broken `...` placeholder instead of helpful text. Both variants now converge on one design-token-aligned treatment — the global low-weight `.form-control` neutral border with a medical-blue focus ring, the medical-blue `btn-outline-primary` action button, and the `Search genes, diseases, IDs` placeholder — differing only by size (default in the hero, `sm` in the navbar). This aligns with the visual design guide ("use blue for action and navigation"; "borders: pale neutral/blue-gray lines with low visual weight"). Suggestions, submit, and keyboard navigation are unchanged.

## [0.21.4] — 2026-06-13

Patch release fixing the NDDScore gene-predictions table on mobile.

### Fixed

- **NDDScore predictions are readable on mobile again.** The `/NDDScore` gene table rendered its 10-column fixed-layout `b-table` directly on small screens, crushing every column to ~28px so values truncated to `0..`, `Ve`, `Kn` with overlapping headers — the "stacked Bootstrap table" anti-pattern the visual design guide warns against. It now follows the same responsive pattern as the reference `/Entities` and `/Genes` tables: the desktop table is hidden below the `md` breakpoint (`d-none d-md-block`) and a purpose-built `NddScoreGeneMobileRows` record-card list renders instead (`d-md-none`). Each card shows gene + rank + an ML-prediction score / risk-tier / confidence / Known-vs-New chip row, with an expandable details panel for HGNC, percentile, top inheritance, model split, and predicted HPO. No horizontal overflow at 390px; the desktop table is unchanged. The "model-derived prediction, separate from curated SysNDD evidence" framing is preserved.

## [0.21.3] — 2026-06-13

Patch release hardening the API against slow external/analysis endpoints blocking cheap routes (#344), fixing the gene-page request-ordering regression that made our own "Associated" data load last, and repairing two latent defects that made it impossible for any public analysis snapshot (GeneNetworks, clustering, correlations) to be built.

### Fixed

- **Slow external/analysis endpoints can no longer block cheap routes (#344).** Three external HTTP calls that bypassed the central per-provider budget are now bounded: the UniProt step-2 features fetch (previously `req_timeout(30)` + `max_seconds=120`, a ~120s worker-occupying window) now goes through `make_external_request()`; the GeneReviews E-utilities call (a budget bypass reintroduced in #389) and the worker-only gnomAD-batch chunk request now derive their timeout/retry from `external_proxy_budget()`.
- **"Associated" entities (our own data) no longer load after the external enrichment cards on gene pages (#344).** `GeneView` fired its five external-provider fetches synchronously in `setup()` (via `useResource`'s immediate watcher) before the child entities table dispatched its request, so on the single-threaded API the cheap entity request queued behind up to six slow upstream calls and finished last (measured 4041ms on a symbol URL). External activation is now deferred to a post-mount macrotask so own-data is requested first (entity completion 4041ms → 391ms).
- **Public analysis snapshots can now be built — GeneNetworks/analysis pages are no longer permanently `snapshot_missing` (#344).** Two latent defects made `analysis_snapshot_refresh` impossible to complete: (1) the MySQL `GET_LOCK` advisory-lock name was 109–124 chars while MySQL caps it at 64 (errno 4163), and (2) the builder wrote each cluster's `equals(hash,…)` filter expression into `cluster_hash CHAR(64)`, overflowing it (errno 1406) and rolling back the refresh. Both fixed; after deploy, run `make refresh-analysis-snapshots` once to populate the public-ready snapshots.

### Added

- **Per-request external-time ceiling + observability (#344).** A request-scoped accumulator (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, default 15s), wired into both universal proxy wrappers, short-circuits further external work once a single request's accumulated external time crosses the ceiling — covering single-endpoint paths the 12s aggregate budget never governed. The `postroute` hook now logs `[request-timing] … duration_ms=… external_ms=… slow=…` (slow over `API_SLOW_REQUEST_MS`, default 2000), attributing slow requests to external time. New tunable env knobs: `EXTERNAL_PROXY_GENEREVIEWS_*`, `EXTERNAL_PROXY_GNOMAD_BATCH_*` (20/30/3 defaults).
- **Regression guards + tests (#344).** `test-unit-external-budget-guard.R` fails CI on any hardcoded external timeout literal; `test-unit-cheap-route-isolation.R` keeps `/health`, `/auth`, `/statistics` free of external-fetcher coupling; `test-integration-slow-provider-isolation.R` proves a slow provider fast-fails while a cheap read stays bounded; and the local-only `app/tests/e2e/slow-provider-resilience.spec.ts` + `gene-page-own-data-priority.spec.ts` lock in gene-page resilience and own-data request ordering. Worker-pool isolation remains tracked in #154.
- **Operator tooling to build analysis snapshots (#344).** `api/scripts/refresh-analysis-snapshots.R` and `make refresh-analysis-snapshots` submit `analysis_snapshot_refresh` jobs for every supported preset; previously no trigger existed (it is intentionally admin/operator-only and heavy).

## [0.21.2] — 2026-06-13

Patch release for Sprint 2 of the continuous oversized-file refactor (#346) — all nine workpackages (#394–#402, WP1–WP9), each landed as a behavior-preserving PR (#404–#412) and merged after integration validation (type-check, strict type-check, full Vitest suite, ESLint/MSW, SEO, R API unit tests, and a Playwright E2E parity check against `master`). Every reduction moves the file-size ratchet baseline downward only.

### Changed

- **WP1 — D3/visualization (#406).** `GeneStructurePlotWithVariants.vue` 1306→680 via a new `components/gene/gene-structure-plot/` module directory (context/render/tooltip/export); `GenomicVisualizationTabs`, `ProteinDomainLollipopPlot`, `VariantPanel`, and `useCytoscape` also reduced (four under the 600-line ceiling), with new unit tests for the extracted pure transforms.
- **WP2 — tables (#409).** `TablesPhenotypes.vue` 1153→873 via a new `PhenotypeFilterToolbar.vue`; the duplicated `normalizeSelectOptions` copies migrate onto the shared `utils/selectOptions.ts`; `TablesLogs` cancel-path hardening.
- **WP3 — analyses (#410).** Six pure-logic modules extracted (`usePubtatorParser`, publications/gene-cluster/curation-comparison/upset/phenotype-cluster helpers), each with specs; `NetworkVisualization` left untouched to preserve the GeneNetworks preset-layout invariant.
- **WP4 — NDDScore + LLM (#412).** `ManageLLM`, `ManageNDDScore`, `LlmSummaryCard`, and `NddScoreGeneDetail` drop under 600 via composables (`useLlm*`, `useNddScore*`) and a new `LlmOverviewPanel.vue`; the "ML prediction, separate from curated evidence" copy invariants are preserved.
- **WP5 — curation views (#411).** `CreateEntity.vue` 637→540 via `useEntityCreateOptions`; `ManageReReview.vue` 1579→1514 via static `reReviewTableConfig` extraction (no workflow/soft-LIMIT/batch logic touched). Deeper Options→composition decomposition of the curation views is deferred to a dedicated follow-up.
- **WP6 — admin views (#408).** `ManageBackups.vue` 1115→579 and `ManagePubtator.vue` under the ceiling via job-polling/upload/confirm-modal composables reusing `useAsyncJob` and the `LogDeleteModal` confirm pattern.
- **WP7 — API endpoints (#405).** `publication_endpoints.R` 1234→1141 (shared `collect_with_filter_pushdown`/`build_cursor_meta`/`build_cursor_links` helpers) and `user_endpoints.R` 1128→1117 (DRY'd password-complexity rule), with paired `test-unit-*-endpoint-helpers.R`.
- **WP8 — API services/functions (#407).** `response-helpers.R` 860→535 and `logging-repository.R` 744→237, splitting cohesive query-builder/field-selection layers into sibling files registered in `load_modules.R`.

### Documented

- **WP9 — DB prep scripts (#404).** `db/11_Rcommands_..._comparisons.R` 636→474 via a sourced helper file; `db/C_Rcommands_set-table-connections.R` recorded in `AGENTS.md` as an intentional size exception (its `ndd_entity_view` body must stay mirrored with migration 026).

## [0.21.1] — 2026-06-11

Patch release for Sprint 1 of the continuous oversized-file refactor (#346, PR #403).

### Changed

- **Oversized-file refactor program structured.** Issue #346 is broken into nine workpackage sub-issues (#394–#402) with a sprint plan; the file-size ratchet baseline is tightened to current actuals (three entries removed, ~14 lowered) and only moves downward.
- **`useD3Lollipop` split into a module directory.** The 1125-line composable now lives in `app/src/composables/d3-lollipop/` (context/helpers/tooltip/render/export modules, largest 388 lines) with unchanged public API and new unit tests for the pure helpers.
- **`TablesLogs` slimmed.** The delete-confirmation modal is extracted to `LogDeleteModal.vue` (with component tests) and the duplicated select-option normalizer is centralized in `app/src/utils/selectOptions.ts`.
- **Strict type-check D3 cohort retired.** `@types/d3` is installed; the d3-lollipop modules, `useD3GeneStructure.ts`, `ProteinDomainLollipopPlot.vue`, and `PubtatorNDDStats.vue` are now strict-clean and removed from the strict-scope exclusion lists.

### Fixed

- **Log delete-modal state reset.** The modal stays mounted so the hidden lifecycle reliably resets the confirmation text and delete mode on every close path (previously the reset handler never fired under `v-if`, leaving the mode stale).
- **`log-cleanup` container no longer reports unhealthy.** The service inherited the API image's Plumber-port healthcheck it could never satisfy; the healthcheck is disabled for the scheduler-only container.

## [0.21.0] — 2026-06-11

Feature release integrating 16 pull requests across the API, app, and database (issues #14, #22, #25, #32, #33, #36, #37, #46, #54, #89, #98, #105, #175, #344, #347, #348, #353, #360).

### Added

- **Curation and correlation matrix navigation links.** The curation matrix and phenotype correlation matrix are now discoverable from the Analyses navigation and cross-linked between related analysis pages (#89).
- **Scheduled database log cleanup.** A `log-cleanup` Compose service prunes old rows from the operational `logging` table on a daily, configurable schedule (`LOG_RETENTION_DAYS`, `LOG_CLEANUP_AT`, dry-run), reusing the API image (#105).
- **Research-popularity-normalized PubtatorNDD ranking.** Gene NDD co-occurrence counts are normalized with enrichment ratio, NPMI, and Fisher's exact test + Benjamini-Hochberg FDR, with the table defaulting to the enrichment ranking (migration 027, #175).
- **Semantic database version.** A single-row `db_version` table tracks the semantic DB version and last `db/`-folder commit, surfaced in `GET /api/version` and on the About page (migration 028, #22).
- **Re-review refusal action.** Re-reviewers can decline a complex / out-of-scope entry, flagging it for specialist attention as a distinct state surfaced to curators (migration 029, #54).
- **Analysis snapshot provenance lineage.** The `meta.snapshot` block returned by public REST and MCP analysis reads now includes `input_hash`, `payload_hash`, and `record_counts`, completing the provenance/FAIR output contract from issue #347.
- **External-provider isolation coverage.** Added a slow-provider regression test asserting cheap routes stay responsive, and structured per-provider timing logs (upstream duration, timeout, cache hit/miss, status); deep worker-pool isolation remains tracked in #154 (#344).
- **Combined status & review modal with role-gated direct approval.** Modify Entity gains a single status+review workflow and a Curator+ direct-approval toggle enforced on both the client and the API (#36, #37).
- **Admin metadata vocabulary management.** A new Administrator `/ManageMetadata` view administers SysNDD-managed curation vocabularies with tiered editability and in-use-protected soft deletes (migration 033, #32).
- **GeneReviews coverage.** A curator view looks up GeneReviews availability per gene via NCBI E-utilities, attaches chapters to entities, and exports coverage; flags genes lacking a chapter (#14, #46).
- **Centralized Gemini model configuration.** Model selection resolves through a single validated source of truth, dropping the shut-down `gemini-3-pro-preview` default in favor of a current Gemini 3.x model (#348).
- **CSR / certificate renewal automation design.** An ADR plus a dry-run-safe CSR-generation skeleton and operator runbook (ACME vs scripted-CSR), pending the institutional CA decision (#25).
- **Reproducible database-creation scripts.** The `db/` data-prep scripts are config-ized (no hardcoded URLs/secrets), working-directory independent, orchestrated by a master runner, documented, and support a reproducible SQLite SysID source (#33).

### Fixed

- **VariO ontology links repaired.** Broken VariO term links now resolve via EBI OLS4 and the base URL is configurable; the larger ontology data migration is documented for curator sign-off (#98).
- **MCP search and analysis defects.** Fixed `publication_type` aggregation, `null` serialization in `structuredContent`, zero-result query echo, and snapshot-unavailable status mapping in the read-only MCP layer, with a spec/plan for the remaining benchmark items (#353).

### Changed

- **Quieter local CI.** `make ci-local` no longer prints an alarming expected MySQL access error on the success path and emits a classified skip summary, with verification strength unchanged (#360).

## [0.19.1] — 2026-05-15

Patch bump for the GeneNetworks cluster-selection UX.

### Added

- **Functional cluster parent nodes are selectable.** Clicking a Cytoscape compound cluster parent filters the graph and table to that cluster while gene-node clicks continue to open the gene page.
- **All-clusters summary cue.** The GeneNetworks table shows a compact AI-summary cue in all-clusters mode with a direct action to focus the first available cluster.

### Fixed

- **Cluster selection can be cleared from the graph.** Clicking the empty network background returns the graph and table to the all-clusters view.
- **Stale AI summary requests no longer replace the active cluster summary.** Rapid cluster changes now ignore older summary responses once a newer cluster selection is active.

## [0.19.0] — 2026-05-14

Minor bump for PR #338's admin visual-design pass, log-table performance work, LLM regeneration feedback fixes, and worker egress correction.

### Added

- **Canonical SysNDD visual guide.** Added `documentation/10-visual-design-guide.md`, admin visual ratings, and cross-agent/editor pointers for future UI work.
- **Shared admin operation surface.** Added `AdminOperationPanel` and migrated multiple admin/annotation views away from dark Bootstrap card chrome.

### Changed

- **Admin operation pages are more consistent.** Refined ManageLLM, ManagePubtator, ManageBackups, AdminStatistics, ViewLogs, and Entities table layouts toward the compact table-first visual guide.
- **Worker egress is explicit.** The async worker remains on the internal backend network and is also attached to the egress-capable proxy network for Gemini, PubMed, PubTator, and similar provider calls.

### Fixed

- **Logs first page loads faster without breaking cursor semantics.** The first-page SQL fast path preserves `page_size=all`, returns a last-page cursor, and uses stable `id` tie-breaking for non-unique sort columns.
- **LLM regeneration tracking is visible and durable across page navigation.** ManageLLM now tracks child jobs per cluster type and restores active browser-session job cards after returning to the page.
- **Character phenotype cluster IDs no longer break LLM progress messages.** Cluster progress formatting now accepts descriptive cluster labels.

## [0.16.5] — 2026-05-09

Fix bump for entity detail clipboard resiliency after PR #328 feedback.

### Fixed

- **Clinical synopsis copy is now reliable.** The copy button in the Clinical Synopsis card only shows “Copied” when clipboard access succeeds, and resets correctly on failure or when permission/secure-context constraints prevent copying.
- **Clipboard side effects are scoped cleanly.** The copy timeout is now canceled on navigation/unmount, preventing stale timers and copy-label flicker.

## [0.16.4] — 2026-05-09

Patch bump for the gene detail UI/UX density and ClinVar summary improvements in PR #327.

### Changed

- **Gene detail external evidence cards are denser and more readable.** Tightens gnomAD constraint, ClinVar, Model Organisms, and protein/gene visualization presentation while preserving the Vue 3 + TypeScript + Bootstrap Vue Next architecture.
- **Associated entities embed no longer shows the global table search row.** Adds a `showSearchInput` option to `TablesEntities` and disables it only for the gene-detail Associated table.
- **ClinVar summary is richer without loading the full variant list into the card.** The `summary=true` gnomAD ClinVar response now includes compact consequence and per-class breakdowns, and the card renders keyboard-accessible dense chips with popover breakdowns.

### Fixed

- **Gene detail contrast and spacing regressions.** Improves compact label contrast, no-data states, card density, and protein panel overflow behavior.
- **Gene page accessibility issues.** Addresses page heading semantics, decorative SVG ARIA, model-organism badge accessible names, and navbar list semantics touched by the gene detail audit.

## [0.16.2] — 2026-05-08

Patch bump for the consolidated dependency refresh in PR #321, combining Dependabot PRs #316, #317, and #312.

### Changed

- **Frontend production dependencies refreshed.** Updates `@unhead/vue`, `@vueuse/core`, `bootstrap-vue-next`, `cytoscape`, `dompurify`, `swagger-ui`, and `swagger-ui-dist`.
- **Frontend development dependencies refreshed.** Updates test/build tooling including `@vue/test-utils`, `axios`, `eslint`, `jsdom`, `msw`, `postcss`, `typescript-eslint`, `vue-tsc`, and related tooling packages.
- **API Docker base image refreshed.** Updates `rocker/r-ver` from `4.5.3` to `4.6.0` with a matching R 4.6 / Bioconductor 3.23 API lockfile refresh.
- **API CI runners aligned with R 4.6.0.** Updates R-based GitHub Actions jobs so `setup-renv` restores against the same R minor recorded in `api/renv.lock`.
- **R 4.6 restore compatibility fixed.** Updates stale API package pins that failed from source under R 4.6/GCC 13 (`lazyeval`, `rex`, `RMariaDB`, `base64enc`, and `S7`), drops the obsolete `plogr` lockfile entry, adds the host CI system libraries required by `textshaping`, and serializes the `tseries` restore before `forecast` on cold API dependency installs.

### Fixed

- **Production CSP allows bundled fonts.** Adds `font-src 'self'` so self-hosted SPA font assets are not blocked by `default-src 'none'`.
- **PubMed parser keeps articles with one-part first-author names.** `table_articles_from_xml()` now treats a missing first-author `ForeName` as an empty string instead of collapsing the parsed PMID row.

## [0.16.1] — 2026-05-08

Patch bump for the atomic entity rename and PubMed validation fix in PR #319.

### Fixed

- **Entity rename is atomic.** `POST /api/entity/rename` now delegates to `svc_entity_rename_full`, carrying source approval/status state to the replacement entity and rolling back all rename writes on failure.
- **Unresolvable PMIDs fail before partial writes.** PubMed misses now raise `publication_fetch_error`, list the offending `PMID:` values, and return HTTP 400 at entity/review endpoints instead of creating partial publication/entity state.
- **Curator error toasts show API messages.** Entity mutation failures now surface structured API error text instead of object-shaped toast content.
- **Rename edge cases are guarded.** Malformed rename payloads, missing active source status, and stale source deactivation are rejected before or inside the transaction.

## [0.11.14] — 2026-04-24

Patch bump for the durable async job hard cut in PR #305. This replaces process-local async job ownership with a MySQL-backed durable queue/state model, a dedicated worker service, and CI smoke/bootstrap fixes required to verify the new architecture on pristine environments.

### Fixed

- **Pristine DB smoke startup no longer fails before foundational schema exists.** Added a bootstrap migration so a fresh MySQL instance creates the base tables needed by later migrations before content and durable async schema migrations run.
- **Production-style smoke verification now matches real stack readiness.** The smoke script retries SPA readiness before asserting security headers, and local prod-stack compose starts rebuild fresh images so stale dev-built images do not produce false failures.
- **Durable async job status reporting preserves terminal semantics.** Cancelled jobs now report as `cancelled` instead of generic execution failures, and worker progress/lease updates are persisted so long-running jobs do not look stale while still executing.

### Changed

- **Async jobs are now durable and worker-owned.** Canonical async state lives in MySQL, the worker service claims and executes jobs independently of the API process, and frontend polling no longer depends on sticky-session correctness.
- **Worker deployment model is explicit.** Operator docs now describe the separate worker service, durable queue semantics, and worker-health expectations rather than the old API-process `mirai` ownership model.

## [0.11.13] — 2026-04-23

Patch bump for the auth query-string hard cut in PR #304, plus a follow-up CI fast-path refactor so normal review cycles no longer wait on the full API suite and environment bootstrap checks.

### Fixed

- **Auth-sensitive inputs are hard-cut to body-only transport.** `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-update flows no longer accept query-string payloads. Runtime request logging keeps auth-sensitive query strings redacted, and the DB cleanup migration scrubs persisted historical values.
- **Auth endpoint validation now fails closed on malformed JSON bodies.** Signup and password-update handlers reject nested or non-scalar required fields with `400` before downstream coercion or tibble/pivot work.
- **Auth review regressions are locked in.** E2E auth lifecycle tests now target the mounted `/api/auth/*` routes, and endpoint-auth tests assert unique source decorators before slicing source windows.

### Changed

- **PR CI now has a fast API gate.** Pull requests run `Test R API (fast PR gate)` against a repo-owned file selection, while non-PR CI keeps the full API suite. This preserves full confidence coverage off the PR critical path.
- **Tooling-heavy PR checks are conditional.** `make doctor` and `Smoke Test (prod stack)` only stay in the PR path when workflow, tooling, or boot-path files change; they still run outside PRs.
- **Local fast-loop mirrors PR CI.** `make test-api-fast` now exists as the local equivalent of the PR-fast API gate, and `make pre-commit` uses it. `make ci-local` remains the full local parity gate.

## [0.11.12] — 2026-04-22

Patch bump for the consolidated dependency + security sweep in #298 (subsumes #288, #289, #291, #292, #293, #295, #297). Also lands two CI stability guardrails introduced during review.

### Fixed

- **Master CI break — `@testing-library/dom` peer-dep drift.** Vitest suites were failing with `Cannot find package '@testing-library/dom'` because `npm ci --legacy-peer-deps --prefer-offline` stopped hoisting it under `@testing-library/user-event`. Pinned as an explicit `devDependency` so the package is guaranteed at the root of `node_modules`. Seventeen previously failing test files now pass.
- **nginx: security headers silently dropped.** Headers declared at `http{}` level were being discarded by every `location{}` block because those blocks define their own `add_header Cache-Control` (nginx inheritance rule: a child `add_header` erases the parent's). Moved the full OWASP / UniBE header set into `app/docker/nginx/security-headers.conf` and `include` it inside every location — closes #296.
- **nginx: server version leak.** Added `server_tokens off` so the `Server:` header no longer advertises the exact nginx build.
- **API crashloop — `mirai 2.5.3` / `nanonext 1.8.2` mismatch.** PPM pruned `nanonext 1.7.2`, `mirai`'s `Imports: nanonext (>= 1.7.2)` floor was satisfied by the 1.8.2 release which no longer exports `.read_header`, and `renv::restore` silently upgraded on rebuild. Date-pinned the PPM snapshot URL (`/cran/2026-04-22`) in both `api/Dockerfile` and `api/renv.lock`, and bumped to `mirai 2.6.1` + `nanonext 1.8.2`. Closes #294.

### Changed

- **Dependency bumps (prod):** `@unhead/vue 3.0.3→3.0.4`, `bootstrap-vue-next 0.44.2→0.44.6`, `dompurify 3.3.2→3.4.0` (mXSS + prototype-pollution fixes), `swagger-ui` / `swagger-ui-dist 5.32.0→5.32.4`.
- **Dependency bumps (dev):** `axios 1.13.6→1.15.1` (header-injection + CRLF hardening), `eslint 10.0.2→10.2.1`, `msw 2.12.10→2.13.4`, `postcss 8.5.8→8.5.10`, `prettier 3.8.2→3.8.3`, `typescript 6.0.2→6.0.3`, `typescript-eslint 8.58.2→8.59.0`, `vue-tsc 3.2.5→3.2.7`.
- **Docker image bumps:** `mysql 8.4.8→8.4.9` (prod + both dev DBs), `axllent/mailpit v1.29.6→v1.29.7`, `fholzer/nginx-brotli v1.29.8→v1.30.0`.
- **HSTS policy.** Rewrote the header set. `Strict-Transport-Security` now ships `max-age=63072000; includeSubDomains; preload` (2 years). **Preload submission is deliberately deferred** — see #300 before adding the domain to the browser preload list. Dropped legacy `X-XSS-Protection`, `X-Download-Options`, `X-Permitted-Cross-Domain-Policies`, and the duplicate `X-Content-Security-Policy` header (all obsolete per modern browser guidance).

### Added

- **CI smoke-test asserts SPA security headers.** `scripts/ci-smoke.sh` step 4 curls the running prod stack and grep-asserts presence of `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `Content-Security-Policy`, plus absence of a `Server: nginx/<version>` leak. Guards against a future `location{}` block forgetting the `include` or a `server_tokens` regression.
- **Dependabot: group container-image bumps.** Weekly runs now open at most one Dockerfile PR and one compose PR (matching the existing `actions` group pattern) instead of one PR per image.
- **Dependabot: ignore Vite semver-major.** Vite 8 has real breaking changes (`manualChunks` type moved from object to function, `vitest.config.ts` factory API changed). Dropped here; reopen when we schedule a migration. Closes #290 (the standing dependabot PR).

### Follow-ups (opened, not in this release)

- #299 — CSP tightening (drop `'unsafe-inline'` / `'unsafe-eval'`); needs Report-Only probe + swagger-ui audit.
- #300 — HSTS preload-submission decision (one-way door, needs UniBE ICT sign-off).

## [0.11.8] — 2026-04-12

Closes Phase D of the v11.0 test foundation initiative by landing D6 (`extract-bootstrap`), plus a reinforcing Phase B worktree that closes six MSW handler-table gaps Phase C batch review identified. **No new runtime behavior**; D6 is a pure structural refactor of the startup path and reinforcing-B adds test-only MSW stubs.

### Changed

- **D6 — Extract `api/start_sysndd_api.R` into `api/bootstrap/` module set.** Rewrote the 992-LoC startup script with 21 `<<-` super-assignments into a 137-LoC thin composer over 8 bootstrap modules. Every `<<-` is eliminated — `bootstrap_*()` functions return their results and the composer binds them at the top level of `start_sysndd_api.R` (which IS `.GlobalEnv`), so endpoint handlers, filters, and middleware that still look up `pool` / `serializers` / `migration_status` / `root` / etc. as globals keep working unchanged.
  - `api/bootstrap/init_libraries.R` (76 LoC) — `library()` attachment order (STRINGdb/biomaRt first so `dplyr`'s masks win).
  - `api/bootstrap/load_modules.R` (144 LoC) — sources repositories → services → core → filters in the order the Phase C source-order test expects.
  - `api/bootstrap/create_pool.R` (50 LoC) — builds the DBI pool, returns it.
  - `api/bootstrap/run_migrations.R` (159 LoC) — runs pending migrations, returns status list.
  - `api/bootstrap/init_globals.R` (63 LoC) — serializers, inheritance/output/user allow-lists, `version_json` / `sysndd_api_version`.
  - `api/bootstrap/init_cache.R` (103 LoC) — disk-backed `memoise` cache + 9 memoised helpers.
  - `api/bootstrap/setup_workers.R` (132 LoC) — mirai daemon pool + `everywhere({...})` worker-side source block (unchanged function set and order, verified against the pre-D6 block).
  - `api/bootstrap/mount_endpoints.R` (191 LoC) — all `pr_mount()` calls + filter wiring, returns the root router.
  - `api/core/filters.R` (294 LoC, new) — extracted Plumber filter definitions (cors, auth, logging, error handler) from `start_sysndd_api.R`.
  - `api/Dockerfile` — added `COPY services/` (pre-existing gap — container was relying on bind-mount alone, which would break production builds) and `COPY bootstrap/` lines so the built image includes the new module directory.
  - `docker-compose.yml` — added `./api/bootstrap:/app/bootstrap` bind-mount and a matching `docker compose watch` sync target.

### Added

- **Reinforcing Phase B — 13 new MSW handlers covering six B1 gaps Phase C specs worked around via per-test `installAuxHandlers` stubs.** These are test-infrastructure-only changes; Phase E rewriting agents can now rely on shared mocks instead of duplicating per-spec stubs.
  - Gap 1: `GET /api/entity?filter=...` (Review.vue step 1).
  - Gap 2-4: `GET /api/list/entity`, `/list/gene`, `/list/disease` (dropdown stubs — these routes are Phase E contracts that `list_endpoints.R` doesn't implement yet; handler shapes follow the `{id, label}` tree-mode convention).
  - Gap 5: `GET /api/re_review/table` (cursor envelope mirroring `re_review_endpoints.R @get table`).
  - Gap 6: `ManageAnnotations.vue` aux endpoints — `GET /api/admin/annotation_dates`, `/admin/deprecated_entities` (with Viewer 403 branch); `PUT /api/admin/update_ontology_async` (Viewer 403 branch), `/admin/force_apply_ontology` (400 when `blocked_job_id` missing); `POST /api/admin/publications/refresh` (400 when body missing); `GET /api/publication/stats`, `/publication`, `/publication/pubtator/genes`, `/publication/pubtator/table`, `/comparisons/metadata`.
  - New fixture files under `app/src/test-utils/mocks/data/`: `lists.ts`, `re_review.ts`, `annotations.ts`.
  - No existing B1 handlers modified; 33 test files still pass (439 passed + 6 todo).

### Verified

- `wc -l api/start_sysndd_api.R` → **137** (plan target ≤200).
- `grep -c "<<-" api/start_sysndd_api.R` → **0**.
- `grep -rn "<<-" api/start_sysndd_api.R api/bootstrap/` → **0 hits**.
- `Rscript --no-init-file api/scripts/lint-check.R` → 90 files, 0 issues.
- Full backend test suite inside the api container: **70 files, 0 failures, 2338 passed, 247 skipped** (the skips are the documented DB-gated / slow tests).
- `docker compose restart api` → boots in 3 attempts, zero "could not find function" or fatal-error entries in startup logs.
- Critical endpoints all return 200: `/api/health/ready`, `/api/version/`, `/api/llm/prompts` (D1-regression guard), `/api/backup/list?page=1` (D5-shape guard), `/api/search/CUL1?helper=true`.
- CI on PR #256 (D6): `Detect Changes`, `make doctor`, `Smoke Test (prod stack)`, `Lint R API`, `Test R API` all SUCCESS; frontend jobs correctly skipped (no frontend changes).

### Phase D gate (§8) — all green

- Local and remote `v11.0/phase-d/*` branches: **0**.
- Legacy wrapper file (`api/functions/legacy-wrappers.R`): **deleted**.
- All D1/D2/D3 split-file size targets met; the two documented overruns (`response-helpers.R` 762 LoC, `llm-service.R` orchestrator 724 LoC) remain because splitting further would fragment cohesive logic.

## [0.11.7] — 2026-04-12

Phase D of the v11.0 test foundation initiative — backend structural refactors protected by the Phase C test net. Five parallel worktree units (D1–D5) consolidated here; D6 (`extract-bootstrap`) follows in a subsequent PR. **No new runtime behavior**; this is exclusively source-structure refactoring protected by pre-existing Phase C tests.

### Changed

- **D1 — Split `api/functions/llm-service.R` (1,748 LoC) into focused modules.**
  - `llm-client.R` (318 LoC) — Gemini HTTP/SDK calls: `get_default_gemini_model()`, `generate_cluster_summary()`, `is_gemini_configured()`, `list_gemini_models()`.
  - `llm-types.R` (572 LoC) — ellmer `type_object` specs + prompt builders.
  - `llm-rate-limiter.R` (184 LoC) — `GEMINI_RATE_LIMIT` config + `calculate_derived_confidence()`.
  - `llm-service.R` (726 LoC orchestrator) — `get_or_generate_summary()`, cluster data fetchers, prompt template CRUD.
  - Conditional source guards let the orchestrator load its dependencies when sourced standalone (e.g., from `test-llm-batch.R`). `get_api_dir()` fallback handles testthat's working-directory switches.
- **D2 — Split `api/functions/helper-functions.R` (1,440 LoC) into 4 focused modules.**
  - `account-helpers.R` (194 LoC) — `random_password`, `is_valid_email`, `generate_initials`, `send_noreply_email`.
  - `entity-helpers.R` (222 LoC) — `nest_gene_tibble`, `nest_pubtator_gene_tibble`, `extract_vario_filter`, `get_entity_ids_by_vario`.
  - `response-helpers.R` (766 LoC) — `generate_sort_expressions`, `generate_filter_expressions`, `select_tibble_fields`, `generate_cursor_pag_inf`, `generate_tibble_fspec`. Exceeds the 500 LoC target because `generate_filter_expressions()` alone is ~340 LoC; splitting it would fragment cohesive dispatch-table logic.
  - `data-helpers.R` (291 LoC) — `generate_panel_hash`, `generate_json_hash`, `generate_function_hash`, `generate_xlsx_bin`, `post_db_hash`.
  - `helper-functions.R` retained as a 14-line compatibility shim — pre-existing tests source it directly; shim conditionally loads the 4 split modules.
- **D3 — Split `api/functions/pubtator-functions.R` (1,269 LoC) into 3 focused modules.**
  - `pubtator-client.R` (351 LoC) — BioCJSON API calls + rate limiting (`pubtator_rate_limited_call`, `pubtator_v3_*`).
  - `pubtator-parser.R` (380 LoC) — JSON parsing + 3-approach gene-symbol computation (`pubtator_parse_biocjson`, `compute_pubtator_gene_symbols`, flatteners, `generate_query_hash`).
  - `pubtator-functions.R` (548 LoC orchestrator) — `pubtator_db_update()` (sync) + `pubtator_db_update_async()` (mirai workers).
- **D4 — Deleted `api/functions/legacy-wrappers.R` (630 LoC).** All 10 wrapper functions migrated to their natural service layer homes with their original names preserved (endpoint handlers and Phase C test sandboxes reference them by name):
  - `put_post_db_review`, `put_post_db_pub_con`, `put_post_db_phen_con`, `put_post_db_var_ont_con` → `api/services/review-service.R`.
  - `put_post_db_status` → `api/services/status-service.R`.
  - `post_db_entity`, `put_db_entity_deactivation` → `api/services/entity-service.R`.
  - `put_db_review_approve`, `put_db_status_approve` → `api/services/approval-service.R`.
  - `new_publication` → already existed in `publication-functions.R`; legacy version removed.
  - All migrated wrapper functions use `logger::log_*` namespacing for consistency with the rest of the service files.
- **D5 — Pagination sweep on 14 GET endpoints across 7 endpoint files.** New `paginate_offset()` helper in `api/functions/pagination-helpers.R` returns a standardized `{data, links, meta}` envelope with input validation (`limit` clamped to `[1, 500]`, `offset >= 0`) and safe URL-separator handling for `links.next`.
  - Paginated: `backup/list`, `llm_admin/cache/summaries`, `llm_admin/logs`, `re_review/assignment_table`, all 4 `search/*` routes, `variant/correlation`, `variant/count`, `panels/options`, `comparisons/options`, `comparisons/upset`, `comparisons/similarity`.
  - `backup/list` preserves legacy top-level `total`/`page`/`page_size` fields for backward compatibility with pre-existing callers while adding `links`/`limit`/`offset` for the new contract.
  - `about/{draft,published}` and `hash/create` intentionally untouched (single-item/non-list endpoints).
  - New `api/tests/testthat/test-pagination-contract.R` (332 LoC, 26 tests) — net-new contract surface allowed by the test gate; validates `paginate_offset()` correctness plus static signature extraction confirming all 14 target handlers accept `limit`/`offset`.

### Source list
- `api/start_sysndd_api.R` — Source block wrapped in `# --- function source list (v11.0) ---` / `# --- end source list ---` markers. `legacy-wrappers.R` and `helper-functions.R` source lines removed/adjusted; new split module source lines added in alphabetical order. `everywhere({...})` mirai worker block updated to match.

### Verified
- Docker container restart smoke — mirai workers load the refactored function set without `could not find function` errors.
- All 5 unit PRs (D1–D5) green on CI: `Lint R API`, `Test R API`, `Smoke Test (prod stack)`, `make doctor`, `Detect Changes`.
- `test-endpoint-backup.R` (76/76), `test-endpoint-search.R`, `test-endpoint-variant.R`, `test-pagination-contract.R` all green in a live Docker container run.
- File size gates: all new files under plan targets except the documented `response-helpers.R` and `llm-service.R` orchestrator exceptions.

### Outstanding (for v0.11.x follow-ups or v11.1)
- D6 (extract-bootstrap) — splits `api/start_sysndd_api.R` into `api/bootstrap/` modules. Follows in a sequenced PR after this one lands.
- Missing `base_url` on several `paginate_offset()` call sites means `links.next` drops active query params; flagged by Copilot, deferred to avoid expanding Phase D scope.
- Weak `post_db_entity()` missing-field detection (NULL/NA values) — pre-existing behavior, preserved intentionally by D4 migration.

## [0.11.6] — 2026-04-12

Phase C of the v11.0 test foundation initiative — the Tier B safety net that Phase D/E rewrites depend on. 11 new test files landed across 6 view functional specs, 2 composable spec pairs, and 3 R endpoint test batches, plus the default-on transaction rollback audit across every pre-existing `test-integration-*.R` file. **No runtime code changed**; this is exclusively test authoring plus narrowly-scoped B1 MSW drift fixes uncovered by Checkpoint #2's batch review.

### Added

- **C1–C6 — View functional specs.** Six new `*.spec.ts` files against unchanged Vue view source, each with a happy path, an error path, and a concrete `it.todo(...)` handshake that Phase E rewriting agents will turn into passing assertions.
  - `app/src/views/curate/ApproveReview.spec.ts` (C1, 487 LoC, 3 tests + 1 todo). Routed-axios wrapper passes C1-scoped endpoints through to real MSW while short-circuiting 4 unrelated onMounted GETs that aren't in the B1 table. Bonus "handlers probe" `it()` block asserts all 5 locked B1 review handlers return their 2xx shapes — durable proof that B1 remains wired even as Phase E5's rewrite changes which code paths invoke them. Locked `it.todo`: *"verify the correct approver role appears in the audit trail"* (E5 handshake).
  - `app/src/views/review/Review.spec.ts` (C2, 563 LoC, 2 tests + 1 todo). Module-level `vi.mock('axios')` for the classification wizard flow since `Review.vue` calls `/api/re_review/table`, `/api/list/*`, and `/api/entity?filter=…` — none of which are in the B1 table. Error path asserts `isFormValid.value === false` + no PUT fires when synopsis is empty (semantic substitution for the plan's literal "Save button disabled", since the view's `:disabled` binding is not wired on unchanged source). Locked `it.todo`: *"verify the step-indicator state after a back-navigation"*.
  - `app/src/views/curate/ApproveStatus.spec.ts` (C3, 466 LoC, 2 tests + 1 todo). Uses the real `@/plugins/axios` instance so the 401 response interceptor fires live; error path asserts `router.push({ path: '/Login', query: { redirect: '/curate/approve-status' } })`, auth header cleared, and `localStorage.token` wiped on stale token. Locked `it.todo`: *"verify the combined status/review handling — hook for E6 convergence"* (E6 handshake).
  - `app/src/views/curate/ModifyEntity.spec.ts` (C4, 320 LoC, 2 tests + 1 todo). Component-level `mocks: { axios }` mirrors the existing `ModifyEntity.a11y.spec.ts` pattern. Happy path asserts the real `rename_json.entity` wire shape (which is what surfaced the B1 `POST /api/entity/rename` handler drift — see _Fixed_ below). Error path asserts 409 on duplicate entity creation. Locked `it.todo`: *"verify unsaved-changes warning on navigation"*.
  - `app/src/views/admin/ManageAnnotations.spec.ts` (C5, 564 LoC, 2 tests + 1 todo). Closure-counter polling via a single `server.use(http.get('/api/jobs/:job_id/status', …))` that returns different payloads on successive polls, driven by `vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] })` + `advanceTimersByTimeAsync(3000)` — precise fake-timer scope keeps axios/MSW/Vue microtasks real. Error path uses the Phase 76 `status="blocked"` safeguard pattern (not a job-cancel endpoint, which does not exist in the API). Locked `it.todo`: *"verify the force-apply flow fires PUT /api/admin/force_apply_ontology with the correct blocked_job_id"* (E4 handshake).
  - `app/src/views/admin/ManageUser.spec.ts` (C6, 317 LoC, 2 tests + 1 todo). **Canonical MSW pattern** for future Phase D/E view specs: real `@/plugins/axios` wired via `mocks: { axios, $http: axios }` + `vi.stubEnv('VITE_API_URL', '')` + seeded `localStorage.token` + minimal `GenericTable` stub exposing `data-test="cell-user-role"`. Line 1558 of `ManageUser.vue` confirmed as `PUT /api/user/update` with body envelope `{ user_details: … }`. Error path asserts the local `users` array still shows `Administrator` after a 403 demote-last-admin rejection — prevents optimistic-drop regression. Locked `it.todo`: *"verify the search-and-filter state persists across role edits and user_role bulk assignments via POST /api/user/bulk_assign_role"*.
- **C10 — useAsyncJob + useEntityForm composable specs.** Two new spec files (`app/src/composables/useAsyncJob.spec.ts`, `useEntityForm.spec.ts`) totalling 48 tests. Pins the composables' behavior before Phase E4/E5 consume them. `useAsyncJob` tests drive the submit→poll→complete, submit→poll→blocked, and submit→poll→error state transitions via `server.use()` + fake timers; the `blocked` test pins the current "composable keeps polling because only `completed`/`failed` are terminal" behavior with an inline comment flagging that Phase E4 will tighten it — loud test-diff signal instead of silent drift. `useEntityForm` has no HTTP calls (it's pure form state); the contract test forwards `getFormSnapshot()` through a `server.use` wrapper around `POST /api/entity/create` to document the camelCase→snake_case field-name mapping (`geneId → hgnc_id`) that the host view is expected to perform.
- **C11 — useTableData + useTableMethods composable specs.** Two new spec files (`app/src/composables/useTableData.spec.ts`, `useTableMethods.spec.ts`) totalling 57 tests. `useTableData` is a pure reactive state factory (zero HTTP), so no MSW handlers are consumed — the spec asserts refs and computeds directly. `useTableMethods` delegates re-fetches to an injected `loadData` callback; the spec over-covers the plan minimum with coverage for `copyLinkToClipboard`, `requestExcel` (happy + error + missing-dep no-op), `filtered`/`removeFilters`/`removeSearch` including the ref-wrapped filter branch and the missing-`any` silent-no-op branch, the URL `history.replaceState` side effect, and the `truncate`/`normalizer` helpers. Source-type oddity noted: `sortDesc` is declared `ComputedRef<boolean>` in `TableDataState` but implemented as a writable computed — the spec casts to `WritableComputedRef<boolean>` to exercise the documented setter; this is flagged as a future cleanup, not fixed in Phase C.
- **C7 — Read endpoint testthat batch.** Four new `test-endpoint-*.R` files covering every HTTP method per route in the read-only endpoint files (exit criterion #5 locked). Each test uses a file-local static handler-shape extraction pattern: parse the endpoint file, extract the anonymous `function(req, res, …)` literal via a decorator regex, `eval()` into a sandbox env with stubs for `require_role`, `pool`, repo functions — then assert formals + body text against expected helper references. Mirrors the Phase A `test-endpoint-auth.R` approach and works without a running plumber server.
  - `api/tests/testthat/test-endpoint-search.R` — 4 `@get` routes in `search_endpoints.R` × 2 blocks (happy + 404/empty) = 8 test_that blocks.
  - `api/tests/testthat/test-endpoint-list.R` — 4 `@get` routes in `list_endpoints.R` × 2 = 8 blocks.
  - `api/tests/testthat/test-endpoint-statistics.R` — 10 `@get` routes in `statistics_endpoints.R` × 2 = 20 blocks (the biggest read-batch file).
  - `api/tests/testthat/test-endpoint-ontology.R` — 2 `@get` + 1 `@put` route in `ontology_endpoints.R` = 6 blocks. The `@put` is included per the file-scope rule of exit criterion #5 even though it's a write route living in a read-only-batch file.
- **C8 — Write endpoint testthat batch.** Four new test files with 60 test_that blocks across 20 route × method combos, each wrapped in `with_test_db_transaction()`. Per exit criterion #5, each combo has happy + validation + permission blocks. For write routes the tests extract handler literals into a sandbox (same pattern as C7); for read-only routes living in these files the "permission" block asserts the **absence** of a `require_role()` call in the handler body blob — a public-read guarantee by construction.
  - `api/tests/testthat/test-endpoint-review.R` — 8 routes × 3 = 24 blocks covering `review_endpoints.R` (largest write file).
  - `api/tests/testthat/test-endpoint-status.R` — 6 routes × 3 = 18 blocks.
  - `api/tests/testthat/test-endpoint-phenotype.R` — 3 routes × 3 = 9 blocks.
  - `api/tests/testthat/test-endpoint-variant.R` — 3 routes × 3 = 9 blocks.
- **C9 — Admin endpoint testthat batch.** Two new test files with 27 test_that blocks. `test-endpoint-backup.R` (22 blocks across 5 routes: `@get /list`, `@post /create`, `@post /restore`, `@get /download/<filename>`, `@delete /delete/<filename>`) — the download happy-path uses `withr::local_tempdir()` with real bytes and stubs `file`/`file.info`/`readBin`/`file.exists` to route reads through the fixture without touching the handler's hard-coded `/backup/` path. `test-endpoint-hash.R` (5 blocks across 1 `@post create` route) tests the hash endpoint with default and custom endpoint forwarding. The `create_job` stub in `make_backup_sandbox` never invokes `executor_fn`, cleanly bypassing the mirai-daemon-sourced `execute_mysqldump`/`execute_restore` path.

### Fixed

- **R1 — B1 handler wire-shape drifts (3 items) found by Checkpoint #2 batch review.** The reviewer ran `curl` against the live dev API for 3 B1 handlers and confirmed drifts that would crash any view going through the real endpoint:
  - `GET /api/review/:id` — R/Plumber returns a 1-row array for single-row queries, not a bare object. `ApproveReview.vue`'s `loadReviewInfo` indexes `response.data[0].synopsis`. Handler now returns `[reviewByIdOk]`. Smoke test at `handlers.spec.ts:257` and C1's handlers-probe `it()` block updated to assert the array shape and index `[0].review_id`.
  - `GET /api/status/:id` — same R/Plumber 1-row-array convention. `ApproveStatus.vue`'s `loadStatusInfo` indexes `response.data[0].category_id`. Handler now returns `[statusByIdOk]`. C3's per-test `server.use` override (which already worked around this via `HttpResponse.json([statusByIdOk])`) becomes redundant but remains correct.
  - `POST /api/entity/rename` — the real endpoint reads `req$argsBody$rename_json$entity$entity_id` (`entity_endpoints.R:408-419`). The old handler checked `body.sysndd_id`/`body.new_symbol` (flat shape) which don't exist on the real wire — every legitimate request would 400 against the B1 default. New validation accepts the real envelope `{ rename_json: { entity: { entity_id, … } } }` and retains the legacy flat shape for backwards compatibility. C4's component-level axios mock is unaffected.
- **R2 — Default-on rollback audit Q5 gap.** C8's rollback audit headers on `test-integration-async.R` and `test-integration-llm-endpoints.R` used prose documentation of the HTTP-only exemption but the Layer B grep in `scripts/verify-test-gate.sh` only accepted the literal `skip_if_no_test_db()` call paired with an exempt keyword. Fix: widened the grep to also accept `skip_if_api_not_running|skip_if_no_api` (the skip helpers these HTTP-only tests actually use — they legitimately skip based on server reachability, not DB availability, and have no client-side transaction to roll back), and widened the exempt-keyword set to include `http-only` and `read-only`. Also widened the Layer A exemption branch prefix from `v11.0/phase-c/test-endpoint-*` to `v11.0/phase-c/*` so the `v11.0/phase-c/combined` integration branch gets the same audit exemption as the per-unit branches. The self-test harness at `scripts/tests/test-verify-test-gate.sh` stays green at 8/8.
- **R3 — C8/C9 test-code bugs caught by CI.** The first push of the C8 (#247) and C9 (#244) PRs failed `Test R API` in CI:
  - `test-endpoint-backup.R:493/505/519` — the `GET /download/<filename>` handler error branches call `res$serializer <- serializer_json()` to switch from `@serializer octet` to JSON for 4xx responses. `serializer_json()` is a Plumber function only available when Plumber is loaded as a package, not when handlers are extracted as literal function objects into a sandbox env. Fix: stub `serializer_json <- function(...) identity` in `make_backup_sandbox()`.
  - `test-endpoint-review.R:226/294` — the `@post /create` and `@put /update` handlers aggregate service-function statuses through a tibble pipeline (`review_endpoints.R:319-328`, `372-381`) that calls `unique()` **before** `mutate(status = max(status))`. When services return distinct messages (e.g. "OK. Review stored." and "OK. Skipped."), the result list's `status` field is a length-N vector, not a scalar. Fix: `expect_true(all(result$status == 200L))` instead of `expect_equal(result$status, 200)`, plus `expect_equal(res$status, 200L)` for the HTTP-level status.

### Changed

- **Coverage ratchet bumped from 6/4/4/6 to 13/9/12/13** (statements/branches/functions/lines). 11 new spec files pushed the measured coverage from Phase B's floor to `13.22%` statements / `12.49%` branches / `9.68%` functions / `13.66%` lines. The new threshold is pinned at the rounded-DOWN measured floor so the ratchet never flaps if a small future refactor shifts the denominator by a fraction. Per Phase C dispatch brief: the plan's stale 45→55 bump is discarded — the real floor is what `test:coverage` actually produces, with `test-utils/` excluded from the denominator. Inline rationale in `app/vitest.config.ts`.
- **`scripts/verify-test-gate.sh`** — Phase C `test-integration-*.R` rollback audit exemption (see _Fixed_ R2 above) plus a narrow carve-out for `app/src/test-utils/mocks/**/*.spec.ts` on `v11.0/phase-c/*` branches. The `test-utils/mocks` exemption lets B1 smoke-test assertions be updated in lockstep with B1 handler shape fixes (e.g. `handlers.spec.ts:257` reflecting the `reviewByIdOk` array wrap) without the gate rejecting the edit as a pre-existing-spec-file modification. Scope is intentionally narrow so it can't cover up view-spec tautology regressions.

### Internal / dev tooling

- Bumped `app/package.json` and `api/version_spec.json` to `0.11.6`.
- Phase C work was developed across 11 parallel git worktrees (`v11.0/phase-c/*`) off Phase-B-merged master (`3efce3ae`) and combined into a single PR via the `v11.0/phase-c/combined` branch (matches Phase A's `v11.0/phase-a/combined` and Phase B's combined-branch pattern). 15 commits cherry-picked across the 11 units — 8 single-commit view/composable branches, C7's 2-commit read-batch, C8's 3 non-gate commits (with C8's `scripts/verify-test-gate.sh` edit dropped in favor of C7's strict superset), and C9's 2 non-gate commits (same drop rule). The 3-way `scripts/verify-test-gate.sh` conflict flagged by the batch reviewer was resolved by keeping C7's most-permissive exemption as the single source of truth on the combined branch.
- **Checkpoint #2 of 3** — the most important checkpoint in the v11.0 milestone — was executed as a single focused batch review across all 11 PRs via `superpowers:code-reviewer`. The reviewer answered the 5 locked questions from `.planning/_archive/legacy-plans/v11.0/phase-c.md` §7:
  - **Q1 Tautology check:** PASS — all 6 view specs assert on real view behavior (reactive data, composable spies, route pushes, toast spies, computed signals), not on mock return shapes.
  - **Q2 Handshake check:** PASS — all 6 locked `it.todo` strings present verbatim; each is concrete enough for an E-phase rewriting agent to turn into a passing assertion.
  - **Q3 MSW shape sanity:** **FAIL** — 3/3 random-sampled handlers drifted from the real API wire shape. All 3 drifts fixed in R1 above.
  - **Q4 Exit criterion #5 scope lock:** PASS — every route × method in C7 and C8's target files has the required blocks. C9's admin files are covered per the plan's per-file scope rule.
  - **Q5 Default-on rollback:** **FAIL** — C8's rollback audit headers on async and llm-endpoints used prose documentation but the Layer B grep required literal `skip_if_no_test_db()`. Fixed in R2 above.
- The B1 shape drifts that were NOT closed by R1 (they aren't Phase-D-blocking because every affected Phase C spec already has working local workarounds) are scheduled for a reinforcing Phase B worktree before Phase D opens:
  - Add `GET /api/entity` list handler supporting `?filter=equals(entity_id,<id>)` for ModifyEntity + Review view use cases.
  - Add `GET /api/list/status` (`?tree=true`), `/api/list/phenotype`, `/api/list/variation_ontology` handlers.
  - Add `GET /api/re_review/table` handler.
  - Decide per ManageAnnotations aux endpoint (6+ paths) whether to promote C5's per-test `installAuxHandlers()` into B1 or keep them test-local.
- The `scripts/verify-test-gate.sh` REPO_ROOT false-green flagged by C6 (hard-codes `DEFAULT_REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)` which can check `master` instead of the worktree branch when invoked by absolute path) is a known follow-up to be fixed by the reinforcing worktree along with the B1 drifts. Empirically verified: when the script is invoked from the worktree by relative path (which is what every Phase C agent did), SCRIPT_DIR resolves to the worktree's own `scripts/` and the check runs against the correct branch. The false-green is a latent risk only for future scripts that call the gate by absolute path.

### Known limitations

- Same host-env constraint as 0.11.4 and 0.11.5: `make ci-local` still fails at the R lint/test steps on Ubuntu 25.10 "questing" hosts running Conda/miniforge R. Phase C's R endpoint tests were verified via CI on `ubuntu-latest`, which is the authoritative baseline. See the "Host-Env Workaround" section of `CLAUDE.md`.
- The `useTableData.sortDesc` writable-computed vs `ComputedRef<boolean>` type declaration mismatch noted in C11's spec is a future cleanup, not fixed in Phase C (Phase C rule: no source modifications).

### References

- PR: [#237](https://github.com/berntpopp/sysndd/pull/237) — C4 test-view-modify-entity (individual, superseded by combined)
- PR: [#238](https://github.com/berntpopp/sysndd/pull/238) — C2 test-view-review (individual, superseded by combined)
- PR: [#239](https://github.com/berntpopp/sysndd/pull/239) — C5 test-view-manage-annotations (individual, superseded by combined)
- PR: [#240](https://github.com/berntpopp/sysndd/pull/240) — C1 test-view-approve-review (individual, superseded by combined)
- PR: [#241](https://github.com/berntpopp/sysndd/pull/241) — C11 test-composables-table (individual, superseded by combined)
- PR: [#242](https://github.com/berntpopp/sysndd/pull/242) — C6 test-view-manage-user (individual, superseded by combined)
- PR: [#243](https://github.com/berntpopp/sysndd/pull/243) — C10 test-composables-async-form (individual, superseded by combined)
- PR: [#244](https://github.com/berntpopp/sysndd/pull/244) — C9 test-endpoint-admin-batch (individual, superseded by combined)
- PR: [#245](https://github.com/berntpopp/sysndd/pull/245) — C3 test-view-approve-status (individual, superseded by combined)
- PR: [#246](https://github.com/berntpopp/sysndd/pull/246) — C7 test-endpoint-read-batch (individual, superseded by combined)
- PR: [#247](https://github.com/berntpopp/sysndd/pull/247) — C8 test-endpoint-write-batch (individual, superseded by combined)
- Plan: `.planning/_archive/legacy-plans/v11.0/phase-c.md`
- Spec: `.planning/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase C

## [0.11.5] — 2026-04-11

Phase B of the v11.0 test foundation initiative — Tier A test infrastructure that unblocks every Phase C / D / E unit. All 5 units (B1–B5) landed as one combined release. **No runtime code changed**; this is exclusively dev/test infrastructure (MSW handlers, httptest2 fixtures, CI jobs, test helpers, verify-test-gate logic). Patch bump per SemVer.

### Added

- **B1 — MSW handler expansion (app/src/test-utils/mocks/).** The vitest MSW layer now covers every handler in the locked Phase B.B1 table: 38 handlers across 6 view families (Auth, User admin, Review workflow, Status workflow, Entity curation, Annotation jobs). Every handler has a 2xx happy path and at least one 4xx branch distinguishable by request shape, and every handler carries an OpenAPI-path comment above it.
  - New fixture modules under `app/src/test-utils/mocks/data/`: `auth.ts`, `users.ts`, `reviews.ts`, `statuses.ts`, `entities.ts`, `jobs.ts` (split by response family, each under 300 LoC).
  - New smoke spec `app/src/test-utils/mocks/handlers.spec.ts` — 77 assertions, one 2xx and one 4xx case per handler, catches handler drift on first run.
  - New shell script `scripts/verify-msw-against-openapi.sh` — greps every handler path against the real `@get`/`@post`/`@put`/`@delete` annotations in `api/endpoints/*.R` and reports drift. Wired into `make lint-app`.
  - New `scripts/msw-openapi-exceptions.txt` — whitelists 4 entries where the locked spec table points at endpoints that don't exist (yet) on master. Each entry is a spec-bug flag for Phase C to resolve, not a handler bug: `PUT /api/user/delete` (real annotation is `@delete delete`), `PUT /api/review/approve/all` (no bulk route), `PUT /api/status/approve/all` (no bulk route), `GET /api/entity/:sysndd_id` (no bare getter — only sub-path routes). The verify script exits non-zero on any unlisted drift.
- **B2 — real PubMed/PubTator httptest2 fixtures.** Replaced the previously empty `api/tests/testthat/fixtures/{pubmed,pubtator}/` directories with 6 real captures (3 pubmed + 3 pubtator, 32.7 KB total), recorded via a new `make refresh-fixtures` target against the live NCBI eUtils and PubTator3 BioCJSON APIs on 2026-04-11. Captured via `httptest2::save_response(..., simplify = FALSE)` to preserve the full `httr2_response` object; not handcrafted JSON.
  - New helper `api/tests/testthat/helper-fixtures.R` — `skip_if_no_fixtures(subdir)` fails **loudly** on missing/empty fixture directories (both `testthat::fail()` and `stop()`, with an actionable message pointing at `make refresh-fixtures`). `.gitkeep`-only directories are treated as missing. Per spec §4.4 rule 1: the point is to make the silent-skip failure mode impossible to miss.
  - New `api/tests/testthat/fixtures/README.md` — documents every committed fixture with filename, recording date, API version, and exact capture command.
  - New `make refresh-fixtures` target (disjoint section from A7/A4/A6 Makefile edits) — invokes the capture commands against live APIs when explicitly run; **not** invoked from `make ci-local`.
  - `test-external-pubmed.R` and `test-external-pubtator.R` now call `skip_if_no_fixtures()` at the first `test_that()` of each file.
- **B3 — skip-slow-wiring.** Wired `skip_if_not_slow_tests()` (previously defined in `helper-skip.R` but never called) into 22 `test_that()` blocks across 4 audited files that actually hit Mailpit or live external APIs: `test-integration-email.R` (5 blocks), `test-external-pubtator.R` (3), `test-e2e-user-lifecycle.R` (11), `test-external-pubmed.R` (3). The other 4 files flagged by the audit grep (`test-unit-publication-functions.R`, `test-unit-pubtator-parse.R`, `test-unit-genereviews-functions.R`, `test-unit-pubtator-functions.R`) were classified MOCK — they contain the search terms only in comments, string assertions, or mocked bindings — and left untouched.
  - New `slow-tests-nightly` CI job in `.github/workflows/ci.yml` — cron `0 3 * * *` plus `workflow_dispatch`, runs `RUN_SLOW_TESTS=true make test-api-full` with MySQL + Mailpit service containers. Correctly skipped on normal PR runs (verified: the pull_request run's `Slow Tests (nightly)` resolves to `skipping` while `Test R API` runs green in ~23 min without Mailpit). Bannered as `# ===== Phase B B3: slow-tests-nightly =====` to make the combined-merge with B4's `smoke-test` job trivial.
- **B4 — CI smoke test + real verify-test-gate.sh.** New `smoke-test` CI job in `.github/workflows/ci.yml` (triggered on `push` and `pull_request`) runs `scripts/ci-smoke.sh` which wraps `make preflight` plus a `curl -f` retry loop against `/api/health/ready`. Bannered as `# ===== Phase B B4: smoke-test =====` (disjoint from B3's nightly block). `ci-success` gates on `smoke-test` (but not `slow-tests-nightly`, which is schedule-only).
  - New `scripts/ci-smoke.sh` — boots the full prod stack via `make preflight` and verifies readiness.
  - Replaced the A6 `scripts/verify-test-gate.sh` stub (2-line echo) with 121 lines of real logic. Protects Phase D / Phase E PRs from silently mutating pre-existing test files to "pin" them to whatever the refactor produced. Rule summary: new `*.spec.ts` / `test-*.R` files are allowed; modifications to pre-existing spec/test files are rejected **unless** one of two branch-gated exemptions applies — (a) adding `skip_if_not_slow_tests()` on `v11.0/phase-b/*` only (for B3), or (b) replacing `Sys.sleep(N)` with `wait_for(..., timeout = N)` on `v11.0/phase-b/*` only (for B5). `--extended` mode also greps every `api/tests/testthat/test-integration-*.R` file and asserts it opens with `with_test_db_transaction` or a documented `skip_if_no_test_db()` exemption.
  - New bash unit-test harness `scripts/tests/test-verify-test-gate.sh` — 7 cases (new-spec-allowed, pre-existing-spec-rejected, phase-b skip exemption allowed, phase-b wait_for exemption allowed, phase-b exemption does NOT leak into phase-d, extended-mode rejects integration test missing rollback, extended-mode accepts well-formed repo). All 7 cases pass.
  - New `make verify-gate` target wires the harness into CI without an R dependency.
- **B5 — Sys.sleep eviction.** Evicted every real `Sys.sleep(N)` from the R test suite (4 call sites in `test-e2e-user-lifecycle.R` at lines 181/215/323/539, 1 in `helper-mailpit.R` at line 116 — the other `Sys.sleep` occurrences in `test-unit-*.R` are `mockery::stub` bindings or `test-publication-refresh.R` comments and were correctly left untouched).
  - New helper `api/tests/testthat/helper-wait.R` (297 lines) — defines `wait_for(condition, timeout, label)` (event-based polling, fails loudly on timeout with a diagnostic including last observed state) and a sibling `wait_stable(probe, duration, label)` for the negative-assertion case ("no change should occur for N seconds"; fails immediately on any change, strictly faster than a fixed sleep + single check on failure).
  - `helper-mailpit.R::mailpit_wait_for_message` refactored to delegate to `wait_for()` — no more internal `Sys.sleep` polling.
  - The 4 e2e call sites were all "no email should arrive" negative assertions, now using `wait_stable(mailpit_message_count, N)` with a baseline captured just before the action. The `wait_stable` approach fails immediately on any unexpected email rather than waiting the full sleep window.
  - 10-iteration flake check passed 10/10 in the prod sysndd-api Docker container (helper-wait self-tests: 10/10, 190/190 assertions; test-e2e-user-lifecycle.R load + dispatch: 10/10, all 11 `test_that` blocks reach `skip_if_no_mailpit()`/`skip_if_no_api()` cleanly).

### Changed

- `app/vitest.setup.ts` — MSW `onUnhandledRequest` flipped from `'warn'` to `'error'`. Every unmocked request now hard-fails the test, making any handler gap impossible to miss. Acceptance criterion: no pre-existing vitest was left failing because of this switch (full suite of 321 tests still green on the combined branch).
- `app/vitest.config.ts` — coverage thresholds pinned at the current measured floor (`lines: 6`, `functions: 4`, `branches: 4`, `statements: 6`). B1 originally "bumped 40 → 45" but the actual coverage is only 4–7% because `test-utils/` is excluded from the coverage denominator — the original 40 threshold was decorative since no CI job runs `npm run test:coverage`. Thresholds now form a ratchet that future phases must raise as specs land; see the inline comment in `app/vitest.config.ts` for the rule and rationale.

### Internal / dev tooling

- Bumped `app/package.json` and `api/version_spec.json` to `0.11.5`.
- Phase B work was developed across 5 parallel git worktrees (`v11.0/phase-b/*`) off Phase-A-merged master (`db18cb51`) and combined into a single PR for review, following the Phase A pattern. B5 merged first on the test-file conflicts (per the tiebreaker rule); B3 and B4's disjoint `ci.yml` job blocks merged cleanly with both banners intact; `ci-success.needs` correctly unions to include `smoke-test` (PR-gating) but not `slow-tests-nightly` (schedule-only).
- End-to-end verification on the combined branch was done via a Playwright monkey-walk against the full dev stack (traefik + api + app + mysql + mailpit) bound to the combined worktree. Walked 13 routes including unauth public views (Genes, Entities, Phenotypes, Panels, PublicationsNDD, Gene detail, About), the post-A1 `POST /api/auth/authenticate` login flow end-to-end against the live API (not a mock), and 4 authed views covering B1's mocked handler families (`/`, `/ManageUser`, `/ManageAnnotations`, `/ApproveReview`, `/ApproveStatus`). Zero Phase-B-introduced regressions; the only console errors encountered were (a) the expected 401 on `/api/auth/signin` for unauthenticated visitors and (b) two pre-existing 404s on `/api/external/{mgi,rgd}/phenotypes/A2ML1` that reflect a data gap in the upstream MGI/RGD records, unrelated to Phase B.
- Per-endpoint sanity-check (§7 of `.planning/_archive/legacy-plans/v11.0/phase-b.md`): curled 4 handler-table endpoints against the live API on the combined worktree and confirmed B1's mock shapes are faithful — `GET /api/status/1` returns a full status record matching the mock shape; `POST /api/auth/authenticate` with bad creds returns HTTP 400 with the documented "Please provide valid username and password." body (matches B1's 4xx branch); `GET /api/user/role_list` and `GET /api/jobs/history` return 403 without a JWT (consistent with the `require_auth` middleware behaviour B1 assumes).

### Post-review fixes on PR #236

The first push of this PR surfaced six actionable items from the automated Copilot review plus one CI failure (smoke-test could not build) plus one misconfigured gate (vitest coverage thresholds). All are fixed in the final combined branch before merge — commit `chore(phase-b/combined): fix Copilot review + codecov + CI smoke-test`:

- **Copilot #1 — Makefile `.PHONY` gap.** `verify-gate` added to the `.PHONY` declaration so a stray file of that name cannot shadow the target.
- **Copilot #2 — `%||%` in `api/scripts/capture-external-fixtures.R`.** Replaced the rlang-only operator with a base-R fallback that resolves the script path via `sys.frame(1)$ofile`, then `commandArgs(trailingOnly = FALSE)` `--file=`, then `"."`. The script no longer has an implicit rlang dependency.
- **Copilot #3 — `helper-wait.R::is_truthy` was too permissive.** The old `is.atomic(v) -> TRUE` branch would return early on `0`, `NA`, `""`, `FALSE`, defeating the "wait until ready" semantics for any probe that uses a count-or-zero sentinel. Tightened to treat only `isTRUE()` logicals, non-empty lists, and non-empty data frames as truthy. A new 14-assertion test case (`wait_for does NOT treat atomic 0/NA/empty-string as truthy`) plus a 4-assertion test for non-empty list/data.frame pin the new semantics — verified 9/9 blocks / 35/35 assertions green in the sysndd-api prod container.
- **Copilot #4 — Bash 4+ in `verify-msw-against-openapi.sh`.** The associative array (`declare -A`) is replaced with a portable indexed array + `is_exception()` lookup so the script runs on Bash 3.2 — the version still shipped as `/bin/bash` on macOS. A defensive `BASH_VERSINFO` check surfaces a friendly error on anything older.
- **Copilot #5 — CI smoke-test failure.** The first PR-236 push made the smoke-test CI job fail at the Docker build step (`"/config.yml": not found`) because `api/config.yml` is gitignored on dev machines but the prod Dockerfile does `COPY config.yml config.yml`. Fix: committed `api/config.yml.example` with CI-safe dummy values (structurally identical to the real config, credentials aligned with `.env.example`'s placeholders so the dummy API container can actually reach the dummy MySQL user) and extended `scripts/ci-smoke.sh` with a `seed_from_template` step that copies `api/config.yml.example → api/config.yml` and `.env.example → .env` when either is missing. Idempotent — it does not overwrite real dev secrets.
- **Copilot #6 — `verify-test-gate.sh` Sys.sleep exemption was too permissive.** The old exemption accepted any diff on a `v11.0/phase-b/*` branch as long as it contained at least one removed `Sys.sleep(` line and one added `wait_for(...)` line — unrelated line changes could slip through. Tightened to a whitelist: every added/removed non-blank, non-comment line must match a narrow set of tokens (`wait_for(`, `wait_stable(`, named kwargs, closing paren, mailpit probe helpers, baseline assignments). A new harness case (`phase-b exemption rejects unrelated edits paired with Sys.sleep->wait_for`) pins the tightened behaviour; all 8 harness cases now pass.
- **Codecov / vitest coverage thresholds — pinned at realistic floor.** See `Changed` above.
- **Self-review S1 — `ERROR_SENTINELS` constants block.** Added a typed const export at the top of `app/src/test-utils/mocks/handlers.ts` documenting the path-param / query / header sentinels that trigger 4xx branches. Existing handlers and specs keep their literals for now; future handlers/specs should import from `ERROR_SENTINELS` so the contract is discoverable.

### Known limitations

- Same host-env constraint as 0.11.4: `make ci-local` still fails at the R lint/test steps on Ubuntu 25.10 "questing" hosts running Conda/miniforge R. Phase B's entire R test verification was done via the `sysndd-api` Docker container or deferred to CI on `ubuntu-latest`, which is the authoritative baseline. See the "Host-Env Workaround" section of `CLAUDE.md` for the details.
- `B1` flagged 4 drifts where the locked handler table points at endpoints that do not exist on master (whitelisted in `scripts/msw-openapi-exceptions.txt`). These are spec bugs for Phase C to resolve, not handler bugs — either the handler table needs updating or the missing endpoints need to be added in Phase C / D when the views actually consume them. See `scripts/msw-openapi-exceptions.txt` for the full list with rationale.

### References

- PR: [#230](https://github.com/berntpopp/sysndd/pull/230) — B3 skip-slow-wiring (individual, superseded by combined)
- PR: [#231](https://github.com/berntpopp/sysndd/pull/231) — B4 ci-smoke-test (individual, superseded by combined)
- PR: [#232](https://github.com/berntpopp/sysndd/pull/232) — B2 pubmed-pubtator-fixtures (individual, superseded by combined)
- PR: [#233](https://github.com/berntpopp/sysndd/pull/233) — B5 sys-sleep-eviction (individual, superseded by combined)
- PR: [#234](https://github.com/berntpopp/sysndd/pull/234) — B1 msw-handler-expansion (individual, superseded by combined)
- Plan: `.planning/_archive/legacy-plans/v11.0/phase-b.md`
- Spec: `.planning/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase B

## [0.11.4] — 2026-04-11

Phase A of the v11.0 test foundation initiative. A1–A7 plus a focused follow-up, landed as one release.

### ⚠️ Upgrade notes — long-lived deployments must read this

On the **first API boot** after deploying this version against a database that was previously running `0.11.3` or earlier, the migration runner emits exactly one INFO log line:

```
[INFO] reconcile_schema_version_renames: rewriting schema_version.filename '008_hgnc_symbol_lookup.sql' -> '018_hgnc_symbol_lookup.sql'
```

This is the new `reconcile_schema_version_renames()` step in `api/functions/migration-runner.R` reconciling the filename rename introduced by **A4** (see _Changed_ below). It runs **before** the pending-migration diff, so the renamed migration is not re-executed.

- **No manual DML is required.** The reconciliation is idempotent: it is a no-op on every subsequent boot and on any fresh database where `008_hgnc_symbol_lookup.sql` was never recorded.
- **What would have happened without it:** `migration-runner.R`'s `setdiff(migration_files, applied)` would have seen `018_hgnc_symbol_lookup.sql` as pending and re-executed it. `CREATE TABLE IF NOT EXISTS` is safe, but the three `INSERT INTO hgnc_symbol_lookup` statements are **not** idempotent and would have duplicated rows.
- **Sanity check (optional but recommended):** `SELECT COUNT(*) FROM hgnc_symbol_lookup;` before and after the deploy — the counts should match exactly. A mismatch means the reconciliation failed and the migration was re-executed. Roll back and investigate.
- **Fail-fast behavior:** if the reconciliation hits a genuine DB error (broken connection, locked `schema_version`, etc.), API startup **aborts loudly** rather than silently proceeding into the main migration loop with an unreconciled state. This is the Risk 5 mitigation agreed during Copilot review — see the module-level doc comment on `MIGRATION_RENAMES` in `api/functions/migration-runner.R`.

_Context: Phase A.A4 resolves a duplicate `008_` migration prefix by renaming `008_hgnc_symbol_lookup.sql` → `018_hgnc_symbol_lookup.sql`. On any deployment that had the old file recorded in `schema_version`, the filename tracker is now stale. The reconciliation is what makes this deployment-safe. See `.planning/_archive/legacy-plans/v11.0/phase-a.md` §3 A4 for the full rationale._

### Security

- **A1 (P0 hotfix):** Moved login and password-change credentials out of URL query strings. The previous `GET /api/auth/authenticate?user_name=…&password=…` and `PUT /api/user/password/update?…` shapes leaked secrets into access logs, Traefik logs, and browser history.
  - **New:** `POST /api/auth/authenticate` with `Content-Type: application/json` and body `{"user_name":"…","password":"…"}`.
  - **New:** `PUT /api/user/password/update` accepts a JSON body for the password fields. Handler is dual-mode: the legacy query-string form still works as a transitional fallback and will be removed in a later release (tracked as Phase E.E7 in the v11.0 plan).
  - **Deprecated (still functional in 0.11.4):** `GET /api/auth/authenticate`. Will be removed alongside the dual-mode password handler in Phase E.E7.
  - `app/src/views/LoginView.vue` and `app/src/views/UserView.vue` switched to the new POST/PUT shapes.
  - Middleware `AUTH_ALLOWLIST` updated to include `/api/auth/authenticate` so the new `@post` handler is reachable through the `require_auth` filter (the legacy `@get` only worked because unauthenticated `GET` requests are forwarded by default). This was caught by end-to-end Playwright testing after the subagent's host-side curl tests missed the interaction with the full Traefik + filter stack.

### Fixed

- **A2:** `/api/gene/:symbol` no longer corrupts the `gnomad_constraints` JSON blob by pipe-splitting it. The repository's `across(...)` call now excludes `gnomad_constraints` from `str_split_fn` using `-any_of("gnomad_constraints")` (schema-tolerant form). The frontend no longer carries the `[0]` dereference workaround in `GeneView.vue`; `app/src/types/gene.ts` now types the field as `string | null` with a JSDoc explanation of why this one field is the scalar exception.

### Added

- **A7 (already on master, merged in #220, released as part of 0.11.4):** One-command developer bootstrap.
  - `make install-dev` — idempotent aggregate bootstrap for R (via `renv::restore()`) and frontend (via `npm install`).
  - `make doctor` — environment verifier: Docker reachability (soft check), git ≥ 2.5, Node major matches `app/.nvmrc`, R callable, dev packages importable (`lintr`, `styler`, `testthat`, `covr`, `httptest2`, `callr`, `mockery`). Exit 0 on healthy; exit 1 with a specific diagnostic on any failure.
  - `make worktree-setup NAME=<scope>/<unit>` — parameterized worktree creation. Creates `worktrees/<scope>/<unit>` on branch `v11.0/<scope>/<unit>` from master, with `mkdir -p` for the parent directory so nested paths work on a clean clone.
  - `app/.nvmrc` pins the Node major to match `.github/workflows/ci.yml` (currently Node 24).
  - Human-facing `docs/DEVELOPMENT.md` (counterpart to the agent-facing `CLAUDE.md`): six sections covering requirements, quickstart, daily workflow, parallel worktree workflow, common gotchas, and getting help.
  - Root `CONTRIBUTING.md` with a minimal TL;DR and a link to `docs/DEVELOPMENT.md`.
  - `api/renv.lock` additions for the 7 declared dev packages (verified via a `rocker/r-ver:4.5` Docker sidecar because the development host runs Conda R on Ubuntu 25.10 "questing", which Posit PPM does not support yet).
  - New CI job `make doctor (ubuntu-latest)` on every PR that touches relevant paths. macOS was tried via colima + homebrew R but hit pre-existing Bioconductor lockfile rot and toolchain issues unrelated to A7 and was removed from the matrix; see the comment header on the `make-doctor` job in `.github/workflows/ci.yml` for the full rationale.
- **A3:** `db/migrations/README.md` rewritten to document the actual runner behavior — advisory lock with 30s timeout, fast-path skip, numbered-prefix convention, forward-only rollback policy, and a cross-reference to the Phase B.B4 CI smoke test.
- **A4:** `scripts/check-migration-prefixes.sh` — POSIX shell script that asserts unique `NNN_` migration prefixes across `db/migrations/*.sql`. Wired into `make lint-api`; fails CI on any future collision with a clear diagnostic listing the conflicting files.
- **A6:** `make worktree-prune` target — `git worktree prune -v` + `git worktree list`, safe as a no-op on clean master. `scripts/verify-test-gate.sh` stub (Phase B.B4 will fill in the real test-gate logic).
- **Follow-up:** `reconcile_schema_version_renames()` in `api/functions/migration-runner.R` with an internal `MIGRATION_RENAMES` map documenting historical renames (currently the A4 008→018 entry). Runs before the pending-migration diff in `run_migrations()`. Fail-fast on DB errors (no silent skip) per Copilot review. 7 `mockery::stub`-based unit tests in `api/tests/testthat/test-unit-migration-runner.R` lock in each state branch: rewrite, idempotent (new-already-present), dedup (both-present), fresh DB, premature-rename (new file not yet on disk), SELECT-error propagation, UPDATE-error propagation.
- **A1 (tests):** New `api/tests/testthat/test-endpoint-auth.R` — structural regex assertions and behavior tests for the new POST/PUT handlers. Uses `parse()` + source-ref extraction instead of `plumber::pr()` because plumber 1.3.2's internal route layout did not match the initial walker; the parse-based form is more portable and runs without plumber installed at test time.

### Changed

- **A4:** `db/migrations/008_hgnc_symbol_lookup.sql` renamed to `db/migrations/018_hgnc_symbol_lookup.sql`. File content unchanged; the rename resolves the duplicate-prefix issue flagged in the 2026-04-11 codebase review §2. **See Upgrade notes above** for deploy-time behavior on long-lived databases.

### Removed

- **A5:** Empty `api/repository/` directory (archaeological debris from an incomplete refactor; `api/functions/legacy-wrappers.R` already covers the repository-layer semantics). No live R code under `api/endpoints`, `api/functions`, `api/core`, `api/services`, or `api/start_sysndd_api.R` references this directory.
- **Follow-up:** Two `api/repository` references in `docker-compose.yml` — the volume bind-mount (line 144) and the `develop.watch` sync rule (line ~196). Without this removal, `docker compose up` and `docker compose watch` would have recreated the empty host-side directory on every invocation, reintroducing the exact state A5 was meant to eliminate.

### Internal / dev tooling

- Bumped `app/package.json` and `api/version_spec.json` to `0.11.4`.
- Tests for the new reconciliation function run entirely offline (`mockery::stub` covers all `DBI::dbGetQuery` / `DBI::dbExecute` call sites).
- The Phase A work was developed across 7 parallel git worktrees (`v11.0/phase-a/*`) and combined into a single PR (#228) for review. All historical branches have been deleted. The v11.0 plan files under `.planning/_archive/legacy-plans/v11.0/` describe the parallel-worktree workflow and the intra-phase ownership rules.

### Known limitations

- `make ci-local` still fails at the lint step on Ubuntu 25.10 "questing" hosts running Conda/miniforge R because Posit Package Manager does not yet publish a `__linux__/questing/` binary repo and Conda R's `ld` cannot link zlib from source tarballs. Workarounds are documented in the agent-facing `CLAUDE.md` (gitignored, local memory). CI on `ubuntu-latest` is the authoritative baseline.
- The A1 POST handler returns HTTP 500 on a malformed JSON body (e.g. non-JSON text with `Content-Type: application/json`) instead of a clean 400. This is plumber's upstream JSON parser dying before the handler's own validation runs. Not a Phase A regression — the prior `@get` form simply never had this code path. Will be addressed in Phase E.E7 when the auth consolidation lands and the dual-mode handler is removed.
- The A4 prefix check script is wired into `make lint-api`, but GitHub Actions' `changes` filter skips the `lint-api` job on PRs that don't touch `api/**`. This means a PR that only touches `db/migrations/` might not exercise the prefix check in CI. Phase B.B4's verify-test-gate will close this gap; until then, the script runs locally on every `make lint-api` invocation.

### References

- PR: [#228](https://github.com/berntpopp/sysndd/pull/228) — combined Phase A (A1–A6 + follow-up + version bump, 22 commits)
- PR: [#220](https://github.com/berntpopp/sysndd/pull/220) — Phase A.A7 dev-environment bootstrap (merged first, 10 commits)
- Plan: `.planning/_archive/legacy-plans/v11.0/phase-a.md`
- Spec: `.planning/superpowers/specs/2026-04-11-v11.0-test-foundation-design.md` §3 Phase A, §4.8 local developer environment
- Review: `.planning/reviews/2026-04-11-codebase-review.md` §2 (duplicate prefix), §3 (empty repository)
- Follow-up todo: `.planning/todos/pending/refresh-stale-bioconductor-pins-in-renv-lock.md` (pre-existing lockfile rot surfaced by A7's CI matrix; deferred)

## [0.11.3] — 2026-04-09

- Dependency security updates (bulk bump of production-minor-patch group).
- Dev server fix: allow Docker proxy hosts in Vite 7 + Traefik routing.

## Earlier versions

Earlier history is available via `git log --grep="bump version"` on `master`. This CHANGELOG starts documenting the project at 0.11.3.

[Unreleased]: https://github.com/berntpopp/sysndd/compare/v0.16.2...HEAD
[0.16.2]: https://github.com/berntpopp/sysndd/compare/v0.16.1...v0.16.2
[0.16.1]: https://github.com/berntpopp/sysndd/compare/v0.16.0...v0.16.1
[0.11.14]: https://github.com/berntpopp/sysndd/compare/v0.11.13...v0.11.14
[0.11.13]: https://github.com/berntpopp/sysndd/compare/v0.11.12...v0.11.13
[0.11.6]: https://github.com/berntpopp/sysndd/compare/v0.11.5...v0.11.6
[0.11.5]: https://github.com/berntpopp/sysndd/compare/v0.11.4...v0.11.5
[0.11.4]: https://github.com/berntpopp/sysndd/compare/v0.11.3...v0.11.4
[0.11.3]: https://github.com/berntpopp/sysndd/releases/tag/v0.11.3
