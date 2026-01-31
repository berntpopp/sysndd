# Architecture Integration: Admin Panel Modernization

**Project:** SysNDD Admin Panel Modernization
**Domain:** Admin dashboard/CMS integration with existing Vue 3 + R/Plumber architecture
**Researched:** 2026-01-25
**Confidence:** HIGH

## Executive Summary

Admin panel modernization integrates seamlessly with SysNDD's existing composable-driven Vue 3 architecture and R/Plumber repository pattern. All established patterns remain valid:
- **Frontend**: Reuse `useTableData`, `useTableMethods`, `GenericTable` for search/pagination
- **Backend**: Extend existing repositories (user-repository.R, entity-repository.R) with admin operations
- **Async jobs**: Leverage existing mirai job system for long-running operations
- **New patterns needed**: Chart composables, rich text editor integration, CMS content storage

The architecture requires **minimal new patterns** because admin features primarily need existing patterns applied to different domains (users, ontology, logs, statistics).

## Current Architecture Assessment

### Frontend: Vue 3 Composable Architecture

**Status:** Mature, well-established patterns

#### Core Composables (Reusable for Admin)

| Composable | Purpose | Admin Use Cases |
|------------|---------|-----------------|
| `useTableData` | Table state management (items, sorting, pagination) | ManageUser, ManageOntology, ViewLogs |
| `useTableMethods` | Table actions (filter, sort, page, export) | All admin tables |
| `useToast` | Toast notification system | All admin operations (success/error feedback) |
| `useModalControls` | Modal show/hide state | Edit user modal, edit ontology modal |
| `useFormDraft` | Form state persistence | Future admin form features |
| `useExcelExport` | Excel download functionality | All admin table exports |

**Assessment:** These composables are production-ready and used in `TablesEntities`, `TablesLogs`, `TablesPhenotypes`. Admin views should follow the same patterns.

#### Existing Table Components (Reusable)

| Component | Purpose | Current Usage | Admin Reuse |
|-----------|---------|---------------|-------------|
| `GenericTable.vue` | Base table with sorting, slots | All Tables* components | ManageUser, ManageOntology |
| `TableSearchInput.vue` | Debounced search input | TablesEntities, TablesLogs | Admin search bars |
| `TablePaginationControls.vue` | Cursor pagination UI | All Tables* components | Admin pagination |
| `TableHeaderLabel.vue` | Table header with stats | All Tables* components | Admin table headers |
| `TableDownloadLinkCopyButtons.vue` | Export/link/filter controls | TablesEntities, TablesLogs | Admin exports |

**Assessment:** Admin views should leverage these components unchanged. No duplication needed.

### Backend: R/Plumber Repository Architecture

**Status:** Established repository pattern with parameterized queries

#### Repository Pattern Structure

```
functions/
  user-repository.R         ← User CRUD operations
  entity-repository.R       ← Entity CRUD operations
  ontology-repository.R     ← Ontology data access
  [domain]-repository.R     ← Domain-specific data access

endpoints/
  admin_endpoints.R         ← Admin-specific endpoints
  logging_endpoints.R       ← Log access endpoints
  jobs_endpoints.R          ← Async job endpoints
```

**Key Pattern:** All repositories use `db_execute_query()` and `db_execute_statement()` from db-helpers.R for parameterized SQL, preventing injection attacks.

#### Current Admin Endpoints (Need Modernization)

| Endpoint File | Coverage | Status |
|---------------|----------|--------|
| `admin_endpoints.R` | Ontology updates, OpenAPI spec | Has async job support (mirai) |
| `logging_endpoints.R` | Log retrieval | Works with TablesLogs |
| `authentication_endpoints.R` | User auth | Production-ready |

**Assessment:** Backend architecture is solid. Extension points are clear (add repository methods, add endpoints).

### Async Job System (Established)

**Status:** Production-ready mirai-based async job system

#### Job System Architecture

```
Async Job Flow:
1. POST /api/jobs/{operation}/submit
   → Create job record
   → Launch mirai background task
   → Return 202 Accepted + job_id

2. GET /api/jobs/{job_id}/status (polling)
   → Check mirai task status
   → Return progress/results

Frontend:
- ManageAnnotations.vue already implements polling UI
- Job progress tracking with elapsed time display
- Success/error handling with toast notifications
```

