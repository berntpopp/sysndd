import type { AxiosInstance } from 'axios';
import { isRef, type Ref } from 'vue';
import useToast from './useToast';
import type { TableDataState } from './useTableData';

/**
 * Composable for table action methods.
 * Uses dependency injection pattern - accepts table state and component-specific dependencies.
 *
 * Note: For Bootstrap-Vue-Next, sortBy is an array of objects:
 * [{ key: 'column_name', order: 'asc' | 'desc' }]
 *
 * @param tableData - Reactive table state from useTableData
 * @param options - Component-specific dependencies
 * @param options.filter - Filter object from component
 * @param options.filterObjToStr - Filter serialization function
 * @param options.loadData - Data loading function
 * @param options.apiEndpoint - API endpoint for Excel export
 * @param options.axios - Axios instance
 * @param options.updateUrl - Whether to update URL (default true)
 * @returns Table action methods
 */

interface FilterField {
  content: string | string[] | null;
  operator: string;
  join_char: string | null;
}

interface FilterObject {
  [key: string]: FilterField;
  any?: FilterField;
}

interface TableMethodsOptions {
  filter?: FilterObject | Ref<FilterObject>;
  filterObjToStr?: (filter: FilterObject) => string;
  loadData?: () => void;
  apiEndpoint?: string;
  axios?: AxiosInstance;
  updateUrl?: boolean;
}

interface TableMethods {
  copyLinkToClipboard: () => void;
  handleSortByOrDescChange: () => void;
  handlePerPageChange: (newPerPage: number | string) => void;
  handlePageChange: (value: number) => void;
  filtered: () => void;
  removeFilters: () => void;
  removeSearch: () => void;
  requestExcel: () => Promise<void>;
  truncate: (str: string, n: number) => string;
  normalizer: (node: string) => { id: string; label: string };
  handleSortUpdate: (payload: { sortBy: string; sortDesc: boolean }) => void;
  handleSortByUpdate: (newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>) => void;
}

