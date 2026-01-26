<!-- src/components/tables/TablesLogs.vue -->
<template>
  <div class="container-fluid">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- User Interface controls -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <BRow>
                <BCol>
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Log entries: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </BCol>
                <BCol>
                  <h5
                    v-if="showFilterControls"
                    class="mb-1 text-end font-weight-bold"
                  >
                    <TableDownloadLinkCopyButtons
                      :downloading="downloading"
                      :remove-filters-title="removeFiltersButtonTitle"
                      :remove-filters-variant="removeFiltersButtonVariant"
                      @request-excel="requestExcel"
                      @copy-link="copyLinkToClipboard"
                      @remove-filters="removeFilters"
                    />
                  </h5>
                </BCol>
              </BRow>
            </template>

            <BRow>
              <BCol
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter['any'].content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </BCol>

              <BCol
                class="my-1"
                sm="4"
              >
                <BContainer v-if="totalRows > perPage || showPaginationControls">
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="pageOptions"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </BContainer>
              </BCol>
            </BRow>
            <!-- User Interface controls -->

            <!-- Main table element -->
            <GenericTable
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              @update-sort="handleSortUpdate"
            >
              <!-- Custom filter fields slot -->
              <template
                v-if="showFilterControls"
                #filter-controls
              >
                <td
                  v-for="field in fields"
                  :key="field.key"
                >
                  <BFormInput
                    v-if="field.filterable"
                    v-model="filter[field.key].content"
                    :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
                    debounce="500"
                    type="search"
                    autocomplete="off"
                    @click="removeSearch()"
                    @update="filtered()"
                  />

                  <BFormSelect
                    v-if="field.selectable"
                    v-model="filter[field.key].content"
                    :options="field.selectOptions"
                    size="sm"
                    @input="removeSearch()"
                    @change="filtered()"
                  >
                    <template #first>
                      <BFormSelectOption value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>

                  <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
                  <label
                    v-if="field.multi_selectable && field.selectOptions && field.selectOptions.length > 0"
                    :for="'select_' + field.key"
                    :aria-label="field.label"
                  >
                    <BFormSelect
                      :id="'select_' + field.key"
                      v-model="filter[field.key].content"
                      :options="normalizeSelectOptions(field.selectOptions)"
                      size="sm"
                      @change="removeSearch();filtered();"
                    >
                      <template #first>
                        <BFormSelectOption :value="null">
                          .. {{ truncate(field.label, 20) }} ..
                        </BFormSelectOption>
                      </template>
                    </BFormSelect>
                  </label>
                </td>
              </template>
              <!-- Custom filter fields slot -->

              <template #cell-id="{ row }">
                <div>
                  <BBadge
                    variant="primary"
                    style="cursor: pointer"
                  >
                    {{ row.id }}
                  </BBadge>
                </div>
              </template>

              <template #cell-agent="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.agent"
                >
                  <BBadge
                    pill
                    variant="info"
                  >
                    {{ truncate(row.agent, 50) }}
                  </BBadge>
                </div>
              </template>

              <template #cell-status="{ row }">
                <BBadge :variant="row.status === 200 ? 'success' : 'danger'">
                  {{ row.status }}
                </BBadge>
              </template>

              <template #cell-request_method="{ row }">
                <BBadge :variant="getMethodVariant(row.request_method)">
                  {{ row.request_method }}
                </BBadge>
              </template>

              <template #cell-query="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.query"
                >
                  {{ row.query }}
                </div>
              </template>

              <template #cell-timestamp="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.timestamp"
                >
                  {{ formatDate(row.timestamp) }}
                </div>
              </template>

              <template #cell-modified="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.modified"
                >
                  {{ formatDate(row.modified) }}
                </div>
              </template>
            </GenericTable>
            <!-- Main table element -->
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
// Import Vue utilities
import { ref, inject } from 'vue';
import { useRoute } from 'vue-router';

// Import composables
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  useTableMethods,
} from '@/composables';

import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

// Module-level variables to track API calls across component remounts
// This survives when Vue Router remounts the component on URL changes
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null;

