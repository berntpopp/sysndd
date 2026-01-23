# Roadmap: SysNDD v4 Backend Overhaul

## Overview

The v4 Backend Overhaul modernizes the R/Plumber API through a strict phase sequence: Foundation (R upgrade), Security (SQL injection and password hashing), Async (non-blocking operations), Architecture (repository and service layers), OMIM (data source migration), and Versioning/Cleanup. This 10-12 week effort addresses 66 security vulnerabilities, eliminates technical debt accumulated over years, and prepares the API for future development with DRY/KISS/SOLID principles.

## Milestones

- Completed v1.0 Developer Experience - Phases 1-5 (shipped 2026-01-21)
- Completed v2.0 Docker Infrastructure - Phases 6-9 (shipped 2026-01-22)
- Completed v3.0 Frontend Modernization - Phases 10-17 (shipped 2026-01-23)
- Current: v4.0 Backend Overhaul - Phases 18-24 (in progress)

## Phases

**Phase Numbering:**
- Continues from v3 (Phase 17) - v4 starts at Phase 18
- Integer phases (18, 19, 20): Planned milestone work
- Decimal phases (18.1, 18.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 18: Foundation** - Upgrade R 4.1.2 to 4.4.3 with renv migration
- [ ] **Phase 19: Security Hardening** - Fix SQL injection and implement password hashing
- [ ] **Phase 20: Async/Non-blocking** - Add mirai for long-running operations
- [ ] **Phase 21: Repository Layer** - Create database access layer with domain repositories
- [ ] **Phase 22: Service Layer & Middleware** - Extract business logic and auth middleware
- [ ] **Phase 23: OMIM Migration** - Switch from genemap2 to mim2gene.txt + MONDO/HPO
- [ ] **Phase 24: Versioning, Pagination & Cleanup** - API versioning, cleanup, and testing

## Phase Details

### Phase 18: Foundation
**Goal**: Stable R 4.4.x environment with modern dependencies and clean renv.lock
**Depends on**: Nothing (first phase of v4)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06
**Success Criteria** (what must be TRUE):
  1. API container starts successfully on R 4.4.3 base image
  2. All existing API tests pass on upgraded R version
  3. renv::restore() completes without errors or Dockerfile workarounds
  4. Matrix/lme4 clustering endpoints return correct results
**Plans**: 2 plans in 2 waves

Plans:
- [ ] 18-01-PLAN.md - Create fresh renv.lock on R 4.4.x with complete dependencies
- [ ] 18-02-PLAN.md - Update Dockerfile to R 4.4.3, remove workarounds, verify build

### Phase 19: Security Hardening
**Goal**: Zero SQL injection vulnerabilities and secure password storage
**Depends on**: Phase 18 (Foundation)
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, SEC-07, ERR-01, ERR-02, ERR-03, ERR-04
**Success Criteria** (what must be TRUE):
  1. All SQL injection points use parameterized queries (dbBind)
  2. New user registrations store Argon2id-hashed passwords
  3. Existing plaintext users can log in (dual-hash verification)
  4. API errors return RFC 9457 format with consistent HTTP status codes
  5. Logs contain no passwords, tokens, or sensitive data
**Plans**: 5 plans in 4 waves

Plans:
- [ ] 19-01-PLAN.md - Create core security infrastructure (security.R, errors.R, responses.R, logging_sanitizer.R)
- [ ] 19-02-PLAN.md - Fix SQL injection in database-functions.R (22 vulnerabilities)
- [ ] 19-03-PLAN.md - Fix SQL injection in user_endpoints.R and implement password hashing
- [ ] 19-04-PLAN.md - Integrate error handler middleware and log sanitization
- [ ] 19-05-PLAN.md - Add package dependencies, create tests, verify integration

### Phase 20: Async/Non-blocking
**Goal**: Long-running operations complete without blocking other API requests
**Depends on**: Phase 19 (Security Hardening)
**Requirements**: ASYNC-01, ASYNC-02, ASYNC-03, ASYNC-04, ASYNC-05, ASYNC-06
**Success Criteria** (what must be TRUE):
  1. Ontology update endpoint returns HTTP 202 with job ID immediately
  2. Clustering analysis endpoint returns HTTP 202 with job ID immediately
  3. Job status polling returns current progress and completion state
  4. Other API requests respond normally during long-running operations
**Plans**: 3 plans in 3 waves

Plans:
- [ ] 20-01-PLAN.md - Create job manager and mirai daemon pool infrastructure
- [ ] 20-02-PLAN.md - Add async clustering endpoints and job status polling
- [ ] 20-03-PLAN.md - Add async ontology update endpoint and background cleanup

### Phase 21: Repository Layer
**Goal**: Single point of database access with parameterized queries
**Depends on**: Phase 20 (Async/Non-blocking)
**Requirements**: ARCH-01, ARCH-02, ARCH-03, ARCH-04, ARCH-05, ARCH-06, ARCH-07, ARCH-08, ARCH-09, ARCH-10
**Success Criteria** (what must be TRUE):
  1. Zero direct dbConnect() calls in endpoint files
  2. All database operations use execute_query/fetch_all helpers
  3. Each domain has dedicated repository (entity, review, status, publication, phenotype, ontology, user, hash)
  4. Connection pool used consistently (no connection leaks under load)
**Plans**: TBD

Plans:
- [ ] 21-01: TBD (to be determined during planning)

### Phase 22: Service Layer & Middleware
**Goal**: Clean separation of HTTP handling, business logic, and cross-cutting concerns
**Depends on**: Phase 21 (Repository Layer)
**Requirements**: ARCH-11, ARCH-12, ARCH-13, ARCH-14, ARCH-15, ARCH-16, ARCH-17, ARCH-18, ARCH-19, ARCH-20, QA-01, QA-02, QA-03, QA-04, QA-05
**Success Criteria** (what must be TRUE):
  1. Authentication checks use require_auth/require_role middleware (no duplicated auth code)
  2. All endpoints verified with curl before and after refactoring
  3. Response format matches production API (https://sysndd.dbmr.unibe.ch/API)
  4. database-functions.R eliminated (1,234-line god file decomposed)
  5. Global mutable state minimized (<<- usages reduced)
**Plans**: TBD

Plans:
- [ ] 22-01: TBD (to be determined during planning)

### Phase 23: OMIM Migration
**Goal**: OMIM annotations work without genemap2 dependency, with OMIM disease names preserved
**Depends on**: Phase 22 (Service Layer & Middleware)
**Requirements**: OMIM-01, OMIM-02, OMIM-03, OMIM-04, OMIM-05, OMIM-06, MONDO-01, MONDO-02, MONDO-03
**Success Criteria** (what must be TRUE):
  1. OMIM annotation update succeeds using mim2gene.txt for gene mappings
  2. OMIM disease names retrieved from JAX ontology API (not replaced by MONDO)
  3. Data completeness validated before database writes (no empty critical fields)
  4. ManageAnnotations admin view works with new data sources
  5. MONDO equivalence available in curation interface (optional enhancement)
**Plans**: TBD

Plans:
- [ ] 23-01: TBD (to be determined during planning)

### Phase 24: Versioning, Pagination & Cleanup
**Goal**: Production-ready API with versioning, pagination, and clean codebase
**Depends on**: Phase 23 (OMIM Migration)
**Requirements**: PAG-01, PAG-02, PAG-03, PAG-04, PAG-05, VER-01, VER-02, VER-03, VER-04, TEST-01, TEST-02, TEST-03, TEST-04, TEST-05
**Success Criteria** (what must be TRUE):
  1. /api/version endpoint returns semantic version and last commit
  2. All tabular endpoints support cursor-based pagination
  3. 30 TODO comments resolved or documented as intentional
  4. lintr issues reduced (target: <200 from current 1240)
  5. API integration tests pass for all refactored endpoints
**Plans**: TBD

Plans:
- [ ] 24-01: TBD (to be determined during planning)

## Progress

**Execution Order:**
Phases execute in numeric order: 18 -> 18.1 (if inserted) -> 19 -> 20 -> 21 -> 22 -> 23 -> 24

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 18. Foundation | 0/2 | Planned | - |
| 19. Security Hardening | 0/5 | Planned | - |
| 20. Async/Non-blocking | 0/3 | Planned | - |
| 21. Repository Layer | 0/TBD | Not started | - |
| 22. Service Layer & Middleware | 0/TBD | Not started | - |
| 23. OMIM Migration | 0/TBD | Not started | - |
| 24. Versioning, Pagination & Cleanup | 0/TBD | Not started | - |

## Coverage Summary

**v4 Requirements:** 71 total
**Mapped to phases:** 71
**Unmapped:** 0

| Category | Count | Phase |
|----------|-------|-------|
| Foundation (FOUND) | 6 | Phase 18 |
| Security (SEC) | 8 | Phase 19 |
| Error Handling (ERR) | 4 | Phase 19 |
| Async (ASYNC) | 6 | Phase 20 |
| Architecture (ARCH-01 to ARCH-10) | 10 | Phase 21 |
| Architecture (ARCH-11 to ARCH-20) | 10 | Phase 22 |
| Quality Assurance (QA) | 5 | Phase 22 |
| OMIM | 6 | Phase 23 |
| MONDO (optional) | 3 | Phase 23 |
| Pagination (PAG) | 5 | Phase 24 |
| Versioning (VER) | 4 | Phase 24 |
| Testing (TEST) | 5 | Phase 24 |

---
*Roadmap created: 2026-01-23*
*Last updated: 2026-01-23 - Phase 20 planned (3 plans in 3 waves)*
