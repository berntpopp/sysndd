<template>
  <div class="container-fluid">
    <b-container fluid>

      NDD entities since the SysID publication

        <div id="my_dataviz"></div>

    </b-container>
  </div>
</template>


<script>
  import * as d3 from 'd3';

  export default {
  name: 'EntriesOverTime',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entries over time',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'This analysis shows the development of database entries over time for neurodevelopmental disorders curated in SysNDD.' }
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

        let apiUrl = process.env.VUE_APP_API_URL + '/api/statistics/entities_over_time';

        try {
          let response = await this.axios.get(apiUrl);

          this.items = response.data;

          this.generateGraph();

        } catch (e) {
          console.error(e);
        }
      },
      generateGraph() {
      // based on https://d3-graph-gallery.com/graph/connectedscatter_legend.html and https://d3-graph-gallery.com/graph/connectedscatter_tooltip.html

      // set the dimensions and margins of the graph
      const margin = {top: 50, right: 30, bottom: 30, left: 60},
          width = 600 - margin.left - margin.right,
          height = 400 - margin.top - margin.bottom;

      // append the svg object to the body of the page
      const svg = d3.select("#my_dataviz")
        .append("svg")
          .attr("width", width + margin.left + margin.right)
          .attr("height", height + margin.top + margin.bottom)
        .append("g")
          .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

      const data = this.items.map(item => {
              return { 
                category: item.category, 
                values: item.values.map(value => {
                    return { cumulative_count: value.cumulative_count, entry_date: d3.timeParse("%Y-%m-%d")(value.entry_date) };
                  })
              };
            });

      // generate array of all categories
      const allCategories = this.items.map(item => item.category);

      // List of groups (here I have one group per column)
      const allGroup = ["Definitive", "Limited"]

      // A color scale: one color for each group
      const myColor = d3.scaleOrdinal()
        .domain(allCategories)
        .range(d3.schemeSet2);

      // Add X axis --> it is a date format
      const x = d3.scaleTime()
        .domain(d3.extent(data[0].values, d => d.entry_date))
        .range([ 0, width ]);
        svg.append("g")
          .attr("transform", `translate(0,${height})`)
          .call(d3.axisBottom(x));

      // Add Y axis
      const y = d3.scaleLinear()
        .domain([0, d3.max(data[0].values, d => +d.cumulative_count)])
        .range([ height, 0 ]);
        svg.append("g")
          .call(d3.axisLeft(y));

      // Add the lines
      const line = d3.line()
        .x(d => x(+d.entry_date))
        .y(d => y(+d.cumulative_count))
      svg.selectAll("myLines")
        .data(data)
        .join("path")
          .attr("class", d => d.category)
          .attr("d", d => line(d.values))
          .attr("stroke", d => myColor(d.category))
          .style("stroke-width", 4)
          .style("fill", "none")

    // create a tooltip
    const Tooltip = d3.select("#my_dataviz")
      .append("div")
      .style("opacity", 0)
      .attr("class", "tooltip")
      .style("background-color", "white")
      .style("border", "solid")
      .style("border-width", "2px")
      .style("border-radius", "5px")
      .style("padding", "5px")

      // Three function that change the tooltip when user hover / move / leave a cell
      // layerX/Y replaced by clientX/Y
      const mouseover = function(event,d) {
        Tooltip
          .style("opacity", 1)
      }
      const mousemove = function(event,d) {
        Tooltip
          .html("Count: " + d.cumulative_count)
          .style("left", `${event.clientX+10}px`)
          .style("top", `${event.clientY-30}px`)
      }
      const mouseleave = function(event,d) {
        Tooltip
          .style("opacity", 0)
      }

      // Add the points
      svg
        // First we need to enter in a group
        .selectAll("myDots")
        .data(data)
        .join('g')
          .style("fill", d => myColor(d.category))
          .attr("class", d => d.category)
        // Second we need to enter in the 'values' part of this group
        .selectAll("myPoints")
        .data(d => d.values)
        .join("circle")
          .attr("cx", d => x(d.entry_date))
          .attr("cy", d => y(d.cumulative_count))
          .attr("r", 5)
          .attr("stroke", "white")
        .on("mouseover", mouseover)
        .on("mousemove", mousemove)
        .on("mouseleave", mouseleave)

      // Add a legend (interactive)
      svg
        .selectAll("myLegend")
        .data(data)
        .join('g')
          .append("text")
            .attr('x', 30)
            .attr('y', (d,i) => 30 + i*20)
            .text(d => d.category)
            .style("fill", d => myColor(d.category))
            .style("font-size", 15)
          .on("click", function(event,d){
            // is the element currently visible ?
            const currentOpacity = d3.selectAll("." + d.category).style("opacity")
            // Change the opacity: from 0 to 1 or from 1 to 0
            d3.selectAll("." + d.category).transition().style("opacity", currentOpacity == 1 ? 0:1)
          })

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
