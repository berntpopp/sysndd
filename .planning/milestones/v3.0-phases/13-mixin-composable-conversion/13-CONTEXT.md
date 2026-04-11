# Phase 13: Mixin → Composable Conversion - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert 7 Vue 2 mixins (colorAndSymbolsMixin, scrollbarMixin, tableDataMixin, tableMethodsMixin, textMixin, toastMixin, urlParsingMixin) to Vue 3 composables. Internal refactoring — users won't see changes, but code organization and developer experience will improve. No new functionality added.

</domain>

<decisions>
## Implementation Decisions

### Composable API design
- Object return pattern: `return { isLoading, data, fetchData }` — components destructure what they need
- Return refs (not reactive objects): `return { count }` where count is a ref — component uses count.value or template auto-unwraps
- Naming convention: `use` prefix with camelCase — colorAndSymbolsMixin → useColorAndSymbols, tableDataMixin → useTableData
- Options object when needed: `useTable({ pageSize: 25 })` — only add options where current mixins have magic numbers or hardcoded values

### State sharing strategy
- Toast notifications: integrate with existing Pinia UI store — useToast() delegates to UI store for single source of truth
- Table composables: per-instance state — each useTableData() call creates fresh state, tables are independent (mirrors current mixin behavior)
- colorAndSymbolsMixin: composable with constants — color/symbol mappings in types/constants.ts, useColorAndSymbols() provides helper functions
- urlParsingMixin: integrate with Vue Router — useUrlParsing() uses useRoute() internally, reactive to route changes

### Conversion order & testing
- Incremental by dependency: convert independent mixins first (text, scrollbar, colorAndSymbols), then dependent ones (table*, urlParsing, toast)
- Replace immediately per mixin: when a composable is done, update all components using that mixin and delete the mixin
- Manual verification: after each conversion, verify build succeeds, affected pages render, key functionality works
- Rollback strategy: git revert to last working commit — each mixin conversion is a separate commit

### Error handling patterns
- Return error state: `return { data, error, isLoading }` — component decides how to display errors
- Let components decide on toasts: composable returns error, component calls useToast() if it wants to show a message
- Loading states: simple `isLoading` ref boolean — component shows spinner when true
- Misuse handling: console warning in development, fail silently in production — developer-friendly but doesn't break production

### Claude's Discretion
- Exact internal implementation details
- TypeScript type definitions (will be added in Phase 14)
- Which specific hardcoded values to make configurable
- Order of independent mixins within conversion waves

</decisions>

<specifics>
## Specific Ideas

- Standard Vue 3 composable patterns — follow VueUse conventions where applicable
- Each converted mixin should have a clean, focused API surface
- Maintain backward compatibility with existing component usage patterns where possible

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-mixin-composable-conversion*
*Context gathered: 2026-01-23*
