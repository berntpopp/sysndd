import { describe, expect, it } from 'vitest';

import type { EnsemblGeneStructure } from '@/types/ensembl';
import { buildExonMap, proteinToGenomic } from './genomicVisualizationData';

function makeEnsembl(
  strand: number,
  exons: Array<{ id: string; start: number; end: number }>
): EnsemblGeneStructure {
  return {
    source: 'ensembl',
    gene_symbol: 'TEST',
    gene_id: 'ENSG00000000001',
    chromosome: '1',
    start: 1000,
    end: 4000,
    strand,
    canonical_transcript: {
      transcript_id: 'ENST00000000001',
      start: 1000,
      end: 4000,
      biotype: 'protein_coding',
      exons,
    },
  };
}

describe('genomicVisualizationData', () => {
  it('buildExonMap returns [] when no exons are present', () => {
    expect(buildExonMap(makeEnsembl(1, []))).toEqual([]);
  });

  it('buildExonMap maps forward-strand exons in genomic order with cumulative offsets', () => {
    const exonMap = buildExonMap(
      makeEnsembl(1, [
        { id: 'e2', start: 3000, end: 3100 },
        { id: 'e1', start: 1000, end: 1100 },
      ])
    );

    expect(exonMap).toEqual([
      { genomicStart: 1000, genomicEnd: 1100, cumulativeStart: 0, cumulativeEnd: 100 },
      { genomicStart: 3000, genomicEnd: 3100, cumulativeStart: 100, cumulativeEnd: 200 },
    ]);
  });

  it('buildExonMap orients reverse-strand exons high-to-low', () => {
    const exonMap = buildExonMap(
      makeEnsembl(-1, [
        { id: 'e1', start: 1000, end: 1100 },
        { id: 'e2', start: 3000, end: 3100 },
      ])
    );

    expect(exonMap).toEqual([
      { genomicStart: 3100, genomicEnd: 3000, cumulativeStart: 0, cumulativeEnd: 100 },
      { genomicStart: 1100, genomicEnd: 1000, cumulativeStart: 100, cumulativeEnd: 200 },
    ]);
  });

  it('proteinToGenomic returns null for an empty exon map', () => {
    expect(proteinToGenomic(10, [], false, 0)).toBeNull();
  });

  it('proteinToGenomic maps a forward-strand position into the first exon', () => {
    const exonMap = buildExonMap(
      makeEnsembl(1, [
        { id: 'e1', start: 1000, end: 1100 },
        { id: 'e2', start: 3000, end: 3100 },
      ])
    );
    const totalExonLength = 200;
    // estimatedProteinLength = floor(200/3) = 66; fraction(1/66) -> cumulative 3 -> first exon
    expect(proteinToGenomic(1, exonMap, false, totalExonLength)).toBe(1003);
  });

  it('proteinToGenomic decreases coordinates on the reverse strand', () => {
    const exonMap = buildExonMap(
      makeEnsembl(-1, [
        { id: 'e1', start: 1000, end: 1100 },
        { id: 'e2', start: 3000, end: 3100 },
      ])
    );
    const totalExonLength = 200;
    // first bin is genomicStart 3100, offset 3 -> 3097
    expect(proteinToGenomic(1, exonMap, true, totalExonLength)).toBe(3097);
  });
});
