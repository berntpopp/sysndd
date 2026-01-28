<!-- src/components/gene/ProteinDomainLollipopCard.vue -->
<!--
  Card wrapper for the protein domain lollipop plot visualization

  Handles:
  - Loading states for UniProt (domains) and ClinVar (variants) data
  - Error states with retry button
  - Empty state when no data available
  - Partial data display (domains only or variants only)
  - Data transformation from raw API responses to ProteinPlotData format

  Uses ProteinDomainLollipopPlot for actual D3.js visualization.
-->
<template>
  <BCard
    class="shadow-sm border-0 mb-3"
    body-class="p-2"
    header-class="py-2 px-3"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h6 class="mb-0 fw-bold">
          <i class="bi bi-diagram-3" /> Protein Domains &amp; ClinVar Variants
        </h6>
        <!-- Reset zoom button (only shown when zoomed in) -->
        <BButton
          v-if="isZoomed"
          variant="outline-secondary"
          size="sm"
          @click="handleResetZoom"
        >
          <i class="bi bi-arrows-angle-expand" /> Reset Zoom
        </BButton>
      </div>
    </template>

    <!-- State 1: Both loading -->
    <div v-if="isLoading" class="d-flex justify-content-center py-4">
      <BSpinner label="Loading protein domain data..." />
    </div>

    <!-- State 2: Full failure (both sources errored) -->
    <div v-else-if="isFullError" class="text-center py-4">
      <p class="text-muted mb-2">
        <i class="bi bi-exclamation-triangle" /> Unable to load protein domain data
      </p>
      <BButton variant="outline-primary" size="sm" @click="$emit('retry')">
        <i class="bi bi-arrow-clockwise" /> Retry
      </BButton>
    </div>

    <!-- State 3: Data available (partial or full) -->
    <div v-else-if="plotData">
      <ProteinDomainLollipopPlot
        ref="plotRef"
        :data="plotData"
        :gene-symbol="geneSymbol"
        @variant-click="$emit('variant-click', $event)"
      />
      <!-- Partial error messages -->
      <div v-if="uniprotError" class="text-muted small text-center mt-1">
        <i class="bi bi-info-circle" /> Domain data unavailable - showing variants only
      </div>
      <div v-if="clinvarError" class="text-muted small text-center mt-1">
        <i class="bi bi-info-circle" /> Variant data unavailable - showing domains only
      </div>
    </div>

    <!-- State 4: No data at all (not error, just empty) -->
    <div v-else class="text-center py-4 text-muted">
      <i class="bi bi-diagram-3" /> No protein domain or variant data available for this gene
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { BCard, BButton, BSpinner } from 'bootstrap-vue-next';
import ProteinDomainLollipopPlot from '@/components/gene/ProteinDomainLollipopPlot.vue';
import type {
  ProteinPlotData,
  ProteinDomain,
  ProcessedVariant,
} from '@/types/protein';
import { normalizeClassification, parseProteinPosition } from '@/types/protein';
import type { ClinVarVariant } from '@/types/external';

/**
 * UniProt domain feature from the API response
 */
interface UniProtDomainFeature {
  type: string;
  description?: string;
  begin: number | string;
  end: number | string;
}

/**
 * UniProt API response structure from /api/external/uniprot/domains/<symbol>
 */
interface UniProtData {
  source: string;
  gene_symbol: string;
  accession: string;
  protein_name: string;
  protein_length: number | string;
  domains: UniProtDomainFeature[];
}

/**
 * Component props
 */
interface Props {
  /** Raw UniProt API response (domains, protein length, accession) */
  uniprotData: UniProtData | null;
  /** Raw ClinVar variants from gnomAD API */
  clinvarVariants: ClinVarVariant[] | null;
  /** Loading state for UniProt source */
  uniprotLoading: boolean;
  /** Loading state for ClinVar source */
  clinvarLoading: boolean;
  /** Error message for UniProt source */
  uniprotError: string | null;
  /** Error message for ClinVar source */
  clinvarError: string | null;
  /** Gene symbol for display and accessibility */
  geneSymbol: string;
}

const props = defineProps<Props>();

/**
 * Component emits
 */
const emit = defineEmits<{
  /** Emitted when retry button is clicked */
  (e: 'retry'): void;
  /** Emitted when a variant marker is clicked (for Phase 45 3D viewer linking) */
  (e: 'variant-click', variant: ProcessedVariant): void;
}>();

