<!-- src/views/analyses/GeneNetworks.vue -->
<template>
  <AnalysisShell
    title="Functional gene clusters"
    subtitle="Explore functionally enriched SysNDD gene clusters and protein-protein interaction networks."
  >
    <template #meta>
      <span class="nddscore-meta-badge">
        <i class="bi bi-stars" aria-hidden="true"></i>
        <span>AI-assisted analysis</span>
      </span>
    </template>
    <AnalyseGeneClusters />
  </AnalysisShell>
</template>

<script>
import { useHead } from '@unhead/vue';
import AnalyseGeneClusters from '@/components/analyses/AnalyseGeneClusters.vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
import { preloadNetworkData } from '@/composables/useNetworkData';

export default {
  name: 'GeneNetworks',
  components: {
    AnalysisShell,
    AnalyseGeneClusters,
  },
  setup() {
    // Kick off network data preload in the background so it is ready
    // before NetworkVisualization mounts. Errors are silenced here;
    // the component handles its own error/retry state.
    void preloadNetworkData().catch(() => undefined);

    useHead({
      title: 'Functional clusters',
      meta: [
        {
          name: 'description',
          content:
            'The Gene Networks analysis shows the interactions between genes associated with neurodevelopmental disorders and curated in SysNDD.',
        },
      ],
    });
  },
};
</script>

<style scoped>
.nddscore-meta-badge {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.35rem;
  min-height: 1.55rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-full, 999px);
  background: var(--status-warning-bg, #fff3e0);
  color: #7a3400;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.nddscore-meta-badge .bi {
  color: #b84d00;
}
</style>
