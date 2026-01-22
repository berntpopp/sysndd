# Frontend Review Report: SysNDD

**Reviewed:** 2026-01-22
**Reviewer perspective:** Senior UI/UX Designer specializing in medical/scientific web applications
**Production URL:** https://sysndd.dbmr.unibe.ch/

---

## Executive Summary

SysNDD is a well-structured Vue 2.7 application with Bootstrap-Vue that serves its core purpose effectively: presenting curated gene-disease relationships for neurodevelopmental disorders. The current design is **functional and professional** but shows its age (Bootstrap 4 aesthetic, circa 2018-2020).

**Key recommendation:** Evolutionary modernization, not revolution. The information architecture is solid; the visual layer needs refinement. A Vue 3 + TypeScript migration is worthwhile but should be planned as a **separate milestone** due to significant effort required.

---

## Current State Analysis

### Technology Stack

| Component | Current | Status |
|-----------|---------|--------|
| Vue.js | 2.7.8 | End of life (Dec 2023), security risk |
| Bootstrap | 4.6.0 | Maintained but outdated |
| Bootstrap-Vue | 2.21.2 | No Vue 3 support, abandoned |
| Node.js | 20 LTS | Current (good) |
| State Management | Pinia 2.0.14 | Modern (good) |
| Build | Vue CLI 5 + Webpack | Functional but Vite preferred |

### Codebase Metrics

- **50+ Vue components** (39 views, 12+ small components)
- **708 lines** in routes.js (lazy-loaded)
- **7 mixins** for shared logic
- **0 TypeScript files** (100% JavaScript)
- **0 test files** (no frontend testing)

---

## UI/UX Assessment (Medical Web App Perspective)

### What Works Well

1. **Information hierarchy is clear**
   - Entity → Gene → Disease → Inheritance → Category
   - Color-coded badges provide instant visual parsing
   - Stoplight icons (green/yellow/red) are intuitive for evidence categories

2. **Data density is appropriate**
   - Tables show essential columns without overwhelming
   - Tooltips provide additional context on hover
   - Expandable rows for detailed inheritance breakdowns

3. **Navigation is logical**
   - Tables / Analyses / Help structure is standard
   - Breadcrumb-style URLs (e.g., `/Entities/4`, `/Genes/HGNC:61`)
   - Search is prominent and contextual

4. **Accessibility basics present**
   - Semantic HTML structure
   - Alt text on images
   - Keyboard-navigable tables

5. **Trust signals**
   - Institutional logos in footer (DFG, University of Bern, ERN ITHACA)
   - Clear usage policy and data privacy notice
   - Version number displayed

### Areas Needing Improvement

#### Visual Design Issues

| Issue | Current | Recommendation |
|-------|---------|----------------|
| **Gradient background** | Pink-to-mint gradient feels dated | Subtle neutral gradient or solid with texture |
| **Card borders** | Hard black borders on cards | Softer shadows, reduced border emphasis |
| **Badge colors** | Non-standard palette (purple primary, green secondary) | Align with medical UI conventions |
| **Typography** | Default Bootstrap, no hierarchy refinement | Increase contrast, improve line height |
| **Whitespace** | Cramped in data tables | More padding, breathing room |
| **Loading states** | Basic spinner text | Skeleton loaders for perceived speed |

#### UX Issues

| Issue | Impact | Recommendation |
|-------|--------|----------------|
| **No empty states** | Confusion when no results | Add helpful empty state illustrations |
| **Filter visibility** | Column filters easily missed | Sticky filter row or filter panel |
| **Mobile experience** | Tables stack awkwardly | Responsive card view alternative |
| **Search feedback** | No autocomplete suggestions | Add typeahead with recent/popular |
| **Error handling** | Toast notifications only | Inline error messages for context |

---

## Detailed Visual Recommendations

### Color Palette Modernization

**Current issues:**
- Primary blue (`#1565c0`) is good but used inconsistently
- Badge colors override Bootstrap defaults in custom.css with non-standard choices
- Pink highlight (`#eaadba`) for `<mark>` feels informal for medical context

