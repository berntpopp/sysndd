# Technology Stack: Vue 3 + TypeScript Migration

**Project:** SysNDD Frontend Migration
**From:** Vue 2.7 + JavaScript + Bootstrap-Vue + Vue CLI/Webpack
**To:** Vue 3 + TypeScript + Bootstrap-Vue-Next + Vite
**Researched:** 2026-01-22
**Overall Confidence:** HIGH

## Executive Summary

This document specifies the exact stack additions and changes needed to migrate SysNDD's Vue 2.7 frontend to Vue 3 + TypeScript + Bootstrap-Vue-Next. All recommendations are based on current stable versions (verified January 2026), official documentation, and established best practices in the Vue ecosystem.

**Key Philosophy:** Prioritize official Vue ecosystem tools with active maintenance, proven TypeScript integration, and minimal visual disruption. Avoid experimental features during migration; adopt stable, production-ready versions only.

---

## Core Framework Migration

### Vue 3.5 (Latest Stable)

| Aspect | Details |
|--------|---------|
| **Current Version** | Vue 2.7.8 |
| **Target Version** | Vue 3.5+ (latest stable as of Jan 2026) |
| **Why Upgrade** | Vue 2 reached EOL Dec 31, 2023. Vue 3 provides better TypeScript integration, Composition API, improved performance, and active ecosystem support. |
| **Confidence** | HIGH (official release, production-ready) |

**Key Changes for SysNDD:**
- **Composition API** - Modern component logic organization (replaces @vue/composition-api backport)
- **`<script setup>`** - Recommended syntax for TypeScript (better type inference, less boilerplate)
- **Better TypeScript** - Framework written in TypeScript, first-class TS support
- **Performance** - Faster reactivity system, smaller bundle size
- **Teleport** - Better modal/overlay handling

**Breaking Changes to Address:**
- Filters removed (use methods/computed)
- `$on`, `$off`, `$once` removed (use mitt or provide/inject)
- Event bus patterns need refactoring

**Installation:**
```bash
npm install vue@latest
```

