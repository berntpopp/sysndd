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
        <h6 class="mb-1 text-left font-weight-bold">
          Matrix plot of the
          <mark
            v-b-tooltip.hover.leftbottom
            title="This is a measure of similarity between two sequences of numbers used to quantify the similarity between two word lists."
          >cosine similarity</mark>
          between different curation effors for neurodevelopmental disorders.
        </h6>
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

      <!-- Content -->
      <div
        id="matrix_dataviz"
        class="svg-container"
      />
      <!-- Content -->
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

import * as d3 from 'd3';

export default {
  name: 'AnalysesCurationMatrixPlot',
  // register the Treeselect component
  components: {},
  mixins: [toastMixin],
  data() {
    return {
      items: [],
      itemsMatrix: [],
      loadingMatrix: true,
    };
  },
  computed: {},
  watch: {},
  mounted() {
    this.loadMatrixData();
  },
  methods: {
    async loadMatrixData() {
      this.loadingMatrix = true;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/comparisons/similarity`;

      try {
        const response = await this.axios.get(apiUrl);

        this.itemsMatrix = response.data;

        this.generateGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.loadingMatrix = false;
    },
    generateGraph() {
      // Graph dimension
      const margin = {
        top: 0, right: 150, bottom: 120, left: 150,
      };
      const width = 800 - margin.left - margin.right;
      const height = 600 - margin.top - margin.bottom;

      // Create the svg area
      const svg = d3
        .select('#matrix_dataviz')
        .append('svg')
        .attr('viewBox', '0 0 800 600')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      //
      const data = this.itemsMatrix;

      // List of all variables and number of them
      const domain = Array.from(
        new Set(
          data.map((d) => d.x),
        ),
      );

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
      const myColor = d3
        .scaleLinear()
        .range(['#000080', '#fff', '#B22222'])
        .domain([-1, 0, 1]);

      // create a tooltip
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

      // Three function that change the tooltip when user hover / move / leave a cell
      const mouseover = function mouseover(event, d) {
        tooltip.style('opacity', 1);

        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      const mousemove = function mousemove(event, d) {
        tooltip
          .html(`S(c): ${d.value}<br>(${d.x} &<br>${d.y})`)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      const mouseleave = function mouseleave(event, d) {
        tooltip.style('opacity', 0);

        d3.select(this).style('stroke', 'none');
      };

      // add the squares
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
</style>
