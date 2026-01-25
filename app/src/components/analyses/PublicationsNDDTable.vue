<!-- src/components/analyses/PublicationsNDDTable.vue -->
<template>
  <div class="container-fluid">
    <!-- Show an overlay spinner while loading -->
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <!-- Once loaded, show the table container -->
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- b-card wrapper for the table and controls -->
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
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

            <!-- Controls (search + pagination) -->
            <BRow>
              <!-- Search box for "any" field -->
              <BCol
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter.any.content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </BCol>

              <!-- Pagination controls -->
              <BCol
                class="my-1"
                sm="4"
              >
                <BContainer
                  v-if="totalRows > perPage || showPaginationControls"
                >
                  <!--
                    TablePaginationControls will emit:
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  -->
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

              <!-- Example custom slot for 'publication_id' -->
              <template #cell-publication_id="{ row }">
                <div>
                  <BBadge
                    variant="primary"
                    style="cursor: pointer"
                  >
                    {{ row.publication_id }}
                  </BBadge>
                </div>
              </template>

              <!-- Example custom slot for 'Title' -->
              <template #cell-Title="{ row }">
                <div
                  v-b-tooltip.hover
                  class="overflow-hidden text-truncate"
                  :title="row.Title"
                >
                  {{ truncate(row.Title, 50) }}
                </div>
              </template>

              <!-- Example custom slot for 'Journal' -->
              <template #cell-Journal="{ row }">
                <div>
                  {{ row.Journal }}
                </div>
              </template>

              <!-- Example custom slot for 'Publication_date' -->
              <template #cell-Publication_date="{ row }">
                <div>
                  {{ row.Publication_date }}
                </div>
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
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
} from '@/composables';

// Small reusable components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

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
      // Table columns
      fields: [
        {
          key: 'publication_id',
          label: 'ID',
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
          key: 'Journal',
          label: 'Journal',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'Publication_date',
          label: 'Date',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
      ],
      // Additional hidden or detail fields can go here:
      fields_details: [],

      // Note: Table state (items, totalRows, perPage, sortBy, sortDesc, loading, isBusy,
      // downloading, currentItemID, prevItemID, nextItemID, lastItemID, executionTime,
      // filter_string, etc.) is provided by useTableData composable in setup()

      // Component-specific cursor pagination info (not in useTableData)
      totalPages: 0,
    };
  },
  watch: {
    // Watch the filters -> load new data
    filter() {
      this.filtered();
    },
    // Watch sorting -> load new data
    sortBy() {
      this.handleSortByOrDescChange();
    },
    sortDesc() {
      this.handleSortByOrDescChange();
    },
    // NOTE: We remove watch(perPage) to avoid double-calling
    // and rely solely on handlePerPageChange(newSize).
  },
  mounted() {
    // Initialize sorting from input
    const sortObject = this.sortStringToVariables(this.sortInput);
    this.sortBy = sortObject.sortColumn;
    this.sortDesc = sortObject.sortDesc;

    // Initialize filters from input
    if (this.filterInput && this.filterInput !== 'null') {
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    }

    // Slight delay, then mark loading false
    setTimeout(() => {
      this.loading = false;
    }, 500);

    // Load initial table data
    this.loadTableData();
  },
  methods: {
    /**
     * loadTableData
     * Fetches data from /api/publication using sort/filter/cursor pagination
     */
    async loadTableData() {
      this.isBusy = true;

      // Build query
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`
        + `&fields=${this.fspecInput}`;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
        this.items = response.data.data;

        // The meta array presumably includes pagination info
        if (response.data.meta && response.data.meta.length > 0) {
          const metaObj = response.data.meta[0];
          this.totalRows = metaObj.totalItems || 0;

          // Fix for b-pagination
          this.$nextTick(() => {
            this.currentPage = metaObj.currentPage;
          });
          this.totalPages = metaObj.totalPages;
          this.prevItemID = metaObj.prevItemID;
          this.currentItemID = metaObj.currentItemID;
          this.nextItemID = metaObj.nextItemID;
          this.lastItemID = metaObj.lastItemID;
          this.executionTime = metaObj.executionTime;

          // Merge inbound fspec so we keep filterable: true
          if (metaObj.fspec && Array.isArray(metaObj.fspec)) {
            this.fields = this.mergeFields(metaObj.fspec);
          }
        }
        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (error) {
        this.makeToast(error, 'Error', 'danger');
      } finally {
        this.isBusy = false;
      }
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
     * Rebuilds filter_string from filter object, calls loadTableData.
     */
    filtered() {
      const filterStringLoc = this.filterObjToStr(this.filter);
      if (filterStringLoc !== this.filter_string) {
        this.filter_string = filterStringLoc;
      }
      this.loadTableData();
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
      // Ensure sortBy is a string for the API URL
      const sortColumn = typeof this.sortBy === 'string' ? this.sortBy : (this.sortBy[0]?.key || 'publication_id');
      this.sort = (!this.sortDesc ? '+' : '-') + sortColumn;
      this.filtered();
    },

    /**
     * requestExcel
     * Makes a call to the same endpoint with format=xlsx to fetch an Excel file.
     */
    async requestExcel() {
      this.downloading = true;
      // For instance: &page_after=0&page_size=all&format=xlsx
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + '&page_after=0'
        + '&page_size=all'
        + '&format=xlsx'
        + `&fields=${this.fspecInput}`;
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
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`;
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
/* Example styling similar to your Entities table code. */
</style>
