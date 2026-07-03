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
            v-if="currentSummary && !summaryLoading && !summaryRejected && !showAllClustersInTable"
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
          <BCard
            v-else-if="summaryRejected && !summaryLoading && !showAllClustersInTable"
            class="my-3 mx-2"
            border-variant="warning"
            data-testid="ai-summary-unavailable"
          >
            <div class="d-flex align-items-start">
              <i class="bi bi-shield-exclamation text-warning fs-4 me-2" aria-hidden="true" />
              <div>
                <p class="fw-semibold mb-1">AI summary could not be validated for this cluster</p>
                <p class="text-muted small mb-0">
                  The automated reviewer could not validate an AI-generated summary for this
                  cluster, so none is shown.
                  <span v-if="summaryRejectionReason"> Reason: {{ summaryRejectionReason }}</span>
                </p>
              </div>
            </div>
          </BCard>
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

          <FunctionalClusterTablePanel
            v-model:gene-search-pattern="geneSearchPattern"
            v-model:search-match-count="searchMatchCount"
            :selected-cluster="selectedCluster"
            :value-categories="valueCategories"
            :loading="loading"
            :is-preparing="isPreparing"
            :show-all-clusters-in-table="showAllClustersInTable"
            :displayed-clusters="displayedClusters"
            :all-gene-symbols="allGeneSymbols"
            :hovered-row-id="hoveredRowId"
            @row-hover="handleTableRowHover"
            @retry="retryLoad"
          />
        </div>
      </Pane>
    </Splitpanes>
    <ClusterValidationCard
      analysis-type="functional_clusters"
      :snapshot-meta="snapshotMeta"
      :clusters="clusterRows"
    />
  </AnalysisPanel>
</template>

<script>
import { useToast, useColorAndSymbols, useFilterSync } from '@/composables';
import { useClusterSummary } from '@/composables/useClusterSummary';

// Import small components
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';

// Import filter components
import TermSearch from '@/components/filters/TermSearch.vue';

// Import NetworkVisualization component (replaces D3.js bubble chart)
import NetworkVisualization from '@/components/analyses/NetworkVisualization.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import ClusterValidationCard from '@/components/analyses/ClusterValidationCard.vue';
import FunctionalClusterTablePanel from '@/components/analyses/FunctionalClusterTablePanel.vue';

// Import LLM Summary Card for AI-generated cluster summaries
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';

// Import Splitpanes for resizable layout
import { Splitpanes, Pane } from 'splitpanes';
import 'splitpanes/dist/splitpanes.css';

// Typed API clients (W5)
import {
  getFunctionalClustering,
  getFunctionalClusterSummary,
  isSnapshotPreparingError,
} from '@/api/analysis';
import { combineClusterData, clusterRowsWithNumber } from './geneClusterTableData';

export default {
  name: 'AnalyseGeneClusters',
  components: {
    AnalysisPanel,
    ClusterValidationCard,
    FunctionalClusterTablePanel,
    InlineHelpBadge,
    TermSearch,
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

    // LLM cluster-summary state and fetch logic (request-id race guarded).
    // Inject the functional summary fetcher; the default no-summary status set
    // (404) preserves the previous behavior.
    const clusterSummary = useClusterSummary(makeToast, getFunctionalClusterSummary);

    return {
      makeToast,
      ...colorAndSymbols,
      filterSyncState,
      setSearch,
      ...clusterSummary,
    };
  },
  data() {
    return {
      /* --------------------------------------
       * Data from the API
       * ------------------------------------ */
      itemsCluster: [],
      snapshotMeta: null,
      clusterRows: [],
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
       * Clustering logic
       * ------------------------------------ */
      selectOptions: [
        { value: 'clusters', text: 'Clusters' },
      ],
      selectType: 'clusters',
      activeParentCluster: 1,
      activeSubCluster: 1,

      loading: true,
      // Snapshot still building (503 snapshot_missing) — render a friendly
      // "being prepared" panel rather than a raw error toast (#440).
      isPreparing: false,
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
  },
  watch: {
    activeParentCluster() {
      if (this.selectType === 'clusters') {
        this.setActiveCluster();
      }
    },
    selectType() {
      this.resetCluster();
    },
  },
  mounted() {
    this.startClusterTableLoad();
  },
  methods: {
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
      this.isPreparing = false;

      try {
        const data = await getFunctionalClustering({
          page_size: '50',
        });
        this.itemsCluster = data.clusters;
        this.clusterRows = data.clusters || [];
        this.snapshotMeta = data.meta?.snapshot || null;
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
        // A snapshot "being prepared" 503 is a transient, expected state — show a
        // friendly panel instead of a hard error toast (#440), mirroring the
        // network graph (useNetworkData) and phenotype clusters views.
        if (isSnapshotPreparingError(e)) {
          this.isPreparing = true;
        } else {
          this.makeToast(e, 'Error', 'danger');
        }
      } finally {
        this.loading = false;
      }
    },

    /**
     * Retry loading the functional clustering snapshot after a "being prepared"
     * 503. Re-arms the one-shot load guard so the user's "Check again" works.
     */
    retryLoad() {
      this.isPreparing = false;
      this.loading = true;
      this.clusterTableLoadStarted = true;
      this.loadClusterData();
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
        return;
      }

      const match = this.itemsCluster.find(
        (item) => Number(item.cluster) === Number(this.activeParentCluster)
      );
      const clusterNum = this.activeParentCluster;

      // Add cluster_num to each row for consistent display
      this.selectedCluster = clusterRowsWithNumber(match, clusterNum);
    },

    resetCluster() {
      this.activeParentCluster = 1;
      this.activeSubCluster = 1;
      this.setActiveCluster();
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
        const clusterData = this.itemsCluster.find(
          (item) => Number(item.cluster) === Number(clusters[0])
        );
        if (clusterData?.hash_filter) {
          this.fetchClusterSummary(clusterData.hash_filter, clusters[0]);
        } else {
          this.clearClusterSummary();
        }
      } else {
        // Multiple clusters selected - combine their data
        const clusterNums = clusters.map(Number);
        const selectedClusterData = this.itemsCluster.filter((item) =>
          clusterNums.includes(Number(item.cluster))
        );
        this.selectedCluster = this.combineClusterData(selectedClusterData);
        // Clear summary when showing multiple clusters
        this.clearClusterSummary();
      }
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
  },
};
</script>

<style scoped>
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

.cluster-summary-cue__action {
  flex: 0 0 auto;
  /* Ensure the outline button text clears AA on the cue background. */
  color: var(--medical-blue-700, #0d47a1);
  border-color: var(--medical-blue-700, #0d47a1);
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
</style>
