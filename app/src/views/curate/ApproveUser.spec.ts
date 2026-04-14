// ApproveUser.spec.ts
/**
 * v11.0 closeout F2b — spec for `views/curate/ApproveUser.vue`.
 *
 * Four authed endpoints now route through `apiClient.raw.*`:
 *
 *   - GET /api/user/table        (`loadUserTableData`)
 *   - GET /api/user/role_list    (`loadRoleList`)
 *   - PUT /api/user/approval     (`handleUserApproval`)
 *   - PUT /api/user/change_role  (`handleUserChangeRole`)
 *
 * Every call previously stamped its own
 * `Authorization: Bearer ${localStorage.getItem('token')}` header — the
 * migration delegates that to the apiClient request interceptor. This
 * spec uses `primeAuth() + expectBearerHeader()` to prove the header is
 * still injected after the refactor.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';
import ApproveUser from './ApproveUser.vue';

const makeToastSpy = vi.fn();
const announceSpy = vi.fn();

vi.mock('@/composables', () => ({
  useToast: () => ({ makeToast: makeToastSpy }),
  useColorAndSymbols: () => ({}),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: announceSpy,
  }),
}));

interface ApproveUserVm {
  loadUserTableData: () => Promise<void>;
  loadRoleList: () => Promise<void>;
  handleUserApproval: (userId: number, approved: boolean) => Promise<void>;
  handleUserChangeRole: (userId: number, role: string) => Promise<void>;
  items_UsersTable: unknown[];
  role_options: unknown[];
}

async function mountView() {
  setActivePinia(createPinia());
  const wrapper = mount(ApproveUser, {
    global: {
      directives: { 'b-tooltip': {}, 'b-toggle': {} },
      stubs: {
        AriaLiveRegion: { template: '<div />' },
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BSpinner: { template: '<div />' },
        BFormInput: { template: '<input />' },
        BFormSelect: { template: '<select />' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BTable: {
          props: ['items'],
          template: '<table />',
        },
        BPagination: { template: '<nav />' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormTextarea: { template: '<textarea />' },
        BForm: { template: '<form><slot /></form>' },
        BModal: { template: '<div><slot /></div>' },
        BPopover: { template: '<div />' },
        BLink: { template: '<a><slot /></a>' },
      },
    },
  });
  await flushPromises();
  return wrapper;
}

beforeEach(() => {
  makeToastSpy.mockClear();
  announceSpy.mockClear();
  vi.stubEnv('VITE_API_URL', '');
});

afterEach(() => {
  useAuth().logout();
  vi.unstubAllEnvs();
});

describe('ApproveUser — v11.0 closeout F2b apiClient migration', () => {
  it('loadUserTableData() fetches /api/user/table with the Bearer header', async () => {
    primeAuth('approve-users-token');

    server.use(
      http.get('/api/user/table', ({ request }) => {
        expectBearerHeader(request, 'approve-users-token');
        return HttpResponse.json([]);
      }),
      http.get('/api/user/role_list', () => HttpResponse.json([]))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;
    await vm.loadUserTableData();
    await flushPromises();
    expect(Array.isArray(vm.items_UsersTable)).toBe(true);
  });

  it('loadRoleList() fetches /api/user/role_list with the Bearer header', async () => {
    primeAuth('roles-token');

    server.use(
      http.get('/api/user/table', () => HttpResponse.json([])),
      http.get('/api/user/role_list', ({ request }) => {
        expectBearerHeader(request, 'roles-token');
        return HttpResponse.json([{ role: 'Curator' }, { role: 'Reviewer' }]);
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;
    await vm.loadRoleList();
    await flushPromises();
    expect(vm.role_options).toEqual([
      { value: 'Curator', text: 'Curator' },
      { value: 'Reviewer', text: 'Reviewer' },
    ]);
  });

  it('handleUserApproval() issues PUT /api/user/approval with the Bearer header', async () => {
    primeAuth('approve-token');

    // Initial mount hits both loaders — keep them quiet.
    server.use(
      http.get('/api/user/table', () => HttpResponse.json([])),
      http.get('/api/user/role_list', () => HttpResponse.json([])),
      http.put('/api/user/approval', ({ request }) => {
        expectBearerHeader(request, 'approve-token');
        // The view builds the URL as query-string params (user_id and
        // status_approval). MSW path-matches the bare path.
        const url = new URL(request.url);
        expect(url.searchParams.get('user_id')).toBe('42');
        expect(url.searchParams.get('status_approval')).toBe('true');
        return HttpResponse.json({ message: 'Approved' });
      })
    );

    const wrapper = await mountView();
    await (wrapper.vm as unknown as ApproveUserVm).handleUserApproval(42, true);
    await flushPromises();
    // A success announce fires on 2xx.
    expect(announceSpy).toHaveBeenCalled();
  });

  it('handleUserChangeRole() issues PUT /api/user/change_role with the Bearer header', async () => {
    primeAuth('role-change-token');

    server.use(
      http.get('/api/user/table', () => HttpResponse.json([])),
      http.get('/api/user/role_list', () => HttpResponse.json([])),
      http.put('/api/user/change_role', ({ request }) => {
        expectBearerHeader(request, 'role-change-token');
        const url = new URL(request.url);
        expect(url.searchParams.get('user_id')).toBe('42');
        expect(url.searchParams.get('role_assigned')).toBe('Curator');
        return HttpResponse.json({ message: 'Role updated' });
      })
    );

    const wrapper = await mountView();
    await (wrapper.vm as unknown as ApproveUserVm).handleUserChangeRole(42, 'Curator');
    await flushPromises();
  });
});
