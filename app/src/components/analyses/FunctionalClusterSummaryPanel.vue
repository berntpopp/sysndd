<!-- src/components/analyses/FunctionalClusterSummaryPanel.vue -->
<!--
  Summary/AI-card/cue block for the functional gene-clusters analysis. Renders
  the LLM cluster summary state (validated card, judge-rejected notice,
  loading indicator, or the "select a cluster" show-all cue), purely from
  props threaded by the parent (AnalyseGeneClusters.vue), which keeps
  ownership of summary fetching and cluster selection. The only interaction
  this component originates is the cue's "View cluster N" button, surfaced as
  a `select-cluster` emit so the parent can drive the network-ref selection.
-->
<template>
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
</template>

<script>
// Import LLM Summary Card for AI-generated cluster summaries
import LlmSummaryCard from '@/components/llm/LlmSummaryCard.vue';

export default {
  name: 'FunctionalClusterSummaryPanel',
  components: {
    LlmSummaryCard,
  },
  props: {
    /** Current AI summary payload for the active single-cluster selection, or null. */
    currentSummary: {
      type: Object,
      default: null,
    },
    /** True while a summary request is in flight. */
    summaryLoading: {
      type: Boolean,
      default: false,
    },
    /** True when the current summary is the terminal judge-rejected state (#490). */
    summaryRejected: {
      type: Boolean,
      default: false,
    },
    /** Judge reason for the rejected summary, or null. */
    summaryRejectionReason: {
      type: String,
      default: null,
    },
    /** True when combined "all clusters" data is displayed (summary panels hidden). */
    showAllClustersInTable: {
      type: Boolean,
      default: false,
    },
    /** True when the "select a cluster" cue should render (show-all + clusters loaded). */
    showAllClustersSummaryCue: {
      type: Boolean,
      default: false,
    },
    /** First cluster id available for the cue's "View cluster N" default selection. */
    firstAvailableCluster: {
      type: Number,
      default: null,
    },
    /** Cluster number the validated summary card should display. */
    activeParentCluster: {
      type: [Number, String],
      default: null,
    },
  },
  emits: ['select-cluster'],
  methods: {
    /**
     * Cue button handler. The parent owns cluster selection (network-ref
     * dispatch); this component only reports the intent.
     */
    selectDefaultClusterForSummary() {
      if (this.firstAvailableCluster === null) return;
      this.$emit('select-cluster', this.firstAvailableCluster);
    },
  },
};
</script>

<style scoped>
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
</style>
