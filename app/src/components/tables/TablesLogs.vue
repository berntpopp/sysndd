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
          <!-- User Interface controls -->
          <b-card
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <b-row>
                <b-col>
                  <h4 class="mb-1 text-left font-weight-bold">
                    {{ headerLabel }}
                    <b-badge
                      v-b-tooltip.hover.bottom
                      variant="primary"
                      :title="
                        'Loaded ' +
                          perPage +
                          '/' +
                          totalRows +
                          ' in ' +
                          executionTime
                      "
                    >
                      Log entries: {{ totalRows }}
                    </b-badge>
                  </h4>
                </b-col>
                <b-col>
                  <h5
                    v-if="showFilterControls"
                    class="mb-1 text-right font-weight-bold"
                  >
                    <b-button
                      v-b-tooltip.hover.bottom
                      class="mr-1"
                      size="sm"
                      title="Download data as Excel file."
                      @click="requestExcel()"
                    >
                      <b-icon
                        icon="table"
                        class="mx-1"
                      />
                      <b-icon
                        v-if="!downloading"
                        icon="download"
                      />
                      <b-spinner
                        v-if="downloading"
                        small
                      />
                      .xlsx
                    </b-button>

                    <b-button
                      v-b-tooltip.hover.bottom
                      class="mx-1"
                      size="sm"
                      title="Copy link to this page."
                      variant="success"
                      @click="copyLinkToClipboard()"
                    >
                      <b-icon
                        icon="link"
                        font-scale="1.0"
                      />
                    </b-button>

                    <b-button
                      v-b-tooltip.hover.bottom
                      size="sm"
                      :title="
                        'The table is ' +
                          ((filter_string === '' || filter_string === null || filter_string === 'null') ? 'not' : '') +
                          ' filtered.' +
                          ((filter_string === '' || filter_string === null || filter_string === 'null')
                            ? ''
                            : ' Click to remove all filters.')
                      "
                      :variant="(filter_string === '' || filter_string === null || filter_string === 'null') ? 'info' : 'warning'"
                      @click="removeFilters()"
                    >
                      <b-icon
                        icon="filter"
                        font-scale="1.0"
                      />
                    </b-button>
                  </h5>
                </b-col>
              </b-row>
            </template>

            <b-row>
              <b-col
                class="my-1"
                sm="8"
              >
                <b-form-group class="mb-1 border-dark">
                  <b-form-input
                    v-if="showFilterControls"
                    id="filter-input"
                    v-model="filter['any'].content"
                    class="mb-1 border-dark"
                    size="sm"
                    type="search"
                    placeholder="Search any field by typing here"
                    debounce="500"
                    @click="removeFilters()"
                    @update="filtered()"
                  />
                </b-form-group>
              </b-col>

              <b-col
                class="my-1"
                sm="4"
              >
                <b-container
                  v-if="totalRows > perPage || showPaginationControls"
                >
                  <b-input-group
                    prepend="Per page"
                    class="mb-1"
                    size="sm"
                  >
                    <b-form-select
                      id="per-page-select"
                      v-model="perPage"
                      :options="pageOptions"
                      size="sm"
                    />
                  </b-input-group>

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
                </b-container>
              </b-col>
            </b-row>
            <!-- User Interface controls -->

            <!-- Logs Table -->
            <!-- Displays log data in a tabular format. Each cell is truncated for text overflow. -->
            <b-table
              :items="items"
              :fields="fields"
              :current-page="currentPage"
              :filter-included-fields="filterOn"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
              :busy="isBusy"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              no-local-sorting
              no-local-pagination
            >
              <!-- custom formatted header -->
              <template v-slot:head()="data">
                <div
                  v-b-tooltip.hover.top
                  :data="data"
                  data-html="true"
                  :title="
                    data.label +
                      ' (unique filtered/total values: ' +
                      fields
                        .filter((item) => item.label === data.label)
                        .map((item) => {
                          return item.count_filtered;
                        })[0] +
                      '/' +
                      fields
                        .filter((item) => item.label === data.label)
                        .map((item) => {
                          return item.count;
                        })[0] +
                      ')'
                  "
                >
                  {{ truncate(data.label.replace(/( word)|( name)/g, ""), 20) }}
                </div>
              </template>
              <!-- custom formatted header -->

              <!-- Filter Controls -->
              <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
              <template
                v-if="showFilterControls"
                slot="top-row"
              >
                <td
                  v-for="field in fields"
                  :key="field.key"
                >
                  <b-form-input
                    v-if="field.filterable"
                    v-model="filter[field.key].content"
                    :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
                    debounce="500"
                    type="search"
                    autocomplete="off"
                    @click="removeSearch()"
                    @update="filtered()"
                  />

                  <b-form-select
                    v-if="field.selectable"
                    v-model="filter[field.key].content"
                    :options="field.selectOptions"
                    type="search"
                    @input="removeSearch()"
                    @change="filtered()"
                  >
                    <template v-slot:first>
                      <b-form-select-option value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </b-form-select-option>
                    </template>
                  </b-form-select>

                  <label
                    v-if="field.multi_selectable"
                    :for="'select_' + field.key"
                    :aria-label="field.label"
                  >
                    <treeselect
                      v-if="field.multi_selectable"
                      :id="'select_' + field.key"
                      v-model="filter[field.key].content"
                      size="small"
                      :multiple="true"
                      :options="field.selectOptions"
                      :normalizer="normalizer"
                      :placeholder="'.. ' + truncate(field.label, 20) + ' ..'"
                      @input="removeSearch();filtered();"
                    />
                  </label>
                </td>
              </template>
              <!-- Filter Controls -->

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
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>

