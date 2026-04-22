---
phase: 40-backend-external-api-layer
plan: 03
subsystem: api
tags: [r, plumber, alphafold, mgi, rgd, memoise, cachem, httr2, external-api]

# Dependency graph
requires:
  - phase: 40-01
    provides: Shared external API proxy infrastructure (make_external_request, cache backends, rate limiting)
provides:
  - AlphaFold structure metadata proxy with UniProt accession lookup
  - MGI mouse phenotype data proxy with defensive error handling
  - RGD rat phenotype data proxy with human-to-rat ortholog lookup
  - All three sources memoised with per-source TTL (30d static, 14d stable)
  - API startup registration for all three proxy functions
affects:
  - 45-3d-protein-structure-viewer (will use AlphaFold structure URLs)
  - 46-model-organism-phenotypes (will use MGI/RGD phenotype data)

# Tech tracking
tech-stack:
  added: []  # No new libraries, uses httr2/memoise/cachem from 40-01
  patterns:
    - Two-step API lookup pattern (UniProt accession → AlphaFold structure)
    - Defensive error handling for undocumented APIs (MGI, RGD)
    - Per-source cache TTL strategy (static 30d, stable 14d)

key-files:
  created:
    - api/functions/external-proxy-alphafold.R
    - api/functions/external-proxy-mgi.R
    - api/functions/external-proxy-rgd.R
  modified:
    - api/start_sysndd_api.R

key-decisions:
  - "AlphaFold requires two-step lookup: UniProt search for accession, then AlphaFold API for structure"
  - "MGI and RGD APIs are undocumented: implement defensive parsing that returns not-found rather than crashing"
  - "AlphaFold uses cache_static (30d TTL) - structure predictions rarely change"
  - "MGI and RGD use cache_stable (14d TTL) - phenotype annotations moderately frequent"

patterns-established:
  - "Two-step lookup pattern: External service A (UniProt) provides ID, external service B (AlphaFold) provides data"
  - "Defensive API parsing: Check for null/unexpected formats, return structured not-found response rather than error"
  - "Multiple fallback attempts for undocumented APIs: Try primary endpoint, fallback to alternate endpoint"

# Metrics
duration: 3min
completed: 2026-01-27
---

# Phase 40 Plan 03: External API Proxy - AlphaFold, MGI, RGD Summary

**AlphaFold 3D structure proxy with UniProt lookup, MGI/RGD phenotype proxies with defensive error handling for undocumented APIs**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-27T20:08:05Z
- **Completed:** 2026-01-27T20:10:46Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- AlphaFold proxy: Two-step lookup (UniProt accession search → structure metadata) returning PDB/CIF/BCIF URLs
- MGI proxy: Mouse phenotype data with defensive parsing for undocumented MGI API endpoints
- RGD proxy: Rat phenotype data with human-to-rat ortholog lookup and defensive parsing
- All three sources registered in API startup with memoised wrappers using appropriate TTL

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AlphaFold and MGI proxy functions** - `8b0b2e6` (feat)
2. **Task 2: Create RGD proxy and register all three sources** - `8f99d4c` (feat)

## Files Created/Modified

### Created
- `api/functions/external-proxy-alphafold.R` - AlphaFold structure metadata proxy with UniProt accession lookup (fetch_alphafold_structure + memoised wrapper)
- `api/functions/external-proxy-mgi.R` - MGI mouse phenotype proxy with defensive error handling (fetch_mgi_phenotypes + memoised wrapper)
- `api/functions/external-proxy-rgd.R` - RGD rat phenotype proxy with human-to-rat ortholog lookup (fetch_rgd_phenotypes + memoised wrapper)

### Modified
- `api/start_sysndd_api.R` - Added source lines for all three proxy function files (lines 130-132)

## Decisions Made

**1. AlphaFold two-step lookup pattern**
- **Decision:** Query UniProt first for canonical accession, then AlphaFold API for structure
- **Rationale:** AlphaFold API requires UniProt accession as input; gene symbols not directly supported
- **Implementation:** Step 1 uses UniProt REST search with gene_exact filter + organism_id:9606 + reviewed:true; Step 2 uses accession to query AlphaFold prediction endpoint

**2. Defensive error handling for MGI/RGD**
- **Decision:** Return structured not-found responses rather than crashing on unexpected API formats
- **Rationale:** MGI and RGD APIs are not well documented; response structures vary by endpoint
- **Implementation:** Multiple null checks, fallback attempts to alternate endpoints, return `list(found = FALSE, source = "mgi/rgd", message = "API returned unexpected format")` on parse failure

**3. Per-source cache TTL strategy**
- **Decision:** AlphaFold uses cache_static (30d TTL), MGI/RGD use cache_stable (14d TTL)
- **Rationale:** AlphaFold structure predictions are static (rarely updated); phenotype annotations change moderately as research progresses
- **Implementation:** Memoised wrappers use appropriate cache backend from 40-01 shared infrastructure

**4. Parallel execution with plan 40-02**
- **Decision:** Add source lines for AlphaFold/MGI/RGD after external-proxy-functions.R; expect potential merge with 40-02's gnomAD/UniProt/Ensembl source lines
- **Rationale:** Both plans modify start_sysndd_api.R independently; adding lines sequentially minimizes merge conflicts
- **Implementation:** Placed source lines at lines 130-132 immediately after external-proxy-functions.R (line 129)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all three proxy implementations completed without blocking issues.

## User Setup Required

None - no external service configuration required. All three APIs (UniProt, AlphaFold, MGI, RGD) are public REST endpoints with no authentication.

## Next Phase Readiness

**Ready for:**
- Phase 45 (3D Protein Structure Viewer): AlphaFold proxy provides structure URLs (PDB/CIF/BCIF) and PAE image URL
- Phase 46 (Model Organism Phenotypes): MGI and RGD proxies provide phenotype data for mouse and rat orthologs

**Dependencies satisfied:**
- All three proxy functions use shared infrastructure from 40-01 (make_external_request, cache backends, validate_gene_symbol)
- Memoised wrappers registered in API startup for server-side caching

**No blockers or concerns.**

---
*Phase: 40-backend-external-api-layer*
*Completed: 2026-01-27*
