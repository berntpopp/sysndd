<!-- src/components/analyses/AnalyseGeneClusters.vue -->
<template>
  <AnalysisPanel
    title="Functionally enriched gene clusters"
    description="Explore functional clusters, network structure, and associated gene annotations."
  >
    <template #actions>
      <InlineHelpBadge id="popover-badge-help-geneclusters" aria-label="Explain gene clusters" />
      <BPopover target="popover-badge-help-geneclusters" variant="info" triggers="focus">
        <template #title> Gene Clusters Information </template>
        This section provides insights into gene clusters that are enriched based on their
        functional annotations. Users can explore clusters and analyze the associated genes and
        their properties.
      </BPopover>
    </template>

    <!-- Resizable split panes: LEFT = Graph, RIGHT = Table -->
    <Splitpanes class="default-theme" @resized="handlePaneResized">
      <!-- LEFT PANE (Network Visualization) -->
      <Pane :size="leftPaneSize" :min-size="25" :max-size="75">
        <!-- NetworkVisualization component replaces D3.js bubble chart -->
        <div class="pane-content">
          <!-- Gene search input for network highlighting with autocomplete -->
          <div class="mb-2">
            <TermSearch
              v-model="geneSearchPattern"
              :match-count="searchMatchCount"
              :suggestions="allGeneSymbols"
              placeholder="Search genes (e.g., PKD*, BRCA?)"
            />
          </div>
          <NetworkVisualization
            ref="networkVisualization"
            @cluster-selected="handleClusterSelected"
            @clusters-changed="handleClustersChanged"
            @network-ready="handleNetworkReady"
            @node-hover="handleNetworkNodeHover"
            @search-match-count="handleSearchMatchCount"
          />
        </div>
      </Pane>

      <!-- RIGHT PANE (Table) -->
      <Pane :size="100 - leftPaneSize" :min-size="25">
        <div class="pane-content">
          <!-- LLM Summary Card (above table) - only shown for single cluster selection -->
          <LlmSummaryCard
            v-if="currentSummary && !summaryLoading && !showAllClustersInTable"
            :summary="currentSummary.summary_json"
            :model-name="
              Array.isArray(currentSummary.model_name)
                ? currentSummary.model_name[0]
                : currentSummary.model_name
            "
            :created-at="
              Array.isArray(currentSummary.created_at)
                ? currentSummary.created_at[0]
                : currentSummary.created_at
            "
            :validation-status="
              Array.isArray(currentSummary.validation_status)
                ? currentSummary.validation_status[0]
                : currentSummary.validation_status
            "
            :cluster-number="Number(activeParentCluster)"
          />
          <div v-else-if="summaryLoading && !showAllClustersInTable" class="mb-3">
            <BSpinner small class="me-2" />
            <span class="text-muted">Loading AI summary...</span>
          </div>
          <div v-else-if="showAllClustersSummaryCue" class="cluster-summary-cue" role="status">
            <div class="cluster-summary-cue__text">
              <i class="bi bi-stars" aria-hidden="true" />
              <span>Select one cluster to view its AI summary and focused enrichment table.</span>
            </div>
            <BButton
              v-if="firstAvailableCluster !== null"
              size="sm"
              variant="outline-primary"
              class="cluster-summary-cue__action"
              :aria-label="`View cluster ${firstAvailableCluster} summary`"
              @click="selectDefaultClusterForSummary"
            >
              View cluster {{ firstAvailableCluster }}
            </BButton>
          </div>
          <!-- No placeholder when summary doesn't exist -->

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
                      v-model="geneSearchPattern"
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
        </div>
      </Pane>
    </Splitpanes>
  </AnalysisPanel>
</template>

<script>
import {
  useToast,
  useColorAndSymbols,
  useFilterSync,
  useWildcardSearch,
  useExcelExport,
} from '@/composables';

// Import small table components
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';

// Import filter components
import TermSearch from '@/components/filters/TermSearch.vue';
import CategoryFilter from '@/components/filters/CategoryFilter.vue';
import ScoreSlider from '@/components/filters/ScoreSlider.vue';

// Import NetworkVisualization component (replaces D3.js bubble chart)
import NetworkVisualization from '@/components/analyses/NetworkVisualization.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';

