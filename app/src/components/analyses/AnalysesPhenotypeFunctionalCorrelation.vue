<!-- src/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue -->
<template>
  <AnalysisPanel
    title="Phenotype & functional clusters correlation"
    description="Heatmap comparing phenotype-derived clusters (pc_) with STRING functional clusters (fc_). Each cell shows the Pearson R between cluster pairs."
  >
    <template #actions>
      <InlineHelpBadge
        id="popover-badge-help-correlations"
        aria-label="Explain phenotype and functional cluster correlation"
      />
      <BPopover target="popover-badge-help-correlations" variant="info" triggers="focus">
        <template #title> Correlation Heatmap Details </template>
        This heatmap displays the Pearson correlation between pairs of clusters:
        <ul>
          <li><strong>pc_#</strong> = Phenotype-based clusters (MCA)</li>
          <li><strong>fc_#</strong> = Functional clusters (STRING)</li>
        </ul>
        A correlation of <strong>+1</strong> indicates strong similarity, whereas
        <strong>-1</strong> implies opposite patterns. The black separator line divides fc_ from
        pc_ clusters. Hover over cells to see exact values.
      </BPopover>
    </template>

    <!-- content with overlay spinner -->
    <div class="position-relative">
      <!-- Loading skeleton -->
      <div v-if="loadingCorrelation" class="loading-skeleton" aria-live="polite" aria-busy="true">
        <div class="skeleton-matrix" />
        <span class="visually-hidden">Loading phenotype-functional correlation…</span>
      </div>

      <!-- Error state -->
      <div v-else-if="loadError" class="state-card error-state text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color: var(--status-danger, #c62828)" />
        <p class="text-muted mb-3">{{ loadError }}</p>
        <BButton variant="primary" size="sm" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />Retry
        </BButton>
      </div>

      <!-- Empty state -->
      <div v-else-if="!loadingCorrelation && correlationMelted.length === 0" class="state-card empty-state text-center p-4">
        <i class="bi bi-grid fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No correlation data available.</p>
      </div>

      <!-- Chart + legend -->
      <template v-else>
        <div ref="svgWrapper" class="svg-wrapper">
          <div id="phenotypeFunctionalCorrelationViz" class="svg-container" />
        </div>

        <!-- Cluster-type legend -->
        <div class="cluster-legend" aria-label="Cluster type key">
          <span class="cluster-legend-item">
            <span class="cluster-badge fc-badge">fc_</span>
            Functional clusters (STRING protein network)
          </span>
          <span class="cluster-legend-item">
            <span class="cluster-badge pc-badge">pc_</span>
            Phenotype clusters (MCA)
          </span>
        </div>

        <!-- Chart caption -->
        <p class="chart-caption">
          Red = positive Pearson R (similar patterns); blue = negative R (opposite patterns).
          The separator line divides fc_ from pc_ clusters.
        </p>

        <!-- Color legend — same diverging scale as sibling correlograms -->
        <div class="d-flex justify-content-center mt-2 mb-3">
          <ColorLegend
            :min="-1"
            :max="1"
            :colors="['#000080', '#fff', '#B22222']"
            title="Correlation Coefficient (R)"
            :labels="correlationLabels"
          />
        </div>
      </template>
    </div>
  </AnalysisPanel>
</template>

<script>
import { ref } from 'vue';
import useToast from '@/composables/useToast';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import ColorLegend from '@/components/analyses/ColorLegend.vue';
import * as d3 from 'd3';

// Typed API client (W5)
import { getPhenotypeFunctionalCorrelation } from '@/api/analysis';

