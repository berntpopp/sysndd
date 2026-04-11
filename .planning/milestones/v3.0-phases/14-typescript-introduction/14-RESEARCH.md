# Phase 14: TypeScript Introduction - Research

**Researched:** 2026-01-23
**Domain:** TypeScript integration with Vue 3 + Vite
**Confidence:** HIGH

## Summary

TypeScript integration with Vue 3 and Vite follows a well-established pattern in 2026, with official tooling (vue-tsc, @vue/tsconfig) providing robust support. The recommended approach uses a relaxed strict mode initially (strict: false) with incremental tightening, ESLint 9 flat config for modern linting, and Prettier 3 for formatting. For API types, manual typing with optional runtime validation (Zod) is recommended over OpenAPI generation for this project's 21-endpoint scale. The Vue ecosystem provides excellent TypeScript inference, making migration straightforward with proper configuration.

**Primary recommendation:** Start with @vue/tsconfig base configuration, ESLint 9 flat config with 'warn' severity, and manual API types in dedicated src/types/ directory. Use branded types for domain IDs, convert infrastructure files (main, router, stores, services, composables) before components, and leverage pre-commit hooks for automated formatting.

## Standard Stack

The established libraries/tools for Vue 3 + TypeScript integration:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| typescript | 5.7+ | TypeScript compiler | Latest version with improved noImplicitAny error reporting, ES2024 target support |
| vue-tsc | 3.2.2+ | Vue-specific type checking | Official Vue 3 type checker based on Volar, required for SFC type checking |
| @vue/tsconfig | latest | Base TypeScript config | Official Vue team preset with optimal compiler options for Vue 3 + Vite |
| @vitejs/plugin-vue | 6.0.3 | Vite Vue plugin | Already installed, TypeScript-aware SFC compilation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| eslint | 9+ | Code linting | Flat config support required for modern setup |
| @vue/eslint-config-typescript | latest | Vue + TypeScript ESLint rules | Official config, auto-configures TypeScript parser |
| typescript-eslint | latest | TypeScript ESLint support | Provides @typescript-eslint/parser and plugin |
| prettier | 3.x | Code formatting | Industry standard, zero-config philosophy |
| eslint-config-prettier | latest | ESLint + Prettier integration | Disables conflicting ESLint formatting rules |
| husky | 9.x | Git hooks | Pre-commit hook automation |
| lint-staged | latest | Staged file linting | Run linters only on staged files for speed |
| @types/* | as needed | Type definitions | DefinitelyTyped packages for third-party libraries without native types |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual types | openapi-typescript | Generation requires OpenAPI spec; project has 21 endpoints, manual is simpler |
| Manual types | Zod schema inference | Adds runtime validation + type generation; overkill unless runtime validation needed |
| vue-tsc | vite-plugin-checker | Runs in worker thread but adds build complexity; vue-tsc simpler for CLI |
| @vue/tsconfig | Custom tsconfig | Official preset has battle-tested defaults, hand-rolling risks misconfiguration |

**Installation:**
```bash
# Core TypeScript
npm install --save-dev typescript@^5.7.0 vue-tsc@^3.2.2 @vue/tsconfig

# ESLint 9 + TypeScript
npm install --save-dev eslint@^9.0.0 @vue/eslint-config-typescript typescript-eslint

# Prettier
npm install --save-dev prettier@^3.0.0 eslint-config-prettier

# Git hooks
npm install --save-dev husky@^9.0.0 lint-staged

# Type definitions (add as needed during conversion)
npm install --save-dev @types/node @types/d3 @types/file-saver
```

## Architecture Patterns

### Recommended Project Structure
```
app/
├── src/
│   ├── types/               # Type definitions
│   │   ├── models.ts        # Domain models (Entity, Gene, User, etc.)
│   │   ├── api.ts           # API request/response types
│   │   ├── components.ts    # Component prop types
│   │   └── utils.ts         # Utility types (branded types, helpers)
│   ├── main.ts              # Entry point (renamed from .js)
│   ├── router/
│   │   ├── index.ts         # Router configuration
│   │   └── routes.ts        # Route definitions
│   ├── stores/
│   │   └── ui.ts            # Pinia stores with TypeScript
│   ├── composables/
│   │   ├── useModalControls.ts
│   │   └── useToastNotifications.ts
│   ├── assets/js/
│   │   ├── services/
│   │   │   └── apiService.ts  # API service with generic types
│   │   └── constants/
│   │       └── url_constants.ts
│   └── components/          # SFCs with <script setup lang="ts">
│       └── *.vue
├── tsconfig.json            # Extends @vue/tsconfig/tsconfig.dom.json
├── tsconfig.node.json       # For Node env (vite.config.ts)
├── tsconfig.app.json        # For app/DOM code
├── eslint.config.js         # ESLint 9 flat config
├── .prettierrc              # Prettier config
└── vite.config.ts           # Vite config (renamed from .js)
```

### Pattern 1: Base TypeScript Configuration (Project References)

**What:** Modern Vue 3 + TypeScript projects use a split tsconfig with project references for different environments.

**When to use:** Standard setup for all Vue 3 + Vite projects with TypeScript

**Example:**
```typescript
// tsconfig.json (root)
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}

// tsconfig.app.json (application code)
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "include": ["src/**/*", "src/**/*.vue"],
  "exclude": ["src/**/__tests__/*"],
  "compilerOptions": {
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}

