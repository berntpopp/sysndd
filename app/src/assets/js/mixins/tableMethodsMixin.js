// app/src/assets/js/mixins/tableMethodsMixin.js
/**
 * Mixin with shared methods for table components.
 *
 * Note: For Bootstrap-Vue-Next, sortBy is an array of objects:
 * [{ key: 'column_name', order: 'asc' | 'desc' }]
 *
 * The handleSortByOrDescChange method extracts sort parameters from this array.
 */
export default {
  methods: {
    /**
     * Copies the current page URL with query parameters to the clipboard.
     */
    copyLinkToClipboard() {
      const urlParam = `sort=${
        this.sort
      }&filter=${
        this.filter_string
      }&page_after=${
        this.currentItemID
      }&page_size=${
        this.perPage}`;
      navigator.clipboard.writeText(
        `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`,
      );
    },

    /**
     * Handles changes in sorting order or direction.
     * Works with Bootstrap-Vue-Next array-based sortBy format.
     */
    handleSortByOrDescChange() {
      this.currentItemID = 0;

      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : '';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';
      const isDesc = sortOrder === 'desc';

      // Build sort string for API: +column for asc, -column for desc
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },

    /**
     * Resets the pagination to the first page.
     */
    handlePerPageChange(newPerPage) {
      this.perPage = parseInt(newPerPage, 10); // Ensure it's a number
      this.filtered();
    },

    /**
     * Handles page changes in pagination.
     * @param {number} value - The new page number.
     */
    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
      } else if (value === this.totalPages) {
        this.currentItemID = this.lastItemID;
      } else if (value > this.currentPage) {
        this.currentItemID = this.nextItemID;
      } else if (value < this.currentPage) {
        this.currentItemID = this.prevItemID;
      }
      this.filtered();
    },

    /**
     * Filters the table data based on the current filter criteria.
     */
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);

      if (filter_string_loc !== this.filter_string) {
        this.filter_string = filter_string_loc;
      }

      // Call a method to load data.
      // This method should be defined in each component.
      this.loadData();
    },

    /**
     * Resets all filters to their default state.
     */
    removeFilters() {
      Object.keys(this.filter).forEach((key) => {
        this.filter[key].content = null;
      });
      this.filtered();
    },

    /**
     * Clears the global search filter.
     */
    removeSearch() {
      this.filter.any.content = null;
      this.filtered();
    },

    /**
     * Requests and downloads table data as an Excel file.
     */
    async requestExcel() {
      this.downloading = true;

      // Compose URL parameter
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=0&page_size=all&format=xlsx`;

      // Build the API URL using the provided endpoint
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });

        // Create a URL for the downloaded file
        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');

        // Set the download attribute with a dynamic filename
        fileLink.setAttribute('download', `sysndd_${this.apiEndpoint}_table.xlsx`);
        fileLink.href = fileURL;
        document.body.appendChild(fileLink);

        // Trigger the download
        fileLink.click();

        // Cleanup
        document.body.removeChild(fileLink);
        window.URL.revokeObjectURL(fileURL);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.downloading = false;
      }
    },

    /**
     * Truncates a string to a specified length and adds an ellipsis if it's longer.
     * @param {string} str - The string to truncate.
     * @param {number} n - Maximum length of the string.
     * @returns {string} Truncated string.
     */
    truncate(str, n) {
      return str.length > n ? `${str.substr(0, n - 1)}...` : str;
    },

    /**
     * Normalizes a node object for certain UI components.
     * @param {Object} node - The node object to normalize.
     * @returns {Object} Normalized node object.
     */
    normalizer(node) {
      return {
        id: node,
        label: node,
      };
    },

    /**
     * Handles sort updates from GenericTable component.
     * Converts legacy { sortBy, sortDesc } format to new array format.
     * @param {Object} payload - Object with sortBy (string) and sortDesc (boolean)
     */
    handleSortUpdate({ sortBy, sortDesc }) {
      // Convert from legacy format to Bootstrap-Vue-Next array format
      this.sortBy = [{ key: sortBy, order: sortDesc ? 'desc' : 'asc' }];
      // Note: handleSortByOrDescChange will be triggered by watcher
    },

    /**
     * Handles sort-by updates from Bootstrap-Vue-Next BTable.
     * Called when @update:sort-by event fires.
     * @param {Array} newSortBy - Array of sort objects: [{ key: 'column', order: 'asc'|'desc' }]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
      // Note: handleSortByOrDescChange will be triggered by watcher
    },
  },
};