export default {
  name: 'AnalysesPhenotypeFunctionalCorrelation',
  components: { AnalysisPanel, InlineHelpBadge, ColorLegend },
  setup() {
    const { makeToast } = useToast();
    const svgWrapper = ref(null);
    return { makeToast, svgWrapper };
  },
  data() {
    return {
      loadingCorrelation: false,
      loadError: null,
      correlationMatrix: {},
      correlationMelted: [],
      correlationLabels: [
        { value: -1, text: '-1 (negative)' },
        { value: 0, text: '0' },
        { value: 1, text: '+1 (positive)' },
      ],
    };
  },
  mounted() {
    this.loadCorrelationData();
  },
  methods: {
    async loadCorrelationData() {
      this.loadingCorrelation = true;
      this.loadError = null;
      try {
        const data = await getPhenotypeFunctionalCorrelation();
        this.correlationMatrix = data.correlation_matrix;
        this.correlationMelted = data.correlation_melted;
        this.$nextTick(() => {
          this.renderHeatmap();
        });
      } catch (err) {
        this.loadError = err.message || 'Failed to load correlation data. Please try again.';
        this.makeToast(err.message, 'Error fetching correlation data', 'danger');
      } finally {
        this.loadingCorrelation = false;
      }
    },

    retryLoad() {
      this.loadCorrelationData();
    },

    /**
     * Render the D3 heatmap.
     * Changes from original:
     * - Removed the redundant in-chart title (panel h2 serves this role)
     * - Responsive width: fills the card
     * - Color scale: blue→white→red (same tokens as sibling correlograms)
     * - Styled tooltip with rounded R value
     * - 13px axis font matching design token scale
     * - Separator lines use border-subtle color instead of black
     */
    renderHeatmap() {
      const containerEl = document.getElementById('phenotypeFunctionalCorrelationViz');
      if (!containerEl) return;

      d3.select('#phenotypeFunctionalCorrelationViz').select('svg').remove();
      d3.select('#phenotypeFunctionalCorrelationViz').selectAll('.pheno-func-tooltip').remove();

      const availableWidth = this.svgWrapper?.clientWidth || containerEl.parentElement?.clientWidth || 500;

      // Dynamic margins — enough for short cluster labels (fc_1, pc_4 etc.)
      const margin = {
        top: 12,
        right: 16,
        bottom: 64,
        left: 48,
      };

      const chartSize = Math.max(240, availableWidth - margin.left - margin.right - 16);
      const totalW = chartSize + margin.left + margin.right;
      const totalH = chartSize + margin.top + margin.bottom;

      const data = this.correlationMelted;
      const clusterNames = Array.from(
        new Set([...data.map((d) => d.x), ...data.map((d) => d.y)])
      );

      const svg = d3
        .select('#phenotypeFunctionalCorrelationViz')
        .append('svg')
        .attr('id', 'pheno-func-corr-svg')
        .attr('viewBox', `0 0 ${totalW} ${totalH}`)
        .attr('preserveAspectRatio', 'xMidYMid meet')
        .style('width', '100%')
        .style('height', 'auto')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      const x = d3.scaleBand().domain(clusterNames).range([0, chartSize]).padding(0.02);
      const y = d3.scaleBand().domain(clusterNames).range([0, chartSize]).padding(0.02);

      // X-axis (bottom) — 45° rotation, 13px font
      svg
        .append('g')
        .attr('transform', `translate(0, ${chartSize})`)
        .call(d3.axisBottom(x).tickSize(0))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.6em')
        .attr('dy', '.4em')
        .attr('transform', 'rotate(-45)')
        .style('font-size', '13px')
        .style('fill', '#27364a');

      // Y-axis (left) — 13px font
      svg
        .append('g')
        .call(d3.axisLeft(y).tickSize(0))
        .selectAll('text')
        .style('font-size', '13px')
        .style('fill', '#27364a');

      // Diverging blue→white→red: same tokens as phenotype & variant correlograms
      const colorScale = d3
        .scaleLinear()
        .domain([-1, 0, 1])
        .range(['#000080', '#fff', '#B22222']);

      // Styled tooltip with rounded R
      const tooltip = d3
        .select('#phenotypeFunctionalCorrelationViz')
        .append('div')
        .attr('class', 'pheno-func-tooltip')
        .style('opacity', 0)
        .style('position', 'absolute')
        .style('pointer-events', 'none')
        .style('background', '#fff')
        .style('border', '1px solid var(--border-subtle, #d9e0ea)')
        .style('border-radius', '6px')
        .style('padding', '6px 10px')
        .style('font-size', '0.8rem')
        .style('box-shadow', '0 2px 6px rgba(15,23,42,0.10)')
        .style('z-index', '20');

      function handleMouseOver(_event, _d) {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', '#172033').style('stroke-width', 1.5);
      }

      function handleMouseMove(event, d) {
        const [mx, my] = d3.pointer(event);
        tooltip
          .html(
            `<strong style="font-family:var(--font-family-mono,'ui-monospace',monospace)">` +
            `R = ${Number(d.value).toFixed(3)}</strong><br>` +
            `<span style="color:#526070">${d.x}</span> vs <span style="color:#526070">${d.y}</span>`
          )
          .style('left', `${mx + margin.left + 14}px`)
          .style('top', `${my + margin.top}px`);
      }

      function handleMouseLeave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      }

      // Draw cells
      svg
        .selectAll('rect')
        .data(data)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.x))
        .attr('y', (d) => y(d.y))
        .attr('width', x.bandwidth())
        .attr('height', y.bandwidth())
        .style('fill', (d) => colorScale(d.value))
        .attr(
          'aria-label',
          (d) => `R=${Number(d.value).toFixed(3)}: ${d.x} vs ${d.y}`
        )
        .on('mouseover', handleMouseOver)
        .on('mousemove', handleMouseMove)
        .on('mouseleave', handleMouseLeave);

      // Separator lines between fc_ and pc_ quadrants — use border-subtle
      const boundaryIndex = clusterNames.findIndex((d) => d.startsWith('pc_'));
      if (boundaryIndex !== -1) {
        const boundaryX = x(clusterNames[boundaryIndex]);
        const boundaryY = y(clusterNames[boundaryIndex]);
        const SEP_COLOR = '#718096'; // neutral-600 substitute

        svg
          .append('line')
          .attr('x1', boundaryX)
          .attr('x2', boundaryX)
          .attr('y1', 0)
          .attr('y2', chartSize)
          .attr('stroke', SEP_COLOR)
          .attr('stroke-width', 1.5)
          .attr('stroke-dasharray', '4 2');

        svg
          .append('line')
          .attr('y1', boundaryY)
          .attr('y2', boundaryY)
          .attr('x1', 0)
          .attr('x2', chartSize)
          .attr('stroke', SEP_COLOR)
          .attr('stroke-width', 1.5)
          .attr('stroke-dasharray', '4 2');
      }
    },
  },
};
</script>

