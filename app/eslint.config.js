// ESLint 9 flat config with TypeScript and Vue support
// Migration strategy: 'warn' not 'error' to avoid blocking development
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import pluginVue from 'eslint-plugin-vue';
import eslintConfigPrettier from 'eslint-config-prettier';
import globals from 'globals';

// v11.1 W2.2 finish-hardening: lock the typed-API boundary in src/views/**
// and src/components/**. Wave 1b removed every raw-axios call site; this
// rule prevents regressions.
//
//   - `no-restricted-imports` — block default value-imports of `axios`.
//     Type-only imports (`import type { ... } from 'axios'`) remain
//     permitted (the spec §1 explicitly allows them and the strict-scope
//     expansion in Wave 2 will retire them organically).
//   - `no-restricted-syntax` — block `this.axios.<verb>(...)` calls
//     (Options API legacy pattern that the migration eliminated).
//
// During Waves 0–1b this rule lived in a separate eslint.config.wave1b-gate.js
// invoked via `npm run lint:wave1b-gate`. Wave 2 folds it into the main
// config so `npm run lint` (and CI's `Run ESLint` step) enforce it on
// every push.
//
// See `.planning/superpowers/specs/2026-04-25-v11.1-finish-hardening-design.md`
// §4 Wave 1b precise grep gate (precise grep + ESLint rule are equivalent).
const FH_NO_RAW_AXIOS_BOUNDARY = {
  files: ['src/views/**/*.{vue,ts}', 'src/components/**/*.{vue,ts}'],
  ignores: ['**/*.spec.ts'],
  rules: {
    'no-restricted-imports': [
      'error',
      {
        paths: [
          {
            name: 'axios',
            importNames: ['default'],
            message:
              "Use typed clients from '@/api/*' instead. Type-only imports (import type { ... } from 'axios') remain allowed.",
          },
        ],
      },
    ],
    'no-restricted-syntax': [
      'error',
      {
        selector:
          "MemberExpression[object.type='ThisExpression'][property.name='axios']",
        message:
          "Use typed clients from '@/api/*' instead of this.axios.* (vue-axios plugin).",
      },
    ],
  },
};

// v11.0 closeout §8.1: forbid direct localStorage token/user reads outside
// the permitted owners (useAuth.ts, plugins/axios.ts, test-utils, specs).
// The apiClient request interceptor is the single injection point for the
// Bearer header; call sites must route through `useAuth()` or `apiClient`.
//
// F1 scope note: the guardrail is `error` so regressions fail lint.
// The `ignores` below include the 24 files that F2a–F2e will migrate —
// each F2 worktree removes its target files from this list as it lands.
// When the last F2 worktree merges, the list collapses to just the
// permitted owners. See `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2a–F2e.
const CLOSEOUT_NO_LOCAL_STORAGE_TOKEN = {
  files: ['src/**/*.{ts,vue}'],
  ignores: [
    // Permitted owners (§2 goal 1 + test-utils + specs)
    'src/composables/useAuth.ts',
    'src/plugins/axios.ts',
    'src/test-utils/**',
    '**/*.spec.ts',

    // F2a + F2b + F2c + F2d migrations landed — all 25 files now route
    // through `useAuth()` / `apiClient` and no longer need the ignore
    // entries. The ignore list collapses to just the permitted owners
    // (useAuth.ts, plugins/axios.ts, test-utils, specs). See
    // `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2a–F2d.
  ],
  rules: {
    // The selectors cover three surface forms so the guardrail cannot be
    // bypassed by qualifying the global:
    //   - `localStorage.token`          (direct)
    //   - `window.localStorage.token`   (window-qualified)
    //   - `globalThis.localStorage.token` (globalThis-qualified)
    // Both static and computed property syntax (`localStorage['token']`) are
    // matched for the direct member-access rule.
    'no-restricted-syntax': [
      'error',
      {
        selector: [
          "MemberExpression[object.name='localStorage'][computed=false][property.name=/^(token|user)$/]",
          "MemberExpression[object.name='localStorage'][computed=true][property.value=/^(token|user)$/]",
          "MemberExpression[object.object.name=/^(window|globalThis)$/][object.property.name='localStorage'][computed=false][property.name=/^(token|user)$/]",
          "MemberExpression[object.object.name=/^(window|globalThis)$/][object.property.name='localStorage'][computed=true][property.value=/^(token|user)$/]",
        ].join(', '),
        message:
          'Direct localStorage.token / localStorage.user access is forbidden outside app/src/composables/useAuth.ts. Use useAuth() or apiClient.',
      },
      {
        selector: [
          "CallExpression[callee.object.name='localStorage'][callee.property.name=/^(getItem|setItem|removeItem)$/][arguments.0.value=/^(token|user)$/]",
          "CallExpression[callee.object.object.name=/^(window|globalThis)$/][callee.object.property.name='localStorage'][callee.property.name=/^(getItem|setItem|removeItem)$/][arguments.0.value=/^(token|user)$/]",
        ].join(', '),
        message:
          "Direct localStorage.{get,set,remove}Item('token'|'user') access is forbidden outside app/src/composables/useAuth.ts. Use useAuth() or apiClient.",
      },
    ],
  },
};

