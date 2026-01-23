<!-- src/components/analyses/AnalysesCurationUpset.vue -->
<template>
  <BContainer fluid>
    <!-- User Interface controls -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            <mark
              v-b-tooltip.hover.leftbottom
              title="A visualization for set intersections used as an alternative to Venn diagrams. Rows correspond to a set and columns correspond to possible intersections represented by the connected dots."
            >
              Upset plot
            </mark>
            showing the overlap between different selected curation efforts for
            neurodevelopmental disorders.
            <BBadge
              id="popover-badge-help-upset"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
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
            </BPopover>
          </h6>
          <DownloadImageButtons
            :svg-id="'comparisons-upset-svg'"
            :file-name="'upset_plot'"
          />
        </div>
      </template>

      <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
      <div v-if="!loadingUpset && columns_list && columns_list.length > 0">
        <BRow>
          <BCol class="my-1">
            <BFormSelect
              id="columns-select"
              v-model="selected_columns"
              :options="normalizeSelectOptions(columns_list)"
              multiple
              :select-size="4"
            />
          </BCol>
        </BRow>
      </div>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner
          v-if="loadingUpset"
          label="Loading..."
          class="spinner"
        />
        <div
          v-else
          id="comparisons-upset-svg"
          ref="upsetContainer"
          class="upset-container"
        />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import {
  ref,
  onMounted,
  watch,
  nextTick,
} from 'vue';
import useToast from '@/composables/useToast';
import { render, extractSets, UpSetDarkTheme } from '@upsetjs/bundle';
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import Treeselect from '@zanmato/vue3-treeselect';
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';

export default {
  name: 'AnalysesCurationUpset',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: { DownloadImageButtons },
  setup() {
    const upsetContainer = ref(null);
    const { makeToast } = useToast();
    return { upsetContainer, makeToast };
  },
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
    sets: {
      handler() {
        this.$nextTick(() => {
          this.renderUpset();
        });
      },
      deep: true,
    },
  },
  mounted() {
    this.loadOptionsData();
  },
  methods: {
    async loadOptionsData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/comparisons/options`;
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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/comparisons/upset?fields=${this.selected_columns.join()}`;
      try {
        const response = await this.axios.get(apiUrl);
        this.elems = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingUpset = false;
        this.$nextTick(() => {
          this.renderUpset();
        });
      }
    },
    renderUpset() {
      if (!this.upsetContainer || this.loadingUpset) {
        return;
      }

      const sets = extractSets(this.elems);

      render(this.upsetContainer, {
        sets,
        width: this.width,
        height: this.height,
        selection: this.selection,
        theme: 'vega',
        onHover: (s) => {
          this.selection = s;
        },
      });
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
    // Normalize select options for BFormSelect (replacement for treeselect normalizer)
    normalizeSelectOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => {
        if (typeof opt === 'object' && opt !== null) {
          return { value: opt.list || opt.id || opt.value, text: opt.list || opt.label || opt.text || opt.id };
        }
        return { value: opt, text: opt };
      });
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
.upset-container {
  width: 100%;
  min-height: 600px;
}
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
</style>
