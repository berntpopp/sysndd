<!-- src/components/analyses/AnalysesCurationComparisonsTable.vue -->
<template>
  <BContainer fluid>
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
            <h6 class="mb-1 text-start font-weight-bold">
              Comparing the presence of a gene in different
              <mark
                v-b-tooltip.hover.leftbottom
                title="These have been reviewed to include lists which are regularly updated. Below table allows users to filter the presence of a gene (normalized category/ not listed) in the respective list overlaps."
              >curation efforts</mark>
              for NDDs.

              <BBadge
                id="popover-badge-help-comparisons"
                pill
                href="#"
                variant="info"
              >
                <i class="bi bi-question-circle-fill" />
              </BBadge>

              <BPopover
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
              </BPopover>
            </h6>

            <h6 class="mb-1 text-start font-weight-bold">
              <BBadge
                v-b-tooltip.hover.bottom
                variant="success"
                :title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
              >
                Genes: {{ totalRows }}
              </BBadge>
            </h6>
          </BCol>
          <BCol>
            <h5
              v-if="showFilterControls"
              class="mb-1 text-end font-weight-bold"
            >
              <BButton
                v-b-tooltip.hover.bottom
                class="me-1"
                size="sm"
                title="Download data as Excel file."
                @click="requestExcel()"
              >
                <i class="bi bi-table mx-1" />
                <i
                  v-if="!downloading"
                  class="bi bi-download"
                />
                <BSpinner
                  v-if="downloading"
                  small
                />
                .xlsx
              </BButton>
              <BButton
                v-b-tooltip.hover.bottom
                size="sm"
                :title="'The table is ' + (filter_string === '' ? 'not' : '') + ' filtered.' + (filter_string === '' ? '' : ' Click to remove all filters.')"
                :variant="filter_string === '' ? 'info' : 'warning'"
                @click="removeFilters()"
              >
                <i class="bi bi-filter" />
              </BButton>
            </h5>
          </BCol>
        </BRow>
      </template>

      <div v-if="!loadingTable">
        <BRow>
          <BCol
            class="my-1"
            sm="6"
          >
            <BFormGroup class="mb-1 border-dark">
              <BFormInput
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
            </BFormGroup>
          </BCol>

          <BCol
            class="my-1"
            sm="4"
          >
            <BContainer
              v-if="totalRows > perPage || showPaginationControls"
            >
              <BInputGroup
                prepend="Per page"
                class="mb-1"
                size="sm"
              >
                <BFormSelect
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  class="filter-input"
                  size="sm"
                />
              </BInputGroup>

              <BPagination
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
                limit="2"
                @change="handlePageChange"
              />
            </BContainer>
          </BCol>
        </BRow>
      </div>

      <div class="position-relative">
        <BSpinner
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
              <BFormInput
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

              <BFormSelect
                v-if="field.selectable && field.selectOptions && field.selectOptions.length > 0"
                v-model="filter[field.key].content"
                class="filter-input"
                :options="normalizeSelectOptions(field.selectOptions)"
                size="sm"
                @input="removeSearch()"
                @change="filtered()"
              >
                <template v-slot:first>
                  <BFormSelectOption :value="null">
                    .. {{ truncate(field.label, 20) }} ..
                  </BFormSelectOption>
                </template>
              </BFormSelect>

              <!-- Multi-select: temporarily use BFormSelect instead of treeselect for compatibility -->
              <BFormSelect
                v-if="field.multi_selectable && field.selectOptions && field.selectOptions.length > 0"
                v-model="filter[field.key].content"
                class="filter-input"
                :options="normalizeSelectOptions(field.selectOptions)"
                size="sm"
                @change="removeSearch();filtered();"
              >
                <template v-slot:first>
                  <BFormSelectOption :value="null">
                    .. {{ truncate(field.label, 20) }} ..
                  </BFormSelectOption>
                </template>
              </BFormSelect>
            </td>
          </template>

          <template v-slot:cell-symbol="{ row }">
            <GeneBadge
              :symbol="row.symbol"
              :hgnc-id="row.hgnc_id"
              :link-to="'/Genes/' + row.hgnc_id"
              size="sm"
            />
          </template>

          <template v-slot:cell-SysNDD="{ row }">
            <CategoryIcon
              :category="row.SysNDD"
              size="sm"
            />
          </template>

          <template v-slot:cell-radboudumc_ID="{ row }">
            <CategoryIcon
              :category="row.radboudumc_ID"
              size="sm"
            />
          </template>

          <template v-slot:cell-gene2phenotype="{ row }">
            <CategoryIcon
              :category="row.gene2phenotype"
              size="sm"
            />
          </template>

          <template v-slot:cell-panelapp="{ row }">
            <CategoryIcon
              :category="row.panelapp"
              size="sm"
            />
          </template>

          <template v-slot:cell-sfari="{ row }">
            <CategoryIcon
              :category="row.sfari"
              size="sm"
            />
          </template>

          <template v-slot:cell-geisinger_DBD="{ row }">
            <CategoryIcon
              :category="row.geisinger_DBD"
              size="sm"
            />
          </template>

          <template v-slot:cell-omim_ndd="{ row }">
            <CategoryIcon
              :category="row.omim_ndd"
              size="sm"
            />
          </template>

          <template v-slot:cell-orphanet_id="{ row }">
            <CategoryIcon
              :category="row.orphanet_id"
              size="sm"
            />
          </template>
        </GenericTable>
      </div>
    </BCard>
  </BContainer>
</template>

<script>
// Treeselect temporarily disabled due to Vue 3 compatibility issues
// TODO: Re-enable when vue3-treeselect compatibility is fixed
// import Treeselect from '@zanmato/vue3-treeselect';
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import { useToast, useUrlParsing, useColorAndSymbols } from '@/composables';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the GenericTable component
import GenericTable from '@/components/small/GenericTable.vue';

export default {
  name: 'AnalysesCurationComparisonsTable',
  // register the GenericTable component (Treeselect temporarily disabled)
  components: { GenericTable },
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
  setup() {
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();

    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
    };
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
      pageOptions: [10, 25, 50, 200],
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
    filter: {
      handler(value) {
        this.filtered();
      },
      deep: true, // Vue 3 requires deep:true for object mutation watching
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
    // Use sortColumn for string format, sortDesc for boolean
    this.sortBy = sort_object.sortColumn;
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
        `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`,
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

      const apiUrl = `${import.meta.env.VITE_API_URL
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

      const apiUrl = `${import.meta.env.VITE_API_URL
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
      // Ensure sortBy is a string for the API URL
      const sortColumn = typeof this.sortBy === 'string' ? this.sortBy : (this.sortBy[0]?.key || 'symbol');
      this.sort = (!this.sortDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },
    /**
     * Handle sort updates from GenericTable component
     * @param {Object} ctx - Sort context with sortBy (string) and sortDesc (boolean)
     */
    handleSortUpdate(ctx) {
      this.sortBy = ctx.sortBy;
      this.sortDesc = ctx.sortDesc;
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
    /**
     * Normalize select options for BFormSelect
     * Converts simple string arrays to { value, text } format
     * @param {Array} options - Array of option values
     * @returns {Array} - Array of { value, text } objects
     */
    normalizeSelectOptions(options) {
      if (!options || !Array.isArray(options)) {
        return [];
      }
      return options.map((opt) => {
        if (typeof opt === 'string') {
          return { value: opt, text: opt };
        }
        if (typeof opt === 'object' && opt !== null) {
          return { value: opt.value || opt.id || opt, text: opt.text || opt.label || opt.name || opt };
        }
        return { value: opt, text: String(opt) };
      });
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
