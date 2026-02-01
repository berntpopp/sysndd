<!-- src/components/analyses/AnalysesCurationUpset.vue -->
<template>
  <BContainer fluid>
    <!-- User Interface controls -->
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            <mark
              v-b-tooltip.hover.leftbottom
              title="A visualization for set intersections used as an alternative to Venn diagrams. Rows correspond to a set and columns correspond to possible intersections represented by the connected dots."
            >
              Upset plot
            </mark>
            showing the overlap between different selected curation efforts for neurodevelopmental
            disorders.
            <BBadge id="popover-badge-help-upset" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-upset" variant="info" triggers="focus">
              <template #title> Comparisons of Curation Efforts </template>
              The Upset plot visualizes the overlaps between various curation efforts including:
              <br />
              <strong>1) SysNDD</strong>: This curation effort<br />
              <strong>2) Radboudumc ID</strong>: Clinical curation list<br />
              <strong>3) SFARI</strong>: Autism gene curation effort<br />
              <strong>4) Gene2Phenotype</strong>: Gene to phenotype database<br />
              <strong>5) PanelApp</strong>: Gene panels for genetic disorders<br />
              <strong>6) Geisinger DBD</strong>: Developmental disorder curation<br />
            </BPopover>
          </h6>
          <DownloadImageButtons :svg-id="'comparisons-upset-svg'" :file-name="'upset_plot'" />
        </div>
      </template>

      <!-- Source Selection: Dropdown + Chips -->
      <div v-if="!loadingUpset && columns_list && columns_list.length > 0" class="source-selector p-2">
        <div class="d-flex flex-wrap align-items-center gap-2">
          <!-- Dropdown for adding sources -->
          <BDropdown
            variant="outline-primary"
            size="sm"
            :auto-close="false"
            menu-class="source-dropdown-menu"
          >
            <template #button-content>
              <i class="bi bi-plus-circle me-1" />
              Add Sources
              <BBadge v-if="availableSources.length > 0" variant="secondary" pill class="ms-1">
                {{ availableSources.length }}
              </BBadge>
            </template>

            <div class="px-3 py-2">
              <div class="d-flex justify-content-between align-items-center mb-2">
                <small class="text-muted fw-semibold">Available Sources</small>
                <BButton
                  v-if="selected_columns.length < columns_list.length"
                  variant="link"
                  size="sm"
                  class="p-0 text-decoration-none"
                  @click="selectAllSources"
                >
                  Select All
                </BButton>
              </div>

              <div v-if="availableSources.length === 0" class="text-muted small text-center py-2">
                All sources selected
              </div>

              <BFormCheckbox
                v-for="source in normalizeSelectOptions(columns_list)"
                :key="source.value"
                :model-value="selected_columns.includes(source.value)"
                class="source-checkbox mb-1"
                @change="toggleSource(source.value)"
              >
                <span class="small">{{ formatSourceName(source.text) }}</span>
              </BFormCheckbox>
            </div>
          </BDropdown>

          <!-- Selected sources as chips -->
          <TransitionGroup name="chip" tag="div" class="d-flex flex-wrap gap-1">
            <BFormTag
              v-for="source in selected_columns"
              :key="source"
              :variant="getSourceVariant(source)"
              class="source-chip"
              :disabled="selected_columns.length <= 2"
              :title="selected_columns.length <= 2 ? 'Minimum 2 sources required' : `Remove ${formatSourceName(source)}`"
              @remove="removeSource(source)"
            >
              {{ formatSourceName(source) }}
            </BFormTag>
          </TransitionGroup>

          <!-- Clear all button -->
          <BButton
            v-if="selected_columns.length > 2"
            variant="link"
            size="sm"
            class="text-muted text-decoration-none p-0 ms-1"
            title="Reset to default selection"
            @click="resetToDefault"
          >
            <i class="bi bi-arrow-counterclockwise" />
          </BButton>
        </div>

        <!-- Helper text -->
        <small class="text-muted d-block mt-1">
          <i class="bi bi-info-circle me-1" />
          {{ selected_columns.length }} of {{ columns_list.length }} sources selected
          <span v-if="selected_columns.length < 2" class="text-danger ms-1">
            (minimum 2 required)
          </span>
        </small>
      </div>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner v-if="loadingUpset" label="Loading..." class="spinner" />
        <div v-else id="comparisons-upset-svg" ref="upsetContainer" class="upset-container" />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import { ref } from 'vue';
