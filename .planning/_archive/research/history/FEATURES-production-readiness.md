# Features Research: v9.0 Production Readiness

**Domain:** Production deployment readiness for clinical genetics database (SysNDD)
**Researched:** 2026-01-29
**Confidence:** MEDIUM (based on web research + analysis of existing codebase)

## Executive Summary

This research identifies expected features for four production readiness areas: Migration Systems, Backup Management, User Lifecycle & SMTP, and Production Docker Configuration. The existing SysNDD codebase already has strong foundations (health checks, async jobs, admin endpoints) that these features can extend.

**Key Context from Existing System:**
- Already has: fradelg/mysql-cron-backup container (daily 3am dumps, 60 retention)
- Already has: health endpoints with performance metrics
- Already has: SMTP configured in config.yml (smtp.strato.de:587)
- Already has: admin panel with user management, logs, statistics
- Missing: Migration runner, backup UI, SMTP testing, production validation

---

## Migration System Features

### Table Stakes

| Feature | Complexity | Why Essential | Dependencies |
|---------|------------|---------------|--------------|
| **Sequential migration execution** | Medium | Must apply migrations in correct order (001, 002, 003...) when deploying to existing database. Without this, schema updates cannot be reliably deployed. | None |
| **Migration state tracking table** | Low | Must track which migrations have been applied (like Flyway's `flyway_schema_history`). Prevents re-running completed migrations. | Database access |
| **Idempotent migration runner** | Medium | Skips already-applied migrations, runs pending ones. Core requirement for "deploy updated Docker with old database." | State tracking table |
| **Clear migration ordering** | Low | Filename convention (e.g., `V001__description.sql`) enforces deterministic order. Prevents conflicts with parallel development. | None |
| **Atomic transactions per migration** | Medium | Each migration runs in transaction; rolls back on failure. Prevents half-applied states. | Database supports transactions |

### Differentiators

| Feature | Complexity | Value Added | Dependencies |
|---------|------------|-------------|--------------|
| **Admin UI migration status panel** | Medium | Shows applied/pending migrations in admin panel. Reduces deployment anxiety by making state visible. | Vue admin, API endpoint |
| **Pre-flight migration check** | Low | Warns during container startup if pending migrations exist. Could log warning or block API start until migrations run. | Migration state tracking |
| **Dry-run mode** | Medium | Shows what migrations WOULD run without executing. Useful for production deployment planning. | Migration runner |
| **Migration history API endpoint** | Low | GET `/api/admin/migrations` returns migration status. Enables programmatic monitoring. | Migration state tracking |
| **Timestamp-based ordering alternative** | Low | Alternative to sequential numbers for larger teams. Format: `V20260129_120000__description.sql`. | None |

### Anti-Features

| Anti-Feature | Why NOT to Build |
|--------------|------------------|
| **Auto-generated migrations from schema diff** | Complex, error-prone for production. Manual migrations are more predictable for a small team. |
| **Database-agnostic migration format (XML/YAML)** | SysNDD is MySQL-only. Adding abstraction (like Liquibase's changelog format) adds complexity without benefit. |
| **Interactive migration rollback UI** | Production rollbacks are dangerous and rare. Manual DBA intervention is safer than a UI button. |
| **Automatic migration on container start** | Too risky for production. Migrations should be explicitly triggered, not auto-run on every restart. |
| **Cross-database synchronization** | Only one production database exists. No need for multi-target deployment features. |

---

## Backup Management Features

### Table Stakes

| Feature | Complexity | Why Essential | Dependencies |
|---------|------------|---------------|--------------|
| **List available backups** | Low | Admin must see what backups exist (filename, date, size). Foundation for any backup management. | Read access to backup volume |
| **Download individual backup** | Medium | Admin must be able to download backup files for off-site storage or disaster recovery. | Secure file serving, auth |
| **View backup status** | Low | Show when last backup ran, if it succeeded, next scheduled time. Removes guesswork from "is backup working?" | Parse cron logs or status file |
| **Retention policy display** | Low | Show current retention settings (60 days). Admin knows how far back they can restore. | Read config |

### Differentiators

| Feature | Complexity | Value Added | Dependencies |
|---------|------------|-------------|--------------|
| **Manual backup trigger** | Medium | "Backup Now" button for pre-deployment safety. Admin can create point-in-time backup before risky changes. | API to cron container |
| **Backup integrity verification** | Medium | Validate backup files (check gzip integrity, SQL syntax header). Catch corrupted backups before needing them. | File access, validation logic |
| **Restore dry-run preview** | High | Show what a restore would do (tables affected, row counts). Builds confidence before restore. | Parse SQL dump, analyze |
| **Email notifications on failure** | Medium | Alert admin if backup job fails. Proactive monitoring vs. discovering failures during crisis. | SMTP integration |
| **Backup size trending chart** | Low | Show backup sizes over time. Helps predict storage needs, detect anomalies. | Store/read historical sizes |

### Anti-Features

| Anti-Feature | Why NOT to Build |
|--------------|------------------|
| **One-click restore from UI** | Production database restore is too dangerous for a UI button. Require manual DBA process with verification. |
| **Automated restore testing** | Complex to implement safely. Manual verification is more appropriate for clinical data. |
| **Backup to multiple cloud providers** | Single backup location is sufficient. Multi-cloud adds complexity without clear benefit for this scale. |
| **Incremental/differential backups** | Current daily full backups are appropriate for database size. Incremental adds complexity. |
| **Real-time backup streaming** | Overkill for daily backup needs. Point-in-time recovery not required for this use case. |

---

## User Lifecycle & SMTP Features

### Table Stakes

| Feature | Complexity | Why Essential | Dependencies |
|---------|------------|---------------|--------------|
| **SMTP connection test endpoint** | Low | Verify SMTP credentials work before relying on email. Catches config errors early. | SMTP config in config.yml |
| **Test email send** | Low | Send test email to specified address. Proves entire email pipeline works end-to-end. | Working SMTP connection |
| **SMTP status in health check** | Medium | Include SMTP reachability in health/status API. Proactive monitoring of email capability. | Health endpoint extension |
| **Email template preview** | Low | View rendered email templates without sending. Verify formatting before production use. | blastula templates |

### Differentiators

| Feature | Complexity | Value Added | Dependencies |
|---------|------------|-------------|--------------|
| **Admin UI SMTP test panel** | Medium | Button to test SMTP from admin panel with result display. Non-technical admins can verify email works. | Vue admin, API endpoint |
| **Email delivery log** | Medium | Track sent emails (recipient, timestamp, type, status). Audit trail for "did user receive email?" questions. | New database table |
| **Password reset flow test** | Medium | Simulate password reset flow in test mode (sends to admin instead of user). Validates critical user journey. | Auth endpoints, test mode flag |
| **Signup notification to admin** | Low | Email admin when new user registers (already exists). Verify this works and make configurable. | Existing signup flow |
| **DNS record validation** | Low | Check SPF/DKIM/DMARC records for email domain. Helps diagnose deliverability issues. | DNS lookup |

### Anti-Features

| Anti-Feature | Why NOT to Build |
|--------------|------------------|
| **Multi-provider email failover** | Single SMTP provider is sufficient. Failover adds complexity for minimal benefit. |
| **Email bounce handling** | Requires webhook setup with email provider. Out of scope for initial production readiness. |
| **User-facing email preferences UI** | Users don't need to configure email preferences for this application's transactional emails. |
| **Email queue with retry logic** | Synchronous email send is acceptable. Queue adds infrastructure complexity. |
| **Rich HTML email editor** | Email templates are developer-managed. No need for admin-editable templates. |

---

## Production Docker Features

### Table Stakes

| Feature | Complexity | Why Essential | Dependencies |
|---------|------------|---------------|--------------|
| **Pre-deployment validation script** | Medium | Check database connectivity, required tables exist, config valid. Fail fast if environment is misconfigured. | Database access, config parsing |
| **Migration pending check on startup** | Low | Log warning or fail if pending migrations detected. Prevents running API against incompatible schema. | Migration state tracking |
| **Environment variable validation** | Low | Verify required env vars are set (MYSQL_PASSWORD, SMTP_PASSWORD, etc.). Clear error messages for missing config. | Startup script |
| **Database version compatibility check** | Low | Verify MySQL version is supported. Prevents cryptic errors from version mismatches. | Database query |

### Differentiators

| Feature | Complexity | Value Added | Dependencies |
|---------|------------|-------------|--------------|
| **Production checklist endpoint** | Medium | GET `/api/admin/production-checklist` returns validation status of all production requirements. Deployment verification. | All validation checks |
| **Container resource monitoring** | Low | Memory/CPU usage in health endpoint. Helps diagnose performance issues. | System metrics access |
| **Startup timing metrics** | Low | Log how long each startup phase takes. Identifies slow initialization steps. | Logging |
| **SSL certificate validation** | Low | Check that HTTPS certificates are valid and not expiring soon. Proactive certificate management. | Certificate access |
| **External dependency health** | Medium | Check connectivity to external APIs (OMIM, HGNC) during health check. Identifies external service issues. | Network access |

### Anti-Features

| Anti-Feature | Why NOT to Build |
|--------------|------------------|
| **Auto-scaling configuration** | Single VPS deployment. Auto-scaling is infrastructure-level, not application concern. |
| **Blue-green deployment automation** | Manual deployment is acceptable for release frequency. Adds complexity without clear benefit. |
| **Canary deployment support** | Single instance deployment. Canary requires multiple instances and traffic splitting. |
| **Container orchestration integration (K8s)** | Target is single VPS with Docker Compose. Kubernetes adds massive complexity. |
| **Distributed tracing** | Single application instance doesn't benefit from distributed tracing. Simple logging is sufficient. |

---

## Feature Dependencies

```
Migration System:
  State tracking table <-- Migration runner <-- Admin UI panel
                                            <-- Pre-flight check
                                            <-- History API endpoint

Backup Management:
  Backup volume access <-- List backups <-- Download backup
                                        <-- Status display
  Cron container access <-- Manual trigger
  SMTP integration <-- Failure notifications

SMTP/User Lifecycle:
  SMTP config <-- Connection test <-- Test email send
                                  <-- Admin UI panel
  Auth endpoints <-- Password reset test

Production Docker:
  Migration state <-- Pending check on startup
  Database access <-- Pre-deployment validation <-- Checklist endpoint
  All checks <-- Production checklist endpoint
```

### Recommended Implementation Order

1. **Migration System** (Phase 1)
   - State tracking table
   - Migration runner
   - Pre-flight check
   - Rationale: Must be first to ensure schema changes can be deployed safely

2. **Backup Management UI** (Phase 2)
   - List/download backups
   - Status display
   - Manual trigger
   - Rationale: Backup system exists; UI provides visibility and control

3. **SMTP Testing** (Phase 3)
   - Connection test
   - Test email send
   - Admin UI panel
   - Rationale: Email system exists; testing ensures it works before user-facing issues

4. **Production Validation** (Phase 4)
   - Pre-deployment validation
   - Production checklist endpoint
   - Rationale: Validates all previous work and provides deployment confidence

---

## MVP Recommendation

For minimum viable production readiness:

**Must Have (Week 1-2):**
1. Migration state tracking table
2. Migration runner that can apply pending migrations
3. Pre-flight check logging pending migrations on startup
4. Backup list endpoint (see what backups exist)

**Should Have (Week 3-4):**
5. SMTP connection test endpoint
6. Pre-deployment validation script
7. Backup download capability
8. Admin UI showing migration status

**Nice to Have (Week 5+):**
9. Manual backup trigger
10. Production checklist endpoint
11. Full admin UI for backup/SMTP management

---

## Complexity Estimates

| Feature Area | Low | Medium | High | Total |
|--------------|-----|--------|------|-------|
| Migration System | 3 | 4 | 0 | 7 |
| Backup Management | 4 | 3 | 1 | 8 |
| SMTP/User Lifecycle | 4 | 3 | 0 | 7 |
| Production Docker | 4 | 2 | 0 | 6 |
| **Total** | **15** | **12** | **1** | **28** |

**Complexity Definitions:**
- Low: 1-2 hours implementation, straightforward
- Medium: 4-8 hours, some design decisions required
- High: 1-2 days, significant complexity or research needed

---

## Sources

### Migration Systems
- [Data Migration Best Practices 2026](https://medium.com/@kanerika/data-migration-best-practices-your-ultimate-guide-for-2026-7cbd5594d92e)
- [Flyway vs Liquibase Comparison 2025](https://www.bytebase.com/blog/flyway-vs-liquibase/)
- [Top Database Schema Migration Tools 2025](https://www.bytebase.com/blog/top-database-schema-change-tool-evolution/)
- [Database Migration Best Practices](https://www.bacancytechnology.com/blog/database-migration-best-practices)
- [Flyway vs Liquibase Developer Guide](https://sergiolema.dev/2025/08/18/flyway-vs-liquibase-which-database-migration-tool-is-right-for-you/)

### Backup Management
- [Top MySQL/MariaDB Backup Tools 2026](https://dev.to/dmetrovich/top-mysql-and-mariadb-backup-tools-in-2026-32ak)
- [Best Database Backup Tools 2026](https://www.websentra.com/best-database-backup-tools/)
- [Database Backup Software Comparison](https://www.acronis.com/en/blog/posts/database-backup/)
- [Backup and Restore Best Practices](https://learn.microsoft.com/en-us/sharepoint/administration/best-practices-for-backup-and-restore)

### SMTP Testing
- [Top SMTP Testing Tools 2025](https://www.mailkarma.ai/blog/best-smtp-testing-tools-2025-fix-email-failures-fast)
- [Mailtrap Email Testing](https://mailtrap.io/)
- [Mailpit SMTP Testing Tool](https://mailpit.axllent.org/)
- [SMTP Server Setup Best Practices 2025](https://octeth.com/best-practices-setting-up-smtp-servers/)
- [Email Validation Best Practices 2025](https://mailfloss.com/email-validation-best-practices-ensuring-high-delivery-rates-in-2025/)

### Production Docker
- [Docker HEALTHCHECK Best Practices](https://mihirpopat.medium.com/understanding-dockerfile-healthcheck-the-missing-layer-in-production-grade-containers-ad4879353a5e)
- [Docker Production Deployment Checklist](https://dev.to/ramer_lacida_2b58cbe46bc8/the-ultimate-checklist-for-docker-deployments-on-production-3e9c)
- [Docker Compose Health Checks Guide](https://last9.io/blog/docker-compose-health-checks/)
- [Zero-Downtime Docker Deploys](https://dev.to/ramer2b58cbe46bc8/the-ultimate-checklist-for-zero-downtime-deploys-with-docker-and-nginx-22fc)
- [How to Deploy Apps with Docker Compose 2025](https://dokploy.com/blog/how-to-deploy-apps-with-docker-compose-in-2025)

### Existing Codebase Analysis
- `/home/bernt-popp/development/sysndd/docker-compose.yml` - Current backup container config
- `/home/bernt-popp/development/sysndd/api/endpoints/health_endpoints.R` - Existing health check pattern
- `/home/bernt-popp/development/sysndd/api/endpoints/admin_endpoints.R` - Admin endpoint patterns
- `/home/bernt-popp/development/sysndd/api/config.yml` - SMTP configuration
- `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageUser.vue` - Admin UI patterns

---

*Research completed: 2026-01-29*
*Confidence: MEDIUM (web research patterns verified against existing codebase)*
*Researcher: GSD Project Researcher (Features dimension - v9.0 Production Readiness)*