**Key Files:**
- `api/functions/job-manager.R` - Job lifecycle management
- `api/endpoints/jobs_endpoints.R` - Job submission/polling
- `app/src/views/admin/ManageAnnotations.vue` - Reference implementation

**Assessment:** Async pattern is proven. ManageAnnotations shows polling UI works. Reuse for any long-running admin operations.

## Integration Architecture by Admin View

### 1. ManageUser (NEEDS MODERNIZATION)

**Current State:** Basic GenericTable with edit/delete buttons. No search, no pagination, no filtering.

**Target Architecture:**

```
Components:
├── GenericTable (reuse)
├── TableSearchInput (add)
├── TablePaginationControls (add)
├── TableHeaderLabel (add)
└── TableDownloadLinkCopyButtons (add)

Composables:
├── useTableData (add)
├── useTableMethods (add)
├── useToast (existing)
└── useModalControls (existing)

Backend:
├── user-repository.R (extend)
│   ├── user_list_paginated() (NEW)
│   ├── user_search() (NEW)
│   └── user_update() (existing)
└── admin_endpoints.R
    ├── GET /admin/users (NEW - paginated/filtered)
    └── PUT /admin/users/:id (extend existing)
```

**Integration Pattern:** Follow `TablesEntities.vue` pattern exactly. Replace current ManageUser with Table component structure.

**Estimated Effort:** Low - copy structure from TablesEntities, adapt fields

---

### 2. ManageAnnotations (PARTIALLY MODERN)

**Current State:** Has async job UI with polling. Needs minor polish.

**Target Architecture:**

```
Current (Keep):
├── Async job submission UI
├── Progress bar with job polling
├── Status badges (running/complete/error)
└── Elapsed time display

Polish Needed:
├── Better error messaging
├── Job history table (reuse GenericTable)
└── Cancel job functionality (if mirai supports)

Backend (Extend):
├── jobs_endpoints.R
│   └── DELETE /jobs/:id/cancel (NEW - if feasible)
└── admin_endpoints.R
    └── GET /admin/annotation_history (NEW - job audit log)
```

**Integration Pattern:** ManageAnnotations is reference implementation for async jobs. Minor enhancements only.

**Estimated Effort:** Low - already modern, needs polish

---

### 3. ManageOntology (NEEDS SEARCH/PAGINATION)

**Current State:** GenericTable with edit button. No search or pagination.

**Target Architecture:**

```
Components (Same as ManageUser):
├── GenericTable (reuse)
├── TableSearchInput (add)
├── TablePaginationControls (add)
└── TableHeaderLabel (add)

Composables:
├── useTableData (add)
├── useTableMethods (add)
└── useModalControls (existing)

Backend:
├── ontology-repository.R (extend)
│   ├── ontology_list_paginated() (NEW)
│   └── ontology_search() (NEW)
└── ontology_endpoints.R
    └── GET /ontology/list (extend with pagination/filter)
```

**Integration Pattern:** Follow ManageUser modernization pattern. Ontology table is smaller but still benefits from search.

**Estimated Effort:** Low - duplicate ManageUser structure, swap fields

---

### 4. ManageAbout (NEW PATTERN: CMS)

**Current State:** Empty placeholder - only title.

**Target Architecture (CMS Editor):**

```
NEW Pattern: Rich Text Editor + Content Storage
├── Components:
│   ├── RichTextEditor (NEW - wraps library)
│   └── ContentPreview (NEW - markdown/HTML display)
├── Composables:
│   ├── useContentEditor (NEW)
│   │   ├── loadContent()
│   │   ├── saveContent()
│   │   └── publishContent()
│   └── useToast (existing)
├── Backend:
│   ├── content-repository.R (NEW)
│   │   ├── content_get_by_key() (e.g., "about_page")
│   │   ├── content_save_draft()
│   │   └── content_publish()
│   └── admin_endpoints.R
│       ├── GET /admin/content/:key
│       ├── PUT /admin/content/:key/draft
│       └── PUT /admin/content/:key/publish

Database (NEW):
CREATE TABLE cms_content (
  content_key VARCHAR(100) PRIMARY KEY,
  content_html TEXT,
  content_markdown TEXT,
  draft_html TEXT,
  draft_markdown TEXT,
  published_at DATETIME,
  updated_by INT,
  FOREIGN KEY (updated_by) REFERENCES users(user_id)
);
```

