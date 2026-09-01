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

## Newly-Awake DB Tests (#612)

Since CI applies the real schema (`api/scripts/ci-load-test-schema.R`, `make test-db-schema`), a file that used to `skip()` on `dbExistsTable()` now RUNS. Such a test can fail for reasons that have nothing to do with the code under test, and the error rarely names the real cause. The five found so far, each with its tell:

- **`invalid format '%d'; use format %f, %e, %g or %a for numeric objects`** — `LAST_INSERT_ID()` is a BIGINT, and RMariaDB returns a BIGINT as `bit64::integer64`: a double carrying an int64 BIT PATTERN, so `sprintf("%d", id)` sees a denormal, not a whole number. Use `test_db_last_insert_id()` (`helper-db.R`). The value `0` works by coincidence, so a fresh connection looks fine and only a real inserted row fails.
- **`Data too long for column '<x>' [1406]`** — a synthetic fixture value that never had to fit a real column now does. Seen twice: `HGNC:` + 7 digits against `varchar(10)`, and a microsecond-stamped template version against `varchar(20)`. Prefer asserting the fixture against `information_schema.COLUMNS` over hardcoding the width.
- **A stub that silently does nothing.** `source_api_file(..., local = FALSE)` sources into `envir = parent.frame()`, which at a test file's top level is testthat's PER-FILE environment — a child of globalenv, **not** globalenv. A stub assigned to `globalenv()` is therefore SHADOWED by the real function, and the production implementation runs while the stub sits invisible one level up. It is asymmetric: a name bound at API startup (e.g. `gen_string_clust_obj_mem`) really does resolve in globalenv, so some stubs work and others don't. Stub where the name is already bound — see `stub_binding()` / `.stub_target_env()` in `test-unit-analysis-snapshot-validation-build.R`. Note bare `source()` (default `local = FALSE`) targets globalenv, so files loaded that way need the opposite treatment.
- **`Nested transactions not supported.`** — the code under test opens its OWN transaction on the connection it is handed, and `with_test_db_transaction()` already issued `dbBegin()`. **Do not "fix" this by switching the production helper to `db_with_savepoint_or_transaction()`** unless production really passes a caller-owned connection inside a transaction: `refresh_disease_ontology_set()` and `analysis_snapshot_refresh()` both receive a raw autocommit connection, where a `SAVEPOINT` silently buys NO atomicity. Either drop the outer transaction and clean up explicitly (documenting why, per AGENTS.md) or stub the thin BEGIN/COMMIT seam if the transaction is not what the test is about.
- **`could not find function ...` deep in a build path.** The test sources only part of the runtime. Add the missing module in `bootstrap/load_modules.R` order and say why in a comment.

## Test the Shape Plumber Actually Delivers

A handler test that hand-builds `req = list(argsBody = list(items = list(list(...))))` is asserting the `simplifyVector = FALSE` shape. Plumber uses `simplifyVector = TRUE`, so a uniform JSON array of objects reaches the handler as a **data.frame** whose `[[i]]` is a COLUMN. The curation queue's `confirm`/`dismiss` shipped rejecting every well-formed batch with `items[1] must be an object.` while its unit *and* endpoint tests were green, because both fed the hand-built shape.

Build the fixture through the parser instead, so the test sees what the wire sees:

```r
items <- jsonlite::fromJSON(jsonlite::toJSON(
  list(items = list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L))),
  auto_unbox = TRUE
))$items
expect_s3_class(items, "data.frame")   # assert the shape, so the test can't drift back
```

## Teardown Rules (learned the hard way)

- **Register the restore BEFORE the destructive step, not after the assertions.** An expectation failure aborts the block, and a teardown registered later never runs. A migration test that drops its tables and leaves them dropped destroys shared schema for every later file AND every subsequent run.
- **`on.exit(add = TRUE)` runs handlers in REGISTRATION order; `withr::defer()` unwinds LIFO.** A `dbDisconnect` registered first with `on.exit` fires BEFORE a cleanup registered later, and the cleanup then aborts with `bad_weak_ptr`, leaking fixture rows. Prefer `withr::defer()`.
- **Seed what you need instead of skipping on ambient data.** Several blocks keyed a `skip()` off whether the database happened to contain something — a category with >=2 NDD genes, an active inheritance term, a leaked disease row — so they ran only when an unrelated file had left it behind, and went silent the moment that leak was fixed. Seed inside your own rollback. A `skip_if_not(exists(<the thing under test>))` on a STATIC GUARD is worse: it makes the guard vacuous. Source the definition instead.
- **Never depend on another file's residue.** `test-integration-mondo-index.R` skipped unless `disease_ontology_set` happened to contain a row a *different* file had leaked — so it passed for the wrong reason and went silent the moment that leak was fixed. Seed what you need.
- **Delete only what you created.** A seed helper should report whether it inserted, so the teardown can remove exactly that (`.seed_disease_ontology_set_omim()` / `.unseed_...`).

## Don't Trip the Static Guards

Behavior changes must not break the guard tests that encode invariants: `test-unit-filter-column-allowlist.R`, `test-unit-endpoint-error-handler.R`, `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`, `test-unit-analysis-snapshot-coherence.R`, `test-unit-llm-model-default-guard.R`. If your change makes one fail, the change is likely wrong — not the guard.

## Output

Report which lane you ran and paste the real summary line. Never claim green on a run that only SKIPped.

## Deep reference

Authoritative detail, extracted from `AGENTS.md`:

- `references/ci-schema-and-traps.md` — CI test schema, the traps that woke up with it, destructive-teardown and nested-transaction rules.
- `references/e2e-playwright-stack.md` — Playwright stack, baseline fixture, known-good local baseline.
