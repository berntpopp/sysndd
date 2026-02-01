# Phase 56: Variant Correlations & Publications - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix navigation links in VariantCorrelations and VariantCounts views, and improve Publications view to match Entities table patterns. This phase does not add new publication features — it brings existing functionality to parity with established table patterns.

</domain>

<decisions>
## Implementation Decisions

### Variant Navigation Fixes
- VCOR-01: VariantCorrelations view navigation links route to correct destinations
- VCOR-02: VariantCounts view navigation links route to correct destinations
- These are bug fixes — investigate and fix broken navigation

### Publications Table UX (PUB-01)
- Match Entities table patterns exactly (DRY, KISS, SOLID, modularization)
- Traditional pagination with page numbers and items per page selector (10/25/50/100)
- Global search box + per-column filters (both available)
- All visible columns searchable/filterable
- Compact row density
- Dropdown filters for categorical columns where applicable
- Clickable links: PMID → external PubMed (https://pubmed.ncbi.nlm.nih.gov/{pmid})
- Row click → expandable detail view (Show button pattern from Entities)
- Add "Details" column with Show button matching Entities table
- Column sorting via clickable headers
- Export (.xlsx) and copy link features (already present)

### Publication Metadata Display (PUB-02)
- Expandable row detail view (matching Entities table "Show" button pattern)
- Core fields displayed: Title, authors, journal, year, abstract
- Abstract handling: truncated (~200 chars) with "Read more" to expand full text
- Hybrid data fetching strategy:
  - Primary: fetch from database cache
  - Fallback: fetch from PubMed API if missing
  - Background job to refresh/populate cache periodically

### TimePlot Improvements (PUB-03)
- Visual polish: better colors, smoother lines, improved tooltips, responsive sizing
- Interactivity features (all):
  - Date range selection (brush/slider)
  - Click point/bar to filter Publications table to that period
  - Zoom (mouse wheel) and pan (drag)
- Time aggregation options: year, month, quarter (user selectable)
- Cumulative view: toggle between count-per-period and cumulative total
- Match styling with other D3 charts in the application

### Stats View Layout (PUB-04)
- Visual consistency with other charts and tables in the app
- Add metrics cards with trend data:
  - Publications this year
  - Growth rate (vs previous year)
  - Newest publication date
- Card layout: match existing stats/analysis page patterns
- Existing bar charts (journal/author/keyword) remain with visual polish

### Claude's Discretion
- Exact implementation of zoom/pan library (D3 zoom vs custom)
- Specific color palette for improved charts (following existing app colors)
- Loading states and error handling patterns
- Responsive breakpoints for chart sizing

</decisions>

<specifics>
## Specific Ideas

- "Match full functionality and layout of Entities table" — reference: http://localhost:5173/Entities
- PMID links open in new tab to PubMed external site
- Row expansion reveals detail panel inline (not modal or side panel)
- Follow existing composable patterns for table functionality

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 56-variant-correlations-publications*
*Context gathered: 2026-01-31*
