// ESLint 9 flat config with TypeScript and Vue support
// Migration strategy: 'warn' not 'error' to avoid blocking development
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import pluginVue from 'eslint-plugin-vue';
import eslintConfigPrettier from 'eslint-config-prettier';
import globals from 'globals';

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

  // Prettier integration (disables conflicting rules)
  eslintConfigPrettier,
];
