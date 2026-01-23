<!-- components/tables/TablesEntities.vue -->
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
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Entities: ' + totalRows"
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

            <BRow>
              <BCol
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter['any'].content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
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
              <!-- Custom filter fields slot -->
              <template
                v-if="showFilterControls"
                v-slot:filter-controls
              >
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
                    @update="filtered()"
                  />

                  <BFormSelect
                    v-if="field.selectable && field.selectOptions && field.selectOptions.length > 0"
                    v-model="filter[field.key].content"
                    :options="field.selectOptions"
                    size="sm"
                    @input="removeSearch()"
                    @change="filtered()"
                  >
                    <template v-slot:first>
                      <BFormSelectOption value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                  <BSpinner
                    v-else-if="field.selectable && (!field.selectOptions || field.selectOptions.length === 0)"
                    small
                    label="Loading..."
                  />

                  <!-- Multi-select: temporarily use BFormSelect instead of treeselect for compatibility -->
                  <BFormSelect
                    v-if="field.multi_selectable && field.selectOptions && field.selectOptions.length > 0"
                    v-model="filter[field.key].content"
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
                  <BSpinner
                    v-else-if="field.multi_selectable && (!field.selectOptions || field.selectOptions.length === 0)"
                    small
                    label="Loading..."
                  />
                </td>
              </template>
              <!-- Custom filter fields slot -->

              <template v-slot:cell-entity_id="{ row }">
                <EntityBadge
                  :entity-id="row.entity_id"
                  :link-to="'/Entities/' + row.entity_id"
                  size="sm"
                />
              </template>

              <template v-slot:cell-symbol="{ row }">
                <GeneBadge
                  :symbol="row.symbol"
                  :hgnc-id="row.hgnc_id"
                  :link-to="'/Genes/' + row.hgnc_id"
                  size="sm"
                />
              </template>

              <template v-slot:cell-disease_ontology_name="{ row }">
                <DiseaseBadge
                  :name="row.disease_ontology_name"
                  :ontology-id="row.disease_ontology_id_version"
                  :link-to="'/Ontology/' + row.disease_ontology_id_version.replace(/_.+/g, '')"
                  :max-length="35"
                  size="sm"
                />
              </template>

              <!-- Custom slot for the 'hpo_mode_of_inheritance_term_name' column -->
              <template v-slot:cell-hpo_mode_of_inheritance_term_name="{ row }">
                <InheritanceBadge
                  :full-name="row.hpo_mode_of_inheritance_term_name"
                  :hpo-term="row.hpo_mode_of_inheritance_term"
                  size="sm"
                />
              </template>

              <!-- Custom slot for the 'ndd_phenotype_word' column -->
              <template v-slot:cell-ndd_phenotype_word="{ row }">
                <span v-b-tooltip.hover.left :title="ndd_icon_text[row.ndd_phenotype_word]">
                  <NddIcon :status="row.ndd_phenotype_word" size="sm" :show-title="false" />
                </span>
              </template>

              <!-- Custom slot for the 'category' column -->
              <template v-slot:cell-category="{ row }">
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

<script>/**
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

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'TablesEntities',
  components: {
    // Components used within TablesEntities
    TablePaginationControls, TableDownloadLinkCopyButtons, TableHeaderLabel, TableSearchInput, GenericTable,
    CategoryIcon, NddIcon, EntityBadge, GeneBadge, DiseaseBadge, InheritanceBadge,
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

    // Inject axios and route
    const axios = inject('axios');
    const route = useRoute();

    // Table methods composable
    const tableMethods = useTableMethods(tableData, {
      filter,
      filterObjToStr,
      apiEndpoint: props.apiEndpoint,
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
    filter: {
      handler(value) {
        this.filtered();
      },
      deep: true,
    },
    // Watch for sortBy changes (deep watch for array)
    sortBy: {
      handler() {
        this.handleSortByOrDescChange();
      },
      deep: true,
    },
  },
  created() {
  // Lifecycle hooks
  },
  mounted() {
    // Lifecycle hooks
    // Transform input sort string to Bootstrap-Vue-Next array format
    // sortStringToVariables now returns { sortBy: [{ key: 'column', order: 'asc'|'desc' }] }
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;

    // Transform input filter string to object and load data
    // Use $nextTick to ensure Vue reactivity is fully initialized
    this.$nextTick(() => {
      if (this.filterInput && this.filterInput !== 'null' && this.filterInput !== '') {
        // Directly set the filter_string from input and load
        // This bypasses complex reactivity issues with the filter object
        this.filter_string = this.filterInput;
        this.loadData();
      } else {
        this.loadData();
      }
    });

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
    // Override filtered to call loadData
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);

      if (filter_string_loc !== this.filter_string) {
        this.filter_string = filter_string_loc;
      }

      this.loadData();
    },
    async loadData() {
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
      }/api/entity?${
        urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);
        this.items = response.data.data;

        this.totalRows = response.data.meta[0].totalItems;
        // this solves an update issue in b-pagination component
        // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
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

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
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