// tsconfig.node.json (Node environment - vite.config.ts)
{
  "extends": "@tsconfig/node22/tsconfig.json",
  "include": [
    "vite.config.*",
    "vitest.config.*",
    "cypress.config.*",
    "nightwatch.conf.*",
    "playwright.config.*"
  ],
  "compilerOptions": {
    "composite": true,
    "noEmit": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "types": ["node"]
  }
}
```

**User decision override:** Single tsconfig preferred - simplify to one file:
```typescript
// tsconfig.json (single file approach)
{
  "extends": "@vue/tsconfig/tsconfig.dom.json",
  "include": ["src/**/*", "src/**/*.vue", "vite.config.ts"],
  "compilerOptions": {
    "strict": false,  // User decision: start relaxed
    "noImplicitAny": false,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    },
    "types": ["node", "vite/client"]
  }
}
```

### Pattern 2: Branded Types for Domain IDs

**What:** Create distinct compile-time types for different ID types to prevent mixing (e.g., GeneId vs EntityId).

**When to use:** Medical/scientific domains where mixing IDs causes serious errors; user specifically requested this pattern

**Example:**
```typescript
// Source: https://effect.website/docs/code-style/branded-types/
// types/utils.ts
declare const __brand: unique symbol;
type Brand<T, TBrand> = T & { [__brand]: TBrand };

// types/models.ts
export type GeneId = Brand<string, 'GeneId'>;
export type EntityId = Brand<string, 'EntityId'>;
export type UserId = Brand<string, 'UserId'>;
export type SymbolId = Brand<string, 'SymbolId'>;

// Factory functions for creating branded values
export function createGeneId(id: string): GeneId {
  return id as GeneId;
}

export function createEntityId(id: string): EntityId {
  return id as EntityId;
}

// Usage example
function fetchGene(id: GeneId) { /* ... */ }

const geneId = createGeneId("123");
const entityId = createEntityId("456");

fetchGene(geneId);      // OK
fetchGene(entityId);    // Compile error - type mismatch!
```

### Pattern 3: API Service with Generic Types

**What:** Type-safe API service using generics for request/response typing with reusable fetch logic.

**When to use:** All API calls in the application

**Example:**
```typescript
// Source: Verified pattern from Vue + TypeScript community
// types/api.ts
export interface ApiResponse<T> {
  data: T;
  status: number;
  message?: string;
}

export interface StatisticsResponse {
  category: string;
  count: number;
  lastUpdated: string;
}

export interface NewsItem {
  id: number;
  title: string;
  date: string;
  content: string;
}

export interface SearchResult {
  genes: Gene[];
  entities: Entity[];
  symbols: Symbol[];
}

// services/apiService.ts
import type {
  ApiResponse,
  StatisticsResponse,
  NewsItem,
  SearchResult
} from '@/types/api';
import axios, { AxiosResponse } from 'axios';
import URLS from '@/assets/js/constants/url_constants';

class ApiService {
  private async fetch<T>(url: string): Promise<T> {
    const response: AxiosResponse<ApiResponse<T>> = await axios.get(url);
    return response.data.data;
  }

  async fetchStatistics(type: string): Promise<StatisticsResponse> {
    const url = `${URLS.API_URL}/api/statistics/category_count?type=${type}`;
    return this.fetch<StatisticsResponse>(url);
  }

  async fetchNews(n: number): Promise<NewsItem[]> {
    const url = `${URLS.API_URL}/api/statistics/news?n=${n}`;
    return this.fetch<NewsItem[]>(url);
  }

  async fetchSearchInfo(searchInput: string): Promise<SearchResult> {
    const url = `${URLS.API_URL}/api/search/${searchInput}?helper=true`;
    return this.fetch<SearchResult>(url);
  }
}

export default new ApiService();
```

### Pattern 4: Pinia Store with TypeScript (Setup Syntax)

**What:** Type-safe Pinia stores using Composition API setup syntax for automatic type inference.

**When to use:** All Pinia stores in the application

**Example:**
```typescript
// Source: https://pinia.vuejs.org/core-concepts/
// stores/ui.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useUIStore = defineStore('ui', () => {
  // State (ref() becomes state)
  const scrollbarWidth = ref<number>(0);
  const sidebarCollapsed = ref<boolean>(false);
  const loadingStates = ref<Map<string, boolean>>(new Map());

  // Getters (computed() becomes getters)
  const isLoading = computed(() => (key: string) => {
    return loadingStates.value.get(key) ?? false;
  });

  // Actions (function() becomes actions)
  function setScrollbarWidth(width: number): void {
    scrollbarWidth.value = width;
  }

  function toggleSidebar(): void {
    sidebarCollapsed.value = !sidebarCollapsed.value;
  }

  function setLoading(key: string, loading: boolean): void {
    loadingStates.value.set(key, loading);
  }

  // CRITICAL: Return all properties for SSR and type inference
  return {
    scrollbarWidth,
    sidebarCollapsed,
    loadingStates,
    isLoading,
    setScrollbarWidth,
    toggleSidebar,
    setLoading,
  };
});
```

### Pattern 5: Vue Router with TypeScript

**What:** Type-safe route definitions and navigation guards.

**When to use:** Router configuration and navigation logic

**Example:**
```typescript
// Source: https://router.vuejs.org/guide/advanced/navigation-guards.html
// router/routes.ts
import type { RouteRecordRaw } from 'vue-router';

export const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue'),
    meta: {
      requiresAuth: false,
      title: 'Home',
    },
  },
  {
    path: '/genes/:id',
    name: 'GeneDetail',
    component: () => import('@/views/GeneDetailView.vue'),
    props: (route) => ({ geneId: route.params.id as string }),
    meta: {
      requiresAuth: true,
      title: 'Gene Detail',
    },
  },
];

// router/index.ts
import { createRouter, createWebHistory } from 'vue-router';
import type { Router, NavigationGuardNext, RouteLocationNormalized } from 'vue-router';
import { routes } from './routes';

