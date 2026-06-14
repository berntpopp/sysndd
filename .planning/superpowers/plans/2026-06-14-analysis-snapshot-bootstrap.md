# Analysis Snapshot Startup Bootstrap + Admin Endpoints — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-bootstrap the public `analysis_snapshot_*` snapshots on API startup, expose admin HTTP refresh/status endpoints, and unify all three submit paths behind one shared function — so public analysis pages heal automatically after a fresh deploy (#420).

**Architecture:** Mirror the merged #421 `pubtatornidd_bootstrap_enrichment()` pattern. A shared service function `service_analysis_snapshot_submit_refresh()` is called by (1) a gated, never-throws startup hook, (2) a new Administrator-only endpoint, and (3) the existing operator script. Cheap `SELECT ... LIMIT 1` existence probes keep restarts idempotent. A small frontend change turns the 503 `snapshot_missing` into a friendly "being prepared" state.

**Tech Stack:** R / Plumber (api), Vue 3 + TypeScript (app), testthat + vitest.

**Sprints (disjoint file sets → parallel-safe):**
- **A** — API core: repository reads, shared submit/status/bootstrap service, startup hook, script DRY, R tests.
- **B** — API admin endpoints: new endpoint file + mount + guard test. (Implements against A's signatures.)
- **C** — Frontend resilience: 503 → "being prepared" UX + vitest.

Interface contract locked by this plan:
```
# service (services/analysis-snapshot-service.R)
service_analysis_snapshot_submit_refresh(analysis_type=NULL, force=FALSE, presets=NULL,
    submit_fn=async_job_service_submit, exists_fn=analysis_snapshot_public_exists, conn=NULL)
  -> list(requested, submitted, reused, skipped, failed, force, results=list({analysis_type, parameter_hash, action, job_id, message}))
service_analysis_snapshot_status(presets=NULL, manifest_fn=analysis_snapshot_public_manifest, conn=NULL)
  -> list(presets=list({analysis_type, parameter_hash, state, generated_at, activated_at, stale_after, source_data_version, row_counts}), summary=list(total, available, missing, stale, mismatch))
analysis_snapshot_bootstrap_enabled() -> logical
analysis_snapshot_bootstrap_on_startup(submit_refresh_fn=..., enabled_fn=...) -> invisible(logical)
# repository (functions/analysis-snapshot-repository.R)
analysis_snapshot_public_exists(analysis_type, parameter_hash, conn=NULL) -> logical
analysis_snapshot_public_manifest(analysis_type, parameter_hash, conn=NULL, current_source_data_version=NULL) -> 1-row df (with $status_code) or NULL
```

---

## Sprint A — API core

### Task A1: Cheap repository read helpers

**Files:**
- Modify: `api/functions/analysis-snapshot-repository.R` (append after `analysis_snapshot_status_code()`, ~line 407)
- Test: covered indirectly (functions are thin SQL wrappers; behavior tested via service with injected fakes in A5)

- [ ] **Step 1: Add the two helpers** after `analysis_snapshot_status_code()`:

```r
#' Cheap existence probe for an active public-ready snapshot.
#'
#' Mirrors the public-ready predicate of `analysis_snapshot_get_public()` but
#' fetches no child-table rows — used by the startup bootstrap and admin refresh
#' to decide whether a preset still needs a refresh job.
#'
#' @return TRUE when a `public_ready = 1, status = 'public_ready'` manifest row
#'   exists for the (analysis_type, parameter_hash); FALSE otherwise.
#' @export
analysis_snapshot_public_exists <- function(analysis_type, parameter_hash, conn = NULL) {
  row <- db_execute_query(
    "SELECT snapshot_id
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND public_ready = 1
        AND status = 'public_ready'
      LIMIT 1",
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )
  nrow(row) > 0L
}

#' Metadata-only read of the active public-ready manifest row.
#'
#' Like `analysis_snapshot_get_public()` but returns just the single manifest row
#' annotated with the computed `status_code` (no network/cluster/correlation
#' child queries). Used by the admin status endpoint to report per-preset state.
#'
#' @return A 1-row data frame with an added `status_code` column, or NULL when no
#'   public-ready row exists.
#' @export
analysis_snapshot_public_manifest <- function(analysis_type,
                                              parameter_hash,
                                              conn = NULL,
                                              current_source_data_version = NULL) {
  manifest <- db_execute_query(
    "SELECT *
       FROM analysis_snapshot_manifest
      WHERE analysis_type = ?
        AND parameter_hash = ?
        AND public_ready = 1
        AND status = 'public_ready'
      ORDER BY activated_at DESC, snapshot_id DESC
      LIMIT 1",
    unname(list(analysis_type, parameter_hash)),
    conn = conn
  )

  if (nrow(manifest) == 0L) {
    return(NULL)
  }

  if (is.null(current_source_data_version) &&
    exists("analysis_snapshot_source_data_version", mode = "function")) {
    current_source_data_version <- tryCatch(
      analysis_snapshot_source_data_version(conn = conn),
      error = function(e) NULL
    )
  }

  manifest <- manifest[1, , drop = FALSE]
  if (!is.null(current_source_data_version)) {
    manifest$current_source_data_version <- as.character(current_source_data_version)[1]
  }
  manifest$status_code <- analysis_snapshot_status_code(manifest)
  manifest
}
```

- [ ] **Step 2: Lint** — `make lint-api` (or `cd api && Rscript -e "lintr::lint('functions/analysis-snapshot-repository.R')"`). Expected: no new lints.

- [ ] **Step 3: Commit**

```bash
git add api/functions/analysis-snapshot-repository.R
git commit -m "feat(api): cheap public-ready snapshot existence + manifest reads (#420)"
```

### Task A2: Shared submit + status + bootstrap service

**Files:**
- Modify: `api/services/analysis-snapshot-service.R` (append new functions at end)

- [ ] **Step 1: Append the shared functions** to `api/services/analysis-snapshot-service.R`:

```r
# --- Shared snapshot refresh submission (#420) ---------------------------------
# One submit path shared by the startup bootstrap, the admin endpoint, and the
# operator script (scripts/refresh-analysis-snapshots.R). Keep this the single
# source of submission logic.

#' Whether the startup snapshot bootstrap is enabled.
#'
#' Config gate (issue #420), implemented as an env var to match the repo's
#' sidecar/env conventions. Default enabled; set
#' `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP=false` to disable.
#' @export
analysis_snapshot_bootstrap_enabled <- function() {
  raw <- trimws(Sys.getenv("ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP", "true"))
  if (!nzchar(raw)) {
    return(TRUE)
  }
  tolower(raw) %in% c("true", "1", "yes", "on")
}

#' Submit analysis_snapshot_refresh jobs for supported presets.
#'
#' For each target preset: normalize params (canonical parameter_hash), and
#' unless `force` skip presets that already have an active public-ready snapshot,
#' then submit a durable `analysis_snapshot_refresh` job (dedup-safe). Per-preset
#' failures are isolated and reported, never thrown.
#'
#' @param analysis_type Optional single preset; NULL = all supported presets.
#' @param force When TRUE, submit even when a current snapshot exists.
#' @param presets Optional preset list (defaults to the supported presets).
#' @param submit_fn Injectable job-submit fn (default `async_job_service_submit`).
#' @param exists_fn Injectable existence probe (default `analysis_snapshot_public_exists`).
#' @param conn Optional DB connection/pool.
#' @return Structured summary list (see plan interface contract).
#' @export
service_analysis_snapshot_submit_refresh <- function(analysis_type = NULL,
                                                     force = FALSE,
                                                     presets = NULL,
                                                     submit_fn = async_job_service_submit,
                                                     exists_fn = analysis_snapshot_public_exists,
                                                     conn = NULL) {
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  if (!is.null(analysis_type)) {
    analysis_type <- as.character(analysis_type[[1]])
    presets <- Filter(function(p) identical(p$analysis_type, analysis_type), presets)
    if (length(presets) == 0L) {
      analysis_snapshot_unsupported_parameter(
        sprintf("Unsupported analysis snapshot type: %s", analysis_type),
        fields = list(analysis_type = analysis_type)
      )
    }
  }

  force <- isTRUE(force)
  results <- list()
  submitted <- 0L
  reused <- 0L
  skipped <- 0L
  failed <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash

    if (!force) {
      already <- tryCatch(exists_fn(at, ph, conn = conn), error = function(e) FALSE)
      if (isTRUE(already)) {
        skipped <- skipped + 1L
        results[[length(results) + 1L]] <- list(
          analysis_type = at, parameter_hash = ph,
          action = "skipped_existing", job_id = NA_character_,
          message = "public-ready snapshot already present"
        )
        next
      }
    }

    outcome <- tryCatch(
      submit_fn(
        job_type = "analysis_snapshot_refresh",
        request_payload = list(analysis_type = at, params = normalized$params),
        queue_name = "default",
        priority = 50L,
        conn = conn
      ),
      error = function(e) list(.error = conditionMessage(e))
    )

    if (!is.null(outcome$.error)) {
      failed <- failed + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "error", job_id = NA_character_, message = outcome$.error
      )
      next
    }

    job_id <- tryCatch(as.character(outcome$job$job_id[[1]]), error = function(e) NA_character_)
    if (isTRUE(outcome$duplicate)) {
      reused <- reused + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "reused", job_id = job_id,
        message = "existing queued/running job reused"
      )
    } else {
      submitted <- submitted + 1L
      results[[length(results) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph,
        action = "submitted", job_id = job_id, message = "refresh job submitted"
      )
    }
  }

  list(
    requested = length(presets),
    submitted = submitted,
    reused = reused,
    skipped = skipped,
    failed = failed,
    force = force,
    results = results
  )
}

#' Per-preset public snapshot status overview.
#'
#' @return list(presets = list(per-preset state), summary = counts).
#' @export
service_analysis_snapshot_status <- function(presets = NULL,
                                             manifest_fn = analysis_snapshot_public_manifest,
                                             conn = NULL) {
  if (is.null(presets)) {
    presets <- analysis_snapshot_supported_presets()
  }
  preset_states <- list()
  total <- 0L
  available <- 0L
  missing <- 0L
  stale <- 0L
  mismatch <- 0L

  for (preset in presets) {
    normalized <- analysis_snapshot_normalize_params(preset$analysis_type, preset$params)
    at <- normalized$analysis_type
    ph <- normalized$parameter_hash
    manifest <- tryCatch(manifest_fn(at, ph, conn = conn), error = function(e) NULL)
    total <- total + 1L

    if (is.null(manifest)) {
      missing <- missing + 1L
      preset_states[[length(preset_states) + 1L]] <- list(
        analysis_type = at, parameter_hash = ph, state = "missing",
        generated_at = NA_character_, activated_at = NA_character_,
        stale_after = NA_character_, source_data_version = NA_character_,
        row_counts = NULL
      )
      next
    }

    status_code <- service_analysis_snapshot_scalar_value(manifest$status_code, "available")
    state <- switch(status_code,
      available = "available",
      snapshot_stale = "stale",
      source_version_mismatch = "source_version_mismatch",
      snapshot_missing = "missing",
      status_code
    )
    if (identical(state, "available")) {
      available <- available + 1L
    } else if (identical(state, "stale")) {
      stale <- stale + 1L
    } else if (identical(state, "source_version_mismatch")) {
      mismatch <- mismatch + 1L
    } else if (identical(state, "missing")) {
      missing <- missing + 1L
    }

    preset_states[[length(preset_states) + 1L]] <- list(
      analysis_type = at,
      parameter_hash = ph,
      state = state,
      generated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$generated_at)
      ),
      activated_at = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$activated_at)
      ),
      stale_after = service_analysis_snapshot_time_string(
        service_analysis_snapshot_scalar_value(manifest$stale_after)
      ),
      source_data_version = service_analysis_snapshot_scalar_value(
        manifest$source_data_version, NA_character_
      ),
      row_counts = service_analysis_snapshot_record_counts(manifest)
    )
  }

  list(
    presets = preset_states,
    summary = list(
      total = total, available = available, missing = missing,
      stale = stale, mismatch = mismatch
    )
  )
}

#' Startup bootstrap: enqueue refresh jobs for missing presets (idempotent).
#'
#' Mirrors `pubtatornidd_bootstrap_enrichment()`. No-op when disabled; never
#' throws (callable directly in API startup).
#' @export
analysis_snapshot_bootstrap_on_startup <- function(
    submit_refresh_fn = service_analysis_snapshot_submit_refresh,
    enabled_fn = analysis_snapshot_bootstrap_enabled) {
  if (!isTRUE(enabled_fn())) {
    message("[snapshot-bootstrap] disabled via ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP; skipping")
    return(invisible(FALSE))
  }

  summary <- tryCatch(
    submit_refresh_fn(force = FALSE),
    error = function(e) {
      message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(summary)) {
    return(invisible(FALSE))
  }

  missing <- summary$requested - summary$skipped
  if (missing > 0L) {
    message(sprintf(
      "[snapshot-bootstrap] %d/%d presets missing -> submitted %d refresh jobs (reused %d, failed %d)",
      missing, summary$requested, summary$submitted, summary$reused, summary$failed
    ))
  } else {
    message("[snapshot-bootstrap] all presets present, nothing to do")
  }
  invisible(missing > 0L)
}
```

- [ ] **Step 2: Lint** — `make lint-api`. Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add api/services/analysis-snapshot-service.R
git commit -m "feat(api): shared snapshot refresh submit + status + startup bootstrap (#420)"
```

### Task A3: Wire the startup hook

**Files:**
- Modify: `api/start_sysndd_api.R` (after the pubtatornidd bootstrap block, ~line 151)

- [ ] **Step 1: Insert** immediately after the closing `)` of the existing `tryCatch(pubtatornidd_bootstrap_enrichment(), ...)` block (after line 151), before the `# 10) Run the API.` banner:

