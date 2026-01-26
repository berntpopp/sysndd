<!-- src/views/curate/ManageReReview.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- Batch Creation Section (Collapsible) -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="primary"
            class="mb-3"
          >
            <template #header>
              <div class="d-flex justify-content-between align-items-center">
                <h6 class="mb-1 text-start font-weight-bold">
                  <i class="bi bi-plus-square me-1" />
                  Create New Batch
                </h6>
                <BButton
                  v-b-toggle.batch-form-collapse
                  variant="outline-primary"
                  size="sm"
                  aria-label="Toggle batch creation form"
                >
                  <i class="bi bi-chevron-down" />
                </BButton>
              </div>
            </template>
            <BCollapse
              id="batch-form-collapse"
              visible
            >
              <div class="p-3">
                <BatchCriteriaForm @batch-created="onBatchCreated" />
              </div>
            </BCollapse>
          </BCard>

          <!-- Gene-Specific Assignment Section (Collapsible) - RRV-06 -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="info"
            class="mb-3"
          >
            <template #header>
              <div class="d-flex justify-content-between align-items-center">
                <h6 class="mb-1 text-start font-weight-bold">
                  <i class="bi bi-person-plus me-1" />
                  Assign Specific Genes to User
                </h6>
                <BButton
                  v-b-toggle.entity-assign-collapse
                  variant="outline-info"
                  size="sm"
                  aria-label="Toggle gene-specific assignment form"
                >
                  <i class="bi bi-chevron-down" />
                </BButton>
              </div>
            </template>
            <BCollapse id="entity-assign-collapse">
              <div class="p-3">
                <!-- Entity Selection Table -->
                <BFormGroup
                  label="Select entities to assign:"
                  label-for="entity-select-table"
                  class="mb-3"
                >
                  <BTable
                    id="entity-select-table"
                    :items="availableEntities"
                    :fields="entitySelectFields"
                    selectable
                    select-mode="multi"
                    small
                    striped
                    hover
                    responsive
                    :busy="isLoadingEntities"
                    @row-selected="onEntitySelected"
                  >
                    <template #table-busy>
                      <div class="text-center my-2">
                        <BSpinner class="align-middle" />
                        <strong class="ms-2">Loading entities...</strong>
                      </div>
                    </template>
                  </BTable>
                  <small class="text-muted d-block mt-1">
                    {{ selectedEntityIds.length }} entity/entities selected.
                    Click rows to select/deselect. Hold Shift for range selection.
                  </small>
                </BFormGroup>

                <!-- User Selection -->
                <BFormGroup
                  label="Assign to User:"
                  label-for="entity-assign-user"
                  class="mb-3"
                >
                  <BFormSelect
                    id="entity-assign-user"
                    v-model="entityAssignUserId"
                    :options="user_options"
                    aria-label="Select user to assign selected entities to"
                  >
                    <template #first>
                      <option
                        :value="null"
                        disabled
                      >
                        -- Select a user --
                      </option>
                    </template>
                  </BFormSelect>
                </BFormGroup>

                <!-- Batch Name (optional) -->
                <BFormGroup
                  label="Batch Name (optional):"
                  label-for="entity-assign-batch-name"
                  class="mb-3"
                >
                  <BFormInput
                    id="entity-assign-batch-name"
                    v-model="entityAssignBatchName"
                    placeholder="Auto-generated if empty"
                    aria-label="Custom name for the new batch"
                  />
                </BFormGroup>

                <!-- Actions -->
                <div class="d-flex gap-2">
                  <BButton
                    variant="info"
                    :disabled="selectedEntityIds.length === 0 || !entityAssignUserId || isAssigningEntities"
                    @click="handleEntityAssignment"
                  >
                    <BSpinner
                      v-if="isAssigningEntities"
                      small
                      class="me-1"
                    />
                    <i
                      v-else
                      class="bi bi-person-plus me-1"
                    />
                    Assign {{ selectedEntityIds.length }} Entities to User
                  </BButton>
                  <BButton
                    variant="outline-secondary"
                    @click="loadAvailableEntities"
                  >
                    <i class="bi bi-arrow-clockwise me-1" />
                    Refresh Entity List
                  </BButton>
                </div>
              </div>
            </BCollapse>
          </BCard>

          <!-- Submissions Management Card -->
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
                    <strong>Manage Re-review Submissions</strong>
                    <BBadge
                      variant="secondary"
                      class="ms-2"
                    >
                      {{ totalRows }} batches
                    </BBadge>
                    <BBadge
                      id="popover-badge-help-manage"
                      pill
                      href="#"
                      variant="info"
                      class="ms-1"
                    >
                      <i class="bi bi-question-circle-fill" />
                    </BBadge>
                    <BPopover
                      target="popover-badge-help-manage"
                      variant="info"
                      triggers="focus"
                    >
                      <template #title>
                        Re-review Submissions Management
                      </template>
                      Use this section to manage re-review submissions. You can assign new batches to users and view the details of each batch.
                    </BPopover>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <BButton
                    id="btn-refresh-table"
                    size="sm"
                    variant="outline-secondary"
                    class="me-1"
                    :disabled="loadingReReviewManagment"
                    @click="loadReReviewTableData"
                  >
                    <BSpinner
                      v-if="loadingReReviewManagment"
                      small
                    />
                    <i
                      v-else
                      class="bi bi-arrow-clockwise"
                    />
                  </BButton>
                  <BTooltip
                    target="btn-refresh-table"
                    triggers="hover"
                  >
                    Refresh table data
                  </BTooltip>
                </BCol>
              </BRow>
            </template>

            <!-- Search and Filters Row -->
            <BRow class="px-2 py-2">
              <BCol sm="5">
                <BInputGroup size="sm">
                  <template #prepend>
                    <BInputGroupText><i class="bi bi-search" /></BInputGroupText>
                  </template>
                  <BFormInput
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="Search batches, users..."
                    debounce="300"
                  />
                </BInputGroup>
              </BCol>
              <BCol sm="3">
                <BFormSelect
                  v-model="userFilter"
                  :options="userFilterOptions"
                  size="sm"
                  @update:model-value="applyFilters"
                >
                  <template #first>
                    <BFormSelectOption :value="null">
                      All Users
                    </BFormSelectOption>
                  </template>
                </BFormSelect>
              </BCol>
              <BCol sm="2">
                <BFormSelect
                  v-model="assignmentFilter"
                  :options="assignmentFilterOptions"
                  size="sm"
                  @update:model-value="applyFilters"
                >
                  <template #first>
                    <BFormSelectOption :value="null">
                      All Status
                    </BFormSelectOption>
                  </template>
                </BFormSelect>
              </BCol>
              <BCol
                sm="2"
                class="text-end"
              >
                <BFormSelect
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                />
              </BCol>
            </BRow>

            <!-- Legacy Assignment Row (Compact) -->
            <BRow class="px-2 pb-2">
              <BCol sm="6">
                <div class="d-flex align-items-center gap-2">
                  <BFormSelect
                    v-model="user_id_assignment"
                    :options="user_options"
                    size="sm"
                    style="max-width: 180px;"
                  >
                    <template #first>
                      <BFormSelectOption
                        :value="0"
                        disabled
                      >
                        Select user...
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                  <BButton
                    size="sm"
                    variant="outline-secondary"
                    :disabled="!user_id_assignment"
                    aria-label="Assign next available pre-computed batch to selected user"
                    @click="handleNewBatchAssignment"
                  >
                    <i class="bi bi-plus-square me-1" />
                    Assign Legacy Batch
                  </BButton>
                  <i
                    id="help-legacy-batch"
                    class="bi bi-question-circle text-muted"
                  />
                  <BTooltip
                    target="help-legacy-batch"
                    placement="right"
                    triggers="hover"
                  >
                    Assign next available pre-computed batch. Use 'Create New Batch' above for dynamic batches.
                  </BTooltip>
                </div>
              </BCol>
              <BCol
                sm="6"
                class="text-end"
              >
                <span class="text-muted small">
                  Showing {{ Math.min((currentPage - 1) * perPage + 1, totalRows) }}-{{ Math.min(currentPage * perPage, totalRows) }} of {{ totalRows }}
                </span>
              </BCol>
            </BRow>

            <!-- Table with Loading State -->
            <div class="position-relative">
              <BSpinner
                v-if="loadingReReviewManagment"
                class="position-absolute top-50 start-50 translate-middle"
                variant="primary"
              />
              <div
                v-if="!loadingReReviewManagment && filteredItems.length === 0"
                class="text-center py-4"
              >
                <i class="bi bi-inbox fs-1 text-muted" />
                <p class="text-muted mt-2">
                  No batches found
                </p>
              </div>
              <BTable
                v-else
                :items="filteredItems"
                :fields="fields_ReReviewTable"
                :per-page="perPage"
                :current-page="currentPage"
                :class="{ 'opacity-50': loadingReReviewManagment }"
                head-variant="light"
                show-empty
                small
                striped
                hover
                responsive
                sort-icon-left
                @filtered="onFiltered"
                @sort-changed="onSortChanged"
              >
                <!-- User column with badge -->
                <template #cell(user_name)="row">
                  <div class="d-flex align-items-center gap-1">
                    <i
                      :class="row.item.user_id ? 'bi bi-person-fill text-primary' : 'bi bi-person text-muted'"
                    />
                    <BBadge
                      :variant="row.item.user_id ? 'primary' : 'secondary'"
                    >
                      {{ row.item.user_name || 'Unassigned' }}
                    </BBadge>
                  </div>
                </template>

                <!-- Batch ID column -->
                <template #cell(re_review_batch)="row">
                  <span class="font-monospace">
                    #{{ row.item.re_review_batch }}
                  </span>
                </template>

                <!-- Progress columns with mini badges -->
                <template #cell(re_review_review_saved)="row">
                  <BBadge
                    :variant="row.item.re_review_review_saved > 0 ? 'info' : 'light'"
                    class="count-badge"
                  >
                    {{ row.item.re_review_review_saved }}
                  </BBadge>
                </template>

                <template #cell(re_review_status_saved)="row">
                  <BBadge
                    :variant="row.item.re_review_status_saved > 0 ? 'info' : 'light'"
                    class="count-badge"
                  >
                    {{ row.item.re_review_status_saved }}
                  </BBadge>
                </template>

                <template #cell(re_review_submitted)="row">
                  <BBadge
                    :variant="row.item.re_review_submitted > 0 ? 'warning' : 'light'"
                    class="count-badge"
                  >
                    {{ row.item.re_review_submitted }}
                  </BBadge>
                </template>

                <template #cell(re_review_approved)="row">
                  <BBadge
                    :variant="row.item.re_review_approved > 0 ? 'success' : 'light'"
                    class="count-badge"
                  >
                    {{ row.item.re_review_approved }}
                  </BBadge>
                </template>

                <template #cell(entity_count)="row">
                  <strong>{{ row.item.entity_count }}</strong>
                </template>

                <!-- Actions column -->
                <template #cell(actions)="data">
                  <div class="d-flex gap-1 justify-content-center">
                    <!-- Recalculate button (only for unassigned batches) -->
                    <BButton
                      v-if="!data.item.user_id"
                      :id="`btn-recalc-${data.item.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="secondary"
                      @click="openRecalculateModal(data.item)"
                    >
                      <i class="bi bi-calculator" />
                    </BButton>
                    <BTooltip
                      v-if="!data.item.user_id"
                      :target="`btn-recalc-${data.item.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Recalculate batch contents
                    </BTooltip>

                    <!-- Reassign button (only for assigned batches) -->
                    <BButton
                      v-if="data.item.user_id"
                      :id="`btn-reassign-${data.item.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="warning"
                      @click="openReassignModal(data.item)"
                    >
                      <i class="bi bi-person-lines-fill" />
                    </BButton>
                    <BTooltip
                      v-if="data.item.user_id"
                      :target="`btn-reassign-${data.item.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Reassign to different user
                    </BTooltip>

                    <!-- Unassign button -->
                    <BButton
                      v-if="data.item.user_id"
                      :id="`btn-unassign-${data.item.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="danger"
                      @click="handleBatchUnAssignment(data.item.re_review_batch)"
                    >
                      <i class="bi bi-person-dash-fill" />
                    </BButton>
                    <BTooltip
                      v-if="data.item.user_id"
                      :target="`btn-unassign-${data.item.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Unassign this batch
                    </BTooltip>
                  </div>
                </template>
              </BTable>
            </div>

            <!-- Pagination Row -->
            <BRow
              v-if="totalRows > perPage"
              class="px-2 py-2"
            >
              <BCol class="d-flex justify-content-center">
                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  size="sm"
                  class="mb-0"
                  first-number
                  last-number
                  limit="7"
                />
              </BCol>
            </BRow>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>

    <!-- Reassign Modal -->
    <BModal
      v-model="reassignModalShow"
      title="Reassign Batch"
      ok-title="Reassign"
      cancel-title="Cancel"
      @ok="handleBatchReassignment"
    >
      <BFormGroup
        label="Select new user:"
        label-for="reassign-user-select"
      >
        <BFormSelect
          id="reassign-user-select"
          v-model="reassignNewUserId"
          :options="user_options"
          aria-label="Select user to reassign batch to"
        />
      </BFormGroup>
      <small class="text-muted">
        This will reassign batch {{ reassignBatchId }} to the selected user.
      </small>
    </BModal>

    <!-- Recalculate Modal (RRV-05) -->
    <BModal
      v-model="recalculateModalShow"
      title="Recalculate Batch Contents"
      size="lg"
      ok-title="Recalculate"
      cancel-title="Cancel"
      :ok-disabled="isRecalculating"
      @ok="handleBatchRecalculation"
    >
      <BAlert
        variant="info"
        show
        class="mb-3"
      >
        <i class="bi bi-info-circle me-1" />
        This will replace the current entities in batch {{ recalculateBatchId }} with entities matching the new criteria.
        Only unassigned batches can be recalculated.
      </BAlert>

      <!-- Date Range -->
      <BFormGroup
        label="Review Date Range"
        class="mb-3"
      >
        <div class="d-flex gap-2">
          <BFormInput
            v-model="recalculateCriteria.date_range.start"
            type="date"
            :disabled="isRecalculating"
            aria-label="Start date for review date range"
          />
          <span class="align-self-center">to</span>
          <BFormInput
            v-model="recalculateCriteria.date_range.end"
            type="date"
            :disabled="isRecalculating"
            aria-label="End date for review date range"
          />
        </div>
      </BFormGroup>

      <!-- Status Filter -->
      <BFormGroup
        label="Status Category"
        class="mb-3"
      >
        <BFormSelect
          v-model="recalculateCriteria.status_filter"
          :options="status_options"
          :disabled="isRecalculating"
          aria-label="Filter by entity status category"
        >
          <template #first>
            <option :value="null">
              -- Any status --
            </option>
          </template>
        </BFormSelect>
      </BFormGroup>

      <!-- Batch Size -->
      <BFormGroup
        label="Batch Size"
        class="mb-3"
      >
        <BFormInput
          v-model.number="recalculateCriteria.batch_size"
          type="number"
          min="1"
          max="100"
          :disabled="isRecalculating"
          aria-label="Maximum number of entities in recalculated batch"
        />
      </BFormGroup>

      <BSpinner
        v-if="isRecalculating"
        class="me-2"
        small
      />
    </BModal>
  </div>
