import { describe, expect, it } from 'vitest';

import { filterFunctionalClusterRows, sortFunctionalClusterRows } from './functionalClusterTable';

const enrichmentRows = [
  {
    cluster_num: 2,
    category: 'GO',
    fdr: '1e-8',
    description: 'synapse organization',
    term: 'GO:0050808',
  },
  {
    cluster_num: 1,
    category: 'KEGG',
    fdr: '0.03',
    description: 'metabolic pathway',
    term: 'hsa01100',
  },
  {
    cluster_num: 3,
    category: 'GO',
    fdr: '0.2',
    description: 'axon guidance',
    term: 'GO:0007411',
  },
];

const identifierRows = [
  { cluster_num: 2, symbol: 'SCN2A', STRING_id: '9606.ENSP000003' },
  { cluster_num: 1, symbol: 'SYNGAP1', STRING_id: '9606.ENSP000004' },
  { cluster_num: 3, symbol: 'MECP2', STRING_id: '9606.ENSP000005' },
];

describe('functionalClusterTable', () => {
  it('filters enrichment rows by category, FDR threshold, generic text, and column text', () => {
    expect(
      filterFunctionalClusterRows(enrichmentRows, {
        tableType: 'term_enrichment',
        categoryFilter: 'GO',
        fdrThreshold: 0.05,
        anyText: 'synapse',
        columnFilters: {
          term: 'GO:',
        },
      })
    ).toEqual([enrichmentRows[0]]);
  });

  it('filters identifier rows through wildcard gene matching only for identifier tables', () => {
    expect(
      filterFunctionalClusterRows(identifierRows, {
        tableType: 'identifiers',
        searchPattern: 'SYN*',
        wildcardMatches: (symbol) => symbol === 'SYNGAP1',
      })
    ).toEqual([identifierRows[1]]);

    expect(
      filterFunctionalClusterRows(enrichmentRows, {
        tableType: 'term_enrichment',
        searchPattern: 'SYN*',
        wildcardMatches: () => false,
      })
    ).toEqual(enrichmentRows);
  });

  it('sorts numeric-looking values numerically and keeps nulls last', () => {
    expect(sortFunctionalClusterRows(enrichmentRows, 'fdr', false)).toEqual([
      enrichmentRows[0],
      enrichmentRows[1],
      enrichmentRows[2],
    ]);
    expect(
      sortFunctionalClusterRows(
        [...identifierRows, { cluster_num: 4, symbol: null }],
        'symbol',
        false
      )
    ).toEqual([
      identifierRows[2],
      identifierRows[0],
      identifierRows[1],
      { cluster_num: 4, symbol: null },
    ]);
  });
});
