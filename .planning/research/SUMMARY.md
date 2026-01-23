# Research Summary: v4 Backend Overhaul

**Project:** SysNDD API Backend Modernization
**Synthesized:** 2026-01-23
**Overall Confidence:** HIGH

---

## Executive Summary

The SysNDD v4 Backend Overhaul is a comprehensive modernization of an R/Plumber API serving a neurodevelopmental disorders database. The current codebase suffers from **66 SQL injection vulnerabilities**, **plaintext password storage**, a **1,234-line god file** (database-functions.R), and outdated dependencies (R 4.1.2). The research consensus is clear: this is primarily a **security and architecture remediation project** with async capabilities as a secondary goal.

The recommended approach follows a strict phase order: **Foundation first** (R upgrade, renv migration), then **Security** (SQL injection elimination, password hashing), then **Async** (mirai + promises for non-blocking operations), then **Architecture refactoring** (repository pattern, service layer), and finally **OMIM migration** (mim2gene.txt + MONDO/HPO). Attempting async or refactoring before fixing security creates false confidence and leaves attack vectors open.

Key risks center on the R 4.1.2 to 4.4.x upgrade (Matrix/lme4 ABI breaking changes) and the password migration (dual-hash verification required to avoid user lockout). The OMIM migration has medium confidence because mim2gene.txt lacks disease names, requiring additional data source integration. The architecture patterns (repository, service layer, middleware) are well-documented in R/Plumber contexts and present low risk if executed incrementally.

---

## Key Findings

### From STACK.md

