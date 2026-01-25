<template>
  <div class="container-fluid">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
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
                  <h4 class="mb-1 text-start font-weight-bold">
                    Phenotype search
                    <BBadge
                      v-b-tooltip.hover.bottom
                      variant="primary"
                      :title="
                        'Loaded ' +
                          perPage +
                          '/' +
                          totalRows +
                          ' in ' +
                          executionTime
                      "
                    >
                      Associated entities: {{ totalRows }}
                    </BBadge>
                  </h4>
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
                      @click="requestSelectedExcel()"
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
                          ((filter_string === '' || filter_string === null || filter_string === 'null') ? 'not' : '') +
                          ' filtered.' +
                          ((filter_string === '' || filter_string === null || filter_string === 'null')
                            ? ''
                            : ' Click to remove all filters.')
                      "
                      :variant="(filter_string === '' || filter_string === null || filter_string === 'null') ? 'info' : 'warning'"
                      @click="removeFilters()"
                    >
                      <i class="bi bi-filter" />
                    </BButton>
                  </h5>
                </BCol>
              </BRow>
            </template>

            <BRow>
              <BCol
                class="my-1"
                sm="6"
              >
                <label
                  for="phenotype_select"
                  aria-label="Phenotype select"
                >
                  <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
                  <!-- Multi-select temporarily disabled - using single select -->
                  <!-- <treeselect
                    v-if="showFilterControls && phenotypes_options.length > 0"
                    id="phenotype_select"
                    v-model="filter.modifier_phenotype_id.content"
                    :multiple="true"
                    :options="phenotypes_options"
                    :normalizer="normalizerPhenotypes"
                    @input="filtered"
                  /> -->
                  <BFormSelect
                    v-if="showFilterControls && phenotypes_options.length > 0"
                    id="phenotype_select"
                    v-model="filter.modifier_phenotype_id.content[0]"
                    :options="normalizePhenotypesOptions(phenotypes_options)"
                    size="sm"
                    @update:model-value="filtered"
                  >
                    <template #first>
                      <BFormSelectOption :value="null">
                        Select phenotype...
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                  <BSpinner
                    v-else-if="showFilterControls && phenotypes_options.length === 0"
                    small
                    label="Loading phenotypes..."
                  />
                </label>
              </BCol>

              <BCol
                class="my-1"
                sm="2"
              >
                <BRow>
                  <BCol class="my-1">
                    <BFormCheckbox
                      v-model="checked"
                      switch
                      name="check-button"
                      @update:model-value="filtered"
                    >
                      <b>{{ switch_text[checked] }}</b>
                    </BFormCheckbox>
                  </BCol>
                </BRow>
              </BCol>

              <BCol
                class="my-1"
                sm="4"
              >
                <BContainer
                  v-if="totalRows > perPage || showPaginationControls"
                >
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
            <!-- User Interface controls -->

            <!-- Main table element -->
            <BTable
              :items="items"
              :fields="fields"
              :sort-by="sortBy"
              :busy="isBusy"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
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
                  {{ truncate(data.label.replace(/( word)|( name)/g, ""), 20) }}
                </div>
              </template>

              <!-- Filter row in table header - Bootstrap-Vue-Next uses #thead-top instead of slot="top-row" -->
              <template #thead-top>
                <tr v-if="showFilterControls">
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
                      @update:model-value="filtered()"
                    />

                    <BFormSelect
                      v-if="field.selectable"
                      v-model="filter[field.key].content"
                      :options="field.selectOptions"
                      size="sm"
                      @update:model-value="removeSearch();filtered();"
                    >
                      <template #first>
                        <BFormSelectOption :value="null">
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
                        @update:model-value="removeSearch();filtered();"
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
                  class="btn-xs"
                  variant="outline-primary"
                  @click="row.toggleDetails"
                >
                  {{ row.detailsShowing ? "Hide" : "Show" }}
                </BButton>
              </template>

              <template #row-details="row">
                <BCard>
                  <BTable
                    :items="[row.item]"
                    :fields="fields_details"
                    stacked
                    small
                  />
                </BCard>
              </template>

              <template #cell(entity_id)="data">
                <EntityBadge
                  :entity-id="data.item.entity_id"
                  :link-to="'/Entities/' + data.item.entity_id"
                  size="sm"
                />
              </template>

              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="data.item.symbol"
                  :hgnc-id="data.item.hgnc_id"
                  :link-to="'/Genes/' + data.item.hgnc_id"
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
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import the Treeselect component
// import Treeselect from '@zanmato/vue3-treeselect';
// import the Treeselect styles
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

