<!-- views/analyses/PublicationsNDD.vue -->
<template>
  <AnalysisShell
    title="NDD publications"
    subtitle="Browse SysNDD-curated publications, publication timelines, and publication-level statistics."
    nav-label="NDD publication views"
    :tabs="tabs"
  >
    <router-view />
  </AnalysisShell>
</template>

<script>
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

export default {
  name: 'PublicationsNDDParent',
  components: {
    AnalysisShell,
  },
  // This parent purely handles tab navigation & route display.
  data() {
    return {
      tabs: [
        { label: 'SysNDD Curated', to: { name: 'PublicationsNDDTable' } },
        { label: 'Time Plot', to: { name: 'PublicationsNDDTimePlot' } },
        { label: 'Stats', to: { name: 'PublicationsNDDStats' } },
      ],
    };
  },
};
</script>

<style scoped>
/* Optional styling for your background gradient, etc. */
</style>
