// app/src/types/ensembl.ts

/**
 * TypeScript type definitions for Ensembl gene structure data
 *
 * Defines interfaces for the Ensembl REST API response from the backend proxy
 * (api/functions/external-proxy-ensembl.R) and helper functions for processing
 * gene structure data for D3.js visualization.
 *
 * The backend proxy fetches gene structure information including exons,
 * transcript coordinates, and strand direction. These types bridge the
 * backend response to the frontend rendering pipeline.
 */

/**
 * Individual exon within a transcript
 * Maps from backend `external-proxy-ensembl.R` response exon objects
 */
export interface EnsemblExon {
  /** Ensembl exon ID (e.g., "ENSE00001234567") */
  id: string;
  /** Genomic start coordinate (GRCh38) */
  start: number;
  /** Genomic end coordinate (GRCh38) */
  end: number;
}

/**
 * Transcript information including exons
 * Maps from canonical_transcript in backend response
 */
export interface EnsemblTranscript {
  /** Ensembl transcript ID (e.g., "ENST00000302278") */
  transcript_id: string;
  /** Transcript genomic start coordinate */
  start: number;
  /** Transcript genomic end coordinate */
  end: number;
  /** Transcript biotype (e.g., "protein_coding") */
  biotype: string;
  /** Array of exons in this transcript */
  exons: EnsemblExon[];
}

/**
 * Complete gene structure response from Ensembl backend proxy
 * Shape matches api/functions/external-proxy-ensembl.R return value
 */
export interface EnsemblGeneStructure {
  /** Data source identifier (always "ensembl") */
  source: string;
  /** Gene symbol (e.g., "BRCA1") */
  gene_symbol: string;
  /** Ensembl gene ID (e.g., "ENSG00000012048") */
  gene_id: string;
  /** Chromosome (e.g., "17") */
  chromosome: string;
  /** Gene genomic start coordinate */
  start: number;
  /** Gene genomic end coordinate */
  end: number;
  /** Strand direction (1 for forward/+, -1 for reverse/-) */
  strand: number;
  /** Canonical transcript (main isoform) with exons */
  canonical_transcript: EnsemblTranscript;
}

/**
 * Exon classification for rendering
 * Distinguishes coding exons from UTR regions
 */
export type ExonType = 'coding' | '5_utr' | '3_utr';

/**
 * Processed exon with type classification
 * Ready for visualization rendering
 */
export interface ClassifiedExon {
  /** Ensembl exon ID */
  id: string;
  /** Genomic start coordinate */
  start: number;
  /** Genomic end coordinate */
  end: number;
  /** Exon type (coding vs UTR) */
  type: ExonType;
  /** 1-based exon number in genomic order (left-to-right, regardless of strand) */
  exonNumber: number;
}

/**
 * Intron calculated from gap between consecutive exons
 */
export interface Intron {
  /** Intron start coordinate (previous exon end) */
  start: number;
  /** Intron end coordinate (next exon start) */
  end: number;
}

/**
 * Fully processed gene structure data ready for D3 rendering
 * All coordinates and classifications computed
 */
export interface GeneStructureRenderData {
  /** Gene symbol for display */
  geneSymbol: string;
  /** Transcript ID for reference */
  transcriptId: string;
  /** Chromosome identifier */
  chromosome: string;
  /** Gene start coordinate */
  geneStart: number;
  /** Gene end coordinate */
  geneEnd: number;
  /** Strand direction (converted to +/- string) */
  strand: '+' | '-';
  /** Classified exons with types */
  exons: ClassifiedExon[];
  /** Calculated introns */
  introns: Intron[];
  /** Total number of exons */
  exonCount: number;
  /** Gene length in base pairs */
  geneLength: number;
}

/**
 * Classify exons as coding or UTR based on CDS boundaries
 *
 * @param exons - Array of exons from Ensembl API
 * @param strand - Strand direction (1 for +, -1 for -)
 * @param cdsStart - Optional CDS start coordinate (coding sequence start)
 * @param cdsEnd - Optional CDS end coordinate (coding sequence end)
 * @returns Array of classified exons with type and genomic order number
 *
 * Classification logic:
 * - If cdsStart/cdsEnd provided: classify relative to CDS boundaries
 *   - On + strand: exons before CDS are 5' UTR, after CDS are 3' UTR
 *   - On - strand: exons before CDS are 3' UTR, after CDS are 5' UTR
 *   - Exons overlapping CDS are classified as coding
 * - If CDS not provided: all exons classified as 'coding' (safe fallback)
 * - Exon numbers are assigned 1-based in genomic order (left-to-right ascending
 *   coordinates regardless of strand)
 */
