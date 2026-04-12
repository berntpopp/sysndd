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
import axios from 'axios';

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
    delete axios.defaults.headers.common.Authorization;
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

    it('sets the axios default Authorization header so subsequent calls send the Bearer token', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      expect(axios.defaults.headers.common.Authorization).toBe(`Bearer ${FRESH_TOKEN}`);
    });

    it('exposes hasRole() for role-gated UI (matches the A1 scalar-array payload)', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser({ user_role: ['Curator'] }));

      expect(auth.hasRole('Curator')).toBe(true);
      expect(auth.hasRole('Administrator')).toBe(false);
      expect(auth.hasRole('Viewer')).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Case 2: Logout clears both
  // -------------------------------------------------------------------------

  describe('logout', () => {
    it('clears token, user, axios header, and reactive state', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      auth.logout();

      expect(localStorage.getItem('token')).toBeNull();
      expect(localStorage.getItem('user')).toBeNull();
      expect(auth.token.value).toBeNull();
      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
      expect(axios.defaults.headers.common.Authorization).toBeUndefined();
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
      expect(axios.defaults.headers.common.Authorization).toBe(`Bearer ${REFRESHED_TOKEN}`);
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

    it('refresh() bubbles errors; callers decide whether to logout/redirect', async () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(
        http.get('/api/auth/refresh', () => HttpResponse.json({ error: 'nope' }, { status: 401 }))
      );

      await expect(auth.refresh()).rejects.toThrow();
      // Token is unchanged; the axios 401 interceptor handles state cleanup.
      expect(auth.token.value).toBe(FRESH_TOKEN);
    });

    it('refresh() rejects on a malformed 200 body ([null]) and does NOT mutate token/localStorage/header', async () => {
      // A 200 with [null] (or similar shapes where the Plumber scalar-array
      // unwraps to undefined/null) must not poison the session with the
      // literal string "undefined"/"null". useAuth.refresh() guards against
      // this before persisting.
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());

      server.use(
        http.get('/api/auth/refresh', () => HttpResponse.json([null]))
      );

      await expect(auth.refresh()).rejects.toThrow('Refresh returned invalid token');

      // Nothing must have been mutated.
      expect(auth.token.value).toBe(FRESH_TOKEN);
      expect(localStorage.getItem('token')).toBe(FRESH_TOKEN);
      expect(axios.defaults.headers.common.Authorization).toBe(`Bearer ${FRESH_TOKEN}`);
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

    it('treats missing localStorage.user (token-only) as logged-out', () => {
      localStorage.setItem('token', FRESH_TOKEN);
      // no user key

      const auth = useAuth();
      auth.syncFromStorage();

      expect(auth.user.value).toBeNull();
      expect(auth.isAuthenticated.value).toBe(false);
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

    it('handle401() clears the axios default header so queued requests stop sending the stale Bearer', () => {
      const auth = useAuth();
      auth.login(FRESH_TOKEN, makeFreshUser());
      expect(axios.defaults.headers.common.Authorization).toBe(`Bearer ${FRESH_TOKEN}`);

      // interceptor path: it already deletes the default header but we test
      // that handle401() tolerates either order (idempotent cleanup).
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      auth.handle401();

      expect(axios.defaults.headers.common.Authorization).toBeUndefined();
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
