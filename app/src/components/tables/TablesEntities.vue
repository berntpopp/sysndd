<!-- components/tables/TablesEntities.vue -->
<template>
  <div class="container-fluid">
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- User Interface controls -->
          <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
            <template #header>
              <BRow>
                <BCol>
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Entities: ' + totalRows"
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

            <BRow>
              <BCol class="my-1" sm="8">
                <TableSearchInput
                  v-model="filter['any'].content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @update:model-value="filtered"
                />
              </BCol>

              <BCol class="my-1" sm="4">
                <BContainer v-if="totalRows > perPage || showPaginationControls">
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
            <GenericTable
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              @update-sort="handleSortUpdate"
            >
              <!-- Column header tooltips -->
              <template #column-header="{ data }">
                <div
                  v-b-tooltip.hover.top
                  :title="
                    getTooltipText(
                      fields.find((f) => f.label === data.label) || { key: data.column, label: data.label }
                    )
                  "
                >
                  {{ truncate(data.label.replace(/( word)|( name)/g, ''), 20) }}
                </div>
              </template>

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
                    @update:model-value="filtered()"
                  />

                  <BFormSelect
                    v-if="field.selectable && field.selectOptions && field.selectOptions.length > 0"
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
                  <BSpinner
                    v-else-if="
                      field.selectable && (!field.selectOptions || field.selectOptions.length === 0)
                    "
                    small
                    label="Loading..."
                  />

                  <!-- Multi-select: temporarily use BFormSelect instead of treeselect for compatibility -->
                  <BFormSelect
                    v-if="
                      field.multi_selectable &&
                      field.selectOptions &&
                      field.selectOptions.length > 0
                    "
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
                  <BSpinner
                    v-else-if="
                      field.multi_selectable &&
                      (!field.selectOptions || field.selectOptions.length === 0)
                    "
                    small
                    label="Loading..."
                  />
                </td>
              </template>
              <!-- Custom filter fields slot -->

              <template #cell-entity_id="{ row }">
                <EntityBadge
                  :entity-id="row.entity_id"
                  :link-to="'/Entities/' + row.entity_id"
                  size="sm"
                />
              </template>

              <template #cell-symbol="{ row }">
                <GeneBadge
                  :symbol="row.symbol"
                  :hgnc-id="row.hgnc_id"
                  :link-to="'/Genes/' + row.hgnc_id"
                  size="sm"
                />
              </template>

              <template #cell-disease_ontology_name="{ row }">
                <DiseaseBadge
                  :name="row.disease_ontology_name"
                  :ontology-id="row.disease_ontology_id_version"
                  :link-to="'/Ontology/' + row.disease_ontology_id_version.replace(/_.+/g, '')"
                  :max-length="35"
                  size="sm"
                />
              </template>

              <!-- Custom slot for the 'hpo_mode_of_inheritance_term_name' column -->
              <template #cell-hpo_mode_of_inheritance_term_name="{ row }">
                <InheritanceBadge
                  :full-name="row.hpo_mode_of_inheritance_term_name"
                  :hpo-term="row.hpo_mode_of_inheritance_term"
                  size="sm"
                />
              </template>

              <!-- Custom slot for the 'ndd_phenotype_word' column -->
              <template #cell-ndd_phenotype_word="{ row }">
                <span v-b-tooltip.hover.left :title="ndd_icon_text[row.ndd_phenotype_word]">
                  <NddIcon :status="row.ndd_phenotype_word" size="sm" :show-title="false" />
                </span>
              </template>

              <!-- Custom slot for the 'category' column -->
              <template #cell-category="{ row }">
                <span v-b-tooltip.hover.left :title="row.category">
                  <CategoryIcon :category="row.category" size="sm" :show-title="false" />
                </span>
              </template>
              <!-- Custom slot for the 'category' column -->
            </GenericTable>
            <!-- Main table element -->
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
/**
 * TablesEntities Component
 *
 * This component is responsible for displaying and managing a table of entities.
 * It includes features such as a searchable input, pagination controls, and downloadable links.
 *
 * @component
 * @example
 * <TablesEntities
 *  showFilterControls={true}
 *  showPaginationControls={true}
 *  headerLabel="Entities table"
 *  sortInput="+entity_id"
 *  filterInput={null}
 *  fieldsInput={null}
 *  pageAfterInput="0"
 *  pageSizeInput=10
 *  fspecInput="entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details"
 * />
 */

// Import Vue utilities
import { ref, inject } from 'vue';

// Import composables
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  useTableMethods,
  useColumnTooltip,
} from '@/composables';

// Import the Table components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Module-level variables to track API calls across component remounts
// This survives when Vue Router remounts the component on URL changes
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null; // Cache last API response for remounted components