<style scoped>
.svg-wrapper {
  width: 100%;
  overflow: visible;
}

.svg-container {
  display: block;
  width: 100%;
  overflow: visible;
}

/* Cluster-type legend */
.cluster-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  justify-content: center;
  margin: 0.6rem 0 0.25rem;
  font-size: 0.8rem;
  color: #344054;
}

.cluster-legend-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.cluster-badge {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 4px;
  font-family: var(--font-family-mono, 'ui-monospace', monospace);
  font-size: 0.75rem;
  font-weight: 600;
}

.fc-badge {
  background: #e8f4fd;
  color: var(--medical-blue-700, #0d47a1);
  border: 1px solid #bee3f8;
}

.pc-badge {
  background: #e8f8f5;
  color: var(--medical-teal-700, #00796b);
  border: 1px solid #b2dfdb;
}

/* Chart caption */
.chart-caption {
  margin: 0.25rem 0 0;
  font-size: 0.78rem;
  color: #526070;
  text-align: center;
  line-height: 1.35;
}

/* Loading skeleton */
.loading-skeleton {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1.5rem 0;
}

.skeleton-matrix {
  width: 100%;
  max-width: 460px;
  aspect-ratio: 1;
  background: linear-gradient(135deg, #f0f4f8 25%, #e2e8f0 50%, #f0f4f8 75%);
  background-size: 400% 100%;
  border-radius: 4px;
  animation: shimmer 1.5s ease-in-out infinite;
}

@media (prefers-reduced-motion: reduce) {
  .skeleton-matrix {
    animation: none;
    background: #f0f4f8;
  }
}

@keyframes shimmer {
  0% { background-position: 100% 0; }
  100% { background-position: -100% 0; }
}

/* Shared state card */
.state-card {
  min-height: 180px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.pheno-func-tooltip {
  pointer-events: none;
  z-index: 9999;
}

@media (max-width: 575.98px) {
  .cluster-legend {
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }
}
</style>