const router: Router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// Type-safe navigation guard
router.beforeEach((
  to: RouteLocationNormalized,
  from: RouteLocationNormalized,
  next: NavigationGuardNext
) => {
  const requiresAuth = to.meta.requiresAuth as boolean | undefined;

  if (requiresAuth && !isAuthenticated()) {
    next({ name: 'Login' });
  } else {
    next();
  }
});

export default router;
```

### Pattern 6: Composable with TypeScript

**What:** Type-safe composables with explicit return types and parameter types.

**When to use:** All composables in the application

**Example:**
```typescript
// Source: Verified Vue 3 + TypeScript pattern
// composables/useModalControls.ts
import { ref } from 'vue';
import type { Ref } from 'vue';

interface ModalControls {
  isOpen: Ref<boolean>;
  open: () => void;
  close: () => void;
  toggle: () => void;
}

export default function useModalControls(initialState = false): ModalControls {
  const isOpen = ref<boolean>(initialState);

  const open = (): void => {
    isOpen.value = true;
  };

  const close = (): void => {
    isOpen.value = false;
  };

  const toggle = (): void => {
    isOpen.value = !isOpen.value;
  };

  return {
    isOpen,
    open,
    close,
    toggle,
  };
}
```

### Pattern 7: Single File Component with `<script setup lang="ts">`

**What:** Modern Vue 3 SFC using script setup with TypeScript.

**When to use:** All Vue components (converted in later phase, documented here for reference)

**Example:**
```vue
<!-- Source: https://vuejs.org/guide/typescript/overview.html -->
<script setup lang="ts">
import { ref, computed } from 'vue';
import type { ComputedRef } from 'vue';

// Props with TypeScript
interface Props {
  title: string;
  count?: number;
  items: string[];
}

const props = withDefaults(defineProps<Props>(), {
  count: 0,
});

// Emits with TypeScript
interface Emits {
  (e: 'update', value: number): void;
  (e: 'delete', id: string): void;
}

const emit = defineEmits<Emits>();

// State
const localCount = ref<number>(props.count);

// Computed with explicit typing
const displayText: ComputedRef<string> = computed(() => {
  return `${props.title}: ${localCount.value}`;
});

// Methods
function increment(): void {
  localCount.value++;
  emit('update', localCount.value);
}
</script>

<template>
  <div>
    <h2>{{ displayText }}</h2>
    <button @click="increment">Increment</button>
  </div>
</template>
```

### Pattern 8: ESLint 9 Flat Config for Vue + TypeScript

**What:** Modern ESLint configuration using flat config format with TypeScript and Vue support.

**When to use:** Project-wide linting configuration

**Example:**
```javascript
// Source: https://github.com/vuejs/eslint-config-typescript
// eslint.config.js
import js from '@eslint/js';
import pluginVue from 'eslint-plugin-vue';
import tseslint from 'typescript-eslint';
import prettierConfig from 'eslint-config-prettier';

export default [
  // Base JavaScript recommendations
  js.configs.recommended,

  // TypeScript recommendations
  ...tseslint.configs.recommended,

  // Vue 3 recommendations
  ...pluginVue.configs['flat/recommended'],

  // Prettier integration (disables conflicting rules)
  prettierConfig,

  {
    files: ['**/*.{ts,tsx,vue}'],
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        parser: '@typescript-eslint/parser',
        extraFileExtensions: ['.vue'],
      },
    },
    rules: {
      // Migration strategy: 'warn' not 'error'
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': 'warn',
      'vue/multi-word-component-names': 'warn',
      'vue/no-v-html': 'warn',

      // Keep existing project conventions
      'no-console': 'off',
      'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'warn',
    },
  },

  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: {
        parser: '@typescript-eslint/parser',
      },
    },
  },

  {
    ignores: ['dist/**', 'node_modules/**', '*.config.js'],
  },
];
```

### Pattern 9: Prettier Configuration for Vue + TypeScript

**What:** Zero-config Prettier with minimal overrides for Vue/TypeScript projects.

**When to use:** Project-wide formatting

**Example:**
```json
// Source: https://prettier.io/docs/options
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "vueIndentScriptAndStyle": false
}
```

### Pattern 10: Pre-commit Hooks with Husky + lint-staged

**What:** Automated linting and formatting on git commit.

**When to use:** All TypeScript projects to enforce code quality

**Example:**
```json
// Source: https://github.com/lint-staged/lint-staged
// package.json
{
  "scripts": {
    "prepare": "husky install"
  },
  "lint-staged": {
    "*.{ts,tsx,vue}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ]
  }
}
```

```bash
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

### Anti-Patterns to Avoid

- **Don't use `any` without documentation:** If `any` is temporarily needed, add `// TODO: type this properly` comment and track in migration log
- **Don't mix `.js` and `.ts` in same directory:** Convert entire directories at once to avoid confusion
- **Don't use `@ts-ignore` without explanation:** Use `@ts-expect-error` with comment explaining why, better for future cleanup
- **Don't skip return types on public functions:** Explicit return types catch errors and document intent
- **Don't use Options API typing with implicit `this`:** Always enable `strict` or `noImplicitThis` for Options API
- **Don't hand-roll branded type runtime checks:** Branded types are compile-time only, don't add runtime overhead
- **Don't use type assertions without validation:** If casting external data, validate first (consider Zod for runtime checks)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Runtime API validation | Custom validators | Zod schemas with `.safeParse()` | Handles edge cases (null, undefined, partial data), provides useful error messages, type inference |
| Base TypeScript config | Manual tsconfig | @vue/tsconfig/tsconfig.dom.json | Official Vue team config, tested with Vite + Vue 3, handles isolatedModules, moduleResolution: 'bundler', proper lib versions |
| Vue component type inference | Manual prop typing | `defineProps<T>()` generic syntax | Leverages TypeScript inference, handles defaults via `withDefaults()`, no duplication |
| ESLint + TypeScript integration | Custom parser config | @vue/eslint-config-typescript | Official config, auto-wires typescript-eslint parser, handles .vue files correctly |
| Pre-commit linting | Custom git hooks | husky + lint-staged | Cross-platform, runs only on staged files (fast), handles partial commits correctly |
| Type-only imports optimization | Manual annotations | TypeScript auto-detection with `verbatimModuleSyntax` | Vite/esbuild require correct import syntax, this option enforces it automatically |

