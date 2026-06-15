<template>
  <AnalysisPanel
    title="Entities clustered using phenotype annotation"
    description="Interactive phenotype-cluster network with linked entity and variable tables."
  >
    <template #actions>
      <InlineHelpBadge id="popover-badge-help-clusters" aria-label="Explain phenotype clusters" />
      <BPopover target="popover-badge-help-clusters" variant="info" triggers="focus">
        <template #title> Cluster Analysis Details </template>
        This section provides an interactive visualization of entities grouped by phenotype
        annotations. The graphical part allows you to explore the clusters by clicking on the nodes,
        and the table displays detailed information about the variables within each cluster.
      </BPopover>
      <div class="btn-group btn-group-sm" role="group" aria-label="Export phenotype cluster network">
        <BButton
          variant="outline-secondary"
          size="sm"
          title="Export as PNG"
          aria-label="Export network as PNG image"
          @click="exportPNG"
        >
          <i class="bi bi-image" aria-hidden="true" />
        </BButton>
        <BButton
          variant="outline-secondary"
          size="sm"
          title="Export as SVG"
          aria-label="Export network as SVG image"
          @click="exportSVG"
        >
          <i class="bi bi-filetype-svg" aria-hidden="true" />
        </BButton>
      </div>
    </template>

    <BRow>
      <BCol md="4">
        <BCard
          header-tag="header"
          class="my-3 mx-2 text-start"
          body-class="p-0"
          header-class="p-1"
          footer-class="p-1"
          border-variant="light"
        >
          <template #header>
            <p class="mb-0 fw-semibold" style="font-size: 0.875rem;">
              Selected cluster {{ selectedCluster.cluster }}
              with
              <span class="sysndd-chip sysndd-chip--blue">
                {{ selectedCluster.cluster_size }}
              </span>
              entities
            </p>
          </template>

          <div id="cluster_dataviz" class="svg-container">
            <div v-if="isPreparing" class="error-state text-center p-4">
              <i class="bi bi-hourglass-split text-primary fs-1 mb-3 d-block" />
              <p class="text-muted mb-3">
                This analysis is being prepared and will appear here shortly. This can take a
                couple of minutes after a deploy or data update.
              </p>
              <BButton variant="primary" @click="retryLoad">
                <i class="bi bi-arrow-clockwise me-1" />
                Check again
              </BButton>
            </div>

            <div v-else-if="error" class="error-state text-center p-4">
              <i class="bi bi-exclamation-triangle-fill text-danger fs-1 mb-3 d-block" />
              <p class="text-muted mb-3">
                {{ error }}
              </p>
              <BButton variant="primary" @click="retryLoad">
                <i class="bi bi-arrow-clockwise me-1" />
                Retry
              </BButton>
            </div>

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
              <BLink :to="entitiesLink"> Entities for cluster {{ selectedCluster.cluster }} </BLink>
              <small class="text-muted">
                <i class="bi bi-circle-fill" style="font-size: 6px" /> = fewer entities |
                <i class="bi bi-circle-fill" style="font-size: 12px" /> = more entities
              </small>
            </div>
          </template>
        </BCard>
      </BCol>

      <BCol md="8">
        <LlmSummaryCard
          v-if="currentSummary && !summaryLoading"
          class="my-3 mx-2"
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
          :cluster-number="Number(selectedCluster?.cluster)"
        />
        <div v-else-if="summaryLoading" class="my-3 mx-2">
          <BSpinner small class="me-2" />
          <span class="text-muted">Loading AI summary...</span>
        </div>
        <BCard
          header-tag="header"
          class="my-3 mx-2 text-start"
          body-class="p-0"
          header-class="p-1"
          border-variant="light"
        >
          <template #header>
            <div class="mb-0 font-weight-bold">
              <BRow>
                <BCol sm="6" class="mb-1">
                  <BInputGroup size="sm">
                    <label for="phenotype-table-type-select" class="input-group-text">Table type</label>
                    <BFormSelect
                      id="phenotype-table-type-select"
                      v-model="tableType"
                      :options="tableOptions"
                      size="sm"
                      aria-label="Select table type"
                    />
                  </BInputGroup>
                </BCol>

                <BCol sm="6" class="mb-1 text-end">
                  <div class="d-flex align-items-center justify-content-end gap-2">
                    <TableSearchInput
                      v-model="filter.any.content"
                      :placeholder="'Search variables here...'"
                      :debounce-time="500"
                      @input="onFilterChange"
                    />
                    <BButton
                      v-b-tooltip.hover.bottom
                      size="sm"
                      variant="outline-secondary"
                      title="Download table data as Excel file"
                      aria-label="Download table data as Excel file"
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
          </template>

          <BCardText class="text-start" :aria-busy="loading ? 'true' : 'false'">
            <TableLoadingState
              v-if="loading"
              class="phenotype-table-loading"
              label="Loading phenotype cluster rows"
              :rows="6"
            />

            <GenericTable
              v-else
              :items="displayedItems"
              :fields="fields"
              :sort-by="sortBy"
              :sort-desc="sortDesc"
              @update-sort="handleSortUpdate"
            >
              <template #filter-controls>
                <td v-for="field in fields" :key="field.key" role="presentation">
                  <BFormInput
                    v-if="field.key !== 'details'"
                    v-model="filter[field.key].content"
                    :placeholder="'Filter ' + field.label"
                    :aria-label="'Filter by ' + field.label"
                    debounce="500"
                    @input="onFilterChange"
                  />
                </td>
              </template>

              <template #cell-variable="{ row }">
                <span class="sysndd-chip sysndd-chip--blue">
                  {{ row.variable }}
                </span>
              </template>

              <template #cell-p.value="{ row }">
                <span class="sysndd-chip sysndd-chip--info sysndd-chip--mono">
                  {{ row['p.value'] }}
                </span>
              </template>

              <template #cell-v.test="{ row }">
                <span class="sysndd-chip sysndd-chip--warning sysndd-chip--mono">
                  {{ row['v.test'] }}
                </span>
              </template>
            </GenericTable>

            <BRow v-if="!loading" class="justify-content-end">
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
  </AnalysisPanel>