export default [
  // Global ignores
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'public/**',
      'coverage/**',
      '*.config.js',
      '*.config.ts',
      '.eslintrc*',
      // Playwright E2E fixtures + specs are type-checked via the ad-hoc
      // tsc invocation in CI (Wave 0 of v11.1) and not via the project
      // tsconfig.json. ESLint's typescript-eslint parser would reject them
      // as "not in project", so we exclude the directory globally.
      'tests/e2e/**',
      // v11.3 W4 perf bench specs follow the same pattern as e2e tests:
      // type-checked via ad-hoc tsc and not in the main tsconfig project.
      'tests/perf/**',
      'playwright-report/**',
    ],
  },

  // Base JavaScript recommendations
  js.configs.recommended,

  // TypeScript recommendations
  ...tseslint.configs.recommended,

  // Vue 3 recommendations
  ...pluginVue.configs['flat/recommended'],

  // Global configuration
  {
    files: ['**/*.{js,ts,vue,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.browser,
        ...globals.node,
        ...globals.es2021,
      },
      parserOptions: {
        ecmaVersion: 2022,
        sourceType: 'module',
      },
    },
    rules: {
      // Migration strategy: warnings instead of errors
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': ['warn', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
        caughtErrorsIgnorePattern: '^_',
        destructuredArrayIgnorePattern: '^_',
      }],
      '@typescript-eslint/no-unused-expressions': 'warn',
      'no-unused-vars': 'off', // TypeScript handles this
      'no-undef': 'warn',

      // Preserve existing relaxed rules
      'no-console': 'off',
      'no-debugger': 'warn',

      // Vue-specific rules (warnings for migration)
      'vue/multi-word-component-names': 'warn',
      'vue/no-v-html': 'warn',
      'vue/require-default-prop': 'warn',
      'vue/require-prop-types': 'warn',
      'vue/valid-v-slot': ['error', { allowModifiers: true }],

      // Allow async component setup
      'vue/no-setup-props-destructure': 'off',

      // TypeScript-specific relaxed rules
      '@typescript-eslint/no-require-imports': 'warn',
      '@typescript-eslint/ban-ts-comment': 'warn',
    },
  },

  // Disable no-undef for TypeScript files (TS compiler handles this;
  // avoids false positives with Vitest globals and type-only imports)
  {
    files: ['**/*.ts', '**/*.tsx', '**/*.vue'],
    rules: {
      'no-undef': 'off',
    },
  },

  // TypeScript-specific configuration
  {
    files: ['**/*.ts', '**/*.tsx'],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
        project: './tsconfig.json',
        extraFileExtensions: ['.vue'],
      },
    },
  },

  // Vue file TypeScript configuration
  {
    files: ['**/*.vue'],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
        ecmaVersion: 2022,
        sourceType: 'module',
        extraFileExtensions: ['.vue'],
      },
    },
  },

  // v11.0 closeout F1: localStorage token/user guardrail (§8.1).
  CLOSEOUT_NO_LOCAL_STORAGE_TOKEN,

  // v11.1 W2.2 finish-hardening: raw-axios boundary in views/ and components/.
  FH_NO_RAW_AXIOS_BOUNDARY,

  // Standalone Node scripts under app/scripts/. They run under `node`, not
  // in the browser, and use globals like process / console. The shared
  // browser-or-node globals already include node, but `no-undef` is enabled
  // for non-TS files (the TS-files rule that disables it does not apply
  // here because these scripts are .mjs / .js). Disable `no-undef` for the
  // scripts dir specifically and silence the expected console / unused
  // capture-group regex bindings.
  {
    files: ['scripts/**/*.{mjs,js}'],
    languageOptions: {
      sourceType: 'module',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      'no-undef': 'off',
      'no-console': 'off',
      // Audit-style scripts use `while ((m = re.exec(s)) !== null)` patterns
      // where the binding exists only to drive the loop. The capture binding
      // is intentionally unused.
      '@typescript-eslint/no-unused-vars': ['warn', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^[_se]$',
        caughtErrorsIgnorePattern: '^_',
      }],
    },
  },

  // Prettier integration (disables conflicting rules)
  eslintConfigPrettier,
];
