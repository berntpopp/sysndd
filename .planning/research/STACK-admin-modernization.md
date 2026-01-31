# Technology Stack: Admin Panel Modernization

**Project:** SysNDD v6.0 Admin Panel
**Researched:** 2026-01-25
**Confidence:** HIGH

## Executive Summary

Admin panel modernization requires **minimal new dependencies** to the existing Vue 3 + Bootstrap-Vue-Next stack. Add Chart.js for statistics dashboards, TipTap for CMS editing, and leverage existing Bootstrap-Vue-Next table components. The project already has robust patterns (TablesEntities) that should be extended, not replaced.

**Key principle:** Prefer extending existing patterns over introducing new component paradigms.

## Validated Baseline (DO NOT change)

Current stack from PROJECT.md and package.json analysis:

| Technology | Version | Status |
|------------|---------|--------|
| Vue | 3.5.25 | ✓ Keep |
| TypeScript | 5.9.3 | ✓ Keep |
| Bootstrap | 5.3.8 | ✓ Keep |
| Bootstrap-Vue-Next | 0.42.0 | ✓ Keep |
| Vite | 7.3.1 | ✓ Keep |
| @vueuse/core | 14.1.0 | ✓ Keep |
| Pinia | 2.0.14 | ✓ Keep |

**Rationale:** v5.0 just shipped (2026-01-25) with this stack validated. Admin panel is additive work, not a rewrite.

## Recommended Additions

### Charts/Visualization: Chart.js

| Library | Version | Purpose | Installation |
|---------|---------|---------|--------------|
| chart.js | ^4.5.1 | Core charting library | `npm install chart.js` |
| vue-chartjs | ^5.3.3 | Vue 3 wrapper for Chart.js | `npm install vue-chartjs` |

**Why Chart.js over ApexCharts:**

1. **Simpler learning curve** - AdminStatistics needs 3-4 basic chart types (line, bar, pie), not 16 complex types
2. **Better Bootstrap 5 integration** - Canvas-based rendering integrates naturally with Bootstrap grid, documented patterns exist
3. **Smaller bundle** - Chart.js v4 is tree-shakable; import only needed chart types (~50KB vs ApexCharts ~130KB)
4. **Vue 3 wrapper maturity** - vue-chartjs 5.3.3 (published 3 months ago) has excellent Vue 3 Composition API support with reactive data
5. **Massive ecosystem** - 4,923+ npm dependents vs ApexCharts' 823; every error has Stack Overflow solutions
6. **Performance for admin stats** - AdminStatistics shows aggregate metrics (total entities, averages), not real-time data streams where ApexCharts excels

**When NOT to use Chart.js:**
- Real-time streaming data (stick with D3 or ApexCharts)
- Complex financial charts with synchronized zoom/pan
- Advanced interactivity beyond tooltips/legends

**Implementation pattern:**

```typescript
// composables/useChartData.ts
import { ref, computed } from 'vue'
import type { ChartData, ChartOptions } from 'chart.js'

export function useChartData() {
  // Reactive chart data matching Chart.js types
  const chartData = ref<ChartData>({ datasets: [], labels: [] })

  // Bootstrap-styled options
  const chartOptions = computed<ChartOptions>(() => ({
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: true, position: 'bottom' }
    }
  }))

  return { chartData, chartOptions }
}
```

```vue
<!-- AdminStatistics.vue -->
<template>
  <BCard>
    <div style="height: 300px;">
      <Line :data="chartData" :options="chartOptions" />
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { Line } from 'vue-chartjs'
import { useChartData } from '@/composables/useChartData'

const { chartData, chartOptions } = useChartData()
</script>
```

**Chart types for AdminStatistics:**
- Line chart: entities added over time (temporal trends)
- Bar chart: entities by category (distribution)
- Doughnut chart: review status breakdown (proportions, max 3-4 slices per anti-pattern research)

