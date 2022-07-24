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
          Bar plot of phenotype counts.
        </h6>
      </template>

      <!-- Content -->
      <div
        id="count_dataviz"
        class="svg-container"
      />
      <!-- Content -->
    </b-card>
    <!-- User Interface controls -->
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

import * as d3 from 'd3';

export default {
  name: 'AnalysesPhenotypeCounts',
  mixins: [toastMixin],
  data() {
    return {
      itemsCount: [],
      tabIndex: 0,
    };
  },
  mounted() {
    this.loadCountData();
  },
  methods: {
    async loadCountData() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/phenotype/count`;

      try {
        const response = await this.axios.get(apiUrl);

        this.itemsCount = response.data;

        this.generateCountGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    generateCountGraph() {
      // set the dimensions and margins of the graph
      const margin = {
        top: 30, right: 30, bottom: 200, left: 150,
      };
      const width = 760 - margin.left - margin.right;
      const height = 500 - margin.top - margin.bottom;

      // append the svg object to the body of the page
      const svg = d3
        .select('#count_dataviz')
        .append('svg')
        .attr('viewBox', '0 0 760 500')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // prepare data
      const data = this.itemsCount;

      // X axis
      const x = d3
        .scaleBand()
        .range([0, width])
        .domain(
          data.map((d) => d.HPO_term),
        )
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
      const y = d3.scaleLinear().domain([0, 1000]).range([height, 0]);
      svg.append('g').call(d3.axisLeft(y));

      // create a tooltip
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

      // Three function that change the tooltip when user hover / move / leave a cell
      const mouseover = function mouseover(event, d) {
        tooltip.style('opacity', 1);

        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      const mousemove = function mousemove(event, d) {
        tooltip
          .html(`Count: ${d.count}<br>(${d.HPO_term})`)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

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
        .attr('xlink:href', (d) => `/Phenotypes/?sort=entity_id&filter=any(category,Definitive),all(modifier_phenotype_id,${d.phenotype_id})&page_after=0&page_size=10`) // <- add links to the filtered phenotype table to the bars
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
</style>
