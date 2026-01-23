# Requirements: SysNDD v4 Backend Overhaul

**Defined:** 2026-01-23
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v4 Requirements

Requirements for v4 Backend Overhaul. Each maps to roadmap phases.

### Foundation (R Upgrade)

- [ ] **FOUND-01**: R upgraded from 4.1.2 to 4.4.3
- [ ] **FOUND-02**: Matrix package upgraded to 1.6.3+ for ABI compatibility
- [ ] **FOUND-03**: Docker base image updated to rocker/r-ver:4.4.3
- [ ] **FOUND-04**: P3M URLs updated from focal to jammy
- [ ] **FOUND-05**: Fresh renv.lock created on R 4.4.x
- [ ] **FOUND-06**: FactoMineR/lme4 2022 snapshot workaround removed from Dockerfile

### Security

- [ ] **SEC-01**: All 66 SQL injection vulnerabilities fixed with parameterized queries (dbBind)
- [ ] **SEC-02**: Password hashing implemented with sodium/Argon2id
- [ ] **SEC-03**: Dual-hash verification for existing user migration
- [ ] **SEC-04**: Logging sanitized to exclude passwords, tokens, and sensitive data
- [ ] **SEC-05**: bcrypt::checkpw comparison removed from authentication_endpoints.R
- [ ] **SEC-06**: core/errors.R created with RFC 7807 error format helpers
- [ ] **SEC-07**: Response builder helpers (response_success, response_error) created

### Async/Non-blocking

- [ ] **ASYNC-01**: mirai package added to project dependencies
- [ ] **ASYNC-02**: Connection pool properly configured for async operations
- [ ] **ASYNC-03**: Ontology update endpoint made async/non-blocking
- [ ] **ASYNC-04**: Clustering analysis endpoint made async/non-blocking
- [ ] **ASYNC-05**: Job status polling endpoint implemented
- [ ] **ASYNC-06**: HTTP 202 Accepted pattern for long-running operations

### OMIM Data Migration

- [ ] **OMIM-01**: mim2gene.txt integration implemented (replaces genemap2 dependency)
- [ ] **OMIM-02**: MONDO integration enhanced for disease name lookup
- [ ] **OMIM-03**: HPO annotation files integrated for phenotype links
- [ ] **OMIM-04**: Data completeness validation before database writes
- [ ] **OMIM-05**: ManageAnnotations view updated for new data sources
- [ ] **OMIM-06**: Fallback strategy for missing disease names documented

### Architecture Refactoring

- [ ] **ARCH-01**: Database access layer created (execute_query, fetch_all helpers)
- [ ] **ARCH-02**: Connection pool used consistently (17 dbConnect duplications eliminated)
- [ ] **ARCH-03**: Entity repository created (domain-specific database operations)
- [ ] **ARCH-04**: Review repository created
- [ ] **ARCH-05**: Status repository created
- [ ] **ARCH-06**: Publication repository created
- [ ] **ARCH-07**: Phenotype repository created
- [ ] **ARCH-08**: Ontology repository created
- [ ] **ARCH-09**: User repository created
- [ ] **ARCH-10**: Hash repository created
- [ ] **ARCH-11**: Authentication middleware created (require_auth, require_role filters)
- [ ] **ARCH-12**: 12 duplicated auth checks consolidated into middleware
- [ ] **ARCH-13**: Entity service layer created
- [ ] **ARCH-14**: Review service layer created
- [ ] **ARCH-15**: Approval service layer created
- [ ] **ARCH-16**: Auth service layer created
- [ ] **ARCH-17**: Search service layer created
- [ ] **ARCH-18**: database-functions.R decomposed (1,234 line god file eliminated)
- [ ] **ARCH-19**: Response patterns standardized (~100 inconsistent patterns fixed)
- [ ] **ARCH-20**: Global mutable state reduced (15 `<<-` usages minimized)

### Pagination

- [ ] **PAG-01**: Cursor-based pagination standardized for all tabular endpoints
- [ ] **PAG-02**: Configurable page_size with max limit (100-500)
- [ ] **PAG-03**: Stable composite key sorting implemented
- [ ] **PAG-04**: API documentation updated with pagination details
- [ ] **PAG-05**: Default pagination settings provided for backward compatibility

### API Versioning

- [ ] **VER-01**: /api/version endpoint returns semantic version and last commit
- [ ] **VER-02**: Version displayed in Swagger UI
- [ ] **VER-03**: URL path versioning implemented (/api/v1/)
- [ ] **VER-04**: Version displayed in frontend

### Error Handling

- [ ] **ERR-01**: RFC 7807 error format implemented across all endpoints
- [ ] **ERR-02**: HTTP status codes consistent (4xx operational, 5xx programmer errors)
- [ ] **ERR-03**: Error handler middleware created
- [ ] **ERR-04**: Swallowed errors eliminated (tryCatch with proper handling)

### Quality Assurance

