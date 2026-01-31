# Codebase Concerns

**Analysis Date:** 2026-01-20

## Security Concerns

**Hardcoded Credentials in config.yml:**
- Risk: Database passwords, API tokens, and JWT secrets committed to version control
- Files: `api/config.yml`
- Current state: Contains plaintext passwords (`Nur7DoofeFliegen.`), JWT secret, mail credentials, and OMIM tokens
- Impact: Anyone with repository access can access production credentials; leaked credentials expose database and external APIs
- Recommendation: Migrate all secrets to environment variables or `.env` file (already in `.gitignore`). Use a secrets management system (AWS Secrets Manager, HashiCorp Vault) for production

**SQL Injection Vulnerability in Database Functions:**
- Risk: Dynamic SQL construction using `paste0()` and `dbExecute()`
- Files: `api/functions/database-functions.R` lines 145-152 (and similar patterns throughout)
- Current pattern:
  ```r
  dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
    "is_active = 0, ",
    "replaced_by = ",
    replacement,  # Unparameterized user input
    " WHERE entity_id = ",
    entity_id,    # Unparameterized user input
    ";"))
  ```
- Impact: Malicious input in `entity_id` or `replacement` parameters could execute arbitrary SQL
- Recommendation: Use parameterized queries with `?` placeholders and pass parameters separately to `dbExecute()`

**JWT Secret Key Stored in Config:**
- Risk: Secret key visible in `config.yml` for both local and production
- Files: `api/config.yml` (field `secret`)
- Impact: JWT token validation can be compromised; token forgery possible
- Recommendation: Load JWT secret from environment variable only, never from committed config files

**Direct Database Connections in Endpoints:**
- Risk: Many endpoints create direct `dbConnect()` calls instead of using the connection pool
- Files: `api/endpoints/authentication_endpoints.R`, `api/endpoints/admin_endpoints.R`, and others
- Current state: Mixed usage - some endpoints use `pool`, others create new connections
- Impact: Connection pool exhaustion under load; connection leaks if errors occur; inconsistent connection management
- Recommendation: Standardize on using `pool` object for all database queries; only use `dbConnect()` for testing

**Password Comparison Without Hashing:**
- Risk: User passwords compared directly as plain text
- Files: `api/endpoints/authentication_endpoints.R` line 154
- Current pattern: `filter(user_name == check_user & password == check_pass & approved == 1)`
- Impact: Plaintext password storage means database breach exposes all user passwords
- Recommendation: Use bcrypt or scrypt for password hashing; never store plaintext passwords

**Overly Broad CORS Configuration:**
- Risk: Potential CORS misconfiguration in Plumber filters
- Files: `api/_old/sysndd_plumber.R` shows `Access-Control-Allow-Origin: *`
- Impact: Cross-origin requests from any domain; potential for CSRF attacks
- Recommendation: Restrict CORS to specific trusted origins in production

## Performance Bottlenecks

**No Client-Side Pagination:**
- Issue: Frontend loads all records into memory at once (200+ entries in some cases)
- Files: `app/src/views/curate/ApproveReview.vue` lines 1288-1290
- Current limitation: Client-side pagination requires fetching all data then filtering/sorting
- Impact: Severely degrades performance with large datasets (>1000 records); browser memory exhaustion; slow initial load
- Recommendation: Implement server-side pagination with cursor or offset-based approach; limit page size to 50-100 records

**Full Data Load on Every Filter Change:**
- Issue: Components reload entire dataset when filters are applied
- Files: `app/src/views/curate/ApproveReview.vue` method `loadReviewTableData()`
- Impact: High latency during table filtering; poor UX with 1000+ records
- Recommendation: Pass filter/sort parameters to API endpoint; implement lazy loading

**Magic Numbers and Hardcoded Pagination:**
- Issue: Pagination limited to 200 hardcoded entries
- Files: `app/src/views/curate/ApproveReview.vue` line 1288
- Impact: Cannot view records beyond 200 entries without custom queries
- Recommendation: Implement proper pagination with configurable page size

**Multiple Concurrent API Requests Without Batching:**
- Issue: Multiple sequential API calls within single UI action
- Files: `app/src/views/curate/ApproveReview.vue` lines 1324-1328
- Current pattern: 4 separate `await axios.get()` calls in sequence
- Impact: Slow response time; network latency multiplied across requests
- Recommendation: Implement batch endpoint or use Promise.all() for parallel requests

**Large Vue Components with Inline Logic:**
- Issue: Monolithic components with 1900+ lines of code mixed with UI and logic
- Files:
  - `app/src/views/review/Review.vue` (1910 lines)
  - `app/src/views/curate/ApproveReview.vue` (1726 lines)
  - `app/src/views/curate/ModifyEntity.vue` (1065 lines)
