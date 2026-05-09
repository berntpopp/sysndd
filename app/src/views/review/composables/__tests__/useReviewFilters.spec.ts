// app/src/views/review/composables/__tests__/useReviewFilters.spec.ts
/**
 * Unit tests for `useReviewFilters` — extracted during W6 of v11.1
 * finish-hardening.
 *
 * Owns three filter dimensions plus the derived options/availability
 * computeds the template binds against:
 *
 *   - Free-text filter (`filter`) — drives BTable's stock filter prop;
 *     reactive but not applied inside the composable (BTable owns that).
 *   - Column filters (`categoryFilter`, `userFilter`) — applied inside
 *     `filteredItems`. Drop-down options derived from unique values in
 *     the input list.
 *   - Quick filters (`pending`, `submitted`, `needsStatus`) — boolean
 *     toggles applied AND-style on top of the column filters.
 */

import { describe, it, expect } from 'vitest';
import { ref, type Ref } from 'vue';

import { useReviewFilters } from '../useReviewFilters';

interface Row {
  entity_id: number;
  category: string | null;
  review_user_name: string | null;
  re_review_review_saved: number;
  re_review_status_saved: number;
  status_id: number | null;
  // Index signature satisfies the FilterableRow contract from the
  // composable so the typed `useReviewFilters<Row>(source)` call doesn't
  // narrow `Row` away.
  [key: string]: unknown;
  approved?: number;
}

function makeRows(): Row[] {
  return [
    {
      entity_id: 1,
      category: 'Definitive',
      review_user_name: 'alice',
      re_review_review_saved: 0,
      re_review_status_saved: 0,
      status_id: 100,
    },
    {
      entity_id: 2,
      category: 'Moderate',
      review_user_name: 'bob',
      re_review_review_saved: 1,
      re_review_status_saved: 1,
      status_id: 101,
    },
    {
      entity_id: 3,
      category: 'Definitive',
      review_user_name: 'alice',
      re_review_review_saved: 1,
      re_review_status_saved: 0,
      status_id: 102,
      approved: 0,
    },
    {
      entity_id: 4,
      category: null,
      review_user_name: null,
      re_review_review_saved: 0,
      re_review_status_saved: 0,
      status_id: null,
    },
  ];
}

describe('useReviewFilters', () => {
  it('starts with no filters applied — filteredItems mirrors the source', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    expect(f.filteredItems.value).toHaveLength(4);
    expect(f.categoryFilter.value).toBeNull();
    expect(f.userFilter.value).toBeNull();
    expect(f.quickFilters.pending).toBe(false);
    expect(f.quickFilters.submitted).toBe(false);
    expect(f.quickFilters.needsStatus).toBe(false);
  });

  it('categoryFilter narrows to matching rows', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.categoryFilter.value = 'Definitive';
    expect(f.filteredItems.value).toHaveLength(2);
    expect(f.filteredItems.value.map((r) => r.entity_id)).toEqual([1, 3]);
  });

  it('userFilter narrows to matching reviewer', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.userFilter.value = 'alice';
    expect(f.filteredItems.value.map((r) => r.entity_id)).toEqual([1, 3]);
  });

  it('combined column filters apply AND-style', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.categoryFilter.value = 'Definitive';
    f.userFilter.value = 'alice';
    expect(f.filteredItems.value.map((r) => r.entity_id)).toEqual([1, 3]);

    f.userFilter.value = 'bob';
    expect(f.filteredItems.value).toHaveLength(0);
  });

  it('pending quick filter keeps rows with re_review_review_saved == 0', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.addQuickFilter('pending');
    expect(f.quickFilters.pending).toBe(true);
    expect(f.filteredItems.value.map((r) => r.entity_id)).toEqual([1, 4]);
  });

  it('submitted quick filter keeps saved-but-unapproved rows', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.addQuickFilter('submitted');
    // Rows 2 (saved=1, approved=undef) and 3 (saved=1, approved=0). Row 1+4
    // are unsaved (filtered out).
    const ids = f.filteredItems.value.map((r) => r.entity_id);
    expect(ids).toContain(2);
    expect(ids).toContain(3);
    expect(ids).not.toContain(1);
    expect(ids).not.toContain(4);
  });

  it('needsStatus quick filter keeps rows missing status_id or re_review_status_saved', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.addQuickFilter('needsStatus');
    // Row 2 has both status_id and re_review_status_saved=1 → out.
    // Row 4 has no status_id → in.
    // Rows 1 + 3 have re_review_status_saved=0 → in.
    const ids = f.filteredItems.value.map((r) => r.entity_id);
    expect(ids).toContain(1);
    expect(ids).toContain(3);
    expect(ids).toContain(4);
    expect(ids).not.toContain(2);
  });

  it('removeQuickFilter clears the toggle', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.addQuickFilter('pending');
    expect(f.quickFilters.pending).toBe(true);
    f.removeQuickFilter('pending');
    expect(f.quickFilters.pending).toBe(false);
  });

  it('activeQuickFilters and availableQuickFilters partition the definitions', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.addQuickFilter('pending');
    expect(f.activeQuickFilters.value.map((qf) => qf.key)).toEqual(['pending']);
    expect(f.availableQuickFilters.value.map((qf) => qf.key)).toEqual(['submitted', 'needsStatus']);

    f.addQuickFilter('submitted');
    expect(f.activeQuickFilters.value.map((qf) => qf.key)).toEqual(['pending', 'submitted']);
    expect(f.availableQuickFilters.value.map((qf) => qf.key)).toEqual(['needsStatus']);
  });

  it('categoryFilterOptions deduplicates and prepends the "All Categories" sentinel', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    const opts = f.categoryFilterOptions.value;
    expect(opts[0]).toEqual({ value: null, text: 'All Categories' });
    // Skip the "All Categories" sentinel (value === null) and assert on the
    // tail. Row 4's actual null category should be dropped during dedup.
    const tailValues = opts.slice(1).map((o) => o.value);
    expect(tailValues).toContain('Definitive');
    expect(tailValues).toContain('Moderate');
    expect(tailValues).not.toContain(null);
    // No duplicate Definitive.
    expect(tailValues.filter((v) => v === 'Definitive')).toHaveLength(1);
  });

  it('userFilterOptions deduplicates and prepends the "All Users" sentinel', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    const opts = f.userFilterOptions.value;
    expect(opts[0]).toEqual({ value: null, text: 'All Users' });
    const values = opts.map((o) => o.value);
    expect(values).toContain('alice');
    expect(values).toContain('bob');
  });

  it('reacts to source updates', () => {
    const source: Ref<Row[]> = ref(makeRows());
    const f = useReviewFilters(source);

    f.categoryFilter.value = 'Definitive';
    expect(f.filteredItems.value).toHaveLength(2);

    source.value = source.value.filter((r) => r.entity_id !== 3);
    expect(f.filteredItems.value).toHaveLength(1);
    expect(f.filteredItems.value[0].entity_id).toBe(1);
  });
});
