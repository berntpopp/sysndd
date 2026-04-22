# Phase 73: Data Infrastructure & Cache Fixes - Research

**Researched:** 2026-02-05
**Domain:** MySQL schema migrations, R memoisation cache invalidation, external data integration
**Confidence:** HIGH

## Summary

Phase 73 addresses three distinct infrastructure issues identified in production: database column size constraints, outdated external API URLs, and stale memoisation cache after code deployments. All three share a common theme of data integrity and freshness.

The project has a mature migration system (11 existing migrations) using R-based runner with MySQL advisory locks for coordination. Migrations use stored procedures with INFORMATION_SCHEMA checks for idempotency. The caching layer uses R's memoise package with cachem::cache_disk backend, configured with infinite TTL (`max_age = Inf`) requiring manual invalidation.

Key findings:
- MySQL ALTER TABLE MODIFY is safe for widening columns (VARCHAR → TEXT) but not strictly idempotent without INFORMATION_SCHEMA guards
- Gene2Phenotype changed from legacy download URL to API-based endpoint with different file format (csv.gz → csv)
- Memoisation cache persists across container restarts and requires explicit clearing when code changes affect cached data structures
- No built-in cache versioning exists; manual invalidation via `forget()` or filesystem operations is required

**Primary recommendation:** Use existing migration patterns (stored procedure + INFORMATION_SCHEMA checks) for schema changes, UPDATE statement for URL fix, and implement cache versioning strategy for deployment safety.

## Standard Stack

### Core Technologies

| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| MySQL | 8.0.40 (8.4.8 prod) | Primary database | Project standard, INFORMATION_SCHEMA support |
| DBI | 1.2.3 | Database interface | R standard for database connections |
| pool | 1.0.4 | Connection pooling | Manages database connections efficiently |
| memoise | 2.0.1 | Function memoisation | R-lib standard for caching expensive computations |
| cachem | 1.1.0 | Cache backend | Modern replacement for older cache systems |
| fs | 1.6.5 | File system operations | Tidyverse standard, used in migration runner |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| logger | 0.4.0 | Structured logging | All migration operations |
| readr | 2.1.5 | CSV parsing | Gene2Phenotype and other external data |
| dplyr | 1.1.4 | Data transformation | All data processing |
| stringr | 1.5.1 | String manipulation | URL/version parsing |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Stored procedures | Raw ALTER TABLE | Stored procedures provide idempotency via INFORMATION_SCHEMA checks |
| memoise + cachem | R.cache | memoise is r-lib maintained, better integration with modern R ecosystem |
| Manual cache clear | Version-based keys | Version keys require code changes but provide automatic invalidation |

**Installation:**
```bash
# All dependencies already in api/renv.lock
# No new packages required for this phase
```

## Architecture Patterns

### Recommended Migration Structure

```
db/migrations/
├── 012_widen_comparison_columns.sql    # DATA-01: Column widening
├── 013_update_gene2phenotype_url.sql   # DATA-02: URL update
└── 014_add_cache_version_tracking.sql  # DATA-03: Cache version table (optional)
```

### Pattern 1: Idempotent Column Modification (DATA-01)

**What:** Use stored procedure with INFORMATION_SCHEMA checks to conditionally widen columns only if needed

**When to use:** Any ALTER TABLE MODIFY where migration may run multiple times

**Example:**
```sql
-- Source: SysNDD migration 009_ndd_database_comparison.sql
DELIMITER //

DROP PROCEDURE IF EXISTS migrate_012_widen_comparison_columns //

CREATE PROCEDURE migrate_012_widen_comparison_columns()
BEGIN
    -- Check current column type before modifying
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'version'
          AND CHARACTER_MAXIMUM_LENGTH < 255
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN version VARCHAR(255);
    END IF;

    -- Check if column is VARCHAR before converting to TEXT
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'publication_id'
          AND DATA_TYPE = 'varchar'
    ) THEN
        ALTER TABLE ndd_database_comparison
          MODIFY COLUMN publication_id TEXT;
    END IF;
END //

CALL migrate_012_widen_comparison_columns() //
DROP PROCEDURE IF EXISTS migrate_012_widen_comparison_columns //

DELIMITER ;
```

**Key insight:** INFORMATION_SCHEMA.COLUMNS provides `DATA_TYPE` (text, varchar) and `CHARACTER_MAXIMUM_LENGTH` (255, NULL for TEXT) for conditional logic.

### Pattern 2: Idempotent UPDATE Statement (DATA-02)

**What:** UPDATE configuration row that may already be correct

