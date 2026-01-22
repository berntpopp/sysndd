<!-- src/components/analyses/PubtatorNDDTable.vue -->
<template>
  <div class="container-fluid">
    <!-- Show an overlay spinner while loading -->
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <!-- Once loaded, show the table container -->
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col md="12">
          <!-- b-card wrapper for the table and controls -->
          <b-card
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <!-- Card Header -->
            <template #header>
              <b-row>
                <b-col>
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Publications: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </b-col>
                <b-col>
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
                </b-col>
              </b-row>
            </template>

            <!-- Controls (search + pagination) -->
            <b-row>
              <!-- Search box for "any" field -->
              <b-col
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter.any.content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </b-col>

              <!-- Pagination controls -->
              <b-col
                class="my-1"
                sm="4"
              >
                <b-container
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
                </b-container>
              </b-col>
            </b-row>
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
                v-slot:filter-controls
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
              <!-- Custom filter fields slot -->

              <!-- search_id -->
              <template v-slot:cell-search_id="{ row }">
                <div>
                  <b-badge
                    variant="primary"
                    style="cursor: pointer"
                  >
                    {{ row.search_id }}
                  </b-badge>
                </div>
              </template>

              <!-- pmid -->
              <template v-slot:cell-pmid="{ row }">
                <b-button
                  v-b-tooltip.hover.bottom
                  class="btn-xs mx-2"
                  variant="primary"
                  :href=" 'https://pubmed.ncbi.nlm.nih.gov/' + row.pmid "
                  target="_blank"
                  :title="row.pmid"
                >
                  <b-icon
                    icon="box-arrow-up-right"
                    font-scale="0.8"
                  />
                  PMID: {{ row.pmid }}
                </b-button>
              </template>

              <!-- doi -->
              <template v-slot:cell-doi="{ row }">
                <div class="text-truncate">
                  <a
                    :href="`https://doi.org/${row.doi}`"
                    target="_blank"
                  >
                    {{ row.doi }}
                  </a>
                </div>
              </template>

              <!-- title -->
              <template v-slot:cell-title="{ row }">
                <div
                  v-b-tooltip.hover
                  :title="row.title"
                  class="overflow-hidden text-truncate"
                  style="max-width: 300px;"
                >
                  {{ truncate(row.title, 60) }}
                </div>
              </template>

              <!-- journal -->
              <template v-slot:cell-journal="{ row }">
                <div>
                  {{ row.journal }}
                </div>
              </template>

              <!-- date -->
              <template v-slot:cell-date="{ row }">
                <div>
                  {{ row.date }}
                </div>
              </template>

              <!-- score -->
              <template v-slot:cell-score="{ row }">
                <div>
                  {{ row.score ? row.score.toFixed(3) : '' }}
                </div>
              </template>

              <!-- text_hl -->
              <template v-slot:cell-text_hl="{ row }">
                <div
                  v-if="row.text_hl"
                  v-b-tooltip.hover
                  :title="row.text_hl"
                  class="overflow-hidden text-truncate"
                  style="max-width: 400px;"
                >
                  {{ truncate(row.text_hl, 60) }}
                </div>
                <div v-else>
                  <span class="text-muted">No highlight text</span>
                </div>
              </template>
            </GenericTable>
            <!-- Main GenericTable -->
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// Table/pagination/data mixins
import tableMethodsMixin from '@/assets/js/mixins/tableMethodsMixin';
import tableDataMixin from '@/assets/js/mixins/tableDataMixin';

// Small reusable components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

