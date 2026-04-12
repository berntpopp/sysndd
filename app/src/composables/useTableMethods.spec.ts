// useTableMethods.spec.ts
/**
 * Tests for useTableMethods composable
 *
 * Phase C unit C11 — pins `useTableMethods` behavior (dependency-injected
 * table action methods) before Phase E4/E5 consume it. See
 * `.plans/v11.0/phase-c.md` §3 C11.
 *
 * Pattern: Dependency-injected composable testing
 * ------------------------------------------------
 * `useTableMethods` is a factory that accepts a `TableDataState` object
 * (from `useTableData`) plus component-specific options:
 *   - `filter` / `filterObjToStr` — used by `filtered`/`removeFilters`/`removeSearch`
 *   - `loadData` — the "re-fetch" callback injected by the consumer
 *   - `apiEndpoint` + `axios` — used only by `requestExcel` for blob downloads
 *   - `updateUrl` — controls whether methods call `history.replaceState`
 *
 * Important: the composable itself does NOT make any list-route HTTP calls.
 * Its public methods either mutate the injected `tableData` refs, call the
 * injected `loadData` callback, or (for `requestExcel`) call the injected
 * `axios` instance with an endpoint the caller provides. Because there is no
 * list-route fetch inside the composable, no MSW handler is required — the
 * "network" contract is the injected callback, which we assert against a
 * `vi.fn()` stub (the test-level equivalent of a network assertion).
 *
 * Scope per plan §3 C11: "sort, filter, pagination state transitions". The
 * three handler methods (`handleSortByOrDescChange`, `handlePerPageChange`,
 * `handlePageChange`) each write state + call `loadData` + (optionally)
 * update the URL, so each transition is asserted on all three axes.
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ref } from 'vue';

// Mock bootstrap-vue-next BEFORE importing the composable (hoisted).
// useTableMethods imports useToast which wraps bootstrap-vue-next's useToast.
// We also need it stubbed for requestExcel's error toast path.
const mockToastCreate = vi.fn();
vi.mock('bootstrap-vue-next', () => ({
  useToast: () => ({
    create: mockToastCreate,
  }),
}));

// Stub Vite env for requestExcel's URL construction.
vi.stubEnv('VITE_URL', 'https://sysndd.test');
vi.stubEnv('VITE_API_URL', 'https://sysndd.test');

import useTableData from './useTableData';
import useTableMethods from './useTableMethods';

/**
 * Helper: build a fresh tableData with known fixture state for pagination tests.
 */
function makeTableData() {
  const td = useTableData();
  td.totalRows.value = 100;
  td.perPage.value = 10;
  td.currentPage.value = 1;
  td.currentItemID.value = 0;
  td.prevItemID.value = null;
  td.nextItemID.value = 10;
  td.lastItemID.value = 90;
  return td;
}

