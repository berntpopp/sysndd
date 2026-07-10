<!-- views/admin/ManageUser.vue — orchestration shell (v11.2 W1) -->
<template>
  <AuthenticatedPageShell
    title="Manage Users"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol md="12">
            <TableShell title="User table" :meta="`${totalRows} users`">
              <template #title-actions>
                <BBadge v-if="selectionCount > 0" variant="primary">
                  {{ selectionCount }} selected
                </BBadge>
              </template>
              <template #actions>
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
              </template>

              <!-- Filter presets row -->
              <template #toolbar>
                <BRow v-if="filterPresets.presets.value.length > 0 || hasActiveFilters" class="g-2">
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
                        @click="savePresetModalOpen = true"
                      >
                        <i class="bi bi-plus-lg" /> Save Preset
                      </BButton>
                    </div>
                  </BCol>
                </BRow>

                <BRow class="g-2 mt-1">
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

                <BRow class="g-2 mt-1">
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

                <BRow v-if="hasActiveFilters" class="g-2 mt-1">
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
              </template>

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
                  class="d-none d-md-table"
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
                      aria-label="Select all users on this page"
                      @update:model-value="toggleSelectAllOnPage"
                    />
                  </template>
                  <template #cell-select="{ row }">
                    <BFormCheckbox
                      :model-value="isSelected(row.user_id)"
                      :aria-label="`Select user ${row.user_name}`"
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
                        :aria-label="`Edit user ${row.user_name}`"
                        @click="editUser(row)"
                      >
                        <i class="bi bi-pen" aria-hidden="true" />
                      </BButton>
                      <BButton
                        v-b-tooltip.hover.top
                        size="sm"
                        class="me-1 btn-xs"
                        title="Delete user"
                        :aria-label="`Delete user ${row.user_name}`"
                        @click="promptDelete(row)"
                      >
                        <i class="bi bi-x" aria-hidden="true" />
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
                <UserAdminMobileRows
                  v-if="!isBusy && users.length > 0"
                  class="d-md-none"
                  :items="users"
                  :selected-ids="getSelectedArray()"
                  @toggle-select="handleRowSelect"
                  @edit="editUser"
                  @delete="promptDelete"
                />
              </div>
            </TableShell>
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

        <SavePresetModal v-model:visible="savePresetModalOpen" @confirm="confirmSavePreset" />
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import { defineComponent } from 'vue';

import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

import UserBulkActionToolbar from './components/UserBulkActionToolbar.vue';
import UserUpdateModal from './components/UserUpdateModal.vue';
import UserDeleteConfirmModal from './components/UserDeleteConfirmModal.vue';
import UserBulkApproveModal from './components/UserBulkApproveModal.vue';
import UserBulkDeleteModal from './components/UserBulkDeleteModal.vue';
import UserBulkRoleModal from './components/UserBulkRoleModal.vue';
import UserAdminMobileRows from './components/UserAdminMobileRows.vue';
import SavePresetModal from './components/SavePresetModal.vue';

// Page-level composition (issue #346, Wave 2 Task 6 — users domain). Owns
// only the wiring between useUserData/useUserMutations/useBulkUserActions/
// useUserModals/useUserTablePresentation; each of those composables remains
// the single owner of its own responsibility.
import { useManageUserPage } from './composables/useManageUserPage';

export default defineComponent({
  name: 'ManageUser',
  components: {
    AuthenticatedPageShell,
    TableShell,
    GenericTable,
    TablePaginationControls,
    UserBulkActionToolbar,
    UserUpdateModal,
    UserDeleteConfirmModal,
    UserBulkApproveModal,
    UserBulkDeleteModal,
    UserBulkRoleModal,
    UserAdminMobileRows,
    SavePresetModal,
  },
  setup() {
    return useManageUserPage();
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
