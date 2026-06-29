<!-- src/components/analyses/AnalysesCurationComparisonsTable.vue -->
<template>
  <TableShell
    title="Curation effort comparisons"
    description="Comparing the presence of a gene in different curation efforts for NDDs."
    :meta="'Genes: ' + totalRows"
    :loading="loadingTable"
  >
    <template #title-actions>
      <InlineHelpBadge
        id="popover-badge-help-comparisons"
        aria-label="Show curation comparison table help"
      />

      <BPopover target="popover-badge-help-comparisons" variant="info" triggers="focus">
        <template #title> Comparisons selection [last update 2023-04-13] </template>
        The NDD databases and lists for the comparison with SysNDD are:
        <br />
        <strong>1) radboudumc ID,</strong> downloaded and normalized from
        https://order.radboudumc.nl/en/LabProduct/Pdf/30240, <br />
        <strong>2) gene2phenotype ID</strong> downloaded and normalized from
        https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz,
        <br />
        <strong>3) panelapp ID</strong> downloaded and normalized from
        https://panelapp.genomicsengland.co.uk/panels/285/download/01234/,
        <br />
        <strong>4) sfari</strong> downloaded and normalized from
        https://gene.sfari.org//wp-content/themes/sfari-gene/utilities/download-csv.php?api-endpoint=genes,
        <br />
        <strong>5) geisinger DBD</strong> downloaded and normalized from
        https://dbd.geisingeradmi.org/downloads/DBD-Genes-Full-Data.csv,
        <br />
        <strong>6) orphanet ID</strong> downloaded and normalized from
        https://id-genes.orphanet.app/es/index/sysid_index_1, <br />
        <strong>7) OMIM NDD</strong> filtered OMIM for the HPO term "Neurodevelopmental abnormality"
        (HP:0012759) using the pre-propagated phenotype_to_genes.txt
        (http://purl.obolibrary.org/obo/hp/hpoa/phenotype_to_genes.txt) and genemap2 (genemap2.txt
        from OMIM, requires download key),
        <br />
      </BPopover>
    </template>

    <template #actions>
      <div
        v-if="showFilterControls"
        class="comparison-actions d-flex align-items-center justify-content-end gap-2"
      >
        <BFormCheckbox
          v-model="definitiveOnly"
          v-b-tooltip.hover.bottom
          switch
          size="sm"
          class="definitive-toggle me-2"
          title="Show only Definitive entries for each source"
        >
          <span class="small fw-semibold">Definitive Only</span>
        </BFormCheckbox>

        <TableDownloadLinkCopyButtons
          :downloading="downloading"
          :remove-filters-title="removeFiltersButtonTitle"
          :remove-filters-variant="removeFiltersButtonVariant"
          @request-excel="requestExcel"
          @copy-link="copyLinkToClipboard"
          @remove-filters="removeFilters"
        />
      </div>
    </template>

    <template #toolbar>
      <BRow v-if="!loadingTable">
        <BCol class="my-1" sm="6">
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
              @update:model-value="filtered()"
            />
          </BFormGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <TablePaginationControls
            v-if="totalRows > perPage || showPaginationControls"
            :total-rows="totalRows"
            :initial-per-page="perPage"
            :page-options="pageOptions"
            :current-page="currentPage"
            @page-change="handlePageChange"
            @per-page-change="handlePerPageChange"
          />
        </BCol>
      </BRow>
    </template>

    <template #loading>
      <TableLoadingState label="Loading curation comparison table" />
    </template>

    <div class="position-relative">
      <div class="d-none d-md-block">
        <GenericTable
          :items="items"
          :fields="fields"
          :current-page="currentPage"
          :is-busy="isBusy"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          :stacked-mode="false"
          @update-sort="handleSortUpdate"
        >
          <!-- Column header tooltips -->
          <template #column-header="{ data }">
            <div
              v-b-tooltip.hover.top
              :title="
                getTooltipText(
                  fields.find((f) => f.label === data.label) || {
                    key: data.column,
                    label: data.label,
                  }
                )
              "
              :aria-label="data.label"
            >
              {{ truncate(data.label, 28) }}
            </div>
          </template>

          <template #filter-controls>
            <td v-for="field in fields" :key="field.key" role="presentation">
              <BFormInput
                v-if="field.filterable"
                v-model="filter[field.key].content"
                class="filter-input"
                :placeholder="'Filter ' + truncate(field.label, 20)"
                :aria-label="`Filter by ${field.label}`"
                debounce="500"
                type="search"
                autocomplete="off"
                @click="removeSearch()"
                @update:model-value="filtered()"
              />

              <BFormSelect
                v-if="field.selectable && field.selectOptions && field.selectOptions.length > 0"
                v-model="filter[field.key].content"
                class="filter-input"
                :aria-label="`Filter by ${field.label}`"
                :options="normalizeSelectOptions(field.selectOptions)"
                size="sm"
                @update:model-value="
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

              <!-- Multi-select: temporarily use BFormSelect instead of treeselect for compatibility -->
              <BFormSelect
                v-if="
                  field.multi_selectable && field.selectOptions && field.selectOptions.length > 0
                "
                v-model="filter[field.key].content"
                class="filter-input"
                :aria-label="`Filter by ${field.label}`"
                :options="normalizeSelectOptions(field.selectOptions)"
                size="sm"
                @update:model-value="
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
            </td>
          </template>

          <template #cell-symbol="{ row }">
            <GeneBadge
              :symbol="row.symbol"
              :hgnc-id="row.hgnc_id"
              :link-to="'/Genes/' + row.hgnc_id"
              size="sm"
            />
          </template>

          <template #cell-SysNDD="{ row }">
            <CategoryIcon :category="row.SysNDD" size="sm" />
          </template>

          <template #cell-radboudumc_ID="{ row }">
            <CategoryIcon :category="row.radboudumc_ID" size="sm" />
          </template>

          <template #cell-gene2phenotype="{ row }">
            <CategoryIcon :category="row.gene2phenotype" size="sm" />
          </template>

          <template #cell-panelapp="{ row }">
            <CategoryIcon :category="row.panelapp" size="sm" />
          </template>

          <template #cell-sfari="{ row }">
            <CategoryIcon :category="row.sfari" size="sm" />
          </template>

          <template #cell-geisinger_DBD="{ row }">
            <CategoryIcon :category="row.geisinger_DBD" size="sm" />
          </template>

          <template #cell-orphanet_id="{ row }">
            <CategoryIcon :category="row.orphanet_id" size="sm" />
          </template>

          <template #cell-omim_ndd="{ row }">
            <CategoryIcon :category="row.omim_ndd" size="sm" />
          </template>
        </GenericTable>
      </div>

      <div class="d-md-none">
        <CurationComparisonMobileRows :items="items" />
      </div>
    </div>
  </TableShell>
