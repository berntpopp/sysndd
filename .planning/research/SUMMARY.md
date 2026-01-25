# Project Research Summary

**Project:** SysNDD v6.0 Admin Panel Modernization
**Domain:** Scientific database administration (neurodevelopmental disorders research)
**Researched:** 2026-01-25
**Confidence:** HIGH

## Executive Summary

Admin panel modernization in scientific databases requires **extending existing patterns rather than introducing new frameworks**. SysNDD's v5.0 architecture (Vue 3 + Bootstrap-Vue-Next + R/Plumber repositories) provides proven patterns that need application to admin domains, not replacement. The research reveals two critical insights: (1) TablesEntities and ManageAnnotations already demonstrate modern patterns (URL state sync, async job polling) that should be replicated across all admin views, and (2) only two new libraries are needed—Chart.js for statistics visualization and TipTap for CMS editing—keeping bundle impact minimal (+130KB gzipped).

The recommended approach prioritizes **pattern consistency over feature richness**. Phase 1 should establish foundation by modernizing ManageUser and ManageOntology using existing TablesEntities patterns (search, pagination, URL sync). Phase 2 adds charts to AdminStatistics with scientific context (not just pretty visuals). Phase 3 introduces CMS editing for ManageAbout with reusable composables. Phase 4 polishes ManageAnnotations' already-excellent async job UI. This ordering mitigates the highest-risk pitfall: diverging patterns across admin views that create fragmented UX and maintenance burden.

The key risk is **inconsistency between admin views**—some with URL state sync, others without; some using composables, others reimplementing logic. Prevention requires upfront pattern documentation, admin table scaffolding that includes URL sync by default, and PR checklists enforcing reuse of existing composables (useTableData, useTableMethods, useModalControls). With disciplined pattern adherence, admin panel modernization is low-risk extension work, not architectural transformation.

## Key Findings

### Recommended Stack

**Minimal additions to validated v5.0 baseline.** The project already has Vue 3.5.25, TypeScript 5.9.3, Bootstrap 5.3.8, Bootstrap-Vue-Next 0.42.0—all shipped in production 2026-01-25. Admin panel needs only targeted library additions, not framework changes.

**Core technologies (existing, keep unchanged):**
- Vue 3.5.25 + Composition API — Established pattern with 13 composables, proven in TablesEntities
- Bootstrap-Vue-Next 0.42.0 — Provides all needed components (BCard, BTable, BButton), no gaps identified
- Pinia 2.0.14 — Available but optional; composables sufficient for view-level state
- VeeValidate 4.15.1 — Form validation already integrated
- VueUse 14.1.0 — URL state sync via useUrlSearchParams (TablesEntities pattern)
- R/Plumber + MariaDB — Backend architecture unchanged

**New additions (admin-specific):**
- Chart.js 4.5.1 + vue-chartjs 5.3.3 — Dashboard charts for AdminStatistics (~50KB gzipped). Chosen over ApexCharts for simpler API, better Bootstrap integration, tree-shakable imports. Admin needs basic line/bar/doughnut charts, not real-time streaming.
- TipTap 3.15.3 (vue-3 + starter-kit) — Rich text editor for ManageAbout CMS (~80KB gzipped). Chosen over Quill/TinyMCE for TypeScript-native design, headless architecture (apply Bootstrap classes directly), Composition API compatibility. ManageAbout needs WYSIWYG for prose content, not document authoring features.

**Explicitly rejected:**
- Additional UI libraries (PrimeVue, Element Plus) — Bootstrap-Vue-Next 0.42.0 has all components needed
- ApexCharts/ECharts — Overkill for basic admin statistics (AdminStatistics needs aggregated metrics, not real-time streaming)
- Quill/TinyMCE — Heavier alternatives without advantage for simple CMS editing
- Additional table libraries (ag-grid, TanStack Table) — TablesEntities pattern already implements server-side pagination, sorting, filtering, export

**Version compatibility:** All new libraries verified compatible with Vue 3.5.25, TypeScript 5.9.3, Vite 7.3.1. Published within last 3 months (as of 2026-01-25), actively maintained.

### Expected Features

