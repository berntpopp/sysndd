<!-- src/components/analyses/AnalysesCurationMatrixPlot.vue -->
<template>
  <section class="analysis-panel similarity-panel">
    <header class="panel-header">
      <div class="panel-heading">
        <h2 class="panel-title">
          Similarity
          <InlineHelpBadge
            id="popover-badge-help-similarity"
            aria-label="Explain cosine similarity matrix"
          />
        </h2>
        <p class="panel-description">
          Cosine similarity matrix comparing gene-list overlap between curation efforts.
          Darker teal cells indicate higher gene-list similarity (0 = no overlap, 1 = identical).
        </p>
        <BPopover target="popover-badge-help-similarity" variant="info" triggers="focus">
          <template #title>Cosine Similarity Analysis</template>
          Cosine similarity measures the angle between two gene-membership vectors. Here it compares
          curation efforts by their gene lists. Values range from 0 (no shared genes) to 1 (identical
          gene lists). The diagonal always equals 1 (self-similarity).
        </BPopover>
      </div>

      <DownloadImageButtons :svg-id="'matrix-svg'" :file-name="'matrix_plot'" />
    </header>

    <div class="matrix-body position-relative">
      <!-- Loading skeleton -->
      <div v-if="loadingMatrix" class="loading-state" aria-live="polite" aria-busy="true">
        <BSpinner label="Loading similarity matrix…" class="spinner" />
        <span class="visually-hidden">Loading similarity matrix…</span>
      </div>

      <!-- Error state -->
      <div v-else-if="loadError" class="state-card error-state text-center p-4" role="alert">
        <i class="bi bi-exclamation-triangle-fill fs-2 mb-2 d-block" style="color: var(--status-danger, #c62828)" />
        <p class="mb-3 text-muted">{{ loadError }}</p>
        <BButton variant="primary" size="sm" @click="retryLoad">
          <i class="bi bi-arrow-clockwise me-1" />Retry
        </BButton>
      </div>

      <!-- Empty state -->
      <div v-else-if="!loadingMatrix && itemsMatrix.length === 0" class="state-card empty-state text-center p-4">
        <i class="bi bi-grid fs-2 mb-2 d-block text-muted" />
        <p class="text-muted mb-0">No similarity data available for the current selection.</p>
      </div>

      <!-- Chart + legend -->
      <template v-else>
        <div id="matrix_dataviz" class="svg-container" />
        <!-- Color legend using sequential teal scale matching the chart -->
        <div class="d-flex justify-content-center mt-2 mb-3">
          <div class="color-legend-wrap">
            <div class="color-legend-title">Cosine Similarity</div>
            <div class="color-legend-bar" />
            <div class="color-legend-labels">
              <span>0 (no overlap)</span>
              <span>0.5</span>
              <span>1 (identical)</span>
            </div>
          </div>
        </div>
      </template>
    </div>
  </section>
</template>

<script>
import useToast from '@/composables/useToast';
import * as d3 from 'd3';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import InlineHelpBadge from '@/components/small/InlineHelpBadge.vue';

// Typed API client (W5)
import { getSimilarity } from '@/api/comparisons';

// Sequential scale: white (0) → medical-teal-700 (#00796b) at domain [0,1]
// Cosine similarity over gene-membership vectors is always ≥ 0, so a diverging
// navy/red scale with a negative half is misleading. We use a sequential scale
// anchored to the SysNDD teal token.
const SIMILARITY_COLOR_LOW = '#f0faf8';  // near-white teal tint
const SIMILARITY_COLOR_MID = '#4db6ac';  // teal-400
const SIMILARITY_COLOR_HIGH = '#00695c'; // teal-800 (close to --medical-teal-700)

/** Format source name for axis display — removes underscores */
function formatAxisLabel(name) {
  const MAP = {
    SysNDD: 'SysNDD',
    panelapp: 'PanelApp',
    gene2phenotype: 'Gene2Phenotype',
    orphanet_id: 'Orphanet',
    radboudumc_ID: 'Radboudumc',
    sfari: 'SFARI',
    geisinger_DBD: 'Geisinger DBD',
    omim_ndd: 'OMIM NDD',
  };
  return MAP[name] || name.replace(/_/g, ' ');
}

