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

         this.items = this.items.map(item => {
              return { cumulative_count: item.cumulative_count, entry_date: d3.timeParse("%Y-%m-%d")(item.entry_date) };
            });

          this.generateGraph();

        } catch (e) {
          console.error(e);
        }
      },
      generateGraph() {

      // set the dimensions and margins of the graph
      const margin = {top: 10, right: 30, bottom: 30, left: 60},
          width = 600 - margin.left - margin.right,
          height = 300 - margin.top - margin.bottom;

      // append the svg object to the body of the page
      const svg = d3.select("#my_dataviz")
        .append("svg")
          .attr("width", width + margin.left + margin.right)
          .attr("height", height + margin.top + margin.bottom)
        .append("g")
          .attr("transform",
                "translate(" + margin.left + "," + margin.top + ")");

      const data = this.items;
          console.log(data);

        // Add X axis --> it is a date format
        const x = d3.scaleTime()
          .domain(d3.extent(data, d => d.entry_date))
          .range([ 0, width ]);
          svg.append("g")
            .attr("transform", `translate(0,${height})`)
            .call(d3.axisBottom(x));

        // Add Y axis
        const y = d3.scaleLinear()
          .domain([0, d3.max(data, d => +d.cumulative_count)])
          .range([ height, 0 ]);
          svg.append("g")
            .call(d3.axisLeft(y));

        // Add the line
        svg.append("path")
          .datum(data)
          .attr("fill", "none")
          .attr("stroke", "steelblue")
          .attr("stroke-width", 1.5)
          .attr("d", d3.line()
            .x(function(d) { return x(d.entry_date) })
            .y(function(d) { return y(d.cumulative_count) })
            )

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
