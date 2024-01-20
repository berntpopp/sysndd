// app/src/assets/js/mixins/tableMethodsMixin.js
/**
 * Mixin with shared methods for table components.
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
        `${process.env.VUE_APP_URL + this.$route.path}?${urlParam}`,
      );
    },

    /**
     * Handles changes in sorting order or direction.
     */
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      this.sort = (!this.sortDesc ? '-' : '+') + this.sortBy;
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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

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
    handleSortUpdate({ sortBy, sortDesc }) {
      this.sortBy = sortBy;
      this.sortDesc = sortDesc;
    },
  },
};