// Expose emit to suppress unused variable warning
void emit;

// Template ref for the plot component
const plotRef = ref<InstanceType<typeof ProteinDomainLollipopPlot> | null>(null);

/**
 * Computed: isLoading
 * True when either UniProt or ClinVar is still loading
 */
const isLoading = computed(() => props.uniprotLoading || props.clinvarLoading);

/**
 * Computed: isFullError
 * True when both sources have errors and no data is available
 */
const isFullError = computed(() =>
  !props.uniprotLoading &&
  !props.clinvarLoading &&
  !!props.uniprotError &&
  !!props.clinvarError
);

/**
 * Estimate protein length from variant positions when UniProt data is unavailable
 * Returns max variant position + 10% buffer, or 1000 if no variants
 */
function estimateProteinLength(variants: ProcessedVariant[]): number {
  if (variants.length === 0) return 1000;

  const maxPosition = Math.max(...variants.map((v) => v.proteinPosition));
  // Add 10% buffer to the max position
  return Math.ceil(maxPosition * 1.1);
}

/**
 * Computed: plotData
 * Process raw API data into ProteinPlotData format for the visualization
 */
const plotData = computed<ProteinPlotData | null>(() => {
  // Need at least one data source
  const hasUniprot = props.uniprotData && !props.uniprotError;
  const hasClinvar = props.clinvarVariants && !props.clinvarError;

  if (!hasUniprot && !hasClinvar) return null;

  // Process domains from UniProt response
  const domains: ProteinDomain[] = hasUniprot
    ? (props.uniprotData?.domains || []).map((d) => ({
        type: d.type,
        description: d.description || '',
        begin: Number(d.begin),
        end: Number(d.end),
      }))
    : [];

  // Process variants from ClinVar response
  const variants: ProcessedVariant[] = hasClinvar
    ? (props.clinvarVariants || [])
        .map((v) => {
          const parsed = parseProteinPosition(v.hgvsp, v.hgvsc);
          if (!parsed) return null;
          return {
            proteinPosition: parsed.position,
            // Handle empty objects {} from gnomAD API (truthy but not strings)
            proteinHGVS: typeof v.hgvsp === 'string' ? v.hgvsp : 'N/A',
            codingHGVS: typeof v.hgvsc === 'string' ? v.hgvsc : 'N/A',
            classification: normalizeClassification(v.clinical_significance),
            goldStars: v.gold_stars,
            reviewStatus: v.review_status,
            clinvarId: String(v.clinvar_variation_id),
            variantId: v.variant_id,
            majorConsequence: v.major_consequence,
            isSpliceVariant: parsed.isSplice,
            inGnomad: v.in_gnomad,
          } as ProcessedVariant;
        })
        .filter((v): v is ProcessedVariant => v !== null)
    : [];

  // Calculate protein length: use max of UniProt length and max variant position
  // This handles cases where ClinVar variants are annotated to a different isoform
  // than the UniProt canonical sequence (e.g., MECP2 isoform e1 vs e2)
  const uniprotLength = hasUniprot ? Number(props.uniprotData?.protein_length) : 0;
  const maxVariantPosition = variants.length > 0
    ? Math.max(...variants.map((v) => v.proteinPosition))
    : 0;
  const proteinLength = Math.max(uniprotLength, maxVariantPosition);
  const proteinName = hasUniprot ? props.uniprotData?.protein_name || '' : '';
  const accession = hasUniprot ? props.uniprotData?.accession || '' : '';

  return {
    proteinLength,
    proteinName,
    accession,
    domains,
    variants,
  };
});

/**
 * Computed: isZoomed
 * Check if the plot is currently zoomed in (for showing reset button)
 * This accesses the composable's currentZoomDomain via the component ref
 */
const isZoomed = computed(() => {
  // The plot component does not expose currentZoomDomain directly in this implementation
  // For now, we'll always show the reset button is not visible
  // A future enhancement could expose this from the plot component
  return false;
});

/**
 * Handle reset zoom button click
 * Calls the plot component's resetZoom method
 */
function handleResetZoom(): void {
  // Plot component would need to expose resetZoom via defineExpose
  // For now, this is a placeholder for future implementation
  console.log('[ProteinDomainLollipopCard] Reset zoom requested');
}
</script>

<style scoped>
/* Card styling follows existing patterns from IdentifierCard/ClinicalResourcesCard */
</style>
