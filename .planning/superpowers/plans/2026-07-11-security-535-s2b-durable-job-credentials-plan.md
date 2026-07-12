# S2b — DB Credentials Out of All Durable Job Payloads — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the database password from being persisted into `async_jobs.request_payload_json` for **every remaining durable job family** (S2 fixed only `backup`), by removing `db_config` from every job payload and having each worker handler resolve credentials at run time via the already-shipped `async_job_worker_db_config()` / `async_job_db_connect()` resolver.

**Architecture:** Each family currently marshals `password = dw$password` (or a `db_*`-keyed variant) into a `db_config` list that `create_job()`/`async_job_service_submit()` serializes into the durable payload; the worker later reads `db_config$password` back to open a `DBI::dbConnect`. Both the API (`start_sysndd_api.R:54`) and the durable worker (`start_async_worker.R:28`) hold the **same** global `dw`, and durable handlers run **in-process in the worker** (no mirai daemon dispatch), so `async_job_db_connect()` returns a byte-identical connection at run time. This is a **pure security change with zero behavioral change**: drop the credential from the payload (submit side) and swap each handler's inline `DBI::dbConnect(...)` for `conn <- async_job_db_connect()` (consume side). No family uses `db_config` for anything except opening the connection, so `db_config` is removed from every payload entirely.

**Tech Stack:** R / Plumber / testthat; `RMariaDB`/`DBI`; the resolver in `api/functions/async-job-db-config.R` (already merged on this branch base).

## Global Constraints

