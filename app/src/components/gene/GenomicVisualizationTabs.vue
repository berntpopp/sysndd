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
  <BCard
    class="shadow-sm border-0 mb-3"
    body-class="p-0"
    header-class="py-2 px-3"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h6 class="mb-0 fw-bold">
          <i class="bi bi-graph-up" /> Genomic Visualizations
        </h6>
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
        pills
        card
        nav-wrapper-class="visualization-nav-wrapper"
        content-class="visualization-content"
      >
        <!-- Tab 1: Protein View (Lollipop Plot) -->
        <BTab title-item-class="visualization-tab-item">
          <template #title>
            <span class="tab-title">
              <i class="bi bi-diagram-3" />
              Protein View
              <BBadge v-if="variantCount > 0" variant="secondary" pill class="ms-1">
                {{ formatCount(variantCount) }}
              </BBadge>
            </span>
          </template>

          <div class="visualization-panel">
            <!-- Protein lollipop content -->
            <div v-if="hasProteinData">
              <ProteinDomainLollipopPlot
                ref="proteinPlotRef"
                :data="proteinPlotData!"
                :gene-symbol="geneSymbol"
                @variant-click="handleVariantClick"
                @variant-hover="handleVariantHover"
              />
            </div>
            <div v-else class="empty-state">
              <i class="bi bi-diagram-3" />
              <p>No protein domain or variant data available</p>
            </div>
          </div>
        </BTab>

        <!-- Tab 2: Gene Structure (lazy loaded on activate) -->
        <BTab title-item-class="visualization-tab-item" @click="onGeneStructureTabClick">
          <template #title>
            <span class="tab-title">
              <i class="bi bi-bar-chart-steps" />
              Gene Structure
              <BBadge v-if="exonCount > 0" variant="secondary" pill class="ms-1">
                {{ exonCount }} exons
              </BBadge>
            </span>
          </template>

          <div class="visualization-panel">
            <div v-if="hasGeneStructureData">
              <GeneStructurePlotWithVariants
                :gene-data="geneStructureData!"
                :variants="genomicVariants"
                :gene-symbol="geneSymbol"
                @variant-click="handleGenomicVariantClick"
              />
            </div>
            <div v-else-if="geneStructureLoading" class="d-flex justify-content-center py-4">
              <BSpinner small label="Loading gene structure..." />
            </div>
            <div v-else class="empty-state">
              <i class="bi bi-bar-chart-steps" />
              <p>No gene structure data available</p>
            </div>
          </div>
        </BTab>

        <!-- Tab 3: 3D Structure (lazy loaded on activate) -->
        <BTab title-item-class="visualization-tab-item" lazy>
          <template #title>
            <span class="tab-title">
              <i class="bi bi-box" />
              3D Structure
            </span>
          </template>

          <div class="visualization-panel-3d">
            <ProteinStructure3D
              :gene-symbol="geneSymbol"
              :structure-url="alphafoldPdbUrl"
              :variants="clinvarVariants || []"
              :metadata="alphafoldMetadata"
            />
          </div>
        </BTab>
      </BTabs>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { BCard, BTabs, BTab, BBadge, BSpinner } from 'bootstrap-vue-next';
import axios from 'axios';
import ProteinDomainLollipopPlot from './ProteinDomainLollipopPlot.vue';
import GeneStructurePlotWithVariants from './GeneStructurePlotWithVariants.vue';
import ProteinStructure3D from './ProteinStructure3D.vue';
import type { ProteinPlotData, ProcessedVariant, ProteinDomain } from '@/types/protein';
import { normalizeClassification, parseProteinPosition } from '@/types/protein';
import type { ClinVarVariant } from '@/types/external';
import type { EnsemblGeneStructure, GeneStructureRenderData } from '@/types/ensembl';
import { processEnsemblResponse, formatGenomicCoordinate } from '@/types/ensembl';
import type { AlphaFoldMetadata } from '@/types/alphafold';

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
 * UniProt API response structure
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
 * Genomic variant for gene structure plot
 */
export interface GenomicVariant {
  genomicPosition: number;
  proteinPosition: number;
  proteinHGVS: string;
  codingHGVS: string;
  classification: string;
  goldStars: number;
  reviewStatus: string;
  clinvarId: string;
  variantId: string;
  majorConsequence: string;
}

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

