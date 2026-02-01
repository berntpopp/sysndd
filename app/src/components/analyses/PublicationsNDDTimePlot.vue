<!-- src/components/analyses/PublicationsNDDTimePlot.vue -->
<template>
  <BContainer fluid>
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            Publications Over Time / Type
            <mark
              v-b-tooltip.hover.leftbottom
              title="Select 'Publication date' or 'Update date' or display publication_type counts."
            >
              (Interactive)
            </mark>
            <BBadge id="popover-badge-help-timeplot" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-timeplot" variant="info" triggers="focus">
              <template #title> Publications Over Time / Type </template>
              This plot can display either the publication_date_aggregated, update_date_aggregated
              line graphs or a bar chart of publication_type_counts. Hover over the points/bars to
              see the details.
            </BPopover>
          </h6>
        </div>
      </template>

      <!-- Controls row -->
      <BRow>
        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Display" size="sm" class="mb-1">
            <BFormSelect v-model="plotMode" :options="plotModeOptions" @change="generateGraph" />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Aggregate" size="sm" class="mb-1">
            <BFormSelect
              v-model="timeAggregation"
              :options="timeAggregationOptions"
              :disabled="plotMode === 'type_counts'"
              @change="loadData"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BFormCheckbox
            v-model="showCumulative"
            :disabled="plotMode === 'type_counts'"
            switch
            class="mt-1"
            @change="generateGraph"
          >
            Cumulative View
          </BFormCheckbox>
        </BCol>
      </BRow>

      <!-- Overlay spinner & SVG container -->
      <div class="position-relative">
        <BSpinner v-if="loading" label="Loading..." class="spinner" />
        <div v-show="!loading" id="pubs_dataviz" class="svg-container" />
      </div>
    </BCard>
  </BContainer>
</template>

<script>
import { useToast, useText } from '@/composables';
import * as d3 from 'd3';

