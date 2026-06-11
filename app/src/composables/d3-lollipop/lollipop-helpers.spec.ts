import { describe, expect, it } from 'vitest';
import { normalizeEffectType } from '@/types/protein';
import type { LollipopFilterState, PathogenicityClass } from '@/types/protein';
import {
  AGGREGATION_THRESHOLD,
  MIN_MARKER_RADIUS,
  MAX_MARKER_RADIUS,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  determineRenderingMode,
  isClassificationVisible,
  isEffectTypeVisible,
} from './lollipop-helpers';

function makeFilterState(overrides: Partial<LollipopFilterState> = {}): LollipopFilterState {
  return {
    pathogenic: true,
    likelyPathogenic: false,
    vus: true,
    likelyBenign: false,
    benign: true,
    ...overrides,
  } as LollipopFilterState;
}

describe('lollipop-helpers', () => {
  it('isClassificationVisible maps classes to filter flags and defaults unknown to visible', () => {
    const fs = makeFilterState();
    expect(isClassificationVisible('Pathogenic', fs)).toBe(true);
    expect(isClassificationVisible('Likely pathogenic', fs)).toBe(false);
    expect(isClassificationVisible('Uncertain significance', fs)).toBe(true);
    expect(isClassificationVisible('Likely benign', fs)).toBe(false);
    expect(isClassificationVisible('Benign', fs)).toBe(true);
    expect(isClassificationVisible('other' as PathogenicityClass, fs)).toBe(true);
  });

  it('isEffectTypeVisible shows all when effectFilters is missing', () => {
    expect(isEffectTypeVisible('missense_variant', makeFilterState())).toBe(true);
  });

  it('isEffectTypeVisible respects the normalized effect-type flag', () => {
    const effectType = normalizeEffectType('missense_variant');
    const fs = makeFilterState({
      effectFilters: { [effectType]: false } as LollipopFilterState['effectFilters'],
    });
    expect(isEffectTypeVisible('missense_variant', fs)).toBe(false);
  });

  it('calculateDynamicOpacity combines density and zoom and clamps to bounds', () => {
    expect(calculateDynamicOpacity(1, 1)).toBeCloseTo(0.7, 5);
    expect(calculateDynamicOpacity(10000, 1)).toBeCloseTo(0.25, 5);
    expect(calculateDynamicOpacity(1, 0)).toBeCloseTo(0.95, 5);
  });

  it('calculateAggregatedRadius scales by sqrt of count share within bounds', () => {
    expect(calculateAggregatedRadius(9, 9)).toBeCloseTo(MAX_MARKER_RADIUS, 5);
    expect(calculateAggregatedRadius(0, 9)).toBeCloseTo(MIN_MARKER_RADIUS, 5);
    // sqrt scaling: quarter share -> half range (linear would give quarter range)
    expect(calculateAggregatedRadius(1, 4)).toBeCloseTo(
      MIN_MARKER_RADIUS + 0.5 * (MAX_MARKER_RADIUS - MIN_MARKER_RADIUS),
      5
    );
  });

  it('determineRenderingMode switches at the aggregation threshold', () => {
    expect(determineRenderingMode(AGGREGATION_THRESHOLD)).toBe('individual');
    expect(determineRenderingMode(AGGREGATION_THRESHOLD + 1)).toBe('aggregated');
  });
});
