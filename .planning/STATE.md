# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul - Phase 24 Versioning, Pagination & Cleanup COMPLETE

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** 24 of 24 (Versioning, Pagination & Cleanup) - COMPLETE
**Plan:** 7 of 7 complete
**Status:** Phase 24 complete - All waves complete
**Last activity:** 2026-01-24 - Completed 24-07 Integration tests (version, pagination, async)

```
v4 Backend Overhaul: PHASE 24 COMPLETE
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: ████████████████████████████████ 100% (24/24 phases)
```

## Completed Milestones

| Milestone | Phases | Shipped | Archive |
|-----------|--------|---------|---------|
| v1 Developer Experience | 1-5 (19 plans) | 2026-01-21 | milestones/01-developer-experience/ |
| v2 Docker Infrastructure | 6-9 (8 plans) | 2026-01-22 | milestones/02-docker-infrastructure/ |
| v3 Frontend Modernization | 10-17 (53 plans) | 2026-01-23 | milestones/03-frontend-modernization/ |

## GitHub Issues

| Issue | Description | Status |
|-------|-------------|--------|
| #109 | Refactor sysndd_plumber.R into smaller endpoint files | Ready for PR |
| #123 | Implement comprehensive testing | Foundation complete, integration tests added (Phase 24-07) |

## Tech Debt (from API_CODE_REVIEW_REPORT.md)

**Critical (Security) - RESOLVED in Phase 19:**
- ~~66 SQL injection vulnerabilities via string concatenation~~ Parameterized queries
- ~~Plaintext password storage/comparison~~ Argon2id hashing with progressive migration
- ~~Passwords visible in logs~~ Sanitized logging

**High - Addressed in Phases 20-22:**
- ~~17 `dbConnect` calls bypassing connection pool~~ RESOLVED - ALL eliminated (34 total: Phase 21-06 removed 19, Phase 21-07/08 removed 15)
- ~~Missing `on.exit(dbDisconnect(...))` cleanup~~ RESOLVED - Repository layer handles all connections
- ~~Zero dbConnect in production code~~ RESOLVED - Only pool creation in start_sysndd_api.R
- ~~19 direct DBI calls bypassing db-helpers~~ RESOLVED - Phase 21-09/10 eliminated all (4 in 21-09, 15 in 21-10)
- ~~OMIM genemap2 no longer provides required fields~~ RESOLVED - mim2gene.txt + JAX API + MONDO mappings (Phase 23 complete)

**Medium - Addressed in Phases 22-24:**
- 15 global mutable state (`<<-`) usages
- 5 god functions (>200 lines)
- ~100 inconsistent error handling patterns
- ~~30 incomplete TODO comments~~ RESOLVED - Phase 24-05 reduced to 1 intentional TODO
- ~~1240 lintr issues~~ RESOLVED - Phase 24-06 reduced to 85 (88% reduction, 57% under target)

## Key Decisions

See PROJECT.md for full decisions table. Pending v4 decisions will be logged as they are made.

## Accumulated Context

### Decisions

