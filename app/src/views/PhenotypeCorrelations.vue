<template>
  <div class="container-fluid">
    <b-container fluid>

      Matrix of phenotype correlations

        <div id="my_dataviz"></div>

    </b-container>
  </div>
</template>


<script>
  import * as d3 from 'd3';

  export default {
  name: 'PhenotypeCorrelations',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Phenotype correlations',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Phenotype analysis can be used to compare the correltations between phenotypes and with their associated inheritance patterns in neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability).' }
    ]
  },

  data() {
    return {
      items: [],
      };
    },
    mounted() {
      this.loadData();
    },
    methods: {
      async loadData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/correlation';

        try {
          let response = await this.axios.get(apiUrl);

          this.items = response.data;

          this.generateGraph();

        } catch (e) {
          console.error(e);
        }
      },
      generateGraph() {


// Graph dimension
const margin = {top: 20, right: 20, bottom: 20, left: 20},
    width = 830 - margin.left - margin.right,
    height = 830 - margin.top - margin.bottom

// Create the svg area
const svg = d3.select("#my_dataviz")
  .append("svg")
    .attr("width", width + margin.left + margin.right)
    .attr("height", height + margin.top + margin.bottom)
  .append("g")
    .attr("transform", `translate(${margin.left},${margin.top})`);


  // 
  const data = this.items;

  // List of all variables and number of them
  const domain = Array.from(new Set(data.map(function(d) { return d.x })))

  // Create a color scale
  const color = d3.scaleLinear()
    .domain([-1, 0, 1])
    .range(["#000080", "#fff", "#B22222"]);

  // Create a size scale for bubbles on top right. Watch out: must be a rootscale!
  const size = d3.scaleSqrt()
    .domain([0, 1])
    .range([0, 9]);

  // X scale
  const x = d3.scalePoint()
    .range([0, width])
    .domain(domain)

  // Y scale
  const y = d3.scalePoint()
    .range([0, height])
    .domain(domain)

  // Create one 'g' element for each cell of the correlogram
  const cor = svg.selectAll(".cor")
    .data(data)
    .join("g")
      .attr("class", "cor")
      .attr("transform", function(d) {
        return `translate(${x(d.x)}, ${y(d.y)})`
      });

  // Low left part + Diagonal: Add the text with specific color
  cor
    .filter(function(d){
      const ypos = domain.indexOf(d.y);
      const xpos = domain.indexOf(d.x);
      return xpos <= ypos;
    })
    .append("text")
      .attr("y", 5)
      .text(function(d) {
        if (d.x === d.y) {
          return d.x;
        } else {
          return d.value.toFixed(2);
        }
      })
      .style("font-size", 11)
      .style("text-align", "center")
      .style("fill", function(d){
        if (d.x === d.y) {
          return "#000";
        } else {
          return color(d.value);
        }
      });


  // Up right part: add circles
  cor
    .filter(function(d){
      const ypos = domain.indexOf(d.y);
      const xpos = domain.indexOf(d.x);
      return xpos > ypos;
    })
    .append("circle")
      .attr("r", function(d){ return size(Math.abs(d.value)) })
      .style("fill", function(d){
        if (d.x === d.y) {
          return "#000";
        } else {
          return color(d.value);
        }
      })
      .style("opacity", 0.8)

      }
    }
  };
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>

