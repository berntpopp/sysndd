// app/src/views/curate/composables/useUserApprovalQueue.spec.ts
/**
 * Unit tests for `useUserApprovalQueue` — the queue-orchestration
 * composable extracted from `ApproveUser.vue` during Wave 2 Task 7 of #346.
 *
 * Covers everything the composable owns: pending-only filtering, combined
 * search/role filtering, the filtered-set page reset, the review->reject
 * modal transition, toast/announcement behavior, and role-before-approval
 * ordering — plus the array/`{data}` defensive unwrap the original
 * component's `loadUserTableData()` performed.
 *
 * Mock strategy: stub `axios` at the module level (the typed clients in
 * `@/api/user` resolve through it), matching the established precedent in
 * `src/views/review/composables/__tests__/` and
 * `src/views/admin/composables/__tests__/`.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { nextTick } from 'vue';

vi.mock('axios', () => {
  const axiosMock = {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    defaults: { baseURL: '', headers: { common: {} } },
    interceptors: {
      request: { use: vi.fn(), _cb: null },
      response: { use: vi.fn() },
    },
    isAxiosError: (err: unknown): boolean =>
      typeof err === 'object' && err !== null && 'isAxiosError' in err,
  };
  return {
    default: axiosMock,
    ...axiosMock,
    AxiosHeaders: class {
      private store = new Map<string, string>();
      has(key: string): boolean {
        return this.store.has(key.toLowerCase());
      }
      get(key: string): string | null {
        return this.store.get(key.toLowerCase()) ?? null;
      }
      set(key: string, value: string): this {
        this.store.set(key.toLowerCase(), value);
        return this;
      }
    },
    AxiosError: Error,
  };
});

vi.mock('@/router', () => ({
  default: {
    push: vi.fn(),
    currentRoute: { value: { fullPath: '/curate/ApproveUser' } },
  },
}));

import {
  useUserApprovalQueue,
  APPROVE_USER_TABLE_FIELDS,
  formatDate,
  getRoleBadgeVariant,
  getRoleIcon,
} from './useUserApprovalQueue';

interface AxiosMock {
  get: ReturnType<typeof vi.fn>;
  put: ReturnType<typeof vi.fn>;
}

async function getAxiosMock(): Promise<AxiosMock> {
  const axios = await import('axios');
  return axios.default as unknown as AxiosMock;
}

const PENDING_ALICE = {
  user_id: 1,
  user_name: 'alice',
  email: 'alice@example.org',
  orcid: null,
  abbreviation: null,
  first_name: 'Alice',
  family_name: 'Anderson',
  comment: null,
  terms_agreed: 1,
  created_at: '2026-07-01T00:00:00Z',
  user_role: 'Curator',
  approved: 0,
};
const PENDING_BOB = {
  user_id: 2,
  user_name: 'bob',
  email: 'bob@example.org',
  orcid: null,
  abbreviation: null,
  first_name: 'Bob',
  family_name: 'Baxter',
  comment: null,
  terms_agreed: 1,
  created_at: '2026-07-02T00:00:00Z',
  user_role: 'Reviewer',
  approved: 0,
};
const APPROVED_CARL = {
  user_id: 3,
  user_name: 'carl',
  email: 'carl@example.org',
  orcid: null,
  abbreviation: null,
  first_name: 'Carl',
  family_name: 'Carlson',
  comment: null,
  terms_agreed: 1,
  created_at: '2026-07-03T00:00:00Z',
  user_role: 'Viewer',
  approved: 1,
};

describe('useUserApprovalQueue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('loadUserTableData', () => {
    it('keeps only pending (unapproved) users from an enveloped {data} response', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: { data: [PENDING_ALICE, PENDING_BOB, APPROVED_CARL], meta: [], links: [] },
      });

      const queue = useUserApprovalQueue();
      await queue.loadUserTableData();
      await flushPromises();

      expect(queue.items_UsersTable.value).toHaveLength(2);
      expect(queue.items_UsersTable.value.map((u) => u.user_name)).toEqual(['alice', 'bob']);
      expect(queue.totalRows.value).toBe(2);
      expect(queue.loadingUsersApprove.value).toBe(false);
    });

    it('also accepts a bare-array response (defensive Plumber-array unwrap)', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: [PENDING_ALICE, APPROVED_CARL] });

      const queue = useUserApprovalQueue();
      await queue.loadUserTableData();
      await flushPromises();

      expect(queue.items_UsersTable.value).toHaveLength(1);
      expect(queue.items_UsersTable.value[0].user_name).toBe('alice');
    });

    it('routes errors through onToast and clears the queue', async () => {
      const axios = await getAxiosMock();
      const err = new Error('boom');
      axios.get.mockRejectedValueOnce(err);
      const onToast = vi.fn();

      const queue = useUserApprovalQueue({ onToast });
      await queue.loadUserTableData();
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith(err, 'Error', 'danger');
      expect(queue.items_UsersTable.value).toEqual([]);
      expect(queue.totalRows.value).toBe(0);
      expect(queue.loadingUsersApprove.value).toBe(false);
    });

    it('calls onScrollbarUpdate on success', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({ data: { data: [PENDING_ALICE] } });
      const onScrollbarUpdate = vi.fn();

      const queue = useUserApprovalQueue({ onScrollbarUpdate });
      await queue.loadUserTableData();
      await flushPromises();

      expect(onScrollbarUpdate).toHaveBeenCalledTimes(1);
    });
  });

  describe('loadRoleList', () => {
    it('populates role_options on success', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: [{ role: 'Curator' }, { role: 'Reviewer' }],
      });

      const queue = useUserApprovalQueue();
      await queue.loadRoleList();
      await flushPromises();

      expect(queue.role_options.value).toEqual([
        { value: 'Curator', text: 'Curator' },
        { value: 'Reviewer', text: 'Reviewer' },
      ]);
    });

    it('routes errors through onToast', async () => {
      const axios = await getAxiosMock();
      const err = new Error('role list down');
      axios.get.mockRejectedValueOnce(err);
      const onToast = vi.fn();

      const queue = useUserApprovalQueue({ onToast });
      await queue.loadRoleList();
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith(err, 'Error', 'danger');
    });
  });

  describe('filtering', () => {
    async function seededQueue() {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: { data: [PENDING_ALICE, PENDING_BOB, APPROVED_CARL] },
      });
      const queue = useUserApprovalQueue();
      await queue.loadUserTableData();
      await flushPromises();
      return queue;
    }

    it('search text matches user_name/email/first_name/family_name case-insensitively', async () => {
      const queue = await seededQueue();
      queue.filter.value = 'ALICE';
      expect(queue.filteredItems.value.map((u) => u.user_name)).toEqual(['alice']);

      queue.filter.value = 'baxter';
      expect(queue.filteredItems.value.map((u) => u.user_name)).toEqual(['bob']);
    });

    it('role filter narrows to the exact requested role', async () => {
      const queue = await seededQueue();
      queue.roleFilter.value = 'Reviewer';
      expect(queue.filteredItems.value.map((u) => u.user_name)).toEqual(['bob']);
    });

    it('combines search text AND role filter', async () => {
      const queue = await seededQueue();
      queue.filter.value = 'alice';
      queue.roleFilter.value = 'Reviewer';
      // alice is a Curator, so the AND combination yields nothing.
      expect(queue.filteredItems.value).toEqual([]);

      queue.roleFilter.value = 'Curator';
      expect(queue.filteredItems.value.map((u) => u.user_name)).toEqual(['alice']);
    });

    it('roleFilterOptions lists distinct roles from the pending queue plus "All Roles"', async () => {
      const queue = await seededQueue();
      expect(queue.roleFilterOptions.value).toEqual([
        { value: null, text: 'All Roles' },
        { value: 'Curator', text: 'Curator' },
        { value: 'Reviewer', text: 'Reviewer' },
      ]);
    });
  });

  describe('pagination page reset', () => {
    it('resets currentPage to 1 and totalRows whenever the filtered set changes shape', async () => {
      const axios = await getAxiosMock();
      axios.get.mockResolvedValueOnce({
        data: { data: [PENDING_ALICE, PENDING_BOB] },
      });
      const queue = useUserApprovalQueue();
      await queue.loadUserTableData();
      await flushPromises();
      await nextTick();

      queue.currentPage.value = 3;
      expect(queue.currentPage.value).toBe(3);

      queue.filter.value = 'alice';
      await nextTick();

      expect(queue.currentPage.value).toBe(1);
      expect(queue.totalRows.value).toBe(1);
    });
  });

  describe('modal triggers', () => {
    it('approveUser sets selectedUser and opens the approve modal only', () => {
      const queue = useUserApprovalQueue();
      queue.approveUser(PENDING_ALICE);
      expect(queue.selectedUser.value).toEqual(PENDING_ALICE);
      expect(queue.showApproveModal.value).toBe(true);
      expect(queue.showReviewModal.value).toBe(false);
      expect(queue.showRejectModal.value).toBe(false);
    });

    it('reviewUser sets selectedUser and opens the review modal only', () => {
      const queue = useUserApprovalQueue();
      queue.reviewUser(PENDING_BOB);
      expect(queue.selectedUser.value).toEqual(PENDING_BOB);
      expect(queue.showReviewModal.value).toBe(true);
      expect(queue.showApproveModal.value).toBe(false);
    });

    it('rejectUser sets selectedUser and opens the reject modal only', () => {
      const queue = useUserApprovalQueue();
      queue.rejectUser(PENDING_ALICE);
      expect(queue.selectedUser.value).toEqual(PENDING_ALICE);
      expect(queue.showRejectModal.value).toBe(true);
      expect(queue.showApproveModal.value).toBe(false);
    });

    it('rejectFromModal transitions review -> reject on the next tick', async () => {
      const queue = useUserApprovalQueue();
      queue.reviewUser(PENDING_ALICE);
      expect(queue.showReviewModal.value).toBe(true);

      queue.rejectFromModal();
      // Closes the review modal synchronously...
      expect(queue.showReviewModal.value).toBe(false);
      expect(queue.showRejectModal.value).toBe(false);

      // ...and opens the reject modal only after the next tick.
      await nextTick();
      expect(queue.showRejectModal.value).toBe(true);
    });
  });

  describe('mutations', () => {
    it('confirmApprove PUTs /api/user/approval with status_approval=true and closes the modal', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } }); // reload after approval

      const queue = useUserApprovalQueue();
      queue.approveUser(PENDING_ALICE);
      await queue.confirmApprove();
      await flushPromises();

      expect(axios.put).toHaveBeenCalledWith(
        '/api/user/approval',
        undefined,
        expect.objectContaining({ params: { user_id: 1, status_approval: true } })
      );
      expect(queue.showApproveModal.value).toBe(false);
    });

    it('confirmReject PUTs /api/user/approval with status_approval=false and closes the modal', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } });

      const queue = useUserApprovalQueue();
      queue.rejectUser(PENDING_BOB);
      await queue.confirmReject();
      await flushPromises();

      expect(axios.put).toHaveBeenCalledWith(
        '/api/user/approval',
        undefined,
        expect.objectContaining({ params: { user_id: 2, status_approval: false } })
      );
      expect(queue.showRejectModal.value).toBe(false);
    });

    it('handleApproveWithChanges assigns the role BEFORE approving (ordering)', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValue({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } }); // reload after approval

      const queue = useUserApprovalQueue();
      queue.reviewUser({ ...PENDING_ALICE, user_role: 'Curator' });
      await queue.handleApproveWithChanges();
      await flushPromises();

      expect(axios.put).toHaveBeenCalledTimes(2);
      const [firstCall, secondCall] = axios.put.mock.calls;
      expect(firstCall[0]).toBe('/api/user/change_role');
      expect(firstCall[2]).toEqual(
        expect.objectContaining({ params: { user_id: 1, role_assigned: 'Curator' } })
      );
      expect(secondCall[0]).toBe('/api/user/approval');
      expect(secondCall[2]).toEqual(
        expect.objectContaining({ params: { user_id: 1, status_approval: true } })
      );
      expect(queue.showReviewModal.value).toBe(false);
    });

    it('handleApproveWithChanges skips the role call when no role is selected', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValue({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } });

      const queue = useUserApprovalQueue();
      queue.reviewUser({ ...PENDING_ALICE, user_role: '' });
      await queue.handleApproveWithChanges();
      await flushPromises();

      expect(axios.put).toHaveBeenCalledTimes(1);
      expect(axios.put).toHaveBeenCalledWith(
        '/api/user/approval',
        undefined,
        expect.objectContaining({ params: { user_id: 1, status_approval: true } })
      );
    });

    it('handleUserApproval toasts + announces success and reloads the table', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } });
      const onToast = vi.fn();
      const onAnnounce = vi.fn();

      const queue = useUserApprovalQueue({ onToast, onAnnounce });
      await queue.handleUserApproval(1, true);
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith('User approved successfully.', 'Success', 'success');
      expect(onAnnounce).toHaveBeenCalledWith('User approved successfully.');
      // handleUserApproval() reloads the queue on success.
      expect(axios.get).toHaveBeenCalledWith('/api/user/table', { params: {} });
    });

    it('handleUserApproval toasts a rejection message + info variant when approved=false', async () => {
      const axios = await getAxiosMock();
      axios.put.mockResolvedValueOnce({ data: { message: 'ok' } });
      axios.get.mockResolvedValueOnce({ data: { data: [] } });
      const onToast = vi.fn();
      const onAnnounce = vi.fn();

      const queue = useUserApprovalQueue({ onToast, onAnnounce });
      await queue.handleUserApproval(2, false);
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith('User application rejected.', 'Success', 'info');
      expect(onAnnounce).toHaveBeenCalledWith('User application rejected.');
    });

    it('handleUserApproval routes failures through onToast (danger) and announces assertively', async () => {
      const axios = await getAxiosMock();
      const err = new Error('403');
      axios.put.mockRejectedValueOnce(err);
      const onToast = vi.fn();
      const onAnnounce = vi.fn();

      const queue = useUserApprovalQueue({ onToast, onAnnounce });
      await queue.handleUserApproval(1, true);
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith(err, 'Error', 'danger');
      expect(onAnnounce).toHaveBeenCalledWith('Error approving user', 'assertive');
    });

    it('handleUserChangeRole routes failures through onToast (danger)', async () => {
      const axios = await getAxiosMock();
      const err = new Error('403');
      axios.put.mockRejectedValueOnce(err);
      const onToast = vi.fn();

      const queue = useUserApprovalQueue({ onToast });
      await queue.handleUserChangeRole(1, 'Curator');
      await flushPromises();

      expect(onToast).toHaveBeenCalledWith(err, 'Error', 'danger');
    });
  });

  describe('static table config + display formatters', () => {
    it('exposes the queue table field config on the composable return', () => {
      const queue = useUserApprovalQueue();
      expect(queue.fields).toBe(APPROVE_USER_TABLE_FIELDS);
      expect(queue.fields.map((f) => f.key)).toEqual([
        'user_name',
        'email',
        'orcid',
        'user_role',
        'created_at',
        'comment',
        'actions',
      ]);
    });

    it('formatDate renders a short US date or the placeholder for empty input', () => {
      // Midday UTC so the assertion is stable across CI/local timezones.
      expect(formatDate('2026-07-01T12:00:00Z')).toBe('Jul 1, 2026');
      expect(formatDate(null)).toBe('—');
      expect(formatDate(undefined)).toBe('—');
    });

    it('getRoleBadgeVariant/getRoleIcon map known roles and fall back for unknown ones', () => {
      expect(getRoleBadgeVariant('Administrator')).toBe('danger');
      expect(getRoleBadgeVariant('unknown-role')).toBe('secondary');
      expect(getRoleIcon('Curator')).toBe('bi bi-pencil-fill');
      expect(getRoleIcon(null)).toBe('bi bi-person-fill');
    });
  });
});
