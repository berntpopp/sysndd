// LoginView.spec.ts
/**
 * v11.0 closeout F2e — Exception E1 characterisation.
 *
 * The closeout spec §3.4 enumerates two flows that LEGITIMATELY construct
 * their own `Authorization: Bearer` header instead of going through the
 * apiClient interceptor. This file pins down the **LoginView bootstrap
 * handshake (E1)** in executable form.
 *
 * Why E1 is a sanctioned exception
 * --------------------------------
 * Logging in is a two-step dance:
 *   1. POST /api/auth/authenticate returns the new JWT (Plumber scalar-array).
 *   2. GET  /api/auth/signin exchanges that JWT for the full user payload.
 *
 * `useAuth().login(token, user)` is an atomic operation — it must receive
 * BOTH the token AND the user at the same call so the module-level refs,
 * `localStorage.token`, and `localStorage.user` flip from "logged out" to
 * "logged in" in one transition. If LoginView called `login(token, null)`
 * first, then `login(token, user)` after step 2, any component reading the
 * refs in the gap would observe a half-logged-in session (token present,
 * user missing) — exactly the drift the F1 interceptor contract is designed
 * to prevent.
 *
 * So LoginView.vue attaches `Authorization: Bearer ${token}` to the single
 * /signin call via an explicit per-request header. The apiClient
 * interceptor (post-Copilot-review) yields to any explicit per-call
 * `Authorization`, so this works at runtime without ever touching the
 * session state.
 *
 * Why this spec exists
 * --------------------
 * The E1 contract is subtle. A well-meaning future refactor that "cleans
 * up" the bootstrap — for example by storing the token with
 * `localStorage.setItem('token', ...)` before calling /signin, or by
 * calling `useAuth().login(token, ...)` twice — would silently break it.
 * The three cases below turn that contract into a failing red test:
 *
 *   1. The Bearer on /signin is the LOCAL variable, not a storage read.
 *      Proven by a server-side handler that asserts
 *      `localStorage.getItem('token') === null` at the moment the signin
 *      request lands — if the bootstrap ever persisted the token to
 *      storage before calling /signin, this resolver would throw.
 *
 *   2. `useAuth().login()` is called exactly once, and it receives both
 *      the token AND the user payload atomically. Any implementation that
 *      splits login into "set token" + "set user" fails this.
 *
 *   3. No localStorage writes happen before the atomic login() call.
 *      Snapshots `localStorage.length` before, during, and after the
 *      signin handshake; only `login()` may mutate storage.
 *
 * See `docs/superpowers/specs/2026-04-14-v11.0-closeout-design.md` §3.4
 * for the full exception policy; `.plans/v11.0/closeout.md` §3 F2e for the
 * task-level brief.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount, type VueWrapper } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { signinOk, type AuthSigninResponse } from '@/test-utils/mocks/data/auth';
import useAuth from '@/composables/useAuth';

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

// `src/plugins/axios.ts` does `import router from '@/router'` at module load;
// mounting `@/router` would drag in the full route table, auth guards, and a
// real history stack. Replace it with a minimal stub so the axios 401
// interceptor can call `router.push(...)` without blowing up.
vi.mock('@/router', () => {
  const push = vi.fn();
  (globalThis as unknown as { __loginRouterPushMock: ReturnType<typeof vi.fn> }).__loginRouterPushMock =
    push;
  return {
    default: {
      push,
      currentRoute: { value: { fullPath: '/Login' } },
    },
  };
});

// `@unhead/vue`'s `useHead()` requires a `createHead()` plugin to be
// registered on the app. Replace it with a no-op so the LoginView `setup()`
// hook doesn't throw when mounted standalone.
vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

// The view imports `useToast` and calls `makeToast` on error paths. The real
// `useToast` pulls in bootstrap-vue-next's BApp provider; swap it for a
// minimal stub so mount doesn't require the provider.
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

// Import AFTER the `@/router` mock is registered so the axios plugin
// (transitively imported via `useAuth` / `LoginView`) picks up the stub.
import axios from '@/plugins/axios';
import LoginView from '@/views/LoginView.vue';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const BOOTSTRAP_TOKEN = 'BOOTSTRAP_TOKEN';

/**
 * Plumber wraps the authenticate-endpoint token in a one-element array.
 * LoginView unwraps this at `response_authenticate.data[0]`.
 */
const bootstrapTokenEnvelope: [string] = [BOOTSTRAP_TOKEN];

/**
 * `/api/auth/signin` returns the scalar-array user payload shape that
 * `useAuth().login()` expects as its second argument.
 */
