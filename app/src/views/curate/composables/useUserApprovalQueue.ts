// app/src/views/curate/composables/useUserApprovalQueue.ts
//
// Wave 2 Task 7 of #346 — queue-orchestration composable extracted from
// `ApproveUser.vue`. Owns everything the Curator/Administrator "Approve
// Users" queue needs so the view itself is a thin template-binding shell:
//
//   - loading the pending-user queue + the assignable-role list
//     (`GET /api/user/table`, `GET /api/user/role_list`)
//   - client-side search + role filtering, and the pagination that rides
//     on top of the filtered result (resets to page 1 whenever the
//     filtered set changes shape)
//   - the three confirmation-modal flows (quick approve / review+approve /
//     reject) and the review -> reject in-modal transition
//   - the two mutations (`PUT /api/user/approval`, `PUT /api/user/change_role`)
//     and their toast/announce side effects
//   - the queue table's static field config and the pure display
//     formatters the row/modal templates call (no reactive state — kept
//     here beside the rows they render rather than split into a file of
//     their own)
//
// `GET /api/user/table` normally resolves to the cursor-pagination
// envelope (`{ links, meta, data }`) per `api/endpoints/user_endpoints.R`,
// but the original component defensively unwrapped a bare array too (the
// general Plumber-array gotcha — see AGENTS.md). That defensive unwrap is
// preserved unchanged in `extractUserRows`.

import { computed, nextTick, ref, watch } from 'vue';
import {
  approveUser as apiApproveUser,
  changeUserRole as apiChangeUserRole,
  getRoleList,
  getUserTable,
} from '@/api/user';
import type { UserTableRow } from '@/api/user';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface RoleOption {
  value: string;
  text: string;
}

export interface RoleFilterOption {
  value: string | null;
  text: string;
}

export interface PageOption {
  value: number;
  text: string;
}

