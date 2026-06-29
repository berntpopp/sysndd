# Verified Publication Dates Implementation Plan (#460)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make publication dates verifiable end-to-end: the `publication_refresh` job persists `publication_date_source`, a durable Administrator-triggerable backfill job re-verifies legacy rows against PubMed, and verified dates surface (already) through the API/MCP with the year in `recommended_citation`.

**Architecture:** One small correctness patch to the existing `publication_refresh` handler; factor the existing standalone backfill script's core into a shared function loaded by both the API and the worker; register a durable async handler around it; add an Administrator endpoint to trigger + inspect it. No schema change (column `publication_date_source` already exists).

**Tech Stack:** R / Plumber, durable MySQL-backed async jobs (System B), NCBI E-utilities via `pubmed_fetch_xml()` / `info_from_pmid()`, testthat.

## Global Constraints

- **No manuscript references in any file.** Frame as temporal/provenance queryability.
- **No new external provider** — PubMed EUtils only; no Crossref. Unresolvable PMIDs stay `unverified`.
- **Do not widen the `external-budget-guard` static test** to cover the PubMed helpers (out of scope; the dedicated job carries its own chunking + NCBI rate-limit).
- Confidence derivation is fixed (`api/services/mcp-service.R:283-293`): `pubmed`→`pubmed_verified`; `pubmed_partial`/`medline_date`→`pubmed_partial`; `unknown`/`NA`→`unverified`. Do not change it.
- `recommended_citation` already includes the date for trusted rows — **no citation-format change**.
- New source files registered in `api/bootstrap/load_modules.R`; new endpoint files mounted via `mount_endpoint()` in `api/bootstrap/mount_endpoints.R`, more-specific prefix before `/api/admin`.
- Worker needs NCBI egress (already on the `proxy` network). `DBI::dbBind()` `?` placeholders need `unname(params)`.
- Auth-sensitive: admin trigger guarded by `require_role(req, res, "Administrator")`.
- Tests mock `pubmed_fetch_xml` / `info_from_pmid` — no live NCBI in CI.

---

### Task 1: `publication_refresh` persists `publication_date_source` (latent bug)

**Files:**
- Modify: `api/functions/async-job-handlers.R` (`.async_job_run_publication_refresh`, UPDATE at `:782-791`)
- Test: `api/tests/testthat/test-unit-publication-refresh-source.R` (Create)

**Interfaces:**
- Produces: the per-PMID UPDATE now sets `publication_date_source` from the `info_from_pmid()` result (which already returns it).

- [ ] **Step 1: Write the failing static-guard test**

```r
# api/tests/testthat/test-unit-publication-refresh-source.R
test_that("publication_refresh UPDATE persists publication_date_source", {
  src <- readLines(file.path(get_api_dir(), "functions", "async-job-handlers.R"))
  body <- paste(src, collapse = "\n")
  # The publication UPDATE must set publication_date_source, not only Publication_date.
  expect_match(body, "publication_date_source\\s*=", fixed = FALSE)
})
```

- [ ] **Step 2: Run; verify FAIL**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-refresh-source.R')"`
Expected: FAIL (current UPDATE omits the source column).

- [ ] **Step 3: Add `publication_date_source` to the existing UPDATE.** **Codebase-verified:** the handler (`:782-800`) uses `db_execute_statement(<sql>, list(...))` with `WHERE publication_id = ?` bound to `pmid`, and `info <- info_from_pmid(pmid)` already returns a `publication_date_source` column (`publication-functions.R:428-463`). Insert `publication_date_source = ?` into the SET list and bind `info$publication_date_source[1]` in the matching params position:

```r
rows_affected <- db_execute_statement(
  "UPDATE publication SET
      Title = ?, Abstract = ?, Publication_date = ?,
      publication_date_source = ?,                 -- NEW
      Journal = ?, Keywords = ?, Lastname = ?, Firstname = ?, update_date = NOW()
    WHERE publication_id = ?",
  list(
    info$Title[1], info$Abstract[1], info$Publication_date[1],
    info$publication_date_source[1],               -- NEW (same position as the new column)
    info$Journal[1], info$Keywords[1], info$Lastname[1], info$Firstname[1],
    pmid
  )
)
```

- [ ] **Step 4: Run; verify PASS** — same command as Step 2.

> **Codex-verified note:** the durable handler signature is
> `.async_job_run_publication_refresh(job, payload, state, worker_config)` (`:758`) — NOT
> `(payload, conn, progress)`. Invoking it directly in a unit test is heavy (it needs a
> `job` row, `state`, and `worker_config`), so Task 1 is intentionally a **static guard
> only**; the source-persistence behavior is exercised end-to-end by the shared-function
> test in Task 2 (which tests the same UPDATE columns through `backfill_publication_dates_run`).
> The publication key column is `publication_id` (a prefixed string, e.g. `PMID:123`), not a
> bare numeric `PMID` — never seed/query a `PMID` column.