// Active tab state - BTabs expects string for tab selection
const activeTabIndex = ref(0);

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
const isLoading = computed(() =>
  props.clinvarLoading && props.uniprotLoading && geneStructureLoading.value
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
const proteinPlotData = computed<ProteinPlotData | null>(() => {
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

  // Calculate protein length
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
 * Build exon coordinate map from Ensembl data
 * Maps cumulative exon positions to genomic coordinates (accounting for strand)
 *
 * Since we don't have CDS boundaries, we map across all exons
 * This ensures variants only appear on exons, not introns
 */
interface ExonMapEntry {
  genomicStart: number;
  genomicEnd: number;
  cumulativeStart: number; // Cumulative base position start
  cumulativeEnd: number; // Cumulative base position end
}

function buildExonMap(ensemblData: EnsemblGeneStructure): ExonMapEntry[] {
  const transcript = ensemblData.canonical_transcript;
  if (!transcript?.exons || transcript.exons.length === 0) return [];

  const isReverse = ensemblData.strand === -1;

  // Sort exons by genomic order (5' to 3' in gene direction)
  const sortedExons = [...transcript.exons].sort((a, b) =>
    isReverse ? b.start - a.start : a.start - b.start
  );

  const exonMap: ExonMapEntry[] = [];
  let cumulativePosition = 0;

  for (const exon of sortedExons) {
    const exonLength = exon.end - exon.start;

    exonMap.push({
      genomicStart: isReverse ? exon.end : exon.start,
      genomicEnd: isReverse ? exon.start : exon.end,
      cumulativeStart: cumulativePosition,
      cumulativeEnd: cumulativePosition + exonLength,
    });

    cumulativePosition += exonLength;
  }

  return exonMap;
}

/**
 * Map protein position to genomic coordinate using exon-aware mapping
 * Only maps to exonic regions (NOT introns)
 */
function proteinToGenomic(
  proteinPosition: number,
  exonMap: ExonMapEntry[],
  isReverse: boolean,
  totalExonLength: number
): number | null {
  if (exonMap.length === 0 || totalExonLength === 0) return null;

  // Estimate protein length from total exon length (roughly 3 bp per amino acid)
  const estimatedProteinLength = Math.floor(totalExonLength / 3);

  // Convert protein position to cumulative exon position
  // Use fraction-based mapping: position in exons proportional to protein position
  const fraction = Math.min(proteinPosition / Math.max(estimatedProteinLength, 1), 1);
  const cumulativePosition = Math.floor(fraction * totalExonLength);

  // Find which exon contains this cumulative position
  for (const exon of exonMap) {
    if (cumulativePosition >= exon.cumulativeStart && cumulativePosition < exon.cumulativeEnd) {
      const offsetInExon = cumulativePosition - exon.cumulativeStart;
      if (isReverse) {
        // Reverse strand: genomic coordinates decrease
        return exon.genomicStart - offsetInExon;
      } else {
        // Forward strand: genomic coordinates increase
        return exon.genomicStart + offsetInExon;
      }
    }
  }

  // Position beyond exons - return last exon position
  const lastExon = exonMap[exonMap.length - 1];
  return isReverse ? lastExon.genomicEnd : lastExon.genomicEnd;
}

/**
 * Process variants with genomic positions for gene structure plot
 * Uses exon-aware mapping (variants only appear on exons, NOT introns)
 */
const genomicVariants = computed<GenomicVariant[]>(() => {
  if (!props.clinvarVariants || !ensemblRawData.value) return [];

  const isReverse = ensemblRawData.value.strand === -1;
  const exonMap = buildExonMap(ensemblRawData.value);

  if (exonMap.length === 0) {
    console.warn('[GenomicVisualizationTabs] No exons found for variant mapping');
    return [];
  }

  // Calculate total exon length
  const totalExonLength = exonMap.reduce((sum, e) => sum + (e.cumulativeEnd - e.cumulativeStart), 0);

  return props.clinvarVariants
    .map((v) => {
      const parsed = parseProteinPosition(v.hgvsp, v.hgvsc);
      if (!parsed) return null;

      // Map protein position to genomic coordinate using exon-aware mapping
      const genomicPosition = proteinToGenomic(parsed.position, exonMap, isReverse, totalExonLength);
      if (genomicPosition === null) return null;

      return {
        genomicPosition,
        proteinPosition: parsed.position,
        proteinHGVS: typeof v.hgvsp === 'string' ? v.hgvsp : 'N/A',
        codingHGVS: typeof v.hgvsc === 'string' ? v.hgvsc : 'N/A',
        classification: normalizeClassification(v.clinical_significance),
        goldStars: v.gold_stars,
        reviewStatus: v.review_status,
        clinvarId: String(v.clinvar_variation_id),
        variantId: v.variant_id,
        majorConsequence: v.major_consequence,
      } as GenomicVariant;
    })
    .filter((v): v is GenomicVariant => v !== null);
});

/**
 * Fetch Ensembl gene structure data (lazy loaded on tab activation)
 */
async function fetchGeneStructureData(): Promise<void> {
  if (!props.geneSymbol) return;
  if (geneStructureFetched.value) return; // Already fetched

  geneStructureLoading.value = true;
  geneStructureError.value = null;

  try {
    const apiBase = import.meta.env.VITE_API_URL;
    const response = await axios.get(
      `${apiBase}/api/external/ensembl/structure/${props.geneSymbol}`
    );

    if (response.data?.found === false) {
      geneStructureData.value = null;
      ensemblRawData.value = null;
    } else if (response.data?.error) {
      geneStructureError.value = response.data.message || 'Failed to load gene structure';
    } else {
      ensemblRawData.value = response.data as EnsemblGeneStructure;
      geneStructureData.value = processEnsemblResponse(ensemblRawData.value);
    }
  } catch (e: unknown) {
    if (axios.isAxiosError(e) && e.response?.status === 404) {
      geneStructureData.value = null;
      ensemblRawData.value = null;
    } else if (axios.isAxiosError(e) && e.response?.status === 503) {
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
watch(() => props.geneSymbol, () => {
  // Reset fetch state when gene changes
  geneStructureFetched.value = false;
  geneStructureData.value = null;
  ensemblRawData.value = null;

  // If gene structure tab was already visited for previous gene,
  // and we're still on it, refetch for new gene
  if (activeTabIndex.value === 1 && props.geneSymbol) {
    fetchGeneStructureData();
  }
});
</script>

<style scoped>
/* Visualization tabs styling */
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

/* Visualization panel for 3D structure - full height, no padding */
.visualization-panel-3d {
  height: 500px;  /* Fixed height per Phase 45 spec */
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

  .visualization-tabs :deep(.visualization-tab-item .nav-link) {
    padding: 5px 8px;
    font-size: 0.8rem;
  }

  .tab-title .badge {
    display: none;
  }
}
</style>
