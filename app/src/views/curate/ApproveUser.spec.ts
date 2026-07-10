// ApproveUser.spec.ts
/**
 * Spec for `views/curate/ApproveUser.vue`.
 *
 * Wave 2 Task 7 of #346 moved queue/filter/pagination/modal/load/mutation
 * state into `useUserApprovalQueue()` (see `./composables/
 * useUserApprovalQueue.spec.ts` for the composable's own thorough unit
 * coverage of pending-only filtering, combined search/role filtering, page
 * reset, the review->reject modal transition, toast/announcement behavior,
 * and role-before-approval ordering). This file stays focused on proving
 * the *view* wires the composable correctly end-to-end:
 *
 *   - GET /api/user/table        (`loadUserTableData`)
 *   - GET /api/user/role_list    (`loadRoleList`)
 *   - PUT /api/user/approval     (`handleUserApproval`)
 *   - PUT /api/user/change_role  (`handleUserChangeRole`)
 *
 * All four now route through the typed `@/api/user` clients (built on
 * `apiClient`). This spec uses `primeAuth() + expectBearerHeader()` to
 * prove the Bearer header the apiClient request interceptor injects is
 * still present after the extraction, plus a handful of integration-level
 * checks (filtering, modal transition, mutation ordering) exercised
 * through the mounted component rather than the composable directly.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { nextTick } from 'vue';
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
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: announceSpy,
  }),
}));

interface ApproveUserRow {
  user_id: number;
  user_name: string;
  email: string;
  user_role: string;
  approved: number;
  first_name?: string;
  family_name?: string;
  created_at?: string;
}

interface ApproveUserVm {
  loadUserTableData: () => Promise<void>;
  loadRoleList: () => Promise<void>;
  handleUserApproval: (userId: number, approved: boolean) => Promise<void>;
  handleUserChangeRole: (userId: number, role: string) => Promise<void>;
  reviewUser: (user: ApproveUserRow) => void;
  rejectFromModal: () => void;
  handleApproveWithChanges: () => Promise<void>;
  items_UsersTable: ApproveUserRow[];
  role_options: unknown[];
  filteredItems: ApproveUserRow[];
  filter: string;
  roleFilter: string | null;
  currentPage: number;
  totalRows: number;
  selectedUser: Partial<ApproveUserRow>;
  showReviewModal: boolean;
  showRejectModal: boolean;
}

const ALICE: ApproveUserRow = {
  user_id: 1,
  user_name: 'alice',
  email: 'alice@example.org',
  user_role: 'Curator',
  approved: 0,
  first_name: 'Alice',
  family_name: 'Anderson',
};
const BOB: ApproveUserRow = {
  user_id: 2,
  user_name: 'bob',
  email: 'bob@example.org',
  user_role: 'Reviewer',
  approved: 0,
  first_name: 'Bob',
  family_name: 'Baxter',
};
const CARL_APPROVED: ApproveUserRow = {
  user_id: 3,
  user_name: 'carl',
  email: 'carl@example.org',
  user_role: 'Viewer',
  approved: 1,
};

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
    // toast/announcement behavior: a success toast + a11y announce fire on 2xx.
    expect(makeToastSpy).toHaveBeenCalledWith('User approved successfully.', 'Success', 'success');
    expect(announceSpy).toHaveBeenCalledWith('User approved successfully.');
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

  it('filters the loaded queue to pending users, then narrows by combined search + role', async () => {
    primeAuth('filter-token');
    server.use(
      http.get('/api/user/table', () => HttpResponse.json([ALICE, BOB, CARL_APPROVED])),
      http.get('/api/user/role_list', () => HttpResponse.json([]))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;

    // Approved carl is dropped; only the two pending applications remain.
    expect(vm.items_UsersTable.map((u) => u.user_name)).toEqual(['alice', 'bob']);

    vm.filter = 'b';
    vm.roleFilter = 'Reviewer';
    await nextTick();
    expect(vm.filteredItems.map((u) => u.user_name)).toEqual(['bob']);

    vm.roleFilter = 'Curator';
    await nextTick();
    expect(vm.filteredItems).toEqual([]);
  });

  it('resets to page 1 when the filtered set changes shape (page reset)', async () => {
    primeAuth('page-reset-token');
    server.use(
      http.get('/api/user/table', () => HttpResponse.json([ALICE, BOB])),
      http.get('/api/user/role_list', () => HttpResponse.json([]))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;

    vm.currentPage = 3;
    expect(vm.currentPage).toBe(3);

    vm.filter = 'alice';
    await nextTick();
    expect(vm.currentPage).toBe(1);
    expect(vm.totalRows).toBe(1);
  });

  it('transitions from the review modal to the reject modal (review->reject)', async () => {
    primeAuth('review-reject-token');
    server.use(
      http.get('/api/user/table', () => HttpResponse.json([ALICE])),
      http.get('/api/user/role_list', () => HttpResponse.json([]))
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;

    vm.reviewUser(ALICE);
    expect(vm.showReviewModal).toBe(true);
    expect(vm.selectedUser.user_id).toBe(1);

    vm.rejectFromModal();
    expect(vm.showReviewModal).toBe(false);
    expect(vm.showRejectModal).toBe(false);

    await nextTick();
    expect(vm.showRejectModal).toBe(true);
  });

  it('assigns the role BEFORE approving when a review is saved with a role change (ordering)', async () => {
    primeAuth('ordering-token');
    const callOrder: string[] = [];

    server.use(
      http.get('/api/user/table', () => HttpResponse.json([ALICE])),
      http.get('/api/user/role_list', () => HttpResponse.json([])),
      http.put('/api/user/change_role', () => {
        callOrder.push('change_role');
        return HttpResponse.json({ message: 'Role updated' });
      }),
      http.put('/api/user/approval', () => {
        callOrder.push('approval');
        return HttpResponse.json({ message: 'Approved' });
      })
    );

    const wrapper = await mountView();
    const vm = wrapper.vm as unknown as ApproveUserVm;

    vm.reviewUser({ ...ALICE, user_role: 'Administrator' });
    await vm.handleApproveWithChanges();
    await flushPromises();

    expect(callOrder).toEqual(['change_role', 'approval']);
    expect(vm.showReviewModal).toBe(false);
  });
});
