# Phase 74: API Bug Fixes - Context

**Gathered:** 2026-02-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix three independent 500 errors in API endpoints so they respond correctly for all valid inputs. The three bugs are: (1) direct-approval entity creation fails, (2) Panels page column alias mismatch, (3) clustering endpoints crash on empty STRING interactions. Scanning for similar patterns is in scope; new features are not.

</domain>

<decisions>
## Implementation Decisions

### Error response behavior
- Empty clustering response: Researcher should investigate REST API best practices for empty responses; Claude decides based on research + existing API patterns
- Direct-approval creation response: Researcher should check best practices AND existing API entity creation response patterns; Claude decides to match the better approach
- Panels fix: Minimal — just correct the column alias mismatch, no extra validation layer
- Error detail level: Match current API behavior — no changes to error message verbosity

### Testing strategy
- Test depth: Regression tests + edge cases (nulls, empty inputs, boundary values) for each fixed endpoint
- Clustering tests: Both mocked unit tests AND real DB integration tests; integration tests skip in GitHub Actions CI, run only locally with database available — researcher should investigate best practices for this skip pattern
- Entity creation write tests: Same pattern — real writes with cleanup locally, mocked DB layer in CI — researcher should investigate best practices and docs
- No E2E tests needed — unit + integration is sufficient for these bug fixes

### Fix isolation vs cleanup
- Clustering (empty tibble in rowwise): Fix the specific bug AND scan for similar rowwise patterns across other endpoints that might fail on empty data — fix all found
- Panels (column alias): Fix the alias AND scan related endpoints for similar column name mismatches between SQL queries and R code — fix all found
- Direct-approval entity creation: Fix the bug AND review the normal (non-direct) approval path for consistency and similar risks
- If scanning reveals additional issues: Fix all discovered issues in this phase, do not defer

### Claude's Discretion
- Exact empty response format (after research)
- Direct-approval response shape (after research)
- How to structure the CI skip mechanism for integration tests
- Scan scope — how broadly to search for similar patterns

</decisions>

<specifics>
## Specific Ideas

- User wants researcher to investigate REST API best practices via web search for empty response handling and test organization patterns
- Integration tests should be skippable in CI but runnable locally — a first-class pattern, not a hack
- "Fix all found issues" philosophy — if scanning reveals similar bugs, fix them rather than logging for later

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 74-api-bug-fixes*
*Context gathered: 2026-02-05*
