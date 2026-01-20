# Roadmap: SysNDD Developer Experience Improvements

## Overview

This roadmap delivers a modern developer experience for SysNDD through five phases: completing the API refactoring, establishing R API testing infrastructure, modernizing Docker and package management, adding Makefile automation, and expanding test coverage. Each phase builds on the previous, with testing infrastructure enabling TDD for all subsequent work.

## Phases

### Phase 1: API Refactoring Completion

**Goal:** Close out Issue #109 with verified, documented, clean API structure.

**Dependencies:** None (starting point)

**Requirements:** REF-01, REF-02, REF-03

**Plans:** 2 plans

Plans:
- [ ] 01-01-PLAN.md — Create verification scripts and confirm all 94 endpoints respond correctly
- [ ] 01-02-PLAN.md — Remove legacy code and update documentation

**Success Criteria:**
1. All 21 extracted endpoint files respond correctly to their documented routes
2. Legacy `api/_old/` directory is removed from repository
3. API documentation reflects the new modular endpoint structure
4. No regressions in existing functionality (manual verification against production)

---

### Phase 2: Test Infrastructure Foundation

**Goal:** Establish testthat-based testing framework enabling TDD for future work.

**Dependencies:** Phase 1 (need stable API structure to test against)

**Requirements:** TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06

**Plans:** 0 plans

Plans:
- [ ] TBD (created by /gsd:plan-phase)

**Success Criteria:**
1. Running `Rscript -e "testthat::test_dir('tests/testthat')"` executes tests successfully
2. At least 5 unit tests pass for core utility functions in `functions/`
3. At least 3 integration tests pass for authentication endpoints (login, logout, token validation)
4. At least 3 integration tests pass for entity CRUD operations (create, read, update)
5. Test database connection is isolated from development/production databases

---

### Phase 3: Package Management + Docker Modernization

**Goal:** Reproducible R environment with modern hybrid development workflow.

**Dependencies:** Phase 2 (tests validate environment works correctly)

**Requirements:** DEV-01, DEV-02, DEV-03, DEV-04, DEV-05, DEV-06, TEST-07

**Plans:** 0 plans

Plans:
- [ ] TBD (created by /gsd:plan-phase)

**Success Criteria:**
1. Running `renv::restore()` on a fresh clone installs identical package versions
2. `docker compose -f docker-compose.dev.yml up db` starts database for local API development
3. Docker Compose Watch syncs file changes to running containers without manual restart
4. External API calls (HGNC, PubMed) are mocked in tests using httptest2 fixtures
5. WSL2 development setup is documented with performance requirements

---

### Phase 4: Makefile Automation

**Goal:** Single unified interface for all development tasks across R and Vue components.

**Dependencies:** Phase 2 (test targets need working test infrastructure), Phase 3 (docker targets need dev compose file)

**Requirements:** MAKE-01, MAKE-02, MAKE-03, MAKE-04, MAKE-05, MAKE-06

**Plans:** 0 plans

Plans:
- [ ] TBD (created by /gsd:plan-phase)

**Success Criteria:**
1. Running `make help` displays all available targets with descriptions
2. Running `make install` sets up both R (renv::restore) and frontend (npm install) dependencies
3. Running `make dev` starts database container and displays instructions for local development
4. Running `make test` executes R API tests and reports results
5. Running `make lint` checks both R (lintr) and frontend (ESLint) code quality
6. Running `make pre-commit` validates code before committing (format + lint + test)

---

### Phase 5: Expanded Test Coverage

**Goal:** Comprehensive test coverage providing confidence for future refactoring.

**Dependencies:** Phase 2 (test infrastructure), Phase 4 (make test target)

**Requirements:** COV-01, COV-02, COV-03

**Plans:** 0 plans

Plans:
- [ ] TBD (created by /gsd:plan-phase)

**Success Criteria:**
1. Code coverage for `functions/*.R` files reaches 70% or higher
2. All critical endpoints have at least one integration test (entities, genes, phenotypes, analysis)
3. Running `make coverage` generates an HTML coverage report via covr
4. Test suite completes in under 2 minutes for fast feedback loop

---

## Progress

| Phase | Status | Requirements | Completion |
|-------|--------|--------------|------------|
| 1 - API Refactoring Completion | Planned | REF-01, REF-02, REF-03 | 0/3 |
| 2 - Test Infrastructure Foundation | Not Started | TEST-01 through TEST-06 | 0/6 |
| 3 - Package Management + Docker | Not Started | DEV-01 through DEV-06, TEST-07 | 0/7 |
| 4 - Makefile Automation | Not Started | MAKE-01 through MAKE-06 | 0/6 |
| 5 - Expanded Test Coverage | Not Started | COV-01, COV-02, COV-03 | 0/3 |

**Total:** 0/25 requirements complete

## Dependency Graph

```
Phase 1 (API Refactoring)
    |
    v
Phase 2 (Test Infrastructure)
    |
    +------------------+
    |                  |
    v                  v
Phase 3 (Docker/renv)  Phase 4 (Makefile)*
    |                  |
    +------------------+
    |
    v
Phase 5 (Test Coverage)

* Phase 4 can start after Phase 2, but needs Phase 3 for docker targets
```

## Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| testthat + mirai over callthat | mirai is production-ready; callthat is experimental | 2 |
| Hybrid dev (DB in Docker, API local) | Fast iteration, debugger access, consistent DB | 3 |
| renv over packrat | packrat is soft-deprecated, renv is standard | 3 |
| Root Makefile with namespaced targets | Universal, no dependencies, AI-assistant friendly | 4 |
| 70% function coverage target | Testable business logic prioritized over HTTP layer | 5 |

## Pitfalls to Avoid

From research synthesis (SUMMARY.md):

1. **Phase 2:** Separate business logic tests from HTTP endpoint tests
2. **Phase 2:** Use `withr::defer()` for database connection cleanup
3. **Phase 3:** Multi-stage Docker builds with BuildKit cache for fast renv::restore
4. **Phase 3:** Store project in WSL2 filesystem, NOT `/mnt/c/` (20x performance)
5. **Phase 3:** Document renv lockfile update workflow to prevent merge conflicts
6. **Phase 4:** Use `private` keyword for SHELL variable in Makefile

---
*Last updated: 2026-01-20*
