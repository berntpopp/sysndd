<template>
  <div class="gene-structure-plot">
    <!-- Horizontal scroll container for wide SVGs (large genes) -->
    <div ref="scrollContainer" class="gene-structure-scroll-container">
      <!-- D3 owns this element exclusively -->
      <div ref="plotContainer" class="gene-structure-plot-inner"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watchEffect, watch, onBeforeUnmount } from 'vue';
import { useD3GeneStructure } from '@/composables/useD3GeneStructure';
import type { GeneStructureRenderData } from '@/types/ensembl';

interface Props {
  data: GeneStructureRenderData;
}

const props = defineProps<Props>();

// Refs for D3 container elements
const plotContainer = ref<HTMLElement | null>(null);
const scrollContainer = ref<HTMLElement | null>(null);

// Initialize D3 composable
const {
  isInitialized: _isInitialized,
  renderGeneStructure,
  cleanup,
} = useD3GeneStructure({
  container: plotContainer,
  scrollContainer: scrollContainer,
});

// Watch for data changes and re-render
watchEffect(() => {
  if (plotContainer.value && props.data) {
    renderGeneStructure(props.data);
  }
});

// Also watch props.data with deep option for gene-to-gene navigation
watch(
  () => props.data,
  (newData) => {
    if (newData && plotContainer.value) {
      renderGeneStructure(newData);
    }
  },
  { deep: true }
);

// Cleanup on unmount (composable also does this, but explicit is good)
onBeforeUnmount(() => {
  cleanup();
});
</script>

<style scoped>
.gene-structure-plot {
  width: 100%;
}

.gene-structure-scroll-container {
  width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  border: 1px solid #dee2e6;
  border-radius: 4px;
  background: #f8f9fa;
}

.gene-structure-scroll-container::-webkit-scrollbar {
  height: 6px;
}

.gene-structure-scroll-container::-webkit-scrollbar-track {
  background: #f1f1f1;
}

.gene-structure-scroll-container::-webkit-scrollbar-thumb {
  background: #adb5bd;
  border-radius: 3px;
}

.gene-structure-scroll-container::-webkit-scrollbar-thumb:hover {
  background: #6c757d;
}

.gene-structure-plot-inner {
  min-width: 100%;
  position: relative;
}
</style>
