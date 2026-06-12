/**
 * genomicVisualizationData.ts
 *
 * Pure data-transform helpers for GenomicVisualizationTabs.vue:
 *  - protein lollipop data (UniProt domains + ClinVar variants)
 *  - exon-aware protein-to-genomic mapping for the gene-structure plot
 *
 * Extracted from GenomicVisualizationTabs.vue so the component stays a thin
 * tab/loading shell. These functions are framework-agnostic and unit-testable.
 */

import type {
  ProteinPlotData,
  ProcessedVariant,
  ProteinDomain,
} from '@/types/protein';
import { normalizeClassification, parseProteinPosition } from '@/types/protein';
import type { EnsemblGeneStructure } from '@/types/ensembl';
import type { ClinVarVariant } from '@/types/external';

/**
 * UniProt domain feature from the API response
 */
export interface UniProtDomainFeature {
  type: string;
  description?: string;
  begin: number | string;
  end: number | string;
}

/**
 * UniProt API response structure
 */
export interface UniProtData {
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

/**
 * Cumulative exon coordinate map entry.
 */
export interface ExonMapEntry {
  genomicStart: number;
  genomicEnd: number;
  cumulativeStart: number; // Cumulative base position start
  cumulativeEnd: number; // Cumulative base position end
}

/**
 * Build the protein lollipop plot data from UniProt + ClinVar inputs.
 *
 * Returns null when neither usable UniProt nor usable ClinVar data is present.
 */
export function buildProteinPlotData(args: {
  uniprotData: UniProtData | null;
  uniprotError: string | null;
  clinvarVariants: ClinVarVariant[] | null;
  clinvarError: string | null;
}): ProteinPlotData | null {
  const { uniprotData, uniprotError, clinvarVariants, clinvarError } = args;
  const hasUniprot = uniprotData && !uniprotError;
  const hasClinvar = clinvarVariants && !clinvarError;

  if (!hasUniprot && !hasClinvar) return null;

  // Process domains from UniProt response
  const domains: ProteinDomain[] = hasUniprot
    ? (uniprotData?.domains || []).map((d) => ({
        type: d.type,
        description: d.description || '',
        begin: Number(d.begin),
        end: Number(d.end),
      }))
    : [];

  // Process variants from ClinVar response
  const variants: ProcessedVariant[] = hasClinvar
    ? (clinvarVariants || [])
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
  const uniprotLength = hasUniprot ? Number(uniprotData?.protein_length) : 0;
  const maxVariantPosition =
    variants.length > 0 ? Math.max(...variants.map((v) => v.proteinPosition)) : 0;
  const proteinLength = Math.max(uniprotLength, maxVariantPosition);
  const proteinName = hasUniprot ? uniprotData?.protein_name || '' : '';
  const accession = hasUniprot ? uniprotData?.accession || '' : '';

  return {
    proteinLength,
    proteinName,
    accession,
    domains,
    variants,
  };
}

/**
 * Build exon coordinate map from Ensembl data.
 * Maps cumulative exon positions to genomic coordinates (accounting for strand).
 *
 * Since we don't have CDS boundaries, we map across all exons. This ensures
 * variants only appear on exons, not introns.
 */
export function buildExonMap(ensemblData: EnsemblGeneStructure): ExonMapEntry[] {
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
 * Map a protein position to a genomic coordinate using exon-aware mapping.
 * Only maps to exonic regions (NOT introns).
 */
export function proteinToGenomic(
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
 * Build genomic variants for the gene-structure plot from ClinVar + Ensembl
 * data using exon-aware mapping. Variants only appear on exons (NOT introns).
 */
export function buildGenomicVariants(
  clinvarVariants: ClinVarVariant[] | null,
  ensemblRawData: EnsemblGeneStructure | null
): GenomicVariant[] {
  if (!clinvarVariants || !ensemblRawData) return [];

  const isReverse = ensemblRawData.strand === -1;
  const exonMap = buildExonMap(ensemblRawData);

  if (exonMap.length === 0) {
    console.warn('[GenomicVisualizationTabs] No exons found for variant mapping');
    return [];
  }

  // Calculate total exon length
  const totalExonLength = exonMap.reduce(
    (sum, e) => sum + (e.cumulativeEnd - e.cumulativeStart),
    0
  );

  return clinvarVariants
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
}
