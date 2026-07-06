---
name: sysndd-api-testing
description: Use when writing, running, or fixing SysNDD R/Plumber API tests (testthat) — including database-writing tests, running a single test inside the API container, mocking external providers, or diagnosing SKIP-vs-PASS, helper-loading, or path-resolution issues
---

# SysNDD API Testing

Use this skill before adding or running R API tests under `api/tests/testthat/`. The suite is large (200+ files) and has non-obvious container, database, and helper conventions. The authoritative helpers are `helper-db.R`, `helper-paths.R`, and `setup.R`.

## Run Lanes

- `make test-api-fast` — fast PR gate (also what `make pre-commit` runs).
- `make test-api` — full suite locally.
- `make ci-local` — closest local mirror of CI (lint + tests with DB). Prefer before handoff.
- Single file (host): `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-foo.R')"`
- Single file (running container): `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-foo.R')"`

## Container Boundary (the #1 trap)

`api/tests/` is **not** bind-mounted (only `functions/`, `services/`, `endpoints/`, `core/` are). A new or edited test must be copied in or the image rebuilt:

```bash
docker cp api/tests/testthat/test-foo.R sysndd-api-1:/app/tests/testthat/test-foo.R
```

Inside the container the default `sysndd_db_test` config points at a host-published port that the container can't reach, so `skip_if_no_test_db()` **SKIPs**. `get_test_config()` prefers `MYSQL_*` env when `MYSQL_HOST` is set, so pass DB creds to reach the DB service:

```bash
docker exec -e MYSQL_HOST=mysql -e MYSQL_DATABASE=sysndd_db_test \
  -e MYSQL_USER=<u> -e MYSQL_PASSWORD=<p> sysndd-api-1 \
  Rscript -e "testthat::test_file('/app/tests/testthat/test-foo.R')"
```

**SKIP is not PASS.** Read the summary: `[ FAIL 0 | SKIP 1 ]` means the DB test did not run. Only `PASS n` with `SKIP 0` is a real green.

## Patterns

- **Load code under test:** `source_api_file("services/foo-service.R", local = FALSE)` — resolves `/app` in-container via `get_api_dir()`. `helper-*.R` auto-load through `setup.R`.
- **DB-writing tests:** wrap in `with_test_db_transaction({ conn <- getOption(".test_db_con"); ... })` — always rolls back. It calls `skip_if_no_test_db()` for you. See AGENTS.md: prefer this or document why rollback is impossible.
- **Schema setup goes OUTSIDE the transaction.** `CREATE TABLE`/`TRUNCATE` are DDL and auto-commit — they break rollback isolation. Create fixtures on a separate connection first (mirror `ensure_test_user_table()`).
- **`DBI::dbBind()` with `?` placeholders needs `unname(params)`** (named lists fail silently); positional `params = list(x)` is safe.
- **Mock external providers**, not `httr2`: PubMed tests stub `pubmed_esearch_count()` / `pubmed_fetch_xml()`; see `helper-mock-apis.R` and `dittodb`.

## Don't Trip the Static Guards

Behavior changes must not break the guard tests that encode invariants: `test-unit-filter-column-allowlist.R`, `test-unit-endpoint-error-handler.R`, `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`, `test-unit-analysis-snapshot-coherence.R`, `test-unit-llm-model-default-guard.R`. If your change makes one fail, the change is likely wrong — not the guard.

## Output

Report which lane you ran and paste the real summary line. Never claim green on a run that only SKIPped.