**When to use:** Fixing data values (URLs, settings) where re-running should be safe

**Example:**
```sql
-- Source: SysNDD migration 010_fix_radboudumc_url.sql
-- Simple UPDATE is naturally idempotent - running twice sets same value

UPDATE comparisons_config
SET source_url = 'https://www.ebi.ac.uk/gene2phenotype/api/panel/DD/download',
    file_format = 'csv'
WHERE source_name = 'gene2phenotype';
```

**Why idempotent:** UPDATE with WHERE clause is safe to run multiple times. Second execution affects 0 rows but doesn't error.

### Pattern 3: Cache Invalidation on Deployment (DATA-03)

**What:** Clear stale memoisation cache when code changes affect cached data structures

**When to use:** After any deployment that modifies memoised function signatures or return structures

**Option A - Manual filesystem clear (current pattern):**
```bash
# Source: GitHub issue #157 resolution
docker exec sysndd-api-1 rm -f /app/cache/*.rds
docker exec sysndd-api-1 rm -f /app/cache/external/dynamic/*.rds
docker compose restart api
```

**Option B - Programmatic cache invalidation:**
```r
# Source: memoise documentation
# https://memoise.r-lib.org/reference/forget.html

# Clear entire cache for specific function
memoise::forget(gen_string_clust_obj_mem)

# Clear specific argument combinations
memoise::drop_cache(gen_string_clust_obj_mem)(score_threshold = 800)
```

**Option C - Version-based cache keys (recommended for deployment automation):**
```r
# Source: memoise Issue #39 discussions
# https://github.com/r-lib/memoise/issues/39

# Define cache version from environment or config
CACHE_VERSION <- Sys.getenv("CACHE_VERSION", "1")

# Wrap functions to include version in cache key
gen_string_clust_obj_versioned <- function(score_threshold, version = CACHE_VERSION) {
  gen_string_clust_obj(score_threshold)
}

gen_string_clust_obj_mem <- memoise(gen_string_clust_obj_versioned, cache = cm)

# On deployment: increment CACHE_VERSION environment variable
# Old cache keys with version=1 are automatically orphaned
# New calls use version=2, forcing cache miss and recalculation
```

### Pattern 4: Migration Runner Integration

**What:** Migrations are tracked in `schema_version` table with advisory locks for multi-worker coordination

**When to use:** Every migration (this is how the system works)

**Example:**
```r
# Source: api/functions/migration-runner.R

# Automatic on API startup (api/start_sysndd_api.R)
run_migrations()  # Uses global pool, applies pending migrations

# Migration runner workflow:
# 1. Acquires MySQL advisory lock (GET_LOCK) for coordination
# 2. Checks schema_version table for applied migrations
# 3. Lists migration files (NNN_name.sql sorted by filename)
# 4. Executes pending migrations in order
# 5. Records each success in schema_version table
# 6. Releases lock (RELEASE_LOCK)
```

**Key features:**
- Fail-fast: Stops on first error
- Idempotent: Safe to run multiple times
- Concurrent-safe: Advisory locks prevent race conditions
- Handles DELIMITER commands for stored procedures

### Anti-Patterns to Avoid

- **Bare ALTER TABLE without INFORMATION_SCHEMA checks:** Not idempotent, fails on re-run
  - **Fix:** Wrap in stored procedure with conditional checks

- **Assuming memoise includes function body in cache key prevents all stale cache issues:** The body hash can still miss structural changes in returned data
  - **Fix:** Use explicit cache versioning or manual invalidation workflow

- **Clearing cache manually in production without documentation:** Operations team won't know to do this on deployments
  - **Fix:** Document in DEPLOYMENT.md or automate via startup script

- **Widening columns without checking current type:** Wastes execution time on already-wide columns
  - **Fix:** Use INFORMATION_SCHEMA to check before altering

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database connection pooling | Manual connection queue | pool::dbPool() | Handles cleanup, prevents leaks, battle-tested |
| Migration state tracking | Custom table schema | schema_version pattern (existing) | Already implemented, integrates with runner |
| Cache invalidation logic | Custom timestamp/hash system | memoise::forget() + version env var | R-lib maintained, works with existing cachem backend |
| Advisory locks | File-based locking | MySQL GET_LOCK() | Already used in migration-runner.R, native to MySQL |
| CSV parsing with encoding detection | read.table() + manual encoding | readr::read_csv() | Handles BOM, encoding auto-detection, faster |

**Key insight:** The project already has robust patterns for all three requirements. Don't reinvent - extend existing migration system, update config data, and document cache management.

