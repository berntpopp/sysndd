<!-- src/components/analyses/AnalysesPhenotypeCorrelogram.vue -->
<template>
  <AnalysisPanel
    title="Matrix of phenotype correlations"
    description="Pearson correlation heatmap for curated phenotype co-occurrence patterns. Click a cell to explore entities sharing both phenotypes."
  >
    <template #actions>
      <InlineHelpBadge
        id="popover-badge-help-phenotype"
        aria-label="Explain phenotype correlations"
      />
      <BPopover target="popover-badge-help-phenotype" variant="info" triggers="focus">
        <template #title> Phenotype Correlations </template>
        This plot displays the Pearson correlation coefficients between different phenotypes. The
        color intensity represents the strength of the correlation:
        <ul>
          <li><strong>Red:</strong> Positive correlation</li>
          <li><strong>Blue:</strong> Negative correlation</li>
          <li><strong>White:</strong> No correlation</li>
        </ul>
        Click on the cells to explore the detailed phenotype relationships.
        Use Enter or Space to activate a focused cell.
      </BPopover>
      <DownloadImageButtons :svg-id="'matrix-svg'" :file-name="'phenotype_correlation_matrix'" />
    </template>

    <!-- Content with overlay spinner -->
    <div class="position-relative">
      <!-- Error state with retry -->
      <div v-if="error" class="state-card error-state text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color: var(--status-danger, #c62828)" />
        <p class="text-muted mb-3">
          {{ error }}
        </p>
        <BButton variant="primary" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />
          Retry
        </BButton>
      </div>

      <!-- Loading skeleton -->
      <div v-else-if="loadingMatrix" class="loading-skeleton" aria-live="polite" aria-busy="true">
        <div class="skeleton-matrix" />
        <span class="visually-hidden">Loading phenotype correlation matrix…</span>
      </div>

      <!-- Visualization container -->
      <template v-else-if="itemsMatrix.length > 0">
        <div ref="svgWrapper" class="svg-wrapper">
          <div id="matrix_dataviz" class="svg-container" />
        </div>
        <!-- Caption for non-expert readers -->
        <p class="chart-caption">
          Each cell shows the Pearson R between two phenotype categories.
          Red = co-occurring phenotypes; blue = mutually exclusive patterns. Click a cell to filter entities.
        </p>
        <!-- Color legend -->
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

      <!-- Empty state -->
      <div v-else class="state-card empty-state text-center p-4">
        <i class="bi bi-grid fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No phenotype correlation data available.</p>
      </div>
    </div>
  </AnalysisPanel>
</template>

<script>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import useToast from '@/composables/useToast';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';
import ColorLegend from '@/components/analyses/ColorLegend.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';
import * as d3 from 'd3';

