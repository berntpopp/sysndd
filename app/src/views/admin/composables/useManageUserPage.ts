// app/src/views/admin/composables/useManageUserPage.ts
/**
 * Page-level composition for `views/admin/ManageUser.vue` (issue #346, Wave 2
 * Task 6 — users domain only).
 *
 * This composable owns ONLY the ManageUser page orchestration: wiring the
 * five owning composables together, the cross-page bulk-selection helpers,
 * the mount/URL-restore lifecycle (including the one-time filter-preset
 * seed), the filter/sort watchers, and the legacy-named action aliases the
 * pre-existing `ManageUser.spec.ts` pins.
 *
 * It deliberately does NOT own table data fetching/URL sync (`useUserData`),
 * mutation payloads (`useUserMutations`), bulk-action network calls
 * (`useBulkUserActions`), modal visibility state (`useUserModals`), or table
 * presentation config (`useUserTablePresentation`) — those five composables
 * remain the single owners of their respective responsibilities and are only
 * wired together here.
 */
import { computed, nextTick, onMounted, shallowRef, watch } from 'vue';
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import { useBulkSelection } from '@/composables';
import { useUiStore } from '@/stores/ui';

import { useUserData } from './useUserData';
import type { ManageUserFilter } from './useUserData';
import { useUserMutations } from './useUserMutations';
import type { UpdateUserPayload } from './useUserMutations';
import { useBulkUserActions } from './useBulkUserActions';
import { useUserModals } from './useUserModals';
import { useUserTablePresentation } from './useUserTablePresentation';

