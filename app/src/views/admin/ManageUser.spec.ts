// ManageUser.spec.ts
/**
 * Phase C.C6 functional spec for `views/admin/ManageUser.vue` (1,732 LoC).
 *
 * Part of the v11.0 Phase C Tier B safety net — see `.planning/_archive/legacy-plans/v11.0/phase-c.md`
 * §3 Phase C.C6.  This file does NOT modify the source; it locks in the two
 * behaviours that E-series rewrites must preserve when the giant Options-API
 * view is refactored onto `useTableData` + `useAsyncJob`:
 *
 *   1. Happy path: editing a user's role issues `PUT /api/user/update` (the
 *      write route confirmed by reading `ManageUser.vue` around line 1558 —
 *      `` `${import.meta.env.VITE_API_URL}/api/user/update` ``) and triggers
 *      a re-fetch of `GET /api/user/table` so the permission matrix
 *      re-renders with fresh server data.
 *   2. Error path: when the backend returns the `userUpdateForbidden` 403
 *      (i.e. attempting to demote the last remaining Administrator), the UI
 *      surfaces a danger toast via `useToast().makeToast` AND the local
 *      `users` array retains the original role assignment — the view must
 *      not optimistically drop the admin role client-side.
 *
 * All `/api/user/*` traffic is routed through the Phase B.B1 MSW handler set
 * (`app/src/test-utils/mocks/handlers.ts`).  No new handlers are introduced;
 * the error branch is installed per-test via `server.use(...)` with the
 * `userUpdateForbidden` shape imported from `data/users.ts` so the 403 body
 * stays centralised.
 *
 * Locked `it.todo`: search/filter state persistence across role edits and
 * bulk-role assignments via `POST /api/user/bulk_assign_role`.  Picked up by
 * the downstream E-series rewrite of ManageUser (`useTableData` migration)
 * once the view exposes the filter state as a reactive ref instead of
 * Options-API data.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import { http, HttpResponse } from 'msw';

import axios from '@/plugins/axios';
import ManageUser from './ManageUser.vue';
import { server } from '@/test-utils/mocks/server';
import { bootstrapStubs } from '@/test-utils';
import { userTableOk, userUpdateForbidden, type UserTableRow } from '@/test-utils/mocks/data/users';
// v11.0 closeout F2b — apiClient helpers for the 9 new Bearer-header
// tests below. The Phase C tests above stay on `localStorage.setItem`
// seeding to keep their assertions stable; the new block uses the
// composable abstraction (`primeAuth()`) so regressions in F1 plumbing
// (useAuth / apiClient interceptor) surface here too.
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import { useAuth } from '@/composables/useAuth';

// -----------------------------------------------------------------------------
// Toast spy — the view surfaces its error "banner" as a danger-variant toast.
// We intercept the composable so the assertion is a function call check rather
// than digging through the real Bootstrap-Vue-Next toast DOM.
// -----------------------------------------------------------------------------
const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

// -----------------------------------------------------------------------------
// Router stub — ManageUser reads `this.$route` / `this.$router` transitively
// (the 401 axios interceptor needs `router.currentRoute`).  A memory-history
// router with a single `/ManageUser` route keeps the interceptor happy without
// wiring the real app router.
// -----------------------------------------------------------------------------
function makeTestRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', name: 'Home', component: { template: '<div />' } },
      { path: '/ManageUser', name: 'ManageUser', component: { template: '<div />' } },
    ],
  });
}

// -----------------------------------------------------------------------------
// Stubs for heavy child components — we only need the cells that carry the
// user_role payload so assertions can prove the matrix re-rendered.  Stubbing
// `GenericTable` avoids pulling in BTable's full implementation (which fights
// with jsdom's layout engine in Vitest).
// -----------------------------------------------------------------------------
const genericTableStub = {
  name: 'GenericTable',
  props: ['items', 'fields', 'sortBy'],
  template: `
    <table data-test="user-table">
      <tbody>
        <tr v-for="row in items" :key="row.user_id" :data-user-id="row.user_id">
          <td data-test="cell-user-name">{{ row.user_name }}</td>
          <td data-test="cell-user-role">{{ row.user_role }}</td>
        </tr>
      </tbody>
    </table>
  `,
};

const tablePaginationControlsStub = {
  name: 'TablePaginationControls',
  template: '<div />',
};

async function mountComponent() {
  const router = makeTestRouter();
  await router.push('/ManageUser');
  await router.isReady();

  const pinia = createPinia();

  const wrapper = mount(ManageUser, {
    global: {
      plugins: [router, pinia],
      // Install the real axios instance as `this.axios` via `mocks` rather
      // than `config.globalProperties`.  Options-API views read axios via
      // `this.axios` (registered globally in `main.ts`), and the `mocks`
      // channel bypasses the `ComponentCustomProperties` intersection type
      // that is augmented by `vue-router` / `pinia` in the production build.
      // The real axios instance still goes through MSW's `fetch` interceptor.
      mocks: {
        axios,
        $http: axios,
      },
      stubs: {
        ...bootstrapStubs,
        GenericTable: genericTableStub,
        TablePaginationControls: tablePaginationControlsStub,
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BModal: {
          name: 'BModal',
          props: ['modelValue'],
          template: '<div v-if="modelValue" role="dialog"><slot /></div>',
        },
        BSpinner: { template: '<div role="status" />' },
        BTable: { template: '<table />' },
        BButtonGroup: { template: '<div><slot /></div>' },
        BFormTextarea: { template: '<textarea />' },
        BFormSelect: {
          name: 'BFormSelect',
          props: ['modelValue', 'options'],
          template: '<div class="form-select-stub"><slot /></div>',
        },
        BFormSelectOption: { template: '<span><slot /></span>' },
        BFormInput: { template: '<input />' },
        BFormCheckbox: { template: '<input type="checkbox" />' },
        BFormGroup: { template: '<div><slot /></div>' },
        BFormInvalidFeedback: { template: '<div><slot /></div>' },
        BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
        BInputGroupText: { template: '<span><slot /></span>' },
        BBadge: { template: '<span><slot /></span>' },
        BPopover: { template: '<div />' },
      },
      directives: {
        'b-tooltip': () => {},
        'b-toggle': () => {},
      },
    },
  });

  // Allow the mounted hook to schedule loadData (50 ms debounce) and let MSW
  // resolve the three initial fetches: GET /api/user/table, /role_list, /list.
  await flushPromises();
  await new Promise((resolve) => setTimeout(resolve, 80));
  await flushPromises();

  return wrapper;
}

describe('ManageUser view — functional (Phase C.C6)', () => {
  beforeEach(() => {
    // Empty base URL so `${import.meta.env.VITE_API_URL}/api/...` resolves to
    // the MSW-intercepted relative path (`/api/...`).  `vi.stubEnv` is the
    // Vitest-sanctioned way to mutate `import.meta.env` inside a test.
    vi.stubEnv('VITE_API_URL', '');
    // Seed a session so the B1 handler table accepts requests. Pre-F2b
    // this used `localStorage.setItem('token', 'test-token')` directly;
    // post-F2b the view reads its Bearer from `useAuth().token.value`
    // through the apiClient interceptor, so we prime the composable
    // instead. Behaviour is identical — a 'test-token' Bearer on every
    // outbound call — but the abstraction seam is the correct one.
    primeAuth('test-token');
    makeToastSpy.mockClear();
  });

  afterEach(() => {
    useAuth().logout();
    vi.unstubAllEnvs();
  });

  // ---------------------------------------------------------------------------
  // Happy path — PUT /api/user/update re-fetches the permission matrix.
  // ---------------------------------------------------------------------------
  it('changing a user role issues PUT /api/user/update and re-renders the permission matrix', async () => {
    // Count the number of times the user/table handler is hit so we can prove
    // the happy-path triggered a re-fetch (initial mount fetch + post-update).
    let userTableFetchCount = 0;
    let updatePayload: Record<string, unknown> | null = null;

    server.use(
      http.get('/api/user/table', () => {
        userTableFetchCount += 1;
        return HttpResponse.json(userTableOk);
      }),
      http.put('/api/user/update', async ({ request }) => {
        updatePayload = (await request.json()) as Record<string, unknown>;
        return HttpResponse.json({ message: 'User successfully updated.' });
      })
    );

    const wrapper = await mountComponent();

    // Sanity: the initial mount fetched the table once and both rows rendered.
    expect(userTableFetchCount).toBeGreaterThanOrEqual(1);
    const initialFetches = userTableFetchCount;
    const roleCells = wrapper.findAll('[data-test="cell-user-role"]');
    expect(roleCells).toHaveLength(2);
    expect(roleCells[1].text()).toBe('Viewer');

    // Simulate the admin editing user 2 (bob_viewer) and promoting to Curator.
    // The view's `editUser` handler assigns `userToUpdate` to a copy of the row
    // and then `updateUserData` reads those fields — we set them directly to
    // keep the spec focused on the network contract rather than modal UX.
    const bob = (userTableOk.data as UserTableRow[]).find((u) => u.user_id === 2)!;
    (wrapper.vm as unknown as { userToUpdate: UserTableRow }).userToUpdate = {
      ...bob,
      user_role: 'Curator',
    };

    await (wrapper.vm as unknown as { updateUserData: () => Promise<void> }).updateUserData();

    // Drain the debounced loadData() kicked off by the success branch.
    await flushPromises();
    await new Promise((resolve) => setTimeout(resolve, 80));
    await flushPromises();

    // Contract: the write went to PUT /api/user/update with the selected role.
    expect(updatePayload).not.toBeNull();
    const payload = updatePayload as { user_details?: Record<string, unknown> };
    expect(payload.user_details).toBeDefined();
    expect(payload.user_details).toMatchObject({
      user_id: 2,
      user_name: 'bob_viewer',
      user_role: 'Curator',
    });

    // Contract: the permission matrix re-renders — i.e. the view re-fetched
    // `/api/user/table` at least one more time after the PUT resolved.
    expect(userTableFetchCount).toBeGreaterThan(initialFetches);

    // A success toast SHOULD fire ('User updated successfully') and must NOT
    // have the danger variant — that would indicate an error branch slipped in.
    const successCall = makeToastSpy.mock.calls.find((call) => call[2] === 'success');
    expect(successCall).toBeDefined();
    const dangerCall = makeToastSpy.mock.calls.find((call) => call[2] === 'danger');
    expect(dangerCall).toBeUndefined();
  });

  // ---------------------------------------------------------------------------
  // Error path — permission denied while demoting the last admin.
  // ---------------------------------------------------------------------------
  it('surfaces an error banner and does not drop the role locally when demoting the last admin is forbidden', async () => {
    server.use(
      http.put('/api/user/update', () => {
        // Use the shape from data/users.ts so the 403 body stays centralised —
        // this is the canonical "demote last admin" backend rejection.
        return HttpResponse.json(userUpdateForbidden, { status: 403 });
      })
    );

    const wrapper = await mountComponent();

    // Capture the rendered role for Alice (user_id=1) before the attempt so
    // we can assert it did not change after the 403.
    const aliceRoleCellBefore = wrapper.findAll(
      'tr[data-user-id="1"] [data-test="cell-user-role"]'
    )[0];
    expect(aliceRoleCellBefore.text()).toBe('Administrator');

    const alice = (userTableOk.data as UserTableRow[]).find((u) => u.user_id === 1)!;
    (wrapper.vm as unknown as { userToUpdate: UserTableRow }).userToUpdate = {
      ...alice,
      user_role: 'Viewer', // attempt to demote the last admin
    };

    await (wrapper.vm as unknown as { updateUserData: () => Promise<void> }).updateUserData();

    await flushPromises();

    // Contract: the view surfaced a danger-variant toast (the "error banner"
    // in the Bootstrap-Vue-Next toast bus).  The message must come from the
    // axios error object, not a generic string.
    const dangerCalls = makeToastSpy.mock.calls.filter((call) => call[2] === 'danger');
    expect(dangerCalls.length).toBeGreaterThan(0);
    // The first danger call's title is 'Error' (per the view's catch branch).
    expect(dangerCalls[0][1]).toBe('Error');

    // Contract: the local `users` array still shows Alice as Administrator —
    // the view must not optimistically drop the role before the PUT returns.
    const users = (wrapper.vm as unknown as { users: UserTableRow[] }).users;
    const aliceAfter = users.find((u) => u.user_id === 1);
    expect(aliceAfter).toBeDefined();
    expect(aliceAfter!.user_role).toBe('Administrator');

    // Sanity: the rendered DOM also still shows Administrator for user 1.
    const aliceRoleCellAfter = wrapper.findAll(
      'tr[data-user-id="1"] [data-test="cell-user-role"]'
    )[0];
    expect(aliceRoleCellAfter.text()).toBe('Administrator');
  });

  // ---------------------------------------------------------------------------
  // Locked TODO — downstream E-series rewrite of ManageUser (useTableData +
  // useFilterSync migration) will pin this behaviour.  The string is verbatim
  // from `.planning/_archive/legacy-plans/v11.0/phase-c.md` §3 Phase C.C6 and must not drift.
  // ---------------------------------------------------------------------------
  it.todo(
    'TODO: verify the search-and-filter state persists across role edits and user_role bulk assignments via POST /api/user/bulk_assign_role'
  );
});

// ===========================================================================
// v11.0 closeout F2b — apiClient Bearer header contract (9 new tests)
// ===========================================================================
// Nine authed call sites in ManageUser.vue were migrated from hand-built
// `Authorization: Bearer ${localStorage.getItem('token')}` headers onto
// `apiClient.raw.*`. Each test below pins one migrated call site with
// `primeAuth() + expectBearerHeader()` so any regression in either this
// view or the F1 plumbing (useAuth / apiClient interceptor) surfaces as
// an observable test failure — not just an ESLint warning.
describe('ManageUser view — v11.0 closeout F2b apiClient Bearer contract', () => {
  beforeEach(() => {
    vi.stubEnv('VITE_API_URL', '');
    makeToastSpy.mockClear();
  });

  afterEach(() => {
    useAuth().logout();
    vi.unstubAllEnvs();
  });

  async function mountWithToken(token: string) {
    primeAuth(token);
    // Keep the initial mount loads quiet and valid.
    server.use(
      http.get('/api/user/table', () => HttpResponse.json(userTableOk)),
      http.get('/api/user/role_list', () =>
        HttpResponse.json([{ role: 'Administrator' }, { role: 'Curator' }, { role: 'Viewer' }])
      ),
      http.get('/api/user/list', () => HttpResponse.json([]))
    );
    return mountComponent();
  }

  it('1. confirmBulkApprove → POST /api/user/bulk_approve carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.post('/api/user/bulk_approve', ({ request }) => {
        expectBearerHeader(request, 'bulk-approve-token');
        sawBearer = true;
        return HttpResponse.json({ processed: 2 });
      })
    );

    const wrapper = await mountWithToken('bulk-approve-token');
    // Feed the selection the view reads via `getSelectedArray()`.
    (
      wrapper.vm as unknown as {
        getSelectedArray?: () => number[];
        selected?: Record<number, boolean>;
      }
    ).selected = { 1: true, 2: true };
    (
      wrapper.vm as unknown as {
        getSelectedArray: () => number[];
      }
    ).getSelectedArray = () => [1, 2];

    await (
      wrapper.vm as unknown as { confirmBulkApprove: () => Promise<void> }
    ).confirmBulkApprove();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });

  it('2. confirmBulkRoleAssignment → POST /api/user/bulk_assign_role carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.post('/api/user/bulk_assign_role', ({ request }) => {
        expectBearerHeader(request, 'bulk-role-token');
        sawBearer = true;
        return HttpResponse.json({ processed: 1 });
      })
    );

    const wrapper = await mountWithToken('bulk-role-token');
    (
      wrapper.vm as unknown as {
        getSelectedArray: () => number[];
        bulkRoleSelection: string;
      }
    ).getSelectedArray = () => [2];
    (wrapper.vm as unknown as { bulkRoleSelection: string }).bulkRoleSelection = 'Curator';

    await (
      wrapper.vm as unknown as { confirmBulkRoleAssignment: () => Promise<void> }
    ).confirmBulkRoleAssignment();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });

  it('3. confirmBulkDelete → POST /api/user/bulk_delete carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.post('/api/user/bulk_delete', ({ request }) => {
        expectBearerHeader(request, 'bulk-delete-token');
        sawBearer = true;
        return HttpResponse.json({ processed: 1 });
      })
    );

    const wrapper = await mountWithToken('bulk-delete-token');
    (wrapper.vm as unknown as { getSelectedArray: () => number[] }).getSelectedArray = () => [2];

    await (wrapper.vm as unknown as { confirmBulkDelete: () => Promise<void> }).confirmBulkDelete();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });

  it('4. doLoadData → GET /api/user/table carries the Bearer header', async () => {
    // Install the Bearer-checking handler BEFORE mountWithToken so the
    // initial mount fetch gets intercepted. The view has a 500ms
    // module-level "same-params skip" guard on doLoadData; wait it out
    // so the initial mount actually fires a fresh network request
    // instead of re-using a cached response from an earlier test in
    // this describe block.
    await new Promise((resolve) => setTimeout(resolve, 520));
    primeAuth('user-table-token');
    let sawBearer = false;
    server.use(
      http.get('/api/user/table', ({ request }) => {
        expectBearerHeader(request, 'user-table-token');
        sawBearer = true;
        return HttpResponse.json(userTableOk);
      }),
      http.get('/api/user/role_list', () => HttpResponse.json([])),
      http.get('/api/user/list', () => HttpResponse.json([]))
    );
    await mountComponent();
    expect(sawBearer).toBe(true);
  });

  it('5. loadRoleList → GET /api/user/role_list carries the Bearer header', async () => {
    primeAuth('role-list-token');
    let sawBearer = false;
    server.use(
      http.get('/api/user/table', () => HttpResponse.json(userTableOk)),
      http.get('/api/user/role_list', ({ request }) => {
        expectBearerHeader(request, 'role-list-token');
        sawBearer = true;
        return HttpResponse.json([{ role: 'Administrator' }]);
      }),
      http.get('/api/user/list', () => HttpResponse.json([]))
    );
    await mountComponent();
    expect(sawBearer).toBe(true);
  });

  it('6. loadUserList → GET /api/user/list carries the Bearer header', async () => {
    primeAuth('user-list-token');
    let sawBearer = false;
    server.use(
      http.get('/api/user/table', () => HttpResponse.json(userTableOk)),
      http.get('/api/user/role_list', () => HttpResponse.json([])),
      http.get('/api/user/list', ({ request }) => {
        expectBearerHeader(request, 'user-list-token');
        sawBearer = true;
        return HttpResponse.json([]);
      })
    );
    await mountComponent();
    expect(sawBearer).toBe(true);
  });

  it('7. confirmDeleteUser → DELETE /api/user/delete carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.delete('/api/user/delete', ({ request }) => {
        expectBearerHeader(request, 'delete-user-token');
        sawBearer = true;
        return HttpResponse.json({ message: 'Deleted' });
      })
    );

    const wrapper = await mountWithToken('delete-user-token');
    (wrapper.vm as unknown as { userToDelete: { user_id: number } }).userToDelete = {
      user_id: 2,
    };

    await (wrapper.vm as unknown as { confirmDeleteUser: () => Promise<void> }).confirmDeleteUser();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });

  it('8. updateUserData → PUT /api/user/update carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.put('/api/user/update', ({ request }) => {
        expectBearerHeader(request, 'update-user-token');
        sawBearer = true;
        return HttpResponse.json({ message: 'Updated' });
      })
    );

    const wrapper = await mountWithToken('update-user-token');
    const bob = (userTableOk.data as UserTableRow[]).find((u) => u.user_id === 2)!;
    (wrapper.vm as unknown as { userToUpdate: UserTableRow }).userToUpdate = { ...bob };

    await (wrapper.vm as unknown as { updateUserData: () => Promise<void> }).updateUserData();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });

  it('9. changeUserPassword → PUT /api/user/password/update carries the Bearer header', async () => {
    let sawBearer = false;
    server.use(
      http.put('/api/user/password/update', ({ request }) => {
        expectBearerHeader(request, 'pass-update-token');
        sawBearer = true;
        return HttpResponse.json({ message: 'Password updated' });
      })
    );

    const wrapper = await mountWithToken('pass-update-token');
    (wrapper.vm as unknown as { userToUpdate: UserTableRow }).userToUpdate = {
      ...(userTableOk.data as UserTableRow[])[0],
    };
    const vm = wrapper.vm as unknown as {
      passwordChange: {
        newPassword: string;
        confirmPassword: string;
        showPassword: boolean;
        isChanging: boolean;
      };
      passwordValidation: { isValid: boolean };
      changeUserPassword: () => Promise<void>;
    };
    vm.passwordChange.newPassword = 'NewPass1!abcdefgh';
    vm.passwordChange.confirmPassword = 'NewPass1!abcdefgh';
    // Force the validation guard true so the code path proceeds to the PUT.
    Object.defineProperty(vm, 'passwordValidation', {
      value: { isValid: true },
      configurable: true,
    });

    await vm.changeUserPassword();
    await flushPromises();
    expect(sawBearer).toBe(true);
  });
});
