---
phase: 75-frontend-fixes-ux-improvements
plan: 02
subsystem: frontend-tables
tags: [vue, composables, tooltips, ux, tables]
requires:
  - phase-74-api-fixes
provides:
  - column-header-tooltip-composable
  - generic-table-tooltip-support
affects:
  - future-table-components
tech-stack:
  added: []
  patterns:
    - composable-extraction
    - slot-passthrough
decisions:
  - what: Extract tooltip logic into reusable composable
    why: TablesGenes and TablesPhenotypes had inline tooltip code that should be shared
    impact: All tables can now use consistent tooltip behavior
  - what: Add head() slot to GenericTable with column-header passthrough
    why: Allows consumers to override column headers with tooltips or custom rendering
    impact: GenericTable is now more flexible for header customization
key-files:
  created:
    - app/src/composables/useColumnTooltip.ts
  modified:
    - app/src/composables/index.ts
    - app/src/components/small/GenericTable.vue
    - app/src/components/tables/TablesEntities.vue
metrics:
  duration: 2m 10s
  completed: 2026-02-05
---

# Phase 75 Plan 02: Column Header Tooltips Summary

**One-liner:** Extracted tooltip formatting into useColumnTooltip composable and added column header tooltips to TablesEntities showing unique filtered/total values

## What Was Done

### Task 1: Create useColumnTooltip composable (b5b67d21)
- Created new composable `app/src/composables/useColumnTooltip.ts`
- Exported `useColumnTooltip` function and `FieldWithCounts` interface
- Tooltip format: "Label (unique filtered/total values: X/Y)"
- Re-exported from `app/src/composables/index.ts` for centralized imports

### Task 2: Add tooltip support to GenericTable and TablesEntities (fe668e10)
- Added `#head()` slot to GenericTable with `column-header` slot passthrough
- Default fallback renders label text (preserves existing behavior for non-tooltip consumers)
- Updated TablesEntities to import and use `useColumnTooltip` in setup
- Added `column-header` slot with `v-b-tooltip` directive and `getTooltipText` function
- Tooltip uses `truncate` and regex label cleanup from `useText` composable
- Matches TablesGenes existing tooltip pattern exactly

## Technical Details

**Composable pattern:**
- `useColumnTooltip()` returns `{ getTooltipText }` function
- Accepts field object with optional `count` and `count_filtered` properties
- Works with API fspec metadata that includes unique value counts

**GenericTable enhancement:**
- `#head()="data"` captures BTable's head slot data
- `<slot name="column-header" :data="data" :fields="fields">` passes to consumers
- Default content: `{{ data.label }}` preserves current behavior

**TablesEntities implementation:**
```vue
<template #column-header="{ data }">
  <div
    v-b-tooltip.hover.top
    :title="getTooltipText(fields.find((f) => f.label === data.label) || { key: data.column, label: data.label })"
  >
    {{ truncate(data.label.replace(/( word)|( name)/g, ''), 20) }}
  </div>
</template>
```

## Decisions Made

1. **Composable extraction over inline logic**
   - **Decision:** Extract tooltip formatting into reusable composable
   - **Rationale:** TablesGenes and TablesPhenotypes had identical inline logic
   - **Impact:** All tables can use consistent tooltip behavior, easier to maintain

2. **Slot passthrough pattern in GenericTable**
   - **Decision:** Add `#head()` slot with named `column-header` slot
   - **Rationale:** Allows consumers to override column headers without modifying GenericTable
   - **Impact:** GenericTable is now more flexible for header customization

3. **Preserved label cleanup regex**
   - **Decision:** Keep `/( word)|( name)/g` regex from TablesGenes
   - **Rationale:** Removes " word" and " name" suffixes for cleaner mobile display
   - **Impact:** Consistent label truncation across tables

## Testing Evidence

**ESLint validation:**
```bash
✓ app/src/composables/useColumnTooltip.ts - passed
✓ app/src/components/small/GenericTable.vue - passed
✓ app/src/components/tables/TablesEntities.vue - passed
```

**Verification checks:**
- ✓ useColumnTooltip.ts exists and exports useColumnTooltip
- ✓ Composable re-exported from composables/index.ts
- ✓ GenericTable has #head() slot with column-header passthrough
- ✓ TablesEntities uses column-header slot with v-b-tooltip

## Deviations from Plan

None - plan executed exactly as written.

## Next Phase Readiness

**Ready for:** Future table component enhancements

**Provides:**
- Reusable tooltip composable for all table components
- Generic head slot override pattern for custom headers

**Notes:**
- TablesGenes and TablesPhenotypes can optionally migrate to use the composable in future refactoring
- Pattern established for other header customizations (filters, sorting indicators, etc.)

## Commits

| Commit | Task | Files Modified |
|--------|------|----------------|
| b5b67d21 | Task 1: Create useColumnTooltip composable | useColumnTooltip.ts, composables/index.ts |
| fe668e10 | Task 2: Add tooltip support to GenericTable and TablesEntities | GenericTable.vue, TablesEntities.vue |
