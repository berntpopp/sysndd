import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { loadClinVarVocabularyFixture } from '@/test-utils/clinvarVocabularyFixture';
import {
  CLINVAR_SIGNIFICANCE_TABLE,
  normalizeClinVarSignificance,
  normalizeClinVarSignificanceKey,
  resetUnknownSignificanceLog,
  type ClinVarSignificanceClass,
} from './clinvarSignificance';

/**
 * The shared cross-language fixture. The R suite
 * (api/tests/testthat/test-unit-gnomad-clinvar-summary.R) drives its own
 * implementation from this same file, so the two tables cannot drift.
 */
const vocabularyFixture = loadClinVarVocabularyFixture();

const ACMG_TIERS: ClinVarSignificanceClass[] = [
  'pathogenic',
  'likely_pathogenic',
  'vus',
  'likely_benign',
  'benign',
];

describe('normalizeClinVarSignificance', () => {
  beforeEach(() => {
    resetUnknownSignificanceLog();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it.each(vocabularyFixture.terms)('maps $raw to $class', ({ raw, class: expected }) => {
    expect(normalizeClinVarSignificance(raw)).toBe(expected);
  });

  it.each(vocabularyFixture.normalization_variants)(
    'normalizes $raw to $class',
    ({ raw, class: expected }) => {
      expect(normalizeClinVarSignificance(raw)).toBe(expected);
    }
  );

  it.each(vocabularyFixture.aggregate_terms)(
    'resolves the aggregate value $raw to $class',
    ({ raw, class: expected }) => {
      expect(normalizeClinVarSignificance(raw)).toBe(expected);
    }
  );

  it('never classifies a conflicting term as pathogenic (issue #607)', () => {
    expect(normalizeClinVarSignificance('Conflicting classifications of pathogenicity')).toBe(
      'conflicting'
    );
    expect(normalizeClinVarSignificance('Conflicting classifications of pathogenicity')).not.toBe(
      'pathogenic'
    );
  });

  it('resolves Pathogenic/Likely pathogenic to pathogenic and Benign/Likely benign to likely_benign', () => {
    expect(normalizeClinVarSignificance('Pathogenic/Likely pathogenic')).toBe('pathogenic');
    expect(normalizeClinVarSignificance('Benign/Likely benign')).toBe('likely_benign');
  });

  it.each(vocabularyFixture.unknown_terms)('maps the unresolvable term %j to unknown', (raw) => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    const result = normalizeClinVarSignificance(raw);
    expect(result).toBe('unknown');
    expect(ACMG_TIERS).not.toContain(result);
  });

  it('poisons the whole aggregate when one token is unresolvable', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClinVarSignificance('Pathogenic/Totally new ClinVar term 2027')).toBe('unknown');
  });

  it('handles null, undefined and non-string inputs without throwing', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(normalizeClinVarSignificance(null)).toBe('unknown');
    expect(normalizeClinVarSignificance(undefined)).toBe('unknown');
    expect(normalizeClinVarSignificance(42)).toBe('unknown');
    expect(normalizeClinVarSignificanceKey(null)).toBe('');
  });

  it('warns at most once per distinct unresolvable term', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    normalizeClinVarSignificance('Brand new term');
    normalizeClinVarSignificance('Brand new term');
    normalizeClinVarSignificance('brand   NEW   term');
    normalizeClinVarSignificance('Another new term');
    expect(warn).toHaveBeenCalledTimes(2);
  });

  it('keeps the production table exactly in sync with the fixture (both directions)', () => {
    const fixtureKeys = new Set(
      vocabularyFixture.terms.map(({ raw }) => normalizeClinVarSignificanceKey(raw))
    );
    const tableKeys = new Set(Object.keys(CLINVAR_SIGNIFICANCE_TABLE));

    expect([...tableKeys].filter((key) => !fixtureKeys.has(key)).sort()).toEqual([]);
    expect([...fixtureKeys].filter((key) => !tableKeys.has(key)).sort()).toEqual([]);
  });
});