export interface UseUserApprovalQueueOptions {
  onToast?: (
    message: unknown,
    title?: string,
    variant?: string,
    autoHide?: boolean,
    autoHideDelay?: number
  ) => void;
  onAnnounce?: (text: string, level?: 'polite' | 'assertive') => void;
  onScrollbarUpdate?: () => void;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const PAGE_OPTIONS: PageOption[] = [
  { value: 5, text: '5' },
  { value: 10, text: '10' },
  { value: 25, text: '25' },
  { value: 50, text: '50' },
];

/** Static `BTable`/`GenericTable`-style field config for the queue table. */
export const APPROVE_USER_TABLE_FIELDS = Object.freeze([
  { key: 'user_name', label: 'User', sortable: true, class: 'text-start' },
  { key: 'email', label: 'Email', sortable: true, class: 'text-start' },
  { key: 'orcid', label: 'ORCID', sortable: true, class: 'text-start' },
  { key: 'user_role', label: 'Requested Role', sortable: true, class: 'text-start' },
  { key: 'created_at', label: 'Applied', sortable: true, class: 'text-start' },
  { key: 'comment', label: 'Comment', sortable: false, class: 'text-start' },
  { key: 'actions', label: 'Actions', class: 'text-center' },
]);

const ROLE_BADGE_VARIANTS: Record<string, string> = {
  Administrator: 'danger',
  Curator: 'primary',
  Reviewer: 'info',
  Viewer: 'secondary',
};

const ROLE_ICONS: Record<string, string> = {
  Administrator: 'bi bi-shield-fill-check',
  Curator: 'bi bi-pencil-fill',
  Reviewer: 'bi bi-eye-fill',
  Viewer: 'bi bi-person-fill',
};

/** `created_at` / applied-date display formatter (e.g. "Jul 10, 2026"). */
export function formatDate(dateString?: string | null): string {
  if (!dateString) return '—';
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

export function getRoleBadgeVariant(role?: string | null): string {
  return (role && ROLE_BADGE_VARIANTS[role]) || 'secondary';
}

export function getRoleIcon(role?: string | null): string {
  return (role && ROLE_ICONS[role]) || 'bi bi-person-fill';
}

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

export function useUserApprovalQueue(options: UseUserApprovalQueueOptions = {}) {
  const { onToast, onAnnounce, onScrollbarUpdate } = options;

  const role_options = ref<RoleOption[]>([]);
  const items_UsersTable = ref<UserTableRow[]>([]);
  const totalRows = ref(0);
  const loadingUsersApprove = ref(true);
  const selectedUser = ref<Partial<UserTableRow>>({});
  const showReviewModal = ref(false);
  const showApproveModal = ref(false);
  const showRejectModal = ref(false);
  const currentPage = ref(1);
  const perPage = ref(10);
  const pageOptions = PAGE_OPTIONS;
  const filter = ref('');
  const roleFilter = ref<string | null>(null);

  const roleFilterOptions = computed<RoleFilterOption[]>(() => {
    const roles = [...new Set(items_UsersTable.value.map((item) => item.user_role))].filter(
      (role): role is string => Boolean(role)
    );
    return [
      { value: null, text: 'All Roles' },
      ...roles.map((role) => ({ value: role, text: role })),
    ];
  });

  const filteredItems = computed<UserTableRow[]>(() => {
    let items = items_UsersTable.value;

    // Filter by search text
    if (filter.value) {
      const searchTerm = filter.value.toLowerCase();
      items = items.filter(
        (item) =>
          (item.user_name && item.user_name.toLowerCase().includes(searchTerm)) ||
          (item.email && item.email.toLowerCase().includes(searchTerm)) ||
          (item.first_name && item.first_name.toLowerCase().includes(searchTerm)) ||
          (item.family_name && item.family_name.toLowerCase().includes(searchTerm))
      );
    }

    // Filter by role
    if (roleFilter.value) {
      items = items.filter((item) => item.user_role === roleFilter.value);
    }

    return items;
  });

  const paginatedItems = computed<UserTableRow[]>(() => {
    const start = Math.max(currentPage.value - 1, 0) * perPage.value;
    return filteredItems.value.slice(start, start + perPage.value);
  });

  // Mirrors ApproveUser.vue's original `watch: { filteredItems() {...} }` —
  // any change to the search text, role filter, or underlying queue resets
  // to page 1 and re-syncs the displayed total.
  watch(filteredItems, (next) => {
    totalRows.value = next.length;
    currentPage.value = 1;
  });

  /**
   * `GET /api/user/table` normally resolves to the cursor-pagination
   * envelope (`{ links, meta, data }`). Some Plumber responses instead
   * serialize a bare array (see the R/Plumber JSON gotcha in AGENTS.md);
   * preserve the original component's defensive unwrap for both shapes.
   */
  function extractUserRows(raw: unknown): UserTableRow[] {
    if (Array.isArray(raw)) {
      return raw as UserTableRow[];
    }
    const data = (raw as { data?: unknown } | null | undefined)?.data;
    return Array.isArray(data) ? (data as UserTableRow[]) : [];
  }

  async function loadUserTableData(): Promise<void> {
    loadingUsersApprove.value = true;
    try {
      const raw: unknown = await getUserTable();
      const users = extractUserRows(raw);
      // Show only unapproved (pending) applications.
      items_UsersTable.value = users.filter((user) => !user.approved || user.approved === 0);
      totalRows.value = items_UsersTable.value.length;
      onScrollbarUpdate?.();
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      items_UsersTable.value = [];
      totalRows.value = 0;
    } finally {
      loadingUsersApprove.value = false;
    }
  }

  async function loadRoleList(): Promise<void> {
    try {
      const roles = await getRoleList();
      role_options.value = Array.isArray(roles)
        ? roles.map((item) => ({ value: item.role, text: item.role }))
        : [];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  function approveUser(user: UserTableRow): void {
    selectedUser.value = { ...user };
    showApproveModal.value = true;
  }

  function reviewUser(user: UserTableRow): void {
    selectedUser.value = { ...user };
    showReviewModal.value = true;
  }

  function rejectUser(user: UserTableRow): void {
    selectedUser.value = { ...user };
    showRejectModal.value = true;
  }

  // Review -> reject in-modal transition: close the review modal, then
  // (next tick, so the review modal's own close teardown isn't racing the
  // reopen) show the reject-confirmation modal for the same selectedUser.
  function rejectFromModal(): void {
    showReviewModal.value = false;
    void nextTick(() => {
      showRejectModal.value = true;
    });
  }

  async function handleUserApproval(userId: number, approved: boolean): Promise<void> {
    try {
      await apiApproveUser(userId, { status_approval: approved });
      const message = approved ? 'User approved successfully.' : 'User application rejected.';
      onToast?.(message, 'Success', approved ? 'success' : 'info');
      onAnnounce?.(message);
      await loadUserTableData();
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      onAnnounce?.('Error approving user', 'assertive');
    }
  }

  async function handleUserChangeRole(userId: number, userRole: string): Promise<void> {
    try {
      await apiChangeUserRole(userId, { role_assigned: userRole });
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  async function confirmApprove(): Promise<void> {
    await handleUserApproval(selectedUser.value.user_id as number, true);
    showApproveModal.value = false;
  }

  // Role assignment MUST be persisted before the approval call: approving
  // sends the welcome email against the user's then-current role, so a
  // change_role call landing after approval would race that email. Keep
  // this ordering unchanged.
  async function handleApproveWithChanges(): Promise<void> {
    if (selectedUser.value.user_role) {
      await handleUserChangeRole(selectedUser.value.user_id as number, selectedUser.value.user_role);
    }
    await handleUserApproval(selectedUser.value.user_id as number, true);
    showReviewModal.value = false;
  }

  async function confirmReject(): Promise<void> {
    await handleUserApproval(selectedUser.value.user_id as number, false);
    showRejectModal.value = false;
  }

  return {
    // static table config + pure display formatters (no reactive state)
    fields: APPROVE_USER_TABLE_FIELDS,
    formatDate,
    getRoleBadgeVariant,
    getRoleIcon,
    // owned state
    role_options,
    items_UsersTable,
    totalRows,
    loadingUsersApprove,
    selectedUser,
    showReviewModal,
    showApproveModal,
    showRejectModal,
    currentPage,
    perPage,
    pageOptions,
    filter,
    roleFilter,
    // derived state
    roleFilterOptions,
    filteredItems,
    paginatedItems,
    // load
    loadUserTableData,
    loadRoleList,
    // modal triggers
    approveUser,
    reviewUser,
    rejectUser,
    rejectFromModal,
    // mutations
    handleUserApproval,
    handleUserChangeRole,
    confirmApprove,
    handleApproveWithChanges,
    confirmReject,
  };
}

export default useUserApprovalQueue;
