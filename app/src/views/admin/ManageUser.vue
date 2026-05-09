<!-- views/admin/ManageUser.vue — orchestration shell (v11.2 W1) -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <template #header>
              <BRow>
                <BCol>
                  <h5 class="mb-1 text-start">
                    <strong>Manage Users</strong>
                    <BBadge variant="secondary" class="ms-2">{{ totalRows }} users</BBadge>
                    <BBadge v-if="selectionCount > 0" variant="primary" class="ms-2">
                      {{ selectionCount }} selected
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <!-- Bulk action toolbar -->
                  <UserBulkActionToolbar
                    :selection-count="selectionCount"
                    :busy="bulkActing || isUpdating || isDeleting"
                    @approve="openBulkApprove(getSelectedArray(), users as any)"
                    @assign-role="openBulkRole(getSelectedArray(), users as any)"
                    @delete="openBulkDelete(getSelectedArray(), users as any)"
                    @clear="clearSelection"
                  />
                  <!-- Existing buttons (export, filter) -->
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    class="me-1"
                    :variant="isExporting ? 'secondary' : 'outline-primary'"
                    :disabled="isExporting"
                    title="Export to Excel"
                    @click="handleExport"
                  >
                    <BSpinner v-if="isExporting" small />
                    <i v-else class="bi bi-file-earmark-excel" />
                  </BButton>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    :variant="hasActiveFilters ? 'outline-danger' : 'outline-secondary'"
                    :title="hasActiveFilters ? 'Clear all filters' : 'No active filters'"
                    @click="removeFilters"
                  >
                    <i class="bi bi-funnel" />
                  </BButton>
                </BCol>
              </BRow>
            </template>

            <!-- Filter presets row -->
            <BRow
              v-if="filterPresets.presets.value.length > 0 || hasActiveFilters"
              class="px-2 pt-2"
            >
              <BCol>
                <div class="d-flex gap-2 align-items-center flex-wrap">
                  <span class="text-muted small">Quick filters:</span>
                  <BButton
                    v-for="preset in filterPresets.presets.value"
                    :key="preset.name"
                    size="sm"
                    variant="outline-secondary"
                    class="py-0"
                    @click="loadFilterPreset(preset.name)"
                  >
                    {{ preset.name }}
                    <i class="bi bi-x-lg ms-1" @click.stop="deleteFilterPreset(preset.name)" />
                  </BButton>
                  <BButton
                    v-if="hasActiveFilters"
                    v-b-tooltip.hover
                    size="sm"
                    variant="outline-primary"
                    class="py-0"
                    title="Save current filter as preset"
                    @click="showSavePresetPrompt"
                  >
                    <i class="bi bi-plus-lg" /> Save Preset
                  </BButton>
                </div>
              </BCol>
            </BRow>

            <BRow class="px-2 py-2">
              <BCol sm="8">
                <BInputGroup>
                  <template #prepend>
                    <BInputGroupText><i class="bi bi-search" /></BInputGroupText>
                  </template>
                  <BFormInput
                    v-model="filter.any.content"
                    placeholder="Search by name, email, institution..."
                    debounce="300"
                    type="search"
                    @update:model-value="filtered()"
                  />
                </BInputGroup>
              </BCol>
              <BCol sm="4">
                <BContainer v-if="totalRows > perPage">
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="pageOptions"
                    :current-page="currentPage"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </BContainer>
              </BCol>
            </BRow>

            <BRow class="px-2 pb-2">
              <BCol sm="4">
                <BFormSelect
                  v-model="filter.user_role.content"
                  :options="role_options"
                  size="sm"
                  @update:model-value="filtered()"
                >
                  <template #first>
                    <BFormSelectOption :value="null">All Roles</BFormSelectOption>
                  </template>
                </BFormSelect>
              </BCol>
              <BCol sm="4">
                <BFormSelect
                  v-model="filter.approved.content"
                  :options="[
                    { value: '1', text: 'Approved' },
                    { value: '0', text: 'Pending' },
                  ]"
                  size="sm"
                  @update:model-value="filtered()"
                >
                  <template #first>
                    <BFormSelectOption :value="null">All Status</BFormSelectOption>
                  </template>
                </BFormSelect>
              </BCol>
              <BCol sm="4" class="text-end">
                <span class="text-muted small">
                  Showing {{ (currentPage - 1) * perPage + 1 }}-{{
                    Math.min(currentPage * perPage, totalRows)
                  }}
                  of {{ totalRows }}
                </span>
              </BCol>
            </BRow>

            <BRow v-if="hasActiveFilters" class="px-2 pb-2">
              <BCol>
                <BBadge
                  v-for="(activeFilter, index) in activeFilters"
                  :key="index"
                  variant="secondary"
                  class="me-2 mb-1"
                >
                  {{ activeFilter.label }}: {{ activeFilter.value }}
                  <BButton
                    size="sm"
                    variant="link"
                    class="p-0 ms-1 text-light"
                    @click="clearFilter(activeFilter.key)"
                  >
                    <i class="bi bi-x" />
                  </BButton>
                </BBadge>
                <BButton size="sm" variant="link" class="p-0" @click="removeFilters">
                  Clear all
                </BButton>
              </BCol>
            </BRow>

            <div class="position-relative">
              <BSpinner
                v-if="isBusy"
                class="position-absolute top-50 start-50 translate-middle"
                variant="primary"
              />
              <div v-if="!isBusy && users.length === 0" class="text-center py-4">
                <i class="bi bi-people fs-1 text-muted" />
                <p class="text-muted mt-2">No users found matching your filters</p>
                <BButton v-if="hasActiveFilters" variant="link" @click="removeFilters">
                  Clear filters
                </BButton>
              </div>
              <GenericTable
                v-else
                :items="users"
                :fields="fields"
                :sort-by="sortBy"
                :class="{ 'opacity-50': isBusy }"
                @update:sort-by="handleSortUpdate"
              >
                <template #head-select>
                  <BFormCheckbox
                    :model-value="allOnPageSelected"
                    :indeterminate="selectionCount > 0 && !allOnPageSelected"
                    @update:model-value="toggleSelectAllOnPage"
                  />
                </template>
                <template #cell-select="{ row }">
                  <BFormCheckbox
                    :model-value="isSelected(row.user_id)"
                    @update:model-value="handleRowSelect(row.user_id)"
                  />
                </template>
                <template #cell-actions="{ row }">
                  <div>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="me-1 btn-xs"
                      title="Edit user"
                      @click="editUser(row)"
                    >
                      <i class="bi bi-pen" />
                    </BButton>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="me-1 btn-xs"
                      title="Delete user"
                      @click="promptDelete(row)"
                    >
                      <i class="bi bi-x" />
                    </BButton>
                  </div>
                </template>
                <template #cell-user_role="{ row }">
                  <BBadge
                    :variant="getRoleBadgeVariant(row.user_role) as any"
                    class="d-inline-flex align-items-center gap-1"
                  >
                    <i :class="getRoleIcon(row.user_role)" />
                    {{ row.user_role }}
                  </BBadge>
                </template>
                <template #cell-approved="{ row }">
                  <BBadge
                    :variant="row.approved ? 'success' : 'warning'"
                    class="d-inline-flex align-items-center gap-1"
                  >
                    <i :class="row.approved ? 'bi bi-check-circle-fill' : 'bi bi-clock-fill'" />
                    {{ row.approved ? 'Approved' : 'Pending' }}
                  </BBadge>
                </template>
              </GenericTable>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Modals -->
      <UserDeleteConfirmModal
        v-model:visible="isDeleteOpen"
        :user="userToDelete as any"
        @confirm="onConfirmDelete"
        @cancel="close"
      />

      <UserUpdateModal
        v-model:visible="isUpdateOpen"
        v-model:password-change="passwordChange"
        :user="userToUpdate"
        :password-validation="passwordValidation"
        :is-changing-password="isChangingPassword"
        @submit="onSubmitUpdate"
        @cancel="close"
        @change-password="onChangePassword"
        @generate-password="generatePassword"
      />

      <UserBulkApproveModal
        v-model:visible="isBulkApproveOpen"
        :usernames="bulkApproveUsernames"
        @confirm="onConfirmBulkApprove"
        @cancel="close"
      />

      <UserBulkDeleteModal
        v-model:visible="isBulkDeleteOpen"
        v-model:confirm-text="deleteConfirmText"
        :usernames="bulkDeleteUsernames"
        @confirm="onConfirmBulkDelete"
        @cancel="close"
      />

      <UserBulkRoleModal
        v-model:visible="isBulkRoleOpen"
        v-model:selected-role="bulkRoleSelection"
        :usernames="bulkRoleUsernames"
        @confirm="onConfirmBulkRole"
        @cancel="close"
      />
    </BContainer>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent, nextTick, onMounted, shallowRef, watch } from 'vue';
