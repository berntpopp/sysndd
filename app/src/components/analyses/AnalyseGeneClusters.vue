<!-- src/components/analyses/AnalyseGeneClusters.vue -->
<template>
  <BContainer fluid>
    <!-- Main card -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Functionally enriched
            <mark
              v-b-tooltip.hover.leftbottom
              title="This section displays gene clusters that are enriched based on functional annotations. It allows users to explore and analyze the clusters."
            >
              gene clusters
            </mark>.
            <BBadge
              id="popover-badge-help-geneclusters"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-geneclusters"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Gene Clusters Information
              </template>
              This section provides insights into gene clusters that are enriched based on their functional annotations.
              Users can explore various clusters/subclusters, and analyze the associated genes and their properties.
            </BPopover>
          </h6>
          <!-- Network export buttons now in NetworkVisualization component -->
        </div>
      </template>

      <!-- Resizable split panes: LEFT = Graph, RIGHT = Table -->
      <Splitpanes
        class="default-theme"
        @resized="handlePaneResized"
      >
        <!-- LEFT PANE (Network Visualization) -->
        <Pane
          :size="leftPaneSize"
          :min-size="25"
          :max-size="75"
        >
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
              :cluster-type="selectType"
              @cluster-selected="handleClusterSelected"
              @clusters-changed="handleClustersChanged"
              @node-hover="handleNetworkNodeHover"
              @search-match-count="handleSearchMatchCount"
            />
          </div>
        </Pane>

        <!-- RIGHT PANE (Table) -->
        <Pane
          :size="100 - leftPaneSize"
          :min-size="25"
        >
          <div class="pane-content">
            <BCard
              header-tag="header"
              class="text-start"
              body-class="p-0"
              header-class="p-1"
              border-variant="dark"
            >
            <!-- TABLE HEADER (Table type, Search input, etc.) -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <BRow>
                  <BCol
                    sm="4"
                    class="mb-1"
                  >
                    <!-- Table type selector (term_enrichment vs. identifiers) -->
                    <BInputGroup
                      prepend="Table type"
                      size="sm"
                    >
                      <BFormSelect
                        v-model="tableType"
                        :options="tableOptions"
                        size="sm"
                      />
                    </BInputGroup>
                  </BCol>

                  <BCol
                    sm="4"
                    class="mb-1 text-center"
                  >
                    <!-- Cluster indicator showing which data is displayed -->
                    <BBadge
                      v-b-tooltip.hover
                      :variant="showAllClustersInTable ? 'secondary' : 'primary'"
                      class="py-1 px-2"
                      title="Select clusters in the network to filter table data"
                    >
                      <i class="bi bi-diagram-3 me-1" />
                      {{ clusterDisplayLabel }}
                    </BBadge>
                  </BCol>

                  <BCol
                    sm="4"
                    class="mb-1 text-end"
                  >
                    <!-- Gene search synced with network (uses same geneSearchPattern) -->
                    <TermSearch
                      v-model="geneSearchPattern"
                      :match-count="tableType === 'identifiers' ? searchMatchCount : null"
                      :suggestions="allGeneSymbols"
                      placeholder="Search genes..."
                    />
                  </BCol>
                </BRow>
              </div>
            </template>

            <BCardText class="text-start">
              <!-- GenericTable for main table content -->
              <GenericTable
                :items="displayedItems"
                :fields="fieldsComputed"
                :sort-by="sortBy"
                :sort-desc="sortDesc"
                @update-sort="handleSortUpdate"
              >
                <!-- Optional column-level filters -->
                <template v-slot:filter-controls>
                  <td
                    v-for="field in fieldsComputed"
                    :key="field.key"
                  >
                    <!-- Cluster number: keep text filter -->
                    <BFormInput
                      v-if="field.key === 'cluster_num'"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label"
                      debounce="500"
                      @input="onFilterChange"
                    />

                    <!-- Category: use CategoryFilter dropdown -->
                    <CategoryFilter
                      v-else-if="field.key === 'category'"
                      v-model="categoryFilter"
                      :options="categoryOptions"
                      placeholder="All categories"
                      @update:modelValue="onFilterChange"
                    />

                    <!-- FDR: use ScoreSlider with presets -->
                    <ScoreSlider
                      v-else-if="field.key === 'fdr'"
                      v-model="fdrThreshold"
                      @update:modelValue="onFilterChange"
                    />

                    <!-- Other columns: text filter (symbol, STRING_id, description, etc.) -->
                    <BFormInput
                      v-else-if="field.key !== 'details' && field.key !== 'number_of_genes'"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label"
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

                <!-- category cell -->
                <template #cell-category="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div v-if="tableType === 'term_enrichment'">
                    <BBadge
                      v-b-tooltip.hover.rightbottom
                      variant="light"
                      :style="'border-color: ' + (clusterCategoryStyle[row.category] || clusterCategoryStyle.default) + '; border-width: medium;'"
                      :title="row.category"
                    >
                      {{ findCategoryText(row.category) }}
                    </BBadge>
                  </div>
                </template>

                <template #cell-number_of_genes="{ row }">
                  <BBadge variant="info">
                    {{ row['number_of_genes'] }}
                  </BBadge>
                </template>

                <!-- fdr cell -->
                <template #cell-fdr="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div
                    v-if="tableType === 'term_enrichment'"
                    v-b-tooltip.hover.leftbottom
                    class="overflow-hidden text-truncate"
                    :title="row.fdr != null ? Number(row.fdr).toFixed(10) : ''"
                  >
                    <BBadge variant="warning">
                      {{ row.fdr }}
                    </BBadge>
                  </div>
                </template>

                <!-- description cell -->
                <template #cell-description="{ row }">
                  <!-- Render only if tableType === 'term_enrichment' -->
                  <div v-if="tableType === 'term_enrichment'">
                    <BButton
                      v-b-tooltip.hover.leftbottom
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="findCategoryLink(row.category, row.term)"
                      :title="row.term"
                      target="_blank"
                    >
                      <i class="bi bi-box-arrow-up-right" />
                      {{ row.description }}
                    </BButton>
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
                    <BLink :href="'/Genes/' + row.hgnc_id">
                      <BBadge
                        v-b-tooltip.hover.leftbottom
                        pill
                        variant="success"
                        :title="row.hgnc_id"
                      >
                        {{ row.symbol }}
                      </BBadge>
                    </BLink>
                  </div>
                </template>

                <!-- STRING_id cell -->
                <template #cell-STRING_id="{ row }">
                  <!-- Render only if tableType === 'identifiers' -->
                  <div
                    v-if="tableType === 'identifiers'"
                    class="overflow-hidden text-truncate"
                  >
                    <BButton
                      class="btn-xs mx-2"
                      variant="outline-primary"
                      :href="'https://string-db.org/network/' + row.STRING_id"
                      target="_blank"
                    >
                      <i class="bi bi-box-arrow-up-right" />
                      {{ row.STRING_id }}
                    </BButton>
                  </div>
                </template>
              </GenericTable>

              <!-- OPTIONAL bottom pagination controls -->
              <BRow class="justify-content-end">
                <BCol
                  cols="12"
                  md="auto"
                  class="my-1"
                >
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="[5, 10, 20]"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </BCol>
              </BRow>
            </BCardText>
          </BCard>
          </div>
        </Pane>
      </Splitpanes>
    </BCard>
  </BContainer>
