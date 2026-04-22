# Stack Research: v9.0 Production Readiness

**Project:** SysNDD Developer Experience Improvements
**Researched:** 2026-01-29
**Overall Confidence:** HIGH (custom approach leverages existing stack, no new R packages needed)

## Executive Summary

For v9.0 Production Readiness, **no new R packages are required**. The four production features (migrations, backup management, SMTP testing, Docker validation) can be implemented using existing stack components plus one Docker service addition (Mailpit). The migration system will be custom R code using existing DBI/RMariaDB. Backup management leverages the existing `fradelg/mysql-cron-backup` container via R's `system2()`. SMTP testing adds Mailpit as a development Docker service. Production Docker validation extends existing health check patterns.

## Recommended Stack

### Migration System

**Recommendation:** Custom R migration runner using existing DBI + RMariaDB (already in renv.lock)

| Component | Existing? | Why |
|-----------|-----------|-----|
| DBI | Yes | Already used in `db-helpers.R` for parameterized queries |
| RMariaDB | Yes | Already used for MySQL connectivity |
| pool | Yes | Already used for connection pooling |
| logger | Yes | Already used for structured logging |
| fs | Yes | Already used for file operations |

**Implementation Pattern:**
```r
# migrate.R - leverages existing db-helpers.R patterns
source("functions/db-helpers.R")

# Create schema_version table if not exists
db_execute_statement("
  CREATE TABLE IF NOT EXISTS schema_version (
    version INT PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    checksum VARCHAR(64),
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
")

# Get pending migrations
applied <- db_execute_query("SELECT version FROM schema_version")
pending <- find_pending_migrations("db/migrations/", applied$version)

# Apply each in transaction
for (migration in pending) {
  db_with_transaction({
    sql <- readLines(migration$path)
    # Execute migration SQL
    # Record in schema_version
  })
}
```

**Rationale:**
- SysNDD already has sophisticated DB helpers (`db_execute_query`, `db_execute_statement`, `db_with_transaction`)
- No benefit from external tools (Flyway would add Java dependency, Liquibase adds complexity)
- 3 migrations exist in `db/migrations/` - custom runner integrates naturally
- Can run automatically on API startup (before `pr_run()`)