**Key insight:** TypeScript + Vue 3 tooling ecosystem is mature and well-integrated. Using official packages (@vue/tsconfig, @vue/eslint-config-typescript) prevents subtle misconfiguration issues that are hard to debug. The Vue team tests these configs with every Vite/Vue release.

## Common Pitfalls

### Pitfall 1: Forgetting `isolatedModules` / `verbatimModuleSyntax` with Vite

**What goes wrong:** Build fails with cryptic errors about const enums or namespace imports not being supported.

**Why it happens:** Vite uses esbuild for transpilation, which transpiles files independently without full type graph. TypeScript features that require cross-file analysis (const enums, namespaces) fail at build time.

**How to avoid:**
- Set `compilerOptions.verbatimModuleSyntax: true` in tsconfig (superset of isolatedModules)
- Or set `compilerOptions.isolatedModules: true` minimum
- @vue/tsconfig sets this automatically

**Warning signs:**
- Error: "Cannot use namespace when --isolatedModules is set"
- Error: "const enums are not supported with isolatedModules"
- Build succeeds with `vue-tsc` but fails with `vite build`

### Pitfall 2: Missing `noImplicitThis` with Options API

**What goes wrong:** TypeScript doesn't type-check `this` in component options, leading to runtime errors from typos or wrong property access.

**Why it happens:** Options API uses dynamic `this` binding. Without `noImplicitThis`, TypeScript treats `this` as `any` in component methods.

**How to avoid:**
- Set `compilerOptions.strict: true` (includes noImplicitThis and other checks)
- Or minimum `compilerOptions.noImplicitThis: true`
- Use `defineComponent()` wrapper for all Options API components

**Warning signs:**
- Accessing wrong property names on `this` with no TypeScript error
- Runtime errors like "Cannot read property 'foo' of undefined" in methods
- `this` highlighted in yellow in VS Code but no error

### Pitfall 3: Path Alias Mismatch Between Vite and TypeScript

**What goes wrong:** IDE shows type errors, imports fail at compile time, but Vite dev server runs fine. Or vice versa: dev server fails but TypeScript is happy.

**Why it happens:** Vite resolves aliases via `vite.config.ts` `resolve.alias`, TypeScript via `tsconfig.json` `compilerOptions.paths`. If they don't match, one system can't find the modules.

**How to avoid:**
- Keep `vite.config.ts` alias and `tsconfig.json` paths in sync
- Example: Vite has `'@': './src'`, tsconfig must have `"@/*": ["./src/*"]`
- Vite uses file paths, TypeScript uses path patterns (note the `/*` difference)

**Warning signs:**
- VS Code shows import error but Vite HMR works
- `vue-tsc --noEmit` fails but `npm run dev` succeeds
- Refactoring imports manually works but auto-import fails

### Pitfall 4: Type-Only Imports Not Marked with `type`

**What goes wrong:** Vite build fails with "X is not defined" runtime errors for TypeScript types that were supposed to be erased.

**Why it happens:** Vite's esbuild can't distinguish type-only imports from value imports without the `type` keyword. Without `verbatimModuleSyntax`, it may bundle type imports as runtime code.

**How to avoid:**
- Set `compilerOptions.verbatimModuleSyntax: true` (enforces correct syntax)
- Use `import type { Foo } from './types'` for types
- Use `import { bar } from './utils'` for values
- Enable ESLint rule to auto-fix this

**Warning signs:**
- Production build errors: "ReferenceError: MyInterface is not defined"
- Bundle size unexpectedly large (includes type definitions as runtime code)
- Works in dev but fails in production build

### Pitfall 5: Using `.js` Extensions in TypeScript Imports

**What goes wrong:** IDE shows import errors, TypeScript compilation fails, even though files exist as `.ts`.

**Why it happens:** Coming from JavaScript, developers add `.js` extensions. TypeScript doesn't rewrite extensions, so `import './foo.js'` looks for `foo.js`, not `foo.ts`.

**How to avoid:**
- Never use file extensions in imports: `import { foo } from './foo'` (not `'./foo.ts'` or `'./foo.js'`)
- Vite and TypeScript resolve extensions automatically
- Exception: JSON imports may need explicit `.json`

**Warning signs:**
- Error: "Cannot find module './foo.js'"
- File exists as `foo.ts` but import with `.js` fails
- Imports work in some files but not others

### Pitfall 6: Mixing Default and Named Exports in Converted Files

**What goes wrong:** After converting `.js` to `.ts`, imports break with "module has no default export" or vice versa.

**Why it happens:** TypeScript is stricter about import/export matching. JavaScript allowed loose matching, TypeScript requires exact match.

**How to avoid:**
- Audit all imports when converting a file
- Prefer named exports for utilities: `export function foo()` / `import { foo }`
- Use default exports only for components, stores, router: `export default defineComponent()`
- Be consistent: one default OR multiple named, not mixed

