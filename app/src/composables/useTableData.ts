import type { Ref, ComputedRef } from 'vue';
import { ref, computed } from 'vue';
import type { SortBy } from '@/types/components';

/**
 * Composable for table data state management.
 * Each call creates independent state (per-instance pattern).
 *
 * Note: For Bootstrap-Vue-Next, sortBy is an array of objects:
 * [{ key: 'column_name', order: 'asc' | 'desc' }]
 *
 * The sortDesc computed property is provided for backward compatibility
 * with existing code that references sortDesc directly.
 *
 * @param options - Configuration options
 * @param options.pageAfterInput - Initial item ID for pagination
 * @param options.pageSizeInput - Initial page size
 * @param options.sortInput - Initial sort configuration
 * @returns Reactive table state and computed properties
 */

interface TableDataOptions {
  pageAfterInput?: number | string;
  pageSizeInput?: number | string;
  sortInput?: string;
}

interface TableDataState {
  items: Ref<unknown[]>;
  totalRows: Ref<number>;
  currentPage: Ref<number>;
  currentItemID: Ref<number>;
  prevItemID: Ref<number | null>;
  nextItemID: Ref<number | null>;
  lastItemID: Ref<number | null>;
  executionTime: Ref<number>;
  perPage: Ref<number>;
  pageOptions: Ref<number[]>;
  sortBy: Ref<SortBy[]>;
  sort: Ref<string>;
  filter_string: Ref<string>;
  filterOn: Ref<string[]>;
  downloading: Ref<boolean>;
  loading: Ref<boolean>;
  isBusy: Ref<boolean>;
  sortDesc: ComputedRef<boolean>;
  sortColumn: ComputedRef<string>;
  removeFiltersButtonVariant: ComputedRef<string>;
  removeFiltersButtonTitle: ComputedRef<string>;
}

export default function useTableData(options: TableDataOptions = {}): TableDataState {
  // Reactive state
  const items = ref<unknown[]>([]);
  const totalRows = ref<number>(0);
  const currentPage = ref<number>(1);
  const currentItemID = ref<number>(Number(options.pageAfterInput) || 0);
  const prevItemID = ref<number | null>(null);
  const nextItemID = ref<number | null>(null);
  const lastItemID = ref<number | null>(null);
  const executionTime = ref<number>(0);
  const perPage = ref<number>(Number(options.pageSizeInput) || 10);
  const pageOptions = ref<number[]>([10, 25, 50, 100]);
  // Bootstrap-Vue-Next uses array-based sortBy: [{ key: 'column', order: 'asc'|'desc' }]
  const sortBy = ref<SortBy[]>([]);
  const sort = ref<string>(options.sortInput || '');
  // Note: filter is defined in each component with its specific structure
  // Do NOT define filter here to avoid Vue 3 OPTIONS_DATA_MERGE warning
  const filter_string = ref<string>('');
  const filterOn = ref<string[]>([]);
  const downloading = ref<boolean>(false);
  const loading = ref<boolean>(true);
  const isBusy = ref<boolean>(false);

  /**
   * Backward compatibility: derive sortDesc from sortBy array.
   * Returns true if the first sort column is descending.
   */
  const sortDesc = computed<boolean>({
    get() {
      return sortBy.value.length > 0 && sortBy.value[0].order === 'desc';
    },
    set(value: boolean) {
      // Allow setting sortDesc for backward compatibility
      if (sortBy.value.length > 0) {
        sortBy.value = [{ key: sortBy.value[0].key, order: value ? 'desc' : 'asc' }];
      }
    },
  });

  /**
   * Backward compatibility: derive sortColumn from sortBy array.
   * Returns the key of the first sort column.
   */
  const sortColumn = computed<string>(() => (sortBy.value.length > 0 ? sortBy.value[0].key : ''));

  /**
   * Determines the button variant based on filter state.
   */
  const removeFiltersButtonVariant = computed<string>(() =>
    filter_string.value === '' || filter_string.value === null || filter_string.value === 'null'
      ? 'info'
      : 'warning'
  );

  /**
   * Generates the button title text based on filter state.
   */
  const removeFiltersButtonTitle = computed<string>(() => {
    let title = 'The table is ';
    title +=
      filter_string.value === '' || filter_string.value === null || filter_string.value === 'null'
        ? 'not '
        : '';
    title += 'filtered.';
    if (
      filter_string.value !== '' &&
      filter_string.value !== null &&
      filter_string.value !== 'null'
    ) {
      title += ' Click to remove all filters.';
    }
    return title;
  });

  return {
    items,
    totalRows,
    currentPage,
    currentItemID,
    prevItemID,
    nextItemID,
    lastItemID,
    executionTime,
    perPage,
    pageOptions,
    sortBy,
    sort,
    filter_string,
    filterOn,
    downloading,
    loading,
    isBusy,
    sortDesc,
    sortColumn,
    removeFiltersButtonVariant,
    removeFiltersButtonTitle,
  };
}

// Export TableDataState type for use in components
export type { TableDataState };
