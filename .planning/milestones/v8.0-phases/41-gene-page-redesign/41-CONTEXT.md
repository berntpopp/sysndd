# Phase 41: Gene Page Redesign - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Transform the gene detail page from a flat identifier list into a modern, organized layout with hero section, grouped information cards, responsive design, and reusable components. This phase covers the page structure and internal gene data presentation only — external genomic data integration (gnomAD, UniProt, etc.) is handled by other phases.

</domain>

<decisions>
## Implementation Decisions

### Hero section design
- Minimal hero: shows only gene symbol, full gene name, and chromosome band/location
- All identifiers (Entrez, Ensembl, UniProt, etc.) go in cards below, not in the hero
- Hero is display-only — no buttons, copy actions, or interactive elements in the hero area
- Visual presentation (badge vs typography, background treatment): Claude's discretion, informed by web research of best practices for genomic database UIs and consistency with existing SysNDD design system

### Card layout & density
- Identifier card uses label-value row layout: label on left, value + copy button + external link on right
- Cards have subtle drop shadows, no visible borders — modern elevated look
- Grid column count and overall card arrangement: Claude's discretion, researched against best practices and existing SysNDD patterns
- Clinical resource link organization (single card vs individual mini-cards): Claude's discretion, researched against senior UI/UX best practices

### Empty states & edge cases
- Missing identifiers: show the label row with muted gray "Not available" text — row stays visible
- Empty state message tone: clinical/neutral ("Not available", "No data available") — no personality, appropriate for research tool
- Unavailable clinical resource links: show the card/link but grayed out with "No entry" indicator — user sees the full set of possible resources
- Loading state: simple centered spinner, page content appears all at once when ready (not shimmer skeletons)

### External link presentation
- Use generic icons (external link icon, database icon) — no database-specific logos
- External links open in new tab (target=_blank)
- Copy-to-clipboard feedback: brief "Copied!" tooltip appears next to the button for 1-2 seconds, then fades
- Clinical resource links grouped by type: separate groups like "Curation" (ClinGen, SFARI), "Disease" (OMIM, g2p), "Genome" (UCSC, Ensembl) — Claude determines exact grouping categories

### Claude's Discretion
- Hero visual treatment (badge style, background, typography hierarchy) — research best practices, stay consistent with SysNDD
- Grid column count on desktop — research genomic database UIs
- Clinical resource card structure (single card with list vs individual mini-cards)
- Exact resource link grouping categories
- Responsive breakpoints for tablet/mobile
- Loading spinner style (match existing SysNDD patterns)

</decisions>

<specifics>
## Specific Ideas

- User wants design decisions grounded in web research of best practices and community standards for genomic/biomedical database UIs, not arbitrary choices
- Consistency with existing SysNDD codebase design patterns is a priority — investigate current styling before introducing new patterns
- Gene.vue refactor to Composition API with script setup (per REDESIGN-10)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 41-gene-page-redesign*
*Context gathered: 2026-01-27*
