# Phase 55: Bug Fixes - Research

**Researched:** 2026-01-31
**Domain:** Database debugging, curation workflows, Vue 3 state management
**Confidence:** HIGH

## Summary

This phase addresses 8 bugs in the SysNDD neurodevelopmental disorder gene database, spanning entity updates, curation workflows, and review processes. The bugs fall into three categories:

1. **Entity Update Bugs (BUG-01, BUG-02, BUG-03):** EIF2AK2, GAP43, and MEF2C entities have update/creation issues likely caused by database constraints, orphaned records, or transaction failures in the R/Plumber API layer.

2. **Curation Workflow Bugs (BUG-04, BUG-05, BUG-06):** Viewer profile auto-logout, PMID preservation during re-review, and entities-over-time chart display issues require frontend state management and API/database query fixes.

3. **Review Process Bugs (BUG-07, BUG-08):** Disease renaming approval workflow and re-reviewer identity preservation require implementing/fixing database-level tracking and approval mechanisms.

**Primary recommendation:** Debug each bug systematically by tracing the data flow from frontend through API to database, using the existing service layer patterns and repository functions. Focus on atomic transactions, proper error handling, and reactive UI updates.

## Standard Stack

The existing codebase uses an established stack that must be followed:

### Core Backend (R/Plumber)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| plumber | 1.x | REST API framework | Already in use, well-tested |
| pool | 1.0.3 | Database connection pooling | Handles MySQL connections |
| DBI/RMariaDB | 1.3.x | Database interface | MySQL 8.4 compatibility |
| jose | 1.2 | JWT token handling | Auth already implemented |
| logger | 0.2.x | Structured logging | Consistent debugging |
| httpproblems | 1.0 | RFC 9457 error responses | Error handling pattern |

### Core Frontend (Vue 3)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.x | Frontend framework | Composition API patterns |
| bootstrap-vue-next | 0.x | UI components | BCard, BTable, toast system |
| vee-validate | 4.x | Form validation | Profile editing validation |
| axios | 1.x | HTTP client | API communication |
| d3 | 7.x | Visualization | Entities over time chart |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | 1.1.x | Data manipulation | All tibble operations |
| tibble | 3.2.x | Data structures | API response formatting |
| rlang | 1.1.x | R language tools | Error handling, quoting |
| stringr | 1.5.x | String manipulation | Input parsing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Direct SQL | dbplyr | dbplyr already used where appropriate; direct SQL for complex queries |
| Custom toast | Native browser | bootstrap-vue-next toast already integrated, use existing pattern |

**Installation:**
No new dependencies required - all libraries already in use.

## Architecture Patterns

### Recommended Project Structure
```
api/
├── endpoints/          # Plumber endpoint definitions
├── services/           # Business logic layer (auth-service.R, entity-service.R, etc.)
├── functions/          # Repository and helper functions
│   ├── *-repository.R  # Database operations
│   ├── legacy-wrappers.R # Bridge functions for endpoints
│   └── db-helpers.R    # Database utilities
└── core/               # Security, errors, middleware

app/src/
├── views/              # Page-level Vue components
├── components/         # Reusable components
├── composables/        # Vue 3 composition functions (useToast, useEntityForm, etc.)
├── stores/             # State management (if needed)
└── types/              # TypeScript type definitions
```

### Pattern 1: Service Layer Pattern
**What:** Business logic separated from endpoint handlers
**When to use:** Complex operations spanning multiple tables
**Example:**
```r
# Source: api/services/entity-service.R
entity_create <- function(entity_data, user_id, pool) {
  # Validate required fields
  entity_validate(entity_data)

  # Check for duplicate entity
  duplicate <- entity_check_duplicate(entity_data, pool)
  if (!is.null(duplicate)) {
    return(list(status = 409, message = "Conflict", entry = duplicate))
  }

  # Create using repository
  # ... database operations
}
```

