# Admin Panel Modernization Pitfalls

**Domain:** Scientific database admin interfaces
**Researched:** 2026-01-25
**Confidence:** MEDIUM (WebSearch-informed patterns + existing codebase analysis)

## Executive Summary

Modernizing admin panels in scientific databases presents unique challenges that differ from public-facing interfaces. These pitfalls stem from adding complex features (charts, bulk actions, CMS editing) to existing systems where patterns may not be consistently applied. The most critical risk is **inconsistency between modernized admin views and existing good patterns** (TablesEntities URL sync, ManageAnnotations async polling), leading to fragmented UX and maintenance burden.

---

## Critical Pitfalls

Mistakes that cause rewrites or major issues.

### Pitfall 1: State Management Inconsistency Across Admin Views

**What goes wrong:**
Each admin view implements its own state management pattern (some with URL sync, some without; some using composables, some using local state). This creates:
- Non-bookmarkable filter states in some views but not others
- Lost work when users navigate away from unsaved filters
- Inconsistent back-button behavior
- Duplicate code for similar functionality

**Why it happens:**
Admin panels are added incrementally without architectural planning. Developers copy from the nearest example rather than identifying the project's canonical pattern.

**Evidence from codebase:**
- **TablesEntities** (line 492-514): Implements sophisticated URL sync with `history.replaceState`, module-level caching to prevent duplicate API calls
- **ManageUser** (no URL sync): Simple table with no filter state persistence
- **ManageOntology** (no URL sync): Basic CRUD with no filter/pagination state management

**Consequences:**
- Users lose filter state when refreshing ManageUser but not TablesEntities
- Cannot share filtered admin views (e.g., "unapproved users only")
- Technical debt: three different patterns for table state management

**Prevention:**
1. **Audit existing patterns FIRST** - Document TablesEntities URL sync pattern before building new admin views
2. **Create admin table composable** - Extract TablesEntities URL sync into `useAdminTable` composable
3. **Establish pattern enforcement** - PR checklist: "Does this table implement URL state sync like TablesEntities?"
4. **Document the canonical pattern** - Add architecture decision record: "All paginated admin tables MUST support URL state sync"

**Detection:**
- Code smell: Admin views using `v-model` for filters without corresponding URL parameter updates
- Test: Open admin view, set filters, refresh page - do filters persist?
- Review: Search for `useTableData` usage - does every consumer call `updateBrowserUrl()`?

**Which phase addresses this:** Phase 1 (Foundation) - must establish pattern before building features

---

### Pitfall 2: Bulk Actions with Cross-Page Selection State

**What goes wrong:**
User selects items on page 1, navigates to page 2, selects more items, then clicks "Bulk Approve". System either:
- Only acts on current page items (silently drops page 1 selections)
- Throws error "Selection contains items not on current page"
- Acts on wrong items due to ID collision after pagination

**Why it happens:**
Selection state is stored as array of row indices (not IDs), or state is cleared on pagination. Developers don't anticipate multi-page selection workflows.

