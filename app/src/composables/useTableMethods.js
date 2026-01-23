import useToast from './useToast';

/**
 * Composable for table action methods.
 * Uses dependency injection pattern - accepts table state and component-specific dependencies.
 *
 * Note: For Bootstrap-Vue-Next, sortBy is an array of objects:
 * [{ key: 'column_name', order: 'asc' | 'desc' }]
 *
 * @param {Object} tableData - Reactive table state from useTableData
 * @param {Object} options - Component-specific dependencies
 * @param {Object} options.filter - Filter object from component
 * @param {Function} options.filterObjToStr - Filter serialization function
 * @param {Function} options.loadData - Data loading function
 * @param {string} options.apiEndpoint - API endpoint for Excel export
 * @param {Object} options.axios - Axios instance
 * @param {Object} options.route - Vue Router route object
 * @returns {Object} Table action methods
 */
export default function useTableMethods(tableData, options = {}) {
  const { makeToast } = useToast();

  /**
   * Filters the table data based on the current filter criteria.
   */
  const filtered = () => {
    if (!options.filterObjToStr || !options.filter) {
      console.warn('filterObjToStr or filter not provided to useTableMethods');
      return;
    }

    const filter_string_loc = options.filterObjToStr(options.filter);

    if (filter_string_loc !== tableData.filter_string.value) {
      tableData.filter_string.value = filter_string_loc;
    }

    // Call a method to load data.
    // This method should be defined in each component.
    if (options.loadData) {
      options.loadData();
    }
  };

  /**
   * Copies the current page URL with query parameters to the clipboard.
   */
  const copyLinkToClipboard = () => {
    const urlParam = `sort=${
      tableData.sort.value
    }&filter=${
      tableData.filter_string.value
    }&page_after=${
      tableData.currentItemID.value
    }&page_size=${
      tableData.perPage.value}`;
    navigator.clipboard.writeText(
      `${import.meta.env.VITE_URL + options.route.path}?${urlParam}`,
    );
  };

  /**
   * Handles changes in sorting order or direction.
   * Works with Bootstrap-Vue-Next array-based sortBy format.
   */
  const handleSortByOrDescChange = () => {
    tableData.currentItemID.value = 0;

    // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
    const sortColumn = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].key : '';
    const sortOrder = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';

    // Build sort string for API: +column for asc, -column for desc
    tableData.sort.value = (isDesc ? '-' : '+') + sortColumn;
    filtered();
  };

  /**
   * Resets the pagination to the first page.
   */
  const handlePerPageChange = (newPerPage) => {
    tableData.perPage.value = parseInt(newPerPage, 10); // Ensure it's a number
    filtered();
  };

  /**
   * Handles page changes in pagination.
   * @param {number} value - The new page number.
   */
  const handlePageChange = (value) => {
    // Calculate totalPages from tableData
    const totalPages = Math.ceil(tableData.totalRows.value / tableData.perPage.value);

    if (value === 1) {
      tableData.currentItemID.value = 0;
    } else if (value === totalPages) {
      tableData.currentItemID.value = tableData.lastItemID.value;
    } else if (value > tableData.currentPage.value) {
      tableData.currentItemID.value = tableData.nextItemID.value;
    } else if (value < tableData.currentPage.value) {
      tableData.currentItemID.value = tableData.prevItemID.value;
    }
    filtered();
  };

  /**
   * Resets all filters to their default state.
   */
  const removeFilters = () => {
    if (!options.filter) {
      console.warn('filter not provided to useTableMethods');
      return;
    }

    Object.keys(options.filter).forEach((key) => {
      options.filter[key].content = null;
    });
    filtered();
  };

  /**
   * Clears the global search filter.
   */
  const removeSearch = () => {
    if (!options.filter || !options.filter.any) {
      console.warn('filter.any not available in useTableMethods');
      return;
    }

    options.filter.any.content = null;
    filtered();
  };

  /**
   * Requests and downloads table data as an Excel file.
   */
  const requestExcel = async () => {
    if (!options.apiEndpoint || !options.axios) {
      console.warn('apiEndpoint or axios not provided to useTableMethods');
      return;
    }

    tableData.downloading.value = true;

    // Compose URL parameter
    const urlParam = `sort=${tableData.sort.value}&filter=${tableData.filter_string.value}&page_after=0&page_size=all&format=xlsx`;

    // Build the API URL using the provided endpoint
    const apiUrl = `${import.meta.env.VITE_API_URL}/api/${options.apiEndpoint}?${urlParam}`;

    try {
      const response = await options.axios({
        url: apiUrl,
        method: 'GET',
        responseType: 'blob',
      });

      // Create a URL for the downloaded file
      const fileURL = window.URL.createObjectURL(new Blob([response.data]));
      const fileLink = document.createElement('a');

      // Set the download attribute with a dynamic filename
      fileLink.setAttribute('download', `sysndd_${options.apiEndpoint}_table.xlsx`);
      fileLink.href = fileURL;
      document.body.appendChild(fileLink);

      // Trigger the download
      fileLink.click();

      // Cleanup
      document.body.removeChild(fileLink);
      window.URL.revokeObjectURL(fileURL);
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    } finally {
      tableData.downloading.value = false;
    }
  };

  /**
   * Truncates a string to a specified length and adds an ellipsis if it's longer.
   * @param {string} str - The string to truncate.
   * @param {number} n - Maximum length of the string.
   * @returns {string} Truncated string.
   */
  const truncate = (str, n) => (str.length > n ? `${str.substr(0, n - 1)}...` : str);

  /**
   * Normalizes a node object for certain UI components.
   * @param {Object} node - The node object to normalize.
   * @returns {Object} Normalized node object.
   */
  const normalizer = (node) => ({
    id: node,
    label: node,
  });

  /**
   * Handles sort updates from GenericTable component.
   * Converts legacy { sortBy, sortDesc } format to new array format.
   * @param {Object} payload - Object with sortBy (string) and sortDesc (boolean)
   */
  const handleSortUpdate = ({ sortBy, sortDesc }) => {
    // Convert from legacy format to Bootstrap-Vue-Next array format
    tableData.sortBy.value = [{ key: sortBy, order: sortDesc ? 'desc' : 'asc' }];
    // Note: handleSortByOrDescChange will be triggered by watcher
  };

  /**
   * Handles sort-by updates from Bootstrap-Vue-Next BTable.
   * Called when @update:sort-by event fires.
   * @param {Array} newSortBy - Array of sort objects: [{ key: 'column', order: 'asc'|'desc' }]
   */
  const handleSortByUpdate = (newSortBy) => {
    tableData.sortBy.value = newSortBy;
    // Note: handleSortByOrDescChange will be triggered by watcher
  };

  return {
    copyLinkToClipboard,
    handleSortByOrDescChange,
    handlePerPageChange,
    handlePageChange,
    filtered,
    removeFilters,
    removeSearch,
    requestExcel,
    truncate,
    normalizer,
    handleSortUpdate,
    handleSortByUpdate,
  };
}
