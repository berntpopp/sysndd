# AGENTS.md

Canonical agent-facing instruction file for this repository. SysNDD is a neurodevelopmental disorder gene-disease database with three code trees:

- `api/` — R/Plumber REST API with `renv`
- `app/` — Vue 3 + TypeScript SPA built with Vite
- `db/` — MySQL schema, data-prep scripts, and versioned migrations

**Keep this file lean.** It carries only what applies across the whole repository. Subsystem detail lives in the skills below and their `references/` files, which are the authoritative source for their area — put new subsystem knowledge there, not here.

## Read the skill for your area first

Skill guides live at `.agents/skills/<name>/SKILL.md`. Read the relevant one **before** working in its area — each distills the invariants and traps for that subsystem, with deep detail in its `references/`.

| Skill | Read it before touching |
| --- | --- |
| `sysndd-code-quality` | Maintainability, modularity, file size, DRY/KISS/SOLID, typed boundaries, anti-pattern review |
| `sysndd-visual-design` | UI/UX, layouts, tables, mobile rows, design tokens, admin/curation and public data surfaces |
| `sysndd-frontend-integration` | The Vue↔API boundary: typed clients, Plumber response shapes, BVN table/tooltip traps, review forms |
| `sysndd-r-plumber` | R/Plumber runtime: package masking, request bodies, serializers, path params, sub-router errors, DBI binding |
| `sysndd-api-testing` | Writing/running R API tests, the container boundary, `with_test_db_transaction()`, SKIP-vs-PASS, static guards |
| `sysndd-migrations-db` | DB migrations, SQL views (`ndd_entity_view`, core views), the migration manifest, restore drift |
| `sysndd-async-jobs` | Durable MySQL-backed jobs and workers: handler registration, lanes/priority, the restart-the-worker rule |
| `sysndd-analysis-snapshots` | Clustering, the snapshot builder/validator, the survives-redeploy cache, `CLUSTER_LOGIC_VERSION`, LLM summaries |
| `sysndd-external-proxy` | Outbound provider calls: budgets, `memoise_external_success_only`, the per-request ceiling, API lanes |
| `sysndd-mcp-readonly` | The read-only MCP sidecar: approved-public-only reads, no writes/LLM/external calls, schema version |
| `sysndd-variation-provenance` | Variation-ontology provenance, the curation suggestion queue, review writes, entity rename carry-forward |
| `sysndd-curation-data-sources` | The cross-database comparator, MONDO mappings, admin metadata vocabularies, NDDScore |
| `sysndd-security-bug-scan` | Security + correctness review: authz gates, injection, secrets, public/MCP exposure, error leakage |

## Code Organization

