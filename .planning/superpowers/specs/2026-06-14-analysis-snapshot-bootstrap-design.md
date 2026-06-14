# Auto-bootstrap analysis snapshots on startup (+ admin refresh/status endpoints)

**Issue:** #420
**Date:** 2026-06-14
**Branch:** `feat/analysis-snapshot-bootstrap`
**Author:** automated implementation per issue #420 (owner-authored spec)

## Problem

After a fresh deploy / container rebuild, every public analysis page that reads
from the `analysis_snapshot_*` tables returns **HTTP 503 `snapshot_missing`**
until an operator manually runs `make refresh-analysis-snapshots`
(`docker exec sysndd-api-1 Rscript /app/scripts/refresh-analysis-snapshots.R`).

Concretely (verified in production 2026-06-13/14 after deploying v0.21.8):

| Page | Endpoint | Result |
|------|----------|--------|
| `/GeneNetworks` | `/api/analysis/network_edges`, `/api/analysis/functional_clustering` | 503 `snapshot_missing` |
| `/PhenotypeCorrelations/PhenotypeClusters` | `/api/analysis/phenotype_clustering` | 503 `snapshot_missing` |

Root cause: migrations create the six `analysis_snapshot_*` tables, but
`analysis_snapshot_manifest` starts empty and **nothing ever submits the
`analysis_snapshot_refresh` jobs** — there is no startup hook and no HTTP route,
only the operator script. The pages are dead on arrival, and the only fix path
requires SSH + docker access (which was itself rate-limited mid-incident).

This is the same class of footgun that issue #421 already fixed for the
PubtatorNDD enrichment snapshot. We mirror that proven solution.

## Goals

1. **Startup auto-bootstrap** — after migrations apply, idempotently submit
   `analysis_snapshot_refresh` for any supported preset lacking an active
   current public-ready snapshot row. Enqueue nothing when snapshots already
   exist. Gated by config/env, logged clearly, never crashes boot.
2. **Authenticated admin endpoints** — let an operator rebuild + inspect
   snapshots over HTTP without SSH/docker:
   - `POST /api/admin/analysis/snapshots/refresh` (Administrator) — submit the
     refresh jobs (optionally one `analysis_type`, optional `force`), return job ids.
   - `GET /api/admin/analysis/snapshots/status` (Administrator) — per-preset
     manifest state (missing / available / stale / source_version_mismatch).
3. **DRY** — one shared submit function used by the startup hook, the admin
   endpoint, and the existing operator script.
4. **Frontend resilience (nice-to-have, in scope)** — when an analysis page
   gets a 503 `snapshot_missing` / `snapshot_stale` / `source_version_mismatch`,
   show a friendly "analysis is being prepared, check back shortly" state with a
   retry, instead of a raw `AxiosError ... 503` and an empty page.

## Non-goals

- No change to how snapshots are *built* or *activated* (the worker handler,
  builder, presets, and parameter-hash semantics are untouched).
- No new admin UI page/button (operator uses the existing admin token + curl;
  a future admin UI can consume the new endpoints). The typed frontend client
  for the admin routes is out of scope for this change.
- Bootstrap does **not** rebuild stale/mismatched snapshots — a `public_ready`
  row existing (even if stale) means "nothing to do" on startup, to keep
  restarts cheap. Staleness is handled by the nightly path and by the admin
  endpoint's `force=true`.

## Architecture

Three deliverables across **disjoint file sets** (so they parallelize cleanly):

### Sprint A — API core (shared submit + repository reads + startup hook)

**A1. Repository (cheap reads)** — `api/functions/analysis-snapshot-repository.R`

- `analysis_snapshot_public_exists(analysis_type, parameter_hash, conn = NULL)`
  → `TRUE/FALSE`. Cheap existence probe, mirrors the public-ready predicate of
  `analysis_snapshot_get_public`:
  ```sql
  SELECT snapshot_id FROM analysis_snapshot_manifest
   WHERE analysis_type = ? AND parameter_hash = ?
     AND public_ready = 1 AND status = 'public_ready'
   LIMIT 1
  ```
  No data-row fetch (unlike `analysis_snapshot_get_public`, which fetches 5 child
  tables when available).
- `analysis_snapshot_public_manifest(analysis_type, parameter_hash, conn = NULL)`
  → the public-ready manifest row (single row) annotated with the computed
  `status_code` via `analysis_snapshot_status_code()`, or `NULL` when missing.
  Reuses the existing source-data-version freshness logic but skips the child
  table queries (status overview is metadata-only).

**A2. Service (shared submit + status + bootstrap)** — `api/services/analysis-snapshot-service.R`