export function classifyExons(
  exons: EnsemblExon[],
  strand: number,
  cdsStart?: number,
  cdsEnd?: number
): ClassifiedExon[] {
  // Sort exons by start coordinate (genomic order, left-to-right)
  const sortedExons = [...exons].sort((a, b) => a.start - b.start);

  // If no CDS coordinates provided, classify all as coding
  if (cdsStart === undefined || cdsEnd === undefined) {
    return sortedExons.map((exon, index) => ({
      id: exon.id,
      start: exon.start,
      end: exon.end,
      type: 'coding' as ExonType,
      exonNumber: index + 1,
    }));
  }

  // Classify based on CDS boundaries and strand
  return sortedExons.map((exon, index) => {
    let type: ExonType = 'coding';

    // Check if exon is entirely before CDS
    if (exon.end < cdsStart) {
      // On + strand: before CDS = 5' UTR
      // On - strand: before CDS = 3' UTR (genes run 3'->5' on reverse strand)
      type = strand === 1 ? '5_utr' : '3_utr';
    }
    // Check if exon is entirely after CDS
    else if (exon.start > cdsEnd) {
      // On + strand: after CDS = 3' UTR
      // On - strand: after CDS = 5' UTR
      type = strand === 1 ? '3_utr' : '5_utr';
    }
    // Otherwise exon overlaps CDS boundaries -> coding
    // (Simplification: we don't split exons that partially overlap CDS)
    else {
      type = 'coding';
    }

    return {
      id: exon.id,
      start: exon.start,
      end: exon.end,
      type,
      exonNumber: index + 1,
    };
  });
}

/**
 * Calculate introns from gaps between consecutive exons
 *
 * @param exons - Array of classified exons (must be sorted by start coordinate)
 * @returns Array of introns (gaps between exons)
 *
 * Assumes exons are sorted in genomic order (ascending start coordinate).
 * For each consecutive pair of exons, creates an intron spanning the gap.
 * Skips gaps <= 0 (which would indicate overlapping exons, an error condition).
 */
export function calculateIntrons(exons: ClassifiedExon[]): Intron[] {
  const introns: Intron[] = [];

  for (let i = 0; i < exons.length - 1; i++) {
    const currentExon = exons[i];
    const nextExon = exons[i + 1];

    // Calculate gap between current exon end and next exon start
    const gap = nextExon.start - currentExon.end;

    // Only create intron if there's a positive gap
    if (gap > 0) {
      introns.push({
        start: currentExon.end,
        end: nextExon.start,
      });
    }
  }

  return introns;
}

/**
 * Format genomic coordinate with abbreviated units
 *
 * @param value - Coordinate value in base pairs
 * @returns Formatted string with Mb, kb, or bp units
 *
 * Examples:
 * - 12,350,000 -> "12.35 Mb"
 * - 45,600 -> "45.6 kb"
 * - 456 -> "456 bp"
 */
export function formatGenomicCoordinate(value: number): string {
  if (value >= 1_000_000) {
    // Megabases (Mb)
    const mb = value / 1_000_000;
    return `${mb.toFixed(2)} Mb`;
  } else if (value >= 1_000) {
    // Kilobases (kb)
    const kb = value / 1_000;
    return `${kb.toFixed(1)} kb`;
  } else {
    // Base pairs (bp)
    return `${value} bp`;
  }
}

/**
 * Process Ensembl gene structure response into render-ready format
 *
 * @param data - Raw Ensembl gene structure from backend proxy
 * @param cdsStart - Optional CDS start coordinate for UTR classification
 * @param cdsEnd - Optional CDS end coordinate for UTR classification
 * @returns Fully processed data ready for D3 visualization
 *
 * Orchestrates the full processing pipeline:
 * 1. Classify exons (with optional CDS boundaries)
 * 2. Calculate introns from exon gaps
 * 3. Convert strand from 1/-1 to '+'/'-' string
 * 4. Compute derived metrics (gene length, exon count)
 * 5. Return structured data for D3 rendering
 */
export function processEnsemblResponse(
  data: EnsemblGeneStructure,
  cdsStart?: number,
  cdsEnd?: number
): GeneStructureRenderData {
  // Classify exons
  const classifiedExons = classifyExons(
    data.canonical_transcript.exons,
    data.strand,
    cdsStart,
    cdsEnd
  );

  // Calculate introns
  const introns = calculateIntrons(classifiedExons);

  // Convert strand to string format
  const strand: '+' | '-' = data.strand === 1 ? '+' : '-';

  // Compute gene length
  const geneLength = data.end - data.start;

  return {
    geneSymbol: data.gene_symbol,
    transcriptId: data.canonical_transcript.transcript_id,
    chromosome: data.chromosome,
    geneStart: data.start,
    geneEnd: data.end,
    strand,
    exons: classifiedExons,
    introns,
    exonCount: classifiedExons.length,
    geneLength,
  };
}