</template>

<script>
import useToast from '@/composables/useToast';
import BatchCriteriaForm from '@/components/forms/BatchCriteriaForm.vue';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ManageReReview',
  components: {
    BatchCriteriaForm,
  },
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      filter: null,
      userFilter: null,
      assignmentFilter: null,
      loadingReReviewManagment: false,
      user_options: [],
      user_id_assignment: 0,
      items_ReReviewTable: [],
      fields_ReReviewTable: [
        {
          key: 'user_name',
          label: 'User',
          sortable: true,
          sortDirection: 'desc',
          class: 'text-start',
          thStyle: { width: '140px' },
        },
        {
          key: 're_review_batch',
          label: 'Batch',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '80px' },
        },
        {
          key: 're_review_review_saved',
          label: 'Saved',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '70px' },
        },
        {
          key: 're_review_status_saved',
          label: 'Status',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '70px' },
        },
        {
          key: 're_review_submitted',
          label: 'Submitted',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '85px' },
        },
        {
          key: 're_review_approved',
          label: 'Approved',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '85px' },
        },
        {
          key: 'entity_count',
          label: 'Total',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '70px' },
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
          thStyle: { width: '100px' },
        },
      ],
      currentPage: 1,
      perPage: 25,
      totalRows: 0,
      pageOptions: [10, 25, 50, 100],

      // Gene-specific assignment (RRV-06)
      availableEntities: [],
      selectedEntityIds: [],
      entityAssignUserId: null,
      entityAssignBatchName: '',
      isLoadingEntities: false,
      isAssigningEntities: false,
      entitySelectFields: [
        { key: 'entity_id', label: 'ID', sortable: true },
        { key: 'gene_symbol', label: 'Gene', sortable: true },
        { key: 'disease_ontology_name', label: 'Disease', sortable: true },
        { key: 'review_date', label: 'Last Review', sortable: true },
        { key: 'status_name', label: 'Status', sortable: true },
      ],

      // Reassignment
      reassignModalShow: false,
      reassignBatchId: null,
      reassignNewUserId: null,

      // Recalculation (RRV-05)
      recalculateModalShow: false,
      recalculateBatchId: null,
      recalculateCriteria: {
        date_range: { start: null, end: null },
        gene_list: [],
        status_filter: null,
        batch_size: 20,
      },
      isRecalculating: false,

      // Status options for recalculate modal
      status_options: [],
    };
  },
  computed: {
    // Filter options derived from loaded data
    userFilterOptions() {
      const uniqueUsers = [...new Set(this.items_ReReviewTable
        .filter((item) => item.user_name)
        .map((item) => item.user_name))];
      return uniqueUsers.map((name) => ({ value: name, text: name }));
    },
    assignmentFilterOptions() {
      return [
        { value: 'assigned', text: 'Assigned' },
        { value: 'unassigned', text: 'Unassigned' },
      ];
    },
    // Filtered items based on all filters
    filteredItems() {
      let items = this.items_ReReviewTable;

      // Apply text search filter
      if (this.filter) {
        const searchTerm = this.filter.toLowerCase();
        items = items.filter((item) => {
          const userName = (item.user_name || '').toLowerCase();
          const batchId = String(item.re_review_batch || '');
          return userName.includes(searchTerm) || batchId.includes(searchTerm);
        });
      }

      // Apply user filter
      if (this.userFilter) {
        items = items.filter((item) => item.user_name === this.userFilter);
      }

      // Apply assignment filter
      if (this.assignmentFilter === 'assigned') {
        items = items.filter((item) => item.user_id);
      } else if (this.assignmentFilter === 'unassigned') {
        items = items.filter((item) => !item.user_id);
      }

      // Update totalRows based on filtered results
      this.$nextTick(() => {
        this.totalRows = items.length;
      });

      return items;
    },
  },
  mounted() {
    this.loadUserList();
    this.loadReReviewTableData();
    this.loadAvailableEntities();
    this.loadStatusOptions();
  },
  methods: {
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
        this.user_options = [];
      }
    },
    async loadReReviewTableData() {
      this.loadingReReviewManagment = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/assignment_table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        const data = response.data;
        if (Array.isArray(data)) {
          this.items_ReReviewTable = data;
          this.totalRows = data.length;
        } else if (data?.data && Array.isArray(data.data)) {
          this.items_ReReviewTable = data.data;
          this.totalRows = data.meta?.[0]?.totalItems || data.data.length;
        } else {
          console.error('Unexpected re-review table response format:', data);
          this.items_ReReviewTable = [];
          this.totalRows = 0;
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.items_ReReviewTable = [];
        this.totalRows = 0;
      } finally {
        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
        this.loadingReReviewManagment = false;
      }
    },
    async handleNewBatchAssignment() {
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/re_review/batch/assign?user_id=${
        this.user_id_assignment}`;

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
        this.makeToast('New batch assigned successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loadReReviewTableData();
    },
    // Apply filters and reset pagination
    applyFilters() {
      this.currentPage = 1;
    },
    async handleBatchUnAssignment(batch_id) {
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/re_review/batch/unassign?re_review_batch=${
        batch_id}`;

      try {
        const response = await this.axios.delete(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Batch unassigned successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loadReReviewTableData();
    },
    onFiltered(filteredItems) {
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    onSortChanged(ctx) {
      // Handle sort change if needed
    },

    // Batch creation callback
    onBatchCreated() {
      // Refresh the assignment table after new batch is created
      this.loadReReviewTableData();
      this.loadAvailableEntities();
      this.makeToast('Batch created and table refreshed', 'Success', 'success');
    },

    // Load available entities for manual assignment (RRV-06)
    async loadAvailableEntities() {
      this.isLoadingEntities = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/preview`;

      try {
        // Get entities not in any active batch (preview with no criteria = all available)
        const response = await this.axios.post(apiUrl, { batch_size: 100 }, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.availableEntities = response.data.data || [];
        this.selectedEntityIds = [];
      } catch (e) {
        this.makeToast('Failed to load available entities', 'Error', 'danger');
      } finally {
        this.isLoadingEntities = false;
      }
    },

    // Handle entity selection from table
    onEntitySelected(items) {
      this.selectedEntityIds = items.map((item) => item.entity_id);
    },

    // Assign selected entities to user (RRV-06)
    async handleEntityAssignment() {
      if (this.selectedEntityIds.length === 0) {
        this.makeToast('Please select at least one entity', 'Validation', 'warning');
        return;
      }
      if (!this.entityAssignUserId) {
        this.makeToast('Please select a user', 'Validation', 'warning');
        return;
      }

      this.isAssigningEntities = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/entities/assign`;

      try {
        const response = await this.axios.put(apiUrl, {
          entity_ids: this.selectedEntityIds,
          user_id: this.entityAssignUserId,
          batch_name: this.entityAssignBatchName || null,
        }, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        const result = response.data.entry;
        this.makeToast(
          `Created batch ${result.batch_id} with ${result.entity_count} entities`,
          'Success',
          'success',
        );

        // Reset and refresh
        this.selectedEntityIds = [];
        this.entityAssignUserId = null;
        this.entityAssignBatchName = '';
        this.loadReReviewTableData();
        this.loadAvailableEntities();
      } catch (e) {
        this.makeToast(e.response?.data?.message || 'Assignment failed', 'Error', 'danger');
      } finally {
        this.isAssigningEntities = false;
      }
    },

    // Reassignment methods
    openReassignModal(item) {
      this.reassignBatchId = item.re_review_batch;
      this.reassignNewUserId = item.user_id; // Pre-select current user
      this.reassignModalShow = true;
    },

    async handleBatchReassignment() {
      if (!this.reassignNewUserId) {
        this.makeToast('Please select a user', 'Validation', 'warning');
        return;
      }

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/reassign?re_review_batch=${this.reassignBatchId}&user_id=${this.reassignNewUserId}`;

      try {
        await this.axios.put(apiUrl, {}, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Batch reassigned successfully', 'Success', 'success');
        this.reassignModalShow = false;
        this.loadReReviewTableData();
      } catch (e) {
        this.makeToast(e.response?.data?.message || 'Reassignment failed', 'Error', 'danger');
      }
    },

    // Recalculation methods (RRV-05)
    openRecalculateModal(item) {
      this.recalculateBatchId = item.re_review_batch;
      // Reset criteria to defaults
      this.recalculateCriteria = {
        date_range: { start: null, end: null },
        gene_list: [],
        status_filter: null,
        batch_size: 20,
      };
      this.recalculateModalShow = true;
    },

    async handleBatchRecalculation() {
      this.isRecalculating = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/recalculate`;

      try {
        // Build criteria payload
        const payload = {
          re_review_batch: this.recalculateBatchId,
          batch_size: this.recalculateCriteria.batch_size,
        };

        if (this.recalculateCriteria.date_range.start && this.recalculateCriteria.date_range.end) {
          payload.date_range = this.recalculateCriteria.date_range;
        }

        if (this.recalculateCriteria.status_filter !== null) {
          payload.status_filter = this.recalculateCriteria.status_filter;
        }

        const response = await this.axios.put(apiUrl, payload, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        const result = response.data.entry;
        this.makeToast(
          `Batch ${result.batch_id} recalculated with ${result.entity_count} entities`,
          'Success',
          'success',
        );
        this.recalculateModalShow = false;
        this.loadReReviewTableData();
        this.loadAvailableEntities();
      } catch (e) {
        const message = e.response?.data?.message || 'Recalculation failed';
        this.makeToast(message, 'Error', 'danger');
      } finally {
        this.isRecalculating = false;
      }
    },

    // Load status options for recalculate modal
    async loadStatusOptions() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        const responseData = response.data;
        // Handle paginated response format
        const data = responseData?.data || responseData;
        this.status_options = Array.isArray(data)
          ? data.map((item) => ({
            value: item.category_id,
            text: item.category,
          }))
          : [];
      } catch (e) {
        this.status_options = [];
      }
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.2rem 0.35rem;
  font-size: 0.8rem;
  line-height: 1;
  border-radius: 0.2rem;
}

/* Action buttons - solid, visible icons */
.btn-action {
  padding: 0.25rem 0.5rem;
  font-size: 0.85rem;
  line-height: 1;
  border-radius: 0.25rem;
  min-width: 32px;
}

.btn-action i {
  font-size: 0.9rem;
}

/* Count badges in table */
.count-badge {
  min-width: 28px;
  font-weight: 500;
}

/* Light variant for zero counts */
.badge.bg-light {
  color: #6c757d;
  background-color: #f8f9fa !important;
  border: 1px solid #dee2e6;
}

/* Monospace for batch IDs */
.font-monospace {
  font-family: SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.9em;
}

/* Table compact styling */
:deep(.table) {
  font-size: 0.875rem;
}

:deep(.table th),
:deep(.table td) {
  padding: 0.4rem 0.5rem;
  vertical-align: middle;
}

/* Help icon styling */
.bi-question-circle {
  font-size: 0.85rem;
  cursor: help;
}
</style>