```r
## -------------------------------------------------------------------##
# 9c) Bootstrap public analysis snapshots if missing (#420): a fresh deploy
#     gets the analysis_snapshot_* tables populated so /GeneNetworks and
#     /PhenotypeClusters heal automatically instead of 503 snapshot_missing.
#     Idempotent (existence-checked) + dedup-safe; gated; never crashes boot.
## -------------------------------------------------------------------##
tryCatch(
  analysis_snapshot_bootstrap_on_startup(),
  error = function(e) {
    message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
  }
)
```

- [ ] **Step 2: Sanity-parse** — `cd api && Rscript -e "parse('start_sysndd_api.R'); cat('parse ok\n')"`. Expected: `parse ok`.

- [ ] **Step 3: Commit**

```bash
git add api/start_sysndd_api.R
git commit -m "feat(api): auto-bootstrap analysis snapshots on startup (#420)"
```

### Task A4: DRY the operator script

**Files:**
- Modify: `api/scripts/refresh-analysis-snapshots.R` (replace the inline loop, lines ~52-87)

- [ ] **Step 1: Replace** everything from `presets <- analysis_snapshot_supported_presets()` (line 52) through the final summary `message(...)` (line 87) with:

```r
presets <- analysis_snapshot_supported_presets()
message(sprintf(
  "[refresh-snapshots] forcing analysis_snapshot_refresh for %d presets on '%s'",
  length(presets), api_config
))

summary <- service_analysis_snapshot_submit_refresh(force = TRUE)

for (r in summary$results) {
  tag <- switch(r$action,
    submitted = "",
    reused = " (existing job reused)",
    error = sprintf(" ERROR: %s", r$message),
    skipped_existing = " (already present)",
    ""
  )
  message(sprintf("  %-34s job_id=%s%s", r$analysis_type, r$job_id, tag))
}

message(sprintf(
  "[refresh-snapshots] %d submitted, %d reused, %d failed of %d presets. Worker (queue 'default') will build + activate each snapshot.",
  summary$submitted, summary$reused, summary$failed, summary$requested
))
```

