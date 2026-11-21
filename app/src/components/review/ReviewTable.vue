<!-- components/review/ReviewTable.vue -->
<template>
  <TableShell :title="title" :meta="`${totalRows} ${totalRowsLabel}`">
    <template #actions>
      <BButton
        v-b-tooltip.hover.bottom
        variant="outline-success"
        size="sm"
        :disabled="totalRows === 0"
        :title="approveAllTitle"
        :aria-label="approveAllAriaLabel"
        @click="$emit('approve-all')"
      >
        <i class="bi bi-check2-all me-1" aria-hidden="true" />
        Approve all {{ totalRows.toLocaleString('en-US') }}
      </BButton>
      <BButton
        v-b-tooltip.hover.bottom
        variant="outline-secondary"
        size="sm"
        title="Refresh data"
        aria-label="Refresh table data"
        @click="$emit('refresh')"
      >
        <i class="bi bi-arrow-clockwise" aria-hidden="true" />
      </BButton>
    </template>

    <template #toolbar>
      <div class="review-table__toolbar">
        <BInputGroup size="sm" class="review-table__search">
          <template #prepend>
            <BInputGroupText>
              <i class="bi bi-search" aria-hidden="true" />
            </BInputGroupText>
          </template>
          <BFormInput
            id="filter-input"
            :model-value="filterText"
            type="search"
            placeholder="Search any field..."
            debounce="500"
            aria-label="Search reviews"
            @update:model-value="$emit('update:filterText', String($event ?? ''))"
          />
        </BInputGroup>
        <BFormSelect
          :model-value="categoryFilter"
          size="sm"
          class="review-table__select"
          :options="categoryOptions"
          aria-label="Filter by category"
          @update:model-value="$emit('update:categoryFilter', ($event as string) ?? null)"
        />
        <BFormSelect
          :model-value="userFilter"
          size="sm"
          class="review-table__select"
          :options="userOptions"
          aria-label="Filter by user"
          @update:model-value="$emit('update:userFilter', ($event as string) ?? null)"
        />
        <BInputGroup size="sm" class="review-table__date">
          <template #prepend>
            <BInputGroupText>From</BInputGroupText>
          </template>
          <BFormInput
            :model-value="dateStart"
            type="date"
            size="sm"
            aria-label="Filter from date"
            @update:model-value="$emit('update:dateStart', String($event ?? '') || null)"
          />
        </BInputGroup>
        <BInputGroup size="sm" class="review-table__date">
          <template #prepend>
            <BInputGroupText>To</BInputGroupText>
          </template>
          <BFormInput
            :model-value="dateEnd"
            type="date"
            size="sm"
            aria-label="Filter to date"
            @update:model-value="$emit('update:dateEnd', String($event ?? '') || null)"
          />
        </BInputGroup>

        <div class="review-table__paging">
          <BInputGroup prepend="Per page" size="sm" class="review-table__per-page">
            <BFormSelect
              :id="`${totalRowsLabel}-per-page-select`"
              :model-value="perPage"
              :options="pageOptions"
              size="sm"
              aria-label="Rows per page"
              @update:model-value="$emit('update:perPage', Number($event))"
            />
          </BInputGroup>
          <BPagination
            :model-value="currentPage"
            :total-rows="totalRows"
            :per-page="perPage"
            size="sm"
            class="mb-0"
            limit="5"
            :aria-label="paginationLabel"
            @update:model-value="$emit('update:currentPage', Number($event))"
          />
          <span class="review-table__page-count">Page {{ currentPage }} of {{ pageCount }}</span>
        </div>
      </div>

      <div v-if="categoryFilter || userFilter || dateStart || dateEnd" class="review-table__chips">
        <BButton
          v-if="categoryFilter"
          size="sm"
          variant="light"
          class="review-table__chip"
          :aria-label="`Remove filter ${categoryFilter}`"
          @click="$emit('update:categoryFilter', null)"
        >
          {{ categoryFilter }} <i class="bi bi-x" aria-hidden="true" />
        </BButton>
        <BButton
          v-if="userFilter"
          size="sm"
          variant="light"
          class="review-table__chip"
          :aria-label="`Remove filter ${userFilter}`"
          @click="$emit('update:userFilter', null)"
        >
          {{ userFilter }} <i class="bi bi-x" aria-hidden="true" />
        </BButton>
        <BButton
          v-if="dateStart"
          size="sm"
          variant="light"
          class="review-table__chip"
          :aria-label="`Remove filter from ${dateStart}`"
          @click="$emit('update:dateStart', null)"
        >
          From: {{ dateStart }} <i class="bi bi-x" aria-hidden="true" />
        </BButton>
        <BButton
          v-if="dateEnd"
          size="sm"
          variant="light"
          class="review-table__chip"
          :aria-label="`Remove filter to ${dateEnd}`"
          @click="$emit('update:dateEnd', null)"
        >
          To: {{ dateEnd }} <i class="bi bi-x" aria-hidden="true" />
        </BButton>
      </div>

      <details class="review-table__legend">
        <summary>
          <i class="bi bi-info-circle" aria-hidden="true" />
          Legend
        </summary>
        <IconLegend :legend-items="legendItems" />
      </details>
    </template>

    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <div v-else class="d-none d-md-block review-table__desktop-scroll">
      <GenericTable
        class="review-table__desktop"
        :items="pageItems"
        :fields="fields"
        :is-busy="isBusy"
        :sort-by="sortBy"
        :stacked-mode="false"
        :fixed-layout="false"
        @update:sort-by="$emit('update:sortBy', $event as SortBy[])"
        @update-sort="
          ({ sortBy: key, sortDesc }) =>
            $emit('update:sortBy', [{ key, order: sortDesc ? 'desc' : 'asc' }] as SortBy[])
        "
      >
        <template #column-header="{ data }">
          <div v-b-tooltip.hover.bottom class="review-table__column-header" :title="data.label">
            {{ truncateHeader(data.label) }}
          </div>
        </template>
        <template #cell-entity_id="{ row, index }">
          <slot name="cell(entity_id)" :item="row" :index="index" />
        </template>
        <template #cell-symbol="{ row, index }">
          <slot name="cell(symbol)" :item="row" :index="index" />
        </template>
        <template #cell-disease_ontology_name="{ row, index }">
          <slot name="cell(disease_ontology_name)" :item="row" :index="index" />
        </template>
        <template #cell-hpo_mode_of_inheritance_term_name="{ row, index }">
          <slot name="cell(hpo_mode_of_inheritance_term_name)" :item="row" :index="index" />
        </template>
        <template #cell-category="{ row, index }">
          <slot name="cell(category)" :item="row" :index="index" />
        </template>
        <template #cell-problematic="{ row, index }">
          <slot name="cell(problematic)" :item="row" :index="index" />
        </template>
        <template #cell-synopsis="{ row, index }">
          <slot name="cell(synopsis)" :item="row" :index="index" />
        </template>
        <template #cell-comment="{ row, index }">
          <slot name="cell(comment)" :item="row" :index="index" />
        </template>
        <template #cell-review_date="{ row, index }">
          <slot name="cell(review_date)" :item="row" :index="index" />
        </template>
        <template #cell-review_user_name="{ row, index }">
          <slot name="cell(review_user_name)" :item="row" :index="index" />
        </template>
        <template #cell-status_date="{ row, index }">
          <slot name="cell(status_date)" :item="row" :index="index" />
        </template>
        <template #cell-status_user_name="{ row, index }">
          <slot name="cell(status_user_name)" :item="row" :index="index" />
        </template>
        <template #cell-actions="{ row, index, expansionShowing, toggleExpansion }">
          <slot
            name="cell(actions)"
            :item="row"
            :index="index"
            :expansion-showing="expansionShowing"
            :toggle-expansion="toggleExpansion"
          />
        </template>
        <template #row-expansion="{ row, toggle }">
          <slot name="row-expansion" :item="row" :toggle-expansion="toggle" />
        </template>
      </GenericTable>
    </div>
    <div v-if="!loading" class="d-md-none">
      <slot name="mobile-rows" :items="pageItems" />
    </div>
  </TableShell>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import type { PropType } from 'vue';
