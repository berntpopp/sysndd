<!-- src/components/tables/TablesLogs.vue -->
<template>
  <div class="container-fluid logs-table">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- User Interface controls -->
          <TableShell
            :title="headerLabel"
            :meta="`${totalRows.toLocaleString()} log entries`"
            :description="`Loaded ${perPage}/${totalRows} in ${executionTime}`"
          >
            <template #actions>
              <TableDownloadLinkCopyButtons
                v-if="showFilterControls"
                :downloading="downloading"
                :remove-filters-title="removeFiltersButtonTitle"
                :remove-filters-variant="removeFiltersButtonVariant"
                @request-excel="requestExcel"
                @copy-link="copyLinkToClipboard"
                @remove-filters="removeFilters"
              />
            </template>

            <template #toolbar>
              <BRow class="g-2">
                <BCol sm="8">
                  <TableSearchInput
                    v-model="filter['any'].content"
                    :placeholder="'Search any field by typing here'"
                    :debounce-time="500"
                    @update:model-value="filtered"
                  />
                </BCol>

                <BCol sm="4">
                  <BContainer v-if="totalRows > perPage || showPaginationControls">
                    <TablePaginationControls
                      :total-rows="totalRows"
                      :initial-per-page="perPage"
                      :page-options="pageOptions"
                      :current-page="currentPage"
                      @page-change="handlePageChange"
                      @per-page-change="handlePerPageChange"
                    />
                  </BContainer>
                </BCol>
              </BRow>

              <BRow class="g-2 mt-1 align-items-center">
                <BCol sm="3">
                  <BFormSelect
                    v-model="filter.request_method.content"
                    :options="method_options"
                    size="sm"
                    @update:model-value="filtered()"
                  >
                    <template #first>
                      <BFormSelectOption :value="null">All Methods</BFormSelectOption>
                    </template>
                  </BFormSelect>
                </BCol>
                <BCol sm="3">
                  <BFormSelect
                    v-model="filter.status.content"
                    :options="status_options"
                    size="sm"
                    @update:model-value="filtered()"
                  >
                    <template #first>
                      <BFormSelectOption :value="null">All Status</BFormSelectOption>
                    </template>
                  </BFormSelect>
                </BCol>
                <BCol sm="3">
                  <BFormSelect
                    v-model="filter.path.content"
                    size="sm"
                    @update:model-value="filtered()"
                  >
                    <BFormSelectOption :value="null">All Paths</BFormSelectOption>
                    <BFormSelectOption value="/api/">API Calls</BFormSelectOption>
                    <BFormSelectOption value="/signin">/signin</BFormSelectOption>
                    <BFormSelectOption value="/api/entity">/api/entity</BFormSelectOption>
                    <BFormSelectOption value="/api/logs">/api/logs</BFormSelectOption>
                  </BFormSelect>
                </BCol>
                <BCol sm="3" class="text-end">
                  <span class="text-muted small me-2">
                    {{ items.length }} of {{ totalRows.toLocaleString() }}
                  </span>
                  <BButton
                    v-b-tooltip.hover
                    size="sm"
                    variant="outline-danger"
                    title="Delete all logs (requires confirmation)"
                    @click="showDeleteModal = true"
                  >
                    <i class="bi bi-trash" />
                  </BButton>
                </BCol>
              </BRow>

              <BRow class="g-2 mt-1 d-md-none">
                <BCol>
                  <BInputGroup prepend="Sort" size="sm">
                    <BFormSelect v-model="mobileSortValue" :options="mobileSortOptions" size="sm" />
                  </BInputGroup>
                </BCol>
              </BRow>

              <details class="log-mobile-filters d-md-none">
                <summary>
                  <i class="bi bi-funnel" aria-hidden="true" />
                  More filters
                </summary>
                <div class="log-mobile-filters__grid">
                  <BFormInput
                    v-model="filter.id.content"
                    size="sm"
                    placeholder="ID"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.timestamp.content"
                    size="sm"
                    placeholder="Timestamp"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.address.content"
                    size="sm"
                    placeholder="IP address"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.agent.content"
                    size="sm"
                    placeholder="Agent"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.host.content"
                    size="sm"
                    placeholder="Host"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.user.content"
                    size="sm"
                    placeholder="User"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.query.content"
                    size="sm"
                    placeholder="Query"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.post.content"
                    size="sm"
                    placeholder="POST body"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.duration.content"
                    size="sm"
                    placeholder="Duration"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.file.content"
                    size="sm"
                    placeholder="File"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                  <BFormInput
                    v-model="filter.modified.content"
                    size="sm"
                    placeholder="Modified"
                    type="search"
                    autocomplete="off"
                    @update:model-value="filtered()"
                  />
                </div>
              </details>

              <!-- Active filter pills -->
              <BRow v-if="hasActiveFilters" class="g-2 mt-1">
                <BCol>
                  <BBadge
                    v-for="(activeFilter, index) in activeFilters"
                    :key="index"
                    variant="secondary"
                    class="me-2 mb-1"
                  >
                    {{ activeFilter.label }}: {{ activeFilter.value }}
                    <BButton
                      size="sm"
                      variant="link"
                      class="p-0 ms-1 text-light"
                      @click="clearFilter(activeFilter.key)"
                    >
                      <i class="bi bi-x" />
                    </BButton>
                  </BBadge>
                  <BButton size="sm" variant="link" class="p-0" @click="removeFilters">
                    Clear all
                  </BButton>
                </BCol>
              </BRow>
            </template>
            <!-- User Interface controls -->

            <div v-if="isBusy" data-testid="logs-loading-state" class="logs-loading-state">
              <BSpinner small class="me-2" />
              Loading logs...
            </div>

            <!-- Empty state when no logs match filters -->
            <div v-else-if="items.length === 0" class="text-center py-4">
              <i class="bi bi-journal-x fs-1 text-muted" />
              <p class="text-muted mt-2">No logs match your filters</p>
              <BButton v-if="hasActiveFilters" variant="link" @click="removeFilters">
                Clear filters
              </BButton>
            </div>

            <!-- Main table element -->
            <GenericTable
              v-else-if="items.length > 0"
              class="d-none d-md-table"
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              @update-sort="handleSortUpdate"
            >
              <!-- Custom filter fields slot -->
              <template v-if="showFilterControls" #filter-controls>
                <td v-for="field in fields" :key="field.key">
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
                    v-if="
                      field.multi_selectable &&
                      field.selectOptions &&
                      field.selectOptions.length > 0
                    "
                    :for="'select_' + field.key"
                    :aria-label="field.label"
                  >
                    <BFormSelect
                      :id="'select_' + field.key"
                      v-model="filter[field.key].content"
                      :options="normalizeSelectOptions(field.selectOptions)"
                      size="sm"
                      @change="
                        removeSearch();
                        filtered();
                      "
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
                <div style="cursor: pointer" @click="handleRowClick(row)">
                  <BBadge variant="primary">
                    {{ row.id }}
                  </BBadge>
                </div>
              </template>

              <template #cell-agent="{ row }">
                <div v-b-tooltip.hover.top class="overflow-hidden text-truncate" :title="row.agent">
                  <BBadge pill variant="info">
                    {{ truncate(row.agent, 50) }}
                  </BBadge>
                </div>
              </template>

              <template #cell-status="{ row }">
                <BBadge :variant="getStatusVariant(row.status)">
                  {{ row.status }}
                </BBadge>
              </template>

              <template #cell-request_method="{ row }">
                <BBadge :variant="getMethodVariant(row.request_method)">
                  {{ row.request_method }}
                </BBadge>
              </template>

              <template #cell-path="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate font-monospace small"
                  style="max-width: 200px"
                  :title="row.path + (row.query ? row.query : '')"
                >
                  {{ row.path }}
                </div>
              </template>

              <template #cell-duration="{ row }">
                <span
                  v-b-tooltip.hover
                  :class="getDurationClass(row.duration)"
                  :title="`${row.duration}ms response time`"
                >
                  {{ formatDuration(row.duration) }}
                </span>
              </template>

              <template #cell-address="{ row }">
                <span class="font-monospace small">{{ row.address }}</span>
              </template>

              <template #cell-timestamp="{ row }">
                <div v-b-tooltip.hover.top :title="formatAbsoluteTime(row.timestamp)">
                  {{ formatRelativeTime(row.timestamp) }}
                </div>
              </template>

              <template #cell-modified="{ row }">
                <div v-b-tooltip.hover.top :title="formatAbsoluteTime(row.modified)">
                  {{ formatRelativeTime(row.modified) }}
                </div>
              </template>

              <template #cell-actions="{ row }">
                <BButton
                  v-b-tooltip.hover
                  size="sm"
                  variant="outline-primary"
                  title="View details"
                  @click="handleRowClick(row)"
                >
                  <i class="bi bi-eye" />
                </BButton>
              </template>
            </GenericTable>
            <LogMobileRows
              v-if="!isBusy && items.length > 0"
              class="d-md-none"
              :items="items"
              @view="handleRowClick"
            />
            <!-- Main table element -->
          </TableShell>
        </BCol>
      </BRow>

      <!-- Log Detail Drawer -->
      <LogDetailDrawer
        v-model="showLogDetail"
        :log="selectedLog"
        :can-navigate-prev="canNavigatePrev"
        :can-navigate-next="canNavigateNext"
        @navigate-prev="navigateToPreviousLog"
        @navigate-next="navigateToNextLog"
      />

      <!-- Delete Logs Confirmation Modal: stays mounted (no v-if) so the
           modal's @hidden lifecycle fires and owns the state reset -->
      <LogDeleteModal
        v-model="showDeleteModal"
        v-model:delete-mode="deleteMode"
        :total-rows="totalRows"
        :is-deleting="isDeleting"
        @confirm="deleteLogs"
      />
    </BContainer>
  </div>
