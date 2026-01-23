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
                    @change="filtered"
                  >
                    <template v-slot:first>
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
                      @input="filtered"
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
                  <BInputGroup
                    prepend="Per page"
                    class="mb-1"
                    size="sm"
                  >
                    <BFormSelect
                      id="per-page-select"
                      v-model="perPage"
                      :options="pageOptions"
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
                      @update="filtered()"
                    />

                    <BFormSelect
                      v-if="field.selectable"
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

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

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
  },
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Phenotype table' },
    sortInput: { type: String, default: 'entity_id' },
    filterInput: { type: String, default: 'all(modifier_phenotype_id,HP:0001249)' },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: String, default: '10' },
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

    // Return all needed properties
    return {
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      ...colorAndSymbols,
      ...text,
    };
  },
  data() {
    return {
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
    filter: {
      handler(value) {
        this.filtered();
      },
      deep: true, // Vue 3 requires deep:true for object mutation watching
    },
    // Watch for sortBy changes (deep watch for array)
    sortBy: {
      handler() {
        this.handleSortByOrDescChange();
      },
      deep: true,
    },
    perPage(value) {
      this.handlePerPageChange();
    },
  },
  created() {
    // load phenotypes list
    this.loadPhenotypesList();
  },
  mounted() {
    // Transform input sort string to Bootstrap-Vue-Next array format
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;

    // conditionally perform data load based on filter input
    // fixes double loading and update bugs
    if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      // transform input filter string from params to object and assign
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    } else {
      // initiate first data load
      this.requestSelected();
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
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
        `${import.meta.env.VITE_URL + this.$route.path}?${urlParam}`,
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
      const logical_operator = '';

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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype`;
      try {
        const response = await this.axios.get(apiUrl);
        this.phenotypes_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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
    async loadEntitiesFromPhenotypes() {
      this.isBusy = true;

      // compose URL param
      const urlParam = `sort=${
        this.sort
      }&filter=${
        this.filter_string
      }&page_after=${
        this.currentItemID
      }&page_size=${
        this.perPage}`;

      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/phenotype/entities/browse?${
        urlParam}`;

      try {
        const response = await this.axios.get(apiUrl);

        this.fields = response.data.meta[0].fspec;
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

        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
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