**Sources:**
- Chart.js v4.5.1: [npm](https://www.npmjs.com/package/chart.js), [docs](https://www.chartjs.org/docs/latest/)
- vue-chartjs v5.3.3: [npm](https://www.npmjs.com/package/vue-chartjs), [docs](https://vue-chartjs.org/guide/)
- Bootstrap 5 integration: [MDBootstrap tutorial](https://mdbootstrap.com/docs/standard/data/charts/), [Envato Tuts+](https://webdesign.tutsplus.com/how-to-integrate-bootstrap-5-tabs-with-chartjs--cms-107864t)

### Rich Text Editing: TipTap

| Library | Version | Purpose | Installation |
|---------|---------|---------|--------------|
| @tiptap/vue-3 | ^3.15.3 | Vue 3 editor component | `npm install @tiptap/vue-3` |
| @tiptap/pm | latest | ProseMirror core | `npm install @tiptap/pm` |
| @tiptap/starter-kit | latest | Basic editor extensions | `npm install @tiptap/starter-kit` |

**Why TipTap over Quill/VueQuill:**

1. **Active Vue 3 support** - 462 npm dependents for @tiptap/vue-3, published 11 days ago vs VueQuill (last updated 3 years ago)
2. **TypeScript native** - Written entirely in TypeScript, aligns with project's TS adoption (5.9.3)
3. **Headless architecture** - Apply Bootstrap classes directly to editor markup, no fighting with Quill's opinionated styling
4. **Modular extensions** - Load only needed features (bold, italic, lists, headings) for ManageAbout CMS editing
5. **Framework-agnostic future** - TipTap v3 supports Vue 2/3, React, Svelte; easier migration path if needed
6. **Composition API friendly** - `useEditor()` composable fits project's Composition API patterns (13 existing composables)

**Why NOT VueQuill:**
- Last published May 2023 (3 years stale)
- Based on Quill v2 which had maintenance concerns (project was dormant until 2024 rewrite)
- Options API patterns don't match project's Composition API standard

**Why NOT md-editor-v3:**
- ManageAbout needs WYSIWYG for non-technical content editors, not markdown source
- 6.3.1 (published 13 days ago) is actively maintained, BUT unnecessary complexity for simple CMS content
- Markdown preview/beautify features unused for About page content

**Implementation pattern:**

```typescript
// composables/useEditor.ts
import { useEditor } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'

export function useAboutEditor(content: string) {
  const editor = useEditor({
    extensions: [StarterKit], // includes heading, bold, italic, lists
    content,
    editorProps: {
      attributes: {
        class: 'form-control', // Bootstrap form styling
      },
    },
  })

  return { editor }
}
```

```vue
<!-- ManageAbout.vue -->
<template>
  <BCard>
    <EditorContent :editor="editor" class="tiptap-editor" />
    <BButton @click="save">Save Content</BButton>
  </BCard>
</template>

<script setup lang="ts">
import { EditorContent } from '@tiptap/vue-3'
import { useAboutEditor } from '@/composables/useEditor'

const { editor } = useAboutEditor('<p>Initial content</p>')

const save = () => {
  const html = editor.value?.getHTML()
  // POST to /api/about
}
</script>

<style scoped>
.tiptap-editor :deep(.ProseMirror) {
  min-height: 300px;
  padding: 0.75rem;
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius);
}

.tiptap-editor :deep(.ProseMirror:focus) {
  outline: none;
  border-color: var(--bs-primary);
  box-shadow: 0 0 0 0.25rem rgba(13, 110, 253, 0.25);
}
</style>
```

**Extensions for ManageAbout:**
- StarterKit (headings, bold, italic, bullet lists, ordered lists, blockquotes)
- NO need for tables, images, code blocks (About page is prose content)

**Bootstrap styling integration:**
- Apply `.form-control` to editor container
- Use Bootstrap focus styles (`:focus` border-color + box-shadow)
- Toolbar buttons use `BButton` with Bootstrap variants

**Sources:**
- @tiptap/vue-3 v3.15.3: [npm](https://www.npmjs.com/package/@tiptap/vue-3), [docs](https://tiptap.dev/docs/editor/getting-started/install/vue3)
- TipTap styling guide: [docs](https://tiptap.dev/docs/editor/getting-started/style-editor)
- Quill vs TipTap comparison: [Liveblocks blog](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025)
- Migration from Quill: [TipTap docs](https://tiptap.dev/docs/guides/migrate-from-quill)

### Table Enhancements: NONE (use existing patterns)

**DO NOT add new table libraries.** Bootstrap-Vue-Next 0.42.0 + existing TablesEntities pattern is sufficient.

**Existing capabilities (verified in TablesEntities.vue):**
- ✓ Pagination with BPagination component
- ✓ Column sorting (array-based sortBy format)
- ✓ Per-column filters (input + select)
- ✓ URL state sync via VueUse (already in dependencies 14.1.0)
- ✓ Search debouncing (500ms)
- ✓ Custom cell rendering via scoped slots
- ✓ Loading states with BSpinner
- ✓ Responsive Bootstrap grid layout

**Pattern to extend for admin views:**

1. **ManageUser**: Copy TablesEntities pagination/search pattern
   - Replace `/api/entity` with `/api/admin/users`
   - Add bulk action checkboxes (BFormCheckbox)
   - Add role select dropdown (BFormSelect with role options)
   - Keep URL sync pattern (`page_after`, `page_size`, `sort`, `filter`)

2. **ManageOntology**: Reuse TablesEntities almost verbatim
   - Same API pattern (sort/filter/pagination)
   - Different field spec (ontology_id, name, version vs entity fields)
   - Same GenericTable component

3. **ViewLogs**: Copy TablesEntities table structure
   - Add date range filter (BFormInput type="date")
   - Keep pagination pattern
   - Consider read-only (no edit actions)

**Anti-pattern to avoid:**
- DO NOT add vue-good-table, ag-grid, or other table libraries
- DO NOT replace Bootstrap-Vue-Next BTable (feature parity exists)
- DO NOT create new pagination/filter patterns (URL sync already works)

**Why NOT add new table library:**
- Bundle bloat: ag-grid ~600KB, vue-good-table ~200KB vs 0KB for existing pattern
- Learning curve: Team already understands TablesEntities pattern
- Bootstrap inconsistency: Third-party tables require custom styling to match Bootstrap 5
- URL sync reimplementation: Would need to rebuild VueUse integration

**Sources:**
- Bootstrap-Vue-Next BTable docs: [official](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table)
- Bootstrap-Vue-Next BPagination docs: [official](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/pagination)

## Supporting Libraries (already present)

These dependencies already exist in package.json and support admin panel features:

| Library | Version | Used For |
|---------|---------|----------|
| @vueuse/core | 14.1.0 | URL state sync (useUrlSearchParams) |
| axios | 1.13.2 | API calls to admin endpoints |
| pinia | 2.0.14 | Optional state management (if needed) |
| vee-validate | 4.15.1 | Form validation for user CRUD |

**No additional installation needed.**

## What NOT to Add

### Rejected: Component UI Libraries

**DO NOT add:**
- PrimeVue, Element Plus, Vuetify, Ant Design Vue
- Quasar, Naive UI, Headless UI

**Why:**
- Bootstrap-Vue-Next 0.42.0 provides all needed components (BCard, BTable, BButton, BForm*)
- Introducing second component library causes:
  - Visual inconsistency (two design systems)
  - Bundle bloat (+500KB min for full UI library)
  - z-index conflicts (modals, tooltips, dropdowns)
  - Theming complexity (Bootstrap vars vs library vars)
- PROJECT.md explicitly chose Bootstrap-Vue-Next to "minimize visual disruption for researchers/clinicians"

**Exception:** If a specific component is genuinely missing from Bootstrap-Vue-Next, install targeted micro-library, not entire UI framework.

### Rejected: State Management Beyond Pinia

**DO NOT add:**
- Vuex, MobX, XState
- Redux-like patterns

**Why:**
- Pinia 2.0.14 already in dependencies for global state
- Admin views are isolated (user management doesn't share state with ontology management)
- VueUse composables (useUrlSearchParams) sufficient for view-level state
- PROJECT.md notes: "Module-level singleton for useFilterSync - Simpler than Pinia, sufficient for analysis pages"

**Pattern:** Use Pinia ONLY if admin state needs cross-view sharing (e.g., current admin user permissions).

### Rejected: Additional Charting Libraries

**DO NOT add:**
- ApexCharts, ECharts, Highcharts, D3.js, Plotly
- Specialized libraries (Lightweight Charts, Unovis)

**Why:**
- AdminStatistics needs basic charts (line, bar, doughnut), not advanced features
- Chart.js 4.5.1 covers all use cases identified in research
- Adding ApexCharts increases bundle by +80KB for unused features (real-time updates, complex animations)
- D3.js requires DOM manipulation that conflicts with Vue reactivity (PROJECT.md chose Cytoscape over D3 for this reason)

**Exception:** If future milestone adds real-time monitoring dashboard, THEN consider ApexCharts for streaming data.

### Rejected: Date Pickers Beyond Native

**DO NOT add:**
- vue-datepicker, @vuepic/vue-datepicker, Flatpickr
- Moment.js, Luxon, date-fns

**Why:**
- AdminStatistics date filters use `<BFormInput type="date">` (native HTML5)
- Bootstrap 5.3.8 styles native date inputs consistently
- Modern browsers (Chrome, Firefox, Safari, Edge last 2 versions per browserslist) support native date pickers
- Adds complexity: third-party pickers need Bootstrap styling integration

**Exception:** If date range selection (start + end in single widget) becomes UX requirement, THEN add @vuepic/vue-datepicker (lightweight, Vue 3 native).

### Rejected: Rich Text Alternatives

**DO NOT add:**
- TinyMCE, CKEditor, Froala
- Syncfusion Vue Rich Text Editor

**Why:**
- TinyMCE/CKEditor are heavyweight (500KB+) with commercial licensing for advanced features
- TipTap 3.15.3 provides needed WYSIWYG features (headings, bold, italic, lists) at ~80KB
- Syncfusion requires commercial license ($995/year) for company use
- ManageAbout is simple CMS editing, not document authoring (no need for tables, comments, track changes)

**Exception:** None. TipTap covers all identified CMS use cases.

### Rejected: Form Builders

**DO NOT add:**
- FormKit, VeeValidate Form Generator, FormVueLate
- Survey.js, Form.io

**Why:**
- Admin forms (ManageUser, ManageOntology) are CRUD with fixed fields, not dynamic form building
- Bootstrap-Vue-Next provides form components (BFormInput, BFormSelect, BFormTextarea)
- vee-validate 4.15.1 already handles validation
- Form builders add 200-500KB for unused features (conditional logic, multi-step wizards, drag-drop design)

**Pattern:** Use vee-validate + Bootstrap-Vue-Next form components directly.

### Rejected: Data Table Libraries

**DO NOT add:**
- ag-Grid, TanStack Table (Vue Query), vue-good-table
- Tabulator, Handsontable

**Why:**
- TablesEntities pattern already implements:
  - Server-side pagination (cursor-based with page_after)
  - Column sorting (URL-synced)
  - Filtering (per-column + global search)
  - Custom cell rendering (scoped slots)
- ag-Grid Community is 600KB, Enterprise requires license
- TanStack Table requires reimplementing existing URL sync pattern
- Handsontable requires commercial license for production use

**Pattern:** Extend TablesEntities composables (useTableData, useTableMethods) for admin tables.

## Installation Script

```bash
# Charts for AdminStatistics
npm install chart.js vue-chartjs

# Rich text editor for ManageAbout
npm install @tiptap/vue-3 @tiptap/pm @tiptap/starter-kit

# Verify existing dependencies (should already be installed)
# @vueuse/core@14.1.0, axios@1.13.2, vee-validate@4.15.1, pinia@2.0.14
```

**Total bundle impact:** ~130KB gzipped (Chart.js ~50KB, TipTap ~80KB)

## Integration Checklist

- [ ] Install chart.js + vue-chartjs
- [ ] Create `composables/useChartData.ts` for AdminStatistics
- [ ] Install @tiptap packages
- [ ] Create `composables/useEditor.ts` for ManageAbout
- [ ] Verify vee-validate 4.15.1 works with admin forms
- [ ] Copy TablesEntities pattern to ManageUser/ManageOntology/ViewLogs
- [ ] Style TipTap editor with Bootstrap form-control classes
- [ ] Test Chart.js responsive behavior in Bootstrap grid
- [ ] Document admin composables in composables/README (if exists)

## Version Compatibility Matrix

| Library | Vue 3.5.25 | TypeScript 5.9.3 | Bootstrap 5.3.8 | Vite 7.3.1 |
|---------|------------|------------------|-----------------|------------|
| chart.js 4.5.1 | ✓ | ✓ | ✓ | ✓ |
| vue-chartjs 5.3.3 | ✓ | ✓ | ✓ | ✓ |
| @tiptap/vue-3 3.15.3 | ✓ | ✓ | ✓ | ✓ |

**Verified:** All recommended libraries published within last 3 months (as of 2026-01-25), actively maintained.

## Migration Notes (for roadmap)

**Phase 1: AdminStatistics**
- Install Chart.js packages
- Create useChartData composable
- Replace static numbers with Line/Bar/Doughnut charts
- Keep existing date filter (BFormInput type="date")

**Phase 2: ManageAbout**
- Install TipTap packages
- Create useEditor composable
- Replace empty template with TipTap EditorContent
- Add save endpoint (POST /api/admin/about)

**Phase 3: User/Ontology/Logs Tables**
- NO new installations
- Copy TablesEntities.vue → ManageUser.vue (rename, adjust endpoints)
- Reuse useTableData, useTableMethods composables
- Add role management dropdown to ManageUser
- Add date range to ViewLogs

**Phase 4: Testing**
- Unit test chart data transformation (Vitest + Vue Test Utils)
- Integration test TipTap save operation
- Verify table pagination URL sync works for admin endpoints

## Performance Considerations

**Bundle size (production build):**
- Current app bundle: 520 KB gzipped (from PROJECT.md)
- After admin additions: ~650 KB gzipped (+130KB)
- Still under 1MB threshold for good LCP (Largest Contentful Paint)

**Code splitting:**
- Lazy load admin routes (already using Vue Router lazy loading)
- Chart.js tree-shaking: import only needed chart types
- TipTap extensions: load only StarterKit for ManageAbout

**Runtime performance:**
- Chart.js canvas rendering: 60fps for <100 data points (admin stats are aggregated, not per-entity)
- TipTap ProseMirror: handles 10,000+ word documents (About page ~500 words)
- BTable with pagination: 10-50 rows per page (no virtualization needed)

## Accessibility (WCAG 2.2 AA)

**Chart.js:**
- Provide `aria-label` on canvas: "Chart showing entity trends over time"
- Include table fallback for screen readers (BTable with same data)
- Use distinct colors + patterns (not color-only for categorical data)

**TipTap:**
- Editor has `role="textbox"` and `aria-label="About page content editor"`
- Toolbar buttons need `aria-label` (Bold, Italic, Heading)
- Keyboard shortcuts (Cmd+B for bold) work out-of-box

**Tables (existing pattern):**
- BTable generates semantic HTML (thead, tbody, th scope="col")
- Sort buttons have aria-sort attributes
- Pagination has aria-label="Pagination navigation"

## Security Considerations

**Admin endpoints (R/Plumber API):**
- All admin views require authentication (JWT in localStorage)
- require_auth middleware already validates admin role
- ManageAbout save operation: sanitize HTML server-side (prevent XSS)

**TipTap XSS prevention:**
- Configure allowed HTML tags: `<p>, <h1-h6>, <ul>, <ol>, <li>, <strong>, <em>, <blockquote>`
- Disallow `<script>, <iframe>, <object>, <embed>`
- Server-side validation with DOMPurify or equivalent

**Chart.js:**
- No user input rendering (only server data)
- Validate numeric data types server-side

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| Chart.js version | HIGH | npm (verified 4.5.1, published Oct 2025) |
| vue-chartjs version | HIGH | npm (verified 5.3.3, published Oct 2025) |
| TipTap version | HIGH | npm (verified 3.15.3, published Jan 2026) |
| Bootstrap integration | HIGH | Official docs, MDBootstrap tutorials |
| Rejection of alternatives | HIGH | Multiple sources, ecosystem analysis |
| Bundle size estimates | MEDIUM | Based on typical gzipped sizes, need actual build verification |

## Sources

**Charting:**
- [Chart.js npm](https://www.npmjs.com/package/chart.js)
- [vue-chartjs npm](https://www.npmjs.com/package/vue-chartjs)
- [Best Chart Libraries for Vue 2026 - Weavelinx](https://weavelinx.com/best-chart-libraries-for-vue-projects-in-2026/)
- [Which Vue Chart Library To Use in 2025 - Luzmo](https://www.luzmo.com/blog/vue-chart-libraries)
- [Bootstrap 5 Charts - MDBootstrap](https://mdbootstrap.com/docs/standard/data/charts/)
- [Integrate Bootstrap 5 Tabs With Chart.js - Envato Tuts+](https://webdesign.tutsplus.com/how-to-integrate-bootstrap-5-tabs-with-chartjs--cms-107864t)

**Rich Text Editing:**
- [@tiptap/vue-3 npm](https://www.npmjs.com/package/@tiptap/vue-3)
- [TipTap Vue 3 Installation](https://tiptap.dev/docs/editor/getting-started/install/vue3)
- [Which Rich Text Editor Framework - Liveblocks 2025](https://liveblocks.io/blog/which-rich-text-editor-framework-should-you-choose-in-2025)
- [Migrate from Quill - TipTap docs](https://tiptap.dev/docs/guides/migrate-from-quill)
- [md-editor-v3 npm](https://www.npmjs.com/package/md-editor-v3)
- [@vueup/vue-quill npm](https://www.npmjs.com/package/@vueup/vue-quill)

**Tables:**
- [Bootstrap-Vue-Next BTable docs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table)
- [Bootstrap-Vue-Next BPagination docs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/pagination)

**Admin Patterns:**
- [Vue 3 Dynamic Routes User and Admin Role-Based Access Control](https://copyprogramming.com/howto/c-vuejs-dynamic-route-user-and-admin)
- [Implementing Role-Based Access Control in VueJS - Permify](https://permify.co/post/implementing-role-based-access-control-in-vue-js/)

**Anti-patterns:**
- [Dashboard Anti-Patterns: 12 Mistakes - StartingBlockOnline](https://startingblockonline.org/dashboard-anti-patterns-12-mistakes-and-the-patterns-that-replace-them/)
- [Vue.js Performance Best Practices](https://vuejs.org/guide/best-practices/performance)
- [CoreUI Vue Admin Template](https://coreui.io/product/free-vue-admin-template/)

---

**Ready for roadmap creation.** Stack additions are minimal (2 libraries), prescriptive (specific versions with rationale), and aligned with existing patterns (Bootstrap, Composition API, VueUse).
