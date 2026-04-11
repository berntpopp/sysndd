# Phase 10: Vue 3 Core Migration - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate SysNDD from Vue 2.7 to Vue 3 with @vue/compat migration build. Includes Vue Router 4 migration, event bus removal, lifecycle hook updates, and Pinia verification. Bootstrap-Vue-Next migration is a separate phase (11).

</domain>

<decisions>
## Implementation Decisions

### Migration Rollout Strategy
- Full compat mode first — get app booting on Vue 3 + @vue/compat before fixing any warnings
- Fix warnings API-by-API (not file-by-file) after app boots
- Git branch only for rollback — feature branch with commits, rollback by reverting/switching
- Plans within phase can overlap logically (e.g., lifecycle fixes while doing router migration)
- Zero compat warnings required before proceeding to Phase 11

### Compat Mode Strictness
- All warnings visible in console — no suppression, track progress by watching warnings decrease
- Migration checklist document — create a document listing all warnings with status (fixed/pending/deferred)
- Fix warnings by frequency first — reduce console noise quickly by addressing most common warnings
- Third-party library warnings (Bootstrap-Vue, vue-treeselect): Claude decides handling based on replacement timeline

### Event Bus Replacement Pattern
- Pinia stores for all cross-component communication — no mitt or other event emitter libraries
- Hybrid store design: extend existing stores when event relates to existing domain, create dedicated stores for new cross-cutting concerns
- Pre-audit all $root.$emit/$root.$on usages — create complete inventory before replacing any

### Testing Verification Approach
- Manual smoke testing with Playwright MCP after each major change
- Add E2E tests incrementally during Phase 10 (not deferred to Phase 15)
- Test location: app/tests/e2e/
- Critical flows to test:
  - Gene/disease tables (filtering, sorting, pagination)
  - Entity detail pages (viewing gene/disease/ontology details)
  - Authentication flows (login, logout, session management)

### Claude's Discretion
- Third-party library warning handling strategy (suppress vs document based on replacement timeline)
- Optimal order of plans within phase based on dependencies
- Specific Pinia store naming and structure decisions

</decisions>

<specifics>
## Specific Ideas

- "Full compat mode first" pattern validated by Vue team and large migrations (Crisp: 250K LOC in 2 weeks)
- Event bus → Pinia is more verbose but more declarative and traceable
- Use Playwright MCP for manual verification during development

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-vue3-core-migration*
*Context gathered: 2026-01-22*
