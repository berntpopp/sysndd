import { describe, it, expect } from 'vitest';
import {
  createComparisonFields,
  createComparisonFilter,
  withCuratedComparisonLabels,
  COMPARISON_SOURCE_COLUMNS,
} from './curationComparisonsTableConfig';

describe('createComparisonFields', () => {
  it('returns the expected column order', () => {
    expect(createComparisonFields().map((f) => f.key)).toEqual([
      'symbol',
      'SysNDD',
      'gene2phenotype',
      'panelapp',
      'radboudumc_ID',
      'sfari',
      'ndd_genehub',
      'orphanet_id',
      'omim_ndd',
    ]);
  });

  it('marks every column sortable, filterable, and text-start', () => {
    createComparisonFields().forEach((f) => {
      expect(f).toMatchObject({ sortable: true, filterable: true, class: 'text-start' });
    });
  });

  it('returns a fresh array each call', () => {
    expect(createComparisonFields()).not.toBe(createComparisonFields());
  });
});

describe('createComparisonFilter', () => {
  it('uses "any" operator with comma join for multi-value source columns', () => {
    const filter = createComparisonFilter();
    expect(filter.SysNDD).toEqual({ content: null, join_char: ',', operator: 'any' });
    expect(filter.panelapp).toEqual({ content: null, join_char: ',', operator: 'any' });
  });

  it('uses "contains" for free-text columns', () => {
    const filter = createComparisonFilter();
    expect(filter.symbol).toEqual({ content: null, join_char: null, operator: 'contains' });
    expect(filter.omim_ndd).toEqual({ content: null, join_char: null, operator: 'contains' });
  });

  it('returns a fresh object each call (no shared state)', () => {
    const a = createComparisonFilter();
    const b = createComparisonFilter();
    a.symbol.content = 'X';
    expect(b.symbol.content).toBeNull();
  });
});

describe('COMPARISON_SOURCE_COLUMNS', () => {
  it('excludes the free-text symbol column', () => {
    expect(COMPARISON_SOURCE_COLUMNS).not.toContain('symbol');
  });

  it('covers every non-symbol filterable column', () => {
    const fieldKeys = createComparisonFields()
      .map((f) => f.key)
      .filter((k) => k !== 'symbol');
    expect([...COMPARISON_SOURCE_COLUMNS]).toEqual(fieldKeys);
  });
});

describe('withCuratedComparisonLabels', () => {
  it('re-applies curated source labels while preserving backend count facets', () => {
    const fspec = [
      { key: 'SysNDD', label: 'Sysndd', count: 6, count_filtered: 5, filterable: true },
      { key: 'panelapp', label: 'Panelapp', count: 4, count_filtered: 4 },
      { key: 'omim_ndd', label: 'Omim ndd', count: 2, count_filtered: 2 },
    ];

    const result = withCuratedComparisonLabels(fspec);

    expect(result.map((f) => f.label)).toEqual(['SysNDD', 'PanelApp', 'OMIM NDD']);
    // Backend-computed properties are preserved untouched.
    expect(result[0]).toMatchObject({ count: 6, count_filtered: 5, filterable: true });
  });

  it('leaves unknown keys and their labels unchanged', () => {
    const fspec = [{ key: 'mystery_col', label: 'Mystery col', count: 1 }];
    expect(withCuratedComparisonLabels(fspec)[0].label).toBe('Mystery col');
  });

  it('returns the input unchanged when it is not an array', () => {
    expect(withCuratedComparisonLabels(undefined as never)).toBeUndefined();
  });
});