### Pattern 2: Transaction Pattern
**What:** Atomic database operations using db_with_transaction
**When to use:** Multi-table updates that must succeed or fail together
**Example:**
```r
# Source: api/functions/db-helpers.R
result <- db_with_transaction(function(txn_conn) {
  # Delete old records
  db_execute_statement("DELETE FROM table WHERE id = ?", list(id), conn = txn_conn)

  # Insert new records
  db_execute_statement("INSERT INTO table (col) VALUES (?)", list(val), conn = txn_conn)

  # Return result
  list(success = TRUE)
}, pool_obj = pool)
```

### Pattern 3: Error Toast Pattern (Medical App)
**What:** User-friendly error display with expandable technical details
**When to use:** All error conditions in Vue components
**Example:**
```typescript
// Source: app/src/composables/useToast.ts
const { makeToast } = useToast();

// Danger variant toasts never auto-hide (medical app requirement)
makeToast(
  "Publication update failed. Please try again.",
  "Error",
  "danger"  // Forces manual dismiss
);
```

### Pattern 4: Reactive Data Refresh
**What:** Immediately update UI after data mutation
**When to use:** After create/update/delete operations
**Example:**
```typescript
// After entity creation, emit event or call refresh
async function createEntity() {
  const response = await axios.post('/api/entity/create', data);
  if (response.status === 200) {
    // Trigger parent component refresh
    emit('entity-created', response.data.entry.entity_id);
    // Or directly refresh local data
    await loadEntities();
  }
}
```

### Anti-Patterns to Avoid
- **Raw SQL without parameterization:** Always use `db_execute_statement(sql, list(params))` to prevent SQL injection
- **Silent failures:** Always log errors and show user-facing toast messages
- **Page refresh for updates:** Use reactive patterns instead of forcing page reload
- **Hardcoded entity positions:** New entities should appear in sorted position, not forced to top

## Don't Hand-Roll

Problems that have existing solutions in the codebase:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database transactions | Manual BEGIN/COMMIT | `db_with_transaction()` | Handles rollback on error |
| Parameter binding | String concatenation | `db_execute_statement(sql, list(...))` | Prevents SQL injection |
| JWT validation | Custom parsing | `require_auth` filter + `jose::jwt_decode_hmac` | Already implemented |
| Role checking | Custom role logic | `require_role(req, res, "Curator")` | Consistent enforcement |
| Error responses | Custom JSON | `httpproblems` + `core/errors.R` | RFC 9457 compliance |
| Toast notifications | Browser alerts | `useToast()` composable | Medical app patterns |
| Entity list refresh | Page reload | Reactive `loadData()` / `emit()` | Better UX |

**Key insight:** The codebase has mature patterns for database operations, authentication, and error handling. Bugs likely stem from incorrect use of these patterns, not missing functionality.

## Common Pitfalls

### Pitfall 1: PMID Replacement Instead of Addition (BUG-05)
**What goes wrong:** When adding a new PMID during re-review, existing PMIDs are deleted
**Why it happens:** The `publication_replace_for_review()` function DELETEs all existing publications before inserting new ones. If the frontend only sends the NEW PMID, existing ones are lost.
**How to avoid:**
- Frontend must send ALL PMIDs (existing + new) when calling PUT endpoint
- Or use `publication_connect_to_review()` for adding without replacing
- Verify UI collects and preserves existing PMIDs before submission
**Warning signs:** Users report "PMID disappeared after adding new one"

### Pitfall 2: Orphaned Entity Records (BUG-02 GAP43)
**What goes wrong:** Entity created in database but not visible in entity list
**Why it happens:**
- Entity created but review/status not created (transaction failure)
- Entity created but `is_active = 0` (deactivation bug)
- Entity exists but view/join excludes it (missing join condition)
**How to avoid:**
- Wrap entity + review + status creation in single transaction
- Check `ndd_entity_view` vs `ndd_entity` table contents
- Verify `is_active = 1` for all new entities
**Warning signs:** Entity ID exists in database but returns 0 rows in API

### Pitfall 3: Token Expiration During Profile View (BUG-04)
**What goes wrong:** Viewer-status users are logged out when viewing their own profile
**Why it happens:** The profile page may call endpoints requiring higher privileges, triggering logout
**How to avoid:**
- Check which API calls profile page makes
- Ensure all profile endpoints accept Viewer role
- Verify `getUserContributions()` endpoint allows Viewer access
**Warning signs:** Logout happens specifically on profile page, not elsewhere