Research identifies clear feature tiers based on 2026 admin panel standards and scientific database requirements.

**Must have (table stakes):**
- Bulk selection & actions — Standard since 2015; admins expect checkboxes + "Select All" + contextual action bar. Existing: ManageUser has individual actions only.
- Advanced filtering — Essential for large datasets; needs date ranges, multi-select filters, saved filter sets. Existing: ViewLogs has basic filtering; needs expansion.
- Search across tables — Users expect global + per-column search. Existing: GenericTable supports sorting but not search.
- Pagination controls — Standard for tables >20 rows. Existing: ViewLogs has pagination; ManageUser lacks it.
- Export to CSV/Excel — Admins expect data export for analysis. Common in scientific databases.
- Audit logs — Required for scientific data governance; track who changed what. Existing: ViewLogs displays logs but needs user action tracking.
- Role-based permissions — UI must adapt to roles (Curator, Reviewer, Admin). Existing: Roles exist but UI doesn't adapt.

**Should have (differentiators):**
- Real-time statistics dashboard — Visual KPIs help admins spot trends. Existing: AdminStatistics is basic text; upgrade to charts.
- Inline editing — Edit cells directly without modal; saves clicks. High complexity but high productivity gain for frequent edits.
- Saved filters & views — Admins revisit same combinations ("My pending approvals"). Reduces repetitive work.
- Smart notifications — Alert to important events (new user signup, failed jobs). Existing: Deprecated entities check in ManageAnnotations is good pattern to expand.
- Data validation warnings — Highlight quality issues (duplicate ORCID, missing fields). Proactive quality control.
- Batch import/upload — CSV upload for bulk create/update. Standard in scientific databases.

**Defer to v2+ (anti-features or premature):**
- Over-engineered CMS — ManageAbout is single page; full-featured CMS with versioning/media libraries is overkill. Use simple rich text editor.
- Complex permission UI — Scientific databases have 3-5 roles max; avoid 50+ granular checkboxes. Use predefined roles.
- Real-time collaboration — Google Docs-style editing is complex, rarely needed. Use optimistic locking instead.
- Custom query builder — SQL-like UI for non-technical users is usability trap. Provide pre-built filters.
- Mobile app — Native iOS/Android unnecessary; responsive web sufficient. Admins rarely curate on phones.
- Gamification — Leaderboards/badges inappropriate for scientific curation. Show contribution stats if needed, but avoid game mechanics.

**Feature dependencies identified:**
- Bulk actions → Requires enhanced GenericTable with checkbox column + selection framework
- Inline editing → Requires bulk selection + validation rules
- Charts → Independent of other features, can be implemented standalone
- CMS → Independent, requires new content-repository.R and cms_content table
- Advanced filtering → Requires filter builder component + saved filter storage

### Architecture Approach

**Extend composable-driven architecture with minimal new patterns.** SysNDD's frontend uses Vue 3 Composition API with 13 reusable composables (useTableData, useTableMethods, useModalControls, etc.). Backend uses R/Plumber repository pattern with parameterized queries. Admin panel should replicate proven patterns across new domains (users, ontology, logs, statistics) rather than introduce new paradigms.

**Major components and integration strategy:**

1. **Table Management (ManageUser, ManageOntology, ViewLogs)** — Reuse existing TablesEntities pattern unchanged. TablesEntities demonstrates sophisticated URL state sync (history.replaceState), module-level caching to prevent duplicate API calls, debounced search (500ms), server-side pagination. Copy this structure to admin tables; replace API endpoints and field definitions. Backend extends existing repositories (user-repository.R, ontology-repository.R) with pagination/search methods following db_execute_query pattern.

2. **Statistics Dashboard (AdminStatistics)** — New pattern: chart composables + dashboard layout. Create useChartData composable for data fetching/transformation. Integrate Chart.js via vue-chartjs with ChartCard wrapper component. Keep existing date range filter. Backend adds time series endpoints to admin_endpoints.R (reuse existing statistics-repository.R patterns).

3. **Content Management (ManageAbout)** — New pattern: rich text editor + content storage. Create useContentEditor composable for load/save/publish workflow. Integrate TipTap with EditorContent component styled using Bootstrap form-control classes. New database table: cms_content with draft/publish columns. Backend adds content-repository.R following established parameterized query pattern.

