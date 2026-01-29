# Architecture Research: v9.0 Production Readiness

**Domain:** Production readiness features for SysNDD (R/Plumber + Vue 3)
**Researched:** 2026-01-29
**Confidence:** HIGH (based on codebase analysis of existing patterns)

## Integration Overview

SysNDD uses a layered architecture with clear separation of concerns:

```
Vue 3 Frontend (app/)
    |
    v
Traefik Proxy (docker-compose)
    |
    v
R/Plumber API (api/)
    |-- endpoints/*.R       (HTTP handlers)
    |-- services/*.R        (Business logic)
    |-- functions/*.R       (Repositories, helpers)
    |-- core/*.R            (Security, errors, middleware)
    |
    v
MySQL 8.0 (docker-compose)
```

Production readiness features integrate at different layers:
- **Migration System**: API startup script + new functions
- **Backup Management**: New endpoint file + admin UI view
- **SMTP**: Existing infrastructure in helper-functions.R
- **Docker**: docker-compose.yml configuration changes

---

## Migration System Architecture

### Integration Points

1. **API Startup Script** (`api/start_sysndd_api.R`)
   - Lines 100-161: Helper function loading section
   - Migration runner should execute between DB pool creation (line 179-187) and API startup (line 597)
   - Pattern: Source migration module, then call `run_pending_migrations(pool)`

2. **Database Layer** (`api/functions/db-helpers.R`)
   - `db_execute_query()` - For reading migration state
   - `db_execute_statement()` - For executing DDL
   - `db_with_transaction()` - For atomic migration execution

3. **Configuration** (`api/config.yml`)
   - All config values via `dw$` object
   - Migration settings can be added: `migration_path`, `auto_migrate`

### New Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `migration-runner.R` | `api/functions/` | Core migration logic |
| `migrations/` | `api/migrations/` | SQL migration files |
| `_schema_migrations` | MySQL table | Track applied migrations |

### Migration Runner Design

```r
# api/functions/migration-runner.R

#' Run pending database migrations
#'
#' Called during API startup. Reads migrations from api/migrations/,
#' tracks state in _schema_migrations table.
#'
#' @param pool Database pool object
#' @param migrations_dir Path to migrations directory (default: "migrations/")
#' @return List with count of applied migrations
run_pending_migrations <- function(pool, migrations_dir = "migrations/") {
  # 1. Ensure _schema_migrations table exists
  # 2. Get list of applied migrations from DB
  # 3. Get list of migration files from filesystem
  # 4. Apply pending migrations in order
  # 5. Return summary
}
```

### Data Flow

```
API Container Startup
    |
    v
start_sysndd_api.R
    |
    v
Source migration-runner.R (line ~145)
    |
    v
Create DB pool (line 179)
    |
    v
Call run_pending_migrations(pool)  <-- NEW
    |
    v
For each pending migration:
    |-- BEGIN TRANSACTION
    |-- Execute SQL
    |-- INSERT INTO _schema_migrations
    |-- COMMIT
    |
    v
Continue to endpoint mounting (line 505+)
```

### Migration File Naming Convention

```
api/migrations/
  V001__create_schema_migrations_table.sql
  V002__add_backup_metadata_table.sql
  V003__add_user_email_verified_column.sql
```

Format: `V{sequence}__{description}.sql`
- Sequence: Zero-padded 3-digit number
- Description: Snake_case description
- Separator: Double underscore

---

## Backup Management Architecture

### Integration Points

1. **Admin Endpoints** (`api/endpoints/admin_endpoints.R`)
   - Existing pattern: `@tag admin`, Administrator role check
   - Lines 217-337: Async job pattern (ontology update) - perfect template

2. **Job Manager** (`api/functions/job-manager.R`)
   - `create_job()` - For async backup execution
   - `get_job_status()` - For polling backup progress
   - Existing pattern handles capacity, deduplication, cleanup

3. **Docker Compose** (`docker-compose.yml`)
   - Lines 75-98: Existing `mysql-cron-backup` container
   - Volume: `mysql_backup:/backup`
   - This container writes to the backup volume

4. **Admin Views** (`app/src/views/admin/`)
   - 6 existing admin views provide template
   - Pattern: `Manage*.vue` or `View*.vue`

### New Components

**Backend (API)**

| Component | Location | Purpose |
|-----------|----------|---------|
| `backup_endpoints.R` | `api/endpoints/` | Backup API endpoints |
| `backup-service.R` | `api/services/` | Backup business logic |
| `backup-repository.R` | `api/functions/` | DB queries for backup metadata |

**Frontend (App)**

| Component | Location | Purpose |
|-----------|----------|---------|
| `ManageBackups.vue` | `app/src/views/admin/` | Admin backup UI |
| `useBackupManagement.ts` | `app/src/composables/` | Backup state management (optional) |

### Backup Endpoint Design

