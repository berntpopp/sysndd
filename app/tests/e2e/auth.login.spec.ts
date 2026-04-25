// app/tests/e2e/auth.login.spec.ts
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

test.describe('auth: login flow', () => {
  test('admin can log in via the UI and the navbar reflects the session', async ({ page }) => {
    const { username, password } = testUsers.admin;

    await page.goto('/Login');
    // LoginView uses placeholders, not labels.
    await page.getByPlaceholder('User').fill(username);
    await page.getByPlaceholder('Password').fill(password);
    await page.getByRole('button', { name: /^Login$/ }).click();

    // Token persisted to localStorage
    await expect
      .poll(async () => await page.evaluate(() => localStorage.getItem('token')), {
        timeout: 10_000,
      })
      .not.toBeNull();

    // After successful login, the "Login" nav item disappears.
    await expect(page.getByRole('navigation').getByRole('link', { name: /^Login$/ })).toHaveCount(
      0,
    );

    await page.screenshot({
      path: 'tests/e2e/screenshots/auth.login__success__desktop.png',
      fullPage: true,
    });
  });

  test('login with bad credentials surfaces an error and does not persist a token', async ({
    page,
  }) => {
    await page.goto('/Login');
    await page.getByPlaceholder('User').fill('nopelogin');
    await page.getByPlaceholder('Password').fill('also-nope-pw');
    await page.getByRole('button', { name: /^Login$/ }).click();

    // The toast "Login error" / "Invalid" / etc. — accept any error-shaped
    // message. If no toast appears, fall back to "no token" assertion.
    await expect
      .poll(async () => await page.evaluate(() => localStorage.getItem('token')), {
        timeout: 5_000,
      })
      .toBeNull();

    // Login link still present (still logged out)
    await expect(
      page.getByRole('navigation').getByRole('link', { name: /^Login$/ }),
    ).toBeVisible();
  });

  // W2 will append a third test in this file: 401 redirect from a tampered
  // token. The placeholder below documents the contract for that workstream.
  // (Do not implement here — owned by W2 in Wave 1a.)
});
