<!-- components/small/GenericDesktopTable.vue -->
<!--
  Desktop BTable responsibility extracted from GenericTable.vue (issue #346).
  Owns the full Bootstrap-Vue-Next table: every cell-slot forwarding block, the
  column-header (`#head`) and `filter-controls` (`#thead-top`) slots, busy/empty/
  table attributes, the details-toggle button, and server-side sort wiring via
  useGenericTableSorting. It forwards the raw BTable row-expansion scope up through
  its own `row-expansion` slot so the parent can supply the default detail card.
  Mobile rows, pagination, and toolbar chrome intentionally live in consumer SFCs.
-->
<template>
  <BTable
    :items="items"
    :fields="fields"
    :busy="isBusy"
    :sort-by="localSortBy"
    :stacked="stackedMode"
    :fixed="fixedLayout"
    :table-attrs="tableMinWidth ? { style: `--table-min-width: ${tableMinWidth}` } : undefined"
    head-variant="light"
    show-empty
    hover
    sort-icon-left
    no-local-sorting
    class="entities-table"
    tbody-tr-class="entity-row"
    @update:sort-by="handleSortByUpdate"
    @head-clicked="handleHeadClicked"
    @sorted="handleSorted"
  >
    <!-- Column header with optional tooltip support -->
    <template #head()="data">
      <slot name="column-header" :data="data" :fields="fields">
        {{ data.label }}
      </slot>
    </template>

    <!-- Filter fields row. Bootstrap-Vue-Next uses #thead-top instead of #top-row.
         role="presentation" removes the row from the table accessibility tree so
         axe/Lighthouse does not flag the filter <td> cells as lacking column headers
         (td-has-header). Filter inputs are independently labelled via aria-label. -->
    <template #thead-top>
      <tr v-if="$slots['filter-controls']" role="presentation">
        <slot name="filter-controls" />
      </tr>
    </template>

    <!-- Every consumer `head-<key>` / `cell-<key>` slot maps to BTable's `head(key)` /
         `cell(key)`; columns without one keep BTable's raw value and the column-header
         slot. `cell-description` is rendered below so it keeps its tooltip fallback. -->
    <template v-for="key in slotKeys('head-')" :key="`head-${key}`" #[`head(${key})`]="data">
      <slot :name="`head-${key}`" :data="data" :fields="fields" />
    </template>
    <template v-for="key in slotKeys('cell-')" :key="`cell-${key}`" #[`cell(${key})`]="data">
      <slot
        :name="`cell-${key}`"
        :row="data.item"
        :index="data.index"
        :toggle-expansion="data.toggleDetails || data.toggleExpansion"
        :expansion-showing="data.detailsShowing || data.expansionShowing"
      />
    </template>
    <!-- Description column with truncation and tooltip -->
    <template #cell(description)="data">
      <slot name="cell-description" :row="data.item" :index="data.index">
        <span v-b-tooltip.hover.top class="description-text" :title="data.item.description">
          {{ data.item.description }}
        </span>
      </slot>
    </template>
    <!-- Details toggle button -->
    <template #cell(details)="row">
      <BButton class="btn-xs" variant="outline-primary" @click="row.toggleExpansion">
        {{ row.expansionShowing ? 'Hide' : 'Show' }}
      </BButton>
    </template>
    <!-- Row expansion - forwards the raw BTable scope so the parent can supply
         the default detail card (or a consumer override) via its own slot. -->
    <template #row-expansion="row">
      <slot name="row-expansion" v-bind="row" />
    </template>
  </BTable>
</template>

<script setup>
// Plain <script setup> (no lang="ts") deliberately mirrors the original
// GenericTable.vue JS component: row items are intentionally loosely typed so
// every consumer's cell/row-expansion slot keeps its original untyped contract.
// Sort logic is delegated to the typed useGenericTableSorting composable.
import { computed, useSlots } from 'vue';
import { BTable, BButton } from 'bootstrap-vue-next';
import { useGenericTableSorting } from './useGenericTableSorting';
import { fixedTableMinWidth } from './fixedTableMinWidth';

const slots = useSlots();
// Rendered by their own templates (tooltip fallback, details toggle button).
const OWN_CELL_SLOTS = new Set(['cell-description', 'cell-details']);

/** Column keys of the consumer slots named `<prefix><key>`; read per render. */
function slotKeys(prefix) {
  return Object.keys(slots)
    .filter((name) => name.startsWith(prefix) && !OWN_CELL_SLOTS.has(name))
    .map((name) => name.slice(prefix.length));
}

const props = defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  fields: {
    type: Array,
    default: () => [],
  },
  isBusy: {
    type: Boolean,
    default: false,
  },
  sortBy: {
    // Accept both string (legacy) and array (Bootstrap-Vue-Next) formats
    type: [String, Array],
    default: () => [],
  },
  sortDesc: {
    type: Boolean,
    default: false,
  },
  stackedMode: {
    type: [String, Boolean],
    default: 'md',
  },
  fixedLayout: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['update-sort', 'update:sort-by']);

