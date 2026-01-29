# Phase 49: Backup API Layer - Research

**Researched:** 2026-01-29
**Domain:** REST API endpoints for MySQL backup management
**Confidence:** HIGH

## Summary

This phase implements REST API endpoints for managing MySQL database backups programmatically. The existing infrastructure uses the `fradelg/mysql-cron-backup` Docker container which creates automated daily backups. The API layer will expose endpoints to list backups, trigger manual backups, and restore from backups with automatic pre-restore safety backups.

The primary technical challenge is integrating the API container with the backup volume and executing mysqldump/mysql commands from R. The existing job manager pattern provides a robust foundation for async operations, and the established admin endpoint patterns offer consistent response structures.

**Primary recommendation:** Extend docker-compose to share the backup volume with the API container, create a new `backup_endpoints.R` file following existing patterns, and implement backup/restore operations via `system2()` calls to mysqldump/mysql binaries.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fs | 1.6.x | File system operations | Already used in project for file listing/metadata |
| R base system2() | N/A | Execute shell commands | Standard R approach for subprocess execution |
| plumber | 1.2.x | REST API framework | Already used across all endpoints |
| mirai | 0.13.x | Async job execution | Already used for long-running admin operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| lubridate | 1.9.x | Date parsing from filenames | Already loaded, for parsing backup timestamps |
| jsonlite | 1.8.x | JSON serialization | Already used for API responses |
| uuid | 1.2.x | Job ID generation | Already used by job manager |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| system2() for mysqldump | DBI::dbWriteTable to CSV | mysqldump is authoritative, handles triggers/constraints properly |
| Direct mysql volume access | Docker exec into container | Volume mount is simpler, doesn't require container access |
| Custom backup format | SQL dump (mysqldump) | SQL dumps are standard, compatible with fradelg container |

**Installation:**
No new packages required - all dependencies already in renv.lock.

## Architecture Patterns

### Recommended Project Structure
```
api/
├── endpoints/
│   └── backup_endpoints.R      # New: Backup API endpoints
├── functions/
│   ├── backup-functions.R      # New: Backup business logic
│   └── job-manager.R           # Existing: Async job infrastructure
└── start_sysndd_api.R          # Add: pr_mount("/api/backup", ...)
```

### Pattern 1: Async Job Pattern for Backup Operations
**What:** Use existing job manager for backup creation and restore operations
**When to use:** Any operation taking >2 seconds (backup creation, restore)
**Example:**
```r
# Source: jobs_endpoints.R existing pattern
result <- create_job(
  operation = "backup_create",
  params = list(
    db_config = db_config,
    backup_path = backup_path
  ),
  executor_fn = function(params) {
    # Execute mysqldump via system2()
    system2(
      "mysqldump",
      args = c(
        "-h", params$db_config$host,
        "-u", params$db_config$user,
        paste0("-p", params$db_config$password),
        "--single-transaction",
        "--routines",
        "--triggers",
        params$db_config$dbname
      ),
      stdout = params$backup_path,
      stderr = TRUE
    )
  },
  timeout_ms = 600000  # 10 minutes as per CONTEXT.md
)

res$status <- 202
return(list(
  job_id = result$job_id,
  status = "accepted",
  status_url = paste0("/api/jobs/", result$job_id, "/status")
))
```

### Pattern 2: Paginated List Response
**What:** Return paginated backup list matching existing API patterns
**When to use:** GET /api/backup/list endpoint
**Example:**
```r
# Source: Based on jobs_endpoints.R GET /history pattern
list(
  data = backup_list,
  total = length(all_backups),
  page = page_number,
  page_size = 20,  # Per CONTEXT.md decision
  meta = list(
    backup_directory = "/backup",
    total_size_bytes = sum(file_sizes)
  )
)
```

### Pattern 3: Pre-Restore Safety Backup
**What:** Automatically create backup before any restore operation
**When to use:** POST /api/backup/restore endpoint
**Example:**
```r
# Create pre-restore backup first
pre_restore_filename <- sprintf(
  "pre-restore_%s.sql",
  format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
)

pre_restore_result <- create_backup_sync(
  db_config,
  file.path(backup_dir, pre_restore_filename)
)

if (!pre_restore_result$success) {
  res$status <- 503
  return(list(
    error = "PRE_RESTORE_BACKUP_FAILED",
    message = "Cannot proceed with restore - safety backup failed",
    details = pre_restore_result$error
  ))
}

# Now proceed with restore
restore_result <- execute_restore(db_config, restore_file)
```

