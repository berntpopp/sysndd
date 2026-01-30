<!-- src/components/analyses/PubtatorNDDStats.vue -->
<template>
  <BContainer fluid>
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            PubTator NDD Statistics
            <mark
              v-b-tooltip.hover.leftbottom
              title="Shows aggregated statistics from PubTator gene-publication associations."
            >
              (Bar Plots)
            </mark>
            <BBadge id="popover-badge-help-pubtator-stats" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-pubtator-stats" variant="info" triggers="focus">
              <template #title> PubTator Statistics </template>
              This section displays statistics from PubTator gene-publication associations, showing
              the distribution of publications per gene and other metrics.
            </BPopover>
          </h6>
        </div>
      </template>

      <!-- User Interface controls -->
      <BRow class="p-2">
        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Category" class="mb-1" size="sm">
            <BFormSelect
              v-model="selectedCategory"
              :options="categoryOptions"
              size="sm"
              @change="generateBarPlot"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Min Count" class="mb-1" size="sm">
            <BFormInput
              v-model="minCount"
              type="number"
              min="1"
              step="1"
              debounce="500"
              @change="fetchStats"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Top N" class="mb-1" size="sm">
            <BFormInput
              v-model="topN"
              type="number"
              min="5"
              max="100"
              step="5"
              debounce="500"
              @change="generateBarPlot"
            />
          </BInputGroup>
        </BCol>
      </BRow>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner v-if="loading" label="Loading..." class="spinner" />
        <div v-show="!loading" id="pubtator_stats_dataviz" class="svg-container" />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import * as d3 from 'd3';
import useToast from '@/composables/useToast';

export default {
  name: 'PubtatorNDDStats',
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      // user selections
      selectedCategory: 'gene',
      categoryOptions: [
        { value: 'gene', text: 'Top Genes by Publication Count' },
        { value: 'publication', text: 'Publications by Gene Count' },
      ],

      // minimum count filter
      minCount: 5,
      topN: 30,

      // data from the stats endpoint
      statsData: [],

      // chart loading state
      loading: true,
    };
  },
  async mounted() {
    await this.fetchStats();
  },
  methods: {
    /**
     * fetchStats
     * Fetches PubTator statistics from the API
     */
    async fetchStats() {
      this.loading = true;

      const baseUrl = `${import.meta.env.VITE_API_URL}/api/pubtator`;
      const params = new URLSearchParams();
      params.set('page_size', '1000'); // Get enough data for stats

      const apiUrl = `${baseUrl}?${params.toString()}`;

      try {
        const response = await this.axios.get(apiUrl);
        // Process the data to get statistics
        this.processStatsData(response.data.data || []);
        this.generateBarPlot();
      } catch (error) {
        this.makeToast(error, 'Error fetching PubTator stats', 'danger');
      } finally {
        this.loading = false;
      }
    },

    /**
     * processStatsData
     * Processes raw PubTator data into statistics
     */
    processStatsData(rawData) {
      if (this.selectedCategory === 'gene') {
        // Group by gene symbol and count publications
        const geneCounts = {};
        rawData.forEach((item) => {
          const symbol = item.symbol || 'Unknown';
          geneCounts[symbol] = (geneCounts[symbol] || 0) + 1;
        });

        this.statsData = Object.entries(geneCounts)
          .map(([name, count]) => ({ name, count }))
          .filter((d) => d.count >= this.minCount)
          .sort((a, b) => b.count - a.count);
      } else {
        // Group by PMID and count genes
        const pmidCounts = {};
        rawData.forEach((item) => {
          const pmid = item.pmid || 'Unknown';
          pmidCounts[pmid] = (pmidCounts[pmid] || 0) + 1;
        });

        // Create histogram of gene counts per publication
        const histogram = {};
        Object.values(pmidCounts).forEach((count) => {
          histogram[count] = (histogram[count] || 0) + 1;
        });

        this.statsData = Object.entries(histogram)
          .map(([geneCount, pubCount]) => ({
            name: `${geneCount} genes`,
            count: pubCount,
          }))
          .sort((a, b) => parseInt(a.name, 10) - parseInt(b.name, 10));
      }
    },

    /**
     * generateBarPlot
     * Builds a bar chart from the processed statistics
     */
    generateBarPlot() {
      if (!this.statsData || this.statsData.length === 0) return;

      // remove old svg and tooltip
      d3.select('#pubtator_stats_dataviz').select('svg').remove();
      d3.select('#pubtator_stats_dataviz').select('.tooltip').remove();

      // Limit to top N entries
      const data = this.statsData.slice(0, this.topN);

      // set dimensions
      const margin = {
        top: 30,
        right: 30,
        bottom: 150,
        left: 60,
      };
      const width = 760 - margin.left - margin.right;
      const height = 450 - margin.top - margin.bottom;

      // append the SVG
      const svg = d3
        .select('#pubtator_stats_dataviz')
        .append('svg')
        .attr('id', 'pubtator-stats-svg')
        .attr('viewBox', '0 0 760 450')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // X axis
      const x = d3
        .scaleBand()
        .range([0, width])
        .domain(data.map((d) => d.name))
        .padding(0.2);

      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .attr('transform', 'translate(-10,0)rotate(-45)')
        .style('text-anchor', 'end')
        .style('font-size', '10px');

      // Y axis
      const maxY = d3.max(data, (d) => d.count);
      const y = d3
        .scaleLinear()
        .domain([0, maxY * 1.1])
        .range([height, 0]);
      svg.append('g').call(d3.axisLeft(y));

      // Y axis label
      svg
        .append('text')
        .attr('transform', 'rotate(-90)')
        .attr('y', 0 - margin.left)
        .attr('x', 0 - height / 2)
        .attr('dy', '1em')
        .style('text-anchor', 'middle')
        .style('font-size', '12px')
        .text(this.selectedCategory === 'gene' ? 'Publication Count' : 'Number of Publications');

      // Create a tooltip element
      const tooltip = d3
        .select('#pubtator_stats_dataviz')
        .append('div')
        .attr('class', 'tooltip')
        .style('opacity', 0)
        .style('background-color', 'white')
        .style('border', 'solid 1px')
        .style('border-radius', '5px')
        .style('padding', '5px')
        .style('position', 'absolute')
        .style('pointer-events', 'none');

      const mouseover = function mouseover() {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black').style('opacity', 1);
      };

      const mousemove = function mousemove(event, d) {
        tooltip
          .html(`<strong>${d.name}</strong><br>Count: ${d.count}`)
          .style('left', `${event.layerX + 20}px`)
          .style('top', `${event.layerY + 20}px`);
      };

      const mouseleave = function mouseleave() {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      };

      // bars
      svg
        .selectAll('mybar')
        .data(data)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.name))
        .attr('y', (d) => y(d.count))
        .attr('width', x.bandwidth())
        .attr('height', (d) => height - y(d.count))
        .attr('fill', '#5470c6')
        .on('mouseover', mouseover)
        .on('mousemove', mousemove)
        .on('mouseleave', mouseleave);
    },
  },
};
</script>

<style scoped>
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 900px;
  vertical-align: top;
  overflow: hidden;
  min-height: 450px;
}
.svg-container svg {
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
.tooltip {
  pointer-events: none;
  font-size: 0.9rem;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
