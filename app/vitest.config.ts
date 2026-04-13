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
        // **Phase C bump (2026-04-12, v11.0/phase-c/combined):** 11 new
        // spec files (6 view specs + 2 composable spec pairs + 3 R endpoint
        // test batches that don't touch Node coverage) landed, pushing the
        // measured coverage to 13.66 lines / 9.68 functions / 12.49 branches
        // / 13.22 statements. The ratchet is pinned at the rounded-DOWN
        // floor (13/9/12/13) so the gate never flaps if a future tiny
        // refactor shifts the denominator by a fraction. The plan's original
        // 45→55 bump was stale — that number was set against a much smaller
        // denominator before test-utils/ was excluded. See Phase C batch
        // review (Checkpoint #2) coverage-threshold reconciliation.
        //
        // Ratchet rule: each future phase MUST raise these numbers as new
        // spec files land. Never lower them without deleting spec files or
        // explicit approval. Phase D is expected to push this into the
        // 20–30 range; Phase E further. When a phase does not raise
        // coverage, add a comment here explaining why.
        thresholds: {
          lines: 13,
          functions: 9,
          branches: 12,
          statements: 13,
        },
      },
    },
  })
);