## Common Pitfalls

### Pitfall 1: ALTER TABLE MODIFY Without Conditional Guards

**What goes wrong:** Migration runs fine first time, then fails on re-run with "duplicate column" or "already exists" errors (though MODIFY doesn't error on same type, it wastes execution time and doesn't clearly document intent)

**Why it happens:** MySQL ALTER TABLE MODIFY can run multiple times without error if column type matches, but INFORMATION_SCHEMA checks make intent explicit and allow skipping unnecessary work

**How to avoid:**
1. Always wrap ALTER TABLE in stored procedure
2. Check INFORMATION_SCHEMA.COLUMNS for current DATA_TYPE and CHARACTER_MAXIMUM_LENGTH
3. Only execute ALTER if modification is actually needed

**Warning signs:**
- Migration file contains raw ALTER TABLE without DELIMITER
- No INFORMATION_SCHEMA checks in migration
- Migration executes slowly on second run (rebuilding table unnecessarily)

### Pitfall 2: Stale Cache After Code Changes

**What goes wrong:** Frontend displays "no records to show" or 404 errors even though backend code is correct and database has data

**Why it happens:**
- Memoise includes function body in cache key by default
- But it cannot detect structural changes in returned data (e.g., adding `nrow(.) > 0` filter changes tibble structure)
- Cache persists across container restarts (disk-based, infinite TTL)
- No automatic invalidation on code deployment

**How to avoid:**
1. Document cache clearing in deployment checklist (DEPLOYMENT.md)
2. Implement cache version environment variable (CACHE_VERSION)
3. Add cache clear to container startup if version mismatch detected
4. Test changes locally with `memoise::forget()` before deploying

**Warning signs:**
- Code changes deployed but behavior unchanged
- Local development works but production doesn't
- Restarting API doesn't fix issue
- Manual cache clear fixes issue immediately

**Production evidence:** Issue #157 - GeneNetworks table showed "no records" after fix for empty tibble handling was deployed. Cache contained pre-fix tibble structure. Clearing `/app/cache/*.rds` resolved issue.

### Pitfall 3: External API URL Changes Without Update

**What goes wrong:** Data refresh job fails with HTML instead of CSV data, or 404 errors during download phase

**Why it happens:**
- External services redesign websites and change URL structures
- Legacy URLs redirect to HTML landing pages instead of raw data
- File format changes (csv.gz → csv) without notification

**How to avoid:**
1. Store URLs in database config table (comparisons_config) not hardcoded
2. Log download response headers (Content-Type) to detect HTML vs data
3. Monitor external service announcements for API changes
4. Add tests that verify downloaded content type matches expected format

**Warning signs:**
- Download succeeds (200 OK) but parsing fails
- File size is much smaller than expected (HTML page vs CSV)
- Error message: "Failed to parse [source_name]"
- Content-Type header shows text/html instead of text/csv

**Production evidence:** Issue #156 - Gene2Phenotype changed from `/downloads/DDG2P.csv.gz` to `/api/panel/DD/download` (plain CSV). Download appeared to succeed but returned HTML 404 page. Parser failed with "Failed to parse gene2phenotype".

### Pitfall 4: VARCHAR Size Insufficient for Concatenated Data

**What goes wrong:** Database write fails with "Data too long for column 'X' at row 1 [1406]"

**Why it happens:**
- External databases provide concatenated values (multiple PMIDs, HPO terms)
- Original schema used `VARCHAR(341)` based on observed data
- New data sources have longer concatenations
- No validation of data length before INSERT

**How to avoid:**
1. Use TEXT for variable-length concatenated data (publication_id, phenotype)
2. Use TEXT for long free-text fields (disease_ontology_name, inheritance)
3. Keep VARCHAR only for truly bounded fields (symbol, hgnc_id)
4. Monitor actual data lengths during refresh (log max lengths per column)

**Warning signs:**
- Error 1406 (Data too long for column)
- Comparisons refresh job fails partway through
- Specific external source consistently fails (e.g., OMIM with long disease names)

**Production evidence:** Issue #158 - Multiple columns too small:
- `version VARCHAR(34)` → `VARCHAR(255)` (version strings from filenames)
- `publication_id VARCHAR(341)` → `TEXT` (multiple PMIDs concatenated)
- `phenotype VARCHAR(1308)` → `TEXT` (HPO terms concatenated)
- `disease_ontology_name VARCHAR(249)` → `TEXT` (long disease names from OMIM/Orphanet)

## Code Examples

