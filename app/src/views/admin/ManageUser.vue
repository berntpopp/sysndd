<!-- views/admin/ManageUser.vue -->
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
                  <!-- Bulk action buttons (only visible when selection > 0) -->
                  <template v-if="selectionCount > 0">
                    <BButton
                      v-b-tooltip.hover
                      size="sm"
                      variant="success"
                      class="me-1"
                      title="Approve selected users"
                      @click="handleBulkApprove"
                    >
                      <i class="bi bi-check-circle" /> Approve
                    </BButton>
                    <BButton
                      v-b-tooltip.hover
                      size="sm"
                      variant="primary"
                      class="me-1"
                      title="Assign role to selected users"
                      @click="showBulkRoleModal"
                    >
                      <i class="bi bi-person-badge" /> Role
                    </BButton>
                    <BButton
                      v-b-tooltip.hover
                      size="sm"
                      variant="danger"
                      class="me-1"
                      title="Delete selected users"
                      @click="handleBulkDelete"
                    >
                      <i class="bi bi-trash" /> Delete
                    </BButton>
                    <BButton
                      v-b-tooltip.hover
                      size="sm"
                      variant="link"
                      title="Clear selection"
                      @click="clearSelection"
                    >
                      <i class="bi bi-x-lg" />
                    </BButton>
                  </template>
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
                    :variant="removeFiltersButtonVariant"
                    :title="removeFiltersButtonTitle"
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
                  :options="roleFilterOptions"
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
                  :options="approvalFilterOptions"
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
                      @click="editUser(row, $event.target)"
                    >
                      <i class="bi bi-pen" />
                    </BButton>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="me-1 btn-xs"
                      title="Delete user"
                      @click="promptDeleteUser(row, $event.target)"
                    >
                      <i class="bi bi-x" />
                    </BButton>
                  </div>
                </template>
                <template #cell-user_role="{ row }">
                  <BBadge
                    :variant="getRoleBadgeVariant(row.user_role)"
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

      <BModal
        :id="deleteUserModal.id"
        v-model="showDeleteModal"
        header-bg-variant="danger"
        header-text-variant="light"
        ok-title="Delete User"
        ok-variant="danger"
        cancel-title="Cancel"
        cancel-variant="outline-secondary"
        @ok="confirmDeleteUser"
      >
        <template #title>
          <i class="bi bi-exclamation-triangle-fill me-2" />
          Confirm Deletion
        </template>
        <div class="text-center py-3">
          <i class="bi bi-person-x-fill text-danger" style="font-size: 3rem" />
          <p class="mt-3 mb-0">
            Are you sure you want to delete the user
            <strong class="text-danger">{{ userToDelete.user_name }}</strong
            >?
          </p>
          <p class="text-muted small mt-2">This action cannot be undone.</p>
        </div>
      </BModal>

      <BModal
        :id="updateUserModal.id"
        v-model="showUpdateModal"
        size="lg"
        header-bg-variant="primary"
        header-text-variant="light"
        ok-title="Save Changes"
        ok-variant="primary"
        cancel-title="Cancel"
        cancel-variant="outline-secondary"
        @ok="onUpdateSubmit"
      >
        <template #title>
          <i class="bi bi-person-gear me-2" />
          Edit User: {{ userToUpdate.user_name }}
        </template>
        <form @submit.prevent="onUpdateSubmit">
          <!-- Account Information Section -->
          <div class="mb-4">
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-person-badge me-2" />Account Information
            </h6>
            <BRow>
              <BCol md="6">
                <BFormGroup label="Username" label-for="input-user_name" class="mb-3">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-at" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-user_name"
                      v-model="userToUpdate.user_name"
                      type="text"
                      placeholder="Enter username"
                      :state="userNameMeta.touched ? (userNameError ? false : true) : null"
                    />
                  </BInputGroup>
                  <BFormInvalidFeedback v-if="userNameError" :state="false">
                    {{ userNameError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
              <BCol md="6">
                <BFormGroup label="Email" label-for="input-email" class="mb-3">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-envelope" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-email"
                      v-model="userToUpdate.email"
                      type="email"
                      placeholder="user@example.com"
                      :state="emailMeta.touched ? (emailError ? false : true) : null"
                    />
                  </BInputGroup>
                  <BFormInvalidFeedback v-if="emailError" :state="false">
                    {{ emailError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
            </BRow>
            <BRow>
              <BCol md="6">
                <BFormGroup label="Abbreviation" label-for="input-abbreviation" class="mb-3">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-hash" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-abbreviation"
                      v-model="userToUpdate.abbreviation"
                      type="text"
                      placeholder="XX"
                      maxlength="5"
                      :state="abbreviationMeta.touched ? (abbreviationError ? false : true) : null"
                    />
                  </BInputGroup>
                  <BFormInvalidFeedback v-if="abbreviationError" :state="false">
                    {{ abbreviationError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
              <BCol md="6">
                <BFormGroup label="ORCID" label-for="input-orcid" class="mb-3">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-link-45deg" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-orcid"
                      v-model="userToUpdate.orcid"
                      type="text"
                      placeholder="0000-0000-0000-0000"
                      :state="orcidMeta.touched ? (orcidError ? false : true) : null"
                    />
                  </BInputGroup>
                  <BFormInvalidFeedback v-if="orcidError" :state="false">
                    {{ orcidError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
            </BRow>
          </div>

          <!-- Personal Information Section -->
          <div class="mb-4">
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-person me-2" />Personal Information
            </h6>
            <BRow>
              <BCol md="6">
                <BFormGroup label="First Name" label-for="input-first_name" class="mb-3">
                  <BFormInput
                    id="input-first_name"
                    v-model="userToUpdate.first_name"
                    type="text"
                    placeholder="First name"
                    :state="firstNameMeta.touched ? (firstNameError ? false : true) : null"
                  />
                  <BFormInvalidFeedback v-if="firstNameError">
                    {{ firstNameError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
              <BCol md="6">
                <BFormGroup label="Family Name" label-for="input-family_name" class="mb-3">
                  <BFormInput
                    id="input-family_name"
                    v-model="userToUpdate.family_name"
                    type="text"
                    placeholder="Family name"
                    :state="familyNameMeta.touched ? (familyNameError ? false : true) : null"
                  />
                  <BFormInvalidFeedback v-if="familyNameError">
                    {{ familyNameError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
            </BRow>
          </div>

          <!-- Role & Status Section -->
          <div class="mb-3">
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-shield-check me-2" />Role & Status
            </h6>
            <BRow>
              <BCol md="6">
                <BFormGroup label="Role" label-for="input-user_role" class="mb-3">
                  <BFormSelect
                    id="input-user_role"
                    v-model="userToUpdate.user_role"
                    :options="roleSelectOptions"
                    :state="userRoleMeta.touched ? (userRoleError ? false : true) : null"
                  />
                  <BFormInvalidFeedback v-if="userRoleError">
                    {{ userRoleError }}
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
              <BCol md="6">
                <BFormGroup label="Account Status" label-for="input-approved" class="mb-3">
                  <div class="d-flex flex-column gap-2">
                    <!-- Current status display -->
                    <div class="d-flex align-items-center">
                      <span class="text-muted me-2">Current:</span>
                      <span
                        class="badge"
                        :class="userToUpdate.approved ? 'bg-success' : 'bg-warning text-dark'"
                      >
                        <i
                          :class="
                            userToUpdate.approved ? 'bi bi-check-circle-fill' : 'bi bi-clock-fill'
                          "
                          class="me-1"
                        />
                        {{ userToUpdate.approved ? 'Approved' : 'Pending' }}
                      </span>
                    </div>
                    <!-- Toggle buttons -->
                    <BButtonGroup size="sm">
                      <BButton
                        :variant="userToUpdate.approved ? 'success' : 'outline-success'"
                        @click="userToUpdate.approved = true"
                      >
                        <i class="bi bi-check-lg me-1" />
                        Approve
                      </BButton>
                      <BButton
                        :variant="!userToUpdate.approved ? 'warning' : 'outline-warning'"
                        @click="userToUpdate.approved = false"
                      >
                        <i class="bi bi-clock me-1" />
                        Set Pending
                      </BButton>
                    </BButtonGroup>
                    <small class="text-muted">
                      {{
                        userToUpdate.approved
                          ? 'User can access the system.'
                          : 'User cannot log in until approved.'
                      }}
                    </small>
                  </div>
                </BFormGroup>
              </BCol>
            </BRow>
            <BRow>
              <BCol>
                <BFormGroup label="Comment" label-for="input-comment" class="mb-0">
                  <BFormTextarea
                    id="input-comment"
                    v-model="userToUpdate.comment"
                    placeholder="Add notes about this user..."
                    rows="2"
                  />
                </BFormGroup>
              </BCol>
            </BRow>
          </div>

          <!-- Password Reset Section (Admin Only) -->
          <div class="mb-3">
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-key me-2" />Password Reset
            </h6>
            <BAlert variant="info" :model-value="true" class="mb-3">
              <i class="bi bi-info-circle me-2" />
              As an administrator, you can set a new password for this user. Password requirements:
              8+ characters, uppercase, lowercase, number, and special character (!@#$%^&*).
            </BAlert>
            <BRow>
              <BCol md="6">
                <BFormGroup label="New Password" label-for="input-new-password" class="mb-3">
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-lock" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-new-password"
                      v-model="passwordChange.newPassword"
                      :type="passwordChange.showPassword ? 'text' : 'password'"
                      placeholder="Enter new password"
                      :state="passwordValidation.isValid"
                      autocomplete="new-password"
                    />
                    <template #append>
                      <BButton
                        variant="outline-secondary"
                        @click="passwordChange.showPassword = !passwordChange.showPassword"
                      >
                        <i :class="passwordChange.showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
                      </BButton>
                    </template>
                  </BInputGroup>
                  <div v-if="passwordChange.newPassword" class="mt-2">
                    <small
                      v-for="(rule, key) in passwordValidation.rules"
                      :key="key"
                      class="d-block"
                      :class="rule.valid ? 'text-success' : 'text-danger'"
                    >
                      <i
                        :class="rule.valid ? 'bi bi-check-circle' : 'bi bi-x-circle'"
                        class="me-1"
                      />
                      {{ rule.label }}
                    </small>
                  </div>
                </BFormGroup>
              </BCol>
              <BCol md="6">
                <BFormGroup
                  label="Confirm Password"
                  label-for="input-confirm-password"
                  class="mb-3"
                >
                  <BInputGroup>
                    <template #prepend>
                      <BInputGroupText><i class="bi bi-lock-fill" /></BInputGroupText>
                    </template>
                    <BFormInput
                      id="input-confirm-password"
                      v-model="passwordChange.confirmPassword"
                      :type="passwordChange.showPassword ? 'text' : 'password'"
                      placeholder="Confirm new password"
                      :state="
                        passwordChange.confirmPassword
                          ? passwordChange.newPassword === passwordChange.confirmPassword
                          : null
                      "
                      autocomplete="new-password"
                    />
                  </BInputGroup>
                  <BFormInvalidFeedback
                    v-if="
                      passwordChange.confirmPassword &&
                      passwordChange.newPassword !== passwordChange.confirmPassword
                    "
                    :state="false"
                  >
                    Passwords do not match
                  </BFormInvalidFeedback>
                </BFormGroup>
              </BCol>
            </BRow>
            <BRow>
              <BCol class="d-flex justify-content-between">
                <BButton variant="outline-secondary" @click="generatePassword">
                  <i class="bi bi-shuffle me-1" />
                  Generate Password
                </BButton>
                <BButton
                  variant="warning"
                  :disabled="
                    !passwordValidation.isValid ||
                    passwordChange.newPassword !== passwordChange.confirmPassword ||
                    passwordChange.isChanging
                  "
                  @click="changeUserPassword"
                >
                  <BSpinner v-if="passwordChange.isChanging" small class="me-1" />
                  <i v-else class="bi bi-key-fill me-1" />
                  {{ passwordChange.isChanging ? 'Changing...' : 'Change Password' }}
                </BButton>
              </BCol>
            </BRow>
          </div>
        </form>
      </BModal>

      <!-- Bulk Approve Confirmation Modal -->
      <BModal
        v-model="showBulkApproveModal"
        title="Approve Users"
        ok-variant="success"
        ok-title="Approve"
        cancel-title="Cancel"
        @ok="confirmBulkApprove"
      >
        <p>You are about to approve {{ getSelectedArray().length }} users:</p>
        <div class="border rounded p-2 mb-3 bg-light" style="max-height: 200px; overflow-y: auto">
          <div v-for="username in bulkApproveUsernames" :key="username" class="small">
            {{ username }}
          </div>
        </div>
        <p class="text-muted small">This action will grant these users access to the system.</p>
      </BModal>

      <!-- Bulk Role Assignment Modal -->
      <BModal
        v-model="showBulkRoleModalVisible"
        title="Assign Role"
        ok-variant="primary"
        ok-title="Assign Role"
        cancel-title="Cancel"
        :ok-disabled="!bulkRoleSelection"
        @ok="confirmBulkRoleAssignment"
      >
        <p>Assign role to {{ getSelectedArray().length }} users:</p>
        <div class="border rounded p-2 mb-3 bg-light" style="max-height: 150px; overflow-y: auto">
          <div v-for="username in bulkRoleUsernames" :key="username" class="small">
            {{ username }}
          </div>
        </div>
        <BFormGroup label="Select Role:" label-for="bulk-role-select">
          <BFormSelect
            id="bulk-role-select"
            v-model="bulkRoleSelection"
            :options="[
              { value: '', text: 'Select a role...', disabled: true },
              { value: 'Curator', text: 'Curator' },
              { value: 'Reviewer', text: 'Reviewer' },
              { value: 'Administrator', text: 'Administrator' },
            ]"
          />
        </BFormGroup>
      </BModal>

      <!-- Bulk Delete Confirmation Modal -->
      <BModal
        v-model="showBulkDeleteModal"
        title="Delete Users"
        ok-variant="danger"
        ok-title="Delete"
        cancel-title="Cancel"
        :ok-disabled="deleteConfirmText !== 'DELETE'"
        @ok="confirmBulkDelete"
      >
        <p class="text-danger fw-bold">This action cannot be undone.</p>
        <p>You are about to delete {{ bulkDeleteUsernames.length }} users:</p>
        <div class="border rounded p-2 mb-3 bg-light" style="max-height: 200px; overflow-y: auto">
          <div v-for="username in bulkDeleteUsernames" :key="username" class="small">
            {{ username }}
          </div>
        </div>
        <BFormGroup label="Type DELETE to confirm:" label-for="delete-confirm-input">
          <BFormInput
            id="delete-confirm-input"
            v-model="deleteConfirmText"
            placeholder="DELETE"
            autocomplete="off"
          />
        </BFormGroup>
      </BModal>
    </BContainer>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, email } from '@vee-validate/rules';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import useToast from '@/composables/useToast';
import {
  useUrlParsing,
  useTableData,
  useExcelExport,
  useBulkSelection,
  useFilterPresets,
} from '@/composables';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Define validation rules globally
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);

// Module-level variables to track API calls across component remounts
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null;

export default {
  name: 'ManageUser',
  components: {
    GenericTable,
    TablePaginationControls,
  },
  setup() {
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const { isExporting, exportToExcel } = useExcelExport();

    const tableData = useTableData({
      pageSizeInput: 25,
      sortInput: '+user_name',
      pageAfterInput: '0',
    });

    // Bulk selection state (20 user limit per context decisions)
    const bulkSelection = useBulkSelection(20);

    // Filter presets for quick access to saved filters
    const filterPresets = useFilterPresets('sysndd-manage-user-presets');

    // Filter object structure for user table
    const filter = ref({
      any: { content: null, join_char: null, operator: 'contains' },
      user_name: { content: null, join_char: null, operator: 'contains' },
      email: { content: null, join_char: null, operator: 'contains' },
      user_role: { content: null, join_char: ',', operator: 'any' },
      approved: { content: null, join_char: null, operator: 'equals' },
      abbreviation: { content: null, join_char: null, operator: 'contains' },
      first_name: { content: null, join_char: null, operator: 'contains' },
      family_name: { content: null, join_char: null, operator: 'contains' },
      orcid: { content: null, join_char: null, operator: 'contains' },
      comment: { content: null, join_char: null, operator: 'contains' },
    });

    // Setup form validation with vee-validate 4
    const { handleSubmit, resetForm, setValues } = useForm();

    // Define fields with validation
    const {
      value: userName,
      errorMessage: userNameError,
      meta: userNameMeta,
    } = useField('user_name', 'required|min:2|max:50');

    const {
      value: userEmail,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const { value: orcid, errorMessage: orcidError, meta: orcidMeta } = useField('orcid');

    const {
      value: abbreviation,
      errorMessage: abbreviationError,
      meta: abbreviationMeta,
    } = useField('abbreviation', 'required');

    const {
      value: firstName,
      errorMessage: firstNameError,
      meta: firstNameMeta,
    } = useField('first_name', 'required|min:2|max:50');

    const {
      value: familyName,
      errorMessage: familyNameError,
      meta: familyNameMeta,
    } = useField('family_name', 'required|min:2|max:50');

    const {
      value: userRole,
      errorMessage: userRoleError,
      meta: userRoleMeta,
    } = useField('user_role', 'required');

    return {
      ...tableData,
      filter,
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      isExporting,
      exportToExcel,
      handleSubmit,
      resetForm,
      setValues,
      userName,
      userNameError,
      userNameMeta,
      userEmail,
      emailError,
      emailMeta,
      orcid,
      orcidError,
      orcidMeta,
      abbreviation,
      abbreviationError,
      abbreviationMeta,
      firstName,
      firstNameError,
      firstNameMeta,
      familyName,
      familyNameError,
      familyNameMeta,
      userRole,
      userRoleError,
      userRoleMeta,
      ...bulkSelection, // Spreads: selectedIds, selectionCount, isSelected, toggleSelection, clearSelection, getSelectedArray, selectMultiple
      filterPresets,
    };
  },
  data() {
    return {
      // Flag to prevent watchers from triggering during initialization
      isInitializing: true,
      // Debounce timer for loadData to prevent duplicate calls
      loadDataDebounceTimer: null,
      // Pagination state not in useTableData
      totalPages: 0,
      // User-specific data
      role_options: [],
      user_options: [],
      users: [],
      fields: [
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
        { key: 'actions', label: 'Actions', class: 'text-center' },
      ],
      showDeleteModal: false,
      showUpdateModal: false,
      userToDelete: {},
      userToUpdate: {},
      deleteUserModal: { id: 'delete-usermodal', title: '', content: [] },
      updateUserModal: { id: 'update-usermodal', title: '', content: [] },
      // Bulk action modals
      showBulkApproveModal: false,
      bulkApproveUsernames: [],
      showBulkDeleteModal: false,
      bulkDeleteUsernames: [],
      deleteConfirmText: '',
      showBulkRoleModalVisible: false,
      bulkRoleSelection: '',
      bulkRoleUsernames: [],
      // Password change state
      passwordChange: {
        newPassword: '',
        confirmPassword: '',
        showPassword: false,
        isChanging: false,
      },
    };
  },
  computed: {
    roleFilterOptions() {
      return this.role_options;
    },
    approvalFilterOptions() {
      return [
        { value: '1', text: 'Approved' },
        { value: '0', text: 'Pending' },
      ];
    },
    hasActiveFilters() {
      return Object.values(this.filter).some((f) => f.content !== null && f.content !== '');
    },
    activeFilters() {
      const filters = [];
      if (this.filter.any.content)
        filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
      if (this.filter.user_role.content)
        filters.push({ key: 'user_role', label: 'Role', value: this.filter.user_role.content });
      if (this.filter.approved.content !== null) {
        filters.push({
          key: 'approved',
          label: 'Status',
          value: this.filter.approved.content === '1' ? 'Approved' : 'Pending',
        });
      }
      return filters;
    },
    roleSelectOptions() {
      return [
        { value: 'Administrator', text: 'Administrator' },
        { value: 'Curator', text: 'Curator' },
        { value: 'Reviewer', text: 'Reviewer' },
        { value: 'Viewer', text: 'Viewer' },
      ];
    },
    // Check if all users on current page are selected
    allOnPageSelected() {
      if (this.users.length === 0) return false;
      return this.users.every((user) => this.isSelected(user.user_id));
    },
    removeFiltersButtonVariant() {
      return this.hasActiveFilters ? 'outline-danger' : 'outline-secondary';
    },
    removeFiltersButtonTitle() {
      return this.hasActiveFilters ? 'Clear all filters' : 'No active filters';
    },
    passwordValidation() {
      const password = this.passwordChange.newPassword;
      const rules = {
        minLength: {
          label: 'At least 8 characters',
          valid: password.length >= 8,
        },
        hasUppercase: {
          label: 'At least one uppercase letter',
          valid: /[A-Z]/.test(password),
        },
        hasLowercase: {
          label: 'At least one lowercase letter',
          valid: /[a-z]/.test(password),
        },
        hasNumber: {
          label: 'At least one number',
          valid: /[0-9]/.test(password),
        },
        hasSpecial: {
          label: 'At least one special character (!@#$%^&*)',
          valid: /[!@#$%^&*]/.test(password),
        },
      };
      const isValid = password.length > 0 && Object.values(rules).every((r) => r.valid);
      return { rules, isValid: password.length > 0 ? isValid : null };
    },
  },
  watch: {
    filter: {
      handler() {
        if (this.isInitializing) return;
        this.filtered();
      },
      deep: true,
    },
    sortBy: {
      handler() {
        if (this.isInitializing) return;
        this.handleSortByOrDescChange();
      },
      deep: true,
    },
  },
  mounted() {
    // Parse URL params
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('sort')) {
      const sort_object = this.sortStringToVariables(urlParams.get('sort'));
      this.sortBy = sort_object.sortBy;
      this.sort = urlParams.get('sort');
    }
    if (urlParams.get('filter')) {
      this.filter = this.filterStrToObj(urlParams.get('filter'), this.filter);
      this.filter_string = urlParams.get('filter');
    }
    if (urlParams.get('page_after')) {
      this.currentItemID = parseInt(urlParams.get('page_after'), 10) || 0;
    }
    if (urlParams.get('page_size')) {
      this.perPage = parseInt(urlParams.get('page_size'), 10) || 25;
    }

    this.loadRoleList();
    this.loadUserList();

    // Initialize default presets if none exist
    if (this.filterPresets.presets.value.length === 0) {
      // Add common presets
      this.filterPresets.savePreset('Pending', {
        any: { content: null, join_char: null, operator: 'contains' },
        user_role: { content: null, join_char: ',', operator: 'any' },
        approved: { content: '0', join_char: null, operator: 'equals' },
      });
      this.filterPresets.savePreset('Curators', {
        any: { content: null, join_char: null, operator: 'contains' },
        user_role: { content: 'Curator', join_char: ',', operator: 'any' },
        approved: { content: null, join_char: null, operator: 'equals' },
      });
    }

    this.$nextTick(() => {
      this.loadData();
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });
  },
  methods: {
    toggleSelectAllOnPage() {
      if (this.allOnPageSelected) {
        // Deselect all on current page
        this.users.forEach((user) => {
          if (this.isSelected(user.user_id)) {
            this.toggleSelection(user.user_id);
          }
        });
      } else {
        // Select all on current page (respects 20 limit)
        const pageUserIds = this.users.map((u) => u.user_id);
        const added = this.selectMultiple(pageUserIds);
        if (added < pageUserIds.length && this.selectionCount >= 20) {
          this.makeToast(
            `Selection limited to 20 users. ${added} users added.`,
            'Selection Limit',
            'warning'
          );
        }
      }
    },
    handleRowSelect(userId) {
      const success = this.toggleSelection(userId);
      if (!success) {
        this.makeToast(
          'Maximum 20 users can be selected at once',
          'Selection Limit Reached',
          'warning'
        );
      }
    },
    handleBulkApprove() {
      const userIds = this.getSelectedArray();
      if (userIds.length === 0) {
        this.makeToast('No users selected', 'Bulk Approve', 'warning');
        return;
      }

      // Get usernames for display (USR-06: show all selected items)
      const selectedUsers = this.users.filter((u) => userIds.includes(u.user_id));
      this.bulkApproveUsernames = selectedUsers.map((u) => u.user_name);

      // Show Bootstrap modal
      this.showBulkApproveModal = true;
    },
    async confirmBulkApprove() {
      const userIds = this.getSelectedArray();

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_approve`;
      try {
        const response = await this.axios.post(
          apiUrl,
          {
            user_ids: userIds,
          },
          {
            headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
          }
        );

        if (response.status === 200) {
          this.makeToast(
            `Successfully approved ${response.data.processed || userIds.length} users`,
            'Bulk Approve Complete',
            'success',
            true,
            5000
          );
          this.clearSelection();
          this.loadData();
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.message || error.response?.data?.error || 'Unknown error';
        this.makeToast(errorMsg, 'Bulk Approve Failed', 'danger');
      }
    },
    showBulkRoleModal() {
      const userIds = this.getSelectedArray();
      if (userIds.length === 0) {
        this.makeToast('No users selected', 'Assign Role', 'warning');
        return;
      }

      // Get usernames for display (USR-06: show all selected items)
      const selectedUsers = this.users.filter((u) => userIds.includes(u.user_id));
      this.bulkRoleUsernames = selectedUsers.map((u) => u.user_name);
      this.bulkRoleSelection = ''; // Reset selection

      // Show Bootstrap modal with dropdown (NOT prompt)
      this.showBulkRoleModalVisible = true;
    },
    async confirmBulkRoleAssignment() {
      const userIds = this.getSelectedArray();
      const selectedRole = this.bulkRoleSelection;

      if (!selectedRole) {
        this.makeToast('Please select a role', 'Invalid Role', 'warning');
        return;
      }

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_assign_role`;
      try {
        const response = await this.axios.post(
          apiUrl,
          {
            user_ids: userIds,
            role: selectedRole,
          },
          {
            headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
          }
        );

        if (response.status === 200) {
          this.makeToast(
            `Successfully assigned ${selectedRole} role to ${response.data.processed || userIds.length} users`,
            'Bulk Role Assignment Complete',
            'success',
            true,
            5000
          );
          this.clearSelection();
          this.loadData();
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.message || error.response?.data?.error || 'Unknown error';
        this.makeToast(errorMsg, 'Bulk Role Assignment Failed', 'danger');
      }
    },
    handleBulkDelete() {
      const userIds = this.getSelectedArray();
      if (userIds.length === 0) {
        this.makeToast('No users selected', 'Bulk Delete', 'warning');
        return;
      }

      // Get selected user details for display and admin check
      const selectedUsers = this.users.filter((u) => userIds.includes(u.user_id));

      // Frontend validation: Block if admins selected
      const adminUsers = selectedUsers.filter((u) => u.user_role === 'Administrator');
      if (adminUsers.length > 0) {
        this.makeToast(
          `Cannot delete: selection contains ${adminUsers.length} admin user(s)`,
          'Delete Blocked',
          'danger'
        );
        return;
      }

      // Store usernames for modal display (USR-06: show all selected items)
      this.bulkDeleteUsernames = selectedUsers.map((u) => u.user_name);
      this.deleteConfirmText = ''; // Reset confirm input

      // Show Bootstrap modal
      this.showBulkDeleteModal = true;
    },
    async confirmBulkDelete() {
      const userIds = this.getSelectedArray();

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/bulk_delete`;
      try {
        const response = await this.axios.post(
          apiUrl,
          {
            user_ids: userIds,
          },
          {
            headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
          }
        );

        if (response.status === 200) {
          this.makeToast(
            `Successfully deleted ${response.data.processed || userIds.length} users`,
            'Bulk Delete Complete',
            'success',
            true,
            5000
          );
          this.clearSelection();
          this.loadData();
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.message || error.response?.data?.error || 'Unknown error';
        this.makeToast(errorMsg, 'Bulk Delete Failed', 'danger');
      }
    },
    // Update browser URL with current table state
    updateBrowserUrl() {
      if (this.isInitializing) return;
      const searchParams = new URLSearchParams();
      if (this.sort) searchParams.set('sort', this.sort);
      if (this.filter_string) searchParams.set('filter', this.filter_string);
      if (this.currentItemID > 0) searchParams.set('page_after', String(this.currentItemID));
      searchParams.set('page_size', String(this.perPage));

      const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
      window.history.replaceState({ ...window.history.state }, '', newUrl);
    },
    // Override filtered to call loadData
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);
      if (filter_string_loc !== this.filter_string) {
        this.filter_string = filter_string_loc;
      }
      this.loadData();
    },
    // Override handlePageChange
    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
      } else if (value === this.totalPages) {
        this.currentItemID = Number(this.lastItemID) || 0;
      } else if (value > this.currentPage) {
        this.currentItemID = Number(this.nextItemID) || 0;
      } else if (value < this.currentPage) {
        this.currentItemID = Number(this.prevItemID) || 0;
      }
      this.filtered();
    },
    // Override handlePerPageChange
    handlePerPageChange(newPerPage) {
      this.perPage = parseInt(newPerPage, 10);
      this.currentItemID = 0;
      this.filtered();
    },
    // Override handleSortByOrDescChange
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : '';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';
      const isDesc = sortOrder === 'desc';
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },
    // Override removeFilters
    removeFilters() {
      Object.keys(this.filter).forEach((key) => {
        if (
          this.filter[key] &&
          typeof this.filter[key] === 'object' &&
          'content' in this.filter[key]
        ) {
          this.filter[key].content = null;
        }
      });
      this.filtered();
    },
    // Clear a single filter
    clearFilter(key) {
      if (this.filter[key]) {
        this.filter[key].content = null;
      }
      this.filtered();
    },
    // Load data with debouncing
    loadData() {
      if (this.loadDataDebounceTimer) {
        clearTimeout(this.loadDataDebounceTimer);
      }
      this.loadDataDebounceTimer = setTimeout(() => {
        this.loadDataDebounceTimer = null;
        this.doLoadData();
      }, 50);
    },
    // Actual data loading
    async doLoadData() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const now = Date.now();

      // Prevent duplicate API calls
      if (moduleLastApiParams === urlParam && now - moduleLastApiCallTime < 500) {
        if (moduleLastApiResponse) {
          this.applyApiResponse(moduleLastApiResponse);
        }
        return;
      }

      if (moduleApiCallInProgress && moduleLastApiParams === urlParam) return;

      moduleLastApiParams = urlParam;
      moduleLastApiCallTime = now;
      moduleApiCallInProgress = true;
      this.isBusy = true;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        moduleApiCallInProgress = false;
        moduleLastApiResponse = response.data;
        this.applyApiResponse(response.data);
        this.updateBrowserUrl();
        this.isBusy = false;
      } catch (e) {
        moduleApiCallInProgress = false;
        this.makeToast(e, 'Error', 'danger');
        this.isBusy = false;
      }
    },
    // Apply API response data
    applyApiResponse(data) {
      this.users = data.data;
      this.totalRows = data.meta[0].totalItems;
      this.$nextTick(() => {
        this.currentPage = data.meta[0].currentPage;
      });
      this.totalPages = data.meta[0].totalPages;
      this.prevItemID = Number(data.meta[0].prevItemID) || 0;
      this.currentItemID = Number(data.meta[0].currentItemID) || 0;
      this.nextItemID = Number(data.meta[0].nextItemID) || 0;
      this.lastItemID = Number(data.meta[0].lastItemID) || 0;
      this.executionTime = data.meta[0].executionTime;

      // Update fields from API fspec if available
      // API fspec has arrays for key/label (e.g., ["user_id"]), extract single values
      if (data.meta[0].fspec) {
        const actionsField = this.fields.find((f) => f.key === 'actions');
        const transformedFields = data.meta[0].fspec.map((field) => ({
          ...field,
          key: Array.isArray(field.key) ? field.key[0] : field.key,
          label: Array.isArray(field.label) ? field.label[0] : field.label,
          sortable: Array.isArray(field.sortable) ? field.sortable[0] : field.sortable,
          filterable: Array.isArray(field.filterable) ? field.filterable[0] : field.filterable,
          class: Array.isArray(field.class) ? field.class[0] : field.class,
        }));
        this.fields = [...transformedFields, actionsField].filter(Boolean);
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    },
    // Handle Excel export
    handleExport() {
      this.exportToExcel(this.users, {
        filename: `users_export_${new Date().toISOString().split('T')[0]}`,
        sheetName: 'Users',
        headers: {
          user_name: 'User Name',
          email: 'Email',
          user_role: 'Role',
          approved: 'Approved',
          abbreviation: 'Abbreviation',
          first_name: 'First Name',
          family_name: 'Family Name',
          orcid: 'ORCID',
          comment: 'Comment',
          created_at: 'Created',
        },
      });
    },
    // Handle sort update
    handleSortUpdate(newSortBy) {
      this.sortBy = newSortBy;
      this.handleSortByOrDescChange();
    },
    // Get badge variant for user role
    getRoleBadgeVariant(role) {
      const variants = {
        Administrator: 'danger',
        Curator: 'primary',
        Reviewer: 'info',
        Viewer: 'secondary',
      };
      return variants[role] || 'secondary';
    },
    // Get icon class for user role
    getRoleIcon(role) {
      const icons = {
        Administrator: 'bi bi-shield-fill-check',
        Curator: 'bi bi-pencil-fill',
        Reviewer: 'bi bi-eye-fill',
        Viewer: 'bi bi-person-fill',
      };
      return icons[role] || 'bi bi-person-fill';
    },
    onUpdateSubmit() {
      this.handleSubmit(() => {
        this.updateUserData();
      })();
    },
    async loadRoleList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/role_list`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.role_options = response.data.map((item) => ({ value: item.role, text: item.role }));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadUserList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/list?roles=Curator,Reviewer`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.user_options = response.data.map((item) => ({
          value: item.user_id,
          text: item.user_name,
          role: item.user_role,
        }));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    promptDeleteUser(item, _button) {
      this.deleteUserModal.title = `${item.user_name}`;
      this.userToDelete = item;
      this.showDeleteModal = true;
    },
    async confirmDeleteUser() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/delete`;
      try {
        const response = await this.axios.delete(apiUrl, {
          data: { user_id: this.userToDelete.user_id },
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        if (response.status === 200) {
          this.makeToast('User deleted successfully', 'Success', 'success');
          this.loadData(); // Reload table data after deletion
        } else {
          throw new Error('Failed to delete the user.');
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.showDeleteModal = false;
      this.userToDelete = {};
    },
    editUser(item, _button) {
      this.updateUserModal.title = `${item.user_name}`;
      this.userToUpdate = { ...item };
      // Sync vee-validate fields with the user data
      this.setValues({
        user_name: item.user_name,
        email: item.email,
        orcid: item.orcid,
        abbreviation: item.abbreviation,
        first_name: item.first_name,
        family_name: item.family_name,
        user_role: item.user_role,
      });
      // Reset password change fields
      this.passwordChange.newPassword = '';
      this.passwordChange.confirmPassword = '';
      this.passwordChange.showPassword = false;
      this.passwordChange.isChanging = false;
      this.showUpdateModal = true;
    },
    async updateUserData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/update`;
      // Only send the fields that should be updated, not the entire user object
      // Filter out null/undefined/empty values to avoid API issues
      const updatePayload = {
        user_id: this.userToUpdate.user_id,
        user_name: this.userToUpdate.user_name,
        email: this.userToUpdate.email,
        abbreviation: this.userToUpdate.abbreviation,
        first_name: this.userToUpdate.first_name,
        family_name: this.userToUpdate.family_name,
        user_role: this.userToUpdate.user_role,
        approved: this.userToUpdate.approved ? 1 : 0,
      };
      // Only include optional fields if they have values
      if (this.userToUpdate.orcid) {
        updatePayload.orcid = this.userToUpdate.orcid;
      }
      if (this.userToUpdate.comment) {
        updatePayload.comment = this.userToUpdate.comment;
      }
      try {
        const response = await this.axios.put(
          apiUrl,
          { user_details: updatePayload },
          {
            headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
          }
        );
        if (response.status === 200) {
          this.makeToast('User updated successfully', 'Success', 'success');
          this.loadData(); // Reload the table data
        } else {
          throw new Error('Failed to update the user.');
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.showUpdateModal = false;
      this.userToUpdate = {};
    },
    // Filter preset methods
    loadFilterPreset(name) {
      const presetFilter = this.filterPresets.loadPreset(name);
      if (presetFilter) {
        // Merge preset into current filter structure
        Object.keys(presetFilter).forEach((key) => {
          if (this.filter[key]) {
            this.filter[key] = presetFilter[key];
          }
        });
        this.filtered();
        this.makeToast(`Loaded preset: ${name}`, 'Filter Preset', 'info', true, 2000);
      }
    },
    deleteFilterPreset(name) {
      if (confirm(`Delete preset "${name}"?`)) {
        this.filterPresets.deletePreset(name);
        this.makeToast(`Deleted preset: ${name}`, 'Filter Preset', 'info', true, 2000);
      }
    },
    showSavePresetPrompt() {
      const name = prompt('Enter a name for this filter preset:');
      if (name && name.trim()) {
        // Save current filter state
        this.filterPresets.savePreset(name.trim(), JSON.parse(JSON.stringify(this.filter)));
        this.makeToast(`Saved preset: ${name.trim()}`, 'Filter Preset', 'success', true, 3000);
      }
    },
    generatePassword() {
      // Character sets that meet password requirements
      const lowercase = 'abcdefghijklmnopqrstuvwxyz';
      const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      const numbers = '0123456789';
      const special = '!@#$%^&*';

      // Ensure at least one character from each required set
      const requiredChars = [
        lowercase[Math.floor(Math.random() * lowercase.length)],
        uppercase[Math.floor(Math.random() * uppercase.length)],
        numbers[Math.floor(Math.random() * numbers.length)],
        special[Math.floor(Math.random() * special.length)],
      ];

      // Fill remaining length with random characters from all sets
      const allChars = lowercase + uppercase + numbers + special;
      const passwordLength = 16; // Strong password length
      const remainingLength = passwordLength - requiredChars.length;

      for (let i = 0; i < remainingLength; i++) {
        requiredChars.push(allChars[Math.floor(Math.random() * allChars.length)]);
      }

      // Shuffle the array using Fisher-Yates algorithm
      for (let i = requiredChars.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [requiredChars[i], requiredChars[j]] = [requiredChars[j], requiredChars[i]];
      }

      const generatedPassword = requiredChars.join('');

      // Set both password fields
      this.passwordChange.newPassword = generatedPassword;
      this.passwordChange.confirmPassword = generatedPassword;
      this.passwordChange.showPassword = true; // Show password so user can see/copy it

      this.makeToast(
        'Password generated. Make sure to copy it before saving.',
        'Password Generated',
        'info',
        true,
        5000
      );
    },
    async changeUserPassword() {
      if (!this.passwordValidation.isValid) {
        this.makeToast('Password does not meet requirements', 'Validation Error', 'warning');
        return;
      }
      if (this.passwordChange.newPassword !== this.passwordChange.confirmPassword) {
        this.makeToast('Passwords do not match', 'Validation Error', 'warning');
        return;
      }

      this.passwordChange.isChanging = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/update`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {
            user_id_pass_change: this.userToUpdate.user_id,
            old_pass: '', // Admin can change password without knowing old password
            new_pass_1: this.passwordChange.newPassword,
            new_pass_2: this.passwordChange.confirmPassword,
          },
          {
            headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
          }
        );

        if (response.status === 200) {
          this.makeToast(
            `Password changed successfully for ${this.userToUpdate.user_name}`,
            'Password Changed',
            'success',
            true,
            5000
          );
          // Reset password fields
          this.passwordChange.newPassword = '';
          this.passwordChange.confirmPassword = '';
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.message ||
          error.response?.data?.error ||
          'Failed to change password';
        this.makeToast(errorMsg, 'Password Change Failed', 'danger');
      } finally {
        this.passwordChange.isChanging = false;
      }
    },
  },
};
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
