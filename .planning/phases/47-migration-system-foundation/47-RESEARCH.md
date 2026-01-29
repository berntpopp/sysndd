# Phase 47: Migration System Foundation - Research

**Researched:** 2026-01-29
**Domain:** Database migrations for R/MySQL (RMariaDB/DBI)
**Confidence:** HIGH

## Summary

This research investigates how to build a database migration system for the SysNDD R API using RMariaDB and DBI. The system must track applied migrations, execute them sequentially, and be idempotent (safe to run multiple times).

Key findings:
1. **MySQL DDL limitations**: CREATE TABLE, ALTER TABLE, and other DDL statements cause implicit commits in MySQL and cannot be rolled back within transactions. This fundamentally affects how we handle migration transactions.
2. **DBI multi-statement execution**: RMariaDB supports multi-statement SQL files via `immediate = TRUE` parameter, which uses `mysql_real_query()` API with `CLIENT_MULTI_STATEMENTS` flag.
3. **DELIMITER is client-only**: The `DELIMITER` command used in migration 003 is a mysql CLI feature, not valid SQL. For programmatic execution, stored procedures can be sent as single statements without DELIMITER wrappers.
4. **Idempotent DDL patterns**: MySQL lacks native `IF NOT EXISTS` for ALTER TABLE. The proven pattern uses stored procedures that query `INFORMATION_SCHEMA.COLUMNS` before applying changes.

**Primary recommendation:** Build a minimal migration runner using existing `db-helpers.R` patterns. Parse SQL files by splitting on `;` (or use custom delimiter for stored procedures), execute statements individually, track state in a `schema_version` table.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DBI | 1.2+ | Database interface abstraction | R-DBI standard, already in use |
| RMariaDB | 1.3+ | MySQL/MariaDB driver | Already used in project, supports `immediate = TRUE` |
| pool | 1.0+ | Connection pooling | Already configured in `start_sysndd_api.R` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| fs | 1.6+ | File system operations | Already loaded, for listing migration files |
| logger | 0.3+ | Logging | Already configured, for migration status output |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom SQL splitter | sqlparseR | sqlparseR requires Python/reticulate dependency; simple regex splitting sufficient for our controlled SQL files |
| Custom migration runner | dbmigrater / dm | Additional dependencies; our needs are simple enough for ~100 lines of custom code |

**Installation:**
No new packages required. All dependencies already present in the project.

## Architecture Patterns

### Recommended Project Structure
```
api/
  functions/
    migration-runner.R      # Core migration execution logic
  db/
    migrations/
      001_add_about_content.sql
      002_add_genomic_annotations.sql   # Will be updated for idempotency
      003_fix_hgnc_column_schema.sql
```

### Pattern 1: Schema Version Table
**What:** A table that tracks which migrations have been applied
**When to use:** Always - this is the foundation of migration tracking

```sql
-- Source: Standard migration pattern (Flyway, Liquibase, etc.)
CREATE TABLE IF NOT EXISTS schema_version (
  filename VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  success BOOLEAN DEFAULT TRUE
);
```

**Key design decisions (from CONTEXT.md):**
- Filename is the primary key (version derived from prefix)
- Only successful migrations recorded
- Minimal metadata: filename, timestamp, success flag

### Pattern 2: Migration Runner Flow
**What:** Sequential execution with state tracking
**When to use:** At startup or on-demand

```r
# Source: Project convention based on DBI best practices
run_migrations <- function(migrations_dir = "db/migrations", conn = NULL) {
  # 1. Ensure schema_version table exists
  ensure_schema_version_table(conn)

  # 2. Get list of migration files (sorted by numeric prefix)
  migration_files <- list_migration_files(migrations_dir)

  # 3. Get already-applied migrations
  applied <- get_applied_migrations(conn)

  # 4. Filter to pending migrations
  pending <- setdiff(migration_files, applied)

  # 5. Execute each pending migration sequentially
  for (file in pending) {
    execute_migration(file, conn)  # Stops on first failure
  }

  # 6. Return summary
  list(applied = length(applied), newly_applied = length(pending))
}
```

### Pattern 3: Individual Migration Execution with Transaction
**What:** Per-migration transaction wrapping for DML statements
**When to use:** For each migration file

```r
# Source: DBI documentation for dbWithTransaction
execute_migration <- function(filepath, conn = NULL) {
  use_conn <- if (is.null(conn)) pool else conn

  sql_content <- readLines(filepath, warn = FALSE) |>
    paste(collapse = "\n")

  # Split into statements (simple approach for controlled SQL)
  statements <- split_sql_statements(sql_content)

  tryCatch({
    for (stmt in statements) {
      if (nchar(trimws(stmt)) > 0) {
        # Use immediate = TRUE to bypass prepared statement limitations
        DBI::dbExecute(use_conn, stmt, immediate = TRUE)
      }
    }
    # Record success
    record_migration(basename(filepath), conn)
    log_info("Migration applied: {basename(filepath)}")
  }, error = function(e) {
    log_error("Migration failed: {basename(filepath)} - {e$message}")
    stop(e)  # Propagate error to stop further migrations
  })
}
```

