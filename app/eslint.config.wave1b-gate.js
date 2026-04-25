// Wave 1b boundary gate — extends the main ESLint config with the
// `no-restricted-imports` and `no-restricted-syntax` rules that enforce the
// typed-API migration boundary in src/views/** and src/components/**.
//
// Wave 0 introduces this gate as ADVISORY (CI runs with continue-on-error).
// Wave 1b flips it to required; once all 4 sub-branches merge, the gate
// must pass.
//
// Usage:
//   npm run lint:wave1b-gate
//   eslint --config eslint.config.wave1b-gate.js <files...>
//
// The rules:
//   - `no-restricted-imports` — block default value-imports of `axios`. Type-only
//     imports (`import type { ... } from 'axios'`) remain permitted.
//   - `no-restricted-syntax` — block `this.axios.<verb>(...)` calls (Options
//     API legacy pattern still in use across views).
//
// See `.planning/superpowers/specs/2026-04-25-v11.1-finish-hardening-design.md`
// §4 (Wave 1b precise grep gate).

import baseConfig from './eslint.config.js';

export default [
  ...baseConfig,
  {
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
  },
];