export default {
  name: 'AnalysesCurationMatrixPlot',
  components: {
    DownloadImageButtons,
    InlineHelpBadge,
  },
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      items: [],
      itemsMatrix: [],
      loadingMatrix: true,
      loadError: null,
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
        const data = await getSimilarity();
        this.itemsMatrix = data;
        this.$nextTick(() => {
          this.generateGraph();
        });
      } catch (e) {
        this.loadError = e.message || 'Failed to load similarity data.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false;
      }
    },

    retryLoad() {
      this.loadMatrixData();
    },

    /**
     * Generates the D3.js matrix plot for cosine similarity.
     * Uses a sequential white→teal scale (0–1) matching the real data range.
     */
    generateGraph() {
      const container = document.getElementById('matrix_dataviz');
      if (!container) return;

      // Responsive: use the container's actual width
      const containerWidth = container.clientWidth || 600;

      // Derive margins from label length to avoid clipping
      const labelPx = 13; // font-size in px
      const maxLabelLen = 12; // chars for longest axis label
      const labelMargin = Math.max(80, maxLabelLen * labelPx * 0.6);

      const margin = {
        top: 8,
        right: 12,
        bottom: labelMargin,
        left: labelMargin,
      };

      // Square chart area
      const chartSize = Math.max(280, containerWidth - margin.left - margin.right);
      const totalW = chartSize + margin.left + margin.right;
      const totalH = chartSize + margin.top + margin.bottom;

      // Remove any existing SVG
      d3.select('#matrix_dataviz').select('svg').remove();
      // Remove any existing tooltip
      d3.select('#matrix_dataviz').selectAll('.matrix-tooltip').remove();

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
      const domain = Array.from(new Set(data.map((d) => d.x)));

      const x = d3.scaleBand().range([0, chartSize]).domain(domain).padding(0.02);
      const y = d3.scaleBand().range([chartSize, 0]).domain(domain).padding(0.02);

      // Sequential teal color scale for [0, 1] — no misleading negative half
      const myColor = d3
        .scaleLinear()
        .range([SIMILARITY_COLOR_LOW, SIMILARITY_COLOR_MID, SIMILARITY_COLOR_HIGH])
        .domain([0, 0.5, 1]);

      // X axis (bottom) — rotated, 13px, formatted labels
      svg
        .append('g')
        .attr('transform', `translate(0, ${chartSize})`)
        .call(
          d3.axisBottom(x).tickFormat((d) => formatAxisLabel(d))
        )
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.5em')
        .attr('dy', '.4em')
        .attr('transform', 'rotate(-45)')
        .style('font-size', '13px')
        .style('fill', '#27364a');

      // Y axis (left) — 13px, formatted labels
      svg
        .append('g')
        .call(
          d3.axisLeft(y).tickFormat((d) => formatAxisLabel(d))
        )
        .selectAll('text')
        .style('font-size', '13px')
        .style('fill', '#27364a');

      // Styled tooltip
      const tooltip = d3
        .select('#matrix_dataviz')
        .append('div')
        .attr('class', 'matrix-tooltip')
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
        const val = typeof d.value === 'number' ? d.value.toFixed(3) : d.value;
        tooltip
          .html(
            `<strong style="font-family:var(--font-family-mono,'ui-monospace',monospace)">S = ${val}</strong><br>` +
            `<span style="color:#526070">${formatAxisLabel(d.x)}</span> &amp; ` +
            `<span style="color:#526070">${formatAxisLabel(d.y)}</span>`
          )
          .style('left', `${event.layerX + 14}px`)
          .style('top', `${event.layerY + 14}px`);
      };

      const mouseleave = function mouseleave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      // Squares
      svg
        .selectAll()
        .data(data, (d) => `${d.x}:${d.y}`)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.x))
        .attr('y', (d) => y(d.y))
        .attr('width', x.bandwidth())
        .attr('height', y.bandwidth())
        .style('fill', (d) => myColor(Math.max(0, Math.min(1, d.value))))
        .attr('aria-label', (d) => `${formatAxisLabel(d.x)} vs ${formatAxisLabel(d.y)}: ${typeof d.value === 'number' ? d.value.toFixed(3) : d.value}`)
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);

      // In-cell value labels for cells above 0.5 similarity (diagonal region)
      const bandW = x.bandwidth();
      if (bandW > 22) {
        svg
          .selectAll('.cell-label')
          .data(data.filter((d) => d.x === d.y))
          .enter()
          .append('text')
          .attr('class', 'cell-label')
          .attr('x', (d) => x(d.x) + bandW / 2)
          .attr('y', (d) => y(d.y) + bandW / 2 + 4)
          .attr('text-anchor', 'middle')
          .style('font-size', '10px')
          .style('fill', '#fff')
          .style('font-weight', '600')
          .style('pointer-events', 'none')
          .text('1.0');
      }
    },
  },
};
</script>

<style scoped>
.analysis-panel {
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
}

.panel-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid #e6ebf2;
  background: #fbfcfe;
}

.panel-heading {
  min-width: 0;
  text-align: left;
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

.matrix-body {
  min-height: 12rem;
  padding: 0.75rem 1rem 0.5rem;
}

/* Responsive: let SVG fill the card */
.svg-container {
  display: block;
  width: 100%;
  max-width: 680px;
  margin: 0 auto;
  overflow: visible;
}

/* Shared state card */
.state-card {
  min-height: 180px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 3rem 0;
}

.spinner {
  width: 2rem;
  height: 2rem;
}

/* Color legend */
.color-legend-wrap {
  display: flex;
  flex-direction: column;
  gap: 3px;
  font-size: 0.75rem;
  width: 220px;
}

.color-legend-title {
  font-weight: 600;
  color: #495057;
  margin-bottom: 2px;
}

.color-legend-bar {
  height: 12px;
  border-radius: 2px;
  border: 1px solid var(--border-subtle, #d9e0ea);
  /* Sequential teal: matches SIMILARITY_COLOR_LOW → MID → HIGH */
  background: linear-gradient(to right, #f0faf8, #4db6ac, #00695c);
}

.color-legend-labels {
  display: flex;
  justify-content: space-between;
  color: #6c757d;
  font-size: 0.7rem;
}

@media (max-width: 575.98px) {
  .panel-header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.65rem;
    padding: 0.75rem;
  }

  .matrix-body {
    padding: 0.5rem 0.5rem 0.75rem;
  }

  .svg-container {
    max-width: 100%;
  }
}
</style>
