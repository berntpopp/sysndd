import { describe, expect, it, vi } from 'vitest';

import { loadClinVarVocabularyFixture } from '@/test-utils/clinvarVocabularyFixture';
import { ACMG_COLORS, ACMG_LABELS, classifyClinicalSignificance } from './alphafold';

const fixture = loadClinVarVocabularyFixture();

describe('classifyClinicalSignificance', () => {
  it.each([...fixture.terms, ...fixture.aggregate_terms])(
    'maps $raw to $class (or null for non-tier terms)',
    ({ raw, class: cls }) => {
      const expected = cls === 'other' || cls === 'unknown' ? null : cls;
      expect(classifyClinicalSignificance(raw)).toBe(expected);
    }
  );

  it('does not classify a conflicting term as pathogenic (issue #607)', () => {
    expect(classifyClinicalSignificance('Conflicting classifications of pathogenicity')).toBe(
      'conflicting'
    );
  });

  it('resolves Pathogenic/Likely pathogenic to pathogenic, matching the server and the lollipop', () => {
    expect(classifyClinicalSignificance('Pathogenic/Likely pathogenic')).toBe('pathogenic');
    expect(classifyClinicalSignificance('Pathogenic/Likely_pathogenic')).toBe('pathogenic');
  });

  it('returns null for unresolvable terms', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(classifyClinicalSignificance('Brand new 2027 term')).toBeNull();
    vi.restoreAllMocks();
  });

  it('gives conflicting a colour and a label', () => {
    expect(ACMG_COLORS.conflicting).toBe('#6f42c1');
    expect(ACMG_LABELS.conflicting).toBe('Conflicting');
  });
});
