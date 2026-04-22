# Phase 85: Ghost Entity Cleanup & Prevention - Research

**Researched:** 2026-02-10
**Domain:** Database data correction & API transaction integrity
**Confidence:** HIGH

## Summary

Ghost entities are database records in `ndd_entity` with `is_active = 1` but zero related records in `ndd_entity_review` or `ndd_entity_status`. They exist due to partial creation failures before atomic transaction support was added. Three ghost entities exist in production: 4469 (GAP43), 4474 (FGF14), and 4188 (VCP).

**Root cause:** Prior to commit 831ac85a (2026-02-06), entity creation used sequential non-atomic operations. If entity INSERT succeeded but review/status INSERT failed, the entity became orphaned.

**Solution implemented:** Commit 831ac85a added `svc_entity_create_full()` which wraps all creation steps in a single transaction. The current entity creation endpoint (`POST /api/entity/create`) ALREADY uses this atomic function, so new ghosts cannot be created.

**Cleanup approach:** Delete the three ghost entities via a GitHub issue in the `sysndd-administration` repository following the established data correction protocol. No code changes needed for prevention (already fixed).

**Primary recommendation:** Create a detailed GitHub issue with SQL commands to delete ghost entities, including detection query to find any additional ghosts and verification steps. No API code changes required.

## Standard Stack

### Core Infrastructure
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| DBI | latest | Database interface | R standard for DB operations |
| pool | latest | Connection pooling | Production-grade connection management |
| RMariaDB | latest | MySQL/MariaDB driver | Official MySQL connector for R |
| db-helpers.R | internal | Parameterized queries | Prevents SQL injection, handles transactions |

### Transaction Patterns
| Pattern | Purpose | When to Use |
|---------|---------|-------------|
| `db_with_transaction(function(txn_conn) {...})` | Atomic multi-statement operations | Any operation requiring all-or-nothing semantics |
| Repository `conn` parameter | Transaction participation | Functions called within transactions |
| Service layer transaction wrapper | Business logic atomicity | Orchestrating multiple repository calls |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GitHub issue | Direct production SQL | Issue provides audit trail, review process, and rollback plan |
| Deactivation | Deletion | Deletion cleanly removes orphans; they have no data to preserve |
| Application trigger | Database trigger | Application-level transactions sufficient, simpler to test |

**Installation:**
All infrastructure already installed. No additional packages required.

## Architecture Patterns

### Current Entity Creation Flow (Post-831ac85a)

```
POST /api/entity/create
└── entity_endpoints.R: function(req, res, direct_approval)
    ├── Phase 1: Data preparation (NO DB WRITES)
    │   ├── Parse request body
    │   ├── Call external APIs (GeneReviews lookup)
    │   └── Insert publications (pre-transaction, reference data persists)
    │
    └── Phase 2: Atomic creation via svc_entity_create_full()
        └── db_with_transaction(function(txn_conn) {
            ├── entity_create(entity_data, conn = txn_conn)
            ├── review_create(review_data, conn = txn_conn)
            ├── publication_connect_to_review(..., conn = txn_conn)
            ├── phenotype_connect_to_review(..., conn = txn_conn)
            ├── variation_ontology_connect_to_review(..., conn = txn_conn)
            ├── status_create(status_data, conn = txn_conn)
            └── [Optional] Approve review & status if direct_approval=true
        })
```

**Key insight:** The endpoint ALREADY uses `svc_entity_create_full()` (lines 351-361 of entity_endpoints.R). No wrapper needed — prevention is already implemented.

### Recommended Project Structure (Already Implemented)

