# Roadmap: SysNDD v9.0 Production Readiness

**Created:** 2026-01-29
**Milestone:** v9.0 Production Readiness
**Phases:** 47-53 (7 phases)
**Requirements:** 21 mapped

---

## Overview

SysNDD v9.0 focuses on production readiness infrastructure: automated database migrations with tracking and auto-apply, backup management with admin UI, user lifecycle verification with real SMTP testing, and production Docker validation. These seven phases build sequentially from migration foundation through production validation.

---

## Phase 47: Migration System Foundation

**Goal:** Database migrations execute reliably with state tracking

**Dependencies:** None (foundation phase)

**Requirements:**
- MIGR-01: System creates schema_version table to track applied migrations
- MIGR-02: Migrations execute sequentially in numeric order (001, 002, 003...)
- MIGR-03: Migration runner is idempotent (safe to run multiple times)
- MIGR-05: Migration 002 rewritten to be idempotent (IF NOT EXISTS guards)

**Success Criteria:**
1. Developer can run migration runner manually and see which migrations were applied
2. Running migration runner twice produces identical database state (no errors, no duplicates)
3. Schema_version table shows timestamp and filename for each applied migration
4. Migration 002 can be re-run on a database where it already ran without error

---

## Phase 48: Migration Auto-Run & Health

**Goal:** API startup automatically applies pending migrations with health visibility

**Dependencies:** Phase 47 (migration foundation must exist)

**Requirements:**
- MIGR-04: API startup auto-detects and applies missing migrations
- MIGR-06: Health endpoint reports pending migrations count

**Success Criteria:**
1. API container starting against fresh database automatically applies all migrations
2. API container starting against up-to-date database reports zero pending migrations
3. Health endpoint shows pending_migrations count (0 when current, >0 when behind)
4. API startup logs clearly show which migrations were applied

---

## Phase 49: Backup API Layer

**Goal:** Backups can be managed programmatically via REST API

**Dependencies:** None (parallel with Phase 48)

**Requirements:**
- BKUP-01: API endpoint lists available backup files with metadata
- BKUP-03: API endpoint triggers manual backup creation
- BKUP-05: System creates automatic backup before any restore operation
- BKUP-06: Backup metadata includes file size, creation date, and table count

**Success Criteria:**
1. GET /api/admin/backups returns list of backup files with size, date, and table count
2. POST /api/admin/backups triggers new backup and returns job ID for polling
3. Restore operation automatically creates timestamped backup before proceeding
4. Backup metadata accurately reflects file properties (verified against filesystem)

---

## Phase 50: Backup Admin UI

**Goal:** Administrators can manage backups through the admin panel

**Dependencies:** Phase 49 (backup API must exist)

**Requirements:**
- BKUP-02: Admin UI displays backup list with download links
- BKUP-04: Restore requires typed confirmation ("RESTORE" to proceed)

**Success Criteria:**
1. Admin can navigate to /admin/backups and see list of available backups
2. Admin can download any backup file directly from the UI
3. Admin can trigger "Backup Now" and see progress via job polling
4. Restore modal requires typing "RESTORE" exactly before proceeding (prevents accidents)

---

## Phase 51: SMTP Testing Infrastructure

**Goal:** Email system is testable in development with captured messages

**Dependencies:** None (parallel with backup phases)

**Requirements:**
- SMTP-01: Mailpit container captures all emails in development
- SMTP-02: API endpoint tests SMTP connection and returns status

**Success Criteria:**
1. Development environment includes Mailpit container accessible at localhost:8025
2. All emails sent by API in development mode appear in Mailpit inbox (none sent externally)
3. GET /api/admin/smtp/test returns connection status (success/failure with error details)
4. Mailpit UI shows email content, headers, and attachments for debugging

---

## Phase 52: User Lifecycle E2E

**Goal:** User registration, confirmation, and password reset work end-to-end

**Dependencies:** Phase 51 (Mailpit must capture emails)

**Requirements:**
- SMTP-03: User registration flow works end-to-end with email capture
- SMTP-04: Email confirmation flow works end-to-end
- SMTP-05: Password reset flow works end-to-end

**Success Criteria:**
1. New user registers, confirmation email appears in Mailpit within 5 seconds
2. Clicking confirmation link in captured email activates the user account
3. Password reset request sends email visible in Mailpit with reset link
4. Password reset link allows user to set new password and log in successfully

---

## Phase 53: Production Docker Validation

**Goal:** Production Docker build is validated and ready for deployment

**Dependencies:** Phases 47-52 (all features complete for integration testing)

**Requirements:**
- PROD-01: Production Docker build with 4 API workers validated
- PROD-02: Connection pool sized correctly for multi-worker setup
- PROD-03: Extended health check (/health/ready) verifies database connectivity
- PROD-04: Makefile target for pre-flight production validation

**Success Criteria:**
1. Production Docker build starts successfully with 4 API worker processes
2. All 4 workers can handle concurrent database queries without pool exhaustion
3. /health/ready returns 200 only when database is connected and migrations current
4. `make preflight` runs validation suite and reports pass/fail with clear output

---

## Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 47 | Migration System Foundation | MIGR-01, MIGR-02, MIGR-03, MIGR-05 | Not Started |
| 48 | Migration Auto-Run & Health | MIGR-04, MIGR-06 | Not Started |
| 49 | Backup API Layer | BKUP-01, BKUP-03, BKUP-05, BKUP-06 | Not Started |
| 50 | Backup Admin UI | BKUP-02, BKUP-04 | Not Started |
| 51 | SMTP Testing Infrastructure | SMTP-01, SMTP-02 | Not Started |
| 52 | User Lifecycle E2E | SMTP-03, SMTP-04, SMTP-05 | Not Started |
| 53 | Production Docker Validation | PROD-01, PROD-02, PROD-03, PROD-04 | Not Started |

**Coverage:** 21/21 requirements mapped (100%)

---

## Dependency Graph

```
Phase 47 (Migration Foundation)
    |
    v
Phase 48 (Migration Auto-Run & Health)
    |
    +---------------------------+
    |                           |
    v                           v
Phase 49 (Backup API)     Phase 51 (SMTP Infrastructure)
    |                           |
    v                           v
Phase 50 (Backup Admin UI) Phase 52 (User Lifecycle E2E)
    |                           |
    +---------------------------+
                |
                v
        Phase 53 (Production Docker Validation)
```

---

*Roadmap created: 2026-01-29*
*Last updated: 2026-01-29*
