// app/tests/e2e/auth.password-reset.spec.ts
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

test.describe('auth: password reset flow', () => {
  test('reset request → reset change → new password works', async ({ page, request }) => {
    // The reset-token retrieval mechanism is environment-specific. The
    // current SysNDD API only emails the reset link (no backdoor endpoint
    // exposes the freshly-issued JWT). Until a `/api/test/last-reset-token`
    // (or equivalent) is added behind a Playwright-only env flag, the
    // change-password leg of this flow cannot be exercised end-to-end.
    //
    // The Wave 0 plan explicitly leaves the skip in place rather than have
    // each Playwright runner invent a backdoor (that would be API surface
    // change beyond Wave 0 scope). Wave 1a or a later phase can pull the
    // skip once a deterministic token-retrieval mechanism exists.
    test.skip(
      true,
      'reset-token retrieval mechanism not yet wired into the Playwright stack — see plan W0.11',
    );

    // The block below documents the intended shape of the test once the
    // backdoor exists. It is unreachable due to the skip above; eslint /
    // tsc still type-check it.

    const { email } = testUsers.user;
    const newPassword = 'ResetPass!2026';

    await page.goto('/PasswordReset');
    await page.getByPlaceholder(/email/i).fill(email);
    await page.getByRole('button', { name: /reset|send/i }).click();
    await expect(page.getByText(/email|sent|reset link/i)).toBeVisible();

    const tokenRes = await request.get(
      `/api/admin/last-reset-token?email=${encodeURIComponent(email)}`,
    );
    if (!tokenRes.ok()) {
      test.skip(true, 'reset-token retrieval mechanism not available in this stack');
    }
    const token = ((await tokenRes.json()) as { token: string }).token;

    await page.goto(`/PasswordReset/${token}`);
    await page.getByPlaceholder(/new password/i).first().fill(newPassword);
    await page.getByPlaceholder(/confirm/i).fill(newPassword);
    await page.getByRole('button', { name: /set|change|reset/i }).click();
    await expect(page.getByText(/password.*updated|success/i)).toBeVisible();

    await page.screenshot({
      path: 'tests/e2e/screenshots/auth.password-reset__success__desktop.png',
      fullPage: true,
    });
  });
});
