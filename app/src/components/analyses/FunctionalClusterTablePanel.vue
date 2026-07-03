<!-- src/components/analyses/FunctionalClusterTablePanel.vue -->
<!--
  Right-pane table for the functional gene-clusters analysis. Owns the table's
  own concerns: table-type selection, column filters, sorting, pagination,
  cell formatting, and Excel export (all delegated to useFunctionalClusterTable).
  Cluster selection, network sync, and the LLM summary card live in the parent
  (AnalyseGeneClusters.vue), which threads the selected cluster's rows in as
  `selectedCluster` and receives table events.
-->
<template>
  <!-- Table panel: flat container replaces inner BCard to reduce card-in-card nesting -->
  <div class="cluster-table-panel">
    <!-- TABLE TOOLBAR (Table type, Cluster indicator, Search, Export) -->
    <div class="cluster-table-panel__toolbar">
      <BRow class="g-1 align-items-center">
        <BCol sm="4" class="mb-1">
          <!-- Table type selector (term_enrichment vs. identifiers) -->
          <BInputGroup size="sm" class="cluster-table-type-control">
            <label for="cluster-table-type-select" class="input-group-text">Table type</label>
            <BFormSelect
              id="cluster-table-type-select"
              v-model="tableType"
              :options="tableOptions"
              size="sm"
              aria-label="Select table type"
            />
          </BInputGroup>
        </BCol>

        <BCol sm="4" class="mb-1 text-center">
          <!-- Cluster indicator showing which data is displayed -->
          <span
            v-b-tooltip.hover
            class="sysndd-chip"
            :class="showAllClustersInTable ? 'sysndd-chip--neutral' : 'sysndd-chip--blue'"
            title="Select clusters in the network to filter table data"
          >
            <i class="bi bi-diagram-3 me-1" aria-hidden="true" />
            {{ clusterDisplayLabel }}
          </span>
        </BCol>

        <BCol sm="4" class="mb-1 text-end">
          <div class="d-flex align-items-center justify-content-end gap-2">
            <!-- Gene search synced with network (uses same geneSearchPattern) -->
            <TermSearch
              v-model="searchPattern"
              :match-count="tableType === 'identifiers' ? searchMatchCount : null"
              :suggestions="allGeneSymbols"
              placeholder="Search genes..."
            />
            <!-- Excel download button -->
            <BButton
              v-b-tooltip.hover.bottom
              size="sm"
              variant="outline-secondary"
              title="Download table data as Excel file"
              aria-label="Download table data as Excel file (.xlsx)"
              :disabled="loading || isExporting"
              @click="downloadExcel"
            >
              <i class="bi bi-table me-1" aria-hidden="true" />
              <i v-if="!isExporting" class="bi bi-download" aria-hidden="true" />
              <BSpinner v-else small />
              .xlsx
            </BButton>
          </div>
        </BCol>
      </BRow>
    </div>

    <div class="text-start" :aria-busy="loading ? 'true' : 'false'">
      <TableLoadingState
        v-if="loading"
        class="cluster-table-loading"
        label="Loading functional cluster rows"
        :rows="6"
      />

      <!-- Snapshot still building (503 snapshot_missing) — show a friendly
           "being prepared" state instead of a raw error toast (#440). -->
      <div v-else-if="isPreparing" class="error-state text-center p-4">
        <i class="bi bi-hourglass-split text-primary fs-1 mb-3 d-block" />
        <p class="text-muted mb-3">
          This analysis is being prepared and will appear here shortly. This can take a
          couple of minutes after a deploy or data update.
        </p>
        <BButton variant="primary" @click="$emit('retry')">
          <i class="bi bi-arrow-clockwise me-1" />
          Check again
        </BButton>
      </div>

      <!-- GenericTable for main table content -->
      <GenericTable
        v-else
        :items="displayedItems"
        :fields="fieldsComputed"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @update-sort="handleSortUpdate"
      >
        <!-- Optional column-level filters — role="presentation" prevents td-has-header violation -->
        <template #filter-controls>
          <td v-for="field in fieldsComputed" :key="field.key" role="presentation">
            <!-- Cluster number: keep text filter -->
            <BFormInput
              v-if="field.key === 'cluster_num'"
              v-model="filter[field.key].content"
              :placeholder="'Filter ' + field.label"
              :aria-label="'Filter by ' + field.label"
              debounce="500"
              @input="onFilterChange"
            />

            <!-- Category: use CategoryFilter dropdown -->
            <CategoryFilter
              v-else-if="field.key === 'category'"
              v-model="categoryFilter"
              :options="categoryOptions"
              placeholder="All categories"
              aria-label="Filter by category"
              @update:model-value="onFilterChange"
            />

            <!-- FDR: use ScoreSlider with presets -->
            <ScoreSlider
              v-else-if="field.key === 'fdr'"
              v-model="fdrThreshold"
              aria-label="Filter by FDR threshold"
              @update:model-value="onFilterChange"
            />

            <!-- Other columns: text filter (symbol, STRING_id, description, etc.) -->
            <BFormInput
              v-else-if="field.key !== 'details' && field.key !== 'number_of_genes'"
              v-model="filter[field.key].content"
              :placeholder="'Filter ' + field.label"
              :aria-label="'Filter by ' + field.label"
              debounce="500"
              @input="onFilterChange"
            />
          </td>
        </template>

        <!-- cluster_num cell - colored badge matching network legend -->
        <template #cell-cluster_num="{ row }">
          <span
            v-if="row.cluster_num"
            class="cluster-badge"
            :style="{ backgroundColor: getClusterColor(row.cluster_num) }"
          >
            {{ row.cluster_num }}
          </span>
        </template>

        <!-- category cell: quiet chip tokens instead of heavy dark border -->
        <template #cell-category="{ row }">
          <!-- Render only if tableType === 'term_enrichment' -->
          <div v-if="tableType === 'term_enrichment'">
            <span
              v-b-tooltip.hover.rightbottom
              class="sysndd-chip"
              :class="getCategoryChipClass(row.category)"
              :title="row.category"
            >
              {{ findCategoryText(row.category) }}
            </span>
          </div>
        </template>

        <template #cell-number_of_genes="{ row }">
          <span class="sysndd-chip sysndd-chip--info">
            {{ row['number_of_genes'] }}
          </span>
        </template>

        <!-- fdr cell: scientific notation so tiny values don't render as '0' -->
        <template #cell-fdr="{ row }">
          <!-- Render only if tableType === 'term_enrichment' -->
          <div
            v-if="tableType === 'term_enrichment'"
            v-b-tooltip.hover.leftbottom
            class="overflow-hidden text-truncate"
            :title="row.fdr != null ? Number(row.fdr).toFixed(10) : ''"
          >
            <span class="sysndd-chip sysndd-chip--warning sysndd-chip--mono">
              {{ formatFdr(row.fdr) }}
            </span>
          </div>
        </template>

        <!-- description cell -->
        <template #cell-description="{ row }">
          <!-- Render only if tableType === 'term_enrichment' -->
          <div v-if="tableType === 'term_enrichment'" class="d-flex align-items-center">
            <BButton
              class="btn-xs me-1 flex-shrink-0"
              variant="outline-primary"
              :href="findCategoryLink(row.category, row.term)"
              target="_blank"
              title="Open in external database"
              :aria-label="'Open ' + (row.description || row.term) + ' in external database'"
            >
              <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
            </BButton>
            <span
              v-b-tooltip.hover.top
              class="description-text text-truncate"
              :title="row.description"
            >
              {{ row.description }}
            </span>
          </div>
        </template>

        <!-- symbol cell with bidirectional hover highlighting -->
        <template #cell-symbol="{ row }">
          <!-- Render only if tableType === 'identifiers' -->
          <div
            v-if="tableType === 'identifiers'"
            class="font-italic symbol-cell"
            :class="{ 'row-highlighted': isRowHighlighted(row.hgnc_id) }"
            @mouseenter="handleTableRowHover(row.hgnc_id)"
            @mouseleave="handleTableRowHover(null)"
          >
            <BLink :to="'/Genes/' + row.hgnc_id">
              <span
                v-b-tooltip.hover.leftbottom
                class="sysndd-chip sysndd-chip--success sysndd-chip--mono"
                :title="row.hgnc_id"
              >
                {{ row.symbol }}
              </span>
            </BLink>
          </div>
        </template>

        <!-- STRING_id cell -->
        <template #cell-STRING_id="{ row }">
          <!-- Render only if tableType === 'identifiers' -->
          <div
            v-if="tableType === 'identifiers'"
            v-b-tooltip.hover
            class="overflow-hidden text-truncate"
            :title="row.STRING_id"
          >
            <BButton
              class="btn-xs mx-2"
              variant="outline-primary"
              :href="'https://string-db.org/network/' + row.STRING_id"
              target="_blank"
              :title="'View ' + row.STRING_id + ' in STRING database'"
              :aria-label="'View ' + row.STRING_id + ' in STRING database'"
            >
              <i class="bi bi-box-arrow-up-right" aria-hidden="true" />
              {{ row.STRING_id }}
            </BButton>
          </div>
        </template>
      </GenericTable>

      <!-- OPTIONAL bottom pagination controls -->
      <BRow class="justify-content-end">
        <BCol cols="12" md="auto" class="my-1">
          <TablePaginationControls
            :total-rows="totalRows"
            :initial-per-page="perPage"
            :page-options="[5, 10, 20]"
            @page-change="handlePageChange"
            @per-page-change="handlePerPageChange"
          />
        </BCol>
      </BRow>
    </div>
  </div>
</template>

<script>
// Small table components
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';

// Filter components
import TermSearch from '@/components/filters/TermSearch.vue';
import CategoryFilter from '@/components/filters/CategoryFilter.vue';
import ScoreSlider from '@/components/filters/ScoreSlider.vue';

import { useFunctionalClusterTable } from './useFunctionalClusterTable';

export default {
  name: 'FunctionalClusterTablePanel',
  components: {
    GenericTable,
    TableLoadingState,
    TablePaginationControls,
    TermSearch,
    CategoryFilter,
    ScoreSlider,
  },
  props: {
    /** Rows to display, keyed by table type ({ term_enrichment, identifiers }). */
    selectedCluster: {
      type: Object,
      required: true,
    },
    /** Category descriptors used for label and link resolution. */
    valueCategories: {
      type: Array,
      default: () => [],
    },
    /** True while the parent is loading cluster data. */
    loading: {
      type: Boolean,
      default: false,
    },
    /** True when the snapshot is still being prepared (503 snapshot_missing). */
    isPreparing: {
      type: Boolean,
      default: false,
    },
    /** True when combined "all clusters" data is displayed. */
    showAllClustersInTable: {
      type: Boolean,
      default: true,
    },
    /** Cluster numbers currently displayed (for the label + export filename). */
    displayedClusters: {
      type: Array,
      default: () => [],
    },
    /** Shared gene search pattern (v-model). */
    geneSearchPattern: {
      type: String,
      default: '',
    },
    /** Network-provided search match count (v-model). */
    searchMatchCount: {
      type: Number,
      default: 0,
    },
    /** All gene symbols for autocomplete suggestions. */
    allGeneSymbols: {
      type: Array,
      default: () => [],
    },
    /** HGNC id currently hovered (from network), for row highlighting. */
    hoveredRowId: {
      type: [String, Number],
      default: null,
    },
  },
  emits: ['update:geneSearchPattern', 'update:searchMatchCount', 'row-hover', 'retry'],
  setup(props, { emit }) {
    return useFunctionalClusterTable(props, emit);
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

/* Truncate description text with ellipsis, show full text on hover */
.description-text {
  max-width: 200px;
  display: inline-block;
  cursor: help;
}

mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}

/* Flat table panel replaces inner BCard to reduce nesting depth */
.cluster-table-panel {
  border: 1px solid var(--border-subtle, #e2e8f0);
  border-radius: var(--radius-md, 6px);
  background: #fff;
  overflow: hidden;
}

.cluster-table-panel__toolbar {
  padding: 0.5rem 0.75rem;
  border-bottom: 1px solid var(--border-subtle, #e2e8f0);
  background: #fafbfc;
}

:deep(.cluster-table-type-control .form-select) {
  min-width: 9.75rem;
}

.cluster-table-loading {
  margin: 0.625rem;
}

/* Cluster badge - matches network legend styling */
.cluster-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 6px;
  border-radius: 4px;
  color: white;
  font-weight: 600;
  font-size: 12px;
}

/* Bidirectional hover highlighting (NAVL-05) */
.symbol-cell {
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  transition: background-color 0.15s ease;
}

.row-highlighted {
  background-color: rgba(var(--bs-warning-rgb), 0.25);
}
</style>