</template>

<script>
// Import Vue utilities
import { ref } from 'vue';
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

import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import LogDetailDrawer from '@/components/small/LogDetailDrawer.vue';
import LogDeleteModal from '@/components/small/LogDeleteModal.vue';
import TableShell from '@/components/table/TableShell.vue';
import LogMobileRows from '@/views/admin/components/LogMobileRows.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';
import {
  formatAbsoluteLogTime,
  formatLogDate,
  formatLogDuration,
  formatRelativeLogTime,
  getLogDurationClass,
  getLogMethodVariant,
  getLogStatusVariant,
} from './logTableFormatters';
import { normalizeSelectOptions } from '@/utils/selectOptions';
import { listLogs, listLogsXlsx, deleteLogs as deleteLogsApi } from '@/api/logging';
import { listUsersByRole } from '@/api/user';
import { createLogTableRequestCache } from './logTableRequests';

const moduleLogRequestCache = createLogTableRequestCache();

export default {
  name: 'TablesLogs',
  components: {
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableSearchInput,
    GenericTable,
    LogDetailDrawer,
    LogDeleteModal,
    TableShell,
    LogMobileRows,
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
      default:
        'id,timestamp,address,agent,host,request_method,path,query,post,status,duration,file,modified',
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
      user: { content: null, join_char: null, operator: 'contains' },
      request_method: { content: null, join_char: ',', operator: 'contains' },
      path: { content: null, join_char: ',', operator: 'contains' },
      query: { content: null, join_char: null, operator: 'contains' },
      post: { content: null, join_char: ',', operator: 'contains' },
      status: { content: null, join_char: ',', operator: 'contains' },
      duration: { content: null, join_char: ',', operator: 'contains' },
      file: { content: null, join_char: ',', operator: 'contains' },
      modified: { content: null, join_char: ',', operator: 'contains' },
    });

    const route = useRoute();

    // Table methods composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      apiEndpoint: props.apiEndpoint,
      route,
    });

    const {
      filtered: _filtered,
      handlePageChange: _handlePageChange,
      handlePerPageChange: _handlePerPageChange,
      handleSortByOrDescChange: _handleSortByOrDescChange,
      removeFilters: _removeFilters,
      removeSearch: _removeSearch,
      requestExcel: _requestExcel,
      copyLinkToClipboard: _copyLinkToClipboard,
      truncate: _truncate,
      ...restTableMethods
    } = tableMethods;

    // Return all needed properties
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      ...tableData,
      ...restTableMethods,
      filter,
      // Shared select-option normalizer used by the table-header filter row.
      normalizeSelectOptions,
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
      // User filter options (loaded from API)
      user_options: [],
      // HTTP method filter options
      method_options: [
        { value: 'GET', text: 'GET' },
        { value: 'POST', text: 'POST' },
        { value: 'PUT', text: 'PUT' },
        { value: 'DELETE', text: 'DELETE' },
      ],
      // Log detail drawer state
      showLogDetail: false,
      selectedLog: null,
      selectedLogIndex: -1,
      // Field definitions - NOT overwritten by API
      fields: [
        {
          key: 'id',
          label: 'ID',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '80px' },
        },
        { key: 'timestamp', label: 'Time', sortable: true, thStyle: { width: '120px' } },
        {
          key: 'request_method',
          label: 'Method',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '90px' },
        },
        {
          key: 'status',
          label: 'Status',
          sortable: true,
          class: 'text-center',
          thStyle: { width: '80px' },
        },
        { key: 'path', label: 'Path', sortable: true },
        {
          key: 'duration',
          label: 'Duration',
          sortable: true,
          class: 'text-end',
          thStyle: { width: '90px' },
        },
        { key: 'address', label: 'IP', sortable: true, thStyle: { width: '120px' } },
        {
          key: 'actions',
          label: '',
          sortable: false,
          class: 'text-center',
          thStyle: { width: '60px' },
        },
      ],
      fields_details: [],
      // Status filter options
      status_options: [
        { value: '200', text: '200 OK' },
        { value: '201', text: '201 Created' },
        { value: '307', text: '307 Redirect' },
        { value: '400', text: '400 Bad Request' },
        { value: '401', text: '401 Unauthorized' },
        { value: '403', text: '403 Forbidden' },
        { value: '404', text: '404 Not Found' },
        { value: '500', text: '500 Server Error' },
      ],
      mobileSortOptions: [
        { value: '-id', text: 'Newest ID first' },
        { value: '+id', text: 'Oldest ID first' },
        { value: '-timestamp', text: 'Newest time first' },
        { value: '+timestamp', text: 'Oldest time first' },
        { value: '-duration', text: 'Slowest first' },
        { value: '+duration', text: 'Fastest first' },
      ],
      // Delete confirmation modal state
      showDeleteModal: false,
      deleteMode: 'all', // 'all', '3', '7', '14', '30' (days)
      isDeleting: false,
    };
  },
  computed: {
    mobileSortValue: {
      get() {
        return this.sort || '-id';
      },
      set(value) {
        const sort_object = this.sortStringToVariables(value);
        this.sortBy = sort_object.sortBy;
        this.sort = value;
        this.currentItemID = 0;
        this.filtered();
      },
    },
    canNavigatePrev() {
      return this.selectedLogIndex > 0;
    },
    canNavigateNext() {
      return this.selectedLogIndex < this.items.length - 1;
    },
    hasActiveFilters() {
      return Object.values(this.filter).some((f) => f.content !== null && f.content !== '');
    },
    activeFilters() {
      const filters = [];
      if (this.filter.any.content) {
        filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
      }
      if (this.filter.user.content) {
        filters.push({ key: 'user', label: 'User', value: this.filter.user.content });
      }
      if (this.filter.request_method.content) {
        filters.push({
          key: 'request_method',
          label: 'Method',
          value: this.filter.request_method.content,
        });
      }
      if (this.filter.status.content) {
        filters.push({ key: 'status', label: 'Status', value: this.filter.status.content });
      }
      if (this.filter.path.content) {
        filters.push({ key: 'path', label: 'Path', value: this.filter.path.content });
      }
      return filters;
    },
    removeFiltersButtonVariant() {
      return this.hasActiveFilters ? 'outline-danger' : 'outline-secondary';
    },
    removeFiltersButtonTitle() {
      return this.hasActiveFilters ? 'Clear all filters' : 'No active filters';
    },
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
    // Only trigger if sort actually changed to prevent resetting currentItemID during pagination
    sortBy: {
      handler(newVal) {
        if (this.isInitializing) return;
        const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'id';
        const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'desc';
        const newSortString = (newSortOrder === 'desc' ? '-' : '+') + newSortColumn;
        // Only trigger if sort actually changed - prevents resetting currentItemID during pagination
        if (newSortString !== this.sort) {
          this.handleSortByOrDescChange();
        }
      },
      deep: true,
    },
  },
  created() {
    // Lifecycle hooks
  },
  mounted() {
    // Transform input sort string to Bootstrap-Vue-Next array format
    // sortStringToVariables now returns { sortBy: [{ key: 'column', order: 'asc'|'desc' }] }
    if (this.sortInput) {
      const sort_object = this.sortStringToVariables(this.sortInput);
      this.sortBy = sort_object.sortBy;
      this.sort = this.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (this.pageAfterInput && this.pageAfterInput !== '0') {
      this.currentItemID = parseInt(this.pageAfterInput, 10) || 0;
    }

    // Load user list for filter dropdown
    this.loadUserList();

    // Transform input filter string to object and load data
    // Use $nextTick to ensure Vue reactivity is fully initialized
    this.$nextTick(() => {
      if (this.filterInput && this.filterInput !== 'null' && this.filterInput !== '') {
        // Parse URL filter string into filter object for proper UI state
        this.filter = this.filterStrToObj(this.filterInput, this.filter);
        // Also set filter_string so the API call uses the URL filter
        this.filter_string = this.filterInput;
      }
      // Load data first while still in initializing state
      this.loadData();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });

    this.loading = false;
  },
  methods: {
    // Handle row click to open detail drawer
    handleRowClick(row) {
      this.selectedLog = row;
      this.selectedLogIndex = this.items.findIndex((item) => item.id === row.id);
      this.showLogDetail = true;
    },
    // Navigate to previous log in drawer
    navigateToPreviousLog() {
      if (this.selectedLogIndex > 0) {
        this.selectedLogIndex -= 1;
        this.selectedLog = this.items[this.selectedLogIndex];
      }
    },
    // Navigate to next log in drawer
    navigateToNextLog() {
      if (this.selectedLogIndex < this.items.length - 1) {
        this.selectedLogIndex += 1;
        this.selectedLog = this.items[this.selectedLogIndex];
      }
    },
    // Load user list for filter dropdown
    async loadUserList() {
      try {
        const data = await listUsersByRole();
        this.user_options = data.map((item) => ({
          value: item.user_name,
          text: `${item.user_name} (${item.user_role})`,
        }));
      } catch (_e) {
        this.makeToast('Failed to load user list', 'Error', 'danger');
      }
    },
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
      const params = {
        sort: this.sort,
        filter: this.filter_string,
        page_after: this.currentItemID,
        page_size: this.perPage,
      };
      this.isBusy = true;

      try {
        const result = await moduleLogRequestCache.load(params, () => listLogs(params));
        this.applyApiResponse(result.response);

        // Update URL AFTER API success to prevent component remount during API call
        if (!result.fromCache) {
          this.updateBrowserUrl();
        }

        this.isBusy = false;
      } catch (error) {
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
      // Apply fspec from API for column filters (like TablesEntities)
      // The fspec contains filterable, selectable, selectOptions for each field
      if (data.meta[0].fspec && data.meta[0].fspec.fspec) {
        this.fields = data.meta[0].fspec.fspec;
      }

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
        user: { content: null, join_char: null, operator: 'contains' },
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
    clearFilter(key) {
      if (this.filter[key]) {
        this.filter[key].content = null;
      }
      this.filtered();
    },
    async requestExcel() {
      this.downloading = true;

      // Warn if large export
      if (this.totalRows > 30000) {
        const proceed = confirm(
          `This export contains ${this.totalRows.toLocaleString()} rows and may take a while. Continue?`
        );
        if (!proceed) {
          this.downloading = false;
          return;
        }
      }

      try {
        const blob = await listLogsXlsx({
          page_after: 0,
          page_size: 'all',
          filter: this.filter_string,
          sort: this.sort,
        });

        // Generate filename with date
        const date = new Date().toISOString().split('T')[0];
        const filename = `sysndd_audit_logs_${date}.xlsx`;

        const fileURL = window.URL.createObjectURL(new Blob([blob]));
        const fileLink = document.createElement('a');

        fileLink.href = fileURL;
        fileLink.setAttribute('download', filename);
        document.body.appendChild(fileLink);

        fileLink.click();

        // Cleanup
        document.body.removeChild(fileLink);
        window.URL.revokeObjectURL(fileURL);

        this.makeToast(`Exported ${this.totalRows} log entries`, 'Export Complete', 'success');
      } catch (e) {
        this.makeToast(e, 'Export failed', 'danger');
      }

      this.downloading = false;
    },
    truncate(str, n) {
      return Utils.truncate(str, n);
    },
    formatDate(dateStr) {
      return formatLogDate(dateStr);
    },
    // Format relative time using Intl.RelativeTimeFormat (e.g., "2 hours ago")
    formatRelativeTime(dateStr) {
      return formatRelativeLogTime(dateStr);
    },
    // Format absolute time for tooltip display
    formatAbsoluteTime(dateStr) {
      return formatAbsoluteLogTime(dateStr);
    },
    // Get Bootstrap variant for HTTP status code badges
    getStatusVariant(status) {
      return getLogStatusVariant(status);
    },
    getMethodVariant(method) {
      return getLogMethodVariant(method);
    },
    // Format duration with appropriate unit
    formatDuration(duration) {
      return formatLogDuration(duration);
    },
    // Get CSS class for duration based on performance
    getDurationClass(duration) {
      return getLogDurationClass(duration);
    },
    // Delete logs with optional age filter
    async deleteLogs() {
      this.isDeleting = true;
      try {
        const olderThanDays = this.deleteMode === 'all' ? 0 : parseInt(this.deleteMode, 10);
        const response = await deleteLogsApi({ older_than_days: olderThanDays });

        const deletedCount = response.deleted_count || 0;
        const message =
          this.deleteMode === 'all'
            ? `Successfully deleted ${deletedCount.toLocaleString()} log entries`
            : `Successfully deleted ${deletedCount.toLocaleString()} log entries older than ${this.deleteMode} days`;

        this.makeToast(message, 'Logs Deleted', 'success');
        // Closing the modal triggers its @hidden reset (confirm text + mode)
        this.showDeleteModal = false;
        // Reset and reload
        this.currentItemID = 0;
        this.loadData();
      } catch (error) {
        const errorMsg = error.response?.data?.error || error.message;
        this.makeToast(`Failed to delete logs: ${errorMsg}`, 'Error', 'danger');
      } finally {
        this.isDeleting = false;
      }
    },
  },
};
</script>

<style scoped>
/* Scoped styles for TablesLogs.vue (extracted from the SFC). */

/* Button styles */
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

.log-mobile-filters {
  margin-top: 0.5rem;
}

.logs-table {
  padding-bottom: max(1rem, var(--app-footer-height, 48px));
}

.log-mobile-filters summary {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 2rem;
  color: #0d6efd;
  font-size: 0.8125rem;
  font-weight: 700;
  cursor: pointer;
}

.log-mobile-filters__grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.log-mobile-filters:not([open]) .log-mobile-filters__grid {
  display: none;
}

.logs-loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 14rem;
  color: #526070;
  font-size: 0.875rem;
}

/* Input group styles */
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}

/* Badge container styles */
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Treeselect placeholder styles (legacy) */
:deep(.vue-treeselect__placeholder) {
  color: #6c757d !important;
}
:deep(.vue-treeselect__control) {
  color: #6c757d !important;
}

/* Row hover effect for clickable rows */
:deep(.table tbody tr) {
  cursor: pointer;
  transition: background-color 0.15s ease-in-out;
}

:deep(.table tbody tr:hover) {
  background-color: rgba(var(--bs-primary-rgb), 0.075);
}
</style>
