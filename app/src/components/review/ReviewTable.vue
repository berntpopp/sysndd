<!-- components/review/ReviewTable.vue -->
<template>
  <TableShell :title="title" :meta="`${totalRows} ${totalRowsLabel}`">
    <template #actions>
      <BButton
        v-b-tooltip.hover.bottom
        variant="danger"
        size="sm"
        :title="approveAllTitle"
        :aria-label="approveAllAriaLabel"
        @click="$emit('approve-all')"
      >
        <i class="bi bi-check2-all me-1" aria-hidden="true" />
        Approve All
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
      <BRow class="g-2 align-items-center">
        <BCol cols="12" md="4" lg="3" class="mb-2 mb-md-0">
          <BInputGroup size="sm">
            <template #prepend>
              <BInputGroupText>
                <i class="bi bi-search" />
              </BInputGroupText>
            </template>
            <BFormInput
              id="filter-input"
              :model-value="filterText"
              type="search"
              placeholder="Search any field..."
              debounce="500"
              @update:model-value="$emit('update:filterText', String($event ?? ''))"
            />
          </BInputGroup>
        </BCol>
        <BCol cols="12" md="4" lg="4" class="mb-2 mb-md-0" />
        <BCol
          cols="12"
          md="4"
          lg="5"
          class="d-flex align-items-center justify-content-end gap-2 flex-wrap"
        >
          <BInputGroup prepend="Per page" size="sm">
            <BFormSelect
              id="per-page-select"
              :model-value="perPage"
              :options="pageOptions"
              size="sm"
              @update:model-value="$emit('update:perPage', Number($event))"
            />
          </BInputGroup>
          <BPagination
            :model-value="currentPage"
            :total-rows="totalRows"
            :per-page="perPage"
            size="sm"
            class="mb-0"
            limit="2"
            @update:model-value="$emit('update:currentPage', Number($event))"
          />
        </BCol>
      </BRow>

      <BRow class="g-2 align-items-center mt-1">
        <BCol cols="6" md="2" class="mb-2 mb-md-0">
          <BFormSelect
            :model-value="categoryFilter"
            size="sm"
            :options="categoryOptions"
            aria-label="Filter by category"
            @update:model-value="$emit('update:categoryFilter', ($event as string) ?? null)"
          />
        </BCol>
        <BCol cols="6" md="2" class="mb-2 mb-md-0">
          <BFormSelect
            :model-value="userFilter"
            size="sm"
            :options="userOptions"
            aria-label="Filter by user"
            @update:model-value="$emit('update:userFilter', ($event as string) ?? null)"
          />
        </BCol>
        <BCol cols="6" md="2" class="mb-2 mb-md-0">
          <BInputGroup size="sm">
            <template #prepend>
              <BInputGroupText class="small"> From </BInputGroupText>
            </template>
            <BFormInput
              :model-value="dateStart"
              type="date"
              size="sm"
              aria-label="Filter from date"
              @update:model-value="$emit('update:dateStart', String($event ?? '') || null)"
            />
          </BInputGroup>
        </BCol>
        <BCol cols="6" md="2" class="mb-2 mb-md-0">
          <BInputGroup size="sm">
            <template #prepend>
              <BInputGroupText class="small"> To </BInputGroupText>
            </template>
            <BFormInput
              :model-value="dateEnd"
              type="date"
              size="sm"
              aria-label="Filter to date"
              @update:model-value="$emit('update:dateEnd', String($event ?? '') || null)"
            />
          </BInputGroup>
        </BCol>
        <BCol cols="12" md="4" class="d-flex align-items-center flex-wrap gap-1">
          <BBadge
            v-if="categoryFilter"
            variant="secondary"
            class="d-flex align-items-center gap-1"
            style="cursor: pointer"
            @click="$emit('update:categoryFilter', null)"
          >
            {{ categoryFilter }}
            <i class="bi bi-x" />
          </BBadge>
          <BBadge
            v-if="userFilter"
            variant="secondary"
            class="d-flex align-items-center gap-1"
            style="cursor: pointer"
            @click="$emit('update:userFilter', null)"
          >
            {{ userFilter }}
            <i class="bi bi-x" />
          </BBadge>
          <BBadge
            v-if="dateStart"
            variant="secondary"
            class="d-flex align-items-center gap-1"
            style="cursor: pointer"
            @click="$emit('update:dateStart', null)"
          >
            From: {{ dateStart }}
            <i class="bi bi-x" />
          </BBadge>
          <BBadge
            v-if="dateEnd"
            variant="secondary"
            class="d-flex align-items-center gap-1"
            style="cursor: pointer"
            @click="$emit('update:dateEnd', null)"
          >
            To: {{ dateEnd }}
            <i class="bi bi-x" />
          </BBadge>
        </BCol>
      </BRow>

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
  icon: string;
  color?: string;
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
