<template>
  <div class="container-fluid" style="min-height:90vh">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="8">

          <div>
          <b-tabs content-class="mt-3">

            <b-tab title="Upset" active>
              <UpSetJS :sets="sets" :width="width" :height="height" @hover="hover" :selection="selection"></UpSetJS>
            </b-tab>

            <b-tab title="Correlation matrix">
              
            </b-tab>

            <b-tab title="Table">
              
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
        selection: null,
      };
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
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/upset';
          try {
            let response = await this.axios.get(apiUrl);
            this.elems = response.data;
          } catch (e) {
            console.error(e);
          }
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
