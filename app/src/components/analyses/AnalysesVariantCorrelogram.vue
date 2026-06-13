<!-- src/components/analyses/AnalysesVariantCorrelogram.vue -->
<template>
  <AnalysisPanel
    title="Matrix of variant correlations"
    description="Pearson correlation heatmap for observed genetic variant consequence classes. Click a cell to view entities with either variant type."
  >
    <template #actions>
      <InlineHelpBadge id="popover-badge-help-variant" aria-label="Explain variant correlations" />
      <BPopover target="popover-badge-help-variant" variant="info" triggers="focus">
        <template #title> Variant Correlations </template>
        This plot displays the Pearson correlation coefficients between different genetic variant
        consequence classes. Red cells = co-occurring variant types; blue = mutually exclusive.
        Click on cells to view entities with either variant, or hover to see exact correlation
        values.
      </BPopover>
      <DownloadImageButtons :svg-id="'matrix-svg'" :file-name="'variant_correlation_matrix'" />
    </template>

    <div class="position-relative">
      <!-- Loading skeleton -->
      <div v-if="loadingMatrix" class="loading-skeleton" aria-live="polite" aria-busy="true">
        <div class="skeleton-matrix" />
        <span class="visually-hidden">Loading variant correlation matrix…</span>
      </div>

      <!-- Error state (matches phenotype correlogram) -->
      <div v-else-if="loadError" class="state-card error-state text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color: var(--status-danger, #c62828)" />
        <p class="text-muted mb-3">{{ loadError }}</p>
        <BButton variant="primary" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />
          Retry
        </BButton>
      </div>

      <!-- Empty state -->
      <div v-else-if="itemsMatrix.length === 0" class="state-card empty-state text-center p-4">
        <i class="bi bi-grid fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No variant correlation data available.</p>
      </div>

      <!-- Chart + legend -->
      <template v-else>
        <div ref="svgWrapper" class="svg-wrapper">
          <div id="matrix_dataviz" class="svg-container" />
        </div>
        <!-- Caption -->
        <p class="chart-caption">
          Each cell shows the Pearson R between two variant consequence classes.
          Red = co-occurring; blue = mutually exclusive. Click to filter entities.
        </p>
        <!-- Color legend — shared with phenotype correlogram -->
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
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import ColorLegend from '@/components/analyses/ColorLegend.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import * as d3 from 'd3';

// Typed API client (W5)
import { getVariantCorrelation } from '@/api/variant';

/**
 * Get human-readable interpretation of a correlation coefficient
 */
function getCorrelationInterpretation(r) {
  const absR = Math.abs(r);
  const direction = r >= 0 ? 'positive' : 'negative';
  if (absR >= 0.7) return `Strong ${direction} correlation`;
  if (absR >= 0.4) return `Moderate ${direction} correlation`;
  if (absR >= 0.2) return `Weak ${direction} correlation`;
  return 'No significant correlation';
}

