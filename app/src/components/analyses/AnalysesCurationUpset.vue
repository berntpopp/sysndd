<template>
  <b-spinner
    v-if="loadingUpset"
    label="Loading..."
    class="float-center m-5"
  />
  <b-container
    v-else
    fluid
  >
    <!-- User Interface controls -->
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <h6 class="mb-1 text-left font-weight-bold">
          <mark
            v-b-tooltip.hover.leftbottom
            title="A visualization for set intersections used as alternative to Venn diagrams. Rows corresponds to a set and columns correspond to possible intersections represented by the connected dots."
          >Upset plot</mark>
          showing the overlap between different selected curation effors for
          neurodevelopmental disorders.
        </h6>
      </template>
      <b-row>
        <!-- column 1 -->
        <b-col class="my-1">
          <treeselect
            id="columns-select"
            v-model="selected_columns"
            :multiple="true"
            :options="columns_list"
            :normalizer="normalizeLists"
          />
        </b-col>
      </b-row>
      <!-- User Interface controls -->

      <UpSetJS
        id="comparisons-upset"
        :sets="sets"
        :width="width"
        :height="height"
        :selection="selection"
        :style-factory="customStyleFactory"
        theme="vega"
        @hover="hover"
      />
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

// importUpSetJS
import UpSetJS, { extractSets, createElement } from '@upsetjs/vue';

// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect';
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

export default {
  name: 'AnalysesCurationUpset',
  // register the Treeselect component
  components: { Treeselect, UpSetJS },
  mixins: [toastMixin],
  data() {
    return {
      elems: [
        {
          name: 'AAAS',
          sets: [
            'SysNDD',
            'radboudumc_ID',
            'sfari',
            'gene2phenotype',
            'panelapp',
            'geisinger_DBD',
          ],
        },
      ],
      width: 1400,
      height: 600,
      columns_list: [],
      selected_columns: ['SysNDD', 'panelapp', 'gene2phenotype'],
      selection: null,
      loadingUpset: true,
    };
  },
  computed: {
    sets() {
      return extractSets(this.elems);
    },
  },
  watch: {
    selected_columns() {
      // fixes $ref error in treeselect based on https://github.com/riophae/vue-treeselect/issues/272
      setTimeout(() => {
        this.loadComparisonsUpsetData();
      }, 0);
    },
  },
  mounted() {
    this.loadOptionsData();
  },
  methods: {
    async loadOptionsData() {
      // have to add other options here and normalize the function both here and in the API
      this.loading = true;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/comparisons/options`;
      try {
        const response = await this.axios.get(apiUrl);
        this.columns_list = response.data.list;

        this.loadComparisonsUpsetData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadComparisonsUpsetData() {
      this.loadingUpset = true;

      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/comparisons/upset?fields=${
        this.selected_columns.join()}`;

      try {
        const response = await this.axios.get(apiUrl);
        this.elems = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.loadingUpset = false;
    },
    // add nonce
    // based on https://github.com/upsetjs/upsetjs/pull/98/commits/ac1272b4c7687cbff7363193d3e9464c386db343#:~:text=renderUpSet(rootElement,%7D)%3B
    customStyleFactory(rules) {
      return createElement(
        'style',
        {
          nonce: '3oyp38ny90lxgbgw9g3o4sumkiim4pww',
        },
        rules,
      );
    },
    normalizeLists(node) {
      return {
        id: node.list,
        label: node.list,
      };
    },
    hover(s) {
      this.selection = s;
    },
  },
};
</script>

<style scoped>
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
