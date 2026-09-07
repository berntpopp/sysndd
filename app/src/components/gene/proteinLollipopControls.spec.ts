import { describe, expect, it } from 'vitest';

import type { LollipopFilterState, ProcessedVariant } from '@/types/protein';
import {
  EFFECT_TYPE_ORDER,
  NOT_SPECIFIED_CONDITION,
  countByClassification,
  countByCondition,
  countByEffectType,
  formatDomainType,
  isConditionVisible,
  selectAllConditions,
  selectAllEffectTypes,
  selectAllPathogenicity,
  selectOnlyCondition,
  selectOnlyEffectType,
  selectOnlyPathogenicity,
  toggleCondition,
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

function makeFilterState(
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

describe('condition filtering (ClinVar disease phenotypes)', () => {
  it('countByCondition tallies conditions and sorts by count descending', () => {
    const variants = [
      makeVariant({ conditions: ['Noonan syndrome 1', 'LEOPARD syndrome 1'] }),
      makeVariant({ conditions: ['Noonan syndrome 1'] }),
      makeVariant({ conditions: ['Metachondromatosis'] }),
      makeVariant({ conditions: [] }),
    ];

    const counts = countByCondition(variants);
    expect(counts).toEqual([
      { condition: 'Noonan syndrome 1', count: 2 },
      { condition: 'LEOPARD syndrome 1', count: 1 },
      { condition: 'Metachondromatosis', count: 1 },
      { condition: NOT_SPECIFIED_CONDITION, count: 1 },
    ]);
  });

  it('isConditionVisible returns true when selectedConditions is null, undefined, or empty', () => {
    const state = makeFilterState({ selectedConditions: null });

    expect(isConditionVisible(['Noonan syndrome 1'], state)).toBe(true);
    expect(isConditionVisible([], state)).toBe(true);
    expect(isConditionVisible(undefined, state)).toBe(true);

    state.selectedConditions = [];
    expect(isConditionVisible(['Noonan syndrome 1'], state)).toBe(true);
  });

  it('isConditionVisible filters variants according to selectedConditions', () => {
    const state = makeFilterState({ selectedConditions: ['Noonan syndrome 1'] });

    // Variant with matching condition -> visible
    expect(isConditionVisible(['Noonan syndrome 1', 'LEOPARD syndrome 1'], state)).toBe(true);

    // Variant without matching condition -> hidden
    expect(isConditionVisible(['Metachondromatosis'], state)).toBe(false);

    // Variant with no condition matches NOT_SPECIFIED_CONDITION
    expect(isConditionVisible([], state)).toBe(false);
    expect(isConditionVisible(undefined, state)).toBe(false);

    state.selectedConditions = [NOT_SPECIFIED_CONDITION];
    expect(isConditionVisible([], state)).toBe(true);
    expect(isConditionVisible(undefined, state)).toBe(true);
    expect(isConditionVisible(['Noonan syndrome 1'], state)).toBe(false);
  });

  it('toggleCondition handles selecting and deselecting conditions', () => {
    const allConds = ['Noonan syndrome 1', 'LEOPARD syndrome 1', 'Metachondromatosis'];
    const state = makeFilterState();

    // Initial state: selectedConditions is undefined (all active)
    // Toggling 'Metachondromatosis' turns off Metachondromatosis, leaving other two selected
    toggleCondition(state, 'Metachondromatosis', allConds);
    expect(state.selectedConditions).toEqual(['Noonan syndrome 1', 'LEOPARD syndrome 1']);

    // Toggling 'Metachondromatosis' again re-adds it, reaching allConds length -> resets to null
    toggleCondition(state, 'Metachondromatosis', allConds);
    expect(state.selectedConditions).toBeNull();
  });

  it('selectOnlyCondition and selectAllConditions manage single and all selection', () => {
    const state = makeFilterState();

    selectOnlyCondition(state, 'Noonan syndrome 1');
    expect(state.selectedConditions).toEqual(['Noonan syndrome 1']);

    selectAllConditions(state);
    expect(state.selectedConditions).toBeNull();
  });
});

