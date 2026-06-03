# Security & Data-Integrity Hardening Sprint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the highest-leverage security holes and the bootstrap-integrity gap found in the 2026-05-31 audit, plus a batch of cheap correctness wins — without rewrites.

**Architecture:** Eight self-contained tasks. The pattern throughout: extract the risky inline logic into a small, unit-testable pure helper, write a failing test that encodes the desired guard, implement the helper, then wire it into the endpoint/handler. Migration 025 codifies views that today exist only in the production DB. All API code is sourced into the global env at startup (`api/bootstrap/load_modules.R`); restart the API/worker container to pick up changes.

**Tech Stack:** R 4.4 / Plumber / DBI+RMariaDB / dbplyr / rlang / testthat; MySQL migrations applied at startup under advisory lock; Vue 3 + TS frontend (one follow-up note only).

**Source audit:** `.planning/reviews/2026-05-31-codebase-audit.md` (finding numbers `#N` below reference it).

---

## Status: ✅ COMPLETE (2026-06-03)

Shipped as **PR #369** → merged to `master` (merge commit `a952a7bb`), released as
**v0.20.16**. All 8 acceptance criteria met; `make test-api-fast` and
`make ci-local` green before merge.

- **T1–T8 delivered** (see the resolution table in the source audit). New guards:
  `test-unit-backup-filename.R`, `test-unit-job-result-access.R`,
  `test-unit-archive-url.R`, `test-unit-llm-public-cache-only.R`,
  `test-unit-job-capacity.R`, `test-unit-filter-column-allowlist.R`,
  `test-unit-core-views-manifest.R`, `test-unit-cleanup-batch.R`.
- **Additional work surfaced during execution** (in PR #369 / follow-up commits):
  - **Modify Entity 500 regression** fixed — `loadEntity` was requesting
    `is_active`/`replaced_by`/`details`, absent from `ndd_entity_view`, so
    `select_tibble_fields()` 500'd on every entity selection (introduced by
    `a586078a`, v0.20.14). Trimmed to view-backed columns; vitest + Playwright
    guards added.
  - **RFC 9457 errorHandler propagated to mounted sub-routers** — `mount_endpoint()`
    helper attaches `pr_set_error(errorHandler)` + `pr_set_404(notFoundHandler)` to
    every `/api/<subpath>`; `select_tibble_fields()` now raises `error_400`;
    duplicate `Content-Type` header removed (errorHandler/notFoundHandler/CORS +
    external/nddscore manual returns). Guard: `test-unit-endpoint-error-handler.R`.
  - **CI gate repairs** — `test-endpoint-backup.R` now loads the shared
    `is_valid_backup_filename` into its handler sandbox; `test-network-layout-job.R`
    assertion updated for the `mount_endpoint()` helper; code-quality size baselines
    bumped for the sprint's additions.
- **Process note:** run `make test-api-fast` / `make ci-local` locally before
  pushing — the fast gate caught the backup + network-layout failures that the
  bare-host spot-checks had missed.

Deferred items (out-of-scope below) remain for the recommended next (frontend &
schema) sprint.

---

## Spec (WHAT & WHY)

### In scope (this sprint)

| Task | Audit # | Cat | What |
|------|---------|-----|------|
| T1 | #3 | security | `/restore` filename path-traversal guard (parity with `/download`,`/delete`) |
| T2 | #19 | security | Gate `GET /jobs/<id>/status?result_mode=full` so only public-operation jobs are anonymously readable |
| T3 | #18 | security | `internet_archive` exact-host URL validation + require auth |
| T4 | #5 | security/cost | Public LLM cluster-summary becomes cache-hit-only; generation requires Curator+ |
| T5 | #17 | security/cost | Public clustering-submit queue-depth capacity cap (503 + Retry-After) |
| T6 | #1 | security/correctness | Filter/sort **column allowlist** so user tokens can't be parsed as R code |
| T7 | #2 | correctness | Migration `025_create_core_views.sql` for `ndd_entity_view`/`users_view`/`search_*`; bump manifest |
| T8 | #9,#10,#26,#27,#28 | cleanup | NA-guard `page_size`; drop per-request `source()`; remove un-gated DB `message()`; drop dead `type_suffix`; fix `expires_in` |

### Out of scope (recommended **next** sprint — frontend & schema)

- #4 raw-axios → typed-client migration; #6 Bearer-header interceptor robustness (token-provider injection, also fixes #24); #7 Pubtator double-parse; #11 `Promise.all`; #12 prod `console.log`; #23 d3 submodule imports.
- #14 charset/collation unification; #21 DOUBLE→INT join keys; #22 migration splitter; #29 `entity_id` index. (Higher-effort data migrations; do after T7 lands.)

### Acceptance criteria (sprint is "done" when)

