<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            <b-tab title="Phenotype correlogram" active>
              <b-spinner label="Loading..." v-if="loadingPage" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>

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

                </b-card>
                <!-- User Interface controls -->
              <!-- Content -->
              <div id="matrix_dataviz" class="svg-container"></div>
              <!-- Content -->

              </b-container>

            </b-tab>

            <b-tab title="Phenotype counts">

              <!-- Content -->
              <div id="count_dataviz" class="svg-container"></div>
              <!-- Content -->

            </b-tab>

            <b-tab title="MCA phenotypes & inheritance">
            </b-tab>

          </b-tabs>
          </div>
          
        </b-col>
      </b-row>

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
      itemsMatrix: [],
      itemsCount: [],
      tabIndex: 0,
      loadingPage: false,
      };
    },
    mounted() {
      this.loadMatrixData();
      this.loadCountData();
    },
    methods: {
      async loadMatrixData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/correlation';

        try {
          let response = await this.axios.get(apiUrl);

          this.itemsMatrix = response.data;

          this.generateMatrixGraph();

        } catch (e) {
          console.error(e);
        }
      },
      async loadCountData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/phenotype/count';

        try {
          let response = await this.axios.get(apiUrl);

          this.itemsCount = response.data;

          this.generateCountGraph();

        } catch (e) {
          console.error(e);
        }
      },
      generateMatrixGraph() {
      // Graph dimension
      const margin = {top: 20, right: 50, bottom: 200, left: 220},
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
        .style("border-width", "2px")
        .style("border-radius", "5px")
        .style("padding", "5px");

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
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
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

