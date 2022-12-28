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
        <h5 class="mb-1 text-left font-weight-bold">
          Entities clustered using phenotype annotation.
        </h5>
      </template>

      <!-- Content -->
      <b-row>
        <b-col md="4">
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-left"
            body-class="p-0"
            header-class="p-1"
            footer-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-0 font-weight-bold">
                Selected cluster {{ selectedCluster.cluster }} with {{ selectedCluster.cluster_size }} entities
              </h6>
            </template>

            <div
              id="cluster_dataviz"
              class="svg-container"
            />

            <template #footer>
              <b-link :href="'/Entities/?filter=' + selectedCluster.hash_filter">
                Entities for cluster {{ selectedCluster.cluster }}
              </b-link>
            </template>
          </b-card>
        </b-col>
        <b-col md="8">
          <b-card
            header-tag="header"
            class="my-3 mx-2 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-0 font-weight-bold">
                <b-input-group
                  prepend="Table type"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    v-model="tableType"
                    :options="tableOptions"
                    type="search"
                    size="sm"
                  />
                </b-input-group>
              </h6>
            </template>
            <b-card-text class="text-left">
              <b-table
                id="my-table"
                :items="selectedCluster[tableType]"
                :fields="selectedClusterFields"
                stacked="lg"
                head-variant="light"
                show-empty
                small
                style="width: 100%; white-space: nowrap"
                :per-page="perPage"
                :current-page="currentPage"
              />
              <b-row class="justify-content-md-center">
                <b-col />
                <b-col
                  cols="12"
                  md="auto"
                >
                  <b-pagination
                    v-model="currentPage"
                    :total-rows="totalRows"
                    :per-page="perPage"
                    aria-controls="my-table"
                  />
                </b-col>
                <b-col />
              </b-row>
            </b-card-text>
          </b-card>
        </b-col>
      </b-row>
      <!-- Content -->
    </b-card>
    <!-- User Interface controls -->
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

import * as d3 from 'd3';

