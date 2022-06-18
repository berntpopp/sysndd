<template>
  <div class="container-fluid">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

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
              Genes table <b-badge variant="success" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Genes: {{totalRows}} </b-badge>
            </h6>

            </b-col>
            <b-col>
            
            <h6
              class="mb-1 text-right font-weight-bold"
              v-if="show_filter_controls"
            >
                <b-button
                class="mx-1"
                size="sm"
                v-b-tooltip.hover.bottom
                title="Copy link to this page."
                variant="success"
                @click="copyLinkToClipboard()"
                >
                  <b-icon icon="link" font-scale="1.0"></b-icon>
                </b-button>

                <b-button
                class="mx-1"
                size="sm"
                v-b-tooltip.hover.bottom
                v-bind:title="'The table is ' + (filter_string === '' ? 'not' : '') + ' filtered.' +  (filter_string === '' ? '' : ' Click to remove all filters.')"
                :variant="filter_string === '' ? 'info' : 'warning'"
                @click="removeFilters()"
                >
                  <b-icon icon="filter" font-scale="1.0"></b-icon>
                </b-button>
            </h6>

            </b-col>
          </b-row>
          </template>

          <b-row>
            <b-col class="my-1" sm="8">
              <b-form-group
                class="mb-1"
              >
                  <b-form-input
                    v-if="show_filter_controls"
                    id="filter-input"
                    class="mb-1 border-dark"
                    size="sm"
                    v-model="filter['any']"
                    type="search"
                    placeholder="Search any field by typing here"
                    debounce="500"
                    @click="removeFilters()"
                    @update="filtered()"
                  >
                  </b-form-input>
              </b-form-group>
            </b-col>

            <b-col class="my-1" sm="4">
              <b-container
                v-if="(totalRows > perPage) || show_pagination_controls"
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
                ></b-form-select>
              </b-input-group>

              <b-pagination
                @change="handlePageChange"
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
                limit=2
              ></b-pagination>
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
                  :data="data"
                  v-b-tooltip.hover.top
                  data-html="true"
                  v-bind:title="data.label + 
                    ' (unique filtered/total values: ' + fields.filter(item => item.label == data.label).map(item => {return item.count_filtered })[0] + '/' + fields.filter(item => item.label == data.label).map(item => {return item.count })[0] + ')'"
                >
                  {{ truncate(data.label, 20) }}
                </div>
            </template>

            <!-- based on:  https://stackoverflow.com/questions/52959195/bootstrap-vue-b-table-with-filter-in-header -->
            <template slot="top-row" slot-scope="{ fields }">
              <td v-for="field in fields" :key="field.key">
                <b-form-input 
                v-if="field.filterable"
                v-model="filter[field.key]" 
                :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
                debounce="500"
                type="search"
                autocomplete="off"
                @click="removeSearch()"
                @update="filtered()"
                >
                </b-form-input>

                <b-form-select
                  v-if="field.selectable"
                  v-model="filter[field.key]"
                  :options="field.selectOptions"
                  type="search"
                  @input="removeSearch()"
                >
                  <template v-slot:first>
                    <b-form-select-option value=null> .. {{ truncate(field.label, 20) }} .. </b-form-select-option>
                  </template>
                </b-form-select>

                <treeselect
                  v-if="field.multi_selectable"
                  size="small"
                  :id="'select_' + field.key"
                  v-model="filter[field.key]" 
                  :multiple="true" 
                  :options="field.selectOptions"
                  :normalizer="normalizer"
                  :placeholder="'.. ' + truncate(field.label, 20) + ' ..'"
                  @input="removeSearch()"
                />

              </td>
            </template>

            <template #cell(details)="row">
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }}
              </b-button>
            </template>

            <template #row-details="row">
              <b-card>
                <b-table
                  :items="row.item.entities"
                  :fields="entities_fields"
                  head-variant="light"
                  show-empty
                  small
                  fixed
                  striped
                  sort-icon-left
                >

                  <template #cell(entity_id)="data">
                    <div>
                      <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                        <b-badge 
                        variant="primary" 
                        style="cursor:pointer"
                        >
                        sysndd:{{ data.item.entity_id }}
                        </b-badge>
                      </b-link>
                    </div>
                  </template>

                  <template #cell(disease_ontology_name)="data">
                    <div class="overflow-hidden text-truncate">
                      <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
                        <b-badge 
                        pill 
                        variant="secondary"
                        v-b-tooltip.hover.leftbottom 
                        v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                        >
                        {{ truncate(data.item.disease_ontology_name, 40) }}
                        </b-badge>
                      </b-link>
                    </div> 
                  </template>

                  <template #cell(ndd_phenotype_word)="data">
                    <div>
                      <b-avatar 
                      size="1.4em" 
                      :icon="ndd_icon[data.item.ndd_phenotype_word]"
                      :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                      v-b-tooltip.hover.left 
                      v-bind:title="ndd_icon_text[data.item.ndd_phenotype_word]"
                      >
                      </b-avatar>
                    </div> 
                  </template>

                  <template #cell(category)="data">
                    <div>
                      <b-avatar
                      icon="stoplights"
                      size="1.4em"
                      class="mx-0"
                      :variant="stoplights_style[data.item.category]"
                      v-b-tooltip.hover.left 
                      v-bind:title="data.item.category"
                      >
                      </b-avatar>
                    </div> 
                  </template>

                  <template #cell(hpo_mode_of_inheritance_term_name)="data">
                    <div>
                      <b-badge 
                      pill 
                      variant="info" 
                      class="justify-content-md-center px-1 mx-1" 
                      size="1.3em"
                      v-b-tooltip.hover.leftbottom 
                      v-bind:title="data.item.hpo_mode_of_inheritance_term_name + ' (' + data.item.hpo_mode_of_inheritance_term + ')'"
                      >
                      {{ inheritance_short_text[data.item.hpo_mode_of_inheritance_term_name] }}
                      </b-badge>
                    </div>
                  </template>

                </b-table>
              </b-card>
            </template>

            <template #cell(symbol)="data">
              <div class="font-italic">
                <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                  <b-badge pill variant="success"
                  v-b-tooltip.hover.leftbottom 
                  v-bind:title="data.item.hgnc_id"
                  >
                  {{ data.item.symbol }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
              <div>
                <b-badge 
                pill 
                size="1.3em" 
                variant="info" 
                class="justify-content-md-center px-1 mx-1"
                v-for="item in data.item.entities" 
                :key="item.hpo_mode_of_inheritance_term_name + item.entity_id" 
                v-b-tooltip.hover.leftbottom 
                v-bind:title="item.hpo_mode_of_inheritance_term_name + ' (' + item.hpo_mode_of_inheritance_term + ')'"
                >
                {{ inheritance_short_text[item.hpo_mode_of_inheritance_term_name] }}
                </b-badge>
              </div>
            </template>

            <template #cell(category)="data">
              <div>
                <b-avatar
                icon="stoplights"
                size="1.4em"
                class="px-0 mx-1"
                v-for="item in data.item.entities" 
                :key="item.category + item.entity_id"
                :variant="stoplights_style[item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="item.category"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(ndd_phenotype_word)="data">
              <div>
                <b-avatar 
                  size="1.4em"
                  class="px-0 mx-1"
                  v-for="item in data.item.entities" 
                  :icon="ndd_icon[item.ndd_phenotype_word]"
                  :variant="ndd_icon_style[item.ndd_phenotype_word]"
                  v-b-tooltip.hover.left 
                  v-bind:title="ndd_icon_text[item.ndd_phenotype_word]"
                  :key="item.ndd_phenotype_word + item.entity_id"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(entities_count)="data">
                <b-avatar
                icon="stoplights"
                size="1.2em"
                class="px-0 mx-1"
                >
                {{data.item.entities_count}}
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
  import toastMixin from '@/assets/js/mixins/toastMixin.js'
  import urlParsingMixin from '@/assets/js/mixins/urlParsingMixin.js'

  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

export default {
  name: 'TablesGenes',
  props: {
    show_filter_controls:  {type: Boolean,  default: true},
    show_pagination_controls:  {type: Boolean,  default: true},
    header_label: {type: String,  default: 'Genes table'},
    sort_input: {type: String,  default: '+symbol'},
    filter_input: {type: String,  default: null},
    fields_input: {type: String,  default: null},
    page_after_input: {type: String,  default: ''},
    page_size_input:  {type: String,  default: "10"},
    fspec_input: {type: String,  default: "symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details"},
  },
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, urlParsingMixin],
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "NOT associated with NDD", "Yes": "associated with NDD"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance, other": "Xo", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "Mit", "Somatic mutation": "Som"},
          items: [],
          fields: [
            { 
              key: 'symbol', 
              label: 'Gene Symbol', 
              sortable: true, 
              sortDirection: 'desc', 
              class: 'text-left' 
            },
            { 
              key: 'category', 
              label: 'Category', 
              sortable: false, 
              class: 'text-left' 
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: false,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'ndd_phenotype_word',
              label: 'NDD',
              sortable: false,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { 
              key: 'entities_count',
              label: 'Entities count'
            },
            { 
              key: 'details',
              label: 'Details'
            }
          ],
          entities_fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: false,
              filterable: true, 
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { 
              key: 'category', 
              label: 'Category', 
              sortable: false, 
              filterable: true, 
              class: 'text-left' 
            },            
            { 
              key: 'ndd_phenotype_word', 
              label: 'NDD', 
              sortable: false, 
              class: 'text-left' 
            }
          ],
          totalRows: 0,
          currentPage: 1,
          currentItemID: this.page_after_input,
          prevItemID: null,
          nextItemID: null,
          lastItemID: null,
          executionTime: 0,
          perPage: this.page_size_input,
          pageOptions: ["10", "25", "50", "200"],
          sortBy: 'symbol',
          sortDesc: true,
          sort: this.sort_input,
          filter: {any: null, entity_id: null, symbol: null, disease_ontology_name: null, disease_ontology_id_version: null, hpo_mode_of_inheritance_term_name: null, hpo_mode_of_inheritance_term: null, ndd_phenotype_word: null, category: null},
          filter_string: '',
          filterOn: [],
          infoModal: {
            id: 'info-modal',
            title: '',
            content: ''
          },
          loading: true,
          isBusy: true
        }
      },
      mounted() {
        // transform input filter string from params to object and assign
        this.filter = this.filterStringToObject(this.filter_input);

        // transform input sort string to object and assign
        let sort_object = this.sortStringToVariables(this.sort_input);
        this.sortBy = sort_object.sortBy;
        this.sortDesc = sort_object.sortDesc;

        this.filtered();

        setTimeout(() => {this.loading = false}, 500);
      },
      watch: {
        sortBy(value) {
          this.handleSortByOrDescChange();
        },
        sortDesc(value) {
          this.handleSortByOrDescChange();
        },
        perPage(value) {
          this.handlePerPageChange();
        }
      },
      methods: {
        copyLinkToClipboard() {
          let urlParam = 'sort=' + this.sort + '&filter=' + this.filter_string + '&page_after=' + this.currentItemID + '&page_size=' + this.perPage;
          navigator.clipboard.writeText(process.env.VUE_APP_URL + this.$route.path + '?' + urlParam);
        },
        handleSortByOrDescChange() {
          this.currentItemID = 0;
          this.sort = ((!this.sortDesc) ? '-' : '+') + this.sortBy;
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
          this.filter_string = this.filterObjectToString(this.filter);
          this.loadGenesData();
        },
        removeFilters() {
          this.filter = {any: null, entity_id: null, symbol: null, disease_ontology_name: null, disease_ontology_id_version: null, hpo_mode_of_inheritance_term_name: null, hpo_mode_of_inheritance_term: null, ndd_phenotype_word: null, category: null};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = null;
          this.filtered();
        },
        async loadGenesData() {
          this.isBusy = true;

          let urlParam = 'sort=' + this.sort + '&filter=' + this.filter_string + '&page_after=' + this.currentItemID + '&page_size=' + this.perPage;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/gene?' + urlParam;

          let curParam = new URLSearchParams(this.$route.query).toString();

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
            this.makeToast(e, 'Error', 'danger');
          }
        },
        normalizer(node) {
          return {
            id: node,
            label: node,
          }
        },
        truncate(str, n){
          return (str.length > n) ? str.substr(0, n-1) + '...' : str;
        }
      }
  }
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
  .input-group>.input-group-prepend {
    flex: 0 0 35%;
  }
  .input-group .input-group-text {
      width: 100%;
  }
</style>