const bootstrapUser: AuthSigninResponse = {
  ...signinOk,
  user_role: ['Administrator'],
};

// The view reads `import.meta.env.VITE_API_URL` at call time and concatenates
// `${VITE_API_URL}/api/auth/authenticate`. Vitest leaves this unset by
// default, which collapses to `undefined/api/auth/authenticate` — a URL MSW
// cannot match against the `/api/auth/*` handler patterns. Normalise to an
// empty string so the path-only handlers match.
const envBag = import.meta.env as unknown as Record<string, string>;
const originalViteApiUrl = envBag.VITE_API_URL;

// ---------------------------------------------------------------------------
// Mount helper
// ---------------------------------------------------------------------------

/**
 * Mount LoginView with enough stubs to exercise the bootstrap methods. We
 * drive the flow by calling `wrapper.vm.loadJWT()` / `signinWithJWT(...)`
 * directly, skipping the vee-validate form-submit wrapper — that keeps the
 * test focused on the E1 contract (auth handshake shape) rather than on
 * form validation plumbing.
 */
const mountLoginView = (): VueWrapper => {
  return mount(LoginView, {
    global: {
      mocks: {
        // `main.ts` wires the configured axios instance onto
        // `app.config.globalProperties.axios`. Provide the same instance —
        // with its real 401 interceptor — so outbound calls flow through
        // the interceptor we import above.
        axios,
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
        BFormGroup: { template: '<div><slot /></div>' },
        BFormInput: {
          props: ['modelValue', 'placeholder', 'type', 'state'],
          template: '<input />',
        },
        BFormInvalidFeedback: { template: '<div><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BLink: { template: '<a><slot /></a>' },
        BSpinner: { template: '<div role="status" />' },
      },
    },
  });
};

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

/**
 * Narrow view-model shape so we can call methods directly via `wrapper.vm`.
 * LoginView uses Options API; vue-tsc can't infer the method types through
 * `wrapper.vm`.
 */
interface LoginViewVm {
  user_name: string;
  password: string;
  loadJWT: () => Promise<void>;
  signinWithJWT: (token: string) => Promise<void>;
}

const vm = (wrapper: VueWrapper): LoginViewVm =>
  wrapper.vm as unknown as LoginViewVm;

describe('LoginView — closeout exception E1 (bootstrap Bearer)', () => {
  beforeEach(() => {
    envBag.VITE_API_URL = '';
    // Ensure no session state leaks in from a previous test. `useAuth()` is
    // a module-level singleton — a stale login would let the apiClient
    // interceptor inject a Bearer we'd mistake for the bootstrap one.
    useAuth().logout();
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
  // Case 1: /signin carries Bearer of the LOCAL variable, not a storage read.
  // -------------------------------------------------------------------------

  it('E1 bootstrap: GET /api/auth/signin carries Bearer of the local token (not localStorage)', async () => {
    // Pre-condition: no session, no storage-backed token.
    expect(localStorage.getItem('token')).toBeNull();

    let signinAuth: string | null = null;
    server.use(
      http.post('/api/auth/authenticate', () =>
        HttpResponse.json(bootstrapTokenEnvelope),
      ),
      http.get('/api/auth/signin', ({ request }) => {
        // Capture the Authorization header off the wire.
        signinAuth = request.headers.get('authorization');
        // E1 contract: the Bearer value MUST come from the local `token`
        // variable in `signinWithJWT(token)`, NOT from `localStorage`.
        // Proving it directly: localStorage.token is still null at the
        // moment the signin request lands, so the header cannot possibly
        // have been read from storage.
        expect(localStorage.getItem('token')).toBeNull();
        expect(localStorage.getItem('user')).toBeNull();
        return HttpResponse.json(bootstrapUser);
      }),
    );

    const wrapper = mountLoginView();
    const view = vm(wrapper);
    view.user_name = 'testuser';
    view.password = 'testpass';

    // Drive the bootstrap directly — form submit would add vee-validate
    // timing noise that is not part of the E1 contract.
    await view.loadJWT();
    await flushPromises();

    // The /signin call saw the exact local-variable Bearer we expect.
    expect(signinAuth).toBe(`Bearer ${BOOTSTRAP_TOKEN}`);
  });

  // -------------------------------------------------------------------------
  // Case 2: useAuth().login() called exactly once, with both token and user.
  // -------------------------------------------------------------------------

  it('E1 bootstrap: useAuth().login() called exactly once, with both token and user', async () => {
    server.use(
      http.post('/api/auth/authenticate', () =>
        HttpResponse.json(bootstrapTokenEnvelope),
      ),
      http.get('/api/auth/signin', () => HttpResponse.json(bootstrapUser)),
    );

    const wrapper = mountLoginView();
    const view = vm(wrapper);
    view.user_name = 'testuser';
    view.password = 'testpass';

    // `useAuth()` returns a fresh wrapper object on each call (the module
    // exports a function that returns a new plain object literal each
    // invocation; only the underlying refs are singletons). LoginView calls
    // `useAuth()` at setup and stores the wrapper on `this.auth`; spy on
    // THAT wrapper so we intercept the exact call site.
    const viewAuth = (wrapper.vm as unknown as { auth: ReturnType<typeof useAuth> }).auth;
    const loginSpy = vi.spyOn(viewAuth, 'login');

    await view.loadJWT();
    await flushPromises();

    // E1 contract: exactly one atomic login() call.
    expect(loginSpy).toHaveBeenCalledTimes(1);

    // First arg: the unwrapped scalar token (NOT the `[token]` envelope —
    // LoginView.vue unwraps `response.data[0]` before calling login()).
    const call = loginSpy.mock.calls[0];
    expect(call[0]).toBe(BOOTSTRAP_TOKEN);
    expect(typeof call[0]).toBe('string');

    // Second arg: the full user payload from /signin. The assertion is on
    // the SHAPE (the scalar-array convention) — if a refactor ever unwrapped
    // the arrays or sliced the payload, router guards downstream would fail
    // role/expiry checks. `toMatchObject` proves the critical fields survive.
    expect(call[1]).toMatchObject({
      user_role: ['Administrator'],
      exp: expect.arrayContaining([expect.any(Number)]),
    });

    loginSpy.mockRestore();
  });

  // -------------------------------------------------------------------------
  // Case 3: No localStorage writes happen before the atomic login() call.
  // -------------------------------------------------------------------------

  it('E1 bootstrap: no localStorage writes happen before the atomic useAuth().login() call', async () => {
    // Track ALL setItem calls across the whole flow so we can assert the
    // timing of writes. The vitest.setup.ts localStorage mock doesn't
    // expose `.length` or key enumeration, but `setItem` is a vi.fn() —
    // we consult its `.mock.calls` to reconstruct write history.
    const setItemSpy = vi.spyOn(window.localStorage, 'setItem');

    // Sanity: no session keys before the flow.
    expect(localStorage.getItem('token')).toBeNull();
    expect(localStorage.getItem('user')).toBeNull();

    let setItemCallsAtAuthenticate: number | null = null;
    let setItemCallsAtSignin: number | null = null;
    server.use(
      http.post('/api/auth/authenticate', () => {
        // Post-authenticate, pre-signin: if the bootstrap persisted the
        // token to storage here (a plausible "simplification" a refactor
        // might introduce), we would see a setItem call recorded.
        setItemCallsAtAuthenticate = setItemSpy.mock.calls.length;
        return HttpResponse.json(bootstrapTokenEnvelope);
      }),
      http.get('/api/auth/signin', () => {
        // Snapshot write count at the signin boundary. `login()` has NOT
        // yet been called (it only fires after /signin resolves), so no
        // token/user setItem may have happened.
        setItemCallsAtSignin = setItemSpy.mock.calls.length;
        return HttpResponse.json(bootstrapUser);
      }),
    );

    const wrapper = mountLoginView();
    const view = vm(wrapper);
    view.user_name = 'testuser';
    view.password = 'testpass';

    await view.loadJWT();
    await flushPromises();

    // Between authenticate and signin: no setItem may have happened.
    // These are the in-resolver snapshots — they fire while the flow is
    // mid-handshake, so they are the load-bearing timing assertion.
    expect(setItemCallsAtAuthenticate).toBe(0);
    expect(setItemCallsAtSignin).toBe(0);

    // After the full flow: the atomic login() has now persisted BOTH keys
    // at once (the E1 contract — the whole reason for the exception).
    expect(localStorage.getItem('token')).toBe(BOOTSTRAP_TOKEN);
    expect(localStorage.getItem('user')).not.toBeNull();
    // Verify BOTH keys got written (login() calls setItem twice atomically).
    const finalWrites = setItemSpy.mock.calls
      .map(([key]) => key as string)
      .filter((k) => k === 'token' || k === 'user')
      .sort();
    expect(finalWrites).toEqual(['token', 'user']);

    setItemSpy.mockRestore();
  });
});
