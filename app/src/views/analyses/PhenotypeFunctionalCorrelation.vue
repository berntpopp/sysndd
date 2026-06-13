<template>
  <AnalysisShell
    title="Phenotype & functional clusters correlation"
    subtitle="Heatmap of the correlation between phenotype-based clusters and functional gene clusters."
  >
    <AnalysesPhenotypeFunctionalCorrelation />
  </AnalysisShell>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
// IMPORTANT: Import your child
import AnalysesPhenotypeFunctionalCorrelation from '@/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

export default {
  name: 'PhenotypeFunctionalCorrelation',
  components: {
    AnalysisShell,
    AnalysesPhenotypeFunctionalCorrelation,
  },
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Pheno-Func Correlation',
      meta: [
        {
          name: 'description',
          content:
            'Shows the correlation between phenotype-based clusters and functional clusters, plus optional SFARI genes, in a heatmap format.',
        },
      ],
    });

    // Standalone analysis (functional vs phenotype clusters); no cross-link tabs —
    // it is its own Analyses menu entry, so tab navigation here was misleading.
    return { makeToast };
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {
    // no special logic needed here
  },
};
</script>

<style scoped></style>