- [ ] **QA-01**: Each endpoint verified with curl BEFORE refactoring
- [ ] **QA-02**: Each endpoint verified with curl AFTER refactoring
- [ ] **QA-03**: Response comparison against production API (https://sysndd.dbmr.unibe.ch/API)
- [ ] **QA-04**: Regression testing for all modified endpoints
- [ ] **QA-05**: Expert senior engineer refactoring standards applied

### Testing & Cleanup

- [ ] **TEST-01**: 30 TODO comments resolved across codebase
- [ ] **TEST-02**: 1240 lintr issues addressed
- [ ] **TEST-03**: API integration tests for refactored endpoints
- [ ] **TEST-04**: Async operation tests
- [ ] **TEST-05**: Password migration tests

## Future Requirements

Deferred to v5. Tracked but not in current roadmap.

### CI/CD

- **CI-01**: GitHub Actions pipeline for automated testing
- **CI-02**: Trivy security scanning in CI
- **CI-03**: Automated deployment pipeline

### Frontend Testing

- **FTEST-01**: Expanded frontend test coverage (40-50%)
- **FTEST-02**: Vue component TypeScript conversion

### Additional Integration

- **INT-01**: HTTP endpoint integration tests (full coverage)
- **INT-02**: Load testing for async operations

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| R/Plumber replacement | Keeping current stack, modernizing instead |
| Database schema changes | MySQL 8.0.40 works well |
| plumber2 migration | Too new (0.1.0), stick with plumber v1.x |
| bcrypt package | sodium with Argon2id is OWASP 2025 recommended |
| OMIM API license | mim2gene.txt + MONDO/HPO provides data for free |
| Full test coverage | Target 80%, not 100% (diminishing returns) |
| Server-side rendering | SPA approach sufficient |
| PWA features | Keep existing |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 18 | Pending |
| FOUND-02 | Phase 18 | Pending |
| FOUND-03 | Phase 18 | Pending |
| FOUND-04 | Phase 18 | Pending |
| FOUND-05 | Phase 18 | Pending |
| FOUND-06 | Phase 18 | Pending |
| SEC-01 | Phase 19 | Pending |
| SEC-02 | Phase 19 | Pending |
| SEC-03 | Phase 19 | Pending |
| SEC-04 | Phase 19 | Pending |
| SEC-05 | Phase 19 | Pending |
| SEC-06 | Phase 19 | Pending |
| SEC-07 | Phase 19 | Pending |
| ASYNC-01 | Phase 20 | Pending |
| ASYNC-02 | Phase 20 | Pending |
| ASYNC-03 | Phase 20 | Pending |
| ASYNC-04 | Phase 20 | Pending |
| ASYNC-05 | Phase 20 | Pending |
| ASYNC-06 | Phase 20 | Pending |
| ARCH-01 | Phase 21 | Pending |
| ARCH-02 | Phase 21 | Pending |
| ARCH-03 | Phase 21 | Pending |
| ARCH-04 | Phase 21 | Pending |
| ARCH-05 | Phase 21 | Pending |
| ARCH-06 | Phase 21 | Pending |
| ARCH-07 | Phase 21 | Pending |
| ARCH-08 | Phase 21 | Pending |
| ARCH-09 | Phase 21 | Pending |
| ARCH-10 | Phase 21 | Pending |
| ARCH-11 | Phase 22 | Pending |
| ARCH-12 | Phase 22 | Pending |
| ARCH-13 | Phase 22 | Pending |
| ARCH-14 | Phase 22 | Pending |
| ARCH-15 | Phase 22 | Pending |
| ARCH-16 | Phase 22 | Pending |
| ARCH-17 | Phase 22 | Pending |
| ARCH-18 | Phase 22 | Pending |
| ARCH-19 | Phase 22 | Pending |
| ARCH-20 | Phase 22 | Pending |
| OMIM-01 | Phase 23 | Pending |
| OMIM-02 | Phase 23 | Pending |
| OMIM-03 | Phase 23 | Pending |
| OMIM-04 | Phase 23 | Pending |
| OMIM-05 | Phase 23 | Pending |
| OMIM-06 | Phase 23 | Pending |
| PAG-01 | Phase 24 | Pending |
| PAG-02 | Phase 24 | Pending |
| PAG-03 | Phase 24 | Pending |
| PAG-04 | Phase 24 | Pending |
| PAG-05 | Phase 24 | Pending |
| VER-01 | Phase 24 | Pending |
| VER-02 | Phase 24 | Pending |
| VER-03 | Phase 24 | Pending |
| VER-04 | Phase 24 | Pending |
| ERR-01 | Phase 19 | Pending |
| ERR-02 | Phase 19 | Pending |
| ERR-03 | Phase 19 | Pending |
| ERR-04 | Phase 19 | Pending |
| TEST-01 | Phase 24 | Pending |
| TEST-02 | Phase 24 | Pending |
| TEST-03 | Phase 24 | Pending |
| TEST-04 | Phase 24 | Pending |
| TEST-05 | Phase 24 | Pending |

**Coverage:**
- v4 requirements: 66 total
- Mapped to phases: 66
- Unmapped: 0 ✓

## Reference APIs

**Production API:** https://sysndd.dbmr.unibe.ch/API
- Use for response comparison during refactoring
- Verify endpoint behavior matches production

**Verification Protocol:**
1. curl endpoint BEFORE refactoring
2. Save response for comparison
3. Refactor with expert senior engineer standards
4. curl endpoint AFTER refactoring
5. Compare responses for regressions
6. Test edge cases and error conditions

---
*Requirements defined: 2026-01-23*
*Last updated: 2026-01-23 after initial definition*
