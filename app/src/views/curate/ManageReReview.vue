<!-- src/views/curate/ManageReReview.vue -->
<template>
  <AuthenticatedPageShell
    title="Manage Re-review"
    description="Create batches, assign entities, and manage re-review submission progress."
    content-class="authenticated-route-content"
    full-width
  >
    <div class="re-review-page">
      <BContainer fluid class="px-0">
        <div class="re-review-layout">
          <div class="re-review-summary" aria-label="Re-review overview">
            <div class="re-review-metric">
              <span class="re-review-metric__label">Batches</span>
              <strong>{{ totalRows }}</strong>
            </div>
            <div class="re-review-metric">
              <span class="re-review-metric__label">Assigned</span>
              <strong>{{ assignedBatchCount }}</strong>
            </div>
            <div class="re-review-metric">
              <span class="re-review-metric__label">Unassigned</span>
              <strong>{{ unassignedBatchCount }}</strong>
            </div>
            <div class="re-review-metric">
              <span class="re-review-metric__label">Available entities</span>
              <strong>{{ availableEntities.length }}</strong>
            </div>
          </div>

          <div class="re-review-workflow-grid">
            <section class="re-review-section" aria-labelledby="batch-setup-title">
              <header class="re-review-section__header">
                <div>
                  <h2 id="batch-setup-title">
                    <i class="bi bi-plus-square me-1" aria-hidden="true" />
                    Create batch
                  </h2>
                  <p>Build a dynamic batch from explicit entities or review criteria.</p>
                </div>
                <div class="re-review-section__actions">
                  <BButton
                    v-b-toggle.batch-form-collapse
                    variant="outline-primary"
                    size="sm"
                    class="re-review-icon-button"
                    aria-label="Toggle batch creation form"
                  >
                    <i class="bi bi-chevron-down" aria-hidden="true" />
                  </BButton>
                </div>
              </header>
              <BCollapse id="batch-form-collapse">
                <div class="re-review-section__body">
                  <BatchCriteriaForm @batch-created="onBatchCreated" />
                </div>
              </BCollapse>
            </section>

            <section class="re-review-section" aria-labelledby="assignment-title">
              <header class="re-review-section__header">
                <div>
                  <h2 id="assignment-title">
                    <i class="bi bi-person-plus me-1" aria-hidden="true" />
                    Manual assignment
                  </h2>
                  <p>Use only when a batch must contain hand-picked entities.</p>
                </div>
                <div class="re-review-section__actions">
                  <span class="re-review-chip" :class="{ 'is-selected': selectedEntityIds.length }">
                    {{ selectedEntityIds.length }} selected
                  </span>
                  <BButton
                    v-b-toggle.entity-assign-collapse
                    variant="outline-primary"
                    size="sm"
                    class="re-review-icon-button"
                    aria-label="Toggle manual assignment form"
                  >
                    <i class="bi bi-chevron-down" aria-hidden="true" />
                  </BButton>
                </div>
              </header>
              <BCollapse id="entity-assign-collapse">
                <div class="re-review-section__body re-review-section__body--assignment">
                  <BFormGroup
                    label="Entities"
                    label-for="entity-select-table"
                    class="mb-3 re-review-entity-picker"
                  >
                    <BTable
                      id="entity-select-table"
                      :items="availableEntities"
                      :fields="entitySelectFields"
                      selectable
                      select-mode="multi"
                      small
                      hover
                      responsive
                      :busy="isLoadingEntities"
                      class="re-review-pick-table"
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
                      {{ selectedEntityIds.length }} selected. Click rows to select or clear.
                    </small>
                  </BFormGroup>

                  <div class="re-review-assignment-grid">
                    <BFormGroup label="Assign to" label-for="entity-assign-user" class="mb-0">
                      <BFormSelect
                        id="entity-assign-user"
                        v-model="entityAssignUserId"
                        :options="user_options"
                        size="sm"
                        aria-label="Select user to assign selected entities to"
                      >
                        <template #first>
                          <option :value="null" disabled>Select a user</option>
                        </template>
                      </BFormSelect>
                    </BFormGroup>

                    <BFormGroup
                      label="Batch name"
                      label-for="entity-assign-batch-name"
                      class="mb-0"
                    >
                      <BFormInput
                        id="entity-assign-batch-name"
                        v-model="entityAssignBatchName"
                        size="sm"
                        placeholder="Auto-generated"
                        aria-label="Custom name for the new batch"
                      />
                    </BFormGroup>
                  </div>

                  <BAlert
                    v-if="boundaryGeneAlertVisible"
                    variant="warning"
                    show
                    class="my-3"
                    data-testid="batch-boundary-gene-alert"
                  >
                    <i class="bi bi-exclamation-triangle me-1" aria-hidden="true" />
                    {{ boundaryGeneAlertMessage }}
                  </BAlert>

                  <div class="re-review-button-row">
                    <BButton
                      variant="primary"
                      size="sm"
                      :disabled="
                        selectedEntityIds.length === 0 || !entityAssignUserId || isAssigningEntities
                      "
                      @click="handleEntityAssignment"
                    >
                      <BSpinner v-if="isAssigningEntities" small class="me-1" />
                      <i v-else class="bi bi-person-plus me-1" aria-hidden="true" />
                      Assign selected
                    </BButton>
                    <BButton
                      variant="outline-secondary"
                      size="sm"
                      aria-label="Refresh entity list"
                      @click="loadAvailableEntities"
                    >
                      <i class="bi bi-arrow-clockwise me-1" aria-hidden="true" />
                      Refresh
                    </BButton>
                  </div>
                </div>
              </BCollapse>
            </section>
          </div>

          <div class="re-review-legend-wrap">
            <IconLegend :legend-items="legendItems" class="re-review-legend mb-0" />
          </div>

          <section
            class="re-review-section re-review-section--table"
            aria-labelledby="submissions-title"
          >
            <header class="re-review-section__header re-review-section__header--table">
              <div>
                <h2 id="submissions-title">Submissions</h2>
                <p>Filter, assign, recalculate, and reassign re-review batches.</p>
              </div>
              <div class="re-review-section__actions">
                <span class="re-review-chip">{{ filteredItems.length }} shown</span>
                <BButton
                  id="btn-refresh-table"
                  size="sm"
                  variant="outline-secondary"
                  class="re-review-icon-button"
                  :disabled="loadingReReviewManagment"
                  aria-label="Refresh table data"
                  @click="loadReReviewTableData"
                >
                  <BSpinner v-if="loadingReReviewManagment" small />
                  <i v-else class="bi bi-arrow-clockwise" aria-hidden="true" />
                </BButton>
                <BTooltip target="btn-refresh-table" triggers="hover">
                  Refresh table data
                </BTooltip>
              </div>
            </header>

            <div class="re-review-toolbar">
              <div class="re-review-toolbar__search">
                <BInputGroup size="sm" class="re-review-search">
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
              </div>
              <div>
                <BFormSelect
                  v-model="userFilter"
                  :options="userFilterOptions"
                  size="sm"
                  @update:model-value="applyFilters"
                >
                  <template #first>
                    <BFormSelectOption :value="null"> All Users </BFormSelectOption>
                  </template>
                </BFormSelect>
              </div>
              <div>
                <BFormSelect
                  v-model="assignmentFilter"
                  :options="assignmentFilterOptions"
                  size="sm"
                  @update:model-value="applyFilters"
                >
                  <template #first>
                    <BFormSelectOption :value="null"> All Status </BFormSelectOption>
                  </template>
                </BFormSelect>
              </div>
              <div>
                <BFormSelect
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                  aria-label="Rows per page"
                />
              </div>
            </div>

            <div class="re-review-legacy-strip">
              <div class="re-review-legacy-strip__controls">
                <span class="re-review-legacy-strip__label">Assign next legacy batch</span>
                <BFormSelect
                  v-model="user_id_assignment"
                  :options="user_options"
                  size="sm"
                  class="re-review-user-select"
                  aria-label="Select user for next legacy batch"
                >
                  <template #first>
                    <BFormSelectOption :value="0" disabled>Select user</BFormSelectOption>
                  </template>
                </BFormSelect>
                <BButton
                  size="sm"
                  variant="outline-secondary"
                  :disabled="!user_id_assignment"
                  aria-label="Assign next available pre-computed batch to selected user"
                  @click="handleNewBatchAssignment"
                >
                  <i class="bi bi-plus-square me-1" aria-hidden="true" />
                  Assign
                </BButton>
                <i
                  id="help-legacy-batch"
                  class="bi bi-question-circle text-muted"
                  aria-hidden="true"
                />
                <BTooltip target="help-legacy-batch" placement="right" triggers="hover">
                  Assign next available pre-computed batch. Use 'Create New Batch' above for dynamic
                  batches.
                </BTooltip>
              </div>
              <span class="re-review-range">
                Showing {{ Math.min((currentPage - 1) * perPage + 1, totalRows) }}-{{
                  Math.min(currentPage * perPage, totalRows)
                }}
                of {{ totalRows }}
              </span>
            </div>

            <!-- Table with Loading State -->
            <div class="position-relative re-review-table-wrap">
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
                <p class="text-muted mt-2">No batches found</p>
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
                      :class="
                        row.item.user_id
                          ? 'bi bi-person-fill text-primary'
                          : 'bi bi-person text-muted'
                      "
                      aria-hidden="true"
                    />
                    <BBadge :variant="row.item.user_id ? 'primary' : 'secondary'">
                      {{ row.item.user_name || 'Unassigned' }}
                    </BBadge>
                  </div>
                </template>

                <!-- Batch ID column -->
                <template #cell(re_review_batch)="row">
                  <span class="font-monospace"> #{{ row.item.re_review_batch }} </span>
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
                      :aria-label="`Recalculate batch ${data.item.re_review_batch}`"
                      @click="openRecalculateModal(data.item)"
                    >
                      <i class="bi bi-calculator" aria-hidden="true" />
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
                      :aria-label="`Reassign batch ${data.item.re_review_batch}`"
                      @click="openReassignModal(data.item)"
                    >
                      <i class="bi bi-person-lines-fill" aria-hidden="true" />
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
                      :aria-label="`Unassign batch ${data.item.re_review_batch}`"
                      @click="handleBatchUnAssignment(data.item.re_review_batch)"
                    >
                      <i class="bi bi-person-dash-fill" aria-hidden="true" />
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
            <BRow v-if="totalRows > perPage" class="px-2 py-2">
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
          </section>
        </div>
      </BContainer>

      <!-- Reassign Modal -->
      <BModal
        v-model="reassignModalShow"
        title="Reassign Batch"
        ok-title="Reassign"
        cancel-title="Cancel"
        header-close-label="Close"
        @ok="handleBatchReassignment"
      >
        <BFormGroup label="Select new user:" label-for="reassign-user-select">
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
        header-close-label="Close"
        :ok-disabled="isRecalculating"
        @ok="handleBatchRecalculation"
      >
        <BAlert variant="info" show class="mb-3">
          <i class="bi bi-info-circle me-1" />
          This will replace the current entities in batch {{ recalculateBatchId }} with entities
          matching the new criteria. Only unassigned batches can be recalculated.
        </BAlert>

        <!-- Date Range -->
        <BFormGroup label="Review Date Range" class="mb-3">
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
        <BFormGroup label="Status Category" class="mb-3">
          <BFormSelect
            v-model="recalculateCriteria.status_filter"
            :options="status_options"
            :disabled="isRecalculating"
            aria-label="Filter by entity status category"
          >
            <template #first>
              <option :value="null">-- Any status --</option>
            </template>
          </BFormSelect>
        </BFormGroup>

        <!-- Batch Size -->
        <BFormGroup label="Batch Size" class="mb-3">
          <BFormInput
            v-model.number="recalculateCriteria.batch_size"
            type="number"
            min="1"
            max="100"
            :disabled="isRecalculating"
            aria-label="Maximum number of entities in recalculated batch"
          />
        </BFormGroup>

        <BSpinner v-if="isRecalculating" class="me-2" small />
      </BModal>

      <!-- AriaLiveRegion for screen reader announcements -->
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />
    </div>
  </AuthenticatedPageShell>
