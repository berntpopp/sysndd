# Phase 11: Bootstrap-Vue-Next Migration - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate all UI components from Bootstrap-Vue (Vue 2) to Bootstrap-Vue-Next (Vue 3) with Bootstrap 5 styling. Update all CSS classes, third-party libraries, and resolve security vulnerabilities. Creating new features or changing functionality is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Modal/Toast patterns
- Use `useModal()` composable pattern — modern Vue 3 standard for Bootstrap-Vue-Next
- Programmatic modal creation with `create()` and promise-based results
- Requires `BModalOrchestrator` component at app root
- Toasts positioned top-right
- Success/info toasts: 3 second auto-dismiss
- Error toasts: manual close required (important for medical app reliability)

### Table migration
- Accept Bootstrap-Vue-Next improvements rather than forcing exact parity
- Traditional page numbers pagination style (1, 2, 3... with prev/next)
- Preserve row selection state during filtering/sorting operations
- Simple text message for empty table states ("No data available")

### Visual fidelity
- Accept Bootstrap 5 look — don't override defaults to match Bootstrap 4
- Preserve SysNDD brand colors only
- Direct replacement of Bootstrap 4 → 5 spacing classes (ml-* to ms-*, etc.)
- Keep traditional labels above inputs (no floating labels)

### Third-party replacements
- `@riophae/vue-treeselect` → `@r2rka/vue3-treeselect` (direct port, minimal changes)
- `vue2-perfect-scrollbar` → Remove entirely (use native scrollbars)
- `vue-meta` → `@unhead/vue` (standard Vue 3 head management)
- `vee-validate` 3 → 4 (composition API based migration)

### Security requirements
- Update all packages to latest compatible versions
- Run npm audit before and after migration
- Resolve all Dependabot critical/high alerts:
  - 6 critical: sha.js, cipher-base, form-data, pbkdf2×2, elliptic
  - 5 high: node-tar×2, qs, node-forge, axios
- Many vulnerabilities in transitive dependencies will resolve with Vue 3 ecosystem updates

### Claude's Discretion
- Exact modal animation timing
- Toast stacking behavior when multiple toasts appear
- Specific table hover/focus styling within Bootstrap 5 defaults
- Migration order for individual components

</decisions>

<specifics>
## Specific Ideas

- Modal pattern reference: Bootstrap-Vue-Next's `useModal()` composable documentation
- Keep familiar UX for medical users — no dramatic visual changes
- Prioritize security fixes as transitive dependencies update

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-bootstrap-vue-next*
*Context gathered: 2026-01-22*
