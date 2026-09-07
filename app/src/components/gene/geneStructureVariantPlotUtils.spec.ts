import { describe, expect, it } from 'vitest';

import {
  aggregateVariantsByGenomicPosition,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  calculateDynamicStemStep,
  calculateSafeStemHeight,
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

describe('adaptive vertical headroom and stem height bounds', () => {
  const BASE_STEM = 18;
  const MAX_HEADROOM = 60;

  it('returns 0 dynamic step for a single variant or empty stack', () => {
    expect(calculateDynamicStemStep(MAX_HEADROOM, BASE_STEM, 0)).toBe(0);
    expect(calculateDynamicStemStep(MAX_HEADROOM, BASE_STEM, 1)).toBe(0);
  });

  it('caps dynamic step at maxStep when abundant headroom is available', () => {
    // With maxAllowed = 200 and base = 18, (200 - 18) / 3 = 60.67, should cap at 8
    expect(calculateDynamicStemStep(200, BASE_STEM, 4, 8)).toBe(8);
  });

  it('shrinks dynamic step proportionally under tight headroom constraints', () => {
    // Headroom = 32, base = 18 => 14 available. For 8 items (7 intervals), step = 14 / 7 = 2
    const step = calculateDynamicStemStep(32, BASE_STEM, 8, 8);
    expect(step).toBe(2);
  });

  it('never exceeds maxAllowedStemHeight even at maximum stack index', () => {
    const tightHeadroom = 46;
    for (let count = 1; count <= 20; count++) {
      for (let index = 0; index < count; index++) {
        const height = calculateSafeStemHeight(index, count, BASE_STEM, tightHeadroom, 8);
        expect(height).toBeGreaterThanOrEqual(BASE_STEM);
        expect(height).toBeLessThanOrEqual(tightHeadroom);
      }
    }
  });

  it('clamps out-of-range stack indices safely', () => {
    expect(calculateSafeStemHeight(-1, 5, BASE_STEM, MAX_HEADROOM)).toBe(BASE_STEM);
    const maxIdxHeight = calculateSafeStemHeight(100, 5, BASE_STEM, MAX_HEADROOM);
    expect(maxIdxHeight).toBeLessThanOrEqual(MAX_HEADROOM);
  });
});
