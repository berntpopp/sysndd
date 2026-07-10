<template>
  <TableShell
    title="Submissions"
    :meta="`${filteredCount} shown`"
    description="Filter, assign, recalculate, and reassign re-review batches."
  >
    <template #actions>
      <BButton
        id="btn-refresh-table"
        size="sm"
        variant="outline-secondary"
        class="re-review-icon-button"
        :disabled="loading"
        aria-label="Refresh table data"
        @click="$emit('refresh')"
      >
        <BSpinner v-if="loading" small />
        <i v-else class="bi bi-arrow-clockwise" aria-hidden="true" />
      </BButton>
      <BTooltip target="btn-refresh-table" triggers="hover"> Refresh table data </BTooltip>
    </template>

    <template #toolbar>
      <div class="re-review-toolbar">
        <div class="re-review-toolbar__search">
          <TableSearchInput
            :model-value="filter"
            placeholder="Search batches or users"
            :debounce-time="300"
            @update:model-value="updateFilter"
            @update="$emit('apply-filters')"
            @clear="$emit('apply-filters')"
          />
        </div>
        <div>
          <BFormSelect
            :model-value="userFilter"
            :options="userFilterOptions"
            size="sm"
            @update:model-value="updateUserFilter"
          >
            <template #first>
              <BFormSelectOption :value="null"> All users </BFormSelectOption>
            </template>
          </BFormSelect>
        </div>
        <div>
          <BFormSelect
            :model-value="assignmentFilter"
            :options="assignmentFilterOptions"
            size="sm"
            @update:model-value="updateAssignmentFilter"
          >
            <template #first>
              <BFormSelectOption :value="null"> All status </BFormSelectOption>
            </template>
          </BFormSelect>
        </div>
        <TablePaginationControls
          :total-rows="filteredCount"
          :initial-per-page="perPage"
          :current-page="currentPage"
          :page-options="pageOptions"
          @page-change="$emit('page-change', $event)"
          @per-page-change="$emit('per-page-change', $event)"
        />
      </div>
    </template>

    <div class="re-review-legacy-strip">
      <div class="re-review-legacy-strip__controls">
        <span class="re-review-legacy-strip__label">Assign next legacy batch</span>
        <BFormSelect
          :model-value="userIdAssignment"
          :options="userOptions"
          size="sm"
          class="re-review-user-select"
          aria-label="Select user for next legacy batch"
          @update:model-value="updateUserIdAssignment"
        >
          <template #first>
            <BFormSelectOption :value="0" disabled>Select user</BFormSelectOption>
          </template>
        </BFormSelect>
        <BButton
          size="sm"
          variant="outline-secondary"
          :disabled="!userIdAssignment"
          aria-label="Assign next available pre-computed batch to selected user"
          @click="$emit('new-batch-assignment')"
        >
          <i class="bi bi-plus-square me-1" aria-hidden="true" />
          Assign
        </BButton>
        <i id="help-legacy-batch" class="bi bi-question-circle text-muted" aria-hidden="true" />
        <BTooltip target="help-legacy-batch" placement="right" triggers="hover">
          Assign next available pre-computed batch. Use 'Create New Batch' above for dynamic batches.
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
        v-if="loading"
        class="position-absolute top-50 start-50 translate-middle"
        variant="primary"
      />
      <div v-if="!loading && filteredCount === 0" class="text-center py-4">
        <i class="bi bi-inbox fs-1 text-muted" />
        <p class="text-muted mt-2">No batches found</p>
      </div>
      <GenericTable
        v-else
        :items="paginatedItems"
        :fields="fields"
        :is-busy="loading"
        :class="{ 'opacity-50': loading }"
        :sort-by="sortBy"
        :stacked-mode="false"
        @update-sort="$emit('sort-update', $event)"
      >
        <!-- User column with badge -->
        <template #cell-user_name="{ row }">
          <div class="d-flex align-items-center gap-1">
            <i
              :class="row.user_id ? 'bi bi-person-fill text-primary' : 'bi bi-person text-muted'"
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
          <BBadge :variant="row.re_review_review_saved > 0 ? 'info' : 'light'" class="count-badge">
            {{ row.re_review_review_saved }}
          </BBadge>
        </template>

        <template #cell-re_review_status_saved="{ row }">
          <BBadge :variant="row.re_review_status_saved > 0 ? 'info' : 'light'" class="count-badge">
            {{ row.re_review_status_saved }}
          </BBadge>
        </template>

        <template #cell-re_review_submitted="{ row }">
          <BBadge :variant="row.re_review_submitted > 0 ? 'warning' : 'light'" class="count-badge">
            {{ row.re_review_submitted }}
          </BBadge>
        </template>

        <template #cell-re_review_approved="{ row }">
          <BBadge :variant="row.re_review_approved > 0 ? 'success' : 'light'" class="count-badge">
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
              @click="$emit('open-recalculate', row)"
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
              @click="$emit('open-reassign', row)"
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
              @click="$emit('unassign', row.re_review_batch)"
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
</template>