import useToast from '@/composables/useToast';
import { useBulkSelection } from '@/composables';
import { useUiStore } from '@/stores/ui';

import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

import UserBulkActionToolbar from './components/UserBulkActionToolbar.vue';
import UserUpdateModal from './components/UserUpdateModal.vue';
import UserDeleteConfirmModal from './components/UserDeleteConfirmModal.vue';
import UserBulkApproveModal from './components/UserBulkApproveModal.vue';
import UserBulkDeleteModal from './components/UserBulkDeleteModal.vue';
import UserBulkRoleModal from './components/UserBulkRoleModal.vue';

import { useUserData } from './composables/useUserData';
import { useUserMutations } from './composables/useUserMutations';
import { useBulkUserActions } from './composables/useBulkUserActions';
import { useUserModals } from './composables/useUserModals';

export default defineComponent({
  name: 'ManageUser',
  components: {
    GenericTable,
    TablePaginationControls,
    UserBulkActionToolbar,
    UserUpdateModal,
    UserDeleteConfirmModal,
    UserBulkApproveModal,
    UserBulkDeleteModal,
    UserBulkRoleModal,
  },
  setup() {
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
    const fields = [
      {
        key: 'select',
        label: '',
        class: 'text-center',
        thStyle: { width: '40px' },
        sortable: false,
      },
      {
        key: 'user_name',
        label: 'User name',
        sortable: true,
        filterable: true,
        sortDirection: 'asc',
        class: 'text-start',
      },
      {
        key: 'email',
        label: 'E-mail',
        sortable: true,
        filterable: true,
        sortDirection: 'asc',
        class: 'text-start',
      },
      {
        key: 'user_role',
        label: 'Role',
        sortable: true,
        selectable: true,
        sortDirection: 'asc',
        class: 'text-start',
      },
      {
        key: 'approved',
        label: 'Status',
        sortable: true,
        selectable: true,
        sortDirection: 'asc',
        class: 'text-center',
      },
      {
        key: 'abbreviation',
        label: 'Abbrev.',
        sortable: true,
        sortDirection: 'asc',
        class: 'text-start',
      },
      {
        key: 'created_at',
        label: 'Created',
        sortable: true,
        sortDirection: 'asc',
        class: 'text-start',
      },
      { key: 'actions', label: 'Actions', sortable: false, class: 'text-center' },
    ];

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
      return data.users.value.every((user: any) => bulkSelection.isSelected(user.user_id));
    });

    // ── Selection helpers ──────────────────────────────────────────────────────
    function toggleSelectAllOnPage(): void {
      if (allOnPageSelected.value) {
        data.users.value.forEach((user: any) => {
          if (bulkSelection.isSelected(user.user_id)) bulkSelection.toggleSelection(user.user_id);
        });
      } else {
        const pageUserIds = data.users.value.map((u: any) => u.user_id);
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

    // ── Utility helpers ────────────────────────────────────────────────────────
    function getRoleBadgeVariant(role: string): string {
      const variants: Record<string, string> = {
        Administrator: 'danger',
        Curator: 'primary',
        Reviewer: 'info',
        Viewer: 'secondary',
      };
      return variants[role] || 'secondary';
    }

    function getRoleIcon(role: string): string {
      const icons: Record<string, string> = {
        Administrator: 'bi bi-shield-fill-check',
        Curator: 'bi bi-pencil-fill',
        Reviewer: 'bi bi-eye-fill',
        Viewer: 'bi bi-person-fill',
      };
      return icons[role] || 'bi bi-person-fill';
    }

    function showSavePresetPrompt(): void {
      const name = prompt('Enter a name for this filter preset:');
      if (name && name.trim()) {
        data.saveFilterPreset(name.trim());
        makeToast(`Saved preset: ${name.trim()}`, 'Filter Preset', 'success', true, 3000);
      }
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
        data.filter.value = data.filterStrToObj(urlParams.get('filter'), data.filter.value) as any;
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
      mutations.deleteUser(modals.userToDelete.value as any).catch(() => {});
    // updateUserData reads from modals.userToUpdate.value so the spec can set
    // wrapper.vm.userToUpdate = {...} and then call wrapper.vm.updateUserData()
    // with no args (matching original ManageUser.vue behaviour).
    // Errors are already toasted inside mutations.updateUser; swallow the
    // re-throw here so callers (and the spec) don't see unhandled rejections.
    const updateUserData = () =>
      mutations.updateUser(modals.userToUpdate.value as any).catch(() => {});
    const onSubmitUpdate = (payload: any) => {
      const p =
        payload !== undefined
          ? mutations.updateUser(payload)
          : mutations.updateUser(modals.userToUpdate.value as any);
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
        userId: (modals.userToUpdate.value as any).user_id,
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
      showSavePresetPrompt,
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
  },
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
