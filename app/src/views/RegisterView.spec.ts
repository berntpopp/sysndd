// RegisterView.spec.ts
/**
 * v11.0 closeout F2b — spec covering the auth migration on
 * `views/RegisterView.vue`:
 *
 *   1. `mounted()` clears an authenticated stale session through the
 *      auth composable before the register form loads.
 *   2. `doUserLogOut()` delegates to `useAuth().logout()` — not to
 *      `localStorage.removeItem('token' | 'user')` — when a stale
 *      session is present.
 *   3. `sendRegistration()` issues `POST /api/auth/signup` with a JSON body
 *      and WITHOUT an `Authorization` header. Registration is inherently
 *      unauthenticated; the apiClient request interceptor only injects
 *      the Bearer when `useAuth().token.value` is non-null (not the
 *      case before a user signs up).
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { useAuth } from '@/composables/useAuth';
import RegisterView from './RegisterView.vue';

import axios from '@/plugins/axios';

const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

// The RegisterView setup() calls `useHead()` for route-level meta
// titles; outside of `main.ts` / `createHead()` this throws "no
// provide context". The meta tags are not under test here — stubbing
// the composable keeps the setup callable.
vi.mock('@unhead/vue', () => ({
  useHead: () => {},
}));

// vee-validate brings runtime form state we do not exercise here —
// `useField`/`useForm` still render, but we drive the view via the exported
// Options-API methods so vee-validate's validation remains untouched.

const routerPush = vi.fn();

interface RegisterVm {
  doUserLogOut: () => void;
  sendRegistration: () => Promise<void>;
  user_name: string;
  email: string;
  orcid: string;
  first_name: string;
  family_name: string;
  comment: string;
  terms_agreed: string;
  auth: ReturnType<typeof useAuth>;
}

function mountRegister() {
  return mount(RegisterView, {
    global: {
      mocks: {
        axios,
        $route: { path: '/Register' },
        $router: { push: routerPush },
      },
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<div><slot /></div>' },
        BOverlay: { template: '<div><slot /></div>' },
        BCardText: { template: '<div><slot /></div>' },
        BForm: { template: '<form><slot /></form>' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormInput: { template: '<input />' },
        BFormInvalidFeedback: { template: '<div><slot /></div>' },
        BFormCheckbox: { template: '<input type="checkbox" />' },
        BButton: { template: '<button><slot /></button>' },
        BSpinner: { template: '<div />' },
      },
    },
  });
}

beforeEach(() => {
  makeToastSpy.mockClear();
  routerPush.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('RegisterView — v11.0 closeout F2b auth migration', () => {
  it('mounted() clears an authenticated stale session through the auth composable', async () => {
    // Stale session present — the guard must fire and clear it via
    // `useAuth().logout()`.
    primeAuth();
    const auth = useAuth();
    expect(auth.isAuthenticated.value).toBe(true);

    mountRegister();
    await flushPromises();

    // Post-mount: the stale session was torn down through the composable
    // (both keys cleared, reactive refs cleared).
    expect(window.localStorage.getItem('token')).toBeNull();
    expect(window.localStorage.getItem('user')).toBeNull();
    expect(auth.token.value).toBeNull();
    expect(auth.user.value).toBeNull();
    expect(auth.isAuthenticated.value).toBe(false);
    // doUserLogOut pushes to '/' on its way out.
    expect(routerPush).toHaveBeenCalledWith('/');
  });

  it('mounted() does NOT touch auth state when no session is present', async () => {
    const auth = useAuth();
    expect(auth.isAuthenticated.value).toBe(false);

    mountRegister();
    await flushPromises();

    // No stale session → no push, no toast, auth still empty.
    expect(routerPush).not.toHaveBeenCalled();
    expect(auth.token.value).toBeNull();
  });

  it('doUserLogOut routes through useAuth().logout() when called directly', async () => {
    const auth = useAuth();
    const wrapper = mountRegister();
    primeAuth('direct-token');
    expect(auth.isAuthenticated.value).toBe(true);
    const logoutSpy = vi.spyOn(
      (wrapper.vm as unknown as RegisterVm).auth,
      'logout'
    );

    (wrapper.vm as unknown as RegisterVm).doUserLogOut();
    await flushPromises();

    expect(logoutSpy).toHaveBeenCalledTimes(1);
    expect(window.localStorage.getItem('token')).toBeNull();
    expect(window.localStorage.getItem('user')).toBeNull();
    expect(auth.token.value).toBeNull();
    expect(auth.user.value).toBeNull();
    expect(routerPush).toHaveBeenCalledWith('/');
  });

  it('sendRegistration posts JSON with no Bearer header — registration is unauthenticated', async () => {
    // No primeAuth(): this is a fresh visitor submitting the register form.
    const wrapper = mountRegister();
    await flushPromises();

    let capturedAuthHeader: string | null | undefined;
    let capturedMethod: string | undefined;
    let capturedBody: Record<string, unknown> | undefined;
    server.use(
      http.post('/api/auth/signup', async ({ request }) => {
        capturedMethod = request.method;
        capturedAuthHeader = request.headers.get('authorization');
        capturedBody = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ ok: true });
      })
    );

    const vm = wrapper.vm as unknown as RegisterVm;
    // Fill the form fields directly so vee-validate's state stays out of
    // scope; sendRegistration reads `this.user_name` etc.
    vm.user_name = 'new_user';
    vm.email = 'new@sysndd.local';
    vm.orcid = '0000-0000-0000-0000';
    vm.first_name = 'New';
    vm.family_name = 'User';
    vm.comment = 'Motivation';
    vm.terms_agreed = 'accepted';

    await vm.sendRegistration();
    await flushPromises();

    expect(capturedMethod).toBe('POST');
    // The interceptor must NOT inject a Bearer header when the session is
    // empty — registration is pre-auth by definition.
    expect(capturedAuthHeader).toBeNull();
    expect(capturedBody).toEqual({
      user_name: 'new_user',
      email: 'new@sysndd.local',
      orcid: '0000-0000-0000-0000',
      first_name: 'New',
      family_name: 'User',
      comment: 'Motivation',
      terms_agreed: 'accepted',
    });
  });
});
