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
            <h6 class="mb-1 text-left font-weight-bold">Entities table <b-badge variant="primary" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Entities: {{totalRows}} </b-badge></h6>
          </template>

          <b-row>
            <b-col class="my-1" sm="8">
              <b-form-group
                class="mb-1 border-dark"
              >
                  <b-form-input
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
                  :items="[row.item]"
                  :fields="fields_details"
                  stacked 
                  small
                >
                </b-table>
              </b-card>
            </template>

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

            <template #cell(disease_ontology_name)="data">
              <div class="overflow-hidden text-truncate">
                <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
                  <b-badge 
                  pill 
                  variant="secondary"
                  v-b-tooltip.hover.leftbottom
                  v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                  >
                  {{ data.item.disease_ontology_name }}
                  </b-badge>
                </b-link>
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
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[data.item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="data.item.category"
                >
                </b-avatar>
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
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

export default {
  // register the Treeselect component
  components: { Treeselect },
  name: 'Entities',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entities',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'An expert curated resource of neurodevelopmental disorders.' }
    ]
  },
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "Semidominant inheritance": "SD", "X-linked inheritance, other": "Xo", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "Mit", "Somatic mutation": "Som"},
          items: [],
          fields: [
            { 
              key: 'entity_id', 
              label: 'Entity', 
              sortable: true, 
              filterable: true, 
              sortDirection: 'asc', 
              class: 'text-left' 
            },
            { 
              key: 'symbol', 
              label: 'Symbol', 
              sortable: true, 
              filterable: true, 
              class: 'text-left' 
            },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              filterable: true, 
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              filterable: true, 
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { 
              key: 'category', 
              label: 'Category', 
              sortable: true, 
              filterable: true, 
              class: 'text-left' 
            },
            { 
              key: 'ndd_phenotype_word', 
              label: 'NDD', 
              sortable: true, 
              filterable: true, 
              class: 'text-left'
            },
            { 
              key: 'details', 
              label: 'Details'
            }
          ],
          fields_details: [
            { key: 'hgnc_id', label: 'HGNC ID', class: 'text-left' },
            { key: 'disease_ontology_id_version', label: 'Ontology ID version', class: 'text-left' },
            { key: 'disease_ontology_name', label: 'Disease ontology name', class: 'text-left' },
            { key: 'entry_date', label: 'Entry date', class: 'text-left' },
            { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
          ],
          totalRows: 0,
          currentPage: 1,
          currentItemID: 0,
          prevItemID: null,
          nextItemID: null,
          lastItemID: null,
          executionTime: 0,
          perPage: 10,
          pageOptions: [10, 25, 50, 200],
          sortBy: 'entity_id',
          sortDesc: false,
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
        this.loadEntitiesData();
        setTimeout(() => {this.loading = false}, 500);
      },
      watch: {
        sortBy(value) {
          this.handleSortChange();
        },
        perPage(value) {
          this.handlePerPageChange();
        },
        sortDesc(value) {
          this.handleSortChange();
        }
      },
      methods: {
        handleSortChange() {
          this.currentItemID = 0;
          this.loadEntitiesData();
        },
        handlePerPageChange() {
          this.currentItemID = 0;
          this.loadEntitiesData();
        },
        handlePageChange(value) {
          if (value == 1) {
            this.currentItemID = 0;
            this.loadEntitiesData();
          } else if (value == this.totalPages) {
            this.currentItemID = this.lastItemID;
            this.loadEntitiesData();
          } else if (value > this.currentPage) {
            this.currentItemID = this.nextItemID;
            this.loadEntitiesData();
          } else if (value < this.currentPage) {
            this.currentItemID = this.prevItemID;
            this.loadEntitiesData();
          }
        },
        filtered() {
          // filter the filter object to only contain non null values
          const filter_string_not_empty = Object.filter(this.filter, value => (value !== null && value !== "null" && value !== '' && value.length !== 0));

          // iterate over the filtered non null expressions and join array with regex or "|"
          const filter_string_not_empty_join = {};
          Object.keys(filter_string_not_empty).forEach((key) => {
            if(Array.isArray(filter_string_not_empty[key])) {
              filter_string_not_empty_join[key] = filter_string_not_empty[key].join("|");
            } else {
              filter_string_not_empty_join[key] = filter_string_not_empty[key];
            }
          });

          // compute the filter string by joining the filter object
          if (Object.keys(filter_string_not_empty_join).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty_join).map((key) => [key, filter_string_not_empty_join[key]].join(',')).join('),contains(') + ')';
            this.loadEntitiesData();
          } else {
            this.filter_string = '';
            this.loadEntitiesData();
          }
        },
        removeFilters() {
          this.filter = {any: null, entity_id: null, symbol: null, disease_ontology_name: null, disease_ontology_id_version: null, hpo_mode_of_inheritance_term_name: null, hpo_mode_of_inheritance_term: null, ndd_phenotype_word: null, category: null};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = '';
          this.filtered();
        },
        async loadEntitiesData() {
          this.isBusy = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/entity?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + this.filter_string + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;

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
  .badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space:nowrap;
  }
  .border-dark {
      border: 1;
      border-color: #000;
  }
</style>