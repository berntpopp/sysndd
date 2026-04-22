# Domain Pitfalls: Bug Fixes in Production Database Applications

**Domain:** Bug fixes and data integrity for neurodevelopmental disorders database
**Researched:** 2026-02-08
**Context:** v10.5 milestone fixing 6 bugs in existing SysNDD production system

## Executive Summary

Fixing bugs in a production database application with concurrent users requires defensive patterns that prevent regressions while maintaining system availability. The SysNDD context adds specific constraints: R/dplyr aggregation subtleties, MySQL transaction semantics, Docker container deployment, and researcher workflows that depend on API stability.

**Critical insight:** Most regressions come not from the bug fix itself, but from *side effects* on code paths that weren't tested. In production systems with complex aggregations and concurrent writes, a "simple" fix in one function can cascade through views, cached results, and downstream consumers.

---

## Critical Pitfalls

Mistakes that cause regressions, data corruption, or production downtime.

---

### Pitfall 1: dplyr group_by() Leaves Implicit Grouping After summarise()

**What goes wrong:**

```r
# Bug: Fix cross-database aggregation with max(category)
data %>%
  group_by(gene, database) %>%
  summarise(max_category = max(category), .groups = "drop_last") %>%
  mutate(rank = row_number())  # BUG: Still grouped by gene!
```

After `summarise()`, dplyr drops the *last* grouping level but keeps earlier ones. Subsequent `mutate()` operations execute *per remaining group*, not globally. This is the root cause of issue #173 (CurationComparisons max category aggregation).

**Why it happens:**

- Default `.groups = "drop_last"` behavior is subtle
- Developers assume `summarise()` removes all grouping
- Visually identical results mask per-group vs global operations
- Row order depends on group order, hiding bugs in small datasets

**Consequences:**

- Cross-database comparisons show wrong "max" values
- Frontend displays incorrect category badges
- Users trust wrong data for clinical decisions

**Prevention:**

1. **Always explicit `.groups` argument** in `summarise()`:
   - `.groups = "drop"` — Remove all grouping (most common need)
   - `.groups = "keep"` — Keep all grouping levels
   - `.groups = "drop_last"` — Remove only innermost group (rare)

2. **Add `ungroup()` before operations that should be global**:
   ```r
   data %>%
     group_by(gene, database) %>%
     summarise(max_category = max(category), .groups = "drop") %>%
     ungroup() %>%  # Defensive: ensure no implicit grouping
     mutate(global_rank = row_number())
   ```

3. **Test with multi-group data** where per-group vs global differs:
   ```r
   test_that("aggregation is global, not per-group", {
     result <- aggregate_comparisons(multi_database_fixture)
     expect_equal(nrow(result), n_distinct(result$gene))  # One row per gene
     expect_false(dplyr::is_grouped_df(result))  # No grouping remains
   })
   ```

**Detection:**

- `is_grouped_df(data)` returns TRUE after you thought grouping was removed
- Results have correct row counts but wrong calculated values
- Per-gene counts work but cross-gene comparisons fail
- `group_vars(data)` shows unexpected grouping variables

**Sources:**

