<template>
  <div class="protein-structure-3d" role="region" aria-label="3D protein structure viewer">

    <!-- Loading State (before structure loads) -->
    <div v-if="isLoading" class="state-overlay">
      <BSpinner label="Loading 3D structure..." />
      <p class="text-muted mt-2 small">Loading 3D structure...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="viewerError" class="state-overlay" role="alert">
      <i class="bi bi-exclamation-triangle text-warning fs-3"></i>
      <p class="text-muted mt-2 small">{{ viewerError }}</p>
      <BButton variant="outline-primary" size="sm" @click="retryLoad">Retry</BButton>
    </div>

    <!-- Empty State (no AlphaFold structure, STRUCT3D-07) -->
    <div v-else-if="!structureUrl" class="state-overlay">
      <i class="bi bi-box text-muted fs-3"></i>
      <p class="text-muted mt-2 small">
        No AlphaFold structure available for {{ geneSymbol }}
      </p>
    </div>

    <!-- Active Viewer Layout (70% viewer + 30% variant panel) -->
    <div v-show="isInitialized && !isLoading && structureUrl" class="viewer-layout">

      <!-- Left: NGL Viewer (70%) -->
      <div class="viewer-section">
        <!-- Controls Toolbar (STRUCT3D-02, STRUCT3D-06, A11Y-04) -->
        <div class="controls-toolbar" role="toolbar" aria-label="3D viewer controls">
          <BButtonGroup size="sm">
            <BButton
              v-for="repr in representationOptions"
              :key="repr.value"
              :variant="activeRepresentation === repr.value ? 'primary' : 'outline-secondary'"
              :aria-pressed="activeRepresentation === repr.value"
              :aria-label="`Show ${repr.label} representation`"
              @click="handleSetRepresentation(repr.value)"
              @keydown.enter="handleSetRepresentation(repr.value)"
            >
              {{ repr.label }}
            </BButton>
          </BButtonGroup>

          <BButton
            variant="outline-secondary"
            size="sm"
            aria-label="Reset view to default orientation"
            @click="resetView"
            @keydown.enter="resetView"
          >
            <i class="bi bi-arrow-clockwise"></i> Reset View
          </BButton>
        </div>

        <!-- NGL Viewport Container -->
        <div ref="viewerContainer" class="ngl-viewport" tabindex="0" aria-label="3D protein structure - use mouse to rotate, scroll to zoom" />

        <!-- pLDDT Legend (STRUCT3D-01) -->
        <div class="plddt-legend" aria-label="pLDDT confidence color legend">
          <span class="legend-title">pLDDT:</span>
          <span
            v-for="item in PLDDT_LEGEND"
            :key="item.label"
            class="legend-item"
          >
            <span class="legend-color" :style="{ backgroundColor: item.color }" :aria-hidden="true"></span>
            <span class="small">{{ item.label }}</span>
          </span>
        </div>
      </div>

      <!-- Right: Variant Panel (30%, STRUCT3D-04) -->
      <div class="variant-section">
        <VariantPanel
          :variants="variants"
          @toggle-variant="handleToggleVariant"
          @clear-all="handleClearVariants"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { BSpinner, BButton, BButtonGroup } from 'bootstrap-vue-next';
import { use3DStructure } from '@/composables/use3DStructure';
import VariantPanel from './VariantPanel.vue';
import { PLDDT_LEGEND, ACMG_COLORS, classifyClinicalSignificance, parseResidueNumber } from '@/types/alphafold';
import type { RepresentationType } from '@/types/alphafold';
import type { ClinVarVariant } from '@/types/external';

interface Props {
  geneSymbol: string;
  structureUrl: string | null;  // AlphaFold PDB/CIF URL (null = no structure)
  variants: ClinVarVariant[];   // ClinVar variants for variant panel
}

const props = defineProps<Props>();

const viewerContainer = ref<HTMLElement | null>(null);

// Use the 3D structure composable
const {
  isInitialized,
  isLoading,
  error: composableError,
  activeRepresentation,
  loadStructure,
  addVariantMarker,
  removeVariantMarker,
  clearAllVariantMarkers,
  setRepresentation,
  resetView,
} = use3DStructure(viewerContainer);

// Local error state (combines composable error with component-level errors)
const viewerError = ref<string | null>(null);

// Representation toggle options
const representationOptions: { value: RepresentationType; label: string }[] = [
  { value: 'cartoon', label: 'Cartoon' },
  { value: 'surface', label: 'Surface' },
  { value: 'ball+stick', label: 'Ball+Stick' },
];

// Sync composable error to local error
watch(composableError, (val) => { viewerError.value = val; });

// Load structure when initialized and URL available
watch([isInitialized, () => props.structureUrl], async ([initialized, url]) => {
  if (initialized && url) {
    try {
      await loadStructure(url);
      viewerError.value = null;
    } catch {
      viewerError.value = 'Failed to load 3D structure. Please try again.';
    }
  }
});

// Representation toggle handler
function handleSetRepresentation(type: RepresentationType): void {
  setRepresentation(type);
}

// Variant toggle handler (called from VariantPanel)
function handleToggleVariant(payload: { variant: ClinVarVariant; selected: boolean }): void {
  const residue = parseResidueNumber(payload.variant.hgvsp);
  if (residue === null) return; // Skip variants without parseable position

  if (payload.selected) {
    const classification = classifyClinicalSignificance(payload.variant.clinical_significance);
    const color = classification ? ACMG_COLORS[classification] : '#999999';
    const label = payload.variant.hgvsp || payload.variant.variant_id;
    addVariantMarker(residue, color, label);
  } else {
    removeVariantMarker(residue);
  }
}

// Clear all variant markers
function handleClearVariants(): void {
  clearAllVariantMarkers();
}

// Retry loading
async function retryLoad(): Promise<void> {
  if (props.structureUrl) {
    viewerError.value = null;
    try {
      await loadStructure(props.structureUrl);
    } catch {
      viewerError.value = 'Failed to load 3D structure. Please try again.';
    }
  }
}
</script>

<style scoped>
.protein-structure-3d {
  position: relative;
  height: 500px;  /* Fixed height per CONTEXT.md */
  display: flex;
  flex-direction: column;
}

.state-overlay {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
}

.viewer-layout {
  display: flex;
  height: 100%;
  gap: 0;
}

.viewer-section {
  flex: 7;  /* 70% width */
  position: relative;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.variant-section {
  flex: 3;  /* 30% width */
  border-left: 1px solid #dee2e6;
  overflow-y: auto;
  min-width: 0;
}

.controls-toolbar {
  display: flex;
  gap: 8px;
  padding: 6px 8px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  align-items: center;
  flex-shrink: 0;
  z-index: 10;
}

.ngl-viewport {
  flex: 1;
  min-height: 0;
  outline: none;  /* Remove focus outline on viewer */
}

.ngl-viewport:focus-visible {
  outline: 2px solid #0d6efd;
  outline-offset: -2px;
}

.plddt-legend {
  display: flex;
  gap: 8px;
  padding: 4px 8px;
  background: #f8f9fa;
  border-top: 1px solid #dee2e6;
  align-items: center;
  flex-shrink: 0;
}

.legend-title {
  font-weight: 600;
  font-size: 0.75rem;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 3px;
  font-size: 0.75rem;
}

.legend-color {
  display: inline-block;
  width: 16px;
  height: 10px;
  border-radius: 2px;
  flex-shrink: 0;
}
</style>