- **Branch base / stacking.** This branch (`fix/535-s2b-jobs-credentials`) is stacked on `fix/535-p1-secrets-out-of-jobs` (S2, PR #539), because the resolver `async-job-db-config.R` and the guard test exist **only** on that branch, not on `master`. The S2b PR targets `fix/535-p1-secrets-out-of-jobs`; GitHub auto-retargets to `master` when #539 merges.
- Keep every touched file **< 600 lines** (`make code-quality-audit`). Every S2b edit is a net **removal**, so all touched files shrink; the largest touched are `comparisons-functions.R` (563) and `pubtator-functions.R` (562) and both shrink.
- **`config::get` masks `base::get`** in the loaded API/worker env (no `mode`/`envir` arg). The resolver already handles `dw` lookup with `base::get(..., envir = .GlobalEnv)`; **do not** add any bare `get("dw", ...)`. Handlers must call `async_job_db_connect()` (never re-inline a `password = <cfg>$password` connect — that both re-leaks and trips the guard).
- **Namespace `dplyr`/`DBI` verbs** explicitly; several loaded packages mask them.
- The `api/tests/` dir is **not** bind-mounted into the container. Run a changed test file in the container via:
  `docker cp api/tests/testthat/<file> sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"`.
  The credential-guard test is **static** (file scan) and runs on the host: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`.
- **Worker-executed code is sourced at worker start** — after changing handler/resolver code, **restart the worker container** before a live check reflects it.
- **No DB migration.** S2b is code-only; it touches no schema. Latest migration is unaffected.
- **Credential rotation is operator work** (already documented for S2). S2b stops the *remaining* families from writing the password into new payloads; historical payloads for these families are redacted by the same `async_job_scrub_payload_credentials()` startup/script scrub S2 shipped (see Task 8 note — verify its predicate covers these job types, do not narrow it).
- **The guard test moves in lockstep with the code.** `test-unit-job-payload-credential-guard.R` freezes an EXACT `basename | line` offender set. Each family task removes that family's code lines **and** its frozen-set entries in the same commit, so the static guard stays green at every commit (the test's own comment mandates this: "S2b removes entries as it migrates each family").

---

## Family map (the 14 frozen offenders → disposition)

Frozen set is in `api/tests/testthat/test-unit-job-payload-credential-guard.R`. Classification: **SUBMIT** = builds a `db_config` marshaled into a durable payload; **CONSUME** = `DBI::dbConnect` in a worker handler; **DEAD** = passed to a function that ignores it; **INPROC** = in-process arg marshaling (never persisted, but still matches the guard pattern).

| # | Frozen line (`basename \| line`) | Family | Kind | Fix |
|---|---|---|---|---|
| 1 | `admin-ontology-endpoint-service.R \| password = dw$password,` | omim_update + force_apply_ontology | SUBMIT | delete `.svc_admin_ontology_db_config()`; drop `db_config` from both params |
| 4 | `async-job-omim-apply.R \| password = db_config$password,` | omim_update | CONSUME | `async_job_db_connect()`; drop `db_config` param |
| 5 | `async-job-provider-handlers.R \| password = db_config$password,` | hgnc_update | CONSUME | `async_job_db_connect()`; drop `db_config` param |
| 6 | `comparisons-functions.R \| password = db_config$password,` | comparisons_update | CONSUME | `async_job_db_connect()` |
| 7 | `job-maintenance-submission-service.R \| password = dw$password,` (hgnc) | hgnc_update | SUBMIT | drop `db_config`; remove dead inline `executor_fn` closure |
| 8 | `job-maintenance-submission-service.R \| password = dw$password,` (comparisons) | comparisons_update | SUBMIT | drop `db_config`; remove dead inline `executor_fn` closure |
| 2 | `admin-publication-refresh-endpoint-service.R \| password = dw$password,` | publication_refresh | SUBMIT | delete `.svc_admin_publication_refresh_db_config()`; params → `list(pmids = pmids)` |
| 3 | `admin_publications_endpoints.R \| password = dw$password,` | publication_date_backfill | SUBMIT | drop `db_config` from `request_payload`; keep `limit`, `dry_run` |
| 11 | `publication-admin-endpoint-service.R \| db_password = dw$db_password,` | pubtator_update (sync) | DEAD | delete the dead `db_host/db_port/db_name/db_user/db_password` args (all `NULL`) — do NOT "repair" to `dw$password` |
| 12 | `publication-admin-endpoint-service.R \| db_password = dw$password` | pubtator_update (async) | SUBMIT | drop `db_config`; remove dead inline `executor_fn` closure |
| 13 | `pubtator-functions.R \| password = db_config$db_password,` | pubtator_update | CONSUME | `async_job_db_connect()`; drop `db_config` param + update 2 callers |
| 14 | `pubtatornidd-nightly.R \| db_password = dw_config$password` | pubtatornidd_nightly | INPROC | remove in-process `db_config`; drop `db_config=` arg to `pubtator_db_update_async` |
| 9 | `llm-batch-generator.R \| db_password = db_cfg$password` | llm_generation | SUBMIT | remove `db_config` build block; drop from params + validate/log lines |
| 10 | `llm-batch-generator.R \| password = db_config$db_password` | llm_generation | CONSUME | `async_job_db_connect()`; remove extract/null-guard/log lines |

**Also migrate (correctness, NOT frozen — two-level `payload$db_config$password` evades the one-level guard pattern):**
- `async-job-omim-apply.R:46` `apply_additive_terms_on_block` (`payload$db_config$password`) → `async_job_db_connect()`.
- `async-job-provider-handlers.R:389` `.async_job_run_force_apply_ontology` (`payload$db_config$password`) → `async_job_db_connect()`.
- `async-job-maintenance-handlers.R:141` `.async_job_run_publication_refresh` (`payload$db_config$password`) → `async_job_db_connect()`.
- `async-job-maintenance-handlers.R:224` `.async_job_run_publication_date_backfill` (`payload$db_config$password`) → `async_job_db_connect()`.

These MUST migrate with their family: once the submit side stops writing the password, `payload$db_config$password` becomes `NULL` and the inline connect would fail. Submit + consume for a family always change together.

**Confirmed safe (do NOT touch):**
- `pubtator_enrichment_refresh`, and the `pubtatornidd_nightly` orchestrator's own connection, use `pool::poolCheckout(pool)` — no payload credential. Nothing to change.
- The sync `svc_publication_pubtator_update` / `pubtator_db_update()` connect through the global `pool` (`db_with_transaction`), not `db_config`. Only its dead call-site args (#11) are removed.

---

## Canonical edit patterns (referenced by every task)

**CONSUME pattern.** Replace the inline connect block (any of the field-name shapes: `dbname/host/user/password/port`, with or without an ignored `server`, or the `db_*`-prefixed `db_name/db_host/db_user/db_password/db_port`) with the resolver call, preserving the surrounding variable name and `on.exit(DBI::dbDisconnect(...))`:

```r
# BEFORE (example — .async_job_hgnc_write_db)
conn <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  dbname = db_config$dbname,
  host = db_config$host,
  user = db_config$user,
  password = db_config$password,
  port = db_config$port
)
on.exit(DBI::dbDisconnect(conn), add = TRUE)

