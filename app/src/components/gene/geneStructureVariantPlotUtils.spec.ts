import { describe, expect, it } from 'vitest';

import {
  aggregateVariantsByGenomicPosition,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  determineRenderingMode,
  isGeneStructureVariantVisible,
} from './geneStructureVariantPlotUtils';

const variants = [
  {
    genomicPosition: 1000,
    classification: 'Pathogenic',
    majorConsequence: 'missense_variant',
  },
  {
    genomicPosition: 1040,
    classification: 'Likely pathogenic',
    majorConsequence: 'frameshift_variant',
  },
  {
    genomicPosition: 5200,
    classification: 'Benign',
    majorConsequence: 'synonymous_variant',
  },
];

describe('geneStructureVariantPlotUtils', () => {
  it('aggregates variants into genomic bins and preserves classification counts', () => {
    expect(aggregateVariantsByGenomicPosition(variants, 10000)).toEqual([
      {
        genomicPosition: 1020,
        count: 2,
        dominantClassification: 'Pathogenic',
        classifications: {
          Pathogenic: 1,
          'Likely pathogenic': 1,
        },
        variants: [variants[0], variants[1]],
      },
      {
        genomicPosition: 5200,
        count: 1,
        dominantClassification: 'Benign',
        classifications: {
          Benign: 1,
        },
        variants: [variants[2]],
      },
    ]);
  });

  it('switches rendering mode only above the aggregation threshold', () => {
    expect(determineRenderingMode(500)).toBe('individual');
    expect(determineRenderingMode(501)).toBe('aggregated');
  });

  it('calculates deterministic radius and opacity within visual bounds', () => {
    expect(calculateAggregatedRadius(1, 4)).toBe(7.5);
    expect(calculateAggregatedRadius(4, 4)).toBe(12);
    expect(calculateDynamicOpacity(1)).toBe(0.95);
    expect(calculateDynamicOpacity(1000)).toBe(0.52);
  });

  it('requires both pathogenicity and effect filters to be visible', () => {
    expect(
      isGeneStructureVariantVisible(variants[0], {
        pathogenicity: {
          Pathogenic: true,
          'Likely pathogenic': false,
          'Uncertain significance': false,
          'Likely benign': false,
          Benign: false,
        },
        effectFilters: {
          missense: true,
          frameshift: false,
          stop_gained: false,
          splice: false,
          inframe_indel: false,
          synonymous: false,
          other: false,
        },
      })
    ).toBe(true);

    expect(
      isGeneStructureVariantVisible(variants[0], {
        pathogenicity: {
          Pathogenic: true,
          'Likely pathogenic': false,
          'Uncertain significance': false,
          'Likely benign': false,
          Benign: false,
        },
        effectFilters: {
          missense: false,
          frameshift: false,
          stop_gained: false,
          splice: false,
          inframe_indel: false,
          synonymous: false,
          other: false,
        },
      })
    ).toBe(false);

    expect(
      isGeneStructureVariantVisible(
        { genomicPosition: 1200, classification: 'Pathogenic', majorConsequence: null },
        {
          pathogenicity: {
            Pathogenic: true,
            'Likely pathogenic': false,
            'Uncertain significance': false,
            'Likely benign': false,
            Benign: false,
          },
          effectFilters: {
            missense: false,
            frameshift: false,
            stop_gained: false,
            splice: false,
            inframe_indel: false,
            synonymous: false,
            other: true,
          },
        }
      )
    ).toBe(true);
  });
});

describe('conflicting visibility and aggregation (#607)', () => {
  const effectFilters = {
    missense: true,
    frameshift: true,
    stop_gained: true,
    splice: true,
    inframe_indel: true,
    synonymous: true,
    other: true,
  };

  const conflicting = {
    genomicPosition: 2000,
    classification: 'Conflicting',
    majorConsequence: 'missense_variant',
  };

  it('hides Conflicting variants when the Conflicting filter is off', () => {
    expect(
      isGeneStructureVariantVisible(conflicting, {
        pathogenicity: {
          Pathogenic: true,
          'Likely pathogenic': true,
          Conflicting: false,
          other: false,
        },
        effectFilters,
      })
    ).toBe(false);
  });

  it('shows Conflicting variants when the Conflicting filter is on, even with Pathogenic off', () => {
    expect(
      isGeneStructureVariantVisible(conflicting, {
        pathogenicity: { Pathogenic: false, Conflicting: true, other: false },
        effectFilters,
      })
    ).toBe(true);
  });

  it('aggregates Conflicting under its own classification key', () => {
    const result = aggregateVariantsByGenomicPosition(
      [conflicting, { ...conflicting, genomicPosition: 2010 }],
      100000
    );
    expect(result[0].classifications.Conflicting).toBe(2);
    expect(result[0].dominantClassification).toBe('Conflicting');
  });
});
