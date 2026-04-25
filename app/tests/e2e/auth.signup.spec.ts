// app/tests/e2e/auth.signup.spec.ts
import { test, expect } from './fixtures/auth';
import { uniqueName, uniqueEmail } from './fixtures/data';

test.describe('auth: signup flow', () => {
  test('user can submit a registration request', async ({ page }) => {
    const username = uniqueName('newuser').replace(/-/g, '').slice(0, 18);
    const email = uniqueEmail('newuser');
    // ORCID format is NNNN-NNNN-NNNN-NNNX. Tests a synthetic but
    // syntactically-valid ORCID; the API only validates regex, not checksum.
    const ts = Date.now().toString().slice(-10).padStart(10, '0');
    const orcid = `${ts.slice(0, 4)}-${ts.slice(4, 8)}-${ts.slice(8, 10)}00-000X`;

    await page.goto('/Register');

    // RegisterView uses placeholders, not labels. Use placeholder selectors
    // to keep the spec aligned with the live UI.
    await page.getByPlaceholder('Username').fill(username);
    await page.getByPlaceholder(/your-institution\.com/).fill(email);
    await page.getByPlaceholder(/NNNN-NNNN/).fill(orcid);
    await page.getByPlaceholder('First name').fill('PW');
    await page.getByPlaceholder('Family name').fill('Test');
    await page
      .getByPlaceholder('Your interest in SysNDD')
      .fill('Playwright e2e test fixture user (auto-generated, may be deleted).');

    await page.getByText(/I accept the terms and use/i).click();

    await page.getByRole('button', { name: /^Register$/ }).click();

    // Success toast: "Your registration request has been send ..."
    await expect(page.getByText(/registration request has been send/i)).toBeVisible({
      timeout: 10_000,
    });

    await page.screenshot({
      path: 'tests/e2e/screenshots/auth.signup__success__desktop.png',
      fullPage: true,
    });

    // Note: the registered account requires admin approval before its
    // password can be set (via /PasswordReset?token=...). The login flow is
    // therefore NOT exercised here — see auth.login.spec.ts which uses the
    // pre-seeded `pw_*` accounts from db/fixtures/playwright_users.sql.
  });
});
