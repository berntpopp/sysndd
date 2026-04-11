---
phase: 40-backend-external-api-layer
plan: 04
subsystem: api
tags: [plumber, r, external-api, genomics, gnomad, uniprot, ensembl, alphafold, mgi, rgd, error-isolation, rfc-9457]

# Dependency graph
requires:
  - phase: 40-backend-external-api-layer
    provides: "Plans 40-02 and 40-03 - Seven memoised proxy functions with retry/rate limiting"
provides:
  - "8 Plumber endpoints exposing external genomic data: 7 per-source + 1 aggregation"
  - "Error isolation pattern: one failing source never blocks others"
  - "RFC 9457 error responses with source identification"
  - "Public access to external proxy endpoints via AUTH_ALLOWLIST"
affects: [frontend, gene-page, 41-frontend-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Error isolation: tryCatch per source in aggregation endpoint"
    - "Partial success responses: 200 with partial data when some sources fail"
    - "Consistent endpoint pattern: validation → fetch → error handling → success"

key-files:
  created: []
  modified:
    - api/endpoints/external_endpoints.R
    - api/core/middleware.R

key-decisions:
  - "Aggregation endpoint returns 200 with partial data when at least one source succeeds"
  - "All external proxy endpoints public by default (GET requests without auth)"
  - "Source identification in all error responses for frontend error handling"

patterns-established:
  - "Per-source endpoints: /api/external/{source}/{type}/{symbol}"
  - "Aggregation endpoint: /api/external/gene/{symbol} (all sources)"
  - "Error isolation: tryCatch per source prevents cascading failures"
  - "RFC 9457 errors with source field for precise error reporting"

# Metrics
duration: 3min
completed: 2026-01-27
---

# Phase 40 Plan 04: External Proxy Endpoints Summary

**8 Plumber endpoints with error isolation expose all external genomic data (gnomAD, UniProt, Ensembl, AlphaFold, MGI, RGD) with RFC 9457 error responses and public access**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-27T20:15:31Z
- **Completed:** 2026-01-27T20:18:54Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- 7 per-source proxy endpoints expose individual genomic data sources
- 1 aggregation endpoint fetches all sources in parallel with error isolation
- Partial success pattern: returns 200 with available data when some sources fail
- RFC 9457 error responses include source field for frontend identification
- All 8 endpoints added to AUTH_ALLOWLIST for public read access

## Task Commits

Each task was committed atomically:

1. **Task 1: Add per-source proxy endpoints to external_endpoints.R** - `7b94f47` (feat)
2. **Task 2: Add aggregation endpoint and update AUTH_ALLOWLIST** - `23e155b` (feat)

## Files Created/Modified
- `api/endpoints/external_endpoints.R` - Added 8 GET endpoints (7 per-source + 1 aggregation)
- `api/core/middleware.R` - Added 8 paths to AUTH_ALLOWLIST for public access

## Decisions Made

**1. Aggregation endpoint returns 200 with partial data**
- Rationale: Frontend can display available data even if some sources fail
- Pattern: Only returns 503 when ALL sources fail
- Implementation: Filters out `found: false` when checking for successful sources

**2. Error isolation via tryCatch per source**
- Rationale: One failing API should never block other sources
- Pattern: Each source wrapped in tryCatch, errors collected separately
- Result: Robust aggregation that continues despite individual failures

**3. Source identification in all error responses**
- Rationale: Frontend needs to know which specific API failed
- Pattern: RFC 9457 errors include `source` field with API name
- Usage: Enables targeted error messages and retry logic in UI

**4. Public access for all external proxy endpoints**
- Rationale: External genomic data is already public (gnomAD, UniProt, etc.)
- Implementation: Added to AUTH_ALLOWLIST (though GET endpoints already public per middleware line 77)
- Documentation: Explicit listing future-proofs against middleware changes

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for frontend integration:**
- All 8 endpoints tested and verified
- Error responses standardized with RFC 9457 format
- Source identification enables targeted error handling
- Aggregation endpoint provides single-request interface for gene page

**For plan 40-05 (frontend integration):**
- Use `/api/external/gene/{symbol}` as primary endpoint
- Per-source endpoints available for targeted fetches
- Error handling: Check `errors` object for failed sources
- Partial data: `sources` object contains successful fetches

**No blockers or concerns.**

---
*Phase: 40-backend-external-api-layer*
*Completed: 2026-01-27*
