# Phase 75: Frontend Fixes & UX Improvements - Context

**Gathered:** 2026-02-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix 4 independent frontend issues: restore column header tooltips across data tables, replace basic phenotype/variation selectors with TreeMultiSelect in Create Entity step 3, reorder gene detail page sections, and centralize documentation URLs. The doc link URLs were already fixed in commit 03b2c7ea — this phase extracts them into a constants file for maintainability.

</domain>

<decisions>
## Implementation Decisions

### Phenotype & Variation Selector (UX-01)
- Replace `BFormSelect` with the **exact same `TreeMultiSelect` component** used in ModifyEntity for BOTH phenotype and variation ontology in Create Entity step 3
- Use the same `transformModifierTree()` transformation — hierarchy with phenotype/variation name as parent, modifiers (present, uncertain, variable, etc.) as selectable children
- Use **compound `modifier_id-ontology_id` format** (e.g., `"1-HP:0001999"`, `"2-VARIO:0000198"`) matching ModifyEntity — modifiers are essential for proper data capture
- **Verify thoroughly** that the entity creation API supports the compound modifier-ID format on submission
- Remove the custom badge display — use **TreeMultiSelect's built-in chips only** for showing selections
- Both phenotype and variation ontology get the identical upgrade — same component, same data flow

### Column Header Tooltips (FE-02)
- Add column header tooltips to: **Entities, Genes (already has them), Phenotypes, and Comparisons tables**
- Keep the **existing tooltip format**: `"Column (unique filtered/total values: X/Y)"`
- **Extract into a shared composable** (e.g., `useColumnTooltip()`) so all tables use the same code — DRY approach
- **Enhance GenericTable component** to support tooltips natively — tables using GenericTable get tooltips automatically when field specs include count data
- Backend already computes `count` and `count_filtered` via `generate_tibble_fspec()` for all tables — frontend just needs to consume it

### Gene Page Section Ordering (UX-02)
- New order (top to bottom):
  1. Gene Info Card (symbol, name, location, resources, identifiers) — unchanged
  2. **Associated Entities** (moved up from last position) — full-width
  3. Constraint Scores + ClinVar + Model Organisms (two-column layout) — unchanged internally
  4. Genomic Visualization Tabs (protein view, gene structure, 3D structure) — stays last
- Associated Entities remains **full-width** layout — table needs the space

### Documentation URL Centralization (FE-01)
- Issue #162 already fixed in commit 03b2c7ea (URLs updated to numbered prefixes)
- **Create a constants file** (`src/constants/docs.ts`) as single source of truth for all documentation URLs
- Update all 4 files that reference doc URLs to import from the constants file:
  - `HomeView.vue`
  - `ReviewInstructions.vue`
  - `DocumentationView.vue`
  - `HelperBadge.vue`
- Close issue #162 — the actual bug is resolved

### Claude's Discretion
- Exact composable API design for `useColumnTooltip()`
- How to pass tooltip support flag through GenericTable props
- Internal refactoring of StepPhenotypeVariation.vue component structure
- Constants file naming and export patterns

</decisions>

<specifics>
## Specific Ideas

- Phenotype/variation selector should behave identically to ModifyEntity — same search, hierarchy navigation, and multi-select behavior
- The API endpoint for tree data is `/api/list/phenotype?tree=true` and `/api/list/variation_ontology?tree=true`
- GenericTable already receives field specs with count data — tooltip enhancement should be opt-in via props
- TablesGenes.vue has the reference implementation for tooltips (lines 76-101)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 75-frontend-fixes-ux-improvements*
*Context gathered: 2026-02-05*
