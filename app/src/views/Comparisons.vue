<template>
  <div class="container-fluid" style="min-height:90vh">
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
                    v-model="filter"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
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
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
                last-number
              ></b-pagination>
            </b-col>
          </b-row>
          </b-card>
          <!-- User Interface controls -->

              <!-- Main table element -->
              <b-spinner label="Loading..." v-if="loadingTable" class="float-center m-5"></b-spinner>
              <b-table
                :items="items"
                :current-page="currentPage"
                :per-page="perPage"
                :filter="filter"
                :filter-included-fields="filterOn"
                :sort-by.sync="sortBy"
                :sort-desc.sync="sortDesc"
                :sort-direction="sortDirection"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
                v-else
                @filtered="onFiltered"
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
      { charset: 'utf-8' },
      { name: 'description', content: 'The Comparisions analysis can be used to compare different curation efforts for neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, correlation matrix or tabular views.' }
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
        width: 100,
        height: 100,
        items: [],
        totalRows: 0,
        currentPage: 1,
        perPage: 10,
        pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
        sortBy: '',
        sortDesc: false,
        sortDirection: 'asc',
        filter: null,
        filterOn: [],
        selection: null,
        image: '',
        loadingUpset: true,
        loadingMatrix: true,
        loadingTable: true,
        tabIndex: 0
      };
    },
    watch: {
      tabIndex(value) {
        if (value === 2 & this.loadingTable) {
          this.loadTableData();
        } else if (value === 1 & this.loadingMatrix) {
          this.loadMatrixPlot();
        }
      }
    },
    computed: {
      sets() {
        return extractSets(this.elems);
      },
    },
    mounted() {
      this.loadComparisonsUpsetData();
      const bb = this.$el.getBoundingClientRect();
      this.width = bb.width;
      this.height = bb.height;
    },
    methods: {
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
          this.loadingTable = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/table';
          try {
            let response = await this.axios.get(apiUrl);
            this.items = response.data;
            this.totalRows = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loadingTable = false;
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