export default {
  name: 'TablesLogs',
  components: {
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableHeaderLabel,
    TableSearchInput,
    GenericTable,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'logs',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Logging table' },
    sortInput: { type: String, default: '-id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default: 'id,timestamp,address,agent,host,request_method,path,query,post,status,duration,file,modified',
    },
  },
  setup(props) {
    // Independent composables
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    // Table state composable
    const tableData = useTableData({
      pageSizeInput: props.pageSizeInput,
      sortInput: props.sortInput,
      pageAfterInput: props.pageAfterInput,
    });

    // Component-specific filter
    const filter = ref({
      any: { content: null, join_char: null, operator: 'contains' },
      id: { content: null, join_char: null, operator: 'contains' },
      timestamp: { content: null, join_char: null, operator: 'contains' },
      address: { content: null, join_char: null, operator: 'contains' },
      agent: { content: null, join_char: null, operator: 'contains' },
      host: { content: null, join_char: null, operator: 'contains' },
      request_method: { content: null, join_char: ',', operator: 'contains' },
      path: { content: null, join_char: ',', operator: 'contains' },
      query: { content: null, join_char: null, operator: 'contains' },
      post: { content: null, join_char: ',', operator: 'contains' },
      status: { content: null, join_char: ',', operator: 'contains' },
      duration: { content: null, join_char: ',', operator: 'contains' },
      file: { content: null, join_char: ',', operator: 'contains' },
      modified: { content: null, join_char: ',', operator: 'contains' },
    });

    // Inject axios and route
    const axios = inject('axios');
    const route = useRoute();

    // Table methods composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      apiEndpoint: props.apiEndpoint,
      axios,
      route,
    });

    // Return all needed properties
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      ...tableData,
      ...tableMethods,
      filter,
      axios,
    };
  },
  data() {
    return {
      // Flag to prevent watchers from triggering during initialization
      isInitializing: true,
      // Debounce timer for loadData to prevent duplicate calls
      loadDataDebounceTimer: null,
      // Pagination state
      totalPages: 0,
      fields: [
        { key: 'id', label: 'ID', sortable: true },
        { key: 'timestamp', label: 'Timestamp', sortable: true },
        { key: 'address', label: 'Address', sortable: true },
        { key: 'agent', label: 'Agent', sortable: true },
        { key: 'host', label: 'Host', sortable: true },
        { key: 'request_method', label: 'Request Method', sortable: true },
        { key: 'path', label: 'Path', sortable: true },
        { key: 'query', label: 'Query', sortable: true },
        { key: 'post', label: 'Post', sortable: true },
        { key: 'status', label: 'Status', sortable: true },
        { key: 'duration', label: 'Duration', sortable: true },
        { key: 'file', label: 'File', sortable: true },
        { key: 'modified', label: 'Modified', sortable: true },
      ],
      fields_details: [],
    };
  },
  watch: {
    // Watch for filter changes (deep required for Vue 3 behavior)
    // Skip during initialization to prevent multiple API calls
    filter: {
      handler() {
        if (this.isInitializing) return;
        this.filtered();
      },
      deep: true,
    },
    // Watch for sortBy changes (deep watch for array)
    // Skip during initialization to prevent multiple API calls
    sortBy: {
      handler() {
        if (this.isInitializing) return;
        this.handleSortByOrDescChange();
      },
      deep: true,
    },
  },
  created() {
    // Lifecycle hooks
  },
  mounted() {
    // Parse URL parameters BEFORE initial load
    const urlParams = new URLSearchParams(window.location.search);

    // Parse sort from URL or use prop default
    if (urlParams.get('sort')) {
      const sort_object = this.sortStringToVariables(urlParams.get('sort'));
      this.sortBy = sort_object.sortBy;
      this.sort = urlParams.get('sort');
    } else {
      const sort_object = this.sortStringToVariables(this.sortInput);
      this.sortBy = sort_object.sortBy;
      this.sort = this.sortInput;
    }

    // Parse filter from URL or prop
    if (urlParams.get('filter')) {
      this.filter = this.filterStrToObj(urlParams.get('filter'), this.filter);
      this.filter_string = urlParams.get('filter');
    } else if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
      this.filter_string = this.filterInput;
    }

    // Parse pagination from URL
    if (urlParams.get('page_after')) {
      this.currentItemID = parseInt(urlParams.get('page_after'), 10) || 0;
    }
    if (urlParams.get('page_size')) {
      this.perPage = parseInt(urlParams.get('page_size'), 10) || 10;
    }

    // Load data first while still in initializing state
    this.$nextTick(() => {
      this.loadData();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
    // Debounced loadData to prevent duplicate calls from multiple triggers
    loadData() {
      if (this.loadDataDebounceTimer) {
        clearTimeout(this.loadDataDebounceTimer);
      }
      this.loadDataDebounceTimer = setTimeout(() => {
        this.loadDataDebounceTimer = null;
        this.doLoadData();
      }, 50);
    },
    // Actual data loading with module-level caching
    async doLoadData() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const now = Date.now();

      // Prevent duplicate API calls using module-level tracking
      // This works across component remounts caused by router.replace()
      if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
        // Use cached response data for remounted component
        if (moduleLastApiResponse) {
          this.applyApiResponse(moduleLastApiResponse);
          this.isBusy = false;
        }
        return;
      }

      // Also prevent if a call is already in progress with same params
      if (moduleApiCallInProgress && moduleLastApiParams === urlParam) {
        return;
      }

      moduleLastApiParams = urlParam;
      moduleLastApiCallTime = now;
      moduleApiCallInProgress = true;
      this.isBusy = true;

      try {
        const response = await this.axios.get(`${import.meta.env.VITE_API_URL}/api/logs`, {
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

        moduleApiCallInProgress = false;
        // Cache response for remounted components
        moduleLastApiResponse = response.data;
        this.applyApiResponse(response.data);

        // Update URL AFTER API success to prevent component remount during API call
        this.updateBrowserUrl();

        this.isBusy = false;
      } catch (error) {
        moduleApiCallInProgress = false;
        this.makeToast(`Error: ${error.message}`, 'Error loading logs', 'danger');
        this.isBusy = false;
      }
    },
    /**
     * Apply API response data to component state.
     * Extracted to allow reuse when skipping duplicate API calls.
     * @param {Object} data - API response data
     */
    applyApiResponse(data) {
      this.items = data.data;
      this.totalRows = data.meta[0].totalItems;
      // this solves an update issue in b-pagination component
      // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
      this.$nextTick(() => {
        this.currentPage = data.meta[0].currentPage;
      });
      this.totalPages = data.meta[0].totalPages;
      this.prevItemID = Number(data.meta[0].prevItemID) || 0;
      this.currentItemID = Number(data.meta[0].currentItemID) || 0;
      this.nextItemID = Number(data.meta[0].nextItemID) || 0;
      this.lastItemID = Number(data.meta[0].lastItemID) || 0;
      this.executionTime = data.meta[0].executionTime;
      this.fields = data.meta[0].fspec;

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    },
    // Update browser URL with current table state
    // Uses history.replaceState instead of router.replace to prevent component remount
    updateBrowserUrl() {
      // Don't update URL during initialization - preserves URL params from navigation
      if (this.isInitializing) return;

      const searchParams = new URLSearchParams();

      if (this.sort) {
        searchParams.set('sort', this.sort);
      }
      if (this.filter_string) {
        searchParams.set('filter', this.filter_string);
      }
      const currentId = Number(this.currentItemID) || 0;
      if (currentId > 0) {
        searchParams.set('page_after', String(currentId));
      }
      searchParams.set('page_size', String(this.perPage));

      // Use history.replaceState to update URL without triggering Vue Router navigation
      // This prevents component remount which was causing duplicate API calls
      const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
      window.history.replaceState({ ...window.history.state }, '', newUrl);
    },
    copyLinkToClipboard() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      navigator.clipboard.writeText(`${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`);
    },
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      // Extract sort column and order from array-based sortBy
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : 'id';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'desc';
      this.sort = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
      this.filtered();
    },
    // Override handlePageChange to properly update currentItemID and call loadData
    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
      } else if (value === this.totalPages) {
        this.currentItemID = Number(this.lastItemID) || 0;
      } else if (value > this.currentPage) {
        this.currentItemID = Number(this.nextItemID) || 0;
      } else if (value < this.currentPage) {
        this.currentItemID = Number(this.prevItemID) || 0;
      }
      this.filtered();
    },
    // Override handlePerPageChange to reset pagination and reload
    handlePerPageChange(newPerPage) {
      this.perPage = parseInt(newPerPage, 10);
      this.currentItemID = 0;
      this.filtered();
    },
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);

      if (filter_string_loc !== this.filter_string) {
        this.filter_string = this.filterObjToStr(this.filter);
      }

      this.loadData();
    },
    removeFilters() {
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        id: { content: null, join_char: null, operator: 'contains' },
        timestamp: { content: null, join_char: null, operator: 'contains' },
        address: { content: null, join_char: null, operator: 'contains' },
        agent: { content: null, join_char: null, operator: 'contains' },
        host: { content: null, join_char: null, operator: 'contains' },
        request_method: { content: null, join_char: ',', operator: 'contains' },
        path: { content: null, join_char: ',', operator: 'contains' },
        query: { content: null, join_char: null, operator: 'contains' },
        post: { content: null, join_char: ',', operator: 'contains' },
        status: { content: null, join_char: ',', operator: 'contains' },
        duration: { content: null, join_char: ',', operator: 'contains' },
        file: { content: null, join_char: ',', operator: 'contains' },
        modified: { content: null, join_char: ',', operator: 'contains' },
      };
    },
    removeSearch() {
      this.filter.any.content = null;
    },
    async requestExcel() {
      this.downloading = true;

      try {
        const response = await this.axios.get(`${import.meta.env.VITE_API_URL}/api/logs`, {
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
        fileLink.setAttribute('download', 'logs_table.xlsx');
        document.body.appendChild(fileLink);

        fileLink.click();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.downloading = false;
    },
    truncate(str, n) {
      return Utils.truncate(str, n);
    },
    formatDate(dateStr) {
      const options = {
        year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
      };
      return new Date(dateStr).toLocaleDateString(undefined, options);
    },
    getMethodVariant(method) {
      const methodVariants = {
        GET: 'success',
        POST: 'primary',
        PUT: 'warning',
        DELETE: 'danger',
        OPTIONS: 'info',
      };
      return methodVariants[method] || 'secondary';
    },
    // Normalize select options for BFormSelect (replacement for treeselect normalizer)
    normalizeSelectOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => {
        if (typeof opt === 'object' && opt !== null) {
          return { value: opt.id || opt.value, text: opt.label || opt.text || opt.id };
        }
        return { value: opt, text: opt };
      });
    },
  },
};
</script>

<style scoped>
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