4. **Async Jobs (ManageAnnotations)** — Existing pattern is reference implementation. ManageAnnotations already demonstrates proper polling lifecycle (cleanup in beforeUnmount), elapsed time display, progress tracking, error handling. Extract to useAsyncJob composable for reuse. Minor enhancements: job history table (reuse GenericTable), cancel functionality (if mirai supports).

5. **Logging (ViewLogs)** — Already complete and modern. Uses TablesLogs.vue with full search/pagination/filtering. No architectural changes needed.

**Critical architectural decisions:**
- ADR-1: Reuse existing table patterns (not build custom admin components) — reduces duplication, maintains consistency
- ADR-2: Chart.js for dashboard (not ApexCharts/ECharts) — sufficient features, lighter weight for basic admin charts
- ADR-3: TipTap for rich text (not Quill/TinyMCE) — TypeScript-native, Composition API compatible, headless styling
- ADR-4: Draft/publish CMS workflow (not direct editing) — prevents accidental publication, standard CMS pattern
- ADR-5: Extend existing repositories (not create admin-specific) — backward compatible, minimal disruption

**Technology integration summary:**
- Frontend: Add vue-chartjs + @tiptap packages (~130KB gzipped total)
- Backend: Add content-repository.R + statistics time series methods
- Database: Add cms_content table with draft_html, content_html, published_at columns
- No changes to core stack (Vue, Bootstrap, Pinia, R/Plumber)

### Critical Pitfalls

Research identifies 15 pitfalls from admin panel modernization patterns, WebSearch analysis, and existing codebase inspection. Top 5 for roadmap planning:

1. **State Management Inconsistency Across Admin Views** — Each admin view implements its own pattern (some with URL sync like TablesEntities, others without like ManageUser). Results in non-bookmarkable filter states, lost work on navigation, inconsistent back-button behavior. **Prevention:** Extract TablesEntities URL sync to useAdminTable composable before Phase 1; establish PR checklist requiring URL state sync for all paginated tables; document canonical pattern in architecture guide. **Phase impact:** Phase 1 (Foundation).

2. **Bulk Actions with Cross-Page Selection State** — User selects items on page 1, navigates to page 2, selects more, clicks "Bulk Approve"—system acts only on current page or crashes. Happens when selection stored as array indices not IDs, or state cleared on pagination. **Prevention:** Store selection as Set<number> (IDs not indices); persist across pagination using module-level state; add visual badge "5 items selected across multiple pages"; confirmation dialog lists all selections. Real scenario in SysNDD: Admin filters to 50 unapproved users across 5 pages, needs to approve subset spanning multiple pages. **Phase impact:** Phase 2 (ManageUser bulk actions).

3. **Async Job Polling Without Proper Cleanup** — Long-running jobs start polling intervals that continue after component unmounts (memory leak), fire multiple times on remount (duplicate requests), don't handle errors. ManageAnnotations demonstrates CORRECT pattern (cleanup in beforeUnmount, lines 432-435) but new async features may copy pattern incompletely. **Prevention:** Extract to useAsyncJob composable with mandatory cleanup; template pattern pairing mounted() with beforeUnmount(); implement exponential backoff; set maximum poll duration (5 min). **Phase impact:** Phase 3 (ManageAnnotations improvements).

4. **Chart Data Without Scientific Context** — Admin dashboard shows impressive charts but missing statistical significance indicators, historical baselines, appropriate chart types (3D pie charts for scientific data), accessibility (colorblind-safe colors), export to publication formats. Scientific databases differ from business dashboards—need context not just visuals. **Prevention:** Provide context for every metric ("246 entities, ↑12% vs last month"); use appropriate chart types (time series → line, proportions <5 → horizontal bar); follow ColorBrewer2 palettes; add PNG/SVG export; include "What this means" text below charts. **Phase impact:** Phase 4 (AdminStatistics charts).

