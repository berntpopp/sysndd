<!-- src/components/analyses/AnalysesPhenotypeCounts.vue -->
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
            Bar plot of
            <mark
              v-b-tooltip.hover.leftbottom
              title="This plot shows the counts of different phenotypes observed in the data set."
            >phenotype counts</mark>.
            <b-badge
              id="popover-badge-help-phenotype-counts"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>
            <b-popover
              target="popover-badge-help-phenotype-counts"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Phenotype Counts Information
              </template>
              This bar plot displays the counts of different phenotypes observed in the data set.
              The x-axis represents the different phenotypes, and the y-axis shows the count of each phenotype.
            </b-popover>
          </h6>
          <DownloadImageButtons
            :svg-id="'phenotype-svg'"
            :file-name="'phenotype_counts'"
          />
        </div>
      </template>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <b-spinner
          v-if="loadingCount"
          label="Loading..."
          class="spinner"
        />
        <div
          v-show="!loadingCount"
          id="count_dataviz"
          class="svg-container"
        />
      </div>
    </b-card>
    <!-- User Interface controls -->
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import * as d3 from 'd3';

export default {
  name: 'AnalysesPhenotypeCounts',
  components: {
    DownloadImageButtons,
  },
  mixins: [toastMixin],
  data() {
    return {
      itemsCount: [],
      loadingCount: true, // Added loading state
    };
  },
  mounted() {
    this.loadCountData();
  },
  methods: {
    /**
     * Fetches phenotype count data from the API and triggers graph generation.
     * @async
     * @returns {Promise<void>}
     */
    async loadCountData() {
      this.loadingCount = true;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/phenotype/count`;

      try {
        const response = await this.axios.get(apiUrl);

        this.itemsCount = response.data;

        this.generateCountGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingCount = false; // Set loading to false after data is fetched
      }
    },

    /**
     * Generates the D3.js bar plot for phenotype counts.
     */
    generateCountGraph() {
      // Set the dimensions and margins of the graph
      const margin = {
        top: 30, right: 30, bottom: 200, left: 150,
      };
      const width = 760 - margin.left - margin.right;
      const height = 500 - margin.top - margin.bottom;

      // Remove any existing SVG
      d3.select('#count_dataviz').select('svg').remove();

      // Append the SVG object to the body of the page
      const svg = d3
        .select('#count_dataviz')
        .append('svg')
        .attr('id', 'phenotype-svg') // Added id for easier selection
        .attr('viewBox', '0 0 760 500')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // Prepare data
      const data = this.itemsCount;

      // X axis
      const x = d3
        .scaleBand()
        .range([0, width])
        .domain(data.map((d) => d.HPO_term))
        .padding(0.2);

      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .attr('transform', 'translate(-10,0)rotate(-45)')
        .style('text-anchor', 'end')
        .style('font-size', '12px');

      // Add Y axis
      const maxY = d3.max(data, (d) => d.count);
      const y = d3.scaleLinear().domain([0, maxY * 1.1]).range([height, 0]); // Add 10% buffer to the max value
      svg.append('g').call(d3.axisLeft(y));

      // Create a tooltip
      const tooltip = d3
        .select('#count_dataviz')
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
          .html(`Count: ${d.count}<br>(${d.HPO_term})`)
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

      // Bars
      svg
        .selectAll('mybar')
        .data(data)
        .enter()
        .append('a')
        .attr('xlink:href', (d) => `/Phenotypes/?sort=entity_id&filter=any(category,Definitive),all(modifier_phenotype_id,${d.phenotype_id})&page_after=0&page_size=10`) // Add links to the filtered phenotype table to the bars
        .attr('aria-label', (d) => `Link to phenotypes table for ${d.phenotype_id}`)
        .append('rect')
        .attr('x', (d) => x(d.HPO_term))
        .attr('y', (d) => y(d.count))
        .attr('width', x.bandwidth())
        .attr('height', (d) => height - y(d.count))
        .attr('fill', '#69b3a2')
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
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
