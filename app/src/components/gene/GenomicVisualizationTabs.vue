<!-- src/components/gene/GenomicVisualizationTabs.vue -->
<!--
  Tabbed container for genomic visualizations:
  - Protein View (lollipop plot at amino acid positions)
  - Gene Structure (exon/intron diagram with variants at genomic positions)
  - 3D Structure (placeholder for Phase 45)

  Ensures consistent design across all three visualization types:
  - Same heights, fonts, spacing
  - Same ACMG color scheme for variants
  - Responsive viewBox-based SVG sizing
  - Proper containment without overflow
-->
<template>
  <BCard class="shadow-sm border-0 mb-3" body-class="p-0" header-class="py-2 px-3">
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h2 class="genomic-visualization-title mb-0 fw-bold">
          <i class="bi bi-graph-up" aria-hidden="true" /> Genomic Visualizations
        </h2>
        <span v-if="summaryText" class="text-muted small">
          {{ summaryText }}
        </span>
      </div>
    </template>

    <!-- Loading state for all data -->
    <div v-if="isLoading" class="d-flex justify-content-center py-5">
      <BSpinner label="Loading visualization data..." />
    </div>

    <!-- Tabs container -->
    <div v-else class="visualization-tabs">
      <BTabs
        v-model:index="activeTabIndex"
        pills
        card
        nav-wrapper-class="visualization-nav-wrapper"
        content-class="visualization-content"
      >
        <!-- Tab 1: Protein View (Lollipop Plot) -->
        <BTab title-item-class="visualization-tab-item">
          <template #title>
            <span class="tab-title">
              <i class="bi bi-diagram-3" aria-hidden="true" />
              Protein View
              <BBadge v-if="variantCount > 0" variant="secondary" pill class="ms-1">
                {{ formatCount(variantCount) }}
              </BBadge>
            </span>
          </template>

          <!--
            v11.3 W2.4: lazy-mount inactive panels.
            Heavy SVG plot only mounts after the protein tab has been
            activated at least once; `KeepAlive` then caches the instance
            so revisits are instant. Initial active tab is 0 (protein),
            so the plot mounts on first paint.
          -->
          <div class="visualization-panel visualization-panel--protein">
            <KeepAlive>
              <div v-if="activeTab === 'protein'">
                <ProteinDomainLollipopPlot
                  v-if="hasProteinData"
                  ref="proteinPlotRef"
                  :data="proteinPlotData!"
                  :gene-symbol="geneSymbol"
                  @variant-click="handleVariantClick"
                  @variant-hover="handleVariantHover"
                />
                <div v-else class="empty-state">
                  <i class="bi bi-diagram-3" />
                  <p>No protein domain or variant data available</p>
                </div>
              </div>
            </KeepAlive>
          </div>
        </BTab>

        <!-- Tab 2: Gene Structure (lazy loaded on activate) -->
        <BTab title-item-class="visualization-tab-item" @click="onGeneStructureTabClick">
          <template #title>
            <span class="tab-title">
              <i class="bi bi-bar-chart-steps" aria-hidden="true" />
              Gene Structure
              <BBadge v-if="exonCount > 0" variant="secondary" pill class="ms-1">
                {{ exonCount }} exons
              </BBadge>
            </span>
          </template>

          <!--
            v11.3 W2.4: heavy gene-structure plot is gated on first
            activation of this tab; `KeepAlive` caches the instance for
            instant revisits.
          -->
          <div class="visualization-panel">
            <KeepAlive>
              <div v-if="activeTab === 'structure'">
                <GeneStructurePlotWithVariants
                  v-if="hasGeneStructureData"
                  :gene-data="geneStructureData!"
                  :variants="genomicVariants"
                  :gene-symbol="geneSymbol"
                  @variant-click="handleGenomicVariantClick"
                />
                <div v-else-if="geneStructureLoading" class="d-flex justify-content-center py-4">
                  <BSpinner small label="Loading gene structure..." />
                </div>
                <div v-else class="empty-state">
                  <i class="bi bi-bar-chart-steps" />
                  <p>No gene structure data available</p>
                </div>
              </div>
            </KeepAlive>
          </div>
        </BTab>

        <!-- Tab 3: 3D Structure (lazy loaded on activate) -->
        <BTab title-item-class="visualization-tab-item" lazy>
          <template #title>
            <span class="tab-title">
              <i class="bi bi-box" aria-hidden="true" />
              3D Structure
            </span>
          </template>

          <!--
            v11.3 W2.4: 3D viewer is the heaviest panel - keep it gated
            until first activation, then cache via `KeepAlive` so the
            WebGL context isn't reinitialised on revisit.
          -->
          <div class="visualization-panel-3d">
            <KeepAlive>
              <ProteinStructure3D
                v-if="activeTab === 'three-d'"
                :gene-symbol="geneSymbol"
                :structure-url="alphafoldPdbUrl"
                :variants="clinvarVariants || []"
                :metadata="alphafoldMetadata"
              />
            </KeepAlive>
          </div>
        </BTab>
      </BTabs>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { BCard, BTabs, BTab, BBadge, BSpinner } from 'bootstrap-vue-next';