5. **Diverging from Established Composable Patterns** — SysNDD has 13 composables with established patterns. New admin features risk introducing competing patterns (reimplementing modal logic instead of using useModalControls, new filter state management instead of useTableData). Evidence: ManageUser partially uses composables but reimplements modal logic (lines 413-437). **Prevention:** Audit all composables before implementing; PR requirement "Why not use existing composable?"; composable discovery documentation; pair programming on first admin view. **Phase impact:** Phase 1 (Foundation)—prevent before implementing features.

**Moderate pitfalls (cause delays):**
- Non-reusable CMS implementation — Build useContentEditor composable, test with 2+ content types
- Modal state management hell — Extract to useModalControls, establish modal lifecycle pattern
- Pagination without URL sync — Make URL state sync default in admin table scaffold
- Role-based feature gating inconsistency — Create usePermissions composable, backend as source of truth

**Minor pitfalls (cause annoyance):**
- Search/filter without loading state — Set isBusy flag, cancel in-flight requests
- Inconsistent empty states — Standardize in GenericTable with contextual messages
- Export without progress — Disable button during download, show progress toast
- Scientific notation sort comparison — Add sortCompare function for columns with scientific notation

## Implications for Roadmap

Based on combined research, recommended phase structure prioritizes **pattern establishment before feature richness** and **reuse over reinvention**.

### Phase 1: Table Foundation (ManageUser & ManageOntology Modernization)
**Rationale:** Apply existing TablesEntities pattern before building new features. Establishes consistency baseline and validates pattern reusability. No new libraries needed—pure pattern application.

**Delivers:**
- ManageUser with search, pagination, filtering, URL state sync
- ManageOntology with search, pagination, filtering, URL state sync
- Extended user-repository.R and ontology-repository.R with pagination/search methods
- Extracted useAdminTable composable for pattern reuse
- Pattern documentation and PR checklist

**Addresses features:**
- Bulk selection framework (checkbox column, select all, action bar)
- Advanced filtering (date ranges, multi-select dropdowns)
- Search across tables (global + per-column)
- Pagination controls (page size selector, jump to page)
- Export to CSV (reuse useExcelExport pattern)

**Avoids pitfalls:**
- State management inconsistency (establishes canonical pattern upfront)
- Diverging composable patterns (forces audit and reuse)
- Pagination without URL sync (makes URL sync default)

**Research flag:** Standard patterns well-documented. Skip phase-specific research.

---

### Phase 2: User Management Workflows (Bulk Actions)
**Rationale:** Build on Phase 1 foundation with complex interaction pattern. Bulk actions depend on robust table foundation. Establishes multi-page selection pattern before other views copy it.

**Delivers:**
- Bulk approve/delete/role assignment for users
- Cross-page selection state (Set-based IDs, persistent badge)
- User approval workflow ("Pending Approvals" saved view)
- Role management dropdown with validation
- Confirmation dialogs with action summaries

**Addresses features:**
- Bulk selection & actions (table stakes feature)
- Role-based permissions UI (dropdown instead of text input)
- Smart notifications (approval success/error toasts)
- Saved filters ("My pending approvals" view)

**Avoids pitfalls:**
- Bulk actions cross-page selection loss (Set-based storage, visual feedback)
- Role-based feature gating inconsistency (create usePermissions composable)
- Modal state management hell (establish modal lifecycle pattern)

**Research flag:** Bulk action UX is complex. Consider `/gsd:research-phase` for interaction patterns if team unfamiliar with multi-page selection.

---

### Phase 3: Statistics Visualization (AdminStatistics Charts)
**Rationale:** Introduce first new pattern (charts) before CMS complexity. Visual impact for stakeholders. Chart composable will be reusable for future dashboards. Independent of other admin features—no blocking dependencies.

**Delivers:**
- Chart.js integration with vue-chartjs
- useChartData composable (data fetching, transformation, export)
- ChartCard wrapper component with loading/error states
- Line charts (entities over time), bar charts (user contributions), doughnut charts (entity status breakdown)
- Chart export to PNG/SVG
- Statistics time series backend endpoints

**Addresses features:**
- Real-time statistics dashboard (differentiator)
- Data visualization with scientific context (baselines, comparisons)
- Export charts (publication-ready formats)

