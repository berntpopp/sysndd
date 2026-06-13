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
          UpSet plot of selected curation-list intersections. Each bar shows the gene count unique
          to that intersection; connected dots below show which sources contribute.
        </p>
        <BPopover target="popover-badge-help-upset" variant="info" triggers="focus hover">
          <template #title>Comparisons of Curation Efforts</template>
          UpSet plots show set intersections as connected dots and bars. Sources include SysNDD,
          Radboudumc, SFARI, Gene2Phenotype, PanelApp, Geisinger DBD, Orphanet and OMIM NDD.
        </BPopover>
      </div>
      <DownloadImageButtons :svg-id="'comparisons-upset-svg'" :file-name="'upset_plot'" />
    </header>

    <!-- Source Selection -->
    <div
      v-if="!loadingUpset && columns_list && columns_list.length > 0"
      class="source-selector p-2"
    >
      <div class="source-toolbar d-flex flex-wrap align-items-center gap-2">
        <BDropdown
          variant="outline-primary"
          size="sm"
          :auto-close="false"
          menu-class="source-dropdown-menu"
        >
          <template #button-content>
            <i class="bi bi-plus-circle me-1" />Add Sources
            <BBadge v-if="availableSources.length > 0" variant="secondary" pill class="ms-1">
              {{ availableSources.length }}
            </BBadge>
          </template>
          <div class="px-3 py-2">
            <div class="d-flex justify-content-between align-items-center mb-2">
              <small class="text-muted fw-semibold">Available Sources</small>
              <BButton
                v-if="selected_columns.length < columns_list.length"
                variant="link" size="sm" class="p-0 text-decoration-none"
                @click="selectAllSources"
              >Select All</BButton>
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
          >{{ formatSourceName(source) }}</BFormTag>
        </TransitionGroup>

        <BButton
          v-if="selected_columns.length > 2"
          variant="link" size="sm"
          class="text-muted text-decoration-none p-0 ms-1"
          title="Reset to default selection"
          @click="resetToDefault"
        >
          <i class="bi bi-arrow-counterclockwise" />
        </BButton>

        <span class="separator-line border-start mx-2" />

        <BFormCheckbox v-model="definitiveOnly" switch size="sm" class="definitive-toggle mb-0">
          <span class="small fw-semibold">Definitive Only</span>
        </BFormCheckbox>

        <span class="separator-line border-start mx-2" />

        <!-- Highlight SysNDD toggle with inline count -->
        <BFormCheckbox v-model="highlightSysNDD" switch size="sm" class="highlight-toggle mb-0">
          <span class="small fw-semibold">
            <span class="highlight-dot sysndd-dot" aria-hidden="true" />
            Highlight SysNDD
            <span v-if="sysnddCount !== null" class="legend-count">({{ sysnddCount.toLocaleString() }})</span>
          </span>
        </BFormCheckbox>

        <!-- Highlight Core Overlap toggle with inline count -->
        <BFormCheckbox v-model="highlightCoreOverlap" switch size="sm" class="highlight-toggle mb-0">
          <span class="small fw-semibold">
            <span class="highlight-dot overlap-dot" aria-hidden="true" />
            Core Overlap
            <span v-if="coreOverlapCount !== null" class="legend-count">({{ coreOverlapCount.toLocaleString() }})</span>
          </span>
        </BFormCheckbox>
      </div>

      <small class="text-muted d-block mt-1">
        <i class="bi bi-info-circle me-1" />
        {{ selected_columns.length }} of {{ columns_list.length }} sources selected
        <span v-if="selected_columns.length < 2" class="text-danger ms-1">(minimum 2 required)</span>
        <span v-if="definitiveOnly" class="ms-2" style="color:var(--status-success,#2e7d32)">
          <i class="bi bi-check-circle me-1" />Definitive entries only
        </span>
      </small>
    </div>

    <!-- Content area -->
    <div class="position-relative">
      <!-- Loading skeleton -->
      <div v-if="loadingUpset" class="loading-skeleton" aria-live="polite" aria-busy="true">
        <div class="skeleton-bars">
          <div class="skeleton-bar" style="height:70%" />
          <div class="skeleton-bar" style="height:90%" />
          <div class="skeleton-bar" style="height:55%" />
          <div class="skeleton-bar" style="height:75%" />
          <div class="skeleton-bar" style="height:40%" />
          <div class="skeleton-bar" style="height:60%" />
          <div class="skeleton-bar" style="height:30%" />
        </div>
        <div class="skeleton-dots">
          <div v-for="r in 3" :key="r" class="skeleton-dot-row">
            <div v-for="c in 7" :key="c" class="skeleton-dot" />
          </div>
        </div>
        <span class="visually-hidden">Loading UpSet plot…</span>
      </div>

      <!-- Error state -->
      <div v-else-if="loadError" class="state-card text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color:var(--status-danger,#c62828)" />
        <p class="mb-3 text-muted">{{ loadError }}</p>
        <BButton variant="primary" size="sm" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />Retry
        </BButton>
      </div>

      <!-- Empty state -->
      <div v-else-if="!loadingUpset && elems.length === 0" class="state-card text-center p-4">
        <i class="bi bi-bar-chart fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No intersecting genes found for the selected sources.</p>
        <p class="text-muted small mt-1">Try adding more sources or disabling Definitive Only.</p>
      </div>

      <!-- Chart -->
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
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';

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
  components: { DownloadImageButtons, InlineHelpBadge },
  setup() {
    const upsetContainer = ref(null);
    const { makeToast } = useToast();
    return { upsetContainer, makeToast };
  },
  data() {
    return {
      elems: [],
      columns_list: [],
      selected_columns: [...DEFAULT_SELECTED_SOURCES],
      selection: null,
      loadingUpset: true,
      loadError: null,
      resizeObserver: null,
      definitiveOnly: false,
      highlightSysNDD: true,
      highlightCoreOverlap: true,
      sourceColors: SOURCE_COLORS,
      sysnddHighlightColor: SYSNDD_HIGHLIGHT_COLOR,
      coreOverlapColor: CORE_OVERLAP_COLOR,
      sysnddCount: null,
      coreOverlapCount: null,
    };
  },
  computed: {
    sets() { return extractSets(this.elems); },
    availableSources() {
      if (!this.columns_list) return [];
      return this.normalizeSelectOptions(this.columns_list).filter(
        (opt) => !this.selected_columns.includes(opt.value)
      );
    },
  },
  watch: {
    selected_columns() { setTimeout(() => this.loadComparisonsUpsetData(), 0); },
    definitiveOnly() { setTimeout(() => this.loadComparisonsUpsetData(), 0); },
    highlightSysNDD() { this.$nextTick(() => this.renderUpset()); },
    highlightCoreOverlap() { this.$nextTick(() => this.renderUpset()); },
    sets: { handler() { this.$nextTick(() => this.renderUpset()); }, deep: true },
  },
  mounted() {
    this.loadOptionsData();
    this.$nextTick(() => this.attachResizeObserver());
  },
  beforeUnmount() {
    if (this.resizeObserver) { this.resizeObserver.disconnect(); this.resizeObserver = null; }
    window.removeEventListener('resize', this.renderUpset);
  },
  methods: {
    async loadOptionsData() {
      try {
        const data = await getComparisonsOptions();
        this.columns_list = data.list;
        this.loadComparisonsUpsetData();
      } catch (e) {
        this.loadError = e.message || 'Failed to load source options.';
        this.loadingUpset = false;
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadComparisonsUpsetData() {
      this.loadingUpset = true;
      this.loadError = null;
      try {
        const data = await getUpsetData({
          fields: this.selected_columns.join(),
          definitive_only: this.definitiveOnly.toString(),
        });
        this.elems = data;
      } catch (e) {
        this.loadError = e.message || 'Failed to load UpSet plot data.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingUpset = false;
        this.$nextTick(() => this.renderUpset());
      }
    },
    retryLoad() {
      this.loadError = null;
      this.loadComparisonsUpsetData();
    },
    renderUpset() {
      if (!this.upsetContainer || this.loadingUpset || this.elems.length === 0) return;

      const sets = extractSets(this.elems);
      const dimensions = this.getPlotDimensions();
      const maxH = typeof window !== 'undefined' ? Math.max(300, window.innerHeight - 280) : 560;
      const clampedHeight = Math.min(dimensions.height, maxH);

      const setColors = {};
      sets.forEach((set) => {
        if (this.sourceColors[set.name]) setColors[set.name] = this.sourceColors[set.name];
      });

      const queries = [];
      this.sysnddCount = null;
      this.coreOverlapCount = null;

      if (this.highlightSysNDD) {
        const sysnddSet = sets.find((s) => s.name === 'SysNDD');
        if (sysnddSet) {
          this.sysnddCount = sysnddSet.elems ? sysnddSet.elems.length : null;
          queries.push({ name: 'SysNDD (This Database)', color: this.sysnddHighlightColor, set: sysnddSet });
        }
      }

      if (this.highlightCoreOverlap && sets.length >= 2) {
        const coreGenes = this.elems.filter((elem) => {
          const elemSets = elem.sets || [];
          return this.selected_columns.every((src) => elemSets.includes(src));
        });
        if (coreGenes.length > 0) {
          this.coreOverlapCount = coreGenes.length;
          queries.push({
            name: `Core Overlap (${this.selected_columns.length} sources)`,
            color: this.coreOverlapColor,
            elems: coreGenes,
          });
        }
      }

      render(this.upsetContainer, {
        sets,
        width: dimensions.width,
        height: clampedHeight,
        selection: this.selection,
        theme: 'vega',
        setColors,
        queries: queries.length > 0 ? queries : undefined,
        exportButtons: false,
        barPadding: 0.3,
        dotPadding: 0.7,
        onHover: (s) => { this.selection = s; },
      });
    },
    getPlotDimensions() {
      const cw = this.upsetContainer?.clientWidth || this.upsetContainer?.offsetWidth;
      const vw = typeof window !== 'undefined' ? Math.max(window.innerWidth - 64, 300) : 1400;
      return computeUpsetPlotDimensions(cw, vw);
    },
    attachResizeObserver() {
      if (!this.upsetContainer || typeof ResizeObserver === 'undefined') {
        window.addEventListener('resize', this.renderUpset);
        return;
      }
      this.resizeObserver = new ResizeObserver(() => this.renderUpset());
      this.resizeObserver.observe(this.upsetContainer);
    },
    hover(s) { this.selection = s; },
    normalizeSelectOptions(options) { return normalizeUpsetSelectOptions(options); },
    toggleSource(source) {
      if (this.selected_columns.includes(source)) {
        if (this.selected_columns.length > 2)
          this.selected_columns = this.selected_columns.filter((s) => s !== source);
      } else {
        this.selected_columns = [...this.selected_columns, source];
      }
    },
    removeSource(source) {
      if (this.selected_columns.length > 2)
        this.selected_columns = this.selected_columns.filter((s) => s !== source);
    },
    selectAllSources() {
      this.selected_columns = this.normalizeSelectOptions(this.columns_list).map((opt) => opt.value);
    },
    resetToDefault() { this.selected_columns = [...DEFAULT_SELECTED_SOURCES]; },
    formatSourceName(name) { return formatSourceName(name); },
    getSourceVariant(source) { return getSourceVariant(source); },
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

.panel-heading { min-width: 0; }

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
  overflow: hidden;
  padding: 0.5rem 0;
}

.upset-container :deep(svg) { max-width: 100%; }

.legend-count {
  color: var(--neutral-700, #616161);
  font-weight: 400;
  font-size: 0.8rem;
  font-variant-numeric: tabular-nums;
}

/* Loading skeleton */
.loading-skeleton { padding: 1rem 0.75rem 0.5rem; }

.skeleton-bars {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  padding: 0 1rem;
  height: 140px;
  margin-bottom: 1rem;
}

.skeleton-bar {
  flex: 1;
  background: linear-gradient(90deg, #f0f4f8 25%, #e2e8f0 50%, #f0f4f8 75%);
  background-size: 400% 100%;
  border-radius: 3px 3px 0 0;
  animation: shimmer 1.5s ease-in-out infinite;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-bar { animation: none; background: #f0f4f8; }
}

@keyframes shimmer {
  0% { background-position: 100% 0; }
  100% { background-position: -100% 0; }
}

.skeleton-dots { display: flex; flex-direction: column; gap: 10px; padding: 0 1rem 0.5rem; }
.skeleton-dot-row { display: flex; gap: 6px; }
.skeleton-dot { flex: 1; height: 14px; border-radius: 50%; background: #e2e8f0; }

.state-card {
  min-height: 180px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

/* Source Selector */
.source-selector { background: #f4f7fa; border-bottom: 1px solid #dee2e6; }
.separator-line { height: 24px; }
.source-toolbar { row-gap: 0.4rem !important; }

.source-selector :deep(.btn-sm) {
  --bs-btn-padding-y: 0.18rem;
  --bs-btn-padding-x: 0.45rem;
  --bs-btn-font-size: 0.8125rem;
}

.source-selector :deep(.btn-outline-primary) { border-color: #07509b; background: #fff; color: #063f7a; }
.source-selector :deep(.btn-outline-primary:hover),
.source-selector :deep(.btn-outline-primary:focus) { border-color: #063f7a; background: #eaf3ff; color: #052f5c; }
.source-selector > small { color: #4a5565 !important; }
.source-dropdown-menu { min-width: 220px; max-height: 300px; overflow-y: auto; }

.source-checkbox { cursor: pointer; padding: 0.25rem 0.5rem; border-radius: 0.25rem; transition: background-color 0.15s ease; }
.source-checkbox:hover { background-color: #e9ecef; }

.source-chip {
  min-height: 1.5rem;
  max-height: 1.5rem;
  padding: 0.18rem 0.42rem !important;
  border-radius: 999px;
  font-size: 0.8125rem;
  font-weight: 500;
  line-height: 1;
  transition: all 0.2s ease;
}

@media (prefers-reduced-motion: reduce) { .source-chip { transition: none; } }

.source-chip :deep(.b-form-tag-content) { line-height: 1; }
.source-chip :deep(.b-form-tag-remove) { width: 0.55rem; height: 0.55rem; margin-left: 0.1rem; padding: 0; font-size: 0.55rem; opacity: 0.7; }
.source-chip :deep(.b-form-tag-remove:hover) { opacity: 1; }
.source-chip:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 2px 4px rgba(0,0,0,.1); }

@media (prefers-reduced-motion: reduce) { .source-chip:hover:not(:disabled) { transform: none; } }

/* Toggle styles */
.definitive-toggle :deep(.form-check-input:checked) { background-color: var(--status-success,#2e7d32); border-color: var(--status-success,#2e7d32); }
.highlight-toggle :deep(.form-check-input:checked) { background-color: #0072b2; border-color: #0072b2; }

.highlight-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 4px;
  vertical-align: middle;
  box-shadow: 0 1px 2px rgba(0,0,0,.2);
}

.sysndd-dot { background-color: #0072b2; }
.overlap-dot { background-color: #d55e00; }

/* Chip animation */
.chip-enter-active, .chip-leave-active { transition: all 0.2s ease; }
@media (prefers-reduced-motion: reduce) { .chip-enter-active, .chip-leave-active { transition: none; } }
.chip-enter-from, .chip-leave-to { opacity: 0; transform: scale(0.8); }
.chip-move { transition: transform 0.2s ease; }
@media (prefers-reduced-motion: reduce) { .chip-move { transition: none; } }

@media (max-width: 575.98px) {
  .panel-header { flex-direction: column; align-items: stretch; gap: 0.55rem; padding: 0.7rem; text-align: center; }
  .panel-title { justify-content: center; }
  .source-selector { padding: 0.5rem !important; }
  .source-toolbar { gap: 0.35rem !important; }
  .source-selector :deep(.form-check-label), .source-selector .small { font-size: 0.75rem; }
  .source-selector :deep(.form-switch) { width: auto; }
  .separator-line { display: none; }
  .source-chip { min-height: 1.45rem; max-height: 1.45rem; font-size: 0.75rem; }
}
</style>
