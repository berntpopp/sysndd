# Phase 42: Constraint Scores & Variant Summaries - Context

**Gathered:** 2026-01-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Display gnomAD constraint metrics (pLI, LOEUF, missense Z) and ClinVar variant pathogenicity summaries as visual cards on the gene page. Users can immediately assess gene constraint and variant burden. The composable fetches data via the combined endpoint from Phase 40. Creating variant-level views (lollipop plot, filtering) belongs in Phase 43.

</domain>

<decisions>
## Implementation Decisions

### Score presentation style
- Bootstrap card wrapping a gnomAD-style constraint table inside (card-with-table pattern)
- Table columns: Category | Expected SNVs | Observed SNVs | Constraint metrics (matching gnomAD layout)
- Rows: Synonymous, Missense, pLoF — each showing Z-score and o/e ratio with confidence interval
- pLI stays embedded in the pLoF table row (no headline/prominent display) — same as gnomAD
- Small horizontal o/e confidence interval bars rendered with pure CSS/SVG (no D3.js dependency)
- LOEUF upper bound highlighted in yellow/amber when < 0.6 (gnomAD v4 guideline for "highly constrained")
- No interpretation text alongside scores — researchers interpret values themselves
- No transcript reference note — keep card clean
- Card header links to gnomAD gene page (external link icon)

### ClinVar summary layout
- Row of colored count badges for each ACMG pathogenicity class
- Full 5-class ACMG breakdown: Pathogenic (red), Likely Pathogenic (orange), VUS (yellow), Likely Benign (light green), Benign (green)
- Each badge shows ACMG color + classification text + count (e.g., red badge reading "Pathogenic (15)") for accessibility
- Card header shows total variant count: "ClinVar Variants (N)" with external link to ClinVar gene page
- No ClinVar review star rating in summary card
- ClinVar data fetched via gnomAD GraphQL API (not NCBI directly) — per CLINVAR-03 requirement

### Loading & error states
- Cards load independently — ClinVar card can show data while constraint card is still loading/failed, and vice versa
- Loading state: card frame renders immediately with centered spinner inside
- Error state: card stays visible with inline muted error message ("Constraint data unavailable — gnomAD API error") plus retry button
- No-data state (e.g., non-coding gene): card stays visible with info message ("No constraint data available for this gene")

### Claude's Discretion
- Exact spinner component and animation style
- Card border, shadow, and spacing within the gene page grid
- Error message wording and retry button styling
- Composable internal structure (useGeneExternalData)
- Aria-label text for screen reader accessibility on gauges and badges

</decisions>

<specifics>
## Specific Ideas

- Constraint table should match gnomAD's layout closely: reviewed gnomAD gene page (ABCA4) as reference — table with Category/Expected/Observed/Metrics columns, small horizontal bar for o/e CI
- kidney-genetics-db project (`../kidney-genetics-db`) has existing gnomAD GraphQL integration and Vue constraint display component — use as implementation reference
- kidney-genetics-db gnomAD query structure includes: exp_lof, obs_lof, oe_lof, oe_lof_lower, oe_lof_upper, exp_mis, obs_mis, oe_mis, oe_mis_lower, oe_mis_upper, exp_syn, obs_syn, oe_syn, oe_syn_lower, oe_syn_upper, lof_z, mis_z, syn_z, pLI, flags

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 42-constraint-scores-variant-summaries*
*Context gathered: 2026-01-27*