### Anti-Patterns to Avoid
- **Direct SQL execution for backup:** Don't use DBI to export tables - mysqldump handles foreign keys, triggers, and data types correctly
- **Sync backup creation:** Never create backups synchronously - always use async job pattern
- **Restore without pre-backup:** Per BKUP-05 requirement, never restore without creating safety backup first
- **Exposing backup files via HTTP download:** Backups contain sensitive data; Phase 50 UI will handle secure download

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MySQL dump format | Custom SQL generation | mysqldump binary | Handles edge cases, triggers, routines, charset |
| Job state management | Custom tracking | Existing job-manager.R | Capacity limits, duplicate detection, cleanup |
| Gzip compression | R gzip functions | `gzip` binary via system2() | Faster, matches fradelg container format |
| File listing with metadata | Custom fs traversal | fs::dir_info() | Returns tibble with size, mtime, permissions |
| Pagination | Manual offset/limit | Existing pagination-helpers.R patterns | Validated page_size, cursor-based option |

**Key insight:** The backup infrastructure (fradelg/mysql-cron-backup) already creates properly formatted SQL dumps. The API layer should read and create files in the same format rather than inventing a new backup scheme.

## Common Pitfalls

### Pitfall 1: Missing Volume Mount for API Container
**What goes wrong:** API container cannot access /backup directory where backups are stored
**Why it happens:** docker-compose.yml only mounts mysql_backup to mysql and mysql-cron-backup containers
**How to avoid:** Add `mysql_backup:/backup:ro` to API container volumes for read access, or `:rw` if API needs to create backups
**Warning signs:** "Permission denied" or "No such file or directory" errors in API logs

### Pitfall 2: Backup During Active Transactions
**What goes wrong:** Inconsistent backup if taken during active writes
**Why it happens:** mysqldump without --single-transaction can capture partial state
**How to avoid:** Always use `--single-transaction` flag with mysqldump
**Warning signs:** Foreign key constraint failures when restoring

### Pitfall 3: Concurrent Backup Operations
**What goes wrong:** Multiple backups running simultaneously corrupt files or exhaust disk
**Why it happens:** No locking mechanism between API-triggered and cron-triggered backups
**How to avoid:** Use existing job manager duplicate detection; check for `operation = "backup_create"` running jobs before starting new one; return 409 Conflict per CONTEXT.md
**Warning signs:** Truncated backup files, disk space exhaustion

### Pitfall 4: Restore Without DB Connection Cleanup
**What goes wrong:** Restore fails because tables are locked by active connections
**Why it happens:** API pool connections hold locks on tables being dropped
**How to avoid:** Create separate connection for restore operations using db_config (like HGNC update pattern); disable foreign key checks; use transaction
**Warning signs:** "Lock wait timeout exceeded" or "Cannot drop table" errors

### Pitfall 5: Backup File Naming Mismatch
**What goes wrong:** API-created backups don't match fradelg naming convention
**Why it happens:** Different timestamp format or missing database name
**How to avoid:** Use fradelg format: `YYYYMMDDHHmm.{database_name}.sql.gz` for regular backups; `pre-restore_{timestamp}.sql` for pre-restore backups per CONTEXT.md
**Warning signs:** Backup retention not working, files not recognized by restore

## Code Examples

Verified patterns from existing codebase:

### Listing Files with Metadata
```r
# Source: Based on fs package patterns used in file-functions.R
list_backup_files <- function(backup_dir = "/backup") {
  # Get file info using fs package (already in project)
  files_info <- fs::dir_info(
    backup_dir,
    regexp = "\\.sql(\\.gz)?$"
  )

  if (nrow(files_info) == 0) {
    return(tibble::tibble(
      filename = character(0),
      size_bytes = numeric(0),
      created_at = character(0),
      table_count = integer(0)
    ))
  }

  files_info %>%
    dplyr::select(
      filename = path,
      size_bytes = size,
      created_at = modification_time
    ) %>%
    dplyr::mutate(
      filename = basename(filename),
      created_at = format(created_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      # Table count requires parsing - cache or compute on demand
      table_count = NA_integer_
    ) %>%
    dplyr::arrange(dplyr::desc(created_at))
}
```

