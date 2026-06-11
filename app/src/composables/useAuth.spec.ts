// useAuth.spec.ts
/**
 * Tests for useAuth composable (Phase E.E7).
 *
 * Pattern: module-level reactive auth state + MSW for /api/auth/refresh
 * --------------------------------------------------------------------
 * `useAuth()` is the single owner of read/write/refresh/401-handling for the
 * JWT + user payload stored in `localStorage`. It exposes reactive state
 * (token, user, isAuthenticated, isExpired, hasRole) and actions (login,
 * logout, refresh, handle401) so the five locked call sites (§3 Phase E.E7)
 * no longer touch `localStorage.token` / `localStorage.user` directly.
 *
 * Because auth state is global (a single session per browser tab), the
 * composable uses module-level refs — every call to `useAuth()` returns
 * references to the same underlying state. `syncFromStorage()` re-reads
 * `localStorage` (source of truth coordinated with the axios 401 interceptor
 * at `@/plugins/axios`) and is called on every `useAuth()` invocation plus
 * by `handle401()`. This keeps in-memory state consistent with what the
 * interceptor last wrote.
 *
 * Coverage contract (plan §3 Phase E.E7 Required test coverage):
 *   1. Login stores token + user.
 *   2. Logout clears both.
 *   3. Expired token triggers refresh or redirects (we test both branches:
 *      `refresh()` returns a new token; `isExpired` + `handle401()` clear
 *      state so the 401 interceptor redirect path is reachable).
 *   4. Corrupted `localStorage.user` payload does not crash navigation.
 *   5. 401 interceptor coordinates with useAuth state (state follows the
 *      interceptor-cleared `localStorage` after `handle401()`).
 *
 * MSW-mocked endpoints: GET /api/auth/refresh (Phase B.B1 handler,
 * `authenticateTokenOk`/`refreshTokenOk` in test-utils/mocks/data/auth.ts).
 * We do NOT add new handlers; per-test overrides via `server.use(...)` cover
 * the 401 branch.
 */

import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';

import { apiClient } from '@/api/client';
import { server } from '@/test-utils/mocks/server';
import { refreshTokenOk } from '@/test-utils/mocks/data/auth';
import useAuth, { type UserPayload } from './useAuth';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

/**
 * A user payload shaped the way `/api/auth/signin` returns it (R/Plumber
 * wraps scalars in single-element arrays — see
 * `api/config/openapi/schemas/inferred/api_auth_signin_GET.json`).
 * `exp` is a Unix timestamp in seconds; we make it comfortably in the future
 * so `isExpired` is false in the happy-path tests.
 */
function makeFreshUser(overrides: Partial<UserPayload> = {}): UserPayload {
  const nowSec = Math.floor(Date.now() / 1000);
  return {
    user_id: [42],
    user_name: ['test_user'],
    email: ['test_user@example.org'],
    user_role: ['Administrator'],
    user_created: ['2025-01-01 00:00:00'],
    abbreviation: ['TU'],
    orcid: {},
    exp: [nowSec + 3600],
    ...overrides,
  };
}

/**
 * A user payload whose `exp` is in the past; used to cover the refresh /
 * handle401 branches.
 */
function makeExpiredUser(): UserPayload {
  const nowSec = Math.floor(Date.now() / 1000);
  return makeFreshUser({ exp: [nowSec - 60] });
}

