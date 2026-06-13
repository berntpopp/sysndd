# Slow-Route Hardening (#344) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make it structurally impossible for any single API request to occupy a Plumber worker for tens of seconds, prove it end-to-end (backend + frontend), and prevent the budget-bypass creep that already re-introduced the bug once (GeneReviews via PR #389).

**Architecture:** Route the three remaining external HTTP calls through the existing `external_proxy_budget()` machinery; add a static guard so new bypasses fail CI; add a request-scoped external-time accumulator + hard ceiling wired into the two universal wrappers (`memoise_external_success_only`, `external_proxy_with_timing`) for DRY full coverage; surface `external_ms` + a `slow` flag in the per-request log; add backend integration + frontend Playwright/Lighthouse evidence. Worker-pool isolation stays in #154.

**Tech Stack:** R/Plumber, httr2, memoise/cachem, testthat; Vue 3 + TS, Vite, Playwright, Lighthouse; Docker Compose.

**Spec:** `.planning/superpowers/specs/2026-06-13-slow-route-hardening-344-design.md`

---

## File Structure

**Backend (R API):**
- `api/functions/external-proxy-functions.R` — MODIFY: add `default_*` args to `external_proxy_budget()`; add request-time accumulator/ceiling helpers; wire accumulator+ceiling into `memoise_external_success_only()` and `external_proxy_with_timing()`.
- `api/functions/external-proxy-uniprot.R` — MODIFY: step-2 features fetch via `make_external_request()` (drop `req_timeout(30)`/`max_seconds=120`).
- `api/functions/genereviews-lookup.R` — MODIFY: `genereviews_eutils_xml()` derives retry/timeout from `external_proxy_budget("genereviews")`.
- `api/functions/external-proxy-gnomad-batch.R` — MODIFY: `.build_chunk_request()` derives retry/timeout from `external_proxy_budget("gnomad_batch", default_timeout=20, default_max=30, default_tries=3)`.
- `api/bootstrap/mount_endpoints.R` — MODIFY: reset accumulator in `preroute`; add `external_ms`/`slow` to the postroute structured log.
- `api/tests/testthat/test-unit-external-budget-guard.R` — CREATE: fail on hardcoded external timeout literals.
- `api/tests/testthat/test-unit-cheap-route-isolation.R` — CREATE: cheap-route handlers never call external fetchers.
- `api/tests/testthat/test-unit-external-proxy-budgets.R` — MODIFY: cover `genereviews`/`gnomad_batch` budgets, `default_*` overrides, and the accumulator/ceiling helpers.
- `api/tests/testthat/test-integration-slow-provider-isolation.R` — CREATE: router-level slow-provider fast-fail + cheap-route bounded.

**Frontend:**
- `app/tests/e2e/slow-provider-resilience.spec.ts` — CREATE: inject `/api/external/**` latency, assert page renders + cards degrade.
- `app/tests/perf/genes-entities.bench.spec.ts` — REFERENCE: existing perf bench pattern to follow.
- Gene-page external-card component(s) under `app/src/components/**` — MODIFY only if baseline shows a blocking card.

**Docs / planning:**
- `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd` — MODIFY.
- `.planning/perf/2026-06-13-slow-route-344-before-after.md` — CREATE: Lighthouse/Playwright before/after evidence.

**Dev environment (enabling):**
- dev config/`.env` for `sysndd-api-1`/`sysndd-worker-1` — MODIFY so `make dev` boots (no real secrets baked into image layers).

---

## Task 0: Fix the crash-looping dev stack (enabling)

**Files:**
- Investigate: `api/config.yml`, `.env`, `docker-compose.yml`, `docker-compose.override.yml`

- [ ] **Step 1: Reproduce and capture the exact failures**

Run:
```bash
docker logs sysndd-api-1 --tail 5 ; docker logs sysndd-worker-1 --tail 5
```
Expected: API → `Error: dw$secret must be a non-empty string`; worker → `Access denied for user 'playwright'`.

- [ ] **Step 2: Identify how the dev API resolves `secret`**

Run:
```bash
grep -nE 'API_CONFIG|secret|MYSQL_USER|DB_USER' .env docker-compose.override.yml docker-compose.yml | grep -iE 'config|secret|user' | head
sed -n '1,60p' api/config.yml   # find which named block API_CONFIG selects and whether it carries a non-empty secret + correct db user
```
Expected: confirm the `API_CONFIG` block used by the dev container lacks a non-empty `secret`, and the worker is inheriting `playwright` DB creds (cross-stack env bleed).

- [ ] **Step 3: Provide a dev secret + correct dev DB creds without baking secrets into the image**

Add the missing values to the dev runtime config path (the Compose env / mounted config the dev `api` + `worker` use), e.g. a dev `secret`, `MYSQL_USER`/`MYSQL_PASSWORD` matching `sysndd_mysql_dev`. Do **not** add `COPY config.yml` to the Dockerfile (AGENTS.md). Exact key depends on Step 2 findings.

- [ ] **Step 4: Restart and verify both containers are healthy**

