// tableDataMixin.js
/**
 * Mixin for shared data properties in table components.
 *
 * Note: For Bootstrap-Vue-Next, sortBy is now an array of objects:
 * [{ key: 'column_name', order: 'asc' | 'desc' }]
 *
 * The sortDesc computed property is provided for backward compatibility
 * with existing code that references sortDesc directly.
 */
export default {
  data() {
    return {
      items: [],
      totalRows: 0,
      currentPage: 1,
      currentItemID: this.pageAfterInput,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      perPage: Number(this.pageSizeInput) || 10,
      pageOptions: [10, 25, 50, 100],
      // Bootstrap-Vue-Next uses array-based sortBy: [{ key: 'column', order: 'asc'|'desc' }]
      sortBy: [],
      sort: this.sortInput,
      // Note: filter is defined in each component with its specific structure
      // Do NOT define filter here to avoid Vue 3 OPTIONS_DATA_MERGE warning
      filter_string: '',
      filterOn: [],
      downloading: false,
      loading: true,
      isBusy: false,
      // Add any other shared data properties here
    };
  },
  computed: {
    /**
     * Backward compatibility: derive sortDesc from sortBy array.
     * Returns true if the first sort column is descending.
     */
    sortDesc: {
      get() {
        return this.sortBy.length > 0 && this.sortBy[0].order === 'desc';
      },
      set(value) {
        // Allow setting sortDesc for backward compatibility
        if (this.sortBy.length > 0) {
          this.sortBy = [{ key: this.sortBy[0].key, order: value ? 'desc' : 'asc' }];
        }
      },
    },
    /**
     * Backward compatibility: derive sortColumn from sortBy array.
     * Returns the key of the first sort column.
     */
    sortColumn() {
      return this.sortBy.length > 0 ? this.sortBy[0].key : '';
    },
    removeFiltersButtonVariant() {
      return (this.filter_string === '' || this.filter_string === null || this.filter_string === 'null') ? 'info' : 'warning';
    },
    removeFiltersButtonTitle() {
      let title = 'The table is ';
      title += (this.filter_string === '' || this.filter_string === null || this.filter_string === 'null') ? 'not ' : '';
      title += 'filtered.';
      if (this.filter_string !== '' && this.filter_string !== null && this.filter_string !== 'null') {
        title += ' Click to remove all filters.';
      }
      return title;
    },
  },
};