# AFTER
conn <- async_job_db_connect()
on.exit(DBI::dbDisconnect(conn), add = TRUE)
```

Where the original wrapped the connect in a `tryCatch(..., error = function(e) NULL)` (pubtator, llm), keep the exact `tryCatch`/`NULL` wrapper, only swapping the connect expression:

```r
conn <- tryCatch(
  async_job_db_connect(),
  error = function(e) { <the existing log line>; NULL }
)
```

**SUBMIT pattern.** Delete the `db_config <- list(...)` (or the `.svc_*_db_config()` helper) and drop `db_config = ...` from the `create_job(...)`/`async_job_service_submit(...)` `params`/`request_payload`. No family has a non-connection reader of `db_config`, so nothing downstream needs a replacement value.

---

### Task 1: Ontology family (omim_update + force_apply_ontology)

**Files:**
- Modify: `api/functions/async-job-omim-apply.R` (connects at `:5-13` and `:46-54`)
- Modify: `api/functions/async-job-provider-handlers.R` (force-apply connect `:389-397`; omim caller `:345`)
- Modify: `api/services/admin-ontology-endpoint-service.R` (helper `:20-29`; params `:79`, `:178`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

**Interfaces:**
- Consumes: `async_job_db_connect()` from `functions/async-job-db-config.R` — `function(runtime_config = NULL) -> DBIConnection` (opens from global `dw`).
- Produces: `.async_job_omim_db_write(disease_ontology_set_update, safeguard)` — the `db_config` third param is REMOVED; caller at `provider-handlers.R:345` drops `db_config = payload$db_config`.

- [ ] **Step 1: Migrate the three consume connects.**
  - `async-job-omim-apply.R:5-13` (`.async_job_omim_db_write`): replace the `DBI::dbConnect(...)` block with `sysndd_db <- async_job_db_connect()` (keep the `on.exit` at `:14`). Remove the now-unused `db_config` formal from the function signature (`:4`).
  - `async-job-omim-apply.R:46-54` (`apply_additive_terms_on_block`): replace with `add_conn <- async_job_db_connect()` (keep the `:55` disconnect).
  - `async-job-provider-handlers.R:389-397` (`.async_job_run_force_apply_ontology`): replace with `sysndd_db <- async_job_db_connect()` (keep the `:398` disconnect; the later `batch_create(pool = sysndd_db)` at `:425` keeps working because the variable name is preserved).
  - `async-job-provider-handlers.R:345`: drop `db_config = payload$db_config` from the `.async_job_omim_db_write(...)` call.

- [ ] **Step 2: Remove the submit-side credential.**
  - `admin-ontology-endpoint-service.R`: delete the helper `.svc_admin_ontology_db_config()` (`:19-30`). Remove `db_config = .svc_admin_ontology_db_config(dw)` from the `omim_update` params (`:79`) and the `force_apply_ontology` params (`:178`). Leave `dw` in the two function signatures (harmless; the endpoints still pass it) — do not thread-remove it.

- [ ] **Step 3: Run the guard test — expect RED (scan no longer matches frozen set).**

  Run: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`
  Expected: FAIL on "credential-in-payload line set matches the frozen S2b-pending list" — `actual` is missing `admin-ontology-endpoint-service.R | ...` and `async-job-omim-apply.R | ...`.

- [ ] **Step 4: Shrink the frozen set + add resolver-presence assertion for this family.**
  - In the `expected <- sort(c(...))` vector, delete the two lines:
    `"admin-ontology-endpoint-service.R | password = dw$password,"` and
    `"async-job-omim-apply.R | password = db_config$password,"`.
  - In the third `test_that` (or a new one), add a resolver-presence check that grows per family. Introduce (once) near the top of the file:
    ```r
    .expect_resolves_creds <- function(rel) {
      blob <- paste(readLines(file.path("../..", rel), warn = FALSE), collapse = "\n")
      expect_true(grepl("async_job_db_connect\\(", blob),
                  info = paste(rel, "must open its worker connection via async_job_db_connect()"))
    }
    ```
    and a test:
    ```r
    test_that("migrated durable handlers resolve DB creds at run time", {
      .expect_resolves_creds("functions/async-job-omim-apply.R")
      .expect_resolves_creds("functions/async-job-provider-handlers.R")
    })
    ```

- [ ] **Step 5: Run the guard test — expect GREEN.**

  Run: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`
  Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add api/functions/async-job-omim-apply.R api/functions/async-job-provider-handlers.R \
        api/services/admin-ontology-endpoint-service.R \
        api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for omim_update/force_apply_ontology (#535 S2b)"
```

---

### Task 2: hgnc_update

