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
        </p>
        <BPopover target="popover-badge-help-similarity" variant="info" triggers="focus">
          <template #title>Cosine Similarity Analysis</template>
          Cosine similarity measures the angle between two non-zero vectors. Here it compares
          curation efforts by their gene lists. Values range from -1 for dissimilar to 1 for
          completely similar, with 0 indicating no similarity.
        </BPopover>
      </div>

      <DownloadImageButtons :svg-id="'matrix-svg'" :file-name="'matrix_plot'" />
    </header>

    <div class="matrix-body position-relative">
      <div id="matrix_dataviz" class="svg-container" />
      <div v-show="loadingMatrix" class="loading-state">
        <BSpinner label="Loading..." class="spinner" />
      </div>
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
      loadingMatrix: true, // Added loading state
    };
  },
  mounted() {
    this.loadMatrixData();
  },
  methods: {
    /**
     * Fetches matrix data from the API and triggers graph generation.
     * @async
     * @returns {Promise<void>}
     */
    async loadMatrixData() {
      this.loadingMatrix = true;

      try {
        const data = await getSimilarity();

        this.itemsMatrix = data;
        this.generateGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false; // Set loading to false after data is fetched
      }
    },

    /**
     * Generates the D3.js matrix plot for cosine similarity.
     */
    generateGraph() {
      // Graph dimension
      const margin = {
        top: 0,
        right: 150,
        bottom: 120,
        left: 150,
      };
      const width = 800 - margin.left - margin.right;
      const height = 600 - margin.top - margin.bottom;

      // Remove any existing SVG
      d3.select('#matrix_dataviz').select('svg').remove();

      // Create the svg area
      const svg = d3
        .select('#matrix_dataviz')
        .append('svg')
        .attr('id', 'matrix-svg') // Added id for easier selection
        .attr('viewBox', '0 0 800 600')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // Prepare data
      const data = this.itemsMatrix;

      // List of all variables and number of them
      const domain = Array.from(new Set(data.map((d) => d.x)));

      // Build X scales and axis:
      const x = d3.scaleBand().range([0, width]).domain(domain).padding(0.01);

      svg
        .append('g')
        .attr('transform', `translate(0, ${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.4em')
        .attr('dy', '.5em')
        .attr('transform', 'rotate(-45)')
        .style('font-size', '16px');

      // Build Y scales and axis:
      const y = d3.scaleBand().range([height, 0]).domain(domain).padding(0.01);

      svg.append('g').call(d3.axisLeft(y)).style('font-size', '16px');

      // Build color scale
      const myColor = d3.scaleLinear().range(['#000080', '#fff', '#B22222']).domain([-1, 0, 1]);

      // Create a tooltip
      const tooltip = d3
        .select('#matrix_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid')
        .style('border-width', '1px')
        .style('border-radius', '5px')
        .style('padding', '2px');

      /**
       * Mouseover event handler to display tooltip.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point.
       */
      const mouseover = function mouseover(_event, _d) {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      /**
       * Mousemove event handler to move the tooltip with the mouse.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point.
       */
      const mousemove = function mousemove(event, d) {
        tooltip
          .html(`S(c): ${d.value}<br>(${d.x} &<br>${d.y})`)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      /**
       * Mouseleave event handler to hide the tooltip.
       * @param {Event} event - The event object.
       * @param {Object} d - The data point.
       */
      const mouseleave = function mouseleave(_event, _d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      // Add the squares
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
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);
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
  min-height: 20rem;
  padding: 0.75rem 1rem 1rem;
}

.svg-container {
  display: block;
  position: relative;
  width: 100%;
  max-width: 680px;
  margin: 0 auto;
  overflow: hidden;
}

.svg-content {
  display: inline-block;
  position: absolute;
  top: 0;
  left: 0;
}

.loading-state {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.75);
}

.spinner {
  width: 2rem;
  height: 2rem;
}

@media (max-width: 575.98px) {
  .panel-header {
    flex-direction: column;
    align-items: stretch;
    gap: 0.65rem;
    padding: 0.75rem;
  }

  .matrix-body {
    padding: 0.5rem 0.75rem 0.75rem;
  }
}
</style>
