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

            <BRow class="align-items-center gx-2">
              <BCol
                class="my-1"
                sm="6"
              >
                <!-- Phenotype Multi-Select - Unified Input Style -->
                <div
                  v-if="showFilterControls"
                  class="phenotype-select-container"
                >
                  <div
                    class="phenotype-select-control"
                    @click="openPhenotypeDropdown"
                  >
                    <!-- Selected phenotypes as inline tags -->
                    <div class="phenotype-tags">
                      <span
                        v-for="phenotypeId in filter.modifier_phenotype_id.content"
                        :key="phenotypeId"
                        class="phenotype-tag"
                      >
                        {{ getPhenotypeName(phenotypeId) }}
                        <i
                          class="bi bi-x tag-remove"
                          @click.stop="removePhenotype(phenotypeId)"
                        />
                      </span>
                      <span
                        v-if="filter.modifier_phenotype_id.content.length === 0"
                        class="phenotype-placeholder"
                      >
                        Select phenotypes...
                      </span>
                    </div>

                    <!-- Control buttons -->
                    <div class="phenotype-controls">
                      <i
                        v-if="filter.modifier_phenotype_id.content.length > 0"
                        v-b-tooltip.hover
                        class="bi bi-x-lg control-icon clear-icon"
                        title="Clear all"
                        @click.stop="clearAllPhenotypes"
                      />
                      <BDropdown
                        ref="phenotypeDropdownRef"
                        no-caret
                        variant="link"
                        size="sm"
                        class="phenotype-dropdown-trigger"
                        menu-class="phenotype-dropdown-menu"
                        @shown="focusSearchInput"
                      >
                        <template #button-content>
                          <i class="bi bi-chevron-down control-icon" />
                        </template>
                        <BDropdownForm @submit.prevent>
                          <BFormInput
                            ref="phenotypeSearchInput"
                            v-model="phenotypeSearch"
                            placeholder="Search phenotypes..."
                            size="sm"
                            class="mb-2"
                            autocomplete="off"
                          />
                        </BDropdownForm>
                        <BDropdownDivider />
                        <div class="phenotype-options-list">
                          <BDropdownItemButton
                            v-for="option in filteredPhenotypeOptions"
                            :key="option.phenotype_id"
                            :active="isPhenotypeSelected(option.phenotype_id)"
                            @click="togglePhenotype(option.phenotype_id)"
                          >
                            <i
                              v-if="isPhenotypeSelected(option.phenotype_id)"
                              class="bi bi-check-square me-2 text-primary"
                            />
                            <i
                              v-else
                              class="bi bi-square me-2 text-muted"
                            />
                            {{ option.HPO_term }}
                          </BDropdownItemButton>
                          <BDropdownText v-if="filteredPhenotypeOptions.length === 0">
                            No matching phenotypes
                          </BDropdownText>
                        </div>
                      </BDropdown>
                    </div>
                  </div>
                  <BSpinner
                    v-if="phenotypes_options.length === 0"
                    small
                    class="ms-2"
                    label="Loading..."
                  />
                </div>
              </BCol>

              <BCol
                class="my-1 d-flex align-items-center"
                sm="2"
              >
                <!-- AND/OR Toggle - Clean Pill Style -->
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
      // Search term for phenotype dropdown filter
      phenotypeSearch: '',
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
  computed: {
    /**
     * Filter phenotype options based on search term.
     * Shows first 50 results for performance.
     */
    filteredPhenotypeOptions() {
      if (!Array.isArray(this.phenotypes_options) || this.phenotypes_options.length === 0) {
        return [];
      }
      const search = this.phenotypeSearch.toLowerCase().trim();
      if (!search) {
        // Return first 50 when no search term
        return this.phenotypes_options.slice(0, 50);
      }
      return this.phenotypes_options
        .filter((opt) =>
          opt.HPO_term.toLowerCase().includes(search) ||
          opt.phenotype_id.toLowerCase().includes(search)
        )
        .slice(0, 50);
    },
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
        // API returns { links, meta, data } - extract the data array
        const phenotypeData = response.data.data || response.data;
        modulePhenotypesListCache = phenotypeData;
        this.phenotypes_options = phenotypeData;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        modulePhenotypesListLoading = false;
      }
    },
    /**
     * Check if a phenotype is currently selected.
     * @param {string} phenotypeId - HPO ID to check
     * @returns {boolean} True if selected
     */
    isPhenotypeSelected(phenotypeId) {
      return this.filter.modifier_phenotype_id.content.includes(phenotypeId);
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
     * Open the phenotype dropdown programmatically.
     */
    openPhenotypeDropdown() {
      if (this.$refs.phenotypeDropdownRef) {
        this.$refs.phenotypeDropdownRef.show();
      }
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
     * Focus the search input when dropdown opens.
     */
    focusSearchInput() {
      this.$nextTick(() => {
        if (this.$refs.phenotypeSearchInput) {
          this.$refs.phenotypeSearchInput.focus();
        }
      });
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
    /**
     * Get phenotype display name from ID.
     * @param {string} phenotypeId - HPO ID
     * @returns {string} HPO term name or the ID if not found
     */
    getPhenotypeName(phenotypeId) {
      if (!Array.isArray(this.phenotypes_options) || this.phenotypes_options.length === 0) {
        return phenotypeId;
      }
      const phenotype = this.phenotypes_options.find(
        (opt) => opt.phenotype_id === phenotypeId
      );
      return phenotype ? phenotype.HPO_term : phenotypeId;
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

/* Phenotype Select Container - Treeselect-like styling */
.phenotype-select-container {
  display: flex;
  align-items: center;
}

.phenotype-select-control {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 38px;
  padding: 4px 8px;
  border: 1px solid #ced4da;
  border-radius: 4px;
  background: #fff;
  cursor: pointer;
  flex: 1;
  transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}

.phenotype-select-control:hover {
  border-color: #80bdff;
}

.phenotype-select-control:focus-within {
  border-color: #80bdff;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.phenotype-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  flex: 1;
  align-items: center;
}

.phenotype-tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  background: #e9f5ff;
  border: 1px solid #b8daff;
  border-radius: 3px;
  font-size: 0.85rem;
  color: #004085;
  max-width: 200px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.phenotype-tag .tag-remove {
  margin-left: 6px;
  cursor: pointer;
  opacity: 0.6;
  font-size: 0.75rem;
}

.phenotype-tag .tag-remove:hover {
  opacity: 1;
  color: #dc3545;
}

.phenotype-placeholder {
  color: #6c757d;
  font-size: 0.9rem;
}

.phenotype-controls {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: 8px;
}

.control-icon {
  color: #6c757d;
  cursor: pointer;
  font-size: 0.85rem;
  padding: 2px;
}

.control-icon:hover {
  color: #495057;
}

.clear-icon:hover {
  color: #dc3545;
}

.phenotype-dropdown-trigger {
  padding: 0;
  margin: 0;
}

.phenotype-dropdown-trigger :deep(.btn) {
  padding: 0 4px;
  border: none;
  background: transparent;
  box-shadow: none;
}

.phenotype-dropdown-trigger :deep(.btn:focus) {
  box-shadow: none;
}

:deep(.phenotype-dropdown-menu) {
  min-width: 350px;
  max-width: 450px;
  margin-top: 4px;
}

.phenotype-options-list {
  max-height: 250px;
  overflow-y: auto;
}

.phenotype-options-list :deep(.dropdown-item) {
  font-size: 0.875rem;
  white-space: normal;
  word-wrap: break-word;
  padding: 8px 16px;
}

.phenotype-options-list :deep(.dropdown-item.active) {
  background-color: #e9f5ff;
  color: #004085;
}

/* AND/OR Toggle - Pill Button Group */
.logic-toggle {
  display: inline-flex;
  border: 1px solid #ced4da;
  border-radius: 20px;
  overflow: hidden;
  background: #f8f9fa;
}

.logic-btn {
  padding: 6px 14px;
  border: none;
  background: transparent;
  font-size: 0.8rem;
  font-weight: 600;
  color: #6c757d;
  cursor: pointer;
  transition: all 0.15s ease;
}

.logic-btn:first-child {
  border-right: 1px solid #ced4da;
}

.logic-btn:hover:not(.active) {
  background: #e9ecef;
}

.logic-btn.active {
  background: #0d6efd;
  color: #fff;
}
</style>
