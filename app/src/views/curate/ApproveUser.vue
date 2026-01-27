<!-- views/curate/ApproveUser.vue -->
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
            header-bg-variant="dark"
            header-text-variant="light"
          >
            <template #header>
              <BRow class="align-items-center">
                <BCol>
                  <h5 class="mb-0 text-start fw-bold">
                    Approve User Applications
                    <BBadge
                      variant="primary"
                      class="ms-2"
                    >
                      {{ totalRows }} pending
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    v-b-tooltip.hover.bottom
                    variant="outline-light"
                    size="sm"
                    title="Refresh data"
                    aria-label="Refresh table data"
                    @click="loadUserTableData()"
                  >
                    <i class="bi bi-arrow-clockwise" />
                  </BButton>
                </BCol>
              </BRow>
            </template>

            <!-- Search and pagination row -->
            <BRow class="px-3 py-2 align-items-center">
              <BCol
                cols="12"
                md="5"
                class="mb-2 mb-md-0"
              >
                <BInputGroup size="sm">
                  <template #prepend>
                    <BInputGroupText>
                      <i class="bi bi-search" />
                    </BInputGroupText>
                  </template>
                  <BFormInput
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="Search by name, email..."
                    debounce="300"
                  />
                </BInputGroup>
              </BCol>

              <BCol
                cols="12"
                md="7"
                class="d-flex justify-content-end align-items-center gap-2"
              >
                <BInputGroup
                  size="sm"
                  class="w-auto"
                >
                  <template #prepend>
                    <BInputGroupText>Per page</BInputGroupText>
                  </template>
                  <BFormSelect
                    id="per-page-select"
                    v-model="perPage"
                    :options="pageOptions"
                    size="sm"
                    style="width: 70px"
                  />
                </BInputGroup>

                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  size="sm"
                  class="my-0"
                  limit="3"
                />
              </BCol>
            </BRow>

            <!-- Filter dropdowns -->
            <BRow class="px-3 pb-2 align-items-center">
              <BCol
                cols="6"
                md="3"
                class="mb-2 mb-md-0"
              >
                <BFormSelect
                  v-model="roleFilter"
                  size="sm"
                  :options="roleFilterOptions"
                  aria-label="Filter by role"
                />
              </BCol>
              <BCol
                cols="6"
                md="9"
                class="d-flex align-items-center flex-wrap gap-1"
              >
                <!-- Active filter tags -->
                <BBadge
                  v-if="filter"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="filter = ''"
                >
                  Search: {{ filter }}
                  <i class="bi bi-x" />
                </BBadge>
                <BBadge
                  v-if="roleFilter"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="roleFilter = null"
                >
                  Role: {{ roleFilter }}
                  <i class="bi bi-x" />
                </BBadge>
              </BCol>
            </BRow>

            <!-- Main table -->
            <div class="position-relative">
              <BSpinner
                v-if="loadingUsersApprove"
                class="position-absolute top-50 start-50 translate-middle"
                variant="primary"
              />
              <div
                v-if="!loadingUsersApprove && filteredItems.length === 0"
                class="text-center py-5"
              >
                <i class="bi bi-person-check fs-1 text-success" />
                <p class="text-muted mt-2">
                  No pending user applications
                </p>
              </div>
              <BTable
                v-else-if="!loadingUsersApprove"
                :items="filteredItems"
                :fields="fields"
                :per-page="perPage"
                :current-page="currentPage"
                :class="{ 'opacity-50': loadingUsersApprove }"
                stacked="md"
                head-variant="light"
                show-empty
                small
                striped
                hover
                sort-icon-left
                empty-text="No pending applications found"
              >
                <template #cell(user_name)="data">
                  <div class="d-flex align-items-center gap-2">
                    <span
                      class="d-inline-flex align-items-center justify-content-center rounded-circle bg-primary-subtle text-primary"
                      style="width: 28px; height: 28px; font-size: 0.8rem;"
                    >
                      <i class="bi bi-person-fill" />
                    </span>
                    <div>
                      <strong>{{ data.item.user_name }}</strong>
                      <div class="text-muted small">
                        {{ data.item.first_name }} {{ data.item.family_name }}
                      </div>
                    </div>
                  </div>
                </template>

                <template #cell(email)="data">
                  <div class="d-flex align-items-center">
                    <i class="bi bi-envelope me-1 text-muted" />
                    <span class="small">{{ data.item.email }}</span>
                  </div>
                </template>

                <template #cell(orcid)="data">
                  <a
                    v-if="data.item.orcid"
                    :href="'https://orcid.org/' + data.item.orcid"
                    target="_blank"
                    class="text-decoration-none"
                  >
                    <i class="bi bi-link-45deg me-1" />
                    {{ data.item.orcid }}
                  </a>
                  <span
                    v-else
                    class="text-muted"
                  >—</span>
                </template>

                <template #cell(user_role)="data">
                  <BBadge
                    :variant="getRoleBadgeVariant(data.item.user_role)"
                    class="d-inline-flex align-items-center gap-1"
                  >
                    <i :class="getRoleIcon(data.item.user_role)" />
                    {{ data.item.user_role }}
                  </BBadge>
                </template>

                <template #cell(created_at)="data">
                  <div class="d-flex align-items-center gap-1">
                    <span
                      v-b-tooltip.hover.top
                      :title="data.item.created_at"
                      class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary"
                      style="width: 24px; height: 24px; font-size: 0.75rem;"
                    >
                      <i class="bi bi-calendar3" />
                    </span>
                    <span class="small text-muted">
                      {{ formatDate(data.item.created_at) }}
                    </span>
                  </div>
                </template>

                <template #cell(comment)="data">
                  <div
                    v-if="data.item.comment"
                    :id="'comment-user-' + data.item.user_id"
                    class="text-truncate-multiline small text-popover-trigger"
                    style="max-width: 150px;"
                  >
                    {{ data.item.comment }}
                  </div>
                  <BPopover
                    v-if="data.item.comment"
                    :target="'comment-user-' + data.item.user_id"
                    triggers="hover focus"
                    placement="top"
                    custom-class="wide-popover"
                  >
                    <template #title>
                      <i class="bi bi-chat-left-text me-1" />
                      Application Comment
                    </template>
                    <div class="popover-text-content">
                      {{ data.item.comment }}
                    </div>
                  </BPopover>
                  <span
                    v-else
                    class="text-muted small"
                  >—</span>
                </template>

                <template #cell(actions)="row">
                  <div class="d-flex gap-1">
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="btn-xs"
                      variant="success"
                      title="Approve user"
                      :aria-label="`Approve user ${row.item.user_name}`"
                      @click="approveUser(row.item)"
                    >
                      <i class="bi bi-check-lg" />
                    </BButton>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="btn-xs"
                      variant="outline-secondary"
                      title="Edit & review"
                      :aria-label="`Review user ${row.item.user_name}`"
                      @click="reviewUser(row.item)"
                    >
                      <i class="bi bi-pencil" />
                    </BButton>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="btn-xs"
                      variant="outline-danger"
                      title="Reject application"
                      :aria-label="`Reject user ${row.item.user_name}`"
                      @click="rejectUser(row.item)"
                    >
                      <i class="bi bi-x-lg" />
                    </BButton>
                  </div>
                </template>
              </BTable>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Review/Edit User Modal -->
      <BModal
        v-model="showReviewModal"
        size="lg"
        centered
        ok-title="Save & Approve"
        ok-variant="success"
        cancel-title="Cancel"
        cancel-variant="outline-secondary"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        @ok="handleApproveWithChanges"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-person-gear me-2 text-primary" />
            <span class="fw-semibold">Review Application</span>
          </div>
        </template>

        <template #footer="{ ok, cancel }">
          <div class="w-100 d-flex justify-content-between align-items-center">
            <BButton
              variant="outline-danger"
              size="sm"
              @click="rejectFromModal"
            >
              <i class="bi bi-x-lg me-1" />
              Reject
            </BButton>
            <div class="d-flex gap-2">
              <BButton
                variant="outline-secondary"
                @click="cancel()"
              >
                Cancel
              </BButton>
              <BButton
                variant="success"
                @click="ok()"
              >
                <i class="bi bi-check-lg me-1" />
                Save & Approve
              </BButton>
            </div>
          </div>
        </template>

        <!-- User Info Header -->
        <div class="bg-light rounded-3 p-3 mb-4">
          <div class="d-flex align-items-center gap-3">
            <span
              class="d-inline-flex align-items-center justify-content-center rounded-circle bg-primary text-white"
              style="width: 48px; height: 48px; font-size: 1.2rem;"
            >
              <i class="bi bi-person-fill" />
            </span>
            <div>
              <h5 class="mb-0">
                {{ selectedUser.first_name }} {{ selectedUser.family_name }}
              </h5>
              <div class="text-muted small">
                @{{ selectedUser.user_name }} · Applied {{ formatDate(selectedUser.created_at) }}
              </div>
            </div>
          </div>
        </div>

        <!-- Application Details Section -->
        <div class="mb-4">
          <h6 class="text-muted border-bottom pb-2 mb-3">
            <i class="bi bi-info-circle me-2" />
            Application Details
          </h6>
          <BRow>
            <BCol md="6">
              <div class="mb-3">
                <label class="form-label text-muted small">Email</label>
                <div class="d-flex align-items-center">
                  <i class="bi bi-envelope me-2 text-muted" />
                  <span>{{ selectedUser.email }}</span>
                </div>
              </div>
            </BCol>
            <BCol md="6">
              <div class="mb-3">
                <label class="form-label text-muted small">ORCID</label>
                <div class="d-flex align-items-center">
                  <i class="bi bi-link-45deg me-2 text-muted" />
                  <a
                    v-if="selectedUser.orcid"
                    :href="'https://orcid.org/' + selectedUser.orcid"
                    target="_blank"
                  >
                    {{ selectedUser.orcid }}
                  </a>
                  <span
                    v-else
                    class="text-muted"
                  >Not provided</span>
                </div>
              </div>
            </BCol>
          </BRow>
          <BRow>
            <BCol md="6">
              <div class="mb-3">
                <label class="form-label text-muted small">Abbreviation</label>
                <div>{{ selectedUser.abbreviation || '—' }}</div>
              </div>
            </BCol>
            <BCol md="6">
              <div class="mb-3">
                <label class="form-label text-muted small">Terms Agreed</label>
                <BBadge :variant="selectedUser.terms_agreed ? 'success' : 'danger'">
                  <i :class="selectedUser.terms_agreed ? 'bi bi-check-circle' : 'bi bi-x-circle'" class="me-1" />
                  {{ selectedUser.terms_agreed ? 'Yes' : 'No' }}
                </BBadge>
              </div>
            </BCol>
          </BRow>
          <div v-if="selectedUser.comment">
            <label class="form-label text-muted small">Application Comment</label>
            <div class="bg-warning-subtle rounded p-2 small">
              {{ selectedUser.comment }}
            </div>
          </div>
        </div>

        <!-- Role Assignment Section -->
        <div class="mb-3">
          <h6 class="text-muted border-bottom pb-2 mb-3">
            <i class="bi bi-shield-check me-2" />
            Role Assignment
          </h6>
          <BFormGroup
            label="Assign Role"
            label-for="role-select"
          >
            <BFormSelect
              id="role-select"
              v-model="selectedUser.user_role"
              :options="role_options"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null">
                  Select a role...
                </BFormSelectOption>
              </template>
            </BFormSelect>
            <small class="text-muted">
              Choose the appropriate role for this user based on their application.
            </small>
          </BFormGroup>
        </div>
      </BModal>

      <!-- Quick Approve Confirmation Modal -->
      <BModal
        v-model="showApproveModal"
        size="md"
        centered
        ok-title="Approve"
        ok-variant="success"
        cancel-title="Cancel"
        cancel-variant="outline-secondary"
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        @ok="confirmApprove"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-check-circle-fill me-2 text-success" />
            <span class="fw-semibold">Approve User</span>
          </div>
        </template>

        <div class="text-center py-3">
          <span
            class="d-inline-flex align-items-center justify-content-center rounded-circle bg-success-subtle text-success mb-3"
            style="width: 64px; height: 64px; font-size: 1.5rem;"
          >
            <i class="bi bi-person-check" />
          </span>
          <p class="mb-2">
            Approve user <strong>{{ selectedUser.user_name }}</strong>?
          </p>
          <p class="text-muted small">
            {{ selectedUser.first_name }} {{ selectedUser.family_name }} will be granted access with
            <BBadge :variant="getRoleBadgeVariant(selectedUser.user_role)">
              {{ selectedUser.user_role }}
            </BBadge>
            role.
          </p>
        </div>
      </BModal>

      <!-- Reject Confirmation Modal -->
      <BModal
        v-model="showRejectModal"
        size="md"
        centered
        ok-title="Reject Application"
        ok-variant="danger"
        cancel-title="Cancel"
        cancel-variant="outline-secondary"
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        @ok="confirmReject"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-exclamation-triangle-fill me-2 text-danger" />
            <span class="fw-semibold">Reject Application</span>
          </div>
        </template>

        <div class="text-center py-3">
          <span
            class="d-inline-flex align-items-center justify-content-center rounded-circle bg-danger-subtle text-danger mb-3"
            style="width: 64px; height: 64px; font-size: 1.5rem;"
          >
            <i class="bi bi-person-x" />
          </span>
          <p class="mb-2">
            Reject application from <strong>{{ selectedUser.user_name }}</strong>?
          </p>
          <p class="text-muted small">
            This will delete the user application. This action cannot be undone.
          </p>
        </div>
      </BModal>
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols } from '@/composables';
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
      items_UsersTable: [],
      fields: [
        {
          key: 'user_name',
          label: 'User',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'email',
          label: 'Email',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'orcid',
          label: 'ORCID',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'user_role',
          label: 'Requested Role',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'created_at',
          label: 'Applied',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      totalRows: 0,
      loadingUsersApprove: true,
      selectedUser: {},
      showReviewModal: false,
      showApproveModal: false,
      showRejectModal: false,
      currentPage: 1,
      perPage: 10,
      pageOptions: [
        { value: 5, text: '5' },
        { value: 10, text: '10' },
        { value: 25, text: '25' },
        { value: 50, text: '50' },
      ],
      filter: '',
      roleFilter: null,
    };
  },
  computed: {
    roleFilterOptions() {
      const roles = [...new Set(this.items_UsersTable.map((item) => item.user_role))].filter(Boolean);
      return [
        { value: null, text: 'All Roles' },
        ...roles.map((role) => ({ value: role, text: role })),
      ];
    },
    filteredItems() {
      let items = this.items_UsersTable;

      // Filter by search text
      if (this.filter) {
        const searchTerm = this.filter.toLowerCase();
        items = items.filter(
          (item) => (item.user_name && item.user_name.toLowerCase().includes(searchTerm))
            || (item.email && item.email.toLowerCase().includes(searchTerm))
            || (item.first_name && item.first_name.toLowerCase().includes(searchTerm))
            || (item.family_name && item.family_name.toLowerCase().includes(searchTerm)),
        );
      }

      // Filter by role
      if (this.roleFilter) {
        items = items.filter((item) => item.user_role === this.roleFilter);
      }

      return items;
    },
  },
  watch: {
    filteredItems() {
      this.totalRows = this.filteredItems.length;
      this.currentPage = 1;
    },
  },
  mounted() {
    this.loadRoleList();
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
        let users = [];
        if (Array.isArray(data)) {
          users = data;
        } else if (data?.data && Array.isArray(data.data)) {
          users = data.data;
        }
        // Filter to show only unapproved (pending) users
        this.items_UsersTable = users.filter((user) => !user.approved || user.approved === 0);
        this.totalRows = this.items_UsersTable.length;

        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.items_UsersTable = [];
        this.totalRows = 0;
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
    formatDate(dateString) {
      if (!dateString) return '—';
      const date = new Date(dateString);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    },
    getRoleBadgeVariant(role) {
      const variants = {
        Administrator: 'danger',
        Curator: 'primary',
        Reviewer: 'info',
        Viewer: 'secondary',
      };
      return variants[role] || 'secondary';
    },
    getRoleIcon(role) {
      const icons = {
        Administrator: 'bi bi-shield-fill-check',
        Curator: 'bi bi-pencil-fill',
        Reviewer: 'bi bi-eye-fill',
        Viewer: 'bi bi-person-fill',
      };
      return icons[role] || 'bi bi-person-fill';
    },
    approveUser(user) {
      this.selectedUser = { ...user };
      this.showApproveModal = true;
    },
    reviewUser(user) {
      this.selectedUser = { ...user };
      this.showReviewModal = true;
    },
    rejectUser(user) {
      this.selectedUser = { ...user };
      this.showRejectModal = true;
    },
    rejectFromModal() {
      this.showReviewModal = false;
      this.$nextTick(() => {
        this.showRejectModal = true;
      });
    },
    async confirmApprove() {
      await this.handleUserApproval(this.selectedUser.user_id, true);
      this.showApproveModal = false;
    },
    async handleApproveWithChanges() {
      // First update the role if changed
      if (this.selectedUser.user_role) {
        await this.handleUserChangeRole(this.selectedUser.user_id, this.selectedUser.user_role);
      }
      // Then approve
      await this.handleUserApproval(this.selectedUser.user_id, true);
      this.showReviewModal = false;
    },
    async confirmReject() {
      await this.handleUserApproval(this.selectedUser.user_id, false);
      this.showRejectModal = false;
    },
    async handleUserApproval(userId, approved) {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/approval?user_id=${userId}&status_approval=${approved}`;

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
        this.makeToast(
          approved ? 'User approved successfully.' : 'User application rejected.',
          'Success',
          approved ? 'success' : 'info',
        );
        this.loadUserTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async handleUserChangeRole(userId, userRole) {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/change_role?user_id=${userId}&role_assigned=${userRole}`;

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
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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

/* Multi-line text truncation with ellipsis */
.text-truncate-multiline {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.4;
}

/* Cursor style for popover triggers */
.text-popover-trigger {
  cursor: help;
  border-bottom: 1px dotted #6c757d;
}

.text-popover-trigger:hover {
  background-color: rgba(0, 123, 255, 0.05);
  border-radius: 2px;
}
</style>

<!-- Non-scoped styles for popovers (rendered outside component DOM) -->
<style>
/* Wide popover for comment text */
.wide-popover {
  max-width: 400px !important;
}

.wide-popover .popover-header {
  font-size: 0.85rem;
  font-weight: 600;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

.wide-popover .popover-body {
  max-height: 250px;
  overflow-y: auto;
  font-size: 0.85rem;
  line-height: 1.5;
}

.popover-text-content {
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
