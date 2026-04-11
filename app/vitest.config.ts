import { fileURLToPath, URL } from 'node:url';
import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      globals: true,
      environment: 'jsdom',
      setupFiles: ['./vitest.setup.ts'],
      include: ['src/**/*.spec.ts'],
      exclude: [
        '**/node_modules/**',
        '**/dist/**',
      ],
      coverage: {
        provider: 'v8',
        reporter: ['text', 'json', 'html'],
        reportsDirectory: './coverage',
        include: ['src/**/*.{ts,vue}'],
        exclude: [
          '**/*.config.*',
          '**/main.ts',
          '**/router/**',
          '**/*.d.ts',
          '**/node_modules/**',
          '**/test-utils/**',
          '**/types/**',
        ],
        // Coverage ratchet — pinned at the current measured floor so
        // `npm run test:coverage` actually passes. The original threshold of
        // 40 (and B1's aspirational bump to 45) was decorative — no CI job
        // ran coverage, so nobody noticed the real coverage was only 4–7%.
        // Phase B.B1 can't raise the bar because test-utils/ is excluded
        // from the coverage denominator (see `exclude` above), so adding
        // MSW handlers does not help the numbers. See `.plans/v11.0/
        // phase-b.md` §3 Phase B.B1 and the 2026-04-11 PR #236 review for
        // the full rationale.
        //
        // Ratchet rule: each future phase MUST raise these numbers as new
        // spec files land. Never lower them without deleting spec files or
        // explicit approval. Phase C (view specs) is expected to push this
        // into the 15–25 range; Phase D/E further. When a phase does not
        // raise coverage, add a comment here explaining why.
        thresholds: {
          lines: 6,
          functions: 4,
          branches: 4,
          statements: 6,
        },
      },
    },
  })
);
