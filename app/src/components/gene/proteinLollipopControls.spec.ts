import { describe, expect, it } from 'vitest';

import type { LollipopFilterState, ProcessedVariant } from '@/types/protein';
import {
  EFFECT_TYPE_ORDER,
  countByClassification,
  countByEffectType,
  formatDomainType,
  selectAllEffectTypes,
  selectAllPathogenicity,
  selectOnlyEffectType,
  selectOnlyPathogenicity,
} from './proteinLollipopControls';

function makeVariant(overrides: Partial<ProcessedVariant>): ProcessedVariant {
  return {
    proteinPosition: 1,
    proteinHGVS: 'p.X1Y',
    codingHGVS: 'c.1A>T',
    classification: 'Pathogenic',
    goldStars: 0,
    reviewStatus: '',
    clinvarId: '',
    variantId: 'v1',
    majorConsequence: 'missense_variant',
    isSpliceVariant: false,
    inGnomad: false,
    ...overrides,
  } as ProcessedVariant;
}

function makeFilterState(): LollipopFilterState {
  return {
    pathogenic: true,
    likelyPathogenic: true,
    vus: true,
    likelyBenign: true,
    benign: true,
    effectFilters: {
      missense: true,
      frameshift: true,
      stop_gained: true,
      splice: true,
      inframe_indel: true,
      synonymous: true,
      other: true,
    },
    coloringMode: 'acmg',
  } as LollipopFilterState;
}

describe('proteinLollipopControls', () => {
  it('formatDomainType maps known codes and title-cases unknown ones', () => {
    expect(formatDomainType('ZN_FING')).toBe('Zinc finger');
    expect(formatDomainType('DNA_BIND')).toBe('DNA binding');
    expect(formatDomainType('CUSTOM_THING')).toBe('Custom Thing');
  });

  it('countByClassification tallies classifications', () => {
    const counts = countByClassification([
      makeVariant({ classification: 'Pathogenic' }),
      makeVariant({ classification: 'Pathogenic' }),
      makeVariant({ classification: 'Benign' }),
    ]);
    expect(counts).toEqual({ Pathogenic: 2, Benign: 1 });
  });

  it('countByEffectType normalizes consequences into effect buckets', () => {
    const counts = countByEffectType([
      makeVariant({ majorConsequence: 'missense_variant' }),
      makeVariant({ majorConsequence: 'frameshift_variant' }),
      makeVariant({ majorConsequence: 'missense_variant' }),
    ]);
    expect(counts.missense).toBe(2);
    expect(counts.frameshift).toBe(1);
    expect(counts.synonymous).toBe(0);
  });

  it('selectOnlyPathogenicity isolates one class', () => {
    const fs = makeFilterState();
    selectOnlyPathogenicity(fs, 'vus');
    expect(fs.pathogenic).toBe(false);
    expect(fs.vus).toBe(true);
    expect(fs.benign).toBe(false);
  });

  it('selectAllPathogenicity re-enables every class', () => {
    const fs = makeFilterState();
    selectOnlyPathogenicity(fs, 'vus');
    selectAllPathogenicity(fs);
    expect([fs.pathogenic, fs.likelyPathogenic, fs.vus, fs.likelyBenign, fs.benign]).toEqual([
      true,
      true,
      true,
      true,
      true,
    ]);
  });

  it('selectOnlyEffectType / selectAllEffectTypes toggle the effect filters', () => {
    const fs = makeFilterState();
    selectOnlyEffectType(fs, 'splice');
    expect(EFFECT_TYPE_ORDER.filter((et) => fs.effectFilters[et])).toEqual(['splice']);

    selectAllEffectTypes(fs);
    expect(EFFECT_TYPE_ORDER.every((et) => fs.effectFilters[et])).toBe(true);
  });
});
