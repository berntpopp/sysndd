import { describe, expect, it } from 'vitest';

import { filterReReviewBatches, sortReReviewBatches } from './reReviewFilters';

const rows = [
  {
    user_id: 3,
    user_name: 'Alice Curator',
    re_review_batch: 102,
    entity_count: 14,
  },
  {
    user_id: null,
    user_name: null,
    re_review_batch: 205,
    entity_count: 4,
  },
  {
    user_id: 9,
    user_name: 'Bob Reviewer',
    re_review_batch: 17,
    entity_count: 22,
  },
];

describe('reReviewFilters', () => {
  it('filters batches by text, assigned user, and assignment status', () => {
    expect(filterReReviewBatches(rows, { text: 'bob', userName: null, assignment: null })).toEqual([
      rows[2],
    ]);
    expect(
      filterReReviewBatches(rows, {
        text: '20',
        userName: null,
        assignment: 'unassigned',
      })
    ).toEqual([rows[1]]);
    expect(
      filterReReviewBatches(rows, {
        text: null,
        userName: 'Alice Curator',
        assignment: 'assigned',
      })
    ).toEqual([rows[0]]);
  });

  it('sorts batches with null values last and numeric-aware string comparison', () => {
    expect(sortReReviewBatches(rows, [{ key: 're_review_batch', order: 'asc' }])).toEqual([
      rows[2],
      rows[0],
      rows[1],
    ]);
    expect(sortReReviewBatches(rows, [{ key: 'user_name', order: 'desc' }])).toEqual([
      rows[2],
      rows[0],
      rows[1],
    ]);
  });
});