**Recommended palette (medical/scientific standard):**

```scss
// Primary - Trust/Authority
$primary: #1565C0;        // Keep current blue
$primary-light: #E3F2FD;  // Backgrounds

// Secondary - Information
$secondary: #546E7A;      // Blue-grey (calmer than pure grey)

// Semantic - Evidence Categories
$definitive: #2E7D32;     // Green (high confidence)
$moderate: #F9A825;       // Amber (medium confidence)
$limited: #EF6C00;        // Orange (low confidence)
$refuted: #C62828;        // Red (negative)

// Accents - Entity Components
$gene-badge: #43A047;     // Gene = green (biological)
$inheritance-badge: #1E88E5; // Inheritance = blue (pattern)
$disease-badge: #7B1FA2;  // Disease = purple (clinical)

// Neutrals
$background: #FAFBFC;     // Slight warmth
$surface: #FFFFFF;
$text-primary: #1A1A2E;   // Near-black, not pure black
$text-secondary: #5F6368;
```

### Component Refinements

#### Navbar
- Current: Heavy gradient, cramped logo
- Proposed: Lighter header, more breathing room, sticky on scroll
- Keep: Dark variant for professionalism

#### Cards
- Current: Hard black borders, no shadow depth
- Proposed: Subtle shadow (`0 1px 3px rgba(0,0,0,0.12)`), rounded corners (8px)
- Keep: Header sections for categorization

#### Tables
- Current: Bootstrap default styling, thin separators
- Proposed:
  - Zebra striping with `rgba(0,0,0,0.02)` (barely visible)
  - Sticky headers for long tables
  - Row hover highlight
  - Sort indicators more prominent

#### Badges
- Current: 11px font, 99999px border-radius (full pill)
- Proposed:
  - 12px font for readability
  - 4px border-radius (modern, less "bubble")
  - Consistent padding (4px 8px)
  - Reduced use of pills; reserve for counts

#### Search Bar
- Current: Functional, minimal feedback
- Proposed:
  - Larger input area (48px height)
  - Autocomplete dropdown with categories
  - Recent searches
  - "Press Enter to search" hint

### Layout Improvements

#### Home Page
The home page is information-rich but visually cluttered.

**Current layout:**
```
[Welcome + Search]
[Statistics Card] [Description Text]
[New Entities Card]
```

**Proposed layout:**
```
[Hero: Welcome + Search (full-width, simplified)]
─────────────────────────────────────────
[Quick Stats Bar: 3 key numbers inline]
─────────────────────────────────────────
[New Entities]  |  [About NDD (collapsed)]
                |  [Quick Links]
```

Key changes:
1. Elevate search as the primary action
2. Reduce text density (move to Help/About)
3. Make statistics scannable in one row
4. Collapse educational content by default

#### Entity Detail Page
- Current: Vertical table layout, all information equal weight
- Proposed:
  - Hero section with Gene + Disease + Inheritance
  - Tabbed sections for Phenotypes, Publications, Variation
  - Sticky sidebar for quick stats on desktop

#### Tables View
- Current: Effective but dense
- Proposed:
  - Filter panel option (sidebar, not inline)
  - View toggle: Table / Card view
  - Column visibility customization
  - Batch export with selection

---

## Vue 3 + TypeScript Migration Assessment

### Migration Effort Estimate

Based on codebase analysis and industry benchmarks:

| Factor | Assessment |
|--------|------------|
| Codebase size | 50+ components, 700+ route lines = **Medium** |
| Options API usage | 100% Options API = **High conversion effort** |
| BootstrapVue dependency | Blocking issue = **Critical** |
| Mixin usage | 7 mixins = **Moderate refactoring** |
| TypeScript readiness | 0% typed = **Full type definition work** |

**Estimated effort:** 4-6 weeks for experienced developer

### Migration Blockers

1. **BootstrapVue incompatibility**
   - BootstrapVue does NOT support Vue 3
   - bootstrap-vue-next is in **late alpha** (not production-ready)
   - Options:
     a. Wait for bootstrap-vue-next stable (unknown timeline)
     b. Migrate to different component library (PrimeVue, Vuetify 3, Quasar)
     c. Use plain Bootstrap 5 + custom Vue components