### Pitfall 4: Re-reviewer Identity Overwrite (BUG-08)
**What goes wrong:** Original re-reviewer identity is replaced when review is modified
**Why it happens:** Update query may overwrite `review_user_id` or `approving_user_id` columns
**How to avoid:**
- Separate "original submitter" from "last modifier" if not tracked
- Check UPDATE queries to ensure they preserve original user IDs
- Consider adding `created_by` vs `modified_by` columns if needed
**Warning signs:** User who approved shows up as original submitter

### Pitfall 5: Incorrect Time Aggregation (BUG-06)
**What goes wrong:** Entities-over-time chart shows wrong counts
**Why it happens:**
- Query may count entities multiple times (missing DISTINCT)
- Join conditions may exclude some entities
- Date filtering may be off-by-one
- `ndd_entity_view` may have stale data
**How to avoid:**
- Compare API response counts with direct database query
- Check `summarize_by_time()` grouping logic
- Verify date range boundaries
**Warning signs:** Chart counts don't match manual database count

### Pitfall 6: Disease Renaming Bypasses Approval (BUG-07)
**What goes wrong:** Disease renaming takes effect immediately without approval
**Why it happens:** The `/entity/rename` endpoint creates new entity directly without approval workflow
**How to avoid:**
- Rename should create entry in status/approval table (like re-review)
- New entity should be `is_active = 0` until approved
- Follow existing approval patterns in `services/approval-service.R`
**Warning signs:** Renamed disease visible immediately without curator approval

## Code Examples

Verified patterns from the existing codebase:

### Database Transaction with Error Handling
```r
# Source: api/functions/db-helpers.R pattern
result <- db_with_transaction(function(txn_conn) {
  # Step 1: Insert entity
  db_execute_statement(
    "INSERT INTO ndd_entity (hgnc_id, ndd_phenotype) VALUES (?, ?)",
    list(hgnc_id, phenotype),
    conn = txn_conn
  )

  # Step 2: Get the new ID
  result_id <- db_execute_query("SELECT LAST_INSERT_ID() as entity_id", conn = txn_conn)
  entity_id <- as.integer(result_id$entity_id[1])

  # Step 3: Create review
  db_execute_statement(
    "INSERT INTO ndd_entity_review (entity_id, synopsis) VALUES (?, ?)",
    list(entity_id, synopsis),
    conn = txn_conn
  )

  list(entity_id = entity_id)
}, pool_obj = pool)
```

### Parameterized UPDATE that Preserves Original User
```r
# Source: Pattern for BUG-08 fix - preserve original re-reviewer
# BAD: Overwrites review_user_id
db_execute_statement(
  "UPDATE ndd_entity_review SET synopsis = ?, review_user_id = ? WHERE review_id = ?",
  list(synopsis, current_user_id, review_id)
)

# GOOD: Only updates synopsis, preserves original user
db_execute_statement(
  "UPDATE ndd_entity_review SET synopsis = ?, modified_at = NOW() WHERE review_id = ?",
  list(synopsis, review_id)
)
```

### Error Toast with Expandable Details
```typescript
// Source: app/src/composables/useToast.ts pattern
// For BUG-04 enhancement - error feedback

// Current pattern (use as-is for simple messages)
makeToast("Entity update failed", "Error", "danger");

// Enhanced pattern (for CONTEXT decision: expandable details + copy button)
// Would require new component or toast enhancement
interface ErrorDetails {
  message: string;
  technicalDetails?: string;
}

function showErrorWithDetails(error: ErrorDetails) {
  makeToast(
    error.message,
    "Error",
    "danger"
  );
  // Technical details could be logged to console or stored for copy button
  console.error("Technical details:", error.technicalDetails);
}
```