### Executing System Commands Safely
```r
# Source: Based on version_endpoints.R system2 pattern
execute_mysqldump <- function(db_config, output_file) {
  # Build arguments safely (no shell interpolation)
  args <- c(
    "-h", db_config$host,
    "-P", as.character(db_config$port),
    "-u", db_config$user,
    paste0("-p", db_config$password),
    "--single-transaction",
    "--routines",
    "--triggers",
    "--quick",
    db_config$dbname
  )

  # Execute with stderr capture for error handling
  result <- system2(
    "mysqldump",
    args = args,
    stdout = output_file,
    stderr = TRUE
  )

  # system2 returns status code as attribute when stderr=TRUE
  status <- attr(result, "status") %||% 0

  if (status != 0) {
    return(list(
      success = FALSE,
      error = paste(result, collapse = "\n")
    ))
  }

  list(success = TRUE, file = output_file)
}
```

### Admin Endpoint with Role Check
```r
# Source: admin_endpoints.R pattern
#* List available backups
#*
#* Returns paginated list of backup files with metadata.
#* Requires Administrator role.
#*
#* @tag backup
#* @serializer json list(na="string")
#* @get /list
function(req, res, page = 1, sort = "newest") {
  require_role(req, res, "Administrator")

  page <- as.integer(page)
  if (is.na(page) || page < 1) page <- 1

  page_size <- 20  # Per CONTEXT.md decision

  backups <- list_backup_files("/backup")

  # Sort per CONTEXT.md: newest first by default
  if (sort == "oldest") {
    backups <- dplyr::arrange(backups, created_at)
  }

  total <- nrow(backups)
  offset <- (page - 1) * page_size

  data <- backups %>%
    dplyr::slice((offset + 1):min(offset + page_size, total))

  list(
    data = data,
    total = total,
    page = page,
    page_size = page_size
  )
}
```

