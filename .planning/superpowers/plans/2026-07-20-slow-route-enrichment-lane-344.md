# Slow-Route Enrichment Lane (#344) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make it structurally impossible for a slow `/api/external/*` request to head-of-line-block cheap routes, by serving external-provider traffic from a dedicated `api-enrichment` process pool (bulkhead), and close the remaining #344 acceptance criteria (retire sticky sessions, declare a replica floor, make the per-request external ceiling a true bound, guard the lane boundary).

**Architecture:** The API is a single-threaded Plumber process per container, so one slow synchronous handler blocks all others in that process. The one remaining slow synchronous surface is `/api/external/*` (live upstream HTTP I/O); all heavy analysis is already snapshot/async. We add a second Compose service (`api-enrichment`) from the same image with all routes mounted, and Traefik path-routes `/api/external` there (higher priority) while everything else stays on the core `api`. This is the synchronous-tier analogue of the existing `worker`/`worker-maintenance` async split. The frontend is unchanged (it still calls `/api/...`; Traefik dispatches).

**Tech Stack:** R/Plumber (`httr2`, `tictoc`), Docker Compose v2, Traefik v3.7, testthat.

## Global Constraints

- Keep handwritten source files under 600 lines (soft ceiling); extract helpers before growing a file.
- Namespace `dplyr::select(...)` etc.; use `base::get(...)` explicitly (the `config` package masks `base::get`).
- Every external HTTP call derives its timeout/retry from `external_proxy_budget()` / `make_external_request()` — never a hardcoded `req_timeout(<n>)` literal (enforced by `test-unit-external-budget-guard.R`).
- The API image must NOT bake `config.yml` into image layers — runtime config comes from the read-only Compose mount.
- Durable job state lives in `async_jobs` (MySQL); no request may depend on landing on a specific API instance.
- The two prod worker services (`worker`, `worker-maintenance`) must stay byte-identical except `ASYNC_JOB_QUEUES`; the new `api`/`api-enrichment` pair follows the same "near-clone, one difference class" discipline.
- Local single-test: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-xyz.R')"`. Full gate: `make test-api-fast`, `make lint-api`, `make ci-local`.
- Validate every Compose edit with `docker compose -f docker-compose.yml config` (prod) and `docker compose config` (dev merge) — both must parse.

---

### Task 1: `API_LANE` helper — gate startup bootstraps off the enrichment lane + label request-timing logs

**Files:**
- Modify: `api/functions/external-proxy-functions.R` (add lane helper near the existing request-state helpers, ~line 330)
- Modify: `api/start_sysndd_api.R:146-187` (wrap the three bootstrap `tryCatch` blocks in a lane gate)
- Modify: `api/bootstrap/mount_endpoints.R:170-210` (add `lane=` to the `[request-timing]` log line)
- Test: `api/tests/testthat/test-unit-api-lane.R` (new)

**Interfaces:**
- Produces: `api_lane()` → character (`"core"` default, lowercased `API_LANE` env); `api_lane_is_enrichment()` → logical. Consumed by Task 4's Compose env (`API_LANE=enrichment`) and by the smoke in Task 6.

- [ ] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-api-lane.R`:

```r
# tests/testthat/test-unit-api-lane.R
# Pure test (no DB / no network) — runs on host.
# Guards the #344 enrichment-lane identity helper used to (a) gate startup
# bootstraps off the enrichment lane and (b) label request-timing logs.