</template>

<script>
import { ref, onBeforeUnmount } from 'vue';
import useToast from '@/composables/useToast';
import { usePhenotypeCytoscape, useExcelExport } from '@/composables';
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import {
  getPhenotypeClustering,
  getPhenotypeClusterSummary,
  isSnapshotPreparingError,
} from '@/api/analysis';
import { isApiError } from '@/api/client';
import {
  sortPhenotypeClusterRows,
  filterPhenotypeClusterRows,
  buildPhenotypeClusterExportFilename,
  phenotypeClusterExportSheetName,
  PHENOTYPE_CLUSTER_EXPORT_HEADERS,
} from './phenotypeClusterTable';

export default {
  name: 'AnalysesPhenotypeClusters',
  components: {
    AnalysisPanel,
    GenericTable,
    InlineHelpBadge,
    TableLoadingState,
    TableSearchInput,
    TablePaginationControls,
    LlmSummaryCard,
  },
  props: {
    filterState: {
      type: Object,
      default: null,
    },
  },
  setup(_props, { expose: _expose }) {
    const { makeToast } = useToast();
    const cytoscapeContainer = ref(null);
    const activeClusterRef = ref('1');

    const cytoscape = usePhenotypeCytoscape({
      container: cytoscapeContainer,
      onClusterClick: (clusterId) => {
        activeClusterRef.value = String(clusterId);
      },
    });

    const { isExporting, exportToExcel } = useExcelExport();

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
      itemsCluster: [],
      selectedCluster: {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      },
      loading: true,
      error: null,
      isPreparing: false,

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

      currentSummary: null,
      summaryLoading: false,
      summaryRequestId: 0,
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

      // 3. Apply sorting (numeric / scientific-notation aware)
      dataArray = sortPhenotypeClusterRows(dataArray, this.sortBy, this.sortDesc);

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
      const clusterData = this.itemsCluster.find(
        (item) => Number(item.cluster) === Number(newCluster)
      );
      if (clusterData?.hash_filter) {
        this.fetchClusterSummary(clusterData.hash_filter, newCluster);
      } else {
        this.clearClusterSummary();
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
      this.loading = true;
      this.error = null;
      this.isPreparing = false;
      try {
        const data = await getPhenotypeClustering();
        this.itemsCluster = data.clusters;
        this.setActiveCluster();
        // Fetch LLM summary for initial cluster
        const clusterData = this.itemsCluster.find(
          (item) => Number(item.cluster) === Number(this.activeCluster)
        );
        if (clusterData?.hash_filter) {
          this.fetchClusterSummary(clusterData.hash_filter, this.activeCluster);
        }
        this.$nextTick(() => {
          this.updateClusterGraph();
        });
      } catch (e) {
        // A snapshot "being prepared" 503 is a transient, expected state — show a
        // friendly panel instead of a hard error toast. (#420)
        if (isSnapshotPreparingError(e)) {
          this.isPreparing = true;
        } else {
          this.error = e.message || 'Failed to load phenotype cluster data. Please try again.';
          this.makeToast(e, 'Error', 'danger');
        }
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
      const match = this.itemsCluster.find(
        (item) => Number(item.cluster) === Number(this.activeCluster)
      );
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
        this.clearClusterSummary();
        return;
      }

      const requestId = ++this.summaryRequestId;
      this.summaryLoading = true;
      try {
        const data = await getPhenotypeClusterSummary({
          cluster_hash: clusterHash,
          cluster_number: String(clusterNumber),
        });
        if (requestId !== this.summaryRequestId) return;
        this.currentSummary = data;
      } catch (error) {
        if (requestId !== this.summaryRequestId) return;
        // 404/503 are expected for cache misses when generation is unavailable.
        if (isApiError(error) && error.response && [404, 503].includes(error.response.status)) {
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

    /* --------------------------------------
     * Searching + Filtering (client-side example)
     * ------------------------------------ */
    applyFilters(items) {
      // Delegates to the pure global "any" + per-column filter helper.
      return filterPhenotypeClusterRows(items, this.filter);
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

      // Generate filename with context
      const filename = buildPhenotypeClusterExportFilename(this.activeCluster, this.tableType);

      this.exportToExcel(dataArray, {
        filename,
        sheetName: phenotypeClusterExportSheetName(this.tableType),
        headers: PHENOTYPE_CLUSTER_EXPORT_HEADERS,
      });
    },
  },
};
</script>

<style scoped>
/* Block-level container with reserved height prevents CLS when Cytoscape mounts */
.svg-container {
  display: block;
  position: relative;
  width: 100%;
  overflow: hidden;
  /* Reserve space before graph mounts to prevent layout shift */
  min-height: 380px;
}

.cytoscape-container {
  width: 100%;
  height: 380px;
  background: #fafafa;
  border-radius: var(--radius-md, 6px);
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