import { isApiError } from '@/api/client';
import { getEnsemblStructure } from '@/api/external';
import ProteinDomainLollipopPlot from './ProteinDomainLollipopPlot.vue';
import GeneStructurePlotWithVariants from './GeneStructurePlotWithVariants.vue';
import ProteinStructure3D from './ProteinStructure3D.vue';
import type { ProteinPlotData, ProcessedVariant } from '@/types/protein';
import type { ClinVarVariant } from '@/types/external';
import type { EnsemblGeneStructure, GeneStructureRenderData } from '@/types/ensembl';
import { processEnsemblResponse, formatGenomicCoordinate } from '@/types/ensembl';
import type { AlphaFoldMetadata } from '@/types/alphafold';
import {
  buildProteinPlotData,
  buildGenomicVariants,
  type GenomicVariant,
  type UniProtData,
} from './genomicVisualizationData';

// Re-export GenomicVariant so existing consumers keep importing it from this
// component file (import-preserving). The implementation lives in the
// genomicVisualizationData module alongside the builders that produce it.
export type { GenomicVariant } from './genomicVisualizationData';

interface Props {
  geneSymbol: string;
  clinvarVariants: ClinVarVariant[] | null;
  clinvarLoading: boolean;
  clinvarError: string | null;
  uniprotData: UniProtData | null;
  uniprotLoading: boolean;
  uniprotError: string | null;
  /** Chromosome location for coordinate estimation */
  chromosomeLocation?: string;
  /** AlphaFold structure PDB URL (null if no structure) */
  alphafoldPdbUrl: string | null;
  /** Full AlphaFold metadata for model indicator */
  alphafoldMetadata?: AlphaFoldMetadata | null;
  /** AlphaFold data loading state */
  alphafoldLoading: boolean;
  /** AlphaFold data error state */
  alphafoldError: string | null;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'variant-click', variant: ProcessedVariant | GenomicVariant): void;
  (e: 'retry'): void;
}>();

// Active tab state - drives lazy-mount gates for inactive panels (v11.3 W2.4).
// `BTabs` v-models `index` (number); we expose a string id so the template
// reads `activeTab === 'protein' | 'structure' | 'three-d'`.
const activeTabIndex = ref(0);
const TAB_IDS = ['protein', 'structure', 'three-d'] as const;
type TabId = (typeof TAB_IDS)[number];
const activeTab = computed<TabId>(() => TAB_IDS[activeTabIndex.value] ?? 'protein');

// Template refs
const proteinPlotRef = ref<InstanceType<typeof ProteinDomainLollipopPlot> | null>(null);

// Gene structure data state (lazy loaded)
const geneStructureData = ref<GeneStructureRenderData | null>(null);
const geneStructureLoading = ref(false);
const geneStructureError = ref<string | null>(null);
const ensemblRawData = ref<EnsemblGeneStructure | null>(null);
const geneStructureFetched = ref(false); // Track if we've fetched gene structure

