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

          <BButton
            variant="outline-secondary"
            size="sm"
            aria-label="Export view as PNG image"
            :disabled="isExporting"
            @click="handleExportPNG"
          >
            <i class="bi bi-image"></i> PNG
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

        <!-- Model Indicator (AlphaFold entry info) -->
        <div v-if="metadata" class="model-info text-muted small">
          <span>{{ metadata.entry_id }}</span>
          <span class="separator">·</span>
          <span>AlphaFold v{{ metadata.latest_version }}</span>
        </div>
      </div>

      <!-- Right: Variant Panel (30%, STRUCT3D-04) -->
      <div class="variant-section">
        <VariantPanel
          :variants="variants"
          @toggle-variant="handleToggleVariant"
          @clear-all="handleClearVariants"
          @filter-change="handleFilterChange"
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
import type { RepresentationType, AcmgClassification, AlphaFoldMetadata } from '@/types/alphafold';
import type { ClinVarVariant } from '@/types/external';

interface Props {
  geneSymbol: string;
  structureUrl: string | null;  // AlphaFold PDB/CIF URL (null = no structure)
  variants: ClinVarVariant[];   // ClinVar variants for variant panel
  metadata?: AlphaFoldMetadata | null;  // AlphaFold metadata for model indicator
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
  exportPNG,
} = use3DStructure(viewerContainer);

// Export state
const isExporting = ref(false);

// Track currently selected variants with their classifications for filter sync
// Map of residue number -> AcmgClassification
const selectedVariantClassifications = ref<Map<number, AcmgClassification | null>>(new Map());

// Currently hidden classifications from filter panel
const hiddenClassifications = ref<AcmgClassification[]>([]);

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

  const classification = classifyClinicalSignificance(payload.variant.clinical_significance);

  if (payload.selected) {
    // Track the classification for this residue
    selectedVariantClassifications.value.set(residue, classification);

    // Only add marker if classification is not hidden
    if (!classification || !hiddenClassifications.value.includes(classification)) {
      const color = classification ? ACMG_COLORS[classification] : '#999999';
      const label = payload.variant.hgvsp || payload.variant.variant_id;
      addVariantMarker(residue, color, label);
    }
  } else {
    // Remove tracking and marker
    selectedVariantClassifications.value.delete(residue);
    removeVariantMarker(residue);
  }
}

// Clear all variant markers
function handleClearVariants(): void {
  selectedVariantClassifications.value.clear();
  clearAllVariantMarkers();
}

// Handle filter changes from VariantPanel
// Updates 3D markers to match filter state (hide markers for hidden classifications)
function handleFilterChange(payload: { hiddenClassifications: AcmgClassification[] }): void {
  const newHidden = payload.hiddenClassifications;
  const oldHidden = hiddenClassifications.value;

  // Find classifications that were hidden and are now visible (need to add markers back)
  const nowVisible = oldHidden.filter(c => !newHidden.includes(c));

  // Find classifications that are now hidden (need to remove markers)
  const nowHidden = newHidden.filter(c => !oldHidden.includes(c));

  // Update hidden state
  hiddenClassifications.value = newHidden;

  // Remove markers for newly hidden classifications
  for (const [residue, classification] of selectedVariantClassifications.value.entries()) {
    if (classification && nowHidden.includes(classification)) {
      removeVariantMarker(residue);
    }
  }

  // Re-add markers for newly visible classifications
  for (const [residue, classification] of selectedVariantClassifications.value.entries()) {
    if (classification && nowVisible.includes(classification)) {
      // Find the variant to get color and label
      const variant = props.variants.find(v => parseResidueNumber(v.hgvsp) === residue);
      if (variant) {
        const color = ACMG_COLORS[classification];
        const label = variant.hgvsp || variant.variant_id;
        addVariantMarker(residue, color, label);
      }
    }
  }
}

// PNG export handler
async function handleExportPNG(): Promise<void> {
  isExporting.value = true;
  try {
    const dataUrl = await exportPNG();
    if (dataUrl) {
      // Create download link
      const link = document.createElement('a');
      link.href = dataUrl;
      link.download = `${props.geneSymbol}-3d-structure.png`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  } finally {
    isExporting.value = false;
  }
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

/* NGL.Stage creates an internal wrapper div that needs explicit dimensions.
   Without this, the canvas has 0x0 size in flexbox layouts.
   See: https://github.com/nglviewer/ngl/issues/890 */
.ngl-viewport :deep(> div) {
  width: 100%;
  height: 100%;
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

/* Model info indicator */
.model-info {
  display: flex;
  gap: 4px;
  padding: 4px 8px;
  background: #f8f9fa;
  border-top: 1px solid #dee2e6;
  align-items: center;
  flex-shrink: 0;
  font-size: 0.7rem;
}

.model-info .separator {
  color: #adb5bd;
}
</style>
