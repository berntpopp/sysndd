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
                  <h6 class="mb-1 text-left font-weight-bold">
                    {{ headerLabel }}
                    <b-badge
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
                      Entities: {{ totalRows }}
                    </b-badge>
                  </h6>
                </b-col>
                <b-col>
                  <h6
                    v-if="showFilterControls"
                    class="mb-1 text-right font-weight-bold"
                  >
                    <b-button
                      v-b-tooltip.hover.bottom
                      class="mx-1"
                      size="sm"
                      title="Copy link to this page."
                      variant="success"
                      @click="copyLinkToClipboard()"
                    >
                      <b-icon
                        icon="link"
                        font-scale="1.0"
                      />
                    </b-button>

                    <b-button
                      v-b-tooltip.hover.bottom
                      size="sm"
                      :title="
                        'The table is ' +
                          (filter_string === '' ? 'not' : '') +
                          ' filtered.' +
                          (filter_string === ''
                            ? ''
                            : ' Click to remove all filters.')
                      "
                      :variant="filter_string === '' ? 'info' : 'warning'"
                      @click="removeFilters()"
                    >
                      <b-icon
                        icon="filter"
                        font-scale="1.0"
                      />
                    </b-button>
                  </h6>
                </b-col>
              </b-row>
            </template>

            <b-row>
              <b-col
                class="my-1"
                sm="8"
              >
                <b-form-group class="mb-1 border-dark">
                  <b-form-input
                    v-if="showFilterControls"
                    id="filter-input"
                    v-model="filter['any'].content"
                    class="mb-1 border-dark"
                    size="sm"
                    type="search"
                    placeholder="Search any field by typing here"
                    debounce="500"
                    @click="removeFilters()"
                    @update="filtered()"
                  />
                </b-form-group>
              </b-col>

              <b-col
                class="my-1"
                sm="4"
              >
                <b-container
                  v-if="totalRows > perPage || showPaginationControls"
                >
                  <b-input-group
                    prepend="Per page"
                    class="mb-1"
                    size="sm"
                  >
                    <b-form-select
                      id="per-page-select"
                      v-model="perPage"
                      :options="pageOptions"
                      size="sm"
                    />
                  </b-input-group>

                  <b-pagination
                    v-model="currentPage"
                    :total-rows="totalRows"
                    :per-page="perPage"
                    align="fill"
                    size="sm"
                    class="my-0"
                    limit="2"
                    @change="handlePageChange"
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
                        .filter((item) => item.label == data.label)
                        .map((item) => {
                          return item.count_filtered;
                        })[0] +
                      '/' +
                      fields
                        .filter((item) => item.label == data.label)
                        .map((item) => {
                          return item.count;
                        })[0] +
                      ')'
                  "
                >
                  {{ truncate(data.label, 20) }}
                </div>
              </template>

              <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
              <template
                v-if="showFilterControls"
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
                  >
                    <template v-slot:first>
                      <b-form-select-option value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </b-form-select-option>
                    </template>
                  </b-form-select>

                  <treeselect
                    v-if="field.multi_selectable"
                    :id="'select_' + field.key"
                    v-model="filter[field.key].content"
                    size="small"
                    :multiple="true"
                    :options="field.selectOptions"
                    :normalizer="normalizer"
                    :placeholder="'.. ' + truncate(field.label, 20) + ' ..'"
                    @input="removeSearch()"
                  />
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
                    :items="[row.item]"
                    :fields="fields_details"
                    stacked
                    small
                  />
                </b-card>
              </template>

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

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
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
                      {{ data.item.disease_ontology_name }}
                    </b-badge>
                  </b-link>
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

              <template #cell(ndd_phenotype_word)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :icon="ndd_icon[data.item.ndd_phenotype_word]"
                    :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                    :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                  />
                </div>
              </template>

              <template #cell(category)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style[data.item.category]"
                    :title="data.item.category"
                  />
                </div>
              </template>
            </b-table>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>


<script>
import toastMixin from "@/assets/js/mixins/toastMixin.js";
import urlParsingMixin from "@/assets/js/mixins/urlParsingMixin.js";

// import the Treeselect component
import Treeselect from "@riophae/vue-treeselect";
// import the Treeselect styles
import "@riophae/vue-treeselect/dist/vue-treeselect.css";

