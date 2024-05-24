<template>
  <b-container fluid>
    <!-- User Interface controls -->
    <b-card
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-left font-weight-bold">
            Matrix plot of the
            <mark
              v-b-tooltip.hover.leftbottom
              title="This is a measure of similarity between two sequences of numbers used to quantify the similarity between two word lists."
            >cosine similarity</mark>
            between different curation efforts for neurodevelopmental disorders.
          </h6>
          <DownloadImageButtons
            :svg-id="'matrix-svg'"
            :file-name="'matrix_plot'"
          />
        </div>
      </template>
      <b-row>
        <!-- column 1 -->
        <b-col class="my-1" />
        <!-- column 2 -->
        <b-col class="my-1" />
        <!-- column 3 -->
        <b-col class="my-1" />
        <!-- column 4 -->
        <b-col class="my-1" />
      </b-row>
      <!-- User Interface controls -->

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <div
          id="matrix_dataviz"
          class="svg-container"
        />
        <div
          v-show="loadingMatrix"
          class="float-center m-5"
        >
          <b-spinner
            label="Loading..."
            class="spinner"
          />
        </div>
      </div>
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import * as d3 from 'd3';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';

export default {
  name: 'AnalysesCurationMatrixPlot',
  components: {
    DownloadImageButtons,
  },
  mixins: [toastMixin],
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

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/comparisons/similarity`;

      try {
        const response = await this.axios.get(apiUrl);

        this.itemsMatrix = response.data;
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
        top: 0, right: 150, bottom: 120, left: 150,
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
      const mouseover = function mouseover(event, d) {
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
      const mouseleave = function mouseleave(event, d) {
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
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 600px;
  vertical-align: top;
  overflow: hidden;
}
.svg-content {
  display: inline-block;
  position: absolute;
  top: 0;
  left: 0;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
.spinner {
  width: 2rem;
  height: 2rem;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}
</style>
