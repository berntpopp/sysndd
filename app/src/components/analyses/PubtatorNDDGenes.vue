<!-- src/views/analyses/PubtatorNDDGenes.vue -->
<template>
  <div class="container-fluid">
    <!-- Loading spinner -->
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <!-- Main container -->
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- b-card with header controls -->
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
                    :subtitle="'Genes: ' + totalRows"
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

            <!-- Search + Pagination Controls -->
            <BRow>
              <!-- Global "any" search -->
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
            <!-- End Controls -->

            <!-- Main b-table -->
            <BTable
              :items="items"
              :fields="fields"
              :current-page="currentPage"
              :busy="isBusy"
              :sort-by="sortBy"
              no-local-sorting
              no-local-pagination
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              stacked="md"
              @update:sort-by="handleSortByUpdate"
            >
              <!-- Optional: custom table header cell, showing tooltips or partial labels -->
              <template #head()="columnData">
                <div
                  v-b-tooltip.hover.top
                  :title="
                    columnData.label +
                      ' (unique/total: ' +
                    fields.find((f) => f.label === columnData.label)?.count_filtered +
                      '/' +
                    fields.find((f) => f.label === columnData.label)?.count +
                      ')'
                  "
                >
                  {{ truncate(columnData.label, 20) }}
                </div>
              </template>

              <!-- A "top-row" slot for per-column filters -->
              <template #top-row>
                <td
                  v-for="field in fields"
                  :key="field.key"
                >
                  <!-- If this field is filterable, show an input -->
                  <BFormInput
                    v-if="field.filterable"
                    v-model="filter[field.key].content"
                    :placeholder="'.. ' + truncate(field.label, 20) + ' ..'"
                    debounce="500"
                    type="search"
                    autocomplete="off"
                    @click="removeSearch()"
                    @update="filtered()"
                  />

                  <!-- If we want a select dropdown for exact matching, uncomment below:
                  <BFormSelect
                    v-if="field.selectable"
                    v-model="filter[field.key].content"
                    :options="field.selectOptions"
                    type="search"
                    @input="removeSearch()"
                    @change="filtered()"
                  >
                    <template v-slot:first>
                      <BFormSelectOption value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                  -->
                </td>
              </template>
            </BTable>
            <!-- End b-table -->
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

// Small reusable components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';

import { useUiStore } from '@/stores/ui';

