# Pitfalls Research: v9.0 Production Readiness

**Domain:** Adding production readiness features to existing R/Plumber application
**Researched:** 2026-01-29
**Confidence:** HIGH (verified with official docs and codebase analysis)

## Migration System Pitfalls

### CRITICAL: Non-Idempotent Migrations Causing Deployment Failures

**Risk:** Running a migration twice on the same database causes errors. Migration 002 (`002_add_genomic_annotations.sql`) currently uses plain `ALTER TABLE ... ADD COLUMN` without `IF NOT EXISTS` guards. Re-running this migration will fail with "Duplicate column name" errors.

**Warning Signs:**
- Deployment scripts fail on staging but passed in dev (fresh DB)
- Manual migration tracking has gaps (migration 002 vs 003 applied in different order)
- Docker container restarts trigger migration errors
- "Table 'X' already has a column named 'Y'" errors in logs

**Prevention:**
1. Make ALL existing migrations idempotent using stored procedure pattern (as in migration 003):
   ```sql
   DELIMITER //
   CREATE PROCEDURE IF NOT EXISTS migrate_example()
   BEGIN
       IF NOT EXISTS (
           SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'table_name'
             AND COLUMN_NAME = 'column_name'
       ) THEN
           ALTER TABLE table_name ADD COLUMN column_name TYPE NULL;
       END IF;
   END //
   DELIMITER ;
   CALL migrate_example();
   DROP PROCEDURE IF EXISTS migrate_example;
   ```
2. Add schema_version tracking table BEFORE implementing auto-run
3. Test migrations on database copy with pre-existing data

**Phase:** Phase 1 (Migration System Foundation) - Must fix migration 002 before auto-run implementation

**SysNDD-Specific Context:** Migration 002 already exists in `db/migrations/002_add_genomic_annotations.sql` and is documented as non-idempotent in `.planning/todos/pending/make-migration-002-idempotent.md`.

---

### CRITICAL: Table Locking During Migration on Production

**Risk:** ALTER TABLE statements on large tables can lock the table for extended periods, blocking all reads and writes. The `non_alt_loci_set` table (used by migrations 002 and 003) contains HGNC gene data and is queried frequently.

**Warning Signs:**
- API health checks timing out during deployment
- Connection pool exhaustion during migration window
- "Lock wait timeout exceeded" errors
- User-facing 502/504 errors during deployments

**Prevention:**
1. Use MySQL 8.0 Online DDL where possible:
   ```sql
   ALTER TABLE non_alt_loci_set ADD COLUMN new_col TYPE NULL,
   ALGORITHM=INPLACE, LOCK=NONE;
   ```
