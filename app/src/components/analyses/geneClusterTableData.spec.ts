import { describe, it, expect } from 'vitest';
import {
  clusterRowsWithNumber,
  combineClusterData,
  buildClusterTableFields,
  findCategoryText,
  findCategoryLink,
  categoryChipClass,
  formatFdr,
  buildClusterExportFilename,
  clusterExportSheetName,
  CLUSTER_EXPORT_HEADERS,
  type FunctionalCluster,
  type CategoryDescriptor,
} from './geneClusterTableData';

const cluster = (num: number): FunctionalCluster => ({
  cluster: num,
  term_enrichment: [{ category: 'GO', fdr: '1e-5' }],
  identifiers: [{ symbol: `GENE${num}` }],
});

describe('clusterRowsWithNumber', () => {
  it('returns empty arrays for an undefined cluster', () => {
    expect(clusterRowsWithNumber(undefined, 3)).toEqual({
      term_enrichment: [],
      identifiers: [],
    });
  });

  it('tags every row with the cluster number', () => {
    const out = clusterRowsWithNumber(cluster(7), 7);
    expect(out.term_enrichment[0]).toMatchObject({ category: 'GO', cluster_num: 7 });
    expect(out.identifiers[0]).toMatchObject({ symbol: 'GENE7', cluster_num: 7 });
  });

  it('does not mutate the source rows', () => {
    const src = cluster(1);
    clusterRowsWithNumber(src, 1);
    expect(src.term_enrichment?.[0]).not.toHaveProperty('cluster_num');
  });
});

describe('combineClusterData', () => {
  it('concatenates and tags rows from multiple clusters', () => {
    const combined = combineClusterData([cluster(1), cluster(2)]);
    expect(combined.term_enrichment).toHaveLength(2);
    expect(combined.identifiers.map((r) => r.cluster_num)).toEqual([1, 2]);
    expect(combined.identifiers.map((r) => r.symbol)).toEqual(['GENE1', 'GENE2']);
  });

  it('handles clusters missing one of the arrays', () => {
    const combined = combineClusterData([{ cluster: 9, term_enrichment: [{ a: 1 }] }]);
    expect(combined.term_enrichment).toHaveLength(1);
    expect(combined.identifiers).toHaveLength(0);
  });
});

describe('buildClusterTableFields', () => {
  it('builds term_enrichment fields with a leading cluster column', () => {
    const fields = buildClusterTableFields('term_enrichment');
    expect(fields.map((f) => f.key)).toEqual([
      'cluster_num',
      'category',
      'number_of_genes',
      'fdr',
      'description',
    ]);
  });

  it('builds identifiers fields with a leading cluster column', () => {
    const fields = buildClusterTableFields('identifiers');
    expect(fields.map((f) => f.key)).toEqual(['cluster_num', 'symbol', 'STRING_id']);
  });

  it('sorts FDR numerically including scientific notation strings', () => {
    const fdrField = buildClusterTableFields('term_enrichment').find((f) => f.key === 'fdr');
    const cmp = fdrField?.sortCompare;
    expect(cmp).toBeTypeOf('function');
    expect(cmp!({ fdr: '1.0e-20' }, { fdr: '1.0e-3' }, 'fdr')).toBeLessThan(0);
    expect(cmp!({ fdr: '5e-2' }, { fdr: '5e-2' }, 'fdr')).toBe(0);
  });
});

describe('category helpers', () => {
  const categories: CategoryDescriptor[] = [
    { value: 'GO', text: 'GO (Gene Ontology)', link: 'https://example.org/go/' },
  ];

  it('resolves the category label and falls back to the raw value', () => {
    expect(findCategoryText(categories, 'GO')).toBe('GO (Gene Ontology)');
    expect(findCategoryText(categories, 'KEGG')).toBe('KEGG');
  });

  it('builds a category link and falls back to #', () => {
    expect(findCategoryLink(categories, 'GO', '0001234')).toBe('https://example.org/go/0001234');
    expect(findCategoryLink(categories, 'KEGG', 'x')).toBe('#');
  });
});

describe('categoryChipClass', () => {
  it('maps known categories to chip modifiers', () => {
    expect(categoryChipClass('GO')).toBe('sysndd-chip--teal');
    expect(categoryChipClass('KEGG')).toBe('sysndd-chip--blue');
    expect(categoryChipClass('MONDO')).toBe('sysndd-chip--info');
    expect(categoryChipClass('HPO')).toBe('sysndd-chip--success');
  });

  it('falls back to the neutral chip for unknown categories', () => {
    expect(categoryChipClass('OTHER')).toBe('sysndd-chip--neutral');
  });
});

describe('formatFdr', () => {
  it('renders an em dash for nullish values', () => {
    expect(formatFdr(null)).toBe('—');
    expect(formatFdr(undefined)).toBe('—');
  });

  it('renders tiny values in scientific notation instead of "0"', () => {
    expect(formatFdr(1e-15)).toBe('1.00e-15');
    expect(formatFdr('1e-5')).toBe('1.00e-5');
  });

  it('keeps mid-range values in precision notation and passes through non-numbers', () => {
    expect(formatFdr(0)).toBe('0');
    expect(formatFdr(0.05)).toBe('0.0500');
    expect(formatFdr('n/a')).toBe('n/a');
  });
});

describe('export helpers', () => {
  it('exposes headers per table type', () => {
    expect(CLUSTER_EXPORT_HEADERS.term_enrichment.fdr).toBe('FDR');
    expect(CLUSTER_EXPORT_HEADERS.identifiers.symbol).toBe('Gene Symbol');
  });

  it('builds filenames for all-clusters and selected-clusters', () => {
    expect(buildClusterExportFilename('term_enrichment', true, [])).toBe(
      'sysndd_gene_term_enrichment_all_clusters'
    );
    expect(buildClusterExportFilename('identifiers', false, [2, 5])).toBe(
      'sysndd_gene_identifiers_clusters_2_5'
    );
  });

  it('maps the sheet name per table type', () => {
    expect(clusterExportSheetName('term_enrichment')).toBe('Enrichment');
    expect(clusterExportSheetName('identifiers')).toBe('Identifiers');
  });
});
