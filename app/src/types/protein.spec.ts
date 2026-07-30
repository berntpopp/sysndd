import { describe, expect, it, vi } from 'vitest';

import { loadClinVarVocabularyFixture } from '@/test-utils/clinvarVocabularyFixture';
import type { ClinVarSignificanceClass } from './clinvarSignificance';
import {
  PATHOGENICITY_COLORS,
  PATHOGENICITY_SEVERITY,
  aggregateVariantsByPosition,
  normalizeClassification,
  pathogenicitySeverityRank,
  type PathogenicityClass,
  type ProcessedVariant,
} from './protein';

const fixture = loadClinVarVocabularyFixture();

/** Canonical class -> the display class the lollipop plot renders it as. */
const CANONICAL_TO_DISPLAY: Record<ClinVarSignificanceClass, PathogenicityClass> = {
  pathogenic: 'Pathogenic',
  likely_pathogenic: 'Likely pathogenic',
  vus: 'Uncertain significance',
  likely_benign: 'Likely benign',
  benign: 'Benign',
  conflicting: 'Conflicting',
  other: 'other',
  unknown: 'other',
};

function variant(overrides: Partial<ProcessedVariant> = {}): ProcessedVariant {
  return {
    proteinPosition: 530,
    proteinHGVS: 'p.Gly530Ser',
    codingHGVS: 'c.1588G>A',
    classification: 'Pathogenic',
    goldStars: 1,
    reviewStatus: 'criteria provided',
    clinvarId: '1',
    variantId: '5-1-C-T',
    majorConsequence: 'missense_variant',
    isSpliceVariant: false,
    inGnomad: false,
    ...overrides,
  };
}

describe('normalizeClassification', () => {
  it.each([...fixture.terms, ...fixture.aggregate_terms])(
    'maps $raw to the display class for $class',
    ({ raw, class: cls }) => {
      expect(normalizeClassification(raw)).toBe(CANONICAL_TO_DISPLAY[cls]);
    }
  );

  it('does not classify a conflicting term as Pathogenic (issue #607)', () => {
    expect(normalizeClassification('Conflicting classifications of pathogenicity')).toBe(
      'Conflicting'
    );
  });

  it('maps an unresolvable term to other, never to an ACMG tier', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClassification('Brand new 2027 term')).toBe('other');
    vi.restoreAllMocks();
  });

  it('gives Conflicting the shared purple token value', () => {
    expect(PATHOGENICITY_COLORS.Conflicting).toBe('#6f42c1');
  });
});

describe('PATHOGENICITY_SEVERITY', () => {
  it('ranks other lowest and Pathogenic highest', () => {
    expect(PATHOGENICITY_SEVERITY[0]).toBe('other');
    expect(PATHOGENICITY_SEVERITY[PATHOGENICITY_SEVERITY.length - 1]).toBe('Pathogenic');
  });

  it('ranks Conflicting above Likely benign and below Uncertain significance', () => {
    expect(pathogenicitySeverityRank('Conflicting')).toBeGreaterThan(
      pathogenicitySeverityRank('Likely benign')
    );
    expect(pathogenicitySeverityRank('Conflicting')).toBeLessThan(
      pathogenicitySeverityRank('Uncertain significance')
    );
  });

  it('lists every PathogenicityClass exactly once', () => {
    expect(new Set(PATHOGENICITY_SEVERITY).size).toBe(PATHOGENICITY_SEVERITY.length);
    expect(PATHOGENICITY_SEVERITY).toHaveLength(Object.keys(PATHOGENICITY_COLORS).length);
  });
});

describe('aggregateVariantsByPosition', () => {
  it('does not let an "other" variant dominate a Pathogenic position', () => {
    const [aggregated] = aggregateVariantsByPosition([
      variant({ classification: 'Pathogenic' }),
      variant({ classification: 'other' }),
    ]);
    expect(aggregated.dominantClass).toBe('Pathogenic');
  });

  it('reports Conflicting as dominant when it is the most severe present', () => {
    const [aggregated] = aggregateVariantsByPosition([
      variant({ classification: 'Conflicting' }),
      variant({ classification: 'Benign' }),
    ]);
    expect(aggregated.dominantClass).toBe('Conflicting');
    expect(aggregated.countByClass.Conflicting).toBe(1);
  });

  it('still prefers Pathogenic over Conflicting at the same position', () => {
    const [aggregated] = aggregateVariantsByPosition([
      variant({ classification: 'Conflicting' }),
      variant({ classification: 'Pathogenic' }),
    ]);
    expect(aggregated.dominantClass).toBe('Pathogenic');
  });
});
