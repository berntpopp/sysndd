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
import { isClassificationVisible } from '@/composables/d3-lollipop/lollipop-helpers';

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

describe('conflicting and other pathogenicity filters (#607)', () => {
  function makeLollipopState(
    overrides: Partial<LollipopFilterState> = {}
  ): LollipopFilterState {
    return {
      pathogenic: true,
      likelyPathogenic: true,
      vus: true,
      likelyBenign: true,
      benign: true,
      conflicting: true,
      other: true,
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
      ...overrides,
    };
  }

  it('hides Conflicting variants when the conflicting filter is off', () => {
    expect(isClassificationVisible('Conflicting', makeLollipopState())).toBe(true);
    expect(
      isClassificationVisible('Conflicting', makeLollipopState({ conflicting: false }))
    ).toBe(false);
  });

  it('does not hide Conflicting variants when the pathogenic filter is off', () => {
    expect(isClassificationVisible('Conflicting', makeLollipopState({ pathogenic: false }))).toBe(
      true
    );
  });

  it('routes "other" through its own filter key instead of showing it unconditionally', () => {
    expect(isClassificationVisible('other', makeLollipopState())).toBe(true);
    expect(isClassificationVisible('other', makeLollipopState({ other: false }))).toBe(false);
  });

  it('counts Conflicting variants under their own key', () => {
    const counts = countByClassification([
      { classification: 'Conflicting' },
      { classification: 'Conflicting' },
      { classification: 'Pathogenic' },
    ] as ProcessedVariant[]);
    expect(counts['Conflicting']).toBe(2);
    expect(counts['Pathogenic']).toBe(1);
  });

  it('covers conflicting and other in selectOnly and selectAll', () => {
    const state = makeLollipopState();

    selectOnlyPathogenicity(state, 'conflicting');
    expect(state.conflicting).toBe(true);
    expect(state.pathogenic).toBe(false);
    expect(state.other).toBe(false);

    selectAllPathogenicity(state);
    expect(state.conflicting).toBe(true);
    expect(state.other).toBe(true);
    expect(state.benign).toBe(true);
  });
});