import useToast from '@/composables/useToast';
import { render, extractSets } from '@upsetjs/bundle';
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
          sets: ['SysNDD', 'radboudumc_ID', 'sfari', 'gene2phenotype', 'panelapp', 'geisinger_DBD'],
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
    availableSources() {
      if (!this.columns_list) return [];
      return this.normalizeSelectOptions(this.columns_list)
        .filter((opt) => !this.selected_columns.includes(opt.value));
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
          return {
            value: opt.list || opt.id || opt.value,
            text: opt.list || opt.label || opt.text || opt.id,
          };
        }
        return { value: opt, text: opt };
      });
    },
    // Toggle a source selection
    toggleSource(source) {
      if (this.selected_columns.includes(source)) {
        // Don't allow removing if only 2 left
        if (this.selected_columns.length > 2) {
          this.selected_columns = this.selected_columns.filter((s) => s !== source);
        }
      } else {
        this.selected_columns = [...this.selected_columns, source];
      }
    },
    // Remove a source from selection
    removeSource(source) {
      if (this.selected_columns.length > 2) {
        this.selected_columns = this.selected_columns.filter((s) => s !== source);
      }
    },
    // Select all sources
    selectAllSources() {
      this.selected_columns = this.normalizeSelectOptions(this.columns_list).map((opt) => opt.value);
    },
    // Reset to default selection
    resetToDefault() {
      this.selected_columns = ['SysNDD', 'panelapp', 'gene2phenotype'];
    },
    // Format source name for display (capitalize, replace underscores)
    formatSourceName(name) {
      if (!name) return '';
      // Handle special cases
      const nameMap = {
        SysNDD: 'SysNDD',
        panelapp: 'PanelApp',
        gene2phenotype: 'Gene2Phenotype',
        orphanet_id: 'Orphanet',
        radboudumc_ID: 'Radboudumc',
        sfari: 'SFARI',
        geisinger_DBD: 'Geisinger DBD',
        omim_ndd: 'OMIM NDD',
      };
      return nameMap[name] || name.replace(/_/g, ' ');
    },
    // Get variant color for source chip
    getSourceVariant(source) {
      const variantMap = {
        SysNDD: 'primary',
        panelapp: 'success',
        gene2phenotype: 'info',
        orphanet_id: 'warning',
        radboudumc_ID: 'secondary',
        sfari: 'danger',
        geisinger_DBD: 'dark',
        omim_ndd: 'light',
      };
      return variantMap[source] || 'secondary';
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

/* Source Selector Styles */
.source-selector {
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  border-bottom: 1px solid #dee2e6;
}

.source-dropdown-menu {
  min-width: 220px;
  max-height: 300px;
  overflow-y: auto;
}

.source-checkbox {
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  transition: background-color 0.15s ease;
}

.source-checkbox:hover {
  background-color: #e9ecef;
}

.source-chip {
  font-size: 0.8125rem;
  font-weight: 500;
  transition: all 0.2s ease;
}

.source-chip:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* Chip animation */
.chip-enter-active,
.chip-leave-active {
  transition: all 0.2s ease;
}

.chip-enter-from {
  opacity: 0;
  transform: scale(0.8);
}

.chip-leave-to {
  opacity: 0;
  transform: scale(0.8);
}

.chip-move {
  transition: transform 0.2s ease;
}
</style>