- `service_analysis_snapshot_submit_refresh(analysis_type = NULL, force = FALSE, presets = NULL, submit_fn = async_job_service_submit, exists_fn = analysis_snapshot_public_exists, conn = NULL)`
  — the single shared submit loop. For each target preset:
  1. normalize params via `analysis_snapshot_normalize_params()` → canonical
     `parameter_hash` + `params` (matches what the worker stores and the read
     path queries),
  2. unless `force`, skip presets whose `(analysis_type, parameter_hash)` already
     has a public-ready row (`exists_fn`),
  3. submit `async_job_service_submit(job_type = "analysis_snapshot_refresh", request_payload = list(analysis_type, params), queue_name = "default", priority = 50L)`,
  4. record a per-preset outcome.
  Returns a structured summary:
  ```r
  list(
    requested = <int>,                 # presets considered
    submitted = <int>,                 # new jobs enqueued
    reused    = <int>,                 # dedup hits (queued/running job reused)
    skipped   = <int>,                 # already public-ready (force = FALSE)
    failed    = <int>,
    force     = <lgl>,
    results   = list(<per-preset {analysis_type, parameter_hash, action, job_id, message}>)
  )
  ```
  `action` ∈ `"submitted" | "reused" | "skipped_existing" | "error"`.
  `analysis_type = NULL` ⇒ all supported presets; a single `analysis_type` ⇒
  just that preset (400-class error surfaced if unknown — reuses
  `analysis_snapshot_normalize_params`' `unsupported_parameter` error so the
  endpoint maps it to 400).
- `service_analysis_snapshot_status(presets = NULL, manifest_fn = analysis_snapshot_public_manifest, conn = NULL)`
  — per-preset state for the status route. Returns
  `list(presets = list(<{analysis_type, parameter_hash, state, generated_at, activated_at, stale_after, source_data_version, row_counts}>), summary = list(total, available, missing, stale, mismatch))`.
  `state` ∈ `"missing" | "available" | "stale" | "source_version_mismatch"`.
- `analysis_snapshot_bootstrap_on_startup(submit_refresh_fn = service_analysis_snapshot_submit_refresh, enabled_fn = analysis_snapshot_bootstrap_enabled)`
  — thin startup wrapper that mirrors `pubtatornidd_bootstrap_enrichment()`:
  returns early (no-op) when disabled; otherwise calls the shared submit with
  `force = FALSE`, logs a single
  `[snapshot-bootstrap] N/M presets missing -> submitted N refresh jobs` /
  `[snapshot-bootstrap] all presets present, nothing to do` line. Never throws.
- `analysis_snapshot_bootstrap_enabled()` — reads
  `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP` (default **enabled**); accepts
  `true/1/yes` (case-insensitive). This is the config gate the issue asks for,
  implemented as an env var to match the repo's sidecar/env conventions and
  avoid editing all four `config.yml` blocks.

**A3. Startup hook** — `api/start_sysndd_api.R`

Add a `tryCatch` block immediately after the existing pubtatornidd bootstrap
(section 9b, ~line 151), guarded by the same never-crash-boot pattern:
```r
tryCatch(
  analysis_snapshot_bootstrap_on_startup(),
  error = function(e) message(sprintf("[snapshot-bootstrap] skipped: %s", conditionMessage(e)))
)
```

**A4. DRY the operator script** — `api/scripts/refresh-analysis-snapshots.R`

Replace the inline loop (lines 58-82) with a call to
`service_analysis_snapshot_submit_refresh(force = TRUE)` (the script's contract
is "rebuild them", i.e. force), printing the returned per-preset summary. Keeps
the Make target as the no-HTTP fallback.

**A5. Tests** — `api/tests/testthat/test-unit-analysis-snapshot-bootstrap.R`

Pure-unit, injectable fakes (no DB):
- shared submit skips presets that already exist, submits missing ones, and the
  summary counts are correct;
- `force = TRUE` submits all regardless of existence;
- single `analysis_type` targets just that preset; unknown type raises the
  `analysis_snapshot_unsupported_parameter_error`;
- dedup (`submit_fn` returns `duplicate = TRUE`) is counted as `reused`, not
  `submitted`;
- `analysis_snapshot_bootstrap_enabled()` honors the env var (on/off/default);
- `analysis_snapshot_bootstrap_on_startup()` is a no-op when disabled and never
  throws when the submit fn errors.

### Sprint B — API admin endpoints (new file + mount)