### Pattern 4: Idempotent DDL via Stored Procedure
**What:** Safe ALTER TABLE that can run multiple times
**When to use:** For any DDL that modifies existing tables

```sql
-- Source: Migration 003 pattern (already in codebase)
-- Note: DELIMITER commands stripped for programmatic execution

CREATE PROCEDURE IF NOT EXISTS add_column_if_not_exists()
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'target_table'
          AND COLUMN_NAME = 'new_column'
    ) THEN
        ALTER TABLE target_table ADD COLUMN new_column VARCHAR(100) NULL;
    END IF;
END;

CALL add_column_if_not_exists();
DROP PROCEDURE IF EXISTS add_column_if_not_exists;
```

### Anti-Patterns to Avoid
- **Mixing DDL and DML in same transaction expecting rollback:** DDL causes implicit commit in MySQL; DML before it will be committed regardless of later errors
- **Using `DELIMITER` in programmatic SQL:** DELIMITER is a mysql client command, not valid SQL for DBI
- **Running migration files with `mysql` CLI from R:** Inconsistent error handling; use DBI for unified approach
- **Editing applied migrations:** Never edit migration files after they've been applied to any database

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connection management | Manual connect/disconnect | `pool` package | Handles connection lifecycle, already configured |
| SQL parameter escaping | String concatenation | `DBI::dbBind()` or parameterized queries | SQL injection prevention |
| Transaction management | Manual BEGIN/COMMIT | `DBI::dbWithTransaction()` | Automatic rollback on error |
| File listing with sorting | Custom directory reading | `fs::dir_ls()` with `sort()` | Handles edge cases, cross-platform |

**Key insight:** The existing `db-helpers.R` provides `db_execute_query()`, `db_execute_statement()`, and `db_with_transaction()` which should be leveraged where possible. However, for multi-statement execution, we need `immediate = TRUE` which requires direct DBI calls.

## Common Pitfalls

### Pitfall 1: MySQL DDL Implicit Commits
**What goes wrong:** Expecting transaction rollback to undo DDL statements
**Why it happens:** MySQL implicitly commits before and after DDL (CREATE, ALTER, DROP)
**How to avoid:** Accept that DDL is auto-committed; design migrations to be individually atomic
**Warning signs:** DML changes persisting despite transaction rollback

**From MySQL 8.4 documentation:**
> "Data definition language (DDL) statements that define or modify database objects cause implicit commits... Most of these statements also cause an implicit commit after executing."

### Pitfall 2: DELIMITER Command in SQL Files
**What goes wrong:** SQL parsing errors when executing stored procedure definitions
**Why it happens:** `DELIMITER //` is a mysql client command, not SQL
**How to avoid:** For files with stored procedures:
  1. Strip `DELIMITER` lines when parsing
  2. Use the delimiter (e.g., `//`) to split statements
  3. Send each procedure definition as a single statement
**Warning signs:** Error "You have an error in your SQL syntax near 'DELIMITER'"

### Pitfall 3: ALTER TABLE Without Idempotency Guards
**What goes wrong:** "Duplicate column name" error on re-run
**Why it happens:** MySQL's ALTER TABLE ADD COLUMN fails if column exists
**How to avoid:** Use stored procedure pattern that checks `INFORMATION_SCHEMA.COLUMNS`
**Warning signs:** Migration works first time, fails on second run

### Pitfall 4: Silent Multi-Statement Failure
**What goes wrong:** Only first statement executes, rest ignored
**Why it happens:** Not using `immediate = TRUE` with RMariaDB
**How to avoid:** Always use `immediate = TRUE` for multi-statement execution, or split statements
**Warning signs:** Tables/columns missing that should exist after migration

### Pitfall 5: Dirty State Detection
**What goes wrong:** Migration started but not recorded (crash mid-execution)
**Why it happens:** Recording happens after execution; system crash between leaves no record
**How to avoid:**
  1. Check for partial schema state before running migrations
  2. Log migration START as well as completion (separate field or log)
  3. Require manual intervention for dirty state
**Warning signs:** Schema has changes but schema_version table shows migration not applied

## Code Examples

Verified patterns from official sources and codebase:

### SQL Statement Splitting (Custom for Controlled Files)
```r
# Source: Project implementation (simple approach for known SQL patterns)
split_sql_statements <- function(sql_content, delimiter = ";") {
  # Handle DELIMITER commands for stored procedures
  if (grepl("DELIMITER", sql_content, ignore.case = TRUE)) {
    return(split_sql_with_custom_delimiter(sql_content))
  }

  # Simple split for standard SQL
  statements <- strsplit(sql_content, paste0(delimiter, "\\s*\n"))[[1]]
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0]
  return(statements)
}

split_sql_with_custom_delimiter <- function(sql_content) {
  # Extract custom delimiter (e.g., "DELIMITER //" -> "//")
  delimiter_match <- regmatches(
    sql_content,
    regexpr("DELIMITER\\s+(\\S+)", sql_content)
  )
  custom_delim <- gsub("DELIMITER\\s+", "", delimiter_match[1])

  # Remove DELIMITER commands
  sql_clean <- gsub("DELIMITER\\s+\\S+\\s*\n?", "", sql_content)

  # Split on custom delimiter, then restore semicolons at end
  statements <- strsplit(sql_clean, paste0("\\", custom_delim, "\\s*\n?"))[[1]]
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0]

  return(statements)
}
```

