<!-- components/tables/TablesGenes.vue -->
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
                    :subtitle="'Genes: ' + totalRows"
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
            <BTable
              :items="items"
              :fields="fields"
              :current-page="currentPage"
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
              no-local-pagination
              @update:sort-by="handleSortByUpdate"
            >
              <!-- custom formatted header -->
              <template v-slot:head()="data">
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
                <tr>
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

                  <label
                    v-if="field.selectable"
                    :for="'select_' + field.key"
                    :aria-label="field.label"
                  >
                    <BFormSelect
                      id="'select_' + field.key"
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
                  </label>

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
                      @change="removeSearch();filtered();"
                    >
                      <template v-slot:first>
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
                    :items="row.item.entities"
                    :fields="fields_details"
                    head-variant="light"
                    show-empty
                    small
                    fixed
                    striped
                    sort-icon-left
                  >
                    <template #cell(entity_id)="data">
                      <EntityBadge
                        :entity-id="data.item.entity_id"
                        :link-to="'/Entities/' + data.item.entity_id"
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

                    <template #cell(ndd_phenotype_word)="data">
                      <div v-b-tooltip.hover.left :title="ndd_icon_text[data.item.ndd_phenotype_word]">
                        <NddIcon :status="data.item.ndd_phenotype_word" size="sm" :show-title="false" />
                      </div>
                    </template>

                    <template #cell(category)="data">
                      <div v-b-tooltip.hover.left :title="data.item.category">
                        <CategoryIcon :category="data.item.category" size="sm" :show-title="false" />
                      </div>
                    </template>

                    <template #cell(hpo_mode_of_inheritance_term_name)="data">
                      <InheritanceBadge
                        :full-name="data.item.hpo_mode_of_inheritance_term_name"
                        :hpo-term="data.item.hpo_mode_of_inheritance_term"
                        size="sm"
                      />
                    </template>
                  </BTable>
                </BCard>
              </template>

              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="data.item.symbol"
                  :hgnc-id="data.item.hgnc_id"
                  :link-to="'/Genes/' + data.item.hgnc_id"
                  size="sm"
                />
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="d-flex flex-wrap gap-1">
                  <InheritanceBadge
                    v-for="item in data.item.entities"
                    :key="item.hpo_mode_of_inheritance_term_name + item.entity_id"
                    :full-name="item.hpo_mode_of_inheritance_term_name"
                    :hpo-term="item.hpo_mode_of_inheritance_term"
                    size="sm"
                  />
                </div>
              </template>

              <template #cell(category)="data">
                <div class="d-flex flex-wrap gap-1">
                  <span
                    v-for="item in data.item.entities"
                    :key="item.category + item.entity_id"
                    v-b-tooltip.hover.left
                    :title="item.category"
                  >
                    <CategoryIcon :category="item.category" size="sm" :show-title="false" />
                  </span>
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div class="d-flex flex-wrap gap-1">
                  <span
                    v-for="item in data.item.entities"
                    :key="item.ndd_phenotype_word + item.entity_id"
                    v-b-tooltip.hover.left
                    :title="ndd_icon_text[item.ndd_phenotype_word]"
                  >
                    <NddIcon :status="item.ndd_phenotype_word" size="sm" :show-title="false" />
                  </span>
                </div>
              </template>

              <template #cell(entities_count)="data">
                <BBadge
                  variant="secondary"
                  pill
                  class="px-2"
                >
                  {{ data.item.entities_count }}
                </BBadge>
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

// Import Vue utilities
import { ref, inject } from 'vue';
import { useRoute } from 'vue-router';

// Import Bootstrap-Vue-Next components
import { BTable, BCard } from 'bootstrap-vue-next';

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

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'TablesGenes',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: {
    // Components used within TablesGenes
    BTable, BCard, TablePaginationControls, TableDownloadLinkCopyButtons, TableHeaderLabel, TableSearchInput,
    CategoryIcon, NddIcon, GeneBadge, InheritanceBadge,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'gene',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Genes table' },
    sortInput: { type: String, default: '+symbol' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: String, default: '10' },
    fspecInput: {
      type: String,
      default:
        'symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details',
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

    // Component-specific filter (defined here, not in composable)
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

    // Note: loadData is not passed here because it's defined in methods
    // and will be available via this context when tableMethods.filtered() is called
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
          key: 'symbol',
          label: 'Gene Symbol',
          sortable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'category',
          label: 'Category',
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'entities_count',
          label: 'Entities count',
        },
        {
          key: 'details',
          label: 'Details',
        },
      ],
      fields_details: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          sortDirection: 'desc',
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
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'category',
          label: 'Category',
          sortable: false,
          class: 'text-start',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: false,
          class: 'text-start',
        },
      ],
    };
  },
  watch: {
    // Watch for filter changes
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
    // Transform input sort string to Bootstrap-Vue-Next array format
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;

    // Conditionally perform data load based on filter input
    // Fixes double loading and update bugs
    if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      // Transform input filter string from params to object and assign
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    } else {
      // Initiate first data load
      this.loadData();
    }

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
      }/api/gene?${
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