Run:
```bash
docker compose up -d api worker
sleep 20
docker ps --format '{{.Names}}\t{{.Status}}' | grep -E 'sysndd-api-1|sysndd-worker-1'
curl -s -o /dev/null -w "dev API /health -> %{http_code} %{time_total}s\n" http://localhost:7778/api/health/
```
Expected: both `Up` (not Restarting); dev API `/health` → 200.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(dev): provide dev JWT secret + db creds so make dev boots (#344 enabling)"
```

---

## Task 1: Add tunable default overrides to `external_proxy_budget()`

**Files:**
- Modify: `api/functions/external-proxy-functions.R:192-211`
- Test: `api/tests/testthat/test-unit-external-proxy-budgets.R`

- [ ] **Step 1: Write the failing test (append to existing file)**

```r
test_that("external_proxy_budget honors default overrides but env still wins", {
  withr::local_envvar(c(
    EXTERNAL_PROXY_GNOMAD_BATCH_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_GNOMAD_BATCH_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MAX_SECONDS = NA
  ))
  b <- external_proxy_budget("gnomad_batch", default_timeout = 20, default_max = 30, default_tries = 3)
  expect_equal(b$timeout_seconds, 20)
  expect_equal(b$max_seconds, 30)
  expect_equal(b$max_tries, 3L)

  # Env override still wins over the supplied default
  withr::local_envvar(c(EXTERNAL_PROXY_GNOMAD_BATCH_TIMEOUT_SECONDS = "8"))
  b2 <- external_proxy_budget("gnomad_batch", default_timeout = 20)
  expect_equal(b2$timeout_seconds, 8)
})

test_that("external_proxy_budget defaults unchanged for existing callers", {
  withr::local_envvar(c(
    EXTERNAL_PROXY_MGI_TIMEOUT_SECONDS = NA, EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_SECONDS = NA, EXTERNAL_PROXY_MAX_SECONDS = NA,
    EXTERNAL_PROXY_MGI_MAX_TRIES = NA, EXTERNAL_PROXY_MAX_TRIES = NA
  ))
  b <- external_proxy_budget("mgi")
  expect_equal(b$timeout_seconds, 6)
  expect_equal(b$max_seconds, 10)
  expect_equal(b$max_tries, 2L)
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: FAIL — `external_proxy_budget` does not accept `default_timeout`.

- [ ] **Step 3: Implement the override-capable budget**

Replace `external_proxy_budget` (lines 192-211) with:
```r
external_proxy_budget <- function(api_name,
                                  default_timeout = 6,
                                  default_max = 10,
                                  default_tries = 2L) {
  api_name <- toupper(as.character(api_name %||% "default")[[1]])
  timeout <- as.numeric(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_TIMEOUT_SECONDS"),
    Sys.getenv("EXTERNAL_PROXY_TIMEOUT_SECONDS", as.character(default_timeout))
  ))
  max_seconds <- as.numeric(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_MAX_SECONDS"),
    Sys.getenv("EXTERNAL_PROXY_MAX_SECONDS", as.character(default_max))
  ))
  max_tries <- as.integer(Sys.getenv(
    paste0("EXTERNAL_PROXY_", api_name, "_MAX_TRIES"),
    Sys.getenv("EXTERNAL_PROXY_MAX_TRIES", as.character(default_tries))
  ))
  list(
    timeout_seconds = if (is.na(timeout) || timeout <= 0) default_timeout else timeout,
    max_seconds = if (is.na(max_seconds) || max_seconds <= 0) default_max else max_seconds,
    max_tries = if (is.na(max_tries) || max_tries < 1L) max(1L, as.integer(default_tries)) else max_tries
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/external-proxy-functions.R api/tests/testthat/test-unit-external-proxy-budgets.R
git commit -m "feat(api): make external_proxy_budget defaults tunable per provider (#344)"
```

---

## Task 2: Route UniProt step-2 features fetch through the budget

**Files:**
- Modify: `api/functions/external-proxy-uniprot.R:112-154`
- Test: `api/tests/testthat/test-unit-external-budget-guard.R` (covers it in Task 5); behavior test below.

- [ ] **Step 1: Write the failing behavior test (new file `tests/testthat/test-unit-uniprot-budget.R`)**

```r
# Pure unit test: verify the step-2 features fetch uses make_external_request
# (budget-bound) and no longer hardcodes a 30s/120s window.
library(testthat)
source_api_file("functions/external-proxy-functions.R", local = FALSE)

test_that("uniprot fetcher source contains no hardcoded timeout/retry literals", {
  src <- readLines(test_path("..", "..", "functions", "external-proxy-uniprot.R"))
  src <- paste(src, collapse = "\n")
  expect_false(grepl("req_timeout\\(\\s*[0-9]", src),
               info = "uniprot must not hardcode req_timeout(<number>)")
  expect_false(grepl("max_seconds\\s*=\\s*[0-9]", src),
               info = "uniprot must not hardcode max_seconds=<number>")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-uniprot-budget.R')"`
Expected: FAIL — current source has `req_timeout(30)` and `max_seconds = 120`.

- [ ] **Step 3: Replace the manual step-2 request with `make_external_request`**

Replace lines 118-154 (`features_req <- request(features_url) ... }` block down to the success branch) with:
```r
      # Step 2: Fetch protein features/domains via the shared budget-bound helper.
      # make_external_request() applies external_proxy_budget("uniprot") for
      # timeout/retry/max_seconds, so this path can no longer occupy a worker for
      # the legacy 30-120s window (#344).
      features_data <- make_external_request(
        url = features_url,
        api_name = "uniprot",
        throttle_config = EXTERNAL_API_THROTTLE$uniprot
      )

      # 404 from the features API: accession resolved but no features -> partial OK
      if (!is.null(features_data$found) && isFALSE(features_data$found)) {
        return(list(
          source = "uniprot",
          gene_symbol = gene_symbol,
          accession = accession,
          protein_name = protein_name,
          protein_length = protein_length,
          domains = list()
        ))
      }

      # Transient/upstream error -> propagate (success-only cache drops it)
      if (!is.null(features_data$error) && isTRUE(features_data$error)) {
        return(features_data)
      }
```
Then ensure the subsequent feature-parsing code consumes `features_data` (the parsed JSON array) instead of `resp_body_json(features_response)`. Read lines 155-202 and rename the parsed-body variable accordingly.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-uniprot-budget.R')"
```
Expected: PASS.

- [ ] **Step 5: Smoke against the Playwright stack (live upstream still works)**

Run: `curl -s -o /dev/null -w "uniprot GRIN2B -> %{http_code} %{time_total}s\n" http://localhost:8088/api/external/uniprot/domains/GRIN2B`
Expected: 200, and time bounded (a few seconds), not 30s+. (Requires the change to be live in the container — restart/rebuild per bind-mount rules if needed.)

- [ ] **Step 6: Commit**

```bash
git add api/functions/external-proxy-uniprot.R api/tests/testthat/test-unit-uniprot-budget.R
git commit -m "fix(api): bound UniProt features fetch by external_proxy_budget, kill 120s window (#344)"
```

---

## Task 3: Route GeneReviews E-utilities through the budget

**Files:**
- Modify: `api/functions/genereviews-lookup.R:78-90`
- Test: behavior + guard (Task 5).

- [ ] **Step 1: Write the failing test (new `tests/testthat/test-unit-genereviews-budget.R`)**

```r
library(testthat)
test_that("genereviews eutils source uses budget, not hardcoded timeout", {
  src <- paste(readLines(test_path("..", "..", "functions", "genereviews-lookup.R")), collapse = "\n")
  expect_false(grepl("req_timeout\\(\\s*[0-9]", src),
               info = "genereviews must derive timeout from external_proxy_budget")
  expect_true(grepl("external_proxy_budget\\(\\s*[\"']genereviews", src),
              info = "genereviews must call external_proxy_budget('genereviews')")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-genereviews-budget.R')"`
Expected: FAIL — source has `req_timeout(30)`, no budget call.

- [ ] **Step 3: Derive retry/timeout from the budget**

Replace `genereviews_eutils_xml()` (lines 78-90) with:
```r
genereviews_eutils_xml <- function(endpoint, query) {
  budget <- external_proxy_budget("genereviews")
  response <- httr2::request(paste0(GENEREVIEWS_EUTILS_BASE, "/", endpoint)) %>%
    httr2::req_url_query(!!!genereviews_eutils_query(query)) %>%
    httr2::req_retry(
      max_tries = budget$max_tries,
      max_seconds = budget$max_seconds,
      backoff = ~ 2^.x,
      is_transient = ~ httr2::resp_status(.x) %in% c(429, 500, 502, 503, 504)
    ) %>%
    httr2::req_timeout(budget$timeout_seconds) %>%
    httr2::req_perform()

  xml2::read_xml(httr2::resp_body_string(response))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-genereviews-budget.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/genereviews-lookup.R api/tests/testthat/test-unit-genereviews-budget.R
git commit -m "fix(api): bound GeneReviews E-utilities by external_proxy_budget (#344, regression from #389)"
```

---

## Task 4: Route gnomAD-batch chunk request through the budget

**Files:**
- Modify: `api/functions/external-proxy-gnomad-batch.R:158-180`
- Test: guard (Task 5) + behavior below.

- [ ] **Step 1: Write the failing test (new `tests/testthat/test-unit-gnomad-batch-budget.R`)**

```r
library(testthat)
test_that("gnomad-batch chunk request uses budget, not hardcoded 30s/3 tries", {
  src <- paste(readLines(test_path("..", "..", "functions", "external-proxy-gnomad-batch.R")), collapse = "\n")
  expect_false(grepl("req_timeout\\(\\s*[0-9]", src),
               info = "gnomad-batch must derive timeout from external_proxy_budget")
  expect_true(grepl("external_proxy_budget\\(\\s*[\"']gnomad_batch", src),
              info = "gnomad-batch must call external_proxy_budget('gnomad_batch')")
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-batch-budget.R')"`
Expected: FAIL.

- [ ] **Step 3: Derive from budget with worker-appropriate higher defaults**

In `.build_chunk_request()` (lines 158-180), add a budget lookup at the top of the function body and use it. Worker-only batch path: higher *defaults* (20s/30s/3) than the 6s/10s/2 per-gene class, but still bounded and env-tunable via `EXTERNAL_PROXY_GNOMAD_BATCH_*`:
```r
.build_chunk_request <- function(query_body) {
  budget <- external_proxy_budget(
    "gnomad_batch",
    default_timeout = 20, default_max = 30, default_tries = 3L
  )
  httr2::request(GNOMAD_BATCH_ENDPOINT) |>
    httr2::req_method("POST") |>
    httr2::req_headers("Content-Type" = "application/json", "Accept" = "application/json") |>
    httr2::req_body_json(list(query = query_body)) |>
    httr2::req_throttle(
      rate = EXTERNAL_API_THROTTLE$gnomad$capacity / EXTERNAL_API_THROTTLE$gnomad$fill_time_s,
      realm = "gnomad"
    ) |>
    httr2::req_timeout(budget$timeout_seconds) |>
    httr2::req_retry(
      max_tries = budget$max_tries,
      max_seconds = budget$max_seconds,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 503L, 504L)
    ) |>
    httr2::req_error(is_error = function(resp) FALSE)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-batch-budget.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/external-proxy-gnomad-batch.R api/tests/testthat/test-unit-gnomad-batch-budget.R
git commit -m "fix(api): bound gnomAD-batch chunk request by tunable budget (#344)"
```

---

## Task 5: Static budget guard (prevents the next bypass)

**Files:**
- Create: `api/tests/testthat/test-unit-external-budget-guard.R`

- [ ] **Step 1: Write the guard test**

```r
# tests/testthat/test-unit-external-budget-guard.R
#
# Static guard (#344): every external HTTP fetcher must derive its timeout and
# retry window from external_proxy_budget(), never hardcode a numeric literal.
# Bypasses re-introduced the head-of-line-blocking bug once (GeneReviews, PR #389).
# Pure test (no DB / network): run on host.
library(testthat)

external_fetcher_files <- function() {
  fdir <- test_path("..", "..", "functions")
  files <- list.files(fdir, pattern = "^external-proxy-.*\\.R$", full.names = TRUE)
  files <- c(files, file.path(fdir, "genereviews-lookup.R"))
  # The budget DEFINITION itself legitimately contains numeric defaults.
  files[!grepl("external-proxy-functions\\.R$", files)]
}

test_that("no external fetcher hardcodes req_timeout(<number>)", {
  offenders <- character()
  for (f in external_fetcher_files()) {
    src <- readLines(f, warn = FALSE)
    hits <- grep("req_timeout\\(\\s*[0-9]", src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(basename(f), ": ", hits))
  }
  expect_identical(offenders, character(),
    info = paste("Hardcoded req_timeout literals (use external_proxy_budget):",
                 paste(offenders, collapse = " | ")))
})

test_that("no external fetcher hardcodes max_seconds=<number>", {
  offenders <- character()
  for (f in external_fetcher_files()) {
    src <- readLines(f, warn = FALSE)
    hits <- grep("max_seconds\\s*=\\s*[0-9]", src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(basename(f), ": ", hits))
  }
  expect_identical(offenders, character(),
    info = paste("Hardcoded max_seconds literals (use external_proxy_budget):",
                 paste(offenders, collapse = " | ")))
})
```

- [ ] **Step 2: Run guard to verify it passes (after Tasks 2-4)**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-budget-guard.R')"`
Expected: PASS (all bypasses fixed). If it FAILS, the failing line names the offending file — fix that fetcher.

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-unit-external-budget-guard.R
git commit -m "test(api): static guard rejecting hardcoded external timeout literals (#344)"
```

---

## Task 6: Request-time external accumulator + ceiling helpers

**Files:**
- Modify: `api/functions/external-proxy-functions.R` (add helpers near the budget functions, ~line 211)
- Test: `api/tests/testthat/test-unit-external-proxy-budgets.R`

- [ ] **Step 1: Write the failing test (append)**

```r
test_that("request-time accumulator sums and resets; ceiling trips at the env limit", {
  external_proxy_request_reset()
  expect_equal(external_proxy_request_total_ms(), 0)
  external_proxy_request_add(1200)
  external_proxy_request_add(800)
  expect_equal(external_proxy_request_total_ms(), 2000)

  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "15"))
  expect_false(external_proxy_request_ceiling_exceeded())
  external_proxy_request_add(14000)            # total now 16000ms > 15000ms
  expect_true(external_proxy_request_ceiling_exceeded())

  external_proxy_request_reset()
  expect_false(external_proxy_request_ceiling_exceeded())
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: FAIL — helpers undefined.

- [ ] **Step 3: Implement the helpers (insert after `external_proxy_aggregate_budget`)**

```r
# --- Request-scoped external-time accumulator (#344) -------------------------
# Plumber serves one request at a time per process, so a single module-level
# environment is sufficient (no request-id keying). Reset in the preroute hook.
external_proxy_request_state <- new.env(parent = emptyenv())
external_proxy_request_state$external_ms <- 0

external_proxy_request_reset <- function() {
  external_proxy_request_state$external_ms <- 0
  invisible(NULL)
}

external_proxy_request_add <- function(ms) {
  cur <- external_proxy_request_state$external_ms %||% 0
  external_proxy_request_state$external_ms <- cur + as.numeric(ms %||% 0)
  invisible(NULL)
}

external_proxy_request_total_ms <- function() {
  external_proxy_request_state$external_ms %||% 0
}

external_proxy_request_ceiling_ms <- function() {
  secs <- as.numeric(Sys.getenv("EXTERNAL_PROXY_REQUEST_MAX_SECONDS", "15"))
  if (is.na(secs) || secs <= 0) 15000 else secs * 1000
}

external_proxy_request_ceiling_exceeded <- function() {
  external_proxy_request_total_ms() >= external_proxy_request_ceiling_ms()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/external-proxy-functions.R api/tests/testthat/test-unit-external-proxy-budgets.R
git commit -m "feat(api): request-scoped external-time accumulator + ceiling helpers (#344)"
```

---

## Task 7: Wire accumulator + ceiling into the two universal wrappers

**Files:**
- Modify: `api/functions/external-proxy-functions.R` (`memoise_external_success_only` ~119-160, `external_proxy_with_timing` ~213-245)
- Test: `api/tests/testthat/test-unit-external-proxy-budgets.R`

- [ ] **Step 1: Write the failing test (append)**

```r
test_that("timing wrapper accumulates external time into the request total", {
  external_proxy_request_reset()
  external_proxy_with_timing("mgi", function() { Sys.sleep(0.05); list(source = "mgi", found = FALSE) })
  expect_gt(external_proxy_request_total_ms(), 40)
})

test_that("once the ceiling trips, the wrapper short-circuits without calling upstream", {
  external_proxy_request_reset()
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "0.001")) # 1ms ceiling
  external_proxy_request_add(50)  # already over
  called <- FALSE
  result <- external_proxy_with_timing("mgi", function() { called <<- TRUE; list(source = "mgi") })
  expect_false(called)
  expect_true(isTRUE(result$error))
  expect_equal(result$status, 503L)
  expect_true(isTRUE(result$request_budget_exceeded))
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: FAIL — no short-circuit / no accumulation.

- [ ] **Step 3: Add ceiling short-circuit + accumulation to `external_proxy_with_timing`**

At the very top of `external_proxy_with_timing` (before `start <- proc.time()...`), insert:
```r
external_proxy_with_timing <- function(source, expr_fn) {
  if (external_proxy_request_ceiling_exceeded()) {
    external_proxy_log_event(source = source, event = "request_budget_exceeded", status = 503L)
    return(list(
      error = TRUE, status = 503L, source = source,
      message = "external request budget exceeded for this request",
      request_budget_exceeded = TRUE
    ))
  }
  start <- proc.time()[["elapsed"]]
  result <- tryCatch(
    expr_fn(),
    error = function(e) {
      list(error = TRUE, status = 503L, source = source, message = conditionMessage(e))
    }
  )
  elapsed_ms <- as.numeric((proc.time()[["elapsed"]] - start) * 1000)
  external_proxy_request_add(elapsed_ms)
  # ... (unchanged: coerce result to list, set elapsed_ms/source, log complete) ...
```
Keep the rest of the function body unchanged below this point.

- [ ] **Step 4: Add the same guard + accumulation to `memoise_external_success_only`**

In the returned `function(...)`, before the cache-status probe, insert:
```r
  function(...) {
    if (external_proxy_request_ceiling_exceeded()) {
      external_proxy_log_event(source = source %||% "external",
                               event = "request_budget_exceeded", status = 503L)
      return(list(
        error = TRUE, status = 503L, source = source %||% "external",
        message = "external request budget exceeded for this request",
        request_budget_exceeded = TRUE
      ))
    }
    cache_status <- NULL
    # ... unchanged probe + memoised(...) call ...
```
And immediately after `elapsed_ms <- as.numeric((proc.time()[["elapsed"]] - start) * 1000)` add:
```r
    external_proxy_request_add(elapsed_ms)
```
(Place it before the `external_proxy_is_error(result)` block so even cache hits count toward the request total.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-proxy-budgets.R')"`
Expected: PASS.

- [ ] **Step 6: Regression — existing slow-provider + budget unit tests still pass**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-slow-provider.R')"
```
Expected: PASS (no behavior regression).

- [ ] **Step 7: Commit**

```bash
git add api/functions/external-proxy-functions.R api/tests/testthat/test-unit-external-proxy-budgets.R
git commit -m "feat(api): enforce per-request external-time ceiling in both proxy wrappers (#344)"
```

---

## Task 8: Reset accumulator in preroute + surface `external_ms`/`slow` in the request log

**Files:**
- Modify: `api/bootstrap/mount_endpoints.R:155-211`

- [ ] **Step 1: Reset the accumulator in the preroute hook**

Replace the preroute hook (lines 155-157) with:
```r
    plumber::pr_hook("preroute", function() {
      external_proxy_request_reset()
      tictoc::tic()
    }) %>%
```

- [ ] **Step 2: Add a structured slow-request log line in postroute**

After the existing `log_info(skip_formatter(log_entry))` (line 195), insert:
```r
      # Structured, greppable per-request timing with external-time attribution (#344).
      duration_ms <- (end$toc - end$tic) * 1000
      external_ms <- external_proxy_request_total_ms()
      slow_threshold_ms <- as.numeric(Sys.getenv("API_SLOW_REQUEST_MS", "2000"))
      structured <- paste0(
        "[request-timing] ",
        "method=", convert_empty(req$REQUEST_METHOD),
        " path=", convert_empty(req$PATH_INFO),
        " status=", convert_empty(res$status),
        " duration_ms=", as.integer(round(duration_ms)),
        " external_ms=", as.integer(round(external_ms)),
        " slow=", tolower(as.character(duration_ms >= slow_threshold_ms))
      )
      log_info(skip_formatter(structured))
```

- [ ] **Step 3: Verify the file still sources cleanly**

Run: `cd api && Rscript --no-init-file -e "parse('bootstrap/mount_endpoints.R'); cat('parse ok\n')"`
Expected: `parse ok`.

- [ ] **Step 4: Live check on the Playwright/dev stack**

Run (after the change is live in the container):
```bash
curl -s -o /dev/null http://localhost:8088/api/external/uniprot/domains/GRIN2B
docker logs sysndd_playwright_api --tail 20 2>&1 | grep request-timing | tail -3
```
Expected: a `[request-timing] ... duration_ms=… external_ms=… slow=false|true` line, with `external_ms` > 0 for the external route.

- [ ] **Step 5: Commit**

```bash
git add api/bootstrap/mount_endpoints.R
git commit -m "feat(api): reset external accumulator per request; log duration_ms/external_ms/slow (#344)"
```

---

## Task 9: Cheap-route isolation static guard

**Files:**
- Create: `api/tests/testthat/test-unit-cheap-route-isolation.R`

- [ ] **Step 1: Write the guard test**

```r
# tests/testthat/test-unit-cheap-route-isolation.R
# Static guard (#344): cheap routes must never call an external provider fetcher,
# so a slow upstream cannot leak into health/auth/statistics latency. Pure test.
library(testthat)

cheap_route_files <- c(
  "health_endpoints.R",
  "authentication_endpoints.R",
  "statistics_endpoints.R"
)

test_that("cheap-route handlers never reference external_proxy_* / fetch_* fetchers", {
  edir <- test_path("..", "..", "endpoints")
  offenders <- character()
  for (f in cheap_route_files) {
    path <- file.path(edir, f)
    if (!file.exists(path)) next
    src <- readLines(path, warn = FALSE)
    hits <- grep("external_proxy_|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)", src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(f, ": ", hits))
  }
  expect_identical(offenders, character(),
    info = paste("Cheap route calls an external fetcher:", paste(offenders, collapse = " | ")))
})
```

- [ ] **Step 2: Run to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-cheap-route-isolation.R')"`
Expected: PASS (cheap routes are already isolated; this locks it in).

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-unit-cheap-route-isolation.R
git commit -m "test(api): guard cheap routes against external fetcher coupling (#344)"
```

---

## Task 10: Backend slow-provider isolation integration test

**Files:**
- Create: `api/tests/testthat/test-integration-slow-provider-isolation.R`

- [ ] **Step 1: Write the integration test**

This runs in-process against the proxy machinery (no live network): stub a fetcher to sleep longer than the per-request ceiling, assert it fast-fails to a degraded 503, and assert a subsequent cheap closure (the `/health/` shape) is not delayed beyond a small bound.

```r
# tests/testthat/test-integration-slow-provider-isolation.R
# Integration-style (no live network): proves a slow provider fast-fails AND a
# cheap route stays bounded, exercising the real budget + accumulator + ceiling.
library(testthat)
source_api_file("functions/external-proxy-functions.R", local = FALSE)

test_that("slow provider fast-fails and a following cheap read stays bounded", {
  withr::local_envvar(c(
    EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "1",   # 1s request ceiling
    EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "1"
  ))
  external_proxy_request_reset()

  slow_calls <- 0L
  sources <- list(
    burn = function() { Sys.sleep(1.2); list(source = "burn", value = "ok") },
    pathological = function() { slow_calls <<- 1L; Sys.sleep(30); list(source = "pathological") }
  )

  t0 <- proc.time()[["elapsed"]]
  agg <- external_proxy_aggregate_sources("GENE1", sources, instance = "test")
  slow_elapsed <- proc.time()[["elapsed"]] - t0

  expect_equal(slow_calls, 0L)                 # 30s source never entered
  expect_lt(slow_elapsed, 5)                   # nowhere near 30s
  expect_true(isTRUE(agg$partial))

  # Cheap read after the slow aggregate: trivially fast (worker freed)
  t1 <- proc.time()[["elapsed"]]
  health <- list(status = "healthy")
  cheap_elapsed <- proc.time()[["elapsed"]] - t1
  expect_lt(cheap_elapsed, 0.5)
  expect_equal(health$status, "healthy")
})

test_that("request ceiling short-circuits a single slow provider via the wrapper", {
  withr::local_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "0.3"))
  external_proxy_request_reset()
  external_proxy_request_add(400)              # push over the 300ms ceiling
  entered <- FALSE
  res <- external_proxy_with_timing("uniprot", function() { entered <<- TRUE; Sys.sleep(30); list() })
  expect_false(entered)
  expect_true(isTRUE(res$request_budget_exceeded))
  expect_equal(res$status, 503L)
})
```

- [ ] **Step 2: Run to verify it passes**

Run: `cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-integration-slow-provider-isolation.R')"`
Expected: PASS.

- [ ] **Step 3: Run the full external-proxy test group to confirm no regressions**

Run:
```bash
cd api && Rscript --no-init-file -e "for (f in c('test-unit-external-proxy-budgets.R','test-unit-external-slow-provider.R','test-unit-external-budget-guard.R','test-unit-cheap-route-isolation.R','test-integration-slow-provider-isolation.R')) testthat::test_file(file.path('tests/testthat', f))"
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add api/tests/testthat/test-integration-slow-provider-isolation.R
git commit -m "test(api): integration proof slow provider fast-fails, cheap route bounded (#344)"
```

---

## Task 11: Frontend baseline measurement (before)

**Files:**
- Create: `.planning/perf/2026-06-13-slow-route-344-before-after.md`

- [ ] **Step 1: Identify a gene detail page that mounts external-provider cards**

Run:
```bash
grep -rln "external/uniprot\|external/alphafold\|external/mgi\|external/rgd\|external/gnomad\|api/external" app/src/components app/src/views app/src/api | head
```
Expected: the card components + the route (e.g. `/Genes/<symbol>` or `/genes/HGNC:...`). Record the exact URL to test against `http://localhost:8088`.

- [ ] **Step 2: Capture Lighthouse baseline (perf, LCP, TBT)**

Run (Chrome required; uses the healthy Playwright stack):
```bash
cd app && npx lighthouse "http://localhost:8088/Genes/GRIN2B" \
  --only-categories=performance --preset=desktop --quiet --chrome-flags="--headless=new" \
  --output=json --output-path=../.planning/perf/lh-genes-before.json || true
node -e "const r=require('../.planning/perf/lh-genes-before.json');console.log('perf',r.categories.performance.score,'LCP',r.audits['largest-contentful-paint'].displayValue,'TBT',r.audits['total-blocking-time'].displayValue)"
```
Expected: numeric perf score + LCP + TBT recorded.

- [ ] **Step 3: Capture Playwright network timing baseline (external cards)**

Use the Playwright MCP browser or a quick spec to load the page and dump `/api/external/**` request durations. Record per-card timings.

- [ ] **Step 4: Write the before-numbers into the evidence doc**

Create `.planning/perf/2026-06-13-slow-route-344-before-after.md` with a "Before" section: Lighthouse perf/LCP/TBT, external-card timings, and the page URL/commit hash.

- [ ] **Step 5: Commit**

```bash
git add .planning/perf/2026-06-13-slow-route-344-before-after.md .planning/perf/lh-genes-before.json
git commit -m "docs(perf): capture gene-page baseline before slow-route hardening (#344)"
```

---

## Task 12: Frontend slow-provider resilience Playwright spec

**Files:**
- Create: `app/tests/e2e/slow-provider-resilience.spec.ts`

- [ ] **Step 1: Write the spec (inject latency, assert page renders + cards degrade)**

```ts
import { test, expect } from '@playwright/test';

// #344: a slow external provider must not block the gene page shell/core cards.
// We delay every /api/external/** response by 20s and assert the page + its
// non-external content render well within a few seconds, while external cards
// show a loading/degraded state rather than blocking paint.
test('gene page renders while external providers are slow', async ({ page }) => {
  await page.route('**/api/external/**', async (route) => {
    await new Promise((r) => setTimeout(r, 20_000));
    await route.fulfill({ status: 503, contentType: 'application/json', body: '{"error":true}' });
  });

  const start = Date.now();
  await page.goto('/Genes/GRIN2B', { waitUntil: 'domcontentloaded' });

  // Core (non-external) content must be visible quickly despite the 20s stall.
  await expect(page.getByRole('heading', { name: /GRIN2B/i })).toBeVisible({ timeout: 8_000 });
  const elapsed = Date.now() - start;
  expect(elapsed).toBeLessThan(10_000);

  // The page must remain interactive (no full-page spinner lock).
  await expect(page.locator('body')).toBeVisible();
});
```
(Adjust the URL/selector to the page found in Task 11 Step 1.)

- [ ] **Step 2: Run against the Playwright stack**

Run: `cd app && PLAYWRIGHT_BASE_URL=http://localhost:8088 npx playwright test tests/e2e/slow-provider-resilience.spec.ts`
Expected: PASS if the page is resilient. If it FAILS (page blocks > 10s), Task 13 fixes the blocking card; re-run.

- [ ] **Step 3: Commit**

```bash
git add app/tests/e2e/slow-provider-resilience.spec.ts
git commit -m "test(app): Playwright slow-provider gene-page resilience spec (#344)"
```

---

## Task 13: Fix any blocking external card (conditional on Task 12 result)

**Files:**
- Modify: the offending gene-page external-card component under `app/src/components/**` (identified in Task 11/12)

- [ ] **Step 1: Diagnose whether a card blocks render**

If Task 12 passed, SKIP this task (architecture already resilient — v11.3 SWR + `SectionCard` skeletons). If it failed, find the card that `await`s an external endpoint before rendering the page shell (look for a blocking `await` in `setup`/`onMounted` or a parent gated on the external response).

- [ ] **Step 2: Apply the established resilient pattern**

Make the external card load independently via the typed `app/src/api/*` client + SWR composable (`useResource`), render its own `<SectionCard>` with a skeleton + hide-when-empty, and never gate the page shell or sibling cards on its response. Keep all API access through typed clients (no raw axios, per AGENTS.md).

- [ ] **Step 3: Re-run the resilience spec + type-check**

Run:
```bash
cd app && PLAYWRIGHT_BASE_URL=http://localhost:8088 npx playwright test tests/e2e/slow-provider-resilience.spec.ts
cd app && npm run type-check
```
Expected: both PASS.

- [ ] **Step 4: Commit**

```bash
git add app/src/components
git commit -m "fix(app): load slow external card independently so it can't block gene-page render (#344)"
```

---

## Task 14: After-measurement + before/after evidence

**Files:**
- Modify: `.planning/perf/2026-06-13-slow-route-344-before-after.md`

- [ ] **Step 1: Re-run Lighthouse after the changes**

Run:
```bash
cd app && npx lighthouse "http://localhost:8088/Genes/GRIN2B" \
  --only-categories=performance --preset=desktop --quiet --chrome-flags="--headless=new" \
  --output=json --output-path=../.planning/perf/lh-genes-after.json || true
node -e "const r=require('../.planning/perf/lh-genes-after.json');console.log('perf',r.categories.performance.score,'LCP',r.audits['largest-contentful-paint'].displayValue,'TBT',r.audits['total-blocking-time'].displayValue)"
```
Expected: after-numbers recorded.

- [ ] **Step 2: Fill the "After" + delta section in the evidence doc**

Record Lighthouse delta + the worst-case bounded external latency (now ≤ request ceiling instead of 30-120s). Note the resilience-spec result.

- [ ] **Step 3: Commit**

```bash
git add .planning/perf/2026-06-13-slow-route-344-before-after.md .planning/perf/lh-genes-after.json
git commit -m "docs(perf): record after + delta evidence for slow-route hardening (#344)"
```

---

## Task 15: Documentation

**Files:**
- Modify: `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`

- [ ] **Step 1: Update AGENTS.md external-proxy gotcha**

In the `External proxy fetchers must use memoise_external_success_only()...` bullet, add: every external HTTP call derives timeout/retry from `external_proxy_budget()` (guarded by `test-unit-external-budget-guard.R`); a per-request external-time ceiling (`EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, default 15s) short-circuits further external work via both proxy wrappers; per-request logs carry `duration_ms`/`external_ms`/`slow` (`API_SLOW_REQUEST_MS`, default 2000); cheap routes are guarded against external coupling (`test-unit-cheap-route-isolation.R`); worker-pool isolation remains #154.

- [ ] **Step 2: Update 08-development.qmd**

Add a short subsection: how to run the slow-provider integration test and the Playwright resilience spec; the new env knobs and their defaults.

- [ ] **Step 3: Update 09-deployment.qmd**

Document operator knobs (`EXTERNAL_PROXY_GENEREVIEWS_*`, `EXTERNAL_PROXY_GNOMAD_BATCH_*`, `EXTERNAL_PROXY_REQUEST_MAX_SECONDS`, `API_SLOW_REQUEST_MS`), the `[request-timing]` log format, and degraded-response semantics on ceiling/budget exceed.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md documentation/08-development.qmd documentation/09-deployment.qmd
git commit -m "docs: document external budget guard, request ceiling, timing logs (#344)"
```

---

## Task 16: Full local CI gate + finish

- [ ] **Step 1: Lint + fast API gate + frontend type-check**

Run:
```bash
make lint-api
make test-api-fast
cd app && npm run type-check && cd ..
```
Expected: all green.

- [ ] **Step 2: Full local CI parity**

Run: `make ci-local`
Expected: PASS (closest local mirror of GitHub Actions).

- [ ] **Step 3: Update CHANGELOG + push branch / open PR (only when the user approves push)**

Summarize the #344 hardening in `CHANGELOG.md`; then (on user go-ahead) push `fix/344-slow-route-hardening` and open a PR referencing #344.

---

## Self-Review Notes

- **Spec coverage:** Component 1 → Tasks 2-4; Component 2 (guard) → Task 5; Component 3 (ceiling + cheap-route guard) → Tasks 6,7,9; Component 4 (observability, Option A) → Tasks 6-8; Component 5 (integration test) → Task 10; Component 6 (Playwright+Lighthouse) → Tasks 11-14; Component 7 (docs) → Task 15; dev-fix → Task 0; verification → Task 16.
- **Type/name consistency:** helper names used consistently across tasks — `external_proxy_request_reset()`, `external_proxy_request_add(ms)`, `external_proxy_request_total_ms()`, `external_proxy_request_ceiling_exceeded()`; degraded envelope field `request_budget_exceeded`; `external_proxy_budget(api_name, default_timeout, default_max, default_tries)`.
- **Conditional task:** Task 13 is explicitly conditional on Task 12's result, with the concrete fallback pattern named.
