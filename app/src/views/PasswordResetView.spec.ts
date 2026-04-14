// PasswordResetView.spec.ts
/**
 * v11.0 closeout F2e — Exception E2 characterisation.
 *
 * The closeout spec §3.4 enumerates two flows that LEGITIMATELY construct
 * their own `Authorization: Bearer` header instead of going through the
 * apiClient interceptor. This file pins down the **PasswordResetView
 * route-param JWT (E2)** in executable form.
 *
 * Why E2 is a sanctioned exception
 * --------------------------------
 * The password-reset flow is initiated by an email link of the form:
 *
 *     https://sysndd.example.org/PasswordReset/<reset-jwt>
 *
 * The `<reset-jwt>` lands in `$route.params.request_jwt`. It is a one-shot
 * credential (not a session token) issued by the backend to authorise ONE
 * password change and nothing else. Storing it in `localStorage.token`
 * would be an error — it would masquerade as a session and fail every
 * role/expiry check downstream, and it would survive after the password
 * change, creating a ghost-session attack surface.
 *
 * So PasswordResetView.vue attaches `Authorization: Bearer
 * ${this.$route.params.request_jwt}` to the single POST
 * /api/user/password/reset/change call via an explicit per-request header.
 * The apiClient interceptor (post-Copilot-review) yields to any explicit
 * per-call `Authorization`, so this works at runtime without ever
 * creating a session.
 *
 * Why this spec exists
 * --------------------
 * The E2 contract has three critical invariants:
 *
 *   1. The Bearer on the password-change POST is `$route.params.request_jwt`
 *      — a route-param read, never a storage read. A refactor that "caches"
 *      the JWT in localStorage.token would silently break this.
 *
 *   2. `localStorage.token` and `localStorage.user` are null throughout the
 *      flow. Password reset must NOT create a session. Any future code path
 *      that calls `useAuth().login(...)` from this view would fail this
 *      assertion.
 *
 *   3. `useAuth()` itself is NEVER invoked. The composable is the session
 *      layer; a one-shot credential flow has no business touching it. Spying
 *      on `login` and asserting `not.toHaveBeenCalled()` makes this
 *      machine-checkable.
 *
 * See `docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md` §3.4
 * for the full exception policy; `.plans/v11.0/closeout.md` §3 F2e for the
 * task-level brief.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import useAuth from '@/composables/useAuth';

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

// Axios plugin imports `@/router`; replace with a stub so the 401
// interceptor's `router.push(...)` doesn't blow up if the backend returns
// 401 on an expired reset JWT.
vi.mock('@/router', () => {
  const push = vi.fn();
  (globalThis as unknown as { __resetRouterPushMock: ReturnType<typeof vi.fn> }).__resetRouterPushMock =
    push;
  return {
    default: {
      push,
      currentRoute: { value: { fullPath: '/PasswordReset' } },
    },
  };
});

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

// Import AFTER the `@/router` mock so the axios plugin picks it up.
import axios from '@/plugins/axios';
import PasswordResetView from '@/views/PasswordResetView.vue';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const ROUTE_JWT = 'ROUTE_JWT';

const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

// ---------------------------------------------------------------------------
// Mount helper
// ---------------------------------------------------------------------------

/**
 * Mount PasswordResetView with a mocked `$route` carrying a reset JWT.
 * We stub `$router` too so the post-change redirect doesn't navigate to
 * a route that isn't registered in the test environment.
 */
