# Phase 2: Test Infrastructure Foundation - Context

**Gathered:** 2026-01-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish testthat-based testing framework for R API, enabling TDD for future work. Includes unit tests for core utility functions (`functions/`) and integration tests for endpoints (`endpoints/`). Test coverage expansion is Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Test Organization
- Follow testthat 3e conventions (edition 3)
- Mirror structure: `test-{source-file-name}.R` maps to source files
- Use naming convention to separate test types: `test-unit-*.R` and `test-integration-*.R` in same `tests/testthat/` directory
- Descriptive, behavior-focused test names: `test_that("login endpoint returns 401 for invalid credentials", ...)`
- Brief comments for complex test scenarios explaining setup/assertions

### Database Isolation
- Separate test database (`sysndd_test`) alongside dev/production databases
- Hybrid approach for test isolation:
  - **Unit tests**: dittodb fixtures (no actual database needed)
  - **Integration tests**: Real test database with transaction rollback
- No SQLite mirroring (MariaDB-specific features would break)

### Test Execution
- Separate execution options via Makefile:
  - `make test` — runs all tests
  - `make test-unit` — runs only unit tests (`filter = "unit"`)
  - `make test-integration` — runs only integration tests (`filter = "integration"`)
- Parallel execution where tests are independent
- Verbose output — show each test name as it runs
- Console output only — no JUnit XML artifacts

### Test Data Fixtures
- dittodb fixtures recorded from real database using `start_db_recording()`
- Fixtures stored in `tests/testthat/fixtures/` accessed via `test_path()`
- Integration test seeding: SQL seed script for base data + R helper functions for test-specific data (e.g., `create_test_user()`, `create_test_entity()`)
- Realistic-looking test data (john.smith@institution.edu, real gene names) for better edge case coverage

### Claude's Discretion
- Skip integration tests with informative message when test DB unavailable; CI environment requires DB
- Exact helper function signatures and implementation
- Test file organization within naming convention
- Parallel execution configuration details
- dittodb mock storage structure

</decisions>

<specifics>
## Specific Ideas

- Referenced testthat 3e best practices from R Packages (2e) book
- dittodb for database mocking — eliminates need for DB in CI for unit tests
- Transaction rollback for integration tests — fast cleanup, real DB validation
- Makefile targets align with Phase 4 automation plans

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-test-infrastructure-foundation*
*Context gathered: 2026-01-20*

## Sources

- [R Packages (2e) - Testing basics](https://r-pkgs.org/testing-basics.html)
- [R Packages (2e) - Designing your test suite](https://r-pkgs.org/testing-design.html)
- [testthat documentation](https://testthat.r-lib.org/)
- [dittodb - Test Environment for DB Queries](https://cran.r-project.org/web/packages/dittodb/vignettes/dittodb.html)
- [testthat test_path documentation](https://testthat.r-lib.org/reference/test_path.html)
- [R-hub blog - Helper code and files for testthat tests](https://blog.r-hub.io/2020/11/18/testthat-utility-belt/)
