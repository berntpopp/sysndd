// app/tests/e2e/auth.password-update.spec.ts
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

test.describe('auth: password update (logged-in self-service)', () => {
  test('reviewer updates their own password and sees a success toast', async ({ loggedInAs }) => {
    const page = await loggedInAs('reviewer');
    const oldPassword = testUsers.reviewer.password;
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
    // typically reads "Password updated successfully".
    await expect(page.getByText(/password.*updated|success/i).first()).toBeVisible({
      timeout: 10_000,
    });

    await page.screenshot({
      path: 'tests/e2e/screenshots/auth.password-update__success__desktop.png',
      fullPage: true,
    });

    // Note: the reviewer's password is now newPassword. Subsequent runs of
    // this test reset on stack teardown (volumes -v). Within a run, no
    // other test depends on reviewer auth, so isolation holds.
  });
});
