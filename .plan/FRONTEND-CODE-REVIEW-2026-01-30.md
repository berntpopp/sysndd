# SysNDD Frontend Code Review Report

**Date:** January 30, 2026
**Reviewer:** Senior Frontend Engineer (AI-Assisted Analysis)
**Application:** SysNDD Vue.js Frontend (`app/` directory)
**Framework:** Vue 3.5.25 + TypeScript 5.9.3 + Vite 7.3.1

---

## Executive Summary

| Metric | Score | Change from Prior Review |
|--------|-------|-------------------------|
| **Overall Score** | **7.4/10** | +0.2 from 7.2 |
| Technology Stack | 8/10 | Improved |
| Code Quality | 7/10 | Stable |
| Vue 3 Patterns | 6/10 | Needs Attention |
| TypeScript | 5/10 | Needs Attention |
| Security | 5/10 | Critical |
| Testing | 6/10 | Improved |
| Performance | 8/10 | Good |
| Accessibility | 7/10 | Good |

### Key Findings Summary

**Positive Changes Since Last Review:**
- Pinia stores increased from 1 to 2 (`ui.ts`, `disclaimer.ts`)
- 33 well-structured composables now exist (up from minimal)
- Good type definitions in `types/` directory (9 type files)
- Excellent Vite configuration with manual chunking
- Accessibility testing infrastructure with vitest-axe
- MSW integration for API mocking

**Critical Issues Remaining:**
- **15 duplicated route guards** still present (unchanged from prior review)
- **223 localStorage occurrences** across 33 files (up from 76)
- **78 Options API components** vs 47 `<script setup>` components (mixed codebase)
- TypeScript strict mode disabled (`strict: false`, `noImplicitAny: false`)
- JWT tokens stored in localStorage (security vulnerability)
- Several very large components (2093 lines max)

---

## 1. Technology Stack Assessment

**Rating: 8/10**

### Dependency Health Analysis

| Package | Current | Status | Risk Level |
|---------|---------|--------|------------|
| vue | ^3.5.25 | Current | Low |
| vue-router | ^4.6.0 | Current | Low |
| pinia | ^2.0.14 | Outdated | Medium |
| vite | ^7.3.1 | Current | Low |
| typescript | ^5.9.3 | Current | Low |
| vitest | ^4.0.18 | Current | Low |
| bootstrap-vue-next | ^0.42.0 | Beta | Medium |
| axios | ^1.13.2 | Current | Low |
| chart.js | ^4.5.1 | Current | Low |
| d3 | ^7.4.2 | Slightly Outdated | Low |
| xlsx | ^0.18.5 | Current | Low |
| ngl | ^2.4.0 | Current | Low |

### vite.config.ts Review

**File:** `/home/bernt-popp/development/sysndd/app/vite.config.ts`

**Strengths:**
```typescript
// Lines 162-174: Excellent manual chunk splitting
manualChunks: {
  vendor: ['vue', 'vue-router', 'pinia'],
  bootstrap: ['bootstrap', 'bootstrap-vue-next'],
  viz: ['d3', '@upsetjs/bundle', 'gsap'],
  ngl: ['ngl'],
},
```

- PWA configuration with proper manifest
- Bundle visualizer integration
- Proper API proxy configuration for Docker
- Hidden source maps for security (`sourcemap: 'hidden'`)

**Areas for Improvement:**
```typescript
// Line 115: Options API still enabled - consider disabling after migration
__VUE_OPTIONS_API__: true,
```

### Recommendations

1. **Update Pinia** to latest version (^2.1.x) for better TypeScript support
2. **Monitor bootstrap-vue-next** - it's still in beta, track for stable release
3. Consider adding `vite-plugin-compression` for gzip/brotli precompression

---

## 2. Code Quality Analysis

**Rating: 7/10**

### 2.1 Project Structure

**File:** `/home/bernt-popp/development/sysndd/app/src/`

```
src/
├── assets/           # Static assets, SCSS, legacy JS
│   ├── js/
│   │   ├── classes/  # Legacy submission classes (JS)
│   │   ├── constants/ # Configuration constants
│   │   └── services/  # API service (TypeScript)
│   └── scss/
├── components/       # Reusable components
│   ├── accessibility/ # A11y components (good!)
│   ├── analyses/     # Data visualization
│   ├── forms/        # Form components + wizard
│   ├── gene/         # Gene-specific components
│   ├── navigation/   # Navigation components
│   ├── small/        # Small reusable components
│   ├── tables/       # Table components
│   └── ui/           # UI primitives (badges, icons)
├── composables/      # 33 composables (excellent!)
├── config/           # App configuration
├── plugins/          # Vue plugins (legacy axios.js)
├── router/           # Vue Router
├── stores/           # Pinia stores (2 stores)
├── test-utils/       # Testing utilities
├── types/            # TypeScript definitions (9 files)
├── utils/            # Utility functions
└── views/            # Route views
    ├── admin/        # Admin views
    ├── analyses/     # Analysis views
    ├── curate/       # Curation views
    ├── help/         # Help/documentation
    ├── pages/        # Entity/Gene/Search pages
    ├── review/       # Review views
    └── tables/       # Table views
```

**Assessment:** Good separation of concerns. The `composables/` directory shows modern Vue 3 patterns. However, legacy code in `assets/js/` needs migration.

### 2.2 DRY Violations - Duplicated Route Guards

