// ESLint 9 flat config with TypeScript and Vue support
// Migration strategy: 'warn' not 'error' to avoid blocking development
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import pluginVue from 'eslint-plugin-vue';
import eslintConfigPrettier from 'eslint-config-prettier';
import globals from 'globals';

// v11.0 closeout §8.1: forbid direct localStorage token/user reads outside
// the permitted owners (useAuth.ts, plugins/axios.ts, test-utils, specs).
// The apiClient request interceptor is the single injection point for the
// Bearer header; call sites must route through `useAuth()` or `apiClient`.
//
// F1 scope note: the guardrail is `error` so regressions fail lint.
// The `ignores` below include the 24 files that F2a–F2e will migrate —
// each F2 worktree removes its target files from this list as it lands.
// When the last F2 worktree merges, the list collapses to just the
// permitted owners. See `.plans/v11.0/closeout.md` §3 F2a–F2e.
const CLOSEOUT_NO_LOCAL_STORAGE_TOKEN = {
  files: ['src/**/*.{ts,vue}'],
  ignores: [
    // Permitted owners (§2 goal 1 + test-utils + specs)
    'src/composables/useAuth.ts',
    'src/plugins/axios.ts',
    'src/test-utils/**',
    '**/*.spec.ts',

    // F2a pending migrations (14 files)
    'src/views/admin/AdminStatistics.vue',
    'src/views/admin/ManageLLM.vue',
    'src/views/curate/ApproveStatus.vue',
    'src/views/curate/ApproveReview.vue',
    'src/views/curate/CreateEntity.vue',
    'src/composables/useAsyncJob.ts',
    'src/composables/annotations/useAnnotationFormatters.ts',
    'src/composables/review/useReviewApprovalActions.ts',
    'src/composables/useCmsContent.ts',
    'src/views/curate/composables/useReviewForm.ts',
    'src/views/curate/composables/useStatusForm.ts',
    'src/components/llm/LlmCacheManager.vue',
    'src/components/llm/LlmLogViewer.vue',
    'src/composables/useLlmAdmin.ts',

    // F2b migrations landed — the 9 files now route through `useAuth()`
    // / `apiClient` and no longer need the ignore entries.

    // F2c pending migration (1 file)
    'src/views/review/Review.vue',

    // F2d pending migration (1 file)
    'src/views/curate/ManageReReview.vue',
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

  // Prettier integration (disables conflicting rules)
  eslintConfigPrettier,
];
