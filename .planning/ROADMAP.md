# Roadmap: SysNDD

## Overview

This roadmap tracks the current milestone and references completed milestones archived in `.planning/milestones/`.

## Milestones

- **v1.0 Developer Experience** — Phases 1-5 (shipped 2026-01-21) → [Archive](milestones/v1-ROADMAP.md)
- **v2.0 Docker Infrastructure** — Phases 6-9 (shipped 2026-01-22) → [Archive](milestones/v2-ROADMAP.md)
- **v3.0 Frontend Modernization** — Phases 10-17 (shipped 2026-01-23) → [Archive](milestones/03-frontend-modernization/)
- **v4.0 Backend Overhaul** — Phases 18-24 (shipped 2026-01-24) → [Archive](milestones/v4-ROADMAP.md)
- **v5.0 Analysis Modernization** — Phases 25-27 (shipped 2026-01-25) → [Archive](milestones/v5.0-ROADMAP.md)
- 🚧 **v6.0 Admin Panel Modernization** — Phases 28-33 (in progress)

## Current Status: v6.0 Admin Panel Modernization

**Milestone Goal:** Transform admin views from basic CRUD forms into modern, feature-rich management interfaces with consistent UI/UX, pagination, search, and visualization.

**Progress:** Phase 28 of 33 (complete) → Phase 29 next
**Requirements:** 35 total (100% coverage)
**Target:** 6 phases extending TablesEntities patterns to admin domain

### 🚧 v6.0 Admin Panel Modernization (Phases 28-33)

#### Phase 28: Table Foundation
**Goal**: Modernize ManageUser and ManageOntology with TablesEntities pattern (search, pagination, URL sync)
**Depends on**: Phase 27
**Requirements**: TBL-01, TBL-02, TBL-03, TBL-04, TBL-05, TBL-06
**Success Criteria** (what must be TRUE):
  1. Admin can search users by name, email, or institution with instant results
  2. Admin can filter users by role (Curator, Reviewer, Admin) or approval status
  3. Admin can paginate through large user/ontology tables with page size control (20/50/100)
  4. Admin can bookmark filtered/sorted user table state via URL (refresh preserves state)
  5. Admin can export user/ontology data to CSV with current filters applied
  6. API endpoints return paginated and searchable user/ontology data with total count
**Plans**: 3 plans

Plans:
- [x] 28-01-PLAN.md — Backend API pagination, filter, sort support for user and ontology endpoints
- [x] 28-02-PLAN.md — Modernize ManageUser.vue with TablesEntities pattern and CSV export
- [x] 28-03-PLAN.md — Modernize ManageOntology.vue with TablesEntities pattern and CSV export

#### Phase 29: User Management Workflows
**Goal**: Implement bulk actions (approve, delete, role assignment) with cross-page selection
**Depends on**: Phase 28
**Requirements**: USR-01, USR-02, USR-03, USR-04, USR-05, USR-06, USR-07, USR-08
**Success Criteria** (what must be TRUE):
  1. Admin can select users across multiple pages (selection badge shows "5 selected")
  2. Admin can bulk approve 20 pending users in one action with confirmation dialog
  3. Admin can bulk delete test accounts with "Are you sure?" dialog listing all usernames
  4. Admin can bulk assign "Curator" role to 10 users at once
  5. Admin can save "Pending Approvals" filter preset and reload it with one click
  6. Admin assigns roles via dropdown (Curator/Reviewer/Admin) not text input
**Plans**: 4 plans

Plans:
- [ ] 29-01-PLAN.md — Backend bulk endpoints (bulk_approve, bulk_delete, bulk_assign_role)
- [ ] 29-02-PLAN.md — Frontend composables (useBulkSelection, useFilterPresets)
- [ ] 29-03-PLAN.md — ManageUser.vue bulk selection UI (checkboxes, badge, action bar)
- [ ] 29-04-PLAN.md — Bulk action implementation and filter presets

#### Phase 30: Statistics Dashboard
**Goal**: Add Chart.js visualizations to AdminStatistics with scientific context
**Depends on**: Phase 28
**Requirements**: STAT-01, STAT-02, STAT-03, STAT-04, STAT-05
**Success Criteria** (what must be TRUE):
  1. Admin sees line chart of entity submissions over time (last 12 months)
  2. Admin sees bar chart of top 10 contributor leaderboard (entity count per user)
  3. Charts use Chart.js via vue-chartjs with responsive Bootstrap card layout
  4. Each chart includes context ("246 entities, up 12% vs last month" with trend arrow)
  5. Dashboard has card-based layout with loading spinners during data fetch
