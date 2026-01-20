# Requirements: SysNDD Developer Experience Improvements

## Overview

Developer experience and infrastructure improvements for SysNDD, focusing on API refactoring completion, R API testing infrastructure, Makefile automation, and Docker/development modernization.

## v1 Requirements

### API Refactoring Completion (REF)

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| REF-01 | Verify all extracted endpoints function correctly | Must | Issue #109 cleanup |
| REF-02 | Remove legacy `api/_old/` directory | Must | Cleanup after verification |
| REF-03 | Update documentation to reflect new API structure | Should | README and inline docs |

### R API Testing Infrastructure (TEST)

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| TEST-01 | Install testthat + mirai testing framework | Must | Issue #123 foundation |
| TEST-02 | Create test directory structure with helpers | Must | setup.R, helper files |
| TEST-03 | Write unit tests for core utility functions | Must | functions/*.R coverage |
| TEST-04 | Write endpoint tests for authentication flow | Must | JWT/auth validation |
| TEST-05 | Write endpoint tests for entity CRUD operations | Must | Core business logic |
| TEST-06 | Configure test database connection | Must | Isolated test DB |
| TEST-07 | Add tests for external API mocking (HGNC, PubMed) | Should | httptest2 for mocking |

### Makefile Automation (MAKE)

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| MAKE-01 | Create Makefile with self-documenting help target | Must | `make help` |
| MAKE-02 | Dev setup targets: setup, install, setup-db | Must | Onboarding commands |
| MAKE-03 | Running targets: dev, api, frontend | Must | Development workflow |
| MAKE-04 | Testing targets: test, test-api, lint | Must | Quality assurance |
| MAKE-05 | Docker targets: docker-build, docker-up, docker-down | Must | Container lifecycle |
| MAKE-06 | Quality targets: format, lint-fix, pre-commit | Should | Code quality workflow |

### Docker/Development Modernization (DEV)

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| DEV-01 | Create docker-compose.dev.yml for hybrid development | Must | DB in Docker, API local |
| DEV-02 | Update docker-compose.yml with Watch for hot-reload | Should | Modern Docker workflow |
| DEV-03 | Pin Docker base image versions explicitly | Should | Reproducibility |
| DEV-04 | Add .dockerignore for faster builds | Should | Build optimization |
| DEV-05 | Configure renv for R package version locking | Must | Reproducible R environment |
| DEV-06 | Create renv.lock from current package state | Must | Lock current versions |

### Expanded Test Coverage (COV)

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| COV-01 | Achieve 70%+ coverage of function files | Should | functions/*.R target |
| COV-02 | Integration tests for all critical endpoints | Should | Entity, auth, analysis |
| COV-03 | Coverage reporting via covr | Should | Visibility into coverage |

## v2 (Out of Scope)

| ID | Requirement | Reason |
|----|-------------|--------|
| v2-01 | Vue 3 migration | Scheduled for later milestone |
| v2-02 | Frontend testing | R API testing is priority |
| v2-03 | CI/CD pipeline | Focus on local dev first |
| v2-04 | Production deployment changes | DevEx focused |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REF-01 | Phase 1 | Pending |
| REF-02 | Phase 1 | Pending |
| REF-03 | Phase 1 | Pending |
| TEST-01 | Phase 2 | Pending |
| TEST-02 | Phase 2 | Pending |
| TEST-03 | Phase 2 | Pending |
| TEST-04 | Phase 2 | Pending |
| TEST-05 | Phase 2 | Pending |
| TEST-06 | Phase 2 | Pending |
| TEST-07 | Phase 3 | Pending |
| MAKE-01 | Phase 4 | Pending |
| MAKE-02 | Phase 4 | Pending |
| MAKE-03 | Phase 4 | Pending |
| MAKE-04 | Phase 4 | Pending |
| MAKE-05 | Phase 4 | Pending |
| MAKE-06 | Phase 4 | Pending |
| DEV-01 | Phase 3 | Pending |
| DEV-02 | Phase 3 | Pending |
| DEV-03 | Phase 3 | Pending |
| DEV-04 | Phase 3 | Pending |
| DEV-05 | Phase 3 | Pending |
| DEV-06 | Phase 3 | Pending |
| COV-01 | Phase 5 | Pending |
| COV-02 | Phase 5 | Pending |
| COV-03 | Phase 5 | Pending |

---
*Last updated: 2026-01-20*