**Rich Text Editor Options (2026 Recommendations):**

| Library | Pros | Cons | Recommendation |
|---------|------|------|----------------|
| **VueQuill** | Vue 3 native, TypeScript, lightweight | Fewer features than TinyMCE | **RECOMMENDED for MVP** |
| **TinyMCE** | Feature-rich, enterprise-grade | Heavier, complex setup | Consider for v2 if advanced features needed |
| **Tiptap** | Modern, extensible, ProseMirror-based | More low-level API | Overkill for basic CMS |

**Integration Pattern:** New pattern. Create `useContentEditor` composable, integrate VueQuill, store in new `cms_content` table.

**Estimated Effort:** Medium - new pattern, new database table, editor integration

**Sources:**
- [VueQuill Documentation](https://vueup.github.io/vue-quill/)
- [TinyMCE Vue Integration](https://www.tiny.cloud/solutions/wysiwyg-vue-rich-text-editor/)
- [Best WYSIWYG Editors 2026](https://www.vuescript.com/best-wysiwyg-rich-text-editor/)

---

### 5. AdminStatistics (NEW PATTERN: CHARTS)

**Current State:** Basic statistics display with date filters. No charts.

**Target Architecture (Dashboard Charts):**

```
NEW Pattern: Chart Composables + Dashboard Layout
├── Components:
│   ├── ChartCard (NEW - wrapper for chart libraries)
│   ├── StatisticCard (existing - polish current cards)
│   └── DateRangeFilter (existing - keep current form)
├── Composables:
│   ├── useChartData (NEW)
│   │   ├── loadStatistics()
│   │   ├── transformForChart()
│   │   └── exportChartImage()
│   └── useToast (existing)
├── Backend:
│   └── admin_endpoints.R (extend)
│       ├── GET /admin/statistics/entities (enhance)
│       ├── GET /admin/statistics/reviews (enhance)
│       └── GET /admin/statistics/time_series (NEW)

Chart Library Integration:
└── ApexCharts (vue-apexcharts)
    ├── Line charts (entities over time)
    ├── Bar charts (reviews by user)
    └── Donut charts (entity categories)
```

**Chart Library Options (2026 Recommendations):**

| Library | Pros | Cons | Recommendation |
|---------|------|------|----------------|
| **ApexCharts** | Easy integration, responsive, 100+ samples | Not as feature-rich as ECharts | **RECOMMENDED for MVP** |
| **ECharts** | 20+ chart types, powerful | Steeper learning curve | Consider for advanced dashboards |
| **Unovis** | Modern, modular | Newer, smaller community | Future consideration |

**Integration Pattern:** Create `useChartData` composable, integrate ApexCharts, add chart cards to AdminStatistics.

**Estimated Effort:** Medium - new pattern, chart library integration, data transformation logic

**Sources:**
- [Best Chart Libraries Vue 2026](https://weavelinx.com/best-chart-libraries-for-vue-projects-in-2026/)
- [ApexCharts for Vue](https://www.luzmo.com/blog/vue-chart-libraries)
- [JavaScript Charting Libraries 2026](https://embeddable.com/blog/javascript-charting-libraries)

---

### 6. ViewLogs (ALREADY MODERN)

**Current State:** Uses `TablesLogs.vue` with full search/pagination/filtering.

**Target Architecture:**

```
Status: NO CHANGES NEEDED

Current Implementation:
├── TablesLogs.vue (complete)
│   ├── GenericTable
│   ├── TableSearchInput
│   ├── TablePaginationControls
│   └── TableDownloadLinkCopyButtons
├── useTableData
├── useTableMethods
└── Backend: logging_endpoints.R (complete)
```

**Integration Pattern:** ViewLogs is reference implementation. Already follows all patterns.

**Estimated Effort:** None - already complete

---

## New Components Needed

### Required New Components

| Component | Purpose | Used In |
|-----------|---------|---------|
| `ChartCard.vue` | Wrapper for chart library with title/loading/error | AdminStatistics |
| `RichTextEditor.vue` | Wrapper for VueQuill with toolbar config | ManageAbout |
| `ContentPreview.vue` | Markdown/HTML preview pane | ManageAbout |

### Optional Enhancement Components

| Component | Purpose | Used In |
|-----------|---------|---------|
| `JobHistoryTable.vue` | Reusable async job history | ManageAnnotations |
| `DateRangePickerCard.vue` | Reusable date filter card | AdminStatistics (polish existing) |

## New Composables Needed

### Required New Composables

```typescript
// composables/useChartData.ts
export default function useChartData(options: {
  endpoint: string;
  transformFn?: (data: any) => ChartData;
}) {
  const chartData = ref<ChartData | null>(null);
  const loading = ref(false);
  const error = ref<Error | null>(null);

  const loadChartData = async (params: Record<string, any>) => {
    // Fetch from endpoint, transform, update chartData
  };

  const exportChart = (format: 'png' | 'svg') => {
    // Export chart image
  };

  return {
    chartData,
    loading,
    error,
    loadChartData,
    exportChart,
  };
}

// composables/useContentEditor.ts
export default function useContentEditor(contentKey: string) {
  const content = ref<string>('');
  const draft = ref<string>('');
  const saving = ref(false);
  const publishing = ref(false);

  const loadContent = async () => {
    // Fetch from /admin/content/:key
  };

  const saveDraft = async () => {
    // PUT /admin/content/:key/draft
  };

  const publishContent = async () => {
    // PUT /admin/content/:key/publish
  };

  return {
    content,
    draft,
    saving,
    publishing,
    loadContent,
    saveDraft,
    publishContent,
  };
}
```

## Backend Extensions Needed

### Repository Layer Extensions

```r
# functions/user-repository.R (extend)
user_list_paginated <- function(page_after = 0, page_size = 10, sort = "+user_id", filter = NULL) {
  # Use existing db_execute_query pattern
  # Return paginated user list
}

user_search <- function(search_term, page_size = 10) {
  # Search users by name, email, role
}

# functions/ontology-repository.R (extend)
ontology_list_paginated <- function(page_after = 0, page_size = 10, sort = "+vario_id", filter = NULL) {
  # Paginated ontology list
}

ontology_search <- function(search_term, page_size = 10) {
  # Search ontology by vario_id, vario_name
}

# functions/content-repository.R (NEW)
content_get_by_key <- function(content_key) {
  sql <- "SELECT * FROM cms_content WHERE content_key = ?"
  db_execute_query(sql, list(content_key))
}

content_save_draft <- function(content_key, draft_html, draft_markdown, updated_by) {
  sql <- "INSERT INTO cms_content (content_key, draft_html, draft_markdown, updated_by)
          VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE draft_html = ?, draft_markdown = ?, updated_by = ?"
  db_execute_statement(sql, list(content_key, draft_html, draft_markdown, updated_by, draft_html, draft_markdown, updated_by))
}

content_publish <- function(content_key) {
  sql <- "UPDATE cms_content
          SET content_html = draft_html, content_markdown = draft_markdown,
              published_at = NOW()
          WHERE content_key = ?"
  db_execute_statement(sql, list(content_key))
}

# functions/statistics-repository.R (NEW)
statistics_time_series <- function(start_date, end_date, metric) {
  # Return time series data for charts
  # Metrics: entity_count, review_count, user_activity
}

statistics_entity_breakdown <- function(start_date, end_date) {
  # Return entity counts by category for charts
}
```

### Endpoint Extensions

```r
# endpoints/admin_endpoints.R (extend)

# User management endpoints
#* @get /admin/users
#* Paginated/filtered user list
#* @param page_after:int
#* @param page_size:int
#* @param sort:string
#* @param filter:string

# Content management endpoints
#* @get /admin/content/:key
#* Get CMS content by key

#* @put /admin/content/:key/draft
#* Save content draft

#* @put /admin/content/:key/publish
#* Publish content

# Statistics endpoints
#* @get /admin/statistics/time_series
#* Time series data for charts
#* @param start_date:string
#* @param end_date:string
#* @param metric:string
```

## Database Schema Extensions

### CMS Content Table (NEW)

```sql
CREATE TABLE cms_content (
  content_key VARCHAR(100) PRIMARY KEY,
  content_html TEXT,
  content_markdown TEXT,
  draft_html TEXT,
  draft_markdown TEXT,
  published_at DATETIME,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by INT,
  FOREIGN KEY (updated_by) REFERENCES users(user_id),
  INDEX idx_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Initial content keys
INSERT INTO cms_content (content_key, content_html, content_markdown, updated_by)
VALUES
  ('about_page', '<p>Default about content</p>', '# About\nDefault about content', 1),
  ('citation_policy', '<p>Citation policy</p>', '# Citation\nCitation policy', 1);
```

### Job History Enhancements (OPTIONAL)

```sql
-- If job history doesn't track user, add column
ALTER TABLE job_queue ADD COLUMN created_by INT;
ALTER TABLE job_queue ADD FOREIGN KEY (created_by) REFERENCES users(user_id);

-- Add index for admin job history queries
CREATE INDEX idx_job_created_at ON job_queue(created_at);
```

## Recommended Build Order

**Phase structure optimized for dependency minimization and early wins.**

### Phase 1: Foundation (Modernize Tables)
**Goal:** Apply existing patterns to admin tables. Quick wins, no new patterns.

1. **ManageUser** - Add search/pagination using TablesEntities pattern
2. **ManageOntology** - Add search/pagination using TablesEntities pattern

**Why First:**
- No new patterns required
- Establishes consistency across admin views
- Backend extensions are straightforward (add pagination to repositories)
- Demonstrates pattern reuse to team

**Deliverables:**
- Extended `user-repository.R` with pagination/search
- Extended `ontology-repository.R` with pagination/search
- Modernized ManageUser.vue and ManageOntology.vue
- Backend endpoints for paginated user/ontology lists

---

### Phase 2: Charts (AdminStatistics)
**Goal:** Introduce chart pattern before CMS complexity.

3. **AdminStatistics** - Add charts with ApexCharts

**Why Second:**
- New pattern but simpler than CMS (read-only, no editor)
- Visual impact for stakeholders
- Chart composable will be reusable elsewhere
- No new database tables needed (uses existing statistics endpoints)

**Deliverables:**
- `useChartData` composable
- `ChartCard` component
- ApexCharts integration
- Enhanced AdminStatistics.vue with line/bar/donut charts
- Backend time series endpoints

---

### Phase 3: CMS (ManageAbout)
**Goal:** Most complex new pattern - editor + storage.

4. **ManageAbout** - Rich text editor with draft/publish workflow

**Why Third:**
- Most complex (new database table, editor library, dual storage)
- Benefits from team experience with previous phases
- Requires content strategy decisions (what goes in CMS)
- Less critical path than user/ontology management

**Deliverables:**
- `cms_content` database table
- `content-repository.R`
- `useContentEditor` composable
- `RichTextEditor` and `ContentPreview` components
- VueQuill integration
- ManageAbout.vue with editor UI

---

### Phase 4: Polish (ManageAnnotations)
**Goal:** Refine existing async job UI.

5. **ManageAnnotations** - Add job history, better error handling

**Why Last:**
- Already mostly modern
- Enhancements not critical
- Good target for "nice to have" features
- Can leverage patterns from earlier phases

**Deliverables:**
- Job history table (reuses GenericTable pattern from Phase 1)
- Enhanced error messaging
- Optional: Job cancellation (if mirai supports)

---

### ViewLogs: No Work Needed
ViewLogs is already complete and modern. Leave as-is.

---

## Integration Risk Assessment

### Low Risk (Reuse Existing Patterns)

| Area | Risk Level | Mitigation |
|------|------------|-----------|
| ManageUser modernization | LOW | Copy TablesEntities pattern, swap data source |
| ManageOntology modernization | LOW | Same as ManageUser |
| ViewLogs | NONE | Already complete |
| ManageAnnotations polish | LOW | Already 80% done |

### Medium Risk (New Patterns, Known Solutions)

| Area | Risk Level | Mitigation |
|------|------------|-----------|
| ApexCharts integration | MEDIUM | Well-documented library, Vue 3 support confirmed |
| VueQuill integration | MEDIUM | Official Vue 3 package, TypeScript support |
| Chart composable design | MEDIUM | Similar to useTableData, proven pattern |

### Potential Issues

#### 1. Chart Library Performance
**Issue:** Large datasets may cause chart rendering delays.
**Mitigation:**
- Aggregate data server-side (don't send 10K points)
- Use chart library's built-in data reduction
- Add loading states

#### 2. Rich Text Editor Security
**Issue:** XSS vulnerabilities from HTML content.
**Mitigation:**
- Store both HTML and Markdown
- Sanitize HTML server-side before display
- Use VueQuill's built-in sanitization
- Consider markdown-only storage with HTML rendering

#### 3. CMS Content Versioning
**Issue:** No version history in proposed schema.
**Mitigation:**
- Phase 1: Draft/publish workflow only
- Phase 2: Add `cms_content_history` table if needed
- Use `updated_at` timestamp for simple audit trail

#### 4. Database Migration Coordination
**Issue:** New `cms_content` table needs migration script.
**Mitigation:**
- Create migration script in `api/migrations/`
- Include rollback script
- Test on dev environment first

## Architecture Decision Records

### ADR-1: Reuse Existing Table Patterns
**Decision:** Use `useTableData` + `useTableMethods` + `GenericTable` for admin tables.
**Rationale:** Proven pattern, reduces code duplication, maintains consistency.
**Alternatives Considered:** Build custom admin table components (rejected - unnecessary duplication).

### ADR-2: ApexCharts for Dashboard
**Decision:** Use ApexCharts via vue-apexcharts for AdminStatistics.
**Rationale:** Easy Vue 3 integration, responsive, sufficient features for admin dashboard, lighter than ECharts.
**Alternatives Considered:** ECharts (overkill), Chart.js (less Vue-friendly), Unovis (too new).

### ADR-3: VueQuill for Rich Text Editor
**Decision:** Use VueQuill for ManageAbout CMS editor.
**Rationale:** Native Vue 3 support, TypeScript, lightweight, sufficient for basic CMS needs.
**Alternatives Considered:** TinyMCE (too heavy for MVP), Tiptap (too low-level).

### ADR-4: Draft/Publish Workflow for CMS
**Decision:** Implement draft/publish workflow (not direct editing).
**Rationale:** Prevents accidental publication, allows review before going live, standard CMS pattern.
**Alternatives Considered:** Direct editing (rejected - too risky for public-facing content).

### ADR-5: Extend Existing Repositories, Don't Replace
**Decision:** Extend user-repository.R and ontology-repository.R with pagination methods.
**Rationale:** Maintains existing patterns, backward compatible, minimal disruption.
**Alternatives Considered:** Create admin-specific repositories (rejected - unnecessary indirection).

## Technology Stack Summary

### Frontend Stack (No Changes to Core)

| Category | Technology | Version | Usage |
|----------|-----------|---------|-------|
| Framework | Vue 3 | 3.x | Existing |
| Component Library | Bootstrap Vue Next | 0.x | Existing |
| State Management | Pinia | 2.x | Existing |
| HTTP Client | Axios | 1.x | Existing |
| **NEW: Charts** | **vue-apexcharts** | **Latest** | **AdminStatistics** |
| **NEW: Rich Text** | **@vueup/vue-quill** | **Latest** | **ManageAbout** |

### Backend Stack (No Changes)

| Category | Technology | Usage |
|----------|-----------|-------|
| API Framework | R Plumber | Existing |
| Database | MariaDB | Existing |
| Connection Pool | pool (R package) | Existing |
| Async Jobs | mirai | Existing |
| Query Builder | dplyr + parameterized SQL | Existing |

### New Database Tables

- `cms_content` - CMS content storage (draft/publish workflow)

## Implementation Guidelines

### 1. Follow Existing Patterns First
Before creating new patterns, check if existing composables/components can be reused:
- Table with search/pagination → Use `TablesEntities` pattern
- Async operation → Use `ManageAnnotations` polling pattern
- Form with validation → Use `useEntityForm` pattern
- Toast notifications → Use `useToast`

### 2. Maintain Consistency
- File naming: `ManageX.vue` for admin management views
- Composable naming: `useXData` for data fetching, `useXMethods` for actions
- Endpoint naming: `/admin/X` for admin-only operations
- Repository naming: `x-repository.R` for data access

### 3. Security Considerations
- All admin endpoints require `require_role(req, res, "Administrator")`
- CMS content must be sanitized (use VueQuill's sanitization + server-side validation)
- Excel exports use existing `useExcelExport` pattern (validated, uses format parameter)
- User management endpoints use existing auth middleware

### 4. Testing Strategy
- **Unit tests:** Test new composables (`useChartData`, `useContentEditor`)
- **Component tests:** Test new components (`ChartCard`, `RichTextEditor`)
- **Integration tests:** Test admin endpoints with pagination/filtering
- **E2E tests:** Test admin workflows (edit user → save → verify)

### 5. Progressive Enhancement
Each phase should be deployable independently:
- **Phase 1:** ManageUser/ManageOntology work without Phase 2 charts
- **Phase 2:** Charts work without Phase 3 CMS
- **Phase 3:** CMS works independently
- **Phase 4:** Enhancements are optional

## Success Criteria

Admin panel modernization is complete when:

- [ ] ManageUser and ManageOntology use GenericTable pattern with search/pagination
- [ ] AdminStatistics displays charts (line, bar, donut) with ApexCharts
- [ ] ManageAbout has rich text editor with draft/publish workflow
- [ ] ManageAnnotations has job history table and enhanced error handling
- [ ] All admin views reuse existing composables (useTableData, useTableMethods, useToast)
- [ ] All admin endpoints follow repository pattern with parameterized queries
- [ ] CMS content table exists with draft/publish columns
- [ ] Chart composable (`useChartData`) is reusable for future charts
- [ ] No new global state (all state managed via composables)
- [ ] All admin operations show toast notifications (success/error)

## Sources

**Vue 3 Architecture Patterns:**
- [Custom Composables in Vue 3: Clean Code Through Reusability](https://medium.com/@vasanthancomrads/custom-composables-in-vue-3-clean-code-through-reusability-part-3-d9011dfd1745)
- [Vue.js Official Composables Guide](https://vuejs.org/guide/reusability/composables.html)
- [Design Patterns with Composition API in Vue 3](https://medium.com/@davisaac8/design-patterns-and-best-practices-with-the-composition-api-in-vue-3-77ba95cb4d63)
- [Vue Composables Design Patterns](https://dev.to/jacobandrewsky/good-practices-and-design-patterns-for-vue-composables-24lk)

**Chart Libraries:**
- [Best Chart Libraries for Vue 2026](https://weavelinx.com/best-chart-libraries-for-vue-projects-in-2026/)
- [Vue Chart Libraries Definitive Guide](https://www.luzmo.com/blog/vue-chart-libraries)
- [8 Best Chart Libraries for Vue](https://blog.logrocket.com/8-best-chart-libraries-vue/)
- [JavaScript Charting Libraries 2026](https://embeddable.com/blog/javascript-charting-libraries)

**Rich Text Editors:**
- [VueQuill Official Documentation](https://vueup.github.io/vue-quill/)
- [TinyMCE Vue Rich Text Editor](https://www.tiny.cloud/solutions/wysiwyg-vue-rich-text-editor/)
- [Best WYSIWYG Rich Text Editors 2026](https://www.vuescript.com/best-wysiwyg-rich-text-editor/)
- [Building WYSIWYG Editors with Vue and TinyMCE](https://vueschool.io/articles/news/building-advanced-wysiwyg-editors-with-vue-and-tinymce-a-complete-guide/)

**Confidence Assessment:** HIGH - Architecture analysis based on existing codebase patterns, established Vue 3 best practices, and proven library integrations.
