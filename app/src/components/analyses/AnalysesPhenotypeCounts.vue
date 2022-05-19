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
      <h6 class="mb-1 text-left font-weight-bold">Bar plot of phenotype counts.</h6>
    </template>

      <!-- Content -->
      <div id="count_dataviz" class="svg-container"></div>
      <!-- Content -->

    </b-card>
    <!-- User Interface controls -->

  </b-container>

</template>


<script>
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

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

        let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/count';

        try {
          let response = await this.axios.get(apiUrl);

          this.itemsCount = response.data;

          this.generateCountGraph();

        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      },
      generateCountGraph() {

      // set the dimensions and margins of the graph
      const margin = {top: 30, right: 30, bottom: 200, left: 150},
          width = 760 - margin.left - margin.right,
          height = 500 - margin.top - margin.bottom;

      // append the svg object to the body of the page
      const svg = d3.select("#count_dataviz")
        .append("svg")
        .attr("viewBox", `0 0 760 500`)
        .attr("preserveAspectRatio", "xMinYMin meet")
        .append("g")
          .attr("transform", `translate(${margin.left},${margin.top})`);

            // 
            const data = this.itemsCount;

      // X axis
      var x = d3.scaleBand()
        .range([ 0, width ])
        .domain(data.map(function(d) { return d.HPO_term; }))
        .padding(0.2);
      svg.append("g")
        .attr("transform", "translate(0," + height + ")")
        .call(d3.axisBottom(x))
        .selectAll("text")
          .attr("transform", "translate(-10,0)rotate(-45)")
          .style("text-anchor", "end");

      // Add Y axis
      var y = d3.scaleLinear()
        .domain([0, 1000])
        .range([ height, 0]);
      svg.append("g")
        .call(d3.axisLeft(y));

      // Bars
      svg.selectAll("mybar")
        .data(data)
        .enter()
        .append("rect")
          .attr("x", function(d) { return x(d.HPO_term); })
          .attr("y", function(d) { return y(d.count); })
          .attr("width", x.bandwidth())
          .attr("height", function(d) { return height - y(d.count); })
          .attr("fill", "#69b3a2")

      }
    }
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