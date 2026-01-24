# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-23)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v4 Backend Overhaul - Phase 21 Repository Layer complete, ready for Phase 22

## Current Position

**Milestone:** v4 Backend Overhaul
**Phase:** 22 of 24 (Service Layer & Middleware)
**Plan:** 2 of 9 complete
**Status:** In progress - middleware and auth service complete
**Last activity:** 2026-01-24 - Completed 22-01-PLAN.md (authentication middleware)

```
v4 Backend Overhaul: PHASE 22 IN PROGRESS
Goal: Modernize R/Plumber API with security, async, OMIM fix, R upgrade, DRY/KISS/SOLID
Progress: ████████████████████░░░░░░░░░░░░░ 71% (5/7 phases)
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
| #123 | Implement comprehensive testing | Foundation complete, integration tests deferred |

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
- OMIM genemap2 no longer provides required fields

**Medium - Addressed in Phases 22-24:**
- 15 global mutable state (`<<-`) usages
- 5 god functions (>200 lines)
- ~100 inconsistent error handling patterns
- 30 incomplete TODO comments
- 1240 lintr issues

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

### Pending Todos

None yet.

### Blockers/Concerns

**From Research:**
- ~~Matrix ABI breaking change (must upgrade Matrix to 1.6.3+ BEFORE R upgrade)~~ RESOLVED - Matrix 1.7.2 in R 4.4.3
- ~~Password migration requires dual-hash verification (avoid user lockout)~~ RESOLVED - verify_password() supports both modes
- mim2gene.txt lacks disease names (need MONDO/HPO integration)

**From Phase 20:**
- Analysis functions (gen_string_clust_obj) use global `pool` for DB queries - daemon workers cannot access this. Future refactoring needed for full async execution.

## Session Continuity

**Last session:** 2026-01-24
**Stopped at:** Completed 22-01-PLAN.md (authentication middleware)
**Resume file:** None
**Next action:** Continue Phase 22 - plans 22-03 through 22-09 remaining

---
*Last updated: 2026-01-24 - Completed 22-01 (authentication middleware with require_auth filter and require_role helper)*