- Impact: Difficult to test, refactor, or reuse logic; performance issues with many DOM elements; slow component lifecycle
- Recommendation: Extract business logic to composables or mixins; split UI into smaller subcomponents

**No Database Query Optimization:**
- Issue: Multiple database round-trips for related data without explicit join optimization
- Files: Various endpoint functions in `api/functions/`
- Pattern: Sequential retrieves of related tables without prefetching
- Impact: N+1 query problem leads to slow endpoint response times
- Recommendation: Use eager loading and precompute commonly needed joins

## Test Coverage Gaps

**No Automated Tests:**
- What's not tested: Entire codebase lacks unit/integration/e2e tests
- Files: No `.test.ts`, `.spec.ts`, or `.test.R` files in source (only in node_modules)
- Risk: Regressions undetected; refactoring requires manual testing; deployment risk high
- Priority: High - critical for production system
- Recommendation: Add Jest/Vitest for Vue components; add testthat or RUnit for R endpoints

**No API Endpoint Tests:**
- What's not tested: Authentication flow, authorization checks, error handling, data validation
- Files: All endpoints in `api/endpoints/` lack test coverage
- Risk: Authentication bypass undetected; SQL injection exploits undiscovered
- Priority: High
- Recommendation: Create integration tests with test database connection

**No Database Migration Tests:**
- What's not tested: Database schema changes; backward compatibility
- Files: Database scripts in `db/` directory
- Risk: Migrations fail silently in production; data corruption goes unnoticed
- Priority: Medium
- Recommendation: Version database schema; create migration tests with rollback verification

## Technical Debt