2. **Deprecated dependencies**
   - `vue-meta` → `@unhead/vue` (or native `useHead`)
   - `vue-axios` → native Axios + composables
   - `@vue/composition-api` → native Vue 3
   - `vue2-perfect-scrollbar` → alternative needed

3. **Breaking changes**
   - `this.$set`, `this.$delete` removed
   - Event bus pattern deprecated (use mitt or Pinia)
   - Filters removed (use methods or computed)
   - `v-model` behavior changed

### TypeScript Adoption

**Recommendation: Yes, adopt TypeScript during Vue 3 migration**

Rationale:
- Vue 3 is written in TypeScript, excellent IDE support
- Medical/scientific data benefits from type safety
- Catch data shape errors at compile time (API responses)
- Modern standard for Vue 3 projects

**Effort considerations:**
- Defining types for all API responses (~20 endpoint shapes)
- Component prop typing
- Store typing (Pinia already supports TS)
- Build tooling update (Vite recommended)

### Recommended Migration Path

**Option A: Incremental (Recommended)**
1. Update to Vue 2.7 (already done)
2. Convert components to `<script setup>` + Composition API
3. Add TypeScript incrementally (`.vue` files support TS in Vue 2.7)
4. When bootstrap-vue-next stabilizes, migrate Vue version

**Option B: Full Rewrite**
1. Create new Vue 3 + Vite + TypeScript project
2. Choose new component library (recommendation: **PrimeVue**)
3. Port components one by one
4. Run old/new in parallel during transition

**Option C: UI-Only Modernization (No Vue 3)**
1. Keep Vue 2.7
2. Create custom CSS layer over Bootstrap
3. Replace individual components for modern look
4. Defer Vue 3 until bootstrap-vue-next is stable

---

## Component Library Deep Comparison (SysNDD Requirements)

### SysNDD-Specific Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| DataTable with server-side pagination/filtering/sorting | **Critical** | 4200+ entities, must handle large datasets |
| Minimal visual disruption | **High** | Researchers expect consistency |
| TypeScript support | **High** | Migration goal |
| Accessibility (WCAG 2.2) | **High** | Medical application requirement |
| TreeSelect for ontology hierarchies | **Medium** | Phenotype/disease selection |
| Form validation | **Medium** | Curation workflows |
| Dark mode support | **Low** | Nice to have |

### Library Comparison Matrix

| Criteria | Bootstrap-Vue-Next | PrimeVue | Vuetify 3 | Quasar |
|----------|-------------------|----------|-----------|--------|
| **Version** | 0.42.0 (alpha) | 4.x (stable) | 3.x (stable) | 2.x (stable) |
| **Vue 3 Support** | Native | Native | Native | Native |
| **TypeScript** | First-class | First-class | First-class | First-class |
| **Weekly Downloads** | ~15K | 394K | 717K | 180K |
| **GitHub Stars** | 1.3K | 13.4K | 40.7K | 26.9K |
| **Components** | 35+ | 90+ | 180+ | 70+ |
| **Design System** | Bootstrap 5 | Design agnostic | Material Design 3 | Material Design |
| **DataTable Server-Side** | ✓ (provider func) | ✓ (lazy mode) | ✓ | ✓ (QTable) |
| **Virtual Scrolling** | ⚠️ Limited | ✓ | ✓ | ✓ |
| **Tree Select** | ⚠️ Partial | ✓ TreeSelect | ✓ Treeview | ✓ QTree |
| **Form Validation** | Manual | ✓ Built-in | ✓ Built-in | ✓ Built-in |
| **ARIA/a11y** | ✓ Good | ✓ Excellent | ⚠️ Some issues | ✓ Good |
| **Bundle Size** | ~150KB | ~300KB | ~400KB | ~500KB |
| **Learning Curve** | Low (familiar) | Medium | Medium | High |
| **Migration Effort** | Low | Medium-High | High | High |

### Detailed Analysis

#### Bootstrap-Vue-Next