export default {
  name: "TablesEntities",
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, urlParsingMixin],
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: "Entities table" },
    sortInput: { type: String, default: "+entity_id" },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: "" },
    pageSizeInput: { type: String, default: "10" },
    fspecInput: {
      type: String,
      default:
        "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details",
    },
  },
  data() {
    return {
      stoplights_style: {
        Definitive: "success",
        Moderate: "primary",
        Limited: "warning",
        Refuted: "danger",
      },
      ndd_icon: { No: "x", Yes: "check" },
      ndd_icon_style: { No: "warning", Yes: "success" },
      ndd_icon_text: {
        No: "NOT associated with NDD",
        Yes: "associated with NDD",
      },
      inheritance_short_text: {
        "Autosomal dominant inheritance": "AD",
        "Autosomal recessive inheritance": "AR",
        "Semidominant inheritance": "SD",
        "X-linked inheritance, other": "Xo",
        "X-linked recessive inheritance": "XR",
        "X-linked dominant inheritance": "XD",
        "Mitochondrial inheritance": "Mit",
        "Somatic mutation": "Som",
      },
      items: [],
      fields: [
        {
          key: "entity_id",
          label: "Entity",
          sortable: true,
          sortDirection: "asc",
          class: "text-left",
        },
        {
          key: "symbol",
          label: "Symbol",
          sortable: true,
          class: "text-left",
        },
        {
          key: "disease_ontology_name",
          label: "Disease",
          sortable: true,
          class: "text-left",
        },
        {
          key: "hpo_mode_of_inheritance_term_name",
          label: "Inheritance",
          sortable: true,
          class: "text-left",
        },
        {
          key: "category",
          label: "Category",
          sortable: true,
          class: "text-left",
        },
        {
          key: "ndd_phenotype_word",
          label: "NDD",
          sortable: true,
          class: "text-left",
        },
        {
          key: "details",
          label: "Details",
        },
      ],
      fields_details: [
        { key: "hgnc_id", label: "HGNC ID", class: "text-left" },
        {
          key: "disease_ontology_id_version",
          label: "Ontology ID version",
          class: "text-left",
        },
        {
          key: "disease_ontology_name",
          label: "Disease ontology name",
          class: "text-left",
        },
        { key: "entry_date", label: "Entry date", class: "text-left" },
        { key: "synopsis", label: "Clinical Synopsis", class: "text-left" },
      ],
      totalRows: 0,
      currentPage: 1,
      currentItemID: this.pageAfterInput,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      perPage: this.pageSizeInput,
      pageOptions: ["10", "25", "50", "200"],
      sortBy: "entity_id",
      sortDesc: true,
      sort: this.sortInput,
      filter: {
        any: {content: null, join_char: null, operator: 'contains'},
        entity_id: {content: null, join_char: null, operator: 'contains'},
        symbol: {content: null, join_char: null, operator: 'contains'},
        disease_ontology_name: {content: null, join_char: null, operator: 'contains'},
        disease_ontology_id_version: {content: null, join_char: null, operator: 'contains'},
        hpo_mode_of_inheritance_term_name: {content: null, join_char: ',', operator: 'any'},
        hpo_mode_of_inheritance_term: {content: null, join_char: ',', operator: 'any'},
        ndd_phenotype_word: {content: null, join_char: null, operator: 'contains'},
        category: {content: null, join_char: ',', operator: 'any'},
      },
      filter_string: "",
      filterOn: [],
      infoModal: {
        id: "info-modal",
        title: "",
        content: "",
      },
      loading: true,
      isBusy: true,
    };
  },
  watch: {
    filter(value) {
      this.filtered();
    },
    sortBy(value) {
      this.handleSortByOrDescChange();
    },
    sortDesc(value) {
      this.handleSortByOrDescChange();
    },
    perPage(value) {
      this.handlePerPageChange();
    },
  },
  created() {
    // transform input filter string from params to object and assign
    this.filter = this.filterStrToObj(this.filterInput, this.filter);
  },
  mounted() {
    // transform input sort string to object and assign
    let sort_object = this.sortStringToVariables(this.sortInput);
    this.sortBy = sort_object.sortBy;
    this.sortDesc = sort_object.sortDesc;

    this.filtered();

    setTimeout(() => {
      this.loading = false;
    }, 500);
  },
  methods: {
    copyLinkToClipboard() {
      let urlParam =
        "sort=" +
        this.sort +
        "&filter=" +
        this.filter_string +
        "&page_after=" +
        this.currentItemID +
        "&page_size=" +
        this.perPage;
      navigator.clipboard.writeText(
        process.env.VUE_APP_URL + this.$route.path + "?" + urlParam
      );
    },
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      this.sort = (!this.sortDesc ? "-" : "+") + this.sortBy;
      this.filtered();
    },
    handlePerPageChange() {
      this.currentItemID = 0;
      this.filtered();
    },
    handlePageChange(value) {
      if (value == 1) {
        this.currentItemID = 0;
        this.filtered();
      } else if (value == this.totalPages) {
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
      this.filter_string = this.filterObjToStr(this.filter);
      this.loadEntitiesData();
    },
    removeFilters() {
      this.filter = {
        any: {content: null, join_char: null, operator: 'contains'},
        entity_id: {content: null, join_char: null, operator: 'contains'},
        symbol: {content: null, join_char: null, operator: 'contains'},
        disease_ontology_name: {content: null, join_char: null, operator: 'contains'},
        disease_ontology_id_version: {content: null, join_char: null, operator: 'contains'},
        hpo_mode_of_inheritance_term_name: {content: null, join_char: ',', operator: 'any'},
        hpo_mode_of_inheritance_term: {content: null, join_char: ',', operator: 'any'},
        ndd_phenotype_word: {content: null, join_char: null, operator: 'contains'},
        category: {content: null, join_char: ',', operator: 'any'},
      };
      this.filtered();
    },
    removeSearch() {
      this.filter["any"].content = null;
      this.filtered();
    },
    async loadEntitiesData() {
      this.isBusy = true;

      const urlParam =
        "sort=" +
        this.sort +
        "&filter=" +
        this.filter_string +
        "&page_after=" +
        this.currentItemID +
        "&page_size=" +
        this.perPage;

      const apiUrl = process.env.VUE_APP_API_URL + 
        "/api/entity?" +
        urlParam;

      try {
        let response = await this.axios.get(apiUrl);
        this.items = response.data.data;

        this.totalRows = response.data.meta[0].totalItems;
        this.currentPage = response.data.meta[0].currentPage;
        this.totalPages = response.data.meta[0].totalPages;
        this.prevItemID = response.data.meta[0].prevItemID;
        this.currentItemID = response.data.meta[0].currentItemID;
        this.nextItemID = response.data.meta[0].nextItemID;
        this.lastItemID = response.data.meta[0].lastItemID;
        this.executionTime = response.data.meta[0].executionTime;
        this.fields = response.data.meta[0].fspec;

        this.isBusy = false;
      } catch (e) {
        this.makeToast(e, "Error", "danger");
      }
    },
    normalizer(node) {
      return {
        id: node,
        label: node,
      };
    },
    truncate(str, n) {
      return str.length > n ? str.substr(0, n - 1) + "..." : str;
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
</style>