const mountResetView = (routeJwt: string = ROUTE_JWT): VueWrapper => {
  return mount(PasswordResetView, {
    global: {
      mocks: {
        axios,
        $route: {
          params: { request_jwt: routeJwt },
        },
        $router: { push: vi.fn() },
      },
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: {
          template: '<div><slot name="header" /><slot /></div>',
        },
        BCardText: { template: '<div><slot /></div>' },
        BForm: { template: '<form><slot /></form>' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormInput: {
          props: ['modelValue', 'placeholder', 'type', 'state'],
          template: '<input />',
        },
        BFormInvalidFeedback: { template: '<div><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BSpinner: { template: '<div role="status" />' },
      },
    },
  });
};

/**
 * Narrow view-model shape so TypeScript lets us poke the Options API methods
 * directly via `wrapper.vm`. PasswordResetView uses data-bound `v-model`
 * fields; setting them through `wrapper.vm.newPasswordEntry = '...'` drives
 * the reactive state without synthesising keyboard events on stubbed inputs.
 */
interface PasswordResetViewVm {
  newPasswordEntry: string;
  newPasswordRepeat: string;
  emailEntry: string;
  doPasswordChange: () => Promise<void>;
  requestPasswordReset: () => Promise<void>;
}

const vm = (wrapper: VueWrapper): PasswordResetViewVm =>
  wrapper.vm as unknown as PasswordResetViewVm;

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

describe('PasswordResetView — closeout exception E2 (route-param Bearer)', () => {
  beforeEach(() => {
    envBag.VITE_API_URL = '';
    // Ensure no prior session leaks in — the E2 contract is that
    // localStorage is null throughout; a stale login would falsify that.
    useAuth().logout();
    localStorage.clear();
  });

  afterEach(() => {
    if (originalViteApiUrl === undefined) {
      delete envBag.VITE_API_URL;
    } else {
      envBag.VITE_API_URL = originalViteApiUrl;
    }
    useAuth().logout();
    localStorage.clear();
  });

  // -------------------------------------------------------------------------
  // Case 1: outbound POST carries Bearer of `$route.params.request_jwt`.
  // -------------------------------------------------------------------------

  it('E2 route-param: outbound POST carries Bearer of $route.params.request_jwt', async () => {
    let capturedAuth: string | null = null;
    server.use(
      http.post('/api/user/password/reset/change', ({ request }) => {
        capturedAuth = request.headers.get('authorization');
        return HttpResponse.json({ status: 'ok' });
      }),
    );

    const wrapper = mountResetView();
    const view = vm(wrapper);
    view.newPasswordEntry = 'newpassword123';
    view.newPasswordRepeat = 'newpassword123';

    // Drive the reset directly; form submit would pull in vee-validate
    // timing that is not part of the E2 contract.
    await view.doPasswordChange();
    await flushPromises();

    // E2 contract: the Bearer comes from the route param, full-stop.
    expect(capturedAuth).toBe(`Bearer ${ROUTE_JWT}`);
    // Doubly nail the "not session" part: the session token, if one
    // existed, would be a completely different string; this rules out any
    // future code path that ever sneaks a session Bearer onto this call.
    expect(capturedAuth).not.toBe('Bearer undefined');
    expect(capturedAuth).not.toBe('Bearer null');
  });

  // -------------------------------------------------------------------------
  // Case 2: localStorage.token is null throughout the flow.
  // -------------------------------------------------------------------------

  it('E2 route-param: localStorage.getItem("token") is null throughout the reset flow', async () => {
    // Before: clean storage (beforeEach guaranteed it).
    expect(localStorage.getItem('token')).toBeNull();
    expect(localStorage.getItem('user')).toBeNull();

    let storageDuringRequest: { token: string | null; user: string | null } | null = null;
    server.use(
      http.post('/api/user/password/reset/change', () => {
        // During: neither key may materialise mid-flow. If a future code
        // path ever called `localStorage.setItem('token', routeJwt)` to
        // "make apiClient work", this resolver would catch it.
        storageDuringRequest = {
          token: localStorage.getItem('token'),
          user: localStorage.getItem('user'),
        };
        return HttpResponse.json({ status: 'ok' });
      }),
    );

    const wrapper = mountResetView();
    const view = vm(wrapper);
    view.newPasswordEntry = 'newpassword123';
    view.newPasswordRepeat = 'newpassword123';

    await view.doPasswordChange();
    await flushPromises();

    expect(storageDuringRequest).toEqual({ token: null, user: null });

    // After: still nothing persisted. A successful password reset does
    // NOT log the user in; they must go to /Login and authenticate
    // normally with the new password.
    expect(localStorage.getItem('token')).toBeNull();
    expect(localStorage.getItem('user')).toBeNull();
  });

  // -------------------------------------------------------------------------
  // Case 3: useAuth() is never invoked from this view.
  // -------------------------------------------------------------------------

  it('E2 route-param: useAuth().login is never called during the reset flow', async () => {
    // Spy on the module-level singleton BEFORE mounting the view. If the
    // view ever reached into `useAuth().login(...)` (the only supported
    // way to create a session), the spy would fire. The E2 contract says
    // this flow must NOT create a session — it's a one-shot credential.
    const authInstance = useAuth();
    const loginSpy = vi.spyOn(authInstance, 'login');

    server.use(
      http.post('/api/user/password/reset/change', () =>
        HttpResponse.json({ status: 'ok' }),
      ),
    );

    const wrapper = mountResetView();
    const view = vm(wrapper);
    view.newPasswordEntry = 'newpassword123';
    view.newPasswordRepeat = 'newpassword123';

    await view.doPasswordChange();
    await flushPromises();

    // E2 contract: no session creation, ever.
    expect(loginSpy).not.toHaveBeenCalled();

    loginSpy.mockRestore();
  });
});
