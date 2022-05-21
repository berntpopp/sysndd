<template>
  <b-spinner label="Loading..." v-if="loadingUpset" class="float-center m-5"></b-spinner>
  <b-container fluid v-else>

    <!-- User Interface controls -->
    <b-card 
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
    <template #header>
      <h6 class="mb-1 text-left font-weight-bold">Upset plot showing the overlap between different selected curation effors for neurodevelopmental disorders.</h6>
    </template>
      <b-row>
        <!-- column 1 -->
        <b-col class="my-1">

          <treeselect
            id="columns-select"
            :multiple="true"
            :options="columns_list"
            v-model="selected_columns"
            :normalizer="normalizeLists"
          />

        </b-col>

      </b-row>
    <!-- User Interface controls -->

    <UpSetJS :sets="sets" :width="width" :height="height" @hover="hover" :selection="selection"></UpSetJS>

    </b-card>
  </b-container>
</template>


<script>
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  // importUpSetJS
  import UpSetJS, { extractSets } from '@upsetjs/vue';
  import {createElement} from "@upsetjs/bundle";

  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

  export default {
  // register the Treeselect component
  components: {Treeselect, UpSetJS},
  name: 'AnalysesCurationUpset',
  mixins: [toastMixin],
    data() {
      return {
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
        width: 1400,
        height: 600,
        columns_list: [],
        selected_columns: ['SysNDD', 'panelapp', 'gene2phenotype'],
        selection: null,
        loadingUpset: true,
      };
    },
    watch: {
      selected_columns() {
        // fixes $ref error in treeselect based on https://github.com/riophae/vue-treeselect/issues/272
        setTimeout(() => {
          this.loadComparisonsUpsetData();
        }, 0);
      },
    },
    computed: {
      sets() {
        return extractSets(this.elems);
      },
    },
    mounted() {
      this.loadOptionsData();
    },
    methods: {
        customStyleFactory(rules) {
          return createElement(
            'style',
            {
              extra: 'abc',
            },
            rules
          );
        },
        async loadOptionsData() {
          // have to add other options here and normalize the function both here and in the API
          this.loading = true;

          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/options';
          try {
            let response = await this.axios.get(apiUrl);
            this.columns_list = response.data.list;

            this.loadComparisonsUpsetData();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

        },
        async loadComparisonsUpsetData() {
          this.loadingUpset = true;
          
          let apiUrl = process.env.VUE_APP_API_URL + '/api/comparisons/upset?fields=' + this.selected_columns.join();

          try {
            let response = await this.axios.get(apiUrl);
            this.elems = response.data;

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

          this.loadingUpset = false;

        },
        normalizeLists(node) {
          return {
            id: node.list,
            label: node.list,
          }
        },
        hover(s) {
          this.selection = s;
        },
      }
    };
</script>


<style scoped>

</style>
