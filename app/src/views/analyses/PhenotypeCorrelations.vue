<!-- src/views/analyses/PhenotypeCorrelations.vue -->
<template>
  <AnalysisShell
    title="Phenotype correlations"
    subtitle="Compare phenotype co-occurrence, frequency, and cluster structure across curated SysNDD entities."
    nav-label="Phenotype correlation views"
    :tabs="tabs"
  >
    <router-view />
  </AnalysisShell>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

export default {
  name: 'PhenotypeCorrelations',
  components: {
    AnalysisShell,
  },
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Phenotype correlations',
      meta: [
        {
          name: 'description',
          content:
            'The Phenotype analysis can be used to compare the correlations between phenotypes and with their associated inheritance patterns in neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability).',
        },
      ],
    });

    const tabs = [
      { label: 'Phenotype correlogram', to: '/PhenotypeCorrelations' },
      { label: 'Phenotype counts', to: '/PhenotypeCorrelations/PhenotypeCounts' },
      { label: 'Phenotype clustering', to: '/PhenotypeCorrelations/PhenotypeClusters' },
      { label: 'Correlation matrix', to: { name: 'PhenotypeFunctionalCorrelation' } },
    ];

    return { makeToast, tabs };
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {},
  methods: {},
};
</script>

<style scoped></style>