export default {
  name: 'PublicationsNDDTimePlot',
  setup() {
    const { makeToast } = useToast();
    const text = useText();

    return {
      makeToast,
      ...text,
    };
  },
  data() {
    return {
      // Options to pick from: "Publication date," "Update date," or "Publication type"
      plotModeOptions: [
        { value: 'publication_date', text: 'Publication Date (Line)' },
        { value: 'update_date', text: 'Update Date (Line)' },
        { value: 'type_counts', text: 'Publication Type (Bar)' },
      ],
      plotMode: 'publication_date', // default selection

      // Time aggregation options (year/month/quarter)
      timeAggregation: 'year',
      timeAggregationOptions: [
        { value: 'year', text: 'Year' },
        { value: 'month', text: 'Month' },
        { value: 'quarter', text: 'Quarter' },
      ],

      // Cumulative view toggle
      showCumulative: false,

      statsData: null, // Will store the entire object from publication_stats
      loading: true,
    };
  },
  async mounted() {
    await this.loadData();
  },
  methods: {
    async loadData() {
      this.loading = true;

      // GET /api/statistics/publication_stats with time_aggregate parameter
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/statistics/publication_stats`;
      try {
        const response = await this.axios.get(apiUrl, {
          params: {
            time_aggregate: this.timeAggregation,
          },
        });
        this.statsData = response.data;
        // Now we generate the graph
        this.generateGraph();
      } catch (err) {
        this.makeToast(err, 'Error', 'danger');
      } finally {
        this.loading = false;
      }
    },

    generateGraph() {
      // Remove old svg and tooltips to prevent duplicates
      d3.select('#pubs_dataviz').select('svg').remove();
      d3.select('#pubs_dataviz').selectAll('.tooltip').remove();

      if (!this.statsData) return;

      if (this.plotMode === 'publication_date') {
        this.generateLinePlot(this.statsData.publication_date_aggregated, 'Publication_date');
      } else if (this.plotMode === 'update_date') {
        this.generateLinePlot(this.statsData.update_date_aggregated, 'update_date');
      } else if (this.plotMode === 'type_counts') {
        this.generateBarPlot(this.statsData.publication_type_counts);
      }
    },

    /**
     * formatDateForTooltip
     * Formats date based on aggregation level
     * @param {Date} date - Date object
     * @returns {String} - Formatted date string
     */
    formatDateForTooltip(date) {
      if (this.timeAggregation === 'year') {
        return d3.timeFormat('%Y')(date);
      } else if (this.timeAggregation === 'quarter') {
        return `Q${Math.floor(date.getMonth() / 3) + 1} ${date.getFullYear()}`;
      } else {
        return d3.timeFormat('%b %Y')(date);
      }
    },

    /**
     * generateLinePlot
     * Renders a line plot for an array of objects with shape:
     *   { Publication_date or update_date: 'YYYY-MM-DD', count: number }
     * Uses data already aggregated by the API and optionally applies cumulative view.
     * @param {Array} dataArr
     * @param {String} dateKey e.g. 'Publication_date' or 'update_date'
     */
    generateLinePlot(dataArr, dateKey) {
      // basic margin & dimension
      const margin = {
        top: 30,
        right: 30,
        bottom: 50,
        left: 70,
      };
      const width = 600 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // create the svg
      const svg = d3
        .select('#pubs_dataviz')
        .append('svg')
        .attr('viewBox', '0 0 600 400')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // Parse dates from API data (already aggregated by server)
      const parseDate = d3.timeParse('%Y-%m-%d');
      let data = dataArr
        .map((d) => ({
          dateVal: parseDate(d[dateKey]),
          count: d.count,
        }))
        .filter((d) => d.dateVal !== null)
        .sort((a, b) => a.dateVal - b.dateVal);

      // Apply cumulative view if enabled
      if (this.showCumulative) {
        let cumulative = 0;
        data = data.map((d) => {
          cumulative += d.count;
          return { ...d, count: cumulative };
        });
      }

      if (data.length === 0) return;

      // x scale
      const x = d3
        .scaleTime()
        .domain(d3.extent(data, (d) => d.dateVal))
        .nice()
        .range([0, width]);

      // Calculate time span to determine appropriate tick intervals
      const [minDate, maxDate] = d3.extent(data, (d) => d.dateVal);
      const yearsSpan = (maxDate - minDate) / (1000 * 60 * 60 * 24 * 365);

      // Configure axis with smart tick selection based on time span
      // Goal: Keep ~8-12 readable ticks regardless of aggregation level
      const xAxis = d3.axisBottom(x);

      if (this.timeAggregation === 'year') {
        // For yearly data, show every N years based on span
        const yearInterval = yearsSpan > 30 ? 5 : yearsSpan > 15 ? 3 : yearsSpan > 8 ? 2 : 1;
        xAxis.ticks(d3.timeYear.every(yearInterval)).tickFormat(d3.timeFormat('%Y'));
      } else if (this.timeAggregation === 'month') {
        // For monthly data, show year ticks only (data points are still monthly)
        const yearInterval = yearsSpan > 30 ? 5 : yearsSpan > 15 ? 3 : yearsSpan > 8 ? 2 : 1;
        xAxis.ticks(d3.timeYear.every(yearInterval)).tickFormat(d3.timeFormat('%Y'));
      } else if (this.timeAggregation === 'quarter') {
        // For quarterly data, show year ticks only (data points are still quarterly)
        const yearInterval = yearsSpan > 30 ? 5 : yearsSpan > 15 ? 3 : yearsSpan > 8 ? 2 : 1;
        xAxis.ticks(d3.timeYear.every(yearInterval)).tickFormat(d3.timeFormat('%Y'));
      }

      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(xAxis)
        .selectAll('text')
        .style('text-anchor', 'middle')
        .style('font-size', '11px');

      // y scale
      const maxCount = d3.max(data, (d) => d.count);
      const y = d3
        .scaleLinear()
        .domain([0, maxCount * 1.1])
        .range([height, 0]);

      svg.append('g').call(d3.axisLeft(y));

      // line generator
      const line = d3
        .line()
        .x((d) => x(d.dateVal))
        .y((d) => y(d.count));

      // append path
      svg
        .append('path')
        .datum(data)
        .attr('fill', 'none')
        .attr('stroke', '#69b3a2')
        .attr('stroke-width', 2)
        .attr('d', line);

      // tooltip with improved styling
      const tooltip = d3
        .select('#pubs_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid 1px #ccc')
        .style('border-radius', '5px')
        .style('padding', '8px')
        .style('position', 'absolute')
        .style('pointer-events', 'none')
        .style('font-size', '0.85rem')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)');

      // Store references for tooltip content formatting
      const formatDate = this.formatDateForTooltip.bind(this);
      const isCumulative = this.showCumulative;
      const container = document.getElementById('pubs_dataviz');

      /**
       * Handle mouse over for line points.
       */
      function handleLineMouseOver() {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black').attr('r', 6);
      }

      /**
       * Handle mouse move for line points.
       * Uses smart positioning to prevent tooltip from being cut off at edges.
       * @param {Event} event
       * @param {Object} d
       */
      function handleLineMouseMove(event, d) {
        const containerRect = container.getBoundingClientRect();
        const tooltipWidth = 150; // approximate tooltip width
        const tooltipHeight = 50; // approximate tooltip height
        const offset = 15;

        // Calculate position relative to container
        const mouseX = event.clientX - containerRect.left;
        const mouseY = event.clientY - containerRect.top;

        // Smart positioning: flip to left if too close to right edge
        let left = mouseX + offset;
        if (mouseX + tooltipWidth + offset > containerRect.width) {
          left = mouseX - tooltipWidth - offset;
        }

        // Smart positioning: flip to top if too close to bottom edge
        let top = mouseY + offset;
        if (mouseY + tooltipHeight + offset > containerRect.height) {
          top = mouseY - tooltipHeight - offset;
        }

        // Ensure tooltip doesn't go negative
        left = Math.max(0, left);
        top = Math.max(0, top);

        const label = isCumulative ? 'Total' : 'Count';
        tooltip
          .html(
            `<strong>${formatDate(d.dateVal)}</strong><br/>` +
              `${label}: <strong>${d.count.toLocaleString()}</strong>`
          )
          .style('left', `${left}px`)
          .style('top', `${top}px`);
      }

      /**
       * Handle mouse leave for line points.
       */
      function handleLineMouseLeave() {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'white').attr('r', 4);
      }

      // points
      svg
        .selectAll('circle')
        .data(data)
        .enter()
        .append('circle')
        .attr('cx', (d) => x(d.dateVal))
        .attr('cy', (d) => y(d.count))
        .attr('r', 4)
        .attr('fill', '#69b3a2')
        .attr('stroke', 'white')
        // Named event handlers:
        .on('mouseover', handleLineMouseOver)
        .on('mousemove', handleLineMouseMove)
        .on('mouseleave', handleLineMouseLeave);
    },

    /**
     * generateBarPlot
     * Renders a simple bar chart for e.g. publication_type_counts, with shape:
     *   { publication_type: 'foo', count: 123 }
     */
    generateBarPlot(countArr) {
      // margin & dimension
      const margin = {
        top: 30,
        right: 30,
        bottom: 150,
        left: 100,
      };
      const width = 600 - margin.left - margin.right;
      const height = 400 - margin.top - margin.bottom;

      // create the svg
      const svg = d3
        .select('#pubs_dataviz')
        .append('svg')
        .attr('viewBox', '0 0 600 400')
        .attr('preserveAspectRatio', 'xMinYMin meet')
        .append('g')
        .attr('transform', `translate(${margin.left},${margin.top})`);

      // x scale
      const x = d3
        .scaleBand()
        .range([0, width])
        .domain(countArr.map((d) => d.publication_type))
        .padding(0.2);

      svg
        .append('g')
        .attr('transform', `translate(0,${height})`)
        .call(d3.axisBottom(x))
        .selectAll('text')
        .attr('transform', 'translate(-10,0)rotate(-45)')
        .style('text-anchor', 'end')
        .style('font-size', '12px');

      // y scale
      const maxVal = d3.max(countArr, (d) => d.count);
      const y = d3
        .scaleLinear()
        .domain([0, maxVal * 1.1])
        .range([height, 0]);

      svg.append('g').call(d3.axisLeft(y));

      // tooltip with improved styling
      const tooltip = d3
        .select('#pubs_dataviz')
        .append('div')
        .style('opacity', 0)
        .attr('class', 'tooltip')
        .style('background-color', 'white')
        .style('border', 'solid 1px #ccc')
        .style('border-radius', '5px')
        .style('padding', '8px')
        .style('position', 'absolute')
        .style('pointer-events', 'none')
        .style('font-size', '0.85rem')
        .style('box-shadow', '0 2px 4px rgba(0,0,0,0.1)');

      // Get the container for relative positioning
      const container = document.getElementById('pubs_dataviz');

      /**
       * Handle mouse over for bar chart bars.
       */
      function handleBarMouseOver() {
        tooltip.style('opacity', 1);
        d3.select(this).style('stroke', 'black').style('stroke-width', '2px');
      }

      /**
       * Handle mouse move for bar chart bars.
       * Uses smart positioning to prevent tooltip from being cut off at edges.
       * @param {Event} event
       * @param {Object} d
       */
      function handleBarMouseMove(event, d) {
        const containerRect = container.getBoundingClientRect();
        const tooltipWidth = 180; // approximate tooltip width
        const tooltipHeight = 50; // approximate tooltip height
        const offset = 15;

        // Calculate position relative to container
        const mouseX = event.clientX - containerRect.left;
        const mouseY = event.clientY - containerRect.top;

        // Smart positioning: flip to left if too close to right edge
        let left = mouseX + offset;
        if (mouseX + tooltipWidth + offset > containerRect.width) {
          left = mouseX - tooltipWidth - offset;
        }

        // Smart positioning: flip to top if too close to bottom edge
        let top = mouseY + offset;
        if (mouseY + tooltipHeight + offset > containerRect.height) {
          top = mouseY - tooltipHeight - offset;
        }

        // Ensure tooltip doesn't go negative
        left = Math.max(0, left);
        top = Math.max(0, top);

        tooltip
          .html(
            `<strong>${d.publication_type}</strong><br/>` +
              `Count: <strong>${d.count.toLocaleString()}</strong>`
          )
          .style('left', `${left}px`)
          .style('top', `${top}px`);
      }

      /**
       * Handle mouse leave for bar chart bars.
       */
      function handleBarMouseLeave() {
        tooltip.style('opacity', 0);
        d3.select(this).style('stroke', 'none');
      }

      // Bars
      svg
        .selectAll('myBars')
        .data(countArr)
        .enter()
        .append('rect')
        .attr('x', (d) => x(d.publication_type))
        .attr('y', (d) => y(d.count))
        .attr('width', x.bandwidth())
        .attr('height', (d) => height - y(d.count))
        .attr('fill', '#69b3a2')
        // Named event handlers:
        .on('mouseover', handleBarMouseOver)
        .on('mousemove', handleBarMouseMove)
        .on('mouseleave', handleBarMouseLeave);
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
  overflow: visible;
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
  position: absolute;
}
</style>
