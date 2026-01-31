<!-- src/components/analyses/PublicationsNDDTable.vue -->
<template>
  <div class="container-fluid">
    <!-- Show an overlay spinner while loading -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!-- Once loaded, show the table container -->
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- b-card wrapper for the table and controls -->
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <!-- Card Header -->
            <template #header>
              <BRow>
                <BCol>
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Publications: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </BCol>
                <BCol>
                  <h5 v-if="showFilterControls" class="mb-1 text-end font-weight-bold">
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

            <!-- Controls (search + pagination) -->
            <BRow>
              <!-- Search box for "any" field -->
              <BCol class="my-1" sm="8">
                <TableSearchInput
                  v-model="filter.any.content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </BCol>

              <!-- Pagination controls -->
              <BCol class="my-1" sm="4">
                <BContainer v-if="totalRows > perPage || showPaginationControls">
                  <!--
                    TablePaginationControls will emit:
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  -->
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
            <!-- Controls (search + pagination) -->

            <!-- Main GenericTable -->
            <GenericTable
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              :sort-desc="sortDesc"
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
                    type="search"
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

              <!-- Custom slot for 'publication_id' - links to PubMed -->
              <template #cell-publication_id="{ row }">
                <a
                  :href="getPubMedUrl(row.publication_id)"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="publication-link"
                  :aria-label="`Open PubMed article ${row.publication_id} in new tab`"
                >
                  <span class="publication-badge">
                    <i class="bi bi-journal-medical me-1" />
                    <span class="publication-id">{{ row.publication_id }}</span>
                    <i class="bi bi-box-arrow-up-right ms-1 external-icon" />
                  </span>
                </a>
              </template>

              <!-- Custom slot for 'Title' -->
              <template #cell-Title="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="title-cell"
                  :title="row.Title"
                >
                  <span class="title-text">{{ truncate(row.Title, 60) }}</span>
                </div>
              </template>

              <!-- Custom slot for 'Journal' -->
              <template #cell-Journal="{ row }">
                <span v-if="row.Journal" class="journal-badge">
                  <i class="bi bi-book me-1" />
                  {{ truncate(row.Journal, 35) }}
                </span>
                <span v-else class="text-muted">—</span>
              </template>

              <!-- Custom slot for 'Publication_date' -->
              <template #cell-Publication_date="{ row }">
                <span v-if="row.Publication_date" class="date-badge">
                  <i class="bi bi-calendar3 me-1" />
                  {{ formatDate(row.Publication_date) }}
                </span>
                <span v-else class="text-muted">—</span>
              </template>
            </GenericTable>
            <!-- Main GenericTable -->
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
// Import Vue utilities
import { ref, inject } from 'vue';

// Import composables
import { useToast, useUrlParsing, useColorAndSymbols, useText, useTableData } from '@/composables';

// Small reusable components
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
let moduleLastApiResponse = null; // Cache last API response for remounted components