</template>

<script>
import { useToast, useColorAndSymbols, useFilterSync, useWildcardSearch } from '@/composables';

// Import small table components
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

// Import filter components
import TermSearch from '@/components/filters/TermSearch.vue';
import CategoryFilter from '@/components/filters/CategoryFilter.vue';
import ScoreSlider from '@/components/filters/ScoreSlider.vue';

// Import NetworkVisualization component (replaces D3.js bubble chart)
import NetworkVisualization from '@/components/analyses/NetworkVisualization.vue';

// Import Splitpanes for resizable layout
import { Splitpanes, Pane } from 'splitpanes';
import 'splitpanes/dist/splitpanes.css';

// Import shared cluster color utility for consistent colors
import { getClusterColor } from '@/utils/clusterColors';

export default {
  name: 'AnalyseGeneClusters',
  components: {
    GenericTable,
    TablePaginationControls,
    TermSearch,
    CategoryFilter,
    ScoreSlider,
    NetworkVisualization,
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
    const { filterState, setSearch } = useFilterSync();

    // Wildcard search for filtering table
    const wildcardSearch = useWildcardSearch();

    return {
      makeToast,
      ...colorAndSymbols,
      filterState,
      setSearch,
      wildcardSearch,
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
      fdrThreshold: null,   // FDR threshold (0.01, 0.05, 0.1, or custom value)
      sortBy: 'category',
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
        { value: 'subclusters', text: 'Subclusters' },
      ],
      selectType: 'clusters',
      activeParentCluster: 1,
      activeSubCluster: 1,

      loading: true,
      loadingStage: 'initializing', // 'initializing' | 'submitting' | 'processing' | 'loading_data'
      loadingProgress: 0,
      estimatedSeconds: 15,
      jobId: null,
      algorithm: 'leiden', // 'leiden' (fast) or 'walktrap' (legacy)
      algorithmOptions: [
        { value: 'leiden', text: 'Leiden (Fast)' },
        { value: 'walktrap', text: 'Walktrap (Legacy)' },
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
    };
  },
  computed: {
    /**
     * Computed property for gene search pattern (v-model binding)
     * Gets/sets filterState.search via the composable
     */
    geneSearchPattern: {
      get() {
        return this.filterState?.search || '';
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
      return this.valueCategories.map(cat => ({
        value: cat.value,
        text: cat.text,
      }));
    },

    /**
     * fieldsComputed: Return fields array based on tableType
     * with thClass/tdClass for styling
     * Adds cluster column when showing combined data from multiple clusters
     */
    fieldsComputed() {
      const clusterColumn = {
        key: 'cluster_num',
        label: 'Cluster',
        sortable: true,
        thClass: 'text-start bg-light',
        tdClass: 'text-start',
      };

      if (this.tableType === 'term_enrichment') {
        const fields = [
          {
            key: 'category',
            label: 'Category',
            sortable: true,
            thClass: 'text-start bg-light', // header cell class
            tdClass: 'text-start', // data cell class
          },
          {
            key: 'number_of_genes',
            label: '#Genes',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
          {
            key: 'fdr',
            label: 'FDR',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
          {
            key: 'description',
            label: 'Description',
            sortable: true,
            thClass: 'text-start bg-light',
            tdClass: 'text-start',
          },
        ];
        // Always show cluster column for consistency between table and network
        fields.unshift(clusterColumn);
        return fields;
      }
      // 'identifiers' case
      const fields = [
        {
          key: 'symbol',
          label: 'Symbol',
          sortable: true,
          thClass: 'text-start bg-light',
          tdClass: 'text-start',
        },
        {
          key: 'STRING_id',
          label: 'STRING ID',
          sortable: true,
          thClass: 'text-start bg-light',
          tdClass: 'text-start',
        },
      ];
      // Always show cluster column for consistency between table and network
      fields.unshift(clusterColumn);
      return fields;
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
      return `Clusters ${this.displayedClusters.sort((a, b) => a - b).join(', ')}`;
    },

    /**
     * displayedItems: Filtered + paginated items for the current tableType
     */
    displayedItems() {
      let dataArray = this.selectedCluster[this.tableType] || [];
      dataArray = this.applyFilters(dataArray);

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
    activeSubCluster() {
      if (this.selectType === 'subclusters') {
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
    'filterState.search': {
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
    this.loadClusterData();
  },
  methods: {
    /**
     * Helper method: find category text from valueCategories
     */
    findCategoryText(categoryVal) {
      const found = this.valueCategories.find((cat) => cat.value === categoryVal);
      return found ? found.text : categoryVal; // fallback to raw category if not found
    },
    /**
     * Helper method: build link from valueCategories
     */
    findCategoryLink(categoryVal, termVal) {
      const found = this.valueCategories.find((cat) => cat.value === categoryVal);
      return found ? found.link + termVal : '#';
    },

    /**
     * Get cluster color by cluster number
     * Uses shared utility for consistent colors across table and network
     */
    getClusterColor(clusterNum) {
      return getClusterColor(clusterNum);
    },

    /* --------------------------------------
     * Load cluster data from API using async job system
     * ------------------------------------ */
    async loadClusterData() {
      this.loading = true;
      this.loadingStage = 'submitting';
      this.loadingProgress = 5;

      const baseUrl = import.meta.env.VITE_API_URL;

      try {
        // Step 1: Submit async job
        const submitResponse = await this.axios.post(
          `${baseUrl}/api/jobs/clustering/submit`,
          { algorithm: this.algorithm },
        );

        // Extract job info (R returns arrays for scalars)
        const jobId = Array.isArray(submitResponse.data.job_id)
          ? submitResponse.data.job_id[0]
          : submitResponse.data.job_id;
        const estSeconds = Array.isArray(submitResponse.data.estimated_seconds)
          ? submitResponse.data.estimated_seconds[0]
          : submitResponse.data.estimated_seconds;

        this.jobId = jobId;
        this.estimatedSeconds = estSeconds || 30;

        this.loadingStage = 'processing';
        this.loadingProgress = 15;

        // Step 2: Poll for results
        await this.pollJobStatus();
      } catch (e) {
        // Handle 409 Conflict (duplicate job) - silently use existing job
        if (e.response && e.response.status === 409) {
          const existingJobId = Array.isArray(e.response.data.existing_job_id)
            ? e.response.data.existing_job_id[0]
            : e.response.data.existing_job_id;
          this.jobId = existingJobId;
          this.loadingStage = 'processing';
          this.loadingProgress = 15;
          await this.pollJobStatus();
          return;
        }

        // Other errors: show toast and fall back to sync endpoint
        this.makeToast('Using synchronous loading (async unavailable)', 'Info', 'info');
        await this.loadClusterDataSync();
      }
    },

    /**
     * Poll job status until complete
     */
    async pollJobStatus() {
      const baseUrl = import.meta.env.VITE_API_URL;
      const maxAttempts = 60; // 5 minutes max (60 * 5 seconds)
      let attempts = 0;
      const startTime = Date.now();

      const poll = async () => {
        attempts += 1;

        try {
          const statusResponse = await this.axios.get(
            `${baseUrl}/api/jobs/${this.jobId}/status`,
          );

          const responseData = statusResponse.data;

          // R/plumber may return scalars as single-element arrays
          const status = Array.isArray(responseData.status)
            ? responseData.status[0]
            : responseData.status;
          const result = responseData.result;
          const progress = responseData.progress;

          // Update progress based on elapsed time vs estimate
          const elapsed = (Date.now() - startTime) / 1000;
          const estimatedProgress = Math.min(90, 15 + (elapsed / this.estimatedSeconds) * 75);
          this.loadingProgress = progress || estimatedProgress;

          if (status === 'completed') {
            this.loadingStage = 'loading_data';
            this.loadingProgress = 95;

            // Process result - handle both {clusters, categories} and flat array formats
            if (result && result.clusters) {
              this.itemsCluster = result.clusters;
              this.valueCategories = result.categories || [];
            } else if (Array.isArray(result)) {
              this.itemsCluster = result;
              this.valueCategories = [];
            } else {
              this.itemsCluster = result;
              this.valueCategories = [];
            }

            // Update loading state
            this.loadingProgress = 100;
            this.loading = false;

            // Set table display - show combined data for all clusters by default
            this.$nextTick(() => {
              if (this.showAllClustersInTable) {
                // Show combined data from all clusters
                this.selectedCluster = this.combineClusterData(this.itemsCluster);
                const arr = this.selectedCluster[this.tableType] || [];
                this.totalRows = arr.length;
              } else {
                this.setActiveCluster();
              }
            });
            return;
          }

          if (status === 'failed') {
            throw new Error(responseData.error || 'Clustering job failed');
          }

          // Still running, poll again
          if (attempts < maxAttempts) {
            const retryAfter = parseInt(statusResponse.headers['retry-after'] || '5', 10) * 1000;
            setTimeout(poll, retryAfter);
          } else {
            throw new Error('Job timed out after 5 minutes');
          }
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
          this.loading = false;
        }
      };

      await poll();
    },

    /**
     * Fallback: Synchronous data loading (for when async fails)
     */
    async loadClusterDataSync() {
      this.loadingStage = 'loading_data';
      this.loadingProgress = 50;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/analysis/functional_clustering?algorithm=${this.algorithm}`;
      try {
        const response = await this.axios.get(apiUrl);
        this.itemsCluster = response.data.clusters;
        this.valueCategories = response.data.categories;
        // Show combined data from all clusters by default
        if (this.showAllClustersInTable) {
          this.selectedCluster = this.combineClusterData(this.itemsCluster);
          const arr = this.selectedCluster[this.tableType] || [];
          this.totalRows = arr.length;
        } else {
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
      this.loadingStage = 'submitting';

      // Wait for Vue to swap from D3 container to loading spinner
      await this.$nextTick();

      // v-model already updated this.algorithm, and :key="'graph-' + algorithm"
      // will force container recreation when loading finishes

      // Load new data with updated algorithm
      await this.loadClusterData();
    },

    setActiveCluster() {
      let match;
      let subClusters;
      let clusterNum;

      if (this.selectType === 'clusters') {
        match = this.itemsCluster.find((item) => item.cluster === this.activeParentCluster);
        clusterNum = this.activeParentCluster;
      } else {
        // subclusters
        subClusters = this.itemsCluster.find((item) => item.cluster === this.activeParentCluster);
        if (subClusters) {
          match = subClusters.subclusters.find((sub) => sub.cluster === this.activeSubCluster);
        }
        clusterNum = this.activeSubCluster;
      }

      // Add cluster_num to each row for consistent display
      if (match) {
        this.selectedCluster = {
          term_enrichment: (match.term_enrichment || []).map((row) => ({
            ...row,
            cluster_num: clusterNum,
          })),
          identifiers: (match.identifiers || []).map((row) => ({
            ...row,
            cluster_num: clusterNum,
          })),
        };
      } else {
        this.selectedCluster = { term_enrichment: [], identifiers: [] };
      }

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
      const anyVal = (this.filter.any.content || '').toLowerCase();

      // Sync wildcard pattern from filterState
      const searchPattern = this.filterState?.search || '';
      if (searchPattern !== this.wildcardSearch.pattern.value) {
        this.wildcardSearch.pattern.value = searchPattern;
      }

      return items.filter((row) => {
        // 0) Wildcard gene search filter (for identifiers table)
        if (searchPattern && this.tableType === 'identifiers' && row.symbol) {
          if (!this.wildcardSearch.matches(row.symbol)) {
            return false;
          }
        }

        // 1) Category dropdown filter (for term_enrichment table)
        if (this.categoryFilter && this.tableType === 'term_enrichment') {
          if (row.category !== this.categoryFilter) {
            return false;
          }
        }

        // 2) FDR threshold filter (for term_enrichment table)
        if (this.fdrThreshold !== null && this.tableType === 'term_enrichment') {
          const fdrValue = parseFloat(row.fdr);
          if (isNaN(fdrValue) || fdrValue >= this.fdrThreshold) {
            return false;
          }
        }

        // 3) "any" filter
        if (anyVal) {
          const rowString = Object.values(row).join(' ').toLowerCase();
          if (!rowString.includes(anyVal)) {
            return false;
          }
        }

        // 4) column-specific text filters
        const filterKeys = Object.keys(this.filter).filter((k) => k !== 'any');
        let keep = true;
        filterKeys.forEach((fieldKey) => {
          const colVal = (this.filter[fieldKey].content || '').toLowerCase();
          if (colVal) {
            const rowVal = String(row[fieldKey] || '').toLowerCase();
            if (!rowVal.includes(colVal)) {
              keep = false;
            }
          }
        });
        return keep;
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
      if (this.tableType === 'identifiers' && this.filterState?.search) {
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
      } else if (clusters.length === 1) {
        // Single cluster selected - show that cluster's data
        this.activeParentCluster = clusters[0];
        this.setActiveCluster();
      } else {
        // Multiple clusters selected - combine their data
        const selectedClusterData = this.itemsCluster.filter(
          (item) => clusters.includes(item.cluster)
        );
        this.selectedCluster = this.combineClusterData(selectedClusterData);
      }

      // Update pagination
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1;
    },

    /**
     * Combine data from multiple clusters into a single object
     * Adds cluster number to each row so users can see which cluster it belongs to
     */
    combineClusterData(clusterArray) {
      const combined = {
        term_enrichment: [],
        identifiers: [],
      };

      clusterArray.forEach((cluster) => {
        const clusterNum = cluster.cluster;
        if (cluster.term_enrichment) {
          // Add cluster number to each enrichment row
          const enrichmentWithCluster = cluster.term_enrichment.map((row) => ({
            ...row,
            cluster_num: clusterNum,
          }));
          combined.term_enrichment = combined.term_enrichment.concat(enrichmentWithCluster);
        }
        if (cluster.identifiers) {
          // Add cluster number to each identifier row
          const identifiersWithCluster = cluster.identifiers.map((row) => ({
            ...row,
            cluster_num: clusterNum,
          }));
          combined.identifiers = combined.identifiers.concat(identifiersWithCluster);
        }
      });

      return combined;
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

/* Override splitpanes default theme for better visibility */
/* Use :deep() for Vue 3 scoped styles to affect child components */
:deep(.splitpanes.default-theme .splitpanes__splitter) {
  background-color: #dee2e6;
  min-width: 8px;
  border-left: 1px solid #adb5bd;
  border-right: 1px solid #adb5bd;
  cursor: col-resize;
  position: relative;
}

:deep(.splitpanes.default-theme .splitpanes__splitter:hover) {
  background-color: #adb5bd;
}

:deep(.splitpanes.default-theme .splitpanes__splitter::before) {
  content: '⋮';
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  font-size: 16px;
  color: #6c757d;
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
