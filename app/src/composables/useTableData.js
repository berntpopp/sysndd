import { ref, computed } from 'vue';

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
 * @param {Object} options - Configuration options
 * @param {string} options.pageAfterInput - Initial item ID for pagination
 * @param {number} options.pageSizeInput - Initial page size
 * @param {string} options.sortInput - Initial sort configuration
 * @returns {Object} Reactive table state and computed properties
 */
export default function useTableData(options = {}) {
  // Reactive state
  const items = ref([]);
  const totalRows = ref(0);
  const currentPage = ref(1);
  const currentItemID = ref(options.pageAfterInput || 0);
  const prevItemID = ref(null);
  const nextItemID = ref(null);
  const lastItemID = ref(null);
  const executionTime = ref(0);
  const perPage = ref(Number(options.pageSizeInput) || 10);
  const pageOptions = ref([10, 25, 50, 100]);
  // Bootstrap-Vue-Next uses array-based sortBy: [{ key: 'column', order: 'asc'|'desc' }]
  const sortBy = ref([]);
  const sort = ref(options.sortInput || '');
  // Note: filter is defined in each component with its specific structure
  // Do NOT define filter here to avoid Vue 3 OPTIONS_DATA_MERGE warning
  const filter_string = ref('');
  const filterOn = ref([]);
  const downloading = ref(false);
  const loading = ref(true);
  const isBusy = ref(false);

  /**
   * Backward compatibility: derive sortDesc from sortBy array.
   * Returns true if the first sort column is descending.
   */
  const sortDesc = computed({
    get() {
      return sortBy.value.length > 0 && sortBy.value[0].order === 'desc';
    },
    set(value) {
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
  const sortColumn = computed(() => (sortBy.value.length > 0 ? sortBy.value[0].key : ''));

  /**
   * Determines the button variant based on filter state.
   */
  const removeFiltersButtonVariant = computed(() => (filter_string.value === '' || filter_string.value === null || filter_string.value === 'null' ? 'info' : 'warning'));

  /**
   * Generates the button title text based on filter state.
   */
  const removeFiltersButtonTitle = computed(() => {
    let title = 'The table is ';
    title += (filter_string.value === '' || filter_string.value === null || filter_string.value === 'null') ? 'not ' : '';
    title += 'filtered.';
    if (filter_string.value !== '' && filter_string.value !== null && filter_string.value !== 'null') {
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
