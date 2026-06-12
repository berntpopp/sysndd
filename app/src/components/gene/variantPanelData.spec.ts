import { describe, expect, it } from 'vitest';

import type { ClinVarVariant } from '@/types/external';
import {
  buildMappableVariants,
  countByClassification,
  filterMappableVariants,
  getHiddenClassifications,
  selectAll,
  selectOnly,
  toggleFilter,
  type VariantFilterState,
} from './variantPanelData';

function makeVariant(overrides: Partial<ClinVarVariant>): ClinVarVariant {
  return {
    clinical_significance: 'Pathogenic',
    clinvar_variation_id: '1',
    gold_stars: 2,
    hgvsc: 'c.1A>T',
    hgvsp: 'p.Arg10Trp',
    in_gnomad: false,
    major_consequence: 'missense_variant',
    pos: 1000,
    review_status: 'criteria provided',
    variant_id: 'v1',
    ...overrides,
  } as ClinVarVariant;
}

function makeFilterState(overrides: Partial<VariantFilterState> = {}): VariantFilterState {
  return {
    pathogenic: true,
    likelyPathogenic: true,
    vus: true,
    likelyBenign: true,
    benign: true,
    ...overrides,
  };
}

describe('variantPanelData', () => {
  it('buildMappableVariants drops non-mappable variants and sorts by residue', () => {
    const items = buildMappableVariants([
      makeVariant({ variant_id: 'b', hgvsp: 'p.Arg30Trp' }),
      makeVariant({ variant_id: 'a', hgvsp: 'p.Arg10Trp' }),
      // frameshift -> parseResidueNumber returns null -> dropped
      makeVariant({ variant_id: 'fs', hgvsp: 'p.Arg5fs', hgvsc: null }),
      // no protein notation -> dropped
      makeVariant({ variant_id: 'none', hgvsp: null, hgvsc: null }),
    ]);

    expect(items.map((i) => i.variant.variant_id)).toEqual(['a', 'b']);
    expect(items[0].residue).toBe(10);
    expect(items[1].residue).toBe(30);
  });

  it('countByClassification tallies by ACMG filter key', () => {
    const items = buildMappableVariants([
      makeVariant({ variant_id: 'p1', clinical_significance: 'Pathogenic', hgvsp: 'p.Arg10Trp' }),
      makeVariant({ variant_id: 'b1', clinical_significance: 'Benign', hgvsp: 'p.Arg20Trp' }),
    ]);
    const counts = countByClassification(items);
    expect(counts.pathogenic).toBe(1);
    expect(counts.benign).toBe(1);
    expect(counts.vus).toBe(0);
  });

  it('filterMappableVariants applies ACMG filter and search query', () => {
    const items = buildMappableVariants([
      makeVariant({ variant_id: 'p1', clinical_significance: 'Pathogenic', hgvsp: 'p.Arg10Trp' }),
      makeVariant({ variant_id: 'b1', clinical_significance: 'Benign', hgvsp: 'p.Gly20Ser' }),
    ]);

    // Hide benign
    const hidePathogenic = filterMappableVariants(items, makeFilterState({ benign: false }), '');
    expect(hidePathogenic.map((i) => i.variant.variant_id)).toEqual(['p1']);

    // Search by hgvsp substring
    const searched = filterMappableVariants(items, makeFilterState(), 'gly20');
    expect(searched.map((i) => i.variant.variant_id)).toEqual(['b1']);
  });

  it('getHiddenClassifications reflects disabled keys', () => {
    expect(getHiddenClassifications(makeFilterState())).toEqual([]);
    expect(
      getHiddenClassifications(makeFilterState({ vus: false, benign: false }))
    ).toEqual(['vus', 'benign']);
  });

  it('toggleFilter / selectOnly / selectAll mutate the filter state', () => {
    const fs = makeFilterState();
    toggleFilter(fs, 'vus');
    expect(fs.vus).toBe(false);

    selectOnly(fs, 'pathogenic');
    expect([fs.pathogenic, fs.likelyPathogenic, fs.vus, fs.likelyBenign, fs.benign]).toEqual([
      true,
      false,
      false,
      false,
      false,
    ]);

    selectAll(fs);
    expect([fs.pathogenic, fs.likelyPathogenic, fs.vus, fs.likelyBenign, fs.benign]).toEqual([
      true,
      true,
      true,
      true,
      true,
    ]);
  });
});
