<template>
  <!-- Main Container -->
  <!-- This section contains the overall layout of the component. -->
  <div class="container-fluid">
    <!-- Loading Spinner -->
    <!-- Displays while logs data is being fetched. -->
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <!-- Table Container -->
    <!-- This container holds the table and pagination components. -->
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- Logs Table -->
          <!-- Displays log data in a tabular format. Each cell is truncated for text overflow. -->
          <b-table
            :items="logsData"
            :fields="logFields"
            :per-page="perPage"
            :current-page="currentPage"
            small
            striped
            hover
          >
            <!-- Custom Cell Formatting -->
            <!-- Uses a slot to format the 'http_user_agent' field, truncating long text. -->
            <template v-slot:cell(http_user_agent)="data">
              <div
                v-b-tooltip.hover.top
                :title="data.item.http_user_agent"
              >
                {{ truncate(data.item.http_user_agent, 50) }}
              </div>
            </template>

            <!-- Last Modified Column Formatting -->
            <!-- Formats the 'last_modified' field to display date-time strings. -->
            <template v-slot:cell(last_modified)="data">
              {{ new Date(data.item.last_modified).toLocaleString() }}
            </template>
          </b-table>

          <!-- Pagination Component -->
          <!-- Allows navigating through different pages of log data. -->
          <b-pagination
            v-model="currentPage"
            :total-rows="totalRows"
            :per-page="perPage"
            align="fill"
            size="sm"
            class="my-0"
            limit="2"
            @change="handlePageChange"
          />
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
// TODO: is this import needed?
import axios from 'axios';

// Import the utilities file
import Utils from '@/assets/js/utils';

/**
 * TablesLogs Component
 * @description
 * This component is used to display log data in a table format. It supports pagination and displays a loading spinner while data is being fetched.
 * @component
 * @example
 * <TablesLogs />
 */
export default {
  name: 'TablesLogs',
  data() {
    /**
     * Data function for TablesLogs component
     * @returns {Object} The component's reactive data object
     * @property {Array} logsData - The array of log data to be displayed in the table.
     * @property {Array} logFields - Field definitions for the log table.
     * @property {Number} totalRows - Total number of rows in the log data.
     * @property {Number} currentPage - Current page number in pagination.
     * @property {String} currentItemID - Identifier for the current item for pagination.
     * @property {Number} perPage - Number of items per page in the table.
     * @property {Boolean} loading - Indicates if the data is currently being loaded.
     */
    // Initialize with placeholder data
    const placeholderData = Array(10).fill().map(() => ({
      row_id: 'Loading...',
      remote_addr: 'Loading...',
      http_user_agent: 'Loading...',
      http_host: 'Loading...',
      request_method: 'Loading...',
      path_info: 'Loading...',
      query_string: 'Loading...',
      status: 'Loading...',
      duration: 'Loading...',
      filename: 'Loading...',
      last_modified: new Date().toISOString(),
    }));

    return {
      logsData: placeholderData,
      logFields: [
        // ... other field definitions ...
      ],
      totalRows: 0,
      currentPage: 1,
      currentItemID: this.pageAfterInput,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      perPage: this.pageSizeInput,
      pageOptions: ['10', '25', '50', '200'],
      loading: false, // Start with false as we're showing placeholder data
    };
  },
  watch: {
    currentPage(newVal, oldVal) {
      this.loadLogsData();
    },
  },
  mounted() {
    this.loadLogsData();
  },
  methods: {
    /**
     * Truncates a given string to a specified length.
     * @param {String} str - The string to truncate.
     * @param {Number} n - The maximum length of the truncated string.
     * @returns {String} The truncated string.
     */
    truncate(str, n) {
      return Utils.truncate(str, n);
    },
    /**
    * Fetches and loads log data for the current page.
    */
    loadLogsData() {
      this.loading = true;

      // Calculate the page_after parameter
      const pageAfter = this.currentPage === 1 ? 0 : this.logsData[this.logsData.length - 1].row_id;

      axios.get(`${process.env.VUE_APP_API_URL}/api/logs`, {
        params: {
          page_after: pageAfter,
          page_size: this.perPage,
        },
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      }).then((response) => {
        this.logsData = response.data.data;
        this.totalRows = response.data.meta[0].totalItems;

        // this solves an update issue in b-pagination component
        // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
        this.$nextTick(() => {
          this.currentPage = response.data.meta[0].currentPage;
        });
        this.totalPages = response.data.meta[0].totalPages;
        this.prevItemID = response.data.meta[0].prevItemID;
        this.currentItemID = response.data.meta[0].currentItemID;
        this.nextItemID = response.data.meta[0].nextItemID;
        this.lastItemID = response.data.meta[0].lastItemID;
        this.executionTime = response.data.meta[0].executionTime;
        this.fields = response.data.meta[0].fspec;
      }).catch((error) => {
        console.error('Error fetching logs:', error);
      }).finally(() => {
        this.loading = false;
      });
    },
    /**
     * Handles page change events for pagination.
     * @param {Number} value - The new page number.
     */
    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
        this.filtered();
      } else if (value === this.totalPages) {
        this.currentItemID = this.lastItemID;
        this.filtered();
      } else if (value > this.currentPage) {
        this.currentItemID = this.nextItemID;
        this.filtered();
      } else if (value < this.currentPage) {
        this.currentItemID = this.prevItemID;
        this.filtered();
      }
    },
  },
};
</script>

<style scoped>
/* Styles specific to the TablesLogs component */
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
:deep(.vue-treeselect__placeholder) {
  color: #6C757D !important;
}
:deep(.vue-treeselect__control) {
  color: #6C757D !important;
}
</style>
