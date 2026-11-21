<!-- views/analyses/PubtatorNDD.vue -->
<template>
  <AnalysisShell
    title="PubTator NDD"
    subtitle="Explore gene-literature connections from NCBI PubTator for neurodevelopmental disorder publications."
    nav-label="PubTator NDD views"
    :tabs="tabs"
  >
    <router-view />
  </AnalysisShell>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { listPubtatorGenes } from '@/api/publication';
import { normalizePubtatorGenesMeta } from '@/components/analyses/usePubtatorGenesTable';
import { formatCount } from '@/utils/displayFormat';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

// Reactive state for novel gene count
const novelGeneCount = ref<number>(0);

const tabs = computed(() => [
  { label: 'Table', to: { name: 'PubtatorNDDTable' } },
  {
    label: 'Genes',
    to: { name: 'PubtatorNDDGenes' },
    badge: novelGeneCount.value > 0 ? `${formatCount(novelGeneCount.value)} literature only` : null,
  },
  { label: 'Stats', to: { name: 'PubtatorNDDStats' } },
]);

// Total literature-only genes for the tab badge. The genes table only knows the
// rows of its current page, so its own count would read "6" next to 206 on Stats.
onMounted(async () => {
  try {
    const response = await listPubtatorGenes({
      filter: 'equals(is_novel,1)',
      fields: 'gene_symbol',
      page_size: '1',
    });
    novelGeneCount.value = Number(normalizePubtatorGenesMeta(response.meta)?.totalItems) || 0;
  } catch {
    novelGeneCount.value = 0; // the badge is optional; the tab still works
  }
});
</script>
