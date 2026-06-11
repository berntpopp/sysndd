# AGENTS.md

This is the canonical agent-facing instruction file for this repository. SysNDD is a neurodevelopmental disorder gene-disease database with three main code trees:

- `api/` — R/Plumber REST API with `renv`
- `app/` — Vue 3 + TypeScript SPA built with Vite
- `db/` — MySQL schema, data-prep scripts, and versioned migrations

## Code Organization

- Write modular, focused code with one clear responsibility per file or module, so humans and LLM agents can read, test, and edit it in a single context.
- Keep handwritten source files under 600 lines when practical. Treat this as a soft ceiling: if a file approaches it, extract cohesive helpers, components, composables, or services before adding more behavior.
- Do not split code mechanically. Tests, migrations, generated files, snapshots, fixtures, and tightly coupled implementations may exceed 600 lines when splitting would reduce clarity.

## Code Quality

- Start from nearby patterns and existing helpers before adding new abstractions, dependencies, or cross-layer shortcuts.
- Pair behavior changes with targeted tests or deterministic checks. Run the smallest useful check first, then `make pre-commit` or `make ci-local` when the scope warrants it.
- When touching files already over the 600-line soft ceiling, avoid making them larger by default. Extract cohesive code from the area being changed, but leave broad legacy splits for planned refactors. `make code-quality-audit` enforces this as a fast file-size ratchet.
- Frontend API access should go through typed clients in `app/src/api/*`; do not add raw axios calls in views/components or direct `localStorage.token` / `localStorage.user` access.
- API integration tests that write database state should use `with_test_db_transaction()` or document why rollback is not possible.
- Use `.agents/skills/sysndd-code-quality/SKILL.md` for maintainability, modularity, file-size, DRY/KISS/SOLID, and anti-pattern review passes.

## Verify Before Handoff

- Fast deterministic code-quality audit: `make code-quality-audit`
- Full-repo check: `make ci-local`
- Fast pre-push check: `make pre-commit`
- Full dev stack: `make dev`
- DB-only stack: `make docker-dev-db`
- API tests: `make test-api`
- Fast API PR gate: `make test-api-fast`
- API lint: `make lint-api`
- Frontend lint: `make lint-app`
- Frontend type-check: `cd app && npm run type-check`
- Frontend strict-scope type-check: `cd app && npm run type-check:strict`
- Frontend unit tests: `cd app && npm run test:unit`
- Frontend SEO prerender gate: `make verify-seo-app`
- Frontend E2E (Playwright, **local-only**): `make playwright-stack && cd app && npx playwright test && cd .. && make playwright-stack-down`. The isolated stack serves the app/API at `http://localhost:8088` by default, and `app/playwright.config.ts` uses that default when `PLAYWRIGHT_BASE_URL` is unset. There is no Playwright CI workflow — the spec files in `app/tests/e2e/` exist for ad-hoc local regression checks. The official lane (lint, type-check, vitest, R API, smoke) is the automated coverage.

Single-test shortcuts:

```bash
# R — single file (host)
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-entity-creation.R')"

# R — single file (inside the running container; tests/ is NOT bind-mounted)
docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-xyz.R')"

# Frontend — single spec or test name
cd app && npx vitest run src/components/AppFooter.spec.ts
cd app && npx vitest run -t "match name pattern"
```

## Architecture Invariants

### API bootstrap and source order

`api/start_sysndd_api.R` sources the runtime into the global environment. Source order matters:

1. `functions/*` and repository helpers
2. `core/*`
3. `services/*`
4. `endpoints/*`

Service functions must keep their `svc_` or `service_` prefixes. If a service function drops that prefix and collides with a repository function name, it can silently shadow the repository implementation in the global environment.

### Background jobs

Async jobs are durable and MySQL-backed. The web API submits jobs and serves status/history; the separate worker service claims and executes them. Worker-executed code is sourced once when the worker starts. If you change worker-executed code, restart the worker container before assuming the change is live.

The worker must have outbound network egress for external providers used inside jobs, including Gemini, PubMed, and PubTator. Keep it attached to both the internal `backend` network for database access and the egress-capable `proxy` network; attaching it only to `backend` breaks DNS/API calls because `backend` is `internal: true`.

GeneNetworks display layouts are derived analysis artifacts. To preserve the current fCoSE compound-graph representation without browser main-thread stalls, workers precompute Cytoscape/fCoSE positions for the exact displayed network and the frontend renders them with Cytoscape `preset`. Public API requests must not run fCoSE synchronously; missing artifacts fall back to browser fCoSE. Keep layout cache keys data-aware: include displayed node/edge set, `cluster_type`, `min_confidence`, `max_edges`, layout options, and Cytoscape/fCoSE versions.

