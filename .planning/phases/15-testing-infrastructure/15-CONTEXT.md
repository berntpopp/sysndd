# Phase 15: Testing Infrastructure - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish Vitest + Vue Test Utils foundation with example tests for components, composables, and accessibility. This phase creates testing infrastructure and patterns — not comprehensive test coverage for the entire codebase.

</domain>

<decisions>
## Implementation Decisions

### Test organization
- Co-located test files: `ComponentName.spec.ts` next to `ComponentName.vue`
- Naming convention: `*.spec.ts` for all tests
- Test grouping: By feature/behavior using `describe('when user submits form', () => { ... })`
- Shared utilities in `app/src/test-utils/` for mocks, mounting helpers, and fixtures

### Coverage strategy
- Initial threshold: 40% (warn only, don't block CI)
- Priority: Composables first — most testable and valuable business logic
- Exclusions: `*.config.ts`, `main.ts`, `router/*`, type definitions
- Coverage report: Generate but don't fail builds initially

### Accessibility testing
- Target: WCAG 2.2 AA compliance
- Axe strictness: Fail on violations, warn on needs-review items
- Scope: Interactive components (forms, modals, tables, navigation)
- Helper: Simple `expectNoA11yViolations()` wrapper in test-utils

### Example test selection
- Purpose: Learning patterns — clear, well-documented examples that teach the testing approach
- Component examples: 3-5 components showing common testing patterns
- API mocking: MSW (Mock Service Worker) for realistic API mocking
- Composable testing: Both async/await and reactive ref/computed patterns

### Claude's Discretion
- Which specific components to use for examples (based on teaching value)
- Which specific composables to use for examples (based on complexity variety)
- MSW handler organization structure
- Exact test-utils helper implementations

</decisions>

<specifics>
## Specific Ideas

- Focus on examples that teach patterns, not on achieving coverage in this phase
- Interactive components for accessibility tests: anything users click, type into, or navigate with keyboard
- MSW for API mocking gives more realistic tests than vi.mock

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-testing-infrastructure*
*Context gathered: 2026-01-23*