### Entities Over Time Query
```r
# Source: api/endpoints/statistics_endpoints.R lines 74-196
# Check cumulative count calculation for BUG-06

entity_view_summarized <- entity_view_filtered %>%
  mutate(count = 1) %>%
  arrange(entry_date) %>%
  group_by(!!rlang::sym(group)) %>%
  summarize_by_time(
    .date_var = entry_date,
    .by = rlang::sym(summarize),
    .type = "ceiling",
    count = sum(count)
  ) %>%
  mutate(cumulative_count = cumsum(count)) %>%  # <- Cumulative count
  ungroup()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legacy database-functions.R | Service layer + repository pattern | Phase 22 | Better separation of concerns |
| Check signin filter | require_auth + require_role middleware | Recent | Cleaner auth enforcement |
| Custom error JSON | httpproblems (RFC 9457) | Recent | Standardized error format |
| Options API (Vue 2) | Composition API (Vue 3) | App migration | Modern Vue patterns |

**Deprecated/outdated:**
- `checkSignInFilter`: Deprecated, use `require_auth` filter + `require_role()` helper
- Raw SQL string concatenation: Use parameterized queries only

## Open Questions

Things that couldn't be fully resolved without running the system:

1. **Entity Bug Root Causes (BUG-01, BUG-02, BUG-03)**
   - What we know: Entities fail to update/appear, likely database-level issues
   - What's unclear: Exact failure point - is it constraint violation, transaction rollback, or missing data?
   - Recommendation: Add diagnostic logging at each step; query specific entity_ids directly in database; use Playwright to reproduce

2. **Viewer Profile API Calls (BUG-04)**
   - What we know: Viewer users experience auto-logout on profile page
   - What's unclear: Which specific API call triggers logout - `getUserContributions()` or another?
   - Recommendation: Trace all XHR requests on profile page; check role requirements for each endpoint

3. **PMID UI State (BUG-05)**
   - What we know: `publication_replace_for_review()` deletes before insert
   - What's unclear: Whether frontend sends all PMIDs or only new ones
   - Recommendation: Inspect re-review form state before submission; check request payload

## Sources

### Primary (HIGH confidence)
- `api/services/entity-service.R` - Entity creation patterns
- `api/services/re-review-service.R` - Re-review batch management
- `api/functions/legacy-wrappers.R` - Database operation wrappers
- `api/functions/publication-repository.R` - PMID handling logic
- `api/core/middleware.R` - Auth patterns (require_auth, require_role)
- `api/endpoints/statistics_endpoints.R` - Entities over time query
- `app/src/views/UserView.vue` - Profile page implementation
- `app/src/composables/useToast.ts` - Toast notification pattern
- `app/src/components/analyses/AnalysesTimePlot.vue` - Time chart component

### Secondary (MEDIUM confidence)
- `.planning/phases/55-bug-fixes/55-CONTEXT.md` - User decisions for implementation

### Tertiary (LOW confidence)
- GitHub issues #122, #115, #114, #44, #41 (referenced but not fetched)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified from actual source files
- Architecture: HIGH - Patterns extracted from existing codebase
- Pitfalls: MEDIUM - Based on code analysis, need runtime verification
- Bug root causes: LOW - Require database inspection and runtime debugging

**Research date:** 2026-01-31
**Valid until:** 60 days (stable codebase, debugging-focused phase)

---

## Implementation Guidance Summary

For the planner creating 55-01-PLAN.md (Entity bugs) and 55-02-PLAN.md (Curation bugs):

### Entity Bugs (55-01)
1. **Debug EIF2AK2, GAP43, MEF2C** - Add logging, trace transaction flow, check constraint violations
2. Focus on `entity-service.R`, `entity-repository.R`, `entity_endpoints.R`
3. Verify `is_active = 1` for all created entities
4. Test with specific entity_ids in database

### Curation Bugs (55-02)
1. **BUG-04 (Viewer profile):** Check `getUserContributions()` role requirement, trace API calls
2. **BUG-05 (PMID preservation):** Verify frontend sends all PMIDs, consider `publication_connect_to_review()` vs `publication_replace_for_review()`
3. **BUG-06 (Entities over time):** Debug SQL query, compare with direct count
4. **BUG-07 (Disease renaming):** Add approval workflow to `/entity/rename` endpoint
5. **BUG-08 (Re-reviewer identity):** Add audit column or preserve original user_id in updates
