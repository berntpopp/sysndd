import { describe, it, expect } from 'vitest';
import {
  sortPhenotypeClusterRows,
  filterPhenotypeClusterRows,
  buildPhenotypeClusterExportFilename,
  phenotypeClusterExportSheetName,
  PHENOTYPE_CLUSTER_EXPORT_HEADERS,
  type PhenotypeClusterFilter,
} from './phenotypeClusterTable';

const emptyFilter = (): PhenotypeClusterFilter => ({
  any: { content: null, join_char: null, operator: 'contains' },
  variable: { content: null, join_char: null, operator: 'contains' },
  'p.value': { content: null, join_char: null, operator: 'contains' },
  'v.test': { content: null, join_char: null, operator: 'contains' },
});

describe('sortPhenotypeClusterRows', () => {
  it('returns a copy when no sort column is given', () => {
    const rows = [{ a: 1 }, { a: 2 }];
    const out = sortPhenotypeClusterRows(rows, null, false);
    expect(out).toEqual(rows);
    expect(out).not.toBe(rows);
  });

  it('sorts numeric strings including scientific notation ascending', () => {
    const rows = [{ 'p.value': '1e-3' }, { 'p.value': '1e-20' }, { 'p.value': '5e-5' }];
    const out = sortPhenotypeClusterRows(rows, 'p.value', false);
    expect(out.map((r) => r['p.value'])).toEqual(['1e-20', '5e-5', '1e-3']);
  });

  it('reverses order when descending', () => {
    const rows = [{ v: 1 }, { v: 3 }, { v: 2 }];
    const out = sortPhenotypeClusterRows(rows, 'v', true);
    expect(out.map((r) => r.v)).toEqual([3, 2, 1]);
  });

  it('pushes null/undefined values to the end', () => {
    const rows = [{ v: null }, { v: 2 }, { v: 1 }];
    const out = sortPhenotypeClusterRows(rows, 'v', false);
    expect(out.map((r) => r.v)).toEqual([1, 2, null]);
  });

  it('sorts non-numeric values as lower-cased strings', () => {
    const rows = [{ variable: 'Banana' }, { variable: 'apple' }];
    const out = sortPhenotypeClusterRows(rows, 'variable', false);
    expect(out.map((r) => r.variable)).toEqual(['apple', 'Banana']);
  });

  it('does not mutate the input', () => {
    const rows = [{ v: 2 }, { v: 1 }];
    sortPhenotypeClusterRows(rows, 'v', false);
    expect(rows.map((r) => r.v)).toEqual([2, 1]);
  });
});

describe('filterPhenotypeClusterRows', () => {
  const rows = [
    { variable: 'HP:0001', 'p.value': '0.01', 'v.test': '3.2' },
    { variable: 'HP:0002', 'p.value': '0.50', 'v.test': '0.1' },
  ];

  it('returns all rows when no filter is set', () => {
    expect(filterPhenotypeClusterRows(rows, emptyFilter())).toHaveLength(2);
  });

  it('applies the global "any" filter against all values (case-insensitive)', () => {
    const filter = emptyFilter();
    filter.any.content = 'hp:0001';
    const out = filterPhenotypeClusterRows(rows, filter);
    expect(out).toHaveLength(1);
    expect(out[0].variable).toBe('HP:0001');
  });

  it('applies per-column contains filters', () => {
    const filter = emptyFilter();
    filter['p.value'].content = '0.5';
    const out = filterPhenotypeClusterRows(rows, filter);
    expect(out).toHaveLength(1);
    expect(out[0].variable).toBe('HP:0002');
  });

  it('combines the any filter and column filters (AND)', () => {
    const filter = emptyFilter();
    filter.any.content = 'HP';
    filter['v.test'].content = '3.2';
    const out = filterPhenotypeClusterRows(rows, filter);
    expect(out).toHaveLength(1);
    expect(out[0].variable).toBe('HP:0001');
  });
});

describe('export config', () => {
  it('builds a contextual filename', () => {
    expect(buildPhenotypeClusterExportFilename(3, 'quali_inp_var')).toBe(
      'sysndd_phenotype_cluster_3_quali_inp_var'
    );
  });

  it('maps sheet names per table type', () => {
    expect(phenotypeClusterExportSheetName('quali_inp_var')).toBe('Qualitative Input Variables');
    expect(phenotypeClusterExportSheetName('quanti_sup_var')).toBe(
      'Quantitative Supplementary Variables'
    );
  });

  it('exposes the export headers', () => {
    expect(PHENOTYPE_CLUSTER_EXPORT_HEADERS['p.value']).toBe('p-value');
    expect(PHENOTYPE_CLUSTER_EXPORT_HEADERS.Mean_in_category).toBe('Mean in Category');
  });
});