</template>

<script>
// Treeselect temporarily disabled due to Vue 3 compatibility issues
// TODO: Re-enable when vue3-treeselect compatibility is fixed
// import Treeselect from '@zanmato/vue3-treeselect';
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import { useToast, useUrlParsing, useColorAndSymbols, useColumnTooltip } from '@/composables';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the GenericTable component
import GenericTable from '@/components/small/GenericTable.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import TableShell from '@/components/table/TableShell.vue';
import CurationComparisonMobileRows from '@/components/analyses/CurationComparisonMobileRows.vue';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';

// Typed API client (W5)
import { browseComparisons, browseComparisonsXlsx } from '@/api/comparisons';

import {
  createComparisonFields,
  createComparisonFilter,
  withCuratedComparisonLabels,
  COMPARISON_SOURCE_COLUMNS,
} from './curationComparisonsTableConfig';

export default {
  name: 'AnalysesCurationComparisonsTable',
  // register the GenericTable component (Treeselect temporarily disabled)
  components: {
    GenericTable,
    InlineHelpBadge,
    TableDownloadLinkCopyButtons,
    TablePaginationControls,
    TableLoadingState,
    TableShell,
    CurationComparisonMobileRows,
    CategoryIcon,
    GeneBadge,
  },
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    sortInput: { type: String, default: '+symbol' },
    filterInput: { type: String, default: 'filter=' },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'symbol,SysNDD,gene2phenotype,panelapp,radboudumc_ID,sfari,geisinger_DBD,orphanet_id,omim_ndd',
    },
  },
  setup() {
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();
    const { getTooltipText } = useColumnTooltip();

    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      getTooltipText,
    };
  },
  data() {
    return {
      items: [],
      fields: createComparisonFields(),
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
      filter: createComparisonFilter(),
      filter_string: '',
      filterOn: [],
      loadingTable: true,
      isBusy: true,
      downloading: false,
      definitiveOnly: false,
      // Monotonic id of the latest load; a response whose id is stale is
      // dropped so an earlier request can't overwrite a newer filter (#467).
      loadSerial: 0,
    };
  },
  computed: {
    removeFiltersButtonTitle() {
      return (
        'The table is ' +
        (this.filter_string === '' ? 'not' : '') +
        ' filtered.' +
        (this.filter_string === '' ? '' : ' Click to remove all filters.')
      );
    },
    removeFiltersButtonVariant() {
      return this.filter_string === '' ? 'info' : 'warning';
    },
  },
  watch: {
    filter: {
      handler(_value) {
        this.filtered();
      },
      deep: true, // Vue 3 requires deep:true for object mutation watching
    },
    definitiveOnly(newValue) {
      // Set all source column filters to "Definitive" when enabled, or null when disabled
      // (source columns exclude `symbol`, which is a text search input)
      COMPARISON_SOURCE_COLUMNS.forEach((col) => {
        this.filter[col].content = newValue ? 'Definitive' : null;
      });

      // Reset to first page - the filter watcher will trigger loadTableData via filtered()
      this.currentItemID = '0';
    },
    sortBy() {
      this.handleSortByOrDescChange();
    },
    sortDesc() {
      this.handleSortByOrDescChange();
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
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${
        this.currentItemID
      }&page_size=${this.perPage}`;
      navigator.clipboard.writeText(`${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`);
    },
    async loadTableData() {
      const serial = (this.loadSerial += 1);
      this.isBusy = true;

      try {
        const data = await browseComparisons({
          sort: this.sort,
          filter: this.filter_string,
          page_after: String(this.currentItemID),
          page_size: String(this.perPage),
          definitive_only: String(this.definitiveOnly),
        });
        // Drop a stale response superseded by a newer load (#467).
        if (serial !== this.loadSerial) return;
        this.items = data.data;

        this.totalRows = data.meta[0].totalItems;
        this.$nextTick(() => {
          this.currentPage = data.meta[0].currentPage;
        });
        this.totalPages = data.meta[0].totalPages;
        this.prevItemID = data.meta[0].prevItemID;
        this.currentItemID = data.meta[0].currentItemID;
        this.nextItemID = data.meta[0].nextItemID;
        this.lastItemID = data.meta[0].lastItemID;
        this.executionTime = data.meta[0].executionTime;
        // Keep the backend count facets but re-apply curated source labels
        // ("Sysndd" -> "SysNDD", "Panelapp" -> "PanelApp", ...).
        this.fields = withCuratedComparisonLabels(data.meta[0].fspec);

        this.isBusy = false;
      } catch (e) {
        if (serial === this.loadSerial) this.makeToast(e, 'Error', 'danger');
      }
    },
    async requestExcel() {
      this.downloading = true;

      try {
        const blob = await browseComparisonsXlsx({
          sort: this.sort,
          filter: this.filter_string,
          page_after: '0',
          page_size: 'all',
        });

        const fileURL = window.URL.createObjectURL(blob);
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
      const sortColumn =
        typeof this.sortBy === 'string' ? this.sortBy : this.sortBy[0]?.key || 'symbol';
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
    handlePerPageChange(newPerPage) {
      if (newPerPage !== undefined) {
        this.perPage = typeof newPerPage === 'string' ? parseInt(newPerPage, 10) : newPerPage;
      }
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
      this.filter = createComparisonFilter();
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
          return {
            value: opt.value || opt.id || opt,
            text: opt.text || opt.label || opt.name || opt,
          };
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

/* Definitive toggle styles */
.definitive-toggle {
  margin-bottom: 0;
}

.definitive-toggle :deep(.form-check-input) {
  cursor: pointer;
}

.definitive-toggle :deep(.form-check-input:checked) {
  background-color: #198754;
  border-color: #198754;
}
</style>
