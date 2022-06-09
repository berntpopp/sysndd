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
      <h6 class="mb-1 text-left font-weight-bold">Clusters of NDD genes.</h6>
    </template>

    <!-- Content -->
    <div id="cluster_dataviz" class="svg-container"></div>
    <!-- Content -->

    </b-card>
    <!-- User Interface controls -->

  </b-container>

</template>


<script>
  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  import * as d3 from 'd3';

  export default {
  name: 'AnalyseGeneClusters',
  mixins: [toastMixin],
  data() {
    return {
      itemsCluster: [],
      };
    },
    mounted() {
      this.loadClusterData();
    },
    methods: {
      async loadClusterData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/analysis/cluster';

        try {
          let response = await this.axios.get(apiUrl);

          this.itemsCluster = response.data;

          this.generateClusterGraph();

        } catch (e) {
          
        this.makeToast(e, 'Error', 'danger');
        }
      },
      generateClusterGraph() {
      // Graph dimension
      const margin = {top: 50, right: 50, bottom: 50, left: 50},
          width = 800 - margin.left - margin.right,
          height = 600 - margin.top - margin.bottom;

      // Create the svg area
      const svg = d3.select("#cluster_dataviz")
        .append("svg")
          .attr("width", width)
          .attr("height", height)

      // 
      const data = this.itemsCluster;

      // Color palette for continents?
      const color = d3.scaleOrdinal()
        .domain([1, 2, 3, 4, 5, 6])
        .range(d3.schemeSet1);

      // Size scale for countries
      const size = d3.scaleLinear()
        .domain([0, 1000])
        .range([7,55])  // circle will be between 7 and 55 px wide

  // create a tooltip
  const Tooltip = d3.select("#cluster_dataviz")
    .append("div")
    .style("opacity", 0)
    .attr("class", "tooltip")
    .style("background-color", "white")
    .style("border", "solid")
    .style("border-width", "2px")
    .style("border-radius", "5px")
    .style("padding", "5px")

  const mouseover = function(event, d) {
    Tooltip
      .style("opacity", 1);

    d3.select(this)
      .style("stroke-width", 3)
  }

  const mousemove = function(event, d) {
    Tooltip
      .html('<u>Cluster: ' + d.cluster + '</u>' + "<br>" + d.cluster_size + " genes")
          .style("left", `${event.layerX+20}px`)
          .style("top", `${event.layerY+20}px`);
  }

  var mouseleave = function(event, d) {
    Tooltip
      .style("opacity", 0);

    d3.select(this)
      .style("stroke-width", 1);
  }

  // Initialize the circle: all located at the center of the svg area
  var node = svg.append("g")
    .selectAll("circle")
    .data(data)
    .join("circle")
      .attr("class", "node")
      .attr("r", d => size(d.cluster_size))
      .attr("cx", width / 2)
      .attr("cy", height / 2)
      .style("fill", d => color(d.cluster))
      .style("fill-opacity", 0.8)
      .attr("stroke", "black")
      .style("stroke-width", 1)
      .on("mouseover", mouseover) // What to do when hovered
      .on("mousemove", mousemove)
      .on("mouseleave", mouseleave)
      .call(d3.drag() // call specific function when circle is dragged
           .on("start", dragstarted)
           .on("drag", dragged)
           .on("end", dragended));

  // Features of the forces applied to the nodes:
  const simulation = d3.forceSimulation()
      .force("center", d3.forceCenter().x(width / 2).y(height / 2)) // Attraction to the center of the svg area
      .force("charge", d3.forceManyBody().strength(.1)) // Nodes are attracted one each other of value is > 0
      .force("collide", d3.forceCollide().strength(.2).radius(function(d){ return (size(d.cluster_size) + 3) }).iterations(1)) // Force that avoids circle overlapping

  // Apply these forces to the nodes and update their positions.
  // Once the force algorithm is happy with positions ('alpha' value is low enough), simulations will stop.
  simulation
      .nodes(data)
      .on("tick", function(d){
        node
            .attr("cx", d => d.x)
            .attr("cy", d => d.y)
      });

  // What happens when a circle is dragged?
  function dragstarted(event, d) {
    if (!event.active) simulation.alphaTarget(.03).restart();
    d.fx = d.x;
    d.fy = d.y;
  }
  function dragged(event, d) {
    d.fx = event.x;
    d.fy = event.y;
  }
  function dragended(event, d) {
    if (!event.active) simulation.alphaTarget(.03);
    d.fx = null;
    d.fy = null;
  }


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