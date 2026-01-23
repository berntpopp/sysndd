<template>
  <BContainer fluid>
    <!-- User Interface controls -->
    <BCard
      header-tag="header"
      body-class="p-0"
      header-class="p-1"
      border-variant="dark"
    >
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Matrix of
            <mark
              v-b-tooltip.hover.leftbottom
              title="This plot shows the correlation coefficients between various variants."
            >
              variant correlations
            </mark>.
            <BBadge
              id="popover-badge-help-variant"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover
              target="popover-badge-help-variant"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Variant Correlations
              </template>
              This plot displays the Pearson correlation coefficients between different genetic variants.
              The color intensity represents the strength of the correlation:
              <ul>
                <li><strong>Red:</strong> Positive correlation</li>
                <li><strong>Blue:</strong> Negative correlation</li>
                <li><strong>White:</strong> No correlation</li>
              </ul>
              Click on the cells to explore the detailed variant relationships.
            </BPopover>
          </h6>
          <DownloadImageButtons
            :svg-id="'matrix-svg'"
            :file-name="'variant_correlation_matrix'"
          />
        </div>
      </template>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner
          v-if="loadingMatrix"
          label="Loading..."
          class="spinner"
        />
        <div
          v-show="!loadingMatrix"
          id="matrix_dataviz"
          class="svg-container"
        />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import useToast from '@/composables/useToast';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import * as d3 from 'd3';

export default {
  name: 'AnalysesVariantCorrelogram',
  components: {
    DownloadImageButtons,
  },
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      itemsMatrix: [],
      loadingMatrix: true, // Loading state
    };
  },
  mounted() {
    this.loadMatrixData();
  },
  methods: {
    /**
     * Fetches variant correlation data from the API.
     * @async
     * @returns {Promise<void>}
     */
    async loadMatrixData() {
      this.loadingMatrix = true;

      // Point to your variant correlation endpoint
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/variant/correlation`;

      try {
        const response = await this.axios.get(apiUrl);
        this.itemsMatrix = response.data;

        this.generateMatrixGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingMatrix = false; // Set loading to false after data is fetched
      }
    },

    /**
     * Generates the D3.js correlation matrix for variants.
     */
    generateMatrixGraph() {
      // Graph dimension
      const margin = {
        top: 20, right: 50, bottom: 150, left: 220,
      };
      const width = 650 - margin.left - margin.right;
      const height = 620 - margin.top - margin.bottom;

      // Remove any existing SVG
      d3.select('#matrix_dataviz').select('svg').remove();

      // Create the svg area
      const svg = d3
        .select('#matrix_dataviz')
        .append('svg')
        .attr('id', 'matrix-svg') // Added id for easier selection
        .attr('viewBox', '0 0 700 700')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      const data = this.itemsMatrix;

      // List of all variants (x, y)
      const domain = Array.from(new Set(data.map((d) => d.x)));

      // Build X scales and axis
      const x = d3.scaleBand().range([0, width]).domain(domain).padding(0.01);

      svg
        .append('g')
        .attr('transform', `translate(0, ${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .style('text-anchor', 'end')
        .attr('dx', '-.8em')
        .attr('dy', '.15em')
        .attr('transform', 'rotate(-90)');

      // Build Y scales and axis
      const y = d3.scaleBand().range([height, 0]).domain(domain).padding(0.01);

      svg.append('g').call(d3.axisLeft(y));

      // Build color scale
      const myColor = d3.scaleLinear()
        .range(['#000080', '#fff', '#B22222'])
        .domain([-1, 0, 1]);

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
          .html(`R: ${d.value}<br>(${d.x} &<br>${d.y})`)
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
        .append('a')
        .attr(
          'xlink:href',
          (d) => `/Variants/?sort=entity_id&filter=any(category,Definitive),all(modifier_variant_id,${d.x_vario_id},${d.y_vario_id})&page_after=0&page_size=10`,
        ) // Link to a table with both variants
        .attr('aria-label', (d) => `Link to variants table for combination ${d.x_vario_id} and ${d.y_vario_id}`)
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
  max-width: 800px;
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
  margin: 5rem auto;
  display: block;
}
</style>
