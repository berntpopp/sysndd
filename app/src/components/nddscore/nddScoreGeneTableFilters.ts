export type NddScoreGeneRangeOperator = 'any' | 'gte' | 'lte' | 'eq' | 'range';

export interface NddScoreGeneRangeFilter {
  operator: NddScoreGeneRangeOperator;
  value: string;
  valueMax: string;
}

export interface NddScoreGeneFilterState {
  search: string;
  columnFilters: Record<string, string>;
  rangeFilters: Record<string, NddScoreGeneRangeFilter>;
  hpoTerms: string[];
}

export interface NddScoreGeneFilterClause {
  operator: string;
  key: string;
  values: string[];
}

export interface NddScoreGeneApiFilters {
  search?: string;
  nddScoreMin?: number;
  nddScoreMax?: number;
  rankMin?: number;
  rankMax?: number;
  percentileMin?: number;
  percentileMax?: number;
  riskTier?: string;
  confidenceTier?: string;
  knownSysnddGene?: string;
  geneSymbol?: string;
  modelSplit?: string;
  topInheritanceMode?: string;
  hpoTerms?: string[];
}

export function encodeNddScoreFilterValue(value: string): string {
  return value.replace(/[(),]/g, ' ');
}

export function buildNddScoreGeneFilterString(state: NddScoreGeneFilterState): string {
  const clauses: string[] = [];
  const addClause = (operator: string, key: string, values: string[]) => {
    const cleaned = values
      .map((value) => encodeNddScoreFilterValue(String(value ?? '').trim()))
      .filter(Boolean);
    if (cleaned.length) {
      clauses.push(`${operator}(${key},${cleaned.join(',')})`);
    }
  };

  addClause('contains', 'any', [state.search]);
  addClause('equals', 'gene_symbol', [state.columnFilters.gene_symbol]);
  addClause('equals', 'risk_tier', [state.columnFilters.risk_tier]);
  addClause('equals', 'confidence_tier', [state.columnFilters.confidence_tier]);
  addClause('equals', 'known_sysndd_gene', [state.columnFilters.known_sysndd_gene]);
  addClause('equals', 'model_split', [state.columnFilters.model_split]);
  addClause('equals', 'top_inheritance_mode', [state.columnFilters.top_inheritance_mode]);

  Object.entries(state.rangeFilters).forEach(([key, rangeFilter]) => {
    if (rangeFilter.operator === 'any') return;
    if (rangeFilter.operator === 'range') {
      addClause('range', key, [rangeFilter.value, rangeFilter.valueMax]);
    } else {
      addClause(rangeFilter.operator, key, [rangeFilter.value]);
    }
  });

  addClause('any', 'top_hpo_predictions_json', state.hpoTerms);
  return clauses.join(',');
}

export function parseNddScoreGeneFilterClauses(
  filterString: string | null
): NddScoreGeneFilterClause[] {
  if (!filterString || filterString === 'null') {
    return [];
  }

  return filterString
    .split('),')
    .map((part) => part.replace(/\)$/, ''))
    .map((part) => {
      const match = part.match(/^([^()]+)\(([^,]+),(.*)$/);
      if (!match) {
        return null;
      }
      return {
        operator: match[1].trim(),
        key: match[2].trim(),
        values: match[3]
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean),
      };
    })
    .filter((clause): clause is NddScoreGeneFilterClause => clause != null);
}

export function nddScoreNumberFilter(value: string): number | undefined {
  if (value.trim() === '') {
    return undefined;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function nddScoreRangeMin(
  rangeFilters: Record<string, NddScoreGeneRangeFilter>,
  key: string
): number | undefined {
  const state = rangeFilters[key];
  if (!state) return undefined;
  if (state.operator === 'gte' || state.operator === 'range' || state.operator === 'eq') {
    return nddScoreNumberFilter(state.value);
  }
  return undefined;
}

export function nddScoreRangeMax(
  rangeFilters: Record<string, NddScoreGeneRangeFilter>,
  key: string
): number | undefined {
  const state = rangeFilters[key];
  if (!state) return undefined;
  if (state.operator === 'lte' || state.operator === 'eq') {
    return nddScoreNumberFilter(state.value);
  }
  if (state.operator === 'range') {
    return nddScoreNumberFilter(state.valueMax);
  }
  return undefined;
}

export function buildNddScoreGeneApiFilters(
  state: NddScoreGeneFilterState
): NddScoreGeneApiFilters {
  return {
    search: state.search || undefined,
    nddScoreMin: nddScoreRangeMin(state.rangeFilters, 'ndd_score'),
    nddScoreMax: nddScoreRangeMax(state.rangeFilters, 'ndd_score'),
    rankMin: nddScoreRangeMin(state.rangeFilters, 'rank'),
    rankMax: nddScoreRangeMax(state.rangeFilters, 'rank'),
    percentileMin: nddScoreRangeMin(state.rangeFilters, 'percentile'),
    percentileMax: nddScoreRangeMax(state.rangeFilters, 'percentile'),
    riskTier: state.columnFilters.risk_tier || undefined,
    confidenceTier: state.columnFilters.confidence_tier || undefined,
    knownSysnddGene: state.columnFilters.known_sysndd_gene || undefined,
    geneSymbol: state.columnFilters.gene_symbol || undefined,
    modelSplit: state.columnFilters.model_split || undefined,
    topInheritanceMode: state.columnFilters.top_inheritance_mode || undefined,
    hpoTerms: state.hpoTerms.length ? state.hpoTerms : undefined,
  };
}
