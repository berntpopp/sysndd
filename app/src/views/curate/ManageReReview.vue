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

          <section
            class="re-review-section re-review-section--setup"
            aria-labelledby="batch-setup-title"
          >
            <header class="re-review-section__header re-review-section__header--setup">
              <div>
                <h2 id="batch-setup-title">
                  <i class="bi bi-plus-square me-1" aria-hidden="true" />
                  Batch setup
                </h2>
                <p>
                  Choose the normal criteria workflow or hand-pick entities for an exception batch.
                </p>
              </div>
              <BButtonGroup
                v-if="activeBatchMode"
                size="sm"
                class="re-review-mode-switch"
                aria-label="Batch setup mode"
              >
                <BButton
                  :variant="activeBatchMode === 'criteria' ? 'primary' : 'outline-secondary'"
                  @click="activeBatchMode = 'criteria'"
                >
                  <i class="bi bi-funnel me-1" aria-hidden="true" />
                  Criteria batch
                </BButton>
                <BButton
                  :variant="activeBatchMode === 'manual' ? 'primary' : 'outline-secondary'"
                  @click="activeBatchMode = 'manual'"
                >
                  <i class="bi bi-list-check me-1" aria-hidden="true" />
                  Manual pick
                  <span v-if="selectedEntityIds.length" class="re-review-mode-count">
                    {{ selectedEntityIds.length }}
                  </span>
                </BButton>
              </BButtonGroup>
            </header>

            <div class="re-review-section__body">
              <div v-if="!activeBatchMode" class="re-review-setup-choice">
                <button
                  type="button"
                  class="re-review-choice-card"
                  @click="activeBatchMode = 'criteria'"
                >
                  <span class="re-review-choice-card__icon">
                    <i class="bi bi-funnel" aria-hidden="true" />
                  </span>
                  <span class="re-review-choice-card__body">
                    <strong>Criteria batch</strong>
                    <span>
                      Create the standard re-review batch from entities, genes, dates, status, and
                      size.
                    </span>
                  </span>
                  <span class="re-review-choice-card__action">Configure</span>
                </button>

                <button
                  type="button"
                  class="re-review-choice-card"
                  @click="activeBatchMode = 'manual'"
                >
                  <span class="re-review-choice-card__icon">
                    <i class="bi bi-list-check" aria-hidden="true" />
                  </span>
                  <span class="re-review-choice-card__body">
                    <strong>Manual pick</strong>
                    <span>Hand-pick exact entities only for exception batches.</span>
                  </span>
                  <span class="re-review-choice-card__action">Select entities</span>
                </button>
              </div>

              <div v-else-if="activeBatchMode === 'criteria'" class="re-review-mode-panel">
                <div class="re-review-mode-intro">
                  <strong>Criteria batch</strong>
                  <span>Configure a repeatable batch, preview the match, then create it.</span>
                  <BButton
                    size="sm"
                    variant="outline-secondary"
                    class="ms-auto"
                    @click="activeBatchMode = null"
                  >
                    Close setup
                  </BButton>
                </div>
                <BatchCriteriaForm @batch-created="onBatchCreated" />
              </div>

              <ManualEntityAssignmentPanel
                v-else
                v-model:entity-assign-user-id="entityAssignUserId"
                v-model:entity-assign-batch-name="entityAssignBatchName"
                v-model:manual-entity-filter="manualEntityFilter"
                :user-options="user_options"
                :selected-entity-ids="selectedEntityIds"
                :available-entities="availableEntities"
                :available-entity-total="availableEntityTotal"
                :entity-select-fields="entitySelectFields"
                :is-loading-entities="isLoadingEntities"
                :is-assigning-entities="isAssigningEntities"
                :boundary-gene-alert-visible="boundaryGeneAlertVisible"
                :boundary-gene-alert-message="boundaryGeneAlertMessage"
                @assign-entities="handleEntityAssignment"
                @refresh-entities="loadAvailableEntities"
                @clear-selection="clearManualSelection"
                @toggle-entity-selection="toggleEntitySelection"
                @close="activeBatchMode = null"
              />
            </div>
          </section>

          <div class="re-review-legend-wrap">
            <IconLegend :legend-items="legendItems" class="re-review-legend mb-0" />
          </div>

          <TableShell
            class="re-review-section--table"
            title="Submissions"
            :meta="`${filteredItems.length} shown`"
            description="Filter, assign, recalculate, and reassign re-review batches."
          >
            <template #actions>
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
              <BTooltip target="btn-refresh-table" triggers="hover"> Refresh table data </BTooltip>
            </template>

            <template #toolbar>
              <div class="re-review-toolbar">
                <div class="re-review-toolbar__search">
                  <TableSearchInput
                    v-model="filter"
                    placeholder="Search batches or users"
                    :debounce-time="300"
                    @update="applyFilters"
                    @clear="applyFilters"
                  />
                </div>
                <div>
                  <BFormSelect
                    v-model="userFilter"
                    :options="userFilterOptions"
                    size="sm"
                    @update:model-value="applyFilters"
                  >
                    <template #first>
                      <BFormSelectOption :value="null"> All users </BFormSelectOption>
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
                      <BFormSelectOption :value="null"> All status </BFormSelectOption>
                    </template>
                  </BFormSelect>
                </div>
                <TablePaginationControls
                  :total-rows="filteredItems.length"
                  :initial-per-page="perPage"
                  :current-page="currentPage"
                  :page-options="pageOptions"
                  @page-change="handlePageChange"
                  @per-page-change="handlePerPageChange"
                />
              </div>
            </template>

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
              <GenericTable
                v-else
                :items="paginatedItems"
                :fields="fields_ReReviewTable"
                :is-busy="loadingReReviewManagment"
                :class="{ 'opacity-50': loadingReReviewManagment }"
                :sort-by="sortBy"
                :stacked-mode="false"
                @update-sort="handleSortUpdate"
              >
                <!-- User column with badge -->
                <template #cell-user_name="{ row }">
                  <div class="d-flex align-items-center gap-1">
                    <i
                      :class="
                        row.user_id ? 'bi bi-person-fill text-primary' : 'bi bi-person text-muted'
                      "
                      aria-hidden="true"
                    />
                    <BBadge :variant="row.user_id ? 'primary' : 'secondary'">
                      {{ row.user_name || 'Unassigned' }}
                    </BBadge>
                  </div>
                </template>

                <!-- Batch ID column -->
                <template #cell-re_review_batch="{ row }">
                  <span class="font-monospace"> #{{ row.re_review_batch }} </span>
                </template>

                <!-- Progress columns with mini badges -->
                <template #cell-re_review_review_saved="{ row }">
                  <BBadge
                    :variant="row.re_review_review_saved > 0 ? 'info' : 'light'"
                    class="count-badge"
                  >
                    {{ row.re_review_review_saved }}
                  </BBadge>
                </template>

                <template #cell-re_review_status_saved="{ row }">
                  <BBadge
                    :variant="row.re_review_status_saved > 0 ? 'info' : 'light'"
                    class="count-badge"
                  >
                    {{ row.re_review_status_saved }}
                  </BBadge>
                </template>

                <template #cell-re_review_submitted="{ row }">
                  <BBadge
                    :variant="row.re_review_submitted > 0 ? 'warning' : 'light'"
                    class="count-badge"
                  >
                    {{ row.re_review_submitted }}
                  </BBadge>
                </template>

                <template #cell-re_review_approved="{ row }">
                  <BBadge
                    :variant="row.re_review_approved > 0 ? 'success' : 'light'"
                    class="count-badge"
                  >
                    {{ row.re_review_approved }}
                  </BBadge>
                </template>

                <template #cell-entity_count="{ row }">
                  <strong>{{ row.entity_count }}</strong>
                </template>

                <!-- Actions column -->
                <template #cell-actions="{ row }">
                  <div class="d-flex gap-1 justify-content-center">
                    <!-- Recalculate button (only for unassigned batches) -->
                    <BButton
                      v-if="!row.user_id"
                      :id="`btn-recalc-${row.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="secondary"
                      :aria-label="`Recalculate batch ${row.re_review_batch}`"
                      @click="openRecalculateModal(row)"
                    >
                      <i class="bi bi-calculator" aria-hidden="true" />
                    </BButton>
                    <BTooltip
                      v-if="!row.user_id"
                      :target="`btn-recalc-${row.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Recalculate batch contents
                    </BTooltip>

                    <!-- Reassign button (only for assigned batches) -->
                    <BButton
                      v-if="row.user_id"
                      :id="`btn-reassign-${row.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="warning"
                      :aria-label="`Reassign batch ${row.re_review_batch}`"
                      @click="openReassignModal(row)"
                    >
                      <i class="bi bi-person-lines-fill" aria-hidden="true" />
                    </BButton>
                    <BTooltip
                      v-if="row.user_id"
                      :target="`btn-reassign-${row.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Reassign to different user
                    </BTooltip>

                    <!-- Unassign button -->
                    <BButton
                      v-if="row.user_id"
                      :id="`btn-unassign-${row.re_review_batch}`"
                      size="sm"
                      class="btn-action"
                      variant="danger"
                      :aria-label="`Unassign batch ${row.re_review_batch}`"
                      @click="handleBatchUnAssignment(row.re_review_batch)"
                    >
                      <i class="bi bi-person-dash-fill" aria-hidden="true" />
                    </BButton>
                    <BTooltip
                      v-if="row.user_id"
                      :target="`btn-unassign-${row.re_review_batch}`"
                      placement="top"
                      triggers="hover"
                    >
                      Unassign this batch
                    </BTooltip>
                  </div>
                </template>
              </GenericTable>
            </div>
          </TableShell>

          <!-- Refused / needs-specialist surface (issue #54). Self-contained
               panel so this view does not grow past its size budget. -->
          <RefusedReReviewPanel
            class="re-review-section--refused"
            @cleared="loadReReviewTableData"
          />
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
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import ManualEntityAssignmentPanel from '@/views/curate/components/ManualEntityAssignmentPanel.vue';
import RefusedReReviewPanel from '@/views/curate/components/RefusedReReviewPanel.vue';
import { filterReReviewBatches, sortReReviewBatches } from '@/views/curate/utils/reReviewFilters';
import {
  reReviewTableFields,
  reReviewEntitySelectFields,
  reReviewLegendItems,
} from '@/views/curate/reReviewTableConfig';
import {
  assignReReviewBatch,
  assignReReviewEntities,
  getAssignmentTable,
  listAvailableReReviewEntities,
  recalculateReReviewBatch,
  reassignReReviewBatch,
  unassignReReviewBatch,
} from '@/api/re_review';
import { listUsersByRole } from '@/api/user';
import { listStatusCategories } from '@/api/list';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ManageReReview',
  components: {
    AuthenticatedPageShell,
    BatchCriteriaForm,
    AriaLiveRegion,
    IconLegend,
    TableShell,
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
    ManualEntityAssignmentPanel,
    RefusedReReviewPanel,
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
      activeBatchMode: null,
      loadingReReviewManagment: false,
      user_options: [],
      user_id_assignment: 0,
      items_ReReviewTable: [],
      sortBy: [{ key: 'user_name', order: 'asc' }],
      fields_ReReviewTable: reReviewTableFields,
      currentPage: 1,
      perPage: 25,
      totalRows: 0,
      pageOptions: [10, 25, 50, 100],

      // Gene-specific assignment (RRV-06)
      availableEntities: [],
      availableEntityTotal: 0,
      selectedEntityIds: [],
      manualEntityFilter: null,
      entityAssignUserId: null,
      entityAssignBatchName: '',
      isLoadingEntities: false,
      isAssigningEntities: false,

      // Gene-atomic batch boundary hint (issue #29)
      // Set by previewBatch() from batch_preview's boundary_gene field.
      // Non-null when the preview soft-LIMIT engaged and a gene was partially included.
      previewBoundaryGene: null,
      previewGeneCount: 0,
      previewEntityCount: 0,
      entitySelectFields: reReviewEntitySelectFields,

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
      legendItems: reReviewLegendItems,
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
      return filterReReviewBatches(this.items_ReReviewTable, {
        text: this.filter,
        userName: this.userFilter,
        assignment: this.assignmentFilter,
      });
    },
    sortedItems() {
      return sortReReviewBatches(this.filteredItems, this.sortBy);
    },
    paginatedItems() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedItems.slice(start, start + this.perPage);
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
      try {
        const data = await listUsersByRole({ roles: 'Curator,Reviewer' });
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
      try {
        const data = await getAssignmentTable();
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
      try {
        await assignReReviewBatch({ user_id: this.user_id_assignment });
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
    handlePageChange(page) {
      this.currentPage = page;
    },
    handlePerPageChange(perPage) {
      this.perPage = perPage;
      this.currentPage = 1;
    },
    async handleBatchUnAssignment(batch_id) {
      try {
        await unassignReReviewBatch({ re_review_batch: batch_id });
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
    handleSortUpdate({ sortBy, sortDesc }) {
      this.sortBy = [{ key: sortBy, order: sortDesc ? 'desc' : 'asc' }];
      this.currentPage = 1;
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

      try {
        const responseData = await listAvailableReReviewEntities({
          q: this.manualEntityFilter || '',
          page: 1,
          page_size: 100,
        });
        this.availableEntities = responseData.data || [];
        const total = responseData.meta?.total;
        this.availableEntityTotal = Array.isArray(total)
          ? (total[0] ?? this.availableEntities.length)
          : (total ?? this.availableEntities.length);
        this.previewBoundaryGene = null;
        this.previewGeneCount = 0;
        this.previewEntityCount = 0;
      } catch (_e) {
        this.makeToast('Failed to load available entities', 'Error', 'danger');
      } finally {
        this.isLoadingEntities = false;
      }
    },

    toggleEntitySelection(entityId) {
      if (this.selectedEntityIds.includes(entityId)) {
        this.selectedEntityIds = this.selectedEntityIds.filter((id) => id !== entityId);
        return;
      }
      this.selectedEntityIds = [...this.selectedEntityIds, entityId];
    },
    clearManualSelection() {
      this.selectedEntityIds = [];
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

      try {
        const responseData = await assignReReviewEntities({
          entity_ids: this.selectedEntityIds,
          user_id: this.entityAssignUserId,
          batch_name: this.entityAssignBatchName || null,
        });

        const result = responseData.entry;
        const message =
          result?.batch_id != null && result?.entity_count != null
            ? `Created batch ${result.batch_id} with ${result.entity_count} entities`
            : 'Created assignment batch, but the batch summary was unavailable';
        this.makeToast(message, 'Success', 'success');
        this.announce(message);

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

      try {
        await reassignReReviewBatch({
          re_review_batch: this.reassignBatchId,
          user_id: this.reassignNewUserId,
        });
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

        const responseData = await recalculateReReviewBatch(payload);

        const result = responseData.entry;
        const message =
          result?.batch_id != null && result?.entity_count != null
            ? `Batch ${result.batch_id} recalculated with ${result.entity_count} entities`
            : 'Batch recalculated, but the batch summary was unavailable';
        this.makeToast(message, 'Success', 'success');
        this.announce(message);
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
      try {
        const responseData = await listStatusCategories();
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

.re-review-section--setup {
  border-color: rgba(15, 23, 42, 0.1);
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.04);
}

.re-review-section__header--setup {
  align-items: center;
  background: #fff;
}

.re-review-mode-switch {
  flex: 0 0 auto;
}

.re-review-setup-choice {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.re-review-choice-card {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.8rem 0.9rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  color: inherit;
  text-align: left;
}

.re-review-choice-card:hover,
.re-review-choice-card:focus-visible {
  border-color: #9fc2f1;
  background: #f8fbff;
  outline: 0;
}

.re-review-choice-card__icon {
  display: inline-grid;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 8px;
  background: #eef6ff;
  color: #0b5cad;
  place-items: center;
}

.re-review-choice-card__body {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
}

.re-review-choice-card__body strong {
  color: #172033;
  font-size: 0.9rem;
}

.re-review-choice-card__body span {
  color: #526070;
  font-size: 0.8rem;
  line-height: 1.35;
}

.re-review-choice-card__action {
  color: #0b5cad;
  font-size: 0.78rem;
  font-weight: 700;
  white-space: nowrap;
}

.re-review-mode-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.25rem;
  height: 1.25rem;
  margin-left: 0.35rem;
  border-radius: 999px;
  background: currentColor;
  color: #fff;
  font-size: 0.72rem;
  line-height: 1;
}

.re-review-mode-panel {
  min-width: 0;
}

.re-review-mode-intro {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.45rem;
  margin-bottom: 0.85rem;
  padding: 0.65rem 0.75rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #f8fafc;
  color: #526070;
  font-size: 0.84rem;
}

.re-review-mode-intro strong {
  color: #172033;
  font-size: 0.9rem;
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

.re-review-manual-controls {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.75rem;
  align-items: end;
  padding: 0.75rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #f8fafc;
}

.re-review-picker-toolbar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.65rem;
}

.re-review-picker-toolbar__meta {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 2rem;
  padding: 0 0.65rem;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  color: #526070;
  font-size: 0.78rem;
  white-space: nowrap;
}

.re-review-picker-toolbar__meta strong {
  color: #172033;
}

.re-review-button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.re-review-entity-picker {
  min-width: 0;
}

.re-review-entity-picker :deep(.table-responsive) {
  max-height: 24rem;
  overflow: auto;
  border: 1px solid #edf1f6;
  border-radius: 8px;
}

.re-review-pick-table {
  margin-bottom: 0;
}

.re-review-row-checkbox {
  width: 1rem;
  height: 1rem;
  margin: 0;
  cursor: pointer;
}

.re-review-pick-table :deep(tr.re-review-pick-table__row--selected > td) {
  background: #eef6ff !important;
}

.re-review-disease-cell {
  display: inline-block;
  max-width: min(42rem, 100%);
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: bottom;
  white-space: nowrap;
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

  .re-review-setup-choice {
    grid-template-columns: 1fr;
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

  .re-review-manual-controls {
    grid-template-columns: 1fr;
  }

  .re-review-picker-toolbar {
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