**Pros:**
- Minimal visual disruption — looks like current SysNDD
- Familiar API for team (if any Bootstrap-Vue experience)
- Smallest bundle size
- TypeScript-first, Vue 3 Composition API native

**Cons:**
- Still in alpha (0.x version)
- Breaking changes happening (BTable in 0.42.0)
- Smaller community, fewer resources
- Some components missing vs original BootstrapVue
- No virtual scrolling for very large datasets

**DataTable (BTable) features:**
- Server-side via provider function
- AbortSignal support for request cancellation
- Sort icons customizable
- Dark mode support restored
- Filtering and pagination built-in

**Best for:** Projects prioritizing visual consistency over feature richness

---

#### PrimeVue

**Pros:**
- Production stable, used by Fortune 500 (Intel, Nvidia, American Express)
- Design agnostic — not locked to Material Design
- Excellent DataTable with lazy loading, virtual scroll
- Best TreeSelect implementation for hierarchical data
- Extensive accessibility (ARIA) support
- 200+ icons included

**Cons:**
- Different component API than Bootstrap-Vue
- Requires restyling to match current look
- Larger bundle (~300KB)
- Some documentation gaps for advanced features

**DataTable features:**
- Lazy loading with `lazy` prop
- Virtual scrolling for 100K+ rows
- Column filtering, global search
- Row expansion, selection, grouping
- Export to CSV/Excel built-in
- Frozen columns support

**Best for:** Data-heavy applications requiring advanced table features

---

#### Vuetify 3

**Pros:**
- Most popular Vue UI library (717K weekly downloads)
- Material Design 3 integration
- Massive community and resources
- Extensive component library (180+)

**Cons:**
- Opinionated Material Design look
- Significant visual change from Bootstrap
- Some WCAG contrast issues reported
- Heavier bundle (~400KB)
- Data table less feature-rich than PrimeVue

**DataTable features:**
- Server-side pagination/sorting
- Row expansion and selection
- Fixed headers
- Custom slots for cells

**Best for:** Projects adopting Material Design aesthetic

---

#### Quasar

**Pros:**
- Cross-platform (web, mobile, desktop, PWA)
- QTable is very powerful and fast
- Virtual scrolling excellent
- Good documentation

**Cons:**
- Steepest learning curve
- Heaviest bundle (~500KB)
- Overkill for web-only project
- Material Design based (visual change)

**QTable features:**
- Virtual scroll for massive datasets
- Server-side operations
- Extensive customization via slots
- Grid mode for card layouts

