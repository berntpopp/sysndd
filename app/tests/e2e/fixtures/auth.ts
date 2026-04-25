// app/tests/e2e/fixtures/auth.ts
// Programmatic login that bypasses UI. Use this in non-auth tests so the
// auth flows remain the only place that exercises the login form.
//
// All tests built on this fixture also pre-acknowledge the SysNDD disclaimer
// modal (DisclaimerDialog.vue) — without this, the modal intercepts pointer
// events on every page load and breaks every interactive selector. The
// disclaimer is bypassed by writing the acknowledgment payload to
// localStorage under the same key the disclaimer pinia store uses.

import { test as base, type Page, type APIRequestContext, type BrowserContext } from '@playwright/test';
import { testUsers, type TestRole } from './test-users';

interface AuthFixtures {
  loggedInAs: (role: TestRole) => Promise<Page>;
}

const DISCLAIMER_STORAGE_KEY = 'sysndd-disclaimer';

/**
 * Returns the localStorage payload that DisclaimerDialog reads on app boot to
 * decide whether to show the modal. Pre-seeding this to "acknowledged" skips
 * the modal entirely.
 */
function disclaimerAcknowledgmentPayload(): { isAcknowledged: true; acknowledgmentTimestamp: string } {
  return { isAcknowledged: true, acknowledgmentTimestamp: new Date().toISOString() };
}

/**
 * Adds an init script that pre-acknowledges the SysNDD disclaimer for every
 * page in the given context. Idempotent — safe to call on a fresh context.
 */
async function preAcknowledgeDisclaimer(context: BrowserContext): Promise<void> {
  await context.addInitScript(
    (args: { key: string; payload: { isAcknowledged: true; acknowledgmentTimestamp: string } }) => {
      localStorage.setItem(args.key, JSON.stringify(args.payload));
    },
    { key: DISCLAIMER_STORAGE_KEY, payload: disclaimerAcknowledgmentPayload() },
  );
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
    token = raw.replace(/^"|"$/g, '');
  }
  if (!token) {
    throw new Error(`auth fixture: could not parse token from response: ${raw.slice(0, 200)}`);
  }
  return token;
}

export const test = base.extend<AuthFixtures>({
  // Override the default `context` fixture so every test (logged-in or not)
  // automatically pre-acknowledges the disclaimer modal.
  context: async ({ context }, use) => {
    await preAcknowledgeDisclaimer(context);
    await use(context);
  },

  loggedInAs: async ({ browser, request }, use) => {
    await use(async (role) => {
      const token = await fetchToken(request, role);
      const context = await browser.newContext();
      await preAcknowledgeDisclaimer(context);
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
