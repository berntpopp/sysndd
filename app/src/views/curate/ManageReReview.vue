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

          <ReReviewAssignmentTable
            v-model:filter="filter"
            v-model:user-filter="userFilter"
            v-model:assignment-filter="assignmentFilter"
            v-model:user-id-assignment="user_id_assignment"
            class="re-review-section--table"
            :user-filter-options="userFilterOptions"
            :assignment-filter-options="assignmentFilterOptions"
            :user-options="user_options"
            :filtered-count="filteredItems.length"
            :paginated-items="paginatedItems"
            :loading="loadingReReviewManagment"
            :per-page="perPage"
            :current-page="currentPage"
            :page-options="pageOptions"
            :total-rows="totalRows"
            :sort-by="sortBy"
            @apply-filters="applyFilters"
            @refresh="loadReReviewTableData"
            @page-change="handlePageChange"
            @per-page-change="handlePerPageChange"
            @sort-update="handleSortUpdate"
            @new-batch-assignment="handleNewBatchAssignment"
            @open-recalculate="openRecalculateModal"
            @open-reassign="openReassignModal"
            @unassign="handleBatchUnAssignment"
          />

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
import { onMounted } from 'vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { useToast, useAriaLive } from '@/composables';
import BatchCriteriaForm from '@/components/forms/BatchCriteriaForm.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';
import ManualEntityAssignmentPanel from '@/views/curate/components/ManualEntityAssignmentPanel.vue';
import ReReviewAssignmentTable from '@/views/curate/components/ReReviewAssignmentTable.vue';
import RefusedReReviewPanel from '@/views/curate/components/RefusedReReviewPanel.vue';
import {
  reReviewEntitySelectFields,
  reReviewLegendItems,
} from '@/views/curate/reReviewTableConfig';
import { useManageReReview } from '@/views/curate/composables/useManageReReview';

export default {
  name: 'ManageReReview',
  components: {
    AuthenticatedPageShell,
    BatchCriteriaForm,
    AriaLiveRegion,
    IconLegend,
    ManualEntityAssignmentPanel,
    ReReviewAssignmentTable,
    RefusedReReviewPanel,
  },
  setup() {
    const { makeToast } = useToast();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();

    const controller = useManageReReview({
      onToast: makeToast,
      announce,
    });

    // Fire the four mount loaders concurrently (matches the original mounted()).
    onMounted(controller.initialize);

    return {
      ...controller,
      // static display config (read-only) consumed by the shell's child panels
      entitySelectFields: reReviewEntitySelectFields,
      legendItems: reReviewLegendItems,
      // a11y
      a11yMessage,
      a11yPoliteness,
    };
  },
};
</script>

<style scoped>
/* Page-level layout + batch-setup shell styles. The submissions table styling
   lives with ReReviewAssignmentTable.vue; the modals carry no scoped styles. */
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
  border: 1px solid var(--border-subtle);
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

.re-review-section {
  overflow: hidden;
  border: 1px solid var(--border-subtle);
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

.re-review-section__header h2 {
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
  border: 1px solid var(--border-subtle);
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
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #f8fafc;
  color: #526070;
  font-size: 0.84rem;
}

.re-review-mode-intro strong {
  color: #172033;
  font-size: 0.9rem;
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

.re-review-section--table {
  order: 2;
}

@media (max-width: 767.98px) {
  .re-review-summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .re-review-setup-choice {
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
