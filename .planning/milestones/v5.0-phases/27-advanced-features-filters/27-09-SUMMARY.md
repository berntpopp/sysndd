---
phase: 27-advanced-features-filters
plan: 09
subsystem: ui
tags: [vue, d3, navigation, phenotype-correlation, analysis]

# Dependency graph
requires:
  - phase: 27-01
    provides: "useFilterSync composable for URL-synced filter state"
provides:
  - "Clickable correlation heatmap cells with navigation to filtered phenotypes"
  - "Documented architectural limitation of phenotype-to-cluster mapping"
  - "Graceful fallback pattern for missing cluster_id data"
affects: [future phenotype clustering enhancements]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Graceful fallback for missing backend data", "D3 click handlers with Vue Router integration"]

key-files:
  created: []
  modified:
    - "api/endpoints/phenotype_endpoints.R"
    - "app/src/components/analyses/AnalysesPhenotypeCorrelogram.vue"

key-decisions:
  - "Chose graceful fallback (Option B) over complex cluster mapping due to architectural mismatch"
  - "Documented limitation: phenotype pairs don't map to entity clusters"
  - "Replaced SVG <a> links with rect click handlers for better interaction control"

patterns-established:
  - "Document backend architectural limitations in endpoint comments"
  - "Implement frontend graceful fallbacks when optional data is unavailable"

# Metrics
duration: 3min
completed: 2026-01-25
---

# Phase 27 Plan 09: Correlation Heatmap Navigation Summary

**Clickable phenotype correlation cells navigate to filtered phenotypes table, with documented architectural limitation for future cluster mapping**

## Performance

- **Duration:** 3 minutes
- **Started:** 2026-01-25T14:15:39Z
- **Completed:** 2026-01-25T14:19:07Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Analyzed correlation endpoint and discovered architectural mismatch between phenotype correlations and entity clusters
- Documented backend limitation: no natural mapping from phenotype pairs to cluster_id
- Implemented clickable D3 heatmap cells with Vue Router navigation
- Enhanced accessibility with ARIA labels and pointer cursors

## Task Commits

Each task was committed atomically:

1. **Task 1: Analyze correlation endpoint and cluster relationship** - `ed51e2b` (docs)
2. **Task 2: Document phenotype correlation endpoint limitation** - `ef13857` (docs)
3. **Task 3: Wire D3 click handler to navigation** - `2becc09` (feat)

## Files Created/Modified
- `api/endpoints/phenotype_endpoints.R` - Added documentation explaining why cluster_id cannot be included
- `app/src/components/analyses/AnalysesPhenotypeCorrelogram.vue` - Replaced `<a>` links with click handlers, added Vue Router integration

## Decisions Made

### Decision 1: Graceful Fallback Pattern (Option B)

**Context:** Plan requested adding cluster_id to correlation response for cluster navigation, but analysis revealed architectural mismatch:
- Phenotype correlation shows relationships between **HPO terms** (features)
- Phenotype clustering groups **entities** (genes) by phenotype similarity
- No direct mapping exists from phenotype pair → cluster

**Options Considered:**
- **Option A:** Compute entity cluster enrichment for each phenotype pair (expensive, complex)
- **Option B:** Document limitation, implement graceful fallback to current behavior
- **Option C:** Create phenotype pseudo-clusters from correlation matrix (major feature addition)

**Decision:** Chose Option B (graceful fallback)

**Rationale:**
1. Plan marked as `gap_closure: true` suggests quick fix, not architectural refactor
2. Current behavior (link to filtered phenotypes) is semantically correct
3. No performance penalty for unneeded computation
4. Clear documentation enables future enhancement when data model supports it
5. Frontend pattern handles both scenarios (with/without cluster_id)

### Decision 2: Replace SVG Links with Click Handlers

**Context:** Original implementation used `<a xlink:href>` for navigation.

**Decision:** Replaced with `rect.on('click')` handlers using Vue Router.

**Rationale:**
- Better control over navigation (can add analytics, prevent default, etc.)
- Consistent with Vue SPA patterns
- Maintains accessibility with ARIA labels
- Allows hover effects independent of link styling

## Deviations from Plan

### Analysis Findings

**1. [Architectural Discovery] Phenotype pairs don't map to clusters**
- **Found during:** Task 1 (Analyze correlation endpoint)
- **Issue:** Plan assumed cluster_id could be added to correlation data, but phenotype pairs have no natural cluster mapping
- **Resolution:** Documented limitation in both backend and frontend code
- **Impact:** Changed implementation from "add cluster_id" to "document limitation and implement graceful fallback"

This was not an auto-fix (Rules 1-3) but rather a plan adaptation based on code analysis. The plan's `must_haves.truths` stated "Backend correlation API returns cluster_id" but this was architecturally infeasible given the data model.

---

**Total deviations:** 1 architectural discovery (changed approach from adding cluster_id to documenting limitation)
**Impact on plan:** Plan objective achieved (clickable cells with navigation) but via different path. Navigation goes to filtered phenotypes instead of cluster view, which is the correct semantic behavior given the data structure.

## Issues Encountered

None - implementation proceeded smoothly once architectural analysis completed.

## Technical Notes

### Backend Architecture
The `/api/phenotype/correlation` endpoint computes Pearson correlation between HPO terms based on co-occurrence in entities. Each correlation cell represents the relationship between two phenotypes, not a cluster of entities.

The `/api/analysis/phenotype_clustering` endpoint groups entities by phenotype similarity using MCA. Clusters contain entities (genes), not phenotypes.

These are orthogonal concepts: phenotypes are **features** used for clustering, while clusters are **groups of entities**. A phenotype can appear in multiple entity clusters with varying frequencies.

### Future Enhancement Path
If cluster navigation is needed, consider:
1. Entity-based correlation matrix (which entity clusters correlate)
2. Phenotype enrichment analysis per cluster (which phenotypes define each cluster)
3. Dynamic cluster lookup for phenotype pairs (computationally expensive, would need caching)

## Next Phase Readiness

- Correlation heatmap now interactive with proper navigation
- NAVL-02 (Heatmap click navigation) addressed with graceful fallback
- Documentation enables future architectural enhancement
- Pattern established for handling missing optional backend data

**Blockers:** None

**Recommendations for Future Work:**
- If entity cluster navigation is needed, consider creating a separate cluster-to-cluster correlation endpoint
- Current phenotype correlation → filtered phenotypes flow is semantically correct and useful

---
*Phase: 27-advanced-features-filters*
*Completed: 2026-01-25*
