# Project State: SysNDD

**Last updated:** 2026-01-29
**Current milestone:** v9.0 Production Readiness

---

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-29)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v9.0 Production Readiness — migrations, backups, user lifecycle, Docker validation

**Stack:** R 4.4.3 (Plumber API) + Vue 3.5.25 (TypeScript) + Bootstrap-Vue-Next 0.42.0 + MySQL 8.0.40

---

## Current Position

**Phase:** Not started (defining requirements)
**Plan:** —
**Status:** Defining requirements
**Progress:** ░░░░░░░░░░ 0%

**Last completed:** v8.0 Gene Page & Genomic Data Integration (2026-01-29)
**Next step:** Define requirements, create roadmap

---

## Milestone v9.0 Goals

1. **Automated Migration System**
   - schema_version tracking table
   - db-migrate.R runner script
   - Auto-apply on API startup
   - Fix migration 002 idempotency

2. **Backup Management**
   - API endpoints (trigger, list, restore)
   - Admin UI at /admin/backups
   - Full replace restore with safety rails

3. **User Lifecycle & SMTP**
   - Mailpit for local dev
   - Real SMTP config for production testing
   - E2E verification: registration, confirmation, password reset

4. **Production Docker**
   - Validate 4-worker API build
   - Production configuration verification

---

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 244
- Milestones shipped: 8 (v1-v8)
- Phases completed: 46

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |
| v6 Admin Panel Modernization | 28-33 | 20 | 2026-01-26 |
| v7 Curation Workflow Modernization | 34-39 | 21 | 2026-01-27 |
| v8 Gene Page & Genomic Data | 40-46 | 25 | 2026-01-29 |
| v9 Production Readiness | 47-? | TBD | In progress |

**Current Stats:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Backend Tests** | 634 passing | 20.3% coverage, 24 integration tests |
| **Frontend Tests** | 144 + 6 a11y suites | Vitest + Vue Test Utils + vitest-axe |
| **Vue Composables** | 28 | 7 original + 6 admin + 10 curation + 5 gene page |
| **Migrations** | 3 files | In db/migrations/, no auto-runner yet |
| **Lintr Issues** | 0 | From 1,240 in v4 |
| **ESLint Issues** | 0 | 240 errors fixed in v7 |
| **Bundle Size** | ~600 KB gzipped | Vite 7.3.1, 164ms dev startup |

---

## Accumulated Context

### Existing Migration System

From codebase exploration:
- 3 migration files in `db/migrations/` (001-003)
- Migration 003 uses idempotent stored procedure pattern (best practice)
- Migration 002 is NOT idempotent (needs fixing)
- No schema_version tracking table
- No automated runner
- Backlog items document planned approach

### Existing Backup System

- Cron job container does SQL dumps
- No API endpoints for manual trigger
- No restore capability
- No admin UI

### User Email System

- Registration and password reset exist
- Not tested E2E with real SMTP
- Need Mailpit for local dev visibility

---

## Session Continuity

**Last session:** 2026-01-29
**Stopped at:** Defining v9.0 requirements
**Next action:** Complete requirements definition, create roadmap

**Handoff notes:**

1. **v9.0 milestone initialized:**
   - PROJECT.md updated with milestone goals
   - STATE.md reset for new milestone
   - Four focus areas defined

2. **Pending decisions:**
   - Research: skip or run (infrastructure patterns are well-known)
   - Requirements: need to finalize and assign IDs
   - Roadmap: need to create phases

---

*State initialized: 2026-01-20*
*Last updated: 2026-01-29 — v9.0 milestone started*
