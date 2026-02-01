<!-- src/components/analyses/AnalysesPhenotypeClusters.vue -->
<template>
  <BContainer fluid>
    <!-- The main card -->
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Entities
            <mark
              v-b-tooltip.hover.leftbottom
              title="Entities clustered based on their phenotype annotations to identify groups with similar characteristics. Interactive visualization allows exploration of cluster details."
            >
              clustered using phenotype
            </mark>
            annotation.
            <BBadge id="popover-badge-help-clusters" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-clusters" variant="info" triggers="focus">
              <template #title> Cluster Analysis Details </template>
              This section provides an interactive visualization of entities grouped by phenotype
              annotations. The graphical part allows you to explore the clusters by clicking on the
              nodes, and the table displays detailed information about the variables within each
              cluster.
            </BPopover>
          </h6>
          <!-- Add export buttons for Cytoscape network -->
          <div class="btn-group btn-group-sm">
            <BButton variant="outline-secondary" size="sm" title="Export as PNG" @click="exportPNG">
              <i class="bi bi-image" />
            </BButton>
            <BButton variant="outline-secondary" size="sm" title="Export as SVG" @click="exportSVG">
              <i class="bi bi-filetype-svg" />
            </BButton>
          </div>
        </div>
      </template>

      <!-- Put both graph and table in ONE row -->
      <BRow>
        <!-- LEFT COLUMN (Graph) -->
        <BCol md="4">
          <BCard
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            footer-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-0 font-weight-bold">
                Selected cluster {{ selectedCluster.cluster }}
                with
                <BBadge variant="primary">
                  {{ selectedCluster.cluster_size }}
                </BBadge>
                entities
              </h6>
            </template>

            <div id="cluster_dataviz" class="svg-container">
              <!-- Error state with retry -->
              <div v-if="error" class="error-state text-center p-4">
                <i class="bi bi-exclamation-triangle-fill text-danger fs-1 mb-3 d-block" />
                <p class="text-muted mb-3">
                  {{ error }}
                </p>
                <BButton variant="primary" @click="retryLoad">
                  <i class="bi bi-arrow-clockwise me-1" />
                  Retry
                </BButton>
              </div>

              <!-- Loading spinner -->
              <BSpinner v-else-if="loading" label="Loading..." class="spinner" />

              <div
                v-else
                ref="cytoscapeContainer"
                class="cytoscape-container"
                :style="{ height: '380px', width: '100%' }"
              />
            </div>

            <template #footer>
              <div class="d-flex justify-content-between align-items-center">
                <BLink :href="entitiesLink">
                  Entities for cluster {{ selectedCluster.cluster }}
                </BLink>
                <small class="text-muted">
                  <i class="bi bi-circle-fill" style="font-size: 6px" /> = fewer entities |
                  <i class="bi bi-circle-fill" style="font-size: 12px" /> = more entities
                </small>
              </div>
            </template>
          </BCard>
        </BCol>

        <!-- RIGHT COLUMN (Table) -->
        <BCol md="8">
          <!-- LLM Summary Card (above table) -->
          <LlmSummaryCard
            v-if="currentSummary && !summaryLoading"
            class="my-3 mx-2"
            :summary="currentSummary.summary_json"
            :model-name="Array.isArray(currentSummary.model_name) ? currentSummary.model_name[0] : currentSummary.model_name"
            :created-at="Array.isArray(currentSummary.created_at) ? currentSummary.created_at[0] : currentSummary.created_at"
            :validation-status="Array.isArray(currentSummary.validation_status) ? currentSummary.validation_status[0] : currentSummary.validation_status"
            :cluster-number="Number(selectedCluster?.cluster)"
          />
          <div v-else-if="summaryLoading" class="my-3 mx-2">
            <BSpinner small class="me-2" />
            <span class="text-muted">Loading AI summary...</span>
          </div>
          <!-- No placeholder when summary doesn't exist -->

          <BCard
            header-tag="header"
            class="my-3 mx-2 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- TABLE HEADER CONTROLS (table type selector, search bar, pagination) -->
            <template #header>
              <div class="mb-0 font-weight-bold">
                <BRow>
                  <BCol sm="6" class="mb-1">
                    <BInputGroup prepend="Table type" size="sm">
                      <BFormSelect v-model="tableType" :options="tableOptions" size="sm" />
                    </BInputGroup>
                  </BCol>

                  <BCol sm="6" class="mb-1 text-end">
                    <div class="d-flex align-items-center justify-content-end gap-2">
                      <!-- A search input controlling the 'any' filter -->
                      <TableSearchInput
                        v-model="filter.any.content"
                        :placeholder="'Search variables here...'"
                        :debounce-time="500"
                        @input="onFilterChange"
                      />
                      <!-- Excel download button -->
                      <BButton
                        v-b-tooltip.hover.bottom
                        size="sm"
                        variant="outline-secondary"
                        title="Download table data as Excel file"
                        :disabled="isExporting"
                        @click="downloadExcel"
                      >
                        <i class="bi bi-table me-1" />
                        <i v-if="!isExporting" class="bi bi-download" />
                        <BSpinner v-else small />
                        .xlsx
                      </BButton>
                    </div>
                  </BCol>
                </BRow>
              </div>
            </template>

            <!-- MAIN TABLE -->
            <BCardText class="text-start">
              <GenericTable
                :items="displayedItems"
                :fields="fields"
                :sort-by="sortBy"
                :sort-desc="sortDesc"
                @update-sort="handleSortUpdate"
              >
                <!-- Column-level filter slot (optional) -->
                <template #filter-controls>
                  <td v-for="field in fields" :key="field.key">
                    <BFormInput
                      v-if="field.key !== 'details'"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label"
                      debounce="500"
                      @input="onFilterChange"
                    />
                  </td>
                </template>

                <!-- Optionally define custom column slots -->
                <template #cell-variable="{ row }">
                  <BBadge variant="primary">
                    {{ row.variable }}
                  </BBadge>
                </template>

                <template #cell-p.value="{ row }">
                  <BBadge variant="info">
                    {{ row['p.value'] }}
                  </BBadge>
                </template>

                <template #cell-v.test="{ row }">
                  <BBadge variant="warning">
                    {{ row['v.test'] }}
                  </BBadge>
                </template>
              </GenericTable>

              <!-- Bottom pagination controls (optional) -->
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
            </BCardText>
          </BCard>
        </BCol>
      </BRow>
    </BCard>
  </BContainer>