export function useManageUserPage() {
  useHead({ title: 'Manage Users' });

  const { makeToast } = useToast();
  const uiStore = useUiStore();
  const bulkSelection = useBulkSelection(20);

  const toastFn = makeToast as (...args: unknown[]) => void;
  const data = useUserData({
    onToast: toastFn,
    onScrollbarUpdate: () => uiStore.requestScrollbarUpdate(),
  });
  const modals = useUserModals({ onToast: toastFn });
  const mutations = useUserMutations({
    onToast: toastFn,
    onSuccess: () => {
      void data.loadData();
      modals.close();
    },
  });
  const bulk = useBulkUserActions({
    onToast: toastFn,
    onSuccess: () => {
      void data.loadData();
      bulkSelection.clearSelection();
      modals.close();
    },
  });

  // ── Derived state ──────────────────────────────────────────────────────────
  // Table column config + role badge/icon lookups (pure presentation seam).
  const { fields, getRoleBadgeVariant, getRoleIcon } = useUserTablePresentation();

  const hasActiveFilters = computed(() =>
    Object.values(data.filter.value).some((f) => f.content !== null && f.content !== '')
  );

  const activeFilters = computed(() => {
    const filters: Array<{ key: string; label: string; value: string }> = [];
    if (data.filter.value.any.content)
      filters.push({
        key: 'any',
        label: 'Search',
        value: data.filter.value.any.content as string,
      });
    if (data.filter.value.user_role.content)
      filters.push({
        key: 'user_role',
        label: 'Role',
        value: data.filter.value.user_role.content as string,
      });
    if (
      data.filter.value.approved.content !== null &&
      data.filter.value.approved.content !== undefined
    ) {
      filters.push({
        key: 'approved',
        label: 'Status',
        value: data.filter.value.approved.content === '1' ? 'Approved' : 'Pending',
      });
    }
    return filters;
  });

  const allOnPageSelected = computed(() => {
    if (data.users.value.length === 0) return false;
    return data.users.value.every((user: Record<string, unknown>) =>
      bulkSelection.isSelected(user.user_id as number)
    );
  });

  // ── Selection helpers ──────────────────────────────────────────────────────
  function toggleSelectAllOnPage(): void {
    if (allOnPageSelected.value) {
      data.users.value.forEach((user: Record<string, unknown>) => {
        const id = user.user_id as number;
        if (bulkSelection.isSelected(id)) bulkSelection.toggleSelection(id);
      });
    } else {
      const pageUserIds = data.users.value.map((u: Record<string, unknown>) => u.user_id as number);
      const added = bulkSelection.selectMultiple(pageUserIds);
      if (added < pageUserIds.length && bulkSelection.selectionCount.value >= 20) {
        makeToast(
          `Selection limited to 20 users. ${added} users added.`,
          'Selection Limit',
          'warning'
        );
      }
    }
  }

  function handleRowSelect(userId: number): void {
    const success = bulkSelection.toggleSelection(userId);
    if (!success)
      makeToast('Maximum 20 users can be selected at once', 'Selection Limit Reached', 'warning');
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  onMounted(() => {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('sort')) {
      const sortObj = data.sortStringToVariables(urlParams.get('sort')!);
      data.sortBy.value = sortObj.sortBy;
      data.sort.value = urlParams.get('sort') as string;
    }
    if (urlParams.get('filter')) {
      data.filter.value = data.filterStrToObj(
        urlParams.get('filter'),
        data.filter.value
      ) as ManageUserFilter;
      data.filter_string.value = urlParams.get('filter') as string;
    }
    if (urlParams.get('page_after')) {
      data.currentItemID.value = parseInt(urlParams.get('page_after') as string, 10) || 0;
    }
    if (urlParams.get('page_size')) {
      data.perPage.value = parseInt(urlParams.get('page_size') as string, 10) || 25;
    }

    data.loadRoleList();
    data.loadUserList();

    if (data.filterPresets.presets.value.length === 0) {
      data.filterPresets.savePreset('Pending', {
        any: { content: null, join_char: null, operator: 'contains' },
        user_role: { content: null, join_char: ',', operator: 'any' },
        approved: { content: '0', join_char: null, operator: 'equals' },
      });
      data.filterPresets.savePreset('Curators', {
        any: { content: null, join_char: null, operator: 'contains' },
        user_role: { content: 'Curator', join_char: ',', operator: 'any' },
        approved: { content: null, join_char: null, operator: 'equals' },
      });
    }

    nextTick(() => {
      data.loadData();
      nextTick(() => {
        data.isInitializing.value = false;
      });
    });
  });

  // ── Watchers ──────────────────────────────────────────────────────────────
  watch(
    data.filter,
    () => {
      if (!data.isInitializing.value) data.filtered();
    },
    { deep: true }
  );
  watch(
    data.sortBy,
    () => {
      if (!data.isInitializing.value) data.handleSortByOrDescChange();
    },
    { deep: true }
  );

  // ── Exposed actions (plan aliases + legacy aliases for existing spec) ──────
  // Composables re-throw after toasting; swallow at the orchestration layer
  // so callers don't see unhandled rejections (toast already covers UX).
  const onConfirmDelete = () =>
    mutations.deleteUser(modals.userToDelete.value as { user_id: number }).catch(() => {});
  // updateUserData reads from modals.userToUpdate.value so the spec can set
  // wrapper.vm.userToUpdate = {...} and then call wrapper.vm.updateUserData()
  // with no args (matching original ManageUser.vue behaviour).
  // Errors are already toasted inside mutations.updateUser; swallow the
  // re-throw here so callers (and the spec) don't see unhandled rejections.
  const updateUserData = () =>
    mutations.updateUser(modals.userToUpdate.value as unknown as UpdateUserPayload).catch(() => {});
  const onSubmitUpdate = (payload?: UpdateUserPayload) => {
    const p =
      payload !== undefined
        ? mutations.updateUser(payload)
        : mutations.updateUser(modals.userToUpdate.value as unknown as UpdateUserPayload);
    return p.catch(() => {});
  };
  // Use a shallowRef so the spec can override wrapper.vm.getSelectedArray and
  // the confirm handlers pick up the override (same dynamic dispatch as the
  // original Options-API `this.getSelectedArray()`).
  const getSelectedArray = shallowRef<() => number[]>(bulkSelection.getSelectedArray);
  const onConfirmBulkApprove = () => bulk.bulkApprove(getSelectedArray.value()).catch(() => {});
  const onConfirmBulkRole = () =>
    bulk.bulkAssignRole(getSelectedArray.value(), modals.bulkRoleSelection.value).catch(() => {});
  const onConfirmBulkDelete = () => bulk.bulkDelete(getSelectedArray.value()).catch(() => {});
  const onChangePassword = () =>
    mutations.changePassword({
      userId: modals.userToUpdate.value.user_id as number,
      newPassword: mutations.passwordChange.value.newPassword,
      confirmPassword: mutations.passwordChange.value.confirmPassword,
    });

  return {
    // ── data composable ──
    ...data,
    // ── modal composable ──
    ...modals,
    // ── mutation composable ──
    ...mutations,
    // ── bulk composable ──
    ...bulk,
    // ── bulk selection composable ──
    ...bulkSelection,
    // Override the plain getSelectedArray from bulkSelection with the shallowRef
    // so that spec assignments like `wrapper.vm.getSelectedArray = () => [1,2]`
    // flow through Vue's ref-unwrap setter and update getSelectedArray.value,
    // which the confirm handlers then pick up (matches Options-API `this.*` dispatch).
    getSelectedArray,
    // ── local computed ──
    fields,
    hasActiveFilters,
    activeFilters,
    allOnPageSelected,
    // ── local functions ──
    toggleSelectAllOnPage,
    handleRowSelect,
    getRoleBadgeVariant,
    getRoleIcon,
    // ── plan-named actions ──
    onConfirmDelete,
    onSubmitUpdate,
    onConfirmBulkApprove,
    onConfirmBulkRole,
    onConfirmBulkDelete,
    onChangePassword,
    // ── legacy aliases (preserved for existing ManageUser.spec.ts) ──
    confirmDeleteUser: onConfirmDelete,
    updateUserData,
    confirmBulkApprove: onConfirmBulkApprove,
    confirmBulkRoleAssignment: onConfirmBulkRole,
    confirmBulkDelete: onConfirmBulkDelete,
    changeUserPassword: onChangePassword,
    makeToast,
  };
}

export default useManageUserPage;