- [ ] **Step 2: Sanity-parse** — `cd api && Rscript -e "parse('scripts/refresh-analysis-snapshots.R'); cat('parse ok\n')"`. Expected: `parse ok`.

- [ ] **Step 3: Commit**

```bash
git add api/scripts/refresh-analysis-snapshots.R
git commit -m "refactor(api): operator snapshot script uses shared submit fn (#420)"
```

### Task A5: Unit tests (TDD-style; run to confirm)

**Files:**
- Create: `api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R`

- [ ] **Step 1: Write the test file:**

```r
# Unit tests for the analysis snapshot startup bootstrap + shared submit (#420).
# Pure-unit: injects fake submit/exists fns, no DB.

source_api_file("functions/analysis-snapshot-presets.R", local = FALSE)
source_api_file("services/analysis-snapshot-service.R", local = FALSE)

fake_job <- function(id, duplicate = FALSE) {
  list(
    job = data.frame(job_id = id, stringsAsFactors = FALSE),
    duplicate = duplicate,
    created = !duplicate
  )
}

test_that("submit refresh skips presets that already have a public-ready snapshot", {
  seen <- character()
  fake_submit <- function(job_type, request_payload, ...) {
    seen[[length(seen) + 1L]] <<- request_payload$analysis_type
    fake_job(paste0("job-", length(seen)))
  }
  fake_exists <- function(analysis_type, parameter_hash, conn = NULL) {
    identical(analysis_type, "gene_network_edges")
  }

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$requested, 5L)
  expect_equal(summary$skipped, 1L)
  expect_equal(summary$submitted, 4L)
  expect_false("gene_network_edges" %in% seen)
})

test_that("force = TRUE submits every preset regardless of existence", {
  n <- 0L
  fake_submit <- function(job_type, request_payload, ...) {
    n <<- n + 1L
    fake_job(paste0("job-", n))
  }
  fake_exists <- function(...) TRUE

  summary <- service_analysis_snapshot_submit_refresh(
    force = TRUE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$submitted, 5L)
  expect_equal(summary$skipped, 0L)
  expect_equal(n, 5L)
})

test_that("a single analysis_type targets just that preset", {
  fake_submit <- function(job_type, request_payload, ...) fake_job("job-1")
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    analysis_type = "phenotype_clusters", force = FALSE,
    submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$requested, 1L)
  expect_equal(summary$submitted, 1L)
  expect_equal(summary$results[[1]]$analysis_type, "phenotype_clusters")
})

test_that("an unknown analysis_type raises unsupported_parameter", {
  expect_error(
    service_analysis_snapshot_submit_refresh(
      analysis_type = "nope",
      submit_fn = function(...) NULL,
      exists_fn = function(...) FALSE
    ),
    class = "analysis_snapshot_unsupported_parameter_error"
  )
})

test_that("dedup hits are counted as reused, not submitted", {
  fake_submit <- function(job_type, request_payload, ...) fake_job("existing", duplicate = TRUE)
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$reused, 5L)
  expect_equal(summary$submitted, 0L)
})

test_that("a failing submit is isolated and counted, not thrown", {
  fake_submit <- function(job_type, request_payload, ...) stop("db down")
  fake_exists <- function(...) FALSE

  summary <- service_analysis_snapshot_submit_refresh(
    force = FALSE, submit_fn = fake_submit, exists_fn = fake_exists
  )

  expect_equal(summary$failed, 5L)
  expect_equal(summary$submitted, 0L)
})

test_that("analysis_snapshot_bootstrap_enabled honours the env var", {
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = "false"), {
    expect_false(analysis_snapshot_bootstrap_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = "true"), {
    expect_true(analysis_snapshot_bootstrap_enabled())
  })
  withr::with_envvar(c(ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP = NA), {
    expect_true(analysis_snapshot_bootstrap_enabled())
  })
})

test_that("bootstrap_on_startup is a no-op when disabled", {
  called <- FALSE
  summary_fn <- function(...) {
    called <<- TRUE
    list(requested = 5L, submitted = 0L, reused = 0L, skipped = 5L, failed = 0L)
  }
  res <- analysis_snapshot_bootstrap_on_startup(
    submit_refresh_fn = summary_fn, enabled_fn = function() FALSE
  )
  expect_false(called)
  expect_false(res)
})

test_that("bootstrap_on_startup swallows submit errors (never crashes boot)", {
  res <- analysis_snapshot_bootstrap_on_startup(
    submit_refresh_fn = function(...) stop("db down"),
    enabled_fn = function() TRUE
  )
  expect_false(isTRUE(res))
})
```

