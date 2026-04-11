# Phase 25: Performance Optimization - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Backend infrastructure optimization for clustering performance — 50-65% cold start reduction (15s to 5-7s) through Leiden algorithm, cache versioning, pagination, and timeout handling. Users experience faster load times but don't interact directly with these backend changes.

</domain>

<decisions>
## Implementation Decisions

### Pagination & Filtering

- All clusters must be loaded (for visualization), but table data uses cursor-based pagination
- Follow Entities pattern: `pageAfter` cursor + `pageSize` parameters
- Default page size: 10 rows (matching Entities consistency)
- URL state persistence: page position, filters, search, sort — all shareable/bookmarkable
- Server-side global search across all cluster columns
- Server-side sorting with column header clicks
- Default sort order: by significance (p-value), most significant first
- URL sync uses 500ms debounce to avoid excessive history entries
- Empty filter state: simple message ("No clusters match your filters") with clear filters button

### Timeout & Error Handling

- Timeout shows error immediately with "Try again" button — no automatic retries
- Error message tone: technical/professional (e.g., "Clustering operation timed out after 30s")
- All-or-nothing results — no partial results on failure
- Worker pool exhaustion: show queue position ("Your request is queued. Position: 3")

### Progress Feedback

- Simple spinner without text — minimal, matching existing pattern
- Spinner appears in content area (not full page overlay) — consistent with AnalysesPhenotypeClusters.vue
- Always show spinner even for fast cache loads — consistent UX

### Cache Behavior

- No user indication of cached vs fresh results — transparent
- No user option to force refresh — cache is invisible to users
- Auto-invalidate when underlying data changes (cache keys include data version)
- Silent recompute on cache miss (corrupted, expired, version mismatch) — no notification

### Claude's Discretion

- Exact spinner component styling
- Cache key composition details (algorithm name, STRING version, data hash)
- Worker pool sizing decisions
- Specific timeout duration values
- Pagination cursor implementation details

</decisions>

<specifics>
## Specific Ideas

- "Like Entities page" — server-side pagination, filtering, search, URL state sync
- Technical error messages for scientific audience — precise, professional
- Queue position visibility when server is busy — transparent about wait times

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-performance-optimization*
*Context gathered: 2026-01-24*
