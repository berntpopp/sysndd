<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            
            <b-tab title="Overlap plot" active>
              <b-spinner label="Loading..." v-if="loadingUpset" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
                <UpSetJS :sets="sets" :width="width" :height="height" @hover="hover" :selection="selection"></UpSetJS>
              </b-container>
            </b-tab>

            <b-tab title="Correlation matrix">
              <b-spinner label="Loading..." v-if="loadingMatrix" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
                <b-img :src="image" fluid alt="Fluid image"></b-img>
              </b-container>
            </b-tab>

            <b-tab title="Table">

          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          >
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
                  >
                  </b-form-input>
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
          </b-card>
          <!-- User Interface controls -->

              <!-- Main table element -->
              <b-spinner label="Loading..." v-if="loadingTable" class="float-center m-5"></b-spinner>
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

              <template #cell(SysNDD)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.SysNDD]"
                  :variant="yn_icon_style[data.item.SysNDD]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.SysNDD"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(radboudumc_ID)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.radboudumc_ID]"
                  :variant="yn_icon_style[data.item.radboudumc_ID]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.radboudumc_ID"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(gene2phenotype)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.gene2phenotype]"
                  :variant="yn_icon_style[data.item.gene2phenotype]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.gene2phenotype"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(panelapp)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.panelapp]"
                  :variant="yn_icon_style[data.item.panelapp]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.panelapp"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(sfari)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.sfari]"
                  :variant="yn_icon_style[data.item.sfari]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.sfari"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(geisinger_DBD)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.geisinger_DBD]"
                  :variant="yn_icon_style[data.item.geisinger_DBD]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.geisinger_DBD"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(omim_ndd)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.omim_ndd]"
                  :variant="yn_icon_style[data.item.omim_ndd]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.omim_ndd"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(orphanet_id)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="yn_icon[data.item.orphanet_id]"
                  :variant="yn_icon_style[data.item.orphanet_id]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.orphanet_id"
                  >
                  </b-avatar>
                </div> 
              </template>

              </b-table>

            </b-tab>
            
          </b-tabs>
          </div>
          
        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
  import UpSetJS, { extractSets, ISets, ISet } from '@upsetjs/vue';

  export default {
  name: 'Comparisions',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Comparisions',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Comparisions analysis can be used to compare different curation efforts for neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, correlation matrix or tabular views.' }
    ]
  },
    components: {
      UpSetJS,
    },
    data() {
      return {
        yn_icon: {"no": "x", "yes": "check"},
        yn_icon_style: {"no": "warning", "yes": "success"},
        elems: [ {
          "name": "AAAS",
          "sets": [
            "SysNDD",
            "radboudumc_ID",
            "sfari",
            "gene2phenotype",
            "panelapp",
            "geisinger_DBD"
          ]
        }],
        width: 1200,
        height: 600,
        items: [],
        fields: [
          { 
            key: 'symbol', 
            label: 'Symbol', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'SysNDD', 
            label: 'SysNDD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'radboudumc_ID', 
            label: 'Radboud UMC ID', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'gene2phenotype', 
            label: 'gene2phenotype', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'panelapp', 
            label: 'PanelApp', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'sfari', 
            label: 'SFARI', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'geisinger_DBD', 
            label: 'Geisinger DBD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'omim_ndd', 
            label: 'OMIM NDD', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
          { 
            key: 'orphanet_id', 
            label: 'Orphanet ID', 
            sortable: true, 
            filterable: true, 
            class: 'text-left' 
          },
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
        filter: {any: ''}, 
        filterOn: [],
        selection: null,
        image: '',
        loadingUpset: true,
        loadingMatrix: true,
        loadingTable: true,
        tabIndex: 0,
        isBusy: true
      };
    },
    watch: {
      tabIndex(value) {
        if (value === 2 & this.loadingTable) {
          this.loadTableData();
          this.loadingTable = false;
        } else if (value === 1 & this.loadingMatrix) {
          this.loadMatrixPlot();
        }
      },
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
    computed: {
      sets() {
        return extractSets(this.elems);
      },
    },
    mounted() {
      this.loadComparisonsUpsetData();
    },
    methods: {
        handleSortChange() {
          this.currentItemID = 0;
          this.loadTableData();
        },
        handlePerPageChange() {
          this.currentItemID = 0;
          this.loadTableData();
        },
        handlePageChange(value) {
          if (value == 1) {
            this.currentItemID = 0;
            this.loadTableData();
          } else if (value == this.totalPages) {
            this.currentItemID = this.lastItemID;
            this.loadTableData();
          } else if (value > this.currentPage) {
            this.currentItemID = this.nextItemID;
            this.loadTableData();
          } else if (value < this.currentPage) {
            this.currentItemID = this.prevItemID;
            this.loadTableData();
          }
        },
        filtered() {
          let filter_string_not_empty = Object.filter(this.filter, value => value !== '');

          if (Object.keys(filter_string_not_empty).length !== 0) {
            this.filter_string = 'contains(' + Object.keys(filter_string_not_empty).map((key) => [key, this.filter[key]].join(',')).join('),contains(') + ')';
            this.loadTableData();
          } else {
            this.filter_string = '';
            this.loadTableData();
          }
        },
        removeFilters() {
          this.filter = {any: '', entity_id: '', symbol: '', disease_ontology_name: '', disease_ontology_id_version: '', hpo_mode_of_inheritance_term_name: '', hpo_mode_of_inheritance_term: '', ndd_phenotype: '', category: ''};
          this.filtered();
        },
        removeSearch() {
          this.filter['any']  = '';
          this.filtered();
        },
        async loadComparisonsUpsetData() {
          this.loadingUpset = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/upset';
          try {
            let response = await this.axios.get(apiUrl);
            this.elems = response.data;
          } catch (e) {
            console.error(e);
          }

          this.loadingUpset = false;

        },
        async loadTableData() {
          this.isBusy = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/table?sort=' + ((this.sortDesc) ? '-' : '+') + this.sortBy + '&filter=' + this.filter_string + '&page[after]=' + this.currentItemID + '&page[size]=' + this.perPage;
          
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
            console.error(e);
          }
        },
        async loadMatrixPlot() {
          this.loadingMatrix = true;

          let apiMatrixPlot = process.env.VUE_APP_API_URL + '/api/comparisons/correlation_plot';

          try {
            let response_entities_plot = await this.axios.get(apiMatrixPlot);
            this.image = 'data:image/png;base64,'.concat(this.image.concat(response_entities_plot.data)) ;
            } catch (e) {
            console.error(e);
            }
          this.loadingMatrix = false;
      },
      hover(s) {
        this.selection = s;
      },
      onFiltered(filteredItems) {
        // Trigger pagination to update the number of buttons/pages due to filtering
        this.totalRows = filteredItems.length
        this.currentPage = 1
      }
      }
    };
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
