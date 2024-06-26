<!-- src/components/analyses/AnalysesCurationUpset.vue -->
<template>
  <b-container fluid>
    <!-- User Interface controls -->
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-left font-weight-bold">
            <mark
              v-b-tooltip.hover.leftbottom
              title="A visualization for set intersections used as an alternative to Venn diagrams. Rows correspond to a set and columns correspond to possible intersections represented by the connected dots."
            >
              Upset plot
            </mark>
            showing the overlap between different selected curation efforts for
            neurodevelopmental disorders.
            <b-badge
              id="popover-badge-help-upset"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>
            <b-popover
              target="popover-badge-help-upset"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Comparisons of Curation Efforts
              </template>
              The Upset plot visualizes the overlaps between various curation efforts including:
              <br>
              <strong>1) SysNDD</strong>: This curation effort<br>
              <strong>2) Radboudumc ID</strong>: Clinical curation list<br>
              <strong>3) SFARI</strong>: Autism gene curation effort<br>
              <strong>4) Gene2Phenotype</strong>: Gene to phenotype  database<br>
              <strong>5) PanelApp</strong>: Gene panels for genetic disorders<br>
              <strong>6) Geisinger DBD</strong>: Developmental disorder curation<br>
            </b-popover>
          </h6>
          <DownloadImageButtons
            :svg-id="'comparisons-upset-svg'"
            :file-name="'upset_plot'"
          />
        </div>
      </template>

      <div v-if="!loadingUpset">
        <b-row>
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
      </div>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <b-spinner
          v-if="loadingUpset"
          label="Loading..."
          class="spinner"
        />
        <div v-else>
          <UpSetJS
            id="comparisons-upset-svg"
            :sets="sets"
            :width="width"
            :height="height"
            :selection="selection"
            :style-factory="customStyleFactory"
            theme="vega"
            @hover="hover"
          />
        </div>
      </div>
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import UpSetJS, { extractSets, createElement } from '@upsetjs/vue';
import Treeselect from '@riophae/vue-treeselect';
import '@riophae/vue-treeselect/dist/vue-treeselect.css';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';

export default {
  name: 'AnalysesCurationUpset',
  components: { Treeselect, UpSetJS, DownloadImageButtons },
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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/comparisons/upset?fields=${this.selected_columns.join()}`;
      try {
        const response = await this.axios.get(apiUrl);
        this.elems = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingUpset = false;
      }
    },
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
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 1400px;
  vertical-align: top;
  overflow: hidden;
}
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
</style>