**Avoids pitfalls:**
- Chart data without scientific context (require context for every metric, appropriate chart types)
- Scientific notation sort comparison (add sortCompare for FDR columns)
- Inconsistent empty states (standardize chart loading/error/empty)

**Uses stack:**
- Chart.js 4.5.1 + vue-chartjs 5.3.3 (new)
- Bootstrap grid for responsive chart layout
- Existing date range filter (keep current form)

**Research flag:** Chart.js well-documented. Skip research unless team needs advanced features.

---

### Phase 4: Content Management System (ManageAbout Editor)
**Rationale:** Most complex new pattern—rich text editor + draft/publish workflow + new database table. Benefits from team experience with Phases 1-3. Less critical path than user/ontology management.

**Delivers:**
- TipTap rich text editor integration
- useContentEditor composable (load, save draft, publish)
- RichTextEditor and ContentPreview components
- cms_content database table with draft/publish columns
- ManageAbout UI with editor, preview pane, save/publish buttons
- content-repository.R following parameterized query pattern

**Addresses features:**
- CMS editing for About page (currently stub-only)
- Preview mode (markdown/HTML display)
- Draft/publish workflow (prevents accidental publication)
- Field-level help text (tooltips for complex fields)

**Avoids pitfalls:**
- Non-reusable CMS implementation (build generic useContentEditor, test with 2 content types)
- Rich text editor security (sanitize HTML server-side, store markdown + HTML)
- CMS content versioning (Phase 1: draft/publish only; Phase 2: add history if needed)

**Uses stack:**
- TipTap 3.15.3 (@tiptap/vue-3 + starter-kit) (new)
- Bootstrap form-control styling for editor
- VeeValidate 4.15.1 for form validation

**Research flag:** TipTap Vue 3 integration is straightforward. Consider `/gsd:research-phase` only if team needs advanced editor features (tables, images, custom extensions).

---

### Phase 5: Async Job Polish (ManageAnnotations Enhancements)
**Rationale:** Refine existing excellent async job UI. Enhancements not critical. Good target for "nice to have" features leveraging patterns from earlier phases.

**Delivers:**
- Extracted useAsyncJob composable (reusable for future long-running operations)
- Job history table (reuses GenericTable from Phase 1)
- Enhanced error messaging (specific failure reasons)
- Optional: Job cancellation (if mirai supports AbortController pattern)
- Job status dashboard (aggregate view of recent jobs)

**Addresses features:**
- Activity feed (recent changes across entities)
- Smart notifications (failed job alerts)
- Audit logs (job tracking integrated with ViewLogs)

**Avoids pitfalls:**
- Async job polling without cleanup (extract to composable with mandatory lifecycle)
- Inconsistent error messages (standardize job failure display)
- Ignoring existing async pattern (make ManageAnnotations pattern reusable)

**Implements architecture:**
- Composable extraction from existing code (no new libraries)
- GenericTable pattern reuse (job history as table)

**Research flag:** Standard pattern. Skip research.

---

### Phase 6: Logging & Analytics (ViewLogs Feature Parity)
**Rationale:** ViewLogs already modern but needs export and advanced filtering. Low-risk polish phase. Demonstrates pattern consistency across all admin views.

**Delivers:**
- User filter (filter logs by specific user)
- Action type filter (multi-select: CREATE, UPDATE, DELETE)
- Export logs to CSV (reuse useExcelExport)
- Log detail modal (expand single log entry)
- Integration with job history (link logs to async jobs)

**Addresses features:**
- Audit logs (complete user action tracking)
- Export data (logs to CSV for compliance reporting)
- Advanced filtering (all admin tables have consistent filter UX)

**Avoids pitfalls:**
- Download/export without progress (disable button, show progress toast)
- Inconsistent empty states (standardize "No logs found" message)
- Search/filter without loading state (show spinner during log fetch)

**Research flag:** No research needed. ViewLogs is reference implementation.

---

### Phase Ordering Rationale

**Dependency-driven sequence:**
1. Phase 1 establishes table pattern → Phase 2 builds bulk actions on top → Phase 5 reuses table for job history
2. Phase 3 charts are independent → can be implemented in parallel with Phase 1-2 if team size allows
3. Phase 4 CMS is isolated → defer until team has pattern experience from Phases 1-3
4. Phase 6 is polish → final consistency pass after all patterns established

