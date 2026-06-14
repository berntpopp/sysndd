<!-- components/tables/LogFilterToolbar.vue -->
<!--
  Filter/search/pagination toolbar for the audit-log table. Extracted from
  TablesLogs.vue so the SFC stays a thin shell. Follows props-down / events-up:
  `filter` is read-only here and every field change emits `update-filter`
  (key, value) so the parent (useLogTable) owns the filter object. Pagination,
  delete, and clear actions are surfaced as events too.
-->
<template>
  <div>
    <BRow class="g-2">
      <BCol sm="8">
        <TableSearchInput
          :model-value="filter['any'].content ?? undefined"
          :placeholder="'Search any field by typing here'"
          :debounce-time="500"
          @update:model-value="updateField('any', $event)"
        />
      </BCol>

      <BCol sm="4">
        <BContainer v-if="totalRows > perPage || showPaginationControls">
          <TablePaginationControls
            :total-rows="totalRows"
            :initial-per-page="perPage"
            :page-options="pageOptions"
            :current-page="currentPage"
            @page-change="$emit('page-change', $event)"
            @per-page-change="$emit('per-page-change', $event)"
          />
        </BContainer>
      </BCol>
    </BRow>

    <BRow class="g-2 mt-1 align-items-center">
      <BCol sm="3">
        <BFormSelect
          :model-value="filter.request_method.content"
          :options="methodOptions"
          size="sm"
          @update:model-value="updateField('request_method', $event)"
        >
          <template #first>
            <BFormSelectOption :value="null">All Methods</BFormSelectOption>
          </template>
        </BFormSelect>
      </BCol>
      <BCol sm="3">
        <BFormSelect
          :model-value="filter.status.content"
          :options="statusOptions"
          size="sm"
          @update:model-value="updateField('status', $event)"
        >
          <template #first>
            <BFormSelectOption :value="null">All Status</BFormSelectOption>
          </template>
        </BFormSelect>
      </BCol>
      <BCol sm="3">
        <BFormSelect
          :model-value="filter.path.content"
          size="sm"
          @update:model-value="updateField('path', $event)"
        >
          <BFormSelectOption :value="null">All Paths</BFormSelectOption>
          <BFormSelectOption value="/api/">API Calls</BFormSelectOption>
          <BFormSelectOption value="/signin">/signin</BFormSelectOption>
          <BFormSelectOption value="/api/entity">/api/entity</BFormSelectOption>
          <BFormSelectOption value="/api/logs">/api/logs</BFormSelectOption>
        </BFormSelect>
      </BCol>
      <BCol sm="3" class="text-end">
        <span class="text-muted small me-2">
          {{ itemsLength }} of {{ totalRows.toLocaleString() }}
        </span>
        <BButton
          v-b-tooltip.hover
          size="sm"
          variant="outline-danger"
          title="Delete all logs (requires confirmation)"
          @click="$emit('show-delete')"
        >
          <i class="bi bi-trash" />
        </BButton>
      </BCol>
    </BRow>

    <BRow class="g-2 mt-1 d-md-none">
      <BCol>
        <BInputGroup prepend="Sort" size="sm">
          <BFormSelect
            :model-value="mobileSortValue"
            :options="mobileSortOptions"
            size="sm"
            @update:model-value="$emit('update:mobileSortValue', String($event))"
          />
        </BInputGroup>
      </BCol>
    </BRow>

    <details class="log-mobile-filters d-md-none">
      <summary>
        <i class="bi bi-funnel" aria-hidden="true" />
        More filters
      </summary>
      <div class="log-mobile-filters__grid">
        <BFormInput
          v-for="field in mobileFilterFields"
          :key="field.key"
          :model-value="filter[field.key].content ?? undefined"
          size="sm"
          :placeholder="field.label"
          type="search"
          autocomplete="off"
          @update:model-value="updateField(field.key, $event)"
        />
      </div>
    </details>

    <!-- Active filter pills -->
    <BRow v-if="hasActiveFilters" class="g-2 mt-1">
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
            @click="$emit('clear-filter', activeFilter.key)"
          >
            <i class="bi bi-x" />
          </BButton>
        </BBadge>
        <BButton size="sm" variant="link" class="p-0" @click="$emit('remove-filters')">
          Clear all
        </BButton>
      </BCol>
    </BRow>
  </div>
</template>

<script setup lang="ts">
import {
  BRow,
  BCol,
  BContainer,
  BFormSelect,
  BFormSelectOption,
  BFormInput,
  BInputGroup,
  BButton,
  BBadge,
} from 'bootstrap-vue-next';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import type { LogFilter } from './useLogTable';

interface SelectOption {
  value: string;
  text: string;
}
interface ActiveFilter {
  key: string;
  label: string;
  value: string;
}

defineProps<{
  /** The log filter object (read-only here; changes flow up via update-filter). */
  filter: LogFilter;
  totalRows: number;
  perPage: number;
  showPaginationControls: boolean;
  pageOptions: number[];
  currentPage: number;
  methodOptions: SelectOption[];
  statusOptions: SelectOption[];
  mobileSortOptions: SelectOption[];
  mobileSortValue: string;
  itemsLength: number;
  hasActiveFilters: boolean;
  activeFilters: ActiveFilter[];
}>();

const emit = defineEmits<{
  (e: 'update-filter', key: string, value: string | null): void;
  (e: 'page-change', value: number): void;
  (e: 'per-page-change', value: number): void;
  (e: 'show-delete'): void;
  (e: 'clear-filter', key: string): void;
  (e: 'remove-filters'): void;
  (e: 'update:mobileSortValue', value: string): void;
}>();

// Normalise input values to string | null before emitting up.
function updateField(key: string, value: unknown): void {
  emit('update-filter', key, value == null || value === '' ? null : String(value));
}

// Per-field mobile filter inputs (collapsed "More filters" panel on mobile).
const mobileFilterFields: Array<{ key: keyof LogFilter & string; label: string }> = [
  { key: 'id', label: 'ID' },
  { key: 'timestamp', label: 'Timestamp' },
  { key: 'address', label: 'IP address' },
  { key: 'agent', label: 'Agent' },
  { key: 'host', label: 'Host' },
  { key: 'user', label: 'User' },
  { key: 'query', label: 'Query' },
  { key: 'post', label: 'POST body' },
  { key: 'duration', label: 'Duration' },
  { key: 'file', label: 'File' },
  { key: 'modified', label: 'Modified' },
];
</script>

<style scoped>
.log-mobile-filters {
  margin-top: 0.5rem;
}

.log-mobile-filters summary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 2rem;
  color: #0d6efd;
  font-size: 0.8125rem;
  font-weight: 700;
  cursor: pointer;
}

.log-mobile-filters__grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.log-mobile-filters:not([open]) .log-mobile-filters__grid {
  display: none;
}
</style>
