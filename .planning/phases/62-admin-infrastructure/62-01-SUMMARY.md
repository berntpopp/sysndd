---
phase: 62
plan: 01
subsystem: admin-infrastructure
completed: 2026-02-01
duration: ~8 minutes

requires:
  - Phase 55 (Bug Fixes) - stable codebase

provides:
  - Admin-triggered comparisons data refresh via async job
  - Database config tables for source URLs
  - Progress tracking for multi-source downloads

affects:
  - Future external database additions (comparisons_config table)
  - Admin workflows (ManageAnnotations UI)

tech-stack:
  added: []
  patterns:
    - mirai async job pattern for long-running operations
    - Database-backed configuration (editable without code changes)
    - File-based progress reporting for daemon processes

key-files:
  created:
    - db/migrations/007_comparisons_config.sql
    - api/functions/comparisons-functions.R
    - api/functions/comparisons-sources.R
  modified:
    - api/endpoints/jobs_endpoints.R
    - api/endpoints/comparisons_endpoints.R
    - api/functions/job-manager.R
    - app/src/views/admin/ManageAnnotations.vue
    - app/src/views/analyses/CurationComparisons.vue

decisions:
  - id: "62-01-01"
    date: 2026-02-01
    decision: "Store source URLs in database config table"
    rationale: "Admin can edit URLs without code deployment when external sources change"
  - id: "62-01-02"
    date: 2026-02-01
    decision: "Local HGNC symbol lookup only (no API calls in daemon)"
    rationale: "Rate limiting and reliability - use existing non_alt_loci_set table"
  - id: "62-01-03"
    date: 2026-02-01
    decision: "All-or-nothing refresh pattern"
    rationale: "Partial updates would leave inconsistent data state"

metrics:
  lines-added: ~1600
  files-changed: 9
  tests-added: 0
  tests-passing: existing tests pass

tags:
  - admin
  - async-jobs
  - mirai
  - comparisons
  - external-databases
---

# Phase 62 Plan 01: Comparisons Data Refresh Summary

Refactored standalone 639-line R script into async job pattern with admin UI for database comparisons refresh.

## One-liner

Admin-triggered refresh of 7 external NDD database comparisons via mirai async job with progress tracking and all-or-nothing error handling.

## What Was Built

### 1. Database Migration (007_comparisons_config.sql)
- **comparisons_config table**: Stores source URLs and formats for 8 sources
- **comparisons_metadata table**: Tracks last refresh timestamp, status, statistics
- Initial data inserted for: radboudumc, gene2phenotype, panelapp, sfari, geisinger_DBD, orphanet_id, phenotype_hpoa, omim_genemap2

### 2. API Functions
**comparisons-sources.R (157 lines)**:
- `get_active_sources(conn)`: Fetch source config from database
- `update_source_last_updated(conn, source_name)`: Track download timestamps
- `get_comparisons_metadata(conn)`: UI metadata display
- `update_comparisons_metadata(conn, ...)`: Refresh status updates

**comparisons-functions.R (944 lines)**:
- `download_source_data()`: Download with timeout and format handling
- `parse_radboudumc_pdf()`: PDF parsing via pdftools
- `parse_gene2phenotype_csv()`: CSV.gz parsing
- `parse_panelapp_tsv()`: TSV with OMIM/MONDO extraction
- `parse_sfari_csv()`: SFARI autism gene database
- `parse_geisinger_csv()`: Geisinger DBD with inheritance mapping
- `parse_orphanet_json()`: Orphanet ID genes API
- `parse_omim_genemap2()`: OMIM+HPO phenotype filtering
- `standardize_comparison_data()`: Normalize to common schema
- `resolve_hgnc_symbols()`: Local batch HGNC lookup (no API calls)
- `comparisons_update_async()`: Main mirai daemon entry point

### 3. API Endpoints
- **POST /api/jobs/comparisons_update/submit**: Async job submission
- **GET /api/comparisons/metadata**: Last refresh info for UI

### 4. Admin UI (ManageAnnotations.vue)
- Comparisons Data Refresh section with metadata badges
- Refresh button with useAsyncJob progress tracking
- Shows: last refresh date, source count, row count
- Success/failure alerts on completion

### 5. CurationComparisons.vue
- Converted to Composition API with script setup
- Dynamic metadata display in card header
- Shows last-updated date with tooltip details

## Deviations from Plan

None - plan executed exactly as written.

## Key Implementation Details

### Async Job Pattern
```r
# Job endpoint extracts db_config BEFORE mirai (connections can't cross process boundaries)
db_config <- list(
  dbname = dw$dbname, host = dw$host,
  user = dw$user, password = dw$password, port = dw$port
)

result <- create_job(
  operation = "comparisons_update",
  params = list(db_config = db_config),
  timeout_ms = 1800000,  # 30 minutes
  executor_fn = function(params) {
    comparisons_update_async(params)
  }
)
```

### All-or-Nothing Transaction
```r
tryCatch({
  DBI::dbBegin(conn)
  DBI::dbExecute(conn, "DELETE FROM ndd_database_comparison")
  DBI::dbAppendTable(conn, "ndd_database_comparison", merged_data)
  update_comparisons_metadata(conn, "success", ...)
  DBI::dbCommit(conn)
}, error = function(e) {
  DBI::dbRollback(conn)
  stop(e)
})
```

### Local HGNC Resolution
Uses non_alt_loci_set table for symbol lookup (current, prev_symbol, alias_symbol) instead of HGNC API calls to avoid rate limiting in daemon.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 7d1085a1 | Migration 007: comparisons_config and comparisons_metadata tables |
| 2 | 58982c39 | API functions: parsing, standardization, HGNC resolution |
| 3 | 09ee353f | Endpoint and admin UI with progress tracking |

## Verification Checklist

- [x] Migration 007 creates tables with initial data
- [x] POST /api/jobs/comparisons_update/submit returns 202 with job_id
- [x] GET /api/comparisons/metadata returns refresh info
- [x] ManageAnnotations shows Comparisons section with badges
- [x] CurationComparisons shows dynamic last-updated date
- [x] TypeScript type-check passes
- [x] ESLint passes (no new errors)

## Next Phase Readiness

**Phase 62 Plan 02 (if created)**: Documentation migration to Quarto
- No blockers
- Independent of this plan

**Production Notes**:
- First refresh will take 5-30 minutes depending on external source availability
- OMIM source requires valid API key in URL (stored in comparisons_config)
- pdftools package required for Radboudumc PDF parsing

---

*Plan completed: 2026-02-01*
*Total execution time: ~8 minutes*