**Monolithic API Migration Incomplete:**
- Issue: Refactoring from single `sysndd_plumber.R` to modular endpoints still has legacy code
- Files: `api/_old/` directory contains old versions; evidence of active refactoring (branch #109)
- Impact: Code duplication risk; inconsistent patterns across endpoints; confusion about canonical implementations
- Fix approach: Complete endpoint modularization; delete `_old` directory; ensure all patterns follow new structure

**Mixed Database Connection Patterns:**
- Issue: Inconsistent use of connection pool vs direct connections
- Files: All endpoint files use mix of `pool` and `dbConnect()`
- Impact: Resource exhaustion; connection leaks under errors
- Fix approach: Standardize all endpoints to use `pool` for reads; use transactions for writes

**TODO Comments Throughout Frontend:**
- Issue: Unresolved technical decisions scattered in code
- Files:
  - `app/src/views/User.vue` line 256
  - `app/src/components/tables/TablesEntities.vue` line 438
  - `app/src/components/HelperBadge.vue` line 158
  - `app/src/components/small/LogoutCountdownBadge.vue` lines 60, 75, 91, 93, 115
  - `app/src/views/review/Review.vue` lines 1557, 1628, 1837
  - `app/src/views/curate/ApproveStatus.vue` line 817
  - `app/src/router/routes.js` line 4
  - `app/src/views/curate/ApproveReview.vue` lines 1288-1290, 1478, 1516
- Impact: Code quality suffers; technical debt accumulates; maintenance burden increases
- Fix approach: Create tickets for each TODO; prioritize and resolve systematically

**Client-Side Data Manipulation:**
- Issue: Business logic implemented on client side instead of server
- Files: `app/src/views/review/Review.vue` lines 1837-1845 (hardcoded logic checking if ID <= 3650)
- Impact: Logic cannot be reused by other clients; prone to UI-induced errors; slow execution
- Fix approach: Move validation/transformation logic to API endpoints

**Duplicate Code in Token Management:**
- Issue: JWT refresh and signin logic repeated across components
- Files: `app/src/components/small/LogoutCountdownBadge.vue` has `refreshWithJWT()` and `signinWithJWT()`
- Pattern: Same methods appear in other components
- Impact: Bug fixes must be replicated; memory waste; maintenance burden
- Fix approach: Extract to auth service/composable; implement once, reuse everywhere

**Magic Numbers Without Constants:**
- Issue: Hardcoded values scattered throughout code
- Files: `app/src/components/small/LogoutCountdownBadge.vue` lines 93-96 (1000, 60, warning time points)
- Impact: Difficult to understand intent; impossible to change consistently
- Fix approach: Create config file with constants; reference in code

**Deprecated Dependencies:**
- Issue: Vue 2 framework used (EOL in Dec 2022); many dependencies showing outdated versions
- Files: `app/package.json`
- Current state:
  - Vue 2.7.8 (long-term support ended)
  - axios 0.21.4 (outdated; known vulnerabilities)
  - vee-validate 3.4.14 (Vue 2 only; Vue 3+ requires v4+)
  - bootstrap-vue 2.21.2 (Vue 2 only; no Vue 3 support)
- Impact: Security vulnerabilities in dependencies; no new features or fixes; framework unmaintained
- Timeline: Urgent for production systems
- Recommendation: Create migration plan to Vue 3; prioritize security patches first; update axios immediately

**Old Plumber Code Still in Repository:**
- Issue: Legacy endpoint files in `api/_old/` directory still present
- Files: `api/_old/sysndd_plumber.R` (15KB), `api/_old/plumber_2021-04-17.R` (7.2KB)
- Impact: Code archaeology required to understand history; confusion about source of truth; merge conflict risk
- Fix approach: Archive in git history only; remove from working tree; document migration in commit messages

## Fragile Areas

**Authentication State Management:**
- Files: `app/src/components/small/LogoutCountdownBadge.vue`, `app/src/router/routes.js`
- Why fragile: Token stored in localStorage (accessible to XSS); no automatic refresh mechanism centralized; manual refresh logic scattered across components
- Safe modification: Create centralized auth module with unified token management
- Test coverage: No tests for auth flows; token expiry behavior untested

**Review/Approval Workflows:**
- Files: `app/src/views/review/Review.vue` (1910 lines), `app/src/views/curate/ApproveReview.vue` (1726 lines)
- Why fragile: Complex state management with nested data structures; TODO comments indicate incomplete logic; business logic on client side
- Safe modification: Split into smaller components; move validation to API; add comprehensive tests
- Test coverage: No tests; manual verification only

**Database Connection Management:**
- Files: `api/functions/database-functions.R`, all endpoint files
- Why fragile: Mixed use of pool and direct connections; no centralized connection cleanup; try-catch error handling incomplete
- Safe modification: Create wrapper function for all DB operations; standardize on pool everywhere; add proper resource cleanup
- Test coverage: No tests for connection exhaustion or error scenarios

**Entity Status Workflow:**
- Files: `api/endpoints/entity_endpoints.R` (951 lines), `api/functions/endpoint-functions.R`
- Why fragile: Multiple interdependent status tables; complex normalization logic; TODO comment on line 1557 suggests incomplete implementation
- Safe modification: Document state machine explicitly; create migration script for status updates; add validation layer
- Test coverage: Manual testing only

## Scaling Limits

**Database Connection Pool:**
- Current capacity: Default RMariaDB pool settings (unknown explicit limit)
- Limit: Each endpoint can exhaust pool with direct connections; concurrent request handling limited
- Scaling path: Explicitly configure pool size; implement connection queue; monitor pool utilization; switch to read replicas for read-heavy endpoints

**Memory Usage in Large Tables:**
- Current capacity: Loads 200+ records client-side; limited by browser RAM
- Limit: 5000+ records will cause browser slowdown; 10000+ records causes crashes
- Scaling path: Implement server-side pagination; stream results; use virtual scrolling

**API Endpoint Latency:**
- Current capacity: Single-threaded R process; Plumber limited to sequential requests
- Limit: 10-20 concurrent requests causes noticeable slowdown
- Scaling path: Use async processing with future package; implement caching (memoization for read endpoints); add load balancing

**Data Transmission:**
- Current issue: Full JSON responses without field selection optimization
- Limit: Large result sets (1000+ records with nested data) create 5-10MB responses
- Scaling path: Implement sparse fieldsets via `fspec` parameter consistently; add compression; implement pagination

## Missing Critical Features

**No Comprehensive Error Handling:**
- Problem: API endpoints lack consistent error response format; clients must handle various error structures
- Blocks: Robust error reporting; automated error monitoring; client-side error recovery
- Recommendation: Implement standardized error response envelope with error codes and messages

**No Rate Limiting:**
- Problem: No protection against brute force or DoS attacks
- Blocks: Security hardening; preventing abuse of compute-intensive endpoints
- Recommendation: Add rate limiting middleware to Plumber; use token bucket or sliding window algorithm

**No API Versioning:**
- Problem: No version indicators in endpoints; breaking changes impossible to manage
- Blocks: Backward compatibility maintenance; coordinated client-server upgrades
- Recommendation: Add API version to URL path or header; support multiple versions during transition

**No Request Logging:**
- Problem: Difficult to debug production issues; no audit trail for data modifications
- Blocks: Security compliance; performance analysis; user activity tracking
- Recommendation: Implement centralized request logging with user context; persist to database

**No Webhook/Event System:**
- Problem: Changes to curated data not communicated to external systems in real-time
- Blocks: Third-party integrations; external data synchronization
- Recommendation: Implement webhook system with retry logic and payload signing

**No Caching Layer:**
- Problem: Database queried for same data repeatedly (e.g., lookup tables, reference data)
- Blocks: Performance optimization; scalability
- Recommendation: Add Redis caching for reference data; implement cache invalidation strategy

**No Database Backup Automation:**
- Problem: Manual backup process; no recovery testing
- Blocks: Disaster recovery planning; compliance
- Recommendation: Implement automated daily backups with point-in-time recovery capability

---

*Concerns audit: 2026-01-20*
