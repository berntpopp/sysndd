// app/tests/e2e/global-setup.ts
// Global setup for the Playwright suite. Re-seeds the deterministic fixtures
// (test users + the E2E baseline data) before every `playwright test`
// invocation so every run starts from a known state. Re-seeding users keeps
// mutation specs (e.g. auth.password-update.spec.ts) from leaking across runs;
// re-seeding the baseline keeps the data-dependent specs (public table filters,
// curation comparisons, gene-detail cards, slow-provider resilience, Modify
// Entity) supplied with rows even after a spec touches them.
//
// Wired by playwright.config.ts via `globalSetup`. Each make target shells out
// to `mysql < db/fixtures/<file>`; we reuse them rather than duplicating the
// SQL invocation here. A missing fixture file or make target (e.g. running
// specs against a non-Playwright stack) is skipped with a warning rather than
// failing the run.

import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Ordered: users first, then the baseline data (some baseline rows — the
// re-review assignment — reference a seeded user).
const SEED_STEPS: ReadonlyArray<{ fixture: string; target: string }> = [
  { fixture: 'playwright_users.sql', target: '_playwright-seed-users' },
  { fixture: 'playwright_e2e_baseline.sql', target: '_playwright-seed-e2e-baseline' },
];

export default async function globalSetup(): Promise<void> {
  // Locate the repo root by climbing up from this file. The Playwright
  // config is at app/playwright.config.ts, so this file's dirname is
  // app/tests/e2e/. Three levels up is the repo root.
  const here = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(here, '..', '..', '..');

  for (const { fixture, target } of SEED_STEPS) {
    const fixturePath = resolve(repoRoot, 'db', 'fixtures', fixture);
    if (!existsSync(fixturePath)) {
      console.warn(`[global-setup] fixture missing: ${fixturePath} — skipping ${target}`);
      continue;
    }

    try {
      execSync(`make ${target}`, { cwd: repoRoot, stdio: 'inherit' });
    } catch (err) {
      console.warn(
        `[global-setup] make ${target} failed; continuing without reseed: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }
}