**Files:**
- Modify: `api/functions/async-job-provider-handlers.R` (hgnc consume `:23-30`; caller `:97`)
- Modify: `api/services/job-maintenance-submission-service.R` (hgnc submit `db_config` + dead closure ~`:121-152`, connect `:187-193`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

**Interfaces:**
- Produces: `.async_job_hgnc_write_db(hgnc_data, job_id)` — the `db_config` param is REMOVED; caller at `:97` drops `db_config = payload$db_config`.

- [ ] **Step 1: Migrate the consume connect + drop the param.**
  - `async-job-provider-handlers.R:23-30` (`.async_job_hgnc_write_db`): replace the `DBI::dbConnect(...)` with `conn <- async_job_db_connect()` (keep `:31` disconnect). Remove the `db_config` formal (`:22` region) and update the caller `.async_job_run_hgnc_update` at `:97` to call `.async_job_hgnc_write_db(hgnc_data, job_id)` (drop `db_config = payload$db_config`).

- [ ] **Step 2: Remove the submit-side credential + dead closure.**
  - `job-maintenance-submission-service.R` (`svc_job_submit_hgnc_update`): delete the `db_config <- list(...)` block (contains `password = dw$password` at `:129`) and the dead inline `executor_fn = function(params) { ... DBI::dbConnect(..., password = params$db_config$password ...) }` closure (`:187-193` region). Reduce `create_job(operation = "hgnc_update", params = list(db_config = db_config), executor_fn = <closure>)` to `create_job(operation = "hgnc_update", params = list(), executor_fn = NULL)`.
    - NOTE: empty `params = list()` is already the established pattern — `svc_admin_ontology_update_async` calls `duplicate_check_fn("omim_update", list())`. Serializing `list()` yields a stable payload/hash; two concurrent hgnc submits then dedupe (desired).

- [ ] **Step 3: Run guard — RED** (missing `async-job-provider-handlers.R | password = db_config$password,` and one `job-maintenance-submission-service.R | password = dw$password,`).

  Run: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`
  Expected: FAIL.

- [ ] **Step 4: Shrink the frozen set.** Remove from `expected`: `"async-job-provider-handlers.R | password = db_config$password,"` and ONE `"job-maintenance-submission-service.R | password = dw$password,"` (the vector has two identical entries — delete one; the comparisons entry stays until Task 3). `async-job-provider-handlers.R` is already in the resolver-presence test from Task 1.

- [ ] **Step 5: Run guard — GREEN.**

  Run: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`
  Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add api/functions/async-job-provider-handlers.R api/services/job-maintenance-submission-service.R \
        api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for hgnc_update (#535 S2b)"
```

---

### Task 3: comparisons_update

**Files:**
- Modify: `api/functions/comparisons-functions.R` (consume `:279-286`; `db_config <- params$db_config` `:261`)
- Modify: `api/services/job-maintenance-submission-service.R` (comparisons submit `db_config` + params `:314-347`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

- [ ] **Step 1: Migrate the consume connect.**
  - `comparisons-functions.R:279-286` (`comparisons_update_async`): replace the `DBI::dbConnect(...)` with `conn <- async_job_db_connect()`. Delete the now-unused `db_config <- params$db_config` at `:261` (no other reference — verified).

- [ ] **Step 2: Remove the submit-side credential.**
  - `job-maintenance-submission-service.R` (`svc_job_submit_comparisons_update`): delete the `db_config <- list(...)` block (`password = dw$password` at `:318`) and drop `db_config = db_config` from the `create_job(operation = "comparisons_update", params = ...)` at `:341` → `params = list()`. If a dead inline `executor_fn` closure builds/reads `db_config` here, remove it and pass `executor_fn = NULL`.

- [ ] **Step 3: Run guard — RED** (missing `comparisons-functions.R | password = db_config$password,` and the remaining `job-maintenance-submission-service.R | password = dw$password,`).

- [ ] **Step 4: Shrink frozen set + add resolver-presence.** Remove `"comparisons-functions.R | password = db_config$password,"` and the last `"job-maintenance-submission-service.R | password = dw$password,"`. Add `.expect_resolves_creds("functions/comparisons-functions.R")` to the resolver-presence test.

- [ ] **Step 5: Run guard — GREEN.**

- [ ] **Step 6: Commit.**

```bash
git add api/functions/comparisons-functions.R api/services/job-maintenance-submission-service.R \
        api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for comparisons_update (#535 S2b)"
```

---

### Task 4: publication_refresh + publication_date_backfill

**Files:**
- Modify: `api/functions/async-job-maintenance-handlers.R` (consumes `:141-148`, `:224-231`)
- Modify: `api/services/admin-publication-refresh-endpoint-service.R` (helper `:110-119`; params `:182`)
- Modify: `api/endpoints/admin_publications_endpoints.R` (`request_payload$db_config` `:55-62`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

- [ ] **Step 1: Migrate the two consume connects.**
  - `async-job-maintenance-handlers.R:141-148` (`.async_job_run_publication_refresh`): replace the `DBI::dbConnect(...)` with `sysndd_db <- async_job_db_connect()` (keep disconnect + the subsequent `backfill`/refresh calls that use `sysndd_db`).
  - `async-job-maintenance-handlers.R:224-231` (`.async_job_run_publication_date_backfill`): replace with `sysndd_db <- async_job_db_connect()` (the live conn is still passed to `backfill_publication_dates_run(sysndd_db, ...)` at `:234`).

- [ ] **Step 2: Remove the submit-side credentials.**
  - `admin-publication-refresh-endpoint-service.R`: delete `.svc_admin_publication_refresh_db_config()` (`:110-119`), and reduce the `create_job(operation = "publication_refresh", params = list(pmids = pmids, db_config = ...))` to `params = list(pmids = pmids)` (drop `:182`).
  - `admin_publications_endpoints.R`: delete the `db_config = list(dbname = dw$dbname, ...)` block from `request_payload` (`:55-62`), keeping `limit` and `dry_run`.

- [ ] **Step 3: Run guard — RED** (missing `admin-publication-refresh-endpoint-service.R | ...` and `admin_publications_endpoints.R | ...`).

- [ ] **Step 4: Shrink frozen set + add resolver-presence.** Remove `"admin-publication-refresh-endpoint-service.R | password = dw$password,"` and `"admin_publications_endpoints.R | password = dw$password,"`. Add `.expect_resolves_creds("functions/async-job-maintenance-handlers.R")` (it already resolves for backup; this now also covers the two publication handlers).

- [ ] **Step 5: Run guard — GREEN.**

- [ ] **Step 6: Commit.**

```bash
git add api/functions/async-job-maintenance-handlers.R \
        api/services/admin-publication-refresh-endpoint-service.R \
        api/endpoints/admin_publications_endpoints.R \
        api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for publication_refresh/date_backfill (#535 S2b)"
```

---

### Task 5: pubtator_update (+ pubtatornidd_nightly in-process + sync dead args)

**Files:**
- Modify: `api/functions/pubtator-functions.R` (async consume `:332-338`; signature of `pubtator_db_update_async`)
- Modify: `api/functions/async-job-provider-handlers.R` (`.async_job_run_pubtator` caller `:116`)
- Modify: `api/functions/pubtatornidd-nightly.R` (in-process `db_config` `:189-195`; call `:197-198`)
- Modify: `api/services/publication-admin-endpoint-service.R` (async submit `:310-329`; dead closure `:331-360`; dead sync args `:237-241`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

**Interfaces:**
- Produces: `pubtator_db_update_async(query, max_pages, do_full_update = FALSE, progress_fn = NULL, ...)` — the leading `db_config` param is REMOVED. Both live callers (`.async_job_run_pubtator` at `provider-handlers.R:116`, and `pubtatornidd_nightly_run` at `pubtatornidd-nightly.R:197`) use named args, so dropping `db_config = ...` from those calls is sufficient. Verify no positional call passes `db_config` first.

- [ ] **Step 1: Migrate the async consume connect + drop the param.**
  - `pubtator-functions.R:332-338` (`pubtator_db_update_async`): replace the `DBI::dbConnect(...)` inside its `tryCatch` with `async_job_db_connect()` (keep the `error = function(e) { log_error(...); NULL }` arm). Remove the `db_config` formal from the signature (`:303`).
  - `async-job-provider-handlers.R:116`: drop `db_config = payload$db_config` from the `pubtator_db_update_async(...)` call. (This handler also forwarded `payload$db_config` ONLY to pubtator — after this, `payload$db_config` is unused here.)

- [ ] **Step 2: Remove the pubtatornidd in-process marshal.**
  - `pubtatornidd-nightly.R:189-195`: delete the in-process `db_config <- list(db_host = dw_config$host, ..., db_password = dw_config$password)` block. Update the call at `:197-198` to `pubtator_db_update_async(query = query, max_pages = max_pages, do_full_update = FALSE, progress_fn = progress_fn)` (drop `db_config = db_config`). The `dw_config` param of `pubtatornidd_nightly_run` becomes unused — leave the signature (its caller still passes it) unless removal is trivial and local.

- [ ] **Step 3: Remove the async submit credential + dead closure + dead sync args.**
  - `publication-admin-endpoint-service.R`: delete the `db_config <- list(db_host = dw$host, ..., db_password = dw$password)` block (`:310-316`) and drop `db_config = db_config` from the `submit_fn(operation = "pubtator_update", params = list(query, max_pages, clear_old, query_hash, db_config = db_config))` (`:328`) → keep `query, max_pages, clear_old, query_hash`. Remove the dead inline `executor_fn` closure (`:331-360` — unreachable; `create_job` ignores `executor_fn`).
  - `publication-admin-endpoint-service.R:237-241` (sync `svc_publication_pubtator_update`): delete the dead `db_host = dw$db_host, db_port = dw$db_port, db_name = dw$db_name, db_user = dw$db_user, db_password = dw$db_password` args from the `update_fn(...)` call (all evaluate to `NULL`; `pubtator_db_update` connects via the global pool and ignores them). Do **not** replace with `dw$password` — that would newly funnel the real password into an argument the function discards.

- [ ] **Step 4: Run guard — RED** (missing the two `publication-admin-endpoint-service.R | ...` lines, `pubtator-functions.R | ...`, and `pubtatornidd-nightly.R | ...`).

- [ ] **Step 5: Shrink frozen set + add resolver-presence.** Remove `"publication-admin-endpoint-service.R | db_password = dw$db_password,"`, `"publication-admin-endpoint-service.R | db_password = dw$password"`, `"pubtator-functions.R | password = db_config$db_password,"`, `"pubtatornidd-nightly.R | db_password = dw_config$password"`. Add `.expect_resolves_creds("functions/pubtator-functions.R")`.

- [ ] **Step 6: Run guard — GREEN.**

- [ ] **Step 7: Commit.**

```bash
git add api/functions/pubtator-functions.R api/functions/async-job-provider-handlers.R \
        api/functions/pubtatornidd-nightly.R api/services/publication-admin-endpoint-service.R \
        api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for pubtator_update/pubtatornidd_nightly (#535 S2b)"
```

---

### Task 6: llm_generation (last family → frozen set becomes empty)

**Files:**
- Modify: `api/functions/llm-batch-generator.R` (submit build `:176-200`, params `:210`; consume `:283-306`)
- Modify (guard): `api/tests/testthat/test-unit-job-payload-credential-guard.R`

- [ ] **Step 1: Migrate the consume connect + drop orphaned reads.**
  - `llm-batch-generator.R:296-313` (`llm_batch_executor`): replace the `tryCatch({ DBI::dbConnect(RMariaDB::MariaDB(), host = db_config$db_host, ..., password = db_config$db_password) }, error = ...)` block with:
    ```r
    daemon_conn <- tryCatch(
      async_job_db_connect(),
      error = function(e) {
        log_debug("ERROR: Database connection failed: ", e$message)
        message("[LLM-Executor] ERROR: Database connection failed: ", e$message)
        NULL
      }
    )
    ```
    Keep everything after (null-check → `on.exit` disconnect → `base::assign("daemon_db_conn", daemon_conn, envir = .GlobalEnv)`) unchanged.
  - Delete the orphaned reads: `db_config <- params$db_config` (`:283`), the `if (is.null(db_config)) { ... return(list(success = FALSE, error = "No database config")) }` guard (`:290-294`), and the `log_debug("Creating database connection: host=", db_config$db_host, ", db=", db_config$db_name)` (`:298`). (These now reference an absent payload field; the resolver's own error path replaces the guard.)

- [ ] **Step 2: Remove the submit credential + build block + validate/log.**
  - `llm-batch-generator.R`: delete the `db_config <- list(db_host = db_cfg$host, ..., db_password = db_cfg$password)` construction (`:176-189`) and the surrounding `cfg <- config::get(...)`/`db_cfg <- ...` reads if used only for `db_config` (`:180-188`), the `if (is.null(db_config) || is.null(db_config$db_user)) { ... }` submit gate (`:197`), and the `message("[LLM-Batch] db_config loaded: ...")` (`:202`). Drop `db_config = db_config` from the `create_job(operation = "llm_generation", params = list(...))` (`:210`), keeping `clusters, cluster_type, parent_job_id, force`.
    - Behavioral note (intended): the submit-time "could not read config" abort moves to run time inside `async_job_db_connect()` (which `stop()`s with a non-echoing error). Acceptable and documented.

- [ ] **Step 3: Run guard — RED** (missing both `llm-batch-generator.R | ...` lines).

- [ ] **Step 4: Empty the frozen set + finalize the test.**
  - Remove `"llm-batch-generator.R | db_password = db_cfg$password"` and `"llm-batch-generator.R | password = db_config$db_password"`. The `expected` vector is now empty: `expected <- sort(character(0))`. Update the test name/`info` to state the invariant is now "no credential-in-payload site remains in any durable family (backup must never reappear)".
  - Add `.expect_resolves_creds("functions/llm-batch-generator.R")` to the resolver-presence test.
  - Keep the bypass tripwire test (`db_config = dw`) and the backup exact-string test unchanged.

- [ ] **Step 5: Run guard — GREEN.**

  Run: `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"`
  Expected: PASS (empty offender set; six migrated files resolve via `async_job_db_connect()`; bypass tripwire clean).

- [ ] **Step 6: Commit.**

```bash
git add api/functions/llm-batch-generator.R api/tests/testthat/test-unit-job-payload-credential-guard.R
git commit -m "fix(security): resolve DB creds at run time for llm_generation; frozen credential set now empty (#535 S2b)"
```

---

### Task 7: Update existing container tests that construct `db_config` payloads

**Files (verify + modify as needed):**
- `api/tests/testthat/test-unit-pubtator-functions.R` (calls `pubtator_db_update_async` — drop the removed `db_config` arg; stub `async_job_db_connect`/`dw` if it opened a real conn)
- `api/tests/testthat/test-unit-admin-endpoint-services.R` (may assert `.svc_admin_ontology_db_config`/params shape)
- `api/tests/testthat/test-unit-pubtatornidd-nightly.R` (may pass `dw_config`/assert the in-process `db_config`)
- `api/tests/testthat/test-llm-batch.R` / `test-unit-llm-regenerate.R` (may build a `db_config` payload for `trigger_llm_batch_generation`/`llm_batch_executor`)
- `api/tests/testthat/test-publication-refresh.R`, `test-unit-async-job-maintenance-handlers.R`, `test-unit-async-job-handlers.R`, `test-unit-job-endpoint-services.R`, `test-unit-ontology-refresh-chains-mapping.R`

- [ ] **Step 1: Grep the test suite for the removed surface.**

  Run: `cd api && grep -rn "db_config\|\.svc_admin_ontology_db_config\|\.svc_admin_publication_refresh_db_config\|dw_config" tests/testthat/`
  For each hit: if it constructs a `db_config` payload for a migrated submit, drop it; if it calls a migrated handler/`pubtator_db_update_async` with a `db_config` arg, drop the arg; if it asserts a removed helper exists, delete/adjust the assertion. Where a test needs a live connection from `async_job_db_connect()`, inject via the resolver's `runtime_config` seam — the resolver accepts `async_job_worker_db_config(runtime_config = <list>)`, but `async_job_db_connect()` reads global `dw`; for unit tests, set a global `dw <- <test cfg>` in a local env or mock `async_job_db_connect` to return the test connection.

- [ ] **Step 2: Run each modified test file in the container.**

  For each changed file:
  ```bash
  docker cp api/tests/testthat/<file> sysndd-api-1:/app/tests/testthat/ && \
  docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"
  ```
  Expected: PASS (no `db_config`-shape failures; handlers resolve creds).

- [ ] **Step 3: Commit.**

```bash
git add api/tests/testthat/
git commit -m "test: update durable-job tests for run-time DB credential resolution (#535 S2b)"
```

---

### Task 8: Widen the historical-payload scrub to all families + both JSON paths

**Why:** S2's `async_job_scrub_payload_credentials()` is deliberately **backup-only** and redacts only `$.db_config.password`. Its comment states the narrow scope exists *because "other durable families still READ payload$db_config$password until S2b migrates them, so scrubbing their rows would break queued/retryable jobs."* After Tasks 1–6, **no** handler reads the payload credential, so it is now safe to scrub the migrated families' historical **terminal** rows. Two families (pubtator, llm) persisted the password under `$.db_config.db_password`, which the current statement misses. Without this, new payloads are clean but old rows keep leaking until credential rotation.

**Files:**
- Modify: `api/functions/async-job-payload-scrub.R` (`async_job_payload_scrub_statement()`, module header, startup log message)
- Modify: `api/tests/testthat/test-unit-async-job-payload-scrub.R`

**Interfaces:**
- Produces: `async_job_payload_scrub_statement(sentinel)` — now job-type-agnostic and redacts **both** `$.db_config.password` and `$.db_config.db_password`, preserving the exact terminal + `active_request_hash IS NULL` + not-already-sentinel guards.

- [ ] **Step 1: Write the failing test (non-backup + `db_password`-path rows are scrubbed; retryable rows are not).**
  Extend `test-unit-async-job-payload-scrub.R` with statement-shape assertions (string checks — no DB needed, matching the file's existing style):
  ```r
  test_that("scrub covers all families and both credential JSON paths", {
    stmt <- async_job_payload_scrub_statement("X")
    # both paths redacted in payload + hash recompute
    expect_true(grepl("\\$\\.db_config\\.password", stmt))
    expect_true(grepl("\\$\\.db_config\\.db_password", stmt))
    # job-type-agnostic: no backup-only WHERE filter
    expect_false(grepl("job_type IN \\('backup_create'", stmt))
    # terminal + non-retryable guards preserved (UNIQUE(active_request_hash) safety)
    expect_true(grepl("status IN \\('completed','failed','cancelled'\\)", stmt))
    expect_true(grepl("active_request_hash IS NULL", stmt))
  })
  ```

- [ ] **Step 2: Run it — expect RED.**

  Run: `docker cp api/tests/testthat/test-unit-async-job-payload-scrub.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-async-job-payload-scrub.R')"`
  Expected: FAIL (statement is backup-only, single path).

- [ ] **Step 3: Widen the statement.** Rewrite `async_job_payload_scrub_statement()` to use `JSON_REPLACE` (which is a no-op on absent paths — never creates a key, unlike `JSON_SET`) over both paths, drop the `job_type IN (...)` filter, and broaden the existence guard:
  ```r
  async_job_payload_scrub_statement <- function(sentinel = ASYNC_JOB_PAYLOAD_SCRUB_SENTINEL) {
    sprintf(
      paste0(
        "UPDATE async_jobs\n",
        "SET request_hash = SHA2(CONCAT(job_type, ':', ",
        "JSON_REPLACE(request_payload_json, ",
        "'$.db_config.password', '%s', '$.db_config.db_password', '%s')), 256),\n",
        "    request_payload_json = JSON_REPLACE(request_payload_json, ",
        "'$.db_config.password', '%s', '$.db_config.db_password', '%s')\n",
        "WHERE status IN ('completed','failed','cancelled')\n",
        "  AND active_request_hash IS NULL\n",
        "  AND (JSON_EXTRACT(request_payload_json, '$.db_config.password') IS NOT NULL\n",
        "       OR JSON_EXTRACT(request_payload_json, '$.db_config.db_password') IS NOT NULL)\n",
        "  AND (JSON_UNQUOTE(JSON_EXTRACT(request_payload_json, '$.db_config.password')) <> '%s'\n",
        "       OR JSON_UNQUOTE(JSON_EXTRACT(request_payload_json, '$.db_config.db_password')) <> '%s')"
      ),
      sentinel, sentinel, sentinel, sentinel, sentinel, sentinel
    )
  }
  ```
  Update the module header comment (scope is now "all durable families, terminal non-retryable rows, both `db_config.password` and `db_config.db_password` paths") and the startup log message from "terminal backup payload row(s)" to "terminal job payload row(s)".
  - IMPORTANT: keep `active_request_hash IS NULL` — it is the guard against the `UNIQUE(job_type, active_request_hash)` collision S2 hit; do NOT drop it while widening.

- [ ] **Step 4: Run it — expect GREEN.**

  Run: `docker cp api/tests/testthat/test-unit-async-job-payload-scrub.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-async-job-payload-scrub.R')"`
  Expected: PASS (including the pre-existing backup scrub tests — backup rows are still scrubbed by the job-type-agnostic statement).

- [ ] **Step 5: Commit.**

```bash
git add api/functions/async-job-payload-scrub.R api/tests/testthat/test-unit-async-job-payload-scrub.R
git commit -m "fix(security): scrub historical DB creds from all durable job payloads, both JSON paths (#535 S2b)"
```

---

### Task 9: Documentation

**Files:**
- Modify: `AGENTS.md` (Background jobs section — the S2 paragraph ends "The remaining durable families … still carry `db_config` in payload and are migrated to the same resolver in **S2b**")
- Modify: `documentation/09-deployment.qmd` (the "migrated … in a follow-up (S2b)" note)
- Modify: `.planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md` ("Scope boundary" S2b note, optional)

- [ ] **Step 1: Flip the AGENTS.md S2b note to "done".** Change the S2 paragraph's closing sentence from "The remaining durable families (publication/hgnc/ontology/comparisons/omim/provider/pubtator/llm-batch) still carry `db_config` in payload and are migrated to the same resolver in **S2b**; …" to: "**All** durable families now resolve DB credentials at run time via `async_job_worker_db_config()` — no job payload carries `db_config`/`password` (#535 S2b); the static guard `test-unit-job-payload-credential-guard.R` freezes the offender set at **empty** and fails on any new credential-in-payload site. The historical-payload scrub (`async_job_payload_scrub_statement()`) is now job-type-agnostic and redacts both `$.db_config.password` and `$.db_config.db_password` for terminal non-retryable rows."

- [ ] **Step 2: Update `documentation/09-deployment.qmd`** so the S2b deferral line reads that all durable families are migrated (credential resolved at run time; historical terminal rows scrubbed on both JSON paths; rotation still an operator step because prior payloads/backups/logs may retain the old password).

- [ ] **Step 3: Commit.**

```bash
git add AGENTS.md documentation/09-deployment.qmd .planning/superpowers/plans/2026-07-11-security-535-s2-backup-credentials-plan.md
git commit -m "docs: all durable job families resolve DB creds at run time (#535 S2b)"
```

---

### Task 10: Full verification

- [ ] **Step 1: Static guard (host).** `cd api/tests/testthat && Rscript --no-init-file -e "testthat::test_file('test-unit-job-payload-credential-guard.R')"` → PASS, empty offender set.
- [ ] **Step 2: File-size ratchet.** `make code-quality-audit` → PASS (all touched files shrank).
- [ ] **Step 3: Container test suite** for the touched families (Task 7 files + `test-unit-async-job-db-config.R`, `test-unit-async-job-payload-scrub.R`) → PASS.
- [ ] **Step 4: API lint (host).** `make lint-api` (or `cd api && Rscript -e "lintr::lint_dir('functions'); lintr::lint_dir('services')"`) → no new issues in touched files.
- [ ] **Step 5 (live, if a dev stack is available):** restart the worker (`docker compose restart worker worker-maintenance`), submit one migrated job (e.g. `POST /api/jobs/comparisons_update/submit` or a small `publication_refresh`), and confirm (a) the job completes, and (b) `SELECT request_payload_json FROM async_jobs WHERE job_type='comparisons_update' ORDER BY submitted_at DESC LIMIT 1` contains **no** `password`/`db_config`. The masking effects only surface in the fully-loaded worker env, so prefer this over unit tests alone.
- [ ] **Step 6:** `make test-api-fast` as the PR gate.

---

## Risks & review focus (Codex bait)

- **`async_job_db_connect()` must work in every consumer's process.** Verified: all migrated handlers run **in the durable worker** (`start_async_worker.R` sources `load_modules.R`, never `setup_workers.R`/mirai; handlers dispatch in-process via `async_job_worker_main`), and both API + worker set a global `dw`. If any migrated path can execute in a mirai daemon (which lacks `dw`), the resolver `stop()`s — confirm no such path exists for these job types.
- **Field-name shapes differ** (`dbname/host/user/password/port` vs `db_*`-prefixed vs an ignored `server`). The resolver returns the canonical shape and each consume site is fully replaced (not field-mapped), so drift is irrelevant post-migration — but confirm no consumer reads a `db_config` field **outside** the connect (verified none do except the two llm `log_debug`/`message` lines, which Task 6 removes).
- **Empty `params = list()`** for hgnc/comparisons: confirm `async_job_service_submit(request_payload = list())` serializes/hashes/dedupes cleanly (omim already submits its dup-check with `list()`).
- **`pubtator_db_update_async` signature change**: three call sites (one dead-removed, two live named-arg). Confirm no positional `db_config` caller remains and that the container `test-unit-pubtator-functions.R` is updated.
- **Dead `executor_fn` closures**: removed only where they build/consume `db_config` (directly credential-related). Full dead-`executor_fn` removal is S8; this PR removes only the credential-bearing closures to avoid leaving `params$db_config` references dangling.
- **Two-level consume lines** (`payload$db_config$password`) are migrated for correctness but are invisible to the one-level guard pattern; the resolver-presence assertions are the positive guarantee they were actually migrated.
