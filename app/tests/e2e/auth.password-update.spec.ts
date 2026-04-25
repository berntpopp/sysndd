// app/tests/e2e/auth.password-update.spec.ts
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..', '..', '..');

test.describe('auth: password update (logged-in self-service)', () => {
  // Re-apply the user fixture after the password-mutating test so the admin
  // role's plaintext credentials remain valid for parallel workers and any
  // later admin-role specs in the same run.
  test.afterEach(() => {
    try {
      execSync('make _playwright-seed-users', { cwd: repoRoot, stdio: 'pipe' });
    } catch (err) {
      console.warn(
        `[auth.password-update] reseed failed: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  });

  test('admin updates their own password and sees a success toast', async ({ loggedInAs }) => {
    const page = await loggedInAs('admin');
    const oldPassword = testUsers.admin.password;
    // Must satisfy the password_complexity rule: 8+ chars, upper, lower,
    // number, special — see UserView.vue defineRule('password_complexity').
    const newPassword = 'UpdPass!2026';

    await page.goto('/User');

    // The password change form is collapsed inside a BCollapse — click the
    // "Change Password" toggle first to reveal the inputs.
    await page.getByRole('button', { name: /Change Password/i }).click();

    await page.getByPlaceholder('Enter current password').fill(oldPassword);
    await page.getByPlaceholder('Enter new password').fill(newPassword);
    await page.getByPlaceholder('Repeat new password').fill(newPassword);

    await page.getByRole('button', { name: /Update Password/i }).click();

    // The toast message comes from the API response.data.message — it
    // typically reads "Password successfully changed".
    await expect(page.getByText(/password.*(success|changed|updated)/i).first()).toBeVisible({
      timeout: 10_000,
    });

    await page.screenshot({
      path: 'tests/e2e/screenshots/auth.password-update__success__desktop.png',
      fullPage: true,
    });

    // Note: the admin's password is now newPassword. The Playwright
    // global-setup hook re-applies db/fixtures/playwright_users.sql before
    // each `playwright test` invocation, so subsequent runs start clean.
    // Within a single run the spec relies on test isolation (no other test
    // re-authenticates as admin AFTER this one in the same run); should
    // that ever break, an `afterEach` hook here can re-seed via
    // `make _playwright-seed-users`.
  });
});
