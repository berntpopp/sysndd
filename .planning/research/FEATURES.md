# Feature Landscape: Curation Workflow Modernization

**Domain:** Gene-disease entity curation for neurodevelopmental disorders database
**Milestone:** Curation Views Improvement (subsequent milestone)
**Researched:** 2026-01-26
**Confidence:** HIGH (based on ClinGen/ClinVar patterns + existing codebase analysis)

---

## Executive Summary

Scientific data curation interfaces require a balance between rigorous data quality controls and curator productivity. Based on analysis of ClinGen's Variant Curation Interface (the FDA-recognized standard for clinical genomics curation), general data curation best practices, and assessment of SysNDD's existing implementation, this document categorizes features for the curation workflow modernization milestone.

The existing SysNDD curation views include:
- **CreateEntity**: 5-step wizard (Gene, Disease, Inheritance, NDD, Evidence) with draft save/restore
- **ModifyEntity**: 4 actions (Rename, Deactivate, Modify review, Modify status)
- **ApproveReview**: Table with bulk approve, expandable rows, global search
- **ApproveStatus**: Status approval workflow table
- **ApproveUser**: User registration approval (BROKEN)
- **ManageReReview**: Batch assignment table for re-review workflow

---

## Table Stakes

Features users expect. Missing = product feels incomplete or unprofessional.

### 1. Form Validation and Error Handling

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Real-time field validation | Prevents submission errors, immediate feedback | Low | Partial - exists in CreateEntity wizard | Must validate on step transition and before submission |
| Clear error messages | Users need actionable guidance | Low | Basic - toast notifications only | Position errors near fields, not just in toasts |
| Required field indicators | Standard form pattern | Low | Missing in many places | Asterisks or visual cues for mandatory fields |
| Dropdown population | Empty dropdowns = broken UX | Low | **BROKEN** - ModifyEntity status dropdown empty | Critical fix needed - status_options not loading correctly |

