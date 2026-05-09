<template>
  <AnalysisShell
    title="Variant correlations"
    subtitle="Compare variant consequence patterns and counts across curated SysNDD entities."
    nav-label="Variant correlation views"
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
  name: 'VariantCorrelations',
  components: {
    AnalysisShell,
  },
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Variant correlations',
      meta: [
        {
          name: 'description',
          content:
            'The Variant analysis can be used to compare the correlations between genetic variants observed in neurodevelopmental disorders.',
        },
      ],
    });

    const tabs = [
      { label: 'Variant correlogram', to: '/VariantCorrelations' },
      { label: 'Variant counts', to: '/VariantCorrelations/VariantCounts' },
    ];

    return { makeToast, tabs };
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {
    // Placeholder if needed for future enhancements
  },
  methods: {},
};
</script>

<style scoped></style>