**File:** `/home/bernt-popp/development/sysndd/app/src/router/routes.ts`

**Critical Issue: 15 Identical Navigation Guards**

The same authentication check pattern is duplicated 15 times across routes:

```typescript
// Lines 355-370, 383-398, 405-420, etc. (15 occurrences)
beforeEnter: (to: RouteLocationNormalized, from: RouteLocationNormalized, next: NavigationGuardNext) => {
  const allowed_roles = ['Administrator', 'Curator', 'Reviewer'];
  let expires = 0;
  let timestamp = 0;
  let user_role = 'Viewer';

  if (localStorage.token) {
    expires = JSON.parse(localStorage.user).exp;
    user_role = JSON.parse(localStorage.user).user_role;
    timestamp = Math.floor(new Date().getTime() / 1000);
  }

  if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
    next({ name: 'Login' });
  } else next();
},
```

**Impact:**
- ~250 lines of duplicated code
- Maintenance burden
- Inconsistent error handling risk

### 2.3 localStorage Access Pattern Analysis

**223 localStorage occurrences across 33 files**

| File | Count | Risk |
|------|-------|------|
| `router/routes.ts` | 65 | High - auth tokens |
| `components/AppNavbar.vue` | 8 | Medium |
| `views/curate/*.vue` | Multiple | High |
| `stores/disclaimer.ts` | 9 | Low - non-sensitive |
| `composables/useFormDraft.ts` | 8 | Medium |

### 2.4 KISS Violations - Overly Complex Components

**Components exceeding 300 lines (ordered by size):**

| Component | Lines | Issue |
|-----------|-------|-------|
| `ApproveReview.vue` | 2,093 | Should be split into subcomponents |
| `ManageUser.vue` | 1,692 | Admin complexity |
| `Review.vue` | 1,579 | Mixed concerns |
| `ModifyEntity.vue` | 1,537 | Form + logic combined |
| `AnalyseGeneClusters.vue` | 1,338 | Visualization + data |
| `ApproveStatus.vue` | 1,330 | Should use shared form logic |
| `GeneStructurePlotWithVariants.vue` | 1,324 | D3 logic should be composable |
| `TablesPhenotypes.vue` | 1,262 | Table logic can be extracted |
| `ManageReReview.vue` | 1,210 | Similar to other admin views |

**`$forceUpdate()` Usage Found:**

**File:** `/home/bernt-popp/development/sysndd/app/src/views/HomeView.vue` (Line 598)

```javascript
// Line 597-598
onUpdate: () => {
  after[i].n = Math.round(after[i].n);
  this.$forceUpdate();  // Anti-pattern: forces re-render
},
```

This indicates the reactivity system isn't being used correctly. GSAP animations should update reactive properties directly.

### 2.5 SOLID Assessment

**Single Responsibility Violations:**
- Large view components handling multiple concerns
- `routes.ts` contains both routing AND authentication logic

**Dependency Injection:**
- 66 files use Vue's `provide`/`inject` pattern
- Good adoption of DI patterns in composables

### 2.6 Modularization Statistics

| Category | Count | Assessment |
|----------|-------|------------|
| Pinia Stores | 2 | Needs expansion |
| Composables | 33 | Excellent |
| Type Files | 9 | Good |
| Test Files | 17 | Needs expansion |

---

## 3. Vue 3 Specific Patterns

**Rating: 6/10**

### Component API Style Distribution

| Style | Count | Percentage |
|-------|-------|------------|
| Options API (`export default {}`) | 78 | 62.4% |
| Composition API (`<script setup>`) | 47 | 37.6% |
| **Total** | 125 | 100% |

**File:** `/home/bernt-popp/development/sysndd/app/src/views/HomeView.vue`

Example of hybrid pattern (setup() with Options API):
```javascript
// Lines 458-485
export default {
  name: 'HomeView',
  components: { /* ... */ },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    // ...
    return { makeToast, ...colorAndSymbols };
  },
  data() {
    return { /* reactive data */ };
  },
  methods: {
    async loadStatistics() { /* ... */ }
  }
};
```

### Modern Pattern Adoption

**Good Examples:**

**File:** `/home/bernt-popp/development/sysndd/app/src/stores/ui.ts`
```typescript
// Lines 13-35: Modern Pinia setup syntax
export const useUiStore = defineStore('ui', () => {
  const scrollbarUpdateTrigger: Ref<number> = ref(0);

  function requestScrollbarUpdate(): void {
    scrollbarUpdateTrigger.value++;
  }

  return {
    scrollbarUpdateTrigger,
    requestScrollbarUpdate,
  };
});
```

**File:** `/home/bernt-popp/development/sysndd/app/src/composables/useToast.ts`

Well-structured composable with clear naming convention (`useXxx`).

### Composables Quality Assessment

**Excellent composables (33 total):**
- `useColorAndSymbols.ts` - Style mappings
- `useTableData.ts` - Table state management
- `useCytoscape.ts` - Network visualization
- `useAriaLive.ts` - Accessibility announcements
- `useD3Lollipop.ts` - D3 visualization
- `use3DStructure.ts` - NGL viewer integration

**All composables properly exported via barrel file:**

**File:** `/home/bernt-popp/development/sysndd/app/src/composables/index.ts`
```typescript
// Lines 13-124: Clean barrel exports with types
export { default as useToastNotifications } from './useToastNotifications';
export { default as useToast } from './useToast';
export type { CytoscapeOptions, CytoscapeState } from './useCytoscape';
// ...
```