```
api/
├── endpoints/               # HTTP layer (req/res handling)
│   └── entity_endpoints.R   # Uses svc_entity_create_full
├── services/                # Business logic + transactions
│   └── entity-service.R     # svc_entity_create_full defined here
├── functions/               # Repository layer (DB operations)
│   ├── entity-repository.R  # entity_create(conn = NULL)
│   ├── review-repository.R  # review_create(conn = NULL)
│   ├── status-repository.R  # status_create(conn = NULL)
│   └── db-helpers.R         # db_with_transaction, db_execute_*
└── core/
    └── errors.R             # RFC 9457 error helpers
```

### Pattern: Repository conn Parameter

**What:** Repository functions accept optional `conn = NULL` parameter
**When to use:** Any function that may be called within a transaction
**Example:**
```r
# Repository layer (entity-repository.R)
entity_create <- function(entity_data, conn = NULL) {
  sql <- "INSERT INTO ndd_entity (...) VALUES (?, ?, ?, ?, ?)"
  params <- list(entity_data$hgnc_id, ...)
  db_execute_statement(sql, params, conn = conn)  # Passes conn to db-helpers
  # ...
}

# Service layer (entity-service.R)
svc_entity_create_full <- function(..., pool) {
  db_with_transaction(function(txn_conn) {
    entity_id <- entity_create(entity_data, conn = txn_conn)  # Uses transaction conn
    review_id <- review_create(review_data, conn = txn_conn)
    # All use same txn_conn → atomic
  }, pool_obj = pool)
}
```

### Anti-Patterns to Avoid

- **Non-atomic multi-statement operations:** Never perform entity+review+status INSERTs without a transaction wrapper. Ghost entities occur when one INSERT succeeds and another fails.
- **Expression-based transactions:** `db_with_transaction({ ... })` provides ZERO atomicity. Always use function-based pattern: `db_with_transaction(function(txn_conn) { ... })`.
- **Forgetting conn parameter:** If a repository function is called within a transaction but doesn't accept `conn`, it will checkout a NEW connection and execute outside the transaction.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parameterized queries | Manual string escaping | `db_execute_query/statement` with `?` placeholders | SQL injection prevention, automatic type handling |
| Transaction management | Manual BEGIN/COMMIT/ROLLBACK | `db_with_transaction(function(txn_conn) {...})` | Automatic rollback on error, proper connection management |
| Connection pooling | Direct dbConnect/dbDisconnect | `pool` package | Production-grade connection reuse, automatic cleanup |
| Ghost entity detection | Ad-hoc queries | Detection query (see Code Examples) | Finds ALL ghosts, not just known ones |

**Key insight:** The ghost entity problem was a one-time consequence of sequential non-atomic operations. The fix (transaction-wrapped creation) is already in production. Building additional safeguards (triggers, detection jobs) is unnecessary complexity.

## Common Pitfalls

### Pitfall 1: Assuming Current Endpoint Needs Changes
**What goes wrong:** Reading the phase requirements ("integrate atomic creation") suggests the endpoint doesn't use it yet.
**Why it happens:** Commit 831ac85a (2026-02-06) already refactored the endpoint to use `svc_entity_create_full()`.
**How to avoid:** Check `entity_endpoints.R` lines 351-361. The current code already calls `svc_entity_create_full(...)` with all data. No additional wrapper needed.
**Warning signs:** Planning to "wrap existing endpoint code" when the endpoint already delegates to the service function.

### Pitfall 2: Deactivating Instead of Deleting
**What goes wrong:** Setting `is_active = 0` leaves orphan records in the database that still block duplicate checks due to unique constraint on (hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version, ndd_phenotype).
**Why it happens:** Intuition that deactivation is "safer" than deletion.
**How to avoid:** Ghost entities have NO related data (zero status/review records). Deletion is safe and cleanly resolves the unique constraint issue. User context decision explicitly chose deletion.
**Warning signs:** Duplicate entity creation still failing after "deactivation" of ghosts.

