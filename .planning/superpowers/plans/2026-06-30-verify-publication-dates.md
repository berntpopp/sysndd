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

- [ ] **Step 3: Read `:758-832`** to confirm the exact UPDATE string and the variable holding the `info_from_pmid` row, then add `publication_date_source` to the SET list and bind the value. Example shape (align column/param names to the actual code):

```r
DBI::dbExecute(conn,
  "UPDATE publication
      SET Publication_date = ?, publication_date_source = ?, update_date = NOW()
    WHERE PMID = ?",
  params = unname(list(row$Publication_date, row$publication_date_source, row$PMID))
)
```

- [ ] **Step 4: Add a behavioral test** with a mocked `info_from_pmid` returning a known source, asserting the row's `publication_date_source` is written (use `with_test_db_transaction`):

```r
test_that("a refreshed publication row gets its source persisted", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    DBI::dbExecute(conn, "INSERT INTO publication (PMID, publication_date_source) VALUES (999001, NULL)")
    local_mocked_bindings(info_from_pmid = function(pmid, ...) dplyr::tibble(
      PMID = 999001, Publication_date = as.Date("2020-05-01"),
      publication_date_source = "pubmed"), .package = NULL)
    .async_job_run_publication_refresh(list(pmids = 999001), conn = conn, progress = function(...) NULL)
    got <- DBI::dbGetQuery(conn, "SELECT publication_date_source FROM publication WHERE PMID = 999001")
    expect_equal(got$publication_date_source, "pubmed")
  })
})
```

(Align the handler call signature to the actual `.async_job_run_publication_refresh` interface.)

- [ ] **Step 5: Run; verify PASS** — same command as Step 2.

- [ ] **Step 6: Commit**

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
test_that("backfill selects unverified primary-approved rows and writes both columns", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    # seed a primary-approved publication with NULL source (fixtures: see test-integration-omim-snapshot-additive.R for join seeding patterns)
    seed_primary_approved_publication(conn, pmid = 999100, source = NULL)
    local_mocked_bindings(info_from_pmid = function(pmids, ...) dplyr::tibble(
      PMID = 999100, Publication_date = as.Date("2019-03-01"),
      publication_date_source = "pubmed"), .package = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = FALSE)
    expect_gte(res$targeted, 1L)
    expect_equal(res$verified, 1L)
    got <- DBI::dbGetQuery(conn, "SELECT Publication_date, publication_date_source FROM publication WHERE PMID = 999100")
    expect_equal(got$publication_date_source, "pubmed")
    expect_equal(as.character(got$Publication_date), "2019-03-01")
  })
})

test_that("dry_run reports targets without writing", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, pmid = 999101, source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = TRUE)
    expect_gte(res$targeted, 1L); expect_equal(res$verified, 0L)
    got <- DBI::dbGetQuery(conn, "SELECT publication_date_source FROM publication WHERE PMID = 999101")
    expect_true(is.na(got$publication_date_source))
  })
})
```

(Provide `seed_primary_approved_publication()` as a small test helper, or inline the inserts mirroring the join used by `db/updates/backfill_publication_dates.R:102-111`.)

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`

- [ ] **Step 3: Extract the shared function.** Read `db/updates/backfill_publication_dates.R` (target query `:102-111`, chunked fetch, rate delay `:53-54,:121`, batched UPDATE `:183`) and move its core into `backfill_publication_dates_run(conn, limit, dry_run, progress)`:

```r
# api/functions/publication-date-backfill.R
backfill_publication_dates_run <- function(conn, limit = NULL, dry_run = FALSE, progress = NULL) {
  locked <- DBI::dbGetQuery(conn, "SELECT GET_LOCK('sysndd_backfill_publication_dates', 0) AS l")$l
  if (is.na(locked) || locked != 1) return(list(targeted = 0L, verified = 0L, partial = 0L,
                                                unresolved = 0L, dry_run = dry_run, skipped = "lock_held"))
  on.exit(DBI::dbExecute(conn, "SELECT RELEASE_LOCK('sysndd_backfill_publication_dates')"), add = TRUE)

  targets <- DBI::dbGetQuery(conn,
    "SELECT DISTINCT p.PMID
       FROM publication p
       JOIN ndd_review_publication_join j ON j.publication_id = p.publication_id AND j.is_reviewed = 1
       JOIN ndd_entity_review er ON er.review_id = j.review_id
      WHERE er.is_primary = 1 AND er.review_approved = 1
        AND (p.publication_date_source IS NULL
             OR p.publication_date_source NOT IN ('pubmed','pubmed_partial','medline_date'))")$PMID
  if (!is.null(limit)) targets <- utils::head(targets, limit)
  if (!is.null(progress)) progress("select", total = length(targets))
  if (length(targets) == 0 || dry_run)
    return(list(targeted = length(targets), verified = 0L, partial = 0L,
                unresolved = 0L, dry_run = dry_run))

  verified <- 0L; partial <- 0L; unresolved <- 0L
  chunks <- split(targets, ceiling(seq_along(targets) / 200))
  for (ci in seq_along(chunks)) {
    info <- info_from_pmid(chunks[[ci]])                       # returns Publication_date + publication_date_source
    DBI::dbWithTransaction(conn, {
      for (i in seq_len(nrow(info))) {
        r <- info[i, ]
        DBI::dbExecute(conn,
          "UPDATE publication SET Publication_date = ?, publication_date_source = ? WHERE PMID = ?",
          params = unname(list(r$Publication_date, r$publication_date_source, r$PMID)))
      }
    })
    verified  <- verified  + sum(info$publication_date_source == "pubmed", na.rm = TRUE)
    partial   <- partial   + sum(info$publication_date_source %in% c("pubmed_partial","medline_date"), na.rm = TRUE)
    unresolved<- unresolved+ sum(is.na(info$publication_date_source) | info$publication_date_source == "unknown")
    Sys.sleep(0.34)                                            # NCBI rate-gate
    if (!is.null(progress)) progress("fetch", current = ci, total = length(chunks))
  }
  list(targeted = length(targets), verified = verified, partial = partial,
       unresolved = unresolved, dry_run = FALSE)
}
```

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

- [ ] **Step 1: Write the failing registration test**

```r
test_that("publication_date_backfill handler is registered", {
  reg <- async_job_handler_registry()
  expect_true("publication_date_backfill" %in% names(reg))
})
```

- [ ] **Step 2: Run; verify FAIL** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`

- [ ] **Step 3: Add the handler + registry entry** (model on the pubtatornidd/ontology-mapping handlers — benign skip completes successfully; hard failure marks the job failed):

```r
.async_job_run_publication_date_backfill <- function(payload, conn, progress = function(...) NULL) {
  res <- backfill_publication_dates_run(conn,
           limit = payload$limit %||% NULL,
           dry_run = isTRUE(payload$dry_run),
           progress = progress)
  list(status = "success", summary = res)
}
# in async_job_handler_registry():  publication_date_backfill = .async_job_run_publication_date_backfill
```

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
test_that("verified publication yields pubmed_verified confidence and a dated citation", {
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed_primary_approved_publication(conn, pmid = 999200, source = "pubmed",
                                      pub_date = "2018-07-15")
    out <- mcp_get_publication_context(list(pmids = 999200), conn = conn)
    rec <- out$publications[[1]]
    expect_equal(rec$publication_date_confidence, "pubmed_verified")
    expect_match(rec$recommended_citation, "2018")
  })
})
```

(Align `mcp_get_publication_context` call shape to the existing MCP record-service tests.)

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
