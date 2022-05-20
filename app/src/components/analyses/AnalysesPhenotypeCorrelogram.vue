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
      <h6 class="mb-1 text-left font-weight-bold">Matrix of phenotype correlations.</h6>
    </template>

    <!-- Content -->
    <div id="matrix_dataviz" class="svg-container"></div>
    <!-- Content -->

    </b-card>
    <!-- User Interface controls -->

  </b-container>

</template>


<script>
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  import * as d3 from 'd3';

  export default {
  name: 'AnalysesPhenotypeCorrelogram',
  mixins: [toastMixin],
  data() {
    return {
      itemsMatrix: [],
      itemsCount: [],
      };
    },
    mounted() {
      this.loadMatrixData();
    },
    methods: {
      async loadMatrixData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/correlation';

        try {
          let response = await this.axios.get(apiUrl);

          this.itemsMatrix = response.data;

          this.generateMatrixGraph();

        } catch (e) {
          
        this.makeToast(e, 'Error', 'danger');
        }
      },
      generateMatrixGraph() {
      // Graph dimension
      const margin = {top: 20, right: 50, bottom: 150, left: 220},
          width = 650 - margin.left - margin.right,
          height = 620 - margin.top - margin.bottom;

      // Create the svg area
      const svg = d3.select("#matrix_dataviz")
        .append("svg")
        .attr("viewBox", `0 0 700 700`)
        .attr("preserveAspectRatio", "xMinYMin meet")
        .append("g")
          .attr("transform", `translate(${margin.left},${margin.top})`);

      // 
      const data = this.itemsMatrix;

      // List of all variables and number of them
      const domain = Array.from(new Set(data.map(function(d) { return d.x })))

      // Build X scales and axis:
      const x = d3.scaleBand()
        .range([ 0, width ])
        .domain(domain)
        .padding(0.01);

      svg.append("g")
        .attr("transform", `translate(0, ${height})`)
        .call(d3.axisBottom(x))
        .selectAll("text")  
            .style("text-anchor", "end")
            .attr("dx", "-.8em")
            .attr("dy", ".15em")
            .attr("transform", "rotate(-90)" );

      // Build Y scales and axis:
      const y = d3.scaleBand()
        .range([ height, 0 ])
        .domain(domain)
        .padding(0.01);

      svg.append("g")
        .call(d3.axisLeft(y));

      // Build color scale
      const myColor = d3.scaleLinear()
        .range(["#000080", "#fff", "#B22222"])
        .domain([-1, 0, 1]);

      // create a tooltip
      const tooltip = d3.select("#matrix_dataviz")
        .append("div")
        .style("opacity", 0)
        .attr("class", "tooltip")
        .style("background-color", "white")
        .style("border", "solid")
        .style("border-width", "1px")
        .style("border-radius", "5px")
        .style("padding", "2px")

      // Three function that change the tooltip when user hover / move / leave a cell
      const mouseover = function(event,d) {
        tooltip
          .style("opacity", 1)
        d3.select(this)
          .style("stroke", "black")
          .style("opacity", 1);
      }
      const mousemove = function(event,d) {
        tooltip
          .html("R: " + d.value + "<br>(" + d.x + " &<br>" + d.y + ")")
          .style("left", `${event.layerX+20}px`)
          .style("top", `${event.layerY+20}px`)
      }
      const mouseleave = function(event,d) {
        tooltip
          .style("opacity", 0)
        d3.select(this)
          .style("stroke", "none")
          .style("opacity", 0.8);
      }

      // add the squares
      svg.selectAll()
        .data(data, function(d) {return d.x+':'+d.y;})
        .enter()
        .append("rect")
          .attr("x", function(d) { return x(d.x) })
          .attr("y", function(d) { return y(d.y) })
          .attr("width", x.bandwidth() )
          .attr("height", y.bandwidth() )
          .style("fill", function(d) { return myColor(d.value)} )
        .on("mouseover", mouseover)
        .on("mousemove", mousemove)
        .on("mouseleave", mouseleave)

      },
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