export default {
  name: 'TablesEntities',
  components: {
    // Components used within TablesEntities
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableHeaderLabel,
    TableSearchInput,
    GenericTable,
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'entity',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Entities table' },
    sortInput: { type: String, default: '+entity_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details',
    },
    disableUrlSync: { type: Boolean, default: false },
  },
  setup(props) {
    // Independent composables
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();
    const { getTooltipText } = useColumnTooltip();

    // Table state composable
    const tableData = useTableData({
      pageSizeInput: props.pageSizeInput,
      sortInput: props.sortInput,
      pageAfterInput: props.pageAfterInput,
    });

    // Component-specific filter
    const filter = ref({
      any: { content: null, join_char: null, operator: 'contains' },
      entity_id: { content: null, join_char: null, operator: 'contains' },
      symbol: { content: null, join_char: null, operator: 'contains' },
      disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
      disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
      hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
      hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
      ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
      category: { content: null, join_char: ',', operator: 'any' },
      entities_count: { content: null, join_char: ',', operator: 'any' },
    });

    // Inject axios
    const axios = inject('axios');

    // Table methods composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      apiEndpoint: props.apiEndpoint,
      axios,
    });

    // Destructure to exclude functions we override in methods

    const {
      filtered: _filtered,
      handlePageChange: _handlePageChange,
      handlePerPageChange: _handlePerPageChange,
      handleSortByOrDescChange: _handleSortByOrDescChange,
      removeFilters: _removeFilters,
      removeSearch: _removeSearch,
      ...restTableMethods
    } = tableMethods;

    // Return all needed properties
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
      ...tableData,
      ...restTableMethods,
      filter,
      axios,
      getTooltipText,
    };
  },
  data() {
    return {
      // Flag to prevent watchers from triggering during initialization
      isInitializing: true,
      // Debounce timer for loadData to prevent duplicate calls
      loadDataDebounceTimer: null,
      // Pagination state not in useTableData
      totalPages: 0,
      // ... data properties with a brief description for each
      fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'symbol',
          label: 'Symbol',
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
        { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' },
      ],
      infoModal: {
        id: 'info-modal',
        title: '',
        content: '',
      },
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
    // Only trigger if sort actually changed to prevent resetting currentItemID during pagination
    sortBy: {
      handler(newVal) {
        if (this.isInitializing) return;
        // Build new sort string from sortBy array
        const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'entity_id';
        const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'asc';
        const newSortString = (newSortOrder === 'desc' ? '-' : '+') + newSortColumn;
        // Only trigger if sort actually changed - prevents resetting currentItemID during pagination
        if (newSortString !== this.sort) {
          this.handleSortByOrDescChange();
        }
      },
      deep: true,
    },
  },
  created() {
    // Lifecycle hooks
  },
  mounted() {
    // Transform input sort string to Bootstrap-Vue-Next array format
    // sortStringToVariables now returns { sortBy: [{ key: 'column', order: 'asc'|'desc' }] }
    if (this.sortInput) {
      const sort_object = this.sortStringToVariables(this.sortInput);
      this.sortBy = sort_object.sortBy;
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
    // Update browser URL with current table state
    // Uses history.replaceState instead of router.replace to prevent component remount
    updateBrowserUrl() {
      // Don't update URL during initialization - preserves URL params from navigation
      if (this.isInitializing) return;
      // When embedded (e.g. GeneView), skip URL updates to keep URL clean
      if (this.disableUrlSync) return;

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
    // Override filtered to call loadData (URL is updated AFTER API success to prevent remount)
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);

      if (filter_string_loc !== this.filter_string) {
        this.filter_string = filter_string_loc;
      }

      // Note: updateBrowserUrl() is now called in doLoadData() AFTER API success
      // This prevents component remount during the API call
      this.loadData();
    },
    // Override handlePageChange to properly update currentItemID and call loadData
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
    // Override handlePerPageChange to reset pagination and reload
    handlePerPageChange(newPerPage) {
      this.perPage = parseInt(newPerPage, 10);
      this.currentItemID = 0;
      this.filtered();
    },
    // Override handleSortByOrDescChange to call the component's filtered method
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      // Extract sort column and order from array-based sortBy (Bootstrap-Vue-Next format)
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : '';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';
      const isDesc = sortOrder === 'desc';
      // Build sort string for API: +column for asc, -column for desc
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },
    // Override removeFilters to use component's filter and filtered method
    removeFilters() {
      Object.keys(this.filter).forEach((key) => {
        if (
          this.filter[key] &&
          typeof this.filter[key] === 'object' &&
          'content' in this.filter[key]
        ) {
          this.filter[key].content = null;
        }
      });
      this.filtered();
    },
    // Override removeSearch to use component's filter and filtered method
    removeSearch() {
      if (this.filter.any) {
        this.filter.any.content = null;
      }
      this.filtered();
    },
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
    async doLoadData() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${
        this.currentItemID
      }&page_size=${this.perPage}`;

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

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/entity/?${urlParam}`;

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
      this.fields = data.meta[0].fspec;

      // Apply short label overrides for mobile-friendly stacked table headers
      const shortLabels = {
        entity_id: 'Entity',
        disease_ontology_name: 'Disease',
        hpo_mode_of_inheritance_term_name: 'Inheritance',
        ndd_phenotype_word: 'NDD',
      };
      this.fields = this.fields.map((field) => {
        if (shortLabels[field.key]) {
          return { ...field, label: shortLabels[field.key] };
        }
        return field;
      });

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
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
  color: #6c757d !important;
}
:deep(.vue-treeselect__control) {
  color: #6c757d !important;
}

/* Card styling improvements */
:deep(.card) {
  border-radius: 0.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}

:deep(.card-header) {
  background-color: #f8f9fa;
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}
</style>