### Pitfall 3: Named Parameters with ? Placeholders
**What goes wrong:** `DBI::dbBind()` requires positional (unnamed) parameter lists when using `?` placeholders. Named lists fail silently or cause parameter mismatch.
**Why it happens:** Common pattern in R to use named lists.
**How to avoid:** Always use `unname(params)` before passing to `db_execute_statement/query`. The db-helpers.R already does this internally (line 307: `DBI::dbBind(result, unname(params))`).
**Warning signs:** Error messages about parameter count mismatch or "bind variable does not exist".

### Pitfall 4: Foreign Key Constraint on replaced_by
**What goes wrong:** Entity 1249 has `replaced_by = 4188`. Attempting to delete entity 4188 fails with foreign key constraint violation.
**Why it happens:** Self-referential foreign key on `ndd_entity.replaced_by → ndd_entity.entity_id`.
**How to avoid:** Before deleting entity 4188, execute `UPDATE ndd_entity SET replaced_by = NULL WHERE entity_id = 1249`.
**Warning signs:** SQL error: "Cannot delete or update a parent row: a foreign key constraint fails".

## Code Examples

Verified patterns from the current codebase:

### Detection Query for Ghost Entities
```sql
-- Find ALL entities with is_active=1 but no status or review records
-- Source: Phase 85 requirements, extended from investigation
SELECT
  e.entity_id,
  n.symbol,
  e.disease_ontology_id_version,
  e.hpo_mode_of_inheritance_term,
  e.entry_date,
  COUNT(DISTINCT s.status_id) as status_count,
  COUNT(DISTINCT r.review_id) as review_count
FROM ndd_entity e
LEFT JOIN non_alt_loci_set n ON e.hgnc_id = n.hgnc_id
LEFT JOIN ndd_entity_status s ON e.entity_id = s.entity_id
LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id
WHERE e.is_active = 1
GROUP BY e.entity_id
HAVING status_count = 0 AND review_count = 0
ORDER BY e.entity_id;
```

### Cleanup SQL for Known Ghost Entities
```sql
-- Step 1: NULL out replaced_by FK before deleting entity 4188
-- Entity 1249 points to ghost entity 4188 as its replacement
UPDATE ndd_entity
SET replaced_by = NULL
WHERE entity_id = 1249;

-- Step 2: Delete the three confirmed ghost entities
-- These have zero related records in status/review tables
DELETE FROM ndd_entity
WHERE entity_id IN (4469, 4474, 4188);

-- Verification: Should return 0 rows
SELECT entity_id FROM ndd_entity WHERE entity_id IN (4469, 4474, 4188);
```

### Transaction-Wrapped Entity Creation (Already in Production)
```r
# Source: api/services/entity-service.R, svc_entity_create_full()
# This is the CURRENT implementation as of commit 831ac85a

svc_entity_create_full <- function(entity_data, review_data, status_data,
                                   publications = NULL, phenotypes = NULL,
                                   variation_ontology = NULL,
                                   direct_approval = FALSE,
                                   approving_user_id = NULL,
                                   pool) {
  # Phase 1: Validation (outside transaction, uses pool)
  svc_entity_validate(entity_data)
  duplicate <- svc_entity_check_duplicate(entity_data, pool)
  if (!is.null(duplicate)) {
    return(list(status = 409, message = "Conflict. Entity already exists."))
  }

  # Phase 2: All DB writes in a single transaction
  tryCatch({
    result <- db_with_transaction(function(txn_conn) {
      # All operations use txn_conn → atomicity
      entity_id <- entity_create(entity_data, conn = txn_conn)
      review_id <- review_create(review_data, conn = txn_conn)
      publication_connect_to_review(review_id, entity_id, publications, conn = txn_conn)
      phenotype_connect_to_review(review_id, entity_id, phenotypes, conn = txn_conn)
      variation_ontology_connect_to_review(review_id, entity_id, variation_ontology, conn = txn_conn)
      status_id <- status_create(status_data, conn = txn_conn)

      if (direct_approval) {
        # Approve review and status in same transaction
        db_execute_statement(
          "UPDATE ndd_entity_review SET is_primary = 1, review_approved = 1, approving_user_id = ? WHERE review_id = ?",
          list(approving_user_id, review_id),
          conn = txn_conn
        )
        db_execute_statement(
          "UPDATE ndd_entity_status SET is_active = 1, status_approved = 1, approving_user_id = ? WHERE status_id = ?",
          list(approving_user_id, status_id),
          conn = txn_conn
        )
      }

      list(entity_id = entity_id, review_id = review_id, status_id = status_id)
    }, pool_obj = pool)

    return(list(status = 200, message = "OK. Entry created.", entry = result))
  },
  error = function(e) {
    logger::log_error("Entity creation failed, all changes rolled back", error = e$message)
    return(list(status = 500, message = "Entity creation failed. All changes rolled back."))
  })
}
```

