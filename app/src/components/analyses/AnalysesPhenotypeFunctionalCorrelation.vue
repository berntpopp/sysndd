<!-- src/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue -->
<template>
  <b-container fluid>
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <!-- Header with heading, tooltip, and optional DownloadImageButtons -->
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-left font-weight-bold">
            Phenotype & Functional Clusters
            <mark
              v-b-tooltip.hover.leftbottom
              title="This heatmap shows the pairwise Pearson correlation between clusters derived from phenotype data (MCA) and functional data (STRING), plus optional SFARI genes."
            >
              correlation
            </mark>.
            <b-badge
              id="popover-badge-help-correlations"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>
            <!-- The popover with more details -->
            <b-popover
              target="popover-badge-help-correlations"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Correlation Heatmap Details
              </template>
              This heatmap displays the Pearson correlation between pairs of clusters:
              <ul>
                <li><strong>pc_#</strong> = Phenotype-based clusters (MCA)</li>
                <li><strong>fc_#</strong> = Functional clusters (STRING)</li>
              </ul>
              A correlation of <strong>+1</strong> indicates strong similarity,
              whereas <strong>-1</strong> implies opposite patterns.
              Hover over cells to see exact values.
            </b-popover>
          </h6>

          <!-- Example DownloadImageButtons if you want to capture the SVG -->
          <!--
          <DownloadImageButtons
            :svg-id="'pheno-func-corr-svg'"
            :file-name="'pheno_func_correlation'"
          />
          -->
        </div>
      </template>

      <!-- content with overlay spinner -->
      <div class="position-relative">
        <div
          id="phenotypeFunctionalCorrelationViz"
          class="svg-container"
        />
        <div
          v-show="loadingCorrelation"
          class="m-3 text-center"
        >
          <b-spinner
            label="Loading..."
            class="spinner"
          />
          <p>Loading correlation data...</p>
        </div>
      </div>
    </b-card>
  </b-container>
</template>

<script>
/**
 * @fileoverview Vue component to render a correlation heatmap for phenotype
 * and functional clusters (plus optional SFARI). Demonstrates how to add
 * a tooltip, a popover, and a heading with instructions (similar to
 * AnalysesTimePlot).
 */

import toastMixin from '@/assets/js/mixins/toastMixin';
import * as d3 from 'd3';
// import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue'; // If needed

export default {
  name: 'AnalysesPhenotypeFunctionalCorrelation',
  // components: { DownloadImageButtons }, // If you want the download buttons
  mixins: [toastMixin],
  data() {
    return {
      loadingCorrelation: false,
      correlationMatrix: {}, // if needed
      correlationMelted: [], // array of { x, y, value }
    };
  },
  mounted() {
    this.loadCorrelationData();
  },
  methods: {
    /**
     * Fetch correlation data from the new endpoint
     */
    async loadCorrelationData() {
      this.loadingCorrelation = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/analysis/phenotype_functional_cluster_correlation`;
      try {
        const resp = await this.axios.get(apiUrl);
        this.correlationMatrix = resp.data.correlation_matrix;
        this.correlationMelted = resp.data.correlation_melted;
        this.renderHeatmap();
      } catch (err) {
        this.makeToast(err.message, 'Error fetching correlation data', 'danger');
      } finally {
        this.loadingCorrelation = false;
      }
    },

    /**
     * Render the D3 heatmap
     */
    renderHeatmap() {
      // Clear any old svg
      d3.select('#phenotypeFunctionalCorrelationViz').select('svg').remove();

      // Basic dimensions
      const margin = {
        top: 50, right: 50, bottom: 80, left: 80,
      };
      const width = 400 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // Create SVG
      const svg = d3
        .select('#phenotypeFunctionalCorrelationViz')
        .append('svg')
        .attr('id', 'pheno-func-corr-svg') // For capturing if needed
        .attr('viewBox', `0 0 ${width + margin.left + margin.right} ${height + margin.top + margin.bottom}`)
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // Our melted data
      const data = this.correlationMelted;
      const clusterNames = Array.from(
        new Set([...data.map((d) => d.x), ...data.map((d) => d.y)]),
      );

      // Build scales
      const x = d3
        .scaleBand()
        .domain(clusterNames)
        .range([0, width])
        .padding(0.01);

      const y = d3
        .scaleBand()
        .domain(clusterNames)
        .range([0, height])
        .padding(0.01);

      // X-axis
      svg
        .append('g')
        .attr('transform', `translate(0, ${height})`)
        .call(d3.axisBottom(x).tickSize(0))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.8em')
        .attr('dy', '.15em')
        .attr('transform', 'rotate(-45)');

      // Y-axis
      svg
        .append('g')
        .call(d3.axisLeft(y).tickSize(0));

      // Color scale: -1..+1
      const colorScale = d3
        .scaleLinear()
        .domain([-1, 0, 1])
        .range(['blue', 'white', 'red']);

      // Tooltip
      const tooltip = d3
        .select('#phenotypeFunctionalCorrelationViz')
        .append('div')
        .attr('class', 'tooltip')
        .style('opacity', 0)
        .style('position', 'absolute')
        .style('background-color', 'white')
        .style('border', '1px solid #ccc')
        .style('padding', '5px')
        .style('border-radius', '5px');

      /**
       * Handle mouseover event for each square.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point bound to the rect.
       */
      function handleMouseOver(event, d) {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black');
      }

      /**
       * Handle mousemove event to update the tooltip position and content.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point bound to the rect.
       */
      function handleMouseMove(event, d) {
        const [mx, my] = d3.pointer(event);
        tooltip
          .html(`<strong>${d.x} vs. ${d.y}</strong><br>Corr: ${d.value}`)
          .style('left', `${mx + margin.left + 20}px`)
          .style('top', `${my + margin.top}px`);
      }

      /**
       * Handle mouseleave event to hide the tooltip.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point bound to the rect.
       */
      function handleMouseLeave(event, d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      }

      // Draw the squares
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
        // Named functions for the events:
        .on('mouseover', handleMouseOver)
        .on('mousemove', handleMouseMove)
        .on('mouseleave', handleMouseLeave);

      // Title in the chart area
      svg
        .append('text')
        .attr('x', width / 2)
        .attr('y', -10)
        .attr('text-anchor', 'middle')
        .style('font-weight', 'bold')
        .text('Pheno-Func Cluster Correlation');

      const boundaryIndex = clusterNames.findIndex((d) => d.startsWith('pc_'));
      if (boundaryIndex !== -1) {
        const boundaryX = x(clusterNames[boundaryIndex]);
        const boundaryY = y(clusterNames[boundaryIndex]);
        svg
          .append('line')
          .attr('x1', boundaryX)
          .attr('x2', boundaryX)
          .attr('y1', 0)
          .attr('y2', height)
          .attr('stroke', 'black')
          .attr('stroke-width', 1);
        svg
          .append('line')
          .attr('y1', boundaryY)
          .attr('y2', boundaryY)
          .attr('x1', 0)
          .attr('x2', width)
          .attr('stroke', 'black')
          .attr('stroke-width', 1);
      }
    },
  },
};
</script>

<style scoped>
.svg-container {
  position: relative;
  width: 100%;
  max-width: 600px; /* limit overall max width so it doesn't get too big */
  margin: 0 auto;
  min-height: 400px;
}

.tooltip {
  pointer-events: none;
  z-index: 9999;
}

.spinner {
  width: 2rem;
  height: 2rem;
}
</style>
