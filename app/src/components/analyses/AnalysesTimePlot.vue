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
          NDD entities since the SysID publication.
        </h6>
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
              v-model="selected_aggregate"
              input-id="aggregate-select"
              :options="aggregate_list"
              text-field="value"
              size="sm"
              @input="loadData"
            />
          </b-input-group>

          <b-input-group
            prepend="Grouping"
            class="mb-1"
            size="sm"
          >
            <b-form-select
              v-model="selected_group"
              input-id="group-select"
              :options="group_list"
              text-field="value"
              size="sm"
              @input="loadData"
            />
          </b-input-group>
        </b-col>
      </b-row>
      <!-- User Interface controls -->

      <!-- Content -->
      <div
        id="my_dataviz"
        class="svg-container"
      />
      <!-- Content -->
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from "@/assets/js/mixins/toastMixin.js";

import * as d3 from "d3";

export default {
  name: "AnalysesTimePlot",
  mixins: [toastMixin],
  data() {
    return {
      aggregate_list: ["entity_id", "symbol"],
      selected_aggregate: "entity_id",
      group_list: ["category", "inheritance_filter", "inheritance_multiple"],
      selected_group: "category",
      items: [],
      itemsMeta: [],
    };
  },
  mounted() {
    this.loadData();
  },
  methods: {
    async loadData() {
      let apiUrl =
        process.env.VUE_APP_API_URL +
        "/api/statistics/entities_over_time?aggregate=" +
        this.selected_aggregate +
        "&group=" +
        this.selected_group;

      try {
        let response = await this.axios.get(apiUrl);

        this.items = response.data.data;
        this.itemsMeta = response.data.meta;

        this.generateGraph();
      } catch (e) {
        this.makeToast(e, "Error", "danger");
      }
    },
    generateGraph() {
      // based on https://d3-graph-gallery.com/graph/connectedscatter_legend.html and https://d3-graph-gallery.com/graph/connectedscatter_tooltip.html
      // resposnsive styling based on https://chartio.com/resources/tutorials/how-to-resize-an-svg-when-the-window-is-resized-in-d3-js/

      // set the dimensions and margins of the graph
      const margin = { top: 50, right: 50, bottom: 50, left: 50 },
        width = 600 - margin.left - margin.right,
        height = 400 - margin.top - margin.bottom;

      // first remove svg
      d3.select("#my_dataviz").select("svg").remove();

      // append the svg object to the body of the page
      const svg = d3
        .select("#my_dataviz")
        .append("svg")
        .attr("viewBox", `0 0 600 400`)
        .attr("preserveAspectRatio", "xMinYMin meet")
        .classed("svg-content", true)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      const data = this.items.map((item) => {
        return {
          group: item.group,
          values: item.values.map((value) => {
            return {
              group: item.group,
              cumulative_count: value.cumulative_count,
              entry_date_text: value.entry_date,
              entry_date: d3.timeParse("%Y-%m-%d")(value.entry_date),
            };
          }),
        };
      });

      // generate array of all categories
      const allCategories = this.items.map((item) => item.group);
      const maxCount = this.itemsMeta[0].max_cumulative_count;

      // A color scale: one color for each group
      const myColor = d3
        .scaleOrdinal()
        .domain(allCategories)
        .range(d3.schemeSet2);

      // Add X axis --> it is a date format
      const x = d3
        .scaleTime()
        .domain(d3.extent(data[0].values, (d) => d.entry_date))
        .range([0, width]);

      svg
        .append("g")
        .attr("transform", `translate(0,${height})`)
        .call(d3.axisBottom(x));

      // Add Y axis
      const y = d3.
        scaleLinear().
        domain([0, maxCount]).
        range([height, 0]);

      svg.
        append("g").
        call(d3.axisLeft(y));

      // Add the lines
      const line = d3
        .line()
        .x((d) => x(+d.entry_date))
        .y((d) => y(+d.cumulative_count));

      svg
        .selectAll("myLines")
        .data(data)
        .join("path")
        .attr("class", (d) => d.group)
        .attr("d", (d) => line(d.values))
        .attr("stroke", (d) => myColor(d.group))
        .style("stroke-width", 4)
        .style("fill", "none");

      // create a tooltip
      const tooltip = d3
        .select("#my_dataviz")
        .append("div")
        .style("opacity", 0)
        .attr("class", "tooltip")
        .style("background-color", "white")
        .style("border", "solid")
        .style("border-width", "1px")
        .style("border-radius", "5px")
        .style("padding", "2px");

      // Three function that change the tooltip when user hover / move / leave a cell
      // layerX/Y replaced by clientX/Y
      const mouseover = function (event, d) {
        tooltip.style("opacity", 1);

        d3.select(this).style("stroke", "black");
      };

      const mousemove = function (event, d) {
        tooltip
          .html(
            "Count: " + d.cumulative_count + "<br>Date: " + d.entry_date_text
          )
          .style("left", `${event.layerX + 20}px`)
          .style("top", `${event.layerY + 20}px`);
      };

      const mouseleave = function (event, d) {
        tooltip.style("opacity", 0);

        d3.select(this).style("stroke", "white");
      };

      // Add the points
      svg
        // First we need to enter in a group
        .selectAll("myDots")
        .data(data)
        .enter().append("g")
        .style("fill", (d) => myColor(d.group))
        .attr("class", (d) => d.group)
        // Second we need to enter in the 'values' part of this group
        .selectAll("myPoints")
        .data((d) => d.values)
        .enter()
        .append("a")
        .attr("xlink:href", function(d) { return "/Entities/?sort=entity_id&filter=lessOrEqual(entry_date," + d.entry_date_text + "),any(category," + d.group  + ")"; }) // <- add links to the filtered phenotype table to the bars
        .append("circle")
        .attr("cx", (d) => x(d.entry_date))
        .attr("cy", (d) => y(d.cumulative_count))
        .attr("r", 5)
        .attr("stroke", "white")
        .style("fill", (d) => myColor(d.group))
        .on("mouseover", mouseover)
        .on("mousemove", mousemove)
        .on("mouseleave", mouseleave);

      // Add a legend (interactive)
      svg
        .selectAll("myLegend")
        .data(data)
        .join("g")
        .append("text")
        .attr("x", 30)
        .attr("y", (d, i) => 30 + i * 20)
        .text((d) => d.group)
        .style("fill", (d) => myColor(d.group))
        .style("font-size", 15)
        .on("click", function (event, d) {
          // is the element currently visible ?
          const currentOpacity = d3.selectAll("." + d.group).style("opacity");
          // Change the opacity: from 0 to 1 or from 1 to 0
          d3.selectAll("." + d.group)
            .transition()
            .style("opacity", currentOpacity == 1 ? 0 : 1);
        });
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