// The Phase A1 auth flow stores the raw JWT scalar (Plumber wraps it as a
// one-element array on the wire; LoginView.vue assigns `response.data[0]`
// straight into localStorage, which is what we mirror here).
const FRESH_TOKEN = 'fresh.jwt.token';
const REFRESHED_TOKEN = refreshTokenOk[0];

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('useAuth', () => {
  beforeEach(() => {
    // `vitest.setup.ts` clears localStorage before every test; explicitly
    // re-sync the composable so module-level refs start null.
    useAuth().syncFromStorage();
  });

  afterEach(() => {
    // Reset module-level state so a stray assertion doesn't leak into
    // subsequent tests. handle401() clears without redirecting because
    // `@/router` isn't mounted in this spec.
    const auth = useAuth();
    auth.logout();
  });

  // -------------------------------------------------------------------------
  // Case 1: Login stores token + user
  // -------------------------------------------------------------------------

  describe('login', () => {
    it('stores token + user in localStorage and in reactive state', () => {
      const auth = useAuth();
      const user = makeFreshUser();

      auth.login(FRESH_TOKEN, user);

      expect(localStorage.getItem('token')).toBe(FRESH_TOKEN);
      expect(localStorage.getItem('user')).toBe(JSON.stringify(user));
      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(auth.user.value).toEqual(user);
      expect(auth.isAuthenticated.value).toBe(true);
    });

    it('accepts the R/Plumber scalar-array token shape (response.data[0])', () => {
      // LoginView.vue assigns `response_authenticate.data[0]`; callers already
      // unwrap the array. login() MUST accept a plain string — it is not the
      // unwrap point.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());
      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(typeof auth.token.value).toBe('string');
    });

    it('apiClient carries Authorization: Bearer <token> after login()', async () => {
      // v11.0 closeout F1: the apiClient request interceptor reads
      // useAuth().token.value and injects the Bearer header. This assertion
      // is strictly stronger than the previous `axios.defaults.headers.common`
      // state check: it observes outbound behaviour (what the server actually
      // sees), not an internal axios field.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      let capturedAuth: string | null = null;
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );

      await apiClient.get('/api/ping');
      expect(capturedAuth).toBe(`Bearer ${FRESH_TOKEN}`);
    });

    it('apiClient carries no Authorization after logout()', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());
      auth.logout();

      let capturedAuth: string | null = 'UNSET';
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );

      await apiClient.get('/api/ping');
      expect(capturedAuth).toBeNull();
    });

    it('apiClient preserves a per-request Authorization override', async () => {
      // The closeout spec §3.4 enumerates two exceptions whose flows MUST
      // construct their own Bearer header (LoginView bootstrap handshake and
      // PasswordResetView route-param JWT). The interceptor must yield to an
      // explicit per-call header, never overwrite it with the session token.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      let capturedAuth: string | null = null;
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );

      const OVERRIDE_TOKEN = 'route-param-jwt';
      await apiClient.get('/api/ping', {
        headers: { Authorization: `Bearer ${OVERRIDE_TOKEN}` },
      });
      expect(capturedAuth).toBe(`Bearer ${OVERRIDE_TOKEN}`);
      // The session token must NOT leak into the header.
      expect(capturedAuth).not.toBe(`Bearer ${FRESH_TOKEN}`);
    });

    it('exposes hasRole() for role-gated UI (matches the A1 scalar-array payload)', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser({ user_role: ['Curator'] }));

      expect(auth.hasRole('Curator')).toBe(true);
      expect(auth.hasRole('Administrator')).toBe(false);
      expect(auth.hasRole('Viewer')).toBe(false);
    });

    it('exposes hasMinRole() with hierarchy-aware checks (mirrors API role_levels)', () => {
      const auth = useAuth();

      // Curator satisfies Reviewer/Curator but not Administrator.
      auth.login(FRESH_TOKEN, makeFreshUser({ user_role: ['Curator'] }));
      expect(auth.hasMinRole('Reviewer')).toBe(true);
      expect(auth.hasMinRole('Curator')).toBe(true);
      expect(auth.hasMinRole('Administrator')).toBe(false);

      // Administrator outranks Curator — direct-approval gating must pass.
      auth.login(FRESH_TOKEN, makeFreshUser({ user_role: ['Administrator'] }));
      expect(auth.hasMinRole('Curator')).toBe(true);
      expect(auth.hasMinRole('Administrator')).toBe(true);

      // Reviewer is below Curator — direct-approval gating must fail.
      auth.login(FRESH_TOKEN, makeFreshUser({ user_role: ['Reviewer'] }));
      expect(auth.hasMinRole('Curator')).toBe(false);
      expect(auth.hasMinRole('Reviewer')).toBe(true);
    });

    it('hasMinRole() returns false when there is no authenticated user', () => {
      const auth = useAuth();
      auth.logout();
      expect(auth.hasMinRole('Curator')).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Case 2: Logout clears both
  // -------------------------------------------------------------------------

  describe('logout', () => {
    it('clears token, user, and reactive state', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      auth.logout();

      expect(localStorage.getItem('token')).toBeNull();
      expect(localStorage.getItem('user')).toBeNull();
      expect(auth.token.value).toBeNull();
      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('is idempotent when no session is active', () => {
      const auth = useAuth();
      expect(() => auth.logout()).not.toThrow();
      expect(auth.isAuthenticated.value).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Case 3: Expired token triggers refresh or redirects
  // -------------------------------------------------------------------------

  describe('expired tokens', () => {
    it('flags isExpired=true once user.exp has passed', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeExpiredUser());

      expect(auth.isExpired.value).toBe(true);
      // isAuthenticated still true (token + user present); expiry is a
      // separate concern the call site decides how to handle.
      expect(auth.isAuthenticated.value).toBe(true);
    });

    it('flags isExpired=true at exactly exp (RFC 7519: token is invalid at or after exp)', () => {
      // Lock in the `>=` semantics in useAuth.ts. Master's implementation used
      // `>` which leaves a one-second window where a just-expired token still
      // reads as valid. A future well-meaning refactor that "fixes" this back
      // to `>` will flip this test red.
      const auth = useAuth();
      const nowSec = Math.floor(Date.now() / 1000);
      auth.login(FRESH_TOKEN, makeFreshUser({ exp: [nowSec] }));
      expect(auth.isExpired.value).toBe(true);
    });

    it('refresh() calls GET /api/auth/refresh and stores the new token', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      await auth.refresh();

      expect(auth.token.value).toBe(REFRESHED_TOKEN);
      expect(localStorage.getItem('token')).toBe(REFRESHED_TOKEN);

      // v11.0 closeout F1: outbound assertion — apiClient now carries the
      // refreshed Bearer on the next request (stronger than the old
      // `axios.defaults.headers.common` state check).
      let capturedAuth: string | null = null;
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );
      await apiClient.get('/api/ping');
      expect(capturedAuth).toBe(`Bearer ${REFRESHED_TOKEN}`);
    });

    it('refresh() forwards the current Bearer token on the request', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      let capturedAuth: string | null = null;
      server.use(
        http.get('/api/auth/refresh', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json(refreshTokenOk);
        })
      );

      await auth.refresh();
      expect(capturedAuth).toBe(`Bearer ${FRESH_TOKEN}`);
    });

    it('refresh() bubbles errors; the 401 interceptor (W2) clears state via handle401()', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(
        http.get('/api/auth/refresh', () => HttpResponse.json({ error: 'nope' }, { status: 401 }))
      );

      await expect(auth.refresh()).rejects.toThrow();
      // v11.1 W2 contract: when the 401 response interceptor fires it
      // delegates to `useAuth().handle401()`, which is the single owner
      // of logout cleanup (clears localStorage AND reactive refs in one
      // place). Pre-W2 the interceptor only mutated localStorage, leaving
      // refs lagging by a tick — that drift is exactly what W2 closes.
      // The new assertion locks in the post-W2 state: refs are cleared.
      expect(auth.token.value).toBeNull();
      expect(auth.user.value).toBeNull();
      expect(localStorage.getItem('token')).toBeNull();
      expect(localStorage.getItem('user')).toBeNull();
    });

    it('refresh() rejects on a malformed 200 body ([null]) and does NOT mutate token/localStorage/header', async () => {
      // A 200 with [null] must not poison the session. Copilot Fix 3 tightens
      // this from the earlier string-coercion check to an explicit type
      // check: `[null]` fails `typeof raw[0] === 'string'` up front.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(http.get('/api/auth/refresh', () => HttpResponse.json([null])));

      await expect(auth.refresh()).rejects.toThrow('Refresh returned invalid token shape');

      // Nothing must have been mutated. Verify the outbound Bearer on a
      // subsequent apiClient call is still the original FRESH_TOKEN.
      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(localStorage.getItem('token')).toBe(FRESH_TOKEN);
      let capturedAuth: string | null = null;
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );
      await apiClient.get('/api/ping');
      expect(capturedAuth).toBe(`Bearer ${FRESH_TOKEN}`);
    });

    it('refresh() rejects a plain object body (`{}`) — not a string and not an array', async () => {
      // Copilot Fix 3: without a proper type check, `String({})` would yield
      // "[object Object]" and pass the earlier I2 sentinel check (not
      // "undefined" / "null" / empty), poisoning the session until a 401.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(http.get('/api/auth/refresh', () => HttpResponse.json({ foo: 'bar' })));

      await expect(auth.refresh()).rejects.toThrow('Refresh returned invalid token shape');

      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(localStorage.getItem('token')).toBe(FRESH_TOKEN);
    });

    it('refresh() rejects an array whose first element is not a string (`[123]`)', async () => {
      // Copilot Fix 3: even if the body is an array, element[0] must be a
      // string. A numeric 0th element (or any non-string) is rejected.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(http.get('/api/auth/refresh', () => HttpResponse.json([123])));

      await expect(auth.refresh()).rejects.toThrow('Refresh returned invalid token shape');

      expect(auth.token.value).toBe(FRESH_TOKEN);
    });

    it('refresh() rejects an empty array (`[]`)', async () => {
      // Copilot Fix 3: `[]` has no `[0]` to read. Reject before persisting.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(http.get('/api/auth/refresh', () => HttpResponse.json([])));

      await expect(auth.refresh()).rejects.toThrow('Refresh returned invalid token shape');

      expect(auth.token.value).toBe(FRESH_TOKEN);
    });
  });

  // -------------------------------------------------------------------------
  // Case 4: Corrupted localStorage.user payload does not crash navigation
  // -------------------------------------------------------------------------

  describe('corrupted payload resilience', () => {
    it('treats corrupt JSON in localStorage.user as logged-out, not as a crash', () => {
      localStorage.setItem('token', FRESH_TOKEN);
      localStorage.setItem('user', '{this is not json');

      // syncFromStorage must swallow JSON.parse exceptions so route guards
      // that call useAuth() during navigation never throw.
      const auth = useAuth();
      expect(() => auth.syncFromStorage()).not.toThrow();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
      // isExpired is false when there's no user — there's nothing to expire.
      expect(auth.isExpired.value).toBe(false);
      expect(auth.hasRole('Administrator')).toBe(false);
    });

    it('rejects a JSON array in localStorage.user (`[]` is valid JSON but not a user payload)', () => {
      // Copilot Fix 1: `JSON.parse('[]')` yields an array, and `typeof [] ===
      // 'object'`. Without an explicit `Array.isArray` guard, safeParseUser()
      // would have accepted `[]`, leaving userRef truthy with neither `.exp`
      // nor `.user_role` — callers downstream would see isAuthenticated=true
      // while every role/expiry check silently returned undefined.
      localStorage.setItem('token', FRESH_TOKEN);
      localStorage.setItem('user', '[]');

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('rejects an object with a missing/empty `exp` array', () => {
      // Copilot Fix 1: without a usable exp[0], isExpired can never fire, so
      // a just-expired session would linger until the next 401. Reject at
      // parse time instead.
      localStorage.setItem('token', FRESH_TOKEN);
      localStorage.setItem('user', JSON.stringify({ exp: [], user_role: ['Administrator'] }));

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('rejects an object with a missing/empty `user_role` array', () => {
      // Copilot Fix 1: an empty user_role array would fail every router
      // guard's hasRole() check anyway (roles[0] === undefined), so reject
      // early rather than letting isAuthenticated masquerade as true.
      const nowSec = Math.floor(Date.now() / 1000);
      localStorage.setItem('token', FRESH_TOKEN);
      localStorage.setItem('user', JSON.stringify({ exp: [nowSec + 3600], user_role: [] }));

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('treats missing localStorage.user (token-only) as logged-out', () => {
      localStorage.setItem('token', FRESH_TOKEN);
      // no user key

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('enforces both-or-neither: a dangling user (no token) is cleared from localStorage and state', async () => {
      // Copilot Fix 2: the pre-fix syncFromStorage() only cleaned up a
      // dangling token; a dangling user survived. Components that read
      // `auth.user.value` directly (e.g. UserView.vue's mount hook) would
      // then hit the API without a Bearer header. Symmetric cleanup is now
      // enforced so every observer sees the same cleared state.
      const user = makeFreshUser();
      localStorage.setItem('user', JSON.stringify(user));
      // no token key — simulates a crash between the two setItem calls,
      // or a dev-tools manipulation.

      const auth = useAuth();

      expect(auth.user.value).toBeNull();
      expect(auth.token.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
      // Stored user must be cleaned up too, not just the in-memory ref.
      expect(localStorage.getItem('user')).toBeNull();
      // v11.0 closeout F1: outbound assertion — the apiClient request
      // interceptor reads useAuth().token.value; with no token, no
      // Authorization header is sent. Strictly stronger than the old
      // `expect(axios.defaults.headers.common.Authorization).toBeUndefined()`
      // which only inspected axios internal state.
      let capturedAuth: string | null = 'UNSET';
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );
      await apiClient.get('/api/ping');
      expect(capturedAuth).toBeNull();
    });

    it('rehydrates cleanly when both token and user are present', () => {
      const user = makeFreshUser();
      localStorage.setItem('token', FRESH_TOKEN);
      localStorage.setItem('user', JSON.stringify(user));

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(auth.user.value).toEqual(user);
      expect(auth.isAuthenticated.value).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // Case 5: 401 interceptor coordinates with useAuth state
  // -------------------------------------------------------------------------

  describe('401 interceptor coordination', () => {
    it('handle401() re-reads localStorage and mirrors the cleared state', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());
      expect(auth.isAuthenticated.value).toBe(true);

      // Simulate what `@/plugins/axios` does inside the 401 interceptor:
      // it calls localStorage.removeItem('token') / .removeItem('user')
      // directly without going through useAuth. After that, handle401()
      // must bring the in-memory refs back in sync.
      localStorage.removeItem('token');
      localStorage.removeItem('user');

      auth.handle401();

      expect(auth.token.value).toBeNull();
      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
    });

    it('handle401() stops apiClient from sending the stale Bearer on queued requests', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      // Sanity: before handle401() the apiClient interceptor sends Bearer.
      let capturedAuth: string | null = null;
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );
      await apiClient.get('/api/ping');
      expect(capturedAuth).toBe(`Bearer ${FRESH_TOKEN}`);

      // interceptor path: it already deletes the localStorage keys, but we
      // test that handle401() tolerates either order (idempotent cleanup).
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      auth.handle401();

      // v11.0 closeout F1: observable outbound behaviour — the request
      // interceptor reads useAuth().token.value, so after handle401()
      // no Bearer is sent.
      capturedAuth = 'UNSET';
      server.use(
        http.get('*/api/ping', ({ request }) => {
          capturedAuth = request.headers.get('authorization');
          return HttpResponse.json({ ok: true });
        })
      );
      await apiClient.get('/api/ping');
      expect(capturedAuth).toBeNull();
    });

    it('multiple useAuth() calls share the same reactive state (module-level singleton)', () => {
      const a = useAuth();
      const b = useAuth();

      a.login(FRESH_TOKEN, makeFreshUser());
      expect(b.token.value).toBe(FRESH_TOKEN);
      expect(b.isAuthenticated.value).toBe(true);

      b.logout();
      expect(a.token.value).toBeNull();
      expect(a.isAuthenticated.value).toBe(false);
    });
  });
});

// ---------------------------------------------------------------------------
// W2 (v11.1 finish-hardening): handle401 contract
// ---------------------------------------------------------------------------
//
// Pre-W2, the axios 401 interceptor cleared `localStorage` directly and
// `useAuth().handle401()` only RE-READ that already-cleared state. This split
// ownership left a small reactive-drift window (the interceptor cleared
// localStorage; reactive consumers like AppNavbar lagged by one tick) and
// duplicated the cleanup contract across two files.
//
// W2 makes `useAuth.handle401()` the single owner of logout cleanup:
//   - clears `localStorage` itself (no longer assumes the interceptor did it)
//   - clears the reactive refs
//   - dispatches navigation toward `/Login`
//   - is idempotent: calling more than once is safe (no throws, state
//     stays cleared)
//
// These tests intentionally stand on their own (separate top-level describe)
// so the contract is legible without grep'ing the full file. The spec
// asserts on the `globalThis.__authNavTarget` global hook, which
// `handle401()` always assigns regardless of whether a router is mounted;
// in addition the implementation calls `router.push` when one is available.
describe('useAuth.handle401() — single-owner contract (W2)', () => {
  beforeEach(() => {
    localStorage.clear();
    // Seed a logged-in state directly in localStorage. This simulates the
    // pre-W2 split-ownership world: the interceptor used to clear these
    // keys before calling handle401(); now handle401() owns the clear.
    localStorage.setItem('token', 'fake-jwt-for-spec');
    localStorage.setItem(
      'user',
      JSON.stringify({
        user_id: [42],
        user_name: ['spec'],
        email: ['spec@example.org'],
        user_role: ['Curator'],
        user_created: ['2025-01-01 00:00:00'],
        abbreviation: ['SP'],
        orcid: {},
        exp: [Math.floor(Date.now() / 1000) + 3600],
      })
    );
    // Reset the navigation hook so test 3 starts from a clean slate.
    delete (globalThis as Record<string, unknown>).__authNavTarget;
  });

  it('clears token and user from reactive state and from localStorage', () => {
    const auth = useAuth();
    auth.syncFromStorage(); // ensure refs reflect the seeded localStorage
    expect(auth.token.value).toBe('fake-jwt-for-spec');
    expect(auth.user.value?.user_name?.[0]).toBe('spec');

    auth.handle401();

    // Reactive refs cleared
    expect(auth.token.value).toBeNull();
    expect(auth.user.value).toBeNull();
    // localStorage cleared (handle401 is the OWNER of this cleanup)
    expect(localStorage.getItem('token')).toBeNull();
    expect(localStorage.getItem('user')).toBeNull();
  });

  it('is idempotent — calling twice does not throw and leaves state cleared', () => {
    const auth = useAuth();
    auth.handle401();
    expect(() => auth.handle401()).not.toThrow();
    expect(auth.token.value).toBeNull();
    expect(localStorage.getItem('token')).toBeNull();
  });

  it('dispatches a navigation event toward the login route', () => {
    const auth = useAuth();
    // The implementation always assigns `globalThis.__authNavTarget` for
    // test / pre-init contexts (and additionally calls `router.push` when
    // a router is mounted). Asserting on the global hook directly is the
    // observable surface this spec actually owns.
    delete (globalThis as Record<string, unknown>).__authNavTarget;
    auth.handle401();
    expect((globalThis as Record<string, unknown>).__authNavTarget).toBe('/Login');
  });
});
