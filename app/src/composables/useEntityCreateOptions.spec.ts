import { describe, it, expect } from 'vitest';
import { flattenTreeOptions, transformModifierTree } from './useEntityCreateOptions';

describe('flattenTreeOptions', () => {
  it('flattens nested children into a single value/text list (depth-first)', () => {
    const result = flattenTreeOptions([
      { id: 1, label: 'A', children: [{ id: 2, label: 'B' }] },
      { id: 3, label: 'C' },
    ] as never);

    expect(result).toEqual([
      { value: 1, text: 'A' },
      { value: 2, text: 'B' },
      { value: 3, text: 'C' },
    ]);
  });

  it('returns an empty list for empty input', () => {
    expect(flattenTreeOptions([])).toEqual([]);
  });
});

describe('transformModifierTree', () => {
  it('lifts "present:" to the parent and makes every modifier a selectable child', () => {
    const result = transformModifierTree([
      {
        id: '12-HP:0001250',
        label: 'present: Seizure',
        children: [{ id: '12-HP:0001250-unc', label: 'uncertain: Seizure' }],
      },
    ]);

    expect(result).toEqual([
      {
        id: 'parent-HP:0001250',
        label: 'Seizure',
        children: [
          { id: '12-HP:0001250', label: 'present: Seizure' },
          { id: '12-HP:0001250-unc', label: 'uncertain: Seizure' },
        ],
      },
    ]);
  });

  it('handles nodes without children', () => {
    const result = transformModifierTree([{ id: '1-VO:0001', label: 'present: Missense' }]);
    expect(result[0].id).toBe('parent-VO:0001');
    expect(result[0].label).toBe('Missense');
    expect(result[0].children).toEqual([{ id: '1-VO:0001', label: 'present: Missense' }]);
  });
});
