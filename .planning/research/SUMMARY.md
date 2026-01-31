# Project Research Summary

**Project:** SysNDD v9.0 Production Readiness
**Domain:** Infrastructure - migrations, backups, SMTP testing, Docker validation
**Researched:** 2026-01-29
**Confidence:** HIGH

## Executive Summary

SysNDD v9.0 Production Readiness focuses on four infrastructure areas: database migrations, backup management, SMTP email testing, and production Docker validation. Research reveals that **no new R packages are required** - all features can be implemented using existing stack components (DBI, RMariaDB, pool, blastula, fs) plus one Docker service addition (Mailpit for local email testing). The existing codebase provides strong foundations with established patterns for admin endpoints, async job handling, and health checks.

**However, a critical security blocker was discovered:** `api/config.yml` contains hardcoded credentials (SMTP password, database password, OMIM tokens, archive access keys, JWT secret) committed to version control. This must be remediated before any new production features are implemented. The credentials have been exposed in git history and should be rotated.

The recommended approach is to: (1) remediate credential exposure as Phase 0, (2) implement migration system as foundation, (3) add backup management UI leveraging existing backup infrastructure, (4) add SMTP testing with Mailpit, and (5) validate production Docker configuration with multi-worker setup. Each phase builds on existing patterns with minimal new complexity.

## Critical Blocker

### Credential Exposure in Version Control

**Severity:** CRITICAL - Must be addressed before any other work proceeds

**Finding:** `api/config.yml` contains multiple hardcoded credentials:
- `mail_noreply_password` (SMTP password)
- `password` (database password)
- `archive_access_key`, `archive_secret_key` (archive credentials)
- `omim_token` (OMIM API token)
- `secret` (JWT signing secret)

**Required Actions:**
1. Remove ALL credentials from `config.yml` immediately
2. Convert all secrets to environment variable references
3. Create `config.yml.example` as template without real values
4. Add `config.yml` to `.gitignore`
5. Rotate all compromised credentials (they exist in git history)
6. Use Docker secrets or environment variables for production

**Impact:** Blocks all phases - cannot deploy new production features until credentials are secured.

## Key Findings

### Recommended Stack

No new R packages required. The four production features leverage existing stack components:

**Core technologies already in place:**
- **DBI + RMariaDB + pool:** Database connectivity and connection pooling - used for migration runner
- **blastula:** Email composition and SMTP sending - already implemented in `send_noreply_email()`
- **fs:** File system operations - used for listing/managing backup files
- **logger:** Structured logging - used throughout codebase
- **mirai:** Async job execution - used for long-running backup operations

**New Docker service:**
- **Mailpit:** Local SMTP testing (replaces abandoned MailHog) - captures emails in development without sending to real recipients

**Explicitly NOT adding:**
- Flyway/Liquibase (Java dependencies, overkill for 3 migrations)
- External backup tools (fradelg/mysql-cron-backup already running)
- MailHog (abandoned since 2020)
- Kubernetes (Docker Compose sufficient)

### Expected Features

**Must have (table stakes):**
- Sequential migration execution with state tracking table
- Idempotent migration runner (skips applied, runs pending)
- Backup listing with metadata (filename, date, size)
- Backup download capability for disaster recovery
- SMTP connection test endpoint
- Pre-deployment validation script

**Should have (differentiators):**
- Admin UI migration status panel
- Manual backup trigger ("Backup Now" button)
- Admin UI SMTP test panel
- Production readiness checklist endpoint

**Defer (v2+):**
- Auto-generated migrations from schema diff
- One-click restore from UI (too dangerous)
- Email bounce handling
- Incremental/differential backups
- Point-in-time recovery

### Architecture Approach

SysNDD uses a layered architecture with clear integration points for each feature. Migration system integrates at API startup (between pool creation and endpoint mounting). Backup management adds new endpoint file following existing admin patterns. SMTP testing requires only configuration changes (Mailpit in docker-compose.override.yml). Production Docker validation extends existing health check infrastructure.

**Major components:**
1. **Migration Runner** (`api/functions/migration-runner.R`) - Executes pending migrations at startup, tracks state in `_schema_migrations` table
2. **Backup Endpoints** (`api/endpoints/backup_endpoints.R`) - List, download, trigger, delete backups via REST API
3. **Backup Admin UI** (`app/src/views/admin/ManageBackups.vue`) - Following ManageOntology.vue pattern with async job polling
4. **Enhanced Health Check** (`/health/ready`) - Validates database, workers, and migrations before accepting traffic

### Critical Pitfalls

1. **Credential Exposure in Version Control** - Remove all credentials from config.yml, use environment variables, rotate compromised secrets
2. **Non-Idempotent Migrations** - Migration 002 uses plain `ALTER TABLE ADD COLUMN` without guards; must use stored procedure pattern with `IF NOT EXISTS` checks
3. **Table Locking During Migration** - Use MySQL 8.0 Online DDL (`ALGORITHM=INPLACE, LOCK=NONE`) and schedule during low-traffic periods
4. **Restore Without Safety Rails** - Implement type-to-confirm pattern (user types "RESTORE sysndd_db"), auto-backup before restore, audit logging
5. **Emails to Real Users from Dev** - Use Mailpit in development, environment-specific SMTP config, domain allowlist
6. **Connection Pool Exhaustion** - With 4 workers, configure explicit pool sizes (`maxSize = 10` per worker, total < MySQL max_connections)

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 0: Credential Remediation (PREREQUISITE)
**Rationale:** Security blocker - cannot deploy production features with credentials in version control
**Delivers:** Secure configuration with all secrets in environment variables
**Addresses:** Critical pitfall - credential exposure
**Avoids:** Deploying production features with compromised credentials