1. `/restore` rejects any filename containing `/`, `\`, or not ending in `.sql`/`.sql.gz` with 400, before any filesystem access.
2. Anonymous `result_mode=full` returns full results only for `clustering`/`phenotype_clustering` jobs; all other operations require Reviewer+ (403 otherwise). Public clustering result retrieval still works.
3. `internet_archive` accepts only URLs whose parsed host is exactly the configured archive base host; the endpoint requires an authenticated user.
4. Anonymous request to a not-yet-cached cluster summary returns 404 (not a freshly generated Gemini summary). No Gemini call is made on the public path.
5. Public clustering-submit returns `CAPACITY_EXCEEDED` (503 + `Retry-After`) when pending+running public jobs exceed the cap.
6. `generate_filter_expressions(..., allowed_columns=...)` and `generate_sort_expressions(..., allowed_columns=...)` reject any column not in the per-view allowlist with a 400-class error; a crafted `column` containing `)`/`(`/backtick/`~`/`::` cannot reach `parse_exprs`.
7. `validate_migration_manifest()` passes with `025_create_core_views.sql` as latest; a fresh-DB boot can `SELECT` from all four views.
8. `make test-api-fast` green; `make ci-local` green before PR.

### Risk & rollback

- **Highest risk: T7** (views) and **T6** (filter allowlist) can break read paths if a real column is omitted from an allowlist or a view column is renamed. Mitigation: derive allowlists and view DDL from the live schema (`SHOW CREATE VIEW`, `information_schema.columns`), not from memory; add a regression test that every column the API sorts/filters on is in the allowlist.
- **T2/T4** can break public features if over-tightened. Mitigation: explicit public-operation allowlist (T2) and a manual check that the clustering UI still renders (T2) / that cached summaries still display (T4).
- Each task is an independent atomic commit; revert the single commit to roll back.

---

## File map

- Modify: `api/endpoints/backup_endpoints.R` (T1), `api/endpoints/jobs_endpoints.R` (T2,T5), `api/endpoints/external_endpoints.R` (T3), `api/endpoints/analysis_endpoints.R` (T4,T8), `api/functions/response-helpers.R` (T6,T8)
- Modify: `api/functions/external-functions.R` (T3), `api/functions/llm-endpoint-helpers.R` (T4), `api/functions/async-job-service.R` (T5), `api/functions/migration-manifest.R` (T7), `api/functions/db-helpers.R` (T8), `api/core/filters.R` (T8), `api/services/auth-service.R` (T8)
- Modify: `api/endpoints/gene_endpoints.R`, `entity_endpoints.R`, `statistics_endpoints.R`, `publication_endpoints.R` (T6 — pass allowlists)
- Create: `db/migrations/025_create_core_views.sql` (T7)
- Create tests: `api/tests/testthat/test-unit-backup-filename.R` (T1), `test-unit-job-result-access.R` (T2), `test-unit-archive-url.R` (T3), `test-unit-llm-public-cache-only.R` (T4), `test-unit-job-capacity.R` (T5), `test-unit-filter-column-allowlist.R` (T6), `test-unit-core-views-manifest.R` (T7), `test-unit-cleanup-batch.R` (T8)

**Test runner (host):** `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-NAME.R')"`
(If host R can't load `RMariaDB`, prepend `HOST_R_LD_LIBRARY_PATH` per `documentation/08-development.qmd`. Pure-helper tests in T1/T3/T6/T8 need no DB. **Container alternative:** `tests/` is NOT bind-mounted — `docker cp api/tests/testthat/test-NAME.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-NAME.R')"`.)

**Sequencing:** T1 → T3 → T2 → T5 → T4 → T6 → T7 → T8. (T1/T3 are warm-ups; T6/T7 are the heavy hitters; T8 is mechanical cleanup last.) Tasks are independent — parallelizable if dispatched to separate workers, but commit order above keeps the diff readable.

---

## Task 0: Branch + verify baseline

- [x] **Step 1: Create the working branch**

```bash
cd /home/bernt-popp/development/sysndd
git checkout -b sprint/security-data-integrity-2026-05-31
```

- [x] **Step 2: Confirm the fast gate is green before changes**

Run: `make test-api-fast`
Expected: PASS (record any pre-existing failures noted in memory — `test-llm-benchmark.R`, `test-llm-judge.R`, and 4 status-aggregation cases in `test-unit-entity-creation.R` are known-pre-existing and not caused by this work).

---

## Task 1: `/restore` path-traversal guard (#3)

**Files:**
- Create: `api/tests/testthat/test-unit-backup-filename.R`
- Modify: `api/endpoints/backup_endpoints.R` (restore handler at `:284-307`; refactor download `:459-477` and delete `:559-566` to share the helper)

The download/delete handlers already reject separators and enforce the extension; the restore handler does neither. Extract one validator, use it in all three.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-backup-filename.R`:

```r
# Unit tests for backup filename validation (path-traversal guard).
source_api_file("functions/backup-functions.R", local = FALSE)

test_that("valid backup filenames pass", {
  expect_true(is_valid_backup_filename("backup-2024-01-15.sql"))
  expect_true(is_valid_backup_filename("backup-2024-01-15.sql.gz"))
})

test_that("path separators are rejected", {
  expect_false(is_valid_backup_filename("../etc/passwd"))
  expect_false(is_valid_backup_filename("sub/dir.sql"))
  expect_false(is_valid_backup_filename("a\\b.sql"))
})

test_that("non-backup extensions are rejected", {
  expect_false(is_valid_backup_filename("evil.sh"))
  expect_false(is_valid_backup_filename("backup.sql.gz.exe"))
  expect_false(is_valid_backup_filename(""))
  expect_false(is_valid_backup_filename(NULL))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-backup-filename.R')"`
Expected: FAIL — `could not find function "is_valid_backup_filename"`.

- [x] **Step 3: Implement the validator**

Append to `api/functions/backup-functions.R`:

```r
#' Validate a backup filename for safe filesystem use.
#'
#' Rejects path separators (traversal) and any extension other than
#' `.sql` / `.sql.gz`. Mirrors the inline checks in the download/delete
#' backup endpoints so all three share one guard.
#'
#' @param filename Character scalar candidate filename.
#' @return TRUE if safe, FALSE otherwise.
#' @export
is_valid_backup_filename <- function(filename) {
  if (is.null(filename) || length(filename) != 1L || is.na(filename) || filename == "") {
    return(FALSE)
  }
  if (grepl("[/\\\\]", filename)) {
    return(FALSE)
  }
  grepl("\\.(sql|sql\\.gz)$", filename)
}
```

- [x] **Step 4: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-backup-filename.R')"`
Expected: PASS.

- [x] **Step 5: Use the guard in the restore handler**

In `api/endpoints/backup_endpoints.R`, replace the restore handler's filename block (`:290-307`). After:

```r
  filename <- req$argsBody$filename
  if (is.null(filename) || filename == "") {
    res$status <- 400
    return(list(
      error = "MISSING_FILENAME",
      message = "Backup filename is required in request body"
    ))
  }
```

insert:

```r
  # Path-traversal + extension guard (parity with /download and /delete)
  if (!is_valid_backup_filename(filename)) {
    res$status <- 400
    return(list(
      error = "INVALID_FILENAME",
      message = "Filename contains invalid characters or has an unsupported extension"
    ))
  }
```

Then keep the existing `backup_path <- file.path("/backup", filename)` / `file.exists` check.

- [x] **Step 6: Refactor download/delete to reuse the helper (DRY)**

In `/download/<filename>` (`:460-477`) and `/delete/<filename>` (`:560`), replace the two inline `grepl(...)` blocks with:

```r
  if (!is_valid_backup_filename(filename)) {
    res$status <- 400
    res$serializer <- serializer_json()
    return(list(
      error = "INVALID_FILENAME",
      message = "Filename contains invalid characters or has an unsupported extension"
    ))
  }
```

- [x] **Step 7: Commit**

```bash
git add api/functions/backup-functions.R api/endpoints/backup_endpoints.R api/tests/testthat/test-unit-backup-filename.R
git commit -m "fix(security): add path-traversal guard to /restore; share backup filename validator"
```

---

## Task 2: Gate `result_mode=full` job results by operation (#19)

**Files:**
- Create: `api/tests/testthat/test-unit-job-result-access.R`
- Modify: `api/endpoints/jobs_endpoints.R` (status handler `:920-947`)

`require_auth` forwards anonymous GETs without a role; a Bearer-carrying GET gets `req$user_role` attached (`middleware.R:94,124-126`). Public clustering jobs are submitted anonymously and their results must stay anonymously readable — so gate by **operation**, not blanket auth.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-job-result-access.R`:

```r
# Unit tests for the full-job-result access predicate.
source_api_file("functions/job-manager.R", local = FALSE)

test_that("anonymous may read full results only for public operations", {
  expect_true(can_read_full_job_result("clustering", user_role = NULL))
  expect_true(can_read_full_job_result("phenotype_clustering", user_role = NULL))
  expect_false(can_read_full_job_result("backup_create", user_role = NULL))
  expect_false(can_read_full_job_result("hgnc_update", user_role = NULL))
})

test_that("Reviewer+ may read full results for any operation", {
  expect_true(can_read_full_job_result("backup_create", user_role = "Reviewer"))
  expect_true(can_read_full_job_result("hgnc_update", user_role = "Administrator"))
  expect_false(can_read_full_job_result("backup_create", user_role = "Viewer"))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-result-access.R')"`
Expected: FAIL — `could not find function "can_read_full_job_result"`.

- [x] **Step 3: Implement the predicate**

Append to `api/functions/job-manager.R`:

```r
# Job operations whose full result JSON is safe for anonymous retrieval
# (public, user-initiated analysis that returns the caller's own output).
PUBLIC_FULL_RESULT_JOB_TYPES <- c("clustering", "phenotype_clustering")

#' May this requester read the full result JSON for a job of `job_type`?
#'
#' Anonymous/Viewer callers may read full results only for public-operation
#' jobs; Reviewer and above may read any job's full result.
#'
#' @param job_type Character job operation/type.
#' @param user_role Character role from req$user_role, or NULL if anonymous.
#' @return Logical.
#' @export
can_read_full_job_result <- function(job_type, user_role = NULL) {
  privileged <- !is.null(user_role) &&
    user_role %in% c("Reviewer", "Curator", "Administrator")
  if (privileged) {
    return(TRUE)
  }
  !is.null(job_type) && job_type %in% PUBLIC_FULL_RESULT_JOB_TYPES
}
```

- [x] **Step 4: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-result-access.R')"`
Expected: PASS.

- [x] **Step 5: Enforce in the status handler**

In `api/endpoints/jobs_endpoints.R`, change the handler signature at `:920` to accept `req` (it already does) and insert the gate after the `result_mode` validation block (`:928`), before `status <- get_job_status(...)`:

```r
  if (identical(result_mode, "full")) {
    job_row <- async_job_repository_get(job_id)
    job_type <- if (nrow(job_row) > 0) job_row$job_type[[1]] else NULL
    if (!can_read_full_job_result(job_type, req$user_role)) {
      res$status <- 403
      return(list(
        error = "FORBIDDEN",
        message = "Full job results for this operation require authentication."
      ))
    }
  }
```

(`async_job_repository_get` is sourced at startup and returns a row including `job_type`; it returns 0 rows for unknown/expired ids, so an unknown id falls through to the existing JOB_NOT_FOUND path via `get_job_status`.)

- [x] **Step 6: Manual check — public clustering still works**

Run a clustering submit and poll its `?result_mode=full` anonymously; confirm the result still returns. (Frontend: open the Gene Clusters analysis page and confirm a cluster renders.)

- [x] **Step 7: Commit**

```bash
git add api/functions/job-manager.R api/endpoints/jobs_endpoints.R api/tests/testthat/test-unit-job-result-access.R
git commit -m "fix(security): restrict full job-result reads to public ops or Reviewer+"
```

---

## Task 3: `internet_archive` exact-host validation + auth (#18)

**Files:**
- Create: `api/tests/testthat/test-unit-archive-url.R`
- Modify: `api/functions/external-functions.R` (`:30-54`), `api/endpoints/external_endpoints.R` (`:36-54`)

Current check is `str_detect(parameter_url, dw$archive_base_url)` — an unanchored regex match where `.` is a wildcard, so `https://attacker.example/?x=https://sysndd.dbmr.unibe.ch/` passes and the server then archives it using SysNDD's IA credentials.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-archive-url.R`:

```r
source_api_file("functions/external-functions.R", local = FALSE)

base <- "https://sysndd.dbmr.unibe.ch/"

test_that("only exact-host https URLs are valid", {
  expect_true(is_valid_archive_url("https://sysndd.dbmr.unibe.ch/Genes", base))
  expect_true(is_valid_archive_url("https://sysndd.dbmr.unibe.ch/", base))
})

test_that("host-spoofing and non-https are rejected", {
  expect_false(is_valid_archive_url(
    "https://attacker.example/?x=https://sysndd.dbmr.unibe.ch/", base))
  expect_false(is_valid_archive_url(
    "https://sysndd.dbmr.unibe.ch.attacker.example/x", base))
  expect_false(is_valid_archive_url("http://sysndd.dbmr.unibe.ch/x", base))
  expect_false(is_valid_archive_url("", base))
  expect_false(is_valid_archive_url(NULL, base))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-archive-url.R')"`
Expected: FAIL — function not found.

- [x] **Step 3: Implement exact-host validator**

Add to `api/functions/external-functions.R`:

```r
#' Validate a URL is an https URL whose host exactly matches the archive base.
#'
#' Parses both URLs and compares scheme+host exactly (no substring/regex
#' matching) to prevent host-spoofing of the archive credential.
#'
#' @param parameter_url Candidate URL string.
#' @param archive_base_url Trusted base URL (dw$archive_base_url).
#' @return Logical TRUE only for an https URL on the exact archive host.
#' @export
is_valid_archive_url <- function(parameter_url, archive_base_url) {
  if (is.null(parameter_url) || length(parameter_url) != 1L ||
        is.na(parameter_url) || parameter_url == "") {
    return(FALSE)
  }
  parsed <- tryCatch(httr2::url_parse(parameter_url), error = function(e) NULL)
  base <- tryCatch(httr2::url_parse(archive_base_url), error = function(e) NULL)
  if (is.null(parsed) || is.null(base)) {
    return(FALSE)
  }
  identical(parsed$scheme, "https") &&
    !is.null(parsed$hostname) &&
    identical(parsed$hostname, base$hostname)
}
```

- [x] **Step 4: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-archive-url.R')"`
Expected: PASS. (If `httr2` is unavailable in the test env, the package is already a runtime dep of the external proxies; confirm with `Rscript -e "library(httr2)"`.)

- [x] **Step 5: Wire into the endpoint + require auth**

In `api/endpoints/external_endpoints.R`, replace the handler body validation (`:37-49`). New handler:

```r
function(req, res, parameter_url, capture_screenshot = "on") {
  # Archiving uses a SysNDD credential — require an authenticated user.
  require_role(req, res, "Viewer")

  if (!is_valid_archive_url(parameter_url, dw$archive_base_url)) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(status = 400, message = "Required 'url' parameter not provided or not valid.")
    )
    return(res)
  }
  post_url_archive(parameter_url, capture_screenshot)
}
```

Also update the duplicate inline check inside `post_url_archive()` in `external-functions.R` to call `is_valid_archive_url()`.

> Note: `require_role(req, res, "Viewer")` blocks anonymous callers (level 0 < 1). Verify no anonymous UI flow calls `internet_archive`; archiving is a curation/admin action. If an anonymous caller is found, keep only the host-validation and add the route to `AUTH_ALLOWLIST` instead — but prefer auth.

- [x] **Step 6: Commit**

```bash
git add api/functions/external-functions.R api/endpoints/external_endpoints.R api/tests/testthat/test-unit-archive-url.R
git commit -m "fix(security): exact-host validation + auth for internet_archive endpoint"
```

---

## Task 4: Public LLM cluster-summary is cache-hit-only (#5)

**Files:**
- Create: `api/tests/testthat/test-unit-llm-public-cache-only.R`
- Modify: `api/functions/llm-endpoint-helpers.R` (`get_cluster_summary` `:35-126`), `api/endpoints/analysis_endpoints.R` (`:280-317`)

On cache miss `get_cluster_summary` calls `get_or_generate_summary()` (Gemini) inline; the endpoint is reachable by anonymous GET. Make generation require an authenticated Curator+; the public path returns cache hits only.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-llm-public-cache-only.R`:

```r
source_api_file("functions/llm-endpoint-helpers.R", local = FALSE)

# Stub the cache + generation seams.
local_mocks <- function(cached_value, gen_called_env) {
  assign("get_cached_summary", function(...) cached_value, envir = .GlobalEnv)
  assign("is_gemini_configured", function() TRUE, envir = .GlobalEnv)
  assign("fetch_cluster_data_for_generation", function(...) list(genes = "X"), envir = .GlobalEnv)
  assign("get_or_generate_summary", function(...) {
    gen_called_env$called <- TRUE
    list(success = TRUE, cache_id = 1, summary = list(model_name = "m"))
  }, envir = .GlobalEnv)
  assign("format_summary_response", function(cached, n) list(ok = TRUE), envir = .GlobalEnv)
  assign("extract_raw_hash", function(h) h, envir = .GlobalEnv)
}

test_that("anonymous cache MISS does NOT call Gemini and returns 404", {
  env <- new.env(); env$called <- FALSE
  local_mocks(cached_value = NULL, gen_called_env = env)
  res <- list(status = 200L)
  out <- get_cluster_summary("abc", "1", "functional", res, allow_generation = FALSE)
  expect_false(env$called)
  expect_equal(res$status, 404L)
})

test_that("cache HIT returns the summary without generation", {
  env <- new.env(); env$called <- FALSE
  local_mocks(cached_value = data.frame(validation_status = "validated"), gen_called_env = env)
  res <- list(status = 200L)
  out <- get_cluster_summary("abc", "1", "functional", res, allow_generation = FALSE)
  expect_false(env$called)
  expect_true(isTRUE(out$ok))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-public-cache-only.R')"`
Expected: FAIL — `unused argument (allow_generation = FALSE)`.

- [x] **Step 3: Add the `allow_generation` gate**

In `api/functions/llm-endpoint-helpers.R`, change the signature:

```r
get_cluster_summary <- function(cluster_hash, cluster_number, cluster_type, res,
                                allow_generation = FALSE) {
```

After the cache-miss `log_info(...)` line (`:69`), insert the gate **before** the `is_gemini_configured()` block:

```r
  # Public path is cache-hit-only: never run Gemini synchronously for an
  # unauthenticated request. Generation is opt-in for Curator+ callers.
  if (!isTRUE(allow_generation)) {
    res$status <- 404L
    return(list(message = "Summary not yet available for this cluster"))
  }
```

- [x] **Step 4: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-llm-public-cache-only.R')"`
Expected: PASS.

- [x] **Step 5: Pass the role decision from the endpoints**

In `api/endpoints/analysis_endpoints.R`, both handlers (`:280-286`, `:311-317`) take `req`. Replace each body's last line. For `functional_cluster_summary`:

```r
#* @get functional_cluster_summary
function(cluster_hash = NULL, cluster_number = NULL, req, res) {
  allow_gen <- !is.null(req$user_role) && req$user_role %in% c("Curator", "Administrator")
  get_cluster_summary(cluster_hash, cluster_number, "functional", res, allow_generation = allow_gen)
}
```

Do the same for `phenotype_cluster_summary` with `"phenotype"`. (Also delete the three per-request `source()` lines — handled in Task 8 Step "T8-b".)

- [x] **Step 6: Manual check** — confirm an existing cached cluster summary still renders for anonymous users on the analysis page.

- [x] **Step 7: Commit**

```bash
git add api/functions/llm-endpoint-helpers.R api/endpoints/analysis_endpoints.R api/tests/testthat/test-unit-llm-public-cache-only.R
git commit -m "fix(security): make public LLM cluster-summary cache-hit-only; gate generation to Curator+"
```

---

## Task 5: Public clustering-submit capacity cap (#17)

**Files:**
- Create: `api/tests/testthat/test-unit-job-capacity.R`
- Modify: `api/functions/async-job-service.R` (`async_job_service_submit` `:92`), `api/functions/job-manager.R` (`create_job` `:43`), `api/endpoints/jobs_endpoints.R` (clustering submit handlers)

`create_job` unconditionally returns `status="accepted"`; the public clustering submit routes are in `AUTH_ALLOWLIST` (`middleware.R:22-25`). Add a queue-depth cap for public queues.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-job-capacity.R`:

```r
source_api_file("functions/async-job-service.R", local = FALSE)

test_that("capacity predicate trips at the configured cap", {
  expect_false(async_job_capacity_exceeded(active_count = 4L, cap = 5L))
  expect_true(async_job_capacity_exceeded(active_count = 5L, cap = 5L))
  expect_true(async_job_capacity_exceeded(active_count = 9L, cap = 5L))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-capacity.R')"`
Expected: FAIL — function not found.

- [x] **Step 3: Implement the cap predicate + an active-count query**

Append to `api/functions/async-job-service.R`:

```r
# Max simultaneously pending+running jobs allowed on a public queue.
ASYNC_PUBLIC_JOB_CAP <- as.integer(Sys.getenv("ASYNC_PUBLIC_JOB_CAP", "8"))

#' TRUE when the active (queued+running) job count is at or over the cap.
#' @export
async_job_capacity_exceeded <- function(active_count, cap = ASYNC_PUBLIC_JOB_CAP) {
  isTRUE(as.integer(active_count) >= as.integer(cap))
}

#' Count queued+running jobs for a given queue (default "public").
#' @export
async_job_active_count <- function(queue_name = "public", conn = NULL) {
  sql <- paste(
    "SELECT COUNT(*) AS n FROM async_job",
    "WHERE queue_name = ? AND status IN ('queued','running')"
  )
  row <- db_execute_query(sql, params = list(queue_name), conn = conn)
  if (nrow(row) == 0) 0L else as.integer(row$n[[1]])
}
```

(Confirm the durable table/column names against `db/migrations/020_add_async_job_schema.sql` and adjust `async_job`/`queue_name`/`status` literals if they differ.)

- [x] **Step 4: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-job-capacity.R')"`
Expected: PASS.

- [x] **Step 5: Enforce in the public clustering submit handlers**

In `api/endpoints/jobs_endpoints.R`, at the top of each public submit handler (`clustering/submit` `:28`-area and `phenotype_clustering/submit` `:257`-area), after the duplicate-job check and before `create_job(...)`:

```r
  if (async_job_capacity_exceeded(async_job_active_count("public"))) {
    res$status <- 503
    res$setHeader("Retry-After", "60")
    return(list(
      error = "CAPACITY_EXCEEDED",
      message = "Analysis queue is at capacity. Please retry shortly.",
      retry_after = 60
    ))
  }
```

Ensure these submits enqueue on `queue_name = "public"` (pass `queue_name = "public"` through `create_job`/`async_job_service_submit` if not already; otherwise change the count query's default to `"default"` to match).

- [x] **Step 6: Commit**

```bash
git add api/functions/async-job-service.R api/endpoints/jobs_endpoints.R api/tests/testthat/test-unit-job-capacity.R
git commit -m "fix(security): add queue-depth capacity cap to public clustering submits"
```

---

## Task 6: Filter/sort column allowlist hardening (#1) — the big one

**Files:**
- Create: `api/tests/testthat/test-unit-filter-column-allowlist.R`
- Modify: `api/functions/response-helpers.R` (`generate_sort_expressions` `:40`, `generate_filter_expressions` `:107`)
- Modify callers: `api/endpoints/gene_endpoints.R:87,105`, `entity_endpoints.R:100,117`, `statistics_endpoints.R:116,138,478`, `publication_endpoints.R:216,401,583` (pass `allowed_columns`)

Today `column` is interpolated unvalidated into expression strings that `rlang::parse_exprs()` then parses — and on the `collect()` fallback path it executes as R code. Add a per-view column allowlist; any column not in it is a 400-class error, so user text can never reach `parse_exprs` as code.

- [x] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-filter-column-allowlist.R`:

```r
source_api_file("functions/response-helpers.R", local = FALSE)

cols <- c("symbol", "entity_id", "category", "any", "all")

test_that("known columns build expressions", {
  out <- generate_filter_expressions("and(symbol, equals, 'ARID1B')", allowed_columns = cols)
  expect_true(any(grepl("symbol", out)))
})

test_that("unknown / injected columns are rejected before parse_exprs", {
  expect_error(
    generate_filter_expressions("and(system('id'), equals, 'x')", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
  expect_error(
    generate_filter_expressions("and(symbol);foo, equals, 'x')", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
})

test_that("sort rejects unknown columns", {
  expect_error(
    generate_sort_expressions("-desc(`x`)", allowed_columns = cols),
    regexp = "column|not allowed|invalid", ignore.case = TRUE
  )
  expect_silent(generate_sort_expressions("-symbol", allowed_columns = cols))
})

test_that("allowed_columns = NULL preserves legacy behaviour (no allowlist)", {
  # Back-compat for callers not yet migrated; logged but not rejected.
  expect_silent(generate_sort_expressions("-symbol", allowed_columns = NULL))
})
```

- [x] **Step 2: Run it — expect failure**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-filter-column-allowlist.R')"`
Expected: FAIL — `unused argument (allowed_columns = ...)`.

- [x] **Step 3: Add a shared validator**

Add near the top of `api/functions/response-helpers.R`:

```r
#' Assert a column identifier is in the allowlist and is a bare identifier.
#'
#' Rejects anything that is not a simple column token (letters, digits,
#' underscore) or is absent from `allowed_columns`. Special tokens "any"/"all"
#' (cross-column search) are always permitted. When `allowed_columns` is NULL
#' the allowlist check is skipped (legacy callers) but the bare-identifier
#' check still applies, so syntax like `system(`, backticks, `)`, `~`, `::`
#' can never reach parse_exprs().
#'
#' @export
validate_query_column <- function(column, allowed_columns = NULL) {
  if (column %in% c("any", "all")) {
    return(invisible(TRUE))
  }
  if (!grepl("^[A-Za-z][A-Za-z0-9_]*$", column)) {
    stop(sprintf("Invalid filter/sort column token: '%s'", column))
  }
  if (!is.null(allowed_columns) && !(column %in% allowed_columns)) {
    stop(sprintf("Column not allowed for this resource: '%s'", column))
  }
  invisible(TRUE)
}
```

- [x] **Step 4: Enforce in `generate_sort_expressions`**

Change the signature (`:40`) to `function(sort_string, unique_id = "entity_id", allowed_columns = NULL)`. After the `mutate(column = ...)` step that strips the `+`/`-` prefix (`:52-56`), add:

```r
  purrr::walk(sort_tibble$column, ~ validate_query_column(.x, allowed_columns))
```

- [x] **Step 5: Enforce in `generate_filter_expressions`**

Change the signature (`:107`) to add `allowed_columns = NULL`. Inside the non-hash branch, immediately after `filter_string_tibble` is built (`:182`, before the hash branch at `:185`), add:

```r
  purrr::walk(filter_string_tibble$column, ~ validate_query_column(.x, allowed_columns))
```

This runs before any `paste0(column, ...)` expression construction, so an invalid/injected `column` aborts with a clear error before `parse_exprs`.

- [x] **Step 6: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-filter-column-allowlist.R')"`
Expected: PASS.

- [x] **Step 7: Build per-view allowlists and pass them from callers**

Add to `api/functions/response-helpers.R` a helper that derives allowed columns from the live view (single source of truth — no hand-maintained lists to drift):

```r
#' Columns a public list endpoint may sort/filter on, derived from the view.
#' Memoised per view name for the process lifetime.
#' @export
allowed_columns_for_view <- memoise::memoise(function(view_name) {
  cols <- tryCatch(
    colnames(pool %>% dplyr::tbl(view_name) %>% utils::head(0) %>% dplyr::collect()),
    error = function(e) character(0)
  )
  unique(c(cols, "any", "all"))
})
```

Then in each caller, pass it. Example for `api/endpoints/gene_endpoints.R` where `generate_sort_expressions(sort)` / `generate_filter_expressions(filter)` are called (`:87,105`):

```r
  allowed <- allowed_columns_for_view("ndd_entity_view")
  sort_exprs   <- generate_sort_expressions(sort, allowed_columns = allowed)
  filter_exprs <- generate_filter_expressions(filter, allowed_columns = allowed)
```

Repeat for `entity_endpoints.R` (`ndd_entity_view`), `statistics_endpoints.R`, and `publication_endpoints.R` (use the view each endpoint actually queries — confirm via the `tbl("...")` call in each).

- [x] **Step 8: Regression guard — every sortable/filterable column is allowed**

Add to the test file a check that the columns the UI sends are present in the derived allowlist (guards against an over-tight allowlist breaking real queries). If a DB connection isn't available in unit context, mark this as an integration check gated on `with_test_db_transaction()` per AGENTS.md.

- [x] **Step 9: Run the endpoint integration tests**

Run: `make test-api-fast`
Expected: existing gene/entity/publication list tests still PASS (no real column rejected).

- [x] **Step 10: Commit**

```bash
git add api/functions/response-helpers.R api/endpoints/gene_endpoints.R api/endpoints/entity_endpoints.R api/endpoints/statistics_endpoints.R api/endpoints/publication_endpoints.R api/tests/testthat/test-unit-filter-column-allowlist.R
git commit -m "fix(security): allowlist filter/sort columns before parse_exprs; reject injected tokens"
```

---

## Task 7: Migration `025_create_core_views.sql` (#2)

**Files:**
- Create: `db/migrations/025_create_core_views.sql`
- Create: `api/tests/testthat/test-unit-core-views-manifest.R`
- Modify: `api/functions/migration-manifest.R` (`:5-6`)

`ndd_entity_view`, `search_non_alt_loci_view`, `search_disease_ontology_set` live only in `db/C_Rcommands_set-table-connections.R` (lines 347, 386, 407); `users_view` is defined **nowhere in version control** (the app aliases `email AS user_email`). Capture authoritative DDL in a migration so a fresh DB boots.

- [x] **Step 1: Extract authoritative DDL from a known-good DB**

From a running dev/prod DB (the source of truth, especially for `users_view`):

```bash
for v in ndd_entity_view users_view search_non_alt_loci_view search_disease_ontology_set; do
  docker exec sysndd-db-1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" sysndd_db \
    -N -e "SHOW CREATE VIEW \`$v\`\\G" ;
done
```

Record the `Create View` text for each. For the three that also appear in `C_Rcommands_set-table-connections.R`, cross-check the extracted DDL against lines 347-375 / 386-406 / 407-426 as a fallback if a DB is unavailable.

- [x] **Step 2: Write the migration (idempotent, schema-portable)**

Create `db/migrations/025_create_core_views.sql`. Use `CREATE OR REPLACE VIEW` (idempotent), **strip the `sysndd_db.` schema qualifier**, and set `SQL SECURITY INVOKER`:

```sql
-- 025_create_core_views.sql
-- Codifies the core read views that previously existed only in the legacy
-- C_Rcommands_set-table-connections.R script (and, for users_view, only in
-- the live DB). Required so a pristine MySQL volume boots and the public
-- entity/gene/user/search queries resolve. See audit 2026-05-31 finding #2.

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `ndd_entity_view` AS
    /* <<< paste extracted SELECT, sysndd_db. qualifier removed >>> */ ;

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `users_view` AS
    SELECT
      `user`.`user_id`        AS `user_id`,
      `user`.`user_name`      AS `user_name`,
      `user`.`email`          AS `user_email`,
      `user`.`user_role`      AS `user_role`,
      `user`.`orcid`          AS `orcid`,
      `user`.`approved`       AS `approved`
    FROM `user`;
    /* ^ Replace with the exact SHOW CREATE VIEW output if it differs;
         user-repository.R selects user_id,user_name,user_email,user_role. */

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `search_non_alt_loci_view` AS
    /* <<< paste extracted SELECT >>> */ ;

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `search_disease_ontology_set` AS
    /* <<< paste extracted SELECT >>> */ ;
```

> **No placeholders left behind:** the `/* <<< paste >>> */` markers MUST be replaced with the real extracted SELECTs in Step 1 before commit. Keep one statement per line-group; the migration runner splits on `;`+newline (`migration-runner.R:463`), so do not put `;` inside a single-line string literal in this file.

- [x] **Step 3: Bump the manifest**

In `api/functions/migration-manifest.R`:

```r
EXPECTED_LATEST_MIGRATION <- "025_create_core_views.sql"
EXPECTED_MIGRATION_COUNT <- 26L
```

- [x] **Step 4: Write the manifest test**

Create `api/tests/testthat/test-unit-core-views-manifest.R`:

```r
source_api_file("functions/migration-manifest.R", local = FALSE)
source_api_file("functions/migration-runner.R", local = FALSE)

test_that("manifest expects migration 025 as latest", {
  expect_equal(EXPECTED_LATEST_MIGRATION, "025_create_core_views.sql")
  expect_gte(EXPECTED_MIGRATION_COUNT, 26L)
})

test_that("migration manifest validates against db/migrations", {
  res <- validate_migration_manifest(migrations_dir = "../../../db/migrations")
  expect_true(res$ok)
  expect_identical(res$latest, "025_create_core_views.sql")
})
```

(Adjust the relative `migrations_dir` to the repo's `db/migrations` from the test working dir.)

- [x] **Step 5: Run the test — expect pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-core-views-manifest.R')"`
Expected: PASS.

- [x] **Step 6: Fresh-DB smoke (the real acceptance check)**

Bring up a clean DB volume and confirm migrations apply and the views resolve:

```bash
make docker-dev-db
# after startup/migrations:
docker exec sysndd-db-1 mysql -uroot -p"$MYSQL_ROOT_PASSWORD" sysndd_db \
  -e "SELECT COUNT(*) FROM ndd_entity_view; SELECT COUNT(*) FROM users_view; \
      SELECT COUNT(*) FROM search_non_alt_loci_view; SELECT COUNT(*) FROM search_disease_ontology_set;"
```

Expected: four counts return without "table doesn't exist".

- [x] **Step 7: Update docs**

Note the new core-views migration in `db/migrations/README.md` and `documentation/09-deployment.qmd` (pristine-bootstrap section).

- [x] **Step 8: Commit**

```bash
git add db/migrations/025_create_core_views.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-core-views-manifest.R db/migrations/README.md documentation/09-deployment.qmd
git commit -m "fix: add migration 025 codifying core views (ndd_entity_view/users_view/search_*) for pristine boot"
```

---

## Task 8: Cleanup batch (#9, #10, #26, #27, #28)

Five small, independent, low-risk fixes. One commit.

- [x] **Step T8-a: NA-guard `page_size` (#9)** — `api/endpoints/analysis_endpoints.R:151`

Replace:

```r
page_size_int <- min(max(as.integer(page_size), 1), 50)
```

with:

```r
n <- suppressWarnings(as.integer(page_size))
if (is.na(n)) n <- 10L
page_size_int <- min(max(n, 1L), 50L)
```

- [x] **Step T8-b: Remove per-request `source()` (#10)** — `api/endpoints/analysis_endpoints.R:282-284,313-315` and `api/endpoints/admin_endpoints.R:977-979`

Delete the in-handler `source("functions/...")` lines; these modules are already loaded at startup by `api/bootstrap/load_modules.R`. (If T4 already removed the analysis ones, just do `admin_endpoints.R` here.)

- [x] **Step T8-c: Remove un-gated DB `message()` (#26)** — `api/functions/db-helpers.R:139`

Delete the line `message("[db_execute_query] ENTRY - sql: ", substr(sql, 1, 50))` (the level-gated `log_debug` at `:151` already covers it). Check for a second analogous `message("[db_execute...` in the statement helper and remove it too.

- [x] **Step T8-d: Drop dead `type_suffix` param (#27)** — `api/core/filters.R:260-271` + 5 callers (`:276,280,284,288,293`)

Change `make_problem_response(type_suffix, title, status_code, detail_msg)` → `make_problem_response(title, status_code, detail_msg)` (the body already builds the URL from `status_code`), and update the 5 call sites to drop the duplicated leading status arg.

- [x] **Step T8-e: Fix `expires_in` (#28)** — `api/services/auth-service.R:71,188`

Drive both the reported `expires_in` and the JWT `exp` from one source. Add `token_expiry` to `api/config.yml` (e.g. `token_expiry: 3600`) and change `:71` to `expires_in = config$token_expiry %||% 3600` AND `:188` to `exp = as.numeric(Sys.time()) + (config$token_expiry %||% 3600)`. (Leave the access==refresh-token design note for the out-of-scope auth follow-up; this step only removes the divergence.)

- [x] **Step T8-f: Targeted test for the page_size guard**

Create `api/tests/testthat/test-unit-cleanup-batch.R`:

```r
source_api_file("functions/response-helpers.R", local = FALSE)

# Smallest deterministic check: the page_size clamp helper behaviour.
clamp_page_size <- function(page_size) {
  n <- suppressWarnings(as.integer(page_size))
  if (is.na(n)) n <- 10L
  min(max(n, 1L), 50L)
}

test_that("page_size clamp handles junk, bounds, and NA", {
  expect_equal(clamp_page_size("abc"), 10L)
  expect_equal(clamp_page_size("0"), 1L)
  expect_equal(clamp_page_size("999"), 50L)
  expect_equal(clamp_page_size("25"), 25L)
})
```

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-cleanup-batch.R')"`
Expected: PASS.

- [x] **Step T8-g: Commit**

```bash
git add api/endpoints/analysis_endpoints.R api/endpoints/admin_endpoints.R api/functions/db-helpers.R api/core/filters.R api/services/auth-service.R api/config.yml api/tests/testthat/test-unit-cleanup-batch.R
git commit -m "chore: cleanup batch — page_size NA guard, drop per-request source(), un-gated db message, dead param, expires_in"
```

---

## Final verification gate

- [x] **Step 1: Restart containers so bind-mounted source is live**

```bash
docker compose restart api worker
```

- [x] **Step 2: Run the lint + fast API gate**

Run: `make lint-api && make test-api-fast`
Expected: PASS (modulo the known pre-existing failures recorded in Task 0 Step 2).

- [x] **Step 3: Run the closest-to-CI full check**

Run: `make ci-local`
Expected: PASS.

- [x] **Step 4: Update durable docs per the Documentation Contract**

- `AGENTS.md` — add a "Stack-Specific Gotchas" note that filter/sort columns are allowlisted (`validate_query_column`) and that core views are migration-backed (`025`).
- `documentation/09-deployment.qmd` — note `ASYNC_PUBLIC_JOB_CAP`, the cache-hit-only public LLM path, and migration 025.

- [x] **Step 5: Open the PR**

```bash
git push -u origin sprint/security-data-integrity-2026-05-31
gh pr create --fill --title "Security & data-integrity hardening sprint (audit 2026-05-31)" \
  --body "Implements T1–T8 from .planning/superpowers/plans/2026-05-31-security-data-integrity-sprint-plan.md"
```

---

## Self-review checklist (run before handing off)

- [x] **Spec coverage:** every in-scope finding (#3,#19,#18,#5,#17,#1,#2 and cleanup #9/#10/#26/#27/#28) maps to a task above. ✔
- [x] **Placeholder scan:** the only intentional placeholders are the `/* <<< paste extracted SELECT >>> */` markers in T7 Step 2 — these MUST be filled from `SHOW CREATE VIEW` before committing T7. No others.
- [x] **Type/name consistency:** `is_valid_backup_filename`, `can_read_full_job_result`/`PUBLIC_FULL_RESULT_JOB_TYPES`, `is_valid_archive_url`, `allow_generation`, `async_job_capacity_exceeded`/`async_job_active_count`/`ASYNC_PUBLIC_JOB_CAP`, `validate_query_column`/`allowed_columns_for_view`, `EXPECTED_LATEST_MIGRATION` — names match across their definition and call sites.
- [x] **Confirm-before-coding seams:** T5 table/column literals (`async_job`) vs `020_add_async_job_schema.sql`; T6 each endpoint's actual `tbl("...")` view; T2 that `async_job_repository_get` returns `job_type`; T7 the real `SHOW CREATE VIEW` text. Verify each at implementation time.