**Best for:** Multi-platform projects (not SysNDD's use case)

---

### Recommendation for SysNDD

**Primary Recommendation: Bootstrap-Vue-Next**

Rationale:
1. **Minimal disruption** — Researchers and clinicians expect SysNDD to look the same
2. **Lower migration effort** — Similar component API, familiar Bootstrap patterns
3. **Sufficient features** — BTable has server-side support needed for 4200+ entities
4. **Active development** — Regular releases (0.42.0 Dec 2025), 138 contributors
5. **Risk mitigation** — Pin version, upgrade deliberately, contribute fixes if needed

**Secondary Recommendation: PrimeVue**

If bootstrap-vue-next proves problematic during migration OR if advanced features are needed:
- Virtual scrolling for larger datasets in future
- Better TreeSelect for ontology hierarchies
- Theming flexibility with PrimeVue Unstyled + custom CSS

**Migration Strategy:**
1. Start with bootstrap-vue-next
2. Create abstraction layer around table/form components
3. If blockers arise, swap to PrimeVue with minimal changes

---

### Sources

- [PrimeVue DataTable Documentation](https://v3.primevue.org/datatable/)
- [Vuetify Accessibility](https://vuetifyjs.com/en/features/accessibility/)
- [Quasar QTable](https://quasar.dev/vue-components/table/)
- [Bootstrap-Vue-Next Table](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/table)
- [Vue UI Library Comparison](https://medium.com/@jonathanmimi/vuetify-vs-quasar-vs-primevue-choosing-the-right-ui-library-for-your-vue-app-1323db589463)
- [npm trends: primevue vs quasar vs vuetify](https://npmtrends.com/primevue-vs-quasar-vs-vuetify)
- [PrimeVue Enterprise Adoption](https://primetek.hashnode.dev/primevue-vs-vuetify-vs-quasar-vs-bootstrapvue)

---

## Accessibility Audit (WCAG 2.2)

### Passing

- [x] Alt text on images
- [x] Form labels present
- [x] Link text descriptive
- [x] Heading hierarchy exists
- [x] Color not sole indicator (icons + text)

### Needs Attention

- [ ] Color contrast ratios (some badges fail AA)
- [ ] Focus indicators (default browser, not styled)
- [ ] Skip navigation link missing
- [ ] ARIA landmarks incomplete
- [ ] Touch targets on mobile (some buttons < 44px)
- [ ] Screen reader testing (not verified)

### Recommended Quick Wins

1. Add `<main>`, `<nav>`, `<aside>` landmarks
2. Style `:focus-visible` for keyboard users
3. Ensure all interactive elements are 44px minimum touch target
4. Add skip link to main content
5. Run automated audit (axe-core or Lighthouse)

---

## Performance Observations

### Current Bundle
- Vue CLI + Webpack (functional)
- PurgeCSS configured (good)
- Lazy-loaded routes (good)
- Service worker for offline (PWA)

### Recommendations

1. **Migrate to Vite** during Vue 3 migration (10x faster dev server)
2. **Image optimization** - WebP format for logo already used (good)
3. **Code splitting** - Already implemented per-route
4. **API response caching** - Consider SWR pattern for statistics

---

## Milestone Recommendation

### For v3 Milestone: UI Modernization (Without Vue 3)

Focus on visual polish within current stack:

**Scope:**
1. New color palette CSS variables
2. Card shadow and spacing refinements
3. Table styling improvements
4. Search bar enhancement
5. Loading state skeletons
6. Empty state designs
7. Mobile responsive improvements

**Estimated phases:** 2-3 phases

### For v4 Milestone: Vue 3 + TypeScript Migration

Full technical modernization:

**Scope:**
1. Vue 3 + Vite setup
2. Component library decision and integration
3. TypeScript adoption
4. Composition API conversion
5. Test infrastructure

**Estimated phases:** 4-6 phases

---

## Summary Recommendations

| Priority | Recommendation | Effort | Impact |
|----------|---------------|--------|--------|
| **High** | CSS modernization (colors, shadows, spacing) | Low | High |
| **High** | Table UX improvements (filters, sorting) | Medium | High |
| **Medium** | Search enhancement (autocomplete) | Medium | Medium |
| **Medium** | Mobile responsive refinement | Medium | Medium |
| **Low** | Vue 3 migration | High | Medium |
| **Low** | TypeScript adoption | High | Medium |

**Bottom line:** The UI needs a visual refresh more than a technical rewrite. Focus v3 on CSS/UX improvements. Plan Vue 3 migration for v4 when bootstrap-vue-next stabilizes or when committing to a different component library.

---

## Appendix: Screenshots

Screenshots captured during review are saved to:
- `.playwright-mcp/frontend-review-home.png`
- `.playwright-mcp/frontend-review-entities-table.png`
- `.playwright-mcp/frontend-review-entity-detail.png`
- `.playwright-mcp/frontend-review-gene-detail.png`
- `.playwright-mcp/frontend-review-analysis-upset.png`

---

## Sources

- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [BootstrapVueNext Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [BootstrapVue Vue 3 Support Status](https://bootstrap-vue.org/vue3/)
- [Healthcare UX Design Best Practices 2026](https://www.eleken.co/blog-posts/user-interface-design-for-healthcare-applications)
- [Top Healthcare UX/UI Design Trends 2026](https://www.excellentwebworld.com/healthcare-ux-ui-design-trends/)
- [Vue/Nuxt/Vite Status in 2026](https://fivejars.com/insights/vue-nuxt-vite-status-for-2026-risks-priorities-architecture-updates/)

---

*Report generated: 2026-01-22*
