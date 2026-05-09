// useAuth.handle401-redirect.spec.ts
//
// PR #306 Copilot review (v11.1 finish-hardening): when `handle401()`
// dispatches a navigation to /Login, it must preserve the user's current
// `fullPath` in `query.redirect`. The pre-W2 axios interceptor built that
// query from `currentRoute.value.fullPath`; an earlier W4 sub-agent
// dropped it after grepping for consumers and finding none. Copilot
// flagged the drop as a forward-compatibility regression — a future
// LoginView change might want to bounce the user back after re-auth, and
// the query is the only context handle401() has into "where the user
// was". This spec pins the contract back in.
//
// We use a separate spec file (rather than extending `useAuth.spec.ts`)
// because `vi.mock('@/router', …)` is hoisted to the top of the module
// and cannot be applied conditionally; the existing useAuth.spec.ts
// intentionally does NOT mock `@/router` so the handle401() try/catch
// fallback exercises its global-hook branch. Splitting the redirect
// contract into its own file keeps both branches under test without
// either fighting for control of the mock.

import { beforeEach, describe, expect, it, vi } from 'vitest';

// Hoisted before the SUT import so `useAuth.ts`'s `import router from
// '@/router'` resolves to this stub.
vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { path: '/Entities/123', fullPath: '/Entities/123' } },
  },
}));

// Disarm the axios plugin's side effects (it would normally try to wire
// an interceptor against a real axios instance during module load).
vi.mock('@/plugins/axios', () => ({}));

import router from '@/router';
import useAuth from './useAuth';

describe('useAuth.handle401() — preserves redirect query (Copilot)', () => {
  beforeEach(() => {
    localStorage.clear();
    // Seed a logged-in state so handle401() actually fires its
    // navigation branch (the function early-returns when nothing was
    // logged in, to avoid spamming router.push on coalesced 401s).
    localStorage.setItem('token', 'fake-jwt-for-redirect-spec');
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
    // Reset between tests so each assertion sees a clean call list.
    (router.push as ReturnType<typeof vi.fn>).mockClear();
    // Default: simulate the user is on a real page when 401 lands.
    (router.currentRoute as { value: { path: string; fullPath: string } }).value = {
      path: '/Entities/123',
      fullPath: '/Entities/123',
    };
  });

  it('passes the current fullPath as query.redirect alongside reason=session-expired', () => {
    const auth = useAuth();
    auth.syncFromStorage();

    auth.handle401();

    expect(router.push).toHaveBeenCalledTimes(1);
    const arg = (router.push as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(arg).toMatchObject({
      path: '/Login',
      query: {
        reason: 'session-expired',
        redirect: '/Entities/123',
      },
    });
  });

  it('omits redirect when no current route exists (cold-boot 401)', () => {
    // Simulate a 401 firing before the first navigation: currentRoute
    // is present but its `fullPath` is undefined. handle401() must not
    // emit `redirect=undefined` in that case.
    (
      router.currentRoute as {
        value: { path: string | undefined; fullPath: string | undefined };
      }
    ).value = { path: undefined, fullPath: undefined };

    const auth = useAuth();
    auth.syncFromStorage();

    auth.handle401();

    expect(router.push).toHaveBeenCalledTimes(1);
    const arg = (router.push as ReturnType<typeof vi.fn>).mock.calls[0][0];
    expect(arg).toEqual({
      path: '/Login',
      query: { reason: 'session-expired' },
    });
  });

  it('does not navigate when already on /Login (avoids redirect loop)', () => {
    (router.currentRoute as { value: { path: string; fullPath: string } }).value = {
      path: '/Login',
      fullPath: '/Login?reason=session-expired',
    };

    const auth = useAuth();
    auth.syncFromStorage();

    auth.handle401();

    expect(router.push).not.toHaveBeenCalled();
  });
});