/**
 * Computed: Is any data loading?
 */
const isLoading = computed(
  () => props.clinvarLoading && props.uniprotLoading && geneStructureLoading.value
);

/**
 * Computed: Has protein data available
 */
const hasProteinData = computed(() => {
  return proteinPlotData.value !== null;
});

/**
 * Computed: Has gene structure data available
 */
const hasGeneStructureData = computed(() => {
  return geneStructureData.value !== null;
});

/**
 * Computed: Variant count
 */
const variantCount = computed(() => {
  return props.clinvarVariants?.length || 0;
});

/**
 * Computed: Exon count
 */
const exonCount = computed(() => {
  return geneStructureData.value?.exonCount || 0;
});

/**
 * Computed: Summary text for header
 */
const summaryText = computed(() => {
  const parts: string[] = [];
  if (variantCount.value > 0) {
    parts.push(`${formatCount(variantCount.value)} variants`);
  }
  if (exonCount.value > 0) {
    parts.push(`${exonCount.value} exons`);
  }
  if (geneStructureData.value) {
    parts.push(formatGenomicCoordinate(geneStructureData.value.geneLength));
  }
  return parts.join(' · ');
});

/**
 * Format large numbers with K suffix
 */
function formatCount(count: number): string {
  if (count >= 1000) {
    return `${(count / 1000).toFixed(1)}K`;
  }
  return String(count);
}

/**
 * Process variants for protein lollipop plot
 */
const proteinPlotData = computed<ProteinPlotData | null>(() =>
  buildProteinPlotData({
    uniprotData: props.uniprotData,
    uniprotError: props.uniprotError,
    clinvarVariants: props.clinvarVariants,
    clinvarError: props.clinvarError,
  })
);

/**
 * Process variants with genomic positions for gene structure plot.
 * Uses exon-aware mapping (variants only appear on exons, NOT introns).
 */
const genomicVariants = computed<GenomicVariant[]>(() =>
  buildGenomicVariants(props.clinvarVariants, ensemblRawData.value)
);

/**
 * Fetch Ensembl gene structure data (lazy loaded on tab activation)
 */
async function fetchGeneStructureData(): Promise<void> {
  if (!props.geneSymbol) return;
  if (geneStructureFetched.value) return; // Already fetched

  geneStructureLoading.value = true;
  geneStructureError.value = null;

  try {
    const data = await getEnsemblStructure(props.geneSymbol, {
      withCredentials: true,
    });

    // Defensive runtime narrow: the R endpoint maps the
    // `list(found = FALSE)` and `list(error = TRUE)` paths to 404/503
    // (handled in the catch branch), but legacy proxy payloads may still
    // ship those shapes inside a 200. Mirror GeneStructureCard.vue.
    const payload = data as unknown as {
      found?: boolean;
      error?: boolean;
      message?: string;
    };
    if (payload?.found === false) {
      geneStructureData.value = null;
      ensemblRawData.value = null;
    } else if (payload?.error) {
      geneStructureError.value = payload.message || 'Failed to load gene structure';
    } else {
      ensemblRawData.value = data;
      geneStructureData.value = processEnsemblResponse(ensemblRawData.value);
    }
  } catch (e: unknown) {
    if (isApiError(e) && e.response?.status === 404) {
      geneStructureData.value = null;
      ensemblRawData.value = null;
    } else if (isApiError(e) && e.response?.status === 503) {
      geneStructureError.value = 'Ensembl API temporarily unavailable';
    } else {
      geneStructureError.value = 'Failed to load gene structure data';
    }
  }

  geneStructureLoading.value = false;
  geneStructureFetched.value = true; // Mark as fetched
}

/**
 * Handle Gene Structure tab click/activation - trigger lazy loading
 */
function onGeneStructureTabClick(): void {
  activeTabIndex.value = 1; // Track that we're on gene structure tab
  if (!geneStructureFetched.value && props.geneSymbol) {
    fetchGeneStructureData();
  }
}

/**
 * Handle variant click from protein plot
 */
