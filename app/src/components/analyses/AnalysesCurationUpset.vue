<!-- src/components/analyses/AnalysesCurationUpset.vue -->
<template>
  <section class="analysis-panel upset-panel">
    <header class="panel-header">
      <div class="panel-heading">
        <h2 class="panel-title">
          Overlap
          <InlineHelpBadge
            id="popover-badge-help-upset"
            v-b-tooltip.hover.bottom
            aria-label="Explain UpSet plot"
            title="Explain UpSet plot"
          />
        </h2>
        <p class="panel-description">
          UpSet plot of selected curation-list intersections for neurodevelopmental disorders.
        </p>
        <BPopover target="popover-badge-help-upset" variant="info" triggers="focus hover">
          <template #title>Comparisons of Curation Efforts</template>
          UpSet plots show set intersections as connected dots and bars. Sources include SysNDD,
          Radboudumc, SFARI, Gene2Phenotype, PanelApp, Geisinger DBD, Orphanet and OMIM NDD.
        </BPopover>
      </div>
      <DownloadImageButtons :svg-id="'comparisons-upset-svg'" :file-name="'upset_plot'" />
    </header>

    <!-- Source Selection: Dropdown + Chips -->
    <div
      v-if="!loadingUpset && columns_list && columns_list.length > 0"
      class="source-selector p-2"
    >
      <div class="source-toolbar d-flex flex-wrap align-items-center gap-2">
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
            :title="
              selected_columns.length <= 2
                ? 'Minimum 2 sources required'
                : `Remove ${formatSourceName(source)}`
            "
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

        <!-- Separator -->
        <span class="border-start mx-2" style="height: 24px" />

        <!-- Definitive Only toggle -->
        <BFormCheckbox v-model="definitiveOnly" switch size="sm" class="definitive-toggle">
          <span class="small fw-semibold">Definitive Only</span>
        </BFormCheckbox>

        <!-- Separator -->
        <span class="border-start mx-2" style="height: 24px" />

        <!-- Highlight SysNDD toggle -->
        <BFormCheckbox v-model="highlightSysNDD" switch size="sm" class="highlight-toggle">
          <span class="small fw-semibold">
            <span class="highlight-indicator sysndd-indicator" />
            Highlight SysNDD
          </span>
        </BFormCheckbox>

        <!-- Highlight Core Overlap toggle -->
        <BFormCheckbox v-model="highlightCoreOverlap" switch size="sm" class="highlight-toggle">
          <span class="small fw-semibold">
            <span class="highlight-indicator overlap-indicator" />
            Core Overlap
          </span>
        </BFormCheckbox>
      </div>

      <!-- Helper text -->
      <small class="text-muted d-block mt-1">
        <i class="bi bi-info-circle me-1" />
        {{ selected_columns.length }} of {{ columns_list.length }} sources selected
        <span v-if="selected_columns.length < 2" class="text-danger ms-1">
          (minimum 2 required)
        </span>
        <span v-if="definitiveOnly" class="text-success ms-2">
          <i class="bi bi-check-circle me-1" />
          Showing only Definitive entries for each source
        </span>
      </small>
    </div>

    <!-- Content with overlay spinner -->
    <div class="position-relative">
      <BSpinner v-if="loadingUpset" label="Loading..." class="spinner" />
      <div
        v-else
        id="comparisons-upset-svg"
        ref="upsetContainer"
        class="upset-container"
        data-testid="comparisons-upset-plot"
      />
    </div>
  </section>
</template>

<script>
import { ref } from 'vue';
import useToast from '@/composables/useToast';
import { render, extractSets } from '@upsetjs/bundle';
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import Treeselect from '@zanmato/vue3-treeselect';
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';

// Typed API client (W5)
import { getComparisonsOptions, getUpsetData } from '@/api/comparisons';

import {
  SOURCE_COLORS,
  SYSNDD_HIGHLIGHT_COLOR,
  CORE_OVERLAP_COLOR,
  DEFAULT_SELECTED_SOURCES,
  computeUpsetPlotDimensions,
  normalizeUpsetSelectOptions,
  formatSourceName,
  getSourceVariant,
} from './curationUpsetDisplay';

