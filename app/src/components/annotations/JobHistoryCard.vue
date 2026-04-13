<!-- components/annotations/JobHistoryCard.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-0"
    header-class="p-2"
    border-variant="dark"
    class="mb-3 text-start"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
        <h5 class="mb-0 font-weight-bold">
          Job History
          <span class="badge bg-secondary ms-2 fw-normal">
            {{ filteredJobHistory.length }} jobs
          </span>
        </h5>
        <div class="d-flex align-items-center gap-2">
          <BButton
            size="sm"
            variant="outline-secondary"
            :disabled="loading"
            @click="$emit('refresh')"
          >
            <BSpinner v-if="loading" small class="me-1" />
            <i v-else class="bi bi-arrow-clockwise me-1" />
            Refresh
          </BButton>
        </div>
      </div>
    </template>

    <div class="p-2 border-bottom bg-light">
      <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
        <div class="d-flex align-items-center gap-2">
          <TableSearchInput
            :model-value="searchFilter"
            placeholder="Search jobs..."
            @update="(value: string) => $emit('update:searchFilter', value)"
          />
          <span v-if="searchFilter" class="badge bg-primary d-flex align-items-center">
            Search: {{ searchFilter }}
            <button
              type="button"
              class="btn-close btn-close-white ms-2"
              style="font-size: 0.6rem"
              aria-label="Clear search"
              @click="$emit('clear-search')"
            />
          </span>
        </div>
        <div class="d-flex align-items-center gap-2">
          <TableDownloadLinkCopyButtons
            @request-excel="$emit('download')"
            @copy-link="$emit('copy-link')"
            @remove-filters="$emit('clear-filters')"
          />
          <TablePaginationControls
            :current-page="currentPage"
            :total-rows="filteredJobHistory.length"
            :initial-per-page="pageSize"
            :page-options="pageSizeOptions"
            @page-change="(page: number) => $emit('page-change', page)"
            @per-page-change="(size: number) => $emit('per-page-change', size)"
          />
        </div>
      </div>
    </div>

    <GenericTable
      :items="paginatedJobHistory"
      :fields="jobHistoryFields"
      :is-busy="loading"
      :sort-by="sortBy"
      @update-sort="(payload: SortEvent) => $emit('update-sort', payload)"
    >
      <template #cell-operation="{ row }">
        <span class="badge bg-info text-dark">
          {{ formatOperationType(row.operation) }}
        </span>
      </template>

      <template #cell-status="{ row }">
        <span class="badge" :class="getStatusBadgeClass(row.status)">
          {{ row.status }}
        </span>
      </template>

      <template #cell-submitted_at="{ row }">
        {{ formatDateTime(row.submitted_at) }}
      </template>

      <template #cell-duration_seconds="{ row }">
        {{ formatDuration(row.duration_seconds) }}
      </template>

      <template #cell-error_message="{ row }">
        <span
          v-if="row.error_message"
          v-b-tooltip.hover.top
          class="text-danger error-text"
          :title="row.error_message"
        >
          {{ truncateText(row.error_message, 50) }}
        </span>
        <span v-else class="text-muted">—</span>
      </template>
    </GenericTable>

    <div
      v-if="!loading && filteredJobHistory.length === 0"
      class="text-center text-muted py-4"
    >
      <i class="bi bi-inbox fs-1 d-block mb-2" />
      <span v-if="searchFilter">No jobs match your search criteria.</span>
      <span v-else>
        No job history available. Jobs appear here after they are submitted.
      </span>
    </div>

    <div v-if="filteredJobHistory.length > pageSize" class="p-2 border-top bg-light">
      <div class="d-flex justify-content-end">
        <TablePaginationControls
          :current-page="currentPage"
          :total-rows="filteredJobHistory.length"
          :initial-per-page="pageSize"
          :page-options="pageSizeOptions"
          @page-change="(page: number) => $emit('page-change', page)"
          @per-page-change="(size: number) => $emit('per-page-change', size)"
        />
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import {
  formatOperationType,
  formatDateTime,
  formatDuration,
  getStatusBadgeClass,
  truncateText,
} from '@/composables/annotations/useAnnotationFormatters';

export interface JobHistoryItem {
  job_id: string;
  operation: string;
  status: string;
  submitted_at: string;
  completed_at: string | null;
  duration_seconds: number;
  error_message: string | null;
}

interface TableField {
  key: string;
  label: string;
  sortable?: boolean;
}

interface SortEntry {
  key: string;
  order: 'asc' | 'desc';
}

interface SortEvent {
  sortBy: string;
  sortDesc: boolean;
}

defineProps<{
  filteredJobHistory: JobHistoryItem[];
  paginatedJobHistory: JobHistoryItem[];
  loading: boolean;
  currentPage: number;
  pageSize: number;
  pageSizeOptions: number[];
  sortBy: SortEntry[];
  searchFilter: string;
  jobHistoryFields: TableField[];
}>();

defineEmits<{
  (e: 'refresh'): void;
  (e: 'download'): void;
  (e: 'copy-link'): void;
  (e: 'clear-filters'): void;
  (e: 'clear-search'): void;
  (e: 'update:searchFilter', value: string): void;
  (e: 'page-change', page: number): void;
  (e: 'per-page-change', size: number): void;
  (e: 'update-sort', payload: SortEvent): void;
}>();
</script>

<style scoped>
.error-text {
  display: block;
  max-width: 200px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  cursor: help;
}
</style>