- Write modular, focused code with one clear responsibility per file or module, so humans and LLM agents can read, test, and edit it in a single context.
- Keep handwritten source files under **600 lines** where practical. Treat it as a soft ceiling: if a file approaches it, extract cohesive helpers, components, composables, or services before adding more behavior.
- Do not split code mechanically. Tests, migrations, generated files, snapshots, fixtures, and tightly coupled implementations may exceed 600 lines when splitting would reduce clarity.
- Documented size exceptions are allowlisted in `scripts/code-quality-file-size-baseline.tsv` (WP9 / #346); `db/C_Rcommands_set-table-connections.R` is the standing one — a sequential schema-bootstrap script whose `ndd_entity_view` body must stay mirrored byte-for-byte with the latest `CREATE OR REPLACE VIEW ndd_entity_view` migration.

## Code Quality

- Start from nearby patterns and existing helpers before adding new abstractions, dependencies, or cross-layer shortcuts.
- Pair behavior changes with targeted tests or deterministic checks. Run the smallest useful check first, then `make pre-commit` or `make ci-local` when the scope warrants it.
- When touching files already over the ceiling, avoid making them larger. `make code-quality-audit` enforces this as a fast file-size ratchet — ratchet the baseline in the same change rather than leaving master red.
- Frontend API access goes through typed clients in `app/src/api/*`. No raw axios calls in views/components, and no direct `localStorage.token` / `localStorage.user` access.
- API integration tests that write database state use `with_test_db_transaction()`, or document why rollback is not possible.

## Verify Before Handoff

- Fast deterministic code-quality audit: `make code-quality-audit`
- Full-repo check (closest local CI parity — prefer before handoff): `make ci-local`
- Fast pre-push check: `make pre-commit`
- Full dev stack: `make dev` — DB-only stack: `make docker-dev-db`
- API tests: `make test-api` — fast PR gate: `make test-api-fast` — lint: `make lint-api`
- Load the schema into the test DB so integration tests actually run: `make test-db-schema`
- Frontend: `make lint-app`, `cd app && npm run type-check` (`type-check:strict` for touched scope), `cd app && npm run test:unit`
- Frontend budgets/gates: `make verify-app-bundle-budget`, `make verify-seo-app`
- Frontend E2E (Playwright, **local-only**, no CI workflow): `make playwright-stack && cd app && npx playwright test && cd .. && make playwright-stack-down`. See `sysndd-api-testing/references/e2e-playwright-stack.md` for the baseline fixture and the known-good result.

**Integration tests need a schema, and CI now provides one.** Every `test-integration-*.R` guards itself with `skip_if_missing_*_schema()`; `api/scripts/ci-load-test-schema.R` applies the project's real migrations before the test step. Locally, `make test-db-schema` does the same against `sysndd_db_test`. Never report a wall of SKIPs as success — see `sysndd-api-testing/references/ci-schema-and-traps.md` for the traps that woke up with the schema (destructive teardowns, nested transactions, cross-test residue).

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

Repository-wide rules. Subsystem invariants live in the skills.

### API bootstrap and source order

`api/start_sysndd_api.R` sources the runtime into the global environment in this order: `functions/*` and repository helpers → `core/*` → `services/*` → `endpoints/*`. Service functions must keep their `svc_` or `service_` prefixes: a service function that drops the prefix and collides with a repository function name silently shadows the repository implementation.

`api/bootstrap/load_modules.R` is the **single loader** for both the API and the durable worker. Files are not autodiscovered — register every new `functions/` or `services/` file there, in dependency order.

### Worker restart rule

Worker-executed code is sourced once when the worker starts. **After changing worker-executed code, restart the worker container** before assuming the change is live. Durable job handlers resolve DB credentials from the worker's runtime config (`async_job_worker_db_config()`), never from the job payload.

### Migrations

`db/migrations/*.sql` are applied at API startup by the migration runner using MySQL advisory locks. Migration failures are supposed to crash startup — never work around a failing migration by weakening startup checks. Startup also validates the migration manifest (`api/functions/migration-manifest.R`, `EXPECTED_LATEST_MIGRATION` / `EXPECTED_MIGRATION_COUNT`); read the current values there rather than trusting a number quoted in prose. Missing, empty, or stale mounts are fatal and are fixed at packaging/deployment time.

### Container mount boundary

In dev/prod containers, `api/functions`, `api/services`, `api/endpoints`, and `db/migrations` are bind-mounted live — changes are live on container restart, no rebuild. **`api/tests/` is not bind-mounted**; copy tests in or rebuild to run them inside the container.

The API image must not bake a real `api/config.yml` into image layers. Provide runtime configuration through the Compose read-only mount, an operator secret, or an equivalent injection mechanism.

### Public SEO prerendering

Public SEO pages are generated by the frontend prerender pipeline. If public route content, canonical URL policy, sitemap behavior, or SEO payload endpoints change, run `make verify-seo-app` and update `documentation/08-development.qmd` / `documentation/09-deployment.qmd`.

## Cross-Cutting Rules

Each has a static guard test; the deep explanation is in the linked skill.

- **Namespace `dplyr::select()` / `dplyr::filter()` explicitly**, and use `base::get()` rather than a bare `get()`. Loaded packages mask both, and resolution depends on attach order — which differs between the API, the worker, the mirai pool, and a standalone `Rscript`. → `sysndd-r-plumber`
- **Mount every endpoint file via `mount_endpoint()`**, never a bare `pr_mount()`, or classed errors degrade to opaque 500s instead of RFC 9457 problem+json. → `sysndd-r-plumber`
- **Declare a public route's role gate in the handler**, and declare a static route (e.g. `/status/_list`) **before** any dynamic sibling — Plumber matches in declaration order. → `sysndd-security-bug-scan`
- **Auth-sensitive inputs are body-only**; never reintroduce query-string transport for credentials. → `sysndd-security-bug-scan`
- **Route user-supplied `filter`/`sort` column tokens through `validate_query_column()`** before `rlang::parse_exprs()`. → `sysndd-security-bug-scan`
- **Every external HTTP call derives its timeout/retry from `external_proxy_budget()` or `make_external_request()`** — never a hardcoded literal — and uses `memoise_external_success_only()` so transient failures cannot poison the cache. Cheap routes (`/health`, `/auth`, `/statistics`) must never call an external fetcher. → `sysndd-external-proxy`
- **Public expensive or external operations are throttled or cache-only by design.** Do not reintroduce synchronous Gemini generation or uncapped worker submission on a public path. → `sysndd-security-bug-scan`
- **MCP tools are read-only and approved-public only**: no writes, no raw SQL/R, no LLM generation, no live external providers, no draft/admin/user/log/job data. → `sysndd-mcp-readonly`
- **Public analysis endpoints read durable public-ready snapshots**, never live heavy compute; a miss fails fast with snapshot diagnostics. → `sysndd-analysis-snapshots`

## Environment Notes

- Node major is pinned in `app/.nvmrc` and should match CI.
- Host-side R quality targets in `Makefile` use `Rscript --no-init-file` to avoid Conda/miniforge bootstrap interference.
- On Conda/miniforge R installs, `Makefile` derives `HOST_R_LD_LIBRARY_PATH` from `R RHOME` and prepends the sibling `mariadb/` runtime directory so `RMariaDB` loads. Override it if the MariaDB client runtime lives elsewhere; see `documentation/08-development.qmd`.
- `lintr` is not installed in the production API container — lint from the host.

## Documentation Contract

When repository behavior changes, update the durable docs in the same change:

- The relevant `.agents/skills/<name>/SKILL.md` (or its `references/`) for subsystem behavior — this is where depth belongs
- `AGENTS.md` only when the change is genuinely repository-wide
- `documentation/08-development.qmd` for human development workflow and onboarding
- `documentation/09-deployment.qmd` for deployment and operator-facing behavior
- `README.md` or `CONTRIBUTING.md` when entrypoints or contributor expectations change

## Deeper Docs

- `documentation/08-development.qmd` — human developer onboarding
- `documentation/09-deployment.qmd` — deployment and production operations
- `documentation/10-visual-design-guide.md` — UI/UX visual standards (also mirrored for other LLM tools via `.cursor/rules/`, `.windsurf/rules/`, `GEMINI.md`; keep those pointers aligned)
- `db/migrations/README.md` — migration-specific details
- `.planning/` — planning, specs, reviews, and LLM workflow docs