2. Schedule migrations during low-traffic periods (existing cron runs at 03:00)
3. For large tables, consider pt-online-schema-change or gh-ost tools
4. Add explicit timeout to migration runner (fail fast if lock can't be acquired)
5. Never add columns with DEFAULT values on large tables (forces table rewrite)

**Phase:** Phase 2 (Auto-Run Implementation) - Migration runner should detect table size and warn

**SysNDD-Specific Context:** MySQL 8.0.40 supports ALGORITHM=INPLACE for ADD COLUMN with NULL default. Verify with: `SHOW TABLE STATUS LIKE 'non_alt_loci_set';`

---

### HIGH: Migration Order Dependencies Not Enforced

**Risk:** Running migrations out of order (e.g., 003 before 002) can cause foreign key failures or missing column references. Current system has no enforcement.

**Warning Signs:**
- Manual application of migrations in wrong order
- New developer setup fails with "Unknown column" errors
- Production has different schema than staging

**Prevention:**
1. schema_version table enforces sequential application:
   ```sql
   CREATE TABLE IF NOT EXISTS schema_version (
     version INT PRIMARY KEY,
     filename VARCHAR(255) NOT NULL,
     applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
     checksum VARCHAR(64)
   );
   ```
2. Migration runner checks: `SELECT MAX(version) FROM schema_version`
3. Refuse to apply version N+2 if N+1 is missing
4. Store SHA256 checksum of migration file to detect tampering

**Phase:** Phase 1 (Migration System Foundation)

---

### HIGH: API Startup Blocked by Slow Migration

**Risk:** If migrations run at API startup (as planned), slow migrations will cause health check failures and container restarts in a loop.

**Warning Signs:**
- Docker health check timeout (currently 30s, start_period 60s)
- Kubernetes/Docker Compose restarts container before migration completes
- "OOM killed" if migration is memory-intensive

**Prevention:**
1. Separate migration from API startup - run as init container or pre-hook
2. If running at startup, extend start_period in docker-compose.yml:
   ```yaml
   healthcheck:
     start_period: 300s  # 5 minutes for migration
   ```
3. Add migration timeout with graceful failure
4. Log migration progress to separate file for debugging
5. Consider running migrations only in single-instance mode

**Phase:** Phase 2 (Auto-Run Implementation) - Add migration-specific health endpoint

---

### MEDIUM: Rollback Strategy Undefined

**Risk:** If a migration fails partway through, the database is in an indeterminate state. MySQL DDL is NOT transactional - ALTER TABLE commits immediately.

**Warning Signs:**
- Partial migration state (some columns added, others not)
- Manual intervention required to fix production
- No documented recovery procedure

**Prevention:**
1. Document manual rollback steps for each migration
2. Create down/rollback scripts alongside up scripts
3. For complex migrations, test on production clone first
4. Consider blue-green deployment for schema changes
5. Always take backup before migration (integrate with backup system)

**Phase:** Phase 1 - Document rollback for existing migrations (001-003)

---

## Backup Management Pitfalls

### CRITICAL: Restore Without Safety Rails Destroys Production Data

**Risk:** The restore operation (`mysql < backup.sql`) contains `DROP TABLE IF EXISTS` statements. Running on wrong database or accidentally triggering in production UI destroys all data.

**Warning Signs:**
- No confirmation dialog in admin UI
- Restore endpoint callable without explicit confirmation
- No automatic backup taken before restore
- No logging of who initiated restore

**Prevention:**
1. **Type-to-confirm pattern** (already used in SysNDD for bulk delete):
   ```javascript
   // User must type "RESTORE sysndd_db" to confirm
   if (confirmation !== `RESTORE ${databaseName}`) {
     throw new Error("Confirmation text does not match");
   }
   ```
2. **Auto-backup before restore**: Always create timestamped backup before restore
3. **Audit logging**: Log user_id, timestamp, backup file, and confirmation hash
4. **Two-phase restore**: Preview changes before applying (show table counts)
5. **Role restriction**: Only Administrator role can trigger restore

**Phase:** Phase 3 (Backup API + Admin UI)

**SysNDD-Specific Context:** Existing bulk delete uses type-to-confirm pattern (`user_bulk_delete` in user-service.R). Apply same pattern to restore.

---

### CRITICAL: mysqldump Locking Tables During Backup

**Risk:** Default mysqldump locks tables during export, causing API timeouts. The existing `fradelg/mysql-cron-backup` container may not use optimal flags.

**Warning Signs:**
- API slowdowns at 03:00 (cron backup time)
- Increased error rates during backup window
- Long-running queries timing out

**Prevention:**
1. Use `--single-transaction` for InnoDB tables (consistent snapshot without locks):
   ```bash
   mysqldump --single-transaction --routines --events --databases sysndd_db
   ```
2. Verify existing cron backup container uses appropriate flags
3. Add monitoring for backup duration
4. Consider mydumper for parallel exports on large databases

**Phase:** Phase 3 - Audit existing backup configuration

**SysNDD-Specific Context:** `fradelg/mysql-cron-backup` image default behavior should be verified. All SysNDD tables are InnoDB, so `--single-transaction` should work.

---

### HIGH: Backup Files Missing Critical Data

**Risk:** Default mysqldump excludes stored procedures, events, and triggers. The mysql system database (users/permissions) is also often forgotten.

**Warning Signs:**
- Restore completes but procedures missing
- User accounts don't exist after restore
- Scheduled events not running

**Prevention:**
1. Always use `--routines` and `--events` flags
2. Include mysql database: `--databases sysndd_db mysql`
3. Verify backup completeness with test restore
4. Document what IS and IS NOT included in backups
5. For full DR, also backup Traefik config and Docker volumes

**Phase:** Phase 3 - Verify backup scope

---

### HIGH: No Backup Integrity Verification

**Risk:** Backup file may be corrupted, truncated, or incomplete. Only discovered when restore is needed (worst possible time).

**Warning Signs:**
- Backup file sizes suddenly smaller
- `gzip: unexpected end of file` errors
- SQL syntax errors during restore

**Prevention:**
1. Verify backup after creation:
   ```bash
   gunzip -t backup.sql.gz || alert "Backup corrupted"
   ```
2. Compute and store checksum (SHA256)
3. Periodic test restore to separate database
4. Monitor backup file sizes over time (alert on significant decrease)
5. Keep N backups before rotating (currently MAX_BACKUPS: 60)

**Phase:** Phase 3 - Add verification to API

---

### MEDIUM: Backup List Endpoint Exposes Sensitive Information

**Risk:** Listing backup files may reveal database schema evolution, backup timing patterns, or other operational details to attackers.

**Warning Signs:**
- Backup filenames contain timestamps (reveals backup schedule)
- File sizes reveal database growth patterns
- No authentication on list endpoint

**Prevention:**
1. Restrict endpoint to Administrator role only
2. Return only filename and date, not full paths
3. Rate limit the endpoint
4. Audit log all backup list/download requests

**Phase:** Phase 3 - Add proper authorization

---

### MEDIUM: Point-in-Time Recovery Not Possible

**Risk:** With only daily full backups, data loss window is up to 24 hours. No ability to recover to a specific timestamp.

**Warning Signs:**
- Binary logging may not be enabled
- No documentation on PITR procedures
- "Can you restore to yesterday at 3pm?" - answer is no

**Prevention:**
1. Enable binary logging in MySQL:
   ```yaml
   # docker-compose.yml mysql command
   - --log-bin=mysql-bin
   - --binlog-format=ROW
   ```
2. Backup binlogs with full backups
3. Document PITR restoration procedure
4. Consider if v9 scope should include PITR (likely out of scope)

**Phase:** Future consideration - Document limitation for now

---

## SMTP Testing Pitfalls

### CRITICAL: Emails Sent to Real Users from Development Environment

**Risk:** Development/staging environment sends real emails to real user email addresses, causing confusion and potential security issues (passwords in plaintext email).

**Warning Signs:**
- Users complaining about unexpected password emails
- "Your account was approved" emails sent multiple times
- Production email credentials in dev config (already present in config.yml!)

**Prevention:**
1. **Environment-specific SMTP config**:
   - Development: Mailpit (localhost:1025, no auth)
   - Staging: Mailpit or catch-all address
   - Production: Real SMTP (smtp.strato.de)
2. **Never commit production SMTP credentials** - Current config.yml contains hardcoded passwords!
3. Use environment variables for SMTP host/credentials:
   ```yaml
   mail_noreply_host: ${SMTP_HOST:-localhost}
   mail_noreply_port: ${SMTP_PORT:-1025}
   ```
4. Add email domain allowlist for dev (only @sysndd.org or @example.com)

**Phase:** Phase 4 (SMTP Testing) - First action must be credential cleanup

**SysNDD-Specific Context:** CRITICAL FINDING - `api/config.yml` contains hardcoded SMTP password and other credentials. This must be remediated before any new work.

---

### HIGH: Mailpit Reverse DNS Lookup Timeout

**Risk:** Mailpit performs reverse DNS lookups by default. In Docker networks, this can cause 8-10 second delays per email operation.

**Warning Signs:**
- Email sending takes 8-10 seconds consistently
- Works fine locally, slow in Docker
- "Reverse DNS lookup" in debug logs

**Prevention:**
1. Disable reverse DNS in Mailpit:
   ```yaml
   mailpit:
     image: axllent/mailpit
     environment:
       MP_SMTP_DISABLE_RDNS: true
   ```
2. Or add proper DNS resolution for container network
3. Test email sending timing in Docker environment specifically

**Phase:** Phase 4 - Configure Mailpit correctly from start

---

### HIGH: SMTP Credential Management Insecure

**Risk:** SMTP credentials stored in multiple places (config.yml, environment variables, Docker secrets) with inconsistent handling.

**Warning Signs:**
- Password in config.yml committed to git (CURRENT STATE!)
- Multiple .env files with different credentials
- Credentials visible in Docker inspect

**Prevention:**
1. **Immediate**: Remove credentials from config.yml, use environment variables only
2. Move to Docker secrets for production:
   ```yaml
   secrets:
     smtp_password:
       external: true
   ```
3. Use `creds_envvar()` pattern consistently (already implemented in `send_noreply_email`)
4. Add .gitignore entries for any credential files
5. Rotate compromised credentials

**Phase:** Phase 4 - Credential cleanup is prerequisite

---

### MEDIUM: Email Delivery Failures Silent

**Risk:** Current `send_noreply_email` function may not handle SMTP failures gracefully. User gets approved but never receives password email.

**Warning Signs:**
- User can't log in after approval (password never received)
- No error logs when email fails
- `smtp_send` errors swallowed

**Prevention:**
1. Add explicit error handling:
   ```r
   tryCatch({
     smtp_send(...)
     logger::log_info("Email sent", recipient = email_recipient)
   }, error = function(e) {
     logger::log_error("Email failed", recipient = email_recipient, error = e$message)
     # Still complete user approval but flag for follow-up
   })
   ```
2. Add email delivery status to user approval response
3. Consider retry mechanism for transient failures
4. Add admin notification for failed emails

**Phase:** Phase 4 - Add error handling to email function

**SysNDD-Specific Context:** Current implementation in `api/functions/helper-functions.R:190-220` uses `compose_email()` + `smtp_send()` without explicit error handling.

---

### MEDIUM: E2E Email Testing Incomplete

**Risk:** Only testing that emails are sent, not that they are received or have correct content.

**Warning Signs:**
- Emails sent but formatted incorrectly
- Links in emails broken
- HTML rendering issues in email clients

**Prevention:**
1. Use Mailpit API to verify email content:
   ```r
   # Mailpit API endpoint
   GET http://localhost:8025/api/v1/messages
   ```
2. Test password reset link is clickable and valid
3. Test email renders correctly (plain text + HTML)
4. Verify all user flows: registration, approval, password reset

**Phase:** Phase 4 - Full E2E testing

---

## Production Docker Pitfalls

### CRITICAL: Connection Pool Exhaustion with Multiple Workers

**Risk:** With 4 API workers (planned), each worker creates its own connection pool. Total connections = 4 workers x pool_size. Default pool size may exceed MySQL max_connections.

**Warning Signs:**
- "Too many connections" errors under load
- Intermittent 500 errors that resolve on retry
- Connections accumulating over time (check with `SHOW PROCESSLIST`)

**Prevention:**
1. Calculate total connections: `workers * pool_size < mysql_max_connections - 10`
2. Configure pool explicitly in start_sysndd_api.R:
   ```r
   pool <<- dbPool(
     ...,
     minSize = 1,      # Minimum connections per worker
     maxSize = 10,     # Maximum connections per worker
     idleTimeout = 60  # Return unused connections
   )
   ```
3. For 4 workers with maxSize=10: max 40 connections needed
4. MySQL default max_connections is 151, so this should be safe
5. Monitor with: `SHOW STATUS LIKE 'Threads_connected';`

**Phase:** Phase 5 (Production Docker Validation)

**SysNDD-Specific Context:** Current pool creation in `start_sysndd_api.R:179-187` uses defaults. With 4 workers, explicit sizing is needed.

---

### CRITICAL: Pool Cannot Be Shared Across Workers

**Risk:** The R `pool` package explicitly states: connection pools created in parent process cannot be used in forked worker processes. Each worker must create its own pool.

**Warning Signs:**
- Random segfaults in worker processes
- "Connection not open" errors
- Works with 1 worker, fails with multiple

**Prevention:**
1. Ensure pool is created AFTER worker fork, not before
2. For Plumber with pm2 or similar process managers, pool must be in each worker
3. Current mirai daemon configuration already handles this correctly (daemons create fresh connections via everywhere block)
4. For multi-worker Plumber, use `pr_run()` with `num_procs` and ensure pool creation is per-process

**Phase:** Phase 5 - Verify pool initialization timing

**SysNDD-Specific Context:** Current setup creates pool in `start_sysndd_api.R` before `pr_run()`. With single worker this works. With `scale: 4`, each container gets its own pool (correct). But if using pm2 inside container, be careful.

---

### HIGH: mirai Daemons Not Scaled with Workers

**Risk:** Current config starts 2 mirai daemons per API container. With 4 API workers, that's still 2 daemons total per container, not 2 per worker.

**Warning Signs:**
- Async job queue backs up under load
- Jobs taking longer than expected
- CPU not fully utilized

**Prevention:**
1. Review if 2 daemons is sufficient for 4-worker setup
2. Consider scaling daemons with worker count:
   ```r
   daemons(
     n = as.integer(Sys.getenv("MIRAI_WORKERS", 2)),
     ...
   )
   ```
3. Monitor job queue depth and completion times
4. Document expected throughput

**Phase:** Phase 5 - Load testing will reveal if sufficient

**SysNDD-Specific Context:** mirai daemons initialized at `start_sysndd_api.R:249-253` with n=2. Each API container is independent, so 4 containers = 8 total daemons.

---

### HIGH: Health Check Not Distinguishing Ready vs. Live

**Risk:** Current health check (`/health/`) only checks if API is responding. Doesn't check if database is connected or migrations are complete.

**Warning Signs:**
- Load balancer sends traffic before API is fully initialized
- Health check passes but API returns 500 on DB queries
- Startup race conditions

**Prevention:**
1. Add readiness vs. liveness probes:
   ```yaml
   # Liveness: is the process running?
   livenessProbe:
     httpGet:
       path: /health/
       port: 7777

   # Readiness: can it serve traffic?
   readinessProbe:
     httpGet:
       path: /health/ready
       port: 7777
   ```
2. Readiness check should verify:
   - Database connection works
   - Migrations are complete (schema_version matches expected)
   - Required services available
3. Only route traffic after readiness passes

**Phase:** Phase 5 - Add /health/ready endpoint

---

### MEDIUM: Log Aggregation Across Workers

**Risk:** With multiple API workers, logs are scattered across containers. Current logging writes to per-container temp files and database.

**Warning Signs:**
- Can't correlate requests across workers
- Missing logs when container restarts
- Database log table grows unbounded

**Prevention:**
1. Add worker identifier to log entries
2. Consider centralized logging (ELK, Loki)
3. Ensure log rotation in database (purge old entries)
4. For debugging, add request ID header

**Phase:** Phase 5 - Add worker ID to logs

---

### MEDIUM: Resource Limits Not Tested with Multiple Workers

**Risk:** Current memory limit (4608M) is for single worker. With 4 workers via docker-compose scale, each gets 4608M which may be excessive or insufficient.

**Warning Signs:**
- OOM kills during clustering jobs
- Wasted memory on idle workers
- Swap thrashing

**Prevention:**
1. Load test with realistic workload
2. Adjust resource limits per worker:
   ```yaml
   api:
     deploy:
       replicas: 4
       resources:
         limits:
           memory: 2048M  # Per worker
   ```
3. Monitor actual memory usage under load
4. Consider separate resource profile for worker containers

**Phase:** Phase 5 - Load testing

---

## Cross-Cutting Pitfalls

### CRITICAL: Credential Exposure in Version Control

**Risk:** Multiple credentials are currently hardcoded in `api/config.yml`:
- SMTP password: `mail_noreply_password`
- Database password: `password`
- Archive access keys: `archive_access_key`, `archive_secret_key`
- OMIM token: `omim_token`
- JWT secret: `secret`

**Warning Signs:**
- config.yml in git history
- Same credentials in dev and production
- No credential rotation policy

**Prevention:**
1. **Immediate**: Remove ALL credentials from config.yml
2. Use environment variables for all secrets
3. Add config.yml to .gitignore (keep config.yml.example)
4. Rotate all exposed credentials
5. Use Docker secrets or Vault for production

**Phase:** Phase 1 - MUST be done first, blocks all other work

---

### HIGH: No Feature Flags for Gradual Rollout

**Risk:** New features (migration auto-run, backup API) go live all at once. If issues arise, entire deployment must be rolled back.

**Warning Signs:**
- All-or-nothing deployments
- Can't disable problematic feature without redeploying
- Testing in production is all-or-nothing

**Prevention:**
1. Add environment variable feature flags:
   ```r
   if (Sys.getenv("ENABLE_AUTO_MIGRATIONS", "false") == "true") {
     run_migrations()
   }
   ```
2. Start with features disabled by default
3. Enable per-environment (dev -> staging -> production)
4. Add admin UI toggle for runtime flags (future)

**Phase:** All phases - Design with feature flags from start

---

### MEDIUM: Testing Environment Parity

**Risk:** Dev environment differs from production (single worker, Mailpit vs real SMTP, no real data volume). Tests pass in dev but fail in production.

**Warning Signs:**
- "Works on my machine" syndrome
- First production deployment has issues
- Can't reproduce production bugs locally

**Prevention:**
1. Create staging environment matching production config
2. Test with production-like data volumes
3. Document environment differences
4. Add integration tests that run against Docker Compose setup

**Phase:** Phase 5 - Staging validation

---

### MEDIUM: Deployment Ordering Dependencies

**Risk:** Features have dependencies (migration must complete before API starts, backup must exist before restore enabled). Incorrect deployment order causes failures.

**Warning Signs:**
- Deployment scripts assume order but don't enforce
- Partial deployments leave system in bad state
- Manual steps required between deployments

**Prevention:**
1. Document deployment order in runbook
2. Use Docker Compose depends_on with healthcheck condition:
   ```yaml
   api:
     depends_on:
       mysql:
         condition: service_healthy
       migrations:
         condition: service_completed_successfully
   ```
3. Add pre-flight checks to deployment scripts

**Phase:** All phases - Design for ordered deployment

---

## Phase Mapping Summary

| Pitfall | Severity | Phase |
|---------|----------|-------|
| Credentials in version control | CRITICAL | Phase 1 (prerequisite) |
| Non-idempotent migrations | CRITICAL | Phase 1 |
| Table locking during migration | CRITICAL | Phase 2 |
| API startup blocked by migration | HIGH | Phase 2 |
| Restore without safety rails | CRITICAL | Phase 3 |
| mysqldump locking tables | CRITICAL | Phase 3 |
| Emails to real users from dev | CRITICAL | Phase 4 |
| Connection pool exhaustion | CRITICAL | Phase 5 |
| Pool sharing across workers | CRITICAL | Phase 5 |

---

## Sources

### Official Documentation
- [R pool package - Posit Solutions](https://solutions.posit.co/connections/db/r-packages/pool/)
- [Plumber Hosting - rplumber.io](https://www.rplumber.io/articles/hosting.html)
- [Plumber Execution Model](https://www.rplumber.io/articles/execution-model.html)
- [MySQL Online DDL Reference](https://dev.mysql.com/doc/refman/8.0/en/innodb-online-ddl.html)
- [mysqldump Reference](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html)
- [Mailpit Documentation](https://mailpit.axllent.org/)

### Best Practice Articles
- [Database Migration Tips - Jonathan Hall](https://jhall.io/archive/2022/05/12/database-migration-tips-tricks/)
- [Idempotent DDL Scripts - DZone](https://dzone.com/articles/trouble-free-database-migration-idempotence-and-co)
- [Creating Idempotent DDL Scripts - Redgate](https://www.red-gate.com/hub/product-learning/flyway/creating-idempotent-ddl-scripts-for-database-migrations)
- [MySQL Backup Best Practices - Percona](https://www.percona.com/blog/mysql-backup-and-recovery-best-practices/)
- [MySQL Backup Guide 2026 - DEV.to](https://dev.to/piteradyson/mysql-backup-and-restore-complete-guide-to-mysql-database-backup-strategies-in-2026-4cdk)
- [Connection Pool Exhaustion - HowTech](https://howtech.substack.com/p/connection-pool-exhaustion-the-silent)
- [MySQL Locks in Production - Simon Ninon](https://simon-ninon.medium.com/dont-break-production-learn-about-mysql-locks-297671ec8e73)

### Codebase Analysis
- `/home/bernt-popp/development/sysndd/api/config.yml` - Credential exposure verified
- `/home/bernt-popp/development/sysndd/db/migrations/` - Migration 002 non-idempotent verified
- `/home/bernt-popp/development/sysndd/api/start_sysndd_api.R` - Pool configuration analyzed
- `/home/bernt-popp/development/sysndd/docker-compose.yml` - Backup container configuration verified
