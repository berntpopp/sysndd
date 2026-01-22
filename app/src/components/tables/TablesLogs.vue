<!-- src/components/tables/TablesLogs.vue -->
<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
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
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Log entries: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </b-col>
                <b-col>
                  <h5
                    v-if="showFilterControls"
                    class="mb-1 text-right font-weight-bold"
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

            <b-row>
              <b-col
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter['any'].content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </b-col>

              <b-col
                class="my-1"
                sm="4"
              >
                <b-container v-if="totalRows > perPage || showPaginationControls">
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
            <!-- User Interface controls -->

            <!-- Main table element -->
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

              <template v-slot:cell-id="{ row }">
                <div>
                  <b-badge
                    variant="primary"
                    style="cursor: pointer"
                  >
                    {{ row.id }}
                  </b-badge>
                </div>
              </template>

              <template v-slot:cell-agent="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.agent"
                >
                  <b-badge
                    pill
                    variant="info"
                  >
                    {{ truncate(row.agent, 50) }}
                  </b-badge>
                </div>
              </template>

              <template v-slot:cell-status="{ row }">
                <b-badge :variant="row.status === 200 ? 'success' : 'danger'">
                  {{ row.status }}
                </b-badge>
              </template>

              <template v-slot:cell-request_method="{ row }">
                <b-badge :variant="getMethodVariant(row.request_method)">
                  {{ row.request_method }}
                </b-badge>
              </template>

              <template v-slot:cell-query="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.query"
                >
                  {{ row.query }}
                </div>
              </template>

              <template v-slot:cell-timestamp="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate"
                  :title="row.timestamp"
                >
                  {{ formatDate(row.timestamp) }}
                </div>
              </template>

              <template v-slot:cell-modified="{ row }">
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
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import Treeselect from '@riophae/vue-treeselect';
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

import toastMixin from '@/assets/js/mixins/toastMixin';
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

import tableMethodsMixin from '@/assets/js/mixins/tableMethodsMixin';
import tableDataMixin from '@/assets/js/mixins/tableDataMixin';

import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';

export default {
  name: 'TablesLogs',
  components: {
    Treeselect,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableHeaderLabel,
    TableSearchInput,
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
  data() {
    return {
      items: [],
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
      totalRows: 0,
      currentPage: 1,
      currentItemID: this.pageAfterInput,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      pageOptions: ['10', '25', '50', '200'],
      sortBy: 'id',
      sortDesc: true,
      sort: this.sortInput,
      filter: {
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
      },
      filter_string: null,
      downloading: false,
      loading: false,
      isBusy: true,
    };
  },
  watch: {
    filter(value) {
      this.filtered();
    },
    sortBy(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.handleSortByOrDescChange();
      }
    },
    sortDesc(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.handleSortByOrDescChange();
      }
    },
  },
  created() {
    // Lifecycle hooks
  },
  mounted() {
    // Lifecycle hooks
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;
    this.sortDesc = sort_object.sortDesc;

    if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    } else {
      this.loadData();
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
    async loadData() {
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

        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (error) {
        this.makeToast(`Error: ${error.message}`, 'Error loading logs', 'danger');
      } finally {
        this.isBusy = false;
      }
    },
    copyLinkToClipboard() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      navigator.clipboard.writeText(`${process.env.VUE_APP_URL + this.$route.path}?${urlParam}`);
    },
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      this.sort = (!this.sortDesc ? '-' : '+') + this.sortBy;
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