- [ ] **Step 2: Run the tests** (host):

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-analysis-snapshot-bootstrap.R')"`
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R
git commit -m "test(api): unit tests for snapshot bootstrap + shared submit (#420)"
```

---

## Sprint B — API admin endpoints

### Task B1: New admin endpoint file

**Files:**
- Create: `api/endpoints/admin_analysis_snapshot_endpoints.R`

- [ ] **Step 1: Write the file** (new file — NOT appended to admin_endpoints.R, which is already over the 600-line ceiling):

```r
## -------------------------------------------------------------------##
# api/endpoints/admin_analysis_snapshot_endpoints.R
#
# Administrator-only HTTP triggers for the durable public analysis snapshots that
# the /api/analysis/* read endpoints serve. Mounted at /api/admin/analysis, so:
#   POST /api/admin/analysis/snapshots/refresh  (submit refresh jobs)
#   GET  /api/admin/analysis/snapshots/status   (per-preset manifest state)
#
# All three snapshot submit paths (startup hook, this endpoint, and the operator
# script scripts/refresh-analysis-snapshots.R) share one function,
# service_analysis_snapshot_submit_refresh(), so submission logic is not
# duplicated. Spec: .planning/superpowers/specs/2026-06-14-analysis-snapshot-bootstrap-design.md
## -------------------------------------------------------------------##