**Warning signs:**
- Error after conversion: "Module has no default export"
- Error: "Attempted import error: 'foo' is not exported from './bar'"
- Imports that worked in `.js` fail in `.ts`

### Pitfall 7: Forgetting to Add `lang="ts"` in Vue SFCs

**What goes wrong:** Vue component script blocks aren't type-checked, errors only appear at runtime.

**Why it happens:** Without `lang="ts"`, script is treated as JavaScript. TypeScript compiler skips it.

**How to avoid:**
- Always add `<script setup lang="ts">` or `<script lang="ts">`
- Set up ESLint rule to enforce this in `.vue` files
- vue-tsc will type-check templates only if script has `lang="ts"`

**Warning signs:**
- Type errors in component but `vue-tsc` passes
- VS Code doesn't show TypeScript IntelliSense in component
- Template expressions using wrong types work without error

### Pitfall 8: Using `any` in API Response Types

**What goes wrong:** Type safety disappears at API boundaries. Typos and wrong property access become runtime errors in production.

**Why it happens:** API responses are external data, "any" seems easier than defining types. But this defeats the purpose of TypeScript.

**How to avoid:**
- Define explicit types for ALL API responses in `types/api.ts`
- Start with partial types if needed: `Partial<User>` for optional fields
- Consider Zod for runtime validation: `UserSchema.parse(response.data)`
- Use `unknown` for truly dynamic data, force type narrowing before use

**Warning signs:**
- Accessing wrong API response properties with no error
- Frequent runtime errors like "Cannot read property of undefined" in data handling
- Refactoring breaks API code but TypeScript doesn't catch it

### Pitfall 9: Project Reference Mismatch with Single tsconfig

**What goes wrong:** Following tutorials with project references setup fails because user chose single tsconfig approach.

**Why it happens:** Modern Vue creates multi-file tsconfig (tsconfig.json, tsconfig.app.json, tsconfig.node.json) but user decided on single file for simplicity.

**How to avoid:**
- User chose single tsconfig - honor that decision
- Don't copy project references from examples
- Single file includes both app and node environment types
- Add both `vite/client` and `node` to `compilerOptions.types`

**Warning signs:**
- Error: "File is not in project defined by tsconfig"
- Vite config types not recognized
- Trying to include both `@vue/tsconfig` and `@tsconfig/node` in single file

### Pitfall 10: Enabling All Strict Checks Immediately

**What goes wrong:** 1000+ TypeScript errors on first build. Migration grinds to halt.

**Why it happens:** Enabling `strict: true` turns on ~10 strict checks at once. Existing JavaScript code violates many.

**How to avoid:**
- User decision: Start with `strict: false`
- Enable individual checks incrementally: `noImplicitAny`, `strictNullChecks`, etc.
- Set rule severity to 'warn' during migration phase
- Tighten after all files converted and errors addressed

**Warning signs:**
- Developer gives up on TypeScript because "too many errors"
- Copy-pasting `@ts-ignore` everywhere to make errors go away
- Build time skyrockets due to error reporting

## Code Examples

Verified patterns from official sources and community best practices:

### Example 1: Converting main.js to main.ts

```typescript
// Source: Vue 3 + TypeScript official patterns
// Before: main.js
import { createApp } from 'vue';
import App from './App.vue';
import router from './router';
import { createPinia } from 'pinia';

const app = createApp(App);
app.use(router);
app.use(createPinia());
app.mount('#app');

// After: main.ts
import { createApp } from 'vue';
import type { App as VueApp } from 'vue';
import App from './App.vue';
import router from './router';
import { createPinia } from 'pinia';

const app: VueApp = createApp(App);

app.use(router);
app.use(createPinia());

app.mount('#app');
```

### Example 2: API Response Types Definition

```typescript
// Source: Manual typing pattern (verified approach for 21-endpoint scale)
// types/api.ts

// Generic API response wrapper
export interface ApiResponse<T> {
  data: T;
  status: number;
  message?: string;
  errors?: ApiError[];
}

export interface ApiError {
  field?: string;
  message: string;
  code?: string;
}

// Domain models
export interface Gene {
  gene_id: string;
  hgnc_id: string;
  symbol: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term_name: string;
  ndd_phenotype: {
    disease_ontology_id_version: string;
    hpo_mode_of_inheritance_term: string;
  };
}

export interface Entity {
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  category: string;
  disease_ontology_name: string;
}

export interface User {
  user_id: string;
  email: string;
  name: string;
  roles: string[];
}

// Endpoint-specific response types
export interface StatisticsResponse {
  category_counts: CategoryCount[];
  last_updated: string;
}

export interface CategoryCount {
  category: string;
  count: number;
}

export interface NewsResponse {
  items: NewsItem[];
  total: number;
}

export interface NewsItem {
  id: number;
  title: string;
  content: string;
  date: string;
  author: string;
}

export interface SearchResponse {
  genes: Gene[];
  entities: Entity[];
  symbols: string[];
  total_results: number;
}

// Pagination types
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

// Request parameter types
export interface SearchParams {
  query: string;
  helper?: boolean;
  limit?: number;
}

export interface StatisticsParams {
  type: 'genes' | 'entities' | 'phenotypes';
}
```

### Example 3: Generic API Service Implementation