// Typed API client (W5)
import { getPhenotypeCorrelation } from '@/api/phenotype';

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
  name: 'AnalysesPhenotypeCorrelogram',
  components: {
    AnalysisPanel,
    DownloadImageButtons,
    InlineHelpBadge,
    ColorLegend,
  },
  setup() {
    const { makeToast } = useToast();
    const router = useRouter();
    const svgWrapper = ref(null);
    return { makeToast, router, svgWrapper };
  },
  data() {
    return {
      itemsMatrix: [],
      loadingMatrix: true,
      error: null,
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
      this.error = null;

      try {
        const data = await getPhenotypeCorrelation();
        this.itemsMatrix = data;
      } catch (e) {
        this.error = e.message || 'Failed to load correlation data. Please try again.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false;
        this.$nextTick(() => {
          if (this.itemsMatrix.length > 0 && !this.error) {
            this.generateMatrixGraph();
          }
        });
      }
    },
    retryLoad() {
      this.loadMatrixData();
    },
    generateMatrixGraph() {
      const wrapper = this.svgWrapper;
      const containerEl = document.getElementById('matrix_dataviz');
      if (!containerEl) return;

      // Responsive width: fill the card width
      const availableWidth = (wrapper?.clientWidth || containerEl.parentElement?.clientWidth || 600);
      const domain = Array.from(new Set(this.itemsMatrix.map((d) => d.x)));

      // Derive margins based on longest label length
      const maxLabelLen = Math.max(...domain.map((d) => d.length));
      const labelFontPx = 12;
      const labelMargin = Math.min(240, Math.max(120, maxLabelLen * labelFontPx * 0.55));

      const margin = {
        top: 20,
        right: 20,
        bottom: labelMargin,
        left: labelMargin,
      };

      // Square chart area filling available space
      const chartSize = Math.max(200, availableWidth - margin.left - margin.right - 24);
      const totalW = chartSize + margin.left + margin.right;
      const totalH = chartSize + margin.top + margin.bottom;

      // Remove any existing SVG + tooltip
      d3.select('#matrix_dataviz').select('svg').remove();
      d3.select('#matrix_dataviz').selectAll('.corr-tooltip').remove();

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

      // X axis — rotated 90deg
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

      // Y axis
      svg
        .append('g')
        .call(d3.axisLeft(y))
        .selectAll('text')
        .style('font-size', '12px')
        .style('fill', '#27364a');

      // Diverging color scale
      const myColor = d3.scaleLinear().range(['#000080', '#fff', '#B22222']).domain([-1, 0, 1]);

      // Styled tooltip
      const tooltip = d3
        .select('#matrix_dataviz')
        .append('div')
        .attr('class', 'corr-tooltip')
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
        const interpretation = getCorrelationInterpretation(d.value);
        tooltip
          .html(
            `<strong style="font-family:var(--font-family-mono,'ui-monospace',monospace)">R = ${Number(d.value).toFixed(3)}</strong><br>` +
            `<em style="color:#526070">${interpretation}</em><br>` +
            `<small style="color:#6c757d">${d.x} &amp; ${d.y}</small>`
          )
          .style('left', `${event.layerX + 14}px`)
          .style('top', `${event.layerY + 14}px`);
      };

      const mouseleave = function mouseleave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      const router = this.$router;

      // Add cells — keyboard-accessible interactive rects
      svg
        .selectAll()
        .data(data, (d) => `${d.x}:${d.y}`)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.x))
        .attr('y', (d) => y(d.y))
        .attr('width', x.bandwidth())
        .attr('height', y.bandwidth())
        .style('fill', (d) => myColor(d.value))
        .style('cursor', 'pointer')
        .attr('role', 'button')
        .attr('tabindex', '0')
        .attr(
          'aria-label',
          (d) =>
            `R=${Number(d.value).toFixed(3)}: ${d.x} and ${d.y}. Press Enter to view entities.`
        )
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave)
        .on('click', (_event, d) => {
          const filterQuery = `all(modifier_phenotype_id,${d.x_id},${d.y_id})`;
          const url = `/Phenotypes/?sort=entity_id&filter=${filterQuery}&page_after=0&page_size=10`;
          router.push(url);
        })
        .on('keydown', function keydown(event, d) {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            const filterQuery = `all(modifier_phenotype_id,${d.x_id},${d.y_id})`;
            const url = `/Phenotypes/?sort=entity_id&filter=${filterQuery}&page_after=0&page_size=10`;
            router.push(url);
          }
        })
        .on('focus', function focus() {
          d3.select(this)
            .style('stroke', 'var(--medical-blue-700, #0d47a1)')
            .style('stroke-width', 2)
            .style('outline', 'none');
        })
        .on('blur', function blur() {
          d3.select(this).style('stroke', 'none');
        });
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

/* Chart caption — one-liner read guide */
.chart-caption {
  margin: 0.4rem 0 0;
  font-size: 0.78rem;
  color: #526070;
  text-align: center;
  line-height: 1.35;
}

/* Focus outline for keyboard-accessible cells (shown by SVG stroke in JS) */
:deep(rect:focus) {
  outline: none;
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
