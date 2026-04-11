// useTableData.spec.ts
/**
 * Tests for useTableData composable
 *
 * Phase C unit C11 — pins `useTableData` reactive-state behavior before Phase
 * E4/E5 consume it. See `.plans/v11.0/phase-c.md` §3 C11.
 *
 * Pattern: Pure reactive-state composable testing
 * -----------------------------------------------
 * `useTableData` is a factory for independent per-instance reactive state —
 * it does NOT make any HTTP calls, it does NOT own a loadData callback, and
 * it does NOT depend on Vue lifecycle hooks. Each call returns a fresh set of
 * refs (items, totalRows, currentPage, currentItemID, perPage, sortBy, sort,
 * filter_string, filterOn, downloading, loading, isBusy) and two computed
 * properties (sortDesc, sortColumn, removeFiltersButton*). The consumer is
 * expected to wire mutations to a fetch externally (see useTableMethods).
 *
 * Scope per plan §3 C11: "sort, filter, pagination state transitions". Since
 * the composable contains no list-route fetch of its own, MSW handlers are
 * not required for these specs — the assertions are against the returned
 * refs and their derived computed properties. The network-assertion side of
 * the plan is covered by `useTableMethods.spec.ts`, where the callback
 * contract is exercised.
 *
 * Key learnings:
 * - Can be tested directly without withSetup (no lifecycle hooks used)
 * - Each useTableData() call creates independent refs (per-instance pattern)
 * - sortDesc is a two-way computed bound to sortBy[0].order
 * - sortColumn is a one-way computed derived from sortBy[0].key
 * - filter_string drives removeFiltersButton{Variant,Title} computeds
 */

import { describe, it, expect } from 'vitest';
import type { WritableComputedRef } from 'vue';
import useTableData from './useTableData';

