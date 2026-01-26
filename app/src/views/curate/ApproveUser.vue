<!-- views/curate/ApproveUser.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- User Interface controls -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">
                Approve new user applications
              </h6>
            </template>
            <!-- User Interface controls -->

            <!-- Pagination Controls -->
            <BRow class="my-2">
              <BCol>
                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows_UsersTable"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                />
              </BCol>
              <BCol class="text-end">
                <BFormSelect
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                />
              </BCol>
            </BRow>
            <!-- Pagination Controls -->

            <!-- Main table -->
            <BSpinner
              v-if="loadingUsersApprove"
              label="Loading..."
              class="float-center m-5"
            />
            <BTable
              v-else
              :items="items_UsersTable"
              :fields="fields_UsersTable"
              :per-page="perPage"
              :current-page="currentPage"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              empty-text="Currently no open user applications."
              @filtered="onFiltered"
            >
              <template #cell(user_role)="row">
                <BFormSelect
                  v-model="row.item.user_role"
                  class="form-control"
                  size="sm"
                  :options="role_options"
                />
              </template>

              <template #cell(approved)="row">
                <BButton
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  title="Manage user approval"
                  :variant="user_approval_style[row.item.approved]"
                  @click="infoApproveUser(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-hand-thumbs-up" />
                  <i class="bi bi-hand-thumbs-down" />
                </BButton>
              </template>
            </BTable>
          </BCard>
        </BCol>
      </BRow>

      <!-- Manage user approval modal -->
      <BModal
        :id="approveUserModal.id"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        @show="prepareApproveUserModal"
        @hide="resetUserApproveModal"
        @ok="handleUserApproveOk"
      >
        <template #modal-title>
          <h4>
            Manage application from:
            <BBadge variant="primary">
              {{ approveUserModal.title }}
            </BBadge>
          </h4>
        </template>
        What should happen to this user ?

        <div class="custom-control custom-switch">
          <input
            id="approveUserSwitch"
            v-model="user_approved"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="approveUserSwitch"
          >
            <b>{{ switch_user_approval_text[user_approved] }}</b>
          </label>
        </div>
      </BModal>
      <!-- Manage user approval modal -->
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols } from '@/composables';
import useModalControls from '@/composables/useModalControls';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ApproveUser',
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    return {
      makeToast,
      ...colorAndSymbols,
    };
  },
  data() {
    return {
      role_options: [],
      user_options: [],
      switch_user_approval_text: {
        true: 'Approve user',
        false: 'Delete application',
      },
      items_UsersTable: [],
      fields_UsersTable: [
        {
          key: 'user_id', label: 'User Id', sortable: true, class: 'text-start',
        },
        {
          key: 'user_name', label: 'User Name', sortable: true, class: 'text-start',
        },
        {
          key: 'email', label: 'Email', sortable: true, class: 'text-start',
        },
        {
          key: 'orcid', label: 'Orcid', sortable: true, class: 'text-start',
        },
        {
          key: 'abbreviation', label: 'Abbreviation', sortable: true, class: 'text-start',
        },
        {
          key: 'first_name', label: 'First Name', sortable: true, class: 'text-start',
        },
        {
          key: 'family_name', label: 'Family Name', sortable: true, class: 'text-start',
        },
        {
          key: 'comment', label: 'Comment', sortable: true, class: 'text-start',
        },
        {
          key: 'terms_agreed', label: 'Terms Agreed', sortable: true, class: 'text-start',
        },
        {
          key: 'created_at', label: 'Created At', sortable: true, class: 'text-start',
        },
        {
          key: 'user_role', label: 'User Role', sortable: false, class: 'text-start',
        },
        {
          key: 'approved', label: 'Approved', sortable: false, class: 'text-start',
        },
      ],
      totalRows_UsersTable: 0,
      loadingUsersApprove: true,
      approveUserModal: {
        id: 'approve-usermodal',
        title: '',
        content: [],
      },
      selectedUserId: null,
      approve_user: null,
      user_approved: false,
      currentPage: 1,
      perPage: 10,
      pageOptions: [
        { value: 5, text: '5' },
        { value: 10, text: '10' },
        { value: 20, text: '20' },
        { value: 50, text: '50' },
      ],
    };
  },
  mounted() {
    this.loadRoleList();
    this.loadUserList();
    this.loadUserTableData();
  },
  methods: {
    async loadUserTableData() {
      this.loadingUsersApprove = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        const data = response.data;
        // Defensive check for both API formats
        if (Array.isArray(data)) {
          this.items_UsersTable = data;
          this.totalRows_UsersTable = data.length;
        } else if (data?.data && Array.isArray(data.data)) {
          this.items_UsersTable = data.data;
          this.totalRows_UsersTable = data.meta?.[0]?.totalItems || data.data.length;
        } else {
          console.error('Unexpected user table response format:', data);
          this.items_UsersTable = [];
          this.totalRows_UsersTable = 0;
        }

        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.items_UsersTable = [];
        this.totalRows_UsersTable = 0;
      } finally {
        this.loadingUsersApprove = false;
      }
    },
    async loadRoleList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/role_list`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        const data = response.data;
        this.role_options = Array.isArray(data)
          ? data.map((item) => ({ value: item.role, text: item.role }))
          : [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadUserList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/list?roles=Curator,Reviewer`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        const data = response.data;
        this.user_options = Array.isArray(data)
          ? data.map((item) => ({
              value: item.user_id,
              text: item.user_name,
              role: item.user_role,
            }))
          : [];
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    infoApproveUser(item, index, button) {
      this.selectedUserId = item.user_id;
      const { showModal } = useModalControls();
      showModal(this.approveUserModal.id);
    },
    prepareApproveUserModal() {
      // Reset stale state
      this.approveUserModal.title = '';
      this.approve_user = null;
      this.user_approved = false;

      // Load fresh data for selected user
      if (this.selectedUserId) {
        const user = this.items_UsersTable.find((u) => u.user_id === this.selectedUserId);
        if (user) {
          this.approveUserModal.title = user.user_name;
          this.approve_user = user;
        }
      }
    },
    resetUserApproveModal() {
      this.approveUserModal = {
        id: 'approve-usermodal',
        title: '',
        content: [],
      };
      this.selectedUserId = null;
      this.approve_user = null;
      this.user_approved = false;
    },
    async handleUserApproveOk(bvModalEvt) {
      if (!this.approve_user) {
        this.makeToast('No user selected', 'Error', 'danger');
        return;
      }
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/approval?user_id=${this.approve_user.user_id}&status_approval=${this.user_approved}`;

      try {
        await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
        this.makeToast('User approval updated successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetUserApproveModal();
      this.loadUserTableData();
    },
    async handleUserChangeRole(user_id, user_role) {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/change_role?user_id=${user_id}&role_assigned=${user_role}`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
        this.makeToast('User role updated successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    onFiltered(filteredItems) {
      this.totalRows_UsersTable = filteredItems.length;
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

.username-select {
  background-color: #f8f9fa;
  border: 1px solid #ced4da;
  border-radius: 0.25rem;
  padding: 0.25rem 0.5rem;
  transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}

.username-select:focus {
  border-color: #80bdff;
  outline: 0;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.table-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.table-header h6 {
  margin-bottom: 0;
}

.table-header .actions {
  display: flex;
  gap: 0.5rem;
}

.table-search-pagination {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 1rem;
}

.table-search-pagination .search-input {
  flex: 1;
  margin-right: 1rem;
}

.table-search-pagination .pagination-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.table-search-pagination .pagination-controls .b-pagination,
.table-search-pagination .pagination-controls .b-form-select {
  margin-bottom: 0;
}

.text-start {
  text-align: left;
}
</style>