**B1. New endpoint file** — `api/endpoints/admin_analysis_snapshot_endpoints.R`
(new file, because `admin_endpoints.R` is already 1081 lines, over the 600
soft-ceiling — AGENTS.md says don't grow files already over it).

- `#* @post /snapshots/refresh` → full path `/api/admin/analysis/snapshots/refresh`
  - `require_role(req, res, "Administrator")`
  - body/query: optional `analysis_type` (one preset), optional `force` (bool)
  - calls `service_analysis_snapshot_submit_refresh(...)`, returns 202 with the
    structured summary (`results` carry job ids)
  - unknown `analysis_type` ⇒ the service's `unsupported_parameter` error maps to
    400 via the attached RFC 9457 `errorHandler`
- `#* @get /snapshots/status` → `/api/admin/analysis/snapshots/status`
  - `require_role(req, res, "Administrator")`
  - returns `service_analysis_snapshot_status()` (200)

**B2. Mount** — `api/bootstrap/mount_endpoints.R`

Add, **before** the `/api/admin` mount (so the more specific prefix wins, exactly
like `/api/jobs/network_layout` precedes `/api/jobs`):
```r
plumber::pr_mount("/api/admin/analysis", mount_endpoint("endpoints/admin_analysis_snapshot_endpoints.R")) %>%
```
Using `mount_endpoint()` keeps the RFC 9457 error/404 handlers attached (and
keeps the static guard `test-unit-endpoint-error-handler.R` green).

**B3. Tests** — extend the bootstrap test file or add
`test-unit-admin-analysis-snapshot-endpoints.R`: the handlers enforce the
Administrator gate (non-admin → 403) and pass through to the service with the
parsed `analysis_type`/`force`. Auth gate verified with a stub `req`/`res`.

### Sprint C — Frontend resilience (app/, fully independent)

**C1. Error classification** — `app/src/composables/useNetworkData.ts` (and the
phenotype clusters path). Detect the snapshot-preparing problem codes
(`snapshot_missing`, `snapshot_stale`, `source_version_mismatch`) on a 503 and
expose a `preparing` flag / friendly message distinct from a hard error.

**C2. UI state** — `app/src/components/analyses/NetworkVisualization.vue` and
`app/src/components/analyses/AnalysesPhenotypeClusters.vue`: when `preparing`,
render an informational "Analysis is being prepared, check back shortly" panel
with a Retry button instead of the red error card.

**C3. Tests** — vitest unit for the error-classification helper (problem-code →
preparing vs error).

## Data flow

```
fresh deploy
  start_sysndd_api.R: migrations -> mount endpoints
    -> analysis_snapshot_bootstrap_on_startup()        [gated, never throws]
         -> service_analysis_snapshot_submit_refresh(force = FALSE)
              for each preset: normalize -> exists? skip : submit refresh job
    -> pr_run()
  worker claims analysis_snapshot_refresh jobs -> builds + activates snapshots
  public pages: 503 snapshot_missing -> (minutes later) 200 with data

operator (no SSH):
  POST /api/admin/analysis/snapshots/refresh {force?, analysis_type?}
    -> service_analysis_snapshot_submit_refresh(...) -> job ids
  GET  /api/admin/analysis/snapshots/status
    -> service_analysis_snapshot_status() -> per-preset state

operator (SSH fallback, unchanged contract):
  make refresh-analysis-snapshots
    -> refresh-analysis-snapshots.R -> service_analysis_snapshot_submit_refresh(force = TRUE)
```

## Idempotency & safety

- **Startup**: existence check (`force = FALSE`) ⇒ a restart with snapshots
  present enqueues zero jobs. `async_job_service_submit` dedups by `request_hash`
  ⇒ a restart while a bootstrap job is still queued/running reuses it (counted
  `reused`). The whole hook is `tryCatch`-wrapped and gated ⇒ never crashes boot,
  can be disabled.
- **Admin refresh**: same dedup; `force` only changes the existence pre-filter,
  not the dedup (a queued/running job is still reused).
- **Cheap common path**: bootstrap does one `SELECT ... LIMIT 1` per preset (5
  cheap probes), no clustering, no child-table reads.

## Error handling

- Admin routes are wrapped by `mount_endpoint()` ⇒ classed errors map to RFC
  9457 problem+json (`unsupported_parameter` → 400, role gate → 403).
- Service submit isolates per-preset failures (`tryCatch` per preset) so one bad
  preset doesn't abort the rest; failures are counted and reported, not thrown.

## Acceptance criteria (from #420)

- [ ] Fresh `docker compose up --build` with empty `analysis_snapshot_*` tables →
      `/GeneNetworks` and `/PhenotypeClusters` heal automatically within minutes
      (no manual Make target).
- [ ] A restart when snapshots already exist enqueues **zero** new refresh jobs.
- [ ] Behaviour is config/env-gated and logged.
- [ ] `make refresh-analysis-snapshots` remains the manual/forced-rebuild path.
- [ ] `POST /api/admin/analysis/snapshots/refresh` (admin) submits jobs + returns
      ids; non-admin → 401/403.
- [ ] `GET /api/admin/analysis/snapshots/status` reports per-preset state.
- [ ] Script, startup hook, and endpoint all call one shared submit function.
- [ ] Operator can rebuild snapshots with no SSH/docker access.
- [ ] (nice-to-have) public analysis pages show a "being prepared" state on 503
      instead of a raw error.

## Verification

- `make lint-api`, `make test-api-fast` (PR gate), then `make ci-local` before handoff.
- `cd app && npm run lint && npm run type-check && npm run test:unit` for Sprint C.
- New unit tests above. Manual: a curl of the two admin routes against a dev stack.

## Documentation

- `AGENTS.md` → "Background jobs": note snapshots now auto-bootstrap on startup
  (env `ANALYSIS_SNAPSHOT_BOOTSTRAP_ON_STARTUP`), plus the two admin routes and
  the shared submit function.
- `documentation/09-deployment.qmd` → operator note: the new env flag + the admin
  refresh/status routes as the no-SSH rebuild path.