Public analysis endpoints read durable public-ready snapshots from `analysis_snapshot_*` tables. Supported parameter presets are fixed in `analysis-snapshot-presets.R` until a worker/admin refresh precomputes more; unsupported parameters fail fast as `unsupported_parameter`, while supported presets without an active current public-ready row report snapshot diagnostics such as `snapshot_missing`, `snapshot_stale`, or `source_version_mismatch`. Snapshot refresh jobs must use approved-public input gates only, and activation is scoped by exactly one public-ready row per `(analysis_type, parameter_hash)`. MCP analysis reads the same public-ready snapshots only; it must not compute heavy analysis, fCoSE layouts, external calls, or Gemini/LLM summaries on miss.

### NDDScore prediction layer

NDDScore lives in the four `nddscore_*` tables and three current-release views added by migration `023_add_nddscore_prediction_release.sql`. It is a model-derived prediction layer, separate from curated SysNDD evidence. It must never be represented as a curation status or as changing curated SysNDD classifications; use copy such as `ML prediction`, `Model-derived`, `Prediction layer`, `Separate from curated SysNDD evidence`, and `Not an evidence tier`.

NDDScore imports run through the durable `nddscore_import` System B async job registered in `async_job_handler_registry`. The worker executes the job and needs outbound egress for Zenodo. Imports are serialized with the `nddscore_import` MySQL advisory lock, and activation switches atomically through the generated-column unique key on `active_release_slot`; a currently active release cannot be re-imported as active. The upstream `nddscore_release.json` `is_active` value is ignored because active release state is SysNDD-controlled.

The default NDDScore Zenodo source is deployment-configurable. Prefer `NDDSCORE_ZENODO_RECORD_ID` and `NDDSCORE_ZENODO_API_BASE_URL` in the deployed `.env`; `api/config.yml` carries the same defaults for local/test fallback. Do not reintroduce independent frontend defaults for the record ID.

### Read-only MCP sidecar

`api/start_sysndd_mcp.R` runs the MCP server as a separate sidecar/process, not inside Plumber. The Phase 0 spike proved `mcptools` HTTP initialize -> `tools/list` -> `tools/call`, `GET 405`, no required session header, and JSON-serialized text output; v1 tools should keep stable JSON text with `schema_version` as the compatibility contract. The sidecar also patches `mcptools` to advertise output schemas, read-only tool annotations, static schema resources, and tool-visible recoverable errors. MCP prompts are disabled by default because agentic clients such as Claude Code surface them as user-invoked slash commands, not automatically discovered LLM workflows; enable them explicitly with `MCP_ENABLE_PROMPTS=true` only when slash-command prompts are wanted.

The MCP container healthcheck must stay cheap and data-independent: use `api/scripts/mcp-healthcheck.R` for `initialize` + `tools/list` liveness only. Keep `api/scripts/mcp-smoke.R` as the heavier developer/CI verification probe because it exercises real tools and approved public DB content.

MCP analysis cache access is read-only. The sidecar binds the same memoised wrapper names as the API and mounts `api_cache` read-only so it can inspect and read already-warmed derived-analysis cache entries. It must not initialize cache versions, clear cache files, compute STRING/phenotype clusters, or write cache entries; API endpoints or worker/admin jobs remain responsible for prewarming derived analysis data.

Phenotype correlations served through MCP are cache-hit-only; MCP must not call `generate_phenotype_correlations()` directly on a cache miss.

MCP v1 is private/internal by default in Compose. Do not expose public unauthenticated `/mcp`; any route must be private or static-bearer protected at the proxy/service boundary.

The frontend owns a public `/mcp` information page for browser `GET text/html` requests. In development, Vite may proxy MCP protocol traffic on the same path to the sidecar; browser navigation must continue to render the information page. In production, only add a real `/mcp` transport route when it is protected and method/header-scoped so normal browser visits still reach the informational page.