```typescript
// Source: TypeScript + axios pattern
// services/apiService.ts
import axios from 'axios';
import type { AxiosResponse, AxiosError } from 'axios';
import type {
  ApiResponse,
  StatisticsResponse,
  NewsResponse,
  SearchResponse,
  StatisticsParams,
  SearchParams,
} from '@/types/api';
import URLS from '@/assets/js/constants/url_constants';

class ApiService {
  /**
   * Generic fetch method with type safety
   */
  private async fetch<T>(url: string): Promise<T> {
    try {
      const response: AxiosResponse<ApiResponse<T>> = await axios.get(url);
      return response.data.data;
    } catch (error) {
      this.handleError(error as AxiosError);
      throw error;
    }
  }

  private handleError(error: AxiosError): void {
    if (error.response) {
      console.error('API Error:', error.response.status, error.response.data);
    } else if (error.request) {
      console.error('Network Error:', error.message);
    } else {
      console.error('Error:', error.message);
    }
  }

  /**
   * Fetch statistical data
   */
  async fetchStatistics(params: StatisticsParams): Promise<StatisticsResponse> {
    const url = `${URLS.API_URL}/api/statistics/category_count?type=${params.type}`;
    return this.fetch<StatisticsResponse>(url);
  }

  /**
   * Fetch latest news items
   */
  async fetchNews(n: number): Promise<NewsResponse> {
    const url = `${URLS.API_URL}/api/statistics/news?n=${n}`;
    return this.fetch<NewsResponse>(url);
  }

  /**
   * Fetch search information
   */
  async fetchSearchInfo(params: SearchParams): Promise<SearchResponse> {
    const { query, helper = true } = params;
    const url = `${URLS.API_URL}/api/search/${query}?helper=${helper}`;
    return this.fetch<SearchResponse>(url);
  }
}

export default new ApiService();
```

### Example 4: Branded Types Implementation

```typescript
// Source: https://effect.website/docs/code-style/branded-types/
// types/utils.ts

declare const __brand: unique symbol;

/**
 * Create a branded type - adds compile-time type safety without runtime cost
 */
type Brand<T, TBrand extends string> = T & { [__brand]: TBrand };

// Export branded type helper
export type { Brand };

// types/models.ts
import type { Brand } from './utils';

// Domain-specific ID types
export type GeneId = Brand<string, 'GeneId'>;
export type EntityId = Brand<string, 'EntityId'>;
export type UserId = Brand<string, 'UserId'>;
export type SymbolId = Brand<string, 'SymbolId'>;
export type DiseaseId = Brand<string, 'DiseaseId'>;
export type PhenotypeId = Brand<string, 'PhenotypeId'>;

/**
 * Factory functions for creating branded values
 * Use these when receiving IDs from external sources (API, route params)
 */
export function createGeneId(id: string): GeneId {
  // Optional: add validation here
  if (!id || id.trim() === '') {
    throw new Error('Invalid GeneId: cannot be empty');
  }
  return id as GeneId;
}

export function createEntityId(id: string | number): EntityId {
  return String(id) as EntityId;
}

export function createUserId(id: string): UserId {
  return id as UserId;
}

// Usage in components/services
import type { GeneId, EntityId } from '@/types/models';
import { createGeneId, createEntityId } from '@/types/models';

// Type-safe function
function fetchGeneDetails(id: GeneId): Promise<Gene> {
  return apiService.get(`/genes/${id}`);
}

// Route params conversion
const geneId = createGeneId(route.params.id as string);
fetchGeneDetails(geneId); // OK

const entityId = createEntityId('123');
fetchGeneDetails(entityId); // Compile error! EntityId !== GeneId
```

### Example 5: Vue Router TypeScript Conversion

```typescript
// Source: https://router.vuejs.org/guide/advanced/navigation-guards.html
// router/routes.ts
import type { RouteRecordRaw } from 'vue-router';

export const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/HomeView.vue'),
    meta: {
      requiresAuth: false,
      title: 'SysNDD - Home',
    },
  },
  {
    path: '/genes',
    name: 'Genes',
    component: () => import('@/views/Genes/ListView.vue'),
    meta: {
      requiresAuth: false,
      title: 'Genes Database',
    },
  },
  {
    path: '/genes/:id',
    name: 'GeneDetail',
    component: () => import('@/views/Genes/DetailView.vue'),
    props: (route) => ({
      geneId: route.params.id as string,
    }),
    meta: {
      requiresAuth: false,
      title: 'Gene Details',
    },
  },
];

// router/index.ts
import { createRouter, createWebHistory } from 'vue-router';
import type { Router } from 'vue-router';
import { routes } from './routes';

const router: Router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

// Type-safe meta interface (module augmentation)
declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean;
    title?: string;
    roles?: string[];
  }
}

export default router;
```

### Example 6: Pinia Store Conversion

```typescript
// Source: https://pinia.vuejs.org/core-concepts/
// Before: stores/ui.js
import { defineStore } from 'pinia';
import { ref } from 'vue';

export const useUIStore = defineStore('ui', () => {
  const scrollbarWidth = ref(0);

  function setScrollbarWidth(width) {
    scrollbarWidth.value = width;
  }

  return {
    scrollbarWidth,
    setScrollbarWidth,
  };
});

// After: stores/ui.ts
import { defineStore } from 'pinia';
import { ref } from 'vue';
import type { Ref } from 'vue';

// State interface (optional but helpful for complex stores)
interface UIState {
  scrollbarWidth: Ref<number>;
}

// Actions interface (documents public API)
interface UIActions {
  setScrollbarWidth(width: number): void;
}

export const useUIStore = defineStore('ui', () => {
  // State with explicit types
  const scrollbarWidth = ref<number>(0);

  // Actions with explicit return types
  function setScrollbarWidth(width: number): void {
    if (width < 0) {
      console.warn('Scrollbar width cannot be negative');
      return;
    }
    scrollbarWidth.value = width;
  }

  // Return with type annotation (optional but helpful)
  return {
    scrollbarWidth,
    setScrollbarWidth,
  } as UIState & UIActions;
});

// Usage with type inference
import { useUIStore } from '@/stores/ui';

const uiStore = useUIStore();
uiStore.setScrollbarWidth(15); // OK
uiStore.setScrollbarWidth('15'); // Error: Argument type not assignable
```

