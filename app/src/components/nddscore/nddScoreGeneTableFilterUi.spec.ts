import { describe, expect, it } from 'vitest';
import {
  nddScoreSelectOptionsFor,
  nddScoreRangeValuePlaceholder,
  nddScoreRangeFilterLabel,
  nddScoreFilterDropdownToggleClass,
  nddScoreFilterDropdownClass,
  nddScoreFilterControlClass,
  nddScoreHpoTermOption,
} from './nddScoreGeneTableFilterUi';
import { nddScoreGeneFields } from './nddScoreGeneTableColumns';

const riskField = nddScoreGeneFields.find((field) => field.key === 'risk_tier')!;
const rankField = nddScoreGeneFields.find((field) => field.key === 'rank')!;

describe('nddScoreGeneTableFilterUi', () => {
  it('prepends a placeholder option to select filters', () => {
    const options = nddScoreSelectOptionsFor(riskField);
    expect(options[0]).toEqual({ value: '', text: '.. Risk tier ..' });
    expect(options).toHaveLength((riskField.selectOptions?.length ?? 0) + 1);
  });

  it('chooses the range value placeholder by operator', () => {
    expect(nddScoreRangeValuePlaceholder('range')).toBe('from');
    expect(nddScoreRangeValuePlaceholder('gte')).toBe('value');
  });

  it('labels range filters based on operator and bounds', () => {
    expect(nddScoreRangeFilterLabel(rankField, { operator: 'any', value: '', valueMax: '' })).toBe(
      'Any Rank'
    );
    expect(
      nddScoreRangeFilterLabel(rankField, { operator: 'range', value: '10', valueMax: '20' })
    ).toBe('10-20');
    expect(nddScoreRangeFilterLabel(rankField, { operator: 'lte', value: '200', valueMax: '' })).toBe(
      '<= 200'
    );
  });

  it('produces empty-state dropdown and control classes', () => {
    expect(nddScoreFilterDropdownToggleClass(true)).toContain(
      'nddscore-gene-table__filter-toggle--empty'
    );
    expect(nddScoreFilterDropdownToggleClass(false)).toBe('nddscore-gene-table__filter-toggle');
    expect(nddScoreFilterDropdownClass(true)['nddscore-gene-table__filter-dropdown--empty']).toBe(
      true
    );
    expect(nddScoreFilterControlClass(true)['nddscore-gene-table__filter-control--empty']).toBe(
      true
    );
  });

  it('shapes HPO term options and drops missing ids', () => {
    expect(
      nddScoreHpoTermOption({ phenotype_id: 'HP:0001249', phenotype_name: 'Intellectual disability' })
    ).toEqual({ value: 'HP:0001249', text: 'HP:0001249 Intellectual disability' });
    expect(nddScoreHpoTermOption({ phenotype_id: '', phenotype_name: '' })).toBeNull();
  });
});
