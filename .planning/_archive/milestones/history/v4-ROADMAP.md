# Milestone v4.0: Backend Overhaul

**Status:** ✅ SHIPPED 2026-01-24
**Phases:** 18-24
**Total Plans:** 42

## Overview

The v4 Backend Overhaul modernizes the R/Plumber API through a strict phase sequence: Foundation (R upgrade), Security (SQL injection and password hashing), Async (non-blocking operations), Architecture (repository and service layers), OMIM (data source migration), and Versioning/Cleanup. This milestone addressed 66 security vulnerabilities, eliminated technical debt accumulated over years, and prepared the API for future development with DRY/KISS/SOLID principles.

## Phases

### Phase 18: Foundation

**Goal:** Stable R 4.4.x environment with modern dependencies and clean renv.lock
**Depends on:** Nothing (first phase of v4)
**Plans:** 2 plans

Plans:
- [x] 18-01: Create fresh renv.lock on R 4.4.x with complete dependencies
- [x] 18-02: Update Dockerfile to R 4.4.3, remove workarounds, verify build

**Details:**
- R upgraded from 4.1.2 to 4.4.3
- Matrix package 1.7.2 for ABI compatibility
- Docker base image rocker/r-ver:4.4.3
- P3M URLs updated to noble binaries
- Fresh renv.lock with 281 packages
- FactoMineR/lme4 2022 snapshot workaround removed

### Phase 19: Security Hardening

**Goal:** Zero SQL injection vulnerabilities and secure password storage
**Depends on:** Phase 18 (Foundation)
**Plans:** 5 plans

Plans:
- [x] 19-01: Create core security infrastructure (security.R, errors.R, responses.R, logging_sanitizer.R)
- [x] 19-02: Fix SQL injection in database-functions.R (22 vulnerabilities)
- [x] 19-03: Fix SQL injection in user_endpoints.R and implement password hashing
- [x] 19-04: Integrate error handler middleware and log sanitization
- [x] 19-05: Add package dependencies, create tests, verify integration

**Details:**
- All 66 SQL injection vulnerabilities fixed with parameterized queries (dbBind)
- Argon2id password hashing via sodium package
- Progressive re-hash on login for existing plaintext passwords
- RFC 9457 error format with httpproblems package
- Log sanitization to exclude passwords, tokens, sensitive data

### Phase 20: Async/Non-blocking

**Goal:** Long-running operations complete without blocking other API requests
**Depends on:** Phase 19 (Security Hardening)
**Plans:** 3 plans

Plans:
- [x] 20-01: Create job manager and mirai daemon pool infrastructure
- [x] 20-02: Add async clustering endpoints and job status polling
- [x] 20-03: Add async ontology update endpoint and background cleanup

**Details:**
- mirai package for async processing
- 8-worker daemon pool with 30-minute job timeout
- HTTP 202 Accepted pattern for long-running operations
- Job status polling with progress updates
- Pre-fetch data workaround for pool access limitation

### Phase 21: Repository Layer

**Goal:** Single point of database access with parameterized queries
**Depends on:** Phase 20 (Async/Non-blocking)
**Plans:** 10 plans (8 core + 2 gap closure)

Plans:
- [x] 21-01: Create db-helpers.R with query execution functions
- [x] 21-02: Create entity-repository.R and review-repository.R
- [x] 21-03: Create status-repository.R and publication-repository.R
- [x] 21-04: Create phenotype-repository.R and ontology-repository.R
- [x] 21-05: Create user-repository.R and hash-repository.R
- [x] 21-06: Refactor database-functions.R to use repositories
- [x] 21-07: Refactor user_endpoints.R and re_review_endpoints.R
- [x] 21-08: Refactor remaining files
- [x] 21-09: Gap closure - Migrate authentication_endpoints.R and publication-functions.R
- [x] 21-10: Gap closure - Migrate admin_endpoints.R and pubtator-functions.R

**Details:**
- db-helpers.R with db_execute_query, db_execute_statement, db_with_transaction
- 8 domain repositories (entity, review, status, publication, phenotype, ontology, user, hash)
- 131 parameterized database calls
- Zero direct DBI bypasses in production code
- Only pool creation in start_sysndd_api.R

### Phase 22: Service Layer & Middleware

**Goal:** Clean separation of HTTP handling, business logic, and cross-cutting concerns
**Depends on:** Phase 21 (Repository Layer)
**Plans:** 10 plans