- [Summarise each group down to one row — summarise • dplyr](https://dplyr.tidyverse.org/reference/summarise.html)
- [Grouped data • dplyr](https://dplyr.tidyverse.org/articles/grouping.html)
- [Data Manipulation in R with dplyr (2026): Practical Patterns](https://thelinuxcode.com/data-manipulation-in-r-with-dplyr-2026-practical-patterns-for-clean-reliable-pipelines/)

---

### Pitfall 2: Time-Series Aggregation with Sparse Categorical Data Creates Misleading Trends

**What goes wrong:**

Issue #171 (entities over time chart): When aggregating entity counts by date and category, sparse data creates visual artifacts. If no entities exist for a category on certain dates, the chart shows:

- **Jagged lines** that appear to drop to zero and spike back up
- **Missing segments** where categories temporarily disappear
- **Misleading totals** when summing across incomplete date ranges

Forward-fill (LOCF - Last Observation Carried Forward) seems like a solution but introduces bias: a category with 5 entities on Day 1 and nothing until Day 30 will show flat-line at 5, not the reality of "no new data."

**Why it happens:**

- SQL/dplyr aggregations naturally return sparse results (only dates with data)
- Frontend charting libraries connect points linearly, creating false "drops"
- Forward-fill assumes stationarity (values stay constant), but entity creation is cumulative
- Different categories have different sparsity patterns, making global fill strategies fail

**Consequences:**

- Administrators misinterpret trends (e.g., "why did approvals drop last week?")
- Cumulative charts show impossible decreases
- Comparison across categories becomes meaningless
- Stakeholder reports contain incorrect growth metrics

**Prevention:**

1. **Choose aggregation strategy based on metric semantics**:
   - **Cumulative counts** (entities created to date): Use SQL window functions to compute running total, then fill missing dates with previous total
   - **Rate/velocity** (entities per week): Either show sparse data with clear "no data" markers, or use zero-fill (absence = zero activity)
   - **Status snapshots**: Require explicit date range query, don't fill gaps

2. **Server-side gap-filling for cumulative metrics**:
   ```r
   # Generate complete date sequence
   date_range <- seq.Date(min_date, max_date, by = "day")

   # Compute cumulative sum per category
   cumulative <- entities %>%
     group_by(category, date) %>%
     summarise(count = n(), .groups = "drop") %>%
     arrange(category, date) %>%
     group_by(category) %>%
     mutate(cumulative_count = cumsum(count)) %>%
     ungroup()

   # Fill missing dates with last known cumulative (not last known count)
   complete_series <- expand.grid(
     date = date_range,
     category = unique(cumulative$category)
   ) %>%
     left_join(cumulative, by = c("date", "category")) %>%
     group_by(category) %>%
     arrange(date) %>%
     fill(cumulative_count, .direction = "down") %>%  # tidyr::fill()
     mutate(cumulative_count = replace_na(cumulative_count, 0)) %>%
     ungroup()
   ```

3. **Test with realistic sparsity patterns**:
   ```r
   test_that("entities over time handles sparse categories correctly", {
     # Day 1: Category A has 5 entities
     # Day 5: Category B has 3 entities
     # Day 10: Category A has 2 more (cumulative 7)
     sparse_data <- create_sparse_entity_fixture()

     result <- compute_entities_over_time(sparse_data, granularity = "day")

     # Category A should show 5 on days 1-9, then 7 on day 10+
     expect_equal(result %>% filter(category == "A", date == as.Date("2024-01-09")) %>% pull(count), 5)
     expect_equal(result %>% filter(category == "A", date == as.Date("2024-01-10")) %>% pull(count), 7)
   })
   ```

4. **Frontend: Use step charts for cumulative data** (not line charts):
   ```javascript
   // Chart.js: stepped: true for cumulative metrics
   datasets: [{
     data: cumulativeData,
     stepped: 'before',  // Flat line until next data point
     fill: false
   }]
   ```

**Detection:**

- Chart shows sudden drops to zero in cumulative metrics (impossible)
- Different date ranges return different historical totals (should be stable)
- Sparse categories have jagged lines, dense categories are smooth
- Sum of per-category counts ≠ total entity count on sparse dates

**Sources:**

- [Time Series Forecasting Real-World Challenges: Part 1](https://medium.com/@ODAIAai/time-series-forecasting-real-world-challenges-part-1-436800c97032)
- [Handling Missing Data in Time Series: 5 Methods](https://growth-onomics.com/handling-missing-data-in-time-series-5-methods/)
- [Data Imputation Demystified | Time Series Data](https://medium.com/@aaabulkhair/data-imputation-demystified-time-series-data-69bc9c798cb7)

---

### Pitfall 3: Re-Review Approval Sync Across Multiple Pathways (Transaction Safety)

**What goes wrong:**

Issue #172 (re_review_approved flag never set): When a re-review is approved, multiple flags must be updated atomically:

1. `ndd_re_review.is_approved = TRUE`
2. `ndd_entity_review.review_approved = TRUE` (if review changed)
3. `ndd_entity_status.status_approved = TRUE` (if status changed)

If these updates happen in separate transactions or queries, concurrent requests can leave the system in inconsistent state:

- Re-review marked approved but underlying review still unapproved
- Status shows as active but review is still pending
- Entity visible in one view but not another due to approval flag mismatch

**Why it happens:**

- Multiple approval pathways exist: direct approval, re-review approval, admin override
- Legacy code scattered approval logic across service layers
- Transaction boundaries unclear (which operations must be atomic)
- MySQL default isolation (REPEATABLE READ) doesn't prevent lost updates when reading before writing

**Consequences:**

- Entities stuck in "limbo" state (approved in one table, not in others)
- Curator workflow breaks (entities don't appear in expected lists)
- Data integrity violations visible to end users
- Manual database surgery required to fix inconsistent records

**Prevention:**

1. **Single transaction for all related approval updates**:
   ```r
   approve_re_review <- function(re_review_id, approving_user_id, pool) {
     db_with_transaction(function(txn_conn) {
       # Step 1: Get re-review details
       re_review <- db_execute_query(
         "SELECT entity_id, review_id, status_id FROM ndd_re_review WHERE re_review_id = ?",
         list(re_review_id),
         conn = txn_conn
       )

       # Step 2: Update re-review approval
       db_execute_statement(
         "UPDATE ndd_re_review SET is_approved = 1, approved_by = ?, approved_at = NOW() WHERE re_review_id = ?",
         list(approving_user_id, re_review_id),
         conn = txn_conn
       )

       # Step 3: Update review approval if new review was created
       if (!is.na(re_review$review_id)) {
         db_execute_statement(
           "UPDATE ndd_entity_review SET review_approved = 1, is_primary = 1, approving_user_id = ? WHERE review_id = ?",
           list(approving_user_id, re_review$review_id),
           conn = txn_conn
         )
       }

       # Step 4: Update status approval if new status was created
       if (!is.na(re_review$status_id)) {
         db_execute_statement(
           "UPDATE ndd_entity_status SET status_approved = 1, is_active = 1, approving_user_id = ? WHERE status_id = ?",
           list(approving_user_id, re_review$status_id),
           conn = txn_conn
         )
       }

       # Return updated re-review
       re_review_id
     }, pool_obj = pool)
   }
   ```

2. **Test transaction rollback on partial failure**:
   ```r
   test_that("approval rollback leaves no partial state", {
     # Mock: re_review exists, but status_id is invalid (FK violation)
     invalid_re_review <- create_re_review_fixture(status_id = 99999)

     # Attempt approval should fail and rollback
     expect_error(
       approve_re_review(invalid_re_review$re_review_id, user_id = 10, pool),
       class = "db_transaction_error"
     )

     # Verify: re_review.is_approved is still FALSE (rollback worked)
     result <- pool %>% tbl("ndd_re_review") %>%
       filter(re_review_id == !!invalid_re_review$re_review_id) %>%
       collect()
     expect_false(result$is_approved)
   })
   ```

3. **Avoid SELECT then UPDATE pattern** (read-modify-write race):
   ```r
   # BAD: Race condition between SELECT and UPDATE
   current <- db_execute_query("SELECT is_approved FROM ndd_re_review WHERE re_review_id = ?", list(id))
   if (!current$is_approved) {
     db_execute_statement("UPDATE ndd_re_review SET is_approved = 1 WHERE re_review_id = ?", list(id))
   }

   # GOOD: Single atomic UPDATE with WHERE clause check
   rows_affected <- db_execute_statement(
     "UPDATE ndd_re_review SET is_approved = 1, approved_by = ?, approved_at = NOW()
      WHERE re_review_id = ? AND is_approved = 0",
     list(user_id, id)
   )
   if (rows_affected == 0) {
     stop_for_conflict("Re-review already approved or does not exist")
   }
   ```

4. **Use foreign key constraints** to enforce referential integrity:
   ```sql
   -- Ensure status_id in ndd_re_review must reference valid status
   ALTER TABLE ndd_re_review
   ADD CONSTRAINT fk_re_review_status
   FOREIGN KEY (status_id) REFERENCES ndd_entity_status(status_id)
   ON DELETE RESTRICT;  -- Prevent orphaned pointers
   ```

**Detection:**

- `SELECT COUNT(*) FROM ndd_re_review WHERE is_approved = 1` ≠ count of approved reviews/statuses
- Entities disappear from frontend tables after approval
- Logs show "rows affected: 0" for UPDATE queries that should succeed
- Manual SQL joins reveal mismatched approval flags across tables

**Sources:**

- [MySQL Isolation Levels Guide](https://www.mydbops.com/blog/back-to-basics-isolation-levels-in-mysql)
- [MySQL Transaction Isolation Levels and Concurrency Issues](https://medium.com/@dmzlovelife/mysql-transaction-isolation-levels-and-concurrency-issues-87f0ec0a109c)
- [Transaction Isolation Levels by Vivek Bansal](https://vivekbansal.substack.com/p/transaction-isolation-levels)

---

### Pitfall 4: PubTator Batch Annotation Storage Without Deduplication

**What goes wrong:**

Issue #170 (PubTator annotation storage fails for incremental updates): When storing gene annotations from PubTator API, duplicate `(pmid, gene_symbol)` pairs cause INSERT failures:

```sql
-- First batch: PMID 12345 mentions "BRCA1"
INSERT INTO pubtator_annotations (pmid, gene_symbol) VALUES ('12345', 'BRCA1');

-- Second batch (same PMID re-processed): Duplicate key error
INSERT INTO pubtator_annotations (pmid, gene_symbol) VALUES ('12345', 'BRCA1');
-- ERROR 1062: Duplicate entry '12345-BRCA1' for key 'pmid_gene'
```

This happens because:
- Incremental updates re-process overlapping PMIDs
- Batch processing doesn't check existing annotations before INSERT
- Rate limiting causes retries that duplicate successful writes

**Why it happens:**

- External API batch processing is naturally idempotent (fetch same data twice → same result)
- Database INSERTs are *not* idempotent (insert twice → error)
- Developer assumes "new batch" means "new data" (false for retries/overlaps)
- No unique constraint or deduplication logic in storage layer

**Consequences:**

- Batch annotation jobs fail midway through, requiring manual cleanup
- Partial data stored (first N PMIDs succeed, rest fail)
- Curator workflow blocked (can't proceed until annotation completes)
- Lost annotations (job marked "failed" but some data was written)

**Prevention:**

1. **Use INSERT IGNORE or ON DUPLICATE KEY UPDATE**:
   ```r
   # MySQL-specific: INSERT IGNORE silently skips duplicates
   db_execute_statement(
     "INSERT IGNORE INTO pubtator_annotations (pmid, gene_symbol, score, mentions)
      VALUES (?, ?, ?, ?)",
     list(pmid, gene_symbol, score, mentions)
   )

   # OR: UPDATE if duplicate exists
   db_execute_statement(
     "INSERT INTO pubtator_annotations (pmid, gene_symbol, score, mentions)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE score = VALUES(score), mentions = VALUES(mentions), updated_at = NOW()",
     list(pmid, gene_symbol, score, mentions)
   )
   ```

2. **Batch deduplication before INSERT**:
   ```r
   store_pubtator_batch <- function(annotations, pool) {
     # Get existing (pmid, gene_symbol) pairs
     pmids <- unique(annotations$pmid)
     existing <- pool %>%
       tbl("pubtator_annotations") %>%
       filter(pmid %in% !!pmids) %>%
       dplyr::select(pmid, gene_symbol) %>%
       collect() %>%
       mutate(exists = TRUE)

     # Left join to identify new annotations
     new_annotations <- annotations %>%
       left_join(existing, by = c("pmid", "gene_symbol")) %>%
       filter(is.na(exists)) %>%
       dplyr::select(-exists)

     # Insert only new annotations
     if (nrow(new_annotations) > 0) {
       db_execute_statement(
         "INSERT INTO pubtator_annotations (pmid, gene_symbol, score, mentions) VALUES (?, ?, ?, ?)",
         # ... batch insert logic
       )
     }
   }
   ```

3. **Add unique constraint** to enforce at database level:
   ```sql
   -- Migration: Add unique constraint (prevents duplicates)
   ALTER TABLE pubtator_annotations
   ADD CONSTRAINT unique_pmid_gene UNIQUE (pmid, gene_symbol);
   ```

4. **Test idempotency** (same batch inserted twice should succeed):
   ```r
   test_that("storing same annotations twice is idempotent", {
     batch <- tibble(pmid = "12345", gene_symbol = "BRCA1", score = 0.95)

     # First insert: succeeds
     store_pubtator_batch(batch, pool)
     count_after_first <- pool %>% tbl("pubtator_annotations") %>%
       filter(pmid == "12345") %>% count() %>% collect()

     # Second insert: should not error or create duplicates
     expect_no_error(store_pubtator_batch(batch, pool))
     count_after_second <- pool %>% tbl("pubtator_annotations") %>%
       filter(pmid == "12345") %>% count() %>% collect()

     expect_equal(count_after_first$n, count_after_second$n)
   })
   ```

**Detection:**

- Async job logs show "Duplicate entry" MySQL error 1062
- `pubtator_annotations` table row count < expected from batch size
- Retrying failed job immediately fails again (not transient error)
- Manual query shows duplicate `(pmid, gene_symbol)` pairs

**Sources:**

- [How to Handle API Rate Limits Gracefully (2026 Guide)](https://apistatuscheck.com/blog/how-to-handle-api-rate-limits)
- [API Rate Limiting at Scale: Patterns and Strategies](https://www.gravitee.io/blog/rate-limiting-apis-scale-patterns-strategies)

---

### Pitfall 5: Database Migration Script Lack of Idempotency

**What goes wrong:**

Migration scripts that aren't idempotent fail when:
- Re-run during rollback testing
- Applied to environment where schema is in unexpected state
- Run twice due to CI retry or manual operator error

Classic example: Adding an index that already exists:
```sql
-- Migration 011: Add logging indexes
ALTER TABLE logging ADD INDEX idx_logging_timestamp (timestamp);
-- ERROR 1061: Duplicate key name 'idx_logging_timestamp'
```

Non-idempotent migrations cause:
- Half-applied schema changes (migration fails midway)
- Production downtime (can't roll forward or back)
- Manual database surgery to fix inconsistent state

**Why it happens:**

- SQL DDL lacks native "if not exists" guards (before MySQL 8.0.29)
- Developer writes migration for clean slate, not existing production schema
- No testing of migration re-application
- Assumption that migration runner prevents duplicates (doesn't handle partial failures)

**Consequences:**

- CI pipeline blocked (migration fails, can't merge PR)
- Production deployment requires manual intervention
- Rollback impossible (can't undo half-applied changes)
- Data loss if destructive migration fails midway

**Prevention:**

1. **Use stored procedure guards** for idempotent schema changes:
   ```sql
   DELIMITER //

   CREATE PROCEDURE IF NOT EXISTS migrate_add_logging_indexes()
   BEGIN
     -- Check if index exists before creating
     IF NOT EXISTS (
       SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
       WHERE TABLE_SCHEMA = DATABASE()
         AND TABLE_NAME = 'logging'
         AND INDEX_NAME = 'idx_logging_timestamp'
     ) THEN
       ALTER TABLE logging ADD INDEX idx_logging_timestamp (timestamp);
     END IF;

     -- Repeat for other indexes...
   END //

   CALL migrate_add_logging_indexes() //
   DROP PROCEDURE IF EXISTS migrate_add_logging_indexes //
   ```

2. **Test migration re-application**:
   ```bash
   # CI test: Apply migration twice to same database
   mysql < db/migrations/011_logging_indexes.sql
   mysql < db/migrations/011_logging_indexes.sql  # Should not error
   ```

3. **Separate additive and destructive migrations**:
   ```sql
   -- Migration 012a: Add new columns (safe, idempotent)
   ALTER TABLE ndd_entity ADD COLUMN IF NOT EXISTS new_field VARCHAR(100);

   -- Migration 012b: Drop old columns (requires application deployment first)
   -- Run this AFTER application code no longer references old_field
   -- ALTER TABLE ndd_entity DROP COLUMN IF EXISTS old_field;
   ```

4. **Avoid destructive DDL in single step**:
   ```
   Phase 1 (Migration 015a): Add new_column, backfill from old_column
   Phase 2 (Application Deploy v2.3): Code reads new_column, writes both
   Phase 3 (Application Deploy v2.4): Code reads/writes only new_column
   Phase 4 (Migration 015b): Drop old_column (safe, no references remain)
   ```

5. **Use migration checksum/version tracking**:
   ```r
   # Before applying migration
   schema_version <- pool %>% tbl("schema_migrations") %>% collect()
   if ("011_logging_indexes" %in% schema_version$migration_name) {
     log_info("Migration 011 already applied, skipping")
     return(invisible(NULL))
   }

   # Apply migration
   execute_migration_file("db/migrations/011_logging_indexes.sql")

   # Record success
   db_execute_statement(
     "INSERT INTO schema_migrations (migration_name, applied_at) VALUES (?, NOW())",
     list("011_logging_indexes")
   )
   ```

**Detection:**

- CI migration tests fail on re-run
- Production deployment requires manual schema inspection before applying
- Error logs show "Duplicate key name" or "Duplicate column name"
- `SHOW CREATE TABLE` reveals schema inconsistencies between environments

**Sources:**

- [Creating Idempotent DDL Scripts for Database Migrations](https://www.red-gate.com/hub/product-learning/flyway/creating-idempotent-ddl-scripts-for-database-migrations)
- [Database migration tips & tricks by Jonathan Hall](https://jhall.io/archive/2022/05/12/database-migration-tips-tricks/)
- [Trouble-Free Database Migration: Idempotence and Convergence](https://dzone.com/articles/trouble-free-database-migration-idempotence-and-co)

---

## Moderate Pitfalls

Mistakes that cause delays or technical debt but don't corrupt data.

---

### Pitfall 6: API Response Schema Changes Break Frontend Without Versioning

**What goes wrong:**

Issue #167 context: Building admin entity audit UI requires new API endpoint. Developer adds field to existing `/api/entity/{id}` response:

```json
// Before
{"entity_id": 123, "hgnc_id": 456, "symbol": "BRCA1"}

// After (added replaced_by field)
{"entity_id": 123, "hgnc_id": 456, "symbol": "BRCA1", "replaced_by": 789}
```

Frontend that relies on response structure may break:
- TypeScript interfaces don't match new shape
- Unit tests fail due to snapshot mismatches
- Cached responses have old schema

**Prevention:**

1. **Add new fields as optional** (never make existing fields required):
   ```typescript
   // Backend: Add new field with NULL default
   interface EntityResponse {
     entity_id: number;
     hgnc_id: number;
     symbol: string;
     replaced_by?: number | null;  // Optional: old clients ignore
   }
   ```

2. **Use separate endpoint for new functionality**:
   ```
   GET /api/entity/{id} — Original response (backward compatible)
   GET /api/entity/{id}/audit — New audit info (opt-in, doesn't break existing clients)
   ```

3. **Version API endpoints** when breaking changes are unavoidable:
   ```
   GET /api/v1/entity/{id} — Original schema
   GET /api/v2/entity/{id} — New schema with replaced_by
   ```

4. **Test backward compatibility**:
   ```r
   test_that("entity endpoint response matches schema version 1", {
     response <- request_entity(entity_id = 5)
     expect_has_keys(response, c("entity_id", "hgnc_id", "symbol"))
     # New field is optional, don't require it in v1 schema
   })
   ```

**Detection:**

- Frontend console shows TypeScript type errors after API deployment
- E2E tests fail with "unexpected field" errors
- User reports "data not displaying" after backend update
- API monitoring shows 4xx errors spike after deployment

**Sources:**

- [API Versioning Best Practices for Backward Compatibility](https://endgrate.com/blog/api-versioning-best-practices-for-backward-compatibility)
- [Avoiding Backward Compatibility Breaks in API Design](https://medium.com/carvago-development/avoiding-backward-compatibility-breaks-in-api-design-a-developers-guide-b6b4d280d443)
- [API Backwards Compatibility Best Practices](https://zuplo.com/learning-center/api-versioning-backward-compatibility-best-practices)

---

### Pitfall 7: Traefik v3 Router Rule Matcher Syntax Changes

**What goes wrong:**

Issue #169 (Traefik Host() matcher for TLS): Traefik v2 → v3 migration changes router rule syntax:

```yaml
# Traefik v2 (deprecated)
- "traefik.http.routers.api.rule=Host(`api.sysndd.org`)"

# Traefik v3 (required)
- "traefik.http.routers.api.rule=Host(`api.sysndd.org`)"  # Same syntax!
```

BUT: v3 path normalization changes break some rules:
- `PathPrefix(/api)` now matches `/api/` but not `/api` (trailing slash)
- Reserved characters (`, /, ?, #) are URL-encoded during matching
- ClientIP matcher syntax changed

**Why it happens:**

- Traefik maintains backward compatibility in most cases
- Path normalization is a security fix (RFC 3986 compliance)
- Developer assumes "it works in v2" means "it works in v3"
- TLS certificate selection depends on router rule matching

**Prevention:**

1. **Test router rules** in staging with Traefik v3:
   ```bash
   # Verify router rule matches expected paths
   curl -v https://api.sysndd.org/api/entity/5  # Should route to API
   curl -v https://api.sysndd.org/api/entity/5/  # Trailing slash
   ```

2. **Use explicit path patterns** instead of prefix:
   ```yaml
   # BAD: Ambiguous with trailing slash
   rule: "PathPrefix(`/api`)"

   # GOOD: Explicit with regex
   rule: "PathPrefix(`/api/`) || Path(`/api`)"
   ```

3. **Check TLS certificate selection** with SNI:
   ```bash
   # Verify cert matches hostname
   openssl s_client -connect api.sysndd.org:443 -servername api.sysndd.org < /dev/null 2>/dev/null | openssl x509 -noout -text | grep DNS
   ```

4. **Add health check** that verifies routing:
   ```yaml
   # docker-compose.yml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost/api/health"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

**Detection:**

- HTTPS requests return "404 Not Found" or wrong backend
- TLS certificate is Traefik default, not Let's Encrypt for domain
- Logs show "no router found for path /api"
- Some paths work, others fail (inconsistent routing)

**Sources:**

- [Traefik v3 Migration Documentation](https://doc.traefik.io/traefik/migrate/v3/)
- [Traefik V3 Migration Details](https://doc.traefik.io/traefik/migrate/v2-to-v3-details/)
- [Traefik 3.0 GA Has Landed: Here's How to Migrate](https://traefik.io/blog/traefik-3-0-ga-has-landed-heres-how-to-migrate)

---

### Pitfall 8: AbortController Request Cancellation Memory Leaks

**What goes wrong:**

Vue composable for fetching data uses `AbortController` to cancel requests on unmount:

```javascript
// BUG: Reusing same AbortController for multiple requests
const controller = new AbortController();

async function fetchData() {
  await axios.get('/api/entity', { signal: controller.signal });
}

// First call: works
await fetchData();

// Second call: ERROR - signal already aborted!
await fetchData();
```

Additionally, not cleaning up event listeners causes memory leaks:
- Pending promises hold references to component instances
- Axios interceptors accumulate on repeated calls
- Race conditions when fast navigation cancels requests

**Prevention:**

1. **Create new AbortController per request**:
   ```javascript
   // GOOD: Fresh controller for each request
   const useFetchEntity = (entityId) => {
     const controller = ref(null);

     const fetchData = async () => {
       // Cancel previous request if still pending
       controller.value?.abort();

       // New controller for this request
       controller.value = new AbortController();

       try {
         const response = await axios.get(`/api/entity/${entityId}`, {
           signal: controller.value.signal
         });
         return response.data;
       } catch (error) {
         if (axios.isCancel(error)) {
           console.log('Request cancelled');
         } else {
           throw error;
         }
       }
     };

     // Cleanup on unmount
     onUnmounted(() => {
       controller.value?.abort();
     });

     return { fetchData };
   };
   ```

2. **Use composable pattern** for automatic cleanup:
   ```javascript
   // composables/useCancellableRequest.js
   import { onUnmounted, ref } from 'vue';
   import axios from 'axios';

   export function useCancellableRequest() {
     const controllers = ref(new Map());

     const request = async (key, config) => {
       // Cancel previous request with same key
       controllers.value.get(key)?.abort();

       // New controller
       const controller = new AbortController();
       controllers.value.set(key, controller);

       try {
         return await axios({ ...config, signal: controller.signal });
       } finally {
         controllers.value.delete(key);
       }
     };

     // Cancel all pending requests on unmount
     onUnmounted(() => {
       controllers.value.forEach(c => c.abort());
       controllers.value.clear();
     });

     return { request };
   }
   ```

3. **Test race condition handling**:
   ```javascript
   test('rapid navigation cancels pending requests', async () => {
     const { request } = useCancellableRequest();

     // Start first request (slow)
     const promise1 = request('entities', { url: '/api/entity', delay: 1000 });

     // Start second request (fast) - should cancel first
     const promise2 = request('entities', { url: '/api/entity', delay: 100 });

     // Only second request should resolve
     await expect(promise1).rejects.toThrow('cancelled');
     await expect(promise2).resolves.toBeDefined();
   });
   ```

4. **Avoid reusing cancelled controllers**:
   ```javascript
   // BAD: Checking if signal is aborted doesn't help
   if (controller.signal.aborted) {
     controller = new AbortController();  // This is pointless
   }

   // GOOD: Always create fresh controller
   controller = new AbortController();
   ```

**Detection:**

- Console warnings: "AbortError: The operation was aborted"
- Memory profiler shows increasing heap size after navigation
- Frontend becomes sluggish after repeated navigation
- Network tab shows requests completing after component unmounted

**Sources:**

- [Avoiding race conditions and memory leaks in React useEffect](https://dev.to/saranshk/avoiding-race-conditions-and-memory-leaks-in-react-useeffect-3mme)
- [How to fix memory leaks in Vue](https://coreui.io/answers/how-to-fix-memory-leaks-in-vue/)
- [Fixed cancelToken leakage; Added AbortController support](https://github.com/axios/axios/pull/3305)
- [How to Cancel and Restart Fetch Requests with AbortController](https://copyprogramming.com/howto/how-to-restart-fetch-api-request-after-aborting-using-abortcontroller)

---

## Minor Pitfalls

Mistakes that cause annoyance but are quickly fixable.

---

### Pitfall 9: biomaRt::select() Masks dplyr::select()

**What goes wrong:**

Known from project memory: Loading `biomaRt` package masks `dplyr::select()`:

```r
library(dplyr)
library(biomaRt)  # Masks select()

# BUG: This now calls biomaRt::select(), not dplyr::select()
data %>% dplyr::select(gene, disease)
# Error in select(., gene, disease) : unused arguments (gene, disease)
```

**Prevention:**

1. **Always use explicit namespace** for `select()`:
   ```r
   data %>% dplyr::select(gene, disease)  # Unambiguous
   ```

2. **Check for masked functions** after library loads:
   ```r
   library(dplyr)
   library(biomaRt)
   conflicts(detail = TRUE)  # Shows masked functions
   ```

3. **Lint rule** to catch bare `select()` calls:
   ```r
   # .lintr
   linters: linters_with_defaults(
     namespace_linter = namespace_linter(check_exports = TRUE)
   )
   ```

**Detection:**

- Error message: "unused arguments" when calling `select()`
- Code works locally but fails in Docker (different package load order)
- `search()` shows biomaRt after dplyr in environment

**Sources:**

- Project context from `.claude/projects/.../memory/MEMORY.md`

---

## Phase-Specific Warnings

| Bug Fix Phase | Likely Pitfall | Mitigation |
|---------------|---------------|------------|
| CurationComparisons aggregation (#173) | Implicit grouping after summarise() (Pitfall 1) | Use `.groups = "drop"` explicitly, test with multi-group data |
| AdminStatistics entity trend (#171) | Sparse categorical data forward-fill (Pitfall 2) | Server-side cumulative aggregation, use step charts |
| Re-review approval sync (#172) | Multiple approval pathways (Pitfall 3) | Single transaction for all related updates |
| PubTator annotation storage (#170) | Non-idempotent batch INSERT (Pitfall 4) | INSERT IGNORE or ON DUPLICATE KEY UPDATE |
| Traefik Host() TLS matcher (#169) | Router rule matcher syntax (Pitfall 7) | Test routing in staging with Traefik v3 |
| Entity audit UI (#167) | API response schema changes (Pitfall 6) | Add new fields as optional, use separate endpoint |
| Data integrity migrations | Non-idempotent migration scripts (Pitfall 5) | Stored procedure guards, test re-application |
| Admin UI request cancellation | AbortController memory leaks (Pitfall 8) | New controller per request, composable cleanup |

---

## Regression Risk Matrix

| Area | Risk Level | Why | Prevention |
|------|-----------|-----|------------|
| dplyr aggregations | **HIGH** | Subtle grouping behavior, visually correct but semantically wrong | Explicit `.groups`, integration tests with multi-group data |
| Time-series charts | **HIGH** | Sparse data creates misleading visuals | Server-side gap-filling, step charts, test with sparse fixtures |
| Multi-table approval | **CRITICAL** | Concurrent updates create inconsistent state | Single transaction, test rollback, avoid read-modify-write |
| Batch API processing | **MEDIUM** | Duplicates cause INSERT failures, partial success | INSERT IGNORE, idempotency tests, unique constraints |
| Database migrations | **CRITICAL** | Non-idempotent scripts block deployments | Stored procedure guards, test re-run, separate additive/destructive |
| API response schemas | **MEDIUM** | Breaking changes invisible until frontend deploys | Optional fields, separate endpoints, TypeScript contracts |
| Traefik routing | **LOW** | v3 mostly backward compatible | Test in staging, verify TLS cert selection |
| Request cancellation | **LOW** | Memory leaks accumulate slowly | Composable pattern, automatic cleanup on unmount |
| Package masking | **LOW** | Caught by linter, easy to fix | Explicit namespace, lint rules |

---

## Testing Checklist for Bug Fixes

Before merging bug fix PR:

- [ ] **Aggregation bugs**: Test with multi-group and single-group data, verify no implicit grouping remains
- [ ] **Time-series bugs**: Test with sparse data (missing dates/categories), verify cumulative values never decrease
- [ ] **Approval bugs**: Test with concurrent requests, verify transaction rollback on partial failure
- [ ] **Batch API bugs**: Test idempotency (same batch twice), verify no duplicates or errors
- [ ] **Migration bugs**: Run migration twice, verify no errors and schema matches expected state
- [ ] **API schema bugs**: Verify TypeScript types match response, test with old and new clients
- [ ] **Routing bugs**: Test all URL patterns in staging with production-like config
- [ ] **Request bugs**: Test rapid navigation and component unmount during pending requests
- [ ] **Integration tests**: Run full test suite including existing tests (catch regressions)
- [ ] **Smoke test**: Deploy to staging, verify all related workflows still function

---

## Quick Reference: Transaction Safety Checklist

When fixing bugs that update multiple tables:

1. **Identify scope**: What tables/flags must be consistent?
2. **Single transaction**: Wrap all related UPDATEs in `db_with_transaction()`
3. **Test rollback**: Mock partial failure (FK violation, duplicate key), verify clean rollback
4. **Avoid race conditions**: Use single-query UPDATE with WHERE clause instead of SELECT then UPDATE
5. **Foreign keys**: Ensure constraints exist to prevent orphaned records
6. **Test concurrency**: Simulate concurrent requests to same entity/re-review

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|-----------|-----------|
| dplyr aggregation pitfalls | **HIGH** | Official dplyr docs + 2026 best practices articles |
| Time-series sparse data | **MEDIUM** | General time-series wisdom, not R-specific |
| MySQL transactions | **HIGH** | Official MySQL docs + production experience articles |
| Migration idempotency | **HIGH** | Multiple authoritative sources + SysNDD migration examples |
| API backward compatibility | **HIGH** | Industry best practices + specific examples |
| Traefik v3 changes | **MEDIUM** | Official migration guide, but v3 is mostly backward compatible |
| AbortController patterns | **HIGH** | Vue-specific best practices + axios integration docs |
| SysNDD-specific context | **HIGH** | Derived from actual codebase inspection + project memory |

---

## Summary for Roadmap Planning

**For each bug fix phase, address:**

1. **Root cause** (not just symptom) — Why did bug happen? What pattern needs changing?
2. **Regression prevention** — What existing workflows could break? Add integration tests.
3. **Transaction boundaries** — Which operations must be atomic? Use `db_with_transaction()`.
4. **Idempotency** — Can fix be applied twice safely? Critical for migrations and batch jobs.
5. **Backward compatibility** — Will API clients break? Add fields as optional, version if needed.
6. **Test with realistic data** — Sparse groups, concurrent updates, duplicate inputs.

**Anti-patterns to eliminate:**

- Implicit dplyr grouping after summarise() → Always explicit `.groups`
- Forward-fill sparse time-series → Server-side cumulative aggregation
- Multi-table updates in separate queries → Single transaction
- Non-idempotent batch INSERTs → INSERT IGNORE or deduplication
- Schema changes without versioning → Optional fields or separate endpoints
- SELECT then UPDATE pattern → Single atomic UPDATE with WHERE clause

**Critical success factor:** Comprehensive integration tests that exercise *production-like data patterns* (sparse groups, concurrent users, retry scenarios) not just happy-path unit tests.