| Date | Phase | Decision | Rationale |
|------|-------|----------|-----------|
| 2026-01-23 | 19-01 | Use sodium::password_store for Argon2id | OWASP recommended, superior to bcrypt for new implementations |
| 2026-01-23 | 19-01 | Progressive migration via dual-verification | Zero-downtime migration without forcing password resets |
| 2026-01-23 | 19-01 | Use httpproblems for RFC 9457 errors | Industry standard Problem Details format |
| 2026-01-23 | 19-01 | Centralize sensitive fields in constant | Consistent sanitization across all logging |
| 2026-01-23 | 19-02 | params = list() for simple parameterized queries | Standard RMariaDB pattern |
| 2026-01-23 | 19-02 | Dynamic IN clause with placeholder generation | paste(rep("?", n)) pattern for batch operations |
| 2026-01-23 | 19-03 | Combined UPDATE statements in user approval | Single parameterized query more efficient than 3 separate |
| 2026-01-23 | 19-03 | Silent password upgrade on login | No user notification needed for transparent migration |
| 2026-01-23 | 19-04 | Sanitize JSON body by parsing then sanitize_object | More reliable than regex replacement |
| 2026-01-23 | 19-04 | Generic 500 for unhandled exceptions | Don't expose stack traces or internal error messages |
| 2026-01-24 | 19-05 | Use $7$ prefix for libsodium hash detection | sodium::password_store produces $7$ hashes, not $argon2 |
| 2026-01-24 | 19-05 | Plumber sourcing via find.package path | Relative paths fail when Plumber sources endpoints |
| 2026-01-24 | 19-05 | Mount core/ directory in Docker | Core modules must be accessible at container runtime |
| 2026-01-24 | 20-01 | 8-worker daemon pool for async jobs | Matches MAX_CONCURRENT_JOBS limit for predictable capacity |
| 2026-01-24 | 20-01 | 30-minute job timeout (1800000ms) | Sufficient for STRING-db clustering and ontology updates |
| 2026-01-24 | 20-01 | Promise pipe (%...>%) for status updates | Non-blocking callback pattern from mirai/promises integration |
| 2026-01-24 | 20-01 | Recursive later() for hourly cleanup | Workaround for later package lacking loop=TRUE parameter |
| 2026-01-24 | 20-02 | Pre-fetch database data before mirai call | DB connections cannot cross process boundaries |
| 2026-01-24 | 20-02 | Entity count hash for phenotype clustering dedup | Stable identifier since endpoint takes no parameters |
| 2026-01-24 | 20-02 | Preserve sync endpoints for backward compatibility | New clients should use async, existing clients still work |
| 2026-01-24 | 20-03 | Pre-fetch HGNC/MOI data for ontology_update | DB data must be collected before mirai submission |
| 2026-01-24 | 20-03 | Administrator role required for ontology updates | Ontology updates are administrative operations |
| 2026-01-24 | 20-03 | Auth filter allowlist for /api/jobs | Endpoints need authentication filter bypass pattern |
| 2026-01-24 | 20-03 | Daemon package exports via .packages param | Worker processes need explicit package access |
| 2026-01-24 | 21-01 | Use positional ? placeholders for RMariaDB | RMariaDB only supports positional, not :name syntax |
| 2026-01-24 | 21-01 | Return tibbles from db_execute_query (never NULL) | Consistent interface, avoids NULL checks downstream |
| 2026-01-24 | 21-01 | Redact strings > 50 chars in DEBUG logs | Balance debugging utility with security |
| 2026-01-24 | 21-01 | Structured error classes with rlang::abort() | Type-safe error handling in repositories and endpoints |
| 2026-01-24 | 21-01 | Pool checkout for transactions, direct use for single queries | Transactions need connection stability, single queries use pool's automatic management |
| 2026-01-24 | 21-02 | Use rlang::abort with structured error classes for validation | Type-safe error handling allows endpoints to catch specific error classes |
| 2026-01-24 | 21-02 | Escape single quotes in synopsis using str_replace_all | Prevents SQL syntax errors from single quotes in user-provided text |
| 2026-01-24 | 21-02 | Use db_with_transaction for review_approve atomicity | Multi-statement approval workflow must be all-or-nothing |
| 2026-01-24 | 21-02 | Reset approval status on review_update | Business rule enforcement - any modification requires re-approval |
| 2026-01-24 | 21-05 | user_find_for_auth includes password hash (auth only) | Authentication requires password verification, but must be isolated from general user queries |
| 2026-01-24 | 21-05 | user_update_password isolated from user_update | Clear separation makes password handling explicit and prevents accidental logging |
| 2026-01-24 | 21-05 | Public user queries use users_view (excludes password) | Database-level protection against password exposure in non-auth queries |
| 2026-01-24 | 21-05 | hash_create returns hash_value (not hash_id) | Existing API contract expects hash value back, maintaining consistency |
| 2026-01-24 | 21-05 | hash_validate_columns enforces whitelist | Prevents malicious hash requests from accessing arbitrary tables/columns |
| 2026-01-24 | 21-03 | Status approval uses transaction for atomicity | Approving status requires multiple DB operations (reset all entity statuses, set new active) |
| 2026-01-24 | 21-03 | Publication validation uses pool with dplyr | Cleaner than raw SQL, type-safe with dplyr's collect() |
| 2026-01-24 | 21-03 | Status update prevents entity_id changes | Changing entity association would break referential integrity |
| 2026-01-24 | 21-04 | Validate against allowed lists before database operations | Prevents invalid HPO/VARIO terms from being inserted |
| 2026-01-24 | 21-04 | Enforce entity_id matching for review connections | Prevent changing entity association of existing reviews |
| 2026-01-24 | 21-04 | Parallel domain structure for phenotype/ontology repositories | Same connection pattern for different term types reduces cognitive load |
| 2026-01-24 | 21-06 | Keep existing function signatures unchanged for backward compatibility | Legacy API functions act as thin wrappers, endpoints can migrate gradually |
| 2026-01-24 | 21-06 | Delegate validation to repositories | Centralized validation logic in repository layer |
| 2026-01-24 | 21-06 | Maintain quote escaping in database-functions.R for synopsis fields | Escaping still needed at API layer before passing to repositories |
| 2026-01-24 | 21-08 | Use parameterized queries with ? placeholders for all SQL statements | Prevents SQL injection across entire codebase |
| 2026-01-24 | 21-08 | Use poolWithTransaction for single-table operations with AppendTable | Atomic inserts with automatic connection management |
| 2026-01-24 | 21-08 | Use db_with_transaction for multi-statement atomic operations | Ensures consistency across complex database updates |
| 2026-01-24 | 21-09 | Use dynamic column extraction for INSERT statements | names(tibble) guarantees column order matches parameter order |
| 2026-01-24 | 21-09 | Replace poolWithTransaction + dbAppendTable with db_execute_statement | Consistency with repository layer security pattern |
| 2026-01-24 | 21-10 | Move total_pages check BEFORE transaction in pubtator_db_update | No database operations needed for PubTator API call, avoids unnecessary transaction overhead |
| 2026-01-24 | 21-10 | Use early returns inside db_with_transaction for auto-commit | Cleaner than manual dbCommit calls - db_with_transaction handles commit automatically on successful return |
| 2026-01-24 | 21-10 | Use dynamic column INSERT loops instead of dbAppendTable/dbWriteTable | Maintains parameterized query pattern while handling dynamic column sets - prevents SQL injection |
| 2026-01-24 | 22-01 | Use AUTH_ALLOWLIST constant for public endpoints | Centralized list prevents scattered conditional logic - easier to audit and maintain security posture |
| 2026-01-24 | 22-01 | Provide public read access for GET requests without authentication | SysNDD data is publicly accessible for research - GET without auth enables public browsing while requiring auth for modifications |
| 2026-01-24 | 22-01 | Attach user context to req object (user_id, user_role, user_name) | Downstream endpoints need user info for logging/authorization - avoid re-decoding JWT in every endpoint |
| 2026-01-24 | 22-01 | Use require_role as helper function (not filter) | Different endpoints require different roles - helper function provides more flexibility than per-endpoint filter configuration |
| 2026-01-24 | 22-02 | Service layer uses dependency injection (pool, config as params) | Services accept dependencies as parameters rather than accessing global state - enables testability and follows SOLID principles |
| 2026-01-24 | 22-02 | Progressive password upgrade integrated in signin flow | Transparently upgrades legacy plaintext passwords to Argon2id on successful login - zero user friction |
| 2026-01-24 | 22-02 | JWT claims include comprehensive user info | Include user_id, user_name, email, user_role, abbreviation, orcid to avoid database lookups on every request |
| 2026-01-24 | 22-02 | Token expiry configurable via config parameter | Uses config$refresh with fallback to 86400 seconds - production can adjust without code changes |
| 2026-01-24 | 22-03 | Service layer uses pool parameter for dependency injection | Testability and SOLID principles - services accept dependencies rather than accessing global state |
| 2026-01-24 | 22-03 | Entity duplicate checking via quadruple validation | Prevent duplicate entities with same hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, and ndd_phenotype - returns 409 Conflict |
| 2026-01-24 | 22-03 | entity_get_full retrieves comprehensive entity data | Single function to get entity with all related data (reviews, status, phenotypes, publications, variation ontology) - reduces endpoint boilerplate |
| 2026-01-24 | 22-03 | Direct db_execute_statement calls in service layer | Service layer directly uses db-helpers instead of going through repository layer - simpler stack, avoids naming conflicts |
| 2026-01-24 | 22-05 | Service layer uses dependency injection (pool as parameter) | Services accept dependencies as parameters rather than accessing global state - enables testability and follows SOLID principles |
| 2026-01-24 | 22-05 | Role-based user list filtering in service layer | Administrator sees all users with full details, Curator sees reviewers/viewers, Reviewer/Viewer sees limited info |
| 2026-01-24 | 22-05 | Status service uses pool checkout/return for transactions | Re-review workflow requires multiple statements to be atomic - checkout connection for transaction control |
| 2026-01-24 | 22-05 | Search functions validate minimum 2-character query | Prevents performance issues from single-character wildcard searches that would match too many records |
| 2026-01-24 | 22-05 | User approval workflow integrated in service layer | Complex business logic (password generation, email sending, status updates) belongs in service layer, not endpoints |
| 2026-01-24 | 22-04 | Use svc_ prefix for service functions to avoid repository conflicts | Both service and repository layers have functions like review_create - svc_ prefix prevents naming collisions and clarifies layer separation |
| 2026-01-24 | 22-04 | Service layer accepts pool despite repositories using global pool | Dependency injection pattern for future testability - even though current repositories access global pool, services structured for future refactoring |
| 2026-01-24 | 22-04 | Support batch approval via "all" parameter | Matches existing database-functions.R behavior - enables admin workflows to approve all pending reviews/statuses at once |
| 2026-01-24 | 22-04 | Maintain quote escaping at service layer | Repository also escapes quotes - duplication exists for backward compatibility with database-functions.R during migration |
| 2026-01-24 | 22-06 | Keep password/update complex self-vs-admin logic inline | Complex self-vs-admin authorization doesn't fit cleanly into require_role pattern - deferred to later service layer refactoring |
| 2026-01-24 | 22-06 | Maintain backward compatibility in auth endpoints | auth service returns structured response, but existing endpoints return plain JWT string - extract access_token for compatibility |
| 2026-01-24 | 22-06 | Use require_role for simple checks, keep == checks for differentiation | require_role enforces minimum role, explicit == checks needed for differentiated behavior (e.g., Admin sees all, Curator sees subset) |
| 2026-01-24 | 22-07 | Remove inline authorization from endpoints | Middleware provides consistent authorization, eliminates duplicated role checks |
| 2026-01-24 | 22-07 | Delegate approval operations to service layer | Service layer provides batch operation support and consistent business logic |
| 2026-01-24 | 23-01 | 50ms delay between JAX API requests | No rate limiting observed, but provides safety margin (20 req/sec max) |
| 2026-01-24 | 23-01 | WARN on missing disease names, don't abort | 18% of phenotype MIMs return 404 - too high to abort, log and continue |
| 2026-01-24 | 23-01 | Use req_error(is_error = ~ FALSE) for httr2 | Prevents throwing on HTTP errors, allows manual handling of 404s |
| 2026-01-24 | 23-01 | max_tries=5, backoff=2^x, max_seconds=120 for retries | Conservative retry strategy for transient JAX API failures |
| 2026-01-24 | 23-02 | Use check_file_age from file-functions.R | Consistent with existing file caching pattern |
| 2026-01-24 | 23-02 | Return NA_character_ for JAX 404s (not abort) | 18% of MIMs not in JAX - too many to abort batch |
| 2026-01-24 | 23-02 | Filter deprecated entries from ontology set | Deprecated entries tracked separately for re-review workflow |
| 2026-01-24 | 23-02 | Versioning: OMIM:XXXXXX_N for duplicates | Same pattern as existing process_omim_ontology |
| 2026-01-24 | 23-02 | MOI term is NA for mim2gene source | mim2gene.txt lacks inheritance information |
| 2026-01-24 | 23-03 | Use readr comment='#' for SSSOM metadata | SSSOM files have # comment header lines |
| 2026-01-24 | 23-03 | Semicolon-separate multiple MONDO matches | Consistent with existing ontology-functions.R pattern |
| 2026-01-24 | 23-03 | Only mim2gene entries get MONDO lookups | mondo entries already have MONDO ID |
| 2026-01-24 | 23-03 | Remove redundant source() calls in endpoints | All modules already loaded by start_sysndd_api.R |
| 2026-01-24 | 23-04 | Conditional sourcing for omim/mondo functions | Plumber vs standalone have different working directories; conditional paths ensure portability |
| 2026-01-24 | 23-04 | Pass progress_callback through nested function calls | process_combine_ontology passes to process_omim_ontology which passes to fetch_all_disease_names |
| 2026-01-24 | 23-04 | Pre-fetch all DB data before create_job | Mirai daemon workers cannot access the pool; all data must be collected before submission |
| 2026-01-24 | 23-04 | Use DBI:: prefix in executor function | Executor runs in daemon worker without loaded packages; explicit namespace required |
| 2026-01-24 | 23-04 | Deprecate synchronous endpoint in docs only | Keep backward compatibility while encouraging async usage |
| 2026-01-24 | 24-01 | Use GIT_COMMIT env var with git command fallback | Enables both Docker production (build arg) and local development (git command) |
| 2026-01-24 | 24-01 | Public endpoint for version discovery | Version information is public metadata - no authentication required |
| 2026-01-24 | 24-01 | Return "unknown" when git not available | Graceful degradation instead of errors in containerized environments |
| 2026-01-24 | 24-02 | Set PAGINATION_MAX_SIZE to 500 | Upper end of PAG-02 100-500 range - balances DoS prevention with usability |
| 2026-01-24 | 24-02 | Return validated page_size as character | Maintains consistency with existing generate_cursor_pag_inf API |
| 2026-01-24 | 24-02 | Log warnings for invalid page_size values | Security monitoring for potential DoS attempts via log_warn |
| 2026-01-24 | 24-02 | Default to 10 for invalid/below-minimum page_size | Reasonable default prevents empty results, non-breaking fallback |
| 2026-01-24 | 24-03 | Composite key sorting (created_at, unique_id) for pagination | Ensures stable pagination across API restarts and concurrent updates |
| 2026-01-24 | 24-03 | Default page_size="all" for table endpoints | Maintains backward compatibility with existing API consumers |
| 2026-01-24 | 24-03 | Pagination applied in both role-based branches | Administrator and Curator see different data but both get paginated response |
| 2026-01-24 | 24-04 | Use tree parameter to control pagination | tree=TRUE bypasses pagination for hierarchical data, tree=FALSE applies it |
| 2026-01-24 | 24-04 | Sort by primary identifier for stable pagination | phenotype_id not HPO_term, vario_id not sort column - ensures cursor stability |
| 2026-01-24 | 24-04 | Default page_size='all' for list endpoints | Backward compatibility with existing dropdown/list consumers |
| 2026-01-24 | 24-05 | Fix multiple title matches with first-match strategy | GeneReviews scraping can return multiple title elements; taking first match is safest, with logging for monitoring |
| 2026-01-24 | 24-05 | Add parentheses validation to filter expressions | Malformed filter strings cause cryptic errors; validating structure upfront provides better UX |
| 2026-01-24 | 24-05 | Document future TODOs with context and links | Remaining TODOs are legitimate future enhancements; clear documentation prevents confusion and provides implementation guidance |
| 2026-01-24 | 24-06 | Target <200 lintr issues not zero | Diminishing returns - focus on high-value fixes not cosmetic perfection; 85 final issues are justified (long fspec strings, edge cases) |
| 2026-01-24 | 24-06 | Fix pipe consistency to magrittr %>% | Project standard in .lintr config, consistency across codebase; newer code was using native pipe |
| 2026-01-24 | 24-06 | Applied styler to bulk directories | Safe automated formatting, 80% of issues fixed automatically; verified no functional changes via git diff and health check |
| 2026-01-24 | 24-07 | Use httr2::request for HTTP integration tests | Consistent with existing test-integration-auth.R pattern; leverages existing test infrastructure |
| 2026-01-24 | 24-07 | Skip tests when API not running (CI flexibility) | skip_if_api_not_running() helper checks localhost:8000/health; tests run in dev, skip in CI without failures |
| 2026-01-24 | 24-07 | Document authenticated endpoint tests rather than skip | Provides testing guide for manual verification; tests serve as API usage documentation |
| 2026-01-24 | 24-07 | Leverage existing test-unit-security.R for password migration | Comprehensive coverage already exists (290 lines); avoid test duplication |

