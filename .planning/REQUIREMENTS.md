# Requirements: SysNDD v4 Backend Overhaul

**Defined:** 2026-01-23
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v4 Requirements

Requirements for v4 Backend Overhaul. Each maps to roadmap phases.

### Foundation (R Upgrade)

- [x] **FOUND-01**: R upgraded from 4.1.2 to 4.4.3
- [x] **FOUND-02**: Matrix package upgraded to 1.6.3+ for ABI compatibility
- [x] **FOUND-03**: Docker base image updated to rocker/r-ver:4.4.3
- [x] **FOUND-04**: P3M URLs updated from focal to jammy
- [x] **FOUND-05**: Fresh renv.lock created on R 4.4.x
- [x] **FOUND-06**: FactoMineR/lme4 2022 snapshot workaround removed from Dockerfile

### Security

- [x] **SEC-01**: All 66 SQL injection vulnerabilities fixed with parameterized queries (dbBind)
- [x] **SEC-02**: Password hashing implemented with sodium/Argon2id for new registrations
- [x] **SEC-03**: Progressive re-hash on login for existing plaintext passwords (production-compatible)
  - Detect hash type by prefix (`$argon2` or `$7$` = hashed, else = plaintext)
  - If plaintext: verify with direct comparison, then immediately hash and update DB
  - If hashed: verify with `sodium::password_verify()`
  - No schema change needed (same `password` column stores both formats)
  - Users transparently upgraded on next login
- [x] **SEC-04**: Logging sanitized to exclude passwords, tokens, and sensitive data
- [x] **SEC-05**: Plaintext password comparison removed from authentication_endpoints.R:153
- [x] **SEC-05a**: Password change endpoint (user_endpoints.R:426) updated to support both formats
- [x] **SEC-06**: core/errors.R created with RFC 7807 error format helpers
- [x] **SEC-07**: Response builder helpers (response_success, response_error) created

### Async/Non-blocking

- [x] **ASYNC-01**: mirai package added to project dependencies ✓
- [x] **ASYNC-02**: Connection pool properly configured for async operations ✓
- [x] **ASYNC-03**: Ontology update endpoint made async/non-blocking ✓
- [x] **ASYNC-04**: Clustering analysis endpoint made async/non-blocking ✓
- [x] **ASYNC-05**: Job status polling endpoint implemented ✓
- [x] **ASYNC-06**: HTTP 202 Accepted pattern for long-running operations ✓

### OMIM Data Migration

- [ ] **OMIM-01**: mim2gene.txt integration for MIM-to-gene mappings (filtered for phenotype entries)
- [ ] **OMIM-02**: JAX ontology API integration for OMIM disease names
  - Endpoint: `https://ontology.jax.org/api/network/annotation/OMIM:{mim_number}`
  - Returns disease name, description, phenotypes, genes
  - Caching strategy for API responses (rate limiting consideration)
- [ ] **OMIM-03**: OMIM disease names preserved (NOT replaced by MONDO names)
- [ ] **OMIM-04**: Data completeness validation before database writes
- [ ] **OMIM-05**: ManageAnnotations view updated for new data sources
- [ ] **OMIM-06**: Fallback strategy for missing disease names documented

### MONDO Equivalence (Optional Enhancement)

- [ ] **MONDO-01**: MONDO-to-OMIM equivalence mapping stored
- [ ] **MONDO-02**: Curation interface to view/assign MONDO equivalents
- [ ] **MONDO-03**: Existing MONDO integration preserved for cross-ontology queries

### Architecture Refactoring

- [x] **ARCH-01**: Database access layer created (execute_query, fetch_all helpers) ✓ Phase 21
- [x] **ARCH-02**: Connection pool used consistently (34 dbConnect/DBI duplications eliminated) ✓ Phase 21
- [x] **ARCH-03**: Entity repository created (domain-specific database operations) ✓ Phase 21
- [x] **ARCH-04**: Review repository created ✓ Phase 21
- [x] **ARCH-05**: Status repository created ✓ Phase 21
- [x] **ARCH-06**: Publication repository created ✓ Phase 21
- [x] **ARCH-07**: Phenotype repository created ✓ Phase 21
- [x] **ARCH-08**: Ontology repository created ✓ Phase 21
- [x] **ARCH-09**: User repository created ✓ Phase 21
- [x] **ARCH-10**: Hash repository created ✓ Phase 21
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

- [x] **ERR-01**: RFC 7807 error format implemented across all endpoints
- [x] **ERR-02**: HTTP status codes consistent (4xx operational, 5xx programmer errors)
- [x] **ERR-03**: Error handler middleware created
- [x] **ERR-04**: Swallowed errors eliminated (tryCatch with proper handling)

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
| QA-01 | Phase 22 | Pending |
| QA-02 | Phase 22 | Pending |
| QA-03 | Phase 22 | Pending |
| QA-04 | Phase 22 | Pending |
| QA-05 | Phase 22 | Pending |
| OMIM-01 | Phase 23 | Pending |
| OMIM-02 | Phase 23 | Pending |
| OMIM-03 | Phase 23 | Pending |
| OMIM-04 | Phase 23 | Pending |
| OMIM-05 | Phase 23 | Pending |
| OMIM-06 | Phase 23 | Pending |
| MONDO-01 | Phase 23 | Pending |
| MONDO-02 | Phase 23 | Pending |
| MONDO-03 | Phase 23 | Pending |
| PAG-01 | Phase 24 | Pending |
| PAG-02 | Phase 24 | Pending |
| PAG-03 | Phase 24 | Pending |
| PAG-04 | Phase 24 | Pending |
| PAG-05 | Phase 24 | Pending |
| VER-01 | Phase 24 | Pending |
| VER-02 | Phase 24 | Pending |
| VER-03 | Phase 24 | Pending |
| VER-04 | Phase 24 | Pending |
| TEST-01 | Phase 24 | Pending |
| TEST-02 | Phase 24 | Pending |
| TEST-03 | Phase 24 | Pending |
| TEST-04 | Phase 24 | Pending |
| TEST-05 | Phase 24 | Pending |

**Coverage:**
- v4 requirements: 71 total
- Mapped to phases: 71
- Unmapped: 0

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

## Password Migration Strategy

**Progressive Re-hash on Login** (production-compatible):
- No forced password resets for active users
- No database schema changes required
- Existing plaintext passwords continue to work
- Passwords silently upgraded to Argon2id on next login
- Hash type detected by prefix (`$argon2id$` vs plaintext)

**Implementation:**
1. On login: check if `password` starts with `$argon2`
2. If hashed → `sodium::password_verify(stored_hash, submitted_password)`
3. If plaintext → direct comparison, then immediately:
   - `new_hash <- sodium::password_store(submitted_password)`
   - Update user record with new hash
4. New registrations always use Argon2id

**For inactive accounts (optional):**
- Consider forced password reset after 6+ months of inactivity
- Send email notification before forcing reset

**Sources:**
- [Upgrading Existing Password Hashes](https://www.michalspacek.com/upgrading-existing-password-hashes)
- [Vaadata: Migrate to Argon2](https://www.vaadata.com/blog/how-to-update-passwords-in-database-to-secure-their-storage-with-argon2/)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

---
*Requirements defined: 2026-01-23*
*Last updated: 2026-01-24 - Phase 18 Foundation and Phase 19 Security Hardening complete*