export default {
  name: 'AnalysesCurationUpset',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: { DownloadImageButtons, InlineHelpBadge },
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
      resizeObserver: null,
      definitiveOnly: false,
      highlightSysNDD: true,
      highlightCoreOverlap: true,
      // Color palette + highlight colors (Wong/Okabe-Ito, see curationUpsetDisplay.ts)
      sourceColors: SOURCE_COLORS,
      sysnddHighlightColor: SYSNDD_HIGHLIGHT_COLOR,
      coreOverlapColor: CORE_OVERLAP_COLOR,
    };
  },
  computed: {
    sets() {
      return extractSets(this.elems);
    },
    availableSources() {
      if (!this.columns_list) return [];
      return this.normalizeSelectOptions(this.columns_list).filter(
        (opt) => !this.selected_columns.includes(opt.value)
      );
    },
  },
  watch: {
    selected_columns() {
      setTimeout(() => {
        this.loadComparisonsUpsetData();
      }, 0);
    },
    definitiveOnly() {
      setTimeout(() => {
        this.loadComparisonsUpsetData();
      }, 0);
    },
    highlightSysNDD() {
      this.$nextTick(() => {
        this.renderUpset();
      });
    },
    highlightCoreOverlap() {
      this.$nextTick(() => {
        this.renderUpset();
      });
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
    this.$nextTick(() => {
      this.attachResizeObserver();
    });
  },
  beforeUnmount() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
      this.resizeObserver = null;
    }
    window.removeEventListener('resize', this.renderUpset);
  },
  methods: {
    async loadOptionsData() {
      try {
        const data = await getComparisonsOptions();
        this.columns_list = data.list;
        this.loadComparisonsUpsetData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadComparisonsUpsetData() {
      this.loadingUpset = true;
      try {
        const data = await getUpsetData({
          fields: this.selected_columns.join(),
          definitive_only: this.definitiveOnly.toString(),
        });
        this.elems = data;
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
      const dimensions = this.getPlotDimensions();

      // Build setColors map for coloring individual sets
      const setColors = {};
      sets.forEach((set) => {
        if (this.sourceColors[set.name]) {
          setColors[set.name] = this.sourceColors[set.name];
        }
      });

      // Build queries for highlighting
      const queries = [];

      // Highlight SysNDD set if enabled and present
      if (this.highlightSysNDD) {
        const sysnddSet = sets.find((s) => s.name === 'SysNDD');
        if (sysnddSet) {
          queries.push({
            name: 'SysNDD (This Database)',
            color: this.sysnddHighlightColor,
            set: sysnddSet,
          });
        }
      }

      // Highlight core overlap (intersection of all selected sources) if enabled
      if (this.highlightCoreOverlap && sets.length >= 2) {
        // Find genes that appear in ALL selected sources
        const coreOverlapGenes = this.elems.filter((elem) => {
          // Check if this gene has all selected sources
          const elemSets = elem.sets || [];
          return this.selected_columns.every((source) => elemSets.includes(source));
        });

        if (coreOverlapGenes.length > 0) {
          queries.push({
            name: `Core Overlap (${this.selected_columns.length} sources)`,
            color: this.coreOverlapColor,
            elems: coreOverlapGenes,
          });
        }
      }

      render(this.upsetContainer, {
        sets,
        width: dimensions.width,
        height: dimensions.height,
        selection: this.selection,
        theme: 'vega',
        setColors,
        queries: queries.length > 0 ? queries : undefined,
        exportButtons: false,
        // Enhanced styling
        barPadding: 0.3,
        dotPadding: 0.7,
        onHover: (s) => {
          this.selection = s;
        },
      });
    },
    getPlotDimensions() {
      const containerWidth = this.upsetContainer?.clientWidth || this.upsetContainer?.offsetWidth;
      const viewportWidth =
        typeof window !== 'undefined' ? Math.max(window.innerWidth - 64, 300) : this.width;
      return computeUpsetPlotDimensions(containerWidth, viewportWidth);
    },
    attachResizeObserver() {
      if (!this.upsetContainer) {
        window.addEventListener('resize', this.renderUpset);
        return;
      }

      if (typeof ResizeObserver === 'undefined') {
        window.addEventListener('resize', this.renderUpset);
        return;
      }

      this.resizeObserver = new ResizeObserver(() => {
        this.renderUpset();
      });
      this.resizeObserver.observe(this.upsetContainer);
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
    // Normalize select options for BFormSelect (delegates to the upset helper)
    normalizeSelectOptions(options) {
      return normalizeUpsetSelectOptions(options);
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
      this.selected_columns = this.normalizeSelectOptions(this.columns_list).map(
        (opt) => opt.value
      );
    },
    // Reset to default selection
    resetToDefault() {
      this.selected_columns = [...DEFAULT_SELECTED_SOURCES];
    },
    // Format source name for display (delegates to the upset helper)
    formatSourceName(name) {
      return formatSourceName(name);
    },
    // Get variant color for source chip (delegates to the upset helper)
    getSourceVariant(source) {
      return getSourceVariant(source);
    },
  },
};
</script>

<style scoped>
.analysis-panel {
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  border-radius: 6px;
  background: #fff;
}

.panel-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.75rem 0.85rem;
  border-bottom: 1px solid #e6ebf2;
}

.panel-heading {
  min-width: 0;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin: 0;
  color: #27364a;
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.2;
}

.panel-description {
  margin: 0.25rem 0 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.35;
}

.upset-container {
  display: flex;
  justify-content: center;
  width: 100%;
  min-height: 0;
  overflow: hidden;
  padding: 0.5rem 0;
}

.upset-container :deep(svg) {
  max-width: 100%;
}

.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}

/* Source Selector Styles */
.source-selector {
  background: #f4f7fa;
  border-bottom: 1px solid #dee2e6;
}

.source-toolbar {
  row-gap: 0.4rem !important;
}

.source-selector :deep(.btn-sm) {
  --bs-btn-padding-y: 0.18rem;
  --bs-btn-padding-x: 0.45rem;
  --bs-btn-font-size: 0.8125rem;
}

.source-selector :deep(.btn-outline-primary) {
  border-color: #07509b;
  background: #fff;
  color: #063f7a;
}

.source-selector :deep(.btn-outline-primary:hover),
.source-selector :deep(.btn-outline-primary:focus) {
  border-color: #063f7a;
  background: #eaf3ff;
  color: #052f5c;
}

.source-selector > small {
  color: #4a5565 !important;
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
  min-height: 1.5rem;
  max-height: 1.5rem;
  padding: 0.18rem 0.42rem !important;
  border-radius: 999px;
  font-size: 0.8125rem;
  font-weight: 500;
  line-height: 1;
  gap: 0.25rem;
  transition: all 0.2s ease;
}

.source-chip :deep(.b-form-tag-content) {
  line-height: 1;
}

.source-chip :deep(.b-form-tag-remove) {
  width: 0.55rem;
  height: 0.55rem;
  margin-left: 0.1rem;
  padding: 0;
  font-size: 0.55rem;
  opacity: 0.7;
}

.source-chip :deep(.b-form-tag-remove:hover) {
  opacity: 1;
}

.source-chip:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* Definitive toggle styles */
.definitive-toggle {
  margin-bottom: 0;
}

.definitive-toggle :deep(.form-check-input) {
  cursor: pointer;
}

.definitive-toggle :deep(.form-check-input:checked) {
  background-color: #198754;
  border-color: #198754;
}

/* Highlight toggle styles */
.highlight-toggle {
  margin-bottom: 0;
}

.highlight-toggle :deep(.form-check-input) {
  cursor: pointer;
}

.highlight-toggle :deep(.form-check-input:checked) {
  background-color: #0072b2; /* Okabe-Ito Blue */
  border-color: #0072b2;
}

/* Color indicator dots next to toggle labels */
.highlight-indicator {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 4px;
  vertical-align: middle;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

.sysndd-indicator {
  background-color: #0072b2; /* Okabe-Ito Blue */
}

.overlap-indicator {
  background-color: #d55e00; /* Okabe-Ito Vermilion */
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

@media (max-width: 575.98px) {
  .panel-header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.55rem;
    padding: 0.7rem;
    text-align: center;
  }

  .panel-title {
    justify-content: center;
    font-size: 1rem;
  }

  .panel-description {
    font-size: 0.8125rem;
  }

  .source-selector {
    padding: 0.5rem !important;
  }

  .source-toolbar {
    gap: 0.35rem !important;
  }

  .source-selector :deep(.form-check-label),
  .source-selector .small {
    padding: 0;
    font-size: 0.75rem;
    line-height: 1.1;
  }

  .source-selector :deep(.form-check) {
    min-height: 1.65rem;
    margin-bottom: 0;
    padding-top: 0.1rem;
    padding-bottom: 0.1rem;
  }

  .source-selector :deep(.form-switch) {
    align-items: center;
    width: auto;
    padding-right: 0.35rem;
  }

  .source-selector .border-start {
    display: none;
  }

  .source-chip {
    min-height: 1.45rem;
    max-height: 1.45rem;
    font-size: 0.75rem;
  }

  .upset-container {
    padding-top: 0.25rem;
  }
}
</style>
