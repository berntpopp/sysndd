<template>
  <BCard class="shadow-sm border-0 mb-3" body-class="p-2" header-class="py-2 px-3">
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h6 class="mb-0 fw-bold">
          <i class="bi bi-bar-chart-steps" /> Gene Structure
        </h6>
        <span v-if="renderData" class="text-muted small">
          {{ renderData.exonCount }} exon{{ renderData.exonCount !== 1 ? 's' : '' }}
          &bull;
          {{ formattedGeneLength }}
        </span>
      </div>
    </template>

    <!-- State 1: Loading -->
    <div v-if="loading" class="d-flex justify-content-center py-3">
      <BSpinner small label="Loading gene structure..." />
    </div>

    <!-- State 2: Error -->
    <div v-else-if="error" class="text-center py-3">
      <p class="text-muted mb-2 small">
        <i class="bi bi-exclamation-triangle" /> {{ error }}
      </p>
      <BButton variant="outline-primary" size="sm" @click="fetchEnsemblData">
        <i class="bi bi-arrow-clockwise" /> Retry
      </BButton>
    </div>

    <!-- State 3: Data available -->
    <div v-else-if="renderData">
      <GeneStructurePlot :data="renderData" />
    </div>

    <!-- State 4: No data (gene not found in Ensembl or no canonical transcript) -->
    <div v-else class="text-center py-3 text-muted small">
      <i class="bi bi-bar-chart-steps" /> No gene structure data available
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { BCard, BSpinner, BButton } from 'bootstrap-vue-next';
import axios from 'axios';
import GeneStructurePlot from './GeneStructurePlot.vue';
import {
  processEnsemblResponse,
  formatGenomicCoordinate,
} from '@/types/ensembl';
import type { EnsemblGeneStructure, GeneStructureRenderData } from '@/types/ensembl';

interface Props {
  geneSymbol: string;
}

const props = defineProps<Props>();

// Reactive state
const loading = ref(false);
const error = ref<string | null>(null);
const ensemblData = ref<EnsemblGeneStructure | null>(null);

/**
 * Computed: Process raw API response into render-ready data
 */
const renderData = computed<GeneStructureRenderData | null>(() => {
  if (!ensemblData.value) return null;
  return processEnsemblResponse(ensemblData.value);
});

/**
 * Computed: Formatted gene length for header display
 */
const formattedGeneLength = computed(() => {
  if (!renderData.value) return '';
  return formatGenomicCoordinate(renderData.value.geneLength);
});

/**
 * Fetch Ensembl gene structure data from backend proxy
 *
 * Handles multiple response scenarios:
 * - 200 with data: Success, store in ensemblData
 * - 200 with found: false: Gene not found (show empty state, not error)
 * - 404: Gene not found (show empty state)
 * - 503: Ensembl API unavailable (show error with retry)
 * - Other errors: Generic error message
 */
async function fetchEnsemblData() {
  if (!props.geneSymbol) return;

  loading.value = true;
  error.value = null;
  ensemblData.value = null;

  try {
    const apiBase = import.meta.env.VITE_API_URL;
    const response = await axios.get(
      `${apiBase}/api/external/ensembl/structure/${props.geneSymbol}`
    );

    // Check for API-level not-found or error
    if (response.data?.found === false) {
      // Gene not found in Ensembl -- show empty state (not error)
      ensemblData.value = null;
    } else if (response.data?.error) {
      error.value = response.data.message || 'Failed to load gene structure';
    } else {
      ensemblData.value = response.data as EnsemblGeneStructure;
    }
  } catch (e: unknown) {
    if (axios.isAxiosError(e) && e.response?.status === 404) {
      // 404 = gene not found, show empty state
      ensemblData.value = null;
    } else if (axios.isAxiosError(e) && e.response?.status === 503) {
      error.value = 'Ensembl API temporarily unavailable';
    } else {
      error.value = 'Failed to load gene structure data';
    }
  }

  loading.value = false;
}

// Lifecycle: Fetch on mount
onMounted(() => {
  fetchEnsemblData();
});

// Watch: Re-fetch when gene symbol changes (gene-to-gene navigation)
watch(
  () => props.geneSymbol,
  (newSymbol) => {
    if (newSymbol) {
      fetchEnsemblData();
    }
  }
);
</script>

<style scoped>
/* Card inherits shadow-sm border-0 from BCard class */
</style>
