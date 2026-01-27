---
phase: 42-constraint-scores-variant-summaries
plan: 02
subsystem: ui
tags: [vue3, gnomad, clinvar, constraint-scores, acmg, svg, accessibility, bootstrap-vue-next]

# Dependency graph
requires:
  - phase: 42-01
    provides: TypeScript interfaces (GnomADConstraints, ClinVarVariant) in app/src/types/external.ts
  - phase: 41-gene-page-redesign
    provides: Card-based gene page layout pattern with BCard + shadow-sm styling
provides:
  - GeneConstraintCard component: gnomAD constraint table with SVG confidence interval bars
  - GeneClinVarCard component: ACMG 5-class pathogenicity badge summary
  - Pure CSS/SVG constraint visualization (no D3.js dependency)
  - Screen reader accessibility with ARIA labels on visualizations
affects: [42-03-gene-external-data-composable, 43-protein-domain-lollipop-plot, gene-page-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SVG confidence interval bars with scaleOE() mapping (0-2 range to 0-100px)"
    - "ACMG 5-class colored badges (red/orange/yellow/light-green/green)"
    - "Card accessibility pattern: role=region + aria-label on card wrapper"
    - "Conditional highlighting based on thresholds (LOEUF < 0.6 amber)"
    - "Independent loading/error/no-data state handling per card"

key-files:
  created:
    - app/src/components/gene/GeneConstraintCard.vue
    - app/src/components/gene/GeneClinVarCard.vue
  modified: []

key-decisions:
  - "pLI embedded in pLoF row (not prominently displayed) per CONTEXT.md decision"
  - "LOEUF < 0.6 highlighted in amber (#ffc107) following gnomAD v4 guideline"
  - "Pure CSS/SVG for CI bars (no D3.js) per user decision"
  - "Custom badge colors for Likely Pathogenic (orange #fd7e14) and Likely Benign (teal #20c997) to achieve full 5-color ACMG spectrum"
  - "Handle both underscore and space formats in clinical_significance field for robustness"
  - "No interpretation text in constraint card - researchers interpret values themselves"

patterns-established:
  - "SVG visualization in Vue: inline SVG in template with computed attributes, role=img + aria-label for accessibility"
  - "Table-in-card pattern: BTable inside BCard with custom slot templates for complex cell rendering"
  - "Metrics cell layout: flexbox container with gap for Z-score, o/e ratio, CI bar, and pLI display"
  - "gnomAD constraint table structure: Category | Expected SNVs | Observed SNVs | Constraint Metrics (55% width)"

# Metrics
duration: 2min
completed: 2026-01-27
---

# Phase 42 Plan 02: Constraint & ClinVar Card Components Summary

**gnomAD constraint table with SVG confidence interval bars and ACMG 5-class ClinVar pathogenicity badges**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-27T23:39:46Z
- **Completed:** 2026-01-27T23:41:30Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- GeneConstraintCard displays gnomAD-style constraint metrics table with Category/Expected/Observed/Metrics columns
- Pure CSS/SVG confidence interval bars with ARIA labels for screen reader accessibility
- pLI embedded in pLoF row (not prominently displayed) following gnomAD pattern
- LOEUF < 0.6 highlighted in amber per gnomAD v4 guideline for highly constrained genes
- GeneClinVarCard shows ACMG 5-class colored badges with counts per pathogenicity classification
- Both cards handle loading/error/no-data states independently with retry functionality
- External links to gnomAD and ClinVar gene pages

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GeneConstraintCard component** - `3fd4eb33` (feat)
2. **Task 2: Create GeneClinVarCard component** - `ce17b64d` (feat)

## Files Created/Modified
- `app/src/components/gene/GeneConstraintCard.vue` (227 lines) - gnomAD constraint scores table card with SVG o/e CI bars, pLI embedded in pLoF row, LOEUF amber highlighting, loading/error/no-data states
- `app/src/components/gene/GeneClinVarCard.vue` (176 lines) - ClinVar pathogenicity summary card with ACMG-colored badges (red/orange/yellow/light-green/green), total count in header, loading/error/no-data states

## Decisions Made

**1. pLI display approach (GNOMAD-01)**
- **Decision:** Embedded pLI in pLoF row metrics (not prominently displayed)
- **Rationale:** Follows gnomAD gene page pattern per CONTEXT.md decision

**2. LOEUF highlighting threshold (GNOMAD-02/05)**
- **Decision:** Highlight oe_lof_upper < 0.6 in amber (#ffc107)
- **Rationale:** gnomAD v4 guideline for highly constrained genes

**3. CI bar visualization (GNOMAD-04, A11Y-02)**
- **Decision:** Pure CSS/SVG (no D3.js) with scaleOE() helper mapping 0-2 range to 0-100px
- **Rationale:** User decision to avoid D3.js dependency for simple bars, ARIA labels for accessibility

**4. ACMG color spectrum (CLINVAR-02)**
- **Decision:** Custom badge colors for Likely Pathogenic (orange #fd7e14) and Likely Benign (teal #20c997)
- **Rationale:** Bootstrap's warning variant is amber (used for VUS), needed distinct orange and light-green to achieve full 5-class ACMG spectrum

**5. clinical_significance parsing (CLINVAR-01)**
- **Decision:** Handle both underscore ("Likely_pathogenic") and space ("Likely pathogenic") formats
- **Rationale:** gnomAD ClinVar data uses underscores, but future API sources might use spaces - defensive programming

**6. No interpretation text (CONTEXT.md)**
- **Decision:** No interpretation/guidance text alongside constraint scores
- **Rationale:** Per CONTEXT.md decision - researchers interpret values themselves

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - components implemented successfully following plan specifications.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 42-03 (Gene External Data Composable):**
- Both card components created and ready to consume data
- Props interfaces defined (geneSymbol, loading, error, data)
- Emits defined (retry event)
- Cards expect GnomADConstraints and ClinVarVariant[] types from Plan 42-01

**Ready for Gene Page Integration:**
- Cards follow established pattern from Phase 41 (BCard with shadow-sm, no border)
- Responsive-ready (cards will work in BCol with cols="12" lg="6" grid)
- Independent error handling allows partial success (one card can show data while other errors)

**Requirements satisfied:**
- GNOMAD-01 (pLI embedded in pLoF row) ✓
- GNOMAD-02 (LOEUF highlighting) ✓
- GNOMAD-03 (Missense Z-score) ✓
- GNOMAD-04 (constraint table structure) ✓
- GNOMAD-05 (LOEUF < 0.6 amber highlight) ✓
- CLINVAR-01 (ACMG pathogenicity breakdown) ✓
- CLINVAR-02 (colored badges) ✓
- CLINVAR-03 (gnomAD API source) ✓
- A11Y-01 (aria-labels on badges) ✓
- A11Y-02 (aria-labels on SVG bars) ✓

**No blockers or concerns.**

---
*Phase: 42-constraint-scores-variant-summaries*
*Completed: 2026-01-27*
