<!-- views/analyses/PubtatorNDD.vue -->
<template>
  <AnalysisShell
    title="PubTator NDD"
    subtitle="Explore gene-literature connections from NCBI PubTator for neurodevelopmental disorder publications."
    nav-label="PubTator NDD views"
    :tabs="tabs"
  >
    <router-view @novel-count="handleNovelCount" />
  </AnalysisShell>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

// Reactive state for novel gene count
const novelGeneCount = ref<number>(0);

const tabs = computed(() => [
  { label: 'Table', to: { name: 'PubtatorNDDTable' } },
  {
    label: 'Genes',
    to: { name: 'PubtatorNDDGenes' },
    badge: novelGeneCount.value > 0 ? `${novelGeneCount.value} literature only` : null,
  },
  { label: 'Stats', to: { name: 'PubtatorNDDStats' } },
]);

/**
 * Handle novel-count event from child component (PubtatorNDDGenes)
 * @param count - Number of novel genes (not in SysNDD)
 */
const handleNovelCount = (count: number) => {
  novelGeneCount.value = count;
};
</script>
