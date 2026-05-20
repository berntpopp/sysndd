import { describe, expect, it } from 'vitest';

import {
  buildNddScoreGeneApiFilters,
  buildNddScoreGeneFilterString,
  parseNddScoreGeneFilterClauses,
} from './nddScoreGeneTableFilters';

describe('nddScoreGeneTableFilters', () => {
  it('builds compact URL filter clauses and sanitizes reserved separators', () => {
    expect(
      buildNddScoreGeneFilterString({
        search: 'KMT2A',
        columnFilters: {
          gene_symbol: 'SCN2A,(bad)',
          model_split: 'unseen',
          top_inheritance_mode: 'AD',
        },
        rangeFilters: {
          rank: { operator: 'lte', value: '200', valueMax: '' },
          percentile: { operator: 'range', value: '90', valueMax: '99' },
        },
        hpoTerms: ['HP:0001249', 'HP:0001250'],
      })
    ).toBe(
      'contains(any,KMT2A),equals(gene_symbol,SCN2A  bad ),equals(model_split,unseen),equals(top_inheritance_mode,AD),lte(rank,200),range(percentile,90,99),any(top_hpo_predictions_json,HP:0001249,HP:0001250)'
    );
  });

  it('parses URL filter clauses and drops malformed clauses', () => {
    expect(
      parseNddScoreGeneFilterClauses(
        'equals(model_split,unseen),range(percentile,90,99),bad-clause'
      )
    ).toEqual([
      { operator: 'equals', key: 'model_split', values: ['unseen'] },
      { operator: 'range', key: 'percentile', values: ['90', '99'] },
    ]);
  });

  it('builds API filters with empty filters omitted and numeric ranges normalized', () => {
    expect(
      buildNddScoreGeneApiFilters({
        search: '',
        columnFilters: {
          gene_symbol: 'KMT2A',
          model_split: 'unseen',
          risk_tier: '',
          confidence_tier: 'Medium',
          known_sysndd_gene: '',
          top_inheritance_mode: 'AD',
        },
        rangeFilters: {
          ndd_score: { operator: 'gte', value: '0.75', valueMax: '' },
          rank: { operator: 'lte', value: '200', valueMax: '' },
          percentile: { operator: 'range', value: '95', valueMax: '99' },
        },
        hpoTerms: ['HP:0001249'],
      })
    ).toEqual({
      search: undefined,
      nddScoreMin: 0.75,
      nddScoreMax: undefined,
      rankMin: undefined,
      rankMax: 200,
      percentileMin: 95,
      percentileMax: 99,
      riskTier: undefined,
      confidenceTier: 'Medium',
      knownSysnddGene: undefined,
      geneSymbol: 'KMT2A',
      modelSplit: 'unseen',
      topInheritanceMode: 'AD',
      hpoTerms: ['HP:0001249'],
    });
  });
});
