// app/tests/e2e/auth.password-update.spec.ts
import { test, expect } from './fixtures/auth';
import { testUsers } from './fixtures/test-users';

const NEW_PASSWORD = 'UpdPass!2026';

test.describe('auth: password update (logged-in self-service)', () => {
  // Restore the admin password via the same API endpoint the test exercises,
  // so any other admin-using test that fires its `loggedInAs('admin')`
  // fixture concurrently in another worker still sees valid credentials.
  //
  // Earlier iterations relied on `make _playwright-seed-users` here, but the
  // shell-out + mysql round-trip opened a multi-second window during which
  // parallel admin-role smoke specs flaked on 401. Resetting the password
  // through the API closes that window to a single HTTP request.
  test.afterEach(async ({ request }) => {
    // Step 1: log in with the new password to get a fresh token.
    const authRes = await request.post('/api/auth/authenticate', {
      data: { user_name: testUsers.admin.username, password: NEW_PASSWORD },
    });
    if (!authRes.ok()) {
      // Already restored or never mutated — nothing to do.
      return;
    }
    const tokenRaw = (await authRes.text()).trim();
    let token: string | undefined;
    try {
      const parsed: unknown = JSON.parse(tokenRaw);
      if (Array.isArray(parsed) && typeof parsed[0] === 'string') token = parsed[0];
      else if (typeof parsed === 'string') token = parsed;
    } catch {
      token = tokenRaw.replace(/^"|"$/g, '');
    }
    if (!token) return;

    // Step 2: ask the API for the user_id (signin returns the full payload).
    const signinRes = await request.get('/api/auth/signin', {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!signinRes.ok()) return;
    const signinPayload = (await signinRes.json()) as { user_id?: number[] | number };
    const userId = Array.isArray(signinPayload.user_id)
      ? signinPayload.user_id[0]
      : signinPayload.user_id;
    if (typeof userId !== 'number') return;

    // Step 3: change it back to the seeded plaintext.
    await request.put('/api/user/password/update', {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        user_id_pass_change: userId,
        old_pass: NEW_PASSWORD,
        new_pass_1: testUsers.admin.password,
        new_pass_2: testUsers.admin.password,
      },
    });
  });

  test('admin updates their own password and sees a success toast', async ({ loggedInAs }) => {
    const page = await loggedInAs('admin');
    const oldPassword = testUsers.admin.password;
    // Must satisfy the password_complexity rule: 8+ chars, upper, lower,
    // number, special — see UserView.vue defineRule('password_complexity').

    await page.goto('/User');

    // The password change form is collapsed inside a BCollapse — click the
    // "Change Password" toggle first to reveal the inputs.
    await page.getByRole('button', { name: /Change Password/i }).click();

    await page.getByPlaceholder('Enter current password').fill(oldPassword);
    await page.getByPlaceholder('Enter new password').fill(NEW_PASSWORD);
    await page.getByPlaceholder('Repeat new password').fill(NEW_PASSWORD);

    await page.getByRole('button', { name: /Update Password/i }).click();

    // The toast message comes from the API response.data.message — it
    // typically reads "Password successfully changed".
    await expect(page.getByText(/password.*(success|changed|updated)/i).first()).toBeVisible({
      timeout: 10_000,
    });

    // The afterEach hook restores admin's password via PUT /api/user/password/update,
    // closing the credential-mutation window to a single HTTP round-trip
    // (vs the seconds-long mysql exec path used previously).
  });
});