- [ ] **Step 5: Commit**

```bash
git add api/functions/async-job-handlers.R api/tests/testthat/test-unit-publication-refresh-source.R
git commit -m "fix(api): publication_refresh persists publication_date_source so refreshed rows verify (#460)"
```

---

### Task 2: Shared backfill function; standalone script becomes a thin wrapper

**Files:**
- Create: `api/functions/publication-date-backfill.R`
- Modify: `api/bootstrap/load_modules.R` (register the new module)
- Modify: `db/updates/backfill_publication_dates.R` (call the shared function)
- Test: `api/tests/testthat/test-unit-publication-date-backfill.R` (Create)

**Interfaces:**
- Produces: `backfill_publication_dates_run(conn, limit = NULL, dry_run = FALSE, progress = NULL)` → `list(targeted = <int>, verified = <int>, partial = <int>, unresolved = <int>, dry_run = <lgl>)`. Single-flights via `GET_LOCK('sysndd_backfill_publication_dates', 0)`; selects primary-approved publications with `publication_date_source` NULL/invalid; chunked ≤200/req; NCBI rate-limit; transactional batched UPDATE of `Publication_date` + `publication_date_source`.

- [ ] **Step 1: Write the failing test** (target selection + writes both columns, PubMed mocked):

```r
# api/tests/testthat/test-unit-publication-date-backfill.R
# NOTE: publication key is `publication_id` (prefixed string, e.g. "PMID:999100"); there is
# no bare numeric PMID column. Seed publication_id + a primary-approved review join.
test_that("backfill selects unverified primary-approved rows and writes both columns", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, publication_id = "PMID:999100", source = NULL)
    # info_from_pmid returns one row per fetched PMID with Publication_date + publication_date_source
    local_mocked_bindings(info_from_pmid = function(pmid_value, ...) dplyr::tibble(
      Publication_date = as.Date("2019-03-01"), publication_date_source = "pubmed"),
      .package = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = FALSE)
    expect_gte(res$targeted, 1L); expect_equal(res$verified, 1L)
    got <- DBI::dbGetQuery(conn,
      "SELECT Publication_date, publication_date_source FROM publication WHERE publication_id = 'PMID:999100'")
    expect_equal(got$publication_date_source, "pubmed")
    expect_equal(as.character(got$Publication_date), "2019-03-01")
  })
})

test_that("dry_run reports targets without writing", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, publication_id = "PMID:999101", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = TRUE)
    expect_gte(res$targeted, 1L); expect_equal(res$verified, 0L)
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999101'")
    expect_true(is.na(got$publication_date_source))
  })
})
```

