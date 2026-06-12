<template>
  <div class="container-fluid py-2">
    <TableShell
      title="Phenotype search"
      :meta="`Associated entities: ${totalRows}`"
      :description="`Loaded ${perPage}/${totalRows} in ${executionTime}`"
      :loading="loading"
    >
      <template v-if="!loading && showFilterControls" #actions>
        <BButton
          v-b-tooltip.hover.bottom
          class="me-1"
          size="sm"
          title="Download data as Excel file."
          @click="requestSelectedExcel()"
        >
          <i class="bi bi-table mx-1" />
          <i v-if="!downloading" class="bi bi-download" />
          <BSpinner v-if="downloading" small />
          .xlsx
        </BButton>

        <BButton
          v-b-tooltip.hover.bottom
          class="me-1"
          size="sm"
          title="Copy link to this page."
          variant="success"
          @click="copyLinkToClipboard()"
        >
          <i class="bi bi-link" />
        </BButton>

        <BButton
          v-b-tooltip.hover.bottom
          size="sm"
          class="me-1"
          :title="
            'The table is ' +
            (filter_string === '' || filter_string === null || filter_string === 'null'
              ? 'not'
              : '') +
            ' filtered.' +
            (filter_string === '' || filter_string === null || filter_string === 'null'
              ? ''
              : ' Click to remove all filters.')
          "
          :variant="
            filter_string === '' || filter_string === null || filter_string === 'null'
              ? 'info'
              : 'warning'
          "
          @click="removeFilters()"
        >
          <i class="bi bi-filter" />
        </BButton>
      </template>

      <template v-if="!loading" #toolbar>
        <BRow class="align-items-center gx-2">
          <BCol class="my-1" sm="6">
            <PhenotypeFilterToolbar
              v-if="showFilterControls"
              :phenotype-options="phenotypes_options"
              :selected-ids="filter.modifier_phenotype_id.content"
              @toggle="togglePhenotype"
              @remove="removePhenotype"
              @clear-all="clearAllPhenotypes"
            />
          </BCol>

          <BCol class="my-1 d-flex align-items-center" sm="2">
            <div class="logic-toggle">
              <button
                type="button"
                class="logic-btn"
                :class="{ active: !checked }"
                @click="setLogicMode(false)"
              >
                AND
              </button>
              <button
                type="button"
                class="logic-btn"
                :class="{ active: checked }"
                @click="setLogicMode(true)"
              >
                OR
              </button>
            </div>
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
        <TableLoadingState label="Loading phenotype-associated entities" />
      </template>

      <div class="d-none d-md-block">
        <BTable
          :items="items"
          :fields="fields"
          :sort-by="sortBy"
          :busy="isBusy"
          :stacked="false"
          head-variant="light"
          show-empty
          small
          fixed
          hover
          class="public-data-table"
          sort-icon-left
          no-local-sorting
          @update:sort-by="handleSortByUpdate"
        >
          <!-- custom formatted header -->
          <template #head()="data">
            <div
              v-b-tooltip.hover.top
              :data="data"
              data-html="true"
              :title="
                data.label +
                ' (unique filtered/total values: ' +
                fields
                  .filter((item) => item.label === data.label)
                  .map((item) => {
                    return item.count_filtered;
                  })[0] +
                '/' +
                fields
                  .filter((item) => item.label === data.label)
                  .map((item) => {
                    return item.count;
                  })[0] +
                ')'
              "
            >
              {{ truncate(data.label.replace(/( word)|( name)/g, ''), 20) }}
            </div>
          </template>

          <!-- Filter row in table header - Bootstrap-Vue-Next uses #thead-top instead of slot="top-row" -->
          <template #thead-top>
            <tr v-if="showFilterControls">
              <td v-for="field in fields" :key="field.key">
                <BFormInput
                  v-if="field.filterable"
                  v-model="filter[field.key].content"
                  :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
                  debounce="500"
                  type="search"
                  autocomplete="off"
                  @click="removeSearch()"
                  @update:model-value="filtered()"
                />

                <BFormSelect
                  v-if="field.selectable"
                  v-model="filter[field.key].content"
                  :options="field.selectOptions"
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

                <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
                <label
                  v-if="
                    field.multi_selectable && field.selectOptions && field.selectOptions.length > 0
                  "
                  :for="'select_' + field.key"
                  :aria-label="field.label"
                >
                  <BFormSelect
                    :id="'select_' + field.key"
                    v-model="filter[field.key].content"
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
                </label>
              </td>
            </tr>
          </template>

          <template #cell(details)="row">
            <BButton
              class="btn-xs fw-semibold"
              variant="outline-primary"
              :aria-label="`${row.expansionShowing ? 'Hide' : 'Show'} details for entity ${
                row.item.entity_id
              }`"
              @click="row.toggleExpansion"
            >
              {{ row.expansionShowing ? 'Hide' : 'Show' }}
            </BButton>
          </template>

          <template #row-expansion="row">
            <BCard>
              <BTable :items="[row.item]" :fields="fields_details" stacked small />
            </BCard>
          </template>

          <template #cell(entity_id)="data">
            <EntityBadge
              :entity-id="data.item.entity_id"
              :link-to="withCurrentReturnTo('/Entities/' + data.item.entity_id)"
              size="sm"
            />
          </template>

          <template #cell(symbol)="data">
            <GeneBadge
              :symbol="data.item.symbol"
              :hgnc-id="data.item.hgnc_id"
              :link-to="withCurrentReturnTo('/Genes/' + data.item.hgnc_id)"
              size="sm"
            />
          </template>

          <template #cell(disease_ontology_name)="data">
            <DiseaseBadge
              :name="data.item.disease_ontology_name"
              :ontology-id="data.item.disease_ontology_id_version"
              :link-to="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"
              :max-length="35"
              size="sm"
            />
          </template>

          <template #cell(hpo_mode_of_inheritance_term_name)="data">
            <InheritanceBadge
              :full-name="data.item.hpo_mode_of_inheritance_term_name"
              :hpo-term="data.item.hpo_mode_of_inheritance_term"
              size="sm"
            />
          </template>

          <template #cell(ndd_phenotype_word)="data">
            <span v-b-tooltip.hover.left :title="ndd_icon_text[data.item.ndd_phenotype_word]">
              <NddIcon :status="data.item.ndd_phenotype_word" size="sm" :show-title="false" />
            </span>
          </template>

          <template #cell(category)="data">
            <span v-b-tooltip.hover.left :title="data.item.category">
              <CategoryIcon :category="data.item.category" size="sm" :show-title="false" />
            </span>
          </template>
        </BTable>
      </div>

      <div class="d-md-none">
        <PhenotypesMobileRows :items="items" />
      </div>
    </TableShell>
  </div>
</template>

<script>
// Import Bootstrap-Vue-Next BTable
import { BTable } from 'bootstrap-vue-next';

// Import Vue utilities
import { inject } from 'vue';

// Import composables
import { useToast, useUrlParsing, useColorAndSymbols, useText } from '@/composables';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import { withReturnTo } from '@/utils/returnNavigation';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import table components
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableShell from '@/components/table/TableShell.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import PhenotypesMobileRows from '@/components/tables/PhenotypesMobileRows.vue';
import PhenotypeFilterToolbar from '@/components/tables/PhenotypeFilterToolbar.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';
import { normalizeSelectOptions } from '@/utils/selectOptions';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Typed API clients
import { browsePhenotypeEntities, browsePhenotypeEntitiesXlsx } from '@/api/phenotype';
import { listPhenotypes } from '@/api/list';
import { createTableRequestCoordinator } from '@/utils/tableRequestCoordinator';
import { applyPhenotypeLogicMode, createDefaultPhenotypeFilter } from './phenotypeTableFilters';

const phenotypeEntitiesRequestCoordinator = createTableRequestCoordinator();

// Module-level cache for phenotypes list (loaded once, reused across remounts)
let modulePhenotypesListCache = null;
let modulePhenotypesListLoading = false;

export default {
  name: 'TablesPhenotypes',
  components: {
    BTable,
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    TablePaginationControls,
    TableShell,
    TableLoadingState,
    PhenotypesMobileRows,
    PhenotypeFilterToolbar,
  },
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Phenotype table' },
    sortInput: { type: String, default: 'entity_id' },
    filterInput: { type: String, default: 'all(modifier_phenotype_id,HP:0001249)' },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,modifier_phenotype_id',
    },
  },
  setup() {
    // Independent composables
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    // Inject axios
    const axios = inject('axios');

    // Return all needed properties
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      axios,
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
      switch_text: { true: 'OR', false: 'AND' },
      phenotypes_options: [],
      items: [],
      fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'symbol',
          label: 'Gene Symbol',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'category',
          label: 'Category',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'details',
          label: 'Details',
        },
      ],
      fields_details: [
        { key: 'hgnc_id', label: 'HGNC ID', class: 'text-start' },
        {
          key: 'disease_ontology_id_version',
          label: 'Ontology ID version',
          class: 'text-start',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease ontology name',
          class: 'text-start',
        },
        { key: 'entry_date', label: 'Entry date', class: 'text-start' },
        { key: 'last_update', label: 'Last updated', class: 'text-start' },
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
      // Bootstrap-Vue-Next uses array-based sortBy
      sortBy: [{ key: 'entity_id', order: 'desc' }],
      sort: this.sortInput,
      filter: createDefaultPhenotypeFilter(),
      filter_string: null,
      filterOn: [],
      checked: false,
      downloading: false,
      loading: true,
      isBusy: true,
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
    perPage() {
      if (this.isInitializing) return;
      this.handlePerPageChange();
    },
  },
  created() {
    // load phenotypes list
    this.loadPhenotypesList();
  },
  mounted() {
    // Transform input sort string to Bootstrap-Vue-Next array format
    if (this.sortInput) {
      const sort_object = this.sortStringToVariables(this.sortInput);
      this.sortBy = sort_object.sortBy;
      this.sort = this.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (this.pageAfterInput && this.pageAfterInput !== '0' && this.pageAfterInput !== '') {
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
      this.requestSelected();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });
  },
  methods: {
    withCurrentReturnTo(path) {
      return withReturnTo(path);
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
      // compose URL param
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${
        this.currentItemID
      }&page_size=${this.perPage}`;

      navigator.clipboard.writeText(
        `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
      );
    },
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      // Extract sort column and order from array-based sortBy
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : 'entity_id';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'desc';
      this.sort = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
      this.filtered();
    },
    /**
     * Handle sort-by updates from Bootstrap-Vue-Next BTable.
     * @param {Array} newSortBy - Array of sort objects: [{ key: 'column', order: 'asc'|'desc' }]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
    handlePerPageChange() {
      this.currentItemID = 0;
      this.filtered();
    },
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
    filtered() {
      this.filter = applyPhenotypeLogicMode(this.filter, this.checked === true);

      const filter_string_loc = this.filterObjToStr(this.filter);
      if (filter_string_loc !== this.filter_string) {
        this.filter_string = this.filterObjToStr(this.filter);
      }

      // Note: updateBrowserUrl() is now called in doLoadEntitiesFromPhenotypes() AFTER API success
      // This prevents component remount during the API call
      this.requestSelected();
    },
    removeFilters() {
      this.filter = createDefaultPhenotypeFilter();
    },
    removeSearch() {
      this.filter.any.content = null;

      if (this.filter.any.content !== null) {
        this.filter.any.content = null;
      }
    },
    async loadPhenotypesList() {
      // Use cached phenotypes list if available (prevents reload on component remount)
      if (modulePhenotypesListCache) {
        this.phenotypes_options = modulePhenotypesListCache;
        return;
      }

      // Prevent duplicate loading if already in progress
      if (modulePhenotypesListLoading) {
        return;
      }

      modulePhenotypesListLoading = true;
      try {
        const response = await listPhenotypes();
        // The typed `listPhenotypes()` helper always returns the
        // `{ links, meta, data }` envelope per W3 spec; consume that
        // shape directly so any future contract drift fails the build
        // instead of being papered over by a `|| response` fallback.
        const phenotypeData = response.data;
        modulePhenotypesListCache = phenotypeData;
        this.phenotypes_options = phenotypeData;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        modulePhenotypesListLoading = false;
      }
    },
    /**
     * Toggle phenotype selection.
     * @param {string} phenotypeId - HPO ID to toggle
     */
    togglePhenotype(phenotypeId) {
      const index = this.filter.modifier_phenotype_id.content.indexOf(phenotypeId);
      if (index === -1) {
        // Add phenotype
        this.filter.modifier_phenotype_id.content.push(phenotypeId);
      } else {
        // Remove phenotype
        this.filter.modifier_phenotype_id.content.splice(index, 1);
      }
      this.filtered();
    },
    /**
     * Clear all selected phenotypes.
     */
    clearAllPhenotypes() {
      this.filter.modifier_phenotype_id.content = [];
      this.filtered();
    },
    /**
     * Set the logic mode (AND/OR) for phenotype filtering.
     * @param {boolean} isOr - True for OR mode, false for AND mode
     */
    setLogicMode(isOr) {
      this.checked = isOr;
      this.filtered();
    },
    /**
     * Remove a phenotype from selection.
     * @param {string} phenotypeId - HPO ID to remove
     */
    removePhenotype(phenotypeId) {
      const index = this.filter.modifier_phenotype_id.content.indexOf(phenotypeId);
      if (index !== -1) {
        this.filter.modifier_phenotype_id.content.splice(index, 1);
        this.filtered();
      }
    },
    loadEntitiesFromPhenotypes() {
      // Debounce to prevent duplicate calls from multiple triggers
      if (this.loadDataDebounceTimer) {
        clearTimeout(this.loadDataDebounceTimer);
      }
      this.loadDataDebounceTimer = setTimeout(() => {
        this.loadDataDebounceTimer = null;
        this.doLoadEntitiesFromPhenotypes();
      }, 50);
    },
    async doLoadEntitiesFromPhenotypes() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const currentUrlParam = () =>
        `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      this.isBusy = true;

      const result = await phenotypeEntitiesRequestCoordinator.request({
        params: urlParam,
        fetcher: () =>
          browsePhenotypeEntities({
            sort: this.sort,
            filter: this.filter_string,
            page_after: this.currentItemID,
            page_size: String(this.perPage),
          }),
        apply: (data, source) => {
          this.applyApiResponse(data);
          if (source === 'network') {
            // Update URL AFTER API success to prevent component remount during API call
            this.updateBrowserUrl();
          }
        },
        onError: (e) => {
          this.makeToast(e, 'Error', 'danger');
        },
        isCurrent: (params) => currentUrlParam() === params,
      });

      if (result.handled) {
        this.isBusy = false;
        this.loading = false;
      }
    },
    /**
     * Apply API response data to component state.
     * Extracted to allow reuse when skipping duplicate API calls.
     * @param {Object} data - API response data
     */
    applyApiResponse(data) {
      this.fields = data.meta[0].fspec;
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

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    },
    requestSelected() {
      if (this.filter.modifier_phenotype_id.content.length > 0) {
        this.loadEntitiesFromPhenotypes();
      } else {
        this.items = [];
        this.totalRows = 0;
        this.isBusy = false;
        this.loading = false;
      }
    },
    requestSelectedExcel() {
      if (this.filter.modifier_phenotype_id.content.length > 0) {
        this.requestExcel();
      }
    },
    async requestExcel() {
      this.downloading = true;

      try {
        const blob = await browsePhenotypeEntitiesXlsx({
          sort: this.sort,
          filter: this.filter_string,
          page_after: 0,
          page_size: 'all',
        });

        // browsePhenotypeEntitiesXlsx() already returns a Blob (typed
        // `Promise<Blob>` in src/api/phenotype.ts via the apiClient.raw
        // call with responseType: 'blob'). Wrapping it in `new Blob([blob])`
        // re-allocates the entire payload into a second Blob — for an
        // "all rows" XLSX export of the entity catalogue that's hundreds
        // of MB of needless copy. Pass the original Blob straight through.
        const fileURL = window.URL.createObjectURL(blob);
        const fileLink = document.createElement('a');

        fileLink.href = fileURL;
        fileLink.setAttribute('download', 'phenotype_search.xlsx');
        document.body.appendChild(fileLink);

        fileLink.click();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.downloading = false;
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

<style scoped src="./TablesPhenotypes.css"></style>
