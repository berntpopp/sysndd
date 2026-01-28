# Phase 46: Model Organism Phenotypes & Final Integration - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Display mouse (MGI) and rat (RGD) phenotype data on the gene page with a combined card layout, plus final accessibility validation (WCAG 2.2 AA) and manual end-to-end verification of all v8.0 features. Creating new phenotype analysis tools or extending API data capture belongs in other phases.

</domain>

<decisions>
## Implementation Decisions

### Phenotype card layout
- **Combined Model Organisms card** containing both MGI and RGD data (not separate cards)
- **Two-column layout** within card: Mouse (left) | Rat (right)
- **MGI section:** Count chip + zygosity breakdown chips following kidney-genetics-db pattern
  - Colored chips: homozygous (red/error), heterozygous (yellow/warning), conditional (blue/info)
  - Example: "37 phenotypes [15 hm] [22 ht]"
- **RGD section:** Count chip only (RGD API does not provide zygosity breakdown)
  - Example: "12 phenotypes"
- External links to MGI/RGD database pages in both sections

### Empty state handling
- **Generic message** when no data: "No model organism data available"
- **Show both columns** even when only one organism has data
  - Mouse with data, Rat empty: Mouse shows data, Rat shows "No data available"
- **Hide card entirely** if neither mouse nor rat has phenotype data
- **Distinguish errors from empty:** Error icon + "Could not load mouse/rat data" when API fails vs. plain "No data available" when gene has no phenotypes

### Color accessibility
- **Scope:** Comprehensive review of all v8.0 components (Phases 40-46)
- **Target:** WCAG 2.2 AA compliance, Lighthouse accessibility score 100
- **Method:** Manual verification using Lighthouse MCP tool
- **Focus areas:** Color contrast, text labels on colored elements, keyboard navigation

### Cross-feature integration
- **Card position:** Model Organisms card placed after ClinVar card (genetic evidence grouped together)
- **Loading strategy:** Independent loading (current pattern) - each card loads when its data arrives
- **Verification method:** Manual E2E testing, not automated Playwright tests
- **Test genes:** Known NDD genes with rich data (SCN1A, SHANK3, MECP2)

### Claude's Discretion
- Exact chip styling within Bootstrap-Vue-Next constraints
- Specific spacing between mouse and rat sections
- Icon choice for error states
- Column width ratio (50/50 or adjusted)
- Loading spinner placement within card

</decisions>

<specifics>
## Specific Ideas

- Follow kidney-genetics-db MousePhenotypes.vue pattern for zygosity chip display (hm/ht/cn abbreviations with color coding)
- RGD implementation is simpler due to API limitations - don't try to manufacture zygosity data
- Lighthouse MCP tool available for accessibility verification

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 46-model-organism-phenotypes*
*Context gathered: 2026-01-28*