export default {
  name: 'AnalysesVariantCorrelogram',
  components: {
    AnalysisPanel,
    DownloadImageButtons,
    InlineHelpBadge,
    ColorLegend,
  },
  setup() {
    const { makeToast } = useToast();
    const svgWrapper = ref(null);
    return { makeToast, svgWrapper };
  },
  data() {
    return {
      itemsMatrix: [],
      loadingMatrix: true,
      loadError: null,
      correlationLabels: [
        { value: -1, text: '-1 (negative)' },
        { value: 0, text: '0' },
        { value: 1, text: '+1 (positive)' },
      ],
    };
  },
  mounted() {
    this.loadMatrixData();
  },
  methods: {
    async loadMatrixData() {
      this.loadingMatrix = true;
      this.loadError = null;

      try {
        const data = await getVariantCorrelation();
        this.itemsMatrix = data;
        this.$nextTick(() => {
          this.generateMatrixGraph();
        });
      } catch (e) {
        this.loadError = e.message || 'Failed to load variant correlation data. Please try again.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false;
      }
    },

    retryLoad() {
      this.loadMatrixData();
    },

    /**
     * Generates the D3.js correlation matrix for variants.
     * Fixes: full-width responsive, enlarged bottom margin so x-axis labels
     * are never truncated, styled tooltip with rounded R values.
     */
    generateMatrixGraph() {
      const wrapper = this.svgWrapper;
      const containerEl = document.getElementById('matrix_dataviz');
      if (!containerEl) return;

      const domain = Array.from(new Set(this.itemsMatrix.map((d) => d.x)));

      // Responsive width: fill the available card width
      const availableWidth = wrapper?.clientWidth || containerEl.parentElement?.clientWidth || 600;

      // Bottom margin must be large enough for fully rotated x-axis labels.
      // Longest variant name is ~30 chars; at 12px, rotated 90deg → ~180px.
      const maxLabelLen = Math.max(...domain.map((d) => d.length));
      const labelFontPx = 12;
      const bottomMargin = Math.min(220, Math.max(120, maxLabelLen * labelFontPx * 0.6));
      const leftMargin = Math.min(220, Math.max(140, maxLabelLen * labelFontPx * 0.55));

      const margin = {
        top: 20,
        right: 20,
        bottom: bottomMargin,
        left: leftMargin,
      };

      const chartSize = Math.max(200, availableWidth - margin.left - margin.right - 24);
      const totalW = chartSize + margin.left + margin.right;
      const totalH = chartSize + margin.top + margin.bottom;

      // Remove any existing SVG + tooltip
      d3.select('#matrix_dataviz').select('svg').remove();
      d3.select('#matrix_dataviz').selectAll('.variant-tooltip').remove();

      const svg = d3
        .select('#matrix_dataviz')
        .append('svg')
        .attr('id', 'matrix-svg')
        .attr('viewBox', `0 0 ${totalW} ${totalH}`)
        .attr('preserveAspectRatio', 'xMidYMid meet')
        .style('width', '100%')
        .style('height', 'auto')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      const data = this.itemsMatrix;

      const x = d3.scaleBand().range([0, chartSize]).domain(domain).padding(0.01);
      const y = d3.scaleBand().range([chartSize, 0]).domain(domain).padding(0.01);

      // X axis (bottom) — rotated 90deg so full labels are visible
      svg
        .append('g')
        .attr('transform', `translate(0, ${chartSize})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.8em')
        .attr('dy', '.15em')
        .attr('transform', 'rotate(-90)')
        .style('font-size', '12px')
        .style('fill', '#27364a');

      // Y axis (left)
      svg
        .append('g')
        .call(d3.axisLeft(y))
        .selectAll('text')
        .style('font-size', '12px')
        .style('fill', '#27364a');

      // Diverging color scale identical to phenotype correlogram
      const myColor = d3.scaleLinear().range(['#000080', '#fff', '#B22222']).domain([-1, 0, 1]);

      // Styled tooltip with rounded values (fixes raw float display)
      const container = containerEl;
      const tooltip = d3
        .select('#matrix_dataviz')
        .append('div')
        .attr('class', 'variant-tooltip')
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

      const mouseover = function mouseover(_event, _d) {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', '#172033').style('stroke-width', 1.5);
      };

      const mousemove = function mousemove(event, d) {
        const containerRect = container.getBoundingClientRect();
        const scrollLeft = window.scrollX || document.documentElement.scrollLeft;
        const scrollTop = window.scrollY || document.documentElement.scrollTop;
        const interpretation = getCorrelationInterpretation(d.value);
        tooltip
          .html(
            `<strong style="font-family:var(--font-family-mono,'ui-monospace',monospace)">R = ${Number(d.value).toFixed(3)}</strong><br>` +
            `<em style="color:#526070">${interpretation}</em><br>` +
            `<small style="color:#6c757d">${d.x}</small><br>` +
            `<small style="color:#6c757d">${d.y}</small>`
          )
          .style('left', `${event.pageX - containerRect.left - scrollLeft + 15}px`)
          .style('top', `${event.pageY - containerRect.top - scrollTop + 15}px`);
      };

      const mouseleave = function mouseleave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      // Add cells with real links
      svg
        .selectAll()
        .data(data, (d) => `${d.x}:${d.y}`)
        .enter()
        .append('a')
        .attr(
          'xlink:href',
          (d) =>
            `/Entities/?sort=entity_id&filter=any(category,Definitive),any(vario_id,${d.x_vario_id},${d.y_vario_id})&page_after=0&page_size=10`
        )
        .attr('aria-label', (d) => `R=${Number(d.value).toFixed(3)}: View entities with ${d.x} or ${d.y} variants`)
        .append('rect')
        .attr('x', (d) => x(d.x))
        .attr('y', (d) => y(d.y))
        .attr('width', x.bandwidth())
        .attr('height', y.bandwidth())
        .style('fill', (d) => myColor(d.value))
        .style('cursor', 'pointer')
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);
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

/* Chart caption */
.chart-caption {
  margin: 0.4rem 0 0;
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
  max-width: 580px;
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

.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
</style>