(`seed_primary_approved_publication()` is a small test helper seeding `publication` +
`ndd_review_publication_join` (`is_reviewed=1`) + `ndd_entity_review` (`is_primary=1`,
`review_approved=1`), mirroring the join in `db/updates/backfill_publication_dates.R:102-111`.)

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`

- [ ] **Step 3: Extract the shared function by lifting the script's existing logic verbatim.** **Codex-verified** — do NOT re-derive the SQL; the standalone script already keys on `publication_id` and has a per-PMID fallback that must be preserved:
  - **Target query** (`:102-111`, lift verbatim) selects `DISTINCT p.publication_id` (NOT `PMID`):
    ```sql
    SELECT DISTINCT p.publication_id, p.Publication_date AS old_date, p.publication_date_source AS old_source
      FROM publication p
      JOIN ndd_review_publication_join rpj ON rpj.publication_id = p.publication_id AND rpj.is_reviewed = 1
      JOIN ndd_entity_review er ON er.review_id = rpj.review_id AND er.is_primary = 1 AND er.review_approved = 1
     WHERE p.publication_date_source IS NULL
        OR p.publication_date_source NOT IN ('pubmed','pubmed_partial','medline_date','unknown')
    ```
  - **UPDATE** (`:183`, lift verbatim) keys on `publication_id`:
    ```sql
    UPDATE publication SET Publication_date = ?, publication_date_source = ? WHERE publication_id = ?
    ```
  - **Per-PMID fallback (`:120-159`, MUST preserve):** the script chunk-fetches via `info_from_pmid` and, on a chunk error, falls back to single-PMID `fetch_one` fetches so one bad PMID doesn't fail the whole chunk/job. Copy that fallback into the shared function — do not replace it with a single bulk fetch that aborts the chunk.

  Wrap the lifted logic in `backfill_publication_dates_run(conn, limit = NULL, dry_run = FALSE, progress = NULL)`: acquire `GET_LOCK('sysndd_backfill_publication_dates', 0)` (return `skipped="lock_held"` if not acquired, `RELEASE_LOCK` on exit), apply `limit` via `utils::head`, short-circuit on `dry_run` returning `list(targeted, verified=0L, partial=0L, unresolved=0L, dry_run=TRUE)`, otherwise chunk (≤200), fetch (with the per-PMID fallback), `DBI::dbWithTransaction` batched UPDATE keyed on `publication_id`, `Sys.sleep(0.34)` NCBI rate-gate between chunks, call `progress(...)` if non-NULL, and return `list(targeted, verified, partial, unresolved, dry_run=FALSE)`. The `verified`/`partial`/`unresolved` counters derive from `publication_date_source` (`pubmed`→verified; `pubmed_partial`/`medline_date`→partial; `NA`/`unknown`→unresolved).

- [ ] **Step 4: Register the module** in `api/bootstrap/load_modules.R`. Then **rewrite the standalone script** `db/updates/backfill_publication_dates.R` to source the runtime + parse `--dry-run/--apply/--limit` and call `backfill_publication_dates_run(conn, limit, dry_run)`, preserving the operator CLI.

- [ ] **Step 5: Run; verify PASS** — same command as Step 2.

- [ ] **Step 6: Commit**

```bash
git add api/functions/publication-date-backfill.R api/bootstrap/load_modules.R db/updates/backfill_publication_dates.R api/tests/testthat/test-unit-publication-date-backfill.R
git commit -m "refactor(api): shared verified-date backfill function reused by script + worker (#460)"
```

---

### Task 3: Durable async handler

**Files:**
- Modify: `api/functions/async-job-handlers.R` (new `.async_job_run_publication_date_backfill` + registry entry in `async_job_handler_registry`, near `:924`)
- Test: `api/tests/testthat/test-unit-publication-date-backfill.R` (extend)

**Interfaces:**
- Consumes: `backfill_publication_dates_run` (Task 2).
- Produces: registered handler `publication_date_backfill`; returns the run summary into `result_json`.

- [ ] **Step 1: Write the failing registration test.** **Codex-verified:** `async_job_handler_registry` is a **list object** (`async-job-handlers.R:834`), not a function — use `names(...)` directly:

```r
test_that("publication_date_backfill handler is registered", {
  expect_true("publication_date_backfill" %in% names(async_job_handler_registry))
})
```

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`

- [ ] **Step 3: Add the handler + registry entry.** **Codex-verified:** durable handlers take `(job, payload, state, worker_config)` (e.g. `.async_job_run_publication_refresh` `:758`), open their own DB connection from the worker config, and create a progress reporter via `.async_job_progress_reporter(job$job_id[[1]])`. Model the skip/fail semantics on the pubtatornidd/ontology-mapping handlers (benign skip completes successfully; hard failure marks the job failed):

```r
.async_job_run_publication_date_backfill <- function(job, payload, state, worker_config) {
  reporter <- .async_job_progress_reporter(job$job_id[[1]])
  conn <- async_job_open_connection(worker_config)        # mirror the DB-open used by other handlers
  on.exit(pool::poolReturn(conn), add = TRUE)             # align to the actual connection lifecycle
  res <- backfill_publication_dates_run(
    conn,
    limit   = payload$limit %||% NULL,
    dry_run = isTRUE(payload$dry_run),
    progress = function(stage, ...) reporter(stage, ...)
  )
  list(status = "success", summary = res)
}
# add to the async_job_handler_registry <- list( ... ) object:
#   publication_date_backfill = .async_job_run_publication_date_backfill,
```

(Read an existing handler `:758-832` + the registry `:834-929` to copy the exact DB-open + reporter idiom; `async_job_open_connection`/`pool::poolReturn` above are placeholders for whatever those handlers actually use.)

- [ ] **Step 4: Run; verify PASS** — same command.

- [ ] **Step 5: Commit**

```bash
git add api/functions/async-job-handlers.R api/tests/testthat/test-unit-publication-date-backfill.R
git commit -m "feat(api): durable publication_date_backfill async job (#460)"
```

---

### Task 4: Administrator trigger + status endpoints

**Files:**
- Create: `api/endpoints/admin_publications_endpoints.R`
- Modify: `api/bootstrap/mount_endpoints.R` (mount `/api/admin/publications` before `/api/admin`)
- Test: `api/tests/testthat/test-unit-admin-publications-endpoint-guard.R` (Create)

**Interfaces:**
- Produces: `POST /api/admin/publications/verify-dates` (optional `limit`, `dry_run`) → enqueues the durable job; `GET /api/admin/publications/verify-dates/status` → last-run summary from job history. Both `require_role(..., "Administrator")`.

- [ ] **Step 1: Write the failing guard test** (model on `test-unit-admin-snapshot-endpoint-guard.R`):