**Evidence from research:**
[Bulk action UX guidelines](https://www.eleken.co/blog-posts/bulk-actions-ux) identify this as the #1 UX failure: "selections should span both pages" but implementation is complex.

**Real-world scenario in SysNDD:**
Admin wants to approve all unapproved users with domain "@university.edu":
1. Filters to unapproved users (50 results across 5 pages)
2. Page 1: Selects 3 users
3. Page 2: Selects 4 more users
4. Clicks "Bulk Approve"
5. **Expected:** 7 users approved
6. **Actual:** Only page 2's 4 users approved (page 1 state lost)

**Consequences:**
- Data integrity issues (partial bulk operations)
- Lost admin productivity (must repeat operations page by page)
- User confusion (no feedback about dropped selections)

**Prevention:**
1. **Store selection by ID, not index** - `selectedIds: Set<number>` not `selectedRows: number[]`
2. **Persist across pagination** - Module-level selection state (like TablesEntities' API cache pattern)
3. **Visual feedback for off-page selections** - Badge showing "5 items selected across multiple pages"
4. **Clear confirmation dialogs** - "Approve 7 users? (3 on this page, 4 on other pages)"
5. **Provide "select all matching filter" option** - "Select all 50 unapproved users" (server-side selection)

**Detection:**
- Test: Select items on page 1, navigate to page 2, check if page 1 selections still show in count
- Code review: Search for `selected` state - is it cleared on `handlePageChange`?
- Warning sign: No "X items selected" persistent indicator when navigating pages

**Which phase addresses this:** Phase 2 (ManageUser bulk actions) - implement robust pattern before other views copy it

---

### Pitfall 3: Async Job Polling Without Proper Cleanup

**What goes wrong:**
Long-running jobs (ontology updates, OMIM sync) start polling intervals that:
- Continue after component unmounts (memory leak)
- Fire multiple times when component remounts (duplicate requests)
- Don't handle page navigation (stale job IDs)
- Crash on network errors without retry limit

**Why it happens:**
Developers forget Vue component lifecycle. Polling is started in `mounted()` but not stopped in `beforeUnmount()`. Component remounts (due to navigation) start new polling without cleaning old intervals.

**Evidence from codebase:**
**ManageAnnotations** (lines 432-435, 565-577): **CORRECT** implementation:
```javascript
beforeUnmount() {
  this.stopPolling();
  this.stopElapsedTimer();
}
```
But other admin views may copy async patterns without understanding this requirement.

**Evidence from research:**
[Async state management pitfalls](https://evilmartians.com/chronicles/how-to-avoid-tricky-async-state-manager-pitfalls-react) warns: "blind client-side retries are problematic for production systems"

**Consequences:**
- Memory leaks: 100-300MB per leaked polling interval (seen in Cytoscape cleanup patterns, line 273 in PROJECT.md)
- API overload: N concurrent polling requests for same job (N = number of times user navigated)
- Stale UI: Old polling interval updates UI with outdated job status after new job started

**Prevention:**
1. **Always pair polling start with cleanup** - Template pattern:
   ```javascript
   mounted() { this.startPolling(); }
   beforeUnmount() { this.stopPolling(); }
   ```
2. **Store interval ID in component instance** - `this.pollInterval = setInterval(...)` enables cleanup
3. **Debounce job start** - Prevent multiple jobs from rapid button clicks
4. **Implement exponential backoff** - Start at 1s, increase to 5s after multiple polls
5. **Set maximum poll duration** - Stop after 5 minutes, show "Check ViewLogs" message
6. **Guard against stale job IDs** - Compare `this.jobId === response.job_id` before updating UI

**Detection:**
- Test: Start long job, navigate away immediately, check network tab for continuing requests
- Test: Start job, refresh page, start another job - check for duplicate polling
- Code review: Every `setInterval` must have corresponding `clearInterval` in `beforeUnmount`
- Memory profiling: Open admin view, start 10 jobs (navigate between starts), check DevTools memory

**Which phase addresses this:** Phase 3 (ManageAnnotations improvements) - establish async job pattern as reusable composable

---

### Pitfall 4: Chart Data Without Scientific Context

**What goes wrong:**
Admin dashboard shows impressive-looking charts (bar charts, pie charts, trend lines) but:
- Missing statistical significance indicators
- No comparison to historical baselines
- Charts use inappropriate types for scientific data (3D pie charts for proportions)
- Color choices violate accessibility (red/green for colorblind users)
- No export to publication-ready formats

**Why it happens:**
Developers treat admin dashboards like business dashboards, copying patterns from generic admin templates. Scientific databases require domain-specific chart considerations.

**Evidence from research:**
[Scientific visualization pitfalls](https://pmc.ncbi.nlm.nih.gov/articles/PMC8556474/) found "pie chart is the most misused graphical representation" and "size is the most critical issue" in scientific publications.

[Dashboard design mistakes](https://databox.com/bad-dashboard-examples) warns: "most common mistake is too many different types of information on one visualization"

**Real-world scenario in SysNDD:**
Admin wants to show "Entity approval rate trends":
- **Bad:** 3D pie chart showing "65% approved" (no context, what's baseline?)
- **Good:** Line chart showing approval rate over time, with annotation: "↓ 15% from previous month" and link to "View 50 unapproved entities"

**Consequences:**
- Misleading insights (chart shows change but not significance)
- Cannot use charts in publications (wrong format, accessibility issues)
- Users ignore dashboard ("pretty but useless")
- Extra work creating publication charts elsewhere

**Prevention:**
1. **Provide context, not just values** - "246 entities (↑12% vs last month, avg: 220)"
2. **Use appropriate chart types**:
   - Time series → Line charts (not pie)
   - Proportions < 5 categories → Horizontal bar (not 3D pie)
   - Distributions → Histograms (not stacked area)
3. **Follow existing project patterns** - SysNDD already has Cytoscape network viz, ColorLegend component
4. **Add export buttons** - PNG/SVG download (TablesEntities has Excel export pattern to follow)
5. **Use accessible color palettes** - ColorBrewer2 for colorblind-safe colors
6. **Include "What this means" text** - One-sentence interpretation below each chart

**Detection:**
- Review: Can a colorblind user distinguish chart categories?
- Test: Export chart - is it publication-quality (vector format, labeled axes)?
- Comparison: Show chart to domain expert - do they immediately understand significance?
- Code smell: Chart library has 10+ chart types but no annotation/comparison features

**Which phase addresses this:** Phase 5 (AdminStatistics) - establish chart standards before implementation

---

## Moderate Pitfalls

Mistakes that cause delays or technical debt.

### Pitfall 5: Non-Reusable CMS Implementation

**What goes wrong:**
ManageAbout CMS editor is built as one-off component tightly coupled to About page structure. When team wants to add CMS editing to other pages (Help, Documentation), must rewrite from scratch.

**Why it happens:**
CMS integration is treated as feature implementation rather than infrastructure addition. Developer focuses on "edit About page" requirement without considering "edit any markdown content" abstraction.

**Evidence from research:**
[CMS integration mistakes](https://www.apparate.com.au/blog/cms-fails-2026): "Nearly 90% of users consider integration to be the number one sales hurdle" and "every feature typically needs additional implementation effort"

**Consequences:**
- 3-4x work when adding CMS to second page (duplicate editor, preview, save logic)
- Inconsistent editing UX across different content types
- Maintenance burden (bug fixes must be applied N times)

**Prevention:**
1. **Build generic CMS composable** - `useCmsEditor({ contentKey: 'about', apiEndpoint: '/content' })`
2. **Store content in generic table** - `content_pages (page_key, markdown_content, last_updated)` not `about_page_text` field
3. **Reuse existing patterns** - TablesEntities GenericTable component shows path to reusability
4. **Start with 2+ use cases** - Implement ManageAbout AND ManageHelp together to force generic design
5. **Document extension points** - Clear instructions: "To add CMS to new page, add row to content_pages, create view with useCmsEditor"

**Detection:**
- Code smell: Component name is `AboutEditor` not `MarkdownEditor`
- Test: Can you add CMS to FAQ page in < 30 lines of code?
- Review: Are database schema, API endpoints, components specific to About page?

**Which phase addresses this:** Phase 4 (ManageAbout) - but refactor in Phase 6 if not generic

---

### Pitfall 6: Modal State Management Hell

**What goes wrong:**
Admin views have 5+ modals (edit user, delete user, bulk approve, role assignment, password reset). State management becomes nightmare:
- Modal data stale (shows user from previous edit)
- Multiple modals can't open simultaneously (z-index conflicts)
- Validation state persists across modal opens
- Close button doesn't reset form state

**Why it happens:**
Each modal is implemented independently without shared state management pattern. Bootstrap-Vue-Next modal API differs from Vue 2's BootstrapVue, causing migration issues.

**Evidence from codebase:**
**ManageUser** (lines 439-453): Each modal manually resets state:
```javascript
editUser(item) {
  this.userToUpdate = { ...item };
  this.setValues({ /* vee-validate reset */ });
}
```
This pattern must be repeated for every modal.

**Consequences:**
- Bugs: Edit user modal shows previous user's data if not properly reset
- Validation errors persist: "Email invalid" from previous modal edit still shows
- Z-index wars: Delete confirmation appears behind edit modal

**Prevention:**
1. **Extract modal management** - Already have `useModalControls` composable, extend it
2. **Modal lifecycle hooks** - `onModalShow(() => resetFormState())` pattern
3. **Isolate modal state** - Each modal gets own reactive object, cleared on close
4. **Use modal IDs consistently** - `${entity}-${action}-modal` pattern (`user-edit-modal`, `user-delete-modal`)
5. **Reset vee-validate explicitly** - `resetForm()` in modal close handler

**Detection:**
- Test: Open edit modal, close without saving, reopen - are fields empty?
- Test: Trigger validation error, close modal, reopen - is error still shown?
- Code review: Does `@ok` handler call `resetForm()`?

**Which phase addresses this:** Phase 2 (ManageUser) - establish modal pattern for other views

---

### Pitfall 7: Pagination Without URL Sync (Moderate Version)

**What goes wrong:**
ManageUser, ManageOntology have pagination but no URL state. User navigates to page 5, finds interesting user, clicks to edit, realizes they need to check something in Entities table, navigates back - now on page 1 of ManageUser again.

**Why it happens:**
Developers copy basic table example without URL sync. Viewed as "nice to have" rather than UX requirement.

**Evidence from codebase:**
**TablesEntities** (line 492-514) has sophisticated URL sync, but **ManageUser/ManageOntology** don't use it.

**Consequences:**
- Lost context during workflows (must repeatedly paginate back to page 5)
- Cannot bookmark/share admin views ("check unapproved users on page 3")
- Inconsistent with public-facing tables (Entities is bookmarkable)

**Prevention:**
1. **Make URL sync default** - Admin table scaffold should include it by default
2. **Reuse TablesEntities pattern** - Extract `updateBrowserUrl()` to composable
3. **Document URL params** - `?page_after=50&page_size=25` becomes standard
4. **Add to component checklist** - "If component has pagination, must implement URL sync"

**Detection:**
- Test: Navigate to page 3, refresh browser - still on page 3?
- Review: Does component call `updateBrowserUrl()` or `router.replace()`?

**Which phase addresses this:** Phase 3 (ManageOntology) - add URL sync when adding pagination

---

### Pitfall 8: Role-Based Feature Gating Inconsistency

**What goes wrong:**
Some admin features check roles on frontend only, others on backend only, some on both. Results:
- Edit button visible but API returns 403
- Bulk actions UI available to non-admin users (fails silently)
- Different admin views have different permission levels

**Why it happens:**
Auth middleware (`require_auth`) added in v4 but frontend still has role checks scattered across components. No single source of truth for "can user perform action X?"

**Evidence from codebase:**
Backend has `require_auth` middleware (line 19 in PROJECT.md), but ManageUser doesn't conditionally hide delete button based on role.

**Consequences:**
- Security risk (frontend checks can be bypassed)
- Poor UX (user sees button, clicks, gets error)
- Maintenance burden (permission changes require N component updates)

**Prevention:**
1. **Backend as source of truth** - Always check permissions in API, frontend just provides better UX
2. **Create permission composable** - `const { canEditUser, canBulkApprove } = usePermissions()`
3. **Disable, don't hide** - Show buttons as disabled with tooltip "Admin only"
4. **Consistent error handling** - 403 responses should show same error message format across admin views
5. **Document role matrix** - Table showing which roles can access which features

**Detection:**
- Security test: Remove localStorage token, can you still see admin buttons?
- Test: Log in as Curator (not Admin), are bulk actions disabled or hidden?
- Review: Does component check role before showing feature?

**Which phase addresses this:** Phase 2 (ManageUser bulk actions) - establish permission checking pattern

---

## Minor Pitfalls

Mistakes that cause annoyance but are fixable.

### Pitfall 9: Search/Filter Without Loading State

**What goes wrong:**
User types in search box, results don't update immediately, user types more, original search returns and overrides new search, causing confusion.

**Why it happens:**
Debounced search triggers API call but doesn't set loading state. Multiple overlapping requests race to completion.

**Evidence from codebase:**
TablesEntities (line 107) has debounce="500" but ManageUser doesn't show loading indicator during search.

**Consequences:**
- Results flicker as overlapping requests complete
- User doesn't know if search is still processing
- Feels slow even though API is fast

**Prevention:**
1. **Loading state for every async action** - `isBusy` ref in useTableData pattern
2. **Cancel in-flight requests** - AbortController pattern when new search triggers
3. **Debounce with loading indicator** - Show spinner during debounce delay
4. **Instant visual feedback** - Gray out results while loading

**Detection:**
- Test: Type fast in search box - do results flicker?
- Review: Does search handler set `isBusy = true`?

**Which phase addresses this:** Any phase - can be added incrementally

---

### Pitfall 10: Inconsistent Empty States

**What goes wrong:**
Some admin tables show "No items found" when empty, others show blank table, others show spinner indefinitely.

**Why it happens:**
Each component implements empty state differently. GenericTable has `show-empty` prop but not all consumers use it consistently.

**Evidence from codebase:**
GenericTable (line 10) has `show-empty` but no standardized empty state message.

**Consequences:**
- User confusion ("Is it loading or empty?")
- Inconsistent UX across admin views

**Prevention:**
1. **Default empty state in GenericTable** - Standard message with icon
2. **Contextual empty states** - "No unapproved users" vs "No users found"
3. **Call to action** - "No entities yet. Create your first entity"
4. **Distinguish loading from empty** - Spinner + "Loading..." vs Empty state illustration

**Detection:**
- Test: View admin table with no data - what displays?
- Review: Does every table use consistent empty state?

**Which phase addresses this:** Phase 1 (Foundation) - standardize in GenericTable

---

### Pitfall 11: Download/Export Without Progress

**What goes wrong:**
Admin clicks "Export 10,000 entities to Excel", nothing visible happens for 30 seconds, clicks again, two downloads start.

**Why it happens:**
Excel export is async but no progress indication. Button not disabled during download.

**Evidence from codebase:**
TablesEntities requestExcel (useTableMethods line 239-280) sets `downloading` ref but ManageUser doesn't implement export yet.

**Consequences:**
- User frustration ("Did it work?")
- Duplicate requests from impatient clicking
- No way to cancel long exports

**Prevention:**
1. **Disable button during download** - `:disabled="downloading"` binding
2. **Show progress toast** - "Generating export... 5,234/10,000 rows"
3. **Change button text** - "Download" → "Downloading..." with spinner
4. **Cancel button for long exports** - AbortController pattern

**Detection:**
- Test: Click export, immediately click again - does second click do nothing?
- Review: Does export button have `:disabled="downloading"` binding?

**Which phase addresses this:** Phase 6 (ViewLogs feature parity) - when adding export

---

### Pitfall 12: Scientific Notation in Sort Comparison

**What goes wrong:**
AdminStatistics shows table with FDR p-values (1.2e-10, 3.4e-8) but sorting treats them as strings: "1.2e-10" comes before "3.4e-8" alphabetically.

**Why it happens:**
GenericTable uses default string sorting. Scientific notation needs custom `sortCompare` function.

**Evidence from codebase:**
PROJECT.md (line 215) explicitly mentions "FDR column sorting needs sortCompare for scientific notation" as minor tech debt.

**Consequences:**
- Cannot sort statistical tables correctly
- Confusing results (visually larger numbers sort first)

**Prevention:**
1. **Add sortCompare function** - Parse scientific notation to float for comparison
2. **Detect scientific notation columns** - Auto-apply numeric sort to columns with regex `\d+\.?\d*e[+-]?\d+`
3. **TypeScript types for column data** - `fdr_value: ScientificNumber` type

**Detection:**
- Test: Sort column with values "1e-10, 5e-5, 2e-8" - is order correct?
- Review: Does field definition include `sortCompare`?

**Which phase addresses this:** Phase 5 (AdminStatistics) - when implementing stats tables

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: Foundation** | Inconsistent pattern adoption | Create admin table template with URL sync, document in architecture guide |
| **Phase 2: ManageUser bulk actions** | Cross-page selection state lost | Implement Set-based selection with module-level persistence, show "X selected" badge |
| **Phase 3: ManageAnnotations UI** | Async polling memory leaks | Extract polling to `useAsyncJob` composable with mandatory cleanup |
| **Phase 4: ManageOntology pagination** | No URL sync when adding pagination | Mandate URL state sync in PR checklist, reuse TablesEntities pattern |
| **Phase 5: ManageAbout CMS** | One-off implementation | Build `useCmsEditor` composable, test with 2 content types |
| **Phase 6: AdminStatistics charts** | Charts without scientific context | Establish chart standards doc, require context/comparison for all charts |
| **Phase 7: ViewLogs feature parity** | Reimplementing TablesEntities features | Use TablesEntities as component template, share composables |

---

## Integration Pitfalls with Existing System

These are pitfalls specific to adding features to SysNDD's established codebase.

### Pitfall 13: Diverging from Established Composable Patterns

**What goes wrong:**
SysNDD has 13 composables (line 35 in PROJECT.md) with established patterns (`useTableData`, `useTableMethods`, `useModalControls`). New admin features introduce competing patterns:
- Some views use composables, others use mixins (already migrated but risk regression)
- Filter state managed differently in each admin view
- Modal management reimplemented instead of using `useModalControls`

**Evidence from codebase:**
- TablesEntities uses `useTableData` + `useTableMethods` (lines 299-355)
- ManageUser partially uses composables but reimplements modal logic (lines 413-437)
- ManageOntology doesn't use `useModalControls` despite it being available

**Prevention:**
1. **Audit composables before implementing** - List all existing composables, identify reusable ones
2. **PR requirement: "Why not use existing composable?"** - Force justification for new patterns
3. **Composable discovery documentation** - README listing all composables and use cases
4. **Pair programming on first admin view** - Ensure team knows composable patterns

**Detection:**
- Code review: New component reimplements existing composable functionality
- Pattern count: If project has 3+ ways to do same thing, patterns are diverging

**Which phase addresses this:** Phase 1 (Foundation) - prevent before implementing features

---

### Pitfall 14: Breaking TablesEntities' Module-Level Caching

**What goes wrong:**
TablesEntities uses module-level variables (lines 266-271) to prevent duplicate API calls across component remounts. New admin tables try to copy this pattern but:
- Module-level state is shared across ALL table instances
- ManageUser table pollutes TablesEntities cache
- Race conditions when both tables visible simultaneously

**Evidence from codebase:**
```javascript
// Module-level variables to track API calls across component remounts
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiResponse = null;
```
This pattern is specific to single-instance tables, breaks with multiple admin tables.

**Prevention:**
1. **Don't copy module-level pattern** - It's optimization for specific case (URL-driven remounts)
2. **Use composable instance state** - `useTableData` creates per-instance state
3. **Namespace module-level caches** - `moduleLastApiParams_entities` vs `moduleLastApiParams_users`
4. **Consider Pinia store** - If state needs sharing, use proper state management

**Detection:**
- Bug: Open Entities table and ManageUser simultaneously, strange behavior occurs
- Code review: New table uses `let module*` variables at top of file

**Which phase addresses this:** Phase 1 (Foundation) - document when to use module-level state

---

### Pitfall 15: Ignoring Existing Async Job Pattern

**What goes wrong:**
ManageAnnotations has robust async job polling (lines 527-642) with:
- Proper cleanup in `beforeUnmount`
- Elapsed time display
- Progress tracking
- Error handling

New admin features need async operations (bulk user import, entity batch update) but reimplement from scratch, missing these safeguards.

**Prevention:**
1. **Extract to `useAsyncJob` composable** - Make ManageAnnotations pattern reusable
2. **Document async job requirements** - Checklist: cleanup, progress, timeout, error handling
3. **Create async job template** - Scaffold new async features with pattern included

**Detection:**
- Code review: New async operation doesn't use `useAsyncJob` composable
- Test: Start async job, navigate away, check for memory leak

**Which phase addresses this:** Phase 3 (ManageAnnotations) - extract to composable during UI improvements

---

## Confidence Assessment

| Source | Confidence | Rationale |
|--------|------------|-----------|
| State management patterns | HIGH | Directly observed in TablesEntities implementation |
| Async polling issues | HIGH | ManageAnnotations provides canonical example |
| Bulk actions complexity | MEDIUM | Based on WebSearch results, not observed in codebase yet |
| Chart context requirements | MEDIUM | Scientific database domain knowledge + research |
| CMS integration | LOW | No existing CMS in codebase, based on general patterns |
| Module-level caching pitfall | HIGH | Specific to TablesEntities implementation pattern |

---

## Sources

**Web Research:**
- [Five application modernization pitfalls](https://vfunction.com/blog/app-modernization-pitfalls/)
- [Bad Dashboard Examples](https://databox.com/bad-dashboard-examples)
- [Examining data visualization pitfalls in scientific publications](https://pmc.ncbi.nlm.nih.gov/articles/PMC8556474/)
- [Bulk action UX: 8 design guidelines](https://www.eleken.co/blog-posts/bulk-actions-ux)
- [Effective pagination: implementation and pitfalls](https://medium.com/@maxthraex/effective-pagination-implementation-and-pitfalls-84f964b19549)
- [How to avoid tricky async state manager pitfalls in React](https://evilmartians.com/chronicles/how-to-avoid-tricky-async-state-manager-pitfalls-react)
- [State Management 2025: React, Server State, URL State](https://medium.com/@QuarkAndCode/state-management-2025-react-server-state-url-state-dapr-agent-sync-d8a1f6c59288)
- [CMS integration: Why Everything You Need To Know About CMS Fails in 2026](https://www.apparate.com.au/blog/cms-fails-2026)

**Codebase Analysis:**
- TablesEntities.vue (URL sync pattern, module-level caching)
- ManageAnnotations.vue (async job polling pattern)
- GenericTable.vue (reusable table component)
- ManageUser.vue (basic admin CRUD)
- ManageOntology.vue (basic admin table)
- useTableData.ts (table state composable)
- useTableMethods.ts (table action methods)
- PROJECT.md (existing patterns and technical debt)
