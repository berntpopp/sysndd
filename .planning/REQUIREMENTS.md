# Requirements: SysNDD v9.0 Production Readiness

**Defined:** 2026-01-29
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v9.0 Requirements

Requirements for production readiness milestone. Each maps to roadmap phases.

### Migration System

- [ ] **MIGR-01**: System creates schema_version table to track applied migrations
- [ ] **MIGR-02**: Migrations execute sequentially in numeric order (001, 002, 003...)
- [ ] **MIGR-03**: Migration runner is idempotent (safe to run multiple times)
- [ ] **MIGR-04**: API startup auto-detects and applies missing migrations
- [ ] **MIGR-05**: Migration 002 rewritten to be idempotent (IF NOT EXISTS guards)
- [ ] **MIGR-06**: Health endpoint reports pending migrations count

### Backup Management

- [ ] **BKUP-01**: API endpoint lists available backup files with metadata
- [ ] **BKUP-02**: Admin UI displays backup list with download links
- [ ] **BKUP-03**: API endpoint triggers manual backup creation
- [ ] **BKUP-04**: Restore requires typed confirmation ("RESTORE" to proceed)
- [ ] **BKUP-05**: System creates automatic backup before any restore operation
- [ ] **BKUP-06**: Backup metadata includes file size, creation date, and table count

### SMTP & User Lifecycle

- [ ] **SMTP-01**: Mailpit container captures all emails in development
- [ ] **SMTP-02**: API endpoint tests SMTP connection and returns status
- [ ] **SMTP-03**: User registration flow works end-to-end with email capture
- [ ] **SMTP-04**: Email confirmation flow works end-to-end
- [ ] **SMTP-05**: Password reset flow works end-to-end

### Production Docker

- [ ] **PROD-01**: Production Docker build with 4 API workers validated
- [ ] **PROD-02**: Connection pool sized correctly for multi-worker setup
- [ ] **PROD-03**: Extended health check (/health/ready) verifies database connectivity
- [ ] **PROD-04**: Makefile target for pre-flight production validation

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Admin Enhancements

- **ADMIN-01**: Migration admin UI showing applied/pending migrations
- **ADMIN-02**: Dry-run mode showing what migrations would be applied
- **ADMIN-03**: Test email send button from admin panel
- **ADMIN-04**: SMTP health indicator in status dashboard
- **ADMIN-05**: Backup notifications on success/failure

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Point-in-time recovery | Requires binary logs, adds complexity beyond SQL dumps |
| One-click restore button | Too dangerous; type-to-confirm pattern safer |
| Auto-migrations on startup without flag | Too risky for production; explicit trigger preferred |
| Database rollback support | MySQL DDL is not transactional; adds significant complexity |
| Backup encryption | Adds complexity; rely on volume/filesystem encryption |
| CI/CD pipeline | Defer to v10; focus on local validation first |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MIGR-01 | Phase 47 | Pending |
| MIGR-02 | Phase 47 | Pending |
| MIGR-03 | Phase 47 | Pending |
| MIGR-04 | Phase 48 | Pending |
| MIGR-05 | Phase 47 | Pending |
| MIGR-06 | Phase 48 | Pending |
| BKUP-01 | Phase 49 | Pending |
| BKUP-02 | Phase 50 | Pending |
| BKUP-03 | Phase 49 | Pending |
| BKUP-04 | Phase 50 | Pending |
| BKUP-05 | Phase 49 | Pending |
| BKUP-06 | Phase 49 | Pending |
| SMTP-01 | Phase 51 | Pending |
| SMTP-02 | Phase 51 | Pending |
| SMTP-03 | Phase 52 | Pending |
| SMTP-04 | Phase 52 | Pending |
| SMTP-05 | Phase 52 | Pending |
| PROD-01 | Phase 53 | Pending |
| PROD-02 | Phase 53 | Pending |
| PROD-03 | Phase 53 | Pending |
| PROD-04 | Phase 53 | Pending |

**Coverage:**
- v9.0 requirements: 21 total
- Mapped to phases: 21 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-01-29*
*Last updated: 2026-01-29 after roadmap creation*