### Example 7: Composable Conversion

```typescript
// Source: Vue 3 Composition API + TypeScript patterns
// Before: composables/useModalControls.js
import { ref } from 'vue';

export default function useModalControls(initialState = false) {
  const isOpen = ref(initialState);

  const open = () => {
    isOpen.value = true;
  };

  const close = () => {
    isOpen.value = false;
  };

  const toggle = () => {
    isOpen.value = !isOpen.value;
  };

  return {
    isOpen,
    open,
    close,
    toggle,
  };
}

// After: composables/useModalControls.ts
import { ref } from 'vue';
import type { Ref } from 'vue';

/**
 * Return type for useModalControls composable
 */
export interface ModalControls {
  isOpen: Ref<boolean>;
  open: () => void;
  close: () => void;
  toggle: () => void;
}

/**
 * Composable for managing modal open/close state
 *
 * @param initialState - Initial open state (default: false)
 * @returns Modal control methods and state
 *
 * @example
 * const modal = useModalControls();
 * modal.open();
 * console.log(modal.isOpen.value); // true
 */
export default function useModalControls(initialState = false): ModalControls {
  const isOpen = ref<boolean>(initialState);

  const open = (): void => {
    isOpen.value = true;
  };

  const close = (): void => {
    isOpen.value = false;
  };

  const toggle = (): void => {
    isOpen.value = !isOpen.value;
  };

  return {
    isOpen,
    open,
    close,
    toggle,
  };
}
```

### Example 8: Constants File Conversion