export default function useTableMethods(tableData: TableDataState, options: TableMethodsOptions = {}): TableMethods {
  const { makeToast } = useToast();

  /**
   * Helper to unwrap ref if needed.
   * Vue refs passed from components need to be unwrapped to access .value
   */
  const getFilterValue = (): FilterObject | undefined => {
    if (!options.filter) return undefined;
    return isRef(options.filter) ? options.filter.value : options.filter;
  };

  /**
   * Updates the browser URL with current table state.
   * Uses history.replaceState to prevent Vue Router component remount.
   * Enables shareable/bookmarkable URLs that reflect filter, sort, and pagination.
   */
  const updateBrowserUrl = (): void => {
    if (options.updateUrl === false) return;

    const searchParams = new URLSearchParams();

    if (tableData.sort.value) {
      searchParams.set('sort', tableData.sort.value);
    }
    if (tableData.filter_string.value) {
      searchParams.set('filter', tableData.filter_string.value);
    }
    if (tableData.currentItemID.value > 0) {
      searchParams.set('page_after', String(tableData.currentItemID.value));
    }
    if (tableData.perPage.value !== 10) {
      searchParams.set('page_size', String(tableData.perPage.value));
    }

    // Use history.replaceState to update URL without triggering Vue Router navigation
    // This prevents component remount which was causing duplicate API calls
    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
    window.history.replaceState({ ...window.history.state }, '', newUrl);
  };

  /**
   * Filters the table data based on the current filter criteria.
   */
  const filtered = (): void => {
    const filterValue = getFilterValue();
    if (!options.filterObjToStr || !filterValue) {
      console.warn('filterObjToStr or filter not provided to useTableMethods');
      return;
    }

    const filter_string_loc = options.filterObjToStr(filterValue);

    if (filter_string_loc !== tableData.filter_string.value) {
      tableData.filter_string.value = filter_string_loc;
    }

    // Update browser URL to reflect current state
    updateBrowserUrl();

    // Call a method to load data.
    // This method should be defined in each component.
    if (options.loadData) {
      options.loadData();
    }
  };

  /**
   * Copies the current page URL with query parameters to the clipboard.
   */
  const copyLinkToClipboard = (): void => {
    const urlParam = `sort=${
      tableData.sort.value
    }&filter=${
      tableData.filter_string.value
    }&page_after=${
      tableData.currentItemID.value
    }&page_size=${
      tableData.perPage.value}`;
    navigator.clipboard.writeText(
      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`,
    );
  };

  /**
   * Handles changes in sorting order or direction.
   * Works with Bootstrap-Vue-Next array-based sortBy format.
   */
  const handleSortByOrDescChange = (): void => {
    tableData.currentItemID.value = 0;

    // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
    const sortColumn = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].key : '';
    const sortOrder = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';

    // Build sort string for API: +column for asc, -column for desc
    tableData.sort.value = (isDesc ? '-' : '+') + sortColumn;

    // Update URL and reload data
    updateBrowserUrl();
    if (options.loadData) {
      options.loadData();
    }
  };

  /**
   * Resets the pagination to the first page.
   */
  const handlePerPageChange = (newPerPage: number | string): void => {
    tableData.perPage.value = parseInt(String(newPerPage), 10);
    tableData.currentItemID.value = 0; // Reset to first page when changing page size

    // Update URL and reload data
    updateBrowserUrl();
    if (options.loadData) {
      options.loadData();
    }
  };

  /**
   * Handles page changes in pagination.
   * @param value - The new page number.
   */
  const handlePageChange = (value: number): void => {
    // Calculate totalPages from tableData
    const totalPages = Math.ceil(tableData.totalRows.value / tableData.perPage.value);

    if (value === 1) {
      tableData.currentItemID.value = 0;
    } else if (value === totalPages) {
      tableData.currentItemID.value = tableData.lastItemID.value as number;
    } else if (value > tableData.currentPage.value) {
      tableData.currentItemID.value = tableData.nextItemID.value as number;
    } else if (value < tableData.currentPage.value) {
      tableData.currentItemID.value = tableData.prevItemID.value as number;
    }

    // Update URL and reload data
    updateBrowserUrl();
    if (options.loadData) {
      options.loadData();
    }
  };

  /**
   * Resets all filters to their default state.
   */
  const removeFilters = (): void => {
    const filterValue = getFilterValue();
    if (!filterValue) {
      console.warn('filter not provided to useTableMethods');
      return;
    }

    Object.keys(filterValue).forEach((key) => {
      if (filterValue[key] && typeof filterValue[key] === 'object' && 'content' in filterValue[key]) {
        filterValue[key].content = null;
      }
    });
    filtered();
  };

  /**
   * Clears the global search filter.
   */
  const removeSearch = (): void => {
    const filterValue = getFilterValue();
    if (!filterValue || !filterValue.any) {
      // Silently return if no 'any' filter exists - this is normal for some table configurations
      return;
    }

    filterValue.any.content = null;
    filtered();
  };

  /**
   * Requests and downloads table data as an Excel file.
   */
  const requestExcel = async (): Promise<void> => {
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
      makeToast(e as Error, 'Error', 'danger');
    } finally {
      tableData.downloading.value = false;
    }
  };

  /**
   * Truncates a string to a specified length and adds an ellipsis if it's longer.
   * @param str - The string to truncate.
   * @param n - Maximum length of the string.
   * @returns Truncated string.
   */
  const truncate = (str: string, n: number): string => (str.length > n ? `${str.substr(0, n - 1)}...` : str);

  /**
   * Normalizes a node object for certain UI components.
   * @param node - The node object to normalize.
   * @returns Normalized node object.
   */
  const normalizer = (node: string): { id: string; label: string } => ({
    id: node,
    label: node,
  });

  /**
   * Handles sort updates from GenericTable component.
   * Converts legacy { sortBy, sortDesc } format to new array format.
   * @param payload - Object with sortBy (string) and sortDesc (boolean)
   */
  const handleSortUpdate = ({ sortBy, sortDesc }: { sortBy: string; sortDesc: boolean }): void => {
    // Convert from legacy format to Bootstrap-Vue-Next array format
    tableData.sortBy.value = [{ key: sortBy, order: sortDesc ? 'desc' : 'asc' }];
    // Note: handleSortByOrDescChange will be triggered by watcher
  };

  /**
   * Handles sort-by updates from Bootstrap-Vue-Next BTable.
   * Called when @update:sort-by event fires.
   * @param newSortBy - Array of sort objects: [{ key: 'column', order: 'asc'|'desc' }]
   */
  const handleSortByUpdate = (newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>): void => {
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

// Export TableDataState type for use in components
export type { TableDataState };
