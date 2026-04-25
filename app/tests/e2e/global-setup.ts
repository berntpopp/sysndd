// app/tests/e2e/global-setup.ts
// Global setup for the Playwright suite. Re-seeds the test users from
// db/fixtures/playwright_users.sql via `make _playwright-seed-users` so
// every `playwright test` invocation starts from a known state. Specs
// that mutate user-table state (e.g. auth.password-update.spec.ts) no
// longer leak across runs.
//
// Wired by playwright.config.ts via `globalSetup`. The make target itself
// shells out to `mysql < db/fixtures/playwright_users.sql`; we reuse it
// rather than duplicating the SQL invocation here. If the make target is
// missing (e.g. running specs against a non-Playwright stack), the seed
// step is skipped with a warning.

import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export default async function globalSetup(): Promise<void> {
  // Locate the repo root by climbing up from this file. The Playwright
  // config is at app/playwright.config.ts, so this file's dirname is
  // app/tests/e2e/. Three levels up is the repo root.
  const here = dirname(fileURLToPath(import.meta.url));
  const repoRoot = resolve(here, '..', '..', '..');
  const fixturePath = resolve(repoRoot, 'db', 'fixtures', 'playwright_users.sql');

  if (!existsSync(fixturePath)) {
    console.warn(`[global-setup] fixture missing: ${fixturePath} — skipping user reseed`);
    return;
  }

  try {
    execSync('make _playwright-seed-users', {
      cwd: repoRoot,
      stdio: 'inherit',
    });
  } catch (err) {
    console.warn(
      `[global-setup] make _playwright-seed-users failed; continuing without reseed: ${
        err instanceof Error ? err.message : String(err)
      }`,
    );
  }
}