MCP client ergonomics are part of the contract. Keep initialize instructions SysNDD-specific but concise, with the gene -> entity -> publication workflow, the entity model, deferred-tool loading guidance, cheap-path payload controls, resource semantics, and read-only constraints. `MCP_SCHEMA_VERSION` is `1.2`. `get_sysndd_capabilities` is the longer in-band guide for workflows, limits, payload modes, citation rules, resources, prompt opt-in status, errors, and v1 exclusions. Keep `resources/list` / `resources/read` aligned with distinct `sysndd://schema/overview` and `sysndd://schema/tool-guide` content; record-like `sysndd://gene`, `sysndd://entity`, and `sysndd://publication` URIs are stable identifiers, not v1 parameterized resources. Publication outputs are citation-friendly (`recommended_citation`), expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `unverified`) sourced from the `publication.publication_date_source` column, distinguish that date from `sysndd_curation_date`, expose `abstract_available` when abstract text is requested or metadata mode is selected, and omit `abstract_excerpt` unless `abstract_mode = "excerpt"`. `recommended_citation` omits the year when the date is unverified. Historical rows remain unverified until the one-off PubMed backfill is applied.

MCP 1.2 analysis tools expose only the analysis catalog, gene research context, NDDScore context, curation comparison context, phenotype analysis context, and gene network context. All analysis payloads must label their data class as `curated_sysndd_evidence`, `curated_derived_analysis`, `ml_prediction`, `llm_generated_summary`, `external_reference_identifier`, or `operational_metadata`. NDDScore is always an ML prediction layer, separate from curated SysNDD evidence, not an evidence tier, and must not alter curated classifications. LLM summaries exposed through MCP are current, validated, admin-generated cache reads only; MCP must not expose LLM prompts/queries or trigger Gemini/LLM generation. MCP must not call live external gene providers; stored external IDs may be shown only as `external_reference_identifier`. Large analysis tools default to `response_mode = "compact"` and `max_response_chars = "auto"`, expose `budget` metadata with `dropped_summary`, support `dry_run`/`diagnostics` where broad results are possible, and guide clients through the low-token path: catalog first, gene research dry-run/compact second, focused follow-up tools third.

Recoverable MCP validation failures should return a JSON tool result with `schema_version`, `error.code`, and `isError = true`, not raw R errors or JSON-RPC `-32603`. Do not keep hidden parameter aliases; clients should use the advertised schema. Include short examples and boolean defaults in tool descriptions, default `get_gene_context(include_comparisons = false)` for the cheap path, use `response_mode = "minimal"` for structure-first retrieval, use `get_gene_context(expand = "entities")` for one-call gene detail when the caller opts into it, cap that detailed expansion at the 20-ID batch limit, and use `get_genes_context`, `get_entities_context(dedupe_publications = true)` / `get_publications_context` to avoid avoidable fan-out and duplicate abstracts. Entity phenotypes are compacted as modifier-keyed HPO ID arrays, and batch payloads should keep `schema_version` only at the outer envelope.

MCP tools and prompts are strictly read-only and limited to approved public data. They must not write to the DB, call write routes, execute raw SQL/R, call Gemini/LLM generation, call live external providers, or expose draft reviews, re-review workflows, admin/user/log/job data, curation comments, or broad export payloads. Enforce approved public data in repository queries: active records from `ndd_entity_view`, and review-derived synopsis/phenotype/variation/publication data only from primary approved reviews (`is_primary = 1` and `review_approved = 1`).

### Migrations

`db/migrations/*.sql` are applied at API startup by the migration runner using MySQL advisory locks. Migration failures are supposed to crash startup. Do not work around a failing migration by weakening startup checks.

Startup validates the migration manifest before the fast path. In non-test startup the directory must exist, contain SQL files, have `EXPECTED_LATEST_MIGRATION` as the actual sorted latest migration, and meet the expected minimum file count. Missing, empty, or stale mounts are fatal and should be fixed at packaging/deployment time.

### Container mount boundary

In the dev/prod containers, source directories such as `api/functions`, `api/services`, `api/endpoints`, and `db/migrations` are bind-mounted live. `api/tests/` is not bind-mounted. To run tests inside the running API container, copy them in or rebuild.

The API image must not bake real `api/config.yml` into image layers. Provide runtime configuration through the Compose read-only mount, an operator secret, or an equivalent deployment-specific config injection mechanism; do not re-add `COPY config.yml config.yml` to `api/Dockerfile`.

### Public SEO prerendering

Public SEO pages are generated by the frontend prerender pipeline. If public route content, canonical URL policy, sitemap behavior, or SEO payload endpoints change, run `make verify-seo-app` and update `documentation/08-development.qmd` / `documentation/09-deployment.qmd`.

## Stack-Specific Gotchas