#* Submit analysis snapshot refresh jobs (Administrator only)
#*
#* Idempotently submits `analysis_snapshot_refresh` jobs so the worker rebuilds +
#* activates the durable public-ready snapshots. By default only presets without a
#* current public-ready snapshot are submitted; pass `force=true` to rebuild all.
#* Re-submitting a queued/running refresh returns the existing job (dedup).
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @param analysis_type:str Optional single preset (e.g. "gene_network_edges"). Omit for all supported presets.
#* @param force:bool Optional; rebuild even when a current snapshot exists. Default false.
#*
#* @post /snapshots/refresh
function(req, res, analysis_type = NULL, force = FALSE) {
  require_role(req, res, "Administrator")

  at <- if (is.null(analysis_type) || !nzchar(as.character(analysis_type[[1]]))) {
    NULL
  } else {
    as.character(analysis_type[[1]])
  }
  force_flag <- isTRUE(force) ||
    identical(tolower(as.character(force)[[1]]), "true") ||
    identical(as.character(force)[[1]], "1")

  summary <- service_analysis_snapshot_submit_refresh(analysis_type = at, force = force_flag)

  res$status <- 202L
  summary
}

#* Per-preset analysis snapshot status (Administrator only)
#*
#* Returns the manifest state (missing / available / stale /
#* source_version_mismatch) for each supported analysis preset, with timestamps
#* and stored row counts, so an operator can watch a rebuild progress without DB
#* access.
#*
#* @tag admin
#* @serializer unboxedJSON
#*
#* @get /snapshots/status
function(req, res) {
  require_role(req, res, "Administrator")
  service_analysis_snapshot_status()
}
```

- [ ] **Step 2: Sanity-parse** — `cd api && Rscript -e "parse('endpoints/admin_analysis_snapshot_endpoints.R'); cat('parse ok\n')"`. Expected: `parse ok`.

### Task B2: Mount the endpoint

**Files:**
- Modify: `api/bootstrap/mount_endpoints.R` (add a mount line directly BEFORE the `/api/admin` mount, line 144)

- [ ] **Step 1: Insert** the new mount immediately before the existing `plumber::pr_mount("/api/admin", mount_endpoint("endpoints/admin_endpoints.R")) %>%` line (so the more specific `/api/admin/analysis` prefix is matched first, mirroring how `/api/jobs/network_layout` precedes `/api/jobs`):

```r
    plumber::pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R")) %>%
    plumber::pr_mount("/api/admin", mount_endpoint("endpoints/admin_endpoints.R")) %>%
