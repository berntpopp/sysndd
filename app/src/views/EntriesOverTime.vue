<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">
          <div>
            <b-tab title="Entities over time" active>
              <b-spinner label="Loading..." v-if="loadingPage" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>

                <!-- User Interface controls -->
                <b-card 
                header-tag="header"
                bg-variant="light"
                >
                <template #header>
                  <h6 class="mb-1 text-left font-weight-bold">NDD entities since the SysID publication.</h6>
                </template>
                <b-row>

                  <!-- column 1 -->
                  <b-col class="my-1">
                    <b-input-group
                      prepend="Aggregation"
                      class="mb-1"
                      size="sm"
                    >
                      <b-form-select 
                      @input="loadData"
                      input-id="aggregate-select"
                      v-model="selected_aggregate" 
                      :options="aggregate_list" 
                      text-field="value"
                      size="sm"
                      >
                      </b-form-select>
                    </b-input-group>

                    <b-input-group
                      prepend="Grouping"
                      class="mb-1"
                      size="sm"
                    >
                      <b-form-select 
                      @input="loadData"
                      input-id="group-select"
                      v-model="selected_group" 
                      :options="group_list" 
                      text-field="value"
                      size="sm"
                      >
                      </b-form-select>
                    </b-input-group>
                  </b-col>

                  <!-- column 2 -->
                  <b-col class="my-1">
                  </b-col>

                  <!-- column 3 -->
                  <b-col class="my-1">
                  </b-col>

                  <!-- column 4 -->
                  <b-col class="my-1">
                  </b-col>

                </b-row>

                </b-card>
                <!-- User Interface controls -->

                <!-- Content -->
                <div id="my_dataviz" class="svg-container"></div>
                <!-- Content -->
                
              </b-container>
            </b-tab>
          </div>
          
        </b-col>
      </b-row>

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
      aggregate_list: ["entity_id", "symbol"],
      selected_aggregate: "entity_id",
      group_list: ["category", "inheritance_filter"],
      selected_group: "category",
      items: [],
      itemsMeta: [],
      tabIndex: 0,
      loadingPage: false,
      };
    },
    mounted() {
      this.loadData();
    },
    methods: {
      async loadData() {

        let apiUrl = process.env.VUE_APP_API_URL + '/api/statistics/entities_over_time?aggregate=' + this.selected_aggregate + '&group=' + this.selected_group;

        try {
          let response = await this.axios.get(apiUrl);

          this.items = response.data.data;
          this.itemsMeta = response.data.meta;

          this.generateGraph();

        } catch (e) {
          console.error(e);
        }
      },
      generateGraph() {
      // based on https://d3-graph-gallery.com/graph/connectedscatter_legend.html and https://d3-graph-gallery.com/graph/connectedscatter_tooltip.html
      // resposnsive styling based on https://chartio.com/resources/tutorials/how-to-resize-an-svg-when-the-window-is-resized-in-d3-js/

      // set the dimensions and margins of the graph
      const margin = {top: 50, right: 50, bottom: 50, left: 50},
          width = 600 - margin.left - margin.right,
          height = 400 - margin.top - margin.bottom;

      // first remove svg
      d3.select("svg").remove();

      // append the svg object to the body of the page
      const svg = d3.select("#my_dataviz")
        .append("svg")
        .attr("viewBox", `0 0 600 400`)
        .attr("preserveAspectRatio", "xMinYMin meet")
        .classed("svg-content", true)
        .append("g")
          .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

      const data = this.items.map(item => {
              return { 
                group: item.group, 
                values: item.values.map(value => {
                    return { cumulative_count: value.cumulative_count, entry_date_text: value.entry_date, entry_date: d3.timeParse("%Y-%m-%d")(value.entry_date) };
                  })
              };
            });

      // generate array of all categories
      const allCategories = this.items.map(item => item.group);
      const maxCount = this.itemsMeta[0].max_cumulative_count;

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
        .domain([0, maxCount])
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
          .attr("class", d => d.group)
          .attr("d", d => line(d.values))
          .attr("stroke", d => myColor(d.group))
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
          .html("Count: " + d.cumulative_count + "<br>Date: " + d.entry_date_text)
          .style("left", `${event.layerX+20}px`)
          .style("top", `${event.layerY+20}px`)
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
          .style("fill", d => myColor(d.group))
          .attr("class", d => d.group)
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
            .text(d => d.group)
            .style("fill", d => myColor(d.group))
            .style("font-size", 15)
          .on("click", function(event,d){
            // is the element currently visible ?
            const currentOpacity = d3.selectAll("." + d.group).style("opacity")
            // Change the opacity: from 0 to 1 or from 1 to 0
            d3.selectAll("." + d.group).transition().style("opacity", currentOpacity == 1 ? 0:1)
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