</template>

<script>
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { useToast, useAriaLive } from '@/composables';
import BatchCriteriaForm from '@/components/forms/BatchCriteriaForm.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';

// v11.0 closeout F2d: typed api client. The request interceptor in
// `@/api/client` reads `useAuth().token.value` on every outbound call and
// injects `Authorization: Bearer <token>` — no inline header construction
// here.
import { apiClient } from '@/api/client';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ManageReReview',
  components: {
    AuthenticatedPageShell,
    BatchCriteriaForm,
    AriaLiveRegion,
    IconLegend,
  },
  setup() {
    const { makeToast } = useToast();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();
    return { makeToast, a11yMessage, a11yPoliteness, announce };
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

      // Gene-atomic batch boundary hint (issue #29)
      // Set by loadAvailableEntities() from batch_preview's boundary_gene field.
      // Non-null when the preview soft-LIMIT engaged and a gene was partially included.
      previewBoundaryGene: null,
      previewGeneCount: 0,
      previewEntityCount: 0,
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

      // Icon legend items for ManageReReview
      legendItems: [
        { icon: 'bi bi-person-fill', color: '#0d6efd', label: 'Assigned user' },
        { icon: 'bi bi-person', color: '#6c757d', label: 'Unassigned batch' },
        { icon: 'bi bi-calculator', color: '#6c757d', label: 'Recalculate batch' },
        { icon: 'bi bi-person-lines-fill', color: '#b45309', label: 'Reassign batch' },
        { icon: 'bi bi-person-dash-fill', color: '#dc3545', label: 'Unassign batch' },
      ],
    };
  },
  computed: {
    assignedBatchCount() {
      return this.items_ReReviewTable.filter((item) => item.user_id).length;
    },
    unassignedBatchCount() {
      return this.items_ReReviewTable.filter((item) => !item.user_id).length;
    },
    // Gene-atomic boundary alert computed properties (issue #29)
    boundaryGeneAlertVisible() {
      return Boolean(this.previewBoundaryGene);
    },
    boundaryGeneAlertMessage() {
      if (!this.previewBoundaryGene) return '';
      return (
        `Batch is gene-atomic: to keep gene ${this.previewBoundaryGene} together, ` +
        `the available-entity list holds ${this.previewEntityCount} entities across ` +
        `${this.previewGeneCount} gene(s). The last gene was extended past the ` +
        `batch_size cap to avoid splitting it. Tighten criteria or increase ` +
        `batch size to avoid the overflow.`
      );
    },

    // Filter options derived from loaded data
    userFilterOptions() {
      const uniqueUsers = [
        ...new Set(
          this.items_ReReviewTable.filter((item) => item.user_name).map((item) => item.user_name)
        ),
      ];
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

      return items;
    },
  },
  watch: {
    filteredItems(newItems) {
      this.totalRows = newItems.length;
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
        const data = await apiClient.get(apiUrl);
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
        const data = await apiClient.get(apiUrl);
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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/assign?user_id=${
        this.user_id_assignment
      }`;

      try {
        await apiClient.put(apiUrl, {});
        this.makeToast('New batch assigned successfully.', 'Success', 'success');
        this.announce('New batch assigned successfully');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to assign batch', 'assertive');
      }
      this.loadReReviewTableData();
    },
    // Apply filters and reset pagination
    applyFilters() {
      this.currentPage = 1;
    },
    async handleBatchUnAssignment(batch_id) {
      const apiUrl = `${
        import.meta.env.VITE_API_URL
      }/api/re_review/batch/unassign?re_review_batch=${batch_id}`;

      try {
        await apiClient.delete(apiUrl);
        this.makeToast('Batch unassigned successfully.', 'Success', 'success');
        this.announce('Batch unassigned successfully');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to unassign batch', 'assertive');
      }
      this.loadReReviewTableData();
    },
    onFiltered(filteredItems) {
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    onSortChanged(_ctx) {
      // Handle sort change if needed
    },

    // Batch creation callback
    onBatchCreated() {
      // Refresh the assignment table after new batch is created
      this.loadReReviewTableData();
      this.loadAvailableEntities();
      this.makeToast('Batch created and table refreshed', 'Success', 'success');
      this.announce('Batch created successfully');
    },

    // Load available entities for manual assignment (RRV-06)
    async loadAvailableEntities() {
      this.isLoadingEntities = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/preview`;

      try {
        // Get entities not in any active batch (preview with no criteria = all available)
        const responseData = await apiClient.post(apiUrl, { batch_size: 100 });
        this.availableEntities = responseData.data || [];
        this.selectedEntityIds = [];
        // Capture gene-atomic boundary hint (issue #29): boundary_gene is non-null
        // when the soft-LIMIT extended the last gene past batch_size.
        // BatchServiceResponse uses [key: string]: unknown so values flow through
        // without type assertions in this plain-JS Options API component.
        this.previewBoundaryGene = responseData.boundary_gene ?? null;
        this.previewGeneCount = responseData.gene_count ?? 0;
        this.previewEntityCount = responseData.entity_count ?? 0;
      } catch (_e) {
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
        const responseData = await apiClient.put(apiUrl, {
          entity_ids: this.selectedEntityIds,
          user_id: this.entityAssignUserId,
          batch_name: this.entityAssignBatchName || null,
        });

        const result = responseData.entry;
        this.makeToast(
          `Created batch ${result.batch_id} with ${result.entity_count} entities`,
          'Success',
          'success'
        );
        this.announce(`Created batch ${result.batch_id} with ${result.entity_count} entities`);

        // Reset and refresh
        this.selectedEntityIds = [];
        this.entityAssignUserId = null;
        this.entityAssignBatchName = '';
        this.loadReReviewTableData();
        this.loadAvailableEntities();
      } catch (e) {
        this.makeToast(e.response?.data?.message || 'Assignment failed', 'Error', 'danger');
        this.announce('Failed to assign entities', 'assertive');
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
        await apiClient.put(apiUrl, {});
        this.makeToast('Batch reassigned successfully', 'Success', 'success');
        this.announce('Batch reassigned successfully');
        this.reassignModalShow = false;
        this.loadReReviewTableData();
      } catch (e) {
        this.makeToast(e.response?.data?.message || 'Reassignment failed', 'Error', 'danger');
        this.announce('Failed to reassign batch', 'assertive');
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

        const responseData = await apiClient.put(apiUrl, payload);

        const result = responseData.entry;
        this.makeToast(
          `Batch ${result.batch_id} recalculated with ${result.entity_count} entities`,
          'Success',
          'success'
        );
        this.announce(`Batch ${result.batch_id} recalculated with ${result.entity_count} entities`);
        this.recalculateModalShow = false;
        this.loadReReviewTableData();
        this.loadAvailableEntities();
      } catch (e) {
        const message = e.response?.data?.message || 'Recalculation failed';
        this.makeToast(message, 'Error', 'danger');
        this.announce('Failed to recalculate batch', 'assertive');
      } finally {
        this.isRecalculating = false;
      }
    },

    // Load status options for recalculate modal
    async loadStatusOptions() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status`;
      try {
        const responseData = await apiClient.get(apiUrl);
        // Handle paginated response format
        const data = responseData?.data || responseData;
        this.status_options = Array.isArray(data)
          ? data.map((item) => ({
              value: item.category_id,
              text: item.category,
            }))
          : [];
      } catch (_e) {
        this.status_options = [];
      }
    },
  },
};
</script>

<style scoped>
.re-review-page {
  min-width: 0;
}

.re-review-layout {
  display: grid;
  gap: 1rem;
}

.re-review-summary {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
}

.re-review-metric {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  min-width: 0;
  padding: 0.65rem 0.85rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
}

.re-review-metric__label {
  overflow: hidden;
  color: #526070;
  font-size: 0.78rem;
  font-weight: 700;
  text-overflow: ellipsis;
  text-transform: uppercase;
  white-space: nowrap;
}

.re-review-metric strong {
  color: #172033;
  font-size: 1rem;
  line-height: 1;
}

.re-review-workflow-grid {
  order: 3;
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.re-review-section {
  overflow: hidden;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
}

.re-review-section__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.85rem 1rem;
  border-bottom: 1px solid #e6ebf2;
  background: #f8fafc;
}

.re-review-section__header--table {
  align-items: center;
}

.re-review-section__header > .row {
  flex: 1 1 auto;
  width: 100%;
}

.re-review-section__header h2,
.re-review-section__heading h2 {
  display: inline-flex;
  align-items: center;
  margin: 0;
  color: #172033;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.3;
}

.re-review-section__header p {
  margin: 0.15rem 0 0;
  color: #526070;
  font-size: 0.8125rem;
}

.re-review-section__heading {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
}

.re-review-section__body {
  padding: 1rem;
}

.re-review-section__body--assignment {
  display: grid;
  gap: 0.75rem;
}

.re-review-section__actions {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.45rem;
}

.re-review-chip {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  min-height: 1.45rem;
  padding: 0.15rem 0.5rem;
  border: 1px solid #d7dee8;
  border-radius: 999px;
  background: #fff;
  color: #526070;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.re-review-chip.is-selected {
  border-color: #b8d3f7;
  background: #eef6ff;
  color: #0b5cad;
}

.re-review-icon-button {
  display: inline-grid;
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  padding: 0;
  place-items: center;
}

.re-review-legend-wrap {
  order: 4;
  min-width: 0;
}

.re-review-legend-wrap :deep(.card),
.re-review-legend-wrap :deep(.border),
.re-review-legend-wrap :deep([class*='border']) {
  border-color: transparent !important;
  box-shadow: none !important;
}

.re-review-legend-wrap :deep(.card) {
  margin-bottom: 0 !important;
  background: transparent;
}

.re-review-legend-wrap :deep(.card-body) {
  padding: 0.35rem 0.1rem !important;
}

.re-review-legend-wrap :deep(strong) {
  color: #526070;
  font-size: 0.78rem;
  text-transform: uppercase;
}

.re-review-toolbar {
  display: grid;
  grid-template-columns: minmax(16rem, 2fr) minmax(11rem, 1fr) minmax(10rem, 0.9fr) minmax(
      7rem,
      0.6fr
    );
  gap: 0.55rem;
  padding: 0.8rem 1rem 0.6rem;
  border-bottom: 1px solid #edf1f6;
  background: #fff;
}

.re-review-toolbar > * {
  min-width: 0;
}

.re-review-search :deep(.input-group-text) {
  border-color: #cfd7e3;
  background: #fff;
  color: #526070;
}

.re-review-legacy-strip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0 1rem 0.75rem;
  border-bottom: 1px solid #edf1f6;
  background: #fff;
}

.re-review-legacy-strip__controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}

.re-review-legacy-strip__label,
.re-review-range {
  color: #526070;
  font-size: 0.78rem;
  font-weight: 700;
}

.re-review-user-select {
  width: 12rem;
  max-width: 100%;
}

.re-review-table-wrap {
  padding: 0.75rem;
}

.re-review-section--table {
  order: 2;
}

.re-review-assignment-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 0.75rem;
}

.re-review-button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.re-review-entity-picker {
  min-width: 0;
}

.re-review-pick-table {
  margin-bottom: 0;
}

.btn-group-xs > .btn,
.btn-xs {
  padding: 0.2rem 0.35rem;
  font-size: 0.8rem;
  line-height: 1;
  border-radius: 0.2rem;
}

/* Action buttons - solid, visible icons */
.btn-action {
  display: inline-grid;
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  padding: 0;
  font-size: 0.85rem;
  line-height: 1;
  border-radius: 6px;
  place-items: center;
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

:deep(.table-responsive) {
  margin-bottom: 0;
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

@media (max-width: 1199.98px) {
  .re-review-workflow-grid {
    grid-template-columns: 1fr;
  }

  .re-review-toolbar {
    grid-template-columns: minmax(14rem, 1fr) minmax(10rem, 1fr);
  }
}

@media (max-width: 767.98px) {
  .re-review-summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .re-review-toolbar {
    grid-template-columns: 1fr;
  }

  .re-review-legacy-strip {
    align-items: flex-start;
    flex-direction: column;
  }

  .re-review-assignment-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 575.98px) {
  .re-review-summary {
    grid-template-columns: 1fr;
  }

  .re-review-section__header {
    align-items: stretch;
    flex-direction: column;
    padding: 0.8rem;
  }

  .re-review-section__body {
    padding: 0.8rem;
  }
}
</style>