Plans:
- [x] 22-01: Create middleware infrastructure (require_auth filter, require_role helper)
- [x] 22-02: Create auth-service.R (signin, verify, refresh, token generation)
- [x] 22-03: Create entity-service.R (create, deactivate, get_full, validate)
- [x] 22-04: Create review-service.R and approval-service.R
- [x] 22-05: Create user-service.R, status-service.R, and search-service.R
- [x] 22-06: Refactor user, admin, authentication endpoints to use middleware and services
- [x] 22-07: Refactor entity, review, status, and remaining endpoints
- [x] 22-07b: Refactor admin and specialized endpoints to use middleware
- [x] 22-08: Delete database-functions.R after migration verification
- [x] 22-09: Comprehensive endpoint verification and human approval

**Details:**
- require_auth filter with AUTH_ALLOWLIST for public endpoints
- User context attached to request (user_id, user_role, user_name)
- 7 service layers (auth, entity, review, approval, user, status, search)
- database-functions.R eliminated (1,226-line god file decomposed)
- All endpoints verified with curl and Playwright testing

### Phase 23: OMIM Migration

**Goal:** OMIM annotations work without genemap2 dependency, with OMIM disease names preserved
**Depends on:** Phase 22 (Service Layer & Middleware)
**Plans:** 5 plans

Plans:
- [x] 23-01: Create JAX API validation script and document rate limits
- [x] 23-02: Create omim-functions.R (mim2gene parsing, JAX API, validation)
- [x] 23-03: Create mondo-functions.R (SSSOM parsing, MONDO mappings)
- [x] 23-04: Integrate new functions into ontology update, create async endpoint
- [x] 23-05: OLS4 API integration and frontend MONDO display

**Details:**
- mim2gene.txt integration for MIM-to-gene mappings
- JAX ontology API for OMIM disease names (50ms rate limiting)
- MONDO SSSOM mappings for cross-ontology equivalence
- ManageAnnotations admin view with async job polling UI
- Entity.vue with MONDO equivalence display
- Deprecated OMIM detection and review workflow

### Phase 24: Versioning, Pagination & Cleanup

**Goal:** Production-ready API with versioning, pagination, and clean codebase
**Depends on:** Phase 23 (OMIM Migration)
**Plans:** 7 plans

Plans:
- [x] 24-01: Create /api/version endpoint with git commit integration
- [x] 24-02: Create pagination safety wrapper with max page_size enforcement
- [x] 24-03: Extend pagination to user and re_review endpoints
- [x] 24-04: Extend pagination to list and status endpoints
- [x] 24-05: Resolve TODO comments and fix identified bugs
- [x] 24-06: Reduce lintr issues to zero
- [x] 24-07: Create integration tests for new features

**Details:**
- /api/version endpoint returning semantic version and last commit
- Pagination with 500-item max (PAGINATION_MAX_SIZE)
- Cursor-based pagination on user/table, re_review/table, list endpoints
- 0 TODO comments (from 29)
- 0 lintr issues (from 1,240)
- 24 integration tests for version, pagination, async

---

## Milestone Summary

**Key Decisions:**
- Use sodium::password_store for Argon2id (OWASP recommended over bcrypt)
- Progressive password migration via dual-verification (zero-downtime)
- 8-worker mirai daemon pool for async jobs
- Pre-fetch data before job creation (pool cross-process workaround)
- require_auth middleware with AUTH_ALLOWLIST pattern
- Service layer uses dependency injection (pool as parameter)
- mim2gene.txt + JAX API replaces genemap2

**Issues Resolved:**
- 66 SQL injection vulnerabilities fixed
- Plaintext password storage eliminated
- 34 dbConnect calls eliminated (all use pool now)
- OMIM annotation update restored (genemap2 workaround)
- 1,226-line database-functions.R god file decomposed
- 1,240 lintr issues resolved
- 29 TODO comments resolved

**Issues Deferred:**
- VER-03: URL path versioning (/api/v1/) - Needs only when v2 API exists
- VER-04: Version displayed in frontend - Low priority

**Technical Debt Incurred:**
- Job workers cannot access pool (pre-fetch workaround functional)
- OMIM/MONDO functions worker-sourced, not global (works for async use case)
- entity_endpoints.R uses old pagination (pre-existing, not in scope)

---

*For current project status, see .planning/ROADMAP.md*
