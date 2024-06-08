<!-- components/tables/TablesGenes.vue -->
<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
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
                  <TableHeaderLabel
                    :label="headerLabel"
                    :subtitle="'Genes: ' + totalRows"
                    :tool-tip-title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
                  />
                </b-col>
                <b-col>
                  <h5
                    v-if="showFilterControls"
                    class="mb-1 text-right font-weight-bold"
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
                </b-col>
              </b-row>
            </template>

            <b-row>
              <b-col
                class="my-1"
                sm="8"
              >
                <TableSearchInput
                  v-model="filter['any'].content"
                  :placeholder="'Search any field by typing here'"
                  :debounce-time="500"
                  @input="filtered"
                />
              </b-col>

              <b-col
                class="my-1"
                sm="4"
              >
                <b-container
                  v-if="totalRows > perPage || showPaginationControls"
                >
                  <TablePaginationControls
                    :total-rows="totalRows"
                    :initial-per-page="perPage"
                    :page-options="pageOptions"
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  />
                </b-container>
              </b-col>
            </b-row>
            <!-- User Interface controls -->

            <!-- Main table element -->
            <b-table
              :items="items"
              :fields="fields"
              :current-page="currentPage"
              :filter-included-fields="filterOn"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
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

              <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
              <template
                slot="top-row"
              >
                <td
                  v-for="field in fields"
                  :key="field.key"
                >
                  <b-form-input
                    v-if="field.filterable"
                    v-model="filter[field.key].content"
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

              <template #cell(details)="row">
                <b-button
                  class="btn-xs"
                  variant="outline-primary"
                  @click="row.toggleDetails"
                >
                  {{ row.detailsShowing ? "Hide" : "Show" }}
                </b-button>
              </template>

              <template #row-details="row">
                <b-card>
                  <b-table
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
                      <div>
                        <b-link :href="'/Entities/' + data.item.entity_id">
                          <b-badge
                            variant="primary"
                            style="cursor: pointer"
                          >
                            sysndd:{{ data.item.entity_id }}
                          </b-badge>
                        </b-link>
                      </div>
                    </template>

                    <template #cell(disease_ontology_name)="data">
                      <div class="overflow-hidden text-truncate">
                        <b-link
                          :href="
                            '/Ontology/' +
                              data.item.disease_ontology_id_version.replace(
                                /_.+/g,
                                ''
                              )
                          "
                        >
                          <b-badge
                            v-b-tooltip.hover.leftbottom
                            pill
                            variant="secondary"
                            :title="
                              data.item.disease_ontology_name +
                                '; ' +
                                data.item.disease_ontology_id_version
                            "
                          >
                            {{ truncate(data.item.disease_ontology_name, 40) }}
                          </b-badge>
                        </b-link>
                      </div>
                    </template>

                    <template #cell(ndd_phenotype_word)="data">
                      <div>
                        <b-avatar
                          v-b-tooltip.hover.left
                          size="1.4em"
                          :icon="ndd_icon[data.item.ndd_phenotype_word]"
                          :variant="
                            ndd_icon_style[data.item.ndd_phenotype_word]
                          "
                          :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                        />
                      </div>
                    </template>

                    <template #cell(category)="data">
                      <div>
                        <b-avatar
                          v-b-tooltip.hover.left
                          icon="stoplights"
                          size="1.4em"
                          class="mx-0"
                          :variant="stoplights_style[data.item.category]"
                          :title="data.item.category"
                        />
                      </div>
                    </template>

                    <template #cell(hpo_mode_of_inheritance_term_name)="data">
                      <div>
                        <b-badge
                          v-b-tooltip.hover.leftbottom
                          pill
                          variant="info"
                          class="justify-content-md-center px-1 mx-1"
                          size="1.3em"
                          :title="
                            data.item.hpo_mode_of_inheritance_term_name +
                              ' (' +
                              data.item.hpo_mode_of_inheritance_term +
                              ')'
                          "
                        >
                          {{
                            inheritance_short_text[
                              data.item.hpo_mode_of_inheritance_term_name
                            ]
                          }}
                        </b-badge>
                      </div>
                    </template>
                  </b-table>
                </b-card>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic">
                  <b-link :href="'/Genes/' + data.item.hgnc_id">
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div>
                  <b-badge
                    v-for="item in data.item.entities"
                    :key="
                      item.hpo_mode_of_inheritance_term_name + item.entity_id
                    "
                    v-b-tooltip.hover.leftbottom
                    pill
                    size="1.3em"
                    variant="info"
                    class="justify-content-md-center px-1 mx-1"
                    :title="
                      item.hpo_mode_of_inheritance_term_name +
                        ' (' +
                        item.hpo_mode_of_inheritance_term +
                        ')'
                    "
                  >
                    {{
                      inheritance_short_text[
                        item.hpo_mode_of_inheritance_term_name
                      ]
                    }}
                  </b-badge>
                </div>
              </template>

              <template #cell(category)="data">
                <div>
                  <b-avatar
                    v-for="item in data.item.entities"
                    :key="item.category + item.entity_id"
                    v-b-tooltip.hover.left
                    icon="stoplights"
                    size="1.4em"
                    class="px-0 mx-1"
                    :variant="stoplights_style[item.category]"
                    :title="item.category"
                  />
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div>
                  <b-avatar
                    v-for="item in data.item.entities"
                    :key="item.ndd_phenotype_word + item.entity_id"
                    v-b-tooltip.hover.left
                    size="1.4em"
                    class="px-0 mx-1"
                    :icon="ndd_icon[item.ndd_phenotype_word]"
                    :variant="ndd_icon_style[item.ndd_phenotype_word]"
                    :title="ndd_icon_text[item.ndd_phenotype_word]"
                  />
                </div>
              </template>

              <template #cell(entities_count)="data">
                <b-avatar
                  icon="stoplights"
                  size="1.2em"
                  class="px-0 mx-1"
                >
                  {{ data.item.entities_count }}
                </b-avatar>
              </template>
            </b-table>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect';
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