- Namespace `dplyr::select(...)` and similar verbs explicitly in API code. Several loaded packages mask them.
- Use `inherits(x, "Date")`, not `is.Date(x)`, in library-light contexts.
- Plumber may return JSON scalars as arrays. Frontend callers should unwrap values before feeding them back into axios params.
- Plumber does not propagate a router's error handler to mounted sub-routers. Every endpoint file is mounted as its own sub-router in `api/bootstrap/mount_endpoints.R`, so each must be wrapped with the `mount_endpoint()` helper (which attaches the RFC 9457 `errorHandler` from `api/core/filters.R`). Without it, a thrown classed error (e.g. `stop_for_bad_request()` → `error_400`) falls back to plumber's opaque default `{"error":"500 ..."}` instead of mapping to the correct status + `application/problem+json`. Never reintroduce a bare `plumber::pr_mount("/api/x", plumber::pr("endpoints/x.R"))`; route it through `mount_endpoint()`, which attaches both `pr_set_error(errorHandler)` and `pr_set_404(notFoundHandler)`. Only `error_400/401/403/404/500` classes exist. The frontend reads problem+json via `extractApiErrorMessage` (`app/src/utils/api-errors.ts`, `detail` → `title`). Static guard: `api/tests/testthat/test-unit-endpoint-error-handler.R`.
- `DBI::dbBind()` with `?` placeholders needs `unname(params)`; named lists can fail silently.
- Auth-sensitive inputs are body-only: use JSON request bodies for `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-change endpoints; do not reintroduce query-string transport or raw query-string logging for these flows.
- User-supplied `filter`/`sort` column tokens are allowlisted before they reach `rlang::parse_exprs()`. `generate_filter_expressions()` / `generate_sort_expressions()` in `api/functions/response-helpers.R` take an `allowed_columns` argument and call `validate_query_column()`, which rejects any non-bare-identifier or non-allowlisted column with a 400 (`stop_for_bad_request`). List endpoints derive the allowlist from the queried view via `allowed_columns_for_view("<view>")` (fails open to `NULL` on a DB error, so legacy behavior still applies). Never reintroduce raw `paste0(column, ...)` into `parse_exprs` without routing the column through `validate_query_column`. Static guard: `api/tests/testthat/test-unit-filter-column-allowlist.R`.
- Public expensive/external operations are throttled or cache-only by design. The public clustering submit routes (`/api/jobs/clustering/submit`, `/api/jobs/phenotype_clustering/submit`) enforce a queue-depth cap via `async_job_capacity_exceeded()` / `async_job_active_count("default")` (env `ASYNC_PUBLIC_JOB_CAP`, default 8 → 503 + `Retry-After`). The public LLM cluster-summary endpoints are cache-hit-only: `get_cluster_summary(..., allow_generation = ...)` only runs Gemini when the caller is Curator+. Do not reintroduce synchronous Gemini generation or uncapped worker submission on a public path.
- The Gemini model default is centralized in `api/functions/llm-model-config.R`. There is exactly one in-code default (`LLM_DEFAULT_GEMINI_MODEL`, currently `gemini-3.5-flash`), resolved through `get_default_gemini_model()` with precedence `GEMINI_MODEL` env → `config.yml` `gemini_model` → in-code default. Every generation entry point (`generate_cluster_summary()`, `get_or_generate_summary()`, `validate_with_llm_judge()`) must default `model = NULL` and resolve via `get_default_gemini_model()`; never hardcode a model literal as a default or `%||%` fallback. Requested/configured models are validated by `llm_model_config_validate()` against `llm_model_catalog()` before any Gemini call (recoverable `llm_model_invalid`, not a raw stop); shut-down models such as `gemini-3-pro-preview` (retired 2026-03-09) stay in the catalog only as historical, disallowed metadata. Unknown models are accepted only when listed in `GEMINI_ALLOWED_MODELS_EXTRA` (operator override, surfaced with a warning). Static guard: `api/tests/testthat/test-unit-llm-model-default-guard.R`.
- Access-token lifetime is driven by `config$token_expiry` (default 3600s) for both the JWT `exp` claim (`auth_generate_token`) and the reported `expires_in` (`auth_signin`); keep them on the same source. `config$refresh` is now only the password-reset link TTL (`user_endpoints.R`), not the access-token lifetime.
- Core read views (`ndd_entity_view`, `users_view`, `search_non_alt_loci_view`, `search_disease_ontology_set`) are codified in migration `db/migrations/025_create_core_views.sql` with `SQL SECURITY INVOKER`, so a pristine DB boots. They are no longer only in the out-of-band `db/C_Rcommands_set-table-connections.R`; keep the migration and that script in sync if a view definition changes. `ndd_entity_view` is later rebuilt by `026_add_entity_last_update.sql` to add the derived `last_update` freshness column (`GREATEST(entry_date, approved status_date, primary-approved review_date)`); the latest `CREATE OR REPLACE VIEW ndd_entity_view` migration is the source of truth and must stay mirrored in the C_Rcommands script.
- Metadata refreshes that need rollback semantics must not use MySQL `TRUNCATE` inside transaction code because `TRUNCATE` is DDL and auto-commits. Use `refresh_disease_ontology_set()` or `metadata_with_foreign_key_checks_disabled()` from `api/functions/metadata-refresh.R`; both restore `FOREIGN_KEY_CHECKS` with immediate cleanup. The static guard `api/tests/testthat/test-unit-metadata-refresh-patterns.R` enforces this for `disease_ontology_set` and `non_alt_loci_set`; extend it when adding new metadata tables.
- `make ci-local` is the closest local CI parity check and should be preferred before handoff.
- `make pre-commit` now uses the fast API PR gate to keep local iteration close to pull-request CI; use `make ci-local` before handoff and `make test-api` when you need the full API suite locally.
- Host-side R quality targets in `Makefile` use `Rscript --no-init-file` to avoid Conda/miniforge bootstrap interference before the repo's own script entrypoints run.
- On Conda/miniforge R installs, `Makefile` derives `HOST_R_LD_LIBRARY_PATH` from `R RHOME` and prepends the sibling `mariadb/` runtime directory so `RMariaDB` can load successfully. Override `HOST_R_LD_LIBRARY_PATH` if the MariaDB client runtime lives elsewhere.
- External proxy fetchers must use `memoise_external_success_only()` rather than raw `memoise::memoise()`. Successful and true not-found responses may be cached, but `list(error = TRUE, ...)` transient upstream failures must not poison the 7/14/30-day external caches.
- API publication ingestion uses direct NCBI E-utilities helpers (`pubmed_esearch_count()` and `pubmed_fetch_xml()`). Tests that mock PubMed should stub those helpers.
- `batch_preview()` and `batch_create()` in `api/services/re-review-service.R` use a **soft LIMIT** (gene-atomic): the returned entity count may exceed `batch_size` to keep all entities for a partially-included gene in the same batch. Callers that assumed strict LIMIT for sizing UI elements must read the response length, not the requested cap. The `boundary_gene` field on the preview response is non-null when the soft-LIMIT engaged.
- Genes / Entities detail pages (v11.3) use an in-house SWR composable layer (`app/src/composables/useResource.ts` + Pinia `cacheStore`) and ~12 per-source hooks. Each card on the page is a `<SectionCard>` with skeleton + hide-when-empty. `<TablesEntities>` mounts on the URL-derived filter (HGNC id or symbol) — no gating on the gene record. There is a Playwright perf + axe bench at `app/tests/perf/genes-entities.bench.spec.ts` (local-only). Historical design docs are archived at `.planning/_archive/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md` and `.planning/_archive/superpowers/plans/2026-04-26-v11.3-genes-entities-perf-ux-plan.md`.

## Environment Notes

- Node major is pinned in `app/.nvmrc` and should match CI.
- Host-side API work may require overriding `HOST_R_LD_LIBRARY_PATH` if the MariaDB client runtime is not next to `R RHOME`; see `documentation/08-development.qmd`.
- `lintr` is not installed in the production API container; lint from the host.

## Documentation Contract

When repository behavior changes, update the durable docs in the same change:

- `AGENTS.md` for persistent agent-facing repository guidance
- `documentation/08-development.qmd` for human development workflow and onboarding
- `documentation/09-deployment.qmd` for deployment and operator-facing behavior
- `README.md` or `CONTRIBUTING.md` when entrypoints or contributor expectations change

## Deeper Docs

- Start with `documentation/08-development.qmd` for human developer onboarding.
- Use `documentation/09-deployment.qmd` for deployment and production operations.
- Use `documentation/10-visual-design-guide.md` for SysNDD UI/UX visual standards before changing public tables, authenticated admin/curation pages, mobile table rows, or design tokens.
- Cross-LLM visual-design enforcement lives in `.agents/skills/sysndd-visual-design/SKILL.md`, `.cursor/rules/sysndd-visual-design.mdc`, `.windsurf/rules/sysndd-visual-design.md`, and `GEMINI.md`; keep those pointers aligned with the visual guide.
- See `db/migrations/README.md` for migration-specific details.
- Planning, specs, reviews, and LLM workflow docs live under `.planning/`.