describe('useTableMethods', () => {
  // Snapshot history + URL for restoration after tests that mutate them.
  let originalReplaceState: typeof window.history.replaceState;
  let originalPathname: string;

  beforeEach(() => {
    mockToastCreate.mockClear();
    originalReplaceState = window.history.replaceState.bind(window.history);
    originalPathname = window.location.pathname;
  });

  afterEach(() => {
    // Restore history.replaceState in case a test stubbed it.
    window.history.replaceState = originalReplaceState;
    // Restore URL so tests don't bleed into each other.
    window.history.replaceState({}, '', originalPathname);
  });

  // ---------------------------------------------------------------------------
  // Factory + surface
  // ---------------------------------------------------------------------------

  describe('factory surface', () => {
    it('returns the documented set of methods', () => {
      const td = useTableData();
      const methods = useTableMethods(td);

      expect(typeof methods.copyLinkToClipboard).toBe('function');
      expect(typeof methods.handleSortByOrDescChange).toBe('function');
      expect(typeof methods.handlePerPageChange).toBe('function');
      expect(typeof methods.handlePageChange).toBe('function');
      expect(typeof methods.filtered).toBe('function');
      expect(typeof methods.removeFilters).toBe('function');
      expect(typeof methods.removeSearch).toBe('function');
      expect(typeof methods.requestExcel).toBe('function');
      expect(typeof methods.truncate).toBe('function');
      expect(typeof methods.normalizer).toBe('function');
      expect(typeof methods.handleSortUpdate).toBe('function');
      expect(typeof methods.handleSortByUpdate).toBe('function');
    });
  });

  // ---------------------------------------------------------------------------
  // Sort state transitions: default → asc → desc → cleared
  // ---------------------------------------------------------------------------

  describe('sort state transitions', () => {
    it('handleSortByUpdate writes the new sortBy array and nothing else', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handleSortByUpdate([{ key: 'symbol', order: 'asc' }]);

      expect(td.sortBy.value).toEqual([{ key: 'symbol', order: 'asc' }]);
      // Docstring says "handleSortByOrDescChange will be triggered by watcher"
      // — so this method itself does NOT call loadData directly.
      expect(loadData).not.toHaveBeenCalled();
    });

    it('handleSortByOrDescChange: default → asc writes sort="+col", resets cursor, calls loadData', () => {
      const td = useTableData();
      td.currentItemID.value = 42; // stale cursor from a previous page
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      td.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      methods.handleSortByOrDescChange();

      expect(td.sort.value).toBe('+symbol');
      expect(td.currentItemID.value).toBe(0);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('asc → desc writes sort="-col" and re-invokes loadData', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      td.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      methods.handleSortByOrDescChange();
      expect(td.sort.value).toBe('+symbol');

      td.sortBy.value = [{ key: 'symbol', order: 'desc' }];
      methods.handleSortByOrDescChange();

      expect(td.sort.value).toBe('-symbol');
      expect(loadData).toHaveBeenCalledTimes(2);
    });

    it('desc → cleared writes sort="+" (empty column) and resets cursor', () => {
      const td = useTableData();
      td.currentItemID.value = 25;
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      td.sortBy.value = [{ key: 'symbol', order: 'desc' }];
      methods.handleSortByOrDescChange();
      expect(td.sort.value).toBe('-symbol');

      // Clear sort (empty array)
      td.sortBy.value = [];
      td.currentItemID.value = 25; // simulate mid-page
      methods.handleSortByOrDescChange();

      // With empty sortBy the composable coerces to '+' (empty column name).
      // This is intentional per current contract; pinning it here so any
      // future refactor has to acknowledge the change.
      expect(td.sort.value).toBe('+');
      expect(td.currentItemID.value).toBe(0);
      expect(loadData).toHaveBeenCalledTimes(2);
    });

    it('handleSortUpdate converts legacy {sortBy, sortDesc} to array format', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handleSortUpdate({ sortBy: 'symbol', sortDesc: true });
      expect(td.sortBy.value).toEqual([{ key: 'symbol', order: 'desc' }]);

      methods.handleSortUpdate({ sortBy: 'disease', sortDesc: false });
      expect(td.sortBy.value).toEqual([{ key: 'disease', order: 'asc' }]);

      // Docstring: "handleSortByOrDescChange will be triggered by watcher"
      expect(loadData).not.toHaveBeenCalled();
    });

    it('handleSortByOrDescChange is a no-op for loadData if callback missing', () => {
      const td = useTableData();
      const methods = useTableMethods(td, { updateUrl: false });

      td.sortBy.value = [{ key: 'symbol', order: 'asc' }];

      // Must not throw even though loadData is not provided.
      expect(() => methods.handleSortByOrDescChange()).not.toThrow();
      expect(td.sort.value).toBe('+symbol');
    });
  });

  // ---------------------------------------------------------------------------
  // Filter state transitions: empty → applied → cleared
  // ---------------------------------------------------------------------------

  describe('filter state transitions', () => {
    const makeEmptyFilter = () => ({
      any: { content: null, operator: '=', join_char: null },
      symbol: { content: null, operator: '=', join_char: null },
    });

    it('filtered: empty → serialized filter_string is applied and loadData called', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const filter = makeEmptyFilter();
      filter.symbol.content = 'ARID1B';

      const methods = useTableMethods(td, {
        filter,
        filterObjToStr: (f) =>
          Object.entries(f)
            .filter(([, v]) => v && v.content !== null)
            .map(([k, v]) => `${k}=${String(v.content)}`)
            .join('&'),
        loadData,
        updateUrl: false,
      });

      methods.filtered();

      expect(td.filter_string.value).toBe('symbol=ARID1B');
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('filtered: supports ref-wrapped filter (isRef branch)', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const filterRef = ref(makeEmptyFilter());
      filterRef.value.symbol.content = 'FOXG1';

      const methods = useTableMethods(td, {
        filter: filterRef,
        filterObjToStr: (f) =>
          Object.entries(f)
            .filter(([, v]) => v && v.content !== null)
            .map(([k, v]) => `${k}=${String(v.content)}`)
            .join('&'),
        loadData,
        updateUrl: false,
      });

      methods.filtered();

      expect(td.filter_string.value).toBe('symbol=FOXG1');
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('filtered: short-circuits (no mutation, no loadData) when filterObjToStr is missing', () => {
      const td = useTableData();
      td.filter_string.value = 'old=value';
      const loadData = vi.fn();
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

      const methods = useTableMethods(td, {
        filter: makeEmptyFilter(),
        loadData,
        updateUrl: false,
      });

      methods.filtered();

      expect(td.filter_string.value).toBe('old=value');
      expect(loadData).not.toHaveBeenCalled();
      expect(warnSpy).toHaveBeenCalled();
      warnSpy.mockRestore();
    });

    it('filtered: does not re-write filter_string when the serialized value is unchanged', () => {
      const td = useTableData();
      td.filter_string.value = 'symbol=ARID1B';
      const loadData = vi.fn();

      const filter = makeEmptyFilter();
      filter.symbol.content = 'ARID1B';

      const methods = useTableMethods(td, {
        filter,
        filterObjToStr: () => 'symbol=ARID1B',
        loadData,
        updateUrl: false,
      });

      methods.filtered();

      expect(td.filter_string.value).toBe('symbol=ARID1B');
      // loadData is still called even when the string is unchanged — the
      // contract is "filtered() always refetches" so that components can
      // retry after errors without having to touch state first.
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('removeFilters: applied → cleared wipes content on every filter field and calls loadData', () => {
      const td = useTableData();
      td.filter_string.value = 'symbol=ARID1B&any=foo';
      const loadData = vi.fn();

      const filter = makeEmptyFilter();
      filter.symbol.content = 'ARID1B';
      filter.any.content = 'foo';

      const methods = useTableMethods(td, {
        filter,
        filterObjToStr: (f) =>
          Object.entries(f)
            .filter(([, v]) => v && v.content !== null)
            .map(([k, v]) => `${k}=${String(v.content)}`)
            .join('&'),
        loadData,
        updateUrl: false,
      });

      methods.removeFilters();

      expect(filter.symbol.content).toBeNull();
      expect(filter.any.content).toBeNull();
      expect(td.filter_string.value).toBe('');
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('removeSearch: clears only the "any" field and calls loadData via filtered', () => {
      const td = useTableData();
      const loadData = vi.fn();

      const filter = makeEmptyFilter();
      filter.any.content = 'global search';
      filter.symbol.content = 'ARID1B';

      const methods = useTableMethods(td, {
        filter,
        filterObjToStr: (f) =>
          Object.entries(f)
            .filter(([, v]) => v && v.content !== null)
            .map(([k, v]) => `${k}=${String(v.content)}`)
            .join('&'),
        loadData,
        updateUrl: false,
      });

      methods.removeSearch();

      expect(filter.any.content).toBeNull();
      expect(filter.symbol.content).toBe('ARID1B'); // unchanged
      expect(td.filter_string.value).toBe('symbol=ARID1B');
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('removeSearch: silently no-ops when filter has no "any" field', () => {
      const td = useTableData();
      const loadData = vi.fn();

      const filter: Record<
        string,
        { content: string | null; operator: string; join_char: string | null }
      > = {
        symbol: { content: 'ARID1B', operator: '=', join_char: null },
      };

      const methods = useTableMethods(td, {
        filter,
        filterObjToStr: () => 'symbol=ARID1B',
        loadData,
        updateUrl: false,
      });

      methods.removeSearch();

      // No 'any' key → silently returns without invoking filtered()/loadData.
      expect(loadData).not.toHaveBeenCalled();
      expect(td.filter_string.value).toBe('');
    });

    it('removeFilters: warns and no-ops when filter option is not provided', () => {
      const td = useTableData();
      const loadData = vi.fn();
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.removeFilters();

      expect(loadData).not.toHaveBeenCalled();
      expect(warnSpy).toHaveBeenCalled();
      warnSpy.mockRestore();
    });
  });

  // ---------------------------------------------------------------------------
  // Pagination state transitions: page 1 → next → prev → jump to last
  // ---------------------------------------------------------------------------

  describe('pagination state transitions', () => {
    it('page 1 → next: writes nextItemID onto currentItemID and calls loadData', () => {
      const td = makeTableData();
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      // Bootstrap-Vue-Next pagination reports currentPage already advanced
      // (the composable reads from tableData.currentPage.value to decide
      // direction), so caller bumps currentPage before calling handlePageChange.
      td.currentPage.value = 1; // previous page
      methods.handlePageChange(2);

      expect(td.currentItemID.value).toBe(10); // nextItemID
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('next → previous: writes prevItemID onto currentItemID', () => {
      const td = makeTableData();
      td.currentPage.value = 2;
      td.currentItemID.value = 10;
      td.prevItemID.value = 0;
      td.nextItemID.value = 20;
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePageChange(1);

      // value === 1 → special-case: currentItemID = 0
      expect(td.currentItemID.value).toBe(0);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('middle → previous (not page 1): writes prevItemID onto currentItemID', () => {
      const td = makeTableData();
      td.currentPage.value = 5;
      td.currentItemID.value = 40;
      td.prevItemID.value = 30;
      td.nextItemID.value = 50;
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePageChange(4);

      expect(td.currentItemID.value).toBe(30);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('jump to last page: writes lastItemID onto currentItemID', () => {
      const td = makeTableData();
      // totalRows=100, perPage=10 → totalPages=10
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePageChange(10);

      expect(td.currentItemID.value).toBe(90); // lastItemID
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('jump to first page (value === 1) always resets currentItemID to 0', () => {
      const td = makeTableData();
      td.currentPage.value = 5;
      td.currentItemID.value = 40;
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePageChange(1);

      expect(td.currentItemID.value).toBe(0);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('handlePerPageChange: coerces to int, resets cursor to 0, calls loadData', () => {
      const td = makeTableData();
      td.currentItemID.value = 40;
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePerPageChange('25');

      expect(td.perPage.value).toBe(25);
      expect(td.currentItemID.value).toBe(0);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('handlePerPageChange: numeric input is also honored', () => {
      const td = makeTableData();
      const loadData = vi.fn();
      const methods = useTableMethods(td, { loadData, updateUrl: false });

      methods.handlePerPageChange(50);

      expect(td.perPage.value).toBe(50);
      expect(loadData).toHaveBeenCalledTimes(1);
    });

    it('handlePageChange tolerates missing loadData callback', () => {
      const td = makeTableData();
      const methods = useTableMethods(td, { updateUrl: false });

      expect(() => methods.handlePageChange(2)).not.toThrow();
      expect(td.currentItemID.value).toBe(10);
    });
  });

  // ---------------------------------------------------------------------------
  // URL side effect (history.replaceState)
  // ---------------------------------------------------------------------------

  describe('browser URL synchronization', () => {
    it('handleSortByOrDescChange calls history.replaceState with the new sort query (default updateUrl=true)', () => {
      const td = useTableData();
      const replaceSpy = vi
        .spyOn(window.history, 'replaceState')
        .mockImplementation(() => {});
      const methods = useTableMethods(td); // updateUrl defaults to true

      td.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      methods.handleSortByOrDescChange();

      expect(replaceSpy).toHaveBeenCalledTimes(1);
      const lastCall = replaceSpy.mock.calls[0];
      expect(lastCall[2]).toContain('sort=%2Bsymbol'); // URLSearchParams encodes '+'
    });

    it('does not call history.replaceState when updateUrl is false', () => {
      const td = useTableData();
      const replaceSpy = vi
        .spyOn(window.history, 'replaceState')
        .mockImplementation(() => {});
      const methods = useTableMethods(td, { updateUrl: false });

      td.sortBy.value = [{ key: 'symbol', order: 'asc' }];
      methods.handleSortByOrDescChange();

      expect(replaceSpy).not.toHaveBeenCalled();
    });
  });

  // ---------------------------------------------------------------------------
  // copyLinkToClipboard
  // ---------------------------------------------------------------------------

  describe('copyLinkToClipboard', () => {
    it('writes a URL combining sort, filter, page_after, and page_size', () => {
      const td = useTableData();
      td.sort.value = '+symbol';
      td.filter_string.value = 'any=foo';
      td.currentItemID.value = 25;
      td.perPage.value = 50;

      const writeText = vi.fn();
      Object.defineProperty(navigator, 'clipboard', {
        configurable: true,
        value: { writeText },
      });

      const methods = useTableMethods(td, { updateUrl: false });
      methods.copyLinkToClipboard();

      expect(writeText).toHaveBeenCalledTimes(1);
      const [url] = writeText.mock.calls[0];
      expect(url).toContain('sort=+symbol');
      expect(url).toContain('filter=any=foo');
      expect(url).toContain('page_after=25');
      expect(url).toContain('page_size=50');
    });
  });

  // ---------------------------------------------------------------------------
  // requestExcel — uses injected axios, no list-route network call
  // ---------------------------------------------------------------------------

  describe('requestExcel', () => {
    it('calls the injected axios with a blob responseType and toggles downloading', async () => {
      const td = useTableData();
      td.sort.value = '+symbol';
      td.filter_string.value = 'any=foo';

      const axiosStub = vi.fn().mockResolvedValue({ data: new Blob(['x'], { type: 'text/plain' }) });
      const methods = useTableMethods(td, {
        apiEndpoint: 'user/table',
        axios: axiosStub as unknown as import('axios').AxiosInstance,
        updateUrl: false,
      });

      // Stub DOM APIs that jsdom doesn't implement for blob downloads.
      const createObjectURL = vi.fn().mockReturnValue('blob:mock');
      const revokeObjectURL = vi.fn();
      window.URL.createObjectURL = createObjectURL;
      window.URL.revokeObjectURL = revokeObjectURL;

      await methods.requestExcel();

      expect(axiosStub).toHaveBeenCalledTimes(1);
      const call = axiosStub.mock.calls[0][0];
      expect(call.method).toBe('GET');
      expect(call.responseType).toBe('blob');
      expect(call.url).toContain('/api/user/table');
      expect(call.url).toContain('format=xlsx');
      // Final state after resolution: downloading flipped back to false
      expect(td.downloading.value).toBe(false);
      expect(createObjectURL).toHaveBeenCalledTimes(1);
      expect(revokeObjectURL).toHaveBeenCalledTimes(1);
    });

    it('routes axios errors through the toast and still clears downloading', async () => {
      const td = useTableData();
      const axiosStub = vi.fn().mockRejectedValue(new Error('boom'));
      const methods = useTableMethods(td, {
        apiEndpoint: 'user/table',
        axios: axiosStub as unknown as import('axios').AxiosInstance,
        updateUrl: false,
      });

      await methods.requestExcel();

      expect(mockToastCreate).toHaveBeenCalledTimes(1);
      expect(td.downloading.value).toBe(false);
    });

    it('warns and no-ops when axios or apiEndpoint are missing', async () => {
      const td = useTableData();
      const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
      const methods = useTableMethods(td, { updateUrl: false });

      await methods.requestExcel();

      expect(warnSpy).toHaveBeenCalled();
      expect(td.downloading.value).toBe(false);
      warnSpy.mockRestore();
    });
  });

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  describe('truncate', () => {
    it('returns the string unchanged when shorter than n', () => {
      const td = useTableData();
      const { truncate } = useTableMethods(td, { updateUrl: false });

      expect(truncate('hello', 10)).toBe('hello');
    });

    it('truncates and appends ellipsis when longer than n', () => {
      const td = useTableData();
      const { truncate } = useTableMethods(td, { updateUrl: false });

      expect(truncate('hello world', 6)).toBe('hello...');
    });
  });

  describe('normalizer', () => {
    it('maps a string to { id, label } with the same value for both', () => {
      const td = useTableData();
      const { normalizer } = useTableMethods(td, { updateUrl: false });

      expect(normalizer('ARID1B')).toEqual({ id: 'ARID1B', label: 'ARID1B' });
    });
  });
});