**Plans**: 3 plans

Plans:
- [ ] 30-01-PLAN.md — Install Chart.js and create reusable chart components
- [ ] 30-02-PLAN.md — Add contributor leaderboard API endpoint
- [ ] 30-03-PLAN.md — Modernize AdminStatistics.vue with charts and KPI cards

#### Phase 31: Content Management
**Goal**: Build CMS editor for ManageAbout page with draft/publish workflow
**Depends on**: Phase 28
**Requirements**: CMS-01, CMS-02, CMS-03, CMS-04, CMS-05
**Success Criteria** (what must be TRUE):
  1. Admin edits About page content in markdown textarea with toolbar
  2. Admin sees live preview pane showing rendered HTML while typing
  3. Admin can save draft without publishing (two buttons: "Save Draft" / "Publish")
  4. About page content loads from database table (not hardcoded component)
  5. API endpoint saves and retrieves About content with draft/published versions
**Plans**: 4 plans

Plans:
- [ ] 31-01-PLAN.md — Database schema and API endpoints for draft/publish workflow
- [ ] 31-02-PLAN.md — Install libraries, TypeScript types, and composables
- [ ] 31-03-PLAN.md — CMS components (MarkdownEditor, MarkdownPreview, SectionEditor, SectionList)
- [ ] 31-04-PLAN.md — ManageAbout.vue and About.vue integration

#### Phase 32: Async Jobs
**Goal**: Extract useAsyncJob composable and improve ManageAnnotations job UI
**Depends on**: Phase 28
**Requirements**: JOB-01, JOB-02, JOB-03, JOB-04, JOB-05, JOB-06
**Success Criteria** (what must be TRUE):
  1. useAsyncJob composable is reusable for any long-running job (HGNC, annotations)
  2. HGNC update job shows progress bar with elapsed time and status messages
  3. HGNC job displays "Last annotation: 2026-01-20" before starting new job
  4. Job history table shows recent async jobs (type, status, duration, user) in GenericTable
  5. Failed jobs show specific error ("Network timeout" not "Job failed")
  6. All async jobs cleanup polling interval in beforeUnmount (no memory leaks)
**Plans**: 3 plans

Plans:
- [ ] 32-01-PLAN.md — Extract useAsyncJob composable with VueUse polling and cleanup
- [ ] 32-02-PLAN.md — HGNC async job endpoint and ManageAnnotations composable refactor
- [ ] 32-03-PLAN.md — Job history API endpoint and table UI

#### Phase 33: Logging & Analytics
**Goal**: Add advanced filtering and export to ViewLogs (feature parity with Entities table)
**Depends on**: Phase 28
**Requirements**: LOG-01, LOG-02, LOG-03, LOG-04, LOG-05
**Success Criteria** (what must be TRUE):
  1. Admin can filter logs by specific user (dropdown with autocomplete)
  2. Admin can filter logs by action type (multi-select: CREATE, UPDATE, DELETE)
  3. Admin can export filtered logs to CSV for compliance reporting
  4. Admin can expand single log entry in modal to see full JSON payload
  5. ViewLogs has same filter/pagination/URL sync UX as TablesEntities
**Plans**: 3 plans

Plans:
- [ ] 33-01-PLAN.md — Module-level caching, URL sync, relative timestamps
- [ ] 33-02-PLAN.md — User filter dropdown, action type filter, filter pills UI
- [ ] 33-03-PLAN.md — Log detail drawer with copy to clipboard and keyboard navigation

## Progress

**Execution Order:**
Phases execute in numeric order: 28 → 29 → 30 → 31 → 32 → 33

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 28. Table Foundation | v6.0 | 3/3 | ✓ Complete | 2026-01-25 |
| 29. User Management | v6.0 | 0/4 | Planned | - |
| 30. Statistics Dashboard | v6.0 | 0/3 | Planned | - |
| 31. Content Management | v6.0 | 0/4 | Planned | - |
| 32. Async Jobs | v6.0 | 0/3 | Planned | - |
| 33. Logging & Analytics | v6.0 | 0/3 | Planned | - |

## Completed Phases Summary

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1.0 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2.0 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3.0 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4.0 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5.0 Analysis Modernization | 25-27 | 16 | 2026-01-25 |

**Total:** 27 phases, 138 plans shipped across 5 milestones

---
*Roadmap created: 2026-01-20*
*Last updated: 2026-01-25 — Phase 33 planned (3 plans)*