### Multi-Statement Execution with RMariaDB
```r
# Source: RMariaDB documentation for immediate parameter
# https://rmariadb.r-dbi.org/reference/query

execute_sql_statement <- function(conn, sql) {
  # immediate = TRUE uses mysql_real_query() API
  # This enables multi-statement execution and bypasses prepared statement limits
  DBI::dbExecute(conn, sql, immediate = TRUE)
}
```

### Schema Version Table Operations
```r
# Source: Project convention following Flyway/Liquibase patterns
ensure_schema_version_table <- function(conn = NULL) {
  sql <- "
    CREATE TABLE IF NOT EXISTS schema_version (
      filename VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      success BOOLEAN DEFAULT TRUE
    )
  "
  DBI::dbExecute(conn, sql, immediate = TRUE)
}

get_applied_migrations <- function(conn = NULL) {
  result <- DBI::dbGetQuery(
    conn,
    "SELECT filename FROM schema_version WHERE success = TRUE ORDER BY filename"
  )
  return(result$filename)
}

record_migration <- function(filename, conn = NULL) {
  DBI::dbExecute(
    conn,
    "INSERT INTO schema_version (filename, success) VALUES (?, TRUE)",
    params = list(filename)
  )
}
```

### Migration 002 Idempotent Rewrite
```sql
-- Current (non-idempotent):
ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;

-- Rewritten (idempotent using stored procedure pattern):
CREATE PROCEDURE IF NOT EXISTS migrate_002_genomic_annotations()
BEGIN
    -- Add gnomad_constraints column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'gnomad_constraints'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
    END IF;

    -- Add alphafold_id column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'alphafold_id'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;
    END IF;
END;

CALL migrate_002_genomic_annotations();
DROP PROCEDURE IF EXISTS migrate_002_genomic_annotations;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| RMySQL package | RMariaDB package | 2018+ | RMySQL deprecated, RMariaDB is official replacement |
| Manual connection management | pool package | 2016+ | Automatic connection lifecycle |
| `dbSendQuery()` for DML | `dbExecute()` / `dbSendStatement()` | DBI 1.0+ | Clearer intent, automatic cleanup |

**Deprecated/outdated:**
- RMySQL: Legacy package, use RMariaDB instead
- Manual `dbConnect()`/`dbDisconnect()`: Use pool for connection management in long-running processes

## Open Questions

Things that couldn't be fully resolved:

1. **Exact dirty state detection mechanism**
   - What we know: Need to detect if migration started but didn't complete
   - What's unclear: Best approach - separate "started" column, external log file, or schema inspection?
   - Recommendation: Use schema inspection (check if expected objects exist) combined with timestamp comparison; simple and no extra tracking needed

2. **Verbose output formatting**
   - What we know: Default is summary ("Applied 3 migrations"), optional verbose mode needed
   - What's unclear: Exact format for verbose output
   - Recommendation: Use existing logger levels (INFO for summary, DEBUG for verbose per-statement output)

3. **Transaction boundaries for mixed DDL/DML**
   - What we know: DDL causes implicit commit, DML can be transactional
   - What's unclear: How migration 001 (CREATE TABLE + INSERT) should be handled
   - Recommendation: Accept implicit commits; CREATE TABLE is idempotent via IF NOT EXISTS, INSERT can use ON DUPLICATE KEY or be wrapped in existence check

## Sources

### Primary (HIGH confidence)
- MySQL 8.4 Reference Manual - [Implicit Commits](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html)
- RMariaDB documentation - [Query Execution](https://rmariadb.r-dbi.org/reference/query)
- DBI documentation - [dbExecute](https://dbi.r-dbi.org/reference/dbExecute.html)
- DBI Advanced Usage - [CRAN Vignette](https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html)

### Secondary (MEDIUM confidence)
- MySQL Tutorial - [DELIMITER](https://www.mysqltutorial.org/mysql-stored-procedure/mysql-delimiter/)
- DZone - [Idempotent Migrations](https://dzone.com/articles/trouble-free-database-migration-idempotence-and-co)
- GitHub Gist - [Idempotent MySQL Pattern](https://gist.github.com/stevepereira/60a10935473b075bc5f4)

### Tertiary (LOW confidence)
- WebSearch results for general migration patterns - verified against official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing project dependencies, verified with official docs
- Architecture: HIGH - Based on established migration tool patterns (Flyway, Liquibase) and existing codebase patterns (db-helpers.R, migration 003)
- Pitfalls: HIGH - MySQL implicit commits documented in official MySQL reference, multi-statement execution verified in RMariaDB docs
- SQL splitting: MEDIUM - Custom implementation needed; sqlparseR exists but adds Python dependency

**Research date:** 2026-01-29
**Valid until:** 60 days (stable domain, no expected breaking changes)
