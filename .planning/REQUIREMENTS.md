# Requirements: SysNDD v6.0 Admin Panel Modernization

**Defined:** 2026-01-25
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v6.0 Requirements

Requirements for Admin Panel Modernization. Each maps to roadmap phases.

### Table Foundation

- [x] **TBL-01**: Admin tables (ManageUser, ManageOntology) have search functionality (global + per-column)
- [x] **TBL-02**: Admin tables have pagination controls (page size selector, jump to page)
- [x] **TBL-03**: Admin tables have advanced filtering (date ranges, multi-select dropdowns where applicable)
- [x] **TBL-04**: Admin tables have URL state sync (bookmarkable filter/sort/pagination state)
- [x] **TBL-05**: Admin tables have CSV export functionality
- [x] **TBL-06**: API endpoints support pagination and search for user and ontology data

### User Management

- [ ] **USR-01**: Admin can bulk select users across multiple pages
- [ ] **USR-02**: Admin can bulk approve selected users
- [ ] **USR-03**: Admin can bulk delete selected users
- [ ] **USR-04**: Admin can bulk assign roles to selected users
- [ ] **USR-05**: Selection state persists across pagination (Set-based ID storage)
- [ ] **USR-06**: Confirmation dialog shows all selected items before bulk action
- [ ] **USR-07**: Admin can save filter combinations as named views ("Pending Approvals")
- [ ] **USR-08**: Role selector uses dropdown instead of text input

### Statistics Dashboard

- [ ] **STAT-01**: AdminStatistics displays line chart for entities over time
- [ ] **STAT-02**: AdminStatistics displays bar chart for user contributions
- [ ] **STAT-03**: AdminStatistics uses Chart.js integration via vue-chartjs
- [ ] **STAT-04**: Charts include scientific context (baselines, comparisons, "What this means" text)
- [ ] **STAT-05**: Dashboard has card-based layout with loading states

### Content Management

- [ ] **CMS-01**: ManageAbout has markdown textarea for content editing
- [ ] **CMS-02**: ManageAbout has preview pane showing rendered markdown
- [ ] **CMS-03**: ManageAbout has draft/save workflow (no accidental publishing)
- [ ] **CMS-04**: About page content is stored in database (not hardcoded)
- [ ] **CMS-05**: API endpoint for loading and saving About page content

### Async Jobs

- [ ] **JOB-01**: useAsyncJob composable extracted from ManageAnnotations pattern
- [ ] **JOB-02**: HGNC update uses async job pattern with progress display
- [ ] **JOB-03**: HGNC update shows last annotation date
- [ ] **JOB-04**: Job history table shows recent async jobs (reuses GenericTable)
- [ ] **JOB-05**: Enhanced error messaging with specific failure reasons
- [ ] **JOB-06**: All async jobs have proper cleanup (no memory leaks on navigation)

### Logging

- [ ] **LOG-01**: ViewLogs has user filter (filter logs by specific user)
- [ ] **LOG-02**: ViewLogs has action type filter (multi-select: CREATE, UPDATE, DELETE)
- [ ] **LOG-03**: ViewLogs has CSV export for compliance reporting
- [ ] **LOG-04**: ViewLogs has log detail modal (expand single log entry)
- [ ] **LOG-05**: Feature parity with Entities table (same filter/pagination/URL sync UX)

## Future Requirements

Deferred to v7 or later.

### CI/CD & Quality

- **CICD-01**: GitHub Actions CI/CD pipeline
- **CICD-02**: Trivy security scanning in pipeline
- **CICD-03**: Expanded frontend test coverage (40-50%)
- **CICD-04**: Vue component TypeScript conversion
- **CICD-05**: URL path versioning (/api/v1/)
- **CICD-06**: Version displayed in frontend

### Advanced Admin Features

- **ADV-01**: Chart export to PNG/SVG (publication-ready)
- **ADV-02**: TipTap rich text editor (WYSIWYG instead of markdown)
- **ADV-03**: Inline editing in admin tables
- **ADV-04**: Job cancellation (if mirai supports)
- **ADV-05**: Real-time notifications for admin events

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Over-engineered CMS with versioning | ManageAbout is single page; simple markdown sufficient for v6 |
| Complex permission UI (50+ checkboxes) | SysNDD has 3-5 roles; predefined role dropdown is sufficient |
| Real-time collaboration editing | Complex, rarely needed; use optimistic locking instead |
| Custom SQL query builder | Usability trap; pre-built filters serve admin needs |
| Mobile native app | Responsive web sufficient; admins rarely curate on phones |
| Gamification (leaderboards, badges) | Inappropriate for scientific curation |
| Additional UI libraries (PrimeVue, Vuetify) | Bootstrap-Vue-Next has all needed components |
| ApexCharts/ECharts | Chart.js sufficient for admin statistics |
| ag-Grid/TanStack Table | TablesEntities pattern already implements everything needed |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TBL-01 | Phase 28 | Complete |
| TBL-02 | Phase 28 | Complete |
| TBL-03 | Phase 28 | Complete |
| TBL-04 | Phase 28 | Complete |
| TBL-05 | Phase 28 | Complete |
| TBL-06 | Phase 28 | Complete |
| USR-01 | Phase 29 | Pending |
| USR-02 | Phase 29 | Pending |
| USR-03 | Phase 29 | Pending |
| USR-04 | Phase 29 | Pending |
| USR-05 | Phase 29 | Pending |
| USR-06 | Phase 29 | Pending |
| USR-07 | Phase 29 | Pending |
| USR-08 | Phase 29 | Pending |
| STAT-01 | Phase 30 | Pending |
| STAT-02 | Phase 30 | Pending |
| STAT-03 | Phase 30 | Pending |
| STAT-04 | Phase 30 | Pending |
| STAT-05 | Phase 30 | Pending |
| CMS-01 | Phase 31 | Pending |
| CMS-02 | Phase 31 | Pending |
| CMS-03 | Phase 31 | Pending |
| CMS-04 | Phase 31 | Pending |
| CMS-05 | Phase 31 | Pending |
| JOB-01 | Phase 32 | Pending |
| JOB-02 | Phase 32 | Pending |
| JOB-03 | Phase 32 | Pending |
| JOB-04 | Phase 32 | Pending |
| JOB-05 | Phase 32 | Pending |
| JOB-06 | Phase 32 | Pending |
| LOG-01 | Phase 33 | Pending |
| LOG-02 | Phase 33 | Pending |
| LOG-03 | Phase 33 | Pending |
| LOG-04 | Phase 33 | Pending |
| LOG-05 | Phase 33 | Pending |

**Coverage:**
- v6.0 requirements: 35 total
- Mapped to phases: 35 (100%)
- Unmapped: 0

**Requirement distribution:**
- Phase 28 (Table Foundation): 6 requirements
- Phase 29 (User Management): 8 requirements
- Phase 30 (Statistics Dashboard): 5 requirements
- Phase 31 (Content Management): 5 requirements
- Phase 32 (Async Jobs): 6 requirements
- Phase 33 (Logging & Analytics): 5 requirements

---
*Requirements defined: 2026-01-25*
*Last updated: 2026-01-25 — Phase 28 requirements complete (TBL-01 through TBL-06)*