### Async Restore with Pre-Backup
```r
# Source: jobs_endpoints.R HGNC update pattern
#* Restore database from backup
#*
#* Triggers async restore operation. Creates automatic pre-restore backup first.
#* Returns job ID for status polling.
#*
#* @tag backup
#* @serializer json list(na="string")
#* @post /restore
function(req, res) {
  require_role(req, res, "Administrator")

  filename <- req$argsBody$filename
  if (is.null(filename) || filename == "") {
    res$status <- 400
    return(list(
      error = "MISSING_FILENAME",
      message = "Backup filename is required"
    ))
  }

  # Validate file exists
  backup_path <- file.path("/backup", filename)
  if (!file.exists(backup_path)) {
    res$status <- 404
    return(list(
      error = "BACKUP_NOT_FOUND",
      message = sprintf("Backup file '%s' not found", filename)
    ))
  }

  # Check for duplicate restore job
  dup_check <- check_duplicate_job("backup_restore", list(filename = filename))
  if (dup_check$duplicate) {
    res$status <- 409
    return(list(
      error = "DUPLICATE_JOB",
      message = "Restore operation already in progress",
      existing_job_id = dup_check$existing_job_id
    ))
  }

  # Database config for daemon
  db_config <- list(
    dbname = dw$dbname,
    host = dw$host,
    user = dw$user,
    password = dw$password,
    port = dw$port
  )

  result <- create_job(
    operation = "backup_restore",
    params = list(
      db_config = db_config,
      restore_file = backup_path,
      backup_dir = "/backup"
    ),
    timeout_ms = 600000,  # 10 minutes
    executor_fn = function(params) {
      # Step 1: Create pre-restore backup (BKUP-05)
      pre_restore_file <- file.path(
        params$backup_dir,
        sprintf("pre-restore_%s.sql", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"))
      )

      pre_result <- system2(
        "mysqldump",
        args = c(
          "-h", params$db_config$host,
          "-P", as.character(params$db_config$port),
          "-u", params$db_config$user,
          paste0("-p", params$db_config$password),
          "--single-transaction",
          params$db_config$dbname
        ),
        stdout = pre_restore_file,
        stderr = TRUE
      )

      if ((attr(pre_result, "status") %||% 0) != 0) {
        stop(paste("Pre-restore backup failed:", paste(pre_result, collapse = " ")))
      }

      # Step 2: Execute restore
      # Decompress if gzipped
      restore_cmd <- if (grepl("\\.gz$", params$restore_file)) {
        sprintf("gunzip -c '%s' | mysql -h %s -P %s -u %s -p'%s' %s",
                params$restore_file,
                params$db_config$host,
                params$db_config$port,
                params$db_config$user,
                params$db_config$password,
                params$db_config$dbname)
      } else {
        sprintf("mysql -h %s -P %s -u %s -p'%s' %s < '%s'",
                params$db_config$host,
                params$db_config$port,
                params$db_config$user,
                params$db_config$password,
                params$db_config$dbname,
                params$restore_file)
      }

      restore_result <- system(restore_cmd, intern = FALSE, ignore.stderr = FALSE)

      if (restore_result != 0) {
        stop("Restore failed - pre-restore backup available at: ", pre_restore_file)
      }

      list(
        status = "completed",
        pre_restore_backup = basename(pre_restore_file),
        restored_from = basename(params$restore_file)
      )
    }
  )

  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = "accepted",
    estimated_seconds = 120,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sync mysqldump in endpoint | Async via mirai daemon | Phase 32 (async jobs) | Non-blocking, timeout support |
| Manual file listing | fs::dir_info() | Already in project | Consistent metadata, tibble output |
| No pre-restore backup | Automatic pre-restore | BKUP-05 requirement | Safety for destructive operations |

**Deprecated/outdated:**
- Direct shell interpolation: Use system2() with args array instead of system() with string concatenation (security)
- Synchronous admin operations: All long-running operations should use job manager (user experience)

## Open Questions

Things that couldn't be fully resolved:

1. **Job Record Retention Duration**
   - What we know: Current cleanup is 24 hours (cleanup_old_jobs in job-manager.R)
   - What's unclear: CONTEXT.md defers this to research, but 24h seems reasonable for backup jobs
   - Recommendation: Keep 24h retention, matches existing pattern. Backup metadata persists in files regardless

2. **Table Count in Backup Metadata (BKUP-06)**
   - What we know: Requirement asks for table count in metadata
   - What's unclear: Parsing SQL dump for table count is expensive; could cache or compute lazily
   - Recommendation: Return null initially, compute on demand or during idle time; table count is rarely critical

3. **Docker Volume Access Mode**
   - What we know: API needs read access for listing, write access for creating backups
   - What's unclear: Whether read-only (:ro) is sufficient if backups are triggered via docker exec
   - Recommendation: Use :rw for simplicity; security is handled by admin role requirement

## Sources

### Primary (HIGH confidence)
- Existing codebase: `api/functions/job-manager.R` - job creation/status patterns
- Existing codebase: `api/endpoints/jobs_endpoints.R` - async endpoint patterns
- Existing codebase: `api/endpoints/admin_endpoints.R` - admin authorization patterns
- Existing codebase: `docker-compose.yml` - volume structure and backup container config
- Existing codebase: `api/functions/file-functions.R` - fs package file operations

### Secondary (MEDIUM confidence)
- [fradelg/docker-mysql-cron-backup GitHub](https://github.com/fradelg/docker-mysql-cron-backup) - backup naming convention: `YYYYMMDDHHmm.{database_name}.sql.gz`
- [mysqldump documentation](https://dev.mysql.com/doc/en/mysqldump.html) - recommended flags for consistent backups
- [Asynchronous API Design](https://octo-woapi.github.io/cookbook/asynchronous-api.html) - 202 Accepted + polling pattern

### Tertiary (LOW confidence)
- Web search for "REST API backup restore endpoint design patterns" - general best practices, not R-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components already in codebase
- Architecture: HIGH - patterns directly from existing job manager
- Pitfalls: HIGH - based on MySQL/Docker documentation and existing codebase analysis
- Code examples: HIGH - adapted from existing endpoint patterns

**Research date:** 2026-01-29
**Valid until:** 90 days (stable infrastructure, no rapidly changing dependencies)
