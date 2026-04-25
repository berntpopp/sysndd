// app/tests/e2e/fixtures/auth.ts
// Programmatic login that bypasses UI. Use this in non-auth tests so the
// auth flows remain the only place that exercises the login form.

import { test as base, type Page, type APIRequestContext } from '@playwright/test';
import { testUsers, type TestRole } from './test-users';

interface AuthFixtures {
  loggedInAs: (role: TestRole) => Promise<Page>;
}

/**
 * Posts credentials to /api/auth/authenticate and returns the JWT.
 *
 * Plumber may serialize scalar responses as either a JSON string ("token")
 * or a 1-element array (["token"]); both shapes are normalised here.
 */
async function fetchToken(request: APIRequestContext, role: TestRole): Promise<string> {
  const { username, password } = testUsers[role];
  const res = await request.post('/api/auth/authenticate', {
    data: { user_name: username, password },
  });
  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`auth fixture: login failed for ${role}: ${res.status()} ${body}`);
  }
  // Try JSON first; fall back to raw text. The endpoint sometimes returns
  // a single quoted string and sometimes a [string] array.
  const raw = (await res.text()).trim();
  let token: string | undefined;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (Array.isArray(parsed) && typeof parsed[0] === 'string') {
      token = parsed[0];
    } else if (typeof parsed === 'string') {
      token = parsed;
    }
  } catch {
    // raw was not valid JSON — strip surrounding quotes if present
    token = raw.replace(/^"|"$/g, '');
  }
  if (!token) {
    throw new Error(`auth fixture: could not parse token from response: ${raw.slice(0, 200)}`);
  }
  return token;
}

export const test = base.extend<AuthFixtures>({
  loggedInAs: async ({ browser, request }, use) => {
    await use(async (role) => {
      const token = await fetchToken(request, role);
      const context = await browser.newContext();
      // Inject the token + a minimal user object into localStorage so the
      // app thinks the user is already logged in. Mirrors what useAuth
      // expects after a UI login.
      await context.addInitScript(
        (args: { token: string; role: TestRole; users: typeof testUsers }) => {
          localStorage.setItem('token', args.token);
          const u = args.users[args.role];
          localStorage.setItem('user', JSON.stringify({ user_name: u.username, role: args.role }));
        },
        { token, role, users: testUsers },
      );
      const page = await context.newPage();
      return page;
    });
  },
});

export { expect } from '@playwright/test';
