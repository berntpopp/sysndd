import { describe, expect, it } from 'vitest';

import {
  applyPubtatorGenePrioritizationFilters,
  createDefaultPubtatorGeneFilter,
} from './pubtatorGeneFilters';

describe('pubtatorGeneFilters', () => {
  it('creates the default PubTator gene filter state', () => {
    expect(createDefaultPubtatorGeneFilter()).toMatchObject({
      any: { content: null, join_char: null, operator: 'contains' },
      gene_symbol: { content: null, join_char: null, operator: 'contains' },
      publication_count: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
      oldest_pub_date: { content: null, join_char: null, operator: 'greaterThanOrEqual' },
      is_novel: { content: null, join_char: null, operator: 'equals' },
    });
  });

  it('applies minimum publication and date range filters without mutating input', () => {
    const filter = createDefaultPubtatorGeneFilter();

    const updated = applyPubtatorGenePrioritizationFilters(filter, {
      minPublications: '5',
      dateRangeYears: '2',
      today: new Date('2026-05-19T12:00:00Z'),
    });

    expect(updated.publication_count.content).toBe('5');
    expect(updated.oldest_pub_date.content).toBe('2024-05-19');
    expect(filter.publication_count.content).toBeNull();
    expect(filter.oldest_pub_date.content).toBeNull();
  });

  it('clears prioritization filters when all options are selected', () => {
    const filter = createDefaultPubtatorGeneFilter();
    filter.publication_count.content = '10';
    filter.oldest_pub_date.content = '2021-01-01';

    const updated = applyPubtatorGenePrioritizationFilters(filter, {
      minPublications: 'all',
      dateRangeYears: 'all',
      today: new Date('2026-05-19T12:00:00Z'),
    });

    expect(updated.publication_count.content).toBeNull();
    expect(updated.oldest_pub_date.content).toBeNull();
  });
});