| Technology | Version | Rationale |
|------------|---------|-----------|
| **R** | 4.4.3 | Security patches, Matrix bundled, removes P3M snapshot workaround |
| **mirai** | >= 2.0.0 | Purpose-built for Plumber async, zero-latency promises |
| **sodium** | >= 1.4.0 | Argon2id hashing (OWASP 2025 #1 recommendation), libsodium-dev already in Dockerfile |
| **DBI dbBind()** | existing | Parameterized queries to eliminate 66 SQL injection points |
| **mim2gene.txt** | FREE | Replaces genemap2 dependency, no OMIM license required |
| **MONDO + HPO** | existing | Disease names and phenotype mappings (already partially integrated) |

**Critical version requirements:**
- Matrix >= 1.6.3 before R upgrade (ABI compatibility with lme4)
- rocker/r-ver:4.4.3 Docker base image
- P3M URL change: focal to jammy

**What NOT to add:** plumber2 (too new), bcrypt package (sodium superior), future for Plumber async (mirai is better), OMIM API license (mim2gene.txt is free).

### From FEATURES.md

**Table Stakes (must-have):**
1. SQL injection prevention via parameterized queries - 66 points require conversion
2. Password hashing with Argon2id/bcrypt - replace plaintext storage
3. Pagination standardization - cursor-based for 4200+ entity records
4. RFC 7807 error format - consistent error handling across all endpoints
5. API versioning - URL path versioning (/api/v1/) per GitHub #21
6. Database access layer - eliminate 17 direct dbConnect calls

**Differentiators (should-have):**
1. Async non-blocking for ontology updates, clustering analysis
2. OMIM data source migration to free alternatives
3. Authentication middleware refactoring (12 duplicated auth checks)
4. Response builder helpers for consistent API responses

**Anti-features (avoid):**
- Synchronous long-running operations (>30 seconds)
- Partial security fixes (inconsistent patterns worse than none)
- Custom error formats per endpoint
- Pagination without limits (DoS vector)
- Mixing dbConnect() with pool (connection leaks)

### From ARCHITECTURE.md

**Target Architecture:**
```
core/           # errors.R, response.R, middleware.R
repositories/   # 8 domain repositories (entity, review, status, publication, phenotype, ontology, user, hash)
services/       # 5 business logic services (entity, review, approval, auth, search)
middleware/     # cors.R, auth.R, logging.R, validation.R, error_handler.R
endpoints/      # Thin controllers delegating to services
```

**Key Patterns:**
1. **Repository Pattern** - encapsulate all database access, parameterized queries, inject pool
2. **Service Layer** - business logic isolation, workflow orchestration, testable without HTTP
3. **Middleware Chain** - cross-cutting concerns (auth, validation, logging, errors)
4. **Dependency Injection** - factory functions returning closures, avoid R6 over-engineering
5. **Response Builder** - consistent API responses via helper functions

**Current Problems:**
- 17 direct dbConnect calls bypassing pool
- 15 global mutable state uses (`<<-`)
- 66 SQL injection vulnerabilities
- ~100 inconsistent error patterns
- 12 duplicated auth checks

### From PITFALLS.md

**Critical Pitfalls:**
1. **Matrix ABI breaking changes** (Phase 1) - upgrade Matrix to 1.6.3+ BEFORE R upgrade
2. **SQL injection via paste0()** (Phase 2) - all 66 points must use dbBind() or glue_sql()
3. **Plaintext password lockout** (Phase 2) - dual-hash verification required during transition
4. **future::future() blocking** (Phase 3) - use promises::future_promise() or mirai, not raw future
5. **renv restore failures** (Phase 1) - create fresh renv.lock on R 4.4.x, test in Docker first

**Moderate Pitfalls:**
- God file refactoring creates circular dependencies (map dependencies first)
- OMIM genemap2 data structure changes (mim2gene.txt lacks disease names)
- Connection pool exhaustion during async (always use pool, never standalone dbConnect)
- Sodium vs bcrypt prefix incompatibility (document algorithm choice)

**Pre-Phase Checklist:**
- renv.lock tested on R 4.4.x in Docker
- Matrix 1.6.3+ confirmed compatible
- Test database isolated from production
- Logging sanitization in place
- Production database backup

---

## Implications for Roadmap

### Recommended Phase Structure

**Phase 1: Foundation (Week 1)**
- Upgrade R 4.1.2 to 4.4.3
- Upgrade Matrix to 1.6.3+, remove P3M snapshot workaround
- Create fresh renv.lock on R 4.4.x
- Test Docker build with new base image
- **Rationale:** Everything depends on working R environment. Must complete before code changes.
- **Delivers:** Stable R 4.4.x environment, updated dependencies
- **Pitfalls to avoid:** #1 (Matrix ABI), #5 (renv restore)

**Phase 2: Security Hardening (Weeks 2-3)**
- Fix all 66 SQL injection vulnerabilities with parameterized queries
- Implement password hashing (sodium/Argon2id)
- Add dual-hash verification for migration
- Create core/errors.R and response builders
- Sanitize logging to exclude passwords/tokens
- **Rationale:** Security must come before features. Unblocks safe development.
- **Delivers:** No SQL injection, hashed passwords, consistent error handling
- **Features:** SQL injection prevention, password hashing, RFC 7807 errors
- **Pitfalls to avoid:** #2 (SQL injection), #3 (password lockout), #9 (algorithm prefix), #12 (logging sensitive data)

**Phase 3: Async/Non-blocking (Weeks 4-5)**
- Add mirai package
- Configure connection pool properly
- Implement async for ontology updates
- Implement async for clustering analysis
- Add job status endpoint pattern
- **Rationale:** Requires security foundation. Addresses timeout/blocking issues.
- **Delivers:** Non-blocking admin operations, improved responsiveness
- **Features:** Async API patterns, job queue pattern
- **Pitfalls to avoid:** #4 (future blocking), #8 (pool exhaustion)

**Phase 4: Architecture Refactoring (Weeks 6-8)**
- Create repository layer (8 repositories)
- Create service layer (5 services)
- Extract middleware (auth, CORS, logging, validation)
- Refactor endpoints to thin controllers
- Remove database-functions.R (god file decomposition)
- Standardize response formats
- **Rationale:** Requires async foundation. Large effort with dependency graph.
- **Delivers:** DRY/KISS/SOLID compliant codebase, testable architecture
- **Features:** Database access layer, auth middleware, response builders
- **Pitfalls to avoid:** #6 (circular dependencies), #10 (inconsistent errors)

**Phase 5: OMIM Migration (Weeks 9-10)**
- Implement mim2gene.txt integration
- Enhance MONDO integration for disease names
- Add HPO annotation files for phenotype links
- Validate data completeness before writes
- **Rationale:** Depends on async (ontology updates are long-running). Lower priority than security.
- **Delivers:** Working OMIM annotation without license requirement
- **Features:** OMIM data source migration
- **Pitfalls to avoid:** #7 (empty disease names)

**Phase 6: API Versioning and Cleanup (Week 11)**
- Add /api/version endpoint
- Implement URL path versioning (/api/v1/)
- Remove dead code
- Add comprehensive test coverage (target: 80%)
- Performance testing
- **Rationale:** Labels the stable state after all other work complete.
- **Delivers:** Versioned API, clean codebase
- **Features:** API versioning, pagination standardization

### Research Flags

| Phase | Needs Research? | Notes |
|-------|-----------------|-------|
| Phase 1 (Foundation) | NO | Standard patterns, official docs available |
| Phase 2 (Security) | NO | Well-documented DBI patterns, OWASP guidelines |
| Phase 3 (Async) | MAYBE | mirai + Plumber integration has good docs, but test job queue pattern |
| Phase 4 (Refactoring) | YES | R-specific service layer patterns less documented, dependency mapping needed |
| Phase 5 (OMIM) | YES | mim2gene.txt field mapping, JAX API integration need validation |
| Phase 6 (Versioning) | NO | Standard API patterns |

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official R/Plumber docs, CRAN packages, verified versions |
| Features | HIGH | Official docs, IETF standards (RFC 7807), OWASP guidelines |
| Architecture | HIGH | Official Plumber filter/routing docs, verified community patterns |
| Pitfalls | HIGH | Codebase analysis verified, GitHub issues referenced |

### Gaps to Address

1. **OMIM disease name source** - mim2gene.txt only provides gene mappings, disease names need MONDO/HPO/JAX integration. Validate that all required data is available before starting Phase 5.

2. **mirai + Plumber production testing** - mirai is purpose-built for Plumber but relatively new. Test async patterns under load before full implementation.

3. **Service layer patterns in R** - Repository pattern is well-documented, but service layer is adapted from OOP languages. May need adjustment for R idioms.

4. **Existing password count** - Need to assess how many users have plaintext passwords and plan migration timeline. Consider forced password reset deadline.

5. **Job queue persistence** - For long-running admin operations, consider whether job status needs database persistence or in-memory is sufficient.

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1: Foundation | 1 week | Week 1 |
| Phase 2: Security | 2 weeks | Weeks 2-3 |
| Phase 3: Async | 2 weeks | Weeks 4-5 |
| Phase 4: Refactoring | 3 weeks | Weeks 6-8 |
| Phase 5: OMIM | 2 weeks | Weeks 9-10 |
| Phase 6: Versioning | 1 week | Week 11 |

**Total estimate:** 10-12 weeks

---

## Sources

### Official Documentation (HIGH Confidence)
- [Plumber Official Documentation](https://www.rplumber.io/)
- [DBI Parameterized Queries](https://dbi.r-dbi.org/articles/DBI-advanced.html)
- [Posit: Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)
- [mirai Package Documentation](https://mirai.r-lib.org/)
- [sodium R Package CRAN](https://cran.r-project.org/web/packages/sodium/sodium.pdf)
- [R 4.4.0 Release Notes](https://stat.ethz.ch/pipermail/r-announce/2024/000701.html)
- [RFC 7807 (IETF)](https://datatracker.ietf.org/doc/html/rfc7807)
- [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

### Data Sources
- [OMIM Downloads (mim2gene.txt)](https://www.omim.org/downloads/)
- [MONDO Disease Ontology](https://mondo.monarchinitiative.org/)
- [Human Phenotype Ontology](https://hpo.jax.org/)
- [Rocker r-ver Docker Images](https://hub.docker.com/r/rocker/r-ver)

### Community Resources (MEDIUM Confidence)
- [lme4 Matrix compatibility issue #763](https://github.com/lme4/lme4/issues/763)
- [renv restore issues #750, #1714](https://github.com/rstudio/renv/issues)
- [Plumber async filters issue #907](https://github.com/rstudio/plumber/issues/907)
- [Structured Errors in Plumber APIs](https://unconj.ca/blog/structured-errors-in-plumber-apis.html)

### Codebase Analysis
- `api/functions/database-functions.R` (1,234 lines, 66 SQL injection points)
- `api/endpoints/authentication_endpoints.R` (plaintext password comparison)
- `api/Dockerfile` (R 4.1.2, P3M 2022-01-03 snapshot workaround)
- `api/renv.lock` (Matrix 1.4-0, incomplete package tracking)

---

*Research synthesis completed: 2026-01-23*
*Synthesizer: GSD Research Synthesizer*