---

## 4. TypeScript Assessment

**Rating: 5/10**

### File Type Distribution

| Type | Count | Percentage |
|------|-------|------------|
| `.ts` files | 83 | 86.5% |
| `.js` files | 13 | 13.5% |
| **Total** | 96 | 100% |

### Legacy JavaScript Files Requiring Migration

**File:** `/home/bernt-popp/development/sysndd/app/src/plugins/axios.js`
```javascript
// Lines 1-49: Legacy Vue 2 style axios plugin
import Vue from 'vue';  // Still using Vue 2 import!
import axios from 'axios';

Vue.use(plugin);  // Vue 2 plugin pattern
```

**Other legacy files:**
- `assets/js/functions.js`
- `assets/js/utils.js`
- `assets/js/classes/submission/*.js` (7 files)
- `registerServiceWorker.js`
- `bootstrap-vue-next-components.js`

### tsconfig.json Analysis

**File:** `/home/bernt-popp/development/sysndd/app/tsconfig.json`

**Critical Issues:**
```json
{
  "compilerOptions": {
    "strict": false,        // CRITICAL: Should be true
    "noImplicitAny": false, // CRITICAL: Should be true
    "allowJs": true,        // Acceptable during migration
  }
}
```

### `any` Type Usage

Only **2 occurrences** found:

**File:** `/home/bernt-popp/development/sysndd/app/src/composables/use3DStructure.ts`
```typescript
// Limited any usage - good discipline
```

### Type Definitions Quality

**File:** `/home/bernt-popp/development/sysndd/app/src/types/api.ts`

Excellent API type definitions:
```typescript
// Lines 24-47: Well-structured generic types
export interface ApiResponse<T> {
  meta: StatisticsMeta[];
  data: T;
}

export interface PaginatedResponse<T> {
  meta: StatisticsMeta[];
  data: T[];
  page?: number;
  page_size?: number;
  total?: number;
}
```

---

## 5. Security Analysis

**Rating: 5/10 - CRITICAL**

### 5.1 Authentication Token Storage

**CRITICAL VULNERABILITY: JWT tokens stored in localStorage**

**File:** `/home/bernt-popp/development/sysndd/app/src/plugins/axios.js` (Line 6)
```javascript
axios.defaults.headers.common.Authorization = `Bearer ${localStorage.getItem('token')}`;
```

**File:** `/home/bernt-popp/development/sysndd/app/src/router/routes.ts` (Lines 361-363)
```typescript
if (localStorage.token) {
  expires = JSON.parse(localStorage.user).exp;
  user_role = JSON.parse(localStorage.user).user_role;
}
```

**Risk:** XSS attacks can steal authentication tokens from localStorage.

### 5.2 localStorage Sensitive Data Analysis

| Pattern | Occurrences | Files | Risk |
|---------|-------------|-------|------|
| `localStorage.token` | 65 | routes.ts | Critical |
| `localStorage.user` | 65 | routes.ts | Critical |
| `localStorage.getItem('token')` | 5 | Multiple | Critical |
| Non-sensitive (disclaimer, drafts) | ~88 | Various | Low |

### 5.3 v-html Usage Analysis

**File:** `/home/bernt-popp/development/sysndd/app/src/components/filters/TermSearch.vue` (Lines 28-29)
```html
<!-- eslint-disable-next-line vue/no-v-html -- content is generated internally by highlightMatch(), no user input -->
<span class="suggestion-text" v-html="highlightMatch(suggestion)"></span>
```

**Assessment:** Properly documented with ESLint disable comment. Uses internal data only (safe).

**Good Pattern Found:**

**File:** `/home/bernt-popp/development/sysndd/app/src/components/gene/VariantTooltip.vue` (Lines 3-5)
```html
<!--
  Uses structured data props instead of v-html to avoid XSS vulnerabilities.
-->
```

### 5.4 Axios Interceptor Configuration

**File:** `/home/bernt-popp/development/sysndd/app/src/plugins/axios.js` (Lines 17-28)

```javascript
// Interceptors are minimal - no error handling, no token refresh
_axios.interceptors.request.use(
  (config) => config,  // No-op
  (error) => Promise.reject(error),
);

_axios.interceptors.response.use(
  (response) => response,  // No-op
  (error) => Promise.reject(error),
);
```

**Missing:**
- Token refresh logic
- 401 handling with redirect to login
- Error normalization

---

## 6. Testing Assessment

**Rating: 6/10**

### Test Infrastructure

**File:** `/home/bernt-popp/development/sysndd/app/vitest.config.ts`

```typescript
// Lines 31-37: Coverage thresholds
thresholds: {
  lines: 40,
  functions: 40,
  branches: 40,
  statements: 40,
},
```

**40% coverage threshold is low** - should target 70-80% for critical paths.

### Test File Analysis

| Type | Count | Coverage |
|------|-------|----------|
| Composable Unit Tests | 5 | Good |
| Component Tests | 4 | Needs expansion |
| A11y Tests | 8 | Excellent initiative |
| **Total** | 17 | Insufficient |

### Test Files Inventory