export default {
  name: 'PubtatorNDDTable',
  components: {
    TableHeaderLabel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    GenericTable,
  },
  mixins: [
    toastMixin,
    urlParsingMixin,
    colorAndSymbolsMixin,
    textMixin,
    tableMethodsMixin,
    tableDataMixin,
  ],
  props: {
    apiEndpoint: {
      type: String,
      default: 'publication/pubtator/table',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Pubtator Publications table' },
    sortInput: { type: String, default: '-search_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default: 'search_id,pmid,doi,title,journal,date,score,text_hl',
    },
  },
  data() {
    return {
      // Table columns
      fields: [
        {
          key: 'search_id',
          label: 'Search ID',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'pmid',
          label: 'PMID',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'doi',
          label: 'DOI',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'title',
          label: 'Title',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'journal',
          label: 'Journal',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'date',
          label: 'Date',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'score',
          label: 'Score',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
        {
          key: 'text_hl',
          label: 'Text HL',
          sortable: true,
          class: 'text-start',
          filterable: true,
        },
      ],
      // Additional hidden or detail fields can go here:
      fields_details: [],

      // Basic data or filter state
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        search_id: { content: null, join_char: null, operator: 'contains' },
        pmid: { content: null, join_char: null, operator: 'contains' },
        doi: { content: null, join_char: null, operator: 'contains' },
        title: { content: null, join_char: null, operator: 'contains' },
        journal: { content: null, join_char: null, operator: 'contains' },
        date: { content: null, join_char: null, operator: 'contains' },
        score: { content: null, join_char: null, operator: 'contains' },
        text_hl: { content: null, join_char: null, operator: 'contains' },
      },
      // Table items
      items: [],
      totalRows: 0,
      currentPage: 1,
      perPage: 10,
      pageOptions: [10, 25, 50],
      sortBy: 'search_id',
      sortDesc: false,
      sort: '+search_id',
      filter_string: '',

      // Cursor pagination info
      prevItemID: null,
      currentItemID: 0,
      nextItemID: null,
      lastItemID: null,
      totalPages: 0,

      // Execution time
      executionTime: 0,

      // UI states
      loading: true,
      isBusy: false,
      downloading: false,
    };
  },
  watch: {
    // Re-run data load when filter changes
    filter() {
      this.filtered();
    },
    // Re-run data load when sorting changes
    sortBy() {
      this.handleSortByOrDescChange();
    },
    sortDesc() {
      this.handleSortByOrDescChange();
    },
  },
  mounted() {
    // Initialize sorting
    const sortObject = this.sortStringToVariables(this.sortInput);
    this.sortBy = sortObject.sortBy;
    this.sortDesc = sortObject.sortDesc;

    // Initialize filters from input
    if (this.filterInput && this.filterInput !== 'null') {
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);

    // Load initial data
    this.loadTableData();
  },
  methods: {
    /**
     * loadTableData
     * Fetches data from the API using sort/filter/cursor pagination
     */
    async loadTableData() {
      this.isBusy = true;

      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`
        + `&fields=${this.fspecInput}`;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
        this.items = response.data.data;

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

    handlePerPageChange(newSize) {
      this.perPage = parseInt(newSize, 10) || 10;
      this.currentItemID = 0;
      this.filtered();
    },

    filtered() {
      const filterStringLoc = this.filterObjToStr(this.filter);
      if (filterStringLoc !== this.filter_string) {
        this.filter_string = filterStringLoc;
      }
      this.loadTableData();
    },

    removeFilters() {
      // Reset every field's filter to null
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        search_id: { content: null, join_char: null, operator: 'contains' },
        pmid: { content: null, join_char: null, operator: 'contains' },
        doi: { content: null, join_char: null, operator: 'contains' },
        title: { content: null, join_char: null, operator: 'contains' },
        journal: { content: null, join_char: null, operator: 'contains' },
        date: { content: null, join_char: null, operator: 'contains' },
        score: { content: null, join_char: null, operator: 'contains' },
        text_hl: { content: null, join_char: null, operator: 'contains' },
      };
      this.currentItemID = 0;
      this.filtered();
    },

    removeSearch() {
      this.filter.any.content = null;
    },

    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
    },

    handleSortByOrDescChange() {
      this.currentItemID = 0;
      this.sort = (!this.sortDesc ? '+' : '-') + this.sortBy;
      this.filtered();
    },

    async requestExcel() {
      this.downloading = true;
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + '&page_after=0'
        + '&page_size=all'
        + '&format=xlsx'
        + `&fields=${this.fspecInput}`;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/${this.apiEndpoint}?${urlParam}`;

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

    copyLinkToClipboard() {
      const urlParam = `sort=${this.sort}`
        + `&filter=${this.filter_string}`
        + `&page_after=${this.currentItemID}`
        + `&page_size=${this.perPage}`;
      const fullUrl = `${process.env.VUE_APP_URL + this.$route.path}?${urlParam}`;
      navigator.clipboard.writeText(fullUrl);
      this.makeToast('Link copied to clipboard', 'Info', 'info');
    },

    mergeFields(inboundFields) {
      return inboundFields.map((f) => {
        const existing = this.fields.find((x) => x.key === f.key);
        return {
          ...f,
          // If your inbound fspec sets filterable, keep it or override it
          // For now, we forcibly set filterable to true, but you can merge logic
          filterable: true,
          selectable: existing ? existing.selectable : false,
          class: existing ? existing.class : 'text-start',
          multi_selectable: existing ? existing.multi_selectable : false,
        };
      });
    },

    truncate(str, n) {
      return Utils.truncate(str, n);
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
</style>