**Risk mitigation sequence:**
- Highest-risk pitfall is pattern inconsistency → Phase 1 addresses by establishing foundation first
- Second-risk is cross-page selection → Phase 2 addresses before other views copy bulk actions
- Third-risk is async cleanup → Phase 5 extracts composable after team understands lifecycle from Phase 2-4

**Stakeholder value sequence:**
- Phase 1 delivers immediate productivity (search/filter in user management)
- Phase 2 delivers workflow efficiency (bulk approve pending users)
- Phase 3 delivers visual impact (charts for reports)
- Phase 4 delivers content control (edit About page)
- Phase 5-6 are polish (nice-to-have enhancements)

**Technical complexity sequence:**
- Phase 1: Low complexity (pattern replication)
- Phase 2: Medium complexity (interaction patterns)
- Phase 3: Medium complexity (new library integration)
- Phase 4: High complexity (editor + storage + workflow)
- Phase 5-6: Low complexity (enhancements to existing code)

This ordering ensures early wins (Phase 1-2), parallel track options (Phase 3), and complexity management (hardest phase comes after pattern experience).

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 2 (Bulk Actions):** Multi-page selection UX patterns. If team unfamiliar with Set-based state management or contextual action bars, consider `/gsd:research-phase bulk-action-ux` to gather interaction examples from PatternFly, HeliosDesignSystem, Nielsen Norman Group guidelines.
- **Phase 4 (CMS Editor):** Advanced TipTap features if requirements expand. If team needs image upload, tables, custom extensions beyond StarterKit, consider `/gsd:research-phase tiptap-extensions`.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Table Foundation):** TablesEntities is canonical example. Copy-paste-adapt approach. No additional research needed.
- **Phase 3 (Charts):** Chart.js documentation is excellent. Official vue-chartjs examples cover all use cases. Skip research.
- **Phase 5 (Async Polish):** ManageAnnotations is reference implementation. Extracting to composable is refactoring, not new pattern. Skip research.
- **Phase 6 (ViewLogs):** Already complete. Feature parity is incremental enhancement. Skip research.

**Research depth recommendation:** Standard depth (not deep) for all phases. Admin panel extends existing architecture, doesn't introduce unfamiliar domains. WebSearch + existing codebase inspection is sufficient.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommended libraries actively maintained (published within 3 months), verified Vue 3.5/TypeScript 5.9 compatibility, existing v5.0 baseline validated in production. Bundle size estimates based on npm package analyzer. Only gap: Need actual build verification for +130KB claim. |
| Features | HIGH | Feature expectations derived from 15+ sources on admin panel best practices (2026), scientific database UX patterns (G2, Research.com), bulk action guidelines (PatternFly, NN/g). Existing codebase analysis confirms table stakes features missing from current admin views. |
| Architecture | HIGH | Architecture analysis based on direct codebase inspection (TablesEntities 492-514, ManageAnnotations 432-577, GenericTable, useTableData composables). Integration patterns proven in production. New patterns (charts, CMS) follow established Vue 3 Composition API best practices documented in official Vue.js guides. |
| Pitfalls | MEDIUM | Critical pitfalls validated through codebase inspection (module-level caching in TablesEntities, async cleanup in ManageAnnotations). Moderate/minor pitfalls based on WebSearch patterns + inference. Bulk action cross-page selection pitfall identified from NN/g guidelines but not yet observed in SysNDD codebase. |

**Overall confidence:** HIGH

### Gaps to Address

**Bundle size verification:** Estimated +130KB gzipped (Chart.js ~50KB, TipTap ~80KB) needs validation during Phase 3-4 implementation. Add build size check to CI/CD pipeline. If bundle exceeds 1MB total, implement code splitting for admin routes.

**Mirai job cancellation:** Phase 5 includes optional job cancellation "if mirai supports." Needs validation during planning. If mirai doesn't support AbortController pattern, remove feature from phase scope or research alternative (kill process by job_id, if safe).

**CMS versioning requirements:** Phase 4 implements draft/publish only. If stakeholders need full version history (undo to previous content, compare versions), requires cms_content_history table and UI changes. Validate requirements during Phase 4 planning—don't assume draft/publish is sufficient.