```r
test_that("verify-dates endpoints require Administrator and are mounted via mount_endpoint", {
  src <- readLines(file.path(get_api_dir(), "endpoints", "admin_publications_endpoints.R"))
  body <- paste(src, collapse = "\n")
  expect_match(body, 'require_role\\([^)]*"Administrator"')
  mnt <- paste(readLines(file.path(get_api_dir(), "bootstrap", "mount_endpoints.R")), collapse = "\n")
  expect_match(mnt, "/api/admin/publications")
  # more-specific prefix mounted before /api/admin
  expect_lt(regexpr("/api/admin/publications", mnt)[1], regexpr('"/api/admin"', mnt)[1])
})
```

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-admin-publications-endpoint-guard.R')"`

- [ ] **Step 3: Write the endpoint file** with `@post /verify-dates` (enqueue via the existing `create_job`/submit path used by other admin job triggers) and `@get /verify-dates/status` (read last `publication_date_backfill` job from history), each calling `require_role(req, res, "Administrator")`.

- [ ] **Step 4: Mount it** in `api/bootstrap/mount_endpoints.R` via `mount_endpoint("/api/admin/publications", "endpoints/admin_publications_endpoints.R")` placed **before** the `/api/admin` mount line.

- [ ] **Step 5: Run; verify PASS** — same command as Step 2.

- [ ] **Step 6: Commit**

```bash
git add api/endpoints/admin_publications_endpoints.R api/bootstrap/mount_endpoints.R api/tests/testthat/test-unit-admin-publications-endpoint-guard.R
git commit -m "feat(api): Administrator endpoints to trigger + inspect verified-date backfill (#460)"
```

---

### Task 5: MCP verified-citation confirmation + run

**Files:**
- Test: `api/tests/testthat/test-mcp-publication-context-verified.R` (Create)
- Operational: run the backfill

**Interfaces:**
- Consumes: a verified `publication_date_source` (after running the backfill); confirms `mcp_publication_record` output unchanged-but-now-trusted.

- [ ] **Step 1: Write the test** — a row with `publication_date_source = 'pubmed'` yields `publication_date_confidence = "pubmed_verified"` and a year-bearing `recommended_citation`:

```r
# Codex-verified: mcp_get_publication_context(pmid, abstract_max_chars, abstract_mode) takes a
# SINGLE prefixed pmid and NO conn (it opens its own approved-public read). Batch variant is
# mcp_get_publications_context(pmids, ...).
test_that("verified publication yields pubmed_verified confidence and a dated citation", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, publication_id = "PMID:999200",
                                      source = "pubmed", pub_date = "2018-07-15")
    rec <- mcp_get_publication_context("PMID:999200")
    expect_equal(rec$publication_date_confidence, "pubmed_verified")
    expect_match(rec$recommended_citation, "2018")
  })
})
```

(Confirm the exact result shape against `mcp-record-service.R:188-193` and the existing MCP
record-service tests — `mcp_get_publication_context` returns the single record object.)

- [ ] **Step 2: Run; verify PASS** (the derivation + citation logic already supports this once the source is set) — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-publication-context-verified.R')"`

- [ ] **Step 3: Run the backfill** post-deploy (operator triggers `POST /api/admin/publications/verify-dates`, or runs `Rscript db/updates/backfill_publication_dates.R --apply`). Confirm via `GET /api/admin/publications/verify-dates/status` that `verified + partial` rose and `unresolved` is bounded.

- [ ] **Step 4: Commit the test**

```bash
git add api/tests/testthat/test-mcp-publication-context-verified.R
git commit -m "test(mcp): verified publication date yields trusted confidence + dated citation (#460)"
```

---

## Self-Review

- **Spec coverage:** Fix 1 refresh-persists-source (T1); Fix 2 shared fn + thin wrapper (T2) + durable handler (T3) + admin endpoints (T4); Fix 3 run + MCP confirmation (T5); fallback for unverifiable PMIDs is `NULL`/`unknown`→`unverified` (unchanged derivation, asserted indirectly in T2 `unresolved` counter). ✅
- **Placeholder scan:** "align to actual code" notes (handler signature in T1/T3, `create_job` submit path in T4, MCP call shape in T5) are explicit read-the-file instructions with named targets, not deferred work. No TODO/TBD.
- **Type consistency:** `backfill_publication_dates_run(conn, limit, dry_run, progress)` return list (`targeted/verified/partial/unresolved/dry_run`) is consumed consistently in T3 handler and T4 status; `seed_primary_approved_publication(conn, pmid, source, …)` helper referenced consistently across T2/T5.

## Execution sequencing

T1 (independent) → T2 → T3 → T4 → T5. Ships in parallel with the cluster-validation plan (no shared files).
