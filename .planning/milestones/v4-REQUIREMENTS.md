# Requirements Archive: v4.0 Backend Overhaul

**Archived:** 2026-01-24
**Status:** ✅ SHIPPED

This is the archived requirements specification for v4.0.
For current requirements, see `.planning/REQUIREMENTS.md` (created for next milestone).

---

# Requirements: SysNDD v4 Backend Overhaul

**Defined:** 2026-01-23
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v4 Requirements

Requirements for v4 Backend Overhaul. Each maps to roadmap phases.

### Foundation (R Upgrade)

- [x] **FOUND-01**: R upgraded from 4.1.2 to 4.4.3 ✓
- [x] **FOUND-02**: Matrix package upgraded to 1.6.3+ for ABI compatibility ✓
- [x] **FOUND-03**: Docker base image updated to rocker/r-ver:4.4.3 ✓
- [x] **FOUND-04**: P3M URLs updated from focal to noble ✓
- [x] **FOUND-05**: Fresh renv.lock created on R 4.4.x ✓
- [x] **FOUND-06**: FactoMineR/lme4 2022 snapshot workaround removed from Dockerfile ✓

### Security

- [x] **SEC-01**: All 66 SQL injection vulnerabilities fixed with parameterized queries (dbBind) ✓
- [x] **SEC-02**: Password hashing implemented with sodium/Argon2id for new registrations ✓
- [x] **SEC-03**: Progressive re-hash on login for existing plaintext passwords ✓
- [x] **SEC-04**: Logging sanitized to exclude passwords, tokens, and sensitive data ✓
- [x] **SEC-05**: Plaintext password comparison removed from authentication_endpoints.R ✓
- [x] **SEC-05a**: Password change endpoint updated to support both formats ✓
- [x] **SEC-06**: core/errors.R created with RFC 9457 error format helpers ✓
- [x] **SEC-07**: Response builder helpers (response_success, response_error) created ✓

### Async/Non-blocking

- [x] **ASYNC-01**: mirai package added to project dependencies ✓
- [x] **ASYNC-02**: Connection pool properly configured for async operations ✓
- [x] **ASYNC-03**: Ontology update endpoint made async/non-blocking ✓
- [x] **ASYNC-04**: Clustering analysis endpoint made async/non-blocking ✓
- [x] **ASYNC-05**: Job status polling endpoint implemented ✓
- [x] **ASYNC-06**: HTTP 202 Accepted pattern for long-running operations ✓

### OMIM Data Migration

- [x] **OMIM-01**: mim2gene.txt integration for MIM-to-gene mappings ✓
- [x] **OMIM-02**: JAX ontology API integration for OMIM disease names ✓
- [x] **OMIM-03**: OMIM disease names preserved (NOT replaced by MONDO names) ✓
- [x] **OMIM-04**: Data completeness validation before database writes ✓
- [x] **OMIM-05**: ManageAnnotations view updated for new data sources ✓
- [x] **OMIM-06**: Fallback strategy for missing disease names documented ✓

### MONDO Equivalence (Optional Enhancement)

- [x] **MONDO-01**: MONDO-to-OMIM equivalence mapping stored ✓
- [x] **MONDO-02**: Curation interface to view/assign MONDO equivalents ✓
- [x] **MONDO-03**: Existing MONDO integration preserved for cross-ontology queries ✓

### Architecture Refactoring

- [x] **ARCH-01**: Database access layer created (execute_query, fetch_all helpers) ✓
- [x] **ARCH-02**: Connection pool used consistently (34 dbConnect duplications eliminated) ✓
- [x] **ARCH-03**: Entity repository created (domain-specific database operations) ✓
- [x] **ARCH-04**: Review repository created ✓
- [x] **ARCH-05**: Status repository created ✓
- [x] **ARCH-06**: Publication repository created ✓
- [x] **ARCH-07**: Phenotype repository created ✓
- [x] **ARCH-08**: Ontology repository created ✓
- [x] **ARCH-09**: User repository created ✓
- [x] **ARCH-10**: Hash repository created ✓
- [x] **ARCH-11**: Authentication middleware created (require_auth, require_role filters) ✓
- [x] **ARCH-12**: 12 duplicated auth checks consolidated into middleware ✓
- [x] **ARCH-13**: Entity service layer created ✓
- [x] **ARCH-14**: Review service layer created ✓
- [x] **ARCH-15**: Approval service layer created ✓
- [x] **ARCH-16**: Auth service layer created ✓
- [x] **ARCH-17**: Search service layer created ✓
- [x] **ARCH-18**: database-functions.R decomposed (1,226 line god file eliminated) ✓
- [x] **ARCH-19**: Response patterns standardized (~100 inconsistent patterns fixed) ✓
- [x] **ARCH-20**: Global mutable state reduced (<<- usages minimized) ✓

### Pagination

- [x] **PAG-01**: Cursor-based pagination standardized for all tabular endpoints ✓
- [x] **PAG-02**: Configurable page_size with max limit (500) ✓
- [x] **PAG-03**: Stable composite key sorting implemented ✓
- [x] **PAG-04**: API documentation updated with pagination details ✓
- [x] **PAG-05**: Default pagination settings provided for backward compatibility ✓

### API Versioning

- [x] **VER-01**: /api/version endpoint returns semantic version and last commit ✓
- [x] **VER-02**: Version displayed in Swagger UI ✓
- [ ] **VER-03**: URL path versioning implemented (/api/v1/) ⏸ DEFERRED to v5
- [ ] **VER-04**: Version displayed in frontend ⏸ DEFERRED to v5