**Reference:** [Multi-step form best practices](https://www.growform.co/must-follow-ux-best-practices-when-designing-a-multi-step-form/) - "Validate each step before proceeding to prevent users from encountering issues later."

### 2. Table Filtering and Sorting

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Column-specific filters | Standard for data tables | Medium | Missing on approval tables | ApproveReview only has global search |
| Sortable columns | Users expect to reorder data | Low | Partial - some tables have it | Needs consistent implementation |
| Clear sort indicators | Users need visual feedback | Low | Exists via Bootstrap-Vue | Ensure aria-sort for accessibility |
| Filter persistence | Don't lose filters on navigation | Medium | Missing | Store in URL params or session |

**Reference:** [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) - "Filtering and sorting are fundamental table interactions that users expect."

### 3. Pagination Controls

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Consistent pagination | Same pattern across all tables | Low | **INCONSISTENT** - varies by view | ApproveUser top, ApproveReview bottom |
| Page size selector | User preference accommodation | Low | Exists but inconsistent options | Standardize: 10, 25, 50, 100 |
| Total count display | Users need context | Low | Partial | "Showing 1-10 of 150 items" pattern |
| Server-side pagination | Required for large datasets | High | Missing - client-side only | TODO noted in ApproveReview code |

**Reference:** [ClinGen VCI](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-021-01004-8) uses server-side pagination for variant lists.

### 4. Accessibility Compliance

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| ARIA labels on buttons | Screen reader support | Low | **MISSING** on action buttons | UX review finding |
| Focus indicators | Keyboard navigation | Low | Partial - Bootstrap defaults | Verify on all interactive elements |
| Accessible table structure | WCAG 2.2 compliance | Medium | Needs audit | Proper th/td scoping |
| Live region announcements | Dynamic content updates | Medium | Missing | Announce filter results, approvals |

**Reference:** [WCAG Tables Accessibility](https://testparty.ai/blog/wcag-tables-accessibility) - "Sortable columns need aria-sort attributes and button controls."

### 5. Loading States and Feedback

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| Loading spinners | User knows action is processing | Low | Exists - BSpinner | Consistent across all async operations |
| Success/error feedback | Clear outcome communication | Low | Exists - toast system | Continue using |
| Disabled buttons during submit | Prevent double-submission | Low | Partial | Add to all submit actions |
| Optimistic updates | Responsive feel | Medium | Missing | Optional enhancement |

### 6. Working Approval Workflows

| Feature | Why Expected | Complexity | Current State | Notes |
|---------|--------------|------------|---------------|-------|
| User approval | Administrators approve new users | Low | **BROKEN** - ApproveUser F rating | Critical - blocks new curator onboarding |
| Role assignment during approval | Set user role on approval | Low | Exists but may not persist | Verify API call works |
| Review approval | Approve submitted reviews | Low | Works - ApproveReview | Keep working |
| Status approval | Approve status changes | Low | Works - ApproveStatus | Keep working |

---

## Differentiators

Features that set product apart. Not expected, but valued by curators.

### 1. Batch Operations

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Bulk approve reviews | Massive time savings for curators | Medium | Exists in ApproveReview | "Approve all reviews" button works |
| Bulk status changes | Batch classification updates | High | Missing | ClinGen supports batch classification |
| Select-all with conditions | Smart batch selection | Medium | Missing | "Select all matching filter" pattern |
| Undo batch operations | Error recovery | High | Missing | Toast with undo button |

**Reference:** [Bulk Actions UX](https://www.eleken.co/blog-posts/bulk-actions-ux) - "Immediately offer a way to revert bulk actions with undo."

### 2. Advanced Workflow States

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| In-progress / Provisional / Approved states | ClinGen-style workflow tracking | Medium | Partial - review_approved flag | ClinGen VCI has 4 states |
| Status change indicators | Visual alerts for pending changes | Low | Exists - exclamation icon | Good implementation |
| Revision tracking | See what changed between versions | High | Missing | "New-Provisional" state in ClinGen |
| Conflict detection | Multiple curators on same entity | High | Exists - duplicate warning | Good implementation |

**Reference:** [ClinGen VCI Workflow](https://clinicalgenome.org/docs/variant-curation-standard-operating-procedure/) - "In-progress, Provisional, Approved, New-Provisional status progression."

### 3. Draft Save and Resume

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Auto-save drafts | Never lose work | Medium | **EXISTS** in CreateEntity | useFormDraft composable |
| Draft recovery prompt | Seamless session recovery | Low | **EXISTS** in CreateEntity | Well implemented |
| Draft indicators | Know when data is saved | Low | **EXISTS** - last saved timestamp | Good implementation |
| Cross-session persistence | Long-form curation support | Low | Exists via localStorage | Good approach |

**This is a strength of the current implementation - preserve and extend to other forms.**

### 4. Dynamic Re-review Batch Creation

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Create custom batches | Flexibility for administrators | High | **MISSING** - batches hardcoded | UX review finding |
| Batch criteria definition | Select entities by filter | High | Missing | Could use existing filter system |
| Batch size configuration | Control workload distribution | Medium | Missing | Fixed batch sizes currently |
| Batch progress tracking | Monitor completion | Low | Exists - counts in table | Good implementation |

### 5. Inline Editing

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Quick status edits in table | Reduce modal interactions | Medium | Missing | Could reduce clicks significantly |
| Inline comments | Fast annotation | Medium | Missing | Hover to edit pattern |
| Cell-level editing | Direct manipulation | High | Missing | Complex but powerful |

**Reference:** [DataTables Bulk Editing](https://datatables.net/blog/2015-09-11) - "Allow some fields to retain individual values while others are batch-updated."

### 6. Advanced Search and Autocomplete

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| Async entity search | Find entities by gene/disease | Medium | **DISABLED** - treeselect issues | TODO comments throughout code |
| Typeahead suggestions | Fast data entry | Medium | Disabled | Was working, Vue 3 migration issue |
| Recent searches | Productivity boost | Low | Missing | Store last 5-10 searches |
| Saved searches/filters | Workflow personalization | Medium | Missing | URL-based filters would enable this |

### 7. Audit Trail Visibility

| Feature | Value Proposition | Complexity | Current State | Notes |
|---------|-------------------|------------|---------------|-------|
| View change history | Accountability and traceability | Medium | Backend exists, UI missing | Show who changed what when |
| Compare versions | See what changed | High | Missing | Side-by-side diff |
| Revert capability | Error correction | High | Missing | Controlled rollback |

**Reference:** [Audit Trail Best Practices](https://www.openclinica.com/blog/audit-trails-transparency-tracking-changes-in-clinical-data/) - "Audit trails ensure data integrity and regulatory compliance."

---

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

### 1. Overly Complex Approval Chains

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-level approval hierarchies | Adds friction, slows curation | Single reviewer + curator approval model (current approach is correct) |
| Approval by committee votes | Scheduling nightmare | Expert panel model with designated approvers |
| Automated approval | Loses human judgment value | Keep human-in-the-loop for all classifications |

**Rationale:** ClinGen found that streamlined approval with clear accountability produces better outcomes than bureaucratic chains.

### 2. Real-time Collaborative Editing

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Google Docs-style co-editing | Complexity > benefit for curation | Sequential editing with conflict detection |
| Live cursor positions | Distracting for focused work | Show who's currently viewing/editing |
| Instant sync | Race conditions in data integrity | Save-and-refresh model |

**Rationale:** Scientific curation requires focused attention, not collaborative chaos. Current conflict detection (duplicate warning) is the right approach.

### 3. AI-Automated Classification

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| ML-driven status assignment | Accountability and reproducibility | AI can suggest, humans must approve |
| Automated literature extraction | Error-prone for edge cases | AI-assisted with curator verification |
| Black-box recommendations | Regulatory compliance requires traceability | Transparent evidence-based classification |

**Reference:** [LLM-assisted curation tools](https://www.tandfonline.com/doi/full/10.1080/27660400.2025.2590811) - "LLMs cannot yet replace the flexible judgment of human curators."

### 4. Complex Permission Matrices

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Field-level permissions | Maintenance nightmare | Role-based access (Curator, Reviewer, Admin) |
| Custom permission sets | Configuration debt | Predefined roles with clear capabilities |
| Per-entity permissions | Unmanageable at scale | Collection-level access controls |

**Rationale:** SysNDD's simple role model (Curator, Reviewer, Administrator) is appropriate for team size and use case.

### 5. Excessive Customization

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Customizable form fields | Data inconsistency | Standardized curation schema |
| User-defined workflows | Training overhead | Consistent workflow for all curators |
| Theme customization | Distraction from curation | Professional, accessible defaults |

### 6. Over-Engineering the Treeselect Replacement

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom multi-level tree component | High complexity, maintenance burden | Use existing BFormSelect with optgroups |
| Virtual scrolling tree | Overkill for current data volume | Standard select is sufficient |
| Drag-and-drop tree editing | Feature creep | Not needed for selection use case |

**Rationale:** The treeselect was disabled due to Vue 3 compatibility issues. A simpler BFormSelect approach already works in the codebase - extend this pattern rather than rebuilding treeselect.

---

## Feature Dependencies

```
Authentication & Roles (EXISTS)
    |
    v
User Approval (BROKEN - must fix first)
    |
    v
Entity Creation (EXISTS - CreateEntity wizard)
    |
    +---> Review Submission (EXISTS)
    |         |
    |         v
    +---> Review Approval (EXISTS - ApproveReview)
    |         |
    |         +---> Status Assignment
    |         |         |
    |         |         v
    |         +---> Status Approval (EXISTS - ApproveStatus)
    |
    +---> Entity Modification (EXISTS - ModifyEntity)
              |
              +---> Disease Rename
              +---> Deactivation
              +---> Review Modification
              +---> Status Modification (BROKEN - empty dropdown)

Re-review Workflow (EXISTS - ManageReReview)
    |
    +---> Batch Assignment (EXISTS)
    +---> Batch Creation (MISSING - hardcoded)
```

### Critical Dependencies for Fixes

1. **ApproveUser** depends on:
   - API endpoint `/api/user/table` returning pending users
   - Role options loading from `/api/user/role_list`
   - Correct modal behavior for approval

2. **ModifyEntity status dropdown** depends on:
   - `loadStatusList()` being called on mount
   - `status_options` array populating before modal opens
   - `normalizeStatusOptions()` returning correct format

3. **Column filters** depend on:
   - Bootstrap-Vue-Next filter capabilities
   - Field configuration with `filterable: true`

---

## MVP Recommendation

For the curation modernization milestone, prioritize:

### Must Fix (Broken Functionality) - P0

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P0 | **ApproveUser view** | Medium | Cannot approve new users - blocks curator onboarding |
| P0 | **ModifyEntity status dropdown** | Low | Empty dropdown prevents status changes |
| P0 | **Accessibility labels** | Low | WCAG compliance requirement |

### Should Improve (Table Stakes Gaps) - P1

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P1 | Column filters on approval tables | Medium | Expected UX, improves curator efficiency |
| P1 | Consistent pagination | Low | Professional UX, reduces confusion |
| P1 | Restore async search | Medium | Treeselect replacement needed for entity/disease search |

### Nice to Have (Differentiators) - P2

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P2 | Dynamic batch creation | High | ManageReReview enhancement |
| P2 | Batch undo operations | High | Error recovery for bulk actions |
| P2 | Filter persistence | Medium | Productivity enhancement |
| P2 | Audit trail UI | Medium | Accountability visibility |

### Defer to Post-MVP

- **Inline editing** - High complexity, moderate benefit
- **Server-side pagination** - Requires backend changes
- **Revision tracking** - Major feature addition
- **Compare versions** - Complex UI/UX

---

## Implementation Notes from Codebase Analysis

### ApproveUser Issues Identified

```vue
// Line 146: Component name is wrong
name: 'ApproveStatus',  // Should be 'ApproveUser'

// Line 232: API call to approve user
const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/approval?user_id=${this.approve_user[0].user_id}&status_approval=${this.user_approved}`;
// Need to verify this endpoint works and handles role assignment
```

### ModifyEntity Status Dropdown Issue

```vue
// Line 696-703: loadStatusList() exists and is called
async loadStatusList() {
  const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
  // ...
  this.status_options = response.data;
}

// Line 560-572: BFormSelect expects normalizeStatusOptions()
<BFormSelect
  v-if="status_options && status_options.length > 0"
  id="status-select"
  v-model="status_info.category_id"
  :options="normalizeStatusOptions(status_options)"
  size="sm"
>
// Issue: status_options may be empty or normalizeStatusOptions may fail
```

### Treeselect Replacement Pattern (already working in CreateEntity)

```vue
// CreateEntity uses BFormSelect with optgroups successfully
// Pattern to follow for ModifyEntity and ApproveReview
<BFormSelect
  v-if="phenotypeOptions && phenotypeOptions.length > 0"
  id="review-phenotype-select"
  v-model="select_phenotype[0]"
  :options="normalizePhenotypesOptions(phenotypes_options)"
  size="sm"
>
```

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Table Stakes | HIGH | Based on established UX patterns, WCAG standards, ClinGen VCI |
| Differentiators | HIGH | Based on ClinGen documentation, curation tool research |
| Anti-Features | MEDIUM | Based on domain knowledge, some inference |
| Dependencies | HIGH | Based on codebase analysis of existing views |
| MVP Priorities | HIGH | Based on UX review findings + severity assessment |
| Implementation Notes | HIGH | Based on direct code reading |

---

## Sources

### Primary (HIGH confidence)
- [ClinGen Variant Curation Interface](https://genomemedicine.biomedcentral.com/articles/10.1186/s13073-021-01004-8) - FDA-recognized curation platform
- [ClinGen Variant Curation SOP](https://clinicalgenome.org/docs/variant-curation-standard-operating-procedure/)
- [ClinGen Overview](https://pmc.ncbi.nlm.nih.gov/articles/PMC11984750/)
- SysNDD codebase analysis (existing views: ApproveUser.vue, ApproveReview.vue, ApproveStatus.vue, CreateEntity.vue, ModifyEntity.vue, ManageReReview.vue)

### Secondary (MEDIUM confidence)
- [Data Table Design UX Patterns](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables)
- [Bulk Actions UX Guidelines](https://www.eleken.co/blog-posts/bulk-actions-ux)
- [Multi-step Form Best Practices](https://www.growform.co/must-follow-ux-best-practices-when-designing-a-multi-step-form/)
- [WCAG Tables Accessibility](https://testparty.ai/blog/wcag-tables-accessibility)
- [Adrian Roselli: Sortable Table Columns](https://adrianroselli.com/2021/04/sortable-table-columns.html)
- [Audit Trail Best Practices](https://www.openclinica.com/blog/audit-trails-transparency-tracking-changes-in-clinical-data/)

### Tertiary (LOW confidence - general patterns)
- [Data Curation Best Practices](https://research.aimultiple.com/data-curation/)
- [LLM-assisted Curation Tools Study](https://www.tandfonline.com/doi/full/10.1080/27660400.2025.2590811)
- [DAQCORD Guidelines](https://pmc.ncbi.nlm.nih.gov/articles/PMC7681114/)

---

*Research completed: 2026-01-26*
*Confidence: HIGH (ClinGen patterns verified, codebase analyzed)*
*Researcher: GSD Project Researcher (Features dimension - Curation Workflow)*

---
---

# Feature Landscape: Multi-Container Migration Coordination

**Domain:** Database migrations in horizontally-scaled container environments
**Milestone:** Production deployment scaling fix
**Researched:** 2026-02-01
**Overall Confidence:** HIGH (patterns verified with official docs and existing codebase)

---

## Executive Summary

SysNDD's current migration system uses MySQL advisory locks (`GET_LOCK`) to coordinate migrations across containers. This works correctly for the migration itself but creates a scaling bottleneck: all containers must acquire the lock sequentially during startup, even when no migrations are pending. With 4 containers and a 30-second timeout, containers that cannot acquire the lock in time crash and restart in an infinite loop.

The solution is implementing **double-checked locking**: check migration status BEFORE acquiring the lock, skip the entire lock/migration cycle if already up-to-date.

---

## Migration Coordination Patterns

### Pattern 1: Lock-First (Current SysNDD Pattern)

**How it works:**
1. Container starts
2. Acquires advisory lock (blocks up to 30s)
3. Checks migration status
4. Runs migrations if needed
5. Releases lock
6. Continues startup

**Problem:** O(n) sequential startup. With 4 containers and 30s timeout:
- Container 1: Acquires lock immediately
- Container 2-4: Queue behind Container 1
- If migrations + startup take >30s, containers timeout and crash

**When appropriate:** Single container deployments only.

### Pattern 2: Double-Checked Locking (Recommended)

**How it works:**
1. Container starts
2. **Check migration status first (no lock)**
3. If up-to-date: skip to startup (O(1))
4. If migrations pending: acquire lock, re-check, run migrations
5. Continue startup

**Benefit:** When schema is current (99% of startups), all containers start in parallel.

**Source:** [golang-migrate issue #468](https://github.com/golang-migrate/migrate/issues/468) documents this exact pattern request. The maintainer noted: "Since this behavior is a bit riskier in nature, don't make it the default and gate it with an option."

### Pattern 3: Kubernetes Init Container

**How it works:**
1. Kubernetes Job runs migrations before deployment
2. Init container waits for Job completion
3. Main containers start only after migrations done

**Source:** [FreeCodeCamp: How to Run Database Migrations in Kubernetes](https://www.freecodecamp.org/news/how-to-run-database-migrations-in-kubernetes/)

**When appropriate:** Pure Kubernetes deployments with Helm/ArgoCD.

**Why not for SysNDD:** Docker Compose deployment, not Kubernetes.

### Pattern 4: Decouple Migrations from Startup

**How it works:**
1. Run migrations in CI/CD pipeline before deployment
2. Application startup never runs migrations
3. Health check verifies schema version matches expected

**Source:** [Codefresh: Database Migrations in Kubernetes Microservices](https://codefresh.io/blog/database-migrations-in-the-era-of-kubernetes-microservices/) - "we should treat database migrations as a standalone entity that has its own lifecycle which is completely unrelated to the source code."

**When appropriate:** Teams with sophisticated CI/CD.

**Why not for SysNDD (now):** Requires pipeline changes; double-checked locking solves immediate scaling issue without CI/CD changes.

---

## Table Stakes

Features that MUST exist for horizontal scaling to work.

| Feature | Why Required | Complexity | Current State |
|---------|--------------|------------|---------------|
| **Pre-lock migration check** | Prevents O(n) startup bottleneck | Low | NOT IMPLEMENTED |
| **Graceful lock timeout handling** | Prevents crash loops when lock unavailable | Low | PARTIAL (crashes on timeout) |
| **Schema version tracking** | Required for idempotent migrations | Low | IMPLEMENTED (schema_version table) |
| **Advisory lock coordination** | Prevents concurrent migration corruption | Low | IMPLEMENTED (GET_LOCK) |
| **Idempotent migrations** | Safe to run multiple times | Low | IMPLEMENTED |

### Critical Gap: Pre-Lock Migration Check

The current implementation always acquires a lock, even when no migrations are pending:

```r
# Current flow (lines 210-253 of start_sysndd_api.R):
migration_conn <- pool::poolCheckout(pool)
acquire_migration_lock(migration_conn, timeout = 30)  # ALWAYS blocks
result <- run_migrations(...)  # May find nothing to do
release_migration_lock(migration_conn)
```

**Required change:**
```r
# Recommended flow:
pending <- get_pending_migrations(pool)  # Quick query, no lock
if (length(pending) == 0) {
  log_info("Schema up to date, skipping migration lock")
} else {
  acquire_migration_lock(...)
  # Re-check after lock (someone else may have migrated)
  pending <- get_pending_migrations(pool)
  if (length(pending) > 0) {
    run_migrations(...)
  }
  release_migration_lock(...)
}
```

---

## Differentiators

Features that improve upon typical solutions.

| Feature | Value Proposition | Complexity | Priority |
|---------|-------------------|------------|----------|
| **Health endpoint shows migration status** | Ops visibility into schema state | Low | ALREADY EXISTS (migration_status global) |
| **Lock timeout configuration** | Tune for deployment topology | Low | EASY ADD (env var) |
| **Migration metrics** | Track migration duration, frequency | Medium | POST-MVP |
| **Leader election** | Single designated migration runner | High | FUTURE (overkill for 4 containers) |

### Already Implemented Differentiators

SysNDD already has good infrastructure:

1. **schema_version table** - Tracks applied migrations with timestamps
2. **Fail-fast on migration error** - Crashes API if migration fails
3. **Health endpoint integration** - `migration_status` global exposed to health checks
4. **DELIMITER handling** - Properly parses stored procedures

---

## Anti-Features

Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Automatic retry on lock timeout** | Creates thundering herd, extends startup | Check first, skip if up-to-date |
| **Background migration thread** | Complex, race conditions with requests | Run migrations before accepting traffic |
| **Skip lock entirely** | Data corruption if two containers migrate simultaneously | Use double-checked locking pattern |
| **Extend timeout to "long enough"** | Fragile, doesn't scale, hides the problem | Fix the O(n) bottleneck |
| **IS_FREE_LOCK check** | Race condition: free when checked, taken when acquired | Use GET_LOCK return value only |

### Anti-Pattern: IS_FREE_LOCK

From [MySQL documentation](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html):

> Thread 1: IS_LOCK_FREE (1: free), Thread 2: IS_LOCK_FREE (1: free), Thread 1: DO GET_LOCK (1: acquired), Thread 2: DO GET_LOCK (0; timeout). You have failed to protect the critical section.

**Correct approach:** Check migration status (which is immutable once applied), not lock status.

---

## Recommended Pattern

### Double-Checked Locking for SysNDD

**Implementation approach:**

```r
#' Check if migrations are pending without acquiring lock
#'
#' Compares migration files to schema_version table.
#' Safe to call concurrently from multiple containers.
#'
#' @return Character vector of pending migration filenames (empty if up-to-date)
get_pending_migrations <- function(conn = NULL) {
  migration_files <- list_migration_files("db/migrations")
  applied <- get_applied_migrations(conn)
  setdiff(migration_files, applied)
}

#' Run migrations with double-checked locking
#'
#' 1. Check if migrations pending (no lock)
#' 2. If none: return immediately
#' 3. If pending: acquire lock, re-check, run, release
run_migrations_with_dbl <- function(conn = NULL, migrations_dir = "db/migrations") {
  # First check: without lock (fast path for 99% of startups)
  pending <- get_pending_migrations(conn)

  if (length(pending) == 0) {
    log_info("Schema up to date - skipping migration lock")
    applied <- get_applied_migrations(conn)
    return(list(
      total_applied = length(applied),
      newly_applied = 0,
      filenames = character(0),
      lock_acquired = FALSE
    ))
  }

  # Slow path: acquire lock and re-check
  log_info("Pending migrations detected, acquiring lock")
  acquire_migration_lock(conn)
  on.exit(release_migration_lock(conn), add = TRUE)

  # Second check: after lock (someone else may have migrated)
  pending <- get_pending_migrations(conn)

  if (length(pending) == 0) {
    log_info("Another container applied migrations - nothing to do")
    applied <- get_applied_migrations(conn)
    return(list(
      total_applied = length(applied),
      newly_applied = 0,
      filenames = character(0),
      lock_acquired = TRUE
    ))
  }

  # Actually run migrations
  result <- run_migrations(migrations_dir = migrations_dir, conn = conn)
  result$lock_acquired <- TRUE
  result
}
```

**Why this is safe:**
- `schema_version` is append-only (migrations are never un-applied)
- Reading `schema_version` before lock is safe (worst case: see stale data, acquire lock, find nothing to do)
- Re-checking after lock handles race condition where another container migrated first
- Lock still protects actual migration execution

---

## Feature Dependencies

```
                    [schema_version table exists]
                              |
                              v
         +--------------------+--------------------+
         |                                        |
         v                                        v
[get_applied_migrations()]              [list_migration_files()]
         |                                        |
         +--------------------+--------------------+
                              |
                              v
                   [get_pending_migrations()]
                              |
              +---------------+---------------+
              |                               |
              v                               v
    [No pending: skip lock]      [Pending: acquire lock]
                                              |
                                              v
                                   [Re-check pending]
                                              |
                              +---------------+---------------+
                              |                               |
                              v                               v
                    [Still pending: run]         [None: release & skip]
```

---

## MVP Recommendation

For fixing the horizontal scaling issue, implement:

### Phase 1: Double-Checked Locking (Required)

1. **Add `get_pending_migrations()` function** - Already implementable with existing `list_migration_files()` and `get_applied_migrations()`
2. **Modify startup flow** - Check before lock, re-check after
3. **Update logging** - Distinguish "skipped (up-to-date)" from "skipped (another container migrated)"

Complexity: LOW (< 50 lines of code changes)

### Phase 2: Timeout Configuration (Nice-to-have)

1. Add `MIGRATION_LOCK_TIMEOUT` environment variable
2. Default to 30s, allow override for slow deployments

Complexity: TRIVIAL (2 lines)

### Defer to Post-MVP

- Migration metrics/telemetry
- Leader election
- CI/CD-based migration runner
- Kubernetes operator

---

## Sources

### HIGH Confidence (Official Documentation)
- [MySQL 8.4 Locking Functions](https://dev.mysql.com/doc/refman/8.4/en/locking-functions.html) - GET_LOCK behavior
- [Kubernetes Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) - Init container pattern

### MEDIUM Confidence (Verified with Multiple Sources)
- [golang-migrate Double Check Locking Issue #468](https://github.com/golang-migrate/migrate/issues/468) - Exact pattern description
- [Codefresh: Database Migrations in Kubernetes](https://codefresh.io/blog/database-migrations-in-the-era-of-kubernetes-microservices/) - Decoupling pattern
- [FreeCodeCamp: Database Migrations in Kubernetes](https://www.freecodecamp.org/news/how-to-run-database-migrations-in-kubernetes/) - Init container vs Job patterns
- [Andrew Lock: Running Database Migrations in Kubernetes](https://andrewlock.net/deploying-asp-net-core-applications-to-kubernetes-part-7-running-database-migrations/) - Sequential startup problem description
- [Decoupling Database Migrations from Server Startup](https://pythonspeed.com/articles/schema-migrations-server-startup/) - Why startup migrations are problematic

### LOW Confidence (Single Source, Needs Validation)
- [Kraken Engineering: MySQL Race Conditions](https://engineering.kraken.tech/news/2025/01/20/mysql-race-conditions.html) - Advisory lock caveats

---

## Validation Checklist

Before implementation:

- [x] Pattern verified in existing codebase (migration-runner.R has all building blocks)
- [x] No breaking changes to existing `run_migrations()` interface
- [x] Race condition analysis complete (double-check after lock)
- [x] O(n) to O(1) startup improvement verified for up-to-date case
- [ ] Integration test for concurrent container startup (needs implementation)

---

*Research completed: 2026-02-01*
*Confidence: HIGH (MySQL docs verified, golang-migrate pattern documented, existing codebase analyzed)*
*Researcher: GSD Project Researcher (Features dimension - Multi-Container Coordination)*
---
---

# Feature Landscape: OMIM Phenotype Mapping

**Domain:** Neurodevelopmental disorder gene-disease associations
**Researched:** 2026-02-07
**Confidence:** MEDIUM

## Executive Summary

OMIM phenotype mapping for NDD databases requires two distinct workflows with different data sources and feature requirements:

1. **Ontology system** (disease ontology set for entity curation): Uses mim2gene.txt + JAX API to provide disease names for curator selection during entity creation
2. **Comparisons system** (cross-database gene analysis): Uses genemap2.txt + phenotype.hpoa to identify NDD-relevant genes based on HPO phenotype filtering

The project has ALREADY migrated the ontology system to mim2gene.txt + JAX API (Phase 23, completed). This milestone focuses on the comparisons system, which still uses the OLD genemap2.txt parsing approach.

Key architectural insight: genemap2.txt contains BOTH gene-disease associations AND inheritance mode information in a complex semicolon-delimited "Phenotypes" column that requires multi-stage regex parsing. The old script (db/02_Rcommands) demonstrates the extraction pattern.

## Table Stakes

Features users expect from OMIM phenotype mapping. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Disease name extraction | Core requirement for displaying human-readable disease labels | Medium | Currently parsed from genemap2 Phenotypes column using regex: `"Disease name, 123456 (3), Autosomal recessive"` → "Disease name" |
| MIM number to gene association | Required to link OMIM diseases to genes for cross-database comparison | Medium | genemap2 Phenotypes column format: MIM number embedded between disease name and mapping key |
| Evidence level (mapping key) | OMIM provides 1-4 scale indicating gene-disease evidence strength | Low | Parenthetical number in Phenotypes: (1)=wildtype gene mapped, (2)=disease mapped, (3)=molecular basis known, (4)=chromosome deletion/duplication |
| Inheritance mode extraction | Essential for filtering/categorizing diseases by inheritance pattern | High | Complex parsing from Phenotypes trailing text: `"), Autosomal recessive"` requires mapping to HPO terms |
| NDD-specific filtering | Must identify neurodevelopmental disorders among 8000+ OMIM diseases | High | Requires cross-reference with HPO phenotype.hpoa annotations using NDD-related HPO terms (HP:0012759 and children) |
| Multi-disease per gene support | Single gene can associate with multiple OMIM diseases | Low | genemap2 Phenotypes column uses semicolon delimiter: `"Disease A; Disease B; Disease C"` |
| Versioning for duplicates | Same MIM may appear multiple times with different genes/inheritance | Medium | Existing pattern: `OMIM:123456_1`, `OMIM:123456_2` when count > 1 |

## Differentiators

Features that set SysNDD apart. Not expected by all users, but valued for research quality.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Dual-source validation | Cross-validate genemap2 gene-disease associations against mim2gene + JAX API | Medium | Detect discrepancies between OMIM data sources (genemap2 vs mim2gene); flag for curator review |
| HPO term hierarchy filtering | Use hierarchical HPO relationships to identify NDD-relevant phenotypes beyond direct matches | High | Current code uses static list (HP:0012759, HP:0002342, etc.); could fetch HPO children dynamically via JAX API |
| Deprecation detection | Flag entities using moved/removed OMIM IDs for curator re-review | Low | Already implemented for ontology system; extend to comparisons |
| MONDO equivalence mapping | Provide MONDO disease IDs for OMIM diseases to enable cross-ontology research | Medium | Already implemented via SSSOM files; ensure comparisons data includes MONDO mappings |
| Evidence-weighted filtering | Use mapping key (1-4) to filter comparison results by evidence strength | Low | Simple numeric comparison after parsing; UI could show "molecular basis known" vs "gene mapped" |
| Inheritance-specific comparisons | Enable database comparisons filtered by inheritance mode (e.g., only autosomal recessive) | Medium | Requires accurate inheritance mode extraction and HPO term normalization |

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Real-time OMIM API integration | OMIM API requires authentication, has rate limits, and is slower than file-based approach | Download static files (genemap2.txt, mim2gene.txt) nightly; use JAX API only for missing disease names in ontology system |
| Parsing all OMIM phenotypes | OMIM contains ~8000 phenotypes; comparisons only need NDD-relevant subset | Filter via HPO phenotype.hpoa cross-reference using NDD HPO terms (HP:0012759 children) |
| Hand-rolled inheritance mode mapping | Genemap2 uses non-standard inheritance abbreviations ("Autosomal dominant" vs HPO "Autosomal dominant inheritance") | Use existing normalization map from db/02_Rcommands line 285-299; map to HPO terms via mode_of_inheritance_list |
| Storing raw Phenotypes column | Complex semicolon-delimited field with embedded regex patterns is not queryable | Parse into normalized columns: disease_ontology_name, disease_ontology_id, mapping_key, hpo_mode_of_inheritance_term |
| Mixing ontology and comparison workflows | Two different use cases with different data sources and requirements | Keep ontology system (mim2gene + JAX) separate from comparisons system (genemap2 + HPO); share deprecation detection logic only |
| Single-source OMIM data | Relying only on genemap2 OR only on mim2gene creates blind spots | Use genemap2 for comparisons (has inheritance + evidence), use mim2gene + JAX for ontology (has deprecation status) |

## Feature Dependencies

```
Core OMIM Parsing (genemap2.txt)
    ├─→ Disease Name Extraction
    │   └─→ Regex: separate on ", (?=[0-9]{6})" to split name from MIM number
    │
    ├─→ MIM Number Extraction
    │   └─→ Regex: extract 6-digit number after disease name
    │
    ├─→ Mapping Key Extraction
    │   └─→ Regex: extract parenthetical number after MIM number
    │
    └─→ Inheritance Mode Extraction
        ├─→ Regex: extract trailing text after ")"
        ├─→ Normalization: map OMIM terms to HPO standard terms
        └─→ HPO Term Lookup: join with mode_of_inheritance_list

HPO Phenotype Filtering (phenotype.hpoa)
    ├─→ NDD HPO Term Definition
    │   └─→ Static list OR HPO API fetch of HP:0012759 children
    │
    ├─→ OMIM-HPO Association
    │   └─→ Join phenotype.hpoa database_id (MIM:123456) with genemap2 MIM numbers
    │
    └─→ NDD Gene Extraction
        └─→ Filter phenotype.hpoa for NDD HPO terms, then join with genemap2 genes

Dual-Source Validation (genemap2 + mim2gene)
    ├─→ genemap2 gene-disease pairs
    ├─→ mim2gene phenotype entries
    └─→ Cross-reference: flag discrepancies for curator review

Versioning
    └─→ Group by disease_ontology_id, add _N suffix when count > 1
```

## Data Source Comparison

| Source | Contains | Best For | Limitations |
|--------|----------|----------|-------------|
| **genemap2.txt** | Gene-disease associations, chromosomal location, inheritance modes, mapping keys, phenotype descriptions | Comparisons system (gene-centric analysis with inheritance filtering) | Complex Phenotypes column requires multi-stage regex parsing; no deprecation status |
| **mim2gene.txt** | MIM number to gene symbol mapping, entry type (gene/phenotype/moved/removed) | Ontology system (disease ID to gene lookup), deprecation detection | NO inheritance modes, NO disease names (requires JAX API), phenotype entries lack gene associations |
| **mimTitles.txt** | MIM number to disease title mapping | Alternative to JAX API for disease names | Requires OMIM API key; less comprehensive than JAX API |
| **morbidmap.txt** | Disease-centric view (sorted by disorder name instead of chromosome) | Disorder-first lookups | Subset of genemap2 data; same Phenotypes parsing complexity |
| **phenotype.hpoa** | HPO phenotype annotations for diseases (including OMIM), evidence codes | NDD filtering via HPO term cross-reference | Large file (~200k annotations); requires NDD HPO term list for filtering |

**Recommendation for comparisons system:** genemap2.txt + phenotype.hpoa is sufficient and correct. Do NOT switch to mim2gene for comparisons (it lacks inheritance modes and requires JAX API calls for disease names, which is slow for 8000+ phenotypes).

## Parsing Strategy: genemap2.txt Phenotypes Column

The Phenotypes column (column 13 in genemap2.txt) has this structure:

```
Format: "Disease name, MIM_number (mapping_key), inheritance_mode; Next_disease, ..."

Examples:
1. "Epilepsy, progressive myoclonic 3, 611726 (3), Autosomal recessive"
2. "Charcot-Marie-Tooth disease, type 2A1, 118210 (3), Autosomal dominant"
3. "Mental retardation, 615139 (3); ?Microcephaly 10, 615095 (3), Autosomal recessive"
```

**Multi-stage regex extraction (verified from db/02_Rcommands.R lines 272-277):**

```r
# Stage 1: Split multiple diseases by semicolon
separate_rows(Phenotypes, sep = "; ")

# Stage 2: Split disease name from inheritance mode
#   Pattern: "), " followed by inheritance text (no more closing parens after)
separate(Phenotypes, c("disease_name_with_mim", "inheritance"), "\\), (?!.+\\))")

# Stage 3: Split disease name from mapping key
#   Pattern: "(" not followed by another "(" (last opening paren)
separate(disease_name_with_mim, c("disease_name_with_mim", "mapping_key"), "\\((?!.+\\()")

# Stage 4: Split disease name from MIM number
#   Pattern: ", " followed by 6-digit number
separate(disease_name_with_mim, c("disease_name", "mim_number"), ", (?=[0-9]{6})")

# Stage 5: Clean and normalize
mutate(
  mapping_key = str_replace_all(mapping_key, "\\)", ""),  # Remove trailing ")"
  mim_number = str_replace_all(mim_number, " ", ""),      # Remove whitespace
  inheritance = str_replace_all(inheritance, "\\?", "")   # Remove "?" uncertainty marker
)
```

**Inheritance mode normalization (db/02_Rcommands lines 285-299):**
Maps OMIM abbreviations to HPO standard terms:
- "Autosomal dominant" → "Autosomal dominant inheritance"
- "Autosomal recessive" → "Autosomal recessive inheritance"
- "X-linked" → "X-linked inheritance"
- "Mitochondrial" → "Mitochondrial inheritance"
- "Isolated cases" → "Sporadic"
- etc.

## HPO Phenotype Filtering Strategy

phenotype.hpoa file structure (verified from HPO documentation):

```
database_id    disease_name    qualifier    hpo_id    reference    evidence    ...
OMIM:123456    Disease Name    NOT          HP:0001234    PMID:12345    PCS        ...
```

**NDD filtering workflow:**

1. **Define NDD HPO terms** (comparisons-functions.R lines 393-396):
   ```r
   ndd_phenotypes <- c(
     "HP:0012759",  # Neurodevelopmental abnormality (root term)
     "HP:0002342",  # Intellectual disability (most common child)
     "HP:0006889",  # Intellectual disability, severe
     "HP:0010864"   # Intellectual disability, profound
     # ... additional children of HP:0012759
   )
   ```

2. **Filter phenotype.hpoa** for NDD-annotated OMIM diseases:
   ```r
   phenotype_hpoa %>%
     filter(str_detect(database_id, "^OMIM:")) %>%  # OMIM entries only
     filter(hpo_id %in% ndd_phenotypes) %>%         # NDD phenotypes only
     mutate(database_id = str_remove(database_id, "OMIM:"))  # Convert to MIM number
   ```

3. **Join with genemap2** to get genes:
   ```r
   ndd_omim_ids %>%
     left_join(genemap2_parsed, by = c("database_id" = "mim_number")) %>%
     filter(!is.na(Approved_Symbol))  # Only entries with gene associations
   ```

**Trade-off:** Static HPO term list vs dynamic API fetch
- Static list (current): Fast, reliable, but requires manual updates when HPO hierarchy changes
- Dynamic API: Always current, but adds external dependency and latency
- **Recommendation:** Start with static list; add HPO API option for advanced users who want latest hierarchy

## MVP Recommendation

For reimplementing OMIM comparisons data integration, prioritize:

**Phase 1: Core Parsing (Must Have)**
1. genemap2.txt download and parsing with multi-stage regex extraction
2. Disease name, MIM number, mapping key extraction
3. Inheritance mode extraction with OMIM→HPO normalization
4. Multi-disease-per-gene support (semicolon splitting)

**Phase 2: NDD Filtering (Must Have)**
1. phenotype.hpoa download and parsing
2. Static NDD HPO term list (HP:0012759 + common children)
3. OMIM-HPO cross-reference to identify NDD genes
4. Join with genemap2 parsed data

**Phase 3: Data Quality (Should Have)**
1. Versioning for duplicate MIM numbers
2. Evidence level filtering (mapping key 1-4)
3. Validation before database write
4. Transaction-based atomic updates

Defer to post-MVP:
- **Dual-source validation** (genemap2 vs mim2gene cross-check): Nice-to-have for data quality, but comparisons system doesn't need mim2gene
- **Dynamic HPO hierarchy fetch**: Static list is sufficient for NDD filtering; API fetch is optimization
- **mimTitles.txt integration**: JAX API already provides disease names for ontology system; comparisons uses genemap2 Phenotypes
- **MONDO mapping for comparisons**: Already exists for ontology system; can extend later if needed

## Implementation Notes

### Existing Code to Reuse

1. **Inheritance mode normalization map** (db/02_Rcommands.R lines 285-299):
   - Move to shared constants or configuration
   - Use in both ontology and comparisons systems

2. **HPO mode_of_inheritance_list** (db/02_Rcommands.R lines 210-227):
   - Fetch from HPO API: `HP:0000005` children with names and definitions
   - Cache in database or static file
   - Join after normalization to get HPO term IDs

3. **Versioning logic** (db/02_Rcommands.R lines 303-308):
   - Group by disease_ontology_id
   - Add cumulative version number when count > 1
   - Format: `OMIM:123456_1`, `OMIM:123456_2`, etc.

4. **HGNC symbol resolution** (comparisons-functions.R):
   - Already implemented in comparisons system
   - Batch lookup via database join (not HGNC API for performance)

### New Code Needed

1. **parse_omim_genemap2() refactoring**:
   - Current implementation (comparisons-functions.R lines 390-503) is functional
   - Extract regex patterns to constants for readability
   - Add validation for malformed Phenotypes entries
   - Document expected format with examples

2. **NDD HPO term management**:
   - Static list as configuration constant
   - Optional: Admin endpoint to refresh from HPO API
   - Store in database table for auditability

3. **Data validation**:
   - Check required fields: gene_symbol, disease_ontology_id, mapping_key
   - Warn on missing inheritance modes (some OMIM entries lack this)
   - Log parsing failures for curator review

## Sources

### PRIMARY (HIGH confidence)
- [OMIM FAQ - Phenotype Mapping Keys](https://www.omim.org/help/faq) - Official documentation of mapping key values 1-4
- [HPO phenotype.hpoa format specification](https://obophenotype.github.io/human-phenotype-ontology/annotations/phenotype_hpoa/) - Official 12-column format with OMIM cross-reference
- SysNDD existing code:
  - `/home/bernt-popp/development/sysndd/db/02_Rcommands_sysndd_db_table_disease_ontology_set.R` (lines 265-313: genemap2 Phenotypes parsing)
  - `/home/bernt-popp/development/sysndd/api/functions/comparisons-functions.R` (lines 390-503: current genemap2 + HPO parsing)
  - `/home/bernt-popp/development/sysndd/api/functions/omim-functions.R` (mim2gene + JAX API implementation from Phase 23)

### SECONDARY (MEDIUM confidence)
- [OMIM Downloads Page](https://www.omim.org/downloads/) - File availability and authentication requirements
- [Biostars: morbidmap vs genemap2 differences](https://www.biostars.org/p/128868/) - Community discussion of OMIM file purposes
- [OMIM.org: leveraging knowledge across phenotype–gene relationships](https://academic.oup.com/nar/article/47/D1/D1038/5184722) - Academic publication describing OMIM data structure
- [Monarch Initiative OMIM parsing](https://github.com/monarch-initiative/omim/issues/73) - Community discussion of morbidmap.txt parsing challenges

### TERTIARY (LOW confidence - needs verification)
- [R OMIM parsing example](https://rdrr.io/github/zhezhangsh/rchive/src/R/ParseOmim.r) - Third-party parsing code (useful patterns but not authoritative)
- WebSearch results for inheritance mode extraction (multiple sources agree on standard abbreviations, but official OMIM documentation doesn't specify exact format)

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| genemap2.txt format | HIGH | Verified from existing SysNDD code (db/02_Rcommands) which successfully parses file; regex patterns tested in production |
| Phenotypes column structure | HIGH | Multiple code examples (SysNDD + third-party) use identical parsing strategy; consistent across years |
| phenotype.hpoa format | HIGH | Official HPO documentation specifies 12-column format with OMIM database_id field |
| Mapping key meanings | HIGH | Official OMIM FAQ defines values 1-4 with clear descriptions |
| Inheritance mode normalization | MEDIUM | Existing SysNDD code has normalization map, but OMIM doesn't publish official abbreviation list |
| NDD HPO filtering | MEDIUM | Current code uses static HP:0012759 + children; effective but may miss new HPO terms without updates |
| File comparison (genemap2 vs mim2gene) | HIGH | Phase 23 research documented tradeoffs; confirmed mim2gene lacks inheritance modes |

## Open Questions

1. **HPO term list maintenance:** Should NDD HPO term list be static or dynamically fetched?
   - **Static:** Faster, reliable, but requires manual updates
   - **Dynamic:** Always current, but adds HPO API dependency
   - **Recommendation:** Static list with admin refresh option

2. **Inheritance mode coverage:** What percentage of genemap2 phenotypes have inheritance information?
   - Existing code handles missing inheritance with `left_join` (some entries will have NA)
   - Should these be excluded or flagged in comparisons?
   - **Recommendation:** Include with NA; let users filter by inheritance presence

3. **Evidence level filtering:** Should comparisons default to mapping key ≥3 (molecular basis known)?
   - Current code extracts mapping_key but doesn't filter
   - Level 1-2 are lower evidence (gene/disease mapped, but not molecular basis)
   - **Recommendation:** Extract all, add UI filter option

4. **MONDO integration:** Should comparisons data include MONDO equivalence mappings?
   - Already implemented for ontology system via SSSOM files
   - Could enrich comparisons with cross-ontology links
   - **Recommendation:** Defer to post-MVP; comparisons primarily gene-centric

---

*Research completed: 2026-02-07*
*Confidence: MEDIUM (genemap2 parsing HIGH, HPO filtering MEDIUM, inheritance normalization MEDIUM)*
*Researcher: GSD Project Researcher (Features dimension - OMIM Phenotype Mapping)*