**Sources:**
- [Database Migration Best Practices](https://www.bacancytechnology.com/blog/database-migration-best-practices) - recommends small, focused migrations
- [Rails Data Migration Guide](https://www.railscarma.com/blog/rails-data-migration-best-practices-guide/) - patterns for custom migration systems

---

### Backup Management

**Recommendation:** API endpoints calling `mysqldump`/`mysql` via `system2()` + leverage existing backup volume

| Component | Existing? | Why |
|-----------|-----------|-----|
| fradelg/mysql-cron-backup | Yes | Already running daily backups to `mysql_backup` volume |
| system2() | Base R | Execute shell commands from R |
| fs | Yes | List backup files, get metadata |

**Implementation Pattern:**

**Trigger Backup (API endpoint):**
```r
#* POST /api/admin/backups/trigger
trigger_backup <- function() {
  timestamp <- format(Sys.time(), "%Y%m%d%H%M%S")
  filename <- sprintf("%s.sysndd_db.sql.gz", timestamp)

  result <- system2(
    "mysqldump",
    args = c(
      "-h", dw$host,
      "-u", "root",
      sprintf("-p%s", Sys.getenv("MYSQL_ROOT_PASSWORD")),
      "--single-transaction",
      "--routines",
      "--triggers",
      dw$dbname
    ),
    stdout = TRUE,
    stderr = TRUE
  )

  # Compress and write to /backup volume
  # Return backup metadata
}
```

**List Backups (API endpoint):**
```r
#* GET /api/admin/backups
list_backups <- function() {
  files <- fs::dir_info("/backup", glob = "*.sql.gz")
  files %>%
    select(path, size, modification_time) %>%
    arrange(desc(modification_time))
}
```

**Restore Backup (API endpoint):**
```r
#* POST /api/admin/backups/restore
restore_backup <- function(filename, confirmation) {
  # Require typed confirmation matching "RESTORE [filename]"
  if (confirmation != sprintf("RESTORE %s", filename)) {
    stop_for_bad_request("Confirmation text does not match")
  }

  # Auto-backup before restore
  trigger_backup()

  # Restore via mysql client
  system2(
    "bash",
    args = c("-c", sprintf("gunzip -c /backup/%s | mysql ...", filename)),
    stdout = TRUE,
    stderr = TRUE
  )
}
```

**Rationale:**
- `mysql_backup` Docker volume already exists and contains backups
- `fradelg/mysql-cron-backup` handles automated daily backups
- API just needs to expose management capabilities (list, trigger, restore)
- `system2()` is standard R pattern for shell integration
- Docker Compose mounts `/backup` volume to API container for access

**Required docker-compose.yml change:**
```yaml
api:
  volumes:
    # ... existing mounts ...
    - mysql_backup:/backup:ro  # Read backup files
```

For restore, either:
1. Execute restore via `mysql-cron-backup` container (has restore.sh)
2. Install mysql-client in API container

**Sources:**
- [fradelg/docker-mysql-cron-backup](https://github.com/fradelg/docker-mysql-cron-backup) - documents restore.sh interface
- [MySQL Backup and Restore Guide 2026](https://dev.to/piteradyson/mysql-backup-and-restore-complete-guide-to-mysql-database-backup-strategies-in-2026-4cdk)
- [mysqldump Reference](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)

---

### SMTP Testing

**Recommendation:** Mailpit for local development (replaces real SMTP in dev)

| Tool | Version | Why |
|------|---------|-----|
| axllent/mailpit | latest (1.27+) | Modern replacement for abandoned MailHog, actively maintained |

**Docker Compose Addition (docker-compose.override.yml):**
```yaml
services:
  mailpit:
    image: axllent/mailpit:latest
    container_name: sysndd_mailpit
    restart: unless-stopped
    ports:
      - "127.0.0.1:8025:8025"  # Web UI
      - "127.0.0.1:1025:1025"  # SMTP
    environment:
      MP_MAX_MESSAGES: 500
      MP_SMTP_AUTH_ACCEPT_ANY: 1
      MP_SMTP_AUTH_ALLOW_INSECURE: 1
      TZ: UTC
    networks:
      - backend
    deploy:
      resources:
        limits:
          memory: 128M
```

**API config.yml addition (development profile):**
```yaml
sysndd_db_dev_mailpit:
  # ... other settings ...
  mail_noreply_host: "mailpit"
  mail_noreply_port: 1025
  mail_noreply_use_ssl: FALSE
```

**blastula integration:** No changes needed - existing `send_noreply_email()` works with any SMTP server. Just configure host/port to point to Mailpit.

**Verification workflow:**
1. Start Docker Compose with Mailpit
2. Trigger user registration/approval in API
3. View captured emails at http://localhost:8025
4. Verify email content, links, formatting

**Why Mailpit over alternatives:**

| Tool | Status | Recommendation |
|------|--------|----------------|
| Mailpit | Actively maintained (2022+) | **Use this** |
| MailHog | Abandoned (last release 2020) | Avoid - security concerns |
| Mailcatcher | Ruby-based, limited features | Avoid - extra dependency |
| Mailtrap | Cloud service, requires account | Production testing only |

**Sources:**
- [Mailpit Docker Documentation](https://mailpit.axllent.org/docs/install/docker/)
- [Mailpit GitHub](https://github.com/axllent/mailpit) - 7k+ stars, active development
- [Mailpit vs MailHog Comparison](https://www.houseoffoss.com/post/mailpit-vs-mailhog-2025-email-testing-showdown)
- [Jeff Geerling - Local Email Debugging with Mailpit](https://www.jeffgeerling.com/blog/2026/mailpit-local-email-debugging/)

---

### Production Docker

**Recommendation:** Extend existing health check patterns for multi-worker validation

**Current State:**
- `/health/` endpoint exists - lightweight, no auth, returns status/version
- `/health/performance` endpoint exists - reports worker pool and cache status
- Dockerfile has HEALTHCHECK using curl to `/health/`
- docker-compose.yml has healthcheck with 60s start_period

**Multi-Worker Validation Pattern:**

For production 4-worker setup, the existing health endpoint is insufficient. Need to verify:
1. API process is running (current)
2. Database connectivity (new)
3. mirai worker pool has capacity (existing via /health/performance)

**Enhanced health check endpoint:**
```r
#* GET /health/ready
function(req, res) {
  checks <- list()

  # 1. Database connectivity
  db_ok <- tryCatch({
    result <- db_execute_query("SELECT 1 as ping")
    nrow(result) == 1
  }, error = function(e) FALSE)
  checks$database <- db_ok

  # 2. Worker pool
  worker_ok <- tryCatch({
    status <- mirai::status()
    length(status$connections) >= 1
  }, error = function(e) FALSE)
  checks$workers <- worker_ok

  # Overall status
  all_ok <- all(unlist(checks))

  if (!all_ok) {
    res$status <- 503
  }

  list(
    ready = all_ok,
    checks = checks,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}
```

**Production docker-compose.yml pattern:**
```yaml
api:
  build: ./api/
  deploy:
    replicas: 4  # Multi-worker via Docker Compose
    resources:
      limits:
        memory: 2048M  # Per worker
  healthcheck:
    test: ["CMD", "curl", "-sf", "http://localhost:7777/health/ready"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 120s  # Longer for multi-worker startup
```

**Traefik load balancing:** Already configured for multi-container routing via Docker provider.

**Sources:**
- [Three Useful Endpoints for Any Plumber API](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html) - health check patterns
- [Docker Compose Health Checks Guide](https://last9.io/blog/docker-compose-health-checks/)
- [Production Plumber with Docker](https://mlr-org.com/gallery/technical/2020-08-13-a-production-example-using-plumber-and-docker/)

---

## Integration Points

### How These Integrate with Existing Stack

| Feature | Integration Point | Existing Component |
|---------|-------------------|-------------------|
| Migration System | `start_sysndd_api.R` startup | DBI, pool, db-helpers.R |
| Backup API | New endpoints file | db-helpers.R patterns, system2() |
| Backup Volume | docker-compose.yml | Existing mysql_backup volume |
| SMTP Testing | docker-compose.override.yml | Existing blastula email sending |
| Health Checks | health_endpoints.R | Existing health infrastructure |

### API Startup Sequence (with migrations)

```r
# start_sysndd_api.R (modified)

# 1. Load libraries (existing)
# 2. Load config (existing)
# 3. Create pool (existing)

# 4. NEW: Run migrations before API starts
source("functions/migration-runner.R")
run_pending_migrations(pool)

# 5. Load endpoints (existing)
# 6. Start API (existing)
root %>% pr_run(host = "0.0.0.0", port = as.numeric(dw$port_self))
```

### Admin UI Integration (Vue)

The backup management page at `/admin/backups` will use:
- Existing admin layout patterns
- Existing API composable patterns (`useApi`)
- Existing confirmation modal patterns (typed "DELETE" confirmation)
- Table components for backup list

---

## What NOT to Add

| Tool/Package | Why NOT |
|--------------|---------|
| Flyway | Adds Java dependency to R-based stack; overkill for 3 migrations |
| Liquibase | XML/YAML complexity not needed; custom R solution simpler |
| dbmigrater R package | Does not exist as a maintained package |
| MailHog | Abandoned since 2020; security concerns; Mailpit is actively maintained |
| Mailcatcher | Ruby dependency; Mailpit is single binary with no deps |
| Mailtrap/Mailosaur | Cloud services requiring accounts; local testing preferred |
| New R packages for backup | `system2()` + existing `fs` package sufficient |
| External backup tools | fradelg/mysql-cron-backup already running |
| Kubernetes | Docker Compose sufficient for current scale |
| Redis for health state | Overkill; health checks query current state |

---

## Sources

### Migration System
- [Database Migration Best Practices](https://www.bacancytechnology.com/blog/database-migration-best-practices)
- [Rails Data Migration Guide](https://www.railscarma.com/blog/rails-data-migration-best-practices-guide/)
- [CloudBees Database Migration](https://www.cloudbees.com/blog/database-migration)

### Backup Management
- [fradelg/docker-mysql-cron-backup GitHub](https://github.com/fradelg/docker-mysql-cron-backup)
- [fradelg/mysql-cron-backup Docker Hub](https://hub.docker.com/r/fradelg/mysql-cron-backup)
- [MySQL mysqldump Reference](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)
- [MySQL Backup Guide 2026](https://dev.to/piteradyson/mysql-backup-and-restore-complete-guide-to-mysql-database-backup-strategies-in-2026-4cdk)

### SMTP Testing
- [Mailpit Official Documentation](https://mailpit.axllent.org/)
- [Mailpit Docker Installation](https://mailpit.axllent.org/docs/install/docker/)
- [Mailpit GitHub Repository](https://github.com/axllent/mailpit)
- [Mailpit vs MailHog Comparison 2025](https://www.houseoffoss.com/post/mailpit-vs-mailhog-2025-email-testing-showdown)
- [Jeff Geerling - Mailpit Local Email Debugging](https://www.jeffgeerling.com/blog/2026/mailpit-local-email-debugging/)

### Production Docker
- [Three Useful Endpoints for Plumber APIs](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html)
- [Docker Compose Health Checks](https://last9.io/blog/docker-compose-health-checks/)
- [Production Plumber with Docker](https://mlr-org.com/gallery/technical/2020-08-13-a-production-example-using-plumber-and-docker/)
- [Docker Health Check Guide](https://lumigo.io/container-monitoring/docker-health-check-a-practical-guide/)

---

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Migration System | HIGH | Uses existing DBI/pool patterns from db-helpers.R |
| Backup Management | HIGH | fradelg/mysql-cron-backup already running; system2() is standard R |
| SMTP Testing | HIGH | Mailpit well-documented, drop-in SMTP replacement |
| Production Docker | HIGH | Extends existing health check patterns |

---

*Last updated: 2026-01-29*