```r
# api/endpoints/backup_endpoints.R

#* List available backups
#* @tag backup
#* @get /
function(req, res) {
  require_role(req, res, "Administrator")
  # List files from /backup volume
  # Return metadata: filename, size, created_at
}

#* Trigger manual backup (async)
#* @tag backup
#* @post /create
function(req, res) {
  require_role(req, res, "Administrator")
  # Create async job via job-manager
  # Execute mysqldump in background
  res$status <- 202
  list(job_id = job_id, status = "accepted")
}

#* Download backup file
#* @tag backup
#* @get /<filename>/download
function(req, res, filename) {
  require_role(req, res, "Administrator")
  # Validate filename (no path traversal)
  # Stream file from /backup volume
}

#* Delete backup
#* @tag backup
#* @delete /<filename>
function(req, res, filename) {
  require_role(req, res, "Administrator")
  # Validate filename
  # Delete from /backup volume
}
```

### Mount Point

In `start_sysndd_api.R`, add after line 520:
```r
pr_mount("/api/backup", pr("endpoints/backup_endpoints.R")) %>%
```

### Data Flow

```
Admin UI (ManageBackups.vue)
    |
    |-- GET /api/backup/          --> List backups from /backup volume
    |-- POST /api/backup/create   --> Submit async job
    |-- GET /api/jobs/{id}/status --> Poll job progress (existing endpoint)
    |-- GET /api/backup/{name}/download --> Stream backup file
    |-- DELETE /api/backup/{name} --> Remove backup file
    |
    v
Backup Endpoints
    |
    v
mysql_backup Docker volume (/backup in containers)
```

### Admin UI Pattern

Following `ManageOntology.vue` pattern (lines 344-801):

```vue
<!-- app/src/views/admin/ManageBackups.vue -->
<template>
  <BContainer>
    <!-- Backup List Table -->
    <GenericTable :items="backups" :fields="fields">
      <template #cell-actions="{ row }">
        <BButton @click="downloadBackup(row)">Download</BButton>
        <BButton @click="deleteBackup(row)">Delete</BButton>
      </template>
    </GenericTable>

    <!-- Manual Backup Button with Progress -->
    <BButton @click="triggerBackup">Create Backup</BButton>
    <BProgress v-if="isBackingUp" :value="progress" />
  </BContainer>
</template>

<script>
import { useAsyncJob } from '@/composables';
// ... rest follows ManageOntology pattern
</script>
```

### Async Job Integration

Use existing `useAsyncJob` composable (app/src/composables/useAsyncJob.ts):

```typescript
const { startJob, status, progress, elapsedTimeDisplay } = useAsyncJob(
  (jobId) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

async function triggerBackup() {
  const response = await axios.post('/api/backup/create');
  startJob(response.data.job_id);
}
```

---

## SMTP Integration Architecture

### Existing Infrastructure

SMTP is already fully implemented in SysNDD:

1. **Configuration** (`api/config.yml` lines 17-22)
   ```yaml
   mail_noreply_user: "noreply@sysndd.org"
   mail_noreply_host: "smtp.strato.de"
   mail_noreply_port: 587
   mail_noreply_use_ssl: TRUE
   ```

2. **Helper Function** (`api/functions/helper-functions.R` lines 184-218)
   ```r
   send_noreply_email <- function(email_body_text, email_subject,
                                   email_recipient, email_blind_copy) {
     email <- compose_email(body = md(paste0(...)))
     email %>% smtp_send(
       from = "noreply@sysndd.org",
       credentials = creds_envvar(
         pass_envvar = "SMTP_PASSWORD",
         user = dw$mail_noreply_user,
         host = dw$mail_noreply_host,
         port = dw$mail_noreply_port,
         use_ssl = dw$mail_noreply_use_ssl
       )
     )
   }
   ```

3. **Library** (`api/start_sysndd_api.R` line 52)
   ```r
   library(blastula)
   ```

4. **Environment Variable** (`docker-compose.yml` line 121)
   ```yaml
   SMTP_PASSWORD: ${SMTP_PASSWORD}
   ```

### Current Usage

SMTP is used in 5 locations:
- User approval notifications (`api/services/user-service.R` lines 149, 388)
- Password reset requests (`api/endpoints/authentication_endpoints.R` line 91)
- User registration (`api/endpoints/user_endpoints.R` lines 235, 484, 703)
- Re-review notifications (`api/endpoints/re_review_endpoints.R` line 345)

### Integration Points for Production Readiness

For production readiness, SMTP might be extended for:
- Backup completion notifications
- Migration failure alerts
- Monitoring alerts

**Recommended Pattern**: Extend existing `send_noreply_email()` or create:

```r
# api/functions/notification-functions.R

#' Send admin notification email
#'
#' Wrapper around send_noreply_email for admin alerts.
#'
#' @param subject Email subject
#' @param body Email body text
#' @param admin_emails Optional vector of admin emails (defaults to all admins)
send_admin_notification <- function(subject, body, admin_emails = NULL) {
  if (is.null(admin_emails)) {
    # Get admin emails from user table
    admin_emails <- pool %>%
      tbl("user") %>%
      filter(user_role == "Administrator", account_status == "active") %>%
      select(email) %>%
      collect() %>%
      pull(email)
  }

  for (email in admin_emails) {
    tryCatch(
      send_noreply_email(body, subject, email, NULL),
      error = function(e) logger::log_error("Failed to send admin email: {e$message}")
    )
  }
}
```