### Correct Transaction Pattern (Function-Based)
```r
# Source: api/tests/testthat/test-unit-transaction-patterns.R
# CORRECT pattern - provides atomicity
db_with_transaction(function(txn_conn) {
  db_execute_statement("INSERT INTO ndd_entity (...) VALUES (...)", params, conn = txn_conn)
  db_execute_statement("INSERT INTO ndd_entity_review (...) VALUES (...)", params, conn = txn_conn)
  # Both use same txn_conn → atomic
}, pool_obj = pool)

# WRONG pattern - provides ZERO atomicity
db_with_transaction({
  db_execute_statement("INSERT INTO ndd_entity (...) VALUES (...)")  # New connection!
  db_execute_statement("INSERT INTO ndd_entity_review (...) VALUES (...)")  # Another new connection!
  # Different connections → NOT atomic
}, pool_obj = pool)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sequential entity+review+status INSERTs | Transaction-wrapped via `svc_entity_create_full` | Commit 831ac85a (2026-02-06) | Eliminated ghost entity creation risk |
| Legacy endpoint calls repository functions directly | Endpoint delegates to service layer for transactions | Commit 831ac85a | Separation of concerns, cleaner transaction boundaries |
| Partial failure detection via logging | Full rollback on any failure | Commit 831ac85a | No partial state possible, cleaner error handling |
| Entity creation split across 300+ lines | Consolidated in `svc_entity_create_full` | Commit 831ac85a | Easier to verify transaction atomicity |

**Deprecated/outdated:**
- **Sequential non-atomic entity creation:** Pre-831ac85a pattern that created ghost entities. Endpoint now uses atomic service function.
- **Manual partial failure detection:** Logging "PARTIAL CREATION" warnings. No longer needed because transactions guarantee all-or-nothing semantics.
- **Entity-only creation services:** `svc_entity_create_with_review_status` (lines 348-494 of entity-service.R) is superseded by `svc_entity_create_full` (lines 496-720). The full function handles publications/phenotypes/variation ontology atomically.

## Open Questions

### Q1: Are there additional ghost entities beyond the known three?
**What we know:** Phase context identifies 4469 (GAP43), 4474 (FGF14), 4188 (VCP).
**What's unclear:** Whether the detection query finds additional ghosts.
**Recommendation:** Include detection query in cleanup issue. If additional ghosts found, document in issue and expand DELETE statement.

### Q2: How did entity 4188 become a replacement target?
**What we know:** Entity 1249 has `replaced_by = 4188`. Entity 4188 is a ghost (no status/review).
**What's unclear:** How entity 4188 was set as replacement despite being invisible in UI.
**Recommendation:** After NULLing the FK, investigate entity 1249's history to prevent similar issues. Not blocking for this phase.

### Q3: Should we add periodic ghost detection monitoring?
**What we know:** Atomic transactions prevent new ghosts. Risk is eliminated.
**What's unclear:** Whether ongoing monitoring adds value vs. complexity.
**Recommendation:** Trust the transaction fix. No periodic detection needed. If new ghosts appear, it indicates a regression in the atomic creation pattern (test-unit-transaction-patterns.R will catch this).

## Sources

### Primary (HIGH confidence)
- `api/endpoints/entity_endpoints.R` (lines 195-371) - Current entity creation endpoint implementation
- `api/services/entity-service.R` (lines 496-720) - `svc_entity_create_full()` atomic creation
- `api/functions/db-helpers.R` (lines 333-397) - `db_with_transaction()` transaction wrapper
- `db/C_Rcommands_set-table-connections.R` (lines 169-237) - Foreign key constraints on ndd_entity
- Git commit 831ac85a - Entity creation 500 error fix, atomic creation implementation
- Git commit 9e4a2d33 - Initial atomic entity creation (`entity_create_with_review_status`)
- Git commit 22f6ad22 - Review_user_id fix for atomic creation

### Secondary (MEDIUM confidence)
- `sysndd-administration/scripts/data-corrections/README.md` - Data correction protocol
- `sysndd-administration/scripts/data-corrections/001-vario-synopsis-extraction/PLAN.md` - Example correction issue format
- `.planning/phases/85-ghost-entity-cleanup-prevention/85-CONTEXT.md` - User decisions and ghost entity details
- `.planning/REQUIREMENTS-v10.6.md` - Original problem description

### Tertiary (LOW confidence)
None. All findings verified against current codebase and git history.

## Metadata

**Confidence breakdown:**
- Current endpoint implementation: HIGH - Verified by reading current code at lines 351-361 of entity_endpoints.R
- Atomic creation already implemented: HIGH - Confirmed via git history (831ac85a) and code inspection
- Ghost entity causes: HIGH - Commit messages explicitly describe the bug (9e4a2d33: "Fixes BUG-02 (GAP43) and BUG-03 (MEF2C) orphaned entity issues")
- Database schema and FKs: HIGH - Verified via C_Rcommands_set-table-connections.R
- Cleanup approach: HIGH - User decision in CONTEXT.md, verified FK constraint implications
- Administration repo format: HIGH - Verified via README.md and example PLAN.md files

**Research date:** 2026-02-10
**Valid until:** 60 days (stable patterns - transaction architecture unlikely to change)

## Implementation Notes for Planner

### Critical Findings

1. **No API code changes required for prevention** - The entity creation endpoint (POST /api/entity/create) ALREADY uses `svc_entity_create_full()` as of commit 831ac85a (2026-02-06). Ghost entities cannot be created with current code.

2. **Cleanup is a documentation task** - Create a GitHub issue in `sysndd-administration` repository with SQL commands. The issue becomes the work item for production deployment.

3. **Foreign key dependency must be resolved first** - Entity 1249 points to ghost entity 4188 via `replaced_by`. This FK must be NULLed before deletion.

4. **Detection query should run before and after** - Include the ghost entity detection query in the issue to discover any additional ghosts and verify cleanup success.

### Planning Recommendations

**Phase scope:**
- Task 1: Write detailed GitHub issue with problem description, SQL commands, and verification steps
- Task 2: [Optional] Add test case verifying `svc_entity_create_full` transaction behavior (if not already covered)
- Task 3: [Optional] Add logging for rollback events in entity creation

**Out of scope:**
- Modifying entity creation endpoint (already uses atomic creation)
- Building monitoring/detection infrastructure (trust the transaction fix)
- Database triggers or constraints (application-level transactions sufficient)

**Testing strategy:**
- Unit test: Transaction rollback behavior (may already exist in test-unit-transaction-patterns.R)
- Integration test: Not needed - cleanup is SQL-only, no API changes
- E2E test: Verify entity creation still works after cleanup (existing tests cover this)

**Risk areas:**
- Forgetting to NULL the replaced_by FK before deleting entity 4188
- Running DELETE without detection query (may miss additional ghosts)
- Assuming endpoint needs changes when it's already fixed