### Error Handling

- [x] **ERR-01**: RFC 9457 error format implemented across all endpoints ✓
- [x] **ERR-02**: HTTP status codes consistent (4xx operational, 5xx programmer errors) ✓
- [x] **ERR-03**: Error handler middleware created ✓
- [x] **ERR-04**: Swallowed errors eliminated (tryCatch with proper handling) ✓

### Quality Assurance

- [x] **QA-01**: Each endpoint verified with curl BEFORE refactoring ✓
- [x] **QA-02**: Each endpoint verified with curl AFTER refactoring ✓
- [x] **QA-03**: Response comparison against production API ✓
- [x] **QA-04**: Regression testing for all modified endpoints ✓
- [x] **QA-05**: Expert senior engineer refactoring standards applied ✓

### Testing & Cleanup

- [x] **TEST-01**: 29 TODO comments resolved across codebase (0 remaining) ✓
- [x] **TEST-02**: 1,240 lintr issues addressed (0 remaining) ✓
- [x] **TEST-03**: API integration tests for refactored endpoints ✓
- [x] **TEST-04**: Async operation tests ✓
- [x] **TEST-05**: Password migration tests ✓

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 18 | Complete |
| FOUND-02 | Phase 18 | Complete |
| FOUND-03 | Phase 18 | Complete |
| FOUND-04 | Phase 18 | Complete |
| FOUND-05 | Phase 18 | Complete |
| FOUND-06 | Phase 18 | Complete |
| SEC-01 | Phase 19 | Complete |
| SEC-02 | Phase 19 | Complete |
| SEC-03 | Phase 19 | Complete |
| SEC-04 | Phase 19 | Complete |
| SEC-05 | Phase 19 | Complete |
| SEC-06 | Phase 19 | Complete |
| SEC-07 | Phase 19 | Complete |
| ERR-01 | Phase 19 | Complete |
| ERR-02 | Phase 19 | Complete |
| ERR-03 | Phase 19 | Complete |
| ERR-04 | Phase 19 | Complete |
| ASYNC-01 | Phase 20 | Complete |
| ASYNC-02 | Phase 20 | Complete |
| ASYNC-03 | Phase 20 | Complete |
| ASYNC-04 | Phase 20 | Complete |
| ASYNC-05 | Phase 20 | Complete |
| ASYNC-06 | Phase 20 | Complete |
| ARCH-01 | Phase 21 | Complete |
| ARCH-02 | Phase 21 | Complete |
| ARCH-03 | Phase 21 | Complete |
| ARCH-04 | Phase 21 | Complete |
| ARCH-05 | Phase 21 | Complete |
| ARCH-06 | Phase 21 | Complete |
| ARCH-07 | Phase 21 | Complete |
| ARCH-08 | Phase 21 | Complete |
| ARCH-09 | Phase 21 | Complete |
| ARCH-10 | Phase 21 | Complete |
| ARCH-11 | Phase 22 | Complete |
| ARCH-12 | Phase 22 | Complete |
| ARCH-13 | Phase 22 | Complete |
| ARCH-14 | Phase 22 | Complete |
| ARCH-15 | Phase 22 | Complete |
| ARCH-16 | Phase 22 | Complete |
| ARCH-17 | Phase 22 | Complete |
| ARCH-18 | Phase 22 | Complete |
| ARCH-19 | Phase 22 | Complete |
| ARCH-20 | Phase 22 | Complete |
| QA-01 | Phase 22 | Complete |
| QA-02 | Phase 22 | Complete |
| QA-03 | Phase 22 | Complete |
| QA-04 | Phase 22 | Complete |
| QA-05 | Phase 22 | Complete |
| OMIM-01 | Phase 23 | Complete |
| OMIM-02 | Phase 23 | Complete |
| OMIM-03 | Phase 23 | Complete |
| OMIM-04 | Phase 23 | Complete |
| OMIM-05 | Phase 23 | Complete |
| OMIM-06 | Phase 23 | Complete |
| MONDO-01 | Phase 23 | Complete |
| MONDO-02 | Phase 23 | Complete |
| MONDO-03 | Phase 23 | Complete |
| PAG-01 | Phase 24 | Complete |
| PAG-02 | Phase 24 | Complete |
| PAG-03 | Phase 24 | Complete |
| PAG-04 | Phase 24 | Complete |
| PAG-05 | Phase 24 | Complete |
| VER-01 | Phase 24 | Complete |
| VER-02 | Phase 24 | Complete |
| VER-03 | Phase 24 | Deferred |
| VER-04 | Phase 24 | Deferred |
| TEST-01 | Phase 24 | Complete |
| TEST-02 | Phase 24 | Complete |
| TEST-03 | Phase 24 | Complete |
| TEST-04 | Phase 24 | Complete |
| TEST-05 | Phase 24 | Complete |

**Coverage:**
- v4 requirements: 71 total
- Satisfied: 69 (97%)
- Deferred: 2 (VER-03, VER-04)

---

## Milestone Summary

**Shipped:** 69 of 71 v4 requirements

**Adjusted:** None - all requirements shipped as specified

**Dropped:** None

**Deferred to v5:**
- VER-03: URL path versioning (/api/v1/) - Requires dual-path mounting, needed only when v2 API exists
- VER-04: Version displayed in frontend - Low priority, depends on /api/version

---
*Archived: 2026-01-24 as part of v4.0 milestone completion*
