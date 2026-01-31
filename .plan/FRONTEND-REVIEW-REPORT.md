# SysNDD Frontend Review Report

**Date:** 2026-01-21
**Reviewer:** Senior Frontend Developer
**Scope:** Vue.js Frontend Application (`app/`)
**Last Updated:** 2026-01-21 (Verified against actual implementation)

---

## Executive Summary

The SysNDD frontend is a **functional Vue 2.7 Single Page Application** serving as a neurodevelopmental disorders database interface. While the codebase demonstrates reasonable organization and some good practices, it has accumulated significant technical debt through organic growth without consistent architectural patterns. The application faces **critical security risks** due to its reliance on end-of-life dependencies (Vue 2, Node 16, BootstrapVue) and known vulnerable packages (axios 0.21.4).

**Overall Rating: 4.8/10** *(Revised from 5.1 after detailed verification)*

### Migration Decision

**Target Stack: Vue 3 + bootstrap-vue-next + Vite + TypeScript**

This migration path was selected to:
- Address critical security concerns (EOL dependencies, known CVEs)
- Minimize UI rewrite scope through API compatibility
- Maintain Bootstrap design language users are familiar with
- Enable modern tooling (Vite, TypeScript, Composition API)
- Improve developer experience and bundle performance

**Estimated Total Effort: 14-20 weeks** *(Revised upward due to scope of DRY violations)*

---

## 1. Technology Stack Analysis

### Current Stack

| Technology | Version | Status | EOL/Support | Risk Level |
|------------|---------|--------|-------------|------------|
| Vue.js | 2.7.8 | End of Life | Dec 31, 2023 | 🔴 Critical |
| Node.js | 16 (implied) | End of Life | Sep 11, 2023 | 🔴 Critical |
| Bootstrap-Vue | 2.21.2 | End of Life | No Vue 3 support | 🔴 Critical |
| Bootstrap | 4.6.0 | Maintenance | Bootstrap 5 available | 🟡 Medium |
| Vue Router | 3.5.3 | End of Life | Vue Router 4 for Vue 3 | 🔴 Critical |
| Pinia | 2.0.14 | Current | Compatible with Vue 2/3 | 🟢 Good |
| VeeValidate | 3.4.14 | Legacy | v4 for Vue 3 | 🟡 Medium |
| D3.js | 7.4.2 | Current | Framework agnostic | 🟢 Good |
| **Axios** | **0.21.4** | **Vulnerable** | **Multiple CVEs** | 🔴 **Critical** |
| Vue CLI | 5.0.8 | Maintenance | Vite recommended | 🟡 Medium |
| ESLint | 6.8.0 | Outdated | v8+ available | 🟡 Medium |

### Verified Dependency Health Rating: 2/10

**Critical Security Issues (Verified):**