export default {
  name: 'AnalysesPhenotypeClusters',
  mixins: [toastMixin],
  data() {
    return {
      itemsCluster: [],
      selectedCluster: {
        quali_inp_var: [],
        quali_sup_var: [],
        quanti_sup_var: [],
      },
      selectedClusterFields: [
        { key: 'variable', label: 'Variable', class: 'text-left' },
        { key: 'p.value', label: 'p-value', class: 'text-left' },
        { key: 'v.test', label: 'v-test', class: 'text-left' },
      ],
      tableOptions: [
        { value: 'quali_inp_var', text: 'Qualitative input variables (phenotypes)' },
        { value: 'quali_sup_var', text: 'Qualitative supplementary variables (inheritance)' },
        { value: 'quanti_sup_var', text: 'Quantitative supplementary variables (phenotype counts)' },
      ],
      tableType: 'quali_inp_var',
      activeCluster: '1',
      perPage: 10,
      totalRows: 1,
      currentPage: 1,
    };
  },
  watch: {
    activeCluster(value) {
      this.setActiveCluster();
      // TODO: do not redraw the svg, instead just set border in function
      this.generateClusterGraph();
    },
    tableType(value) {
      this.totalRows = this.selectedCluster[this.tableType].length;
    },
  },
  mounted() {
    this.loadClusterData();
  },
  methods: {
    async loadClusterData() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/analysis/phenotype_clustering`;

      try {
        const response = await this.axios.get(apiUrl);

        this.itemsCluster = response.data;
        this.setActiveCluster();

        this.generateClusterGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    setActiveCluster() {
      let rest;
      [this.selectedCluster, ...rest] = this.itemsCluster.filter((item) => item.cluster === this.activeCluster);
      this.totalRows = this.selectedCluster[this.tableType].length;
    },
    generateClusterGraph() {
      // Graph dimension
      const margin = {
        top: 10, right: 10, bottom: 10, left: 10,
      };
      const width = 400 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // first remove svg
      d3.select('#cluster_dataviz').select('svg').remove();
      d3.select('#cluster_dataviz').select('div').remove();

      // Create the svg area
      const svg = d3
        .select('#cluster_dataviz')
        .append('svg')
        .attr('width', width)
        .attr('height', height);

      // define data from API call object
      const data = this.itemsCluster;

      // Color palette for clusters
      const color = d3
        .scaleOrdinal()
        .domain([1, 2, 3, 4, 5, 6])
        .range(d3.schemeSet1);

      // Size scale for clusters
      const size = d3
        .scaleLinear()
        .domain([0, 1000])
        .range([7, 55]); // circle will be between 7 and 55 px wide

      // get unique cluster ids as array
      const unique = (value, index, self) => self.indexOf(value) === index;

      const unique_cluster = data
        .map(({ cluster }) => cluster)
        .filter(unique);

      // A scale that gives a X target position for each cluster
      const x = d3
        .scaleOrdinal()
        .domain(unique_cluster)
        .range(
          unique_cluster.map((x) => x * 30),
        );

      // create a tooltip
      const Tooltip = d3
        .select('#cluster_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid')
        .style('border-width', '2px')
        .style('border-radius', '5px')
        .style('padding', '5px');

      const mouseover = function mouseover(event, d) {
        d3.select(this)
          .style('cursor', 'pointer');
        Tooltip
          .style('opacity', 1);

        d3.select(this).style('stroke', 'black');
      };

      const mousemove = function mousemove(event, d) {
        Tooltip.html(
          `<u>Cluster: ${
            d.cluster
          }</u>`
            + `<br>${
              d.cluster_size
            } entities`,
        )
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      const mouseleave = function mouseleave(event, d) {
        d3.select(this)
          .style('cursor', 'default');
        Tooltip
          .style('opacity', 0);

        d3.select(this).style('stroke', '#696969');
      };

      // Features of the forces applied to the nodes:
      const simulation = d3
        .forceSimulation()
        .force(
          'center',
          d3
            .forceCenter()
            .x(width / 2)
            .y(height / 2),
        ) // Attraction to the center of the svg area
        .force('charge', d3.forceManyBody().strength(0.1)) // Nodes are attracted one each other of value is > 0
        .force(
          'collide',
          d3
            .forceCollide()
            .strength(0.2)
            .radius((d) => size(d.cluster_size) + 3)
            .iterations(1),
        ) // Force that avoids circle overlapping
        .force(
          'forceX',
          d3
            .forceX()
            .strength(0.5)
            .x((d) => x(d.cluster)),
        )
        .force(
          'forceY',
          d3
            .forceY()
            .strength(0.1)
            .y(height * 0.5),
        );

      // What happens when a circle is dragged?
      function dragstarted(event, d) {
        if (!event.active) simulation.alphaTarget(0.03).restart();
        d.fx = d.x;
        d.fy = d.y;
      }
      function dragged(event, d) {
        d.fx = event.x;
        d.fy = event.y;
      }
      function dragended(event, d) {
        if (!event.active) simulation.alphaTarget(0.03);
        d.fx = null;
        d.fy = null;
      }

      // Initialize the circle: all located at the center of the svg area
      const node = svg
        .append('g')
        .selectAll('circle')
        .data(data)
        .enter()
        .append('a')
        // .attr('xlink:href', (d) => `/Entities/?filter=${d.hash_filter}`) // <- add links to the filtered gene table to the circles
        // .attr('aria-label', (d) => `Link to entity table for cluster, ${d.cluster}`)
        .append('circle')
        .attr('class', 'node')
        .attr('r', (d) => size(d.cluster_size))
        .attr('cx', width / 2)
        .attr('cy', height / 2)
        .style('fill', (d) => color(d.cluster))
        .style('fill-opacity', 0.8)
        .attr('stroke', '#696969')
        .style('stroke-width', (d) => {
          if (d.cluster === this.activeCluster) {
            return 4;
          }
          return 1;
        })
        .on('mouseover', mouseover) // What to do when hovered
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave)
        .on('click', (e, d) => {
          this.activeCluster = d.cluster;
        })
        .call(
          d3
            .drag() // call specific function when circle is dragged
            .on('start', dragstarted)
            .on('drag', dragged)
            .on('end', dragended),
        );

      // Apply these forces to the nodes and update their positions.
      // Once the force algorithm is happy with positions ('alpha' value is low enough), simulations will stop.
      simulation
        .nodes(data)
        .on('tick', (d) => {
          node
            .attr('cx', (d) => d.x)
            .attr('cy', (d) => d.y);
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
