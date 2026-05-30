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
import useToast from '@/composables/useToast';
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
    const { makeToast } = useToast();
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

    return { makeToast };
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
</style>
