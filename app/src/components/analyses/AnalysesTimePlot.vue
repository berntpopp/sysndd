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
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-left font-weight-bold">
            NDD entities and genes over time.
          </h6>
          <DownloadImageButtons
            :svg-id="'timeplot-svg'"
            :file-name="'entities_over_time'"
          />
        </div>
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
              text-field="text"
              size="sm"
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
              :options="filteredGroupList"
              text-field="text"
              size="sm"
            />
          </b-input-group>
        </b-col>
      </b-row>
      <!-- User Interface controls -->

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <b-spinner
          v-if="loadingData"
          label="Loading..."
          class="spinner"
        />
        <div
          v-show="!loadingData"
          id="my_dataviz"
          class="svg-container"
        />
      </div>
    </b-card>
  </b-container>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import textMixin from '@/assets/js/mixins/textMixin';
import DownloadImageButtons from '@/components/small/DownloadImageButtons.vue';
import * as d3 from 'd3';

export default {
  name: 'AnalysesTimePlot',
  components: {
    DownloadImageButtons,
  },
  mixins: [toastMixin, textMixin],
  data() {
    return {
      aggregate_list: [
        { value: 'entity_id', text: 'Entity ID' },
        { value: 'symbol', text: 'Symbol' },
      ],
      selected_aggregate: 'entity_id',
      group_list: [
        { value: 'category', text: 'Category' },
        { value: 'inheritance_filter', text: 'Inheritance Filter' },
        { value: 'inheritance_multiple', text: 'Inheritance Multiple' },
      ],
      selected_group: 'category',
      filter_string: 'contains(ndd_phenotype_word,Yes),any(inheritance_filter,Autosomal dominant,Autosomal recessive,X-linked)',
      items: [],
      itemsMeta: [],
      loadingData: true, // Added loading state
    };
  },
  computed: {
    filteredGroupList() {
      if (this.selected_aggregate === 'entity_id') {
        return this.group_list.filter((group) => group.value !== 'inheritance_multiple');
      }
      return this.group_list;
    },
  },
  watch: {
    selected_aggregate(newVal, oldVal) {
      if (newVal !== oldVal) {
        this.selected_group = 'category';
        this.loadData();
      }
    },
    selected_group() {
      this.loadData();
    },
  },
  mounted() {
    this.loadData();
  },
  methods: {
    async loadData() {
      this.loadingData = true;
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/statistics/entities_over_time?aggregate=${
        this.selected_aggregate
      }&group=${
        this.selected_group
      }&filter=${
        this.filter_string}`;

      try {
        const response = await this.axios.get(apiUrl);

        this.items = response.data.data;
        this.itemsMeta = response.data.meta;

        this.generateGraph();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingData = false; // Set loading to false after data is fetched
      }
    },
    generateLink(d) {
      let baseUrl = '/Entities/?sort=entity_id&filter=';
      if (this.selected_aggregate === 'symbol') {
        baseUrl = '/Genes/?sort=symbol&filter=';
      }

      const dateFilter = `lessOrEqual(entry_date,${d.entry_date_text})`;
      let groupFilter = '';

      if (this.selected_group === 'category') {
        groupFilter = `any(category,${d.group})`;
      } else if (this.selected_group === 'inheritance_filter' || this.selected_group === 'inheritance_multiple') {
        const groupText = d.group.split(' | ').map((term) => `${term} inheritance`).join(',');
        groupFilter = this.selected_group === 'inheritance_multiple' ? `all(hpo_mode_of_inheritance_term_name,${groupText})` : `any(hpo_mode_of_inheritance_term_name,${groupText})`;
      }

      return `${baseUrl}${groupFilter},${dateFilter}`;
    },
    generateGraph() {
      // based on https://d3-graph-gallery.com/graph/connectedscatter_legend.html and https://d3-graph-gallery.com/graph/connectedscatter_tooltip.html
      // responsive styling based on https://chartio.com/resources/tutorials/how-to-resize-an-svg-when-the-window-is-resized-in-d3-js/

      // set the dimensions and margins of the graph
      const margin = {
        top: 50, right: 50, bottom: 50, left: 50,
      };
      const width = 600 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // first remove svg
      d3.select('#my_dataviz').select('svg').remove();

      // append the svg object to the body of the page
      const svg = d3
        .select('#my_dataviz')
        .append('svg')
        .attr('id', 'timeplot-svg') // Added id for easier selection
        .attr('viewBox', '0 0 600 400')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .classed('svg-content', true)
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      const data = this.items.map((item) => ({
        group: item.group,
        class: item.group.replace(/[ |]/g, '_'),
        values: item.values.map((value) => ({
          group: item.group,
          cumulative_count: value.cumulative_count,
          entry_date_text: value.entry_date,
          entry_date: d3.timeParse('%Y-%m-%d')(value.entry_date),
        })),
      }));

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
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x));

      // Add Y axis
      const y = d3
        .scaleLinear()
        .domain([0, maxCount])
        .range([height, 0]);

      svg
        .append('g')
        .call(d3.axisLeft(y));

      // Add the lines
      const line = d3
        .line()
        .x((d) => x(+d.entry_date))
        .y((d) => y(+d.cumulative_count));

      svg
        .selectAll('myLines')
        .data(data)
        .join('path')
        .attr('class', (d) => d.class)
        .attr('d', (d) => line(d.values))
        .attr('stroke', (d) => myColor(d.group))
        .style('stroke-width', 4)
        .style('fill', 'none');

      // create a tooltip
      const tooltip = d3
        .select('#my_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid')
        .style('border-width', '1px')
        .style('border-radius', '5px')
        .style('padding', '2px');

      // Three functions that change the tooltip when user hover / move / leave a cell
      const mouseover = function mouseover(event, d) {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black');
      };

      const mousemove = function mousemove(event, d) {
        tooltip
          .html(
            `Count: ${d.cumulative_count}<br>Date: ${d.entry_date_text}`,
          )
          .style('left', `${event.clientX + 20}px`)
          .style('top', `${event.clientY + 20}px`);
      };

      const mouseleave = function mouseleave(event, d) {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'white');
      };

      // Add the points
      svg
      // First we need to enter in a group
        .selectAll('myDots')
        .data(data)
        .enter().append('g')
        .style('fill', (d) => myColor(d.group))
        .attr('class', (d) => d.class)
      // Second we need to enter in the 'values' part of this group
        .selectAll('myPoints')
        .data((d) => d.values)
        .enter()
        .append('a')
        .attr('xlink:href', (d) => this.generateLink(d)) // <- Use generateLink method here
        .attr('aria-label', (d) => `Link to entities filtered before entry date ${d.entry_date_text}`)
        .style('text-decoration', 'none') // <- Ensure no text decoration on links
        .append('circle')
        .attr('cx', (d) => x(d.entry_date))
        .attr('cy', (d) => y(d.cumulative_count))
        .attr('r', 5)
        .attr('stroke', 'white')
        .style('fill', (d) => myColor(d.group))
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);

      // function for clickable legend
      const clicklegend = function clicklegend(event, d) {
        // is the element currently visible?
        const currentOpacity = d3.selectAll(`.${d.class}`).style('opacity');

        // Change the opacity: from 0 to 1 or from 1 to 0
        d3.selectAll(`.${d.class}`)
          .transition()
          .style('opacity', currentOpacity === '1' ? '0' : '1');
      };

      // Add a legend (interactive)
      svg
        .selectAll('myLegend')
        .data(data)
        .join('g')
        .append('text')
        .attr('x', 30)
        .attr('y', (d, i) => 30 + i * 20)
        .text((d) => d.group)
        .style('fill', (d) => myColor(d.group))
        .style('font-size', 15)
        .style('cursor', 'pointer')
        .on('click', clicklegend);
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
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
