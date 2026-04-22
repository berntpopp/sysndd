# Phase 27: Advanced Features & Filters - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish competitive differentiators through wildcard gene search, comprehensive filters, bidirectional network-table navigation, and UI polish. This phase adds interactive features to the network visualization built in Phase 26, enabling users to search, filter, and navigate between views with state preserved in URLs.

</domain>

<decisions>
## Implementation Decisions

### Search Behavior
- Search-as-you-type with debounce (~300ms delay)
- Matching nodes glow/pulse in network, non-matches fade to gray
- No-results: subtle message below search ("No genes match 'XYZ*'"), network stays visible
- Single pattern only (no comma-separated multi-pattern support)
- Wildcard syntax: * for multiple characters, ? for single character (biologist-familiar)

### Filter UX
- Inline filters in column headers (filter input/dropdown in each column header row)
- Active filter indicators: colored column header + count badge ("3 filters active")
- FDR numeric filter: preset thresholds dropdown (< 0.01, < 0.05, < 0.1, Custom)
- Clear all filters: reset to defaults, stay on current page, URL updates

### Network-Table Linking
- Click node in network: navigate to entity detail page (existing behavior preserved)
- Click cluster in correlation heatmap: filter network + table to cluster members (zoom to cluster)
- Bidirectional hover highlighting: hover table row → node glows; hover node → row highlights
- Click table row: same as node click — navigate to entity detail page (consistent behavior)

### Navigation Structure
- Horizontal tabs at top: Phenotype Clusters | Gene Networks | Correlation
- Shared filter state: gene search and filters apply across all analysis views
- URL format: query parameters (/analysis?tab=networks&search=PKD*&fdr=0.05)
- Share/URL approach: follow existing pattern from Entities table (http://localhost:5173/Entities) for visual consistency

### Claude's Discretion
- Exact debounce timing (around 300ms)
- Highlight/glow animation style for matching nodes
- Specific color for filtered column headers
- Transition animations between tab views
- Exact tab order and naming

</decisions>

<specifics>
## Specific Ideas

- Look at existing Entities table (http://localhost:5173/Entities) for URL/sharing pattern to maintain visual consistency
- Wildcard syntax should match biologist mental models (PKD*, BRCA?)
- Filter + network state must be bookmarkable/shareable via URL

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 27-advanced-features-filters*
*Context gathered: 2026-01-25*