```
composables/
├── useColorAndSymbols.spec.ts
├── useText.spec.ts
├── useUrlParsing.spec.ts
├── useToast.spec.ts
└── useModalControls.spec.ts

components/
├── AppFooter.spec.ts
├── AppFooter.a11y.spec.ts
├── small/FooterNavItem.spec.ts
├── small/FooterNavItem.a11y.spec.ts
├── small/AppBanner.spec.ts
└── small/AppBanner.a11y.spec.ts

views/
├── review/Review.a11y.spec.ts
├── curate/ApproveReview.a11y.spec.ts
├── curate/ApproveStatus.a11y.spec.ts
├── curate/ApproveUser.a11y.spec.ts
├── curate/ManageReReview.a11y.spec.ts
└── curate/ModifyEntity.a11y.spec.ts
```

### Untested Critical Paths

| Component/Feature | Risk Level |
|-------------------|------------|
| `apiService.ts` | High |
| `router/routes.ts` (guards) | High |
| `stores/ui.ts` | Medium |
| `stores/disclaimer.ts` | Medium |
| All view components | High |
| Form wizard steps | High |
| Table components | Medium |

### Test Setup Quality

**File:** `/home/bernt-popp/development/sysndd/app/vitest.setup.ts`

**Excellent setup:**
```typescript
// Lines 12-14: vitest-axe integration
expect.extend(matchers);

// Lines 36-51: localStorage mock
const localStorageMock = (() => { /* ... */ })();

// Lines 57-62: MSW server setup
beforeAll(() => {
  server.listen({ onUnhandledRequest: 'warn' });
});
```

---

## 7. Performance Analysis

**Rating: 8/10**

### Chunk Splitting Configuration

**File:** `/home/bernt-popp/development/sysndd/app/vite.config.ts` (Lines 162-174)

```typescript
manualChunks: {
  vendor: ['vue', 'vue-router', 'pinia'],      // ~150KB
  bootstrap: ['bootstrap', 'bootstrap-vue-next'], // ~300KB
  viz: ['d3', '@upsetjs/bundle', 'gsap'],      // Lazy-loaded
  ngl: ['ngl'],                                  // Lazy-loaded 3D viewer
},
```

**Assessment:** Excellent separation of critical vs lazy-loaded chunks.

### Route-Level Lazy Loading

**File:** `/home/bernt-popp/development/sysndd/app/src/router/routes.ts`

All routes use dynamic imports:
```typescript
// Line 11, 22, 41, etc.
component: () => import('@/views/HomeView.vue'),
component: () => import('@/views/tables/EntitiesTable.vue'),
component: () => import('@/views/tables/GenesTable.vue'),
```

### Large Component Optimization Opportunities

| Component | Lines | Recommendation |
|-----------|-------|----------------|
| `ApproveReview.vue` | 2,093 | Extract form sections to subcomponents |
| `ManageUser.vue` | 1,692 | Use composables for user logic |
| `AnalyseGeneClusters.vue` | 1,338 | Extract D3 logic to composable |

### Dependency Prebundling

```typescript
// Lines 154-156
optimizeDeps: {
  include: ['xlsx', 'ngl'],  // Heavy deps prebundled
},
```

---

## 8. Accessibility (a11y)

**Rating: 7/10**

### ARIA Usage Statistics

| Pattern | Occurrences | Files |
|---------|-------------|-------|
| `aria-*` attributes | 376 | 68 |
| `role=` attributes | 78 | 33 |

### Accessibility Components

**File:** `/home/bernt-popp/development/sysndd/app/src/components/accessibility/`

```
accessibility/
├── AriaLiveRegion.vue    # Live region announcements
├── IconLegend.vue        # Visual legend for icons
└── SkipLink.vue          # Skip navigation link
```

### vitest-axe Integration

**File:** `/home/bernt-popp/development/sysndd/app/vitest.setup.ts` (Lines 4-14)

```typescript
/// <reference types="vitest-axe/extend-expect" />
import * as matchers from 'vitest-axe/matchers';
expect.extend(matchers);
```

### A11y Test Examples

**File:** `/home/bernt-popp/development/sysndd/app/src/components/AppFooter.a11y.spec.ts`
```typescript
// Uses toHaveNoViolations matcher
expect(results).toHaveNoViolations();
```

### Missing A11y Patterns

- No keyboard navigation tests
- No screen reader announcements for dynamic content (beyond AriaLiveRegion)
- Color contrast verification not automated

---

## 9. Anti-Pattern Detection

### Summary Table

| Anti-Pattern | Found | Severity | Location |
|--------------|-------|----------|----------|
| Event Bus | 1 mention | Low | `stores/ui.ts` (being replaced) |
| Mixins | 4 files | Low | CSS files (acceptable) |
| `$refs` for data flow | 7 files | Medium | Various |
| `$forceUpdate()` | 1 file | High | `HomeView.vue` |
| Magic strings | Many | Medium | Route guards |
| Nested callbacks | Few | Low | Various |
| Prop drilling | N/A | N/A | Uses provide/inject |

### `$refs` Usage

**Files with `$refs`:**
1. `App.vue`
2. `views/review/Review.vue`
3. `views/curate/ApproveStatus.vue`
4. `views/curate/ApproveReview.vue`
5. `components/analyses/AnalyseGeneClusters.vue`
6. `views/curate/ModifyEntity.vue`
7. `components/tables/TablesPhenotypes.vue`

### Magic Strings in Route Guards

**File:** `/home/bernt-popp/development/sysndd/app/src/router/routes.ts` (Line 289-298)

