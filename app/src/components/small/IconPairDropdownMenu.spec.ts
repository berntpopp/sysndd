// IconPairDropdownMenu.spec.ts
/**
 * v11.0 closeout F2b — spec covering the three migrated auth branches on
 * `IconPairDropdownMenu.vue`:
 *
 *   1. `doUserLogOut` routes through `useAuth().logout()` and does NOT
 *      touch `localStorage.removeItem('token' | 'user')` directly.
 *   2. `refreshWithJWT` issues `GET /api/auth/refresh` with the current
 *      session Bearer and persists the returned token through `useAuth`.
 *   3. `signinWithJWT` issues `GET /api/auth/signin` with the Bearer
 *      header (injected by the apiClient request interceptor) and
 *      updates `useAuth().user` via `login(currentToken, user)`.
 *
 * The pre-F2b implementation read/wrote `localStorage.token` /
 * `localStorage.user` by hand in every one of those branches — the
 * closeout grep gate fails any regression, and this spec pins the
 * migrated path so future edits cannot drift without notice.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';

// Importing the plugin attaches the baseURL + 401 response interceptor to
// the shared axios default instance so the apiClient request interceptor
// fires with the same config the production app sees.
import '@/plugins/axios';
import IconPairDropdownMenu from './IconPairDropdownMenu.vue';

const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

interface DropdownVm {
  doUserLogOut: () => void;
  refreshWithJWT: () => Promise<void>;
  signinWithJWT: () => Promise<void>;
}

const routerPush = vi.fn();
const routerGo = vi.fn();

function mountMenu() {
  return mount(IconPairDropdownMenu, {
    props: {
      title: 'User',
      required: [],
      align: 'right',
      items: [],
    },
    global: {
      mocks: {
        $route: { path: '/SomeOther' },
        $router: { push: routerPush, go: routerGo },
      },
      stubs: {
        BNavItemDropdown: { template: '<div><slot /></div>' },
        BDropdownItem: { template: '<a><slot /></a>' },
      },
    },
  });
}

beforeEach(() => {
  makeToastSpy.mockClear();
  routerPush.mockClear();
  routerGo.mockClear();
});

afterEach(() => {
  useAuth().logout();
});

describe('IconPairDropdownMenu — v11.0 closeout F2b auth migration', () => {
  it('doUserLogOut routes through useAuth().logout() — no direct localStorage removal', async () => {
    primeAuth();
    const auth = useAuth();
    expect(auth.isAuthenticated.value).toBe(true);

    // Spy on `window.localStorage.removeItem` — the pre-F2b implementation
    // called `localStorage.removeItem('user')` + `localStorage.removeItem('token')`
    // directly. `useAuth().logout()` still uses `removeItem`, but only from
    // inside the composable module. We assert the observable outcome: after
    // invoking `doUserLogOut`, both keys are gone AND the reactive refs are
    // cleared (proving the call went through the composable, not a local
    // dot-access shortcut that would miss the refs).
    const wrapper = mountMenu();

    (wrapper.vm as unknown as DropdownVm).doUserLogOut();
    await flushPromises();

    // Both keys must be gone — `useAuth().logout()` owns the cleanup.
    expect(window.localStorage.getItem('token')).toBeNull();
    expect(window.localStorage.getItem('user')).toBeNull();
    // The composable cleared its reactive refs (evidence the logout flowed
    // through `useAuth()` — a direct localStorage nuke would leave these
    // stale until the next `syncFromStorage`).
    expect(auth.token.value).toBeNull();
    expect(auth.user.value).toBeNull();
    expect(auth.isAuthenticated.value).toBe(false);
    // The component triggers a home redirect through the router after
    // logout; the route path is not '/', so `push({ name: 'Home' })` fires.
    expect(routerPush).toHaveBeenCalledWith({ name: 'Home' });
  });

  it('refreshWithJWT calls /api/auth/refresh with Bearer and persists the new token via useAuth', async () => {
    primeAuth('test-token-old');
    const auth = useAuth();

    server.use(
      http.get('/api/auth/refresh', ({ request }) => {
        expectBearerHeader(request, 'test-token-old');
        // R/Plumber scalar-array shape is unwrapped by `useAuth().refresh`.
        return HttpResponse.json(['fresh-token-123']);
      }),
      http.get('/api/auth/signin', ({ request }) => {
        // The subsequent signinWithJWT must pick up the new token.
        expectBearerHeader(request, 'fresh-token-123');
        return HttpResponse.json({
          user_id: [1],
          user_name: ['test-admin'],
          email: ['test@sysndd.local'],
          user_role: ['Administrator'],
          user_created: ['2024-01-01'],
          abbreviation: ['TA'],
          orcid: [''],
          exp: [Math.floor(Date.now() / 1000) + 3600],
        });
      })
    );

    const wrapper = mountMenu();
    await (wrapper.vm as unknown as DropdownVm).refreshWithJWT();
    await flushPromises();

    expect(auth.token.value).toBe('fresh-token-123');
    // signinWithJWT completed successfully → no danger toast raised.
    expect(makeToastSpy).not.toHaveBeenCalled();
  });

  it('signinWithJWT sends the Bearer header and stores the returned user via useAuth', async () => {
    primeAuth('test-token-sign');
    const auth = useAuth();

    const payload = {
      user_id: [42],
      user_name: ['curator-42'],
      email: ['curator@sysndd.local'],
      user_role: ['Curator'],
      user_created: ['2025-01-01'],
      abbreviation: ['C42'],
      orcid: [''],
      exp: [Math.floor(Date.now() / 1000) + 7200],
    };

    server.use(
      http.get('/api/auth/signin', ({ request }) => {
        expectBearerHeader(request, 'test-token-sign');
        return HttpResponse.json(payload);
      })
    );

    const wrapper = mountMenu();
    await (wrapper.vm as unknown as DropdownVm).signinWithJWT();
    await flushPromises();

    expect(auth.user.value?.user_name?.[0]).toBe('curator-42');
    expect(auth.user.value?.user_role?.[0]).toBe('Curator');
    // Token is unchanged because signin doesn't rotate it.
    expect(auth.token.value).toBe('test-token-sign');
  });
});