### Pending Todos

None yet.

### Blockers/Concerns

**From Research:**
- ~~Matrix ABI breaking change (must upgrade Matrix to 1.6.3+ BEFORE R upgrade)~~ RESOLVED - Matrix 1.7.2 in R 4.4.3
- ~~Password migration requires dual-hash verification (avoid user lockout)~~ RESOLVED - verify_password() supports both modes
- ~~mim2gene.txt lacks disease names (need MONDO/HPO integration)~~ RESOLVED - JAX API + MONDO SSSOM mappings provide coverage

**From Phase 23-01 Validation:**
- ~~18% of phenotype MIM numbers not in JAX database~~ DOCUMENTED - Log warning and continue, MONDO mappings provide additional context

**From Phase 20:**
- Analysis functions (gen_string_clust_obj) use global `pool` for DB queries - daemon workers cannot access this. Future refactoring needed for full async execution.

## Session Continuity

**Last session:** 2026-01-24
**Stopped at:** Completed 24-07-PLAN.md (Integration tests - version, pagination, async)
**Resume file:** None
**Next action:** Phase 24 COMPLETE - Ready for PR submission (#109)

---
*Last updated: 2026-01-24 - Phase 24 COMPLETE (All 7 plans complete - version endpoint, pagination safety, user/re-review tables, list/status endpoints, TODO cleanup, lintr cleanup, integration tests)*
