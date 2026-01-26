# Milestone v6.0: Admin Panel Modernization

**Status:** SHIPPED 2026-01-26
**Phases:** 28-33
**Total Plans:** 20

## Overview

Transform admin views from basic CRUD forms into modern, feature-rich management interfaces with consistent UI/UX, pagination, search, and visualization.

## Phases

### Phase 28: Table Foundation

**Goal**: Modernize ManageUser and ManageOntology with TablesEntities pattern (search, pagination, URL sync)
**Depends on**: Phase 27
**Plans**: 3 plans

Plans:
- [x] 28-01: Backend API pagination, filter, sort support for user and ontology endpoints
- [x] 28-02: Modernize ManageUser.vue with TablesEntities pattern and CSV export
- [x] 28-03: Modernize ManageOntology.vue with TablesEntities pattern and CSV export

**Details:**
- Module-level caching to prevent duplicate API calls on component remount
- Debounced search with 300ms delay for responsive filtering
- URL state synchronization using history.replaceState (no component remount)
- Filter object structure with operator and join_char patterns
- Active filter pills with individual clear buttons

### Phase 29: User Management Workflows

**Goal**: Implement bulk actions (approve, delete, role assignment) with cross-page selection
**Depends on**: Phase 28
**Plans**: 4 plans

Plans:
- [x] 29-01: Backend bulk endpoints (bulk_approve, bulk_delete, bulk_assign_role)
- [x] 29-02: Frontend composables (useBulkSelection, useFilterPresets)
- [x] 29-03: ManageUser.vue bulk selection UI (checkboxes, badge, action bar)
- [x] 29-04: Bulk action implementation and filter presets

**Details:**
- Bootstrap modal confirmation pattern for bulk actions (not native confirm/prompt)
- Type-to-confirm pattern for destructive actions (requires exact text input)
- Username list display in modals (show all affected items)
- Dropdown selector for role assignment (not text prompt)
- Filter preset persistence via useFilterPresets composable

### Phase 30: Statistics Dashboard

**Goal**: Add Chart.js visualizations to AdminStatistics with scientific context
**Depends on**: Phase 28
**Plans**: 3 plans

Plans:
- [x] 30-01: Install Chart.js and create reusable chart components
- [x] 30-02: Add contributor leaderboard API endpoint
- [x] 30-03: Modernize AdminStatistics.vue with charts and KPI cards

**Details:**
- Tree-shaken Chart.js registration reduces bundle size ~30-40% vs registerables
- Trend delta comparison uses equal-length periods for calculation
- Admin dashboard layout: KPI cards row at top, then charts, then detail cards
- Chart granularity toggle using BFormRadioGroup with buttons variant

### Phase 31: Content Management

**Goal**: Build CMS editor for ManageAbout page with draft/publish workflow
**Depends on**: Phase 28
**Plans**: 4 plans

Plans:
- [x] 31-01: Database schema and API endpoints for draft/publish workflow
- [x] 31-02: Install libraries, TypeScript types, and composables
- [x] 31-03: CMS components (MarkdownEditor, MarkdownPreview, SectionEditor, SectionList)
- [x] 31-04: ManageAbout.vue and About.vue integration

**Details:**
- JSON column for sections (flexible CMS schema, no migrations for structure changes)
- Single draft per user (upsert pattern enforces one active draft)
- Version auto-increment (MAX(version) + 1 query)
- Public CMS endpoint (GET /published requires no auth)
- Global vue-dompurify-html for consistent XSS sanitization
- Side-by-side editor/preview at SectionEditor level

### Phase 32: Async Jobs

**Goal**: Extract useAsyncJob composable and improve ManageAnnotations job UI
**Depends on**: Phase 28
**Plans**: 3 plans

Plans:
- [x] 32-01: Extract useAsyncJob composable with VueUse polling and cleanup
- [x] 32-02: HGNC async job endpoint and ManageAnnotations composable refactor
- [x] 32-03: Job history API endpoint and table UI

**Details:**
- VueUse useIntervalFn for polling (auto-cleanup via tryOnCleanup)
- useAsyncJob composable: reactive job state with elapsed time display
- HGNC async job pattern: POST /api/jobs/hgnc_update/submit with 202 Accepted
- Composition API for ManageAnnotations (converted from Options API)
- Job history in-memory storage (jobs_env environment)

### Phase 33: Logging & Analytics

**Goal**: Add advanced filtering and export to ViewLogs (feature parity with Entities table)
**Depends on**: Phase 28
**Plans**: 3 plans

Plans:
- [x] 33-01: Module-level caching, URL sync, relative timestamps
- [x] 33-02: User filter dropdown, action type filter, filter pills UI
- [x] 33-03: Log detail drawer with copy to clipboard and keyboard navigation

**Details:**
- TablesLogs module-level caching (same pattern as TablesEntities)
- Intl.RelativeTimeFormat for timestamps (native browser API)
- HTTP status badge color scheme (2xx=success, 4xx=warning, 5xx=danger)
- Filter pills pattern with hasActiveFilters + clearFilter()
- BOffcanvas detail drawer with keyboard navigation
- useClipboard for copy (VueUse composable with copiedDuring)
- Filter-aware XLSX export with date-stamped filename

---

## Milestone Summary

**Key Decisions:**
- TablesEntities pattern: URL state sync via VueUse useUrlSearchParams, module-level caching
- Bootstrap-Vue-Next 0.42.0: Has all needed components (BTable, BCard, BModal, BForm)
- Chart.js + vue-chartjs: Chosen for statistics dashboard (~50KB gzipped)
- marked + DOMPurify: Chosen for CMS markdown rendering
- VueUse useIntervalFn: Auto-cleanup for async job polling

**Issues Resolved:**
- Admin tables now have consistent UX (search, pagination, URL sync, export)
- Bulk operations have proper confirmation workflows
- Async jobs have proper memory leak prevention
- Audit logging has feature parity with data tables

**Issues Deferred:**
- Bulk operation audit logging (future milestone)
- Database migration automation (future milestone)
- TipTap rich text editor (future milestone)

**Technical Debt Incurred:**
- Legacy TODO comment about treeselect migration (TablesLogs.vue:197) - does not affect Phase 33 features

---

_For current project status, see .planning/ROADMAP.md_
