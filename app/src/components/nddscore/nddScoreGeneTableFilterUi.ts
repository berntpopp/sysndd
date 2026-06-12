// Pure presentation helpers for the NDDScore gene table filter controls
// (dropdown CSS classes, range labels/placeholders, and HPO term option
// shaping). Extracted from NddScoreGeneTable.vue; no behavior change.

import type { NddScoreHpoTerm } from '@/api/nddscore';
import { displayValue } from './nddScoreGeneTableFormatters';
import {
  nddScoreRangeOperatorOptions,
  type NddScoreGeneFieldDefinition,
} from './nddScoreGeneTableColumns';
import type { NddScoreGeneRangeFilter } from './nddScoreGeneTableFilters';

export interface NddScoreSelectOption {
  value: string;
  text: string;
}

export function nddScoreSelectOptionsFor(
  field: NddScoreGeneFieldDefinition
): NddScoreSelectOption[] {
  return [{ value: '', text: `.. ${field.label} ..` }, ...(field.selectOptions ?? [])];
}

export function nddScoreRangeValuePlaceholder(operator: NddScoreGeneRangeFilter['operator']): string {
  if (operator === 'range') {
    return 'from';
  }
  return 'value';
}

export function nddScoreRangeFilterLabel(
  field: NddScoreGeneFieldDefinition,
  state: NddScoreGeneRangeFilter
): string {
  if (state.operator === 'any') {
    return `Any ${field.label}`;
  }
  if (state.operator === 'range') {
    return state.value && state.valueMax
      ? `${state.value}-${state.valueMax}`
      : `${field.label} range`;
  }
  const operatorLabel = nddScoreRangeOperatorOptions.find(
    (option) => option.value === state.operator
  )?.text;
  return state.value ? `${operatorLabel} ${state.value}` : `${field.label} ${operatorLabel}`;
}

export function nddScoreFilterDropdownToggleClass(isEmpty: boolean): string {
  return [
    'nddscore-gene-table__filter-toggle',
    isEmpty
      ? 'nddscore-gene-table__filter-toggle--empty nddscore-gene-table__filter-dropdown--empty'
      : '',
  ]
    .filter(Boolean)
    .join(' ');
}

export function nddScoreFilterDropdownClass(isEmpty: boolean): Record<string, boolean> {
  return {
    'nddscore-gene-table__filter-dropdown': true,
    'nddscore-gene-table__filter-dropdown--empty': isEmpty,
  };
}

export function nddScoreFilterControlClass(isEmpty: boolean): Record<string, boolean> {
  return {
    'nddscore-gene-table__filter-control': true,
    'nddscore-gene-table__filter-control--empty': isEmpty,
  };
}

export function nddScoreHpoTermOption(term: NddScoreHpoTerm): NddScoreSelectOption | null {
  const phenotypeId = displayValue(term.phenotype_id);
  if (phenotypeId === 'NA') {
    return null;
  }
  const phenotypeName = displayValue(term.phenotype_name);
  return {
    value: phenotypeId,
    text: phenotypeName === 'NA' ? phenotypeId : `${phenotypeId} ${phenotypeName}`,
  };
}