**Performance testing:** AdminStatistics charts with large time series (1000+ data points) may cause rendering delays. Chart.js handles <100 points at 60fps; server-side aggregation needed for larger datasets. Add performance testing during Phase 3 implementation.

**Role permission matrix:** Phase 2 establishes usePermissions composable but specific role capabilities not documented. Need stakeholder validation: Can Reviewers bulk approve users? Can Curators edit ontology? Create permission matrix during Phase 2 planning.

## Sources

### Primary (HIGH confidence)
- **SysNDD codebase inspection** (2026-01-25) — TablesEntities.vue, ManageAnnotations.vue, GenericTable.vue, useTableData.ts, PROJECT.md, package.json. Established patterns for table state, async jobs, composables, existing tech stack.
- **Chart.js npm v4.5.1** — [npm](https://www.npmjs.com/package/chart.js), [official docs](https://www.chartjs.org/docs/latest/). Chart types, configuration, Vue integration.
- **vue-chartjs npm v5.3.3** — [npm](https://www.npmjs.com/package/vue-chartjs), [official docs](https://vue-chartjs.org/guide/). Vue 3 Composition API wrapper.
- **TipTap @tiptap/vue-3 v3.15.3** — [npm](https://www.npmjs.com/package/@tiptap/vue-3), [official docs](https://tiptap.dev/docs/editor/getting-started/install/vue3). Vue 3 integration, extensions, styling.
- **Bootstrap-Vue-Next v0.42.0** — [BTable docs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table), [BPagination docs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/pagination). Component capabilities verification.
- **Vue.js Composables Official Guide** — [vuejs.org](https://vuejs.org/guide/reusability/composables.html). Composition API patterns, lifecycle management.

### Secondary (MEDIUM confidence)
- **Admin Dashboard Best Practices 2026** — [WeWeb guide](https://www.weweb.io/blog/admin-dashboard-ultimate-guide-templates-examples), [FanRuan design ideas](https://www.fanruan.com/en/blog/top-admin-dashboard-design-ideas-inspiration). Modern admin panel feature expectations.
- **Scientific Data Management Systems** — [Research.com top 20](https://research.com/software/best-scientific-data-management-systems), [G2 user reviews](https://www.g2.com/categories/scientific-data-management-system-sdms). Scientific database admin interface patterns.
- **Bulk Action UX Guidelines** — [Eleken design guidelines](https://www.eleken.co/blog-posts/bulk-actions-ux), [NN/g video](https://www.nngroup.com/videos/bulk-actions-design-guidelines/), [PatternFly bulk selection](https://www.patternfly.org/patterns/bulk-selection/). Interaction patterns for multi-select actions.
- **Chart Library Comparisons 2026** — [Weavelinx best libraries](https://weavelinx.com/best-chart-libraries-for-vue-projects-in-2026/), [Luzmo definitive guide](https://www.luzmo.com/blog/vue-chart-libraries). Vue 3 chart library tradeoffs.
- **Rich Text Editor Comparisons 2025** — [Liveblocks editor framework comparison](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025), [TipTap Quill migration](https://tiptap.dev/docs/guides/migrate-from-quill). Editor selection criteria.
- **Scientific Visualization Pitfalls** — [PMC article](https://pmc.ncbi.nlm.nih.gov/articles/PMC8556474/). Chart type appropriateness for scientific data.
- **Async State Management Pitfalls** — [Evil Martians guide](https://evilmartians.com/chronicles/how-to-avoid-tricky-async-state-manager-pitfalls-react). Polling lifecycle patterns (React-focused but principles applicable).

### Tertiary (LOW confidence)
- **CMS Integration Failures 2026** — [Apparate blog](https://www.apparate.com.au/blog/cms-fails-2026). CMS adoption challenges (marketing-focused, needs validation for technical CMS).
- **Dashboard Design Mistakes** — [Databox bad examples](https://databox.com/bad-dashboard-examples). Anti-patterns (business dashboard focus, scientific context added from domain knowledge).

---
*Research completed: 2026-01-25*
*Ready for roadmap: yes*
