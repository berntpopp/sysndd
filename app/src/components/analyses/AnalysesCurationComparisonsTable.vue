<!-- src/components/analyses/AnalysesCurationComparisonsTable.vue -->
<template>
  <b-container fluid>
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
            <h6 class="mb-1 text-start font-weight-bold">
              Comparing the presence of a gene in different
              <mark
                v-b-tooltip.hover.leftbottom
                title="These have been reviewed to include lists which are regularly updated. Below table allows users to filter the presence of a gene (normalized category/ not listed) in the respective list overlaps."
              >curation efforts</mark>
              for NDDs.

              <b-badge
                id="popover-badge-help-comparisons"
                pill
                href="#"
                variant="info"
              >
                <b-icon icon="question-circle-fill" />
              </b-badge>

              <b-popover
                target="popover-badge-help-comparisons"
                variant="info"
                triggers="focus"
              >
                <template #title>
                  Comparisons selection [last update 2023-04-13]
                </template>
                The NDD databases and lists for the comparison with SysNDD are:
                <br>
                <strong>1) radboudumc ID,</strong> downloaded and normalized
                from https://order.radboudumc.nl/en/LabProduct/Pdf/30240, <br>
                <strong>2) gene2phenotype ID</strong> downloaded and normalized
                from https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz,
                <br>
                <strong>3) panelapp ID</strong> downloaded and normalized from
                https://panelapp.genomicsengland.co.uk/panels/285/download/01234/,
                <br>
                <strong>4) sfari</strong> downloaded and normalized from
                https://gene.sfari.org//wp-content/themes/sfari-gene/utilities/download-csv.php?api-endpoint=genes,
                <br>
                <strong>5) geisinger DBD</strong> downloaded and normalized from
                https://dbd.geisingeradmi.org/downloads/DBD-Genes-Full-Data.csv,
                <br>
                <strong>6) orphanet ID</strong> downloaded and normalized from
                https://id-genes.orphanet.app/es/index/sysid_index_1, <br>
                <strong>7) OMIM NDD</strong> filtered OMIM for the HPO term
                "Neurodevelopmental abnormality" (HP:0012759) and all its child
                terms using the files phenotype_to_genes
                (http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa)
                and genemap2
                (https://data.omim.org/downloads/9GJLEFvqSmWaImCijeRdVA/genemap2.txt),
                <br>
              </b-popover>
            </h6>

            <h6 class="mb-1 text-start font-weight-bold">
              <b-badge
                v-b-tooltip.hover.bottom
                variant="success"
                :title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
              >
                Genes: {{ totalRows }}
              </b-badge>
            </h6>
          </b-col>
          <b-col>
            <h5
              v-if="showFilterControls"
              class="mb-1 text-end font-weight-bold"
            >
              <b-button
                v-b-tooltip.hover.bottom
                class="me-1"
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
                size="sm"
                :title="'The table is ' + (filter_string === '' ? 'not' : '') + ' filtered.' + (filter_string === '' ? '' : ' Click to remove all filters.')"
                :variant="filter_string === '' ? 'info' : 'warning'"
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

      <div v-if="!loadingTable">
        <b-row>
          <b-col
            class="my-1"
            sm="6"
          >
            <b-form-group class="mb-1 border-dark">
              <b-form-input
                v-if="showFilterControls"
                id="filter-input"
                v-model="filter['any'].content"
                class="filter-input mb-1 border-dark"
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
                  class="filter-input"
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
      </div>

      <div class="position-relative">
        <b-spinner
          v-if="loadingTable"
          label="Loading..."
          class="spinner"
        />
        <GenericTable
          v-else
          :items="items"
          :fields="fields"
          :current-page="currentPage"
          :is-busy="isBusy"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          @update-sort="handleSortUpdate"
        >
          <template v-slot:filter-controls>
            <td
              v-for="field in fields"
              :key="field.key"
            >
              <b-form-input
                v-if="field.filterable"
                v-model="filter[field.key].content"
                class="filter-input"
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
                class="filter-input"
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
                  class="filter-input"
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

          <template v-slot:cell-symbol="{ row }">
            <div class="font-italic">
              <b-link :href="'/Genes/' + row.hgnc_id">
                <b-badge
                  v-b-tooltip.hover.leftbottom
                  pill
                  variant="success"
                  :title="row.hgnc_id"
                >
                  {{ row.symbol }}
                </b-badge>
              </b-link>
            </div>
          </template>

          <template v-slot:cell-SysNDD="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.SysNDD]"
                :title="row.SysNDD"
              />
            </div>
          </template>

          <template v-slot:cell-radboudumc_ID="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.radboudumc_ID]"
                :title="row.radboudumc_ID"
              />
            </div>
          </template>

          <template v-slot:cell-gene2phenotype="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.gene2phenotype]"
                :title="row.gene2phenotype"
              />
            </div>
          </template>

          <template v-slot:cell-panelapp="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.panelapp]"
                :title="row.panelapp"
              />
            </div>
          </template>

          <template v-slot:cell-sfari="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.sfari]"
                :title="row.sfari"
              />
            </div>
          </template>

          <template v-slot:cell-geisinger_DBD="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.geisinger_DBD]"
                :title="row.geisinger_DBD"
              />
            </div>
          </template>

          <template v-slot:cell-omim_ndd="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.omim_ndd]"
                :title="row.omim_ndd"
              />
            </div>
          </template>

          <template v-slot:cell-orphanet_id="{ row }">
            <div>
              <b-avatar
                v-b-tooltip.hover.left
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[row.orphanet_id]"
                :title="row.orphanet_id"
              />
            </div>
          </template>
        </GenericTable>
      </div>
    </b-card>
  </b-container>
</template>

<script>
// import the Treeselect component
import Treeselect from '@r2rka/vue3-treeselect';
// import the Treeselect styles
import '@r2rka/vue3-treeselect/dist/style.css';

import toastMixin from '@/assets/js/mixins/toastMixin';
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the GenericTable component
import GenericTable from '@/components/small/GenericTable.vue';

export default {
  name: 'AnalysesCurationComparisonsTable',
  // register the Treeselect component and GenericTable component
  components: { Treeselect, GenericTable },
  mixins: [toastMixin, urlParsingMixin, colorAndSymbolsMixin],
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    sortInput: { type: String, default: '+symbol' },
    filterInput: { type: String, default: 'filter=' },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: String, default: '10' },
    fspecInput: {
      type: String,
      default:
          'symbol,SysNDD,radboudumc_ID,gene2phenotype,panelapp,sfari,geisinger_DBD,omim_ndd,orphanet_id',
    },
  },
  data() {
    return {
      items: [],
      fields: [
        {
          key: 'symbol',
          label: 'Symbol',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'SysNDD',
          label: 'SysNDD',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'radboudumc_ID',
          label: 'Radboud UMC ID',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'gene2phenotype',
          label: 'gene2phenotype',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'panelapp',
          label: 'PanelApp',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'sfari',
          label: 'SFARI',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'geisinger_DBD',
          label: 'Geisinger DBD',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'omim_ndd',
          label: 'OMIM NDD',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'orphanet_id',
          label: 'Orphanet ID',
          sortable: true,
          filterable: true,
          class: 'text-start',
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
      sortBy: 'symbol',
      sortDesc: false,
      sort: this.sortInput,
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        SysNDD: { content: null, join_char: ',', operator: 'any' },
        radboudumc_ID: { content: null, join_char: null, operator: 'contains' },
        gene2phenotype: { content: null, join_char: ',', operator: 'any' },
        panelapp: { content: null, join_char: ',', operator: 'any' },
        sfari: { content: null, join_char: ',', operator: 'any' },
        geisinger_DBD: { content: null, join_char: null, operator: 'contains' },
        omim_ndd: { content: null, join_char: null, operator: 'contains' },
        orphanet_id: { content: null, join_char: null, operator: 'contains' },
      },
      filter_string: '',
      filterOn: [],
      loadingTable: true,
      isBusy: true,
      downloading: false,
    };
  },
  watch: {
    filter(value) {
      this.filtered();
    },
    sortBy() {
      this.handleSortByOrDescChange();
    },
    sortDesc() {
      this.handleSortByOrDescChange();
    },
    perPage() {
      this.handlePerPageChange();
    },
  },
  created() {
    this.filter = this.filterStrToObj(this.filterInput, this.filter);
  },
  mounted() {
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;
    this.sortDesc = sort_object.sortDesc;

    setTimeout(() => {
      this.loadingTable = false;
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
    async loadTableData() {
      this.isBusy = true;

      const urlParam = `sort=${
        this.sort
      }&filter=${
        this.filter_string
      }&page_after=${
        this.currentItemID
      }&page_size=${
        this.perPage}`;

      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/comparisons/browse?${
        urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
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

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async requestExcel() {
      this.downloading = true;

      const urlParam = `sort=${
        this.sort
      }&filter=${
        this.filter_string
      }&page_after=`
          + '0'
          + '&page_size='
          + 'all'
          + '&format=xlsx';

      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/comparisons/browse?${
        urlParam}`;

      try {
        const response = await this.axios({
          url: apiUrl,
          method: 'GET',
          responseType: 'blob',
        });

        const fileURL = window.URL.createObjectURL(new Blob([response.data]));
        const fileLink = document.createElement('a');

        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'curation_comparisons.xlsx');
        document.body.appendChild(fileLink);

        fileLink.click();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.downloading = false;
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

      this.loadTableData();
    },
    removeFilters() {
      this.filter = {
        any: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        SysNDD: { content: null, join_char: ',', operator: 'any' },
        radboudumc_ID: { content: null, join_char: null, operator: 'contains' },
        gene2phenotype: { content: null, join_char: ',', operator: 'any' },
        panelapp: { content: null, join_char: ',', operator: 'any' },
        sfari: { content: null, join_char: ',', operator: 'any' },
        geisinger_DBD: { content: null, join_char: null, operator: 'contains' },
        omim_ndd: { content: null, join_char: null, operator: 'contains' },
        orphanet_id: { content: null, join_char: null, operator: 'contains' },
      };
    },
    removeSearch() {
      this.filter.any.content = null;
    },
    normalizer(node) {
      return {
        id: node,
        label: node,
      };
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
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
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
.filter-input {
  font-size: 0.875rem;
  color: #495057;
  border-color: #ced4da;
}
</style>
