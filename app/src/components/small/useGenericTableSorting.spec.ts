import { reactive } from 'vue';
import { describe, expect, it, vi } from 'vitest';
import {
  normalizeSortBy,
  useGenericTableSorting,
  type GenericTableSortingProps,
} from './useGenericTableSorting';

/**
 * Builds a reactive props object plus a spy emit, mirroring how
 * GenericDesktopTable wires the composable to its declared props/emits.
 */
function setup(initial: Partial<GenericTableSortingProps> = {}) {
  const props = reactive<GenericTableSortingProps>({
    sortBy: initial.sortBy ?? [],
    sortDesc: initial.sortDesc ?? false,
  });
  const emit = vi.fn();
  const sorting = useGenericTableSorting(props, emit);
  return { props, emit, sorting };
}

describe('normalizeSortBy', () => {
  it('returns array sortBy as-is', () => {
    const arr = [{ key: 'symbol', order: 'desc' as const }];
    expect(normalizeSortBy(arr, false)).toBe(arr);
  });

  it('converts a legacy string with asc default to array form', () => {
    expect(normalizeSortBy('symbol', false)).toEqual([{ key: 'symbol', order: 'asc' }]);
  });

  it('converts a legacy string with sortDesc to descending array form', () => {
    expect(normalizeSortBy('symbol', true)).toEqual([{ key: 'symbol', order: 'desc' }]);
  });

  it('returns an empty array for an empty string', () => {
    expect(normalizeSortBy('', false)).toEqual([]);
  });

  it('returns an empty array for nullish input', () => {
    expect(normalizeSortBy(undefined as unknown as string, false)).toEqual([]);
  });
});

describe('useGenericTableSorting - localSortBy', () => {
  it('reflects the current array prop reactively', () => {
    const { props, sorting } = setup({ sortBy: [{ key: 'symbol', order: 'asc' }] });
    expect(sorting.localSortBy.value).toEqual([{ key: 'symbol', order: 'asc' }]);
    props.sortBy = [{ key: 'category', order: 'desc' }];
    expect(sorting.localSortBy.value).toEqual([{ key: 'category', order: 'desc' }]);
  });

  it('normalizes a legacy string + sortDesc prop', () => {
    const { sorting } = setup({ sortBy: 'symbol', sortDesc: true });
    expect(sorting.localSortBy.value).toEqual([{ key: 'symbol', order: 'desc' }]);
  });
});

describe('useGenericTableSorting - handleHeadClicked', () => {
  it('starts a new column ascending and emits both events', () => {
    const { emit, sorting } = setup();
    sorting.handleHeadClicked('symbol', { sortable: true }, new Event('click'));
    expect(emit).toHaveBeenCalledWith('update:sort-by', [{ key: 'symbol', order: 'asc' }]);
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'symbol', sortDesc: false });
  });

  it('toggles the same column from asc to desc', () => {
    const { emit, sorting } = setup({ sortBy: [{ key: 'symbol', order: 'asc' }] });
    sorting.handleHeadClicked('symbol', { sortable: true });
    expect(emit).toHaveBeenCalledWith('update:sort-by', [{ key: 'symbol', order: 'desc' }]);
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'symbol', sortDesc: true });
  });

  it('toggles the same column back from desc to asc', () => {
    const { emit, sorting } = setup({ sortBy: [{ key: 'symbol', order: 'desc' }] });
    sorting.handleHeadClicked('symbol', { sortable: true });
    expect(emit).toHaveBeenCalledWith('update:sort-by', [{ key: 'symbol', order: 'asc' }]);
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'symbol', sortDesc: false });
  });

  it('normalizes a legacy string prop before toggling', () => {
    const { emit, sorting } = setup({ sortBy: 'symbol', sortDesc: false });
    sorting.handleHeadClicked('symbol', { sortable: true });
    expect(emit).toHaveBeenCalledWith('update:sort-by', [{ key: 'symbol', order: 'desc' }]);
  });

  it('is a no-op for a non-sortable column', () => {
    const { emit, sorting } = setup();
    sorting.handleHeadClicked('symbol', { sortable: false });
    expect(emit).not.toHaveBeenCalled();
  });

  it('is a no-op when the field definition is missing', () => {
    const { emit, sorting } = setup();
    sorting.handleHeadClicked('symbol', undefined);
    expect(emit).not.toHaveBeenCalled();
  });
});

describe('useGenericTableSorting - handleSortByUpdate', () => {
  it('emits both events for a keyed sort update', () => {
    const { emit, sorting } = setup();
    sorting.handleSortByUpdate([{ key: 'category', order: 'desc' }]);
    expect(emit).toHaveBeenCalledWith('update:sort-by', [{ key: 'category', order: 'desc' }]);
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'category', sortDesc: true });
  });

  it('emits only update:sort-by when the update is empty', () => {
    const { emit, sorting } = setup();
    sorting.handleSortByUpdate([]);
    expect(emit).toHaveBeenCalledWith('update:sort-by', []);
    expect(emit).not.toHaveBeenCalledWith('update-sort', expect.anything());
  });
});

describe('useGenericTableSorting - handleSorted', () => {
  it('emits update-sort for an array sort context', () => {
    const { emit, sorting } = setup();
    sorting.handleSorted({ sortBy: [{ key: 'symbol', order: 'desc' }] });
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'symbol', sortDesc: true });
  });

  it('emits update-sort for a legacy scalar sort context', () => {
    const { emit, sorting } = setup();
    sorting.handleSorted({ sortBy: 'symbol', sortDesc: true });
    expect(emit).toHaveBeenCalledWith('update-sort', { sortBy: 'symbol', sortDesc: true });
  });

  it('ignores a context without a sortBy', () => {
    const { emit, sorting } = setup();
    sorting.handleSorted({});
    expect(emit).not.toHaveBeenCalled();
  });
});