describe('useTableData', () => {
  // ---------------------------------------------------------------------------
  // Factory + default state
  // ---------------------------------------------------------------------------

  describe('factory defaults', () => {
    it('returns refs and computeds for the documented surface', () => {
      const state = useTableData();

      // Core pagination state refs
      expect(state.items.value).toEqual([]);
      expect(state.totalRows.value).toBe(0);
      expect(state.currentPage.value).toBe(1);
      expect(state.currentItemID.value).toBe(0);
      expect(state.prevItemID.value).toBeNull();
      expect(state.nextItemID.value).toBeNull();
      expect(state.lastItemID.value).toBeNull();
      expect(state.executionTime.value).toBe(0);
      expect(state.perPage.value).toBe(10);
      expect(state.pageOptions.value).toEqual([10, 25, 50, 100]);

      // Sort + filter refs
      expect(state.sortBy.value).toEqual([]);
      expect(state.sort.value).toBe('');
      expect(state.filter_string.value).toBe('');
      expect(state.filterOn.value).toEqual([]);

      // Busy/loading refs
      expect(state.downloading.value).toBe(false);
      expect(state.loading.value).toBe(true);
      expect(state.isBusy.value).toBe(false);

      // Backward-compat computeds
      expect(state.sortDesc.value).toBe(false);
      expect(state.sortColumn.value).toBe('');
      expect(state.removeFiltersButtonVariant.value).toBe('info');
      expect(state.removeFiltersButtonTitle.value).toBe('The table is not filtered.');
    });

    it('honors pageAfterInput, pageSizeInput, and sortInput options', () => {
      const state = useTableData({
        pageAfterInput: 42,
        pageSizeInput: 25,
        sortInput: '+symbol',
      });

      expect(state.currentItemID.value).toBe(42);
      expect(state.perPage.value).toBe(25);
      expect(state.sort.value).toBe('+symbol');
    });

    it('coerces string options to numbers', () => {
      const state = useTableData({
        pageAfterInput: '17',
        pageSizeInput: '50',
      });

      expect(state.currentItemID.value).toBe(17);
      expect(state.perPage.value).toBe(50);
    });

    it('falls back to defaults when option values are 0 / empty / NaN', () => {
      const state = useTableData({
        pageAfterInput: 0,
        pageSizeInput: 0,
      });

      // 0 is falsy → falls through to default
      expect(state.currentItemID.value).toBe(0);
      expect(state.perPage.value).toBe(10);
    });

    it('creates independent per-instance state (no shared refs)', () => {
      const a = useTableData();
      const b = useTableData();

      a.currentPage.value = 3;
      a.filter_string.value = 'foo=bar';
      a.sortBy.value = [{ key: 'symbol', order: 'asc' }];

      expect(b.currentPage.value).toBe(1);
      expect(b.filter_string.value).toBe('');
      expect(b.sortBy.value).toEqual([]);
    });
  });

  // ---------------------------------------------------------------------------
  // Sort state transitions: default → asc → desc → cleared
  // ---------------------------------------------------------------------------

  describe('sort state transitions', () => {
    it('starts with empty sortBy, empty sortColumn, sortDesc=false', () => {
      const state = useTableData();

      expect(state.sortBy.value).toEqual([]);
      expect(state.sortColumn.value).toBe('');
      expect(state.sortDesc.value).toBe(false);
    });

    it('transitions default → asc: sortColumn updates, sortDesc stays false', () => {
      const state = useTableData();

      state.sortBy.value = [{ key: 'symbol', order: 'asc' }];

      expect(state.sortColumn.value).toBe('symbol');
      expect(state.sortDesc.value).toBe(false);
    });

    it('transitions asc → desc: sortDesc flips to true', () => {
      const state = useTableData();

      state.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      expect(state.sortDesc.value).toBe(false);

      state.sortBy.value = [{ key: 'symbol', order: 'desc' }];
      expect(state.sortDesc.value).toBe(true);
      expect(state.sortColumn.value).toBe('symbol');
    });

    it('transitions desc → cleared: sortColumn goes empty, sortDesc=false', () => {
      const state = useTableData();

      state.sortBy.value = [{ key: 'symbol', order: 'desc' }];
      expect(state.sortDesc.value).toBe(true);

      state.sortBy.value = [];
      expect(state.sortColumn.value).toBe('');
      expect(state.sortDesc.value).toBe(false);
    });

    it('sortDesc setter flips the first sortBy entry order (backward compat)', () => {
      const state = useTableData();
      // sortDesc is exposed as ComputedRef at the type level, but the
      // underlying computed has a setter for backward-compat callers that
      // still mutate sortDesc directly. Cast so TypeScript lets us exercise
      // the documented setter path.
      const sortDesc = state.sortDesc as unknown as WritableComputedRef<boolean>;

      state.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      sortDesc.value = true;

      expect(state.sortBy.value).toEqual([{ key: 'symbol', order: 'desc' }]);

      sortDesc.value = false;
      expect(state.sortBy.value).toEqual([{ key: 'symbol', order: 'asc' }]);
    });

    it('sortDesc setter is a no-op when sortBy is empty', () => {
      const state = useTableData();
      const sortDesc = state.sortDesc as unknown as WritableComputedRef<boolean>;

      sortDesc.value = true;

      expect(state.sortBy.value).toEqual([]);
      expect(state.sortDesc.value).toBe(false);
    });

    it('sortColumn returns only the first key when multiple sortBy entries exist', () => {
      const state = useTableData();

      state.sortBy.value = [
        { key: 'symbol', order: 'asc' },
        { key: 'disease', order: 'desc' },
      ];

      expect(state.sortColumn.value).toBe('symbol');
      expect(state.sortDesc.value).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // Filter state transitions: empty → applied → cleared
  // ---------------------------------------------------------------------------

  describe('filter state transitions', () => {
    it('starts with empty filter_string and info variant', () => {
      const state = useTableData();

      expect(state.filter_string.value).toBe('');
      expect(state.removeFiltersButtonVariant.value).toBe('info');
      expect(state.removeFiltersButtonTitle.value).toBe('The table is not filtered.');
    });

    it('transitions empty → applied: variant switches to warning, title updates', () => {
      const state = useTableData();

      state.filter_string.value = 'symbol=ARID1B';

      expect(state.removeFiltersButtonVariant.value).toBe('warning');
      expect(state.removeFiltersButtonTitle.value).toBe(
        'The table is filtered. Click to remove all filters.'
      );
    });

    it('transitions applied → cleared (empty string): variant returns to info', () => {
      const state = useTableData();

      state.filter_string.value = 'symbol=ARID1B';
      expect(state.removeFiltersButtonVariant.value).toBe('warning');

      state.filter_string.value = '';
      expect(state.removeFiltersButtonVariant.value).toBe('info');
      expect(state.removeFiltersButtonTitle.value).toBe('The table is not filtered.');
    });

    it('treats the literal string "null" as unfiltered', () => {
      const state = useTableData();

      state.filter_string.value = 'null';

      // Important: the literal word 'null' is a URL-marker for "no filter",
      // NOT an active filter. Both variant and title treat it as unfiltered.
      expect(state.removeFiltersButtonVariant.value).toBe('info');
      expect(state.removeFiltersButtonTitle.value).toBe('The table is not filtered.');
    });

    it('filterOn array can be mutated independently', () => {
      const state = useTableData();

      state.filterOn.value = ['symbol', 'disease'];

      expect(state.filterOn.value).toEqual(['symbol', 'disease']);

      state.filterOn.value = [];
      expect(state.filterOn.value).toEqual([]);
    });
  });

  // ---------------------------------------------------------------------------
  // Pagination state transitions: page 1 → next → prev → jump to last
  // ---------------------------------------------------------------------------

  describe('pagination state transitions', () => {
    it('starts on page 1 with currentItemID=0', () => {
      const state = useTableData();

      expect(state.currentPage.value).toBe(1);
      expect(state.currentItemID.value).toBe(0);
    });

    it('can advance currentPage and currentItemID (simulating next)', () => {
      const state = useTableData();

      // After a page load: page 1 known next ID is 25
      state.nextItemID.value = 25;

      // Advance
      state.currentPage.value = 2;
      state.currentItemID.value = state.nextItemID.value as number;

      expect(state.currentPage.value).toBe(2);
      expect(state.currentItemID.value).toBe(25);
    });

    it('can walk back using prevItemID (simulating previous)', () => {
      const state = useTableData();

      state.currentPage.value = 2;
      state.currentItemID.value = 25;
      state.prevItemID.value = 0;

      // Go back one page
      state.currentPage.value = 1;
      state.currentItemID.value = state.prevItemID.value as number;

      expect(state.currentPage.value).toBe(1);
      expect(state.currentItemID.value).toBe(0);
    });

    it('can jump to last using lastItemID', () => {
      const state = useTableData();

      state.lastItemID.value = 9000;
      state.totalRows.value = 9100;

      state.currentPage.value = Math.ceil(state.totalRows.value / state.perPage.value);
      state.currentItemID.value = state.lastItemID.value as number;

      expect(state.currentPage.value).toBe(910);
      expect(state.currentItemID.value).toBe(9000);
    });

    it('perPage changes do not coerce types (caller responsibility)', () => {
      const state = useTableData();

      state.perPage.value = 50;

      expect(state.perPage.value).toBe(50);
      // Pagination pointers are independent refs; changing perPage does not
      // reset them (that's useTableMethods.handlePerPageChange's job).
      expect(state.currentItemID.value).toBe(0);
    });

    it('pageOptions is mutable for components that customise sizes', () => {
      const state = useTableData();

      state.pageOptions.value = [5, 10, 20];

      expect(state.pageOptions.value).toEqual([5, 10, 20]);
    });
  });

  // ---------------------------------------------------------------------------
  // Busy / loading flags
  // ---------------------------------------------------------------------------

  describe('busy flags', () => {
    it('loading defaults to true and can be toggled', () => {
      const state = useTableData();

      expect(state.loading.value).toBe(true);

      state.loading.value = false;
      expect(state.loading.value).toBe(false);
    });

    it('isBusy and downloading default to false and can be toggled', () => {
      const state = useTableData();

      expect(state.isBusy.value).toBe(false);
      expect(state.downloading.value).toBe(false);

      state.isBusy.value = true;
      state.downloading.value = true;

      expect(state.isBusy.value).toBe(true);
      expect(state.downloading.value).toBe(true);
    });
  });
});