---

## Production Docker Architecture

### Current Configuration

```yaml
# docker-compose.yml structure
services:
  traefik:      # Reverse proxy (port 80)
  mysql:        # Database (internal network only)
  mysql-cron-backup:  # Automated backups
  api:          # R/Plumber API
  app:          # Vue frontend

networks:
  proxy:        # Public-facing (traefik, api, app)
  backend:      # Internal (mysql, api, mysql-cron-backup)

volumes:
  mysql_data:   # Database files
  mysql_backup: # Backup files
  api_cache:    # Memoization cache
```

### Integration Points

1. **Backup Volume Access**
   - API container needs access to `mysql_backup` volume
   - Add volume mount to api service

2. **Migration at Startup**
   - No Docker changes needed
   - Migration runs in API startup before endpoints mount

3. **Health Checks**
   - Existing health checks sufficient
   - API: `curl http://localhost:7777/health/`
   - MySQL: `mysqladmin ping`

### Configuration Changes

Add backup volume to API container:

```yaml
# docker-compose.yml
services:
  api:
    volumes:
      - ./api/endpoints:/app/endpoints
      # ... existing volumes ...
      - mysql_backup:/backup:ro  # NEW: Read-only access to backups
```

### Security Considerations

- Backup volume mounted read-only in API (`:ro`)
- Manual backup creation writes via mysqldump from mysql container
- Download streams through API with Administrator role check
- No direct backup volume write access from API

---

## Suggested Build Order

Based on dependencies and risk, build in this order:

### Phase 1: Migration System (Foundation)

**Why first:** Required foundation for all other features. Database schema changes need a migration system.

**Components:**
1. `_schema_migrations` table (manual or bootstrap migration)
2. `migration-runner.R` module
3. Integration into `start_sysndd_api.R`
4. Test migrations for backup metadata table

**Dependencies:** None (uses existing db-helpers.R)

### Phase 2: Backup API Endpoints

**Why second:** Backend infrastructure before UI.

**Components:**
1. `backup_endpoints.R` file
2. `backup-service.R` (if needed)
3. Mount in `start_sysndd_api.R`
4. Docker volume mount for api container

**Dependencies:** Migration system (for backup_metadata table if tracking)

### Phase 3: Backup Admin UI

**Why third:** UI depends on API.

**Components:**
1. `ManageBackups.vue` view
2. Router entry in admin section
3. Reuse existing `useAsyncJob` composable

**Dependencies:** Backup API endpoints

### Phase 4: SMTP Enhancements (Optional)

**Why last:** Independent of other features, adds polish.

**Components:**
1. `notification-functions.R` (if needed)
2. Backup completion notifications
3. Migration failure alerts

**Dependencies:** Backup system (for notifications)

---

## Existing Patterns to Follow

### Endpoint File Pattern
- File: `api/endpoints/{name}_endpoints.R`
- Mount: `pr_mount("/api/{path}", pr("endpoints/{name}_endpoints.R"))`
- Auth: `require_role(req, res, "Administrator")`
- Tag: `@tag admin` or `@tag backup`

### Service Layer Pattern
- File: `api/services/{name}-service.R`
- Functions accept `pool` as parameter (DI)
- Business logic separate from HTTP handling

### Admin View Pattern
- File: `app/src/views/admin/{Name}.vue`
- Uses `GenericTable`, `TablePaginationControls`
- Auth via router guard (already configured)

### Async Job Pattern
- Backend: `create_job()` from job-manager.R
- Frontend: `useAsyncJob` composable
- Poll: `GET /api/jobs/{id}/status`

### Error Handling Pattern
- Backend: RFC 9457 Problem Details
- Use `httpproblems` package or custom errors from `core/errors.R`
- Frontend: Toast notifications via `useToast`

---

## Sources

All findings based on direct codebase analysis:
- `/home/bernt-popp/development/sysndd/api/start_sysndd_api.R` (API startup)
- `/home/bernt-popp/development/sysndd/api/functions/db-helpers.R` (DB layer)
- `/home/bernt-popp/development/sysndd/api/functions/job-manager.R` (Async jobs)
- `/home/bernt-popp/development/sysndd/api/endpoints/admin_endpoints.R` (Admin patterns)
- `/home/bernt-popp/development/sysndd/api/functions/helper-functions.R` (SMTP implementation)
- `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageOntology.vue` (Vue patterns)
- `/home/bernt-popp/development/sysndd/app/src/composables/useAsyncJob.ts` (Async composable)
- `/home/bernt-popp/development/sysndd/docker-compose.yml` (Container orchestration)
- `/home/bernt-popp/development/sysndd/api/config.yml` (Configuration structure)