// Import Bootstrap-Vue-Next BTable
import { BTable } from 'bootstrap-vue-next';

// Import Vue utilities
import { inject } from 'vue';

// Import composables
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
} from '@/composables';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import table components
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Module-level variables to track API calls across component remounts
// This survives when Vue Router remounts the component on URL changes
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null;

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
      filter: {
        modifier_phenotype_id: { content: ['HP:0001249'], join_char: ',', operator: 'all' },
        any: { content: null, join_char: null, operator: 'contains' },
        entity_id: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
        hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
        hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
        ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
        category: { content: null, join_char: ',', operator: 'any' },
      },
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

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
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
      const urlParam = `sort=${
        this.sort
      }&filter=${
        this.filter_string
      }&page_after=${
        this.currentItemID
      }&page_size=${
        this.perPage}`;

      navigator.clipboard.writeText(
        `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`,
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
      switch (this.checked) {
        case true:
          this.filter.modifier_phenotype_id.operator = 'any';
          break;
        case false:
          this.filter.modifier_phenotype_id.operator = 'all';
          break;
        default:
          this.filter.modifier_phenotype_id.operator = 'all';
      }

      const filter_string_loc = this.filterObjToStr(this.filter);
      if (filter_string_loc !== this.filter_string) {
        this.filter_string = this.filterObjToStr(this.filter);
      }

      // Note: updateBrowserUrl() is now called in doLoadEntitiesFromPhenotypes() AFTER API success
      // This prevents component remount during the API call
      this.requestSelected();
    },
    removeFilters() {
      this.filter = {
        modifier_phenotype_id: { content: ['HP:0001249'], join_char: ',', operator: 'all' },
        any: { content: null, join_char: null, operator: 'contains' },
        entity_id: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
        hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
        hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
        ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
        category: { content: null, join_char: ',', operator: 'any' },
      };
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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype`;
      try {
        const response = await this.axios.get(apiUrl);
        modulePhenotypesListCache = response.data;
        this.phenotypes_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        modulePhenotypesListLoading = false;
      }
    },
    normalizerPhenotypes(node) {
      return {
        id: node.phenotype_id,
        label: node.HPO_term,
      };
    },
    normalizer(node) {
      return {
        id: node,
        label: node,
      };
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

      const now = Date.now();

      // Prevent duplicate API calls using module-level tracking
      // This works across component remounts caused by router.replace()
      if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
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

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/phenotype/entities/browse?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
        moduleApiCallInProgress = false;
        // Cache response for remounted components
        moduleLastApiResponse = response.data;
        this.applyApiResponse(response.data);

        // Update URL AFTER API success to prevent component remount during API call
        this.updateBrowserUrl();

        this.isBusy = false;
      } catch (e) {
        moduleApiCallInProgress = false;
        this.makeToast(e, 'Error', 'danger');
        this.isBusy = false;
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
      }
    },
    requestSelectedExcel() {
      if (this.filter.modifier_phenotype_id.content.length > 0) {
        this.requestExcel();
      }
    },
    async requestExcel() {
      this.downloading = true;

      // compose URL param
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
      }/api/phenotype/entities/browse?${
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
    // Normalize phenotypes options for BFormSelect
    normalizePhenotypesOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => ({
        value: opt.phenotype_id,
        text: opt.HPO_term,
      }));
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
:deep(.vue-treeselect__placeholder) {
  color: #6C757D !important;
}
:deep(.vue-treeselect__control) {
  color: #6C757D !important;
}
:deep(.vue-treeselect__multi-value-label) {
  color: #000 !important;
}
</style>
