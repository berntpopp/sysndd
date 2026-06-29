import { describe, expect, it } from 'vitest';

import { createDefaultPhenotypeFilter, phenotypeLogicOperator } from './phenotypeTableFilters';

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

  it('maps the AND/OR logic toggle to the modifier_phenotype_id operator', () => {
    // OR mode -> "any", AND mode -> "all". Applied in place by the caller so a
    // no-op write does not re-fire the deep filter watcher (#466).
    expect(phenotypeLogicOperator(true)).toBe('any');
    expect(phenotypeLogicOperator(false)).toBe('all');
  });
});