// Import LLM Summary Card for AI-generated cluster summaries
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';

// Import Splitpanes for resizable layout
import { Splitpanes, Pane } from 'splitpanes';
import 'splitpanes/dist/splitpanes.css';

// Import shared cluster color utility for consistent colors
import { getClusterColor } from '@/utils/clusterColors';

// Typed API clients (W5)
import { getFunctionalClustering, getFunctionalClusterSummary } from '@/api/analysis';
import { isApiError } from '@/api/client';
import { filterFunctionalClusterRows, sortFunctionalClusterRows } from './functionalClusterTable';
import {
  combineClusterData,
  clusterRowsWithNumber,
  buildClusterTableFields,
  findCategoryText as findCategoryTextHelper,
  findCategoryLink as findCategoryLinkHelper,
  buildClusterExportFilename,
  clusterExportSheetName,
  CLUSTER_EXPORT_HEADERS,
} from './geneClusterTableData';

export default {
  name: 'AnalyseGeneClusters',
  components: {
    AnalysisPanel,
    GenericTable,
    InlineHelpBadge,
    TableLoadingState,
    TablePaginationControls,
    TermSearch,
    CategoryFilter,
    ScoreSlider,
    NetworkVisualization,
    LlmSummaryCard,
    Splitpanes,
    Pane,
  },
  props: {
    /**
     * Optional filter state from parent AnalysisView
     * Enables shared filter state across analysis views in 27-04
     */
    filterState: {
      type: Object,
      default: null,
    },
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const { filterState: filterSyncState, setSearch } = useFilterSync();

    // Wildcard search for filtering table
    const wildcardSearch = useWildcardSearch();

    // Excel export functionality
    const { isExporting, exportToExcel } = useExcelExport();

    return {
      makeToast,
      ...colorAndSymbols,
      filterSyncState,
      setSearch,
      wildcardSearch,
      isExporting,
      exportToExcel,
    };
  },
  data() {
    return {
      /* --------------------------------------
       * Data from the API
       * ------------------------------------ */
      itemsCluster: [],
      valueCategories: [], // for showing text, link, etc. by category
      selectedCluster: {
        term_enrichment: [],
      },

      /*
       * If you color badges by category, define clusterCategoryStyle object here
       * with fallback "default" color (renamed to avoid conflict with mixin's category_style)
       */
      clusterCategoryStyle: {
        GO: '#AA00AA',
        KEGG: '#AA5500',
        MONDO: '#0088AA',
        default: '#666666', // fallback if row.category not in object
      },

      /* --------------------------------------
       * Table logic
       * ------------------------------------ */
      tableType: 'term_enrichment',
      tableOptions: [
        { value: 'term_enrichment', text: 'Term enrichment' },
        { value: 'identifiers', text: 'Identifiers' },
      ],

      // You can define classes for columns in fields using thClass/tdClass if desired
      // (in computed fieldsComputed below)
      filter: {
        any: { content: null, operator: 'contains' },
        cluster_num: { content: null, operator: 'contains' },
        category: { content: null, operator: 'contains' },
        number_of_genes: { content: null, operator: 'contains' },
        fdr: { content: null, operator: 'contains' },
        description: { content: null, operator: 'contains' },
        symbol: { content: null, operator: 'contains' },
        STRING_id: { content: null, operator: 'contains' },
      },
      // Specialized filter values (separate from text filter object)
      categoryFilter: null, // Selected category (GO, KEGG, MONDO, or null for all)
      fdrThreshold: null, // FDR threshold (0.01, 0.05, 0.1, or custom value)
      sortBy: 'fdr',
      sortDesc: false,

      // Pagination
      perPage: 10,
      totalRows: 1,
      currentPage: 1,

      /* --------------------------------------
       * Clustering logic
       * ------------------------------------ */
      selectOptions: [
        { value: 'clusters', text: 'Clusters' },
      ],
      selectType: 'clusters',
      activeParentCluster: 1,
      activeSubCluster: 1,

      loading: true,
      loadingStage: 'initializing', // 'initializing' | 'submitting' | 'processing' | 'loading_data'
      loadingProgress: 0,
      estimatedSeconds: 15,
      jobId: null,
      algorithm: 'leiden',
      algorithmOptions: [
        { value: 'leiden', text: 'Leiden' },
      ],

      // Resizable pane size (percentage)
      leftPaneSize: 42,

      // Track which clusters are displayed in table (synced from network filter)
      displayedClusters: [],
      showAllClustersInTable: true,

      // Search highlighting state
      searchMatchCount: 0,

      // Bidirectional hover highlighting
      hoveredRowId: null,

      // LLM Summary data
      currentSummary: null,
      summaryLoading: false,
      summaryRequestId: 0,
      clusterTableLoadStarted: false,
    };
  },
  computed: {
    /**
     * Computed property for gene search pattern (v-model binding)
     * Gets/sets filterState.search via the composable
     */
    geneSearchPattern: {
      get() {
        return this.filterSyncState?.search || '';
      },
      set(val) {
        this.setSearch(val);
      },
    },

    /**
     * Whether we're showing combined data from multiple clusters
     */
    isShowingCombinedData() {
      return this.showAllClustersInTable || this.displayedClusters.length > 1;
    },

    firstAvailableCluster() {
      const firstCluster = this.itemsCluster?.[0]?.cluster;
      return firstCluster == null ? null : Number(firstCluster);
    },

    showAllClustersSummaryCue() {
      return !this.loading && this.itemsCluster.length > 0 && this.showAllClustersInTable;
    },

    /**
     * All gene symbols for autocomplete suggestions
     */
    allGeneSymbols() {
      const identifiers = this.selectedCluster?.identifiers || [];
      return [...new Set(identifiers.map((row) => row.symbol))].sort();
    },

    /**
     * Category options for CategoryFilter dropdown
     * Derived from valueCategories loaded from API
     */
    categoryOptions() {
      if (!this.valueCategories || this.valueCategories.length === 0) {
        return [
          { value: 'GO', text: 'GO (Gene Ontology)' },
          { value: 'KEGG', text: 'KEGG (Pathways)' },
          { value: 'MONDO', text: 'MONDO (Disease)' },
        ];
      }
      return this.valueCategories.map((cat) => ({
        value: cat.value,
        text: cat.text,
      }));
    },

    /**
     * fieldsComputed: Return fields array based on tableType
     * with thClass/tdClass for styling. Delegates to the pure field builder.
     */
    fieldsComputed() {
      return buildClusterTableFields(this.tableType);
    },

    /**
     * Label showing which cluster(s) data is displayed in the table
     */
    clusterDisplayLabel() {
      if (this.showAllClustersInTable || this.displayedClusters.length === 0) {
        return 'All Clusters';
      }
      if (this.displayedClusters.length === 1) {
        return `Cluster ${this.displayedClusters[0]}`;
      }
      return `Clusters ${[...this.displayedClusters].sort((a, b) => a - b).join(', ')}`;
    },

    /**
     * displayedItems: Filtered + sorted + paginated items for the current tableType
     */
    displayedItems() {
      let dataArray = this.selectedCluster[this.tableType] || [];
      dataArray = this.applyFilters(dataArray);
      dataArray = sortFunctionalClusterRows(dataArray, this.sortBy, this.sortDesc);

      // Pagination
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    activeParentCluster() {
      if (this.selectType === 'clusters') {
        this.setActiveCluster();
      }
    },
    tableType() {
      // When user changes tableType, re-check totalRows with filters applied
      this.updateFilteredTotalRows();
      this.currentPage = 1;
    },
    selectType() {
      this.resetCluster();
    },
    // Watch for search pattern changes to update table filtering
    'filterSyncState.search': {
      handler() {
        this.updateFilteredTotalRows();
        this.currentPage = 1;
      },
      immediate: false,
    },
    categoryFilter() {
      this.updateFilteredTotalRows();
      this.currentPage = 1;
    },
    fdrThreshold() {
      this.updateFilteredTotalRows();
      this.currentPage = 1;
    },
  },
  mounted() {
    this.startClusterTableLoad();
  },
  methods: {
    /**
     * Helper method: find category text from valueCategories
     * (delegates to the pure helper).
     */
    findCategoryText(categoryVal) {
      return findCategoryTextHelper(this.valueCategories, categoryVal);
    },
    /**
     * Helper method: build link from valueCategories
     * (delegates to the pure helper).
     */
    findCategoryLink(categoryVal, termVal) {
      return findCategoryLinkHelper(this.valueCategories, categoryVal, termVal);
    },

    /**
     * Map category value to a sysndd-chip modifier class.
     * Uses quiet token chips instead of heavy dark-bordered BBadge.
     */
    getCategoryChipClass(category) {
      const map = {
        GO: 'sysndd-chip--teal',
        KEGG: 'sysndd-chip--blue',
        MONDO: 'sysndd-chip--info',
        HPO: 'sysndd-chip--success',
      };
      return map[category] || 'sysndd-chip--neutral';
    },

    /**
     * Format FDR value as scientific notation so tiny values (e.g. 1e-15)
     * render meaningfully instead of as "0".
     */
    formatFdr(fdr) {
      if (fdr == null) return '—';
      const n = Number(fdr);
      if (Number.isNaN(n)) return String(fdr);
      if (n === 0) return '0';
      if (n < 0.001 || n >= 1000) {
        return n.toExponential(2);
      }
      return n.toPrecision(3);
    },

    /**
     * Get cluster color by cluster number
     * Uses shared utility for consistent colors across table and network
     */
    getClusterColor(clusterNum) {
      return getClusterColor(clusterNum);
    },

    startClusterTableLoad() {
      if (this.clusterTableLoadStarted) return;
      this.clusterTableLoadStarted = true;
      this.loadClusterData();
    },

    handleNetworkReady() {
      this.startClusterTableLoad();
    },

    async loadClusterData() {
      await this.loadClusterDataSync();
    },

    /**
     * Fallback: Synchronous data loading (for when async fails)
     */
    async loadClusterDataSync() {
      this.loadingStage = 'loading_data';
      this.loadingProgress = 50;

      try {
        const data = await getFunctionalClustering({
          page_size: '50',
        });
        this.itemsCluster = data.clusters;
        this.valueCategories = data.categories;

        // Default to showing all clusters
        // User can select individual clusters to see AI summaries
        if (this.itemsCluster.length > 0) {
          this.showAllClustersInTable = true;
          this.displayedClusters = [];
          this.activeParentCluster = null;
          this.setActiveCluster();
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
    },

    /**
     * Reload with different algorithm
     * Note: v-model already updates this.algorithm before @change fires,
     * so we just trigger a reload with the current (already updated) algorithm
     */
    async reloadWithAlgorithm() {
      // Set loading first - Vue will hide D3 container and show loading spinner
      this.loading = true;
      this.loadingProgress = 0;
      this.loadingStage = 'loading_data';
      this.clusterTableLoadStarted = true;

      // Wait for Vue to swap from D3 container to loading spinner
      await this.$nextTick();

      // v-model already updated this.algorithm, and :key="'graph-' + algorithm"
      // will force container recreation when loading finishes

      // Load new data with updated algorithm
      await this.loadClusterData();
    },

    setActiveCluster() {
      // Handle "All Clusters" mode - combine data from all clusters
      if (this.showAllClustersInTable) {
        this.selectedCluster = this.combineClusterData(this.itemsCluster);
        const arr = this.selectedCluster[this.tableType] || [];
        this.totalRows = arr.length;
        return;
      }

      const match = this.itemsCluster.find((item) => item.cluster === this.activeParentCluster);
      const clusterNum = this.activeParentCluster;

      // Add cluster_num to each row for consistent display
      this.selectedCluster = clusterRowsWithNumber(match, clusterNum);

      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
    },

    resetCluster() {
      this.activeParentCluster = 1;
      this.activeSubCluster = 1;
      this.setActiveCluster();
    },

    /* --------------------------------------
     * Filtering logic
     * ------------------------------------ */
    applyFilters(items) {
      // Sync wildcard pattern from filterState
      const searchPattern = this.filterSyncState?.search || '';
      if (searchPattern !== this.wildcardSearch.pattern.value) {
        this.wildcardSearch.pattern.value = searchPattern;
      }

      const columnFilters = Object.fromEntries(
        Object.entries(this.filter)
          .filter(([key]) => key !== 'any')
          .map(([key, filter]) => [key, filter.content])
      );

      return filterFunctionalClusterRows(items, {
        tableType: this.tableType,
        searchPattern,
        wildcardMatches: (symbol) => this.wildcardSearch.matches(symbol),
        categoryFilter: this.categoryFilter,
        fdrThreshold: this.fdrThreshold,
        anyText: this.filter.any.content,
        columnFilters,
      });
    },
    onFilterChange() {
      this.currentPage = 1;
    },

    /**
     * Update totalRows based on filtered data
     * Called when search pattern or tableType changes
     */
    updateFilteredTotalRows() {
      const arr = this.selectedCluster[this.tableType] || [];
      const filtered = this.applyFilters(arr);
      this.totalRows = filtered.length;

      // Update search match count for identifiers table
      if (this.tableType === 'identifiers' && this.filterSyncState?.search) {
        this.searchMatchCount = filtered.length;
      }
    },

    /* --------------------------------------
     * Pagination
     * ------------------------------------ */
    handlePageChange(newPage) {
      this.currentPage = newPage;
    },
    handlePerPageChange(newPerPage) {
      this.perPage = newPerPage;
      this.currentPage = 1;
    },

    /* --------------------------------------
     * Sorting
     * ------------------------------------ */
    handleSortUpdate({ sortBy, sortDesc }) {
      this.sortBy = sortBy;
      this.sortDesc = sortDesc;
    },

    /* --------------------------------------
     * Network visualization event handlers
     * ------------------------------------ */
    handleClusterSelected(hgncId) {
      // Handle node click from NetworkVisualization
      // This can be used for table synchronization or other interactions
      console.log('Gene selected from network:', hgncId);
    },

    selectDefaultClusterForSummary() {
      if (this.firstAvailableCluster === null) return;
      this.$refs.networkVisualization?.selectSingleCluster?.(this.firstAvailableCluster);
    },

    /**
     * Handle network node hover - highlight corresponding table row
     * Part of bidirectional hover highlighting (NAVL-05)
     */
    handleNetworkNodeHover(nodeId) {
      this.hoveredRowId = nodeId;
    },

    /**
     * Handle search match count updates from network
     * Updates the TermSearch component feedback
     */
    handleSearchMatchCount(count) {
      this.searchMatchCount = count;
    },

    /**
     * Handle table row hover - highlight corresponding network node
     * Part of bidirectional hover highlighting (NAVL-05)
     */
    handleTableRowHover(hgncId) {
      this.hoveredRowId = hgncId;
      // Call network highlight method via ref
      if (this.$refs.networkVisualization) {
        this.$refs.networkVisualization.highlightNodeFromTable(hgncId);
      }
    },

    /**
     * Check if a table row should be highlighted (from network hover)
     */
    isRowHighlighted(hgncId) {
      return this.hoveredRowId === hgncId;
    },

    /**
     * Fetch LLM-generated summary for a specific cluster
     * Uses cluster's hash_filter as the cluster_hash parameter
     */
    async fetchClusterSummary(clusterHash, clusterNumber) {
      if (!clusterHash) {
        this.clearClusterSummary();
        return;
      }

      const requestId = ++this.summaryRequestId;
      this.summaryLoading = true;
      try {
        const data = await getFunctionalClusterSummary({
          cluster_hash: clusterHash,
          cluster_number: String(clusterNumber),
        });
        if (requestId !== this.summaryRequestId) return;
        this.currentSummary = data;
      } catch (error) {
        if (requestId !== this.summaryRequestId) return;
        // 404 is expected when summary doesn't exist yet - treat as no summary
        if (isApiError(error) && error.response && error.response.status === 404) {
          this.currentSummary = null;
          return;
        }
        // Only reaches here for actual errors (network, 500, etc.)
        this.makeToast(
          'Unable to load AI summary. The summary may still be generating.',
          'Info',
          'info'
        );
        this.currentSummary = null;
      } finally {
        if (requestId === this.summaryRequestId) {
          this.summaryLoading = false;
        }
      }
    },

    clearClusterSummary() {
      this.summaryRequestId += 1;
      this.currentSummary = null;
      this.summaryLoading = false;
    },

    /**
     * Handle cluster filter changes from NetworkVisualization
     * Updates the table to show data for selected cluster(s)
     */
    handleClustersChanged(clusters, showAll) {
      console.log('Clusters changed:', clusters, 'showAll:', showAll);

      // Track which clusters are displayed for the label
      this.displayedClusters = [...clusters];
      this.showAllClustersInTable = showAll || clusters.length === 0;

      if (showAll || clusters.length === 0) {
        // Show combined data from all clusters
        this.selectedCluster = this.combineClusterData(this.itemsCluster);
        // Clear summary when showing all clusters
        this.clearClusterSummary();
      } else if (clusters.length === 1) {
        // Single cluster selected - show that cluster's data
        this.activeParentCluster = clusters[0];
        this.setActiveCluster();
        // Fetch LLM summary for this cluster
        const clusterData = this.itemsCluster.find((item) => item.cluster === clusters[0]);
        if (clusterData?.hash_filter) {
          this.fetchClusterSummary(clusterData.hash_filter, clusters[0]);
        } else {
          this.clearClusterSummary();
        }
      } else {
        // Multiple clusters selected - combine their data
        const selectedClusterData = this.itemsCluster.filter((item) =>
          clusters.includes(item.cluster)
        );
        this.selectedCluster = this.combineClusterData(selectedClusterData);
        // Clear summary when showing multiple clusters
        this.clearClusterSummary();
      }

      // Update pagination
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1;
    },

    /**
     * Combine data from multiple clusters into a single object
     * (delegates to the pure helper).
     */
    combineClusterData(clusterArray) {
      return combineClusterData(clusterArray);
    },

    /**
     * Handle pane resize events from Splitpanes
     * Updates leftPaneSize and triggers network refit
     */
    handlePaneResized(panes) {
      if (panes && panes.length > 0) {
        this.leftPaneSize = panes[0].size;
      }
    },

    /**
     * Download the current table data as Excel file
     * Exports all filtered data (not just the current page)
     */
    downloadExcel() {
      // Get all filtered data (not just paginated subset)
      let dataArray = this.selectedCluster[this.tableType] || [];
      dataArray = this.applyFilters(dataArray);

      if (dataArray.length === 0) {
        this.makeToast('No data to export', 'Warning', 'warning');
        return;
      }

      // Define column headers based on table type
      const headers = CLUSTER_EXPORT_HEADERS[this.tableType];

      // Generate filename with context
      const filename = buildClusterExportFilename(
        this.tableType,
        this.showAllClustersInTable,
        this.displayedClusters
      );

      this.exportToExcel(dataArray, {
        filename,
        sheetName: clusterExportSheetName(this.tableType),
        headers,
      });
    },
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

/* Splitpanes layout */
.splitpanes {
  min-height: 650px;
}

.pane-content {
  padding: 12px;
  height: 100%;
  overflow: auto;
}

.cluster-summary-cue {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--border-subtle, #e2e8f0);
  border-radius: var(--radius-md, 6px);
  background: var(--medical-blue-50, #e3f2fd);
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
}

.cluster-summary-cue__text {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  min-width: 0;
}

.cluster-summary-cue__text .bi {
  color: var(--medical-blue-700, #0d47a1);
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

.cluster-summary-cue__action {
  flex: 0 0 auto;
  /* Ensure the outline button text clears AA on the cue background. */
  color: var(--medical-blue-700, #0d47a1);
  border-color: var(--medical-blue-700, #0d47a1);
}

:deep(.cluster-table-type-control .form-select) {
  min-width: 9.75rem;
}

.cluster-table-loading {
  margin: 0.625rem;
}

@media (max-width: 767.98px) {
  .cluster-summary-cue {
    align-items: flex-start;
    flex-direction: column;
  }
}

/* Override splitpanes default theme for better visibility */
/* Use :deep() for Vue 3 scoped styles to affect child components */
:deep(.splitpanes.default-theme .splitpanes__splitter) {
  background-color: var(--border-subtle, #e2e8f0);
  min-width: 8px;
  border-left: 1px solid var(--neutral-300, #e0e0e0);
  border-right: 1px solid var(--neutral-300, #e0e0e0);
  cursor: col-resize;
  position: relative;
}

:deep(.splitpanes.default-theme .splitpanes__splitter:hover) {
  background-color: var(--neutral-300, #e0e0e0);
}

:deep(.splitpanes.default-theme .splitpanes__splitter::before) {
  content: '⋮';
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  font-size: 16px;
  color: var(--neutral-600, #757575);
  font-weight: bold;
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