```typescript
// Source: TypeScript const assertions pattern
// Before: constants/url_constants.js
const URLS = {
  API_URL: import.meta.env.VITE_API_URL || 'http://localhost:7778',
  BASE_URL: import.meta.env.VITE_BASE_URL || 'http://localhost:5173',
};

export default URLS;

// After: constants/url_constants.ts
/**
 * Application URL constants
 * Values sourced from environment variables with fallbacks
 */
const URLS = {
  API_URL: import.meta.env.VITE_API_URL || 'http://localhost:7778',
  BASE_URL: import.meta.env.VITE_BASE_URL || 'http://localhost:5173',
} as const; // const assertion for literal types

export default URLS;

// Type for the URLS object (auto-inferred from const assertion)
export type UrlConfig = typeof URLS;

// Environment variable types (module augmentation)
// Create: src/env.d.ts
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_BASE_URL: string;
  // Add other env vars as they're discovered
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Vue CLI + ts-loader | Vite + vue-tsc | ~2021 | Separate type checking from build = faster dev, recommended by Vue team |
| babel-eslint parser | @typescript-eslint/parser | ~2020 | Native TypeScript parsing, proper type-aware linting |
| ESLint .eslintrc | ESLint 9 flat config | 2024 | Simpler config, better composition, ESLint 10 will remove .eslintrc support |
| Vuex | Pinia | ~2021 | Better TypeScript inference, simpler API, official Vue recommendation |
| vue-meta | @unhead/vue | ~2023 | Vue 3 compatible, better TypeScript support |
| Manual tsconfig | @vue/tsconfig | ~2022 | Official presets prevent misconfig, updated for Vite/esbuild |
| moduleResolution: node | moduleResolution: bundler | TypeScript 5.0 (2023) | Matches actual bundler behavior, required for Vite |
| lib: ES2016 | lib: ES2020 | @vue/tsconfig v0.3+ | Matches Vite 4 transpilation defaults |
| isolatedModules | verbatimModuleSyntax | TypeScript 5.0 (2023) | Superset of isolatedModules, enforces type-only imports |
| Type generation tools | Manual types + optional Zod | ~2024 | Runtime validation > generation for small-medium APIs, Zod provides both |

**Deprecated/outdated:**
- **Vetur extension:** Replaced by Vue - Official (Volar-based) in 2022. Vetur doesn't support Vue 3 Composition API properly.
- **@vue/composition-api:** Plugin for Vue 2, not needed in Vue 3 (built-in).
- **ts-loader in build pipeline:** Replaced by type-checking-only (vue-tsc) separate from build. Makes dev server faster.
- **TSX for Vue components:** `.vue` SFCs with `<script setup lang="ts">` is now standard, TSX only for special cases.
- **Vuex typing patterns:** Pinia has superior inference, Vuex 5 abandoned in favor of Pinia.
- **@tsconfig/node18 or older:** Use @tsconfig/node22 (Node 22 LTS as of 2024-2026).
- **eslint-plugin-vue v6-8:** Use v9 for Vue 3 + ESLint 9 flat config support.

## Open Questions

Things that couldn't be fully resolved:

### 1. **OpenAPI Specification Availability**

- **What we know:** Project has R-based API (plumber), 21 endpoints documented in requirements
- **What's unclear:** Whether OpenAPI/Swagger spec exists for automated type generation
- **Recommendation:**
  - Plan assumes manual types (simpler for 21 endpoints)
  - If OpenAPI spec found during planning, consider openapi-typescript for generation
  - Check `/api/swagger.json` or R plumber auto-generated spec during planning phase

### 2. **Third-Party Library Type Definitions**

- **What we know:** Project uses d3, file-saver, joi, swagger-ui, gsap, html2canvas, and custom libraries (@zanmato/vue3-treeselect, @upsetjs/bundle)
- **What's unclear:** Which need @types/* packages vs have built-in types
- **Recommendation:**
  - Check on conversion: try importing, see if types exist
  - Install @types/* as needed: `npm install --save-dev @types/d3 @types/file-saver`
  - Some may not have types - create local declarations in `src/types/vendor.d.ts`

### 3. **Optimal File Conversion Order**

- **What we know:** User decided infrastructure first (main, router, stores, services, composables), components later
- **What's unclear:** Exact order within each category to minimize dependency errors
- **Recommendation:**
  - Order by dependency: constants → types → services → composables → stores → router → main
  - Convert entire directories at once (all stores, all composables) to avoid mixing
  - Document in PLAN.md with specific file list and rationale

### 4. **Existing ESLint Rules to Preserve**

- **What we know:** Current .eslintrc.json has Airbnb config with many rules disabled (no-unused-vars, camelcase, max-len, etc.)
- **What's unclear:** Which disabled rules were intentional style choices vs workarounds for JS limitations
- **Recommendation:**
  - Start with current relaxed rules in ESLint 9 flat config
  - Re-enable gradually as TypeScript solves problems (e.g., camelcase might be safe with strict typing)
  - Set severity to 'warn' during migration, 'error' after complete

### 5. **Migration Timeline and Incremental vs Big-Bang**

- **What we know:** User chose incremental approach with `allowJs: true` coexistence
- **What's unclear:** How long coexistence period should last, criteria for completion
- **Recommendation:**
  - Phase 14 completes infrastructure only
  - Set completion criteria: all infrastructure files converted, green build with vue-tsc
  - Component conversion in dedicated later phase (separate planning)

### 6. **Runtime Validation Strategy**

- **What we know:** Zod provides runtime validation + type inference, medical app needs reliability
- **What's unclear:** Whether to add Zod validation to all API responses or just critical ones
- **Recommendation:**
  - Start with manual types (simpler, no runtime cost)
  - Add Zod selectively for critical endpoints (user data, medical records)
  - Revisit in Phase 14 planning: evaluate API reliability, error frequency
  - Consider Zod's `z.infer<>` for type generation if runtime validation desired

## Sources

### Primary (HIGH confidence)
- [Vue.js Official TypeScript Guide](https://vuejs.org/guide/typescript/overview) - TypeScript setup, vue-tsc, tsconfig requirements
- [Vue.js TypeScript with Composition API](https://vuejs.org/guide/typescript/composition-api) - Script setup patterns
- [Official @vue/tsconfig Repository](https://github.com/vuejs/tsconfig) - Base configuration structure, compiler options
- [Pinia Core Concepts](https://pinia.vuejs.org/core-concepts/) - Store typing patterns
- [Vue Router Navigation Guards](https://router.vuejs.org/guide/advanced/navigation-guards.html) - Router TypeScript patterns
- [TypeScript 5.7 Features](https://javascript-conference.com/blog/typescript-5-7-5-8-features-ecmascript-direct-execution/) - noImplicitAny improvements
- [Effect Branded Types](https://effect.website/docs/code-style/branded-types/) - Branded type implementation pattern

### Secondary (MEDIUM confidence)
- [Integrating TypeScript with Vue.js 3 Best Practices](https://borstch.com/blog/development/integrating-typescript-with-vuejs-3-best-practices) - Migration strategies
- [ESLint 9 Flat Config Tutorial](https://dev.to/aolyang/eslint-9-flat-config-tutorial-2bm5) - Modern ESLint setup
- [Official @vue/eslint-config-typescript](https://github.com/vuejs/eslint-config-typescript) - ESLint TypeScript integration
- [Prettier Options Documentation](https://prettier.io/docs/options) - Formatting configuration
- [Husky + lint-staged Guide](https://betterstack.com/community/guides/scaling-nodejs/husky-and-lint-staged/) - Pre-commit hooks
- [Zod Official Documentation](https://zod.dev/) - Runtime validation
- [openapi-typescript Repository](https://github.com/openapi-ts/openapi-typescript) - API type generation option
- [TypeScript Official Migration Guide](https://www.typescriptlang.org/docs/handbook/migrating-from-javascript.html) - JavaScript to TypeScript migration
- [Vue 3 Migration to TypeScript (Medium)](https://medium.com/@ichsanputr/use-typescript-in-existing-vue-3-project-132d79c31271) - Practical migration guide

### Tertiary (LOW confidence)
- [Vue 3 + ESLint 9 + Prettier Setup](https://dev.to/devidev/setting-up-eslint-9130-with-prettier-typescript-vuejs-and-vscode-autosave-autoformat-n0) - Community setup guide
- [Branded Types in TypeScript (DEV Community)](https://dev.to/saleor/branded-types-in-typescript-techniques-340f) - Alternative branded type patterns
- [Strong Typing in Vue 3 (Medium)](https://medium.com/@vasanthancomrads/%EF%B8%8F-strong-typing-in-vue-3-with-typescript-best-practices-for-maintainability-e77e5474e06a) - Community best practices

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Vue/TypeScript tooling verified through Vue.js docs, @vue/tsconfig, vue-tsc npm page
- Architecture: HIGH - Patterns from official Vue.js TypeScript guide, Pinia docs, Vue Router docs
- ESLint/Prettier setup: MEDIUM - ESLint 9 flat config verified but still evolving, Prettier config stable
- Pitfalls: HIGH - Based on official Vite documentation caveats, Vue TypeScript guide warnings
- API type generation: MEDIUM - Manual typing recommended but OpenAPI option available if spec exists
- Branded types: MEDIUM - Pattern verified but specific implementation (factory functions, validation) is discretionary

**Research date:** 2026-01-23
**Valid until:** ~60 days (February 2026) - TypeScript/Vue stack is stable, ESLint 9 is current and won't change rapidly, Vite is stable at v7
