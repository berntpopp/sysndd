# Phase 5: Expanded Test Coverage - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Achieve comprehensive test coverage for the R API functions and critical endpoints, providing confidence for future refactoring. Target 70%+ coverage for `functions/*.R` files, integration tests for critical endpoints, a `make coverage` command, and test suite under 2 minutes.

</domain>

<decisions>
## Implementation Decisions

### Coverage Scope
- Prioritize business logic first (entity helpers, data transformations, complex logic)
- Database-dependent functions included via mocking; counts toward 70%
- External API functions (PubMed, PubTator, HGNC) use existing httptest2 fixtures from Phase 3; included in 70%
- Exclude config/setup files from coverage target (config loading, connection pooling, startup code)

### Test Organization
- Claude's discretion: Research testthat best practices to determine optimal test file organization
- Claude's discretion: Determine splitting strategy based on test count and complexity
- Claude's discretion: Determine helper/fixture organization based on testthat conventions
- Claude's discretion: Follow testthat best practices for file naming conventions

### Coverage Reporting
- Console summary output for `make coverage` (quick percentage for terminal)
- Warn if coverage drops below 70% but don't fail the command
- Store coverage reports in `coverage/` directory at repo root (gitignored)
- File-level summary reporting (overall % per file)

### Performance Budget
- Separate budgets: unit tests < 30s, integration tests < 2min
- Skip slow tests by default; add `make test-api-full` for complete suite
- Parallel test execution enabled (requires test isolation)
- Tests that exceed time budget timeout and fail

### Claude's Discretion
- Test file organization strategy (1:1 mapping vs domain grouping)
- Test file splitting strategy
- Helper and fixture organization structure
- Test file naming conventions
- Parallel execution implementation details

</decisions>

<specifics>
## Specific Ideas

- Build on existing test infrastructure from Phase 2 (108 tests passing)
- Leverage httptest2 fixtures already created in Phase 3 for external API mocking
- Use mirai for parallel test execution (already installed in Phase 2)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-expanded-test-coverage*
*Context gathered: 2026-01-21*