function handleVariantClick(variant: ProcessedVariant): void {
  emit('variant-click', variant);
}

/**
 * Handle variant hover from protein plot
 */
function handleVariantHover(variant: ProcessedVariant | null): void {
  // Could be used for cross-highlighting in future
  console.log('[GenomicVisualizationTabs] Variant hover:', variant?.proteinHGVS);
}

/**
 * Handle variant click from gene structure plot
 */
function handleGenomicVariantClick(variant: GenomicVariant): void {
  emit('variant-click', variant);
}

// Lifecycle - NO automatic fetch on mount (lazy loading)
onMounted(() => {
  // Don't fetch gene structure on mount - wait for tab activation
});

// Watch for gene symbol changes - reset fetch state
watch(
  () => props.geneSymbol,
  () => {
    // Reset fetch state when gene changes
    geneStructureFetched.value = false;
    geneStructureData.value = null;
    ensemblRawData.value = null;

    // If gene structure tab was already visited for previous gene,
    // and we're still on it, refetch for new gene
    if (activeTabIndex.value === 1 && props.geneSymbol) {
      fetchGeneStructureData();
    }
  }
);
</script>

<style scoped>
/* Visualization tabs styling */
.genomic-visualization-title {
  font-size: 1rem;
  line-height: 1.2;
}

.visualization-tabs {
  width: 100%;
}

/* Nav wrapper - consistent with scientific plotting conventions */
.visualization-tabs :deep(.visualization-nav-wrapper) {
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  padding: 8px 12px 0;
}

/* Tab items */
.visualization-tabs :deep(.visualization-tab-item) {
  margin-right: 4px;
}

.visualization-tabs :deep(.visualization-tab-item .nav-link) {
  padding: 6px 12px;
  font-size: 0.85rem;
  border-radius: 4px 4px 0 0;
  color: #495057;
  background: transparent;
  border: 1px solid transparent;
  border-bottom: none;
}

.visualization-tabs :deep(.visualization-tab-item .nav-link:hover) {
  background: #e9ecef;
  border-color: #dee2e6 #dee2e6 transparent;
}

.visualization-tabs :deep(.visualization-tab-item .nav-link.active) {
  background: #fff;
  border-color: #dee2e6 #dee2e6 #fff;
  color: #212529;
  font-weight: 500;
}

/* Tab title styling */
.tab-title {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.tab-title i {
  font-size: 0.9rem;
}

/* Content area */
.visualization-tabs :deep(.visualization-content) {
  padding: 0;
  background: #fff;
}

/* Visualization panel - compact height and styling */
.visualization-panel {
  min-height: 200px;
  max-height: 380px;
  overflow-y: auto;
  padding: 6px 12px;
}

.visualization-panel--protein {
  max-height: none;
  overflow-y: visible;
}

/* Visualization panel for 3D structure - full height, no padding */
.visualization-panel-3d {
  height: 500px; /* Fixed height per Phase 45 spec */
  overflow: hidden;
  padding: 0;
}

/* Empty state */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 200px;
  color: #6c757d;
  text-align: center;
}

.empty-state i {
  font-size: 2.5rem;
  margin-bottom: 12px;
  opacity: 0.5;
}

.empty-state p {
  margin: 0;
  font-size: 0.95rem;
}

.empty-state small {
  margin-top: 8px;
  font-size: 0.8rem;
}

/* Ensure plots fill container properly */
.visualization-panel :deep(.protein-lollipop-plot),
.visualization-panel :deep(.gene-structure-plot) {
  width: 100%;
}

/* Match plot container styling */
.visualization-panel :deep(.plot-container) {
  width: 100%;
  min-height: 140px;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .visualization-panel {
    min-height: 180px;
    max-height: 320px;
  }

  .visualization-panel--protein {
    max-height: none;
    overflow-y: visible;
  }

  .visualization-tabs :deep(.visualization-tab-item .nav-link) {
    padding: 5px 8px;
    font-size: 0.8rem;
  }

  .tab-title .badge {
    display: none;
  }
}
</style>
