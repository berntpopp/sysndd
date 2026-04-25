// router/__tests__/routes.spec.ts
/**
 * Unit spec for the `createAuthGuard` factory in `@/router/routes.ts`.
 *
 * v11.1 finish-hardening fix #1: Vue Router 4 deprecated calling `next(value)`
 * from navigation guards in favour of returning the value directly. This spec
 * pins the new return-based contract:
 *
 *   - Unauthenticated navigation → guard resolves to `{ name: 'Login' }`.
 *   - Authenticated + role-matched navigation → guard resolves to `true`.
 *
 * The factory delegates every auth decision to `useAuth()`, so we mock the
 * composable to drive the two branches without touching `localStorage` or the
 * module-level singleton refs.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { RouteLocationNormalized } from 'vue-router';

// Hoisted mock: `useAuth()` returns the shape `createAuthGuard` reads. We swap
// the return value per test by assigning into `mockAuthState` (declared at
// module scope so the factory body — which is hoisted by `vi.mock` — can close
// over it via the lazy getter).
const mockAuthState: {
  isAuthenticated: { value: boolean };
  isExpired: { value: boolean };
  roles: string[];
} = {
  isAuthenticated: { value: false },
  isExpired: { value: false },
  roles: [],
};

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: mockAuthState.isAuthenticated,
    isExpired: mockAuthState.isExpired,
    hasRole: (role: string) => mockAuthState.roles.includes(role),
  }),
}));

// Import AFTER the mock so the route table picks up the stubbed composable.
// The `routes` array exercises every `createAuthGuard(...)` call site at
// import time; we recover the factory by re-importing the module after the
// mock is registered.
//
// The factory itself is not exported (it's a local helper), so we exercise it
// via one of the routes that uses it. Find by route `name` to keep the test
// independent of the exact list ordering.
import { routes } from '@/router/routes';

const fakeRoute = (path: string): RouteLocationNormalized =>
  ({
    path,
    name: undefined,
    params: {},
    query: {},
    hash: '',
    matched: [],
    fullPath: path,
    redirectedFrom: undefined,
    meta: {},
  }) as unknown as RouteLocationNormalized;

describe('createAuthGuard (via /User route beforeEnter) — Vue Router 4 return-based API', () => {
  beforeEach(() => {
    mockAuthState.isAuthenticated.value = false;
    mockAuthState.isExpired.value = false;
    mockAuthState.roles = [];
  });

  // The /User route guards on ['Administrator', 'Curator', 'Reviewer'] —
  // the same allowed-roles tuple the original Phase E.E7 refactor pinned. We
  // pull the guard off that route and drive it directly.
  const userRoute = routes.find((r) => r.name === 'User');
  if (!userRoute || typeof userRoute.beforeEnter !== 'function') {
    throw new Error('Test setup: /User route or its beforeEnter guard not found');
  }
  const guard = userRoute.beforeEnter as (
    to: RouteLocationNormalized,
    from: RouteLocationNormalized
  ) => unknown;

  it('returns { name: "Login" } when unauthenticated', () => {
    const result = guard(fakeRoute('/User'), fakeRoute('/'));
    expect(result).toEqual({ name: 'Login' });
  });

  it('returns { name: "Login" } when authenticated but token is expired', () => {
    mockAuthState.isAuthenticated.value = true;
    mockAuthState.isExpired.value = true;
    mockAuthState.roles = ['Administrator'];
    const result = guard(fakeRoute('/User'), fakeRoute('/'));
    expect(result).toEqual({ name: 'Login' });
  });

  it('returns { name: "Login" } when authenticated but role is not in the allow-list', () => {
    mockAuthState.isAuthenticated.value = true;
    mockAuthState.roles = ['Viewer']; // not Administrator/Curator/Reviewer
    const result = guard(fakeRoute('/User'), fakeRoute('/'));
    expect(result).toEqual({ name: 'Login' });
  });

  it('returns true when authenticated, fresh, and role is allowed', () => {
    mockAuthState.isAuthenticated.value = true;
    mockAuthState.isExpired.value = false;
    mockAuthState.roles = ['Curator'];
    const result = guard(fakeRoute('/User'), fakeRoute('/'));
    expect(result).toBe(true);
  });

  it('does NOT call any next() callback (legacy Vue Router 3 contract)', () => {
    // The new return-based API takes only (to, from). If a future refactor
    // adds a third callback parameter back, this assertion will catch the
    // regression: invoke the guard with TWO args and verify the result is
    // synchronously available. With the legacy callback API, a guard called
    // without `next` would never resolve.
    mockAuthState.isAuthenticated.value = true;
    mockAuthState.roles = ['Administrator'];
    const result = guard(fakeRoute('/User'), fakeRoute('/'));
    expect(result).toBe(true);
    // Length of a function reflects its declared arity. Vue Router 4 guards
    // taking the return-based API have arity 2; legacy guards taking `next`
    // would have arity 3.
    expect(guard.length).toBe(2);
  });
});
