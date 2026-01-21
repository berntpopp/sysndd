# State: SysNDD Developer Experience Improvements

## Project Reference

**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current Focus:** Phase 3 in progress (Package Management & Docker Modernization)

## Current Position

**Phase:** 3 - Package Management & Docker Modernization (in progress)
**Plan:** 03-04 of 4 in phase
**Status:** In progress
**Last activity:** 2026-01-21 - Completed 03-04-PLAN.md

```
Progress: [████████..] 80%
Phase 1: [██████████] 2/2 plans COMPLETE
Phase 2: [██████████] 5/5 plans COMPLETE
Phase 3: [███████...] 3/4 plans (in progress)
```

**Plans completed:**
- 01-01: Endpoint verification scripts (3 tasks, 5 commits)
- 01-02: Legacy cleanup and documentation (2 tasks, 3 commits)
- 02-01: Test infrastructure foundation (2 tasks, 1 commit)
- 02-02: Test database configuration (2 tasks, 1 commit)
- 02-03: Helper function unit tests (2 tasks, 2 commits)
- 02-04: Authentication integration tests (2 tasks, 2 commits)
- 02-05: Entity integration tests (1 task, 1 commit)
- 03-01: Phase research and planning (research phase)
- 03-02: Docker development configuration (2 tasks, 2 commits)
- 03-04: External API mocking with httptest2 (2 tasks, 2 commits)

## GitHub Issues

| Issue | Description | Phase | Status |
|-------|-------------|-------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | 1 | Complete - verified, ready for PR |
| #123 | Implement comprehensive testing | 2, 5 | Not started |

## Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Session count | 4 | Current session |
| Phases completed | 2/5 | Phase 1, Phase 2 COMPLETE |
| Requirements completed | 9/25 | REF-01, REF-02, REF-03, TEST-01, TEST-03, TEST-04, TEST-06, TEST-07 |
| Plans executed | 10 | 01-01, 01-02, 02-01 thru 02-05, 03-01, 03-02, 03-04 |
| Total commits | 21 | 10 from Phase 1, 7 from Phase 2, 4 from Phase 3 |
| Test count | 108 | All passing (4 skipped - expected) |

## Accumulated Context

### Key Decisions Made

| Decision | Rationale | Date | Plan |
|----------|-----------|------|------|
| testthat + mirai for testing | callthat experimental; mirai production-ready | 2026-01-20 | Research |
| Hybrid dev setup | DB in Docker, API/frontend local for fast iteration | 2026-01-20 | Research |
| renv for R packages | Industry standard, replaces deprecated packrat | 2026-01-20 | Research |
| Makefile over Taskfile | Universal, no dependencies, works everywhere | 2026-01-20 | Research |
| Remove legacy _old directory | Safe after verification; preserved in git history | 2026-01-20 | 01-02 |
| Document all 21 endpoints in table | Clear reference for mount paths and purpose | 2026-01-20 | 01-02 |
| Test DB isolation via separate database name | Prevents any possibility of test data affecting dev/prod | 2026-01-20 | 02-02 |
| Transaction-based testing with auto-rollback | Tests never leave data in database, maintaining clean state | 2026-01-20 | 02-02 |
| Graceful test skipping when DB unavailable | Tests skip in CI/CD where test DB might not exist | 2026-01-20 | 02-02 |
| testthat 3e conventions for test structure | setup.R for global init, helper-*.R for modular utilities | 2026-01-20 | 02-01 |
| Auto-source helper files via pattern matching | Enables modular test utilities automatically available | 2026-01-20 | 02-01 |
| Test runner enforces working directory | Tests must run from api/ for correct path resolution | 2026-01-20 | 02-01 |
| Tidyverse for test assertions | dplyr, tibble, stringr provide data manipulation in tests | 2026-01-20 | 02-01 |
| Robust path resolution for test files | Detect api/ directory from test context to source functions reliably | 2026-01-20 | 02-03 |
| Test pure functions first | Start with functions without DB/API dependencies for fast, simple verification | 2026-01-20 | 02-03 |
| tidyr required for helper function tests | helper-functions.R uses tidyr::nest, must be available in test environment | 2026-01-20 | 02-03 |
| Use absolute path for sourcing helper-functions.R | testthat changes working directory during test execution | 2026-01-21 | 02-05 |
| Test helper functions directly without DB mocks | Entity helpers handle data transformation logic independently | 2026-01-21 | 02-05 |
| Test JWT logic at function level not HTTP | Avoids requiring running API server during tests, faster and more reliable | 2026-01-21 | 02-04 |
| Use expect_error for expired token tests | jose validates expiration by default and throws error | 2026-01-21 | 02-04 |
| Enhanced config path resolution for testthat | testthat changes working directory, need multiple path strategies | 2026-01-21 | 02-04 |
| Port 7654 for dev DB | Matches existing config.yml sysndd_db_local configuration | 2026-01-21 | 03-02 |
| Port 7655 for test DB | Enables running both dev and test databases simultaneously | 2026-01-21 | 03-02 |
| Docker Compose Watch for hot-reload | Syncs endpoints/ and functions/ changes without container restart | 2026-01-21 | 03-02 |
| Named volumes for data persistence | mysql_dev_data and mysql_test_data persist across restarts | 2026-01-21 | 03-02 |
| httptest2 for API mocking | Industry standard for R API testing; records real responses to JSON files | 2026-01-21 | 03-04 |
| Pure function tests run without network | table_articles_from_xml, generate_query_hash work independently | 2026-01-21 | 03-04 |
| Graceful skip for network-dependent tests | skip_if_no_fixtures_or_network allows tests to skip not fail | 2026-01-21 | 03-04 |
| Redactor for fixture files | Strips email addresses and API keys from recorded fixtures | 2026-01-21 | 03-04 |