</template>

<script>
import { ref, onBeforeUnmount } from 'vue';
import useToast from '@/composables/useToast';
import { usePhenotypeCytoscape, useExcelExport } from '@/composables';

// Import your small table components:
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

// Import LLM Summary Card for AI-generated cluster summaries
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';

export default {
  name: 'AnalysesPhenotypeClusters',
  components: {
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
    LlmSummaryCard,
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
  setup(_props, { expose: _expose }) {
    const { makeToast } = useToast();
    const cytoscapeContainer = ref(null);
    const activeClusterRef = ref('1');

    // Initialize composable in setup() to properly register lifecycle hooks
    const cytoscape = usePhenotypeCytoscape({
      container: cytoscapeContainer,
      onClusterClick: (clusterId) => {
        activeClusterRef.value = String(clusterId);
      },
    });

    // Excel export functionality
    const { isExporting, exportToExcel } = useExcelExport();

    // Cleanup on unmount
    onBeforeUnmount(() => {
      cytoscape.destroy();
    });

    return {
      makeToast,
      cytoscapeContainer,
      cytoscape,
      activeClusterRef,
      isExporting,
      exportToExcel,
    };
  },
  data() {
    return {
      /* --------------------------------------
       * Clustering + Graph data
       * ------------------------------------ */
      itemsCluster: [],
      selectedCluster: {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      },
      // activeCluster moved to setup() as activeClusterRef
      loading: false,
      error: null, // Error state for retry functionality
      // cyInstance moved to setup() as 'cytoscape'

      /* --------------------------------------
       * Table logic / fields
       * ------------------------------------ */
      fields: [
        {
          key: 'variable',
          label: 'Variable',
          class: 'text-start',
          sortable: true,
        },
        {
          key: 'p.value',
          label: 'p-value',
          class: 'text-start',
          sortable: true,
        },
        {
          key: 'v.test',
          label: 'v-test',
          class: 'text-start',
          sortable: true,
        },
      ],
      tableOptions: [
        {
          value: 'quali_inp_var',
          text: 'Qualitative input variables (phenotypes)',
        },
        {
          value: 'quali_sup_var',
          text: 'Qualitative supplementary variables (inheritance)',
        },
        {
          value: 'quanti_sup_var',
          text: 'Quantitative supplementary variables (phenotype counts)',
        },
      ],
      tableType: 'quali_inp_var',

      /* --------------------------------------
       * Pagination / Sorting / Filtering
       * ------------------------------------ */
      perPage: 10,
      totalRows: 1,
      currentPage: 1,
      sortBy: 'p.value',
      sortDesc: false,
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        variable: { content: null, join_char: null, operator: 'contains' },
        'p.value': { content: null, join_char: null, operator: 'contains' },
        'v.test': { content: null, join_char: null, operator: 'contains' },
      },

      // LLM Summary data
      currentSummary: null,
      summaryLoading: false,
    };
  },
  computed: {
    /**
     * Bridge between setup() ref and Options API
     */
    activeCluster: {
      get() {
        return this.activeClusterRef;
      },
      set(value) {
        this.activeClusterRef = value;
      },
    },
    /**
     * Computed URL for the Entities link (fixes NAVL-07 bug)
     * Prevents 'filter=undefined' when hash_filter is not set
     * @returns {string} URL to the Entities page with or without filter
     */
    entitiesLink() {
      const base = '/Entities/';
      if (this.selectedCluster?.hash_filter) {
        return `${base}?filter=${this.selectedCluster.hash_filter}`;
      }
      return base;
    },
    /**
     * The items currently being displayed in the table (filtered + sorted + paginated).
     */
    displayedItems() {
      // 1. Start from the relevant cluster data
      let dataArray = this.selectedCluster[this.tableType] || [];

      // 2. Apply filtering
      dataArray = this.applyFilters(dataArray);

      // 3. Apply sorting
      if (this.sortBy) {
        dataArray = [...dataArray].sort((a, b) => {
          let aVal = a[this.sortBy];
          let bVal = b[this.sortBy];

          // Handle null/undefined - push to end
          if (aVal == null && bVal == null) return 0;
          if (aVal == null) return 1;
          if (bVal == null) return -1;

          // Handle numeric comparison (including scientific notation)
          const aNum = typeof aVal === 'number' ? aVal : parseFloat(aVal);
          const bNum = typeof bVal === 'number' ? bVal : parseFloat(bVal);

          if (!isNaN(aNum) && !isNaN(bNum)) {
            const diff = aNum - bNum;
            return this.sortDesc ? -diff : diff;
          }

          // String comparison for non-numeric values
          const aStr = String(aVal).toLowerCase();
          const bStr = String(bVal).toLowerCase();
          if (aStr < bStr) return this.sortDesc ? 1 : -1;
          if (aStr > bStr) return this.sortDesc ? -1 : 1;
          return 0;
        });
      }

      // 4. Paginate (client-side)
      const start = (this.currentPage - 1) * this.perPage;
      const end = start + this.perPage;
      return dataArray.slice(start, end);
    },
  },
  watch: {
    // Update data whenever the user picks a new cluster
    activeCluster(newCluster) {
      this.setActiveCluster();
      // Highlight selected cluster in Cytoscape using the composable method
      if (this.cytoscape?.isInitialized.value) {
        this.cytoscape.selectCluster(newCluster);
      }
      // Fetch LLM summary for the selected cluster
      const clusterData = this.itemsCluster.find((item) => item.cluster === newCluster);
      if (clusterData?.hash_filter) {
        this.fetchClusterSummary(clusterData.hash_filter, newCluster);
      } else {
        this.currentSummary = null;
      }
    },
    // Watch the tableType so we can update totalRows based on new array
    tableType() {
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
      this.currentPage = 1; // Reset to first page
    },
  },
  mounted() {
    this.loadClusterData();
  },
  methods: {
    /* --------------------------------------
     * Load cluster data from API
     * ------------------------------------ */
    async loadClusterData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/analysis/phenotype_clustering`;
      this.loading = true;
      this.error = null;
      try {
        const response = await this.axios.get(apiUrl);
        this.itemsCluster = response.data;
        this.setActiveCluster();
        // Fetch LLM summary for initial cluster
        const clusterData = this.itemsCluster.find((item) => item.cluster === this.activeCluster);
        if (clusterData?.hash_filter) {
          this.fetchClusterSummary(clusterData.hash_filter, this.activeCluster);
        }
        this.$nextTick(() => {
          this.updateClusterGraph();
        });
      } catch (e) {
        this.error = e.message || 'Failed to load phenotype cluster data. Please try again.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
    },
    /**
     * Retry loading data after an error
     */
    retryLoad() {
      this.loadClusterData();
    },
    setActiveCluster() {
      // Filter out the cluster matching activeCluster
      const match = this.itemsCluster.find((item) => item.cluster === this.activeCluster);
      this.selectedCluster = match || {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      };
      // Update total rows
      const arr = this.selectedCluster[this.tableType] || [];
      this.totalRows = arr.length;
    },

    /**
     * Fetch LLM-generated summary for a specific phenotype cluster
     * Uses cluster's hash_filter as the cluster_hash parameter
     */
    async fetchClusterSummary(clusterHash, clusterNumber) {
      if (!clusterHash) {
        this.currentSummary = null;
        return;
      }

      this.summaryLoading = true;
      try {
        const response = await this.axios.get(
          `${import.meta.env.VITE_API_URL}/api/analysis/phenotype_cluster_summary`,
          {
            params: {
              cluster_hash: clusterHash,
              cluster_number: clusterNumber,
            },
          }
        );
        this.currentSummary = response.data;
      } catch (error) {
        if (error.response?.status === 404) {
          // No summary yet - silently handle (this is expected)
          this.currentSummary = null;
        } else {
          console.warn('Failed to fetch cluster summary:', error);
          this.currentSummary = null;
        }
      } finally {
        this.summaryLoading = false;
      }
    },

    /* --------------------------------------
     * Searching + Filtering (client-side example)
     * ------------------------------------ */
    applyFilters(items) {
      const anyFilterValue = (this.filter.any.content || '').toLowerCase();

      // Return items that match the global "any" filter AND column-specific filters
      return items.filter((row) => {
        // 1. Global "any" filter
        if (anyFilterValue) {
          const rowString = Object.values(row).join(' ').toLowerCase();
          if (!rowString.includes(anyFilterValue)) {
            return false;
          }
        }
        // 2. Column-specific filters
        const filterKeys = Object.keys(this.filter).filter((f) => f !== 'any');
        let keepRow = true;
        filterKeys.forEach((fieldKey) => {
          const colFilterVal = (this.filter[fieldKey].content || '').toLowerCase();
          if (colFilterVal) {
            const rowVal = String(row[fieldKey] || '').toLowerCase();
            if (!rowVal.includes(colFilterVal)) {
              keepRow = false;
            }
          }
        });
        return keepRow;
      });
    },
    onFilterChange() {
      // Reset page to 1 to see the updated first page
      this.currentPage = 1;
    },

    /* --------------------------------------
     * Pagination controls
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
    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
    },

    /* --------------------------------------
     * Graph code for cluster viz (Cytoscape)
     * ------------------------------------ */
    initializeCytoscape() {
      if (!this.cytoscapeContainer) return;
      // Cytoscape composable initialized in setup(), just init the graph
      this.cytoscape.initializeCytoscape();
    },

    updateClusterGraph() {
      if (!this.cytoscape.isInitialized.value) {
        this.initializeCytoscape();
      }
      if (this.cytoscape && this.itemsCluster.length > 0) {
        this.cytoscape.updateElements(this.itemsCluster);
        // Select the initial cluster after a short delay for layout to complete
        setTimeout(() => {
          this.cytoscape.selectCluster(this.activeCluster);
        }, 600);
      }
    },

    handleClusterClick(clusterId) {
      this.activeCluster = clusterId;
    },

    /* --------------------------------------
     * Export functions for Cytoscape network
     * ------------------------------------ */
    exportPNG() {
      if (!this.cytoscape?.isInitialized.value) return;
      const png = this.cytoscape.exportPNG();
      const link = document.createElement('a');
      link.href = png;
      link.download = 'phenotype_clusters.png';
      link.click();
    },

    exportSVG() {
      if (!this.cytoscape?.isInitialized.value) return;
      const svgContent = this.cytoscape.exportSVG();
      const blob = new Blob([svgContent], { type: 'image/svg+xml' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'phenotype_clusters.svg';
      link.click();
      URL.revokeObjectURL(url);
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
      const tableTypeLabels = {
        quali_inp_var: 'Qualitative Input Variables',
        quali_sup_var: 'Qualitative Supplementary Variables',
        quanti_sup_var: 'Quantitative Supplementary Variables',
      };

      const headers = {
        variable: 'Variable',
        'p.value': 'p-value',
        'v.test': 'v-test',
        // Additional columns that might be present
        Mean_in_category: 'Mean in Category',
        Overall_mean: 'Overall Mean',
        sd_in_category: 'SD in Category',
        Overall_sd: 'Overall SD',
      };

      // Generate filename with context
      const filename = `sysndd_phenotype_cluster_${this.activeCluster}_${this.tableType}`;

      this.exportToExcel(dataArray, {
        filename,
        sheetName: tableTypeLabels[this.tableType] || 'Data',
        headers,
      });
    },
  },
};
</script>

<style scoped>
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 800px;
  vertical-align: top;
  overflow: hidden;
}

.cytoscape-container {
  width: 100%;
  height: 380px;
  background: #fafafa;
  border-radius: 4px;
}

.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}

.error-state {
  min-height: 200px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