**Sources:**
- [Releases | Vue.js](https://vuejs.org/about/releases)
- [Vue.js - 2025 In Review and a Peek into 2026 - Vue School](https://vueschool.io/articles/news/vue-js-2025-in-review-and-a-peek-into-2026/)

---

## TypeScript Integration

### TypeScript 5.0+

| Aspect | Details |
|--------|---------|
| **Current** | None (100% JavaScript) |
| **Target Version** | TypeScript 5.7+ (latest stable) |
| **Mode** | Strict mode enabled |
| **Why** | First-class Vue 3 support, better IDE experience, catch bugs at compile time, required for medical app reliability |
| **Confidence** | HIGH (official TypeScript, Vue 3 requires TS 5.0+) |

**Configuration (tsconfig.json):**
```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "jsx": "preserve",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "lib": ["ESNext", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src/**/*.ts", "src/**/*.d.ts", "src/**/*.tsx", "src/**/*.vue"],
  "exclude": ["node_modules"]
}
```

**Key TypeScript Settings:**
- `strict: true` - **MANDATORY** for medical app reliability
- `moduleResolution: "bundler"` - Modern option that works better with Vite
- `noEmit: true` - Type checking only, Vite handles transpilation
- `allowImportingTsExtensions: true` - Allow .vue imports in TS files

**Installation:**
```bash
npm install -D typescript
```

**Sources:**
- [Using Vue with TypeScript | Vue.js](https://vuejs.org/guide/typescript/overview.html)
- [Vue 3 + TypeScript Best Practices: 2025 Enterprise Architecture Guide](https://eastondev.com/blog/en/posts/dev/20251124-vue3-typescript-best-practices/)

---

### vue-tsc 3.2.2+

| Aspect | Details |
|--------|---------|
| **Version** | 3.2.2+ (latest: Jan 2026) |
| **Purpose** | Vue 3 SFC type checking |
| **Why** | Wraps TypeScript compiler with Vue SFC support, generates .d.ts declarations |
| **Confidence** | HIGH (official Vue tooling) |

**Usage:**
```json
{
  "scripts": {
    "type-check": "vue-tsc --noEmit",
    "build": "vue-tsc --noEmit && vite build"
  }
}
```

**Key Features:**
- Type-check `.vue` files
- Generate TypeScript declarations for component libraries
- Supports TypeScript 5.0+ and Vue 3.4+
- All standard `tsc` options work

**Installation:**
```bash
npm install -D vue-tsc
```

**Sources:**
- [vue-tsc - npm](https://www.npmjs.com/package/vue-tsc)
- [TypeScript with Composition API | Vue.js](https://vuejs.org/guide/typescript/composition-api.html)

---

## Build Tooling Migration

### Vite 7.3+ (Replace Vue CLI 5)

| Aspect | Details |
|--------|---------|
| **Current** | Vue CLI 5.0.8 + Webpack |
| **Target Version** | Vite 7.3+ (latest stable) |
| **Purpose** | Next-generation frontend build tool |
| **Why** | 10-100x faster dev startup, instant HMR, official Vue recommendation, TypeScript out-of-the-box |
| **Confidence** | HIGH (official Vue tooling, production-ready) |

**Key Benefits for SysNDD:**
- **Instant server start** - No bundling in dev mode
- **Lightning HMR** - Sub-50ms updates regardless of app size
- **TypeScript native** - No additional config needed
- **Tree-shaking** - Better production bundle optimization
- **Modern by default** - ES modules, native browser features

**Configuration (vite.config.ts):**
```typescript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 8080,
    proxy: {
      '/api': {
        target: 'http://localhost:7777',
        changeOrigin: true
      }
    }
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'bootstrap-vue': ['bootstrap-vue-next'],
          'vendor': ['vue', 'vue-router', 'pinia']
        }
      }
    }
  }
})
```

**Migration from Vue CLI:**
- Remove `vue.config.js` → Create `vite.config.ts`
- Update `index.html` (move to project root, change script path)
- Add `.vue` extensions to all component imports
- Remove webpack-specific features (magic comments, `require.context`)
- Update environment variables: `VUE_APP_*` → `VITE_*`

**Installation:**
```bash
npm install -D vite @vitejs/plugin-vue
```

**Sources:**
- [Vite 6.0 is out! | Vite](https://vite.dev/blog/announcing-vite6)
- [How to Migrate from Vue CLI to Vite - Vue School](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)

---

### @vitejs/plugin-vue 6.0.3+

| Aspect | Details |
|--------|---------|
| **Version** | 6.0.3+ (latest) |
| **Purpose** | Official Vite plugin for Vue 3 SFC support |
| **Why** | Required for `.vue` file processing in Vite |
| **Confidence** | HIGH (official plugin) |

**Features:**
- Vue 3 SFC compilation
- HMR for Vue components
- `<script setup>` support
- Custom blocks support

**Installation:**
```bash
npm install -D @vitejs/plugin-vue
```

**Sources:**
- [@vitejs/plugin-vue - npm](https://www.npmjs.com/package/@vitejs/plugin-vue)

---

## UI Framework Migration

### Bootstrap 5.3.8 + Bootstrap-Vue-Next 0.42.0

| Component | Current | Target | Purpose |
|-----------|---------|--------|---------|
| **Bootstrap CSS** | 4.6.0 | 5.3.8 | CSS framework |
| **Component Library** | Bootstrap-Vue 2.21.2 | Bootstrap-Vue-Next 0.42.0 | Vue 3 components |

**Why Bootstrap-Vue-Next:**
- Official migration path from Bootstrap-Vue (Vue 2)
- Bootstrap 5 + Vue 3 + TypeScript native
- 35+ components with TypeScript definitions
- Composition API based
- Active maintenance
- **CRITICAL:** Most comprehensive Bootstrap component library for Vue 3

**Breaking Changes from Bootstrap-Vue:**
- Different import paths: `bootstrap-vue` → `bootstrap-vue-next`
- Some component API changes (mostly prop renames)
- Bootstrap 5 breaking changes (custom CSS variables, utility changes)
- No jQuery dependency (Bootstrap 5 change)

**Installation:**
```bash
npm install bootstrap@5.3.8 bootstrap-vue-next@latest
```

**Setup (main.ts):**
```typescript
import { createApp } from 'vue'
import BootstrapVueNext from 'bootstrap-vue-next'
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css'

const app = createApp(App)
app.use(BootstrapVueNext)
```

**Component Migration Strategy:**
1. **Phase 1:** Global CSS changes (Bootstrap 4 → 5)
2. **Phase 2:** Component-by-component migration
3. **Phase 3:** Visual regression testing

**Confidence:** HIGH for Bootstrap 5.3.8, MEDIUM-HIGH for Bootstrap-Vue-Next (latest stable but smaller ecosystem than original)

**Sources:**
- [Bootstrap · The most popular HTML, CSS, and JS library](https://getbootstrap.com)
- [bootstrap-vue-next - npm](https://www.npmjs.com/package/bootstrap-vue-next)
- [BootstrapVueNext Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)

---

## Router and State Management

### Vue Router 4.6.4+

| Aspect | Details |
|--------|---------|
| **Current** | Vue Router 3.5.3 (Vue 2) |
| **Target** | Vue Router 4.6.4+ (Vue 3) |
| **Why** | Vue 3 compatibility, TypeScript support, Composition API integration |
| **Confidence** | HIGH (official router) |

**Breaking Changes:**
- `new VueRouter()` → `createRouter()`
- History mode: `mode: 'history'` → `createWebHistory()`
- `router.app` removed
- Stricter route matching

**Setup (router/index.ts):**
```typescript
import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  // ... routes
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

export default router
```

**Installation:**
```bash
npm install vue-router@latest
```

**Sources:**
- [vue-router - npm](https://www.npmjs.com/package/vue-router)
- [Vue Router | The official Router for Vue.js](https://router.vuejs.org/)

---

### Pinia 2.0.14 (Already Installed - No Changes)

| Aspect | Details |
|--------|---------|
| **Current** | Pinia 2.0.14 ✅ |
| **Status** | **KEEP AS-IS** - Already Vue 3 compatible |
| **Why** | Pinia works with both Vue 2 (via composition-api) and Vue 3 |
| **Confidence** | HIGH (already validated) |

**What to Verify:**
- Remove `@vue/composition-api` dependency (Vue 3 has it built-in)
- Update Pinia setup to use Vue 3 native API

**Migration (main.ts):**
```typescript
// OLD (Vue 2.7)
import { createPinia, PiniaVuePlugin } from 'pinia'
Vue.use(PiniaVuePlugin)

// NEW (Vue 3)
import { createPinia } from 'pinia'
const pinia = createPinia()
app.use(pinia)
```

**No version upgrade needed** - 2.0.14 is Vue 3 ready.

**Sources:**
- Project validation (MILESTONE context confirmed Pinia 2.0.14)

---

## Form Validation

### VeeValidate 4.x (Vue 3 Upgrade)

| Aspect | Details |
|--------|---------|
| **Current** | vee-validate 3.4.14 (Vue 2) |
| **Target** | vee-validate 4.x (latest) |
| **Why** | Vue 3 compatibility, Composition API, TypeScript support |
| **Confidence** | HIGH (official Vue 3 support) |

**Breaking Changes:**
- ValidationProvider/ValidationObserver removed
- Use `useField()`, `useForm()` composables
- Different API for Composition API
- TypeScript native support

**Setup:**
```typescript
import { useField, useForm } from 'vee-validate'
import * as yup from 'yup' // Schema validation

// Component usage
const { value, errorMessage } = useField('email', yup.string().email().required())
```

**Installation:**
```bash
npm install vee-validate@latest
```

**Sources:**
- [vee-validate - npm](https://www.npmjs.com/package/vee-validate)
- [VeeValidate: Painless Vue.js forms](https://vee-validate.logaretm.com/v4/)

---

## Component Libraries

### Vue TreeSelect Alternative

| Aspect | Details |
|--------|---------|
| **Current** | @riophae/vue-treeselect 0.4.0 (Vue 2 only) |
| **Recommendation** | PrimeVue TreeSelect OR @zanmato/vue3-treeselect |
| **Why** | Original vue-treeselect doesn't support Vue 3 |
| **Confidence** | MEDIUM (community forks exist but less mature than original) |

**Options:**

#### Option 1: PrimeVue TreeSelect (RECOMMENDED)
- **Pros:** Mature Vue 3 component library, TypeScript support, active maintenance
- **Cons:** Requires adopting PrimeVue (additional dependency)
- **Best for:** If considering component library for other needs

```bash
npm install primevue
```

#### Option 2: @zanmato/vue3-treeselect
- **Pros:** Direct fork of vue-treeselect for Vue 3, similar API
- **Cons:** Community maintained, less active than PrimeVue
- **Best for:** Minimal migration, similar API to existing code

```bash
npm install @zanmato/vue3-treeselect
```

#### Option 3: Element Plus TreeSelect
- **Alternative:** Another mature Vue 3 component library
- **Similar to PrimeVue** but different design system

**Migration Strategy:**
1. Audit current treeselect usage (how many components?)
2. If usage is limited, consider PrimeVue for better long-term support
3. If heavily used, @zanmato/vue3-treeselect for easier migration

**Sources:**
- [PrimeVue TreeSelect Component](https://primevue.org/treeselect/)
- [@zanmato/vue3-treeselect - npm](https://www.npmjs.com/package/@zanmato/vue3-treeselect)

---

### Other Dependencies (Keep Compatible Versions)

| Library | Current | Vue 3 Status | Action |
|---------|---------|--------------|--------|
| **d3** | 7.4.2 | ✅ Framework-agnostic | Keep |
| **gsap** | 3.12.1 | ✅ Framework-agnostic | Keep |
| **html2canvas** | 1.4.1 | ✅ Framework-agnostic | Keep |
| **file-saver** | 2.0.5 | ✅ Framework-agnostic | Keep |
| **joi** | 17.6.0 | ✅ Framework-agnostic | Keep |
| **swagger-ui** | 4.10.3 | ✅ Framework-agnostic | Keep |
| **vue-axios** | 3.4.1 | ✅ Vue 3 compatible | Keep |
| **axios** | 0.21.4 | ⚠️ **UPGRADE** (security) | 1.6+ |
| **vue-meta** | 2.4.0 | ❌ Vue 2 only | Replace with @unhead/vue |
| **vue2-perfect-scrollbar** | 1.5.56 | ❌ Vue 2 only | Find Vue 3 alternative or custom directive |
| **@upsetjs/vue** | 1.11.0 | ❓ **VERIFY** | Check Vue 3 compatibility |

**Critical Replacements:**

#### @unhead/vue (Replace vue-meta)
```bash
npm install @unhead/vue
```

**Setup:**
```typescript
import { createHead } from '@unhead/vue'
const head = createHead()
app.use(head)
```

**Sources:**
- Framework compatibility verified via npm registry

---

## Testing Infrastructure (NEW)

### Vitest 4.0.17 (Replace Jest/No Tests)

| Aspect | Details |
|--------|---------|
| **Current** | None (0% test coverage) |
| **Target** | Vitest 4.0.17+ |
| **Why** | Vite-native, fast, Jest-compatible API, TypeScript native, Vue 3 SFC support |
| **Confidence** | HIGH (official Vite testing framework) |

**Key Features:**
- **Blazing fast** - Powered by Vite, uses same config
- **Jest-compatible API** - Easy to learn if familiar with Jest
- **TypeScript native** - No additional setup
- **Vue 3 SFC testing** - Works with @vue/test-utils
- **Browser mode stable** (Vitest 4.0) - Real browser testing
- **Visual regression testing** - New in 4.0

**Configuration (vitest.config.ts):**
```typescript
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'jsdom',
    globals: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      exclude: ['node_modules/', 'src/tests/']
    }
  }
})
```

**Installation:**
```bash
npm install -D vitest @vitest/ui @vitest/coverage-v8 jsdom
```

**Sources:**
- [Vitest 4.0 is out! | Vitest](https://vitest.dev/blog/vitest-4)
- [vitest - npm](https://www.npmjs.com/package/vitest)

---

### @vue/test-utils 2.x + @testing-library/vue 8.x

| Library | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| **@vue/test-utils** | 2.x (latest) | Official Vue 3 testing utilities | HIGH |
| **@testing-library/vue** | 8.x (latest) | User-centric testing approach | HIGH |

**Why Both:**
- **@vue/test-utils** - Vue-specific testing (component internals, props, emits)
- **@testing-library/vue** - DOM testing (user interactions, accessibility)

**Testing Philosophy:**
> "The more your tests resemble the way your software is used, the more confidence they can provide."

**Example Test:**
```typescript
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { render, screen } from '@testing-library/vue'
import MyComponent from '@/components/MyComponent.vue'

describe('MyComponent', () => {
  it('renders correctly', () => {
    const wrapper = mount(MyComponent, {
      props: { title: 'Test' }
    })
    expect(wrapper.text()).toContain('Test')
  })

  it('is accessible', async () => {
    render(MyComponent, { props: { title: 'Test' } })
    const button = screen.getByRole('button', { name: /test/i })
    expect(button).toBeInTheDocument()
  })
})
```

**Installation:**
```bash
npm install -D @vue/test-utils @testing-library/vue @testing-library/user-event
```

**Sources:**
- [Testing | Vue.js](https://vuejs.org/guide/scaling-up/testing)
- [@testing-library/vue - npm](https://www.npmjs.com/package/@testing-library/vue)

---

### Accessibility Testing

#### vitest-axe (Automated WCAG Testing)

| Aspect | Details |
|--------|---------|
| **Purpose** | Automated accessibility auditing in tests |
| **Standard** | WCAG 2.1/2.2 Level A/AA |
| **Why** | Medical app requires WCAG 2.2 compliance |
| **Confidence** | HIGH (axe-core based, industry standard) |

**Setup:**
```typescript
import { axe, toHaveNoViolations } from 'vitest-axe'
import { render } from '@testing-library/vue'

expect.extend(toHaveNoViolations)

it('is accessible', async () => {
  const { container } = render(MyComponent)
  const results = await axe(container)
  expect(results).toHaveNoViolations()
})
```

**Installation:**
```bash
npm install -D vitest-axe
```

**Note:** For Vue 3, use `vitest-axe` (Jest-axe equivalent for Vitest). `vue-axe-next` is for runtime dev auditing, not test integration.

**Sources:**
- [vue-axe-next - GitHub](https://github.com/vue-a11y/vue-axe-next)
- [How to Improve Accessibility with Testing Library and jest-axe](https://alexop.dev/posts/how-to-improve-accessibility-with-testing-library-and-jest-axe-for-your-vue-application/)

---

## Code Quality and Linting

### ESLint 9 + Flat Config (TypeScript + Vue 3)

| Aspect | Details |
|--------|---------|
| **Current** | ESLint 6.8.0 + .eslintrc.json |
| **Target** | ESLint 9+ with flat config (eslint.config.js) |
| **Why** | Modern config format, better TypeScript support, Vue 3 support |
| **Confidence** | HIGH (official, .eslintrc removed in ESLint 10) |

**Breaking Changes:**
- `.eslintrc.*` deprecated → `eslint.config.js` (flat config)
- Different plugin syntax
- Array-based configuration

**Configuration (eslint.config.js):**
```javascript
import js from '@eslint/js'
import pluginVue from 'eslint-plugin-vue'
import tseslint from 'typescript-eslint'
import vueParser from 'vue-eslint-parser'

export default [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...pluginVue.configs['flat/recommended'],
  {
    files: ['**/*.vue', '**/*.ts'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tseslint.parser,
        sourceType: 'module'
      }
    },
    rules: {
      'vue/multi-word-component-names': 'off',
      '@typescript-eslint/no-explicit-any': 'warn'
    }
  }
]
```

**Required Packages:**
```bash
npm install -D eslint@latest @eslint/js eslint-plugin-vue vue-eslint-parser typescript-eslint
```

**Alternative:** Use `@vue/eslint-config-typescript` for simpler setup:
```bash
npm install -D @vue/eslint-config-typescript
```

**Sources:**
- [ESLint 9 Flat config tutorial - DEV](https://dev.to/aolyang/eslint-9-flat-config-tutorial-2bm5)
- [@vue/eslint-config-typescript - npm](https://www.npmjs.com/package/@vue/eslint-config-typescript)

---

### Prettier 3.x (Code Formatting)

| Aspect | Details |
|--------|---------|
| **Version** | 3.x (latest) |
| **Purpose** | Opinionated code formatter |
| **Why** | Consistent code style, works with ESLint |
| **Confidence** | HIGH (standard) |

**Configuration (.prettierrc.json):**
```json
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2
}
```

**ESLint Integration:**
```bash
npm install -D eslint-config-prettier eslint-plugin-prettier
```

**Sources:**
- Industry standard practice

---

## Migration Tooling

### webpack-to-vite (Automated Conversion)

| Aspect | Details |
|--------|---------|
| **Tool** | webpack-to-vite (originjs) |
| **Purpose** | Automate Vue CLI → Vite migration |
| **Confidence** | MEDIUM (community tool, requires manual verification) |

**Usage:**
```bash
npx webpack-to-vite
# Or: npx webpack-to-vite -t vue-cli
```

**What it converts:**
- `vue.config.js` → `vite.config.ts`
- package.json scripts
- Environment variables
- Basic webpack configs

**What requires manual work:**
- Add `.vue` extensions to imports
- Remove webpack magic comments
- Update dynamic imports
- Test all features

**Recommendation:** Use as starting point, verify everything manually.

**Sources:**
- [webpack-to-vite - GitHub](https://github.com/originjs/webpack-to-vite)
- [How to Migrate from Vue CLI to Vite - Vue School](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)

---

### @vue/compat (Migration Build)

| Aspect | Details |
|--------|---------|
| **Version** | Latest (matches Vue 3 version) |
| **Purpose** | Run Vue 2 code in Vue 3 with compatibility warnings |
| **Why** | Gradual migration, identify breaking changes |
| **Confidence** | HIGH (official Vue migration tool) |

**Strategy:**
1. Install `@vue/compat` instead of `vue`
2. Configure Vite to alias `vue` to `@vue/compat`
3. Run app, fix warnings one by one
4. Switch back to `vue` when all warnings resolved

**Configuration:**
```typescript
// vite.config.ts
export default defineConfig({
  resolve: {
    alias: {
      vue: '@vue/compat'
    }
  }
})
```

**Installation:**
```bash
npm install @vue/compat
```

**Recommendation:** Use for complex migration. For greenfield TypeScript rewrite, skip and migrate directly.

**Sources:**
- [Vue 3 Migration Build | Vue Mastery](https://www.vuemastery.com/blog/vue-3-migration-build/)
- [Migration Build | Vue 3 Migration Guide](https://v3-migration.vuejs.org/migration-build)

---

## Developer Experience

### Auto-Import Plugins (OPTIONAL - Post-MVP)

| Plugin | Purpose | Recommendation |
|--------|---------|----------------|
| **unplugin-auto-import** | Auto-import Vue APIs (ref, computed, etc.) | Consider for Phase 2 |
| **unplugin-vue-components** | Auto-import components | Consider for Phase 2 |

**Why Optional:**
- Adds "magic" that hides imports
- Can confuse developers during migration
- TypeScript may not recognize auto-imports initially
- **Recommend:** Explicit imports during migration, auto-import after team comfortable with Vue 3

**If Adopted Later:**
```bash
npm install -D unplugin-auto-import unplugin-vue-components
```

**Sources:**
- [unplugin-auto-import - GitHub](https://github.com/unplugin/unplugin-auto-import)
- [unplugin-vue-components - GitHub](https://github.com/unplugin/unplugin-vue-components)

---

## What NOT to Use

### Deprecated / Replaced

| Package/Feature | Status | Use Instead |
|----------------|--------|-------------|
| **Vue CLI** | Maintenance mode | **Vite** (official recommendation) |
| **@vue/composition-api** | Vue 2 backport | **Vue 3 native** (built-in) |
| **bootstrap-vue** | Vue 2 only | **bootstrap-vue-next** |
| **vue-meta** | Vue 2 only | **@unhead/vue** |
| **@riophae/vue-treeselect** | Vue 2 only | **PrimeVue TreeSelect** or **@zanmato/vue3-treeselect** |
| **vue-template-compiler** | Vue 2 compiler | **Not needed** (Vue 3 includes compiler) |
| **vue-loader 17** | Webpack only | **@vitejs/plugin-vue** (Vite) |
| **vue-server-renderer** | Vue 2 SSR | **@vue/server-renderer** (if using SSR) |

### Experimental / Premature

| Feature | Status | Why Avoid |
|---------|--------|-----------|
| **Vue 3.6 Vapor Mode** | Beta | Unstable, breaking changes expected |
| **unplugin-vue-macros** | Experimental | Wait for stable release |

### Anti-Patterns for Migration

| Anti-Pattern | Why Avoid |
|--------------|-----------|
| **Options API for new components** | Use Composition API + `<script setup>` for better TypeScript |
| **Global event bus** | Use Pinia stores or provide/inject |
| **$refs for component communication** | Use props/emits or composables |
| **Mixing Options and Composition API** | Pick one style per component |

---

## Complete Installation Script

### Step 1: Remove Vue 2 Dependencies

```bash
npm uninstall \
  vue@2 \
  @vue/composition-api \
  bootstrap-vue \
  vue-meta \
  vue-template-compiler \
  @vue/cli-service \
  @vue/cli-plugin-babel \
  @vue/cli-plugin-eslint \
  @vue/cli-plugin-router \
  @vue/cli-plugin-pwa \
  vue-cli-plugin-axios \
  vue-cli-plugin-sitemap \
  vue2-perfect-scrollbar \
  eslint@6 \
  babel-eslint
```

### Step 2: Install Vue 3 Core

```bash
npm install \
  vue@latest \
  vue-router@latest \
  pinia@latest
```

### Step 3: Install Bootstrap-Vue-Next

```bash
npm install \
  bootstrap@5.3.8 \
  bootstrap-vue-next@latest
```

### Step 4: Install TypeScript

```bash
npm install -D \
  typescript@latest \
  vue-tsc@latest \
  @types/node@latest
```

### Step 5: Install Vite

```bash
npm install -D \
  vite@latest \
  @vitejs/plugin-vue@latest
```

### Step 6: Install Testing (Vitest)

```bash
npm install -D \
  vitest@latest \
  @vitest/ui@latest \
  @vitest/coverage-v8@latest \
  jsdom@latest \
  @vue/test-utils@latest \
  @testing-library/vue@latest \
  @testing-library/user-event@latest \
  vitest-axe@latest
```

### Step 7: Install Linting (ESLint 9 + Prettier)

```bash
npm install -D \
  eslint@latest \
  @eslint/js@latest \
  eslint-plugin-vue@latest \
  vue-eslint-parser@latest \
  typescript-eslint@latest \
  prettier@latest \
  eslint-config-prettier@latest \
  eslint-plugin-prettier@latest
```

### Step 8: Install Form Validation

```bash
npm install \
  vee-validate@latest \
  yup@latest
```

### Step 9: Install Utilities

```bash
npm install \
  @unhead/vue@latest
npm install -D \
  @types/d3@latest
```

### Step 10: Upgrade Security Vulnerabilities

```bash
npm install axios@latest
```

---

## package.json Scripts Update

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc --noEmit && vite build",
    "preview": "vite preview",
    "type-check": "vue-tsc --noEmit",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest --coverage",
    "lint": "eslint . --ext .vue,.js,.jsx,.cjs,.mjs,.ts,.tsx,.cts,.mts",
    "lint:fix": "eslint . --ext .vue,.js,.jsx,.cjs,.mjs,.ts,.tsx,.cts,.mts --fix",
    "format": "prettier --write src/"
  }
}
```

---

## Migration Checklist

### Phase 1: Project Setup
- [ ] Install Node.js 20 LTS (already validated)
- [ ] Create Git migration branch
- [ ] Backup current working version
- [ ] Install Vite + TypeScript dependencies
- [ ] Create `vite.config.ts`
- [ ] Create `tsconfig.json`
- [ ] Move `index.html` to project root
- [ ] Update `index.html` for Vite

### Phase 2: Build Tool Migration
- [ ] Remove Vue CLI config
- [ ] Update environment variables (`VUE_APP_*` → `VITE_*`)
- [ ] Add `.vue` extensions to all component imports
- [ ] Remove webpack-specific code
- [ ] Test dev server starts
- [ ] Test production build

### Phase 3: Vue 3 + TypeScript Core
- [ ] Install Vue 3 dependencies
- [ ] Rename `main.js` → `main.ts`
- [ ] Update app initialization (Vue 2 → Vue 3 API)
- [ ] Convert router to Vue Router 4
- [ ] Update Pinia initialization
- [ ] Add TypeScript types to entry files

### Phase 4: Component Migration
- [ ] Audit 50+ components for breaking changes
- [ ] Migrate components to `<script setup lang="ts">`
- [ ] Add TypeScript types (props, emits, refs)
- [ ] Replace deprecated Vue 2 features
- [ ] Test each component in isolation

### Phase 5: Bootstrap Migration
- [ ] Install Bootstrap 5 + Bootstrap-Vue-Next
- [ ] Update Bootstrap imports
- [ ] Migrate Bootstrap-Vue components
- [ ] Update custom CSS for Bootstrap 5 breaking changes
- [ ] Visual regression testing

### Phase 6: Testing Setup
- [ ] Install Vitest + @vue/test-utils
- [ ] Create test configuration
- [ ] Write component tests (target: 80%+ coverage)
- [ ] Add accessibility tests (vitest-axe)
- [ ] Set up CI/CD test pipeline

### Phase 7: Code Quality
- [ ] Install ESLint 9 + Prettier
- [ ] Create flat config
- [ ] Fix all linting errors
- [ ] Set up pre-commit hooks
- [ ] Configure VS Code / IDE

### Phase 8: Third-Party Libraries
- [ ] Migrate vue-treeselect → PrimeVue/alternative
- [ ] Replace vue-meta → @unhead/vue
- [ ] Replace vue2-perfect-scrollbar
- [ ] Verify @upsetjs/vue Vue 3 compatibility
- [ ] Test all third-party integrations

### Phase 9: Validation
- [ ] End-to-end testing (all features)
- [ ] Performance benchmarking
- [ ] Accessibility audit (WCAG 2.2)
- [ ] Browser compatibility testing
- [ ] Mobile responsiveness check

---

## Confidence Assessment

| Category | Confidence | Basis |
|----------|------------|-------|
| Vue 3.5 + TypeScript 5 | HIGH | Official stable releases, Jan 2026 verified |
| Vite 7.3 + @vitejs/plugin-vue | HIGH | Official Vue tooling, production-ready |
| Bootstrap 5.3.8 | HIGH | Mature, stable release |
| Bootstrap-Vue-Next 0.42.0 | MEDIUM-HIGH | Active development, 35+ components, but smaller ecosystem than original |
| Vue Router 4.6.4 | HIGH | Official router, stable |
| Pinia 2.0.14 | HIGH | Already validated, Vue 3 compatible |
| Vitest 4.0.17 | HIGH | Official Vite testing, v4 is stable |
| VeeValidate 4.x | HIGH | Official Vue 3 support |
| ESLint 9 flat config | HIGH | Official ESLint, .eslintrc removed in v10 |
| Migration tooling | MEDIUM | Community tools, require verification |
| TreeSelect alternatives | MEDIUM | Community forks or larger component libraries |

---

## Key Risks and Mitigations

### Risk 1: Visual Regressions from Bootstrap 4 → 5
**Impact:** HIGH (medical users expect consistency)
**Mitigation:**
- Comprehensive visual regression testing
- Staged rollout
- Side-by-side comparison screenshots
- User acceptance testing

### Risk 2: TypeScript Strict Mode Errors
**Impact:** MEDIUM (many type errors expected)
**Mitigation:**
- Start with `strict: false`, enable gradually
- Use `@ts-expect-error` temporarily
- Prioritize critical paths first
- Budget extra time for type fixes

### Risk 3: Bootstrap-Vue → Bootstrap-Vue-Next Component Gaps
**Impact:** MEDIUM (some components may have breaking changes)
**Mitigation:**
- Audit all Bootstrap-Vue components used
- Check Bootstrap-Vue-Next documentation for equivalents
- Budget time for custom component wrappers
- Consider PrimeVue as fallback

### Risk 4: Third-Party Library Compatibility
**Impact:** MEDIUM (vue-treeselect, @upsetjs/vue)
**Mitigation:**
- Verify Vue 3 compatibility early
- Identify alternatives before starting
- Consider feature freeze for non-Vue-3-ready deps

### Risk 5: Testing Infrastructure from 0% → Target
**Impact:** LOW-MEDIUM (new process, learning curve)
**Mitigation:**
- Start with critical path tests
- Use Testing Library for user-centric tests
- Vitest is Jest-compatible (easier learning)
- Budget time for team training

---

## Integration with Existing Stack

### Preserved from Current Stack

| Component | Version | Status | Notes |
|-----------|---------|--------|-------|
| **Node.js** | 20 LTS | ✅ Keep | Already validated |
| **Pinia** | 2.0.14 | ✅ Keep | Vue 3 compatible |
| **D3** | 7.4.2 | ✅ Keep | Framework-agnostic |
| **GSAP** | 3.12.1 | ✅ Keep | Framework-agnostic |
| **axios** | 0.21.4 | ⚠️ Upgrade | Security: upgrade to 1.6+ |
| **Joi** | 17.6.0 | ✅ Keep | Framework-agnostic |
| **file-saver** | 2.0.5 | ✅ Keep | Framework-agnostic |
| **html2canvas** | 1.4.1 | ✅ Keep | Framework-agnostic |
| **swagger-ui** | 4.10.3 | ✅ Keep | Framework-agnostic |

### Backend Integration

**API Communication:** No changes required
- Axios remains the HTTP client
- vue-axios wrapper compatible with Vue 3
- API endpoints unchanged
- Authentication flow unchanged

**Docker:** No changes required
- Node 20 base image (already using)
- Build process: `npm run build` (same output)
- nginx serving (same static files)

---

## Next Steps

1. **Review and Approve Stack** - Confirm all package versions and choices
2. **Set Up Development Environment** - Install dependencies, configure TypeScript, Vite
3. **Create Proof of Concept** - Migrate 1-2 simple components to validate stack
4. **Component Audit** - Document all 50+ components and their dependencies
5. **Create Migration Plan** - Detailed roadmap with component-by-component phases
6. **Begin Migration** - Follow checklist above, starting with build tool setup

---

## Sources

**Official Documentation (High Confidence):**
- [Vue.js Official Documentation](https://vuejs.org/)
- [Vite Official Documentation](https://vite.dev/)
- [Vitest Official Documentation](https://vitest.dev/)
- [TypeScript Official Documentation](https://www.typescriptlang.org/)
- [Vue Router Official Documentation](https://router.vuejs.org/)
- [Bootstrap Official Documentation](https://getbootstrap.com/)
- [Bootstrap-Vue-Next Documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/)

**Community Resources (Medium Confidence):**
- [Vue 3 Migration Guide](https://v3-migration.vuejs.org/)
- [Vue School: How to Migrate from Vue CLI to Vite](https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/)
- [Vue School: Vue.js 2025 In Review and 2026 Peek](https://vueschool.io/articles/news/vue-js-2025-in-review-and-a-peek-into-2026/)
- [LogRocket: How to use Vue 3 with TypeScript](https://blog.logrocket.com/how-to-use-vue-3-typescript/)

**Package Registries (Version Verification):**
- [npm Registry](https://www.npmjs.com/) - All versions verified January 2026
- [GitHub Releases](https://github.com/) - Official release pages

**Migration Tools:**
- [webpack-to-vite](https://github.com/originjs/webpack-to-vite)
- [Vue 3 Migration Build (@vue/compat)](https://v3-migration.vuejs.org/migration-build)

---

**Document Version:** 1.0
**Last Updated:** 2026-01-22
**Next Review:** After Phase 1 completion