import toastMixin from '@/assets/js/mixins/toastMixin';
import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// Import the table mixins
import tableMethodsMixin from '@/assets/js/mixins/tableMethodsMixin';
import tableDataMixin from '@/assets/js/mixins/tableDataMixin';

// Import the Table components
import TableHeaderLabel from '@/components/small/TableHeaderLabel.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Import the event bus
import EventBus from '@/assets/js/eventBus';

export default {
  name: 'TablesGenes',
  // register the Treeselect component
  components: {
    // Components used within TablesEntities
    Treeselect, TablePaginationControls, TableDownloadLinkCopyButtons, TableHeaderLabel, TableSearchInput,
  },
  mixins: [
    // Mixins used within TablesEntities
    toastMixin, urlParsingMixin, colorAndSymbolsMixin, textMixin, tableMethodsMixin, tableDataMixin,
  ],
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
  data() {
    return {
      // ... data properties with a brief description for each
      fields: [
        {
          key: 'symbol',
          label: 'Gene Symbol',
          sortable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'category',
          label: 'Category',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: false,
          class: 'text-left',
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
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'category',
          label: 'Category',
          sortable: false,
          class: 'text-left',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: false,
          class: 'text-left',
        },
      ],
      filter: {
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
      },
    };
  },
  watch: {
    // ... watchers with descriptions
    filter(value) {
      this.filtered();
    },
    sortBy(value) {
      this.handleSortByOrDescChange();
    },
    sortDesc(value) {
      this.handleSortByOrDescChange();
    },
  },
  created() {
  // Lifecycle hooks
  },
  mounted() {
  // Lifecycle hooks
    // transform input sort string to object and assign
    const sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;
    this.sortDesc = sort_object.sortDesc;

    // conditionally perform data load based on filter input
    // fixes double loading and update bugs
    if (this.filterInput !== null && this.filterInput !== 'null' && this.filterInput !== '') {
      // transform input filter string from params to object and assign
      this.filter = this.filterStrToObj(this.filterInput, this.filter);
    } else {
      // initiate first data load
      this.loadData();
    }

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
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

      const apiUrl = `${process.env.VUE_APP_API_URL
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

        EventBus.$emit('update-scrollbar'); // Emit event to update scrollbar

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
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
