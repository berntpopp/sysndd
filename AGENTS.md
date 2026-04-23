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
- Frontend unit tests: `cd app && npm run test:unit`

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

The API uses a bounded `mirai` daemon pool for long-running jobs. Code used inside those workers is sourced once when the worker starts. If you change worker-executed code, restart the API container before assuming the change is live.

### Migrations

`db/migrations/*.sql` are applied at API startup by the migration runner using MySQL advisory locks. Migration failures are supposed to crash startup. Do not work around a failing migration by weakening startup checks.

### Container mount boundary

In the dev/prod containers, source directories such as `api/functions`, `api/services`, `api/endpoints`, and `db/migrations` are bind-mounted live. `api/tests/` is not bind-mounted. To run tests inside the running API container, copy them in or rebuild.

## Stack-Specific Gotchas

- Namespace `dplyr::select(...)` and similar verbs explicitly in API code. Several loaded packages mask them.
- Use `inherits(x, "Date")`, not `is.Date(x)`, in library-light contexts.
- Plumber may return JSON scalars as arrays. Frontend callers should unwrap values before feeding them back into axios params.
- `DBI::dbBind()` with `?` placeholders needs `unname(params)`; named lists can fail silently.
- Auth-sensitive inputs are body-only: use JSON request bodies for `POST /api/auth/signup`, `POST /api/auth/authenticate`, and password-change endpoints; do not reintroduce query-string transport or raw query-string logging for these flows.
- `make ci-local` is the closest local CI parity check and should be preferred before handoff.
- `make pre-commit` now uses the fast API PR gate to keep local iteration close to pull-request CI; use `make ci-local` before handoff and `make test-api` when you need the full API suite locally.

## Environment Notes

- Node major is pinned in `app/.nvmrc` and should match CI.
- Host-side API work may require the Conda/Ubuntu 25.10 workaround summarized in `documentation/08-development.qmd`.
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
- See `db/migrations/README.md` for migration-specific details.
- Planning, specs, reviews, and LLM workflow docs live under `.planning/`.