```typescript
// Magic strings for validation
if (['All', 'Limited', 'Definitive', 'Moderate', 'Refuted'].includes(categoryInput)) {
  // ...
}
```

Should use constants from `role_constants.ts`.

---

## 10. Scoring Summary

| Category | Score | Weight | Weighted |
|----------|-------|--------|----------|
| Technology Stack | 8/10 | 15% | 1.20 |
| Code Quality | 7/10 | 20% | 1.40 |
| Vue 3 Patterns | 6/10 | 15% | 0.90 |
| TypeScript | 5/10 | 10% | 0.50 |
| Security | 5/10 | 15% | 0.75 |
| Testing | 6/10 | 10% | 0.60 |
| Performance | 8/10 | 10% | 0.80 |
| Accessibility | 7/10 | 5% | 0.35 |
| **TOTAL** | | 100% | **7.4/10** |

---

## 11. Best Practice Improvements

### 11.1 Pinia Authentication Store Best Practices

Based on research from [Building Modular Store Architecture with Pinia](https://medium.com/@vasanthancomrads/building-modular-store-architecture-with-pinia-in-large-vue-apps-0131e3d05430) and [Pinia Documentation](https://pinia.vuejs.org/core-concepts/actions.html):

**Recommended Implementation for SysNDD:**

```typescript
// stores/auth.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import type { Ref, ComputedRef } from 'vue';

interface User {
  user_name: string;
  user_role: string[];
  email: string;
  exp: number;
  abbreviation: string;
  orcid?: string;
}

const STORAGE_KEY = 'sysndd-auth';

export const useAuthStore = defineStore('auth', () => {
  // State
  const user: Ref<User | null> = ref(null);
  const token: Ref<string | null> = ref(null);
  const returnUrl: Ref<string | null> = ref(null);

  // Computed
  const isAuthenticated: ComputedRef<boolean> = computed(() => {
    if (!token.value || !user.value) return false;
    const now = Math.floor(Date.now() / 1000);
    return user.value.exp > now;
  });

  const userRole: ComputedRef<string> = computed(() =>
    user.value?.user_role?.[0] ?? 'Viewer'
  );

  const hasRole = (roles: string[]): boolean =>
    roles.includes(userRole.value);

  // Actions
  function login(userData: User, authToken: string): void {
    user.value = userData;
    token.value = authToken;
    persistState();
  }

  function logout(): void {
    user.value = null;
    token.value = null;
    clearPersistedState();
  }

  function setReturnUrl(url: string): void {
    returnUrl.value = url;
  }

  // Persistence
  function persistState(): void {
    try {
      // Note: For enhanced security, consider HttpOnly cookies instead
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
        user: user.value,
        token: token.value,
      }));
    } catch { /* Storage unavailable */ }
  }

  function loadPersistedState(): void {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        user.value = parsed.user;
        token.value = parsed.token;
      }
    } catch {
      clearPersistedState();
    }
  }

  function clearPersistedState(): void {
    sessionStorage.removeItem(STORAGE_KEY);
  }

  // Initialize from storage
  loadPersistedState();

  return {
    // State
    user,
    token,
    returnUrl,
    // Computed
    isAuthenticated,
    userRole,
    // Methods
    hasRole,
    login,
    logout,
    setReturnUrl,
  };
});
```

**Key Improvements:**
- Centralized auth state management
- Type-safe role checking with `hasRole()` method
- Session expiry validation in computed property
- Return URL handling for post-login redirect
- Uses `sessionStorage` (more secure than `localStorage` for tokens)

### 11.2 Vue 3 Script Setup Migration

Based on the [Official Vue 3 Migration Guide](https://v3-migration.vuejs.org/) and [TatvaSoft Migration Guide](https://www.tatvasoft.com/outsourcing/2025/03/vue-2-to-vue-3-migration.html):

**Migration Path for SysNDD:**

**Before (Current HomeView.vue pattern):**
```javascript
export default {
  name: 'HomeView',
  components: { SearchCombobox, CategoryIcon },
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return { entity_statistics: INIT_OBJ.ENTITY_STAT_INIT };
  },
  computed: {
    last_update() { /* ... */ }
  },
  methods: {
    async loadStatistics() { /* ... */ }
  }
};
```

**After (Modern script setup):**
```vue
<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import { useToast, useColorAndSymbols, useText } from '@/composables';
import SearchCombobox from '@/components/small/SearchCombobox.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import apiService from '@/assets/js/services/apiService';
import INIT_OBJ from '@/assets/js/constants/init_obj_constants';
import type { StatisticsResponse } from '@/types/api';

// Composables
const { makeToast } = useToast();
const { inheritance_overview_text, ndd_icon_text } = useColorAndSymbols();
const { inheritance_link } = useText();

// State
const entity_statistics = ref<StatisticsResponse>(INIT_OBJ.ENTITY_STAT_INIT);
const gene_statistics = ref<StatisticsResponse>(INIT_OBJ.GENE_STAT_INIT);
const loadingStates = ref({ statistics: false, news: false });

// Computed
const last_update = computed(() => {
  if (!entity_statistics.value?.meta?.[0]?.last_update) {
    return 'Data not available';
  }
  return new Date(entity_statistics.value.meta[0].last_update).toLocaleDateString();
});

// Methods
async function loadStatistics(): Promise<void> {
  loadingStates.value.statistics = true;
  try {
    entity_statistics.value = await apiService.fetchStatistics('entity');
    gene_statistics.value = await apiService.fetchStatistics('gene');
  } catch (e) {
    makeToast(e as Error, 'Error', 'danger');
  } finally {
    loadingStates.value.statistics = false;
  }
}

// Lifecycle
onMounted(() => {
  loadStatistics();
});

// Head management
useHead({
  title: 'Home',
  meta: [
    { name: 'description', content: 'The Home view...' },
  ],
});
</script>
```

**Migration Priority (based on file size and complexity):**
1. Small UI components first (`ui/`, `small/`)
2. Composables (already TypeScript, just need type improvements)
3. Views with simple logic
4. Complex views last (after testing infrastructure improves)

### 11.3 Vue Router Navigation Guards Factory Pattern

Based on [Vue Router Navigation Guards Documentation](https://router.vuejs.org/guide/advanced/navigation-guards.html) and [Route Meta Fields](https://router.vuejs.org/guide/advanced/meta.html):

**Recommended Guard Factory for SysNDD:**

```typescript
// router/guards.ts
import type { NavigationGuardWithThis, RouteLocationNormalized } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

type Role = 'Administrator' | 'Curator' | 'Reviewer' | 'Viewer';

interface AuthGuardOptions {
  roles: Role[];
  redirectTo?: string;
}

/**
 * Factory function to create role-based navigation guards
 * Replaces 15 duplicated guard implementations
 */
export function createAuthGuard(options: AuthGuardOptions): NavigationGuardWithThis<undefined> {
  const { roles, redirectTo = 'Login' } = options;

  return (_to, _from) => {
    const authStore = useAuthStore();

    // Check if authenticated
    if (!authStore.isAuthenticated) {
      authStore.setReturnUrl(_to.fullPath);
      return { name: redirectTo };
    }

    // Check if user has required role
    if (!authStore.hasRole(roles)) {
      return { name: redirectTo };
    }

    return true; // Allow navigation
  };
}

// Pre-built guards for common role combinations
export const requiresReviewer = createAuthGuard({
  roles: ['Administrator', 'Curator', 'Reviewer'],
});

export const requiresCurator = createAuthGuard({
  roles: ['Administrator', 'Curator'],
});

export const requiresAdmin = createAuthGuard({
  roles: ['Administrator'],
});
```

**Updated routes.ts usage:**
```typescript
// router/routes.ts
import { requiresReviewer, requiresCurator, requiresAdmin } from './guards';

export const routes: RouteRecordRaw[] = [
  // ... public routes

  {
    path: '/Review',
    name: 'Review',
    component: () => import('@/views/review/Review.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: requiresReviewer,  // Clean, reusable
  },
  {
    path: '/CreateEntity',
    name: 'CreateEntity',
    component: () => import('@/views/curate/CreateEntity.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: requiresCurator,
  },
  {
    path: '/ManageUser',
    name: 'ManageUser',
    component: () => import('@/views/admin/ManageUser.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: requiresAdmin,
  },
];
```

### 11.4 Vue 3 Vitest Component Testing Best Practices

Based on [Vue.js Testing Guide](https://vuejs.org/guide/scaling-up/testing), [Vitest Component Testing](https://vitest.dev/guide/browser/component-testing), and [Vue 3 Testing Pyramid](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/):

**Recommended Testing Patterns for SysNDD:**

```typescript
// tests/components/GeneBadge.spec.ts
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/vue';
import userEvent from '@testing-library/user-event';
import GeneBadge from '@/components/ui/GeneBadge.vue';

describe('GeneBadge', () => {
  // Test behavior, not implementation
  it('renders gene symbol with link', async () => {
    render(GeneBadge, {
      props: {
        symbol: 'BRCA1',
        hgncId: 'HGNC:1100',
        linkTo: '/Genes/HGNC:1100',
      },
    });

    // Use accessible selectors
    const link = screen.getByRole('link', { name: /BRCA1/i });
    expect(link).toHaveAttribute('href', '/Genes/HGNC:1100');
  });

  // Test user interactions
  it('shows tooltip on hover', async () => {
    const user = userEvent.setup();
    render(GeneBadge, {
      props: { symbol: 'TP53', hgncId: 'HGNC:11998' },
    });

    const badge = screen.getByText('TP53');
    await user.hover(badge);

    // Check tooltip appears
    expect(await screen.findByRole('tooltip')).toBeInTheDocument();
  });

  // Test edge cases
  it('truncates long symbols', () => {
    render(GeneBadge, {
      props: { symbol: 'VERY_LONG_GENE_SYMBOL', maxLength: 10 },
    });

    expect(screen.getByText(/VERY_LONG\.\.\./)).toBeInTheDocument();
  });
});
```

**Composable Testing Pattern:**
```typescript
// tests/composables/useAuthStore.spec.ts
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useAuthStore } from '@/stores/auth';

describe('useAuthStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.stubGlobal('sessionStorage', {
      getItem: vi.fn(),
      setItem: vi.fn(),
      removeItem: vi.fn(),
    });
  });

  it('returns false for isAuthenticated when no user', () => {
    const store = useAuthStore();
    expect(store.isAuthenticated).toBe(false);
  });

  it('validates token expiry', () => {
    const store = useAuthStore();
    const futureExp = Math.floor(Date.now() / 1000) + 3600;

    store.login(
      { user_name: 'test', user_role: ['Curator'], exp: futureExp },
      'mock-token'
    );

    expect(store.isAuthenticated).toBe(true);
  });

  it('checks role authorization correctly', () => {
    const store = useAuthStore();
    store.login(
      { user_name: 'test', user_role: ['Reviewer'], exp: Date.now() + 3600 },
      'token'
    );

    expect(store.hasRole(['Administrator', 'Curator'])).toBe(false);
    expect(store.hasRole(['Reviewer'])).toBe(true);
  });
});
```

### 11.5 Vue.js Security - HttpOnly Cookies

Based on [Authentication in SPA the Right Way](https://medium.com/@jcbaey/authentication-in-spa-reactjs-and-vuejs-the-right-way-e4a9ac5cd9a3), [VueJS JWT HttpOnly Cookie](https://github.com/Naveen512/VueJS.Jwt.HttpOnly.Cookie), and [Cookies vs Local Storage](https://www.permit.io/blog/cookies-vs-local-storage):

**Security Hardening Recommendations for SysNDD:**

**Current Vulnerability:**
```javascript
// plugins/axios.js (VULNERABLE)
axios.defaults.headers.common.Authorization = `Bearer ${localStorage.getItem('token')}`;
```

**Recommended Secure Implementation:**

1. **Backend Changes (R Plumber API):**
```r
# Set HttpOnly cookie on login
plumber::res$setCookie(
  "access_token",
  jwt_token,
  httpOnly = TRUE,
  secure = TRUE,      # HTTPS only
  sameSite = "Strict" # CSRF protection
)
```

2. **Frontend Changes:**
```typescript
// services/authService.ts
import axios from 'axios';

const authAxios = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  withCredentials: true, // CRITICAL: Include cookies
});

// No need to manually set Authorization header
// Browser automatically sends HttpOnly cookies

export async function login(credentials: LoginCredentials): Promise<User> {
  const response = await authAxios.post('/api/auth/login', credentials);
  // Token is set as HttpOnly cookie by backend
  return response.data.user;
}

export async function logout(): Promise<void> {
  await authAxios.post('/api/auth/logout');
  // Backend clears the HttpOnly cookie
}
```

3. **Axios Interceptor for Token Refresh:**
```typescript
// plugins/axios.ts
import axios from 'axios';
import { useAuthStore } from '@/stores/auth';
import router from '@/router';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  withCredentials: true,
});

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Handle 401 Unauthorized
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // Attempt token refresh (backend sets new cookie)
        await axios.post('/api/auth/refresh', {}, { withCredentials: true });
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed - logout user
        const authStore = useAuthStore();
        authStore.logout();
        router.push({ name: 'Login' });
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default apiClient;
```

4. **Migration Path:**
   - Phase 1: Add `withCredentials: true` to axios
   - Phase 2: Backend adds HttpOnly cookie alongside localStorage token
   - Phase 3: Frontend migrates to cookie-based auth
   - Phase 4: Remove localStorage token storage

### 11.6 Vite Vue 3 Bundle Optimization

Based on [Vite Build Options](https://vite.dev/config/build-options), [Reducing Bundle Size](https://medium.com/@m9hmood/getting-the-most-out-of-vite-tips-for-reducing-vue-3-bundle-size-and-improving-performance-76961e727bb3), and [Vite Code Splitting Discussion](https://github.com/vitejs/vite/discussions/17730):

**Current Configuration (Already Good):**
```typescript
// vite.config.ts - Lines 162-174
manualChunks: {
  vendor: ['vue', 'vue-router', 'pinia'],
  bootstrap: ['bootstrap', 'bootstrap-vue-next'],
  viz: ['d3', '@upsetjs/bundle', 'gsap'],
  ngl: ['ngl'],
},
```

**Enhanced Configuration for SysNDD:**
```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { visualizer } from 'rollup-plugin-visualizer';
import { compression } from 'vite-plugin-compression2';

export default defineConfig({
  plugins: [
    vue(),
    // Gzip/Brotli pre-compression
    compression({
      algorithm: 'gzip',
      threshold: 10240, // Only compress files > 10KB
    }),
    compression({
      algorithm: 'brotliCompress',
    }),
    // Bundle analysis
    visualizer({
      filename: './dist/stats.html',
      gzipSize: true,
      brotliSize: true,
    }),
  ],

  build: {
    target: 'es2022', // Modern browsers only
    sourcemap: 'hidden',
    chunkSizeWarningLimit: 500,
    cssCodeSplit: true,

    rollupOptions: {
      output: {
        manualChunks: (id) => {
          // Vendor chunks
          if (id.includes('node_modules')) {
            if (id.includes('vue') || id.includes('pinia')) {
              return 'vendor-vue';
            }
            if (id.includes('bootstrap')) {
              return 'vendor-bootstrap';
            }
            if (id.includes('d3') || id.includes('gsap')) {
              return 'vendor-viz';
            }
            if (id.includes('ngl')) {
              return 'vendor-3d';
            }
            if (id.includes('xlsx')) {
              return 'vendor-excel';
            }
            if (id.includes('chart.js') || id.includes('cytoscape')) {
              return 'vendor-charts';
            }
            return 'vendor-misc';
          }

          // Feature-based splitting for large components
          if (id.includes('/views/admin/')) {
            return 'feature-admin';
          }
          if (id.includes('/views/curate/')) {
            return 'feature-curate';
          }
          if (id.includes('/components/analyses/')) {
            return 'feature-analyses';
          }
          if (id.includes('/components/gene/')) {
            return 'feature-gene';
          }
        },

        // Consistent chunk naming
        chunkFileNames: 'js/[name]-[hash].js',
        entryFileNames: 'js/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      },
    },
  },

  // Optimize specific dependencies
  optimizeDeps: {
    include: ['xlsx', 'ngl', 'cytoscape', 'd3'],
    exclude: ['@vueuse/core'], // Tree-shakeable
  },
});
```

**Additional Optimizations:**

1. **Tree-shaking Bootstrap:**
```typescript
// Import only needed components
import { BButton, BCard, BTable } from 'bootstrap-vue-next';
// Instead of: import * from 'bootstrap-vue-next';
```

2. **Lazy Load Heavy Features:**
```typescript
// For 3D viewer (NGL)
const ProteinStructure3D = defineAsyncComponent({
  loader: () => import('@/components/gene/ProteinStructure3D.vue'),
  loadingComponent: LoadingSkeleton,
  delay: 200,
});
```

---

## 12. Prioritized Action Items

### Quick Wins (1-2 days each)

| Priority | Task | Impact | Effort |
|----------|------|--------|--------|
| 1 | Create route guard factory | High | Low |
| 2 | Enable TypeScript strict mode incrementally | High | Low |
| 3 | Add `vite-plugin-compression2` | Medium | Low |
| 4 | Remove `$forceUpdate()` from HomeView | Medium | Low |
| 5 | Migrate axios.js to TypeScript | Medium | Low |

### Short-term (1-2 weeks)

| Priority | Task | Impact | Effort |
|----------|------|--------|--------|
| 1 | Create Pinia auth store | Critical | Medium |
| 2 | Migrate 10 smallest components to `<script setup>` | Medium | Medium |
| 3 | Add unit tests for apiService | High | Medium |
| 4 | Add unit tests for auth store | High | Medium |
| 5 | Split ApproveReview.vue into subcomponents | High | Medium |

### Medium-term (1-2 months)

| Priority | Task | Impact | Effort |
|----------|------|--------|--------|
| 1 | Implement HttpOnly cookie authentication | Critical | High |
| 2 | Migrate remaining 60+ Options API components | High | High |
| 3 | Achieve 70% test coverage | High | High |
| 4 | Migrate legacy JS classes to TypeScript | Medium | High |
| 5 | Add E2E tests for critical paths | High | High |

---

## 13. Sources

### Official Documentation
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Pinia Documentation - Actions](https://pinia.vuejs.org/core-concepts/actions.html)
- [Vue Router Navigation Guards](https://router.vuejs.org/guide/advanced/navigation-guards.html)
- [Vue Router Route Meta Fields](https://router.vuejs.org/guide/advanced/meta.html)
- [Vitest Component Testing](https://vitest.dev/guide/browser/component-testing)
- [Vue.js Testing Guide](https://vuejs.org/guide/scaling-up/testing)
- [Vite Build Options](https://vite.dev/config/build-options)

### Community Resources
- [Building Modular Store Architecture with Pinia](https://medium.com/@vasanthancomrads/building-modular-store-architecture-with-pinia-in-large-vue-apps-0131e3d05430)
- [Vue 3 + Pinia JWT Authentication](https://jasonwatmore.com/post/2022/05/26/vue-3-pinia-jwt-authentication-tutorial-example)
- [Authentication in SPA the Right Way](https://medium.com/@jcbaey/authentication-in-spa-reactjs-and-vuejs-the-right-way-e4a9ac5cd9a3)
- [Vue 3 Testing Pyramid with Vitest](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/)
- [Unit Testing Vue 3 Components with Vitest](https://medium.com/@vasanthancomrads/unit-testing-vue-3-components-with-vitest-and-testing-library-part-1-554d86aa1797)
- [Reducing Bundle Size in Vite](https://medium.com/@m9hmood/getting-the-most-out-of-vite-tips-for-reducing-vue-3-bundle-size-and-improving-performance-76961e727bb3)
- [Vite Code Splitting Discussion](https://github.com/vitejs/vite/discussions/17730)
- [VueJS JWT HttpOnly Cookie Example](https://github.com/Naveen512/VueJS.Jwt.HttpOnly.Cookie)
- [Cookies vs Local Storage Comparison](https://www.permit.io/blog/cookies-vs-local-storage)
- [Vue 2 to Vue 3 Migration - TatvaSoft](https://www.tatvasoft.com/outsourcing/2025/03/vue-2-to-vue-3-migration.html)

---

## Appendix: File Reference Index

| Section | Key Files |
|---------|-----------|
| Configuration | `vite.config.ts`, `tsconfig.json`, `vitest.config.ts` |
| Routing | `router/routes.ts`, `router/index.ts` |
| State Management | `stores/ui.ts`, `stores/disclaimer.ts` |
| API Service | `assets/js/services/apiService.ts` |
| Types | `types/index.ts`, `types/api.ts`, `types/models.ts` |
| Composables | `composables/index.ts` (33 composables) |
| Test Setup | `vitest.setup.ts`, `test-utils/` |
| Large Components | `views/curate/ApproveReview.vue` (2093 lines) |
| Security Concern | `plugins/axios.js` (legacy, uses localStorage) |