### Phase 1: Migration System Foundation
**Rationale:** Required foundation - all schema changes need migration system before deployment
**Delivers:** `_schema_migrations` table, migration-runner.R, startup integration
**Addresses:** Sequential execution, state tracking, pre-flight check (table stakes)
**Avoids:** Non-idempotent migrations causing deployment failures

### Phase 2: Migration Auto-Run and Admin UI
**Rationale:** Builds on foundation, makes migrations operational
**Delivers:** Auto-run at startup with extended health check timeout, admin status panel
**Addresses:** Admin UI migration status, pre-flight check (differentiators)
**Avoids:** API startup blocked by slow migration, table locking during migration

### Phase 3: Backup API and Admin UI
**Rationale:** Backend before frontend, uses existing backup infrastructure
**Delivers:** Backup endpoints (list, download, trigger, delete), ManageBackups.vue
**Addresses:** Backup listing, download, manual trigger (table stakes + differentiators)
**Avoids:** Restore without safety rails, mysqldump locking

### Phase 4: SMTP Testing Infrastructure
**Rationale:** Independent feature, adds development safety
**Delivers:** Mailpit in docker-compose.override.yml, SMTP test endpoint
**Addresses:** SMTP connection test, test email send (table stakes)
**Avoids:** Emails to real users from dev, credential management issues

### Phase 5: Production Docker Validation
**Rationale:** Validates entire system, requires other phases complete
**Delivers:** Enhanced /health/ready endpoint, multi-worker validation, load testing
**Addresses:** Pre-deployment validation, production checklist (table stakes)
**Avoids:** Connection pool exhaustion, pool sharing across workers

### Phase Ordering Rationale

- **Phase 0 first:** Security blocker - no new features until credentials secured
- **Phase 1 before 2:** Migration foundation needed before auto-run
- **Phase 3 after 2:** Backup metadata table may use migration system
- **Phase 4 independent:** Can proceed in parallel with Phase 3 if resources available
- **Phase 5 last:** Integration testing requires other features complete

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Table locking behavior needs MySQL 8.0 Online DDL verification with actual table sizes
- **Phase 5:** Multi-worker connection pooling needs load testing to determine optimal settings

Phases with standard patterns (skip research-phase):
- **Phase 0:** Standard credential remediation, well-documented
- **Phase 1:** Custom migration runner follows existing db-helpers.R patterns
- **Phase 3:** Follows existing admin endpoint and Vue patterns exactly
- **Phase 4:** Mailpit has excellent documentation, drop-in replacement

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new packages - all existing components, verified in renv.lock |
| Features | MEDIUM | Web research patterns verified against existing codebase |
| Architecture | HIGH | Based on direct codebase analysis of existing patterns |
| Pitfalls | HIGH | Verified with official docs (pool, Plumber, MySQL) and codebase analysis |

**Overall confidence:** HIGH

### Gaps to Address

- **MySQL Online DDL behavior:** Need to verify `ALGORITHM=INPLACE, LOCK=NONE` works with actual migration SQL for tables with current data volume
- **Connection pool sizing:** Load testing required to determine optimal pool size for 4-worker setup
- **Backup container flags:** Need to verify fradelg/mysql-cron-backup uses `--single-transaction` flag
- **Point-in-time recovery:** Documented as out of scope, but should determine if binary logging should be enabled for future capability

## Sources

### Primary (HIGH confidence)
- [R pool package documentation](https://solutions.posit.co/connections/db/r-packages/pool/) - connection pooling behavior
- [Plumber Execution Model](https://www.rplumber.io/articles/execution-model.html) - multi-worker patterns
- [MySQL Online DDL Reference](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl.html) - ALTER TABLE locking
- [Mailpit Documentation](https://mailpit.axllent.org/) - SMTP testing configuration
- [fradelg/docker-mysql-cron-backup](https://github.com/fradelg/docker-mysql-cron-backup) - existing backup container

### Secondary (MEDIUM confidence)
- [Database Migration Best Practices](https://www.bacancytechnology.com/blog/database-migration-best-practices) - migration patterns
- [Docker Compose Health Checks](https://last9.io/blog/docker-compose-health-checks/) - health check configuration
- [Three Useful Endpoints for Plumber APIs](https://unconj.ca/blog/three-useful-endpoints-for-any-plumber-api.html) - health endpoint patterns

### Codebase Analysis (HIGH confidence)
- `/home/bernt-popp/development/sysndd/api/config.yml` - Credential exposure verified
- `/home/bernt-popp/development/sysndd/db/migrations/` - Migration 002 non-idempotent verified
- `/home/bernt-popp/development/sysndd/api/start_sysndd_api.R` - Pool and startup patterns
- `/home/bernt-popp/development/sysndd/api/functions/db-helpers.R` - Database layer patterns
- `/home/bernt-popp/development/sysndd/api/endpoints/admin_endpoints.R` - Admin endpoint patterns
- `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageOntology.vue` - Admin UI patterns
- `/home/bernt-popp/development/sysndd/docker-compose.yml` - Container orchestration

---

**Research completed:** 2026-01-29
**Ready for roadmap:** Yes (after credential remediation decision)
