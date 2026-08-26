// Tests for the computed syndromicity presenter (#630).
//
// The block is `curated_derived_analysis`, not model output, so these lock the
// two things a reader must not be misled about: what the label means, and that
// the fraction (with its interval) is the primary reported quantity.

import { describe, it, expect } from 'vitest';
import {
  hasSyndromicity,
  syndromicityLabel,
  syndromicityVariant,
  syndromicitySubtitle,
  topSystems,
  systemLabel,
  type SyndromicityBlock,
} from './syndromicityPresenter';

const block: SyndromicityBlock = {
  rule_version: '1.0',
  entities: 1053,
  evaluable: 1053,
  syndromic: 693,
  no_recorded_extraneurological_involvement: 360,
  insufficient_annotation: 0,
  fraction_syndromic: 0.658,
  fraction_syndromic_ci95: { lower: 0.629, upper: 0.686 },
  median_systems: 1,
  system_frequencies: { craniofacial: 271, eye: 208, growth: 190, skeletal: 105 },
  cluster_call: 'mixed',
};

describe('hasSyndromicity', () => {
  it('is false for a missing block', () => {
    expect(hasSyndromicity(null)).toBe(false);
    expect(hasSyndromicity(undefined)).toBe(false);
    expect(hasSyndromicity({})).toBe(false);
  });

  it('is true once a cluster_call is present', () => {
    expect(hasSyndromicity(block)).toBe(true);
  });
});

describe('syndromicityLabel', () => {
  it('labels each computed call', () => {
    expect(syndromicityLabel({ cluster_call: 'predominantly_syndromic' })).toBe(
      'Predominantly syndromic'
    );
    expect(syndromicityLabel({ cluster_call: 'predominantly_no_recorded_involvement' })).toBe(
      'No recorded involvement in most'
    );
    expect(syndromicityLabel({ cluster_call: 'mixed' })).toBe('Mixed');
    expect(syndromicityLabel({ cluster_call: 'insufficient_annotation' })).toBe(
      'Insufficient annotation'
    );
  });

  it('falls back to the raw value rather than inventing one', () => {
    expect(syndromicityLabel({ cluster_call: 'something_new' })).toBe('something_new');
    expect(syndromicityLabel(null)).toBe('Not computed');
  });
});

describe('syndromicityVariant', () => {
  it('never reuses the retired AI badge "light" variant for a real value', () => {
    for (const call of ['predominantly_syndromic', 'predominantly_no_recorded_involvement', 'mixed']) {
      expect(syndromicityVariant({ cluster_call: call })).not.toBe('light');
    }
  });
});

describe('syndromicitySubtitle', () => {
  it('leads with the fraction and its interval, not the label', () => {
    expect(syndromicitySubtitle(block)).toBe('65.8% (95% CI 62.9%–68.6%) of 1053 entities');
  });

  it('omits the interval when it is absent rather than rendering undefined', () => {
    expect(syndromicitySubtitle({ fraction_syndromic: 0.5, evaluable: 10 })).toBe(
      '50.0% of 10 entities'
    );
  });

  it('is empty when there is nothing to report', () => {
    expect(syndromicitySubtitle(null)).toBe('');
    expect(syndromicitySubtitle({})).toBe('');
  });
});

describe('plumber array unwrapping', () => {
  it('unwraps length-1 arrays that plumber does not auto-unbox', () => {
    const wrapped = {
      cluster_call: ['mixed'],
      fraction_syndromic: [0.658],
      evaluable: [1053],
      fraction_syndromic_ci95: { lower: [0.629], upper: [0.686] },
    } as unknown as SyndromicityBlock;
    expect(syndromicityLabel(wrapped)).toBe('Mixed');
    expect(syndromicitySubtitle(wrapped)).toBe('65.8% (95% CI 62.9%–68.6%) of 1053 entities');
  });
});

describe('topSystems', () => {
  it('orders most-frequent-first and caps the list', () => {
    expect(topSystems(block, 2)).toEqual([
      { system: 'craniofacial', count: 271 },
      { system: 'eye', count: 208 },
    ]);
  });

  it('is empty rather than throwing when frequencies are absent', () => {
    expect(topSystems({})).toEqual([]);
    expect(topSystems(null)).toEqual([]);
  });
});

describe('systemLabel', () => {
  it('renders readable organ-system names', () => {
    expect(systemLabel('renal_urogenital')).toBe('Renal / urogenital');
    expect(systemLabel('ear_hearing')).toBe('Hearing');
  });

  it('passes an unmapped system through unchanged', () => {
    expect(systemLabel('future_system')).toBe('future_system');
  });
});