Verified patterns from existing codebase and official sources.

### Example 1: Checking Column Type Before Modification

```sql
-- Source: MySQL 8.4 Reference Manual + SysNDD migration 009
-- https://dev.mysql.com/doc/refman/8.4/en/information-schema-columns-table.html

-- Check if column exists and needs widening
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    COLUMN_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'ndd_database_comparison'
  AND COLUMN_NAME = 'version';

-- Conditional modification in stored procedure
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ndd_database_comparison'
      AND COLUMN_NAME = 'version'
      AND (DATA_TYPE = 'varchar' AND CHARACTER_MAXIMUM_LENGTH < 255)
) THEN
    ALTER TABLE ndd_database_comparison
      MODIFY COLUMN version VARCHAR(255);
END IF;
```

### Example 2: Converting VARCHAR to TEXT Safely

```sql
-- Source: SysNDD issue #158 production fix
-- Converting bounded VARCHAR to unbounded TEXT for concatenated data

-- Check if still VARCHAR before converting
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ndd_database_comparison'
      AND COLUMN_NAME IN ('publication_id', 'phenotype', 'disease_ontology_name')
      AND DATA_TYPE = 'varchar'
) THEN
    ALTER TABLE ndd_database_comparison
      MODIFY COLUMN publication_id TEXT,
      MODIFY COLUMN phenotype TEXT,
      MODIFY COLUMN disease_ontology_name TEXT;
END IF;
```

### Example 3: Cache Invalidation Strategies

```r
# Source: memoise package documentation
# https://memoise.r-lib.org/reference/forget.html
# https://memoise.r-lib.org/reference/drop_cache.html

# Strategy 1: Clear all cached results for a function
memoise::forget(gen_string_clust_obj_mem)

# Strategy 2: Clear specific argument combinations
memoise::drop_cache(gen_string_clust_obj_mem)(score_threshold = 800)

# Strategy 3: Version-based automatic invalidation
cache_version <- Sys.getenv("CACHE_VERSION", "1")

gen_string_clust_obj_versioned <- function(score_threshold,
                                          cache_version = cache_version) {
  # cache_version included in cache key, but not used in computation
  gen_string_clust_obj(score_threshold)
}

gen_string_clust_obj_mem <- memoise(
  gen_string_clust_obj_versioned,
  cache = cm
)
```

### Example 4: Migration Test Pattern

```r
# Source: api/tests/testthat/test-unit-migration-runner.R

describe("Migration idempotency", {
  it("can run same migration twice without error", {
    # First run - should apply migration
    result1 <- run_migrations(migrations_dir = test_dir, conn = test_conn)
    expect_equal(result1$newly_applied, 1)

    # Second run - should be no-op (already applied)
    result2 <- run_migrations(migrations_dir = test_dir, conn = test_conn)
    expect_equal(result2$newly_applied, 0)

    # Verify schema_version tracks application
    applied <- get_applied_migrations(test_conn)
    expect_true("012_widen_comparison_columns.sql" %in% applied)
  })
})
```

### Example 5: Verifying Gene2Phenotype URL and Format

