# AGENTS.md

This is the canonical agent-facing instruction file for this repository. SysNDD is a neurodevelopmental disorder gene-disease database with three main code trees:

- `api/` — R/Plumber REST API with `renv`
- `app/` — Vue 3 + TypeScript SPA built with Vite
- `db/` — MySQL schema, data-prep scripts, and versioned migrations

## Verify Before Handoff

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

### Read-only MCP sidecar

`api/start_sysndd_mcp.R` runs the MCP server as a separate sidecar/process, not inside Plumber. The Phase 0 spike proved `mcptools` HTTP initialize -> `tools/list` -> `tools/call`, `GET 405`, no required session header, and JSON-serialized text output; v1 tools should keep stable JSON text with `schema_version` as the compatibility contract. The sidecar also patches `mcptools` to advertise output schemas, read-only tool annotations, static schema resources, user-controlled prompts, and tool-visible recoverable errors.

The MCP container healthcheck must stay cheap and data-independent: use `api/scripts/mcp-healthcheck.R` for `initialize` + `tools/list` liveness only. Keep `api/scripts/mcp-smoke.R` as the heavier developer/CI verification probe because it exercises real tools and approved public DB content.

MCP v1 is private/internal by default in Compose. Do not expose public unauthenticated `/mcp`; any route must be private or static-bearer protected at the proxy/service boundary.

MCP client ergonomics are part of the contract. Keep initialize instructions SysNDD-specific but concise, with the gene -> entity -> publication workflow, the entity model, cheap-path payload controls, resource semantics, and read-only constraints. `MCP_SCHEMA_VERSION` is `1.1`. `get_sysndd_capabilities` is the longer in-band guide for workflows, limits, payload modes, citation rules, resources, prompts, errors, and v1 exclusions. Keep `resources/list` / `resources/read` aligned with distinct `sysndd://schema/overview` and `sysndd://schema/tool-guide` content; record-like `sysndd://gene`, `sysndd://entity`, and `sysndd://publication` URIs are stable identifiers, not v1 parameterized resources. Publication outputs are citation-friendly (`recommended_citation`), expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `matches_curation_date`, `unverified`) sourced from the `publication.publication_date_source` column, distinguish that date from `sysndd_curation_date`, expose `abstract_available` when abstract text is requested or metadata mode is selected, and omit `abstract_excerpt` unless `abstract_mode = "excerpt"`. `recommended_citation` omits the year when the date is unverified.

Recoverable MCP validation failures should return a JSON tool result with `schema_version`, `error.code`, and `isError = true`, not raw R errors or JSON-RPC `-32603`. Keep `symbol` and `query` as hidden deprecated aliases for `get_gene_context(gene = ...)` and `list_gene_entities(gene = ...)`, but do not advertise them in `tools/list` input schemas. Include short examples and boolean defaults in tool descriptions, default `get_gene_context(include_comparisons = false)` for the cheap path, use `get_gene_context(expand = "entities")` for one-call gene detail when the caller opts into it, cap that detailed expansion at the 20-ID batch limit, and use `get_genes_context`, `get_entities_context(dedupe_publications = true)` / `get_publications_context` to avoid avoidable fan-out and duplicate abstracts.

MCP tools and prompts are strictly read-only. They must not write to the DB, execute raw SQL/R, call Gemini, call external providers, or expose draft reviews, re-review workflows, admin/user/log/job data, curation comments, or broad export payloads. Enforce approved public data in repository queries: active records from `ndd_entity_view`, and review-derived synopsis/phenotype/variation/publication data only from primary approved reviews (`is_primary = 1` and `review_approved = 1`).

### Migrations

`db/migrations/*.sql` are applied at API startup by the migration runner using MySQL advisory locks. Migration failures are supposed to crash startup. Do not work around a failing migration by weakening startup checks.

### Container mount boundary

In the dev/prod containers, source directories such as `api/functions`, `api/services`, `api/endpoints`, and `db/migrations` are bind-mounted live. `api/tests/` is not bind-mounted. To run tests inside the running API container, copy them in or rebuild.

### Public SEO prerendering

Public SEO pages are generated by the frontend prerender pipeline. If public route content, canonical URL policy, sitemap behavior, or SEO payload endpoints change, run `make verify-seo-app` and update `documentation/08-development.qmd` / `documentation/09-deployment.qmd`.

## Stack-Specific Gotchas

- Namespace `dplyr::select(...)` and similar verbs explicitly in API code. Several loaded packages mask them.
- Use `inherits(x, "Date")`, not `is.Date(x)`, in library-light contexts.
- Plumber may return JSON scalars as arrays. Frontend callers should unwrap values before feeding them back into axios params.
- `DBI::dbBind()` with `?` placeholders needs `unname(params)`; named lists can fail silently.
- Auth-sensitive inputs are body-only: use JSON request bodies for `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-change endpoints; do not reintroduce query-string transport or raw query-string logging for these flows.
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