export default {
  name: 'PublicationsNDDTable',
  components: {
    TableHeaderLabel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    GenericTable,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'publication', // So it references /api/publication
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Publications table' },
    sortInput: { type: String, default: '+publication_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default: 'publication_id,Title,Journal,Publication_date',
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
      publication_id: { content: null, join_char: null, operator: 'contains' },
      Title: { content: null, join_char: null, operator: 'contains' },
      Journal: { content: null, join_char: null, operator: 'contains' },
      Publication_date: { content: null, join_char: null, operator: 'contains' },
    });

    // Inject axios and route
    const axios = inject('axios');

    // Return all needed properties (this component has its own method implementations)
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      ...tableData,
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
      // Table columns
      fields: [
        {
          key: 'publication_id',
          label: 'Publication id',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'Title',
          label: 'Title',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'Publication_date',
          label: 'Publication date',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'Journal',
          label: 'Journal',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
      ],
      // Detail fields shown in expandable row view
      fields_details: [
        { key: 'Abstract', label: 'Abstract', class: 'text-start' },
        { key: 'Lastname', label: 'Authors (Last names)', class: 'text-start' },
        { key: 'Firstname', label: 'Authors (First names)', class: 'text-start' },
        { key: 'Keywords', label: 'Keywords', class: 'text-start' },
      ],

      // Note: Table state (items, totalRows, perPage, sortBy, sortDesc, loading, isBusy,
      // downloading, currentItemID, prevItemID, nextItemID, lastItemID, executionTime,
      // filter_string, etc.) is provided by useTableData composable in setup()

      // Component-specific cursor pagination info (not in useTableData)
      totalPages: 0,
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
      handler(newVal) {
        if (this.isInitializing) return;
        // Build new sort string from sortBy
        const sortColumn =
          typeof newVal === 'string'
            ? newVal
            : newVal && newVal.length > 0
              ? newVal[0].key
              : 'publication_id';
        const sortOrder =
          typeof newVal === 'string'
            ? this.sortDesc
              ? 'desc'
              : 'asc'
            : newVal && newVal.length > 0
              ? newVal[0].order
              : 'asc';
        const newSortString = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
        // Only trigger if sort actually changed
        if (newSortString !== this.sort) {
          this.handleSortByOrDescChange();
        }
      },
      deep: true,
    },
    // NOTE: We remove watch(perPage) and sortDesc to avoid double-calling
    // and rely solely on handlePerPageChange(newSize) and sortBy watcher.
  },
  mounted() {
    // Transform input sort string to Bootstrap-Vue-Next array format
    // sortStringToVariables now returns { sortBy: [{ key: 'column', order: 'asc'|'desc' }] }
    if (this.sortInput) {
      const sortObject = this.sortStringToVariables(this.sortInput);
      this.sortBy = sortObject.sortBy;
      this.sort = this.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (this.pageAfterInput && this.pageAfterInput !== '0') {
      this.currentItemID = parseInt(this.pageAfterInput, 10) || 0;
    }

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

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
    /**
     * updateBrowserUrl
     * Updates the browser URL with current table state using history.replaceState
     * to prevent Vue Router from remounting the component
     */
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
      const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
      window.history.replaceState({ ...window.history.state }, '', newUrl);
    },

    /**
     * loadData
     * Debounced wrapper for doLoadData to prevent duplicate calls
     */
    loadData() {
      // Debounce to prevent duplicate calls from multiple triggers
      if (this.loadDataDebounceTimer) {
        clearTimeout(this.loadDataDebounceTimer);
      }
      this.loadDataDebounceTimer = setTimeout(() => {
        this.loadDataDebounceTimer = null;
        this.doLoadData();
      }, 50);
    },

    /**
     * doLoadData
     * Fetches data from /api/publication using sort/filter/cursor pagination
     * Uses module-level caching to prevent duplicate API calls
     */
    async doLoadData() {
      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        `&page_after=${this.currentItemID}` +
        `&page_size=${this.perPage}`;

      const now = Date.now();

      // Prevent duplicate API calls using module-level tracking
      // This works across component remounts caused by router.replace()
      if (moduleLastApiParams === urlParam && now - moduleLastApiCallTime < 500) {
        // Use cached response data for remounted component
        if (moduleLastApiResponse) {
          this.applyApiResponse(moduleLastApiResponse);
          this.isBusy = false; // Clear busy state when using cached data
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

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}&fields=${this.fspecInput}`;

      try {
        const response = await this.axios.get(apiUrl);
        moduleApiCallInProgress = false;
        // Cache response for remounted components
        moduleLastApiResponse = response.data;
        this.applyApiResponse(response.data);

        // Update URL AFTER API success to prevent component remount during API call
        this.updateBrowserUrl();

        this.isBusy = false;
      } catch (error) {
        moduleApiCallInProgress = false;
        this.makeToast(error, 'Error', 'danger');
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

      // The meta array presumably includes pagination info
      if (data.meta && data.meta.length > 0) {
        const metaObj = data.meta[0];
        this.totalRows = metaObj.totalItems || 0;

        // Fix for b-pagination
        this.$nextTick(() => {
          this.currentPage = metaObj.currentPage;
        });
        this.totalPages = metaObj.totalPages;
        // Note: Publication IDs are strings like "PMID:12345", not numbers
        // Store as-is for cursor pagination, only convert to 0 if null/undefined
        this.prevItemID = metaObj.prevItemID === 'null' ? 0 : metaObj.prevItemID || 0;
        this.currentItemID = metaObj.currentItemID === 'null' ? 0 : metaObj.currentItemID || 0;
        this.nextItemID = metaObj.nextItemID === 'null' ? 0 : metaObj.nextItemID || 0;
        this.lastItemID = metaObj.lastItemID === 'null' ? 0 : metaObj.lastItemID || 0;
        this.executionTime = metaObj.executionTime;

        // Merge inbound fspec so we keep filterable: true
        if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
          this.fields = this.mergeFields(metaObj.fspec);
        }
      }
      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    },

    /**
     * handlePageChange
     * Moves to the next/previous "page" in cursor pagination.
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
     * handlePerPageChange
     * Called by the child TablePaginationControls when user picks a new page size
     */
    handlePerPageChange(newSize) {
      // Convert to integer
      this.perPage = parseInt(newSize, 10) || 10;
      this.currentItemID = 0;
      this.filtered();
    },

    /**
     * filtered
     * Rebuilds filter_string from filter object, calls loadData.
     */
    filtered() {
      const filterStringLoc = this.filterObjToStr(this.filter);
      if (filterStringLoc !== this.filter_string) {
        this.filter_string = filterStringLoc;
      }
      this.loadData();
    },

    /**
     * removeFilters
     * Clears the filter object, resets to page=1, reloads data.
     */
    removeFilters() {
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        publication_id: { content: null, join_char: null, operator: 'contains' },
        Title: { content: null, join_char: null, operator: 'contains' },
        Journal: { content: null, join_char: null, operator: 'contains' },
        Publication_date: { content: null, join_char: null, operator: 'contains' },
      };
      this.currentItemID = 0;
      this.filtered();
    },

    /**
     * removeSearch
     * Clears the "any" filter so column-specific filters remain
     */
    removeSearch() {
      this.filter.any.content = null;
    },

    /**
     * handleSortUpdate
     * Event fired from the GenericTable if user clicks a column header
     */
    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
    },

    /**
     * handleSortByOrDescChange
     * Rebuilds the sort param string (+ or -)
     */
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn =
        Array.isArray(this.sortBy) && this.sortBy.length > 0
          ? this.sortBy[0].key
          : typeof this.sortBy === 'string'
            ? this.sortBy
            : 'publication_id';
      const sortOrder =
        Array.isArray(this.sortBy) && this.sortBy.length > 0
          ? this.sortBy[0].order
          : this.sortDesc
            ? 'desc'
            : 'asc';
      const isDesc = sortOrder === 'desc';
      // Build sort string for API: +column for asc, -column for desc
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },

    /**
     * requestExcel
     * Makes a call to the same endpoint with format=xlsx to fetch an Excel file.
     */
    async requestExcel() {
      this.downloading = true;
      // For instance: &page_after=0&page_size=all&format=xlsx
      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        '&page_after=0' +
        '&page_size=all' +
        '&format=xlsx' +
        `&fields=${this.fspecInput}`;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });

        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');
        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'publications.xlsx');
        document.body.appendChild(fileLink);
        fileLink.click();
      } catch (error) {
        this.makeToast(error, 'Error downloading Excel', 'danger');
      }
      this.downloading = false;
    },

    /**
     * copyLinkToClipboard
     * Copies the current table state (sort, filter, pagination) to the clipboard as a URL
     */
    copyLinkToClipboard() {
      const urlParam =
        `sort=${this.sort}` +
        `&filter=${this.filter_string}` +
        `&page_after=${this.currentItemID}` +
        `&page_size=${this.perPage}`;
      const fullUrl = `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`;
      navigator.clipboard.writeText(fullUrl);
      this.makeToast('Link copied to clipboard', 'Info', 'info');
    },

    /**
     * mergeFields
     * Merges inbound fspec from the backend with your local fields array,
     * preserving filterable or selectable properties if they exist.
     */
    mergeFields(inboundFields) {
      return inboundFields.map((f) => {
        // Attempt to match inbound field by key
        const existing = this.fields.find((x) => x.key === f.key);
        return {
          ...f,
          // Preserve 'filterable' if it was in the local field
          filterable: existing ? existing.filterable : false,
          selectable: existing ? existing.selectable : false,
          // Keep local classes if desired
          class: existing ? existing.class : 'text-start',
        };
      });
    },

    /**
     * truncate
     * Shortens text to n chars + ellipsis, from utils.js
     */
    truncate(str, n) {
      return Utils.truncate(str, n);
    },

    /**
     * getPubMedUrl
     * Constructs PubMed URL from publication ID
     * @param {string} pubId - Publication ID (e.g., "PMID:12345678")
     * @returns {string} - PubMed URL
     */
    getPubMedUrl(pubId) {
      // Extract numeric ID from formats like "PMID:12345678" or just "12345678"
      const numericId = pubId?.replace(/^PMID:/i, '') || pubId;
      return `https://pubmed.ncbi.nlm.nih.gov/${numericId}`;
    },

    /**
     * formatDate
     * Formats date string for display
     * @param {string} dateStr - Date string (e.g., "2024-01-15")
     * @returns {string} - Formatted date
     */
    formatDate(dateStr) {
      if (!dateStr) return '';
      try {
        const date = new Date(dateStr);
        return date.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'short',
          day: 'numeric',
        });
      } catch {
        return dateStr;
      }
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
/* Modern publication table styling */
.publication-link {
  text-decoration: none;
  display: inline-block;
}

.publication-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.35em 0.65em;
  font-size: 0.85em;
  font-weight: 500;
  background-color: #e7f1ff;
  color: #0d6efd;
  border-radius: 0.375rem;
  transition: all 0.15s ease-in-out;
}

.publication-link:hover .publication-badge {
  background-color: #0d6efd;
  color: white;
}

.publication-id {
  font-family: 'SFMono-Regular', Menlo, Monaco, Consolas, monospace;
}

.external-icon {
  font-size: 0.75em;
  opacity: 0.7;
}

.title-cell {
  max-width: 400px;
}

.title-text {
  color: #333;
  line-height: 1.4;
}

.journal-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.85em;
  background-color: #f8f9fa;
  color: #495057;
  border-radius: 0.25rem;
  border: 1px solid #dee2e6;
}

.date-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.85em;
  background-color: #e8f5e9;
  color: #2e7d32;
  border-radius: 0.25rem;
  white-space: nowrap;
}
</style>
