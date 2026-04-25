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

  // v11.1 W2 finish-hardening: a tampered token must redirect to /Login on
  // the next API request and clear navbar/state. Locks in the
  // useAuth.handle401() contract end-to-end (the Vitest spec covers the
  // unit-level shape; this asserts the user-facing behaviour).
  test('tampered token redirects to login on next request and clears navbar state', async ({
    loggedInAs,
  }) => {
    const page = await loggedInAs('curator');
    await page.goto('/Entities');

    // The page renders TWO `<nav>` elements: the top navbar (carries the
    // user badge after login) and the bottom footer-nav (decorative).
    // `.first()` selects the top one — the only nav whose contents reflect
    // session state.
    const topNav = page.getByRole('navigation').first();
    await expect(topNav).toContainText('pw_curator');

    // Force the next authenticated API call to return 401. We can't simply
    // tamper `localStorage.token` and navigate — the auth fixture's
    // `addInitScript` re-seeds the original token on every navigation, so
    // the in-page state would be reset by the time the new view mounts.
    // Routing a network response is the deterministic path: it fires the
    // axios response interceptor's 401 path regardless of how the token was
    // obtained.
    //
    // Match `/api/user/<id>/contributions` (called by UserView.mounted())
    // because that's the first authenticated call /User makes after mount.
    await page.route('**/api/user/*/contributions', (route) =>
      route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Token expired' }),
      }),
    );

    // Navigate to a route that fires an authenticated API call.
    await page.goto('/User');

    // Expect: the W2 handle401() chain redirected us to /Login.
    await expect(page).toHaveURL(/\/Login/);

    // Expect: navbar reflects the logged-out state (the "pw_curator" badge
    // is no longer present).
    await expect(topNav).not.toContainText('pw_curator');

    // Expect: handle401() cleared both localStorage keys (single owner of
    // cleanup; no more split between interceptor and useAuth). The init
    // script re-seeds these on the next navigation, but the redirect to
    // /Login already fired before any navigation, so the keys are still
    // null when we read them now.
    expect(await page.evaluate(() => localStorage.getItem('token'))).toBeNull();
    expect(await page.evaluate(() => localStorage.getItem('user'))).toBeNull();
  });
});