const tableMinWidth = computed(() =>
  props.fixedLayout ? fixedTableMinWidth(props.fields) : undefined
);

const { localSortBy, handleSortByUpdate, handleHeadClicked, handleSorted } = useGenericTableSorting(
  props,
  emit
);
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

/* Mobile: modest touch-target bump for details button */
@media (max-width: 767px) {
  .btn-xs {
    padding: 0.3rem 0.6rem;
    font-size: 0.8125rem;
    line-height: 1.2;
  }
}

/* Modern table styling */
.entities-table {
  border-collapse: separate;
  border-spacing: 0;
}

:deep(.entities-table td[colspan]) {
  overflow: visible;
  white-space: normal;
}

/* Row styling - subtle separator and better spacing */
:deep(.entities-table tbody tr) {
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);
  transition: background-color 0.15s ease;
}

:deep(.entities-table tbody tr:last-child) {
  border-bottom: none;
}

/* Alternating row backgrounds - very subtle */
:deep(.entities-table tbody tr:nth-child(even)) {
  background-color: rgba(0, 0, 0, 0.015);
}

/* Enhanced hover effect */
:deep(.entities-table tbody tr:hover) {
  background-color: rgba(13, 110, 253, 0.04);
}

/* Cell padding and alignment */
:deep(.entities-table td) {
  padding: 0.65rem 0.5rem;
  vertical-align: middle;
  border-top: none;
}

:deep(.entities-table th) {
  padding: 0.6rem 0.5rem;
  font-weight: 600;
  font-size: 0.8125rem;
  text-transform: uppercase;
  letter-spacing: 0;
  color: #495057;
  background-color: #f8f9fa;
  border-bottom: 2px solid #dee2e6;
}

/* Filter row styling */
:deep(.entities-table thead tr:first-child td) {
  padding: 0.4rem 0.25rem;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

/* Stacked mode improvements for mobile */
@media (max-width: 767px) {
  :deep(.entities-table.b-table-stacked-md > tbody > tr) {
    padding: 0.75rem;
    margin-bottom: 0.5rem;
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 0.5rem;
    background-color: #fff;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
  }

  :deep(.entities-table.b-table-stacked-md > tbody > tr:hover) {
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.08);
  }

  :deep(.entities-table.b-table-stacked-md > tbody > tr > td) {
    padding: 0.35rem 0;
    border: none;
  }
}

/* Accessibility - respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  :deep(.entities-table tbody tr) {
    transition: none;
  }
}
</style>

<!-- The override that keeps column-header tooltips from being clipped by the
     sortable <th>'s overflow:hidden now lives once in
     `assets/scss/components/_tables.scss`, shared by `.entities-table` and
     `.public-data-table` surfaces. Kept there to avoid duplicating it per table. -->
