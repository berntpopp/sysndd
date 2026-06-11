# Changelog

All notable changes to SysNDD are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (loosely, in the `0.x` line — additive changes land as patch bumps while the public API still stabilises).

## [Unreleased]

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
