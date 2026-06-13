<!-- src/views/analyses/GeneNetworks.vue -->
<template>
  <AnalysisShell
    title="Functional gene clusters"
    subtitle="Explore functionally enriched SysNDD gene clusters and protein-protein interaction networks."
  >
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
