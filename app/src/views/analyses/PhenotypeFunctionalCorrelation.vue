<template>
  <AnalysisShell
    title="Phenotype & functional clusters correlation"
    subtitle="Compare phenotype-based clusters with functional gene clusters in a heatmap view."
    nav-label="Phenotype correlation views"
    :tabs="tabs"
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

    // Cross-link back to the related phenotype correlation views so users who
    // land on the correlation matrix can discover (and return to) the wider
    // phenotype-correlation analysis section. The self-link highlights via
    // AnalysisShell's `exact-active-class`.
    const tabs = [
      { label: 'Phenotype correlogram', to: { name: 'PhenotypeCorrelations' } },
      { label: 'Correlation matrix', to: { name: 'PhenotypeFunctionalCorrelation' } },
    ];

    return { makeToast, tabs };
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
