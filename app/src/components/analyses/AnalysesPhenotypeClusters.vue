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
      <div
        class="btn-group btn-group-sm"
        role="group"
        aria-label="Export phenotype cluster network"
      >
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
            <p class="mb-0 fw-semibold" style="font-size: 0.875rem">
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
                This analysis is being prepared and will appear here shortly. This can take a couple
                of minutes after a deploy or data update.
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
        <PhenotypeClusterVariableTable
          :selected-cluster="selectedCluster"
          :loading="loading"
          :active-cluster="activeCluster"
        />
      </BCol>
    </BRow>
    <ClusterValidationCard
      analysis-type="phenotype_clusters"
      :snapshot-meta="snapshotMeta"
      :clusters="clusterRows"
    />
  </AnalysisPanel>
</template>

<script>
import { ref, onBeforeUnmount } from 'vue';
import useToast from '@/composables/useToast';
import { usePhenotypeCytoscape } from '@/composables';
import { useClusterSummary } from '@/composables/useClusterSummary';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import ClusterValidationCard from '@/components/analyses/ClusterValidationCard.vue';
import PhenotypeClusterVariableTable from '@/components/analyses/PhenotypeClusterVariableTable.vue';
import {
  getPhenotypeClustering,
  getPhenotypeClusterSummary,
  isSnapshotPreparingError,
} from '@/api/analysis';
import { normalizePhenotypeClusterRows } from './phenotypeClusterTable';

export default {
  name: 'AnalysesPhenotypeClusters',
  components: {
    AnalysisPanel,
    ClusterValidationCard,
    InlineHelpBadge,
    LlmSummaryCard,
    PhenotypeClusterVariableTable,
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

    // LLM cluster-summary state and fetch logic (request-id race guarded).
    // The phenotype endpoint silences both 404 and a transient 503.
    const { currentSummary, summaryLoading, fetchClusterSummary, clearClusterSummary } =
      useClusterSummary(makeToast, getPhenotypeClusterSummary, { noSummaryStatuses: [404, 503] });

    onBeforeUnmount(() => {
      cytoscape.destroy();
    });

    return {
      makeToast,
      cytoscapeContainer,
      cytoscape,
      activeClusterRef,
      currentSummary,
      summaryLoading,
      fetchClusterSummary,
      clearClusterSummary,
    };
  },
  data() {
    return {
      itemsCluster: [],
      snapshotMeta: null,
      clusterRows: [],
      selectedCluster: {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      },
      loading: true,
      error: null,
      isPreparing: false,
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
        this.clusterRows = data.clusters || [];
        this.snapshotMeta = data.meta?.snapshot || null;
        // De-dot the MCA stat keys (p.value -> p_value, v.test -> v_test) so the
        // table columns render; BTable cannot resolve a dotted field key.
        this.itemsCluster = (data.clusters || []).map((cluster) => ({
          ...cluster,
          quali_inp_var: normalizePhenotypeClusterRows(cluster.quali_inp_var),
          quali_sup_var: normalizePhenotypeClusterRows(cluster.quali_sup_var),
          quanti_sup_var: normalizePhenotypeClusterRows(cluster.quanti_sup_var),
        }));
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
</style>