```

- [ ] **Step 2: Sanity-parse** — `cd api && Rscript -e "parse('bootstrap/mount_endpoints.R'); cat('parse ok\n')"`. Expected: `parse ok`.

### Task B3: Static guard test + verify endpoint-handler guard stays green

**Files:**
- Create: `api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R`

- [ ] **Step 1: Inspect** `api/tests/testthat/test-unit-endpoint-error-handler.R` to copy its api-root path-resolution convention (how it locates source files when run from `api/`). Use the same convention below in `read_api_lines`.

- [ ] **Step 2: Write the guard test** (replace `read_api_lines` body with the convention from Step 1 if different — the default below resolves relative to the testthat working dir which is `api/`):

```r
# Static guard: the admin snapshot endpoints must gate both routes on the
# Administrator role and must be mounted via mount_endpoint() (#420).

read_api_lines <- function(rel) {
  candidates <- c(rel, file.path("..", "..", rel))
  hit <- Filter(file.exists, candidates)
  if (length(hit) == 0L) stop(sprintf("cannot locate %s", rel))
  readLines(hit[[1]], warn = FALSE)
}

test_that("both admin snapshot routes require the Administrator role", {
  src <- read_api_lines("endpoints/admin_analysis_snapshot_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl("@post /snapshots/refresh", joined, fixed = TRUE))
  expect_true(grepl("@get /snapshots/status", joined, fixed = TRUE))
  role_gate <- grepl('require_role(req, res, "Administrator")', src, fixed = TRUE)
  expect_gte(sum(role_gate), 2L)
})

test_that("admin snapshot endpoint is mounted via mount_endpoint", {
  src <- read_api_lines("bootstrap/mount_endpoints.R")
  joined <- paste(src, collapse = "\n")
  expect_true(grepl(
    'pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R"))',
    joined, fixed = TRUE
  ))
})
```

- [ ] **Step 3: Run** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-admin-snapshot-endpoint-guard.R')"`. Expected: PASS.

- [ ] **Step 4: Confirm the existing mount guard still passes** — `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-endpoint-error-handler.R')"`. Expected: PASS (the new mount uses `mount_endpoint()`).

- [ ] **Step 5: Commit**

```bash
git add api/endpoints/admin_analysis_snapshot_endpoints.R api/bootstrap/mount_endpoints.R api/tests/testthat/test-unit-admin-snapshot-endpoint-guard.R
git commit -m "feat(api): admin analysis snapshot refresh + status endpoints (#420)"
```

---

## Sprint C — Frontend resilience (503 → "being prepared")

### Task C1: Problem-code classification helper

**Files:**
- Modify: `app/src/api/analysis.ts` (add an exported helper + a constant set of "preparing" codes)
- Test: `app/src/api/analysis.spec.ts` (create if absent)

- [ ] **Step 1: Add** to `app/src/api/analysis.ts` (near the top-level exports):

```ts
/**
 * Problem codes the analysis-snapshot endpoints return (HTTP 503) while a
 * snapshot is being (re)built rather than on a hard failure. The frontend shows
 * a friendly "being prepared" state for these instead of a raw error. (#420)
 */
export const SNAPSHOT_PREPARING_CODES = [
  'snapshot_missing',
  'snapshot_stale',
  'source_version_mismatch',
] as const;

/**
 * Returns true when an error is an analysis-snapshot "being prepared" 503
 * (snapshot missing/stale/mismatch), false for any other error.
 */
export function isSnapshotPreparingError(err: unknown): boolean {
  const problem = (err as { response?: { status?: number; data?: { code?: string } } })?.response;
  if (!problem || problem.status !== 503) return false;
  const code = problem.data?.code;
  return typeof code === 'string'
    && (SNAPSHOT_PREPARING_CODES as readonly string[]).includes(code);
}
```

- [ ] **Step 2: Write the vitest** `app/src/api/analysis.spec.ts`:

```ts
import { describe, it, expect } from 'vitest';
import { isSnapshotPreparingError } from './analysis';

describe('isSnapshotPreparingError', () => {
  it('is true for a 503 snapshot_missing problem', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_missing' } } })).toBe(true);
  });
  it('is true for snapshot_stale and source_version_mismatch', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'snapshot_stale' } } })).toBe(true);
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'source_version_mismatch' } } })).toBe(true);
  });
  it('is false for a non-503 error', () => {
    expect(isSnapshotPreparingError({ response: { status: 500, data: { code: 'snapshot_missing' } } })).toBe(false);
  });
  it('is false for a 503 with an unrelated code', () => {
    expect(isSnapshotPreparingError({ response: { status: 503, data: { code: 'CAPACITY_EXCEEDED' } } })).toBe(false);
  });
  it('is false for a plain error', () => {
    expect(isSnapshotPreparingError(new Error('boom'))).toBe(false);
  });
});
```

- [ ] **Step 3: Run** — `cd app && npx vitest run src/api/analysis.spec.ts`. Expected: PASS.

### Task C2: Surface a "preparing" state in the network composable + components

**Files:**
- Modify: `app/src/composables/useNetworkData.ts` (add `isPreparing` ref; set it in the catch)
- Modify: `app/src/components/analyses/NetworkVisualization.vue` (render preparing panel)
- Modify: `app/src/components/analyses/AnalysesPhenotypeClusters.vue` (render preparing panel on its fetch path)

- [ ] **Step 1:** In `useNetworkData.ts`, import the helper and add an `isPreparing` ref. In `fetchNetworkData`'s `catch`, set `isPreparing.value = isSnapshotPreparingError(err)` before mapping the error; reset to `false` at the start of the try. Return `isPreparing` from the composable. Concretely:

```ts
// add to imports:
import { isSnapshotPreparingError } from '@/api/analysis';

// add alongside the other refs:
const isPreparing = ref(false);

// in fetchNetworkData(), at the start of try block (where isLoading is set):
isPreparing.value = false;

// in the catch block, before error.value is set:
isPreparing.value = isSnapshotPreparingError(err);

// add isPreparing to the returned object from the composable.
```

- [ ] **Step 2:** In `NetworkVisualization.vue`, read `isPreparing` from the composable and render an info panel (Bootstrap-vue-next styles already in use) ahead of the existing error card:

```html
<div v-if="isPreparing && !isLoading" class="preparing-container text-center py-4">
  <i class="bi bi-hourglass-split text-primary fs-1 mb-3 d-block" />
  <p class="text-muted mb-3">
    This analysis is being prepared and will appear here shortly. This can take a
    couple of minutes after a deploy or data update.
  </p>
  <BButton variant="primary" @click="retryLoadNetwork">
    <i class="bi bi-arrow-clockwise me-1" />
    Check again
  </BButton>
</div>
<div v-else-if="error && !isLoading" class="error-container text-center">
  <!-- existing error card unchanged -->
</div>
```

(Adjust the existing `v-if="error && !isLoading"` to `v-else-if` so the two states are mutually exclusive.)

- [ ] **Step 3:** In `AnalysesPhenotypeClusters.vue`, apply the same pattern to its fetch/error path: classify with `isSnapshotPreparingError` where it catches the fetch error, and render the same "being prepared" panel before its existing error state.

- [ ] **Step 4: Type-check + lint + unit** — `cd app && npm run type-check && npm run lint && npm run test:unit`. Expected: clean / pass.

- [ ] **Step 5: Commit**

```bash
git add app/src/api/analysis.ts app/src/api/analysis.spec.ts app/src/composables/useNetworkData.ts app/src/components/analyses/NetworkVisualization.vue app/src/components/analyses/AnalysesPhenotypeClusters.vue
git commit -m "feat(app): show 'analysis being prepared' state on snapshot 503 (#420)"
```

---

## Final integration & docs

### Task D1: Docs

**Files:**
- Modify: `AGENTS.md` (Background jobs section)
- Modify: `documentation/09-deployment.qmd` (operator note)

- [ ] **Step 1:** In `AGENTS.md` "Background jobs", add a short paragraph: public analysis snapshots auto-bootstrap on API startup (`analysis_snapshot_bootstrap_on_startup()` in `start_sysndd_api.R`, gated by `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP`, default on); the startup hook, the new `POST/GET /api/admin/analysis/snapshots/{refresh,status}` Administrator endpoints, and `make refresh-analysis-snapshots` all share `service_analysis_snapshot_submit_refresh()`; bootstrap only enqueues presets lacking a public-ready row (restarts enqueue nothing).

- [ ] **Step 2:** In `documentation/09-deployment.qmd`, add an operator note documenting the env flag and the two admin routes as the no-SSH rebuild/status path.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md documentation/09-deployment.qmd
git commit -m "docs: analysis snapshot startup bootstrap + admin endpoints (#420)"
```

### Task D2: Full verification

- [ ] **Step 1:** `make lint-api` → clean.
- [ ] **Step 2:** `cd app && npm run lint && npm run type-check && npm run test:unit` → clean/pass.
- [ ] **Step 3:** `make test-api-fast` → pass (PR gate). If host RMariaDB is unavailable, run the new unit files directly (they need no DB) and note the DB-backed suite runs in CI.
- [ ] **Step 4:** `make ci-local` before handoff (full mirror) when DB available.
- [ ] **Step 5:** Open PR.

---

## Self-review

**Spec coverage:**
- Startup auto-bootstrap → A2 (`analysis_snapshot_bootstrap_on_startup`), A3 (hook). ✓
- Idempotent / existence-checked → A1 (`analysis_snapshot_public_exists`), A2 submit skip. ✓
- Config/env gate + logged → A2 (`analysis_snapshot_bootstrap_enabled`, log lines). ✓
- Admin refresh endpoint → B1/B2. ✓
- Admin status endpoint → B1/B2 + A2 `service_analysis_snapshot_status` + A1 `analysis_snapshot_public_manifest`. ✓
- One shared submit fn (script + startup + endpoint) → A2 + A4 + B1. ✓
- Script remains manual/forced path → A4 (`force = TRUE`). ✓
- Non-admin → 403 → B1 `require_role`; guard B3. ✓
- Frontend "being prepared" → C1/C2. ✓
- Docs → D1. ✓

**Placeholder scan:** none — all code is concrete.

**Type/name consistency:** `service_analysis_snapshot_submit_refresh`, `service_analysis_snapshot_status`, `analysis_snapshot_public_exists`, `analysis_snapshot_public_manifest`, `analysis_snapshot_bootstrap_enabled`, `analysis_snapshot_bootstrap_on_startup`, `isSnapshotPreparingError`, `isPreparing` — used consistently across A/B/C. Summary keys (`requested/submitted/reused/skipped/failed/results`) consistent between A2, A4, A5, B1. ✓