// Import the utilities file
import Utils from '@/assets/js/utils';

import toastMixin from '@/assets/js/mixins/toastMixin';
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

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
  mixins: [toastMixin, urlParsingMixin, colorAndSymbolsMixin, textMixin],
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Logging table' },
    sortInput: { type: String, default: '+row_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: String, default: '10' },
    fspecInput: {
      type: String,
      default:
        'row_id,remote_addr,http_user_agent,http_host,request_method,path_info,query_string,postbody,status,duration,filename,last_modified',
    },
  },
  data() {
    /**
     * Data function for TablesLogs component
     * @returns {Object} The component's reactive data object
     * @property {Array} items - The array of log data to be displayed in the table.
     * @property {Array} fields - Field definitions for the log table.
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
      items: placeholderData,
      fields: [
        {
          key: 'row_id',
          label: 'Row',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'remote_addr',
          label: 'Address',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'http_user_agent',
          label: 'Agent',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'http_host',
          label: 'Host',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'request_method',
          label: 'Request Method',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'path_info',
          label: 'Path',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'query_string',
          label: 'Query',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'postbody',
          label: 'Post',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'status',
          label: 'Status',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'duration',
          label: 'Duration',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'filename',
          label: 'File',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'last_modified',
          label: 'Modified',
          sortable: true,
          class: 'text-left',
        },
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
      sortBy: 'entity_id',
      sortDesc: true,
      sort: this.sortInput,
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        row_id: { content: null, join_char: null, operator: 'contains' },
        remote_addr: { content: null, join_char: null, operator: 'contains' },
        http_user_agent: { content: null, join_char: null, operator: 'contains' },
        http_host: { content: null, join_char: null, operator: 'contains' },
        request_method: { content: null, join_char: ',', operator: 'contains' },
        path_info: { content: null, join_char: ',', operator: 'contains' },
        query_string: { content: null, join_char: null, operator: 'contains' },
        postbody: { content: null, join_char: ',', operator: 'contains' },
        status: { content: null, join_char: ',', operator: 'contains' },
        duration: { content: null, join_char: ',', operator: 'contains' },
        filename: { content: null, join_char: ',', operator: 'contains' },
        last_modified: { content: null, join_char: ',', operator: 'contains' },
      },
      filter_string: null,
      filterOn: [],
      downloading: false,
      loading: false, // Start with false as we're showing placeholder data
      isBusy: true,
    };
  },
  watch: {
    filter(value) {
      this.filtered();
    },
    sortBy(value) {
      this.handleSortByOrDescChange();
    },
    sortDesc(value) {
      this.handleSortByOrDescChange();
    },
    perPage(value) {
      this.handlePerPageChange();
    },
  },
  created() {
  },
  mounted() {
    // transform input sort string to object and assign
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;
    this.sortDesc = sort_object.sortDesc;

    // conditionally perform data load based on filter input
    // fixes double loading and update bugs
    if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      // transform input filter string from params to object and assign
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    } else {
      // initiate first data load
      this.loadLogsData();
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
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
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      this.sort = (!this.sortDesc ? '-' : '+') + this.sortBy;
      this.filtered();
    },
    handlePerPageChange() {
      this.currentItemID = 0;
      this.filtered();
    },
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
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);

      if (filter_string_loc !== this.filter_string) {
        this.filter_string = this.filterObjToStr(this.filter);
      }

      this.loadLogsData();
    },
    removeFilters() {
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        entity_id: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
        hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
        hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
        ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
        category: { content: null, join_char: ',', operator: 'any' },
      };
    },
    removeSearch() {
      this.filter.any.content = null;

      if (this.filter.any.content !== null) {
        this.filter.any.content = null;
      }
    },
    /**
     * Asynchronously fetches and loads log data for the current page.
     */
    async loadLogsData() {
      this.isBusy = true;

      try {
        const response = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/logs`, {
          params: {
            sort: this.sort,
            filter: this.filter_string,
            page_after: this.currentItemID,
            page_size: this.perPage,
          },
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        this.items = response.data.data;
        this.totalRows = response.data.meta[0].totalItems;

        // Update pagination details
        this.$nextTick(() => {
          this.currentPage = response.data.meta[0].currentPage;
        });
        this.totalPages = response.data.meta[0].totalPages;
        this.prevItemID = response.data.meta[0].prevItemID;
        this.currentItemID = response.data.meta[0].currentItemID;
        this.nextItemID = response.data.meta[0].nextItemID;
        this.lastItemID = response.data.meta[0].lastItemID;
        this.executionTime = response.data.meta[0].executionTime;
      } catch (error) {
        console.error('Error fetching logs:', error);
        this.makeToast(`Error: ${error.message}`, 'Error loading logs', 'danger');
      } finally {
        this.isBusy = false;
      }
    },
    async requestExcel() {
      this.downloading = true;

      try {
        const response = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/logs`, {
          params: {
            page_after: 0,
            page_size: 'all',
            format: 'xlsx',
          },
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');

        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'sysndd_logs_table.xlsx');
        document.body.appendChild(fileLink);

        fileLink.click();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.downloading = false;
    },
    /**
     * Truncates a given string to a specified length.
     * @param {String} str - The string to truncate.
     * @param {Number} n - The maximum length of the truncated string.
     * @returns {String} The truncated string.
     */
    truncate(str, n) {
      return Utils.truncate(str, n);
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
