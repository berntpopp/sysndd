<template>
  <div class="container-fluid" style="min-height:90vh">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="8">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            
            <b-tab title="Upset" active>
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
              
              <!-- Main table element -->
              <b-spinner label="Loading..." v-if="loadingTable" class="float-center m-5"></b-spinner>
              <b-table
                :items="items"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
                v-else
              >

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
    components: {
      UpSetJS,
    },
    data() {
      return {
        elems: [ {
          "name": "AAAS",
          "sets": [
            "SysNDD",
            "radboudumc_ID",
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
      },
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
