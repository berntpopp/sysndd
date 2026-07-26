import { describe, expect, it } from 'vitest';

import { splitOntologyTag } from './ontologyTags';

describe('splitOntologyTag', () => {
  it.each([
    ['1-HP:0001249', 1, 'HP:0001249'],
    ['5-VariO:0015', 5, 'VariO:0015'],
    ['1-CURIE:part-with-hyphen', 1, 'CURIE:part-with-hyphen'],
  ])('preserves the CURIE suffix after the first separator for %s', (tag, modifierId, ontologyId) => {
    const result = splitOntologyTag(tag);

    expect(result).toEqual({ modifierId, ontologyId });
    expect(typeof result.ontologyId).toBe('string');
  });
});
