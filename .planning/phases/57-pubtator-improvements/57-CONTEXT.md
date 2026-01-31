# Phase 57: Pubtator Improvements - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Enhance Pubtator integration for curators and researchers: fix broken Stats page, add gene prioritization with coverage gap detection, novel gene alerts, export functionality, and explanatory documentation. Also add missing admin infrastructure for Pubtator data management (update trigger, basic stats, configurable query).

</domain>

<decisions>
## Implementation Decisions

### Update Management
- Manual update only (no scheduled automation) — admin triggers via button
- Admin controls in existing ManageAnnotations page (new tab alongside HGNC, Ontology)
- Basic stats only: last update time, total publications cached, total genes linked
- Search query admin-configurable (stored in database/config, not hardcoded)

### Prioritization Criteria
- Primary ranking: Coverage gap first (genes NOT in SysNDD), then recency
- Recency measured by oldest publication date (long-overlooked genes prioritized)
- Two-tier display: Non-SysNDD genes first (sorted by oldest pub date), then SysNDD genes (sorted by oldest pub date)

### Novel Gene Alerts
- Display style: Badge/highlight in gene list (not separate section or tab)
- Novel threshold: Minimum 2+ publications (filters noise from single mentions)
- Filtering: Both publication count filter (2+, 5+, 10+) AND date range filter (last 1/2/5 years)
- Visibility: Badge on Genes tab showing count ("Genes (47 novel)") AND stat card in Stats view

### Gene List UI
- PMIDs shown as clickable chips in gene row
- Expandable details with subtable showing publication information

### Export Format
- Excel (.xlsx) format only
- Exports current filtered view (respects active filters)
- Columns: Gene symbol, publication count, oldest publication date, in-SysNDD status, PMIDs (comma-separated in one cell)

### Documentation
- Follow CurationComparisons pattern: header text + help badge with popover
- Popover content explains both what Pubtator is AND how to use the prioritization/filtering features

### Claude's Discretion
- Exact badge styling and colors for novel gene highlights
- Chip component implementation details
- Subtable column layout for expanded publication details
- Admin panel layout within ManageAnnotations
- Query configuration storage mechanism (database table vs config file)

</decisions>

<specifics>
## Specific Ideas

- "Like CurationComparisons/Table" — follow that pattern for header explanatory text + help popover
- Coverage gap = genes in Pubtator but NOT in SysNDD entities
- "Oldest publication" for prioritization = find long-overlooked genes that should have been added years ago
- Filters let curators slice the data: "show me genes with 5+ publications from the last 2 years that we haven't added yet"

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 57-pubtator-improvements*
*Context gathered: 2026-01-31*