<script setup lang="ts">
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import { reReviewTableFields } from '@/views/curate/reReviewTableConfig';
import type {
  SelectOption,
  UserOption,
  ReReviewSortEntry,
} from '@/views/curate/composables/useManageReReview';
import type { ReReviewBatchRow } from '@/views/curate/utils/reReviewFilters';

defineProps<{
  filter: string | null;
  userFilter: string | null;
  assignmentFilter: 'assigned' | 'unassigned' | null;
  userIdAssignment: number;
  userFilterOptions: SelectOption[];
  assignmentFilterOptions: SelectOption[];
  userOptions: UserOption[];
  filteredCount: number;
  paginatedItems: ReReviewBatchRow[];
  loading: boolean;
  perPage: number;
  currentPage: number;
  pageOptions: number[];
  totalRows: number;
  sortBy: ReReviewSortEntry[];
}>();

const emit = defineEmits<{
  (event: 'update:filter', value: string | null): void;
  (event: 'update:userFilter', value: string | null): void;
  (event: 'update:assignmentFilter', value: 'assigned' | 'unassigned' | null): void;
  (event: 'update:userIdAssignment', value: number): void;
  (event: 'apply-filters'): void;
  (event: 'refresh'): void;
  (event: 'page-change', page: number): void;
  (event: 'per-page-change', perPage: number): void;
  (event: 'sort-update', payload: { sortBy: string; sortDesc: boolean }): void;
  (event: 'new-batch-assignment'): void;
  (event: 'open-recalculate', row: ReReviewBatchRow): void;
  (event: 'open-reassign', row: ReReviewBatchRow): void;
  (event: 'unassign', batchId: number): void;
}>();

// Column definitions live with the table (static, read-only config).
const fields = reReviewTableFields;

// BootstrapVueNext BFormSelect emits this broad union from `update:model-value`.
type BvSelectValue = string | number | (string | number | null)[] | null;

function pickScalar(value: BvSelectValue): string | number | null {
  return Array.isArray(value) ? (value[0] ?? null) : value;
}

function updateFilter(value: string | null) {
  emit('update:filter', value);
}

function updateUserFilter(value: BvSelectValue) {
  const next = pickScalar(value);
  emit('update:userFilter', next == null ? null : String(next));
  emit('apply-filters');
}

function updateAssignmentFilter(value: BvSelectValue) {
  const next = pickScalar(value);
  emit('update:assignmentFilter', (typeof next === 'string' ? next : null) as
    | 'assigned'
    | 'unassigned'
    | null);
  emit('apply-filters');
}

function updateUserIdAssignment(value: BvSelectValue) {
  const next = pickScalar(value);
  emit('update:userIdAssignment', typeof next === 'number' ? next : Number(next) || 0);
}
</script>

<style scoped>
.re-review-icon-button {
  display: inline-grid;
  width: 2rem;
  min-width: 2rem;
  height: 2rem;
  padding: 0;
  place-items: center;
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
  .re-review-toolbar {
    grid-template-columns: minmax(14rem, 1fr) minmax(10rem, 1fr);
  }
}

@media (max-width: 767.98px) {
  .re-review-toolbar {
    grid-template-columns: 1fr;
  }

  .re-review-legacy-strip {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