### Technical Discoveries

- API refactoring created 21 endpoint files in `api/endpoints/`
- All 21 endpoints verified working (Plan 01-01: 21/21 tests passing)
- Fixed /api/list/status endpoint bug during verification
- Legacy code removed after verification (Plan 01-02)
- R linting infrastructure already exists in `api/scripts/`
- Test infrastructure foundation complete (Plans 02-01, 02-02)
- testthat 3e framework with setup.R and auto-sourced helpers
- All testing packages installed (testthat, dittodb, withr, httr2, mirai)
- New modular structure has 94 endpoints vs ~20 in old monolithic file
- config.yml is gitignored (correct for security) - test config local only
- Unit tests established for helper functions (Plan 02-03: 11 test blocks, 29 assertions)
- is_valid_email regex allows spaces in local part (discovered via testing)
- Helper function tests use robust path resolution to find api/ directory
- Entity integration tests established (Plan 02-05: 9 test blocks, 16 assertions)
- Entity tests validate sorting, field selection, pagination without database
- Absolute path sourcing required for helper-functions.R due to testthat working directory changes
- Authentication integration tests established (Plan 02-04: 9 test blocks, 14 assertions)
- JWT token generation helpers created (create_test_jwt, decode_test_jwt, auth_header)
- jose package installed for JWT token testing
- Config path resolution enhanced to handle testthat working directory changes
- Docker Compose dev config created with separate dev/test databases
- .dockerignore files reduce build context by excluding renv/library, node_modules, tests
- Docker Compose Watch configured for api service hot-reload
- httptest2 installed for external API mocking (v1.2.2)
- easyPubMed uses base R url() connections not intercepted by httptest2
- PubMed/PubTator integration tests skip gracefully when fixtures unavailable
- External API test files now have 49 new assertions (14 PubMed, 35 PubTator)
- Total test count: 108 passing, 4 skipped (expected behavior)

### Blockers

None currently.

**Minor concerns:**
- Test database (sysndd_db_test) doesn't exist yet - needs to be created before integration tests can run
- Tests will skip gracefully until test DB is set up (skip_if_no_test_db() pattern)
- Users need to update local config.yml sysndd_db_test.port to 7655 to match docker-compose.dev.yml

### TODOs (Cross-Session)

- [x] Verify all extracted endpoints function correctly (Phase 1) - Done in 01-01
- [x] Remove legacy _old directory (Phase 1) - Done in 01-02
- [x] Update documentation for new structure (Phase 1) - Done in 01-02
- [x] Test database configuration helpers (Phase 2) - Done in 02-02
- [x] Create test directory structure (Phase 2) - Done in 02-01
- [x] Unit tests for helper functions (Phase 2) - Done in 02-03
- [x] Authentication integration tests (Phase 2) - Done in 02-04
- [x] Entity integration tests (Phase 2) - Done in 02-05
- [x] Phase 2 test infrastructure (Phase 2) - COMPLETE
- [x] Docker development configuration (Phase 3) - Done in 03-02
- [x] External API mocking (Phase 3) - Done in 03-04
- [ ] Create PR and close Issue #109 (Phase 1, Plan 01-03)
- [ ] Create test database (sysndd_db_test) - can now use docker-compose.dev.yml
- [ ] Document WSL2 filesystem requirement for Windows developers (Phase 3)
- [ ] renv package management setup (Phase 3, Plan 03-03)
- [ ] Makefile automation (Phase 3, remaining plan)
- [ ] Record fixtures from live API for full integration test coverage

## Session Continuity

### Last Session

**Date:** 2026-01-21
**Work completed:**
- Plan 03-04: Created external API mocking infrastructure
  - helper-mock-apis.R with httptest2 configuration
  - test-external-pubmed.R with 14 pure function tests + 4 integration tests
  - test-external-pubtator.R with 18 pure function tests + 3 integration tests
  - Fixture directories for PubMed and PubTator responses
  - Test suite now at 108 passing tests

**State at end:** Phase 3 in progress (3/4 plans complete). Ready for Plan 03-03 (renv setup).

### Resume Instructions

To continue this project:

1. Continue Phase 3: Plan 03-03 (renv package management setup)
2. Start test database: `docker compose -f docker-compose.dev.yml up -d mysql-test`
3. Update local config.yml sysndd_db_test.port to 7655
4. Review accumulated decisions in this STATE.md before planning

### Files to Review on Resume

- `.planning/phases/03-package-management-docker-modernization/03-04-SUMMARY.md` - External API mocking
- `.planning/phases/03-package-management-docker-modernization/03-02-SUMMARY.md` - Docker dev configuration
- `api/tests/testthat/helper-mock-apis.R` - httptest2 configuration
- `api/tests/testthat/test-external-pubmed.R` - PubMed API tests
- `api/tests/testthat/test-external-pubtator.R` - PubTator API tests
- `docker-compose.dev.yml` - Development Docker Compose file

---
*Last updated: 2026-01-21*
