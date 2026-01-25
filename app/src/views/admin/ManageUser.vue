<!-- views/admin/ManageUser.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <BRow>
                <BCol>
                  <h5 class="mb-1 text-start">
                    <strong>Manage Users</strong>
                    <BBadge variant="secondary" class="ms-2">{{ totalRows }} users</BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
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
                  Showing {{ (currentPage - 1) * perPage + 1 }}-{{ Math.min(currentPage * perPage, totalRows) }} of {{ totalRows }}
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
                <BButton
                  size="sm"
                  variant="link"
                  class="p-0"
                  @click="removeFilters"
                >
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
                <template #cell-approved="{ row }">
                  <BBadge :variant="row.approved ? 'success' : 'danger'">
                    {{ row.approved ? 'Approved' : 'Unapproved' }}
                  </BBadge>
                </template>
              </GenericTable>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <BModal
        :id="deleteUserModal.id"
        title="Confirm Deletion"
        ok-title="Delete"
        ok-variant="danger"
        cancel-title="Cancel"
        cancel-variant="secondary"
        @ok="confirmDeleteUser"
      >
        Are you sure you want to delete the user <strong>{{ userToDelete.user_name }}</strong>?
      </BModal>

      <BModal
        :id="updateUserModal.id"
        title="Update User"
        ok-title="Update"
        ok-variant="primary"
        cancel-title="Cancel"
        @ok="onUpdateSubmit"
      >
        <form @submit.prevent="onUpdateSubmit">
          <!-- User name -->
          <BFormGroup
            label="User name:"
            label-for="input-user_name"
          >
            <BFormInput
              id="input-user_name"
              v-model="userToUpdate.user_name"
              type="text"
              :state="userNameMeta.touched ? (userNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="userNameError">
              {{ userNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Email -->
          <BFormGroup
            label="E-mail:"
            label-for="input-email"
          >
            <BFormInput
              id="input-email"
              v-model="userToUpdate.email"
              type="email"
              :state="emailMeta.touched ? (emailError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="emailError">
              {{ emailError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- ORCID -->
          <BFormGroup
            label="ORCID:"
            label-for="input-orcid"
          >
            <BFormInput
              id="input-orcid"
              v-model="userToUpdate.orcid"
              type="text"
              :state="orcidMeta.touched ? (orcidError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="orcidError">
              {{ orcidError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Abbreviation -->
          <BFormGroup
            label="Abbreviation:"
            label-for="input-abbreviation"
          >
            <BFormInput
              id="input-abbreviation"
              v-model="userToUpdate.abbreviation"
              type="text"
              :state="abbreviationMeta.touched ? (abbreviationError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="abbreviationError">
              {{ abbreviationError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- First name -->
          <BFormGroup
            label="First name:"
            label-for="input-first_name"
          >
            <BFormInput
              id="input-first_name"
              v-model="userToUpdate.first_name"
              type="text"
              :state="firstNameMeta.touched ? (firstNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="firstNameError">
              {{ firstNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Family name -->
          <BFormGroup
            label="Family name:"
            label-for="input-family_name"
          >
            <BFormInput
              id="input-family_name"
              v-model="userToUpdate.family_name"
              type="text"
              :state="familyNameMeta.touched ? (familyNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="familyNameError">
              {{ familyNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Role -->
          <BFormGroup
            label="Role:"
            label-for="input-user_role"
          >
            <BFormInput
              id="input-user_role"
              v-model="userToUpdate.user_role"
              type="text"
              :state="userRoleMeta.touched ? (userRoleError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="userRoleError">
              {{ userRoleError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Comment -->
          <BFormGroup
            label="Comment:"
            label-for="input-comment"
          >
            <BFormInput
              id="input-comment"
              v-model="userToUpdate.comment"
              type="text"
            />
          </BFormGroup>

          <!-- Approved -->
          <BFormGroup
            label="Approved:"
            label-for="input-approved"
          >
            <BFormCheckbox
              id="input-approved"
              v-model="userToUpdate.approved"
            >
              User is approved
            </BFormCheckbox>
          </BFormGroup>
        </form>
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
import useModalControls from '@/composables/useModalControls';
import { useUrlParsing, useTableData, useExcelExport } from '@/composables';

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

    const {
      value: orcid,
      errorMessage: orcidError,
      meta: orcidMeta,
    } = useField('orcid', 'required');

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
          key: 'user_name', label: 'User name', sortable: true, filterable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'email', label: 'E-mail', sortable: true, filterable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'user_role', label: 'Role', sortable: true, selectable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'approved', label: 'Status', sortable: true, selectable: true, sortDirection: 'asc', class: 'text-center',
        },
        {
          key: 'abbreviation', label: 'Abbrev.', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'created_at', label: 'Created', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        { key: 'actions', label: 'Actions', class: 'text-center' },
      ],
      showDeleteModal: false,
      userToDelete: {},
      userToUpdate: {},
      deleteUserModal: { id: 'delete-usermodal', title: '', content: [] },
      updateUserModal: { id: 'update-usermodal', title: '', content: [] },
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
      return Object.values(this.filter).some(f => f.content !== null && f.content !== '');
    },
    activeFilters() {
      const filters = [];
      if (this.filter.any.content) filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
      if (this.filter.user_role.content) filters.push({ key: 'user_role', label: 'Role', value: this.filter.user_role.content });
      if (this.filter.approved.content !== null) {
        filters.push({ key: 'approved', label: 'Status', value: this.filter.approved.content === '1' ? 'Approved' : 'Pending' });
      }
      return filters;
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

    this.$nextTick(() => {
      this.loadData();
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });
  },
  methods: {
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
        if (this.filter[key] && typeof this.filter[key] === 'object' && 'content' in this.filter[key]) {
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
      if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
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
      if (data.meta[0].fspec) {
        const actionsField = this.fields.find(f => f.key === 'actions');
        this.fields = [...data.meta[0].fspec, actionsField].filter(Boolean);
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
        this.user_options = response.data.map((item) => ({ value: item.user_id, text: item.user_name, role: item.user_role }));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    promptDeleteUser(item, button) {
      this.deleteUserModal.title = `${item.user_name}`;
      this.userToDelete = item;
      const { showModal } = useModalControls();
      showModal(this.deleteUserModal.id);
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
      const { hideModal } = useModalControls();
      hideModal(this.deleteUserModal.id);
      this.userToDelete = {};
    },
    editUser(item, button) {
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
      const { showModal } = useModalControls();
      showModal(this.updateUserModal.id);
    },
    async updateUserData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/update`;
      try {
        const response = await this.axios.put(apiUrl, { user_details: this.userToUpdate }, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        if (response.status === 200) {
          this.makeToast('User updated successfully', 'Success', 'success');
          this.loadData(); // Reload the table data
        } else {
          throw new Error('Failed to update the user.');
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.userToUpdate = {};
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn, .btn-xs {
  padding: .25rem .4rem;
  font-size: .875rem;
  line-height: .5;
  border-radius: .2rem;
}
</style>