```r
# Source: api/functions/comparisons-functions.R (lines 154-178)

# Gene2Phenotype parser handles plain CSV (not gzipped)
parse_gene2phenotype_csv <- function(file_path) {
  data <- readr::read_csv(file_path, show_col_types = FALSE)

  # Column names as of 2026 API format
  result <- data %>%
    dplyr::select(
      gene_symbol = `gene symbol`,
      disease_ontology_name = `disease name`,
      disease_ontology_id = `disease mim`,
      category = confidence,
      inheritance = `allelic requirement`,
      pathogenicity_mode = `variant consequence`,
      phenotype = phenotypes,
      publication_id = publications
    )

  return(result)
}

# Configuration update for new API
# UPDATE comparisons_config
# SET source_url = 'https://www.ebi.ac.uk/gene2phenotype/api/panel/DD/download',
#     file_format = 'csv'
# WHERE source_name = 'gene2phenotype';
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Gene2Phenotype `/downloads` URL | API-based `/api/panel/DD/download` | 2025-2026 | Must update URL and format (csv.gz → csv) |
| VARCHAR for all text columns | TEXT for unbounded/concatenated data | Issue #158 (2026) | Prevents truncation errors on data refresh |
| Manual cache clear only | Should add version-based invalidation | Issue #157 (2026) | Deployment safety, automatic invalidation |
| Raw ALTER TABLE in migrations | Stored procedure + INFORMATION_SCHEMA | Migration 009 (2024) | Idempotent migrations |

**Deprecated/outdated:**
- **Gene2Phenotype old URL:** `https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz` - Use `/api/panel/DD/download` instead
- **File format:** `csv.gz` - New API returns plain `csv`
- **Bare ALTER TABLE:** Use stored procedure pattern for idempotency
- **Infinite cache without versioning:** Add CACHE_VERSION env var for deployment safety

## Open Questions

1. **Should cache versioning be implemented in migration 014?**
   - What we know: Manual cache clearing works, but requires operational knowledge
   - What's unclear: Whether to implement automatic version checking in API startup
   - Recommendation: Document manual process in DEPLOYMENT.md for v10.3, implement automatic versioning in future phase if deployment frequency increases

2. **Should INFORMATION_SCHEMA checks be in every migration?**
   - What we know: Stored procedure pattern used in migrations 007, 009
   - What's unclear: Whether simpler migrations (like 010 UPDATE) need stored procedures
   - Recommendation: Use stored procedures for DDL (ALTER TABLE, CREATE TABLE), simple SQL for DML (UPDATE, INSERT) that is naturally idempotent

3. **How to detect stale cache programmatically?**
   - What we know: No built-in detection in memoise
   - What's unclear: Whether to implement cache validation checks
   - Recommendation: Use version-based keys (CACHE_VERSION env var) rather than validation logic

4. **Should migration 012 modify all columns or only problematic ones?**
   - What we know: Issue #158 lists 8 columns needing changes
   - What's unclear: Whether to widen conservatively (only reported issues) or comprehensively (all text-like columns)
   - Recommendation: Widen all columns identified in issue #158 to prevent future truncation issues

## Sources

### Primary (HIGH confidence)

**Codebase (verified):**
- `api/functions/migration-runner.R` - Migration system architecture
- `db/migrations/009_ndd_database_comparison.sql` - Stored procedure pattern
- `db/migrations/010_fix_radboudumc_url.sql` - Simple UPDATE pattern
- `db/migrations/004_extend_password_column.sql` - ALTER TABLE MODIFY pattern
- `api/start_sysndd_api.R` lines 357-371 - Memoisation setup
- `api/functions/comparisons-functions.R` lines 154-178 - Gene2Phenotype parser

**GitHub Issues (authoritative):**
- [Issue #158](https://github.com/berntpopp/sysndd/issues/158) - Column truncation errors with exact schema fix
- [Issue #156](https://github.com/berntpopp/sysndd/issues/156) - Gene2Phenotype URL and format change
- [Issue #157](https://github.com/berntpopp/sysndd/issues/157) - Stale cache after code deployment

**Official Documentation:**
- [MySQL 8.4 INFORMATION_SCHEMA.COLUMNS](https://dev.mysql.com/doc/refman/8.4/en/information-schema-columns-table.html) - Column metadata queries
- [memoise::forget()](https://memoise.r-lib.org/reference/forget.html) - Cache clearing documentation
- [memoise::drop_cache()](https://memoise.r-lib.org/reference/drop_cache.html) - Selective cache invalidation

### Secondary (MEDIUM confidence)

**Community Resources:**
- [Creating Idempotent DDL Scripts](https://www.red-gate.com/hub/product-learning/flyway/creating-idempotent-ddl-scripts-for-database-migrations) - Migration patterns
- [Idempotent SQL Alter Table Statements](https://gist.github.com/kmoormann/3758257) - INFORMATION_SCHEMA patterns
- [Gene2Phenotype Download](https://www.ebi.ac.uk/gene2phenotype/download) - Official download page showing new API structure

**Package Documentation:**
- [memoise Issue #39](https://github.com/r-lib/memoise/issues/39) - Cache versioning strategies discussion
- [R-hub: Caching in R packages](https://blog.r-hub.io/2021/07/30/cache/) - Best practices for package caching

### Tertiary (LOW confidence)

None - all findings verified with official documentation or authoritative codebase sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in renv.lock, versions verified
- Architecture: HIGH - Patterns extracted from existing migrations and codebase
- Pitfalls: HIGH - All based on actual production issues (#156, #157, #158) with verified fixes

**Research date:** 2026-02-05
**Valid until:** 30 days (2026-03-07) for stable technologies (MySQL, R packages); 7 days for external API changes (Gene2Phenotype)

**Notes:**
- No new dependencies required
- All three fixes use existing infrastructure (migration runner, database config, memoisation)
- External API (Gene2Phenotype) may change again - monitor EBI announcements
- Cache versioning is optional enhancement, not required for v10.3