test_that("api_lane defaults to core and is case-insensitive", {
  withr::with_envvar(c(API_LANE = ""), {
    expect_identical(api_lane(), "core")
    expect_false(api_lane_is_enrichment())
  })
  withr::with_envvar(c(API_LANE = "Enrichment"), {
    expect_identical(api_lane(), "enrichment")
    expect_true(api_lane_is_enrichment())
  })
  withr::with_envvar(c(API_LANE = "core"), {
    expect_false(api_lane_is_enrichment())
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-api-lane.R')"`
Expected: FAIL — `could not find function "api_lane"`.

- [ ] **Step 3: Add the helper**

In `api/functions/external-proxy-functions.R`, after the request-ceiling helpers (~line 330), add:

```r
#' Which synchronous API lane this process serves (#344).
#'
#' The core lane serves cheap/own-data routes; the enrichment lane serves
#' `/api/external/*` only (Traefik-routed). Lane identity gates startup
#' bootstraps (only the core lane owns them) and labels request-timing logs.
#'
#' @return "core" (default) or "enrichment", lowercased from the API_LANE env.
#' @export
api_lane <- function() {
  lane <- tolower(trimws(Sys.getenv("API_LANE", "core")))
  if (identical(lane, "enrichment")) "enrichment" else "core"
}

#' @rdname api_lane
#' @export
api_lane_is_enrichment <- function() identical(api_lane(), "enrichment")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-api-lane.R')"`
Expected: PASS (3 assertions).

- [ ] **Step 5: Gate the startup bootstraps in `start_sysndd_api.R`**

Wrap the three bootstrap `tryCatch` blocks (`pubtatornidd_bootstrap_enrichment` L147, `analysis_snapshot_bootstrap_on_startup` L168, `disease_ontology_mapping_bootstrap_on_startup` L183). Replace the block spanning lines 141-187 so all three run only on the core lane:

```r
## -------------------------------------------------------------------##
# 9b-9d) Startup bootstraps (pubtatornidd enrichment #421, analysis snapshots
#        #420, disease ontology mapping WP-C). These enqueue durable jobs and
#        are the CORE lane's responsibility only: the enrichment lane (#344)
#        depends_on the core API being healthy (migrations + these bootstraps
#        already done), so it must NOT re-run them.
## -------------------------------------------------------------------##
if (!api_lane_is_enrichment()) {
  tryCatch(
    pubtatornidd_bootstrap_enrichment(),
    error = function(e) {
      message(sprintf("[pubtatornidd-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )

  tryCatch(
    analysis_snapshot_bootstrap_on_startup(),
    error = function(e) {
      message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )

  tryCatch(
    disease_ontology_mapping_bootstrap_on_startup(),
    error = function(e) {
      message(sprintf("[ontology-mapping-bootstrap] skipped: %s", conditionMessage(e)))
    }
  )
} else {
  message("[api-lane] enrichment lane: skipping startup bootstraps (core lane owns them)")
}
```

Leave the credential scrub (`async_job_scrub_payload_credentials_on_startup()`, L159) OUTSIDE the gate — it is idempotent, cheap, and safe on both lanes; keep it where it is (move it above the `if` block, before the bootstraps).

- [ ] **Step 6: Add `lane=` to the request-timing log**

In `api/bootstrap/mount_endpoints.R`, inside the `postroute` hook where `structured_timing` is built (the `paste0("[request-timing] ", ...)` block), add the lane field right after `method=`:

```r
  structured_timing <- paste0(
    "[request-timing] ",
    "lane=", api_lane(),
    " method=", convert_empty(req$REQUEST_METHOD),
    " path=", convert_empty(req$PATH_INFO),
    " status=", convert_empty(res$status),
    " duration_ms=", as.integer(round(duration_ms)),
    " external_ms=", as.integer(round(external_ms)),
    " slow=", tolower(as.character(duration_ms >= slow_threshold_ms))
  )
```

- [ ] **Step 7: Run lint + the lane test**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-api-lane.R')"` → PASS
Run: `make lint-api` → no new lint errors in the three touched files.

- [ ] **Step 8: Commit**

```bash
git add api/functions/external-proxy-functions.R api/start_sysndd_api.R api/bootstrap/mount_endpoints.R api/tests/testthat/test-unit-api-lane.R
git commit -m "feat(api): API_LANE helper — gate startup bootstraps off enrichment lane + label timing logs (#344)"
```

---

### Task 2: Make the per-request external ceiling a true bound (MGI two-call fetcher)

**Files:**
- Modify: `api/functions/external-proxy-functions.R` (add `external_proxy_request_would_exceed()` near the ceiling helpers)
- Modify: `api/functions/external-proxy-mgi.R:113-140` (skip the best-effort zygosity call when the ceiling would already be crossed)
- Test: `api/tests/testthat/test-unit-external-proxy-request-bound.R` (new)

**Interfaces:**
- Consumes: `external_proxy_request_reset()`, `external_proxy_request_add(ms)`, `external_proxy_request_total_ms()`, `external_proxy_request_ceiling_ms()` (existing, `external-proxy-functions.R:299-323`).
- Produces: `external_proxy_request_would_exceed(pending_ms = 0)` → logical.

- [ ] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-external-proxy-request-bound.R`:

```r
# tests/testthat/test-unit-external-proxy-request-bound.R
# Pure test (no DB / no network) — runs on host.
# #344: a multi-call fetcher must be able to see, BEFORE a subsequent upstream
# call, that this request has already spent (or, counting the just-elapsed but
# not-yet-accumulated time, is about to spend) its external-time ceiling.

test_that("external_proxy_request_would_exceed accounts for pending, not-yet-added time", {
  withr::with_envvar(c(EXTERNAL_PROXY_REQUEST_MAX_SECONDS = "15"), {
    external_proxy_request_reset()
    expect_false(external_proxy_request_would_exceed(0))
    expect_false(external_proxy_request_would_exceed(14000)) # 14s < 15s ceiling

    # Simulate 10s already accumulated from a prior fetcher this request.
    external_proxy_request_add(10000)
    expect_false(external_proxy_request_would_exceed(0))     # 10s < 15s
    expect_true(external_proxy_request_would_exceed(6000))   # 10s + 6s pending >= 15s
    external_proxy_request_reset()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-proxy-request-bound.R')"`
Expected: FAIL — `could not find function "external_proxy_request_would_exceed"`.

- [ ] **Step 3: Add the helper**

In `api/functions/external-proxy-functions.R`, immediately after `external_proxy_request_ceiling_exceeded()` (~line 329):

```r
#' Would this request cross its external-time ceiling if it spent `pending_ms`
#' more? Lets a multi-call fetcher skip a subsequent best-effort upstream call
#' instead of driving one request through several full provider budgets (#344).
#'
#' Unlike `external_proxy_request_ceiling_exceeded()`, this counts just-elapsed
#' time the wrapping `external_proxy_with_timing()` has not yet accumulated (it
#' adds only after its closure returns).
#'
#' @param pending_ms Milliseconds already spent on the current in-flight call
#'   that are not yet reflected in the accumulator.
#' @return TRUE if `accumulated + pending_ms >= ceiling`.
#' @export
external_proxy_request_would_exceed <- function(pending_ms = 0) {
  (external_proxy_request_total_ms() + pending_ms) >= external_proxy_request_ceiling_ms()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-proxy-request-bound.R')"`
Expected: PASS.

- [ ] **Step 5: Use the guard in the MGI fetcher**

In `api/functions/external-proxy-mgi.R`, measure step-1 elapsed and skip the best-effort step-2 (zygosity) call when the ceiling would already be crossed. Change the step-1 `req_perform()` block (L60-80) to capture elapsed, and gate the `if (!is.null(mouse_symbol) ...)` block (L114):

Replace the step-1 perform (keep the pipeline identical, wrap timing around it):

```r
        step1_start <- proc.time()[["elapsed"]]
        phenotype_response <- httr2::request(phenotype_url) |>
          httr2::req_url_query(
            name = "HGene_MPhenotype",
            constraint1 = "Gene",
            op1 = "LOOKUP",
            value1 = gene_symbol,
            extra1 = "H. sapiens",
            format = "json",
            size = "10000"
          ) |>
          httr2::req_retry(
            max_tries = budget$max_tries,
            max_seconds = budget$max_seconds,
            backoff = ~2
          ) |>
          httr2::req_throttle(
            rate = EXTERNAL_API_THROTTLE$mgi$capacity / EXTERNAL_API_THROTTLE$mgi$fill_time_s,
            realm = "mousemine"
          ) |>
          httr2::req_timeout(budget$timeout_seconds) |>
          httr2::req_perform()
        step1_elapsed_ms <- (proc.time()[["elapsed"]] - step1_start) * 1000
```

Then change the step-2 guard condition (L114) from:

```r
        if (!is.null(mouse_symbol) && nchar(mouse_symbol) > 0) {
```

to:

```r
        # #344: skip the best-effort zygosity call if step 1 already consumed
        # this request's external-time ceiling, so a slow MouseMine cannot drive
        # ONE request through TWO full provider budgets (~2x the nominal 15s).
        if (!is.null(mouse_symbol) && nchar(mouse_symbol) > 0 &&
          !external_proxy_request_would_exceed(step1_elapsed_ms)) {
```

(The phenotypes from step 1 are still returned; only the optional zygosity enrichment is skipped when over budget.)

- [ ] **Step 6: Add a static assertion that MGI references the guard**

Append to `api/tests/testthat/test-unit-external-proxy-request-bound.R`:

```r
test_that("MGI fetcher gates its second upstream call on the request ceiling", {
  path <- file.path(get_api_dir(), "functions", "external-proxy-mgi.R")
  src <- readLines(path, warn = FALSE)
  src <- src[!grepl("^\\s*#", src)]
  expect_true(
    any(grepl("external_proxy_request_would_exceed", src)),
    info = "external-proxy-mgi.R must gate its zygosity call on the per-request ceiling (#344)"
  )
})
```

- [ ] **Step 7: Run tests + guard**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-proxy-request-bound.R')"` → PASS (both tests)
Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-budget-guard.R')"` → PASS (no hardcoded-timeout regression introduced).

- [ ] **Step 8: Commit**

```bash
git add api/functions/external-proxy-functions.R api/functions/external-proxy-mgi.R api/tests/testthat/test-unit-external-proxy-request-bound.R
git commit -m "fix(api): bound multi-call MGI fetcher by the per-request external ceiling (#344)"
```

---

### Task 3: Boundary-completeness static guard for external-fetcher callers

**Files:**
- Test: `api/tests/testthat/test-unit-external-fetcher-allowlist.R` (new)

**Interfaces:**
- Consumes nothing from other tasks. Enforces that the set of files invoking an external fetcher on a public request path equals a known allowlist, so a NEW external-calling public endpoint cannot silently land on the core lane (bypassing the Traefik `/api/external` bulkhead).

- [ ] **Step 1: Write the test (it IS the deliverable)**

Create `api/tests/testthat/test-unit-external-fetcher-allowlist.R`:

```r
# tests/testthat/test-unit-external-fetcher-allowlist.R
# Pure test (no DB / no network) — runs on host.
#
# #344 bulkhead boundary guard: `/api/external/*` is Traefik-routed to the
# dedicated `api-enrichment` process pool so a slow upstream cannot block cheap
# routes. That guarantee holds only if the ONLY public request-path file that
# invokes an external fetcher is `external_endpoints.R`. This test fails if a
# new endpoint file starts calling an external fetcher without being routed to
# the enrichment lane (or added, with justification, to the allowlist below).

test_that("only allowlisted endpoint files invoke external fetchers on the request path", {
  edir <- file.path(get_api_dir(), "endpoints")
  # Files legitimately allowed to call external fetchers from a request handler:
  allowlist <- c(
    "external_endpoints.R", # THE enrichment-lane surface (/api/external/*)
    "entity_endpoints.R"    # Curator-gated POST /entity/create -> GeneReviews
                            # (write path, low-frequency, budget-bounded; stays on core)
  )
  pattern <- "external_proxy_[a-z]|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd|genereviews)"
  offenders <- character()
  for (path in list.files(edir, pattern = "_endpoints\\.R$", full.names = TRUE)) {
    fname <- basename(path)
    if (fname %in% allowlist) next
    src <- readLines(path, warn = FALSE)
    src <- src[!grepl("^\\s*#", src)]
    hits <- grep(pattern, src, value = TRUE)
    if (length(hits)) offenders <- c(offenders, paste0(fname, ": ", trimws(hits)))
  }
  expect_identical(
    offenders, character(),
    info = paste(
      "New external-fetcher caller outside the enrichment-lane allowlist —",
      "route it under /api/external or justify + add to the allowlist:",
      paste(offenders, collapse = " | ")
    )
  )
})

test_that("the enrichment-lane surface actually calls external fetchers (guard is live)", {
  # Sanity: if this fails, the pattern drifted and the guard above is inert.
  path <- file.path(get_api_dir(), "endpoints", "external_endpoints.R")
  src <- readLines(path, warn = FALSE)
  pattern <- "external_proxy_[a-z]|fetch_(gnomad|uniprot|ensembl|alphafold|mgi|rgd)"
  expect_true(any(grepl(pattern, src)))
})
```

- [ ] **Step 2: Run to verify it passes on the current tree**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-fetcher-allowlist.R')"`
Expected: PASS (2 tests). If it FAILS, an existing file already calls a fetcher — investigate before proceeding (the boundary assumption is wrong and the spec must be revisited).

- [ ] **Step 3: Prove the guard bites (manual negative check, do not commit the edit)**

Temporarily add `fetch_mgi_phenotypes("X")` to a non-allowlisted file (e.g. `api/endpoints/health_endpoints.R`), re-run the test, confirm it now FAILS naming that file, then revert the edit.

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-fetcher-allowlist.R')"` → FAIL (expected), then revert.

- [ ] **Step 4: Commit**

```bash
git add api/tests/testthat/test-unit-external-fetcher-allowlist.R
git commit -m "test(api): guard the /api/external bulkhead boundary is complete (#344)"
```

---

### Task 4: Add the `api-enrichment` Compose service + Traefik enrichment router

**Files:**
- Modify: `docker-compose.yml` (add the `api-enrichment` service after the `api` service block, ~after line 261)

**Interfaces:**
- Consumes: `API_LANE=enrichment` (Task 1) so the service skips startup bootstraps; the existing `api-strip-xff-alias` middleware (defined on the `api` service labels, `docker-compose.yml:252-254`).
- Produces: a Traefik router `api-enrichment` (`PathPrefix('/api/external')`, priority 200) → the `api-enrichment` service on port 7777. Consumed by Task 6's smoke.

- [ ] **Step 1: Add the service**

Insert into `docker-compose.yml` after the `api` service's `labels:` block (after line 261), a near-clone of `api` mirroring its volumes/env (I/O-bound, low-resource), depending on the core `api` being healthy, with bootstraps disabled via the lane and its own Traefik router:

```yaml
  # #344: synchronous "enrichment" lane. Same image + full router as `api`, but
  # Traefik sends it ONLY /api/external/* (live upstream provider I/O). Isolating
  # that surface into its own process pool means a slow upstream can never
  # head-of-line-block cheap/core routes (health/auth/statistics/entity/gene/
  # analysis/jobs), which stay on `api`. Mirrors the worker/worker-maintenance
  # async-lane split. Scale independently: --scale api-enrichment=N.
  api-enrichment:
    image: ${SYSNDD_API_IMAGE:-sysndd-api:latest}
    build:
      context: ./api/
      args:
        UID: ${HOST_UID:-1000}
        GID: ${HOST_GID:-1000}
    command: ["Rscript", "start_sysndd_api.R"]
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    depends_on:
      api:
        condition: service_healthy   # migrations + startup bootstraps done by core first
    volumes:
      - ./api/endpoints:/app/endpoints
      - ./api/functions:/app/functions
      - ./api/core:/app/core
      - ./api/services:/app/services
      - ./api/bootstrap:/app/bootstrap
      - ./api/config:/app/config
      - ./api/scripts:/app/scripts:ro
      - ./api/data:/app/data
      - ./api/results:/app/results
      - ./db/migrations:/app/db/migrations:ro
      - api_cache:/app/cache
      - ./api/config.yml:/app/config.yml:ro
      - ./api/version_spec.json:/app/version_spec.json
      - ./api/start_sysndd_api.R:/app/start_sysndd_api.R
    environment:
      ENVIRONMENT: production
      API_LANE: enrichment            # #344: skip startup bootstraps (core owns them)
      PASSWORD: ${PASSWORD}
      SMTP_PASSWORD: ${SMTP_PASSWORD}
      DB_POOL_SIZE: ${API_ENRICHMENT_DB_POOL_SIZE:-3}
      MIRAI_WORKERS: 1                # I/O-bound proxy calls, no heavy compute here
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      NCBI_API_KEY: ${NCBI_API_KEY:-}
      NCBI_EUTILS_EMAIL: ${NCBI_EUTILS_EMAIL:-}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-}
      CACHE_VERSION: ${CACHE_VERSION:-3}
      OMIM_DOWNLOAD_KEY: ${OMIM_DOWNLOAD_KEY}
      # Belt-and-braces: the API_LANE gate already skips these, but pin the flags
      # off too so a future ungated bootstrap cannot double-run on this lane.
      ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP: "false"
      DISEASE_ONTOLOGY_MAPPING_BOOTSTRAP_ON_STARTUP: "false"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:7777/api/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 2048M
          cpus: '1.0'
    networks:
      - proxy      # egress for external providers
      - backend    # DB for cache reads/writes (e.g. RGD id lookup)
    labels:
      - "traefik.enable=true"
      # Higher priority than the core `api` router (100) so /api/external wins.
      - "traefik.http.routers.api-enrichment.rule=Host(`sysndd.dbmr.unibe.ch`) && PathPrefix(`/api/external`)"
      - "traefik.http.routers.api-enrichment.entrypoints=web"
      - "traefik.http.routers.api-enrichment.priority=200"
      - "traefik.http.routers.api-enrichment.middlewares=api-strip-xff-alias@docker"
      - "traefik.http.services.api-enrichment.loadbalancer.server.port=7777"
      # No sticky cookie: the enrichment lane is stateless (durable MySQL jobs).
```

- [ ] **Step 2: Validate the prod compose parses and the router resolves**

Run: `docker compose -f docker-compose.yml config >/dev/null && echo OK`
Expected: `OK` (no YAML/interpolation errors).

Run: `docker compose -f docker-compose.yml config | grep -A1 "api-enrichment.rule"`
Expected: shows the `PathPrefix(\`/api/external\`)` rule at priority 200.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(infra): add api-enrichment lane serving /api/external via Traefik (#344)"
```

---

### Task 5: Retire sticky sessions, declare the prod replica floor, keep dev single-lane

**Files:**
- Modify: `docker-compose.yml:217-261` (remove sticky labels on `api`; add `deploy.replicas: 2`)
- Modify: `docker-compose.override.yml:59-70` (pin dev `api` to 1 replica; profile-gate `api-enrichment` out of dev)

**Interfaces:**
- Consumes: Task 4's `api-enrichment` service (profile-gated out of dev here).

- [ ] **Step 1: Remove the sticky-session labels on `api`**

In `docker-compose.yml`, delete the four sticky-cookie label lines (currently 257-261):

```yaml
      # Sticky sessions for job state consistency across scaled API containers
      - "traefik.http.services.api.loadbalancer.sticky.cookie=true"
      - "traefik.http.services.api.loadbalancer.sticky.cookie.name=sysndd_api_sticky"
      - "traefik.http.services.api.loadbalancer.sticky.cookie.httponly=true"
      - "traefik.http.services.api.loadbalancer.sticky.cookie.samesite=lax"
```

Replace with a one-line rationale comment:

```yaml
      # #344: sticky sessions removed — job state is durable in `async_jobs`
      # (MySQL), so no request needs the same instance. Sticky harmed load
      # distribution (the exact thing the 2026-05-18 mitigation had to undo).
```

- [ ] **Step 2: Declare the core replica floor**

In the `api` service's `deploy:` block (`docker-compose.yml:217`), add `replicas: 2` above `resources:`:

```yaml
    deploy:
      # #344: core lane floor. A single API container gives zero cross-request
      # isolation; two replicas is the baseline. Override for load tests with
      # `--scale api=N`.
      replicas: 2
      resources:
        limits:
          memory: 4608M
          cpus: '2.0'
```

- [ ] **Step 3: Keep dev single-lane in the override**

In `docker-compose.override.yml`, extend the `api:` service block (currently 59-70) to pin replicas to 1, and append an `api-enrichment:` profile gate at the end of the `services:` map (mirroring the `worker-maintenance` gate at 157-159):

```yaml
  api:
    labels:
      - "traefik.http.routers.api.rule=(Host(`sysndd.dbmr.unibe.ch`) || Host(`localhost`) || Host(`127.0.0.1`)) && PathPrefix(`/api`)"
    environment:
      ENVIRONMENT: development
      MIRAI_WORKERS: ${MIRAI_WORKERS:-1}
    # DEV: one API container. The prod floor (deploy.replicas: 2) would spin two
    # containers that both re-run startup work on a memory-constrained laptop.
    deploy:
      replicas: 1
```

And, alongside the existing `worker-maintenance` gate at the bottom of the file:

```yaml
  # DEV: keep the enrichment lane OUT of the local stack (#344). Its Traefik
  # router disappears with it, so /api/external falls through to the single dev
  # `api` via the /api router — dev stays one lane; prod runs both.
  api-enrichment:
    profiles:
      - prod-enrichment-lane
```

- [ ] **Step 4: Validate both prod and dev merges parse and dev excludes the enrichment lane**

Run: `docker compose -f docker-compose.yml config | grep -c "sticky"` → `0`
Run: `docker compose -f docker-compose.yml config | grep -A2 "^  api:" | grep replicas` → shows `replicas: 2`
Run: `docker compose config --services` (dev merge, override auto-loaded) → list must NOT contain `api-enrichment`.
Run: `docker compose config | grep -A2 "^  api:" | grep replicas` (dev) → shows `replicas: 1`.

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml docker-compose.override.yml
git commit -m "feat(infra): retire sticky sessions, declare prod core replica floor, keep dev single-lane (#344)"
```

---

### Task 6: Two-lane isolation smoke script + make target

**Files:**
- Create: `scripts/smoke-lane-isolation.sh`
- Modify: `Makefile` (add a `smoke-lane-isolation` target)

**Interfaces:**
- Consumes: the two-lane prod stack (Tasks 4-5). This is the authoritative cross-container bulkhead proof a unit test cannot give; it is operator/CI-optional, not in the fast unit gate.

- [ ] **Step 1: Write the smoke script**

Create `scripts/smoke-lane-isolation.sh`:

```bash
#!/usr/bin/env bash
# #344 two-lane bulkhead smoke. Requires the PROD two-lane stack up:
#   docker compose -f docker-compose.yml up -d --build
# Saturates the enrichment lane with a concurrent burst of /api/external
# aggregator requests (each fans out to up to 7 upstream sources, so the single
# enrichment process stays busy regardless of cache warmth), and concurrently
# probes /api/health on the core lane, asserting the core probe stays fast.
# Best-effort operator smoke (needs the running stack), not a fast-unit gate.
set -euo pipefail

BASE="${SMOKE_BASE_URL:-http://localhost}"
HEALTH_BUDGET_MS="${HEALTH_BUDGET_MS:-1500}"
SYM="${SMOKE_SYMBOL:-SCN2A}"        # a seeded gene; the aggregator hits live upstreams
BURST="${SMOKE_BURST:-24}"          # > enrichment replica count -> queues on that process

echo "[smoke] saturating the enrichment lane: ${BURST} concurrent /api/external/gene/${SYM}"
pids=()
for _ in $(seq 1 "$BURST"); do
  curl -s -o /dev/null "${BASE}/api/external/gene/${SYM}" &
  pids+=($!)
done

sleep 1   # let the burst occupy the single enrichment process
worst=0
for i in 1 2 3 4 5 6 7 8; do
  ms=$(curl -s -o /dev/null -w '%{time_total}' "${BASE}/api/health/" | awk '{printf "%d", $1*1000}')
  echo "[smoke] /api/health/ probe ${i}: ${ms}ms"
  (( ms > worst )) && worst=$ms
  sleep 0.25
done
for p in "${pids[@]}"; do wait "$p" 2>/dev/null || true; done

if (( worst > HEALTH_BUDGET_MS )); then
  echo "[smoke] FAIL: worst /api/health/ ${worst}ms > ${HEALTH_BUDGET_MS}ms while the enrichment lane was saturated — cheap routes are still blocked."
  exit 1
fi
echo "[smoke] PASS: /api/health/ stayed under ${HEALTH_BUDGET_MS}ms (worst ${worst}ms) under enrichment-lane saturation."
```

Make it executable: `chmod +x scripts/smoke-lane-isolation.sh`.

- [ ] **Step 2: Add the make target**

In `Makefile`, add:

```makefile
.PHONY: smoke-lane-isolation
smoke-lane-isolation: ## #344: prove /api/health stays fast while /api/external is slow (needs the two-lane prod stack up)
	bash scripts/smoke-lane-isolation.sh
```

- [ ] **Step 3: Run it against a local two-lane stack**

Run: `docker compose -f docker-compose.yml up -d --build`
Wait for `api` and `api-enrichment` healthy: `docker compose -f docker-compose.yml ps`
Run: `make smoke-lane-isolation`
Expected: `[smoke] PASS: ...`. (If FAIL, confirm `api-enrichment` is actually receiving `/api/external` — check `docker compose -f docker-compose.yml logs api-enrichment | grep 'lane=enrichment'` and the core `api` logs show `lane=core` for `/api/health/`.)

- [ ] **Step 4: Commit**

```bash
git add scripts/smoke-lane-isolation.sh Makefile
git commit -m "test(infra): two-lane bulkhead isolation smoke + make target (#344)"
```

---

### Task 7: Documentation

**Files:**
- Modify: `AGENTS.md` (new "Synchronous API lanes" subsection under Architecture Invariants)
- Modify: `documentation/09-deployment.qmd` (operator guide; update the stale "#154 stopgap" note)
- Modify: `documentation/08-development.qmd` (dev single-lane; how to run the two-lane stack locally)
- Modify: `CHANGELOG.md` (entry under the next unreleased version)

**Interfaces:** none (docs).

- [ ] **Step 1: AGENTS.md — add the invariant**

Under `## Architecture Invariants`, add a subsection (place it near "### Background jobs" since it mirrors the worker-lane concept):

```markdown
### Synchronous API lanes (core vs enrichment)

The API is one single-threaded Plumber process per container, so a slow
synchronous handler blocks every other request in that process (#344). The one
remaining slow synchronous surface is `/api/external/*` (live upstream provider
I/O; all heavy analysis is snapshot/async and 503s fast on a miss). To bulkhead
it, production runs two API services from the SAME image with the FULL router
mounted on both: the core `api` (health/auth/statistics/entity/gene/analysis/
jobs) and `api-enrichment`, which Traefik feeds ONLY `/api/external/*` (router
priority 200 > the `/api` router's 100). Cheap routes therefore run on a pool no
slow upstream can occupy — the synchronous-tier analogue of the
`worker`/`worker-maintenance` async split. The frontend is unchanged (it calls
`/api/...`; Traefik dispatches). `api-enrichment` sets `API_LANE=enrichment`,
which makes `start_sysndd_api.R` skip the startup bootstraps (the core lane owns
them; enrichment `depends_on: api healthy`), and labels its `[request-timing]`
logs `lane=enrichment`. Sticky sessions are removed (job state is durable in
`async_jobs`); the core `api` declares `deploy.replicas: 2` in prod and the dev
override pins it back to 1 and profile-gates `api-enrichment` out of dev
(`prod-enrichment-lane`), so `make dev` stays single-lane. The bulkhead boundary
is kept complete by `test-unit-external-fetcher-allowlist.R` (only
`external_endpoints.R` + the Curator-gated `entity_endpoints.R` create path may
call an external fetcher on a request path). The per-request external ceiling is
now a true bound: the multi-call MGI fetcher re-checks it before its best-effort
zygosity call (`external_proxy_request_would_exceed()`), so one request cannot
spend ~2x a provider budget. Operator smoke: `make smoke-lane-isolation`. This
resolves the #344 gap that was formerly deferred to the now-closed #154.
```

- [ ] **Step 2: 09-deployment.qmd — operator guide**

Find the existing note that says true heavy/light isolation is "tracked in issue #154" and prescribes "run the API with more than one replica and non-sticky routing" (~line 161). Replace it with the resolved state: the two-lane topology, that sticky is now removed, `deploy.replicas: 2` core floor, `--scale api-enrichment=N` to scale the enrichment lane, the routing table (`/api/external` → enrichment @ prio 200; `/api` → core @ 100; `/` → SPA @ 1), the `API_LANE` env, and `make smoke-lane-isolation`. Note both core replicas run migrations/bootstraps on cold start (advisory-locked + idempotent — pre-existing behavior) and that the enrichment lane skips bootstraps via `API_LANE`.

- [ ] **Step 3: 08-development.qmd — dev workflow**

Add: `make dev` runs a single API container (the enrichment lane is profile-gated out); `/api/external` is served by that single container in dev. To reproduce the two-lane isolation locally, run `docker compose -f docker-compose.yml up -d --build` (prod compose, no override) and `make smoke-lane-isolation`.

- [ ] **Step 4: CHANGELOG.md**

Add an entry under the next unreleased section summarizing: enrichment-lane bulkhead for `/api/external/*`, sticky-session removal, prod replica floor, the real per-request external ceiling (MGI), the boundary allowlist guard, and the isolation smoke — closing the #344 structural gap left after PR #386/#413 (formerly deferred to the closed #154).

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md documentation/09-deployment.qmd documentation/08-development.qmd CHANGELOG.md
git commit -m "docs: enrichment-lane bulkhead, sticky removal, replica floor, real external ceiling (#344)"
```

---

## Final verification (run before handoff / PR)

- [ ] `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-api-lane.R')"` → PASS
- [ ] `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-proxy-request-bound.R')"` → PASS
- [ ] `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-external-fetcher-allowlist.R')"` → PASS
- [ ] `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-cheap-route-isolation.R')"` and `test-unit-external-budget-guard.R` → PASS (no regression)
- [ ] `docker compose -f docker-compose.yml config >/dev/null` and `docker compose config >/dev/null` → both parse; dev services exclude `api-enrichment`; prod `api` has no `sticky` labels and `replicas: 2`
- [ ] `make lint-api` → clean
- [ ] `make test-api-fast` → PASS
- [ ] Two-lane stack up → `make smoke-lane-isolation` → PASS
- [ ] `make ci-local` → PASS

## Self-review notes (spec coverage)

- Spec Component 1 (enrichment lane) → Task 4. Component 2 (Traefik routing) → Task 4. Component 3 (sticky retire) → Task 5. Component 4 (replica floor + dev) → Task 5. Component 5 (real ceiling) → Task 2. Component 6 (boundary guard + observability) → Task 3 (guard) + Task 1 (lane log). Component 7 (docs) → Task 7. Startup-bootstrap subordination (spec §3 Component 1) → Task 1. Smoke (spec §5) → Task 6. All spec sections have a task.
- Deliberately deferred (spec §8): cache-first external decoupling — not planned here.
- Not fixed (out of scope, noted): the latent double-count when `fetch_rgd_phenotypes` nests `fetch_rgd_phenotypes_by_id` — not on the request path (the endpoint calls `fetch_rgd_phenotypes_by_id_mem` directly); the per-replica rate-limiter caveat (documented, no code change).