1. **Axios 0.21.4** - Multiple known vulnerabilities ([Snyk Report](https://security.snyk.io/package/npm/axios/0.21.4)):
   - [CVE-2022-1214](https://nvd.nist.gov/products/cpe/search/results?namingFormat=2.3&orderBy=2.3&keyword=cpe:2.3:a:axios:axios:0.21.4) (High Severity)
   - ReDoS vulnerability - O(n²) regex complexity
   - XSRF-TOKEN disclosure vulnerability
   - SSRF and credential leakage risks
   - Data URI DoS vulnerability (unbounded memory allocation)
   - **Recommended:** Upgrade to axios 1.12.0+

2. **Vue 2 reached EOL** December 2023 - no security patches

3. **Node 16 EOL** since September 2023

4. **BootstrapVue** - abandoned, no Vue 3 path

---

## 2. Code Quality Assessment

### 2.1 Project Structure (Verified)

```
app/src/
├── assets/js/
│   ├── classes/submission/    # Data models (7 files)
│   ├── constants/             # Configuration constants (5 files)
│   ├── mixins/                # Vue mixins (8 files)
│   ├── services/              # API service layer (1 file)
│   └── eventBus.js            # ⚠️ Vue 2 Event Bus (anti-pattern)
├── components/
│   ├── analyses/              # Data visualizations (15+ files)
│   ├── small/                 # Reusable components (12 files)
│   └── tables/                # Table components (4 files)
├── views/                     # Page components (~35 files)
├── router/                    # Routing configuration
├── plugins/                   # Plugin configuration
└── config/                    # App configuration
```

**Structure Rating: 6/10** *(Revised from 7/10)*

**Strengths:**
- Clear separation between views and components
- Logical grouping by feature domain
- Constants centralized for maintainability
- Service layer abstraction exists (apiService.js)
- Lazy loading with webpack chunks implemented

**Weaknesses (Verified):**
- No dedicated `stores/` directory - Pinia installed but **not used**
- No TypeScript files (0 .ts files found)
- Mixins should be converted to composables
- No test infrastructure whatsoever
- 35+ icon components manually registered in main.js

---

### 2.2 DRY (Don't Repeat Yourself) Analysis

**Rating: 3/10** *(Revised from 6/10 after verification)*

**Critical DRY Violation Verified:**

**Route Guard Duplication** - **30 occurrences** of nearly identical authentication logic:

```javascript
// Repeated 30 times in routes.js with only allowed_roles array changing
beforeEnter: (to, from, next) => {
  const allowed_roles = ['Administrator', 'Curator'];  // varies
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
}
```

**Impact:** ~400 lines of duplicated code that could be reduced to ~20 lines with a factory function.

**Recommended Fix:**
```javascript
// utils/routeGuards.js
export const createRoleGuard = (allowedRoles) => (to, from, next) => {
  const user = localStorage.user ? JSON.parse(localStorage.user) : null;
  const token = localStorage.token;
  const now = Math.floor(Date.now() / 1000);

  if (!user || !token || now > user.exp || !allowedRoles.includes(user.user_role?.[0])) {
    return next({ name: 'Login' });
  }
  next();
};

// Usage
beforeEnter: createRoleGuard(['Administrator', 'Curator'])
```

**Other DRY Issues:**
- 35 icon components individually registered instead of dynamic registration
- Filter object structures duplicated across table components

---

### 2.3 KISS (Keep It Simple, Stupid) Analysis

**Rating: 5/10**

**Complexity Issues (Verified):**

1. **Manual Icon Registration** - 35 individual Vue.component() calls in main.js:
   ```javascript
   Vue.component('BIconPersonCircle', BIconPersonCircle);
   Vue.component('BIconEmojiSmile', BIconEmojiSmile);
   // ... 33 more
   ```
   **Better:** Dynamic registration or tree-shaking with build tools

2. **Mixin Overload** - Components use 4-6 mixins:
   ```javascript
   mixins: [
     toastMixin, urlParsingMixin, colorAndSymbolsMixin,
     textMixin, tableMethodsMixin, tableDataMixin
   ]
   ```
   **Issue:** Hidden dependencies, naming conflicts, difficult debugging

3. **Event Bus Pattern** - Global event system via Vue instance:
   ```javascript
   // eventBus.js
   const EventBus = new Vue();
   export default EventBus;
   ```
   **Issue:** Doesn't work in Vue 3, causes memory leaks if not cleaned up

---

### 2.4 SOLID Principles Analysis

**Rating: 4/10** *(Revised from 5/10)*

| Principle | Rating | Notes |
|-----------|--------|-------|
| **S**ingle Responsibility | 4/10 | Home.vue: 755 lines handling stats, news, animation, banner, search |
| **O**pen/Closed | 6/10 | Slot-based customization is good |
| **L**iskov Substitution | N/A | Not applicable (no class inheritance) |
| **I**nterface Segregation | 4/10 | Mixins inject unused methods into components |
| **D**ependency Inversion | 3/10 | Direct localStorage access, process.env scattered everywhere |

**Specific Issues (Verified):**

1. **No Abstraction for Auth State:**
   ```javascript
   // Scattered throughout codebase
   if (localStorage.token) {
     expires = JSON.parse(localStorage.user).exp;
     user_role = JSON.parse(localStorage.user).user_role;
   }
   ```

2. **Environment Variables Hardcoded:**
   ```javascript
   `${process.env.VUE_APP_API_URL}/api/${endpoint}`
   `${process.env.VUE_APP_URL + this.$route.path}`
   ```

---

### 2.5 Modularization Analysis

**Rating: 5/10** *(Revised from 6/10)*

**Good:**
- Component-based architecture
- Lazy loading with webpack chunks (40+ routes with code splitting)
- Feature-based directory organization
- Constants centralized in dedicated files

**Critical Issues:**
- **Pinia installed but NOT used** - No store files found
- No feature modules/domains
- State management is component-local only
- No shared composables (still using Vue 2 mixins)

---

## 3. Anti-Patterns Identified (Verified)

### 3.1 Critical Anti-Patterns

| Anti-Pattern | Severity | Location | Verified | Impact |
|--------------|----------|----------|----------|--------|
| **Event Bus** | 🔴 Critical | `eventBus.js` | ✅ Yes | Memory leaks, Vue 3 incompatible |
| **localStorage for Auth** | 🔴 Critical | `routes.js` (30 places) | ✅ Yes | XSS vulnerability |
| **$forceUpdate()** | 🟡 Medium | `Home.vue:685` | ✅ Yes | Performance issues |
| **Disabled ESLint Rules** | 🟡 Medium | `.eslintrc.json` | ✅ Yes | Code quality degradation |
| **Duplicated Route Guards** | 🔴 Critical | `routes.js` | ✅ Yes (30x) | Maintenance nightmare |
| **No Tests** | 🔴 Critical | Entire codebase | ✅ Yes (0 tests) | No regression safety |
| **Manual Icon Registration** | 🟡 Medium | `main.js` | ✅ Yes (35 icons) | Bundle bloat |

### 3.2 Detailed Anti-Pattern Analysis

**1. Event Bus Pattern (Vue 3 Incompatible)**
```javascript
// src/assets/js/eventBus.js
import Vue from 'vue';
const EventBus = new Vue();
export default EventBus;
```
- **Risk:** Event listeners not cleaned up cause memory leaks
- **Vue 3 Impact:** This pattern is completely broken in Vue 3
- **Fix:** Replace with Pinia stores or provide/inject

**2. LocalStorage for Sensitive Data (30 occurrences)**
```javascript
// routes.js - Token and user data in localStorage
if (localStorage.token) {
  expires = JSON.parse(localStorage.user).exp;
  user_role = JSON.parse(localStorage.user).user_role;
}
```
- **Risk:** XSS attacks can access localStorage
- **Better:** HttpOnly cookies or secure session management

**3. Force Update Anti-Pattern**
```javascript
// Home.vue:683-686
onUpdate: () => {
  after[i].n = Math.round(after[i].n);
  this.$forceUpdate();
},
```
- **Risk:** Bypasses Vue's reactivity, causes performance hit
- **Fix:** Use reactive data properly

**4. Disabled ESLint Rules (Verified)**
```json
{
  "no-unused-vars": "off",      // Dead code accumulates
  "camelcase": "off",           // Inconsistent naming
  "max-len": "off",             // Unreadable long lines
  "no-param-reassign": "off",   // Mutation bugs
  "no-shadow": "off",           // Variable confusion
  "no-console": "off"           // Production console logs
}
```

---

## 4. Testing Assessment

### Test Coverage Rating: 0/10

**Verified Findings:**
- **0 test files** (.spec.js or .test.js)
- No Jest/Vitest configuration
- No test runner in package.json scripts
- No E2E testing setup (Cypress/Playwright)

**Recommended Testing Stack for Vue 3 Migration:**
```bash
# Unit/Component Testing
npm install -D vitest @vue/test-utils happy-dom

# E2E Testing
npm install -D @playwright/test
```

---

## 5. Migration Assessment

### 5.1 Vue 2 to Vue 3 Migration

**Complexity Rating: HIGH (8/10)**

**Breaking Changes Affecting This Codebase:**

| Change | Impact | Occurrences |
|--------|--------|-------------|
| Event Bus removal | 🔴 Critical | All EventBus usage |
| v-model changes | 🟡 Medium | Forms, inputs |
| Vue.prototype removal | 🔴 Critical | Global axios, meta |
| Composition API | 🟡 Medium | All 77+ components |
| Vue Router 4 | 🔴 Critical | 40+ routes |
| Global component registration | 🟡 Medium | 35+ icons |

**Migration Effort (Revised):**
- **Minimum (compat mode):** 3-5 weeks
- **Full migration (Composition API):** 10-14 weeks
- **Including tests:** Add 4-6 weeks

### 5.2 UI Library Migration: bootstrap-vue-next

**Selected Path:** Vue 3 + [bootstrap-vue-next](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)

**Current Status (January 2026):**
- Version: 0.42.0+
- Status: Alpha/Pre-1.0 ([npm](https://www.npmjs.com/package/bootstrap-vue-next))
- 35+ components available
- Active development with regular releases

**Key Advantages:**
- Similar API to current BootstrapVue minimizes rewrite scope
- Maintains Bootstrap styling users are familiar with
- First-class TypeScript support
- Bootstrap 5 features and utilities
- WAI-ARIA accessibility markup included

**Considerations:**
- Pre-1.0 status requires version pinning
- Not a drop-in replacement - some API differences exist
- [Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide) available

### 5.3 Build Tool Migration: Vue CLI to Vite

**Recommended:** Migrate to [Vite](https://vuejs.org/guide/scaling-up/tooling) as recommended by Vue team

**Benefits ([Vue School Guide](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)):**
- Instant server start (no bundling during dev)
- Lightning-fast HMR
- Smaller production bundles
- Native ES modules
- Better TypeScript support

**Migration Steps ([Official Recommendations](https://v3-migration.vuejs.org/recommendations)):**
1. Remove Vue CLI dependencies
2. Add explicit .vue extensions to imports
3. Update environment variables (VUE_APP_ → VITE_)
4. Move index.html to root
5. Install @vitejs/plugin-vue

---

## 6. Risk Assessment Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Security vulnerabilities (axios) | 🔴 Certain | 🔴 Critical | Upgrade axios immediately |
| Vue 2 security issues | 🔴 High | 🔴 Critical | Migrate to Vue 3 |
| Node 16 incompatibility | 🔴 High | 🟡 High | Upgrade to Node 20 LTS |
| BootstrapVue abandonment | 🔴 Certain | 🟡 High | Migrate to bootstrap-vue-next |
| Breaking changes during migration | 🟡 High | 🟡 High | Incremental migration, add tests first |
| Regression bugs (no tests) | 🔴 High | 🔴 Critical | Add test coverage before migration |

---

## 7. Migration Strategy: Vue 3 + bootstrap-vue-next + Vite

### Phase 0: Pre-Migration Hardening (1-2 weeks)
1. **CRITICAL:** Upgrade axios to 1.12.0+ (security fix)
2. Add basic test infrastructure (Vitest + Vue Test Utils)
3. Create auth guard factory function (DRY fix)
4. Document all EventBus usages for Pinia migration
5. Enable stricter ESLint rules incrementally

### Phase 1: Foundation (2-3 weeks)
1. Upgrade Node.js to 20 LTS
2. Update non-breaking dependencies (D3, GSAP)
3. Add TypeScript configuration (tsconfig.json)
4. Create Pinia stores for auth state
5. Add unit tests for critical paths

### Phase 2: Vue 3 Migration (5-7 weeks)
1. Install Vue 3 migration build
2. Run migration linter to identify issues
3. Remove Event Bus, replace with Pinia
4. Update route guards to Vue Router 4 navigation guards
5. Migrate mixins to composables incrementally
6. Switch from Vue CLI to Vite

### Phase 3: UI Library Migration (4-6 weeks)
1. Install bootstrap-vue-next
2. Create component migration checklist
3. Migrate components incrementally (start with simple ones)
4. Update Bootstrap 4 classes to Bootstrap 5
5. Remove old BootstrapVue

### Phase 4: Cleanup & Polish (2 weeks)
1. Remove deprecated code and compat shims
2. Add comprehensive TypeScript types
3. Performance optimization (bundle analysis)
4. Add E2E tests with Playwright
5. Documentation update

**Total Estimated Effort: 14-20 weeks**

---

## 8. Ratings Summary

| Category | Rating | Change | Notes |
|----------|--------|--------|-------|
| **Project Structure** | 6/10 | ↓1 | Good organization, but Pinia unused, no TS |
| **Code Quality** | 4/10 | ↓1 | ESLint disabled, many anti-patterns |
| **DRY Compliance** | 3/10 | ↓3 | 30 duplicated route guards, 35 manual icons |
| **KISS Compliance** | 5/10 | = | Over-engineered in places |
| **SOLID Compliance** | 4/10 | ↓1 | Poor dependency inversion, SRP violations |
| **Modularization** | 5/10 | ↓1 | Pinia installed but unused |
| **Security** | 2/10 | ↓2 | axios CVEs, localStorage auth, XSS risk |
| **Maintainability** | 4/10 | ↓1 | Technical debt, EOL dependencies |
| **Performance** | 6/10 | = | Lazy loading good, force updates bad |
| **Test Coverage** | 0/10 | ↓2 | Zero tests verified |

**Overall Score: 4.8/10** *(Revised from 5.1)*

---

## 9. Priority Action Items

### Immediate (Before Any Other Work)
| Priority | Task | Risk Addressed | Effort |
|----------|------|----------------|--------|
| P0 | Upgrade axios to 1.12.0+ | CVE-2022-1214, ReDoS, SSRF | 1 hour |
| P0 | Add .nvmrc with Node 20 | Runtime compatibility | 5 mins |

### Short-Term (This Sprint)
| Priority | Task | Risk Addressed | Effort |
|----------|------|----------------|--------|
| P1 | Create route guard factory function | 30x code duplication | 2 hours |
| P1 | Add Vitest + basic test setup | Zero test coverage | 4 hours |
| P1 | Enable `no-unused-vars` ESLint rule | Dead code | 2 hours |

### Medium-Term (Before Migration)
| Priority | Task | Risk Addressed | Effort |
|----------|------|----------------|--------|
| P2 | Create Pinia auth store | localStorage scattered usage | 1 day |
| P2 | Replace Event Bus with Pinia | Vue 3 incompatibility | 2 days |
| P2 | Add tests for critical paths | Regression risk | 1 week |

### Long-Term (Migration)
| Priority | Task | Risk Addressed | Effort |
|----------|------|----------------|--------|
| P3 | Migrate to Vue 3 | EOL framework | 5-7 weeks |
| P3 | Migrate to Vite | Vue CLI maintenance mode | 1 week |
| P3 | Migrate to bootstrap-vue-next | EOL UI library | 4-6 weeks |
| P3 | Add TypeScript | Type safety | 2-3 weeks |

---

## 10. Best Practices References

### Vue 3 & Composition API
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Composition API vs Options API](https://vuejs.org/guide/extras/composition-api-faq.html) - [Vue School Comparison](https://vueschool.io/articles/vuejs-tutorials/options-api-vs-composition-api/)
- [Composables Best Practices](https://vuejs.org/guide/reusability/composables)
- [Mixins are No Longer Recommended](https://vuejs.org/api/options-composition#mixins)

### Build Tools
- [Vue Tooling Recommendations](https://vuejs.org/guide/scaling-up/tooling) - Vite recommended
- [Vue CLI to Vite Migration](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)
- [Vite vs Vue CLI](https://enterprisevue.dev/blog/vite-vs-vue-cli/)

### UI Libraries
- [bootstrap-vue-next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)
- [bootstrap-vue-next Migration Guide](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/migration-guide)
- [bootstrap-vue-next GitHub](https://github.com/bootstrap-vue-next/bootstrap-vue-next)

### Security
- [axios 0.21.4 Vulnerabilities](https://security.snyk.io/package/npm/axios/0.21.4)
- [CVE Details for Axios](https://www.cvedetails.com/product/54129/Axios-Axios.html)

---

## Appendix A: Verified Code Samples

### A.1 Route Guard Duplication (30 occurrences in routes.js)
```javascript
// Lines 334-349, 362-377, 384-399, 406-421, 428-443, ...
beforeEnter: (to, from, next) => {
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

### A.2 Event Bus Anti-Pattern (eventBus.js)
```javascript
import Vue from 'vue';
const EventBus = new Vue();
export default EventBus;
```

### A.3 Force Update Anti-Pattern (Home.vue:683-686)
```javascript
onUpdate: () => {
  after[i].n = Math.round(after[i].n);
  this.$forceUpdate();
},
```

### A.4 Manual Icon Registration (main.js:99-135)
```javascript
Vue.component('BIconPersonCircle', BIconPersonCircle);
Vue.component('BIconEmojiSmile', BIconEmojiSmile);
// ... 33 more individual registrations
```

---

*Report verified against SysNDD frontend codebase on 2026-01-21.*
*All ratings based on actual code inspection and current best practices.*