export default {
  name: 'PubtatorNDDGenes',
  components: {
    TableHeaderLabel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
  },
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Pubtator Genes table' },

    // Initial sorting can come in as a string like '+gene_symbol' or '-gene_symbol'
    sortInput: { type: String, default: '+gene_symbol' },

    // Filter string from route query if desired
    filterInput: { type: String, default: null },

    // Not used in this simplified version, but you can pass in other fields
    fieldsInput: { type: String, default: null },

    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: String, default: '10' },

    // The server might expect these fields in the "fspec"
    fspecInput: {
      type: String,
      default: 'gene_name,gene_symbol,gene_normalized_id,hgnc_id,publication_count,entities_count',
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
      gene_name: { content: null, join_char: null, operator: 'contains' },
      gene_symbol: { content: null, join_char: null, operator: 'contains' },
      gene_normalized_id: { content: null, join_char: null, operator: 'contains' },
      hgnc_id: { content: null, join_char: null, operator: 'contains' },
      publication_count: { content: null, join_char: null, operator: 'contains' },
      entities_count: { content: null, join_char: null, operator: 'contains' },
    });

    // Inject axios and route
    const axios = inject('axios');
    const route = useRoute();

    // Table methods composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      apiEndpoint: 'pubtator_genes',
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
      // Table columns. We'll make them all filterable for demonstration.
      fields: [
        {
          key: 'gene_name',
          label: 'Gene name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'gene_symbol',
          label: 'Gene symbol',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'gene_normalized_id',
          label: 'Gene normalized id',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'hgnc_id',
          label: 'HGNC id',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'publication_count',
          label: 'Publication count',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'entities_count',
          label: 'Entities count',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
      ],

      // Table data (items and other properties now in setup())
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'gene_symbol', order: 'asc' }],
      sort: '+gene_symbol',
      filter_string: '',

      // Cursor pagination
      prevItemID: null,
      currentItemID: 0,
      nextItemID: null,
      lastItemID: null,
      totalPages: 0,

      // Execution
      executionTime: 0,

      // UI states
      loading: true,
      isBusy: false,
      downloading: false,
    };
  },
  watch: {
    // Watch filter changes -> reload
    filter() {
      this.filtered();
    },
  },
  mounted() {
    // Transform "+gene_symbol" into sortBy="gene_symbol" and sortDesc=false
    const sortObject = this.sortStringToVariables(this.sortInput);
    this.sortBy = sortObject.sortColumn;
    this.sortDesc = sortObject.sortDesc;

    // If we have a pre-loaded filter string, parse it
    if (this.filterInput && this.filterInput !== 'null' && this.filterInput !== '') {
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    }
    // Slight delay, then show table
    setTimeout(() => {
      this.loading = false;
    }, 500);

    // Load initial data
    this.loadData();
  },
  methods: {
    async loadData() {
      this.isBusy = true;
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`
        + `&fields=${this.fspecInput}`;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
        this.items = response.data.data;

        if (response.data.meta && response.data.meta.length > 0) {
          const metaObj = response.data.meta[0];
          this.totalRows = metaObj.totalItems || 0;
          this.totalPages = metaObj.totalPages || 1;
          this.prevItemID = metaObj.prevItemID || null;
          this.currentItemID = metaObj.currentItemID || 0;
          this.nextItemID = metaObj.nextItemID || null;
          this.lastItemID = metaObj.lastItemID || null;
          this.executionTime = metaObj.executionTime || 0;

          // Fix for b-pagination (which expects currentPage)
          this.$nextTick(() => {
            this.currentPage = metaObj.currentPage;
          });

          // Optionally merge any fspec changes into fields
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

    // Called when user changes page
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

    // Called when user changes page size (10, 25, etc.)
    handlePerPageChange(newSize) {
      this.perPage = parseInt(newSize, 10) || 10;
      this.currentItemID = 0;
      this.filtered();
    },

    // Rebuild filter string, reload data
    filtered() {
      const filterStringLoc = this.filterObjToStr(this.filter);
      if (filterStringLoc !== this.filter_string) {
        this.filter_string = filterStringLoc;
      }
      this.loadData();
    },

    // Clear all filters
    removeFilters() {
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        gene_name: { content: null, join_char: null, operator: 'contains' },
        gene_symbol: { content: null, join_char: null, operator: 'contains' },
        gene_normalized_id: { content: null, join_char: null, operator: 'contains' },
        hgnc_id: { content: null, join_char: null, operator: 'contains' },
        publication_count: { content: null, join_char: null, operator: 'contains' },
        entities_count: { content: null, join_char: null, operator: 'contains' },
      };
      this.currentItemID = 0;
      this.filtered();
    },

    // Clear the global "any" filter
    removeSearch() {
      this.filter.any.content = null;
    },

    /**
     * Handles sortBy updates from Bootstrap-Vue-Next BTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
      this.currentItemID = 0;
      // Extract sort string from array format for API
      if (newSortBy && newSortBy.length > 0) {
        const sortKey = newSortBy[0].key;
        const sortDesc = newSortBy[0].order === 'desc';
        this.sort = (sortDesc ? '-' : '+') + sortKey;
      }
      this.filtered();
    },

    // Excel download
    async requestExcel() {
      this.downloading = true;
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + '&page_after=0'
        + '&page_size=all'
        + '&format=xlsx'
        + `&fields=${this.fspecInput}`;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes?${urlParam}`;

      try {
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });
        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');
        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'genes.xlsx');
        document.body.appendChild(fileLink);
        fileLink.click();
      } catch (error) {
        this.makeToast(error, 'Error downloading Excel', 'danger');
      }
      this.downloading = false;
    },

    // Copy current filter/sort state to clipboard
    copyLinkToClipboard() {
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`;
      const fullUrl = `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`;
      navigator.clipboard.writeText(fullUrl);
      this.makeToast('Link copied to clipboard', 'Info', 'info');
    },

    // If server returns fspec changes, merge them into local fields
    mergeFields(inboundFields) {
      return inboundFields.map((f) => {
        const existing = this.fields.find((x) => x.key === f.key);
        return {
          ...f,
          // Force filterable if you want all columns text-filterable
          filterable: true,
          selectable: existing ? existing.selectable : false,
          class: existing ? existing.class : 'text-start',
        };
      });
    },

    // Simple truncation utility
    truncate(str, n) {
      return str?.length > n ? `${str.slice(0, n)}...` : str;
    },

    // Example Treeselect normalizer if needed
    normalizer(node) {
      return {
        id: node,
        label: node,
        children: [],
      };
    },
  },
};
</script>

<style scoped>
/* Some example styling you already had */
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

/* Optional: narrower placeholders */
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}
</style>