import type { SortBy, TableField } from '@/types/components';
import IconLegend from '@/components/accessibility/IconLegend.vue';
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';

export interface LegendItem {
  icon?: string;
  color?: string;
  component?: unknown;
  componentProps?: Record<string, unknown>;
  label: string;
}

const props = defineProps({
  title: { type: String, default: 'Approve Reviews' },
  /** Plural resource noun rendered in the "X reviews" badge — override for status/other streams. */
  totalRowsLabel: { type: String, default: 'reviews' },
  /** Tooltip text on the "Approve All" button. */
  approveAllTitle: { type: String, default: 'Approve all pending reviews' },
  /** aria-label on the "Approve All" button. */
  approveAllAriaLabel: { type: String, default: 'Approve all reviews' },
  items: { type: Array as PropType<unknown[]>, required: true },
  fields: { type: Array as PropType<TableField[]>, required: true },
  totalRows: { type: Number, required: true },
  currentPage: { type: Number, required: true },
  perPage: { type: Number, required: true },
  pageOptions: { type: Array as PropType<number[]>, required: true },
  sortBy: { type: Array as PropType<SortBy[]>, required: true },
  filterText: { type: String as PropType<string | null>, default: null },
  categoryFilter: { type: String as PropType<string | null>, default: null },
  userFilter: { type: String as PropType<string | null>, default: null },
  dateStart: { type: String as PropType<string | null>, default: null },
  dateEnd: { type: String as PropType<string | null>, default: null },
  categoryOptions: {
    type: Array as PropType<Array<{ value: string | null; text: string }>>,
    required: true,
  },
  userOptions: {
    type: Array as PropType<Array<{ value: string | null; text: string }>>,
    required: true,
  },
  legendItems: { type: Array as PropType<LegendItem[]>, required: true },
  isBusy: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

const filteredSortedItems = computed<unknown[]>(() => {
  const searchTerm = (props.filterText || '').trim().toLowerCase();
  const sortConfig = props.sortBy[0];
  let visibleItems = props.items;

  if (searchTerm) {
    visibleItems = visibleItems.filter((item) =>
      Object.values((item ?? {}) as Record<string, unknown>).some((value) =>
        value == null ? false : String(value).toLowerCase().includes(searchTerm)
      )
    );
  }

  if (sortConfig?.key) {
    visibleItems = [...visibleItems].sort((a, b) => {
      const left = String(((a ?? {}) as Record<string, unknown>)[sortConfig.key] ?? '');
      const right = String(((b ?? {}) as Record<string, unknown>)[sortConfig.key] ?? '');
      return left.localeCompare(right, undefined, { numeric: true, sensitivity: 'base' });
    });

    if (sortConfig.order === 'desc') {
      visibleItems.reverse();
    }
  }

  return visibleItems;
});

const pageItems = computed<unknown[]>(() => {
  const start = Math.max(props.currentPage - 1, 0) * props.perPage;
  return filteredSortedItems.value.slice(start, start + props.perPage);
});

const paginationLabel = computed(
  () => `${props.totalRowsLabel.charAt(0).toUpperCase()}${props.totalRowsLabel.slice(1)} pagination`
);
const pageCount = computed(() => Math.max(1, Math.ceil(props.totalRows / props.perPage)));

const emit = defineEmits<{
  (e: 'approve-all'): void;
  (e: 'refresh'): void;
  (e: 'update:currentPage', value: number): void;
  (e: 'update:perPage', value: number): void;
  (e: 'update:sortBy', value: SortBy[]): void;
  (e: 'update:filterText', value: string): void;
  (e: 'update:categoryFilter', value: string | null): void;
  (e: 'update:userFilter', value: string | null): void;
  (e: 'update:dateStart', value: string | null): void;
  (e: 'update:dateEnd', value: string | null): void;
  (e: 'filtered', value: unknown[]): void;
}>();

watch(
  filteredSortedItems,
  (items) => {
    emit('filtered', items);
  },
  { immediate: true }
);

function truncateHeader(label: string): string {
  return label.length > 18 ? `${label.slice(0, 15)}...` : label;
}
</script>

<style scoped>
.review-table__toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
}

.review-table__search {
  flex: 1 1 14rem;
  max-width: 20rem;
}

.review-table__select {
  flex: 0 1 11rem;
  min-width: 9.5rem;
  width: auto;
}

.review-table__date {
  flex: 1 1 11.5rem;
  max-width: 14rem;
}

.review-table__paging {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  margin-left: auto;
}

.review-table__per-page {
  width: auto;
}

.review-table__per-page :deep(.form-select) {
  width: auto;
  min-width: 4.5rem;
}

.review-table__page-count {
  color: var(--text-secondary, #475569);
  font-size: 0.8125rem;
  white-space: nowrap;
}

.review-table__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
  margin-top: 0.5rem;
}

.review-table__chip {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.1rem 0.5rem;
  font-size: 0.8125rem;
}

.review-table__legend {
  margin-top: 0.625rem;
  color: #475569;
  font-size: 0.8125rem;
}

.review-table__legend summary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  cursor: pointer;
  font-weight: 700;
}

.review-table__legend :deep(.icon-legend) {
  margin-top: 0.5rem;
}

.review-table__desktop {
  overflow-x: auto;
}

.review-table__column-header {
  white-space: nowrap;
}
</style>
