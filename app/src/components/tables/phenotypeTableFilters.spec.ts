import { describe, expect, it } from 'vitest';

import { applyPhenotypeLogicMode, createDefaultPhenotypeFilter } from './phenotypeTableFilters';

describe('phenotypeTableFilters', () => {
  it('creates the default phenotype entity filter state', () => {
    expect(createDefaultPhenotypeFilter()).toMatchObject({
      modifier_phenotype_id: {
        content: ['HP:0001249'],
        join_char: ',',
        operator: 'all',
      },
      any: { content: null, operator: 'contains' },
      category: { content: null, join_char: ',', operator: 'any' },
    });
  });

  it('sets phenotype filter logic without mutating the original filter object', () => {
    const filter = createDefaultPhenotypeFilter();

    const anyFilter = applyPhenotypeLogicMode(filter, true);
    expect(anyFilter.modifier_phenotype_id.operator).toBe('any');
    expect(filter.modifier_phenotype_id.operator).toBe('all');

    const allFilter = applyPhenotypeLogicMode(anyFilter, false);
    expect(allFilter.modifier_phenotype_id.operator).toBe('all');
  });
});
