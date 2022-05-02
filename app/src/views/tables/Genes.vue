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
            <h6 class="mb-1 text-left font-weight-bold">Genes table <b-badge variant="success" v-b-tooltip.hover.bottom v-bind:title="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime">Genes: {{totalRows}} </b-badge></h6>
          </template>

          <b-row>
            <b-col class="my-1">
              <b-form-group
                class="mb-1"
              >
                <b-input-group
                prepend="Search"
                size="sm">
                  <b-form-input
                    id="filter-input"
                    v-model="filter['any']"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
                    @click="removeFilters()"
                    @update="filtered()"
                  ></b-form-input>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col class="my-1">
            </b-col>

            <b-col class="my-1">
            </b-col>

            <b-col class="my-1">
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

            <template #cell(actions)="row">
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }} Details
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
                      class="justify-content-md-center" 
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
                class="justify-content-md-center mx-0"
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
                class="mx-0"
                v-for="item in data.item.entities" 
                :key="item.category + item.entity_id"
                :variant="stoplights_style[item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="item.category"
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

export default {
  name: 'Genes',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Genes',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Genes table view allows browsing NDD associations by gene.' }
    ]
  },
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance": "X", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "M", "Somatic mutation": "S", "Semidominant mode of inheritance": "sD"},
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
            { key: 'actions', label: 'Actions' }
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
          currentItemID: 0,
          prevItemID: null,
          nextItemID: null,
          lastItemID: null,
          executionTime: 0,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: 'symbol',
          sortDesc: false,
          filter: {any: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype_word: '', category: ''}, 
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
        // Set the initial number of items
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
          let filter_string_not_empty = Object.filter(this.filter, value => value !== '');

          if (Object.keys(filter_string_not_empty).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty).map((key) => [key, this.filter[key]].join(',')).join('),contains(') + ')';
            this.loadEntitiesData();
          } else {
            this.filter_string = '';
            this.loadEntitiesData();
          }
        },
        removeFilters() {
          this.filter = {any: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype_word: '', category: ''};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = '';
          this.filtered();
        },
        async loadEntitiesData() {
          this.isBusy = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/gene?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + this.filter_string + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;

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

              this.isBusy = false;

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
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